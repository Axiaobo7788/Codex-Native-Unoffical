part of '../codex_native_app.dart';

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
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const ValueKey('diff-file-picker'),
                  value: selected.path,
                  isExpanded: true,
                  items: [
                    for (final file in snapshot.files)
                      DropdownMenuItem(
                        value: file.path,
                        child: Text(
                          '${file.path}  +${file.additions} -${file.deletions}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (path) {
                    if (path != null) {
                      controller.selectFile(path);
                    }
                  },
                ),
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
        const Divider(height: 1),
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
    return SelectionArea(
      child: ListView.builder(
        itemExtent: 21,
        itemCount: file.lines.length,
        itemBuilder: (context, index) {
          final line = file.lines[index];
          final background = line.startsWith('+') && !line.startsWith('+++')
              ? palette.diffAdded
              : line.startsWith('-') && !line.startsWith('---')
              ? palette.diffRemoved
              : Colors.transparent;
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
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace', height: 1.5),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner({required this.controller});

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
          child: Container(
            constraints: const BoxConstraints(maxWidth: 760),
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            padding: const EdgeInsets.all(ThemeTokens.space3),
            decoration: BoxDecoration(
              color: palette.warning.withValues(alpha: 0.08),
              border: Border.all(
                color: palette.warning.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
            ),
            child: Column(
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
                const SizedBox(height: ThemeTokens.space2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: deciding
                          ? null
                          : () => controller.reject(request.requestId),
                      child: const Text('Reject'),
                    ),
                    if (request.approveSupported) ...[
                      const SizedBox(width: ThemeTokens.space2),
                      FilledButton(
                        onPressed: deciding
                            ? null
                            : () => controller.approve(request.requestId),
                        child: const Text('Approve once'),
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
    required this.outputGateway,
  });

  final HistoryItem item;
  final HistoryController historyController;
  final OutputGateway outputGateway;

  @override
  Widget build(BuildContext context) {
    final kind = switch (item.kind) {
      HistoryItemKind.user => ConversationEntryKind.user,
      HistoryItemKind.assistant => ConversationEntryKind.assistant,
      HistoryItemKind.activity ||
      HistoryItemKind.reasoning ||
      HistoryItemKind.unknown => ConversationEntryKind.activity,
    };
    final turn = historyController.turnForId(item.turnId);
    final durationLabel = turn?.formattedWorkDuration;
    final showWorkDivider =
        durationLabel != null &&
        historyController.isFirstNonUserItemInTurn(item);
    final expanded = historyController.selectedTurnId == item.turnId;
    return _ConversationEntryView(
      entry: ConversationEntry(
        id: item.id,
        kind: kind,
        text: item.text,
        completed: true,
        status: item.status,
      ),
      attachments: item.attachments,
      isReasoning: item.kind == HistoryItemKind.reasoning,
      isCommand: item.isCommand,
      leadingHeader: showWorkDivider
          ? _TurnWorkDivider(
              key: ValueKey('turn-work-${item.turnId}'),
              label: durationLabel,
              expanded: expanded,
              loading: expanded && historyController.loadingItems,
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
          : null,
      trailingAction: item.isCommand ? _commandOutputAction(context) : null,
    );
  }

  Widget? _commandOutputAction(BuildContext context) {
    final output = item.output;
    if (output != null && output.available && output.reference != null) {
      return TextButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) =>
              _OutputDialog(gateway: outputGateway, descriptor: output),
        ),
        icon: const Icon(Icons.terminal, size: 15),
        label: Text(
          output.truncated ? 'View stored output (truncated)' : 'View output',
        ),
      );
    }
    if (output != null && !output.available) {
      return Text(
        'Output unavailable',
        style: Theme.of(context).textTheme.labelSmall,
      );
    }
    if (item.outputDeferred) {
      return TextButton(
        onPressed: historyController.loadingItems
            ? null
            : () => historyController.loadDeferredOutput(item),
        child: const Text('Fetch output safely'),
      );
    }
    if (historyController.selectedTurnId != item.turnId) {
      return TextButton(
        onPressed: historyController.loadingItems
            ? null
            : () => historyController.loadTurnItems(item.turnId),
        child: const Text('Load turn details'),
      );
    }
    return null;
  }
}

class _TurnWorkDivider extends StatelessWidget {
  const _TurnWorkDivider({
    super.key,
    required this.label,
    required this.expanded,
    required this.loading,
    this.onTap,
  });

  final String label;
  final bool expanded;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ThemeTokens.space3),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, color: palette.border)),
          const SizedBox(width: ThemeTokens.space2),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 3),
                  if (loading)
                    SizedBox.square(
                      dimension: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: palette.textSecondary,
                      ),
                    )
                  else
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      size: 14,
                      color: palette.textSecondary,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: ThemeTokens.space2),
          Expanded(child: Divider(height: 1, color: palette.border)),
        ],
      ),
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
    final viewport = MediaQuery.sizeOf(context);
    final width = (viewport.width - 32).clamp(280, 820).toDouble();
    final height = (viewport.height - 32).clamp(320, 680).toDouble();
    return Dialog(
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
                  padding: const EdgeInsets.all(ThemeTokens.space3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Command output',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              chunk == null
                                  ? '${widget.descriptor.storedBytes} stored byte(s)'
                                  : 'Window at byte ${chunk.offset} of '
                                        '${widget.descriptor.storedBytes}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
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
                const Divider(height: 1),
                Expanded(
                  child: ColoredBox(
                    color: palette.codeSurface,
                    child: _controller.loading && chunk == null
                        ? const Center(child: CircularProgressIndicator())
                        : SelectionArea(
                            child: ListView.builder(
                              key: const ValueKey('output-window-list'),
                              itemExtent: 20,
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
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(ThemeTokens.space2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _controller.loading
                            ? null
                            : _controller.loadStart,
                        child: const Text('First'),
                      ),
                      TextButton(
                        onPressed: _controller.canLoadPrevious
                            ? _controller.loadPrevious
                            : null,
                        child: const Text('Previous'),
                      ),
                      TextButton(
                        onPressed: _controller.canLoadNext
                            ? _controller.loadNext
                            : null,
                        child: const Text('Next'),
                      ),
                      TextButton(
                        onPressed: _controller.loading
                            ? null
                            : _controller.loadTail,
                        child: const Text('Tail'),
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
          TextButton(
            onPressed: controller.loadOlderTurns,
            child: const Text('Load older turns'),
          ),
        if (controller.canReturnToNewest)
          TextButton(
            onPressed: controller.refresh,
            child: const Text('Return to newest'),
          ),
        if (controller.canLoadMoreItems)
          TextButton(
            onPressed: controller.loadMoreItems,
            child: const Text('Load more items'),
          ),
      ],
    );
  }
}
