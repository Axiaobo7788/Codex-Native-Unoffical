import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/output_models.dart';
import '../../domain/thread_models.dart';
import '../../domain/turn_gateway.dart';
import '../../domain/turn_models.dart';
import '../settings/execution_settings_controller.dart';

enum ConversationEntryKind { user, assistant, activity, review, error }

class ConversationEntry {
  const ConversationEntry({
    required this.id,
    required this.kind,
    required this.text,
    required this.completed,
    this.turnId,
    this.stockItemId,
    this.status,
    this.exitCode,
    this.commandActions = const {},
    this.commandOutput,
    this.reasoningParts = const [],
    this.attachments = const [],
    this.retiredRuntimeVersion = 0,
  });

  final String id;
  final ConversationEntryKind kind;
  final String text;
  final bool completed;
  final String? turnId;
  final String? stockItemId;
  final String? status;
  final int? exitCode;
  final Set<CommandActionKind> commandActions;
  final OutputDescriptor? commandOutput;
  final List<String> reasoningParts;
  final List<UserAttachment> attachments;
  final int retiredRuntimeVersion;

  ConversationEntry copyWith({
    String? text,
    bool? completed,
    String? turnId,
    String? stockItemId,
    String? status,
    int? exitCode,
    OutputDescriptor? commandOutput,
    List<UserAttachment>? attachments,
    List<String>? reasoningParts,
    int retiredRuntimeVersion = 0,
  }) => ConversationEntry(
    id: id,
    kind: kind,
    text: text ?? this.text,
    completed: completed ?? this.completed,
    turnId: turnId ?? this.turnId,
    stockItemId: stockItemId ?? this.stockItemId,
    status: status ?? this.status,
    exitCode: exitCode ?? this.exitCode,
    commandActions: commandActions,
    commandOutput: commandOutput ?? this.commandOutput,
    reasoningParts: reasoningParts ?? this.reasoningParts,
    attachments: attachments ?? this.attachments,
    retiredRuntimeVersion: retiredRuntimeVersion,
  );
}

class ConversationController extends ChangeNotifier {
  ConversationController({
    required this.gateway,
    required this.settings,
    this.reviewStarter,
    this.maxEntries = 200,
    this.maxEntryCharacters = 64 * 1024,
    this.maxPendingDeltaItems = 16,
    this.coalesceInterval = const Duration(milliseconds: 50),
  }) : assert(maxEntries > 0),
       assert(maxEntryCharacters >= 1024),
       assert(maxPendingDeltaItems > 0) {
    _eventSubscription = gateway.turnEvents.listen(
      _handleEvent,
      onError: _handleStreamError,
    );
  }

  static const _omittedPrefix = '[Earlier text omitted]\n';
  static const _maxMcpBaseSummaryChars = 160;
  static const _maxMcpProgressMessageChars = 240;
  static const _maxModelIdentifierChars = 120;
  static const _maxRerouteReasonChars = 160;
  static const _maxWarningChars = 320;
  static const _maxTurnPlanSteps = 50;
  static const _maxPlanStepChars = 240;
  static const _maxPlanExplanationChars = 320;

  final TurnGateway gateway;
  final ExecutionSettingsController settings;
  final ReviewStarter? reviewStarter;
  final int maxEntries;
  final int maxEntryCharacters;
  final int maxPendingDeltaItems;
  final Duration coalesceInterval;
  final List<ConversationEntry> _entries = [];
  final LinkedHashMap<String, StringBuffer> _deltaBuffers = LinkedHashMap();
  final LinkedHashMap<String, String> _reasoningDeltaBuffers = LinkedHashMap();
  final LinkedHashMap<String, _ReasoningSummaryBuffer> _reasoningSummaries =
      LinkedHashMap();
  final LinkedHashMap<String, String> _mcpBaseSummaries = LinkedHashMap();
  late final StreamSubscription<TurnEvent> _eventSubscription;
  Timer? _flushTimer;
  ThreadSummary? _thread;
  String? _activeTurnId;
  TurnPlanSnapshot? _latestTurnPlan;
  ThreadTokenUsageSnapshot? _tokenUsage;
  ModelReroutedEvent? _latestModelReroute;
  String? _processWarning;
  String? _latestWarning;
  String? _activeReviewDescription;
  var _busy = false;
  String? _startingUserEntryId;
  String? _steeringUserEntryId;
  var _startingReview = false;
  var _interruptReady = false;
  var _disposed = false;
  var _localEntrySequence = 0;
  var _bindingGeneration = 0;
  var _runtimeInvalidationVersion = 0;
  late final String _clientMessageNonce = _newClientMessageNonce();

