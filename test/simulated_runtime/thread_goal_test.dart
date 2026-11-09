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
        timeUsedSeconds: 0,
      );
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    final badge = find.byKey(const ValueKey('thread-goal-badge-goal-thread'));
    expect(badge, findsNothing);
    await tester.tap(find.text('Goal thread'));
    await tester.pumpAndSettle();
    expect(badge, findsOneWidget);
    expect(find.text('Persisted objective'), findsOneWidget);
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

    await openGoal();
    await tester.tap(find.text('Resume goal'));
    await tester.pumpAndSettle();
    expect(harness.goal?.status, ThreadGoalStatus.active);

    await openGoal();
    await tester.tap(find.text('Pause goal'));
    await tester.pumpAndSettle();
    expect(harness.goal?.status, ThreadGoalStatus.paused);

    await openGoal();
    await tester.tap(find.text('Clear goal…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(harness.goal, isNotNull);

    await openGoal();
    await tester.tap(find.text('Clear goal…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear goal'));
    await tester.pumpAndSettle();
    expect(harness.goal, isNull);
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

  @override
  bool get supportsThreadGoals => true;

  @override
  Future<ThreadGoal?> readThreadGoal(String threadId) async => goal;

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
