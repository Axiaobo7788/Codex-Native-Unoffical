import '../domain/history_models.dart';
import '../domain/thread_models.dart';
import '../domain/turn_models.dart';
import 'jsonl_decoder.dart';
import 'output_protocol.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';

final class HistoryProtocolAdapter {
  const HistoryProtocolAdapter({
    required this.request,
    this.maxTextCharacters = 8 * 1024,
    this.maxSummaryItemsPerTurn = 10,
  }) : assert(maxTextCharacters >= 256),
       assert(maxSummaryItemsPerTurn > 0);

  final ProtocolRequest request;
  final int maxTextCharacters;
  final int maxSummaryItemsPerTurn;

  Future<HistoryTurnPage> listTurns(HistoryTurnQuery query) async {
    final response = await request('thread/turns/list', {
      'threadId': query.threadId,
      if (query.cursor != null) 'cursor': query.cursor,
      'limit': query.limit,
      'sortDirection': _sortDirection(query.sortDirection),
      'itemsView': 'summary',
    });
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ProtocolViolation('thread/turns/list data must be an array.');
    }
    return HistoryTurnPage(
      turns: data.map(_parseTurn).toList(growable: false),
      nextCursor: _optionalString(response, 'nextCursor'),
    );
  }

  Future<HistoryItemPage> listItems(HistoryItemQuery query) async {
    final response = await request('thread/items/list', {
      'threadId': query.threadId,
      'turnId': query.turnId,
      if (query.cursor != null) 'cursor': query.cursor,
      'limit': query.limit,
      'sortDirection': _sortDirection(query.sortDirection),
      'deferOutput': const {'commandExecution': true},
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
  }) async {
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
    return data.map(_parseItemEntry).toList(growable: false);
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
    return _parseItem(value['item'], _requiredString(value, 'turnId'));
  }

  HistoryItem _parseItem(Object? value, String turnId) {
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
        text: _bounded(_userText(value['content'])),
        attachments: _userAttachments(value['content']),
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
        outputDeferred: value['outputDeferred'] == true,
        isCommand: true,
      ),
      'fileChange' => HistoryItem(
        id: id,
        turnId: turnId,
        kind: HistoryItemKind.activity,
        text: 'File changes: ${_listLength(value['changes'])} update(s)',
        status: _optionalString(value, 'status'),
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

  String _userText(Object? content) {
    if (content is! List<Object?>) {
      return 'User message';
    }
    return content
        .whereType<Map<String, Object?>>()
        .where((part) => part['type'] == 'text')
        .map((part) => part['text'])
        .whereType<String>()
        .join('\n');
  }

  static List<UserAttachment> _userAttachments(Object? content) {
    if (content is! List<Object?>) {
      return const [];
    }
    final attachments = <UserAttachment>[];
    for (final part in content.whereType<Map<String, Object?>>()) {
      if (attachments.length >= maxUserAttachments) {
        break;
      }
      final type = part['type'];
      switch (type) {
        case 'localImage':
          final path = _optionalString(part, 'path') ?? '';
          attachments.add(
            UserAttachment(
              kind: UserAttachmentKind.image,
              label: path.isEmpty ? 'Local image' : _shortPath(path),
              path: path.isEmpty ? null : path,
            ),
          );
        case 'image':
          final url = _optionalString(part, 'url');
          attachments.add(
            UserAttachment(
              kind: UserAttachmentKind.image,
              label: 'Image',
              path: url,
            ),
          );
        case 'file':
          final path = _optionalString(part, 'path') ?? '';
          final name = _optionalString(part, 'name') ?? '';
          attachments.add(
            UserAttachment(
              kind: UserAttachmentKind.file,
              label: name.isNotEmpty
                  ? name
                  : (path.isEmpty ? 'File' : _shortPath(path)),
              path: path.isEmpty ? null : path,
            ),
          );
        case 'skill':
          final name = _optionalString(part, 'name') ?? 'Skill';
          final path = _optionalString(part, 'path');
          attachments.add(
            UserAttachment(
              kind: UserAttachmentKind.skill,
              label: name,
              path: path,
            ),
          );
        case 'mention':
          final name = _optionalString(part, 'name') ?? 'Mention';
          final path = _optionalString(part, 'path');
          attachments.add(
            UserAttachment(
              kind: UserAttachmentKind.mention,
              label: name,
              path: path,
            ),
          );
      }
    }
    return attachments.isEmpty ? const [] : List.unmodifiable(attachments);
  }

  static String _shortPath(String path) {
    final normalized = path.trim().replaceAll(r'\', '/');
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return segments.isEmpty ? normalized : segments.last;
  }

  String _bounded(String value) => value.length <= maxTextCharacters
      ? value
      : '${value.substring(0, maxTextCharacters)}…';

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