  List<ConversationEntry> get entries => List.unmodifiable(_entries);
  ThreadSummary? get thread => _thread;
  String? get activeTurnId => _activeTurnId;
  TurnPlanSnapshot? get latestTurnPlan => _latestTurnPlan;
  ThreadTokenUsageSnapshot? get tokenUsage => _tokenUsage;
  ModelReroutedEvent? get latestModelReroute => _latestModelReroute;
  String? get latestWarning => _latestWarning;
  String? get activeReviewDescription => _activeReviewDescription;
  bool get reviewModeActive => _activeReviewDescription != null;
  bool get busy => _busy;
  int get runtimeInvalidationVersion => _runtimeInvalidationVersion;

  /// Retire only the previous-session entries after a fresh saved read. The
  /// epoch tag avoids retaining a second old working set while a read needs
  /// Retry. New accepted events create/copy untagged entries and survive.
  void reconcileRecoveredHistory(int retiredVersion) {
    if (retiredVersion <= 0) return;
    final before = _entries.length;
    _entries.removeWhere(
      (entry) => entry.retiredRuntimeVersion == retiredVersion,
    );
    if (_entries.length != before) _notify();
  }

  bool get canInterrupt => _busy && _interruptReady;
  bool get canSteer =>
      _busy &&
      _interruptReady &&
      _activeTurnId != null &&
      _steeringUserEntryId == null;
  bool get canStartReview =>
      reviewStarter != null && _thread != null && !_busy && !_startingReview;

  void dismissTelemetryNotice() {
    if (_latestWarning == null && _latestModelReroute == null) {
      return;
    }
    _processWarning = null;
    _latestWarning = null;
    _latestModelReroute = null;
    _notify();
  }

  void dismissTurnPlan() {
    if (_latestTurnPlan == null) {
      return;
    }
    _latestTurnPlan = null;
    _notify();
  }

  void bindThread(ThreadSummary? thread) {
    if (_thread?.id == thread?.id) {
      final metadataChanged =
          _thread?.name != thread?.name ||
          _thread?.status != thread?.status ||
          _thread?.preview != thread?.preview;
      _thread = thread;
      if (metadataChanged) {
        _notify();
      }
      return;
    }
    _flushTimer?.cancel();
    _flushTimer = null;
    _deltaBuffers.clear();
    _reasoningDeltaBuffers.clear();
    _reasoningSummaries.clear();
    _mcpBaseSummaries.clear();
    _entries.clear();
    _bindingGeneration += 1;
    _startingUserEntryId = null;
    _thread = thread;
    _activeTurnId = null;
    _latestTurnPlan = null;
    _tokenUsage = null;
    _latestModelReroute = null;
    _latestWarning = _processWarning;
    _activeReviewDescription = null;
    _busy = false;
    _steeringUserEntryId = null;
    _startingReview = false;
    _interruptReady = false;
    _notify();
  }

  void clearEntries() {
    _bindingGeneration += 1;
    _startingUserEntryId = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _deltaBuffers.clear();
    _reasoningDeltaBuffers.clear();
    _reasoningSummaries.clear();
    _mcpBaseSummaries.clear();
    if (_entries.isEmpty &&
        !_busy &&
        _activeTurnId == null &&
        _latestTurnPlan == null &&
        _tokenUsage == null &&
        _latestModelReroute == null &&
        _latestWarning == null &&
        _activeReviewDescription == null &&
        !_startingReview) {
      return;
    }
    _entries.clear();
    _activeTurnId = null;
    _latestTurnPlan = null;
    _tokenUsage = null;
    _latestModelReroute = null;
    _latestWarning = _processWarning;
    _activeReviewDescription = null;
    _busy = false;
    _steeringUserEntryId = null;
    _startingReview = false;
    _interruptReady = false;
    _notify();
  }

