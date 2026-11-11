import 'dart:async';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_activity_row.dart';
import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/assistant_markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../simulated_runtime/simulated_runtime_harness.dart';

void main() {
  testWidgets(
    'A7 completed turn divider, reasoning Faus.k2/140px body, and flush grouped commands match official 25894 geometry',
    (tester) async {
      final longBody = List.generate(
        18,
        (index) => 'Normalized reasoning paragraph line ${index + 1}.',
      ).join('\n');
      final harness = _A7ParityHarness(
        reasoningText: '**Inspecting local files**\n\n$longBody',
      );
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('A7 parity thread'));
      await tester.pumpAndSettle();

      final divider = find.byKey(const ValueKey('turn-work-a7-turn-1'));
      expect(divider, findsOneWidget);
      expect(find.text('Worked for 4s'), findsOneWidget);

      // Collapsed turn: 4px gap above 1px hairline and 16px rhythm before assistant prose.
      final dividerWidget = find.byType(CodexInlineWorkDivider);
      final hairline = find.descendant(
        of: dividerWidget,
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 1.0,
        ),
      );
      expect(
        tester.getTopLeft(hairline).dy - tester.getBottomLeft(divider).dy,
        4.0,
      );
      expect(
        tester.getTopLeft(find.text('Completed A7 answer.')).dy -
            tester.getBottomLeft(hairline).dy,
        16.0,
      );

      // Keyboard focus + Enter opens turn details without a pill button surface.
      await tester.tap(divider);
      await tester.pumpAndSettle();

      // Completed reasoning shows collapsed "Thought" in 30% ink without literal **bold** heading.
      expect(find.textContaining('Inspecting local files'), findsNothing);
      expect(find.text('Thought'), findsOneWidget);
      final thoughtText = tester.widget<Text>(find.text('Thought'));
      expect(
        thoughtText.style?.color,
        OfficialCodexThemeData.light.activityChildText,
      );
      expect(
        find.byKey(const ValueKey('reasoning-body-scroll-a7-reason-1')),
        findsNothing,
      );

      // Hovering "Thought" promotes ink to primary; clicking expands bounded 140px (8.75rem) scroll body.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.text('Thought')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Thought')).style?.color,
        OfficialCodexThemeData.light.textPrimary,
      );

      await tester.tap(find.text('Thought'));
      await tester.pumpAndSettle();
      final reasoningScroll = find.byKey(
        const ValueKey('reasoning-body-scroll-a7-reason-1'),
      );
      expect(reasoningScroll, findsOneWidget);
      expect(tester.getSize(reasoningScroll).height, 140.0);
      expect(
        find.textContaining(
          'Normalized reasoning paragraph line 1.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Inspecting local files'), findsNothing);

      // Saved command group renders quiet inline header, 0px flush-left child icons, and 4px child spacing.
      final groupHeader = find.text('Read files and ran a command');
      expect(groupHeader, findsOneWidget);
      await tester.tap(groupHeader);
      await tester.pumpAndSettle();

      final groupList = find.byKey(const ValueKey('saved-command-group-items'));
      expect(groupList, findsOneWidget);

      final groupIconLeft = tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(const ValueKey('saved-command-group-a7-cmd-1')),
              matching: find.byIcon(Icons.menu_book_outlined).first,
            ),
          )
          .dx;
      final child1Row = find.descendant(
        of: find.byKey(const ValueKey('a7-cmd-1')),
        matching: find.byType(CodexActivityRow),
      );
      final child2Row = find.descendant(
        of: find.byKey(const ValueKey('a7-cmd-2')),
        matching: find.byType(CodexActivityRow),
      );
      final childIconLeft = tester
          .getTopLeft(
            find.descendant(
              of: child1Row,
              matching: find.byIcon(Icons.menu_book_outlined),
            ),
          )
          .dx;
      expect(childIconLeft, groupIconLeft);
      expect(
        tester.getTopLeft(child2Row).dy - tester.getBottomLeft(child1Row).dy,
        4.0,
      );

      // Inline row click opens command output preview without a separate right-edge 28px icon button.
      await tester.tap(find.text('Read counter.txt'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('command-output-preview-surface')),
        findsOneWidget,
      );
      expect(find.text('one\nthree'), findsOneWidget);

      // Collapsing group disposes active output preview.
      await tester.tap(groupHeader);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('command-output-preview-surface')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'A7 active streaming reasoning strips leading bold heading and heading-only completed reasoning stays non-expandable',
    (tester) async {
      final harness = _A7ParityHarness(reasoningText: '**Heading only**');
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('A7 parity thread'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('turn-work-a7-turn-1')));
      await tester.pumpAndSettle();

      // Heading-only completed reasoning normalizes to empty P via Faus.k2 -> non-expandable Thought row.
      final thoughtHeader = find.ancestor(
        of: find.text('Thought'),
        matching: find.byType(CodexInlineActivityHeader),
      );
      expect(
        tester.widget<CodexInlineActivityHeader>(thoughtHeader).hasDisclosure,
        isFalse,
      );
      expect(find.textContaining('Heading only'), findsNothing);

      // In-conversation search matching the stripped heading reveals raw copyable text as a fallback.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('conversation-search-field')),
        'Heading only',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('conversation-search-count')),
            )
            .data,
        startsWith('1 of 1'),
      );
      expect(find.text('**Heading only**'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('conversation-search-close')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Heading only'), findsNothing);

      if (find
          .byKey(const ValueKey('jump-to-latest-button'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('jump-to-latest-button')));
        await tester.pumpAndSettle();
      }

      // Emit active streaming turn with incomplete '**Plan' then '**Planning**\nStreaming body line'.
      harness.customTurnEvents
        ..add(
          const TurnStartedEvent(threadId: 'a7-thread', turnId: 'a7-live-turn'),
        )
        ..add(
          const ActivityEvent(
            threadId: 'a7-thread',
            turnId: 'a7-live-turn',
            itemId: 'live-reason',
            summary: 'Reasoning',
            status: 'inProgress',
            completed: false,
          ),
        )
        ..add(
          const ReasoningSummaryDeltaEvent(
            threadId: 'a7-thread',
            turnId: 'a7-live-turn',
            itemId: 'live-reason',
            summaryIndex: 0,
            delta: '**Plan',
          ),
        );
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('Thinking'), findsOneWidget);
      expect(find.textContaining('**Plan'), findsNothing);
      expect(
        find.byKey(const ValueKey('reasoning-body-scroll-live-reason')),
        findsNothing,
      );

      harness.customTurnEvents.add(
        const ReasoningSummaryDeltaEvent(
          threadId: 'a7-thread',
          turnId: 'a7-live-turn',
          itemId: 'live-reason',
          summaryIndex: 0,
          delta: 'ning**\n\nStreaming active reasoning detail.',
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('Thinking'), findsOneWidget);
      expect(find.textContaining('Planning'), findsNothing);
      expect(find.text('Streaming active reasoning detail.'), findsOneWidget);

      // Verify 2.0x text scaling produces zero overflow on divider, group, and inline activity rows.
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A7 inline disclosures activate via keyboard Enter and Space', (
    tester,
  ) async {
    var toggled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OfficialCodexThemeProvider(
          data: OfficialCodexThemeData.light,
          child: Scaffold(
            body: CodexInlineActivityHeader(
              label: 'Read fixture.txt',
              leadingIcon: const Icon(Icons.menu_book_outlined),
              hasDisclosure: true,
              isExpanded: false,
              onToggle: () => toggled += 1,
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(toggled, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(toggled, 2);
  });

  testWidgets(
    'A7 saved turns translate official 25894 typed captions, dual-tone ink, NKAf mixed group headers, and Execution raw fallback',
    (tester) async {
      final harness = _A7TypedActivityHarness();
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('A7 typed activity thread'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('turn-work-a7-typed-turn')));
      await tester.pumpAndSettle();

      // Mixed contiguous nominal groupable items collapse into a single NKAf conjunction header.
      const expectedGroupLabel =
          'Used GitHub and Linear integrations, edited a file, read files, '
          'ran a command, searched the web, and read chat terminal';
      expect(find.text(expectedGroupLabel), findsOneWidget);

      // Standalone items break out of groups and render typed 25894 captions/icons/tones.
      expect(
        find.text('Command declined: rm -rf /tmp/scratch'),
        findsOneWidget,
      );
      expect(find.text('File changes declined'), findsOneWidget);
      final declinedIcon = tester.widget<Icon>(
        find.byIcon(Icons.shield_outlined).first,
      );
      expect(declinedIcon.color, OfficialCodexThemeData.light.warning);

      expect(find.text('Stopped sleep 30'), findsOneWidget);
      expect(find.text('Ran false'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Ran false')).style?.color,
        OfficialCodexThemeData.light.danger,
      );
      expect(find.text('Viewed an image'), findsOneWidget);
      expect(find.text('Generated an image'), findsOneWidget);
      expect(find.text('Context compacted'), findsOneWidget);
      expect(find.text('Created agent'), findsOneWidget);

      // Expand the NKAf group and verify child typed captions + dual-tone spans.
      await tester.tap(find.text(expectedGroupLabel));
      await tester.pumpAndSettle();

      expect(find.text('GitHub · List pull requests'), findsOneWidget);
      final githubText = tester.widget<Text>(
        find.text('GitHub · List pull requests'),
      );
      final githubSpan = githubText.textSpan! as TextSpan;
      expect(githubSpan.text, 'GitHub');
      expect(
        (githubSpan.children!.single as TextSpan).style?.color,
        OfficialCodexThemeData.light.activityChildText,
      );

      expect(find.text('Linear · Update issue'), findsOneWidget);
      expect(find.text('Edited a file'), findsOneWidget);
      expect(
        find.text('Searched for ConversationEntry in lib/src'),
        findsOneWidget,
      );
      expect(find.text('Listed files in lib/src/app'), findsOneWidget);
      expect(find.text('Ran dart test'), findsOneWidget);

      final groupList = find.byKey(const ValueKey('saved-command-group-items'));
      await tester.drag(groupList, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(
        find.text('Searched the web for flutter customscrollview'),
        findsOneWidget,
      );
      expect(find.text('Read chat terminal'), findsOneWidget);

      // Switching to Execution mode preserves raw protocol strings ungrouped.
      await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Execution'));
      await tester.pumpAndSettle();

      expect(find.text(expectedGroupLabel), findsNothing);
      expect(
        find.text('MCP: github_mcp/github_list_pull_requests'),
        findsOneWidget,
      );
      expect(find.text('File changes: 1 update(s) (+8 -2)'), findsOneWidget);
      expect(find.text('Tool: read_task_terminal'), findsOneWidget);
      expect(find.text('Collaboration: spawn_agent'), findsOneWidget);
    },
  );

  testWidgets(
    'A7 live turns group contiguous groupable activity with progressive I3PO headers, 224px lazy expansion, output preview lifecycle, and Ctrl+F flatten',
    (tester) async {
      final harness = _A7ParityHarness(reasoningText: 'Brief summary.');
      harness.storeOutput(
        'live-cmd-out',
        'live preview line 1\nlive preview line 2',
      );
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('A7 parity thread'));
      await tester.pumpAndSettle();

      // 1. Singleton live MCP item unwraps (`I3PO.Pq`) with humanized caption + progress badge.
      harness.customTurnEvents
        ..add(
          const TurnStartedEvent(
            threadId: 'a7-thread',
            turnId: 'live-group-turn',
          ),
        )
        ..add(
          const ActivityEvent(
            threadId: 'a7-thread',
            turnId: 'live-group-turn',
            itemId: 'live-mcp-1',
            summary: 'MCP: github/list_pull_requests',
            status: 'inProgress',
            completed: false,
          ),
        )
        ..add(
          const McpToolCallProgressEvent(
            threadId: 'a7-thread',
            turnId: 'live-group-turn',
            itemId: 'live-mcp-1',
            message: 'Fetching page 1',
          ),
        );
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('GitHub · List pull requests'), findsOneWidget);
      expect(find.text('Fetching page 1'), findsOneWidget);

      // 2. Completing MCP and starting a command forms a 2-item active group (`I3PO.U6` -> "Running command").
      harness.customTurnEvents
        ..add(
          const ActivityEvent(
            threadId: 'a7-thread',
            turnId: 'live-group-turn',
            itemId: 'live-mcp-1',
            summary: 'MCP: github/list_pull_requests',
            status: 'completed',
            completed: true,
          ),
        )
        ..add(
          const ActivityEvent(
            threadId: 'a7-thread',
            turnId: 'live-group-turn',
            itemId: 'live-cmd-1',
            summary: 'Command: flutter analyze',
            status: 'inProgress',
            completed: false,
            commandActions: {CommandActionKind.run},
          ),
        );
      await tester.pump(const Duration(milliseconds: 60));

      expect(
        find.byKey(const ValueKey('live-activity-group-live-mcp-1')),
        findsOneWidget,
      );
      expect(find.text('Running command'), findsOneWidget);

      // 3. Complete command (with output) + webSearch + standalone collaboration item closing the group, then finish turn.
      harness.customTurnEvents
        ..add(
          const ActivityEvent(
            threadId: 'a7-thread',
            turnId: 'live-group-turn',
            itemId: 'live-cmd-1',
            summary: 'Command: flutter analyze',
            status: 'completed',
            completed: true,
            commandActions: {CommandActionKind.run},
            commandOutput: OutputDescriptor(
              reference: 'live-cmd-out',
              bytes: 39,
              storedBytes: 39,
              truncated: false,
              available: true,
            ),
          ),
        )
        ..add(
          const ActivityEvent(
            threadId: 'a7-thread',
            turnId: 'live-group-turn',
            itemId: 'live-web-1',
            summary: 'Web search: dart records',
            status: 'completed',
            completed: true,
          ),
        )
        ..add(
          const ActivityEvent(
            threadId: 'a7-thread',
            turnId: 'live-group-turn',
            itemId: 'live-collab-1',
            summary: 'Collaboration: wait',
            status: 'completed',
            completed: true,
          ),
        )
        ..add(
          const TurnCompletedEvent(
            threadId: 'a7-thread',
            turnId: 'live-group-turn',
            status: TurnRuntimeStatus.completed,
          ),
        );
      await tester.pumpAndSettle();

      const liveSummary =
          'Used GitHub integration, ran a command, and searched the web';
      expect(find.text(liveSummary), findsOneWidget);
      expect(find.text('Waited for agent'), findsOneWidget);

      // 4. Expanding live group opens 224px bounded ListView, allows inline command preview, and disposes preview on collapse.
      await tester.tap(find.text(liveSummary));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('live-activity-group-items-live-mcp-1')),
        findsOneWidget,
      );
      expect(find.text('Ran flutter analyze'), findsOneWidget);
      expect(find.text('Searched the web for dart records'), findsOneWidget);

      await tester.tap(find.text('Ran flutter analyze'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('command-output-preview-surface')),
        findsOneWidget,
      );
      expect(
        find.text('live preview line 1\nlive preview line 2'),
        findsOneWidget,
      );

      await tester.tap(find.text(liveSummary));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('command-output-preview-surface')),
        findsNothing,
      );

      // 5. Ctrl+F flattens live groups and matches translated captions.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('conversation-search-field')),
        'List pull requests',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('conversation-search-count')),
            )
            .data,
        startsWith('1 of 1'),
      );
      expect(find.text('GitHub · List pull requests'), findsOneWidget);
    },
  );

  testWidgets(
    'A7 expanded reasoning renders .content-oxuumP Markdown inside 140px scroll, formats live Thought for {elapsed}, and preserves Execution raw fallback',
    (tester) async {
      var fakeNow = DateTime.utc(2026, 4, 15, 12, 0, 0);
      final harness = _A7ParityHarness(
        reasoningText: '''
**Stripped heading**

First reasoning paragraph with `inline_code`.

### Nested section

- Alpha check
- Beta check

Trailing paragraph 1.

Trailing paragraph 2.

Trailing paragraph 3.

Trailing paragraph 4.
''',
      );
      tester.view.physicalSize = const Size(1191, 865);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(harness.disposeHarness);

      await tester.pumpWidget(
        ReasoningClockScope(
          now: () => fakeNow,
          child: CodexNativeApp(runtimeController: harness),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('A7 parity thread'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('turn-work-a7-turn-1')));
      await tester.pumpAndSettle();

      // Saved historical reasoning without observed live duration shows "Thought".
      expect(find.text('Thought'), findsOneWidget);
      await tester.tap(find.text('Thought'));
      await tester.pumpAndSettle();

      final savedScroll = find.byKey(
        const ValueKey('reasoning-body-scroll-a7-reason-1'),
      );
      expect(savedScroll, findsOneWidget);
      expect(tester.getSize(savedScroll).height, 140.0);
      expect(find.byKey(const ValueKey('reasoning-markdown')), findsOneWidget);
      expect(find.text('Stripped heading', findRichText: true), findsNothing);
      expect(find.text('inline_code'), findsOneWidget);
      expect(find.text('Nested section', findRichText: true), findsOneWidget);
      expect(find.text('Alpha check', findRichText: true), findsOneWidget);

      // Execution detail mode preserves raw SelectableText (including stripped heading).
      await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Execution'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reasoning-markdown')), findsNothing);
      expect(find.textContaining('**Stripped heading**'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commands'));
      await tester.pumpAndSettle();

      // Live streaming reasoning records elapsed duration via F9dY.C (>=1s -> "Thought for {elapsed}", <1s -> "Thought").
      harness.customTurnEvents
        ..add(
          const TurnStartedEvent(
            threadId: 'a7-thread',
            turnId: 'live-elapsed-turn',
          ),
        )
        ..add(
          const ActivityEvent(
            threadId: 'a7-thread',
            turnId: 'live-elapsed-turn',
            itemId: 'live-r-4s',
            summary: 'Reasoning: **Plan**\n\nEvaluating `schema` paths.',
            status: 'inProgress',
            completed: false,
          ),
        );
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Thinking'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reasoning-streaming-text')),
        findsOneWidget,
      );

      fakeNow = fakeNow.add(const Duration(milliseconds: 4200));
      harness.customTurnEvents.add(
        const ActivityEvent(
          threadId: 'a7-thread',
          turnId: 'live-elapsed-turn',
          itemId: 'live-r-4s',
          summary: 'Reasoning: **Plan**\n\nEvaluating `schema` paths.',
          status: 'completed',
          completed: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thought for 4s'), findsOneWidget);

      // Sub-second live reasoning (<1s) omits duration ("Thought").
      harness.customTurnEvents.add(
        const ActivityEvent(
          threadId: 'a7-thread',
          turnId: 'live-elapsed-turn',
          itemId: 'live-r-subsec',
          summary: 'Reasoning: Quick check.',
          status: 'inProgress',
          completed: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      fakeNow = fakeNow.add(const Duration(milliseconds: 650));
      harness.customTurnEvents
        ..add(
          const ActivityEvent(
            threadId: 'a7-thread',
            turnId: 'live-elapsed-turn',
            itemId: 'live-r-subsec',
            summary: 'Reasoning: Quick check.',
            status: 'completed',
            completed: true,
          ),
        )
        ..add(
          const TurnCompletedEvent(
            threadId: 'a7-thread',
            turnId: 'live-elapsed-turn',
            status: TurnRuntimeStatus.completed,
          ),
        );
      await tester.pumpAndSettle();
      expect(find.text('Thought for 4s'), findsOneWidget);
      expect(find.text('Thought'), findsWidgets);

      // Expanding the completed live reasoning row renders Markdown pill `schema`.
      await tester.tap(find.text('Thought for 4s'));
      await tester.pumpAndSettle();
      expect(find.text('schema'), findsOneWidget);
    },
  );

  testWidgets(
    'A7 reasoningParts applies official 182735 v1hC.W multi-part first-part emphasis while preserving raw Execution/search and sparse/single-part bodies',
    (tester) async {
      const savedParts = <String>[
        'Plain summary title',
        'First body paragraph.\n\nSecond body paragraph.',
      ];
      final harness = _A7ParityHarness(
        reasoningText: savedParts.join('\n\n'),
        reasoningParts: savedParts,
      );
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('A7 parity thread'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('turn-work-a7-turn-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thought'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reasoning-markdown')), findsOneWidget);
      expect(
        find.textContaining('Plain summary title', findRichText: true),
        findsNothing,
      );
      expect(
        find.text('First body paragraph.', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Second body paragraph.', findRichText: true),
        findsOneWidget,
      );

      // Execution mode keeps unmodified raw text without synthetic **bold** syntax.
      await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Execution'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Plain summary title\n\nFirst body paragraph.\n\nSecond body paragraph.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('**Plain summary title**'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commands'));
      await tester.pumpAndSettle();

      // In-conversation search matching the stripped plain first part reveals unmodified text.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('conversation-search-field')),
        'Plain summary title',
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Plain summary title\n\nFirst body paragraph.\n\nSecond body paragraph.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('conversation-search-close')));
      await tester.pumpAndSettle();

      if (find
          .byKey(const ValueKey('jump-to-latest-button'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('jump-to-latest-button')));
        await tester.pumpAndSettle();
      }

      // Live streaming multipart summary strips plain part[0] and keeps part[1].
      harness.customTurnEvents
        ..add(
          const TurnStartedEvent(
            threadId: 'a7-thread',
            turnId: 'live-parts-turn',
          ),
        )
        ..add(
          const ReasoningSummaryDeltaEvent(
            threadId: 'a7-thread',
            turnId: 'live-parts-turn',
            itemId: 'live-multipart',
            summaryIndex: 0,
            delta: 'Live plain title',
          ),
        )
        ..add(
          const ReasoningSummaryDeltaEvent(
            threadId: 'a7-thread',
            turnId: 'live-parts-turn',
            itemId: 'live-multipart',
            summaryIndex: 1,
            delta: 'Live body paragraph.',
          ),
        );
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('Live plain title'), findsNothing);
      expect(find.text('Live body paragraph.'), findsOneWidget);

      // Empty first part (`['', 'Sparse body...']`) yields `''` under exact
      // `182735.v1hC.W` (`t && n.length !== 0 ? ... : t ?? ""`), keeping the
      // inline `Thought` row non-expandable while Execution preserves raw text.
      harness.customTurnEvents
        ..add(
          const ReasoningItemEvent(
            threadId: 'a7-thread',
            turnId: 'live-parts-turn',
            itemId: 'live-multipart',
            status: 'completed',
            completed: true,
            summaryParts: ['', 'Sparse body without heading.'],
          ),
        )
        ..add(
          const ReasoningItemEvent(
            threadId: 'a7-thread',
            turnId: 'live-parts-turn',
            itemId: 'live-single-part',
            status: 'completed',
            completed: true,
            summaryParts: ['Standalone plain summary.'],
          ),
        )
        ..add(
          const TurnCompletedEvent(
            threadId: 'a7-thread',
            turnId: 'live-parts-turn',
            status: TurnRuntimeStatus.completed,
          ),
        );
      await tester.pumpAndSettle();

      final thoughtHeaders = find.text('Thought');
      expect(thoughtHeaders, findsNWidgets(3));
      final sparseHeader = find.ancestor(
        of: thoughtHeaders.at(1),
        matching: find.byType(CodexInlineActivityHeader),
      );
      expect(
        tester.widget<CodexInlineActivityHeader>(sparseHeader).hasDisclosure,
        isFalse,
      );
      expect(
        find.textContaining('Sparse body without heading.', findRichText: true),
        findsNothing,
      );
      await tester.tap(thoughtHeaders.first);
      await tester.pumpAndSettle();
      expect(
        find.text('Standalone plain summary.', findRichText: true),
        findsOneWidget,
      );

      // Execution mode still exposes unmodified raw text even when part[0] is empty.
      await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Execution'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sparse body without heading.'),
        findsOneWidget,
      );
    },
  );
}

