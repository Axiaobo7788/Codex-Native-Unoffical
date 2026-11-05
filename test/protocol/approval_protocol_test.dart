import 'dart:async';

import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/protocol/approval_protocol.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<CodexServerRequest> requests;
  late StreamController<CodexNotification> notifications;
  late List<(Object, JsonObject)> responses;
  late List<(Object, int, String)> errors;
  late ApprovalProtocolAdapter adapter;

  setUp(() {
    requests = StreamController<CodexServerRequest>.broadcast(sync: true);
    notifications = StreamController<CodexNotification>.broadcast(sync: true);
    responses = [];
    errors = [];
    adapter = ApprovalProtocolAdapter(
      serverRequests: requests.stream,
      notifications: notifications.stream,
      respond: (id, result) async => responses.add((id, result)),
      respondError: (id, code, message) async =>
          errors.add((id, code, message)),
    );
  });

  tearDown(() async {
    await adapter.dispose();
    await requests.close();
    await notifications.close();
  });

  test('maps and approves a v2 command request once', () async {
    final eventFuture = adapter.events.first;
    requests.add(
      const CodexServerRequest(
        id: 7,
        method: 'item/commandExecution/requestApproval',
        params: {
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'itemId': 'command-1',
          'kind': 'command',
          'command': 'flutter test',
          'cwd': '/workspace',
          'reason': 'Run tests',
          'availableDecisions': ['accept', 'decline'],
        },
      ),
    );

    final event = await eventFuture as ApprovalRequestedEvent;
    expect(event.request.kind, ApprovalKind.command);
    expect(event.request.summary, 'Run: flutter test');
    expect(event.request.approveSupported, isTrue);

    await adapter.decide(requestId: 7, decision: ApprovalDecision.approveOnce);
    expect(responses.single.$1, 7);
    expect(responses.single.$2, {'decision': 'accept'});
  });

  test('rejects file changes with the v2 decline decision', () async {
    requests.add(
      const CodexServerRequest(
        id: 'file-request',
        method: 'item/fileChange/requestApproval',
        params: {
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'itemId': 'patch-1',
          'reason': 'Write files',
        },
      ),
    );

    await adapter.decide(
      requestId: 'file-request',
      decision: ApprovalDecision.reject,
    );
    expect(responses.single.$2, {'decision': 'decline'});
  });

  test('fails closed for unsupported server requests', () async {
    final eventFuture = adapter.events.first;
    requests.add(
      const CodexServerRequest(
        id: 99,
        method: 'item/tool/requestUserInput',
        params: {'threadId': 'thread-1'},
      ),
    );
    final event = await eventFuture as ApprovalRequestedEvent;
    expect(event.request.kind, ApprovalKind.unsupported);
    expect(event.request.approveSupported, isFalse);

    await expectLater(
      adapter.decide(requestId: 99, decision: ApprovalDecision.approveOnce),
      throwsA(isA<UnsupportedError>()),
    );
    await adapter.decide(requestId: 99, decision: ApprovalDecision.reject);

    expect(errors.single.$1, 99);
    expect(errors.single.$2, -32000);
  });

  test('honors command availableDecisions', () async {
    requests.add(
      const CodexServerRequest(
        id: 11,
        method: 'item/commandExecution/requestApproval',
        params: {
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'itemId': 'command-1',
          'kind': 'command',
          'availableDecisions': ['decline'],
        },
      ),
    );

    await expectLater(
      adapter.decide(requestId: 11, decision: ApprovalDecision.approveOnce),
      throwsA(isA<UnsupportedError>()),
    );
    expect(responses, isEmpty);
  });

  test('removes requests resolved by another client', () async {
    final events = <ApprovalEvent>[];
    final subscription = adapter.events.listen(events.add);
    addTearDown(subscription.cancel);
    requests.add(
      const CodexServerRequest(
        id: 'remote-resolution',
        method: 'item/fileChange/requestApproval',
        params: {'threadId': 'thread-1', 'turnId': 'turn-1', 'itemId': '1'},
      ),
    );
    notifications.add(
      const CodexNotification(
        method: 'serverRequest/resolved',
        params: {'threadId': 'thread-1', 'requestId': 'remote-resolution'},
      ),
    );
    await pumpEventQueue();

    expect(events, hasLength(2));
    expect(events.last, isA<ApprovalResolvedEvent>());
  });
}
