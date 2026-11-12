import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/approval_gateway.dart';
import '../../domain/approval_models.dart';

class ApprovalController extends ChangeNotifier {
  ApprovalController({required this.gateway, this.maxPending = 32})
    : assert(maxPending > 0) {
    _subscription = gateway.approvalEvents.listen(
      _handleEvent,
      onError: _handleStreamError,
    );
  }

  final ApprovalGateway gateway;
  final int maxPending;
  final List<ApprovalRequest> _pending = [];
  final Set<Object> _deciding = {};
  late final StreamSubscription<ApprovalEvent> _subscription;
  String? _errorMessage;
  var _disposed = false;
  var _runtimeGeneration = 0;

  List<ApprovalRequest> get pending => List.unmodifiable(_pending);
  String? get errorMessage => _errorMessage;
  bool isDeciding(Object requestId) => _deciding.contains(requestId);

  Future<void> approve(Object requestId) =>
      _decide(requestId, ApprovalDecision.approveOnce);

  Future<void> reject(Object requestId) =>
      _decide(requestId, ApprovalDecision.reject);

  /// Server request IDs belong to the retired connection, not the next Host.
  void invalidateRuntime() {
    _runtimeGeneration += 1;
    _pending.clear();
    _deciding.clear();
    _errorMessage = null;
    _notify();
  }

  Future<void> _decide(Object requestId, ApprovalDecision decision) async {
    final index = _pending.indexWhere(
      (request) => request.requestId == requestId,
    );
    if (_disposed || index == -1 || _deciding.contains(requestId)) {
      return;
    }
    final request = _pending[index];
    final generation = _runtimeGeneration;
    if (decision == ApprovalDecision.approveOnce && !request.approveSupported) {
      _errorMessage = 'This request cannot be safely approved by this client.';
      _notify();
      return;
    }

    _deciding.add(requestId);
    _errorMessage = null;
    _notify();
    try {
      await gateway.decideApproval(requestId: requestId, decision: decision);
      if (generation == _runtimeGeneration) _pending.remove(request);
    } catch (error) {
      if (generation == _runtimeGeneration) _errorMessage = error.toString();
    } finally {
      if (generation == _runtimeGeneration) {
        _deciding.remove(requestId);
        _notify();
      }
    }
  }

  void _handleEvent(ApprovalEvent event) {
    switch (event) {
      case ApprovalRequestedEvent():
        _pending.removeWhere(
          (request) => request.requestId == event.request.requestId,
        );
        _pending.add(event.request);
        if (_pending.length > maxPending) {
          _pending.removeRange(0, _pending.length - maxPending);
        }
      case ApprovalResolvedEvent():
        _pending.removeWhere((request) => request.requestId == event.requestId);
        _deciding.remove(event.requestId);
    }
    _notify();
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    _errorMessage = 'Approval protocol error: $error';
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
