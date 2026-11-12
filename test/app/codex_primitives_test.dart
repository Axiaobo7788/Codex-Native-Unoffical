import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show SemanticsAction;

import 'package:codex_native_unofficial/src/app/primitives/codex_activity_row.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_composer.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_menu.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_message_bubble.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_popover.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_segment.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_sidebar_row.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_tooltip.dart';
import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.dark}) {
    final themeData = brightness == Brightness.dark
        ? OfficialCodexThemeData.dark
        : OfficialCodexThemeData.light;
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: OfficialCodexThemeProvider(
        data: themeData,
        child: Scaffold(
          body: SingleChildScrollView(child: Center(child: child)),
        ),
      ),
    );
  }

  group('CodexButton and CodexIconButton', () {
    testWidgets('toolbar size keeps its measured label and radius', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CodexButton(
                label: 'Save',
                size: CodexButtonSize.toolbar,
                onPressed: () {},
              ),
              CodexButton(
                label: 'Small',
                size: CodexButtonSize.sm,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      final title = tester.widget<Text>(find.text('Save'));
      expect(title.style!.fontSize, 13);
      expect(title.style!.height! * title.style!.fontSize!, 18);
      expect(title.style!.fontWeight, FontWeight.w400);
      expect(tester.widget<Text>(find.text('Small')).style!.fontSize, 12);
      for (final (label, radius) in [('Save', 8.0), ('Small', 10.0)]) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byType(CodexButton),
        );
        expect(tester.getSize(button).height, 28);
        final container = tester.widget<AnimatedContainer>(
          find.descendant(of: button, matching: find.byType(AnimatedContainer)),
        );
        expect(
          (container.decoration! as BoxDecoration).borderRadius,
          BorderRadius.circular(radius),
        );
      }
    });

    testWidgets('renders button with label and responds to tap', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(CodexButton(label: 'Action', onPressed: () => tapped = true)),
      );

      expect(find.text('Action'), findsOneWidget);
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders icon button without ink ripples', (tester) async {
      var iconTapped = false;
      await tester.pumpWidget(
        wrap(
          CodexIconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: () => iconTapped = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();
      expect(iconTapped, isTrue);
      // Verify no InkWell or InkResponse widgets are used
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(InkResponse), findsNothing);
    });
  });

  group('CodexSidebarRow', () {
    testWidgets('renders sidebar row with exact 36px height', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CodexSidebarRow(
            title: 'Sample Thread',
            leading: Icon(Icons.chat_bubble_outline),
          ),
        ),
      );

      final row = find.byType(CodexSidebarRow);
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, 36.0);
    });
  });

  group('CodexComposer', () {
    testWidgets('clamps to 672px max width with 24px radius', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CodexComposer(
            child: SizedBox(
              width: 1000,
              height: 48,
              child: Text('Composer Input'),
            ),
          ),
        ),
      );

      final composer = find.byType(CodexComposer);
      expect(composer, findsOneWidget);
      expect(tester.getSize(composer).width, 672.0);
    });
  });

  group('CodexMessageBubble', () {
    testWidgets(
      'translates borderless 70% 22px 16x10 user bubble with relaxed line box and zero negative tracking',
      (tester) async {
        final longSingleParagraph =
            'Official user bubble geometry check across reading column width. ' *
            8;

        await tester.pumpWidget(
          wrap(
            brightness: Brightness.light,
            SizedBox(
              width: 672.0,
              child: CodexMessageBubble(text: longSingleParagraph),
            ),
          ),
        );

        final bubble = find.byType(CodexMessageBubble);
        final surface = tester.widget<Container>(
          find.descendant(
            of: bubble,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container && widget.decoration is BoxDecoration,
            ),
          ),
        );
        final surfaceFinder = find.descendant(
          of: bubble,
          matching: find.byWidget(surface),
        );
        expect(
          tester.getSize(surfaceFinder).width,
          lessThanOrEqualTo(672.0 * 0.70 + 0.01),
        );
        expect(
          surface.padding,
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        );
        final decoration = surface.decoration! as BoxDecoration;
        expect(decoration.color, OfficialCodexTheme.lightUserBubbleBackground);
        expect(decoration.borderRadius, BorderRadius.circular(22.0));
        expect(decoration.border, isNull);

        final markdownRoot = find.descendant(
          of: bubble,
          matching: find.byKey(const ValueKey('user-message-markdown')),
        );
        expect(markdownRoot, findsOneWidget);
        final renderedText = tester.widget<Text>(
          find.descendant(of: markdownRoot, matching: find.byType(Text)).first,
        );
        final spanStyle = renderedText.textSpan?.style;
        expect(spanStyle?.fontSize, 14.0);
        expect(spanStyle?.height, 1.625);
        expect(spanStyle?.letterSpacing, isNull);
        expect(find.text('Show more'), findsNothing);
      },
    );

    testWidgets(
      'collapses only past 20 rendered lines and toggles Show more / Show less via pointer, keyboard, and semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final twentyLines = List.generate(
            20,
            (index) => 'Prompt line ${index + 1}',
          ).join('\n');
          await tester.pumpWidget(
            wrap(
              SizedBox(
                width: 672.0,
                child: CodexMessageBubble(
                  text: twentyLines,
                  expandKey: const ValueKey('expand-20'),
                ),
              ),
            ),
          );
          expect(find.text('Show more'), findsNothing);
          expect(find.textContaining('Prompt line 20'), findsOneWidget);

          final twentyFiveLines = List.generate(
            25,
            (index) => 'Prompt line ${index + 1}',
          ).join('\n');
          await tester.pumpWidget(
            wrap(
              SizedBox(
                width: 672.0,
                child: CodexMessageBubble(
                  text: twentyFiveLines,
                  expandKey: const ValueKey('expand-25'),
                ),
              ),
            ),
          );

          final toggle = find.byKey(const ValueKey('expand-25'));
          expect(find.text('Show more'), findsOneWidget);
          expect(find.text('…'), findsOneWidget);
          expect(
            tester.getTopLeft(toggle).dy -
                tester.getBottomLeft(find.text('…')).dy,
            closeTo(OfficialCodexTheme.userMessageExpandGap, 0.01),
          );
          expect(find.textContaining('Prompt line 19'), findsOneWidget);
          expect(find.textContaining('Prompt line 25'), findsNothing);
          final collapsedRendered = tester.widget<Text>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('user-message-markdown')),
                  matching: find.byType(Text),
                )
                .first,
          );
          final collapsedPlain = collapsedRendered.textSpan!.toPlainText();
          expect(
            collapsedPlain,
            List.generate(19, (index) => 'Prompt line ${index + 1}').join('\n'),
          );
          expect(collapsedPlain, isNot(contains('…')));
          expect(collapsedPlain, isNot(contains('Show more')));
          expect(
            find.semantics.byLabel(RegExp(r'Prompt line 25')),
            findsNothing,
          );
          expect(
            tester
                .widget<AnimatedRotation>(
                  find.descendant(
                    of: toggle,
                    matching: find.byType(AnimatedRotation),
                  ),
                )
                .turns,
            0.0,
          );

          // Screen-reader semantics tap expands.
          final node = tester.getSemantics(toggle).getSemanticsData();
          expect(node.label, 'Show more');
          expect(node.hasAction(SemanticsAction.tap), isTrue);
          tester.semantics.tap(find.semantics.byLabel('Show more'));
          await tester.pumpAndSettle();

          expect(find.text('Show less'), findsOneWidget);
          expect(find.text('…'), findsNothing);
          expect(find.textContaining('Prompt line 25'), findsOneWidget);
          final expandedRendered = tester.widget<Text>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('user-message-markdown')),
                  matching: find.byType(Text),
                )
                .first,
          );
          final expandedPlain = expandedRendered.textSpan!.toPlainText();
          expect(expandedPlain, twentyFiveLines);
          expect(expandedPlain, isNot(contains('Show less')));
          expect(
            tester
                .widget<AnimatedRotation>(
                  find.descendant(
                    of: toggle,
                    matching: find.byType(AnimatedRotation),
                  ),
                )
                .turns,
            0.5,
          );

          // Keyboard Enter collapses back to 20-line preview.
          final focusNode = Focus.of(
            tester.element(
              find.descendant(
                of: toggle,
                matching: find.byType(GestureDetector),
              ),
            ),
          );
          focusNode.requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();

          expect(find.text('Show more'), findsOneWidget);
          expect(find.textContaining('Prompt line 25'), findsNothing);

          // Expanding and then updating `text` resets expansion to collapsed (`189497.oQwr.ee` parity).
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(find.text('Show less'), findsOneWidget);

          final updatedTwentySixLines = List.generate(
            26,
            (index) => 'Updated line ${index + 1}',
          ).join('\n');
          await tester.pumpWidget(
            wrap(
              SizedBox(
                width: 672.0,
                child: CodexMessageBubble(
                  text: updatedTwentySixLines,
                  expandKey: const ValueKey('expand-25'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Show more'), findsOneWidget);
          expect(find.textContaining('Updated line 26'), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'bounds collapsed slice to 512 * maxCollapsedLines and caps expanded display safely across surrogate pairs',
      (tester) async {
        // Place an emoji straddling the 10,240 code-unit collapsed slice boundary.
        final prefix = 'a' * 10239;
        final hugePrompt = '$prefix🚀${'b' * 4000}';

        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 672.0,
              child: CodexMessageBubble(
                text: hugePrompt,
                maxExpandedCharacters: 11000,
                expandKey: const ValueKey('expand-huge'),
              ),
            ),
          ),
        );

        expect(find.text('Show more'), findsOneWidget);
        final collapsedTextWidget = tester.widget<Text>(
          find
              .descendant(
                of: find.byKey(const ValueKey('user-message-markdown')),
                matching: find.byType(Text),
              )
              .first,
        );
        expect(
          collapsedTextWidget.textSpan!.toPlainText().length,
          lessThanOrEqualTo(10240),
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('expand-huge')));
        await tester.pumpAndSettle();

        final expandedTextWidget = tester.widget<Text>(
          find
              .descendant(
                of: find.byKey(const ValueKey('user-message-markdown')),
                matching: find.byType(Text),
              )
              .first,
        );
        expect(expandedTextWidget.textSpan!.toPlainText().length, 11000);
        expect(find.text('…'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('CodexActivityRow and CodexActivityDivider', () {
    testWidgets('renders execution card row and divider correctly', (
      tester,
    ) async {
      var outputClicked = false;
      var toggled = false;

      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              CodexActivityRow(
                summary: 'git status -s',
                onViewOutput: () => outputClicked = true,
              ),
              CodexActivityDivider(
                label: 'Worked for 42s',
                isExpanded: false,
                onToggle: () => toggled = true,
              ),
            ],
          ),
        ),
      );

      final cardRow = find.byType(CodexActivityRow);
      expect(tester.getSize(cardRow).height, 40.0); // 34px + 2 * 3px margin
      final monoText = tester.widget<Text>(find.text('git status -s'));
      expect(monoText.style?.fontFamily, 'monospace');
      expect(monoText.style?.fontSize, 12.5);
      expect(find.text('View output'), findsOneWidget);
      await tester.tap(find.text('View output'));
      await tester.pumpAndSettle();
      expect(outputClicked, isTrue);

      expect(find.text('Worked for 42s'), findsOneWidget);
      await tester.tap(find.text('Worked for 42s'));
      await tester.pumpAndSettle();
      expect(toggled, isTrue);
    });

    testWidgets(
      'inline activity row uses natural chat height, 60% resting ink, and callback-only interactivity',
      (tester) async {
        var expanded = false;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => wrap(
              brightness: Brightness.light,
              SizedBox(
                width: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CodexActivityRow(
                      key: ValueKey('static-inline-row'),
                      summary: 'Read README.md',
                      inline: true,
                    ),
                    CodexActivityRow(
                      key: const ValueKey('interactive-inline-row'),
                      summary: 'Ran flutter test',
                      inline: true,
                      hasDisclosure: true,
                      isExpanded: expanded,
                      disclosureTooltip: expanded
                          ? 'Hide output preview'
                          : 'Show output preview',
                      onToggle: () => setState(() => expanded = !expanded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final staticRow = find.byKey(const ValueKey('static-inline-row'));
        final interactiveRow = find.byKey(
          const ValueKey('interactive-inline-row'),
        );

        // Natural `.text-size-chat` line-height (`21px` at `14px`), not the 34px execution card box.
        expect(tester.getSize(staticRow).height, closeTo(21.0, 0.5));
        expect(tester.getSize(interactiveRow).height, closeTo(21.0, 0.5));

        final staticText = tester.widget<Text>(find.text('Read README.md'));
        expect(staticText.style?.fontFamily, isNull);
        expect(staticText.style?.fontSize, 14.0);
        expect(staticText.style?.height, 1.5);
        expect(
          staticText.style?.color,
          OfficialCodexThemeData.light.activitySummaryText,
        );
        expect(
          OfficialCodexThemeData.light.textPrimary,
          const Color(0xFF1A1C1F),
        );
        expect(
          OfficialCodexThemeData.dark.textPrimary,
          const Color(0xFFDFDFDF),
        );
        expect(
          OfficialCodexThemeData.light.userBubbleBackground,
          const Color(0x0D1A1C1F),
        );
        expect(
          OfficialCodexThemeData.dark.userBubbleBackground,
          const Color(0x0DDFDFDF),
        );
        expect(
          OfficialCodexThemeData.light.activitySummaryText,
          const Color(0x991A1C1F),
        );
        expect(
          OfficialCodexThemeData.dark.activitySummaryText,
          const Color(0x99DFDFDF),
        );
        expect(
          OfficialCodexThemeData.light.activityChildText,
          const Color(0x4D1A1C1F),
        );
        expect(
          OfficialCodexThemeData.dark.activityChildText,
          const Color(0x4DDFDFDF),
        );
        expect(
          find.descendant(
            of: staticRow,
            matching: find.byIcon(Icons.chevron_right_rounded),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: staticRow,
            matching: find.byType(FocusableActionDetector),
          ),
          findsNothing,
        );

        // Interactive row hides chevron at rest (opacity 0), promotes ink & reveals chevron on hover.
        Opacity chevronOpacity() => tester.widget<Opacity>(
          find.descendant(of: interactiveRow, matching: find.byType(Opacity)),
        );
        AnimatedRotation chevronRotation() => tester.widget<AnimatedRotation>(
          find.descendant(
            of: interactiveRow,
            matching: find.byType(AnimatedRotation),
          ),
        );
        expect(chevronOpacity().opacity, 0.0);
        expect(chevronRotation().turns, 0.0);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(
          location: tester.getCenter(find.text('Ran flutter test')),
        );
        await tester.pumpAndSettle();

        expect(chevronOpacity().opacity, 1.0);
        expect(
          tester.widget<Text>(find.text('Ran flutter test')).style?.color,
          OfficialCodexThemeData.light.textPrimary,
        );

        await tester.tap(find.text('Ran flutter test'));
        await tester.pumpAndSettle();
        expect(expanded, isTrue);
        expect(chevronRotation().turns, 0.25);

        // Chevron remains visible while expanded even after pointer leaves.
        await gesture.moveTo(const Offset(600, 300));
        await tester.pumpAndSettle();
        expect(chevronOpacity().opacity, 1.0);
      },
    );

    testWidgets(
      'CodexInlineWorkDivider renders backgroundless trigger, 4px rule gap, and 16px bottom rhythm',
      (tester) async {
        var expanded = false;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => wrap(
              brightness: Brightness.light,
              SizedBox(
                width: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CodexInlineWorkDivider(
                      triggerKey: const ValueKey('work-trigger'),
                      label: 'Worked for 7s',
                      isExpanded: expanded,
                      onToggle: () => setState(() => expanded = !expanded),
                    ),
                    const Text('Assistant answer'),
                  ],
                ),
              ),
            ),
          ),
        );

        final trigger = find.byKey(const ValueKey('work-trigger'));
        final hairline = find.descendant(
          of: find.byType(CodexInlineWorkDivider),
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.height == 1.0,
          ),
        );
        expect(
          tester.getTopLeft(hairline).dy - tester.getBottomLeft(trigger).dy,
          4.0,
        );
        expect(
          tester.getTopLeft(find.text('Assistant answer')).dy -
              tester.getBottomLeft(hairline).dy,
          16.0,
        );
        final workLabel = tester.widget<Text>(find.text('Worked for 7s'));
        expect(workLabel.style?.fontSize, 14.0);
        expect(workLabel.style?.height, 1.5);
        expect(workLabel.style?.color, OfficialCodexThemeData.light.textMuted);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(
          location: tester.getCenter(find.text('Worked for 7s')),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('Worked for 7s')).style?.color,
          OfficialCodexThemeData.light.textPrimary,
        );

        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(expanded, isTrue);
        expect(
          tester
              .widget<AnimatedRotation>(
                find.descendant(
                  of: trigger,
                  matching: find.byType(AnimatedRotation),
                ),
              )
              .turns,
          0.25,
        );
      },
    );

    testWidgets(
      'CodexInlineWorkDivider and CodexInlineActivityHeader announce single labels and expose screen-reader tap',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var dividerActivations = 0;
          var rowActivations = 0;

          await tester.pumpWidget(
            wrap(
              brightness: Brightness.light,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CodexInlineWorkDivider(
                    triggerKey: const ValueKey('work-trigger'),
                    label: 'Worked for 7s',
                    isExpanded: false,
                    onToggle: () => dividerActivations += 1,
                  ),
                  CodexInlineActivityHeader(
                    key: const ValueKey('row-trigger'),
                    label: 'Read counter.txt',
                    leadingIcon: const Icon(Icons.menu_book_outlined),
                    hasDisclosure: true,
                    isExpanded: false,
                    onToggle: () => rowActivations += 1,
                  ),
                ],
              ),
            ),
          );

          final workNode = tester.getSemantics(
            find.byKey(const ValueKey('work-trigger')),
          );
          final workData = workNode.getSemanticsData();
          expect(workData.label, 'Worked for 7s');
          expect(workData.hasAction(SemanticsAction.tap), isTrue);
          tester.semantics.tap(find.semantics.byLabel('Worked for 7s'));
          await tester.pump();
          expect(dividerActivations, 1);

          final rowNode = tester.getSemantics(
            find.byKey(const ValueKey('row-trigger')),
          );
          final rowData = rowNode.getSemanticsData();
          expect(rowData.label, 'Read counter.txt');
          expect(rowData.hasAction(SemanticsAction.tap), isTrue);
          tester.semantics.tap(find.semantics.byLabel('Read counter.txt'));
          await tester.pump();
          expect(rowActivations, 1);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'CodexActivityRow dual-tone verbLength and isWarning preserve resting ink, hover promotion, and single semantics label',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var expanded = false;
          await tester.pumpWidget(
            StatefulBuilder(
              builder: (context, setState) => wrap(
                brightness: Brightness.light,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CodexActivityRow(
                      key: const ValueKey('dual-tone-row'),
                      summary: 'GitHub · List pull requests',
                      verbLength: 'GitHub'.length,
                      icon: const Icon(Icons.extension_outlined),
                      inline: true,
                      hasDisclosure: true,
                      isExpanded: expanded,
                      onToggle: () => setState(() => expanded = !expanded),
                    ),
                    const CodexActivityRow(
                      key: ValueKey('warning-row'),
                      summary: 'Command declined: rm -rf /tmp/x',
                      icon: Icon(Icons.shield_outlined),
                      inline: true,
                      isWarning: true,
                    ),
                  ],
                ),
              ),
            ),
          );

          final dualText = tester.widget<Text>(
            find.text('GitHub · List pull requests'),
          );
          expect(
            dualText.style?.color,
            OfficialCodexThemeData.light.activitySummaryText,
          );
          final rootSpan = dualText.textSpan! as TextSpan;
          expect(rootSpan.text, 'GitHub');
          final detailSpan = rootSpan.children!.single as TextSpan;
          expect(detailSpan.text, ' · List pull requests');
          expect(
            detailSpan.style?.color,
            OfficialCodexThemeData.light.activityChildText,
          );

          // Single accessible button label is preserved across dual-tone spans.
          expect(
            find.semantics.byLabel('GitHub · List pull requests'),
            findsOneWidget,
          );

          // Warning row tints shield icon with warning token while keeping summary text ink.
          final warningIcon = tester.widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey('warning-row')),
              matching: find.byIcon(Icons.shield_outlined),
            ),
          );
          expect(warningIcon.color, OfficialCodexThemeData.light.warning);
          expect(
            tester
                .widget<Text>(find.text('Command declined: rm -rf /tmp/x'))
                .style
                ?.color,
            OfficialCodexThemeData.light.activitySummaryText,
          );

          // Hover promotes both leading verb and trailing detail to primary ink.
          final gesture = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          addTearDown(gesture.removePointer);
          await gesture.addPointer(
            location: tester.getCenter(
              find.text('GitHub · List pull requests'),
            ),
          );
          await tester.pumpAndSettle();

          final hoveredText = tester.widget<Text>(
            find.text('GitHub · List pull requests'),
          );
          expect(
            hoveredText.style?.color,
            OfficialCodexThemeData.light.textPrimary,
          );
          final hoveredDetail =
              (hoveredText.textSpan! as TextSpan).children!.single as TextSpan;
          expect(
            hoveredDetail.style?.color,
            OfficialCodexThemeData.light.textPrimary,
          );
        } finally {
          semantics.dispose();
        }
      },
    );
  });

  group('CodexSegment', () {
    testWidgets('switches selected option on tap', (tester) async {
      var selected = 'commands';
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => CodexSegment<String>(
              items: const [
                CodexSegmentItem(value: 'prose', label: 'Prose'),
                CodexSegmentItem(value: 'commands', label: 'Commands'),
                CodexSegmentItem(value: 'execution', label: 'Execution'),
              ],
              selectedValue: selected,
              onSelected: (val) => setState(() => selected = val),
            ),
          ),
        ),
      );

      expect(selected, 'commands');
      await tester.tap(find.text('Prose'));
      await tester.pumpAndSettle();
      expect(selected, 'prose');

      await tester.tap(find.text('Execution'));
      await tester.pumpAndSettle();
      expect(selected, 'execution');
    });
  });

  group('CodexPopover and CodexMenu', () {
    testWidgets('rebinds the anchor when its controller changes', (
      tester,
    ) async {
      final first = CodexPopoverController();
      final second = CodexPopoverController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Widget anchor(CodexPopoverController controller, String content) => wrap(
        CodexPopoverAnchor(
          controller: controller,
          popoverBuilder: (context, close) => Text(content),
          child: const Text('Anchor'),
        ),
      );

      await tester.pumpWidget(anchor(first, 'First panel'));
      first.show();
      await tester.pumpAndSettle();
      expect(find.text('First panel'), findsOneWidget);

      second.show();
      await tester.pumpWidget(anchor(second, 'Second panel'));
      await tester.pumpAndSettle();
      expect(find.text('First panel'), findsNothing);
      expect(find.text('Second panel'), findsOneWidget);

      first.hide();
      await tester.pumpAndSettle();
      expect(find.text('Second panel'), findsOneWidget);
      second.hide();
      await tester.pumpAndSettle();
      expect(find.text('Second panel'), findsNothing);
    });

    testWidgets('menu arrow keys skip disabled items and wrap focus', (
      tester,
    ) async {
      final controller = CodexPopoverController();
      addTearDown(controller.dispose);
      final chosen = <String>[];

      await tester.pumpWidget(
        wrap(
          CodexPopoverAnchor(
            controller: controller,
            popoverBuilder: (context, close) => CodexMenu<String>(
              items: const [
                CodexMenuItem(value: 'first', label: 'First'),
                CodexMenuItem(
                  value: 'disabled',
                  label: 'Disabled',
                  disabled: true,
                ),
                CodexMenuItem(value: 'last', label: 'Last'),
              ],
              onSelected: (value) {
                chosen.add(value);
                close();
              },
            ),
            child: CodexButton(
              label: 'Open menu',
              onPressed: controller.toggle,
            ),
          ),
        ),
      );

      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();
      await press(LogicalKeyboardKey.arrowDown);
      await press(LogicalKeyboardKey.arrowDown);
      await press(LogicalKeyboardKey.enter);
      expect(chosen, ['last']);

      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();
      await press(LogicalKeyboardKey.arrowUp);
      await press(LogicalKeyboardKey.arrowDown);
      await press(LogicalKeyboardKey.enter);
      expect(chosen, ['last', 'first']);
    });

    testWidgets('opens and selects an item from menu', (tester) async {
      final controller = CodexPopoverController();
      String? chosen;

      await tester.pumpWidget(
        wrap(
          CodexPopoverAnchor(
            controller: controller,
            popoverBuilder: (context, close) => CodexMenu<String>(
              items: const [
                CodexMenuItem(value: 'gpt-5', label: 'GPT-5'),
                CodexMenuItem(value: 'gpt-4o', label: 'GPT-4o'),
              ],
              onSelected: (val) {
                chosen = val;
                close();
              },
            ),
            child: CodexButton(
              label: 'Choose Model',
              onPressed: controller.toggle,
            ),
          ),
        ),
      );

      expect(find.text('GPT-5'), findsNothing);
      await tester.tap(find.text('Choose Model'));
      await tester.pumpAndSettle();

      expect(find.text('GPT-5'), findsOneWidget);
      await tester.tap(find.text('GPT-5'));
      await tester.pumpAndSettle();

      expect(chosen, 'gpt-5');
      expect(find.text('GPT-5'), findsNothing);
    });
  });

  group('CodexTooltip', () {
    testWidgets('renders child and provides tooltip semantic information', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const CodexTooltip(message: 'Helpful tip', child: Text('Hover me')),
        ),
      );

      expect(find.text('Hover me'), findsOneWidget);
      expect(find.byTooltip('Helpful tip'), findsOneWidget);
    });

    testWidgets(
      'CodexSidebarRow and CodexSegment wrap tooltips in CodexTooltip instead of raw Material Tooltip',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            Column(
              children: [
                CodexSidebarRow(
                  title: 'Thread item',
                  tooltip: 'Sidebar row tooltip',
                  onTap: () {},
                ),
                CodexSegment<String>(
                  items: const [
                    CodexSegmentItem(
                      value: 'native',
                      label: 'Native',
                      tooltip: 'Native segment tooltip',
                    ),
                    CodexSegmentItem(
                      value: 'chat',
                      label: 'Chat',
                      tooltip: 'Chat segment tooltip',
                    ),
                  ],
                  selectedValue: 'native',
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        );

        expect(find.byType(CodexTooltip), findsNWidgets(3));
        expect(find.byTooltip('Sidebar row tooltip'), findsOneWidget);
        expect(find.byTooltip('Native segment tooltip'), findsOneWidget);
        expect(find.byTooltip('Chat segment tooltip'), findsOneWidget);
      },
    );

    testWidgets(
      'CodexButton and CodexActivityDivider reset hover/pressed states when disabled or loading',
      (tester) async {
        var enabled = true;
        var loading = false;
        var dividerTaps = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => wrap(
              Column(
                children: [
                  CodexButton(
                    label: 'Toggle Enable',
                    onPressed: enabled
                        ? () => setState(() => enabled = false)
                        : null,
                  ),
                  CodexActivityDivider(
                    label: 'Worked for 12s',
                    isExpanded: false,
                    isLoading: loading,
                    onToggle: () {
                      dividerTaps += 1;
                      setState(() => loading = true);
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(
          location: tester.getCenter(find.text('Toggle Enable')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Toggle Enable'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(CodexButton),
            matching: find.byType(Opacity),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Worked for 12s'));
        await tester.pump();
        expect(dividerTaps, 1);

        // Tapping while loading is ignored
        await tester.tap(find.text('Worked for 12s'));
        await tester.pump();
        expect(dividerTaps, 1);
      },
    );
  });

  group('BoundedLocalFileImage', () {
    test('enforces async stat admission before open and caps TOCTOU mid-read growth at maxEncodedBytes + 1', () async {
      // 1. Oversize stat() rejects with 0 file opens and 0 bytes read.
      final oversizeFile = _InstrumentedFile(
        path: '/virtual/oversize-50mb.png',
        statType: FileSystemEntityType.file,
        statSize: 50 * 1024 * 1024,
        openedLength: 50 * 1024 * 1024,
        backingBytes: Uint8List(0),
      );
      await expectLater(
        BoundedLocalFileImage.readBoundedEncodedBytes(
          oversizeFile,
          maxEncodedBytes: 4096,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(oversizeFile.openCalls, 0);
      expect(oversizeFile.totalBytesRead, 0);

      // 2. Non-regular path (e.g. directory / FIFO) rejects before open.
      final nonRegularFile = _InstrumentedFile(
        path: '/virtual/not-a-regular-file',
        statType: FileSystemEntityType.directory,
        statSize: 128,
        openedLength: 128,
        backingBytes: Uint8List(128),
      );
      await expectLater(
        BoundedLocalFileImage.readBoundedEncodedBytes(
          nonRegularFile,
          maxEncodedBytes: 4096,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(nonRegularFile.openCalls, 0);

      // 3. TOCTOU mid-read growth: stat and fstat report 1024 <= 4096,
      //    but backing stream yields 128 KiB. Reader stops at 4097 bytes
      //    (maxEncodedBytes + 1) and closes the RandomAccessFile handle.
      final growingFile = _InstrumentedFile(
        path: '/virtual/growing.png',
        statType: FileSystemEntityType.file,
        statSize: 1024,
        openedLength: 1024,
        backingBytes: Uint8List(128 * 1024),
      );
      await expectLater(
        BoundedLocalFileImage.readBoundedEncodedBytes(
          growingFile,
          maxEncodedBytes: 4096,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(growingFile.openCalls, 1);
      expect(growingFile.totalBytesRead, 4097);
      expect(growingFile.lastHandleClosed, isTrue);
    });

    testWidgets(
      'evicts failed empty/corrupt cache keys so subsequent valid writes decode cleanly',
      (tester) async {
        final tempDir = await tester.runAsync(
          () => Directory.systemTemp.createTemp('native-bounded-img-test-'),
        );
        addTearDown(() async {
          await tester.runAsync(() async {
            if (tempDir != null && await tempDir.exists()) {
              await tempDir.delete(recursive: true);
            }
          });
        });

        final targetPath = '${tempDir!.path}/recoverable.png';
        await tester.runAsync(() async {
          await File(targetPath).writeAsBytes(const <int>[], flush: true);
        });

        ImageProvider<Object> buildProvider() => ResizeImage(
          BoundedLocalFileImage(File(targetPath), maxEncodedBytes: 4096),
          width: 160,
          height: 160,
          policy: ResizeImagePolicy.fit,
        );

        await tester.pumpWidget(
          wrap(
            Image(
              key: const ValueKey('attempt-1'),
              image: buildProvider(),
              errorBuilder: (context, error, stackTrace) =>
                  const Text('Failed-1'),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Failed-1'), findsOneWidget);

        // Replace empty file with a valid 1x1 PNG; retry must not stick on evicted error.
        await tester.runAsync(() async {
          final pngBytes = base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
          );
          await File(targetPath).writeAsBytes(pngBytes, flush: true);
        });

        await tester.pumpWidget(
          wrap(
            Image(
              key: const ValueKey('attempt-2'),
              image: buildProvider(),
              frameBuilder: (context, child, frame, sync) => frame == null
                  ? const Text('Loading-2')
                  : const Text('Ready-2'),
              errorBuilder: (context, error, stackTrace) =>
                  const Text('Failed-2'),
            ),
          ),
        );
        for (
          var step = 0;
          step < 16 && find.text('Ready-2').evaluate().isEmpty;
          step += 1
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text('Ready-2'), findsOneWidget);
        expect(find.text('Failed-2'), findsNothing);
      },
    );

    testWidgets(
      'relinquishes ImmutableBuffer ownership to decode without double-disposing on decoder failure',
      (tester) async {
        final pngBytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        );
        final provider = BoundedLocalFileImage(
          _InstrumentedFile(
            path: '/virtual/decoder-disposes-then-fails.png',
            statType: FileSystemEntityType.file,
            statSize: pngBytes.length,
            openedLength: pngBytes.length,
            backingBytes: pngBytes,
          ),
          maxEncodedBytes: 4096,
        );
        PaintingBinding.instance.imageCache.putIfAbsent(
          provider,
          () => provider.loadImage(provider, (buffer, {getTargetSize}) async {
            // Simulate instantiateImageCodecWithSize disposing buffer in its
            // finally block when codec instantiation fails after header parse.
            buffer.dispose();
            throw const FormatException('corrupt frame payload');
          }),
        );
        Object? capturedError;
        final completer = provider.loadImage(provider, (
          buffer, {
          getTargetSize,
        }) async {
          buffer.dispose();
          throw const FormatException('corrupt frame payload');
        });
        final listener = ImageStreamListener(
          (image, synchronousCall) {},
          onError: (exception, stackTrace) {
            capturedError = exception;
          },
        );
        completer.addListener(listener);
        for (var step = 0; step < 12 && capturedError == null; step += 1) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        completer.removeListener(listener);
        await tester.pump();

        expect(capturedError, isA<FormatException>());
        expect(
          (capturedError as FormatException).message,
          'corrupt frame payload',
        );
        expect(BoundedLocalFileImage.debugActiveLoadCount, 0);
        expect(
          PaintingBinding.instance.imageCache.containsKey(provider),
          isFalse,
        );
      },
    );

    testWidgets(
      'bounds pending load queue at 64 and immediately retires detached listener or widget requests',
      (tester) async {
        expect(BoundedLocalFileImage.debugActiveLoadCount, 0);
        expect(BoundedLocalFileImage.debugPendingLoadCount, 0);

        final blockers = List<Completer<FileStat>>.generate(
          BoundedLocalFileImage.maxConcurrentLoads,
          (_) => Completer<FileStat>(),
        );
        final activeStreams = <ImageStream>[];
        final activeListeners = <ImageStreamListener>[];
        for (var i = 0; i < BoundedLocalFileImage.maxConcurrentLoads; i += 1) {
          final provider = BoundedLocalFileImage(
            _InstrumentedFile(
              path: '/virtual/blocker-$i.png',
              statType: FileSystemEntityType.file,
              statSize: 128,
              openedLength: 128,
              backingBytes: Uint8List(0),
              pendingStat: blockers[i].future,
            ),
            maxEncodedBytes: 4096,
          );
          final stream = provider.resolve(ImageConfiguration.empty);
          final listener = ImageStreamListener(
            (image, synchronousCall) {},
            onError: (exception, stackTrace) {},
          );
          stream.addListener(listener);
          activeStreams.add(stream);
          activeListeners.add(listener);
        }
        await tester.pump();
        expect(
          BoundedLocalFileImage.debugActiveLoadCount,
          BoundedLocalFileImage.maxConcurrentLoads,
        );

        // Enqueue 78 requests while all 4 active slots are blocked: queue must
        // never exceed maxPendingLoads (64), retiring older overflowed entries.
        var overflowErrors = 0;
        final queuedStreams = <ImageStream>[];
        final queuedListeners = <ImageStreamListener>[];
        for (var i = 0; i < 78; i += 1) {
          final path = '/virtual/queued-$i.png';
          BoundedLocalFileImage.retainWidgetInterest(path);
          final provider = BoundedLocalFileImage(
            _InstrumentedFile(
              path: path,
              statType: FileSystemEntityType.notFound,
              statSize: 0,
              openedLength: 0,
              backingBytes: Uint8List(0),
            ),
            maxEncodedBytes: 4096,
          );
          final stream = provider.resolve(ImageConfiguration.empty);
          final listener = ImageStreamListener(
            (image, synchronousCall) {},
            onError: (exception, stackTrace) {
              overflowErrors += 1;
            },
          );
          stream.addListener(listener);
          queuedStreams.add(stream);
          queuedListeners.add(listener);
          expect(
            BoundedLocalFileImage.debugPendingLoadCount,
            lessThanOrEqualTo(BoundedLocalFileImage.maxPendingLoads),
          );
        }
        await tester.pump();
        expect(
          BoundedLocalFileImage.debugPendingLoadCount,
          BoundedLocalFileImage.maxPendingLoads,
        );
        expect(overflowErrors, 14);

        // Release widget interest for the first 32 surviving queued paths (14..45)
        // and detach stream listeners for the remaining 32 (46..77): all 64
        // pending waiters must retire immediately even while blockers hold slots.
        for (var i = 0; i < 46; i += 1) {
          BoundedLocalFileImage.releaseWidgetInterest('/virtual/queued-$i.png');
        }
        expect(BoundedLocalFileImage.debugPendingLoadCount, 32);
        for (var i = 46; i < 78; i += 1) {
          queuedStreams[i].removeListener(queuedListeners[i]);
          BoundedLocalFileImage.releaseWidgetInterest('/virtual/queued-$i.png');
        }
        await tester.pump();
        expect(BoundedLocalFileImage.debugPendingLoadCount, 0);
        expect(BoundedLocalFileImage.debugTrackedInterestCount, 0);

        for (var i = 0; i < queuedStreams.length; i += 1) {
          queuedStreams[i].removeListener(queuedListeners[i]);
        }
        for (final blocker in blockers) {
          blocker.complete(
            const _FakeFileStat(type: FileSystemEntityType.notFound, size: 0),
          );
        }
        await tester.pumpAndSettle();
        for (var i = 0; i < activeStreams.length; i += 1) {
          activeStreams[i].removeListener(activeListeners[i]);
        }
        await tester.pump();
        expect(BoundedLocalFileImage.debugActiveLoadCount, 0);
        expect(BoundedLocalFileImage.debugPendingLoadCount, 0);
        expect(BoundedLocalFileImage.debugTrackedInterestCount, 0);
      },
    );
  });
}

class _InstrumentedFile implements File {
  _InstrumentedFile({
    required this.path,
    required this.statType,
    required this.statSize,
    required this.openedLength,
    required this.backingBytes,
    this.pendingStat,
  });

  @override
  final String path;
  final FileSystemEntityType statType;
  final int statSize;
  final int openedLength;
  final Uint8List backingBytes;
  final Future<FileStat>? pendingStat;

  int openCalls = 0;
  int totalBytesRead = 0;
  bool lastHandleClosed = false;

  @override
  Future<FileStat> stat() =>
      pendingStat ??
      Future<FileStat>.value(_FakeFileStat(type: statType, size: statSize));

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    openCalls += 1;
    return _InstrumentedRandomAccessFile(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFileStat implements FileStat {
  const _FakeFileStat({required this.type, required this.size});

  @override
  final FileSystemEntityType type;

  @override
  final int size;

  @override
  DateTime get accessed => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  DateTime get changed => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  DateTime get modified => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  int get mode => 0;

  @override
  String modeString() => '';
}

class _InstrumentedRandomAccessFile implements RandomAccessFile {
  _InstrumentedRandomAccessFile(this._owner);

  final _InstrumentedFile _owner;
  int _offset = 0;

  @override
  Future<int> length() async => _owner.openedLength;

  @override
  Future<Uint8List> read(int count) async {
    if (_offset >= _owner.backingBytes.length || count <= 0) {
      return Uint8List(0);
    }
    final end = math.min(_offset + count, _owner.backingBytes.length);
    final chunk = Uint8List.sublistView(_owner.backingBytes, _offset, end);
    _offset = end;
    _owner.totalBytesRead += chunk.length;
    return chunk;
  }

  @override
  Future<void> close() async {
    _owner.lastHandleClosed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
