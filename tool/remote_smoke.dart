import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';

const _timeout = Duration(seconds: 10);

Future<void> main() async {
  final codex = await const CodexExecutableLocator().locate();
  final host =
      Platform.environment['CODEX_NATIVE_HOST'] ??
      File('target/release/codex-native-host').absolute.path;
  if (codex == null || !await File(host).exists()) {
    stderr.writeln('REMOTE_SMOKE=RUNTIME_NOT_FOUND');
    stderr.writeln('Run `cargo build --release --workspace` first.');
    exitCode = 2;
    return;
  }

  final temporary = await Directory.systemTemp.createTemp(
    'codex-native-remote-smoke-',
  );
  Process? process;
  _LocalPeer? local;
  WebSocket? socket;
  StreamSubscription<dynamic>? socketSubscription;
  final socketMessages = _MessageQueue();
  final stderrTail = _BoundedText(16 * 1024);
  final stopwatch = Stopwatch()..start();
  var succeeded = false;
  try {
    final deviceFile = File('${temporary.path}/devices.json');
    process = await Process.start(host, [
      '--codex',
      codex,
      '--cache-dir',
      '${temporary.path}/cache',
      '--remote-device-file',
      deviceFile.path,
      '--remote-listen',
      '127.0.0.1:0',
    ]);
    process.stderr.transform(utf8.decoder).listen(stderrTail.add);
    local = _LocalPeer(process);

    final status = await local.request(1, 'host/status', const {});
    final remote = _result(status)['remote'];
    if (remote is! Map<String, dynamic> ||
        remote['enabled'] != true ||
        remote['scope'] != 'loopback' ||
        remote['tls'] != false) {
      throw StateError('Host did not report a loopback Remote listener.');
    }
    final address = remote['address'];
    if (address is! String) {
      throw StateError('Host did not report its Remote address.');
    }
    final endpoint = _parseAddress(address);

    final ticket = _result(
      await local.request(2, 'host/remote/pairing/create', const {}),
    );
    final code = ticket['code'];
    if (code is! String || code.isEmpty) {
      throw StateError('Host did not issue a pairing ticket.');
    }

    final initialized = await local.request(
      3,
      'initialize',
      const InitializeRequest().toJson(),
    );
    final userAgent = _result(initialized)['userAgent'];
    if (userAgent is! String || userAgent.isEmpty) {
      throw StateError('Stock app-server initialization failed.');
    }
    await local.notify('initialized', const {});

    final paired = await _pair(endpoint, code);
    final token = paired['token'];
    final device = paired['device'];
    if (token is! String ||
        token.length != 43 ||
        device is! Map<String, dynamic>) {
      throw StateError('Pairing response was invalid.');
    }
    final deviceId = device['id'];
    if (deviceId is! String || deviceId.isEmpty) {
      throw StateError('Pairing response had no device ID.');
    }
    final stored = await deviceFile.readAsString();
    if (stored.contains(token)) {
      throw StateError('Device store retained the bearer token in plaintext.');
    }

    socket = await WebSocket.connect(
      'ws://${endpoint.address.address}:${endpoint.port}/v1/ws',
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
      protocols: const ['codex-native-v1'],
    ).timeout(_timeout);
    if (socket.protocol != 'codex-native-v1') {
      throw StateError('Remote WebSocket subprotocol was not negotiated.');
    }
    socketSubscription = socket.listen(
      (message) {
        if (message is! String) {
          socketMessages.fail(StateError('Remote emitted a binary message.'));
          return;
        }
        final decoded = jsonDecode(message);
        if (decoded is! Map<String, dynamic>) {
          socketMessages.fail(
            StateError('Remote emitted a non-object message.'),
          );
          return;
        }
        socketMessages.add(decoded);
      },
      onError: socketMessages.fail,
      onDone: socketMessages.close,
    );

    final serverHello = await socketMessages.next().timeout(_timeout);
    if (serverHello['type'] != 'server_hello') {
      throw StateError('Remote did not start with server_hello.');
    }
    final sessionId = serverHello['sessionId'];
    if (sessionId is! String || sessionId.isEmpty) {
      throw StateError('Remote server_hello had no session ID.');
    }
    socket.add(
      jsonEncode({
        'type': 'client_hello',
        'supportedProtocolVersions': [1],
      }),
    );
    final helloAck = await socketMessages.next().timeout(_timeout);
    if (helloAck['type'] != 'hello_ack' ||
        helloAck['sessionId'] != sessionId ||
        helloAck['resyncRequired'] != false) {
      throw StateError('Remote negotiation acknowledgement was invalid.');
    }

    final models = await _remoteRequest(
      socket,
      socketMessages,
      'models',
      'model/list',
      {'limit': 10, 'includeHidden': false},
    );
    final modelData = _remoteResult(models)['data'];
    if (modelData is! List || modelData.isEmpty) {
      throw StateError('Remote model/list returned no models.');
    }

    final threads = await _remoteRequest(
      socket,
      socketMessages,
      'threads',
      'thread/list',
      {
        'limit': 1,
        'sortKey': 'created_at',
        'sortDirection': 'asc',
        'archived': false,
      },
    );
    final threadData = _remoteResult(threads)['data'];
    if (threadData is! List || threadData.isEmpty) {
      throw StateError('Remote thread/list returned no persistent thread.');
    }
    final firstThread = threadData.first;
    if (firstThread is! Map<String, dynamic> || firstThread['id'] is! String) {
      throw StateError('Remote thread/list returned an invalid thread.');
    }
    final read = await _remoteRequest(
      socket,
      socketMessages,
      'thread-read',
      'thread/read',
      {'threadId': firstThread['id'], 'includeTurns': false},
    );
    final readThread = _remoteResult(read)['thread'];
    if (readThread is! Map<String, dynamic> ||
        readThread['id'] != firstThread['id'] ||
        readThread['turns'] is! List ||
        (readThread['turns'] as List).isNotEmpty) {
      throw StateError(
        'Remote metadata-only thread/read hydrated turns or changed identity.',
      );
    }

    if (local.sawReservedResponseId) {
      throw StateError(
        'Internal Remote correlation ID leaked to desktop stdout.',
      );
    }
    final revoked = _result(
      await local.request(4, 'host/remote/devices/revoke', {
        'deviceId': deviceId,
      }),
    );
    if (revoked['revoked'] != true) {
      throw StateError('Local device revocation failed.');
    }
    await socket.done.timeout(_timeout);
    if (socket.closeCode != WebSocketStatus.policyViolation) {
      throw StateError(
        'Live revocation did not close the socket with policy violation.',
      );
    }

    succeeded = true;
    stdout.writeln('REMOTE_SMOKE=PASS');
    stdout.writeln('APP_SERVER_USER_AGENT=$userAgent');
    stdout.writeln('MODELS=${modelData.length}');
    stdout.writeln('THREAD_LISTED=true');
    stdout.writeln('THREAD_READ_METADATA_ONLY=true');
    stdout.writeln('INTERNAL_ID_LEAK=false');
    stdout.writeln('LIVE_REVOCATION=true');
  } catch (error, stackTrace) {
    stderr.writeln('REMOTE_SMOKE=FAIL');
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    await socketSubscription?.cancel();
    if (socket != null && socket.readyState != WebSocket.closed) {
      await socket.close();
    }
    if (process != null) {
      await process.stdin.close();
      try {
        final code = await process.exitCode.timeout(_timeout);
        stdout.writeln('HOST_EXIT_CODE=$code');
        if (code != 0 && succeeded) {
          stderr.writeln('REMOTE_SMOKE=FAIL_HOST_EXIT');
          exitCode = 1;
        }
      } on TimeoutException {
        process.kill(ProcessSignal.sigterm);
        try {
          await process.exitCode.timeout(const Duration(seconds: 3));
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
          await process.exitCode;
        }
        stderr.writeln('REMOTE_SMOKE=FAIL_HOST_TIMEOUT');
        exitCode = 1;
      }
      await local?.close();
    }
    stopwatch.stop();
    stdout.writeln('ELAPSED_MS=${stopwatch.elapsedMilliseconds}');
    final errors = stderrTail.text.trim();
    if (errors.isNotEmpty) {
      stderr.writeln(errors);
    }
    await temporary.delete(recursive: true);
  }
}

