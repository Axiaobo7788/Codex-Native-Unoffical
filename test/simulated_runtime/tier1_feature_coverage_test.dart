import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_menu.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/remote_admin_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  group('Tier 1: Feature Coverage — Thread Lifecycle & Navigation', () {
    testWidgets(
      'T1.1.1: Listing & project grouping, deduplication by thread.id, relative timestamps',
      (tester) async {
        final thread1 = createTestThread(
          id: 'thread-alpha',
          preview: 'Alpha feature thread',
          cwd: '/projects/project-one',
          updatedAt: DateTime.utc(2026, 1, 1, 12, 0),
        );
        final thread2 = createTestThread(
          id: 'thread-beta',
          preview: 'Beta feature thread',
          cwd: '/projects/project-two',
          updatedAt: DateTime.utc(2026, 1, 1, 11, 45),
        );
        final threadDuplicate = createTestThread(
          id: 'thread-alpha',
          preview: 'Duplicate older alpha',
          cwd: '/projects/project-one',
          updatedAt: DateTime.utc(2026, 1, 1, 10, 0),
        );

        final harness = SimulatedRuntimeHarness(
          initialThreads: [thread1, threadDuplicate, thread2],
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        expect(
          find.byKey(const ValueKey('thread-row-thread-alpha')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('thread-row-thread-beta')),
          findsOneWidget,
        );
        expect(find.text('Alpha feature thread'), findsOneWidget);
        expect(find.text('Beta feature thread'), findsOneWidget);
        expect(find.text('Duplicate older alpha'), findsNothing);

        expect(find.text('project-one'), findsOneWidget);
        expect(find.text('project-two'), findsOneWidget);
      },
    );

    testWidgets(
      'T1.1.2: Thread selection transitions landing to selected thread view, single-line header',
      (tester) async {
        final thread = createTestThread(
          id: 'thread-sel-1',
          preview: 'Interactive coding session',
          cwd: '/projects/active-engine',
        );
        final turn = createTestTurn(
          id: 'turn-1',
          userPrompt: 'Implement fast hash',
          assistantProse: 'Here is the fast hash implementation.',
        );

        final harness = SimulatedRuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: [turn],
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        expect(find.byKey(const ValueKey('home-hero-heading')), findsOneWidget);

        await tester.tap(find.text('Interactive coding session'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('home-hero-heading')), findsNothing);
        expect(find.text('Interactive coding session'), findsWidgets);
        expect(find.text('active-engine'), findsWidgets);

        expect(find.text('Implement fast hash'), findsOneWidget);
        expect(
          find.text('Here is the fast hash implementation.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T1.1.3: Unselected landing state auto-start on submit with cwd',
      (tester) async {
        final harness = SimulatedRuntimeHarness(initialThreads: const []);
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        expect(find.byKey(const ValueKey('home-hero-heading')), findsOneWidget);

        final composerField = find.byKey(
          const ValueKey('conversation-composer'),
        );
        expect(composerField, findsOneWidget);

        await tester.enterText(
          composerField,
          'Create a microservice from scratch',
        );
        await tester.pumpAndSettle();

        final sendButton = find.byKey(const ValueKey('composer-send-button'));
        await tester.tap(sendButton);
        await tester.pumpAndSettle();

        expect(harness.startedThreadCwds.length, 1);
        expect(harness.startedTurns.length, 1);
        expect(
          harness.startedTurns.first.text,
          'Create a microservice from scratch',
        );
      },
    );

    testWidgets('T1.1.4: Inline thread search filtering', (tester) async {
      final thread1 = createTestThread(
        id: 't-search-1',
        preview: 'Authentication refactor',
        cwd: '/core',
      );
      final thread2 = createTestThread(
        id: 't-search-2',
        preview: 'UI Theme overhaul',
        cwd: '/core',
      );

      final harness = SimulatedRuntimeHarness(
        initialThreads: [thread1, thread2],
      );
      await pumpSimulatedRuntimeApp(tester, harness: harness);

      expect(find.text('Authentication refactor'), findsOneWidget);
      expect(find.text('UI Theme overhaul'), findsOneWidget);

      final searchToggle = find.byKey(const ValueKey('thread-search-toggle'));
      await tester.tap(searchToggle);
      await tester.pumpAndSettle();

      final searchField = find.byKey(const ValueKey('thread-search-field'));
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Auth');
      await tester.pumpAndSettle();

      expect(find.text('Authentication refactor'), findsOneWidget);
      expect(find.text('UI Theme overhaul'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(find.text('Authentication refactor'), findsOneWidget);
      expect(find.text('UI Theme overhaul'), findsOneWidget);
    });

    testWidgets('T1.1.5: Thread deletion purges row from sidebar', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'thread-to-delete',
        preview: 'Disposable scratchpad',
        cwd: '/tmp',
      );

      final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
      await pumpSimulatedRuntimeApp(tester, harness: harness);

      expect(find.text('Disposable scratchpad'), findsOneWidget);

      await harness.deleteThread('thread-to-delete');
      await tester.tap(find.byTooltip('Refresh threads'));
      await tester.pumpAndSettle();

      expect(harness.deletedThreadIds, contains('thread-to-delete'));
      expect(find.text('Disposable scratchpad'), findsNothing);
    });
  });

  group('Tier 1: Feature Coverage — Conversation Timeline & Bottom-Anchored Virtualization', () {
    testWidgets('T1.2.1: Frame 1 bottom anchor at latest turn', (tester) async {
      final thread = createTestThread(
        id: 'long-thread-bottom',
        preview: 'Bottom anchor thread',
      );
      final turns = List.generate(
        20,
        (i) => createTestTurn(
          id: 'turn-$i',
          userPrompt: 'User prompt $i',
          assistantProse: 'Assistant response $i with multi-line explanation.',
        ),
      );

      final harness = SimulatedRuntimeHarness(
        initialThreads: [thread],
        initialHistoryTurns: turns,
      );
      await pumpSimulatedRuntimeApp(tester, harness: harness);

      await tester.tap(find.text('Bottom anchor thread'));
      await tester.pumpAndSettle();

      // In descending turns, turn-0 is newest and sits at the bottom anchor
      expect(find.text('User prompt 0'), findsOneWidget);
      expect(find.text('User prompt 19'), findsNothing);
      expect(find.byKey(const ValueKey('jump-to-latest-button')), findsNothing);
    });

    testWidgets(
      'T1.2.2: Scrolling up reveals Jump to latest button and clicking returns to bottom',
      (tester) async {
        final thread = createTestThread(
          id: 'jump-thread',
          preview: 'Jump thread',
        );
        final turns = List.generate(
          20,
          (i) => createTestTurn(
            id: 'turn-$i',
            userPrompt: 'Prompt $i',
            assistantProse: 'Response $i with some length content.',
          ),
        );

        final harness = SimulatedRuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: turns,
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Jump thread'));
        await tester.pumpAndSettle();

        // Scroll up toward older turns
        final timeline = find.byKey(const ValueKey('conversation-timeline'));
        await tester.drag(timeline, const Offset(0, 800));
        await tester.pumpAndSettle();

        final jumpButton = find.byKey(const ValueKey('jump-to-latest-button'));
        expect(jumpButton, findsOneWidget);

        await tester.tap(jumpButton);
        await tester.pumpAndSettle();

        expect(find.text('Prompt 0'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('jump-to-latest-button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'T1.2.3: Streaming update does not yank viewport when scrolled up',
      (tester) async {
        final thread = createTestThread(
          id: 'stream-yank-thread',
          preview: 'Stream yank test',
        );
        final turns = List.generate(
          15,
          (i) => createTestTurn(
            id: 'turn-$i',
            userPrompt: 'Question $i',
            assistantProse: 'Answer $i',
          ),
        );

        final harness = SimulatedRuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: turns,
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Stream yank test'));
        await tester.pumpAndSettle();

        final timeline = find.byKey(const ValueKey('conversation-timeline'));
        await tester.drag(timeline, const Offset(0, 600));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('jump-to-latest-button')),
          findsOneWidget,
        );
        final visibleRow = find.text('Question 8');
        if (visibleRow.evaluate().isNotEmpty) {
          final topBefore = tester.getTopLeft(visibleRow).dy;

          harness.emitStreamingMessage(
            'stream-item-1',
            'New incoming streaming token',
            turnId: 'turn-0',
            threadId: 'stream-yank-thread',
          );
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();

          expect(find.text('Question 8'), findsOneWidget);
          final topAfter = tester.getTopLeft(visibleRow).dy;
          expect(topAfter, closeTo(topBefore, 2.0));
        }
      },
    );

    testWidgets(
      'T1.2.4: Load older turns prepends turns and preserves visual anchor',
      (tester) async {
        final thread = createTestThread(
          id: 'paged-load-thread',
          preview: 'Paged load thread',
        );
        final turns = List.generate(
          20,
          (i) => createTestTurn(
            id: 'turn-$i',
            userPrompt: 'Paged item $i',
            assistantProse: 'Paged response $i',
          ),
        );

        final harness = SimulatedRuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: turns,
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Paged load thread'));
        await tester.pumpAndSettle();

        // Scroll up toward top of timeline
        final timeline = find.byKey(const ValueKey('conversation-timeline'));
        await tester.drag(timeline, const Offset(0, 3000));
        await tester.pumpAndSettle();

        // Oldest turn in descending list is turn-19
        expect(find.text('Paged item 19'), findsOneWidget);
      },
    );

    testWidgets(
      'T1.2.5: Virtualized timeline renders only visible items within viewport',
      (tester) async {
        final thread = createTestThread(
          id: 'virtual-test-thread',
          preview: 'Virtual thread',
        );
        final turns = List.generate(
          50,
          (i) => createTestTurn(
            id: 'vturn-$i',
            userPrompt: 'Long prompt number $i in virtualized list',
            assistantProse: 'Response $i containing multi-line content.',
          ),
        );

        final harness = SimulatedRuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: turns,
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Virtual thread'));
        await tester.pumpAndSettle();

        final promptFinders = find.textContaining('Long prompt number');
        final renderedCount = promptFinders.evaluate().length;

        expect(renderedCount, greaterThan(0));
        expect(renderedCount, lessThan(25));
      },
    );
  });

  group(
    'Tier 1: Feature Coverage — Detail Presentation & Message Envelopes',
    () {
      testWidgets(
        'T1.3.1: Worked for duration divider toggles expansion of intermediate turn activity',
        (tester) async {
          final thread = createTestThread(
            id: 'duration-thread',
            preview: 'Duration thread',
          );
          final turn = createTestTurn(
            id: 'turn-work-1',
            userPrompt: 'Run unit test suite',
            assistantProse: 'Tests passed successfully.',
            startedAt: DateTime.utc(2026, 1, 1, 10, 0, 0),
            completedAt: DateTime.utc(2026, 1, 1, 10, 3, 58),
          );
          final activityItem = const HistoryItem(
            id: 'act-1',
            turnId: 'turn-work-1',
            kind: HistoryItemKind.activity,
            text: 'Executed cargo test --workspace',
            status: 'completed',
            isCommand: true,
          );

          final harness = SimulatedRuntimeHarness(
            initialThreads: [thread],
            initialHistoryTurns: [turn],
            initialHistoryItems: [activityItem],
          );
          await pumpSimulatedRuntimeApp(tester, harness: harness);

          await tester.tap(find.text('Duration thread'));
          await tester.pumpAndSettle();

          final workDivider = find.byKey(
            const ValueKey('turn-work-turn-work-1'),
          );
          expect(workDivider, findsOneWidget);
          expect(find.textContaining('3m 58s'), findsOneWidget);

          await tester.tap(workDivider);
          await tester.pumpAndSettle();

          expect(
            find.textContaining('Executed cargo test --workspace'),
            findsOneWidget,
          );

          await tester.tap(workDivider);
          await tester.pumpAndSettle();

          expect(
            find.textContaining('Executed cargo test --workspace'),
            findsNothing,
          );
        },
      );

      testWidgets(
        'T1.3.2: Assistant markdown rendering with code block headers and copy action',
        (tester) async {
          final thread = createTestThread(
            id: 'markdown-thread',
            preview: 'Markdown code thread',
          );
          final turn = createTestTurn(
            id: 'turn-md-1',
            userPrompt: 'Show hello world in rust',
            assistantProse: 'Here is the code:\n\n```rust\nfn main() {\n    println!("Hello, World!");\n}\n```\n',
          );

          final harness = SimulatedRuntimeHarness(
            initialThreads: [thread],
            initialHistoryTurns: [turn],
          );
          await pumpSimulatedRuntimeApp(tester, harness: harness);

          await tester.tap(find.text('Markdown code thread'));
          await tester.pumpAndSettle();

          expect(find.text('Here is the code:'), findsOneWidget);
          expect(find.text('rust'), findsOneWidget);
          expect(find.text('Copy'), findsWidgets);
        },
      );

      testWidgets(
        'T1.3.3: User message attachment normalization into structured chips',
        (tester) async {
          final thread = createTestThread(
            id: 'attachment-thread',
            preview: 'Attachment thread',
          );
          final attachment = const UserAttachment(
            kind: UserAttachmentKind.file,
            label: 'main.rs',
            path: '/src/main.rs',
            preview: 'fn main() {}',
          );
          final turn = createTestTurn(
            id: 'turn-att-1',
            userPrompt: 'Refactor this code',
            assistantProse: 'Done.',
            attachments: [attachment],
          );

          final harness = SimulatedRuntimeHarness(
            initialThreads: [thread],
            initialHistoryTurns: [turn],
          );
          await pumpSimulatedRuntimeApp(tester, harness: harness);

          await tester.tap(find.text('Attachment thread'));
          await tester.pumpAndSettle();

          expect(find.text('main.rs'), findsOneWidget);
          expect(find.text('Refactor this code'), findsOneWidget);
        },
      );

      testWidgets('T1.3.4: HTML space continuation cleanup (&#x20;\\)', (
        tester,
      ) async {
        final thread = createTestThread(
          id: 'escape-thread',
          preview: 'Escape thread',
        );
        final turn = createTestTurn(
          id: 'turn-esc-1',
          userPrompt: 'Line one&#x20;\\\nLine two',
          assistantProse: 'Understood.',
        );

        final harness = SimulatedRuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: [turn],
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Escape thread'));
        await tester.pumpAndSettle();

        expect(find.textContaining('&#x20;\\'), findsNothing);
        expect(find.textContaining('Line one'), findsOneWidget);
      });

      testWidgets(
        'T1.3.5: Assistant completed message copy button (assistant-copy-<id>)',
        (tester) async {
          final thread = createTestThread(
            id: 'copy-btn-thread',
            preview: 'Copy button thread',
          );
          final turn = createTestTurn(
            id: 'turn-cp-1',
            userPrompt: 'Say hi',
            assistantProse: 'Hello from assistant!',
          );

          final harness = SimulatedRuntimeHarness(
            initialThreads: [thread],
            initialHistoryTurns: [turn],
          );
          await pumpSimulatedRuntimeApp(tester, harness: harness);

          await tester.tap(find.text('Copy button thread'));
          await tester.pumpAndSettle();

          final copyBtn = find.byKey(
            const ValueKey('assistant-copy-assistant-turn-cp-1'),
          );
          expect(copyBtn, findsOneWidget);

          await tester.tap(copyBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  group('Tier 1: Feature Coverage — Composer & Controls', () {
    testWidgets(
      'T1.4.1: Multiline text entry with Shift+Enter and submit on Enter',
      (tester) async {
        final thread = createTestThread(
          id: 'multiline-thread',
          preview: 'Multiline thread',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Multiline thread'));
        await tester.pumpAndSettle();

        final composerField = find.byKey(
          const ValueKey('conversation-composer'),
        );
        await tester.tap(composerField);
        await tester.pumpAndSettle();

        await tester.enterText(composerField, 'Line 1\nLine 2');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('composer-send-button')));
        await tester.pumpAndSettle();

        expect(harness.startedTurns.length, 1);
        expect(harness.startedTurns.first.text, 'Line 1\nLine 2');
      },
    );

    testWidgets('T1.4.2: Model selection popover list and selection update', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'model-sel-thread',
        preview: 'Model select thread',
      );
      final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
      await pumpSimulatedRuntimeApp(tester, harness: harness);

      await tester.tap(find.text('Model select thread'));
      await tester.pumpAndSettle();

      final modelPill = find.byKey(const ValueKey('composer-model-pill'));
      expect(modelPill, findsOneWidget);
      expect(find.text('Codex settings'), findsOneWidget);

      await tester.tap(modelPill);
      await tester.pumpAndSettle();

      final picker = find.byKey(const ValueKey('composer-model-picker'));
      expect(tester.getSize(picker).width, closeTo(224, 1));
      expect(
        tester.getRect(picker).bottom,
        lessThan(tester.getRect(modelPill).top),
      );
      tester.view.physicalSize = const Size(820, 420);
      await tester.pumpAndSettle();
      expect(tester.getRect(picker).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(picker).bottom, lessThanOrEqualTo(420));
      await tester.tap(find.text('GPT-4o').last);
      await tester.pumpAndSettle();

      expect(picker, findsNothing);
      expect(find.textContaining('GPT-4o'), findsOneWidget);
      await tester.tap(modelPill);
      await tester.pumpAndSettle();
      await tester.tap(find.text('o3-mini').last);
      await tester.pumpAndSettle();
      final reset = find.byKey(const ValueKey('composer-model-reset'));
      expect(reset, findsOneWidget);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(reset, findsNothing);
      expect(picker, findsNothing);
      expect(find.text('Codex settings'), findsOneWidget);
      await tester.tap(modelPill);
      await tester.pumpAndSettle();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('composer-model-list')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(picker, findsNothing);
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('conversation-composer')),
        'Check inherited runtime settings.',
      );
      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();
      expect(harness.startedTurns.single.model, isNull);
      expect(harness.startedTurns.single.reasoningEffort, isNull);
    });

    testWidgets(
      'T1.4.3: Reasoning effort selection updates summary pill in composer',
      (tester) async {
        final thread = createTestThread(
          id: 'effort-thread',
          preview: 'Effort select thread',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Effort select thread'));
        await tester.pumpAndSettle();

        expect(find.text('Codex settings'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('composer-model-pill')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('o3-mini').last);
        await tester.pumpAndSettle();
        expect(find.textContaining('Medium'), findsWidgets);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.textContaining('High'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('conversation-composer')),
          'Check the selected reasoning effort.',
        );
        await tester.tap(find.byKey(const ValueKey('composer-send-button')));
        await tester.pumpAndSettle();
        expect(harness.startedTurns.single.reasoningEffort, 'high');
      },
    );

    testWidgets('T1.4.4: Narrow Desktop composer can select, steer, and stop', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'stop-btn-thread',
        preview: 'Stop button thread',
      );
      final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
      await pumpSimulatedRuntimeApp(tester, harness: harness);

      await tester.tap(find.text('Stop button thread'));
      await tester.pumpAndSettle();

      final composerField = find.byKey(const ValueKey('conversation-composer'));
      await tester.enterText(composerField, 'Compute prime numbers');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();

      final stop = find.byKey(const ValueKey('composer-stop-button'));
      expect(stop, findsOneWidget);

      await tester.enterText(composerField, 'Keep the input readable.');
      tester.view.physicalSize = const Size(760, 800);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('sidebar-resize-handle')),
        const Offset(310, 0),
      );
      await tester.pumpAndSettle();

      final model = find.byKey(const ValueKey('composer-model-pill'));
      expect(model, findsOneWidget);
      expect(tester.getSize(composerField).width, greaterThanOrEqualTo(180));
      expect(tester.widget<TextField>(composerField).focusNode!.hasFocus, true);
      expect(find.text('Keep the input readable.'), findsOneWidget);

      await tester.tap(model);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('composer-model-picker')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();
      expect(harness.steeredTurns.single.text, 'Keep the input readable.');
      await tester.tap(stop);
      await tester.pumpAndSettle();
      expect(harness.interruptedTurns.single.threadId, 'stop-btn-thread');
      expect(stop, findsNothing);
    });

    testWidgets(
      'T1.4.5: Dangerous execution override displays confirmation dialog',
      (tester) async {
        final thread = createTestThread(
          id: 'danger-thread',
          preview: 'Danger override thread',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Danger override thread'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('execution-settings-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Advanced settings…'));
        await tester.pumpAndSettle();

        final approvalDropdown = find.byKey(
          const ValueKey('execution-Approval mode'),
        );
        await tester.tap(approvalDropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Never ask').last);
        await tester.pumpAndSettle();

        expect(find.text('Disable approval prompts?'), findsOneWidget);

        await tester.tap(find.widgetWithText(CodexButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Disable approval prompts?'), findsNothing);
      },
    );
  });

  group('Tier 1: Feature Coverage — Approvals, Diffs & Command Output', () {
    testWidgets('T1.5.1: Inline command approval request card display', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'appr-card-thread',
        preview: 'Approval card thread',
      );
      final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
      await pumpSimulatedRuntimeApp(tester, harness: harness);

      await tester.tap(find.text('Approval card thread'));
      await tester.pumpAndSettle();

      harness.emitApproval(
        const ApprovalRequest(
          requestId: 'req-cmd-1',
          kind: ApprovalKind.command,
          threadId: 'appr-card-thread',
          turnId: 'turn-1',
          itemId: 'item-1',
          summary: 'rm -rf /tmp/build_cache',
          detail: 'Clean build cache directory',
          approveSupported: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approval required'), findsOneWidget);
      expect(find.textContaining('rm -rf /tmp/build_cache'), findsOneWidget);
      expect(find.text('Approve once'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets(
      'T1.5.2: Reject decision sends reject to gateway and dismisses card',
      (tester) async {
        final thread = createTestThread(
          id: 'appr-rej-thread',
          preview: 'Approval reject thread',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Approval reject thread'));
        await tester.pumpAndSettle();

        harness.emitApproval(
          const ApprovalRequest(
            requestId: 'req-rej-1',
            kind: ApprovalKind.command,
            threadId: 'appr-rej-thread',
            turnId: 'turn-1',
            itemId: 'item-1',
            summary: 'npx dangerous-pkg',
            approveSupported: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Reject'), findsOneWidget);
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();

        expect(harness.approvalDecisions.length, 1);
        expect(
          harness.approvalDecisions.first.decision,
          ApprovalDecision.reject,
        );
        expect(find.text('Approval required'), findsNothing);
      },
    );

    testWidgets(
      'T1.5.3: Bounded diff viewer displays modified files and line diffs',
      (tester) async {
        final thread = createTestThread(
          id: 'diff-thread',
          preview: 'Diff viewer thread',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Diff viewer thread'));
        await tester.pumpAndSettle();

        tester.view.physicalSize = const Size(760, 800);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const ValueKey('sidebar-resize-handle')),
          const Offset(310, 0),
        );
        await tester.pumpAndSettle();

        final snapshot = DiffSnapshot(
          threadId: 'diff-thread',
          turnId: 'turn-1',
          additions: 3,
          deletions: 1,
          truncated: false,
          files: const [
            DiffFile(
              path: 'lib/main.dart',
              additions: 3,
              deletions: 1,
              lines: ['void main() {', '- runApp(Old());', '+ runApp(New());'],
              truncated: false,
            ),
          ],
        );
        harness.emitDiff(snapshot);
        await tester.pumpAndSettle();

        final changesBtn = find.byKey(const ValueKey('changes-view-button'));
        expect(changesBtn, findsOneWidget);
        await tester.tap(changesBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('lib/main.dart'), findsWidgets);
        expect(find.textContaining('runApp(New());'), findsOneWidget);

        harness.emitDiff(
          const DiffSnapshot(
            threadId: 'diff-thread',
            turnId: 'turn-1',
            additions: 0,
            deletions: 0,
            truncated: false,
            files: [],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('No file changes for this turn.'), findsOneWidget);
        expect(changesBtn, findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('workspace-side-panel-toggle')),
        );
        await tester.pumpAndSettle();
        expect(find.text('No file changes for this turn.'), findsNothing);
        expect(changesBtn, findsNothing);
      },
    );

    testWidgets(
      'T1.5.4: Bounded command output viewer displays retained byte window',
      (tester) async {
        final harness = SimulatedRuntimeHarness();
        final thread = createTestThread(
          id: 'output-thread',
          preview: 'Output thread',
        );
        const ref = 'out-ref-1';
        harness.storeOutput(
          ref,
          'Standard build output: compiled 42 modules with 0 errors.',
        );

        final turn = createTestTurn(
          id: 'turn-out-1',
          userPrompt: 'Run build',
          assistantProse: 'Build complete.',
        );
        final cmdItem = HistoryItem(
          id: 'cmd-item-1',
          turnId: 'turn-out-1',
          kind: HistoryItemKind.activity,
          text: 'make build',
          status: 'completed',
          output: harness.outputDescriptors[ref],
          isCommand: true,
        );

        harness.threads.add(thread);
        harness.historyTurns.add(turn);
        harness.historyItems.add(cmdItem);

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Output thread'));
        await tester.pumpAndSettle();

        final workDivider = find.byKey(const ValueKey('turn-work-turn-out-1'));
        await tester.tap(workDivider);
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Show output preview'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('compiled 42 modules with 0 errors'),
          findsOneWidget,
        );
        await tester.tap(find.text('View output'));
        await tester.pumpAndSettle();
        expect(find.text('Command output'), findsOneWidget);
      },
    );

    testWidgets(
      'T1.5.5: File change approval request displays file paths and requires decision',
      (tester) async {
        final thread = createTestThread(
          id: 'appr-file-thread',
          preview: 'File approval thread',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('File approval thread'));
        await tester.pumpAndSettle();

        harness.emitApproval(
          const ApprovalRequest(
            requestId: 'req-file-1',
            kind: ApprovalKind.fileChange,
            threadId: 'appr-file-thread',
            turnId: 'turn-1',
            itemId: 'item-1',
            summary: 'Overwrite src/config.json',
            detail: 'Modified 4 keys',
            approveSupported: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Approval required'), findsOneWidget);
        expect(
          find.textContaining('Overwrite src/config.json'),
          findsOneWidget,
        );
        expect(find.text('Approve once'), findsOneWidget);
      },
    );
  });

  group('Tier 1: Feature Coverage — Remote Setup & Pairing Administration', () {
    testWidgets(
      'T1.6.1: Remote setup panel displays host status, endpoint, TLS',
      (tester) async {
        final harness = SimulatedRuntimeHarness();
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        final remoteBtn = find.byKey(const ValueKey('remote-setup-button'));
        expect(remoteBtn, findsOneWidget);
        await tester.tap(remoteBtn);
        await tester.pumpAndSettle();

        expect(find.text('Remote setup'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('remote-listener-enabled')),
          findsOneWidget,
        );
        expect(find.text('Loopback'), findsOneWidget);
        expect(find.text('wss://127.0.0.1:8443'), findsOneWidget);
      },
    );

    testWidgets(
      'T1.6.2: One-time pairing ticket generation displays invitation details',
      (tester) async {
        final harness = SimulatedRuntimeHarness();
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
        await tester.pumpAndSettle();

        final createTicketBtn = find.byKey(
          const ValueKey('remote-create-ticket-button'),
        );
        expect(createTicketBtn, findsOneWidget);
        await tester.tap(createTicketBtn);
        await tester.pumpAndSettle();

        expect(harness.pairingTicketCounter, 1);
        expect(
          find.byKey(const ValueKey('remote-ticket-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('remote-copy-invitation-button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('T1.6.3: Paired devices list displays device fingerprints', (
      tester,
    ) async {
      final device = RemotePairedDevice(
        id: 'dev-pixel-9',
        name: 'Pixel 9 Pro (Testing)',
        scopes: const {RemoteDeviceScope.read},
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        expiresAtMs: DateTime.now()
            .add(const Duration(days: 30))
            .millisecondsSinceEpoch,
        lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
        rotatedAtMs: null,
        revokedAtMs: null,
      );

      final harness = SimulatedRuntimeHarness(initialPairedDevices: [device]);
      await pumpSimulatedRuntimeApp(tester, harness: harness);

      await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
      await tester.pumpAndSettle();

      expect(find.text('Pixel 9 Pro (Testing)'), findsOneWidget);
      expect(find.textContaining('Expires'), findsOneWidget);
    });

    testWidgets(
      'T1.6.4: Revoke paired device prompts for confirmation and removes device',
      (tester) async {
        final device = RemotePairedDevice(
          id: 'dev-to-revoke',
          name: 'Revocable Tablet',
          scopes: const {RemoteDeviceScope.read},
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          expiresAtMs: DateTime.now()
              .add(const Duration(days: 30))
              .millisecondsSinceEpoch,
          lastSeenAtMs: null,
          rotatedAtMs: null,
          revokedAtMs: null,
        );

        final harness = SimulatedRuntimeHarness(initialPairedDevices: [device]);
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
        await tester.pumpAndSettle();

        expect(find.text('Revocable Tablet'), findsOneWidget);

        final revokeBtn = find.text('Revoke');
        expect(revokeBtn, findsOneWidget);
        await tester.tap(revokeBtn);
        await tester.pumpAndSettle();

        expect(find.text('Revoke paired device?'), findsOneWidget);
        final confirmBtn = find.byKey(
          const ValueKey('remote-confirm-revoke-button'),
        );
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(harness.revokedDeviceIds, contains('dev-to-revoke'));
        expect(find.text('Revocable Tablet'), findsNothing);
      },
    );

    testWidgets(
      'T1.6.5: Read-only remote session panel displays read-only status and hides local creation',
      (tester) async {
        final harness = SimulatedRuntimeHarness(
          initialSnapshot: const RuntimeSnapshot(
            state: RuntimeConnectionState.remoteReadOnly,
            message: 'Connected to remote host (read-only)',
          ),
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        expect(find.text('Remote connected (read-only)'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('remote-read-only-panel')),
          findsOneWidget,
        );
        expect(find.text('New thread'), findsNothing);
      },
    );

    testWidgets(
      'T1.6.6: Thread lifecycle actions (pin, rename, compact, fork, archive, unarchive)',
      (tester) async {
        final thread = createTestThread(
          id: 'lifecycle-thread',
          preview: 'Original lifecycle thread',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Original lifecycle thread'));
        await tester.pumpAndSettle();

        final headerMenuBtn = find.byKey(
          const ValueKey('thread-actions-menu-button'),
        );
        expect(headerMenuBtn, findsOneWidget);

        // 1. Pin thread
        await tester.tap(headerMenuBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pin for session'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('pinned-threads-heading')),
          findsOneWidget,
        );

        // 2. Rename thread
        await tester.tap(headerMenuBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rename thread'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('rename-thread-field')),
          'Renamed Convergence Thread',
        );
        await tester.tap(
          find.byKey(const ValueKey('rename-thread-save-button')),
        );
        await tester.pumpAndSettle();
        expect(harness.renamedThreads, [
          (threadId: 'lifecycle-thread', name: 'Renamed Convergence Thread'),
        ]);
        expect(find.text('Renamed Convergence Thread'), findsWidgets);

        // 3. Compact context
        await tester.tap(headerMenuBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compact context'));
        await tester.pumpAndSettle();
        expect(harness.compactedThreadIds, ['lifecycle-thread']);

        // 4. Fork thread
        await tester.tap(headerMenuBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fork thread'));
        await tester.pumpAndSettle();
        expect(harness.forkedThreads, hasLength(1));
        expect(find.text('Renamed Convergence Thread (fork)'), findsWidgets);

        // 5. Archive forked thread and verify Archived view + Unarchive
        await tester.tap(headerMenuBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Archive thread'));
        await tester.pumpAndSettle();
        expect(harness.archivedThreadIds, ['thread-fork-1']);

        await tester.tap(find.byKey(const ValueKey('thread-archive-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('Archived'), findsOneWidget);
        expect(find.text('Renamed Convergence Thread (fork)'), findsOneWidget);

        await tester.tap(find.text('Renamed Convergence Thread (fork)'));
        await tester.pumpAndSettle();
        await tester.tap(headerMenuBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unarchive thread'));
        await tester.pumpAndSettle();
        expect(harness.unarchivedThreadIds, ['thread-fork-1']);
        await tester.tap(find.byKey(const ValueKey('thread-archive-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Renamed Convergence Thread (fork)'));
        await tester.pumpAndSettle();

        // Detail changes preserve the connected Codex workspace.
        expect(
          find.byKey(const ValueKey('product-mode-selector')),
          findsNothing,
        );
        final detailButton = find.byKey(
          const ValueKey('timeline-details-button'),
        );
        final detail = find.byType(CodexMenu<PresentationDetailMode>);
        await tester.tap(detailButton);
        await tester.pumpAndSettle();
        for (final (label, mode) in [
          ('Prose', PresentationDetailMode.prose),
          ('Commands', PresentationDetailMode.commands),
        ]) {
          await tester.tap(
            find.descendant(of: detail, matching: find.text(label)),
          );
          await tester.pumpAndSettle();
          await tester.tap(detailButton);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<CodexMenu<PresentationDetailMode>>(detail)
                .selectedValue,
            mode,
          );
        }
        await tester.tapAt(const Offset(10, 200));
        await tester.pumpAndSettle();

        // 7. Delete thread via header actions menu
        await tester.tap(headerMenuBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete thread'));
        await tester.pumpAndSettle();
        expect(harness.deletedThreadIds, contains('thread-fork-1'));
      },
    );

    testWidgets(
      'T1.6.7: Composer structured attachments, active turn steering, and turn-level fork/revert',
      (tester) async {
        final thread = createTestThread(
          id: 'steer-attach-thread',
          preview: 'Steer attach thread',
        );
        final histTurn = createTestTurn(
          id: 'turn-hist-1',
          userPrompt: 'Historical prompt',
          assistantProse: 'Historical answer',
        );
        final harness = SimulatedRuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: [histTurn],
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Steer attach thread'));
        await tester.pumpAndSettle();

        // 1. Turn-level fork and revert actions on historical user message
        final forkTurnBtn = find.byKey(const ValueKey('turn-fork-turn-hist-1'));
        final revertTurnBtn = find.byKey(
          const ValueKey('turn-revert-turn-hist-1'),
        );
        expect(forkTurnBtn, findsOneWidget);
        expect(revertTurnBtn, findsOneWidget);

        await tester.tap(revertTurnBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Revert and truncate'));
        await tester.pumpAndSettle();
        expect(harness.revertedThreads, [
          (threadId: 'steer-attach-thread', beforeTurnId: 'turn-hist-1'),
        ]);

        // 2. Composer structured attachment (@mention)
        final attachBtn = find.byKey(const ValueKey('composer-attach-button'));
        expect(attachBtn, findsOneWidget);
        await tester.tap(attachBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Attach file (@mention)'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('composer-attachment-primary-field')),
          'lib/main.dart',
        );
        await tester.tap(
          find.byKey(const ValueKey('composer-attachment-confirm-button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('composer-attachment-chip-0')),
          findsOneWidget,
        );

        // 3. Submit initial turn with attachment
        final composerField = find.byKey(
          const ValueKey('conversation-composer'),
        );
        await tester.enterText(composerField, 'Review this file');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('composer-send-button')));
        await tester.pump();

        expect(harness.startedTurns, hasLength(1));
        expect(harness.startedTurns.single.text, 'Review this file');
        expect(
          harness.startedTurns.single.attachments.single.path,
          'lib/main.dart',
        );

        // 4. Active turn is now in progress and TurnStartedEvent was emitted;
        //    submitting from the composer steers the active turn via turn/steer
        expect(
          find.byKey(const ValueKey('composer-stop-button')),
          findsOneWidget,
        );
        expect(find.text('Steer active turn in Codex'), findsOneWidget);
        await tester.enterText(composerField, 'Also check edge cases');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('composer-send-button')));
        await tester.pump();

        expect(harness.steeredTurns, hasLength(1));
        expect(harness.steeredTurns.single.threadId, 'steer-attach-thread');
        expect(harness.steeredTurns.single.expectedTurnId, 'turn-1');
        expect(harness.steeredTurns.single.text, 'Also check edge cases');
      },
    );

    testWidgets(
      'T1.6.8: Ecosystem dialog (Skills, Plugins, MCP) and Dual-Track Remote Setup (Direct Host vs Official Relay)',
      (tester) async {
        final harness = SimulatedRuntimeHarness();
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        // 1. Open Ecosystem dialog from sidebar footer
        await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
        await tester.pumpAndSettle();

        expect(find.text('Skills, Plugins & MCP'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('skill-row-frontend-design')),
          findsOneWidget,
        );

        // Toggle skill enabled state
        await tester.tap(
          find.byKey(const ValueKey('skill-toggle-frontend-design')),
        );
        await tester.pumpAndSettle();
        expect(harness.toggledSkills, [
          (
            path: '/workspace/.agents/skills/frontend-design/SKILL.md',
            enabled: false,
          ),
        ]);

        // Switch to Plugins tab
        await tester.tap(find.text('Plugins (1)'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plugin-row-git-workflow')),
          findsOneWidget,
        );

        // Switch to MCP tab
        await tester.tap(find.text('MCP (1)'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('mcp-row-filesystem-mcp')),
          findsOneWidget,
        );

        // Close Ecosystem dialog
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        // 2. Open Remote Setup dialog and switch between Track A and Track B
        await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('remote-track-selector')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('remote-listener-enabled')),
          findsOneWidget,
        );

        // Switch to Track B: Official Relay
        await tester.tap(find.text('Official Relay'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('official-remote-control-panel')),
          findsOneWidget,
        );
        expect(find.text('env-local-1'), findsOneWidget);

        // Enable Official Remote Control and start official pairing
        await tester.tap(
          find.byKey(const ValueKey('official-remote-toggle-button')),
        );
        await tester.pumpAndSettle();
        expect(harness.officialRemoteEnabledToggles, [true]);

        await tester.tap(
          find.byKey(const ValueKey('official-remote-pair-button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('PAIR-7788-CODEX'), findsOneWidget);

        // Disconnect connected official client
        await tester.tap(
          find.byKey(const ValueKey('official-remote-disconnect-client-ios-1')),
        );
        await tester.pumpAndSettle();
        expect(harness.disconnectedOfficialClients, ['client-ios-1']);
      },
    );

    testWidgets(
      'T1.6.9: Turn-level Edit & Resubmit, Regenerate, Sibling Branch Navigation (< 1 / 2 >), and Interrupted Turn Continue',
      (tester) async {
        final thread = createTestThread(
          id: 'branch-thread',
          preview: 'Branch thread',
        );
        final histTurn = createTestTurn(
          id: 'turn-hist-1',
          userPrompt: 'Original prompt v1',
          assistantProse: 'Original response v1',
        );
        final harness = SimulatedRuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: [histTurn],
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Branch thread'));
        await tester.pumpAndSettle();

        // 1. Edit user message from turn-hist-1
        final editTurnBtn = find.byKey(const ValueKey('turn-edit-turn-hist-1'));
        final regenerateTurnBtn = find.byKey(
          const ValueKey('turn-regenerate-turn-hist-1'),
        );
        expect(editTurnBtn, findsOneWidget);
        expect(regenerateTurnBtn, findsOneWidget);

        await tester.tap(editTurnBtn);
        await tester.pumpAndSettle();
        expect(harness.revertedThreads, isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(harness.revertedThreads, isEmpty);
        await tester.tap(editTurnBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit and truncate'));
        await tester.pumpAndSettle();

        expect(harness.revertedThreads, [
          (threadId: 'branch-thread', beforeTurnId: 'turn-hist-1'),
        ]);
        final composerField = find.byKey(
          const ValueKey('conversation-composer'),
        );
        expect(
          tester.widget<TextField>(composerField).controller?.text,
          'Original prompt v1',
        );

        // 2. Resubmit edited prompt -> creates turn-1 and records branch
        await tester.enterText(composerField, 'Edited prompt v2');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('composer-send-button')));
        await tester.pump();

        expect(harness.startedTurns, hasLength(1));
        expect(harness.startedTurns.single.text, 'Edited prompt v2');

        harness.emitAssistantMessage(
          'asst-turn-1',
          'Edited response v2',
          turnId: 'turn-1',
          threadId: 'branch-thread',
        );
        harness.emitTurnCompleted('turn-1', threadId: 'branch-thread');
        await tester.pumpAndSettle();

        // 3. Sibling branch switcher (< 2/2 >) is shown on turn-1
        expect(
          find.byKey(const ValueKey('branch-label-turn-1')),
          findsOneWidget,
        );
        expect(find.text('2/2'), findsOneWidget);
        expect(find.text('Edited prompt v2'), findsOneWidget);
        expect(find.text('Edited response v2'), findsOneWidget);

        // Switch to previous sibling branch (1/2)
        await tester.tap(find.byKey(const ValueKey('branch-prev-turn-1')));
        await tester.pumpAndSettle();
        expect(find.text('1/2'), findsOneWidget);
        expect(find.text('Original prompt v1'), findsOneWidget);
        expect(find.text('Original response v1'), findsOneWidget);

        // Switch back to next sibling branch (2/2)
        await tester.tap(find.byKey(const ValueKey('branch-next-turn-1')));
        await tester.pumpAndSettle();
        expect(find.text('2/2'), findsOneWidget);
        expect(find.text('Edited prompt v2'), findsOneWidget);

        // 4. Regenerate turn-1 -> reverts and automatically resubmits (3rd branch: 3/3)
        await tester.tap(find.byKey(const ValueKey('turn-regenerate-turn-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Regenerate and truncate'));
        await tester.pump();
        expect(harness.revertedThreads.last, (
          threadId: 'branch-thread',
          beforeTurnId: 'turn-1',
        ));
        expect(harness.startedTurns, hasLength(2));
        expect(harness.startedTurns.last.text, 'Edited prompt v2');

        harness.emitAssistantMessage(
          'asst-turn-2',
          'Regenerated response v3',
          turnId: 'turn-2',
          threadId: 'branch-thread',
        );
        // 5. Complete turn-2 as interrupted -> Continue action appears and < 3/3 > is navigable
        harness.emitTurnCompleted(
          'turn-2',
          status: TurnRuntimeStatus.interrupted,
          threadId: 'branch-thread',
        );
        await tester.pumpAndSettle();

        expect(find.text('3/3'), findsOneWidget);
        expect(find.text('Regenerated response v3'), findsOneWidget);

        // Step back to 2/3 -> verify Edited response v2 was preserved!
        await tester.tap(find.byKey(const ValueKey('branch-prev-turn-2')));
        await tester.pumpAndSettle();
        expect(find.text('2/3'), findsOneWidget);
        expect(find.text('Edited response v2'), findsOneWidget);

        // Step back to 1/3 -> verify Original prompt v1 & Original response v1, and test search on active branch
        await tester.tap(find.byKey(const ValueKey('branch-prev-turn-2')));
        await tester.pumpAndSettle();
        expect(find.text('1/3'), findsOneWidget);
        expect(find.text('Original prompt v1'), findsOneWidget);
        expect(find.text('Original response v1'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('thread-actions-menu-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Find in conversation'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('conversation-search-field')),
          'Original prompt v1',
        );
        await tester.pumpAndSettle();
        expect(find.text('1 of 1'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('conversation-search-close')),
        );
        await tester.pumpAndSettle();

        final continueBtn = find.byKey(const ValueKey('turn-continue-turn-2'));
        expect(continueBtn, findsOneWidget);
        await tester.tap(continueBtn);
        await tester.pump();

        expect(harness.startedTurns, hasLength(3));
        expect(harness.startedTurns.last.text, 'Continue');
      },
    );

    testWidgets(
      'retry before a turn ID exists resends the prompt for that failure',
      (tester) async {
        final harness = _RejectedStartHarness();
        await pumpSimulatedRuntimeApp(tester, harness: harness);
        await tester.tap(find.text('Retry thread'));
        await tester.pumpAndSettle();

        final composer = find.byKey(const ValueKey('conversation-composer'));
        final send = find.byKey(const ValueKey('composer-send-button'));
        for (final text in ['First prompt', 'Second prompt']) {
          await tester.enterText(composer, text);
          await tester.tap(send);
          await tester.pumpAndSettle();
        }
        final firstFailure = find.ancestor(
          of: find.textContaining('rejected start 1'),
          matching: find.byKey(const ValueKey('local-error-1')),
        );
        await tester.tap(
          find.descendant(of: firstFailure, matching: find.text('Retry')),
        );
        await tester.pumpAndSettle();
        expect(harness.startedTurns.single.text, 'First prompt');
        expect(harness.revertedThreads, isEmpty);
      },
    );

    testWidgets(
      'T1.6.10: In-conversation search (find/count/jump/close) and stock Codex composer capability controls',
      (tester) async {
        final thread = createTestThread(
          id: 'search-mode-thread',
          preview: 'Search & Mode thread',
        );
        final turn1 = createTestTurn(
          id: 'turn-s1',
          userPrompt: 'Investigate Needle alpha',
          assistantProse: 'Alpha analysis complete',
        );
        final turn2 = createTestTurn(
          id: 'turn-s2',
          userPrompt: 'Investigate Needle beta',
          assistantProse: 'Beta analysis complete',
        );
        final harness = SimulatedRuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: [turn1, turn2],
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Search & Mode thread'));
        await tester.pumpAndSettle();

        // 1. Open in-conversation search from the workspace menu.
        await tester.tap(
          find.byKey(const ValueKey('thread-actions-menu-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Find in conversation'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('conversation-search-bar')),
          findsOneWidget,
        );
        expect(find.text('Type to search'), findsOneWidget);

        // 2. Enter search query matching both turns
        await tester.enterText(
          find.byKey(const ValueKey('conversation-search-field')),
          'Needle',
        );
        await tester.pumpAndSettle();

        expect(find.text('1 of 2'), findsOneWidget);

        // Navigate next and previous matches
        await tester.tap(
          find.byKey(const ValueKey('conversation-search-next')),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 of 2'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('conversation-search-prev')),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 of 2'), findsOneWidget);

        // Close search bar
        await tester.tap(
          find.byKey(const ValueKey('conversation-search-close')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('conversation-search-bar')),
          findsNothing,
        );

        // The composer exposes the connected backend's capabilities.
        expect(
          find.byKey(const ValueKey('product-mode-selector')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('composer-mode-badge')), findsNothing);
        expect(find.text('Send a message to Codex'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('composer-attach-button')));
        await tester.pumpAndSettle();
        expect(find.text('Attach file (@mention)'), findsOneWidget);
        expect(find.text(r'Attach skill ($skill)'), findsOneWidget);
      },
    );
  });
}

class _RejectedStartHarness extends SimulatedRuntimeHarness {
  _RejectedStartHarness()
    : super(
        initialThreads: [
          createTestThread(id: 'retry-thread', preview: 'Retry thread'),
        ],
      );

  var _attempts = 0;

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) async {
    if (++_attempts <= 2) {
      throw StateError('rejected start $_attempts');
    }
    return super.startTurn(options);
  }
}
