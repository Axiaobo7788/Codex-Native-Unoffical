import '../domain/execution_settings.dart';
import '../domain/thread_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';

typedef ProtocolRequest = Future<JsonObject> Function(
  String method, [
  JsonObject params,
]);

/// Typed v2 thread protocol surface.
///
/// Full turns are deliberately never requested here. Conversation pagination
/// belongs to separate adapters so metadata screens cannot accidentally hydrate
/// an entire thread.
final class ThreadProtocolAdapter {
  static const _maxGitBranchLength = 512;
  static const _maxGitOriginLength = 1024;
  static const _maxGitShaLength = 128;
  static const _maxGoalObjectiveLength = ThreadGoal.maxObjectiveLength;
  static const _maxIdentifierLength = 512;
  static const _maxSectionNameLength = 128;
  static const _maxSectionAppearanceTokenLength = 64;
  static const _maxSectionsPerPage = 64;

  ThreadProtocolAdapter({
    required this.request,
    Stream<CodexNotification> notifications = const Stream.empty(),
  }) : events = notifications
           .map(_parseNotification)
           .where((event) => event != null)
           .cast<ThreadLifecycleEvent>();

  final ProtocolRequest request;
  final Stream<ThreadLifecycleEvent> events;

  Future<ThreadPage> listThreads(ThreadListQuery query) async {
    final searchTerm = query.searchTerm?.trim();
    final sectionId = switch (query.section?.id) {
      final id? => _requireOpaqueArgumentId(
        id,
        'sectionId',
        _maxIdentifierLength,
      ),
      null => null,
    };
    if (query.sortKey == ThreadSortKey.sectionPosition && sectionId == null) {
      throw ArgumentError('Section-position sorting requires a section ID.');
    }
    final response = await request('thread/list', {
      if (query.cursor != null) 'cursor': query.cursor,
      'limit': query.limit,
      'sortKey': _sortKey(query.sortKey),
      'sortDirection': _sortDirection(query.sortDirection),
      'archived': query.archived,
      if (query.section != null) 'sectionId': sectionId,
      if (searchTerm != null && searchTerm.isNotEmpty) 'searchTerm': searchTerm,
    });
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ProtocolViolation('thread/list data must be an array.');
    }
    if (query.section != null && data.length > query.limit) {
      throw const ProtocolViolation(
        'Scoped thread page exceeds the requested limit.',
      );
    }
    final receipts = response['readStates'];
    final threads = data
        .map((row) {
          final thread = _parseThread(row);
          final receipt = receipts is Map<String, Object?>
              ? _parseReadReceipt(receipts[thread.id])
              : null;
          return thread.ephemeral || receipt == null
              ? thread
              : thread.copyWith(readReceipt: receipt);
        })
        .toList(growable: false);
    if (query.section != null &&
        threads.any((thread) => thread.section?.id != sectionId)) {
      throw const ProtocolViolation(
        'Scoped thread page contains a different section.',
      );
    }
    return ThreadPage(
      threads: threads,
      nextCursor: query.section == null
          ? _optionalString(response, 'nextCursor')
          : _optionalOpaqueIdentifier(
              response,
              'nextCursor',
              _maxIdentifierLength,
              context: 'thread/list',
            ),
    );
  }

  Future<ThreadSummary> startThread(ThreadStartOptions options) async {
    final response = await request('thread/start', {
      'cwd': options.cwd,
      'ephemeral': options.ephemeral,
      if (options.model != null) 'model': options.model,
      if (options.approvalPolicy case final approvalPolicy?)
        'approvalPolicy': _approvalPolicy(approvalPolicy),
      if (options.sandbox case final sandbox?) 'sandbox': _sandbox(sandbox),
    });
    return _parseThreadContainer(response, 'thread/start');
  }

  Future<ThreadSummary> readThread(String threadId) async {
    final response = await request('thread/read', {
      'threadId': threadId,
      'includeTurns': false,
    });
    final thread = _parseThreadContainer(response, 'thread/read');
    if (thread.id != threadId) {
      throw const ProtocolViolation(
        'thread/read returned a different thread ID than requested.',
      );
    }
    final receipt = _parseReadReceipt(response['readState']);
    return thread.ephemeral || receipt == null
        ? thread
        : thread.copyWith(readReceipt: receipt);
  }

  Future<ThreadReadReceipt> setReadReceipt({
    required String threadId,
    required String expectedRevision,
    required bool unread,
  }) async {
    final response = await request('thread/readState/update', {
      'threadId': _requireOpaqueArgumentId(
        threadId,
        'threadId',
        _maxIdentifierLength,
      ),
      'expectedRevision': _requireOpaqueArgumentId(
        expectedRevision,
        'expectedRevision',
        _maxIdentifierLength,
      ),
      'operation': {'type': unread ? 'unread' : 'read'},
    });
    final receipt = _parseReadReceipt(response['readState']);
    if (receipt == null) {
      throw const ProtocolViolation('Invalid updated thread read receipt.');
    }
    return receipt;
  }

  Future<ThreadSummary> resumeThread(String threadId) async {
    final response = await request('thread/resume', {
      'threadId': threadId,
      'excludeTurns': true,
    });
    return _parseThreadContainer(response, 'thread/resume');
  }

  Future<void> renameThread({
    required String threadId,
    required String name,
  }) async {
    await request('thread/name/set', {'threadId': threadId, 'name': name});
  }

  Future<void> archiveThread(String threadId) async {
    await request('thread/archive', {'threadId': threadId});
  }

  Future<ThreadSummary> unarchiveThread(String threadId) async {
    final response = await request('thread/unarchive', {'threadId': threadId});
    return _parseThreadContainer(response, 'thread/unarchive');
  }

  Future<ThreadSummary> forkThread(ThreadForkOptions options) async {
    final response = await request('thread/fork', {
      'threadId': options.threadId,
      'excludeTurns': true,
      'ephemeral': options.ephemeral,
      if (options.beforeTurnId != null) 'beforeTurnId': options.beforeTurnId,
      if (options.lastTurnId != null) 'lastTurnId': options.lastTurnId,
      if (options.cwd != null) 'cwd': options.cwd,
      if (options.model != null) 'model': options.model,
      if (options.approvalPolicy case final approvalPolicy?)
        'approvalPolicy': _approvalPolicy(approvalPolicy),
      if (options.sandbox case final sandbox?) 'sandbox': _sandbox(sandbox),
    });
    return _parseThreadContainer(response, 'thread/fork');
  }

  Future<ThreadSummary> revertThread({
    required String threadId,
    required String beforeTurnId,
  }) async {
    final response = await request('thread/revert', {
      'threadId': threadId,
      'beforeTurnId': beforeTurnId,
    });
    return _parseThreadContainer(response, 'thread/revert');
  }

  Future<void> compactThread(String threadId) async {
    await request('thread/compact/start', {'threadId': threadId});
  }

  Future<void> deleteThread(String threadId) async {
    await request('thread/delete', {'threadId': threadId});
  }

  Future<ThreadGoal?> readThreadGoal(String threadId) async {
    final id = _requireOpaqueArgumentId(
      threadId,
      'threadId',
      _maxIdentifierLength,
    );
    final response = await request('thread/goal/get', {'threadId': id});
    if (response['goal'] == null) {
      return null;
    }
    return _parseGoal(
      _requiredObject(response, 'goal', 'thread/goal/get'),
      threadId: id,
    );
  }

  Future<ThreadGoal> setThreadGoal(
    String threadId, {
    String? objective,
    ThreadGoalStatus? status,
  }) async {
    final id = _requireOpaqueArgumentId(
      threadId,
      'threadId',
      _maxIdentifierLength,
    );
    final trimmed = objective?.trim();
    if (trimmed != null &&
        (trimmed.isEmpty || trimmed.length > _maxGoalObjectiveLength)) {
      throw ArgumentError(
        'Goal objective must contain 1–$_maxGoalObjectiveLength characters.',
      );
    }
    if (trimmed == null && status == null) {
      throw ArgumentError('A goal objective or status is required.');
    }
    final wireStatus = switch (status) {
      ThreadGoalStatus.active => 'active',
      ThreadGoalStatus.paused => 'paused',
      null => null,
      _ => throw ArgumentError(
        'Only active and paused are user-selectable goal states.',
      ),
    };
    final response = await request('thread/goal/set', {
      'threadId': id,
      'origin': 'user',
      'objective': ?trimmed,
      'status': ?wireStatus,
    });
    return _parseGoal(
      _requiredObject(response, 'goal', 'thread/goal/set'),
      threadId: id,
    );
  }

  Future<bool> clearThreadGoal(String threadId) async {
    final id = _requireOpaqueArgumentId(
      threadId,
      'threadId',
      _maxIdentifierLength,
    );
    final response = await request('thread/goal/clear', {
      'threadId': id,
      'origin': 'user',
    });
    return _requiredBool(response, 'cleared');
  }

  Future<ThreadSectionPage> listThreadSections([
    ThreadSectionListQuery query = const ThreadSectionListQuery(),
  ]) async {
    final cursor = _optionalOpaqueArgumentId(
      query.cursor,
      'cursor',
      _maxIdentifierLength,
    );
    final effectiveLimit = query.limit.clamp(1, _maxSectionsPerPage);
    final response = await request('threadSection/list', {
      'cursor': ?cursor,
      'limit': effectiveLimit,
    });
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ProtocolViolation(
        'threadSection/list data must be an array.',
      );
    }
    final nextCursor = _optionalOpaqueIdentifier(
      response,
      'nextCursor',
      _maxIdentifierLength,
      context: 'threadSection/list',
    );
    if (data.length > _maxSectionsPerPage) {
      throw const ProtocolViolation(
        'threadSection/list returned more than 64 sections in a single page.',
      );
    }
    final sections = <ThreadSection>[];
    final seenIds = <String>{};
    for (final raw in data) {
      final section = _parseRequiredSection(raw);
      if (seenIds.add(section.id)) {
        sections.add(section);
      }
    }
    return ThreadSectionPage(
      sections: List.unmodifiable(sections),
      nextCursor: nextCursor,
    );
  }

  Future<ThreadSection> createThreadSection(
    ThreadSectionCreateOptions options,
  ) async {
    final name = _requireArgumentText(
      options.name,
      'name',
      _maxSectionNameLength,
    );
    final response = await request('threadSection/create', {
      'name': name,
      if (options.appearance case final appearance?)
        'appearance': _encodeSectionAppearance(appearance),
    });
    return _parseSectionContainer(response, 'threadSection/create');
  }

  Future<ThreadSection> updateThreadSection(
    ThreadSectionUpdateOptions options,
  ) async {
    final sectionId = _requireOpaqueArgumentId(
      options.sectionId,
      'sectionId',
      _maxIdentifierLength,
    );
    if (sectionId == kBuiltInPinnedThreadSectionId) {
      throw ArgumentError.value(
        options.sectionId,
        'sectionId',
        'The built-in Pinned section cannot be renamed.',
      );
    }
    final name = _requireArgumentText(
      options.name,
      'name',
      _maxSectionNameLength,
    );
    final response = await request('threadSection/update', {
      'sectionId': sectionId,
      'name': name,
      if (options.clearAppearance)
        'appearance': null
      else if (options.appearance case final appearance?)
        'appearance': _encodeSectionAppearance(appearance),
    });
    return _parseSectionContainer(response, 'threadSection/update');
  }

  Future<void> deleteThreadSection(String sectionId) async {
    final normalizedId = _requireOpaqueArgumentId(
      sectionId,
      'sectionId',
      _maxIdentifierLength,
    );
    if (normalizedId == kBuiltInPinnedThreadSectionId) {
      throw ArgumentError.value(
        sectionId,
        'sectionId',
        'The built-in Pinned section cannot be deleted.',
      );
    }
    await request('threadSection/delete', {'sectionId': normalizedId});
  }

  Future<void> moveThreadSection(ThreadSectionMoveOptions options) async {
    final threadId = _requireOpaqueArgumentId(
      options.threadId,
      'threadId',
      _maxIdentifierLength,
    );
    final sectionId = _optionalOpaqueArgumentId(
      options.sectionId,
      'sectionId',
      _maxIdentifierLength,
    );
    final beforeThreadId = _optionalOpaqueArgumentId(
      options.beforeThreadId,
      'beforeThreadId',
      _maxIdentifierLength,
    );
    await request('thread/section/move', {
      'threadId': threadId,
      'sectionId': sectionId,
      'beforeThreadId': ?beforeThreadId,
    });
  }

  static ThreadLifecycleEvent? _parseNotification(
    CodexNotification notification,
  ) {
    final params = notification.params;
    return switch (notification.method) {
      'thread/name/updated' => ThreadNameUpdatedEvent(
        threadId: _requiredString(params, 'threadId'),
        threadName: params.containsKey('threadName')
            ? _optionalString(params, 'threadName')
            : _optionalString(params, 'name'),
      ),
      'thread/archived' => ThreadArchivedEvent(
        threadId: _requiredString(params, 'threadId'),
      ),
      'thread/unarchived' => ThreadUnarchivedEvent(
        threadId: _requiredString(params, 'threadId'),
      ),
      'thread/reverted' => ThreadRevertedEvent(
        threadId: _requiredString(params, 'threadId'),
        turnsBackwardsCursor: _optionalString(params, 'turnsBackwardsCursor'),
        itemsBackwardsCursor: _optionalString(params, 'itemsBackwardsCursor'),
      ),
      'thread/status/changed' => _parseStatusChanged(params),
      'thread/goal/updated' => _parseGoalUpdated(params),
      'thread/goal/cleared' => ThreadGoalClearedEvent(
        threadId: _requiredString(params, 'threadId'),
      ),
      'thread/readState/changed' => _parseReadReceiptChanged(params),
      'thread/section/changed' => _parseSectionChanged(params),
      _ => null,
    };
  }

  static ThreadReadReceiptChangedEvent? _parseReadReceiptChanged(
    JsonObject params,
  ) {
    final threadId = params['threadId'];
    final receipt = _parseReadReceipt(params['readState']);
    if (!_isReadReceiptToken(threadId) || receipt == null) {
      return null;
    }
    return ThreadReadReceiptChangedEvent(
      threadId: threadId as String,
      receipt: receipt,
    );
  }

  static ThreadReadReceipt? _parseReadReceipt(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }
    final revision = value['revision'];
    if (!_isReadReceiptToken(revision)) {
      return null;
    }
    final unread = switch (value['firstUnread']) {
      null => false,
      {'type': 'threadStart'} => true,
      {'type': 'turn', 'turnId': final id} when _isReadReceiptToken(id) => true,
      _ => null,
    };
    return unread == null
        ? null
        : ThreadReadReceipt(revision: revision as String, unread: unread);
  }

  static bool _isReadReceiptToken(Object? value) =>
      value is String &&
      value.trim().isNotEmpty &&
      value.length <= _maxIdentifierLength;

  static ThreadStatusChangedEvent _parseStatusChanged(JsonObject params) {
    final statusValue = params['status'];
    if (statusValue is! Map<String, Object?>) {
      throw const ProtocolViolation('Thread status must be an object.');
    }
    return ThreadStatusChangedEvent(
      threadId: _requiredString(params, 'threadId'),
      status: _status(_requiredString(statusValue, 'type')),
    );
  }

  static ThreadGoalUpdatedEvent _parseGoalUpdated(JsonObject params) {
    final threadId = _requiredOpaqueIdentifier(
      params,
      'threadId',
      _maxIdentifierLength,
      context: 'thread/goal/updated',
    );
    return ThreadGoalUpdatedEvent(
      threadId: threadId,
      turnId: _boundedOptionalString(params, 'turnId', _maxIdentifierLength),
      goal: _parseGoal(
        _requiredObject(params, 'goal', 'thread/goal/updated'),
        threadId: threadId,
      ),
    );
  }

  static ThreadGoal _parseGoal(JsonObject rawGoal, {required String threadId}) {
    if (_requiredString(rawGoal, 'threadId') != threadId) {
      throw const ProtocolViolation(
        'Thread goal threadId must match its requested or notified thread.',
      );
    }
    final rawTokenBudget = rawGoal['tokenBudget'];
    if (rawTokenBudget != null &&
        (rawTokenBudget is! int || rawTokenBudget < 0)) {
      throw const ProtocolViolation(
        'Thread goal tokenBudget must be a non-negative integer or null.',
      );
    }
    return ThreadGoal(
      objective: _truncate(
        _requiredString(rawGoal, 'objective').trim(),
        _maxGoalObjectiveLength,
      ),
      status: _goalStatus(_requiredString(rawGoal, 'status')),
      createdAtSeconds: _nonNegativeInt(rawGoal, 'createdAt'),
      updatedAtSeconds: _nonNegativeInt(rawGoal, 'updatedAt'),
      tokensUsed: _nonNegativeInt(rawGoal, 'tokensUsed'),
      timeUsedSeconds: _nonNegativeInt(rawGoal, 'timeUsedSeconds'),
      tokenBudget: rawTokenBudget as int?,
    );
  }

  static ThreadSummary _parseThreadContainer(
    JsonObject response,
    String method,
  ) {
    final thread = response['thread'];
    if (thread is! Map<String, Object?>) {
      throw ProtocolViolation('$method response did not contain a thread.');
    }
    return _parseThread(thread);
  }

  static ThreadSummary _parseThread(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation('Thread entry must be an object.');
    }
    final statusValue = value['status'];
    if (statusValue is! Map<String, Object?>) {
      throw const ProtocolViolation('Thread status must be an object.');
    }

    return ThreadSummary(
      id: _requiredString(value, 'id'),
      sessionId: _requiredString(value, 'sessionId'),
      preview: _requiredString(value, 'preview'),
      cwd: _requiredString(value, 'cwd'),
      createdAt: _timestamp(value, 'createdAt'),
      updatedAt: _timestamp(value, 'updatedAt'),
      status: _status(_requiredString(statusValue, 'type')),
      ephemeral: _requiredBool(value, 'ephemeral'),
      name: _optionalString(value, 'name'),
      model: _optionalString(value, 'model'),
      projectId: _optionalString(value, 'projectId'),
      gitInfo: _parseGitInfo(value['gitInfo']),
      section: _parseSection(value['section']),
      sectionEnteredAtSeconds: _optionalNonNegativeInt(
        value,
        'sectionEnteredAt',
      ),
    );
  }

  static ThreadSectionChangedEvent _parseSectionChanged(JsonObject params) {
    final threadId = _requiredOpaqueIdentifier(
      params,
      'threadId',
      _maxIdentifierLength,
      context: 'thread/section/changed',
    );
    if (!params.containsKey('sectionId')) {
      throw const ProtocolViolation(
        'thread/section/changed field sectionId is required.',
      );
    }
    final rawSectionId = params['sectionId'];
    String? sectionId;
    if (rawSectionId != null) {
      if (rawSectionId is! String) {
        throw const ProtocolViolation(
          'thread/section/changed field sectionId must be a string or null.',
        );
      }
      final trimmed = rawSectionId.trim();
      if (trimmed.isEmpty) {
        throw const ProtocolViolation(
          'thread/section/changed field sectionId must not be empty when non-null.',
        );
      }
      if (trimmed.length > _maxIdentifierLength) {
        throw const ProtocolViolation(
          'thread/section/changed field sectionId exceeds maximum identifier length.',
        );
      }
      sectionId = trimmed;
    }
    return ThreadSectionChangedEvent(threadId: threadId, sectionId: sectionId);
  }

  static ThreadSection _parseSectionContainer(
    JsonObject response,
    String method,
  ) {
    final section = response['section'];
    if (section is! Map<String, Object?>) {
      throw ProtocolViolation('$method response did not contain a section.');
    }
    return _parseRequiredSection(section);
  }

  static ThreadSection? _parseSection(Object? value) {
    if (value == null) {
      return null;
    }
    return _parseRequiredSection(value);
  }

  static ThreadSection _parseRequiredSection(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation('Thread section must be an object.');
    }
    return ThreadSection(
      id: _requiredOpaqueIdentifier(
        value,
        'id',
        _maxIdentifierLength,
        context: 'ThreadSection',
      ),
      name: _requiredBoundedNonEmptyString(
        value,
        'name',
        _maxSectionNameLength,
        context: 'ThreadSection',
      ),
      appearance: _parseSectionAppearance(value['appearance']),
    );
  }

  static ThreadSectionAppearance? _parseSectionAppearance(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation(
        'ThreadSection field appearance must be an object or null.',
      );
    }
    final color = _boundedOptionalString(
      value,
      'color',
      _maxSectionAppearanceTokenLength,
    );
    final icon = _boundedOptionalString(
      value,
      'icon',
      _maxSectionAppearanceTokenLength,
    );
    if (color == null && icon == null) {
      return const ThreadSectionAppearance();
    }
    return ThreadSectionAppearance(color: color, icon: icon);
  }

  static JsonObject _encodeSectionAppearance(
    ThreadSectionAppearance appearance,
  ) {
    final color = appearance.color?.trim();
    final icon = appearance.icon?.trim();
    return {
      if (color != null && color.isNotEmpty)
        'color': _truncate(color, _maxSectionAppearanceTokenLength),
      if (icon != null && icon.isNotEmpty)
        'icon': _truncate(icon, _maxSectionAppearanceTokenLength),
    };
  }

  static String _requireArgumentText(String raw, String name, int maxLength) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(raw, name, '$name must not be empty.');
    }
    return _truncate(trimmed, maxLength);
  }

  static String _requireOpaqueArgumentId(
    String raw,
    String name,
    int maxLength,
  ) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(raw, name, '$name must not be empty.');
    }
    if (trimmed.length > maxLength) {
      throw ArgumentError.value(
        raw,
        name,
        '$name exceeds maximum identifier length ($maxLength).',
      );
    }
    return trimmed;
  }

  static String? _optionalOpaqueArgumentId(
    String? raw,
    String name,
    int maxLength,
  ) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > maxLength) {
      throw ArgumentError.value(
        raw,
        name,
        '$name exceeds maximum identifier length ($maxLength).',
      );
    }
    return trimmed;
  }

  static ThreadGitInfo? _parseGitInfo(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation('Thread field gitInfo must be an object.');
    }
    return ThreadGitInfo(
      branch: _boundedOptionalString(value, 'branch', _maxGitBranchLength),
      originUrl: _sanitizeOriginUrl(_optionalString(value, 'originUrl')),
      sha: _boundedOptionalString(value, 'sha', _maxGitShaLength),
    );
  }

  static String? _sanitizeOriginUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    // Do not truncate an origin before parsing it. A truncated URI can change
    // meaning, and rebuilding it may percent-encode the ellipsis beyond the
    // bounded projection. Overlong origins are diagnostic metadata, so failing
    // closed is safer than retaining an ambiguous partial credential surface.
    if (normalized.length > _maxGitOriginLength) {
      return null;
    }
    if (!normalized.contains('://')) {
      final userSeparator = normalized.indexOf('@');
      if (userSeparator >= 0) {
        final credentialSeparator = normalized.indexOf(':');
        if (credentialSeparator < userSeparator) {
          return null;
        }
        final pathSeparator = normalized.indexOf(':', userSeparator + 1);
        if (pathSeparator <= userSeparator + 1) {
          return null;
        }
        return _stripOriginSuffix(normalized);
      }
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return null;
    }
    if (!uri.hasScheme) {
      return _stripOriginSuffix(normalized);
    }
    if (uri.host.isEmpty) {
      return null;
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }

  static String? _stripOriginSuffix(String value) {
    final querySeparator = value.indexOf('?');
    final fragmentSeparator = value.indexOf('#');
    final suffixSeparators = [
      querySeparator,
      fragmentSeparator,
    ].where((index) => index >= 0).toList();
    final safeLength = suffixSeparators.isEmpty
        ? value.length
        : suffixSeparators.reduce((left, right) => left < right ? left : right);
    final safeOrigin = value.substring(0, safeLength).trim();
    return safeOrigin.isEmpty ? null : safeOrigin;
  }

  static JsonObject _requiredObject(
    JsonObject object,
    String key,
    String context,
  ) {
    final value = object[key];
    if (value is! Map<String, Object?>) {
      throw ProtocolViolation('$context field $key must be an object.');
    }
    return value;
  }

  static String _requiredString(JsonObject object, String key) {
    final value = object[key];
    if (value is! String) {
      throw ProtocolViolation('Thread field $key must be a string.');
    }
    return value;
  }

  static String? _optionalString(JsonObject object, String key) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ProtocolViolation('Thread field $key must be a string or null.');
    }
    return value;
  }

  static String? _boundedOptionalString(
    JsonObject object,
    String key,
    int limit,
  ) {
    final value = _optionalString(object, key)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return _truncate(value, limit);
  }

  static String _requiredBoundedNonEmptyString(
    JsonObject object,
    String key,
    int limit, {
    required String context,
  }) {
    final value = object[key];
    if (value is! String) {
      throw ProtocolViolation('$context field $key must be a string.');
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ProtocolViolation('$context field $key must not be empty.');
    }
    return _truncate(trimmed, limit);
  }

  static String _requiredOpaqueIdentifier(
    JsonObject object,
    String key,
    int limit, {
    required String context,
  }) {
    final value = object[key];
    if (value is! String) {
      throw ProtocolViolation('$context field $key must be a string.');
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ProtocolViolation('$context field $key must not be empty.');
    }
    if (trimmed.length > limit) {
      throw ProtocolViolation(
        '$context field $key exceeds maximum identifier length ($limit).',
      );
    }
    return trimmed;
  }

  static String? _optionalOpaqueIdentifier(
    JsonObject object,
    String key,
    int limit, {
    required String context,
  }) {
    final value = _optionalString(object, key)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length > limit) {
      throw ProtocolViolation(
        '$context field $key exceeds maximum identifier length ($limit).',
      );
    }
    return value;
  }

  static int? _optionalNonNegativeInt(JsonObject object, String key) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! int || value < 0) {
      throw ProtocolViolation(
        'Thread field $key must be a non-negative integer or null.',
      );
    }
    return value;
  }

  static int _nonNegativeInt(JsonObject object, String key) {
    final value = object[key];
    if (value is! int || value < 0) {
      throw ProtocolViolation(
        'Thread field $key must be a non-negative integer.',
      );
    }
    return value;
  }

  static bool _requiredBool(JsonObject object, String key) {
    final value = object[key];
    if (value is! bool) {
      throw ProtocolViolation('Thread field $key must be a boolean.');
    }
    return value;
  }

  static DateTime _timestamp(JsonObject object, String key) {
    final value = object[key];
    if (value is! num) {
      throw ProtocolViolation('Thread field $key must be a timestamp.');
    }
    return DateTime.fromMillisecondsSinceEpoch(
      (value * Duration.millisecondsPerSecond).round(),
    );
  }

  static ThreadRuntimeStatus _status(String value) => switch (value) {
    'notLoaded' => ThreadRuntimeStatus.notLoaded,
    'idle' => ThreadRuntimeStatus.idle,
    'active' => ThreadRuntimeStatus.active,
    'systemError' => ThreadRuntimeStatus.systemError,
    _ => ThreadRuntimeStatus.unknown,
  };

  static ThreadGoalStatus _goalStatus(String value) => switch (value) {
    'active' => ThreadGoalStatus.active,
    'paused' => ThreadGoalStatus.paused,
    'blocked' => ThreadGoalStatus.blocked,
    'usageLimited' => ThreadGoalStatus.usageLimited,
    'budgetLimited' => ThreadGoalStatus.budgetLimited,
    'complete' => ThreadGoalStatus.complete,
    _ => ThreadGoalStatus.unknown,
  };

  static String _truncate(String value, int limit) {
    if (value.length <= limit) {
      return value;
    }
    var end = limit;
    if (end > 0) {
      final lastUnit = value.codeUnitAt(end - 1);
      if (lastUnit >= 0xD800 && lastUnit <= 0xDBFF) {
        end -= 1;
      }
    }
    return '${value.substring(0, end)}…';
  }

  static String _sortKey(ThreadSortKey key) => switch (key) {
    ThreadSortKey.createdAt => 'created_at',
    ThreadSortKey.updatedAt => 'updated_at',
    ThreadSortKey.recencyAt => 'recency_at',
    ThreadSortKey.sectionPosition => 'section_position',
  };

  static String _sortDirection(SortDirection direction) => switch (direction) {
    SortDirection.ascending => 'asc',
    SortDirection.descending => 'desc',
  };

  static String _approvalPolicy(ApprovalPolicyOverride policy) =>
      switch (policy) {
        ApprovalPolicyOverride.untrusted => 'untrusted',
        ApprovalPolicyOverride.onRequest => 'on-request',
        ApprovalPolicyOverride.never => 'never',
      };

  static String _sandbox(SandboxModeOverride sandbox) => switch (sandbox) {
    SandboxModeOverride.readOnly => 'read-only',
    SandboxModeOverride.workspaceWrite => 'workspace-write',
    SandboxModeOverride.dangerFullAccess => 'danger-full-access',
  };
}
