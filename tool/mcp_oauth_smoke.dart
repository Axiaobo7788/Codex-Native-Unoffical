import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_native_unofficial/src/domain/mcp_oauth_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/child_process.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';

import 'fixtures/mcp_oauth_http_server.dart';

/// Real ProcessTransport → bundled Host → stock, with a disposable loopback
/// MCP/OAuth provider. No account, browser session or real credential is used.
Future<void> main() async {
  final codex = await const CodexExecutableLocator().locate();
  final host = await const HostExecutableLocator().locate();
  if (codex == null || host == null) {
    stderr.writeln('MCP_OAUTH_SMOKE=RUNTIME_NOT_FOUND');
    exitCode = 2;
    return;
  }
  final scratch = await Directory.systemTemp.createTemp(
    'native-mcp-oauth-smoke-',
  );
  McpOauthHttpFixture? fixture;
  ProcessTransport? transport;
  StreamSubscription<McpOauthEvent>? events;
  Completer<McpOauthCompleted?>? pendingCompletion;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  var stage = 'fixture';
  try {
    final provider = await McpOauthHttpFixture.start();
    fixture = provider;
    final configHome = await Directory('${scratch.path}/codex-home').create();
    await File('${configHome.path}/config.toml').writeAsString('''
mcp_oauth_credentials_store = "file"
[features]
remote_plugin = false
[mcp_servers.${McpOauthHttpFixture.serverName}]
url = ${jsonEncode('${provider.mcpUri}')}
[mcp_servers.${McpOauthHttpFixture.serverName}.oauth]
client_id = ${jsonEncode(McpOauthHttpFixture.clientId)}
''');
    stage = 'initialize';
    final connection = await ProcessTransport.startHost(
      hostExecutablePath: host,
      codexExecutablePath: codex,
      launcher: (path, arguments) async => IoChildProcess(
        await Process.start(
          path,
          arguments,
          workingDirectory: scratch.path,
          includeParentEnvironment: false,
          environment: {
            for (final key in ['PATH', 'SystemRoot', 'WINDIR', 'TMP', 'TEMP'])
              key: ?Platform.environment[key],
            'HOME': scratch.path,
            'USERPROFILE': scratch.path,
            'APPDATA': scratch.path,
            'LOCALAPPDATA': scratch.path,
            'CODEX_HOME': configHome.path,
            'CODEX_NATIVE_CACHE_DIR': '${scratch.path}/host-cache',
            'XDG_CONFIG_HOME': '${scratch.path}/.config',
            'XDG_CACHE_HOME': '${scratch.path}/.cache',
            'XDG_DATA_HOME': '${scratch.path}/.local/share',
            'XDG_STATE_HOME': '${scratch.path}/.local/state',
            'GIT_CONFIG_COUNT': '1',
            'GIT_CONFIG_KEY_0': 'protocol.allow',
            'GIT_CONFIG_VALUE_0': 'never',
          },
        ),
      ),
    );
    transport = connection;
    const deadline = Duration(seconds: 30);
    await connection.initialize(const InitializeRequest()).timeout(deadline);
    Future<String?> authStatus() async =>
        (await connection.listMcpServerStatus().timeout(deadline))
            .singleWhere((row) => row.name == McpOauthHttpFixture.serverName)
            .authStatus;
    stage = 'initial status';
    _check(await authStatus() == 'notLoggedIn');
    final completion = Completer<McpOauthCompleted?>();
    pendingCompletion = completion;
    events = connection.mcpOauthEvents.listen(
      (event) {
        if (event is McpOauthCompleted &&
            event.serverName == McpOauthHttpFixture.serverName &&
            event.threadId == null &&
            !completion.isCompleted) {
          completion.complete(event);
        }
      },
      onError: (Object _, StackTrace _) {
        if (!completion.isCompleted) completion.complete(null);
      },
    );
    // Attach the completion consumer before startup to cover early delivery.
    final completed = completion.future.timeout(
      deadline,
      onTimeout: () => null,
    );
    stage = 'login start';
    final attempt = await connection
        .startMcpOauthLogin(serverName: McpOauthHttpFixture.serverName)
        .timeout(deadline);
    _check(
      attempt.authorizationUri.scheme == 'http' &&
          attempt.authorizationUri.authority == provider.baseUri.authority,
    );
    stage = 'loopback browser handoff';
    final request = await client.getUrl(attempt.authorizationUri);
    final response = await request.close().timeout(deadline);
    await response.drain<void>().timeout(deadline);
    _check(response.statusCode < 400);
    stage = 'correlated completion';
    final result = await completed;
    _check(
      result != null && result.success && result.loginId == attempt.loginId,
    );
    stage = 'authenticated readback';
    _check(await authStatus() == 'oAuth');
    _check(
      provider.authorizationCount == 1 &&
          provider.exchangeCount == 1 &&
          provider.authenticatedMcpCount > 0,
    );
    stdout.writeln('MCP_OAUTH_SMOKE=PASS');
  } on Object catch (error) {
    // Never echo authorization URLs, provider error payloads or stored material.
    stderr.writeln(
      'MCP_OAUTH_SMOKE=FAIL stage=$stage type=${error.runtimeType}',
    );
    exitCode = 1;
  } finally {
    if (pendingCompletion != null && !pendingCompletion.isCompleted) {
      pendingCompletion.complete(null);
    }
    client.close(force: true);
    await events?.cancel();
    await transport?.close();
    await fixture?.close();
    await scratch.delete(recursive: true);
  }
}

void _check(bool condition) {
  if (!condition) throw StateError('Local OAuth assertion failed.');
}
