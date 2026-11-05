import 'thread_models.dart';
import 'turn_models.dart';

enum HistoryItemKind { user, assistant, activity, reasoning, unknown }

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.turnId,
    required this.kind,
    required this.text,
    this.status,
  });

  final String id;
  final String turnId;
  final HistoryItemKind kind;
  final String text;
  final String? status;
}

class HistoryTurn {
  const HistoryTurn({
    required this.id,
    required this.status,
    required this.items,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final TurnRuntimeStatus status;
  final List<HistoryItem> items;
  final DateTime? startedAt;
  final DateTime? completedAt;
}

class HistoryTurnPage {
  const HistoryTurnPage({required this.turns, required this.nextCursor});

  final List<HistoryTurn> turns;
  final String? nextCursor;
}

class HistoryItemPage {
  const HistoryItemPage({required this.items, required this.nextCursor});

  final List<HistoryItem> items;
  final String? nextCursor;
}

class HistoryTurnQuery {
  const HistoryTurnQuery({
    required this.threadId,
    this.cursor,
    this.limit = 20,
    this.sortDirection = SortDirection.descending,
  }) : assert(limit > 0 && limit <= 50);

  final String threadId;
  final String? cursor;
  final int limit;
  final SortDirection sortDirection;
}

class HistoryItemQuery {
  const HistoryItemQuery({
    required this.threadId,
    required this.turnId,
    this.cursor,
    this.limit = 25,
    this.sortDirection = SortDirection.ascending,
  }) : assert(limit > 0 && limit <= 50);

  final String threadId;
  final String turnId;
  final String? cursor;
  final int limit;
  final SortDirection sortDirection;
}
