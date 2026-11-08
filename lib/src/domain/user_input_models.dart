import 'dart:collection';

sealed class UserInputEvent {
  const UserInputEvent();
}

final class UserInputRequestedEvent extends UserInputEvent {
  const UserInputRequestedEvent({required this.request});

  final UserInputRequest request;
}

final class UserInputResolvedEvent extends UserInputEvent {
  const UserInputResolvedEvent({required this.requestId});

  final Object requestId;
}

final class UserInputOption {
  const UserInputOption({required this.label, required this.description});

  final String label;
  final String description;
}

final class UserInputQuestion {
  UserInputQuestion({
    required this.id,
    required this.header,
    required this.question,
    required List<UserInputOption> options,
    required this.allowsOther,
    required this.isSecret,
  }) : options = List.unmodifiable(options);

  final String id;
  final String header;
  final String question;
  final List<UserInputOption> options;
  final bool allowsOther;
  final bool isSecret;
}

final class UserInputRequest {
  UserInputRequest({
    required this.requestId,
    required this.threadId,
    required this.turnId,
    required this.itemId,
    required this.isBlocking,
    required List<UserInputQuestion> questions,
  }) : questions = List.unmodifiable(questions);

  final Object requestId;
  final String threadId;
  final String turnId;
  final String itemId;
  final bool isBlocking;
  final List<UserInputQuestion> questions;
}

final class UserInputAnswers {
  UserInputAnswers(Map<String, List<String>> answers)
    : values = UnmodifiableMapView(
        answers.map(
          (questionId, values) =>
              MapEntry(questionId, List<String>.unmodifiable(values)),
        ),
      );

  final Map<String, List<String>> values;
}
