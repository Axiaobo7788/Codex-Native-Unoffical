import 'jsonl_decoder.dart';

class CodexNotification {
  const CodexNotification({required this.method, required this.params});

  final String method;
  final JsonObject params;
}

class CodexServerRequest {
  const CodexServerRequest({
    required this.id,
    required this.method,
    required this.params,
  });

  final Object id;
  final String method;
  final JsonObject params;
}

class InitializeRequest {
  const InitializeRequest({
    this.clientName = 'codex-native-unofficial',
    this.clientTitle = 'Codex Native (Unofficial)',
    this.clientVersion = '0.1.0',
  });

  final String clientName;
  final String clientTitle;
  final String clientVersion;

  JsonObject toJson() => {
    'clientInfo': {
      'name': clientName,
      'title': clientTitle,
      'version': clientVersion,
    },
    'capabilities': null,
  };
}

class InitializeResult {
  const InitializeResult({required this.userAgent});

  final String userAgent;

  factory InitializeResult.fromJson(JsonObject json) {
    final userAgent = json['userAgent'];
    if (userAgent is! String || userAgent.isEmpty) {
      throw const FormatException(
        'initialize response did not contain a userAgent.',
      );
    }
    return InitializeResult(userAgent: userAgent);
  }
}

class JsonRpcException implements Exception {
  const JsonRpcException({
    required this.code,
    required this.message,
    this.data,
  });

  final int code;
  final String message;
  final Object? data;

  @override
  String toString() => 'JSON-RPC error $code: $message';
}

class ProtocolViolation implements Exception {
  const ProtocolViolation(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message ($cause)';
}

class TransportClosedException implements Exception {
  const TransportClosedException([this.message = 'Transport closed.']);

  final String message;

  @override
  String toString() => message;
}
