import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets(
    'cold queued work requires a separate resume and preserves draft attachments',
    (tester) async {
      final harness = _QueueGuardHarness();
      await pumpSimulatedRuntimeApp(tester, harness: harness);
      await _select(tester, 'Cold queue');
      await _attachFile(tester);
      await tester.enterText(_composer, 'New draft');
      await tester.pump();
      await tester.tap(_send);
      await tester.pumpAndSettle();

      expect(find.text('Resume queued work?'), findsOneWidget);
      expect(harness.queueReads, ['cold']);
      expect(harness.resumedThreadIds, isEmpty);
      expect(harness.startedTurns, isEmpty);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('New draft'), findsOneWidget);
      expect(_attachment, findsOneWidget);
      expect(harness.resumedThreadIds, isEmpty);

      await tester.tap(_send);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume queued work'));
      await tester.pumpAndSettle();

      expect(harness.resumedThreadIds, ['cold']);
      expect(harness.startedTurns, isEmpty);
      expect(harness.steeredTurns, isEmpty);
      expect(find.text('New draft'), findsOneWidget);
      expect(_attachment, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'repeated sends and a switch away and back discard the stale preflight',
    (tester) async {
      final harness = _QueueGuardHarness()
        ..pendingRead = Completer<ThreadQueuePresence>();
      await pumpSimulatedRuntimeApp(tester, harness: harness);
      await _select(tester, 'Cold queue');
      await tester.enterText(_composer, 'First draft');
      await tester.pump();
      await tester.tap(_send);
      await tester.pump();
      await tester.tap(_send);
      await tester.pump();
      expect(harness.queueReads, ['cold']);

      await _select(tester, 'Other cold thread');
      await _select(tester, 'Cold queue');
      harness.pendingRead!.complete(ThreadQueuePresence.pending);
      await tester.pumpAndSettle();

      expect(find.text('Resume queued work?'), findsNothing);
      expect(harness.resumedThreadIds, isEmpty);
      expect(harness.startedTurns, isEmpty);
    },
  );

  testWidgets('a stalled preflight makes resume explicit and keeps the draft', (
    tester,
  ) async {
    final harness = _QueueGuardHarness()
      ..pendingRead = Completer<ThreadQueuePresence>();
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    await _select(tester, 'Cold queue');
    await tester.enterText(_composer, 'Draft after timeout');
    await tester.pump();
    await tester.tap(_send);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Could not check queued work'), findsOneWidget);
    expect(harness.resumedThreadIds, isEmpty);
    await tester.tap(find.text('Cancel'));
    harness.pendingRead!.complete(ThreadQueuePresence.empty);
    await tester.pumpAndSettle();
    expect(find.text('Draft after timeout'), findsOneWidget);
    expect(harness.startedTurns, isEmpty);
  });

  testWidgets('old runtime fallback keeps ordinary cold Send working', (
    tester,
  ) async {
    final harness = _QueueGuardHarness()
      ..queuePresence = ThreadQueuePresence.unsupported;
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    await _select(tester, 'Cold queue');
    await tester.enterText(_composer, 'Ordinary draft');
    await tester.pump();
    await tester.tap(_send);
    await tester.pumpAndSettle();

    expect(harness.queueReads, ['cold']);
    expect(harness.resumedThreadIds, ['cold']);
    expect(harness.startedTurns.single.text, 'Ordinary draft');
    expect(find.text('Resume queued work?'), findsNothing);
  });

  testWidgets(
    'a resumed thread that is already active keeps the draft unsubmitted',
    (tester) async {
      final harness = _QueueGuardHarness()
        ..queuePresence = ThreadQueuePresence.empty
        ..resumeAsActive = true;
      await pumpSimulatedRuntimeApp(tester, harness: harness);
      await _select(tester, 'Cold queue');
      await tester.enterText(_composer, 'Draft next to running work');
      await tester.pump();
      await tester.tap(_send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(harness.resumedThreadIds, ['cold']);
      expect(harness.startedTurns, isEmpty);
      expect(harness.steeredTurns, isEmpty);
      expect(find.text('Draft next to running work'), findsOneWidget);
      final running = find.byKey(const ValueKey('thread-running-cold'));
      final menu = find.byKey(const ValueKey('thread-menu-cold'));
      final row = find.byKey(const ValueKey('thread-row-cold'));
      expect(
        tester.getRect(running).left,
        greaterThan(tester.getCenter(row).dx),
      );
      expect(menu, findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(row));
      addTearDown(mouse.removePointer);
      await tester.pump();
      expect(running, findsNothing);
      expect(menu, findsOneWidget);
      await mouse.moveTo(tester.getCenter(_composer));
      await tester.pump();
      expect(running, findsOneWidget);
      expect(menu, findsNothing);
      expect(
        find.textContaining('The resumed thread is already running'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'compact direct cold Send failure surfaces conversation feedback, keeps draft and attachments, and clears on retry',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final harness = _QueueGuardHarness()
          ..queuePresence = ThreadQueuePresence.empty
          ..resumeError = StateError(
            'JSON-RPC error -32600: no rollout found for threadId cold',
          );
        await pumpSimulatedRuntimeApp(
          tester,
          harness: harness,
          size: const Size(720, 800),
        );
        await _select(tester, 'Cold queue');
        await _attachFile(tester);
        await tester.enterText(_composer, 'Draft during missing rollout');
        await tester.tap(_send);
        await tester.pumpAndSettle();

        expect(harness.queueReads, ['cold']);
        expect(harness.resumedThreadIds, ['cold']);
        expect(harness.startedTurns, isEmpty);
        expect(harness.steeredTurns, isEmpty);
        expect(find.text('Draft during missing rollout'), findsOneWidget);
        expect(_attachment, findsOneWidget);
        expect(_resumeErrorBanner, findsOneWidget);
        expect(
          tester.getSemantics(_resumeErrorBanner).flagsCollection.isLiveRegion,
          isTrue,
        );
        expect(
          find.textContaining('no rollout found for threadId cold'),
          findsOneWidget,
        );

        harness.queuePresence = ThreadQueuePresence.pending;
        await tester.tap(_send);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(_resumeErrorBanner, findsOneWidget);
        expect(harness.resumedThreadIds, ['cold']);
        expect(find.text('Draft during missing rollout'), findsOneWidget);
        expect(_attachment, findsOneWidget);

        harness.queuePresence = ThreadQueuePresence.empty;
        harness.resumeError = null;
        await tester.tap(_send);
        await tester.pumpAndSettle();

        expect(harness.resumedThreadIds, ['cold', 'cold']);
        expect(_resumeErrorBanner, findsNothing);
        expect(
          harness.startedTurns.single.text,
          'Draft during missing rollout',
        );
        expect(harness.startedTurns.single.attachments, hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'compact queued-work explicit resume failure surfaces conversation feedback without dispatching a turn',
    (tester) async {
      final harness = _QueueGuardHarness()
        ..queuePresence = ThreadQueuePresence.pending
        ..resumeError = StateError(
          'JSON-RPC error -32600: no rollout found for threadId cold',
        );
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(720, 800),
      );
      await _select(tester, 'Cold queue');
      await _attachFile(tester);
      await tester.enterText(_composer, 'Queued draft');

      await tester.tap(_send);
      await tester.pumpAndSettle();
      expect(find.text('Resume queued work?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(harness.resumedThreadIds, isEmpty);
      expect(_resumeErrorBanner, findsNothing);
      expect(find.text('Queued draft'), findsOneWidget);
      expect(_attachment, findsOneWidget);

      await tester.tap(_send);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume queued work'));
      await tester.pumpAndSettle();

      expect(harness.resumedThreadIds, ['cold']);
      expect(harness.startedTurns, isEmpty);
      expect(harness.steeredTurns, isEmpty);
      expect(find.text('Queued draft'), findsOneWidget);
      expect(_attachment, findsOneWidget);
      expect(_resumeErrorBanner, findsOneWidget);
      expect(
        find.textContaining('no rollout found for threadId cold'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collapsed-sidebar resume failure stays scoped to the current attempt and clears on dismiss or thread switch',
    (tester) async {
      final harness = _QueueGuardHarness()
        ..queuePresence = ThreadQueuePresence.empty
        ..resumeError = StateError(
          'JSON-RPC error -32600: This chat uses provider_alpha',
        );
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1280, 720),
      );
      await _select(tester, 'Cold queue');
      await tester.tap(find.byKey(const ValueKey('sidebar-collapse-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app_shell_sidebar')), findsNothing);

      await _attachFile(tester);
      await tester.enterText(_composer, 'Collapsed draft');
      await tester.tap(_send);
      await tester.pumpAndSettle();

      expect(harness.resumedThreadIds, ['cold']);
      expect(harness.startedTurns, isEmpty);
      expect(find.text('Collapsed draft'), findsOneWidget);
      expect(_attachment, findsOneWidget);
      expect(_resumeErrorBanner, findsOneWidget);
      expect(
        find.textContaining('This chat uses provider_alpha'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('conversation-resume-error-dismiss')),
      );
      await tester.pumpAndSettle();
      expect(_resumeErrorBanner, findsNothing);
      expect(find.text('Collapsed draft'), findsOneWidget);
      expect(_attachment, findsOneWidget);

      await tester.tap(_send);
      await tester.pumpAndSettle();
      expect(_resumeErrorBanner, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sidebar-expand-button')));
      await tester.pumpAndSettle();
      await _select(tester, 'Other cold thread');
      expect(_resumeErrorBanner, findsNothing);

      await _select(tester, 'Cold queue');
      expect(_resumeErrorBanner, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

final _composer = find.byKey(const ValueKey('conversation-composer'));
final _send = find.byKey(const ValueKey('composer-send-button'));
final _attachment = find.byKey(const ValueKey('composer-attachment-chip-0'));
final _resumeErrorBanner = find.byKey(
  const ValueKey('conversation-resume-error-banner'),
);

Future<void> _select(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> _attachFile(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('composer-attach-button')));
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
}

class _QueueGuardHarness extends SimulatedRuntimeHarness {
  _QueueGuardHarness()
    : super(
        initialThreads: [
          createTestThread(
            id: 'cold',
            preview: 'Cold queue',
            status: ThreadRuntimeStatus.notLoaded,
          ),
          createTestThread(
            id: 'other',
            preview: 'Other cold thread',
            status: ThreadRuntimeStatus.notLoaded,
          ),
        ],
      );

  final queueReads = <String>[];
  Completer<ThreadQueuePresence>? pendingRead;
  ThreadQueuePresence queuePresence = ThreadQueuePresence.pending;
  bool resumeAsActive = false;
  Object? resumeError;

  @override
  bool get supportsThreadQueuePresence => true;

  @override
  Future<ThreadQueuePresence> readThreadQueuePresence(String threadId) async {
    queueReads.add(threadId);
    return pendingRead?.future ?? queuePresence;
  }

  @override
  Future<ThreadSummary> resumeThread(String threadId) async {
    if (resumeError case final error?) {
      resumedThreadIds.add(threadId);
      throw error;
    }
    final thread = await super.resumeThread(threadId);
    return resumeAsActive
        ? thread.copyWith(status: ThreadRuntimeStatus.active)
        : thread;
  }
}
