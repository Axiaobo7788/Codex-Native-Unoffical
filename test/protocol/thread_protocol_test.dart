import 'dart:async';

import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/thread_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<_Request> requests;
  late Map<String, JsonObject> responses;
  late StreamController<CodexNotification> notifications;
  late ThreadProtocolAdapter adapter;

  setUp(() {
    requests = [];
    responses = {};
    notifications = StreamController<CodexNotification>.broadcast(sync: true);
    adapter = ThreadProtocolAdapter(
      request: (method, [params = const {}]) async {
        requests.add(_Request(method, params));
        return responses[method] ?? const {};
      },
      notifications: notifications.stream,
    );
  });

  tearDown(() async {
    await notifications.close();
  });

  test('lists a bounded metadata page with an opaque cursor', () async {
    responses['thread/list'] = {
      'data': [_threadJson(id: 'thread-1')],
      'nextCursor': 'next-page',
      'backwardsCursor': null,
      'readStates': null,
    };

    final page = await adapter.listThreads(
      const ThreadListQuery(cursor: 'current', limit: 12),
    );

    expect(requests.single.method, 'thread/list');
    expect(requests.single.params, {
      'cursor': 'current',
      'limit': 12,
      'sortKey': 'recency_at',
      'sortDirection': 'desc',
      'archived': false,
    });
    expect(page.nextCursor, 'next-page');
    expect(page.threads.single.id, 'thread-1');
    expect(page.threads.single.cwd, '/workspace');
    expect(page.threads.single.status, ThreadRuntimeStatus.idle);
    expect(page.threads.single.displayTitle, 'First task');
  });

  test(
    'bounds git metadata and removes URL credentials and query data',
    () async {
      responses['thread/list'] = {
        'data': [
          {
            ..._threadJson(id: 'thread-git'),
            'gitInfo': {
              'branch': 'b' * 600,
              'originUrl': 'https://user:secret@example.test/owner/repo.git?token=secret#fragment',
              'sha': 'a' * 200,
            },
          },
        ],
        'nextCursor': null,
      };

      final page = await adapter.listThreads(const ThreadListQuery());
      final gitInfo = page.threads.single.gitInfo!;

      expect(gitInfo.branch, hasLength(513));
      expect(gitInfo.branch, endsWith('…'));
      expect(gitInfo.sha, hasLength(129));
      expect(gitInfo.sha, endsWith('…'));
      expect(gitInfo.originUrl, 'https://example.test/owner/repo.git');
    },
  );

  test('drops malformed credential-bearing git origins', () async {
    responses['thread/list'] = {
      'data': [
        {
          ..._threadJson(id: 'thread-git-malformed'),
          'gitInfo': {
            'branch': 'main',
            'originUrl': 'https://user:secret@',
            'sha': 'abc123',
          },
        },
      ],
      'nextCursor': null,
    };

    final page = await adapter.listThreads(const ThreadListQuery());

    expect(page.threads.single.gitInfo?.originUrl, isNull);
  });

  test(
    'passes archived filter and trimmed searchTerm in thread/list',
    () async {
      responses['thread/list'] = {
        'data': [_threadJson(id: 'archived-1')],
        'nextCursor': null,
      };

      await adapter.listThreads(
        const ThreadListQuery(
          limit: 10,
          archived: true,
          searchTerm: '  migration  ',
        ),
      );

      expect(requests.single.method, 'thread/list');
      expect(requests.single.params, {
        'limit': 10,
        'sortKey': 'recency_at',
        'sortDirection': 'desc',
        'archived': true,
        'searchTerm': 'migration',
      });
    },
  );

  test('never requests full turns for read or resume', () async {
    responses['thread/read'] = {'thread': _threadJson(id: 'thread-2')};
    responses['thread/resume'] = {'thread': _threadJson(id: 'thread-2')};

    await adapter.readThread('thread-2');
    await adapter.resumeThread('thread-2');

    expect(
      requests[0],
      _Request('thread/read', {'threadId': 'thread-2', 'includeTurns': false}),
    );
    expect(
      requests[1],
      _Request('thread/resume', {'threadId': 'thread-2', 'excludeTurns': true}),
    );
  });

  test('starts only with presentation-owned options', () async {
    responses['thread/start'] = {'thread': _threadJson(id: 'thread-3')};

    await adapter.startThread(
      const ThreadStartOptions(cwd: '/workspace/project', ephemeral: true),
    );

    expect(
      requests.single,
      _Request('thread/start', {
        'cwd': '/workspace/project',
        'ephemeral': true,
      }),
    );
    expect(requests.single.params, isNot(contains('baseInstructions')));
    expect(requests.single.params, isNot(contains('developerInstructions')));
  });

  test('serializes explicit approval and sandbox overrides', () async {
    responses['thread/start'] = {'thread': _threadJson(id: 'thread-4')};

    await adapter.startThread(
      const ThreadStartOptions(
        cwd: '/workspace/project',
        model: 'model-wire-name',
        approvalPolicy: ApprovalPolicyOverride.untrusted,
        sandbox: SandboxModeOverride.readOnly,
      ),
    );

    expect(
      requests.single,
      _Request('thread/start', {
        'cwd': '/workspace/project',
        'ephemeral': false,
        'model': 'model-wire-name',
        'approvalPolicy': 'untrusted',
        'sandbox': 'read-only',
      }),
    );
  });

  test(
    'renames, archives, unarchives, forks, reverts, and compacts threads',
    () async {
      responses['thread/name/set'] = const {};
      responses['thread/archive'] = const {};
      responses['thread/unarchive'] = {'thread': _threadJson(id: 'thread-5')};
      responses['thread/fork'] = {'thread': _threadJson(id: 'thread-fork-5')};
      responses['thread/revert'] = {'thread': _threadJson(id: 'thread-5')};
      responses['thread/compact/start'] = const {};

      await adapter.renameThread(threadId: 'thread-5', name: 'Renamed task');
      await adapter.archiveThread('thread-5');
      final unarchived = await adapter.unarchiveThread('thread-5');
      final forked = await adapter.forkThread(
        const ThreadForkOptions(
          threadId: 'thread-5',
          beforeTurnId: 'turn-3',
          cwd: '/workspace/fork',
        ),
      );
      final reverted = await adapter.revertThread(
        threadId: 'thread-5',
        beforeTurnId: 'turn-2',
      );
      await adapter.compactThread('thread-5');

      expect(unarchived.id, 'thread-5');
      expect(forked.id, 'thread-fork-5');
      expect(reverted.id, 'thread-5');
      expect(requests, [
        _Request('thread/name/set', {
          'threadId': 'thread-5',
          'name': 'Renamed task',
        }),
        _Request('thread/archive', {'threadId': 'thread-5'}),
        _Request('thread/unarchive', {'threadId': 'thread-5'}),
        _Request('thread/fork', {
          'threadId': 'thread-5',
          'excludeTurns': true,
          'ephemeral': false,
          'beforeTurnId': 'turn-3',
          'cwd': '/workspace/fork',
        }),
        _Request('thread/revert', {
          'threadId': 'thread-5',
          'beforeTurnId': 'turn-2',
        }),
        _Request('thread/compact/start', {'threadId': 'thread-5'}),
      ]);
    },
  );

  test('parses thread lifecycle notifications into typed events', () async {
    final received = <ThreadLifecycleEvent>[];
    final sub = adapter.events.listen(received.add);
    addTearDown(sub.cancel);

    notifications.add(
      const CodexNotification(
        method: 'thread/name/updated',
        params: {'threadId': 't-1', 'threadName': 'Updated Name'},
      ),
    );
    notifications.add(
      const CodexNotification(
        method: 'thread/archived',
        params: {'threadId': 't-1'},
      ),
    );
    notifications.add(
      const CodexNotification(
        method: 'thread/unarchived',
        params: {'threadId': 't-1'},
      ),
    );
    notifications.add(
      const CodexNotification(
        method: 'thread/reverted',
        params: {'threadId': 't-1', 'turnsBackwardsCursor': 'cur-1'},
      ),
    );
    notifications.add(
      const CodexNotification(
        method: 'thread/status/changed',
        params: {
          'threadId': 't-1',
          'status': {'type': 'active'},
        },
      ),
    );
    notifications.add(
      const CodexNotification(
        method: 'thread/goal/updated',
        params: {
          'threadId': 't-1',
          'turnId': 'turn-1',
          'goal': {
            'threadId': 't-1',
            'objective': 'Ship the supported projection',
            'status': 'active',
            'createdAt': 100,
            'updatedAt': 120,
            'tokensUsed': 42,
            'timeUsedSeconds': 20,
            'tokenBudget': 500,
          },
        },
      ),
    );
    notifications.add(
      const CodexNotification(
        method: 'thread/goal/cleared',
        params: {'threadId': 't-1'},
      ),
    );

    expect(received, hasLength(7));
    expect(
      received[0],
      isA<ThreadNameUpdatedEvent>()
          .having((e) => e.threadId, 'threadId', 't-1')
          .having((e) => e.threadName, 'threadName', 'Updated Name'),
    );
    expect(
      received[1],
      isA<ThreadArchivedEvent>().having((e) => e.threadId, 'threadId', 't-1'),
    );
    expect(
      received[2],
      isA<ThreadUnarchivedEvent>().having((e) => e.threadId, 'threadId', 't-1'),
    );
    expect(
      received[3],
      isA<ThreadRevertedEvent>()
          .having((e) => e.threadId, 'threadId', 't-1')
          .having(
            (e) => e.turnsBackwardsCursor,
            'turnsBackwardsCursor',
            'cur-1',
          ),
    );
    expect(
      received[4],
      isA<ThreadStatusChangedEvent>()
          .having((e) => e.threadId, 'threadId', 't-1')
          .having((e) => e.status, 'status', ThreadRuntimeStatus.active),
    );
    expect(
      received[5],
      isA<ThreadGoalUpdatedEvent>()
          .having((e) => e.threadId, 'threadId', 't-1')
          .having((e) => e.turnId, 'turnId', 'turn-1')
          .having(
            (e) => e.goal.objective,
            'objective',
            'Ship the supported projection',
          )
          .having((e) => e.goal.status, 'status', ThreadGoalStatus.active)
          .having((e) => e.goal.tokenBudget, 'tokenBudget', 500),
    );
    expect(received[6], isA<ThreadGoalClearedEvent>());
  });

  test('bounds goal objectives at parser ingress', () async {
    final received = <ThreadLifecycleEvent>[];
    final sub = adapter.events.listen(received.add);
    addTearDown(sub.cancel);

    notifications.add(
      CodexNotification(
        method: 'thread/goal/updated',
        params: {
          'threadId': 't-1',
          'goal': {
            'threadId': 't-1',
            'objective': 'x' * 4096,
            'status': 'paused',
            'createdAt': 100,
            'updatedAt': 120,
            'tokensUsed': 42,
            'timeUsedSeconds': 20,
            'tokenBudget': null,
          },
        },
      ),
    );

    final event = received.single as ThreadGoalUpdatedEvent;
    expect(event.goal.objective, hasLength(2049));
    expect(event.goal.objective, endsWith('…'));
    expect(event.goal.status, ThreadGoalStatus.paused);
  });

  test('rejects a goal routed to a different thread', () async {
    final error = expectLater(
      adapter.events,
      emitsError(isA<ProtocolViolation>()),
    );

    notifications.add(
      const CodexNotification(
        method: 'thread/goal/updated',
        params: {
          'threadId': 't-1',
          'goal': {
            'threadId': 't-2',
            'objective': 'Wrong target',
            'status': 'active',
            'createdAt': 100,
            'updatedAt': 120,
            'tokensUsed': 42,
            'timeUsedSeconds': 20,
            'tokenBudget': null,
          },
        },
      ),
    );

    await error;
  });

  test('deletes only the explicitly identified thread', () async {
    responses['thread/delete'] = const {};

    await adapter.deleteThread('smoke-owned-thread');

    expect(
      requests.single,
      _Request('thread/delete', {'threadId': 'smoke-owned-thread'}),
    );
  });

  test('rejects malformed metadata instead of leaking raw JSON', () async {
    responses['thread/list'] = {
      'data': [
        {'id': 'incomplete'},
      ],
      'nextCursor': null,
    };

    await expectLater(
      adapter.listThreads(const ThreadListQuery()),
      throwsA(isA<ProtocolViolation>()),
    );
  });
}

JsonObject _threadJson({required String id}) => {
  'id': id,
  'sessionId': 'session-$id',
  'preview': 'First task\nMore detail',
  'cwd': '/workspace',
  'createdAt': 1730000000,
  'updatedAt': 1730000100,
  'status': {'type': 'idle'},
  'ephemeral': false,
  'name': null,
  'model': 'gpt-test',
  'projectId': null,
  'turns': <Object?>[],
};

class _Request {
  const _Request(this.method, this.params);

  final String method;
  final JsonObject params;

  @override
  bool operator ==(Object other) =>
      other is _Request &&
      other.method == method &&
      _mapsEqual(other.params, params);

  @override
  int get hashCode => Object.hash(method, params.length);

  @override
  String toString() => '$method $params';
}

bool _mapsEqual(JsonObject left, JsonObject right) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
