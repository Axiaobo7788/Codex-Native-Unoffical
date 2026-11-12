import 'dart:async';

import 'package:codex_native_unofficial/src/domain/history_gateway.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'old occurrence request cannot mark a replacement runtime unsupported',
    () async {
      final gateway = _OccurrenceHistoryGateway()
        ..pendingOccurrence = Completer<HistoryOccurrencePage>();
      final controller = HistoryController(gateway: gateway);
      addTearDown(controller.dispose);
      await controller.bindThread(_thread('same'));
      controller.searchOccurrences('old runtime');
      controller.invalidateRuntime();
      await controller.bindThread(_thread('same'), force: true);
      controller.searchOccurrences('fresh runtime');
      await Future<void>.delayed(Duration.zero);
      expect(gateway.occurrenceRequests, hasLength(2));
      expect(controller.occurrencePage, isNotNull);
      gateway.pendingOccurrence!.completeError(
        UnsupportedError('retired runtime'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.occurrenceUnsupported, isFalse);
      expect(controller.occurrencePage, isNotNull);
      expect(controller.occurrenceError, isNull);
    },
  );

  test(
    'runtime retirement drops old Host references but keeps bounded prose',
    () async {
      final gateway = _OutputHistoryGateway();
      final controller = HistoryController(gateway: gateway);
      addTearDown(controller.dispose);
      await controller.bindThread(_thread('same'));
      final before = controller.timelineItems.single;
      expect(before.output?.reference, 'old-host-only');
      controller.invalidateRuntime();
      final after = controller.timelineItems.single;
      expect(after.text, before.text);
      expect(after.output?.reference, isNull);
      expect(after.output?.available, isFalse);
      expect(after.output?.exitCode, 2);
      expect(controller.turns, hasLength(1));
    },
  );

  test(
    'defers only known unmaterialized history and hydrates when readable',
    () async {
      final gateway = _KnownEmptyHistoryGateway();
      final controller = HistoryController(gateway: gateway);
      addTearDown(controller.dispose);
      final thread = _thread('new');
      await controller.bindThread(thread, knownUnmaterialized: true);
      await controller.refresh();
      await controller.bindThread(thread, knownUnmaterialized: true);
      expect(gateway.turnCalls, 0);
      expect(controller.errorMessage, isNull);
      expect(controller.turns, isEmpty);
      expect(controller.supportsOccurrenceSearch, isFalse);

      await controller.bindThread(thread);
      await controller.bindThread(thread);
      expect(gateway.turnCalls, 1);
      expect(controller.turns, hasLength(1));
      expect(controller.supportsOccurrenceSearch, isTrue);
    },
  );

  test(
    'ordinary history failures remain visible instead of becoming empty',
    () async {
      final gateway = _KnownEmptyHistoryGateway()..failRead = true;
      final controller = HistoryController(gateway: gateway);
      addTearDown(controller.dispose);
      await controller.bindThread(_thread('ordinary'));
      expect(gateway.turnCalls, 1);
      expect(controller.errorMessage, contains('not materialized yet'));
    },
  );

  test(
    'saved MCP reads are single-flight and discard old turn results',
    () async {
      final gateway = _McpTextHistoryGateway();
      final controller = HistoryController(gateway: gateway);
      addTearDown(controller.dispose);
      await controller.bindThread(_thread('thread-1'));
      final item = gateway.item;
      expect(controller.canReadSavedMcpText(item), isFalse);
      expect(await controller.loadSavedMcpText(item), isNull);

      await controller.loadTurnItems(item.turnId);
      expect(controller.canReadSavedMcpText(item), isTrue);
      final first = controller.loadSavedMcpText(item);
      await expectLater(controller.loadSavedMcpText(item), throwsStateError);
      expect(gateway.readCalls, 1);

      controller.collapseTurnItems();
      await controller.bindThread(_thread('thread-2'));
      gateway.reply.complete(
        const SavedMcpTextResult('Old turn', truncated: false),
      );
      expect(await first, isNull);
      expect(controller.canReadSavedMcpText(item), isFalse);
    },
  );

  test(
    'an old scope does not show opening progress in another thread',
    () async {
      final gateway = _OccurrenceHistoryGateway();
      final controller = HistoryController(gateway: gateway);
      addTearDown(controller.dispose);
      await controller.bindThread(_thread('thread-1'));
      controller.searchOccurrences('Old');
      await Future<void>.delayed(Duration.zero);
      gateway.pendingAnchor = Completer<HistoryTurnPage>();
      final open = controller.openOccurrence(
        controller.occurrencePage!.occurrences.single,
      );
      expect(controller.openingOccurrence, isTrue);

      await controller.bindThread(_thread('thread-2'));
      controller.searchOccurrences('New');
      await Future<void>.delayed(Duration.zero);
      expect(controller.openingOccurrence, isFalse);
      expect(controller.canOpenOccurrence, isFalse);
      expect(controller.occurrencePage, isNotNull);
      gateway.pendingAnchor!.complete(gateway.anchorPage);
      expect(await open, isNull);
      expect(controller.canOpenOccurrence, isTrue);
      expect(controller.turns.first.id, 'turn-0');
    },
  );

  test(
    'opens a verified occurrence without retaining the previous window',
    () async {
      final gateway = _OccurrenceHistoryGateway();
      final controller = HistoryController(gateway: gateway);
      addTearDown(controller.dispose);
      await controller.bindThread(_thread('thread-1'));
      controller.searchOccurrences(' Old ');
      await Future<void>.delayed(Duration.zero);
      expect(gateway.occurrenceRequests.single.searchTerm, 'Old');
      final result = controller.occurrencePage!.occurrences.single;
      expect(controller.turns.first.id, 'turn-0');

      gateway.anchorFirstId = 'different-turn';
      expect(await controller.openOccurrence(result), isNull);
      expect(controller.turns.first.id, 'turn-0');
      expect(controller.canReturnToNewest, isFalse);
      expect(controller.occurrenceError, contains('no longer available'));

      gateway.anchorFirstId = 'turn-old';
      expect((await controller.openOccurrence(result))?.id, 'turn-old');
      expect(controller.turns.single.id, 'turn-old');
      expect(controller.canReturnToNewest, isTrue);
      await controller.refresh();
      expect(controller.turns.first.id, 'turn-0');
      expect(controller.canReturnToNewest, isFalse);
    },
  );

  test('a newer refresh supersedes an in-flight search anchor', () async {
    final gateway = _OccurrenceHistoryGateway();
    final controller = HistoryController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.bindThread(_thread('thread-1'));
    controller.searchOccurrences('Old');
    await Future<void>.delayed(Duration.zero);
    gateway.pendingAnchor = Completer<HistoryTurnPage>();
    final open = controller.openOccurrence(
      controller.occurrencePage!.occurrences.single,
    );

    await controller.refresh();
    gateway.pendingAnchor!.complete(gateway.anchorPage);
    expect(await open, isNull);
    expect(controller.turns.first.id, 'turn-0');
    expect(controller.canReturnToNewest, isFalse);
  });

  test(
    'search retains one running request and the latest pending scope',
    () async {
      final gateway = _OccurrenceHistoryGateway()
        ..pendingOccurrence = Completer<HistoryOccurrencePage>();
      final controller = HistoryController(gateway: gateway);
      addTearDown(controller.dispose);
      await controller.bindThread(_thread('thread-1'));
      controller.searchOccurrences('running');
      controller.searchOccurrences('discarded');
      await controller.bindThread(_thread('thread-2'));
      controller.searchOccurrences('latest');
      expect(gateway.occurrenceRequests.map((query) => query.searchTerm), [
        'running',
      ]);

      gateway.pendingOccurrence!.completeError(UnsupportedError('Old thread'));
      await Future<void>.delayed(Duration.zero);
      expect(
        gateway.occurrenceRequests.map(
          (query) => (query.threadId, query.searchTerm),
        ),
        [('thread-1', 'running'), ('thread-2', 'latest')],
      );
      expect(controller.occurrenceUnsupported, isFalse);
      expect(controller.occurrencePage!.occurrences.single.turnId, 'turn-old');

      controller.loadMoreOccurrences();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.occurrenceRequests.last.cursor, 'next-occurrence');
      expect(gateway.occurrenceRequests.last.searchTerm, 'latest');
      expect(controller.occurrencePage!.nextCursor, isNull);
    },
  );

  test('legacy fallback belongs to the selected thread only', () async {
    final gateway = _OccurrenceHistoryGateway()..unsupportedThread = 'thread-1';
    final controller = HistoryController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.bindThread(_thread('thread-1'));
    controller.searchOccurrences('Old');
    await Future<void>.delayed(Duration.zero);
    expect(controller.occurrenceUnsupported, isTrue);
    expect(controller.turns.first.id, 'turn-0');

    await controller.bindThread(_thread('thread-2'));
    controller.searchOccurrences('Old');
    await Future<void>.delayed(Duration.zero);
    expect(controller.occurrenceUnsupported, isFalse);
    expect(controller.occurrencePage, isNotNull);
  });

  test(
    'refresh releases an outstanding item load from the old window',
    () async {
      final gateway = _DelayedItemGateway();
      final controller = HistoryController(gateway: gateway);
      addTearDown(controller.dispose);
      await controller.bindThread(_thread('thread-1'));
      final load = controller.loadTurnItems('turn-0');
      expect(controller.loadingItems, isTrue);

      await controller.refresh();
      gateway.pending.complete(
        const HistoryItemPage(items: [], nextCursor: null),
      );
      await load;

      expect(controller.selectedTurnId, isNull);
      expect(controller.loadingItems, isFalse);
      await controller.loadTurnItems('turn-1');
      expect(controller.selectedTurnId, 'turn-1');
    },
  );

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

