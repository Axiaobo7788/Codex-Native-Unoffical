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
  static const _maxGoalObjectiveLength = 2048;
  static const _maxIdentifierLength = 512;

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
    final response = await request('thread/list', {
      if (query.cursor != null) 'cursor': query.cursor,
      'limit': query.limit,
      'sortKey': _sortKey(query.sortKey),
      'sortDirection': _sortDirection(query.sortDirection),
      'archived': query.archived,
      if (searchTerm != null && searchTerm.isNotEmpty) 'searchTerm': searchTerm,
    });
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ProtocolViolation('thread/list data must be an array.');
    }
    final threads = data.map(_parseThread).toList(growable: false);
    return ThreadPage(
      threads: threads,
      nextCursor: _optionalString(response, 'nextCursor'),
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
    return _parseThreadContainer(response, 'thread/read');
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
      _ => null,
    };
  }

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
    final threadId = _requiredString(params, 'threadId');
    final rawGoal = _requiredObject(params, 'goal', 'thread/goal/updated');
    final goalThreadId = _requiredString(rawGoal, 'threadId');
    if (goalThreadId != threadId) {
      throw const ProtocolViolation(
        'Thread goal threadId must match the notification threadId.',
      );
    }
    final rawTokenBudget = rawGoal['tokenBudget'];
    if (rawTokenBudget != null &&
        (rawTokenBudget is! int || rawTokenBudget < 0)) {
      throw const ProtocolViolation(
        'Thread goal tokenBudget must be a non-negative integer or null.',
      );
    }
    return ThreadGoalUpdatedEvent(
      threadId: threadId,
      turnId: _boundedOptionalString(params, 'turnId', _maxIdentifierLength),
      goal: ThreadGoal(
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
      ),
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
    );
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
      originUrl: _sanitizeOriginUrl(
        _boundedOptionalString(value, 'originUrl', _maxGitOriginLength),
      ),
      sha: _boundedOptionalString(value, 'sha', _maxGitShaLength),
    );
  }

  static String? _sanitizeOriginUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
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

  static String _truncate(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit)}…';

  static String _sortKey(ThreadSortKey key) => switch (key) {
    ThreadSortKey.createdAt => 'created_at',
    ThreadSortKey.updatedAt => 'updated_at',
    ThreadSortKey.recencyAt => 'recency_at',
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
