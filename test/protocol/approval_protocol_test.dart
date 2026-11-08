import 'dart:async';

import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/user_input_models.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/server_request_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<CodexServerRequest> requests;
  late StreamController<CodexNotification> notifications;
  late List<(Object, JsonObject)> responses;
  late List<(Object, int, String)> errors;
  late ServerRequestProtocolAdapter adapter;

  setUp(() {
    requests = StreamController<CodexServerRequest>.broadcast(sync: true);
    notifications = StreamController<CodexNotification>.broadcast(sync: true);
    responses = [];
    errors = [];
    adapter = ServerRequestProtocolAdapter(
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
    final eventFuture = adapter.approvalEvents.first;
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

    await adapter.decideApproval(
      requestId: 7,
      decision: ApprovalDecision.approveOnce,
    );
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

    await adapter.decideApproval(
      requestId: 'file-request',
      decision: ApprovalDecision.reject,
    );
    expect(responses.single.$2, {'decision': 'decline'});
  });

  test('fails closed for permission approvals', () async {
    final eventFuture = adapter.approvalEvents.first;
    requests.add(
      const CodexServerRequest(
        id: 99,
        method: 'item/permissions/requestApproval',
        params: {'threadId': 'thread-1'},
      ),
    );
    final event = await eventFuture as ApprovalRequestedEvent;
    expect(event.request.kind, ApprovalKind.permissions);
    expect(event.request.approveSupported, isFalse);

    await expectLater(
      adapter.decideApproval(
        requestId: 99,
        decision: ApprovalDecision.approveOnce,
      ),
      throwsA(isA<UnsupportedError>()),
    );
    await adapter.decideApproval(
      requestId: 99,
      decision: ApprovalDecision.reject,
    );

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
      adapter.decideApproval(
        requestId: 11,
        decision: ApprovalDecision.approveOnce,
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(responses, isEmpty);
  });

  test('removes requests resolved by another client', () async {
    final events = <ApprovalEvent>[];
    final subscription = adapter.approvalEvents.listen(events.add);
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

  test('answers currentTime/read without creating interactive state', () async {
    await adapter.dispose();
    adapter = ServerRequestProtocolAdapter(
      serverRequests: requests.stream,
      notifications: notifications.stream,
      respond: (id, result) async => responses.add((id, result)),
      respondError: (id, code, message) async =>
          errors.add((id, code, message)),
      clock: () => DateTime.fromMillisecondsSinceEpoch(1760000000123),
    );

    requests.add(
      const CodexServerRequest(
        id: 'clock',
        method: 'currentTime/read',
        params: {},
      ),
    );
    await pumpEventQueue();

    expect(responses.single.$1, 'clock');
    expect(responses.single.$2, {'currentTimeAt': 1760000000});
    expect(errors, isEmpty);
  });

  test('projects bounded tool user input and writes schema response', () async {
    final eventFuture = adapter.userInputEvents.first;
    requests.add(
      const CodexServerRequest(
        id: 'input-1',
        method: 'item/tool/requestUserInput',
        params: {
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'itemId': 'item-1',
          'isBlocking': true,
          'questions': [
            {
              'id': 'approach',
              'header': 'Approach',
              'question': 'Which implementation should be used?',
              'isOther': true,
              'options': [
                {
                  'label': 'Incremental',
                  'description': 'Make the smallest compatible change.',
                },
                {
                  'label': 'Refactor',
                  'description': 'Reshape the boundary first.',
                },
              ],
            },
            {
              'id': 'note',
              'header': 'Note',
              'question': 'Add a short note.',
              'isSecret': true,
            },
          ],
        },
      ),
    );

    final event = await eventFuture as UserInputRequestedEvent;
    expect(event.request.isBlocking, isTrue);
    expect(event.request.questions, hasLength(2));
    expect(event.request.questions.first.options, hasLength(2));
    expect(event.request.questions.first.allowsOther, isTrue);
    expect(event.request.questions.last.isSecret, isTrue);

    await adapter.submitUserInput(
      requestId: 'input-1',
      answers: UserInputAnswers({
        'approach': ['Incremental'],
        'note': ['Keep the protocol bounded.'],
      }),
    );

    expect(responses.single.$1, 'input-1');
    expect(responses.single.$2, {
      'answers': {
        'approach': {
          'answers': ['Incremental'],
        },
        'note': {
          'answers': ['Keep the protocol bounded.'],
        },
      },
    });
  });

  test(
    'rejects malformed and unsupported non-approval requests immediately',
    () async {
      requests.add(
        const CodexServerRequest(
          id: 'invalid-input',
          method: 'item/tool/requestUserInput',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'itemId': 'item-1',
            'isBlocking': true,
            'questions': [],
          },
        ),
      );
      requests.add(
        const CodexServerRequest(
          id: 'dynamic-tool',
          method: 'item/tool/call',
          params: {},
        ),
      );
      await pumpEventQueue();

      expect(errors, hasLength(2));
      expect(errors.first.$1, 'invalid-input');
      expect(errors.first.$2, -32602);
      expect(errors.last.$1, 'dynamic-tool');
      expect(errors.last.$2, -32000);
    },
  );

  test('validates user input answers before writing a response', () async {
    final eventFuture = adapter.userInputEvents.first;
    requests.add(
      const CodexServerRequest(
        id: 'input-2',
        method: 'item/tool/requestUserInput',
        params: {
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'itemId': 'item-1',
          'isBlocking': true,
          'questions': [
            {
              'id': 'choice',
              'header': 'Choice',
              'question': 'Choose one.',
              'options': [
                {'label': 'A', 'description': 'First'},
                {'label': 'B', 'description': 'Second'},
              ],
            },
          ],
        },
      ),
    );
    await eventFuture;

    await expectLater(
      adapter.submitUserInput(
        requestId: 'input-2',
        answers: UserInputAnswers({
          'choice': ['C'],
        }),
      ),
      throwsArgumentError,
    );
    expect(responses, isEmpty);

    await adapter.cancelUserInput('input-2');
    expect(errors.single.$1, 'input-2');
    expect(errors.single.$2, -32000);
  });

  test(
    'shares one bounded pending budget across interactive request types',
    () async {
      await adapter.dispose();
      adapter = ServerRequestProtocolAdapter(
        serverRequests: requests.stream,
        notifications: notifications.stream,
        respond: (id, result) async => responses.add((id, result)),
        respondError: (id, code, message) async =>
            errors.add((id, code, message)),
        maxPendingRequests: 1,
      );

      requests.add(
        const CodexServerRequest(
          id: 'approval-1',
          method: 'item/fileChange/requestApproval',
          params: {'threadId': 'thread-1'},
        ),
      );
      requests.add(
        const CodexServerRequest(
          id: 'input-over-limit',
          method: 'item/tool/requestUserInput',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'itemId': 'item-1',
            'isBlocking': true,
            'questions': [
              {'id': 'choice', 'header': 'Choice', 'question': 'Choose one.'},
            ],
          },
        ),
      );
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(errors.single.$1, 'input-over-limit');
      expect(errors.single.$2, -32000);
      expect(errors.single.$3, contains('Too many pending'));
    },
  );
}
