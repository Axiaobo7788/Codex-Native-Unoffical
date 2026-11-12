import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/features/threads/thread_list_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../simulated_runtime/simulated_runtime_harness.dart';

void main() {
  test(
    'lastSessionDraftReplacement records only retired session-draft transfers',
    () async {
      final harness = _DraftNavigationRuntime();
      addTearDown(harness.disposeHarness);
      final controller = ThreadListController(gateway: harness);
      addTearDown(controller.dispose);

      await controller.refresh();
      final first = await controller.startThread(
        const ThreadStartOptions(cwd: '/workspace/test'),
      );
      expect(first, isNotNull);
      expect(controller.lastSessionDraftReplacement, isNull);

      final nonRetired = await controller.startThread(
        const ThreadStartOptions(cwd: '/workspace/test'),
        replaceSessionDraftId: first!.id,
      );
      expect(nonRetired, isNotNull);
      expect(controller.lastSessionDraftReplacement, isNull);

      controller.invalidateRuntime();
      final replacement = await controller.startThread(
        const ThreadStartOptions(cwd: '/workspace/test'),
        replaceSessionDraftId: nonRetired!.id,
      );
      expect(replacement, isNotNull);
      final event = controller.lastSessionDraftReplacement;
      expect(event, isNotNull);
      expect(event!.version, 1);
      expect(event.retiredThreadId, nonRetired.id);
      expect(event.replacementThreadId, replacement!.id);
    },
  );

  testWidgets(
    'replacing a standalone retired session draft leaves Back disabled',
    (tester) async {
      final harness = _DraftNavigationRuntime();
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      final back = find.byKey(const ValueKey('app-shell-back-button'));
      final forward = find.byKey(const ValueKey('app-shell-forward-button'));
      final header = find.byKey(const ValueKey('thread_header_bar'));

      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      final retiredId = harness.threads.first.id;
      expect(tester.widget<CodexIconButton>(back).isEnabled, isFalse);
      expect(tester.widget<CodexIconButton>(forward).isEnabled, isFalse);

      harness.lostThreadId = retiredId;
      harness.threads.removeWhere((thread) => thread.id == retiredId);
      harness.updateSnapshot(
        const RuntimeSnapshot(state: RuntimeConnectionState.processExited),
      );
      await tester.pumpAndSettle();
      harness.updateSnapshot(
        const RuntimeSnapshot(state: RuntimeConnectionState.connected),
      );
      await tester.pumpAndSettle();

      harness.readThreadCalls.clear();
      await tester.tap(
        find.byKey(const ValueKey('runtime-draft-new-conversation')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: header,
          matching: find.text('New created thread 2'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<CodexIconButton>(back).isEnabled, isFalse);
      expect(tester.widget<CodexIconButton>(forward).isEnabled, isFalse);
      expect(harness.readThreadCalls, isNot(contains(retiredId)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacing a retired draft preserves Back to an off-catalog saved thread '
    'and Forward to the replacement draft',
    (tester) async {
      final savedOffCatalog = createTestThread(
        id: 'saved-off-catalog',
        preview: 'Off-catalog saved thread',
      );
      final harness = _DraftNavigationRuntime(
        initialThreads: [savedOffCatalog],
        offCatalogSavedThreads: {'saved-off-catalog': savedOffCatalog},
      );
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      final back = find.byKey(const ValueKey('app-shell-back-button'));
      final forward = find.byKey(const ValueKey('app-shell-forward-button'));
      final header = find.byKey(const ValueKey('thread_header_bar'));
      final composer = find.byKey(const ValueKey('conversation-composer'));

      await tester.tap(
        find.byKey(const ValueKey('thread-row-saved-off-catalog')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      final retiredId = harness.threads.first.id;
      expect(tester.widget<CodexIconButton>(back).isEnabled, isTrue);

      await tester.enterText(composer, 'Draft preserved across Back/Forward');
      await tester.pump();

      // Simulate the earlier saved thread paging out of the first catalog page
      // while remaining readable by ID on demand.
      harness.lostThreadId = retiredId;
      harness.threads
        ..removeWhere((thread) => thread.id == retiredId)
        ..removeWhere((thread) => thread.id == savedOffCatalog.id);
      harness.updateSnapshot(
        const RuntimeSnapshot(state: RuntimeConnectionState.processExited),
      );
      await tester.pumpAndSettle();
      harness.updateSnapshot(
        const RuntimeSnapshot(state: RuntimeConnectionState.connected),
      );
      await tester.pumpAndSettle();

      harness.readThreadCalls.clear();
      await tester.tap(
        find.byKey(const ValueKey('runtime-draft-new-conversation')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: header,
          matching: find.text('New created thread 2'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<CodexIconButton>(back).isEnabled, isTrue);

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: header,
          matching: find.text('Off-catalog saved thread'),
        ),
        findsOneWidget,
      );
      expect(harness.readThreadCalls, ['saved-off-catalog']);
      expect(tester.widget<CodexIconButton>(back).isEnabled, isFalse);
      expect(tester.widget<CodexIconButton>(forward).isEnabled, isTrue);

      await tester.tap(forward);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: header,
          matching: find.text('New created thread 2'),
        ),
        findsOneWidget,
      );
      expect(harness.readThreadCalls, ['saved-off-catalog']);
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Draft preserved across Back/Forward',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacing a retired draft rewrites Customize navigation visits so Back '
    'returns to Customize without probing the evicted ID',
    (tester) async {
      final harness = _DraftNavigationRuntime();
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      final back = find.byKey(const ValueKey('app-shell-back-button'));
      final forward = find.byKey(const ValueKey('app-shell-forward-button'));
      final homeRail = find.byKey(const ValueKey('app-shell-home-button'));
      final customizeRail = find.byKey(const ValueKey('ecosystem-button'));

      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      final retiredId = harness.threads.first.id;

      await tester.tap(customizeRail);
      await tester.pumpAndSettle();
      expect(tester.widget<CodexIconButton>(customizeRail).selected, isTrue);

      await tester.tap(homeRail);
      await tester.pumpAndSettle();
      expect(tester.widget<CodexIconButton>(homeRail).selected, isTrue);

      harness.lostThreadId = retiredId;
      harness.threads.removeWhere((thread) => thread.id == retiredId);
      harness.updateSnapshot(
        const RuntimeSnapshot(state: RuntimeConnectionState.processExited),
      );
      await tester.pumpAndSettle();
      harness.updateSnapshot(
        const RuntimeSnapshot(state: RuntimeConnectionState.connected),
      );
      await tester.pumpAndSettle();

      harness.readThreadCalls.clear();
      await tester.tap(
        find.byKey(const ValueKey('runtime-draft-new-conversation')),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<CodexIconButton>(back).isEnabled, isTrue);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(tester.widget<CodexIconButton>(customizeRail).selected, isTrue);
      expect(harness.readThreadCalls, isEmpty);

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(tester.widget<CodexIconButton>(homeRail).selected, isTrue);
      expect(tester.widget<CodexIconButton>(back).isEnabled, isFalse);
      expect(tester.widget<CodexIconButton>(forward).isEnabled, isTrue);
      expect(harness.readThreadCalls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DraftNavigationRuntime extends SimulatedRuntimeHarness {
  _DraftNavigationRuntime({
    super.initialThreads = const [],
    this.offCatalogSavedThreads = const {},
  });

  final Map<String, ThreadSummary> offCatalogSavedThreads;
  final List<String> readThreadCalls = [];
  String? lostThreadId;

  @override
  Future<ThreadSummary> readThread(String threadId) async {
    readThreadCalls.add(threadId);
    if (threadId == lostThreadId) {
      throw StateError('Fixture thread not loaded in new runtime');
    }
    if (offCatalogSavedThreads[threadId] case final saved?) {
      return saved;
    }
    return super.readThread(threadId);
  }
}
