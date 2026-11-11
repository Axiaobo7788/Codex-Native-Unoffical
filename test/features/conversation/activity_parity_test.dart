import 'dart:async';

import 'package:codex_native_unofficial/src/app/primitives/codex_activity_row.dart';
import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
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
        find.textContaining('Normalized reasoning paragraph line 1.'),
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
}

class _A7ParityHarness extends SimulatedRuntimeHarness {
  _A7ParityHarness({required String reasoningText})
    : super(
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
