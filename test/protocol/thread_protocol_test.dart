import 'dart:async';

import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
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

  test(
    'an unload invalidates cached settings before an active auto-load',
    () async {
      final subscription = adapter.events.listen((_) {});
      try {
        responses['thread/resume'] = {
          'thread': _threadJson(id: 'unloaded'),
          ..._executionSettingsJson(model: 'retired-model'),
        };
        await adapter.resumeThread('unloaded');
        for (final type in ['notLoaded', 'active']) {
          notifications.add(
            CodexNotification(
              method: 'thread/status/changed',
              params: {
                'threadId': 'unloaded',
                'status': {'type': type},
              },
            ),
          );
        }
        responses['thread/read'] = {'thread': _threadJson(id: 'unloaded')};
        expect(
          (await adapter.readThread('unloaded')).executionSettings?.model,
          isNull,
        );
      } finally {
        await subscription.cancel();
      }
    },
  );

  test(
    'evicting an in-flight newer snapshot cannot resurrect an older reply',
    () async {
      final reply = Completer<JsonObject>();
      final raced = ThreadProtocolAdapter(
        request: (_, [params = const {}]) => reply.future,
        notifications: notifications.stream,
      );
      final subscription = raced.events.listen((_) {});
      try {
        final pending = raced.startThread(
          const ThreadStartOptions(cwd: '/workspace'),
        );
        for (var i = 0; i <= 100; i += 1) {
          notifications.add(
            CodexNotification(
              method: 'thread/settings/updated',
              params: {
                'threadId': i == 0 ? 'raced' : 'other-$i',
                'threadSettings': {
                  ..._executionSettingsJson(model: 'newer-model'),
                  'sandboxPolicy': {'type': 'readOnly'},
                },
              },
            ),
          );
        }
        reply.complete({
          'thread': _threadJson(id: 'raced'),
          ..._executionSettingsJson(model: 'older-model'),
        });
        // Retaining the newer value or admitting honest uncertainty is safe;
        // displaying the known-older configuration after eviction is not.
        expect((await pending).executionSettings?.model, isNot('older-model'));
      } finally {
        await subscription.cancel();
      }
    },
  );

  test('loaded session replies preserve actual inherited settings', () async {
    for (final method in ['thread/start', 'thread/resume', 'thread/fork']) {
      responses[method] = {
        'thread': _threadJson(id: 'configured-thread'),
        ..._executionSettingsJson(model: 'configured-model'),
      };
      final thread = await switch (method) {
        'thread/start' => adapter.startThread(
          const ThreadStartOptions(cwd: '/workspace'),
        ),
        'thread/resume' => adapter.resumeThread('configured-thread'),
        _ => adapter.forkThread(
          const ThreadForkOptions(threadId: 'parent-thread'),
        ),
      };
      final settings = thread.executionSettings!;
      expect(settings.model, 'configured-model');
      expect(settings.modelProvider, 'custom-provider');
      expect(settings.reasoningEffort, 'high');
      expect(settings.approvalPolicy, ObservedApprovalPolicy.never);
      expect(settings.sandbox, ObservedSandboxPolicy.readOnly);
      expect(requests.last.params.containsKey('model'), isFalse);
      expect(requests.last.params.containsKey('approvalPolicy'), isFalse);
    }
  });

  test('a newer settings notification wins over an in-flight session reply', () async {
    final reply = Completer<JsonObject>();
    final raced = ThreadProtocolAdapter(
      request: (method, [params = const {}]) => method == 'thread/start'
          ? reply.future
          : Future.value({'thread': _threadJson(id: 'raced-thread')}),
      notifications: notifications.stream,
    );
    final events = <ThreadLifecycleEvent>[];
    final subscription = raced.events.listen(events.add);
    try {
      final pending = raced.startThread(
        const ThreadStartOptions(cwd: '/workspace'),
      );
      notifications.add(
        CodexNotification(
          method: 'thread/settings/updated',
          params: {
            'threadId': 'raced-thread',
            'threadSettings': {
              ..._executionSettingsJson(model: 'newer-model'),
              'effort': 'low',
              'sandboxPolicy': {'type': 'externalSandbox'},
            },
          },
        ),
      );
      reply.complete({
        'thread': _threadJson(id: 'raced-thread'),
        ..._executionSettingsJson(model: 'older-model'),
      });
      final settings = (await pending).executionSettings!;
      expect(settings.model, 'newer-model');
      expect(settings.reasoningEffort, 'low');
      expect(settings.sandbox, ObservedSandboxPolicy.externalSandbox);
      expect(settings.source, ThreadSettingsSource.notification);
      expect(events.single, isA<ThreadExecutionSettingsChangedEvent>());
      // A subsequent metadata-only read cannot invent or reset model settings.
      expect(
        (await raced.readThread('raced-thread')).executionSettings,
        same(settings),
      );
    } finally {
      await subscription.cancel();
    }
  });

  test(
    'settings observation retention stays bounded for inactive IDs',
    () async {
      final subscription = adapter.events.listen((_) {});
      try {
        for (var i = 0; i < 101; i += 1) {
          notifications.add(
            CodexNotification(
              method: 'thread/settings/updated',
              params: {
                'threadId': 'settings-$i',
                'threadSettings': {
                  ..._executionSettingsJson(model: 'configured-$i'),
                  'sandboxPolicy': {'type': 'readOnly'},
                },
              },
            ),
          );
        }
        responses['thread/read'] = {'thread': _threadJson(id: 'settings-0')};
        expect(
          (await adapter.readThread('settings-0')).executionSettings,
          isNull,
        );
        responses['thread/read'] = {'thread': _threadJson(id: 'settings-100')};
        expect(
          (await adapter.readThread('settings-100')).executionSettings?.model,
          'configured-100',
        );
      } finally {
        await subscription.cancel();
      }
    },
  );

  test(
    'granular and unknown policies do not become writable defaults',
    () async {
      responses['thread/start'] = {
        'thread': _threadJson(id: 'custom-policy'),
        ..._executionSettingsJson(model: 'configured-model'),
        'approvalPolicy': {
          'granular': {
            'mcp_elicitations': false,
            'rules': true,
            'sandbox_approval': false,
          },
        },
        'sandbox': {'type': 'externalSandbox'},
      };
      var thread = await adapter.startThread(
        const ThreadStartOptions(cwd: '/workspace'),
      );
      expect(
        thread.executionSettings?.approvalPolicy,
        ObservedApprovalPolicy.granular,
      );
      expect(
        thread.executionSettings?.sandbox,
        ObservedSandboxPolicy.externalSandbox,
      );
      responses['thread/start'] = {
        'thread': _threadJson(id: 'unknown-policy'),
        ..._executionSettingsJson(model: 'configured-model'),
        'approvalPolicy': 'future-policy',
        'sandbox': {'type': 'future-sandbox'},
      };
      thread = await adapter.startThread(
        const ThreadStartOptions(cwd: '/workspace'),
      );
      expect(
        thread.executionSettings?.approvalPolicy,
        ObservedApprovalPolicy.unknown,
      );
      expect(thread.executionSettings?.sandbox, ObservedSandboxPolicy.unknown);
    },
  );

  test('oversized settings stay unknown without failing a successful thread operation', () async {
    responses['thread/start'] = {
      'thread': _threadJson(id: 'oversized-settings'),
      ..._executionSettingsJson(model: 'm' * 513),
    };
    final thread = await adapter.startThread(
      const ThreadStartOptions(cwd: '/workspace'),
    );
    expect(thread.id, 'oversized-settings');
    expect(thread.executionSettings?.model, isNull);
    expect(
      thread.executionSettings?.approvalPolicy,
      ObservedApprovalPolicy.never,
    );
  });

  test('queued-work presence requires a conclusive bounded page', () async {
    responses['thread/queue/list'] = {'data': [], 'nextCursor': null};
    expect(
      await adapter.readQueuePresence('thread-1'),
      ThreadQueuePresence.empty,
    );
    expect(requests.last.params, {'threadId': 'thread-1', 'limit': 1});

    responses['thread/queue/list'] = {'data': [], 'nextCursor': 'continuation'};
    await expectLater(
      adapter.readQueuePresence('thread-1'),
      throwsA(isA<ProtocolViolation>()),
    );
    responses['thread/queue/list'] = {
      'data': [
        {'id': 'one'},
        {'id': 'unexpected-extra'},
      ],
    };
    await expectLater(
      adapter.readQueuePresence('thread-1'),
      throwsA(isA<ProtocolViolation>()),
    );
  });

  test(
    'optional read receipts bind to listed IDs and metadata-only reads',
    () async {
      responses['thread/list'] = {
        'data': [
          _threadJson(id: 'saved'),
          {..._threadJson(id: 'temporary'), 'ephemeral': true},
          _threadJson(id: 'unknown-position'),
        ],
        'readStates': {
          'saved': {
            'revision': 'opaque-1',
            'firstUnread': {'type': 'turn', 'turnId': 'turn-1'},
          },
          'temporary': {
            'revision': 'opaque-2',
            'firstUnread': {'type': 'threadStart'},
          },
          'unknown-position': {
            'revision': 'opaque-3',
            'firstUnread': {'type': 'future'},
          },
          'not-in-page': {'revision': 'opaque-4', 'firstUnread': null},
        },
      };
      final page = await adapter.listThreads(const ThreadListQuery());
      expect(page.threads.first.readReceipt?.revision, 'opaque-1');
      expect(page.threads.first.readReceipt?.unread, isTrue);
      expect(
        page.threads.skip(1).map((row) => row.readReceipt),
        everyElement(isNull),
      );

      responses['thread/read'] = {
        'thread': _threadJson(id: 'saved'),
        'readState': {'revision': 'opaque-5', 'firstUnread': null},
      };
      final cold = await adapter.readThread('saved');
      expect(cold.readReceipt?.unread, isFalse);
      expect(requests.last.params, {
        'threadId': 'saved',
        'includeTurns': false,
      });
    },
  );

  test(
    'only sends an explicit revisioned mark and decodes valid receipt events',
    () async {
      final observed = <ThreadLifecycleEvent>[];
      final subscription = adapter.events.listen(observed.add);
      addTearDown(subscription.cancel);
      const readState = {
        'revision': 'opaque-new',
        'firstUnread': {'type': 'threadStart'},
      };
      responses['thread/readState/update'] = {'readState': readState};

      final updated = await adapter.setReadReceipt(
        threadId: 'saved',
        expectedRevision: 'opaque-seen',
        unread: true,
      );
      expect(updated.unread, isTrue);
      expect(requests.last.params, {
        'threadId': 'saved',
        'expectedRevision': 'opaque-seen',
        'operation': {'type': 'unread'},
      });
      notifications.add(
        const CodexNotification(
          method: 'thread/readState/changed',
          params: {'threadId': 'saved', 'readState': readState},
        ),
      );
      notifications.add(
        const CodexNotification(
          method: 'thread/readState/changed',
          params: {
            'threadId': 'saved',
            'readState': {'revision': '', 'firstUnread': null},
          },
        ),
      );
      final event = observed.single as ThreadReadReceiptChangedEvent;
      expect(event.threadId, 'saved');
      expect(event.receipt.revision, 'opaque-new');
    },
  );

  test(
    'direct Host read-only mode rejects local read receipt writes',
    () async {
      final runtime = RuntimeController(useRemote: true);
      addTearDown(runtime.dispose);
      expect(runtime.supportsThreadReadReceiptWrites, isFalse);
      await expectLater(
        runtime.setThreadReadReceipt(
          threadId: 'thread-1',
          expectedRevision: 'opaque',
          unread: false,
        ),
        throwsUnsupportedError,
      );
    },
  );

  test('writes only explicit user goal fields and validates replies', () async {
    final goal = {
      'threadId': 'thread-1',
      'objective': 'Check the fixture',
      'status': 'paused',
      'createdAt': 10,
      'updatedAt': 11,
      'tokensUsed': 0,
      'timeUsedSeconds': 0,
    };
    responses['thread/goal/get'] = {'goal': null};
    responses['thread/goal/set'] = {'goal': goal};
    responses['thread/goal/clear'] = {'cleared': true};

    expect(await adapter.readThreadGoal('thread-1'), isNull);
    final saved = await adapter.setThreadGoal(
      'thread-1',
      objective: ' Check the fixture ',
      status: ThreadGoalStatus.paused,
    );
    expect(saved.status, ThreadGoalStatus.paused);
    expect(requests.last.params, {
      'threadId': 'thread-1',
      'origin': 'user',
      'objective': 'Check the fixture',
      'status': 'paused',
    });
    await adapter.setThreadGoal('thread-1', status: ThreadGoalStatus.active);
    expect(requests.last.params, {
      'threadId': 'thread-1',
      'origin': 'user',
      'status': 'active',
    });
    expect(await adapter.clearThreadGoal('thread-1'), isTrue);
    expect(requests.last.params, {'threadId': 'thread-1', 'origin': 'user'});

    responses['thread/goal/get'] = {
      'goal': {...goal, 'threadId': 'other-thread'},
    };
    await expectLater(
      adapter.readThreadGoal('thread-1'),
      throwsA(isA<ProtocolViolation>()),
    );
    final callCount = requests.length;
    await expectLater(
      adapter.setThreadGoal('thread-1', objective: 'x' * 2049),
      throwsArgumentError,
    );
    await expectLater(
      adapter.setThreadGoal('thread-1', status: ThreadGoalStatus.complete),
      throwsArgumentError,
    );
    expect(requests, hasLength(callCount));
  });

  test('read-only Remote rejects every thread-goal call', () {
    final runtime = RuntimeController(useRemote: true);
    addTearDown(runtime.dispose);
    expect(runtime.supportsThreadGoals, isFalse);
    expect(() => runtime.readThreadGoal('thread-1'), throwsUnsupportedError);
    expect(
      () => runtime.setThreadGoal('thread-1', status: ThreadGoalStatus.active),
      throwsUnsupportedError,
    );
    expect(() => runtime.clearThreadGoal('thread-1'), throwsUnsupportedError);
  });

  test(
    'serializes explicit section scope and validates the bounded page',
    () async {
      const scopedQuery = ThreadListQuery(
        section: (id: ' section-1 '),
        sortKey: ThreadSortKey.sectionPosition,
        sortDirection: SortDirection.ascending,
        cursor: 'section-page',
        limit: 1,
      );
      final inSection = {
        ..._threadJson(id: 'thread-1'),
        'section': {'id': 'section-1', 'name': 'Work queue'},
      };
      responses['thread/list'] = {
        'data': [inSection],
        'nextCursor': 'section-next',
      };
      final page = await adapter.listThreads(scopedQuery);
      expect(page.threads.single.section?.id, 'section-1');
      expect(page.nextCursor, 'section-next');
      expect(requests.last.params, {
        'sectionId': 'section-1',
        'sortKey': 'section_position',
        'sortDirection': 'asc',
        'cursor': 'section-page',
        'limit': 1,
        'archived': false,
      });

      responses['thread/list'] = {
        'data': [_threadJson(id: 'plain')],
      };
      await adapter.listThreads(const ThreadListQuery(section: (id: null)));
      expect(requests.last.params, containsPair('sectionId', null));
      await adapter.listThreads(const ThreadListQuery());
      expect(requests.last.params, isNot(contains('sectionId')));

      await expectLater(
        adapter.listThreads(scopedQuery),
        throwsA(isA<ProtocolViolation>()),
      );
      responses['thread/list'] = {
        'data': [inSection, inSection],
      };
      await expectLater(
        adapter.listThreads(scopedQuery),
        throwsA(isA<ProtocolViolation>()),
      );
      final issued = requests.length;
      await expectLater(
        adapter.listThreads(
          const ThreadListQuery(sortKey: ThreadSortKey.sectionPosition),
        ),
        throwsArgumentError,
      );
      expect(requests, hasLength(issued));
    },
  );

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

  test(
    'drops credential-bearing git origins that cannot be sanitized',
    () async {
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
          {
            ..._threadJson(id: 'thread-git-scp-credentials'),
            'gitInfo': {
              'branch': 'main',
              'originUrl': 'user:secret@example.test:owner/repo.git',
              'sha': 'def456',
            },
          },
        ],
        'nextCursor': null,
      };

      final page = await adapter.listThreads(const ThreadListQuery());

      expect(page.threads, hasLength(2));
      expect(page.threads[0].gitInfo?.originUrl, isNull);
      expect(page.threads[1].gitInfo?.originUrl, isNull);
    },
  );

  test('preserves normal SCP-like git origins without suffix data', () async {
    responses['thread/list'] = {
      'data': [
        {
          ..._threadJson(id: 'thread-git-scp'),
          'gitInfo': {
            'branch': 'main',
            'originUrl':
                'git@example.test:owner/repo.git?token=secret#fragment',
            'sha': 'abc123',
          },
        },
      ],
      'nextCursor': null,
    };

    final page = await adapter.listThreads(const ThreadListQuery());

    expect(
      page.threads.single.gitInfo?.originUrl,
      'git@example.test:owner/repo.git',
    );
  });

  test('drops overlong git origins before parsing or reconstruction', () async {
    responses['thread/list'] = {
      'data': [
        {
          ..._threadJson(id: 'thread-git-overlong-url'),
          'gitInfo': {
            'branch': 'main',
            'originUrl': 'https://example.test/${'a' * 1100}',
            'sha': 'abc123',
          },
        },
        {
          ..._threadJson(id: 'thread-git-overlong-scp'),
          'gitInfo': {
            'branch': 'main',
            'originUrl': 'git@example.test:${'b' * 1100}',
            'sha': 'def456',
          },
        },
      ],
      'nextCursor': null,
    };

    final page = await adapter.listThreads(const ThreadListQuery());

    expect(page.threads[0].gitInfo?.originUrl, isNull);
    expect(page.threads[1].gitInfo?.originUrl, isNull);
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

  test('lists, deduplicates, bounds, creates, updates, deletes, and moves thread sections', () async {
    responses['threadSection/list'] = {
      'data': [
        for (var i = 0; i < 64; i += 1)
          {
            'id': 'sec-${i == 1 ? 0 : i}',
            'name': 'Section $i ${'x' * 200}',
            'appearance': {'color': 'blue', 'icon': 'star'},
          },
      ],
      'nextCursor': 'next-sec-cursor',
    };
    responses['threadSection/create'] = {
      'section': {
        'id': 'sec-created',
        'name': 'Priority',
        'appearance': {'color': 'amber', 'icon': 'flag'},
      },
    };
    responses['threadSection/update'] = {
      'section': {
        'id': 'sec-created',
        'name': 'Renamed Priority',
        'appearance': null,
      },
    };
    responses['threadSection/delete'] = const {};
    responses['thread/section/move'] = const {};

    final page = await adapter.listThreadSections(
      const ThreadSectionListQuery(cursor: 'cur-0', limit: 64),
    );
    expect(page.sections, hasLength(63));
    expect(page.sections.first.id, 'sec-0');
    expect(page.sections.first.name, hasLength(129));
    expect(page.sections.first.name, endsWith('…'));
    expect(page.sections.first.appearance?.color, 'blue');
    expect(page.sections.first.appearance?.icon, 'star');
    expect(page.nextCursor, 'next-sec-cursor');

    final created = await adapter.createThreadSection(
      const ThreadSectionCreateOptions(
        name: 'Priority',
        appearance: ThreadSectionAppearance(color: 'amber', icon: 'flag'),
      ),
    );
    expect(created.id, 'sec-created');
    expect(created.name, 'Priority');
    expect(created.appearance?.color, 'amber');

    final updated = await adapter.updateThreadSection(
      const ThreadSectionUpdateOptions(
        sectionId: 'sec-created',
        name: 'Renamed Priority',
        clearAppearance: true,
      ),
    );
    expect(updated.id, 'sec-created');
    expect(updated.name, 'Renamed Priority');
    expect(updated.appearance, isNull);

    await adapter.deleteThreadSection('sec-created');
    await expectLater(
      () => adapter.updateThreadSection(
        const ThreadSectionUpdateOptions(
          sectionId: ' $kBuiltInPinnedThreadSectionId ',
          name: 'Renamed Built-in',
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      () => adapter.deleteThreadSection(' $kBuiltInPinnedThreadSectionId '),
      throwsArgumentError,
    );
    await adapter.moveThreadSection(
      const ThreadSectionMoveOptions(
        threadId: 'thread-5',
        sectionId: 'sec-created',
        beforeThreadId: 'thread-4',
      ),
    );
    await adapter.moveThreadSection(
      const ThreadSectionMoveOptions(threadId: 'thread-5', sectionId: null),
    );

    expect(requests, [
      _Request('threadSection/list', {'cursor': 'cur-0', 'limit': 64}),
      _Request('threadSection/create', {
        'name': 'Priority',
        'appearance': {'color': 'amber', 'icon': 'flag'},
      }),
      _Request('threadSection/update', {
        'sectionId': 'sec-created',
        'name': 'Renamed Priority',
        'appearance': null,
      }),
      _Request('threadSection/delete', {'sectionId': 'sec-created'}),
      _Request('thread/section/move', {
        'threadId': 'thread-5',
        'sectionId': 'sec-created',
        'beforeThreadId': 'thread-4',
      }),
      _Request('thread/section/move', {
        'threadId': 'thread-5',
        'sectionId': null,
      }),
    ]);
  });

  test('fails closed on overlong opaque section/thread IDs and oversized unpaginated section pages', () async {
    final maxId = 'm' * 512;
    responses['threadSection/update'] = {
      'section': {'id': maxId, 'name': 'Max ID Section'},
    };
    final exactUpdated = await adapter.updateThreadSection(
      ThreadSectionUpdateOptions(sectionId: maxId, name: 'Max ID Section'),
    );
    expect(exactUpdated.id, maxId);

    final overlongId = 's' * 513;
    await expectLater(
      () => adapter.updateThreadSection(
        ThreadSectionUpdateOptions(sectionId: overlongId, name: 'Valid'),
      ),
      throwsArgumentError,
    );
    await expectLater(
      () => adapter.deleteThreadSection(overlongId),
      throwsArgumentError,
    );
    await expectLater(
      () => adapter.moveThreadSection(
        ThreadSectionMoveOptions(threadId: overlongId, sectionId: 'sec-1'),
      ),
      throwsArgumentError,
    );
    await expectLater(
      () => adapter.moveThreadSection(
        ThreadSectionMoveOptions(threadId: 't-1', sectionId: overlongId),
      ),
      throwsArgumentError,
    );

    responses['threadSection/list'] = {
      'data': [
        for (var i = 0; i < 65; i += 1) {'id': 'sec-$i', 'name': 'Sec $i'},
      ],
      'nextCursor': null,
    };
    await expectLater(
      adapter.listThreadSections(),
      throwsA(isA<ProtocolViolation>()),
    );

    responses['threadSection/list'] = {
      'data': [
        for (var i = 0; i < 65; i += 1) {'id': 'sec-$i', 'name': 'Sec $i'},
      ],
      'nextCursor': 'cur-next',
    };
    await expectLater(
      adapter.listThreadSections(),
      throwsA(isA<ProtocolViolation>()),
    );

    responses['threadSection/list'] = {
      'data': [
        {'id': overlongId, 'name': 'Invalid ID'},
      ],
      'nextCursor': null,
    };
    await expectLater(
      adapter.listThreadSections(),
      throwsA(isA<ProtocolViolation>()),
    );

    final notificationError = expectLater(
      adapter.events,
      emitsError(isA<ProtocolViolation>()),
    );
    notifications.add(
      CodexNotification(
        method: 'thread/section/changed',
        params: {'threadId': 't-1', 'sectionId': overlongId},
      ),
    );
    await notificationError;
  });

  test('parses thread section metadata on Thread and thread/section/changed notifications', () async {
    responses['thread/read'] = {
      'thread': {
        ..._threadJson(id: 'thread-sec'),
        'section': {
          'id': 'sec-active',
          'name': 'Active Sprint',
          'appearance': {'color': 'green', 'icon': 'bolt'},
        },
        'sectionEnteredAt': 1730000555,
      },
    };

    final thread = await adapter.readThread('thread-sec');
    expect(thread.section?.id, 'sec-active');
    expect(thread.section?.name, 'Active Sprint');
    expect(thread.section?.appearance?.color, 'green');
    expect(thread.sectionEnteredAtSeconds, 1730000555);

    final received = <ThreadLifecycleEvent>[];
    final sub = adapter.events.listen(received.add);
    addTearDown(sub.cancel);

    notifications.add(
      const CodexNotification(
        method: 'thread/section/changed',
        params: {'threadId': 'thread-sec', 'sectionId': 'sec-next'},
      ),
    );
    notifications.add(
      const CodexNotification(
        method: 'thread/section/changed',
        params: {'threadId': 'thread-sec', 'sectionId': null},
      ),
    );

    expect(received, hasLength(2));
    expect(
      received[0],
      isA<ThreadSectionChangedEvent>()
          .having((e) => e.threadId, 'threadId', 'thread-sec')
          .having((e) => e.sectionId, 'sectionId', 'sec-next'),
    );
    expect(
      received[1],
      isA<ThreadSectionChangedEvent>()
          .having((e) => e.threadId, 'threadId', 'thread-sec')
          .having((e) => e.sectionId, 'sectionId', isNull),
    );
  });

  test(
    'RuntimeController fails closed for thread sections on Remote',
    () async {
      final remoteController = RuntimeController(useRemote: true);
      expect(remoteController.supportsThreadSections, isFalse);
      await expectLater(
        () => remoteController.listThreadSections(),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        () => remoteController.createThreadSection(
          const ThreadSectionCreateOptions(name: 'Blocked'),
        ),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        () => remoteController.updateThreadSection(
          const ThreadSectionUpdateOptions(sectionId: 'sec-1', name: 'Blocked'),
        ),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        () => remoteController.deleteThreadSection('sec-1'),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        () => remoteController.moveThreadSection(
          const ThreadSectionMoveOptions(threadId: 't-1', sectionId: 'sec-1'),
        ),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        () => remoteController.startReview(
          const ReviewStartOptions(
            threadId: 't-1',
            target: UncommittedChangesReviewTarget(),
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    },
  );
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

JsonObject _executionSettingsJson({required String model}) => {
  'model': model,
  'modelProvider': 'custom-provider',
  'reasoningEffort': 'high',
  'approvalPolicy': 'never',
  'sandbox': {'type': 'readOnly'},
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
    final leftValue = entry.value;
    final rightValue = right[entry.key];
    if (leftValue is JsonObject && rightValue is JsonObject) {
      if (!_mapsEqual(leftValue, rightValue)) {
        return false;
      }
      continue;
    }
    if (rightValue != leftValue) {
      return false;
    }
  }
  return true;
}
