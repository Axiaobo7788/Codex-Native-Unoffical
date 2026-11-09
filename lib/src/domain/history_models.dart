import 'output_models.dart';
import 'thread_models.dart';
import 'turn_models.dart';

export 'user_message_presentation.dart';

enum HistoryItemKind { user, assistant, activity, reasoning, review, unknown }

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.turnId,
    required this.kind,
    required this.text,
    this.status,
    this.output,
    this.outputDeferred = false,
    this.isCommand = false,
    this.attachments = const [],
  });

  final String id;
  final String turnId;
  final HistoryItemKind kind;
  final String text;
  final String? status;
  final OutputDescriptor? output;
  final bool outputDeferred;
  final bool isCommand;
  final List<UserAttachment> attachments;
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

  Duration? get workDuration {
    final start = startedAt;
    final end = completedAt;
    if (start == null || end == null || !end.isAfter(start)) {
      return null;
    }
    return end.difference(start);
  }

  String? get formattedWorkDuration {
    final duration = workDuration;
    if (duration == null) {
      return null;
    }
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) {
      return null;
    }
    if (totalSeconds < 60) {
      return 'Worked for ${totalSeconds}s';
    }
    final totalMinutes = duration.inMinutes;
    final seconds = totalSeconds % 60;
    if (totalMinutes < 60) {
      return seconds == 0
          ? 'Worked for ${totalMinutes}m'
          : 'Worked for ${totalMinutes}m ${seconds}s';
    }
    final hours = duration.inHours;
    final minutes = totalMinutes % 60;
    return minutes == 0
        ? 'Worked for ${hours}h'
        : 'Worked for ${hours}h ${minutes}m';
  }
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

class HistoryOccurrenceQuery {
  const HistoryOccurrenceQuery({
    required this.threadId,
    required this.searchTerm,
    this.cursor,
  });

  static const pageSize = 16;
  static const maxSearchTermLength = 256;

  final String threadId;
  final String searchTerm;
  final String? cursor;
}

class HistoryOccurrence {
  const HistoryOccurrence({
    required this.turnId,
    required this.itemId,
    required this.turnCursor,
    required this.snippet,
    required this.matchStart,
    required this.matchEnd,
  });

  final String turnId;
  final String itemId;
  final String turnCursor;
  final String snippet;
  // Offsets are UTF-16 code units, as in the stock schema and Dart strings.
  final int matchStart;
  final int matchEnd;
}

class HistoryOccurrencePage {
  const HistoryOccurrencePage({
    required this.occurrences,
    required this.nextCursor,
  });

  final List<HistoryOccurrence> occurrences;
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