  /// Retire session-local operations without replacing the selected thread or
  /// its mounted composer. No server completion/interrupt is synthesized.
  void invalidateRuntime() {
    final hadWork = _busy || _startingReview;
    final optimisticIds = {_startingUserEntryId, _steeringUserEntryId};
    _bindingGeneration += 1;
    _runtimeInvalidationVersion += 1;
    _flushDeltas();
    _entries.removeWhere(
      (entry) => optimisticIds.contains(entry.id) && entry.stockItemId == null,
    );
    for (var i = 0; i < _entries.length; i += 1) {
      final entry = _entries[i];
      // End rendering a dead stream, without asserting a stock completion.
      _entries[i] = entry.copyWith(
        completed: true,
        status: entry.completed ? entry.status : 'unconfirmed',
        commandOutput: entry.commandOutput?.withoutSessionReference(),
        retiredRuntimeVersion: _runtimeInvalidationVersion,
      );
    }
    _reasoningSummaries.clear();
    _mcpBaseSummaries.clear();
    _startingUserEntryId = null;
    _steeringUserEntryId = null;
    _activeTurnId = null;
    _activeReviewDescription = null;
    _latestTurnPlan = null;
    _tokenUsage = null;
    _latestModelReroute = null;
    _processWarning = null;
    _latestWarning = hadWork
        ? 'The runtime disconnected. The active work is unconfirmed. '
              'Reconnect to inspect saved history before retrying.'
        : null;
    _busy = false;
    _startingReview = false;
    _interruptReady = false;
    _notify();
  }

  Future<bool> submit(
    String text, {
    List<UserAttachment> attachments = const [],
  }) async {
    if (canSteer) {
      return steer(text, attachments: attachments);
    }
    final currentThread = _thread;
    final trimmed = text.trim();
    final normalizedAttachments = normalizeUserAttachments(attachments);
    if (currentThread == null ||
        (trimmed.isEmpty && normalizedAttachments.isEmpty) ||
        _busy) {
      return false;
    }

    _busy = true;
    _interruptReady = false;
    _activeTurnId = null;
    final generation = _bindingGeneration;
    final entryId = _nextLocalUserId();
    _startingUserEntryId = entryId;
    _append(
      ConversationEntry(
        id: entryId,
        kind: ConversationEntryKind.user,
        text: _bounded(trimmed),
        completed: true,
        attachments: normalizedAttachments,
      ),
    );
    _notify();

    try {
      final turn = await gateway.startTurn(
        settings.turnOptions(
          threadId: currentThread.id,
          text: trimmed,
          attachments: normalizedAttachments,
          clientUserMessageId: entryId,
        ),
      );
      if (!_isCurrentBinding(generation)) {
        return true;
      }
      _assignTurnIdToEntry(entryId, turn.id);
      if (_startingUserEntryId == entryId &&
          _busy &&
          (_activeTurnId == null || _activeTurnId == turn.id)) {
        _activeTurnId = turn.id;
        _busy = turn.status == TurnRuntimeStatus.inProgress;
      }
      _notify();
      return true;
    } catch (error) {
      if (_isCurrentBinding(generation)) {
        if (_wasUserItemEchoed(entryId)) {
          return true;
        }
        if (_startingUserEntryId == entryId && !_interruptReady) {
          _busy = false;
          _activeTurnId = null;
        }
        _appendError(error.toString());
        _notify();
      }
      return false;
    } finally {
      if (_isCurrentBinding(generation) && _startingUserEntryId == entryId) {
        _startingUserEntryId = null;
      }
    }
  }

  Future<bool> steer(
    String text, {
    List<UserAttachment> attachments = const [],
  }) async {
    final currentThread = _thread;
    final turnId = _activeTurnId;
    final trimmed = text.trim();
    final normalizedAttachments = normalizeUserAttachments(attachments);
    if (currentThread == null ||
        turnId == null ||
        !canSteer ||
        (trimmed.isEmpty && normalizedAttachments.isEmpty)) {
      return false;
    }

    final generation = _bindingGeneration;
    final entryId = _nextLocalUserId();
    _steeringUserEntryId = entryId;
    _append(
      ConversationEntry(
        id: entryId,
        kind: ConversationEntryKind.user,
        text: _bounded(trimmed),
        completed: true,
        turnId: turnId,
        attachments: normalizedAttachments,
      ),
    );
    _notify();

    try {
      final steeredTurnId = await gateway.steerTurn(
        TurnSteerOptions(
          threadId: currentThread.id,
          expectedTurnId: turnId,
          text: trimmed,
          attachments: normalizedAttachments,
          clientUserMessageId: entryId,
        ),
      );
      if (_isCurrentBinding(generation)) {
        if (_busy && _activeTurnId == turnId) {
          _activeTurnId = steeredTurnId;
        }
        _assignTurnIdToEntry(entryId, steeredTurnId);
      }
      return true;
    } catch (error) {
      if (_isCurrentBinding(generation)) {
        if (_wasUserItemEchoed(entryId)) {
          return true;
        }
        _entries.removeWhere((entry) => entry.id == entryId);
        _appendError(error.toString());
      }
      return false;
    } finally {
      if (_isCurrentBinding(generation)) {
        if (_steeringUserEntryId == entryId) {
          _steeringUserEntryId = null;
        }
        _notify();
      }
    }
  }

