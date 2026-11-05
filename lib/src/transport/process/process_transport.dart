import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/approval_models.dart';
import '../../domain/history_models.dart';
import '../../domain/model_models.dart';
import '../../domain/output_models.dart';
import '../../domain/thread_models.dart';
import '../../domain/turn_models.dart';
import '../../protocol/approval_protocol.dart';
import '../../protocol/history_protocol.dart';
import '../../protocol/json_rpc_peer.dart';
import '../../protocol/jsonl_decoder.dart';
import '../../protocol/model_protocol.dart';
import '../../protocol/output_protocol.dart';
import '../../protocol/protocol_models.dart';
import '../../protocol/thread_protocol.dart';
import '../../protocol/turn_protocol.dart';
import '../codex_transport.dart';
import 'child_process.dart';

class ProcessExit {
  const ProcessExit({required this.code, required this.stderrTail});

  final int code;
  final String stderrTail;
}

class ProcessTransport implements CodexTransport {
  ProcessTransport._({
    required this.executablePath,
    required ChildProcess process,
    required this.shutdownTimeout,
    required this.stderrTailLimit,
  }) : _process = process,
       assert(stderrTailLimit > 0) {
    _peer = JsonRpcPeer(
      input: process.stdout.transform(const JsonlDecoder()),
      writer: process.write,
    );
    _threadProtocol = ThreadProtocolAdapter(request: _peer.request);
    _historyProtocol = HistoryProtocolAdapter(request: _peer.request);
    _modelProtocol = ModelProtocolAdapter(request: _peer.request);
    _outputProtocol = OutputProtocolAdapter(request: _peer.request);
    _turnProtocol = TurnProtocolAdapter(
      request: _peer.request,
      notifications: _peer.notifications,
    );
    _approvalProtocol = ApprovalProtocolAdapter(
      serverRequests: _peer.serverRequests,
      notifications: _peer.notifications,
      respond: _peer.respond,
      respondError: _peer.respondError,
    );
    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .listen(_captureStderr);
    _exitWatcher = _watchExit();
  }

  final String executablePath;
  final ChildProcess _process;
  final Duration shutdownTimeout;
  final int stderrTailLimit;
  final StreamController<ProcessExit> _exits =
      StreamController<ProcessExit>.broadcast();
  late final JsonRpcPeer _peer;
  late final ThreadProtocolAdapter _threadProtocol;
  late final HistoryProtocolAdapter _historyProtocol;
  late final ModelProtocolAdapter _modelProtocol;
  late final OutputProtocolAdapter _outputProtocol;
  late final TurnProtocolAdapter _turnProtocol;
  late final ApprovalProtocolAdapter _approvalProtocol;
  late final StreamSubscription<String> _stderrSubscription;
  late final Future<void> _exitWatcher;
  Future<void>? _closeOperation;
  var _stderrTail = '';
  var _closing = false;

  static Future<ProcessTransport> start({
    required String executablePath,
    List<String> arguments = const ['app-server', '--listen', 'stdio://'],
    ProcessLauncher launcher = launchIoProcess,
    Duration shutdownTimeout = const Duration(seconds: 3),
    int stderrTailLimit = 32 * 1024,
  }) async {
    final process = await launcher(executablePath, arguments);
    return ProcessTransport._(
      executablePath: executablePath,
      process: process,
      shutdownTimeout: shutdownTimeout,
      stderrTailLimit: stderrTailLimit,
    );
  }

  static Future<ProcessTransport> startHost({
    required String hostExecutablePath,
    required String codexExecutablePath,
    ProcessLauncher launcher = launchIoProcess,
    Duration shutdownTimeout = const Duration(seconds: 7),
    int stderrTailLimit = 32 * 1024,
  }) => start(
    executablePath: hostExecutablePath,
    arguments: ['--codex', codexExecutablePath],
    launcher: launcher,
    shutdownTimeout: shutdownTimeout,
    stderrTailLimit: stderrTailLimit,
  );

  int get processId => _process.pid;
  String get stderrTail => _stderrTail;
  Stream<ProcessExit> get exits => _exits.stream;

  @override
  Stream<CodexNotification> get notifications => _peer.notifications;

  @override
  Stream<CodexServerRequest> get serverRequests => _peer.serverRequests;

  @override
  Stream<ProtocolViolation> get protocolErrors => _peer.protocolErrors;

  @override
  Stream<TurnEvent> get turnEvents => _turnProtocol.events;

  @override
  Stream<ApprovalEvent> get approvalEvents => _approvalProtocol.events;

  @override
  Future<InitializeResult> initialize(InitializeRequest request) async {
    final response = await _peer
        .request('initialize', request.toJson())
        .timeout(const Duration(seconds: 30));
    final result = InitializeResult.fromJson(response);
    await _peer.notify('initialized');
    return result;
  }

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) =>
      _threadProtocol.listThreads(query);

  @override
  Future<ModelPage> listModels(ModelListQuery query) =>
      _modelProtocol.listModels(query);

  @override
  Future<OutputDescriptor> statOutput(String reference) =>
      _outputProtocol.stat(reference);

  @override
  Future<OutputChunk> readOutputRange({
    required String reference,
    required int offset,
    required int length,
  }) => _outputProtocol.readRange(
    reference: reference,
    offset: offset,
    length: length,
  );

  @override
  Future<OutputChunk> readOutputTail({
    required String reference,
    required int length,
  }) => _outputProtocol.tail(reference: reference, length: length);

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
      _threadProtocol.startThread(options);

  @override
  Future<ThreadSummary> readThread(String threadId) =>
      _threadProtocol.readThread(threadId);

  @override
  Future<ThreadSummary> resumeThread(String threadId) =>
      _threadProtocol.resumeThread(threadId);

  @override
  Future<void> deleteThread(String threadId) =>
      _threadProtocol.deleteThread(threadId);

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) =>
      _turnProtocol.startTurn(options);

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) => _turnProtocol.interruptTurn(threadId: threadId, turnId: turnId);

  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) => _approvalProtocol.decide(requestId: requestId, decision: decision);

  void _captureStderr(String chunk) {
    _stderrTail += chunk;
    if (_stderrTail.length > stderrTailLimit) {
      _stderrTail = _stderrTail.substring(_stderrTail.length - stderrTailLimit);
    }
  }

  Future<void> _watchExit() async {
    final code = await _process.exitCode;
    if (!_exits.isClosed) {
      _exits.add(ProcessExit(code: code, stderrTail: _stderrTail.trim()));
    }
    if (!_closing) {
      await _peer.close(
        TransportClosedException('Codex app-server exited with code $code.'),
      );
    }
  }

  @override
  Future<void> close() => _closeOperation ??= _close();

  Future<void> _close() async {
    _closing = true;
    try {
      await _process.closeInput();
    } on Object {
      // The child may already have closed its stdin while exiting.
    }

    try {
      await _process.exitCode.timeout(shutdownTimeout);
    } on TimeoutException {
      _process.kill(ProcessSignal.sigterm);
      try {
        await _process.exitCode.timeout(shutdownTimeout);
      } on TimeoutException {
        _process.kill(ProcessSignal.sigkill);
        await _process.exitCode;
      }
    }

    await _exitWatcher;
    await _stderrSubscription.cancel();
    await _approvalProtocol.dispose();
    await _peer.close();
    await _exits.close();
  }
}
