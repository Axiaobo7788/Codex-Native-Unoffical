import '../domain/history_models.dart';
import '../domain/thread_models.dart';
import '../domain/turn_models.dart';
import 'jsonl_decoder.dart';
import 'output_protocol.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';
import 'user_message_protocol.dart';

final class HistoryProtocolAdapter {
  static const _maxReviewDescriptionLength = 512;
  static const _maxOccurrenceSnippetLength = 2048;
  static const _maxOccurrenceTokenLength = 4096;
  static const _maxMcpTextBlocks = 64;
  static const _maxMcpTextBytes = 32 * 1024;
  static final _richMcpTextStart = RegExp(r'^[\s\uFEFF]*(?:\{|\[|```|~~~)');

  const HistoryProtocolAdapter({
    required this.request,
    this.maxTextCharacters = 8 * 1024,
    this.maxSummaryItemsPerTurn = 10,
  }) : assert(maxTextCharacters >= 256),
       assert(maxSummaryItemsPerTurn > 0);

  final ProtocolRequest request;
  final int maxTextCharacters;
  final int maxSummaryItemsPerTurn;

  Future<HistoryOccurrencePage> listOccurrences(
    HistoryOccurrenceQuery query,
  ) async {
    if (query.searchTerm.trim().isEmpty ||
        query.searchTerm.length > HistoryOccurrenceQuery.maxSearchTermLength) {
      throw ArgumentError('Saved history search requires a bounded query.');
    }
    final cursor = query.cursor;
    if (cursor != null) {
      _validateOccurrenceToken(cursor);
    }
    final response = await request('thread/searchOccurrences', {
      'threadId': query.threadId,
      'searchTerm': query.searchTerm,
      'limit': HistoryOccurrenceQuery.pageSize,
      'cursor': ?cursor,
    });
    final data = response['data'];
    if (data is! List<Object?> ||
        data.length > HistoryOccurrenceQuery.pageSize) {
      throw const ProtocolViolation('Invalid saved history result page.');
    }
    final nextCursor = _optionalString(response, 'nextCursor');
    if (nextCursor != null) {
      _validateOccurrenceToken(nextCursor);
      if (nextCursor == cursor || data.isEmpty) {
        throw const ProtocolViolation('Saved history cursor did not advance.');
      }
    }
    return HistoryOccurrencePage(
      occurrences: List.unmodifiable(data.map(_parseOccurrence)),
      nextCursor: nextCursor,
    );
  }

