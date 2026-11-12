import 'dart:convert';
import 'dart:io';

import 'package:codex_native_unofficial/src/domain/chat_conversation_dag.dart';
import 'package:codex_native_unofficial/src/domain/conversation_backend.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/product_mode.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/protocol/history_protocol.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'projects only bounded single-action captions from lazy saved items',
    () async {
      final longName = '😀' * 270;
      final adapter = HistoryProtocolAdapter(
        request: (method, [params = const {}]) async {
          final command = {
            'id': 'saved-command',
            'type': 'commandExecution',
            'command': 'cat fixture.txt',
            'status': 'completed',
            'commandActions': [
              {
                'type': 'read',
                'name': longName,
                'path': '/workspace/fixture\nname.txt',
              },
            ],
          };
          return method == 'thread/turns/list'
              ? {
                  'data': [
                    {
                      'id': 'turn-1',
                      'status': 'completed',
                      'items': [command],
                    },
                  ],
                }
              : {
                  'data': [
                    {'turnId': 'turn-1', 'item': command},
                    {
                      'turnId': 'turn-1',
                      'item': {
                        ...command,
                        'id': 'compound',
                        'commandActions': [
                          {'type': 'read', 'name': 'fixture.txt'},
                          {'type': 'unknown'},
                        ],
                      },
                    },
                  ],
                };
        },
      );
      final summary = await adapter.listTurns(
        const HistoryTurnQuery(threadId: 'thread-1'),
      );
      expect(summary.turns.single.items.single.commandAction, isNull);

      final details = await adapter.listItems(
        const HistoryItemQuery(threadId: 'thread-1', turnId: 'turn-1'),
      );
      final read = details.items.first;
      expect(read.text, 'Command: cat fixture.txt');
      expect(read.commandAction?.kind, CommandActionKind.read);
      expect(read.commandAction?.name, '😀' * 240);
      expect(read.commandAction?.path, '/workspace/fixture name.txt');
      expect(details.items.last.commandAction, isNull);
    },
  );

  test(
    'prefers stock elapsed milliseconds with a legacy timestamp fallback',
    () async {
      final adapter = HistoryProtocolAdapter(
        request: (method, [params = const {}]) async {
          expect(method, 'thread/turns/list');
          expect(params['itemsView'], 'summary');
          return {
            'data': [
              for (final (id, start, end, duration) in [
                ('subsecond', 1760000000, 1760000000, 570),
                ('hour', null, null, 3602000),
                ('legacy', 1760000000, 1760000015, -1),
                ('unmeasured', null, null, null),
              ])
                {
                  'id': id,
                  'status': 'completed',
                  'items': [],
                  'startedAt': start,
                  'completedAt': end,
                  'durationMs': duration,
                },
            ],
          };
        },
      );
      final page = await adapter.listTurns(
        const HistoryTurnQuery(threadId: 'thread-1'),
      );
      expect(page.turns.map((turn) => turn.formattedWorkDuration), [
        'Worked for 0s',
        'Worked for 1h 2s',
        'Worked for 15s',
        null,
      ]);
    },
  );

  test(
    'projects only eligible saved MCP text and requests local deferral',
    () async {
      final adapter = HistoryProtocolAdapter(
        request: (method, [params = const {}]) async {
          expect(method, 'thread/items/list');
          expect(params['deferOutput'], {
            'commandExecution': true,
            'mcpToolCall': true,
          });
          return {
            'data': [
              _mcpTextEntry('inline', [_textBlock('plain text')]),
              _mcpTextEntry('deferred', [], deferred: true),
              _mcpTextEntry('missing', []),
              _mcpTextEntry('envelope', [_textBlock(' \uFEFF{"content":[]}')]),
              _mcpTextEntry('unicode-envelope', [
                _textBlock('\u0085{"content":[]}'),
              ]),
              _mcpTextEntry('array', [_textBlock('  [1,2]')]),
              _mcpTextEntry('fenced', [_textBlock('  ~~~\ntext\n~~~')]),
              _mcpTextEntry('media', [
                {'type': 'image', 'data': 'synthetic'},
              ]),
              _mcpTextEntry('annotated', [
                {
                  ..._textBlock('annotated'),
                  'annotations': <String, Object?>{},
                },
              ]),
              _mcpTextEntry(
                'structured',
                [_textBlock('plain')],
                resultFields: {
                  'structuredContent': {'value': 'opaque'},
                },
              ),
              _mcpTextEntry(
                'app',
                [_textBlock('plain')],
                itemFields: {
                  'appContext': {'resourceUri': 'ui://test/widget'},
                },
              ),
              _mcpTextEntry(
                'failed',
                [_textBlock('plain')],
                itemFields: {'status': 'failed'},
              ),
            ],
          };
        },
      );
      final page = await adapter.listItems(
        const HistoryItemQuery(threadId: 'thread-1', turnId: 'turn-1'),
        deferMcpText: true,
      );
      expect(
        page.items.where((item) => item.canReadMcpText).map((item) => item.id),
        ['inline', 'deferred'],
      );
      expect(page.items.map((item) => item.text).toSet(), {
        'MCP: fixture/tool',
      });
    },
  );

  test(
    'reads one saved MCP item and truncates at a UTF-8 scalar boundary',
    () async {
      var response = _mcpTextEntry('mcp-1', [
        _textBlock('a' * 32764),
        _textBlock('😀'),
      ]);
      final adapter = HistoryProtocolAdapter(
        request: (method, [params = const {}]) async {
          expect(method, 'thread/items/read');
          expect(params, {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'itemIds': ['mcp-1'],
          });
          return {
            'data': [response],
          };
        },
      );
      Future<SavedMcpTextResult?> read() => adapter.readSavedMcpText(
        threadId: 'thread-1',
        turnId: 'turn-1',
        itemId: 'mcp-1',
      );
      final truncated = (await read())!;
      expect(truncated.truncated, isTrue);
      expect(utf8.encode(truncated.text).length, 32765);
      expect(truncated.text, '${'a' * 32764}\n');
      response = _mcpTextEntry('mcp-1', [_textBlock('a' * 32764 + '😀')]);
      final exact = (await read())!;
      expect(exact.truncated, isFalse);
      expect(utf8.encode(exact.text).length, 32768);
      response = _mcpTextEntry('wrong-item', [_textBlock('unrelated')]);
      await expectLater(read(), throwsA(isA<ProtocolViolation>()));
      response = _mcpTextEntry('mcp-1', [], deferred: true);
      expect(await read(), isNull);
    },
  );

  test(
    'classifies only method-specific RPC unavailability as unsupported',
    () async {
      var error = const JsonRpcException(
        code: -32600,
        message: 'thread/items/read requires experimentalApi capability',
      );
      final adapter = HistoryProtocolAdapter(
        request: (method, [params = const {}]) async => throw error,
      );
      Future<SavedMcpTextResult?> read() => adapter.readSavedMcpText(
        threadId: 'thread-1',
        turnId: 'turn-1',
        itemId: 'mcp-1',
      );
      await expectLater(read(), throwsUnsupportedError);
      error = const JsonRpcException(
        code: -32600,
        message: 'Invalid saved thread',
      );
      await expectLater(read(), throwsA(same(error)));
    },
  );

  test(
    'requests a bounded saved occurrence page and keeps UTF-16 ranges',
    () async {
      final adapter = HistoryProtocolAdapter(
        request: (method, [params = const {}]) async {
          expect(method, 'thread/searchOccurrences');
          expect(params, {
            'threadId': 'thread-1',
            'searchTerm': 'Find',
            'limit': HistoryOccurrenceQuery.pageSize,
            'cursor': 'opaque-search',
          });
          return {
            'data': [_occurrenceFixture()],
            'nextCursor': 'following-page',
          };
        },
      );
      final page = await adapter.listOccurrences(
        const HistoryOccurrenceQuery(
          threadId: 'thread-1',
          searchTerm: 'Find',
          cursor: 'opaque-search',
        ),
      );
      final hit = page.occurrences.single;
      expect(hit.snippet.substring(hit.matchStart, hit.matchEnd), 'Find');
      expect(hit.itemId, 'message-1');
      expect(hit.turnCursor, 'opaque-turn-anchor');
      expect(page.nextCursor, 'following-page');
    },
  );

  test(
    'rejects malformed ranges, oversized result pages and stalled cursors',
    () async {
      final invalid = [
        {
          'data': [_occurrenceFixture(start: 1)],
        },
        {
          'data': [_occurrenceFixture(end: 99)],
        },
        {
          'data': List.filled(
            HistoryOccurrenceQuery.pageSize + 1,
            _occurrenceFixture(),
          ),
        },
        {
          'data': [_occurrenceFixture()],
          'nextCursor': 'opaque-search',
        },
        {'data': [], 'nextCursor': 'empty-page'},
      ];
      for (final result in invalid) {
        final adapter = HistoryProtocolAdapter(
          request: (_, [params = const {}]) async => result,
        );
        await expectLater(
          adapter.listOccurrences(
            const HistoryOccurrenceQuery(
              threadId: 'thread-1',
              searchTerm: 'Find',
              cursor: 'opaque-search',
            ),
          ),
          throwsA(isA<ProtocolViolation>()),
        );
      }
    },
  );

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
              'outputDeferred': true,
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

  test('projects review-mode markers from summary and paged history', () async {
    final oversizedReview = 'R' * 600;
    final reviewAdapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async => {
        'data': [
          if (method == 'thread/turns/list')
            {
              'id': 'review-turn-1',
              'status': 'completed',
              'items': [
                {
                  'id': 'review-entered',
                  'type': 'enteredReviewMode',
                  'review': 'Uncommitted changes',
                },
              ],
            }
          else
            {
              'turnId': 'review-turn-1',
              'item': {
                'id': 'review-exited',
                'type': 'exitedReviewMode',
                'review': oversizedReview,
              },
            },
        ],
        'nextCursor': null,
      },
    );

    final turns = await reviewAdapter.listTurns(
      const HistoryTurnQuery(threadId: 'thread-1'),
    );
    final entered = turns.turns.single.items.single;
    expect(entered.kind, HistoryItemKind.review);
    expect(entered.text, 'Review started: Uncommitted changes');
    expect(entered.status, 'completed');

    final items = await reviewAdapter.listItems(
      const HistoryItemQuery(threadId: 'thread-1', turnId: 'review-turn-1'),
    );
    final exited = items.items.single;
    expect(exited.kind, HistoryItemKind.review);
    expect(exited.text, 'Review completed: ${'R' * 512}…');
    expect(exited.status, 'completed');
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
    expect(page.items.single.outputDeferred, isTrue);
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
      'source: missing file \\\n&#x20;\\\nnext line &#x20;\\\nafter trailing escape',
    );
    expect(escapedHtmlSpace.bodyText, isNot(contains(r'&#x20;\')));
    expect(escapedHtmlSpace.bodyText, contains('next line'));
    expect(escapedHtmlSpace.bodyText, contains('after trailing escape'));

    const literalHtmlSpaceQuestion = '请问 HTML 里的 `&#x20;` 是什么意思？';
    final preservedLiteral = parseUserMessagePresentation(
      literalHtmlSpaceQuestion,
    );
    expect(preservedLiteral.hadStructuredEnvelope, isFalse);
    expect(preservedLiteral.bodyText, literalHtmlSpaceQuestion);

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

  test('bounds, normalizes, and deduplicates HistoryItem.attachments directly at the protocol boundary', () async {
    final oversizedName = 'label_${'n' * 400}';
    final oversizedPath = '/workspace/${'p' * 2400}/target.dart';
    final oversizedUrl = 'https://example.com/${'u' * 2400}/image.png';

    final boundedAdapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async => {
        'data': [
          {
            'id': 'turn-bounded',
            'status': 'completed',
            'itemsView': 'summary',
            'items': [
              {
                'id': 'user-bounded',
                'type': 'userMessage',
                'content': [
                  {'type': 'text', 'text': 'Check protocol attachment caps'},
                  {'type': 'localImage', 'path': oversizedPath},
                  // Duplicate localImage path with Windows separators must deduplicate:
                  {
                    'type': 'localImage',
                    'path': oversizedPath.replaceAll('/', r'\'),
                  },
                  {'type': 'image', 'url': oversizedUrl},
                  {
                    'type': 'file',
                    'name': oversizedName,
                    'path': oversizedPath,
                  },
                  {
                    'type': 'skill',
                    'name': oversizedName,
                    'path': '/skills/${'s' * 2000}',
                  },
                  for (var i = 0; i < 25; i += 1)
                    {
                      'type': 'mention',
                      'name': 'mention_${i}_${'m' * 300}',
                      'path': '/workspace/pkg_$i/${'d' * 1500}/file_$i.dart',
                    },
                ],
              },
            ],
          },
        ],
        'nextCursor': null,
      },
    );

    final page = await boundedAdapter.listTurns(
      const HistoryTurnQuery(threadId: 'thread-bounded'),
    );
    final userItem = page.turns.single.items.single;
    expect(userItem.attachments, hasLength(maxUserAttachments));
    for (final attachment in userItem.attachments) {
      expect(
        attachment.label.length,
        lessThanOrEqualTo(maxAttachmentLabelLength + 1),
      );
      expect(attachment.path, isNotNull);
      expect(
        attachment.path!.length,
        lessThanOrEqualTo(maxAttachmentPathLength + 1),
      );
    }
    // First attachment is the localImage whose fallback label is the basename ('target.dart')
    // and whose duplicate Windows-separator entry was deduplicated.
    expect(userItem.attachments[0].kind, UserAttachmentKind.image);
    expect(userItem.attachments[0].label, 'target.dart');
    expect(userItem.attachments[1].kind, UserAttachmentKind.image);
    expect(userItem.attachments[1].label, 'Image');
    expect(userItem.attachments[2].kind, UserAttachmentKind.file);
    expect(userItem.attachments[3].kind, UserAttachmentKind.skill);
    expect(userItem.attachments[4].kind, UserAttachmentKind.mention);
  });

  test('enforces structured attachment precedence, deduplication, caps, and adversarial envelope safety', () {
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

    // Adversarial input 1a: user prose starting with header line and ALSO containing
    // `## My request:`, but with ordinary prose paragraphs instead of valid attachment entries.
    const proseWithHeaderAndRequestHeading = '''
# Files mentioned by the user:

我正在讨论这种 Markdown 格式，但下面并没有 `## name: path` 条目。

## My request:

为什么这个格式会被误判？
''';
    final preservedProseWithDelimiter = parseUserMessagePresentation(
      proseWithHeaderAndRequestHeading,
      attachments: const [
        UserAttachment(
          kind: UserAttachmentKind.skill,
          label: 'rust-check',
          path: '/skills/rust-check',
        ),
      ],
    );
    expect(preservedProseWithDelimiter.hadStructuredEnvelope, isFalse);
    expect(
      preservedProseWithDelimiter.bodyText,
      proseWithHeaderAndRequestHeading,
    );
    expect(preservedProseWithDelimiter.attachments, hasLength(1));
    expect(
      preservedProseWithDelimiter.attachments.single.kind,
      UserAttachmentKind.skill,
    );

    // Adversarial input 1b: header followed immediately by `## My request:` with zero entries.
    const emptyHeaderWithDelimiter = '''
# Files mentioned by the user:

## My request:

Nothing was actually attached above.
''';
    final preservedEmptyHeader = parseUserMessagePresentation(
      emptyHeaderWithDelimiter,
    );
    expect(preservedEmptyHeader.hadStructuredEnvelope, isFalse);
    expect(preservedEmptyHeader.bodyText, emptyHeaderWithDelimiter);

    // Adversarial input 1c: `# Files pasted by the user:` whose quoted preview itself
    // contains `## My request:` before the real outer `## My request:` delimiter.
    const pastedWithInnerDelimiter = '''
# Files pasted by the user:

## "# Quoted Handoff
## My request:
Inner request line inside pasted preview.": /home/user/.codex/.tmp/pasted-text/inner.txt

Pasted text contains the user's request.

## My request:
Outer actual user request after envelope.
''';
    final parsedInnerDelimiter = parseUserMessagePresentation(
      pastedWithInnerDelimiter,
    );
    expect(parsedInnerDelimiter.hadStructuredEnvelope, isTrue);
    expect(
      parsedInnerDelimiter.bodyText,
      'Outer actual user request after envelope.',
    );
    expect(parsedInnerDelimiter.attachments, hasLength(1));
    expect(parsedInnerDelimiter.attachments.single.label, 'Pasted · inner.txt');
    expect(
      parsedInnerDelimiter.attachments.single.preview,
      contains('Inner request line inside pasted preview.'),
    );

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
  });

  test(
    'domain layer import graph is a strict DAG with zero circular imports',
    () {
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
    },
  );

  test('projects rich Codex item types (mcpToolCall, dynamicToolCall, collabAgentToolCall, webSearch, plan, contextCompaction)', () async {
    final richAdapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async => {
        'data': [
          {
            'id': 'turn-rich',
            'status': 'completed',
            'itemsView': 'summary',
            'items': [
              {
                'id': 'mcp-1',
                'type': 'mcpToolCall',
                'server': 'filesystem',
                'tool': 'read_file',
                'status': 'completed',
              },
              {
                'id': 'dyn-1',
                'type': 'dynamicToolCall',
                'tool': 'run_linter',
                'status': 'completed',
              },
              {
                'id': 'collab-1',
                'type': 'collabAgentToolCall',
                'tool': 'spawn_worker',
                'status': 'completed',
              },
              {
                'id': 'search-1',
                'type': 'webSearch',
                'query': 'flutter custom scroll view',
                'status': 'completed',
              },
              {
                'id': 'plan-1',
                'type': 'plan',
                'steps': [
                  {'step': '1', 'status': 'completed'},
                  {'step': '2', 'status': 'inProgress'},
                ],
                'status': 'completed',
              },
              {
                'id': 'file-1',
                'type': 'fileChange',
                'changes': [
                  {
                    'path': 'lib/main.dart',
                    'diff': '--- a/lib/main.dart\n+++ b/lib/main.dart\n@@ -1 +1,2 @@\n-old\n+new1\n+new2\n',
                  },
                ],
                'status': 'completed',
              },
              {
                'id': 'compact-1',
                'type': 'contextCompaction',
                'status': 'completed',
              },
            ],
          },
        ],
        'nextCursor': null,
      },
    );

    final page = await richAdapter.listTurns(
      const HistoryTurnQuery(threadId: 'thread-rich'),
    );
    final items = page.turns.single.items;
    expect(items, hasLength(7));
    expect(items[0].kind, HistoryItemKind.activity);
    expect(items[0].text, 'MCP: filesystem/read_file');
    expect(items[1].text, 'Tool: run_linter');
    expect(items[2].text, 'Collaboration: spawn_worker');
    expect(items[3].text, 'Web search: flutter custom scroll view');
    expect(items[4].text, 'Plan updated (1/2 completed)');
    expect(items[5].text, 'File changes: 1 update(s) (+2 -1)');
    expect(items[6].text, 'Context compacted');
  });

  test('parses ChatGPT conversations.json mapping DAG with cycle protection and sibling branch switching', () {
    final dag = ChatConversationDag.fromMappingJson({
      'current_node': 'asst-b',
      'mapping': {
        'root': {
          'id': 'root',
          'parent': null,
          'children': ['user-a', 'user-b'],
        },
        'user-a': {
          'id': 'user-a',
          'parent': 'root',
          'children': ['asst-a'],
          'message': {
            'id': 'turn-a',
            'author': {'role': 'user'},
            'content': {
              'parts': ['Original question'],
            },
          },
        },
        'asst-a': {
          'id': 'asst-a',
          'parent': 'user-a',
          'children': <Object?>[],
          'message': {
            'id': 'turn-a',
            'author': {'role': 'assistant'},
            'content': {
              'parts': ['Original answer'],
            },
          },
        },
        'user-b': {
          'id': 'user-b',
          'parent': 'root',
          'children': ['asst-b'],
          'message': {
            'id': 'turn-b',
            'author': {'role': 'user'},
            'content': {
              'parts': ['Edited question'],
            },
          },
        },
        'asst-b': {
          'id': 'asst-b',
          'parent': 'user-b',
          'children': <Object?>[],
          'message': {
            'id': 'turn-b',
            'author': {'role': 'assistant'},
            'content': {
              'parts': ['Edited answer'],
            },
          },
        },
      },
    });

    expect(dag.activeVisibleMessages.map((n) => n.text), [
      'Edited question',
      'Edited answer',
    ]);
    final siblingInfo = dag.siblingInfoFor('user-b')!;
    expect(siblingInfo.hasMultipleBranches, isTrue);
    expect(siblingInfo.displayLabel, '2/2');
    expect(siblingInfo.canSelectPrevious, isTrue);
    expect(siblingInfo.canSelectNext, isFalse);

    final switched = dag.selectSiblingBranch(nodeId: 'user-b', offset: -1);
    expect(switched.activeVisibleMessages.map((n) => n.text), [
      'Original question',
      'Original answer',
    ]);
    expect(switched.siblingInfoFor('user-a')!.displayLabel, '1/2');

    final switchedBack = switched.selectSiblingBranch(
      nodeId: 'user-a',
      offset: 1,
    );
    expect(switchedBack.activeVisibleMessages.map((n) => n.text), [
      'Edited question',
      'Edited answer',
    ]);
  });

  test('isolates sibling branch groups per turn and preserves assistant replies across 3+ chained branches', () {
    var dag = const ChatConversationDag.empty();

    // Branch Turn 1 -> 1b -> 1c (3 branches on Turn 1)
    dag = dag.recordTurnBranch(
      turnId: 'turn-1',
      originalUserText: 'Turn 1 v1',
      originalAssistantText: 'Reply 1 v1',
      nextTurnId: 'turn-1b',
      nextUserText: 'Turn 1 v2',
    );
    dag = dag.recordTurnBranch(
      turnId: 'turn-1b',
      originalUserText: 'Turn 1 v2',
      originalAssistantText: 'Reply 1 v2',
      nextTurnId: 'turn-1c',
      nextUserText: 'Turn 1 v3',
      nextAssistantText: 'Reply 1 v3',
    );

    // Branch Turn 2 -> 2b in the same conversation DAG
    dag = dag.recordTurnBranch(
      turnId: 'turn-2',
      originalUserText: 'Turn 2 v1',
      originalAssistantText: 'Reply 2 v1',
      nextTurnId: 'turn-2b',
      nextUserText: 'Turn 2 v2',
      nextAssistantText: 'Reply 2 v2',
    );

    // Turn 1 has 3 siblings (3/3) and Turn 2 has 2 siblings (2/2), never merged into 5!
    final activeTurn1 = dag.activeSiblingForTurn('turn-1c')!;
    final infoTurn1 = dag.siblingInfoFor(activeTurn1.id)!;
    expect(infoTurn1.displayLabel, '3/3');
    expect(dag.assistantChildFor(activeTurn1.id)?.text, 'Reply 1 v3');

    final activeTurn2 = dag.activeSiblingForTurn('turn-2b')!;
    final infoTurn2 = dag.siblingInfoFor(activeTurn2.id)!;
    expect(infoTurn2.displayLabel, '2/2');
    expect(dag.assistantChildFor(activeTurn2.id)?.text, 'Reply 2 v2');

    // Step Turn 1 back to 2/3 and verify Reply 1 v2 is preserved while Turn 2 stays at 2/2
    dag = dag.selectSiblingBranch(nodeId: activeTurn1.id, offset: -1);
    final turn1Branch2 = dag.activeSiblingForTurn('turn-1c')!;
    expect(dag.siblingInfoFor(turn1Branch2.id)!.displayLabel, '2/3');
    expect(turn1Branch2.text, 'Turn 1 v2');
    expect(dag.assistantChildFor(turn1Branch2.id)?.text, 'Reply 1 v2');
    expect(
      dag.siblingInfoFor(dag.activeSiblingForTurn('turn-2b')!.id)!.displayLabel,
      '2/2',
    );
  });

  test('resolves mode-aware BackendCapabilities across Codex, Work, and Chat modes', () {
    final codexCaps = resolveEffectiveCapabilities(
      transportCapabilities: const BackendCapabilities.stockCodexLocal(),
      mode: ProductMode.codex,
    );
    expect(codexCaps.supportsSandboxConfiguration, isTrue);
    expect(codexCaps.supportsWorkingDirectorySelection, isTrue);
    expect(codexCaps.supportsSkillsAndMcp, isTrue);

    final workCaps = resolveEffectiveCapabilities(
      transportCapabilities: const BackendCapabilities.stockCodexLocal(),
      mode: ProductMode.work,
    );
    expect(workCaps.supportsSandboxConfiguration, isFalse);
    expect(workCaps.supportsWorkingDirectorySelection, isTrue);
    expect(workCaps.supportsSkillsAndMcp, isTrue);

    final chatCaps = resolveEffectiveCapabilities(
      transportCapabilities: const BackendCapabilities.stockCodexLocal(),
      mode: ProductMode.chat,
    );
    expect(chatCaps.supportsSandboxConfiguration, isFalse);
    expect(chatCaps.supportsWorkingDirectorySelection, isFalse);
    expect(chatCaps.supportsSkillsAndMcp, isFalse);
    expect(chatCaps.supportsBranchNavigation, isTrue);
  });

  test('projects bounded int32 commandExecution exitCode onto HistoryItem and OutputDescriptor', () async {
    const nativeOut = {
      'available': true,
      'bytes': 16,
      'ref': 'fedcba9876543210fedcba9876543210',
      'storedBytes': 16,
      'truncated': false,
    };
    final exitAdapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async => {
        'data': [
          for (final (id, status, rawExit) in <(String, String, Object?)>[
            ('cmd-0', 'completed', 0),
            ('cmd-2', 'failed', 2),
            ('cmd-sig', 'failed', -9),
            ('cmd-declined', 'declined', null),
            ('cmd-overflow', 'failed', 0x100000000),
            ('cmd-bad-type', 'failed', '2'),
          ])
            {
              'turnId': 'turn-1',
              'item': {
                'id': id,
                'type': 'commandExecution',
                'command': 'echo $id',
                'status': status,
                'exitCode': rawExit,
                '_codexNativeOutput': nativeOut,
              },
            },
        ],
        'nextCursor': null,
      },
    );

    final page = await exitAdapter.listItems(
      const HistoryItemQuery(threadId: 'thread-1', turnId: 'turn-1'),
    );
    const expected = <int?>[0, 2, -9, null, null, null];
    expect(page.items.map((item) => item.exitCode).toList(), expected);
    expect(page.items.map((item) => item.output?.exitCode).toList(), expected);
  });
}

Map<String, Object?> _textBlock(String text) => {'type': 'text', 'text': text};

Map<String, Object?> _mcpTextEntry(
  String id,
  List<Object?> blocks, {
  bool deferred = false,
  Map<String, Object?> itemFields = const {},
  Map<String, Object?> resultFields = const {},
}) => {
  'turnId': 'turn-1',
  if (deferred) 'outputDeferred': true,
  'item': {
    'id': id,
    'type': 'mcpToolCall',
    'status': 'completed',
    'server': 'fixture',
    'tool': 'tool',
    'result': {'content': blocks, ...resultFields},
    ...itemFields,
  },
};

String _multiMegabyteOutput() {
  final kibibyte = List.filled(1024, 'x').join();
  return List.filled(3 * 1024, kibibyte).join();
}

JsonObject _occurrenceFixture({int start = 3, int end = 7}) => {
  'itemId': 'message-1',
  'turnId': 'turn-1',
  'turnCursor': 'opaque-turn-anchor',
  'snippet': '🧪 Find the marker.',
  'snippetMatchRange': {'start': start, 'end': end},
};
