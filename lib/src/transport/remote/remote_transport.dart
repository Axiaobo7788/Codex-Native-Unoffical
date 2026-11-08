import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import '../../domain/approval_models.dart';
import '../../domain/ecosystem_models.dart';
import '../../domain/history_models.dart';
import '../../domain/model_models.dart';
import '../../domain/output_models.dart';
import '../../domain/thread_models.dart';
import '../../domain/turn_models.dart';
import '../../protocol/history_protocol.dart';
import '../../protocol/jsonl_decoder.dart';
import '../../protocol/model_protocol.dart';
import '../../protocol/protocol_models.dart';
import '../../protocol/thread_protocol.dart';
import '../../protocol/turn_protocol.dart';
import '../codex_transport.dart';
import 'remote_protocol.dart';
import 'remote_session.dart';
import 'remote_socket.dart';

const _protocolVersion = 1;
const _maxPendingRequests = 64;
const _maxBufferedEvents = 512;
const _maxBufferedEventBytes = 8 * 1024 * 1024;
const _maxRequestId = 0x7fffffff;
const _requiredCapabilities = {'ack', 'eventReplay', 'readOnlyCodex'};
const _eventMethods = {
  'turn/started',
  'turn/completed',
  'item/started',
  'item/completed',
  'thread/status/changed',
  'thread/name/updated',
  'thread/archived',
  'thread/unarchived',
  'thread/reverted',
  'error',
  'host/resyncRequired',
};

final class RemoteTransport implements CodexTransport, RemoteSession {
  RemoteTransport._({
    required this._socket,
    required this._input,
    required this.handshake,
    required this._lastSequence,
    required this._durableCursor,
    required this._requiresResync,
    required this._resyncGeneration,
    required this.requestTimeout,
  }) {
    _notifications = StreamController<CodexNotification>.broadcast(
      sync: true,
      onListen: _drainBufferedEvents,
    );
    _sequencedNotifications =
        StreamController<RemoteSequencedNotification>.broadcast(
          sync: true,
          onListen: _drainBufferedEvents,
        );
    _turnProtocol = TurnProtocolAdapter(
      request: _request,
      notifications: _notifications.stream,
    );
    _modelProtocol = ModelProtocolAdapter(request: _request);
    _threadProtocol = ThreadProtocolAdapter(
      request: _request,
      notifications: _notifications.stream,
    );
    _historyProtocol = HistoryProtocolAdapter(request: _request);
    _ensureReader();
  }

