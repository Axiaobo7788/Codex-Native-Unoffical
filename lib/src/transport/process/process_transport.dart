import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/thread_models.dart';
import '../../protocol/json_rpc_peer.dart';
import '../../protocol/jsonl_decoder.dart';
import '../../protocol/protocol_models.dart';
import '../../protocol/thread_protocol.dart';
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
  late final StreamSubscription<String> _stderrSubscription;
  late final Future<void> _exitWatcher;
  Future<void>? _closeOperation;
  var _stderrTail = '';
  var _closing = false;

  static Future<ProcessTransport> start({
    required String executablePath,
    ProcessLauncher launcher = launchIoProcess,
    Duration shutdownTimeout = const Duration(seconds: 3),
    int stderrTailLimit = 32 * 1024,
  }) async {
    final process = await launcher(executablePath, const [
      'app-server',
      '--listen',
      'stdio://',
    ]);
    return ProcessTransport._(
      executablePath: executablePath,
      process: process,
      shutdownTimeout: shutdownTimeout,
      stderrTailLimit: stderrTailLimit,
    );
  }

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
    await _peer.close();
    await _exits.close();
  }
}
