import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/remote_admin_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_harness.dart';

void main() {
  group('Tier 4: Real-World Application Scenarios (End-to-End User Journeys)', () {
    testWidgets('Scenario 1: Fresh Developer Onboarding & First Coding Turn', (
      tester,
    ) async {
      // App starts fresh with zero threads
      final harness = E2ERuntimeHarness(initialThreads: const []);
      await pumpE2EApp(tester, harness: harness);

      // 1. Landing view is visible
      expect(find.text('Let’s build'), findsOneWidget);

      // 2. User enters coding prompt
      final composer = find.byKey(const ValueKey('conversation-composer'));
      await tester.enterText(composer, 'Create an HTTP server in Dart');
      await tester.pumpAndSettle();

      // 3. User taps send button
      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();

      // 4. Thread auto-created and turn started
      expect(harness.startedThreadCwds.length, 1);
      expect(harness.startedTurns.length, 1);
      expect(harness.startedTurns.first.text, 'Create an HTTP server in Dart');

      final activeThreadId = harness.threads.first.id;

      // 5. Server streams back explanation and fenced code block
      const assistantCode =
          'Here is a simple HTTP server:\n\n```dart\nimport "dart:io";\nvoid main() async {\n  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);\n  print("Listening on 8080");\n}\n```\n';
      harness.emitAssistantMessage(
        'item-code-1',
        assistantCode,
        threadId: activeThreadId,
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Here is a simple HTTP server:',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('dart', findRichText: true), findsOneWidget);

      // 6. User clicks code block Copy action
      final copyButtons = find.text('Copy');
      expect(copyButtons, findsWidgets);
      await tester.tap(copyButtons.first);
      await tester.pumpAndSettle();

      // 7. Complete turn
      harness.emitTurnCompleted('turn-1', threadId: activeThreadId);
      await tester.pumpAndSettle();

      // Composer returns to active idle state ready for follow-up
      expect(
        find.byKey(const ValueKey('conversation-composer')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Scenario 2: Code Review, Approval, Diff & Output Workflow', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 't-review-flow',
        preview: 'Refactor database migrations',
        cwd: '/projects/migration-core',
      );
      const outRef = 'migration-out-ref';
      final harness = E2ERuntimeHarness(initialThreads: [thread]);
      harness.storeOutput(
        outRef,
        'Migration v2 applied: 3 tables created, 1 index added.',
      );

      await pumpE2EApp(tester, harness: harness);

      // 1. User selects project thread
      await tester.tap(find.text('Refactor database migrations'));
      await tester.pumpAndSettle();

      // 2. User submits prompt
      final composer = find.byKey(const ValueKey('conversation-composer'));
      await tester.enterText(composer, 'Run schema migration test');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('composer-send-button')));
      await tester.pumpAndSettle();

      // 3. Server requests command approval for cargo test
      harness.emitApproval(
        const ApprovalRequest(
          requestId: 'req-mig-1',
          kind: ApprovalKind.command,
          threadId: 't-review-flow',
          turnId: 'turn-1',
          itemId: 'item-mig-1',
          summary: 'cargo test --test migration',
          approveSupported: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approval required'), findsOneWidget);
      expect(
        find.textContaining('cargo test --test migration'),
        findsOneWidget,
      );

      // 4. User approves command
      await tester.tap(find.text('Approve once'));
      await tester.pumpAndSettle();

      expect(harness.approvalDecisions.length, 1);
      expect(
        harness.approvalDecisions.first.decision,
        ApprovalDecision.approveOnce,
      );

      // 5. Server emits file diff for schema.sql
      final snapshot = DiffSnapshot(
        threadId: 't-review-flow',
        turnId: 'turn-1',
        additions: 15,
        deletions: 2,
        truncated: false,
        files: const [
          DiffFile(
            path: 'schema.sql',
            additions: 15,
            deletions: 2,
            lines: [
              '+ CREATE TABLE users (id UUID PRIMARY KEY);',
              '+ CREATE INDEX idx_users ON users(id);',
            ],
            truncated: false,
          ),
        ],
      );
      harness.emitDiff(snapshot);
      await tester.pumpAndSettle();

      // 6. User opens diff viewer, verifies hunks
      final changesBtn = find.byKey(const ValueKey('changes-view-button'));
      await tester.tap(changesBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('schema.sql'), findsWidgets);
      expect(find.textContaining('CREATE TABLE users'), findsOneWidget);

      // Close diff view
      await tester.tap(changesBtn);
      await tester.pumpAndSettle();

      // 7. Complete turn
      harness.emitTurnCompleted('turn-1', threadId: 't-review-flow');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Scenario 3: Deep Investigation Session with History Navigation',
      (tester) async {
        final thread = createTestThread(
          id: 'deep-session-thread',
          preview: 'Deep research log',
        );
        // 35 historical turns
        final turns = List.generate(
          35,
          (i) => createTestTurn(
            id: 'turn-deep-$i',
            userPrompt: 'Research query item $i',
            assistantProse: 'Investigation notes for turn $i with details.',
          ),
        );

        final harness = E2ERuntimeHarness(
          initialThreads: [thread],
          initialHistoryTurns: turns,
        );
        await pumpE2EApp(tester, harness: harness);

        // 1. User opens long research thread
        await tester.tap(find.text('Deep research log'));
        await tester.pumpAndSettle();

        // 2. Lands at latest turn at bottom anchor (turn-0 in descending order)
        expect(find.text('Research query item 0'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('jump-to-latest-button')),
          findsNothing,
        );

        // 3. User scrolls up through older turns
        final timeline = find.byKey(const ValueKey('conversation-timeline'));
        await tester.drag(timeline, const Offset(0, 800));
        await tester.pumpAndSettle();

        // 4. Floating Jump to latest pill becomes visible
        expect(
          find.byKey(const ValueKey('jump-to-latest-button')),
          findsOneWidget,
        );

        // 5. User clicks Jump to latest
        await tester.tap(find.byKey(const ValueKey('jump-to-latest-button')));
        await tester.pumpAndSettle();

        // 6. Viewport smoothly returns to latest message at bottom
        expect(find.text('Research query item 0'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('jump-to-latest-button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Scenario 4: Project Organization, Search & Responsive Mode Switch',
      (tester) async {
        final thread1 = createTestThread(
          id: 't-org-1',
          preview: 'Refactor auth tokens',
          cwd: '/projects/Codex-Native',
        );
        final thread2 = createTestThread(
          id: 't-org-2',
          preview: 'Rust native host bindings',
          cwd: '/projects/fura-project',
        );

        final harness = E2ERuntimeHarness(initialThreads: [thread1, thread2]);
        await pumpE2EApp(tester, harness: harness, size: const Size(1400, 900));

        // 1. Project headings visible
        expect(find.text('Codex-Native'), findsOneWidget);
        expect(find.text('fura-project'), findsOneWidget);

        // 2. User presses search toggle
        await tester.tap(find.byKey(const ValueKey('thread-search-toggle')));
        await tester.pumpAndSettle();

        // 3. Filter by keyword
        final searchField = find.byKey(const ValueKey('thread-search-field'));
        await tester.enterText(searchField, 'Rust');
        await tester.pumpAndSettle();

        expect(find.text('Rust native host bindings'), findsOneWidget);
        expect(find.text('Refactor auth tokens'), findsNothing);

        // 4. Clear filter
        await tester.enterText(searchField, '');
        await tester.pumpAndSettle();

        expect(find.text('Refactor auth tokens'), findsOneWidget);
        expect(find.text('Rust native host bindings'), findsOneWidget);

        // 5. Window resizes to narrow mobile mode
        tester.view.physicalSize = const Size(550, 800);
        await tester.pumpAndSettle();

        // 6. Adapts cleanly to single-pane navigation without assertion error
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Scenario 5: Safety Overrides & Execution Settings', (
      tester,
    ) async {
      final thread = createTestThread(
        id: 't-safety-flow',
        preview: 'Production deployment script',
      );
      final harness = E2ERuntimeHarness(initialThreads: [thread]);
      await pumpE2EApp(tester, harness: harness);

      await tester.tap(find.text('Production deployment script'));
      await tester.pumpAndSettle();

      // 1. Open execution settings dialog
      await tester.tap(find.byKey(const ValueKey('composer-model-pill')));
      await tester.pumpAndSettle();

      expect(find.text('Execution settings'), findsOneWidget);

      // 2. Select model o3-mini
      await tester.tap(find.byKey(const ValueKey('execution-Model')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('o3-mini').last);
      await tester.pumpAndSettle();

      // 3. Attempt Approval mode: Never ask
      await tester.tap(find.byKey(const ValueKey('execution-Approval mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Never ask').last);
      await tester.pumpAndSettle();

      // 4. Warning dialog appears
      expect(find.text('Disable approval prompts?'), findsOneWidget);
      // User cancels
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // 5. User selects Danger: full access sandbox and confirms
      await tester.tap(find.byKey(const ValueKey('execution-Sandbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Danger: full access').last);
      await tester.pumpAndSettle();

      expect(find.text('Allow full filesystem access?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Allow full access'));
      await tester.pumpAndSettle();

      // 6. Close settings dialog
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Execution settings'), findsNothing);
    });

    testWidgets(
      'Scenario 6: Remote Pairing, Token Management & Device Revocation',
      (tester) async {
        final device = RemotePairedDevice(
          id: 'dev-tablet-1',
          name: 'Android Tablet (QA)',
          scopes: const {RemoteDeviceScope.read},
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          expiresAtMs: DateTime.now()
              .add(const Duration(days: 30))
              .millisecondsSinceEpoch,
          lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
          rotatedAtMs: null,
          revokedAtMs: null,
        );

        final harness = E2ERuntimeHarness(initialPairedDevices: [device]);
        await pumpE2EApp(tester, harness: harness);

        // 1. Open Remote setup from sidebar footer
        final remoteBtn = find.byKey(const ValueKey('remote-setup-button'));
        await tester.tap(remoteBtn);
        await tester.pumpAndSettle();

        expect(find.text('Remote setup'), findsOneWidget);
        expect(find.text('wss://127.0.0.1:8443'), findsOneWidget);

        // 2. Generate one-time pairing ticket
        final createTicketBtn = find.byKey(
          const ValueKey('remote-create-ticket-button'),
        );
        await tester.tap(createTicketBtn);
        await tester.pumpAndSettle();

        expect(harness.pairingTicketCounter, 1);
        expect(
          find.byKey(const ValueKey('remote-ticket-card')),
          findsOneWidget,
        );

        // 3. Verify paired device in list
        expect(find.text('Android Tablet (QA)'), findsOneWidget);

        // 4. Revoke device
        final revokeButton = find.widgetWithText(OutlinedButton, 'Revoke');
        await tester.ensureVisible(revokeButton);
        await tester.pumpAndSettle();
        await tester.tap(revokeButton);
        await tester.pumpAndSettle();

        expect(find.text('Revoke paired device?'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('remote-confirm-revoke-button')),
        );
        await tester.pumpAndSettle();

        // 5. Device purged from active list
        expect(harness.revokedDeviceIds, contains('dev-tablet-1'));
        expect(find.text('Android Tablet (QA)'), findsNothing);

        // 6. Close dialog
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        expect(find.text('Remote setup'), findsNothing);
      },
    );
  });
}
