import 'dart:async';

import 'package:codex_native_unofficial/src/domain/thread_gateway.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/features/threads/thread_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  bool sectionSupport = true;

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
    return _thread(threadId, name: 'Read metadata');
  }

  @override
  Future<ThreadSummary> resumeThread(String threadId) async {
    resumeIds.add(threadId);
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