  Future<bool> startReview(
    ReviewTarget target, {
    ReviewStarter? starter,
  }) async {
    final currentThread = _thread;
    final effectiveStarter = starter ?? reviewStarter;
    if (currentThread == null ||
        effectiveStarter == null ||
        _busy ||
        _startingReview) {
      return false;
    }

    final generation = _bindingGeneration;
    _startingReview = true;
    _busy = true;
    _notify();
    try {
      final handle = await effectiveStarter(
        ReviewStartOptions(threadId: currentThread.id, target: target),
      );
      if (!_isCurrentBinding(generation) || _thread?.id != currentThread.id) {
        return true;
      }
      // Do not resurrect an already-completed review if its lifecycle raced
      // ahead of the response.
      if (_busy) {
        _activeTurnId ??= handle.turn.id;
        _busy = handle.turn.status == TurnRuntimeStatus.inProgress;
      }
      _notify();
      return true;
    } catch (error) {
      if (_isCurrentBinding(generation) && _thread?.id == currentThread.id) {
        _busy = false;
        _interruptReady = false;
        _activeTurnId = null;
        _activeReviewDescription = null;
        _appendError(error.toString());
        _notify();
      }
      return false;
    } finally {
      if (_isCurrentBinding(generation)) {
        _startingReview = false;
        _notify();
      }
    }
  }

  Future<void> interrupt() async {
    final currentThread = _thread;
    final turnId = _activeTurnId;
    if (currentThread == null || turnId == null || !canInterrupt) {
      return;
    }
    final generation = _bindingGeneration;
    try {
      await gateway.interruptTurn(threadId: currentThread.id, turnId: turnId);
    } catch (error) {
      if (!_isCurrentBinding(generation)) return;
      _appendError(error.toString());
      _notify();
    }
  }

  void _assignTurnIdToEntry(String entryId, String turnId) {
    if (turnId.isEmpty) {
      return;
    }
    final index = _entries.indexWhere((entry) => entry.id == entryId);
    if (index != -1 && _entries[index].stockItemId == null) {
      _entries[index] = _entries[index].copyWith(turnId: turnId);
    }
  }

  void _assignTurnIdToLatestUnassignedUserEntry(String turnId) {
    if (turnId.isEmpty) {
      return;
    }
    for (var i = _entries.length - 1; i >= 0; i -= 1) {
      final entry = _entries[i];
      if (entry.kind == ConversationEntryKind.user) {
        if (entry.turnId == null || entry.turnId!.isEmpty) {
          _entries[i] = entry.copyWith(turnId: turnId);
        }
        break;
      }
    }
  }

