import 'execution_settings.dart';
import 'diff_models.dart';
import 'output_models.dart';
import 'user_message_presentation.dart';

export 'user_message_presentation.dart';

enum TurnRuntimeStatus { inProgress, completed, interrupted, failed, unknown }

class TurnStartOptions {
  const TurnStartOptions({
    required this.threadId,
    required this.text,
    this.attachments = const [],
    this.clientUserMessageId,
    this.model,
    this.reasoningEffort,
    this.approvalPolicy,
    this.sandbox,
  });

  final String threadId;
  final String text;
  final List<UserAttachment> attachments;
  final String? clientUserMessageId;
  final String? model;
  final String? reasoningEffort;
  final ApprovalPolicyOverride? approvalPolicy;
  final SandboxModeOverride? sandbox;
}

class TurnSteerOptions {
  const TurnSteerOptions({
    required this.threadId,
    required this.expectedTurnId,
    required this.text,
    this.attachments = const [],
    this.clientUserMessageId,
  });

  final String threadId;
  final String expectedTurnId;
  final String text;
  final List<UserAttachment> attachments;
  final String? clientUserMessageId;
}

sealed class ReviewTarget {
  const ReviewTarget();

  String get displayLabel;
}

class UncommittedChangesReviewTarget extends ReviewTarget {
  const UncommittedChangesReviewTarget();

  @override
  String get displayLabel => 'Uncommitted changes';
}

class BaseBranchReviewTarget extends ReviewTarget {
  const BaseBranchReviewTarget(this.branch);

  final String branch;

  @override
  String get displayLabel => 'Changes against $branch';
}

class CommitReviewTarget extends ReviewTarget {
  const CommitReviewTarget({required this.sha, this.title});

  final String sha;
  final String? title;

  @override
  String get displayLabel {
    final normalizedTitle = title?.trim();
    return normalizedTitle == null || normalizedTitle.isEmpty
        ? 'Commit $sha'
        : normalizedTitle;
  }
}

class CustomReviewTarget extends ReviewTarget {
  const CustomReviewTarget(this.instructions);

  final String instructions;

  @override
  String get displayLabel => 'Custom review';
}

class ReviewStartOptions {
  const ReviewStartOptions({required this.threadId, required this.target});

  final String threadId;
  final ReviewTarget target;
}

class ReviewHandle {
  const ReviewHandle({required this.reviewThreadId, required this.turn});

  final String reviewThreadId;
  final TurnHandle turn;
}

typedef ReviewStarter = Future<ReviewHandle> Function(
  ReviewStartOptions options,
);

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

class UserMessageEvent extends TurnEvent {
  const UserMessageEvent({
    required super.threadId,
    required super.turnId,
    required this.itemId,
    required this.text,
    this.clientMessageId,
    this.attachments = const [],
  });

  final String itemId;
  final String text;
  final String? clientMessageId;
  final List<UserAttachment> attachments;
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

enum CommandActionKind { read, listFiles, search, run }

class ActivityEvent extends TurnEvent {
  const ActivityEvent({
    required super.threadId,
    required super.turnId,
    required this.itemId,
    required this.summary,
    required this.status,
    required this.completed,
    this.commandActions = const {},
    this.commandOutput,
  });

  final String itemId;
  final String summary;
  final String status;
  final bool completed;
  final Set<CommandActionKind> commandActions;
  final OutputDescriptor? commandOutput;
}

enum ReviewModePhase { entered, exited }

class ReviewModeEvent extends ActivityEvent {
  const ReviewModeEvent({
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required this.phase,
    required this.review,
    required super.status,
    required super.completed,
  }) : super(
         summary: phase == ReviewModePhase.entered
             ? 'Review started: $review'
             : 'Review completed: $review',
       );

  final ReviewModePhase phase;
  final String review;
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

class TurnDiffUpdatedEvent extends TurnEvent {
  TurnDiffUpdatedEvent({required this.snapshot})
    : super(threadId: snapshot.threadId, turnId: snapshot.turnId);

  final DiffSnapshot snapshot;
}

enum TurnPlanStepStatus { pending, inProgress, completed, unknown }

class TurnPlanStepModel {
  const TurnPlanStepModel({required this.step, required this.status});

  final String step;
  final TurnPlanStepStatus status;
}

class TurnPlanSnapshot {
  const TurnPlanSnapshot({
    required this.threadId,
    required this.turnId,
    required this.steps,
    this.explanation,
  });

  final String threadId;
  final String turnId;
  final List<TurnPlanStepModel> steps;
  final String? explanation;

  int get completedCount =>
      steps.where((step) => step.status == TurnPlanStepStatus.completed).length;

