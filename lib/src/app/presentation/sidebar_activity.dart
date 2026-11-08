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
                        child: CodexButton(
                          key: const ValueKey('new-thread-button'),
                          variant: CodexButtonVariant.secondary,
                          size: CodexButtonSize.md,
                          onPressed: controller.mutating ? null : _startThread,
                          icon: Icon(
                            Icons.edit_square,
                            size: 15,
                            color: palette.textSecondary,
                          ),
                          label: 'New thread',
                        ),
                      ),
                      const SizedBox(width: 4),
                      CodexIconButton(
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
                          controller.showArchived ? 'Archived' : 'Threads',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      CodexIconButton(
                        key: const ValueKey('thread-archive-toggle'),
                        tooltip: controller.showArchived
                            ? 'Show active threads'
                            : 'Show archived threads',
                        onPressed: controller.loading || controller.mutating
                            ? null
                            : () => controller.setShowArchived(
                                !controller.showArchived,
                              ),
                        icon: Icon(
                          controller.showArchived
                              ? Icons.inventory_2_rounded
                              : Icons.inventory_2_outlined,
                          size: 16,
                        ),
                      ),
                      CodexIconButton(
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
                      CodexIconButton(
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
                              : CodexIconButton(
                                  tooltip: 'Clear filter',
                                  onPressed: _searchController.clear,
                                  size: 24,
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
      height: OfficialCodexTheme.titlebarHeight,
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
            CodexIconButton(
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

    final showPinnedGroup = !controller.showArchived && query.isEmpty;
    final pinnedThreads = showPinnedGroup
        ? filteredThreads
              .where((thread) => controller.isPinned(thread.id))
              .toList(growable: false)
        : const <ThreadSummary>[];
    final unpinnedThreads = showPinnedGroup
        ? filteredThreads
              .where((thread) => !controller.isPinned(thread.id))
              .toList(growable: false)
        : filteredThreads;

    final projects = <String, List<ThreadSummary>>{};
    for (final thread in unpinnedThreads) {
      projects.putIfAbsent(thread.cwd, () => <ThreadSummary>[]).add(thread);
    }
    final rows = <Object>[];
    if (pinnedThreads.isNotEmpty) {
      rows.add(_PinnedHeading(count: pinnedThreads.length));
      rows.addAll(pinnedThreads);
    }
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
          return Center(
            child: CodexButton(
              variant: CodexButtonVariant.ghost,
              size: CodexButtonSize.sm,
              onPressed: controller.loadingMore ? null : controller.loadMore,
              loading: controller.loadingMore,
              label: 'Load more',
            ),
          );
        }
        final row = rows[index];
        if (row is _PinnedHeading) {
          return _PinnedHeadingRow(heading: row);
        }
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
          pinned: controller.isPinned(thread.id),
          archived: controller.showArchived,
          enabled: !controller.mutating,
          onSelect: () => controller.selectThread(thread.id),
          onResume: () => controller.resumeThread(thread.id),
          onTogglePin: () => controller.togglePinThread(thread.id),
          onRename: () => _renameThreadDialog(thread),
          onFork: () => controller.forkThread(
            ThreadForkOptions(threadId: thread.id, cwd: thread.cwd),
          ),
          onArchiveToggle: () {
            if (controller.showArchived) {
              unawaited(controller.unarchiveThread(thread.id));
            } else {
              unawaited(controller.archiveThread(thread.id));
            }
          },
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
          CodexIconButton(
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
          CodexButton(
            variant: CodexButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
            label: 'Cancel',
          ),
          CodexButton(
            variant: CodexButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(field.text),
            label: 'Use location',
          ),
        ],
      ),
    );
    field.dispose();
    if (next != null && next.trim().isNotEmpty && mounted) {
      setState(() => _workingDirectory = next.trim());
    }
  }

  Future<void> _renameThreadDialog(ThreadSummary thread) async {
    final next = await showDialog<String>(
      context: context,
      builder: (context) => _RenameThreadDialog(thread: thread),
    );
    if (next != null && mounted) {
      await widget.controller.renameThread(thread.id, next);
    }
  }
}

class _RenameThreadDialog extends StatefulWidget {
  const _RenameThreadDialog({required this.thread});

  final ThreadSummary thread;

  @override
  State<_RenameThreadDialog> createState() => _RenameThreadDialogState();
}

