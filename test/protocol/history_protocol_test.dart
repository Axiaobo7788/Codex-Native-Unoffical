import 'dart:io';

import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
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

    final escapedHtmlSpace = parseUserMessagePresentation(
      'source: missing file \\\n&#x20;\\\nnext line&#x20;here',
    );
    expect(escapedHtmlSpace.bodyText, isNot(contains('&#x20;')));
    expect(escapedHtmlSpace.bodyText, contains('next line here'));

    final shortTurn = HistoryTurn(
      id: 't-1',
      status: TurnRuntimeStatus.completed,
      items: const [],
      startedAt: DateTime.utc(2026, 1, 1, 0, 0, 0),
      completedAt: DateTime.utc(2026, 1, 1, 0, 0, 15),
    );
    expect(shortTurn.formattedWorkDuration, 'Worked for 15s');

    final multiMinuteTurn = HistoryTurn(
      id: 't-2',
      status: TurnRuntimeStatus.completed,
      items: const [],
      startedAt: DateTime.utc(2026, 1, 1, 0, 0, 0),
      completedAt: DateTime.utc(2026, 1, 1, 0, 3, 58),
    );
    expect(multiMinuteTurn.formattedWorkDuration, 'Worked for 3m 58s');
  });

  test(
    'enforces structured attachment precedence, deduplication, caps, and adversarial envelope safety',
    () {
      const envelope = '''
# Files mentioned by the user:
## conversation.dart: lib/src/app/presentation/conversation.dart
## history_controller.dart: lib/src/features/conversation/history_controller.dart
## history_controller_dup.dart: lib/src/features/conversation/history_controller.dart

## My request for Codex:
Please verify the scroll anchor fix.
''';
      final presentation = parseUserMessagePresentation(
        envelope,
        attachments: const [
          UserAttachment(
            kind: UserAttachmentKind.mention,
            label: 'conversation.dart',
            path: r'lib\src\app\presentation\conversation.dart',
          ),
          UserAttachment(
            kind: UserAttachmentKind.image,
            label: 'review.png',
            path: '/workspace/screenshots/review.png',
          ),
        ],
      );
      expect(presentation.hadStructuredEnvelope, isTrue);
      expect(presentation.bodyText, 'Please verify the scroll anchor fix.');
      // Structured mention for conversation.dart suppresses the duplicate legacy file entry,
      // and duplicate history_controller.dart path is deduplicated.
      expect(presentation.attachments, hasLength(3));
      expect(presentation.attachments[0].kind, UserAttachmentKind.mention);
      expect(presentation.attachments[0].label, 'conversation.dart');
      expect(presentation.attachments[1].kind, UserAttachmentKind.image);
      expect(presentation.attachments[1].label, 'review.png');
      expect(presentation.attachments[2].kind, UserAttachmentKind.file);
      expect(presentation.attachments[2].label, 'history_controller.dart');

      // Adversarial input 1: user prose starting with header line but without delimiter or valid entries.
      const proseLookingLikeHeader = '''
# Files mentioned by the user:
This is actually plain user prose discussing how markdown headings work.
It does not contain any valid attachment entries or request delimiter.
''';
      final safeProse = parseUserMessagePresentation(
        proseLookingLikeHeader,
        attachments: const [
          UserAttachment(
            kind: UserAttachmentKind.skill,
            label: 'rust-check',
            path: '/skills/rust-check',
          ),
        ],
      );
      expect(safeProse.hadStructuredEnvelope, isFalse);
      expect(safeProse.bodyText, contains('plain user prose'));
      expect(safeProse.attachments, hasLength(1));
      expect(safeProse.attachments.single.kind, UserAttachmentKind.skill);

      // Adversarial input 2: excessive attachment count and oversized labels/paths/previews.
      final manyMentions = StringBuffer('# Files mentioned by the user:\n');
      for (var i = 0; i < 40; i += 1) {
        final longLabel = 'file_${i}_${'a' * 200}';
        final longPath = '/workspace/dir_$i/${'p' * 1100}/file_$i.dart';
        manyMentions.writeln('## $longLabel: $longPath');
      }
      manyMentions.writeln('\n## My request for Codex:\nBounded request.');

      final capped = parseUserMessagePresentation(
        manyMentions.toString(),
        attachments: [
          for (var i = 0; i < 6; i += 1)
            UserAttachment(
              kind: UserAttachmentKind.mention,
              label: 'structured_$i',
              path: '/workspace/structured_$i.dart',
              preview: 'x' * 4000,
            ),
        ],
      );
      expect(capped.hadStructuredEnvelope, isTrue);
      expect(capped.bodyText, 'Bounded request.');
      expect(capped.attachments, hasLength(maxUserAttachments));
      // First 6 must be the structured attachments.
      for (var i = 0; i < 6; i += 1) {
        expect(capped.attachments[i].kind, UserAttachmentKind.mention);
        expect(capped.attachments[i].label, 'structured_$i');
        expect(
          capped.attachments[i].preview!.length,
          lessThanOrEqualTo(maxAttachmentPreviewLength + 1),
        );
      }
      // Remaining 10 are bounded legacy fallback attachments.
      for (var i = 6; i < maxUserAttachments; i += 1) {
        expect(capped.attachments[i].kind, UserAttachmentKind.file);
        expect(
          capped.attachments[i].label.length,
          lessThanOrEqualTo(maxAttachmentLabelLength + 1),
        );
        expect(
          capped.attachments[i].path!.length,
          lessThanOrEqualTo(maxAttachmentPathLength + 1),
        );
      }
    },
  );

  test('domain layer import graph is a strict DAG with zero circular imports', () {
    final domainDir = Directory('lib/src/domain');
    expect(domainDir.existsSync(), isTrue);

    final directivePattern = RegExp(
      r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    final graph = <String, Set<String>>{};

    for (final entity in domainDir.listSync().whereType<File>()) {
      if (!entity.path.endsWith('.dart')) {
        continue;
      }
      final fileName = entity.uri.pathSegments.last;
      final edges = <String>{};
      final content = entity.readAsStringSync();
      for (final match in directivePattern.allMatches(content)) {
        final target = match.group(1)!;
        if (target.startsWith('dart:') || target.startsWith('package:')) {
          continue;
        }
        edges.add(target.split('/').last);
      }
      graph[fileName] = edges;
    }

    final visiting = <String>{};
    final visited = <String>{};
    final cyclePath = <String>[];

    bool hasCycle(String node) {
      if (visiting.contains(node)) {
        cyclePath.add(node);
        return true;
      }
      if (visited.contains(node)) {
        return false;
      }
      visiting.add(node);
      for (final neighbor in graph[node] ?? const <String>{}) {
        if (hasCycle(neighbor)) {
          cyclePath.add(node);
          return true;
        }
      }
      visiting.remove(node);
      visited.add(node);
      return false;
    }

    for (final file in graph.keys) {
      expect(
        hasCycle(file),
        isFalse,
        reason: 'Circular dependency detected in lib/src/domain/: $cyclePath',
      );
    }
  });
}

String _multiMegabyteOutput() {
  final kibibyte = List.filled(1024, 'x').join();
  return List.filled(3 * 1024, kibibyte).join();
}
