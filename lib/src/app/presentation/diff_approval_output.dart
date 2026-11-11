part of '../codex_native_app.dart';

class _DiffFilePicker extends StatefulWidget {
  const _DiffFilePicker({
    required this.files,
    required this.selectedPath,
    required this.onSelected,
  });

  final List<DiffFile> files;
  final String selectedPath;
  final ValueChanged<String> onSelected;

  @override
  State<_DiffFilePicker> createState() => _DiffFilePickerState();
}

class _DiffFilePickerState extends State<_DiffFilePicker> {
  final _popoverController = CodexPopoverController();

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final selectedFile = widget.files.firstWhere(
      (f) => f.path == widget.selectedPath,
      orElse: () => widget.files.first,
    );
    final label =
        '${selectedFile.path}  +${selectedFile.additions} -${selectedFile.deletions}';

    return CodexPopoverAnchor(
      controller: _popoverController,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      width: 320,
      popoverBuilder: (context, close) => CodexMenu<String>(
        items: [
          for (final file in widget.files)
            CodexMenuItem<String>(
              value: file.path,
              label: '${file.path}  +${file.additions} -${file.deletions}',
            ),
        ],
        selectedValue: widget.selectedPath,
        onSelected: (path) {
          widget.onSelected(path);
          close();
        },
      ),
      child: GestureDetector(
        key: const ValueKey('diff-file-picker'),
        behavior: HitTestBehavior.opaque,
        onTap: _popoverController.toggle,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 36.0,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
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
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.0,
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6.0),
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
    );
  }
}

class _DesktopChangesPane extends StatelessWidget {
  const _DesktopChangesPane({
    required this.width,
    required this.controller,
    required this.onClose,
  });

  final double width;
  final DiffController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    return Container(
      key: const ValueKey('desktop-changes-pane'),
      width: width,
      decoration: BoxDecoration(
        color: theme.workspaceBackground,
        border: BorderDirectional(
          start: BorderSide(
            color: theme.hairlineBorder,
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
            child: SizedBox(
              height: OfficialCodexTheme.headerHeight,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Changes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  CodexIconButton(
                    tooltip: 'Close Changes pane',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: OfficialCodexTheme.hairlineBorderWidth,
            color: theme.hairlineBorder,
          ),
          Expanded(child: _DiffView(controller: controller)),
        ],
      ),
    );
  }
}

class _DiffView extends StatelessWidget {
  const _DiffView({required this.controller});

  final DiffController controller;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final snapshot = controller.snapshot;
    final selected = controller.selectedFile;
    if (snapshot == null || snapshot.files.isEmpty || selected == null) {
      return Center(
        child: Text(
          'No file changes for this turn.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(ThemeTokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DiffFilePicker(
                files: snapshot.files,
                selectedPath: selected.path,
                onSelected: controller.selectFile,
              ),
              Text(
                '${snapshot.files.length} file(s)  '
                '+${snapshot.additions}  -${snapshot.deletions}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (snapshot.truncated || selected.truncated) ...[
                const SizedBox(height: ThemeTokens.space2),
                Text(
                  'Large diff truncated to the bounded presentation limit.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.warning),
                ),
              ],
            ],
          ),
        ),
        const Divider(
          height: 1,
          thickness: OfficialCodexTheme.hairlineBorderWidth,
        ),
        Expanded(child: _DiffLines(file: selected)),
      ],
    );
  }
}

class _DiffLines extends StatelessWidget {
  const _DiffLines({required this.file});

