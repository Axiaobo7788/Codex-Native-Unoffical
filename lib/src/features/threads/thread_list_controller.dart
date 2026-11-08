import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/thread_gateway.dart';
import '../../domain/thread_models.dart';

class ThreadListController extends ChangeNotifier {
  ThreadListController({
    required this.gateway,
    this.pageSize = 25,
    this.maxRetainedThreads = 100,
  }) : assert(pageSize > 0 && pageSize <= 100),
       assert(maxRetainedThreads >= pageSize) {
    _threadEventSubscription = gateway.threadEvents.listen(
      _handleThreadEvent,
      onError: (Object error, StackTrace _) {
        if (!_disposed) {
          _errorMessage = error.toString();
          _notify();
        }
      },
    );
  }

  static const maxPinnedThreads = 32;

  final ThreadGateway gateway;
  final int pageSize;
  final int maxRetainedThreads;
  final List<ThreadSummary> _threads = [];
  final Set<String> _unmaterializedThreadIds = {};
  final Set<String> _pinnedThreadIds = {};
  StreamSubscription<ThreadLifecycleEvent>? _threadEventSubscription;
  String? _nextCursor;
  ThreadSummary? _selectedThread;
  String? _errorMessage;
  String? _lastRevertedThreadId;
  var _revertVersion = 0;
  var _showArchived = false;
  var _initialLoadStarted = false;
  var _loading = false;
  var _loadingMore = false;
  var _mutating = false;
  var _disposed = false;

  List<ThreadSummary> get threads => List.unmodifiable(_threads);
  Set<String> get pinnedThreadIds => Set.unmodifiable(_pinnedThreadIds);
  ThreadSummary? get selectedThread => _selectedThread;
  String? get errorMessage => _errorMessage;
  String? get lastRevertedThreadId => _lastRevertedThreadId;
  int get revertVersion => _revertVersion;
  bool get showArchived => _showArchived;
  bool get initialLoadStarted => _initialLoadStarted;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get mutating => _mutating;
  bool get canLoadMore =>
      _nextCursor != null && _threads.length < maxRetainedThreads;
  bool get retentionLimitReached =>
      _nextCursor != null && _threads.length >= maxRetainedThreads;

  bool isPinned(String threadId) => _pinnedThreadIds.contains(threadId);
  bool isMaterialized(String threadId) =>
      !_unmaterializedThreadIds.contains(threadId);

  void togglePinThread(String threadId) {
    if (_pinnedThreadIds.contains(threadId)) {
      _pinnedThreadIds.remove(threadId);
    } else {
      if (_pinnedThreadIds.length >= maxPinnedThreads) {
        _pinnedThreadIds.remove(_pinnedThreadIds.first);
      }
      _pinnedThreadIds.add(threadId);
    }
    _notify();
  }

