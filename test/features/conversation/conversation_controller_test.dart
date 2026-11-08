import 'dart:async';

import 'package:codex_native_unofficial/src/domain/model_gateway.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_gateway.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/conversation_controller.dart';
import 'package:codex_native_unofficial/src/features/settings/execution_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeTurnGateway gateway;
  late ConversationController controller;

  setUp(() {
    gateway = _FakeTurnGateway();
    final settings = ExecutionSettingsController(gateway: _FakeModelGateway());
    addTearDown(settings.dispose);
    controller = ConversationController(
      gateway: gateway,
      settings: settings,
      maxEntries: 8,
      maxEntryCharacters: 1024,
      coalesceInterval: Duration.zero,
    )..bindThread(_thread());
  });

  tearDown(() async {
    controller.dispose();
    await gateway.dispose();
  });

  test('submits user text and tracks turn lifecycle', () async {
    expect(await controller.submit('  Hello Codex  '), isTrue);

    expect(gateway.started, [('thread-1', 'Hello Codex')]);
    expect(controller.entries.single.kind, ConversationEntryKind.user);
    expect(controller.entries.single.text, 'Hello Codex');
    expect(controller.activeTurnId, 'turn-1');
    expect(controller.busy, isTrue);

    gateway.events
      ..add(const TurnStartedEvent(threadId: 'thread-1', turnId: 'turn-1'))
      ..add(
        const TurnCompletedEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          status: TurnRuntimeStatus.completed,
        ),
      );

    expect(controller.busy, isFalse);
    expect(controller.activeTurnId, isNull);
  });

  test('coalesces token deltas into one presentation update', () async {
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    for (var index = 0; index < 100; index += 1) {
      gateway.events.add(
        const AssistantTextDeltaEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'assistant-1',
          delta: 'x',
        ),
      );
    }
    expect(notifications, 0);

    await Future<void>.delayed(Duration.zero);

    expect(notifications, 1);
    expect(controller.entries.single.text, List.filled(100, 'x').join());
    expect(controller.entries.single.completed, isFalse);
  });

  test('caps assistant text and retains the newest portion', () async {
    gateway.events.add(
      AssistantMessageEvent(
        threadId: 'thread-1',
        turnId: 'turn-1',
        itemId: 'assistant-large',
        text: List.filled(2000, 'a').join(),
        completed: true,
      ),
    );

    final entry = controller.entries.single;
    expect(entry.text.length, 1024);
    expect(entry.text, startsWith('[Earlier text omitted]'));
    expect(entry.completed, isTrue);
  });

  test('stores activity summaries and can interrupt the active turn', () async {
    await controller.submit('Run it');
    gateway.events
      ..add(const TurnStartedEvent(threadId: 'thread-1', turnId: 'turn-1'))
      ..add(
        const ActivityEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'command-1',
          summary: 'Command: flutter test',
          status: 'inProgress',
          completed: false,
        ),
      );

    await controller.interrupt();

    expect(controller.entries.last.kind, ConversationEntryKind.activity);
    expect(controller.entries.last.text, 'Command: flutter test');
    expect(gateway.interrupted, [('thread-1', 'turn-1')]);
  });

  test('does not interrupt before turn/started is observed', () async {
    await controller.submit('Run it');

    expect(controller.busy, isTrue);
    expect(controller.canInterrupt, isFalse);
    await controller.interrupt();

    expect(gateway.interrupted, isEmpty);
  });

  test('ignores events for inactive threads and clears on thread switch', () {
    gateway.events.add(
      const AssistantMessageEvent(
        threadId: 'another-thread',
        turnId: 'turn-2',
        itemId: 'assistant-2',
        text: 'Not visible',
        completed: true,
      ),
    );
    expect(controller.entries, isEmpty);

    controller.bindThread(_thread(id: 'thread-2'));
    expect(controller.entries, isEmpty);
    expect(controller.thread?.id, 'thread-2');
  });

  test('steers an active turn when turn/started has been observed', () async {
    await controller.submit(
      'Initial instruction',
      attachments: const [
        UserAttachment(
          kind: UserAttachmentKind.mention,
          label: 'main.dart',
          path: 'lib/main.dart',
        ),
      ],
    );
    expect(controller.canSteer, isFalse);

    gateway.events.add(
      const TurnStartedEvent(threadId: 'thread-1', turnId: 'turn-1'),
    );
    expect(controller.canSteer, isTrue);

    expect(
      await controller.submit(
        'Focus on tests instead',
        attachments: const [
          UserAttachment(
            kind: UserAttachmentKind.skill,
            label: r'$test-runner',
            path: '/skills/test-runner',
          ),
        ],
      ),
      isTrue,
    );

    expect(gateway.steered, hasLength(1));
    expect(gateway.steered.single.threadId, 'thread-1');
    expect(gateway.steered.single.expectedTurnId, 'turn-1');
    expect(gateway.steered.single.text, 'Focus on tests instead');
    expect(gateway.steered.single.attachments.single.label, r'$test-runner');
    expect(controller.entries, hasLength(2));
    expect(controller.entries.last.text, 'Focus on tests instead');
    expect(controller.entries.last.turnId, 'turn-1');
    expect(controller.entries.last.attachments.single.label, r'$test-runner');
  });

  test('does not resurrect activeTurnId if turn/completed arrives while turn/steer is in flight', () async {
    await controller.submit('Start work');
    gateway.events.add(
      const TurnStartedEvent(threadId: 'thread-1', turnId: 'turn-1'),
    );

    final steerCompleter = Completer<String>();
    gateway.nextSteerCompleter = steerCompleter;

    final steerFuture = controller.steer('Mid-flight steer');
    expect(controller.canSteer, isFalse);

    // Server finishes turn-1 before steerTurn RPC resolves.
    gateway.events.add(
      const TurnCompletedEvent(
        threadId: 'thread-1',
        turnId: 'turn-1',
        status: TurnRuntimeStatus.completed,
      ),
    );
    expect(controller.busy, isFalse);
    expect(controller.activeTurnId, isNull);

    steerCompleter.complete('turn-1');
    expect(await steerFuture, isTrue);

    expect(controller.busy, isFalse);
    expect(controller.activeTurnId, isNull);
  });

  test('rolls back optimistic user entry on failed steer and clears entries on clearEntries()', () async {
    await controller.submit('Start work');
    gateway.events.add(
      const TurnStartedEvent(threadId: 'thread-1', turnId: 'turn-1'),
    );

    gateway.throwOnSteer = true;
    expect(await controller.steer('Will fail'), isFalse);

    // Optimistic 'Will fail' user bubble was rolled back; only original user
    // entry + error entry remain.
    expect(
      controller.entries.where((e) => e.kind == ConversationEntryKind.user),
      hasLength(1),
    );
    expect(controller.entries.last.kind, ConversationEntryKind.error);

    controller.clearEntries();
    expect(controller.entries, isEmpty);
    expect(controller.busy, isFalse);
    expect(controller.activeTurnId, isNull);
  });

  test('projects and coalesces reasoning summary deltas, MCP tool progress, turn plan, token usage, hooks, model reroute, and warnings with thread-switch reset', () async {
    var listenerCalls = 0;
    controller.addListener(() => listenerCalls += 1);

    // 1. Coalesce 20 reasoning summary deltas into a single 50ms flush and preserve summary on item/completed.
    for (var i = 0; i < 20; i++) {
      gateway.events.add(
        const ReasoningSummaryDeltaEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'reason-1',
          summaryIndex: 0,
          delta: 'step ',
        ),
      );
    }
    expect(listenerCalls, 0);
    await Future<void>.delayed(Duration.zero);
    expect(listenerCalls, 1);
    expect(
      controller.entries.single.text,
      startsWith('Reasoning: step step step'),
    );
    expect(controller.entries.single.completed, isFalse);

    gateway.events.add(
      const ActivityEvent(
        threadId: 'thread-1',
        turnId: 'turn-1',
        itemId: 'reason-1',
        summary: 'Reasoning',
        status: 'completed',
        completed: true,
      ),
    );
    expect(
      controller.entries.single.text,
      startsWith('Reasoning: step step step'),
    );
    expect(controller.entries.single.completed, isTrue);

    // 2. MCP tool call progress updates in-flight MCP activity item in place.
    gateway.events
      ..add(
        const ActivityEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'mcp-1',
          summary: 'MCP: github/list_issues',
          status: 'inProgress',
          completed: false,
        ),
      )
      ..add(
        const McpToolCallProgressEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'mcp-1',
          message: 'Loaded 25 issues',
        ),
      );
    final mcpEntry = controller.entries.firstWhere((e) => e.id == 'mcp-1');
    expect(mcpEntry.text, 'MCP: github/list_issues — Loaded 25 issues');
    expect(mcpEntry.completed, isFalse);

    // 3. Turn plan, token usage, hooks, model reroute, and warnings update bounded state.
    gateway.events
      ..add(
        TurnPlanUpdatedEvent(
          plan: const TurnPlanSnapshot(
            threadId: 'thread-1',
            turnId: 'turn-1',
            explanation: 'Execute validation suite',
            steps: [
              TurnPlanStepModel(
                step: 'Parse notifications',
                status: TurnPlanStepStatus.completed,
              ),
              TurnPlanStepModel(
                step: 'Verify UI banners',
                status: TurnPlanStepStatus.inProgress,
              ),
            ],
          ),
        ),
      )
      ..add(
        ThreadTokenUsageUpdatedEvent(
          usage: const ThreadTokenUsageSnapshot(
            threadId: 'thread-1',
            turnId: 'turn-1',
            last: TokenUsageBreakdownModel(
              inputTokens: 500,
              cachedInputTokens: 100,
              outputTokens: 200,
              reasoningOutputTokens: 50,
              totalTokens: 700,
            ),
            total: TokenUsageBreakdownModel(
              inputTokens: 6000,
              cachedInputTokens: 2000,
              outputTokens: 400,
              reasoningOutputTokens: 100,
              totalTokens: 6400,
            ),
            modelContextWindow: 64000,
          ),
        ),
      )
      ..add(
        const HookActivityEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          runId: 'hook-1',
          eventName: 'preToolUse',
          handlerType: 'command',
          executionMode: 'sync',
          scope: 'turn',
          status: 'completed',
          completed: true,
          statusMessage: 'Checked permissions',
          durationMs: 18,
        ),
      )
      ..add(
        const ModelReroutedEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          fromModel: 'gpt-5-codex',
          toModel: 'o3-mini',
          reason: 'highRiskCyberActivity',
        ),
      )
      ..add(
        const TurnWarningEvent(
          threadId: 'thread-1',
          message: 'Approaching rate limit window.',
        ),
      );

    expect(controller.latestTurnPlan?.completedCount, 1);
    expect(controller.tokenUsage?.total.totalTokens, 6400);
    expect(controller.latestModelReroute?.toModel, 'o3-mini');
    expect(controller.latestWarning, 'Approaching rate limit window.');
    expect(
      controller.entries.any(
        (e) =>
            e.id == 'hook-hook-1' &&
            e.text.contains('Hook: preToolUse (command)'),
      ),
      isTrue,
    );

    controller.dismissTelemetryNotice();
    expect(controller.latestWarning, isNull);
    expect(controller.latestModelReroute, isNull);

    controller.dismissTurnPlan();
    expect(controller.latestTurnPlan, isNull);

    // 4. Switching threads resets all per-thread telemetry state.
    controller.bindThread(_thread(id: 'thread-2'));
    expect(controller.tokenUsage, isNull);
    expect(controller.latestTurnPlan, isNull);
    expect(controller.entries, isEmpty);
  });

  test('bounds oversized telemetry strings at controller ingress and finalizes only matching or unassigned turn entries on turn/completed', () async {
    controller.bindThread(_thread());
    final huge = 'z' * 2000;

    // 1. Oversized reasoning deltas, MCP base summary, model reroute, and warning
    gateway.events
      ..add(
        ReasoningSummaryDeltaEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'reason-huge',
          summaryIndex: 0,
          delta: huge,
        ),
      )
      ..add(
        ReasoningSummaryDeltaEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'reason-huge',
          summaryIndex: 0,
          delta: huge,
        ),
      )
      ..add(
        ActivityEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'mcp-huge',
          summary: 'MCP: $huge/$huge',
          status: 'inProgress',
          completed: false,
        ),
      )
      ..add(
        McpToolCallProgressEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'mcp-huge',
          message: huge,
        ),
      )
      ..add(
        ModelReroutedEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          fromModel: huge,
          toModel: huge,
          reason: huge,
        ),
      )
      ..add(TurnWarningEvent(threadId: 'thread-1', message: huge))
      ..add(
        const ActivityEvent(
          threadId: 'thread-1',
          turnId: 'turn-2',
          itemId: 'other-turn-activity',
          summary: 'Command: cargo test',
          status: 'inProgress',
          completed: false,
        ),
      );

    expect(controller.latestModelReroute!.fromModel.length, 121);
    expect(controller.latestModelReroute!.toModel.length, 121);
    expect(controller.latestModelReroute!.reason.length, 161);
    expect(controller.latestWarning!.length, 321);

    final mcpEntryBeforeComplete = controller.entries.singleWhere(
      (e) => e.id == 'mcp-huge',
    );
    expect(mcpEntryBeforeComplete.text.length, lessThanOrEqualTo(410));
    expect(mcpEntryBeforeComplete.completed, isFalse);

    // 2. Completing turn-1 flushes and finalizes turn-1 entries without mutating turn-2
    gateway.events.add(
      const TurnCompletedEvent(
        threadId: 'thread-1',
        turnId: 'turn-1',
        status: TurnRuntimeStatus.completed,
      ),
    );

    final reasoningEntry = controller.entries.singleWhere(
      (e) => e.id == 'reason-huge',
    );
    expect(reasoningEntry.text.length, lessThanOrEqualTo(260));
    expect(reasoningEntry.completed, isTrue);
    expect(reasoningEntry.status, 'completed');

    final mcpEntryAfterComplete = controller.entries.singleWhere(
      (e) => e.id == 'mcp-huge',
    );
    expect(mcpEntryAfterComplete.completed, isTrue);
    expect(mcpEntryAfterComplete.status, 'completed');

    final otherTurnEntry = controller.entries.singleWhere(
      (e) => e.id == 'other-turn-activity',
    );
    expect(otherTurnEntry.completed, isFalse);
    expect(otherTurnEntry.status, 'inProgress');
    expect(otherTurnEntry.turnId, 'turn-2');
  });
}

