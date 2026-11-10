import 'dart:async';

import 'package:codex_native_unofficial/src/domain/thread_gateway.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/features/threads/thread_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a newer catalog receipt supersedes a pending write response', () async {
    const seen = ThreadReadReceipt(revision: 'seen', unread: true);
    const newer = ThreadReadReceipt(
      revision: 'catalog-after-write',
      unread: true,
    );
    final gateway = _ReadReceiptGateway()..serverReceipt = seen;
    final row = _thread('saved').copyWith(readReceipt: seen);
    gateway.pages.add(ThreadPage(threads: [row], nextCursor: null));
    final controller = ThreadListController(gateway: gateway);
    addTearDown(gateway.dispose);
    addTearDown(controller.dispose);
    await controller.refresh();

    gateway.pendingPage = Completer<ThreadPage>();
    gateway.pendingWrite = Completer<ThreadReadReceipt>();
    final refresh = controller.refresh();
    final write = controller.toggleReadReceipt('saved', seen);
    gateway.pendingPage!.complete(
      ThreadPage(threads: [row.copyWith(readReceipt: newer)], nextCursor: null),
    );
    await refresh;
    gateway.pendingWrite!.complete(
      const ThreadReadReceipt(revision: 'write-result', unread: false),
    );
    await write;

    expect(
      controller.threads.single.readReceipt?.revision,
      'catalog-after-write',
    );
    expect(controller.threads.single.readReceipt?.unread, isTrue);
  });

  test('stale receipt writes refresh state and require a new action', () async {
    const seen = ThreadReadReceipt(revision: 'seen', unread: true);
    const newer = ThreadReadReceipt(revision: 'newer', unread: true);
    final gateway = _ReadReceiptGateway()..serverReceipt = newer;
    gateway.pages.add(
      ThreadPage(
        threads: [_thread('saved').copyWith(readReceipt: seen)],
        nextCursor: null,
      ),
    );
    final controller = ThreadListController(gateway: gateway);
    addTearDown(gateway.dispose);
    addTearDown(controller.dispose);
    await controller.refresh();

    await controller.toggleReadReceipt('saved', seen);
    expect(gateway.writes, [('saved', 'seen', false)]);
    expect(gateway.readIds, ['saved']);
    expect(controller.threads.single.readReceipt?.revision, 'newer');
    expect(controller.threads.single.readReceipt?.unread, isTrue);
    expect(controller.errorMessage, contains('Read status changed'));

    await controller.toggleReadReceipt('saved', newer);
    expect(gateway.writes, [
      ('saved', 'seen', false),
      ('saved', 'newer', false),
    ]);
    expect(controller.threads.single.readReceipt?.unread, isFalse);
    expect(controller.errorMessage, isNull);
    expect(gateway.resumeIds, isEmpty);
  });

  test(
    'late catalog and receipt-less resume cannot erase a newer event',
    () async {
      const original = ThreadReadReceipt(revision: 'before', unread: false);
      const latest = ThreadReadReceipt(revision: 'after', unread: true);
      final gateway = _ReadReceiptGateway();
      final row = _thread('saved').copyWith(readReceipt: original);
      gateway.pages.add(ThreadPage(threads: [row], nextCursor: null));
      final controller = ThreadListController(gateway: gateway);
      addTearDown(gateway.dispose);
      addTearDown(controller.dispose);
      await controller.refresh();
      gateway.pendingPage = Completer<ThreadPage>();
      final refresh = controller.refresh(preserveSelection: true);
      gateway.events.add(
        const ThreadReadReceiptChangedEvent(threadId: 'saved', receipt: latest),
      );
      gateway.events.add(
        const ThreadReadReceiptChangedEvent(
          threadId: 'unknown',
          receipt: latest,
        ),
      );
      gateway.pendingPage!.complete(
        ThreadPage(threads: [row], nextCursor: null),
      );
      await refresh;

      expect(controller.threads.single.readReceipt?.revision, 'after');
      expect(controller.threads.single.readReceipt?.unread, isTrue);
      await controller.resumeThread('saved');
      expect(controller.selectedThread?.readReceipt?.revision, 'after');
      expect(gateway.writes, isEmpty);
    },
  );

  test('a newer receipt notice supersedes a pending write response', () async {
    const seen = ThreadReadReceipt(revision: 'seen', unread: true);
    const notice = ThreadReadReceipt(revision: 'after', unread: true);
    final gateway = _ReadReceiptGateway()..serverReceipt = seen;
    gateway.pages.add(
      ThreadPage(
        threads: [_thread('saved').copyWith(readReceipt: seen)],
        nextCursor: null,
      ),
    );
    final controller = ThreadListController(gateway: gateway);
    addTearDown(gateway.dispose);
    addTearDown(controller.dispose);
    await controller.refresh();
    gateway.pendingWrite = Completer<ThreadReadReceipt>();

    final write = controller.toggleReadReceipt('saved', seen);
    gateway.events.add(
      const ThreadReadReceiptChangedEvent(threadId: 'saved', receipt: notice),
    );
    gateway.pendingWrite!.complete(
      const ThreadReadReceipt(revision: 'write-result', unread: false),
    );
    await write;

    expect(controller.threads.single.readReceipt?.revision, 'after');
    expect(controller.threads.single.readReceipt?.unread, isTrue);
  });

  test(
    'searches saved threads with the existing page and selection bounds',
    () async {
      final gateway = _FakeThreadGateway()
        ..pages.addAll([
          ThreadPage(threads: [_thread('recent')], nextCursor: 'catalog'),
          ThreadPage(
            threads: [_thread('saved-1'), _thread('saved-2')],
            nextCursor: 'saved',
          ),
          ThreadPage(threads: [_thread('saved-3')], nextCursor: 'remaining'),
          ThreadPage(threads: [_thread('saved-2')], nextCursor: null),
          ThreadPage(threads: [_thread('newer')], nextCursor: null),
          const ThreadPage(threads: [], nextCursor: null),
          const ThreadPage(threads: [], nextCursor: null),
        ]);
      final controller = ThreadListController(
        gateway: gateway,
        pageSize: 2,
        maxRetainedThreads: 3,
      );
      addTearDown(gateway.dispose);
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.selectThread('recent');

      await controller.setSavedSearch('  Cobalt  ');
      expect(gateway.queries.last.searchTerm, 'Cobalt');
      expect(gateway.queries.last.cursor, isNull);
      expect(gateway.queries.last.section, isNull);
      expect(controller.selectedThread?.id, 'recent');
      expect(controller.threads.map((row) => row.id), ['saved-1', 'saved-2']);

      await controller.loadMore();
      expect(gateway.queries.last.searchTerm, 'Cobalt');
      expect(gateway.queries.last.cursor, 'saved');
      expect(gateway.queries.last.limit, 1);
      expect(controller.threads.map((row) => row.id), [
        'saved-1',
        'saved-2',
        'saved-3',
      ]);
      expect(controller.retentionLimitReached, isTrue);

      gateway.events.add(
        const ThreadNameUpdatedEvent(
          threadId: 'saved-1',
          threadName: 'Changed elsewhere',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(gateway.queries.last.searchTerm, 'Cobalt');
      expect(gateway.queries.last.cursor, isNull);
      expect(controller.threads.map((row) => row.id), ['saved-2']);

      await controller.setSavedSearch(null);
      expect(gateway.queries.last.searchTerm, isNull);
      expect(gateway.queries.last.cursor, isNull);
      expect(controller.selectedThread?.id, 'recent');
      expect(controller.threads.map((row) => row.id), ['newer']);

      await controller.setShowArchived(true);
      await controller.setSavedSearch('Historical');
      expect(gateway.queries.last.archived, isTrue);
      expect(gateway.queries.last.searchTerm, 'Historical');
    },
  );

  test('closing saved search discards a pending result page', () async {
    final gateway = _DelayedCatalogGateway()
      ..pages.addAll([
        ThreadPage(threads: [_thread('selected')], nextCursor: null),
        ThreadPage(threads: [_thread('match')], nextCursor: 'stale'),
        ThreadPage(threads: [_thread('restored')], nextCursor: null),
      ]);
    final controller = ThreadListController(gateway: gateway);
    addTearDown(gateway.dispose);
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.selectThread('selected');
    await controller.setSavedSearch('Needle');
    final paging = controller.loadMore();
    await controller.setSavedSearch(null);
    expect(controller.savedSearchTerm, isNull);
    expect(controller.canLoadMore, isFalse);
    expect(controller.threads, isEmpty);
    expect(controller.selectedThread?.id, 'selected');

    gateway.pageReply.complete(
      ThreadPage(threads: [_thread('stale-row')], nextCursor: 'stale-next'),
    );
    await paging;
    await Future<void>.delayed(Duration.zero);

    expect(gateway.queries.last.searchTerm, isNull);
    expect(gateway.queries.last.cursor, isNull);
    expect(controller.threads.map((row) => row.id), ['restored']);
    expect(controller.selectedThread?.id, 'selected');
  });

  test(
    'opens one ordered section, preserves the active thread, and caps pages',
    () async {
      const section = ThreadSection(id: 'queue', name: 'Queue');
      final gateway = _FakeThreadGateway()
        ..sections.add(section)
        ..pages.addAll([
          ThreadPage(threads: [_thread('outside')], nextCursor: 'global-page'),
          ThreadPage(
            threads: [
              _thread('b', section: section),
              _thread('a', section: section),
            ],
            nextCursor: 'scoped-page',
          ),
          ThreadPage(
            threads: [_thread('c', section: section)],
            nextCursor: 'unretained-page',
          ),
          ThreadPage(
            threads: [_thread('global-first')],
            nextCursor: 'global-next',
          ),
          ThreadPage(threads: [_thread('global-second')], nextCursor: null),
        ]);
      final controller = ThreadListController(
        gateway: gateway,
        pageSize: 2,
        maxRetainedThreads: 3,
      );
      addTearDown(controller.dispose);
      addTearDown(gateway.dispose);
      await controller.refresh();
      await controller.selectThread('outside');
      await controller.setSectionScope('queue');
      expect(controller.selectedThread?.id, 'outside');
      expect(controller.threads.map((thread) => thread.id), ['b', 'a']);
      expect(gateway.queries.last.section?.id, 'queue');
      expect(gateway.queries.last.sortKey, ThreadSortKey.sectionPosition);
      expect(gateway.queries.last.sortDirection, SortDirection.ascending);

      await controller.loadMore();
      expect(gateway.queries.last.cursor, 'scoped-page');
      expect(gateway.queries.last.limit, 1);
      expect(controller.threads.map((thread) => thread.id), ['b', 'a', 'c']);
      expect(controller.retentionLimitReached, isTrue);

      await controller.setSectionScope(null);
      expect(gateway.queries.last.section, isNull);
      expect(gateway.queries.last.cursor, isNull);
      expect(controller.selectedThread?.id, 'outside');
      expect(controller.threads.map((thread) => thread.id), ['global-first']);
      await controller.loadMore();
      expect(controller.selectedThread?.id, 'outside');
      expect(controller.threads.map((thread) => thread.id), [
        'global-first',
        'global-second',
      ]);
    },
  );

  test(
    'a section event discards an in-flight page and reloads from the start',
    () async {
      const section = ThreadSection(id: 'queue', name: 'Queue');
      final gateway = _DelayedCatalogGateway()
        ..sections.add(section)
        ..pages.addAll([
          const ThreadPage(threads: [], nextCursor: null),
          ThreadPage(
            threads: [_thread('old', section: section)],
            nextCursor: 'stale',
          ),
          ThreadPage(
            threads: [_thread('reordered', section: section)],
            nextCursor: null,
          ),
        ]);
      final controller = ThreadListController(gateway: gateway);
      addTearDown(controller.dispose);
      addTearDown(gateway.dispose);
      await controller.refresh();
      await controller.setSectionScope('queue');
      final paging = controller.loadMore();
      gateway.events.add(
        const ThreadSectionChangedEvent(
          threadId: 'reordered',
          sectionId: 'queue',
        ),
      );
      expect(controller.canLoadMore, isFalse);
      gateway.pageReply.complete(
        ThreadPage(
          threads: [_thread('stale-page-row', section: section)],
          nextCursor: 'more',
        ),
      );
      await paging;
      await Future<void>.delayed(Duration.zero);
      expect(controller.threads.map((thread) => thread.id), ['reordered']);
      expect(gateway.queries.map((query) => query.cursor), [
        null,
        null,
        'stale',
        null,
      ]);
      expect(gateway.queries.last.section?.id, 'queue');
    },
  );

  test('a read revealing a move refreshes the scoped catalog', () async {
    const section = ThreadSection(id: 'queue', name: 'Queue');
    final gateway = _FakeThreadGateway()
      ..sections.add(section)
      ..pages.addAll([
        const ThreadPage(threads: [], nextCursor: null),
        ThreadPage(
          threads: [_thread('moved', section: section)],
          nextCursor: 'old-order',
        ),
        const ThreadPage(threads: [], nextCursor: null),
      ]);
    final controller = ThreadListController(gateway: gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.dispose);
    await controller.refresh();
    await controller.setSectionScope('queue');

    final moved = await controller.selectThread('moved');
    await Future<void>.delayed(Duration.zero);
    expect(moved?.section, isNull);
    expect(controller.selectedThread?.id, 'moved');
    expect(controller.threads, isEmpty);
    expect(gateway.queries.last.section?.id, 'queue');
    expect(gateway.queries.last.cursor, isNull);
  });

  test('keeps only the active draft outside the scoped catalog', () async {
    const section = ThreadSection(id: 'queue', name: 'Queue');
    final gateway = _DraftSectionGateway(section)
      ..sections.add(section)
      ..pages.addAll([
        const ThreadPage(threads: [], nextCursor: null),
        ThreadPage(
          threads: [_thread('row', section: section)],
          nextCursor: null,
        ),
      ]);
    final controller = ThreadListController(gateway: gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.dispose);
    await controller.refresh();
    await controller.setSectionScope('queue');

    final first = await controller.startThread(
      const ThreadStartOptions(cwd: '/tmp'),
    );
    expect(controller.isMaterialized(first!.id), isFalse);
    final second = await controller.startThread(
      const ThreadStartOptions(cwd: '/tmp'),
    );
    expect(controller.selectedThread?.id, second!.id);
    expect(controller.isMaterialized(second.id), isFalse);
    expect(controller.isMaterialized(first.id), isTrue);
    expect(controller.threads.map((thread) => thread.id), ['row']);

    await controller.selectThread('row');
    expect(controller.selectedThread?.id, 'row');
    expect(controller.isMaterialized(second.id), isTrue);
  });

  test(
    'keeps goal events that arrive while a direct read is in flight',
    () async {
      final gateway = _GoalReadGateway()
        ..pages.add(ThreadPage(threads: [_thread('goal')], nextCursor: null));
      final controller = ThreadListController(gateway: gateway);
      addTearDown(controller.dispose);
      addTearDown(gateway.dispose);
      await controller.refresh();

      final load = controller.loadGoal('goal');
      const newer = ThreadGoal(
        objective: 'Newer notification',
        status: ThreadGoalStatus.paused,
        createdAtSeconds: 1,
        updatedAtSeconds: 2,
        tokensUsed: 0,
        timeUsedSeconds: 0,
      );
      gateway.events.add(
        const ThreadGoalUpdatedEvent(threadId: 'goal', goal: newer),
      );
      gateway.goalReplies['goal']!.complete(null);
      expect((await load)?.goal, same(newer));
      expect(controller.goalForThread('goal'), same(newer));
    },
  );

  test('paginates metadata without exceeding its retention bound', () async {
    final gateway = _FakeThreadGateway()
      ..pages.addAll([
        ThreadPage(threads: [_thread('1'), _thread('2')], nextCursor: 'page-2'),
        ThreadPage(threads: [_thread('3'), _thread('4')], nextCursor: 'page-3'),
      ]);
    final controller = ThreadListController(
      gateway: gateway,
      pageSize: 2,
      maxRetainedThreads: 3,
    );
    addTearDown(controller.dispose);
    addTearDown(gateway.dispose);

    await controller.refresh();
    await controller.loadMore();

    expect(controller.threads.map((thread) => thread.id), ['1', '2', '3']);
    expect(gateway.queries[1].cursor, 'page-2');
    expect(gateway.queries[1].limit, 1);
    expect(controller.canLoadMore, isFalse);
    expect(controller.retentionLimitReached, isTrue);
  });

  test(
    'hydrates only the latest selected goal while a read is pending',
    () async {
      final gateway = _GoalReadGateway()
        ..pages.add(
          ThreadPage(
            threads: [_thread('first'), _thread('skipped'), _thread('last')],
            nextCursor: null,
          ),
        );
      final controller = ThreadListController(gateway: gateway);
      addTearDown(controller.dispose);
      addTearDown(gateway.dispose);
      await controller.refresh();
      await controller.selectThread('first');
      await controller.selectThread('skipped');
      await controller.selectThread('last');
      expect(gateway.goalReplies.keys, ['first']);
      const goal = ThreadGoal(
        objective: 'Read only when selected',
        status: ThreadGoalStatus.paused,
        createdAtSeconds: 1,
        updatedAtSeconds: 2,
        tokensUsed: 0,
        timeUsedSeconds: 0,
      );
      gateway.goalReplies['first']!.complete(goal);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.goalReplies.keys, ['first', 'last']);
      expect(controller.goalForThread('first'), isNull);
      gateway.goalReplies['last']!.complete(goal);
      await Future<void>.delayed(Duration.zero);
      expect(controller.selectedThread?.goal, same(goal));
    },
  );

  test('start, read, and resume update the bounded projection', () async {
    final gateway = _FakeThreadGateway()
      ..pages.add(
        ThreadPage(threads: [_thread('1'), _thread('2')], nextCursor: null),
      );
    final controller = ThreadListController(
      gateway: gateway,
      pageSize: 2,
      maxRetainedThreads: 2,
    );
    addTearDown(controller.dispose);
    addTearDown(gateway.dispose);

    await controller.refresh();
    await controller.startThread(const ThreadStartOptions(cwd: '/new-project'));
    expect(controller.threads.map((thread) => thread.id), ['new', '1']);
    expect(controller.selectedThread?.id, 'new');

    await controller.selectThread('new');
    expect(gateway.readIds, isEmpty);

    await controller.selectThread('1');
    expect(gateway.readIds, ['1']);
    expect(controller.selectedThread?.name, 'Read metadata');

    await controller.resumeThread('1');
    expect(gateway.resumeIds, ['1']);
    expect(controller.selectedThread?.status, ThreadRuntimeStatus.idle);
  });

  test(
    'resume outcome distinguishes loaded, failed, and skipped attempts',
    () async {
      final gateway = _FakeThreadGateway()
        ..pages.add(
          ThreadPage(threads: [_thread('1'), _thread('2')], nextCursor: null),
        );
      final controller = ThreadListController(gateway: gateway);
      addTearDown(controller.dispose);
      addTearDown(gateway.dispose);

      await controller.refresh();
      await controller.selectThread('1');

      final wrongSelection = await controller
          .ensureSelectedThreadLoadedWithOutcome('2');
      expect(wrongSelection.status, ThreadResumeStatus.skipped);
      expect(gateway.resumeIds, isEmpty);

      gateway.resumeError = StateError('JSON-RPC error -32600: no rollout');
      final failed = await controller.ensureSelectedThreadLoadedWithOutcome(
        '1',
      );
      expect(failed.status, ThreadResumeStatus.failed);
      expect(failed.errorMessage, contains('no rollout'));
      expect(controller.errorMessage, contains('no rollout'));
      expect(controller.selectedThread?.status, ThreadRuntimeStatus.notLoaded);

      gateway.resumeError = null;
      final loaded = await controller.ensureSelectedThreadLoadedWithOutcome(
        '1',
      );
      expect(loaded.status, ThreadResumeStatus.loaded);
      expect(loaded.thread?.status, ThreadRuntimeStatus.idle);
      expect(controller.errorMessage, isNull);

      final alreadyLoaded = await controller
          .ensureSelectedThreadLoadedWithOutcome('1');
      expect(alreadyLoaded.status, ThreadResumeStatus.loaded);
      expect(gateway.resumeIds, ['1', '1']);
    },
  );

  test(
    'refresh deduplicates duplicate thread IDs and tops up initial page',
    () async {
      final gateway = _FakeThreadGateway()
        ..pages.addAll([
          ThreadPage(
            threads: [_thread('1'), _thread('1'), _thread('2'), _thread('1')],
            nextCursor: 'cursor-2',
          ),
          ThreadPage(
            threads: [_thread('2'), _thread('3'), _thread('4')],
            nextCursor: null,
          ),
        ]);
      final controller = ThreadListController(
        gateway: gateway,
        pageSize: 4,
        maxRetainedThreads: 10,
      );
      addTearDown(controller.dispose);
      addTearDown(gateway.dispose);

      await controller.refresh();

      expect(controller.threads.map((thread) => thread.id), [
        '1',
        '2',
        '3',
        '4',
      ]);
      expect(gateway.queries, hasLength(2));
      expect(gateway.queries[0].cursor, isNull);
      expect(gateway.queries[1].cursor, 'cursor-2');
      expect(controller.canLoadMore, isFalse);
    },
  );

  test(
    'rename, archive, unarchive, fork, revert, and compact update projection',
    () async {
      final gateway = _FakeThreadGateway()
        ..pages.addAll([
          ThreadPage(threads: [_thread('1'), _thread('2')], nextCursor: null),
          ThreadPage(threads: [_thread('1')], nextCursor: null),
        ]);
      final controller = ThreadListController(
        gateway: gateway,
        pageSize: 5,
        maxRetainedThreads: 10,
      );
      addTearDown(controller.dispose);
      addTearDown(gateway.dispose);

      await controller.refresh();
      await controller.selectThread('1');

      final renamed = await controller.renameThread('1', '  Custom Title  ');
      expect(renamed, isTrue);
      expect(gateway.renamedThreads, [('1', 'Custom Title')]);
      expect(controller.selectedThread?.displayTitle, 'Custom Title');
      expect(controller.threads.first.displayTitle, 'Custom Title');

      final compacted = await controller.compactThread('1');
      expect(compacted, isTrue);
      expect(gateway.compactedIds, ['1']);

      final archived = await controller.archiveThread('1');
      expect(archived, isTrue);
      expect(gateway.archivedIds, ['1']);
      expect(controller.threads.map((t) => t.id), ['2']);
      expect(controller.selectedThread?.id, '2');

      await controller.setShowArchived(true);
      expect(controller.showArchived, isTrue);
      expect(gateway.queries.last.archived, isTrue);
      expect(controller.threads.map((t) => t.id), ['1']);

      final unarchived = await controller.unarchiveThread('1');
      expect(unarchived?.id, '1');
      expect(gateway.unarchivedIds, ['1']);
      expect(controller.threads, isEmpty);

      final forked = await controller.forkThread(
        const ThreadForkOptions(threadId: '2', beforeTurnId: 'turn-1'),
      );
      expect(forked?.id, 'fork-2');
      expect(controller.showArchived, isFalse);
      expect(controller.selectedThread?.id, 'fork-2');

      final reverted = await controller.revertThread(
        threadId: 'fork-2',
        beforeTurnId: 'turn-1',
      );
      expect(reverted?.id, 'fork-2');
      expect(gateway.revertedThreads, [('fork-2', 'turn-1')]);
    },
  );

  test('bounds pinnedThreadIds to maxPinnedThreads (32)', () {
    final gateway = _FakeThreadGateway();
    final controller = ThreadListController(gateway: gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.dispose);

    for (var i = 0; i < ThreadListController.maxPinnedThreads + 5; i++) {
      controller.togglePinThread('t-$i');
    }

    expect(
      controller.pinnedThreadIds.length,
      ThreadListController.maxPinnedThreads,
    );
    expect(controller.isPinned('t-0'), isFalse);
    expect(controller.isPinned('t-4'), isFalse);
    expect(controller.isPinned('t-5'), isTrue);
    expect(
      controller.isPinned('t-${ThreadListController.maxPinnedThreads + 4}'),
      isTrue,
    );

    controller.togglePinThread('t-5');
    expect(controller.isPinned('t-5'), isFalse);
  });

  test('applies live ThreadLifecycleEvents to retained threads', () async {
    final gateway = _FakeThreadGateway()
      ..pages.add(
        ThreadPage(threads: [_thread('1'), _thread('2')], nextCursor: null),
      );
    final controller = ThreadListController(gateway: gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.dispose);

    await controller.refresh();
    await controller.selectThread('1');

    gateway.events.add(
      const ThreadNameUpdatedEvent(
        threadId: '1',
        threadName: 'Server Generated Title',
      ),
    );
    expect(controller.selectedThread?.displayTitle, 'Server Generated Title');

    gateway.events.add(
      const ThreadStatusChangedEvent(
        threadId: '1',
        status: ThreadRuntimeStatus.active,
      ),
    );
    expect(controller.selectedThread?.status, ThreadRuntimeStatus.active);

    gateway.events.add(
      const ThreadGoalUpdatedEvent(
        threadId: '1',
        turnId: 'turn-1',
        goal: ThreadGoal(
          objective: 'Converge the supported thread surface',
          status: ThreadGoalStatus.active,
          createdAtSeconds: 100,
          updatedAtSeconds: 120,
          tokensUsed: 42,
          timeUsedSeconds: 20,
          tokenBudget: 500,
        ),
      ),
    );
    expect(
      controller.selectedThread?.goal?.objective,
      'Converge the supported thread surface',
    );
    expect(controller.threads.first.goal?.tokensUsed, 42);

    await controller.resumeThread('1');
    expect(
      controller.selectedThread?.goal?.objective,
      'Converge the supported thread surface',
    );

    gateway.events.add(const ThreadGoalClearedEvent(threadId: '1'));
    expect(controller.selectedThread?.goal, isNull);
    expect(controller.threads.first.goal, isNull);

    gateway.events.add(const ThreadArchivedEvent(threadId: '1'));
    expect(controller.threads.map((t) => t.id), ['2']);
    expect(controller.selectedThread?.id, '2');

    gateway.events.add(
      const ThreadRevertedEvent(threadId: '2', turnsBackwardsCursor: 'turn-1'),
    );
    expect(controller.lastRevertedThreadId, '2');
    expect(controller.revertVersion, 1);

    final deleted = await controller.deleteThread('2');
    expect(deleted, isTrue);
    expect(gateway.deletedIds, ['2']);
    expect(controller.threads, isEmpty);
    expect(controller.selectedThread, isNull);
  });

  test('guards fork and compact on unmaterialized threads until status transitions', () async {
    final gateway = _FakeThreadGateway();
    final controller = ThreadListController(gateway: gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.dispose);

    final created = await controller.startThread(
      const ThreadStartOptions(cwd: '/workspace'),
    );
    expect(created?.id, 'new');
    expect(controller.isMaterialized('new'), isFalse);

    expect(
      await controller.forkThread(const ThreadForkOptions(threadId: 'new')),
      isNull,
    );
    expect(controller.errorMessage, contains('Start at least one turn'));

    expect(await controller.compactThread('new'), isFalse);
    expect(controller.errorMessage, contains('Start at least one turn'));

    gateway.events.add(
      const ThreadStatusChangedEvent(
        threadId: 'new',
        status: ThreadRuntimeStatus.active,
      ),
    );
    expect(controller.isMaterialized('new'), isTrue);

    final forked = await controller.forkThread(
      const ThreadForkOptions(threadId: 'new'),
    );
    expect(forked?.id, 'fork-new');
  });

  test('loads, creates, renames, deletes, and moves thread sections and reacts to section/changed events', () async {
    final gateway = _FakeThreadGateway();
    gateway.sections.add(const ThreadSection(id: 'sec-1', name: 'Priority'));
    gateway.pages.add(
      ThreadPage(
        threads: [
          _thread(
            't-1',
            status: ThreadRuntimeStatus.idle,
            section: const ThreadSection(id: 'sec-1', name: 'Priority'),
            sectionEnteredAtSeconds: 1700000010,
          ),
          _thread('t-2', status: ThreadRuntimeStatus.idle),
        ],
        nextCursor: null,
      ),
    );

    final controller = ThreadListController(gateway: gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.dispose);

    await controller.refresh();
    expect(controller.supportsThreadSections, isTrue);
    expect(controller.sections.map((s) => s.id), ['sec-1']);
    expect(controller.threads.first.section?.id, 'sec-1');

    final created = await controller.createSection('Backlog');
    expect(created?.id, 'sec-2');
    expect(controller.sections.map((s) => s.name), ['Priority', 'Backlog']);

    final renamed = await controller.renameSection('sec-1', 'Urgent');
    expect(renamed?.name, 'Urgent');
    expect(controller.sections.first.name, 'Urgent');
    expect(controller.threads.first.section?.name, 'Urgent');

    final moved = await controller.moveThreadToSection(
      threadId: 't-2',
      sectionId: 'sec-2',
      beforeThreadId: 't-1',
    );
    expect(moved, isTrue);
    expect(gateway.movedSections.single.threadId, 't-2');
    expect(gateway.movedSections.single.sectionId, 'sec-2');
    expect(gateway.movedSections.single.beforeThreadId, 't-1');
    ThreadSummary threadById(String id) =>
        controller.threads.firstWhere((t) => t.id == id);
    expect(threadById('t-2').section?.id, 'sec-2');

    // Live notification for unknown section does not fabricate a raw-ID section name,
    // and resolves authoritatively once background section reload completes.
    gateway.sections.add(
      const ThreadSection(id: 'sec-remote', name: 'Synced Section'),
    );
    gateway.events.add(
      const ThreadSectionChangedEvent(threadId: 't-2', sectionId: 'sec-remote'),
    );
    expect(controller.sections.where((s) => s.name == 'sec-remote'), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(threadById('t-2').section?.id, 'sec-remote');
    expect(threadById('t-2').section?.name, 'Synced Section');

    // Live notification clearing section
    gateway.events.add(
      const ThreadSectionChangedEvent(threadId: 't-2', sectionId: null),
    );
    expect(threadById('t-2').section, isNull);
    expect(threadById('t-2').sectionEnteredAtSeconds, isNull);

    final deleted = await controller.deleteSection('sec-1');
    expect(deleted, isTrue);
    expect(controller.sections.map((s) => s.id), isNot(contains('sec-1')));
    expect(threadById('t-1').section, isNull);
  });

  test('protects built-in Pinned by ID, persists unsectioned pins, preserves custom-section session pins, and reconciles stock/local pin transitions', () async {
    const builtInPinned = ThreadSection(
      id: kBuiltInPinnedThreadSectionId,
      name: 'Pinned',
    );
    const customPinned = ThreadSection(id: 'sec-custom-pinned', name: 'Pinned');
    const customWork = ThreadSection(id: 'sec-work', name: 'Work');

    final gateway = _FakeThreadGateway();
    gateway.sections.addAll([builtInPinned, customPinned, customWork]);
    gateway.pages.add(
      ThreadPage(
        threads: [
          _thread('t-plain', status: ThreadRuntimeStatus.idle),
          _thread(
            't-work',
            status: ThreadRuntimeStatus.idle,
            section: customWork,
          ),
          _thread(
            't-custom-pinned',
            status: ThreadRuntimeStatus.idle,
            section: customPinned,
          ),
        ],
        nextCursor: null,
      ),
    );

    final controller = ThreadListController(gateway: gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.dispose);

    // Local session pin before stock refresh observes built-in Pinned membership
    await controller.togglePinThread('t-prepinned');
    expect(controller.pinnedThreadIds, contains('t-prepinned'));

    gateway.pages.first = ThreadPage(
      threads: [
        ...gateway.pages.first.threads,
        _thread(
          't-prepinned',
          status: ThreadRuntimeStatus.idle,
          section: builtInPinned,
        ),
      ],
      nextCursor: null,
    );

    await controller.refresh();

    // 1. Local pin + newly observed stock membership reconciles out of pinnedThreadIds
    expect(controller.isPinned('t-prepinned'), isTrue);
    expect(controller.isPersistedPinned('t-prepinned'), isTrue);
    expect(controller.isSessionPinned('t-prepinned'), isFalse);
    expect(controller.pinnedThreadIds, isNot(contains('t-prepinned')));

    // 2. Built-in Pinned cannot be renamed or deleted, while custom section named Pinned can
    expect(
      await controller.renameSection(kBuiltInPinnedThreadSectionId, 'Saved'),
      isNull,
    );
    expect(
      controller.errorMessage,
      'The built-in Pinned section cannot be renamed.',
    );
    expect(
      await controller.deleteSection(kBuiltInPinnedThreadSectionId),
      isFalse,
    );
    expect(
      controller.errorMessage,
      'The built-in Pinned section cannot be deleted.',
    );
    expect(gateway.updatedSections, isEmpty);
    expect(gateway.deletedSectionIds, isEmpty);

    final renamedCustom = await controller.renameSection(
      'sec-custom-pinned',
      'Team Pinned',
    );
    expect(renamedCustom?.name, 'Team Pinned');
    expect(await controller.deleteSection('sec-custom-pinned'), isTrue);

    // 3. Unsectioned materialized thread persists to built-in Pinned on togglePinThread
    expect(controller.canPersistPin('t-plain'), isTrue);
    expect(await controller.togglePinThread('t-plain'), isTrue);
    expect(gateway.movedSections.last.threadId, 't-plain');
    expect(gateway.movedSections.last.sectionId, kBuiltInPinnedThreadSectionId);
    expect(controller.isPersistedPinned('t-plain'), isTrue);
    expect(controller.isSessionPinned('t-plain'), isFalse);

    // 4. Custom-section thread keeps session-only quick pin without losing section
    expect(controller.canPersistPin('t-work'), isFalse);
    expect(await controller.togglePinThread('t-work'), isTrue);
    expect(gateway.movedSections, hasLength(1));
    expect(controller.isPinned('t-work'), isTrue);
    expect(controller.isSessionPinned('t-work'), isTrue);
    expect(controller.isPersistedPinned('t-work'), isFalse);
    expect(
      controller.threads.firstWhere((t) => t.id == 't-work').section?.id,
      'sec-work',
    );

    // Explicit move from custom section to built-in Pinned promotes session pin to saved
    expect(
      await controller.moveThreadToSection(
        threadId: 't-work',
        sectionId: kBuiltInPinnedThreadSectionId,
      ),
      isTrue,
    );
    expect(controller.isPersistedPinned('t-work'), isTrue);
    expect(controller.isSessionPinned('t-work'), isFalse);
    expect(controller.pinnedThreadIds, isNot(contains('t-work')));

    // 5. Stock unpin clears any retained local pin and unpins cleanly
    expect(await controller.togglePinThread('t-plain'), isTrue);
    expect(gateway.movedSections.last.threadId, 't-plain');
    expect(gateway.movedSections.last.sectionId, isNull);
    expect(controller.isPinned('t-plain'), isFalse);

    // External stock unpin notification also leaves thread unpinned
    gateway.events.add(
      const ThreadSectionChangedEvent(threadId: 't-prepinned', sectionId: null),
    );
    expect(controller.isPinned('t-prepinned'), isFalse);
    expect(controller.pinnedThreadIds, isNot(contains('t-prepinned')));

    // 6. Stale cached unsectioned state re-reads before saved pin and refuses to overwrite a custom section
    gateway.readSectionOverrides['t-plain'] = customWork;
    final movesBeforeStalePin = gateway.movedSections.length;
    expect(await controller.togglePinThread('t-plain'), isFalse);
    expect(gateway.movedSections, hasLength(movesBeforeStalePin));
    expect(
      controller.threads.firstWhere((t) => t.id == 't-plain').section?.id,
      'sec-work',
    );
    expect(
      controller.errorMessage,
      contains('Thread is now in section "Work"'),
    );

    // 7. Stale cached saved-Pinned state re-reads before saved unpin and refuses to clear a custom section
    gateway.readSectionOverrides['t-work'] = customWork;
    final movesBeforeStaleUnpin = gateway.movedSections.length;
    expect(await controller.togglePinThread('t-work'), isFalse);
    expect(gateway.movedSections, hasLength(movesBeforeStaleUnpin));
    expect(
      controller.threads.firstWhere((t) => t.id == 't-work').section?.id,
      'sec-work',
    );
    expect(
      controller.errorMessage,
      contains('Thread is now in section "Work"'),
    );

    // 8. Mismatched readThread ID fails closed before any move or projection overwrite
    gateway.readSectionOverrides.remove('t-custom-pinned');
    await controller.moveThreadToSection(
      threadId: 't-custom-pinned',
      sectionId: null,
    );
    gateway.readIdOverrides['t-custom-pinned'] = 't-wrong';
    final movesBeforeMismatch = gateway.movedSections.length;
    expect(await controller.togglePinThread('t-custom-pinned'), isFalse);
    expect(gateway.movedSections, hasLength(movesBeforeMismatch));
    expect(
      controller.errorMessage,
      'Thread read returned a mismatched thread identifier.',
    );
    expect(controller.threads.any((t) => t.id == 't-wrong'), isFalse);
  });

  test('capped section retention preserves active scoped custom section when built-in Pinned arrives and uses session wording when built-in is absent', () async {
    final gateway = _FakeThreadGateway();
    for (var i = 0; i < ThreadListController.maxRetainedSections; i++) {
      gateway.sections.add(ThreadSection(id: 'sec-$i', name: 'Section $i'));
    }
    final scopedSection = gateway.sections.last;
    final tScoped = _thread(
      't-scoped',
      status: ThreadRuntimeStatus.idle,
      section: scopedSection,
    );
    gateway.pages.addAll([
      ThreadPage(threads: [tScoped], nextCursor: null),
      ThreadPage(threads: [tScoped], nextCursor: null),
    ]);

    final controller = ThreadListController(gateway: gateway);
    addTearDown(controller.dispose);
    addTearDown(gateway.dispose);

    await controller.refresh();
    expect(controller.builtInPinnedSection, isNull);
    expect(
      controller.pinActionLabelForThread(controller.threads.single),
      'Pin for session',
    );
    await controller.togglePinThread('t-scoped');
    expect(
      controller.pinActionLabelForThread(controller.threads.single),
      'Unpin session pin',
    );

    await controller.setSectionScope(scopedSection.id);
    expect(controller.sectionScopeId, scopedSection.id);

    // Observe built-in Pinned while at the 64-section cap and scoped to sec-63
    gateway.pages.add(ThreadPage(threads: [tScoped], nextCursor: null));
    gateway.events.add(
      const ThreadSectionChangedEvent(
        threadId: 't-other',
        sectionId: kBuiltInPinnedThreadSectionId,
      ),
    );
    expect(controller.builtInPinnedSection?.id, kBuiltInPinnedThreadSectionId);
    expect(controller.scopedSection?.id, scopedSection.id);
  });
}

class _DraftSectionGateway extends _FakeThreadGateway {
  _DraftSectionGateway(this.section);

  final ThreadSection section;
  var _draft = 0;

  @override
  Future<ThreadSummary> readThread(String threadId) async =>
      _thread(threadId, section: section);

  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) async =>
      _thread(
        'draft-${++_draft}',
        cwd: options.cwd,
        status: ThreadRuntimeStatus.notLoaded,
      );
}

