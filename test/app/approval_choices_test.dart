import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../simulated_runtime/simulated_runtime_harness.dart';

void main() {
  for (final size in [const Size(1191, 865), const Size(700, 760)]) {
    testWidgets('typed approval choices are reachable at $size', (
      tester,
    ) async {
      final harness = SimulatedRuntimeHarness(
        initialThreads: [
          createTestThread(id: 'thread', preview: 'Choices thread'),
        ],
      );
      await pumpSimulatedRuntimeApp(tester, harness: harness, size: size);
      await tester.tap(find.text('Choices thread').first);
      await tester.pumpAndSettle();
      final rule = ApprovalDecision.withExecpolicyAmendment([
        'printf',
        'fixed argument',
      ]);
      harness.emitApproval(
        ApprovalRequest(
          requestId: 'choice',
          kind: ApprovalKind.command,
          threadId: 'thread',
          turnId: 'turn',
          itemId: 'item',
          summary: 'Run bounded fixture command',
          approveSupported: false,
          decisions: [
            ApprovalDecision.approveOnce,
            rule,
            ApprovalDecision.cancelTurn,
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose an approval response'));
      await tester.pumpAndSettle();
      expect(find.text('Allow similar commands'), findsOneWidget);
      expect(find.text('Approve for session'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('approval-details-scroll')),
          matching: find.textContaining('1: "printf"\n2: "fixed argument"'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Allow similar commands'));
      await tester.pumpAndSettle();
      expect(harness.approvalDecisions.single.decision, same(rule));
      expect(find.text('Approval required'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('session approval and turn cancellation have distinct actions', (
    tester,
  ) async {
    final harness = SimulatedRuntimeHarness(
      initialThreads: [
        createTestThread(id: 'thread', preview: 'Choices thread'),
      ],
    );
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    await tester.tap(find.text('Choices thread').first);
    await tester.pumpAndSettle();
    harness.emitApproval(
      const ApprovalRequest(
        requestId: 'session',
        kind: ApprovalKind.fileChange,
        threadId: 'thread',
        turnId: 'turn',
        itemId: 'item',
        summary: 'Edit files',
        approveSupported: false,
        decisions: [
          ApprovalDecision.approveForSession,
          ApprovalDecision.cancelTurn,
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose an approval response'));
    await tester.pumpAndSettle();
    expect(find.text('Approve for session'), findsOneWidget);
    expect(find.text('Stop turn'), findsOneWidget);
    expect(find.text('Approve once'), findsNothing);
    await tester.tap(find.text('Stop turn'));
    await tester.pumpAndSettle();
    expect(
      harness.approvalDecisions.single.decision,
      same(ApprovalDecision.cancelTurn),
    );
  });

  testWidgets('response picker escapes and retires without granting consent', (
    tester,
  ) async {
    final harness = SimulatedRuntimeHarness(
      initialThreads: [
        createTestThread(id: 'thread', preview: 'Choices thread'),
      ],
    );
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    await tester.tap(find.text('Choices thread').first);
    await tester.pumpAndSettle();
    harness.emitApproval(
      const ApprovalRequest(
        requestId: 'choice',
        kind: ApprovalKind.fileChange,
        threadId: 'thread',
        turnId: 'turn',
        itemId: 'item',
        summary: 'Edit files',
        approveSupported: false,
        decisions: [
          ApprovalDecision.approveForSession,
          ApprovalDecision.cancelTurn,
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose an approval response'));
    await tester.pumpAndSettle();
    expect(find.text('Stop turn'), findsOneWidget);
    expect(harness.approvalDecisions, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Stop turn'), findsNothing);
    expect(harness.approvalDecisions, isEmpty);
    await tester.tap(find.byTooltip('Choose an approval response'));
    await tester.pumpAndSettle();
    await harness.decideApproval(
      requestId: 'choice',
      decision: ApprovalDecision.reject,
    );
    await tester.pumpAndSettle();
    expect(find.text('Stop turn'), findsNothing);
    expect(find.text('Approval required'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit multiline rule text cannot spoof another argument', (
    tester,
  ) async {
    final harness = SimulatedRuntimeHarness(
      initialThreads: [
        createTestThread(id: 'thread', preview: 'Choices thread'),
      ],
    );
    await pumpSimulatedRuntimeApp(tester, harness: harness);
    await tester.tap(find.text('Choices thread').first);
    await tester.pumpAndSettle();
    final rule = ApprovalDecision.withExecpolicyAmendment([
      'printf',
      'one\n2: hidden\r',
    ]);
    harness.emitApproval(
      ApprovalRequest(
        requestId: 'choice',
        kind: ApprovalKind.command,
        threadId: 'thread',
        turnId: 'turn',
        itemId: 'item',
        summary: 'Run a proposed command',
        approveSupported: false,
        decisions: [rule, ApprovalDecision.reject],
      ),
    );
    await tester.pumpAndSettle();
    final details = tester
        .widget<SelectableText>(
          find
              .descendant(
                of: find.byKey(const ValueKey('approval-details-scroll')),
                matching: find.byType(SelectableText),
              )
              .last,
        )
        .data!;
    expect(details, contains(r'2: "one\n2: hidden\r"'));
    expect(details, isNot(contains('one\n2: hidden')));
    await tester.tap(find.byTooltip('Choose an approval response'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow similar commands'));
    await tester.pumpAndSettle();
    expect(harness.approvalDecisions.single.decision, same(rule));
    expect(rule.execpolicyAmendment.last, 'one\n2: hidden\r');
  });
}
