import 'package:flutter/foundation.dart';

import '../../domain/thread_gateway.dart';
import '../../domain/thread_models.dart';

class ThreadListController extends ChangeNotifier {
  ThreadListController({
    required this.gateway,
    this.pageSize = 25,
    this.maxRetainedThreads = 100,
  }) : assert(pageSize > 0 && pageSize <= 100),
       assert(maxRetainedThreads >= pageSize);

  final ThreadGateway gateway;
  final int pageSize;
  final int maxRetainedThreads;
  final List<ThreadSummary> _threads = [];
  final Set<String> _unmaterializedThreadIds = {};
  String? _nextCursor;
  ThreadSummary? _selectedThread;
  String? _errorMessage;
  var _initialLoadStarted = false;
  var _loading = false;
  var _loadingMore = false;
  var _mutating = false;
  var _disposed = false;

  List<ThreadSummary> get threads => List.unmodifiable(_threads);
  ThreadSummary? get selectedThread => _selectedThread;
  String? get errorMessage => _errorMessage;
  bool get initialLoadStarted => _initialLoadStarted;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get mutating => _mutating;
  bool get canLoadMore =>
      _nextCursor != null && _threads.length < maxRetainedThreads;
  bool get retentionLimitReached =>
      _nextCursor != null && _threads.length >= maxRetainedThreads;

  Future<void> refresh() async {
    if (_loading || _mutating) {
      return;
    }
    _initialLoadStarted = true;
    _loading = true;
    _errorMessage = null;
    _notify();
    try {
      final page = await gateway.listThreads(ThreadListQuery(limit: pageSize));
      if (_disposed) {
        return;
      }
      _threads
        ..clear()
        ..addAll(page.threads.take(maxRetainedThreads));
      _nextCursor = page.nextCursor;
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
    super.dispose();
  }
}
