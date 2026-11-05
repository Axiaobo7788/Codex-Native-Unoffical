import 'approval_models.dart';

abstract interface class ApprovalGateway {
  Stream<ApprovalEvent> get approvalEvents;

  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  });
}