  void _handleEvent(TurnEvent event) {
    if (_disposed) {
      return;
    }
    if (event case TurnWarningEvent(threadId: '', message: final message)) {
      _processWarning = _truncate(message.trim(), _maxWarningChars);
      _latestWarning = _processWarning;
      _notify();
      return;
    }
    if (_thread == null) {
      return;
    }
    if (event.threadId.isNotEmpty && event.threadId != _thread!.id) {
      return;
    }
    switch (event) {
      case TurnStartedEvent():
        _activeTurnId = event.turnId;
        _assignTurnIdToLatestUnassignedUserEntry(event.turnId);
        _busy = true;
        _interruptReady = true;
        _notify();
      case TurnCompletedEvent():
        _flushDeltas();
        _finalizeTurnEntries(event.turnId, event.status);
        _activeTurnId = null;
        _busy = false;
        _steeringUserEntryId = null;
        _interruptReady = false;
        _activeReviewDescription = null;
        if (event.errorMessage case final message?) {
          _appendError(
            message,
            turnId: event.turnId,
            status: event.status == TurnRuntimeStatus.interrupted
                ? 'interrupted'
                : 'failed',
          );
        } else if (event.status == TurnRuntimeStatus.interrupted) {
          _appendError(
            'Turn interrupted.',
            turnId: event.turnId,
            status: 'interrupted',
          );
        }
        _notify();
      case UserMessageEvent():
        _handleUserMessage(event);
      case AssistantTextDeltaEvent():
        _bufferDelta(event.itemId, event.delta);
      case AssistantMessageEvent():
        _completeAssistantMessage(event);
      case ReasoningSummaryDeltaEvent():
        _bufferReasoningDelta(
          event.itemId,
          event.turnId,
          event.summaryIndex,
          event.delta,
        );
      case McpToolCallProgressEvent():
        final base = _mcpBaseSummaries[event.itemId] ?? 'MCP';
        final progress = _truncate(
          event.message.trim(),
          _maxMcpProgressMessageChars,
        );
        final text = progress.isEmpty ? base : '$base — $progress';
        _upsert(
          ConversationEntry(
            id: event.itemId,
            kind: ConversationEntryKind.activity,
            text: _bounded(text),
            completed: false,
            turnId: event.turnId,
            status: 'inProgress',
          ),
        );
        _notify();
      case TurnPlanUpdatedEvent():
        final rawPlan = event.plan;
        final rawExplanation = rawPlan.explanation?.trim();
        final boundedExplanation =
            rawExplanation == null || rawExplanation.isEmpty
            ? null
            : _truncate(rawExplanation, _maxPlanExplanationChars);
        final boundedSteps = List<TurnPlanStepModel>.unmodifiable(
          rawPlan.steps
              .take(_maxTurnPlanSteps)
              .map(
                (s) => TurnPlanStepModel(
                  step: _truncate(s.step.trim(), _maxPlanStepChars),
                  status: s.status,
                ),
              ),
        );
        final plan = TurnPlanSnapshot(
          threadId: rawPlan.threadId,
          turnId: rawPlan.turnId,
          steps: boundedSteps,
          explanation: boundedExplanation,
        );
        _latestTurnPlan = plan;
        final activeStep = plan.steps
            .where((s) => s.status == TurnPlanStepStatus.inProgress)
            .map((s) => s.step)
            .firstOrNull;
        final headline =
            activeStep ??
            plan.explanation ??
            (plan.steps.isNotEmpty ? plan.steps.first.step : null);
        final summary = headline == null || headline.isEmpty
            ? 'Plan updated (${plan.completedCount}/${plan.steps.length} completed)'
            : 'Plan (${plan.completedCount}/${plan.steps.length} completed): $headline';
        _upsert(
          ConversationEntry(
            id: 'turn-plan-${event.turnId}',
            kind: ConversationEntryKind.activity,
            text: _bounded(summary),
            completed: plan.allCompleted,
            turnId: event.turnId,
            status: plan.allCompleted ? 'completed' : 'inProgress',
          ),
        );
        _notify();
      case ThreadTokenUsageUpdatedEvent():
        _tokenUsage = event.usage;
        _notify();
      case HookActivityEvent():
        final effectiveTurnId = event.turnId.isEmpty
            ? _activeTurnId
            : event.turnId;
        _upsert(
          ConversationEntry(
            id: 'hook-${event.runId}',
            kind: ConversationEntryKind.activity,
            text: _bounded(event.formattedSummary),
            completed: event.completed,
            turnId: effectiveTurnId,
            status: event.status,
          ),
        );
        _notify();
      case ModelReroutedEvent():
        final boundedReroute = ModelReroutedEvent(
          threadId: event.threadId,
          turnId: event.turnId,
          fromModel: _truncate(
            event.fromModel.trim(),
            _maxModelIdentifierChars,
          ),
          toModel: _truncate(event.toModel.trim(), _maxModelIdentifierChars),
          reason: _truncate(event.reason.trim(), _maxRerouteReasonChars),
        );
        _latestModelReroute = boundedReroute;
        _upsert(
          ConversationEntry(
            id: 'model-reroute-${event.turnId}',
            kind: ConversationEntryKind.activity,
            text: _bounded(
              'Model rerouted: ${boundedReroute.fromModel} → ${boundedReroute.toModel} (${boundedReroute.reason})',
            ),
            completed: true,
            turnId: event.turnId,
            status: 'completed',
          ),
        );
        _notify();
      case TurnWarningEvent():
        _latestWarning = _truncate(event.message.trim(), _maxWarningChars);
        _notify();
      case ReviewModeEvent():
        _activeReviewDescription = event.phase == ReviewModePhase.entered
            ? _truncate(event.review, _maxWarningChars)
            : null;
        _upsert(
          ConversationEntry(
            id: event.itemId,
            kind: ConversationEntryKind.review,
            text: _bounded(event.summary),
            completed: event.completed,
            turnId: event.turnId,
            status: event.status,
          ),
        );
        _notify();
      case ActivityEvent():
        final bufferedReasoning = _reasoningDeltaBuffers.remove(event.itemId);
        if (bufferedReasoning != null) {
          _flushReasoningDelta(event.itemId, bufferedReasoning);
        }
        var summary = event.summary;
        if (summary == 'Reasoning') {
          if (event is ReasoningItemEvent && event.summaryParts.isNotEmpty) {
            _reasoningState(event.itemId).replace(event.summaryParts);
          }
          final accumulated = _reasoningSummaries[event.itemId]?.text;
          if (accumulated != null && accumulated.isNotEmpty) {
            summary = _reasoningText(accumulated);
          }
        } else if (summary.startsWith('MCP: ')) {
          _rememberBounded(
            _mcpBaseSummaries,
            event.itemId,
            _truncate(summary, _maxMcpBaseSummaryChars),
          );
        }
        _upsert(
          ConversationEntry(
            id: event.itemId,
            kind: ConversationEntryKind.activity,
            text: _bounded(summary),
            reasoningParts:
                summary == 'Reasoning' || summary.startsWith('Reasoning: ')
                ? _reasoningSummaries[event.itemId]?.parts ?? const []
                : const [],
            completed: event.completed,
            turnId: event.turnId,
            status: event.status,
            exitCode: event.exitCode,
            commandActions: event.commandActions,
            commandOutput: event.commandOutput,
          ),
        );
        if (_deltaBuffers.isEmpty && _reasoningDeltaBuffers.isEmpty) {
          _flushTimer?.cancel();
          _flushTimer = null;
        }
        _notify();
      case TurnErrorEvent():
        _appendError(
          event.willRetry ? '${event.message} (retrying)' : event.message,
          turnId: event.turnId,
          status: event.willRetry ? 'retrying' : 'failed',
        );
        _notify();
      case TurnDiffUpdatedEvent():
      // Diff state has its own bounded projection and view controller.
    }
  }

