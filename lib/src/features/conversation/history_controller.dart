import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/history_gateway.dart';
import '../../domain/history_models.dart';
import '../../domain/thread_models.dart';

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
  ThreadSummary? _thread;
  String? _turnCursor;
  String? _itemCursor;
  String? _selectedTurnId;
  String? _errorMessage;
  var _loadingTurns = false;
  var _loadingOlderTurns = false;
  var _loadingItems = false;
  var _turnDetailsLoadFailed = false;
  var _windowShifted = false;
  var _loadOlderVersion = 0;
  var _evictionVersion = 0;
  List<String> _lastEvictedItemIds = const [];
  var _generation = 0;
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
  int get evictionVersion => _evictionVersion;
  List<String> get lastEvictedItemIds => _lastEvictedItemIds;
  bool get canLoadMoreItems =>
      _itemCursor != null && _selectedTurnItems.length < maxRetainedItems;

  HistoryOccurrenceGateway? get _occurrenceGateway => switch (gateway) {
    final HistoryOccurrenceGateway search => search,
    _ => null,
  };

  bool get supportsOccurrenceSearch =>
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
    _occurrenceRequestInFlight = true;
    try {
      while (!_disposed) {
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
      _occurrenceRequestInFlight = false;
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
      _openingOccurrenceThreadId = null;
      _notify();
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

  Future<void> bindThread(ThreadSummary? thread) async {
    if (_thread?.id == thread?.id) {
      _thread = thread;
      return;
    }
    _generation += 1;
    _thread = thread;
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
    if (thread != null) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    final thread = _thread;
    if (thread == null || _loadingTurns) {
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
    _generation += 1;
    _resetOccurrenceSearch();
    super.dispose();
  }
}