class _DelayedCatalogGateway extends _FakeThreadGateway {
  final pageReply = Completer<ThreadPage>();

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) {
    if (query.cursor == 'stale') {
      queries.add(query);
      return pageReply.future;
    }
    return super.listThreads(query);
  }
}

class _GoalReadGateway extends _FakeThreadGateway implements ThreadGoalGateway {
  final goalReplies = <String, Completer<ThreadGoal?>>{};

  @override
  bool get supportsThreadGoals => true;

  @override
  Future<ThreadGoal?> readThreadGoal(String threadId) =>
      (goalReplies[threadId] = Completer<ThreadGoal?>()).future;

  @override
  Future<ThreadGoal> setThreadGoal(
    String threadId, {
    String? objective,
    ThreadGoalStatus? status,
  }) => throw UnimplementedError();

  @override
  Future<bool> clearThreadGoal(String threadId) => throw UnimplementedError();
}

class _ReadReceiptGateway extends _FakeThreadGateway
    implements ThreadReadReceiptGateway {
  ThreadReadReceipt? serverReceipt;
  Completer<ThreadPage>? pendingPage;
  Completer<ThreadReadReceipt>? pendingWrite;
  final writes = <(String, String, bool)>[];

  @override
  bool get supportsThreadReadReceiptWrites => true;

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) =>
      pendingPage?.future ?? super.listThreads(query);

  @override
  Future<ThreadSummary> readThread(String threadId) async =>
      (await super.readThread(threadId)).copyWith(readReceipt: serverReceipt);

  @override
  Future<ThreadReadReceipt> setThreadReadReceipt({
    required String threadId,
    required String expectedRevision,
    required bool unread,
  }) async {
    writes.add((threadId, expectedRevision, unread));
    if (serverReceipt?.revision != expectedRevision) {
      throw StateError('Synthetic stale receipt');
    }
    if (pendingWrite case final pending?) {
      return pending.future;
    }
    return serverReceipt = ThreadReadReceipt(
      revision: 'new-write',
      unread: unread,
    );
  }
}

