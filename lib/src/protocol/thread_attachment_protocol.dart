import 'dart:convert';

import '../domain/thread_attachment_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';

/// Typed protocol adapter for stock `thread/attachment/list`,
/// `thread/attachment/add`, and `thread/attachment/updated` notifications.
///
/// Stock allows up to 64 KiB per attachment payload, 256 UTF-8 bytes per
/// `identityKey`, and up to 100 attachments per thread. To keep memory bounded,
/// this adapter pages in small slices ([defaultPageSize] = 16), scans at most
/// [maxScannedAttachments] (100) rows with a duplicate-cursor guard, and
/// projects only sanitized canonical `pull_request` links (up to
/// [maxRetainedPullRequests] = 16).
final class ThreadAttachmentProtocolAdapter {
  static const int defaultPageSize = 16;
  static const int maxPageSize = 16;
  static const int maxScannedAttachments = 100;
  static const int maxScannedPages = 16;
  static const int maxRetainedPullRequests = 16;
  static const int maxIdentityKeyUtf8Bytes = 256;
  static const int _maxIdentifierLength = 512;
  static const int _maxIdentityKeyLength = 1024;
  static const int _maxAttachmentTypeLength = 128;
  static const int _maxUrlLength = 512;
  static const int _maxHeadBranchLength = 128;

  static final RegExp _controlOrWhitespace = RegExp(r'[\x00-\x20\x7F]');
  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _pathSegmentPattern = RegExp(r'^[A-Za-z0-9_.-]{1,100}$');
  static final RegExp _positiveIntPattern = RegExp(r'^[1-9][0-9]{0,8}$');

  ThreadAttachmentProtocolAdapter({
    required this.request,
    Stream<CodexNotification> notifications = const Stream.empty(),
  }) : events = notifications
           .map(_parseNotification)
           .where((event) => event != null)
           .cast<ThreadAttachmentEvent>();

  final ProtocolRequest request;
  final Stream<ThreadAttachmentEvent> events;

  Future<ThreadLinkedPullRequestsSnapshot> readLinkedPullRequests(
    String threadId, {
    int pageSize = defaultPageSize,
  }) async {
    final normalizedThreadId = _requireOpaqueArgumentId(
      threadId,
      'threadId',
      _maxIdentifierLength,
    );
    final clampedPageSize = pageSize.clamp(1, maxPageSize);
    final pullRequests = <ThreadLinkedPullRequest>[];
    final seenIdentityKeys = <String>{};
    final seenCursors = <String>{};
    String? cursor;
    var scannedCount = 0;
    var scannedPages = 0;
    var truncated = false;

    while (scannedCount < maxScannedAttachments &&
        scannedPages < maxScannedPages) {
      final remainingBudget = maxScannedAttachments - scannedCount;
      final requestLimit = remainingBudget < clampedPageSize
          ? remainingBudget
          : clampedPageSize;
      final response = await request('thread/attachment/list', {
        'threadId': normalizedThreadId,
        'limit': requestLimit,
        'cursor': ?cursor,
      });
      scannedPages += 1;

      final data = response['data'];
      if (data is! List<Object?>) {
        throw const ProtocolViolation(
          'thread/attachment/list data must be an array.',
        );
      }
      if (data.length > requestLimit) {
        throw const ProtocolViolation(
          'thread/attachment/list page exceeds the requested limit.',
        );
      }
      final nextCursor = _optionalOpaqueIdentifier(
        response,
        'nextCursor',
        _maxIdentifierLength,
        context: 'thread/attachment/list',
      );
      if (nextCursor != null && !seenCursors.add(nextCursor)) {
        throw const ProtocolViolation(
          'Duplicate thread/attachment/list pagination cursor.',
        );
      }

      scannedCount += data.length;
      for (final rawItem in data) {
        final parsed = _parseLinkedPullRequestItem(rawItem);
        if (parsed == null) {
          continue;
        }
        if (seenIdentityKeys.contains(parsed.canonicalIdentityKey)) {
          continue;
        }
        if (pullRequests.length >= maxRetainedPullRequests) {
          truncated = true;
          break;
        }
        seenIdentityKeys.add(parsed.canonicalIdentityKey);
        pullRequests.add(parsed);
      }

      if (truncated) {
        break;
      }
      if (nextCursor == null) {
        break;
      }
      if (data.isEmpty ||
          scannedCount >= maxScannedAttachments ||
          scannedPages >= maxScannedPages) {
        truncated = true;
        break;
      }
      cursor = nextCursor;
    }

    return ThreadLinkedPullRequestsSnapshot(
      threadId: normalizedThreadId,
      pullRequests: List<ThreadLinkedPullRequest>.unmodifiable(pullRequests),
      scannedAttachmentCount: scannedCount,
      truncated: truncated,
    );
  }

