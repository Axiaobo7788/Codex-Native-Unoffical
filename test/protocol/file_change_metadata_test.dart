import 'dart:async';

import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/protocol/file_change_summary.dart';
import 'package:codex_native_unofficial/src/protocol/history_protocol.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/turn_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> change({String path = '/project/a.txt'}) => {
  'path': path,
  'kind': {'type': 'update', 'move_path': '/project/renamed.txt'},
  'diff': '',
  '_codexNativeFileDiff': {
    'ref': 'owned-file-ref',
    'bytes': 9000000,
    'storedBytes': 64,
    'available': true,
    'truncated': true,
    'lineStats': {'contentLines': 3000000, 'additions': 7, 'deletions': 2},
  },
};

void main() {
  test(
    'live and saved detail carry metadata; turn summaries retain no file refs',
    () async {
      final item = {
        'id': 'i',
        'type': 'fileChange',
        'status': 'completed',
        'changes': [change()],
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
          params: {'threadId': 't', 'turnId': 'u', 'item': item},
        ),
      );
      final current = (await event).fileChanges!.files.single;
      expect(current.path, '/project/a.txt');
      expect(current.movePath, '/project/renamed.txt');
      expect(current.kind, FileChangeKind.update);
      expect(current.additions, 7);
      expect(current.diff?.reference, 'owned-file-ref');
      final saved = HistoryProtocolAdapter(
        request: (method, [params = const {}]) async => {
          'data': method == 'thread/turns/list'
              ? [
                  {
                    'id': 'u',
                    'status': 'completed',
                    'items': [item],
                  },
                ]
              : [
                  {'turnId': 'u', 'item': item},
                ],
        },
      );
      final summary = await saved.listTurns(
        const HistoryTurnQuery(threadId: 't'),
      );
      expect(summary.turns.single.items.single.fileChanges, isNull);
      final page = await saved.listItems(
        const HistoryItemQuery(threadId: 't', turnId: 'u'),
      );
      final info = page.items.single.fileChanges!;
      expect(info.files.single.diff?.reference, 'owned-file-ref');
      expect(info.files.single.deletions, 2);
      final retired = info.withoutSessionReferences();
      expect(retired.files.single.path, current.path);
      expect(retired.files.single.diff?.reference, isNull);
      expect(retired.files.single.diff?.available, isFalse);
      expect(retired.files.single.additions, 7);
    },
  );

  test('file metadata is immutable and bounded without retaining large paths or refs', () {
    final raw = List.generate(
      30,
      (index) => change(path: '/project/${'😀' * 700}/$index'),
    );
    (raw.first['_codexNativeFileDiff'] as Map<String, Object?>)['ref'] =
        'x' * 9000;
    final projection = parseFileChanges(raw);
    expect(projection.summary, 'File changes: 30 update(s) (+210 -60)');
    expect(projection.changes.totalFiles, 30);
    expect(projection.changes.truncated, isTrue);
    expect(projection.changes.files, hasLength(FileChangeSet.maxFiles));
    expect(projection.changes.files.first.path.length, lessThanOrEqualTo(512));
    expect(
      projection.changes.files.first.path.codeUnitAt(
        projection.changes.files.first.path.length - 1,
      ),
      isNot(inInclusiveRange(0xd800, 0xdbff)),
    );
    expect(projection.changes.files.first.pathTruncated, isTrue);
    expect(projection.changes.files.first.diff, isNull);
    expect(() => projection.changes.files.clear(), throwsUnsupportedError);
  });

  test(
    'stable patchUpdated carries the same typed per-item projection',
    () async {
      final notifications = StreamController<CodexNotification>();
      addTearDown(notifications.close);
      final live = TurnProtocolAdapter(
        request: (method, [params = const {}]) async => {},
        notifications: notifications.stream,
      );
      final next = live.events.first;
      notifications.add(
        CodexNotification(
          method: 'item/fileChange/patchUpdated',
          params: {
            'threadId': 't',
            'turnId': 'u',
            'itemId': 'i',
            'changes': [change()],
          },
        ),
      );
      final event = await next as FileChangePatchUpdatedEvent;
      expect(event.completed, isFalse);
      expect(event.itemId, 'i');
      expect(event.summary, 'File changes: 1 update(s) (+7 -2)');
      expect(event.fileChanges?.files.single.diff?.reference, 'owned-file-ref');
    },
  );
}
