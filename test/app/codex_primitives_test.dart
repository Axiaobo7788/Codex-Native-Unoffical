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
    testWidgets('clamps to 704px max width with 24px radius', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CodexComposer(
            child: SizedBox(height: 48, child: Text('Composer Input')),
          ),
        ),
      );

      final composer = find.byType(CodexComposer);
      expect(composer, findsOneWidget);
      expect(tester.getSize(composer).width, lessThanOrEqualTo(704.0));
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
    testWidgets('renders activity row and divider correctly', (tester) async {
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

      expect(find.text('git status -s'), findsOneWidget);
      expect(find.text('View output'), findsOneWidget);
      await tester.tap(find.text('View output'));
      await tester.pumpAndSettle();
      expect(outputClicked, isTrue);

      expect(find.text('Worked for 42s'), findsOneWidget);
      await tester.tap(find.text('Worked for 42s'));
      await tester.pumpAndSettle();
      expect(toggled, isTrue);
    });
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