Future<Map<String, dynamic>> _pair(_Endpoint endpoint, String code) async {
  final client = HttpClient();
  try {
    final request = await client.post(
      endpoint.address.address,
      endpoint.port,
      '/v1/pair',
    );
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({'code': code, 'deviceName': 'Remote smoke phone'}),
    );
    final response = await request.close().timeout(_timeout);
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Pairing failed with ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Pairing response was not an object.');
    }
    return decoded;
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>> _remoteRequest(
  WebSocket socket,
  _MessageQueue messages,
  Object id,
  String method,
  Map<String, dynamic> params,
) async {
  socket.add(
    jsonEncode({'type': 'rpc', 'id': id, 'method': method, 'params': params}),
  );
  final response = await messages.next().timeout(_timeout);
  if (response['id'] != id ||
      (response['type'] != 'rpc_result' && response['type'] != 'rpc_error')) {
    throw StateError('Unexpected Remote RPC response: $response');
  }
  if (response['type'] == 'rpc_error') {
    throw StateError('Remote RPC failed: ${response['error']}');
  }
  return response;
}

Map<String, dynamic> _result(Map<String, dynamic> response) {
  final error = response['error'];
  if (error != null) {
    throw StateError('Local Host RPC failed: $error');
  }
  final result = response['result'];
  if (result is! Map<String, dynamic>) {
    throw StateError('Local Host RPC result was not an object.');
  }
  return result;
}

