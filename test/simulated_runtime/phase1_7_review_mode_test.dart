import 'dart:async';

import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

class _ReviewModeE2EHarness extends SimulatedRuntimeHarness {
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
  testWidgets('starts a typed uncommitted review from the local thread menu', (
    tester,
  ) async {
    final harness = SimulatedRuntimeHarness(
      initialThreads: [
        createTestThread(
          id: 'review-action-thread',
          preview: 'Review Action Thread',
        ),
      ],
    );
    await pumpSimulatedRuntimeApp(tester, harness: harness);

    await tester.tap(find.text('Review Action Thread'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('thread-actions-menu-button')));
    await tester.pumpAndSettle();
    expect(find.text('Review uncommitted changes'), findsOneWidget);
    expect(find.text('Code review…'), findsOneWidget);

    await tester.tap(find.text('Review uncommitted changes'));
    await tester.pumpAndSettle();

    expect(harness.startedReviews, hasLength(1));
    expect(harness.startedReviews.single.threadId, 'review-action-thread');
    expect(
      harness.startedReviews.single.target,
      isA<UncommittedChangesReviewTarget>(),
    );
    expect(
      find.byKey(const ValueKey('conversation-review-mode-banner')),
      findsOneWidget,
    );
  });

  testWidgets(
    'starts baseBranch, commit, and custom reviews from the Code review dialog and validates inputs',
    (tester) async {
      final harness = _ReviewModeE2EHarness();
      await pumpSimulatedRuntimeApp(tester, harness: harness);

      await tester.tap(find.text('Review Mode Test Thread'));
      await tester.pumpAndSettle();

      // 1. Base branch review (validates invalid refs and trims valid input)
      await tester.tap(
        find.byKey(const ValueKey('thread-actions-menu-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code review…'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('review-target-baseBranch')));
      await tester.pumpAndSettle();

      var submitBtn = tester.widget<CodexButton>(
        find.byKey(const ValueKey('start-review-submit-button')),
      );
      expect(submitBtn.onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('review-base-branch-field')),
        '-invalid-flag',
      );
      await tester.pumpAndSettle();
      submitBtn = tester.widget<CodexButton>(
        find.byKey(const ValueKey('start-review-submit-button')),
      );
      expect(submitBtn.onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('review-base-branch-field')),
        'has whitespace',
      );
      await tester.pumpAndSettle();
      submitBtn = tester.widget<CodexButton>(
        find.byKey(const ValueKey('start-review-submit-button')),
      );
      expect(submitBtn.onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('review-base-branch-field')),
        '  origin/main  ',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('start-review-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(harness.startedReviews, hasLength(1));
      expect(
        harness.startedReviews.last.target,
        isA<BaseBranchReviewTarget>().having(
          (t) => t.branch,
          'branch',
          'origin/main',
        ),
      );

      // Complete the first review turn so the thread can start another review.
      harness.reviewEvents.add(
        const ReviewModeEvent(
          threadId: 'review-thread',
          turnId: 'review-turn-1',
          itemId: 'review-exited-1',
          phase: ReviewModePhase.exited,
          review: 'Changes against origin/main',
          status: 'completed',
          completed: true,
        ),
      );
      harness.reviewEvents.add(
        const TurnCompletedEvent(
          threadId: 'review-thread',
          turnId: 'review-turn-1',
          status: TurnRuntimeStatus.completed,
        ),
      );
      await tester.pumpAndSettle();

      // 2. Commit review with optional title
      await tester.tap(
        find.byKey(const ValueKey('thread-actions-menu-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code review…'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('review-target-commit')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('review-commit-sha-field')),
        '  HEAD~1  ',
      );
      final titleField = tester.widget<TextField>(
        find.byKey(const ValueKey('review-commit-title-field')),
      );
      titleField.controller!.text = 'a' * 241;
      await tester.pumpAndSettle();
      submitBtn = tester.widget<CodexButton>(
        find.byKey(const ValueKey('start-review-submit-button')),
      );
      expect(submitBtn.onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('review-commit-title-field')),
        '  Consolidation baseline  ',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('start-review-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(harness.startedReviews, hasLength(2));
      expect(
        harness.startedReviews.last.target,
        isA<CommitReviewTarget>()
            .having((t) => t.sha, 'sha', 'HEAD~1')
            .having((t) => t.title, 'title', 'Consolidation baseline'),
      );

      harness.reviewEvents.add(
        const TurnCompletedEvent(
          threadId: 'review-thread',
          turnId: 'review-turn-2',
          status: TurnRuntimeStatus.completed,
        ),
      );
      await tester.pumpAndSettle();

      // 3. Custom instructions review
      await tester.tap(
        find.byKey(const ValueKey('thread-actions-menu-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code review…'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('review-target-custom')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('review-custom-instructions-field')),
        '  Audit async rollback rebind and boundary checks.  ',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('start-review-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(harness.startedReviews, hasLength(3));
      expect(
        harness.startedReviews.last.target,
        isA<CustomReviewTarget>().having(
          (t) => t.instructions,
          'instructions',
          'Audit async rollback rebind and boundary checks.',
        ),
      );
    },
  );

  testWidgets(
    'aborts starting review if the thread becomes busy while the Code review dialog is open',
    (tester) async {
      final harness = _ReviewModeE2EHarness();
      await pumpSimulatedRuntimeApp(tester, harness: harness);

      await tester.tap(find.text('Review Mode Test Thread'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('thread-actions-menu-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code review…'));
      await tester.pumpAndSettle();

      // Another turn starts on the active thread while the modal is open.
      harness.reviewEvents.add(
        const TurnStartedEvent(
          threadId: 'review-thread',
          turnId: 'concurrent-turn',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('start-review-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(harness.startedReviews, isEmpty);
    },
  );

  testWidgets('hides review action on the read-only Remote surface', (
    tester,
  ) async {
    final harness = SimulatedRuntimeHarness(
      initialThreads: [
        createTestThread(
          id: 'remote-review-thread',
          preview: 'Remote Review Thread',
        ),
      ],
    )..remoteModeOverride = true;
    await pumpSimulatedRuntimeApp(tester, harness: harness);

    await tester.tap(find.text('Remote Review Thread'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('thread-actions-menu-button')));
    await tester.pumpAndSettle();

    expect(find.text('Review uncommitted changes'), findsNothing);
    expect(find.text('Code review…'), findsNothing);
    expect(harness.startedReviews, isEmpty);
  });

  testWidgets(
    'renders review-mode banner and lifecycle markers without hiding them in prose mode',
    (tester) async {
      final harness = _ReviewModeE2EHarness();
      await pumpSimulatedRuntimeApp(tester, harness: harness);

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
