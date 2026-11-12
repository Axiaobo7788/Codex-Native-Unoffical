import 'history_models.dart';
import 'file_change_models.dart';

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

/// Optional whole-item read from a local stock runtime.
abstract interface class HistoryMcpTextGateway {
  bool get supportsSavedMcpText;
  Future<SavedMcpTextResult?> readSavedMcpText({
    required String threadId,
    required String turnId,
    required String itemId,
  });
}

/// Optional local, explicit per-file read. Stock may require a whole-item
/// fallback; the result and retained UI state remain independently bounded.
abstract interface class HistoryFileChangeGateway {
  bool get supportsFileChangePreviews;
  Future<FileChangePreview?> readFileChangePreview({
    required String threadId,
    required String turnId,
    required String itemId,
    required FileChangeEntry file,
  });
}
