import 'dart:async';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Official Desktop Convergence Geometry (Multi-Viewport)', () {
    final viewports = [
      (
        name: '1920x1080 DPR 1.0 Full-HD',
        width: 1920.0,
        height: 1080.0,
        dpr: 1.0,
      ),
      (
        name: '1440x900 DPR 1.0 Standard Laptop',
        width: 1440.0,
        height: 900.0,
        dpr: 1.0,
      ),
      (
        name: '2560x1440 DPR 1.25 QHD Scaled',
        width: 2560.0,
        height: 1440.0,
        dpr: 1.25,
      ),
      (
        name: '2560x1440 DPR 2.0 Retina/HiDPI',
        width: 2560.0,
        height: 1440.0,
        dpr: 2.0,
      ),
    ];

    for (final vp in viewports) {
      testWidgets('validates official geometry on ${vp.name}', (tester) async {
        tester.view.physicalSize = Size(vp.width, vp.height);
        tester.view.devicePixelRatio = vp.dpr;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final runtime = _GeometryTestRuntimeController();
        addTearDown(runtime.closeStreams);

        await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
        await tester.pumpAndSettle();

        // 1. Assert Titlebar geometry: height exactly 46px
        final titlebarFinder = find.byKey(const ValueKey('app_shell_titlebar'));
        expect(titlebarFinder, findsOneWidget);
        expect(
          tester.getSize(titlebarFinder).height,
          equals(OfficialCodexTheme.titlebarHeight),
        );
        expect(tester.getSize(titlebarFinder).height, equals(46.0));

        // 2. Assert Sidebar width: exactly 260px
        final sidebarFinder = find.byKey(const ValueKey('app_shell_sidebar'));
        expect(sidebarFinder, findsOneWidget);
        expect(
          tester.getSize(sidebarFinder).width,
          equals(OfficialCodexTheme.sidebarWidth),
        );
        expect(tester.getSize(sidebarFinder).width, equals(260.0));

        // 3. Assert Inset workspace card: top-left corner radius 12px
        final insetCardFinder = find.byKey(
          const ValueKey('inset_workspace_card'),
        );
        expect(insetCardFinder, findsOneWidget);
        final container = tester.widget<Container>(insetCardFinder);
        final boxDecoration = container.decoration as BoxDecoration;
        expect(
          boxDecoration.borderRadius,
          equals(BorderRadius.circular(OfficialCodexTheme.mainSurfaceRadius)),
        );

        // Select thread to view conversation timeline
        await tester.tap(find.text('Geometry Test Thread'));
        await tester.pumpAndSettle();

        // 4. Assert Thread header bar: height exactly 46px
        final threadHeaderFinder = find.byKey(
          const ValueKey('thread_header_bar'),
        );
        expect(threadHeaderFinder, findsOneWidget);
        expect(
          tester.getSize(threadHeaderFinder).height,
          equals(OfficialCodexTheme.headerHeight),
        );
        expect(tester.getSize(threadHeaderFinder).height, equals(46.0));

        // 5. Assert Conversation reading column: bounded to <= 704px
        final columnFinder = find.byKey(
          const ValueKey('conversation_reading_column'),
        );
        expect(columnFinder, findsOneWidget);
        expect(
          tester.getSize(columnFinder).width,
          lessThanOrEqualTo(OfficialCodexTheme.maxContentWidth),
        );
        expect(tester.getSize(columnFinder).width, lessThanOrEqualTo(704.0));

        // 6. Assert Floating Composer: bounded to <= 704px with 24px radius
        final composerFinder = find.byKey(const ValueKey('floating_composer'));
        expect(composerFinder, findsOneWidget);
        expect(
          tester.getSize(composerFinder).width,
          lessThanOrEqualTo(OfficialCodexTheme.maxContentWidth),
        );
        expect(tester.getSize(composerFinder).width, lessThanOrEqualTo(704.0));

        // 7. Verify user message bubble max width factor (75% of reading column = 528px)
        final bubbleFinder = find.text('Hello Codex from geometry test suite!');
        expect(bubbleFinder, findsOneWidget);
        final bubbleSize = tester.getSize(bubbleFinder);
        expect(
          bubbleSize.width,
          lessThanOrEqualTo(
            OfficialCodexTheme.maxContentWidth *
                OfficialCodexTheme.maxUserBubbleWidthFactor,
          ),
        );
        expect(bubbleSize.width, lessThanOrEqualTo(528.0));

        // 8. Verify Presentation Detail Mode selector is present and functional
        expect(find.text('Prose'), findsOneWidget);
        expect(find.text('Commands'), findsOneWidget);
        expect(find.text('Execution'), findsOneWidget);

        await tester.tap(find.text('Prose'));
        await tester.pumpAndSettle();
        expect(
          find.text('Hello Codex from geometry test suite!'),
          findsOneWidget,
        );

        // 9. Verify composer accepts input and send button is rendered
        await tester.enterText(
          find.byKey(const ValueKey('conversation-composer')),
          'Testing input geometry',
        );
        expect(find.text('Testing input geometry'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('composer-send-button')),
          findsOneWidget,
        );
      });
    }
  });
}

class _GeometryTestRuntimeController extends RuntimeController {
  final StreamController<TurnEvent> _turns =
      StreamController<TurnEvent>.broadcast(sync: true);
  final StreamController<ApprovalEvent> _approvals =
      StreamController<ApprovalEvent>.broadcast(sync: true);

  final ThreadSummary thread = ThreadSummary(
    id: 'geom-thread-1',
    sessionId: 'geom-session-1',
    preview: 'Geometry Test Thread',
    cwd: '/workspace/project',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    status: ThreadRuntimeStatus.idle,
    ephemeral: false,
  );

  List<HistoryTurn> get historyTurns => const [
    HistoryTurn(
      id: 'turn-geom-1',
      status: TurnRuntimeStatus.completed,
      items: [
        HistoryItem(
          id: 'item-user-1',
          turnId: 'turn-geom-1',
          kind: HistoryItemKind.user,
          text: 'Hello Codex from geometry test suite!',
        ),
        HistoryItem(
          id: 'item-assistant-1',
          turnId: 'turn-geom-1',
          kind: HistoryItemKind.assistant,
          text: 'Acknowledged geometry verified.',
        ),
      ],
    ),
  ];

  @override
  RuntimeSnapshot get snapshot => const RuntimeSnapshot(
    state: RuntimeConnectionState.connected,
    executablePath: '/usr/bin/codex',
    userAgent: 'codex-desktop-official',
    processId: 101,
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
        id: 'gpt-5-codex',
        model: 'gpt-5-codex-wire',
        displayName: 'GPT-5 Codex',
        description: 'Official model',
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
      HistoryTurnPage(turns: historyTurns, nextCursor: null);

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async =>
      const HistoryItemPage(items: [], nextCursor: null);

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) async =>
      const TurnHandle(id: 'turn-geom-2', status: TurnRuntimeStatus.completed);

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
