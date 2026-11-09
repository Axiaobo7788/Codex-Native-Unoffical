import 'thread_models.dart';

abstract interface class ThreadGateway {
  Stream<ThreadLifecycleEvent> get threadEvents;

  Future<ThreadPage> listThreads(ThreadListQuery query);
  Future<ThreadSummary> startThread(ThreadStartOptions options);
  Future<ThreadSummary> readThread(String threadId);
  Future<ThreadSummary> resumeThread(String threadId);
  Future<void> renameThread({required String threadId, required String name});
  Future<void> archiveThread(String threadId);
  Future<ThreadSummary> unarchiveThread(String threadId);
  Future<ThreadSummary> forkThread(ThreadForkOptions options);
  Future<ThreadSummary> revertThread({
    required String threadId,
    required String beforeTurnId,
  });
  Future<void> compactThread(String threadId);
  Future<void> deleteThread(String threadId);
}

/// User-initiated goal operations on a connected local Codex thread.
abstract interface class ThreadGoalGateway {
  bool get supportsThreadGoals;

  Future<ThreadGoal?> readThreadGoal(String threadId);
  Future<ThreadGoal> setThreadGoal(
    String threadId, {
    String? objective,
    ThreadGoalStatus? status,
  });
  Future<bool> clearThreadGoal(String threadId);
}

abstract interface class ThreadSectionGateway {
  bool get supportsThreadSections;

  Future<ThreadSectionPage> listThreadSections([
    ThreadSectionListQuery query = const ThreadSectionListQuery(),
  ]);
  Future<ThreadSection> createThreadSection(ThreadSectionCreateOptions options);
  Future<ThreadSection> updateThreadSection(ThreadSectionUpdateOptions options);
  Future<void> deleteThreadSection(String sectionId);
  Future<void> moveThreadSection(ThreadSectionMoveOptions options);
}
