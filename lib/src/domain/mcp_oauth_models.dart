const maxMcpOauthIdentifierLength = 256;
const maxMcpAuthorizationUriLength = 4096;
final _mcpOauthControlCharacters = RegExp(r'[\x00-\x1F\x7F]');

bool isValidMcpOauthIdentifier(String value) =>
    value.trim().isNotEmpty &&
    value.length <= maxMcpOauthIdentifierLength &&
    !_mcpOauthControlCharacters.hasMatch(value);

/// Browser handoff returned by stock. Credentials remain owned by stock.
final class McpOauthLoginAttempt {
  const McpOauthLoginAttempt({required this.authorizationUri, this.loginId});

  final Uri authorizationUri;
  final String? loginId;
}

sealed class McpOauthEvent {
  const McpOauthEvent();
}

final class McpOauthCompleted extends McpOauthEvent {
  const McpOauthCompleted({
    required this.serverName,
    required this.success,
    this.loginId,
    this.threadId,
  });

  final String serverName;
  final bool success;
  final String? loginId;
  final String? threadId;

  // Provider error text is deliberately not retained: it can contain URLs or
  // account material. The UI reports the outcome without echoing that payload.
}

/// A client lifecycle projection, not a fabricated stock notification.
final class McpOauthInvalidated extends McpOauthEvent {
  const McpOauthInvalidated();
}

bool isAllowedMcpAuthorizationUri(Uri uri) =>
    (uri.scheme == 'https' || uri.scheme == 'http') &&
    uri.toString().length <= maxMcpAuthorizationUriLength &&
    uri.hasAuthority &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;

final class McpOauthStartPendingException implements Exception {
  const McpOauthStartPendingException();

  @override
  String toString() => 'A sign-in start is still pending in the runtime.';
}

final class McpOauthNotSupportedException implements Exception {
  const McpOauthNotSupportedException();

  @override
  String toString() => 'This runtime does not support MCP sign-in.';
}
