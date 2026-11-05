import 'history_models.dart';

abstract interface class HistoryGateway {
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query);
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query);
}
