import 'dart:async';

import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_harness.dart';

class _ReviewModeE2EHarness extends E2ERuntimeHarness {
  _ReviewModeE2EHarness()
    : super(
        initialThreads: [
          createTestThread(
            id: 'review-thread',
            preview: 'Review Mode Test Thread',
          ),
        ],
      );

  final StreamController<TurnEvent> reviewEvents =
      StreamController<TurnEvent>.broadcast(sync: true);

  @override
  Stream<TurnEvent> get turnEvents => reviewEvents.stream;

  @override
  Future<void> disposeHarness() async {
    await reviewEvents.close();
    await super.disposeHarness();
  }
}

void main() {
  testWidgets(
    'renders review-mode banner and lifecycle markers without hiding them in prose mode',
    (tester) async {
      final harness = _ReviewModeE2EHarness();
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Review Mode Test Thread'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prose'));
      await tester.pumpAndSettle();

      harness.reviewEvents.add(
        const ReviewModeEvent(
          threadId: 'review-thread',
          turnId: 'review-turn-1',
          itemId: 'review-entered',
          phase: ReviewModePhase.entered,
          review: 'Uncommitted changes',
          status: 'completed',
          completed: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('conversation-review-mode-banner')),
        findsOneWidget,
      );
      expect(find.text('Reviewing Uncommitted changes'), findsOneWidget);
      expect(find.text('Review started: Uncommitted changes'), findsOneWidget);

      harness.reviewEvents.add(
        const ReviewModeEvent(
          threadId: 'review-thread',
          turnId: 'review-turn-1',
          itemId: 'review-exited',
          phase: ReviewModePhase.exited,
          review: 'Uncommitted changes',
          status: 'completed',
          completed: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('conversation-review-mode-banner')),
        findsNothing,
      );
      expect(
        find.text('Review completed: Uncommitted changes'),
        findsOneWidget,
      );
    },
  );
}