  final DiffFile file;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
    return SelectionArea(
      child: ListView.builder(
        itemExtent: 21,
        itemCount: file.lines.length,
        itemBuilder: (context, index) {
          final line = file.lines[index];
          final isAdded = line.startsWith('+') && !line.startsWith('+++');
          final isRemoved = line.startsWith('-') && !line.startsWith('---');
          final background = isAdded
              ? palette.diffAdded
              : isRemoved
              ? palette.diffRemoved
              : Colors.transparent;
          final textColor = isAdded
              ? theme.diffAddedText
              : isRemoved
              ? theme.diffRemovedText
              : null;
          return ColoredBox(
            color: background,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ThemeTokens.space3,
              ),
              child: Text(
                line,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                  color: textColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner({super.key, required this.controller});

  final ApprovalController controller;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final error = controller.errorMessage;
        final request = controller.pending.firstOrNull;
        if (request == null && error == null) {
          return const SizedBox.shrink();
        }
        if (request == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _InlineNotice(
              icon: Icons.error_outline_rounded,
              color: palette.danger,
              text: error!,
            ),
          );
        }

        final deciding = controller.isDeciding(request.requestId);
        return Center(
          heightFactor: 1,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: OfficialCodexTheme.maxContentWidth,
            ),
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            padding: const EdgeInsets.all(ThemeTokens.space3),
            decoration: BoxDecoration(
              color: palette.warning.withValues(alpha: 0.08),
              border: Border.all(
                color: palette.warning.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(
                OfficialCodexTheme.mainSurfaceRadius,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Approval required'
                        '${controller.pending.length > 1 ? ' (${controller.pending.length})' : ''}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (deciding)
                      const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: ThemeTokens.space2),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      key: const ValueKey('approval-details-scroll'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(request.summary),
                          if (request.detail case final detail?) ...[
                            const SizedBox(height: ThemeTokens.space1),
                            SelectableText(
                              detail,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (request.reason case final reason?) ...[
                            const SizedBox(height: ThemeTokens.space1),
                            SelectableText(
                              'Reason: $reason',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: ThemeTokens.space2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      flex: 2,
                      child: CodexButton(
                        variant: CodexButtonVariant.ghost,
                        size: CodexButtonSize.sm,
                        onPressed: deciding
                            ? null
                            : () => controller.reject(request.requestId),
                        label: 'Reject',
                        tooltip: 'Reject',
                      ),
                    ),
                    if (request.approveSupported) ...[
                      const SizedBox(width: ThemeTokens.space2),
                      Flexible(
                        flex: 3,
                        child: CodexButton(
                          variant: CodexButtonVariant.primary,
                          size: CodexButtonSize.sm,
                          onPressed: deciding
                              ? null
                              : () => controller.approve(request.requestId),
                          label: 'Approve once',
                          tooltip: 'Approve once',
                        ),
                      ),
                    ],
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: ThemeTokens.space2),
                  SelectableText(
                    error,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: palette.danger),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryEntryView extends StatelessWidget {
  const _HistoryEntryView({
    super.key,
    required this.item,
    required this.historyController,
    this.detailMode = PresentationDetailMode.commands,
    this.inlineActivity = false,
    this.revealAssistantCopy = false,
    this.commandOutput,
    this.groupedCommands,
    this.showDetailsHeader = true,
    this.bottomGap,
    this.onForkFromTurn,
    this.onRevertFromTurn,
    this.onEditFromTurn,
    this.onRegenerateFromTurn,
    this.onContinueTurn,
    this.onRetryTurn,
    this.siblingBranchInfo,
    this.onSelectSiblingBranch,
    this.overrideEntryText,
    this.overrideAttachments,
    this.isSearchMatch = false,
    this.isActiveSearchMatch = false,
  });

  final HistoryItem item;
  final HistoryController historyController;
  final PresentationDetailMode detailMode;
  final bool inlineActivity;
  final bool revealAssistantCopy;
  final _CommandOutputPresentation? commandOutput;
  final Widget? groupedCommands;
  final bool showDetailsHeader;
  final double? bottomGap;
  final VoidCallback? onForkFromTurn;
  final VoidCallback? onRevertFromTurn;
  final VoidCallback? onEditFromTurn;
  final VoidCallback? onRegenerateFromTurn;
  final VoidCallback? onContinueTurn;
  final VoidCallback? onRetryTurn;
  final ChatSiblingBranchInfo? siblingBranchInfo;
  final ValueChanged<int>? onSelectSiblingBranch;
  final String? overrideEntryText;
  final List<UserAttachment>? overrideAttachments;
  final bool isSearchMatch;
  final bool isActiveSearchMatch;

  @override
  Widget build(BuildContext context) {
    final kind = switch (item.kind) {
      HistoryItemKind.user => ConversationEntryKind.user,
      HistoryItemKind.assistant => ConversationEntryKind.assistant,
      HistoryItemKind.review => ConversationEntryKind.review,
      HistoryItemKind.activity ||
      HistoryItemKind.reasoning ||
      HistoryItemKind.unknown => ConversationEntryKind.activity,
    };
    final turn = historyController.turnForId(item.turnId);
    final durationLabel = turn?.formattedWorkDuration;
    final showDetails =
        showDetailsHeader &&
        historyController.isTurnDetailsAnchor(item) &&
        (detailMode != PresentationDetailMode.prose ||
            (durationLabel != null && item.kind != HistoryItemKind.user));
    final selected = historyController.selectedTurnId == item.turnId;
    final loadFailed =
        selected && historyController.selectedTurnDetailsLoadFailed;
    final expanded = selected && !loadFailed;
    final detailsHeader = showDetails
        ? _TurnWorkDivider(
            actionKey: ValueKey('turn-work-${item.turnId}'),
            label: loadFailed
                ? 'Retry turn details'
                : durationLabel ?? 'Turn details',
            expanded: expanded,
            inline: inlineActivity,
            loading: selected && historyController.loadingItems,
            onTap: historyController.loadingItems
                ? null
                : () {
                    if (expanded) {
                      historyController.collapseTurnItems();
                    } else {
                      unawaited(historyController.loadTurnItems(item.turnId));
                    }
                  },
          )
        : null;
    if (groupedCommands case final group?) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: OfficialCodexTheme.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [?detailsHeader, group],
          ),
        ),
      );
    }
    final effectiveAttachments = overrideAttachments ?? item.attachments;
    final useInlinePreviewDisclosure =
        inlineActivity &&
        item.isCommand &&
        (commandOutput?.hasInlinePreview ?? false);
    return _ConversationEntryView(
      entry: ConversationEntry(
        id: item.id,
        kind: kind,
        text: overrideEntryText ?? item.text,
        completed: true,
        status: item.status,
        attachments: effectiveAttachments,
      ),
      attachments: effectiveAttachments,
      turnId: item.turnId,
      onForkFromTurn: onForkFromTurn,
      onRevertFromTurn: onRevertFromTurn,
      onEditFromTurn: onEditFromTurn,
      onRegenerateFromTurn: onRegenerateFromTurn,
      onContinueTurn: onContinueTurn,
      onRetryTurn: onRetryTurn,
      siblingBranchInfo: siblingBranchInfo,
      onSelectSiblingBranch: onSelectSiblingBranch,
      isSearchMatch: isSearchMatch,
      isActiveSearchMatch: isActiveSearchMatch,
      isReasoning: item.kind == HistoryItemKind.reasoning,
      isCommand: item.isCommand,
      detailMode: detailMode,
      inlineActivity: inlineActivity,
      revealAssistantCopy: revealAssistantCopy,
      bottomGap: bottomGap,
      activitySummary: _explorationCaption(),
      activityDetail: commandOutput?.detail,
      hasActivityDisclosure: useInlinePreviewDisclosure,
      activityExpanded:
          useInlinePreviewDisclosure &&
          (commandOutput?.previewExpanded ?? false),
      onToggleActivity: useInlinePreviewDisclosure
          ? commandOutput?.onTogglePreview
          : null,
      activityDisclosureTooltip: useInlinePreviewDisclosure
          ? commandOutput?.previewTooltip
          : null,
      leadingHeader: detailsHeader,
      trailingAction: item.isCommand
          ? (useInlinePreviewDisclosure
                ? null
                : commandOutput?.action ?? _commandOutputFallback(context))
          : _savedMcpTextAction(context),
    );
  }

  String? _explorationCaption() {
    final action = item.commandAction;
    if (action == null ||
        !inlineActivity ||
        detailMode != PresentationDetailMode.commands ||
        item.status != 'completed') {
      return null;
    }
    final (:kind, :name, :path, :query) = action;
    return switch (kind) {
      CommandActionKind.read => switch (name ?? path) {
        final target? => 'Read $target',
        null => null,
      },
      CommandActionKind.listFiles =>
        path == null ? 'Listed files' : 'Listed files in $path',
      CommandActionKind.search => switch ((query, path)) {
        (final query?, final path?) => 'Searched for $query in $path',
        (final query?, null) => 'Searched for $query',
        _ => 'Searched for files',
      },
      CommandActionKind.run => null,
    };
  }

  Widget? _commandOutputFallback(BuildContext context) {
    final output = item.output;
    if (output != null && !output.available) {
      return Text(
        'Output unavailable',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      );
    }
    if (item.outputDeferred) {
      return CodexButton(
        variant: CodexButtonVariant.ghost,
        size: CodexButtonSize.sm,
        onPressed: historyController.loadingItems
            ? null
            : () => historyController.loadDeferredOutput(item),
        label: 'Fetch output safely',
        tooltip: 'Fetch output safely',
      );
    }
    if (historyController.selectedTurnId != item.turnId) {
      return CodexButton(
        variant: CodexButtonVariant.ghost,
        size: CodexButtonSize.sm,
        onPressed: historyController.loadingItems
            ? null
            : () => historyController.loadTurnItems(item.turnId),
        label: 'Load turn details',
        tooltip: 'Load turn details',
      );
    }
    return null;
  }

  Widget? _savedMcpTextAction(BuildContext context) {
    if (!historyController.canReadSavedMcpText(item)) {
      return null;
    }
    return CodexButton(
      variant: CodexButtonVariant.ghost,
      size: CodexButtonSize.sm,
      label: 'View saved text',
      tooltip: 'View saved text',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => _SavedMcpTextDialog(
          read: () => historyController.loadSavedMcpText(item),
        ),
      ),
    );
  }
}

Widget _commandOutputDialogAction(
  BuildContext context,
  OutputGateway gateway,
  OutputDescriptor output,
) {
  final label = output.truncated
      ? 'View stored output (truncated)'
      : 'View output';
  return CodexButton(
    variant: CodexButtonVariant.ghost,
    size: CodexButtonSize.sm,
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => _OutputDialog(gateway: gateway, descriptor: output),
    ),
    icon: const Icon(Icons.terminal, size: 14),
    label: label,
    tooltip: label,
  );
}

class _InlineCommandOutput extends StatelessWidget {
  const _InlineCommandOutput({
    required this.viewer,
    required this.openFullOutput,
  });

  final OutputViewerController viewer;
  final Widget openFullOutput;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final chunk = viewer.chunk;
    final output = viewer.text;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start:
            OfficialCodexTheme.activityInlineIconSize +
            OfficialCodexTheme.activityInlineIconGap,
        top: OfficialCodexTheme.conversationGroupedItemGap,
      ),
      child: Container(
        key: const ValueKey('command-output-preview-surface'),
        padding: const EdgeInsets.all(ThemeTokens.space2),
        decoration: BoxDecoration(
          color: theme.elevatedSurface,
          border: Border.all(color: theme.hairlineBorder),
          borderRadius: BorderRadius.circular(
            OfficialCodexTheme.activityRowRadius,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (viewer.loading)
              Text('Loading output preview…', style: textStyle)
            else if (viewer.errorMessage != null)
              Text(
                'Could not load output preview.',
                style: textStyle?.copyWith(color: theme.danger),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: OfficialCodexTheme.commandOutputPreviewHeight,
                ),
                child: SingleChildScrollView(
                  key: const ValueKey('command-output-preview-scroll'),
                  primary: false,
                  child: SingleChildScrollView(
                    primary: false,
                    scrollDirection: Axis.horizontal,
                    child: SelectionArea(
                      child: Text(
                        output.isEmpty ? 'No output' : output,
                        softWrap: false,
                        style: textStyle?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: ThemeTokens.space2),
            Wrap(
              alignment: chunk != null && chunk.offset > 0
                  ? WrapAlignment.spaceBetween
                  : WrapAlignment.end,
              spacing: ThemeTokens.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (chunk != null && chunk.offset > 0)
                  Text(
                    'Last ${chunk.data.length} stored bytes',
                    style: textStyle?.copyWith(color: theme.textSecondary),
                  ),
                openFullOutput,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedMcpTextDialog extends StatefulWidget {
  const _SavedMcpTextDialog({required this.read});

  final Future<SavedMcpTextResult?> Function() read;

  @override
  State<_SavedMcpTextDialog> createState() => _SavedMcpTextDialogState();
}

class _SavedMcpTextDialogState extends State<_SavedMcpTextDialog> {
  SavedMcpTextResult? _result;
  _SavedMcpTextFailure? _failure;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    SavedMcpTextResult? result;
    _SavedMcpTextFailure? failure;
    try {
      result = await widget.read().timeout(const Duration(seconds: 15));
    } on UnsupportedError {
      failure = _SavedMcpTextFailure.unsupported;
    } catch (_) {
      failure = _SavedMcpTextFailure.retryable;
    }
    if (mounted) {
      setState(() {
        _result = result;
        _failure = failure;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Saved MCP text'),
    scrollable: true,
    content: SizedBox(width: 520, child: _content()),
    actions: [
      if (!_loading && _failure == _SavedMcpTextFailure.retryable)
        CodexButton(
          variant: CodexButtonVariant.ghost,
          size: CodexButtonSize.sm,
          label: 'Retry',
          onPressed: () {
            if (_loading) {
              return;
            }
            setState(() => _loading = true);
            unawaited(_read());
          },
        ),
      CodexButton(
        variant: CodexButtonVariant.ghost,
        size: CodexButtonSize.sm,
        label: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );

  Widget _content() {
    if (_loading) {
      return const LinearProgressIndicator(
        semanticsLabel: 'Loading saved MCP text',
      );
    }
    switch (_failure) {
      case _SavedMcpTextFailure.unsupported:
        return const Text(
          'This local runtime does not support reading saved MCP text.',
        );
      case _SavedMcpTextFailure.retryable:
        return const Text('Could not read the saved MCP text.');
      case null:
        break;
    }
    final result = _result;
    if (result == null) {
      return const Text('No saved plain-text result is available.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (result.truncated)
          const Padding(
            padding: EdgeInsets.only(bottom: ThemeTokens.space2),
            child: Text('Showing a bounded preview of the saved text.'),
          ),
        SelectableText(result.text),
      ],
    );
  }
}

enum _SavedMcpTextFailure { unsupported, retryable }

class _SavedCommandGroup extends StatefulWidget {
  const _SavedCommandGroup({
    super.key,
    required this.label,
    required this.includesExploration,
    required this.itemCount,
    required this.initiallyExpanded,
    required this.itemBuilder,
    required this.onCollapse,
  });

  final String label;
  final bool includesExploration;
  final int itemCount;
  final bool initiallyExpanded;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback onCollapse;

  @override
  State<_SavedCommandGroup> createState() => _SavedCommandGroupState();
}

class _SavedCommandGroupState extends State<_SavedCommandGroup> {
  late var _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CodexInlineActivityHeader(
          label: widget.label,
          leadingIcon: Icon(
            widget.includesExploration
                ? Icons.menu_book_outlined
                : Icons.terminal_rounded,
            size: OfficialCodexTheme.activityInlineIconSize,
          ),
          hasDisclosure: true,
          isExpanded: _expanded,
          onToggle: () {
            setState(() => _expanded = !_expanded);
            if (!_expanded) {
              widget.onCollapse();
            }
          },
        ),
        if (_expanded) ...[
          const SizedBox(height: OfficialCodexTheme.conversationGroupedItemGap),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: OfficialCodexTheme.activityGroupMaxHeight,
            ),
            child: ListView.builder(
              key: const ValueKey('saved-command-group-items'),
              primary: false,
              shrinkWrap: true,
              scrollCacheExtent: const ScrollCacheExtent.pixels(0),
              padding: EdgeInsets.zero,
              itemCount: widget.itemCount,
              itemBuilder: widget.itemBuilder,
            ),
          ),
        ],
        const SizedBox(height: OfficialCodexTheme.conversationItemGap),
      ],
    );
  }
}

class _TurnWorkDivider extends StatelessWidget {
  const _TurnWorkDivider({
    required this.actionKey,
    required this.label,
    required this.expanded,
    required this.loading,
    required this.inline,
    this.onTap,
  });

  final Key actionKey;
  final String label;
  final bool expanded;
  final bool loading;
  final bool inline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (inline) {
      return CodexInlineWorkDivider(
        triggerKey: actionKey,
        label: label,
        isExpanded: expanded,
        isLoading: loading,
        onToggle: onTap,
      );
    }
    return CodexActivityDivider(
      key: actionKey,
      label: label,
      isExpanded: expanded,
      isLoading: loading,
      onToggle: onTap,
    );
  }
}

class _OutputDialog extends StatefulWidget {
  const _OutputDialog({required this.gateway, required this.descriptor});

  final OutputGateway gateway;
  final OutputDescriptor descriptor;

  @override
  State<_OutputDialog> createState() => _OutputDialogState();
}

class _OutputDialogState extends State<_OutputDialog> {
  late final OutputViewerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OutputViewerController(
      gateway: widget.gateway,
      descriptor: widget.descriptor,
    );
    unawaited(_controller.loadInitial());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final width = (viewport.width - 32).clamp(280, 820).toDouble();
    final height = (viewport.height - 32).clamp(320, 680).toDouble();
    return Dialog(
      backgroundColor: theme.modalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final chunk = _controller.chunk;
            final rows = _outputRows(_controller.text);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ThemeTokens.space3,
                    ThemeTokens.space3,
                    ThemeTokens.space3,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Command output',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      CodexIconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height / 3),
                  child: SingleChildScrollView(
                    primary: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            ThemeTokens.space3,
                            0,
                            ThemeTokens.space3,
                            ThemeTokens.space3,
                          ),
                          child: Text(
                            chunk == null
                                ? '${widget.descriptor.storedBytes} stored byte(s)'
                                : 'Window at byte ${chunk.offset} of '
                                      '${widget.descriptor.storedBytes}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (widget.descriptor.truncated)
                          Container(
                            padding: const EdgeInsets.all(ThemeTokens.space2),
                            color: palette.warning.withValues(alpha: 0.1),
                            child: Text(
                              'Only ${widget.descriptor.storedBytes} of '
                              '${widget.descriptor.bytes} bytes were retained by the '
                              'configured Host limit.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        if (_controller.errorMessage case final error?)
                          Padding(
                            padding: const EdgeInsets.all(ThemeTokens.space2),
                            child: SelectableText(
                              error,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: palette.danger),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: OfficialCodexTheme.hairlineBorderWidth,
                ),
                Expanded(
                  child: ColoredBox(
                    color: palette.codeSurface,
                    child: _controller.loading && chunk == null
                        ? const Center(child: CircularProgressIndicator())
                        : SelectionArea(
                            child: ListView.builder(
                              key: const ValueKey('output-window-list'),
                              itemExtent: math.max(
                                20,
                                MediaQuery.textScalerOf(context).scale(20),
                              ),
                              itemCount: rows.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ThemeTokens.space3,
                                ),
                                child: Text(
                                  rows[index],
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontFamily: 'monospace',
                                        color: CodexPalette.dark.textPrimary,
                                      ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: OfficialCodexTheme.hairlineBorderWidth,
                ),
                Padding(
                  padding: const EdgeInsets.all(ThemeTokens.space2),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      CodexButton(
                        variant: CodexButtonVariant.ghost,
                        size: CodexButtonSize.sm,
                        onPressed: _controller.loading
                            ? null
                            : _controller.loadStart,
                        label: 'First',
                      ),
                      CodexButton(
                        variant: CodexButtonVariant.ghost,
                        size: CodexButtonSize.sm,
                        onPressed: _controller.canLoadPrevious
                            ? _controller.loadPrevious
                            : null,
                        label: 'Previous',
                      ),
                      CodexButton(
                        variant: CodexButtonVariant.ghost,
                        size: CodexButtonSize.sm,
                        onPressed: _controller.canLoadNext
                            ? _controller.loadNext
                            : null,
                        label: 'Next',
                      ),
                      CodexButton(
                        variant: CodexButtonVariant.ghost,
                        size: CodexButtonSize.sm,
                        onPressed: _controller.loading
                            ? null
                            : _controller.loadTail,
                        label: 'Tail',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

List<String> _outputRows(String text) {
  const maxCharactersPerRow = 4096;
  final rows = <String>[];
  for (final line in text.split('\n')) {
    if (line.isEmpty) {
      rows.add('');
      continue;
    }
    var offset = 0;
    while (offset < line.length) {
      var end = (offset + maxCharactersPerRow).clamp(0, line.length);
      if (end < line.length &&
          _isHighSurrogate(line.codeUnitAt(end - 1)) &&
          _isLowSurrogate(line.codeUnitAt(end))) {
        end -= 1;
      }
      rows.add(line.substring(offset, end));
      offset = end;
    }
  }
  return rows;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xd800 && codeUnit <= 0xdbff;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xdc00 && codeUnit <= 0xdfff;

class _HistoryFooter extends StatelessWidget {
  const _HistoryFooter({super.key, required this.controller});

  final HistoryController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadingTurns || controller.loadingItems) {
      return const Padding(
        padding: EdgeInsets.all(ThemeTokens.space3),
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: ThemeTokens.space2,
      children: [
        if (controller.canLoadOlderTurns)
          CodexButton(
            variant: CodexButtonVariant.ghost,
            size: CodexButtonSize.sm,
            onPressed: controller.loadOlderTurns,
            label: 'Load older turns',
          ),
        if (controller.canReturnToNewest)
          CodexButton(
            variant: CodexButtonVariant.ghost,
            size: CodexButtonSize.sm,
            onPressed: controller.refresh,
            label: 'Return to newest',
          ),
        if (controller.canLoadMoreItems)
          CodexButton(
            variant: CodexButtonVariant.ghost,
            size: CodexButtonSize.sm,
            onPressed: controller.loadMoreItems,
            label: 'Load more items',
          ),
      ],
    );
  }
}
