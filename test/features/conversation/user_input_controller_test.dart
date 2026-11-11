import 'dart:async';

import 'package:codex_native_unofficial/src/domain/ecosystem_gateway.dart';
import 'package:codex_native_unofficial/src/domain/ecosystem_models.dart';
import 'package:codex_native_unofficial/src/domain/user_input_gateway.dart';
import 'package:codex_native_unofficial/src/domain/user_input_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/user_input_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeUserInputGateway gateway;
  late UserInputController controller;

  setUp(() {
    gateway = _FakeUserInputGateway();
    controller = UserInputController(gateway: gateway, mcpGateway: gateway);
  });

  tearDown(() async {
    controller.dispose();
    await gateway.dispose();
  });

  test('tracks a typed request and submits immutable answers', () async {
    gateway.events.add(UserInputRequestedEvent(request: _request('input-1')));

    expect(controller.pending, hasLength(1));
    await controller.submit('input-1', {
      'approach': ['Incremental'],
    });

    expect(controller.pending, isEmpty);
    expect(gateway.submissions, hasLength(1));
    expect(gateway.submissions.single.$1, 'input-1');
    expect(gateway.submissions.single.$2.values, {
      'approach': ['Incremental'],
    });
  });

  test('external resolution removes a pending request', () {
    gateway.events.add(UserInputRequestedEvent(request: _request('input-1')));
    gateway.events.add(const UserInputResolvedEvent(requestId: 'input-1'));

    expect(controller.pending, isEmpty);
  });

  test('failed cancellation keeps the request actionable', () async {
    gateway.cancelError = StateError('app-server write failed');
    gateway.events.add(UserInputRequestedEvent(request: _request('input-1')));

    await controller.cancel('input-1');

    expect(controller.pending, hasLength(1));
    expect(controller.errorMessage, contains('app-server write failed'));

    gateway.events.add(const UserInputResolvedEvent(requestId: 'input-1'));
    expect(controller.pending, isEmpty);
    expect(controller.errorMessage, isNull);
  });

  test('late submit completion keeps the next request submitting', () async {
    final first = Completer<void>();
    final second = Completer<void>();
    gateway.responses.addAll({'input-1': first, 'input-2': second});
    gateway.events.add(UserInputRequestedEvent(request: _request('input-1')));
    gateway.events.add(UserInputRequestedEvent(request: _request('input-2')));
    final firstSubmit = controller.submit('input-1', const {});
    gateway.events.add(const UserInputResolvedEvent(requestId: 'input-1'));
    final secondSubmit = controller.submit('input-2', const {});
    expect(controller.isSubmitting('input-2'), isTrue);

    first.complete();
    await firstSubmit;
    expect(controller.isSubmitting('input-2'), isTrue);
    await controller.submit('input-2', const {});
    expect(gateway.submissions, hasLength(2));

    second.complete();
    await secondSubmit;
    expect(controller.submittingRequestId, isNull);
    expect(controller.pending, isEmpty);
  });

  test(
    'late cancellation failure preserves the current request error',
    () async {
      final first = Completer<void>();
      final second = Completer<void>();
      gateway.responses.addAll({'input-1': first, 'input-2': second});
      gateway.events.add(UserInputRequestedEvent(request: _request('input-1')));
      gateway.events.add(UserInputRequestedEvent(request: _request('input-2')));
      final firstCancel = controller.cancel('input-1');
      gateway.events.add(const UserInputResolvedEvent(requestId: 'input-1'));
      final secondSubmit = controller.submit('input-2', const {});
      second.completeError(StateError('current request failed'));
      await secondSubmit;
      expect(controller.errorMessage, contains('current request failed'));

      first.completeError(StateError('resolved request failed late'));
      await firstCancel;
      expect(controller.errorMessage, contains('current request failed'));
      expect(controller.pending.single.requestId, 'input-2');
    },
  );

  test('late completion cannot remove a reused request identifier', () async {
    final first = Completer<void>();
    gateway.responses['input-1'] = first;
    gateway.events.add(UserInputRequestedEvent(request: _request('input-1')));
    final firstSubmit = controller.submit('input-1', const {});
    gateway.events.add(const UserInputResolvedEvent(requestId: 'input-1'));

    final second = Completer<void>();
    final replacement = _request('input-1');
    gateway.responses['input-1'] = second;
    gateway.events.add(UserInputRequestedEvent(request: replacement));
    final secondSubmit = controller.submit('input-1', const {});
    first.complete();
    await firstSubmit;
    expect(controller.pending.single, same(replacement));
    expect(controller.isSubmitting('input-1'), isTrue);

    second.complete();
    await secondSubmit;
    expect(controller.pending, isEmpty);
    expect(controller.submittingRequestId, isNull);
  });

  test(
    'late elicitation completion keeps the next question submitting',
    () async {
      final first = Completer<void>();
      final second = Completer<void>();
      gateway.responses.addAll({'elicitation-1': first, 'input-1': second});
      gateway.elicitations.add(
        McpElicitationRequestedEvent(
          request: McpElicitationRequest(
            requestId: 'elicitation-1',
            serverName: 'fixture',
            threadId: 'thread-1',
            message: 'Provide fixture input',
            mode: McpElicitationMode.form,
          ),
        ),
      );
      gateway.events.add(UserInputRequestedEvent(request: _request('input-1')));
      final elicitation = controller.respondToElicitation(
        'elicitation-1',
        McpElicitationAction.decline,
      );
      gateway.elicitations.add(
        const McpElicitationResolvedEvent(requestId: 'elicitation-1'),
      );
      final submit = controller.submit('input-1', const {});
      first.complete();
      await elicitation;
      expect(controller.isSubmitting('input-1'), isTrue);

      second.complete();
      await submit;
      expect(controller.pendingElicitations, isEmpty);
      expect(controller.pending, isEmpty);
    },
  );
  test(
    'disposal invalidates pending writes and rejects further actions',
    () async {
      final disposedController = UserInputController(gateway: gateway);
      final response = Completer<void>();
      gateway.responses['input-1'] = response;
      gateway.events.add(UserInputRequestedEvent(request: _request('input-1')));
      final submit = disposedController.submit('input-1', const {});
      disposedController.dispose();

      await disposedController.submit('input-1', const {});
      await disposedController.cancel('input-1');
      response.completeError(StateError('disposed write failed late'));
      await submit;

      expect(gateway.submissions, hasLength(1));
      expect(gateway.cancellations, isEmpty);
      expect(disposedController.submittingRequestId, isNull);
      expect(disposedController.errorMessage, isNull);
    },
  );
  test('unrelated resolution cannot retire another request kind', () async {
    final elicitationGate = Completer<void>();
    gateway.responses[1] = elicitationGate;
    gateway.elicitations.add(
      McpElicitationRequestedEvent(
        request: McpElicitationRequest(
          requestId: 1,
          serverName: 'fixture',
          threadId: 'thread-1',
          message: 'Provide fixture input',
          mode: McpElicitationMode.form,
        ),
      ),
    );
    final elicitation = controller.respondToElicitation(
      1,
      McpElicitationAction.decline,
    );
    gateway.events.add(const UserInputResolvedEvent(requestId: 1));
    expect(controller.isSubmitting(1), isTrue);
    gateway.elicitations.add(const McpElicitationResolvedEvent(requestId: 1));
    elicitationGate.complete();
    await elicitation;

    final inputGate = Completer<void>();
    gateway.responses[1] = inputGate;
    gateway.events.add(UserInputRequestedEvent(request: _request(1)));
    final submit = controller.submit(1, const {});
    gateway.elicitations.add(const McpElicitationResolvedEvent(requestId: 1));
    expect(controller.isSubmitting(1), isTrue);
    gateway.events.add(const UserInputResolvedEvent(requestId: 1));
    inputGate.complete();
    await submit;
    expect(controller.submittingRequestId, isNull);
  });

  test(
    'projection eviction preserves the write until typed resolution',
    () async {
      final bounded = UserInputController(gateway: gateway, maxPending: 1);
      addTearDown(bounded.dispose);
      final first = Completer<void>();
      final second = Completer<void>();
      gateway.responses.addAll({0: first, 1: second});
      gateway.events.add(UserInputRequestedEvent(request: _request(0)));
      final firstSubmit = bounded.submit(0, const {});
      gateway.events.add(UserInputRequestedEvent(request: _request(1)));
      expect(bounded.pending.single.requestId, 1);
      expect(bounded.isSubmitting(0), isTrue);
      await bounded.submit(1, const {});
      expect(gateway.submissions, hasLength(1));

      gateway.events.add(const UserInputResolvedEvent(requestId: 0));
      expect(bounded.submittingRequestId, isNull);
      final secondSubmit = bounded.submit(1, const {});
      first.complete();
      await firstSubmit;
      expect(bounded.isSubmitting(1), isTrue);
      second.complete();
      await secondSubmit;
      expect(bounded.pending, isEmpty);
    },
  );
}

