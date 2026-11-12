import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/file_change_models.dart';
import '../../domain/history_gateway.dart';
import '../../domain/history_models.dart';
import '../../domain/thread_models.dart';

typedef _FilePreviewKey = ({
  String turnId,
  String itemId,
  int index,
  String path,
  String? movePath,
  FileChangeKind kind,
  Object revision,
});

class HistoryController extends ChangeNotifier {
  HistoryController({
    required this.gateway,
    this.turnPageSize = 20,
    this.itemPageSize = 25,
    this.maxRetainedTurns = 100,
    this.maxRetainedItems = 100,
  }) : assert(turnPageSize > 0 && turnPageSize <= 50),
       assert(itemPageSize > 0 && itemPageSize <= 50),
       assert(maxRetainedTurns >= turnPageSize),
       assert(maxRetainedItems >= itemPageSize);

  final HistoryGateway gateway;
  final int turnPageSize;
  final int itemPageSize;
  final int maxRetainedTurns;
  final int maxRetainedItems;
  final List<HistoryTurn> _turns = [];
  final List<HistoryItem> _selectedTurnItems = [];
  static const maxFilePreviews = 4;
  final _filePreviews = <_FilePreviewKey, FileChangePreview>{};
  final _filePreviewReads = <_FilePreviewKey, Completer<FileChangePreview?>>{};
  var _filePreviewSlots = 0;

  ThreadSummary? _thread;
  var _knownUnmaterialized = false;
  String? _turnCursor;
  String? _itemCursor;
  String? _selectedTurnId;
  String? _errorMessage;
  var _loadingTurns = false;
  var _loadingOlderTurns = false;
  var _loadingItems = false;
  var _turnDetailsLoadFailed = false;
  var _readingSavedMcpText = false;
  var _windowShifted = false;
  var _loadOlderVersion = 0;
  var _evictionVersion = 0;
  List<String> _lastEvictedItemIds = const [];
  var _generation = 0;
  var _runtimeRevision = 0;
  var _refreshVersion = 0;
  var _itemGeneration = 0;
  var _turnWindowRevision = 0;
  var _disposed = false;
  HistoryOccurrenceQuery? _occurrenceRequest;
  HistoryOccurrenceQuery? _pendingOccurrenceRequest;
  HistoryOccurrencePage? _occurrencePage;
  String? _occurrenceError;
  String? _openingOccurrenceThreadId;
  var _occurrenceRequestInFlight = false;
  var _occurrenceLoading = false;
  var _occurrenceUnsupported = false;

  List<HistoryTurn> get turns => List.unmodifiable(_turns);
  String? get selectedTurnId => _selectedTurnId;
  String? get errorMessage => _errorMessage;
  bool get loadingTurns => _loadingTurns;
  bool get loadingOlderTurns => _loadingOlderTurns;
  bool get loadingItems => _loadingItems;
  bool get selectedTurnDetailsLoadFailed => _turnDetailsLoadFailed;
  bool get canLoadOlderTurns => _turnCursor != null;
  bool get canReturnToNewest => _windowShifted;
  int get loadOlderVersion => _loadOlderVersion;

  /// Client publication counter for an accepted newest-page read, not stock
  /// revision metadata. Failed/stale reads never advance it.
  int get refreshVersion => _refreshVersion;
  int get evictionVersion => _evictionVersion;
  List<String> get lastEvictedItemIds => _lastEvictedItemIds;
  bool get canLoadMoreItems =>
      _itemCursor != null && _selectedTurnItems.length < maxRetainedItems;

  HistoryOccurrenceGateway? get _occurrenceGateway => switch (gateway) {
    final HistoryOccurrenceGateway search => search,
    _ => null,
  };

  bool get supportsOccurrenceSearch =>
      !_knownUnmaterialized &&
      _thread?.ephemeral == false &&
      (_occurrenceGateway?.supportsHistoryOccurrences ?? false);
  bool get occurrenceUnsupported => _occurrenceUnsupported;
  bool get occurrenceLoading => _occurrenceLoading;
  bool get openingOccurrence =>
      _openingOccurrenceThreadId != null &&
      _openingOccurrenceThreadId == _thread?.id;
  bool get canOpenOccurrence =>
      _openingOccurrenceThreadId == null &&
      !_loadingTurns &&
      !_occurrenceLoading;
  HistoryOccurrencePage? get occurrencePage => _occurrencePage;
  String? get occurrenceError => _occurrenceError;

