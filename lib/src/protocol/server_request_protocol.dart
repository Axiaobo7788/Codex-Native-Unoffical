import 'dart:async';
import 'dart:collection';

import '../domain/approval_models.dart';
import '../domain/ecosystem_models.dart';
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
    this.maxElicitationFields = 20,
  }) : assert(maxPendingRequests > 0),
       assert(maxQuestionsPerRequest > 0),
       assert(maxOptionsPerQuestion > 0),
       assert(maxElicitationFields > 0),
       _clock = clock ?? DateTime.now {
    _requestSubscription = serverRequests.listen(
      _handleRequest,
      onDone: _resolveAllPending,
    );
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
  static const _maximumElicitationMessageLength = 4000;
  static const _maximumElicitationDescriptionLength = 2000;
  static const _maximumElicitationUrlLength = 4096;

  final ProtocolResponse respond;
  final ProtocolErrorResponse respondError;
  final int maxPendingRequests;
  final int maxQuestionsPerRequest;
  final int maxOptionsPerQuestion;
  final int maxElicitationFields;
  final ProtocolClock _clock;
  final LinkedHashMap<Object, _PendingApproval> _pendingApprovals =
      LinkedHashMap();
  final LinkedHashMap<Object, UserInputRequest> _pendingUserInputs =
      LinkedHashMap();
  final LinkedHashMap<Object, McpElicitationRequest> _pendingElicitations =
      LinkedHashMap();
  final Set<Object> _inFlightRequestIds = <Object>{};
  final StreamController<ApprovalEvent> _approvalEvents =
      StreamController<ApprovalEvent>.broadcast();
  final StreamController<UserInputEvent> _userInputEvents =
      StreamController<UserInputEvent>.broadcast();
  final StreamController<McpElicitationEvent> _mcpElicitationEvents =
      StreamController<McpElicitationEvent>.broadcast();
  late final StreamSubscription<CodexServerRequest> _requestSubscription;
  late final StreamSubscription<CodexNotification> _notificationSubscription;
  var _disposed = false;

  Stream<ApprovalEvent> get approvalEvents => _approvalEvents.stream;
  Stream<UserInputEvent> get userInputEvents => _userInputEvents.stream;
  Stream<McpElicitationEvent> get mcpElicitationEvents =>
      _mcpElicitationEvents.stream;

  int get _pendingCount =>
      _pendingApprovals.length +
      _pendingUserInputs.length +
      _pendingElicitations.length;

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
    _beginResolution(requestId);
    try {
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

      if (_pendingApprovals.remove(requestId) != null) {
        _emitApproval(ApprovalResolvedEvent(requestId: requestId));
      }
    } finally {
      _inFlightRequestIds.remove(requestId);
    }
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
    _beginResolution(requestId);
    try {
      await respond(requestId, {
        'answers': {
          for (final entry in normalized.entries)
            entry.key: {'answers': entry.value},
        },
      });
      if (_pendingUserInputs.remove(requestId) != null) {
        _emitUserInput(UserInputResolvedEvent(requestId: requestId));
      }
    } finally {
      _inFlightRequestIds.remove(requestId);
    }
  }

  Future<void> cancelUserInput(Object requestId) async {
    if (!_pendingUserInputs.containsKey(requestId)) {
      throw StateError('User input request is no longer pending.');
    }
    _beginResolution(requestId);
    try {
      await respondError(
        requestId,
        _unsupportedErrorCode,
        'User input request cancelled by the user.',
      );
      if (_pendingUserInputs.remove(requestId) != null) {
        _emitUserInput(UserInputResolvedEvent(requestId: requestId));
      }
    } finally {
      _inFlightRequestIds.remove(requestId);
    }
  }

  Future<void> respondToMcpElicitation({
    required Object requestId,
    required McpElicitationAction action,
    Map<String, Object?> content = const {},
  }) async {
    final request = _pendingElicitations[requestId];
    if (request == null) {
      throw StateError('MCP elicitation request is no longer pending.');
    }
    final normalized = action == McpElicitationAction.accept
        ? _validateElicitationContent(request, content)
        : const <String, Object?>{};
    _beginResolution(requestId);
    try {
      await respond(requestId, {
        'action': action.name,
        if (action == McpElicitationAction.accept &&
            request.mode == McpElicitationMode.form)
          'content': normalized,
      });
      if (_pendingElicitations.remove(requestId) != null) {
        _emitMcpElicitation(McpElicitationResolvedEvent(requestId: requestId));
      }
    } finally {
      _inFlightRequestIds.remove(requestId);
    }
  }

  void _handleRequest(CodexServerRequest request) {
    if (_disposed) {
      return;
    }
    if (_inFlightRequestIds.contains(request.id)) {
      // A JSON-RPC ID cannot be reused before its response completes. Sending
      // another response with the same ID would itself violate correlation, so
      // keep the in-flight request authoritative and ignore the duplicate.
      return;
    }
    if (_pendingApprovals.containsKey(request.id) ||
        _pendingUserInputs.containsKey(request.id) ||
        _pendingElicitations.containsKey(request.id)) {
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
      case 'mcpServer/elicitation/request':
        _handleMcpElicitationRequest(request);
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
    try {
      _requiredBoundedString(
        request.params,
        'threadId',
        _maximumIdentifierLength,
      );
      final seconds =
          _clock().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
      _runDetached(respond(request.id, {'currentTimeAt': seconds}));
    } on FormatException catch (error) {
      _respondDetached(
        request.id,
        _invalidParamsErrorCode,
        'Invalid currentTime/read params: ${error.message}',
      );
    }
  }

  void _handleMcpElicitationRequest(CodexServerRequest request) {
    if (!_reservePendingSlot(request.id)) {
      return;
    }
    try {
      final parsed = _parseMcpElicitationRequest(request);
      _pendingElicitations[request.id] = parsed;
      _emitMcpElicitation(McpElicitationRequestedEvent(request: parsed));
    } on FormatException catch (error) {
      _respondDetached(
        request.id,
        _invalidParamsErrorCode,
        'Invalid mcpServer/elicitation/request params: ${error.message}',
      );
    }
  }

  void _beginResolution(Object requestId) {
    if (!_inFlightRequestIds.add(requestId)) {
      throw StateError('Server request response is already in flight.');
    }
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

  McpElicitationRequest _parseMcpElicitationRequest(
    CodexServerRequest request,
  ) {
    final params = request.params;
    final serverName = _requiredBoundedString(
      params,
      'serverName',
      _maximumIdentifierLength,
    );
    final threadId = _requiredBoundedString(
      params,
      'threadId',
      _maximumIdentifierLength,
    );
    final turnId = _optionalBoundedString(
      params,
      'turnId',
      _maximumIdentifierLength,
    );
    final message = _requiredBoundedString(
      params,
      'message',
      _maximumElicitationMessageLength,
    );
    final mode = _requiredBoundedString(params, 'mode', 32);
    switch (mode) {
      case 'form':
        final rawSchema = params['requestedSchema'];
        if (rawSchema is! Map<String, Object?>) {
          throw const FormatException('requestedSchema must be an object.');
        }
        final schemaType = rawSchema['type'];
        if (schemaType != 'object') {
          throw const FormatException('requestedSchema.type must be object.');
        }
        final rawProperties = rawSchema['properties'];
        if (rawProperties is! Map<String, Object?> ||
            rawProperties.length > maxElicitationFields) {
          throw FormatException(
            'requestedSchema.properties must contain at most '
            '$maxElicitationFields fields.',
          );
        }
        final requiredIds = _parseRequiredElicitationIds(
          rawSchema['required'],
          rawProperties.keys,
        );
        final fields = <McpElicitationField>[];
        for (final entry in rawProperties.entries) {
          if (entry.key.isEmpty ||
              entry.key.length > _maximumIdentifierLength) {
            throw const FormatException(
              'elicitation field ids must be non-empty bounded strings.',
            );
          }
          if (entry.value is! Map<String, Object?>) {
            throw FormatException(
              'elicitation field ${entry.key} must be an object.',
            );
          }
          fields.add(
            _parseMcpElicitationField(
              entry.key,
              entry.value! as Map<String, Object?>,
              required: requiredIds.contains(entry.key),
            ),
          );
        }
        return McpElicitationRequest(
          requestId: request.id,
          serverName: serverName,
          threadId: threadId,
          turnId: turnId,
          message: message,
          mode: McpElicitationMode.form,
          fields: fields,
        );
      case 'url':
        final elicitationId = _requiredBoundedString(
          params,
          'elicitationId',
          _maximumIdentifierLength,
        );
        final rawUrl = _requiredBoundedString(
          params,
          'url',
          _maximumElicitationUrlLength,
        );
        final url = Uri.tryParse(rawUrl);
        if (url == null ||
            !url.isAbsolute ||
            (url.scheme != 'https' && url.scheme != 'http')) {
          throw const FormatException(
            'url must be an absolute HTTP or HTTPS URL.',
          );
        }
        return McpElicitationRequest(
          requestId: request.id,
          serverName: serverName,
          threadId: threadId,
          turnId: turnId,
          message: message,
          mode: McpElicitationMode.url,
          elicitationId: elicitationId,
          url: url,
        );
      case 'openai/form':
      case 'openaiForm':
        if (!params.containsKey('requestedSchema')) {
          throw const FormatException('requestedSchema is required.');
        }
        return McpElicitationRequest(
          requestId: request.id,
          serverName: serverName,
          threadId: threadId,
          turnId: turnId,
          message: message,
          mode: McpElicitationMode.openaiForm,
        );
      default:
        throw FormatException('unsupported elicitation mode "$mode".');
    }
  }

  Set<String> _parseRequiredElicitationIds(
    Object? raw,
    Iterable<String> propertyIds,
  ) {
    if (raw == null) {
      return const {};
    }
    if (raw is! List<Object?> || raw.length > maxElicitationFields) {
      throw FormatException(
        'requestedSchema.required must contain at most '
        '$maxElicitationFields field ids.',
      );
    }
    final known = propertyIds.toSet();
    final result = <String>{};
    for (final value in raw) {
      if (value is! String ||
          value.isEmpty ||
          value.length > _maximumIdentifierLength ||
          !known.contains(value) ||
          !result.add(value)) {
        throw const FormatException(
          'requestedSchema.required must contain unique known field ids.',
        );
      }
    }
    return result;
  }

  McpElicitationField _parseMcpElicitationField(
    String id,
    JsonObject schema, {
    required bool required,
  }) {
    final type = _requiredBoundedString(schema, 'type', 32);
    final title =
        _optionalBoundedString(schema, 'title', _maximumHeaderLength) ?? id;
    final description =
        _optionalBoundedString(
          schema,
          'description',
          _maximumElicitationDescriptionLength,
        ) ??
        '';
    final minimum = _optionalFiniteNumber(schema, 'minimum');
    final maximum = _optionalFiniteNumber(schema, 'maximum');
    if (minimum != null && maximum != null && minimum > maximum) {
      throw FormatException('field $id has minimum greater than maximum.');
    }
    switch (type) {
      case 'string':
        final options = _parseElicitationOptions(schema);
        final minLength = _optionalNonNegativeInt(schema, 'minLength');
        final maxLength = _optionalNonNegativeInt(schema, 'maxLength');
        if (minLength != null && maxLength != null && minLength > maxLength) {
          throw FormatException(
            'field $id has minLength greater than maxLength.',
          );
        }
        return McpElicitationField(
          id: id,
          title: title,
          description: description,
          kind: options.isEmpty
              ? McpElicitationFieldKind.string
              : McpElicitationFieldKind.singleSelect,
          required: required,
          defaultValue: _compatibleDefault(schema['default'], type, options),
          minLength: minLength,
          maxLength: maxLength?.clamp(0, _maximumAnswerLength),
          options: options,
        );
      case 'number':
      case 'integer':
        return McpElicitationField(
          id: id,
          title: title,
          description: description,
          kind: type == 'integer'
              ? McpElicitationFieldKind.integer
              : McpElicitationFieldKind.number,
          required: required,
          defaultValue: _compatibleDefault(schema['default'], type, const []),
          minimum: minimum,
          maximum: maximum,
        );
      case 'boolean':
        return McpElicitationField(
          id: id,
          title: title,
          description: description,
          kind: McpElicitationFieldKind.boolean,
          required: required,
          defaultValue: _compatibleDefault(schema['default'], type, const []),
        );
      case 'array':
        final items = schema['items'];
        if (items is! Map<String, Object?>) {
          throw FormatException('field $id items must be an object.');
        }
        final options = _parseElicitationOptions(items);
        if (options.isEmpty) {
          throw FormatException(
            'field $id array items must declare bounded enum options.',
          );
        }
        final minItems = _optionalNonNegativeInt(schema, 'minItems');
        final maxItems = _optionalNonNegativeInt(schema, 'maxItems');
        if (minItems != null && maxItems != null && minItems > maxItems) {
          throw FormatException(
            'field $id has minItems greater than maxItems.',
          );
        }
        return McpElicitationField(
          id: id,
          title: title,
          description: description,
          kind: McpElicitationFieldKind.multiSelect,
          required: required,
          defaultValue: _compatibleMultiDefault(schema['default'], options),
          minItems: minItems,
          maxItems: maxItems?.clamp(0, maxOptionsPerQuestion),
          options: options,
        );
      default:
        throw FormatException('field $id has unsupported type "$type".');
    }
  }

  List<McpElicitationOption> _parseElicitationOptions(JsonObject schema) {
    final titled = schema['oneOf'] ?? schema['anyOf'];
    if (titled != null) {
      if (titled is! List<Object?> || titled.length > maxOptionsPerQuestion) {
        throw FormatException(
          'elicitation options must contain at most '
          '$maxOptionsPerQuestion entries.',
        );
      }
      final options = <McpElicitationOption>[];
      final seen = <String>{};
      for (final raw in titled) {
        if (raw is! Map<String, Object?>) {
          throw const FormatException('titled enum option must be an object.');
        }
        final value = _requiredBoundedString(
          raw,
          'const',
          _maximumOptionLabelLength,
        );
        final label = _requiredBoundedString(
          raw,
          'title',
          _maximumOptionLabelLength,
        );
        if (!seen.add(value)) {
          throw const FormatException(
            'elicitation option values must be unique.',
          );
        }
        options.add(McpElicitationOption(value: value, label: label));
      }
      return List.unmodifiable(options);
    }
    final rawEnum = schema['enum'];
    if (rawEnum == null) {
      return const [];
    }
    if (rawEnum is! List<Object?> || rawEnum.length > maxOptionsPerQuestion) {
      throw FormatException(
        'elicitation enum must contain at most '
        '$maxOptionsPerQuestion entries.',
      );
    }
    final rawNames = schema['enumNames'];
    if (rawNames != null &&
        (rawNames is! List<Object?> || rawNames.length != rawEnum.length)) {
      throw const FormatException('enumNames must align with enum values.');
    }
    final names = rawNames is List<Object?> ? rawNames : null;
    final seen = <String>{};
    final options = <McpElicitationOption>[];
    for (var index = 0; index < rawEnum.length; index++) {
      final value = rawEnum[index];
      if (value is! String ||
          value.isEmpty ||
          value.length > _maximumOptionLabelLength ||
          !seen.add(value)) {
        throw const FormatException(
          'elicitation enum values must be unique bounded strings.',
        );
      }
      final rawLabel = names?[index];
      final label = rawLabel ?? value;
      if (label is! String ||
          label.isEmpty ||
          label.length > _maximumOptionLabelLength) {
        throw const FormatException('elicitation option labels are invalid.');
      }
      options.add(McpElicitationOption(value: value, label: label));
    }
    return List.unmodifiable(options);
  }

  Object? _compatibleDefault(
    Object? value,
    String type,
    List<McpElicitationOption> options,
  ) {
    if (value == null) {
      return null;
    }
    return switch (type) {
      'string'
          when value is String &&
              value.length <= _maximumAnswerLength &&
              (options.isEmpty || options.any((o) => o.value == value)) =>
        value,
      'number' when value is num && _isFinite(value) => value,
      'integer' when value is int => value,
      'boolean' when value is bool => value,
      _ => null,
    };
  }

  List<String>? _compatibleMultiDefault(
    Object? value,
    List<McpElicitationOption> options,
  ) {
    if (value is! List<Object?> || value.length > maxOptionsPerQuestion) {
      return null;
    }
    final allowed = options.map((o) => o.value).toSet();
    final selected = <String>[];
    for (final raw in value) {
      if (raw is! String || !allowed.contains(raw) || selected.contains(raw)) {
        return null;
      }
      selected.add(raw);
    }
    return List.unmodifiable(selected);
  }

  Map<String, Object?> _validateElicitationContent(
    McpElicitationRequest request,
    Map<String, Object?> content,
  ) {
    if (request.mode == McpElicitationMode.openaiForm) {
      throw UnsupportedError(
        'This OpenAI form elicitation requires an official form renderer.',
      );
    }
    if (request.mode == McpElicitationMode.url) {
      if (content.isNotEmpty) {
        throw ArgumentError(
          'URL elicitation acceptance does not accept form content.',
          'content',
        );
      }
      return const {};
    }
    final fields = {for (final field in request.fields) field.id: field};
    if (!fields.keys.toSet().containsAll(content.keys)) {
      throw ArgumentError(
        'Elicitation content contains undeclared fields.',
        'content',
      );
    }
    final normalized = <String, Object?>{};
    for (final field in request.fields) {
      if (!content.containsKey(field.id)) {
        if (field.required) {
          throw ArgumentError(
            'Required elicitation field ${field.id} is missing.',
            'content',
          );
        }
        continue;
      }
      final value = content[field.id];
      normalized[field.id] = _validateElicitationValue(field, value);
    }
    return Map.unmodifiable(normalized);
  }

  Object _validateElicitationValue(McpElicitationField field, Object? value) {
    switch (field.kind) {
      case McpElicitationFieldKind.string:
        if (value is! String || value.length > _maximumAnswerLength) {
          throw ArgumentError('Field ${field.id} requires bounded text.');
        }
        final minimum = field.minLength ?? (field.required ? 1 : 0);
        final maximum = field.maxLength ?? _maximumAnswerLength;
        if (value.length < minimum || value.length > maximum) {
          throw ArgumentError('Field ${field.id} violates its length bounds.');
        }
        return value;
      case McpElicitationFieldKind.singleSelect:
        if (value is! String ||
            !field.options.any((option) => option.value == value)) {
          throw ArgumentError('Field ${field.id} requires a declared option.');
        }
        return value;
      case McpElicitationFieldKind.number:
      case McpElicitationFieldKind.integer:
        if (value is! num ||
            !_isFinite(value) ||
            (field.kind == McpElicitationFieldKind.integer && value is! int)) {
          throw ArgumentError('Field ${field.id} requires a valid number.');
        }
        if ((field.minimum != null && value < field.minimum!) ||
            (field.maximum != null && value > field.maximum!)) {
          throw ArgumentError('Field ${field.id} violates numeric bounds.');
        }
        return value;
      case McpElicitationFieldKind.boolean:
        if (value is! bool) {
          throw ArgumentError('Field ${field.id} requires a boolean.');
        }
        return value;
      case McpElicitationFieldKind.multiSelect:
        if (value is! List<Object?> || value.length > maxOptionsPerQuestion) {
          throw ArgumentError(
            'Field ${field.id} requires a bounded option list.',
          );
        }
        final allowed = field.options.map((option) => option.value).toSet();
        final selected = <String>[];
        for (final raw in value) {
          if (raw is! String ||
              !allowed.contains(raw) ||
              selected.contains(raw)) {
            throw ArgumentError(
              'Field ${field.id} contains an invalid option.',
            );
          }
          selected.add(raw);
        }
        final minimum = field.minItems ?? (field.required ? 1 : 0);
        final maximum = field.maxItems ?? maxOptionsPerQuestion;
        if (selected.length < minimum || selected.length > maximum) {
          throw ArgumentError('Field ${field.id} violates selection bounds.');
        }
        return List<String>.unmodifiable(selected);
    }
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
      final rawAnswer = values.single;
      final matchesDeclaredOption = question.options.any(
        (option) => option.label == rawAnswer,
      );
      final answer = matchesDeclaredOption || question.isSecret
          ? rawAnswer
          : rawAnswer.trim();
      if (answer.isEmpty || answer.length > _maximumAnswerLength) {
        throw ArgumentError(
          'Question ${question.id} has an invalid answer length.',
          'answers',
        );
      }
      if (question.options.isNotEmpty &&
          !question.allowsOther &&
          !matchesDeclaredOption) {
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
    if (_pendingElicitations.remove(requestId) != null) {
      _emitMcpElicitation(McpElicitationResolvedEvent(requestId: requestId));
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

  void _emitMcpElicitation(McpElicitationEvent event) {
    if (!_mcpElicitationEvents.isClosed) {
      _mcpElicitationEvents.add(event);
    }
  }

  void _resolveAllPending() {
    for (final requestId in _pendingApprovals.keys.toList(growable: false)) {
      _emitApproval(ApprovalResolvedEvent(requestId: requestId));
    }
    for (final requestId in _pendingUserInputs.keys.toList(growable: false)) {
      _emitUserInput(UserInputResolvedEvent(requestId: requestId));
    }
    for (final requestId in _pendingElicitations.keys.toList(growable: false)) {
      _emitMcpElicitation(McpElicitationResolvedEvent(requestId: requestId));
    }
    _pendingApprovals.clear();
    _pendingUserInputs.clear();
    _pendingElicitations.clear();
    _inFlightRequestIds.clear();
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

  static String? _optionalBoundedString(
    JsonObject object,
    String key,
    int maximumLength,
  ) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.isEmpty || value.length > maximumLength) {
      throw FormatException(
        '$key must be a non-empty string no longer than '
        '$maximumLength characters when present.',
      );
    }
    return value;
  }

  static num? _optionalFiniteNumber(JsonObject object, String key) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! num || !_isFinite(value)) {
      throw FormatException('$key must be a finite number when present.');
    }
    return value;
  }

  static int? _optionalNonNegativeInt(JsonObject object, String key) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! int || value < 0) {
      throw FormatException(
        '$key must be a non-negative integer when present.',
      );
    }
    return value;
  }

  static bool _isFinite(num value) => switch (value) {
    double() => value.isFinite,
    _ => true,
  };

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
    _resolveAllPending();
    await Future.wait([
      _approvalEvents.close(),
      _userInputEvents.close(),
      _mcpElicitationEvents.close(),
    ]);
  }
}
