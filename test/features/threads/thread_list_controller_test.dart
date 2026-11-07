import 'package:codex_native_unofficial/src/domain/thread_gateway.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/features/threads/thread_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    await controller.refresh();
    await controller.loadMore();

    expect(controller.threads.map((thread) => thread.id), ['1', '2', '3']);
    expect(gateway.queries[1].cursor, 'page-2');
    expect(gateway.queries[1].limit, 1);
    expect(controller.canLoadMore, isFalse);
    expect(controller.retentionLimitReached, isTrue);
  });

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
}

class _FakeThreadGateway implements ThreadGateway {
  final List<ThreadPage> pages = [];
  final List<ThreadListQuery> queries = [];
  final List<String> readIds = [];
  final List<String> resumeIds = [];

  @override
  Future<void> deleteThread(String threadId) async {}

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
}

ThreadSummary _thread(
  String id, {
  String cwd = '/workspace',
  String? name,
  ThreadRuntimeStatus status = ThreadRuntimeStatus.notLoaded,
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
);