class _FakeThreadGateway implements ThreadGateway, ThreadSectionGateway {
  final StreamController<ThreadLifecycleEvent> events =
      StreamController<ThreadLifecycleEvent>.broadcast(sync: true);
  final List<ThreadPage> pages = [];
  final List<ThreadListQuery> queries = [];
  final List<String> readIds = [];
  final List<String> resumeIds = [];
  final List<(String, String)> renamedThreads = [];
  final List<String> archivedIds = [];
  final List<String> unarchivedIds = [];
  final List<ThreadForkOptions> forkedOptions = [];
  final List<(String, String)> revertedThreads = [];
  final List<String> compactedIds = [];
  final List<String> deletedIds = [];
  final List<ThreadSection> sections = [];
  final List<ThreadSectionCreateOptions> createdSections = [];
  final List<ThreadSectionUpdateOptions> updatedSections = [];
  final List<String> deletedSectionIds = [];
  final List<ThreadSectionMoveOptions> movedSections = [];
  final Map<String, ThreadSection?> readSectionOverrides = {};
  final Map<String, String> readIdOverrides = {};
  bool sectionSupport = true;
  Object? resumeError;

  @override
  bool get supportsThreadSections => sectionSupport;

  @override
  Future<ThreadSectionPage> listThreadSections([
    ThreadSectionListQuery query = const ThreadSectionListQuery(),
  ]) async {
    return ThreadSectionPage(
      sections: List.unmodifiable(sections),
      nextCursor: null,
    );
  }

