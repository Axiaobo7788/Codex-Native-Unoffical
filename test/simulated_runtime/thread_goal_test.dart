import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets('loads a saved goal only after selecting its thread', (
    tester,
  ) async {
    final harness = _GoalHarness()
      ..goal = const ThreadGoal(
        objective: 'Persisted objective',
        status: ThreadGoalStatus.paused,
        createdAtSeconds: 1,
        updatedAtSeconds: 1,
        tokensUsed: 0,
        timeUsedSeconds: 3661,
      );
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    final badge = find.byKey(const ValueKey('thread-goal-badge-goal-thread'));
    final strip = find.byKey(const ValueKey('desktop-thread-goal-strip'));
    expect(badge, findsNothing);
    expect(strip, findsNothing);
    expect(harness.goalReads, 0);
    await tester.tap(find.text('Goal thread'));
    await tester.pumpAndSettle();
    expect(badge, findsNothing);
    expect(harness.goalReads, 1);
    expect(
      find.textContaining(
        'Paused goal  Persisted objective',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('1h 1m 1s'), findsOneWidget);
    final composer = find.byKey(const ValueKey('floating_composer'));
    expect(
      tester.getRect(strip).bottom,
      lessThan(tester.getRect(composer).top),
    );
  });

  testWidgets('manages a local goal and confirms clearing it', (tester) async {
    final harness = _GoalHarness();
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    await tester.tap(find.text('Goal thread'));
    await tester.pumpAndSettle();

    Future<void> openGoal() async {
      await tester.tap(find.byKey(const ValueKey('thread-menu-goal-thread')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage goal…'));
      await tester.pumpAndSettle();
    }

    await openGoal();
    expect(find.text('New goal'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('thread-goal-objective')),
      'Validate the feature',
    );
    await tester.pump();
    await tester.tap(find.text('Create paused goal'));
    await tester.pumpAndSettle();
    expect(harness.goal?.objective, 'Validate the feature');
    expect(harness.goal?.status, ThreadGoalStatus.paused);

    await tester.tap(find.byTooltip('Edit goal'));
    await tester.pumpAndSettle();
    expect(find.text('Edit goal'), findsOneWidget);
    expect(find.text('Validate the feature'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final readsBeforeQuickActions = harness.goalReads;
    await tester.tap(find.byTooltip('Resume goal'));
    await tester.pumpAndSettle();
    expect(harness.goal?.status, ThreadGoalStatus.active);

    await tester.tap(find.byTooltip('Pause goal'));
    await tester.pumpAndSettle();
    expect(harness.goal?.status, ThreadGoalStatus.paused);

    await tester.tap(find.byTooltip('Clear goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(harness.goal, isNotNull);

    await tester.tap(find.byTooltip('Clear goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear goal'));
    await tester.pumpAndSettle();
    expect(harness.goal, isNull);
    expect(harness.goalReads, readsBeforeQuickActions);
    expect(
      find.byKey(const ValueKey('desktop-thread-goal-strip')),
      findsNothing,
    );
  });
}

class _GoalHarness extends SimulatedRuntimeHarness {
  _GoalHarness()
    : super(
        initialThreads: [
          createTestThread(id: 'goal-thread', preview: 'Goal thread'),
        ],
      );

  ThreadGoal? goal;
  var goalReads = 0;

  @override
  bool get supportsThreadGoals => true;

  @override
  Future<ThreadGoal?> readThreadGoal(String threadId) async {
    goalReads += 1;
    return goal;
  }

  @override
  Future<ThreadGoal> setThreadGoal(
    String threadId, {
    String? objective,
    ThreadGoalStatus? status,
  }) async => goal = ThreadGoal(
    objective: objective ?? goal!.objective,
    status: status ?? goal!.status,
    createdAtSeconds: 1,
    updatedAtSeconds: 1,
    tokensUsed: 0,
    timeUsedSeconds: 0,
  );

  @override
  Future<bool> clearThreadGoal(String threadId) async {
    goal = null;
    return true;
  }
}
