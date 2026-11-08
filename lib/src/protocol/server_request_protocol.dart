import 'dart:async';
import 'dart:collection';

import '../domain/approval_models.dart';
import '../domain/user_input_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';

typedef ProtocolResponse = Future<void> Function(Object id, JsonObject result);
typedef ProtocolErrorResponse = Future<void> Function(
  Object id,
  int code,
  String message,
);
typedef ProtocolClock = DateTime Function();

enum _ApprovalResponseStyle {
  commandV2,
  fileV2,
  execLegacy,
  patchLegacy,
  unsupported,
}

final class _PendingApproval {
  const _PendingApproval(this.style, this.approveSupported);

  final _ApprovalResponseStyle style;
  final bool approveSupported;
}

/// Owns the single dispatch point for every app-server initiated request.
///
/// Interactive requests are projected into bounded domain streams. Requests
/// that this client cannot safely fulfill are rejected immediately so the
/// app-server cannot wait forever on a card the UI does not understand.
final class ServerRequestProtocolAdapter {
  ServerRequestProtocolAdapter({
    required Stream<CodexServerRequest> serverRequests,
    required Stream<CodexNotification> notifications,
    required this.respond,
    required this.respondError,
    ProtocolClock? clock,
    this.maxPendingRequests = 32,
    this.maxQuestionsPerRequest = 3,
    this.maxOptionsPerQuestion = 20,
  }) : assert(maxPendingRequests > 0),
       assert(maxQuestionsPerRequest > 0),
       assert(maxOptionsPerQuestion > 0),
       _clock = clock ?? DateTime.now {
    _requestSubscription = serverRequests.listen(_handleRequest);
    _notificationSubscription = notifications
        .where(
          (notification) => notification.method == 'serverRequest/resolved',
        )
        .listen(_handleResolvedNotification);
  }

  static const _unsupportedErrorCode = -32000;
  static const _invalidParamsErrorCode = -32602;
  static const _maximumIdentifierLength = 256;
  static const _maximumHeaderLength = 120;
  static const _maximumQuestionLength = 2000;
  static const _maximumOptionLabelLength = 240;
  static const _maximumOptionDescriptionLength = 2000;
  static const _maximumAnswerLength = 4096;

  final ProtocolResponse respond;
  final ProtocolErrorResponse respondError;
  final int maxPendingRequests;
  final int maxQuestionsPerRequest;
  final int maxOptionsPerQuestion;
  final ProtocolClock _clock;
  final LinkedHashMap<Object, _PendingApproval> _pendingApprovals =
      LinkedHashMap();
  final LinkedHashMap<Object, UserInputRequest> _pendingUserInputs =
      LinkedHashMap();
  final StreamController<ApprovalEvent> _approvalEvents =
      StreamController<ApprovalEvent>.broadcast();
  final StreamController<UserInputEvent> _userInputEvents =
      StreamController<UserInputEvent>.broadcast();
  late final StreamSubscription<CodexServerRequest> _requestSubscription;
  late final StreamSubscription<CodexNotification> _notificationSubscription;
  var _disposed = false;

  Stream<ApprovalEvent> get approvalEvents => _approvalEvents.stream;
  Stream<UserInputEvent> get userInputEvents => _userInputEvents.stream;

