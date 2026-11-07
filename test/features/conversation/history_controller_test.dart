import 'package:codex_native_unofficial/src/domain/history_gateway.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
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

  test('reads one deferred item and replaces only the active item', () async {
    final gateway = _HistoryGateway(
      turnCount: 1,
      itemsPerTurn: 2,
      deferred: true,
    );
    final controller = HistoryController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.bindThread(_thread('thread-1'));
    await controller.loadTurnItems('turn-0');
    final deferred = controller.timelineItems.firstWhere(
      (item) => item.outputDeferred,
    );

    await controller.loadDeferredOutput(deferred);

    final loaded = controller.timelineItems.firstWhere(
      (item) => item.id == deferred.id,
    );
    expect(loaded.outputDeferred, isFalse);
    expect(loaded.output?.reference, 'output-ref');
    expect(gateway.readCalls, 1);
    expect(controller.timelineItems, hasLength(2));
  });

  test('tracks evicted item IDs and clears expanded turn when crossing >100-turn boundary', () async {
    final gateway = _HistoryGateway(turnCount: 140, itemsPerTurn: 3);
    final controller = HistoryController(
      gateway: gateway,
      turnPageSize: 20,
      itemPageSize: 3,
      maxRetainedTurns: 100,
      maxRetainedItems: 10,
    );
    addTearDown(controller.dispose);

    await controller.bindThread(_thread('thread-1'));
    await controller.loadTurnItems('turn-0');
    expect(controller.selectedTurnId, 'turn-0');
    expect(controller.evictionVersion, 0);
    expect(controller.lastEvictedItemIds, isEmpty);

    // Load pages 2..5 (turns 20..99): total 100 turns, no eviction yet.
    for (var page = 2; page <= 5; page += 1) {
      await controller.loadOlderTurns();
      expect(controller.evictionVersion, 0);
      expect(controller.lastEvictedItemIds, isEmpty);
      expect(controller.canReturnToNewest, isFalse);
    }
    expect(controller.turns, hasLength(100));

    // Load page 6 (turns 100..119): evicts turns 0..19 (including expanded turn-0).
    await controller.loadOlderTurns();
    expect(controller.turns, hasLength(100));
    expect(controller.turns.first.id, 'turn-20');
    expect(controller.turns.last.id, 'turn-119');
    expect(controller.evictionVersion, 1);
    expect(controller.canReturnToNewest, isTrue);
    expect(controller.selectedTurnId, isNull);
    // 19 summary turns (turn-1..turn-19) + 3 expanded items of turn-0 = 22 evicted items.
    expect(controller.lastEvictedItemIds, hasLength(22));
    expect(controller.lastEvictedItemIds, contains('item-0'));
    expect(controller.lastEvictedItemIds, contains('summary-19'));

    await controller.refresh();
    expect(controller.canReturnToNewest, isFalse);
    expect(controller.lastEvictedItemIds, isEmpty);
    expect(controller.turns.first.id, 'turn-0');
  });
}

class _HistoryGateway implements HistoryGateway {
  _HistoryGateway({
    required this.turnCount,
    required this.itemsPerTurn,
    this.deferred = false,
  });

  final int turnCount;
  final int itemsPerTurn;
  final bool deferred;
  var turnCalls = 0;
  var readCalls = 0;

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
            outputDeferred: deferred && index == 0,
          ),
      ],
      nextCursor: end < itemsPerTurn ? '$end' : null,
    );
  }

  @override
  Future<List<HistoryItem>> readHistoryItems({
    required String threadId,
    required String turnId,
    required List<String> itemIds,
  }) async {
    readCalls += 1;
    return [
      for (final itemId in itemIds)
        HistoryItem(
          id: itemId,
          turnId: turnId,
          kind: HistoryItemKind.activity,
          text: 'Read $itemId',
          output: const OutputDescriptor(
            reference: 'output-ref',
            bytes: 10,
            storedBytes: 10,
            truncated: false,
            available: true,
          ),
        ),
    ];
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