  static Future<RemoteTransport> connect({
    required Uri endpoint,
    required String credential,
    RemoteResumeCursor? resumeCursor,
    RemoteSocketConnector connector = IoRemoteSocket.connect,
    bool allowInsecureLoopback = false,
    Duration handshakeTimeout = const Duration(seconds: 5),
    Duration requestTimeout = const Duration(seconds: 35),
  }) async {
    validateRemoteEndpoint(
      endpoint,
      allowInsecureLoopback: allowInsecureLoopback,
    );
    validateRemoteCredential(credential);
    validateRemoteResumeCursor(resumeCursor);
    if (requestTimeout <= Duration.zero || handshakeTimeout <= Duration.zero) {
      throw ArgumentError('Remote timeouts must be positive.');
    }

    final socketFuture = connector(endpoint, credential);
    late final RemoteSocket socket;
    try {
      socket = await socketFuture.timeout(handshakeTimeout);
    } on TimeoutException {
      unawaited(
        socketFuture.then<void>((lateSocket) async {
          try {
            await lateSocket.close(
              WebSocketStatus.goingAway,
              'Remote connection attempt expired',
            );
          } on Object {
            // A timed-out connection may fail independently while closing.
          }
        }, onError: (Object _, StackTrace _) {}),
      );
      rethrow;
    }
    final input = StreamIterator<Object?>(socket.messages);
    try {
      if (socket.protocol != remoteWebSocketProtocol) {
        throw const ProtocolViolation(
          'Remote WebSocket subprotocol was not negotiated.',
        );
      }
      final hello = await _nextHandshakeMessage(
        input,
        handshakeTimeout,
        'server_hello',
      );
      final helloSession = _requiredString(hello, 'sessionId', maxLength: 128);
      final helloSequence = _requiredSequence(hello, 'sequence');
      final versions = _requiredIntList(hello, 'supportedProtocolVersions');
      final minVersion = _requiredInt(hello, 'minProtocolVersion');
      final maxVersion = _requiredInt(hello, 'maxProtocolVersion');
      final helloCapabilities = _requiredStringSet(hello, 'capabilities');
      if (minVersion < 0 ||
          maxVersion < minVersion ||
          !versions.contains(_protocolVersion) ||
          minVersion > _protocolVersion ||
          maxVersion < _protocolVersion ||
          !_hasRequiredCapabilities(helloCapabilities)) {
        throw const ProtocolViolation(
          'Remote Host does not support the required protocol capabilities.',
        );
      }

      await _sendBounded(socket, {
        'type': 'client_hello',
        'supportedProtocolVersions': [_protocolVersion],
        if (resumeCursor != null) ...{
          'lastSessionId': resumeCursor.sessionId,
          'lastSequence': resumeCursor.sequence,
        },
      });
      final acknowledgement = await _nextHandshakeMessage(
        input,
        handshakeTimeout,
        'hello_ack',
      );
      final sessionId = _requiredString(
        acknowledgement,
        'sessionId',
        maxLength: 128,
      );
      final serverSequence = _requiredSequence(acknowledgement, 'sequence');
      final protocolVersion = _requiredInt(acknowledgement, 'protocolVersion');
      final replayAvailable = _requiredBool(acknowledgement, 'replayAvailable');
      final serverRequiresResync = _requiredBool(
        acknowledgement,
        'resyncRequired',
      );
      final capabilities = _requiredStringSet(acknowledgement, 'capabilities');
      if (sessionId != helloSession ||
          serverSequence < helloSequence ||
          protocolVersion != _protocolVersion ||
          !replayAvailable ||
          !_hasRequiredCapabilities(capabilities)) {
        throw const ProtocolViolation(
          'Remote negotiation acknowledgement is inconsistent.',
        );
      }

      final canResume =
          resumeCursor != null &&
          resumeCursor.sessionId == sessionId &&
          resumeCursor.sequence <= serverSequence &&
          !serverRequiresResync;
      final requiresResync = !canResume;
      final initialSequence = canResume
          ? resumeCursor.sequence
          : serverSequence;
      return RemoteTransport._(
        socket: socket,
        input: input,
        handshake: RemoteHandshake(
          sessionId: sessionId,
          serverSequence: serverSequence,
          requiresResync: requiresResync,
          capabilities: Set.unmodifiable(capabilities),
        ),
        lastSequence: initialSequence,
        durableCursor: canResume ? resumeCursor : null,
        requiresResync: requiresResync,
        resyncGeneration: requiresResync ? 1 : 0,
        requestTimeout: requestTimeout,
      );
    } catch (_) {
      try {
        await input.cancel();
      } on Object {
        // Preserve the original negotiation failure.
      }
      try {
        await socket.close(
          WebSocketStatus.protocolError,
          'Remote handshake failed',
        );
      } on Object {
        // Preserve the original negotiation failure.
      }
      rethrow;
    }
  }

  final RemoteSocket _socket;
  final StreamIterator<Object?> _input;
  @override
  final RemoteHandshake handshake;
  final Duration requestTimeout;
  final Map<int, _PendingRequest> _pending = {};
  final ListQueue<_BufferedEvent> _bufferedEvents = ListQueue();
  final StreamController<ProtocolViolation> _protocolErrors =
      StreamController<ProtocolViolation>.broadcast(sync: true);
  final StreamController<RemoteResyncRequired> _resyncEvents =
      StreamController<RemoteResyncRequired>.broadcast(sync: true);
  late final StreamController<CodexNotification> _notifications;
  late final StreamController<RemoteSequencedNotification>
  _sequencedNotifications;
  late final TurnProtocolAdapter _turnProtocol;
  late final ModelProtocolAdapter _modelProtocol;
  late final ThreadProtocolAdapter _threadProtocol;
  late final HistoryProtocolAdapter _historyProtocol;
  Future<void>? _reader;
  Future<void>? _finishOperation;
  final Completer<RemoteTransportClose> _closed = Completer();
  RemoteResumeCursor? _durableCursor;
  var _lastSequence = 0;
  var _bufferedEventBytes = 0;
  var _nextRequestId = 1;
  var _requiresResync = false;
  var _resyncGeneration = 0;
  var _closing = false;

