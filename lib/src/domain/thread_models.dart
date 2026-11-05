enum ThreadRuntimeStatus { notLoaded, idle, active, systemError, unknown }

enum ThreadSortKey { createdAt, updatedAt, recencyAt }

enum SortDirection { ascending, descending }

/// Optional per-thread approval policy overrides supported by app-server v2.
///
/// Production callers normally leave this unset so Codex uses the user's
/// configured policy. Explicit values are useful for settings UI and bounded
/// protocol smoke tests.
enum ThreadApprovalPolicy { untrusted, onRequest, never }

enum ThreadSandboxMode { readOnly, workspaceWrite, dangerFullAccess }

class ThreadSummary {
  const ThreadSummary({
    required this.id,
    required this.sessionId,
    required this.preview,
    required this.cwd,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.ephemeral,
    this.name,
    this.model,
    this.projectId,
  });

  final String id;
  final String sessionId;
  final String preview;
  final String cwd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ThreadRuntimeStatus status;
  final bool ephemeral;
  final String? name;
  final String? model;
  final String? projectId;

  String get displayTitle {
    final explicitName = name?.trim();
    if (explicitName != null && explicitName.isNotEmpty) {
      return explicitName;
    }
    final firstLine = preview.trim().split('\n').firstOrNull;
    if (firstLine != null && firstLine.isNotEmpty) {
      return firstLine;
    }
    return 'Untitled thread';
  }
}

class ThreadPage {
  const ThreadPage({required this.threads, required this.nextCursor});

  final List<ThreadSummary> threads;
  final String? nextCursor;
}

class ThreadListQuery {
  const ThreadListQuery({
    this.cursor,
    this.limit = 25,
    this.sortKey = ThreadSortKey.recencyAt,
    this.sortDirection = SortDirection.descending,
  }) : assert(limit > 0 && limit <= 100);

  final String? cursor;
  final int limit;
  final ThreadSortKey sortKey;
  final SortDirection sortDirection;
}

class ThreadStartOptions {
  const ThreadStartOptions({
    required this.cwd,
    this.ephemeral = false,
    this.approvalPolicy,
    this.sandbox,
  });

  final String cwd;
  final bool ephemeral;
  final ThreadApprovalPolicy? approvalPolicy;
  final ThreadSandboxMode? sandbox;
}
