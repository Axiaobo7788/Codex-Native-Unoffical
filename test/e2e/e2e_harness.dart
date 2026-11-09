import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/ecosystem_models.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
import 'package:codex_native_unofficial/src/domain/product_mode.dart';
import 'package:codex_native_unofficial/src/domain/remote_admin_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opaque-box E2E test harness that emulates the complete Codex app-server
/// and Native Host transport boundary, allowing test suites to interact
/// with [CodexNativeApp] as an opaque end-user UI.
class E2ERuntimeHarness extends RuntimeController {
  E2ERuntimeHarness({
    List<ThreadSummary>? initialThreads,
    List<CodexModel>? initialModels,
    List<HistoryTurn>? initialHistoryTurns,
    List<HistoryItem>? initialHistoryItems,
    List<RemotePairedDevice>? initialPairedDevices,
    RuntimeSnapshot? initialSnapshot,
    RemoteHostStatus? initialHostStatus,
  }) : _snapshot =
           initialSnapshot ??
           const RuntimeSnapshot(
             state: RuntimeConnectionState.connected,
             executablePath: '/usr/bin/codex',
             userAgent: 'e2e-app-server',
             processId: 1001,
           ),
       _hostStatus =
           initialHostStatus ??
           const RemoteHostStatus(
             hostVersion: '0.1.0',
             enabled: true,
             bindAddress: '127.0.0.1:8443',
             tls: true,
             scope: RemoteListenerScope.loopback,
             advertisedEndpoint: 'wss://127.0.0.1:8443',
             pairingTrust: RemotePairingTrustMode.system,
           ) {
    if (initialThreads != null) {
      threads.addAll(initialThreads);
    }
    if (initialModels != null) {
      models.addAll(initialModels);
    } else {
      models.addAll(_defaultModels);
    }
    if (initialHistoryTurns != null) {
      historyTurns.addAll(initialHistoryTurns);
    }
    if (initialHistoryItems != null) {
      historyItems.addAll(initialHistoryItems);
    }
    if (initialPairedDevices != null) {
      pairedDevices.addAll(initialPairedDevices);
    }
    skills.addAll(_defaultSkills);
    plugins.addAll(_defaultPlugins);
    installedApps.addAll(_defaultInstalledApps);
    catalogApps.addAll(_defaultCatalogApps);
    mcpServers.addAll(_defaultMcpServers);
  }

  static const _defaultSkills = [
    SkillSummary(
      name: 'frontend-design',
      description: 'Desktop UI design and typography skill',
      path: '/workspace/.agents/skills/frontend-design/SKILL.md',
      enabled: true,
      scope: 'repo',
    ),
  ];

  static const _defaultPlugins = [
    PluginSummaryModel(
      id: 'git-workflow',
      name: 'Git Workflow',
      pluginName: 'git-workflow',
      description: 'Branch and PR helpers',
      enabled: true,
      installed: true,
      version: '1.0.0',
      marketplaceName: 'openai-primary-runtime',
      marketplacePath: '/workspace/.agents/plugins/marketplace.json',
      sourceType: 'local',
    ),
  ];

  static const _defaultInstalledApps = [
    InstalledAppSnapshotModel(
      id: 'connector_github',
      runtimeName: 'GitHub',
      enabled: true,
      callable: true,
    ),
  ];

  static const _defaultCatalogApps = [
    AppSummaryModel(
      id: 'connector_github',
      name: 'GitHub',
      description: 'Access repositories, issues, and pull requests.',
      isAccessible: true,
      isEnabled: true,
      distributionChannel: 'DEFAULT_OAI_CATALOG',
      category: 'Developer Tools',
      developer: 'OpenAI',
      pluginDisplayNames: ['Git Workflow'],
    ),
  ];

  static const _defaultMcpServers = [
    McpServerStatusModel(
      name: 'filesystem-mcp',
      status: 'ready',
      toolCount: 4,
      resourceCount: 2,
    ),
  ];

  static const _defaultModels = [
    CodexModel(
      id: 'o3-mini',
      model: 'o3-mini-wire',
      displayName: 'o3-mini',
      description: 'Reasoning model for code',
      isDefault: true,
      defaultReasoningEffort: 'medium',
      supportedReasoningEfforts: [
        ReasoningEffortOption(value: 'low', description: 'Low'),
        ReasoningEffortOption(value: 'medium', description: 'Medium'),
        ReasoningEffortOption(value: 'high', description: 'High'),
      ],
    ),
    CodexModel(
      id: 'gpt-4o',
      model: 'gpt-4o-wire',
      displayName: 'GPT-4o',
      description: 'Fast general-purpose model',
      isDefault: false,
      defaultReasoningEffort: '',
      supportedReasoningEfforts: [],
    ),
  ];

  final StreamController<TurnEvent> _turnsController =
      StreamController<TurnEvent>.broadcast(sync: true);
  final StreamController<ThreadLifecycleEvent> _threadsController =
      StreamController<ThreadLifecycleEvent>.broadcast(sync: true);
  final StreamController<ApprovalEvent> _approvalsController =
      StreamController<ApprovalEvent>.broadcast(sync: true);
  final StreamController<McpElicitationEvent> _mcpElicitationsController =
      StreamController<McpElicitationEvent>.broadcast(sync: true);
  final StreamController<RuntimeDiagnosticsEvent>
  _runtimeDiagnosticsController =
      StreamController<RuntimeDiagnosticsEvent>.broadcast(sync: true);

  RuntimeSnapshot _snapshot;
  RemoteHostStatus _hostStatus;

