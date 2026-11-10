import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('defers command output and navigates only bounded byte windows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = _OutputRuntimeController();
    addTearDown(runtime.closeStreams);

    await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Output thread'));
    await tester.pumpAndSettle();

    expect(find.text('Load turn details'), findsOneWidget);
    expect(runtime.itemListCalls, 0);
    expect(runtime.itemReadCalls, 0);
    expect(runtime.tailLengths, isEmpty);

    await tester.tap(find.text('Load turn details'));
    await tester.pumpAndSettle();
    expect(runtime.itemListCalls, 1);
    expect(find.text('Fetch output safely'), findsOneWidget);
    expect(runtime.itemReadCalls, 0);

    await tester.tap(find.text('Fetch output safely'));
    await tester.pumpAndSettle();
    expect(runtime.itemReadCalls, 1);
    expect(find.text('View stored output (truncated)'), findsOneWidget);
    expect(runtime.tailLengths, isEmpty);

    await tester.tap(find.text('View stored output (truncated)'));
    await tester.pumpAndSettle();

    expect(find.text('Command output'), findsOneWidget);
    expect(
      find.text(
        'Only 150000 of 200000 bytes were retained by the configured Host limit.',
      ),
      findsOneWidget,
    );
    expect(find.text('Window at byte 84464 of 150000'), findsOneWidget);
    expect(find.textContaining('TAIL'), findsOneWidget);
    expect(runtime.tailLengths, [64 * 1024]);
    expect(runtime.rangeReads, isEmpty);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(find.text('Window at byte 0 of 150000'), findsOneWidget);
    expect(find.textContaining('START'), findsOneWidget);
    expect(runtime.rangeReads.single, (offset: 0, length: 64 * 1024 + 3));

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Window at byte 65536 of 150000'), findsOneWidget);
    expect(runtime.rangeReads.last.offset, 64 * 1024);
    expect(runtime.rangeReads.last.length, 64 * 1024 + 3);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('Window at byte 0 of 150000'), findsOneWidget);
    expect(runtime.rangeReads.last.offset, 0);

    await tester.tap(find.text('Tail'));
    await tester.pumpAndSettle();
    expect(find.text('Window at byte 84464 of 150000'), findsOneWidget);
    expect(runtime.tailLengths, [64 * 1024, 64 * 1024]);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 420);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.tap(find.text('First').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Window at byte 0 of 150000'), findsOneWidget);
    expect(find.textContaining('START').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Close').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Command output'), findsNothing);
  });

  testWidgets('desktop previews only one command with one bounded tail read', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1191, 865);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = _OutputRuntimeController(includeSecondCommand: true);
    addTearDown(runtime.closeStreams);

    await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Output thread'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fetch output safely'));
    await tester.pumpAndSettle();

    final show = find.byTooltip('Show output preview');
    final hide = find.byTooltip('Hide output preview');
    final preview = find.byKey(const ValueKey('command-output-preview-scroll'));
    expect(show, findsNWidgets(2));
    expect(runtime.tailLengths, isEmpty);

    final pendingRead = Completer<void>();
    runtime.tailDelay = pendingRead.future;
    await tester.tap(show.first);
    await tester.pumpAndSettle();
    expect(find.text('Loading output preview…'), findsOneWidget);
    expect(runtime.tailLengths, [4096]);

    await tester.tap(hide);
    await tester.pumpAndSettle();
    await tester.tap(show.last);
    await tester.pumpAndSettle();
    expect(runtime.tailLengths, [4096]);
    pendingRead.complete();
    runtime.tailDelay = null;
    await tester.pumpAndSettle();
    expect(preview, findsNothing);

    await tester.tap(show.first);
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);
    final surface = find.byKey(
      const ValueKey('command-output-preview-surface'),
    );
    final decoration =
        tester.widget<Container>(surface).decoration! as BoxDecoration;
    final theme = OfficialCodexTheme.of(tester.element(surface));
    expect(decoration.color, theme.elevatedSurface);
    expect(
      find.descendant(
        of: surface,
        matching: find.byTooltip('View stored output (truncated)'),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(preview).height, lessThanOrEqualTo(144));
    expect(find.textContaining('TAIL'), findsOneWidget);
    expect(runtime.tailLengths, [4096, 4096]);

    await tester.tap(show);
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);
    expect(hide, findsOneWidget);
    expect(runtime.tailLengths, [4096, 4096, 4096]);
    expect(runtime.rangeReads, isEmpty);

    await tester.tap(find.text('View stored output (truncated)'));
    await tester.pumpAndSettle();
    expect(find.text('Command output'), findsOneWidget);
    expect(runtime.tailLengths.last, 64 * 1024);
    await tester.tap(find.byTooltip('Close').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turn details').hitTestable());
    await tester.pumpAndSettle();
    expect(preview, findsNothing);
    await tester.tap(find.text('Turn details').hitTestable());
    await tester.pumpAndSettle();
    expect(preview, findsNothing);
    expect(runtime.tailLengths, [4096, 4096, 4096, 64 * 1024]);
  });

  testWidgets(
    'previews completed live command output without reading history',
    (tester) async {
      tester.view.physicalSize = const Size(1191, 865);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _OutputRuntimeController();
      addTearDown(runtime.closeStreams);

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Output thread'));
      await tester.pumpAndSettle();
      runtime.emitTurnEvent(
        const TurnStartedEvent(
          threadId: 'output-thread',
          turnId: 'active-turn',
        ),
      );
      runtime.emitTurnEvent(
        const ActivityEvent(
          threadId: 'output-thread',
          turnId: 'active-turn',
          itemId: 'active-command',
          summary: 'Command: fixture still running',
          status: 'inProgress',
          completed: false,
        ),
      );
      await tester.pump();
      final view = find.text('View stored output (truncated)');
      final show = find.byTooltip('Show output preview');
      expect(view, findsNothing);
      expect(show, findsNothing);

      runtime.emitTurnEvent(
        const ActivityEvent(
          threadId: 'output-thread',
          turnId: 'active-turn',
          itemId: 'active-command',
          summary: 'Command: fixture still running',
          status: 'completed',
          completed: true,
          commandOutput: _OutputRuntimeController.descriptor,
        ),
      );
      await tester.pumpAndSettle();
      expect(view, findsNothing);
      expect(show, findsOneWidget);
      expect(runtime.tailLengths, isEmpty);
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(find.text('Last 4096 stored bytes'), findsOneWidget);
      expect(runtime.tailLengths, [4096]);
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(find.text('Window at byte 84464 of 150000'), findsOneWidget);
      expect(runtime.tailLengths, [4096, 64 * 1024]);
      expect(runtime.itemListCalls, 0);
      expect(runtime.itemReadCalls, 0);

      await tester.tap(find.byTooltip('Close').hitTestable());
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(600, 780);
      await tester.pumpAndSettle();
      expect(show, findsNothing);
      expect(find.text('Last 4096 stored bytes'), findsNothing);
      await tester.tap(view.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Command output'), findsOneWidget);
      expect(runtime.tailLengths, [4096, 64 * 1024, 64 * 1024]);
    },
  );

  testWidgets('live eviction releases the shared saved-command preview slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1191, 865);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = _OutputRuntimeController();
    addTearDown(runtime.closeStreams);

    await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Output thread'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fetch output safely'));
    await tester.pumpAndSettle();
    runtime.emitTurnEvent(
      const TurnStartedEvent(threadId: 'output-thread', turnId: 'active-turn'),
    );
    runtime.emitTurnEvent(
      const ActivityEvent(
        threadId: 'output-thread',
        turnId: 'active-turn',
        itemId: 'active-command',
        summary: 'Command: live fixture',
        status: 'completed',
        completed: true,
        commandOutput: _OutputRuntimeController.descriptor,
      ),
    );
    await tester.pumpAndSettle();

    final show = find.byTooltip('Show output preview');
    final hide = find.byTooltip('Hide output preview');
    final preview = find.byKey(const ValueKey('command-output-preview-scroll'));
    expect(show, findsNWidgets(2));
    final liveToggle = find.descendant(
      of: find.byKey(const ValueKey('measured-live-active-command')),
      matching: show,
    );
    final savedToggle = find.descendant(
      of: find.byKey(const ValueKey('measured-history-output-command')),
      matching: show,
    );
    final pending = Completer<void>();
    runtime.tailDelay = pending.future;
    await tester.tap(liveToggle);
    await tester.pumpAndSettle();
    expect(hide, findsOneWidget);
    await tester.tap(savedToggle);
    await tester.pumpAndSettle();
    expect(runtime.tailLengths, [4096]);

    runtime.emitTurnEvent(
      const ActivityEvent(
        threadId: 'output-thread',
        turnId: 'active-turn',
        itemId: 'newer-command',
        summary: 'Command: newer fixture',
        status: 'completed',
        completed: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(hide, findsNothing);
    expect(find.text('Loading output preview…'), findsNothing);
    pending.complete();
    runtime.tailDelay = null;
    await tester.pumpAndSettle();
    expect(preview, findsNothing);

    await tester.tap(savedToggle);
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);
    expect(runtime.tailLengths, [4096, 4096]);
  });
}

