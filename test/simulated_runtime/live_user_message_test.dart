import 'dart:async';

import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets(
    'reconciled live input keeps its row key and replaces its history echo',
    (tester) async {
      final harness = SimulatedRuntimeHarness(
        initialThreads: [
          createTestThread(id: 'active-thread', preview: 'Fixture'),
        ],
        initialHistoryTurns: const [
          HistoryTurn(
            id: 'turn-1',
            status: TurnRuntimeStatus.completed,
            items: [
              HistoryItem(
                id: 'stock-user',
                turnId: 'turn-1',
                kind: HistoryItemKind.user,
                text: 'Stock projection',
              ),
            ],
          ),
        ],
      );
      await pumpSimulatedRuntimeApp(tester, harness: harness);
      await tester.tap(find.text('Fixture'));
      await tester.pumpAndSettle();
      expect(find.text('Stock projection'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('conversation-composer')),
        'Composer projection',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();
      final clientId = harness.startedTurns.single.clientUserMessageId;
      expect(clientId, isNotNull);
      final optimisticBubble = find.byKey(
        ValueKey('user-message-bubble-$clientId'),
      );
      expect(optimisticBubble, findsOneWidget);

      final echo = UserMessageEvent(
        threadId: 'active-thread',
        turnId: 'turn-1',
        itemId: 'stock-user',
        clientMessageId: clientId,
        text: 'Stock projection',
      );
      harness.emitUserMessage(echo);
      harness.emitUserMessage(echo);
      await tester.pumpAndSettle();

      expect(optimisticBubble, findsOneWidget);
      expect(find.text('Composer projection'), findsOneWidget);
      expect(find.text('Stock projection'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a reply leaves the draft typed while the previous send was pending',
    (tester) async {
      final harness = _DelayedStartHarness();
      await pumpSimulatedRuntimeApp(tester, harness: harness);
      await tester.tap(find.text('Fixture'));
      await tester.pumpAndSettle();
      final composer = find.byKey(const ValueKey('conversation-composer'));

      await tester.enterText(composer, 'First send');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();
      expect(harness.startedTurns.single.text, 'First send');

      await tester.enterText(composer, 'Draft for the running turn');
      harness.release.complete();
      await tester.pumpAndSettle();

      expect(find.text('Draft for the running turn'), findsOneWidget);
      expect(harness.steeredTurns, isEmpty);
    },
  );
}

class _DelayedStartHarness extends SimulatedRuntimeHarness {
  _DelayedStartHarness()
    : super(
        initialThreads: [
          createTestThread(id: 'active-thread', preview: 'Fixture'),
        ],
      );

  final release = Completer<void>();

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) async {
    final started = await super.startTurn(options);
    await release.future;
    return started;
  }
}