class _OccurrenceHistoryGateway extends _HistoryGateway
    implements HistoryOccurrenceGateway {
  _OccurrenceHistoryGateway() : super(turnCount: 3, itemsPerTurn: 2);

  final occurrenceRequests = <HistoryOccurrenceQuery>[];
  Completer<HistoryOccurrencePage>? pendingOccurrence;
  Completer<HistoryTurnPage>? pendingAnchor;
  String? unsupportedThread;
  String anchorFirstId = 'turn-old';

  @override
  bool get supportsHistoryOccurrences => true;

  HistoryTurnPage get anchorPage => HistoryTurnPage(
    turns: [
      HistoryTurn(
        id: anchorFirstId,
        status: TurnRuntimeStatus.completed,
        items: [
          HistoryItem(
            id: 'old-user',
            turnId: anchorFirstId,
            kind: HistoryItemKind.user,
            text: 'Old',
          ),
        ],
      ),
    ],
    nextCursor: null,
  );

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async =>
      query.cursor == 'turn-anchor'
      ? (pendingAnchor?.future ?? anchorPage)
      : super.listHistoryTurns(query);

  @override
  Future<HistoryOccurrencePage> listHistoryOccurrences(
    HistoryOccurrenceQuery query,
  ) async {
    occurrenceRequests.add(query);
    if (query.threadId == unsupportedThread) {
      throw UnsupportedError('Synthetic unsupported thread');
    }
    if (pendingOccurrence case final pending?
        when occurrenceRequests.length == 1) {
      return pending.future;
    }
    return HistoryOccurrencePage(
      occurrences: const [
        HistoryOccurrence(
          turnId: 'turn-old',
          itemId: 'old-user',
          turnCursor: 'turn-anchor',
          snippet: 'Old',
          matchStart: 0,
          matchEnd: 3,
        ),
      ],
      nextCursor: query.cursor == null ? 'next-occurrence' : null,
    );
  }
}

