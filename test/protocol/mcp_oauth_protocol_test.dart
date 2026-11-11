import 'dart:async';

import 'package:codex_native_unofficial/src/domain/mcp_oauth_models.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/mcp_oauth_protocol.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses the global stock MCP login contract and accepts legacy ids',
    () async {
      final calls = <(String, JsonObject)>[];
      String? loginId = 'login-1';
      final adapter = McpOauthProtocolAdapter(
        request: (method, [params = const {}]) async {
          calls.add((method, params));
          return {
            'authorizationUrl':
                'https://auth.example.test/authorize?state=dummy',
            'loginId': ?loginId,
          };
        },
      );
      final attempt = await adapter.start(serverName: ' local-mcp ');
      expect(calls.single.$1, 'mcpServer/oauth/login');
      expect(calls.single.$2, {'name': 'local-mcp', 'timeoutSecs': 180});
      expect(attempt.authorizationUri.host, 'auth.example.test');
      expect(attempt.loginId, 'login-1');
      loginId = null;
      expect((await adapter.start(serverName: 'local-mcp')).loginId, isNull);
    },
  );

  test('rejects unsafe, malformed and oversized browser handoffs', () async {
    Object? authorizationUrl;
    Object? loginId;
    final adapter = McpOauthProtocolAdapter(
      request: (method, [params = const {}]) async => {
        'authorizationUrl': authorizationUrl,
        'loginId': loginId,
      },
    );
    for (final value in [
      null,
      42,
      '',
      '/relative',
      'file:///tmp/secret',
      'javascript:alert(1)',
      'https://user:password@auth.example.test/',
      'https://auth.example.test/\n',
      'https://auth.example.test/${'x' * 4096}',
    ]) {
      authorizationUrl = value;
      await expectLater(
        adapter.start(serverName: 'mcp'),
        throwsA(isA<ProtocolViolation>()),
      );
    }
    authorizationUrl = 'http://127.0.0.1:31234/authorize';
    expect(
      (await adapter.start(serverName: 'mcp')).authorizationUri.host,
      '127.0.0.1',
    );
    loginId = <String>['not-an-id'];
    await expectLater(
      adapter.start(serverName: 'mcp'),
      throwsA(isA<ProtocolViolation>()),
    );
  });

  test('rejects invalid arguments before issuing a request', () async {
    var requests = 0;
    final adapter = McpOauthProtocolAdapter(
      request: (method, [params = const {}]) async {
        requests++;
        return {};
      },
    );
    for (final name in ['', ' \n ', 'mcp\u0000other', 'x' * 257]) {
      await expectLater(adapter.start(serverName: name), throwsArgumentError);
    }
    await expectLater(
      adapter.start(serverName: 'mcp', timeoutSeconds: 0),
      throwsArgumentError,
    );
    await expectLater(
      adapter.start(serverName: 'mcp', timeoutSeconds: 901),
      throwsArgumentError,
    );
    expect(requests, 0);
  });

  test(
    'projects completion identity without retaining provider errors',
    () async {
      final notifications = StreamController<CodexNotification>();
      addTearDown(notifications.close);
      final adapter = McpOauthProtocolAdapter(
        request: (method, [params = const {}]) async => {},
        notifications: notifications.stream,
      );
      final event = adapter.events.first;
      notifications.add(
        const CodexNotification(method: 'unrelated', params: {}),
      );
      notifications.add(
        const CodexNotification(
          method: 'mcpServer/oauthLogin/completed',
          params: {
            'name': 'mcp',
            'success': false,
            'loginId': 'login-1',
            'threadId': 'thread-1',
            'error': 'https://auth.example.test/?sensitive=dummy',
          },
        ),
      );
      final completion = await event as McpOauthCompleted;
      expect(completion.serverName, 'mcp');
      expect(completion.success, isFalse);
      expect(completion.loginId, 'login-1');
      expect(completion.threadId, 'thread-1');
      expect(completion.toString(), isNot(contains('sensitive')));
    },
  );

  test('invalid completion is a typed protocol error', () async {
    final adapter = McpOauthProtocolAdapter(
      request: (method, [params = const {}]) async => {},
      notifications: Stream.value(
        const CodexNotification(
          method: 'mcpServer/oauthLogin/completed',
          params: {'name': 'mcp', 'success': 'true'},
        ),
      ),
    );
    await expectLater(adapter.events.first, throwsA(isA<ProtocolViolation>()));
  });
}
