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
    testWidgets('clamps to 75% max width and toggles long message collapse', (
      tester,
    ) async {
      final longText =
          'Paragraph content testing message bubble collapse threshold. ' * 20;

      await tester.pumpWidget(
        wrap(CodexMessageBubble(text: longText, maxColumnWidth: 704.0)),
      );

      expect(find.text('Show full message'), findsOneWidget);
      await tester.tap(find.text('Show full message'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
    });
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

        // Natural chat line-height (~20px), not the 34px execution card box.
        expect(tester.getSize(staticRow).height, lessThan(26.0));
        expect(tester.getSize(interactiveRow).height, lessThan(26.0));

        final staticText = tester.widget<Text>(find.text('Read README.md'));
        expect(staticText.style?.fontFamily, isNull);
        expect(staticText.style?.fontSize, 13.5);
        expect(
          staticText.style?.color,
          OfficialCodexThemeData.light.activitySummaryText,
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
        expect(
          tester.widget<Text>(find.text('Worked for 7s')).style?.color,
          OfficialCodexThemeData.light.textMuted,
        );

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
}
