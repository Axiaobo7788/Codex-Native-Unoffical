import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets('desktop navigation revisits threads across a viewport resize', (
    tester,
  ) async {
    final runtime = _NavigationHarness();
    await pumpSimulatedRuntimeApp(tester, harness: runtime);
    final back = find.byKey(const ValueKey('app-shell-back-button'));
    final forward = find.byKey(const ValueKey('app-shell-forward-button'));
    final header = find.byKey(const ValueKey('thread_header_bar'));

    Future<void> select(String id) async {
      await tester.tap(find.byKey(ValueKey('thread-row-$id')));
      await tester.pumpAndSettle();
    }

    void expectThread(String id) {
      expect(
        find.descendant(of: header, matching: find.text('Thread $id')),
        findsOneWidget,
      );
    }

    expect(tester.widget<CodexIconButton>(back).isEnabled, isFalse);
    expect(tester.widget<CodexIconButton>(forward).isEnabled, isFalse);
    await select('first');
    await select('second');
    expectThread('second');
    expect(tester.widget<CodexIconButton>(back).isEnabled, isTrue);

    tester.view.physicalSize = const Size(720, 800);
    await tester.pumpAndSettle();
    expect(back, findsNothing);
    tester.view.physicalSize = const Size(1191, 865);
    await tester.pumpAndSettle();

    runtime.failNextRead = true;
    await tester.tap(back);
    await tester.pumpAndSettle();
    expectThread('second');
    expect(tester.widget<CodexIconButton>(back).isEnabled, isTrue);
    expect(tester.widget<CodexIconButton>(forward).isEnabled, isFalse);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expectThread('first');
    expect(tester.widget<CodexIconButton>(back).isEnabled, isFalse);
    expect(tester.widget<CodexIconButton>(forward).isEnabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('conversation-composer')));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expectThread('second');

    Future<void> pressMouseButton(int buttons) async {
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: buttons,
      );
      await gesture.down(tester.getCenter(header));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await pressMouseButton(kBackMouseButton);
    expectThread('first');
    await pressMouseButton(kBackMouseButton);
    expectThread('first');
    await pressMouseButton(kForwardMouseButton);
    expectThread('second');
    await tester.tap(back);
    await tester.pumpAndSettle();
    await select('third');
    expectThread('third');
    expect(tester.widget<CodexIconButton>(forward).isEnabled, isFalse);
    expect(runtime.resumedThreadIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop Edit menu targets the focused composer', (tester) async {
    final runtime = _NavigationHarness();
    await pumpSimulatedRuntimeApp(tester, harness: runtime);
    await tester.tap(find.byKey(const ValueKey('thread-row-first')));
    await tester.pumpAndSettle();
    final composer = find.byKey(const ValueKey('conversation-composer'));
    await tester.enterText(composer, 'Edit this draft');
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(composer);

    Future<void> edit(String label) async {
      await tester.tap(
        find.widgetWithText(CodexButton, 'Edit'),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(label), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
    }

    await edit('Select All');
    expect(
      field.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 15),
    );
    expect(field.focusNode!.hasFocus, isTrue);
    await edit('Delete');
    expect(field.controller!.text, isEmpty);
    await edit('Undo');
    expect(field.controller!.text, 'Edit this draft');

    await tester.tap(find.widgetWithText(CodexButton, 'Help'));
    await tester.pumpAndSettle();
    expect(find.text('Documentation'), findsOneWidget);
    expect(find.text('Troubleshooting'), findsOneWidget);
    expect(find.text('System Status'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Documentation'), findsNothing);
    expect(field.controller!.text, 'Edit this draft');
  });
}

class _NavigationHarness extends SimulatedRuntimeHarness {
  _NavigationHarness()
    : super(
        initialThreads: [
          for (final id in ['first', 'second', 'third'])
            createTestThread(id: id, preview: 'Thread $id'),
        ],
      );

  var failNextRead = false;

  @override
  Future<ThreadSummary> readThread(String threadId) {
    if (failNextRead) {
      failNextRead = false;
      throw StateError('Disposable navigation read failure');
    }
    return super.readThread(threadId);
  }
}
