import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/approval_gateway.dart';
import '../domain/approval_models.dart';
import '../domain/history_gateway.dart';
import '../domain/history_models.dart';
import '../domain/model_gateway.dart';
import '../domain/model_models.dart';
import '../domain/output_gateway.dart';
import '../domain/output_models.dart';
import '../domain/runtime_snapshot.dart';
import '../domain/thread_gateway.dart';
import '../domain/thread_models.dart';
import '../domain/turn_gateway.dart';
import '../domain/turn_models.dart';
import '../protocol/protocol_models.dart';
import '../transport/process/codex_executable_locator.dart';
import '../transport/process/host_executable_locator.dart';
import '../transport/process/process_transport.dart';
import '../transport/remote/remote_credentials.dart';
import '../transport/remote/remote_cursor_store.dart';
import '../transport/remote/remote_lifecycle_coordinator.dart';
import '../transport/remote/remote_projection.dart';
import '../transport/remote/remote_secure_storage.dart';

typedef TransportStarter = Future<ProcessTransport> Function(
  String hostExecutable,
  String codexExecutable,
);

class RuntimeController extends ChangeNotifier
    implements
        ThreadGateway,
        TurnGateway,
        ApprovalGateway,
        ModelGateway,
        OutputGateway,
        HistoryGateway {
  RuntimeController({
    this.locator = const CodexExecutableLocator(),
    this.hostLocator = const HostExecutableLocator(),
    TransportStarter? transportStarter,
    bool? useRemote,
    RemoteLifecycleOwner? remoteLifecycle,
  }) {
    _transportStarter =
        transportStarter ??
        ((hostExecutable, codexExecutable) => ProcessTransport.startHost(
          hostExecutablePath: hostExecutable,
          codexExecutablePath: codexExecutable,
        ));
    _usesRemote = useRemote ?? (remoteLifecycle != null || Platform.isAndroid);
    if (!_usesRemote && remoteLifecycle != null) {
      throw ArgumentError(
        'A Remote lifecycle owner requires Remote runtime mode.',
        'remoteLifecycle',
      );
    }
    _remoteLifecycle =
        remoteLifecycle ??
        (_usesRemote ? _createDefaultRemoteLifecycle() : null);
  }

  final CodexExecutableLocator locator;
  final HostExecutableLocator hostLocator;
  late final TransportStarter _transportStarter;
  late final bool _usesRemote;
  late final RemoteLifecycleOwner? _remoteLifecycle;
  RuntimeSnapshot _snapshot = const RuntimeSnapshot.idle();
  ProcessTransport? _transport;
  StreamSubscription<ProcessExit>? _exitSubscription;
  StreamSubscription<ProtocolViolation>? _protocolErrorSubscription;
  StreamSubscription<TurnEvent>? _turnEventSubscription;
  StreamSubscription<ApprovalEvent>? _approvalEventSubscription;
  StreamSubscription<RemoteLifecycleState>? _remoteStateSubscription;
  final StreamController<TurnEvent> _turnEvents =
      StreamController<TurnEvent>.broadcast();
  final StreamController<ApprovalEvent> _approvalEvents =
      StreamController<ApprovalEvent>.broadcast();
  Future<void>? _startOperation;
  var _disposed = false;
  var _stopping = false;

  RuntimeSnapshot get snapshot => _snapshot;
  bool get usesRemote => _usesRemote;
  List<CodexModel> get remoteModels =>
      _remoteLifecycle?.projection?.models ?? const [];
  List<ThreadSummary> get remoteThreads =>
      _remoteLifecycle?.projection?.threads ?? const [];
  bool get remoteHasMoreThreads =>
      _remoteLifecycle?.projection?.nextThreadCursor != null;

  @override
  Stream<TurnEvent> get turnEvents => _turnEvents.stream;

  @override
  Stream<ApprovalEvent> get approvalEvents => _approvalEvents.stream;

  Future<void> start() =>
      _usesRemote ? _startRemote() : (_startOperation ??= _startDesktop());

  Future<void> handleAppHidden() async {
    if (!_usesRemote || _stopping || _disposed) {
      return;
    }
    await _remoteLifecycle!.suspend();
    _handleRemoteState(_remoteLifecycle.state);
  }

  Future<void> handleAppShown() => start();

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) =>
      _connectedTransport().listThreads(query);

  @override
  Future<ModelPage> listModels(ModelListQuery query) =>
      _connectedTransport().listModels(query);

  @override
  Future<OutputDescriptor> statOutput(String reference) =>
      _connectedTransport().statOutput(reference);

  @override
  Future<OutputChunk> readOutputRange({
    required String reference,
    required int offset,
    required int length,
  }) => _connectedTransport().readOutputRange(
    reference: reference,
    offset: offset,
    length: length,
  );

  @override
  Future<OutputChunk> readOutputTail({
    required String reference,
    required int length,
  }) => _connectedTransport().readOutputTail(
    reference: reference,
    length: length,
  );

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) =>
      _connectedTransport().listHistoryTurns(query);

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) =>
      _connectedTransport().listHistoryItems(query);

  @override
  Future<List<HistoryItem>> readHistoryItems({
    required String threadId,
    required String turnId,
    required List<String> itemIds,
  }) => _connectedTransport().readHistoryItems(
    threadId: threadId,
    turnId: turnId,
    itemIds: itemIds,
  );

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
  Future<void> deleteThread(String threadId) =>
      _connectedTransport().deleteThread(threadId);

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) =>
      _connectedTransport().startTurn(options);

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
    if (_usesRemote) {
      throw UnsupportedError(
        'This operation is unavailable on the read-only Remote product surface.',
      );
    }
    final transport = _transport;
    if (transport == null ||
        _snapshot.state != RuntimeConnectionState.connected ||
        _stopping) {
      throw StateError('Codex app-server is not connected.');
    }
    return transport;
  }

  Future<void> _startDesktop() async {
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

    final hostExecutable = await hostLocator.locate();
    if (hostExecutable == null) {
      _setSnapshot(
        const RuntimeSnapshot(
          state: RuntimeConnectionState.hostNotFound,
          message:
              'Build or install codex-native-host, or set CODEX_NATIVE_HOST '
              'to its path. Direct app-server fallback is disabled so large '
              'output cannot bypass the bounded transport.',
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
      final transport = await _transportStarter(hostExecutable, executable);
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

  Future<void> _startRemote() async {
    if (_stopping || _disposed) {
      return;
    }
    final lifecycle = _remoteLifecycle!;
    _remoteStateSubscription ??= lifecycle.states.listen(
      _handleRemoteState,
      onError: (Object _, StackTrace _) {
        _setSnapshot(
          const RuntimeSnapshot(
            state: RuntimeConnectionState.error,
            message: 'Remote lifecycle failed.',
          ),
        );
      },
    );
    _handleRemoteState(lifecycle.state);
    await lifecycle.start();
    _handleRemoteState(lifecycle.state);
  }

  void _handleRemoteState(RemoteLifecycleState state) {
    if (!_usesRemote || _stopping || _disposed) {
      return;
    }
    final snapshot = switch (state.phase) {
      RemoteLifecyclePhase.idle ||
      RemoteLifecyclePhase.loadingCredentials => const RuntimeSnapshot(
        state: RuntimeConnectionState.remoteConnecting,
        message: 'Loading the paired Remote device profile.',
      ),
      RemoteLifecyclePhase.unpaired => const RuntimeSnapshot(
        state: RuntimeConnectionState.remoteUnpaired,
        message:
            'This device is not paired with a Codex Native Host. Pairing UI '
            'is not available in this build yet.',
      ),
      RemoteLifecyclePhase.credentialRecoveryRequired => const RuntimeSnapshot(
        state: RuntimeConnectionState.remoteCredentialRecoveryRequired,
        message:
            'The saved Remote profile is unreadable or invalid. It was not '
            'deleted; explicit clear and re-pair recovery is required.',
      ),
      RemoteLifecyclePhase.connecting => RuntimeSnapshot(
        state: RuntimeConnectionState.remoteConnecting,
        message: 'Connecting to the paired Host (attempt ${state.attempt}).',
      ),
      RemoteLifecyclePhase.hydrating => const RuntimeSnapshot(
        state: RuntimeConnectionState.remoteHydrating,
        message: 'Loading a bounded authoritative model and thread snapshot.',
      ),
      RemoteLifecyclePhase.ready => const RuntimeSnapshot(
        state: RuntimeConnectionState.remoteReadOnly,
        message:
            'Read-only Remote metadata is ready. Turns, history, output, '
            'approvals, and writes are unavailable in this build.',
      ),
      RemoteLifecyclePhase.waitingToRetry => RuntimeSnapshot(
        state: RuntimeConnectionState.remoteWaitingToRetry,
        message:
            'The Remote connection failed. Retrying in '
            '${state.retryDelay?.inSeconds ?? 0} seconds.',
      ),
      RemoteLifecyclePhase.revoked => const RuntimeSnapshot(
        state: RuntimeConnectionState.remoteRevoked,
        message:
            'This device credential was rejected or revoked. Re-pairing is '
            'required; automatic reconnect has stopped.',
      ),
      RemoteLifecyclePhase.suspended => const RuntimeSnapshot(
        state: RuntimeConnectionState.remoteSuspended,
        message: 'Remote is suspended while the application is hidden.',
      ),
      RemoteLifecyclePhase.stopped => const RuntimeSnapshot(
        state: RuntimeConnectionState.stopped,
      ),
    };
    _setSnapshot(snapshot);
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
    await _remoteLifecycle?.stop();
    await _remoteStateSubscription?.cancel();
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

  static RemoteLifecycleOwner _createDefaultRemoteLifecycle() {
    final storage = FlutterRemoteSecureValueStore();
    return RemoteLifecycleCoordinator(
      credentialStore: RemoteCredentialStore(storage),
      cursorStore: RemoteAppliedCursorStore(storage),
      projection: BoundedRemoteProjection(),
    );
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