  @override
  RemoteResumeCursor? get resumeCursor => _durableCursor;
  @override
  bool get requiresResync => _requiresResync;
  @override
  int get resyncGeneration => _resyncGeneration;
  @override
  int get currentSequence => _lastSequence;
  @override
  Stream<RemoteResyncRequired> get resyncEvents => _resyncEvents.stream;
  @override
  Stream<RemoteSequencedNotification> get sequencedNotifications =>
      _sequencedNotifications.stream;
  @override
  Future<RemoteTransportClose> get closed => _closed.future;

  @override
  void completeResync({required int generation}) {
    if (_closing) {
      throw const TransportClosedException();
    }
    if (!_requiresResync || generation != _resyncGeneration) {
      throw StateError('Remote resync completion is stale.');
    }
    _requiresResync = false;
    _durableCursor = RemoteResumeCursor(
      sessionId: handshake.sessionId,
      sequence: _lastSequence,
    );
    _drainBufferedEvents();
  }

  @override
  Stream<CodexNotification> get notifications => _notifications.stream;

  @override
  Stream<CodexServerRequest> get serverRequests => const Stream.empty();

  @override
  Stream<ProtocolViolation> get protocolErrors => _protocolErrors.stream;

  @override
  Stream<TurnEvent> get turnEvents => _turnProtocol.events;

  @override
  Stream<ThreadLifecycleEvent> get threadEvents => _threadProtocol.events;

  @override
  Stream<ApprovalEvent> get approvalEvents => const Stream.empty();

  @override
  Future<RemoteStatus> status() async {
    final result = await _request('host/remote/status');
    final device = _requiredObject(result, 'device');
    return RemoteStatus(
      sessionId: _requiredString(result, 'sessionId', maxLength: 128),
      deviceId: _requiredString(device, 'id', maxLength: 128),
      deviceName: _requiredString(device, 'name', maxLength: 128),
      mode: _requiredString(result, 'mode', maxLength: 64),
    );
  }

  @override
  Future<InitializeResult> initialize(InitializeRequest request) async {
    final remote = await status();
    if (remote.sessionId != handshake.sessionId ||
        remote.mode != 'readOnlyCodex') {
      throw const ProtocolViolation('Remote status changed after negotiation.');
    }
    return const InitializeResult(userAgent: 'Codex Native Remote');
  }