class _A7ParityHarness extends SimulatedRuntimeHarness {
  _A7ParityHarness({
    required String reasoningText,
    List<String> reasoningParts = const [],
  }) : super(
         initialThreads: [
           createTestThread(id: 'a7-thread', preview: 'A7 parity thread'),
         ],
         initialHistoryTurns: [
           HistoryTurn(
             id: 'a7-turn-1',
             status: TurnRuntimeStatus.completed,
             startedAt: DateTime.utc(2026),
             completedAt: DateTime.utc(2026).add(const Duration(seconds: 4)),
             items: const [_user, _assistant],
           ),
         ],
         initialHistoryItems: [
           _user,
           HistoryItem(
             id: 'a7-reason-1',
             turnId: 'a7-turn-1',
             kind: HistoryItemKind.reasoning,
             text: reasoningText,
             reasoningParts: reasoningParts,
             status: 'completed',
           ),
           const HistoryItem(
             id: 'a7-cmd-1',
             turnId: 'a7-turn-1',
             kind: HistoryItemKind.activity,
             text: 'Command: cat counter.txt',
             status: 'completed',
             isCommand: true,
             commandAction: (
               kind: CommandActionKind.read,
               name: 'counter.txt',
               path: 'counter.txt',
               query: null,
             ),
             output: OutputDescriptor(
               reference: 'a7-output-1',
               bytes: 9,
               storedBytes: 9,
               truncated: false,
               available: true,
             ),
           ),
           const HistoryItem(
             id: 'a7-cmd-2',
             turnId: 'a7-turn-1',
             kind: HistoryItemKind.activity,
             text: 'Command: printf ok',
             status: 'completed',
             isCommand: true,
           ),
           _assistant,
         ],
       ) {
    storeOutput('a7-output-1', 'one\nthree');
  }

