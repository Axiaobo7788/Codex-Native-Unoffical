import 'dart:async';
import 'dart:convert';

import 'package:codex_native_unofficial/src/protocol/json_rpc_peer.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<JsonObject> input;
  late List<String> output;
  late JsonRpcPeer peer;

  setUp(() {
    input = StreamController<JsonObject>();
    output = [];
    peer = JsonRpcPeer(
      input: input.stream,
      writer: (message) async => output.add(message),
    );
  });

  tearDown(() async {
    await peer.close();
    await input.close();
  });

  test('correlates concurrent responses by request ID', () async {
    final first = peer.request('first');
    final second = peer.request('second');
    await pumpEventQueue();

    final firstRequest = jsonDecode(output[0]) as Map<String, Object?>;
    final secondRequest = jsonDecode(output[1]) as Map<String, Object?>;
    input.add({
      'id': secondRequest['id'],
      'result': {'value': 2},
    });
    input.add({
      'id': firstRequest['id'],
      'result': {'value': 1},
    });

    expect(await first, {'value': 1});
    expect(await second, {'value': 2});
  });

  test(
    'surfaces unknown response IDs without completing another request',
    () async {
      final protocolError = peer.protocolErrors.first;
      final pending = peer.request('known');
      await pumpEventQueue();
      final request = jsonDecode(output.single) as Map<String, Object?>;

      input.add({'id': 999, 'result': <String, Object?>{}});
      expect((await protocolError).message, contains('unknown request id 999'));

      input.add({
        'id': request['id'],
        'result': {'completed': true},
      });
      expect(await pending, {'completed': true});
    },
  );

  test('turns JSON-RPC errors into typed exceptions', () async {
    final requestFuture = peer.request('fails');
    await pumpEventQueue();
    final request = jsonDecode(output.single) as Map<String, Object?>;
    input.add({
      'id': request['id'],
      'error': {'code': -32602, 'message': 'Invalid params'},
    });

    await expectLater(
      requestFuture,
      throwsA(
        isA<JsonRpcException>()
            .having((error) => error.code, 'code', -32602)
            .having((error) => error.message, 'message', 'Invalid params'),
      ),
    );
  });

  test('peer close owns a request whose write fails later', () async {
    final delayedInput = StreamController<JsonObject>();
    final write = Completer<void>();
    final delayedPeer = JsonRpcPeer(
      input: delayedInput.stream,
      writer: (_) => write.future,
    );
    addTearDown(delayedInput.close);
    addTearDown(delayedPeer.close);
    final response = expectLater(
      delayedPeer.request('thread/items/read'),
      throwsA(isA<TransportClosedException>()),
    );
    await delayedPeer.close();
    write.completeError(StateError('Delayed write failure'));
    await response;
    await pumpEventQueue();
  });

  test('delivers an RPC error before its write finishes flushing', () async {
    final delayedInput = StreamController<JsonObject>();
    final write = Completer<void>();
    final delayedPeer = JsonRpcPeer(
      input: delayedInput.stream,
      writer: (_) => write.future,
    );
    addTearDown(delayedInput.close);
    addTearDown(delayedPeer.close);
    final response = expectLater(
      delayedPeer.request('thread/items/read'),
      throwsA(isA<JsonRpcException>()),
    );
    delayedInput.add({
      'id': 1,
      'error': {'code': -32601, 'message': 'Method not found'},
    });
    try {
      await response.timeout(const Duration(seconds: 1));
    } finally {
      write.complete();
    }
  });

  test('writes JSON-RPC errors for unsupported server requests', () async {
    await peer.respondError('server-request-1', -32000, 'Rejected');

    expect(jsonDecode(output.single), {
      'id': 'server-request-1',
      'error': {'code': -32000, 'message': 'Rejected'},
    });
  });
}
