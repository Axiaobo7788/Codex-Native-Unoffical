part of '../codex_native_app.dart';

class _ThreadPanel extends StatefulWidget {
  const _ThreadPanel({
    required this.controller,
    required this.settingsController,
    required this.runtimeController,
    required this.defaultWorkingDirectory,
  });

  final ThreadListController controller;
  final ExecutionSettingsController settingsController;
  final RuntimeController runtimeController;
  final String defaultWorkingDirectory;

  @override
  State<_ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends State<_ThreadPanel> {
  late String _workingDirectory;

  @override
  void initState() {
    super.initState();
    _workingDirectory = widget.defaultWorkingDirectory;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return ColoredBox(
      color: palette.sidebar,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _brandHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('new-thread-button'),
                        onPressed: controller.mutating ? null : _startThread,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New thread'),
                      ),
                    ),
                    const SizedBox(width: ThemeTokens.space1),
                    IconButton(
                      key: const ValueKey('thread-directory-button'),
                      tooltip: 'New thread location',
                      onPressed: controller.mutating ? null : _chooseDirectory,
                      icon: const Icon(Icons.folder_outlined, size: 18),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'THREADS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh threads',
                      onPressed: controller.loading || controller.mutating
                          ? null
                          : controller.refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                    ),
                  ],
                ),
              ),
              if (controller.errorMessage case final error?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: _InlineNotice(
                    icon: Icons.error_outline_rounded,
                    color: palette.danger,
                    text: error,
                  ),
                ),
              Expanded(child: _threadList(controller)),
              _sidebarFooter(context),
            ],
          );
        },
      ),
    );
  }

  Widget _brandHeader(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.textPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.terminal_rounded,
              size: 16,
              color: palette.canvas,
            ),
          ),
          const SizedBox(width: ThemeTokens.space2),
          Expanded(
            child: Text(
              'Codex Native',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _threadList(ThreadListController controller) {
    if (controller.loading && controller.threads.isEmpty) {
      return const _SidebarLoadingState();
    }
    if (controller.threads.isEmpty) {
      return const _SidebarEmptyState();
    }

    final projects = <String, List<ThreadSummary>>{};
    for (final thread in controller.threads) {
      projects.putIfAbsent(thread.cwd, () => <ThreadSummary>[]).add(thread);
    }
    final rows = <Object>[];
    for (final project in projects.entries) {
      rows
        ..add(_ProjectHeading(project.key))
        ..addAll(project.value);
    }
    final hasFooter =
        controller.canLoadMore || controller.retentionLimitReached;
    return ListView.builder(
      key: const ValueKey('thread-list'),
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      itemCount: rows.length + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          if (controller.retentionLimitReached) {
            return Padding(
              padding: const EdgeInsets.all(ThemeTokens.space3),
              child: Text(
                'Showing the newest ${controller.maxRetainedThreads} threads.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          return TextButton(
            onPressed: controller.loadingMore ? null : controller.loadMore,
            child: controller.loadingMore
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Load more'),
          );
        }
        final row = rows[index];
        if (row is _ProjectHeading) {
          return _ProjectHeadingRow(directory: row.directory);
        }
        final thread = row as ThreadSummary;
        return _ThreadRow(
          key: ValueKey(thread.id),
          thread: thread,
          selected: controller.selectedThread?.id == thread.id,
          enabled: !controller.mutating,
          onSelect: () => controller.selectThread(thread.id),
          onResume: () => controller.resumeThread(thread.id),
        );
      },
    );
  }

  Widget _sidebarFooter(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RuntimeStatusPill(controller: widget.runtimeController),
          ),
          const SizedBox(width: ThemeTokens.space1),
          IconButton(
            key: const ValueKey('remote-setup-button'),
            tooltip: 'Remote setup',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) =>
                  _RemoteSetupDialog(gateway: widget.runtimeController),
            ),
            icon: const Icon(Icons.devices_outlined, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _startThread() async {
    final cwd = _workingDirectory.trim();
    if (cwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a working directory first.')),
      );
      return;
    }
    await widget.controller.startThread(
      widget.settingsController.threadOptions(cwd),
    );
  }

  Future<void> _chooseDirectory() async {
    final field = TextEditingController(text: _workingDirectory);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New thread location'),
        content: SizedBox(
          width: 480,
          child: TextField(
            key: const ValueKey('thread-directory-field'),
            controller: field,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Working directory',
              hintText: '/path/to/project',
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(field.text),
            child: const Text('Use location'),
          ),
        ],
      ),
    );
    field.dispose();
    if (next != null && next.trim().isNotEmpty && mounted) {
      setState(() => _workingDirectory = next.trim());
    }
  }
}

final class _ProjectHeading {
  const _ProjectHeading(this.directory);

  final String directory;
}

class _ProjectHeadingRow extends StatelessWidget {
  const _ProjectHeadingRow({required this.directory});

  final String directory;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: directory,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 11, 8, 4),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _projectName(directory),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ThemeTokens.of(context).textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadRow extends StatefulWidget {
  const _ThreadRow({
    super.key,
    required this.thread,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    required this.onResume,
  });

  final ThreadSummary thread;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelect;
  final VoidCallback onResume;

  @override
  State<_ThreadRow> createState() => _ThreadRowState();
}

class _ThreadRowState extends State<_ThreadRow> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final background = widget.selected
        ? palette.selected
        : _hovered
        ? palette.hover
        : Colors.transparent;
    final statusColor = switch (widget.thread.status) {
      ThreadRuntimeStatus.active => palette.accent,
      ThreadRuntimeStatus.idle => palette.textMuted,
      _ => palette.warning,
    };
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onSelect();
              return null;
            },
          ),
        },
        child: AnimatedContainer(
          key: ValueKey('thread-row-${widget.thread.id}'),
          duration: const Duration(milliseconds: 100),
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: _focused ? palette.accent : Colors.transparent,
              width: _focused ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
              onTap: widget.enabled ? widget.onSelect : null,
              child: Padding(
                padding: const EdgeInsets.only(left: 9, right: 4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.thread.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_hovered || widget.selected)
                      IconButton(
                        tooltip: 'Resume thread',
                        onPressed: widget.enabled ? widget.onResume : null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 17),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          _shortTime(widget.thread.updatedAt),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarLoadingState extends StatelessWidget {
  const _SidebarLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 7,
      itemBuilder: (context, index) => Container(
        height: 34,
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          color: ThemeTokens.of(context).surfaceRaised,
          borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
        ),
      ),
    );
  }
}

class _SidebarEmptyState extends StatelessWidget {
  const _SidebarEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 24,
              color: ThemeTokens.of(context).textMuted,
            ),
            const SizedBox(height: ThemeTokens.space2),
            Text(
              'No threads yet',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: ThemeTokens.space1),
            Text(
              'Start a task in the current project.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _projectName(String directory) {
  final normalized = directory.replaceAll('\\', '/');
  final segments = normalized
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  return segments.isEmpty ? directory : segments.last;
}

String _shortTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
