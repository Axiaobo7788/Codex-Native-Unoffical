import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/approval_models.dart';
import '../../domain/ecosystem_gateway.dart';
import '../../domain/ecosystem_models.dart';
import '../../domain/history_gateway.dart';
import '../../domain/history_models.dart';
import '../../domain/model_models.dart';
import '../../domain/output_models.dart';
import '../../domain/remote_admin_models.dart';
import '../../domain/runtime_diagnostics_gateway.dart';
import '../../domain/runtime_diagnostics_models.dart';
import '../../domain/thread_attachment_gateway.dart';
import '../../domain/thread_attachment_models.dart';
import '../../domain/thread_gateway.dart';
import '../../domain/thread_models.dart';
import '../../domain/turn_models.dart';
import '../../domain/user_input_models.dart';
import '../../protocol/ecosystem_protocol.dart';
import '../../protocol/history_protocol.dart';
import '../../protocol/json_rpc_peer.dart';
import '../../protocol/jsonl_decoder.dart';
import '../../protocol/model_protocol.dart';
import '../../protocol/output_protocol.dart';
import '../../protocol/protocol_models.dart';
import '../../protocol/remote_admin_protocol.dart';
import '../../protocol/runtime_diagnostics_protocol.dart';
import '../../protocol/server_request_protocol.dart';
import '../../protocol/thread_attachment_protocol.dart';
import '../../protocol/thread_protocol.dart';
import '../../protocol/turn_protocol.dart';
import '../codex_transport.dart';
import 'child_process.dart';

class ProcessExit {
  const ProcessExit({required this.code, required this.stderrTail});

  final int code;
  final String stderrTail;
}

