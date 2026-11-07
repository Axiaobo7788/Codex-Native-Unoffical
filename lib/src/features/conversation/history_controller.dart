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
  var _loadingItems = false;
  var _windowShifted = false;
  var _generation = 0;
  var _disposed = false;

  List<HistoryTurn> get turns => List.unmodifiable(_turns);
  String? get selectedTurnId => _selectedTurnId;
  String? get errorMessage => _errorMessage;
  bool get loadingTurns => _loadingTurns;
  bool get loadingItems => _loadingItems;
  bool get canLoadOlderTurns => _turnCursor != null;
  bool get canReturnToNewest => _windowShifted;
  bool get canLoadMoreItems =>
      _itemCursor != null && _selectedTurnItems.length < maxRetainedItems;

  HistoryTurn? turnForId(String turnId) {
    for (final turn in _turns) {
      if (turn.id == turnId) {
        return turn;
      }
    }
    return null;
  }

  bool isFirstNonUserItemInTurn(HistoryItem candidate) {
    final turn = turnForId(candidate.turnId);
    if (turn == null) {
      return false;
    }
    final source = turn.id == _selectedTurnId && _selectedTurnItems.isNotEmpty
        ? _selectedTurnItems
        : turn.items;
    for (final item in source) {
      if (item.kind != HistoryItemKind.user) {
        return item.id == candidate.id;
      }
    }
    return false;
  }

  void collapseTurnItems() {
    if (_selectedTurnId == null && _selectedTurnItems.isEmpty) {
      return;
    }
    _selectedTurnId = null;
    _selectedTurnItems.clear();
    _itemCursor = null;
    _notify();
  }

  List<HistoryItem> get timelineItems {
    final items = <HistoryItem>[];
    final seen = <String>{};
    for (final turn in _turns.reversed) {
      final source = turn.id == _selectedTurnId && _selectedTurnItems.isNotEmpty
          ? _selectedTurnItems
          : turn.items;
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
    _selectedTurnItems.clear();
    _turnCursor = null;
    _itemCursor = null;
    _selectedTurnId = null;
    _errorMessage = null;
    _loadingTurns = false;
    _loadingItems = false;
    _windowShifted = false;
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
    _loadingTurns = true;
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
      _selectedTurnItems.clear();
      _selectedTurnId = null;
      _itemCursor = null;
    } catch (error) {
      if (_isCurrent(thread.id, generation)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrent(thread.id, generation)) {
        _loadingTurns = false;
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
        !canLoadOlderTurns) {
      return;
    }
    final generation = _generation;
    _loadingTurns = true;
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
        _turns.removeRange(0, _turns.length - maxRetainedTurns);
        _windowShifted = true;
      }
      _turnCursor = page.nextCursor;
    } catch (error) {
      if (_isCurrent(thread.id, generation)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrent(thread.id, generation)) {
        _loadingTurns = false;
        _notify();
      }
    }
  }

  Future<void> loadTurnItems(String turnId) async {
    final thread = _thread;
    if (thread == null || _loadingItems) {
      return;
    }
    final generation = _generation;
    _selectedTurnId = turnId;
    _selectedTurnItems.clear();
    _itemCursor = null;
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
      if (!_isCurrent(thread.id, generation) || _selectedTurnId != turnId) {
        return;
      }
      _selectedTurnItems.addAll(page.items.take(maxRetainedItems));
      _itemCursor = page.nextCursor;
    } catch (error) {
      if (_isCurrent(thread.id, generation)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrent(thread.id, generation) && _selectedTurnId == turnId) {
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
    final generation = _generation;
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
      if (!_isCurrent(thread.id, generation) || _selectedTurnId != turnId) {
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
      if (_isCurrent(thread.id, generation)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrent(thread.id, generation) && _selectedTurnId == turnId) {
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
    final generation = _generation;
    _loadingItems = true;
    _errorMessage = null;
    _notify();
    try {
      final items = await gateway.readHistoryItems(
        threadId: thread.id,
        turnId: item.turnId,
        itemIds: [item.id],
      );
      if (!_isCurrent(thread.id, generation) ||
          _selectedTurnId != item.turnId) {
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
      if (_isCurrent(thread.id, generation)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrent(thread.id, generation) && _selectedTurnId == item.turnId) {
        _loadingItems = false;
        _notify();
      }
    }
  }

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
    super.dispose();
  }
}