  final List<ThreadSummary> threads = [];
  final List<ThreadSummary> archivedThreads = [];
  final List<ThreadSection> threadSections = [];
  var threadSectionsSupported = true;
  final List<CodexModel> models = [];
  final List<HistoryTurn> historyTurns = [];
  final List<HistoryItem> historyItems = [];
  final List<RemotePairedDevice> pairedDevices = [];
  final List<SkillSummary> skills = [];
  final List<PluginSummaryModel> plugins = [];
  final List<InstalledAppSnapshotModel> installedApps = [];
  final List<AppSummaryModel> catalogApps = [];
  final Map<String, AppDetailModel> appDetails = {};
  final Map<String, PluginDetailModel> pluginDetails = {};
  final List<PluginAppReferenceModel> installAuthApps = [];
  final List<McpServerStatusModel> mcpServers = [];
  var mcpCapabilitiesSupported = true;
  var mcpReloadCount = 0;
  final List<McpResourceReadQuery> mcpResourceReadQueries = [];
  final List<McpToolCallQuery> mcpToolCallQueries = [];
  final List<
    ({
      Object requestId,
      McpElicitationAction action,
      Map<String, Object?> content,
    })
  >
  mcpElicitationResponses = [];
  McpResourceReadResultModel mcpResourceReadResult = McpResourceReadResultModel(
    contents: const [
      McpTextResourceContentModel(
        uri: 'file:///workspace/README.md',
        mimeType: 'text/markdown',
        text: '# Test workspace',
      ),
    ],
  );
  McpToolCallResultModel mcpToolCallResult = McpToolCallResultModel(
    content: const [
      McpToolContentModel(
        kind: 'text',
        summary: 'Text',
        text: 'Tool completed.',
      ),
    ],
    isError: false,
    structuredContentPreview: '{"changed":true}',
  );
  var catalogSupported = true;
  var runtimeDiagnosticsSupported = true;
  var remoteModeOverride = false;
  int? catalogPageSizeOverride;
  Future<AppListPage> Function(AppListQuery query)? listAppsOverride;
  AccountDiagnosticsSnapshot accountDiagnostics =
      const AccountDiagnosticsSnapshot(
        requiresOpenaiAuth: true,
        accountType: 'chatgpt',
        planType: 'plus',
        email: 'dev@example.test',
        workspaceName: 'Synthetic Workspace',
      );
  RateLimitsDiagnosticsSnapshot rateLimitsDiagnostics =
      RateLimitsDiagnosticsSnapshot(
        primaryBucket: const RateLimitBucketSnapshot(
          limitId: 'codex',
          limitName: 'Codex Primary',
          normalModelSlug: 'o3-mini',
          planType: 'plus',
          primary: RateLimitWindowSnapshot(
            usedPercent: 42,
            windowDurationMins: 300,
            resetsAtEpochSeconds: 1790000000,
          ),
          credits: CreditsDiagnosticsSnapshot(
            hasCredits: true,
            unlimited: false,
            balance: '25.00',
          ),
        ),
        bucketsById: const [
          RateLimitBucketSnapshot(
            limitId: 'codex',
            primary: RateLimitWindowSnapshot(
              usedPercent: 42,
              windowDurationMins: 300,
            ),
          ),
        ],
        ordinaryUsageAllowed: true,
        availableResetCreditsCount: 2,
      );
  PermissionProfileListSnapshot permissionProfilesSnapshot =
      PermissionProfileListSnapshot(
        profiles: const [
          PermissionProfileSummaryModel(
            id: ':read-only',
            allowed: true,
            description: 'Read-only workspace inspection',
          ),
          PermissionProfileSummaryModel(
            id: ':workspace',
            allowed: true,
            description: 'Standard workspace writes',
          ),
          PermissionProfileSummaryModel(
            id: ':danger-full-access',
            allowed: false,
            description: 'Unrestricted host access',
          ),
        ],
      );
  ConfigDiagnosticsSnapshot configDiagnostics = ConfigDiagnosticsSnapshot(
    configKeyCount: 48,
    originCount: 12,
    model: 'o3-mini',
    reviewModel: 'o3-mini',
    modelProvider: 'openai',
    modelReasoningEffort: 'medium',
    modelReasoningSummary: 'concise',
    modelVerbosity: 'medium',
    approvalPolicy: 'on-request',
    approvalsReviewer: 'user',
    sandboxMode: 'workspace-write',
    webSearchMode: 'cached',
    defaultPermissions: ':workspace',
    serviceTier: 'default',
    profile: 'dev-profile',
    modelContextWindow: 200000,
    modelAutoCompactTokenLimit: 160000,
    layers: const [
      ConfigLayerSummaryModel(
        sourceType: 'user',
        version: 'v1',
        configEntryCount: 6,
        sourceLocation: '/workspace/.codex/config.toml',
        profile: 'dev-profile',
      ),
      ConfigLayerSummaryModel(
        sourceType: 'project',
        version: 'v1',
        configEntryCount: 3,
        sourceLocation: '/workspace/project/.codex',
      ),
    ],
  );
  ConfigRequirementsSummaryModel configRequirements =
      ConfigRequirementsSummaryModel(
        hasRequirements: true,
        supportsIndependentSpeedModes: true,
        allowedApprovalPolicies: const ['untrusted', 'on-request'],
        allowedSandboxModes: const ['read-only', 'workspace-write'],
        allowedWebSearchModes: const ['disabled', 'cached'],
        allowedLoginMethods: const ['chatgpt'],
        enforceResidency: 'us',
        allowRemoteControl: true,
        allowManagedHooksOnly: false,
        allowLoginShell: true,
      );
  ModelProviderCapabilitiesSnapshot modelProviderCapabilities =
      const ModelProviderCapabilitiesSnapshot(
        imageGeneration: true,
        webSearch: true,
      );
  HooksDiagnosticsSnapshot hooksDiagnostics = HooksDiagnosticsSnapshot(
    entries: [
      WorkspaceHooksEntrySummary(
        cwd: '/workspace/test',
        hooks: const [
          HookSummaryModel(
            key: 'pre-tool-lint',
            eventName: 'preToolUse',
            handlerType: 'command',
            enabled: true,
            isManaged: false,
            source: 'project',
            sourcePath: '/workspace/test/.codex/hooks.toml',
            trustStatus: 'trusted',
            timeoutSec: 15,
            targetSummary: 'Command handler',
            matcher: 'Edit|Write',
            statusMessage: 'Running analyzer hook',
          ),
        ],
        errors: const [],
        warnings: const ['Hook timeout exceeds 10s recommendation'],
      ),
    ],
    totalHookCount: 1,
    totalErrorCount: 0,
    totalWarningCount: 1,
  );
  Object? accountDiagnosticsError;
  var accountReadCount = 0;
  var rateLimitsReadCount = 0;
  var permissionProfilesListCount = 0;
  var configReadCount = 0;
  var configRequirementsReadCount = 0;
  var providerCapabilitiesReadCount = 0;
  var hooksListCount = 0;
  OfficialRemoteControlStatus officialRemoteStatus =
      const OfficialRemoteControlStatus(
        supported: true,
        enabled: false,
        connected: false,
        environmentId: 'env-local-1',
        clients: [
          OfficialRemoteControlClient(
            id: 'client-ios-1',
            name: 'iPhone 16 Pro',
            platform: 'iOS',
          ),
        ],
      );
  final Map<String, Uint8List> outputStore = {};
  final Map<String, OutputDescriptor> outputDescriptors = {};

