enum TurnRuntimeStatus { inProgress, completed, interrupted, failed, unknown }

class TurnHandle {
  const TurnHandle({required this.id, required this.status});

  final String id;
  final TurnRuntimeStatus status;
}

sealed class TurnEvent {
  const TurnEvent({required this.threadId, required this.turnId});

  final String threadId;
  final String turnId;
}

class TurnStartedEvent extends TurnEvent {
  const TurnStartedEvent({required super.threadId, required super.turnId});
}

class TurnCompletedEvent extends TurnEvent {
  const TurnCompletedEvent({
    required super.threadId,
    required super.turnId,
    required this.status,
    this.errorMessage,
  });

  final TurnRuntimeStatus status;
  final String? errorMessage;
}

class AssistantTextDeltaEvent extends TurnEvent {
  const AssistantTextDeltaEvent({
    required super.threadId,
    required super.turnId,
    required this.itemId,
    required this.delta,
  });

  final String itemId;
  final String delta;
}

class AssistantMessageEvent extends TurnEvent {
  const AssistantMessageEvent({
    required super.threadId,
    required super.turnId,
    required this.itemId,
    required this.text,
    required this.completed,
  });

  final String itemId;
  final String text;
  final bool completed;
}

class ActivityEvent extends TurnEvent {
  const ActivityEvent({
    required super.threadId,
    required super.turnId,
    required this.itemId,
    required this.summary,
    required this.status,
    required this.completed,
  });

  final String itemId;
  final String summary;
  final String status;
  final bool completed;
}

class TurnErrorEvent extends TurnEvent {
  const TurnErrorEvent({
    required super.threadId,
    required super.turnId,
    required this.message,
    required this.willRetry,
  });

  final String message;
  final bool willRetry;
}
