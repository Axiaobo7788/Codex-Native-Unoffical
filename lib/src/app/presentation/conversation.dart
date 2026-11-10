part of '../codex_native_app.dart';

enum PresentationDetailMode { prose, commands, execution }

typedef _CommandOutputPreviewKey = ({
  String turnId,
  String itemId,
  String reference,
  bool saved,
});
typedef _CommandOutputPresentation = ({Widget action, Widget? detail});

class _ConversationPanel extends StatefulWidget {
  const _ConversationPanel({
    super.key,
    required this.controller,
    this.threadController,
    required this.historyController,
    required this.approvalController,
    required this.userInputController,
    required this.settingsController,
    required this.diffController,
    required this.outputGateway,
    required this.transportCapabilities,
    this.defaultWorkingDirectory = '',
    this.hasDesktopShell = false,
    this.isOffstage = false,
  });

  final ConversationController controller;
  final ThreadListController? threadController;
  final HistoryController historyController;
  final ApprovalController approvalController;
  final UserInputController userInputController;
  final ExecutionSettingsController settingsController;
  final DiffController diffController;
  final OutputGateway outputGateway;
  final BackendCapabilities transportCapabilities;
  final String defaultWorkingDirectory;
  final bool hasDesktopShell;
  final bool isOffstage;

  @override
  State<_ConversationPanel> createState() => _ConversationPanelState();
}

class _ThreadScrollBookmark {
  const _ThreadScrollBookmark({
    required this.scrollPixels,
    required this.anchorItemKey,
    required this.anchorTurnId,
    required this.anchorViewportTopDy,
  });

  final double scrollPixels;
  final String anchorItemKey;
  final String anchorTurnId;
  final double anchorViewportTopDy;
}

class _VisibleAnchor {
  const _VisibleAnchor({
    required this.itemKey,
    required this.turnId,
    required this.viewportTopDy,
  });

  final String itemKey;
  final String turnId;
  final double viewportTopDy;
}

class _PendingTurnBranchEdit {
  const _PendingTurnBranchEdit({
    required this.threadId,
    required this.turnId,
    required this.userText,
    required this.attachments,
    this.assistantText,
  });

  final String threadId;
  final String turnId;
  final String userText;
  final List<UserAttachment> attachments;
  final String? assistantText;
}

class _ConversationPanelState extends State<_ConversationPanel> {
  static const _maxRetainedThreadScrollBookmarks = 32;
  static const _maxRetainedThreadDags = 32;
  static const _maxMeasuredItemHeights = 512;
  static const _maxRestorePages = 10;
  static const _maxRestoreAlignmentPasses = 32;
  static const _followThresholdPixels = 160.0;

  late final TextEditingController _composerController;
  late final FocusNode _composerFocusNode;
  final _composerInputKey = GlobalKey();
  final _approvalBannerKey = GlobalKey();
  final _userInputBannerKey = GlobalKey();
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final _conversationFocusNode = FocusNode();
  late final ScrollController _scrollController;
  final LinkedHashMap<String, _ThreadScrollBookmark> _threadScrollBookmarks =
      LinkedHashMap();
  final LinkedHashMap<String, ChatConversationDag> _threadChatDags =
      LinkedHashMap();
  final LinkedHashMap<String, double> _measuredItemHeights = LinkedHashMap();
  final Map<String, RenderBox> _mountedItemBoxes = <String, RenderBox>{};
  final Map<String, String> _mountedItemTurnIds = <String, String>{};
  List<String> _currentTimelineItemKeys = const [];
  List<String> _searchMatchItemKeys = const [];
  _VisibleAnchor? _preLoadOlderAnchor;
  _VisibleAnchor? _pendingStreamAnchor;
  _PendingTurnBranchEdit? _pendingBranchEdit;
  String? _activeThreadId;
  var _lastMeasuredItemWidth = 0.0;
  var _pendingThreadRestore = false;
  var _restoreScheduled = false;
  var _aligningScrollAnchor = false;
  var _wasLoadingOlderTurns = false;
  var _wasWindowShifted = false;
  var _lastHandledLoadOlderVersion = 0;
  var _lastHandledRevertVersion = 0;
  var _restorePagesLoaded = 0;
  var _restoreAlignmentPasses = 0;
  var _showJumpToLatest = false;
  var _showChanges = false;
  String? _goalEditorThreadId;
  final _goalEditorKey = GlobalKey();
  var _usingGoalEditorSidePane = false;
  bool? _usingChangesSidePane;
  var _searchOpen = false;
  var _checkingColdResume = false;
  var _threadSelectionVersion = 0;
  var _activeSearchMatchIndex = 0;
  var _branchSequence = 1;
  var _detailMode = PresentationDetailMode.commands;
  ({_CommandOutputPreviewKey key, OutputViewerController viewer})?
  _commandOutputPreview;
  var _commandPreviewReading = false;
  String? _customProjectDirectory;
  final _threadActionsPopoverController = CodexPopoverController();
  final _timelineDetailsPopoverController = CodexPopoverController();
  final _composerAttachPopoverController = CodexPopoverController();
  final _linkedPrsPopoverController = CodexPopoverController();
  final _linkedPrViewNotifier = ValueNotifier<int>(0);
  late final TextEditingController _linkedPrUrlController;
  late final TextEditingController _linkedPrBranchController;
  late final FocusNode _linkedPrUrlFocusNode;
  final List<UserAttachment> _composerAttachments = <UserAttachment>[];
  StreamSubscription<ThreadAttachmentEvent>? _attachmentEventSubscription;
  ThreadLinkedPullRequestsSnapshot? _activeThreadLinkedPrs;
  String? _linkedPrLoadError;
  String? _linkedPrLaunchError;
  String? _linkedPrMutationError;
  String? _linkedPrMutationNotice;
  String? _queuedLinkedPrThreadId;
  var _linkedPrScanInFlight = false;
  var _linkedPrFormOpen = false;
  var _linkedPrMutationInFlight = false;

  BackendCapabilities get _activeCapabilities => widget.transportCapabilities;

  ThreadAttachmentGateway? get _attachmentGateway =>
      switch (widget.outputGateway) {
        final ThreadAttachmentGateway g => g,
        _ => null,
      };

  String get _activeProjectDirectory {
    final selectedCwd = widget.controller.thread?.cwd;
    if (selectedCwd != null && selectedCwd.trim().isNotEmpty) {
      return selectedCwd.trim();
    }
    if (_customProjectDirectory != null &&
        _customProjectDirectory!.trim().isNotEmpty) {
      return _customProjectDirectory!.trim();
    }
    if (widget.defaultWorkingDirectory.trim().isNotEmpty) {
      return widget.defaultWorkingDirectory.trim();
    }
    final threads = widget.threadController?.threads;
    if (threads != null && threads.isNotEmpty) {
      return threads.first.cwd.trim();
    }
    return '';
  }

