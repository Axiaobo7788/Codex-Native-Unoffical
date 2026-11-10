import 'dart:async';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'builds only visible rows from a 1000-item history projection and opens at latest',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _StressRuntimeController();
      addTearDown(runtime.closeStreams);

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pump();
      await tester.pump();
      expect(find.text('Stress thread'), findsOneWidget);

      await tester.tap(find.text('Stress thread'));
      await tester.pump();
      await tester.pump();

      final builtHistoryRows = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> && key.value.startsWith('history-');
      });
      expect(builtHistoryRows, findsWidgets);
      expect(builtHistoryRows.evaluate().length, lessThan(100));
      expect(
        find.byKey(const ValueKey('conversation-timeline')),
        findsOneWidget,
      );
      // Turn 0 is the newest turn in descending order; its last item (item-9)
      // must be immediately visible at the bottom without scrolling from top.
      expect(find.byKey(const ValueKey('history-item-9')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-item-990')), findsNothing);
      expect(find.byKey(const ValueKey('jump-to-latest-button')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scrolling up shows Jump to latest, prevents streaming yank, and preserves anchor when loading older turns',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _PagedHistoryRuntimeController();
      addTearDown(runtime.closeStreams);

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paged thread'));
      await tester.pumpAndSettle();

      // Opens at newest item (recent-29).
      expect(find.byKey(const ValueKey('history-recent-29')), findsOneWidget);
      expect(find.byKey(const ValueKey('jump-to-latest-button')), findsNothing);

      // Scroll up toward older items in the first page.
      final timeline = find.byKey(const ValueKey('conversation-timeline'));
      await tester.drag(timeline, const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('jump-to-latest-button')),
        findsOneWidget,
      );
      final scrollableState = tester.state<ScrollableState>(
        find.descendant(of: timeline, matching: find.byType(Scrollable)),
      );
      final scrolledOffset = scrollableState.position.pixels;
      expect(scrolledOffset, lessThan(-160));
      final scrolledAnchorRow = find.byKey(const ValueKey('history-recent-18'));
      expect(scrolledAnchorRow, findsOneWidget);
      final scrolledAnchorTopBefore = tester.getTopLeft(scrolledAnchorRow).dy;

      // Streaming updates while scrolled up must not yank the user back to
      // bottom or shift the currently visible history row on screen.
      runtime.emitStreamingMessage('live-item-1', 'Streaming update while up');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(
        scrollableState.position.pixels,
        lessThanOrEqualTo(scrolledOffset),
      );
      expect(
        tester.getTopLeft(scrolledAnchorRow).dy,
        closeTo(scrolledAnchorTopBefore, 1.0),
      );
      expect(
        find.byKey(const ValueKey('jump-to-latest-button')),
        findsOneWidget,
      );

      // Scroll all the way to the top of the loaded page and load older turns.
      await tester.drag(timeline, const Offset(0, 3000));
      await tester.pumpAndSettle();
      final oldestRecentRow = find.byKey(const ValueKey('history-recent-0'));
      expect(oldestRecentRow, findsOneWidget);
      expect(find.text('Load older turns'), findsOneWidget);

      final anchorTopBefore = tester.getTopLeft(oldestRecentRow).dy;
      await tester.tap(find.text('Load older turns'));
      await tester.pumpAndSettle();

      final anchorTopAfter = tester.getTopLeft(oldestRecentRow).dy;
      expect(anchorTopAfter, closeTo(anchorTopBefore, 1.0));

      // Tapping Jump to latest returns to the newest live message at bottom.
      await tester.tap(find.byKey(const ValueKey('jump-to-latest-button')));
      await tester.pumpAndSettle();
      expect(scrollableState.position.pixels, closeTo(0.0, 0.5));
      expect(find.byKey(const ValueKey('jump-to-latest-button')), findsNothing);
      expect(find.text('Streaming update while up'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preserves visual viewport anchor across >100-turn bounded eviction and recovers via Jump to latest',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _MultiThreadLongHistoryRuntimeController();
      addTearDown(runtime.closeStreams);

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Long thread A'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('history-a-item-0')), findsOneWidget);

      final timeline = find.byKey(const ValueKey('conversation-timeline'));

      Future<void> scrollToTopOfLoadedWindow() async {
        for (var step = 0; step < 6; step += 1) {
          await tester.drag(timeline, const Offset(0, 2400));
          await tester.pumpAndSettle();
        }
      }

      // Load pages 2..5 (total 100 turns: turn 0..99).
      for (var page = 2; page <= 5; page += 1) {
        await scrollToTopOfLoadedWindow();
        expect(find.text('Load older turns'), findsOneWidget);
        await tester.tap(find.text('Load older turns'));
        await tester.pumpAndSettle();
      }

      await scrollToTopOfLoadedWindow();
      final row99 = find.byKey(const ValueKey('history-a-item-99'));
      expect(row99, findsOneWidget);
      expect(find.text('Load older turns'), findsOneWidget);

      final anchorTopBeforeEviction = tester.getTopLeft(row99).dy;

      // Load page 6 (turns 100..119): crosses >100-turn cap and evicts turns 0..19.
      await tester.tap(find.text('Load older turns'));
      await tester.pumpAndSettle();

      expect(row99, findsOneWidget);
      final anchorTopAfterEviction = tester.getTopLeft(row99).dy;
      expect(anchorTopAfterEviction, closeTo(anchorTopBeforeEviction, 1.0));
      expect(
        find.byKey(const ValueKey('jump-to-latest-button')),
        findsOneWidget,
      );

      // Scrolling up further reveals the newly loaded older turns 100..119 and the Return to newest footer.
      await scrollToTopOfLoadedWindow();
      expect(find.byKey(const ValueKey('history-a-item-119')), findsOneWidget);
      expect(find.text('Return to newest'), findsOneWidget);

      // Tapping Jump to latest from the shifted window reloads the newest turns and lands at bottom.
      await tester.tap(find.byKey(const ValueKey('jump-to-latest-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('history-a-item-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('jump-to-latest-button')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restores cross-thread scroll position by content identity across multi-page history and viewport resize',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _MultiThreadLongHistoryRuntimeController();
      addTearDown(runtime.closeStreams);

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();

      // Open Long thread A and load Page 2 (turns 20..39).
      await tester.tap(find.text('Long thread A'));
      await tester.pumpAndSettle();

      final timeline = find.byKey(const ValueKey('conversation-timeline'));
      for (var step = 0; step < 5; step += 1) {
        await tester.drag(timeline, const Offset(0, 2400));
        await tester.pumpAndSettle();
      }
      expect(find.text('Load older turns'), findsOneWidget);
      await tester.tap(find.text('Load older turns'));
      await tester.pumpAndSettle();

      // Scroll into Page 2 so turn 24 is visible in the viewport.
      await tester.drag(timeline, const Offset(0, 750));
      await tester.pumpAndSettle();

      final targetRow = find.byKey(const ValueKey('history-a-item-24'));
      expect(targetRow, findsOneWidget);
      final targetTopBeforeSwitch = tester.getTopLeft(targetRow).dy;

      // Switch to Short thread B: opens at its latest message.
      await tester.tap(find.text('Short thread B'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('history-b-item-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('jump-to-latest-button')), findsNothing);

      // Resize the window width while on Thread B so text wrapping changes.
      tester.view.physicalSize = const Size(1020, 900);
      await tester.pumpAndSettle();

      // Return to Long thread A: must automatically load Page 2 and align targetRow.
      await tester.tap(find.text('Long thread A'));
      await tester.pumpAndSettle();

      expect(targetRow, findsOneWidget);
      final targetTopAfterReturn = tester.getTopLeft(targetRow).dy;
      expect(targetTopAfterReturn, closeTo(targetTopBeforeSwitch, 1.5));
      expect(
        find.byKey(const ValueKey('jump-to-latest-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'returning from Changes restores the same bounded history position',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _MultiThreadLongHistoryRuntimeController();
      addTearDown(runtime.closeStreams);
      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Long thread A'));
      await tester.pumpAndSettle();

      runtime.showChanges();
      await tester.pumpAndSettle();
      final timeline = find.byKey(const ValueKey('conversation-timeline'));
      for (var step = 0; step < 5; step += 1) {
        await tester.drag(timeline, const Offset(0, 2400));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Load older turns'));
      await tester.pumpAndSettle();
      await tester.drag(timeline, const Offset(0, 750));
      await tester.pumpAndSettle();

      final target = find.byKey(const ValueKey('history-a-item-24'));
      expect(target, findsOneWidget);
      final topBefore = tester.getTopLeft(target).dy;
      final olderPageCalls = runtime.olderTurnPageCalls;
      final changes = find.byKey(const ValueKey('changes-view-button'));
      await tester.tap(changes);
      await tester.pumpAndSettle();
      expect(find.text('+fixture change'), findsOneWidget);
      await tester.tap(changes);
      await tester.pumpAndSettle();

      expect(target, findsOneWidget);
      expect(tester.getTopLeft(target).dy, closeTo(topBefore, 1.5));
      expect(runtime.olderTurnPageCalls, olderPageCalls);

      await tester.tap(changes);
      await tester.pumpAndSettle();
      await tester.drag(timeline, const Offset(0, 430));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(timeline);
      final measured = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('measured-history-');
      });
      final visible =
          [
                for (final element in measured.evaluate())
                  (
                    key: element.widget.key!,
                    top: tester.getTopLeft(find.byKey(element.widget.key!)).dy,
                  ),
              ]
              .where(
                (item) =>
                    item.top >= viewport.top && item.top < viewport.bottom,
              )
              .toList()
            ..sort((first, second) => first.top.compareTo(second.top));
      final readingAnchor = visible.first;

      tester.view.physicalSize = const Size(1191, 865);
      await tester.pumpAndSettle();
      expect(timeline, findsNothing);
      tester.view.physicalSize = const Size(1400, 900);
      await tester.pumpAndSettle();
      expect(find.byKey(readingAnchor.key), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(readingAnchor.key)).dy,
        closeTo(readingAnchor.top, 1.5),
      );
      expect(runtime.olderTurnPageCalls, olderPageCalls);
    },
  );

  testWidgets(
    'deep-history bookmark beyond _maxRestorePages does not fall back to raw pixels and resets deterministically to newest',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _MultiThreadLongHistoryRuntimeController(
        threadATurnCount: 260,
      );
      addTearDown(runtime.closeStreams);

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Long thread A'));
      await tester.pumpAndSettle();

      final timeline = find.byKey(const ValueKey('conversation-timeline'));
      Future<void> scrollToTopOfLoadedWindow() async {
        for (var step = 0; step < 6; step += 1) {
          await tester.drag(timeline, const Offset(0, 2400));
          await tester.pumpAndSettle();
        }
      }

      // Load 11 older pages (Pages 2..12: turns 20..239), exceeding _maxRestorePages (10).
      for (var page = 2; page <= 12; page += 1) {
        await scrollToTopOfLoadedWindow();
        expect(find.text('Load older turns'), findsOneWidget);
        await tester.tap(find.text('Load older turns'));
        await tester.pumpAndSettle();
      }

      // Position viewport inside Page 12 (turns 220..239) so an item beyond the 10-page
      // restore budget (which only covers Pages 1..11 = turns 0..219) is the visible anchor
      // at a non-zero negative scrollPixels offset.
      await scrollToTopOfLoadedWindow();
      await tester.drag(timeline, const Offset(0, -300));
      await tester.pumpAndSettle();
      final deepRow = find.byKey(const ValueKey('history-a-item-235'));
      expect(deepRow, findsOneWidget);
      final scrollableState = tester.state<ScrollableState>(
        find.descendant(of: timeline, matching: find.byType(Scrollable)).first,
      );
      expect(scrollableState.position.pixels, lessThan(-200.0));

      // Switch to Short thread B.
      await tester.tap(find.text('Short thread B'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('history-b-item-0')), findsOneWidget);

      // Return to Long thread A: restore attempts at most _maxRestorePages (10) older page loads,
      // sees that a-turn-235 is still outside the loaded window, discards the stale bookmark
      // instead of clamping old scrollPixels onto the wrong turn, and resets to newest (turn 0).
      runtime.olderTurnPageCalls = 0;
      await tester.tap(find.text('Long thread A'));
      await tester.pumpAndSettle();

      expect(runtime.olderTurnPageCalls, 10);
      expect(find.byKey(const ValueKey('history-a-item-0')), findsOneWidget);
      expect(scrollableState.position.pixels, closeTo(0.0, 0.5));
      expect(find.byKey(const ValueKey('jump-to-latest-button')), findsNothing);

      // Switching away and returning again must not re-attempt the discarded deep bookmark.
      await tester.tap(find.text('Short thread B'));
      await tester.pumpAndSettle();
      runtime.olderTurnPageCalls = 0;
      await tester.tap(find.text('Long thread A'));
      await tester.pumpAndSettle();
      expect(runtime.olderTurnPageCalls, 0);
      expect(find.byKey(const ValueKey('history-a-item-0')), findsOneWidget);
      expect(scrollableState.position.pixels, closeTo(0.0, 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short-thread viewport shift preserves hit-testing, semantics, selection, focus ensureVisible, and dynamic resize',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semanticsHandle = tester.ensureSemantics();

      final runtime = _MultiThreadLongHistoryRuntimeController();
      addTearDown(runtime.closeStreams);

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Short thread B'));
      await tester.pumpAndSettle();

      final userRow = find.byKey(const ValueKey('history-b-user-0'));
      final shortRow = find.byKey(const ValueKey('history-b-item-0'));
      expect(userRow, findsOneWidget);
      expect(shortRow, findsOneWidget);

      // 1. Short thread content is top-aligned (not stuck near bottom at y ~ 800).
      final userRect = tester.getRect(userRow);
      final rowRect = tester.getRect(shortRow);
      expect(userRect.top, lessThan(140));
      expect(rowRect.top, lessThan(260));

      // 2. Global transformed SemanticsNode bounds align with the painted shifted position.
      final semanticsNode = tester.getSemantics(shortRow);
      final globalSemRect = _globalSemanticsRect(semanticsNode);
      expect(globalSemRect.top, closeTo(rowRect.top, 2.0));
      expect(globalSemRect.left, closeTo(rowRect.left, 2.0));
      expect(globalSemRect.height, closeTo(rowRect.height, 2.0));

      // 3. Hit-testing works accurately on interactive controls inside the shifted sliver.
      final copyButton = find.byKey(const ValueKey('assistant-copy-b-item-0'));
      expect(copyButton, findsOneWidget);
      await tester.tap(copyButton);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      // 4. Text selection / tap gesture on SelectableText inside the shifted short viewport
      // resolves coordinates accurately and updates the EditableText selection.
      final userSelectableText = find.descendant(
        of: userRow,
        matching: find.byType(SelectableText),
      );
      expect(userSelectableText, findsOneWidget);
      await tester.tapAt(tester.getCenter(userSelectableText));
      await tester.pump();
      final editableState = tester.state<EditableTextState>(
        find.descendant(
          of: userSelectableText,
          matching: find.byType(EditableText),
        ),
      );
      final selection = editableState.renderEditable.selection;
      expect(selection, isNotNull);
      expect(selection!.isValid, isTrue);
      expect(selection.baseOffset, greaterThan(0));

      // 5. Focus / Scrollable.ensureVisible (getOffsetToReveal) does not yank a visible short-thread item.
      final timeline = find.byKey(const ValueKey('conversation-timeline'));
      final scrollableState = tester.state<ScrollableState>(
        find.descendant(of: timeline, matching: find.byType(Scrollable)).first,
      );
      expect(scrollableState.position.pixels, closeTo(0.0, 0.5));
      await Scrollable.ensureVisible(tester.element(shortRow));
      await tester.pumpAndSettle();
      expect(scrollableState.position.pixels, closeTo(0.0, 0.5));

      // 6. Dynamic resize: short -> compact -> short transitions cleanly.
      tester.view.physicalSize = const Size(1400, 380);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1400, 900);
      await tester.pumpAndSettle();
      expect(scrollableState.position.pixels, closeTo(0.0, 0.5));
      expect(tester.getRect(shortRow).top, lessThan(260));
      expect(tester.takeException(), isNull);
      semanticsHandle.dispose();
    },
  );
}

Rect _globalSemanticsRect(Object semanticsNode) {
  dynamic current = semanticsNode;
  Rect rect = current.rect as Rect;
  while (current != null) {
    final transform = current.transform;
    if (transform != null) {
      rect = MatrixUtils.transformRect(transform, rect);
    }
    current = current.parent;
  }
  return rect;
}

class _StressRuntimeController extends RuntimeController {
  final StreamController<TurnEvent> _turns =
      StreamController<TurnEvent>.broadcast();
  final StreamController<ApprovalEvent> _approvals =
      StreamController<ApprovalEvent>.broadcast();
  final ThreadSummary thread = ThreadSummary(
    id: 'stress-thread',
    sessionId: 'stress-session',
    preview: 'Stress thread',
    cwd: '/workspace',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    status: ThreadRuntimeStatus.idle,
    ephemeral: false,
  );

  @override
  RuntimeSnapshot get snapshot => const RuntimeSnapshot(
    state: RuntimeConnectionState.connected,
    executablePath: '/usr/bin/codex',
    userAgent: 'stress-app-server',
    processId: 42,
  );

  @override
  Stream<TurnEvent> get turnEvents => _turns.stream;

  @override
  Stream<ApprovalEvent> get approvalEvents => _approvals.stream;

  @override
  Future<void> start() async {
    notifyListeners();
  }

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) async =>
      ThreadPage(threads: [thread], nextCursor: null);

  @override
  Future<ThreadSummary> readThread(String threadId) async => thread;

  @override
  Future<ThreadSummary> resumeThread(String threadId) async => thread;

  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) async => thread;

  @override
  Future<void> deleteThread(String threadId) async {}

  @override
  Future<ModelPage> listModels(ModelListQuery query) async =>
      const ModelPage(models: [], nextCursor: null);

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async =>
      HistoryTurnPage(
        turns: [
          for (var turnIndex = 0; turnIndex < 100; turnIndex += 1)
            HistoryTurn(
              id: 'turn-$turnIndex',
              status: TurnRuntimeStatus.completed,
              items: [
                for (var itemIndex = 0; itemIndex < 10; itemIndex += 1)
                  HistoryItem(
                    id: 'item-${turnIndex * 10 + itemIndex}',
                    turnId: 'turn-$turnIndex',
                    kind: HistoryItemKind.assistant,
                    text: 'History item ${turnIndex * 10 + itemIndex}',
                  ),
              ],
            ),
        ],
        nextCursor: null,
      );

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async =>
      const HistoryItemPage(items: [], nextCursor: null);

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) =>
      throw UnimplementedError();

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {}

  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) async {}

  @override
  Future<void> shutdown() async {}

  Future<void> closeStreams() async {
    await _turns.close();
    await _approvals.close();
    dispose();
  }
}

class _PagedHistoryRuntimeController extends RuntimeController {
  final StreamController<TurnEvent> _turns =
      StreamController<TurnEvent>.broadcast(sync: true);
  final StreamController<ApprovalEvent> _approvals =
      StreamController<ApprovalEvent>.broadcast(sync: true);
  final ThreadSummary thread = ThreadSummary(
    id: 'paged-thread',
    sessionId: 'paged-session',
    preview: 'Paged thread',
    cwd: '/workspace',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    status: ThreadRuntimeStatus.idle,
    ephemeral: false,
  );

  void emitStreamingMessage(String itemId, String text) {
    _turns.add(
      AssistantMessageEvent(
        threadId: thread.id,
        turnId: 'live-turn',
        itemId: itemId,
        text: text,
        completed: true,
      ),
    );
  }

  @override
  RuntimeSnapshot get snapshot => const RuntimeSnapshot(
    state: RuntimeConnectionState.connected,
    executablePath: '/usr/bin/codex',
    userAgent: 'paged-app-server',
    processId: 45,
  );

  @override
  Stream<TurnEvent> get turnEvents => _turns.stream;

  @override
  Stream<ApprovalEvent> get approvalEvents => _approvals.stream;

  @override
  Future<void> start() async {
    notifyListeners();
  }

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) async =>
      ThreadPage(threads: [thread], nextCursor: null);

  @override
  Future<ThreadSummary> readThread(String threadId) async => thread;

  @override
  Future<ThreadSummary> resumeThread(String threadId) async => thread;

  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) async => thread;

  @override
  Future<void> deleteThread(String threadId) async {}

  @override
  Future<ModelPage> listModels(ModelListQuery query) async =>
      const ModelPage(models: [], nextCursor: null);

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async {
    if (query.cursor == 'older-page') {
      return HistoryTurnPage(
        turns: [
          for (var i = 9; i >= 0; i -= 1)
            HistoryTurn(
              id: 'older-turn-$i',
              status: TurnRuntimeStatus.completed,
              items: [
                HistoryItem(
                  id: 'older-$i',
                  turnId: 'older-turn-$i',
                  kind: HistoryItemKind.assistant,
                  text: 'Older message $i\nLine 2\nLine 3',
                ),
              ],
            ),
        ],
        nextCursor: null,
      );
    }
    return HistoryTurnPage(
      turns: [
        for (var i = 29; i >= 0; i -= 1)
          HistoryTurn(
            id: 'recent-turn-$i',
            status: TurnRuntimeStatus.completed,
            items: [
              HistoryItem(
                id: 'recent-$i',
                turnId: 'recent-turn-$i',
                kind: HistoryItemKind.assistant,
                text: 'Recent message $i\nLine 2\nLine 3',
              ),
            ],
          ),
      ],
      nextCursor: 'older-page',
    );
  }

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async =>
      const HistoryItemPage(items: [], nextCursor: null);

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) =>
      throw UnimplementedError();

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {}

  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) async {}

  @override
  Future<void> shutdown() async {}

  Future<void> closeStreams() async {
    await _turns.close();
    await _approvals.close();
    dispose();
  }
}

class _MultiThreadLongHistoryRuntimeController extends RuntimeController {
  _MultiThreadLongHistoryRuntimeController({this.threadATurnCount = 140});

  final int threadATurnCount;
  var olderTurnPageCalls = 0;

  final StreamController<TurnEvent> _turns =
      StreamController<TurnEvent>.broadcast(sync: true);
  final StreamController<ApprovalEvent> _approvals =
      StreamController<ApprovalEvent>.broadcast(sync: true);

  void showChanges() => _turns.add(
    TurnDiffUpdatedEvent(
      snapshot: DiffSnapshot(
        threadId: threadA.id,
        turnId: 'a-turn-0',
        files: const [
          DiffFile(
            path: 'fixture.txt',
            additions: 1,
            deletions: 0,
            lines: ['+fixture change'],
            truncated: false,
          ),
        ],
        additions: 1,
        deletions: 0,
        truncated: false,
      ),
    ),
  );

  final ThreadSummary threadA = ThreadSummary(
    id: 'thread-a',
    sessionId: 'session-a',
    preview: 'Long thread A',
    cwd: '/workspace/a',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    status: ThreadRuntimeStatus.idle,
    ephemeral: false,
  );

  final ThreadSummary threadB = ThreadSummary(
    id: 'thread-b',
    sessionId: 'session-b',
    preview: 'Short thread B',
    cwd: '/workspace/b',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    status: ThreadRuntimeStatus.idle,
    ephemeral: false,
  );

  @override
  RuntimeSnapshot get snapshot => const RuntimeSnapshot(
    state: RuntimeConnectionState.connected,
    executablePath: '/usr/bin/codex',
    userAgent: 'multi-thread-app-server',
    processId: 46,
  );

  @override
  Stream<TurnEvent> get turnEvents => _turns.stream;

  @override
  Stream<ApprovalEvent> get approvalEvents => _approvals.stream;

  @override
  Future<void> start() async {
    notifyListeners();
  }

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) async =>
      ThreadPage(threads: [threadA, threadB], nextCursor: null);

  @override
  Future<ThreadSummary> readThread(String threadId) async =>
      threadId == threadB.id ? threadB : threadA;

  @override
  Future<ThreadSummary> resumeThread(String threadId) async =>
      threadId == threadB.id ? threadB : threadA;

  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) async =>
      threadA;

  @override
  Future<void> deleteThread(String threadId) async {}

  @override
  Future<ModelPage> listModels(ModelListQuery query) async =>
      const ModelPage(models: [], nextCursor: null);

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async {
    if (query.threadId == threadB.id) {
      return const HistoryTurnPage(
        turns: [
          HistoryTurn(
            id: 'b-turn-0',
            status: TurnRuntimeStatus.completed,
            items: [
              HistoryItem(
                id: 'b-user-0',
                turnId: 'b-turn-0',
                kind: HistoryItemKind.user,
                text: 'Short thread B user prompt text for selection testing.',
              ),
              HistoryItem(
                id: 'b-item-0',
                turnId: 'b-turn-0',
                kind: HistoryItemKind.assistant,
                text: 'Short thread B single assistant response.',
              ),
            ],
          ),
        ],
        nextCursor: null,
      );
    }

    if (query.cursor != null) {
      olderTurnPageCalls += 1;
    }
    final start = query.cursor == null ? 0 : int.parse(query.cursor!);
    final end = (start + query.limit).clamp(0, threadATurnCount);
    return HistoryTurnPage(
      turns: [
        for (var i = start; i < end; i += 1)
          HistoryTurn(
            id: 'a-turn-$i',
            status: TurnRuntimeStatus.completed,
            items: [
              HistoryItem(
                id: 'a-item-$i',
                turnId: 'a-turn-$i',
                kind: HistoryItemKind.assistant,
                text:
                    'Thread A turn $i detailed summary text that wraps across '
                    'multiple lines when the desktop window is narrowed.\n'
                    'Second line of turn $i.\nThird line of turn $i.',
              ),
            ],
          ),
      ],
      nextCursor: end < threadATurnCount ? '$end' : null,
    );
  }

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async =>
      const HistoryItemPage(items: [], nextCursor: null);

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) =>
      throw UnimplementedError();

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {}

  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) async {}

  @override
  Future<void> shutdown() async {}

  Future<void> closeStreams() async {
    await _turns.close();
    await _approvals.close();
    dispose();
  }
}
