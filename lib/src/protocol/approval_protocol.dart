import 'dart:async';
import 'dart:collection';

import '../domain/approval_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';

typedef ProtocolResponse = Future<void> Function(Object id, JsonObject result);
typedef ProtocolErrorResponse = Future<void> Function(
  Object id,
  int code,
  String message,
);

enum _ResponseStyle { commandV2, fileV2, execLegacy, patchLegacy, unsupported }

final class ApprovalProtocolAdapter {
  ApprovalProtocolAdapter({
    required Stream<CodexServerRequest> serverRequests,
    required Stream<CodexNotification> notifications,
    required this.respond,
    required this.respondError,
    this.maxPendingRequests = 32,
  }) : assert(maxPendingRequests > 0) {
    _requestSubscription = serverRequests.listen(_handleRequest);
    _notificationSubscription = notifications
        .where(
          (notification) => notification.method == 'serverRequest/resolved',
        )
        .listen(_handleResolvedNotification);
  }

  final ProtocolResponse respond;
  final ProtocolErrorResponse respondError;
  final int maxPendingRequests;
  final LinkedHashMap<Object, (_ResponseStyle, bool)> _pending =
      LinkedHashMap();
  final StreamController<ApprovalEvent> _events =
      StreamController<ApprovalEvent>.broadcast();
  late final StreamSubscription<CodexServerRequest> _requestSubscription;
  late final StreamSubscription<CodexNotification> _notificationSubscription;
  var _disposed = false;

  Stream<ApprovalEvent> get events => _events.stream;

  Future<void> decide({
    required Object requestId,
    required ApprovalDecision decision,
  }) async {
    final pending = _pending[requestId];
    if (pending == null) {
      throw StateError('Approval request is no longer pending.');
    }
    final (style, approveSupported) = pending;
    if (decision == ApprovalDecision.approveOnce && !approveSupported) {
      throw UnsupportedError(
        'This server request cannot be safely approved by this client.',
      );
    }

    switch (style) {
      case _ResponseStyle.commandV2:
      case _ResponseStyle.fileV2:
        await respond(requestId, {
          'decision': decision == ApprovalDecision.approveOnce
              ? 'accept'
              : 'decline',
        });
      case _ResponseStyle.execLegacy:
      case _ResponseStyle.patchLegacy:
        await respond(requestId, {
          'decision': decision == ApprovalDecision.approveOnce
              ? 'approved'
              : {
                  'denied': {'rejection': 'Rejected by the user'},
                },
        });
      case _ResponseStyle.unsupported:
        await respondError(
          requestId,
          -32000,
          'Request rejected: unsupported by this client.',
        );
    }

    _pending.remove(requestId);
    if (!_events.isClosed) {
      _events.add(ApprovalResolvedEvent(requestId: requestId));
    }
  }

  void _handleRequest(CodexServerRequest request) {
    if (_disposed) {
      return;
    }
    if (_pending.length >= maxPendingRequests) {
      unawaited(
        respondError(request.id, -32000, 'Too many pending client requests.'),
      );
      return;
    }

    final parsed = _parseRequest(request);
    _pending[request.id] = (parsed.$2, parsed.$1.approveSupported);
    _events.add(ApprovalRequestedEvent(request: parsed.$1));
  }

  (ApprovalRequest, _ResponseStyle) _parseRequest(CodexServerRequest request) {
    final params = request.params;
    return switch (request.method) {
      'item/commandExecution/requestApproval' => (
        ApprovalRequest(
          requestId: request.id,
          kind: ApprovalKind.command,
          threadId: _optionalString(params, 'threadId'),
          turnId: _optionalString(params, 'turnId'),
          itemId: _optionalString(params, 'itemId'),
          summary: _commandSummary(params['kind'], params['command']),
          detail: _optionalString(params, 'cwd'),
          reason: _optionalString(params, 'reason'),
          approveSupported: _supportsDecision(params, 'accept'),
        ),
        _ResponseStyle.commandV2,
      ),
      'item/fileChange/requestApproval' => (
        ApprovalRequest(
          requestId: request.id,
          kind: ApprovalKind.fileChange,
          threadId: _optionalString(params, 'threadId'),
          turnId: _optionalString(params, 'turnId'),
          itemId: _optionalString(params, 'itemId'),
          summary: 'Apply file changes',
          detail: _optionalString(params, 'grantRoot'),
          reason: _optionalString(params, 'reason'),
          approveSupported: true,
        ),
        _ResponseStyle.fileV2,
      ),
      'execCommandApproval' => (
        ApprovalRequest(
          requestId: request.id,
          kind: ApprovalKind.command,
          threadId: _optionalString(params, 'conversationId'),
          turnId: null,
          itemId: _optionalString(params, 'callId'),
          summary: _legacyCommandSummary(params['command']),
          detail: _optionalString(params, 'cwd'),
          reason: _optionalString(params, 'reason'),
          approveSupported: true,
        ),
        _ResponseStyle.execLegacy,
      ),
      'applyPatchApproval' => (
        ApprovalRequest(
          requestId: request.id,
          kind: ApprovalKind.fileChange,
          threadId: _optionalString(params, 'conversationId'),
          turnId: null,
          itemId: _optionalString(params, 'callId'),
          summary: 'Apply file changes',
          detail: _optionalString(params, 'grantRoot'),
          reason: _optionalString(params, 'reason'),
          approveSupported: true,
        ),
        _ResponseStyle.patchLegacy,
      ),
      'item/permissions/requestApproval' => (
        ApprovalRequest(
          requestId: request.id,
          kind: ApprovalKind.permissions,
          threadId: _optionalString(params, 'threadId'),
          turnId: _optionalString(params, 'turnId'),
          itemId: _optionalString(params, 'itemId'),
          summary: 'Additional permissions requested',
          detail: _optionalString(params, 'cwd'),
          reason: _optionalString(params, 'reason'),
          approveSupported: false,
        ),
        _ResponseStyle.unsupported,
      ),
      _ => (
        ApprovalRequest(
          requestId: request.id,
          kind: ApprovalKind.unsupported,
          threadId: _optionalString(params, 'threadId'),
          turnId: _optionalString(params, 'turnId'),
          itemId: _optionalString(params, 'itemId'),
          summary: 'Unsupported server request: ${request.method}',
          approveSupported: false,
        ),
        _ResponseStyle.unsupported,
      ),
    };
  }

  void _handleResolvedNotification(CodexNotification notification) {
    final requestId = notification.params['requestId'];
    if (requestId == null || _pending.remove(requestId) == null) {
      return;
    }
    _events.add(ApprovalResolvedEvent(requestId: requestId));
  }

  static String _commandSummary(Object? kind, Object? command) {
    if (kind == 'writeStdin') {
      return 'Write to a running terminal';
    }
    return command is String && command.isNotEmpty
        ? 'Run: ${_truncate(command, 320)}'
        : 'Run a command';
  }

  static String _legacyCommandSummary(Object? command) {
    if (command is List<Object?>) {
      return 'Run: ${_truncate(command.whereType<String>().join(' '), 320)}';
    }
    return 'Run a command';
  }

  static bool _supportsDecision(JsonObject params, String decision) {
    final available = params['availableDecisions'];
    return available == null ||
        (available is List<Object?> && available.contains(decision));
  }

  static String? _optionalString(JsonObject object, String key) {
    final value = object[key];
    return value is String ? value : null;
  }

  static String _truncate(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit)}…';

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _requestSubscription.cancel();
    await _notificationSubscription.cancel();
    _pending.clear();
    await _events.close();
  }
}
