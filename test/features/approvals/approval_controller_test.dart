import 'dart:async';

import 'package:codex_native_unofficial/src/domain/approval_gateway.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/features/approvals/approval_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeApprovalGateway gateway;
  late ApprovalController controller;

  setUp(() {
    gateway = _FakeApprovalGateway();
    controller = ApprovalController(gateway: gateway);
  });

  tearDown(() async {
    controller.dispose();
    await gateway.dispose();
  });

  test('tracks and approves a pending request', () async {
    gateway.events.add(
      const ApprovalRequestedEvent(
        request: ApprovalRequest(
          requestId: 1,
          kind: ApprovalKind.command,
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'command-1',
          summary: 'Run: flutter test',
          approveSupported: true,
        ),
      ),
    );
    expect(controller.pending, hasLength(1));

    await controller.approve(1);

    expect(controller.pending, isEmpty);
    expect(gateway.decisions, [(1, ApprovalDecision.approveOnce)]);
  });

  test('exposes reject but refuses unsupported approval', () async {
    gateway.events.add(
      const ApprovalRequestedEvent(
        request: ApprovalRequest(
          requestId: 'unsupported',
          kind: ApprovalKind.unsupported,
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: null,
          summary: 'Unsupported request',
          approveSupported: false,
        ),
      ),
    );

    await controller.approve('unsupported');
    expect(controller.errorMessage, contains('cannot be safely approved'));
    expect(gateway.decisions, isEmpty);

    await controller.reject('unsupported');
    expect(gateway.decisions, [('unsupported', ApprovalDecision.reject)]);
  });
}

class _FakeApprovalGateway implements ApprovalGateway {
  final StreamController<ApprovalEvent> events =
      StreamController<ApprovalEvent>.broadcast(sync: true);
  final List<(Object, ApprovalDecision)> decisions = [];

  @override
  Stream<ApprovalEvent> get approvalEvents => events.stream;

  @override
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) async {
    decisions.add((requestId, decision));
  }

  Future<void> dispose() => events.close();
}
