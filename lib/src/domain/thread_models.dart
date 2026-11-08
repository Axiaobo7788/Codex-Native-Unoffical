import 'execution_settings.dart';
import 'user_message_presentation.dart';

enum ThreadRuntimeStatus { notLoaded, idle, active, systemError, unknown }

enum ThreadGoalStatus {
  active,
  paused,
  blocked,
  usageLimited,
  budgetLimited,
  complete,
  unknown,
}

enum ThreadSortKey { createdAt, updatedAt, recencyAt }

enum SortDirection { ascending, descending }

class ThreadGitInfo {
  const ThreadGitInfo({this.branch, this.originUrl, this.sha});

  final String? branch;
  final String? originUrl;
  final String? sha;
}

class ThreadGoal {
  const ThreadGoal({
    required this.objective,
    required this.status,
    required this.createdAtSeconds,
    required this.updatedAtSeconds,
    required this.tokensUsed,
    required this.timeUsedSeconds,
    this.tokenBudget,
  });

  final String objective;
  final ThreadGoalStatus status;
  final int createdAtSeconds;
  final int updatedAtSeconds;
  final int tokensUsed;
  final int timeUsedSeconds;
  final int? tokenBudget;
}

class ThreadSummary {
  const ThreadSummary({
    required this.id,
    required this.sessionId,
    required this.preview,
    required this.cwd,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.ephemeral,
    this.name,
    this.model,
    this.projectId,
    this.gitInfo,
    this.goal,
  });

  final String id;
  final String sessionId;
  final String preview;
  final String cwd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ThreadRuntimeStatus status;
  final bool ephemeral;
  final String? name;
  final String? model;
  final String? projectId;
  final ThreadGitInfo? gitInfo;
  final ThreadGoal? goal;

  ThreadSummary copyWith({
    String? preview,
    String? cwd,
    DateTime? updatedAt,
    ThreadRuntimeStatus? status,
    String? name,
    bool clearName = false,
    String? model,
    String? projectId,
    ThreadGitInfo? gitInfo,
    bool clearGitInfo = false,
    ThreadGoal? goal,
    bool clearGoal = false,
  }) => ThreadSummary(
    id: id,
    sessionId: sessionId,
    preview: preview ?? this.preview,
    cwd: cwd ?? this.cwd,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    ephemeral: ephemeral,
    name: clearName ? null : (name ?? this.name),
    model: model ?? this.model,
    projectId: projectId ?? this.projectId,
    gitInfo: clearGitInfo ? null : (gitInfo ?? this.gitInfo),
    goal: clearGoal ? null : (goal ?? this.goal),
  );

  String get displayTitle {
    final explicitName = name?.trim();
    if (explicitName != null && explicitName.isNotEmpty) {
      return explicitName;
    }
    final normalized = parseUserMessagePresentation(preview).bodyText.trim();
    final source = normalized.isEmpty ? preview.trim() : normalized;
    for (final rawLine in source.split('\n')) {
      final cleaned = rawLine.trim().replaceFirst(RegExp(r'^#+\s*'), '').trim();
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }
    return 'Untitled thread';
  }
}

class ThreadPage {
  const ThreadPage({required this.threads, required this.nextCursor});

  final List<ThreadSummary> threads;
  final String? nextCursor;
}

class ThreadListQuery {
  const ThreadListQuery({
    this.cursor,
    this.limit = 25,
    this.sortKey = ThreadSortKey.recencyAt,
    this.sortDirection = SortDirection.descending,
    this.archived = false,
    this.searchTerm,
  }) : assert(limit > 0 && limit <= 100);

  final String? cursor;
  final int limit;
  final ThreadSortKey sortKey;
  final SortDirection sortDirection;
  final bool archived;
  final String? searchTerm;
}

class ThreadStartOptions {
  const ThreadStartOptions({
    required this.cwd,
    this.ephemeral = false,
    this.model,
    this.approvalPolicy,
    this.sandbox,
  });

  final String cwd;
  final bool ephemeral;
  final String? model;
  final ApprovalPolicyOverride? approvalPolicy;
  final SandboxModeOverride? sandbox;
}

class ThreadForkOptions {
  const ThreadForkOptions({
    required this.threadId,
    this.beforeTurnId,
    this.lastTurnId,
    this.cwd,
    this.ephemeral = false,
    this.model,
    this.approvalPolicy,
    this.sandbox,
  }) : assert(
         beforeTurnId == null || lastTurnId == null,
         'beforeTurnId and lastTurnId are mutually exclusive.',
       );

  final String threadId;
  final String? beforeTurnId;
  final String? lastTurnId;
  final String? cwd;
  final bool ephemeral;
  final String? model;
  final ApprovalPolicyOverride? approvalPolicy;
  final SandboxModeOverride? sandbox;
}

sealed class ThreadLifecycleEvent {
  const ThreadLifecycleEvent({required this.threadId});

  final String threadId;
}

final class ThreadNameUpdatedEvent extends ThreadLifecycleEvent {
  const ThreadNameUpdatedEvent({
    required super.threadId,
    required this.threadName,
  });

  final String? threadName;
}

final class ThreadArchivedEvent extends ThreadLifecycleEvent {
  const ThreadArchivedEvent({required super.threadId});
}

final class ThreadUnarchivedEvent extends ThreadLifecycleEvent {
  const ThreadUnarchivedEvent({required super.threadId});
}

final class ThreadRevertedEvent extends ThreadLifecycleEvent {
  const ThreadRevertedEvent({
    required super.threadId,
    this.turnsBackwardsCursor,
    this.itemsBackwardsCursor,
  });

  final String? turnsBackwardsCursor;
  final String? itemsBackwardsCursor;
}

final class ThreadStatusChangedEvent extends ThreadLifecycleEvent {
  const ThreadStatusChangedEvent({
    required super.threadId,
    required this.status,
  });

  final ThreadRuntimeStatus status;
}

final class ThreadGoalUpdatedEvent extends ThreadLifecycleEvent {
  const ThreadGoalUpdatedEvent({
    required super.threadId,
    required this.goal,
    this.turnId,
  });

  final ThreadGoal goal;
  final String? turnId;
}

final class ThreadGoalClearedEvent extends ThreadLifecycleEvent {
  const ThreadGoalClearedEvent({required super.threadId});
}
