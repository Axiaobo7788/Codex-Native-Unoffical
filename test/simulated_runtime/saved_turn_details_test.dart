import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets('short saved turns open and collapse one bounded detail page', (
    tester,
  ) async {
    final harness = _TurnDetailsHarness();
    await _open(tester, harness);

    expect(find.text('Turn details'), findsOneWidget);
    expect(find.text('Command: synthetic fixture'), findsNothing);
    expect(harness.requests, isEmpty);

    await tester.tap(_divider);
    await tester.pumpAndSettle();

    expect(find.text('Command: synthetic fixture'), findsOneWidget);
    final query = harness.requests.single;
    expect(query.threadId, 'details-thread');
    expect(query.turnId, _turnId);
    expect(query.limit, 25);
    expect(query.cursor, isNull);

    await tester.tap(_divider);
    await tester.pumpAndSettle();
    expect(find.text('Command: synthetic fixture'), findsNothing);
    expect(harness.requests, hasLength(1));
  });

  testWidgets('Execution does not treat an unloaded turn as expanded', (
    tester,
  ) async {
    final harness = _TurnDetailsHarness(timed: true);
    await _open(tester, harness);
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
      expect(find.text('Command: synthetic fixture'), findsOneWidget);
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
    expect(find.text('Command: synthetic fixture'), findsOneWidget);
    expect(find.text('Fixture answer'), findsOneWidget);
  });
}

const _turnId = 'saved-detail-turn';
final _divider = find.byKey(const ValueKey('turn-work-saved-detail-turn'));

Future<void> _open(WidgetTester tester, _TurnDetailsHarness harness) async {
  await pumpSimulatedRuntimeApp(tester, harness: harness);
  await tester.tap(find.text('Saved details fixture'));
  await tester.pumpAndSettle();
}

class _TurnDetailsHarness extends SimulatedRuntimeHarness {
  _TurnDetailsHarness({
    bool timed = false,
    bool userOnly = false,
    this.failFirst = false,
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
             startedAt: DateTime.utc(2026),
             completedAt: DateTime.utc(2026).add(
               timed
                   ? const Duration(seconds: 3)
                   : const Duration(milliseconds: 221),
             ),
           ),
         ],
         initialHistoryItems: const [_user, _command, _assistant],
       );

  static const _user = HistoryItem(
    id: 'saved-user',
    turnId: _turnId,
    kind: HistoryItemKind.user,
    text: 'Fixture question',
  );
  static const _command = HistoryItem(
    id: 'saved-command',
    turnId: _turnId,
    kind: HistoryItemKind.activity,
    text: 'Command: synthetic fixture',
    status: 'completed',
    isCommand: true,
  );
  static const _assistant = HistoryItem(
    id: 'saved-assistant',
    turnId: _turnId,
    kind: HistoryItemKind.assistant,
    text: 'Fixture answer',
  );

  final bool failFirst;
  final requests = <HistoryItemQuery>[];

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async {
    requests.add(query);
    if (failFirst && requests.length == 1) {
      throw StateError('Synthetic first page failure');
    }
    return super.listHistoryItems(query);
  }
}
