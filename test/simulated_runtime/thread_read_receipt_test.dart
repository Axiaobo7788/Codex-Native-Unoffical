import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets('wide sidebar projects and updates a trailing unread receipt', (
    tester,
  ) async {
    final harness = _ReceiptHarness();
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    expect(_unreadIndicator, findsOneWidget);
    expect(tester.getSize(_unreadIndicator), const Size.square(8));
    expect(find.text('Read sibling'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('thread-timestamp-read-sibling')),
      findsNothing,
    );
    expect(
      tester.getCenter(_unreadIndicator).dx,
      greaterThan(tester.getCenter(find.text('Receipt fixture')).dx),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(_receiptRow));
    addTearDown(mouse.removePointer);
    await tester.pump();
    expect(_unreadIndicator, findsNothing);
    expect(_receiptMenu, findsOneWidget);
    await mouse.moveTo(const Offset(600, 20));
    await tester.pump();
    expect(_unreadIndicator, findsOneWidget);
    await tester.tap(find.text('Receipt fixture'));
    await tester.pumpAndSettle();
    expect(_unreadIndicator, findsOneWidget);
    expect(harness.writes, isEmpty);

    await _openMenu(tester, mouse);
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(harness.writes, [('saved', 'initial', false)]);
    expect(_unreadIndicator, findsNothing);
    await _openMenu(tester, mouse);
    await tester.tap(find.text('Mark as unread'));
    await tester.pumpAndSettle();
    await mouse.moveTo(const Offset(600, 20));
    await tester.pumpAndSettle();
    expect(harness.writes, [
      ('saved', 'initial', false),
      ('saved', 'after-1', true),
    ]);
    expect(_unreadIndicator, findsOneWidget);
    expect(harness.resumedThreadIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a passive unread receipt does not expose an unavailable write', (
    tester,
  ) async {
    final harness = _ReceiptHarness()..canWrite = false;
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    await tester.tap(find.text('Receipt fixture'));
    await tester.pumpAndSettle();
    expect(_unreadIndicator, findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(600, 20));
    addTearDown(mouse.removePointer);
    await _openMenu(tester, mouse);
    expect(find.text('Mark as read'), findsNothing);
    expect(find.text('Mark as unread'), findsNothing);
    expect(harness.writes, isEmpty);
  });
}

final _unreadIndicator = find.byKey(const ValueKey('thread-unread-saved'));
final _receiptRow = find.byKey(const ValueKey('thread-row-saved'));
final _receiptMenu = find.byKey(const ValueKey('thread-menu-saved'));

Future<void> _openMenu(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(tester.getCenter(_receiptRow));
  await tester.pump();
  await tester.tap(_receiptMenu);
  await tester.pumpAndSettle();
}

class _ReceiptHarness extends SimulatedRuntimeHarness {
  _ReceiptHarness()
    : super(
        initialThreads: [
          createTestThread(
            id: 'saved',
            preview: 'Receipt fixture',
            status: ThreadRuntimeStatus.notLoaded,
          ).copyWith(
            readReceipt: const ThreadReadReceipt(
              revision: 'initial',
              unread: true,
            ),
          ),
          createTestThread(id: 'read-sibling', preview: 'Read sibling'),
        ],
      );

  bool canWrite = true;
  final writes = <(String, String, bool)>[];

  @override
  bool get supportsThreadReadReceiptWrites => canWrite;

  @override
  Future<ThreadReadReceipt> setThreadReadReceipt({
    required String threadId,
    required String expectedRevision,
    required bool unread,
  }) async {
    writes.add((threadId, expectedRevision, unread));
    final receipt = ThreadReadReceipt(
      revision: 'after-${writes.length}',
      unread: unread,
    );
    final index = threads.indexWhere((thread) => thread.id == threadId);
    threads[index] = threads[index].copyWith(readReceipt: receipt);
    return receipt;
  }
}
