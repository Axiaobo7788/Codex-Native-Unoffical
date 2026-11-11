import 'mcp_oauth_models.dart';

/// Optional local stock-managed MCP OAuth. Read-only Remote does not expose it.
abstract interface class McpOauthGateway {
  bool get supportsMcpOauth;

  Stream<McpOauthEvent> get mcpOauthEvents;

  /// Authenticates a globally configured server without loading a cold thread.
  Future<McpOauthLoginAttempt> startMcpOauthLogin({
    required String serverName,
    int timeoutSeconds = 180,
  });
}
