import 'dart:async';

import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/ecosystem_models.dart';
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

  test('parses and accepts a typed MCP form elicitation', () async {
    final eventFuture = adapter.mcpElicitationEvents.first;
    requests.add(
      const CodexServerRequest(
        id: 'mcp-form-1',
        method: 'mcpServer/elicitation/request',
        params: {
          'serverName': 'filesystem',
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'mode': 'form',
          'message': 'Choose how to write the file.',
          'requestedSchema': {
            'type': 'object',
            'required': ['path', 'mode'],
            'properties': {
              'path': {
                'type': 'string',
                'title': 'Path',
                'minLength': 1,
                'maxLength': 120,
              },
              'mode': {
                'type': 'string',
                'title': 'Write mode',
                'oneOf': [
                  {'const': 'replace', 'title': 'Replace'},
                  {'const': 'append', 'title': 'Append'},
                ],
              },
              'retries': {
                'type': 'integer',
                'minimum': 0,
                'maximum': 3,
                'default': 1,
              },
              'confirm': {'type': 'boolean', 'default': true},
              'labels': {
                'type': 'array',
                'items': {
                  'type': 'string',
                  'enum': ['docs', 'test'],
                },
                'maxItems': 2,
              },
            },
          },
        },
      ),
    );

    final event = await eventFuture as McpElicitationRequestedEvent;
    expect(event.request.serverName, 'filesystem');
    expect(event.request.mode, McpElicitationMode.form);
    expect(event.request.fields, hasLength(5));
    expect(event.request.fields[1].kind, McpElicitationFieldKind.singleSelect);
    expect(event.request.fields.last.kind, McpElicitationFieldKind.multiSelect);

    await adapter.respondToMcpElicitation(
      requestId: 'mcp-form-1',
      action: McpElicitationAction.accept,
      content: const {
        'path': 'README.md',
        'mode': 'replace',
        'retries': 1,
        'confirm': true,
        'labels': ['docs'],
      },
    );
    expect(responses.single.$2, {
      'action': 'accept',
      'content': {
        'path': 'README.md',
        'mode': 'replace',
        'retries': 1,
        'confirm': true,
        'labels': ['docs'],
      },
    });
  });

  test('handles URL and hosted-form elicitation actions safely', () async {
    final urlEvent = adapter.mcpElicitationEvents.first;
    requests.add(
      const CodexServerRequest(
        id: 'mcp-url-1',
        method: 'mcpServer/elicitation/request',
        params: {
          'serverName': 'github',
          'threadId': 'thread-1',
          'mode': 'url',
          'message': 'Authorize GitHub.',
          'elicitationId': 'auth-1',
          'url': 'https://example.com/oauth',
        },
      ),
    );
    final parsedUrl = await urlEvent as McpElicitationRequestedEvent;
    expect(parsedUrl.request.url, Uri.parse('https://example.com/oauth'));
    await adapter.respondToMcpElicitation(
      requestId: 'mcp-url-1',
      action: McpElicitationAction.accept,
    );
    expect(responses.single.$2, {'action': 'accept'});

    final formEvent = adapter.mcpElicitationEvents.first;
    requests.add(
      const CodexServerRequest(
        id: 'mcp-hosted-form-1',
        method: 'mcpServer/elicitation/request',
        params: {
          'serverName': 'hosted',
          'threadId': 'thread-1',
          'mode': 'openai/form',
          'message': 'Complete the hosted form.',
          'requestedSchema': {'opaque': true},
        },
      ),
    );
    await formEvent;
    await expectLater(
      adapter.respondToMcpElicitation(
        requestId: 'mcp-hosted-form-1',
        action: McpElicitationAction.accept,
      ),
      throwsA(isA<UnsupportedError>()),
    );
    await adapter.respondToMcpElicitation(
      requestId: 'mcp-hosted-form-1',
      action: McpElicitationAction.decline,
    );
    expect(responses.last.$2, {'action': 'decline'});
  });

  test(
    'external resolution and adapter disposal clear MCP elicitations',
    () async {
      final events = <McpElicitationEvent>[];
      final subscription = adapter.mcpElicitationEvents.listen(events.add);
      addTearDown(subscription.cancel);
      requests.add(
        const CodexServerRequest(
          id: 'mcp-resolved',
          method: 'mcpServer/elicitation/request',
          params: {
            'serverName': 'filesystem',
            'threadId': 'thread-1',
            'mode': 'form',
            'message': 'Input needed.',
            'requestedSchema': {
              'type': 'object',
              'properties': {
                'value': {'type': 'string'},
              },
            },
          },
        ),
      );
      notifications.add(
        const CodexNotification(
          method: 'serverRequest/resolved',
          params: {'requestId': 'mcp-resolved'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<McpElicitationResolvedEvent>(), hasLength(1));

      requests.add(
        const CodexServerRequest(
          id: 'mcp-disconnect',
          method: 'mcpServer/elicitation/request',
          params: {
            'serverName': 'filesystem',
            'threadId': 'thread-1',
            'mode': 'form',
            'message': 'Input needed.',
            'requestedSchema': {
              'type': 'object',
              'properties': <String, Object?>{},
            },
          },
        ),
      );
      await adapter.dispose();
      expect(
        events.whereType<McpElicitationResolvedEvent>().last.requestId,
        'mcp-disconnect',
      );
    },
  );

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
        params: {'threadId': 'thread-1'},
      ),
    );
    await pumpEventQueue();

    expect(responses.single.$1, 'clock');
    expect(responses.single.$2, {'currentTimeAt': 1760000000});
    expect(errors, isEmpty);
  });

  test('rejects currentTime/read without its required thread ID', () async {
    requests.add(
      const CodexServerRequest(
        id: 'invalid-clock',
        method: 'currentTime/read',
        params: {},
      ),
    );
    await pumpEventQueue();

    expect(responses, isEmpty);
    expect(errors.single.$1, 'invalid-clock');
    expect(errors.single.$2, -32602);
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

  test('preserves secret whitespace and declared option labels', () async {
    final eventFuture = adapter.userInputEvents.first;
    requests.add(
      const CodexServerRequest(
        id: 'input-whitespace',
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
                {'label': ' A ', 'description': 'Whitespace is significant.'},
              ],
            },
            {
              'id': 'secret',
              'header': 'Secret',
              'question': 'Enter a secret.',
              'isSecret': true,
            },
          ],
        },
      ),
    );
    await eventFuture;

    await adapter.submitUserInput(
      requestId: 'input-whitespace',
      answers: UserInputAnswers({
        'choice': [' A '],
        'secret': ['  pass phrase  '],
      }),
    );

    expect(responses.single.$2, {
      'answers': {
        'choice': {
          'answers': [' A '],
        },
        'secret': {
          'answers': ['  pass phrase  '],
        },
      },
    });
  });

  test('coalesces an in-flight response with external resolution', () async {
    await adapter.dispose();
    final responseStarted = Completer<void>();
    final releaseResponse = Completer<void>();
    adapter = ServerRequestProtocolAdapter(
      serverRequests: requests.stream,
      notifications: notifications.stream,
      respond: (id, result) async {
        responses.add((id, result));
        responseStarted.complete();
        await releaseResponse.future;
      },
      respondError: (id, code, message) async =>
          errors.add((id, code, message)),
    );
    final events = <UserInputEvent>[];
    final subscription = adapter.userInputEvents.listen(events.add);
    addTearDown(subscription.cancel);
    requests.add(
      const CodexServerRequest(
        id: 'input-race',
        method: 'item/tool/requestUserInput',
        params: {
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'itemId': 'item-1',
          'isBlocking': true,
          'questions': [
            {'id': 'answer', 'header': 'Answer', 'question': 'Continue?'},
          ],
        },
      ),
    );
    await pumpEventQueue();

    final firstResponse = adapter.submitUserInput(
      requestId: 'input-race',
      answers: UserInputAnswers({
        'answer': ['yes'],
      }),
    );
    await responseStarted.future;
    await expectLater(
      adapter.submitUserInput(
        requestId: 'input-race',
        answers: UserInputAnswers({
          'answer': ['yes'],
        }),
      ),
      throwsStateError,
    );
    notifications.add(
      const CodexNotification(
        method: 'serverRequest/resolved',
        params: {'threadId': 'thread-1', 'requestId': 'input-race'},
      ),
    );
    await pumpEventQueue();
    releaseResponse.complete();
    await firstResponse;

    expect(responses, hasLength(1));
    expect(events.whereType<UserInputResolvedEvent>(), hasLength(1));
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