UserInputRequest _request(Object requestId) => UserInputRequest(
  requestId: requestId,
  threadId: 'thread-1',
  turnId: 'turn-1',
  itemId: 'item-1',
  isBlocking: true,
  questions: [
    UserInputQuestion(
      id: 'approach',
      header: 'Approach',
      question: 'Which implementation should be used?',
      options: const [
        UserInputOption(
          label: 'Incremental',
          description: 'Make the smallest compatible change.',
        ),
      ],
      allowsOther: false,
      isSecret: false,
    ),
  ],
);

final class _FakeUserInputGateway extends Fake
    implements UserInputGateway, McpCapabilityGateway {
  final StreamController<UserInputEvent> events =
      StreamController<UserInputEvent>.broadcast(sync: true);
  final List<(Object, UserInputAnswers)> submissions = [];
  final List<Object> cancellations = [];
  final responses = <Object, Completer<void>>{};
  final elicitations = StreamController<McpElicitationEvent>.broadcast(
    sync: true,
  );
  Object? cancelError;

  @override
  Stream<UserInputEvent> get userInputEvents => events.stream;

  @override
  bool get supportsMcpCapabilities => true;

  @override
  Stream<McpElicitationEvent> get mcpElicitationEvents => elicitations.stream;

  @override
  Future<void> submitUserInput({
    required Object requestId,
    required UserInputAnswers answers,
  }) async {
    submissions.add((requestId, answers));
    await responses[requestId]?.future;
  }

  @override
  Future<void> cancelUserInput(Object requestId) async {
    cancellations.add(requestId);
    await responses[requestId]?.future;
    if (cancelError case final error?) {
      throw error;
    }
  }

  @override
  Future<void> respondToMcpElicitation({
    required Object requestId,
    required McpElicitationAction action,
    Map<String, Object?> content = const {},
  }) async {
    await responses[requestId]?.future;
  }

  Future<void> dispose() async {
    await events.close();
    await elicitations.close();
  }
}