  /// Links a canonical GitHub Pull Request or GitLab Merge Request URL to
  /// [threadId] using `thread/attachment/add` (`attachmentType: 'pull_request'`).
  ///
  /// Performs a bounded fresh same-thread preflight scan so an already-linked
  /// legacy URL row does not receive a duplicate canonical backing row. If the
  /// bounded preflight scan stops early at the 100-row / 16-page bound (or sees
  /// an empty page with a non-null continuation cursor) before confirming
  /// absence, returns [ThreadPullRequestLinkOutcome.scanIncomplete] with a null
  /// [ThreadPullRequestLinkResult.pullRequest] without issuing a write.
  Future<ThreadPullRequestLinkResult> linkPullRequest(
    String threadId, {
    required String url,
    String? headBranch,
  }) async {
    final normalizedThreadId = _requireOpaqueArgumentId(
      threadId,
      'threadId',
      _maxIdentifierLength,
    );
    final canonicalParts = tryParseCanonicalPullRequestUrl(url);
    if (canonicalParts == null) {
      throw ArgumentError(
        'Enter a valid HTTPS GitHub Pull Request or GitLab Merge Request URL.',
        'url',
      );
    }
    final identityBytes = utf8.encode(canonicalParts.canonicalIdentityKey);
    if (identityBytes.length > maxIdentityKeyUtf8Bytes) {
      throw ArgumentError(
        'Canonical pull request identity exceeds 256 UTF-8 bytes.',
        'url',
      );
    }
    final sanitizedBranch = headBranch == null || headBranch.trim().isEmpty
        ? null
        : _requireSanitizedHeadBranchArgument(headBranch);
    final targetDisplayLabel =
        '${canonicalParts.owner}/${canonicalParts.repository}#${canonicalParts.number}';

    final preflight = await _preflightFindExistingPullRequest(
      normalizedThreadId,
      canonicalParts.canonicalIdentityKey,
    );
    if (preflight.existing case final existingPr?) {
      return ThreadPullRequestLinkResult(
        outcome: ThreadPullRequestLinkOutcome.existing,
        displayLabel: existingPr.displayLabel,
        pullRequest: existingPr,
        hiddenByDisplayCap: preflight.beyondDisplayCap,
      );
    }
    if (preflight.truncated) {
      return ThreadPullRequestLinkResult(
        outcome: ThreadPullRequestLinkOutcome.scanIncomplete,
        displayLabel: targetDisplayLabel,
      );
    }

    final payload = <String, Object?>{
      'url': canonicalParts.canonicalUrl,
      'headBranch': ?sanitizedBranch,
    };
    final response = await request('thread/attachment/add', {
      'threadId': normalizedThreadId,
      'attachmentType': 'pull_request',
      'identityKey': canonicalParts.canonicalIdentityKey,
      'payload': payload,
    });

    final outcome = switch (response['outcome']) {
      'created' => ThreadPullRequestLinkOutcome.created,
      'existing' => ThreadPullRequestLinkOutcome.existing,
      _ => throw const ProtocolViolation(
        'thread/attachment/add outcome must be "created" or "existing".',
      ),
    };
    final rawAttachment = response['attachment'];
    if (rawAttachment is! Map<String, Object?>) {
      throw const ProtocolViolation(
        'thread/attachment/add attachment must be an object.',
      );
    }
    final parsed = _parseLinkedPullRequestItem(rawAttachment);
    if (parsed == null ||
        parsed.canonicalIdentityKey != canonicalParts.canonicalIdentityKey) {
      throw const ProtocolViolation(
        'thread/attachment/add returned an invalid pull_request attachment.',
      );
    }
    return ThreadPullRequestLinkResult(
      outcome: outcome,
      displayLabel: parsed.displayLabel,
      pullRequest: parsed,
      hiddenByDisplayCap: preflight.beyondDisplayCap,
    );
  }

