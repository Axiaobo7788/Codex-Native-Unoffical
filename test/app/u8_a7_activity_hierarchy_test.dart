import 'dart:async';

import 'package:codex_native_unofficial/src/app/primitives/codex_activity_row.dart';
import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../simulated_runtime/simulated_runtime_harness.dart';

void main() {
  testWidgets(
    'U8 A7 saved interrupted/failed turns group boundary-proven runs while keeping page-clipped tails flat',
    (tester) async {
      final harness = _NonCompletedGroupingHarness();
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('U8 interrupted grouping thread'));
      await tester.pumpAndSettle();

      // Expand the interrupted turn's details: 2 completed exploration commands
      // precede an interrupted command boundary, so they group cleanly into
      // "Read files" while the interrupted command remains standalone.
      await tester.tap(
        find.byKey(const ValueKey('turn-work-u8-interrupted-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('saved-command-group-int-read-1')),
        findsOneWidget,
      );
      expect(find.text('Read files'), findsOneWidget);
      expect(find.text('Stopped sleep 30', findRichText: true), findsOneWidget);

      // Expand the clipped-tail failed turn: 2 exploration commands sit at the
      // end of the loaded item page with NO following same-turn boundary item,
      // so they stay flat rather than implying a bounded group count.
      await tester.tap(find.byKey(const ValueKey('turn-work-u8-clipped-2')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('saved-command-group-clip-read-1')),
        findsNothing,
      );
      expect(find.text('Read a.dart', findRichText: true), findsOneWidget);
      expect(find.text('Read b.dart', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'U8 A7 grouped and standalone saved/live Shell cards forward numeric exitCode from HistoryItem and ConversationEntry',
    (tester) async {
      final harness = _ExitCodeForwardingHarness();
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('U8 shell exitCode thread'));
      await tester.pumpAndSettle();

      // Saved turn: expand turn details -> standalone failed command with
      // output descriptor (where descriptor.exitCode is null and HistoryItem.exitCode == 2).
      await tester.tap(find.byKey(const ValueKey('turn-work-u8-exit-saved')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ran false', findRichText: true));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('command-output-preview-surface')),
        findsOneWidget,
      );
      expect(find.text('Exit code 2'), findsOneWidget);

      // Expand saved command group and open grouped command output -> Success (exitCode 0).
      await tester.tap(
        find.byKey(const ValueKey('saved-command-group-exit-grp-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ran printf grouped-ok', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('Success'), findsOneWidget);

      // Stream a live turn with a grouped command (exitCode 0) and a standalone
      // failed command (exitCode 7) whose OutputDescriptor omits exitCode.
      harness.customTurnEvents.add(
        const TurnStartedEvent(
          threadId: 'u8-exit-thread',
          turnId: 'u8-exit-live',
        ),
      );
      harness.customTurnEvents.add(
        const ActivityEvent(
          threadId: 'u8-exit-thread',
          turnId: 'u8-exit-live',
          itemId: 'live-grp-1',
          summary: 'Command: cat README.md',
          status: 'completed',
          completed: true,
          exitCode: 0,
          commandActions: {CommandActionKind.read},
        ),
      );
      harness.customTurnEvents.add(
        const ActivityEvent(
          threadId: 'u8-exit-thread',
          turnId: 'u8-exit-live',
          itemId: 'live-grp-2',
          summary: 'Command: printf live-grouped',
          status: 'completed',
          completed: true,
          exitCode: 0,
          commandOutput: OutputDescriptor(
            reference: 'u8-live-grp-out',
            bytes: 12,
            storedBytes: 12,
            truncated: false,
            available: true,
          ),
        ),
      );
      harness.customTurnEvents.add(
        const ActivityEvent(
          threadId: 'u8-exit-thread',
          turnId: 'u8-exit-live',
          itemId: 'live-fail-7',
          summary: 'Command: cargo check',
          status: 'failed',
          completed: true,
          exitCode: 7,
          commandOutput: OutputDescriptor(
            reference: 'u8-live-fail-out',
            bytes: 14,
            storedBytes: 14,
            truncated: false,
            available: true,
          ),
        ),
      );
      harness.customTurnEvents.add(
        const TurnCompletedEvent(
          threadId: 'u8-exit-thread',
          turnId: 'u8-exit-live',
          status: TurnRuntimeStatus.failed,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ran cargo check', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('Exit code 7'), findsOneWidget);
    },
  );

  testWidgets(
    'U8 A7 fileChange rows render per-item +A -D stats while withholding turn-aggregate diff disclosure pending per-item seam',
    (tester) async {
      final harness = _PatchAndNonShellHarness();
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('U8 A7 non-shell thread'));
      await tester.pumpAndSettle();

      // Emit a live turn with grouped exploration + fileChange (+12 -3) and matching TurnDiffUpdatedEvent.
      harness.customTurnEvents.add(
        const TurnStartedEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-live-patch-turn',
        ),
      );
      harness.customTurnEvents.add(
        const ActivityEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-live-patch-turn',
          itemId: 'lp-read-1',
          summary: 'Command: cat lib/main.dart',
          status: 'completed',
          completed: true,
          commandActions: {CommandActionKind.read},
        ),
      );
      harness.customTurnEvents.add(
        const ActivityEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-live-patch-turn',
          itemId: 'lp-edit-1',
          summary: 'File changes: 1 update(s) (+12 -3)',
          status: 'completed',
          completed: true,
        ),
      );
      final diffLines = <String>[
        '@@ -1,4 +1,13 @@',
        '-final oldFlag = false;',
        '-final legacyCount = 1;',
        '-final staleLabel = "old";',
        for (var i = 1; i <= 24; i++) '+final line$i = $i;',
      ];
      harness.customTurnEvents.add(
        TurnDiffUpdatedEvent(
          snapshot: DiffSnapshot(
            threadId: 'u8-nonshell-thread',
            turnId: 'u8-live-patch-turn',
            additions: 12,
            deletions: 3,
            truncated: false,
            files: [
              DiffFile(
                path: 'lib/main.dart',
                additions: 12,
                deletions: 3,
                lines: diffLines,
                truncated: false,
              ),
            ],
          ),
        ),
      );
      harness.customTurnEvents.add(
        const AssistantTextDeltaEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-live-patch-turn',
          itemId: 'lp-assistant-1',
          delta: 'Applied patch.',
        ),
      );
      harness.customTurnEvents.add(
        const AssistantMessageEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-live-patch-turn',
          itemId: 'lp-assistant-1',
          text: 'Applied patch.',
          completed: true,
        ),
      );
      harness.customTurnEvents.add(
        const TurnCompletedEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-live-patch-turn',
          status: TurnRuntimeStatus.completed,
        ),
      );
      await tester.pumpAndSettle();

      // Expand the live activity group ("Edited a file and read files").
      expect(find.text('Edited a file and read files'), findsOneWidget);
      await tester.tap(find.text('Edited a file and read files'));
      await tester.pumpAndSettle();

      // Inline +12 -3 diff stats accessory is rendered on the Edited a file row.
      final statsAccessory = find.byType(CodexInlineDiffStatsAccessory);
      expect(statsAccessory, findsOneWidget);
      final plusTwelve = find.descendant(
        of: statsAccessory,
        matching: find.text('+12'),
      );
      final minusThree = find.descendant(
        of: statsAccessory,
        matching: find.text('-3'),
      );
      expect(plusTwelve, findsOneWidget);
      expect(minusThree, findsOneWidget);
      expect(
        tester.widget<Text>(plusTwelve).style?.color,
        OfficialCodexThemeData.light.diffAddedText,
      );
      expect(
        tester.widget<Text>(minusThree).style?.color,
        OfficialCodexThemeData.light.diffRemovedText,
      );

      // Even when TurnDiffUpdated carries identical +12 -3 stats, turn-aggregate
      // diffs are never presented as per-item fileChange content.
      final liveEditHeader = tester.widget<CodexInlineActivityHeader>(
        find.ancestor(
          of: plusTwelve,
          matching: find.byType(CodexInlineActivityHeader),
        ),
      );
      expect(liveEditHeader.hasDisclosure, isFalse);
      await tester.tap(find.text('Edited a file'));
      await tester.pumpAndSettle();
      expect(find.byType(CodexInlinePatchPreviewCard), findsNothing);

      // Saved turn with a DIFFERENT turnId ('u8-saved-nonshell') shows +4 -1
      // stats from HistoryItem text but does NOT expose stale patch disclosure
      // from 'u8-live-patch-turn'.
      await tester.tap(
        find.byKey(const ValueKey('turn-work-u8-saved-nonshell')),
      );
      await tester.pumpAndSettle();
      expect(find.text('+4'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      final savedEditHeader = tester.widget<CodexInlineActivityHeader>(
        find.ancestor(
          of: find.text('+4'),
          matching: find.byType(CodexInlineActivityHeader),
        ),
      );
      expect(savedEditHeader.hasDisclosure, isFalse);

      // Collapse saved work block so the next live turn stays cleanly visible.
      await tester.tap(
        find.byKey(const ValueKey('turn-work-u8-saved-nonshell')),
      );
      await tester.pumpAndSettle();

      // Multi-fileChange-item turn with aggregate TurnDiffUpdated (A + B)
      // keeps per-item +A -D stats truthful without falsely attributing the
      // two-file turn diff to either single-file row.
      harness.customTurnEvents.add(
        const TurnStartedEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-multi-patch-turn',
        ),
      );
      harness.customTurnEvents.add(
        const ActivityEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-multi-patch-turn',
          itemId: 'mp-edit-a',
          summary: 'File changes: 1 update(s) (+2 -0)',
          status: 'completed',
          completed: true,
        ),
      );
      harness.customTurnEvents.add(
        const ActivityEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-multi-patch-turn',
          itemId: 'mp-edit-b',
          summary: 'File changes: 1 update(s) (+3 -1)',
          status: 'completed',
          completed: true,
        ),
      );
      harness.customTurnEvents.add(
        TurnDiffUpdatedEvent(
          snapshot: DiffSnapshot(
            threadId: 'u8-nonshell-thread',
            turnId: 'u8-multi-patch-turn',
            additions: 5,
            deletions: 1,
            truncated: false,
            files: [
              DiffFile(
                path: 'lib/a.dart',
                additions: 2,
                deletions: 0,
                lines: ['+final a = 1;', '+final a2 = 2;'],
                truncated: false,
              ),
              DiffFile(
                path: 'lib/b.dart',
                additions: 3,
                deletions: 1,
                lines: ['-old', '+b1', '+b2', '+b3'],
                truncated: false,
              ),
            ],
          ),
        ),
      );
      harness.customTurnEvents.add(
        const AssistantMessageEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-multi-patch-turn',
          itemId: 'mp-assistant-1',
          text: 'Applied two file edits.',
          completed: true,
        ),
      );
      harness.customTurnEvents.add(
        const TurnCompletedEvent(
          threadId: 'u8-nonshell-thread',
          turnId: 'u8-multi-patch-turn',
          status: TurnRuntimeStatus.completed,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Edited files'));
      await tester.tap(find.text('Edited files'));
      await tester.pumpAndSettle();
      final multiEditHeaderA = tester.widget<CodexInlineActivityHeader>(
        find.ancestor(
          of: find.descendant(
            of: find.byType(CodexInlineDiffStatsAccessory),
            matching: find.text('+2'),
          ),
          matching: find.byType(CodexInlineActivityHeader),
        ),
      );
      final multiEditHeaderB = tester.widget<CodexInlineActivityHeader>(
        find.ancestor(
          of: find.descendant(
            of: find.byType(CodexInlineDiffStatsAccessory),
            matching: find.text('+3'),
          ),
          matching: find.byType(CodexInlineActivityHeader),
        ),
      );
      expect(multiEditHeaderA.hasDisclosure, isFalse);
      expect(multiEditHeaderB.hasDisclosure, isFalse);
      expect(find.byType(CodexInlinePatchPreviewCard), findsNothing);
    },
  );

  testWidgets(
    'U8 A7 webSearch site: formatting, YoMb/collab dual-tone spans, Model rerouted humanization, Execution raw preservation, and 2.0x text scale',
    (tester) async {
      final harness = _PatchAndNonShellHarness();
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('U8 A7 non-shell thread'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('turn-work-u8-saved-nonshell')),
      );
      await tester.pumpAndSettle();

      // 1. Web search gtGM.Q site: extraction + YoMb.B dual-tone split
      // ("Searched the web" in 60% summary ink, " for customscrollview | docs.flutter.dev · api.flutter.dev" in 30% child ink).
      const expectedWebCaption =
          'Searched the web for customscrollview | docs.flutter.dev · api.flutter.dev';
      final webFinder = find.text(expectedWebCaption);
      expect(webFinder, findsOneWidget);
      final webText = tester.widget<Text>(webFinder);
      expect(
        webText.style?.color,
        OfficialCodexThemeData.light.activitySummaryText,
      );
      final webRootSpan = webText.textSpan! as TextSpan;
      expect(webRootSpan.text, 'Searched the web');
      final webDetailSpan = webRootSpan.children!.single as TextSpan;
      expect(
        webDetailSpan.text,
        ' for customscrollview | docs.flutter.dev · api.flutter.dev',
      );
      expect(
        webDetailSpan.style?.color,
        OfficialCodexThemeData.light.activityChildText,
      );

      // 2. Collaboration O3Io.nJ dual-tone split ("Created" 60% / " agent" 30%).
      final collabFinder = find.text('Created agent');
      expect(collabFinder, findsOneWidget);
      final collabText = tester.widget<Text>(collabFinder);
      final collabRoot = collabText.textSpan! as TextSpan;
      expect(collabRoot.text, 'Created');
      expect(
        (collabRoot.children!.single as TextSpan).style?.color,
        OfficialCodexThemeData.light.activityChildText,
      );

      // 3. Model rerouted O3Io.nO inline humanization ("Your request was routed to gpt-5.4.").
      expect(find.text('Your request was routed to gpt-5.4.'), findsOneWidget);

      // 4. Ctrl+F search flattens groups cleanly; Escape restores.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('conversation-search-bar')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // 5. Execution mode preserves raw diagnostic strings verbatim.
      await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Execution'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Web search: customscrollview site:docs.flutter.dev OR site:www.api.flutter.dev',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Model rerouted: gpt-5-mini → gpt-5.4 (capacity)'),
        findsOneWidget,
      );

      // 6. Switch back to Commands mode at 2.0x text scale without layout overflow.
      await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commands'));
      await tester.pumpAndSettle();

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'U8 A7 CodexInlinePatchPreviewCard clamps to 240px, truncates at 80 lines, awaits Clipboard.setData, and suppresses clipboard errors',
    (tester) async {
      var completer = Completer<void>();
      var failClipboard = false;
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              if (failClipboard) {
                throw PlatformException(code: 'unavailable');
              }
              final args = call.arguments as Map<Object?, Object?>?;
              copiedText = args?['text'] as String?;
              await completer.future;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final file = DiffFile(
        path: 'lib/a.dart',
        additions: 90,
        deletions: 1,
        lines: [
          '-final oldFlag = false;',
          for (var i = 1; i <= 90; i++) '+final ok$i = $i;',
        ],
        truncated: false,
      );
      final card = CodexInlinePatchPreviewCard(files: [file]);
      const copyKey = ValueKey('inline-patch-copy-lib/a.dart');

      await tester.pumpWidget(
        MaterialApp(
          home: OfficialCodexThemeProvider(
            data: OfficialCodexThemeData.light,
            child: Scaffold(body: card),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CodexInlinePatchPreviewCard)).height,
        lessThanOrEqualTo(246.0),
      );
      expect(find.text('-final oldFlag = false;'), findsOneWidget);
      expect(find.text('Showing bounded diff preview'), findsOneWidget);

      final copyButton = find.byKey(copyKey);

      await tester.tap(copyButton);
      await tester.pump();
      expect(copiedText, contains('-final oldFlag = false;'));
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      completer.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1450));
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      failClipboard = true;
      await tester.tap(copyButton);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      failClipboard = false;
      completer = Completer<void>();
      await tester.tap(copyButton);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      completer.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

class _NonCompletedGroupingHarness extends SimulatedRuntimeHarness {
  _NonCompletedGroupingHarness()
    : super(
        initialThreads: [
          createTestThread(
            id: 'u8-int-thread',
            preview: 'U8 interrupted grouping thread',
          ),
        ],
        initialHistoryTurns: [
          HistoryTurn(
            id: 'u8-interrupted-1',
            status: TurnRuntimeStatus.interrupted,
            startedAt: DateTime.utc(2026),
            completedAt: DateTime.utc(2026).add(const Duration(seconds: 3)),
            items: const [_user1],
          ),
          HistoryTurn(
            id: 'u8-clipped-2',
            status: TurnRuntimeStatus.failed,
            startedAt: DateTime.utc(2026, 1, 1, 0, 1),
            completedAt: DateTime.utc(2026, 1, 1, 0, 1, 5),
            items: const [_user2],
          ),
        ],
        initialHistoryItems: const [
          _user1,
          HistoryItem(
            id: 'int-read-1',
            turnId: 'u8-interrupted-1',
            kind: HistoryItemKind.activity,
            text: 'Command: cat pubspec.yaml',
            status: 'completed',
            isCommand: true,
            commandAction: (
              kind: CommandActionKind.read,
              name: 'pubspec.yaml',
              path: 'pubspec.yaml',
              query: null,
            ),
          ),
          HistoryItem(
            id: 'int-read-2',
            turnId: 'u8-interrupted-1',
            kind: HistoryItemKind.activity,
            text: 'Command: ls lib',
            status: 'completed',
            isCommand: true,
            commandAction: (
              kind: CommandActionKind.listFiles,
              name: null,
              path: 'lib',
              query: null,
            ),
          ),
          HistoryItem(
            id: 'int-stop-3',
            turnId: 'u8-interrupted-1',
            kind: HistoryItemKind.activity,
            text: 'Command: sleep 30',
            status: 'interrupted',
            isCommand: true,
          ),
          _user2,
          HistoryItem(
            id: 'clip-read-1',
            turnId: 'u8-clipped-2',
            kind: HistoryItemKind.activity,
            text: 'Command: cat a.dart',
            status: 'completed',
            isCommand: true,
            commandAction: (
              kind: CommandActionKind.read,
              name: 'a.dart',
              path: 'a.dart',
              query: null,
            ),
          ),
          HistoryItem(
            id: 'clip-read-2',
            turnId: 'u8-clipped-2',
            kind: HistoryItemKind.activity,
            text: 'Command: cat b.dart',
            status: 'completed',
            isCommand: true,
            commandAction: (
              kind: CommandActionKind.read,
              name: 'b.dart',
              path: 'b.dart',
              query: null,
            ),
          ),
        ],
      );

  static const _user1 = HistoryItem(
    id: 'int-user-1',
    turnId: 'u8-interrupted-1',
    kind: HistoryItemKind.user,
    text: 'Inspect project then sleep.',
  );

  static const _user2 = HistoryItem(
    id: 'clip-user-2',
    turnId: 'u8-clipped-2',
    kind: HistoryItemKind.user,
    text: 'Inspect clipped page.',
  );
}

class _ExitCodeForwardingHarness extends SimulatedRuntimeHarness {
  _ExitCodeForwardingHarness()
    : super(
        initialThreads: [
          createTestThread(
            id: 'u8-exit-thread',
            preview: 'U8 shell exitCode thread',
          ),
        ],
        initialHistoryTurns: [
          HistoryTurn(
            id: 'u8-exit-saved',
            status: TurnRuntimeStatus.completed,
            startedAt: DateTime.utc(2026),
            completedAt: DateTime.utc(2026).add(const Duration(seconds: 4)),
            items: const [_user, _assistant],
          ),
        ],
        initialHistoryItems: const [
          _user,
          HistoryItem(
            id: 'exit-grp-1',
            turnId: 'u8-exit-saved',
            kind: HistoryItemKind.activity,
            text: 'Command: cat README.md',
            status: 'completed',
            isCommand: true,
            exitCode: 0,
            commandAction: (
              kind: CommandActionKind.read,
              name: 'README.md',
              path: 'README.md',
              query: null,
            ),
          ),
          HistoryItem(
            id: 'exit-grp-2',
            turnId: 'u8-exit-saved',
            kind: HistoryItemKind.activity,
            text: 'Command: printf grouped-ok',
            status: 'completed',
            isCommand: true,
            exitCode: 0,
            output: OutputDescriptor(
              reference: 'u8-saved-grp-out',
              bytes: 10,
              storedBytes: 10,
              truncated: false,
              available: true,
            ),
          ),
          HistoryItem(
            id: 'exit-fail-2',
            turnId: 'u8-exit-saved',
            kind: HistoryItemKind.activity,
            text: 'Command: false',
            status: 'failed',
            isCommand: true,
            exitCode: 2,
            output: OutputDescriptor(
              reference: 'u8-saved-fail-out',
              bytes: 11,
              storedBytes: 11,
              truncated: false,
              available: true,
            ),
          ),
          _assistant,
        ],
      ) {
    storeOutput('u8-saved-grp-out', 'grouped-ok');
    storeOutput('u8-saved-fail-out', 'failed line');
    storeOutput('u8-live-grp-out', 'live-grouped');
    storeOutput('u8-live-fail-out', 'error[E0425]');
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
    id: 'exit-user',
    turnId: 'u8-exit-saved',
    kind: HistoryItemKind.user,
    text: 'Run exit code checks.',
  );

  static const _assistant = HistoryItem(
    id: 'exit-assistant',
    turnId: 'u8-exit-saved',
    kind: HistoryItemKind.assistant,
    text: 'Checked exit codes.',
  );
}

class _PatchAndNonShellHarness extends SimulatedRuntimeHarness {
  _PatchAndNonShellHarness()
    : super(
        initialThreads: [
          createTestThread(
            id: 'u8-nonshell-thread',
            preview: 'U8 A7 non-shell thread',
          ),
        ],
        initialHistoryTurns: [
          HistoryTurn(
            id: 'u8-saved-nonshell',
            status: TurnRuntimeStatus.completed,
            startedAt: DateTime.utc(2026),
            completedAt: DateTime.utc(2026).add(const Duration(seconds: 5)),
            items: const [_user, _assistant],
          ),
        ],
        initialHistoryItems: const [
          _user,
          HistoryItem(
            id: 'ns-web-1',
            turnId: 'u8-saved-nonshell',
            kind: HistoryItemKind.activity,
            text: 'Web search: customscrollview site:docs.flutter.dev OR site:www.api.flutter.dev',
            status: 'completed',
          ),
          HistoryItem(
            id: 'ns-collab-1',
            turnId: 'u8-saved-nonshell',
            kind: HistoryItemKind.activity,
            text: 'Collaboration: spawn_agent',
            status: 'completed',
          ),
          HistoryItem(
            id: 'ns-reroute-1',
            turnId: 'u8-saved-nonshell',
            kind: HistoryItemKind.activity,
            text: 'Model rerouted: gpt-5-mini → gpt-5.4 (capacity)',
            status: 'completed',
          ),
          HistoryItem(
            id: 'ns-edit-1',
            turnId: 'u8-saved-nonshell',
            kind: HistoryItemKind.activity,
            text: 'File changes: 1 update(s) (+4 -1)',
            status: 'completed',
          ),
          _assistant,
        ],
      );

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
    id: 'ns-user',
    turnId: 'u8-saved-nonshell',
    kind: HistoryItemKind.user,
    text: 'Check non-shell activity rows.',
  );

  static const _assistant = HistoryItem(
    id: 'ns-assistant',
    turnId: 'u8-saved-nonshell',
    kind: HistoryItemKind.assistant,
    text: 'Completed non-shell checks.',
  );
}
