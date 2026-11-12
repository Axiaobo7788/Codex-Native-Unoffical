import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../simulated_runtime/simulated_runtime_harness.dart';

void main() {
  testWidgets(
    'opposite persistent rules remain distinguishable in a short split',
    (tester) async {
      final harness = SimulatedRuntimeHarness(
        initialThreads: [
          createTestThread(id: 'thread', preview: 'Choices thread'),
        ],
      );
      await pumpSimulatedRuntimeApp(
        tester,
        harness: harness,
        size: const Size(840, 420),
      );
      await tester.tap(find.text('Choices thread').first);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('sidebar-resize-handle')),
        const Offset(310, 0),
      );
      await tester.pumpAndSettle();
      harness.emitApproval(
        ApprovalRequest(
          requestId: 'network',
          kind: ApprovalKind.command,
          threadId: 'thread',
          turnId: 'turn',
          itemId: 'item',
          summary: 'Connect to example.invalid',
          approveSupported: false,
          decisions: [
            ApprovalDecision.withNetworkPolicyAmendment(
              host: 'example.invalid',
              action: ApprovalNetworkAction.allow,
            ),
            ApprovalDecision.withNetworkPolicyAmendment(
              host: 'example.invalid',
              action: ApprovalNetworkAction.deny,
            ),
            ApprovalDecision.approveForSession,
            ApprovalDecision.approveOnce,
            ApprovalDecision.reject,
            ApprovalDecision.cancelTurn,
          ],
        ),
      );
      await tester.pumpAndSettle();
      // Both a direct strip and an overflow response picker must show the actual
      // decision before it can be selected; opening a picker grants nothing.
      final picker = find.byTooltip('Choose an approval response');
      if (picker.evaluate().isNotEmpty) {
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(harness.approvalDecisions, isEmpty);
      }
      for (final label in [
        'Always allow example.invalid',
        'Always deny example.invalid',
      ]) {
        final text = find.text(label);
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        final criticalPrefix = label.startsWith('Always allow')
            ? 'Always allow…'
            : 'Always deny…';
        final measurement = TextPainter(
          text: TextSpan(text: criticalPrefix, style: paragraph.text.style),
          textDirection: TextDirection.ltr,
          textScaler: paragraph.textScaler,
        )..layout();
        final requiredWidth = measurement.width;
        measurement.dispose();
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(requiredWidth),
          reason: 'The allow/deny verb must stay visible before any hostname ellipsis.',
        );
      }
      await tester.tap(find.text('Always deny example.invalid'));
      await tester.pumpAndSettle();
      expect(
        harness.approvalDecisions.single.decision.networkAction,
        ApprovalNetworkAction.deny,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