  void searchOccurrences(String searchTerm) {
    final thread = _thread;
    final term = searchTerm.trim();
    if (thread == null ||
        !supportsOccurrenceSearch ||
        _occurrenceUnsupported ||
        term.isEmpty ||
        term.length > HistoryOccurrenceQuery.maxSearchTermLength) {
      return;
    }
    if (_occurrenceLoading &&
        _occurrenceRequest?.searchTerm == term &&
        _occurrenceRequest?.cursor == null) {
      return;
    }
    _occurrencePage = null;
    _queueOccurrenceSearch(
      HistoryOccurrenceQuery(threadId: thread.id, searchTerm: term),
    );
  }

  void loadMoreOccurrences() {
    final query = _occurrenceRequest;
    final cursor = _occurrencePage?.nextCursor;
    if (query == null ||
        cursor == null ||
        _occurrenceLoading ||
        openingOccurrence ||
        !supportsOccurrenceSearch) {
      return;
    }
    _queueOccurrenceSearch(
      HistoryOccurrenceQuery(
        threadId: query.threadId,
        searchTerm: query.searchTerm,
        cursor: cursor,
      ),
    );
  }

  void clearOccurrenceSearch() {
    if (_occurrenceRequest == null) {
      return;
    }
    _resetOccurrenceSearch();
    _notify();
  }

  void _resetOccurrenceSearch() {
    _occurrenceRequest = null;
    _pendingOccurrenceRequest = null;
    _occurrencePage = null;
    _occurrenceError = null;
    _occurrenceLoading = false;
  }

  void _queueOccurrenceSearch(HistoryOccurrenceQuery query) {
    _occurrenceRequest = query;
    _pendingOccurrenceRequest = query;
    _occurrenceError = null;
    _occurrenceLoading = true;
    _notify();
    unawaited(_drainOccurrenceSearch());
  }

  Future<void> _drainOccurrenceSearch() async {
    if (_occurrenceRequestInFlight) {
      return;
    }
    final runtime = _runtimeRevision;
    _occurrenceRequestInFlight = true;
    try {
      while (!_disposed && runtime == _runtimeRevision) {
        final query = _pendingOccurrenceRequest;
        if (query == null) {
          break;
        }
        _pendingOccurrenceRequest = null;
        try {
          final page = await _occurrenceGateway!.listHistoryOccurrences(query);
          if (identical(query, _occurrenceRequest)) {
            _occurrencePage = page;
          }
        } on UnsupportedError {
          if (identical(query, _occurrenceRequest)) {
            _occurrenceUnsupported = true;
            _occurrencePage = null;
          }
        } catch (_) {
          if (identical(query, _occurrenceRequest)) {
            _occurrenceError = 'Could not search saved messages. Try again.';
          }
        } finally {
          if (identical(query, _occurrenceRequest)) {
            _occurrenceLoading = false;
            _notify();
          }
        }
      }
    } finally {
      if (runtime == _runtimeRevision) _occurrenceRequestInFlight = false;
    }
  }

  Future<HistoryTurn?> openOccurrence(HistoryOccurrence occurrence) async {
    final thread = _thread;
    final query = _occurrenceRequest;
    if (thread == null ||
        query == null ||
        !canOpenOccurrence ||
        !(_occurrencePage?.occurrences.contains(occurrence) ?? false)) {
      return null;
    }
    final generation = _generation;
    final revision = _turnWindowRevision;
    final runtime = _runtimeRevision;
    bool stillRequested() =>
        _isCurrent(thread.id, generation) &&
        identical(query, _occurrenceRequest) &&
        revision == _turnWindowRevision;
    _openingOccurrenceThreadId = thread.id;
    _occurrenceError = null;
    _notify();
    try {
      final page = await gateway.listHistoryTurns(
        HistoryTurnQuery(
          threadId: thread.id,
          cursor: occurrence.turnCursor,
          limit: turnPageSize,
        ),
      );
      if (!stillRequested()) {
        return null;
      }
      final target = page.turns.firstOrNull;
      if (target == null ||
          target.id != occurrence.turnId ||
          !target.items.any(
            (item) =>
                item.kind == HistoryItemKind.user ||
                item.kind == HistoryItemKind.assistant,
          )) {
        _occurrenceError = 'This match is no longer available. Search again.';
        return null;
      }
      _turns
        ..clear()
        ..addAll(page.turns.take(turnPageSize));
      _clearSelectedItems();
      _turnCursor = page.nextCursor;
      _windowShifted = true;
      _lastEvictedItemIds = const [];
      _errorMessage = null;
      return target;
    } catch (_) {
      if (stillRequested()) {
        _occurrenceError = 'Could not open this match. Search again.';
      }
      return null;
    } finally {
      if (runtime == _runtimeRevision) {
        _openingOccurrenceThreadId = null;
        _notify();
      }
    }
  }

