import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_protocol.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_socket.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_transport.dart';
import 'package:flutter_test/flutter_test.dart';

const _credential = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _sessionId = 'host-session';
const _capabilities = ['ack', 'eventReplay', 'readOnlyCodex'];

void main() {
  late List<RemoteTransport> transports;
  late List<_FakeRemoteSocket> sockets;

  setUp(() {
    transports = [];
    sockets = [];
  });

  tearDown(() async {
    for (final transport in transports) {
      await transport.close();
    }
    for (final socket in sockets) {
      await socket.dispose();
    }
  });

  test('requires WSS except for an explicit literal loopback opt-in', () async {
    var connectorCalls = 0;
    Future<RemoteSocket> connector(Uri endpoint, String credential) async {
      connectorCalls += 1;
      throw StateError('Connector must not run for invalid configuration.');
    }

    await expectLater(
      RemoteTransport.connect(
        endpoint: Uri.parse('ws://host.example/v1/ws'),
        credential: _credential,
        connector: connector,
      ),
      throwsArgumentError,
    );
    await expectLater(
      RemoteTransport.connect(
        endpoint: Uri.parse('ws://localhost/v1/ws'),
        credential: _credential,
        connector: connector,
        allowInsecureLoopback: true,
      ),
      throwsArgumentError,
    );
    await expectLater(
      RemoteTransport.connect(
        endpoint: Uri.parse('wss://host.example/v1/ws?token=forbidden'),
        credential: _credential,
        connector: connector,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.toString(),
          'redacted message',
          isNot(contains('forbidden')),
        ),
      ),
    );
    await expectLater(
      RemoteTransport.connect(
        endpoint: Uri.parse('wss://host.example/v1/ws'),
        credential: 'not-a-credential',
        connector: connector,
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      RemoteTransport.connect(
        endpoint: Uri.parse('wss://host.example/v1/ws'),
        credential: _credential,
        resumeCursor: RemoteResumeCursor(
          sessionId: List.filled(129, 'x').join(),
          sequence: 0,
        ),
        connector: connector,
      ),
      throwsArgumentError,
    );
    expect(connectorCalls, 0);

    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(
      socket,
      endpoint: Uri.parse('ws://127.0.0.1:8765/v1/ws'),
      allowInsecureLoopback: true,
    );
    transports.add(transport);
    expect(transport.handshake.sessionId, _sessionId);
  });

  test('closes a socket that arrives after the connection deadline', () async {
    final lateSocket = _FakeRemoteSocket();
    sockets.add(lateSocket);
    final connector = Completer<RemoteSocket>();

    await expectLater(
      RemoteTransport.connect(
        endpoint: Uri.parse('wss://host.example/v1/ws'),
        credential: _credential,
        connector: (_, _) => connector.future,
        handshakeTimeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<TimeoutException>()),
    );
    connector.complete(lateSocket);

    await lateSocket.done;
    expect(lateSocket.closeCode, WebSocketStatus.goingAway);
    expect(lateSocket.closeReason, 'Remote connection attempt expired');
  });

  test('fails negotiation when the WebSocket subprotocol is absent', () async {
    final socket = _FakeRemoteSocket()..protocol = null;
    sockets.add(socket);

    await expectLater(
      RemoteTransport.connect(
        endpoint: Uri.parse('wss://host.example/v1/ws'),
        credential: _credential,
        connector: (_, _) async => socket,
      ),
      throwsA(isA<ProtocolViolation>()),
    );

    expect(socket.closeCode, WebSocketStatus.protocolError);
    expect(socket.closeReason, 'Remote handshake failed');
  });

  test(
    'performs the exact negotiation and gates initial events on resync',
    () async {
      final socket = _FakeRemoteSocket();
      sockets.add(socket);
      final transport = await _connect(socket, serverSequence: 5);
      transports.add(transport);

      expect(socket.jsonWrites.single, {
        'type': 'client_hello',
        'supportedProtocolVersions': [1],
      });
      expect(transport.handshake.requiresResync, isTrue);
      expect(transport.requiresResync, isTrue);
      expect(transport.resyncGeneration, 1);
      expect(transport.resumeCursor, isNull);

      final received = <CodexNotification>[];
      final subscription = transport.notifications.listen(received.add);
      socket.addJson({
        'type': 'codex_event',
        'sequence': 6,
        'method': 'thread/status/changed',
        'params': {
          'threadId': 'thread-1',
          'status': {'type': 'active'},
        },
      });
      await _waitFor(
        () => socket.jsonWrites.any(
          (message) => message['type'] == 'ack' && message['sequence'] == 6,
        ),
      );

      expect(received, isEmpty);
      expect(transport.resumeCursor, isNull);
      transport.completeResync(generation: 1);
      expect(received.single.method, 'thread/status/changed');
      expect(
        transport.resumeCursor,
        const RemoteResumeCursor(sessionId: _sessionId, sequence: 6),
      );
      await subscription.cancel();
    },
  );

  test(
    'replays an exact same-session suffix and advances ACK cursor',
    () async {
      final socket = _FakeRemoteSocket();
      sockets.add(socket);
      final transport = await _connect(
        socket,
        serverSequence: 7,
        resumeCursor: const RemoteResumeCursor(
          sessionId: _sessionId,
          sequence: 5,
        ),
      );
      transports.add(transport);

      expect(socket.jsonWrites.single, {
        'type': 'client_hello',
        'supportedProtocolVersions': [1],
        'lastSessionId': _sessionId,
        'lastSequence': 5,
      });
      expect(transport.requiresResync, isFalse);
      expect(
        transport.resumeCursor,
        const RemoteResumeCursor(sessionId: _sessionId, sequence: 5),
      );

      final events = transport.notifications.take(2).toList();
      socket
        ..addJson({
          'type': 'codex_event',
          'sequence': 6,
          'method': 'turn/started',
          'params': {'threadId': 'thread-1', 'turnId': 'turn-1'},
        })
        ..addJson({
          'type': 'codex_event',
          'sequence': 7,
          'method': 'turn/completed',
          'params': {'threadId': 'thread-1', 'turnId': 'turn-1'},
        });

      expect((await events).map((event) => event.method), [
        'turn/started',
        'turn/completed',
      ]);
      await _waitFor(() => _acks(socket).length == 2);
      expect(_acks(socket), [6, 7]);
      expect(
        transport.resumeCursor,
        const RemoteResumeCursor(sessionId: _sessionId, sequence: 7),
      );
    },
  );

  test(
    'exposes applied event sequences and a redacted revoked close',
    () async {
      final socket = _FakeRemoteSocket();
      sockets.add(socket);
      final transport = await _connect(socket);
      transports.add(transport);
      transport.completeResync(generation: transport.resyncGeneration);

      final eventFuture = transport.sequencedNotifications.first;
      socket.addJson({
        'type': 'codex_event',
        'sequence': 1,
        'method': 'thread/status/changed',
        'params': {'threadId': 'thread-1', 'status': 'active'},
      });

      final event = await eventFuture;
      expect(event.sessionId, _sessionId);
      expect(event.sequence, 1);
      expect(event.notification.method, 'thread/status/changed');
      await _waitFor(() => _acks(socket).contains(1));

      socket.finishPeer(
        WebSocketStatus.policyViolation,
        reason: 'device credential revoked',
      );
      final close = await transport.closed;
      expect(close.kind, RemoteTransportCloseKind.credentialRevoked);
      expect(close.code, WebSocketStatus.policyViolation);
      expect(close.toString(), isNot(contains('credential')));
    },
  );

  test('correlates typed RPC results that arrive out of order', () async {
    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(socket);
    transports.add(transport);

    final modelsFuture = transport.listModels(const ModelListQuery(limit: 10));
    final threadsFuture = transport.listThreads(
      const ThreadListQuery(limit: 12),
    );
    await _waitFor(() => _rpcWrites(socket).length == 2);
    final requests = {
      for (final request in _rpcWrites(socket)) request['method']: request,
    };

    socket.addJson({
      'type': 'rpc_result',
      'id': requests['thread/list']!['id'],
      'result': {
        'data': [_threadJson('thread-1')],
        'nextCursor': 'next-page',
      },
    });
    socket.addJson({
      'type': 'rpc_result',
      'id': requests['model/list']!['id'],
      'result': {
        'data': [_modelJson()],
        'nextCursor': null,
      },
    });

    final threads = await threadsFuture;
    final models = await modelsFuture;
    expect(threads.threads.single.id, 'thread-1');
    expect(threads.nextCursor, 'next-page');
    expect(models.models.single.model, 'gpt-test');
    expect(requests['thread/list']!['params'], {
      'limit': 12,
      'sortKey': 'recency_at',
      'sortDirection': 'desc',
      'archived': false,
    });
    expect(requests['model/list']!['params'], {
      'limit': 10,
      'includeHidden': false,
    });
  });

  test('validates Remote status before reporting initialization', () async {
    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(socket);
    transports.add(transport);

    final initialized = transport.initialize(const InitializeRequest());
    await _waitFor(() => _rpcWrites(socket).length == 1);
    final request = _rpcWrites(socket).single;
    expect(request['method'], 'host/remote/status');
    expect(request['params'], isEmpty);
    socket.addJson({
      'type': 'rpc_result',
      'id': request['id'],
      'result': {
        'sessionId': _sessionId,
        'device': {'id': 'device-1', 'name': 'Test phone'},
        'mode': 'readOnlyCodex',
      },
    });

    expect((await initialized).userAgent, 'Codex Native Remote');
  });

  test('rejects every unavailable write before sending it', () async {
    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(socket);
    transports.add(transport);
    final writesBefore = socket.writes.length;

    await expectLater(
      transport.startThread(const ThreadStartOptions(cwd: '/workspace')),
      throwsUnsupportedError,
    );
    await expectLater(
      transport.decideApproval(
        requestId: 1,
        decision: ApprovalDecision.approveOnce,
      ),
      throwsUnsupportedError,
    );

    expect(socket.writes.length, writesBefore);
  });

  test('fails closed on an event sequence gap', () async {
    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(socket, serverSequence: 5);
    transports.add(transport);
    final errorFuture = transport.protocolErrors.first;

    socket.addJson({
      'type': 'codex_event',
      'sequence': 7,
      'method': 'error',
      'params': {'message': 'test'},
    });

    final error = await errorFuture;
    expect(error.message, contains('sequence gap'));
    await socket.done;
    expect(socket.closeCode, WebSocketStatus.protocolError);
    expect(socket.closeReason, 'Remote protocol violation');
  });

  test('rejects binary WebSocket messages without decoding them', () async {
    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(socket);
    transports.add(transport);
    final errorFuture = transport.protocolErrors.first;

    socket.addRaw(<int>[0x7b, 0x7d]);

    expect((await errorFuture).message, contains('JSON text'));
    await socket.done;
    expect(socket.closeCode, WebSocketStatus.protocolError);
  });

  test('surfaces an abnormal peer close as a protocol error', () async {
    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(socket);
    transports.add(transport);
    final errorFuture = transport.protocolErrors.first;

    socket.finishPeer(WebSocketStatus.protocolError);

    final error = await errorFuture;
    expect(error.message, 'Remote transport closed unexpectedly.');
    expect(error.cause, isA<TransportClosedException>());
  });

  test('fails the whole connection on a malformed RPC result', () async {
    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(socket);
    transports.add(transport);

    final requestFuture = transport.listModels(const ModelListQuery());
    await _waitFor(() => _rpcWrites(socket).length == 1);
    final errorFuture = transport.protocolErrors.first;
    socket.addJson({
      'type': 'rpc_result',
      'id': _rpcWrites(socket).single['id'],
      'result': <Object?>[],
    });

    await expectLater(requestFuture, throwsA(isA<ProtocolViolation>()));
    expect((await errorFuture).message, contains('result'));
    await socket.done;
    expect(socket.closeCode, WebSocketStatus.protocolError);
  });

  test(
    'invalidates the cursor and closes on explicit resync_required',
    () async {
      final socket = _FakeRemoteSocket();
      sockets.add(socket);
      final transport = await _connect(socket, serverSequence: 5);
      transports.add(transport);
      transport.completeResync(generation: transport.resyncGeneration);
      final resyncFuture = transport.resyncEvents.first;

      socket.addJson({
        'type': 'resync_required',
        'sessionId': _sessionId,
        'sequence': 6,
        'reason': 'live event receiver lagged',
      });

      final event = await resyncFuture;
      expect(event.sequence, 6);
      expect(transport.requiresResync, isTrue);
      expect(transport.resumeCursor, isNull);
      await socket.done;
      expect(socket.closeCode, WebSocketStatus.policyViolation);
    },
  );

  test(
    'buffer exhaustion invalidates an in-flight resync generation',
    () async {
      final socket = _FakeRemoteSocket();
      sockets.add(socket);
      final transport = await _connect(socket, serverSequence: 0);
      transports.add(transport);
      final initialGeneration = transport.resyncGeneration;
      final invalidated = transport.resyncEvents.first;

      for (var sequence = 1; sequence <= 513; sequence += 1) {
        socket.addJson({
          'type': 'codex_event',
          'sequence': sequence,
          'method': 'thread/status/changed',
          'params': {'threadId': 'thread-$sequence'},
        });
      }
      await _waitFor(() => _acks(socket).length == 513);

      expect((await invalidated).reason, contains('buffer'));
      expect(transport.resyncGeneration, initialGeneration + 1);
      expect(
        () => transport.completeResync(generation: initialGeneration),
        throwsStateError,
      );
      transport.completeResync(generation: transport.resyncGeneration);
      expect(
        transport.resumeCursor,
        const RemoteResumeCursor(sessionId: _sessionId, sequence: 513),
      );
    },
  );

  test('times out one ambiguous RPC and closes the connection', () async {
    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(
      socket,
      requestTimeout: const Duration(milliseconds: 20),
    );
    transports.add(transport);

    await expectLater(
      transport.listModels(const ModelListQuery()),
      throwsA(isA<TimeoutException>()),
    );
    await socket.done;
    expect(socket.closeCode, WebSocketStatus.policyViolation);
    expect(socket.closeReason, 'Remote RPC timed out');
  });

  test('coalesces concurrent close requests', () async {
    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(socket);
    transports.add(transport);

    await Future.wait([
      transport.close(),
      transport.close(),
      transport.close(),
    ]);

    expect(socket.closeCalls, 1);
    expect(socket.closeCode, WebSocketStatus.normalClosure);
  });

  test('supports bounded remote history pagination (listHistoryTurns, listHistoryItems, readHistoryItems) and thread lifecycle events', () async {
    final socket = _FakeRemoteSocket();
    sockets.add(socket);
    final transport = await _connect(socket);
    transports.add(transport);
    transport.completeResync(generation: transport.resyncGeneration);

    final turnsFuture = transport.listHistoryTurns(
      const HistoryTurnQuery(threadId: 'thread-1', limit: 10),
    );
    final itemsFuture = transport.listHistoryItems(
      const HistoryItemQuery(threadId: 'thread-1', turnId: 'turn-1', limit: 25),
    );
    final readFuture = transport.readHistoryItems(
      threadId: 'thread-1',
      turnId: 'turn-1',
      itemIds: const ['item-1'],
    );
    await _waitFor(() => _rpcWrites(socket).length == 3);
    final rpcs = {
      for (final req in _rpcWrites(socket)) req['method'] as String: req,
    };

    expect(rpcs['thread/turns/list']!['params'], {
      'threadId': 'thread-1',
      'limit': 10,
      'sortDirection': 'desc',
      'itemsView': 'summary',
    });
    expect(rpcs['thread/items/list']!['params'], {
      'threadId': 'thread-1',
      'turnId': 'turn-1',
      'limit': 25,
      'sortDirection': 'asc',
      'deferOutput': {'commandExecution': true},
    });
    expect(rpcs['thread/items/read']!['params'], {
      'threadId': 'thread-1',
      'turnId': 'turn-1',
      'itemIds': ['item-1'],
    });

    socket
      ..addJson({
        'type': 'rpc_result',
        'id': rpcs['thread/turns/list']!['id'],
        'result': {
          'data': [
            {
              'id': 'turn-1',
              'status': 'completed',
              'itemsView': 'summary',
              'items': [
                {
                  'id': 'user-1',
                  'type': 'userMessage',
                  'content': [
                    {'type': 'text', 'text': 'Remote history prompt'},
                  ],
                },
              ],
            },
          ],
          'nextCursor': null,
        },
      })
      ..addJson({
        'type': 'rpc_result',
        'id': rpcs['thread/items/list']!['id'],
        'result': {
          'data': [
            {
              'turnId': 'turn-1',
              'item': {
                'id': 'item-1',
                'type': 'agentMessage',
                'text': 'Remote assistant reply',
              },
            },
          ],
          'nextCursor': null,
        },
      })
      ..addJson({
        'type': 'rpc_result',
        'id': rpcs['thread/items/read']!['id'],
        'result': {
          'data': [
            {
              'turnId': 'turn-1',
              'item': {
                'id': 'item-1',
                'type': 'agentMessage',
                'text': 'Remote assistant reply',
              },
            },
          ],
        },
      });

    final turnsPage = await turnsFuture;
    final itemsPage = await itemsFuture;
    final readItems = await readFuture;

    expect(turnsPage.turns.single.items.single.text, 'Remote history prompt');
    expect(itemsPage.items.single.text, 'Remote assistant reply');
    expect(readItems.single.text, 'Remote assistant reply');

    final lifecycleEvents = <ThreadLifecycleEvent>[];
    final sub = transport.threadEvents.listen(lifecycleEvents.add);
    addTearDown(sub.cancel);

    socket.addJson({
      'type': 'codex_event',
      'sequence': 1,
      'method': 'thread/name/updated',
      'params': {'threadId': 'thread-1', 'name': 'Renamed Remotely'},
    });
    await _waitFor(() => lifecycleEvents.isNotEmpty);
    expect(
      lifecycleEvents.single,
      isA<ThreadNameUpdatedEvent>().having(
        (e) => e.threadName,
        'threadName',
        'Renamed Remotely',
      ),
    );
  });
}

