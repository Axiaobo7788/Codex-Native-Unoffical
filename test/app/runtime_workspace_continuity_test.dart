import 'dart:async';

import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../simulated_runtime/simulated_runtime_harness.dart';

void main() {
  testWidgets('manual history Retry also retires the old live projection', (
    tester,
  ) async {
    final harness = _TransientHistoryRuntime();
    await pumpSimulatedRuntimeApp(
      tester,
      harness: harness,
      size: const Size(1191, 865),
    );
    await tester.tap(find.text('Retry history context'));
    await tester.pumpAndSettle();
    harness.emitAssistantMessage(
      'retry-item',
      'Retained before transient read',
      threadId: 'retry-history',
    );
    await tester.pumpAndSettle();
    harness.updateSnapshot(
      const RuntimeSnapshot(state: RuntimeConnectionState.processExited),
    );
    await tester.pumpAndSettle();
    harness.failHistory = true;
    harness.historyTurns.add(
      const HistoryTurn(
        id: 'turn-1',
        status: TurnRuntimeStatus.completed,
        items: [
          HistoryItem(
            id: 'retry-item',
            turnId: 'turn-1',
            kind: HistoryItemKind.assistant,
            text: 'Saved after manual history Retry',
          ),
        ],
      ),
    );
    harness.updateSnapshot(
      const RuntimeSnapshot(state: RuntimeConnectionState.connected),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Retained before transient read', findRichText: true),
      findsOneWidget,
    );
    harness.failHistory = false;
    await tester.tap(find.text('Retry').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Retained before transient read', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining(
        'Saved after manual history Retry',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(harness.startedTurns, isEmpty);
    expect(harness.resumedThreadIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('runtime loss dismisses root-overlay composer popovers', (
    tester,
  ) async {
    final harness = SimulatedRuntimeHarness(
      initialThreads: [
        createTestThread(id: 'popover-runtime', preview: 'Popover runtime'),
      ],
    );
    await pumpSimulatedRuntimeApp(
      tester,
      harness: harness,
      size: const Size(1191, 865),
    );
    await tester.tap(find.text('Popover runtime'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer-attach-button')));
    await tester.pumpAndSettle();
    expect(find.text('Attach file (@mention)').hitTestable(), findsOneWidget);
    harness.updateSnapshot(
      const RuntimeSnapshot(state: RuntimeConnectionState.processExited),
    );
    await tester.pumpAndSettle();
    expect(find.text('Attach file (@mention)').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final compact in [false, true]) {
    testWidgets(
      'unavailable session draft needs explicit replacement (compact=$compact)',
      (tester) async {
        final harness = _SessionLostRuntime();
        await pumpSimulatedRuntimeApp(
          tester,
          harness: harness,
          size: const Size(1191, 865),
        );
        await tester.tap(find.text('New chat'));
        await tester.pumpAndSettle();
        final oldId = harness.threads.first.id;
        final cwd = harness.startedThreadCwds.single;
        final composer = find.byKey(const ValueKey('conversation-composer'));
        await tester.enterText(
          composer,
          'Keep draft across explicit replacement',
        );
        await tester.tap(find.byKey(const ValueKey('composer-attach-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Attach file (@mention)'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('composer-attachment-primary-field')),
          'keep.md',
        );
        await tester.tap(
          find.byKey(const ValueKey('composer-attachment-confirm-button')),
        );
        await tester.pumpAndSettle();
        if (compact) {
          tester.view.physicalSize = const Size(700, 760);
          await tester.pumpAndSettle();
        }
        final editor = tester.widget<TextField>(composer).controller!;
        harness.lostThreadId = oldId;
        harness.threads.removeWhere((thread) => thread.id == oldId);
        harness.updateSnapshot(
          const RuntimeSnapshot(state: RuntimeConnectionState.processExited),
        );
        await tester.pumpAndSettle();
        harness.updateSnapshot(
          const RuntimeSnapshot(state: RuntimeConnectionState.connected),
        );
        await tester.pumpAndSettle();
        expect(harness.startedThreadCwds, [cwd]);
        await tester.tap(find.byKey(const ValueKey('composer-send-button')));
        await tester.pumpAndSettle();
        expect(harness.startedTurns, isEmpty);
        expect(harness.resumedThreadIds, isEmpty);
        expect(
          find.byKey(const ValueKey('runtime-draft-new-conversation')),
          findsOneWidget,
        );
        harness.failReplacement = true;
        await tester.tap(
          find.byKey(const ValueKey('runtime-draft-new-conversation')),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('Fixture replacement denied'),
          ),
          findsOneWidget,
        );
        expect(harness.startedThreadCwds, [cwd]);
        expect(editor.text, 'Keep draft across explicit replacement');
        expect(
          find.byKey(const ValueKey('composer-attachment-chip-0')),
          findsOneWidget,
        );
        harness.failReplacement = false;
        await tester.tap(
          find.byKey(const ValueKey('runtime-draft-new-conversation')),
        );
        await tester.pumpAndSettle();
        expect(harness.startedThreadCwds, [cwd, cwd]);
        expect(harness.startedTurns, isEmpty);
        expect(tester.widget<TextField>(composer).controller, same(editor));
        expect(editor.text, 'Keep draft across explicit replacement');
        expect(
          find.byKey(const ValueKey('composer-attachment-chip-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('runtime-draft-new-conversation')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('composer-send-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(harness.startedTurns, hasLength(1));
        expect(harness.startedTurns.single.threadId, isNot(oldId));
        expect(harness.startedTurns.single.attachments, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'recovery replaces the dead live projection with freshly saved history',
    (tester) async {
      final harness = SimulatedRuntimeHarness(
        initialThreads: [
          createTestThread(id: 'same-history', preview: 'History recovery'),
        ],
      );
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('History recovery'));
      await tester.pumpAndSettle();
      harness.emitAssistantMessage(
        'same-item',
        'Old retained live output',
        threadId: 'same-history',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Old retained live output', findRichText: true),
        findsOneWidget,
      );
      harness.updateSnapshot(
        const RuntimeSnapshot(state: RuntimeConnectionState.processExited),
      );
      await tester.pumpAndSettle();
      harness.historyTurns.add(
        const HistoryTurn(
          id: 'turn-1',
          status: TurnRuntimeStatus.completed,
          items: [
            HistoryItem(
              id: 'same-item',
              turnId: 'turn-1',
              kind: HistoryItemKind.assistant,
              text: 'Freshly saved authoritative output',
            ),
          ],
        ),
      );
      harness.updateSnapshot(
        const RuntimeSnapshot(state: RuntimeConnectionState.connected),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Old retained live output', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining(
          'Freshly saved authoritative output',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(harness.resumedThreadIds, isEmpty);
      expect(harness.startedTurns, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'local runtime loss preserves the mounted draft and attachments',
    (tester) async {
      final harness = SimulatedRuntimeHarness(
        initialThreads: [
          createTestThread(
            id: 'runtime-loss-thread',
            preview: 'Runtime loss work',
          ),
        ],
      );
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.text('Runtime loss work'));
      await tester.pumpAndSettle();
      final composer = find.byKey(const ValueKey('conversation-composer'));
      await tester.enterText(
        composer,
        'Keep this unsent work after runtime loss',
      );
      await tester.tap(find.byKey(const ValueKey('composer-attach-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attach file (@mention)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('composer-attachment-primary-field')),
        'preserved-draft.md',
      );
      await tester.tap(
        find.byKey(const ValueKey('composer-attachment-confirm-button')),
      );
      await tester.pumpAndSettle();
      final editor = tester.widget<TextField>(composer).controller!;
      expect(
        find.byKey(const ValueKey('composer-attachment-chip-0')),
        findsOneWidget,
      );

      // This is a typed presentation integration fixture, not a real process
      // crash. The packaged stock/Host crash path must be exercised separately.
      harness.updateSnapshot(
        const RuntimeSnapshot(
          state: RuntimeConnectionState.processExited,
          message: 'Owned fixture runtime stopped.',
        ),
      );
      await tester.pumpAndSettle();

      expect(composer, findsOneWidget);
      expect(tester.widget<TextField>(composer).controller, same(editor));
      expect(editor.text, 'Keep this unsent work after runtime loss');
      expect(
        find.byKey(const ValueKey('composer-attachment-chip-0')),
        findsOneWidget,
      );
      expect(harness.startedTurns, isEmpty);
      harness.updateSnapshot(
        const RuntimeSnapshot(
          state: RuntimeConnectionState.connected,
          processId: 1002,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(composer).controller, same(editor));
      expect(editor.text, 'Keep this unsent work after runtime loss');
      expect(
        find.byKey(const ValueKey('composer-attachment-chip-0')),
        findsOneWidget,
      );
      expect(harness.resumedThreadIds, isEmpty);
      expect(harness.startedTurns, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('late turn acknowledgement cannot erase the recovered draft', (
    tester,
  ) async {
    final harness = _PendingTurnRuntime();
    await pumpSimulatedRuntimeApp(
      tester,
      harness: harness,
      size: const Size(1191, 865),
    );
    await tester.tap(find.text('Pending runtime work'));
    await tester.pumpAndSettle();
    final composer = find.byKey(const ValueKey('conversation-composer'));
    await tester.enterText(
      composer,
      'Possibly admitted work; retain before retry',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('composer-send-button')));
    await tester.pump();
    expect(harness.startedTurns, hasLength(1));
    harness.updateSnapshot(
      const RuntimeSnapshot(state: RuntimeConnectionState.processExited),
    );
    await tester.pumpAndSettle();
    harness.turnGate.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(composer).controller!.text,
      'Possibly admitted work; retain before retry',
    );
    harness.updateSnapshot(
      const RuntimeSnapshot(state: RuntimeConnectionState.connected),
    );
    await tester.pumpAndSettle();
    expect(harness.startedTurns, hasLength(1));
    expect(harness.resumedThreadIds, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _PendingTurnRuntime extends SimulatedRuntimeHarness {
  _PendingTurnRuntime()
    : super(
        initialThreads: [
          createTestThread(
            id: 'pending-runtime',
            preview: 'Pending runtime work',
          ),
        ],
      );
  final turnGate = Completer<void>();
  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) async {
    final turn = await super.startTurn(options);
    await turnGate.future;
    return turn;
  }
}

class _SessionLostRuntime extends SimulatedRuntimeHarness {
  _SessionLostRuntime() : super(initialThreads: []);
  String? lostThreadId;
  bool failReplacement = false;
  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) {
    if (failReplacement) throw StateError('Fixture replacement denied');
    return super.startThread(options);
  }

  @override
  Future<ThreadSummary> readThread(String threadId) {
    if (threadId == lostThreadId) {
      throw StateError('Fixture thread not loaded in new runtime');
    }
    return super.readThread(threadId);
  }
}

class _TransientHistoryRuntime extends SimulatedRuntimeHarness {
  _TransientHistoryRuntime()
    : super(
        initialThreads: [
          createTestThread(
            id: 'retry-history',
            preview: 'Retry history context',
          ),
        ],
      );
  bool failHistory = false;
  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) {
    if (failHistory) throw StateError('Transient owned history failure');
    return super.listHistoryTurns(query);
  }
}
