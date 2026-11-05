import '../domain/turn_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';

final class TurnProtocolAdapter {
  TurnProtocolAdapter({
    required this.request,
    required Stream<CodexNotification> notifications,
  }) : events = notifications
           .map(_parseNotification)
           .where((event) => event != null)
           .cast<TurnEvent>();

  final ProtocolRequest request;
  final Stream<TurnEvent> events;

  Future<TurnHandle> startTurn({
    required String threadId,
    required String text,
  }) async {
    final response = await request('turn/start', {
      'threadId': threadId,
      'input': [
        {'type': 'text', 'text': text, 'text_elements': <Object?>[]},
      ],
    });
    final turn = _requiredObject(response, 'turn', 'turn/start response');
    return _parseTurnHandle(turn);
  }

  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    await request('turn/interrupt', {'threadId': threadId, 'turnId': turnId});
  }

  static TurnEvent? _parseNotification(CodexNotification notification) {
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
