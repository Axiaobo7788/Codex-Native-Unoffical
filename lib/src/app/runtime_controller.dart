import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/approval_gateway.dart';
import '../domain/approval_models.dart';
import '../domain/conversation_backend.dart';
import '../domain/ecosystem_gateway.dart';
import '../domain/ecosystem_models.dart';
import '../domain/history_gateway.dart';
import '../domain/history_models.dart';
import '../domain/model_gateway.dart';
import '../domain/model_models.dart';
import '../domain/output_gateway.dart';
import '../domain/output_models.dart';
import '../domain/product_mode.dart';
import '../domain/remote_admin_gateway.dart';
import '../domain/remote_admin_models.dart';
import '../domain/runtime_snapshot.dart';
import '../domain/thread_gateway.dart';
import '../domain/thread_models.dart';
import '../domain/turn_gateway.dart';
import '../domain/turn_models.dart';
import '../domain/user_input_models.dart';
import '../protocol/protocol_models.dart';
import '../transport/process/codex_executable_locator.dart';
import '../transport/process/host_executable_locator.dart';
import '../transport/process/process_transport.dart';
import '../transport/remote/remote_credentials.dart';
import '../transport/remote/remote_cursor_store.dart';
import '../transport/remote/remote_lifecycle_coordinator.dart';
import '../transport/remote/remote_onboarding.dart';
import '../transport/remote/remote_projection.dart';
import '../transport/remote/remote_secure_storage.dart';

typedef TransportStarter = Future<ProcessTransport> Function(
  String hostExecutable,
  String codexExecutable,
);

