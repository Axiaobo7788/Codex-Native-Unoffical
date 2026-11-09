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

enum ThreadSortKey { createdAt, updatedAt, recencyAt, sectionPosition }

enum SortDirection { ascending, descending }

class ThreadGitInfo {
  const ThreadGitInfo({this.branch, this.originUrl, this.sha});

  final String? branch;
  final String? originUrl;
  final String? sha;
}

class ThreadSectionAppearance {
  const ThreadSectionAppearance({this.color, this.icon});

  final String? color;
  final String? icon;
}

class ThreadSection {
  const ThreadSection({required this.id, required this.name, this.appearance});

  final String id;
  final String name;
  final ThreadSectionAppearance? appearance;

  ThreadSection copyWith({
    String? name,
    ThreadSectionAppearance? appearance,
    bool clearAppearance = false,
  }) => ThreadSection(
    id: id,
    name: name ?? this.name,
    appearance: clearAppearance ? null : (appearance ?? this.appearance),
  );
}

class ThreadGoal {
  static const maxObjectiveLength = 2048;

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
    this.section,
    this.sectionEnteredAtSeconds,
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
  final ThreadSection? section;
  final int? sectionEnteredAtSeconds;

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
    ThreadSection? section,
    bool clearSection = false,
    int? sectionEnteredAtSeconds,
    bool clearSectionEnteredAtSeconds = false,
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
    section: clearSection ? null : (section ?? this.section),
    sectionEnteredAtSeconds: clearSectionEnteredAtSeconds
        ? null
        : (sectionEnteredAtSeconds ?? this.sectionEnteredAtSeconds),
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

class ThreadSectionPage {
  const ThreadSectionPage({required this.sections, required this.nextCursor});

  final List<ThreadSection> sections;
  final String? nextCursor;
}

class ThreadSectionListQuery {
  const ThreadSectionListQuery({this.cursor, this.limit = 50})
    : assert(limit > 0 && limit <= maxLimit);

  static const int maxLimit = 64;

  final String? cursor;
  final int limit;
}

class ThreadSectionCreateOptions {
  const ThreadSectionCreateOptions({required this.name, this.appearance});

  final String name;
  final ThreadSectionAppearance? appearance;
}

class ThreadSectionUpdateOptions {
  const ThreadSectionUpdateOptions({
    required this.sectionId,
    required this.name,
    this.appearance,
    this.clearAppearance = false,
  });

  final String sectionId;
  final String name;
  final ThreadSectionAppearance? appearance;
  final bool clearAppearance;
}

class ThreadSectionMoveOptions {
  const ThreadSectionMoveOptions({
    required this.threadId,
    required this.sectionId,
    this.beforeThreadId,
  });

  final String threadId;
  final String? sectionId;
  final String? beforeThreadId;
}

class ThreadListQuery {
  const ThreadListQuery({
    this.cursor,
    this.limit = 25,
    this.sortKey = ThreadSortKey.recencyAt,
    this.sortDirection = SortDirection.descending,
    this.archived = false,
    this.searchTerm,
    this.section,
  }) : assert(limit > 0 && limit <= 100);

  final String? cursor;
  final int limit;
  final ThreadSortKey sortKey;
  final SortDirection sortDirection;
  final bool archived;
  final String? searchTerm;

  /// Omit for the global catalog. A present record with a null ID selects
  /// unsectioned threads. A concrete ID selects one stock section.
  final ({String? id})? section;
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

final class ThreadSectionChangedEvent extends ThreadLifecycleEvent {
  const ThreadSectionChangedEvent({
    required super.threadId,
    required this.sectionId,
  });

  final String? sectionId;
}