  HistoryTurn? turnForId(String turnId) {
    for (final turn in _turns) {
      if (turn.id == turnId) {
        return turn;
      }
    }
    return null;
  }

  List<HistoryItem> _itemsForTurn(HistoryTurn turn) =>
      turn.id == _selectedTurnId && _selectedTurnItems.isNotEmpty
      ? _selectedTurnItems
      : turn.items;

  bool isTurnDetailsAnchor(HistoryItem candidate) {
    final turn = turnForId(candidate.turnId);
    if (turn == null) {
      return false;
    }
    final source = _itemsForTurn(turn);
    for (final item in source) {
      if (item.kind != HistoryItemKind.user) {
        return item.id == candidate.id;
      }
    }
    return source.isNotEmpty && source.last.id == candidate.id;
  }

  void collapseTurnItems() {
    if (_selectedTurnId == null && _selectedTurnItems.isEmpty) {
      return;
    }
    _clearSelectedItems();
    _notify();
  }

  List<HistoryItem> get timelineItems {
    final items = <HistoryItem>[];
    final seen = <String>{};
    for (final turn in _turns.reversed) {
      final source = _itemsForTurn(turn);
      for (final item in source) {
        if (seen.add(item.id)) {
          items.add(item);
        }
      }
    }
    return List.unmodifiable(items);
  }

  HistoryFileChangeGateway? get _fileGateway => switch (gateway) {
    final HistoryFileChangeGateway local => local,
    _ => null,
  };

  bool get supportsFileChangePreviews =>
      !_disposed && (_fileGateway?.supportsFileChangePreviews ?? false);

  _FilePreviewKey _fileKey(
    String turnId,
    String itemId,
    FileChangeEntry file,
  ) => (
    turnId: turnId,
    itemId: itemId,
    index: file.index,
    path: file.path,
    movePath: file.movePath,
    kind: file.kind,
    revision: file.diff?.reference ?? file,
  );

  FileChangePreview? fileChangePreviewFor({
    required String turnId,
    required String itemId,
    required FileChangeEntry file,
  }) => _filePreviews[_fileKey(turnId, itemId, file)];

  bool isReadingFileChangePreview({
    required String turnId,
    required String itemId,
    required FileChangeEntry file,
  }) => _filePreviewReads.containsKey(_fileKey(turnId, itemId, file));

  Future<FileChangePreview?> readFileChangePreview({
    required String turnId,
    required String itemId,
    required FileChangeEntry file,
  }) async {
    final threadId = _thread?.id;
    if (_disposed || threadId == null) return null;
    if (file.kind == FileChangeKind.unknown || file.pathTruncated) {
      return FileChangePreview(
        file: file,
        lines: const [],
        truncated: false,
        status: FileChangePreviewStatus.unsupported,
      );
    }
    if (file.isEmpty) {
      return FileChangePreview(file: file, lines: const [], truncated: false);
    }
    final local = _fileGateway;
    if (local == null || !supportsFileChangePreviews) {
      return FileChangePreview(
        file: file,
        lines: const [],
        truncated: false,
        status: FileChangePreviewStatus.unavailable,
      );
    }
    final key = _fileKey(turnId, itemId, file);
    final cached = _filePreviews.remove(key);
    if (cached != null) {
      _filePreviews[key] = cached;
      return cached;
    }
    final pending = _filePreviewReads[key];
    if (pending != null) return pending.future;
    // Count physical requests, including released readers awaiting retirement.
    if (_filePreviewSlots >= maxFilePreviews) {
      return FileChangePreview(
        file: file,
        lines: const [],
        truncated: false,
        status: FileChangePreviewStatus.unavailable,
      );
    }
    final completion = Completer<FileChangePreview?>();
    completion.future.ignore();
    _filePreviewReads[key] = completion;
    _filePreviewSlots++;
    final generation = _generation;
    _notify();
    unawaited(() async {
      try {
        final result = await local.readFileChangePreview(
          threadId: threadId,
          turnId: turnId,
          itemId: itemId,
          file: file,
        );
        if (!completion.isCompleted) {
          if (_isCurrent(threadId, generation) &&
              identical(_filePreviewReads[key], completion)) {
            if (result != null) _rememberFilePreview(key, result);
            completion.complete(result);
          } else {
            completion.complete(null);
          }
        }
      } on Object catch (error) {
        if (!completion.isCompleted) {
          if (_isCurrent(threadId, generation) &&
              identical(_filePreviewReads[key], completion)) {
            final result = FileChangePreview(
              file: file,
              lines: const [],
              truncated: false,
              status: error is UnsupportedError
                  ? FileChangePreviewStatus.unsupported
                  : FileChangePreviewStatus.unavailable,
            );
            _rememberFilePreview(key, result);
            completion.complete(result);
          } else {
            completion.complete(null);
          }
        }
      } finally {
        if (identical(_filePreviewReads[key], completion)) {
          _filePreviewReads.remove(key);
        }
        _filePreviewSlots--;
        if (_isCurrent(threadId, generation)) _notify();
      }
    }());
    return completion.future;
  }

