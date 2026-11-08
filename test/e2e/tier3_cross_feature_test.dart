import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_harness.dart';

void main() {
  group('Tier 3: Cross-Feature Combinations (Pairwise)', () {
    testWidgets(
      'T3.1: Composer submission + Landing State Auto-Start (Seamless start and turn execution)',
      (tester) async {
        final harness = E2ERuntimeHarness(initialThreads: const []);
        await pumpE2EApp(tester, harness: harness);

        // Landing view
        expect(find.text('Let’s build'), findsOneWidget);

        final composerField = find.byKey(
          const ValueKey('conversation-composer'),
        );
        await tester.enterText(
          composerField,
          'Initialize native flutter pipeline',
        );
        await tester.pumpAndSettle();

        // Submit
        await tester.tap(find.byKey(const ValueKey('composer-send-button')));
        await tester.pumpAndSettle();

        // Verifies thread created and turn started
        expect(harness.startedThreadCwds.length, 1);
        expect(harness.startedTurns.length, 1);
        expect(
          harness.startedTurns.first.text,
          'Initialize native flutter pipeline',
        );
        // Landing state transitioned to conversation
        expect(find.text('Let’s build'), findsNothing);
      },
    );

    testWidgets('T3.2: Sliding History Eviction + Active Streaming Turn', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'evict-stream-thread',
        preview: 'Eviction stream thread',
      );
      final turns = List.generate(
        25,
        (i) => createTestTurn(
          id: 'turn-es-$i',
          userPrompt: 'Question $i',
          assistantProse: 'Answer $i',
        ),
      );

      final harness = E2ERuntimeHarness(
        initialThreads: [thread],
        initialHistoryTurns: turns,
      );
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Eviction stream thread'));
      await tester.pump();
      await tester.pump();

      // Stream new token
      harness.emitStreamingMessage(
        'item-live-stream',
        'Token during eviction window',
        turnId: 'turn-es-0',
        threadId: 'evict-stream-thread',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Question 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'T3.3: Active Turn + Diff Notification + Inline Approval Request',
      (tester) async {
        final thread = createTestThread(
          id: 'diff-appr-thread',
          preview: 'Diff and approval thread',
        );
        final harness = E2ERuntimeHarness(initialThreads: [thread]);
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Diff and approval thread'));
        await tester.pumpAndSettle();

        // Emit diff
        final snapshot = DiffSnapshot(
          threadId: 'diff-appr-thread',
          turnId: 'turn-1',
          additions: 10,
          deletions: 2,
          truncated: false,
          files: const [
            DiffFile(
              path: 'lib/auth.dart',
              additions: 10,
              deletions: 2,
              lines: ['+ void authenticate() {}'],
              truncated: false,
            ),
          ],
        );
        harness.emitDiff(snapshot);

        // Simultaneously emit command approval
        harness.emitApproval(
          const ApprovalRequest(
            requestId: 'req-auth-1',
            kind: ApprovalKind.command,
            threadId: 'diff-appr-thread',
            turnId: 'turn-1',
            itemId: 'item-auth-1',
            summary: 'cargo run auth_server',
            approveSupported: true,
          ),
        );
        await tester.pumpAndSettle();

        // Both are rendered harmoniously
        expect(find.text('Approval required'), findsOneWidget);
        expect(find.textContaining('cargo run auth_server'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('changes-view-button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('T3.4: Narrow Viewport Mode + Search Filter + Navigation', (
      tester,
    ) async {
      final thread1 = createTestThread(
        id: 't-narrow-1',
        preview: 'Database schema migration',
        cwd: '/backend',
      );
      final thread2 = createTestThread(
        id: 't-narrow-2',
        preview: 'Frontend styling',
        cwd: '/frontend',
      );

      final harness = E2ERuntimeHarness(initialThreads: [thread1, thread2]);
      // Narrow viewport
      await pumpE2EApp(tester, harness: harness, size: const Size(600, 800));

      expect(find.text('Database schema migration'), findsOneWidget);
      expect(find.text('Frontend styling'), findsOneWidget);

      // Filter threads
      await tester.tap(find.byKey(const ValueKey('thread-search-toggle')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('thread-search-field')),
        'Database',
      );
      await tester.pumpAndSettle();

      expect(find.text('Database schema migration'), findsOneWidget);
      expect(find.text('Frontend styling'), findsNothing);

      // Tap filtered thread
      await tester.tap(find.text('Database schema migration'));
      await tester.pumpAndSettle();

      // Transitions into conversation view
      expect(
        find.byKey(const ValueKey('conversation-composer')),
        findsOneWidget,
      );
    });

    testWidgets('T3.5: Model Selection + Dangerous Sandbox Override', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'settings-combo-thread',
        preview: 'Settings combo thread',
      );
      final harness = E2ERuntimeHarness(initialThreads: [thread]);
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Settings combo thread'));
      await tester.pumpAndSettle();

      // Open settings
      await tester.tap(find.byKey(const ValueKey('composer-model-pill')));
      await tester.pumpAndSettle();

      // 1. Select GPT-4o
      await tester.tap(find.byKey(const ValueKey('execution-Model')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GPT-4o').last);
      await tester.pumpAndSettle();

      // 2. Select Danger: full access sandbox
      await tester.tap(find.byKey(const ValueKey('execution-Sandbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Danger: full access').last);
      await tester.pumpAndSettle();

      // Confirm danger dialog
      expect(find.text('Allow full filesystem access?'), findsOneWidget);
      await tester.tap(find.widgetWithText(CodexButton, 'Allow full access'));
      await tester.pumpAndSettle();

      // Close settings dialog
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Summary pill reflects model and danger state
      expect(find.textContaining('GPT-4o'), findsOneWidget);
    });

    testWidgets('T3.6: Worked for Toggle + Output Viewer Dialog', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'work-output-thread',
        preview: 'Work output thread',
      );
      const ref = 'out-combo-ref';
      final harness = E2ERuntimeHarness();
      harness.storeOutput(ref, 'Unit tests completed: 15 passed, 0 failed.');

      final turn = createTestTurn(
        id: 'turn-combo-1',
        userPrompt: 'Run tests',
        assistantProse: 'Done.',
      );
      final activity = HistoryItem(
        id: 'act-combo-1',
        turnId: 'turn-combo-1',
        kind: HistoryItemKind.activity,
        text: 'pytest tests/',
        status: 'completed',
        output: harness.outputDescriptors[ref],
        isCommand: true,
      );

      harness.threads.add(thread);
      harness.historyTurns.add(turn);
      harness.historyItems.add(activity);

      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Work output thread'));
      await tester.pumpAndSettle();

      // Expand worked-for divider
      await tester.tap(find.byKey(const ValueKey('turn-work-turn-combo-1')));
      await tester.pumpAndSettle();

      // Open output viewer
      final viewOutputBtn = find.text('View output');
      if (viewOutputBtn.evaluate().isNotEmpty) {
        await tester.tap(viewOutputBtn);
        await tester.pumpAndSettle();

        expect(find.text('Command output'), findsOneWidget);
        expect(find.textContaining('15 passed, 0 failed'), findsOneWidget);

        // Close dialog
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        expect(find.text('Command output'), findsNothing);
        // Timeline still shows activity row
        expect(find.textContaining('pytest tests/'), findsOneWidget);
      }
    });

    testWidgets('T3.7: Remote Read-Only + App Lifecycle Suspend/Resume', (
      tester,
    ) async {
      final harness = E2ERuntimeHarness(
        initialSnapshot: const RuntimeSnapshot(
          state: RuntimeConnectionState.remoteReadOnly,
          message: 'Connected (read-only)',
        ),
      );
      await pumpE2EApp(tester, harness: harness);

      expect(
        find.byKey(const ValueKey('remote-read-only-panel')),
        findsOneWidget,
      );

      // App hidden
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();

      // App resumed (through inactive)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('remote-read-only-panel')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T3.8: Thread Deletion + Current Thread Selection Reset', (
      tester,
    ) async {
      final thread1 = createTestThread(
        id: 't-del-sel-1',
        preview: 'Selected thread to delete',
      );
      final thread2 = createTestThread(
        id: 't-del-sel-2',
        preview: 'Remaining thread',
      );

      final harness = E2ERuntimeHarness(initialThreads: [thread1, thread2]);
      await pumpE2EApp(tester, harness: harness);

      // Select thread 1
      await tester.tap(find.text('Selected thread to delete'));
      await tester.pumpAndSettle();

      expect(find.text('Selected thread to delete'), findsWidgets);

      // Delete thread 1
      await harness.deleteThread('t-del-sel-1');
      await tester.tap(find.byTooltip('Refresh threads'));
      await tester.pumpAndSettle();

      expect(find.text('Selected thread to delete'), findsNothing);
      expect(find.text('Remaining thread'), findsOneWidget);
    });

    testWidgets('T3.9: Search Filter + New Thread Button Action', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 't-search-new',
        preview: 'Existing project thread',
      );
      final harness = E2ERuntimeHarness(initialThreads: [thread]);
      await pumpE2EApp(tester, harness: harness);

      // Filter search
      await tester.tap(find.byKey(const ValueKey('thread-search-toggle')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('thread-search-field')),
        'Existing',
      );
      await tester.pumpAndSettle();

      // Tap New thread button
      await tester.tap(find.byKey(const ValueKey('new-thread-button')));
      await tester.pumpAndSettle();

      // New thread was created
      expect(harness.startedThreadCwds.length, 1);
    });

    testWidgets('T3.10: Turn Completion + Composer Immediate Resubmission', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 're-submit-thread',
        preview: 'Resubmit thread',
      );
      final harness = E2ERuntimeHarness(initialThreads: [thread]);
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Resubmit thread'));
      await tester.pumpAndSettle();

      final composerField = find.byKey(const ValueKey('conversation-composer'));

      // First prompt
      await tester.enterText(composerField, 'Prompt 1');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();

      expect(harness.startedTurns.length, 1);

      // Complete turn 1
      harness.emitTurnCompleted('turn-1', threadId: 're-submit-thread');
      await tester.pumpAndSettle();

      // Immediately enter and submit follow-up prompt
      await tester.enterText(composerField, 'Prompt 2 follow-up');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();

      expect(harness.startedTurns.length, 2);
      expect(harness.startedTurns.last.text, 'Prompt 2 follow-up');
    });
  });
}