  Future<void> setShowArchived(bool value) async {
    if (_showArchived == value) {
      return;
    }
    _showArchived = value;
    _selectedThread = null;
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading || _mutating) {
      return;
    }
    _initialLoadStarted = true;
    _loading = true;
    _errorMessage = null;
    _notify();
    try {
      final page = await gateway.listThreads(
        ThreadListQuery(limit: pageSize, archived: _showArchived),
      );
      if (_disposed) {
        return;
      }
      final seenIds = <String>{};
      final uniqueThreads = <ThreadSummary>[];
      var hadDuplicates = false;
      for (final thread in page.threads) {
        if (seenIds.add(thread.id)) {
          if (uniqueThreads.length < maxRetainedThreads) {
            uniqueThreads.add(thread);
          }
        } else {
          hadDuplicates = true;
        }
      }
      var cursor = page.nextCursor;
      var extraPages = 0;
      while (hadDuplicates &&
          extraPages < 2 &&
          cursor != null &&
          uniqueThreads.length < pageSize &&
          uniqueThreads.length < maxRetainedThreads) {
        extraPages += 1;
        final nextPage = await gateway.listThreads(
          ThreadListQuery(
            cursor: cursor,
            limit: pageSize,
            archived: _showArchived,
          ),
        );
        if (_disposed) {
          return;
        }
        for (final thread in nextPage.threads) {
          if (seenIds.add(thread.id) &&
              uniqueThreads.length < maxRetainedThreads) {
            uniqueThreads.add(thread);
          }
        }
        cursor = nextPage.nextCursor;
      }
      _threads
        ..clear()
        ..addAll(uniqueThreads);
      _nextCursor = cursor;
      _synchronizeSelection();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || !canLoadMore || _loading || _loadingMore) {
      return;
    }
    _loadingMore = true;
    _errorMessage = null;
    _notify();
    try {
      final remaining = maxRetainedThreads - _threads.length;
      final page = await gateway.listThreads(
        ThreadListQuery(
          cursor: cursor,
          limit: remaining < pageSize ? remaining : pageSize,
          archived: _showArchived,
        ),
      );
      if (_disposed) {
        return;
      }
      final existingIds = _threads.map((thread) => thread.id).toSet();
      _threads.addAll(
        page.threads
            .where((thread) => existingIds.add(thread.id))
            .take(remaining),
      );
      _nextCursor = page.nextCursor;
      _synchronizeSelection();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  Future<ThreadSummary?> startThread(ThreadStartOptions options) async {
    if (_mutating) {
      return null;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.startThread(options);
      if (_disposed) {
        return null;
      }
      _unmaterializedThreadIds.add(thread.id);
      _replaceOrPrepend(thread);
      _selectedThread = thread;
      return thread;
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<ThreadSummary?> selectThread(String threadId) async {
    if (_mutating) {
      return null;
    }
    if (_unmaterializedThreadIds.contains(threadId)) {
      final index = _threads.indexWhere((thread) => thread.id == threadId);
      if (index != -1) {
        _selectedThread = _threads[index];
        _notify();
        return _selectedThread;
      }
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.readThread(threadId);
      if (_disposed) {
        return null;
      }
      _unmaterializedThreadIds.remove(threadId);
      _replaceInPlace(thread);
      _selectedThread = thread;
      return thread;
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<ThreadSummary?> resumeThread(String threadId) async {
    if (_mutating) {
      return null;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.resumeThread(threadId);
      if (_disposed) {
        return null;
      }
      _unmaterializedThreadIds.remove(threadId);
      _replaceInPlace(thread);
      _selectedThread = thread;
      return thread;
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<bool> renameThread(String threadId, String name) async {
    if (_mutating) {
      return false;
    }
    final trimmed = name.trim();
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      await gateway.renameThread(threadId: threadId, name: trimmed);
      if (_disposed) {
        return false;
      }
      _applyNameUpdate(threadId, trimmed.isEmpty ? null : trimmed);
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<bool> archiveThread(String threadId) async {
    if (_mutating) {
      return false;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      await gateway.archiveThread(threadId);
      if (_disposed) {
        return false;
      }
      if (!_showArchived) {
        final wasSelected = _selectedThread?.id == threadId;
        _threads.removeWhere((thread) => thread.id == threadId);
        if (wasSelected) {
          _selectedThread = _threads.isEmpty ? null : _threads.first;
        }
        _synchronizeSelection();
      }
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<ThreadSummary?> unarchiveThread(String threadId) async {
    if (_mutating) {
      return null;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.unarchiveThread(threadId);
      if (_disposed) {
        return null;
      }
      if (_showArchived) {
        final wasSelected = _selectedThread?.id == threadId;
        _threads.removeWhere((candidate) => candidate.id == threadId);
        if (wasSelected) {
          _selectedThread = _threads.isEmpty ? null : _threads.first;
        }
        _synchronizeSelection();
      } else {
        _replaceOrPrepend(thread);
        _selectedThread = thread;
      }
      return thread;
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<ThreadSummary?> forkThread(ThreadForkOptions options) async {
    if (_mutating) {
      return null;
    }
    if (_unmaterializedThreadIds.contains(options.threadId)) {
      _errorMessage = 'Start at least one turn before forking this thread.';
      _notify();
      return null;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.forkThread(options);
      if (_disposed) {
        return null;
      }
      if (_showArchived) {
        _showArchived = false;
      }
      _replaceOrPrepend(thread);
      _selectedThread = thread;
      return thread;
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<ThreadSummary?> revertThread({
    required String threadId,
    required String beforeTurnId,
  }) async {
    if (_mutating) {
      return null;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.revertThread(
        threadId: threadId,
        beforeTurnId: beforeTurnId,
      );
      if (_disposed) {
        return null;
      }
      _replaceInPlace(thread);
      if (_selectedThread?.id == thread.id) {
        _selectedThread = thread;
      }
      _lastRevertedThreadId = thread.id;
      _revertVersion += 1;
      return thread;
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<bool> compactThread(String threadId) async {
    if (_mutating) {
      return false;
    }
    if (_unmaterializedThreadIds.contains(threadId)) {
      _errorMessage = 'Start at least one turn before compacting this thread.';
      _notify();
      return false;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      await gateway.compactThread(threadId);
      if (_disposed) {
        return false;
      }
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<bool> deleteThread(String threadId) async {
    if (_mutating) {
      return false;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      await gateway.deleteThread(threadId);
      if (_disposed) {
        return false;
      }
      _pinnedThreadIds.remove(threadId);
      _unmaterializedThreadIds.remove(threadId);
      final wasSelected = _selectedThread?.id == threadId;
      _threads.removeWhere((thread) => thread.id == threadId);
      if (wasSelected) {
        _selectedThread = _threads.isEmpty ? null : _threads.first;
      }
      _synchronizeSelection();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<bool> ensureSelectedThreadLoaded() async {
    final current = _selectedThread;
    if (current == null) {
      return false;
    }
    if (current.status != ThreadRuntimeStatus.notLoaded ||
        _unmaterializedThreadIds.contains(current.id)) {
      return true;
    }
    final resumed = await resumeThread(current.id);
    return resumed != null;
  }

  void _handleThreadEvent(ThreadLifecycleEvent event) {
    if (_disposed) {
      return;
    }
    switch (event) {
      case ThreadNameUpdatedEvent(:final threadId, :final threadName):
        _applyNameUpdate(threadId, threadName);
        _notify();
      case ThreadStatusChangedEvent(:final threadId, :final status):
        if (status != ThreadRuntimeStatus.notLoaded) {
          _unmaterializedThreadIds.remove(threadId);
        }
        _applyStatusUpdate(threadId, status);
        _notify();
      case ThreadArchivedEvent(:final threadId):
        if (!_showArchived) {
          final wasSelected = _selectedThread?.id == threadId;
          _threads.removeWhere((thread) => thread.id == threadId);
          if (wasSelected) {
            _selectedThread = _threads.isEmpty ? null : _threads.first;
          }
          _synchronizeSelection();
          _notify();
        }
      case ThreadUnarchivedEvent(:final threadId):
        if (_showArchived) {
          final wasSelected = _selectedThread?.id == threadId;
          _threads.removeWhere((thread) => thread.id == threadId);
          if (wasSelected) {
            _selectedThread = _threads.isEmpty ? null : _threads.first;
          }
          _synchronizeSelection();
          _notify();
        }
      case ThreadRevertedEvent(:final threadId):
        _lastRevertedThreadId = threadId;
        _revertVersion += 1;
        _notify();
    }
  }

  void _applyNameUpdate(String threadId, String? threadName) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index != -1) {
      _threads[index] = _threads[index].copyWith(
        name: threadName,
        clearName: threadName == null,
      );
    }
    if (_selectedThread?.id == threadId) {
      _selectedThread = _selectedThread!.copyWith(
        name: threadName,
        clearName: threadName == null,
      );
    }
  }

  void _applyStatusUpdate(String threadId, ThreadRuntimeStatus status) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index != -1) {
      _threads[index] = _threads[index].copyWith(status: status);
    }
    if (_selectedThread?.id == threadId) {
      _selectedThread = _selectedThread!.copyWith(status: status);
    }
  }

  void _replaceOrPrepend(ThreadSummary thread) {
    _threads.removeWhere((candidate) => candidate.id == thread.id);
    _threads.insert(0, thread);
    if (_threads.length > maxRetainedThreads) {
      _threads.removeRange(maxRetainedThreads, _threads.length);
    }
    _synchronizeSelection();
  }

  void _replaceInPlace(ThreadSummary thread) {
    final index = _threads.indexWhere((candidate) => candidate.id == thread.id);
    if (index == -1) {
      _replaceOrPrepend(thread);
    } else {
      _threads[index] = thread;
    }
  }

  void _synchronizeSelection() {
    final retainedIds = _threads.map((thread) => thread.id).toSet();
    _unmaterializedThreadIds.retainAll(retainedIds);
    final selectedId = _selectedThread?.id;
    if (selectedId == null) {
      return;
    }
    final index = _threads.indexWhere((thread) => thread.id == selectedId);
    _selectedThread = index == -1 ? null : _threads[index];
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_threadEventSubscription?.cancel());
    super.dispose();
  }
}
