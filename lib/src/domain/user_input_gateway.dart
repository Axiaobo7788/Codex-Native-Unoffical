import 'user_input_models.dart';

abstract interface class UserInputGateway {
  Stream<UserInputEvent> get userInputEvents;

  Future<void> submitUserInput({
    required Object requestId,
    required UserInputAnswers answers,
  });

  Future<void> cancelUserInput(Object requestId);
}
