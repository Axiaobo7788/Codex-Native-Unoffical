import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_native_unofficial/src/domain/ecosystem_models.dart';
import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/child_process.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';

import 'fixtures/mcp_stdio_server.dart' as fixture;

const _deadline = Duration(seconds: 12);

Future<void> main() async {
  final codex = await const CodexExecutableLocator().locate();
  final host = await const HostExecutableLocator().locate();
  if (codex == null || host == null) {
    stderr.writeln('MCP_SMOKE=RUNTIME_NOT_FOUND');
    exitCode = 2;
    return;
  }

  try {
    await _exerciseMcp(host: host, codex: codex);
    stdout.writeln('MCP_SMOKE=PASS');
  } catch (error) {
    stderr.writeln('MCP_SMOKE=FAIL');
    stderr.writeln(error);
    exitCode = 1;
  }
}

Future<void> _exerciseMcp({required String host, required String codex}) async {
  final scratch = await Directory.systemTemp.createTemp('native-mcp-smoke-');
  HttpServer? model;
  ProcessTransport? transport;
  StreamIterator<McpElicitationEvent>? forms;
  StreamSubscription<TurnEvent>? turns;
  var modelRequests = 0;
  try {
    final endpoint = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    model = endpoint;
    endpoint.listen((request) => _replyToModel(request, () => ++modelRequests));
    final configHome = await Directory.fromUri(
      scratch.uri.resolve('codex-home/'),
    ).create();
    final script = File.fromUri(
      Platform.script.resolve('fixtures/mcp_stdio_server.dart'),
    );
    await File.fromUri(configHome.uri.resolve('config.toml')).writeAsString('''
model = "native-fixture-model"
model_provider = "native-fixture"
[model_providers.native-fixture]
name = "Native local fixture"
base_url = "http://127.0.0.1:${endpoint.port}/v1"
wire_api = "responses"
supports_websockets = false
request_max_retries = 0
stream_max_retries = 0
[mcp_servers.${fixture.fixtureServer}]
command = ${jsonEncode(Platform.resolvedExecutable)}
args = [${jsonEncode(script.path)}]
startup_timeout_sec = 5
tool_timeout_sec = 8
''');

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
          },
        ),
      ),
    );
    transport = connection;
    await connection.initialize(const InitializeRequest()).timeout(_deadline);
    final servers = await connection.listMcpServerStatus().timeout(_deadline);
    final catalog = servers.singleWhere(
      (server) => server.name == fixture.fixtureServer,
    );
    _check(
      catalog.toolCount == 1 && catalog.resourceCount == 1,
      'MCP catalog counts differ.',
    );
    _check(
      catalog.authStatus == 'unsupported' && catalog.status != 'unsupported',
      'Catalog authentication was projected as runtime status.',
    );

    Future<ThreadSummary> start(ApprovalPolicyOverride policy) => connection
        .startThread(
          ThreadStartOptions(
            cwd: scratch.path,
            sandbox: SandboxModeOverride.readOnly,
            approvalPolicy: policy,
          ),
        )
        .timeout(_deadline);

    Future<McpToolCallResultModel> call(String threadId, String value) =>
        connection
            .callMcpTool(
              McpToolCallQuery(
                server: fixture.fixtureServer,
                threadId: threadId,
                tool: fixture.fixtureTool,
                arguments: {'value': value},
              ),
            )
            .timeout(_deadline);

    final withoutApprovals = await start(ApprovalPolicyOverride.never);
    for (final threadId in [null, withoutApprovals.id]) {
      final resource = await connection
          .readMcpResource(
            McpResourceReadQuery(
              server: fixture.fixtureServer,
              uri: fixture.fixtureUri,
              threadId: threadId,
            ),
          )
          .timeout(_deadline);
      final content = resource.contents.single;
      _check(
        content is McpTextResourceContentModel &&
            content.uri == fixture.fixtureUri &&
            content.text == 'native fixture resource',
        'Unexpected MCP resource.',
      );
    }
    final echo = await call(withoutApprovals.id, 'deterministic');
    _check(
      !echo.isError &&
          echo.content.single.text == 'echo: deterministic' &&
          echo.structuredContentPreview?.contains('deterministic') == true,
      'Unexpected MCP tool result.',
    );
    final declined = await call(withoutApprovals.id, 'needs-form');
    _check(
      declined.isError && declined.content.single.text == 'decline: null',
      'Unexpected direct form outcome under never.',
    );

    final withApprovals = await start(ApprovalPolicyOverride.onRequest);
    final formEvents = StreamIterator(connection.mcpElicitationEvents);
    forms = formEvents;
    await _exerciseDirectForm(
      connection,
      formEvents,
      threadId: withApprovals.id,
      operation: () async {
        final result = await call(withApprovals.id, 'needs-form');
        _check(
          !result.isError && result.content.single.text == 'accept: answer',
          'Direct form response was not delivered to the MCP tool.',
        );
      },
    );
    await _exerciseDirectForm(
      connection,
      formEvents,
      threadId: withApprovals.id,
      operation: () async {
        final resource = await connection
            .readMcpResource(
              McpResourceReadQuery(
                server: fixture.fixtureServer,
                uri: fixture.fixtureFormUri,
                threadId: withApprovals.id,
              ),
            )
            .timeout(_deadline);
        final content = resource.contents.single;
        _check(
          content is McpTextResourceContentModel &&
              content.uri == fixture.fixtureFormUri &&
              content.text == 'accept: answer',
          'Direct form response was not delivered to the MCP resource read.',
        );
      },
    );

    final terminal = Completer<TurnCompletedEvent>();
    turns = connection.turnEvents.listen((event) {
      if (event is TurnCompletedEvent &&
          event.threadId == withApprovals.id &&
          !terminal.isCompleted) {
        terminal.complete(event);
      }
    });
    final consent = _nextForm(formEvents);
    final turn = await connection
        .startTurn(
          TurnStartOptions(
            threadId: withApprovals.id,
            text: 'Exercise the disposable MCP form.',
          ),
        )
        .timeout(_deadline);
    final consentRequest = await consent;
    _verifyForm(
      consentRequest,
      threadId: withApprovals.id,
      turnId: turn.id,
      expectsValue: false,
    );
    await _acceptForm(connection, consentRequest);

    final toolForm = await _nextForm(formEvents);
    _verifyForm(
      toolForm,
      threadId: withApprovals.id,
      turnId: turn.id,
      expectsValue: true,
    );
    await _acceptForm(connection, toolForm);

    final end = await terminal.future.timeout(_deadline);
    _check(
      end.turnId == turn.id &&
          end.status == TurnRuntimeStatus.completed &&
          modelRequests == 2,
      'Model-driven MCP fixture did not complete.',
    );
  } finally {
    try {
      await forms?.cancel();
      await turns?.cancel();
      await transport?.close();
    } finally {
      await model?.close(force: true);
      await scratch.delete(recursive: true);
    }
  }
}

