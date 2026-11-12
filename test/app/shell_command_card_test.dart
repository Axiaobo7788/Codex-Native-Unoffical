import 'package:codex_native_unofficial/src/app/primitives/codex_activity_row.dart';
import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../simulated_runtime/simulated_runtime_harness.dart';

void main() {
  test(
    'shell detector and -lc command unwrapping match 25894 kq2V + PuGl.g',
    () {
      expect(
        detectCodexShellLabel("Command: /bin/bash -lc 'git status --short'"),
        'bash',
      );
      expect(
        unwrapCodexShellCommand("Command: /bin/bash -lc 'git status --short'"),
        'git status --short',
      );
      expect(detectCodexShellLabel('Command: /bin/zsh -lc "pytest -q"'), 'zsh');
      expect(
        unwrapCodexShellCommand('Command: /bin/zsh -lc "pytest -q"'),
        'pytest -q',
      );
      expect(
        detectCodexShellLabel('Command: pwsh.exe -NoLogo -Command Get-Date'),
        'PowerShell',
      );
      expect(detectCodexShellLabel('Command: flutter analyze'), 'Shell');
      expect(
        unwrapCodexShellCommand('Command: flutter analyze'),
        'flutter analyze',
      );
      expect(
        unwrapCodexShellCommand(
          r"""Command: /bin/bash -lc 'printf '"'"'hello world'"'"''""",
        ),
        "printf 'hello world'",
      );
    },
  );

  testWidgets(
    'CodexShellExecutionCard renders 8px frame, line-clamp-2 command expand, 144px reverse scroll, copy actions, and PuGl.d.Footer states',
    (tester) async {
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<Object?, Object?>;
              clipboardText = args['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      const multiLineCmd =
          "Command: /bin/bash -lc 'echo alpha\necho beta\necho gamma\necho delta'";
      final tallOutput = List.generate(
        24,
        (index) => 'output line ${index + 1}',
      ).join('\n');

      await tester.pumpWidget(
        MaterialApp(
          home: OfficialCodexThemeProvider(
            data: OfficialCodexThemeData.light,
            child: Scaffold(
              body: SizedBox(
                width: 600,
                child: CodexShellExecutionCard(
                  rawCommand: multiLineCmd,
                  output: tallOutput,
                  status: 'completed',
                  exitCode: 0,
                ),
              ),
            ),
          ),
        ),
      );

      final surface = find.byKey(
        const ValueKey('command-output-preview-surface'),
      );
      final decoration =
          tester.widget<Container>(surface).decoration! as BoxDecoration;
      expect(decoration.color, OfficialCodexThemeData.light.elevatedSurface);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(OfficialCodexTheme.activityRowRadius),
      );
      final border = decoration.border! as Border;
      expect(border.top.width, OfficialCodexTheme.shellCardBorderWidth);
      expect(border.top.color, OfficialCodexThemeData.light.shellCardBorder);

      // Header detects /bin/bash -> "bash".
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shell-card-header')),
          matching: find.text('bash'),
        ),
        findsOneWidget,
      );

      // Command block clamps to 2 lines at rest and expands on click.
      final cmdToggle = find.byKey(const ValueKey('shell-card-command-toggle'));
      expect(tester.widget<Text>(cmdToggle).maxLines, 2);
      await tester.tap(cmdToggle);
      await tester.pump();
      expect(tester.widget<Text>(cmdToggle).maxLines, isNull);

      // Copy command copies unwrapped command without /bin/bash -lc wrapper.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(cmdToggle));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shell-card-copy-command')));
      await tester.pump();
      expect(clipboardText, 'echo alpha\necho beta\necho gamma\necho delta');

      // Output viewport is capped at 144px and bottom-anchored (reverse: true).
      final scrollFinder = find.byKey(
        const ValueKey('command-output-preview-scroll'),
      );
      expect(tester.getSize(scrollFinder).height, 144.0);
      expect(
        tester.widget<SingleChildScrollView>(scrollFinder).reverse,
        isTrue,
      );

      // Copy output copies raw output text.
      await mouse.moveTo(tester.getCenter(scrollFinder));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shell-card-copy-output')));
      await tester.pump();
      expect(clipboardText, tallOutput);
      await tester.pump(const Duration(milliseconds: 1500));

      // Footer renders check + "Success" for exitCode 0.
      final statusFooter = find.byKey(
        const ValueKey('shell-card-status-footer'),
      );
      expect(
        find.descendant(of: statusFooter, matching: find.text('Success')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: statusFooter,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );

      // Empty completed output renders "No output" and non-zero exit renders "Exit code {code}".
      await tester.pumpWidget(
        MaterialApp(
          home: OfficialCodexThemeProvider(
            data: OfficialCodexThemeData.dark,
            child: const Scaffold(
              body: SizedBox(
                width: 600,
                child: CodexShellExecutionCard(
                  rawCommand: 'Command: pytest -q',
                  output: '   \n  ',
                  status: 'failed',
                  exitCode: 2,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Shell'), findsOneWidget);
      expect(find.text('No output'), findsOneWidget);
      expect(find.text('Exit code 2'), findsOneWidget);

      // Interrupted status renders "Stopped".
      await tester.pumpWidget(
        MaterialApp(
          home: OfficialCodexThemeProvider(
            data: OfficialCodexThemeData.dark,
            child: const Scaffold(
              body: SizedBox(
                width: 600,
                child: CodexShellExecutionCard(
                  rawCommand: 'Command: sleep 30',
                  output: '',
                  status: 'interrupted',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Stopped'), findsOneWidget);

      // Non-zero exitCode overrides "completed" status to show numeric exit code.
      await tester.pumpWidget(
        MaterialApp(
          home: OfficialCodexThemeProvider(
            data: OfficialCodexThemeData.dark,
            child: const Scaffold(
              body: SizedBox(
                width: 600,
                child: CodexShellExecutionCard(
                  rawCommand: 'Command: exit 2',
                  output: 'failed check',
                  status: 'completed',
                  exitCode: 2,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Exit code 2'), findsOneWidget);
      expect(find.text('Success'), findsNothing);

      // Declined status without exitCode renders "Exit code unknown".
      await tester.pumpWidget(
        MaterialApp(
          home: OfficialCodexThemeProvider(
            data: OfficialCodexThemeData.dark,
            child: const Scaffold(
              body: SizedBox(
                width: 600,
                child: CodexShellExecutionCard(
                  rawCommand: 'Command: rm -rf build',
                  output: '',
                  status: 'declined',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Exit code unknown'), findsOneWidget);
      expect(find.text('Success'), findsNothing);

      // Unknown or missing status without exitCode must never imply "Success".
      for (final unrecognized in <String?>[null, '', 'unknown']) {
        await tester.pumpWidget(
          MaterialApp(
            home: OfficialCodexThemeProvider(
              data: OfficialCodexThemeData.dark,
              child: Scaffold(
                body: SizedBox(
                  width: 600,
                  child: CodexShellExecutionCard(
                    rawCommand: 'Command: echo probe',
                    output: 'probe',
                    status: unrecognized,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Success'), findsNothing);
        expect(
          find.byKey(const ValueKey('shell-card-status-footer')),
          findsNothing,
        );
      }
    },
  );

  testWidgets(
    'Desktop timeline unwraps collapsed -lc command, collapses header to Ran command when expanded, and shows PuGl.d Shell card without 28px expand button',
    (tester) async {
      final harness = _ShellCardTimelineHarness();
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('U6 shell thread'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('turn-work-u6-turn-1')));
      await tester.pumpAndSettle();

      // Collapsed row shows unwrapped command without /bin/bash -lc and without 28px expand icon button.
      expect(find.text('Ran git status --short'), findsOneWidget);
      expect(find.text('Ran false'), findsOneWidget);
      expect(find.text('Ran exit 2'), findsOneWidget);
      expect(find.text('Ran echo unknown'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);

      // Clicking full row expands the bash Shell card and switches row header to "Ran command".
      await tester.tap(find.text('Ran git status --short'));
      await tester.pumpAndSettle();

      expect(find.text('Ran command'), findsOneWidget);
      expect(find.text('Ran git status --short'), findsNothing);
      expect(
        find.byKey(const ValueKey('command-output-preview-surface')),
        findsOneWidget,
      );
      expect(find.text('bash'), findsOneWidget);
      expect(
        find.textContaining('git status --short', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('M lib/main.dart'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);

      // Collapse first card so subsequent footer checks remain unambiguous.
      await tester.tap(find.text('Ran command'));
      await tester.pumpAndSettle();

      // Failed command without protocol exitCode truthfully renders "Exit code unknown".
      await tester.tap(find.text('Ran false'));
      await tester.pumpAndSettle();
      expect(find.text('Exit code unknown'), findsOneWidget);
      await tester.tap(find.text('Ran command'));
      await tester.pumpAndSettle();

      // Descriptor exitCode projects numeric "Exit code 2" into PuGl.d.Footer.
      await tester.tap(find.text('Ran exit 2'));
      await tester.pumpAndSettle();
      expect(find.text('Exit code 2'), findsOneWidget);
      expect(find.text('Success'), findsNothing);
      await tester.tap(find.text('Ran command'));
      await tester.pumpAndSettle();

      // Unknown status with null exitCode does not imply "Success".
      await tester.tap(find.text('Ran echo unknown'));
      await tester.pumpAndSettle();
      expect(find.text('Success'), findsNothing);
      expect(
        find.byKey(const ValueKey('shell-card-status-footer')),
        findsNothing,
      );
    },
  );
}

class _ShellCardTimelineHarness extends SimulatedRuntimeHarness {
  _ShellCardTimelineHarness()
    : super(
        initialThreads: [
          createTestThread(id: 'u6-thread', preview: 'U6 shell thread'),
        ],
        initialHistoryTurns: [
          HistoryTurn(
            id: 'u6-turn-1',
            status: TurnRuntimeStatus.completed,
            startedAt: DateTime.utc(2026),
            completedAt: DateTime.utc(2026).add(const Duration(seconds: 3)),
            items: const [_user, _assistant],
          ),
        ],
        initialHistoryItems: const [
          _user,
          HistoryItem(
            id: 'u6-cmd-ok',
            turnId: 'u6-turn-1',
            kind: HistoryItemKind.activity,
            text: "Command: /bin/bash -lc 'git status --short'",
            status: 'completed',
            exitCode: 0,
            isCommand: true,
            output: OutputDescriptor(
              reference: 'u6-out-ok',
              bytes: 15,
              storedBytes: 15,
              truncated: false,
              available: true,
              exitCode: 0,
            ),
          ),
          HistoryItem(
            id: 'u6-cmd-fail',
            turnId: 'u6-turn-1',
            kind: HistoryItemKind.activity,
            text: 'Command: false',
            status: 'failed',
            isCommand: true,
            output: OutputDescriptor(
              reference: 'u6-out-fail',
              bytes: 11,
              storedBytes: 11,
              truncated: false,
              available: true,
            ),
          ),
          HistoryItem(
            id: 'u6-cmd-exit-2',
            turnId: 'u6-turn-1',
            kind: HistoryItemKind.activity,
            text: 'Command: exit 2',
            status: 'failed',
            exitCode: 2,
            isCommand: true,
            output: OutputDescriptor(
              reference: 'u6-out-exit-2',
              bytes: 10,
              storedBytes: 10,
              truncated: false,
              available: true,
              exitCode: 2,
            ),
          ),
          HistoryItem(
            id: 'u6-cmd-unknown',
            turnId: 'u6-turn-1',
            kind: HistoryItemKind.activity,
            text: 'Command: echo unknown',
            status: 'unknown',
            isCommand: true,
            output: OutputDescriptor(
              reference: 'u6-out-unknown',
              bytes: 7,
              storedBytes: 7,
              truncated: false,
              available: true,
            ),
          ),
          _assistant,
        ],
      ) {
    storeOutput('u6-out-ok', 'M lib/main.dart');
    storeOutput('u6-out-fail', 'error: boom');
    storeOutput('u6-out-exit-2', 'cache miss');
    storeOutput('u6-out-unknown', 'unknown');
  }

  static const _user = HistoryItem(
    id: 'u6-user',
    turnId: 'u6-turn-1',
    kind: HistoryItemKind.user,
    text: 'Check workspace git status.',
  );

  static const _assistant = HistoryItem(
    id: 'u6-assistant',
    turnId: 'u6-turn-1',
    kind: HistoryItemKind.assistant,
    text: 'Checked workspace status.',
  );
}
