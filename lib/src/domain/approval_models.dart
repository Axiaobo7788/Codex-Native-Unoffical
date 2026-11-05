enum ApprovalKind { command, fileChange, permissions, unsupported }

enum ApprovalDecision { approveOnce, reject }

sealed class ApprovalEvent {
  const ApprovalEvent();
}

class ApprovalRequestedEvent extends ApprovalEvent {
  const ApprovalRequestedEvent({required this.request});

  final ApprovalRequest request;
}

class ApprovalResolvedEvent extends ApprovalEvent {
  const ApprovalResolvedEvent({required this.requestId});

  final Object requestId;
}

class ApprovalRequest {
  const ApprovalRequest({
    required this.requestId,
    required this.kind,
    required this.threadId,
    required this.turnId,
    required this.itemId,
    required this.summary,
    required this.approveSupported,
    this.detail,
    this.reason,
  });

  final Object requestId;
  final ApprovalKind kind;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String summary;
  final String? detail;
  final String? reason;
  final bool approveSupported;
}
