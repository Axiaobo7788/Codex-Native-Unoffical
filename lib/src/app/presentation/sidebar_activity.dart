part of '../codex_native_app.dart';

class _ThreadPanel extends StatefulWidget {
  const _ThreadPanel({
    required this.controller,
    required this.settingsController,
    required this.runtimeController,
    required this.defaultWorkingDirectory,
    this.onToggleSidebar,
  });

  final ThreadListController controller;
  final ExecutionSettingsController settingsController;
  final RuntimeController runtimeController;
  final String defaultWorkingDirectory;
  final VoidCallback? onToggleSidebar;

  @override
  State<_ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends State<_ThreadPanel> {
  late String _workingDirectory;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final Set<String> _collapsedProjects = <String>{};
  var _showSearch = false;
  var _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _workingDirectory = widget.defaultWorkingDirectory;
    _searchController = TextEditingController()
      ..addListener(() {
        final next = _searchController.text.trim();
        if (next != _searchQuery && mounted) {
          setState(() => _searchQuery = next);
        }
      });
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    if (_showSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          if (!widget.controller.mutating) {
            unawaited(_startThread());
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
          if (!widget.controller.mutating) {
            unawaited(_startThread());
          }
        },
      },
      child: ColoredBox(
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
                  padding: const EdgeInsets.fromLTRB(8, 2, 6, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          key: const ValueKey('new-thread-button'),
                          onPressed: controller.mutating ? null : _startThread,
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            foregroundColor: palette.textPrimary,
                            backgroundColor: palette.surface.withValues(
                              alpha: 0.65,
                            ),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: palette.border),
                              borderRadius: BorderRadius.circular(
                                ThemeTokens.radiusSmall,
                              ),
                            ),
                          ),
                          icon: Icon(
                            Icons.edit_square,
                            size: 15,
                            color: palette.textSecondary,
                          ),
                          label: Text(
                            'New thread',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: palette.textPrimary,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        key: const ValueKey('thread-directory-button'),
                        tooltip: 'New thread location',
                        onPressed: controller.mutating
                            ? null
                            : _chooseDirectory,
                        icon: const Icon(
                          Icons.create_new_folder_outlined,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Threads',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('thread-search-toggle'),
                        tooltip: 'Filter threads',
                        onPressed: _toggleSearch,
                        icon: Icon(
                          _showSearch
                              ? Icons.filter_list_off_rounded
                              : Icons.search_rounded,
                          size: 16,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh threads',
                        onPressed: controller.loading || controller.mutating
                            ? null
                            : controller.refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                      ),
                    ],
                  ),
                ),
                if (_showSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape):
                            _toggleSearch,
                      },
                      child: TextField(
                        key: const ValueKey('thread-search-field'),
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Filter threads…',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 16,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 30,
                          ),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear filter',
                                  onPressed: _searchController.clear,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                  ),
                                ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                        ),
                      ),
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
      ),
    );
  }

  Widget _brandHeader(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: palette.textPrimary,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              Icons.terminal_rounded,
              size: 15,
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
          if (widget.onToggleSidebar != null)
            IconButton(
              key: const ValueKey('sidebar-collapse-button'),
              tooltip: 'Hide sidebar',
              onPressed: widget.onToggleSidebar,
              icon: const Icon(Icons.view_sidebar_outlined, size: 17),
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

    final query = _searchQuery.toLowerCase();
    final filteredThreads = query.isEmpty
        ? controller.threads
        : controller.threads
              .where((thread) {
                return thread.displayTitle.toLowerCase().contains(query) ||
                    _projectName(thread.cwd).toLowerCase().contains(query) ||
                    thread.cwd.toLowerCase().contains(query);
              })
              .toList(growable: false);

    if (filteredThreads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ThemeTokens.space4),
          child: Text(
            'No matching threads.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final projects = <String, List<ThreadSummary>>{};
    for (final thread in filteredThreads) {
      projects.putIfAbsent(thread.cwd, () => <ThreadSummary>[]).add(thread);
    }
    final rows = <Object>[];
    for (final project in projects.entries) {
      final collapsed =
          query.isEmpty && _collapsedProjects.contains(project.key);
      rows.add(
        _ProjectHeading(
          directory: project.key,
          count: project.value.length,
          collapsed: collapsed,
        ),
      );
      if (!collapsed) {
        rows.addAll(project.value);
      }
    }
    final hasFooter =
        query.isEmpty &&
        (controller.canLoadMore || controller.retentionLimitReached);
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
          return _ProjectHeadingRow(
            heading: row,
            onToggleCollapse: () {
              setState(() {
                if (!_collapsedProjects.remove(row.directory)) {
                  _collapsedProjects.add(row.directory);
                }
              });
            },
            onNewThreadInProject: controller.mutating
                ? null
                : () => _startThreadInDirectory(row.directory),
          );
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
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

  Future<void> _startThread() => _startThreadInDirectory(_workingDirectory);

  Future<void> _startThreadInDirectory(String directory) async {
    final cwd = directory.trim();
    if (cwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a working directory first.')),
      );
      return;
    }
    if (cwd != _workingDirectory && mounted) {
      setState(() => _workingDirectory = cwd);
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
  const _ProjectHeading({
    required this.directory,
    required this.count,
    required this.collapsed,
  });

  final String directory;
  final int count;
  final bool collapsed;
}

class _ProjectHeadingRow extends StatefulWidget {
  const _ProjectHeadingRow({
    required this.heading,
    required this.onToggleCollapse,
    this.onNewThreadInProject,
  });

  final _ProjectHeading heading;
  final VoidCallback onToggleCollapse;
  final VoidCallback? onNewThreadInProject;

  @override
  State<_ProjectHeadingRow> createState() => _ProjectHeadingRowState();
}

class _ProjectHeadingRowState extends State<_ProjectHeadingRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final heading = widget.heading;
    final leadingIcon = heading.collapsed
        ? Icons.keyboard_arrow_right_rounded
        : _hovered
        ? Icons.keyboard_arrow_down_rounded
        : Icons.folder_outlined;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: heading.directory,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
          onTap: widget.onToggleCollapse,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 9, 6, 4),
            child: Row(
              children: [
                Icon(leadingIcon, size: 15, color: palette.textSecondary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _projectName(heading.directory),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (_hovered && widget.onNewThreadInProject != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: widget.onNewThreadInProject,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: palette.textSecondary,
                      ),
                    ),
                  )
                else if (heading.collapsed)
                  Text(
                    '${heading.count}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
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
      ThreadRuntimeStatus.systemError => palette.danger,
      _ => null,
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
                padding: EdgeInsets.only(
                  left: statusColor != null ? 8 : 18,
                  right: 6,
                ),
                child: Row(
                  children: [
                    if (statusColor != null) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        widget.thread.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: widget.selected
                              ? palette.textPrimary
                              : palette.textPrimary.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_hovered &&
                        widget.thread.status == ThreadRuntimeStatus.notLoaded)
                      IconButton(
                        tooltip: 'Resume thread',
                        onPressed: widget.enabled ? widget.onResume : null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      )
                    else
                      Text(
                        _shortTime(widget.thread.updatedAt),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontSize: 11, color: palette.textMuted),
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
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) {
    return 'now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h';
  }
  final days = diff.inDays;
  if (days < 7) {
    return '${days}d';
  }
  if (days < 30) {
    return '${(days / 7).floor()}w';
  }
  if (days < 365) {
    return '${(days / 30).floor()}mo';
  }
  return '${(days / 365).floor()}y';
}
