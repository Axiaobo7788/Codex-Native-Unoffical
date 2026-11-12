import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/execution_settings.dart';
import '../../domain/thread_gateway.dart';
import '../../domain/thread_models.dart';

enum ThreadResumeStatus { loaded, failed, skipped }

@immutable
class ThreadResumeOutcome {
  const ThreadResumeOutcome._({
    required this.status,
    this.thread,
    this.errorMessage,
  });

  const ThreadResumeOutcome.loaded(ThreadSummary thread)
    : this._(status: ThreadResumeStatus.loaded, thread: thread);

  const ThreadResumeOutcome.failed(String errorMessage)
    : this._(status: ThreadResumeStatus.failed, errorMessage: errorMessage);

  const ThreadResumeOutcome.skipped()
    : this._(status: ThreadResumeStatus.skipped);

  final ThreadResumeStatus status;
  final ThreadSummary? thread;
  final String? errorMessage;

  bool get isLoaded => status == ThreadResumeStatus.loaded;
  bool get isFailed => status == ThreadResumeStatus.failed;
}

@immutable
class SessionDraftReplacement {
  const SessionDraftReplacement({
    required this.version,
    required this.retiredThreadId,
    required this.replacementThreadId,
  });

  final int version;
  final String retiredThreadId;
  final String replacementThreadId;
}

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
  static const maxSavedSearchLength = 256;
  static const _maxErrorChars = 320;

  final ThreadGateway gateway;
  final int pageSize;
  final int maxRetainedThreads;
  final List<ThreadSummary> _threads = [];
  final List<ThreadSection> _sections = [];
  final Set<String> _unmaterializedThreadIds = {};
  final Set<String> _retiredSessionDraftIds = {};
  final Set<String> _pinnedThreadIds = {};
  // Local ordering for in-flight snapshots. Stock revisions remain opaque.
  final Map<String, int> _readReceiptVersions = {};
  StreamSubscription<ThreadLifecycleEvent>? _threadEventSubscription;
  String? _nextCursor;
  String? _sectionScopeId;
  String? _savedSearchTerm;
  var _catalogRevision = 0;
  var _readReceiptVersion = 0;
  var _refreshCatalogPending = false;
  var _preserveOutsideCatalog = false;
  ThreadSummary? _selectedThread;
  String? _errorMessage;
  String? _lastRevertedThreadId;
  SessionDraftReplacement? _lastSessionDraftReplacement;
  String? _goalOperationThreadId;
  String? _pendingGoalHydrationThreadId;
  var _goalProjectionRevision = 0;
  var _hydratingGoal = false;
  var _goalEventObserved = false;
  var _revertVersion = 0;
  var _sessionDraftReplacementVersion = 0;
  var _showArchived = false;
  var _initialLoadStarted = false;
  var _loading = false;
  var _loadingMore = false;
  var _mutating = false;
  var _disposed = false;
  var _runtimeGeneration = 0;

  bool _isCurrentRuntime(int generation) =>
      !_disposed && generation == _runtimeGeneration;

  /// Keep bounded metadata and selection, retiring session-local settings and
  /// old async work before a new Host can reuse request IDs.
  void invalidateRuntime() {
    _retiredSessionDraftIds.addAll(_unmaterializedThreadIds);
    _retiredSessionDraftIds.addAll([
      for (final row in _threads)
        if (row.ephemeral) row.id,
      if (_selectedThread case final selected? when selected.ephemeral)
        selected.id,
    ]);
    _runtimeGeneration += 1;
    _catalogRevision += 1;
    _goalProjectionRevision += 1;
    _readReceiptVersion += 1;
    _readReceiptVersions.clear();
    _loading = false;
    _loadingMore = false;
    _mutating = false;
    _refreshCatalogPending = false;
    _nextCursor = null;
    _goalOperationThreadId = null;
    _pendingGoalHydrationThreadId = null;
    _hydratingGoal = false;
    _goalEventObserved = false;
    _errorMessage = null;
    for (var i = 0; i < _threads.length; i += 1) {
      _threads[i] = _threads[i].copyWith(
        status: ThreadRuntimeStatus.notLoaded,
        clearExecutionSettings: true,
      );
    }
    if (_selectedThread case final selected?) {
      _selectedThread = selected.copyWith(
        status: ThreadRuntimeStatus.notLoaded,
        clearExecutionSettings: true,
      );
    }
    _notify();
  }

  List<ThreadSummary> get threads => List.unmodifiable(_threads);
  List<ThreadSection> get sections => List.unmodifiable(_sections);
  Set<String> get pinnedThreadIds => Set.unmodifiable(_pinnedThreadIds);
  ThreadSummary? get selectedThread => _selectedThread;
  String? get errorMessage => _errorMessage;
  String? get lastRevertedThreadId => _lastRevertedThreadId;
  int get revertVersion => _revertVersion;
  SessionDraftReplacement? get lastSessionDraftReplacement =>
      _lastSessionDraftReplacement;
  bool get showArchived => _showArchived;
  String? get sectionScopeId => _sectionScopeId;
  String? get savedSearchTerm => _savedSearchTerm;
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

  ThreadReadReceiptGateway? get _readReceiptGateway => switch (gateway) {
    final ThreadReadReceiptGateway receiptGateway
        when receiptGateway.supportsThreadReadReceiptWrites =>
      receiptGateway,
    _ => null,
  };

  bool canChangeReadReceipt(ThreadSummary thread) =>
      !_disposed &&
      !thread.ephemeral &&
      thread.readReceipt != null &&
      _readReceiptGateway != null;

  Future<void> toggleReadReceipt(
    String threadId,
    ThreadReadReceipt seenReceipt,
  ) async {
    final receiptGateway = _readReceiptGateway;
    final thread = _findThread(threadId);
    if (_disposed ||
        _mutating ||
        receiptGateway == null ||
        thread == null ||
        thread.ephemeral) {
      return;
    }
    if (thread.readReceipt?.revision != seenReceipt.revision) {
      _errorMessage =
          'Read status changed. Check the updated status and try again.';
      _notify();
      return;
    }
    final version = _readReceiptVersion;
    _mutating = true;
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      final receipt = await receiptGateway.setThreadReadReceipt(
        threadId: threadId,
        expectedRevision: seenReceipt.revision,
        unread: !seenReceipt.unread,
      );
      if (_isCurrentRuntime(generation) &&
          !_receiptChangedAfter(threadId, version)) {
        _applyReadReceipt(threadId, receipt);
      }
    } on UnsupportedError {
      if (_isCurrentRuntime(generation)) {
        _errorMessage = 'This runtime cannot change saved read status.';
      }
    } catch (_) {
      if (!_isCurrentRuntime(generation)) return;
      if (_isCurrentRuntime(generation)) {
        await _refreshReceiptAfterFailedWrite(threadId, seenReceipt);
      }
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<void> _refreshReceiptAfterFailedWrite(
    String threadId,
    ThreadReadReceipt seenReceipt,
  ) async {
    final generation = _runtimeGeneration;
    final version = _readReceiptVersion;
    try {
      final latest = await gateway.readThread(threadId);
      if (_isCurrentRuntime(generation) &&
          latest.id == threadId &&
          !_receiptChangedAfter(threadId, version)) {
        _applyReadReceipt(threadId, latest.readReceipt);
      }
    } catch (_) {
      // Keep the last displayed receipt. The next explicit action can retry.
    }
    if (_isCurrentRuntime(generation)) {
      final current = _findThread(threadId)?.readReceipt;
      _errorMessage =
          current != null && current.revision != seenReceipt.revision
          ? 'Read status changed. Check the updated status and try again.'
          : 'Could not change saved read status. Try again.';
    }
  }

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
      !_unmaterializedThreadIds.contains(threadId) &&
      !_retiredSessionDraftIds.contains(threadId);

  bool selectedThreadNeedsDraftRecovery(String threadId) =>
      _selectedThread?.id == threadId &&
      _retiredSessionDraftIds.contains(threadId);

  static const sessionDraftRecoveryMessage =
      'This conversation is not available in the current runtime. '
      'Nothing was replayed. Start a new conversation to keep this draft.';

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
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      final receiptVersion = _readReceiptVersion;
      final latest = await gateway.readThread(threadId);
      if (!_isCurrentRuntime(generation)) {
        return false;
      }
      if (latest.id != threadId) {
        _errorMessage = 'Thread read returned a mismatched thread identifier.';
        return false;
      }
      _unmaterializedThreadIds.remove(threadId);
      final reconciled = _replaceInPlace(
        _acceptReceiptSnapshot(latest, receiptVersion),
      );
      if (_selectedThread?.id == threadId) {
        _selectedThread = reconciled;
      }
      if (reconciled.section != null && !reconciled.isPersistedPinned) {
        _errorMessage = expectedCurrentlyPinned
            ? 'Thread is now in section "${reconciled.section!.name}" and was not removed from that section.'
            : 'Thread is now in section "${reconciled.section!.name}". Use Pin for session or Move to section.';
        return false;
      }
      final targetSectionId = expectedCurrentlyPinned
          ? null
          : kBuiltInPinnedThreadSectionId;
      _pinnedThreadIds.remove(threadId);
      if (reconciled.isPersistedPinned != expectedCurrentlyPinned) {
        _invalidateSectionOrder();
        return true;
      }
      await sectionGateway.moveThreadSection(
        ThreadSectionMoveOptions(
          threadId: threadId,
          sectionId: targetSectionId,
        ),
      );
      if (!_isCurrentRuntime(generation)) {
        return false;
      }
      _applySectionChanged(threadId, targetSectionId);
      _invalidateSectionOrder();
      return true;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return false;
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
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
    _savedSearchTerm = null;
    _resetCatalogScope();
    await refresh(preserveSelection: true);
  }

  Future<void> setSavedSearch(String? term) async {
    final trimmed = term?.trim() ?? '';
    final searchTerm = trimmed.isEmpty ? null : trimmed;
    if (_disposed ||
        _sectionScopeId != null ||
        _savedSearchTerm == searchTerm ||
        trimmed.length > maxSavedSearchLength ||
        (searchTerm != null && catalogBusy)) {
      return;
    }
    _savedSearchTerm = searchTerm;
    _resetCatalogScope();
    if (catalogBusy) {
      // Let a pending page finish before starting the replacement request.
      // The revision prevents the pending page from changing the new scope.
      _refreshCatalogPending = true;
      _notify();
      return;
    }
    await refresh(preserveSelection: true);
  }

  void _resetCatalogScope() {
    _catalogRevision += 1;
    _nextCursor = null;
    _errorMessage = null;
    _threads.clear();
    _preserveOutsideCatalog = _selectedThread != null;
  }

  ThreadListQuery _threadQuery({String? cursor, required int limit}) {
    final sectionId = _sectionScopeId;
    return sectionId == null
        ? ThreadListQuery(
            cursor: cursor,
            limit: limit,
            archived: _showArchived,
            searchTerm: _savedSearchTerm,
          )
        : ThreadListQuery(
            cursor: cursor,
            limit: limit,
            section: (id: sectionId),
            sortKey: ThreadSortKey.sectionPosition,
            sortDirection: SortDirection.ascending,
          );
  }

  void _invalidateSectionOrder() {
    if (_sectionScopeId != null) {
      _invalidateCatalogOrder();
    }
  }

  void _invalidateSavedSearch() {
    if (_savedSearchTerm != null) {
      _invalidateCatalogOrder();
    }
  }

  void _invalidateCatalogOrder() {
    _catalogRevision += 1;
    _nextCursor = null;
    _refreshCatalogPending = true;
  }

  Future<void> setShowArchived(bool value) async {
    if (_showArchived == value || catalogBusy) {
      return;
    }
    _showArchived = value;
    _sectionScopeId = null;
    if (_savedSearchTerm != null) {
      _threads.clear();
    }
    _savedSearchTerm = null;
    _refreshCatalogPending = false;
    _preserveOutsideCatalog = false;
    _nextCursor = null;
    _selectedThread = null;
    await refresh();
  }

  Future<void> refresh({bool preserveSelection = false}) async {
    if (_disposed || catalogBusy) {
      return;
    }
    final generation = _runtimeGeneration;
    final revision = _catalogRevision;
    final receiptVersion = _readReceiptVersion;
    _refreshCatalogPending = false;
    _initialLoadStarted = true;
    _loading = true;
    _errorMessage = null;
    _notify();
    try {
      final page = await gateway.listThreads(_threadQuery(limit: pageSize));
      if (_disposed || revision != _catalogRevision) {
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
        if (_disposed || revision != _catalogRevision) {
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
      if (!_showArchived &&
          _sectionScopeId == null &&
          _savedSearchTerm == null) {
        await _refreshSectionsWithThreads(uniqueThreads);
        if (_disposed || revision != _catalogRevision) {
          return;
        }
      } else {
        _mergeThreadEmbeddedSections(uniqueThreads);
      }
      final reconciled = uniqueThreads
          .map((thread) => _acceptReceiptSnapshot(thread, receiptVersion))
          .map(_syncThreadSection)
          .toList(growable: false);
      _threads
        ..clear()
        ..addAll(reconciled);
      _nextCursor = cursor;
      _synchronizeSelection(preserveSelection: preserveSelection);
    } catch (error) {
      if (_isCurrentRuntime(generation) && revision == _catalogRevision) {
        _errorMessage = _boundedError(error);
      }
    } finally {
      if (_isCurrentRuntime(generation)) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (_disposed || cursor == null || !canLoadMore || catalogBusy) {
      return;
    }
    final generation = _runtimeGeneration;
    final revision = _catalogRevision;
    final receiptVersion = _readReceiptVersion;
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
      if (_disposed || revision != _catalogRevision) {
        return;
      }
      final existingIds = _threads.map((thread) => thread.id).toSet();
      final appended = page.threads
          .where((thread) => existingIds.add(thread.id))
          .take(remaining)
          .map(_preserveTransientState)
          .map((thread) => _acceptReceiptSnapshot(thread, receiptVersion))
          .toList(growable: false);
      _mergeThreadEmbeddedSections(appended);
      _threads.addAll(appended.map(_syncThreadSection));
      _nextCursor = page.nextCursor;
      _synchronizeSelection();
    } catch (error) {
      if (_isCurrentRuntime(generation) && revision == _catalogRevision) {
        _errorMessage = _boundedError(error);
      }
    } finally {
      if (_isCurrentRuntime(generation)) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  Future<ThreadSummary?> startThread(
    ThreadStartOptions options, {
    String? replaceSessionDraftId,
  }) async {
    if (_mutating) {
      return null;
    }
    _mutating = true;
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.startThread(options);
      if (!_isCurrentRuntime(generation)) {
        return null;
      }
      _unmaterializedThreadIds.add(thread.id);
      if (replaceSessionDraftId != null &&
          _retiredSessionDraftIds.remove(replaceSessionDraftId)) {
        // Evict only the local unavailable projection. Never delete a rollout
        // or infer that a possibly accepted operation did not reach stock.
        _unmaterializedThreadIds.remove(replaceSessionDraftId);
        _threads.removeWhere((row) => row.id == replaceSessionDraftId);
        if (replaceSessionDraftId != thread.id) {
          _lastSessionDraftReplacement = SessionDraftReplacement(
            version: ++_sessionDraftReplacementVersion,
            retiredThreadId: replaceSessionDraftId,
            replacementThreadId: thread.id,
          );
        }
      }
      final retained = _replaceOrPrepend(thread);
      _activateThread(retained);
      return retained;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return null;
      _errorMessage = _boundedError(error);
      return null;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<ThreadSummary?> selectThread(String threadId) async {
    if (_mutating) {
      return null;
    }
    if (_unmaterializedThreadIds.contains(threadId) &&
        !_retiredSessionDraftIds.contains(threadId)) {
      final index = _threads.indexWhere((thread) => thread.id == threadId);
      if (index != -1) {
        _activateThread(_threads[index]);
        _queueSelectedGoalHydration(threadId);
        _notify();
        return _selectedThread;
      }
    }
    _mutating = true;
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      final receiptVersion = _readReceiptVersion;
      final thread = await gateway.readThread(threadId);
      if (!_isCurrentRuntime(generation)) {
        return null;
      }
      _unmaterializedThreadIds.remove(threadId);
      _retiredSessionDraftIds.remove(threadId);
      final retainedThread = _replaceInPlace(
        _acceptReceiptSnapshot(thread, receiptVersion),
      );
      _activateThread(retainedThread);
      _queueSelectedGoalHydration(threadId);
      return retainedThread;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return null;
      _errorMessage = _boundedError(error);
      return null;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<ThreadSummary?> resumeThread(String threadId) async =>
      (await resumeThreadWithOutcome(threadId)).thread;

  Future<ThreadResumeOutcome> resumeThreadWithOutcome(String threadId) async {
    if (_disposed || _mutating) {
      return const ThreadResumeOutcome.skipped();
    }
    if (_retiredSessionDraftIds.contains(threadId)) {
      return const ThreadResumeOutcome.failed(sessionDraftRecoveryMessage);
    }
    _mutating = true;
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.resumeThread(threadId);
      if (!_isCurrentRuntime(generation)) {
        return const ThreadResumeOutcome.skipped();
      }
      _unmaterializedThreadIds.remove(threadId);
      final retainedThread = _replaceInPlace(_retainReceipt(thread));
      _activateThread(retainedThread);
      _queueSelectedGoalHydration(threadId);
      return ThreadResumeOutcome.loaded(retainedThread);
    } catch (error) {
      if (!_isCurrentRuntime(generation)) {
        return const ThreadResumeOutcome.skipped();
      }
      final message = _boundedError(error);
      _errorMessage = message;
      return ThreadResumeOutcome.failed(message);
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<bool> renameThread(String threadId, String name) async {
    if (_mutating) {
      return false;
    }
    final trimmed = name.trim();
    _mutating = true;
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      await gateway.renameThread(threadId: threadId, name: trimmed);
      if (!_isCurrentRuntime(generation)) {
        return false;
      }
      _applyNameUpdate(threadId, trimmed.isEmpty ? null : trimmed);
      return true;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return false;
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<bool> archiveThread(String threadId) async {
    if (_mutating) {
      return false;
    }
    _mutating = true;
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      await gateway.archiveThread(threadId);
      if (!_isCurrentRuntime(generation)) {
        return false;
      }
      _applyStatusUpdate(threadId, ThreadRuntimeStatus.notLoaded);
      if (!_showArchived) {
        final wasSelected = _selectedThread?.id == threadId;
        _threads.removeWhere((thread) => thread.id == threadId);
        if (wasSelected) {
          _selectedThread = _threads.isEmpty ? null : _threads.first;
        }
        _synchronizeSelection();
      }
      _invalidateSectionOrder();
      _invalidateSavedSearch();
      return true;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return false;
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<ThreadSummary?> unarchiveThread(String threadId) async {
    if (_mutating) {
      return null;
    }
    _mutating = true;
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.unarchiveThread(threadId);
      if (!_isCurrentRuntime(generation)) {
        return null;
      }
      _invalidateSectionOrder();
      _invalidateSavedSearch();
      if (_showArchived) {
        final wasSelected = _selectedThread?.id == threadId;
        _threads.removeWhere((candidate) => candidate.id == threadId);
        if (wasSelected) {
          _selectedThread = _threads.isEmpty ? null : _threads.first;
        }
        _synchronizeSelection();
        return thread;
      } else {
        final retained = _replaceOrPrepend(_retainReceipt(thread));
        _activateThread(retained);
        return retained;
      }
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return null;
      _errorMessage = _boundedError(error);
      return null;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
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
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.forkThread(options);
      if (!_isCurrentRuntime(generation)) {
        return null;
      }
      if (_showArchived) {
        _showArchived = false;
        if (_savedSearchTerm != null) {
          _resetCatalogScope();
        }
      }
      _invalidateSavedSearch();
      final retained = _replaceOrPrepend(thread);
      _activateThread(retained);
      return retained;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return null;
      _errorMessage = _boundedError(error);
      return null;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
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
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      final thread = await gateway.revertThread(
        threadId: threadId,
        beforeTurnId: beforeTurnId,
      );
      if (!_isCurrentRuntime(generation)) {
        return null;
      }
      final retainedThread = _replaceInPlace(_retainReceipt(thread));
      if (_selectedThread?.id == retainedThread.id) {
        _selectedThread = retainedThread;
      }
      _lastRevertedThreadId = retainedThread.id;
      _revertVersion += 1;
      _invalidateSavedSearch();
      return retainedThread;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return null;
      _errorMessage = _boundedError(error);
      return null;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
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
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      await gateway.compactThread(threadId);
      if (!_isCurrentRuntime(generation)) {
        return false;
      }
      return true;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return false;
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
    }
  }

  Future<bool> deleteThread(String threadId) async {
    if (_mutating) {
      return false;
    }
    _mutating = true;
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      await gateway.deleteThread(threadId);
      if (!_isCurrentRuntime(generation)) {
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
      _invalidateSavedSearch();
      return true;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return false;
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
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
    final generation = _runtimeGeneration;
    _hydratingGoal = true;
    try {
      while (_isCurrentRuntime(generation) &&
          _pendingGoalHydrationThreadId != null) {
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
        if (!_isCurrentRuntime(generation) ||
            _selectedThread?.id != threadId ||
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
      if (_isCurrentRuntime(generation)) _hydratingGoal = false;
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
    final generation = _runtimeGeneration;
    _goalOperationThreadId = threadId;
    _goalProjectionRevision += 1;
    _goalEventObserved = false;
    _errorMessage = null;
    _notify();
    try {
      final goal = await request(gateway);
      if (!_isCurrentRuntime(generation) || !canManageGoal(threadId)) {
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
      if (!_isCurrentRuntime(generation)) return null;
      if (_isCurrentRuntime(generation)) {
        _errorMessage = _boundedError(error);
      }
      return null;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _goalOperationThreadId = null;
        _goalEventObserved = false;
        _mutating = false;
        _notify();
      }
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
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      final section = await sectionGateway.createThreadSection(
        ThreadSectionCreateOptions(name: trimmed, appearance: appearance),
      );
      if (!_isCurrentRuntime(generation)) {
        return null;
      }
      _upsertSection(section);
      return section;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return null;
      _errorMessage = _boundedError(error);
      return null;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
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
    final generation = _runtimeGeneration;
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
      if (!_isCurrentRuntime(generation)) {
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
      if (!_isCurrentRuntime(generation)) return null;
      _errorMessage = _boundedError(error);
      return null;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
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
    final generation = _runtimeGeneration;
    _errorMessage = null;
    _notify();
    try {
      await sectionGateway.deleteThreadSection(normalizedId);
      if (!_isCurrentRuntime(generation)) {
        return false;
      }
      _sections.removeWhere((section) => section.id == normalizedId);
      if (_sectionScopeId == normalizedId) {
        _sectionScopeId = null;
        _catalogRevision += 1;
        _refreshCatalogPending = true;
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
      if (!_isCurrentRuntime(generation)) return false;
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
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
    final generation = _runtimeGeneration;
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
      if (!_isCurrentRuntime(generation)) {
        return false;
      }
      _applySectionChanged(threadId, sectionId);
      _invalidateSectionOrder();
      return true;
    } catch (error) {
      if (!_isCurrentRuntime(generation)) return false;
      _errorMessage = _boundedError(error);
      return false;
    } finally {
      if (_isCurrentRuntime(generation)) {
        _mutating = false;
        _notify();
      }
    }
  }

  bool selectedThreadNeedsResume(String threadId) =>
      _selectedThread?.id == threadId &&
      _selectedThread?.status == ThreadRuntimeStatus.notLoaded &&
      !_unmaterializedThreadIds.contains(threadId);

  Future<ThreadQueuePresence> selectedThreadQueuePresence(
    String threadId,
  ) async {
    if (_disposed || !selectedThreadNeedsResume(threadId)) {
      return ThreadQueuePresence.unknown;
    }
    final source = switch (gateway) {
      final ThreadQueuePresenceGateway queue
          when queue.supportsThreadQueuePresence =>
        queue,
      _ => null,
    };
    if (source == null) {
      return ThreadQueuePresence.unsupported;
    }
    try {
      return await source
          .readThreadQueuePresence(threadId)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => ThreadQueuePresence.unknown,
          );
    } catch (_) {
      return ThreadQueuePresence.unknown;
    }
  }

  Future<bool> ensureSelectedThreadLoaded(String threadId) async =>
      (await ensureSelectedThreadLoadedWithOutcome(threadId)).isLoaded;

  Future<ThreadResumeOutcome> ensureSelectedThreadLoadedWithOutcome(
    String threadId,
  ) async {
    final current = _selectedThread;
    if (current == null || current.id != threadId) {
      return const ThreadResumeOutcome.skipped();
    }
    if (selectedThreadNeedsDraftRecovery(threadId)) {
      return const ThreadResumeOutcome.failed(sessionDraftRecoveryMessage);
    }
    if (!selectedThreadNeedsResume(threadId)) {
      return ThreadResumeOutcome.loaded(current);
    }
    return resumeThreadWithOutcome(threadId);
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
          _retiredSessionDraftIds.remove(threadId);
        }
        _applyStatusUpdate(threadId, status);
        _notify();
      case ThreadExecutionSettingsChangedEvent(
        :final threadId,
        :final settings,
      ):
        _applyExecutionSettings(threadId, settings);
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
      case ThreadReadReceiptChangedEvent(:final threadId, :final receipt):
        if (_applyReadReceipt(threadId, receipt)) {
          _notify();
        }
      case ThreadSectionChangedEvent(:final threadId, :final sectionId):
        _applySectionChanged(threadId, sectionId);
        _invalidateSectionOrder();
        _notify();
      case ThreadArchivedEvent(:final threadId):
        _applyStatusUpdate(threadId, ThreadRuntimeStatus.notLoaded);
        if (!_showArchived) {
          final wasSelected = _selectedThread?.id == threadId;
          _threads.removeWhere((thread) => thread.id == threadId);
          if (wasSelected) {
            _selectedThread = _threads.isEmpty ? null : _threads.first;
          }
          _synchronizeSelection();
          _invalidateSectionOrder();
          _invalidateSavedSearch();
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
          _invalidateSavedSearch();
          _notify();
        } else if (_sectionScopeId != null || _savedSearchTerm != null) {
          _invalidateSectionOrder();
          _invalidateSavedSearch();
          _notify();
        }
      case ThreadRevertedEvent(:final threadId):
        _lastRevertedThreadId = threadId;
        _revertVersion += 1;
        _invalidateSavedSearch();
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
    _invalidateSavedSearch();
  }

  void _applyStatusUpdate(String threadId, ThreadRuntimeStatus status) {
    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index != -1) {
      _threads[index] = _threads[index].copyWith(
        status: status,
        clearExecutionSettings: status == ThreadRuntimeStatus.notLoaded,
      );
    }
    if (_selectedThread?.id == threadId) {
      _selectedThread = _selectedThread!.copyWith(
        status: status,
        clearExecutionSettings: status == ThreadRuntimeStatus.notLoaded,
      );
    }
  }

  void _applyExecutionSettings(
    String threadId,
    ThreadExecutionSettings settings,
  ) {
    ThreadSummary update(ThreadSummary thread) {
      if (thread.status == ThreadRuntimeStatus.notLoaded) return thread;
      final previous = thread.executionSettings;
      if (previous != null && previous.isNewerThan(settings)) return thread;
      return thread.copyWith(executionSettings: settings);
    }

    final index = _threads.indexWhere((thread) => thread.id == threadId);
    if (index != -1) _threads[index] = update(_threads[index]);
    if (_selectedThread?.id == threadId) {
      _selectedThread = update(_selectedThread!);
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

  bool _receiptChangedAfter(String threadId, int version) =>
      (_readReceiptVersions[threadId] ?? 0) > version;

  ThreadSummary _reconcileReceipt(ThreadSummary thread, int version) {
    if (!_receiptChangedAfter(thread.id, version)) {
      return thread;
    }
    final retained = _findThread(thread.id);
    if (retained == null) {
      return thread;
    }
    final current = retained.readReceipt;
    return thread.copyWith(
      readReceipt: current,
      clearReadReceipt: current == null,
    );
  }

  ThreadSummary _retainReceipt(ThreadSummary thread) {
    final receipt = _findThread(thread.id)?.readReceipt;
    return thread.readReceipt != null || receipt == null
        ? thread
        : thread.copyWith(readReceipt: receipt);
  }

  ThreadSummary _acceptReceiptSnapshot(ThreadSummary thread, int version) {
    final reconciled = _reconcileReceipt(thread, version);
    _applyReadReceipt(reconciled.id, reconciled.readReceipt);
    return reconciled;
  }

  bool _applyReadReceipt(String threadId, ThreadReadReceipt? receipt) {
    final thread = _findThread(threadId);
    if (thread == null ||
        thread.ephemeral ||
        (thread.readReceipt?.revision == receipt?.revision &&
            thread.readReceipt?.unread == receipt?.unread)) {
      return false;
    }
    final index = _threads.indexWhere((row) => row.id == threadId);
    if (index != -1) {
      _threads[index] = _threads[index].copyWith(
        readReceipt: receipt,
        clearReadReceipt: receipt == null,
      );
    }
    if (_selectedThread?.id == threadId) {
      _selectedThread = _selectedThread!.copyWith(
        readReceipt: receipt,
        clearReadReceipt: receipt == null,
      );
    }
    _readReceiptVersions[threadId] = ++_readReceiptVersion;
    if (_readReceiptVersions.length > maxRetainedThreads + 1) {
      final retainedIds = _threads.map((row) => row.id).toSet();
      _readReceiptVersions.removeWhere(
        (id, _) => !retainedIds.contains(id) && _selectedThread?.id != id,
      );
    }
    return true;
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
    final generation = _runtimeGeneration;
    final sectionGateway = _sectionGateway;
    if (sectionGateway == null) {
      _mergeThreadEmbeddedSections(threads);
      return;
    }
    try {
      final page = await sectionGateway.listThreadSections(
        const ThreadSectionListQuery(limit: maxRetainedSections),
      );
      if (!_isCurrentRuntime(generation)) {
        return;
      }
      _sections
        ..clear()
        ..addAll(page.sections.take(maxRetainedSections));
    } catch (error) {
      if (_isCurrentRuntime(generation)) _errorMessage = _boundedError(error);
    }
    if (_isCurrentRuntime(generation)) _mergeThreadEmbeddedSections(threads);
  }

  Future<void> _reloadSectionsAndResolveThread(
    String threadId,
    String sectionId,
  ) async {
    final generation = _runtimeGeneration;
    final sectionGateway = _sectionGateway;
    if (sectionGateway == null || _disposed) {
      return;
    }
    try {
      final page = await sectionGateway.listThreadSections(
        const ThreadSectionListQuery(limit: maxRetainedSections),
      );
      if (!_isCurrentRuntime(generation)) {
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
    if (_savedSearchTerm != null) {
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
    final incomingSettings = thread.executionSettings;
    final previousSettings = retained?.executionSettings;
    if (thread.status == ThreadRuntimeStatus.notLoaded) {
      thread = thread.copyWith(clearExecutionSettings: true);
    } else if (previousSettings != null &&
        (incomingSettings == null ||
            previousSettings.isNewerThan(incomingSettings))) {
      thread = thread.copyWith(executionSettings: previousSettings);
    }
    if (thread.goal != null) {
      return thread;
    }
    final goal = retained?.goal;
    return goal == null ? thread : thread.copyWith(goal: goal);
  }

  void _activateThread(ThreadSummary thread) {
    _selectedThread = thread;
    if (_sectionScopeId != null ||
        _savedSearchTerm != null ||
        _preserveOutsideCatalog) {
      _synchronizeSelection();
    }
  }

  void _synchronizeSelection({bool preserveSelection = false}) {
    final selectedId = _selectedThread?.id;
    final keepSelected =
        preserveSelection ||
        _sectionScopeId != null ||
        _savedSearchTerm != null ||
        _preserveOutsideCatalog;
    final retainedIds = {
      for (final thread in _threads) thread.id,
      if (keepSelected && selectedId != null) selectedId,
    };
    _unmaterializedThreadIds.retainAll(retainedIds);
    _retiredSessionDraftIds.retainAll(retainedIds);
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
    if (_refreshCatalogPending && !catalogBusy) {
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
