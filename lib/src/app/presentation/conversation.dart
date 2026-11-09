part of '../codex_native_app.dart';

enum PresentationDetailMode { prose, commands, execution }

class _ConversationPanel extends StatefulWidget {
  const _ConversationPanel({
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
    this.sidebarCollapsed = false,
    this.onToggleSidebar,
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
  final bool sidebarCollapsed;
  final VoidCallback? onToggleSidebar;

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
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
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
  var _searchOpen = false;
  var _activeSearchMatchIndex = 0;
  var _branchSequence = 1;
  var _detailMode = PresentationDetailMode.commands;
  String? _customProjectDirectory;
  final _threadActionsPopoverController = CodexPopoverController();
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
    final field = TextEditingController(text: _activeProjectDirectory);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select project directory'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: field,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Working directory',
              hintText: '/path/to/repository',
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
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
            onPressed: () => Navigator.of(context).pop(field.text.trim()),
            label: 'Use directory',
          ),
        ],
      ),
    );
    field.dispose();
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
    }
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
      _bindAttachmentEvents();
      if (_activeThreadId case final activeId?) {
        _requestActiveThreadLinkedPrs(activeId);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_attachmentEventSubscription?.cancel());
    widget.threadController?.removeListener(_handleThreadListChanged);
    widget.controller.removeListener(_handleConversationChanged);
    widget.historyController.removeListener(_handleHistoryChanged);
    _scrollController
      ..removeListener(_handleScrollPositionChanged)
      ..dispose();
    _threadActionsPopoverController.dispose();
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
          }
        },
      },
      child: ColoredBox(
        color: theme.workspaceBackground,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.controller,
            if (widget.threadController != null) widget.threadController!,
            widget.diffController,
            widget.historyController,
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
            final timelineChild =
                _showChanges && widget.diffController.snapshot != null
                ? _DiffView(controller: widget.diffController)
                : _timeline(controller);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _conversationHeader(controller),
                if (_searchOpen && controller.thread != null)
                  _conversationSearchBar(),
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
                Expanded(child: timelineChild),
                _ApprovalBanner(controller: widget.approvalController),
                _UserInputBanner(controller: widget.userInputController),
                _composer(controller),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _conversationSearchBar() {
    final palette = ThemeTokens.of(context);
    final query = _searchController.text.trim();
    final matchCount = _searchMatchItemKeys.length;
    final statusLabel = query.isEmpty
        ? 'Type to search'
        : matchCount == 0
        ? '0 matches'
        : '${(_activeSearchMatchIndex + 1).clamp(1, matchCount)} of $matchCount';
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
                  decoration: const InputDecoration(
                    hintText: 'Find in conversation…',
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
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

  Widget _conversationHeader(ConversationController controller) {
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
    final thread = controller.thread;
    final threadController = widget.threadController;
    final projectCwd = thread?.cwd ?? _activeProjectDirectory;
    final isHomeEmpty = thread == null;
    return Container(
      key: const ValueKey('thread_header_bar'),
      height: OfficialCodexTheme.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.space4),
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
              thread != null &&
              _activeCapabilities.supportsInConversationSearch &&
              constraints.maxWidth >= 520;
          return Row(
            children: [
              if (widget.sidebarCollapsed &&
                  widget.onToggleSidebar != null) ...[
                CodexIconButton(
                  key: const ValueKey('sidebar-expand-button'),
                  tooltip: 'Show sidebar (Ctrl+B)',
                  onPressed: widget.onToggleSidebar,
                  icon: const Icon(Icons.view_sidebar_outlined, size: 17),
                ),
                const SizedBox(width: ThemeTokens.space2),
              ],
              Expanded(
                child: thread == null
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          Flexible(
                            child: Text(
                              thread.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    letterSpacing: -0.1,
                                  ),
                            ),
                          ),
                          if (_attachmentGateway?.supportsThreadAttachments ??
                              false) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: _buildLinkedPrHeaderPill(
                                context,
                                thread.id,
                                _activeThreadLinkedPrs?.threadId == thread.id
                                    ? _activeThreadLinkedPrs
                                    : null,
                              ),
                            ),
                          ],
                          if (projectCwd.isNotEmpty &&
                              _activeCapabilities
                                  .supportsWorkingDirectorySelection &&
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
                              when constraints.maxWidth >= 680) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: CodexTooltip(
                                message:
                                    'Thread total: ${usage.total.totalTokens} tokens '
                                    '(in ${usage.total.inputTokens}, cached ${usage.total.cachedInputTokens}, '
                                    'out ${usage.total.outputTokens}, reasoning ${usage.total.reasoningOutputTokens})\n'
                                    'Last turn: ${usage.last.totalTokens} tokens',
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
              if (widget.diffController.snapshot?.files.isNotEmpty ??
                  false) ...[
                CodexButton(
                  key: const ValueKey('changes-view-button'),
                  size: CodexButtonSize.sm,
                  variant: CodexButtonVariant.ghost,
                  onPressed: () => setState(() => _showChanges = !_showChanges),
                  icon: Icon(
                    _showChanges
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.difference_outlined,
                    size: 15,
                  ),
                  label: _showChanges
                      ? 'Conversation'
                      : 'Changes ${widget.diffController.snapshot!.files.length}',
                ),
                const SizedBox(width: ThemeTokens.space2),
              ],
              if (showSegment)
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
                  onSelected: (mode) {
                    setState(() {
                      _detailMode = mode;
                    });
                  },
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
                            if (_canStartThreadReview(thread.id)) {
                              unawaited(
                                controller.startReview(
                                  const UncommittedChangesReviewTarget(),
                                ),
                              );
                            }
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
              if (controller.canInterrupt) ...[
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

  Widget _buildLinkedPrHeaderPill(
    BuildContext context,
    String threadId,
    ThreadLinkedPullRequestsSnapshot? linkedPrs,
  ) {
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
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
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
        variant: CodexButtonVariant.secondary,
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
          color: _linkedPrLoadError != null ? palette.danger : palette.accent,
        ),
        child: Row(
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
      widget.controller.canStartReview &&
      _activeCapabilities.supportsGitDiff;

  Future<void> _startThreadReviewDialog(ThreadSummary thread) async {
    if (!_canStartThreadReview(thread.id)) {
      return;
    }
    final target = await showDialog<ReviewTarget>(
      context: context,
      builder: (context) => _StartReviewDialog(thread: thread),
    );
    if (target == null || !_canStartThreadReview(thread.id)) {
      return;
    }
    await widget.controller.startReview(target);
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
                  e ==
                      rawLiveEntries.lastWhere(
                        (item) => item.kind == ConversationEntryKind.activity,
                        orElse: () => e,
                      ),
            )
            .toList(growable: false),
      PresentationDetailMode.execution => rawLiveEntries,
    };
    final liveIds = liveEntries.map((entry) => entry.id).toSet();
    final rawHistoryItems = widget.historyController.timelineItems
        .where((item) => !liveIds.contains(item.id))
        .toList(growable: false);
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
                  widget.historyController.isFirstNonUserItemInTurn(item);
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
                        outputGateway: widget.outputGateway,
                        detailMode: _detailMode,
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
                  return _MeasuredTimelineItem(
                    key: ValueKey('measured-$itemKey'),
                    itemKey: itemKey,
                    turnId: liveTurnId,
                    onMeasured: _recordItemMeasurement,
                    onUnmount: _unregisterItemBox,
                    child: _ConversationEntryView(
                      key: ValueKey(entry.id),
                      entry: effectiveEntry,
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
              CallbackShortcuts(
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
              ),
              LayoutBuilder(
                builder: (context, rowConstraints) {
                  final compactComposer = rowConstraints.maxWidth < 560;
                  final showModelPill = rowConstraints.maxWidth >= 320;
                  final busyReserve = controller.busy ? 76.0 : 0.0;
                  final maxModelLabelWidth =
                      (rowConstraints.maxWidth -
                              (compactComposer ? 260 : 455) -
                              busyReserve)
                          .clamp(52.0, 148.0);
                  return Row(
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
                      if (showModelPill)
                        _ComposerModelSummaryButton(
                          controller: widget.settingsController,
                          maxLabelWidth: maxModelLabelWidth,
                        ),
                      if (capabilities.supportsSandboxConfiguration)
                        _ExecutionSettingsButton(
                          controller: widget.settingsController,
                        ),
                      if (projectCwd.isNotEmpty &&
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
                      const Spacer(),
                      if (controller.busy)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Working…',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
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
                    ],
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
    final text = _composerController.text;
    final attachments = List<UserAttachment>.of(_composerAttachments);
    if (text.trim().isEmpty && attachments.isEmpty) {
      return;
    }
    var targetThreadId = widget.controller.thread?.id;
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
        final ready = await threadController.ensureSelectedThreadLoaded();
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
    _threadScrollBookmarks.remove(targetThreadId);
    if (widget.historyController.canReturnToNewest) {
      unawaited(widget.historyController.refresh());
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
    final pendingBranch = _pendingBranchEdit;
    final submitted = await widget.controller.submit(
      text,
      attachments: attachments,
    );
    if (submitted &&
        mounted &&
        widget.controller.thread?.id == targetThreadId) {
      _pendingBranchEdit = null;
      _composerController.clear();
      setState(() {
        _composerAttachments.clear();
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
    if (!_scrollController.hasClients) {
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
    if (!_scrollController.hasClients) {
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
    if (!_scrollController.hasClients ||
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
    if (!_scrollController.hasClients) {
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

  void _syncActiveThreadSelection() {
    final nextThreadId = widget.controller.thread?.id;
    if (nextThreadId == _activeThreadId) {
      return;
    }
    if (!_pendingThreadRestore && _activeThreadId != null) {
      _captureThreadScrollBookmark(_activeThreadId!);
    }
    _activeThreadId = nextThreadId;
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
    _pendingThreadRestore = nextThreadId != null;
    _restorePagesLoaded = 0;
    _restoreAlignmentPasses = 0;
    _preLoadOlderAnchor = null;
    _pendingStreamAnchor = null;
    _pendingBranchEdit = null;
    _wasLoadingOlderTurns = widget.historyController.loadingOlderTurns;
    _wasWindowShifted = widget.historyController.canReturnToNewest;
    _lastHandledLoadOlderVersion = widget.historyController.loadOlderVersion;
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
        if (!mounted || !_scrollController.hasClients) {
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
      if (!_scrollController.hasClients || _pendingThreadRestore) {
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
    if (previousThreadId != _activeThreadId) {
      final thread = widget.controller.thread;
      if (thread != null &&
          widget.controller.entries.isEmpty &&
          widget.historyController.timelineItems.isEmpty &&
          !widget.historyController.loadingTurns) {
        _threadScrollBookmarks.remove(thread.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              widget.controller.thread?.id == thread.id &&
              !widget.controller.busy) {
            _composerFocusNode.requestFocus();
          }
        });
      }
      return;
    }
    if (!_scrollController.hasClients ||
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
      if (!mounted || !_scrollController.hasClients) {
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
      if (!_scrollController.hasClients) {
        if (widget.historyController.timelineItems.isEmpty &&
            widget.controller.entries.isEmpty) {
          _threadScrollBookmarks.remove(threadId);
          _pendingThreadRestore = false;
          if (!widget.controller.busy) {
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
    if (!_scrollController.hasClients) {
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
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: _UserMessageEntryView(
            entry: entry,
            turnId: turnId,
            attachments: attachments,
            onForkFromTurn: onForkFromTurn,
            onRevertFromTurn: onRevertFromTurn,
            onEditFromTurn: onEditFromTurn,
            onRegenerateFromTurn: onRegenerateFromTurn,
            siblingBranchInfo: siblingBranchInfo,
            onSelectSiblingBranch: onSelectSiblingBranch,
            isSearchMatch: isSearchMatch,
            isActiveSearchMatch: isActiveSearchMatch,
          ),
        ),
      );
    }

    if (isReasoning ||
        (entry.kind == ConversationEntryKind.activity &&
            entry.text == 'Reasoning')) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?leadingHeader,
              _ReasoningEntryView(entry: entry),
            ],
          ),
        ),
      );
    }

    final isReview = entry.kind == ConversationEntryKind.review;
    final isActivity = entry.kind == ConversationEntryKind.activity || isReview;
    final isError = entry.kind == ConversationEntryKind.error;
    final showAssistantCopy =
        entry.kind == ConversationEntryKind.assistant &&
        entry.completed &&
        entry.text.trim().isNotEmpty;
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
                padding: isActivity || isError
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: isError
                      ? palette.danger.withValues(alpha: 0.08)
                      : isActivity
                      ? isReview
                            ? palette.accent.withValues(alpha: 0.06)
                            : palette.surfaceRaised
                      : isActiveSearchMatch
                      ? palette.accent.withValues(alpha: 0.06)
                      : Colors.transparent,
                  border: isActivity || isError
                      ? Border.all(
                          color: isError
                              ? palette.danger.withValues(alpha: 0.3)
                              : palette.border,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
                ),
                child: isActivity
                    ? _ActivityContent(
                        entry: entry,
                        isCommand: isCommand,
                        trailingAction: trailingAction,
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
                            AssistantMarkdown(
                              data: entry.text,
                              completed: entry.completed,
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
                          if (showAssistantCopy ||
                              onContinueTurn != null ||
                              onRetryTurn != null) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (showAssistantCopy)
                                  _AssistantCopyButton(
                                    key: ValueKey('assistant-copy-${entry.id}'),
                                    text: entry.text,
                                  ),
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
}

class _AssistantCopyButton extends StatefulWidget {
  const _AssistantCopyButton({super.key, required this.text});

  final String text;

  @override
  State<_AssistantCopyButton> createState() => _AssistantCopyButtonState();
}

class _AssistantCopyButtonState extends State<_AssistantCopyButton> {
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
    return CodexTooltip(
      message: _copied ? 'Copied' : 'Copy response',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _copy,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.transparent,
            ),
            child: Icon(
              _copied ? Icons.check_rounded : Icons.content_copy_rounded,
              size: 14,
              color: _copied ? palette.success : palette.textMuted,
            ),
          ),
        ),
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
    final hasBranches =
        siblingBranchInfo != null && siblingBranchInfo!.hasMultipleBranches;
    final hasTurnActions =
        fullText.isNotEmpty ||
        hasBranches ||
        onEditFromTurn != null ||
        onRegenerateFromTurn != null ||
        onForkFromTurn != null ||
        onRevertFromTurn != null;

    return Padding(
      key: isActiveSearchMatch
          ? ValueKey('active-search-match-${entry.id}')
          : null,
      padding: const EdgeInsets.only(bottom: ThemeTokens.space4),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          if (hasTurnActions)
            Positioned(
              left: 0,
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasBranches) ...[
                    GestureDetector(
                      key: ValueKey('branch-prev-$keySuffix'),
                      behavior: HitTestBehavior.opaque,
                      onTap:
                          siblingBranchInfo!.canSelectPrevious &&
                              onSelectSiblingBranch != null
                          ? () => onSelectSiblingBranch!(-1)
                          : null,
                      child: MouseRegion(
                        cursor: siblingBranchInfo!.canSelectPrevious
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 14,
                            color: siblingBranchInfo!.canSelectPrevious
                                ? palette.textSecondary
                                : palette.textMuted.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      siblingBranchInfo!.displayLabel,
                      key: ValueKey('branch-label-$keySuffix'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      key: ValueKey('branch-next-$keySuffix'),
                      behavior: HitTestBehavior.opaque,
                      onTap:
                          siblingBranchInfo!.canSelectNext &&
                              onSelectSiblingBranch != null
                          ? () => onSelectSiblingBranch!(1)
                          : null,
                      child: MouseRegion(
                        cursor: siblingBranchInfo!.canSelectNext
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: siblingBranchInfo!.canSelectNext
                                ? palette.textSecondary
                                : palette.textMuted.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                  if (fullText.isNotEmpty)
                    _AssistantCopyButton(
                      key: ValueKey('user-copy-${entry.id}'),
                      text: fullText,
                    ),
                  if (onEditFromTurn != null)
                    CodexTooltip(
                      message: 'Edit message and resubmit',
                      child: GestureDetector(
                        key: ValueKey('turn-edit-$keySuffix'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onEditFromTurn,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: palette.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onRegenerateFromTurn != null)
                    CodexTooltip(
                      message: 'Regenerate response from this turn',
                      child: GestureDetector(
                        key: ValueKey('turn-regenerate-$keySuffix'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onRegenerateFromTurn,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: palette.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onForkFromTurn != null)
                    CodexTooltip(
                      message: 'Fork thread before this turn',
                      child: GestureDetector(
                        key: ValueKey('turn-fork-$keySuffix'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onForkFromTurn,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.call_split_rounded,
                              size: 14,
                              color: palette.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onRevertFromTurn != null)
                    CodexTooltip(
                      message: 'Revert thread before this turn',
                      child: GestureDetector(
                        key: ValueKey('turn-revert-$keySuffix'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onRevertFromTurn,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.undo_rounded,
                              size: 14,
                              color: palette.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          CodexMessageBubble(
            key: ValueKey('user-message-bubble-${entry.id}'),
            text: fullText,
            attachments: attachmentWidgets,
            expandKey: ValueKey('user-expand-${entry.id}'),
          ),
        ],
      ),
    );
  }
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
  const _ReasoningEntryView({required this.entry});

  final ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final raw = entry.text.trim();
    final summary = raw.isEmpty || raw == 'Reasoning'
        ? (entry.completed ? 'Thought' : 'Thinking…')
        : raw;
    return Padding(
      padding: const EdgeInsets.only(bottom: ThemeTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.psychology_outlined,
              size: 15,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              summary,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityContent extends StatelessWidget {
  const _ActivityContent({
    required this.entry,
    this.isCommand = false,
    this.trailingAction,
  });

  final ConversationEntry entry;
  final bool isCommand;
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
    final icon = !entry.completed
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

    return CodexActivityRow(
      summary: entry.text,
      icon: Icon(icon, size: 14, color: iconColor),
      statusText: statusBadge,
      isRunning: !entry.completed,
      isError: statusBadge != null,
      trailingAction: trailingAction,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome_mosaic_outlined,
          size: 40,
          color: theme.textPrimary.withValues(alpha: 0.78),
        ),
        const SizedBox(height: 12),
        Text(
          'Let’s build',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.6,
            height: 1.2,
          ),
        ),
        if (projectLabel != null) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: onChooseDirectory,
            child: MouseRegion(
              cursor: onChooseDirectory != null
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        projectLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.4,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (onChooseDirectory != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: theme.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
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
      child: Padding(
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

class _ExecutionSettingsButton extends StatelessWidget {
  const _ExecutionSettingsButton({required this.controller});

  final ExecutionSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final fullAccess =
            controller.sandbox == SandboxModeOverride.dangerFullAccess;
        final label = fullAccess ? 'Full access' : 'Defaults';
        final color = fullAccess ? palette.warning : palette.textSecondary;
        return CodexButton(
          variant: CodexButtonVariant.ghost,
          size: CodexButtonSize.sm,
          onPressed: controller.loading
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      _ExecutionSettingsDialog(controller: controller),
                ),
          icon: controller.loading
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  fullAccess ? Icons.shield_outlined : Icons.tune_rounded,
                  size: 15,
                  color: color,
                ),
          label: label,
        );
      },
    );
  }
}

class _ComposerModelSummaryButton extends StatelessWidget {
  const _ComposerModelSummaryButton({
    required this.controller,
    this.maxLabelWidth = 190,
  });

  final ExecutionSettingsController controller;
  final double maxLabelWidth;

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
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: CodexButton(
            key: const ValueKey('composer-model-pill'),
            variant: CodexButtonVariant.ghost,
            size: CodexButtonSize.sm,
            onPressed: controller.loading
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _ExecutionSettingsDialog(controller: controller),
                  ),
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
        CodexPopoverAnchor(
          controller: _popoverController,
          popoverBuilder: (context, close) => CodexMenu<String>(
            items: [
              for (final item in widget.items)
                CodexMenuItem<String>(value: item.value, label: item.label),
            ],
            selectedValue: widget.value,
            onSelected: (val) {
              widget.onChanged(val);
              close();
            },
          ),
          child: GestureDetector(
            key: ValueKey('execution-${widget.label}'),
            behavior: HitTestBehavior.opaque,
            onTap: _popoverController.toggle,
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
                    value: controller.selectedReasoningEffort ?? _inherit,
                    items: [
                      const _ExecutionDropdownItem(
                        value: _inherit,
                        label: 'Model default',
                      ),
                      for (final effort in controller.availableReasoningEfforts)
                        _ExecutionDropdownItem(
                          value: effort.value,
                          label: effort.value,
                        ),
                    ],
                    onChanged: (value) => controller.selectReasoningEffort(
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
                      style: TextStyle(fontSize: 12.0, color: theme.danger),
                    ),
                  ],
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
    controller.selectSandbox(sandbox);
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

Future<bool> _confirmDesktopAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
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
              variant: CodexButtonVariant.danger,
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
