import 'dart:convert';

import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/output_protocol.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(String, JsonObject)> requests;
  late OutputProtocolAdapter adapter;

  setUp(() {
    requests = [];
    adapter = OutputProtocolAdapter(
      request: (method, [params = const {}]) async {
        requests.add((method, params));
        if (method == 'host/output/stat') {
          return {
            'ref': params['ref'],
            'bytes': 12,
            'storedBytes': 10,
            'truncated': true,
          };
        }
        return {
          'ref': params['ref'],
          'offset': params['offset'] ?? 7,
          'data': base64Encode(utf8.encode('abc')),
          'encoding': 'base64',
          'bytes': 12,
          'storedBytes': 10,
          'truncated': true,
          'eof': ((params['offset'] as int?) ?? 7) + 3 >= 10,
        };
      },
    );
  });

  test('reads typed stat, range, and tail responses', () async {
    final stat = await adapter.stat('output-ref');
    expect(stat.reference, 'output-ref');
    expect(stat.bytes, 12);
    expect(stat.storedBytes, 10);
    expect(stat.truncated, isTrue);

    final range = await adapter.readRange(
      reference: 'output-ref',
      offset: 4,
      length: 3,
    );
    expect(utf8.decode(range.data), 'abc');
    expect(range.offset, 4);
    expect(range.eof, isFalse);

    final tail = await adapter.tail(reference: 'output-ref', length: 3);
    expect(utf8.decode(tail.data), 'abc');
    expect(requests.map((request) => request.$1), [
      'host/output/stat',
      'host/output/readRange',
      'host/output/tail',
    ]);
  });

  test('rejects unbounded reads before sending a request', () async {
    await expectLater(
      adapter.readRange(
        reference: 'output-ref',
        offset: 0,
        length: OutputProtocolAdapter.maxReadBytes + 1,
      ),
      throwsRangeError,
    );
    await expectLater(
      adapter.tail(reference: 'output-ref', length: 0),
      throwsRangeError,
    );
    expect(requests, isEmpty);
  });

  test('rejects malformed host descriptors and base64 chunks', () async {
    expect(
      () => OutputProtocolAdapter.descriptorFromItem({
        'ref': null,
        'bytes': 1,
        'storedBytes': 0,
        'truncated': true,
        'available': 'yes',
      }),
      throwsA(isA<ProtocolViolation>()),
    );

    final malformed = OutputProtocolAdapter(
      request: (method, [params = const {}]) async => {
        'ref': 'output-ref',
        'offset': 0,
        'data': '*not-base64*',
        'encoding': 'base64',
        'bytes': 1,
        'storedBytes': 1,
        'truncated': false,
        'eof': true,
      },
    );
    await expectLater(
      malformed.readRange(reference: 'output-ref', offset: 0, length: 1),
      throwsA(isA<ProtocolViolation>()),
    );
  });

  test('rejects a chunk that does not match the bounded request', () async {
    final mismatched = OutputProtocolAdapter(
      request: (method, [params = const {}]) async => {
        'ref': 'different-ref',
        'offset': 0,
        'data': base64Encode(utf8.encode('abc')),
        'encoding': 'base64',
        'bytes': 3,
        'storedBytes': 3,
        'truncated': false,
        'eof': true,
      },
    );

    await expectLater(
      mismatched.readRange(reference: 'output-ref', offset: 0, length: 3),
      throwsA(isA<ProtocolViolation>()),
    );
  });
}