class _DelayedItemGateway extends _HistoryGateway {
  _DelayedItemGateway() : super(turnCount: 3, itemsPerTurn: 2);

  final pending = Completer<HistoryItemPage>();
  var calls = 0;

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) {
    return calls++ == 0 ? pending.future : super.listHistoryItems(query);
  }
}

class _McpTextHistoryGateway extends _HistoryGateway
    implements HistoryMcpTextGateway {
  _McpTextHistoryGateway() : super(turnCount: 1, itemsPerTurn: 1);

  final reply = Completer<SavedMcpTextResult?>();
  final item = const HistoryItem(
    id: 'mcp',
    turnId: 'turn-0',
    kind: HistoryItemKind.activity,
    text: 'MCP: fixture/tool',
    status: 'completed',
    canReadMcpText: true,
  );

  @override
  bool get supportsSavedMcpText => true;

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async =>
      HistoryItemPage(items: [item], nextCursor: null);

  @override
  Future<SavedMcpTextResult?> readSavedMcpText({
    required String threadId,
    required String turnId,
    required String itemId,
  }) {
    expect((threadId, turnId, itemId), ('thread-1', 'turn-0', 'mcp'));
    readCalls += 1;
    return reply.future;
  }
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

class _KnownEmptyHistoryGateway extends _HistoryGateway
    implements HistoryOccurrenceGateway {
  _KnownEmptyHistoryGateway() : super(turnCount: 1, itemsPerTurn: 1);
  var failRead = false;
  @override
  bool get supportsHistoryOccurrences => true;
  @override
  Future<HistoryOccurrencePage> listHistoryOccurrences(
    HistoryOccurrenceQuery query,
  ) async => const HistoryOccurrencePage(occurrences: [], nextCursor: null);
  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) {
    if (failRead) {
      turnCalls++;
      throw StateError(
        'not materialized yet: ordinary read failure must stay visible',
      );
    }
    return super.listHistoryTurns(query);
  }
}

class _OutputHistoryGateway extends _HistoryGateway {
  _OutputHistoryGateway() : super(turnCount: 1, itemsPerTurn: 1);
  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async =>
      const HistoryTurnPage(
        turns: [
          HistoryTurn(
            id: 'one',
            status: TurnRuntimeStatus.completed,
            items: [
              HistoryItem(
                id: 'one-command',
                turnId: 'one',
                kind: HistoryItemKind.activity,
                text: 'Last known bounded command',
                isCommand: true,
                output: OutputDescriptor(
                  reference: 'old-host-only',
                  bytes: 12,
                  storedBytes: 12,
                  truncated: false,
                  available: true,
                  exitCode: 2,
                ),
              ),
            ],
          ),
        ],
        nextCursor: null,
      );
}
