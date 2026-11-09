import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets('local sidebar marks the displayed receipt without resuming', (
    tester,
  ) async {
    final harness = _ReceiptHarness();
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    expect(_unreadIndicator, findsOneWidget);
    await tester.tap(find.text('Receipt fixture'));
    await tester.pumpAndSettle();
    expect(_unreadIndicator, findsOneWidget);
    expect(harness.writes, isEmpty);

    await _openMenu(tester);
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(harness.writes, [('saved', 'initial', false)]);
    expect(_unreadIndicator, findsNothing);
    await _openMenu(tester);
    await tester.tap(find.text('Mark as unread'));
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
    await _openMenu(tester);
    expect(find.text('Mark as read'), findsNothing);
    expect(find.text('Mark as unread'), findsNothing);
    expect(_unreadIndicator, findsOneWidget);
    expect(harness.writes, isEmpty);
  });
}

final _unreadIndicator = find.byKey(const ValueKey('thread-unread-saved'));

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('thread-menu-saved')));
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
