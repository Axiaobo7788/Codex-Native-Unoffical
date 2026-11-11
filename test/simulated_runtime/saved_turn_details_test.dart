import 'dart:async';

import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets('short saved turns open and collapse one bounded detail page', (
    tester,
  ) async {
    final harness = _TurnDetailsHarness();
    await _open(tester, harness);

    expect(find.text('Worked for 0s'), findsOneWidget);
    expect(find.text('Ran synthetic fixture'), findsNothing);
    expect(find.text('Command: synthetic fixture'), findsNothing);
    expect(
      find.descendant(
        of: _divider,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AnimatedRotation>(
            find.descendant(
              of: _divider,
              matching: find.byType(AnimatedRotation),
            ),
          )
          .turns,
      0.0,
    );
    expect(harness.requests, isEmpty);

    await tester.tap(_divider);
    await tester.pumpAndSettle();

    expect(find.text('Ran synthetic fixture'), findsOneWidget);
    expect(find.text('Command: synthetic fixture'), findsNothing);
    expect(
      find.descendant(
        of: _divider,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AnimatedRotation>(
            find.descendant(
              of: _divider,
              matching: find.byType(AnimatedRotation),
            ),
          )
          .turns,
      0.25,
    );
    final query = harness.requests.single;
    expect(query.threadId, 'details-thread');
    expect(query.turnId, _turnId);
    expect(query.limit, 25);
    expect(query.cursor, isNull);

    await tester.tap(_divider);
    await tester.pumpAndSettle();
    expect(find.text('Ran synthetic fixture'), findsNothing);
    expect(harness.requests, hasLength(1));
  });

  testWidgets('Execution does not treat an unloaded turn as expanded', (
    tester,
  ) async {
    final harness = _TurnDetailsHarness(timed: true);
    await _open(tester, harness);
    await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Execution'));
    await tester.pumpAndSettle();

    expect(harness.requests, isEmpty);
    expect(find.text('Worked for 3s'), findsOneWidget);
    expect(find.text('Command: synthetic fixture'), findsNothing);

    await tester.tap(_divider);
    await tester.pumpAndSettle();
    expect(harness.requests, hasLength(1));
    expect(find.text('Command: synthetic fixture'), findsOneWidget);

    await tester.tap(_divider);
    await tester.pumpAndSettle();
    expect(find.text('Command: synthetic fixture'), findsNothing);
    expect(harness.requests, hasLength(1));
  });

  testWidgets('saved exploration captions retain the raw Execution command', (
    tester,
  ) async {
    final harness = _TurnDetailsHarness(
      commandAction: (
        kind: CommandActionKind.read,
        name: null,
        path: '/workspace/fixture.txt',
        query: null,
      ),
    );
    await _open(tester, harness);
    expect(find.text('Read /workspace/fixture.txt'), findsNothing);
    expect(harness.requests, isEmpty);
    await tester.tap(_divider);
    await tester.pumpAndSettle();
    expect(find.text('Read /workspace/fixture.txt'), findsOneWidget);
    expect(find.text('Command: synthetic fixture'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('timeline-details-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Execution'));
    await tester.pumpAndSettle();
    expect(find.text('Read /workspace/fixture.txt'), findsNothing);
    expect(find.text('Command: synthetic fixture'), findsOneWidget);
    expect(harness.requests, hasLength(1));
  });

  testWidgets(
    'a failed item read leaves the summary visible and can be retried',
    (tester) async {
      final harness = _TurnDetailsHarness(timed: true, failFirst: true);
      await _open(tester, harness);

      await tester.tap(_divider);
      await tester.pumpAndSettle();
      expect(harness.requests, hasLength(1));
      expect(find.text('Fixture answer'), findsOneWidget);
      expect(find.text('Retry turn details'), findsOneWidget);

      await tester.tap(_divider);
      await tester.pumpAndSettle();
      expect(harness.requests, hasLength(2));
      expect(find.text('Ran synthetic fixture'), findsOneWidget);
      expect(find.text('Retry turn details'), findsNothing);
    },
  );

  testWidgets('a user-only summary still exposes its saved details', (
    tester,
  ) async {
    final harness = _TurnDetailsHarness(userOnly: true);
    await _open(tester, harness);

    expect(find.text('Fixture question'), findsOneWidget);
    expect(find.text('Fixture answer'), findsNothing);
    expect(find.text('Turn details'), findsOneWidget);

    await tester.tap(_divider);
    await tester.pumpAndSettle();
    expect(harness.requests, hasLength(1));
    expect(find.text('Ran synthetic fixture'), findsOneWidget);
    expect(find.text('Fixture answer'), findsOneWidget);
  });

  testWidgets('saved MCP text loads only on click and stays in its viewer', (
    tester,
  ) async {
    final reply = Completer<SavedMcpTextResult?>();
    final harness = _TurnDetailsHarness(readMcpText: () => reply.future);
    await _open(tester, harness, size: const Size(720, 800));
    expect(find.text('View saved text'), findsNothing);
    await tester.tap(_divider);
    await tester.pumpAndSettle();
    expect(harness.mcpRequests, isEmpty);
    expect(find.text('MCP: fixture/tool'), findsOneWidget);

    await tester.tap(find.text('View saved text'));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is LinearProgressIndicator &&
            widget.semanticsLabel == 'Loading saved MCP text',
      ),
      findsOneWidget,
    );
    expect(harness.mcpRequests, [('details-thread', _turnId, 'saved-mcp')]);
    reply.complete(
      const SavedMcpTextResult('Synthetic result', truncated: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved MCP text'), findsOneWidget);
    expect(
      find.text('Showing a bounded preview of the saved text.'),
      findsOneWidget,
    );
    expect(find.text('Synthetic result'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic result'), findsNothing);
  });

  testWidgets('saved MCP read can retry without displaying upstream errors', (
    tester,
  ) async {
    var attempts = 0;
    final harness = _TurnDetailsHarness(
      readMcpText: () async {
        attempts += 1;
        if (attempts == 1) {
          throw StateError('Synthetic upstream detail');
        }
        throw UnsupportedError('Synthetic unsupported detail');
      },
    );
    await _open(tester, harness);
    await tester.tap(_divider);
    await tester.pumpAndSettle();
    expect(find.text('Fixture · Tool'), findsOneWidget);
    await tester.tap(find.text('View saved text'));
    await tester.pumpAndSettle();
    expect(find.text('Could not read the saved MCP text.'), findsOneWidget);
    expect(find.textContaining('Synthetic upstream detail'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(harness.mcpRequests, hasLength(2));
    expect(
      find.text('This local runtime does not support reading saved MCP text.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.textContaining('Synthetic unsupported detail'), findsNothing);
  });

  testWidgets('a stalled saved MCP read leaves a dismissible failure', (
    tester,
  ) async {
    final reply = Completer<SavedMcpTextResult?>();
    final harness = _TurnDetailsHarness(readMcpText: () => reply.future);
    await _open(tester, harness);
    await tester.tap(_divider);
    await tester.pumpAndSettle();
    expect(find.text('Fixture · Tool'), findsOneWidget);
    await tester.tap(find.text('View saved text'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('Could not read the saved MCP text.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    reply.complete(const SavedMcpTextResult('Late text', truncated: false));
    await tester.pumpAndSettle();
    expect(find.text('Late text'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _turnId = 'saved-detail-turn';
final _divider = find.byKey(const ValueKey('turn-work-saved-detail-turn'));

Future<void> _open(
  WidgetTester tester,
  _TurnDetailsHarness harness, {
  Size size = const Size(1400, 900),
}) async {
  await pumpSimulatedRuntimeApp(tester, harness: harness, size: size);
  await tester.tap(find.text('Saved details fixture'));
  await tester.pumpAndSettle();
}

class _TurnDetailsHarness extends SimulatedRuntimeHarness {
  _TurnDetailsHarness({
    bool timed = false,
    bool userOnly = false,
    HistoryCommandAction? commandAction,
    this.failFirst = false,
    this.readMcpText,
  }) : super(
         initialThreads: [
           createTestThread(
             id: 'details-thread',
             preview: 'Saved details fixture',
           ),
         ],
         initialHistoryTurns: [
           HistoryTurn(
             id: _turnId,
             status: TurnRuntimeStatus.completed,
             items: [_user, if (!userOnly) _assistant],
             startedAt: userOnly ? null : DateTime.utc(2026),
             completedAt: userOnly
                 ? null
                 : DateTime.utc(2026)
                       .add(timed ? const Duration(seconds: 3) : Duration.zero),
             reportedWorkDuration: timed || userOnly
                 ? null
                 : const Duration(milliseconds: 221),
           ),
         ],
         initialHistoryItems: [
           _user,
           _command(commandAction),
           if (readMcpText != null) _mcp,
           _assistant,
         ],
       );

  static const _user = HistoryItem(
    id: 'saved-user',
    turnId: _turnId,
    kind: HistoryItemKind.user,
    text: 'Fixture question',
  );
  static HistoryItem _command(HistoryCommandAction? action) => HistoryItem(
    id: 'saved-command',
    turnId: _turnId,
    kind: HistoryItemKind.activity,
    text: 'Command: synthetic fixture',
    status: 'completed',
    isCommand: true,
    commandAction: action,
  );
  static const _assistant = HistoryItem(
    id: 'saved-assistant',
    turnId: _turnId,
    kind: HistoryItemKind.assistant,
    text: 'Fixture answer',
  );
  static const _mcp = HistoryItem(
    id: 'saved-mcp',
    turnId: _turnId,
    kind: HistoryItemKind.activity,
    text: 'MCP: fixture/tool',
    status: 'completed',
    canReadMcpText: true,
  );

  final bool failFirst;
  final Future<SavedMcpTextResult?> Function()? readMcpText;
  final requests = <HistoryItemQuery>[];
  final mcpRequests = <(String, String, String)>[];

  @override
  bool get supportsSavedMcpText => readMcpText != null && !usesRemote;

  @override
  Future<SavedMcpTextResult?> readSavedMcpText({
    required String threadId,
    required String turnId,
    required String itemId,
  }) {
    mcpRequests.add((threadId, turnId, itemId));
    return readMcpText!();
  }

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async {
    requests.add(query);
    if (failFirst && requests.length == 1) {
      throw StateError('Synthetic first page failure');
    }
    return super.listHistoryItems(query);
  }
}
