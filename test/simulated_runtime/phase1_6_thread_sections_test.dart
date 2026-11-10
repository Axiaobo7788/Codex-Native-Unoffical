import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  group('Phase 1.6 Thread Sections & Sidebar Metadata simulated runtime', () {
    testWidgets('desktop keeps saved pins reachable without an empty section', (
      tester,
    ) async {
      const pinned = ThreadSection(
        id: kBuiltInPinnedThreadSectionId,
        name: 'Pinned',
      );
      final ordinary = createTestThread(id: 'ordinary', preview: 'Ordinary');
      final saved = createTestThread(
        id: 'saved-pin',
        preview: 'Saved pin outside the loaded catalog',
      ).copyWith(section: pinned);
      final harness = _OrderedSectionHarness(
        global: [ordinary],
        ordered: [saved],
      )..threadSections.add(pinned);
      await pumpSimulatedRuntimeApp(tester, harness: harness);

      final headerActions = find.byKey(
        const ValueKey('desktop-project-header-actions'),
      );
      final actionsRect = tester.getRect(headerActions);
      expect(tester.widget<Opacity>(headerActions).opacity, 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Projects')));
      await tester.pump();
      expect(tester.widget<Opacity>(headerActions).opacity, 1);
      expect(tester.getRect(headerActions), actionsRect);
      await mouse.removePointer();
      await tester.pump();
      expect(tester.widget<Opacity>(headerActions).opacity, 0);
      final archive = find.byKey(const ValueKey('thread-archive-toggle'));
      final archiveFocus = Focus.of(
        tester.element(
          find
              .descendant(of: archive, matching: find.byType(GestureDetector))
              .last,
        ),
      );
      archiveFocus.requestFocus();
      await tester.pumpAndSettle();
      expect(archiveFocus.hasFocus, isTrue);
      expect(tester.widget<Opacity>(headerActions).opacity, 1);
      archiveFocus.unfocus();
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(headerActions).opacity, 0);

      expect(
        find.byKey(const ValueKey('pinned-threads-heading')),
        findsNothing,
      );
      expect(harness.scopedQueries, isEmpty);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse saved pins'));
      await tester.pumpAndSettle();

      expect(harness.scopedQueries.single.section?.id, pinned.id);
      expect(find.text('Saved in stock Pinned only'), findsOneWidget);
      expect(find.text('Saved pin outside the loaded catalog'), findsOneWidget);
    });

    testWidgets(
      'browses the ordered section without replacing the active thread',
      (tester) async {
        const section = ThreadSection(id: 'review-queue', name: 'Review queue');
        final outside = createTestThread(
          id: 'outside',
          preview: 'Active outside',
        );
        final first = createTestThread(
          id: 'first',
          preview: 'Ordered first',
        ).copyWith(section: section);
        final second = createTestThread(
          id: 'second',
          preview: 'Ordered second',
        ).copyWith(section: section);
        final harness = _OrderedSectionHarness(
          global: [outside, second, first],
          ordered: [first, second],
        )..threadSections.add(section);
        await pumpSimulatedRuntimeApp(tester, harness: harness);
        await tester.tap(find.text('Active outside'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('thread-section-menu-review-queue')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Browse section'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('thread-section-scope-name')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('thread-row-outside')), findsNothing);
        expect(find.text('Active outside'), findsWidgets);
        expect(find.byKey(const ValueKey('thread-row-first')), findsOneWidget);
        expect(find.byKey(const ValueKey('thread-row-second')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('thread-search-toggle')));
        await tester.pumpAndSettle();
        final filter = find.byKey(const ValueKey('thread-search-field'));
        await tester.enterText(filter, 'Ordered second');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('thread-row-first')), findsNothing);
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('thread-row-second')), findsOneWidget);
        await tester.enterText(filter, '');
        await tester.pumpAndSettle();
        final firstRow = find.byKey(const ValueKey('thread-row-first'));
        final secondRow = find.byKey(const ValueKey('thread-row-second'));
        expect(
          tester.getTopLeft(firstRow).dy,
          lessThan(tester.getTopLeft(secondRow).dy),
        );
        expect(harness.scopedQueries.map((query) => query.cursor), [
          null,
          'scoped-next',
        ]);

        await tester.tap(
          find.byKey(const ValueKey('thread-section-scope-back')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('thread-section-scope-name')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('thread-row-outside')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'manages thread sections and retains Git context and goal metadata',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final harness = SimulatedRuntimeHarness();
        harness.threadSections.add(
          const ThreadSection(id: 'sec-initial', name: 'In Progress'),
        );
        harness.threads.addAll([
          ThreadSummary(
            id: 'thread-alpha',
            sessionId: 'session-alpha',
            preview: 'Alpha feature thread',
            cwd: '/workspace/app',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 2),
            status: ThreadRuntimeStatus.idle,
            ephemeral: false,
            name: 'Alpha Thread',
            gitInfo: const ThreadGitInfo(
              branch: 'feat/thread-sections',
              sha: 'abcdef1234567890',
            ),
            goal: const ThreadGoal(
              objective: 'Ship bounded sidebar sections',
              status: ThreadGoalStatus.active,
              createdAtSeconds: 1700000000,
              updatedAtSeconds: 1700000050,
              tokensUsed: 120,
              timeUsedSeconds: 15,
            ),
          ),
          ThreadSummary(
            id: 'thread-beta',
            sessionId: 'session-beta',
            preview: 'Beta section thread',
            cwd: '/workspace/app',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 2),
            status: ThreadRuntimeStatus.idle,
            ephemeral: false,
            name: 'Beta Thread',
            section: const ThreadSection(
              id: 'sec-initial',
              name: 'In Progress',
            ),
            sectionEnteredAtSeconds: 1700000100,
          ),
        ]);

        await tester.pumpWidget(CodexNativeApp(runtimeController: harness));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('thread-section-heading-sec-initial')),
          findsOneWidget,
        );
        expect(find.text('In Progress'), findsOneWidget);
        expect(
          find.byTooltip('Alpha Thread\nGit · feat/thread-sections'),
          findsOneWidget,
        );
        expect(find.text('feat/thread-sections'), findsNothing);
        expect(
          find.byKey(const ValueKey('thread-goal-badge-thread-alpha')),
          findsOneWidget,
        );
        expect(find.text('Ship bounded sidebar sections'), findsOneWidget);

        // Create a new section from sidebar header
        final createBtn = find.byKey(
          const ValueKey('thread-section-create-button'),
        );
        expect(createBtn, findsOneWidget);
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('thread-section-name-field')),
          'Release Blockers',
        );
        await tester.tap(
          find.byKey(const ValueKey('thread-section-save-button')),
        );
        await tester.pumpAndSettle();

        expect(harness.createdThreadSections, hasLength(1));
        expect(harness.createdThreadSections.single.name, 'Release Blockers');

        // Select Alpha Thread and move it to Release Blockers via thread menu
        await tester.tap(find.byKey(const ValueKey('thread-row-thread-alpha')));
        await tester.pumpAndSettle();

        final alphaMenuBtn = find.byKey(
          const ValueKey('thread-menu-thread-alpha'),
        );
        expect(alphaMenuBtn, findsOneWidget);
        await tester.tap(alphaMenuBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Move to section…'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Release Blockers'),
          ),
        );
        await tester.pumpAndSettle();

        expect(harness.movedThreadSections, hasLength(1));
        expect(harness.movedThreadSections.single.threadId, 'thread-alpha');
        expect(harness.movedThreadSections.single.sectionId, 'section-1');
        expect(
          find.byKey(const ValueKey('thread-section-heading-section-1')),
          findsOneWidget,
        );

        // Rename section via section heading menu
        await tester.tap(
          find.byKey(const ValueKey('thread-section-menu-section-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rename section'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('thread-section-name-field')),
          'Critical Blockers',
        );
        await tester.tap(
          find.byKey(const ValueKey('thread-section-save-button')),
        );
        await tester.pumpAndSettle();

        expect(harness.updatedThreadSections, hasLength(1));
        expect(harness.updatedThreadSections.single.name, 'Critical Blockers');
        expect(find.text('Critical Blockers'), findsOneWidget);

        // Live notification moves thread-alpha out of section
        harness.emitThreadSectionChanged('thread-alpha', null);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('thread-section-heading-section-1')),
          findsOneWidget,
        );

        // Delete section sec-initial via section heading menu
        await tester.tap(
          find.byKey(const ValueKey('thread-section-menu-sec-initial')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete section'));
        await tester.pumpAndSettle();

        expect(harness.deletedThreadSectionIds, ['sec-initial']);
        expect(
          find.byKey(const ValueKey('thread-section-heading-sec-initial')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'moves to a retained section beyond the first eight destinations',
      (tester) async {
        tester.view.physicalSize = const Size(900, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = SimulatedRuntimeHarness();
        harness.threadSections.addAll([
          for (var index = 0; index < 16; index++)
            ThreadSection(id: 'section-$index', name: 'Section $index'),
        ]);
        harness.threads.add(
          ThreadSummary(
            id: 'movable',
            sessionId: 'session',
            preview: '',
            cwd: '/workspace',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            status: ThreadRuntimeStatus.idle,
            ephemeral: false,
            name: 'Movable thread',
            section: harness.threadSections.first,
          ),
        );
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Movable thread'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('thread-menu-movable')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Move to section…'));
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        final destination = find.descendant(
          of: dialog,
          matching: find.text('Section 15'),
        );
        await tester.scrollUntilVisible(
          destination,
          160,
          scrollable: find.descendant(
            of: dialog,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(destination);
        await tester.pumpAndSettle();
        await tester.tap(destination);
        await tester.pumpAndSettle();
        expect(harness.movedThreadSections.single.sectionId, 'section-15');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'read-only Remote hides thread section creation and mutation actions',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final harness = SimulatedRuntimeHarness()..remoteModeOverride = true;
        harness.threads.add(
          ThreadSummary(
            id: 'thread-remote',
            sessionId: 'session-remote',
            preview: 'Remote thread',
            cwd: '/workspace/remote',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 2),
            status: ThreadRuntimeStatus.idle,
            ephemeral: false,
            name: 'Remote Thread',
          ),
        );

        await tester.pumpWidget(CodexNativeApp(runtimeController: harness));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('thread-section-create-button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'unifies built-in Pinned and session pins, protects built-in Pinned by ID, and scopes Browse to saved Pinned only',
      (tester) async {
        const builtInPinned = ThreadSection(
          id: kBuiltInPinnedThreadSectionId,
          name: 'Pinned',
        );
        const customPinned = ThreadSection(
          id: 'custom-pinned-sec',
          name: 'Pinned',
        );
        const customWork = ThreadSection(id: 'work-sec', name: 'In Progress');

        final savedPinThread = createTestThread(
          id: 'thread-saved-pin',
          preview: 'Saved pinned thread',
        ).copyWith(name: 'Saved Pin Thread', section: builtInPinned);
        final workThread = createTestThread(
          id: 'thread-work-pin',
          preview: 'Work section thread',
        ).copyWith(name: 'Work Thread', section: customWork);
        final customPinnedThread = createTestThread(
          id: 'thread-custom-pinned',
          preview: 'Custom pinned section thread',
        ).copyWith(name: 'Custom Pinned Thread', section: customPinned);

        final harness = _OrderedSectionHarness(
          global: [savedPinThread, workThread, customPinnedThread],
          ordered: [savedPinThread, savedPinThread],
        )..threadSections.addAll([builtInPinned, customPinned, customWork]);

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        // Unified Pinned heading renders once at top; custom section named Pinned renders separately
        expect(
          find.byKey(const ValueKey('pinned-threads-heading')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey(
              'thread-section-heading-$kBuiltInPinnedThreadSectionId',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey('thread-section-heading-custom-pinned-sec'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('thread-pin-badge-thread-saved-pin')),
          findsOneWidget,
        );
        expect(find.text('Saved pin'), findsOneWidget);

        // Built-in Pinned menu offers only 'Browse saved pins' (no Rename/Delete)
        await tester.tap(
          find.byKey(
            const ValueKey(
              'thread-section-menu-$kBuiltInPinnedThreadSectionId',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Browse saved pins'), findsOneWidget);
        expect(find.text('Rename section'), findsNothing);
        expect(find.text('Delete section'), findsNothing);
        // Close popover by tapping outside
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Custom section named 'Pinned' still offers Rename and Delete
        await tester.tap(
          find.byKey(const ValueKey('thread-section-menu-custom-pinned-sec')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Browse section'), findsOneWidget);
        expect(find.text('Rename section'), findsOneWidget);
        expect(find.text('Delete section'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Session-pinning a custom-section thread keeps its section and shows 'Session pin · In Progress'
        await tester.tap(
          find.byKey(const ValueKey('thread-row-thread-work-pin')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('thread-menu-thread-work-pin')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pin for session'), findsOneWidget);
        await tester.tap(find.text('Pin for session'));
        await tester.pumpAndSettle();

        expect(harness.movedThreadSections, isEmpty);
        expect(find.text('2 loaded'), findsOneWidget);
        expect(find.text('Session pin · In Progress'), findsOneWidget);

        // Browsing saved Pinned section scopes to persisted stock membership only
        await tester.tap(
          find.byKey(
            const ValueKey(
              'thread-section-menu-$kBuiltInPinnedThreadSectionId',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Browse saved pins'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('thread-section-scope-pinned-note')),
          findsOneWidget,
        );
        expect(find.text('Saved in stock Pinned only'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('thread-row-thread-saved-pin')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('thread-row-thread-work-pin')),
          findsNothing,
        );
      },
    );
  });
}

class _OrderedSectionHarness extends SimulatedRuntimeHarness {
  _OrderedSectionHarness({
    required List<ThreadSummary> global,
    required this.ordered,
  }) : super(initialThreads: global);

  final List<ThreadSummary> ordered;
  final List<ThreadListQuery> scopedQueries = [];

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) async {
    if (query.section == null) {
      return super.listThreads(query);
    }
    scopedQueries.add(query);
    return query.cursor == null
        ? ThreadPage(threads: [ordered.first], nextCursor: 'scoped-next')
        : ThreadPage(threads: [ordered.last], nextCursor: null);
  }
}