  @override
  Future<ModelPage> listModels(ModelListQuery query) =>
      _modelProtocol.listModels(query);

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) =>
      _threadProtocol.listThreads(query);

  @override
  Future<ThreadSummary> readThread(String threadId) =>
      _threadProtocol.readThread(threadId);

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) =>
      _historyProtocol.listTurns(query);

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) =>
      _historyProtocol.listItems(query);

  @override
  Future<List<HistoryItem>> readHistoryItems({
    required String threadId,
    required String turnId,
    required List<String> itemIds,
  }) => _historyProtocol.readItems(
    threadId: threadId,
    turnId: turnId,
    itemIds: itemIds,
  );

  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) =>
      _unsupported('Thread creation');

  @override
  Future<ThreadSummary> resumeThread(String threadId) =>
      _unsupported('Thread resume');

  @override
  Future<void> renameThread({required String threadId, required String name}) =>
      _unsupported('Thread rename');

  @override
  Future<void> archiveThread(String threadId) =>
      _unsupported('Thread archiving');

  @override
  Future<ThreadSummary> unarchiveThread(String threadId) =>
      _unsupported('Thread unarchiving');

  @override
  Future<ThreadSummary> forkThread(ThreadForkOptions options) =>
      _unsupported('Thread forking');

  @override
  Future<ThreadSummary> revertThread({
    required String threadId,
    required String beforeTurnId,
  }) => _unsupported('Thread revert');

  @override
  Future<void> compactThread(String threadId) =>
      _unsupported('Thread compaction');

  @override
  Future<void> deleteThread(String threadId) => _unsupported('Thread deletion');

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) =>
      _unsupported('Turn start');

  @override
  Future<String> steerTurn(TurnSteerOptions options) =>
      _unsupported('Turn steering');

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) => _unsupported('Turn interruption');

  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) => _unsupported('Approval decisions');

  @override
  Future<OutputDescriptor> statOutput(String reference) =>
      _unsupported('Remote output reads');

  @override
  Future<OutputChunk> readOutputRange({
    required String reference,
    required int offset,
    required int length,
  }) => _unsupported('Remote output reads');

  @override
  Future<OutputChunk> readOutputTail({
    required String reference,
    required int length,
  }) => _unsupported('Remote output reads');

  @override
  Future<List<SkillSummary>> listSkills({List<String> cwds = const []}) =>
      Future.value(const []);

  @override
  Future<bool> setSkillEnabled({required String path, required bool enabled}) =>
      _unsupported('Skill configuration');

  @override
  Future<List<PluginSummaryModel>> listPlugins({
    List<String> cwds = const [],
  }) => Future.value(const []);

  @override
  Future<List<McpServerStatusModel>> listMcpServerStatus() =>
      Future.value(const []);

  @override
  Future<OfficialRemoteControlStatus> readOfficialRemoteControlStatus() =>
      Future.value(
        const OfficialRemoteControlStatus(
          supported: false,
          errorMessage: 'Not available while connected as a remote client.',
        ),
      );

  @override
  Future<OfficialRemoteControlStatus> setOfficialRemoteControlEnabled(
    bool enabled,
  ) => _unsupported('Official Remote Control administration');

  @override
  Future<OfficialRemoteControlPairing> startOfficialRemoteControlPairing() =>
      _unsupported('Official Remote Control pairing');

  @override
  Future<bool> disconnectOfficialRemoteControlClient(
    String clientId, {
    String? environmentId,
  }) => _unsupported('Official Remote Control administration');

  Future<T> _unsupported<T>(String operation) => Future.error(
    UnsupportedError('$operation is not available on read-only Remote.'),
  );

  Future<JsonObject> _request(
    String method, [
    JsonObject params = const {},
  ]) async {
    if (_closing) {
      throw const TransportClosedException();
    }
    if (method.isEmpty || method.length > 128) {
      throw ArgumentError.value(method, 'method', 'Invalid Remote RPC method.');
    }
    if (_pending.length >= _maxPendingRequests) {
      throw StateError('Remote pending-request limit reached.');
    }
    if (_nextRequestId > _maxRequestId) {
      throw StateError('Remote request identifier space exhausted.');
    }
    _ensureReader();
    final id = _nextRequestId++;
    final completer = Completer<JsonObject>();
    final timer = Timer(requestTimeout, () {
      final pending = _pending.remove(id);
      if (pending == null) {
        return;
      }
      pending.completer.completeError(
        TimeoutException('Remote RPC timed out.', requestTimeout),
      );
      unawaited(
        _finish(
          const TransportClosedException('Remote RPC timed out.'),
          kind: RemoteTransportCloseKind.failed,
          closeSocket: true,
          closeCode: WebSocketStatus.policyViolation,
          closeReason: 'Remote RPC timed out',
        ),
      );
    });
    _pending[id] = _PendingRequest(completer, timer);
    try {
      await _sendBounded(_socket, {
        'type': 'rpc',
        'id': id,
        'method': method,
        'params': params,
      });
    } catch (error, stackTrace) {
      final pending = _pending.remove(id);
      pending?.timer.cancel();
      pending?.completer.completeError(error, stackTrace);
    }
    return completer.future;
  }

  void _ensureReader() {
    _reader ??= _readLoop();
  }

  Future<void> _readLoop() async {
    Object terminal = const TransportClosedException(
      'Remote WebSocket closed.',
    );
    var closeSocket = false;
    var closeCode = WebSocketStatus.normalClosure;
    var closeReason = 'Remote WebSocket closed';
    var closeKind = RemoteTransportCloseKind.peer;
    try {
      while (!_closing && await _input.moveNext()) {
        await _handleMessage(_input.current);
      }
      if (!_closing && _socket.closeCode != WebSocketStatus.normalClosure) {
        terminal = TransportClosedException(
          'Remote WebSocket closed with code ${_socket.closeCode ?? 'unknown'}.',
        );
        if (!_protocolErrors.isClosed) {
          _protocolErrors.add(
            ProtocolViolation(
              'Remote transport closed unexpectedly.',
              terminal,
            ),
          );
        }
      }
    } catch (error) {
      terminal = error;
      if (error is ProtocolViolation && !_protocolErrors.isClosed) {
        closeKind = RemoteTransportCloseKind.protocolViolation;
        _protocolErrors.add(error);
        closeSocket = true;
        closeCode = WebSocketStatus.protocolError;
        closeReason = 'Remote protocol violation';
      }
      if (error is! RemoteResyncRequired &&
          error is! ProtocolViolation &&
          !_protocolErrors.isClosed) {
        closeKind = RemoteTransportCloseKind.failed;
        _protocolErrors.add(
          ProtocolViolation('Remote transport failed.', error),
        );
        closeSocket = true;
        closeCode = WebSocketStatus.internalServerError;
        closeReason = 'Remote transport failed';
      }
      if (error is RemoteResyncRequired) {
        closeKind = RemoteTransportCloseKind.resyncRequired;
        closeSocket = true;
        closeCode = WebSocketStatus.policyViolation;
        closeReason = 'Authoritative resync required';
      }
    } finally {
      if (_socket.closeCode == WebSocketStatus.policyViolation &&
          _socket.closeReason == 'device credential revoked') {
        closeKind = RemoteTransportCloseKind.credentialRevoked;
      }
      unawaited(
        _finish(
          terminal,
          kind: closeKind,
          closeSocket: closeSocket,
          closeCode: closeCode,
          closeReason: closeReason,
        ),
      );
    }
  }

  Future<void> _handleMessage(Object? wireMessage) async {
    final decoded = _decodeMessage(wireMessage);
    switch (decoded['type']) {
      case 'rpc_result':
        _completeResult(decoded);
      case 'rpc_error':
        _completeError(decoded);
      case 'codex_event':
        await _handleEvent(decoded, wireMessage as String);
      case 'resync_required':
        final sessionId = _requiredString(decoded, 'sessionId', maxLength: 128);
        final sequence = _requiredSequence(decoded, 'sequence');
        if (sessionId != handshake.sessionId || sequence < _lastSequence) {
          throw const ProtocolViolation(
            'Remote resync marker is inconsistent with this session.',
          );
        }
        final resync = RemoteResyncRequired(
          sessionId: sessionId,
          sequence: sequence,
          reason: _requiredString(decoded, 'reason', maxLength: 512),
        );
        _markRequiresResync(resync);
        throw resync;
      case 'protocol_error':
        throw ProtocolViolation(
          'Remote Host rejected the protocol: '
          '${_requiredString(decoded, 'error', maxLength: 512)}',
        );
      default:
        throw const ProtocolViolation('Unknown Remote message type.');
    }
  }

  void _completeResult(JsonObject message) {
    final result = message['result'];
    final JsonObject normalized;
    if (result == null) {
      normalized = const {};
    } else if (result is Map<String, Object?>) {
      normalized = result;
    } else {
      throw const ProtocolViolation(
        'Remote RPC result must be an object or null.',
      );
    }
    final pending = _takePending(message['id']);
    pending.completer.complete(normalized);
  }

  void _completeError(JsonObject message) {
    final error = message['error'];
    if (error is! Map<String, Object?>) {
      throw const ProtocolViolation('Remote RPC error must be an object.');
    }
    final code = error['code'];
    final errorMessage = error['message'];
    if (code is! int ||
        errorMessage is! String ||
        errorMessage.isEmpty ||
        errorMessage.length > 4096) {
      throw const ProtocolViolation(
        'Remote RPC error has an invalid code or message.',
      );
    }
    final pending = _takePending(message['id']);
    pending.completer.completeError(
      JsonRpcException(code: code, message: errorMessage, data: error['data']),
    );
  }

  _PendingRequest _takePending(Object? id) {
    if (id is! int) {
      throw const ProtocolViolation(
        'Remote RPC response ID must be an integer.',
      );
    }
    final pending = _pending.remove(id);
    if (pending == null) {
      throw ProtocolViolation('Remote RPC response has unknown ID $id.');
    }
    pending.timer.cancel();
    return pending;
  }

  Future<void> _handleEvent(JsonObject message, String encoded) async {
    final sequence = _requiredSequence(message, 'sequence');
    final expected = _lastSequence + 1;
    if (sequence != expected) {
      throw ProtocolViolation(
        'Remote event sequence gap: expected $expected, received $sequence.',
      );
    }
    final method = _requiredString(message, 'method', maxLength: 128);
    if (!_eventMethods.contains(method)) {
      throw ProtocolViolation('Remote event method is not supported: $method.');
    }
    final paramsValue = message['params'];
    final params = paramsValue == null
        ? const <String, Object?>{}
        : paramsValue is Map<String, Object?>
        ? paramsValue
        : throw const ProtocolViolation(
            'Remote event params must be an object or null.',
          );
    final notification = CodexNotification(method: method, params: params);
    _lastSequence = sequence;
    if (method == 'host/resyncRequired') {
      _markRequiresResync(
        RemoteResyncRequired(
          sessionId: handshake.sessionId,
          sequence: sequence,
          reason: 'Remote event payload requires authoritative resync.',
        ),
      );
    } else {
      _deliverOrBuffer(
        RemoteSequencedNotification(
          sessionId: handshake.sessionId,
          sequence: sequence,
          notification: notification,
        ),
        utf8.encode(encoded).length,
      );
    }
    if (!_requiresResync) {
      _durableCursor = RemoteResumeCursor(
        sessionId: handshake.sessionId,
        sequence: sequence,
      );
    }
    await _sendBounded(_socket, {'type': 'ack', 'sequence': sequence});
  }

  void _deliverOrBuffer(RemoteSequencedNotification event, int bytes) {
    if (!_requiresResync &&
        (_notifications.hasListener || _sequencedNotifications.hasListener)) {
      if (_notifications.hasListener) {
        _notifications.add(event.notification);
      }
      if (_sequencedNotifications.hasListener) {
        _sequencedNotifications.add(event);
      }
      return;
    }
    if (_bufferedEvents.length >= _maxBufferedEvents ||
        bytes > _maxBufferedEventBytes - _bufferedEventBytes) {
      _bufferedEvents.clear();
      _bufferedEventBytes = 0;
      _markRequiresResync(
        RemoteResyncRequired(
          sessionId: handshake.sessionId,
          sequence: _lastSequence,
          reason: 'Remote client event buffer was exhausted.',
        ),
      );
      return;
    }
    _bufferedEvents.add(_BufferedEvent(event, bytes));
    _bufferedEventBytes += bytes;
  }

  void _drainBufferedEvents() {
    if (_requiresResync ||
        (!_notifications.hasListener && !_sequencedNotifications.hasListener)) {
      return;
    }
    while (_bufferedEvents.isNotEmpty && !_notifications.isClosed) {
      final event = _bufferedEvents.removeFirst();
      _bufferedEventBytes -= event.bytes;
      if (_notifications.hasListener) {
        _notifications.add(event.value.notification);
      }
      if (_sequencedNotifications.hasListener) {
        _sequencedNotifications.add(event.value);
      }
    }
  }

  void _markRequiresResync(RemoteResyncRequired event) {
    _requiresResync = true;
    _resyncGeneration += 1;
    _durableCursor = null;
    if (!_resyncEvents.isClosed) {
      _resyncEvents.add(event);
    }
  }

  @override
  Future<void> close() => _finish(
    const TransportClosedException(),
    kind: RemoteTransportCloseKind.local,
    closeSocket: true,
    closeCode: WebSocketStatus.normalClosure,
    closeReason: 'Client closing',
  );

  Future<void> _finish(
    Object cause, {
    required RemoteTransportCloseKind kind,
    required bool closeSocket,
    int? closeCode,
    String? closeReason,
  }) => _finishOperation ??= () async {
    _closing = true;
    for (final pending in _pending.values) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(cause);
      }
    }
    _pending.clear();
    try {
      await _input.cancel();
    } on Object {
      // Continue closing the socket and public streams.
    }
    if (closeSocket) {
      try {
        await _socket.close(closeCode, closeReason);
      } on Object {
        // The peer may already have closed while this side was finishing.
      }
    }
    try {
      await Future.wait([
        _notifications.close(),
        _sequencedNotifications.close(),
        _protocolErrors.close(),
        _resyncEvents.close(),
      ]);
    } finally {
      if (!_closed.isCompleted) {
        _closed.complete(
          RemoteTransportClose(
            kind: kind,
            code: _socket.closeCode ?? closeCode,
          ),
        );
      }
    }
  }();
}

