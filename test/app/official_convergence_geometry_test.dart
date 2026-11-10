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
import 'package:flutter/services.dart';
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
      (
        name: '780x800 near split threshold',
        width: 780.0,
        height: 800.0,
        dpr: 1.0,
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

        // The app toolbar spans all columns above the persistent rail and page.
        final titlebarFinder = find.byKey(const ValueKey('app_shell_titlebar'));
        expect(titlebarFinder, findsOneWidget);
        expect(find.text('Codex Native'), findsNothing);
        final titlebarRect = tester.getRect(titlebarFinder);
        expect(
          titlebarRect.size,
          Size(vp.width / vp.dpr, OfficialCodexTheme.shellToolbarHeight),
        );

        final rail = tester.getRect(
          find.byKey(const ValueKey('app-shell-navigation-rail')),
        );
        final pageFinder = find.byKey(const ValueKey('app-shell-page-surface'));
        final page = tester.getRect(pageFinder);
        expect(rail.left, titlebarRect.left);
        expect(
          rail.top,
          titlebarRect.bottom + OfficialCodexTheme.shellPageTopInset,
        );
        expect(rail.width, OfficialCodexTheme.navigationRailWidth);
        expect(page.top, rail.top);
        expect(page.left, rail.right);
        expect(page.right, titlebarRect.right);
        final pageDecoration =
            tester.widget<Container>(pageFinder).decoration as BoxDecoration;
        expect(
          pageDecoration.borderRadius,
          BorderRadius.circular(OfficialCodexTheme.mainSurfaceRadius),
        );

        final sidebarFinder = find.byKey(const ValueKey('app_shell_sidebar'));
        final sidebar = tester.getRect(sidebarFinder);
        final workspace = tester.getRect(
          find.byKey(const ValueKey('app-shell-workspace')),
        );
        expect(sidebar.topLeft, page.topLeft);
        expect(sidebar.width, OfficialCodexTheme.sidebarWidth);
        expect(workspace.left, sidebar.right);
        expect(workspace.top, sidebar.top);
        expect(workspace.right, page.right);
        expect(
          workspace.left - rail.left,
          OfficialCodexTheme.desktopLeftPanelWidth,
        );
        expect(find.text('New chat'), findsOneWidget);
        expect(find.text('Projects'), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('codex-sidebar-header')))
              .height,
          OfficialCodexTheme.contextualSidebarHeaderHeight,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('codex-sidebar-header')),
            matching: find.byKey(const ValueKey('thread-search-toggle')),
          ),
          findsOneWidget,
        );
        final projectHeadingFinder = find.text('project');
        final threadRowFinder = find.byKey(
          const ValueKey('thread-row-geom-thread-1'),
        );
        expect(projectHeadingFinder, findsOneWidget);
        expect(threadRowFinder, findsOneWidget);
        expect(
          tester.getTopLeft(threadRowFinder).dx,
          greaterThan(tester.getTopLeft(sidebarFinder).dx + 14.0),
        );

        // Home keeps a centered composer and hides thread detail modes.
        final emptyHeaderContainer = tester.widget<Container>(
          find.byKey(const ValueKey('thread_header_bar')),
        );
        expect(
          (emptyHeaderContainer.decoration as BoxDecoration).border,
          isNull,
        );
        expect(find.text('Prose'), findsNothing);
        final heroHeading = find.byKey(const ValueKey('home-hero-heading'));
        expect(
          find.descendant(
            of: heroHeading,
            matching: find.byKey(const ValueKey('home-project-selector')),
          ),
          findsOneWidget,
        );
        final heroTitleBottom = tester.getBottomLeft(heroHeading).dy;
        final heroComposerTop = tester
            .getTopLeft(find.byKey(const ValueKey('floating_composer')))
            .dy;
        expect(heroComposerTop - heroTitleBottom, lessThan(80.0));
        final composerSurface = tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('composer-surface')),
        );
        expect(
          (composerSurface.decoration as BoxDecoration).color,
          equals(OfficialCodexThemeData.light.elevatedSurface),
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
        final folder = find.descendant(
          of: threadHeaderFinder,
          matching: find.byIcon(Icons.folder_outlined),
        );
        final workspaceTitle = find.descendant(
          of: threadHeaderFinder,
          matching: find.text('Geometry Test Thread'),
        );
        expect(
          tester.getTopLeft(folder).dx,
          lessThan(tester.getTopLeft(workspaceTitle).dx),
        );

        // The current desktop reading column is bounded to 42rem.
        final columnFinder = find.byKey(
          const ValueKey('conversation_reading_column'),
        );
        expect(columnFinder, findsOneWidget);
        expect(
          tester.getSize(columnFinder).width,
          lessThanOrEqualTo(OfficialCodexTheme.maxContentWidth),
        );
        expect(tester.getSize(columnFinder).width, lessThanOrEqualTo(672.0));

        // The active composer shares the reading width and groups controls right.
        final composerFinder = find.byKey(const ValueKey('floating_composer'));
        expect(composerFinder, findsOneWidget);
        expect(
          tester.getSize(composerFinder).width,
          lessThanOrEqualTo(OfficialCodexTheme.maxContentWidth),
        );
        final field = find.byKey(const ValueKey('conversation-composer'));
        final attach = find.byKey(const ValueKey('composer-attach-button'));
        final model = find.byKey(const ValueKey('composer-model-pill'));
        final permissions = find.byKey(
          const ValueKey('execution-settings-button'),
        );
        final send = find.byKey(const ValueKey('composer-send-button'));
        expect(
          tester.getCenter(attach).dx,
          lessThan(tester.getCenter(field).dx),
        );
        expect(
          tester.getCenter(field).dx,
          lessThan(tester.getCenter(model).dx),
        );
        expect(
          tester.getCenter(model).dx,
          lessThan(tester.getCenter(permissions).dx),
        );
        expect(
          tester.getCenter(permissions).dx,
          lessThan(tester.getCenter(send).dx),
        );
        final activeSurface = tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('composer-surface')),
        );
        expect(
          (activeSurface.decoration as BoxDecoration).borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerRadiusPill),
        );

        // User bubbles remain capped at 75% of the reading column.
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

        // Timeline detail stays available in a compact header action.
        final detailsButton = find.byKey(
          const ValueKey('timeline-details-button'),
        );
        await tester.tap(detailsButton);
        await tester.pumpAndSettle();
        expect(find.text('Prose'), findsOneWidget);
        expect(find.text('Commands'), findsOneWidget);
        expect(find.text('Execution'), findsOneWidget);

        // In Commands (default): intermediate command 2 is collapsed under work divider
        expect(find.text('Worked for 42s'), findsOneWidget);
        expect(find.text('Command: flutter test'), findsOneWidget);
        expect(find.text('Command: cargo test'), findsNothing);

        // In Execution: intermediate command 2 expands inline
        await tester.tap(find.text('Execution'));
        await tester.pumpAndSettle();
        expect(find.text('Command: flutter test'), findsOneWidget);
        expect(find.text('Command: cargo test'), findsOneWidget);

        // In Prose: both commands are filtered out, user and assistant messages remain
        await tester.tap(detailsButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Prose'));
        await tester.pumpAndSettle();
        expect(find.text('Command: flutter test'), findsNothing);
        expect(find.text('Command: cargo test'), findsNothing);
        expect(
          find.text('Hello Codex from geometry test suite!'),
          findsOneWidget,
        );
        expect(find.text('Acknowledged geometry verified.'), findsOneWidget);

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

    testWidgets('opens the Home project chooser from keyboard focus', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1191, 865);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _GeometryTestRuntimeController();
      addTearDown(runtime.closeStreams);
      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();

      final selector = tester.element(
        find.byKey(const ValueKey('home-project-selector')),
      );
      bool selectorHasFocus() {
        var focused = false;
        (FocusManager.instance.primaryFocus?.context as Element?)
            ?.visitAncestorElements((ancestor) {
              focused = identical(ancestor, selector);
              return !focused;
            });
        return focused;
      }

      final composer = find.byKey(const ValueKey('conversation-composer'));
      await tester.enterText(composer, 'Draft for the next project');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      for (var i = 0; i < 12 && !selectorHasFocus(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(selectorHasFocus(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Select project directory'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        '  /workspace/chosen-project  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Select project directory'), findsNothing);
      expect(find.text('chosen-project?'), findsOneWidget);
      expect(find.text('Draft for the next project'), findsOneWidget);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(760, 800);
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.byKey(const ValueKey('home-project-selector')))
            .height,
        greaterThan(44),
      );
      expect(
        find.byKey(const ValueKey('composer-model-pill')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('execution-settings-button')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets(
      'resizes the sidebar and preserves the draft across a compact window',
      (tester) async {
        tester.view.physicalSize = const Size(1191, 865);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final runtime = _GeometryTestRuntimeController();
        addTearDown(runtime.closeStreams);
        await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Geometry Test Thread'));
        await tester.pumpAndSettle();

        final composer = find.byKey(const ValueKey('conversation-composer'));
        final workspace = find.byKey(const ValueKey('app-shell-workspace'));
        final handle = find.byKey(const ValueKey('sidebar-resize-handle'));
        await tester.enterText(composer, 'Draft through sidebar resize');

        await tester.drag(handle, const Offset(-130, 0));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(workspace).dx,
          OfficialCodexTheme.desktopLeftPanelMinWidth,
        );

        Focus.of(tester.element(handle)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(workspace).dx,
          greaterThan(OfficialCodexTheme.desktopLeftPanelMinWidth),
        );

        await tester.drag(handle, const Offset(350, 0));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(workspace).dx,
          OfficialCodexTheme.sidebarMaxWidth,
        );

        tester.view.physicalSize = const Size(760, 800);
        await tester.pumpAndSettle();
        expect(find.text('Draft through sidebar resize'), findsOneWidget);

        tester.view.physicalSize = const Size(720, 800);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('compact-workspace')), findsOneWidget);
        expect(handle, findsNothing);
        expect(find.text('Draft through sidebar resize'), findsOneWidget);

        tester.view.physicalSize = const Size(1191, 865);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(workspace).dx,
          OfficialCodexTheme.sidebarMaxWidth,
        );
        expect(find.text('Draft through sidebar resize'), findsOneWidget);
      },
    );

    testWidgets(
      'validates compact workspace geometry on 720x800 compact viewport (< 760px breakpoint)',
      (tester) async {
        tester.view.physicalSize = const Size(720.0, 800.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final runtime = _GeometryTestRuntimeController();
        addTearDown(runtime.closeStreams);

        await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
        await tester.pumpAndSettle();

        // Below 760px breakpoint, desktop split workspace is inactive and compact workspace is active
        expect(
          find.byKey(const ValueKey('desktop-split-workspace')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('compact-workspace')), findsOneWidget);
      },
    );
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

  List<HistoryTurn> get historyTurns => [
    HistoryTurn(
      id: 'turn-geom-1',
      status: TurnRuntimeStatus.completed,
      startedAt: DateTime.utc(2026, 1, 1, 12, 0, 0),
      completedAt: DateTime.utc(2026, 1, 1, 12, 0, 42),
      items: const [
        HistoryItem(
          id: 'item-user-1',
          turnId: 'turn-geom-1',
          kind: HistoryItemKind.user,
          text: 'Hello Codex from geometry test suite!',
        ),
        HistoryItem(
          id: 'item-cmd-1',
          turnId: 'turn-geom-1',
          kind: HistoryItemKind.activity,
          text: 'Command: flutter test',
          isCommand: true,
        ),
        HistoryItem(
          id: 'item-cmd-2',
          turnId: 'turn-geom-1',
          kind: HistoryItemKind.activity,
          text: 'Command: cargo test',
          isCommand: true,
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