  Future<
    ({ThreadLinkedPullRequest? existing, bool truncated, bool beyondDisplayCap})
  >
  _preflightFindExistingPullRequest(
    String normalizedThreadId,
    String targetCanonicalIdentityKey,
  ) async {
    final seenCursors = <String>{};
    final seenCanonicalKeys = <String>{};
    String? cursor;
    var scannedCount = 0;
    var scannedPages = 0;

    while (scannedCount < maxScannedAttachments &&
        scannedPages < maxScannedPages) {
      final remainingBudget = maxScannedAttachments - scannedCount;
      final requestLimit = remainingBudget < defaultPageSize
          ? remainingBudget
          : defaultPageSize;
      final response = await request('thread/attachment/list', {
        'threadId': normalizedThreadId,
        'limit': requestLimit,
        'cursor': ?cursor,
      });
      scannedPages += 1;

      final data = response['data'];
      if (data is! List<Object?>) {
        throw const ProtocolViolation(
          'thread/attachment/list data must be an array.',
        );
      }
      if (data.length > requestLimit) {
        throw const ProtocolViolation(
          'thread/attachment/list page exceeds the requested limit.',
        );
      }
      final nextCursor = _optionalOpaqueIdentifier(
        response,
        'nextCursor',
        _maxIdentifierLength,
        context: 'thread/attachment/list',
      );
      if (nextCursor != null && !seenCursors.add(nextCursor)) {
        throw const ProtocolViolation(
          'Duplicate thread/attachment/list pagination cursor.',
        );
      }

      scannedCount += data.length;
      for (final rawItem in data) {
        final parsed = _parseLinkedPullRequestItem(rawItem);
        if (parsed == null) {
          continue;
        }
        if (parsed.canonicalIdentityKey == targetCanonicalIdentityKey) {
          return (
            existing: parsed,
            truncated: false,
            beyondDisplayCap:
                seenCanonicalKeys.length >= maxRetainedPullRequests,
          );
        }
        seenCanonicalKeys.add(parsed.canonicalIdentityKey);
      }

      if (nextCursor == null) {
        return (
          existing: null,
          truncated: false,
          beyondDisplayCap: seenCanonicalKeys.length >= maxRetainedPullRequests,
        );
      }
      if (data.isEmpty ||
          scannedCount >= maxScannedAttachments ||
          scannedPages >= maxScannedPages) {
        return (
          existing: null,
          truncated: true,
          beyondDisplayCap: seenCanonicalKeys.length >= maxRetainedPullRequests,
        );
      }
      cursor = nextCursor;
    }

    return (
      existing: null,
      truncated: true,
      beyondDisplayCap: seenCanonicalKeys.length >= maxRetainedPullRequests,
    );
  }

