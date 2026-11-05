import 'dart:async';
import 'dart:io';

import 'package:codex_native_unofficial/src/transport/remote/remote_socket.dart';
import 'package:flutter_test/flutter_test.dart';

const _credential = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  test('serializes outbound text through the real WebSocket sink', () async {
    final pair = await _SocketPair.connect();
    addTearDown(pair.dispose);

    final received = pair.serverSocket.take(2).toList();
    await Future.wait([
      pair.client.sendText('first'),
      pair.client.sendText('second'),
    ]);

    expect(await received, ['first', 'second']);
    expect(pair.authorization, 'Bearer $_credential');
  });

  test('rejects an oversized frame before exposing a message', () async {
    final pair = await _SocketPair.connect();
    addTearDown(pair.dispose);
    final peerSubscription = pair.serverSocket.listen((_) {});
    addTearDown(peerSubscription.cancel);
    final messagesDone = expectLater(pair.client.messages, emitsDone);

    pair.serverSocket.add(''.padRight(remoteMaxMessageBytes + 1, 'x'));

    await messagesDone;
    expect(pair.client.closeCode, WebSocketStatus.protocolError);
  });

  test('maps HTTP 401 to a redacted credential rejection', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
    });
    final endpoint = Uri.parse(
      'ws://${server.address.address}:${server.port}/v1/ws',
    );

    await expectLater(
      IoRemoteSocket.connect(endpoint, _credential),
      throwsA(
        isA<RemoteCredentialRejected>().having(
          (error) => error.toString(),
          'redacted message',
          allOf(isNot(contains(endpoint.host)), isNot(contains(_credential))),
        ),
      ),
    );
  });
}

final class _SocketPair {
  const _SocketPair({
    required this.server,
    required this.serverSocket,
    required this.client,
    required this.authorization,
  });

  final HttpServer server;
  final WebSocket serverSocket;
  final RemoteSocket client;
  final String? authorization;

  static Future<_SocketPair> connect() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final upgraded = Completer<(WebSocket, String?)>();
    server.listen((request) async {
      final authorization = request.headers.value(
        HttpHeaders.authorizationHeader,
      );
      try {
        final socket = await WebSocketTransformer.upgrade(
          request,
          protocolSelector: (protocols) => remoteWebSocketProtocol,
        );
        upgraded.complete((socket, authorization));
      } catch (error, stackTrace) {
        upgraded.completeError(error, stackTrace);
      }
    });

    final client = await IoRemoteSocket.connect(
      Uri.parse('ws://${server.address.address}:${server.port}/v1/ws'),
      _credential,
    );
    final (serverSocket, authorization) = await upgraded.future;
    return _SocketPair(
      server: server,
      serverSocket: serverSocket,
      client: client,
      authorization: authorization,
    );
  }

  Future<void> dispose() async {
    try {
      await Future.wait([
        client.close(WebSocketStatus.normalClosure, 'Test closing'),
        serverSocket.close(WebSocketStatus.normalClosure, 'Test closing'),
      ]).timeout(const Duration(seconds: 2));
    } on Object {
      // The oversize-frame case may already have closed either protocol side.
    }
    await server.close(force: true);
  }
}
