import 'thread_models.dart';

abstract interface class ThreadGateway {
  Future<ThreadPage> listThreads(ThreadListQuery query);
  Future<ThreadSummary> startThread(ThreadStartOptions options);
  Future<ThreadSummary> readThread(String threadId);
  Future<ThreadSummary> resumeThread(String threadId);
}