class _OutputRuntimeController extends RuntimeController {
  _OutputRuntimeController({this.includeSecondCommand = false})
    : outputBytes = _makeOutput();

  final bool includeSecondCommand;
  Future<void>? tailDelay;

  static const descriptor = OutputDescriptor(
    reference: 'bounded-output-ref',
    bytes: 200000,
    storedBytes: 150000,
    truncated: true,
    available: true,
  );

  final Uint8List outputBytes;
  final StreamController<TurnEvent> _turns =
      StreamController<TurnEvent>.broadcast();
  final StreamController<ApprovalEvent> _approvals =
      StreamController<ApprovalEvent>.broadcast();
  final ThreadSummary thread = ThreadSummary(
    id: 'output-thread',
    sessionId: 'output-session',
    preview: 'Output thread',
    cwd: '/workspace',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    status: ThreadRuntimeStatus.idle,
    ephemeral: false,
  );
  final List<int> tailLengths = [];
  final List<({int offset, int length})> rangeReads = [];
  var itemListCalls = 0;
  var itemReadCalls = 0;

  @override
  RuntimeSnapshot get snapshot => const RuntimeSnapshot(
    state: RuntimeConnectionState.connected,
    executablePath: '/usr/bin/codex',
    userAgent: 'output-app-server',
    processId: 43,
  );

