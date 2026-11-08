part of '../codex_native_app.dart';

enum PresentationDetailMode { prose, commands, execution }

class _ConversationPanel extends StatefulWidget {
  const _ConversationPanel({
    required this.controller,
    this.threadController,
    required this.historyController,
    required this.approvalController,
    required this.settingsController,
    required this.diffController,
    required this.outputGateway,
    this.defaultWorkingDirectory = '',
    this.sidebarCollapsed = false,
    this.onToggleSidebar,
  });

  final ConversationController controller;
  final ThreadListController? threadController;
  final HistoryController historyController;
  final ApprovalController approvalController;
  final ExecutionSettingsController settingsController;
  final DiffController diffController;
  final OutputGateway outputGateway;
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

class _ConversationPanelState extends State<_ConversationPanel> {
  static const _maxRetainedThreadScrollBookmarks = 32;
  static const _maxMeasuredItemHeights = 512;
  static const _maxRestorePages = 10;
  static const _maxRestoreAlignmentPasses = 32;
  static const _followThresholdPixels = 160.0;

  late final TextEditingController _composerController;
  late final FocusNode _composerFocusNode;
  late final ScrollController _scrollController;
  final LinkedHashMap<String, _ThreadScrollBookmark> _threadScrollBookmarks =
      LinkedHashMap();
  final LinkedHashMap<String, double> _measuredItemHeights = LinkedHashMap();
  final Map<String, RenderBox> _mountedItemBoxes = <String, RenderBox>{};
  final Map<String, String> _mountedItemTurnIds = <String, String>{};
  List<String> _currentTimelineItemKeys = const [];
  _VisibleAnchor? _preLoadOlderAnchor;
  _VisibleAnchor? _pendingStreamAnchor;
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
  var _detailMode = PresentationDetailMode.commands;
  var _productMode = ProductMode.codex;
  final _threadActionsPopoverController = CodexPopoverController();
  final _composerAttachPopoverController = CodexPopoverController();
  final List<UserAttachment> _composerAttachments = <UserAttachment>[];

  String get _activeProjectDirectory {
    final selectedCwd = widget.controller.thread?.cwd;
    if (selectedCwd != null && selectedCwd.trim().isNotEmpty) {
      return selectedCwd.trim();
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

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _composerFocusNode = FocusNode();
    _scrollController = ScrollController(keepScrollOffset: false)
      ..addListener(_handleScrollPositionChanged);
    _activeThreadId = widget.controller.thread?.id;
    _pendingThreadRestore = _activeThreadId != null;
    _wasLoadingOlderTurns = widget.historyController.loadingOlderTurns;
    _wasWindowShifted = widget.historyController.canReturnToNewest;
    _lastHandledLoadOlderVersion = widget.historyController.loadOlderVersion;
    _lastHandledRevertVersion = widget.threadController?.revertVersion ?? 0;
    widget.controller.addListener(_handleConversationChanged);
    widget.historyController.addListener(_handleHistoryChanged);
    widget.threadController?.addListener(_handleThreadListChanged);
  }

  @override
  void didUpdateWidget(covariant _ConversationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.threadController, widget.threadController)) {
      oldWidget.threadController?.removeListener(_handleThreadListChanged);
      _lastHandledRevertVersion = widget.threadController?.revertVersion ?? 0;
      widget.threadController?.addListener(_handleThreadListChanged);
    }
  }