  @override
  Future<ThreadSection> createThreadSection(
    ThreadSectionCreateOptions options,
  ) async {
    createdSections.add(options);
    final created = ThreadSection(
      id: 'sec-${sections.length + 1}',
      name: options.name,
      appearance: options.appearance,
    );
    sections.add(created);
    return created;
  }

  @override
  Future<ThreadSection> updateThreadSection(
    ThreadSectionUpdateOptions options,
  ) async {
    updatedSections.add(options);
    final idx = sections.indexWhere((s) => s.id == options.sectionId);
    final updated = ThreadSection(
      id: options.sectionId,
      name: options.name,
      appearance: options.clearAppearance
          ? null
          : (options.appearance ??
                (idx != -1 ? sections[idx].appearance : null)),
    );
    if (idx != -1) {
      sections[idx] = updated;
    } else {
      sections.add(updated);
    }
    return updated;
  }

  @override
  Future<void> deleteThreadSection(String sectionId) async {
    deletedSectionIds.add(sectionId);
    sections.removeWhere((s) => s.id == sectionId);
  }

  @override
  Future<void> moveThreadSection(ThreadSectionMoveOptions options) async {
    movedSections.add(options);
    final sectionId = options.sectionId;
    readSectionOverrides[options.threadId] = sectionId == null
        ? null
        : sections.firstWhere(
            (s) => s.id == sectionId,
            orElse: () => ThreadSection(id: sectionId, name: sectionId),
          );
  }

