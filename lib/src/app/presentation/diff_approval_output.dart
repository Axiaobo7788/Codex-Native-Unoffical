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
        final choices = request.availableDecisions;
        final actions = [
          ...choices,
          if (!choices.contains(ApprovalDecision.reject))
            ApprovalDecision.reject,
        ];
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
                          for (final choice in choices)
                            if (_scope(choice) case final scope?) ...[
                              const SizedBox(height: ThemeTokens.space2),
                              SelectableText(
                                scope,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: ThemeTokens.space2),
                _ApprovalActions(
                  key: ObjectKey(request),
                  request: request,
                  controller: controller,
                  choices: actions,
                  deciding: deciding,
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

  static String _label(ApprovalDecision decision) => switch (decision.kind) {
    ApprovalDecisionKind.approveOnce => 'Approve once',
    ApprovalDecisionKind.approveForSession => 'Approve for session',
    ApprovalDecisionKind.approveWithExecpolicyAmendment =>
      'Allow similar commands',
    ApprovalDecisionKind.applyNetworkPolicyAmendment =>
      decision.networkAction == ApprovalNetworkAction.allow
          ? 'Always allow ${decision.networkHost}'
          : 'Always deny ${decision.networkHost}',
    ApprovalDecisionKind.reject => 'Reject',
    ApprovalDecisionKind.cancelTurn => 'Stop turn',
  };

  static String? _scope(ApprovalDecision decision) => switch (decision.kind) {
    ApprovalDecisionKind.approveForSession =>
      'Approve using the stock runtime session-scoped approval cache. '
          'This is broader than a one-time approval.',
    ApprovalDecisionKind.approveWithExecpolicyAmendment =>
      'Approve and apply the proposed command rule. Prefix arguments in order:\n'
          '${decision.execpolicyAmendment.indexed.map((entry) => '${entry.$1 + 1}: ${jsonEncode(entry.$2)}').join('\n')}',
    ApprovalDecisionKind.applyNetworkPolicyAmendment =>
      'Save a persistent ${decision.networkAction!.name} network rule for host: '
          '${jsonEncode(decision.networkHost)}',
    ApprovalDecisionKind.cancelTurn =>
      'Deny this request and stop the current turn.',
    ApprovalDecisionKind.approveOnce || ApprovalDecisionKind.reject => null,
  };
}

class _ApprovalActions extends StatefulWidget {
  const _ApprovalActions({
    super.key,
    required this.request,
    required this.controller,
    required this.choices,
    required this.deciding,
  });

  final ApprovalRequest request;
  final ApprovalController controller;
  final List<ApprovalDecision> choices;
  final bool deciding;

  @override
  State<_ApprovalActions> createState() => _ApprovalActionsState();
}

class _ApprovalActionsState extends State<_ApprovalActions> {
  final _more = CodexPopoverController();
  final _moreButtonKey = GlobalKey();

  @override
  void didUpdateWidget(covariant _ApprovalActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deciding && !oldWidget.deciding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.deciding) _more.hide();
      });
    }
  }

  @override
  void dispose() {
    _more.dispose();
    super.dispose();
  }

  void _openMore() {
    if (_more.isOpen) {
      _more.hide();
      return;
    }
    final box = _moreButtonKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    // The existing point-positioned menu clamps its complete bounded surface
    // inside the window, even when the approval card is in a short split.
    _more.show(
      globalPosition: box.localToGlobal(Offset(0, box.size.height + 6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extra = widget.choices
        .where(
          (choice) =>
              choice != ApprovalDecision.approveOnce &&
              choice != ApprovalDecision.reject,
        )
        .toList(growable: false);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          flex: 2,
          child: CodexButton(
            variant: CodexButtonVariant.ghost,
            size: CodexButtonSize.sm,
            label: 'Reject',
            tooltip: 'Reject',
            onPressed: widget.deciding
                ? null
                : () => widget.controller.choose(
                    widget.request,
                    ApprovalDecision.reject,
                  ),
          ),
        ),
        if (widget.request.approveSupported) ...[
          const SizedBox(width: ThemeTokens.space2),
          Flexible(
            flex: 3,
            child: CodexButton(
              variant: CodexButtonVariant.primary,
              size: CodexButtonSize.sm,
              label: 'Approve once',
              tooltip: 'Approve once',
              onPressed: widget.deciding
                  ? null
                  : () => widget.controller.choose(
                      widget.request,
                      ApprovalDecision.approveOnce,
                    ),
            ),
          ),
        ],
        if (extra.isNotEmpty) ...[
          const SizedBox(width: ThemeTokens.space2),
          CodexPopoverAnchor(
            controller: _more,
            width: math.min(
              420.0,
              math.max(0.0, MediaQuery.sizeOf(context).width - 16),
            ),
            popoverBuilder: (context, close) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(
                  0.0,
                  math.min(360.0, MediaQuery.sizeOf(context).height - 24),
                ),
              ),
              child: SingleChildScrollView(
                child: CodexMenu<ApprovalDecision>(
                  header: const Text('Choose an approval response'),
                  items: [
                    for (final choice in extra)
                      CodexMenuItem(
                        value: choice,
                        label: _ApprovalBanner._label(choice),
                        description: _ApprovalBanner._scope(choice),
                        disabled: widget.deciding,
                        trailing: switch (_ApprovalBanner._scope(choice)) {
                          final scope? => CodexTooltip(
                            message: scope,
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              semanticLabel: scope,
                            ),
                          ),
                          null => null,
                        },
                      ),
                  ],
                  onSelected: (choice) {
                    close();
                    widget.controller.choose(widget.request, choice);
                  },
                ),
              ),
            ),
            child: CodexIconButton(
              key: _moreButtonKey,
              icon: const Icon(Icons.more_horiz_rounded),
              size: 28,
              tooltip: 'Choose an approval response',
              onPressed: widget.deciding ? null : _openMore,
            ),
          ),
        ],
      ],
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
    final resolvedActivity = overrideEntryText == null
        ? _resolveHistoryInlineActivity(
            item,
            inlineActivity: inlineActivity,
            detailMode: detailMode,
          )
        : null;
    final useInlinePreviewDisclosure =
        inlineActivity &&
        item.isCommand &&
        (commandOutput?.hasInlinePreview ?? false);
    return _ConversationEntryView(
      entry: ConversationEntry(
        id: item.id,
        kind: kind,
        text: overrideEntryText ?? item.text,
        reasoningParts: overrideEntryText == null
            ? item.reasoningParts
            : const [],
        completed: true,
        status: item.status,
        exitCode: item.exitCode,
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
      resolvedActivity: resolvedActivity,
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
    this.rawCommand = '',
    this.status,
    this.completed = true,
    this.exitCode,
  });

  final OutputViewerController viewer;
  final Widget openFullOutput;
  final String rawCommand;
  final String? status;
  final bool completed;
  final int? exitCode;

  @override
  Widget build(BuildContext context) {
    final chunk = viewer.chunk;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start:
            OfficialCodexTheme.activityInlineIconSize +
            OfficialCodexTheme.activityInlineIconGap,
        top: OfficialCodexTheme.conversationGroupedItemGap,
      ),
      child: CodexShellExecutionCard(
        rawCommand: rawCommand,
        output: viewer.text,
        loading: viewer.loading,
        errorMessage: viewer.errorMessage,
        isInProgress: !completed || status?.trim() == 'inProgress',
        status: status,
        exitCode: exitCode ?? viewer.descriptor.exitCode,
        storedBytesNotice: chunk != null && chunk.offset > 0
            ? 'Last ${chunk.data.length} stored bytes'
            : null,
        trailingFooterAction: openFullOutput,
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
    this.iconData,
    required this.itemCount,
    this.initiallyExpanded = false,
    this.controlledExpanded,
    this.onExpansionChanged,
    this.listKey = const ValueKey('saved-command-group-items'),
    required this.itemBuilder,
    this.onCollapse,
  });

  final String label;
  final IconData? iconData;
  final int itemCount;
  final bool initiallyExpanded;
  final bool? controlledExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final Key? listKey;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onCollapse;

  @override
  State<_SavedCommandGroup> createState() => _SavedCommandGroupState();
}

class _SavedCommandGroupState extends State<_SavedCommandGroup> {
  late var _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final expanded = widget.controlledExpanded ?? _expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CodexInlineActivityHeader(
          label: widget.label,
          leadingIcon: Icon(
            widget.iconData ?? Icons.terminal_rounded,
            size: OfficialCodexTheme.activityInlineIconSize,
          ),
          hasDisclosure: true,
          isExpanded: expanded,
          onToggle: () {
            final next = !expanded;
            if (widget.controlledExpanded == null) {
              setState(() => _expanded = next);
            }
            widget.onExpansionChanged?.call(next);
            if (!next) {
              widget.onCollapse?.call();
            }
          },
        ),
        if (expanded) ...[
          const SizedBox(height: OfficialCodexTheme.conversationGroupedItemGap),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: OfficialCodexTheme.activityGroupMaxHeight,
            ),
            child: ListView.builder(
              key: widget.listKey,
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