class _RenameThreadDialogState extends State<_RenameThreadDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.thread.name ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    return AlertDialog(
      title: const Text('Rename thread'),
      content: SizedBox(
        width: 420,
        child: TextField(
          key: const ValueKey('rename-thread-field'),
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Thread title',
            hintText: thread.preview.trim().isEmpty
                ? 'Untitled thread'
                : thread.preview.trim(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
      actions: [
        CodexButton(
          variant: CodexButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
          label: 'Cancel',
        ),
        CodexButton(
          key: const ValueKey('rename-thread-save-button'),
          variant: CodexButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(_controller.text),
          label: 'Save',
        ),
      ],
    );
  }
}

final class _PinnedHeading {
  const _PinnedHeading({required this.count});

  final int count;
}

class _PinnedHeadingRow extends StatelessWidget {
  const _PinnedHeadingRow({required this.heading});

  final _PinnedHeading heading;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return CodexSidebarRow(
      key: const ValueKey('pinned-threads-heading'),
      title: 'Pinned',
      leading: Icon(
        Icons.push_pin_outlined,
        size: 14,
        color: palette.textSecondary,
      ),
      trailingBuilder: (context, _) => Text(
        '${heading.count}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
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

class _ProjectHeadingRow extends StatelessWidget {
  const _ProjectHeadingRow({
    required this.heading,
    required this.onToggleCollapse,
    this.onNewThreadInProject,
  });

  final _ProjectHeading heading;
  final VoidCallback onToggleCollapse;
  final VoidCallback? onNewThreadInProject;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final leadingIcon = heading.collapsed
        ? Icons.keyboard_arrow_right_rounded
        : Icons.folder_outlined;

    return CodexSidebarRow(
      tooltip: heading.directory,
      title: _projectName(heading.directory),
      leading: Icon(leadingIcon, size: 15, color: palette.textSecondary),
      onTap: onToggleCollapse,
      trailingBuilder: (context, isHovered) {
        if (isHovered && onNewThreadInProject != null) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onNewThreadInProject,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.add_rounded,
                size: 15,
                color: palette.textSecondary,
              ),
            ),
          );
        } else if (heading.collapsed) {
          return Text(
            '${heading.count}',
            style: Theme.of(context).textTheme.labelSmall,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _ThreadRow extends StatefulWidget {
  const _ThreadRow({
    super.key,
    required this.thread,
    required this.selected,
    required this.pinned,
    required this.archived,
    required this.enabled,
    required this.onSelect,
    required this.onResume,
    required this.onTogglePin,
    required this.onRename,
    required this.onFork,
    required this.onArchiveToggle,
  });

  final ThreadSummary thread;
  final bool selected;
  final bool pinned;
  final bool archived;
  final bool enabled;
  final VoidCallback onSelect;
  final VoidCallback onResume;
  final VoidCallback onTogglePin;
  final VoidCallback onRename;
  final VoidCallback onFork;
  final VoidCallback onArchiveToggle;

  @override
  State<_ThreadRow> createState() => _ThreadRowState();
}

class _ThreadRowState extends State<_ThreadRow> {
  final _menuController = CodexPopoverController();

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final thread = widget.thread;
    final statusColor = switch (thread.status) {
      ThreadRuntimeStatus.active => palette.accent,
      ThreadRuntimeStatus.systemError => palette.danger,
      _ => null,
    };

    return CodexSidebarRow(
      containerKey: ValueKey('thread-row-${thread.id}'),
      title: thread.displayTitle,
      selected: widget.selected,
      onTap: widget.enabled ? widget.onSelect : null,
      padding: EdgeInsets.only(left: statusColor != null ? 8 : 12, right: 8),
      leading: statusColor != null
          ? Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            )
          : null,
      trailingBuilder: (context, isHovered) {
        if (isHovered || _menuController.isOpen) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (thread.status == ThreadRuntimeStatus.notLoaded)
                CodexIconButton(
                  tooltip: 'Resume thread',
                  onPressed: widget.enabled ? widget.onResume : null,
                  size: 24,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                ),
              CodexPopoverAnchor(
                controller: _menuController,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                width: 184,
                popoverBuilder: (context, close) => CodexMenu<String>(
                  items: [
                    CodexMenuItem(
                      value: 'pin',
                      label: widget.pinned ? 'Unpin thread' : 'Pin thread',
                      icon: Icon(
                        widget.pinned
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
                    CodexMenuItem(
                      value: 'archive',
                      label: widget.archived
                          ? 'Unarchive thread'
                          : 'Archive thread',
                      icon: Icon(
                        widget.archived
                            ? Icons.unarchive_outlined
                            : Icons.inventory_2_outlined,
                      ),
                    ),
                  ],
                  onSelected: (action) {
                    close();
                    switch (action) {
                      case 'pin':
                        widget.onTogglePin();
                      case 'rename':
                        widget.onRename();
                      case 'fork':
                        widget.onFork();
                      case 'archive':
                        widget.onArchiveToggle();
                    }
                  },
                ),
                child: CodexIconButton(
                  key: ValueKey('thread-menu-${thread.id}'),
                  tooltip: 'Thread actions',
                  onPressed: widget.enabled ? _menuController.toggle : null,
                  size: 24,
                  icon: const Icon(Icons.more_horiz_rounded, size: 15),
                ),
              ),
            ],
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.pinned) ...[
              Icon(Icons.push_pin_rounded, size: 12, color: palette.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              _shortTime(thread.updatedAt),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(fontSize: 11, color: palette.textMuted),
            ),
          ],
        );
      },
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
