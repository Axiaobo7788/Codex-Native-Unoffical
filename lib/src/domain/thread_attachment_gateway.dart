import 'thread_attachment_models.dart';

/// Read-only local thread attachment gateway for stock `codex app-server`.
///
/// Only the bounded, non-loading `thread/attachment/list` read path and
/// `thread/attachment/updated` notification stream are exposed here. Managed
/// worktree mutations, attachment writes, private cloud attachment services,
/// and Direct-Host Remote surfaces remain outside this contract; callers must
/// check [supportsThreadAttachments] and fail closed when unsupported.
abstract interface class ThreadAttachmentGateway {
  bool get supportsThreadAttachments;

  Stream<ThreadAttachmentEvent> get threadAttachmentEvents;

  Future<ThreadLinkedPullRequestsSnapshot> readLinkedPullRequests(
    String threadId,
  );
}