  HistoryOccurrence _parseOccurrence(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation('Saved history result must be an object.');
    }
    final snippet = _requiredString(value, 'snippet');
    final range = value['snippetMatchRange'];
    final start = range is Map<String, Object?> ? range['start'] : null;
    final end = range is Map<String, Object?> ? range['end'] : null;
    if (snippet.length > _maxOccurrenceSnippetLength ||
        start is! int ||
        end is! int ||
        start < 0 ||
        end <= start ||
        end > snippet.length ||
        _splitsSurrogatePair(snippet, start) ||
        _splitsSurrogatePair(snippet, end)) {
      throw const ProtocolViolation('Invalid saved history match range.');
    }
    return HistoryOccurrence(
      turnId: _validateOccurrenceToken(_requiredString(value, 'turnId')),
      itemId: _validateOccurrenceToken(_requiredString(value, 'itemId')),
      turnCursor: _validateOccurrenceToken(
        _requiredString(value, 'turnCursor'),
      ),
      snippet: snippet,
      matchStart: start,
      matchEnd: end,
    );
  }

  static String _validateOccurrenceToken(String token) {
    if (token.isEmpty || token.length > _maxOccurrenceTokenLength) {
      throw const ProtocolViolation('Invalid saved history identifier.');
    }
    return token;
  }

  static bool _splitsSurrogatePair(String text, int offset) {
    if (offset == 0 || offset == text.length) {
      return false;
    }
    final before = text.codeUnitAt(offset - 1);
    final after = text.codeUnitAt(offset);
    return before >= 0xd800 &&
        before <= 0xdbff &&
        after >= 0xdc00 &&
        after <= 0xdfff;
  }

  Future<HistoryTurnPage> listTurns(HistoryTurnQuery query) async {
    final response = await request('thread/turns/list', {
      'threadId': query.threadId,
      if (query.cursor != null) 'cursor': query.cursor,
      'limit': query.limit,
      'sortDirection': _sortDirection(query.sortDirection),
      'itemsView': 'summary',
    });
    final data = response['data'];
    if (data is! List<Object?> || data.length > query.limit) {
      throw const ProtocolViolation('Invalid thread/turns/list page.');
    }
    return HistoryTurnPage(
      turns: data.map(_parseTurn).toList(growable: false),
      nextCursor: _optionalString(response, 'nextCursor'),
    );
  }

  Future<HistoryItemPage> listItems(
    HistoryItemQuery query, {
    bool deferMcpText = false,
  }) async {
    final response = await request('thread/items/list', {
      'threadId': query.threadId,
      'turnId': query.turnId,
      if (query.cursor != null) 'cursor': query.cursor,
      'limit': query.limit,
      'sortDirection': _sortDirection(query.sortDirection),
      'deferOutput': {
        'commandExecution': true,
        if (deferMcpText) 'mcpToolCall': true,
      },
    });
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ProtocolViolation('thread/items/list data must be an array.');
    }
    return HistoryItemPage(
      items: data.map(_parseItemEntry).toList(growable: false),
      nextCursor: _optionalString(response, 'nextCursor'),
    );
  }

  Future<List<HistoryItem>> readItems({
    required String threadId,
    required String turnId,
    required List<String> itemIds,
  }) async => (await _readItemEntries(
    threadId,
    turnId,
    itemIds,
  )).map(_parseItemEntry).toList(growable: false);

  Future<List<Object?>> _readItemEntries(
    String threadId,
    String turnId,
    List<String> itemIds,
  ) async {
    if (itemIds.isEmpty || itemIds.length > 100) {
      throw RangeError('thread/items/read requires 1-100 item IDs.');
    }
    final response = await request('thread/items/read', {
      'threadId': threadId,
      'turnId': turnId,
      'itemIds': itemIds,
    });
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ProtocolViolation('thread/items/read data must be an array.');
    }
    return data;
  }

  Future<SavedMcpTextResult?> readSavedMcpText({
    required String threadId,
    required String turnId,
    required String itemId,
  }) async {
    const method = 'thread/items/read';
    final List<Object?> entries;
    try {
      entries = await _readItemEntries(threadId, turnId, [itemId]);
    } on JsonRpcException catch (error) {
      if (error.code == -32601 ||
          (error.code == -32600 &&
              (error.message == '$method requires experimentalApi capability' ||
                  error.message.startsWith(
                    'Invalid request: unknown variant `$method`',
                  )))) {
        throw UnsupportedError('Saved MCP text requires a compatible runtime.');
      }
      rethrow;
    }
    if (entries.isEmpty) {
      return null;
    }
    final entry = entries.first;
    final item = entry is JsonObject ? entry['item'] : null;
    if (entries.length != 1 ||
        entry is! JsonObject ||
        entry['turnId'] != turnId ||
        item is! JsonObject ||
        item['id'] != itemId ||
        item['type'] != 'mcpToolCall') {
      throw const ProtocolViolation(
        'Saved MCP read returned an unexpected item.',
      );
    }
    final blocks = _plainMcpTextBlocks(
      item,
      deferred: entry['outputDeferred'] == true,
    );
    if (blocks == null || blocks.isEmpty) {
      return null;
    }
    final buffer = StringBuffer();
    var bytes = 0;
    for (final block in blocks.cast<JsonObject>()) {
      final text = block['text'] as String;
      if (text.isEmpty) {
        continue;
      }
      if (bytes > 0) {
        if (bytes + 1 >= _maxMcpTextBytes) {
          return SavedMcpTextResult(buffer.toString(), truncated: true);
        }
        buffer.write('\n');
        bytes += 1;
      }
      for (final rune in text.runes) {
        bytes += switch (rune) {
          < 0x80 => 1,
          < 0x800 => 2,
          < 0x10000 => 3,
          _ => 4,
        };
        if (bytes > _maxMcpTextBytes) {
          return SavedMcpTextResult(buffer.toString(), truncated: true);
        }
        buffer.writeCharCode(rune);
      }
    }
    return SavedMcpTextResult(buffer.toString(), truncated: false);
  }

  // Match the supported stock plain-text subset. An empty list is a deferred
  // result marker. The history projection only keeps the eligibility boolean.
  List<Object?>? _plainMcpTextBlocks(
    JsonObject item, {
    required bool deferred,
  }) {
    final context = item['appContext'];
    final result = item['result'];
    if (item['status'] != 'completed' ||
        item['error'] != null ||
        item['server'] == 'codex_app' ||
        item['mcpAppResourceUri'] != null ||
        item['mcpAppUi'] != null ||
        (context is JsonObject && context['resourceUri'] != null) ||
        result is! JsonObject ||
        result['structuredContent'] != null ||
        result['_meta'] != null) {
      return null;
    }
    final blocks = result['content'];
    if (blocks is! List<Object?> || blocks.length > _maxMcpTextBlocks) {
      return null;
    }
    var hasText = false;
    for (final block in blocks) {
      if (block is! JsonObject ||
          block.length != 2 ||
          block['type'] != 'text') {
        return null;
      }
      final text = block['text'];
      if (text is! String || _richMcpTextStart.hasMatch(text)) {
        return null;
      }
      hasText |= text.isNotEmpty;
    }
    return hasText || (deferred && blocks.isEmpty) ? blocks : null;
  }

  HistoryTurn _parseTurn(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation('History turn must be an object.');
    }
    final turnId = _requiredString(value, 'id');
    final items = value['items'];
    if (items is! List<Object?>) {
      throw const ProtocolViolation('History turn items must be an array.');
    }
    return HistoryTurn(
      id: turnId,
      status: _turnStatus(_requiredString(value, 'status')),
      items: items
          .take(maxSummaryItemsPerTurn)
          .map((item) => _parseItem(item, turnId))
          .toList(growable: false),
      startedAt: _optionalTimestamp(value, 'startedAt'),
      completedAt: _optionalTimestamp(value, 'completedAt'),
    );
  }

  HistoryItem _parseItemEntry(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation('History item entry must be an object.');
    }
    return _parseItem(
      value['item'],
      _requiredString(value, 'turnId'),
      outputDeferred: value['outputDeferred'] == true,
    );
  }

  HistoryItem _parseItem(
    Object? value,
    String turnId, {
    bool outputDeferred = false,
  }) {
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation('History item must be an object.');
    }
    final id = _requiredString(value, 'id');
    final type = _requiredString(value, 'type');
    return switch (type) {
      'userMessage' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.user,
        text: parseStockUserText(
          value['content'],
          maxCharacters: maxTextCharacters,
        ),
        attachments: parseStockUserAttachments(value['content']),
      ),
      'agentMessage' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.assistant,
        text: _bounded(_optionalString(value, 'text') ?? ''),
      ),
      'reasoning' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.reasoning,
        text: _bounded(_stringList(value['summary']).join('\n')),
      ),
      'commandExecution' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.activity,
        text: _bounded(
          'Command: ${_optionalString(value, 'command') ?? 'command'}',
        ),
        status: _optionalString(value, 'status'),
        output: value['_codexNativeOutput'] == null
            ? null
            : OutputProtocolAdapter.descriptorFromItem(
                value['_codexNativeOutput'],
              ),
        // `outputDeferred` belongs to ThreadItemEntry, not the nested
        // commandExecution item. Keep the optional nested check for older
        // app-server builds that emitted the flag there.
        outputDeferred: outputDeferred || value['outputDeferred'] == true,
        isCommand: true,
      ),
      'fileChange' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.activity,
        text: _fileChangeSummary(value['changes']),
        status: _optionalString(value, 'status'),
      ),
      'mcpToolCall' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.activity,
        text: _bounded(
          'MCP: ${_optionalString(value, 'server') ?? 'mcp'}/'
          '${_optionalString(value, 'tool') ?? 'tool'}',
        ),
        status: _optionalString(value, 'status'),
        canReadMcpText:
            _plainMcpTextBlocks(value, deferred: outputDeferred) != null,
      ),
      'dynamicToolCall' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.activity,
        text: _bounded('Tool: ${_optionalString(value, 'tool') ?? 'tool'}'),
        status: _optionalString(value, 'status'),
      ),
      'collabAgentToolCall' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.activity,
        text: _bounded(
          'Collaboration: ${_optionalString(value, 'tool') ?? 'agent'}',
        ),
        status: _optionalString(value, 'status'),
      ),
      'webSearch' => () {
        final query = (_optionalString(value, 'query') ?? '').trim();
        return HistoryItem(
          id: id,
          turnId: turnId,
          kind: HistoryItemKind.activity,
          text: _bounded(query.isEmpty ? 'Web search' : 'Web search: $query'),
          status: _optionalString(value, 'status'),
        );
      }(),
      'plan' || 'todo' || 'todoList' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.activity,
        text: _bounded(_planSummary(value)),
        status: _optionalString(value, 'status'),
      ),
      'contextCompaction' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.activity,
        text: 'Context compacted',
        status: _optionalString(value, 'status'),
      ),
      'enteredReviewMode' || 'exitedReviewMode' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.review,
        text: _bounded(
          '${type == 'enteredReviewMode' ? 'Review started' : 'Review completed'}: '
          '${_truncate(_requiredString(value, 'review').trim(), _maxReviewDescriptionLength)}',
        ),
        status: 'completed',
      ),
      _ => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.unknown,
        text: _humanize(type),
        status: _optionalString(value, 'status'),
      ),
    };
  }

  static String _fileChangeSummary(Object? rawChanges) {
    final count = _listLength(rawChanges);
    final stats = _diffLineStats(rawChanges);
    if (stats.additions == 0 && stats.deletions == 0) {
      return 'File changes: $count update(s)';
    }
    return 'File changes: $count update(s) (+${stats.additions} -${stats.deletions})';
  }

  static ({int additions, int deletions}) _diffLineStats(Object? rawChanges) {
    if (rawChanges is! List<Object?>) {
      return (additions: 0, deletions: 0);
    }
    var additions = 0;
    var deletions = 0;
    for (final entry in rawChanges.whereType<Map<String, Object?>>()) {
      final entryAdditions = entry['additions'];
      final entryDeletions = entry['deletions'];
      if (entryAdditions is int && entryAdditions >= 0) {
        additions += entryAdditions;
      }
      if (entryDeletions is int && entryDeletions >= 0) {
        deletions += entryDeletions;
      }
      if (entryAdditions is! int && entryDeletions is! int) {
        final diff = entry['diff'];
        if (diff is String && diff.isNotEmpty) {
          for (final line in diff.split('\n')) {
            if (line.startsWith('+') && !line.startsWith('+++')) {
              additions += 1;
            } else if (line.startsWith('-') && !line.startsWith('---')) {
              deletions += 1;
            }
          }
        }
      }
    }
    return (additions: additions, deletions: deletions);
  }

  static String _planSummary(JsonObject value) {
    final text = (_optionalString(value, 'text') ?? '').trim();
    if (text.isNotEmpty) {
      final firstLine = text.split('\n').first.trim();
      return 'Plan: $firstLine';
    }
    final steps = value['steps'] ?? value['items'] ?? value['todos'];
    if (steps is List<Object?> && steps.isNotEmpty) {
      var hasCompletionState = false;
      var completedCount = 0;
      for (final step in steps.whereType<Map<String, Object?>>()) {
        if (step.containsKey('completed') || step.containsKey('status')) {
          hasCompletionState = true;
          final status = step['status'];
          if (step['completed'] == true ||
              (status is String && status.toLowerCase() == 'completed')) {
            completedCount += 1;
          }
        }
      }
      if (hasCompletionState) {
        return 'Plan updated ($completedCount/${steps.length} completed)';
      }
      return 'Plan updated (${steps.length} step(s))';
    }
    return 'Plan updated';
  }

  String _bounded(String value) => value.length <= maxTextCharacters
      ? value
      : '${value.substring(0, maxTextCharacters)}…';

  static String _truncate(String value, int limit) {
    if (value.length <= limit) {
      return value;
    }
    var end = limit;
    if (end > 0) {
      final lastUnit = value.codeUnitAt(end - 1);
      if (lastUnit >= 0xD800 && lastUnit <= 0xDBFF) {
        end -= 1;
      }
    }
    return '${value.substring(0, end)}…';
  }

  static List<String> _stringList(Object? value) =>
      value is List<Object?> ? value.whereType<String>().toList() : const [];

  static int _listLength(Object? value) =>
      value is List<Object?> ? value.length : 0;

  static String _requiredString(JsonObject object, String key) {
    final value = object[key];
    if (value is! String) {
      throw ProtocolViolation('History field $key must be a string.');
    }
    return value;
  }

  static String? _optionalString(JsonObject object, String key) {
    final value = object[key];
    return value is String ? value : null;
  }

  static DateTime? _optionalTimestamp(JsonObject object, String key) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! num) {
      throw ProtocolViolation('History field $key must be a timestamp.');
    }
    return DateTime.fromMillisecondsSinceEpoch(
      (value * Duration.millisecondsPerSecond).round(),
    );
  }

  static TurnRuntimeStatus _turnStatus(String value) => switch (value) {
    'inProgress' => TurnRuntimeStatus.inProgress,
    'completed' => TurnRuntimeStatus.completed,
    'interrupted' => TurnRuntimeStatus.interrupted,
    'failed' => TurnRuntimeStatus.failed,
    _ => TurnRuntimeStatus.unknown,
  };

  static String _sortDirection(SortDirection direction) => switch (direction) {
    SortDirection.ascending => 'asc',
    SortDirection.descending => 'desc',
  };

  static String _humanize(String value) {
    final spaced = value.replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    );
    return spaced.isEmpty
        ? 'Activity'
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}
