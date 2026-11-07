import 'execution_settings.dart';
import 'user_message_presentation.dart';

enum ThreadRuntimeStatus { notLoaded, idle, active, systemError, unknown }

enum ThreadSortKey { createdAt, updatedAt, recencyAt }

enum SortDirection { ascending, descending }

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
    final normalized = parseUserMessagePresentation(preview).bodyText.trim();
    final source = normalized.isEmpty ? preview.trim() : normalized;
    for (final rawLine in source.split('\n')) {
      final cleaned = rawLine.trim().replaceFirst(RegExp(r'^#+\s*'), '').trim();
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
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
    this.model,
    this.approvalPolicy,
    this.sandbox,
  });

  final String cwd;
  final bool ephemeral;
  final String? model;
  final ApprovalPolicyOverride? approvalPolicy;
  final SandboxModeOverride? sandbox;
}
