import '../domain/approval_models.dart';
import '../domain/conversation_backend.dart';
import '../domain/ecosystem_gateway.dart';
import '../domain/history_models.dart';
import '../domain/model_models.dart';
import '../domain/output_gateway.dart';
import '../domain/thread_models.dart';
import '../domain/turn_models.dart';
import '../protocol/protocol_models.dart';

abstract interface class CodexTransport
    implements
        ConversationBackend,
        ExecutionBackend,
        OutputGateway,
        EcosystemGateway {
  Stream<CodexNotification> get notifications;
  Stream<CodexServerRequest> get serverRequests;
  Stream<ProtocolViolation> get protocolErrors;
  @override
  Stream<TurnEvent> get turnEvents;
  @override
  Stream<ThreadLifecycleEvent> get threadEvents;
  @override
  Stream<ApprovalEvent> get approvalEvents;

  Future<InitializeResult> initialize(InitializeRequest request);
  @override
  Future<ModelPage> listModels(ModelListQuery query);
  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query);
  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query);
  @override
  Future<List<HistoryItem>> readHistoryItems({
    required String threadId,
    required String turnId,
    required List<String> itemIds,
  });
  @override
  Future<ThreadPage> listThreads(ThreadListQuery query);
  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options);
  @override
  Future<ThreadSummary> readThread(String threadId);
  @override
  Future<ThreadSummary> resumeThread(String threadId);
  @override
  Future<void> renameThread({required String threadId, required String name});
  @override
  Future<void> archiveThread(String threadId);
  @override
  Future<ThreadSummary> unarchiveThread(String threadId);
  @override
  Future<ThreadSummary> forkThread(ThreadForkOptions options);
  @override
  Future<ThreadSummary> revertThread({
    required String threadId,
    required String beforeTurnId,
  });
  @override
  Future<void> compactThread(String threadId);
  @override
  Future<void> deleteThread(String threadId);
  @override
  Future<TurnHandle> startTurn(TurnStartOptions options);
  @override
  Future<String> steerTurn(TurnSteerOptions options);
  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  });
  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  });
  Future<void> close();
}
