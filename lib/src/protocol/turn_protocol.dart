import '../domain/execution_settings.dart';
import '../domain/turn_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';
import 'unified_diff_parser.dart';

final class TurnProtocolAdapter {
  static const _maxTurnPlanSteps = 50;
  static const _maxPlanStepLength = 240;
  static const _maxPlanExplanationLength = 320;
  static const _maxReasoningDeltaLength = 240;
  static const _maxProgressMessageLength = 240;
  static const _maxHookMessageLength = 240;
  static const _maxModelIdentifierLength = 120;
  static const _maxRerouteReasonLength = 160;
  static const _maxToolIdentifierLength = 80;
  static const _maxWarningMessageLength = 320;

  TurnProtocolAdapter({
    required this.request,
    required Stream<CodexNotification> notifications,
    UnifiedDiffParser diffParser = const UnifiedDiffParser(),
  }) : events = notifications
           .map((notification) => _parseNotification(notification, diffParser))
           .where((event) => event != null)
           .cast<TurnEvent>();

  final ProtocolRequest request;
  final Stream<TurnEvent> events;

  Future<TurnHandle> startTurn(TurnStartOptions options) async {
    final response = await request('turn/start', {
      'threadId': options.threadId,
      'input': _serializeUserInput(options.text, options.attachments),
      if (options.model != null) 'model': options.model,
      if (options.reasoningEffort != null) 'effort': options.reasoningEffort,
      if (options.approvalPolicy case final approvalPolicy?)
        'approvalPolicy': _approvalPolicy(approvalPolicy),
      if (options.sandbox case final sandbox?)
        'sandboxPolicy': _sandboxPolicy(sandbox),
    });
    final turn = _requiredObject(response, 'turn', 'turn/start response');
    return _parseTurnHandle(turn);
  }

