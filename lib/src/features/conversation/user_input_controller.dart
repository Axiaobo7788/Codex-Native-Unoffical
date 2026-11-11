import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/ecosystem_gateway.dart';
import '../../domain/ecosystem_models.dart';
import '../../domain/user_input_gateway.dart';
import '../../domain/user_input_models.dart';

final class UserInputController extends ChangeNotifier {
  UserInputController({
    required this.gateway,
    this.mcpGateway,
    this.maxPending = 32,
  }) : assert(maxPending > 0) {
    _subscription = gateway.userInputEvents.listen(
      _handleEvent,
      onError: _handleStreamError,
    );
    final mcp = mcpGateway;
    if (mcp != null && mcp.supportsMcpCapabilities) {
      _mcpSubscription = mcp.mcpElicitationEvents.listen(
        _handleMcpEvent,
        onError: _handleMcpStreamError,
      );
    }
  }

  final UserInputGateway gateway;
  final McpCapabilityGateway? mcpGateway;
  final int maxPending;
  final List<UserInputRequest> _pending = [];
  final List<McpElicitationRequest> _pendingElicitations = [];
  late final StreamSubscription<UserInputEvent> _subscription;
  StreamSubscription<McpElicitationEvent>? _mcpSubscription;
  // Resolution can retire a write before its gateway Future completes.
  ({Object requestId, Object request, Object token})? _submission;
  String? _errorMessage;
  var _disposed = false;

  List<UserInputRequest> get pending => List.unmodifiable(_pending);
  List<McpElicitationRequest> get pendingElicitations =>
      List.unmodifiable(_pendingElicitations);
  Object? get submittingRequestId => _submission?.requestId;
  String? get errorMessage => _errorMessage;
  bool isSubmitting(Object requestId) => submittingRequestId == requestId;

  Future<void> submit(
    Object requestId,
    Map<String, List<String>> answers,
  ) async {
    final request = _pending
        .where((request) => request.requestId == requestId)
        .firstOrNull;
    if (_disposed || _submission != null || request == null) {
      return;
    }
    final token = Object();
    _submission = (requestId: requestId, request: request, token: token);
    _errorMessage = null;
    _notify();
    try {
      await gateway.submitUserInput(
        requestId: requestId,
        answers: UserInputAnswers(answers),
      );
      _pending.remove(request);
    } catch (error) {
      if (identical(_submission?.token, token)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (identical(_submission?.token, token)) {
        _submission = null;
        _notify();
      }
    }
  }

  Future<void> cancel(Object requestId) async {
    final request = _pending
        .where((request) => request.requestId == requestId)
        .firstOrNull;
    if (_disposed || _submission != null || request == null) {
      return;
    }
    final token = Object();
    _submission = (requestId: requestId, request: request, token: token);
    _errorMessage = null;
    _notify();
    try {
      await gateway.cancelUserInput(requestId);
      _pending.remove(request);
    } catch (error) {
      if (identical(_submission?.token, token)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (identical(_submission?.token, token)) {
        _submission = null;
        _notify();
      }
    }
  }

  Future<void> respondToElicitation(
    Object requestId,
    McpElicitationAction action, {
    Map<String, Object?> content = const {},
  }) async {
    final mcp = mcpGateway;
    final request = _pendingElicitations
        .where((request) => request.requestId == requestId)
        .firstOrNull;
    if (_disposed || mcp == null || _submission != null || request == null) {
      return;
    }
    final token = Object();
    _submission = (requestId: requestId, request: request, token: token);
    _errorMessage = null;
    _notify();
    try {
      await mcp.respondToMcpElicitation(
        requestId: requestId,
        action: action,
        content: content,
      );
      _pendingElicitations.removeWhere(
        (pending) => identical(pending, request),
      );
    } catch (error) {
      if (identical(_submission?.token, token)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (identical(_submission?.token, token)) {
        _submission = null;
        _notify();
      }
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
        if (_submission?.request is UserInputRequest &&
            submittingRequestId == event.requestId) {
          _submission = null;
        }
    }
    _notify();
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    _errorMessage = 'User input protocol error: $error';
    _notify();
  }

  void _handleMcpEvent(McpElicitationEvent event) {
    switch (event) {
      case McpElicitationRequestedEvent():
        _errorMessage = null;
        _pendingElicitations.removeWhere(
          (request) => request.requestId == event.request.requestId,
        );
        _pendingElicitations.add(event.request);
        if (_pendingElicitations.length > maxPending) {
          _pendingElicitations.removeRange(
            0,
            _pendingElicitations.length - maxPending,
          );
        }
      case McpElicitationResolvedEvent():
        final hadRequest = _pendingElicitations.any(
          (request) => request.requestId == event.requestId,
        );
        _pendingElicitations.removeWhere(
          (request) => request.requestId == event.requestId,
        );
        if (hadRequest) {
          _errorMessage = null;
        }
        if (_submission?.request is McpElicitationRequest &&
            submittingRequestId == event.requestId) {
          _submission = null;
        }
    }
    _notify();
  }

  void _handleMcpStreamError(Object error, StackTrace stackTrace) {
    _errorMessage = 'MCP elicitation protocol error: $error';
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
    _submission = null;
    unawaited(_subscription.cancel());
    final mcpSubscription = _mcpSubscription;
    if (mcpSubscription != null) {
      unawaited(mcpSubscription.cancel());
    }
    super.dispose();
  }
}
