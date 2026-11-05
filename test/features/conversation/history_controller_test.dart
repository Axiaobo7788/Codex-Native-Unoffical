import 'package:codex_native_unofficial/src/domain/history_gateway.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('caps a synthetic 1000-turn history at the working-set limit', () async {
    final gateway = _HistoryGateway(turnCount: 1000, itemsPerTurn: 200);
    final controller = HistoryController(
      gateway: gateway,
      turnPageSize: 20,
      itemPageSize: 25,
      maxRetainedTurns: 100,
      maxRetainedItems: 50,
    );
    addTearDown(controller.dispose);

    await controller.bindThread(_thread('thread-1'));
    while (controller.canLoadOlderTurns) {
      await controller.loadOlderTurns();
    }

    expect(controller.turns, hasLength(100));
    expect(controller.timelineItems, hasLength(100));
    expect(controller.turns.first.id, 'turn-900');
    expect(gateway.turnCalls, 50);
    expect(controller.canLoadOlderTurns, isFalse);
    expect(controller.canReturnToNewest, isTrue);

    await controller.refresh();
    expect(controller.turns.first.id, 'turn-0');
    expect(controller.canReturnToNewest, isFalse);

    await controller.loadTurnItems(controller.turns.first.id);
    expect(
      controller.timelineItems.where(
        (item) => item.turnId == controller.selectedTurnId,
      ),
      hasLength(25),
    );
    expect(controller.timelineItems.length, lessThanOrEqualTo(100));
    await controller.loadMoreItems();
    expect(
      controller.timelineItems.where(
        (item) => item.turnId == controller.selectedTurnId,
      ),
      hasLength(50),
    );
    expect(controller.canLoadMoreItems, isFalse);
  });

  test('evicts all inactive-thread history on selection change', () async {
    final controller = HistoryController(
      gateway: _HistoryGateway(turnCount: 5, itemsPerTurn: 2),
    );
    addTearDown(controller.dispose);
    await controller.bindThread(_thread('thread-1'));
    expect(controller.turns, isNotEmpty);

    await controller.bindThread(null);

    expect(controller.turns, isEmpty);
    expect(controller.timelineItems, isEmpty);
    expect(controller.selectedTurnId, isNull);
  });
}

class _HistoryGateway implements HistoryGateway {
  _HistoryGateway({required this.turnCount, required this.itemsPerTurn});

  final int turnCount;
  final int itemsPerTurn;
  var turnCalls = 0;

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async {
    turnCalls += 1;
    final start = query.cursor == null ? 0 : int.parse(query.cursor!);
    final end = (start + query.limit).clamp(0, turnCount);
    return HistoryTurnPage(
      turns: [
        for (var index = start; index < end; index += 1)
          HistoryTurn(
            id: 'turn-$index',
            status: TurnRuntimeStatus.completed,
            items: [
              HistoryItem(
                id: 'summary-$index',
                turnId: 'turn-$index',
                kind: HistoryItemKind.assistant,
                text: 'Summary $index',
              ),
            ],
          ),
      ],
      nextCursor: end < turnCount ? '$end' : null,
    );
  }

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async {
    final start = query.cursor == null ? 0 : int.parse(query.cursor!);
    final end = (start + query.limit).clamp(0, itemsPerTurn);
    return HistoryItemPage(
      items: [
        for (var index = start; index < end; index += 1)
          HistoryItem(
            id: 'item-$index',
            turnId: query.turnId,
            kind: HistoryItemKind.activity,
            text: 'Item $index',
          ),
      ],
      nextCursor: end < itemsPerTurn ? '$end' : null,
    );
  }
}

ThreadSummary _thread(String id) => ThreadSummary(
  id: id,
  sessionId: 'session-$id',
  preview: 'Thread $id',
  cwd: '/workspace',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  status: ThreadRuntimeStatus.idle,
  ephemeral: false,
);
