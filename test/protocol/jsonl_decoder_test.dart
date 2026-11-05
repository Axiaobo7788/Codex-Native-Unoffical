import 'dart:async';
import 'dart:convert';

import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonlDecoder', () {
    test('reassembles fragmented input', () async {
      final chunks = <List<int>>[
        utf8.encode('{"id":1,"res'),
        utf8.encode('ult":{"ok":true}}\n'),
      ];

      final messages = await Stream.fromIterable(chunks)
          .transform(const JsonlDecoder())
          .toList();

      expect(messages, [
        {
          'id': 1,
          'result': {'ok': true},
        },
      ]);
    });

    test('decodes multiple messages from one chunk', () async {
      final messages = await Stream<List<int>>.value(
        utf8.encode('{"id":1,"result":{}}\n{"method":"ready"}\n'),
      ).transform(const JsonlDecoder()).toList();

      expect(messages, [
        {'id': 1, 'result': <String, Object?>{}},
        {'method': 'ready'},
      ]);
    });

    test('reports malformed JSON and continues with later lines', () async {
      final values = <JsonObject>[];
      final errors = <Object>[];
      final done = Completer<void>();

      Stream<List<int>>.value(
            utf8.encode('not-json\n{"method":"still/usable"}\n'),
          )
          .transform(const JsonlDecoder())
          .listen(values.add, onError: errors.add, onDone: done.complete);
      await done.future;

      expect(errors, hasLength(1));
      expect(errors.single, isA<FormatException>());
      expect(values, [
        {'method': 'still/usable'},
      ]);
    });
  });
}
