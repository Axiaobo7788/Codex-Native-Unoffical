import '../domain/mcp_oauth_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';

/// Version-specific wire details remain outside feature/controller code.
final class McpOauthProtocolAdapter {
  McpOauthProtocolAdapter({
    required this.request,
    Stream<CodexNotification> notifications = const Stream.empty(),
  }) : events = notifications
           .map(_parseNotification)
           .where((event) => event != null)
           .cast<McpOauthEvent>();

  final ProtocolRequest request;
  final Stream<McpOauthEvent> events;

  static const maxIdentifierLength = maxMcpOauthIdentifierLength;
  static const maxAuthorizationUriLength = maxMcpAuthorizationUriLength;
  static final _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

  Future<McpOauthLoginAttempt> start({
    required String serverName,
    int? timeoutSeconds,
  }) async {
    final name = serverName.trim();
    if (name.isEmpty ||
        name.length > maxIdentifierLength ||
        _controlCharacters.hasMatch(name)) {
      throw ArgumentError('Invalid MCP server name.');
    }
    if (timeoutSeconds != null &&
        (timeoutSeconds < 1 || timeoutSeconds > 900)) {
      throw ArgumentError(
        'MCP sign-in timeout must be between 1 and 900 seconds.',
      );
    }
    final JsonObject result;
    try {
      result = await request('mcpServer/oauth/login', {
        'name': name,
        'timeoutSecs': ?timeoutSeconds,
      });
    } on JsonRpcException catch (error) {
      if (error.code == -32601) {
        throw const McpOauthNotSupportedException();
      }
      rethrow;
    }
    final rawUri = result['authorizationUrl'];
    if (rawUri is! String ||
        rawUri.isEmpty ||
        rawUri.length > maxAuthorizationUriLength ||
        _controlCharacters.hasMatch(rawUri)) {
      throw const ProtocolViolation('Invalid MCP authorization URL.');
    }
    final uri = Uri.tryParse(rawUri);
    if (uri == null || !isAllowedMcpAuthorizationUri(uri)) {
      throw const ProtocolViolation('Unsupported MCP authorization URL.');
    }
    return McpOauthLoginAttempt(
      authorizationUri: uri,
      loginId: _optionalIdentifier(result, 'loginId'),
    );
  }

  static McpOauthCompleted? _parseNotification(CodexNotification event) {
    if (event.method != 'mcpServer/oauthLogin/completed') {
      return null;
    }
    final name = _optionalIdentifier(event.params, 'name');
    final success = event.params['success'];
    if (name == null || success is! bool) {
      throw const ProtocolViolation('Invalid MCP sign-in completion.');
    }
    return McpOauthCompleted(
      serverName: name,
      success: success,
      loginId: _optionalIdentifier(event.params, 'loginId'),
      threadId: _optionalIdentifier(event.params, 'threadId'),
    );
  }

  static String? _optionalIdentifier(JsonObject value, String field) {
    final raw = value[field];
    if (raw == null) {
      return null;
    }
    if (raw is! String ||
        raw.trim().isEmpty ||
        raw.length > maxIdentifierLength ||
        _controlCharacters.hasMatch(raw)) {
      throw const ProtocolViolation('Invalid MCP sign-in identifier.');
    }
    return raw;
  }
}