  void _rememberBounded(
    LinkedHashMap<String, String> map,
    String key,
    String value,
  ) {
    map.remove(key);
    map[key] = value;
    while (map.length > maxEntries) {
      map.remove(map.keys.first);
    }
  }

  void _bufferDelta(String itemId, String delta) {
    var buffer = _deltaBuffers[itemId];
    if (buffer == null) {
      if (_deltaBuffers.length >= maxPendingDeltaItems) {
        final oldestId = _deltaBuffers.keys.first;
        _flushDelta(oldestId, _deltaBuffers.remove(oldestId)!);
      }
      buffer = StringBuffer();
      _deltaBuffers[itemId] = buffer;
    }
    buffer.write(delta);
    _flushTimer ??= Timer(coalesceInterval, _flushDeltas);
  }

  _ReasoningSummaryBuffer _reasoningState(String itemId) {
    final previous = _reasoningSummaries.remove(itemId);
    final state =
        previous ??
        _ReasoningSummaryBuffer(
          min(
            ReasoningItemEvent.maxSummaryCharacters,
            maxEntryCharacters - 'Reasoning: '.length,
          ),
        );
    _reasoningSummaries[itemId] = state;
    while (_reasoningSummaries.length > maxEntries) {
      final oldestId = _reasoningSummaries.keys.first;
      _reasoningSummaries.remove(oldestId);
      _reasoningDeltaBuffers.remove(oldestId);
    }
    return state;
  }

  void _bufferReasoningDelta(
    String itemId,
    String turnId,
    int summaryIndex,
    String delta,
  ) {
    if (summaryIndex < 0 || delta.isEmpty) return;
    if (!_reasoningDeltaBuffers.containsKey(itemId) &&
        _reasoningDeltaBuffers.length >= maxPendingDeltaItems) {
      final oldestId = _reasoningDeltaBuffers.keys.first;
      _flushReasoningDelta(oldestId, _reasoningDeltaBuffers.remove(oldestId)!);
    }
    _reasoningState(itemId).append(summaryIndex, delta);
    _reasoningDeltaBuffers[itemId] = turnId;
    _flushTimer ??= Timer(coalesceInterval, _flushDeltas);
  }

  static String _truncate(String value, int maxChars) =>
      value.length <= maxChars ? value : '${value.substring(0, maxChars)}…';

