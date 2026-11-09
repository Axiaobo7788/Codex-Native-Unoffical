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
  String? _sectionScopeId;
  var _sectionOrderRevision = 0;
  var _refreshSectionOrder = false;
  var _preserveOutsideCatalog = false;
  ThreadSummary? _selectedThread;
  String? _errorMessage;
  String? _lastRevertedThreadId;
  String? _goalOperationThreadId;
  String? _pendingGoalHydrationThreadId;
  var _goalProjectionRevision = 0;
  var _hydratingGoal = false;
  var _goalEventObserved = false;
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
  String? get sectionScopeId => _sectionScopeId;
  ThreadSection? get scopedSection => switch (_sectionScopeId) {
    final id? => _findSectionById(id),
    null => null,
  };
  bool get catalogBusy => _loading || _loadingMore || _mutating;
  bool get initialLoadStarted => _initialLoadStarted;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get mutating => _mutating;
  bool get supportsThreadSections => _sectionGateway != null;

  bool canManageGoal(String threadId) =>
      !_disposed &&
      !_showArchived &&
      _goalGateway != null &&
      (_selectedThread?.id == threadId ||
          _threads.any((row) => row.id == threadId));

  ThreadGoal? goalForThread(String threadId) {
    if (_selectedThread?.id == threadId) {
      return _selectedThread?.goal;
    }
    for (final row in _threads) {
      if (row.id == threadId) {
        return row.goal;
      }
    }
    return null;
  }

  bool get canLoadMore =>
      _nextCursor != null && _threads.length < maxRetainedThreads;
  bool get retentionLimitReached =>
      _nextCursor != null && _threads.length >= maxRetainedThreads;

  ThreadGoalGateway? get _goalGateway => switch (gateway) {
    final ThreadGoalGateway goalGateway when goalGateway.supportsThreadGoals =>
      goalGateway,
    _ => null,
  };

  ThreadSectionGateway? get _sectionGateway => switch (gateway) {
    final ThreadSectionGateway sectionGateway
        when sectionGateway.supportsThreadSections =>
      sectionGateway,
    _ => null,
  };

  ThreadSection? get builtInPinnedSection =>
      _findSectionById(kBuiltInPinnedThreadSectionId);

  bool isPersistedPinned(String threadId) =>
      _findThread(threadId)?.isPersistedPinned ?? false;

  bool isSessionPinned(String threadId) =>
      _pinnedThreadIds.contains(threadId) && !isPersistedPinned(threadId);

  bool isSessionPinnedThread(ThreadSummary thread) =>
      !thread.isPersistedPinned && _pinnedThreadIds.contains(thread.id);

  bool isPinned(String threadId) =>
      isPersistedPinned(threadId) || _pinnedThreadIds.contains(threadId);

  bool isPinnedThread(ThreadSummary thread) =>
      thread.isPersistedPinned || _pinnedThreadIds.contains(thread.id);

  bool isMaterialized(String threadId) =>
      !_unmaterializedThreadIds.contains(threadId);

  bool canPersistPinForThread(ThreadSummary thread) {
    if (_disposed || _showArchived || !supportsThreadSections) {
      return false;
    }
    if (builtInPinnedSection == null || !isMaterialized(thread.id)) {
      return false;
    }
    return thread.section == null || thread.isPersistedPinned;
  }

  bool canPersistPin(String threadId) {
    final thread = _findThread(threadId);
    if (thread == null) {
      return false;
    }
    return canPersistPinForThread(thread);
  }

  bool canTogglePinForThread(ThreadSummary thread) =>
      !_disposed &&
      (!thread.isPersistedPinned || (!_showArchived && supportsThreadSections));

  bool canTogglePin(String threadId) =>
      !_disposed &&
      (!isPersistedPinned(threadId) ||
          (!_showArchived && supportsThreadSections));

  String pinActionLabelForThread(ThreadSummary thread) {
    if (thread.isPersistedPinned) {
      return 'Unpin saved thread';
    }
    if (isSessionPinnedThread(thread)) {
      return 'Unpin session pin';
    }
    if (canPersistPinForThread(thread)) {
      return 'Pin thread';
    }
    return 'Pin for session';
  }

  Future<bool> togglePinThread(String threadId) {
    if (_disposed) {
      return Future<bool>.value(false);
    }
    if (isPersistedPinned(threadId)) {
      final removedLocal = _pinnedThreadIds.remove(threadId);
      if (_showArchived || !supportsThreadSections) {
        if (!removedLocal) {
          _errorMessage =
              'Saved Pinned threads cannot be unpinned in this view.';
        }
        _notify();
        return Future<bool>.value(removedLocal);
      }
      if (_mutating) {
        if (removedLocal) {
          _notify();
        }
        return Future<bool>.value(false);
      }
      return _togglePersistedPinWithFreshRead(
        threadId: threadId,
        expectedCurrentlyPinned: true,
      );
    }
    if (_pinnedThreadIds.remove(threadId)) {
      _notify();
      return Future<bool>.value(true);
    }
    if (canPersistPin(threadId)) {
      if (_mutating) {
        return Future<bool>.value(false);
      }
      return _togglePersistedPinWithFreshRead(
        threadId: threadId,
        expectedCurrentlyPinned: false,
      );
    }
    if (_pinnedThreadIds.length >= maxPinnedThreads) {
      _pinnedThreadIds.remove(_pinnedThreadIds.first);
    }
    _pinnedThreadIds.add(threadId);
    _notify();
    return Future<bool>.value(true);
  }

  /// Re-reads current thread metadata under [_mutating] before sending a stock
  /// section move for saved pin/unpin.
  ///
  /// Stock `thread/section/move` has no compare-and-swap precondition field, so
  /// a concurrent cross-process write between `thread/read` and
  /// `thread/section/move` remains a stock protocol limitation; re-reading
  /// immediately before the move prevents stale cached membership from
  /// silently overwriting or clearing a custom section.
  Future<bool> _togglePersistedPinWithFreshRead({
    required String threadId,
    required bool expectedCurrentlyPinned,
  }) async {
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
      final latest = await gateway.readThread(threadId);
      if (_disposed) {
        return false;
      }
      _unmaterializedThreadIds.remove(threadId);
      final reconciled = _replaceInPlace(latest);
      if (_selectedThread?.id == threadId) {
        _selectedThread = reconciled;
      }
      if (expectedCurrentlyPinned) {
        _pinnedThreadIds.remove(threadId);
        if (reconciled.section == null) {
          _invalidateSectionOrder();
          return true;
        }
        if (!reconciled.isPersistedPinned) {
          _errorMessage =
              'Thread is now in section "${reconciled.section!.name}" and was not removed from that section.';
          return false;
        }
        await sectionGateway.moveThreadSection(
          ThreadSectionMoveOptions(threadId: threadId, sectionId: null),
        );
        if (_disposed) {
          return false;
        }
        _applySectionChanged(threadId, null);
        _invalidateSectionOrder();
        return true;
      } else {
        if (reconciled.isPersistedPinned) {
          _pinnedThreadIds.remove(threadId);
          _invalidateSectionOrder();
          return true;
        }
        if (reconciled.section != null) {
          _errorMessage =
              'Thread is now in section "${reconciled.section!.name}". Use Pin for session or Move to section.';
          return false;
        }
        await sectionGateway.moveThreadSection(
          ThreadSectionMoveOptions(
            threadId: threadId,
            sectionId: kBuiltInPinnedThreadSectionId,
          ),
        );
        if (_disposed) {
          return false;
        }
        _applySectionChanged(threadId, kBuiltInPinnedThreadSectionId);
        _invalidateSectionOrder();
        return true;
      }
    } catch (error) {
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  Future<void> setSectionScope(String? sectionId) async {
    if (_disposed ||
        catalogBusy ||
        _sectionScopeId == sectionId ||
        (sectionId != null &&
            (_showArchived ||
                !supportsThreadSections ||
                !_sections.any((section) => section.id == sectionId)))) {
      return;
    }
    _sectionScopeId = sectionId;
    _sectionOrderRevision += 1;
    _nextCursor = null;
    _threads.clear();
    await refresh(preserveSelection: true);
  }

  ThreadListQuery _threadQuery({String? cursor, required int limit}) {
    final sectionId = _sectionScopeId;
    return sectionId == null
        ? ThreadListQuery(cursor: cursor, limit: limit, archived: _showArchived)
        : ThreadListQuery(
            cursor: cursor,
            limit: limit,
            section: (id: sectionId),
            sortKey: ThreadSortKey.sectionPosition,
            sortDirection: SortDirection.ascending,
          );
  }

  void _invalidateSectionOrder() {
    if (_sectionScopeId == null) {
      return;
    }
    _sectionOrderRevision += 1;
    _nextCursor = null;
    _refreshSectionOrder = true;
  }

  Future<void> setShowArchived(bool value) async {
    if (_showArchived == value || catalogBusy) {
      return;
    }
    _showArchived = value;
    _sectionScopeId = null;
    _refreshSectionOrder = false;
    _preserveOutsideCatalog = false;
    _nextCursor = null;
    _selectedThread = null;
    await refresh();
  }

  Future<void> refresh({bool preserveSelection = false}) async {
    if (_disposed || catalogBusy) {
      return;
    }
    final revision = _sectionOrderRevision;
    _refreshSectionOrder = false;
    _initialLoadStarted = true;
    _loading = true;
    _errorMessage = null;
    _notify();
    try {
      final page = await gateway.listThreads(_threadQuery(limit: pageSize));
      if (_disposed || revision != _sectionOrderRevision) {
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
          _threadQuery(cursor: cursor, limit: pageSize),
        );
        if (_disposed || revision != _sectionOrderRevision) {
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
      if (!_showArchived && _sectionScopeId == null) {
        await _refreshSectionsWithThreads(uniqueThreads);
        if (_disposed || revision != _sectionOrderRevision) {
          return;
        }
      } else {
        _mergeThreadEmbeddedSections(uniqueThreads);
      }
      _threads
        ..clear()
        ..addAll(uniqueThreads.map(_syncThreadSection));
      _nextCursor = cursor;
      _synchronizeSelection(preserveSelection: preserveSelection);
    } catch (error) {
      _errorMessage = _boundedError(error);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (_disposed || cursor == null || !canLoadMore || catalogBusy) {
      return;
    }
    final revision = _sectionOrderRevision;
    _loadingMore = true;
    _errorMessage = null;
    _notify();
    try {
      final remaining = maxRetainedThreads - _threads.length;
      final page = await gateway.listThreads(
        _threadQuery(
          cursor: cursor,
          limit: remaining < pageSize ? remaining : pageSize,
        ),
      );
      if (_disposed || revision != _sectionOrderRevision) {
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
      _activateThread(retained);
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
        _activateThread(_threads[index]);
        _queueSelectedGoalHydration(threadId);
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
      _activateThread(retainedThread);
      _queueSelectedGoalHydration(threadId);
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
      _activateThread(retainedThread);
      _queueSelectedGoalHydration(threadId);
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
      _invalidateSectionOrder();
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
      _invalidateSectionOrder();
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
        _activateThread(retained);
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
      _activateThread(retained);
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
      _invalidateSectionOrder();
      return true;
    } catch (error) {
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      _mutating = false;
      _notify();
    }
  }

  // Stock thread/list and thread/read omit goal state. Fetch only for the
  // selected thread, with one request and one replaceable pending target.
  void _queueSelectedGoalHydration(String threadId) {
    if (!canManageGoal(threadId)) {
      return;
    }
    _pendingGoalHydrationThreadId = threadId;
    if (!_hydratingGoal) {
      unawaited(_drainSelectedGoalHydration());
    }
  }

  Future<void> _drainSelectedGoalHydration() async {
    _hydratingGoal = true;
    try {
      while (_pendingGoalHydrationThreadId != null) {
        final threadId = _pendingGoalHydrationThreadId!;
        _pendingGoalHydrationThreadId = null;
        final gateway = _goalGateway;
        if (gateway == null ||
            _selectedThread?.id != threadId ||
            !canManageGoal(threadId) ||
            _goalOperationThreadId == threadId) {
          continue;
        }
        final revision = _goalProjectionRevision;
        ThreadGoal? goal;
        try {
          goal = await gateway.readThreadGoal(threadId);
        } catch (_) {
          // Selection stays usable with older runtimes. An explicit Manage
          // goal request can surface its bounded error.
          continue;
        }
        if (_selectedThread?.id != threadId ||
            !canManageGoal(threadId) ||
            revision != _goalProjectionRevision) {
          continue;
        }
        if (goal == null) {
          _clearGoal(threadId);
        } else {
          _applyGoalUpdate(threadId, goal);
        }
        _notify();
      }
    } finally {
      _hydratingGoal = false;
    }
  }

  Future<({ThreadGoal? goal})?> loadGoal(String threadId) => _runGoalOperation(
    threadId,
    (gateway) => gateway.readThreadGoal(threadId),
  );

  Future<void> saveGoal(
    String threadId, {
    String? objective,
    ThreadGoalStatus? status,
  }) async {
    await _runGoalOperation(
      threadId,
      (gateway) =>
          gateway.setThreadGoal(threadId, objective: objective, status: status),
    );
  }

  Future<void> clearGoal(String threadId) async {
    await _runGoalOperation(threadId, (gateway) async {
      if (await gateway.clearThreadGoal(threadId)) {
        return null;
      }
      return gateway.readThreadGoal(threadId);
    });
  }

  Future<({ThreadGoal? goal})?> _runGoalOperation(
    String threadId,
    Future<ThreadGoal?> Function(ThreadGoalGateway) request,
  ) async {
    final gateway = _goalGateway;
    if (_mutating || gateway == null || !canManageGoal(threadId)) {
      return null;
    }
    _mutating = true;
    _goalOperationThreadId = threadId;
    _goalProjectionRevision += 1;
    _goalEventObserved = false;
    _errorMessage = null;
    _notify();
    try {
      final goal = await request(gateway);
      if (!canManageGoal(threadId)) {
        return null;
      }
      if (_goalEventObserved) {
        return (goal: goalForThread(threadId));
      }
      if (goal == null) {
        _clearGoal(threadId);
      } else {
        _applyGoalUpdate(threadId, goal);
      }
      return (goal: goal);
    } catch (error) {
      if (!_disposed) {
        _errorMessage = _boundedError(error);
      }
      return null;
    } finally {
      _goalOperationThreadId = null;
      _goalEventObserved = false;
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
    final normalizedId = sectionId.trim();
    if (normalizedId == kBuiltInPinnedThreadSectionId) {
      _errorMessage = 'The built-in Pinned section cannot be renamed.';
      _notify();
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
          sectionId: normalizedId,
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
    final normalizedId = sectionId.trim();
    if (normalizedId == kBuiltInPinnedThreadSectionId) {
      _errorMessage = 'The built-in Pinned section cannot be deleted.';
      _notify();
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
      await sectionGateway.deleteThreadSection(normalizedId);
      if (_disposed) {
        return false;
      }
      _sections.removeWhere((section) => section.id == normalizedId);
      if (_sectionScopeId == normalizedId) {
        _sectionScopeId = null;
        _sectionOrderRevision += 1;
        _refreshSectionOrder = true;
        _threads.clear();
        _nextCursor = null;
      }
      for (var i = 0; i < _threads.length; i++) {
        if (_threads[i].section?.id == normalizedId) {
          _threads[i] = _threads[i].copyWith(
            clearSection: true,
            clearSectionEnteredAtSeconds: true,
          );
        }
      }
      if (_selectedThread?.section?.id == normalizedId) {
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
      _invalidateSectionOrder();
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
        _goalProjectionRevision += 1;
        _goalEventObserved |= threadId == _goalOperationThreadId;
        _applyGoalUpdate(threadId, goal);
        _notify();
      case ThreadGoalClearedEvent(:final threadId):
        _goalProjectionRevision += 1;
        _goalEventObserved |= threadId == _goalOperationThreadId;
        _clearGoal(threadId);
        _notify();
      case ThreadSectionChangedEvent(:final threadId, :final sectionId):
        _applySectionChanged(threadId, sectionId);
        _invalidateSectionOrder();
        _notify();
      case ThreadArchivedEvent(:final threadId):
        if (!_showArchived) {
          final wasSelected = _selectedThread?.id == threadId;
          _threads.removeWhere((thread) => thread.id == threadId);
          if (wasSelected) {
            _selectedThread = _threads.isEmpty ? null : _threads.first;
          }
          _synchronizeSelection();
          _invalidateSectionOrder();
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
        } else if (_sectionScopeId != null) {
          _invalidateSectionOrder();
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
    final previousWasBuiltInPinned = isPersistedPinned(threadId);
    if (sectionId == kBuiltInPinnedThreadSectionId ||
        previousWasBuiltInPinned) {
      _pinnedThreadIds.remove(threadId);
    }
    if (_sectionScopeId != null && sectionId != _sectionScopeId) {
      _threads.removeWhere((thread) => thread.id == threadId);
    }
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

    var resolved = _findSectionById(sectionId);
    if (resolved == null && sectionId == kBuiltInPinnedThreadSectionId) {
      const builtIn = ThreadSection(
        id: kBuiltInPinnedThreadSectionId,
        name: 'Pinned',
      );
      _upsertSection(builtIn);
      resolved = builtIn;
    }
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
      if (section.isBuiltInPinned) {
        final replaceIndex = _sections.lastIndexWhere(
          (candidate) =>
              !candidate.isBuiltInPinned && candidate.id != _sectionScopeId,
        );
        if (replaceIndex != -1) {
          _sections[replaceIndex] = section;
        }
      }
      return;
    }
    _sections.add(section);
  }

  ThreadSummary? _findThread(String threadId) {
    for (final thread in _threads) {
      if (thread.id == threadId) {
        return thread;
      }
    }
    if (_selectedThread?.id == threadId) {
      return _selectedThread;
    }
    return null;
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
    if (currentSection.isBuiltInPinned) {
      _pinnedThreadIds.remove(thread.id);
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
    if (_sectionScopeId != null) {
      if (thread.section?.id == _sectionScopeId) {
        _invalidateSectionOrder();
      }
      return thread;
    }
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
    }
    if (_sectionScopeId != null && thread.section?.id != _sectionScopeId) {
      // A metadata read can observe a move before a lifecycle notification.
      _threads.removeAt(index);
      _invalidateSectionOrder();
    } else {
      _threads[index] = thread;
    }
    return thread;
  }

  ThreadSummary _preserveTransientState(ThreadSummary thread) {
    ThreadSummary? retained;
    final index = _threads.indexWhere((candidate) => candidate.id == thread.id);
    if (index != -1) {
      retained = _threads[index];
    } else if (_selectedThread?.id == thread.id) {
      retained = _selectedThread;
    }
    if (thread.section?.isBuiltInPinned == true ||
        retained?.section?.isBuiltInPinned == true) {
      _pinnedThreadIds.remove(thread.id);
    }
    if (thread.goal != null) {
      return thread;
    }
    final goal = retained?.goal;
    return goal == null ? thread : thread.copyWith(goal: goal);
  }

  void _activateThread(ThreadSummary thread) {
    _selectedThread = thread;
    if (_sectionScopeId != null || _preserveOutsideCatalog) {
      _synchronizeSelection();
    }
  }

  void _synchronizeSelection({bool preserveSelection = false}) {
    final selectedId = _selectedThread?.id;
    final keepSelected =
        preserveSelection || _sectionScopeId != null || _preserveOutsideCatalog;
    final retainedIds = {
      for (final thread in _threads) thread.id,
      if (keepSelected && selectedId != null) selectedId,
    };
    _unmaterializedThreadIds.retainAll(retainedIds);
    if (selectedId == null) {
      _preserveOutsideCatalog = false;
      return;
    }
    final index = _threads.indexWhere((thread) => thread.id == selectedId);
    if (index != -1) {
      _selectedThread = _threads[index];
      _preserveOutsideCatalog = false;
    } else if (keepSelected) {
      // A scope transition can leave the active conversation outside the
      // first global page. Keep it through later paging until it reappears.
      _preserveOutsideCatalog = true;
    } else {
      _selectedThread = null;
    }
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
    if (_refreshSectionOrder && !catalogBusy) {
      unawaited(refresh(preserveSelection: true));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_threadEventSubscription?.cancel());
    super.dispose();
  }
}