  bool get allCompleted => steps.isNotEmpty && completedCount == steps.length;
}

class TurnPlanUpdatedEvent extends ActivityEvent {
  TurnPlanUpdatedEvent({required this.plan})
    : super(
        threadId: plan.threadId,
        turnId: plan.turnId,
        itemId: 'turn-plan-${plan.turnId}',
        summary:
            'Plan updated (${plan.completedCount}/${plan.steps.length} completed)',
        status: plan.allCompleted ? 'completed' : 'inProgress',
        completed: plan.allCompleted,
      );

  final TurnPlanSnapshot plan;
}

class TokenUsageBreakdownModel {
  const TokenUsageBreakdownModel({
    required this.inputTokens,
    required this.cachedInputTokens,
    this.cacheWriteInputTokens = 0,
    required this.outputTokens,
    required this.reasoningOutputTokens,
    required this.totalTokens,
  });

  final int inputTokens;
  final int cachedInputTokens;
  final int cacheWriteInputTokens;
  final int outputTokens;
  final int reasoningOutputTokens;
  final int totalTokens;
}

class ThreadTokenUsageSnapshot {
  const ThreadTokenUsageSnapshot({
    required this.threadId,
    required this.turnId,
    required this.last,
    required this.total,
    this.modelContextWindow,
  });

  final String threadId;
  final String turnId;
  final TokenUsageBreakdownModel last;
  final TokenUsageBreakdownModel total;
  final int? modelContextWindow;

  double? get contextWindowUtilization {
    final window = modelContextWindow;
    if (window == null || window <= 0) {
      return null;
    }
    return (total.totalTokens / window).clamp(0.0, 1.0);
  }
}

class ThreadTokenUsageUpdatedEvent extends ActivityEvent {
  ThreadTokenUsageUpdatedEvent({required this.usage})
    : super(
        threadId: usage.threadId,
        turnId: usage.turnId,
        itemId: 'token-usage-${usage.turnId}',
        summary: 'Token usage: ${usage.total.totalTokens} total',
        status: 'completed',
        completed: true,
      );

  final ThreadTokenUsageSnapshot usage;
}

class ReasoningSummaryDeltaEvent extends ActivityEvent {
  const ReasoningSummaryDeltaEvent({
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required this.summaryIndex,
    required this.delta,
  }) : super(summary: 'Reasoning', status: 'inProgress', completed: false);

  final int summaryIndex;
  final String delta;
}

class McpToolCallProgressEvent extends ActivityEvent {
  const McpToolCallProgressEvent({
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required this.message,
  }) : super(
         summary: 'MCP progress: $message',
         status: 'inProgress',
         completed: false,
       );

  final String message;
}

class HookActivityEvent extends ActivityEvent {
  const HookActivityEvent({
    required super.threadId,
    required super.turnId,
    required this.runId,
    required this.eventName,
    required this.handlerType,
    required this.executionMode,
    required this.scope,
    required super.status,
    required super.completed,
    this.statusMessage,
    this.durationMs,
    this.entrySummary,
  }) : super(itemId: 'hook-$runId', summary: 'Hook: $eventName ($handlerType)');

  final String runId;
  final String eventName;
  final String handlerType;
  final String executionMode;
  final String scope;
  final String? statusMessage;
  final int? durationMs;
  final String? entrySummary;

  String get formattedSummary {
    final base = 'Hook: $eventName ($handlerType)';
    final details = <String>[
      if (statusMessage != null && statusMessage!.trim().isNotEmpty)
        statusMessage!.trim()
      else if (entrySummary != null && entrySummary!.trim().isNotEmpty)
        entrySummary!.trim(),
      if (durationMs != null && durationMs! >= 0) '${durationMs}ms',
    ];
    if (details.isEmpty) {
      return base;
    }
    return '$base — ${details.join(' · ')}';
  }
}

class ModelReroutedEvent extends ActivityEvent {
  const ModelReroutedEvent({
    required super.threadId,
    required super.turnId,
    required this.fromModel,
    required this.toModel,
    required this.reason,
  }) : super(
         itemId: 'model-reroute-$turnId',
         summary: 'Model rerouted: $fromModel → $toModel ($reason)',
         status: 'completed',
         completed: true,
       );

  final String fromModel;
  final String toModel;
  final String reason;
}

class TurnWarningEvent extends ActivityEvent {
  const TurnWarningEvent({
    required super.threadId,
    super.turnId = '',
    required this.message,
  }) : super(
         itemId: 'warning-$turnId',
         summary: 'Warning: $message',
         status: 'warning',
         completed: true,
       );

  final String message;
}
