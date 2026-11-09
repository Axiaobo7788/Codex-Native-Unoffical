import 'thread_attachment_models.dart';

/// Local thread attachment gateway for stock `codex app-server` `pull_request`
/// references.
///
/// Exposes the bounded, non-loading `thread/attachment/list` read path,
/// explicit canonical `pull_request` `thread/attachment/add` linking, and the
/// `thread/attachment/updated` notification stream. Managed worktree mutations,
/// generic arbitrary attachment writes, attachment removals, private cloud
/// attachment services, and Direct-Host Remote surfaces remain outside this
/// contract; callers must check [supportsThreadAttachments] /
/// [supportsThreadAttachmentWrites] and fail closed when unsupported.
abstract interface class ThreadAttachmentGateway {
  bool get supportsThreadAttachments;

  bool get supportsThreadAttachmentWrites => supportsThreadAttachments;

  Stream<ThreadAttachmentEvent> get threadAttachmentEvents;

  Future<ThreadLinkedPullRequestsSnapshot> readLinkedPullRequests(
    String threadId,
  );

  Future<ThreadPullRequestLinkResult> linkPullRequest(
    String threadId, {
    required String url,
    String? headBranch,
  });
}