  final StreamController<TurnEvent> customTurnEvents =
      StreamController<TurnEvent>.broadcast(sync: true);

  @override
  Stream<TurnEvent> get turnEvents => customTurnEvents.stream;

  @override
  Future<void> disposeHarness() async {
    await customTurnEvents.close();
    await super.disposeHarness();
  }

  static const _user = HistoryItem(
    id: 'a7-user-1',
    turnId: 'a7-turn-1',
    kind: HistoryItemKind.user,
    text: 'Inspect local counter fixture.',
  );

  static const _assistant = HistoryItem(
    id: 'a7-assistant-1',
    turnId: 'a7-turn-1',
    kind: HistoryItemKind.assistant,
    text: 'Completed A7 answer.',
  );
}

class _A7TypedActivityHarness extends SimulatedRuntimeHarness {
  _A7TypedActivityHarness()
    : super(
        initialThreads: [
          createTestThread(
            id: 'a7-typed-thread',
            preview: 'A7 typed activity thread',
          ),
        ],
        initialHistoryTurns: [
          HistoryTurn(
            id: 'a7-typed-turn',
            status: TurnRuntimeStatus.completed,
            startedAt: DateTime.utc(2026),
            completedAt: DateTime.utc(2026).add(const Duration(seconds: 9)),
            items: const [_user, _assistant],
          ),
        ],
        initialHistoryItems: const [
          _user,
          HistoryItem(
            id: 'typed-mcp-gh',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'MCP: github_mcp/github_list_pull_requests',
            status: 'completed',
          ),
          HistoryItem(
            id: 'typed-mcp-lin',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'MCP: linear-server/update_issue',
            status: 'completed',
          ),
          HistoryItem(
            id: 'typed-edit-1',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'File changes: 1 update(s) (+8 -2)',
            status: 'completed',
          ),
          HistoryItem(
            id: 'typed-search-1',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'Command: rg ConversationEntry lib/src',
            status: 'completed',
            isCommand: true,
            commandAction: (
              kind: CommandActionKind.search,
              name: null,
              path: 'lib/src',
              query: 'ConversationEntry',
            ),
          ),
          HistoryItem(
            id: 'typed-list-1',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'Command: ls lib/src/app',
            status: 'completed',
            isCommand: true,
            commandAction: (
              kind: CommandActionKind.listFiles,
              name: null,
              path: 'lib/src/app',
              query: null,
            ),
          ),
          HistoryItem(
            id: 'typed-run-1',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'Command: dart test',
            status: 'completed',
            isCommand: true,
          ),
          HistoryItem(
            id: 'typed-web-1',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'Web search: flutter customscrollview',
            status: 'completed',
          ),
          HistoryItem(
            id: 'typed-dyn-1',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'Tool: read_task_terminal',
            status: 'completed',
          ),
          HistoryItem(
            id: 'typed-declined-1',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'Command: rm -rf /tmp/scratch',
            status: 'declined',
            isCommand: true,
          ),
          HistoryItem(
            id: 'typed-patch-declined-1',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'File changes: 1 update(s) (+2 -1)',
            status: 'declined',
          ),
          HistoryItem(
            id: 'typed-stopped-1',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'Command: sleep 30',
            status: 'interrupted',
            isCommand: true,
          ),
          HistoryItem(
            id: 'typed-failed-1',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'Command: false',
            status: 'failed',
            isCommand: true,
          ),
          HistoryItem(
            id: 'typed-img-view',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.unknown,
            text: 'Image view',
            status: 'completed',
          ),
          HistoryItem(
            id: 'typed-img-gen',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.unknown,
            text: 'Image generation',
            status: 'completed',
          ),
          HistoryItem(
            id: 'typed-compact',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'Context compacted',
            status: 'completed',
          ),
          HistoryItem(
            id: 'typed-collab',
            turnId: 'a7-typed-turn',
            kind: HistoryItemKind.activity,
            text: 'Collaboration: spawn_agent',
            status: 'completed',
          ),
          _assistant,
        ],
      );

  static const _user = HistoryItem(
    id: 'typed-user',
    turnId: 'a7-typed-turn',
    kind: HistoryItemKind.user,
    text: 'Exercise all A7 typed activity surfaces.',
  );

  static const _assistant = HistoryItem(
    id: 'typed-assistant',
    turnId: 'a7-typed-turn',
    kind: HistoryItemKind.assistant,
    text: 'All typed activity items completed.',
  );
}
