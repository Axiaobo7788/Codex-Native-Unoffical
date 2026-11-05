import 'dart:async';
import 'dart:convert';
import 'dart:io';

const remoteWebSocketProtocol = 'codex-native-v1';
const remoteMaxMessageBytes = 1024 * 1024;
const _maxPendingWrites = 64;
const _maxPendingWriteBytes = 2 * 1024 * 1024;

abstract interface class RemoteSocket {
  Stream<Object?> get messages;
  String? get protocol;
  Future<void> get done;
  int? get closeCode;
  String? get closeReason;

  Future<void> sendText(String message);
  Future<void> close([int? code, String? reason]);
}

final class RemoteCredentialRejected implements Exception {
  const RemoteCredentialRejected();

  @override
  String toString() => 'Remote device credential was rejected.';
}

typedef RemoteSocketConnector = Future<RemoteSocket> Function(
  Uri endpoint,
  String credential,
);

final class IoRemoteSocket implements RemoteSocket {
  IoRemoteSocket._(this._socket, this._client) {
    _done = _socket.done
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _client.close(force: true));
  }

  final WebSocket _socket;
  final HttpClient _client;
  late final Future<void> _done;
  Future<void> _writeTail = Future.value();
  Future<void>? _closeOperation;
  var _pendingWrites = 0;
  var _pendingWriteBytes = 0;
  var _closing = false;

  /// Creates one Remote WebSocket and takes ownership of [client] when supplied.
  static Future<RemoteSocket> connect(
    Uri endpoint,
    String credential, {
    HttpClient? client,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final connectionClient = client ?? HttpClient();
    final socketFuture = WebSocket.connect(
      endpoint.toString(),
      headers: {HttpHeaders.authorizationHeader: 'Bearer $credential'},
      protocols: const [remoteWebSocketProtocol],
      compression: CompressionOptions.compressionOff,
      customClient: connectionClient,
      maxPayloadLength: remoteMaxMessageBytes,
    );
    try {
      return IoRemoteSocket._(
        await socketFuture.timeout(timeout),
        connectionClient,
      );
    } on TimeoutException {
      connectionClient.close(force: true);
      unawaited(
        socketFuture.then<void>((lateSocket) async {
          try {
            await lateSocket.close(
              WebSocketStatus.goingAway,
              'Remote connection attempt expired',
            );
          } on Object {
            // The late connection may already have failed or closed.
          }
        }, onError: (Object _, StackTrace _) {}),
      );
      rethrow;
    } on WebSocketException catch (error) {
      connectionClient.close(force: true);
      if (RegExp(r'HTTP status code:\s*401\b').hasMatch(error.toString())) {
        throw const RemoteCredentialRejected();
      }
      rethrow;
    } catch (_) {
      connectionClient.close(force: true);
      rethrow;
    }
  }

  @override
  Stream<Object?> get messages => _socket;

  @override
  String? get protocol => _socket.protocol;

  @override
  Future<void> get done => _done;

  @override
  int? get closeCode => _socket.closeCode;

  @override
  String? get closeReason => _socket.closeReason;

  @override
  Future<void> sendText(String message) {
    if (_closing || _socket.readyState != WebSocket.open) {
      return Future.error(
        const WebSocketException('Remote WebSocket is not open.'),
      );
    }
    final bytes = utf8.encode(message).length;
    if (bytes > remoteMaxMessageBytes) {
      return Future.error(
        const WebSocketException('Remote outbound message is too large.'),
      );
    }
    if (_pendingWrites >= _maxPendingWrites ||
        bytes > _maxPendingWriteBytes - _pendingWriteBytes) {
      return Future.error(
        const WebSocketException('Remote outbound queue is full.'),
      );
    }

    _pendingWrites += 1;
    _pendingWriteBytes += bytes;
    final scheduled = _writeTail.then<void>((_) async {
      if (_closing || _socket.readyState != WebSocket.open) {
        throw const WebSocketException('Remote WebSocket is not open.');
      }
      await _socket.addStream(Stream<Object>.value(message));
    });
    final result = scheduled.whenComplete(() {
      _pendingWrites -= 1;
      _pendingWriteBytes -= bytes;
    });
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  Future<void> close([int? code, String? reason]) =>
      _closeOperation ??= () async {
        _closing = true;
        try {
          await _writeTail.timeout(const Duration(seconds: 2));
        } on Object {
          // Continue the protocol close after a stalled/failed write.
        }
        try {
          await _socket.close(code, reason);
        } finally {
          _client.close(force: true);
        }
      }();
}
