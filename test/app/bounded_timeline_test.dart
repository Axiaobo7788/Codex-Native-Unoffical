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
  testWidgets('builds only visible rows from a 1000-item history projection', (
    tester,
  ) async {
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
    expect(find.byKey(const ValueKey('history-item-999')), findsNothing);
    expect(tester.takeException(), isNull);
  });
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
