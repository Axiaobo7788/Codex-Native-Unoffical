import 'dart:async';
import 'dart:convert';

import 'jsonl_decoder.dart';
import 'protocol_models.dart';

typedef ProtocolWriter = Future<void> Function(String message);

/// Owns request IDs and correlates JSON-RPC responses for one connection.
final class JsonRpcPeer {
  JsonRpcPeer({required Stream<JsonObject> input, required this.writer}) {
    _inputSubscription = input.listen(
      _handleMessage,
      onError: (Object error, StackTrace stackTrace) {
        _protocolErrors.add(
          ProtocolViolation('Malformed app-server message.', error),
        );
      },
      onDone: () =>
          close(const TransportClosedException('App-server output closed.')),
    );
  }

  final ProtocolWriter writer;
  final Map<Object, Completer<JsonObject>> _pending = {};
  final StreamController<CodexNotification> _notifications =
      StreamController<CodexNotification>.broadcast();
  final StreamController<CodexServerRequest> _serverRequests =
      StreamController<CodexServerRequest>.broadcast();
  final StreamController<ProtocolViolation> _protocolErrors =
      StreamController<ProtocolViolation>.broadcast();
  late final StreamSubscription<JsonObject> _inputSubscription;
  var _nextRequestId = 1;
  var _isClosed = false;

  Stream<CodexNotification> get notifications => _notifications.stream;
  Stream<CodexServerRequest> get serverRequests => _serverRequests.stream;
  Stream<ProtocolViolation> get protocolErrors => _protocolErrors.stream;

  Future<JsonObject> request(
    String method, [
    JsonObject params = const {},
  ]) async {
    if (_isClosed) {
      throw const TransportClosedException();
    }

    final id = _nextRequestId++;
    final completer = Completer<JsonObject>();
    _pending[id] = completer;

    try {
      await _write({'id': id, 'method': method, 'params': params});
    } catch (error, stackTrace) {
      _pending.remove(id);
      completer.completeError(error, stackTrace);
    }
    return completer.future;
  }

  Future<void> notify(String method, [JsonObject params = const {}]) =>
      _write({'method': method, 'params': params});

  Future<void> respond(Object id, JsonObject result) =>
      _write({'id': id, 'result': result});

  Future<void> _write(JsonObject message) async {
    if (_isClosed) {
      throw const TransportClosedException();
    }
    await writer('${jsonEncode(message)}\n');
  }

  void _handleMessage(JsonObject message) {
    final id = message['id'];
    final method = message['method'];

    if (method is String) {
      final params = _objectParams(message['params']);
      if (id != null) {
        _serverRequests.add(
          CodexServerRequest(id: id, method: method, params: params),
        );
      } else {
        _notifications.add(CodexNotification(method: method, params: params));
      }
      return;
    }

    if (id == null) {
      _protocolErrors.add(
        const ProtocolViolation('Protocol message has neither method nor id.'),
      );
      return;
    }

    final completer = _pending.remove(id);
    if (completer == null) {
      _protocolErrors.add(
        ProtocolViolation('Received a response for unknown request id $id.'),
      );
      return;
    }

    final error = message['error'];
    if (error is Map<String, Object?>) {
      final code = error['code'];
      final errorMessage = error['message'];
      completer.completeError(
        JsonRpcException(
          code: code is int ? code : -1,
          message: errorMessage is String ? errorMessage : 'Unknown error',
          data: error['data'],
        ),
      );
      return;
    }

    final result = message['result'];
    if (result == null) {
      completer.complete(const {});
    } else if (result is Map<String, Object?>) {
      completer.complete(result);
    } else {
      completer.completeError(
        const ProtocolViolation('JSON-RPC result must be an object or null.'),
      );
    }
  }

  JsonObject _objectParams(Object? params) {
    if (params == null) {
      return const {};
    }
    if (params is Map<String, Object?>) {
      return params;
    }
    _protocolErrors.add(
      const ProtocolViolation('Protocol params must be an object or null.'),
    );
    return const {};
  }

  Future<void> close([Object? cause]) async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    final error = cause ?? const TransportClosedException();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pending.clear();
    await _inputSubscription.cancel();
    await Future.wait([
      _notifications.close(),
      _serverRequests.close(),
      _protocolErrors.close(),
    ]);
  }
}
