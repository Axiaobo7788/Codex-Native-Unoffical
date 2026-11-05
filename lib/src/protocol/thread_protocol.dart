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
  const ThreadProtocolAdapter({required this.request});

  final ProtocolRequest request;

  Future<ThreadPage> listThreads(ThreadListQuery query) async {
    final response = await request('thread/list', {
      if (query.cursor != null) 'cursor': query.cursor,
      'limit': query.limit,
      'sortKey': _sortKey(query.sortKey),
      'sortDirection': _sortDirection(query.sortDirection),
      'archived': false,
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

  Future<void> deleteThread(String threadId) async {
    await request('thread/delete', {'threadId': threadId});
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
    );
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

  static String _sortKey(ThreadSortKey key) => switch (key) {
    ThreadSortKey.createdAt => 'created_at',
    ThreadSortKey.updatedAt => 'updated_at',
    ThreadSortKey.recencyAt => 'recency_at',
  };

  static String _sortDirection(SortDirection direction) => switch (direction) {
    SortDirection.ascending => 'asc',
    SortDirection.descending => 'desc',
  };

  static String _approvalPolicy(ThreadApprovalPolicy policy) =>
      switch (policy) {
        ThreadApprovalPolicy.untrusted => 'untrusted',
        ThreadApprovalPolicy.onRequest => 'on-request',
        ThreadApprovalPolicy.never => 'never',
      };

  static String _sandbox(ThreadSandboxMode sandbox) => switch (sandbox) {
    ThreadSandboxMode.readOnly => 'read-only',
    ThreadSandboxMode.workspaceWrite => 'workspace-write',
    ThreadSandboxMode.dangerFullAccess => 'danger-full-access',
  };
}
