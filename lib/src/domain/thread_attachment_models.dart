enum ThreadAttachmentUpdateOperation { created, deleted, unknown }

enum ThreadPullRequestLinkOutcome { created, existing, scanIncomplete }

/// Sanitized, canonical Pull Request / Merge Request reference projected from
/// a persisted `thread/attachment/list` `pull_request` record.
class ThreadLinkedPullRequest {
  const ThreadLinkedPullRequest({
    required this.attachmentId,
    required this.canonicalIdentityKey,
    required this.canonicalHost,
    required this.owner,
    required this.repository,
    required this.number,
    required this.canonicalUrl,
    required this.createdAtSeconds,
    this.headBranch,
  });

  final String attachmentId;
  final String canonicalIdentityKey;
  final String canonicalHost;
  final String owner;
  final String repository;
  final int number;
  final String canonicalUrl;
  final int createdAtSeconds;
  final String? headBranch;

  String get displayLabel => '$owner/$repository#$number';
}

/// Result of an explicit local `thread/attachment/add` call for a canonical
/// `pull_request` reference.
class ThreadPullRequestLinkResult {
  const ThreadPullRequestLinkResult({
    required this.outcome,
    required this.displayLabel,
    this.pullRequest,
    this.hiddenByDisplayCap = false,
  });

  final ThreadPullRequestLinkOutcome outcome;
  final String displayLabel;

  /// Populated when [outcome] is [ThreadPullRequestLinkOutcome.created] or
  /// [ThreadPullRequestLinkOutcome.existing]; null when
  /// [ThreadPullRequestLinkOutcome.scanIncomplete] prevented verification.
  final ThreadLinkedPullRequest? pullRequest;

  /// True when the linked PR falls past the retained 16-PR display cap for the
  /// thread.
  final bool hiddenByDisplayCap;
}

/// Bounded per-thread projection of sanitized linked Pull Requests.
class ThreadLinkedPullRequestsSnapshot {
  const ThreadLinkedPullRequestsSnapshot({
    required this.threadId,
    required this.pullRequests,
    required this.scannedAttachmentCount,
    required this.truncated,
  });

  final String threadId;
  final List<ThreadLinkedPullRequest> pullRequests;
  final int scannedAttachmentCount;

  /// True when pagination stopped early at the attachment scan bound (100 rows)
  /// or retained PR display bound (16 items) while more records remained.
  final bool truncated;

  bool get isEmpty => pullRequests.isEmpty;
  bool get isNotEmpty => pullRequests.isNotEmpty;
}

sealed class ThreadAttachmentEvent {
  const ThreadAttachmentEvent({required this.threadId});

  final String threadId;
}

final class ThreadAttachmentUpdatedEvent extends ThreadAttachmentEvent {
  const ThreadAttachmentUpdatedEvent({
    required super.threadId,
    required this.attachmentId,
    required this.attachmentType,
    required this.identityKey,
    required this.operation,
  });

  final String attachmentId;
  final String attachmentType;
  final String identityKey;
  final ThreadAttachmentUpdateOperation operation;
}