  void _rememberFilePreview(_FilePreviewKey key, FileChangePreview preview) {
    _filePreviews.remove(key);
    _filePreviews[key] = preview;
    while (_filePreviews.length > maxFilePreviews) {
      _filePreviews.remove(_filePreviews.keys.first);
    }
  }

  void releaseFileChangePreview({
    required String turnId,
    required String itemId,
    required FileChangeEntry file,
  }) {
    final key = _fileKey(turnId, itemId, file);
    _filePreviews.remove(key);
    final pending = _filePreviewReads.remove(key);
    if (pending != null && !pending.isCompleted) pending.complete(null);
  }

  void clearFileChangePreviews() {
    _filePreviews.clear();
    final pending = _filePreviewReads.values.toList(growable: false);
    _filePreviewReads.clear();
    for (final completion in pending) {
      if (!completion.isCompleted) completion.complete(null);
    }
  }

  Future<void> bindThread(
    ThreadSummary? thread, {
    bool knownUnmaterialized = false,
    bool force = false,
  }) async {
    final deferHistory = thread != null && knownUnmaterialized;
    if (!force &&
        _thread?.id == thread?.id &&
        _knownUnmaterialized == deferHistory) {
      _thread = thread;
      return;
    }
    _generation += 1;
    _thread = thread;
    clearFileChangePreviews();
    _knownUnmaterialized = deferHistory;
    _turns.clear();
    _clearSelectedItems();
    _resetOccurrenceSearch();
    _occurrenceUnsupported = false;
    _turnCursor = null;
    _errorMessage = null;
    _loadingTurns = false;
    _loadingOlderTurns = false;
    _windowShifted = false;
    _lastEvictedItemIds = const [];
    _notify();
    if (thread != null && !_knownUnmaterialized) {
      await refresh();
    }
  }

  /// Keep the bounded last-known turn window while retiring old loads and
  /// Host references. Recovery explicitly calls [bindThread] with `force: true`.
  void invalidateRuntime() {
    clearFileChangePreviews();
    _runtimeRevision += 1;
    _generation += 1;
    _turnWindowRevision += 1;
    _clearSelectedItems();
    _resetOccurrenceSearch();
    _occurrenceRequestInFlight = false;
    _openingOccurrenceThreadId = null;
    _readingSavedMcpText = false;
    _loadingTurns = false;
    _loadingOlderTurns = false;
    _turnCursor = null;
    _errorMessage = null;
    for (var i = 0; i < _turns.length; i += 1) {
      final turn = _turns[i];
      _turns[i] = HistoryTurn(
        id: turn.id,
        status: turn.status,
        startedAt: turn.startedAt,
        completedAt: turn.completedAt,
        reportedWorkDuration: turn.reportedWorkDuration,
        items: [
          for (final item in turn.items)
            HistoryItem(
              id: item.id,
              turnId: item.turnId,
              kind: item.kind,
              text: item.text,
              status: item.status,
              exitCode: item.exitCode,
              output: item.output?.withoutSessionReference(),
              fileChanges: item.fileChanges?.withoutSessionReferences(),
              outputDeferred: item.outputDeferred,
              isCommand: item.isCommand,
              commandAction: item.commandAction,
              canReadMcpText: item.canReadMcpText,
              reasoningParts: item.reasoningParts,
              attachments: item.attachments,
            ),
        ],
      );
    }
    _notify();
  }

