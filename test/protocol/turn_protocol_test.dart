import 'dart:async';

import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/turn_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<CodexNotification> notifications;
  late List<_Request> requests;
  late Map<String, JsonObject> responses;
  late TurnProtocolAdapter adapter;

  setUp(() {
    notifications = StreamController<CodexNotification>.broadcast(sync: true);
    requests = [];
    responses = {};
    adapter = TurnProtocolAdapter(
      request: (method, [params = const {}]) async {
        requests.add(_Request(method, params));
        return responses[method] ?? const {};
      },
      notifications: notifications.stream,
      includeUserMessages: true,
    );
  });

  tearDown(() => notifications.close());

  test('starts a text turn without client prompt rewriting', () async {
    responses['turn/start'] = {
      'turn': {'id': 'turn-1', 'status': 'inProgress'},
    };

    final turn = await adapter.startTurn(
      const TurnStartOptions(threadId: 'thread-1', text: 'Do the task'),
    );

    expect(turn.id, 'turn-1');
    expect(turn.status, TurnRuntimeStatus.inProgress);
    expect(requests.single.method, 'turn/start');
    expect(requests.single.params, {
      'threadId': 'thread-1',
      'input': [
        {'type': 'text', 'text': 'Do the task', 'text_elements': <Object?>[]},
      ],
    });
    expect(requests.single.params, isNot(contains('developerInstructions')));
    expect(requests.single.params, isNot(contains('model')));
  });

  test('interrupts the exact active turn', () async {
    responses['turn/interrupt'] = const {};

    await adapter.interruptTurn(threadId: 'thread-1', turnId: 'turn-1');

    expect(requests.single.method, 'turn/interrupt');
    expect(requests.single.params, {
      'threadId': 'thread-1',
      'turnId': 'turn-1',
    });
  });

  test(
    'starts typed inline reviews without rewriting review targets',
    () async {
      responses['review/start'] = {
        'reviewThreadId': 'thread-1',
        'turn': {'id': 'review-turn-1', 'status': 'inProgress'},
      };

      final targets = <(ReviewTarget, JsonObject)>[
        (
          const UncommittedChangesReviewTarget(),
          const {'type': 'uncommittedChanges'},
        ),
        (
          const BaseBranchReviewTarget('origin/main'),
          const {'type': 'baseBranch', 'branch': 'origin/main'},
        ),
        (
          const CommitReviewTarget(sha: 'abc123', title: 'Fix race'),
          const {'type': 'commit', 'sha': 'abc123', 'title': 'Fix race'},
        ),
        (
          const CustomReviewTarget('Focus on shutdown races.'),
          const {'type': 'custom', 'instructions': 'Focus on shutdown races.'},
        ),
      ];

      for (final (target, expectedTarget) in targets) {
        final handle = await adapter.startReview(
          ReviewStartOptions(threadId: 'thread-1', target: target),
        );
        expect(handle.reviewThreadId, 'thread-1');
        expect(handle.turn.id, 'review-turn-1');
        expect(handle.turn.status, TurnRuntimeStatus.inProgress);
        expect(requests.last.method, 'review/start');
        expect(requests.last.params, {
          'threadId': 'thread-1',
          'target': expectedTarget,
        });
        expect(requests.last.params, isNot(contains('delivery')));
      }
    },
  );

  test(
    'rejects invalid review input and mismatched review thread IDs',
    () async {
      await expectLater(
        adapter.startReview(
          const ReviewStartOptions(
            threadId: 'thread-1',
            target: BaseBranchReviewTarget('  '),
          ),
        ),
        throwsArgumentError,
      );

      responses['review/start'] = {
        'reviewThreadId': 'thread-other',
        'turn': {'id': 'review-turn-1', 'status': 'inProgress'},
      };
      await expectLater(
        adapter.startReview(
          const ReviewStartOptions(
            threadId: 'thread-1',
            target: UncommittedChangesReviewTarget(),
          ),
        ),
        throwsA(isA<ProtocolViolation>()),
      );
    },
  );

  test('serializes only explicit execution overrides', () async {
    responses['turn/start'] = {
      'turn': {'id': 'turn-2', 'status': 'inProgress'},
    };

    await adapter.startTurn(
      const TurnStartOptions(
        threadId: 'thread-1',
        text: 'Do the task',
        model: 'model-wire-name',
        reasoningEffort: 'high',
        approvalPolicy: ApprovalPolicyOverride.onRequest,
        sandbox: SandboxModeOverride.workspaceWrite,
      ),
    );

    expect(requests.single.params['model'], 'model-wire-name');
    expect(requests.single.params['effort'], 'high');
    expect(requests.single.params['approvalPolicy'], 'on-request');
    expect(requests.single.params['sandboxPolicy'], {'type': 'workspaceWrite'});
  });

  test(
    'serializes structured UserAttachment items and steers active turns',
    () async {
      responses['turn/start'] = {
        'turn': {'id': 'turn-3', 'status': 'inProgress'},
      };
      responses['turn/steer'] = {'turnId': 'turn-3'};

      await adapter.startTurn(
        const TurnStartOptions(
          threadId: 'thread-1',
          text: 'Inspect these',
          attachments: [
            UserAttachment(
              kind: UserAttachmentKind.mention,
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
            UserAttachment(
              kind: UserAttachmentKind.image,
              label: 'screen.png',
              path: '/tmp/screen.png',
            ),
            UserAttachment(
              kind: UserAttachmentKind.image,
              label: 'diagram.png',
              path: 'https://example.com/diagram.png',
            ),
            UserAttachment(
              kind: UserAttachmentKind.skill,
              label: r'$frontend-design',
              path: '/skills/frontend-design',
            ),
          ],
        ),
      );

      expect(requests.first.method, 'turn/start');
      expect(requests.first.params['input'], [
        {'type': 'text', 'text': 'Inspect these', 'text_elements': <Object?>[]},
        {'type': 'mention', 'name': 'main.dart', 'path': 'lib/main.dart'},
        {'type': 'localImage', 'path': '/tmp/screen.png'},
        {'type': 'image', 'url': 'https://example.com/diagram.png'},
        {
          'type': 'skill',
          'name': 'frontend-design',
          'path': '/skills/frontend-design',
        },
      ]);

      final steeredTurnId = await adapter.steerTurn(
        const TurnSteerOptions(
          threadId: 'thread-1',
          expectedTurnId: 'turn-3',
          text: 'Now update the widget',
          attachments: [
            UserAttachment(
              kind: UserAttachmentKind.pastedText,
              label: 'Snippet',
              preview: 'const x = 1;',
            ),
          ],
        ),
      );

      expect(steeredTurnId, 'turn-3');
      expect(requests.last.method, 'turn/steer');
      expect(requests.last.params, {
        'threadId': 'thread-1',
        'expectedTurnId': 'turn-3',
        'input': [
          {
            'type': 'text',
            'text': 'Now update the widget',
            'text_elements': <Object?>[],
          },
          {
            'type': 'text',
            'text': 'const x = 1;',
            'text_elements': <Object?>[],
          },
        ],
      });
    },
  );

  test('passes distinct client IDs for start and steer', () async {
    responses['turn/start'] = {
      'turn': {'id': 'turn-1', 'status': 'inProgress'},
    };
    responses['turn/steer'] = {'turnId': 'turn-1'};

    await adapter.startTurn(
      const TurnStartOptions(
        threadId: 'thread-1',
        text: 'Start',
        clientUserMessageId: 'native-start',
      ),
    );
    await adapter.steerTurn(
      const TurnSteerOptions(
        threadId: 'thread-1',
        expectedTurnId: 'turn-1',
        text: 'Steer',
        clientUserMessageId: 'native-steer',
      ),
    );

    expect(requests.map((request) => request.params['clientUserMessageId']), [
      'native-start',
      'native-steer',
    ]);
  });

  test('projects identified completed user items with bounded input', () async {
    final events = <TurnEvent>[];
    final subscription = adapter.events.listen(events.add);
    addTearDown(subscription.cancel);
    final defaultEvents = <TurnEvent>[];
    final defaultProjection = TurnProtocolAdapter(
      request: (_, [_ = const {}]) async => const {},
      notifications: notifications.stream,
    ).events.listen(defaultEvents.add);
    addTearDown(defaultProjection.cancel);
    final params = <String, Object?>{
      'threadId': 'thread-1',
      'turnId': 'turn-1',
      'item': {
        'id': 'user-1',
        'type': 'userMessage',
        'clientId': 'originating-client',
        'content': [
          {'type': 'text', 'text': 'Inspect'},
          {'type': 'text', 'text': 'this file'},
          {'type': 'mention', 'name': 'main.dart', 'path': 'lib/main.dart'},
        ],
      },
    };
    notifications
      ..add(CodexNotification(method: 'item/started', params: params))
      ..add(
        CodexNotification(
          method: 'item/completed',
          params: {
            ...params,
            'item': {'id': 'anonymous', 'type': 'userMessage', 'content': []},
          },
        ),
      )
      ..add(CodexNotification(method: 'item/completed', params: params))
      ..add(
        CodexNotification(
          method: 'item/completed',
          params: {
            ...params,
            'item': {
              'id': 'user-2',
              'type': 'userMessage',
              'clientId': 'c' * 1024,
              'content': [
                {'type': 'text', 'text': '${'x' * (64 * 1024 - 1)}😀b'},
                for (var i = 0; i < 20; i++)
                  {'type': 'mention', 'name': 'file $i', 'path': 'file-$i'},
              ],
            },
          },
        ),
      );

    final projected = events.cast<UserMessageEvent>();
    expect(projected, hasLength(2));
    expect(defaultEvents, isEmpty);
    expect(projected.first.itemId, 'user-1');
    expect(projected.first.clientMessageId, 'originating-client');
    expect(projected.first.text, 'Inspect\nthis file');
    expect(projected.first.attachments.single.path, 'lib/main.dart');
    expect(projected.last.itemId, 'user-2');
    expect(projected.last.clientMessageId, isNull);
    expect(projected.last.text, '${'x' * (64 * 1024 - 1)}…');
    expect(projected.last.attachments, hasLength(maxUserAttachments));
  });

  test('maps lifecycle and assistant delta notifications', () async {
    final events = <TurnEvent>[];
    final subscription = adapter.events.listen(events.add);
    addTearDown(subscription.cancel);

    notifications
      ..add(
        CodexNotification(
          method: 'turn/started',
          params: {
            'threadId': 'thread-1',
            'turn': {'id': 'turn-1'},
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'item/agentMessage/delta',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'itemId': 'message-1',
            'delta': 'Hello',
          },
        ),
      )
      ..add(
        CodexNotification(
          method: 'item/completed',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'completedAtMs': 1,
            'item': {
              'type': 'agentMessage',
              'id': 'message-1',
              'text': 'Hello',
            },
          },
        ),
      )
      ..add(
        CodexNotification(
          method: 'turn/completed',
          params: {
            'threadId': 'thread-1',
            'turn': {'id': 'turn-1', 'status': 'completed', 'error': null},
          },
        ),
      );
    await pumpEventQueue();

    expect(events, hasLength(4));
    expect(events[0], isA<TurnStartedEvent>());
    expect(
      events[1],
      isA<AssistantTextDeltaEvent>().having(
        (event) => event.delta,
        'delta',
        'Hello',
      ),
    );
    expect(
      events[2],
      isA<AssistantMessageEvent>().having(
        (event) => event.completed,
        'completed',
        isTrue,
      ),
    );
    expect(
      events[3],
      isA<TurnCompletedEvent>().having(
        (event) => event.status,
        'status',
        TurnRuntimeStatus.completed,
      ),
    );
  });

  test('summarizes command activity without retaining its output', () async {
    final eventFuture = adapter.events.first;
    notifications.add(
      CodexNotification(
        method: 'item/completed',
        params: {
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'item': {
            'type': 'commandExecution',
            'id': 'command-1',
            'command': 'flutter test',
            'status': 'completed',
            'commandActions': [
              {'type': 'read', 'path': '/fixture/first'},
              {'type': 'read', 'path': '/fixture/second'},
              {'type': 'listFiles'},
              {'type': 'search'},
              {'type': 'unknown'},
              {'type': 'futureVariant'},
            ],
            'aggregatedOutput': 'MULTI_MEGABYTE_OUTPUT_MUST_NOT_BE_RETAINED',
          },
        },
      ),
    );

    final event = await eventFuture as ActivityEvent;
    expect(event.summary, 'Command: flutter test');
    expect(event.summary, isNot(contains('MULTI_MEGABYTE')));
    expect(event.status, 'completed');
    expect(event.commandActions, CommandActionKind.values.toSet());
  });

  test('projects completed command references only on the Host path', () async {
    final host = TurnProtocolAdapter(
      request: (_, [params = const {}]) async => const {},
      notifications: notifications.stream,
      includeHostCommandOutput: true,
    );
    final hostEvents = host.events.take(3).cast<ActivityEvent>().toList();
    final stockEvents = adapter.events.take(3).cast<ActivityEvent>().toList();
    const item = {
      'type': 'commandExecution',
      'id': 'command-1',
      'command': 'flutter test',
      'status': 'completed',
      'aggregatedOutput': 'OUTPUT_STAYS_OUT_OF_THE_ACTIVITY_EVENT',
      '_codexNativeOutput': {
        'ref': 'host-command-ref',
        'bytes': 200000,
        'storedBytes': 179835,
        'truncated': true,
        'available': true,
      },
    };
    for (final (method, value) in [
      ('item/started', item),
      ('item/completed', item),
      ('item/completed', {...item, '_codexNativeOutput': 'invalid'}),
    ]) {
      notifications.add(
        CodexNotification(
          method: method,
          params: {'threadId': 'thread-1', 'turnId': 'turn-1', 'item': value},
        ),
      );
    }
    final events = await hostEvents;
    expect(events.first.commandOutput, isNull);
    expect(events[1].commandOutput?.reference, 'host-command-ref');
    expect(events[1].commandOutput?.storedBytes, 179835);
    expect(events[1].summary, 'Command: flutter test');
    expect(events.last.commandOutput, isNull);
    expect(events.last.completed, isTrue);
    expect(
      (await stockEvents).map((event) => event.commandOutput),
      everyElement(isNull),
    );
  });

  test('projects bounded review-mode lifecycle items', () async {
    final events = <TurnEvent>[];
    final subscription = adapter.events.listen(events.add);
    addTearDown(subscription.cancel);

    notifications
      ..add(
        CodexNotification(
          method: 'item/completed',
          params: {
            'threadId': 'thread-1',
            'turnId': 'review-turn-1',
            'item': {
              'id': 'review-entered',
              'type': 'enteredReviewMode',
              'review': 'r' * 1000,
            },
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'item/completed',
          params: {
            'threadId': 'thread-1',
            'turnId': 'review-turn-1',
            'item': {
              'id': 'review-exited',
              'type': 'exitedReviewMode',
              'review': 'Uncommitted changes',
            },
          },
        ),
      );
    await pumpEventQueue();

    expect(events, hasLength(2));
    final entered = events.first as ReviewModeEvent;
    expect(entered.phase, ReviewModePhase.entered);
    expect(entered.review, hasLength(513));
    expect(entered.review, endsWith('…'));
    expect(entered.summary, startsWith('Review started:'));
    final exited = events.last as ReviewModeEvent;
    expect(exited.phase, ReviewModePhase.exited);
    expect(exited.summary, 'Review completed: Uncommitted changes');
  });

  test('projects turn diff updates into bounded typed files', () async {
    final eventFuture = adapter.events
        .where((event) => event is TurnDiffUpdatedEvent)
        .cast<TurnDiffUpdatedEvent>()
        .first;
    notifications.add(
      const CodexNotification(
        method: 'turn/diff/updated',
        params: {
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'diff':
              'diff --git a/lib/a.dart b/lib/a.dart\n'
              '--- a/lib/a.dart\n'
              '+++ b/lib/a.dart\n'
              '@@ -1 +1 @@\n'
              '-old\n'
              '+new\n',
        },
      ),
    );

    final event = await eventFuture;
    expect(event.snapshot.files.single.path, 'lib/a.dart');
    expect(event.snapshot.additions, 1);
    expect(event.snapshot.deletions, 1);
  });

  test('projects rich Codex tool, webSearch, plan, and contextCompaction notifications into ActivityEvent', () async {
    final events = <ActivityEvent>[];
    final sub = adapter.events
        .where((e) => e is ActivityEvent)
        .cast<ActivityEvent>()
        .listen(events.add);
    addTearDown(sub.cancel);

    notifications
      ..add(
        const CodexNotification(
          method: 'item/started',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'item': {
              'type': 'mcpToolCall',
              'id': 'mcp-1',
              'server': 'github',
              'tool': 'list_issues',
              'status': 'inProgress',
            },
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'item/completed',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'item': {
              'type': 'webSearch',
              'id': 'ws-1',
              'query': 'rust tokio select',
              'status': 'completed',
            },
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'item/completed',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'item': {
              'type': 'plan',
              'id': 'plan-1',
              'text': 'Inspect transport layer\nRun tests',
              'status': 'completed',
            },
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'item/completed',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'item': {
              'type': 'todoList',
              'id': 'todo-1',
              'steps': [
                {'step': 'Audit', 'completed': true},
                {'step': 'Fix', 'completed': false},
              ],
              'status': 'completed',
            },
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'item/completed',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'item': {
              'type': 'fileChange',
              'id': 'fc-1',
              'changes': [
                {'path': 'src/lib.rs', 'additions': 5, 'deletions': 2},
              ],
              'status': 'completed',
            },
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'item/completed',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'item': {
              'type': 'contextCompaction',
              'id': 'compact-1',
              'status': 'completed',
            },
          },
        ),
      );
    await pumpEventQueue();

    expect(events, hasLength(6));
    expect(events[0].summary, 'MCP: github/list_issues');
    expect(events[0].completed, isFalse);
    expect(events[1].summary, 'Web search: rust tokio select');
    expect(events[2].summary, 'Plan: Inspect transport layer');
    expect(events[3].summary, 'Plan updated (1/2 completed)');
    expect(events[4].summary, 'File changes: 1 update(s) (+5 -2)');
    expect(events[5].summary, 'Context compacted');
  });

  test('parses stable turn plan, token usage, reasoning summary delta, MCP progress, hook lifecycle, model reroute, and warning notifications with bounds', () async {
    final events = <TurnEvent>[];
    final sub = adapter.events.listen(events.add);
    addTearDown(sub.cancel);

    notifications
      ..add(
        CodexNotification(
          method: 'turn/plan/updated',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'explanation': 'Verify protocol adapters and UI projection',
            'plan': [
              for (var i = 0; i < 60; i++)
                {
                  'step': 'Step $i',
                  'status': i == 0
                      ? 'completed'
                      : i == 1
                      ? 'inProgress'
                      : 'pending',
                },
            ],
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'thread/tokenUsage/updated',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'tokenUsage': {
              'last': {
                'inputTokens': 1200,
                'cachedInputTokens': 400,
                'cacheWriteInputTokens': 100,
                'outputTokens': 300,
                'reasoningOutputTokens': 150,
                'totalTokens': 1500,
              },
              'total': {
                'inputTokens': 10000,
                'cachedInputTokens': 2500,
                'outputTokens': 2800,
                'reasoningOutputTokens': 900,
                'totalTokens': 12800,
              },
              'modelContextWindow': 128000,
            },
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'item/reasoning/summaryTextDelta',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'itemId': 'reason-1',
            'summaryIndex': 0,
            'delta': 'Analyzing notification schema',
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'item/mcpToolCall/progress',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'itemId': 'mcp-1',
            'message': 'Fetched 12 pull requests',
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'hook/started',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'run': {
              'id': 'hook-run-1',
              'eventName': 'preToolUse',
              'handlerType': 'command',
              'executionMode': 'sync',
              'scope': 'turn',
              'source': 'project',
              'sourcePath': '/workspace/.codex/hooks.json',
              'startedAt': 1700000000,
              'status': 'running',
              'displayOrder': 0,
              'entries': <Object?>[],
            },
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'hook/completed',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'run': {
              'id': 'hook-run-1',
              'eventName': 'preToolUse',
              'handlerType': 'command',
              'executionMode': 'sync',
              'scope': 'turn',
              'source': 'project',
              'sourcePath': '/workspace/.codex/hooks.json',
              'startedAt': 1700000000,
              'completedAt': 1700000001,
              'durationMs': 42,
              'status': 'completed',
              'statusMessage': 'Policy check passed',
              'displayOrder': 0,
              'entries': [
                {'kind': 'context', 'text': 'Allowed tool call'},
              ],
            },
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'model/rerouted',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'fromModel': 'gpt-5-codex',
            'toModel': 'o3-mini',
            'reason': 'highRiskCyberActivity',
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'warning',
          params: {
            'threadId': 'thread-1',
            'message': 'Approaching workspace rate limit window.',
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'guardianWarning',
          params: {
            'threadId': 'thread-1',
            'message': 'Approval review requires extra caution.',
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'configWarning',
          params: {
            'summary': 'Project config contains a deprecated key.',
            'details': 'Use the supported replacement.',
            'path': '/private/workspace/.codex/config.toml',
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'deprecationNotice',
          params: {'summary': 'Legacy option is deprecated.', 'details': null},
        ),
      );
    await pumpEventQueue();

    expect(events, hasLength(11));

    final planEvent = events[0] as TurnPlanUpdatedEvent;
    expect(planEvent.plan.steps, hasLength(50));
    expect(planEvent.plan.completedCount, 1);
    expect(
      planEvent.plan.explanation,
      'Verify protocol adapters and UI projection',
    );
    expect(planEvent.plan.steps[0].status, TurnPlanStepStatus.completed);
    expect(planEvent.plan.steps[1].status, TurnPlanStepStatus.inProgress);

    final usageEvent = events[1] as ThreadTokenUsageUpdatedEvent;
    expect(usageEvent.usage.last.totalTokens, 1500);
    expect(usageEvent.usage.last.cacheWriteInputTokens, 100);
    expect(usageEvent.usage.total.totalTokens, 12800);
    expect(usageEvent.usage.modelContextWindow, 128000);
    expect(usageEvent.usage.contextWindowUtilization, closeTo(0.10, 0.001));

    final reasoningDelta = events[2] as ReasoningSummaryDeltaEvent;
    expect(reasoningDelta.itemId, 'reason-1');
    expect(reasoningDelta.summaryIndex, 0);
    expect(reasoningDelta.delta, 'Analyzing notification schema');

    final mcpProgress = events[3] as McpToolCallProgressEvent;
    expect(mcpProgress.itemId, 'mcp-1');
    expect(mcpProgress.message, 'Fetched 12 pull requests');

    final hookStarted = events[4] as HookActivityEvent;
    expect(hookStarted.runId, 'hook-run-1');
    expect(hookStarted.completed, isFalse);
    expect(hookStarted.formattedSummary, 'Hook: preToolUse (command)');

    final hookCompleted = events[5] as HookActivityEvent;
    expect(hookCompleted.runId, 'hook-run-1');
    expect(hookCompleted.completed, isTrue);
    expect(
      hookCompleted.formattedSummary,
      'Hook: preToolUse (command) — Policy check passed · 42ms',
    );

    final rerouted = events[6] as ModelReroutedEvent;
    expect(rerouted.fromModel, 'gpt-5-codex');
    expect(rerouted.toModel, 'o3-mini');
    expect(rerouted.reason, 'highRiskCyberActivity');

    final warning = events[7] as TurnWarningEvent;
    expect(warning.threadId, 'thread-1');
    expect(warning.message, 'Approaching workspace rate limit window.');

    final guardianWarning = events[8] as TurnWarningEvent;
    expect(guardianWarning.threadId, 'thread-1');
    expect(guardianWarning.message, 'Approval review requires extra caution.');

    final configWarning = events[9] as TurnWarningEvent;
    expect(configWarning.threadId, isEmpty);
    expect(
      configWarning.message,
      'Config: Project config contains a deprecated key. — Use the supported replacement.',
    );
    expect(configWarning.message, isNot(contains('/private/workspace')));

    final deprecationNotice = events[10] as TurnWarningEvent;
    expect(deprecationNotice.threadId, isEmpty);
    expect(
      deprecationNotice.message,
      'Deprecation: Legacy option is deprecated.',
    );
  });

  test('bounds config warning content at parser ingress', () async {
    final events = <TurnEvent>[];
    final sub = adapter.events.listen(events.add);
    addTearDown(sub.cancel);

    notifications.add(
      CodexNotification(
        method: 'configWarning',
        params: {
          'summary': 's' * 500,
          'details': 'd' * 500,
          'path': '/private/path/that/must/not/be/projected',
        },
      ),
    );
    await pumpEventQueue();

    final warning = events.single as TurnWarningEvent;
    expect(warning.message, hasLength(321));
    expect(warning.message, endsWith('…'));
    expect(warning.message, isNot(contains('/private/path')));
  });

  test('truncates oversized reasoning delta, model reroute fields, and MCP tool identifiers at parser ingress', () async {
    final events = <TurnEvent>[];
    final sub = adapter.events.listen(events.add);
    addTearDown(sub.cancel);

    final longText = 'x' * 500;
    notifications
      ..add(
        CodexNotification(
          method: 'item/reasoning/summaryTextDelta',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'itemId': 'reason-oversized',
            'summaryIndex': 0,
            'delta': longText,
          },
        ),
      )
      ..add(
        CodexNotification(
          method: 'model/rerouted',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'fromModel': longText,
            'toModel': longText,
            'reason': longText,
          },
        ),
      )
      ..add(
        CodexNotification(
          method: 'item/started',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'item': {
              'type': 'mcpToolCall',
              'id': 'mcp-oversized',
              'server': longText,
              'tool': longText,
              'status': 'inProgress',
            },
          },
        ),
      );
    await pumpEventQueue();

    expect(events, hasLength(3));
    final reasoning = events[0] as ReasoningSummaryDeltaEvent;
    expect(reasoning.delta.length, 241);
    expect(reasoning.delta.endsWith('…'), isTrue);

    final reroute = events[1] as ModelReroutedEvent;
    expect(reroute.fromModel.length, 121);
    expect(reroute.toModel.length, 121);
    expect(reroute.reason.length, 161);

    final mcpActivity = events[2] as ActivityEvent;
    expect(mcpActivity.summary.length, lessThanOrEqualTo(170));
    expect(mcpActivity.summary.endsWith('…'), isTrue);
  });
}

class _Request {
  const _Request(this.method, this.params);

  final String method;
  final JsonObject params;
}