  // Action audit trails for assertion verification
  final List<String> startedThreadCwds = [];
  final List<TurnStartOptions> startedTurns = [];
  final List<ReviewStartOptions> startedReviews = [];
  final List<TurnSteerOptions> steeredTurns = [];
  final List<String> deletedThreadIds = [];
  final List<({String threadId, String name})> renamedThreads = [];
  final List<String> archivedThreadIds = [];
  final List<String> unarchivedThreadIds = [];
  final List<ThreadForkOptions> forkedThreads = [];
  final List<({String threadId, String beforeTurnId})> revertedThreads = [];
  final List<String> compactedThreadIds = [];
  final List<ThreadSectionCreateOptions> createdThreadSections = [];
  final List<ThreadSectionUpdateOptions> updatedThreadSections = [];
  final List<String> deletedThreadSectionIds = [];
  final List<ThreadSectionMoveOptions> movedThreadSections = [];
  final List<({String path, bool enabled})> toggledSkills = [];
  final List<AppListQuery> appListQueries = [];
  final List<({String? threadId, bool forceRefresh})> installedAppsQueries = [];
  final List<({List<String> appIds, bool includeTools, String? threadId})>
  readAppRequests = [];
  final List<
    ({
      String pluginName,
      String? marketplacePath,
      String? remoteMarketplaceName,
    })
  >
  readPluginRequests = [];
  final List<
    ({
      String pluginName,
      String? marketplacePath,
      String? remoteMarketplaceName,
    })
  >
  installedPluginRequests = [];
  final List<String> uninstalledPluginIds = [];
  final List<bool> officialRemoteEnabledToggles = [];
  final List<String> disconnectedOfficialClients = [];
  final List<({String threadId, String turnId})> interruptedTurns = [];
  final List<({Object requestId, ApprovalDecision decision})>
  approvalDecisions = [];
  final List<String> revokedDeviceIds = [];
  var pairingTicketCounter = 0;

  @override
  RuntimeSnapshot get snapshot => _snapshot;

  @override
  Stream<TurnEvent> get turnEvents => _turnsController.stream;

  @override
  Stream<ThreadLifecycleEvent> get threadEvents => _threadsController.stream;

  @override
  Stream<ApprovalEvent> get approvalEvents => _approvalsController.stream;

  @override
  bool get usesRemote => remoteModeOverride;

  @override
  BackendCapabilities get capabilities => remoteModeOverride
      ? const BackendCapabilities.directHostRemoteReadOnly()
      : super.capabilities;

  @override
  bool get supportsMcpCapabilities =>
      mcpCapabilitiesSupported && !remoteModeOverride;

  @override
  Stream<McpElicitationEvent> get mcpElicitationEvents =>
      _mcpElicitationsController.stream;

  @override
  bool get supportsRuntimeDiagnostics =>
      runtimeDiagnosticsSupported && !remoteModeOverride;

  @override
  Stream<RuntimeDiagnosticsEvent> get runtimeDiagnosticsEvents =>
      _runtimeDiagnosticsController.stream;

  @override
  Future<void> start() async {
    notifyListeners();
  }

  void updateSnapshot(RuntimeSnapshot newSnapshot) {
    _snapshot = newSnapshot;
    notifyListeners();
  }