  Future<void> refresh() async {
    final thread = _thread;
    if (thread == null || _knownUnmaterialized || _loadingTurns) {
      return;
    }
    final generation = _generation;
    _turnWindowRevision += 1;
    _loadingTurns = true;
    _loadingOlderTurns = false;
    _errorMessage = null;
    _notify();
    try {
      final page = await gateway.listHistoryTurns(
        HistoryTurnQuery(threadId: thread.id, limit: turnPageSize),
      );
      if (!_isCurrent(thread.id, generation)) {
        return;
      }
      _turns
        ..clear()
        ..addAll(page.turns.take(maxRetainedTurns));
      _turnCursor = page.nextCursor;
      _windowShifted = false;
      _lastEvictedItemIds = const [];
      _clearSelectedItems();
      _refreshVersion += 1;
    } catch (error) {
      if (_isCurrent(thread.id, generation)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrent(thread.id, generation)) {
        _loadingTurns = false;
        _loadingOlderTurns = false;
        _notify();
      }
    }
  }

  Future<void> loadOlderTurns() async {
    final thread = _thread;
    final cursor = _turnCursor;
    if (thread == null ||
        cursor == null ||
        _loadingTurns ||
        _openingOccurrenceThreadId == thread.id ||
        !canLoadOlderTurns) {
      return;
    }
    final generation = _generation;
    _turnWindowRevision += 1;
    _loadingTurns = true;
    _loadingOlderTurns = true;
    _notify();
    try {
      final page = await gateway.listHistoryTurns(
        HistoryTurnQuery(
          threadId: thread.id,
          cursor: cursor,
          limit: turnPageSize,
        ),
      );
      if (!_isCurrent(thread.id, generation)) {
        return;
      }
      final known = _turns.map((turn) => turn.id).toSet();
      _turns.addAll(page.turns.where((turn) => known.add(turn.id)));
      if (_turns.length > maxRetainedTurns) {
        final removeCount = _turns.length - maxRetainedTurns;
        final evictedTurns = _turns.sublist(0, removeCount);
        final evictedIds = <String>[];
        final seenIds = <String>{};
        for (final turn in evictedTurns.reversed) {
          for (final item in _itemsForTurn(turn)) {
            if (seenIds.add(item.id)) {
              evictedIds.add(item.id);
            }
          }
        }
        _lastEvictedItemIds = List.unmodifiable(evictedIds);
        if (evictedTurns.any((turn) => turn.id == _selectedTurnId)) {
          _clearSelectedItems();
        }
        _turns.removeRange(0, removeCount);
        _windowShifted = true;
        _evictionVersion += 1;
      } else {
        _lastEvictedItemIds = const [];
      }
      _turnCursor = page.nextCursor;
      _loadOlderVersion += 1;
    } catch (error) {
      if (_isCurrent(thread.id, generation)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrent(thread.id, generation)) {
        _loadingTurns = false;
        _loadingOlderTurns = false;
        _notify();
      }
    }
  }

  Future<void> loadTurnItems(String turnId) async {
    final thread = _thread;
    if (thread == null || _loadingItems) {
      return;
    }
    final itemGeneration = ++_itemGeneration;
    _selectedTurnId = turnId;
    _selectedTurnItems.clear();
    _itemCursor = null;
    _turnDetailsLoadFailed = false;
    _loadingItems = true;
    _errorMessage = null;
    _notify();
    try {
      final page = await gateway.listHistoryItems(
        HistoryItemQuery(
          threadId: thread.id,
          turnId: turnId,
          limit: itemPageSize,
        ),
      );
      if (!_isCurrentItemLoad(turnId, itemGeneration)) {
        return;
      }
      _selectedTurnItems.addAll(page.items.take(maxRetainedItems));
      _itemCursor = page.nextCursor;
    } catch (error) {
      if (_isCurrentItemLoad(turnId, itemGeneration)) {
        _turnDetailsLoadFailed = true;
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrentItemLoad(turnId, itemGeneration)) {
        _loadingItems = false;
        _notify();
      }
    }
  }