class _FakeTurnGateway implements TurnGateway {
  final StreamController<TurnEvent> events =
      StreamController<TurnEvent>.broadcast(sync: true);
  final List<(String, String)> started = [];
  final List<TurnSteerOptions> steered = [];
  final List<(String, String)> interrupted = [];
  Completer<String>? nextSteerCompleter;
  var throwOnSteer = false;

  @override
  Stream<TurnEvent> get turnEvents => events.stream;

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) async {
    started.add((options.threadId, options.text));
    return const TurnHandle(id: 'turn-1', status: TurnRuntimeStatus.inProgress);
  }

  @override
  Future<String> steerTurn(TurnSteerOptions options) async {
    steered.add(options);
    if (throwOnSteer) {
      throw StateError('Turn already completed');
    }
    if (nextSteerCompleter case final completer?) {
      nextSteerCompleter = null;
      return completer.future;
    }
    return options.expectedTurnId;
  }

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    interrupted.add((threadId, turnId));
  }

  Future<void> dispose() => events.close();
}

class _FakeModelGateway implements ModelGateway {
  @override
  Future<ModelPage> listModels(ModelListQuery query) async =>
      const ModelPage(models: [], nextCursor: null);
}

ThreadSummary _thread({String id = 'thread-1'}) => ThreadSummary(
  id: id,
  sessionId: 'session-$id',
  preview: 'Test thread',
  cwd: '/workspace',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  status: ThreadRuntimeStatus.idle,
  ephemeral: false,
);
