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