  @override
  Stream<ThreadLifecycleEvent> get threadEvents => events.stream;

  @override
  Future<void> deleteThread(String threadId) async {
    deletedIds.add(threadId);
  }

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) async {
    queries.add(query);
    return pages.removeAt(0);
  }

  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) async =>
      _thread('new', cwd: options.cwd, status: ThreadRuntimeStatus.notLoaded);

  @override
  Future<ThreadSummary> readThread(String threadId) async {
    readIds.add(threadId);
    return _thread(
      readIdOverrides[threadId] ?? threadId,
      name: 'Read metadata',
      section: readSectionOverrides[threadId],
    );
  }

  @override
  Future<ThreadSummary> resumeThread(String threadId) async {
    resumeIds.add(threadId);
    if (resumeError case final error?) {
      throw error;
    }
    return _thread(threadId, status: ThreadRuntimeStatus.idle);
  }

  @override
  Future<void> renameThread({
    required String threadId,
    required String name,
  }) async {
    renamedThreads.add((threadId, name));
  }

  @override
  Future<void> archiveThread(String threadId) async {
    archivedIds.add(threadId);
  }

  @override
  Future<ThreadSummary> unarchiveThread(String threadId) async {
    unarchivedIds.add(threadId);
    return _thread(threadId, status: ThreadRuntimeStatus.idle);
  }

  @override
  Future<ThreadSummary> forkThread(ThreadForkOptions options) async {
    forkedOptions.add(options);
    return _thread(
      'fork-${options.threadId}',
      cwd: options.cwd ?? '/workspace',
      status: ThreadRuntimeStatus.idle,
    );
  }

  @override
  Future<ThreadSummary> revertThread({
    required String threadId,
    required String beforeTurnId,
  }) async {
    revertedThreads.add((threadId, beforeTurnId));
    return _thread(threadId, status: ThreadRuntimeStatus.idle);
  }

  @override
  Future<void> compactThread(String threadId) async {
    compactedIds.add(threadId);
  }

  Future<void> dispose() => events.close();
}

ThreadSummary _thread(
  String id, {
  String cwd = '/workspace',
  String? name,
  ThreadRuntimeStatus status = ThreadRuntimeStatus.notLoaded,
  ThreadSection? section,
  int? sectionEnteredAtSeconds,
}) => ThreadSummary(
  id: id,
  sessionId: 'session-$id',
  preview: 'Thread $id',
  cwd: cwd,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 1, 2),
  status: status,
  ephemeral: false,
  name: name,
  section: section,
  sectionEnteredAtSeconds: sectionEnteredAtSeconds,
);