  @override
  Stream<TurnEvent> get turnEvents => _turns.stream;

  void emitTurnEvent(TurnEvent event) => _turns.add(event);

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
          HistoryTurn(
            id: 'output-turn',
            status: TurnRuntimeStatus.completed,
            items: const [
              HistoryItem(
                id: 'output-command',
                turnId: 'output-turn',
                kind: HistoryItemKind.activity,
                text: 'Generated bounded output',
                isCommand: true,
              ),
            ],
          ),
        ],
        nextCursor: null,
      );

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async {
    itemListCalls += 1;
    return HistoryItemPage(
      items: [
        const HistoryItem(
          id: 'output-command',
          turnId: 'output-turn',
          kind: HistoryItemKind.activity,
          text: 'Generated bounded output',
          outputDeferred: true,
          isCommand: true,
        ),
        if (includeSecondCommand)
          const HistoryItem(
            id: 'another-output-command',
            turnId: 'output-turn',
            kind: HistoryItemKind.activity,
            text: 'Generated another bounded output',
            output: descriptor,
            isCommand: true,
          ),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<List<HistoryItem>> readHistoryItems({
    required String threadId,
    required String turnId,
    required List<String> itemIds,
  }) async {
    itemReadCalls += 1;
    return const [
      HistoryItem(
        id: 'output-command',
        turnId: 'output-turn',
        kind: HistoryItemKind.activity,
        text: 'Generated bounded output',
        output: descriptor,
        isCommand: true,
      ),
    ];
  }

  @override
  Future<OutputChunk> readOutputRange({
    required String reference,
    required int offset,
    required int length,
  }) async {
    rangeReads.add((offset: offset, length: length));
    return _chunk(reference, offset, length);
  }

  @override
  Future<OutputChunk> readOutputTail({
    required String reference,
    required int length,
  }) async {
    tailLengths.add(length);
    await tailDelay;
    return _chunk(reference, outputBytes.length - length, length);
  }

  OutputChunk _chunk(String reference, int offset, int length) {
    final end = (offset + length).clamp(0, outputBytes.length);
    return OutputChunk(
      reference: reference,
      offset: offset,
      data: Uint8List.fromList(outputBytes.sublist(offset, end)),
      bytes: descriptor.bytes,
      storedBytes: descriptor.storedBytes,
      truncated: descriptor.truncated,
      eof: end == outputBytes.length,
    );
  }

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

  static Uint8List _makeOutput() {
    final bytes = Uint8List(descriptor.storedBytes);
    for (var index = 0; index < bytes.length; index += 1) {
      bytes[index] = 97 + index % 26;
    }
    bytes.setRange(0, 5, ascii.encode('START'));
    bytes.setRange(bytes.length - 4, bytes.length, ascii.encode('TAIL'));
    return bytes;
  }
}