final class _PendingRequest {
  const _PendingRequest(this.completer, this.timer);

  final Completer<JsonObject> completer;
  final Timer timer;
}

final class _BufferedEvent {
  const _BufferedEvent(this.value, this.bytes);

  final RemoteSequencedNotification value;
  final int bytes;
}

Future<JsonObject> _nextHandshakeMessage(
  StreamIterator<Object?> input,
  Duration timeout,
  String expectedType,
) async {
  final hasMessage = await input.moveNext().timeout(timeout);
  if (!hasMessage) {
    throw const TransportClosedException('Remote closed during negotiation.');
  }
  final message = _decodeMessage(input.current);
  if (message['type'] != expectedType) {
    throw ProtocolViolation('Expected Remote $expectedType.');
  }
  return message;
}

JsonObject _decodeMessage(Object? wireMessage) {
  if (wireMessage is! String) {
    throw const ProtocolViolation('Remote messages must be UTF-8 JSON text.');
  }
  if (wireMessage.length > remoteMaxMessageBytes ||
      utf8.encode(wireMessage).length > remoteMaxMessageBytes) {
    throw const ProtocolViolation('Remote message exceeds the bounded limit.');
  }
  try {
    final decoded = jsonDecode(wireMessage);
    if (decoded is! Map<String, Object?>) {
      throw const ProtocolViolation('Remote message must be a JSON object.');
    }
    return decoded;
  } on FormatException catch (error) {
    throw ProtocolViolation('Remote message is not valid JSON.', error);
  }
}

