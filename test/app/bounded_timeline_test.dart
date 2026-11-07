import 'dart:async';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
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

      // Streaming updates while scrolled up must not yank the user back to bottom.
      runtime.emitStreamingMessage('live-item-1', 'Streaming update while up');
      await tester.pump(const Duration(milliseconds: 200));
      expect(scrollableState.position.pixels, scrolledOffset);
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