  static String _requireSanitizedHeadBranchArgument(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty ||
        trimmed.length > _maxHeadBranchLength ||
        _controlChars.hasMatch(trimmed)) {
      throw ArgumentError(
        'Head branch must be a single-line branch name up to $_maxHeadBranchLength characters.',
        'headBranch',
      );
    }
    return trimmed;
  }

  static ThreadLinkedPullRequest? _parseLinkedPullRequestItem(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const ProtocolViolation(
        'thread/attachment/list item must be an object.',
      );
    }
    final attachmentType = _requireOpaqueField(
      raw,
      'attachmentType',
      _maxAttachmentTypeLength,
      context: 'thread/attachment/list',
    );
    if (attachmentType != 'pull_request') {
      return null;
    }
    final attachmentId = _requireOpaqueField(
      raw,
      'id',
      _maxIdentifierLength,
      context: 'thread/attachment/list',
    );
    final identityKey = _requireBoundedSingleLineField(
      raw,
      'identityKey',
      _maxIdentityKeyLength,
      context: 'thread/attachment/list',
    );
    if (utf8.encode(identityKey).length > maxIdentityKeyUtf8Bytes) {
      return null;
    }
    final createdAt = _requireInt(raw, 'createdAt');
    final payload = raw['payload'];
    if (payload is! Map<String, Object?>) {
      return null;
    }
    final rawUrl = payload['url'];
    if (rawUrl is! String) {
      return null;
    }
    final canonicalUrlParts = tryParseCanonicalPullRequestUrl(rawUrl);
    if (canonicalUrlParts == null) {
      return null;
    }
    if (utf8.encode(canonicalUrlParts.canonicalIdentityKey).length >
        maxIdentityKeyUtf8Bytes) {
      return null;
    }
    if (!_matchesCanonicalIdentityKey(identityKey, canonicalUrlParts)) {
      return null;
    }
    final headBranch = _optionalSanitizedHeadBranch(payload['headBranch']);
    return ThreadLinkedPullRequest(
      attachmentId: attachmentId,
      canonicalIdentityKey: canonicalUrlParts.canonicalIdentityKey,
      canonicalHost: canonicalUrlParts.canonicalHost,
      owner: canonicalUrlParts.owner,
      repository: canonicalUrlParts.repository,
      number: canonicalUrlParts.number,
      canonicalUrl: canonicalUrlParts.canonicalUrl,
      createdAtSeconds: createdAt,
      headBranch: headBranch,
    );
  }

  /// Validates and canonicalizes a GitHub Pull Request or GitLab Merge Request
  /// HTTPS URL, rejecting userinfo, queries, fragments, non-default ports, and
  /// non-canonical paths.
  static ({
    String canonicalIdentityKey,
    String canonicalHost,
    String owner,
    String repository,
    int number,
    String canonicalUrl,
  })?
  tryParseCanonicalPullRequestUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty ||
        trimmed.length > _maxUrlLength ||
        _controlOrWhitespace.hasMatch(trimmed) ||
        !trimmed.toLowerCase().startsWith('https://') ||
        trimmed.contains('%') ||
        trimmed.contains('?') ||
        trimmed.contains('#') ||
        trimmed.contains('@') ||
        trimmed.contains(r'\')) {
      return null;
    }
    final afterScheme = trimmed.substring('https://'.length);
    final firstSlash = afterScheme.indexOf('/');
    if (firstSlash <= 0) {
      return null;
    }
    final rawAuthority = afterScheme.substring(0, firstSlash);
    if (rawAuthority.contains(':')) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.hasPort ||
        uri.authority.contains(':') ||
        uri.path.isEmpty ||
        uri.path.startsWith('//') ||
        uri.path.endsWith('/') ||
        uri.path.contains('//')) {
      return null;
    }

    final host = uri.host.toLowerCase();
    final List<String> segments;
    try {
      segments = uri.pathSegments;
    } on FormatException {
      return null;
    }
    if (host == 'github.com' || host == 'www.github.com') {
      if (segments.length != 4 || segments[2] != 'pull') {
        return null;
      }
      final owner = segments[0];
      final repo = segments[1];
      final number = _parsePositivePrNumber(segments[3]);
      if (!_isValidPathToken(owner) ||
          !_isValidPathToken(repo) ||
          number == null) {
        return null;
      }
      const canonicalHost = 'github.com';
      final canonicalIdentityKey = jsonEncode([
        canonicalHost,
        owner.toLowerCase(),
        repo.toLowerCase(),
        number,
      ]);
      return (
        canonicalIdentityKey: canonicalIdentityKey,
        canonicalHost: canonicalHost,
        owner: owner,
        repository: repo,
        number: number,
        canonicalUrl: 'https://github.com/$owner/$repo/pull/$number',
      );
    }

    if (host == 'gitlab.com' || host == 'www.gitlab.com') {
      final mrIndex = segments.lastIndexOf('merge_requests');
      if (mrIndex < 2 || mrIndex != segments.length - 2) {
        return null;
      }
      final repoEndIndex = segments[mrIndex - 1] == '-' ? mrIndex - 1 : mrIndex;
      if (repoEndIndex < 2 || repoEndIndex > 6) {
        return null;
      }
      final ownerSegments = segments.sublist(0, repoEndIndex - 1);
      final repo = segments[repoEndIndex - 1];
      final number = _parsePositivePrNumber(segments.last);
      if (ownerSegments.any((segment) => !_isValidPathToken(segment)) ||
          !_isValidPathToken(repo) ||
          number == null) {
        return null;
      }
      final ownerPath = ownerSegments.join('/');
      const canonicalHost = 'gitlab.com';
      final canonicalIdentityKey = jsonEncode([
        canonicalHost,
        ownerPath.toLowerCase(),
        repo.toLowerCase(),
        number,
      ]);
      return (
        canonicalIdentityKey: canonicalIdentityKey,
        canonicalHost: canonicalHost,
        owner: ownerPath,
        repository: repo,
        number: number,
        canonicalUrl:
            'https://gitlab.com/$ownerPath/$repo/-/merge_requests/$number',
      );
    }

    return null;
  }

  static bool _matchesCanonicalIdentityKey(
    String identityKey,
    ({
      String canonicalIdentityKey,
      String canonicalHost,
      String owner,
      String repository,
      int number,
      String canonicalUrl,
    })
    urlParts,
  ) {
    final trimmed = identityKey.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is! List || decoded.length != 4) {
          return false;
        }
        final host = decoded[0];
        final owner = decoded[1];
        final repo = decoded[2];
        final rawNumber = decoded[3];
        final number = switch (rawNumber) {
          final int value when value > 0 => value,
          final String text => _parsePositivePrNumber(text),
          _ => null,
        };
        if (host is! String ||
            owner is! String ||
            repo is! String ||
            number == null) {
          return false;
        }
        final normalizedHost = switch (host.trim().toLowerCase()) {
          'www.github.com' => 'github.com',
          'www.gitlab.com' => 'gitlab.com',
          final value => value,
        };
        return normalizedHost == urlParts.canonicalHost &&
            owner.trim().toLowerCase() == urlParts.owner.toLowerCase() &&
            repo.trim().toLowerCase() == urlParts.repository.toLowerCase() &&
            number == urlParts.number;
      } on FormatException {
        return false;
      }
    }

    final legacyParsed = tryParseCanonicalPullRequestUrl(trimmed);
    return legacyParsed != null &&
        legacyParsed.canonicalIdentityKey == urlParts.canonicalIdentityKey;
  }

  static bool _isValidPathToken(String value) =>
      value != '.' && value != '..' && _pathSegmentPattern.hasMatch(value);

  static int? _parsePositivePrNumber(String value) {
    if (!_positiveIntPattern.hasMatch(value)) {
      return null;
    }
    final parsed = int.tryParse(value);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static String? _optionalSanitizedHeadBranch(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _controlChars.hasMatch(trimmed)) {
      return null;
    }
    if (trimmed.length <= _maxHeadBranchLength) {
      return trimmed;
    }
    return trimmed.substring(0, _maxHeadBranchLength);
  }

  static ThreadAttachmentEvent? _parseNotification(
    CodexNotification notification,
  ) {
    if (notification.method != 'thread/attachment/updated') {
      return null;
    }
    final params = notification.params;
    final threadId = _optionalBoundedSingleLineField(
      params,
      'threadId',
      _maxIdentifierLength,
    );
    final attachmentId = _optionalBoundedSingleLineField(
      params,
      'attachmentId',
      _maxIdentifierLength,
    );
    final attachmentType = _optionalBoundedSingleLineField(
      params,
      'attachmentType',
      _maxAttachmentTypeLength,
    );
    final identityKey = _optionalBoundedSingleLineField(
      params,
      'identityKey',
      _maxIdentityKeyLength,
    );
    if (threadId == null ||
        attachmentId == null ||
        attachmentType == null ||
        identityKey == null) {
      return null;
    }
    final operation = switch (params['operation']) {
      'created' => ThreadAttachmentUpdateOperation.created,
      'deleted' => ThreadAttachmentUpdateOperation.deleted,
      _ => ThreadAttachmentUpdateOperation.unknown,
    };
    return ThreadAttachmentUpdatedEvent(
      threadId: threadId,
      attachmentId: attachmentId,
      attachmentType: attachmentType,
      identityKey: identityKey,
      operation: operation,
    );
  }

  static String _requireOpaqueArgumentId(
    String value,
    String field,
    int maxLength,
  ) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed != value ||
        trimmed.length > maxLength ||
        _controlChars.hasMatch(trimmed)) {
      throw ArgumentError.value(value, field, 'Must be a valid opaque ID.');
    }
    return trimmed;
  }

  static String _requireOpaqueField(
    JsonObject json,
    String key,
    int maxLength, {
    required String context,
  }) {
    final value = json[key];
    if (value is! String) {
      throw ProtocolViolation('$context.$key must be a string.');
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed != value ||
        trimmed.length > maxLength ||
        _controlChars.hasMatch(trimmed)) {
      throw ProtocolViolation('$context.$key must be a valid opaque ID.');
    }
    return trimmed;
  }

  static String _requireBoundedSingleLineField(
    JsonObject json,
    String key,
    int maxLength, {
    required String context,
  }) {
    final value = json[key];
    if (value is! String) {
      throw ProtocolViolation('$context.$key must be a string.');
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.length > maxLength ||
        _controlChars.hasMatch(trimmed)) {
      throw ProtocolViolation('$context.$key must be a bounded string.');
    }
    return trimmed;
  }

  static String? _optionalOpaqueIdentifier(
    JsonObject json,
    String key,
    int maxLength, {
    required String context,
  }) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ProtocolViolation('$context.$key must be a string or null.');
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed != value ||
        trimmed.length > maxLength ||
        _controlChars.hasMatch(trimmed)) {
      throw ProtocolViolation('$context.$key must be a valid opaque cursor.');
    }
    return trimmed;
  }

  static String? _optionalBoundedSingleLineField(
    JsonObject json,
    String key,
    int maxLength,
  ) {
    final value = json[key];
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.length > maxLength ||
        _controlChars.hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  static int _requireInt(JsonObject json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    throw ProtocolViolation('Attachment field "$key" must be an int.');
  }
}
