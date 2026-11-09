import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  group('Phase 1.6 Thread Sections & Sidebar Metadata simulated runtime', () {
    testWidgets(
      'creates, renames, moves, and deletes thread sections and renders bounded git/goal badges',
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

        // Verify initial section heading and bounded git/goal badges
        expect(
          find.byKey(const ValueKey('thread-section-heading-sec-initial')),
          findsOneWidget,
        );
        expect(find.text('In Progress'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('thread-git-badge-thread-alpha')),
          findsOneWidget,
        );
        expect(find.text('feat/thread-sections'), findsOneWidget);
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
  });
}