Future<RemoteTransport> _connect(
  _FakeRemoteSocket socket, {
  Uri? endpoint,
  bool allowInsecureLoopback = false,
  int serverSequence = 0,
  RemoteResumeCursor? resumeCursor,
  Duration requestTimeout = const Duration(seconds: 1),
}) async {
  final connecting = RemoteTransport.connect(
    endpoint: endpoint ?? Uri.parse('wss://host.example/v1/ws'),
    credential: _credential,
    resumeCursor: resumeCursor,
    connector: (_, _) async => socket,
    allowInsecureLoopback: allowInsecureLoopback,
    requestTimeout: requestTimeout,
  );
  socket.addJson({
    'type': 'server_hello',
    'minProtocolVersion': 1,
    'maxProtocolVersion': 1,
    'supportedProtocolVersions': [1],
    'sessionId': _sessionId,
    'sequence': serverSequence,
    'capabilities': _capabilities,
  });
  await _waitFor(() => socket.writes.length == 1);
  socket.addJson({
    'type': 'hello_ack',
    'protocolVersion': 1,
    'sessionId': _sessionId,
    'sequence': serverSequence,
    'replayAvailable': true,
    'resyncRequired': false,
    'capabilities': _capabilities,
  });
  return connecting;
}

List<Map<String, Object?>> _rpcWrites(_FakeRemoteSocket socket) => socket
    .jsonWrites
    .where((message) => message['type'] == 'rpc')
    .toList(growable: false);