  Future<void> loadMoreItems() async {
    final thread = _thread;
    final turnId = _selectedTurnId;
    final cursor = _itemCursor;
    if (thread == null ||
        turnId == null ||
        cursor == null ||
        _loadingItems ||
        !canLoadMoreItems) {
      return;
    }
    final itemGeneration = _itemGeneration;
    _loadingItems = true;
    _notify();
    try {
      final page = await gateway.listHistoryItems(
        HistoryItemQuery(
          threadId: thread.id,
          turnId: turnId,
          cursor: cursor,
          limit: itemPageSize,
        ),
      );
      if (!_isCurrentItemLoad(turnId, itemGeneration)) {
        return;
      }
      final known = _selectedTurnItems.map((item) => item.id).toSet();
      _selectedTurnItems.addAll(
        page.items
            .where((item) => known.add(item.id))
            .take(maxRetainedItems - _selectedTurnItems.length),
      );
      _itemCursor = page.nextCursor;
    } catch (error) {
      if (_isCurrentItemLoad(turnId, itemGeneration)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrentItemLoad(turnId, itemGeneration)) {
        _loadingItems = false;
        _notify();
      }
    }
  }

  Future<void> loadDeferredOutput(HistoryItem item) async {
    final thread = _thread;
    if (thread == null ||
        _loadingItems ||
        !item.outputDeferred ||
        item.turnId != _selectedTurnId) {
      return;
    }
    final itemGeneration = _itemGeneration;
    _loadingItems = true;
    _errorMessage = null;
    _notify();
    try {
      final items = await gateway.readHistoryItems(
        threadId: thread.id,
        turnId: item.turnId,
        itemIds: [item.id],
      );
      if (!_isCurrentItemLoad(item.turnId, itemGeneration)) {
        return;
      }
      final replacement = items.where((candidate) => candidate.id == item.id);
      if (replacement.length != 1) {
        throw StateError(
          'thread/items/read did not return the requested item.',
        );
      }
      final index = _selectedTurnItems.indexWhere(
        (candidate) => candidate.id == item.id,
      );
      if (index < 0) {
        throw StateError(
          'The deferred item is no longer in the active window.',
        );
      }
      _selectedTurnItems[index] = replacement.single;
    } catch (error) {
      if (_isCurrentItemLoad(item.turnId, itemGeneration)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrentItemLoad(item.turnId, itemGeneration)) {
        _loadingItems = false;
        _notify();
      }
    }
  }

  HistoryMcpTextGateway? get _mcpTextGateway => switch (gateway) {
    final HistoryMcpTextGateway local => local,
    _ => null,
  };

  bool canReadSavedMcpText(HistoryItem item) =>
      !_disposed &&
      item.canReadMcpText &&
      _thread?.ephemeral == false &&
      _selectedTurnId == item.turnId &&
      (_mcpTextGateway?.supportsSavedMcpText ?? false) &&
      _selectedTurnItems.contains(item);

  Future<SavedMcpTextResult?> loadSavedMcpText(HistoryItem item) async {
    final local = _mcpTextGateway;
    final thread = _thread;
    if (local == null || thread == null || !canReadSavedMcpText(item)) {
      return null;
    }
    if (_readingSavedMcpText) {
      throw StateError('A saved MCP read is already in progress.');
    }
    final itemGeneration = _itemGeneration;
    final runtime = _runtimeRevision;
    _readingSavedMcpText = true;
    try {
      final result = await local.readSavedMcpText(
        threadId: thread.id,
        turnId: item.turnId,
        itemId: item.id,
      );
      return _isCurrentItemLoad(item.turnId, itemGeneration) ? result : null;
    } catch (_) {
      if (_isCurrentItemLoad(item.turnId, itemGeneration)) {
        rethrow;
      }
      return null;
    } finally {
      if (runtime == _runtimeRevision) _readingSavedMcpText = false;
    }
  }

  void _clearSelectedItems() {
    _itemGeneration += 1;
    _selectedTurnId = null;
    _selectedTurnItems.clear();
    _itemCursor = null;
    _turnDetailsLoadFailed = false;
    _loadingItems = false;
  }

  bool _isCurrentItemLoad(String turnId, int itemGeneration) =>
      !_disposed &&
      _selectedTurnId == turnId &&
      _itemGeneration == itemGeneration;

  bool _isCurrent(String threadId, int generation) =>
      !_disposed && _thread?.id == threadId && _generation == generation;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    clearFileChangePreviews();
    _generation += 1;
    _resetOccurrenceSearch();
    super.dispose();
  }
}
