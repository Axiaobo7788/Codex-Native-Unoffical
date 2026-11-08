import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
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
  }

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

  RuntimeSnapshot _snapshot;
  RemoteHostStatus _hostStatus;

  final List<ThreadSummary> threads = [];
  final List<ThreadSummary> archivedThreads = [];
  final List<CodexModel> models = [];
  final List<HistoryTurn> historyTurns = [];
  final List<HistoryItem> historyItems = [];
  final List<RemotePairedDevice> pairedDevices = [];
  final Map<String, Uint8List> outputStore = {};
  final Map<String, OutputDescriptor> outputDescriptors = {};

  // Action audit trails for assertion verification
  final List<String> startedThreadCwds = [];
  final List<TurnStartOptions> startedTurns = [];
  final List<TurnSteerOptions> steeredTurns = [];
  final List<String> deletedThreadIds = [];
  final List<({String threadId, String name})> renamedThreads = [];
  final List<String> archivedThreadIds = [];
  final List<String> unarchivedThreadIds = [];
  final List<ThreadForkOptions> forkedThreads = [];
  final List<({String threadId, String beforeTurnId})> revertedThreads = [];
  final List<String> compactedThreadIds = [];
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
