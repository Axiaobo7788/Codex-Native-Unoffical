import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final stripRect = tester.getRect(strip);
    final composerRect = tester.getRect(composer);
    expect(stripRect.bottom, lessThan(composerRect.top));
    expect(stripRect.left - composerRect.left, 13);
    expect(composerRect.right - stripRect.right, 13);
  });

  testWidgets('switching to Changes preserves only the current Goal draft', (
    tester,
  ) async {
    final harness = _GoalHarness()
      ..goal = const ThreadGoal(
        objective: 'Saved objective',
        status: ThreadGoalStatus.paused,
        createdAtSeconds: 1,
        updatedAtSeconds: 1,
        tokensUsed: 0,
        timeUsedSeconds: 1,
      )
      ..threads.add(createTestThread(id: 'other', preview: 'Other thread'));
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    await tester.tap(find.text('Goal thread'));
    await tester.pumpAndSettle();
    harness.emitDiff(
      const DiffSnapshot(
        threadId: 'goal-thread',
        turnId: 'fixture-turn',
        files: [
          DiffFile(
            path: 'notes.md',
            additions: 1,
            deletions: 0,
            lines: ['+Fixture'],
            truncated: false,
          ),
        ],
        additions: 1,
        deletions: 0,
        truncated: false,
      ),
    );
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('desktop-thread-goal-title'));
    final editor = find.byKey(const ValueKey('desktop-goal-editor-objective'));
    final changes = find.byKey(const ValueKey('changes-view-button'));
    await tester.tap(title);
    await tester.pumpAndSettle();
    await tester.enterText(editor, 'Unsaved objective');
    await tester.pump();
    await tester.tap(changes);
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
    expect(find.byKey(const ValueKey('desktop-changes-pane')), findsOneWidget);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(editor).controller!.text,
      'Unsaved objective',
    );
    final panelToggle = find.byKey(
      const ValueKey('workspace-side-panel-toggle'),
    );
    await tester.tap(panelToggle);
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
    await tester.tap(panelToggle);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(editor).controller!.text,
      'Unsaved objective',
    );
    expect(harness.goal?.objective, 'Saved objective');
    await tester.tap(find.byTooltip('Close goal editor'));
    await tester.pumpAndSettle();
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(editor).controller!.text,
      'Saved objective',
    );

    await tester.enterText(editor, 'Another unsaved objective');
    await tester.pump();
    await tester.tap(changes);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other thread'));
    await tester.pumpAndSettle();
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(editor).controller!.text,
      'Saved objective',
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
    final editor = find.byKey(const ValueKey('desktop-goal-editor-objective'));
    await tester.enterText(editor, 'Draft objective');
    await tester.pump();
    tester.view.physicalSize = const Size(950, 865);
    await tester.pumpAndSettle();
    expect(find.text('Draft objective'), findsOneWidget);
    tester.view.physicalSize = const Size(1191, 865);
    await tester.pumpAndSettle();
    expect(find.text('Draft objective'), findsOneWidget);
    final composer = find.byKey(const ValueKey('floating_composer'));
    expect(
      tester.getRect(editor).left,
      greaterThan(tester.getRect(composer).right),
    );
    await tester.tap(find.byTooltip('Revert goal draft'));
    await tester.pumpAndSettle();
    expect(find.text('Validate the feature'), findsOneWidget);
    await tester.enterText(editor, 'Validated goal');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(harness.goal?.objective, 'Validated goal');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
    await tester.tap(find.byKey(const ValueKey('desktop-thread-goal-title')));
    await tester.pumpAndSettle();
    expect(editor, findsOneWidget);
    await tester.tap(find.byTooltip('Edit goal'));
    await tester.pumpAndSettle();
    expect(editor, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(editor, findsNothing);

    final readsBeforeQuickActions = harness.goalReads;
    expect(readsBeforeQuickActions, 2);
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