  Future<void> _chooseProjectDirectory() async {
    var directory = _activeProjectDirectory;
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select project directory'),
        content: SizedBox(
          width: 480,
          child: TextFormField(
            initialValue: directory,
            autofocus: true,
            onChanged: (value) => directory = value,
            decoration: const InputDecoration(
              labelText: 'Working directory',
              hintText: '/path/to/repository',
            ),
            onFieldSubmitted: (value) =>
                Navigator.of(context).pop(value.trim()),
          ),
        ),
        actions: [
          CodexButton(
            variant: CodexButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
            label: 'Cancel',
          ),
          CodexButton(
            variant: CodexButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(directory.trim()),
            label: 'Use directory',
          ),
        ],
      ),
    );
    if (next == null || next.isEmpty || !mounted) {
      return;
    }
    setState(() => _customProjectDirectory = next);
  }

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _composerFocusNode = FocusNode();
    _linkedPrUrlController = TextEditingController();
    _linkedPrBranchController = TextEditingController();
    _linkedPrUrlFocusNode = FocusNode();
    _searchController = TextEditingController()
      ..addListener(_handleSearchQueryChanged);
    _searchFocusNode = FocusNode();
    _scrollController = ScrollController(keepScrollOffset: false)
      ..addListener(_handleScrollPositionChanged);
    _activeThreadId = widget.controller.thread?.id;
    _pendingThreadRestore = _activeThreadId != null;
    _wasLoadingOlderTurns = widget.historyController.loadingOlderTurns;
    _wasWindowShifted = widget.historyController.canReturnToNewest;
    _lastHandledLoadOlderVersion = widget.historyController.loadOlderVersion;
    _lastHandledRevertVersion = widget.threadController?.revertVersion ?? 0;
    _composerFocusNode.addListener(_handleComposerFocusChanged);
    widget.controller.addListener(_handleConversationChanged);
    widget.historyController.addListener(_handleHistoryChanged);
    widget.threadController?.addListener(_handleThreadListChanged);
    _bindAttachmentEvents();
    if (_activeThreadId case final activeId?) {
      _requestActiveThreadLinkedPrs(activeId);
      if (!widget.isOffstage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !widget.isOffstage) {
            _conversationFocusNode.requestFocus();
          }
        });
      }
    }
  }

  bool get hasComposerDraft =>
      _composerController.text.isNotEmpty || _composerAttachments.isNotEmpty;

  bool get _hasReadyScrollPosition {
    if (!_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
    return position.hasPixels &&
        position.hasViewportDimension &&
        position.hasContentDimensions;
  }

  void _bindAttachmentEvents() {
    unawaited(_attachmentEventSubscription?.cancel());
    _attachmentEventSubscription = _attachmentGateway?.threadAttachmentEvents
        .listen(_handleThreadAttachmentEvent, onError: (_) {});
  }

  void _handleThreadAttachmentEvent(ThreadAttachmentEvent event) {
    if (!mounted) {
      return;
    }
    if (event is ThreadAttachmentUpdatedEvent &&
        event.attachmentType == 'pull_request' &&
        event.threadId == _activeThreadId) {
      _requestActiveThreadLinkedPrs(event.threadId);
    }
  }

  void _notifyLinkedPrViewChanged() {
    _linkedPrViewNotifier.value += 1;
  }

  void _requestActiveThreadLinkedPrs(String threadId) {
    final gateway = _attachmentGateway;
    if (gateway == null || !gateway.supportsThreadAttachments) {
      _queuedLinkedPrThreadId = null;
      if ((_activeThreadLinkedPrs != null ||
              _linkedPrLoadError != null ||
              _linkedPrLaunchError != null ||
              _linkedPrMutationError != null ||
              _linkedPrMutationNotice != null) &&
          mounted) {
        setState(() {
          _activeThreadLinkedPrs = null;
          _linkedPrLoadError = null;
          _linkedPrLaunchError = null;
          _linkedPrMutationError = null;
          _linkedPrMutationNotice = null;
          _notifyLinkedPrViewChanged();
        });
      }
      return;
    }
    _queuedLinkedPrThreadId = threadId;
    if (_linkedPrScanInFlight) {
      return;
    }
    unawaited(_drainQueuedLinkedPrScan());
  }

  static const int _maxLinkedPrErrorChars = 160;
  static final RegExp _linkedPrErrorControlChars = RegExp(r'[\x00-\x1F\x7F]+');

  static String _boundedLinkedPrError(Object error, {required String prefix}) {
    final raw = error.toString();
    final singleLine = raw
        .replaceAll(_linkedPrErrorControlChars, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (singleLine.isEmpty) {
      return '$prefix.';
    }
    final combined = '$prefix: $singleLine';
    if (combined.length <= _maxLinkedPrErrorChars) {
      return combined;
    }
    return '${combined.substring(0, _maxLinkedPrErrorChars - 1)}…';
  }

  Future<void> _drainQueuedLinkedPrScan() async {
    if (_linkedPrScanInFlight) {
      return;
    }
    _linkedPrScanInFlight = true;
    if (mounted) {
      setState(_notifyLinkedPrViewChanged);
    }
    try {
      while (mounted && _queuedLinkedPrThreadId != null) {
        final targetThreadId = _queuedLinkedPrThreadId!;
        _queuedLinkedPrThreadId = null;
        if (targetThreadId != _activeThreadId) {
          continue;
        }
        final gateway = _attachmentGateway;
        if (gateway == null || !gateway.supportsThreadAttachments) {
          if (mounted && _activeThreadId == targetThreadId) {
            setState(() {
              _activeThreadLinkedPrs = null;
              _linkedPrLoadError = null;
              _linkedPrLaunchError = null;
              _linkedPrMutationError = null;
              _linkedPrMutationNotice = null;
              _linkedPrFormOpen = false;
              _linkedPrsPopoverController.hide();
              _notifyLinkedPrViewChanged();
            });
          }
          break;
        }
        try {
          final snapshot = await gateway.readLinkedPullRequests(targetThreadId);
          if (!mounted || _activeThreadId != targetThreadId) {
            continue;
          }
          setState(() {
            _activeThreadLinkedPrs = snapshot;
            _linkedPrLoadError = null;
            _linkedPrLaunchError = null;
            _notifyLinkedPrViewChanged();
          });
        } on Object catch (error) {
          if (!mounted || _activeThreadId != targetThreadId) {
            continue;
          }
          if (!gateway.supportsThreadAttachments) {
            setState(() {
              _activeThreadLinkedPrs = null;
              _linkedPrLoadError = null;
              _linkedPrLaunchError = null;
              _linkedPrMutationError = null;
              _linkedPrMutationNotice = null;
              _linkedPrFormOpen = false;
              _linkedPrsPopoverController.hide();
              _notifyLinkedPrViewChanged();
            });
            break;
          }
          setState(() {
            _activeThreadLinkedPrs = null;
            _linkedPrLoadError = _boundedLinkedPrError(
              error,
              prefix: 'Could not load linked pull requests',
            );
            _notifyLinkedPrViewChanged();
          });
        }
      }
    } finally {
      _linkedPrScanInFlight = false;
      if (mounted) {
        setState(_notifyLinkedPrViewChanged);
      }
    }
  }

  Future<void> _submitLinkPullRequest(String threadId) async {
    if (_linkedPrMutationInFlight) {
      return;
    }
    final gateway = _attachmentGateway;
    if (gateway == null || !gateway.supportsThreadAttachmentWrites) {
      return;
    }
    final rawUrl = _linkedPrUrlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _linkedPrMutationError =
            'Enter a GitHub Pull Request or GitLab Merge Request HTTPS URL.';
        _linkedPrMutationNotice = null;
        _notifyLinkedPrViewChanged();
      });
      return;
    }
    final rawBranch = _linkedPrBranchController.text.trim();
    setState(() {
      _linkedPrMutationInFlight = true;
      _linkedPrMutationError = null;
      _linkedPrMutationNotice = null;
      _linkedPrLaunchError = null;
      _notifyLinkedPrViewChanged();
    });
    try {
      final result = await gateway.linkPullRequest(
        threadId,
        url: rawUrl,
        headBranch: rawBranch.isEmpty ? null : rawBranch,
      );
      if (!mounted || _activeThreadId != threadId) {
        return;
      }
      if (result.outcome == ThreadPullRequestLinkOutcome.scanIncomplete) {
        setState(() {
          _linkedPrMutationError =
              'Could not verify existing links for ${result.displayLabel} '
              'because the attachment scan was incomplete.';
          _linkedPrMutationNotice = null;
          _notifyLinkedPrViewChanged();
        });
        return;
      }
      final hiddenByCap = result.hiddenByDisplayCap;
      _linkedPrUrlController.clear();
      _linkedPrBranchController.clear();
      setState(() {
        _linkedPrFormOpen = false;
        _linkedPrMutationError = null;
        _linkedPrMutationNotice = switch (result.outcome) {
          ThreadPullRequestLinkOutcome.created when hiddenByCap =>
            'Saved ${result.displayLabel} to this thread '
                '(outside the displayed pull requests).',
          ThreadPullRequestLinkOutcome.created =>
            'Linked ${result.displayLabel} to this thread.',
          ThreadPullRequestLinkOutcome.existing when hiddenByCap =>
            'Already linked to ${result.displayLabel} '
                '(existing stored record preserved; outside the displayed pull requests).',
          ThreadPullRequestLinkOutcome.existing =>
            'Already linked to ${result.displayLabel} '
                '(existing stored record preserved).',
          ThreadPullRequestLinkOutcome.scanIncomplete => null,
        };
        _notifyLinkedPrViewChanged();
      });
      _requestActiveThreadLinkedPrs(threadId);
    } on ArgumentError catch (error) {
      if (!mounted || _activeThreadId != threadId) {
        return;
      }
      setState(() {
        _linkedPrMutationError = _boundedLinkedPrError(
          error.message ?? 'Invalid pull request URL or branch.',
          prefix: 'Invalid pull request link',
        );
        _linkedPrMutationNotice = null;
        _notifyLinkedPrViewChanged();
      });
    } on Object catch (error) {
      if (!mounted || _activeThreadId != threadId) {
        return;
      }
      if (!gateway.supportsThreadAttachments) {
        setState(() {
          _activeThreadLinkedPrs = null;
          _linkedPrLoadError = null;
          _linkedPrLaunchError = null;
          _linkedPrMutationError = null;
          _linkedPrMutationNotice = null;
          _linkedPrFormOpen = false;
          _linkedPrsPopoverController.hide();
          _notifyLinkedPrViewChanged();
        });
        return;
      }
      if (!gateway.supportsThreadAttachmentWrites) {
        setState(() {
          _linkedPrFormOpen = false;
          _linkedPrMutationError =
              'Linking pull requests is unavailable on this runtime.';
          _linkedPrMutationNotice = null;
          _notifyLinkedPrViewChanged();
        });
        return;
      }
      setState(() {
        _linkedPrMutationError = _boundedLinkedPrError(
          error,
          prefix: 'Could not link pull request',
        );
        _linkedPrMutationNotice = null;
        _notifyLinkedPrViewChanged();
      });
    } finally {
      if (mounted) {
        setState(() {
          _linkedPrMutationInFlight = false;
          _notifyLinkedPrViewChanged();
        });
      } else {
        _linkedPrMutationInFlight = false;
      }
    }
  }

  Future<void> _openSanitizedPullRequest(ThreadLinkedPullRequest pr) async {
    final uri = Uri.tryParse(pr.canonicalUrl);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.hasPort ||
        (uri.host != 'github.com' && uri.host != 'gitlab.com')) {
      if (mounted) {
        setState(() {
          _linkedPrLaunchError =
              'Refused to open non-canonical pull request URL.';
          _notifyLinkedPrViewChanged();
        });
      }
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        setState(() {
          _linkedPrLaunchError =
              'The browser could not open ${pr.canonicalUrl}.';
          _notifyLinkedPrViewChanged();
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _linkedPrLaunchError = _boundedLinkedPrError(
            error,
            prefix: 'The browser could not open the URL',
          );
          _notifyLinkedPrViewChanged();
        });
      }
    }
  }

  void _handleComposerFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant _ConversationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.threadController, widget.threadController)) {
      oldWidget.threadController?.removeListener(_handleThreadListChanged);
      _lastHandledRevertVersion = widget.threadController?.revertVersion ?? 0;
      widget.threadController?.addListener(_handleThreadListChanged);
    }
    if (!identical(oldWidget.outputGateway, widget.outputGateway)) {
      _clearCommandOutputPreview();
      _bindAttachmentEvents();
      if (_activeThreadId case final activeId?) {
        _requestActiveThreadLinkedPrs(activeId);
      }
    }
    if (oldWidget.hasDesktopShell && !widget.hasDesktopShell) {
      _goalEditorThreadId = null;
      _clearCommandOutputPreview();
      _timelineDetailsPopoverController.hide();
    }
    if (!oldWidget.isOffstage && widget.isOffstage) {
      _threadActionsPopoverController.hide();
      _timelineDetailsPopoverController.hide();
      _composerAttachPopoverController.hide();
      _linkedPrsPopoverController.hide();
    } else if (oldWidget.isOffstage && !widget.isOffstage) {
      if (_pendingThreadRestore && _activeThreadId != null) {
        _scheduleThreadScrollRestore();
      } else {
        _runAfterFrame(_handleScrollPositionChanged);
      }
      if (_activeThreadId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || widget.isOffstage) {
            return;
          }
          if (widget.controller.thread != null &&
              widget.controller.entries.isEmpty &&
              widget.historyController.timelineItems.isEmpty &&
              !widget.historyController.loadingTurns &&
              !widget.controller.busy) {
            _composerFocusNode.requestFocus();
          } else if (!_conversationFocusNode.hasFocus) {
            _conversationFocusNode.requestFocus();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _clearCommandOutputPreview();
    unawaited(_attachmentEventSubscription?.cancel());
    widget.threadController?.removeListener(_handleThreadListChanged);
    widget.controller.removeListener(_handleConversationChanged);
    widget.historyController.removeListener(_handleHistoryChanged);
    _scrollController
      ..removeListener(_handleScrollPositionChanged)
      ..dispose();
    _threadActionsPopoverController.dispose();
    _timelineDetailsPopoverController.dispose();
    _composerAttachPopoverController.dispose();
    _linkedPrsPopoverController.dispose();
    _linkedPrViewNotifier.dispose();
    _linkedPrUrlFocusNode.dispose();
    _linkedPrUrlController.dispose();
    _linkedPrBranchController.dispose();
    _searchController
      ..removeListener(_handleSearchQueryChanged)
      ..dispose();
    _searchFocusNode.dispose();
    _conversationFocusNode.dispose();
    _composerFocusNode
      ..removeListener(_handleComposerFocusChanged)
      ..dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _openConversationSearch() {
    if (widget.controller.thread == null ||
        !_activeCapabilities.supportsInConversationSearch) {
      return;
    }
    if (!_searchOpen) {
      widget.historyController.clearOccurrenceSearch();
      setState(() {
        _searchOpen = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _toggleConversationSearch() {
    if (_searchOpen) {
      _closeConversationSearch();
    } else {
      _openConversationSearch();
    }
  }

  void _closeConversationSearch() {
    if (!_searchOpen) {
      return;
    }
    widget.historyController.clearOccurrenceSearch();
    setState(() {
      _searchOpen = false;
      _searchController.clear();
      _searchMatchItemKeys = const [];
      _activeSearchMatchIndex = 0;
    });
  }

  void _handleSearchQueryChanged() {
    if (!mounted || !_searchOpen) {
      return;
    }
    setState(() {
      _activeSearchMatchIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searchMatchItemKeys.isNotEmpty) {
        _jumpToSearchMatch(0);
      }
    });
  }

  void _jumpToSearchMatch(int index) {
    if (_searchMatchItemKeys.isEmpty) {
      return;
    }
    final normalized =
        ((index % _searchMatchItemKeys.length) + _searchMatchItemKeys.length) %
        _searchMatchItemKeys.length;
    setState(() {
      _activeSearchMatchIndex = normalized;
    });
    final targetKey = _searchMatchItemKeys[normalized];
    _schedulePostLoadAnchorAlignment(
      _VisibleAnchor(itemKey: targetKey, turnId: '', viewportTopDy: 48.0),
      pass: 0,
    );
  }

  Future<void> _openSavedOccurrence(HistoryOccurrence occurrence) async {
    final threadId = widget.controller.thread?.id;
    final turn = await widget.historyController.openOccurrence(occurrence);
    if (!mounted ||
        !_searchOpen ||
        widget.controller.thread?.id != threadId ||
        turn == null) {
      return;
    }
    final visibleItems = turn.items.where(
      (item) =>
          item.kind == HistoryItemKind.user ||
          item.kind == HistoryItemKind.assistant,
    );
    final target =
        visibleItems
            .where((item) => item.id == occurrence.itemId)
            .firstOrNull ??
        visibleItems.firstOrNull;
    if (target == null) {
      return;
    }
    _pendingThreadRestore = false;
    _preLoadOlderAnchor = null;
    _pendingStreamAnchor = null;
    if (_showChanges || _goalEditorThreadId != null) {
      setState(() {
        _showChanges = false;
        _goalEditorThreadId = null;
      });
    }
    _schedulePostLoadAnchorAlignment(
      _VisibleAnchor(
        itemKey: 'history-${target.id}',
        turnId: turn.id,
        viewportTopDy: 48,
      ),
      pass: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _openConversationSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _openConversationSearch,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchOpen) {
            _closeConversationSearch();
          } else if (_goalEditorThreadId != null) {
            _closeGoalEditor();
          }
        },
      },
      child: Focus(
        focusNode: _conversationFocusNode,
        skipTraversal: true,
        child: ColoredBox(
          color: theme.workspaceBackground,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              widget.controller,
              if (widget.threadController != null) widget.threadController!,
              widget.diffController,
              widget.historyController,
              widget.approvalController,
              widget.userInputController,
            ]),
            builder: (context, _) {
              final controller = widget.controller;
              if (controller.thread == null &&
                  !(_showChanges && widget.diffController.snapshot != null)) {
                _currentTimelineItemKeys = const [];
                _searchMatchItemKeys = const [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _conversationHeader(controller),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal:
                                OfficialCodexTheme.threadBodyInlinePadding,
                            vertical: 20,
                          ),
                          child: ConstrainedBox(
                            key: const ValueKey('conversation_reading_column'),
                            constraints: const BoxConstraints(
                              maxWidth: OfficialCodexTheme.maxContentWidth,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ConversationEmptyState(
                                  workingDirectory: _activeProjectDirectory,
                                  onChooseDirectory:
                                      _activeCapabilities
                                          .supportsWorkingDirectorySelection
                                      ? _chooseProjectDirectory
                                      : null,
                                ),
                                const SizedBox(height: 22),
                                _ApprovalBanner(
                                  controller: widget.approvalController,
                                ),
                                _UserInputBanner(
                                  controller: widget.userInputController,
                                  desktop: widget.hasDesktopShell,
                                ),
                                _composer(controller, isHeroCentered: true),
                                const SizedBox(height: 14),
                                _StarterSuggestionRow(
                                  onSelectSuggestion: (prompt) {
                                    setState(() {
                                      _composerController.value =
                                          TextEditingValue(
                                            text: prompt,
                                            selection: TextSelection.collapsed(
                                              offset: prompt.length,
                                            ),
                                          );
                                    });
                                    _composerFocusNode.requestFocus();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return _activeWorkspace(controller);
            },
          ),
        ),
      ),
    );
  }

  Widget _activeWorkspace(ConversationController controller) {
    final changes = widget.diffController.snapshot;
    final threadId = controller.thread?.id;
    final threadController = widget.threadController;
    final goal = threadId == null
        ? null
        : threadController?.goalForThread(threadId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortViewport = constraints.maxHeight < 560;
        final constrainApproval =
            shortViewport && widget.approvalController.pending.isNotEmpty;
        final constrainUserInput =
            shortViewport &&
            (widget.userInputController.pending.isNotEmpty ||
                widget.userInputController.pendingElicitations.isNotEmpty);
        final approvalBanner = _ApprovalBanner(
          key: _approvalBannerKey,
          controller: widget.approvalController,
        );
        final userInputBanner = _UserInputBanner(
          key: _userInputBannerKey,
          controller: widget.userInputController,
          desktop: widget.hasDesktopShell,
        );
        // The official resize coordinator switches pane behavior at a 960 px
        // workspace. Keep the compact replacement view below that boundary.
        final canSplit = widget.hasDesktopShell && constraints.maxWidth > 960;
        final showingChanges = _showChanges && changes != null;
        final sidePane = showingChanges && canSplit;
        final goalEditor =
            widget.hasDesktopShell &&
                threadId != null &&
                threadId == _goalEditorThreadId &&
                threadController != null &&
                goal != null &&
                goal.status != ThreadGoalStatus.complete
            ? _DesktopGoalEditor(
                key: _goalEditorKey,
                goal: goal,
                saving: threadController.mutating,
                onClose: _closeGoalEditor,
                onSave: (objective) async {
                  await _applyThreadGoalChange(
                    context,
                    threadController,
                    threadId,
                    goal,
                    (objective: objective, status: null, clear: false),
                    canContinue: () =>
                        controller.thread?.id == threadId &&
                        _goalEditorThreadId == threadId &&
                        threadController.canManageGoal(threadId),
                  );
                },
              )
            : null;
        // The right task panel reserves 320 px for itself and 352 px for chat.
        final splitGoalEditor =
            goalEditor != null && constraints.maxWidth >= 672;
        final sidePaneWidth = math.max(
          320.0,
          math.max(
            math.min(1.6 * constraints.maxHeight, constraints.maxWidth - 500),
            math.min(640.0, constraints.maxWidth - 352),
          ),
        );
        if ((sidePane && _usingChangesSidePane == false) ||
            (splitGoalEditor && !_usingGoalEditorSidePane)) {
          _restoreReadingPosition();
        }
        _usingChangesSidePane = showingChanges ? sidePane : null;
        _usingGoalEditorSidePane = splitGoalEditor;
        final VoidCallback? toggleSidePanel;
        if (goalEditor != null) {
          toggleSidePanel = _closeGoalEditor;
        } else if (showingChanges || (changes?.files.isNotEmpty ?? false)) {
          toggleSidePanel = () => _toggleChanges(keepsTimeline: canSplit);
        } else if (threadId != null &&
            goal != null &&
            goal.status != ThreadGoalStatus.complete &&
            threadController?.canManageGoal(threadId) == true) {
          toggleSidePanel = () => _openGoalEditor(threadId);
        } else {
          toggleSidePanel = null;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _conversationHeader(
                    controller,
                    sidePanelOpen: showingChanges || goalEditor != null,
                    onToggleSidePanel: toggleSidePanel,
                  ),
                  if (_searchOpen && controller.thread != null) ...[
                    _conversationSearchBar(),
                    _savedOccurrenceResults(),
                  ],
                  if (controller.thread != null &&
                      (controller.latestWarning != null ||
                          controller.latestModelReroute != null))
                    _telemetryNoticeBar(controller),
                  if (controller.thread != null &&
                      controller.latestTurnPlan != null &&
                      controller.latestTurnPlan!.steps.isNotEmpty)
                    _turnPlanBanner(controller),
                  if (controller.thread != null && controller.reviewModeActive)
                    _reviewModeBanner(controller),
                  Expanded(
                    child: showingChanges && !sidePane
                        ? _DiffView(controller: widget.diffController)
                        : goalEditor != null && !splitGoalEditor
                        ? goalEditor
                        : _timeline(controller),
                  ),
                  if (widget.hasDesktopShell &&
                      !showingChanges &&
                      changes != null &&
                      changes.files.isNotEmpty)
                    _desktopChangesSummary(
                      changes,
                      canSplit: canSplit,
                      running: controller.busy,
                    ),
                  if (widget.hasDesktopShell &&
                      threadId != null &&
                      threadController != null &&
                      goal != null &&
                      goal.status != ThreadGoalStatus.complete)
                    _desktopGoalStrip(
                      goal,
                      threadController,
                      threadId,
                      isCurrent: () => controller.thread?.id == threadId,
                      showElapsed: constraints.maxWidth >= 320,
                    ),
                  if (constrainApproval && constrainUserInput)
                    Flexible(
                      flex: 5,
                      child: SingleChildScrollView(
                        key: const ValueKey('conversation-request-scroll'),
                        child: Column(
                          children: [approvalBanner, userInputBanner],
                        ),
                      ),
                    )
                  else ...[
                    Flexible(
                      flex: constrainApproval ? 5 : 0,
                      child: approvalBanner,
                    ),
                    Flexible(
                      flex: constrainUserInput ? 5 : 0,
                      child: userInputBanner,
                    ),
                  ],
                  _composer(controller),
                ],
              ),
            ),
            if (sidePane)
              _DesktopChangesPane(
                width: sidePaneWidth,
                controller: widget.diffController,
                onClose: () => _toggleChanges(keepsTimeline: true),
              ),
            if (splitGoalEditor)
              SizedBox(width: sidePaneWidth, child: goalEditor),
          ],
        );
      },
    );
  }

  Widget _conversationSearchBar() {
    final palette = ThemeTokens.of(context);
    final history = widget.historyController;
    final query = _searchController.text.trim();
    final matchCount = _searchMatchItemKeys.length;
    final scope = history.supportsOccurrenceSearch ? ' loaded' : '';
    final statusLabel = query.isEmpty
        ? 'Type to search'
        : matchCount == 0
        ? '0$scope matches'
        : '${(_activeSearchMatchIndex + 1).clamp(1, matchCount)} of $matchCount$scope';
    return Container(
      key: const ValueKey('conversation-search-bar'),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.space4),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border(
          bottom: BorderSide(
            color: palette.border,
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 15, color: palette.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('conversation-search-field'),
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: Theme.of(context).textTheme.bodySmall,
                  decoration: InputDecoration(
                    hintText: history.supportsOccurrenceSearch
                        ? 'Find in loaded messages…'
                        : 'Find in conversation…',
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onChanged: (_) => history.clearOccurrenceSearch(),
                  onSubmitted: (_) {
                    if (matchCount > 0) {
                      _jumpToSearchMatch(_activeSearchMatchIndex + 1);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                key: const ValueKey('conversation-search-count'),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(width: 6),
              CodexIconButton(
                key: const ValueKey('conversation-search-prev'),
                tooltip: 'Previous match',
                size: 26,
                onPressed: matchCount > 0
                    ? () => _jumpToSearchMatch(_activeSearchMatchIndex - 1)
                    : null,
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 16),
              ),
              CodexIconButton(
                key: const ValueKey('conversation-search-next'),
                tooltip: 'Next match',
                size: 26,
                onPressed: matchCount > 0
                    ? () => _jumpToSearchMatch(_activeSearchMatchIndex + 1)
                    : null,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              ),
              if (history.supportsOccurrenceSearch)
                CodexIconButton(
                  key: const ValueKey('conversation-search-saved'),
                  tooltip: 'Search saved messages',
                  size: 26,
                  onPressed:
                      query.isNotEmpty &&
                          query.length <=
                              HistoryOccurrenceQuery.maxSearchTermLength &&
                          !history.occurrenceUnsupported
                      ? () => history.searchOccurrences(query)
                      : null,
                  icon: const Icon(Icons.manage_search_rounded, size: 16),
                ),
              CodexIconButton(
                key: const ValueKey('conversation-search-close'),
                tooltip: 'Close search (Esc)',
                size: 26,
                onPressed: _closeConversationSearch,
                icon: const Icon(Icons.close_rounded, size: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _savedOccurrenceResults() {
    final history = widget.historyController;
    final page = history.occurrencePage;
    final error = history.occurrenceError;
    if (page == null &&
        error == null &&
        !history.occurrenceLoading &&
        !history.occurrenceUnsupported) {
      return const SizedBox.shrink();
    }
    final palette = ThemeTokens.of(context);
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final status = history.occurrenceUnsupported
        ? 'Saved search is unavailable for this thread. Find still searches loaded messages.'
        : error ??
              (history.occurrenceLoading
                  ? 'Searching saved messages…'
                  : history.openingOccurrence
                  ? 'Opening saved match…'
                  : page!.occurrences.isEmpty
                  ? 'No matches in saved messages'
                  : 'Saved matches');
    return ColoredBox(
      color: palette.surfaceRaised,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: ThemeTokens.space1,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          status,
                          key: const ValueKey(
                            'conversation-saved-search-status',
                          ),
                          style: textStyle?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      if (page?.nextCursor != null)
                        CodexButton(
                          key: const ValueKey('conversation-saved-search-next'),
                          variant: CodexButtonVariant.ghost,
                          size: CodexButtonSize.sm,
                          label: 'Next page',
                          onPressed:
                              history.occurrenceLoading ||
                                  history.openingOccurrence
                              ? null
                              : history.loadMoreOccurrences,
                        ),
                    ],
                  ),
                ),
                if (page != null && page.occurrences.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 128),
                    child: ListView.builder(
                      key: ObjectKey(page),
                      padding: EdgeInsets.zero,
                      primary: false,
                      shrinkWrap: true,
                      itemCount: page.occurrences.length,
                      itemBuilder: (context, index) {
                        final occurrence = page.occurrences[index];
                        final snippet = occurrence.snippet;
                        return CodexButton(
                          key: ValueKey('conversation-saved-search-hit-$index'),
                          variant: CodexButtonVariant.ghost,
                          size: CodexButtonSize.sm,
                          onPressed: history.canOpenOccurrence
                              ? () => _openSavedOccurrence(occurrence)
                              : null,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: snippet.substring(
                                      0,
                                      occurrence.matchStart,
                                    ),
                                  ),
                                  TextSpan(
                                    text: snippet.substring(
                                      occurrence.matchStart,
                                      occurrence.matchEnd,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: snippet.substring(
                                      occurrence.matchEnd,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _telemetryNoticeBar(ConversationController controller) {
    final palette = ThemeTokens.of(context);
    final reroute = controller.latestModelReroute;
    final warning = controller.latestWarning;
    final parts = <String>[
      if (reroute != null)
        'Model rerouted: ${reroute.fromModel} → ${reroute.toModel} (${reroute.reason})',
      if (warning != null && warning.isNotEmpty) warning,
    ];
    return Container(
      key: const ValueKey('conversation-telemetry-notice'),
      padding: const EdgeInsets.symmetric(
        horizontal: ThemeTokens.space4,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border(
          bottom: BorderSide(
            color: palette.border,
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: palette.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parts.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.textSecondary),
                ),
              ),
              const SizedBox(width: 6),
              CodexIconButton(
                key: const ValueKey('conversation-telemetry-notice-dismiss'),
                tooltip: 'Dismiss notice',
                size: 24,
                onPressed: controller.dismissTelemetryNotice,
                icon: const Icon(Icons.close_rounded, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _turnPlanBanner(ConversationController controller) {
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
    final plan = controller.latestTurnPlan!;
    final displayedSteps = plan.steps.take(6).toList(growable: false);
    return Container(
      key: const ValueKey('conversation-turn-plan-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: ThemeTokens.space4,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        border: Border(
          bottom: BorderSide(
            color: palette.border,
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    plan.allCompleted
                        ? Icons.check_circle_outline_rounded
                        : Icons.checklist_rounded,
                    size: 15,
                    color: plan.allCompleted ? palette.success : palette.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Plan (${plan.completedCount}/${plan.steps.length} completed)'
                      '${plan.explanation != null ? ' — ${plan.explanation}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  CodexIconButton(
                    key: const ValueKey('conversation-turn-plan-dismiss'),
                    tooltip: 'Hide plan banner',
                    size: 24,
                    onPressed: controller.dismissTurnPlan,
                    icon: const Icon(Icons.close_rounded, size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < displayedSteps.length; i++)
                    Container(
                      key: ValueKey('turn-plan-step-$i'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceRaised,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: palette.border,
                          width: OfficialCodexTheme.hairlineBorderWidth,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            switch (displayedSteps[i].status) {
                              TurnPlanStepStatus.completed =>
                                Icons.check_rounded,
                              TurnPlanStepStatus.inProgress =>
                                Icons.play_arrow_rounded,
                              _ => Icons.radio_button_unchecked_rounded,
                            },
                            size: 11,
                            color: switch (displayedSteps[i].status) {
                              TurnPlanStepStatus.completed => palette.success,
                              TurnPlanStepStatus.inProgress => palette.accent,
                              _ => palette.textMuted,
                            },
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              displayedSteps[i].step,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: palette.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (plan.steps.length > displayedSteps.length)
                    Text(
                      '+${plan.steps.length - displayedSteps.length} more',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: palette.textMuted),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewModeBanner(ConversationController controller) {
    final palette = ThemeTokens.of(context);
    return Container(
      key: const ValueKey('conversation-review-mode-banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: ThemeTokens.space4,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(
            color: palette.accent.withValues(alpha: 0.22),
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: Row(
            children: [
              Icon(Icons.rate_review_outlined, size: 15, color: palette.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reviewing ${controller.activeReviewDescription}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCompactTokens(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      final k = count / 1000;
      return k >= 100 ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
    }
    return '$count';
  }

  static String _tokenUsageDetails(ThreadTokenUsageSnapshot usage) =>
      'Thread total: ${usage.total.totalTokens} tokens '
      '(in ${usage.total.inputTokens}, cached ${usage.total.cachedInputTokens}, '
      'out ${usage.total.outputTokens}, reasoning ${usage.total.reasoningOutputTokens})\n'
      'Last turn: ${usage.last.totalTokens} tokens';

  Widget _composerContextUsage(ThreadTokenUsageSnapshot usage) {
    final theme = OfficialCodexTheme.of(context);
    final utilization = usage.contextWindowUtilization;
    final summary = utilization == null
        ? '${_formatCompactTokens(usage.total.totalTokens)} tokens'
        : 'Context usage: ${(utilization * 100).round()}% '
              '(${_formatCompactTokens(usage.total.totalTokens)} / '
              '${_formatCompactTokens(usage.modelContextWindow!)} tokens)';
    return CodexTooltip(
      message: '$summary\n${_tokenUsageDetails(usage)}',
      child: SizedBox.square(
        key: const ValueKey('composer-context-usage'),
        dimension: 14,
        child: utilization == null
            ? Icon(Icons.donut_large_rounded, size: 14, color: theme.textMuted)
            : CircularProgressIndicator(
                value: utilization,
                strokeWidth: 2,
                color: theme.textSecondary,
                backgroundColor: theme.hairlineBorder,
              ),
      ),
    );
  }

  Widget _conversationHeader(
    ConversationController controller, {
    bool sidePanelOpen = false,
    VoidCallback? onToggleSidePanel,
  }) {
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
    final thread = controller.thread;
    final threadController = widget.threadController;
    final changes = widget.diffController.snapshot;
    final projectCwd = thread?.cwd ?? _activeProjectDirectory;
    final hasProject =
        projectCwd.isNotEmpty &&
        _activeCapabilities.supportsWorkingDirectorySelection;
    final isHomeEmpty = thread == null;
    return Container(
      key: const ValueKey('thread_header_bar'),
      height: OfficialCodexTheme.headerHeight,
      padding: EdgeInsets.symmetric(
        horizontal: widget.hasDesktopShell
            ? ThemeTokens.space6
            : ThemeTokens.space4,
      ),
      decoration: BoxDecoration(
        color: theme.workspaceBackground,
        border: isHomeEmpty
            ? null
            : Border(
                bottom: BorderSide(
                  color: palette.border,
                  width: OfficialCodexTheme.hairlineBorderWidth,
                ),
              ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showSegment = thread != null && constraints.maxWidth >= 380;
          final showSearchButton =
              !widget.hasDesktopShell &&
              thread != null &&
              _activeCapabilities.supportsInConversationSearch &&
              constraints.maxWidth >= 520;
          final supportsLinkedPrs =
              _attachmentGateway?.supportsThreadAttachments ?? false;
          final linkedPrs = _activeThreadLinkedPrs?.threadId == thread?.id
              ? _activeThreadLinkedPrs
              : null;
          final compactLinkedPrs =
              constraints.maxWidth < 360 ||
              (linkedPrs?.isNotEmpty != true &&
                  linkedPrs?.truncated != true &&
                  _linkedPrLoadError == null);
          return Row(
            children: [
              Expanded(
                child: thread == null
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          if (widget.hasDesktopShell && hasProject) ...[
                            CodexTooltip(
                              message: projectCwd,
                              child: Icon(
                                Icons.folder_outlined,
                                size: 18,
                                color: palette.textSecondary,
                              ),
                            ),
                            const SizedBox(width: ThemeTokens.space3),
                          ],
                          Flexible(
                            child: Text(
                              thread.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: widget.hasDesktopShell
                                        ? FontWeight.w500
                                        : FontWeight.w600,
                                    fontSize: widget.hasDesktopShell
                                        ? 14
                                        : 13.5,
                                    letterSpacing: -0.1,
                                  ),
                            ),
                          ),
                          if (!widget.hasDesktopShell && supportsLinkedPrs) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: _buildLinkedPrHeaderPill(
                                context,
                                thread.id,
                                linkedPrs,
                                compact: false,
                              ),
                            ),
                          ],
                          if (!widget.hasDesktopShell &&
                              hasProject &&
                              constraints.maxWidth >= 680) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: CodexTooltip(
                                message: projectCwd,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.elevatedSurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.folder_outlined,
                                        size: 12,
                                        color: palette.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          _projectName(projectCwd),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: palette.textSecondary,
                                                fontSize: 11.5,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (controller.tokenUsage case final usage?
                              when !widget.hasDesktopShell &&
                                  constraints.maxWidth >= 680) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: CodexTooltip(
                                message: _tokenUsageDetails(usage),
                                child: Container(
                                  key: const ValueKey(
                                    'thread-token-usage-pill',
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.elevatedSurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    usage.modelContextWindow != null
                                        ? '${_formatCompactTokens(usage.total.totalTokens)} / '
                                              '${_formatCompactTokens(usage.modelContextWindow!)} tok '
                                              '(${((usage.contextWindowUtilization ?? 0) * 100).round()}%)'
                                        : '${_formatCompactTokens(usage.total.totalTokens)} tok',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: palette.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              if (!widget.hasDesktopShell &&
                  changes != null &&
                  (_showChanges || changes.files.isNotEmpty)) ...[
                CodexButton(
                  key: const ValueKey('changes-view-button'),
                  size: CodexButtonSize.sm,
                  variant: CodexButtonVariant.ghost,
                  onPressed: _toggleChanges,
                  icon: Icon(
                    _showChanges
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.difference_outlined,
                    size: 15,
                  ),
                  label: _showChanges
                      ? 'Conversation'
                      : 'Changes ${changes.files.length}',
                ),
                const SizedBox(width: ThemeTokens.space2),
              ],
              if (thread != null &&
                  widget.hasDesktopShell &&
                  supportsLinkedPrs) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(168.0, constraints.maxWidth * 0.34),
                  ),
                  child: _buildLinkedPrHeaderPill(
                    context,
                    thread.id,
                    linkedPrs,
                    compact: compactLinkedPrs,
                  ),
                ),
                const SizedBox(width: ThemeTokens.space1),
              ],
              if (!widget.hasDesktopShell && showSegment)
                CodexSegment<PresentationDetailMode>(
                  items: const [
                    CodexSegmentItem(
                      value: PresentationDetailMode.prose,
                      label: 'Prose',
                      tooltip: 'Only messages',
                    ),
                    CodexSegmentItem(
                      value: PresentationDetailMode.commands,
                      label: 'Commands',
                      tooltip: 'Grouped commands',
                    ),
                    CodexSegmentItem(
                      value: PresentationDetailMode.execution,
                      label: 'Execution',
                      tooltip: 'Full execution stream',
                    ),
                  ],
                  selectedValue: _detailMode,
                  onSelected: _setDetailMode,
                ),
              if (showSearchButton) ...[
                const SizedBox(width: ThemeTokens.space1),
                CodexIconButton(
                  key: const ValueKey('conversation-search-toggle'),
                  tooltip: 'Find in conversation (Ctrl+F)',
                  onPressed: _toggleConversationSearch,
                  icon: Icon(
                    Icons.search_rounded,
                    size: 17,
                    color: _searchOpen ? palette.accent : null,
                  ),
                ),
              ],
              if (thread != null && threadController != null) ...[
                const SizedBox(width: ThemeTokens.space1),
                CodexPopoverAnchor(
                  controller: _threadActionsPopoverController,
                  targetAnchor: Alignment.bottomRight,
                  followerAnchor: Alignment.topRight,
                  width: 196,
                  popoverBuilder: (context, close) {
                    final pinned = threadController.isPinnedThread(thread);
                    final canTogglePin = threadController.canTogglePinForThread(
                      thread,
                    );
                    final pinLabel = threadController.pinActionLabelForThread(
                      thread,
                    );
                    final archived = threadController.showArchived;
                    final capabilities = _activeCapabilities;
                    return CodexMenu<String>(
                      items: [
                        if (capabilities.supportsInConversationSearch)
                          const CodexMenuItem(
                            value: 'search',
                            label: 'Find in conversation',
                            icon: Icon(Icons.search_rounded),
                          ),
                        if (canTogglePin)
                          CodexMenuItem(
                            value: 'pin',
                            label: pinLabel,
                            icon: Icon(
                              pinned
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                            ),
                          ),
                        const CodexMenuItem(
                          value: 'rename',
                          label: 'Rename thread',
                          icon: Icon(Icons.drive_file_rename_outline_rounded),
                        ),
                        if (capabilities.supportsThreadFork)
                          const CodexMenuItem(
                            value: 'fork',
                            label: 'Fork thread',
                            icon: Icon(Icons.call_split_rounded),
                          ),
                        if (capabilities.supportsThreadCompact)
                          const CodexMenuItem(
                            value: 'compact',
                            label: 'Compact context',
                            icon: Icon(Icons.compress_rounded),
                          ),
                        if (_canStartThreadReview(thread.id)) ...[
                          const CodexMenuItem(
                            value: 'review',
                            label: 'Review uncommitted changes',
                            icon: Icon(Icons.rate_review_outlined),
                          ),
                          const CodexMenuItem(
                            value: 'review-target',
                            label: 'Code review…',
                            icon: Icon(Icons.manage_search_rounded),
                          ),
                        ],
                        CodexMenuItem(
                          value: 'archive',
                          label: archived
                              ? 'Unarchive thread'
                              : 'Archive thread',
                          icon: Icon(
                            archived
                                ? Icons.unarchive_outlined
                                : Icons.inventory_2_outlined,
                          ),
                        ),
                        const CodexMenuItem(
                          value: 'delete',
                          label: 'Delete thread',
                          icon: Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                      onSelected: (action) {
                        close();
                        switch (action) {
                          case 'search':
                            _openConversationSearch();
                          case 'pin':
                            unawaited(
                              threadController.togglePinThread(thread.id),
                            );
                          case 'rename':
                            unawaited(
                              _renameActiveThreadDialog(
                                threadController,
                                thread,
                              ),
                            );
                          case 'fork':
                            unawaited(
                              threadController.forkThread(
                                ThreadForkOptions(
                                  threadId: thread.id,
                                  cwd: thread.cwd,
                                ),
                              ),
                            );
                          case 'compact':
                            unawaited(
                              threadController.compactThread(thread.id),
                            );
                          case 'review':
                            unawaited(
                              _startThreadReview(
                                thread.id,
                                const UncommittedChangesReviewTarget(),
                              ),
                            );
                          case 'review-target':
                            unawaited(_startThreadReviewDialog(thread));
                          case 'archive':
                            if (archived) {
                              unawaited(
                                threadController.unarchiveThread(thread.id),
                              );
                            } else {
                              unawaited(
                                threadController.archiveThread(thread.id),
                              );
                            }
                          case 'delete':
                            unawaited(threadController.deleteThread(thread.id));
                        }
                      },
                    );
                  },
                  child: CodexIconButton(
                    key: const ValueKey('thread-actions-menu-button'),
                    tooltip: 'Thread actions (Codex)',
                    onPressed: threadController.mutating
                        ? null
                        : _threadActionsPopoverController.toggle,
                    icon: const Icon(Icons.more_horiz_rounded, size: 17),
                  ),
                ),
              ],
              if (thread != null && widget.hasDesktopShell) ...[
                const SizedBox(width: ThemeTokens.space1),
                _timelineDetailsButton(),
                if (onToggleSidePanel != null) ...[
                  const SizedBox(width: ThemeTokens.space1),
                  SizedBox(
                    height: 16,
                    child: VerticalDivider(
                      color: theme.hairlineBorder,
                      width: ThemeTokens.space2,
                      thickness: OfficialCodexTheme.hairlineBorderWidth,
                    ),
                  ),
                  CodexIconButton(
                    key: const ValueKey('workspace-side-panel-toggle'),
                    tooltip: 'Toggle side panel',
                    selected: sidePanelOpen,
                    onPressed: onToggleSidePanel,
                    icon: const Icon(Icons.view_sidebar_outlined, size: 17),
                  ),
                ],
              ],
              if (!widget.hasDesktopShell && controller.canInterrupt) ...[
                const SizedBox(width: ThemeTokens.space2),
                CodexButton(
                  size: CodexButtonSize.sm,
                  variant: CodexButtonVariant.danger,
                  onPressed: controller.interrupt,
                  icon: const Icon(Icons.stop_rounded, size: 16),
                  label: 'Stop',
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _toggleChanges({bool keepsTimeline = false}) {
    final threadId = _activeThreadId;
    if ((!_showChanges || keepsTimeline) &&
        threadId != null &&
        !_pendingThreadRestore) {
      _captureThreadScrollBookmark(threadId);
    }
    setState(() {
      _goalEditorThreadId = null;
      _showChanges = !_showChanges;
    });
    if (keepsTimeline || !_showChanges) {
      _restoreReadingPosition();
    }
  }

  void _restoreReadingPosition() {
    if (_activeThreadId == null) {
      return;
    }
    _pendingThreadRestore = true;
    _restorePagesLoaded = 0;
    _restoreAlignmentPasses = 0;
    _scheduleThreadScrollRestore();
  }

  void _openGoalEditor(String threadId) {
    if (_activeThreadId != threadId || _goalEditorThreadId == threadId) return;
    if (!_showChanges && !_pendingThreadRestore) {
      _captureThreadScrollBookmark(threadId);
    }
    setState(() {
      _showChanges = false;
      _goalEditorThreadId = threadId;
    });
  }

  void _closeGoalEditor() {
    setState(() => _goalEditorThreadId = null);
    _restoreReadingPosition();
  }

  Widget _desktopGoalStrip(
    ThreadGoal goal,
    ThreadListController controller,
    String threadId, {
    required bool Function() isCurrent,
    required bool showElapsed,
  }) {
    final theme = OfficialCodexTheme.of(context);
    final canManage = controller.canManageGoal(threadId);
    final actionsEnabled = canManage && !controller.mutating;
    final nextStatus = switch (goal.status) {
      ThreadGoalStatus.active => ThreadGoalStatus.paused,
      ThreadGoalStatus.paused ||
      ThreadGoalStatus.blocked ||
      ThreadGoalStatus.usageLimited => ThreadGoalStatus.active,
      _ => null,
    };
    void applyChange({ThreadGoalStatus? status, bool clear = false}) {
      unawaited(
        _applyThreadGoalChange(
          context,
          controller,
          threadId,
          goal,
          (objective: null, status: status, clear: clear),
          canContinue: () => isCurrent() && controller.canManageGoal(threadId),
        ),
      );
    }

    final budget = goal.tokenBudget;
    final budgetText =
        budget != null &&
            (goal.status == ThreadGoalStatus.active ||
                goal.status == ThreadGoalStatus.budgetLimited)
        ? '${_formatCompactTokens(goal.tokensUsed)} / ${_formatCompactTokens(budget)}'
        : null;
    final status = switch (goal.status) {
      ThreadGoalStatus.active => 'Pursuing goal',
      ThreadGoalStatus.paused => 'Paused goal',
      ThreadGoalStatus.blocked => 'Goal stalled',
      ThreadGoalStatus.usageLimited => 'Goal usage limited',
      ThreadGoalStatus.budgetLimited => 'Goal limited',
      ThreadGoalStatus.complete => 'Goal achieved',
      ThreadGoalStatus.unknown => 'Thread goal',
    };
    final openEditor = actionsEnabled ? () => _openGoalEditor(threadId) : null;
    final title = Row(
      children: [
        Icon(Icons.track_changes_outlined, size: 16, color: theme.textMuted),
        const SizedBox(width: ThemeTokens.space2),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: status,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: '  ${goal.objective}',
                  style: TextStyle(color: theme.textSecondary),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    const inlineInset = OfficialCodexTheme.composerTrayInlineInset;
    return Center(
      heightFactor: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16 + inlineInset,
          4,
          16 + inlineInset,
          4,
        ),
        child: Container(
          key: const ValueKey('desktop-thread-goal-strip'),
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.composerMaxWidth - 2 * inlineInset,
            minHeight: OfficialCodexTheme.navRowHeight,
          ),
          padding: EdgeInsetsDirectional.fromSTEB(
            openEditor == null ? 12 : 4,
            0,
            4,
            0,
          ),
          decoration: BoxDecoration(
            color: theme.modalSurface,
            border: Border.all(color: theme.hairlineBorder),
            borderRadius: BorderRadius.circular(
              OfficialCodexTheme.mainSurfaceRadius,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: openEditor == null
                    ? title
                    : CodexButton(
                        key: const ValueKey('desktop-thread-goal-title'),
                        tooltip: 'Open goal editor',
                        variant: CodexButtonVariant.ghost,
                        size: CodexButtonSize.sm,
                        onPressed: openEditor,
                        child: title,
                      ),
              ),
              if (showElapsed)
                _DesktopGoalUsage(goal: goal, budgetText: budgetText),
              if (canManage) ...[
                CodexIconButton(
                  key: const ValueKey('desktop-thread-goal-clear'),
                  tooltip: 'Clear goal',
                  onPressed: actionsEnabled
                      ? () => applyChange(clear: true)
                      : null,
                  size: 28,
                  icon: const Icon(Icons.delete_outline, size: 16),
                ),
                if (nextStatus != null)
                  CodexIconButton(
                    key: const ValueKey('desktop-thread-goal-status'),
                    tooltip: nextStatus == ThreadGoalStatus.active
                        ? 'Resume goal'
                        : 'Pause goal',
                    onPressed: actionsEnabled
                        ? () => applyChange(status: nextStatus)
                        : null,
                    size: 28,
                    icon: Icon(
                      nextStatus == ThreadGoalStatus.active
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                      size: 16,
                    ),
                  ),
                CodexIconButton(
                  key: const ValueKey('desktop-thread-goal-edit'),
                  tooltip: 'Edit goal',
                  onPressed: openEditor,
                  size: 28,
                  icon: const Icon(Icons.open_in_full_rounded, size: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopChangesSummary(
    DiffSnapshot snapshot, {
    required bool canSplit,
    required bool running,
  }) {
    final theme = OfficialCodexTheme.of(context);
    final count = snapshot.files.length;
    final label = snapshot.truncated
        ? count == 1
              ? '1 file shown'
              : '$count files shown'
        : count == 1
        ? '1 file changed'
        : '$count files changed';
    final preview = running;
    final summary = '$label, +${snapshot.additions} −${snapshot.deletions}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.isDark
                ? OfficialCodexTheme.darkChangesSummarySurface
                : OfficialCodexTheme.lightShellBackground,
            borderRadius: BorderRadius.circular(
              OfficialCodexTheme.changesSummaryRadius,
            ),
            border: Border.all(
              color: theme.hairlineBorder,
              width: OfficialCodexTheme.hairlineBorderWidth,
            ),
          ),
          child: _changesPreview(
            snapshot,
            enabled: preview,
            label: summary,
            canSplit: canSplit,
            child: CodexButton(
              key: const ValueKey('changes-view-button'),
              variant: CodexButtonVariant.ghost,
              onPressed: () => _toggleChanges(keepsTimeline: canSplit),
              tooltip: preview ? null : summary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    flex: 2,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: ThemeTokens.space2),
                  Flexible(
                    child: Text(
                      '+${snapshot.additions}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.diffAddedText),
                    ),
                  ),
                  const SizedBox(width: ThemeTokens.space1),
                  Flexible(
                    child: Text(
                      '-${snapshot.deletions}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.diffRemovedText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _changesPreview(
    DiffSnapshot snapshot, {
    required bool enabled,
    required String label,
    required bool canSplit,
    required Widget child,
  }) {
    if (!enabled) return child;
    final theme = OfficialCodexTheme.of(context);
    return Semantics(
      label: label,
      child: Tooltip(
        richMessage: WidgetSpan(
          child: SizedBox(
            key: const ValueKey('desktop-changes-file-preview'),
            width: 256,
            height: math.min(288.0, snapshot.files.length * 36.0),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemExtent: 36,
              itemCount: snapshot.files.length,
              itemBuilder: (context, index) {
                final file = snapshot.files[index];
                return Semantics(
                  label: file.path,
                  child: CodexButton(
                    size: CodexButtonSize.sm,
                    variant: CodexButtonVariant.ghost,
                    onPressed: () {
                      final current = widget.diffController.snapshot;
                      if (_showChanges ||
                          _activeThreadId != snapshot.threadId ||
                          current == null ||
                          current.turnId != snapshot.turnId ||
                          !current.files.any(
                            (entry) => entry.path == file.path,
                          )) {
                        return;
                      }
                      widget.diffController.selectFile(file.path);
                      _toggleChanges(keepsTimeline: canSplit);
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            file.path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.textPrimary),
                          ),
                        ),
                        const SizedBox(width: ThemeTokens.space2),
                        Text(
                          '+${file.additions}',
                          style: TextStyle(color: theme.diffAddedText),
                        ),
                        const SizedBox(width: ThemeTokens.space1),
                        Text(
                          '−${file.deletions}',
                          style: TextStyle(color: theme.diffRemovedText),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        excludeFromSemantics: true,
        preferBelow: false,
        verticalOffset: 24,
        waitDuration: const Duration(milliseconds: 300),
        exitDuration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.elevatedSurface,
          border: Border.all(color: theme.hairlineBorder),
          borderRadius: BorderRadius.circular(OfficialCodexTheme.popoverRadius),
          boxShadow: const [OfficialCodexTheme.shellPageShadow],
        ),
        child: child,
      ),
    );
  }

  Widget _timelineDetailsButton() => CodexPopoverAnchor(
    controller: _timelineDetailsPopoverController,
    targetAnchor: Alignment.bottomRight,
    followerAnchor: Alignment.topRight,
    width: 180,
    popoverBuilder: (context, close) => CodexMenu<PresentationDetailMode>(
      items: const [
        CodexMenuItem(value: PresentationDetailMode.prose, label: 'Prose'),
        CodexMenuItem(
          value: PresentationDetailMode.commands,
          label: 'Commands',
        ),
        CodexMenuItem(
          value: PresentationDetailMode.execution,
          label: 'Execution',
        ),
      ],
      selectedValue: _detailMode,
      onSelected: (mode) {
        close();
        _setDetailMode(mode);
      },
    ),
    child: CodexIconButton(
      key: const ValueKey('timeline-details-button'),
      tooltip: 'Timeline details',
      icon: const Icon(Icons.tune_rounded, size: 17),
      onPressed: _timelineDetailsPopoverController.toggle,
    ),
  );

  Widget _buildLinkedPrHeaderPill(
    BuildContext context,
    String threadId,
    ThreadLinkedPullRequestsSnapshot? linkedPrs, {
    required bool compact,
  }) {
    final palette = ThemeTokens.of(context);
    final hasPrs = linkedPrs != null && linkedPrs.isNotEmpty;
    final firstPr = hasPrs ? linkedPrs.pullRequests.first : null;
    final extraCount = hasPrs ? linkedPrs.pullRequests.length - 1 : 0;
    final countSuffix = hasPrs
        ? (extraCount > 0
              ? '+$extraCount${linkedPrs.truncated ? '+' : ''}'
              : (linkedPrs.truncated ? '+' : null))
        : (linkedPrs != null && linkedPrs.truncated ? '0+' : null);
    final pillLabel = firstPr != null
        ? firstPr.displayLabel
        : (_linkedPrLoadError != null ? 'Linked PRs · Error' : 'Linked PRs');
    final tooltipMessage = switch ((firstPr, linkedPrs, _linkedPrLoadError)) {
      (_, _, final error?) => error,
      (final pr?, final snapshot?, _)
          when snapshot.pullRequests.length == 1 && !snapshot.truncated =>
        '${pr.canonicalUrl}'
            '${pr.headBranch != null ? '\nBranch: ${pr.headBranch}' : ''}',
      (_, final snapshot?, _) when snapshot.isNotEmpty =>
        '${snapshot.pullRequests.length}'
            '${snapshot.truncated ? '+' : ''} linked pull requests',
      _ => 'Inspect linked pull requests for this thread',
    };

    return CodexPopoverAnchor(
      controller: _linkedPrsPopoverController,
      targetAnchor: widget.hasDesktopShell
          ? Alignment.bottomRight
          : Alignment.bottomLeft,
      followerAnchor: widget.hasDesktopShell
          ? Alignment.topRight
          : Alignment.topLeft,
      width: 360,
      popoverBuilder: (context, close) => ValueListenableBuilder<int>(
        valueListenable: _linkedPrViewNotifier,
        builder: (context, _, _) => _buildLinkedPrPopover(
          context,
          threadId,
          _activeThreadLinkedPrs?.threadId == threadId
              ? _activeThreadLinkedPrs
              : null,
          close,
        ),
      ),
      child: CodexButton(
        key: const ValueKey('thread-linked-pr-pill'),
        size: CodexButtonSize.sm,
        variant: compact
            ? CodexButtonVariant.ghost
            : CodexButtonVariant.secondary,
        tooltip: tooltipMessage,
        onPressed: () {
          if (_linkedPrLaunchError != null) {
            setState(() {
              _linkedPrLaunchError = null;
              _notifyLinkedPrViewChanged();
            });
          }
          final wasOpen = _linkedPrsPopoverController.isOpen;
          _linkedPrsPopoverController.toggle();
          if (!wasOpen &&
              linkedPrs == null &&
              _linkedPrLoadError == null &&
              !_linkedPrScanInFlight) {
            _requestActiveThreadLinkedPrs(threadId);
          }
        },
        icon: Icon(
          Icons.call_merge_rounded,
          size: 12,
          color: _linkedPrLoadError != null
              ? palette.danger
              : compact
              ? palette.textSecondary
              : palette.accent,
        ),
        child: compact
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      pillLabel,
                      key: const ValueKey('thread-linked-pr-pill-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _linkedPrLoadError != null
                            ? palette.danger
                            : palette.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  if (countSuffix != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      countSuffix,
                      key: const ValueKey('thread-linked-pr-pill-count'),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: palette.textMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildLinkedPrPopover(
    BuildContext context,
    String threadId,
    ThreadLinkedPullRequestsSnapshot? linkedPrs,
    VoidCallback close,
  ) {
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
    final countText = linkedPrs != null
        ? ' (${linkedPrs.pullRequests.length}${linkedPrs.truncated ? '+' : ''})'
        : '';
    return Container(
      key: const ValueKey('thread-linked-pr-popover'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.modalSurface,
        borderRadius: BorderRadius.circular(OfficialCodexTheme.popoverRadius),
        border: Border.all(
          color: theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Linked Pull Requests$countText',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (_attachmentGateway?.supportsThreadAttachmentWrites ??
                    false) ...[
                  CodexButton(
                    key: const ValueKey('thread-linked-pr-add-toggle'),
                    size: CodexButtonSize.sm,
                    variant: _linkedPrFormOpen
                        ? CodexButtonVariant.primary
                        : CodexButtonVariant.secondary,
                    onPressed: _linkedPrMutationInFlight
                        ? null
                        : () {
                            setState(() {
                              _linkedPrFormOpen = !_linkedPrFormOpen;
                              _linkedPrMutationError = null;
                              _linkedPrMutationNotice = null;
                              _notifyLinkedPrViewChanged();
                            });
                            if (_linkedPrFormOpen) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && _linkedPrFormOpen) {
                                  _linkedPrUrlFocusNode.requestFocus();
                                }
                              });
                            }
                          },
                    label: 'Link PR…',
                  ),
                  const SizedBox(width: 4),
                ],
                CodexIconButton(
                  key: const ValueKey('thread-linked-pr-popover-close'),
                  tooltip: 'Close',
                  size: 22,
                  onPressed: close,
                  icon: const Icon(Icons.close_rounded, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('thread-linked-pr-popover-scroll'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_linkedPrFormOpen &&
                        (_attachmentGateway?.supportsThreadAttachmentWrites ??
                            false)) ...[
                      _buildLinkedPrAddForm(context, threadId),
                      const SizedBox(height: 8),
                    ],
                    if (_linkedPrMutationNotice case final mutationNotice?) ...[
                      Text(
                        mutationNotice,
                        key: const ValueKey('thread-linked-pr-mutation-notice'),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: palette.textSecondary),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (_linkedPrMutationError case final mutationError?) ...[
                      Text(
                        mutationError,
                        key: const ValueKey('thread-linked-pr-mutation-error'),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: palette.danger),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (_linkedPrLoadError case final loadError?) ...[
                      Text(
                        loadError,
                        key: const ValueKey('thread-linked-pr-error'),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.danger),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CodexButton(
                          key: const ValueKey('thread-linked-pr-retry'),
                          size: CodexButtonSize.sm,
                          variant: CodexButtonVariant.secondary,
                          onPressed: () =>
                              _requestActiveThreadLinkedPrs(threadId),
                          label: 'Retry',
                        ),
                      ),
                    ] else if (linkedPrs == null) ...[
                      Text(
                        'Loading linked pull requests...',
                        key: const ValueKey('thread-linked-pr-loading'),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.textMuted),
                      ),
                    ] else if (linkedPrs.isEmpty) ...[
                      Text(
                        'No linked pull requests for this thread.',
                        key: const ValueKey('thread-linked-pr-empty'),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.textMuted),
                      ),
                    ] else ...[
                      for (var i = 0; i < linkedPrs.pullRequests.length; i++)
                        _buildLinkedPrPopoverRow(
                          context,
                          linkedPrs.pullRequests[i],
                          i,
                        ),
                    ],
                    if (linkedPrs != null && linkedPrs.truncated) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Showing first ${linkedPrs.pullRequests.length} linked pull requests '
                        '(scanned ${linkedPrs.scannedAttachmentCount} attachments; limit reached).',
                        key: const ValueKey('thread-linked-pr-limit-notice'),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: palette.textMuted),
                      ),
                    ],
                    if (_linkedPrLaunchError case final launchError?) ...[
                      const SizedBox(height: 6),
                      Text(
                        launchError,
                        key: const ValueKey('thread-linked-pr-launch-error'),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: palette.danger),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedPrAddForm(BuildContext context, String threadId) {
    final palette = ThemeTokens.of(context);
    return Container(
      key: const ValueKey('thread-linked-pr-add-form'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: palette.border,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('thread-linked-pr-url-input'),
            controller: _linkedPrUrlController,
            focusNode: _linkedPrUrlFocusNode,
            enabled: !_linkedPrMutationInFlight,
            style: Theme.of(context).textTheme.bodySmall,
            decoration: const InputDecoration(
              labelText: 'GitHub PR or GitLab MR HTTPS URL',
              hintText: 'https://github.com/owner/repo/pull/123',
              isDense: true,
            ),
            onSubmitted: (_) => unawaited(_submitLinkPullRequest(threadId)),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('thread-linked-pr-branch-input'),
            controller: _linkedPrBranchController,
            enabled: !_linkedPrMutationInFlight,
            style: Theme.of(context).textTheme.bodySmall,
            decoration: const InputDecoration(
              labelText: 'Head branch (optional)',
              hintText: 'feat/my-branch',
              isDense: true,
            ),
            onSubmitted: (_) => unawaited(_submitLinkPullRequest(threadId)),
          ),
          const SizedBox(height: 6),
          Text(
            'Saves a local thread reference only (does not modify Git or GitHub/GitLab).',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.textMuted, fontSize: 10.5),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CodexButton(
                key: const ValueKey('thread-linked-pr-add-cancel'),
                size: CodexButtonSize.sm,
                variant: CodexButtonVariant.ghost,
                onPressed: _linkedPrMutationInFlight
                    ? null
                    : () {
                        setState(() {
                          _linkedPrFormOpen = false;
                          _linkedPrMutationError = null;
                          _notifyLinkedPrViewChanged();
                        });
                      },
                label: 'Cancel',
              ),
              const SizedBox(width: 6),
              CodexButton(
                key: const ValueKey('thread-linked-pr-add-submit'),
                size: CodexButtonSize.sm,
                variant: CodexButtonVariant.primary,
                onPressed: _linkedPrMutationInFlight
                    ? null
                    : () => unawaited(_submitLinkPullRequest(threadId)),
                label: _linkedPrMutationInFlight ? 'Linking…' : 'Link',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedPrPopoverRow(
    BuildContext context,
    ThreadLinkedPullRequest pr,
    int index,
  ) {
    final palette = ThemeTokens.of(context);
    return Container(
      key: ValueKey('thread-linked-pr-item-$index'),
      margin: EdgeInsets.only(
        bottom: index == 0 ? 0 : 6,
        top: index == 0 ? 0 : 2,
      ),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: palette.border,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pr.displayLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (pr.headBranch case final headBranch?) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Branch: $headBranch',
                    key: ValueKey('thread-linked-pr-branch-$index'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                SelectableText(
                  pr.canonicalUrl,
                  key: ValueKey('thread-linked-pr-url-$index'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CodexButton(
            key: ValueKey('thread-linked-pr-open-$index'),
            size: CodexButtonSize.sm,
            variant: CodexButtonVariant.secondary,
            onPressed: () => unawaited(_openSanitizedPullRequest(pr)),
            label: 'Open',
          ),
        ],
      ),
    );
  }

  Future<void> _renameActiveThreadDialog(
    ThreadListController threadController,
    ThreadSummary thread,
  ) async {
    final next = await showDialog<String>(
      context: context,
      builder: (context) => _RenameThreadDialog(thread: thread),
    );
    if (next != null && mounted) {
      await threadController.renameThread(thread.id, next);
    }
  }

  bool _canStartThreadReview(String threadId) =>
      mounted &&
      widget.controller.thread?.id == threadId &&
      widget.threadController?.showArchived == false &&
      widget.threadController?.mutating == false &&
      widget.threadController?.isMaterialized(threadId) == true &&
      widget.threadController?.selectedThread?.status !=
          ThreadRuntimeStatus.active &&
      widget.controller.canStartReview &&
      _activeCapabilities.supportsGitDiff;

  Future<void> _startThreadReviewDialog(ThreadSummary thread) async {
    final threads = widget.threadController;
    if (threads == null ||
        _checkingColdResume ||
        !_canStartThreadReview(thread.id)) {
      return;
    }
    final selectionVersion = _threadSelectionVersion;
    if (threads.selectedThreadNeedsResume(thread.id) &&
        !await _confirmColdResume(threads, thread.id, forReview: true)) {
      return;
    }
    if (!mounted ||
        _threadSelectionVersion != selectionVersion ||
        !_canStartThreadReview(thread.id)) {
      return;
    }
    final target = await showDialog<ReviewTarget>(
      context: context,
      builder: (context) => _StartReviewDialog(thread: thread),
    );
    if (target == null || _threadSelectionVersion != selectionVersion) {
      return;
    }
    // The queue can change while the chooser is open. Review admission
    // checks it again before loading a cold thread.
    await _startThreadReview(thread.id, target);
  }

  Future<void> _startThreadReview(String threadId, ReviewTarget target) async {
    final threads = widget.threadController;
    if (threads == null ||
        _checkingColdResume ||
        !_canStartThreadReview(threadId)) {
      return;
    }
    final selectionVersion = _threadSelectionVersion;
    if (threads.selectedThreadNeedsResume(threadId)) {
      final admitted = await _confirmColdResume(
        threads,
        threadId,
        forReview: true,
      );
      if (!admitted ||
          _threadSelectionVersion != selectionVersion ||
          !_canStartThreadReview(threadId)) {
        return;
      }
      if (!await threads.ensureSelectedThreadLoaded(threadId)) {
        _reportReviewResumeFailure(threads, threadId, selectionVersion);
        return;
      }
    }
    if (_threadSelectionVersion == selectionVersion &&
        _canStartThreadReview(threadId)) {
      await widget.controller.startReview(target);
    }
  }

  void _reportReviewResumeFailure(
    ThreadListController threads,
    String threadId,
    int selectionVersion,
  ) {
    if (mounted &&
        _threadSelectionVersion == selectionVersion &&
        widget.controller.thread?.id == threadId &&
        threads.errorMessage != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Could not resume this thread for review.'),
        ),
      );
    }
  }

  void _rememberThreadDag(String threadId, ChatConversationDag dag) {
    _threadChatDags.remove(threadId);
    _threadChatDags[threadId] = dag;
    while (_threadChatDags.length > _maxRetainedThreadDags) {
      _threadChatDags.remove(_threadChatDags.keys.first);
    }
  }

  void _selectSiblingBranch(String threadId, String nodeId, int offset) {
    final current = _threadChatDags[threadId];
    if (current == null) {
      return;
    }
    setState(() {
      _rememberThreadDag(
        threadId,
        current.selectSiblingBranch(nodeId: nodeId, offset: offset),
      );
    });
  }

  bool _canRollBackTurn(String threadId) =>
      mounted &&
      widget.controller.thread?.id == threadId &&
      widget.threadController?.showArchived == false &&
      !widget.controller.busy &&
      widget.threadController?.mutating == false &&
      _activeCapabilities.supportsThreadRevert;

  Future<bool> _confirmTurnRollback(String threadId, String action) async {
    if (!_canRollBackTurn(threadId)) {
      return false;
    }
    final confirmed = await _confirmDesktopAction(
      context,
      title: '$action this turn?',
      message:
          'This removes the selected turn and every later turn from this '
          'thread’s saved conversation. Fork first to keep the original.',
      confirmLabel: '$action and truncate',
    );
    return confirmed && _canRollBackTurn(threadId);
  }

  Future<void> _revertTurn(String threadId, String turnId) async {
    if (!await _confirmTurnRollback(threadId, 'Revert')) {
      return;
    }
    _pendingBranchEdit = null;
    final reverted = await widget.threadController!.revertThread(
      threadId: threadId,
      beforeTurnId: turnId,
    );
    if (reverted != null && mounted) {
      _threadScrollBookmarks.remove(threadId);
      if (widget.controller.thread?.id == threadId) {
        widget.controller.clearEntries();
        await widget.historyController.refresh();
      }
    }
  }

  Future<void> _editTurn({
    required String threadId,
    required String turnId,
    required String rawText,
    required List<UserAttachment> attachments,
    String? assistantText,
  }) async {
    if (!await _confirmTurnRollback(threadId, 'Edit')) {
      return;
    }
    final threadController = widget.threadController!;
    final presentation = parseUserMessagePresentation(
      rawText,
      attachments: attachments,
    );
    final bodyText = presentation.bodyText.trim();
    final normalizedAttachments = normalizeUserAttachments(
      presentation.attachments,
    );
    if (assistantText != null &&
        assistantText.trim().isNotEmpty &&
        _threadChatDags[threadId] != null) {
      _rememberThreadDag(
        threadId,
        _threadChatDags[threadId]!.updateTurnAssistantText(
          turnId: turnId,
          assistantText: assistantText,
        ),
      );
    }
    _pendingBranchEdit = null;
    final reverted = await threadController.revertThread(
      threadId: threadId,
      beforeTurnId: turnId,
    );
    if (reverted != null &&
        mounted &&
        widget.controller.thread?.id == threadId) {
      widget.controller.clearEntries();
      _threadScrollBookmarks.remove(threadId);
      await widget.historyController.refresh();
      if (!mounted || widget.controller.thread?.id != threadId) {
        return;
      }
      _pendingBranchEdit = _PendingTurnBranchEdit(
        threadId: threadId,
        turnId: turnId,
        userText: bodyText,
        attachments: normalizedAttachments,
        assistantText: assistantText,
      );
      setState(() {
        _composerController.value = TextEditingValue(
          text: bodyText,
          selection: TextSelection.collapsed(offset: bodyText.length),
        );
        _composerAttachments
          ..clear()
          ..addAll(normalizedAttachments);
      });
      _composerFocusNode.requestFocus();
    }
  }

  Future<void> _regenerateTurn({
    required String threadId,
    required String turnId,
    required String rawText,
    required List<UserAttachment> attachments,
    String? assistantText,
    String action = 'Regenerate',
  }) async {
    if (!_canRollBackTurn(threadId)) {
      return;
    }
    final presentation = parseUserMessagePresentation(
      rawText,
      attachments: attachments,
    );
    final bodyText = presentation.bodyText.trim();
    final normalizedAttachments = normalizeUserAttachments(
      presentation.attachments,
    );
    if (bodyText.isEmpty && normalizedAttachments.isEmpty) {
      return;
    }
    if (!await _confirmTurnRollback(threadId, action)) {
      return;
    }
    final threadController = widget.threadController!;
    if (assistantText != null &&
        assistantText.trim().isNotEmpty &&
        _threadChatDags[threadId] != null) {
      _rememberThreadDag(
        threadId,
        _threadChatDags[threadId]!.updateTurnAssistantText(
          turnId: turnId,
          assistantText: assistantText,
        ),
      );
    }
    _pendingBranchEdit = null;
    final reverted = await threadController.revertThread(
      threadId: threadId,
      beforeTurnId: turnId,
    );
    if (reverted != null &&
        mounted &&
        widget.controller.thread?.id == threadId) {
      widget.controller.clearEntries();
      _threadScrollBookmarks.remove(threadId);
      await widget.historyController.refresh();
      if (!mounted ||
          widget.controller.thread?.id != threadId ||
          widget.controller.busy) {
        return;
      }
      final submitted = await widget.controller.submit(
        bodyText,
        attachments: normalizedAttachments,
      );
      if (submitted && mounted && widget.controller.thread?.id == threadId) {
        final nextTurnId =
            widget.controller.activeTurnId ??
            _latestLiveUserTurnId() ??
            'branch-${_branchSequence++}';
        final currentDag =
            _threadChatDags[threadId] ?? const ChatConversationDag.empty();
        setState(() {
          _rememberThreadDag(
            threadId,
            currentDag.recordTurnBranch(
              turnId: turnId,
              originalUserText: bodyText,
              originalAttachments: normalizedAttachments,
              originalAssistantText: assistantText,
              nextTurnId: nextTurnId,
              nextUserText: bodyText,
              nextAttachments: normalizedAttachments,
            ),
          );
        });
        _jumpToLatest();
      }
    }
  }

  String? _latestLiveUserTurnId() {
    final entries = widget.controller.entries;
    for (var i = entries.length - 1; i >= 0; i -= 1) {
      if (entries[i].kind == ConversationEntryKind.user) {
        final turnId = entries[i].turnId;
        if (turnId != null && turnId.isNotEmpty) {
          return turnId;
        }
      }
    }
    return null;
  }

  Future<void> _continueTurn() async {
    if (widget.controller.busy || widget.controller.thread == null) {
      return;
    }
    if (await widget.controller.submit('Continue')) {
      _jumpToLatest();
    }
  }

  Future<void> _retryFailedHistoryTurn(
    String threadId,
    String turnId,
    List<HistoryItem> rawHistoryItems,
  ) async {
    HistoryItem? userItem;
    String? assistantText;
    for (final candidate in rawHistoryItems) {
      if (candidate.turnId == turnId) {
        if (candidate.kind == HistoryItemKind.user) {
          userItem = candidate;
        } else if (candidate.kind == HistoryItemKind.assistant) {
          assistantText = candidate.text;
        }
      }
    }
    if (userItem != null) {
      await _regenerateTurn(
        threadId: threadId,
        turnId: turnId,
        rawText: userItem.text,
        attachments: userItem.attachments,
        assistantText: assistantText,
        action: 'Retry',
      );
    }
  }

  Future<void> _retryFailedLiveTurn(
    String threadId,
    ConversationEntry failure,
    List<ConversationEntry> rawLiveEntries,
  ) async {
    if (!_canRollBackTurn(threadId)) {
      return;
    }
    final failureIndex = rawLiveEntries.indexWhere(
      (entry) => entry.id == failure.id,
    );
    final turnId = failure.turnId ?? '';
    ConversationEntry? userEntry;
    String? assistantText;
    for (var i = failureIndex - 1; i >= 0; i -= 1) {
      final candidate = rawLiveEntries[i];
      if (turnId.isEmpty) {
        if (candidate.kind == ConversationEntryKind.user) {
          if (candidate.turnId == null || candidate.turnId!.isEmpty) {
            userEntry = candidate;
          }
          break;
        }
        if (candidate.kind == ConversationEntryKind.error) {
          break;
        }
      } else if (candidate.turnId == turnId) {
        if (candidate.kind == ConversationEntryKind.user) {
          userEntry = candidate;
          break;
        }
        if (candidate.kind == ConversationEntryKind.assistant) {
          assistantText ??= candidate.text;
        }
      }
    }
    if (userEntry == null) {
      return;
    }
    if (turnId.isNotEmpty) {
      await _regenerateTurn(
        threadId: threadId,
        turnId: turnId,
        rawText: userEntry.text,
        attachments: userEntry.attachments,
        assistantText: assistantText,
        action: 'Retry',
      );
      return;
    }
    final presentation = parseUserMessagePresentation(
      userEntry.text,
      attachments: userEntry.attachments,
    );
    await widget.controller.submit(
      presentation.bodyText.trim(),
      attachments: presentation.attachments,
    );
  }

  Widget _timeline(ConversationController controller) {
    if (controller.thread == null) {
      _currentTimelineItemKeys = const [];
      _searchMatchItemKeys = const [];
      return Center(
        child: ConstrainedBox(
          key: const ValueKey('conversation_reading_column'),
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: _ConversationEmptyState(
            workingDirectory: _activeProjectDirectory,
          ),
        ),
      );
    }
    final showLiveEntries = !widget.historyController.canReturnToNewest;
    final rawLiveEntries = showLiveEntries
        ? controller.entries
        : const <ConversationEntry>[];
    final latestActivity = _detailMode == PresentationDetailMode.commands
        ? _latestLiveActivity(rawLiveEntries)
        : null;
    final collapsedActivitySummary = widget.hasDesktopShell && controller.busy
        ? _collapsedLiveCommandSummary(rawLiveEntries, latestActivity)
        : null;
    final liveEntries = switch (_detailMode) {
      PresentationDetailMode.prose =>
        rawLiveEntries
            .where(
              (e) =>
                  e.kind == ConversationEntryKind.user ||
                  e.kind == ConversationEntryKind.assistant ||
                  e.kind == ConversationEntryKind.review ||
                  e.kind == ConversationEntryKind.error,
            )
            .toList(growable: false),
      PresentationDetailMode.commands =>
        rawLiveEntries
            .where(
              (e) =>
                  e.kind == ConversationEntryKind.user ||
                  e.kind == ConversationEntryKind.assistant ||
                  e.kind == ConversationEntryKind.review ||
                  e.kind == ConversationEntryKind.error ||
                  !e.completed ||
                  identical(e, latestActivity),
            )
            .toList(growable: false),
      PresentationDetailMode.execution => rawLiveEntries,
    };
    final liveIds = liveEntries
        .map((entry) => entry.stockItemId ?? entry.id)
        .toSet();
    final rawHistoryItems = widget.historyController.timelineItems
        .where((item) => !liveIds.contains(item.id))
        .toList(growable: false);
    final latestTurnId =
        controller.activeTurnId ??
        rawLiveEntries.lastOrNull?.turnId ??
        rawHistoryItems.lastOrNull?.turnId;
    final historyItems = switch (_detailMode) {
      PresentationDetailMode.prose =>
        rawHistoryItems
            .where(
              (item) =>
                  item.kind == HistoryItemKind.user ||
                  item.kind == HistoryItemKind.assistant ||
                  item.kind == HistoryItemKind.review,
            )
            .toList(growable: false),
      PresentationDetailMode.commands =>
        rawHistoryItems
            .where((item) {
              if (item.kind == HistoryItemKind.user ||
                  item.kind == HistoryItemKind.assistant ||
                  item.kind == HistoryItemKind.review) {
                return true;
              }
              final turn = widget.historyController.turnForId(item.turnId);
              final hasWorkDivider =
                  turn?.formattedWorkDuration != null &&
                  widget.historyController.isTurnDetailsAnchor(item);
              final isTurnExpanded =
                  widget.historyController.selectedTurnId == item.turnId;
              return isTurnExpanded ||
                  hasWorkDivider ||
                  turn?.formattedWorkDuration == null;
            })
            .toList(growable: false),
      PresentationDetailMode.execution => rawHistoryItems,
    };
    if (liveEntries.isEmpty && historyItems.isEmpty) {
      _currentTimelineItemKeys = const [];
      _searchMatchItemKeys = const [];
      final Widget emptyChild;
      if (widget.historyController.loadingTurns) {
        emptyChild = const _ConversationLoadingState();
      } else if (widget.historyController.errorMessage case final error?) {
        emptyChild = _ConversationErrorState(
          message: error,
          onRetry: widget.historyController.refresh,
        );
      } else {
        emptyChild = _ThreadEmptyState(thread: controller.thread!);
      }
      return Center(
        child: ConstrainedBox(
          key: const ValueKey('conversation_reading_column'),
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: emptyChild,
        ),
      );
    }

    final activeThreadId = controller.thread!.id;
    if (_threadChatDags[activeThreadId] case var dag?) {
      for (final item in rawHistoryItems) {
        if (item.kind == HistoryItemKind.assistant &&
            item.turnId.isNotEmpty &&
            item.text.trim().isNotEmpty) {
          dag = dag.updateTurnAssistantText(
            turnId: item.turnId,
            assistantText: item.text,
          );
        }
      }
      for (final entry in rawLiveEntries) {
        if (entry.kind == ConversationEntryKind.assistant &&
            (entry.turnId?.isNotEmpty ?? false) &&
            entry.text.trim().isNotEmpty) {
          dag = dag.updateTurnAssistantText(
            turnId: entry.turnId!,
            assistantText: entry.text,
          );
        }
      }
      _threadChatDags[activeThreadId] = dag;
    }
    final activeDag = _threadChatDags[activeThreadId];

    String effectiveHistoryText(HistoryItem item) {
      if (!_activeCapabilities.supportsBranchNavigation ||
          item.turnId.isEmpty ||
          activeDag == null) {
        return item.text;
      }
      final activeSibling = activeDag.activeSiblingForTurn(item.turnId);
      if (activeSibling == null) {
        return item.text;
      }
      final siblingInfo = activeDag.siblingInfoFor(activeSibling.id);
      if (siblingInfo == null || !siblingInfo.hasMultipleBranches) {
        return item.text;
      }
      if (item.kind == HistoryItemKind.user) {
        return activeSibling.text;
      }
      if (item.kind == HistoryItemKind.assistant) {
        final asstNode = activeDag.assistantChildFor(activeSibling.id);
        if (asstNode != null && asstNode.text.isNotEmpty) {
          return asstNode.text;
        }
      }
      return item.text;
    }

    String effectiveLiveText(ConversationEntry entry) {
      if (collapsedActivitySummary != null &&
          identical(entry, latestActivity)) {
        return '${entry.text}\n$collapsedActivitySummary';
      }
      final liveTurnId = entry.turnId ?? '';
      if (!_activeCapabilities.supportsBranchNavigation ||
          liveTurnId.isEmpty ||
          activeDag == null) {
        return entry.text;
      }
      final activeSibling = activeDag.activeSiblingForTurn(liveTurnId);
      if (activeSibling == null) {
        return entry.text;
      }
      final siblingInfo = activeDag.siblingInfoFor(activeSibling.id);
      if (siblingInfo == null || !siblingInfo.hasMultipleBranches) {
        return entry.text;
      }
      if (entry.kind == ConversationEntryKind.user) {
        return activeSibling.text;
      }
      if (entry.kind == ConversationEntryKind.assistant) {
        final asstNode = activeDag.assistantChildFor(activeSibling.id);
        if (asstNode != null && asstNode.text.isNotEmpty) {
          return asstNode.text;
        }
      }
      return entry.text;
    }

    final searchQuery = _searchOpen
        ? _searchController.text.trim().toLowerCase()
        : '';
    if (searchQuery.isEmpty) {
      _searchMatchItemKeys = const [];
    } else {
      final matches = <String>[];
      for (final item in historyItems) {
        if (effectiveHistoryText(item).toLowerCase().contains(searchQuery)) {
          matches.add('history-${item.id}');
        }
      }
      for (final entry in liveEntries) {
        if (effectiveLiveText(entry).toLowerCase().contains(searchQuery)) {
          matches.add('live-${entry.id}');
        }
      }
      _searchMatchItemKeys = matches;
      if (_activeSearchMatchIndex >= matches.length) {
        _activeSearchMatchIndex = 0;
      }
    }
    final activeMatchKey =
        _searchMatchItemKeys.isNotEmpty &&
            _activeSearchMatchIndex >= 0 &&
            _activeSearchMatchIndex < _searchMatchItemKeys.length
        ? _searchMatchItemKeys[_activeSearchMatchIndex]
        : null;

    final footerCount =
        widget.historyController.canLoadOlderTurns ||
            widget.historyController.canReturnToNewest ||
            widget.historyController.canLoadMoreItems ||
            widget.historyController.loadingTurns ||
            widget.historyController.loadingItems
        ? 1
        : 0;
    final messageCount = historyItems.length + liveEntries.length;
    final totalCount = messageCount + footerCount;
    _currentTimelineItemKeys = [
      for (var reverseIndex = 0; reverseIndex < messageCount; reverseIndex += 1)
        () {
          final chronologicalIndex = messageCount - 1 - reverseIndex;
          if (chronologicalIndex < historyItems.length) {
            return 'history-${historyItems[chronologicalIndex].id}';
          }
          final liveIndex = chronologicalIndex - historyItems.length;
          return 'live-${liveEntries[liveIndex].id}';
        }(),
    ];
    return Center(
      child: ConstrainedBox(
        key: const ValueKey('conversation_reading_column'),
        constraints: const BoxConstraints(
          maxWidth: OfficialCodexTheme.maxContentWidth,
        ),
        child: Stack(
          children: [
            Scrollbar(
              controller: _scrollController,
              child: _ConversationScrollView(
                key: const ValueKey('conversation-timeline'),
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
                itemCount: totalCount,
                findChildIndexCallback: (key) {
                  if (key is ValueKey<String>) {
                    final value = key.value;
                    if (value == 'history-pagination-footer') {
                      return footerCount > 0 ? messageCount : null;
                    }
                    if (value.startsWith('measured-')) {
                      final itemKey = value.substring('measured-'.length);
                      final index = _currentTimelineItemKeys.indexOf(itemKey);
                      return index >= 0 ? index : null;
                    }
                  }
                  return null;
                },
                itemBuilder: (context, reverseIndex) {
                  if (reverseIndex == messageCount) {
                    return _HistoryFooter(
                      key: const ValueKey('history-pagination-footer'),
                      controller: widget.historyController,
                    );
                  }
                  final chronologicalIndex = messageCount - 1 - reverseIndex;
                  final activeThread = controller.thread;
                  final threadController = widget.threadController;
                  final capabilities = _activeCapabilities;
                  final dag = activeThread == null
                      ? null
                      : _threadChatDags[activeThread.id];
                  if (chronologicalIndex < historyItems.length) {
                    final item = historyItems[chronologicalIndex];
                    final itemKey = 'history-${item.id}';
                    final canMutateTurn =
                        item.kind == HistoryItemKind.user &&
                        item.turnId.isNotEmpty &&
                        activeThread != null &&
                        threadController != null &&
                        !threadController.showArchived &&
                        !controller.busy &&
                        !threadController.mutating;
                    String? assistantTextForTurn;
                    if (item.kind == HistoryItemKind.user &&
                        item.turnId.isNotEmpty) {
                      for (final candidate in rawHistoryItems) {
                        if (candidate.turnId == item.turnId &&
                            candidate.kind == HistoryItemKind.assistant) {
                          assistantTextForTurn = candidate.text;
                        }
                      }
                    }
                    final activeSibling =
                        capabilities.supportsBranchNavigation &&
                            item.turnId.isNotEmpty
                        ? dag?.activeSiblingForTurn(item.turnId)
                        : null;
                    final siblingInfo = activeSibling != null
                        ? dag?.siblingInfoFor(activeSibling.id)
                        : null;
                    final hasMultipleBranches =
                        siblingInfo != null && siblingInfo.hasMultipleBranches;
                    String? overrideText;
                    List<UserAttachment>? overrideAttachments;
                    String? activeBranchAssistantText;
                    if (hasMultipleBranches && activeSibling != null) {
                      final asstNode = dag?.assistantChildFor(activeSibling.id);
                      if (asstNode != null && asstNode.text.isNotEmpty) {
                        activeBranchAssistantText = asstNode.text;
                      }
                      if (item.kind == HistoryItemKind.user) {
                        overrideText = activeSibling.text;
                        overrideAttachments = activeSibling.attachments;
                      } else if (item.kind == HistoryItemKind.assistant) {
                        overrideText = activeBranchAssistantText;
                      }
                    }
                    final effectiveAssistantTextForTurn =
                        activeBranchAssistantText ?? assistantTextForTurn;
                    final isLastInTurn =
                        chronologicalIndex + 1 >= historyItems.length ||
                        historyItems[chronologicalIndex + 1].turnId !=
                            item.turnId;
                    final historyTurn = item.turnId.isEmpty
                        ? null
                        : widget.historyController.turnForId(item.turnId);
                    final showHistoryContinue =
                        isLastInTurn &&
                        historyTurn?.status == TurnRuntimeStatus.interrupted &&
                        !controller.busy;
                    final showHistoryRetry =
                        isLastInTurn &&
                        historyTurn?.status == TurnRuntimeStatus.failed &&
                        activeThread != null &&
                        _canRollBackTurn(activeThread.id);
                    return _MeasuredTimelineItem(
                      key: ValueKey('measured-$itemKey'),
                      itemKey: itemKey,
                      turnId: item.turnId,
                      onMeasured: _recordItemMeasurement,
                      onUnmount: _unregisterItemBox,
                      child: _HistoryEntryView(
                        key: ValueKey(itemKey),
                        item: item,
                        historyController: widget.historyController,
                        detailMode: _detailMode,
                        inlineActivity: widget.hasDesktopShell,
                        revealAssistantCopy:
                            !showLiveEntries || item.turnId != latestTurnId,
                        commandOutput: item.isCommand
                            ? _commandOutputFor(
                                context,
                                itemId: item.id,
                                turnId: item.turnId,
                                output: item.output,
                                saved: true,
                              )
                            : null,
                        overrideEntryText: overrideText,
                        overrideAttachments: overrideAttachments,
                        siblingBranchInfo:
                            item.kind == HistoryItemKind.user &&
                                hasMultipleBranches
                            ? siblingInfo
                            : null,
                        onSelectSiblingBranch:
                            item.kind == HistoryItemKind.user &&
                                hasMultipleBranches &&
                                activeThread != null &&
                                activeSibling != null
                            ? (offset) => _selectSiblingBranch(
                                activeThread.id,
                                activeSibling.id,
                                offset,
                              )
                            : null,
                        isSearchMatch: _searchMatchItemKeys.contains(itemKey),
                        isActiveSearchMatch: activeMatchKey == itemKey,
                        onEditFromTurn:
                            canMutateTurn && capabilities.supportsThreadRevert
                            ? () => unawaited(
                                _editTurn(
                                  threadId: activeThread.id,
                                  turnId: item.turnId,
                                  rawText: overrideText ?? item.text,
                                  attachments:
                                      overrideAttachments ?? item.attachments,
                                  assistantText: effectiveAssistantTextForTurn,
                                ),
                              )
                            : null,
                        onRegenerateFromTurn:
                            canMutateTurn && capabilities.supportsThreadRevert
                            ? () => unawaited(
                                _regenerateTurn(
                                  threadId: activeThread.id,
                                  turnId: item.turnId,
                                  rawText: overrideText ?? item.text,
                                  attachments:
                                      overrideAttachments ?? item.attachments,
                                  assistantText: effectiveAssistantTextForTurn,
                                ),
                              )
                            : null,
                        onContinueTurn: showHistoryContinue
                            ? () => unawaited(_continueTurn())
                            : null,
                        onRetryTurn: showHistoryRetry
                            ? () => unawaited(
                                _retryFailedHistoryTurn(
                                  activeThread.id,
                                  item.turnId,
                                  rawHistoryItems,
                                ),
                              )
                            : null,
                        onForkFromTurn:
                            canMutateTurn && capabilities.supportsThreadFork
                            ? () => unawaited(
                                threadController.forkThread(
                                  ThreadForkOptions(
                                    threadId: activeThread.id,
                                    beforeTurnId: item.turnId,
                                    cwd: activeThread.cwd,
                                  ),
                                ),
                              )
                            : null,
                        onRevertFromTurn:
                            canMutateTurn && capabilities.supportsThreadRevert
                            ? () => _revertTurn(activeThread.id, item.turnId)
                            : null,
                      ),
                    );
                  }
                  final liveIndex = chronologicalIndex - historyItems.length;
                  final entry = liveEntries[liveIndex];
                  final itemKey = 'live-${entry.id}';
                  final liveTurnId = entry.turnId ?? '';
                  final canMutateLiveTurn =
                      entry.kind == ConversationEntryKind.user &&
                      liveTurnId.isNotEmpty &&
                      activeThread != null &&
                      threadController != null &&
                      !threadController.showArchived &&
                      !controller.busy &&
                      !threadController.mutating;
                  String? assistantTextForLiveTurn;
                  if (entry.kind == ConversationEntryKind.user &&
                      liveTurnId.isNotEmpty) {
                    for (final candidate in rawLiveEntries) {
                      if (candidate.turnId == liveTurnId &&
                          candidate.kind == ConversationEntryKind.assistant) {
                        assistantTextForLiveTurn = candidate.text;
                      }
                    }
                  }
                  final activeSibling =
                      capabilities.supportsBranchNavigation &&
                          liveTurnId.isNotEmpty
                      ? dag?.activeSiblingForTurn(liveTurnId)
                      : null;
                  final siblingInfo = activeSibling != null
                      ? dag?.siblingInfoFor(activeSibling.id)
                      : null;
                  final hasMultipleBranches =
                      siblingInfo != null && siblingInfo.hasMultipleBranches;
                  var effectiveEntry = entry;
                  var effectiveAttachments = entry.attachments;
                  String? activeBranchLiveAssistantText;
                  if (hasMultipleBranches && activeSibling != null) {
                    final asstNode = dag?.assistantChildFor(activeSibling.id);
                    if (asstNode != null && asstNode.text.isNotEmpty) {
                      activeBranchLiveAssistantText = asstNode.text;
                    }
                    if (entry.kind == ConversationEntryKind.user) {
                      effectiveEntry = entry.copyWith(
                        text: activeSibling.text,
                        attachments: activeSibling.attachments,
                      );
                      effectiveAttachments = activeSibling.attachments;
                    } else if (entry.kind == ConversationEntryKind.assistant &&
                        activeBranchLiveAssistantText != null) {
                      effectiveEntry = entry.copyWith(
                        text: activeBranchLiveAssistantText,
                      );
                    }
                  }
                  final effectiveAssistantTextForLiveTurn =
                      activeBranchLiveAssistantText ?? assistantTextForLiveTurn;
                  final showLiveContinue =
                      entry.kind == ConversationEntryKind.error &&
                      entry.status == 'interrupted' &&
                      !controller.busy;
                  final showLiveRetry =
                      entry.kind == ConversationEntryKind.error &&
                      entry.status != 'interrupted' &&
                      entry.status != 'retrying' &&
                      activeThread != null &&
                      _canRollBackTurn(activeThread.id);
                  final commandOutput = _commandOutputFor(
                    context,
                    itemId: entry.id,
                    turnId: liveTurnId,
                    output: entry.completed ? entry.commandOutput : null,
                    saved: false,
                  );
                  return _MeasuredTimelineItem(
                    key: ValueKey('measured-$itemKey'),
                    itemKey: itemKey,
                    turnId: liveTurnId,
                    onMeasured: _recordItemMeasurement,
                    onUnmount: _unregisterItemBox,
                    child: _ConversationEntryView(
                      key: ValueKey(entry.id),
                      entry: effectiveEntry,
                      inlineActivity: widget.hasDesktopShell,
                      revealAssistantCopy: liveTurnId != latestTurnId,
                      activitySummary: identical(entry, latestActivity)
                          ? collapsedActivitySummary
                          : null,
                      trailingAction: commandOutput?.action,
                      activityDetail: commandOutput?.detail,
                      turnId: liveTurnId.isEmpty ? null : liveTurnId,
                      attachments: effectiveAttachments,
                      siblingBranchInfo:
                          entry.kind == ConversationEntryKind.user &&
                              hasMultipleBranches
                          ? siblingInfo
                          : null,
                      onSelectSiblingBranch:
                          entry.kind == ConversationEntryKind.user &&
                              hasMultipleBranches &&
                              activeThread != null &&
                              activeSibling != null
                          ? (offset) => _selectSiblingBranch(
                              activeThread.id,
                              activeSibling.id,
                              offset,
                            )
                          : null,
                      isSearchMatch: _searchMatchItemKeys.contains(itemKey),
                      isActiveSearchMatch: activeMatchKey == itemKey,
                      onEditFromTurn:
                          canMutateLiveTurn && capabilities.supportsThreadRevert
                          ? () => unawaited(
                              _editTurn(
                                threadId: activeThread.id,
                                turnId: liveTurnId,
                                rawText: effectiveEntry.text,
                                attachments: effectiveAttachments,
                                assistantText:
                                    effectiveAssistantTextForLiveTurn,
                              ),
                            )
                          : null,
                      onRegenerateFromTurn:
                          canMutateLiveTurn && capabilities.supportsThreadRevert
                          ? () => unawaited(
                              _regenerateTurn(
                                threadId: activeThread.id,
                                turnId: liveTurnId,
                                rawText: effectiveEntry.text,
                                attachments: effectiveAttachments,
                                assistantText:
                                    effectiveAssistantTextForLiveTurn,
                              ),
                            )
                          : null,
                      onContinueTurn: showLiveContinue
                          ? () => unawaited(_continueTurn())
                          : null,
                      onRetryTurn: showLiveRetry
                          ? () => unawaited(
                              _retryFailedLiveTurn(
                                activeThread.id,
                                entry,
                                rawLiveEntries,
                              ),
                            )
                          : null,
                      onForkFromTurn:
                          canMutateLiveTurn && capabilities.supportsThreadFork
                          ? () => unawaited(
                              threadController.forkThread(
                                ThreadForkOptions(
                                  threadId: activeThread.id,
                                  beforeTurnId: liveTurnId,
                                  cwd: activeThread.cwd,
                                ),
                              ),
                            )
                          : null,
                      onRevertFromTurn:
                          canMutateLiveTurn && capabilities.supportsThreadRevert
                          ? () => _revertTurn(activeThread.id, liveTurnId)
                          : null,
                    ),
                  );
                },
              ),
            ),
            if (_showJumpToLatest)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(
                  child: _JumpToLatestButton(onPressed: _jumpToLatest),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _composer(
    ConversationController controller, {
    bool isHeroCentered = false,
  }) {
    final palette = ThemeTokens.of(context);
    final thread = controller.thread;
    final projectCwd = thread?.cwd ?? _activeProjectDirectory;
    final capabilities = _activeCapabilities;
    final canCreateOnSend =
        thread == null &&
        widget.threadController != null &&
        projectCwd.isNotEmpty &&
        !(widget.threadController?.mutating ?? false);
    final canSteer = controller.canSteer;
    final enabled =
        (thread != null || canCreateOnSend) && (!controller.busy || canSteer);
    final desktopComposer = widget.hasDesktopShell && !isHeroCentered;
    final showStop = desktopComposer && controller.canInterrupt;
    final input = CallbackShortcuts(
      key: _composerInputKey,
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (enabled) {
            unawaited(_send());
          }
        },
        const SingleActivator(LogicalKeyboardKey.enter, shift: true):
            _insertComposerNewline,
      },
      child: TextField(
        key: const ValueKey('conversation-composer'),
        controller: _composerController,
        focusNode: _composerFocusNode,
        enabled: enabled,
        minLines: isHeroCentered ? 2 : 1,
        maxLines: 6,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          hintText: thread == null && !canCreateOnSend
              ? 'Select or create a thread'
              : canSteer
              ? 'Steer active turn in Codex'
              : 'Send a message to Codex',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(2, 2, 8, 8),
        ),
      ),
    );
    return Container(
      color: isHeroCentered ? Colors.transparent : palette.canvas,
      padding: isHeroCentered
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Center(
        child: CodexComposer(
          key: const ValueKey('floating_composer'),
          surfaceKey: const ValueKey('composer-surface'),
          isFocused: _composerFocusNode.hasFocus,
          radius: desktopComposer
              ? OfficialCodexTheme.composerRadiusPill
              : OfficialCodexTheme.composerRadius,
          padding: desktopComposer
              ? const EdgeInsets.all(8)
              : const EdgeInsets.fromLTRB(14, 10, 8, 8),
          backgroundColor: desktopComposer
              ? OfficialCodexTheme.of(context).workspaceBackground
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_composerAttachments.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (
                        var index = 0;
                        index < _composerAttachments.length;
                        index += 1
                      )
                        _ComposerAttachmentDraftChip(
                          key: ValueKey('composer-attachment-chip-$index'),
                          removeKey: ValueKey(
                            'composer-attachment-remove-$index',
                          ),
                          attachment: _composerAttachments[index],
                          onRemove: () {
                            setState(() {
                              _composerAttachments.removeAt(index);
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ],
              LayoutBuilder(
                builder: (context, rowConstraints) {
                  final width = rowConstraints.maxWidth;
                  final compactComposer = width < 560;
                  final controlTextScale = math.max(
                    1.0,
                    MediaQuery.textScalerOf(context).scale(12) / 12,
                  );
                  final iconOnly = width < 320 * controlTextScale;
                  // Reserve room for the input even when both Steer and Stop
                  // are visible. The controls keep their own row below it.
                  final inlineInput =
                      desktopComposer && width >= (showStop ? 440 : 360);
                  final busyReserve = controller.busy ? 76.0 : 0.0;
                  final maxModelLabelWidth =
                      (width - (compactComposer ? 260 : 455) - busyReserve)
                          .clamp(52.0, 148.0);
                  final controls = Row(
                    crossAxisAlignment: inlineInput
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.center,
                    children: [
                      CodexPopoverAnchor(
                        controller: _composerAttachPopoverController,
                        targetAnchor: Alignment.topLeft,
                        followerAnchor: Alignment.bottomLeft,
                        width: 210,
                        offset: const Offset(0, -6),
                        popoverBuilder: (context, close) =>
                            CodexMenu<UserAttachmentKind>(
                              items: [
                                const CodexMenuItem(
                                  value: UserAttachmentKind.mention,
                                  label: 'Attach file (@mention)',
                                  icon: Icon(Icons.description_outlined),
                                ),
                                const CodexMenuItem(
                                  value: UserAttachmentKind.image,
                                  label: 'Attach image',
                                  icon: Icon(Icons.image_outlined),
                                ),
                                if (capabilities.supportsSkillsAndMcp)
                                  const CodexMenuItem(
                                    value: UserAttachmentKind.skill,
                                    label: 'Attach skill (\$skill)',
                                    icon: Icon(Icons.auto_fix_high_outlined),
                                  ),
                                const CodexMenuItem(
                                  value: UserAttachmentKind.pastedText,
                                  label: 'Attach snippet',
                                  icon: Icon(Icons.notes_rounded),
                                ),
                              ],
                              onSelected: (kind) {
                                close();
                                unawaited(_promptAddAttachment(kind));
                              },
                            ),
                        child: CodexIconButton(
                          key: const ValueKey('composer-attach-button'),
                          tooltip: 'Add attachment',
                          size: 28.0,
                          onPressed: enabled
                              ? _composerAttachPopoverController.toggle
                              : null,
                          icon: const Icon(Icons.add_rounded, size: 17),
                        ),
                      ),
                      const SizedBox(width: 2),
                      if (inlineInput) Expanded(child: input),
                      if (!inlineInput && desktopComposer) const Spacer(),
                      if (controller.tokenUsage case final usage?
                          when desktopComposer && !compactComposer) ...[
                        _composerContextUsage(usage),
                        const SizedBox(width: ThemeTokens.space1),
                      ],
                      _ComposerModelSummaryButton(
                        controller: widget.settingsController,
                        maxLabelWidth: maxModelLabelWidth,
                        iconOnly: iconOnly,
                      ),
                      if (capabilities.supportsSandboxConfiguration)
                        _ExecutionSettingsButton(
                          controller: widget.settingsController,
                          iconOnly: desktopComposer || iconOnly,
                          useSandboxMenu: desktopComposer,
                        ),
                      if (!desktopComposer &&
                          projectCwd.isNotEmpty &&
                          !isHeroCentered &&
                          !compactComposer &&
                          capabilities.supportsWorkingDirectorySelection) ...[
                        const SizedBox(width: 4),
                        CodexTooltip(
                          message: projectCwd,
                          child: GestureDetector(
                            onTap: thread == null
                                ? _chooseProjectDirectory
                                : null,
                            child: MouseRegion(
                              cursor: thread == null
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.folder_outlined,
                                      size: 13,
                                      color: palette.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 110,
                                      ),
                                      child: Text(
                                        _projectName(projectCwd),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: palette.textSecondary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (!desktopComposer) const Spacer(),
                      if (controller.busy &&
                          !showStop &&
                          width >= 240 * controlTextScale)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Working…',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _composerController,
                        builder: (context, draft, _) {
                          final showSteer =
                              canSteer &&
                              (draft.text.trim().isNotEmpty ||
                                  _composerAttachments.isNotEmpty);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!showStop || showSteer)
                                CodexIconButton(
                                  key: const ValueKey('composer-send-button'),
                                  tooltip: canSteer
                                      ? 'Steer turn (Enter)'
                                      : 'Send (Enter)',
                                  size: 34.0,
                                  shape: BoxShape.circle,
                                  variant: CodexButtonVariant.primary,
                                  onPressed: enabled ? _send : null,
                                  icon: Icon(
                                    canSteer
                                        ? Icons.subdirectory_arrow_right_rounded
                                        : Icons.arrow_upward_rounded,
                                    size: 18,
                                  ),
                                ),
                              if (showStop)
                                CodexIconButton(
                                  key: const ValueKey('composer-stop-button'),
                                  tooltip: 'Stop turn',
                                  size: 34,
                                  shape: BoxShape.circle,
                                  variant: CodexButtonVariant.primary,
                                  onPressed: controller.interrupt,
                                  icon: const Icon(
                                    Icons.stop_rounded,
                                    size: 17,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [if (!inlineInput) input, controls],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _promptAddAttachment(UserAttachmentKind kind) async {
    final added = await showDialog<UserAttachment>(
      context: context,
      builder: (context) => _ComposerAttachmentDialog(kind: kind),
    );
    if (added != null && mounted) {
      setState(() {
        final next = normalizeUserAttachments([..._composerAttachments, added]);
        _composerAttachments
          ..clear()
          ..addAll(next);
      });
    }
  }

  Future<void> _send() async {
    if (_checkingColdResume) {
      return;
    }
    final text = _composerController.text;
    final attachments = List<UserAttachment>.of(_composerAttachments);
    if (text.trim().isEmpty && attachments.isEmpty) {
      return;
    }
    var targetThreadId = widget.controller.thread?.id;
    final selectionVersion = _threadSelectionVersion;
    var resumedForSend = false;
    if (widget.threadController case final threadController?) {
      if (targetThreadId == null) {
        final cwd = _activeProjectDirectory;
        if (cwd.isEmpty) {
          return;
        }
        final created = await threadController.startThread(
          widget.settingsController.threadOptions(cwd),
        );
        if (created == null) {
          return;
        }
        targetThreadId = created.id;
      } else {
        resumedForSend = threadController.selectedThreadNeedsResume(
          targetThreadId,
        );
        if (resumedForSend) {
          final ready = await _confirmColdResume(
            threadController,
            targetThreadId,
          );
          if (!mounted || !ready || !_sameComposerDraft(text, attachments)) {
            return;
          }
        }
        final ready = await threadController.ensureSelectedThreadLoaded(
          targetThreadId,
        );
        if (!ready) {
          return;
        }
      }
    }
    if (!mounted ||
        targetThreadId == null ||
        widget.controller.thread?.id != targetThreadId) {
      return;
    }
    if (resumedForSend &&
        (_threadSelectionVersion != selectionVersion ||
            !_sameComposerDraft(text, attachments))) {
      return;
    }
    _threadScrollBookmarks.remove(targetThreadId);
    if (widget.historyController.canReturnToNewest) {
      unawaited(widget.historyController.refresh());
    }
    if (_hasReadyScrollPosition) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
    final pendingBranch = _pendingBranchEdit;
    if (resumedForSend &&
        (widget.controller.busy ||
            widget.threadController?.selectedThread?.status ==
                ThreadRuntimeStatus.active)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'The resumed thread is already running. Your draft is still in the composer.',
          ),
        ),
      );
      return;
    }
    final submissionSelectionVersion = _threadSelectionVersion;
    final submitted = await widget.controller.submit(
      text,
      attachments: attachments,
    );
    if (submitted &&
        mounted &&
        _threadSelectionVersion == submissionSelectionVersion &&
        widget.controller.thread?.id == targetThreadId) {
      if (identical(_pendingBranchEdit, pendingBranch)) {
        _pendingBranchEdit = null;
      }
      final clearDraft = _sameComposerDraft(text, attachments);
      if (clearDraft) {
        _composerController.clear();
      }
      setState(() {
        if (clearDraft) {
          _composerAttachments.clear();
        }
        if (pendingBranch != null &&
            widget.controller.thread?.id == pendingBranch.threadId) {
          final nextTurnId =
              widget.controller.activeTurnId ??
              _latestLiveUserTurnId() ??
              'branch-${_branchSequence++}';
          final currentDag =
              _threadChatDags[pendingBranch.threadId] ??
              const ChatConversationDag.empty();
          _rememberThreadDag(
            pendingBranch.threadId,
            currentDag.recordTurnBranch(
              turnId: pendingBranch.turnId,
              originalUserText: pendingBranch.userText,
              originalAttachments: pendingBranch.attachments,
              originalAssistantText: pendingBranch.assistantText,
              nextTurnId: nextTurnId,
              nextUserText: text.trim(),
              nextAttachments: attachments,
            ),
          );
        }
      });
      _jumpToLatest();
    }
  }

  bool _sameComposerDraft(String text, List<UserAttachment> attachments) =>
      _composerController.text == text &&
      listEquals(_composerAttachments, attachments);

  Future<bool> _confirmColdResume(
    ThreadListController threadController,
    String threadId, {
    bool forReview = false,
  }) async {
    final selectionVersion = _threadSelectionVersion;
    bool stillCold() =>
        mounted &&
        _threadSelectionVersion == selectionVersion &&
        widget.controller.thread?.id == threadId &&
        threadController.selectedThreadNeedsResume(threadId);
    _checkingColdResume = true;
    try {
      final presence = await threadController.selectedThreadQueuePresence(
        threadId,
      );
      if (!mounted || !stillCold()) {
        return false;
      }
      if (presence == ThreadQueuePresence.empty ||
          presence == ThreadQueuePresence.unsupported) {
        return true;
      }
      final pending = presence == ThreadQueuePresence.pending;
      final continuation = forReview
          ? ' Start the review again after the thread is ready.'
          : ' Your new draft will stay in the composer.';
      final resume = await _confirmDesktopAction(
        context,
        title: pending ? 'Resume queued work?' : 'Could not check queued work',
        message: pending
            ? 'This thread has saved prompts. Resuming will let Codex run them.$continuation'
            : 'Resuming may start saved prompts.$continuation',
        confirmLabel: pending ? 'Resume queued work' : 'Resume thread',
        confirmVariant: CodexButtonVariant.primary,
      );
      if (resume && stillCold()) {
        final resumed = await threadController.resumeThread(threadId);
        if (forReview && resumed == null) {
          _reportReviewResumeFailure(
            threadController,
            threadId,
            selectionVersion,
          );
        }
      }
      return false;
    } finally {
      _checkingColdResume = false;
    }
  }

  void _insertComposerNewline() {
    final value = _composerController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final text = value.text.replaceRange(selection.start, selection.end, '\n');
    _composerController.value = value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: selection.start + 1),
      composing: TextRange.empty,
    );
  }

  void _recordItemMeasurement(String itemKey, String turnId, RenderBox box) {
    if (!box.hasSize) {
      return;
    }
    if ((_lastMeasuredItemWidth - box.size.width).abs() > 0.5) {
      _lastMeasuredItemWidth = box.size.width;
      _measuredItemHeights.clear();
    }
    _mountedItemBoxes[itemKey] = box;
    _mountedItemTurnIds[itemKey] = turnId;
    _measuredItemHeights.remove(itemKey);
    _measuredItemHeights[itemKey] = box.size.height;
    while (_measuredItemHeights.length > _maxMeasuredItemHeights) {
      _measuredItemHeights.remove(_measuredItemHeights.keys.first);
    }
  }

  void _unregisterItemBox(String itemKey, RenderBox box) {
    if (identical(_mountedItemBoxes[itemKey], box)) {
      _mountedItemBoxes.remove(itemKey);
      _mountedItemTurnIds.remove(itemKey);
    }
  }

  RenderViewport? _findViewport(RenderObject object) {
    RenderObject? current = object.parent;
    while (current != null) {
      if (current is RenderViewport) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }

  _VisibleAnchor? _captureVisibleAnchor() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      return null;
    }
    _VisibleAnchor? bestNonNegative;
    _VisibleAnchor? bestNegative;
    for (final entry in _mountedItemBoxes.entries) {
      final itemKey = entry.key;
      final box = entry.value;
      if (!box.attached || !box.hasSize) {
        continue;
      }
      final viewport = _findViewport(box);
      if (viewport == null || !viewport.hasSize) {
        continue;
      }
      final topDy = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final bottomDy = topDy + box.size.height;
      if (bottomDy <= 0 || topDy >= viewport.size.height) {
        continue;
      }
      final turnId = _mountedItemTurnIds[itemKey] ?? '';
      final candidate = _VisibleAnchor(
        itemKey: itemKey,
        turnId: turnId,
        viewportTopDy: topDy,
      );
      if (topDy >= 0) {
        if (bestNonNegative == null || topDy < bestNonNegative.viewportTopDy) {
          bestNonNegative = candidate;
        }
      } else {
        if (bestNegative == null || topDy > bestNegative.viewportTopDy) {
          bestNegative = candidate;
        }
      }
    }
    return bestNonNegative ?? bestNegative;
  }

  double get _averageMeasuredItemHeight {
    if (_measuredItemHeights.isEmpty) {
      return 72.0;
    }
    var sum = 0.0;
    for (final value in _measuredItemHeights.values) {
      sum += value;
    }
    return (sum / _measuredItemHeights.length).clamp(24.0, 4096.0);
  }

  double _estimatePixelsForReverseIndex(
    int targetReverseIndex,
    double targetTopDy,
  ) {
    final position = _scrollController.position;
    final viewportHeight = position.viewportDimension;
    final avgHeight = _averageMeasuredItemHeight;
    final targetKey =
        targetReverseIndex >= 0 &&
            targetReverseIndex < _currentTimelineItemKeys.length
        ? _currentTimelineItemKeys[targetReverseIndex]
        : null;
    final targetEstHeight =
        (targetKey != null ? _measuredItemHeights[targetKey] : null) ??
        avgHeight;
    final minTopDy = (24.0 - targetEstHeight).clamp(-double.infinity, 0.0);
    final maxTopDy = (viewportHeight - 24.0).clamp(0.0, viewportHeight);
    final clampedTargetTopDy = targetTopDy.clamp(minTopDy, maxTopDy);

    int? nearestIndex;
    RenderBox? nearestBox;
    RenderViewport? nearestViewport;
    for (final entry in _mountedItemBoxes.entries) {
      final box = entry.value;
      if (!box.attached || !box.hasSize) {
        continue;
      }
      final viewport = _findViewport(box);
      if (viewport == null || !viewport.hasSize) {
        continue;
      }
      final idx = _currentTimelineItemKeys.indexOf(entry.key);
      if (idx < 0) {
        continue;
      }
      if (nearestIndex == null ||
          (idx - targetReverseIndex).abs() <
              (nearestIndex - targetReverseIndex).abs()) {
        nearestIndex = idx;
        nearestBox = box;
        nearestViewport = viewport;
      }
    }

    if (nearestIndex != null && nearestBox != null && nearestViewport != null) {
      final nearestTopDy = nearestBox
          .localToGlobal(Offset.zero, ancestor: nearestViewport)
          .dy;
      var estimatedTargetTopDy = nearestTopDy;
      if (targetReverseIndex > nearestIndex) {
        for (var i = nearestIndex + 1; i <= targetReverseIndex; i += 1) {
          final key = _currentTimelineItemKeys[i];
          estimatedTargetTopDy -= _measuredItemHeights[key] ?? avgHeight;
        }
      } else if (targetReverseIndex < nearestIndex) {
        for (var i = targetReverseIndex + 1; i <= nearestIndex; i += 1) {
          final key = _currentTimelineItemKeys[i];
          estimatedTargetTopDy += _measuredItemHeights[key] ?? avgHeight;
        }
      }
      final delta = estimatedTargetTopDy - clampedTargetTopDy;
      return position.pixels + delta;
    }

    var cumulativeHeight = 36.0;
    for (
      var i = 0;
      i <= targetReverseIndex && i < _currentTimelineItemKeys.length;
      i += 1
    ) {
      final key = _currentTimelineItemKeys[i];
      cumulativeHeight += _measuredItemHeights[key] ?? avgHeight;
    }
    return viewportHeight - clampedTargetTopDy - cumulativeHeight;
  }

  ({bool mounted, bool jumped}) _alignAnchorToViewportOffset(
    String itemKey,
    double targetTopDy,
  ) {
    if (!_hasReadyScrollPosition) {
      return (mounted: false, jumped: false);
    }
    final box = _mountedItemBoxes[itemKey];
    if (box == null || !box.attached || !box.hasSize) {
      return (mounted: false, jumped: false);
    }
    final viewport = _findViewport(box);
    if (viewport == null || !viewport.hasSize) {
      return (mounted: false, jumped: false);
    }
    final minTopDy = (24.0 - box.size.height).clamp(-double.infinity, 0.0);
    final maxTopDy = (viewport.size.height - 24.0).clamp(
      0.0,
      viewport.size.height,
    );
    final clampedTargetTopDy = targetTopDy.clamp(minTopDy, maxTopDy);
    final currentTopDy = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final delta = currentTopDy - clampedTargetTopDy;
    var jumped = false;
    if (delta.abs() > 0.5) {
      final position = _scrollController.position;
      final targetPixels = (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - targetPixels).abs() > 0.5) {
        _aligningScrollAnchor = true;
        try {
          _scrollController.jumpTo(targetPixels);
          jumped = true;
        } finally {
          _aligningScrollAnchor = false;
        }
      }
    }
    return (mounted: true, jumped: jumped);
  }

  ({bool settled, bool jumped}) _restoreAnchorItemPosition({
    required String itemKey,
    required double targetTopDy,
  }) {
    final alignment = _alignAnchorToViewportOffset(itemKey, targetTopDy);
    if (alignment.mounted) {
      return (settled: !alignment.jumped, jumped: alignment.jumped);
    }
    if (!_hasReadyScrollPosition) {
      return (settled: false, jumped: false);
    }
    final targetReverseIndex = _currentTimelineItemKeys.indexOf(itemKey);
    if (targetReverseIndex < 0) {
      return (settled: true, jumped: false);
    }
    final position = _scrollController.position;
    final estimated = _estimatePixelsForReverseIndex(
      targetReverseIndex,
      targetTopDy,
    ).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((position.pixels - estimated).abs() > 0.5) {
      _aligningScrollAnchor = true;
      try {
        _scrollController.jumpTo(estimated);
      } finally {
        _aligningScrollAnchor = false;
      }
      return (settled: false, jumped: true);
    }
    return (settled: false, jumped: false);
  }

  void _captureThreadScrollBookmark(String threadId) {
    if (!_hasReadyScrollPosition ||
        _pendingStreamAnchor != null ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
      return;
    }
    final position = _scrollController.position;
    final distanceFromEnd = position.maxScrollExtent - position.pixels;
    final windowShifted = widget.historyController.canReturnToNewest;
    if (distanceFromEnd > _followThresholdPixels || windowShifted) {
      final anchor = _captureVisibleAnchor();
      if (anchor == null) {
        return;
      }
      _rememberThreadScrollBookmark(
        threadId,
        _ThreadScrollBookmark(
          scrollPixels: position.pixels,
          anchorItemKey: anchor.itemKey,
          anchorTurnId: anchor.turnId,
          anchorViewportTopDy: anchor.viewportTopDy,
        ),
      );
    } else {
      _threadScrollBookmarks.remove(threadId);
    }
  }

  void _handleThreadListChanged() {
    final threadController = widget.threadController;
    if (threadController == null) {
      return;
    }
    if (_goalEditorThreadId case final id?) {
      final goal = threadController.goalForThread(id);
      if (goal == null || goal.status == ThreadGoalStatus.complete) {
        _goalEditorThreadId = null;
        _restoreReadingPosition();
      }
    }
    if (threadController.revertVersion != _lastHandledRevertVersion) {
      _lastHandledRevertVersion = threadController.revertVersion;
      final revertedId = threadController.lastRevertedThreadId;
      if (revertedId != null) {
        _threadScrollBookmarks.remove(revertedId);
        if (revertedId == _activeThreadId) {
          widget.controller.clearEntries();
        }
      }
    }
    if (!threadController.initialLoadStarted ||
        threadController.loading ||
        threadController.loadingMore ||
        threadController.canLoadMore) {
      return;
    }
    final retainedThreadIds = threadController.threads
        .map((thread) => thread.id)
        .toSet();
    if (_activeThreadId case final activeId?) {
      retainedThreadIds.add(activeId);
    }
    _threadScrollBookmarks.removeWhere(
      (threadId, _) => !retainedThreadIds.contains(threadId),
    );
  }

  void _handleScrollPositionChanged() {
    if (!_hasReadyScrollPosition) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _runAfterFrame(_handleScrollPositionChanged);
      return;
    }
    final position = _scrollController.position;
    final distanceFromEnd = position.maxScrollExtent - position.pixels;
    final windowShifted = widget.historyController.canReturnToNewest;
    final shouldShowJump =
        distanceFromEnd > _followThresholdPixels || windowShifted;
    if (shouldShowJump != _showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = shouldShowJump);
    }
    if (_pendingThreadRestore || _aligningScrollAnchor) {
      return;
    }
    if (_activeThreadId case final threadId?) {
      _captureThreadScrollBookmark(threadId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _pendingThreadRestore ||
            _aligningScrollAnchor ||
            _activeThreadId != threadId) {
          return;
        }
        _captureThreadScrollBookmark(threadId);
      });
    }
  }

  void _rememberThreadScrollBookmark(
    String threadId,
    _ThreadScrollBookmark bookmark,
  ) {
    _threadScrollBookmarks.remove(threadId);
    _threadScrollBookmarks[threadId] = bookmark;
    while (_threadScrollBookmarks.length > _maxRetainedThreadScrollBookmarks) {
      _threadScrollBookmarks.remove(_threadScrollBookmarks.keys.first);
    }
  }

  void _setDetailMode(PresentationDetailMode mode) {
    setState(() {
      _detailMode = mode;
      if (mode == PresentationDetailMode.prose) {
        _clearCommandOutputPreview();
      } else {
        _reconcileLiveOutputPreview();
      }
    });
  }

  _CommandOutputPresentation? _commandOutputFor(
    BuildContext context, {
    required String itemId,
    required String turnId,
    required OutputDescriptor? output,
    required bool saved,
  }) {
    final reference = output?.reference;
    if (output == null || !output.available || reference == null) {
      return null;
    }
    final fullOutput = _commandOutputDialogAction(
      context,
      widget.outputGateway,
      output,
    );
    if (!widget.hasDesktopShell ||
        _detailMode == PresentationDetailMode.prose ||
        turnId.isEmpty ||
        (saved && turnId != widget.historyController.selectedTurnId)) {
      return (action: fullOutput, detail: null);
    }
    final key = (
      itemId: itemId,
      turnId: turnId,
      reference: reference,
      saved: saved,
    );
    final preview = _commandOutputPreview;
    final viewer = preview?.key == key ? preview?.viewer : null;
    final expanded = viewer != null;
    return (
      action: Semantics(
        expanded: expanded,
        child: CodexIconButton(
          size: 28,
          onPressed: _commandPreviewReading && !expanded
              ? null
              : () => unawaited(_toggleCommandOutputPreview(key, output)),
          icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          tooltip: expanded ? 'Hide output preview' : 'Show output preview',
        ),
      ),
      detail: viewer == null
          ? null
          : _InlineCommandOutput(viewer: viewer, openFullOutput: fullOutput),
    );
  }

  Future<void> _toggleCommandOutputPreview(
    _CommandOutputPreviewKey key,
    OutputDescriptor output,
  ) async {
    if (_commandOutputPreview?.key == key) {
      setState(_clearCommandOutputPreview);
      return;
    }
    if (_commandPreviewReading ||
        !widget.hasDesktopShell ||
        _detailMode == PresentationDetailMode.prose ||
        !(key.saved
            ? widget.historyController.selectedTurnId == key.turnId
            : _keepsLiveOutputPreview(key))) {
      return;
    }
    final viewer = OutputViewerController(
      gateway: widget.outputGateway,
      descriptor: output,
      pageBytes: 4 * 1024,
    );
    setState(() {
      _clearCommandOutputPreview();
      _commandOutputPreview = (key: key, viewer: viewer);
      _commandPreviewReading = true;
    });
    try {
      await viewer.loadInitial();
    } finally {
      if (mounted) {
        setState(() => _commandPreviewReading = false);
      }
    }
  }

  void _clearCommandOutputPreview() {
    _commandOutputPreview?.viewer.dispose();
    _commandOutputPreview = null;
  }

  ConversationEntry? _latestLiveActivity(List<ConversationEntry> entries) =>
      entries.reversed
          .where((entry) => entry.kind == ConversationEntryKind.activity)
          .firstOrNull;

  String? _collapsedLiveCommandSummary(
    List<ConversationEntry> entries,
    ConversationEntry? latest,
  ) {
    if (latest == null ||
        !latest.completed ||
        !latest.text.startsWith('Command: ') ||
        _nonNominalStatus(latest.status) != null) {
      return null;
    }
    final actions = <CommandActionKind>{};
    for (var index = entries.lastIndexOf(latest); index >= 0; index--) {
      final entry = entries[index];
      if (entry.turnId != latest.turnId ||
          entry.kind != ConversationEntryKind.activity ||
          !entry.completed ||
          _nonNominalStatus(entry.status) != null) {
        break;
      }
      if (entry.text == 'Reasoning' || entry.text.startsWith('Reasoning: ')) {
        continue;
      }
      if (!entry.text.startsWith('Command: ')) break;
      actions.addAll(
        entry.commandActions.isEmpty
            ? const {CommandActionKind.run}
            : entry.commandActions,
      );
    }
    if (actions.length < 2) return null;
    final labels = [
      if (actions.contains(CommandActionKind.read)) 'read files',
      if (actions.contains(CommandActionKind.listFiles)) 'listed files',
      if (actions.contains(CommandActionKind.search)) 'searched files',
      if (actions.contains(CommandActionKind.run)) 'ran commands',
    ];
    final first = labels.first;
    labels[0] = first[0].toUpperCase() + first.substring(1);
    return labels.length == 2
        ? labels.join(' and ')
        : '${labels.take(labels.length - 1).join(', ')}, and ${labels.last}';
  }

  void _reconcileLiveOutputPreview() {
    final key = _commandOutputPreview?.key;
    if (key != null && !key.saved && !_keepsLiveOutputPreview(key)) {
      _clearCommandOutputPreview();
    }
  }

  bool _keepsLiveOutputPreview(_CommandOutputPreviewKey key) {
    if (widget.historyController.canReturnToNewest) {
      return false;
    }
    final entries = widget.controller.entries;
    final latest = _detailMode == PresentationDetailMode.commands
        ? _latestLiveActivity(entries)
        : null;
    return entries.any(
      (entry) =>
          entry.id == key.itemId &&
          entry.turnId == key.turnId &&
          entry.completed &&
          entry.commandOutput?.reference == key.reference &&
          entry.commandOutput?.available == true &&
          (_detailMode == PresentationDetailMode.execution ||
              identical(entry, latest)),
    );
  }

  void _syncActiveThreadSelection() {
    final nextThreadId = widget.controller.thread?.id;
    if (nextThreadId == _activeThreadId) {
      return;
    }
    final previousThreadId = _activeThreadId;
    if (!_pendingThreadRestore && previousThreadId != null) {
      _captureThreadScrollBookmark(previousThreadId);
    }
    _activeThreadId = nextThreadId;
    _clearCommandOutputPreview();
    _showChanges = false;
    _goalEditorThreadId = null;
    _threadSelectionVersion += 1;
    _queuedLinkedPrThreadId = nextThreadId;
    _activeThreadLinkedPrs = null;
    _linkedPrLoadError = null;
    _linkedPrLaunchError = null;
    _linkedPrMutationError = null;
    _linkedPrMutationNotice = null;
    _linkedPrFormOpen = false;
    _linkedPrUrlController.clear();
    _linkedPrBranchController.clear();
    _linkedPrsPopoverController.hide();
    _timelineDetailsPopoverController.hide();
    _pendingThreadRestore = nextThreadId != null;
    _restorePagesLoaded = 0;
    _restoreAlignmentPasses = 0;
    _preLoadOlderAnchor = null;
    _pendingStreamAnchor = null;
    _pendingBranchEdit = null;
    _wasLoadingOlderTurns = widget.historyController.loadingOlderTurns;
    _wasWindowShifted = widget.historyController.canReturnToNewest;
    _lastHandledLoadOlderVersion = widget.historyController.loadOlderVersion;
    if (widget.isOffstage &&
        previousThreadId != null &&
        _composerController.text.isNotEmpty) {
      _composerController.clear();
    }
    if (_composerAttachments.isNotEmpty) {
      _composerAttachments.clear();
    }
    if (_showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = false);
    }
    if (nextThreadId != null) {
      _scheduleThreadScrollRestore();
      _requestActiveThreadLinkedPrs(nextThreadId);
    }
  }

  void _handleHistoryChanged() {
    _syncActiveThreadSelection();
    if (_commandOutputPreview?.key case final key?
        when key.saved &&
            widget.historyController.selectedTurnId != key.turnId) {
      _clearCommandOutputPreview();
    }
    _reconcileLiveOutputPreview();
    if (_wasWindowShifted &&
        !widget.historyController.canReturnToNewest &&
        !widget.historyController.loadingTurns) {
      _wasWindowShifted = false;
      _wasLoadingOlderTurns = false;
      _pendingThreadRestore = false;
      _preLoadOlderAnchor = null;
      _pendingStreamAnchor = null;
      _lastHandledLoadOlderVersion = widget.historyController.loadOlderVersion;
      if (_activeThreadId case final threadId?) {
        _threadScrollBookmarks.remove(threadId);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_hasReadyScrollPosition) {
          return;
        }
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _handleScrollPositionChanged();
      });
      return;
    }

    if (_pendingThreadRestore) {
      _wasLoadingOlderTurns = widget.historyController.loadingOlderTurns;
      _wasWindowShifted = widget.historyController.canReturnToNewest;
      _lastHandledLoadOlderVersion = widget.historyController.loadOlderVersion;
      _scheduleThreadScrollRestore();
      return;
    }

    if (widget.historyController.loadingOlderTurns && !_wasLoadingOlderTurns) {
      _preLoadOlderAnchor = _captureVisibleAnchor();
    }
    _wasLoadingOlderTurns = widget.historyController.loadingOlderTurns;

    if (widget.historyController.loadOlderVersion !=
        _lastHandledLoadOlderVersion) {
      _lastHandledLoadOlderVersion = widget.historyController.loadOlderVersion;
      for (final evictedId in widget.historyController.lastEvictedItemIds) {
        _measuredItemHeights.remove('history-$evictedId');
      }
      final anchor = _preLoadOlderAnchor ?? _captureVisibleAnchor();
      _preLoadOlderAnchor = null;
      if (anchor != null) {
        _schedulePostLoadAnchorAlignment(anchor, pass: 0);
      }
    }
    _wasWindowShifted = widget.historyController.canReturnToNewest;
  }

  void _runAfterFrame(VoidCallback callback) {
    void register() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        callback();
      });
      WidgetsBinding.instance.scheduleFrame();
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.postFrameCallbacks) {
      scheduleMicrotask(() {
        if (!mounted) {
          return;
        }
        register();
      });
    } else {
      register();
    }
  }

  void _schedulePostLoadAnchorAlignment(
    _VisibleAnchor anchor, {
    required int pass,
  }) {
    _runAfterFrame(() {
      if (!_hasReadyScrollPosition || _pendingThreadRestore) {
        _pendingStreamAnchor = null;
        return;
      }
      final result = _restoreAnchorItemPosition(
        itemKey: anchor.itemKey,
        targetTopDy: anchor.viewportTopDy,
      );
      if (!result.settled &&
          result.jumped &&
          pass + 1 < _maxRestoreAlignmentPasses) {
        _schedulePostLoadAnchorAlignment(anchor, pass: pass + 1);
        return;
      }
      _pendingStreamAnchor = null;
      _handleScrollPositionChanged();
    });
  }

  void _handleConversationChanged() {
    final previousThreadId = _activeThreadId;
    _syncActiveThreadSelection();
    _reconcileLiveOutputPreview();
    if (previousThreadId != _activeThreadId) {
      final thread = widget.controller.thread;
      if (thread != null &&
          widget.controller.entries.isEmpty &&
          widget.historyController.timelineItems.isEmpty &&
          !widget.historyController.loadingTurns) {
        _threadScrollBookmarks.remove(thread.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !widget.isOffstage &&
              widget.controller.thread?.id == thread.id &&
              !widget.controller.busy) {
            _composerFocusNode.requestFocus();
          }
        });
      }
      return;
    }
    if (!_hasReadyScrollPosition ||
        widget.historyController.canReturnToNewest) {
      return;
    }
    final distanceFromEnd =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    if (distanceFromEnd > _followThresholdPixels) {
      final anchor = _pendingStreamAnchor ?? _captureVisibleAnchor();
      if (anchor != null) {
        _pendingStreamAnchor = anchor;
        _schedulePostLoadAnchorAlignment(anchor, pass: 0);
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasReadyScrollPosition) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if ((_scrollController.offset - target).abs() <= 1.0) {
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  void _scheduleThreadScrollRestore() {
    if (_restoreScheduled) {
      return;
    }
    _restoreScheduled = true;
    _runAfterFrame(() {
      _restoreScheduled = false;
      if (!mounted || !_pendingThreadRestore) {
        return;
      }
      final threadId = _activeThreadId;
      if (threadId == null) {
        _pendingThreadRestore = false;
        return;
      }
      if (widget.historyController.loadingTurns) {
        return;
      }
      if (!_hasReadyScrollPosition) {
        if (!_scrollController.hasClients &&
            widget.historyController.timelineItems.isEmpty &&
            widget.controller.entries.isEmpty) {
          _threadScrollBookmarks.remove(threadId);
          _pendingThreadRestore = false;
          if (!widget.isOffstage && !widget.controller.busy) {
            _composerFocusNode.requestFocus();
          }
        }
        return;
      }
      final bookmark = _threadScrollBookmarks[threadId];
      if (bookmark == null) {
        final position = _scrollController.position;
        if ((position.pixels - position.maxScrollExtent).abs() > 0.5) {
          _scrollController.jumpTo(position.maxScrollExtent);
        }
        _pendingThreadRestore = false;
        _handleScrollPositionChanged();
        return;
      }

      final targetTurnId = bookmark.anchorTurnId;
      if (targetTurnId.isNotEmpty &&
          widget.historyController.turnForId(targetTurnId) == null &&
          widget.historyController.canLoadOlderTurns &&
          _restorePagesLoaded < _maxRestorePages) {
        _restorePagesLoaded += 1;
        unawaited(widget.historyController.loadOlderTurns());
        return;
      }

      final anchorKey = bookmark.anchorItemKey;
      final anchorTopDy = bookmark.anchorViewportTopDy;
      final targetTurnLoaded =
          targetTurnId.isEmpty ||
          widget.historyController.turnForId(targetTurnId) != null;
      if (targetTurnLoaded && _currentTimelineItemKeys.contains(anchorKey)) {
        if (_restoreAlignmentPasses == 0 &&
            !_mountedItemBoxes.containsKey(anchorKey) &&
            !widget.historyController.canReturnToNewest) {
          final position = _scrollController.position;
          final initialTarget = bookmark.scrollPixels.clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
          if ((position.pixels - initialTarget).abs() > 0.5) {
            _aligningScrollAnchor = true;
            try {
              _scrollController.jumpTo(initialTarget);
            } finally {
              _aligningScrollAnchor = false;
            }
          }
          _restoreAlignmentPasses += 1;
          _scheduleThreadScrollRestore();
          return;
        }
        final result = _restoreAnchorItemPosition(
          itemKey: anchorKey,
          targetTopDy: anchorTopDy,
        );
        if (!result.settled &&
            result.jumped &&
            _restoreAlignmentPasses < _maxRestoreAlignmentPasses) {
          _restoreAlignmentPasses += 1;
          _scheduleThreadScrollRestore();
          return;
        }
        _rememberThreadScrollBookmark(
          threadId,
          _ThreadScrollBookmark(
            scrollPixels: _scrollController.position.pixels,
            anchorItemKey: anchorKey,
            anchorTurnId: targetTurnId,
            anchorViewportTopDy: anchorTopDy,
          ),
        );
        _pendingThreadRestore = false;
        _handleScrollPositionChanged();
        return;
      }

      // Scheme A: When the bookmarked content anchor is absent from the loaded
      // window after bounded pagination (_maxRestorePages reached or no older
      // turns remain), never fall back to raw scrollPixels on the wrong turn
      // window. Discard the stale bookmark and reset deterministically to the
      // newest boundary.
      _threadScrollBookmarks.remove(threadId);
      if (widget.historyController.canReturnToNewest) {
        unawaited(widget.historyController.refresh());
        return;
      }
      final position = _scrollController.position;
      if ((position.pixels - position.maxScrollExtent).abs() > 0.5) {
        _aligningScrollAnchor = true;
        try {
          _scrollController.jumpTo(position.maxScrollExtent);
        } finally {
          _aligningScrollAnchor = false;
        }
      }
      _pendingThreadRestore = false;
      _handleScrollPositionChanged();
    });
  }

  void _jumpToLatest() {
    if (_activeThreadId case final threadId?) {
      _threadScrollBookmarks.remove(threadId);
    }
    if (_showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = false);
    }
    if (widget.historyController.canReturnToNewest) {
      unawaited(widget.historyController.refresh());
      return;
    }
    if (!_hasReadyScrollPosition) {
      return;
    }
    final target = _scrollController.position.maxScrollExtent;
    final distance = (target - _scrollController.offset).abs();
    if (distance > 1200) {
      _scrollController.jumpTo(target);
    } else if (distance > 0.5) {
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }
}

class _MeasuredTimelineItem extends SingleChildRenderObjectWidget {
  const _MeasuredTimelineItem({
    super.key,
    required this.itemKey,
    required this.turnId,
    required this.onMeasured,
    required this.onUnmount,
    required super.child,
  });

  final String itemKey;
  final String turnId;
  final void Function(String itemKey, String turnId, RenderBox box) onMeasured;
  final void Function(String itemKey, RenderBox box) onUnmount;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasuredTimelineItem(
        itemKey: itemKey,
        turnId: turnId,
        onMeasured: onMeasured,
        onUnmount: onUnmount,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasuredTimelineItem renderObject,
  ) {
    renderObject
      ..itemKey = itemKey
      ..turnId = turnId
      ..onMeasured = onMeasured
      ..onUnmount = onUnmount;
  }
}

class _RenderMeasuredTimelineItem extends RenderProxyBox {
  _RenderMeasuredTimelineItem({
    required String itemKey,
    required this.turnId,
    required this.onMeasured,
    required this.onUnmount,
  }) {
    _itemKey = itemKey;
  }

  late String _itemKey;
  String turnId;
  void Function(String itemKey, String turnId, RenderBox box) onMeasured;
  void Function(String itemKey, RenderBox box) onUnmount;

  set itemKey(String value) {
    if (_itemKey == value) {
      return;
    }
    onUnmount(_itemKey, this);
    _itemKey = value;
  }

  @override
  void performLayout() {
    super.performLayout();
    onMeasured(_itemKey, turnId, this);
  }

  @override
  void detach() {
    onUnmount(_itemKey, this);
    super.detach();
  }
}

class _JumpToLatestButton extends StatelessWidget {
  const _JumpToLatestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.borderStrong,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        key: const ValueKey('jump-to-latest-button'),
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 14,
                  color: palette.textPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Jump to latest',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: palette.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationScrollView extends CustomScrollView {
  const _ConversationScrollView({
    super.key,
    super.controller,
    required this.padding,
    required this.itemCount,
    this.findChildIndexCallback,
    required this.itemBuilder,
  }) : super(anchor: 1.0, center: const ValueKey('conversation-bottom-anchor'));

  final EdgeInsets padding;
  final int itemCount;
  final ChildIndexGetter? findChildIndexCallback;
  final IndexedWidgetBuilder itemBuilder;

  @override
  List<Widget> buildSlivers(BuildContext context) => [
    SliverPadding(
      padding: padding,
      sliver: SliverList.builder(
        itemCount: itemCount,
        findChildIndexCallback: findChildIndexCallback,
        itemBuilder: itemBuilder,
      ),
    ),
    const SliverToBoxAdapter(
      key: ValueKey('conversation-bottom-anchor'),
      child: SizedBox.shrink(),
    ),
  ];

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) => _ConversationViewport(
    axisDirection: axisDirection,
    offset: offset,
    anchor: anchor,
    center: center,
    scrollCacheExtent: scrollCacheExtent,
    clipBehavior: clipBehavior,
    slivers: slivers,
  );
}

class _ConversationViewport extends Viewport {
  _ConversationViewport({
    super.axisDirection,
    required super.offset,
    super.anchor,
    super.center,
    super.scrollCacheExtent,
    super.clipBehavior,
    super.slivers,
  });

  @override
  RenderViewport createRenderObject(BuildContext context) =>
      _RenderConversationViewport(
        axisDirection: axisDirection,
        crossAxisDirection: Viewport.getDefaultCrossAxisDirection(
          context,
          axisDirection,
        ),
        anchor: anchor,
        offset: offset,
        scrollCacheExtent: scrollCacheExtent,
        clipBehavior: clipBehavior,
      );
}

class _RenderConversationViewport extends RenderViewport {
  _RenderConversationViewport({
    super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    super.anchor,
    super.scrollCacheExtent,
    super.clipBehavior,
  });

  @override
  void performLayout() {
    super.performLayout();
    if (axis != Axis.vertical || center == null) {
      return;
    }
    var totalExtent = 0.0;
    for (
      RenderSliver? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      totalExtent += child.geometry?.scrollExtent ?? 0.0;
    }
    final shift = size.height - totalExtent;
    if (shift <= 0) {
      return;
    }
    for (
      RenderSliver? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      final parentData = child.parentData! as SliverPhysicalParentData;
      parentData.paintOffset = parentData.paintOffset.translate(0, -shift);
    }
  }

  @override
  RevealedOffset getOffsetToReveal(
    RenderObject target,
    double alignment, {
    Rect? rect,
    Axis? axis,
  }) {
    if (this.axis != Axis.vertical || center == null || !hasSize) {
      return super.getOffsetToReveal(target, alignment, rect: rect, axis: axis);
    }
    rect ??= target.paintBounds;
    final transform = target.getTransformTo(this);
    final targetRect = MatrixUtils.transformRect(transform, rect);
    final desiredTop = (size.height - targetRect.height) * alignment;
    final delta = targetRect.top - desiredTop;
    final targetOffset = offset.pixels + delta;
    return RevealedOffset(
      offset: targetOffset,
      rect: targetRect.translate(0.0, -delta),
    );
  }
}

class _ConversationEntryView extends StatelessWidget {
  const _ConversationEntryView({
    super.key,
    required this.entry,
    this.turnId,
    this.attachments = const [],
    this.isReasoning = false,
    this.isCommand = false,
    this.inlineActivity = false,
    this.revealAssistantCopy = false,
    this.activitySummary,
    this.activityDetail,
    this.leadingHeader,
    this.trailingAction,
    this.onForkFromTurn,
    this.onRevertFromTurn,
    this.onEditFromTurn,
    this.onRegenerateFromTurn,
    this.onContinueTurn,
    this.onRetryTurn,
    this.siblingBranchInfo,
    this.onSelectSiblingBranch,
    this.isSearchMatch = false,
    this.isActiveSearchMatch = false,
  });

  final ConversationEntry entry;
  final String? turnId;
  final List<UserAttachment> attachments;
  final bool isReasoning;
  final bool isCommand;
  final bool inlineActivity;
  final bool revealAssistantCopy;
  final String? activitySummary;
  final Widget? activityDetail;
  final Widget? leadingHeader;
  final Widget? trailingAction;
  final VoidCallback? onForkFromTurn;
  final VoidCallback? onRevertFromTurn;
  final VoidCallback? onEditFromTurn;
  final VoidCallback? onRegenerateFromTurn;
  final VoidCallback? onContinueTurn;
  final VoidCallback? onRetryTurn;
  final ChatSiblingBranchInfo? siblingBranchInfo;
  final ValueChanged<int>? onSelectSiblingBranch;
  final bool isSearchMatch;
  final bool isActiveSearchMatch;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    if (entry.kind == ConversationEntryKind.user) {
      final message = _UserMessageEntryView(
        entry: entry,
        turnId: turnId,
        attachments: attachments,
        revealActions: inlineActivity,
        onForkFromTurn: onForkFromTurn,
        onRevertFromTurn: onRevertFromTurn,
        onEditFromTurn: onEditFromTurn,
        onRegenerateFromTurn: onRegenerateFromTurn,
        siblingBranchInfo: siblingBranchInfo,
        onSelectSiblingBranch: onSelectSiblingBranch,
        isSearchMatch: isSearchMatch,
        isActiveSearchMatch: isActiveSearchMatch,
      );
      final header = leadingHeader;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: header == null ? message : Column(children: [message, header]),
        ),
      );
    }

    if (isReasoning ||
        (entry.kind == ConversationEntryKind.activity &&
            (entry.text == 'Reasoning' ||
                (inlineActivity && entry.text.startsWith('Reasoning: '))))) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?leadingHeader,
              _ReasoningEntryView(entry: entry, inline: inlineActivity),
            ],
          ),
        ),
      );
    }

    final isReview = entry.kind == ConversationEntryKind.review;
    final isActivity = entry.kind == ConversationEntryKind.activity || isReview;
    final hasActivitySurface = isActivity && (!inlineActivity || isReview);
    final isError = entry.kind == ConversationEntryKind.error;
    final showAssistantCopy =
        entry.kind == ConversationEntryKind.assistant &&
        entry.completed &&
        entry.text.trim().isNotEmpty;
    final copyButton = showAssistantCopy
        ? _MessageCopyButton(
            key: ValueKey('assistant-copy-${entry.id}'),
            text: entry.text,
          )
        : null;
    final hideCopyAtRest =
        inlineActivity &&
        revealAssistantCopy &&
        copyButton != null &&
        onContinueTurn == null &&
        onRetryTurn == null;
    final actionKeySuffix = (turnId != null && turnId!.isNotEmpty)
        ? turnId!
        : entry.id;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: OfficialCodexTheme.maxContentWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?leadingHeader,
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                key: isActiveSearchMatch
                    ? ValueKey('active-search-match-${entry.id}')
                    : null,
                width: double.infinity,
                margin: EdgeInsets.only(
                  bottom: isActivity ? ThemeTokens.space2 : ThemeTokens.space4,
                ),
                padding: hasActivitySurface || isError
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: isError
                      ? palette.danger.withValues(alpha: 0.08)
                      : hasActivitySurface
                      ? isReview
                            ? palette.accent.withValues(alpha: 0.06)
                            : palette.surfaceRaised
                      : isActiveSearchMatch
                      ? palette.accent.withValues(alpha: 0.06)
                      : Colors.transparent,
                  border: hasActivitySurface || isError
                      ? Border.all(
                          color: isError
                              ? palette.danger.withValues(alpha: 0.3)
                              : palette.border,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
                ),
                child: isActivity
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ActivityContent(
                            entry: entry,
                            isCommand: isCommand,
                            inline: !hasActivitySurface,
                            collapsedSummary: activitySummary,
                            trailingAction: trailingAction,
                          ),
                          ?activityDetail,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_nonNominalStatus(entry.status)
                              case final statusLabel?) ...[
                            Text(
                              statusLabel,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: ThemeTokens.space1),
                          ],
                          if (entry.kind == ConversationEntryKind.assistant)
                            _assistantProse(
                              copyOnInteraction: hideCopyAtRest
                                  ? copyButton
                                  : null,
                            )
                          else
                            SelectableText(
                              entry.text,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: isError
                                        ? palette.danger
                                        : palette.textPrimary,
                                  ),
                            ),
                          if (copyButton != null && !hideCopyAtRest ||
                              onContinueTurn != null ||
                              onRetryTurn != null) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ?copyButton,
                                if (onContinueTurn != null)
                                  CodexButton(
                                    key: ValueKey(
                                      'turn-continue-$actionKeySuffix',
                                    ),
                                    size: CodexButtonSize.sm,
                                    variant: CodexButtonVariant.secondary,
                                    onPressed: onContinueTurn,
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 14,
                                    ),
                                    label: 'Continue',
                                  ),
                                if (onRetryTurn != null)
                                  CodexButton(
                                    key: ValueKey(
                                      'turn-retry-$actionKeySuffix',
                                    ),
                                    size: CodexButtonSize.sm,
                                    variant: CodexButtonVariant.secondary,
                                    onPressed: onRetryTurn,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 14,
                                    ),
                                    label: 'Retry',
                                  ),
                              ],
                            ),
                          ],
                          if (!entry.completed) ...[
                            const SizedBox(height: ThemeTokens.space2),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: palette.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assistantProse({required Widget? copyOnInteraction}) {
    final prose = AssistantMarkdown(
      data: entry.text,
      completed: entry.completed,
      proseLineHeight: inlineActivity
          ? OfficialCodexTheme.assistantProseLineHeight
          : null,
    );
    if (copyOnInteraction == null) {
      return prose;
    }
    return _HoverMessageActions(
      content: prose,
      actionsKey: ValueKey('desktop-assistant-message-actions-${entry.id}'),
      alignment: CrossAxisAlignment.start,
      actions: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: copyOnInteraction,
      ),
    );
  }
}

class _MessageCopyButton extends StatefulWidget {
  const _MessageCopyButton({
    super.key,
    required this.text,
    this.tooltip = 'Copy response',
  });

  final String text;
  final String tooltip;

  @override
  State<_MessageCopyButton> createState() => _MessageCopyButtonState();
}

class _MessageCopyButtonState extends State<_MessageCopyButton> {
  var _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return CodexIconButton(
      tooltip: _copied ? 'Copied' : widget.tooltip,
      size: 22,
      onPressed: _copy,
      icon: Icon(
        _copied ? Icons.check_rounded : Icons.content_copy_rounded,
        size: 14,
        color: _copied ? palette.success : palette.textMuted,
      ),
    );
  }
}

String? _nonNominalStatus(String? status) {
  if (status == null) {
    return null;
  }
  final normalized = status.trim();
  if (normalized.isEmpty ||
      normalized == 'completed' ||
      normalized == 'inProgress') {
    return null;
  }
  return normalized;
}

class _UserMessageEntryView extends StatelessWidget {
  const _UserMessageEntryView({
    required this.entry,
    this.turnId,
    required this.attachments,
    required this.revealActions,
    this.onForkFromTurn,
    this.onRevertFromTurn,
    this.onEditFromTurn,
    this.onRegenerateFromTurn,
    this.siblingBranchInfo,
    this.onSelectSiblingBranch,
    this.isSearchMatch = false,
    this.isActiveSearchMatch = false,
  });

  final ConversationEntry entry;
  final String? turnId;
  final List<UserAttachment> attachments;
  final bool revealActions;
  final VoidCallback? onForkFromTurn;
  final VoidCallback? onRevertFromTurn;
  final VoidCallback? onEditFromTurn;
  final VoidCallback? onRegenerateFromTurn;
  final ChatSiblingBranchInfo? siblingBranchInfo;
  final ValueChanged<int>? onSelectSiblingBranch;
  final bool isSearchMatch;
  final bool isActiveSearchMatch;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final presentation = parseUserMessagePresentation(
      entry.text,
      attachments: attachments,
    );
    final fullText = presentation.bodyText.trim();
    final attachmentWidgets = [
      for (var index = 0; index < presentation.attachments.length; index += 1)
        _UserAttachmentChip(
          key: ValueKey('user-attachment-${entry.id}-$index'),
          attachment: presentation.attachments[index],
        ),
    ];
    final keySuffix = turnId ?? entry.id;
    final branch = siblingBranchInfo;
    final selectBranch = onSelectSiblingBranch;
    final actionButtons = [
      if (branch != null && branch.hasMultipleBranches) ...[
        CodexIconButton(
          key: ValueKey('branch-prev-$keySuffix'),
          tooltip: 'Previous response branch',
          size: 18,
          onPressed: branch.canSelectPrevious && selectBranch != null
              ? () => selectBranch(-1)
              : null,
          icon: const Icon(Icons.chevron_left_rounded, size: 14),
        ),
        Text(
          branch.displayLabel,
          key: ValueKey('branch-label-$keySuffix'),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontSize: 11, color: palette.textSecondary),
        ),
        CodexIconButton(
          key: ValueKey('branch-next-$keySuffix'),
          tooltip: 'Next response branch',
          size: 18,
          onPressed: branch.canSelectNext && selectBranch != null
              ? () => selectBranch(1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded, size: 14),
        ),
        const SizedBox(width: 2),
      ],
      if (fullText.isNotEmpty)
        _MessageCopyButton(
          key: ValueKey('user-copy-${entry.id}'),
          text: fullText,
          tooltip: 'Copy message',
        ),
      if (onEditFromTurn != null)
        CodexIconButton(
          key: ValueKey('turn-edit-$keySuffix'),
          tooltip: 'Edit message and resubmit',
          size: 22,
          onPressed: onEditFromTurn,
          icon: const Icon(Icons.edit_outlined, size: 14),
        ),
      if (onRegenerateFromTurn != null)
        CodexIconButton(
          key: ValueKey('turn-regenerate-$keySuffix'),
          tooltip: 'Regenerate response from this turn',
          size: 22,
          onPressed: onRegenerateFromTurn,
          icon: const Icon(Icons.refresh_rounded, size: 14),
        ),
      if (onForkFromTurn != null)
        CodexIconButton(
          key: ValueKey('turn-fork-$keySuffix'),
          tooltip: 'Fork thread before this turn',
          size: 22,
          onPressed: onForkFromTurn,
          icon: const Icon(Icons.call_split_rounded, size: 14),
        ),
      if (onRevertFromTurn != null)
        CodexIconButton(
          key: ValueKey('turn-revert-$keySuffix'),
          tooltip: 'Revert thread before this turn',
          size: 22,
          onPressed: onRevertFromTurn,
          icon: const Icon(Icons.undo_rounded, size: 14),
        ),
    ];
    final bubble = CodexMessageBubble(
      key: ValueKey('user-message-bubble-${entry.id}'),
      text: fullText,
      attachments: attachmentWidgets,
      expandKey: ValueKey('user-expand-${entry.id}'),
    );

    return Padding(
      key: isActiveSearchMatch
          ? ValueKey('active-search-match-${entry.id}')
          : null,
      padding: EdgeInsets.only(
        bottom: revealActions && actionButtons.isNotEmpty
            ? ThemeTokens.space1
            : ThemeTokens.space4,
      ),
      child: actionButtons.isEmpty
          ? bubble
          : revealActions
          ? _HoverMessageActions(
              content: bubble,
              actionsKey: const ValueKey('desktop-user-message-actions'),
              alignment: CrossAxisAlignment.end,
              actions: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actionButtons,
              ),
            )
          : Stack(
              alignment: Alignment.centerRight,
              children: [
                Positioned(
                  left: 0,
                  bottom: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actionButtons,
                  ),
                ),
                bubble,
              ],
            ),
    );
  }
}

class _HoverMessageActions extends StatefulWidget {
  const _HoverMessageActions({
    required this.content,
    required this.actions,
    required this.actionsKey,
    required this.alignment,
  });

  final Widget content;
  final Widget actions;
  final Key actionsKey;
  final CrossAxisAlignment alignment;

  @override
  State<_HoverMessageActions> createState() => _HoverMessageActionsState();
}

class _HoverMessageActionsState extends State<_HoverMessageActions> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Focus(
      canRequestFocus: false,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Column(
        crossAxisAlignment: widget.alignment,
        children: [
          widget.content,
          Opacity(
            key: widget.actionsKey,
            opacity: _hovered || _focused ? 1 : 0,
            alwaysIncludeSemantics: true,
            child: widget.actions,
          ),
        ],
      ),
    ),
  );
}

class _ComposerAttachmentDraftChip extends StatelessWidget {
  const _ComposerAttachmentDraftChip({
    super.key,
    required this.removeKey,
    required this.attachment,
    required this.onRemove,
  });

  final Key removeKey;
  final UserAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final icon = switch (attachment.kind) {
      UserAttachmentKind.pastedText => Icons.notes_rounded,
      UserAttachmentKind.file => Icons.description_outlined,
      UserAttachmentKind.ideContext => Icons.code_rounded,
      UserAttachmentKind.image => Icons.image_outlined,
      UserAttachmentKind.skill => Icons.auto_fix_high_outlined,
      UserAttachmentKind.mention => Icons.alternate_email_rounded,
    };
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border.all(
          color: palette.border,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.textSecondary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              attachment.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.textPrimary),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            key: removeKey,
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerAttachmentDialog extends StatefulWidget {
  const _ComposerAttachmentDialog({required this.kind});

  final UserAttachmentKind kind;

  @override
  State<_ComposerAttachmentDialog> createState() =>
      _ComposerAttachmentDialogState();
}

class _ComposerAttachmentDialogState extends State<_ComposerAttachmentDialog> {
  late final TextEditingController _primaryController;
  late final TextEditingController _secondaryController;

  @override
  void initState() {
    super.initState();
    _primaryController = TextEditingController();
    _secondaryController = TextEditingController();
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  void _submit() {
    final primary = _primaryController.text.trim();
    if (primary.isEmpty) {
      return;
    }
    final secondary = _secondaryController.text.trim();
    final attachment = switch (widget.kind) {
      UserAttachmentKind.mention || UserAttachmentKind.file => UserAttachment(
        kind: UserAttachmentKind.mention,
        label: secondary.isNotEmpty
            ? secondary
            : primary
                  .split('/')
                  .lastWhere((s) => s.isNotEmpty, orElse: () => primary),
        path: primary,
      ),
      UserAttachmentKind.image => UserAttachment(
        kind: UserAttachmentKind.image,
        label: secondary.isNotEmpty
            ? secondary
            : primary
                  .split('/')
                  .lastWhere((s) => s.isNotEmpty, orElse: () => primary),
        path: primary,
      ),
      UserAttachmentKind.skill => UserAttachment(
        kind: UserAttachmentKind.skill,
        label: primary.startsWith(r'$') ? primary : '\$$primary',
        path: secondary.isNotEmpty ? secondary : primary,
      ),
      UserAttachmentKind.pastedText ||
      UserAttachmentKind.ideContext => UserAttachment(
        kind: UserAttachmentKind.pastedText,
        label: secondary.isNotEmpty
            ? secondary
            : 'Snippet (${primary.length} chars)',
        preview: primary,
      ),
    };
    Navigator.of(context).pop(attachment);
  }

  @override
  Widget build(BuildContext context) {
    final (title, primaryHint, secondaryHint) = switch (widget.kind) {
      UserAttachmentKind.mention || UserAttachmentKind.file => (
        'Attach file (@mention)',
        'File path (e.g. lib/main.dart)',
        'Optional label',
      ),
      UserAttachmentKind.image => (
        'Attach image',
        'Image path or URL',
        'Optional label',
      ),
      UserAttachmentKind.skill => (
        'Attach skill (\$skill)',
        'Skill name (e.g. frontend-design)',
        'Skill path (optional)',
      ),
      UserAttachmentKind.pastedText || UserAttachmentKind.ideContext => (
        'Attach snippet',
        'Snippet content',
        'Optional label',
      ),
    };
    final theme = OfficialCodexTheme.of(context);
    return AlertDialog(
      backgroundColor: theme.modalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OfficialCodexTheme.popoverRadius),
        side: BorderSide(
          color: theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      title: Text(title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('composer-attachment-primary-field'),
              controller: _primaryController,
              autofocus: true,
              maxLines: widget.kind == UserAttachmentKind.pastedText ? 4 : 1,
              decoration: InputDecoration(hintText: primaryHint),
              onSubmitted: widget.kind == UserAttachmentKind.pastedText
                  ? null
                  : (_) => _submit(),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('composer-attachment-secondary-field'),
              controller: _secondaryController,
              decoration: InputDecoration(hintText: secondaryHint),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        CodexButton(
          variant: CodexButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
          label: 'Cancel',
        ),
        CodexButton(
          key: const ValueKey('composer-attachment-confirm-button'),
          variant: CodexButtonVariant.primary,
          onPressed: _submit,
          label: 'Attach',
        ),
      ],
    );
  }
}

class _UserAttachmentChip extends StatelessWidget {
  const _UserAttachmentChip({super.key, required this.attachment});

  final UserAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final icon = switch (attachment.kind) {
      UserAttachmentKind.pastedText => Icons.notes_rounded,
      UserAttachmentKind.file => Icons.description_outlined,
      UserAttachmentKind.ideContext => Icons.code_rounded,
      UserAttachmentKind.image => Icons.image_outlined,
      UserAttachmentKind.skill => Icons.auto_fix_high_outlined,
      UserAttachmentKind.mention => Icons.alternate_email_rounded,
    };
    final hasDetails =
        (attachment.path != null && attachment.path!.isNotEmpty) ||
        (attachment.preview != null && attachment.preview!.isNotEmpty);
    return MouseRegion(
      cursor: hasDetails ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: hasDetails ? () => _showAttachmentDetails(context) : null,
        child: Container(
          decoration: BoxDecoration(
            color: palette.surfaceRaised,
            border: Border.all(
              color: palette.border,
              width: OfficialCodexTheme.hairlineBorderWidth,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: palette.textSecondary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  attachment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: palette.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(attachment.label),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth * 0.75,
            maxHeight: 420,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (attachment.path case final path?) ...[
                  Text('Source', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  SelectableText(
                    path,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
                if (attachment.preview case final preview?) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Preview',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    preview,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          CodexButton(
            onPressed: () => Navigator.of(context).pop(),
            label: 'Close',
          ),
        ],
      ),
    );
  }
}

class _ReasoningEntryView extends StatelessWidget {
  const _ReasoningEntryView({required this.entry, required this.inline});

  final ConversationEntry entry;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final raw = inline && entry.text.startsWith('Reasoning: ')
        ? entry.text.substring('Reasoning: '.length).trim()
        : entry.text.trim();
    final hasSummary = raw.isNotEmpty && raw != 'Reasoning';
    final textTheme = Theme.of(context).textTheme;
    final summaryStyle = textTheme.bodySmall?.copyWith(
      color: palette.textSecondary,
      height: 1.4,
    );
    if (inline && !entry.completed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: ThemeTokens.space2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thinking',
              style: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
            ),
            if (hasSummary) SelectableText(raw, style: summaryStyle),
          ],
        ),
      );
    }
    final summary = !hasSummary
        ? (entry.completed ? 'Thought' : 'Thinking…')
        : raw;
    return Padding(
      padding: const EdgeInsets.only(bottom: ThemeTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!inline) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.psychology_outlined,
                size: 15,
                color: palette.textMuted,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: SelectableText(summary, style: summaryStyle)),
        ],
      ),
    );
  }
}

class _ActivityContent extends StatelessWidget {
  const _ActivityContent({
    required this.entry,
    this.isCommand = false,
    required this.inline,
    this.collapsedSummary,
    this.trailingAction,
  });

  final ConversationEntry entry;
  final bool isCommand;
  final bool inline;
  final String? collapsedSummary;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final effectiveCommand = isCommand || entry.text.startsWith('Command: ');
    final isFileChange = entry.text.startsWith('File changes:');
    final isToolCall =
        entry.text.startsWith('MCP: ') ||
        entry.text.startsWith('Tool: ') ||
        entry.text.startsWith('Collaboration: ');
    final isWebSearch = entry.text.startsWith('Web search');
    final isPlan = entry.text.startsWith('Plan');
    final isCompaction = entry.text.startsWith('Context compacted');
    final isReview =
        entry.text.startsWith('Review started:') ||
        entry.text.startsWith('Review completed:');
    final statusBadge = _nonNominalStatus(entry.status);
    final icon = collapsedSummary != null
        ? Icons.menu_book_outlined
        : !entry.completed
        ? Icons.hourglass_top_rounded
        : effectiveCommand
        ? Icons.terminal_rounded
        : isFileChange
        ? Icons.difference_outlined
        : isToolCall
        ? Icons.extension_outlined
        : isWebSearch
        ? Icons.travel_explore_rounded
        : isPlan
        ? Icons.checklist_rounded
        : isCompaction
        ? Icons.compress_rounded
        : isReview
        ? Icons.rate_review_outlined
        : Icons.check_circle_outline_rounded;
    final iconColor = !entry.completed
        ? palette.accent
        : statusBadge != null
        ? palette.warning
        : effectiveCommand ||
              isFileChange ||
              isToolCall ||
              isWebSearch ||
              isPlan ||
              isCompaction ||
              isReview
        ? palette.textSecondary
        : palette.success;

    final summary = collapsedSummary ?? entry.text;
    return CodexActivityRow(
      summary: summary,
      icon: Icon(icon, size: 14, color: iconColor),
      statusText: statusBadge,
      isRunning: !entry.completed,
      isError: statusBadge != null,
      trailingAction: trailingAction,
      inline: inline,
      textWidget: inline && (collapsedSummary != null || !effectiveCommand)
          ? Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.textSecondary),
            )
          : null,
    );
  }
}

class _ConversationEmptyState extends StatelessWidget {
  const _ConversationEmptyState({
    this.workingDirectory = '',
    this.onChooseDirectory,
  });

  final String workingDirectory;
  final VoidCallback? onChooseDirectory;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final projectLabel = workingDirectory.trim().isEmpty
        ? null
        : _projectName(workingDirectory);
    final headingStyle = TextStyle(
      color: theme.textPrimary,
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.6,
      height: 1.2,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome_mosaic_outlined,
          size: 40,
          color: theme.textPrimary.withValues(alpha: 0.78),
        ),
        const SizedBox(height: ThemeTokens.space6),
        Text.rich(
          key: const ValueKey('home-hero-heading'),
          TextSpan(
            text: projectLabel == null
                ? 'What should we build?'
                : 'What should we build in ',
            children: [
              if (projectLabel != null)
                if (onChooseDirectory == null)
                  TextSpan(text: '$projectLabel?')
                else
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: CodexTooltip(
                      message: 'Select project directory',
                      child: TextButton(
                        key: const ValueKey('home-project-selector'),
                        onPressed: onChooseDirectory,
                        style:
                            TextButton.styleFrom(
                              foregroundColor: theme.textPrimary,
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  OfficialCodexTheme.buttonRadius,
                                ),
                              ),
                            ).copyWith(
                              splashFactory: NoSplash.splashFactory,
                              side: WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.focused)
                                    ? BorderSide(
                                        color: theme.focusRing,
                                        width: 1.5,
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                        child: Text(
                          '$projectLabel?',
                          // The enclosing WidgetSpan scales this label.
                          textScaler: TextScaler.noScaling,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: headingStyle.copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor: theme.textMuted,
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
          style: headingStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StarterSuggestionRow extends StatelessWidget {
  const _StarterSuggestionRow({required this.onSelectSuggestion});

  final ValueChanged<String> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    const suggestions = [
      (
        icon: Icons.account_tree_outlined,
        label: 'Explore codebase architecture',
        prompt: 'Explore this repository and summarize its architecture and key modules.',
      ),
      (
        icon: Icons.difference_outlined,
        label: 'Review local git changes',
        prompt: 'Review uncommitted git changes and highlight any potential regressions.',
      ),
      (
        icon: Icons.bug_report_outlined,
        label: 'Run tests & fix failures',
        prompt: 'Run the test suite and diagnose any failing or flaky checks.',
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final item in suggestions)
          CodexButton(
            variant: CodexButtonVariant.secondary,
            size: CodexButtonSize.sm,
            onPressed: () => onSelectSuggestion(item.prompt),
            icon: Icon(item.icon, size: 14, color: theme.textMuted),
            label: item.label,
          ),
      ],
    );
  }
}

class _ThreadEmptyState extends StatelessWidget {
  const _ThreadEmptyState({required this.thread});

  final ThreadSummary thread;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ThemeTokens.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_mosaic_outlined,
              size: 38,
              color: theme.textPrimary.withValues(alpha: 0.78),
            ),
            const SizedBox(height: 12),
            Text(
              'Let’s build ${_projectName(thread.cwd)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationLoadingState extends StatelessWidget {
  const _ConversationLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: OfficialCodexTheme.maxContentWidth,
        ),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(ThemeTokens.space6),
          itemCount: 4,
          itemBuilder: (context, index) => Align(
            alignment: index.isEven
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: index.isEven ? 420 : 260,
              height: index.isEven ? 54 : 42,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: ThemeTokens.of(context).surfaceRaised,
                borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationErrorState extends StatelessWidget {
  const _ConversationErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(ThemeTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: palette.danger,
                size: 28,
              ),
              const SizedBox(height: ThemeTokens.space3),
              Text(
                'Conversation unavailable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: ThemeTokens.space2),
              SelectableText(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: ThemeTokens.space4),
              CodexButton(
                variant: CodexButtonVariant.secondary,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: 'Try again',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutionSettingsButton extends StatefulWidget {
  const _ExecutionSettingsButton({
    required this.controller,
    this.iconOnly = false,
    this.useSandboxMenu = false,
  });

  final ExecutionSettingsController controller;
  final bool iconOnly;
  final bool useSandboxMenu;

  @override
  State<_ExecutionSettingsButton> createState() =>
      _ExecutionSettingsButtonState();
}

class _ExecutionSettingsButtonState extends State<_ExecutionSettingsButton> {
  final _menu = CodexPopoverController();

  @override
  void didUpdateWidget(covariant _ExecutionSettingsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.useSandboxMenu && !widget.useSandboxMenu) ||
        oldWidget.controller != widget.controller) {
      _menu.hide();
    }
  }

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  void _showAdvancedSettings() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => _ExecutionSettingsDialog(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final palette = ThemeTokens.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final sandbox = controller.sandbox;
        final fullAccess = sandbox == SandboxModeOverride.dangerFullAccess;
        final label = _sandboxLabel(sandbox);
        final color = fullAccess ? palette.warning : palette.textSecondary;
        final onPressed = controller.loading
            ? null
            : widget.useSandboxMenu
            ? _menu.toggle
            : _showAdvancedSettings;
        final icon = controller.loading
            ? const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                fullAccess
                    ? Icons.gpp_maybe_outlined
                    : widget.iconOnly
                    ? Icons.shield_outlined
                    : Icons.tune_rounded,
                size: 15,
                color: color,
              );
        if (widget.iconOnly) {
          final button = CodexIconButton(
            key: const ValueKey('execution-settings-button'),
            tooltip: 'Execution settings: $label',
            size: 28,
            onPressed: onPressed,
            icon: icon,
          );
          if (!widget.useSandboxMenu) return button;
          return CodexPopoverAnchor(
            controller: _menu,
            width: 228,
            targetAnchor: Alignment.topRight,
            followerAnchor: Alignment.bottomRight,
            offset: const Offset(0, -6),
            popoverBuilder: (menuContext, close) =>
                CodexMenu<({SandboxModeOverride? mode, bool advanced})>(
                  header: Text(
                    'Sandbox',
                    style: Theme.of(menuContext).textTheme.labelMedium,
                  ),
                  selectedValue: (mode: sandbox, advanced: false),
                  items: [
                    for (final mode in [null, ...SandboxModeOverride.values])
                      CodexMenuItem(
                        value: (mode: mode, advanced: false),
                        label: _sandboxLabel(mode),
                        icon: Icon(
                          mode == SandboxModeOverride.dangerFullAccess
                              ? Icons.gpp_maybe_outlined
                              : Icons.shield_outlined,
                          color: mode == SandboxModeOverride.dangerFullAccess
                              ? palette.warning
                              : null,
                        ),
                      ),
                    CodexMenuItem(
                      value: (mode: null, advanced: true),
                      label: 'Advanced settings…',
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                  onSelected: (option) {
                    close();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || controller != widget.controller) return;
                      if (option.advanced) {
                        _showAdvancedSettings();
                      } else if (option.mode != sandbox) {
                        unawaited(
                          _applySandboxOverride(
                            this.context,
                            controller,
                            option.mode,
                          ),
                        );
                      }
                    });
                  },
                ),
            child: button,
          );
        }
        return CodexButton(
          key: const ValueKey('execution-settings-button'),
          variant: CodexButtonVariant.ghost,
          size: CodexButtonSize.sm,
          onPressed: onPressed,
          icon: icon,
          tooltip: 'Execution settings: $label',
          label: switch (sandbox) {
            null => 'Defaults',
            SandboxModeOverride.workspaceWrite => 'Workspace',
            _ => label,
          },
        );
      },
    );
  }

  String _sandboxLabel(SandboxModeOverride? sandbox) => switch (sandbox) {
    null => 'Codex default',
    SandboxModeOverride.readOnly => 'Read only',
    SandboxModeOverride.workspaceWrite => 'Workspace write',
    SandboxModeOverride.dangerFullAccess => 'Full access',
  };
}

class _ComposerModelSummaryButton extends StatelessWidget {
  const _ComposerModelSummaryButton({
    required this.controller,
    this.maxLabelWidth = 190,
    this.iconOnly = false,
  });

  final ExecutionSettingsController controller;
  final double maxLabelWidth;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final model = controller.effectiveModel;
        final String summary;
        if (model == null) {
          summary = controller.loading ? 'Loading models…' : 'Codex default';
        } else {
          final rawEffort =
              controller.selectedReasoningEffort ??
              model.defaultReasoningEffort;
          final effortLabel = _formatEffortLabel(rawEffort);
          summary = effortLabel == null
              ? model.displayName
              : '${model.displayName} · $effortLabel';
        }
        void showSettings() {
          unawaited(
            showDialog<void>(
              context: context,
              builder: (_) => _ExecutionSettingsDialog(controller: controller),
            ),
          );
        }

        final tooltip = 'Model and reasoning ($summary)';
        if (iconOnly) {
          return CodexIconButton(
            key: const ValueKey('composer-model-pill'),
            tooltip: tooltip,
            size: 28,
            onPressed: controller.loading ? null : showSettings,
            icon: const Icon(Icons.tune_rounded, size: 16),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: CodexButton(
            key: const ValueKey('composer-model-pill'),
            variant: CodexButtonVariant.ghost,
            size: CodexButtonSize.sm,
            onPressed: controller.loading ? null : showSettings,
            tooltip: tooltip,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxLabelWidth),
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: palette.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String? _formatEffortLabel(String? effort) {
    if (effort == null || effort.trim().isEmpty) {
      return null;
    }
    return switch (effort.trim().toLowerCase()) {
      'low' => 'Low',
      'medium' => 'Medium',
      'high' => 'High',
      'xhigh' => 'Extra high',
      'minimal' => 'Minimal',
      final other => '${other[0].toUpperCase()}${other.substring(1)}',
    };
  }
}

class _ExecutionDropdownItem {
  const _ExecutionDropdownItem({required this.value, required this.label});
  final String value;
  final String label;
}

class _ExecutionDropdown extends StatefulWidget {
  const _ExecutionDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<_ExecutionDropdownItem> items;
  final ValueChanged<String> onChanged;

  @override
  State<_ExecutionDropdown> createState() => _ExecutionDropdownState();
}

class _ExecutionDropdownState extends State<_ExecutionDropdown> {
  final _popoverController = CodexPopoverController();
  final _triggerKey = GlobalKey();
  var _opensAbove = false;
  var _menuMaxHeight = 240.0;

  @override
  void dispose() {
    _popoverController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_popoverController.isOpen) {
      _popoverController.hide();
      return;
    }
    final trigger = _triggerKey.currentContext?.findRenderObject();
    if (trigger is! RenderBox || !trigger.hasSize) return;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final top = trigger.localToGlobal(Offset.zero).dy;
    final above = math.max(0.0, top - 12);
    final below = math.max(
      0.0,
      viewportHeight - top - trigger.size.height - 12,
    );
    final desired = math.min(240.0, widget.items.length * 32.0 + 12);
    setState(() {
      _opensAbove = below < desired && above > below;
      _menuMaxHeight = math.min(desired, _opensAbove ? above : below);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _menuMaxHeight > 0) {
        _popoverController.show();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final currentItem = widget.items.firstWhere(
      (item) => item.value == widget.value,
      orElse: () => widget.items.isNotEmpty
          ? widget.items.first
          : _ExecutionDropdownItem(value: widget.value, label: widget.value),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            color: theme.textSecondary,
          ),
        ),
        const SizedBox(height: 6.0),
        LayoutBuilder(
          builder: (context, constraints) => CodexPopoverAnchor(
            controller: _popoverController,
            width: constraints.maxWidth,
            targetAnchor: _opensAbove
                ? Alignment.topLeft
                : Alignment.bottomLeft,
            followerAnchor: _opensAbove
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            offset: Offset(0, _opensAbove ? -6 : 6),
            popoverBuilder: (context, close) => ConstrainedBox(
              constraints: BoxConstraints(maxHeight: _menuMaxHeight),
              child: SingleChildScrollView(
                child: CodexMenu<String>(
                  items: [
                    for (final item in widget.items)
                      CodexMenuItem<String>(
                        value: item.value,
                        label: item.label,
                      ),
                  ],
                  selectedValue: widget.value,
                  onSelected: (val) {
                    widget.onChanged(val);
                    close();
                  },
                ),
              ),
            ),
            child: KeyedSubtree(
              key: _triggerKey,
              child: GestureDetector(
                key: ValueKey('execution-${widget.label}'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggleMenu,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    height: 38.0,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: theme.elevatedSurface,
                      borderRadius: BorderRadius.circular(
                        OfficialCodexTheme.buttonRadius,
                      ),
                      border: Border.all(
                        color: theme.hairlineBorder,
                        width: OfficialCodexTheme.hairlineBorderWidth,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            currentItem.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.0,
                              color: theme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 16.0,
                          color: theme.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExecutionSettingsDialog extends StatelessWidget {
  const _ExecutionSettingsDialog({required this.controller});

  static const _inherit = '';

  final ExecutionSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = OfficialCodexTheme.of(context);
        return Dialog(
          backgroundColor: theme.modalSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              OfficialCodexTheme.popoverRadius,
            ),
            side: BorderSide(
              color: theme.hairlineBorder,
              width: OfficialCodexTheme.hairlineBorderWidth,
            ),
          ),
          child: SizedBox(
            width: 480,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Execution settings',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'Overrides apply only when explicitly selected. Defaults '
                            'continue to come from Codex configuration.',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: theme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: ThemeTokens.space4),
                          _ExecutionDropdown(
                            label: 'Model',
                            value: controller.selectedModelId ?? _inherit,
                            items: [
                              const _ExecutionDropdownItem(
                                value: _inherit,
                                label: 'Codex default',
                              ),
                              for (final model in controller.models)
                                _ExecutionDropdownItem(
                                  value: model.id,
                                  label: model.displayName,
                                ),
                            ],
                            onChanged: (value) => controller.selectModel(
                              value == _inherit ? null : value,
                            ),
                          ),
                          const SizedBox(height: ThemeTokens.space3),
                          _ExecutionDropdown(
                            label: 'Reasoning effort',
                            value:
                                controller.selectedReasoningEffort ?? _inherit,
                            items: [
                              const _ExecutionDropdownItem(
                                value: _inherit,
                                label: 'Model default',
                              ),
                              for (final effort
                                  in controller.availableReasoningEfforts)
                                _ExecutionDropdownItem(
                                  value: effort.value,
                                  label: effort.value,
                                ),
                            ],
                            onChanged: (value) =>
                                controller.selectReasoningEffort(
                                  value == _inherit ? null : value,
                                ),
                          ),
                          const SizedBox(height: ThemeTokens.space3),
                          _ExecutionDropdown(
                            label: 'Approval mode',
                            value: _approvalValue(controller.approvalPolicy),
                            items: const [
                              _ExecutionDropdownItem(
                                value: _inherit,
                                label: 'Codex default',
                              ),
                              _ExecutionDropdownItem(
                                value: 'untrusted',
                                label: 'Ask for untrusted commands',
                              ),
                              _ExecutionDropdownItem(
                                value: 'on-request',
                                label: 'Ask when Codex requests',
                              ),
                              _ExecutionDropdownItem(
                                value: 'never',
                                label: 'Never ask',
                              ),
                            ],
                            onChanged: (value) => _setApproval(context, value),
                          ),
                          const SizedBox(height: ThemeTokens.space3),
                          _ExecutionDropdown(
                            label: 'Sandbox',
                            value: _sandboxValue(controller.sandbox),
                            items: const [
                              _ExecutionDropdownItem(
                                value: _inherit,
                                label: 'Codex default',
                              ),
                              _ExecutionDropdownItem(
                                value: 'read-only',
                                label: 'Read only',
                              ),
                              _ExecutionDropdownItem(
                                value: 'workspace-write',
                                label: 'Workspace write',
                              ),
                              _ExecutionDropdownItem(
                                value: 'danger-full-access',
                                label: 'Danger: full access',
                              ),
                            ],
                            onChanged: (value) => _setSandbox(context, value),
                          ),
                          if (controller.errorMessage case final error?) ...[
                            const SizedBox(height: ThemeTokens.space3),
                            SelectableText(
                              error,
                              style: TextStyle(
                                fontSize: 12.0,
                                color: theme.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ThemeTokens.space4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CodexButton(
                        variant: CodexButtonVariant.ghost,
                        onPressed: controller.refreshModels,
                        label: 'Refresh models',
                      ),
                      const SizedBox(width: 8.0),
                      CodexButton(
                        onPressed: () => Navigator.of(context).pop(),
                        label: 'Done',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _setApproval(BuildContext context, String value) async {
    final policy = switch (value) {
      'untrusted' => ApprovalPolicyOverride.untrusted,
      'on-request' => ApprovalPolicyOverride.onRequest,
      'never' => ApprovalPolicyOverride.never,
      _ => null,
    };
    if (policy == ApprovalPolicyOverride.never &&
        !await _confirmDesktopAction(
          context,
          title: 'Disable approval prompts?',
          message:
              'Codex may execute commands without asking. The configured '
              'sandbox still applies, but this removes an important review gate.',
          confirmLabel: 'Never ask',
        )) {
      return;
    }
    controller.selectApprovalPolicy(policy);
  }

  Future<void> _setSandbox(BuildContext context, String value) async {
    final sandbox = switch (value) {
      'read-only' => SandboxModeOverride.readOnly,
      'workspace-write' => SandboxModeOverride.workspaceWrite,
      'danger-full-access' => SandboxModeOverride.dangerFullAccess,
      _ => null,
    };
    await _applySandboxOverride(context, controller, sandbox);
  }

  static String _approvalValue(ApprovalPolicyOverride? policy) =>
      switch (policy) {
        ApprovalPolicyOverride.untrusted => 'untrusted',
        ApprovalPolicyOverride.onRequest => 'on-request',
        ApprovalPolicyOverride.never => 'never',
        null => _inherit,
      };

  static String _sandboxValue(SandboxModeOverride? sandbox) =>
      switch (sandbox) {
        SandboxModeOverride.readOnly => 'read-only',
        SandboxModeOverride.workspaceWrite => 'workspace-write',
        SandboxModeOverride.dangerFullAccess => 'danger-full-access',
        null => _inherit,
      };
}

Future<void> _applySandboxOverride(
  BuildContext context,
  ExecutionSettingsController controller,
  SandboxModeOverride? sandbox,
) async {
  if (sandbox == SandboxModeOverride.dangerFullAccess &&
      !await _confirmDesktopAction(
        context,
        title: 'Allow full filesystem access?',
        message:
            'Commands will not be restricted by the Codex sandbox. Use this '
            'only for a workspace you trust.',
        confirmLabel: 'Allow full access',
      )) {
    return;
  }
  if (context.mounted) {
    controller.selectSandbox(sandbox);
  }
}

Future<bool> _confirmDesktopAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  CodexButtonVariant confirmVariant = CodexButtonVariant.danger,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = OfficialCodexTheme.of(context);
        return AlertDialog(
          backgroundColor: theme.modalSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.hairlineBorder,
              width: OfficialCodexTheme.hairlineBorderWidth,
            ),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            CodexButton(
              variant: CodexButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false),
              label: 'Cancel',
            ),
            CodexButton(
              variant: confirmVariant,
              onPressed: () => Navigator.of(context).pop(true),
              label: confirmLabel,
            ),
          ],
        );
      },
    ) ??
    false;

enum _ReviewTargetKind { uncommitted, baseBranch, commit, custom }

class _StartReviewDialog extends StatefulWidget {
  const _StartReviewDialog({required this.thread});

  final ThreadSummary thread;

  @override
  State<_StartReviewDialog> createState() => _StartReviewDialogState();
}

class _StartReviewDialogState extends State<_StartReviewDialog> {
  static const _maxBranchChars = 240;
  static const _maxCommitShaChars = 120;
  static const _maxCommitTitleChars = 240;
  static const _maxCustomInstructionsChars = 2000;

  _ReviewTargetKind _kind = _ReviewTargetKind.uncommitted;
  late final TextEditingController _baseBranchController;
  late final TextEditingController _commitShaController;
  late final TextEditingController _commitTitleController;
  late final TextEditingController _customInstructionsController;

  @override
  void initState() {
    super.initState();
    _baseBranchController = TextEditingController()..addListener(_onChanged);
    _commitShaController = TextEditingController()..addListener(_onChanged);
    _commitTitleController = TextEditingController()..addListener(_onChanged);
    _customInstructionsController = TextEditingController()
      ..addListener(_onChanged);
  }

  @override
  void dispose() {
    _baseBranchController.dispose();
    _commitShaController.dispose();
    _commitTitleController.dispose();
    _customInstructionsController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  static bool _isValidGitRef(String raw, int maxChars) {
    final trimmed = raw.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= maxChars &&
        !trimmed.startsWith('-') &&
        !RegExp(r'\s').hasMatch(trimmed);
  }

  ReviewTarget? _resolveTarget() {
    switch (_kind) {
      case _ReviewTargetKind.uncommitted:
        return const UncommittedChangesReviewTarget();
      case _ReviewTargetKind.baseBranch:
        final branch = _baseBranchController.text.trim();
        if (!_isValidGitRef(branch, _maxBranchChars)) {
          return null;
        }
        return BaseBranchReviewTarget(branch);
      case _ReviewTargetKind.commit:
        final sha = _commitShaController.text.trim();
        if (!_isValidGitRef(sha, _maxCommitShaChars)) {
          return null;
        }
        final title = _commitTitleController.text.trim();
        if (title.length > _maxCommitTitleChars) {
          return null;
        }
        return CommitReviewTarget(
          sha: sha,
          title: title.isEmpty ? null : title,
        );
      case _ReviewTargetKind.custom:
        final instructions = _customInstructionsController.text.trim();
        if (instructions.isEmpty ||
            instructions.length > _maxCustomInstructionsChars) {
          return null;
        }
        return CustomReviewTarget(instructions);
    }
  }

  void _submitIfValid() {
    final target = _resolveTarget();
    if (target != null) {
      Navigator.of(context).pop(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final currentBranch = widget.thread.gitInfo?.branch?.trim();
    final resolvedTarget = _resolveTarget();

    return AlertDialog(
      backgroundColor: theme.modalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OfficialCodexTheme.popoverRadius),
        side: BorderSide(
          color: theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      title: const Text('Code review'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                currentBranch != null && currentBranch.isNotEmpty
                    ? 'Select a review target for branch $currentBranch.'
                    : 'Select a review target for this workspace.',
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: ThemeTokens.space3),
              Wrap(
                spacing: ThemeTokens.space2,
                runSpacing: ThemeTokens.space2,
                children: [
                  _ReviewTargetOptionChip(
                    chipKey: const ValueKey('review-target-uncommitted'),
                    label: 'Uncommitted changes',
                    selected: _kind == _ReviewTargetKind.uncommitted,
                    onTap: () =>
                        setState(() => _kind = _ReviewTargetKind.uncommitted),
                  ),
                  _ReviewTargetOptionChip(
                    chipKey: const ValueKey('review-target-baseBranch'),
                    label: 'Base branch',
                    selected: _kind == _ReviewTargetKind.baseBranch,
                    onTap: () =>
                        setState(() => _kind = _ReviewTargetKind.baseBranch),
                  ),
                  _ReviewTargetOptionChip(
                    chipKey: const ValueKey('review-target-commit'),
                    label: 'Commit',
                    selected: _kind == _ReviewTargetKind.commit,
                    onTap: () =>
                        setState(() => _kind = _ReviewTargetKind.commit),
                  ),
                  _ReviewTargetOptionChip(
                    chipKey: const ValueKey('review-target-custom'),
                    label: 'Custom instructions',
                    selected: _kind == _ReviewTargetKind.custom,
                    onTap: () =>
                        setState(() => _kind = _ReviewTargetKind.custom),
                  ),
                ],
              ),
              const SizedBox(height: ThemeTokens.space3),
              switch (_kind) {
                _ReviewTargetKind.uncommitted => Text(
                  'Review staged, unstaged, and untracked changes in the '
                  'current working tree.',
                  style: TextStyle(color: theme.textSecondary, fontSize: 13),
                ),
                _ReviewTargetKind.baseBranch => TextField(
                  key: const ValueKey('review-base-branch-field'),
                  controller: _baseBranchController,
                  autofocus: true,
                  maxLength: _maxBranchChars,
                  decoration: const InputDecoration(
                    labelText: 'Base branch or ref',
                    hintText: 'main or origin/main',
                  ),
                  onSubmitted: (_) => _submitIfValid(),
                ),
                _ReviewTargetKind.commit => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const ValueKey('review-commit-sha-field'),
                      controller: _commitShaController,
                      autofocus: true,
                      maxLength: _maxCommitShaChars,
                      decoration: const InputDecoration(
                        labelText: 'Commit SHA or ref',
                        hintText: 'HEAD~1 or commit SHA',
                      ),
                      onSubmitted: (_) => _submitIfValid(),
                    ),
                    const SizedBox(height: ThemeTokens.space2),
                    TextField(
                      key: const ValueKey('review-commit-title-field'),
                      controller: _commitTitleController,
                      maxLength: _maxCommitTitleChars,
                      decoration: const InputDecoration(
                        labelText: 'Commit title (optional)',
                        hintText: 'Optional label for timeline display',
                      ),
                      onSubmitted: (_) => _submitIfValid(),
                    ),
                  ],
                ),
                _ReviewTargetKind.custom => TextField(
                  key: const ValueKey('review-custom-instructions-field'),
                  controller: _customInstructionsController,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: _maxCustomInstructionsChars,
                  decoration: const InputDecoration(
                    labelText: 'Review instructions',
                    hintText:
                        'Focus on concurrency, rollback bounds, or edge cases…',
                  ),
                ),
              },
            ],
          ),
        ),
      ),
      actions: [
        CodexButton(
          key: const ValueKey('start-review-cancel-button'),
          variant: CodexButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
          label: 'Cancel',
        ),
        CodexButton(
          key: const ValueKey('start-review-submit-button'),
          variant: CodexButtonVariant.primary,
          onPressed: resolvedTarget == null ? null : _submitIfValid,
          label: 'Start review',
        ),
      ],
    );
  }
}

class _ReviewTargetOptionChip extends StatelessWidget {
  const _ReviewTargetOptionChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CodexButton(
      key: chipKey,
      size: CodexButtonSize.sm,
      variant: selected
          ? CodexButtonVariant.primary
          : CodexButtonVariant.secondary,
      selected: selected,
      onPressed: onTap,
      label: label,
    );
  }
}
