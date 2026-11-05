import '../domain/approval_models.dart';
import '../domain/thread_models.dart';
import '../domain/turn_models.dart';
import '../protocol/protocol_models.dart';

abstract interface class CodexTransport {
  Stream<CodexNotification> get notifications;
  Stream<CodexServerRequest> get serverRequests;
  Stream<ProtocolViolation> get protocolErrors;
  Stream<TurnEvent> get turnEvents;
  Stream<ApprovalEvent> get approvalEvents;

  Future<InitializeResult> initialize(InitializeRequest request);
  Future<ThreadPage> listThreads(ThreadListQuery query);
  Future<ThreadSummary> startThread(ThreadStartOptions options);
  Future<ThreadSummary> readThread(String threadId);
  Future<ThreadSummary> resumeThread(String threadId);
  Future<void> deleteThread(String threadId);
  Future<TurnHandle> startTurn({
    required String threadId,
    required String text,
  });
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  });
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  });
  Future<void> close();
}
