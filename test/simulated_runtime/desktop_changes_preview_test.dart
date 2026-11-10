import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets('running Changes previews files and opens the selected patch', (
    tester,
  ) async {
    final runtime = SimulatedRuntimeHarness(
      initialThreads: [
        createTestThread(id: 'diff-fixture', preview: 'Diff fixture'),
      ],
    );
    await pumpSimulatedRuntimeApp(tester, harness: runtime);
    await tester.tap(find.text('Diff fixture'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('conversation-composer')),
      'Make a disposable change',
    );
    await tester.tap(find.byKey(const ValueKey('composer-send-button')));
    await tester.pump();
    runtime.emitDiff(
      const DiffSnapshot(
        threadId: 'diff-fixture',
        turnId: 'turn-1',
        files: [
          DiffFile(
            path: 'src/first.txt',
            additions: 1,
            deletions: 0,
            lines: ['+first disposable patch'],
            truncated: false,
          ),
          DiffFile(
            path: 'src/second.txt',
            additions: 1,
            deletions: 0,
            lines: ['+second disposable patch'],
            truncated: false,
          ),
        ],
        additions: 2,
        deletions: 0,
        truncated: false,
      ),
    );
    await tester.pump();

    final chip = find.byKey(const ValueKey('changes-view-button'));
    final preview = find.byKey(const ValueKey('desktop-changes-file-preview'));
    expect(preview, findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(chip));
    addTearDown(mouse.removePointer);
    await tester.pump(const Duration(milliseconds: 310));
    await tester.pump(const Duration(milliseconds: 180));
    expect(preview, findsOneWidget);
    expect(tester.getRect(preview).bottom, lessThan(tester.getRect(chip).top));
    final second = find.descendant(
      of: preview,
      matching: find.text('second.txt'),
    );
    expect(
      tester.widget<Text>(second).style?.color,
      OfficialCodexTheme.of(tester.element(second)).textPrimary,
    );
    await mouse.moveTo(tester.getCenter(second));
    await tester.pump(const Duration(milliseconds: 350));
    expect(preview, findsOneWidget);
    await tester.tap(second);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(preview, findsNothing);
    expect(chip, findsNothing);
    expect(find.textContaining('second disposable patch'), findsOneWidget);
    expect(find.textContaining('first disposable patch'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
