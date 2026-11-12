import 'dart:async';

import 'package:codex_native_unofficial/src/domain/approval_gateway.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/features/approvals/approval_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an old choice callback cannot decide a reused request ID', () async {
    final gateway = _ChoicesGateway();
    final controller = ApprovalController(gateway: gateway);
    addTearDown(() async {
      controller.dispose();
      await gateway.events.close();
    });
    ApprovalRequest request(String name) => ApprovalRequest(
      requestId: 1,
      kind: ApprovalKind.command,
      threadId: 'thread',
      turnId: 'turn',
      itemId: name,
      summary: name,
      approveSupported: false,
      decisions: const [
        ApprovalDecision.approveForSession,
        ApprovalDecision.cancelTurn,
      ],
    );
    final retired = request('retired');
    gateway.events.add(ApprovalRequestedEvent(request: retired));
    controller.invalidateRuntime();
    final current = request('current');
    gateway.events.add(ApprovalRequestedEvent(request: current));
    await controller.choose(retired, ApprovalDecision.approveForSession);
    expect(gateway.decisions, isEmpty);
    expect(controller.pending.single, same(current));
    await controller.choose(current, ApprovalDecision.approveForSession);
    expect(gateway.decisions, [ApprovalDecision.approveForSession]);
    expect(controller.pending, isEmpty);
  });

  test(
    'unoffered reusable consent is rejected before reaching a gateway',
    () async {
      final gateway = _ChoicesGateway();
      final controller = ApprovalController(gateway: gateway);
      addTearDown(() async {
        controller.dispose();
        await gateway.events.close();
      });
      const request = ApprovalRequest(
        requestId: 1,
        kind: ApprovalKind.command,
        threadId: 'thread',
        turnId: 'turn',
        itemId: 'item',
        summary: 'One-time only',
        approveSupported: true,
      );
      gateway.events.add(const ApprovalRequestedEvent(request: request));
      await controller.choose(request, ApprovalDecision.approveForSession);
      expect(gateway.decisions, isEmpty);
      expect(controller.pending.single, same(request));
      expect(controller.errorMessage, contains('cannot be safely approved'));
      await controller.choose(request, ApprovalDecision.approveOnce);
      expect(gateway.decisions, [ApprovalDecision.approveOnce]);
      expect(controller.errorMessage, isNull);
    },
  );
}

class _ChoicesGateway implements ApprovalGateway {
  final events = StreamController<ApprovalEvent>.broadcast(sync: true);
  final decisions = <ApprovalDecision>[];
  @override
  Stream<ApprovalEvent> get approvalEvents => events.stream;
  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) async {
    decisions.add(decision);
  }
}
