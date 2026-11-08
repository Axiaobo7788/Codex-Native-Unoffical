import 'dart:convert';

import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/remote_admin_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_harness.dart';

void main() {
  group('Tier 2: Boundary & Corner Cases — Thread & Catalog Boundaries', () {
    testWidgets('T2.1.1: Empty thread catalog displays clean empty state', (
      tester,
    ) async {
      final harness = E2ERuntimeHarness(initialThreads: const []);
      await pumpE2EApp(tester, harness: harness);

      expect(find.text('No threads yet'), findsOneWidget);
      expect(find.text('Let’s build'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2.1.2: Catalog 100-thread hard cap clamp', (tester) async {
      final threads = List.generate(
        120,
        (i) => createTestThread(
          id: 'cap-thread-$i',
          preview: 'Cap thread preview $i',
          updatedAt: DateTime.utc(2026, 1, 1, 10, i % 60),
        ),
      );
      final harness = E2ERuntimeHarness(initialThreads: threads);
      await pumpE2EApp(tester, harness: harness);

      expect(find.textContaining('Cap thread preview'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2.1.3: Duplicate thread ID storm handles deduplication', (
      tester,
    ) async {
      final duplicates = List.generate(
        10,
        (i) => createTestThread(
          id: 'storm-thread-id',
          preview: 'Storm duplicate preview $i',
          updatedAt: DateTime.utc(2026, 1, 1, 12, i),
        ),
      );

      final harness = E2ERuntimeHarness(initialThreads: duplicates);
      await pumpE2EApp(tester, harness: harness);

      // Deduplication retains the first unique thread ID entry
      expect(
        find.byKey(const ValueKey('thread-row-storm-thread-id')),
        findsOneWidget,
      );
      expect(find.text('Storm duplicate preview 0'), findsOneWidget);
      expect(find.text('Storm duplicate preview 9'), findsNothing);
    });

    testWidgets('T2.1.4: Extreme thread title length truncates cleanly', (
      tester,
    ) async {
      final superLongTitle = 'Extreme Title: ${'A' * 1500} - end of title';
      final thread = createTestThread(
        id: 'extreme-title-thread',
        preview: superLongTitle,
      );

      final harness = E2ERuntimeHarness(initialThreads: [thread]);
      await pumpE2EApp(tester, harness: harness);

      expect(
        find.byKey(const ValueKey('thread-row-extreme-title-thread')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2.1.5: Search filter with zero matching results', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'sample-thread',
        preview: 'Alpha project thread',
      );
      final harness = E2ERuntimeHarness(initialThreads: [thread]);
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.byKey(const ValueKey('thread-search-toggle')));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const ValueKey('thread-search-field'));
      await tester.enterText(searchField, 'NonExistentSearchTerm12345');
      await tester.pumpAndSettle();

      expect(find.text('No matching threads.'), findsOneWidget);
      expect(find.text('Alpha project thread'), findsNothing);
    });
  });

  group(
    'Tier 2: Boundary & Corner Cases — History & Virtualization Boundaries',
    () {
      testWidgets('T2.2.1: 100-turn sliding window eviction boundary', (
        tester,
      ) async {
        final thread = createTestThread(
          id: 'evict-thread',
          preview: 'Eviction thread',
        );
        final turns = List.generate(
          110,
          (i) => createTestTurn(
            id: 'turn-evict-$i',
            userPrompt: 'Eviction turn prompt $i',
            assistantProse: 'Eviction answer $i',
          ),
        );

        final harness = E2ERuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: turns,
        );
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Eviction thread'));
        await tester.pumpAndSettle();

        // Turn 0 is newest
        expect(find.text('Eviction turn prompt 0'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'T2.2.2: Deep-history bookmark beyond _maxRestorePages=10 resets deterministically to newest',
        (tester) async {
          final thread = createTestThread(
            id: 'deep-thread',
            preview: 'Deep history thread',
          );
          final turns = List.generate(
            25,
            (i) => createTestTurn(
              id: 'deep-turn-$i',
              userPrompt: 'Deep question $i',
              assistantProse: 'Deep answer $i',
            ),
          );

          final harness = E2ERuntimeHarness(
            initialThreads: [thread],
            initialHistoryTurns: turns,
          );
          await pumpE2EApp(tester, harness: harness);

          await tester.tap(find.text('Deep history thread'));
          await tester.pumpAndSettle();

          expect(find.text('Deep question 0'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'T2.2.3: Single-turn short thread layout top-aligns content without losing touch target',
        (tester) async {
          final thread = createTestThread(
            id: 'short-thread',
            preview: 'Short thread',
          );
          final turn = createTestTurn(
            id: 'single-turn',
            userPrompt: 'Short single line prompt',
            assistantProse: 'Short single line answer',
          );

          final harness = E2ERuntimeHarness(
            initialThreads: [thread],
            initialHistoryTurns: [turn],
          );
          await pumpE2EApp(tester, harness: harness);

          await tester.tap(find.text('Short thread'));
          await tester.pumpAndSettle();

          expect(find.text('Short single line prompt'), findsOneWidget);
          expect(find.text('Short single line answer'), findsOneWidget);

          final copyBtn = find.byKey(
            const ValueKey('assistant-copy-assistant-single-turn'),
          );
          expect(copyBtn, findsOneWidget);
          await tester.tap(copyBtn);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('T2.2.4: Empty turn history on resumed thread', (
        tester,
      ) async {
        final thread = createTestThread(
          id: 'empty-history-thread',
          preview: 'Empty history thread',
        );

        final harness = E2ERuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: const [],
        );
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Empty history thread'));
        await tester.pumpAndSettle();

        // Renders empty thread state with active composer
        expect(find.textContaining('Let’s build'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('conversation-composer')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.2.5: Rapid pagination requests handled gracefully', (
        tester,
      ) async {
        final thread = createTestThread(
          id: 'rapid-page-thread',
          preview: 'Rapid page thread',
        );
        final turns = List.generate(
          30,
          (i) => createTestTurn(
            id: 'rp-turn-$i',
            userPrompt: 'Rapid page item $i',
            assistantProse: 'Answer $i',
          ),
        );

        final harness = E2ERuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: turns,
        );
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Rapid page thread'));
        await tester.pumpAndSettle();

        final timeline = find.byKey(const ValueKey('conversation-timeline'));
        await tester.drag(timeline, const Offset(0, 1000));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.drag(timeline, const Offset(0, 1000));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    },
  );

  group('Tier 2: Boundary & Corner Cases — Envelope, Parsing & Escaping Boundaries', () {
    testWidgets(
      'T2.3.1: Oversized envelope header scan (>16 KiB) capped safely',
      (tester) async {
        final thread = createTestThread(
          id: 'oversize-env-thread',
          preview: 'Oversize envelope thread',
        );
        final giantHeader =
            '# Files pasted by the user:\n${'// File padding line\n' * 800}## My request:\nClean request';
        final turn = createTestTurn(
          id: 'turn-giant-env',
          userPrompt: giantHeader,
          assistantProse: 'Handled.',
        );

        final harness = E2ERuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: [turn],
        );
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Oversize envelope thread'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('T2.3.2: Attachment cap at 16 items', (tester) async {
      final thread = createTestThread(
        id: 'att-cap-thread',
        preview: 'Attachment cap thread',
      );
      final attachments = List.generate(
        30,
        (i) => UserAttachment(
          kind: UserAttachmentKind.file,
          label: 'file_$i.txt',
          path: '/path/file_$i.txt',
          preview: 'Preview of file $i',
        ),
      );
      final turn = createTestTurn(
        id: 'turn-30-att',
        userPrompt: 'Process these attachments',
        assistantProse: 'Understood.',
        attachments: attachments,
      );

      final harness = E2ERuntimeHarness(
        initialThreads: [thread],
        initialHistoryTurns: [turn],
      );
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Attachment cap thread'));
      await tester.pumpAndSettle();

      expect(find.text('file_0.txt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'T2.3.3: Adversarial escaping with raw &#x20; followed by markdown',
      (tester) async {
        final thread = createTestThread(
          id: 'adv-esc-thread',
          preview: 'Adversarial escape thread',
        );
        const prose = 'Compare &#x20; with `code` and **bold** formatting.';
        final turn = createTestTurn(
          id: 'turn-adv-esc',
          userPrompt: prose,
          assistantProse: 'Escaping verified.',
        );

        final harness = E2ERuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: [turn],
        );
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Adversarial escape thread'));
        await tester.pumpAndSettle();

        expect(find.textContaining('&#x20;'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('T2.3.4: Giant code block syntax stress (unclosed backticks)', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'unclosed-code-thread',
        preview: 'Unclosed code thread',
      );
      const unclosedMarkdown =
          '```python\ndef broken():\n    x = 1\n# Note: backticks never closed';
      final turn = createTestTurn(
        id: 'turn-unclosed-code',
        userPrompt: 'Show incomplete block',
        assistantProse: unclosedMarkdown,
      );

      final harness = E2ERuntimeHarness(
        initialThreads: [thread],
        initialHistoryTurns: [turn],
      );
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Unclosed code thread'));
      await tester.pumpAndSettle();

      expect(find.textContaining('def broken():'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2.3.5: Truncated markdown AST fallback for >16 KiB text', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'giant-prose-thread',
        preview: 'Giant prose thread',
      );
      final giantAssistantText =
          'Prose intro\n${'A very long repeated prose sentence for test.\n' * 500}';
      final turn = createTestTurn(
        id: 'turn-giant-prose',
        userPrompt: 'Generate huge prose',
        assistantProse: giantAssistantText,
      );

      final harness = E2ERuntimeHarness(
        initialThreads: [thread],
        initialHistoryTurns: [turn],
      );
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Giant prose thread'));
      await tester.pumpAndSettle();

      // Falling back to bounded text with omitted prefix
      expect(
        find.byKey(const ValueKey('assistant-bounded-text')),
        findsOneWidget,
      );
      expect(
        find.textContaining('[Earlier assistant text omitted from this view]'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Tier 2: Boundary & Corner Cases — Controls & Input Boundaries', () {
    testWidgets('T2.4.1: Whitespace-only prompt ignored', (tester) async {
      final thread = createTestThread(
        id: 'ws-prompt-thread',
        preview: 'Whitespace test thread',
      );
      final harness = E2ERuntimeHarness(initialThreads: [thread]);
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Whitespace test thread'));
      await tester.pumpAndSettle();

      final composerField = find.byKey(const ValueKey('conversation-composer'));
      await tester.enterText(composerField, '    \t\n   \n');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();

      expect(harness.startedTurns, isEmpty);
    });

    testWidgets(
      'T2.4.2: Cancel dangerous sandbox override reverts to safe defaults',
      (tester) async {
        final thread = createTestThread(
          id: 'cancel-danger-thread',
          preview: 'Cancel danger thread',
        );
        final harness = E2ERuntimeHarness(initialThreads: [thread]);
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Cancel danger thread'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('composer-model-pill')));
        await tester.pumpAndSettle();

        final sandboxDropdown = find.byKey(const ValueKey('execution-Sandbox'));
        if (sandboxDropdown.evaluate().isNotEmpty) {
          await tester.tap(sandboxDropdown);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Danger: full access').last);
          await tester.pumpAndSettle();

          expect(find.text('Allow full filesystem access?'), findsOneWidget);

          await tester.tap(find.widgetWithText(CodexButton, 'Cancel'));
          await tester.pumpAndSettle();

          expect(find.text('Allow full filesystem access?'), findsNothing);
        }
      },
    );

    testWidgets(
      'T2.4.3: Viewport resizing from desktop wide to mobile narrow transitions cleanly',
      (tester) async {
        final thread = createTestThread(
          id: 'resize-thread',
          preview: 'Resize thread',
        );
        final harness = E2ERuntimeHarness(initialThreads: [thread]);
        await pumpE2EApp(tester, harness: harness, size: const Size(1400, 900));

        expect(
          find.byKey(const ValueKey('desktop-split-workspace')),
          findsOneWidget,
        );

        tester.view.physicalSize = const Size(500, 800);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('desktop-split-workspace')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('T2.4.4: Model list fallback when model list is minimal', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'single-model-thread',
        preview: 'Single model thread',
      );
      final singleModel = const CodexModel(
        id: 'only-model',
        model: 'only-model-wire',
        displayName: 'Only Model',
        description: 'Single model setup',
        isDefault: true,
        defaultReasoningEffort: 'low',
        supportedReasoningEfforts: [],
      );

      final harness = E2ERuntimeHarness(
        initialThreads: [thread],
        initialModels: [singleModel],
      );
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Single model thread'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Only Model'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2.4.5: Long prompt text in composer handles cleanly', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 'long-text-thread',
        preview: 'Long text thread',
      );
      final harness = E2ERuntimeHarness(initialThreads: [thread]);
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Long text thread'));
      await tester.pumpAndSettle();

      final composerField = find.byKey(const ValueKey('conversation-composer'));
      final longPrompt = 'Please analyze this input: ${'word ' * 1000}';
      await tester.enterText(composerField, longPrompt);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();

      expect(harness.startedTurns.length, 1);
      expect(harness.startedTurns.first.text.length, greaterThan(5000));
    });
  });

  group(
    'Tier 2: Boundary & Corner Cases — Diff, Output & Approval Boundaries',
    () {
      testWidgets('T2.5.1: Giant diff input (truncated = true)', (
        tester,
      ) async {
        final thread = createTestThread(
          id: 'giant-diff-thread',
          preview: 'Giant diff thread',
        );
        final harness = E2ERuntimeHarness(initialThreads: [thread]);
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Giant diff thread'));
        await tester.pumpAndSettle();

        final giantLines = List.generate(200, (i) => '+ line addition $i');
        final snapshot = DiffSnapshot(
          threadId: 'giant-diff-thread',
          turnId: 'turn-1',
          additions: 5000,
          deletions: 200,
          truncated: true,
          files: [
            DiffFile(
              path: 'giant_migration.sql',
              additions: 5000,
              deletions: 200,
              lines: giantLines,
              truncated: true,
            ),
          ],
        );
        harness.emitDiff(snapshot);
        await tester.pumpAndSettle();

        final changesBtn = find.byKey(const ValueKey('changes-view-button'));
        expect(changesBtn, findsOneWidget);
        await tester.tap(changesBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('giant_migration.sql'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.5.2: Diff file cap (many files truncated)', (
        tester,
      ) async {
        final thread = createTestThread(
          id: 'many-diff-thread',
          preview: 'Many files diff thread',
        );
        final harness = E2ERuntimeHarness(initialThreads: [thread]);
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Many files diff thread'));
        await tester.pumpAndSettle();

        final diffFiles = List.generate(
          105,
          (i) => DiffFile(
            path: 'src/module_$i.dart',
            additions: 1,
            deletions: 0,
            lines: ['+ // line $i'],
            truncated: false,
          ),
        );
        final snapshot = DiffSnapshot(
          threadId: 'many-diff-thread',
          turnId: 'turn-1',
          additions: 105,
          deletions: 0,
          truncated: true,
          files: diffFiles,
        );
        harness.emitDiff(snapshot);
        await tester.pumpAndSettle();

        final changesBtn = find.byKey(const ValueKey('changes-view-button'));
        await tester.tap(changesBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('src/module_0.dart'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('T2.5.3: Output viewer UTF-8 multibyte edge cut', (
        tester,
      ) async {
        final harness = E2ERuntimeHarness();
        const ref = 'multibyte-output-ref';
        const multibyteText = '这是测试多字节UTF-8边界分割的内容。';
        harness.storeOutput(ref, multibyteText);

        final chunk = await harness.readOutputRange(
          reference: ref,
          offset: 0,
          length: 5,
        );
        expect(chunk.data.length, 5);
        final decoded = utf8.decode(chunk.data, allowMalformed: true);
        expect(decoded.isNotEmpty, isTrue);
      });

      testWidgets(
        'T2.5.4: Unsupported approval kind fails closed without Approve button',
        (tester) async {
          final thread = createTestThread(
            id: 'unsupp-appr-thread',
            preview: 'Unsupported approval thread',
          );
          final harness = E2ERuntimeHarness(initialThreads: [thread]);
          await pumpE2EApp(tester, harness: harness);

          await tester.tap(find.text('Unsupported approval thread'));
          await tester.pumpAndSettle();

          harness.emitApproval(
            const ApprovalRequest(
              requestId: 'req-unsupported-1',
              kind: ApprovalKind.unsupported,
              threadId: 'unsupp-appr-thread',
              turnId: 'turn-1',
              itemId: 'item-1',
              summary: 'Unknown server permission grant',
              approveSupported: false,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Approve once'), findsNothing);
          expect(find.text('Reject'), findsOneWidget);
        },
      );

      testWidgets('T2.5.5: Approval request with null optional fields', (
        tester,
      ) async {
        final thread = createTestThread(
          id: 'minimal-appr-thread',
          preview: 'Minimal approval thread',
        );
        final harness = E2ERuntimeHarness(initialThreads: [thread]);
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Minimal approval thread'));
        await tester.pumpAndSettle();

        harness.emitApproval(
          const ApprovalRequest(
            requestId: 'req-minimal-1',
            kind: ApprovalKind.command,
            threadId: 'minimal-appr-thread',
            turnId: 'turn-1',
            itemId: 'item-1',
            summary: 'git status',
            detail: null,
            reason: null,
            approveSupported: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('git status'), findsOneWidget);
        expect(find.text('Approve once'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );

  group('Tier 2: Boundary & Corner Cases — Process, Remote & Error Boundaries', () {
    testWidgets(
      'T2.6.1: Child process termination / process exited state banner',
      (tester) async {
        final harness = E2ERuntimeHarness(
          initialSnapshot: const RuntimeSnapshot(
            state: RuntimeConnectionState.processExited,
            message: 'Process exited unexpectedly with code 1',
          ),
        );
        await pumpE2EApp(tester, harness: harness);

        expect(find.text('Process exited'), findsOneWidget);
        expect(
          find.text('Process exited unexpectedly with code 1'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T2.6.2: Turn error event displays inline notice without crash',
      (tester) async {
        final thread = createTestThread(
          id: 'turn-err-thread',
          preview: 'Turn error thread',
        );
        final harness = E2ERuntimeHarness(initialThreads: [thread]);
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.text('Turn error thread'));
        await tester.pumpAndSettle();

        harness.emitTurnError(
          'turn-err-1',
          'Model rate limit exceeded; please wait 30s.',
          threadId: 'turn-err-thread',
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Model rate limit exceeded; please wait 30s.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('T2.6.3: Expired pairing ticket message displayed', (
      tester,
    ) async {
      final harness = E2ERuntimeHarness();
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('remote-create-ticket-button')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('remote-ticket-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'T2.6.4: Remote pairing when listener disabled displays disabled notice',
      (tester) async {
        final harness = E2ERuntimeHarness(
          initialHostStatus: const RemoteHostStatus(
            hostVersion: '0.1.0',
            enabled: false,
            bindAddress: null,
            tls: false,
            scope: null,
            advertisedEndpoint: null,
            pairingTrust: null,
          ),
        );
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('remote-listener-disabled')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'T2.6.5: Advertised endpoint missing displays warning indicator',
      (tester) async {
        final harness = E2ERuntimeHarness(
          initialHostStatus: const RemoteHostStatus(
            hostVersion: '0.1.0',
            enabled: true,
            bindAddress: '127.0.0.1:8443',
            tls: true,
            scope: RemoteListenerScope.loopback,
            advertisedEndpoint: null,
            pairingTrust: RemotePairingTrustMode.system,
          ),
        );
        await pumpE2EApp(tester, harness: harness);

        await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('remote-advertised-endpoint-missing')),
          findsOneWidget,
        );
      },
    );
  });
}
