import 'dart:async';

import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/protocol/history_protocol.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/turn_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <String, (List<Map<String, Object?>>, String)>{
    'added Markdown is raw content, including sign-prefixed lines': (
      [
        {
          'path': '/project/notes.md',
          'kind': {'type': 'add'},
          'diff': '- bullet\r\n+literal\r\n\r\n',
        },
      ],
      'File changes: 1 update(s) (+3 -0)',
    ),
    'deleted content counts every actual line and no trailing phantom': (
      [
        {
          'path': '/project/deleted.txt',
          'kind': {'type': 'delete'},
          'diff': 'alpha\n-beta\n',
        },
      ],
      'File changes: 1 update(s) (+0 -2)',
    ),
    'hunk lines beginning with multiple signs are content, not headers': (
      [
        {
          'path': '/project/code.txt',
          'kind': {'type': 'update', 'move_path': null},
          'diff':
              '--- a/code.txt\n+++ b/code.txt\n@@ -1 +1 @@\n---old\n+++new\n',
        },
      ],
      'File changes: 1 update(s) (+1 -1)',
    ),
    'unknown modern kind must not present guessed exact statistics': (
      [
        {
          'path': '/project/file',
          'kind': {'type': 'future'},
          'diff': '+not necessarily an addition\n',
        },
      ],
      'File changes: 1 update(s)',
    ),
    'oversized input must not turn a prefix scan into exact totals': (
      [
        {
          'path': '/project/large.txt',
          'kind': {'type': 'add'},
          'diff': '- line\n' * (512 * 1024),
        },
      ],
      'File changes: 1 update(s)',
    ),
    for (final kind in ['add', 'delete', 'update'])
      'Host-spooled $kind uses full streaming statistics without raw content': (
        [
          {
            'path': '/project/spooled.txt',
            'kind': {'type': kind},
            'diff': '',
            '_codexNativeFileDiff': {
              'ref': 'opaque-session-file-diff',
              'bytes': 9000000,
              'storedBytes': 64,
              'truncated': true,
              'available': true,
              'lineStats': {
                'contentLines': 3000000,
                'additions': 17,
                'deletions': 9,
              },
            },
          },
        ],
        switch (kind) {
          'add' => 'File changes: 1 update(s) (+3000000 -0)',
          'delete' => 'File changes: 1 update(s) (+0 -3000000)',
          _ => 'File changes: 1 update(s) (+17 -9)',
        },
      ),
  };

  for (final entry in cases.entries) {
    test('live and saved ${entry.key}', () async {
      final item = <String, Object?>{
        'id': 'file-1',
        'type': 'fileChange',
        'status': 'completed',
        'changes': entry.value.$1,
      };
      final notifications = StreamController<CodexNotification>();
      addTearDown(notifications.close);
      final live = TurnProtocolAdapter(
        request: (method, [params = const {}]) async => {},
        notifications: notifications.stream,
      );
      final event = live.events
          .where((e) => e is ActivityEvent)
          .cast<ActivityEvent>()
          .first;
      notifications.add(
        CodexNotification(
          method: 'item/completed',
          params: {'threadId': 'thread-1', 'turnId': 'turn-1', 'item': item},
        ),
      );
      final liveSummary = (await event).summary;

      final saved = HistoryProtocolAdapter(
        request: (method, [params = const {}]) async => {
          'data': [
            {'turnId': 'turn-1', 'item': item},
          ],
        },
      );
      final page = await saved.listItems(
        const HistoryItemQuery(threadId: 'thread-1', turnId: 'turn-1'),
      );
      expect(
        [liveSummary, page.items.single.text],
        [entry.value.$2, entry.value.$2],
      );
    });
  }
}
