import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_composer.dart';
import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/app/theme_tokens.dart';
import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../simulated_runtime/simulated_runtime_harness.dart';

void main() {
  testWidgets(
    'stock-observed model reaches the composer without becoming an override',
    (tester) async {
      final thread =
          createTestThread(
            id: 'observed-composer-thread',
            preview: 'Observed settings',
          ).copyWith(
            executionSettings: const ThreadExecutionSettings(
              model: 'configured-not-in-catalog',
              modelProvider: 'fixture-provider',
              reasoningEffort: 'high',
              approvalPolicy: ObservedApprovalPolicy.never,
              sandbox: ObservedSandboxPolicy.readOnly,
              generation: 1,
              observation: 1,
              source: ThreadSettingsSource.resume,
            ),
          );
      final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('Observed settings'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('composer-model-pill')),
          matching: find.text('configured-not-in-catalog High'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Execution settings: Read only'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('execution-settings-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced settings…'));
      await tester.pumpAndSettle();
      expect(find.text('Codex default · Never ask'), findsOneWidget);
      expect(find.text('Codex default · Read only'), findsOneWidget);
      expect(
        find.text('Codex default · configured-not-in-catalog'),
        findsOneWidget,
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('conversation-composer')),
        'Use the inherited thread settings',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pump();
      expect(harness.startedTurns, hasLength(1));
      harness.emitTurnCompleted('turn-1', threadId: thread.id);
      await tester.pumpAndSettle();
      expect(harness.startedTurns.single.model, isNull);
      expect(harness.startedTurns.single.reasoningEffort, isNull);
      expect(harness.startedTurns.single.approvalPolicy, isNull);
      expect(harness.startedTurns.single.sandbox, isNull);
    },
  );

  group('Official A11 Desktop Composer Layout & Surface Parity', () {
    testWidgets(
      'translates Light, Dark, and High-Contrast Desktop composer surface & elevation tokens while keeping Home unchanged',
      (tester) async {
        final thread = createTestThread(
          id: 'composer-surface-thread',
          preview: 'Composer surface thread',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(
          tester,
          harness: harness,
          size: const Size(1191, 865),
        );

        // Home hero composer keeps elevatedSurface (#F4F4F4) and 24px radius.
        BoxDecoration surfaceDecoration() =>
            tester
                    .widget<AnimatedContainer>(
                      find.byKey(const ValueKey('composer-surface')),
                    )
                    .decoration!
                as BoxDecoration;

        expect(
          surfaceDecoration().color,
          OfficialCodexThemeData.light.elevatedSurface,
        );
        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerRadius),
        );

        // Active Light thread composer uses #FFFFFF surface + --elevation-composer.
        await tester.tap(find.text('Composer surface thread'));
        await tester.pumpAndSettle();

        final lightDeco = surfaceDecoration();
        expect(lightDeco.color, OfficialCodexThemeData.light.composerSurface);
        expect(
          lightDeco.borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerRadiusPill),
        );
        expect(
          lightDeco.border,
          Border.all(
            color: OfficialCodexTheme.lightComposerElevationBorder,
            width: 1.0,
          ),
        );
        expect(lightDeco.boxShadow, OfficialCodexTheme.lightComposerShadows);

        // Switch to Dark theme: #2F2F2F surface + 1px #33FFFFFF rim + zero drop shadow.
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            Brightness.dark;
        addTearDown(
          tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
        );
        await tester.pumpAndSettle();

        final darkDeco = surfaceDecoration();
        expect(darkDeco.color, OfficialCodexThemeData.dark.composerSurface);
        expect(
          darkDeco.color,
          isNot(OfficialCodexThemeData.dark.workspaceBackground),
        );
        expect(
          darkDeco.border,
          Border.all(
            color: OfficialCodexTheme.darkComposerElevationBorder,
            width: 1.0,
          ),
        );
        expect(darkDeco.boxShadow, isEmpty);

        // High-contrast forced-colors branch removes shadows and draws solid border.
        tester.view.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(highContrast: true);
        addTearDown(
          tester.view.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpAndSettle();

        final hcFocused = surfaceDecoration();
        expect(hcFocused.boxShadow, isEmpty);
        expect(
          hcFocused.border,
          Border.all(color: OfficialCodexThemeData.dark.focusRing, width: 1.5),
        );

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final hcUnfocused = surfaceDecoration();
        expect(hcUnfocused.boxShadow, isEmpty);
        expect(
          hcUnfocused.border,
          Border.all(
            color: OfficialCodexThemeData.dark.textPrimary,
            width: 1.0,
          ),
        );
      },
    );

    testWidgets(
      'transitions between 28px single-line pill and 22px stacked multiline card while preserving focus, cursor selection, IME lock, and primary action anchor',
      (tester) async {
        final thread = createTestThread(
          id: 'composer-adaptive-thread',
          preview: 'Composer adaptive thread',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(
          tester,
          harness: harness,
          size: const Size(1191, 865),
        );

        await tester.tap(find.text('Composer adaptive thread'));
        await tester.pumpAndSettle();

        final surfaceFinder = find.byKey(const ValueKey('composer-surface'));
        final fieldFinder = find.byKey(const ValueKey('conversation-composer'));
        final attachFinder = find.byKey(
          const ValueKey('composer-attach-button'),
        );
        final modelFinder = find.byKey(const ValueKey('composer-model-pill'));
        final permissionsFinder = find.byKey(
          const ValueKey('execution-settings-button'),
        );
        final sendFinder = find.byKey(const ValueKey('composer-send-button'));

        BoxDecoration surfaceDecoration() =>
            tester.widget<AnimatedContainer>(surfaceFinder).decoration!
                as BoxDecoration;

        TextField textField() => tester.widget<TextField>(fieldFinder);

        await tester.tap(fieldFinder);
        await tester.pump();
        expect(textField().focusNode!.hasFocus, isTrue);

        // Single-line pill baseline geometry.
        final initialSendCenter = tester.getCenter(sendFinder);
        final initialAttachLeft = tester.getRect(attachFinder).left;
        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerRadiusPill),
        );
        expect(
          tester.getCenter(attachFinder).dx,
          lessThan(tester.getCenter(fieldFinder).dx),
        );
        expect(
          tester.getCenter(fieldFinder).dx,
          lessThan(tester.getCenter(modelFinder).dx),
        );
        expect(
          tester.getCenter(modelFinder).dx,
          lessThan(tester.getCenter(permissionsFinder).dx),
        );
        expect(
          tester.getCenter(permissionsFinder).dx,
          lessThan(tester.getCenter(sendFinder).dx),
        );
        expect(
          find.descendant(
            of: permissionsFinder,
            matching: find.text('Codex default'),
          ),
          findsNothing,
        );
        expect(find.text('Ask for approval'), findsNothing);

        // IME composing lock (16389.zdsX.T): long active composition stays locked
        // to single-line until composition commits.
        final controller = textField().controller!;
        final longLine =
            'Long single line prompt that exceeds the inline composer slot width';
        controller.value = TextEditingValue(
          text: longLine,
          selection: TextSelection.collapsed(offset: longLine.length),
          composing: TextRange(start: 0, end: longLine.length),
        );
        await tester.pump();
        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerRadiusPill),
        );
        expect(textField().focusNode!.hasFocus, isTrue);

        // Committing the IME composition transitions to 22px stacked multiline card
        // without dropping focus, cursor selection, or moving Send/Attach X/bottom!
        controller.value = TextEditingValue(
          text: longLine,
          selection: const TextSelection.collapsed(offset: 12),
          composing: TextRange.empty,
        );
        await tester.pumpAndSettle();

        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerMultilineRadius),
        );
        expect(textField().focusNode!.hasFocus, isTrue);
        expect(controller.selection, const TextSelection.collapsed(offset: 12));
        expect(tester.getCenter(sendFinder), initialSendCenter);
        expect(tester.getRect(attachFinder).left, initialAttachLeft);

        // In multiline mode, input spans Row 1 with 12px horizontal inset and
        // permissions moves to Row 2 leading next to '+' with truthful 'Codex default'.
        final surfaceRect = tester.getRect(surfaceFinder);
        final fieldRect = tester.getRect(fieldFinder);
        expect(
          fieldRect.left - surfaceRect.left,
          OfficialCodexTheme.composerMultilineInputHorizontalPadding,
        );
        expect(
          surfaceRect.right - fieldRect.right,
          OfficialCodexTheme.composerMultilineInputHorizontalPadding,
        );
        expect(
          fieldRect.bottom + OfficialCodexTheme.composerInputFooterGap,
          lessThanOrEqualTo(tester.getRect(attachFinder).top + 0.01),
        );
        expect(
          tester.getCenter(attachFinder).dx,
          lessThan(tester.getCenter(permissionsFinder).dx),
        );
        expect(
          tester.getCenter(permissionsFinder).dx,
          lessThan(tester.getCenter(modelFinder).dx),
        );
        expect(
          find.descendant(
            of: permissionsFinder,
            matching: find.text('Codex default'),
          ),
          findsOneWidget,
        );
        expect(find.text('Ask for approval'), findsNothing);

        // Deleting back to a short single-line draft restores 28px inline pill
        // while keeping focus and selection intact.
        controller.value = const TextEditingValue(
          text: 'Short',
          selection: TextSelection.collapsed(offset: 5),
        );
        await tester.pumpAndSettle();
        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerRadiusPill),
        );
        expect(textField().focusNode!.hasFocus, isTrue);
        expect(controller.selection, const TextSelection.collapsed(offset: 5));
        expect(tester.getCenter(sendFinder), initialSendCenter);

        // Shift+Enter inserts newline and transitions cleanly to 22px stacked card.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(controller.text, 'Short\n');
        expect(controller.selection, const TextSelection.collapsed(offset: 6));
        expect(textField().focusNode!.hasFocus, isTrue);
        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerMultilineRadius),
        );
        expect(tester.getCenter(sendFinder), initialSendCenter);

        // Bounded O(1) fast path on huge single-line paste without newlines.
        final hugePaste = 'x' * 10000;
        controller.value = TextEditingValue(
          text: hugePaste,
          selection: TextSelection.collapsed(offset: hugePaste.length),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerMultilineRadius),
        );
      },
    );

    testWidgets(
      'stacks composer on attachment drafts and <640px viewports, collapses narrow permissions label, and opens Full access warning trigger cleanly',
      (tester) async {
        final thread = createTestThread(
          id: 'composer-attachments-permissions',
          preview: 'Attachments and permissions',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(
          tester,
          harness: harness,
          size: const Size(1191, 865),
        );

        await tester.tap(find.text('Attachments and permissions'));
        await tester.pumpAndSettle();

        final surfaceFinder = find.byKey(const ValueKey('composer-surface'));
        final permissionsFinder = find.byKey(
          const ValueKey('execution-settings-button'),
        );
        BoxDecoration surfaceDecoration() =>
            tester.widget<AnimatedContainer>(surfaceFinder).decoration!
                as BoxDecoration;

        // Add a snippet attachment while text is empty -> 22px multiline card.
        await tester.tap(find.byKey(const ValueKey('composer-attach-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Attach snippet'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('composer-attachment-primary-field')),
          'void main() {}',
        );
        await tester.enterText(
          find.byKey(const ValueKey('composer-attachment-secondary-field')),
          'snippet.dart',
        );
        await tester.tap(
          find.byKey(const ValueKey('composer-attachment-confirm-button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('composer-attachment-chip-0')),
          findsOneWidget,
        );
        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerMultilineRadius),
        );
        expect(
          find.descendant(
            of: permissionsFinder,
            matching: find.text('Codex default'),
          ),
          findsOneWidget,
        );
        expect(find.text('Ask for approval'), findsNothing);

        // Select Full access from the multiline labeled permissions trigger.
        await tester.tap(permissionsFinder);
        await tester.pumpAndSettle();
        final fullAccessItem = find.text('Full access');
        expect(
          tester.getRect(fullAccessItem).bottom,
          lessThan(tester.getRect(permissionsFinder).top),
        );
        await tester.tap(fullAccessItem);
        await tester.pumpAndSettle();
        expect(find.text('Allow full filesystem access?'), findsOneWidget);
        await tester.tap(find.widgetWithText(CodexButton, 'Allow full access'));
        await tester.pumpAndSettle();

        final warningLabel = tester.widget<Text>(
          find.descendant(
            of: permissionsFinder,
            matching: find.text('Full access'),
          ),
        );
        expect(
          warningLabel.style?.color,
          ThemeTokens.of(tester.element(permissionsFinder)).warning,
        );
        expect(
          tester.getSize(permissionsFinder).width,
          lessThanOrEqualTo(
            OfficialCodexTheme.composerPermissionsLabelMaxWidth + 16.0,
          ),
        );

        // Footer container <=475px collapses the multiline permissions label
        // back to icon-only while preserving the 22px stacked card.
        tester.view.physicalSize = const Size(760, 800);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const ValueKey('sidebar-resize-handle')),
          const Offset(80, 0),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerMultilineRadius),
        );
        expect(
          find.descendant(
            of: permissionsFinder,
            matching: find.text('Full access'),
          ),
          findsNothing,
        );

        // Removing the attachment keeps the narrow <360px footer stacked at 22px,
        // and widening back restores the 28px single-line pill.
        await tester.tap(
          find.byKey(const ValueKey('composer-attachment-remove-0')),
        );
        await tester.pumpAndSettle();
        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerMultilineRadius),
        );

        tester.view.physicalSize = const Size(1191, 865);
        await tester.pumpAndSettle();
        expect(
          surfaceDecoration().borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerRadiusPill),
        );
      },
    );

    testWidgets(
      'desktop composer surface switches to compact 40px shadow blur below 640px',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeTokens.lightTheme,
            builder: (context, child) => OfficialCodexThemeProvider(
              data: OfficialCodexThemeData.light,
              child: child!,
            ),
            home: const MediaQuery(
              data: MediaQueryData(size: Size(580, 800)),
              child: Scaffold(
                body: CodexComposer(
                  surfaceKey: ValueKey('compact-composer-surface'),
                  useDesktopSurface: true,
                  radius: OfficialCodexTheme.composerMultilineRadius,
                  child: SizedBox(height: 28),
                ),
              ),
            ),
          ),
        );

        final surface = tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('compact-composer-surface')),
        );
        final decoration = surface.decoration! as BoxDecoration;
        expect(
          decoration.borderRadius,
          BorderRadius.circular(OfficialCodexTheme.composerMultilineRadius),
        );
        expect(
          decoration.boxShadow,
          OfficialCodexTheme.lightComposerCompactShadows,
        );
      },
    );

    testWidgets(
      'keeps inherited model and sandbox labels truthful across Home hero, Desktop thread, and compact composers',
      (tester) async {
        final thread = createTestThread(
          id: 'composer-truthful-inherited',
          preview: 'Truthful inherited controls',
        );
        final harness = SimulatedRuntimeHarness(initialThreads: [thread]);
        await pumpSimulatedRuntimeApp(
          tester,
          harness: harness,
          size: const Size(1191, 865),
        );

        final modelFinder = find.byKey(const ValueKey('composer-model-pill'));
        final permissionsFinder = find.byKey(
          const ValueKey('execution-settings-button'),
        );
        final fieldFinder = find.byKey(const ValueKey('conversation-composer'));

        // 1. Home hero composer (null selectedModelId & null sandbox):
        // must NOT display catalog default ('o3-mini') or 'Ask for approval'.
        expect(
          find.descendant(
            of: modelFinder,
            matching: find.text('Codex settings'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('o3-mini'), findsNothing);
        expect(find.text('Ask for approval'), findsNothing);
        expect(
          find.descendant(
            of: permissionsFinder,
            matching: find.text('Defaults'),
          ),
          findsOneWidget,
        );

        // 2. Active Desktop thread composer (1191x865):
        await tester.tap(find.text('Truthful inherited controls'));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: modelFinder,
            matching: find.text('Codex settings'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('o3-mini'), findsNothing);

        await tester.enterText(fieldFinder, 'Line 1\nLine 2');
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: permissionsFinder,
            matching: find.text('Codex default'),
          ),
          findsOneWidget,
        );
        expect(find.text('Ask for approval'), findsNothing);

        await tester.tap(permissionsFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Read only').last);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: permissionsFinder,
            matching: find.text('Read only'),
          ),
          findsOneWidget,
        );

        await tester.tap(permissionsFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Codex default').last);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: permissionsFinder,
            matching: find.text('Codex default'),
          ),
          findsOneWidget,
        );

        // 3. Compact composer (<760px, !hasDesktopShell):
        // null selectedModelId must STILL show 'Codex settings', not catalog default.
        tester.view.physicalSize = const Size(600, 865);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: modelFinder,
            matching: find.text('Codex settings'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('o3-mini'), findsNothing);
        expect(
          find.descendant(
            of: permissionsFinder,
            matching: find.text('Defaults'),
          ),
          findsOneWidget,
        );

        // Selecting an explicit model in compact dialog shows it, and resetting
        // back to Codex default restores 'Codex settings' + null wire overrides.
        await tester.tap(modelFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('execution-Model')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('o3-mini').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: modelFinder,
            matching: find.text('o3-mini · Medium'),
          ),
          findsOneWidget,
        );

        await tester.tap(modelFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('execution-Model')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Codex default').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: modelFinder,
            matching: find.text('Codex settings'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('composer-send-button')));
        await tester.pumpAndSettle();
        expect(harness.startedTurns.single.model, isNull);
        expect(harness.startedTurns.single.sandbox, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
