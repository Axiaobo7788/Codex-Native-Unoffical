import '../domain/execution_settings.dart';
import '../domain/turn_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';
import 'unified_diff_parser.dart';

final class TurnProtocolAdapter {
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
      'error' => _parseError(params),
      _ => null,
    };
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
    'fileChange' => 'File changes: ${_listLength(item, 'changes')} update(s)',
    'mcpToolCall' =>
      'MCP: ${_requiredString(item, 'server')}/${_requiredString(item, 'tool')}',
    'dynamicToolCall' => 'Tool: ${_requiredString(item, 'tool')}',
    'collabAgentToolCall' => 'Collaboration: ${_requiredString(item, 'tool')}',
    'subAgentActivity' => 'Sub-agent activity',
    'functionCallOutput' => 'Function output: ${_requiredString(item, 'name')}',
    'plan' => 'Plan updated',
    'reasoning' => 'Reasoning',
    'webSearch' => 'Web search',
    'imageView' => 'Viewed image',
    'imageGeneration' => 'Generated image',
    'contextCompaction' => 'Context compacted',
    _ => _humanize(type),
  };

  static String _activityStatus(JsonObject item, bool completed) {
    final status = item['status'];
    return status is String ? status : (completed ? 'completed' : 'inProgress');
  }

  static int _listLength(JsonObject object, String key) {
    final value = object[key];
    return value is List<Object?> ? value.length : 0;
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