  @override
  void dispose() {
    widget.threadController?.removeListener(_handleThreadListChanged);
    widget.controller.removeListener(_handleConversationChanged);
    widget.historyController.removeListener(_handleHistoryChanged);
    _scrollController
      ..removeListener(_handleScrollPositionChanged)
      ..dispose();
    _threadActionsPopoverController.dispose();
    _composerAttachPopoverController.dispose();
    _composerFocusNode.dispose();
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return ColoredBox(
      color: palette.canvas,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.controller,
          if (widget.threadController != null) widget.threadController!,
          widget.diffController,
          widget.historyController,
        ]),
        builder: (context, _) {
          final controller = widget.controller;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _conversationHeader(controller),
              Expanded(
                child: _showChanges && widget.diffController.snapshot != null
                    ? _DiffView(controller: widget.diffController)
                    : _timeline(controller),
              ),
              _ApprovalBanner(controller: widget.approvalController),
              _composer(controller),
            ],
          );
        },
      ),
    );
  }

  Widget _conversationHeader(ConversationController controller) {
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
    final thread = controller.thread;
    final threadController = widget.threadController;
    final projectCwd = thread?.cwd ?? _activeProjectDirectory;
    return Container(
      key: const ValueKey('thread_header_bar'),
      height: OfficialCodexTheme.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.space4),
      decoration: BoxDecoration(
        color: theme.workspaceBackground,
        border: Border(
          bottom: BorderSide(
            color: palette.border,
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showProductMode = constraints.maxWidth >= 600;
          final showSegment = constraints.maxWidth >= 380;
          return Row(
            children: [
              if (widget.sidebarCollapsed &&
                  widget.onToggleSidebar != null) ...[
                CodexIconButton(
                  key: const ValueKey('sidebar-expand-button'),
                  tooltip: 'Show sidebar',
                  onPressed: widget.onToggleSidebar,
                  icon: const Icon(Icons.view_sidebar_outlined, size: 17),
                ),
                const SizedBox(width: ThemeTokens.space2),
              ],
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        thread?.displayTitle ?? 'New thread',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.0,
                            ),
                      ),
                    ),
                    if (projectCwd.isNotEmpty &&
                        constraints.maxWidth >= 680) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: CodexTooltip(
                          message: projectCwd,
                          child: Text(
                            _projectName(projectCwd),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palette.textSecondary),
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
              if (showProductMode) ...[
                CodexSegment<ProductMode>(
                  key: const ValueKey('product-mode-selector'),
                  items: const [
                    CodexSegmentItem(
                      value: ProductMode.codex,
                      label: 'Codex',
                      tooltip:
                          'Codex engineering workspace (Commands projection)',
                    ),
                    CodexSegmentItem(
                      value: ProductMode.work,
                      label: 'Work',
                      tooltip: 'Work task projection (Prose projection)',
                    ),
                    CodexSegmentItem(
                      value: ProductMode.chat,
                      label: 'Chat',
                      tooltip: 'Conversational reading projection (Prose projection)',
                    ),
                  ],
                  selectedValue: _productMode,
                  onSelected: (mode) {
                    setState(() {
                      _productMode = mode;
                      _detailMode = switch (mode.defaultDetailPolicy) {
                        PresentationDetailPolicy.prose =>
                          PresentationDetailMode.prose,
                        PresentationDetailPolicy.commands =>
                          PresentationDetailMode.commands,
                        PresentationDetailPolicy.execution =>
                          PresentationDetailMode.execution,
                      };
                    });
                  },
                ),
                const SizedBox(width: ThemeTokens.space1),
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
              if (thread != null && threadController != null) ...[
                const SizedBox(width: ThemeTokens.space1),
                CodexPopoverAnchor(
                  controller: _threadActionsPopoverController,
                  targetAnchor: Alignment.bottomRight,
                  followerAnchor: Alignment.topRight,
                  width: 196,
                  popoverBuilder: (context, close) {
                    final pinned = threadController.isPinned(thread.id);
                    final archived = threadController.showArchived;
                    return CodexMenu<String>(
                      items: [
                        CodexMenuItem(
                          value: 'pin',
                          label: pinned ? 'Unpin thread' : 'Pin thread',
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
                        const CodexMenuItem(
                          value: 'fork',
                          label: 'Fork thread',
                          icon: Icon(Icons.call_split_rounded),
                        ),
                        const CodexMenuItem(
                          value: 'compact',
                          label: 'Compact context',
                          icon: Icon(Icons.compress_rounded),
                        ),
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
                          case 'pin':
                            threadController.togglePinThread(thread.id);
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
                    tooltip: 'Thread actions (${_productMode.label})',
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

  Widget _timeline(ConversationController controller) {
    if (controller.thread == null) {
      _currentTimelineItemKeys = const [];
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
                  e.kind == ConversationEntryKind.assistant,
            )
            .toList(growable: false),
      PresentationDetailMode.commands =>
        rawLiveEntries
            .where(
              (e) =>
                  e.kind == ConversationEntryKind.user ||
                  e.kind == ConversationEntryKind.assistant ||
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
                  item.kind == HistoryItemKind.assistant,
            )
            .toList(growable: false),
      PresentationDetailMode.commands =>
        rawHistoryItems
            .where((item) {
              if (item.kind == HistoryItemKind.user ||
                  item.kind == HistoryItemKind.assistant) {
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
                  if (chronologicalIndex < historyItems.length) {
                    final item = historyItems[chronologicalIndex];
                    final itemKey = 'history-${item.id}';
                    final canMutateTurn =
                        item.kind == HistoryItemKind.user &&
                        item.turnId.isNotEmpty &&
                        activeThread != null &&
                        threadController != null &&
                        !controller.busy &&
                        !threadController.mutating;
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
                        onForkFromTurn: canMutateTurn
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
                        onRevertFromTurn: canMutateTurn
                            ? () async {
                                final reverted = await threadController
                                    .revertThread(
                                      threadId: activeThread.id,
                                      beforeTurnId: item.turnId,
                                    );
                                if (reverted != null && mounted) {
                                  widget.controller.clearEntries();
                                  _threadScrollBookmarks.remove(
                                    activeThread.id,
                                  );
                                  await widget.historyController.refresh();
                                }
                              }
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
                      !controller.busy &&
                      !threadController.mutating;
                  return _MeasuredTimelineItem(
                    key: ValueKey('measured-$itemKey'),
                    itemKey: itemKey,
                    turnId: liveTurnId,
                    onMeasured: _recordItemMeasurement,
                    onUnmount: _unregisterItemBox,
                    child: _ConversationEntryView(
                      key: ValueKey(entry.id),
                      entry: entry,
                      turnId: liveTurnId.isEmpty ? null : liveTurnId,
                      attachments: entry.attachments,
                      onForkFromTurn: canMutateLiveTurn
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
                      onRevertFromTurn: canMutateLiveTurn
                          ? () async {
                              final reverted = await threadController
                                  .revertThread(
                                    threadId: activeThread.id,
                                    beforeTurnId: liveTurnId,
                                  );
                              if (reverted != null && mounted) {
                                widget.controller.clearEntries();
                                _threadScrollBookmarks.remove(activeThread.id);
                                await widget.historyController.refresh();
                              }
                            }
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

  Widget _composer(ConversationController controller) {
    final palette = ThemeTokens.of(context);
    final thread = controller.thread;
    final projectCwd = thread?.cwd ?? _activeProjectDirectory;
    final canCreateOnSend =
        thread == null &&
        widget.threadController != null &&
        projectCwd.isNotEmpty &&
        !(widget.threadController?.mutating ?? false);
    final canSteer = controller.canSteer;
    final enabled =
        (thread != null || canCreateOnSend) && (!controller.busy || canSteer);
    return Container(
      color: palette.canvas,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
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
                  minLines: 1,
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
                  final showModelPill = rowConstraints.maxWidth >= 340;
                  final maxModelLabelWidth =
                      (rowConstraints.maxWidth - (compactComposer ? 270 : 450))
                          .clamp(56.0, 160.0);
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
                              items: const [
                                CodexMenuItem(
                                  value: UserAttachmentKind.mention,
                                  label: 'Attach file (@mention)',
                                  icon: Icon(Icons.description_outlined),
                                ),
                                CodexMenuItem(
                                  value: UserAttachmentKind.image,
                                  label: 'Attach image',
                                  icon: Icon(Icons.image_outlined),
                                ),
                                CodexMenuItem(
                                  value: UserAttachmentKind.skill,
                                  label: 'Attach skill (\$skill)',
                                  icon: Icon(Icons.auto_fix_high_outlined),
                                ),
                                CodexMenuItem(
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
                      _ExecutionSettingsButton(
                        controller: widget.settingsController,
                      ),
                      if (projectCwd.isNotEmpty && !compactComposer) ...[
                        const SizedBox(width: 4),
                        CodexTooltip(
                          message: projectCwd,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceRaised,
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
                                    maxWidth: 120,
                                  ),
                                  child: Text(
                                    _projectName(projectCwd),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (showModelPill)
                        _ComposerModelSummaryButton(
                          controller: widget.settingsController,
                          maxLabelWidth: maxModelLabelWidth,
                        ),
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
    if (widget.threadController case final threadController?) {
      if (widget.controller.thread == null) {
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
      } else {
        final ready = await threadController.ensureSelectedThreadLoaded();
        if (!ready) {
          return;
        }
      }
    }
    if (_activeThreadId case final threadId?) {
      _threadScrollBookmarks.remove(threadId);
    }
    if (widget.historyController.canReturnToNewest) {
      unawaited(widget.historyController.refresh());
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
    if (await widget.controller.submit(text, attachments: attachments)) {
      _composerController.clear();
      setState(_composerAttachments.clear);
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
    _pendingThreadRestore = nextThreadId != null;
    _restorePagesLoaded = 0;
    _restoreAlignmentPasses = 0;
    _preLoadOlderAnchor = null;
    _pendingStreamAnchor = null;
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

    final isActivity = entry.kind == ConversationEntryKind.activity;
    final isError = entry.kind == ConversationEntryKind.error;
    final showAssistantCopy =
        entry.kind == ConversationEntryKind.assistant &&
        entry.completed &&
        entry.text.trim().isNotEmpty;
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
                      ? palette.surfaceRaised
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
                          if (showAssistantCopy) ...[
                            const SizedBox(height: 6),
                            _AssistantCopyButton(
                              key: ValueKey('assistant-copy-${entry.id}'),
                              text: entry.text,
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
  });

  final ConversationEntry entry;
  final String? turnId;
  final List<UserAttachment> attachments;
  final VoidCallback? onForkFromTurn;
  final VoidCallback? onRevertFromTurn;

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
    final hasTurnActions =
        fullText.isNotEmpty ||
        onForkFromTurn != null ||
        onRevertFromTurn != null;

    return Padding(
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
                  if (fullText.isNotEmpty)
                    _AssistantCopyButton(
                      key: ValueKey('user-copy-${entry.id}'),
                      text: fullText,
                    ),
                  if (onForkFromTurn != null)
                    CodexTooltip(
                      message: 'Fork thread before this turn',
                      child: GestureDetector(
                        key: ValueKey('turn-fork-${turnId ?? entry.id}'),
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
                        key: ValueKey('turn-revert-${turnId ?? entry.id}'),
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
    final statusBadge = _nonNominalStatus(entry.status);
    final icon = !entry.completed
        ? Icons.hourglass_top_rounded
        : effectiveCommand
        ? Icons.terminal_rounded
        : isFileChange
        ? Icons.difference_outlined
        : Icons.check_circle_outline_rounded;
    final iconColor = !entry.completed
        ? palette.accent
        : statusBadge != null
        ? palette.warning
        : effectiveCommand || isFileChange
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
  const _ConversationEmptyState({this.workingDirectory = ''});

  final String workingDirectory;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final projectLabel = workingDirectory.trim().isEmpty
        ? null
        : _projectName(workingDirectory);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.surfaceRaised,
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.terminal_rounded,
                size: 22,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: ThemeTokens.space4),
            Text(
              'Let’s build',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (projectLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                projectLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: ThemeTokens.space2),
            Text(
              'Select existing work from the sidebar or type below to start a new thread.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadEmptyState extends StatelessWidget {
  const _ThreadEmptyState({required this.thread});

  final ThreadSummary thread;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.surfaceRaised,
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.terminal_rounded,
                size: 22,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: ThemeTokens.space4),
            Text(
              'Let’s build ${_projectName(thread.cwd)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: ThemeTokens.space2),
            Text(
              'Describe the change you want to make. Codex will keep progress, '
              'tools, approvals, and changes in this thread.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
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
        if (model == null) {
          return const SizedBox.shrink();
        }
        final rawEffort =
            controller.selectedReasoningEffort ?? model.defaultReasoningEffort;
        final effortLabel = _formatEffortLabel(rawEffort);
        final summary = effortLabel == null
            ? model.displayName
            : '${model.displayName} · $effortLabel';
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
        !await _confirm(
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
        !await _confirm(
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

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

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
