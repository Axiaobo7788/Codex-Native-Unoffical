import 'dart:async';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/app/theme_tokens.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'desktop shell keeps dense hover, selection, and composer geometry',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _ProductRuntimeController();
      addTearDown(runtime.closeStreams);

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('desktop-split-workspace')),
        findsOneWidget,
      );
      final row = find.byKey(const ValueKey('thread-row-controls-thread'));
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, 42);
      final palette = ThemeTokens.of(tester.element(row));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(row));
      await tester.pumpAndSettle();
      expect(
        (tester.widget<AnimatedContainer>(row).decoration! as BoxDecoration)
            .color,
        palette.hover,
      );

      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      expect(
        (tester.widget<AnimatedContainer>(row).decoration! as BoxDecoration)
            .color,
        palette.selected,
      );
      final composer = find.byKey(const ValueKey('composer-surface'));
      expect(composer, findsOneWidget);
      expect(tester.getSize(composer).width, lessThanOrEqualTo(760));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact thread selection opens conversation and Escape closes sidebar',
    (tester) async {
      tester.view.physicalSize = const Size(600, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _ProductRuntimeController();
      addTearDown(runtime.closeStreams);

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('conversation-composer')),
        findsOneWidget,
      );
      expect(find.byTooltip('Show threads'), findsOneWidget);

      await tester.tap(find.byTooltip('Show threads'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show conversation'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('conversation-composer')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dangerous execution overrides require affirmative confirmation',
    (tester) async {
      final runtime = await _pumpSelectedApp(tester);

      await tester.tap(find.text('Defaults'));
      await tester.pumpAndSettle();

      await _chooseDropdown(
        tester,
        key: 'execution-Approval mode',
        option: 'Never ask',
      );
      expect(find.text('Disable approval prompts?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await _chooseDropdown(
        tester,
        key: 'execution-Sandbox',
        option: 'Danger: full access',
      );
      expect(find.text('Allow full filesystem access?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      await _send(tester, 'defaults remain inherited');
      expect(runtime.turnOptions.last.approvalPolicy, isNull);
      expect(runtime.turnOptions.last.sandbox, isNull);

      await tester.tap(find.text('Defaults'));
      await tester.pumpAndSettle();
      await _chooseDropdown(
        tester,
        key: 'execution-Approval mode',
        option: 'Never ask',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Never ask'));
      await tester.pumpAndSettle();
      await _chooseDropdown(
        tester,
        key: 'execution-Sandbox',
        option: 'Danger: full access',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Allow full access'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      await _send(tester, 'confirmed dangerous overrides');
      expect(
        runtime.turnOptions.last.approvalPolicy,
        ApprovalPolicyOverride.never,
      );
      expect(
        runtime.turnOptions.last.sandbox,
        SandboxModeOverride.dangerFullAccess,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('composer sends with Enter and keeps Shift+Enter multiline', (
    tester,
  ) async {
    final runtime = await _pumpSelectedApp(tester);
    final composer = find.byKey(const ValueKey('conversation-composer'));

    await tester.enterText(composer, 'first line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    expect(tester.widget<TextField>(composer).controller?.text, 'first line\n');
    await tester.enterText(composer, 'first line\nsecond line');
    expect(runtime.turnOptions, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(runtime.turnOptions, hasLength(1));
    expect(runtime.turnOptions.single.text, 'first line\nsecond line');
    expect(tester.widget<TextField>(composer).controller?.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large diff view is truncated, virtualized, and file-selectable',
    (tester) async {
      final runtime = await _pumpSelectedApp(tester);
      runtime.emitDiff(
        DiffSnapshot(
          threadId: runtime.thread.id,
          turnId: 'diff-turn',
          files: [
            DiffFile(
              path: 'large.dart',
              additions: 4000,
              deletions: 1,
              lines: [
                for (var index = 0; index < 4000; index += 1) '+line-$index',
              ],
              truncated: true,
            ),
            const DiffFile(
              path: 'second.dart',
              additions: 1,
              deletions: 0,
              lines: ['+second'],
              truncated: false,
            ),
          ],
          additions: 4001,
          deletions: 1,
          truncated: true,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Changes 2'));
      await tester.pumpAndSettle();
      expect(
        find.text('Large diff truncated to the bounded presentation limit.'),
        findsOneWidget,
      );
      expect(find.text('2 file(s)  +4001  -1'), findsOneWidget);
      expect(find.text('+line-0'), findsOneWidget);
      expect(find.text('+line-3999'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('diff-file-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('second.dart  +1 -0').last);
      await tester.pumpAndSettle();
      expect(find.text('+second'), findsOneWidget);
      expect(find.text('+line-0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<_ProductRuntimeController> _pumpSelectedApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final runtime = _ProductRuntimeController();
  addTearDown(runtime.closeStreams);
  await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Controls thread'));
  await tester.pumpAndSettle();
  return runtime;
}

Future<void> _chooseDropdown(
  WidgetTester tester, {
  required String key,
  required String option,
}) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester, String text) async {
  final composer = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.hintText == 'Send a message to Codex',
  );
  await tester.enterText(composer, text);
  await tester.tap(find.byKey(const ValueKey('composer-send-button')));
  await tester.pumpAndSettle();
}

class _ProductRuntimeController extends RuntimeController {
  final StreamController<TurnEvent> _turns =
      StreamController<TurnEvent>.broadcast(sync: true);
  final StreamController<ApprovalEvent> _approvals =
      StreamController<ApprovalEvent>.broadcast(sync: true);
  final List<TurnStartOptions> turnOptions = [];
  final ThreadSummary thread = ThreadSummary(
    id: 'controls-thread',
    sessionId: 'controls-session',
    preview: 'Controls thread',
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
    userAgent: 'controls-app-server',
    processId: 44,
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
  Future<ModelPage> listModels(ModelListQuery query) async => const ModelPage(
    models: [
      CodexModel(
        id: 'default-model',
        model: 'default-model-wire',
        displayName: 'Default model',
        description: 'Fixture model',
        isDefault: true,
        defaultReasoningEffort: 'medium',
        supportedReasoningEfforts: [
          ReasoningEffortOption(value: 'medium', description: 'Medium'),
        ],
      ),
    ],
    nextCursor: null,
  );

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async =>
      const HistoryTurnPage(turns: [], nextCursor: null);

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async =>
      const HistoryItemPage(items: [], nextCursor: null);

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) async {
    turnOptions.add(options);
    return TurnHandle(
      id: 'turn-${turnOptions.length}',
      status: TurnRuntimeStatus.completed,
    );
  }

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

  void emitDiff(DiffSnapshot snapshot) {
    _turns.add(TurnDiffUpdatedEvent(snapshot: snapshot));
  }

  Future<void> closeStreams() async {
    await _turns.close();
    await _approvals.close();
    dispose();
  }
}