  int get _pendingCount => _pendingApprovals.length + _pendingUserInputs.length;

  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  }) async {
    final pending = _pendingApprovals[requestId];
    if (pending == null) {
      throw StateError('Approval request is no longer pending.');
    }
    if (decision == ApprovalDecision.approveOnce && !pending.approveSupported) {
      throw UnsupportedError(
        'This server request cannot be safely approved by this client.',
      );
    }

    switch (pending.style) {
      case _ApprovalResponseStyle.commandV2:
      case _ApprovalResponseStyle.fileV2:
        await respond(requestId, {
          'decision': decision == ApprovalDecision.approveOnce
              ? 'accept'
              : 'decline',
        });
      case _ApprovalResponseStyle.execLegacy:
      case _ApprovalResponseStyle.patchLegacy:
        await respond(requestId, {
          'decision': decision == ApprovalDecision.approveOnce
              ? 'approved'
              : {
                  'denied': {'rejection': 'Rejected by the user'},
                },
        });
      case _ApprovalResponseStyle.unsupported:
        await respondError(
          requestId,
          _unsupportedErrorCode,
          'Request rejected: unsupported by this client.',
        );
    }

    _pendingApprovals.remove(requestId);
    _emitApproval(ApprovalResolvedEvent(requestId: requestId));
  }

  Future<void> submitUserInput({
    required Object requestId,
    required UserInputAnswers answers,
  }) async {
    final request = _pendingUserInputs[requestId];
    if (request == null) {
      throw StateError('User input request is no longer pending.');
    }
    final normalized = _validateAnswers(request, answers);
    await respond(requestId, {
      'answers': {
        for (final entry in normalized.entries)
          entry.key: {'answers': entry.value},
      },
    });
    _pendingUserInputs.remove(requestId);
    _emitUserInput(UserInputResolvedEvent(requestId: requestId));
  }

  Future<void> cancelUserInput(Object requestId) async {
    if (!_pendingUserInputs.containsKey(requestId)) {
      throw StateError('User input request is no longer pending.');
    }
    await respondError(
      requestId,
      _unsupportedErrorCode,
      'User input request cancelled by the user.',
    );
    _pendingUserInputs.remove(requestId);
    _emitUserInput(UserInputResolvedEvent(requestId: requestId));
  }

  void _handleRequest(CodexServerRequest request) {
    if (_disposed) {
      return;
    }
    if (_pendingApprovals.containsKey(request.id) ||
        _pendingUserInputs.containsKey(request.id)) {
      _respondDetached(
        request.id,
        _invalidParamsErrorCode,
        'Duplicate pending server request identifier.',
      );
      return;
    }

    switch (request.method) {
      case 'item/commandExecution/requestApproval':
      case 'item/fileChange/requestApproval':
      case 'item/permissions/requestApproval':
      case 'execCommandApproval':
      case 'applyPatchApproval':
        _handleApprovalRequest(request);
      case 'item/tool/requestUserInput':
        _handleUserInputRequest(request);
      case 'currentTime/read':
        _handleCurrentTimeRequest(request);
      default:
        _respondDetached(
          request.id,
          _unsupportedErrorCode,
          'Unsupported server request: ${request.method}.',
        );
    }
  }

  void _handleApprovalRequest(CodexServerRequest request) {
    if (!_reservePendingSlot(request.id)) {
      return;
    }
    final parsed = _parseApprovalRequest(request);
    _pendingApprovals[request.id] = _PendingApproval(
      parsed.$2,
      parsed.$1.approveSupported,
    );
    _emitApproval(ApprovalRequestedEvent(request: parsed.$1));
  }

  void _handleUserInputRequest(CodexServerRequest request) {
    if (!_reservePendingSlot(request.id)) {
      return;
    }
    try {
      final parsed = _parseUserInputRequest(request);
      _pendingUserInputs[request.id] = parsed;
      _emitUserInput(UserInputRequestedEvent(request: parsed));
    } on FormatException catch (error) {
      _respondDetached(
        request.id,
        _invalidParamsErrorCode,
        'Invalid item/tool/requestUserInput params: ${error.message}',
      );
    }
  }

  void _handleCurrentTimeRequest(CodexServerRequest request) {
    final seconds =
        _clock().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    _runDetached(respond(request.id, {'currentTimeAt': seconds}));
  }

  bool _reservePendingSlot(Object requestId) {
    if (_pendingCount < maxPendingRequests) {
      return true;
    }
    _respondDetached(
      requestId,
      _unsupportedErrorCode,
      'Too many pending client requests.',
    );
    return false;
  }

  (ApprovalRequest, _ApprovalResponseStyle) _parseApprovalRequest(
    CodexServerRequest request,
  ) {
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
        _ApprovalResponseStyle.commandV2,
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
        _ApprovalResponseStyle.fileV2,
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
        _ApprovalResponseStyle.execLegacy,
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
        _ApprovalResponseStyle.patchLegacy,
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
        _ApprovalResponseStyle.unsupported,
      ),
      _ => throw StateError('Unexpected approval request ${request.method}.'),
    };
  }

  UserInputRequest _parseUserInputRequest(CodexServerRequest request) {
    final params = request.params;
    final questionsValue = params['questions'];
    if (questionsValue is! List<Object?> ||
        questionsValue.isEmpty ||
        questionsValue.length > maxQuestionsPerRequest) {
      throw FormatException(
        'questions must contain 1 to $maxQuestionsPerRequest entries.',
      );
    }
    final questionIds = <String>{};
    final questions = <UserInputQuestion>[];
    for (final value in questionsValue) {
      if (value is! Map<String, Object?>) {
        throw const FormatException('each question must be an object.');
      }
      final id = _requiredBoundedString(value, 'id', _maximumIdentifierLength);
      if (!questionIds.add(id)) {
        throw FormatException('question id "$id" is duplicated.');
      }
      questions.add(
        UserInputQuestion(
          id: id,
          header: _requiredBoundedString(value, 'header', _maximumHeaderLength),
          question: _requiredBoundedString(
            value,
            'question',
            _maximumQuestionLength,
          ),
          options: _parseOptions(value['options']),
          allowsOther: _optionalBoolean(value, 'isOther'),
          isSecret: _optionalBoolean(value, 'isSecret'),
        ),
      );
    }

    return UserInputRequest(
      requestId: request.id,
      threadId: _requiredBoundedString(
        params,
        'threadId',
        _maximumIdentifierLength,
      ),
      turnId: _requiredBoundedString(
        params,
        'turnId',
        _maximumIdentifierLength,
      ),
      itemId: _requiredBoundedString(
        params,
        'itemId',
        _maximumIdentifierLength,
      ),
      isBlocking: _requiredBoolean(params, 'isBlocking'),
      questions: questions,
    );
  }

  List<UserInputOption> _parseOptions(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is! List<Object?> || value.length > maxOptionsPerQuestion) {
      throw FormatException(
        'options must contain at most $maxOptionsPerQuestion entries.',
      );
    }
    final labels = <String>{};
    final options = <UserInputOption>[];
    for (final option in value) {
      if (option is! Map<String, Object?>) {
        throw const FormatException('each option must be an object.');
      }
      final label = _requiredBoundedString(
        option,
        'label',
        _maximumOptionLabelLength,
      );
      if (!labels.add(label)) {
        throw FormatException('option label "$label" is duplicated.');
      }
      options.add(
        UserInputOption(
          label: label,
          description: _requiredBoundedString(
            option,
            'description',
            _maximumOptionDescriptionLength,
          ),
        ),
      );
    }
    return List.unmodifiable(options);
  }

  Map<String, List<String>> _validateAnswers(
    UserInputRequest request,
    UserInputAnswers answers,
  ) {
    final expectedIds = request.questions
        .map((question) => question.id)
        .toSet();
    if (answers.values.length != expectedIds.length ||
        !answers.values.keys.toSet().containsAll(expectedIds)) {
      throw ArgumentError(
        'Answers must contain exactly one entry for every question.',
        'answers',
      );
    }
    final normalized = <String, List<String>>{};
    for (final question in request.questions) {
      final values = answers.values[question.id];
      if (values == null || values.length != 1) {
        throw ArgumentError(
          'Question ${question.id} requires exactly one answer.',
          'answers',
        );
      }
      final answer = values.single.trim();
      if (answer.isEmpty || answer.length > _maximumAnswerLength) {
        throw ArgumentError(
          'Question ${question.id} has an invalid answer length.',
          'answers',
        );
      }
      if (question.options.isNotEmpty &&
          !question.allowsOther &&
          !question.options.any((option) => option.label == answer)) {
        throw ArgumentError(
          'Question ${question.id} requires one of its declared options.',
          'answers',
        );
      }
      normalized[question.id] = [answer];
    }
    return normalized;
  }

  void _handleResolvedNotification(CodexNotification notification) {
    final requestId = notification.params['requestId'];
    if (requestId == null) {
      return;
    }
    if (_pendingApprovals.remove(requestId) != null) {
      _emitApproval(ApprovalResolvedEvent(requestId: requestId));
    }
    if (_pendingUserInputs.remove(requestId) != null) {
      _emitUserInput(UserInputResolvedEvent(requestId: requestId));
    }
  }

  void _emitApproval(ApprovalEvent event) {
    if (!_approvalEvents.isClosed) {
      _approvalEvents.add(event);
    }
  }

  void _emitUserInput(UserInputEvent event) {
    if (!_userInputEvents.isClosed) {
      _userInputEvents.add(event);
    }
  }

  void _respondDetached(Object id, int code, String message) {
    _runDetached(respondError(id, code, message));
  }

  static void _runDetached(Future<void> operation) {
    unawaited(operation.catchError((Object _, StackTrace _) {}));
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

  static String _requiredBoundedString(
    JsonObject object,
    String key,
    int maximumLength,
  ) {
    final value = object[key];
    if (value is! String || value.isEmpty || value.length > maximumLength) {
      throw FormatException(
        '$key must be a non-empty string no longer than $maximumLength characters.',
      );
    }
    return value;
  }

  static bool _requiredBoolean(JsonObject object, String key) {
    final value = object[key];
    if (value is! bool) {
      throw FormatException('$key must be a boolean.');
    }
    return value;
  }

  static bool _optionalBoolean(JsonObject object, String key) {
    final value = object[key];
    if (value == null) {
      return false;
    }
    if (value is! bool) {
      throw FormatException('$key must be a boolean when present.');
    }
    return value;
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
    _pendingApprovals.clear();
    _pendingUserInputs.clear();
    await Future.wait([_approvalEvents.close(), _userInputEvents.close()]);
  }
}
