import 'dart:async';
import 'dart:io';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_composer.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_sidebar_row.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_menu.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/app/theme_tokens.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/domain/user_input_models.dart';
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
      expect(tester.getSize(row).height, 36.0);
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
      BoxBorder? composerBorder() =>
          (tester.widget<AnimatedContainer>(composer).decoration
                  as BoxDecoration)
              .border;
      expect(composer, findsOneWidget);
      expect(tester.getSize(composer).width, lessThanOrEqualTo(760));
      final focusedBorder = composerBorder();
      expect(
        tester.widget<CodexComposer>(find.byType(CodexComposer)).isFocused,
        isTrue,
      );
      await tester.tap(
        find.byKey(const ValueKey('thread-actions-menu-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find in conversation'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CodexComposer>(find.byType(CodexComposer)).isFocused,
        isFalse,
      );
      expect(composerBorder(), focusedBorder);
      await tester.tap(find.byKey(const ValueKey('conversation-composer')));
      await tester.pump();
      expect(
        tester.widget<CodexComposer>(find.byType(CodexComposer)).isFocused,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('conversation-search-close')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('project new chat shortcut is reachable from keyboard focus', (
    tester,
  ) async {
    final runtime = await _pumpSelectedApp(tester);
    final project = find.widgetWithText(CodexSidebarRow, 'workspace');
    final action = find.byKey(const ValueKey('project-new-thread-/workspace'));
    final visibility = find.byKey(
      const ValueKey('project-actions-visibility-/workspace'),
    );
    expect(project, findsOneWidget);
    expect(tester.widget<Opacity>(visibility).opacity, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    final projectFocus = Focus.of(
      tester.element(
        find
            .descendant(of: project, matching: find.byType(GestureDetector))
            .first,
      ),
    );
    projectFocus.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(visibility).opacity, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(visibility).opacity, 1);
    if (Platform.isLinux || Platform.isMacOS) {
      final item = find.text(
        Platform.isMacOS ? 'Reveal in Finder' : 'Open in File Manager',
      );
      final menu = find.byKey(const ValueKey('project-menu-/workspace'));
      expect(tester.getCenter(menu).dx, lessThan(tester.getCenter(action).dx));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(item, findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(CodexMenu<VoidCallback>)).dx,
        closeTo(tester.getTopLeft(menu).dx, 1),
      );
      expect(tester.widget<Opacity>(visibility).opacity, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(item, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    final actionFocus = Focus.of(
      tester.element(
        find
            .descendant(of: action, matching: find.byType(GestureDetector))
            .last,
      ),
    );
    expect(actionFocus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(runtime.startedThreadCwds, ['/workspace']);
  });

  testWidgets(
    'secondary click opens project and thread context menus while collapsed project row replaces raw count with status indicator',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _ProductRuntimeController()
        ..extraThreads = [
          ThreadSummary(
            id: 'unread-thread',
            sessionId: 'unread-session',
            preview: 'Unread project thread',
            cwd: '/workspace-unread',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            status: ThreadRuntimeStatus.idle,
            ephemeral: false,
            readReceipt: const ThreadReadReceipt(revision: '1', unread: true),
          ),
          ThreadSummary(
            id: 'running-thread',
            sessionId: 'running-session',
            preview: 'Running project thread',
            cwd: '/workspace-running',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            status: ThreadRuntimeStatus.active,
            ephemeral: false,
          ),
        ];
      addTearDown(runtime.closeStreams);
      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final projectRow = find.widgetWithText(CodexSidebarRow, 'workspace');
      final threadRow = find.byKey(
        const ValueKey('thread-row-controls-thread'),
      );
      expect(projectRow, findsOneWidget);
      expect(threadRow, findsOneWidget);

      if (Platform.isLinux || Platform.isMacOS) {
        final projectMenuItem = find.text(
          Platform.isMacOS ? 'Reveal in Finder' : 'Open in File Manager',
        );
        final clickPoint = tester.getTopLeft(projectRow) + const Offset(28, 18);
        await tester.tapAt(clickPoint, buttons: kSecondaryMouseButton);
        await tester.pump();
        expect(projectMenuItem, findsOneWidget);
        expect(tester.widget<CodexSidebarRow>(projectRow).highlighted, isTrue);
        expect(
          tester.getTopLeft(find.byType(CodexMenu<VoidCallback>)).dx,
          closeTo(clickPoint.dx, 1.0),
        );
        expect(
          tester.getTopLeft(find.byType(CodexMenu<VoidCallback>)).dy,
          closeTo(clickPoint.dy, 1.0),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(projectMenuItem, findsNothing);
      }

      final threadClickPoint =
          tester.getTopLeft(threadRow) + const Offset(36, 18);
      await tester.tapAt(threadClickPoint, buttons: kSecondaryMouseButton);
      await tester.pump();
      expect(find.text('Rename thread'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(CodexMenu<String>)).dx,
        closeTo(threadClickPoint.dx, 1.0),
      );
      expect(
        tester.getTopLeft(find.byType(CodexMenu<String>)).dy,
        closeTo(threadClickPoint.dy, 1.0),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Rename thread'), findsNothing);

      // ContextMenu and Shift+F10 on focused thread row open menu at row bottomLeft.
      final threadFocus = Focus.of(tester.element(threadRow));
      threadFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pump();
      expect(find.text('Rename thread'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(CodexMenu<String>)).dx,
        closeTo(tester.getBottomLeft(threadRow).dx, 1.0),
      );
      expect(
        tester.getTopLeft(find.byType(CodexMenu<String>)).dy,
        closeTo(tester.getBottomLeft(threadRow).dy, 1.0),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Rename thread'), findsNothing);

      threadFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(find.text('Rename thread'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(CodexMenu<String>)).dx,
        closeTo(tester.getBottomLeft(threadRow).dx, 1.0),
      );
      expect(
        tester.getTopLeft(find.byType(CodexMenu<String>)).dy,
        closeTo(tester.getBottomLeft(threadRow).dy, 1.0),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Rename thread'), findsNothing);

      // Right-clicking near a short viewport bottom clamps the menu inside the viewport.
      tester.view.physicalSize = const Size(1440, 320);
      await tester.pump();
      await tester.tapAt(threadClickPoint, buttons: kSecondaryMouseButton);
      await tester.pump();
      final clampedMenuRect = tester.getRect(find.byType(CodexMenu<String>));
      expect(clampedMenuRect.top, greaterThanOrEqualTo(8.0));
      expect(clampedMenuRect.bottom, lessThanOrEqualTo(312.0));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pump();

      // Collapse idle/unread/running projects and verify status indicator priority.
      await tester.tap(projectRow);
      await tester.tap(
        find.widgetWithText(CodexSidebarRow, 'workspace-unread'),
      );
      await tester.tap(
        find.widgetWithText(CodexSidebarRow, 'workspace-running'),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('thread-row-controls-thread')),
        findsNothing,
      );
      expect(
        find.descendant(of: projectRow, matching: find.text('1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('project-unread-/workspace-unread')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project-running-/workspace-running')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'compact thread selection and reselection open conversation while refresh or failed read keeps Threads open and Escape closes sidebar',
    (tester) async {
      tester.view.physicalSize = const Size(720, 800);
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

      // Reopen compact Threads and click the already-selected thread row:
      // closes Threads and returns to the conversation.
      await tester.tap(find.byTooltip('Show threads'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show conversation'), findsOneWidget);
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('conversation-composer')),
        findsOneWidget,
      );

      // Reopen compact Threads; refreshing threads preserves selection without
      // closing the Threads sidebar.
      await tester.tap(find.byTooltip('Show threads'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show conversation'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh threads'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show conversation'), findsOneWidget);
      expect(find.byKey(const ValueKey('conversation-composer')), findsNothing);

      // A failed readThread on reselection keeps Threads open so the error is visible.
      runtime.failNextReadThread = true;
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show conversation'), findsOneWidget);
      expect(find.byKey(const ValueKey('conversation-composer')), findsNothing);
      expect(
        find.textContaining('Simulated thread read failure'),
        findsOneWidget,
      );

      // Escape still closes the compact Threads sidebar.
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
    'responsive resize and compact navigation preserve active conversation, unsent draft, and attachments while explicit thread change clears prior draft',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final secondThread = ThreadSummary(
        id: 'other-controls-thread',
        sessionId: 'other-controls-session',
        preview: 'Other controls thread',
        cwd: '/workspace',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        status: ThreadRuntimeStatus.idle,
        ephemeral: false,
      );
      final runtime = _ProductRuntimeController()
        ..extraThreads = [secondThread];
      addTearDown(runtime.closeStreams);

      final composer = find.byKey(const ValueKey('conversation-composer'));
      final chip = find.byKey(const ValueKey('composer-attachment-chip-0'));
      String composerText() =>
          tester.widget<TextField>(composer).controller!.text;

      Future<void> attachMention(String path) async {
        await tester.tap(find.byKey(const ValueKey('composer-attach-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Attach file (@mention)'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('composer-attachment-primary-field')),
          path,
        );
        await tester.tap(
          find.byKey(const ValueKey('composer-attachment-confirm-button')),
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();

      // Cold composer draft at 1280x720 stays in conversation when resized to 720x800.
      await tester.enterText(composer, 'Cold unsent draft');
      tester.view.physicalSize = const Size(720, 800);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('compact-workspace')), findsOneWidget);
      expect(composer, findsOneWidget);
      expect(composerText(), 'Cold unsent draft');

      // Resize back to 1280x720, select thread, add draft text and @mention attachment.
      tester.view.physicalSize = const Size(1280, 720);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      await tester.enterText(composer, 'F29 disposable unsent draft');
      await attachMention('fixture.md');
      expect(composerText(), 'F29 disposable unsent draft');
      expect(chip, findsOneWidget);

      // Resize 1280x720 -> 720x800: stays in active conversation with draft and attachment intact.
      tester.view.physicalSize = const Size(720, 800);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('compact-workspace')), findsOneWidget);
      expect(find.byTooltip('Show threads'), findsOneWidget);
      expect(composer, findsOneWidget);
      expect(composerText(), 'F29 disposable unsent draft');
      expect(chip, findsOneWidget);

      // Toggle compact Threads -> reselect same thread: draft and attachment remain intact.
      await tester.tap(find.byTooltip('Show threads'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show conversation'), findsOneWidget);
      expect(composer, findsNothing);
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      expect(composer, findsOneWidget);
      expect(composerText(), 'F29 disposable unsent draft');
      expect(chip, findsOneWidget);

      // Open compact Threads and resize 720x800 -> 1280x720: draft and attachment remain intact.
      await tester.tap(find.byTooltip('Show threads'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1280, 720);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-split-workspace')),
        findsOneWidget,
      );
      expect(composer, findsOneWidget);
      expect(composerText(), 'F29 disposable unsent draft');
      expect(chip, findsOneWidget);

      // Explicit switch to a different thread on wide retains text and clears prior thread's attachment.
      await tester.tap(find.text('Other controls thread'));
      await tester.pumpAndSettle();
      expect(composerText(), 'F29 disposable unsent draft');
      expect(chip, findsNothing);

      // In compact layout, failed read on another thread keeps Threads open and preserves current draft/attachment;
      // successful selection of a different thread clears both text and attachments.
      tester.view.physicalSize = const Size(720, 800);
      await tester.pumpAndSettle();
      await tester.enterText(composer, 'Compact thread-specific draft');
      await attachMention('compact.md');
      expect(composerText(), 'Compact thread-specific draft');
      expect(chip, findsOneWidget);
      await tester.tap(find.byTooltip('Show threads'));
      await tester.pumpAndSettle();
      runtime.failNextReadThread = true;
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show conversation'), findsOneWidget);
      await tester.tap(find.byTooltip('Show conversation'));
      await tester.pumpAndSettle();
      expect(composerText(), 'Compact thread-specific draft');
      expect(chip, findsOneWidget);
      await tester.tap(find.byTooltip('Show threads'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      expect(composerText(), isEmpty);
      expect(chip, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dangerous execution overrides require affirmative confirmation',
    (tester) async {
      final runtime = await _pumpSelectedApp(tester);
      final execution = find.byKey(const ValueKey('execution-settings-button'));

      await tester.tap(execution);
      await tester.pumpAndSettle();
      final fullAccess = find.text('Full access');
      expect(
        tester.getRect(fullAccess).bottom,
        lessThan(tester.getRect(execution).top),
      );
      await tester.tap(fullAccess);
      await tester.pumpAndSettle();
      expect(find.text('Allow full filesystem access?'), findsOneWidget);
      await tester.tap(find.widgetWithText(CodexButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.gpp_maybe_outlined), findsNothing);

      Future<void> openAdvancedSettings() async {
        await tester.tap(execution);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Advanced settings…'));
        await tester.pumpAndSettle();
      }

      await openAdvancedSettings();

      await _chooseDropdown(
        tester,
        key: 'execution-Approval mode',
        option: 'Never ask',
      );
      expect(find.text('Disable approval prompts?'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      await tester.tap(find.widgetWithText(CodexButton, 'Cancel'));
      await tester.pumpAndSettle();

      await _chooseDropdown(
        tester,
        key: 'execution-Sandbox',
        option: 'Danger: full access',
      );
      expect(find.text('Allow full filesystem access?'), findsOneWidget);
      await tester.tap(find.widgetWithText(CodexButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CodexButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.gpp_maybe_outlined), findsNothing);
      await _send(tester, 'defaults remain inherited');
      expect(runtime.turnOptions.last.approvalPolicy, isNull);
      expect(runtime.turnOptions.last.sandbox, isNull);

      tester.view.physicalSize = const Size(820, 420);
      await tester.pumpAndSettle();
      await openAdvancedSettings();
      await _chooseDropdown(
        tester,
        key: 'execution-Approval mode',
        option: 'Never ask',
      );
      await tester.tap(find.widgetWithText(CodexButton, 'Never ask'));
      await tester.pumpAndSettle();
      await _chooseDropdown(
        tester,
        key: 'execution-Sandbox',
        option: 'Danger: full access',
      );
      await tester.tap(find.widgetWithText(CodexButton, 'Allow full access'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CodexButton, 'Done'));
      await tester.pumpAndSettle();
      final fullAccessIcon = tester.widget<Icon>(
        find.descendant(
          of: execution,
          matching: find.byIcon(Icons.gpp_maybe_outlined),
        ),
      );
      expect(
        fullAccessIcon.color,
        ThemeTokens.of(tester.element(execution)).warning,
      );

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

  testWidgets('approval stays actionable in a narrow conversation', (
    tester,
  ) async {
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
    runtime.emitApproval(
      const ApprovalRequest(
        requestId: 'approval-1',
        kind: ApprovalKind.command,
        threadId: 'controls-thread',
        turnId: 'turn-1',
        itemId: 'item-1',
        summary: 'Run the requested project verification command',
        detail: 'flutter test test/app/product_controls_test.dart',
        reason: 'Verify the presentation change before completion.',
        approveSupported: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approval required'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Approve once'), findsOneWidget);
    await tester.tap(find.text('Approve once'));
    await tester.pumpAndSettle();
    expect(runtime.approvalDecisions, [
      (requestId: 'approval-1', decision: ApprovalDecision.approveOnce),
    ]);
    expect(find.text('Approval required'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tool user input stays bounded and actionable in a narrow view', (
    tester,
  ) async {
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
    runtime.emitUserInput(
      UserInputRequest(
        requestId: 'input-1',
        threadId: 'controls-thread',
        turnId: 'turn-1',
        itemId: 'item-1',
        isBlocking: true,
        questions: [
          UserInputQuestion(
            id: 'approach',
            header: 'Approach',
            question: 'Which implementation should be used?',
            options: const [
              UserInputOption(
                label: 'Incremental',
                description: 'Keep the protocol boundary small.',
              ),
            ],
            allowsOther: true,
            isSecret: false,
          ),
          UserInputQuestion(
            id: 'note',
            header: 'Private note',
            question: 'Add a short private note.',
            options: const [],
            allowsOther: false,
            isSecret: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Codex needs your input'), findsOneWidget);
    final questionCard = find.byKey(const ValueKey('user-input-card'));
    final questionDecoration =
        tester.widget<Container>(questionCard).decoration! as BoxDecoration;
    final theme = OfficialCodexTheme.of(tester.element(questionCard));
    expect(questionDecoration.color, theme.modalSurface);
    expect(questionDecoration.border, Border.all(color: theme.hairlineBorder));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('user-input-question-scroll')))
          .height,
      lessThanOrEqualTo(320),
    );
    await tester.tap(
      find.byKey(const ValueKey('user-input-approach-Incremental')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('user-input-note-text')),
      '  Keep this bounded.  ',
    );
    await tester.pump();
    expect(
      tester
          .widget<CodexButton>(find.byKey(const ValueKey('user-input-submit')))
          .isEnabled,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('user-input-submit')));
    await tester.pumpAndSettle();

    expect(runtime.userInputSubmissions, hasLength(1));
    expect(runtime.userInputSubmissions.single.$1, 'input-1');
    expect(runtime.userInputSubmissions.single.$2.values, {
      'approach': ['Incremental'],
      'note': ['  Keep this bounded.  '],
    });
    expect(find.text('Codex needs your input'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long approval details leave decisions visible in a short split',
    (tester) async {
      tester.view.physicalSize = const Size(760, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _ProductRuntimeController();
      addTearDown(runtime.closeStreams);
      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('sidebar-resize-handle')),
        const Offset(310, 0),
      );
      await tester.pumpAndSettle();
      runtime.emitWarning(
        'The runtime needs confirmation before changing files.',
      );
      runtime.emitApproval(
        ApprovalRequest(
          requestId: 'short-approval',
          kind: ApprovalKind.fileChange,
          threadId: runtime.thread.id,
          turnId: 'turn-1',
          itemId: 'item-1',
          summary: 'Update the disposable fixture files.',
          detail: [for (var i = 0; i < 24; i++) 'fixture/file-$i.txt']
              .join('\n'),
          reason: 'Verify approval controls while a warning is present.',
          approveSupported: true,
        ),
      );
      await tester.pumpAndSettle();

      final reject = find.text('Reject');
      expect(tester.getBottomLeft(reject).dy, lessThan(420));
      expect(tester.getBottomLeft(find.text('Approve once')).dy, lessThan(420));
      final details = find.byKey(const ValueKey('approval-details-scroll'));
      await tester.drag(details, const Offset(0, -120));
      await tester.pumpAndSettle();
      final detailPosition = tester
          .state<ScrollableState>(
            find
                .descendant(of: details, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      expect(detailPosition.pixels, greaterThan(0));
      await tester.tap(reject);
      await tester.pumpAndSettle();
      expect(runtime.approvalDecisions, [
        (requestId: 'short-approval', decision: ApprovalDecision.reject),
      ]);
    },
  );

  testWidgets(
    'concurrent approval and question stay reachable in a short split',
    (tester) async {
      tester.view.physicalSize = const Size(760, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _ProductRuntimeController();
      addTearDown(runtime.closeStreams);
      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('sidebar-resize-handle')),
        const Offset(310, 0),
      );
      await tester.pumpAndSettle();
      runtime.emitWarning(
        'The runtime needs confirmation before changing files.',
      );
      runtime.emitUserInput(
        UserInputRequest(
          requestId: 'simultaneous-input',
          threadId: runtime.thread.id,
          turnId: 'turn-1',
          itemId: 'input-item',
          isBlocking: true,
          questions: [
            UserInputQuestion(
              id: 'answer',
              header: 'Follow-up',
              question: 'Enter a short reply.',
              options: const [],
              allowsOther: false,
              isSecret: false,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('user-input-answer-text'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Keep this answer.');
      await tester.pumpAndSettle();
      runtime.emitApproval(
        ApprovalRequest(
          requestId: 'short-approval',
          kind: ApprovalKind.fileChange,
          threadId: runtime.thread.id,
          turnId: 'turn-1',
          itemId: 'item-1',
          summary: 'Update the disposable fixture files.',
          detail: [for (var i = 0; i < 24; i++) 'fixture/file-$i.txt']
              .join('\n'),
          reason: 'Verify approval controls while a warning is present.',
          approveSupported: true,
        ),
      );
      await tester.pumpAndSettle();
      final dock = find.byKey(const ValueKey('conversation-request-scroll'));
      expect(dock, findsOneWidget);
      final reject = find.text('Reject');
      await tester.ensureVisible(reject);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(reject).dy, lessThan(420));
      await tester.tap(reject);
      await tester.pumpAndSettle();
      expect(runtime.approvalDecisions, [
        (requestId: 'short-approval', decision: ApprovalDecision.reject),
      ]);
      expect(dock, findsNothing);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Keep this answer.',
      );
      await tester.tap(find.byKey(const ValueKey('user-input-submit')));
      await tester.pumpAndSettle();
      expect(runtime.userInputSubmissions.single.$2.values, {
        'answer': ['Keep this answer.'],
      });
    },
  );

  testWidgets('keeps Other drafts without transferring focus across steps', (
    tester,
  ) async {
    final runtime = await _pumpSelectedApp(tester);
    runtime.emitUserInput(
      UserInputRequest(
        requestId: 'other-two-steps',
        threadId: 'controls-thread',
        turnId: 'turn-1',
        itemId: 'item-1',
        isBlocking: true,
        questions: [
          for (final id in ['first', 'second'])
            UserInputQuestion(
              id: id,
              header: id,
              question: 'Choose an answer for $id.',
              options: const [
                UserInputOption(label: 'Default', description: ''),
              ],
              allowsOther: true,
              isSecret: false,
            ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    Finder field(String id) => find.byKey(ValueKey('user-input-$id-text'));
    Future<void> chooseOther(String id, String text) async {
      await tester.tap(field(id));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field(id)).focusNode!.hasFocus, isTrue);
      await tester.enterText(field(id), text);
      await tester.pump();
    }

    final next = find.byKey(const ValueKey('user-input-next'));
    final nextQuestion = find.byKey(const ValueKey('user-input-next-question'));
    final previous = find.byKey(const ValueKey('user-input-previous'));
    final firstCount = find.text('1 of 2');
    final secondCount = find.text('2 of 2');
    expect(tester.widget<CodexIconButton>(previous).isEnabled, isFalse);
    expect(
      tester.getTopLeft(firstCount).dy,
      lessThan(tester.getTopLeft(next).dy),
    );
    expect(
      tester.getCenter(previous).dx,
      lessThan(tester.getCenter(firstCount).dx),
    );
    expect(
      tester.getCenter(firstCount).dx,
      lessThan(tester.getCenter(nextQuestion).dx),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(secondCount, findsOneWidget);
    expect(tester.widget<CodexIconButton>(nextQuestion).isEnabled, isFalse);
    expect(runtime.userInputSubmissions, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(secondCount, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(firstCount, findsOneWidget);

    await tester.tap(field('first'));
    await tester.pumpAndSettle();
    expect(tester.widget<CodexButton>(next).isEnabled, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(firstCount, findsOneWidget);
    await tester.tap(nextQuestion);
    await tester.pumpAndSettle();
    expect(secondCount, findsOneWidget);
    await tester.tap(previous);
    await tester.pumpAndSettle();

    await chooseOther('first', 'Single line');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    final firstEditor = tester.widget<TextField>(field('first'));
    final scope = find.byKey(const ValueKey('user-input-choice-scope'));
    expect(firstEditor.focusNode!.hasFocus, isFalse);
    expect(tester.widget<Focus>(scope).focusNode!.hasPrimaryFocus, isTrue);
    expect(firstEditor.controller!.text, 'Single line');

    await tester.tap(field('first'));
    await tester.pumpAndSettle();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Composing',
        selection: TextSelection.collapsed(offset: 9),
        composing: TextRange(start: 0, end: 9),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(firstEditor.focusNode!.hasFocus, isTrue);

    await chooseOther('first', 'Long wrapped draft ' * 35);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(firstEditor.focusNode!.hasFocus, isTrue);

    await chooseOther('first', 'First custom draft');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(field('first'), findsNothing);
    await chooseOther('second', 'Second custom draft');
    await tester.tap(find.byKey(const ValueKey('user-input-previous')));
    await tester.pumpAndSettle();
    final first = tester.widget<TextField>(field('first'));
    expect(first.controller!.text, 'First custom draft');
    expect(first.focusNode!.hasFocus, isFalse);
    await tester.tap(next);
    await tester.pumpAndSettle();
    final second = tester.widget<TextField>(field('second'));
    expect(second.controller!.text, 'Second custom draft');
    expect(second.focusNode!.hasFocus, isFalse);

    tester.view.physicalSize = const Size(820, 420);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-question-other-footer')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('user-input-second-other')),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(field('second')).controller!.text,
      'Second custom draft',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide stock questions keep answers when stepping back', (
    tester,
  ) async {
    final runtime = await _pumpSelectedApp(tester);
    runtime.emitUserInput(
      UserInputRequest(
        requestId: 'desktop-steps',
        threadId: 'controls-thread',
        turnId: 'turn-1',
        itemId: 'item-1',
        isBlocking: true,
        questions: [
          UserInputQuestion(
            id: 'approach',
            header: 'Approach',
            question: 'Which approach?',
            options: const [
              UserInputOption(
                label: 'Incremental',
                description: 'Small changes',
              ),
              UserInputOption(
                label: 'Full pass',
                description: 'Review the whole fixture',
              ),
            ],
            allowsOther: true,
            isSecret: false,
          ),
          UserInputQuestion(
            id: 'note',
            header: 'Private note',
            question: 'Add a private note.',
            options: [],
            allowsOther: false,
            isSecret: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final next = find.byKey(const ValueKey('user-input-next'));
    final submit = find.byKey(const ValueKey('user-input-submit'));
    final field = find.byKey(const ValueKey('user-input-note-text'));
    expect(find.text('1 of 2'), findsOneWidget);
    expect(tester.widget<CodexButton>(next).label, 'Continue');
    final markers = find.byKey(
      const ValueKey('desktop-question-option-marker'),
    );
    expect(markers, findsNWidgets(2));
    expect(tester.getSize(markers.first), const Size.square(20));
    expect(
      find.descendant(of: markers, matching: find.text('2')),
      findsOneWidget,
    );
    expect(field, findsNothing);
    expect(tester.widget<CodexButton>(next).isEnabled, isTrue);
    final defaultOption = find.descendant(
      of: find.byKey(const ValueKey('user-input-approach-Incremental')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Incremental',
      ),
    );
    expect(tester.widget<Semantics>(defaultOption).properties.checked, isTrue);

    final other = find.byKey(const ValueKey('user-input-approach-text'));
    final footer = find.byKey(const ValueKey('desktop-question-other-footer'));
    expect(find.descendant(of: footer, matching: other), findsOneWidget);
    expect(find.descendant(of: footer, matching: next), findsOneWidget);
    expect(tester.getCenter(other).dy, closeTo(tester.getCenter(next).dy, 1));
    expect(tester.getTopRight(other).dx, lessThan(tester.getTopLeft(next).dx));
    expect(runtime.userInputSubmissions, isEmpty);
    final scope = find.byKey(const ValueKey('user-input-choice-scope'));
    expect(tester.widget<Focus>(scope).focusNode!.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump(const Duration(milliseconds: 70));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('1 of 2'), findsOneWidget);
    expect(tester.widget<TextField>(other).focusNode!.hasFocus, isTrue);
    expect(tester.widget<CodexButton>(next).isEnabled, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('1 of 2'), findsOneWidget);

    FocusNode optionFocus(String label) => Focus.of(
      tester.element(
        find
            .descendant(
              of: find.byKey(ValueKey('user-input-approach-$label')),
              matching: find.byType(GestureDetector),
            )
            .last,
      ),
    );

    final incremental = optionFocus('Incremental');
    final fullPass = optionFocus('Full pass');
    fullPass.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.widget<TextField>(other).focusNode!.hasFocus, isTrue);

    incremental.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(fullPass.hasFocus, isTrue);
    final alternate = find.descendant(
      of: find.byKey(const ValueKey('user-input-approach-Full pass')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Full pass',
      ),
    );
    expect(tester.widget<Semantics>(alternate).properties.checked, isTrue);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(incremental.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 179));
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(tester.widget<TextField>(field).obscureText, isTrue);
    await tester.enterText(field, '  Keep this private.  ');
    await tester.tap(find.byKey(const ValueKey('user-input-previous')));
    await tester.pumpAndSettle();
    expect(tester.widget<CodexButton>(next).isEnabled, isTrue);

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field).controller!.text,
      '  Keep this private.  ',
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(runtime.userInputSubmissions.single.$2.values, {
      'approach': ['Full pass'],
      'note': ['  Keep this private.  '],
    });
  });

  testWidgets('leaving the question thread cancels direct choice submission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1191, 865);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = _ProductRuntimeController()
      ..extraThreads = [
        ThreadSummary(
          id: 'other-thread',
          sessionId: 'other-session',
          preview: 'Alternate thread',
          cwd: '/workspace',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          status: ThreadRuntimeStatus.idle,
          ephemeral: false,
        ),
      ];
    addTearDown(runtime.closeStreams);
    await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controls thread'));
    await tester.pumpAndSettle();
    runtime.emitApproval(
      ApprovalRequest(
        requestId: 'choice-focus-approval',
        kind: ApprovalKind.command,
        threadId: runtime.thread.id,
        turnId: 'turn-1',
        itemId: 'approval-item',
        summary: 'Confirm the fixture.',
        approveSupported: true,
      ),
    );
    runtime.emitUserInput(
      UserInputRequest(
        requestId: 'choice-thread-scope',
        threadId: runtime.thread.id,
        turnId: 'turn-1',
        itemId: 'item-1',
        isBlocking: true,
        questions: [
          UserInputQuestion(
            id: 'approach',
            header: 'Approach',
            question: 'Choose the fixture option.',
            options: const [UserInputOption(label: 'Default', description: '')],
            allowsOther: false,
            isSecret: false,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final singleTitle = tester.widget<Text>(
      find.text('Choose the fixture option.'),
    );
    expect(singleTitle.style!.fontSize, 14);
    expect(singleTitle.style!.fontWeight, FontWeight.w500);
    expect(singleTitle.style!.height! * singleTitle.style!.fontSize!, 20);
    final scope = find.byKey(const ValueKey('user-input-choice-scope'));
    expect(tester.widget<Focus>(scope).focusNode!.hasPrimaryFocus, isFalse);
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(tester.widget<Focus>(scope).focusNode!.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tap(find.text('Alternate thread'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 180));
    expect(runtime.userInputSubmissions, isEmpty);

    await tester.tap(find.text('Controls thread'));
    await tester.pumpAndSettle();
    expect(tester.widget<Focus>(scope).focusNode!.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(runtime.userInputSubmissions.single.$2.values, {
      'approach': ['Default'],
    });
  });

  testWidgets(
    'a pending question and warning fit after resizing a Desktop window',
    (tester) async {
      tester.view.physicalSize = const Size(820, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _ProductRuntimeController();
      addTearDown(runtime.closeStreams);
      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();

      await _send(tester, 'Start a fixture turn.');
      await tester.pumpAndSettle();
      runtime.emitWarning(
        'Model metadata was unavailable and the runtime is using fallback '
        'metadata for this disposable fixture.',
      );

      runtime.emitUserInput(
        UserInputRequest(
          requestId: 'short-input',
          threadId: runtime.thread.id,
          turnId: 'turn-1',
          itemId: 'item-1',
          isBlocking: true,
          questions: [
            UserInputQuestion(
              id: 'approach',
              header: 'Approach',
              question: 'Which implementation should be used?',
              options: [
                for (var i = 1; i <= 8; i++)
                  UserInputOption(
                    label: 'Option $i',
                    description: 'A distinct implementation option.',
                  ),
              ],
              allowsOther: false,
              isSecret: false,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final scroll = find.byKey(const ValueKey('user-input-question-scroll'));
      final submit = find.byKey(const ValueKey('user-input-submit'));
      final last = find.byKey(const ValueKey('user-input-approach-Option 8'));
      tester.view.physicalSize = const Size(820, 420);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(submit).dy, lessThan(420));
      expect(tester.widget<CodexButton>(submit).isEnabled, isTrue);
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('floating_composer')))
            .dy,
        lessThanOrEqualTo(420),
      );
      for (var option = 1; option < 8; option++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      expect(tester.getRect(scroll).contains(tester.getCenter(last)), isTrue);
      expect(runtime.userInputSubmissions, isEmpty);
      await tester.tap(last);
      await tester.pump(const Duration(milliseconds: 179));
      expect(runtime.userInputSubmissions, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(runtime.userInputSubmissions.single.$2.values, {
        'approach': ['Option 8'],
      });
    },
  );

  testWidgets(
    'large diff view is truncated, virtualized, and file-selectable',
    (tester) async {
      final runtime = await _pumpSelectedApp(tester);
      await _send(tester, 'Fixture conversation remains available.');
      await tester.pumpAndSettle();
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
              lines: ['-removed', '+second'],
              truncated: false,
            ),
          ],
          additions: 4001,
          deletions: 1,
          truncated: true,
        ),
      );
      await tester.pump();

      expect(find.text('2 files shown'), findsOneWidget);
      final sidePanelToggle = find.byKey(
        const ValueKey('workspace-side-panel-toggle'),
      );
      final threadMenu = find.byKey(
        const ValueKey('thread-actions-menu-button'),
      );
      final detailMenu = find.byKey(const ValueKey('timeline-details-button'));
      expect(
        tester.getCenter(threadMenu).dx,
        lessThan(tester.getCenter(detailMenu).dx),
      );
      expect(
        tester.getCenter(detailMenu).dx,
        lessThan(tester.getCenter(sidePanelToggle).dx),
      );
      await tester.tap(sidePanelToggle);
      await tester.pumpAndSettle();
      final changesPane = find.byKey(const ValueKey('desktop-changes-pane'));
      final timeline = find.byKey(const ValueKey('conversation-timeline'));
      expect(changesPane, findsOneWidget);
      expect(timeline, findsOneWidget);
      expect(
        tester.getRect(timeline).right,
        lessThanOrEqualTo(tester.getRect(changesPane).left),
      );
      expect(tester.getSize(changesPane).width, greaterThanOrEqualTo(320));
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
      expect(find.text('-removed'), findsOneWidget);
      final addedText = tester.widget<Text>(find.text('+second'));
      final removedText = tester.widget<Text>(find.text('-removed'));
      final expectedTheme = OfficialCodexTheme.of(
        tester.element(find.text('+second')),
      );
      expect(addedText.style?.color, expectedTheme.diffAddedText);
      expect(removedText.style?.color, expectedTheme.diffRemovedText);
      expect(find.text('+line-0'), findsNothing);

      tester.view.physicalSize = const Size(1191, 865);
      await tester.pumpAndSettle();
      expect(changesPane, findsNothing);
      expect(find.text('+second'), findsOneWidget);

      tester.view.physicalSize = const Size(1600, 1000);
      await tester.pumpAndSettle();
      expect(changesPane, findsOneWidget);
      expect(find.text('+second'), findsOneWidget);
      await tester.tap(sidePanelToggle);
      await tester.pumpAndSettle();
      expect(changesPane, findsNothing);
      expect(timeline, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop sidebar collapses cleanly and filters threads inline', (
    tester,
  ) async {
    await _pumpSelectedApp(tester);

    // Filter threads inline.
    await tester.tap(find.byKey(const ValueKey('thread-search-toggle')));
    await tester.pumpAndSettle();
    final searchField = find.byKey(const ValueKey('thread-search-field'));
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'nonexistent');
    await tester.pumpAndSettle();
    expect(find.text('No matching threads.'), findsOneWidget);

    await tester.enterText(searchField, 'Controls');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('thread-row-controls-thread')),
      findsOneWidget,
    );

    // Collapse and expand sidebar.
    await tester.tap(find.byKey(const ValueKey('sidebar-collapse-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('thread-row-controls-thread')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('sidebar-expand-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sidebar-expand-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('thread-row-controls-thread')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders pasted-file user message envelope as attachment chip without protocol scaffolding',
    (tester) async {
      await _pumpSelectedApp(tester);
      await _send(
        tester,
        '# Files pasted by the user:\n\n'
        '## "Fix scroll restoration bug": /tmp/pasted-text/1775-000.txt\n\n'
        "Pasted text contains the user's request.\n\n"
        '## My request:\n',
      );

      expect(find.text('Pasted · 1775-000.txt'), findsOneWidget);
      expect(find.text('Fix scroll restoration bug'), findsOneWidget);
      expect(find.textContaining('# Files pasted by the user:'), findsNothing);
      expect(
        find.textContaining("Pasted text contains the user's request."),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unselected composer starts a thread on submit and history turns toggle Worked-for details',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = _ProductRuntimeController()
        ..historyTurns = [
          HistoryTurn(
            id: 'turn-history-1',
            status: TurnRuntimeStatus.completed,
            startedAt: DateTime.utc(2026, 1, 1, 0, 0, 0),
            completedAt: DateTime.utc(2026, 1, 1, 0, 3, 58),
            items: const [
              HistoryItem(
                id: 'hist-user-1',
                turnId: 'turn-history-1',
                kind: HistoryItemKind.user,
                text: 'Run verification',
              ),
              HistoryItem(
                id: 'hist-assistant-1',
                turnId: 'turn-history-1',
                kind: HistoryItemKind.assistant,
                text: 'Verification complete.',
              ),
            ],
          ),
          const HistoryTurn(
            id: 'turn-history-older',
            status: TurnRuntimeStatus.completed,
            items: [
              HistoryItem(
                id: 'hist-assistant-older',
                turnId: 'turn-history-older',
                kind: HistoryItemKind.assistant,
                text: 'Earlier verification complete.',
              ),
            ],
          ),
        ]
        ..expandedTurnItems = const [
          HistoryItem(
            id: 'hist-user-1',
            turnId: 'turn-history-1',
            kind: HistoryItemKind.user,
            text: 'Run verification',
          ),
          HistoryItem(
            id: 'hist-cmd-1',
            turnId: 'turn-history-1',
            kind: HistoryItemKind.activity,
            text: 'Command: flutter test',
            isCommand: true,
          ),
          HistoryItem(
            id: 'hist-assistant-1',
            turnId: 'turn-history-1',
            kind: HistoryItemKind.assistant,
            text: 'Verification complete.',
          ),
        ];
      addTearDown(runtime.closeStreams);

      await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
      await tester.pumpAndSettle();

      // Unselected state shows the Home hero, model pill, and active composer.
      expect(find.byKey(const ValueKey('home-hero-heading')), findsOneWidget);
      expect(find.text('Default model · Medium'), findsOneWidget);
      await _send(tester, 'Start directly from landing page');
      expect(runtime.startedThreadCwds, hasLength(1));
      expect(runtime.turnOptions, hasLength(1));
      expect(
        runtime.turnOptions.single.text,
        'Start directly from landing page',
      );

      // Select existing thread with history turn duration and assistant copy action.
      await tester.tap(find.text('Controls thread'));
      await tester.pumpAndSettle();
      expect(find.text('Worked for 3m 58s'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('assistant-copy-hist-assistant-1')),
        findsOneWidget,
      );
      final message = find.byKey(
        const ValueKey('user-message-bubble-hist-user-1'),
      );
      final actions = find.byKey(
        const ValueKey('desktop-user-message-actions'),
      );
      final olderActions = find.byKey(
        const ValueKey(
          'desktop-assistant-message-actions-hist-assistant-older',
        ),
      );
      expect(tester.widget<Opacity>(olderActions).opacity, 0);
      expect(
        find.byKey(
          const ValueKey('desktop-assistant-message-actions-hist-assistant-1'),
        ),
        findsNothing,
      );
      expect(tester.widget<Opacity>(actions).opacity, 0);
      final actionRect = tester.getRect(actions);
      final messageRect = tester.getRect(message);
      expect(actionRect.top, messageRect.bottom);
      expect(actionRect.right, messageRect.right);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(5, 90));
      await mouse.moveTo(tester.getCenter(find.text('Run verification')));
      await tester.pump();
      expect(tester.widget<Opacity>(actions).opacity, 1);
      expect(find.byTooltip('Copy message'), findsOneWidget);
      expect(tester.getRect(actions), actionRect);
      await mouse.moveTo(const Offset(5, 90));
      await tester.pump();
      expect(tester.widget<Opacity>(actions).opacity, 0);
      await mouse.moveTo(tester.getCenter(olderActions));
      await tester.pump();
      expect(tester.widget<Opacity>(olderActions).opacity, 1);
      await mouse.removePointer();
      await tester.pump();
      expect(tester.widget<Opacity>(olderActions).opacity, 0);
      final copyButton = find.byKey(const ValueKey('user-copy-hist-user-1'));
      final copyFocus = Focus.of(
        tester.element(
          find
              .descendant(
                of: copyButton,
                matching: find.byType(GestureDetector),
              )
              .last,
        ),
      );
      copyFocus.requestFocus();
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(actions).opacity, 1);
      copyFocus.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Command: flutter test'), findsNothing);

      // Expand turn details via Worked for 3m 58s disclosure row.
      await tester.tap(find.byKey(const ValueKey('turn-work-turn-history-1')));
      await tester.pumpAndSettle();
      expect(find.text('Command: flutter test'), findsOneWidget);

      // Collapse turn details again.
      await tester.tap(find.byKey(const ValueKey('turn-work-turn-history-1')));
      await tester.pumpAndSettle();
      expect(find.text('Command: flutter test'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Escape interrupts the active stock question and cancels choice advancement',
    (tester) async {
      final runtime = await _pumpSelectedApp(tester);
      runtime.turnStartStatus = TurnRuntimeStatus.inProgress;
      final interrupt = Completer<void>();
      runtime.interruptCompletion = interrupt.future;
      addTearDown(() {
        if (!interrupt.isCompleted) interrupt.complete();
      });
      await _send(tester, 'Ask a stock question.');
      UserInputRequest request(String id, String turn) => UserInputRequest(
        requestId: id,
        threadId: 'controls-thread',
        turnId: turn,
        itemId: 'question-item',
        isBlocking: false,
        questions: [
          UserInputQuestion(
            id: 'choice',
            header: 'Choice',
            question: 'Choose the disposable path.',
            options: const [
              UserInputOption(label: 'First', description: ''),
              UserInputOption(label: 'Second', description: ''),
            ],
            allowsOther: true,
            isSecret: false,
          ),
        ],
      );
      runtime.emitUserInput(request('stale-question', 'older-turn'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(runtime.interrupts, isEmpty);
      runtime.resolveUserInput('stale-question');
      runtime.emitUserInput(request('active-question', 'turn-1'));
      runtime.emitApproval(
        const ApprovalRequest(
          requestId: 'priority-approval',
          kind: ApprovalKind.command,
          threadId: 'controls-thread',
          turnId: 'turn-1',
          itemId: 'approved-item',
          summary: 'Disposable approval',
          approveSupported: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(runtime.interrupts, isEmpty);
      expect(runtime.approvalDecisions, isEmpty);
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('thread-actions-menu-button')),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(runtime.interrupts, isEmpty);
      expect(
        tester
            .widget<Focus>(
              find.byKey(const ValueKey('user-input-choice-scope')),
            )
            .focusNode!
            .hasPrimaryFocus,
        isTrue,
      );

      final other = find.byKey(const ValueKey('user-input-choice-text'));
      await tester.tap(other);
      await tester.pumpAndSettle();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Composing',
          selection: TextSelection.collapsed(offset: 9),
          composing: TextRange(start: 0, end: 9),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(runtime.interrupts, isEmpty);
      await tester.enterText(other, 'Preserved custom draft');
      runtime.interruptError = StateError('Disposable interrupt failure');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(runtime.interrupts, [('controls-thread', 'turn-1')]);
      expect(tester.widget<TextField>(other).focusNode!.hasFocus, isTrue);
      expect(
        tester.widget<TextField>(other).controller!.text,
        'Preserved custom draft',
      );
      runtime.interruptError = null;
      runtime.interrupts.clear();
      final scope = find.byKey(const ValueKey('user-input-choice-scope'));
      tester.widget<Focus>(scope).focusNode!.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump(const Duration(milliseconds: 70));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(runtime.interrupts, [('controls-thread', 'turn-1')]);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 250));
      expect(runtime.interrupts, hasLength(1));
      expect(runtime.userInputSubmissions, isEmpty);
      expect(runtime.userInputCancellations, isEmpty);
      interrupt.complete();
      runtime.resolveUserInput('active-question');
      runtime.completeTurn('turn-1', TurnRuntimeStatus.interrupted);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('user-input-card')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved command group opens lazily and keeps loaded item search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const turnId = 'grouped-turn';
    const user = HistoryItem(
      id: 'group-prompt',
      turnId: turnId,
      kind: HistoryItemKind.user,
      text: 'Inspect disposable files.',
    );
    const answer = HistoryItem(
      id: 'group-answer',
      turnId: turnId,
      kind: HistoryItemKind.assistant,
      text: 'Inspection complete.',
    );
    final runtime = _ProductRuntimeController()
      ..historyTurns = const [
        HistoryTurn(
          id: turnId,
          status: TurnRuntimeStatus.completed,
          reportedWorkDuration: Duration(seconds: 1),
          items: [user, answer],
        ),
      ]
      ..expandedTurnItems = [
        user,
        for (var index = 1; index <= 12; index++)
          HistoryItem(
            id: 'group-read-$index',
            turnId: turnId,
            kind: HistoryItemKind.activity,
            text: 'Command: cat fixture-$index',
            isCommand: true,
            status: 'completed',
            output: index == 1
                ? const OutputDescriptor(
                    reference: 'group-preview',
                    bytes: 12,
                    storedBytes: 12,
                    truncated: false,
                    available: true,
                  )
                : null,
            commandAction: (
              kind: CommandActionKind.read,
              name: 'fixture-$index',
              path: null,
              query: null,
            ),
          ),
        const HistoryItem(
          id: 'group-tail',
          turnId: turnId,
          kind: HistoryItemKind.activity,
          text: 'Command: printf group-tail',
          isCommand: true,
          status: 'completed',
        ),
        answer,
      ];
    addTearDown(runtime.closeStreams);
    await tester.pumpWidget(CodexNativeApp(runtimeController: runtime));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controls thread'));
    await tester.pumpAndSettle();

    final turn = find.byKey(const ValueKey('turn-work-grouped-turn'));
    final group = find.text('Read files and ran a command');
    final inner = find.byKey(const ValueKey('saved-command-group-items'));
    final read = find.text('Read fixture-1');
    final tail = find.text('Ran printf group-tail');
    expect(turn, findsOneWidget);
    expect(group, findsNothing);
    expect(runtime.historyItemReads, 0);

    await tester.tap(turn);
    await tester.pumpAndSettle();
    expect(group, findsOneWidget);
    expect(read, findsNothing);
    expect(runtime.historyItemReads, 1);
    await tester.tap(group);
    await tester.pumpAndSettle();
    expect(tester.getSize(inner).height, 224);
    expect(read, findsOneWidget);
    expect(tail, findsNothing);
    await tester.drag(inner, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tail, findsOneWidget);
    expect(runtime.historyItemReads, 1);

    await tester.drag(inner, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(runtime.outputTailReads, isEmpty);
    await tester.tap(find.byTooltip('Show output preview'));
    await tester.pumpAndSettle();
    expect(find.text('group output'), findsOneWidget);
    expect(runtime.outputTailReads, [12]);

    await tester.tap(find.byKey(const ValueKey('thread-actions-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find in conversation'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('conversation-search-field'));
    await tester.enterText(search, 'printf group-tail');
    await tester.pumpAndSettle();
    expect(group, findsNothing);
    final count = tester.widget<Text>(
      find.byKey(const ValueKey('conversation-search-count')),
    );
    expect(count.data, '1 of 1');
    await tester.tap(find.byKey(const ValueKey('conversation-search-next')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('active-search-match-group-tail')),
      findsOneWidget,
    );
    expect(runtime.historyItemReads, 1);
    await tester.tap(find.byKey(const ValueKey('conversation-search-close')));
    await tester.pumpAndSettle();
    expect(inner, findsOneWidget);
    expect(find.text('group output'), findsOneWidget);
    expect(runtime.outputTailReads, [12]);
    await tester.tap(group);
    await tester.pumpAndSettle();
    expect(inner, findsNothing);
    await tester.tap(group);
    await tester.pumpAndSettle();
    expect(find.text('group output'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop question header unifies queued/submitting state and scopes composer send disabled opacity',
    (tester) async {
      final runtime = await _pumpSelectedApp(tester);

      final sendButton = find.byKey(const ValueKey('composer-send-button'));
      expect(tester.widget<CodexIconButton>(sendButton).isEnabled, isFalse);
      final sendOpacity = tester.widget<Opacity>(
        find.descendant(of: sendButton, matching: find.byType(Opacity)).first,
      );
      expect(sendOpacity.opacity, 0.5);

      final submitGate = Completer<void>();
      runtime.userInputSubmitCompletion = submitGate.future;
      for (final id in ['queued-1', 'queued-2']) {
        runtime.emitUserInput(
          UserInputRequest(
            requestId: id,
            threadId: 'controls-thread',
            turnId: 'turn-1',
            itemId: 'item-$id',
            isBlocking: true,
            questions: [
              UserInputQuestion(
                id: 'approach',
                header: 'Approach',
                question: 'Select the preferred strategy.',
                options: const [
                  UserInputOption(
                    label: 'Incremental (Recommended)',
                    description: 'Small, reversible slices.',
                  ),
                  UserInputOption(
                    label: 'Full rewrite',
                    description: 'Replace the whole surface at once.',
                  ),
                ],
                allowsOther: true,
                isSecret: false,
              ),
            ],
          ),
        );
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('Codex needs your input'), findsNothing);
      final header = find.byKey(const ValueKey('desktop-question-header'));
      final queued = find.byKey(
        const ValueKey('desktop-question-queued-count'),
      );
      expect(header, findsOneWidget);
      expect(find.descendant(of: header, matching: queued), findsOneWidget);
      expect(tester.widget<Text>(queued).data, '2 queued');

      expect(find.text('Incremental'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('desktop-question-recommended-badge')),
        findsOneWidget,
      );
      final firstTile = find.byKey(
        const ValueKey('user-input-approach-Incremental (Recommended)'),
      );
      final secondTile = find.byKey(
        const ValueKey('user-input-approach-Full rewrite'),
      );
      expect(
        find.descendant(
          of: firstTile,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == 'Incremental (Recommended)',
          ),
        ),
        findsOneWidget,
      );

      double enterOpacityFor(Finder tile) => tester
          .widget<Opacity>(
            find.descendant(
              of: tile,
              matching: find.byKey(
                const ValueKey('desktop-question-option-enter'),
              ),
            ),
          )
          .opacity;

      expect(enterOpacityFor(firstTile), 1);
      expect(enterOpacityFor(secondTile), 0);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(secondTile));
      await tester.pumpAndSettle();
      expect(enterOpacityFor(firstTile), 0);
      expect(enterOpacityFor(secondTile), 1);

      final footer = find.byKey(
        const ValueKey('desktop-question-other-footer'),
      );
      await gesture.moveTo(tester.getCenter(footer));
      await tester.pumpAndSettle();
      expect(enterOpacityFor(firstTile), 0);
      expect(enterOpacityFor(secondTile), 0);

      final firstMarker = find
          .descendant(
            of: firstTile,
            matching: find.byKey(
              const ValueKey('desktop-question-option-marker'),
            ),
          )
          .first;
      final otherMarker = find.byKey(
        const ValueKey('desktop-question-other-marker'),
      );
      expect(
        tester.getTopLeft(otherMarker).dx,
        closeTo(tester.getTopLeft(firstMarker).dx, 0.5),
      );
      expect(
        tester.getTopLeft(footer).dy - tester.getBottomLeft(secondTile).dy,
        closeTo(4, 1.5),
      );

      final submit = find.byKey(const ValueKey('user-input-submit'));
      expect(
        find.descendant(
          of: submit,
          matching: find.byKey(
            const ValueKey('desktop-question-submit-shortcut'),
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(submit);
      await tester.pump();
      expect(find.textContaining('Codex needs your input'), findsNothing);
      expect(
        find.descendant(
          of: header,
          matching: find.byKey(
            const ValueKey('desktop-question-submitting-indicator'),
          ),
        ),
        findsOneWidget,
      );
      final cancelDisabledOpacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byKey(const ValueKey('user-input-cancel')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(cancelDisabledOpacity.opacity, 0.45);

      submitGate.complete();
      await tester.pumpAndSettle();
      expect(runtime.userInputSubmissions.single.$1, 'queued-1');
      expect(runtime.userInputSubmissions.single.$2.values, {
        'approach': ['Incremental (Recommended)'],
      });
      expect(find.byKey(const ValueKey('user-input-card')), findsOneWidget);
      expect(queued, findsNothing);
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
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  final menu = find.byType(CodexMenu<String>);
  expect(tester.getRect(menu).left, closeTo(tester.getRect(field).left, 1));
  expect(tester.getRect(menu).right, closeTo(tester.getRect(field).right, 1));
  expect(tester.getRect(menu).top, greaterThanOrEqualTo(0));
  expect(
    tester.getRect(menu).bottom,
    lessThanOrEqualTo(
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    ),
  );
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
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('composer-send-button')));
  await tester.pumpAndSettle();
}

class _ProductRuntimeController extends RuntimeController {
  final StreamController<TurnEvent> _turns =
      StreamController<TurnEvent>.broadcast(sync: true);
  final StreamController<ApprovalEvent> _approvals =
      StreamController<ApprovalEvent>.broadcast(sync: true);
  final StreamController<UserInputEvent> _userInputs =
      StreamController<UserInputEvent>.broadcast(sync: true);
  final List<TurnStartOptions> turnOptions = [];
  var turnStartStatus = TurnRuntimeStatus.completed;
  Future<void>? interruptCompletion;
  Object? interruptError;
  final List<(String, String)> interrupts = [];
  final List<String> startedThreadCwds = [];
  List<HistoryTurn> historyTurns = const [];
  List<HistoryItem> expandedTurnItems = const [];
  var historyItemReads = 0;
  final List<int> outputTailReads = [];
  final List<({Object requestId, ApprovalDecision decision})>
  approvalDecisions = [];
  final List<(Object, UserInputAnswers)> userInputSubmissions = [];
  Future<void>? userInputSubmitCompletion;
  final List<Object> userInputCancellations = [];
  var failNextReadThread = false;
  List<ThreadSummary> extraThreads = const [];
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
  Stream<UserInputEvent> get userInputEvents => _userInputs.stream;

  @override
  Future<void> start() async {
    notifyListeners();
  }

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) async =>
      ThreadPage(threads: [thread, ...extraThreads], nextCursor: null);

  @override
  Future<ThreadSummary> readThread(String threadId) async {
    if (failNextReadThread) {
      failNextReadThread = false;
      throw StateError('Simulated thread read failure');
    }
    for (final candidate in [thread, ...extraThreads]) {
      if (candidate.id == threadId) {
        return candidate;
      }
    }
    return thread;
  }

  @override
  Future<ThreadSummary> resumeThread(String threadId) async =>
      readThread(threadId);

  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) async {
    startedThreadCwds.add(options.cwd);
    return ThreadSummary(
      id: 'started-thread-${startedThreadCwds.length}',
      sessionId: 'started-session-${startedThreadCwds.length}',
      preview: 'New thread',
      cwd: options.cwd,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      status: ThreadRuntimeStatus.idle,
      ephemeral: false,
    );
  }

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
      HistoryTurnPage(turns: historyTurns, nextCursor: null);

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) async {
    historyItemReads++;
    return HistoryItemPage(items: expandedTurnItems, nextCursor: null);
  }

  @override
  Future<OutputChunk> readOutputTail({
    required String reference,
    required int length,
  }) async {
    outputTailReads.add(length);
    return OutputChunk(
      reference: reference,
      offset: 0,
      data: Uint8List.fromList('group output'.codeUnits),
      bytes: 12,
      storedBytes: 12,
      truncated: false,
      eof: true,
    );
  }

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) async {
    turnOptions.add(options);
    final id = 'turn-${turnOptions.length}';
    if (turnStartStatus == TurnRuntimeStatus.inProgress) {
      _turns.add(TurnStartedEvent(threadId: options.threadId, turnId: id));
    }
    return TurnHandle(id: id, status: turnStartStatus);
  }

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    interrupts.add((threadId, turnId));
    if (interruptError case final error?) throw error;
    await interruptCompletion;
  }

  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) async {
    approvalDecisions.add((requestId: requestId, decision: decision));
  }

  @override
  Future<void> submitUserInput({
    required Object requestId,
    required UserInputAnswers answers,
  }) async {
    userInputSubmissions.add((requestId, answers));
    await userInputSubmitCompletion;
  }

  @override
  Future<void> cancelUserInput(Object requestId) async {
    userInputCancellations.add(requestId);
  }

  @override
  Future<void> shutdown() async {}

  void emitDiff(DiffSnapshot snapshot) {
    _turns.add(TurnDiffUpdatedEvent(snapshot: snapshot));
  }

  void emitWarning(String message) {
    _turns.add(TurnWarningEvent(threadId: thread.id, message: message));
  }

  void emitApproval(ApprovalRequest request) {
    _approvals.add(ApprovalRequestedEvent(request: request));
  }

  void emitUserInput(UserInputRequest request) {
    _userInputs.add(UserInputRequestedEvent(request: request));
  }

  void resolveUserInput(Object requestId) {
    _userInputs.add(UserInputResolvedEvent(requestId: requestId));
  }

  void completeTurn(String turnId, TurnRuntimeStatus status) {
    _turns.add(
      TurnCompletedEvent(threadId: thread.id, turnId: turnId, status: status),
    );
  }

  Future<void> closeStreams() async {
    await _turns.close();
    await _approvals.close();
    await _userInputs.close();
    dispose();
  }
}