class RuntimeController extends ChangeNotifier
    implements
        ConversationBackend,
        ExecutionBackend,
        ThreadGateway,
        TurnGateway,
        ApprovalGateway,
        ModelGateway,
        OutputGateway,
        HistoryGateway,
        RemoteAdminGateway,
        EcosystemGateway,
        EcosystemCatalogGateway,
        McpCapabilityGateway {
  RuntimeController({
    this.locator = const CodexExecutableLocator(),
    this.hostLocator = const HostExecutableLocator(),
    TransportStarter? transportStarter,
    bool? useRemote,
    RemoteLifecycleOwner? remoteLifecycle,
    RemoteOnboardingOwner? remoteOnboarding,
  }) {
    _transportStarter =
        transportStarter ??
        ((hostExecutable, codexExecutable) => ProcessTransport.startHost(
          hostExecutablePath: hostExecutable,
          codexExecutablePath: codexExecutable,
        ));
    _usesRemote =
        useRemote ??
        (remoteLifecycle != null ||
            remoteOnboarding != null ||
            Platform.isAndroid);
    if (!_usesRemote && (remoteLifecycle != null || remoteOnboarding != null)) {
      throw ArgumentError(
        'Remote owners require Remote runtime mode.',
        'useRemote',
      );
    }
    if (remoteOnboarding != null && remoteLifecycle == null) {
      throw ArgumentError(
        'A Remote onboarding owner requires a Remote lifecycle owner.',
        'remoteOnboarding',
      );
    }
    if (_usesRemote && remoteLifecycle == null) {
      final stack = _createDefaultRemoteStack();
      _remoteLifecycle = stack.lifecycle;
      _remoteOnboarding = stack.onboarding;
    } else {
      _remoteLifecycle = remoteLifecycle;
      _remoteOnboarding = remoteOnboarding;
    }
  }

  final CodexExecutableLocator locator;
  final HostExecutableLocator hostLocator;
  late final TransportStarter _transportStarter;
  late final bool _usesRemote;
  late final RemoteLifecycleOwner? _remoteLifecycle;
  late final RemoteOnboardingOwner? _remoteOnboarding;
  RuntimeSnapshot _snapshot = const RuntimeSnapshot.idle();
  ProcessTransport? _transport;
  StreamSubscription<ProcessExit>? _exitSubscription;
  StreamSubscription<ProtocolViolation>? _protocolErrorSubscription;
  StreamSubscription<TurnEvent>? _turnEventSubscription;
  StreamSubscription<ThreadLifecycleEvent>? _threadEventSubscription;
  StreamSubscription<ApprovalEvent>? _approvalEventSubscription;
  StreamSubscription<UserInputEvent>? _userInputEventSubscription;
  StreamSubscription<McpElicitationEvent>? _mcpElicitationEventSubscription;
  StreamSubscription<RemoteLifecycleState>? _remoteStateSubscription;
  StreamSubscription<RemoteOnboardingState>? _remoteOnboardingSubscription;
  final StreamController<TurnEvent> _turnEvents =
      StreamController<TurnEvent>.broadcast();
  final StreamController<ThreadLifecycleEvent> _threadEvents =
      StreamController<ThreadLifecycleEvent>.broadcast();
  final StreamController<ApprovalEvent> _approvalEvents =
      StreamController<ApprovalEvent>.broadcast();
  final StreamController<UserInputEvent> _userInputEvents =
      StreamController<UserInputEvent>.broadcast();
  final StreamController<McpElicitationEvent> _mcpElicitationEvents =
      StreamController<McpElicitationEvent>.broadcast();
  Future<void>? _startOperation;
  var _disposed = false;
  var _stopping = false;

  RuntimeSnapshot get snapshot => _snapshot;
  bool get usesRemote => _usesRemote;
  BackendCapabilities get capabilities => _usesRemote
      ? const BackendCapabilities.directHostRemoteReadOnly()
      : const BackendCapabilities.stockCodexLocal();
  List<CodexModel> get remoteModels =>
      _remoteLifecycle?.projection?.models ?? const [];
  List<ThreadSummary> get remoteThreads =>
      _remoteLifecycle?.projection?.threads ?? const [];
  bool get remoteHasMoreThreads =>
      _remoteLifecycle?.projection?.nextThreadCursor != null;
  bool get hasRemoteOnboarding => _remoteOnboarding != null;
  RemoteOnboardingState get remoteOnboardingState =>
      _remoteOnboarding?.state ?? const RemoteOnboardingState.idle();

  @override
  Stream<TurnEvent> get turnEvents => _turnEvents.stream;

  @override
  Stream<ThreadLifecycleEvent> get threadEvents => _threadEvents.stream;

  @override
  Stream<ApprovalEvent> get approvalEvents => _approvalEvents.stream;

  @override
  Stream<UserInputEvent> get userInputEvents => _userInputEvents.stream;

  @override
  bool get supportsMcpCapabilities => !_usesRemote;

  @override
  Stream<McpElicitationEvent> get mcpElicitationEvents =>
      _mcpElicitationEvents.stream;

  Future<void> start() =>
      _usesRemote ? _startRemote() : (_startOperation ??= _startDesktop());

  Future<void> handleAppHidden() async {
    if (!_usesRemote || _stopping || _disposed) {
      return;
    }
    _remoteOnboarding?.setApplicationVisible(false);
    await _remoteLifecycle!.suspend();
    _handleRemoteState(_remoteLifecycle.state);
  }

  Future<void> handleAppShown() {
    _remoteOnboarding?.setApplicationVisible(true);
    return start();
  }

  Future<void> pairRemote({
    required String invitation,
    required String deviceName,
  }) {
    final onboarding = _remoteOnboarding;
    if (onboarding == null) {
      throw UnsupportedError('Remote pairing is unavailable.');
    }
    return onboarding.pair(invitation: invitation, deviceName: deviceName);
  }

  Future<void> clearRemoteProfile() {
    final onboarding = _remoteOnboarding;
    if (onboarding == null) {
      throw UnsupportedError('Remote profile recovery is unavailable.');
    }
    return onboarding.clearProfile();
  }

  @override
  Future<RemoteHostStatus> readRemoteAdminStatus() =>
      _connectedTransport().readRemoteAdminStatus();

  @override
  Future<RemotePairingTicket> createRemotePairingTicket() =>
      _connectedTransport().createRemotePairingTicket();

  @override
  Future<List<RemotePairedDevice>> listRemotePairedDevices() =>
      _connectedTransport().listRemotePairedDevices();

  @override
  Future<bool> revokeRemotePairedDevice(String deviceId) =>
      _connectedTransport().revokeRemotePairedDevice(deviceId);

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
  Future<void> renameThread({required String threadId, required String name}) =>
      _connectedTransport().renameThread(threadId: threadId, name: name);

  @override
  Future<void> archiveThread(String threadId) =>
      _connectedTransport().archiveThread(threadId);

  @override
  Future<ThreadSummary> unarchiveThread(String threadId) =>
      _connectedTransport().unarchiveThread(threadId);

  @override
  Future<ThreadSummary> forkThread(ThreadForkOptions options) =>
      _connectedTransport().forkThread(options);

  @override
  Future<ThreadSummary> revertThread({
    required String threadId,
    required String beforeTurnId,
  }) => _connectedTransport().revertThread(
    threadId: threadId,
    beforeTurnId: beforeTurnId,
  );

  @override
  Future<void> compactThread(String threadId) =>
      _connectedTransport().compactThread(threadId);

  @override
  Future<void> deleteThread(String threadId) =>
      _connectedTransport().deleteThread(threadId);

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) =>
      _connectedTransport().startTurn(options);

  @override
  Future<String> steerTurn(TurnSteerOptions options) =>
      _connectedTransport().steerTurn(options);

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

  @override
  Future<void> submitUserInput({
    required Object requestId,
    required UserInputAnswers answers,
  }) => _connectedTransport().submitUserInput(
    requestId: requestId,
    answers: answers,
  );

  @override
  Future<void> cancelUserInput(Object requestId) =>
      _connectedTransport().cancelUserInput(requestId);

  @override
  Future<void> reloadMcpServers() {
    if (_usesRemote) {
      throw UnsupportedError(
        'MCP configuration reload is unavailable on read-only Remote.',
      );
    }
    return _connectedTransport().reloadMcpServers();
  }

  @override
  Future<McpResourceReadResultModel> readMcpResource(
    McpResourceReadQuery query,
  ) {
    if (_usesRemote) {
      throw UnsupportedError(
        'MCP resource reads are unavailable on read-only Remote.',
      );
    }
    return _connectedTransport().readMcpResource(query);
  }

  @override
  Future<McpToolCallResultModel> callMcpTool(McpToolCallQuery query) {
    if (_usesRemote) {
      throw UnsupportedError(
        'MCP tool calls are unavailable on read-only Remote.',
      );
    }
    return _connectedTransport().callMcpTool(query);
  }

  @override
  Future<void> respondToMcpElicitation({
    required Object requestId,
    required McpElicitationAction action,
    Map<String, Object?> content = const {},
  }) {
    if (_usesRemote) {
      throw UnsupportedError(
        'MCP elicitation is unavailable on read-only Remote.',
      );
    }
    return _connectedTransport().respondToMcpElicitation(
      requestId: requestId,
      action: action,
      content: content,
    );
  }

  @override
  bool get supportsEcosystemCatalog => !_usesRemote;

  @override
  Future<List<SkillSummary>> listSkills({List<String> cwds = const []}) =>
      _connectedTransport().listSkills(cwds: cwds);

  @override
  Future<bool> setSkillEnabled({required String path, required bool enabled}) =>
      _connectedTransport().setSkillEnabled(path: path, enabled: enabled);

  @override
  Future<List<PluginSummaryModel>> listPlugins({
    List<String> cwds = const [],
  }) => _connectedTransport().listPlugins(cwds: cwds);

  @override
  Future<PluginDetailModel> readPlugin({
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
  }) => _connectedTransport().readPlugin(
    pluginName: pluginName,
    marketplacePath: marketplacePath,
    remoteMarketplaceName: remoteMarketplaceName,
  );

  @override
  Future<PluginInstallResultModel> installPlugin({
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
    String? installAttemptId,
  }) => _connectedTransport().installPlugin(
    pluginName: pluginName,
    marketplacePath: marketplacePath,
    remoteMarketplaceName: remoteMarketplaceName,
    installAttemptId: installAttemptId,
  );

  @override
  Future<void> uninstallPlugin({required String pluginId}) =>
      _connectedTransport().uninstallPlugin(pluginId: pluginId);

  @override
  Future<AppListPage> listApps([AppListQuery query = const AppListQuery()]) =>
      _connectedTransport().listApps(query);

  @override
  Future<List<InstalledAppSnapshotModel>> listInstalledApps({
    String? threadId,
    bool forceRefresh = false,
  }) => _connectedTransport().listInstalledApps(
    threadId: threadId,
    forceRefresh: forceRefresh,
  );

  @override
  Future<AppReadResultModel> readApps({
    required List<String> appIds,
    bool includeTools = true,
    String? threadId,
  }) => _connectedTransport().readApps(
    appIds: appIds,
    includeTools: includeTools,
    threadId: threadId,
  );

  @override
  Future<List<McpServerStatusModel>> listMcpServerStatus() =>
      _connectedTransport().listMcpServerStatus();

  @override
  Future<OfficialRemoteControlStatus> readOfficialRemoteControlStatus() =>
      _connectedTransport().readOfficialRemoteControlStatus();

  @override
  Future<OfficialRemoteControlStatus> setOfficialRemoteControlEnabled(
    bool enabled,
  ) => _connectedTransport().setOfficialRemoteControlEnabled(enabled);

  @override
  Future<OfficialRemoteControlPairing> startOfficialRemoteControlPairing() =>
      _connectedTransport().startOfficialRemoteControlPairing();

  @override
  Future<bool> disconnectOfficialRemoteControlClient(
    String clientId, {
    String? environmentId,
  }) => _connectedTransport().disconnectOfficialRemoteControlClient(
    clientId,
    environmentId: environmentId,
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
      _threadEventSubscription = transport.threadEvents.listen(
        _threadEvents.add,
        onError: _threadEvents.addError,
      );
      _approvalEventSubscription = transport.approvalEvents.listen(
        _approvalEvents.add,
        onError: _approvalEvents.addError,
      );
      _userInputEventSubscription = transport.userInputEvents.listen(
        _userInputEvents.add,
        onError: _userInputEvents.addError,
      );
      _mcpElicitationEventSubscription = transport.mcpElicitationEvents.listen(
        _mcpElicitationEvents.add,
        onError: _mcpElicitationEvents.addError,
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
    _remoteOnboardingSubscription ??= _remoteOnboarding?.states.listen((_) {
      if (!_stopping && !_disposed) {
        notifyListeners();
      }
    });
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
            'This device is not paired with a Codex Native Host. Create a '
            'one-use ticket on the trusted local Host to continue.',
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
    await _threadEventSubscription?.cancel();
    await _approvalEventSubscription?.cancel();
    await _userInputEventSubscription?.cancel();
    await _mcpElicitationEventSubscription?.cancel();
    await _remoteOnboarding?.stop();
    await _remoteLifecycle?.stop();
    await _remoteStateSubscription?.cancel();
    await _remoteOnboardingSubscription?.cancel();
    await _transport?.close();
    await _turnEvents.close();
    await _threadEvents.close();
    await _approvalEvents.close();
    await _userInputEvents.close();
    await _mcpElicitationEvents.close();
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

  static _DefaultRemoteStack _createDefaultRemoteStack() {
    final storage = FlutterRemoteSecureValueStore();
    final credentialStore = RemoteCredentialStore(storage);
    final cursorStore = RemoteAppliedCursorStore(storage);
    final lifecycle = RemoteLifecycleCoordinator(
      credentialStore: credentialStore,
      cursorStore: cursorStore,
      projection: BoundedRemoteProjection(),
    );
    return _DefaultRemoteStack(
      lifecycle: lifecycle,
      onboarding: RemoteOnboardingCoordinator(
        credentialStore: credentialStore,
        cursorStore: cursorStore,
        lifecycle: lifecycle,
      ),
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

final class _DefaultRemoteStack {
  const _DefaultRemoteStack({
    required this.lifecycle,
    required this.onboarding,
  });

  final RemoteLifecycleOwner lifecycle;
  final RemoteOnboardingOwner onboarding;
}
