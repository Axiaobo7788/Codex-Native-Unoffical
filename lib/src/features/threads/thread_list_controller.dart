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
          _errorMessage = _boundedError(error);
          _notify();
        }
      },
    );
  }

  static const maxPinnedThreads = 32;
  static const maxRetainedSections = 64;
  static const _maxErrorChars = 320;

  final ThreadGateway gateway;
  final int pageSize;
  final int maxRetainedThreads;
  final List<ThreadSummary> _threads = [];
  final List<ThreadSection> _sections = [];
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
  List<ThreadSection> get sections => List.unmodifiable(_sections);
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
  bool get supportsThreadSections => _sectionGateway != null;
  bool get canLoadMore =>
      _nextCursor != null && _threads.length < maxRetainedThreads;
  bool get retentionLimitReached =>
      _nextCursor != null && _threads.length >= maxRetainedThreads;

  ThreadSectionGateway? get _sectionGateway => switch (gateway) {
    final ThreadSectionGateway sectionGateway
        when sectionGateway.supportsThreadSections =>
      sectionGateway,
    _ => null,
  };

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
            uniqueThreads.add(_preserveTransientState(thread));
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
            uniqueThreads.add(_preserveTransientState(thread));
          }
        }
        cursor = nextPage.nextCursor;
      }
      if (!_showArchived) {
        await _refreshSectionsWithThreads(uniqueThreads);
        if (_disposed) {
          return;
        }
      } else {
        _mergeThreadEmbeddedSections(uniqueThreads);
      }
      _threads
        ..clear()
        ..addAll(uniqueThreads.map(_syncThreadSection));
      _nextCursor = cursor;
      _synchronizeSelection();
    } catch (error) {
      _errorMessage = _boundedError(error);
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
      final appended = page.threads
          .where((thread) => existingIds.add(thread.id))
          .take(remaining)
          .map(_preserveTransientState)
          .toList(growable: false);
      _mergeThreadEmbeddedSections(appended);
      _threads.addAll(appended.map(_syncThreadSection));
      _nextCursor = page.nextCursor;
      _synchronizeSelection();
    } catch (error) {
      _errorMessage = _boundedError(error);
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
      final retained = _replaceOrPrepend(thread);
      _selectedThread = retained;
      return retained;
    } catch (error) {
      _errorMessage = _boundedError(error);
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
      final retainedThread = _replaceInPlace(thread);
      _selectedThread = retainedThread;
      return retainedThread;
    } catch (error) {
      _errorMessage = _boundedError(error);
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
      final retainedThread = _replaceInPlace(thread);
      _selectedThread = retainedThread;
      return retainedThread;
    } catch (error) {
      _errorMessage = _boundedError(error);
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
      _errorMessage = _boundedError(error);
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
      _errorMessage = _boundedError(error);
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
        return thread;
      } else {
        final retained = _replaceOrPrepend(thread);
        _selectedThread = retained;
        return retained;
      }
    } catch (error) {
      _errorMessage = _boundedError(error);
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
      final retained = _replaceOrPrepend(thread);
      _selectedThread = retained;
      return retained;
    } catch (error) {
      _errorMessage = _boundedError(error);
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
      final retainedThread = _replaceInPlace(thread);
      if (_selectedThread?.id == retainedThread.id) {
        _selectedThread = retainedThread;
      }
      _lastRevertedThreadId = retainedThread.id;
      _revertVersion += 1;
      return retainedThread;
    } catch (error) {
      _errorMessage = _boundedError(error);
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
      _errorMessage = _boundedError(error);
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
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<ThreadSection?> createSection(
    String name, {
    ThreadSectionAppearance? appearance,
  }) async {
    if (_mutating) {
      return null;
    }
    final sectionGateway = _sectionGateway;
    if (sectionGateway == null) {
      _errorMessage = 'Thread sections are unavailable on this runtime.';
      _notify();
      return null;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Section name must not be empty.';
      _notify();
      return null;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      final section = await sectionGateway.createThreadSection(
        ThreadSectionCreateOptions(name: trimmed, appearance: appearance),
      );
      if (_disposed) {
        return null;
      }
      _upsertSection(section);
      return section;
    } catch (error) {
      _errorMessage = _boundedError(error);
      return null;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<ThreadSection?> renameSection(
    String sectionId,
    String name, {
    ThreadSectionAppearance? appearance,
    bool clearAppearance = false,
  }) async {
    if (_mutating) {
      return null;
    }
    final sectionGateway = _sectionGateway;
    if (sectionGateway == null) {
      _errorMessage = 'Thread sections are unavailable on this runtime.';
      _notify();
      return null;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Section name must not be empty.';
      _notify();
      return null;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      final updated = await sectionGateway.updateThreadSection(
        ThreadSectionUpdateOptions(
          sectionId: sectionId,
          name: trimmed,
          appearance: appearance,
          clearAppearance: clearAppearance,
        ),
      );
      if (_disposed) {
        return null;
      }
      _upsertSection(updated);
      for (var i = 0; i < _threads.length; i++) {
        if (_threads[i].section?.id == updated.id) {
          _threads[i] = _threads[i].copyWith(section: updated);
        }
      }
      if (_selectedThread?.section?.id == updated.id) {
        _selectedThread = _selectedThread!.copyWith(section: updated);
      }
      return updated;
    } catch (error) {
      _errorMessage = _boundedError(error);
      return null;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<bool> deleteSection(String sectionId) async {
    if (_mutating) {
      return false;
    }
    final sectionGateway = _sectionGateway;
    if (sectionGateway == null) {
      _errorMessage = 'Thread sections are unavailable on this runtime.';
      _notify();
      return false;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      await sectionGateway.deleteThreadSection(sectionId);
      if (_disposed) {
        return false;
      }
      _sections.removeWhere((section) => section.id == sectionId);
      for (var i = 0; i < _threads.length; i++) {
        if (_threads[i].section?.id == sectionId) {
          _threads[i] = _threads[i].copyWith(
            clearSection: true,
            clearSectionEnteredAtSeconds: true,
          );
        }
      }
      if (_selectedThread?.section?.id == sectionId) {
        _selectedThread = _selectedThread!.copyWith(
          clearSection: true,
          clearSectionEnteredAtSeconds: true,
        );
      }
      return true;
    } catch (error) {
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<bool> moveThreadToSection({
    required String threadId,
    required String? sectionId,
    String? beforeThreadId,
  }) async {
    if (_mutating) {
      return false;
    }
    final sectionGateway = _sectionGateway;
    if (sectionGateway == null) {
      _errorMessage = 'Thread sections are unavailable on this runtime.';
      _notify();
      return false;
    }
    _mutating = true;
    _errorMessage = null;
    _notify();
    try {
      await sectionGateway.moveThreadSection(
        ThreadSectionMoveOptions(
          threadId: threadId,
          sectionId: sectionId,
          beforeThreadId: beforeThreadId,
        ),
      );
      if (_disposed) {
        return false;
      }
      _applySectionChanged(threadId, sectionId);
      return true;
    } catch (error) {
      _errorMessage = _boundedError(error);
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
      case ThreadGoalUpdatedEvent(:final threadId, :final goal):
        _applyGoalUpdate(threadId, goal);
        _notify();
      case ThreadGoalClearedEvent(:final threadId):
        _clearGoal(threadId);
        _notify();
      case ThreadSectionChangedEvent(:final threadId, :final sectionId):
        _applySectionChanged(threadId, sectionId);
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

  void _applyGoalUpdate(String threadId, ThreadGoal goal) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index != -1) {
      _threads[index] = _threads[index].copyWith(goal: goal);
    }
    if (_selectedThread?.id == threadId) {
      _selectedThread = _selectedThread!.copyWith(goal: goal);
    }
  }

  void _clearGoal(String threadId) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index != -1) {
      _threads[index] = _threads[index].copyWith(clearGoal: true);
    }
    if (_selectedThread?.id == threadId) {
      _selectedThread = _selectedThread!.copyWith(clearGoal: true);
    }
  }

  void _applySectionChanged(String threadId, String? sectionId) {
    if (sectionId == null) {
      final index = _threads.indexWhere((thread) => thread.id == threadId);
      if (index != -1) {
        _threads[index] = _threads[index].copyWith(
          clearSection: true,
          clearSectionEnteredAtSeconds: true,
        );
      }
      if (_selectedThread?.id == threadId) {
        _selectedThread = _selectedThread!.copyWith(
          clearSection: true,
          clearSectionEnteredAtSeconds: true,
        );
      }
      return;
    }

    final resolved = _findSectionById(sectionId);
    if (resolved == null) {
      if (_sectionGateway != null) {
        unawaited(_reloadSectionsAndResolveThread(threadId, sectionId));
      }
      return;
    }

    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index != -1) {
      _threads[index] = _threads[index].copyWith(section: resolved);
    }
    if (_selectedThread?.id == threadId) {
      _selectedThread = _selectedThread!.copyWith(section: resolved);
    }
  }

  Future<void> _refreshSectionsWithThreads(List<ThreadSummary> threads) async {
    final sectionGateway = _sectionGateway;
    if (sectionGateway == null) {
      _mergeThreadEmbeddedSections(threads);
      return;
    }
    try {
      final page = await sectionGateway.listThreadSections(
        const ThreadSectionListQuery(limit: maxRetainedSections),
      );
      if (_disposed) {
        return;
      }
      _sections
        ..clear()
        ..addAll(page.sections.take(maxRetainedSections));
    } catch (error) {
      _errorMessage = _boundedError(error);
    }
    _mergeThreadEmbeddedSections(threads);
  }

  Future<void> _reloadSectionsAndResolveThread(
    String threadId,
    String sectionId,
  ) async {
    final sectionGateway = _sectionGateway;
    if (sectionGateway == null || _disposed) {
      return;
    }
    try {
      final page = await sectionGateway.listThreadSections(
        const ThreadSectionListQuery(limit: maxRetainedSections),
      );
      if (_disposed) {
        return;
      }
      for (final section in page.sections) {
        _upsertSection(section);
      }
      final resolved = _findSectionById(sectionId);
      if (resolved != null) {
        final index = _threads.indexWhere((thread) => thread.id == threadId);
        if (index != -1) {
          _threads[index] = _threads[index].copyWith(section: resolved);
        }
        if (_selectedThread?.id == threadId) {
          _selectedThread = _selectedThread!.copyWith(section: resolved);
        }
      }
      for (var i = 0; i < _threads.length; i++) {
        _threads[i] = _syncThreadSection(_threads[i]);
      }
      if (_selectedThread != null) {
        _selectedThread = _syncThreadSection(_selectedThread!);
      }
      _notify();
    } catch (_) {
      // Best-effort background resolution after thread/section/changed.
    }
  }

  void _mergeThreadEmbeddedSections(Iterable<ThreadSummary> threads) {
    for (final thread in threads) {
      if (thread.section case final section?) {
        _upsertSection(section);
      }
    }
  }

  void _upsertSection(ThreadSection section) {
    final existingIndex = _sections.indexWhere(
      (candidate) => candidate.id == section.id,
    );
    if (existingIndex != -1) {
      _sections[existingIndex] = section;
      return;
    }
    if (_sections.length >= maxRetainedSections) {
      return;
    }
    _sections.add(section);
  }

  ThreadSection? _findSectionById(String sectionId) {
    for (final section in _sections) {
      if (section.id == sectionId) {
        return section;
      }
    }
    return null;
  }

  ThreadSummary _syncThreadSection(ThreadSummary thread) {
    final currentSection = thread.section;
    if (currentSection == null) {
      return thread;
    }
    _upsertSection(currentSection);
    final canonical = _findSectionById(currentSection.id);
    if (canonical == null || identical(canonical, currentSection)) {
      return thread;
    }
    return thread.copyWith(section: canonical);
  }

  static String _boundedError(Object error) {
    final normalized = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return 'Thread operation failed.';
    }
    if (normalized.length <= _maxErrorChars) {
      return normalized;
    }
    var end = _maxErrorChars;
    if (end > 0) {
      final lastUnit = normalized.codeUnitAt(end - 1);
      if (lastUnit >= 0xD800 && lastUnit <= 0xDBFF) {
        end -= 1;
      }
    }
    return '${normalized.substring(0, end)}…';
  }

  ThreadSummary _replaceOrPrepend(ThreadSummary thread) {
    thread = _syncThreadSection(_preserveTransientState(thread));
    _threads.removeWhere((candidate) => candidate.id == thread.id);
    _threads.insert(0, thread);
    if (_threads.length > maxRetainedThreads) {
      _threads.removeRange(maxRetainedThreads, _threads.length);
    }
    _synchronizeSelection();
    return thread;
  }

  ThreadSummary _replaceInPlace(ThreadSummary thread) {
    thread = _syncThreadSection(_preserveTransientState(thread));
    final index = _threads.indexWhere((candidate) => candidate.id == thread.id);
    if (index == -1) {
      return _replaceOrPrepend(thread);
    } else {
      _threads[index] = thread;
    }
    return thread;
  }

  ThreadSummary _preserveTransientState(ThreadSummary thread) {
    if (thread.goal != null) {
      return thread;
    }
    ThreadSummary? retained;
    final index = _threads.indexWhere((candidate) => candidate.id == thread.id);
    if (index != -1) {
      retained = _threads[index];
    } else if (_selectedThread?.id == thread.id) {
      retained = _selectedThread;
    }
    final goal = retained?.goal;
    return goal == null ? thread : thread.copyWith(goal: goal);
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