class ProcessTransport
    implements
        CodexTransport,
        HistoryOccurrenceGateway,
        HistoryMcpTextGateway,
        ThreadGoalGateway,
        ThreadQueuePresenceGateway,
        ThreadReadReceiptGateway,
        ThreadSectionGateway,
        ThreadAttachmentGateway,
        EcosystemCatalogGateway,
        McpCapabilityGateway,
        RuntimeDiagnosticsGateway {
  ProcessTransport._({
    required this.executablePath,
    required ChildProcess process,
    required this.shutdownTimeout,
    required this.stderrTailLimit,
    required bool includeHostCommandOutput,
  }) : _process = process,
       assert(stderrTailLimit > 0) {
    _peer = JsonRpcPeer(
      input: process.stdout.transform(const JsonlDecoder()),
      writer: process.write,
    );
    _threadProtocol = ThreadProtocolAdapter(
      request: _request,
      notifications: _peer.notifications,
    );
    _threadAttachmentProtocol = ThreadAttachmentProtocolAdapter(
      request: _request,
      notifications: _peer.notifications,
    );
    _historyProtocol = HistoryProtocolAdapter(request: _request);
    _modelProtocol = ModelProtocolAdapter(request: _request);
    _outputProtocol = OutputProtocolAdapter(request: _request);
    _remoteAdminProtocol = RemoteAdminProtocolAdapter(request: _request);
    _ecosystemProtocol = EcosystemProtocolAdapter(request: _request);
    _runtimeDiagnosticsProtocol = RuntimeDiagnosticsProtocolAdapter(
      request: _request,
      notifications: _peer.notifications,
    );
    _turnProtocol = TurnProtocolAdapter(
      request: _request,
      includeUserMessages: true,
      includeHostCommandOutput: includeHostCommandOutput,
      notifications: _peer.notifications,
    );
    _serverRequestProtocol = ServerRequestProtocolAdapter(
      serverRequests: _peer.serverRequests,
      notifications: _peer.notifications,
      respond: _respond,
      respondError: _respondError,
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
  late final ThreadAttachmentProtocolAdapter _threadAttachmentProtocol;
  late final HistoryProtocolAdapter _historyProtocol;
  late final ModelProtocolAdapter _modelProtocol;
  late final OutputProtocolAdapter _outputProtocol;
  late final RemoteAdminProtocolAdapter _remoteAdminProtocol;
  late final EcosystemProtocolAdapter _ecosystemProtocol;
  late final RuntimeDiagnosticsProtocolAdapter _runtimeDiagnosticsProtocol;
  late final TurnProtocolAdapter _turnProtocol;
  late final ServerRequestProtocolAdapter _serverRequestProtocol;
  late final StreamSubscription<String> _stderrSubscription;
  late final Future<void> _exitWatcher;
  Future<void>? _closeOperation;
  var _stderrTail = '';
  var _closing = false;
  var _threadAttachmentsUnsupported = false;
  var _threadAttachmentWritesUnsupported = false;
  var _threadReceiptWritesUnsupported = false;
  var _queuePresenceRequestInFlight = false;

  static Future<ProcessTransport> start({
    required String executablePath,
    List<String> arguments = const ['app-server', '--listen', 'stdio://'],
    ProcessLauncher launcher = launchIoProcess,
    Duration shutdownTimeout = const Duration(seconds: 3),
    int stderrTailLimit = 32 * 1024,
    bool includeHostCommandOutput = false,
  }) async {
    final process = await launcher(executablePath, arguments);
    return ProcessTransport._(
      executablePath: executablePath,
      process: process,
      shutdownTimeout: shutdownTimeout,
      stderrTailLimit: stderrTailLimit,
      includeHostCommandOutput: includeHostCommandOutput,
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
    includeHostCommandOutput: true,
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
  Stream<ThreadLifecycleEvent> get threadEvents => _threadProtocol.events;

  @override
  Stream<ApprovalEvent> get approvalEvents =>
      _serverRequestProtocol.approvalEvents;

  @override
  Stream<UserInputEvent> get userInputEvents =>
      _serverRequestProtocol.userInputEvents;

  @override
  bool get supportsMcpCapabilities => true;

  @override
  Stream<McpElicitationEvent> get mcpElicitationEvents =>
      _serverRequestProtocol.mcpElicitationEvents;

  @override
  bool get supportsRuntimeDiagnostics => true;

  @override
  bool get supportsThreadSections => true;

  @override
  Stream<RuntimeDiagnosticsEvent> get runtimeDiagnosticsEvents =>
      _runtimeDiagnosticsProtocol.events;

  @override
  Future<InitializeResult> initialize(InitializeRequest request) async {
    final response = await _request(
      'initialize',
      request.toJson(),
    ).timeout(const Duration(seconds: 30));
    final result = InitializeResult.fromJson(response);
    await _notify('initialized');
    return result;
  }

  Future<JsonObject> _request(String method, [JsonObject params = const {}]) {
    if (_closing) {
      return Future.error(const TransportClosedException());
    }
    return _peer.request(method, params);
  }

  Future<void> _notify(String method, [JsonObject params = const {}]) {
    if (_closing) {
      return Future.error(const TransportClosedException());
    }
    return _peer.notify(method, params);
  }

  Future<void> _respond(Object id, JsonObject result) {
    if (_closing) {
      return Future.error(const TransportClosedException());
    }
    return _peer.respond(id, result);
  }

  Future<void> _respondError(Object id, int code, String message) {
    if (_closing) {
      return Future.error(const TransportClosedException());
    }
    return _peer.respondError(id, code, message);
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
  bool get supportsHistoryOccurrences => !_closing;

  @override
  Future<HistoryOccurrencePage> listHistoryOccurrences(
    HistoryOccurrenceQuery query,
  ) async {
    try {
      return await _historyProtocol.listOccurrences(query);
    } on JsonRpcException catch (error) {
      if (error.code == -32601) {
        throw UnsupportedError('Saved search is unavailable for this thread.');
      }
      rethrow;
    }
  }

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) =>
      _historyProtocol.listItems(query, deferMcpText: true);

  @override
  bool get supportsSavedMcpText => !_closing;

  @override
  Future<SavedMcpTextResult?> readSavedMcpText({
    required String threadId,
    required String turnId,
    required String itemId,
  }) => _historyProtocol.readSavedMcpText(
    threadId: threadId,
    turnId: turnId,
    itemId: itemId,
  );

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
  Future<void> renameThread({required String threadId, required String name}) =>
      _threadProtocol.renameThread(threadId: threadId, name: name);

  @override
  Future<void> archiveThread(String threadId) =>
      _threadProtocol.archiveThread(threadId);

  @override
  Future<ThreadSummary> unarchiveThread(String threadId) =>
      _threadProtocol.unarchiveThread(threadId);

  @override
  Future<ThreadSummary> forkThread(ThreadForkOptions options) =>
      _threadProtocol.forkThread(options);

  @override
  Future<ThreadSummary> revertThread({
    required String threadId,
    required String beforeTurnId,
  }) => _threadProtocol.revertThread(
    threadId: threadId,
    beforeTurnId: beforeTurnId,
  );

  @override
  Future<void> compactThread(String threadId) =>
      _threadProtocol.compactThread(threadId);

  @override
  Future<void> deleteThread(String threadId) =>
      _threadProtocol.deleteThread(threadId);

  @override
  bool get supportsThreadGoals => !_closing;

  @override
  bool get supportsThreadQueuePresence => !_closing;

  @override
  Future<ThreadQueuePresence> readThreadQueuePresence(String threadId) async {
    if (_closing || _queuePresenceRequestInFlight) {
      return ThreadQueuePresence.unknown;
    }
    // Hold this slot until the stock request itself finishes, even when the
    // UI times out or changes threads.
    _queuePresenceRequestInFlight = true;
    try {
      return await _threadProtocol.readQueuePresence(threadId);
    } on JsonRpcException catch (error) {
      if (error.code == -32601) {
        return ThreadQueuePresence.unsupported;
      }
      rethrow;
    } finally {
      _queuePresenceRequestInFlight = false;
    }
  }

  @override
  bool get supportsThreadReadReceiptWrites =>
      !_closing && !_threadReceiptWritesUnsupported;

  @override
  Future<ThreadReadReceipt> setThreadReadReceipt({
    required String threadId,
    required String expectedRevision,
    required bool unread,
  }) async {
    if (!supportsThreadReadReceiptWrites) {
      throw UnsupportedError('Local read receipt changes are unavailable.');
    }
    try {
      return await _threadProtocol.setReadReceipt(
        threadId: threadId,
        expectedRevision: expectedRevision,
        unread: unread,
      );
    } on JsonRpcException catch (error) {
      if (error.code == -32601) {
        _threadReceiptWritesUnsupported = true;
        throw UnsupportedError('Local read receipt changes are unavailable.');
      }
      rethrow;
    }
  }

  @override
  Future<ThreadGoal?> readThreadGoal(String threadId) =>
      _threadProtocol.readThreadGoal(threadId);

  @override
  Future<ThreadGoal> setThreadGoal(
    String threadId, {
    String? objective,
    ThreadGoalStatus? status,
  }) => _threadProtocol.setThreadGoal(
    threadId,
    objective: objective,
    status: status,
  );

  @override
  Future<bool> clearThreadGoal(String threadId) =>
      _threadProtocol.clearThreadGoal(threadId);

  @override
  Future<ThreadSectionPage> listThreadSections([
    ThreadSectionListQuery query = const ThreadSectionListQuery(),
  ]) => _threadProtocol.listThreadSections(query);

  @override
  Future<ThreadSection> createThreadSection(
    ThreadSectionCreateOptions options,
  ) => _threadProtocol.createThreadSection(options);

  @override
  Future<ThreadSection> updateThreadSection(
    ThreadSectionUpdateOptions options,
  ) => _threadProtocol.updateThreadSection(options);

  @override
  Future<void> deleteThreadSection(String sectionId) =>
      _threadProtocol.deleteThreadSection(sectionId);

  @override
  Future<void> moveThreadSection(ThreadSectionMoveOptions options) =>
      _threadProtocol.moveThreadSection(options);

  @override
  bool get supportsThreadAttachments =>
      !_closing && !_threadAttachmentsUnsupported;

  @override
  bool get supportsThreadAttachmentWrites =>
      supportsThreadAttachments && !_threadAttachmentWritesUnsupported;

  @override
  Stream<ThreadAttachmentEvent> get threadAttachmentEvents =>
      _threadAttachmentProtocol.events;

  @override
  Future<ThreadLinkedPullRequestsSnapshot> readLinkedPullRequests(
    String threadId,
  ) async {
    if (_threadAttachmentsUnsupported) {
      throw UnsupportedError(
        'Thread attachments are unavailable on this runtime.',
      );
    }
    try {
      return await _threadAttachmentProtocol.readLinkedPullRequests(threadId);
    } on JsonRpcException catch (error) {
      if (error.code == -32601) {
        _threadAttachmentsUnsupported = true;
        _threadAttachmentWritesUnsupported = true;
      }
      rethrow;
    }
  }

  @override
  Future<ThreadPullRequestLinkResult> linkPullRequest(
    String threadId, {
    required String url,
    String? headBranch,
  }) async {
    if (_threadAttachmentsUnsupported || _threadAttachmentWritesUnsupported) {
      throw UnsupportedError(
        'Linking pull requests is unavailable on this runtime.',
      );
    }
    try {
      return await _threadAttachmentProtocol.linkPullRequest(
        threadId,
        url: url,
        headBranch: headBranch,
      );
    } on JsonRpcException catch (error) {
      if (error.code == -32601) {
        _threadAttachmentWritesUnsupported = true;
      }
      rethrow;
    }
  }

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) =>
      _turnProtocol.startTurn(options);

  Future<ReviewHandle> startReview(ReviewStartOptions options) =>
      _turnProtocol.startReview(options);

  @override
  Future<String> steerTurn(TurnSteerOptions options) =>
      _turnProtocol.steerTurn(options);

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) => _turnProtocol.interruptTurn(threadId: threadId, turnId: turnId);

  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) => _serverRequestProtocol.decideApproval(
    requestId: requestId,
    decision: decision,
  );

  @override
  Future<void> submitUserInput({
    required Object requestId,
    required UserInputAnswers answers,
  }) => _serverRequestProtocol.submitUserInput(
    requestId: requestId,
    answers: answers,
  );

  @override
  Future<void> cancelUserInput(Object requestId) =>
      _serverRequestProtocol.cancelUserInput(requestId);

  @override
  Future<void> reloadMcpServers() => _ecosystemProtocol.reloadMcpServers();

  @override
  Future<McpResourceReadResultModel> readMcpResource(
    McpResourceReadQuery query,
  ) => _ecosystemProtocol.readMcpResource(query);

  @override
  Future<McpToolCallResultModel> callMcpTool(McpToolCallQuery query) =>
      _ecosystemProtocol.callMcpTool(query);

  @override
  Future<void> respondToMcpElicitation({
    required Object requestId,
    required McpElicitationAction action,
    Map<String, Object?> content = const {},
  }) => _serverRequestProtocol.respondToMcpElicitation(
    requestId: requestId,
    action: action,
    content: content,
  );

  Future<RemoteHostStatus> readRemoteAdminStatus() =>
      _remoteAdminProtocol.status();

  Future<RemotePairingTicket> createRemotePairingTicket() =>
      _remoteAdminProtocol.createPairingTicket();

  Future<List<RemotePairedDevice>> listRemotePairedDevices() =>
      _remoteAdminProtocol.listDevices();

  Future<bool> revokeRemotePairedDevice(String deviceId) =>
      _remoteAdminProtocol.revokeDevice(deviceId);

  @override
  bool get supportsEcosystemCatalog => true;

  @override
  Future<List<SkillSummary>> listSkills({List<String> cwds = const []}) =>
      _ecosystemProtocol.listSkills(cwds: cwds);

  @override
  Future<bool> setSkillEnabled({required String path, required bool enabled}) =>
      _ecosystemProtocol.setSkillEnabled(path: path, enabled: enabled);

  @override
  Future<List<PluginSummaryModel>> listPlugins({
    List<String> cwds = const [],
  }) => _ecosystemProtocol.listPlugins(cwds: cwds);

  @override
  Future<PluginCatalogSnapshot> listPluginCatalog({
    List<String> cwds = const [],
  }) => _ecosystemProtocol.listPluginCatalog(cwds: cwds);

  @override
  Future<PluginDetailModel> readPlugin({
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
  }) => _ecosystemProtocol.readPlugin(
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
  }) => _ecosystemProtocol.installPlugin(
    pluginName: pluginName,
    marketplacePath: marketplacePath,
    remoteMarketplaceName: remoteMarketplaceName,
    installAttemptId: installAttemptId,
  );

  @override
  Future<void> uninstallPlugin({required String pluginId}) =>
      _ecosystemProtocol.uninstallPlugin(pluginId: pluginId);

  @override
  Future<AppListPage> listApps([AppListQuery query = const AppListQuery()]) =>
      _ecosystemProtocol.listApps(query);

  @override
  Future<List<InstalledAppSnapshotModel>> listInstalledApps({
    String? threadId,
    bool forceRefresh = false,
  }) => _ecosystemProtocol.listInstalledApps(
    threadId: threadId,
    forceRefresh: forceRefresh,
  );

  @override
  Future<AppReadResultModel> readApps({
    required List<String> appIds,
    bool includeTools = true,
    String? threadId,
  }) => _ecosystemProtocol.readApps(
    appIds: appIds,
    includeTools: includeTools,
    threadId: threadId,
  );

  @override
  Future<List<McpServerStatusModel>> listMcpServerStatus() =>
      _ecosystemProtocol.listMcpServerStatus();

  @override
  Future<OfficialRemoteControlStatus> readOfficialRemoteControlStatus() =>
      _ecosystemProtocol.readOfficialRemoteControlStatus();

  @override
  Future<OfficialRemoteControlStatus> setOfficialRemoteControlEnabled(
    bool enabled,
  ) => _ecosystemProtocol.setOfficialRemoteControlEnabled(enabled);

  @override
  Future<OfficialRemoteControlPairing> startOfficialRemoteControlPairing() =>
      _ecosystemProtocol.startOfficialRemoteControlPairing();

  @override
  Future<bool> disconnectOfficialRemoteControlClient(
    String clientId, {
    String? environmentId,
  }) => _ecosystemProtocol.disconnectOfficialRemoteControlClient(
    clientId,
    environmentId: environmentId,
  );

  @override
  Future<AccountDiagnosticsSnapshot> readAccountDiagnostics({
    bool refreshToken = false,
  }) => _runtimeDiagnosticsProtocol.readAccount(refreshToken: refreshToken);

  @override
  Future<RateLimitsDiagnosticsSnapshot> readAccountRateLimits({
    bool excludeResetCreditDetails = false,
  }) => _runtimeDiagnosticsProtocol.readAccountRateLimits(
    excludeResetCreditDetails: excludeResetCreditDetails,
  );

  @override
  Future<PermissionProfileListSnapshot> listPermissionProfiles({
    String? cwd,
    int? limit,
    String? cursor,
  }) => _runtimeDiagnosticsProtocol.listPermissionProfiles(
    cwd: cwd,
    limit: limit,
    cursor: cursor,
  );

  @override
  Future<ConfigDiagnosticsSnapshot> readConfigDiagnostics({
    String? cwd,
    bool includeLayers = true,
  }) => _runtimeDiagnosticsProtocol.readConfig(
    cwd: cwd,
    includeLayers: includeLayers,
  );

  @override
  Future<ConfigRequirementsSummaryModel> readConfigRequirements() =>
      _runtimeDiagnosticsProtocol.readConfigRequirements();

  @override
  Future<ModelProviderCapabilitiesSnapshot> readModelProviderCapabilities() =>
      _runtimeDiagnosticsProtocol.readModelProviderCapabilities();

  @override
  Future<ModelProviderInventorySnapshot> listModelProviders() =>
      _runtimeDiagnosticsProtocol.listModelProviders();

  @override
  Future<HooksDiagnosticsSnapshot> listHooks({
    List<String> cwds = const [],
    String? threadId,
  }) => _runtimeDiagnosticsProtocol.listHooks(cwds: cwds, threadId: threadId);

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
    await _serverRequestProtocol.dispose();
    await _peer.close();
    await _exits.close();
  }
}
