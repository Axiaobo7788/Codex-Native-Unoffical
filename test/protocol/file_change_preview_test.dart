import 'dart:convert';

import 'package:codex_native_unofficial/src/domain/file_change_models.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
import 'package:codex_native_unofficial/src/protocol/history_protocol.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:flutter_test/flutter_test.dart';

FileChangeEntry file({
  String? ref = 'active',
  int bytes = 18,
  bool available = true,
}) => FileChangeEntry(
  index: 0,
  path: '/project/file',
  kind: FileChangeKind.add,
  diff: OutputDescriptor(
    reference: ref,
    bytes: bytes,
    storedBytes: available ? bytes : 0,
    truncated: !available,
    available: available,
  ),
);

Map<String, Object?> chunk(String ref, List<int> data, int total) => {
  'ref': ref,
  'encoding': 'base64',
  'offset': 0,
  'data': base64Encode(data),
  'bytes': total,
  'storedBytes': total,
  'truncated': false,
  'eof': data.length == total,
};

Map<String, Object?> savedChange({
  String path = '/project/file',
  String? ref = 'fresh',
  bool available = true,
  String? raw,
}) => {
  'data': [
    {
      'turnId': 'u',
      'item': {
        'id': 'i',
        'type': 'fileChange',
        'status': 'completed',
        'changes': [
          {
            'path': path,
            'kind': {'type': 'add'},
            'diff': raw ?? '',
            if (raw == null)
              '_codexNativeFileDiff': {
                'ref': ref,
                'bytes': 18,
                'storedBytes': available ? 18 : 0,
                'truncated': !available,
                'available': available,
                'lineStats': {
                  'contentLines': 2,
                  'additions': 1,
                  'deletions': 1,
                },
              },
          },
        ],
      },
    },
  ],
};

void main() {
  test('known empty file performs no stock or Host RPC', () async {
    var calls = 0;
    final adapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async {
        calls++;
        throw StateError('No request expected');
      },
    );
    final preview = await adapter.readFileChangePreview(
      threadId: 't',
      turnId: 'u',
      itemId: 'i',
      file: file(ref: null, bytes: 0, available: false),
    );
    expect(calls, 0);
    expect(preview?.file.isEmpty, isTrue);
    expect(preview?.status, FileChangePreviewStatus.ready);
  });

  test('live offered descriptor reads bounded raw add content without saved-item lookup', () async {
    const text = '- bullet\n+literal\n';
    final data = utf8.encode(text);
    final calls = <String>[];
    final adapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async {
        calls.add(method);
        expect(method, 'host/output/readRange');
        expect(params['length'], data.length);
        return chunk('active', data, data.length);
      },
    );
    final preview = await adapter.readFileChangePreview(
      threadId: 't',
      turnId: 'u',
      itemId: 'i',
      file: file(bytes: data.length),
    );
    expect(calls, ['host/output/readRange']);
    expect(preview?.lines, ['- bullet', '+literal']);
    expect(preview?.isUnifiedDiff, isFalse);
    expect(preview?.truncated, isFalse);
  });

  test('UTF-8 cut prefix and long line remain valid and bounded', () async {
    final data = utf8.encode('a${'😀' * 17000}');
    final adapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async {
        expect(params['length'], FileChangePreview.maxReadBytes);
        return chunk(
          'active',
          data.sublist(0, FileChangePreview.maxReadBytes),
          data.length,
        );
      },
    );
    final preview = await adapter.readFileChangePreview(
      threadId: 't',
      turnId: 'u',
      itemId: 'i',
      file: file(bytes: data.length),
    );
    expect(preview?.truncated, isTrue);
    expect(
      preview!.lines.single.length,
      lessThanOrEqualTo(FileChangePreview.maxLineCharacters),
    );
    expect(preview.lines.single.contains('\uFFFD'), isFalse);
    expect(preview.lines.single.runes.last, 0x1f600);
  });

  test('retired descriptor refreshes exactly one item and uses its fresh reference', () async {
    final calls = <String>[];
    final data = utf8.encode('- bullet\n+literal\n');
    final adapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async {
        calls.add(method);
        if (method == 'thread/items/read') {
          expect(params['itemIds'], ['i']);
          expect(params['turnId'], 'u');
          return savedChange();
        }
        expect(params['ref'], 'fresh');
        return chunk('fresh', data, data.length);
      },
    );
    final preview = await adapter.readFileChangePreview(
      threadId: 't',
      turnId: 'u',
      itemId: 'i',
      file: file(ref: null, available: false),
    );
    expect(calls, ['thread/items/read', 'host/output/readRange']);
    expect(preview?.file.diff?.reference, 'fresh');
    expect(preview?.lines, ['- bullet', '+literal']);
  });

  test('wrong file is rejected before reading a Host body', () async {
    final calls = <String>[];
    final adapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async {
        calls.add(method);
        return savedChange(path: '/project/another');
      },
    );
    await expectLater(
      adapter.readFileChangePreview(
        threadId: 't',
        turnId: 'u',
        itemId: 'i',
        file: file(ref: null, available: false),
      ),
      throwsA(isA<ProtocolViolation>()),
    );
    expect(calls, ['thread/items/read']);
  });

  test('expired offered reference refreshes once without resuming or replaying a turn', () async {
    final calls = <String>[];
    final data = utf8.encode('- bullet\n+literal\n');
    final adapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async {
        calls.add(method);
        if (method == 'thread/items/read') return savedChange();
        if (params['ref'] == 'active') {
          throw const JsonRpcException(
            code: -32000,
            message: 'Unknown output reference',
          );
        }
        expect(params['ref'], 'fresh');
        return chunk('fresh', data, data.length);
      },
    );
    final preview = await adapter.readFileChangePreview(
      threadId: 't',
      turnId: 'u',
      itemId: 'i',
      file: file(),
    );
    expect(calls, [
      'host/output/readRange',
      'thread/items/read',
      'host/output/readRange',
    ]);
    expect(preview?.lines, ['- bullet', '+literal']);
  });

  test(
    'fresh quota-denied descriptor stays unavailable, never empty',
    () async {
      var calls = 0;
      final adapter = HistoryProtocolAdapter(
        request: (method, [params = const {}]) async {
          calls++;
          return savedChange(ref: null, available: false);
        },
      );
      final preview = await adapter.readFileChangePreview(
        threadId: 't',
        turnId: 'u',
        itemId: 'i',
        file: file(ref: null, available: false),
      );
      expect(calls, 1);
      expect(preview?.status, FileChangePreviewStatus.unavailable);
      expect(preview?.file.isEmpty, isFalse);
    },
  );

  test(
    'direct-stock whole-item fallback keeps large content out of the preview',
    () async {
      final adapter = HistoryProtocolAdapter(
        request: (method, [params = const {}]) async =>
            savedChange(raw: 'x' * (300 * 1024)),
      );
      final preview = await adapter.readFileChangePreview(
        threadId: 't',
        turnId: 'u',
        itemId: 'i',
        file: const FileChangeEntry(
          index: 0,
          path: '/project/file',
          kind: FileChangeKind.add,
        ),
      );
      expect(preview?.status, FileChangePreviewStatus.tooLarge);
      expect(preview?.lines, isEmpty);
    },
  );
}
