import 'dart:async';

import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

class _TelemetryE2EHarness extends SimulatedRuntimeHarness {
  _TelemetryE2EHarness()
    : super(
        initialThreads: [
          createTestThread(
            id: 'active-thread',
            preview: 'Telemetry Test Thread',
          ),
        ],
      );

  final StreamController<TurnEvent> telemetryEvents =
      StreamController<TurnEvent>.broadcast(sync: true);

  @override
  Stream<TurnEvent> get turnEvents => telemetryEvents.stream;

  @override
  Future<void> disposeHarness() async {
    await telemetryEvents.close();
    await super.disposeHarness();
  }
}

void main() {
  group('F10 Live Turn Telemetry & Plan Projection simulated runtime', () {
    testWidgets(
      'renders token usage header pill, live turn plan banner, telemetry notice bar, and activity rows across turn lifecycle',
      (tester) async {
        final harness = _TelemetryE2EHarness();
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Telemetry Test Thread'));
        await tester.pumpAndSettle();

        // Emit live turn plan, token usage, reasoning summary delta, MCP progress, hook lifecycle, model reroute, and warning
        harness.telemetryEvents
          ..add(
            const TurnStartedEvent(
              threadId: 'active-thread',
              turnId: 'turn-live-1',
            ),
          )
          ..add(
            TurnPlanUpdatedEvent(
              plan: const TurnPlanSnapshot(
                threadId: 'active-thread',
                turnId: 'turn-live-1',
                explanation: 'Verify live turn telemetry projection',
                steps: [
                  TurnPlanStepModel(
                    step: 'Parse turn/plan/updated',
                    status: TurnPlanStepStatus.completed,
                  ),
                  TurnPlanStepModel(
                    step: 'Project header token pill',
                    status: TurnPlanStepStatus.inProgress,
                  ),
                  TurnPlanStepModel(
                    step: 'Run widget assertions',
                    status: TurnPlanStepStatus.pending,
                  ),
                ],
              ),
            ),
          )
          ..add(
            ThreadTokenUsageUpdatedEvent(
              usage: const ThreadTokenUsageSnapshot(
                threadId: 'active-thread',
                turnId: 'turn-live-1',
                last: TokenUsageBreakdownModel(
                  inputTokens: 1200,
                  cachedInputTokens: 400,
                  outputTokens: 300,
                  reasoningOutputTokens: 100,
                  totalTokens: 1500,
                ),
                total: TokenUsageBreakdownModel(
                  inputTokens: 10000,
                  cachedInputTokens: 2000,
                  outputTokens: 2800,
                  reasoningOutputTokens: 800,
                  totalTokens: 12800,
                ),
                modelContextWindow: 128000,
              ),
            ),
          )
          ..add(
            const ReasoningSummaryDeltaEvent(
              threadId: 'active-thread',
              turnId: 'turn-live-1',
              itemId: 'reason-item-1',
              summaryIndex: 0,
              delta: 'Evaluating schema invariants',
            ),
          )
          ..add(
            const ActivityEvent(
              threadId: 'active-thread',
              turnId: 'turn-live-1',
              itemId: 'mcp-item-1',
              summary: 'MCP: github/list_pull_requests',
              status: 'inProgress',
              completed: false,
            ),
          )
          ..add(
            const McpToolCallProgressEvent(
              threadId: 'active-thread',
              turnId: 'turn-live-1',
              itemId: 'mcp-item-1',
              message: 'Fetched 8 open PRs',
            ),
          )
          ..add(
            const HookActivityEvent(
              threadId: 'active-thread',
              turnId: 'turn-live-1',
              runId: 'hook-run-9',
              eventName: 'preToolUse',
              handlerType: 'command',
              executionMode: 'sync',
              scope: 'turn',
              status: 'completed',
              completed: true,
              statusMessage: 'Sandbox policy verified',
              durationMs: 24,
            ),
          )
          ..add(
            const ModelReroutedEvent(
              threadId: 'active-thread',
              turnId: 'turn-live-1',
              fromModel: 'gpt-5-codex',
              toModel: 'o3-mini',
              reason: 'highRiskCyberActivity',
            ),
          )
          ..add(
            const TurnWarningEvent(
              threadId: 'active-thread',
              message: 'Approaching weekly usage window.',
            ),
          )
          ..add(
            const TurnCompletedEvent(
              threadId: 'active-thread',
              turnId: 'turn-live-1',
              status: TurnRuntimeStatus.completed,
            ),
          );

        await tester.pumpAndSettle();

        // 1. Header token-usage pill
        expect(
          find.byKey(const ValueKey('thread-token-usage-pill')),
          findsOneWidget,
        );
        expect(find.text('12.8k / 128k tok (10%)'), findsOneWidget);

        // 2. Live turn plan banner & step chips
        expect(
          find.byKey(const ValueKey('conversation-turn-plan-banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Plan (1/3 completed) — Verify live turn telemetry projection',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('turn-plan-step-0')), findsOneWidget);
        expect(find.byKey(const ValueKey('turn-plan-step-1')), findsOneWidget);

        // 3. Telemetry notice bar (model reroute + warning) and dismissal
        expect(
          find.byKey(const ValueKey('conversation-telemetry-notice')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Approaching weekly usage window.'),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('conversation-telemetry-notice-dismiss')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('conversation-telemetry-notice')),
          findsNothing,
        );

        // 4. Dismiss turn plan banner
        await tester.tap(
          find.byKey(const ValueKey('conversation-turn-plan-dismiss')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('conversation-turn-plan-banner')),
          findsNothing,
        );

        // 5. Switch to Execution detail mode to inspect all projected activity rows
        await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Execution'));
        await tester.pumpAndSettle();
        expect(
          find.text('Reasoning: Evaluating schema invariants'),
          findsOneWidget,
        );
        expect(
          find.text('MCP: github/list_pull_requests — Fetched 8 open PRs'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Hook: preToolUse (command) — Sandbox policy verified · 24ms',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