Map<String, dynamic> _remoteResult(Map<String, dynamic> response) {
  final result = response['result'];
  if (result is! Map<String, dynamic>) {
    throw StateError('Remote RPC result was not an object.');
  }
  return result;
}

_Endpoint _parseAddress(String value) {
  final separator = value.lastIndexOf(':');
  if (separator <= 0) {
    throw FormatException('Invalid listener address: $value');
  }
  final host = value.substring(0, separator).replaceAll(RegExp(r'^\[|\]$'), '');
  final port = int.parse(value.substring(separator + 1));
  final address = InternetAddress.tryParse(host);
  if (address == null || !address.isLoopback || port < 1 || port > 65535) {
    throw FormatException('Listener is not a valid loopback endpoint: $value');
  }
  return _Endpoint(address, port);
}

final class _Endpoint {
  const _Endpoint(this.address, this.port);

  final InternetAddress address;
  final int port;
}

final class _LocalPeer {
  _LocalPeer(this._process) {
    _subscription = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onError: _fail, onDone: _closed);
  }

  final Process _process;
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  late final StreamSubscription<String> _subscription;
  bool sawReservedResponseId = false;

  Future<Map<String, dynamic>> request(
    Object id,
    String method,
    Map<String, dynamic> params,
  ) async {
    final key = jsonEncode(id);
    final completer = Completer<Map<String, dynamic>>();
    if (_pending.putIfAbsent(key, () => completer) != completer) {
      throw StateError('Duplicate local request ID $id.');
    }
    _process.stdin.writeln(
      jsonEncode({'id': id, 'method': method, 'params': params}),
    );
    await _process.stdin.flush();
    return completer.future.timeout(_timeout);
  }

  Future<void> notify(String method, Map<String, dynamic> params) async {
    _process.stdin.writeln(jsonEncode({'method': method, 'params': params}));
    await _process.stdin.flush();
  }

  Future<void> close() => _subscription.cancel();

  void _handleLine(String line) {
    final decoded = jsonDecode(line);
    if (decoded is! Map<String, dynamic>) {
      _fail(StateError('Host stdout emitted a non-object JSON value.'));
      return;
    }
    final id = decoded['id'];
    if (id is String && id.startsWith('codex-remote:')) {
      sawReservedResponseId = true;
    }
    if (id == null) {
      return;
    }
    _pending.remove(jsonEncode(id))?.complete(decoded);
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
    _pending.clear();
  }

  void _closed() => _fail(StateError('Host stdout closed.'));
}

final class _MessageQueue {
  final Queue<Map<String, dynamic>> _messages = Queue();
  final Queue<Completer<Map<String, dynamic>>> _waiters = Queue();
  Object? _failure;

  Future<Map<String, dynamic>> next() {
    if (_messages.isNotEmpty) {
      return Future.value(_messages.removeFirst());
    }
    if (_failure case final failure?) {
      return Future.error(failure);
    }
    final completer = Completer<Map<String, dynamic>>();
    _waiters.add(completer);
    return completer.future;
  }

  void add(Map<String, dynamic> message) {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(message);
    } else {
      _messages.add(message);
    }
  }

  void fail(Object error, [StackTrace? stackTrace]) {
    _failure = error;
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().completeError(error, stackTrace);
    }
  }

  void close() => fail(StateError('Remote WebSocket closed.'));
}

final class _BoundedText {
  _BoundedText(this.maxCharacters);

  final int maxCharacters;
  String _text = '';

  void add(String value) {
    _text += value;
    if (_text.length > maxCharacters) {
      _text = _text.substring(_text.length - maxCharacters);
    }
  }

  String get text => _text;
}
