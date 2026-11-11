import 'dart:async';

import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

// Only presentation-relevant admission/failure outcomes are emulated here.
// Real public-stock evidence for the unmaterialized read is preserved separately.
class _NewThreadHistoryHarness extends SimulatedRuntimeHarness {
  _NewThreadHistoryHarness() : super(initialThreads: []);

  final lifecycle = StreamController<ThreadLifecycleEvent>.broadcast(
    sync: true,
  );
  final unmaterialized = <String>{};
  final historyReads = <String>[];

  @override
  Stream<ThreadLifecycleEvent> get threadEvents => lifecycle.stream;

  @override
  Future<ThreadSummary> startThread(ThreadStartOptions options) async {
    final thread = await super.startThread(options);
    unmaterialized.add(thread.id);
    return thread;
  }

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async {
    historyReads.add(query.threadId);
    if (unmaterialized.contains(query.threadId)) {
      throw StateError(
        'thread is not materialized yet; history unavailable before first user message',
      );
    }
    return super.listHistoryTurns(query);
  }

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) {
    unmaterialized.remove(options.threadId);
    lifecycle.add(
      ThreadStatusChangedEvent(
        threadId: options.threadId,
        status: ThreadRuntimeStatus.active,
      ),
    );
    return super.startTurn(options);
  }

  @override
  Future<void> disposeHarness() async {
    await lifecycle.close();
    await super.disposeHarness();
  }
}

void main() {
  testWidgets(
    'New chat stays empty without premature history reads and admits history after the first turn',
    (tester) async {
      final harness = _NewThreadHistoryHarness();
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(1191, 865),
      );
      await tester.tap(find.byKey(const ValueKey('new-thread-button')));
      await tester.pumpAndSettle();
      expect(harness.startedThreadCwds, hasLength(1));
      expect(harness.historyReads, isEmpty);
      expect(find.text('Conversation unavailable'), findsNothing);
      expect(
        find.byKey(const ValueKey('conversation-composer')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('conversation-composer')),
        'First user message',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      // The active sidebar status animates until stock completes the turn.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.startedTurns, hasLength(1));
      expect(harness.historyReads, ['thread-created-1']);
      harness.emitAssistantMessage(
        'assistant-1',
        'First response',
        threadId: 'thread-created-1',
      );
      harness.emitTurnCompleted('turn-1', threadId: 'thread-created-1');
      harness.lifecycle.add(
        const ThreadStatusChangedEvent(
          threadId: 'thread-created-1',
          status: ThreadRuntimeStatus.idle,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conversation unavailable'), findsNothing);
      expect(
        find.text('First user message', findRichText: true),
        findsOneWidget,
      );
    },
  );
}
