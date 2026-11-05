import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/approval_gateway.dart';
import '../domain/approval_models.dart';
import '../domain/runtime_snapshot.dart';
import '../domain/thread_gateway.dart';
import '../domain/thread_models.dart';
import '../domain/turn_gateway.dart';
import '../domain/turn_models.dart';
import '../protocol/protocol_models.dart';
import '../transport/process/codex_executable_locator.dart';
import '../transport/process/process_transport.dart';

typedef TransportStarter = Future<ProcessTransport> Function(String executable);

class RuntimeController extends ChangeNotifier
    implements ThreadGateway, TurnGateway, ApprovalGateway {
  RuntimeController({
    this.locator = const CodexExecutableLocator(),
    TransportStarter? transportStarter,
  }) : _transportStarter =
           transportStarter ??
           ((executable) => ProcessTransport.start(executablePath: executable));

  final CodexExecutableLocator locator;
  final TransportStarter _transportStarter;
  RuntimeSnapshot _snapshot = const RuntimeSnapshot.idle();
  ProcessTransport? _transport;
  StreamSubscription<ProcessExit>? _exitSubscription;
  StreamSubscription<ProtocolViolation>? _protocolErrorSubscription;
  StreamSubscription<TurnEvent>? _turnEventSubscription;
  StreamSubscription<ApprovalEvent>? _approvalEventSubscription;
  final StreamController<TurnEvent> _turnEvents =
      StreamController<TurnEvent>.broadcast();
  final StreamController<ApprovalEvent> _approvalEvents =
      StreamController<ApprovalEvent>.broadcast();
  Future<void>? _startOperation;
  var _disposed = false;
  var _stopping = false;

  RuntimeSnapshot get snapshot => _snapshot;

  @override
  Stream<TurnEvent> get turnEvents => _turnEvents.stream;

  @override
  Stream<ApprovalEvent> get approvalEvents => _approvalEvents.stream;

  Future<void> start() => _startOperation ??= _start();

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) =>
      _connectedTransport().listThreads(query);

  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) =>
      _connectedTransport().startThread(options);

  @override
  Future<ThreadSummary> readThread(String threadId) =>
      _connectedTransport().readThread(threadId);

  @override
  Future<ThreadSummary> resumeThread(String threadId) =>
      _connectedTransport().resumeThread(threadId);

  @override
  Future<TurnHandle> startTurn({
    required String threadId,
    required String text,
  }) => _connectedTransport().startTurn(threadId: threadId, text: text);

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) => _connectedTransport().interruptTurn(threadId: threadId, turnId: turnId);

  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) => _connectedTransport().decideApproval(
    requestId: requestId,
    decision: decision,
  );

  ProcessTransport _connectedTransport() {
    final transport = _transport;
    if (transport == null ||
        _snapshot.state != RuntimeConnectionState.connected ||
        _stopping) {
      throw StateError('Codex app-server is not connected.');
    }
    return transport;
  }

  Future<void> _start() async {
    if (Platform.isAndroid) {
      _setSnapshot(
        const RuntimeSnapshot(
          state: RuntimeConnectionState.unsupported,
          message: 'Android will connect through RemoteTransport in Phase 4.',
        ),
      );

      return;
    }

    _setSnapshot(const RuntimeSnapshot(state: RuntimeConnectionState.locating));
    final executable = await locator.locate();
    if (executable == null) {
      _setSnapshot(
        const RuntimeSnapshot(
          state: RuntimeConnectionState.notFound,
          message: 'Install Codex in PATH or set CODEX_EXECUTABLE to its path.',
        ),
      );
      return;
    }

    _setSnapshot(
      RuntimeSnapshot(
        state: RuntimeConnectionState.starting,
        executablePath: executable,
      ),
    );

    try {
      final transport = await _transportStarter(executable);
      if (_stopping || _disposed) {
        await transport.close();
        return;
      }
      _transport = transport;
      _exitSubscription = transport.exits.listen(_handleExit);
      _protocolErrorSubscription = transport.protocolErrors.listen(
        _handleProtocolError,
      );
      _turnEventSubscription = transport.turnEvents.listen(
        _turnEvents.add,
        onError: _handleTurnStreamError,
      );
      _approvalEventSubscription = transport.approvalEvents.listen(
        _approvalEvents.add,
        onError: _approvalEvents.addError,
      );
      final result = await transport.initialize(const InitializeRequest());
      if (_stopping || _disposed) {
        return;
      }
      _setSnapshot(
        RuntimeSnapshot(
          state: RuntimeConnectionState.connected,
          executablePath: executable,
          userAgent: result.userAgent,
          processId: transport.processId,
        ),
      );
    } catch (error) {
      final transport = _transport;
      _setSnapshot(
        RuntimeSnapshot(
          state: RuntimeConnectionState.error,
          executablePath: executable,
          processId: transport?.processId,
          message: _withStderr(error.toString(), transport?.stderrTail),
        ),
      );
      if (transport != null) {
        await transport.close();
      }
    }
  }

  void _handleExit(ProcessExit exit) {
    if (_stopping || _disposed) {
      return;
    }
    _setSnapshot(
      RuntimeSnapshot(
        state: RuntimeConnectionState.processExited,
        executablePath: _snapshot.executablePath,
        processId: _snapshot.processId,
        userAgent: _snapshot.userAgent,
        message: _withStderr(
          'Codex app-server exited with code ${exit.code}.',
          exit.stderrTail,
        ),
      ),
    );
  }

  void _handleProtocolError(ProtocolViolation error) {
    if (_stopping || _disposed) {
      return;
    }
    _setSnapshot(
      RuntimeSnapshot(
        state: RuntimeConnectionState.error,
        executablePath: _snapshot.executablePath,
        processId: _snapshot.processId,
        userAgent: _snapshot.userAgent,
        message: error.toString(),
      ),
    );
  }

  void _handleTurnStreamError(Object error, StackTrace stackTrace) {
    if (!_turnEvents.isClosed) {
      _turnEvents.addError(error, stackTrace);
    }
    _handleProtocolError(
      ProtocolViolation('Malformed turn notification.', error),
    );
  }

  static String _withStderr(String message, String? stderr) {
    final tail = stderr?.trim();
    return tail == null || tail.isEmpty ? message : '$message\n$tail';
  }

  Future<void> shutdown() async {
    if (_stopping) {
      return;
    }
    _stopping = true;
    await _exitSubscription?.cancel();
    await _protocolErrorSubscription?.cancel();
    await _turnEventSubscription?.cancel();
    await _approvalEventSubscription?.cancel();
    await _transport?.close();
    await _turnEvents.close();
    await _approvalEvents.close();
    if (!_disposed) {
      _setSnapshot(
        RuntimeSnapshot(
          state: RuntimeConnectionState.stopped,
          executablePath: _snapshot.executablePath,
          userAgent: _snapshot.userAgent,
          processId: _snapshot.processId,
        ),
      );
    }
  }

  void _setSnapshot(RuntimeSnapshot value) {
    if (_disposed) {
      return;
    }
    _snapshot = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(shutdown());
    super.dispose();
  }
}