  void updateHostStatus(RemoteHostStatus newStatus) {
    _hostStatus = newStatus;
    notifyListeners();
  }

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) async {
    final source = query.archived ? archivedThreads : threads;
    return ThreadPage(threads: List.unmodifiable(source), nextCursor: null);
  }

  @override
  Future<ThreadSummary> readThread(String threadId) async {
    return threads.firstWhere(
      (t) => t.id == threadId,
      orElse: () => archivedThreads.firstWhere(
        (t) => t.id == threadId,
        orElse: () => _buildDefaultThread(threadId),
      ),
    );
  }

  @override
  Future<ThreadSummary> resumeThread(String threadId) async {
    return readThread(threadId);
  }

  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) async {
    startedThreadCwds.add(options.cwd);
    final newThread = ThreadSummary(
      id: 'thread-created-${startedThreadCwds.length}',
      sessionId: 'session-${startedThreadCwds.length}',
      preview: 'New created thread ${startedThreadCwds.length}',
      cwd: options.cwd,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      status: ThreadRuntimeStatus.idle,
      ephemeral: false,
    );
    threads.insert(0, newThread);
    notifyListeners();
    return newThread;
  }

  @override
  Future<void> renameThread({
    required String threadId,
    required String name,
  }) async {
    renamedThreads.add((threadId: threadId, name: name));
    final index = threads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      threads[index] = threads[index].copyWith(
        name: name.isEmpty ? null : name,
        clearName: name.isEmpty,
      );
    }
    _threadsController.add(
      ThreadNameUpdatedEvent(
        threadId: threadId,
        threadName: name.isEmpty ? null : name,
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> archiveThread(String threadId) async {
    archivedThreadIds.add(threadId);
    final index = threads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      archivedThreads.insert(0, threads.removeAt(index));
    }
    _threadsController.add(ThreadArchivedEvent(threadId: threadId));
    notifyListeners();
  }

  @override
  Future<ThreadSummary> unarchiveThread(String threadId) async {
    unarchivedThreadIds.add(threadId);
    final index = archivedThreads.indexWhere((t) => t.id == threadId);
    final restored = index != -1
        ? archivedThreads.removeAt(index)
        : _buildDefaultThread(threadId);
    threads.insert(0, restored);
    _threadsController.add(ThreadUnarchivedEvent(threadId: threadId));
    notifyListeners();
    return restored;
  }

  @override
  Future<ThreadSummary> forkThread(ThreadForkOptions options) async {
    forkedThreads.add(options);
    final source = await readThread(options.threadId);
    final forked = ThreadSummary(
      id: 'thread-fork-${forkedThreads.length}',
      sessionId: 'session-fork-${forkedThreads.length}',
      preview: '${source.displayTitle} (fork)',
      cwd: options.cwd ?? source.cwd,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      status: ThreadRuntimeStatus.idle,
      ephemeral: options.ephemeral,
      name: source.name != null ? '${source.name} (fork)' : null,
      model: options.model ?? source.model,
    );
    threads.insert(0, forked);
    notifyListeners();
    return forked;
  }

  @override
  Future<ThreadSummary> revertThread({
    required String threadId,
    required String beforeTurnId,
  }) async {
    revertedThreads.add((threadId: threadId, beforeTurnId: beforeTurnId));
    final beforeIndex = historyTurns.indexWhere((t) => t.id == beforeTurnId);
    if (beforeIndex != -1) {
      historyTurns.removeRange(beforeIndex, historyTurns.length);
    }
    _threadsController.add(ThreadRevertedEvent(threadId: threadId));
    notifyListeners();
    return readThread(threadId);
  }

  @override
  Future<void> compactThread(String threadId) async {
    compactedThreadIds.add(threadId);
    notifyListeners();
  }

  @override
  Future<void> deleteThread(String threadId) async {
    deletedThreadIds.add(threadId);
    threads.removeWhere((t) => t.id == threadId);
    notifyListeners();
  }

  @override
  bool get supportsThreadSections =>
      threadSectionsSupported && !remoteModeOverride;

  @override
  Future<ThreadSectionPage> listThreadSections([
    ThreadSectionListQuery query = const ThreadSectionListQuery(),
  ]) async {
    if (!supportsThreadSections) {
      throw UnsupportedError(
        'Thread sections are unavailable on read-only Remote.',
      );
    }
    return ThreadSectionPage(
      sections: List.unmodifiable(threadSections),
      nextCursor: null,
    );
  }

  @override
  Future<ThreadSection> createThreadSection(
    ThreadSectionCreateOptions options,
  ) async {
    if (!supportsThreadSections) {
      throw UnsupportedError(
        'Thread sections are unavailable on read-only Remote.',
      );
    }
    createdThreadSections.add(options);
    final created = ThreadSection(
      id: 'section-${createdThreadSections.length}',
      name: options.name,
      appearance: options.appearance,
    );
    threadSections.add(created);
    notifyListeners();
    return created;
  }

  @override
  Future<ThreadSection> updateThreadSection(
    ThreadSectionUpdateOptions options,
  ) async {
    if (!supportsThreadSections) {
      throw UnsupportedError(
        'Thread sections are unavailable on read-only Remote.',
      );
    }
    updatedThreadSections.add(options);
    final idx = threadSections.indexWhere((s) => s.id == options.sectionId);
    final existing = idx != -1
        ? threadSections[idx]
        : ThreadSection(id: options.sectionId, name: options.name);
    final updated = existing.copyWith(
      name: options.name,
      appearance: options.appearance,
      clearAppearance: options.clearAppearance,
    );
    if (idx != -1) {
      threadSections[idx] = updated;
    } else {
      threadSections.add(updated);
    }
    for (var i = 0; i < threads.length; i += 1) {
      if (threads[i].section?.id == updated.id) {
        threads[i] = threads[i].copyWith(section: updated);
      }
    }
    notifyListeners();
    return updated;
  }

  @override
  Future<void> deleteThreadSection(String sectionId) async {
    if (!supportsThreadSections) {
      throw UnsupportedError(
        'Thread sections are unavailable on read-only Remote.',
      );
    }
    deletedThreadSectionIds.add(sectionId);
    threadSections.removeWhere((s) => s.id == sectionId);
    for (var i = 0; i < threads.length; i += 1) {
      if (threads[i].section?.id == sectionId) {
        threads[i] = threads[i].copyWith(
          clearSection: true,
          clearSectionEnteredAtSeconds: true,
        );
      }
    }
    notifyListeners();
  }

  @override
  Future<void> moveThreadSection(ThreadSectionMoveOptions options) async {
    if (!supportsThreadSections) {
      throw UnsupportedError(
        'Thread sections are unavailable on read-only Remote.',
      );
    }
    movedThreadSections.add(options);
    final sectionId = options.sectionId;
    final targetSection = sectionId == null
        ? null
        : threadSections.firstWhere(
            (s) => s.id == sectionId,
            orElse: () => ThreadSection(id: sectionId, name: sectionId),
          );
    final idx = threads.indexWhere((t) => t.id == options.threadId);
    if (idx != -1) {
      threads[idx] = threads[idx].copyWith(
        section: targetSection,
        clearSection: targetSection == null,
        sectionEnteredAtSeconds: targetSection != null ? 1700000000 : null,
        clearSectionEnteredAtSeconds: targetSection == null,
      );
    }
    _threadsController.add(
      ThreadSectionChangedEvent(
        threadId: options.threadId,
        sectionId: sectionId,
      ),
    );
    notifyListeners();
  }

  void emitThreadSectionChanged(String threadId, String? sectionId) {
    _threadsController.add(
      ThreadSectionChangedEvent(threadId: threadId, sectionId: sectionId),
    );
  }

  @override
  Future<ModelPage> listModels(ModelListQuery query) async {
    return ModelPage(models: List.unmodifiable(models), nextCursor: null);
  }

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async {
    return HistoryTurnPage(
      turns: List.unmodifiable(historyTurns),
      nextCursor: null,
    );
  }

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async {
    return HistoryItemPage(
      items: List.unmodifiable(historyItems),
      nextCursor: null,
    );
  }

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) async {
    startedTurns.add(options);
    final handle = TurnHandle(
      id: 'turn-${startedTurns.length}',
      status: TurnRuntimeStatus.inProgress,
    );
    _turnsController.add(
      TurnStartedEvent(threadId: options.threadId, turnId: handle.id),
    );
    return handle;
  }

  @override
  Future<ReviewHandle> startReview(ReviewStartOptions options) async {
    if (remoteModeOverride) {
      throw UnsupportedError(
        'Code review is unavailable on the read-only Remote product surface.',
      );
    }
    startedReviews.add(options);
    final turn = TurnHandle(
      id: 'review-turn-${startedReviews.length}',
      status: TurnRuntimeStatus.inProgress,
    );
    _turnsController.add(
      TurnStartedEvent(threadId: options.threadId, turnId: turn.id),
    );
    _turnsController.add(
      ReviewModeEvent(
        threadId: options.threadId,
        turnId: turn.id,
        itemId: 'review-entered-${startedReviews.length}',
        phase: ReviewModePhase.entered,
        review: options.target.displayLabel,
        status: 'completed',
        completed: true,
      ),
    );
    return ReviewHandle(reviewThreadId: options.threadId, turn: turn);
  }

  @override
  Future<String> steerTurn(TurnSteerOptions options) async {
    steeredTurns.add(options);
    return options.expectedTurnId;
  }

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    interruptedTurns.add((threadId: threadId, turnId: turnId));
    _turnsController.add(
      TurnCompletedEvent(
        threadId: threadId,
        turnId: turnId,
        status: TurnRuntimeStatus.interrupted,
      ),
    );
  }

  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) async {
    approvalDecisions.add((requestId: requestId, decision: decision));
    _approvalsController.add(ApprovalResolvedEvent(requestId: requestId));
  }

  @override
  Future<OutputDescriptor> statOutput(String reference) async {
    final descriptor = outputDescriptors[reference];
    if (descriptor == null) {
      throw StateError('Output descriptor not found: $reference');
    }
    return descriptor;
  }

  @override
  Future<OutputChunk> readOutputRange({
    required String reference,
    required int offset,
    required int length,
  }) async {
    final data = outputStore[reference] ?? Uint8List(0);
    final actualEnd = (offset + length).clamp(0, data.length);
    final chunkBytes = data.sublist(offset.clamp(0, data.length), actualEnd);
    final stored = data.length;
    final total = outputDescriptors[reference]?.bytes ?? stored;
    return OutputChunk(
      reference: reference,
      offset: offset,
      data: chunkBytes,
      bytes: total,
      storedBytes: stored,
      truncated: total > stored,
      eof: actualEnd >= data.length,
    );
  }

  @override
  Future<OutputChunk> readOutputTail({
    required String reference,
    required int length,
  }) async {
    final data = outputStore[reference] ?? Uint8List(0);
    final start = (data.length - length).clamp(0, data.length);
    final chunkBytes = data.sublist(start);
    final stored = data.length;
    final total = outputDescriptors[reference]?.bytes ?? stored;
    return OutputChunk(
      reference: reference,
      offset: start,
      data: chunkBytes,
      bytes: total,
      storedBytes: stored,
      truncated: total > stored,
      eof: true,
    );
  }

  @override
  Future<RemoteHostStatus> readRemoteAdminStatus() async {
    return _hostStatus;
  }

  @override
  Future<RemotePairingTicket> createRemotePairingTicket() async {
    pairingTicketCounter++;
    return RemotePairingTicket(
      invitation: 'invitation-$pairingTicketCounter',
      endpoint: _hostStatus.advertisedEndpoint ?? 'wss://127.0.0.1:8443',
      expiresAtMs: DateTime.now()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
      trust: _hostStatus.pairingTrust ?? RemotePairingTrustMode.system,
    );
  }

  @override
  Future<List<RemotePairedDevice>> listRemotePairedDevices() async {
    return List.unmodifiable(pairedDevices);
  }

  @override
  Future<bool> revokeRemotePairedDevice(String deviceId) async {
    revokedDeviceIds.add(deviceId);
    pairedDevices.removeWhere((d) => d.id == deviceId);
    notifyListeners();
    return true;
  }

  @override
  Future<List<SkillSummary>> listSkills({List<String> cwds = const []}) async {
    return List.unmodifiable(skills);
  }

  @override
  Future<bool> setSkillEnabled({
    required String path,
    required bool enabled,
  }) async {
    toggledSkills.add((path: path, enabled: enabled));
    final idx = skills.indexWhere((s) => s.path == path);
    if (idx != -1) {
      skills[idx] = skills[idx].copyWith(enabled: enabled);
    }
    return enabled;
  }

  @override
  bool get supportsEcosystemCatalog => catalogSupported;

  @override
  Future<List<PluginSummaryModel>> listPlugins({
    List<String> cwds = const [],
  }) async {
    return List.unmodifiable(plugins);
  }

  @override
  Future<PluginDetailModel> readPlugin({
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
  }) async {
    readPluginRequests.add((
      pluginName: pluginName,
      marketplacePath: marketplacePath,
      remoteMarketplaceName: remoteMarketplaceName,
    ));
    final existing = pluginDetails[pluginName];
    if (existing != null) {
      return existing;
    }
    final summary = plugins.firstWhere(
      (p) => p.effectivePluginName == pluginName || p.id == pluginName,
      orElse: () => PluginSummaryModel(
        id: pluginName,
        name: pluginName,
        pluginName: pluginName,
        description: 'Detailed plugin description for $pluginName',
        enabled: true,
        marketplaceName: remoteMarketplaceName ?? 'openai-primary-runtime',
        marketplacePath: marketplacePath,
      ),
    );
    return PluginDetailModel(
      summary: summary,
      marketplaceName:
          summary.marketplaceName ??
          remoteMarketplaceName ??
          'openai-primary-runtime',
      marketplacePath: marketplacePath ?? summary.marketplacePath,
      description: 'Full detail manifest for ${summary.name}.',
      skills: skills,
      apps: const [
        PluginAppReferenceModel(
          id: 'connector_github',
          name: 'GitHub',
          category: 'Developer Tools',
        ),
      ],
      mcpServers: const ['filesystem-mcp'],
      hooks: const [
        PluginHookSummaryModel(key: 'pre-tool', eventName: 'preToolUse'),
      ],
    );
  }

  @override
  Future<PluginInstallResultModel> installPlugin({
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
    String? installAttemptId,
  }) async {
    installedPluginRequests.add((
      pluginName: pluginName,
      marketplacePath: marketplacePath,
      remoteMarketplaceName: remoteMarketplaceName,
    ));
    final idx = plugins.indexWhere(
      (p) => p.effectivePluginName == pluginName || p.id == pluginName,
    );
    if (idx != -1) {
      plugins[idx] = plugins[idx].copyWith(installed: true, enabled: true);
    }
    return PluginInstallResultModel(
      authPolicy: installAuthApps.isNotEmpty ? 'ON_INSTALL' : 'ON_USE',
      appsNeedingAuth: List.unmodifiable(installAuthApps),
    );
  }

  @override
  Future<void> uninstallPlugin({required String pluginId}) async {
    uninstalledPluginIds.add(pluginId);
    final idx = plugins.indexWhere((p) => p.id == pluginId);
    if (idx != -1) {
      plugins[idx] = plugins[idx].copyWith(installed: false, enabled: false);
    }
  }

  @override
  Future<AppListPage> listApps([
    AppListQuery query = const AppListQuery(),
  ]) async {
    appListQueries.add(query);
    if (listAppsOverride case final override?) {
      return override(query);
    }
    final startIndex = int.tryParse(query.cursor ?? '') ?? 0;
    if (startIndex < 0 || startIndex >= catalogApps.length) {
      return const AppListPage(apps: []);
    }
    final pageSize = catalogPageSizeOverride ?? query.limit;
    final endIndex = (startIndex + pageSize).clamp(0, catalogApps.length);
    final slice = catalogApps.sublist(startIndex, endIndex);
    final nextCursor = endIndex < catalogApps.length ? '$endIndex' : null;
    return AppListPage(apps: List.unmodifiable(slice), nextCursor: nextCursor);
  }

  @override
  Future<List<InstalledAppSnapshotModel>> listInstalledApps({
    String? threadId,
    bool forceRefresh = false,
  }) async {
    installedAppsQueries.add((threadId: threadId, forceRefresh: forceRefresh));
    return List.unmodifiable(installedApps);
  }

  @override
  Future<AppReadResultModel> readApps({
    required List<String> appIds,
    bool includeTools = true,
    String? threadId,
  }) async {
    readAppRequests.add((
      appIds: List.unmodifiable(appIds),
      includeTools: includeTools,
      threadId: threadId,
    ));
    final found = <AppDetailModel>[];
    final missing = <String>[];
    for (final id in appIds) {
      final custom = appDetails[id];
      if (custom != null) {
        found.add(custom);
        continue;
      }
      final match = catalogApps.where((a) => a.id == id);
      if (match.isNotEmpty) {
        final summary = match.first;
        found.add(
          AppDetailModel(
            id: summary.id,
            name: summary.name,
            description: summary.description,
            distributionChannel: summary.distributionChannel,
            installUrl: summary.installUrl,
            pluginDisplayNames: summary.pluginDisplayNames,
            toolSummaries: includeTools
                ? const [
                    AppToolSummaryModel(
                      name: 'create_pull_request',
                      description: 'Create a GitHub pull request.',
                    ),
                    AppToolSummaryModel(
                      name: 'get_issue',
                      description: 'Read an issue snapshot.',
                      isReadOnly: true,
                    ),
                  ]
                : const [],
          ),
        );
      } else {
        missing.add(id);
      }
    }
    return AppReadResultModel(
      apps: List.unmodifiable(found),
      missingAppIds: List.unmodifiable(missing),
    );
  }

  @override
  Future<List<McpServerStatusModel>> listMcpServerStatus() async {
    return List.unmodifiable(mcpServers);
  }

  @override
  Future<void> reloadMcpServers() async {
    mcpReloadCount++;
  }

  @override
  Future<McpResourceReadResultModel> readMcpResource(
    McpResourceReadQuery query,
  ) async {
    mcpResourceReadQueries.add(query);
    return mcpResourceReadResult;
  }

  @override
  Future<McpToolCallResultModel> callMcpTool(McpToolCallQuery query) async {
    mcpToolCallQueries.add(query);
    return mcpToolCallResult;
  }

  @override
  Future<void> respondToMcpElicitation({
    required Object requestId,
    required McpElicitationAction action,
    Map<String, Object?> content = const {},
  }) async {
    mcpElicitationResponses.add((
      requestId: requestId,
      action: action,
      content: Map.unmodifiable(content),
    ));
    _mcpElicitationsController.add(
      McpElicitationResolvedEvent(requestId: requestId),
    );
  }

  @override
  Future<OfficialRemoteControlStatus> readOfficialRemoteControlStatus() async {
    return officialRemoteStatus;
  }

  @override
  Future<OfficialRemoteControlStatus> setOfficialRemoteControlEnabled(
    bool enabled,
  ) async {
    officialRemoteEnabledToggles.add(enabled);
    officialRemoteStatus = OfficialRemoteControlStatus(
      supported: officialRemoteStatus.supported,
      enabled: enabled,
      connected: enabled,
      environmentId: officialRemoteStatus.environmentId,
      clients: officialRemoteStatus.clients,
    );
    return officialRemoteStatus;
  }

  @override
  Future<OfficialRemoteControlPairing>
  startOfficialRemoteControlPairing() async {
    return const OfficialRemoteControlPairing(
      code: 'PAIR-7788-CODEX',
      qrPayload: 'codex://remote-control/pair?code=PAIR-7788-CODEX',
    );
  }

  @override
  Future<bool> disconnectOfficialRemoteControlClient(
    String clientId, {
    String? environmentId,
  }) async {
    disconnectedOfficialClients.add(clientId);
    officialRemoteStatus = OfficialRemoteControlStatus(
      supported: officialRemoteStatus.supported,
      enabled: officialRemoteStatus.enabled,
      connected: officialRemoteStatus.connected,
      environmentId: officialRemoteStatus.environmentId,
      clients: officialRemoteStatus.clients
          .where((c) => c.id != clientId)
          .toList(growable: false),
    );
    return true;
  }

  @override
  Future<AccountDiagnosticsSnapshot> readAccountDiagnostics({
    bool refreshToken = false,
  }) async {
    if (!supportsRuntimeDiagnostics) {
      throw UnsupportedError(
        'Account diagnostics are unavailable on read-only Remote.',
      );
    }
    accountReadCount++;
    if (accountDiagnosticsError case final error?) {
      throw error;
    }
    return accountDiagnostics;
  }

  @override
  Future<RateLimitsDiagnosticsSnapshot> readAccountRateLimits({
    bool excludeResetCreditDetails = false,
  }) async {
    if (!supportsRuntimeDiagnostics) {
      throw UnsupportedError(
        'Rate-limit diagnostics are unavailable on read-only Remote.',
      );
    }
    rateLimitsReadCount++;
    return rateLimitsDiagnostics;
  }

  @override
  Future<PermissionProfileListSnapshot> listPermissionProfiles({
    String? cwd,
    int? limit,
    String? cursor,
  }) async {
    if (!supportsRuntimeDiagnostics) {
      throw UnsupportedError(
        'Permission profile diagnostics are unavailable on read-only Remote.',
      );
    }
    permissionProfilesListCount++;
    return permissionProfilesSnapshot;
  }

  @override
  Future<ConfigDiagnosticsSnapshot> readConfigDiagnostics({
    String? cwd,
    bool includeLayers = true,
  }) async {
    if (!supportsRuntimeDiagnostics) {
      throw UnsupportedError(
        'Configuration diagnostics are unavailable on read-only Remote.',
      );
    }
    configReadCount++;
    return configDiagnostics;
  }

  @override
  Future<ConfigRequirementsSummaryModel> readConfigRequirements() async {
    if (!supportsRuntimeDiagnostics) {
      throw UnsupportedError(
        'Configuration requirement diagnostics are unavailable on read-only Remote.',
      );
    }
    configRequirementsReadCount++;
    return configRequirements;
  }

  @override
  Future<ModelProviderCapabilitiesSnapshot>
  readModelProviderCapabilities() async {
    if (!supportsRuntimeDiagnostics) {
      throw UnsupportedError(
        'Model provider capabilities are unavailable on read-only Remote.',
      );
    }
    providerCapabilitiesReadCount++;
    return modelProviderCapabilities;
  }

  @override
  Future<HooksDiagnosticsSnapshot> listHooks({
    List<String> cwds = const [],
    String? threadId,
  }) async {
    if (!supportsRuntimeDiagnostics) {
      throw UnsupportedError(
        'Workspace hook diagnostics are unavailable on read-only Remote.',
      );
    }
    hooksListCount++;
    return hooksDiagnostics;
  }

  @override
  Future<void> shutdown() async {}

  // Test manipulation helpers
  void emitStreamingMessage(
    String itemId,
    String text, {
    String turnId = 'turn-1',
    String threadId = 'active-thread',
  }) {
    _turnsController.add(
      AssistantTextDeltaEvent(
        threadId: threadId,
        turnId: turnId,
        itemId: itemId,
        delta: text,
      ),
    );
  }

  void emitAssistantMessage(
    String itemId,
    String text, {
    bool completed = true,
    String turnId = 'turn-1',
    String threadId = 'active-thread',
  }) {
    _turnsController.add(
      AssistantMessageEvent(
        threadId: threadId,
        turnId: turnId,
        itemId: itemId,
        text: text,
        completed: completed,
      ),
    );
  }

  void emitTurnCompleted(
    String turnId, {
    TurnRuntimeStatus status = TurnRuntimeStatus.completed,
    String threadId = 'active-thread',
    String? errorMessage,
  }) {
    _turnsController.add(
      TurnCompletedEvent(
        threadId: threadId,
        turnId: turnId,
        status: status,
        errorMessage: errorMessage,
      ),
    );
  }

  void emitTurnError(
    String turnId,
    String errorMessage, {
    String threadId = 'active-thread',
    bool willRetry = false,
  }) {
    _turnsController.add(
      TurnErrorEvent(
        threadId: threadId,
        turnId: turnId,
        message: errorMessage,
        willRetry: willRetry,
      ),
    );
  }

  void emitDiff(DiffSnapshot snapshot) {
    _turnsController.add(TurnDiffUpdatedEvent(snapshot: snapshot));
  }

  void emitApproval(ApprovalRequest request) {
    _approvalsController.add(ApprovalRequestedEvent(request: request));
  }

  void emitMcpElicitation(McpElicitationRequest request) {
    _mcpElicitationsController.add(
      McpElicitationRequestedEvent(request: request),
    );
  }

  void emitAccountUpdated({String? authMode, String? planType}) {
    _runtimeDiagnosticsController.add(
      AccountUpdatedDiagnosticsEvent(authMode: authMode, planType: planType),
    );
  }

  void emitAccountRateLimitsUpdated(RateLimitBucketSnapshot rateLimits) {
    _runtimeDiagnosticsController.add(
      AccountRateLimitsUpdatedDiagnosticsEvent(rateLimits: rateLimits),
    );
  }

  void emitDiagnosticsStreamError(Object error) {
    _runtimeDiagnosticsController.addError(error);
  }

  void storeOutput(String reference, String content, {int? totalLength}) {
    final bytes = Uint8List.fromList(utf8.encode(content));
    outputStore[reference] = bytes;
    final total = totalLength ?? bytes.length;
    outputDescriptors[reference] = OutputDescriptor(
      reference: reference,
      bytes: total,
      storedBytes: bytes.length,
      truncated: total > bytes.length,
      available: true,
    );
  }

  Future<void> disposeHarness() async {
    await _turnsController.close();
    await _threadsController.close();
    await _approvalsController.close();
    await _mcpElicitationsController.close();
    await _runtimeDiagnosticsController.close();
    dispose();
  }

  static ThreadSummary _buildDefaultThread(String threadId) {
    return ThreadSummary(
      id: threadId,
      sessionId: 'session-$threadId',
      preview: 'Thread $threadId',
      cwd: '/workspace',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      status: ThreadRuntimeStatus.idle,
      ephemeral: false,
    );
  }
}