List<int> _acks(_FakeRemoteSocket socket) => socket.jsonWrites
    .where((message) => message['type'] == 'ack')
    .map((message) => message['sequence']! as int)
    .toList(growable: false);

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 1000; attempt += 1) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition did not become true before the test deadline.');
}

Map<String, Object?> _modelJson() => {
  'id': 'model-id',
  'model': 'gpt-test',
  'displayName': 'Test model',
  'description': 'A test model',
  'isDefault': true,
  'defaultReasoningEffort': 'medium',
  'supportedReasoningEfforts': [
    {'reasoningEffort': 'medium', 'description': 'Balanced'},
  ],
};

Map<String, Object?> _threadJson(String id) => {
  'id': id,
  'sessionId': 'session-$id',
  'preview': 'Test thread',
  'cwd': '/workspace',
  'createdAt': 1730000000,
  'updatedAt': 1730000100,
  'status': {'type': 'idle'},
  'ephemeral': false,
  'name': null,
  'model': 'gpt-test',
  'projectId': null,
  'turns': <Object?>[],
};

final class _FakeRemoteSocket implements RemoteSocket {
  final StreamController<Object?> _messages = StreamController<Object?>();
  final Completer<void> _done = Completer<void>();
  final List<String> writes = [];
  var closeCalls = 0;

  @override
  String? protocol = remoteWebSocketProtocol;

  @override
  int? closeCode;

  @override
  String? closeReason;

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  Future<void> get done => _done.future;

  List<Map<String, Object?>> get jsonWrites => writes
      .map((message) => jsonDecode(message) as Map<String, Object?>)
      .toList(growable: false);

  void addJson(Map<String, Object?> message) {
    if (_messages.isClosed) {
      throw StateError('Fake socket is closed.');
    }
    _messages.add(jsonEncode(message));
  }

  void addRaw(Object? message) {
    if (_messages.isClosed) {
      throw StateError('Fake socket is closed.');
    }
    _messages.add(message);
  }

  void finishPeer(int code, {String? reason}) {
    closeCode = code;
    closeReason = reason;
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> sendText(String message) async {
    if (_messages.isClosed) {
      throw const WebSocketException('Fake socket is closed.');
    }
    writes.add(message);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closeCalls += 1;
    closeCode ??= code;
    closeReason ??= reason;
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  Future<void> dispose() => close();
}
