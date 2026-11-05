import 'turn_models.dart';

abstract interface class TurnGateway {
  Stream<TurnEvent> get turnEvents;

  Future<TurnHandle> startTurn({
    required String threadId,
    required String text,
  });
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  });
}
