import 'dart:async';

import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/domain/ecosystem_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Icons, InputBorder, TextField;
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

  testWidgets(
    'desktop Customize destination routes inline, preserves composer continuity, and participates in bounded Back/Forward',
    (tester) async {
      final runtime = _NavigationHarness();
      await pumpSimulatedRuntimeApp(tester, harness: runtime);
      final home = find.byKey(const ValueKey('app-shell-home-button'));
      final pluginsRail = find.byKey(const ValueKey('ecosystem-button'));
      final back = find.byKey(const ValueKey('app-shell-back-button'));
      final forward = find.byKey(const ValueKey('app-shell-forward-button'));

      expect(tester.widget<CodexIconButton>(home).tooltip, 'Home');
      expect(tester.widget<CodexIconButton>(pluginsRail).tooltip, 'Plugins');
      expect(tester.widget<CodexIconButton>(home).selected, isTrue);
      expect(tester.widget<CodexIconButton>(pluginsRail).selected, isFalse);
      final unselectedRailIcon =
          tester.widget<CodexIconButton>(pluginsRail).icon as Icon;
      expect(unselectedRailIcon.icon, Icons.widgets_outlined);
      expect(unselectedRailIcon.size, 20);

      await tester.tap(find.byKey(const ValueKey('thread-row-first')));
      await tester.pumpAndSettle();

      final composer = find.byKey(const ValueKey('conversation-composer'));
      await tester.enterText(composer, 'Unsent draft across Customize');
      await tester.pumpAndSettle();

      // Switch to Customize via rail: inline destination, no modal dialog.
      await tester.tap(pluginsRail);
      await tester.pumpAndSettle();
      expect(tester.widget<CodexIconButton>(home).selected, isFalse);
      expect(tester.widget<CodexIconButton>(pluginsRail).selected, isTrue);
      final selectedRailIcon =
          tester.widget<CodexIconButton>(pluginsRail).icon as Icon;
      expect(selectedRailIcon.icon, Icons.widgets_rounded);
      expect(selectedRailIcon.size, 20);
      expect(find.byKey(const ValueKey('customize-sidebar')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('customize-sidebar-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('customize-workspace-view')),
        findsOneWidget,
      );
      expect(find.text('Skills, Plugins & MCP'), findsNothing);

      // Search installed plugins toggle opens pill input; Escape closes & refocuses trigger without leaving Customize.
      final searchToggle = find.byKey(
        const ValueKey('customize-installed-search-toggle'),
      );
      await tester.tap(searchToggle);
      await tester.pumpAndSettle();
      final installedSearchField = find.byKey(
        const ValueKey('customize-installed-search-field'),
      );
      expect(installedSearchField, findsOneWidget);
      for (final searchFinder in [
        installedSearchField,
        find.byKey(const ValueKey('customize-workspace-search-field')),
      ]) {
        final decoration = tester.widget<TextField>(searchFinder).decoration!;
        expect(decoration.filled, isFalse);
        expect(decoration.border, InputBorder.none);
        expect(decoration.enabledBorder, InputBorder.none);
        expect(decoration.focusedBorder, InputBorder.none);
      }
      await tester.enterText(installedSearchField, 'nomatch');
      await tester.pump();
      expect(find.text('No matching plugins'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(installedSearchField, findsNothing);
      expect(
        find.byKey(const ValueKey('customize-workspace-view')),
        findsOneWidget,
      );
      expect(
        FocusManager.instance.primaryFocus?.context != null &&
            find
                .ancestor(
                  of: find.byWidget(
                    FocusManager.instance.primaryFocus!.context!.widget,
                  ),
                  matching: searchToggle,
                )
                .evaluate()
                .isNotEmpty,
        isTrue,
      );

      // Clicking an installed plugin in the contextual sidebar expands its detail on Plugins.
      await tester.tap(
        find.byKey(const ValueKey('customize-installed-plugin-git-workflow')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plugin-detail-git-workflow')),
        findsOneWidget,
      );

      // Collapsing the sidebar reveals inline section selector inside the Customize header.
      expect(
        find.byKey(const ValueKey('ecosystem-section-selector')),
        findsNothing,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ecosystem-section-selector')),
        findsOneWidget,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Navigate to Skills section, then Back -> Plugins -> Back -> Home (with draft preserved) -> Forward -> Plugins.
      await tester.tap(find.byKey(const ValueKey('customize-nav-skills')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('customize-page-title')))
            .data,
        'Skills',
      );

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('customize-page-title')))
            .data,
        'Plugins',
      );

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(tester.widget<CodexIconButton>(home).selected, isTrue);
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Unsent draft across Customize',
      );

      await tester.tap(forward);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('customize-workspace-view')),
        findsOneWidget,
      );

      // Keyboard Ctrl+[ Back from Customize restores Home focus so Ctrl+] Forward continues working,
      // and switching back to Customize dismisses any hovered Home tooltip overlay.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<CodexIconButton>(home).selected, isTrue);

      final hoverPointer = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await hoverPointer.addPointer(location: Offset.zero);
      addTearDown(hoverPointer.removePointer);
      await hoverPointer.moveTo(
        tester.getCenter(find.byKey(const ValueKey('thread-archive-toggle'))),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Show archived threads', skipOffstage: false),
        findsOneWidget,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('customize-workspace-view')),
        findsOneWidget,
      );
      expect(
        find.text('Show archived threads', skipOffstage: false),
        findsNothing,
      );

      // Also verify a pending (<300 ms) Home hover timer is disposed on route switch.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await hoverPointer.moveTo(Offset.zero);
      await tester.pump();
      await hoverPointer.moveTo(
        tester.getCenter(find.byKey(const ValueKey('thread-archive-toggle'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('Show archived threads', skipOffstage: false),
        findsNothing,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey('customize-workspace-view')),
        findsOneWidget,
      );
      expect(
        find.text('Show archived threads', skipOffstage: false),
        findsNothing,
      );

      // Viewport resize below desktop split preserves composer draft on compact and restores wide shell cleanly.
      tester.view.physicalSize = const Size(700, 800);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Unsent draft across Customize',
      );
      tester.view.physicalSize = const Size(1191, 865);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('customize-workspace-view')),
        findsOneWidget,
      );

      // Escape on Customize returns to Home conversation with draft intact.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.widget<CodexIconButton>(home).selected, isTrue);
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Unsent draft across Customize',
      );
    },
  );

  testWidgets(
    'delayed history read preserves a subsequently opened Plugins destination and keeps context/history coherent',
    (tester) async {
      final runtime = _DelayedNavigationHarness();
      await pumpSimulatedRuntimeApp(tester, harness: runtime);
      for (final id in ['first', 'second']) {
        await tester.tap(find.byKey(ValueKey('thread-row-$id')));
        await tester.pumpAndSettle();
      }

      final delayed = Completer<ThreadSummary>();
      runtime.delayedRead = delayed;
      try {
        await tester.tap(find.byKey(const ValueKey('app-shell-back-button')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();

        final customize = find.byKey(
          const ValueKey('customize-workspace-view'),
        );
        expect(customize, findsOneWidget);
        expect(find.text('project-two'), findsOneWidget);

        delayed.complete(
          runtime.threads.firstWhere((thread) => thread.id == 'first'),
        );
        await tester.pumpAndSettle();

        // Newer Customize route remains visible and updates its bound project context to 'first'.
        expect(customize, findsOneWidget);
        expect(find.text('project-one'), findsOneWidget);

        // History remains coherent: Back returns to the prior Home('second') entry, Forward returns to Customize('first').
        await tester.tap(find.byKey(const ValueKey('app-shell-back-button')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('thread_header_bar')),
            matching: find.text('Thread second'),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('app-shell-forward-button')),
        );
        await tester.pumpAndSettle();
        expect(customize, findsOneWidget);
        expect(find.text('project-one'), findsOneWidget);
      } finally {
        if (!delayed.isCompleted) {
          delayed.complete(
            runtime.threads.firstWhere((thread) => thread.id == 'first'),
          );
          await tester.pumpAndSettle();
        }
      }
    },
  );

  testWidgets(
    'Customize context lifetime isolates per-project catalogs and avoids eager Home ecosystem fetches',
    (tester) async {
      final alphaSkillsGate = Completer<List<SkillSummary>>();
      final harness = _ProjectScopedCustomizeHarness(
        alphaSkillsFuture: alphaSkillsGate.future,
      );
      addTearDown(() {
        if (!alphaSkillsGate.isCompleted) {
          alphaSkillsGate.complete(const <SkillSummary>[]);
        }
      });

      await pumpSimulatedRuntimeApp(tester, harness: harness);

      // Selecting threads on Home does not trigger background Customize catalog fetches.
      await tester.tap(find.byKey(const ValueKey('thread-row-alpha')));
      await tester.pumpAndSettle();
      expect(harness.skillQueryCwds, isEmpty);
      expect(harness.pluginQueryCwds, isEmpty);

      // Entering Customize fetches for Project Alpha; hold Alpha's listSkills in flight.
      await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
      await tester.pump();
      expect(harness.skillQueryCwds, [
        ['/projects/alpha'],
      ]);
      expect(harness.pluginQueryCwds, [
        ['/projects/alpha'],
      ]);

      // Return to Home, select Project Beta, and re-enter Customize on Skills.
      await tester.tap(find.byKey(const ValueKey('app-shell-home-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('thread-row-beta')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customize-nav-skills')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('skill-row-beta-skill')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('skill-row-alpha-skill')), findsNothing);

      // Late completion from disposed Project Alpha controller must not overwrite Project Beta state.
      alphaSkillsGate.complete(const [
        SkillSummary(
          name: 'alpha-skill',
          description: 'Stale skill from alpha',
          path: '/projects/alpha/.agents/skills/alpha/SKILL.md',
          enabled: true,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('skill-row-beta-skill')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('skill-row-alpha-skill')), findsNothing);
    },
  );
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

class _DelayedNavigationHarness extends SimulatedRuntimeHarness {
  _DelayedNavigationHarness()
    : super(
        initialThreads: [
          createTestThread(
            id: 'first',
            preview: 'Thread first',
            cwd: '/tmp/project-one',
          ),
          createTestThread(
            id: 'second',
            preview: 'Thread second',
            cwd: '/tmp/project-two',
          ),
        ],
      );

  Completer<ThreadSummary>? delayedRead;

  @override
  Future<ThreadSummary> readThread(String threadId) {
    final delayed = delayedRead;
    if (threadId == 'first' && delayed != null) {
      delayedRead = null;
      return delayed.future;
    }
    return super.readThread(threadId);
  }
}

class _ProjectScopedCustomizeHarness extends SimulatedRuntimeHarness {
  _ProjectScopedCustomizeHarness({required this.alphaSkillsFuture})
    : super(
        initialThreads: [
          createTestThread(
            id: 'alpha',
            preview: 'Alpha thread',
            cwd: '/projects/alpha',
          ),
          createTestThread(
            id: 'beta',
            preview: 'Beta thread',
            cwd: '/projects/beta',
          ),
        ],
      );

  final Future<List<SkillSummary>> alphaSkillsFuture;
  final List<List<String>> skillQueryCwds = <List<String>>[];
  final List<List<String>> pluginQueryCwds = <List<String>>[];

  @override
  Future<List<SkillSummary>> listSkills({
    List<String> cwds = const <String>[],
  }) {
    skillQueryCwds.add(List<String>.unmodifiable(cwds));
    if (cwds.contains('/projects/alpha')) {
      return alphaSkillsFuture;
    }
    return Future<List<SkillSummary>>.value(const [
      SkillSummary(
        name: 'beta-skill',
        description: 'Beta workspace skill',
        path: '/projects/beta/.agents/skills/beta/SKILL.md',
        enabled: true,
      ),
    ]);
  }

  @override
  Future<PluginCatalogSnapshot> listPluginCatalog({
    List<String> cwds = const <String>[],
  }) async {
    pluginQueryCwds.add(List<String>.unmodifiable(cwds));
    return super.listPluginCatalog(cwds: cwds);
  }
}
