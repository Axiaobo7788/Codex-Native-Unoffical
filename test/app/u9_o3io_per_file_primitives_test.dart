import 'dart:async';

import 'package:codex_native_unofficial/src/app/primitives/codex_activity_row.dart';
import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithTheme(
  Widget child, {
  OfficialCodexThemeData theme = OfficialCodexThemeData.light,
  double textScale = 1.0,
  double width = 640.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: OfficialCodexThemeProvider(
        data: theme,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test(
    'U9 O3Io path helpers match g3QY.ph workspace relativization and movePath',
    () {
      expect(codexPathBasename('/repo/lib/src/app/main.dart'), 'main.dart');
      expect(codexPathBasename(r'C:\Repo\pkg\alpha.ts\'), 'alpha.ts');

      // POSIX paths compare cwd case-sensitively.
      expect(
        formatCodexWorkspaceRelativePath(
          '/workspace/app/lib/a.dart',
          cwd: '/workspace/app/',
        ),
        'lib/a.dart',
      );
      expect(
        formatCodexWorkspaceRelativePath(
          '/Workspace/app/lib/a.dart',
          cwd: '/workspace/app',
        ),
        '/Workspace/app/lib/a.dart',
      );

      // Windows drive and UNC paths compare cwd case-insensitively and
      // normalize separators to forward slashes.
      expect(
        formatCodexWorkspaceRelativePath(
          r'c:\Users\Dev\Repo\src\index.ts',
          cwd: r'C:\users\dev\repo\',
        ),
        'src/index.ts',
      );
      expect(
        formatCodexWorkspaceRelativePath(
          r'\\Server\Share\Repo\pkg\mod.rs',
          cwd: '//server/share/repo',
        ),
        'pkg/mod.rs',
      );

      expect(
        formatCodexFileChangeTooltipPath(
          '/workspace/app/lib/old_name.dart',
          movePath: '/workspace/app/lib/new_name.dart',
          cwd: '/workspace/app',
        ),
        'lib/old_name.dart → lib/new_name.dart',
      );
    },
  );

  test(
    'U9 O3Io verbPrefixFor and expandedGenericTitleFor cover all statuses',
    () {
      expect(
        CodexPerFileChangeRow.verbPrefixFor(
          CodexFileChangeKind.add,
          CodexFileChangeStatus.inProgress,
        ),
        'Creating ',
      );
      expect(
        CodexPerFileChangeRow.verbPrefixFor(
          CodexFileChangeKind.add,
          CodexFileChangeStatus.stopped,
        ),
        'Stopped creating ',
      );
      expect(
        CodexPerFileChangeRow.verbPrefixFor(
          CodexFileChangeKind.add,
          CodexFileChangeStatus.rejected,
        ),
        'Rejected ',
      );
      expect(
        CodexPerFileChangeRow.verbPrefixFor(
          CodexFileChangeKind.add,
          CodexFileChangeStatus.applied,
        ),
        'Created ',
      );
      expect(
        CodexPerFileChangeRow.expandedGenericTitleFor(CodexFileChangeKind.add),
        'Created file',
      );

      expect(
        CodexPerFileChangeRow.verbPrefixFor(
          CodexFileChangeKind.delete,
          CodexFileChangeStatus.inProgress,
        ),
        'Deleting ',
      );
      expect(
        CodexPerFileChangeRow.verbPrefixFor(
          CodexFileChangeKind.delete,
          CodexFileChangeStatus.stopped,
        ),
        'Stopped deleting ',
      );
      expect(
        CodexPerFileChangeRow.verbPrefixFor(
          CodexFileChangeKind.delete,
          CodexFileChangeStatus.applied,
        ),
        'Deleted ',
      );
      expect(
        CodexPerFileChangeRow.expandedGenericTitleFor(
          CodexFileChangeKind.delete,
        ),
        'Deleted file',
      );

      expect(
        CodexPerFileChangeRow.verbPrefixFor(
          CodexFileChangeKind.update,
          CodexFileChangeStatus.inProgress,
        ),
        'Editing ',
      );
      expect(
        CodexPerFileChangeRow.verbPrefixFor(
          CodexFileChangeKind.unknown,
          CodexFileChangeStatus.stopped,
        ),
        'Stopped editing ',
      );
      expect(
        CodexPerFileChangeRow.expandedGenericTitleFor(
          CodexFileChangeKind.unknown,
        ),
        'Edited file',
      );
    },
  );

  testWidgets(
    'U9 O3Io collapsed rows render kind dots and swap title on ready expand',
    (tester) async {
      const createdItem = CodexPerFileChangeItem(
        id: 'f-add',
        path: '/repo/lib/created.dart',
        kind: CodexFileChangeKind.add,
        additions: 12,
        deletions: 0,
        bodyState: CodexFileDiffBodyState.ready,
        diffLines: ['+class Created {}'],
      );
      const deletedItem = CodexPerFileChangeItem(
        id: 'f-del',
        path: '/repo/lib/removed.dart',
        kind: CodexFileChangeKind.delete,
        additions: 0,
        deletions: 8,
        bodyState: CodexFileDiffBodyState.empty,
      );
      const updatedItem = CodexPerFileChangeItem(
        id: 'f-upd',
        path: '/repo/lib/updated.dart',
        kind: CodexFileChangeKind.update,
        additions: 3,
        deletions: 1,
        bodyState: CodexFileDiffBodyState.ready,
        diffLines: ['-old', '+new'],
      );

      var expanded = <String>{};
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _wrapWithTheme(
              CodexFileChangeActivityList(
                files: const [createdItem, deletedItem, updatedItem],
                cwd: '/repo',
                expandedFileIds: expanded,
                onToggleFile: (item) {
                  setState(() {
                    if (expanded.contains(item.id)) {
                      expanded = {...expanded}..remove(item.id);
                    } else {
                      expanded = {...expanded, item.id};
                    }
                  });
                },
              ),
            );
          },
        ),
      );

      expect(
        find.text('Created created.dart', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Deleted removed.dart', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Edited updated.dart', findRichText: true),
        findsOneWidget,
      );

      // Add and delete rows carry 6x6 chartBlue/chartRed dots; update has none.
      final addDot = tester.widget<Container>(
        find.byKey(const ValueKey('o3io-kind-dot-add')),
      );
      final delDot = tester.widget<Container>(
        find.byKey(const ValueKey('o3io-kind-dot-delete')),
      );
      expect(
        (addDot.decoration! as BoxDecoration).color,
        OfficialCodexTheme.chartBlue.withValues(alpha: 0.70),
      );
      expect(
        (delDot.decoration! as BoxDecoration).color,
        OfficialCodexThemeData.light.chartRed.withValues(alpha: 0.70),
      );
      expect(find.byKey(const ValueKey('o3io-kind-dot-update')), findsNothing);

      // Expand created.dart: outer header swaps to "Created file", dot hides,
      // and "+12" + "created.dart" appear once inside the disclosed af header.
      await tester.tap(find.byKey(const ValueKey('o3io-row-header-f-add')));
      await tester.pumpAndSettle();

      expect(find.text('Created file'), findsOneWidget);
      expect(find.text('created.dart'), findsOneWidget);
      expect(find.text('+12'), findsOneWidget);
      expect(find.byKey(const ValueKey('o3io-kind-dot-add')), findsNothing);

      // Expand removed.dart (empty 0-byte delete): outer header swaps to
      // "Deleted file" and am placeholder renders "Contents deleted".
      await tester.tap(find.byKey(const ValueKey('o3io-row-header-f-del')));
      await tester.pumpAndSettle();

      expect(find.text('Deleted file'), findsOneWidget);
      expect(find.text('Contents deleted'), findsOneWidget);
    },
  );

  testWidgets(
    'U9 O3Io retains filename on outer row when card header is absent',
    (tester) async {
      var retried = false;
      final oversized = const CodexPerFileChangeItem(
        id: 'f-large',
        path: '/repo/lib/giant_bundle.js',
        kind: CodexFileChangeKind.update,
        additions: 4200,
        deletions: 900,
        bodyState: CodexFileDiffBodyState.previewTooLarge,
      );
      final unavailable = CodexPerFileChangeItem(
        id: 'f-unavail',
        path: '/repo/lib/retired.dart',
        kind: CodexFileChangeKind.add,
        additions: 5,
        bodyState: CodexFileDiffBodyState.unavailable,
        onRetryPreview: () => retried = true,
      );
      const emptyUpdate = CodexPerFileChangeItem(
        id: 'f-nochange',
        path: '/repo/lib/mode_only.sh',
        kind: CodexFileChangeKind.update,
        bodyState: CodexFileDiffBodyState.empty,
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          CodexFileChangeActivityList(
            files: [oversized, unavailable, emptyUpdate],
            expandedFileIds: const {'f-large', 'f-unavail', 'f-nochange'},
            onToggleFile: (_) {},
          ),
        ),
      );

      // Oversized and unavailable states have no inner af card header, so the
      // outer row keeps "<Verb> <fileName>" and collapsed stats.
      expect(
        find.text('Edited giant_bundle.js', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('+4200'), findsOneWidget);
      expect(find.text('Diff too large to preview'), findsOneWidget);

      expect(
        find.text('Created retired.dart', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Diff preview unavailable'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);

      // Empty update has an inner af card header, so outer row uses generic
      // "Edited file" and body renders "No changes".
      expect(find.text('Edited file'), findsOneWidget);
      expect(find.text('mode_only.sh'), findsOneWidget);
      expect(find.text('No changes'), findsOneWidget);
    },
  );

  testWidgets(
    'U9 O3Io card enforces 240px viewport, 80-line cap, and awaited copy',
    (tester) async {
      String? copiedText;
      var failClipboard = false;
      final completer = Completer<void>();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              if (failClipboard) {
                throw PlatformException(code: 'CLIPBOARD_FAIL');
              }
              final args = call.arguments as Map<Object?, Object?>;
              copiedText = args['text'] as String?;
              await completer.future;
              return null;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final item = CodexPerFileChangeItem(
        id: 'f-scroll',
        path: '/repo/lib/virtualized.dart',
        kind: CodexFileChangeKind.update,
        additions: 90,
        deletions: 1,
        bodyState: CodexFileDiffBodyState.ready,
        diffLines: [
          '-const legacy = true;',
          for (var i = 1; i <= 90; i++) '+final line$i = $i;',
        ],
      );

      await tester.pumpWidget(
        _wrapWithTheme(CodexPerFileDiffCard(item: item, cwd: '/repo')),
      );

      final scrollFinder = find.byKey(
        const ValueKey('o3io-diff-scroll-f-scroll'),
      );
      expect(tester.getSize(scrollFinder).height, lessThanOrEqualTo(240.0));
      expect(find.text('-const legacy = true;'), findsOneWidget);

      // Scroll virtualized ListView.builder to bottom to materialize footer.
      await tester.drag(scrollFinder, const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(find.text('Showing bounded diff preview'), findsOneWidget);
      expect(find.text('+final line79 = 79;'), findsOneWidget);
      expect(find.text('+final line80 = 80;'), findsNothing);

      await tester.drag(scrollFinder, const Offset(0, 2500));
      await tester.pumpAndSettle();

      const copyKey = ValueKey('o3io-diff-copy-f-scroll');
      await tester.tap(find.byKey(copyKey));
      await tester.pump();
      expect(copiedText, contains('-const legacy = true;'));
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      completer.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1450));
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      failClipboard = true;
      await tester.tap(find.byKey(copyKey));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    },
  );

  testWidgets(
    'U9 O3Io list honors 16px/4px gap, showDiffDetails, overflow, and 2.0x',
    (tester) async {
      const files = [
        CodexPerFileChangeItem(
          id: 'a',
          path: '/repo/pkg/very_long_filename_alpha_component.dart',
          kind: CodexFileChangeKind.add,
          additions: 14,
          bodyState: CodexFileDiffBodyState.ready,
          diffLines: ['+a'],
        ),
        CodexPerFileChangeItem(
          id: 'b',
          path: '/repo/pkg/very_long_filename_beta_component.dart',
          kind: CodexFileChangeKind.update,
          additions: 4,
          deletions: 2,
          bodyState: CodexFileDiffBodyState.ready,
          diffLines: ['+b'],
        ),
      ];

      await tester.pumpWidget(
        _wrapWithTheme(
          CodexFileChangeActivityList(
            files: files,
            grouped: false,
            totalFileCount: 5,
            onToggleFile: (_) {},
          ),
        ),
      );

      final rowABottom = tester
          .getBottomLeft(find.byKey(const ValueKey('o3io-file-row-a')))
          .dy;
      final rowBTop = tester
          .getTopLeft(find.byKey(const ValueKey('o3io-file-row-b')))
          .dy;
      expect(rowBTop - rowABottom, closeTo(16.0, 0.01));
      expect(find.text('+3 more files not shown'), findsOneWidget);

      // Grouped mode uses 4px gap; showDiffDetails: false suppresses cards at
      // 2.0x text scale on narrow 320px width without overflow.
      await tester.pumpWidget(
        _wrapWithTheme(
          CodexFileChangeActivityList(
            files: files,
            grouped: true,
            showDiffDetails: false,
            expandedFileIds: const {'a', 'b'},
            onToggleFile: (_) {},
          ),
          textScale: 2.0,
          width: 320.0,
        ),
      );
      expect(tester.takeException(), isNull);
      final groupedABottom = tester
          .getBottomLeft(find.byKey(const ValueKey('o3io-file-row-a')))
          .dy;
      final groupedBTop = tester
          .getTopLeft(find.byKey(const ValueKey('o3io-file-row-b')))
          .dy;
      expect(groupedBTop - groupedABottom, closeTo(4.0, 0.01));
      expect(find.byKey(const ValueKey('o3io-diff-card-a')), findsNothing);
    },
  );

  testWidgets(
    'U9 O3Io raw non-unified add body renders markdown bullets as additions',
    (tester) async {
      const rawMarkdownAdd = CodexPerFileChangeItem(
        id: 'md-add',
        path: '/repo/NOTES.md',
        kind: CodexFileChangeKind.add,
        additions: 2,
        isUnifiedDiff: false,
        bodyState: CodexFileDiffBodyState.ready,
        diffLines: ['# Notes', '- bullet item'],
      );

      await tester.pumpWidget(
        _wrapWithTheme(const CodexPerFileDiffCard(item: rawMarkdownAdd)),
      );

      final bulletText = find.text('+- bullet item');
      expect(bulletText, findsOneWidget);
      final bulletBox = tester.widget<ColoredBox>(
        find.ancestor(of: bulletText, matching: find.byType(ColoredBox)).first,
      );
      expect(bulletBox.color, OfficialCodexThemeData.light.diffAddedFill);

      // Unknown kind with non-unified body stays neutral (no guessed +/- sign),
      // and unsupported + pathTruncated render truthfully without Retry.
      const unknownKindBody = CodexPerFileChangeItem(
        id: 'unk-raw',
        path: '/repo/deep/truncated_seg',
        pathTruncated: true,
        kind: CodexFileChangeKind.unknown,
        isUnifiedDiff: false,
        bodyState: CodexFileDiffBodyState.ready,
        diffLines: ['- not a deletion', '+ not an addition'],
      );
      const unsupportedBody = CodexPerFileChangeItem(
        id: 'remote-unsup',
        path: '/repo/remote.dart',
        kind: CodexFileChangeKind.update,
        additions: 2,
        deletions: 1,
        bodyState: CodexFileDiffBodyState.unsupported,
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          CodexFileChangeActivityList(
            files: const [unknownKindBody, unsupportedBody],
            expandedFileIds: const {'unk-raw', 'remote-unsup'},
            onToggleFile: (_) {},
          ),
        ),
      );

      final neutralLine = find.text('- not a deletion');
      expect(neutralLine, findsOneWidget);
      final neutralBox = tester.widget<ColoredBox>(
        find.ancestor(of: neutralLine, matching: find.byType(ColoredBox)).first,
      );
      expect(neutralBox.color, Colors.transparent);
      expect(find.text('truncated_seg…'), findsOneWidget);
      expect(
        find.text('Edited remote.dart', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Diff preview unsupported'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );
}
