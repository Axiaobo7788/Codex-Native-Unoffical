import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Disposable loopback provider, not an app-server substitute. Values below are
/// test-only credentials; the real stock runtime owns PKCE and its token store.
final class McpOauthHttpFixture {
  McpOauthHttpFixture._(this._server);

  static const serverName = 'native-oauth-fixture';
  static const clientId = 'native-local-fixture';
  final HttpServer _server;
  String? _challenge;
  var authorizationCount = 0;
  var exchangeCount = 0;
  var authenticatedMcpCount = 0;
  Uri get baseUri => Uri.parse('http://127.0.0.1:${_server.port}');
  Uri get mcpUri => baseUri.resolve('/mcp');

  static Future<McpOauthHttpFixture> start() async {
    final fixture = McpOauthHttpFixture._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    fixture._server.listen((request) => unawaited(fixture._serve(request)));
    return fixture;
  }

  Future<void> close() => _server.close(force: true).then((_) {});

  Future<void> _reply(HttpRequest request, int status, [Object? value]) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    if (value != null) request.response.write(jsonEncode(value));
    await request.response.close();
  }

  Future<void> _serve(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method == 'GET') {
        if (path.startsWith('/.well-known/oauth-protected-resource')) {
          return await _reply(request, 200, {
            'resource': '$mcpUri',
            'authorization_servers': ['$baseUri'],
            'scopes_supported': ['mcp.read'],
          });
        }
        if (path.startsWith('/.well-known/oauth-authorization-server')) {
          return await _reply(request, 200, {
            'issuer': '$baseUri',
            'authorization_endpoint': '${baseUri.resolve('/authorize')}',
            'token_endpoint': '${baseUri.resolve('/token')}',
            'response_types_supported': ['code'],
            'grant_types_supported': ['authorization_code', 'refresh_token'],
            'code_challenge_methods_supported': ['S256'],
            'token_endpoint_auth_methods_supported': ['none'],
            'scopes_supported': ['mcp.read'],
          });
        }
        if (path == '/authorize') {
          final query = request.uri.queryParameters;
          final redirect = Uri.tryParse(query['redirect_uri'] ?? '');
          if (redirect == null ||
              redirect.scheme != 'http' ||
              !['localhost', '127.0.0.1'].contains(redirect.host) ||
              redirect.userInfo.isNotEmpty ||
              query['client_id'] != clientId ||
              query['code_challenge_method'] != 'S256' ||
              query['code_challenge'] == null ||
              query['state'] == null) {
            return await _reply(request, 400);
          }
          _challenge = query['code_challenge'];
          authorizationCount++;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            redirect.replace(
              queryParameters: {
                ...redirect.queryParameters,
                'code': 'local-fixture-code',
                'state': query['state']!,
              },
            ),
          );
          return await _reply(request, 302);
        }
        return await _reply(request, path == '/mcp' ? 405 : 404);
      }
      if (request.method != 'POST') return await _reply(request, 405);
      final body = BytesBuilder(copy: false);
      await for (final chunk in request) {
        if (body.length + chunk.length > 64 * 1024) {
          return await _reply(request, 413);
        }
        body.add(chunk);
      }
      final text = utf8.decode(body.takeBytes());
      if (path == '/token') {
        final query = Uri.splitQueryString(text);
        final verifier = query['code_verifier'];
        if (verifier == null ||
            _challenge == null ||
            base64Url
                    .encode(sha256.convert(utf8.encode(verifier)).bytes)
                    .replaceAll('=', '') !=
                _challenge ||
            query['code'] != 'local-fixture-code') {
          return await _reply(request, 400);
        }
        exchangeCount++;
        return await _reply(request, 200, {
          'access_token': 'local-fixture-access',
          'refresh_token': 'local-fixture-refresh',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'scope': 'mcp.read',
        });
      }
      if (path != '/mcp') return await _reply(request, 404);
      if (request.headers.value(HttpHeaders.authorizationHeader) !=
          'Bearer local-fixture-access') {
        request.response.headers.set(
          HttpHeaders.wwwAuthenticateHeader,
          'Bearer resource_metadata="${baseUri.resolve('/.well-known/oauth-protected-resource/mcp')}", scope="mcp.read"',
        );
        return await _reply(request, 401);
      }
      authenticatedMcpCount++;
      final message = jsonDecode(text) as Map<String, Object?>;
      final id = message['id'];
      if (id == null) return await _reply(request, 202);
      final result = switch (message['method']) {
        'initialize' => {
          'protocolVersion':
              (message['params'] as Map<String, Object?>)['protocolVersion'],
          'capabilities': {'tools': <String, Object?>{}},
          'serverInfo': {'name': 'Native local OAuth fixture', 'version': '1'},
        },
        'tools/list' => {'tools': <Object?>[]},
        'resources/list' => {'resources': <Object?>[]},
        'prompts/list' => {'prompts': <Object?>[]},
        _ => null,
      };
      await _reply(request, 200, {
        'jsonrpc': '2.0',
        'id': id,
        if (result != null)
          'result': result
        else
          'error': {'code': -32601, 'message': 'Fixture method unavailable'},
      });
    } on Object {
      try {
        await _reply(request, 400);
      } on Object {
        // The disposable client can close first during test teardown.
      }
    }
  }
}