  void _completeAssistantMessage(AssistantMessageEvent event) {
    final buffered = _deltaBuffers.remove(event.itemId);
    if (buffered != null) {
      _flushDelta(event.itemId, buffered);
    }
    final currentIndex = _entries.indexWhere(
      (entry) => entry.id == event.itemId,
    );
    final currentText = currentIndex == -1 ? '' : _entries[currentIndex].text;
    _upsert(
      ConversationEntry(
        id: event.itemId,
        kind: ConversationEntryKind.assistant,
        text: _bounded(event.text.isEmpty ? currentText : event.text),
        completed: event.completed,
        turnId: event.turnId,
      ),
    );
    if (_deltaBuffers.isEmpty && _reasoningDeltaBuffers.isEmpty) {
      _flushTimer?.cancel();
      _flushTimer = null;
    }
    _notify();
  }

  void _flushDeltas() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_deltaBuffers.isEmpty && _reasoningDeltaBuffers.isEmpty) {
      return;
    }
    final buffered = Map<String, StringBuffer>.from(_deltaBuffers);
    _deltaBuffers.clear();
    for (final entry in buffered.entries) {
      _flushDelta(entry.key, entry.value);
    }
    final bufferedReasoning = Map<String, String>.from(_reasoningDeltaBuffers);
    _reasoningDeltaBuffers.clear();
    for (final entry in bufferedReasoning.entries) {
      _flushReasoningDelta(entry.key, entry.value);
    }
    _notify();
  }

  void _flushReasoningDelta(String itemId, String turnId) {
    final state = _reasoningSummaries[itemId];
    if (state == null) return;
    final boundedSummary = state.text;
    final index = _entries.indexWhere((entry) => entry.id == itemId);
    final isAlreadyCompleted = index != -1 && _entries[index].completed;
    final status = index != -1
        ? (_entries[index].status ?? 'inProgress')
        : 'inProgress';
    _upsert(
      ConversationEntry(
        id: itemId,
        kind: ConversationEntryKind.activity,
        text: _reasoningText(boundedSummary),
        reasoningParts: state.parts,
        completed: isAlreadyCompleted,
        turnId: turnId.isEmpty ? _activeTurnId : turnId,
        status: status,
      ),
    );
  }

  String _reasoningText(String summary) {
    if (summary.isEmpty) return 'Reasoning';
    const prefix = 'Reasoning: ';
    final limit = min(
      ReasoningItemEvent.maxSummaryCharacters,
      maxEntryCharacters - prefix.length,
    );
    final bounded = summary.length <= limit
        ? summary
        : '${ReasoningItemEvent.prefixAtCodePointBoundary(summary, limit - 1)}…';
    return '$prefix$bounded';
  }

  void _flushDelta(String itemId, StringBuffer buffer) {
    final delta = buffer.toString();
    final index = _entries.indexWhere((entry) => entry.id == itemId);
    if (index == -1) {
      _append(
        ConversationEntry(
          id: itemId,
          kind: ConversationEntryKind.assistant,
          text: _bounded(delta),
          completed: false,
          turnId: _activeTurnId,
        ),
      );
      return;
    }
    final existing = _entries[index];
    _entries[index] = existing.copyWith(
      text: _bounded('${existing.text}$delta'),
      completed: false,
      turnId: existing.turnId ?? _activeTurnId,
    );
  }

  void _finalizeTurnEntries(String turnId, TurnRuntimeStatus turnStatus) {
    final fallbackStatus = switch (turnStatus) {
      TurnRuntimeStatus.interrupted => 'interrupted',
      TurnRuntimeStatus.failed => 'failed',
      _ => 'completed',
    };
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry.completed) {
        continue;
      }
      if (turnId.isNotEmpty && entry.turnId != null && entry.turnId != turnId) {
        continue;
      }
      final currentStatus = entry.status;
      final resolvedStatus =
          currentStatus == null ||
              currentStatus == 'inProgress' ||
              currentStatus == 'running'
          ? fallbackStatus
          : currentStatus;
      _entries[i] = entry.copyWith(
        completed: true,
        turnId: entry.turnId ?? (turnId.isEmpty ? null : turnId),
        status: resolvedStatus,
      );
    }
  }

  void _upsert(ConversationEntry entry) {
    final index = _entries.indexWhere((candidate) => candidate.id == entry.id);
    if (index == -1) {
      _append(entry);
    } else {
      _entries[index] = entry;
    }
  }

  void _handleUserMessage(UserMessageEvent event) {
    if (_entries.any((entry) => entry.stockItemId == event.itemId)) {
      return;
    }
    final clientId = event.clientMessageId;
    final optimisticIndex = clientId == null
        ? -1
        : _entries.indexWhere(
            (entry) =>
                entry.kind == ConversationEntryKind.user &&
                entry.id == clientId &&
                entry.stockItemId == null,
          );
    if (optimisticIndex != -1) {
      // Keep the existing row key and the locally authored attachment details.
      _entries[optimisticIndex] = _entries[optimisticIndex].copyWith(
        turnId: event.turnId,
        stockItemId: event.itemId,
      );
    } else {
      _append(
        ConversationEntry(
          id: event.itemId,
          stockItemId: event.itemId,
          kind: ConversationEntryKind.user,
          text: _bounded(event.text),
          completed: true,
          turnId: event.turnId,
          attachments: event.attachments,
        ),
      );
    }
    _notify();
  }

  bool _wasUserItemEchoed(String entryId) =>
      _entries.any((entry) => entry.id == entryId && entry.stockItemId != null);

  bool _isCurrentBinding(int generation) =>
      !_disposed && _bindingGeneration == generation;

  String _nextLocalUserId() =>
      'local-user-$_clientMessageNonce-${_localEntrySequence++}';

  static String _newClientMessageNonce() {
    final random = Random.secure();
    final nonce = StringBuffer();
    for (var index = 0; index < 16; index += 1) {
      nonce.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return nonce.toString();
  }

  void _appendError(
    String message, {
    String? turnId,
    String status = 'failed',
  }) {
    _append(
      ConversationEntry(
        id: 'local-error-${_localEntrySequence++}',
        kind: ConversationEntryKind.error,
        text: _bounded(message),
        completed: true,
        turnId: turnId,
        status: status,
      ),
    );
  }

  void _append(ConversationEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  String _bounded(String value) {
    if (value.length <= maxEntryCharacters) {
      return value;
    }
    final retained = maxEntryCharacters - _omittedPrefix.length;
    return '$_omittedPrefix${value.substring(value.length - retained)}';
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (_disposed || _thread == null) {
      return;
    }
    _appendError('Turn protocol error: $error');
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _deltaBuffers.clear();
    _reasoningDeltaBuffers.clear();
    _reasoningSummaries.clear();
    _mcpBaseSummaries.clear();
    unawaited(_eventSubscription.cancel());
    super.dispose();
  }
}

/// Sparse stock summary indices are keys, never array allocation sizes.
/// Storage is bounded before concatenation; rendering occurs only on a flush.
class _ReasoningSummaryBuffer {
  _ReasoningSummaryBuffer(this.maxCharacters);
  final int maxCharacters;
  final Map<int, StringBuffer> _parts = {0: StringBuffer()};
  var _characters = 0;
  var _truncated = false;
  List<String>? _cachedParts;

  void append(int index, String delta) {
    if (delta.isEmpty) return;
    _cachedParts = null;
    var part = _parts[index];
    if (part == null) {
      if (_parts.length >= ReasoningItemEvent.maxSummaryParts ||
          _characters + (_parts.isEmpty ? 0 : 2) >= maxCharacters) {
        _truncated = true;
        return;
      }
      _characters += _parts.isEmpty ? 0 : 2;
      part = StringBuffer();
      _parts[index] = part;
    }
    final remaining = maxCharacters - _characters;
    final accepted = delta.length <= remaining
        ? delta
        : ReasoningItemEvent.prefixAtCodePointBoundary(delta, remaining);
    part.write(accepted);
    _characters += accepted.length;
    _truncated |= accepted.length < delta.length;
  }

  void replace(List<String> parts) {
    _parts
      ..clear()
      ..[0] = StringBuffer();
    _characters = 0;
    _truncated = false;
    _cachedParts = null;
    final count = min(parts.length, ReasoningItemEvent.maxSummaryParts);
    for (var index = 0; index < count; index++) {
      append(index, parts[index]);
    }
    _truncated |= parts.length > count;
  }

  List<String> get parts {
    if (_cachedParts case final cached?) return cached;
    final indices = _parts.keys.toList()..sort();
    final result = indices.map((index) => _parts[index].toString()).toList();
    if (_truncated && result.isNotEmpty) {
      final last = result.removeLast();
      final prefix = _characters < maxCharacters
          ? last
          : ReasoningItemEvent.prefixAtCodePointBoundary(
              last,
              max(0, last.length - 1),
            );
      result.add('$prefix…');
    }
    return _cachedParts = List.unmodifiable(result);
  }

  String get text => parts.join('\n\n');
}
