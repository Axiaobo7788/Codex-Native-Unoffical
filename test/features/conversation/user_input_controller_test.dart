import 'dart:async';

import 'package:codex_native_unofficial/src/domain/user_input_gateway.dart';
import 'package:codex_native_unofficial/src/domain/user_input_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/user_input_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeUserInputGateway gateway;
  late UserInputController controller;

  setUp(() {
    gateway = _FakeUserInputGateway();
    controller = UserInputController(gateway: gateway);
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

final class _FakeUserInputGateway implements UserInputGateway {
  final StreamController<UserInputEvent> events =
      StreamController<UserInputEvent>.broadcast(sync: true);
  final List<(Object, UserInputAnswers)> submissions = [];
  final List<Object> cancellations = [];
  Object? cancelError;

  @override
  Stream<UserInputEvent> get userInputEvents => events.stream;

  @override
  Future<void> submitUserInput({
    required Object requestId,
    required UserInputAnswers answers,
  }) async {
    submissions.add((requestId, answers));
  }

  @override
  Future<void> cancelUserInput(Object requestId) async {
    cancellations.add(requestId);
    if (cancelError case final error?) {
      throw error;
    }
  }

  Future<void> dispose() => events.close();
}