  Future<String> steerTurn(TurnSteerOptions options) async {
    final response = await request('turn/steer', {
      'threadId': options.threadId,
      'expectedTurnId': options.expectedTurnId,
      'input': _serializeUserInput(options.text, options.attachments),
    });
    return _requiredString(response, 'turnId');
  }

  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    await request('turn/interrupt', {'threadId': threadId, 'turnId': turnId});
  }

  static List<JsonObject> _serializeUserInput(
    String text,
    List<UserAttachment> attachments,
  ) {
    final normalizedAttachments = normalizeUserAttachments(attachments);
    final items = <JsonObject>[];
    if (text.isNotEmpty || normalizedAttachments.isEmpty) {
      items.add({'type': 'text', 'text': text, 'text_elements': <Object?>[]});
    }
    for (final attachment in normalizedAttachments) {
      final path = attachment.path;
      switch (attachment.kind) {
        case UserAttachmentKind.image:
          final value = (path != null && path.isNotEmpty)
              ? path
              : attachment.label;
          if (_isUrlOrDataUri(value)) {
            items.add({'type': 'image', 'url': value});
          } else {
            items.add({'type': 'localImage', 'path': value});
          }
        case UserAttachmentKind.skill:
          final rawName = attachment.label.startsWith(r'$')
              ? attachment.label.substring(1)
              : attachment.label;
          items.add({'type': 'skill', 'name': rawName, 'path': path ?? ''});
        case UserAttachmentKind.file || UserAttachmentKind.mention:
          items.add({
            'type': 'mention',
            'name': attachment.label,
            'path': (path != null && path.isNotEmpty) ? path : attachment.label,
          });
        case UserAttachmentKind.pastedText || UserAttachmentKind.ideContext:
          final snippet = attachment.preview;
          items.add({
            'type': 'text',
            'text': (snippet != null && snippet.isNotEmpty)
                ? snippet
                : attachment.label,
            'text_elements': <Object?>[],
          });
      }
    }
    return items;
  }

  static bool _isUrlOrDataUri(String value) =>
      value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('data:');

  static TurnEvent? _parseNotification(
    CodexNotification notification,
    UnifiedDiffParser diffParser,
  ) {
    final params = notification.params;
    return switch (notification.method) {
      'turn/started' => _parseTurnStarted(params),
      'turn/completed' => _parseTurnCompleted(params),
      'item/agentMessage/delta' => AssistantTextDeltaEvent(
        threadId: _requiredString(params, 'threadId'),
        turnId: _requiredString(params, 'turnId'),
        itemId: _requiredString(params, 'itemId'),
        delta: _requiredString(params, 'delta'),
      ),
      'item/started' => _parseItem(params, completed: false),
      'item/completed' => _parseItem(params, completed: true),
      'turn/diff/updated' => TurnDiffUpdatedEvent(
        snapshot: diffParser.parse(
          threadId: _requiredString(params, 'threadId'),
          turnId: _requiredString(params, 'turnId'),
          diff: _requiredString(params, 'diff'),
        ),
      ),
      'turn/plan/updated' => _parseTurnPlanUpdated(params),
      'thread/tokenUsage/updated' => _parseThreadTokenUsageUpdated(params),
      'item/reasoning/summaryTextDelta' => _parseReasoningSummaryDelta(params),
      'item/mcpToolCall/progress' => _parseMcpToolCallProgress(params),
      'hook/started' => _parseHookNotification(params, completed: false),
      'hook/completed' => _parseHookNotification(params, completed: true),
      'model/rerouted' => _parseModelRerouted(params),
      'warning' => _parseWarning(params),
      'error' => _parseError(params),
      _ => null,
    };
  }

  static TurnPlanUpdatedEvent _parseTurnPlanUpdated(JsonObject params) {
    final threadId = _requiredString(params, 'threadId');
    final turnId = _requiredString(params, 'turnId');
    final rawPlan = params['plan'];
    if (rawPlan is! List<Object?>) {
      throw const ProtocolViolation('turn/plan/updated plan must be an array.');
    }
    final rawExplanation = _optionalString(params, 'explanation')?.trim();
    final explanation = rawExplanation == null || rawExplanation.isEmpty
        ? null
        : _truncate(rawExplanation, _maxPlanExplanationLength);
    final steps = <TurnPlanStepModel>[];
    for (final item in rawPlan) {
      if (steps.length >= _maxTurnPlanSteps) {
        break;
      }
      if (item is! Map<String, Object?>) {
        throw const ProtocolViolation('TurnPlanStep must be an object.');
      }
      final stepText = _requiredString(item, 'step').trim();
      final statusRaw = _requiredString(item, 'status');
      steps.add(
        TurnPlanStepModel(
          step: _truncate(stepText, _maxPlanStepLength),
          status: _planStepStatus(statusRaw),
        ),
      );
    }
    return TurnPlanUpdatedEvent(
      plan: TurnPlanSnapshot(
        threadId: threadId,
        turnId: turnId,
        steps: List<TurnPlanStepModel>.unmodifiable(steps),
        explanation: explanation,
      ),
    );
  }

  static ThreadTokenUsageUpdatedEvent _parseThreadTokenUsageUpdated(
    JsonObject params,
  ) {
    final threadId = _requiredString(params, 'threadId');
    final turnId = _requiredString(params, 'turnId');
    final tokenUsage = _requiredObject(
      params,
      'tokenUsage',
      'thread/tokenUsage/updated',
    );
    final last = _parseTokenUsageBreakdown(
      _requiredObject(tokenUsage, 'last', 'ThreadTokenUsage'),
    );
    final total = _parseTokenUsageBreakdown(
      _requiredObject(tokenUsage, 'total', 'ThreadTokenUsage'),
    );
    final rawWindow = tokenUsage['modelContextWindow'];
    if (rawWindow != null && rawWindow is! int) {
      throw const ProtocolViolation(
        'ThreadTokenUsage field modelContextWindow must be an integer or null.',
      );
    }
    return ThreadTokenUsageUpdatedEvent(
      usage: ThreadTokenUsageSnapshot(
        threadId: threadId,
        turnId: turnId,
        last: last,
        total: total,
        modelContextWindow: rawWindow is int && rawWindow > 0
            ? rawWindow
            : null,
      ),
    );
  }

  static TokenUsageBreakdownModel _parseTokenUsageBreakdown(JsonObject raw) {
    return TokenUsageBreakdownModel(
      inputTokens: _nonNegativeInt(raw, 'inputTokens'),
      cachedInputTokens: _nonNegativeInt(raw, 'cachedInputTokens'),
      cacheWriteInputTokens: raw['cacheWriteInputTokens'] == null
          ? 0
          : _nonNegativeInt(raw, 'cacheWriteInputTokens'),
      outputTokens: _nonNegativeInt(raw, 'outputTokens'),
      reasoningOutputTokens: _nonNegativeInt(raw, 'reasoningOutputTokens'),
      totalTokens: _nonNegativeInt(raw, 'totalTokens'),
    );
  }

  static ReasoningSummaryDeltaEvent _parseReasoningSummaryDelta(
    JsonObject params,
  ) {
    final rawIndex = params['summaryIndex'];
    if (rawIndex is! int || rawIndex < 0) {
      throw const ProtocolViolation(
        'ReasoningSummaryTextDelta field summaryIndex must be a non-negative integer.',
      );
    }
    return ReasoningSummaryDeltaEvent(
      threadId: _requiredString(params, 'threadId'),
      turnId: _requiredString(params, 'turnId'),
      itemId: _requiredString(params, 'itemId'),
      summaryIndex: rawIndex,
      delta: _truncate(
        _requiredString(params, 'delta'),
        _maxReasoningDeltaLength,
      ),
    );
  }

  static McpToolCallProgressEvent _parseMcpToolCallProgress(JsonObject params) {
    return McpToolCallProgressEvent(
      threadId: _requiredString(params, 'threadId'),
      turnId: _requiredString(params, 'turnId'),
      itemId: _requiredString(params, 'itemId'),
      message: _truncate(
        _requiredString(params, 'message').trim(),
        _maxProgressMessageLength,
      ),
    );
  }

  static HookActivityEvent _parseHookNotification(
    JsonObject params, {
    required bool completed,
  }) {
    final threadId = _requiredString(params, 'threadId');
    final turnId = _optionalString(params, 'turnId') ?? '';
    final run = _requiredObject(
      params,
      'run',
      completed ? 'hook/completed' : 'hook/started',
    );
    final runId = _requiredString(run, 'id');
    final eventName = _requiredString(run, 'eventName');
    final handlerType = _requiredString(run, 'handlerType');
    final executionMode = _requiredString(run, 'executionMode');
    final scope = _requiredString(run, 'scope');
    final status = _requiredString(run, 'status');
    final rawStatusMessage = _optionalString(run, 'statusMessage')?.trim();
    final statusMessage = rawStatusMessage == null || rawStatusMessage.isEmpty
        ? null
        : _truncate(rawStatusMessage, _maxHookMessageLength);
    final rawDuration = run['durationMs'];
    if (rawDuration != null && rawDuration is! int) {
      throw const ProtocolViolation(
        'HookRunSummary field durationMs must be an integer or null.',
      );
    }
    String? entrySummary;
    final entries = run['entries'];
    if (entries is List<Object?>) {
      for (final rawEntry in entries.whereType<Map<String, Object?>>()) {
        final text = rawEntry['text'];
        if (text is String && text.trim().isNotEmpty) {
          entrySummary = _truncate(text.trim(), _maxHookMessageLength);
          break;
        }
      }
    }
    return HookActivityEvent(
      threadId: threadId,
      turnId: turnId,
      runId: runId,
      eventName: eventName,
      handlerType: handlerType,
      executionMode: executionMode,
      scope: scope,
      status: status,
      completed: completed,
      statusMessage: statusMessage,
      durationMs: rawDuration is int && rawDuration >= 0 ? rawDuration : null,
      entrySummary: entrySummary,
    );
  }

  static ModelReroutedEvent _parseModelRerouted(JsonObject params) {
    return ModelReroutedEvent(
      threadId: _requiredString(params, 'threadId'),
      turnId: _requiredString(params, 'turnId'),
      fromModel: _truncate(
        _requiredString(params, 'fromModel').trim(),
        _maxModelIdentifierLength,
      ),
      toModel: _truncate(
        _requiredString(params, 'toModel').trim(),
        _maxModelIdentifierLength,
      ),
      reason: _truncate(
        _requiredString(params, 'reason').trim(),
        _maxRerouteReasonLength,
      ),
    );
  }

  static TurnWarningEvent _parseWarning(JsonObject params) {
    final message = _truncate(
      _requiredString(params, 'message').trim(),
      _maxWarningMessageLength,
    );
    return TurnWarningEvent(
      threadId: _optionalString(params, 'threadId') ?? '',
      message: message,
    );
  }

  static TurnStartedEvent _parseTurnStarted(JsonObject params) {
    final turn = _requiredObject(params, 'turn', 'turn/started');
    return TurnStartedEvent(
      threadId: _requiredString(params, 'threadId'),
      turnId: _requiredString(turn, 'id'),
    );
  }

  static TurnCompletedEvent _parseTurnCompleted(JsonObject params) {
    final turn = _requiredObject(params, 'turn', 'turn/completed');
    final error = turn['error'];
    String? errorMessage;
    if (error != null) {
      if (error is! Map<String, Object?>) {
        throw const ProtocolViolation('Turn error must be an object or null.');
      }
      errorMessage = _requiredString(error, 'message');
    }
    return TurnCompletedEvent(
      threadId: _requiredString(params, 'threadId'),
      turnId: _requiredString(turn, 'id'),
      status: _status(_requiredString(turn, 'status')),
      errorMessage: errorMessage,
    );
  }

  static TurnEvent? _parseItem(JsonObject params, {required bool completed}) {
    final item = _requiredObject(params, 'item', 'item lifecycle');
    final type = _requiredString(item, 'type');
    final threadId = _requiredString(params, 'threadId');
    final turnId = _requiredString(params, 'turnId');
    final itemId = _requiredString(item, 'id');

    if (type == 'userMessage') {
      return null;
    }
    if (type == 'agentMessage') {
      return AssistantMessageEvent(
        threadId: threadId,
        turnId: turnId,
        itemId: itemId,
        text: _requiredString(item, 'text'),
        completed: completed,
      );
    }

    return ActivityEvent(
      threadId: threadId,
      turnId: turnId,
      itemId: itemId,
      summary: _activitySummary(type, item),
      status: _activityStatus(item, completed),
      completed: completed,
    );
  }

  static TurnErrorEvent _parseError(JsonObject params) {
    final error = _requiredObject(params, 'error', 'error notification');
    return TurnErrorEvent(
      threadId: _requiredString(params, 'threadId'),
      turnId: _requiredString(params, 'turnId'),
      message: _requiredString(error, 'message'),
      willRetry: _requiredBool(params, 'willRetry'),
    );
  }

  static TurnHandle _parseTurnHandle(JsonObject turn) => TurnHandle(
    id: _requiredString(turn, 'id'),
    status: _status(_requiredString(turn, 'status')),
  );

  static String _activitySummary(
    String type,
    JsonObject item,
  ) => switch (type) {
    'commandExecution' =>
      'Command: ${_truncate(_requiredString(item, 'command'), 240)}',
    'fileChange' => _fileChangeSummary(item['changes']),
    'mcpToolCall' =>
      'MCP: ${_truncate(_requiredString(item, 'server').trim(), _maxToolIdentifierLength)}/${_truncate(_requiredString(item, 'tool').trim(), _maxToolIdentifierLength)}',
    'dynamicToolCall' =>
      'Tool: ${_truncate(_requiredString(item, 'tool').trim(), _maxToolIdentifierLength)}',
    'collabAgentToolCall' =>
      'Collaboration: ${_truncate(_requiredString(item, 'tool').trim(), _maxToolIdentifierLength)}',
    'subAgentActivity' => 'Sub-agent activity',
    'functionCallOutput' =>
      'Function output: ${_truncate(_requiredString(item, 'name').trim(), _maxToolIdentifierLength)}',
    'plan' || 'todo' || 'todoList' => _planSummary(item),
    'reasoning' => 'Reasoning',
    'webSearch' => () {
      final query = item['query'];
      if (query is String && query.trim().isNotEmpty) {
        return 'Web search: ${_truncate(query.trim(), 160)}';
      }
      return 'Web search';
    }(),
    'imageView' => 'Viewed image',
    'imageGeneration' => 'Generated image',
    'contextCompaction' => 'Context compacted',
    _ => _humanize(type),
  };

  static String _fileChangeSummary(Object? rawChanges) {
    final count = rawChanges is List<Object?> ? rawChanges.length : 0;
    if (rawChanges is! List<Object?>) {
      return 'File changes: $count update(s)';
    }
    var additions = 0;
    var deletions = 0;
    for (final entry in rawChanges.whereType<Map<String, Object?>>()) {
      final entryAdditions = entry['additions'];
      final entryDeletions = entry['deletions'];
      if (entryAdditions is int && entryAdditions >= 0) {
        additions += entryAdditions;
      }
      if (entryDeletions is int && entryDeletions >= 0) {
        deletions += entryDeletions;
      }
      if (entryAdditions is! int && entryDeletions is! int) {
        final diff = entry['diff'];
        if (diff is String && diff.isNotEmpty) {
          for (final line in diff.split('\n')) {
            if (line.startsWith('+') && !line.startsWith('+++')) {
              additions += 1;
            } else if (line.startsWith('-') && !line.startsWith('---')) {
              deletions += 1;
            }
          }
        }
      }
    }
    if (additions == 0 && deletions == 0) {
      return 'File changes: $count update(s)';
    }
    return 'File changes: $count update(s) (+$additions -$deletions)';
  }

  static String _planSummary(JsonObject item) {
    final text = item['text'];
    if (text is String && text.trim().isNotEmpty) {
      final firstLine = text.trim().split('\n').first.trim();
      return 'Plan: ${_truncate(firstLine, 160)}';
    }
    final steps = item['steps'] ?? item['items'] ?? item['todos'];
    if (steps is List<Object?> && steps.isNotEmpty) {
      var hasCompletionState = false;
      var completedCount = 0;
      for (final step in steps.whereType<Map<String, Object?>>()) {
        if (step.containsKey('completed') || step.containsKey('status')) {
          hasCompletionState = true;
          final status = step['status'];
          if (step['completed'] == true ||
              (status is String && status.toLowerCase() == 'completed')) {
            completedCount += 1;
          }
        }
      }
      if (hasCompletionState) {
        return 'Plan updated ($completedCount/${steps.length} completed)';
      }
      return 'Plan updated (${steps.length} step(s))';
    }
    return 'Plan updated';
  }

  static String _activityStatus(JsonObject item, bool completed) {
    final status = item['status'];
    return status is String ? status : (completed ? 'completed' : 'inProgress');
  }

  static JsonObject _requiredObject(
    JsonObject object,
    String key,
    String context,
  ) {
    final value = object[key];
    if (value is! Map<String, Object?>) {
      throw ProtocolViolation('$context field $key must be an object.');
    }
    return value;
  }

  static String _requiredString(JsonObject object, String key) {
    final value = object[key];
    if (value is! String) {
      throw ProtocolViolation('Turn field $key must be a string.');
    }
    return value;
  }

  static String? _optionalString(JsonObject object, String key) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ProtocolViolation('Turn field $key must be a string or null.');
    }
    return value;
  }

  static int _nonNegativeInt(JsonObject object, String key) {
    final value = object[key];
    if (value is! int || value < 0) {
      throw ProtocolViolation(
        'Turn field $key must be a non-negative integer.',
      );
    }
    return value;
  }

  static TurnPlanStepStatus _planStepStatus(String value) => switch (value) {
    'pending' => TurnPlanStepStatus.pending,
    'inProgress' => TurnPlanStepStatus.inProgress,
    'completed' => TurnPlanStepStatus.completed,
    _ => TurnPlanStepStatus.unknown,
  };

  static bool _requiredBool(JsonObject object, String key) {
    final value = object[key];
    if (value is! bool) {
      throw ProtocolViolation('Turn field $key must be a boolean.');
    }
    return value;
  }

  static TurnRuntimeStatus _status(String value) => switch (value) {
    'inProgress' => TurnRuntimeStatus.inProgress,
    'completed' => TurnRuntimeStatus.completed,
    'interrupted' => TurnRuntimeStatus.interrupted,
    'failed' => TurnRuntimeStatus.failed,
    _ => TurnRuntimeStatus.unknown,
  };

  static String _truncate(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit)}…';

  static String _approvalPolicy(ApprovalPolicyOverride policy) =>
      switch (policy) {
        ApprovalPolicyOverride.untrusted => 'untrusted',
        ApprovalPolicyOverride.onRequest => 'on-request',
        ApprovalPolicyOverride.never => 'never',
      };

  static JsonObject _sandboxPolicy(SandboxModeOverride sandbox) =>
      switch (sandbox) {
        SandboxModeOverride.readOnly => const {'type': 'readOnly'},
        SandboxModeOverride.workspaceWrite => const {'type': 'workspaceWrite'},
        SandboxModeOverride.dangerFullAccess => const {
          'type': 'dangerFullAccess',
        },
      };

  static String _humanize(String value) {
    final spaced = value.replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    );
    return spaced.isEmpty
        ? 'Activity'
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}