/// Helper to pump [CodexNativeApp] in an opaque-box widget test environment.
Future<void> pumpE2EApp(
  WidgetTester tester, {
  required E2ERuntimeHarness harness,
  Size size = const Size(1400, 900),
  double devicePixelRatio = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(harness.disposeHarness);

  await tester.pumpWidget(CodexNativeApp(runtimeController: harness));
  await tester.pumpAndSettle();
}

/// Helper to create a test thread summary.
ThreadSummary createTestThread({
  required String id,
  required String preview,
  String cwd = '/workspace/test',
  DateTime? updatedAt,
  ThreadRuntimeStatus status = ThreadRuntimeStatus.idle,
}) {
  return ThreadSummary(
    id: id,
    sessionId: 'session-$id',
    preview: preview,
    cwd: cwd,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1, 12, 0),
    status: status,
    ephemeral: false,
  );
}

/// Helper to create a test history turn.
HistoryTurn createTestTurn({
  required String id,
  required String userPrompt,
  String assistantProse = '',
  DateTime? startedAt,
  DateTime? completedAt,
  TurnRuntimeStatus status = TurnRuntimeStatus.completed,
  List<UserAttachment> attachments = const [],
}) {
  return HistoryTurn(
    id: id,
    status: status,
    startedAt: startedAt ?? DateTime.utc(2026, 1, 1, 10, 0),
    completedAt: completedAt ?? DateTime.utc(2026, 1, 1, 10, 3, 58),
    items: [
      HistoryItem(
        id: 'user-$id',
        turnId: id,
        kind: HistoryItemKind.user,
        text: userPrompt,
        attachments: attachments,
      ),
      if (assistantProse.isNotEmpty)
        HistoryItem(
          id: 'assistant-$id',
          turnId: id,
          kind: HistoryItemKind.assistant,
          text: assistantProse,
        ),
    ],
  );
}
