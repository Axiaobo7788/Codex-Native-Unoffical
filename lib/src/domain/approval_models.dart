enum ApprovalKind { command, fileChange, permissions, unsupported }

enum ApprovalDecisionKind {
  approveOnce,
  approveForSession,
  approveWithExecpolicyAmendment,
  applyNetworkPolicyAmendment,
  reject,
  cancelTurn,
}

enum ApprovalNetworkAction { allow, deny }

/// A typed choice from one pending stock request, never a client-authored rule.
///
/// Structured choices retain identity: the adapter accepts only the immutable
/// choice it offered for that request, rather than arbitrary matching payloads.
final class ApprovalDecision {
  const ApprovalDecision._(
    this.kind, {
    this.execpolicyAmendment = const [],
    this.networkHost,
    this.networkAction,
  });

  factory ApprovalDecision.withExecpolicyAmendment(List<String> amendment) =>
      ApprovalDecision._(
        ApprovalDecisionKind.approveWithExecpolicyAmendment,
        execpolicyAmendment: List.unmodifiable(amendment),
      );

  factory ApprovalDecision.withNetworkPolicyAmendment({
    required String host,
    required ApprovalNetworkAction action,
  }) => ApprovalDecision._(
    ApprovalDecisionKind.applyNetworkPolicyAmendment,
    networkHost: host,
    networkAction: action,
  );

  static const approveOnce = ApprovalDecision._(
    ApprovalDecisionKind.approveOnce,
  );
  static const approveForSession = ApprovalDecision._(
    ApprovalDecisionKind.approveForSession,
  );
  static const reject = ApprovalDecision._(ApprovalDecisionKind.reject);
  static const cancelTurn = ApprovalDecision._(ApprovalDecisionKind.cancelTurn);

  final ApprovalDecisionKind kind;
  final List<String> execpolicyAmendment;
  final String? networkHost;
  final ApprovalNetworkAction? networkAction;
}

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
    required bool approveSupported,
    this.decisions,
    this.detail,
    this.reason,
  }) : _legacyApproveSupported = approveSupported;

  final Object requestId;
  final ApprovalKind kind;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String summary;
  final String? detail;
  final String? reason;
  final bool _legacyApproveSupported;

  /// Null preserves older gateway/fixture contracts (one-time approve/reject).
  /// Real stock adapters supply the authoritative, bounded immutable choices.
  final List<ApprovalDecision>? decisions;

  List<ApprovalDecision> get availableDecisions =>
      decisions ??
      [
        ApprovalDecision.reject,
        if (_legacyApproveSupported) ApprovalDecision.approveOnce,
      ];

  bool get approveSupported => supports(ApprovalDecision.approveOnce);

  /// Refusal never needs an advertised grant: decline is a stable v2 response
  /// and the official client keeps its deny action independently of choices.
  bool supports(ApprovalDecision decision) =>
      decision == ApprovalDecision.reject ||
      availableDecisions.contains(decision);
}
