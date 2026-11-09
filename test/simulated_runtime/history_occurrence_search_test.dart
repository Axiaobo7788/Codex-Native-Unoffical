import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets(
    'compact conversation finds a stored hit and opens only its turn window',
    (tester) async {
      final harness = _OccurrenceHarness();
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(720, 800),
      );
      await tester.tap(find.text('Searchable history'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('conversation-search-field')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('conversation-search-field')),
        'Needle',
      );
      await tester.pumpAndSettle();
      expect(harness.requests, isEmpty);
      expect(find.text('Newest visible turn'), findsOneWidget);

      await tester.tap(_savedSearch);
      await tester.pumpAndSettle();
      expect(find.text('Saved matches'), findsOneWidget);
      expect(harness.requests.single.searchTerm, 'Needle');
      expect(find.text('Newest visible turn'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('conversation-saved-search-next')),
      );
      await tester.pumpAndSettle();
      expect(harness.requests.last.cursor, 'next-occurrence');
      expect(harness.requests.last.searchTerm, 'Needle');
      expect(
        find.byKey(const ValueKey('conversation-saved-search-next')),
        findsNothing,
      );

      harness.staleAnchor = true;
      await tester.tap(_firstHit);
      await tester.pumpAndSettle();
      expect(
        find.text('This match is no longer available. Search again.'),
        findsOneWidget,
      );
      expect(find.text('Newest visible turn'), findsOneWidget);

      harness.staleAnchor = false;
      await tester.tap(_firstHit);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('conversation-timeline')),
          matching: find.text('Needle in an older message'),
        ),
        findsOneWidget,
      );
      expect(find.text('Newest visible turn'), findsNothing);
      expect(harness.resumedThreadIds, isEmpty);

      await tester.tap(find.text('Return to newest'));
      await tester.pumpAndSettle();
      expect(find.text('Newest visible turn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loaded-message find remains usable after a per-thread fallback',
    (tester) async {
      final harness = _OccurrenceHarness()..savedSearchUnsupported = true;
      await pumpSimulatedRuntimeApp(tester, harness: harness);
      await tester.tap(find.text('Searchable history'));
      await tester.pumpAndSettle();
      await _enterQuery(tester, 'visible');
      await tester.tap(_savedSearch);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Saved search is unavailable for this thread'),
        findsOneWidget,
      );
      expect(find.text('1 of 1 loaded'), findsOneWidget);
      expect(find.text('Newest visible turn'), findsOneWidget);
      expect(harness.resumedThreadIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

final _savedSearch = find.byKey(const ValueKey('conversation-search-saved'));
final _firstHit = find.byKey(const ValueKey('conversation-saved-search-hit-0'));

Future<void> _enterQuery(WidgetTester tester, String text) async {
  await tester.tap(find.byKey(const ValueKey('conversation-search-toggle')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('conversation-search-field')),
    text,
  );
  await tester.pumpAndSettle();
}

class _OccurrenceHarness extends SimulatedRuntimeHarness {
  _OccurrenceHarness()
    : super(
        initialThreads: [
          createTestThread(
            id: 'stored',
            preview: 'Searchable history',
            status: ThreadRuntimeStatus.notLoaded,
          ),
        ],
        initialHistoryTurns: [
          createTestTurn(id: 'newest', userPrompt: 'Newest visible turn'),
        ],
      );

  final requests = <HistoryOccurrenceQuery>[];
  var staleAnchor = false;
  var savedSearchUnsupported = false;

  @override
  bool get supportsHistoryOccurrences => !remoteModeOverride;

  @override
  Future<HistoryOccurrencePage> listHistoryOccurrences(
    HistoryOccurrenceQuery query,
  ) async {
    requests.add(query);
    if (savedSearchUnsupported) {
      throw UnsupportedError('Synthetic legacy thread');
    }
    return HistoryOccurrencePage(
      occurrences: const [
        HistoryOccurrence(
          turnId: 'older',
          itemId: 'user-older',
          turnCursor: 'opaque-turn-anchor',
          snippet: 'Needle in an older message',
          matchStart: 0,
          matchEnd: 6,
        ),
      ],
      nextCursor: query.cursor == null ? 'next-occurrence' : null,
    );
  }

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async {
    if (query.cursor == 'opaque-turn-anchor') {
      return HistoryTurnPage(
        turns: staleAnchor
            ? const []
            : [
                createTestTurn(
                  id: 'older',
                  userPrompt: 'Needle in an older message',
                ),
              ],
        nextCursor: null,
      );
    }
    return super.listHistoryTurns(query);
  }
}
