import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  testWidgets('loaded filtering and saved thread search have distinct scopes', (
    tester,
  ) async {
    final harness = _SavedSearchHarness();
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    final recentRow = find.byKey(const ValueKey('thread-row-recent'));
    final savedRow = find.byKey(const ValueKey('thread-row-saved'));
    final search = find.byKey(const ValueKey('thread-search-field'));
    expect(recentRow, findsOneWidget);
    expect(savedRow, findsNothing);

    await tester.tap(find.byKey(const ValueKey('thread-search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(search, 'workspace');
    await tester.pumpAndSettle();
    expect(recentRow, findsOneWidget);
    expect(harness.savedSearchQueries, isEmpty);

    await tester.enterText(search, 'Cobalt');
    await tester.pumpAndSettle();
    expect(recentRow, findsNothing);
    expect(savedRow, findsNothing);
    expect(harness.savedSearchQueries, isEmpty);
    expect(find.byKey(const ValueKey('thread-search-saved')), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(harness.savedSearchQueries.single.searchTerm, 'Cobalt');
    expect(find.text('Saved matches for “Cobalt”'), findsOneWidget);
    expect(savedRow, findsOneWidget);
    expect(recentRow, findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(search, findsNothing);
    expect(recentRow, findsOneWidget);
    expect(savedRow, findsNothing);
  });
}

class _SavedSearchHarness extends SimulatedRuntimeHarness {
  _SavedSearchHarness()
    : super(
        initialThreads: [
          createTestThread(id: 'recent', preview: 'Recently opened'),
        ],
      );

  final savedSearchQueries = <ThreadListQuery>[];

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) async {
    if (query.searchTerm == null) {
      return super.listThreads(query);
    }
    savedSearchQueries.add(query);
    return ThreadPage(
      threads: [
        createTestThread(id: 'saved', preview: 'An older Cobalt thread'),
      ],
      nextCursor: null,
    );
  }
}
