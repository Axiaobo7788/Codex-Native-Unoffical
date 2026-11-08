import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/user_input_gateway.dart';
import '../../domain/user_input_models.dart';

final class UserInputController extends ChangeNotifier {
  UserInputController({required this.gateway, this.maxPending = 32})
    : assert(maxPending > 0) {
    _subscription = gateway.userInputEvents.listen(
      _handleEvent,
      onError: _handleStreamError,
    );
  }

  final UserInputGateway gateway;
  final int maxPending;
  final List<UserInputRequest> _pending = [];
  late final StreamSubscription<UserInputEvent> _subscription;
  Object? _submittingRequestId;
  String? _errorMessage;
  var _disposed = false;

  List<UserInputRequest> get pending => List.unmodifiable(_pending);
  Object? get submittingRequestId => _submittingRequestId;
  String? get errorMessage => _errorMessage;
  bool isSubmitting(Object requestId) => _submittingRequestId == requestId;

  Future<void> submit(
    Object requestId,
    Map<String, List<String>> answers,
  ) async {
    if (_submittingRequestId != null ||
        !_pending.any((request) => request.requestId == requestId)) {
      return;
    }
    _submittingRequestId = requestId;
    _errorMessage = null;
    _notify();
    try {
      await gateway.submitUserInput(
        requestId: requestId,
        answers: UserInputAnswers(answers),
      );
      _pending.removeWhere((request) => request.requestId == requestId);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _submittingRequestId = null;
      _notify();
    }
  }

  Future<void> cancel(Object requestId) async {
    if (_submittingRequestId != null ||
        !_pending.any((request) => request.requestId == requestId)) {
      return;
    }
    _submittingRequestId = requestId;
    _errorMessage = null;
    _notify();
    try {
      await gateway.cancelUserInput(requestId);
      _pending.removeWhere((request) => request.requestId == requestId);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _submittingRequestId = null;
      _notify();
    }
  }

  void _handleEvent(UserInputEvent event) {
    switch (event) {
      case UserInputRequestedEvent():
        _errorMessage = null;
        _pending.removeWhere(
          (request) => request.requestId == event.request.requestId,
        );
        _pending.add(event.request);
        if (_pending.length > maxPending) {
          _pending.removeRange(0, _pending.length - maxPending);
        }
      case UserInputResolvedEvent():
        final hadRequest = _pending.any(
          (request) => request.requestId == event.requestId,
        );
        _pending.removeWhere((request) => request.requestId == event.requestId);
        if (hadRequest) {
          _errorMessage = null;
        }
        if (_submittingRequestId == event.requestId) {
          _submittingRequestId = null;
        }
    }
    _notify();
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    _errorMessage = 'User input protocol error: $error';
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
