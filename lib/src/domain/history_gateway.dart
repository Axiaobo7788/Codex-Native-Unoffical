import 'history_models.dart';

abstract interface class HistoryGateway {
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query);
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query);
  Future<List<HistoryItem>> readHistoryItems({
    required String threadId,
    required String turnId,
    required List<String> itemIds,
  });
}

/// Optional local stock operation. A particular saved thread can be unsupported.
abstract interface class HistoryOccurrenceGateway {
  bool get supportsHistoryOccurrences;
  Future<HistoryOccurrencePage> listHistoryOccurrences(
    HistoryOccurrenceQuery query,
  );
}
