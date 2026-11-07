import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/history_protocol.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(String, JsonObject)> requests;
  late HistoryProtocolAdapter adapter;

  setUp(() {
    requests = [];
    adapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async {
        requests.add((method, params));
        if (method == 'thread/turns/list') {
          return {
            'data': [
              {
                'id': 'turn-1',
                'status': 'completed',
                'startedAt': 1760000000,
                'completedAt': 1760000001,
                'itemsView': 'summary',
                'items': [
                  {
                    'id': 'user-1',
                    'type': 'userMessage',
                    'content': [
                      {'type': 'text', 'text': 'Do the task'},
                      {
                        'type': 'localImage',
                        'path': '/workspace/screenshots/review.png',
                      },
                      {
                        'type': 'mention',
                        'name': 'conversation.dart',
                        'path': 'lib/src/app/presentation/conversation.dart',
                      },
                    ],
                  },
                  {
                    'id': 'command-1',
                    'type': 'commandExecution',
                    'command': 'flutter test',
                    'aggregatedOutput': _multiMegabyteOutput(),
                    'status': 'completed',
                  },
                ],
              },
            ],
            'nextCursor': 'older',
          };
        }
        if (method == 'thread/items/read') {
          return {
            'data': [
              {
                'turnId': 'turn-1',
                'item': {
                  'id': 'command-2',
                  'type': 'commandExecution',
                  'command': 'cargo test',
                  'status': 'completed',
                  'aggregatedOutput': null,
                  '_codexNativeOutput': {
                    'ref': '0123456789abcdef0123456789abcdef',
                    'bytes': 1024,
                    'storedBytes': 1024,
                    'truncated': false,
                    'available': true,
                  },
                },
              },
            ],
          };
        }
        return {
          'data': [
            {
              'turnId': 'turn-1',
              'item': {
                'id': 'command-2',
                'type': 'commandExecution',
                'command': 'cargo test',
                'status': 'completed',
                'aggregatedOutput': null,
                '_codexNativeOutput': {
                  'ref': '0123456789abcdef0123456789abcdef',
                  'bytes': 1024,
                  'storedBytes': 1024,
                  'truncated': false,
                  'available': true,
                },
              },
            },
          ],
          'nextCursor': null,
        };
      },
    );
  });

  test('requests summary-only turn pages and omits command output', () async {
    final page = await adapter.listTurns(
      const HistoryTurnQuery(threadId: 'thread-1'),
    );

    expect(requests.single.$1, 'thread/turns/list');
    expect(requests.single.$2['itemsView'], 'summary');
    expect(requests.single.$2['sortDirection'], 'desc');
    expect(page.turns.single.items, hasLength(2));
    expect(page.turns.single.items.first.attachments, hasLength(2));
    expect(page.turns.single.items.first.attachments.first.label, 'review.png');
    expect(
      page.turns.single.items.first.attachments.last.label,
      'conversation.dart',
    );
    expect(page.turns.single.items.last.text, 'Command: flutter test');
    expect(page.turns.single.items.last.text, isNot(contains('secret')));
    expect(page.nextCursor, 'older');
  });

  test('pages full items only for one selected turn', () async {
    final page = await adapter.listItems(
      const HistoryItemQuery(
        threadId: 'thread-1',
        turnId: 'turn-1',
        cursor: 'next',
      ),
    );

    expect(requests.single.$1, 'thread/items/list');
    expect(requests.single.$2, {
      'threadId': 'thread-1',
      'turnId': 'turn-1',
      'cursor': 'next',
      'limit': 25,
      'sortDirection': 'asc',
      'deferOutput': {'commandExecution': true},
    });
    expect(page.items.single.text, 'Command: cargo test');
    expect(page.items.single.output?.bytes, 1024);
    expect(
      page.items.single.output?.reference,
      '0123456789abcdef0123456789abcdef',
    );
  });

  test('reads only explicitly selected deferred item IDs', () async {
    final items = await adapter.readItems(
      threadId: 'thread-1',
      turnId: 'turn-1',
      itemIds: const ['command-2'],
    );

    expect(requests.single.$1, 'thread/items/read');
    expect(requests.single.$2, {
      'threadId': 'thread-1',
      'turnId': 'turn-1',
      'itemIds': ['command-2'],
    });
    expect(items.single.output?.storedBytes, 1024);
    await expectLater(
      adapter.readItems(
        threadId: 'thread-1',
        turnId: 'turn-1',
        itemIds: const [],
      ),
      throwsRangeError,
    );
  });

  test('normalizes pasted-file and IDE-context user message envelopes', () {
    const rawPasted = '''
# Files pasted by the user:

## "# Codex Native (Unofficial) — Handoff Prompt
Inspect the scroll behavior.": /home/user/.codex/.tmp/pasted-text/1775627585654-000.txt

Pasted text contains the user's request.

## My request:
''';
    final pasted = parseUserMessagePresentation(rawPasted);
    expect(pasted.hadStructuredEnvelope, isTrue);
    expect(pasted.attachments, hasLength(1));
    expect(pasted.attachments.single.kind, UserAttachmentKind.pastedText);
    expect(pasted.attachments.single.label, 'Pasted · 1775627585654-000.txt');
    expect(
      pasted.bodyText,
      contains('Codex Native (Unofficial) — Handoff Prompt'),
    );
    expect(pasted.bodyText, isNot(contains('# Files pasted by the user:')));
    expect(
      pasted.bodyText,
      isNot(contains("Pasted text contains the user's request.")),
    );

    final summary = ThreadSummary(
      id: 'thread-pasted',
      sessionId: 'session-pasted',
      preview: rawPasted,
      cwd: '/workspace',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      status: ThreadRuntimeStatus.notLoaded,
      ephemeral: false,
    );
    expect(summary.displayTitle, 'Codex Native (Unofficial) — Handoff Prompt');
  });
}

String _multiMegabyteOutput() {
  final kibibyte = List.filled(1024, 'x').join();
  return List.filled(3 * 1024, kibibyte).join();
}