Future<void> _exerciseDirectForm(
  ProcessTransport connection,
  StreamIterator<McpElicitationEvent> events, {
  required String threadId,
  required Future<void> Function() operation,
}) async {
  final request = _nextForm(events);
  await Future.wait<void>([
    operation(),
    () async {
      final form = await request;
      _verifyForm(form, threadId: threadId, expectsValue: true);
      await _acceptForm(connection, form);
    }(),
  ], eagerError: true);
}

Future<McpElicitationRequest> _nextForm(
  StreamIterator<McpElicitationEvent> events,
) async {
  while (await events.moveNext().timeout(_deadline)) {
    final event = events.current;
    if (event is McpElicitationRequestedEvent) return event.request;
  }
  throw StateError('MCP form stream closed.');
}

void _verifyForm(
  McpElicitationRequest request, {
  required String threadId,
  String? turnId,
  required bool expectsValue,
}) {
  _check(
    request.serverName == fixture.fixtureServer &&
        request.threadId == threadId &&
        request.turnId == turnId &&
        request.mode == McpElicitationMode.form,
    'Unexpected MCP form identity.',
  );
  final fields = request.fields;
  _check(
    expectsValue
        ? fields.length == 1 &&
              fields.single.id == 'value' &&
              fields.single.required
        : fields.isEmpty,
    'Unexpected MCP form fields.',
  );
}

Future<void> _acceptForm(
  ProcessTransport transport,
  McpElicitationRequest request,
) => transport
    .respondToMcpElicitation(
      requestId: request.requestId,
      action: McpElicitationAction.accept,
      content: request.fields.isEmpty ? const {} : const {'value': 'answer'},
    )
    .timeout(_deadline);

Future<void> _replyToModel(HttpRequest request, int Function() nextCall) async {
  await request.drain<void>();
  final response = request.response;
  if (request.method != 'POST' || request.uri.path != '/v1/responses') {
    response.statusCode = HttpStatus.notFound;
    await response.close();
    return;
  }

  final call = nextCall();
  response.headers.contentType = ContentType('text', 'event-stream');
  final id = 'fixture-response-$call';
  void send(String type, Map<String, Object?> payload) {
    response.write(
      'event: $type\ndata: ${jsonEncode({'type': type, ...payload})}\n\n',
    );
  }

  send('response.created', {
    'response': {'id': id},
  });
  send('response.output_item.done', {
    'item': call == 1
        ? {
            'type': 'function_call',
            'call_id': 'fixture-mcp',
            'namespace': 'mcp__${fixture.fixtureServer}',
            'name': fixture.fixtureTool,
            'arguments': '{"value":"needs-form"}',
          }
        : {
            'type': 'message',
            'role': 'assistant',
            'id': 'fixture-completed',
            'content': [
              {'type': 'output_text', 'text': 'Synthetic MCP task completed.'},
            ],
          },
  });
  send('response.completed', {
    'response': {
      'id': id,
      'usage': {'input_tokens': 0, 'output_tokens': 0, 'total_tokens': 0},
    },
  });
  await response.close();
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