Future<void> _sendBounded(RemoteSocket socket, JsonObject message) async {
  final encoded = jsonEncode(message);
  if (utf8.encode(encoded).length > remoteMaxMessageBytes) {
    throw const ProtocolViolation('Remote outbound message exceeds the limit.');
  }
  await socket.sendText(encoded);
}

bool _hasRequiredCapabilities(Set<String> capabilities) =>
    capabilities.containsAll(_requiredCapabilities);

JsonObject _requiredObject(JsonObject object, String key) {
  final value = object[key];
  if (value is! Map<String, Object?>) {
    throw ProtocolViolation('Remote field $key must be an object.');
  }
  return value;
}

String _requiredString(
  JsonObject object,
  String key, {
  required int maxLength,
}) {
  final value = object[key];
  if (value is! String || value.isEmpty || value.length > maxLength) {
    throw ProtocolViolation('Remote field $key must be a bounded string.');
  }
  return value;
}

int _requiredInt(JsonObject object, String key) {
  final value = object[key];
  if (value is! int) {
    throw ProtocolViolation('Remote field $key must be an integer.');
  }
  return value;
}

int _requiredSequence(JsonObject object, String key) {
  final value = _requiredInt(object, key);
  if (value < 0) {
    throw ProtocolViolation('Remote field $key must be non-negative.');
  }
  return value;
}

bool _requiredBool(JsonObject object, String key) {
  final value = object[key];
  if (value is! bool) {
    throw ProtocolViolation('Remote field $key must be a boolean.');
  }
  return value;
}

List<int> _requiredIntList(JsonObject object, String key) {
  final value = object[key];
  if (value is! List<Object?> ||
      value.length > 16 ||
      value.any((item) => item is! int || item < 0)) {
    throw ProtocolViolation(
      'Remote field $key must be a bounded non-negative integer array.',
    );
  }
  return value.cast<int>();
}

Set<String> _requiredStringSet(JsonObject object, String key) {
  final value = object[key];
  if (value is! List<Object?> ||
      value.length > 32 ||
      value.any(
        (item) => item is! String || item.isEmpty || item.length > 64,
      )) {
    throw ProtocolViolation(
      'Remote field $key must be a bounded string array.',
    );
  }
  return value.cast<String>().toSet();
}
