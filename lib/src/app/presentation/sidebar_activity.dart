part of '../codex_native_app.dart';

class _ThreadPanel extends StatefulWidget {
  const _ThreadPanel({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.runtimeController,
    required this.defaultWorkingDirectory,
    this.onWorkingDirectoryChanged,
    this.userInputController,
    this.mcpOauthController,
    this.hasNavigationRail = false,
    this.onThreadSelected,
  });

  final ThreadListController controller;
  final ExecutionSettingsController settingsController;
  final RuntimeController runtimeController;
  final String defaultWorkingDirectory;
  final ValueChanged<String>? onWorkingDirectoryChanged;
  final UserInputController? userInputController;
  final McpOauthController? mcpOauthController;
  final bool hasNavigationRail;
  final VoidCallback? onThreadSelected;

  @override
  State<_ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends State<_ThreadPanel> {
  late String _workingDirectory;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final Set<String> _collapsedProjects = <String>{};
  final Set<String> _collapsedSections = <String>{};
  var _showSearch = false;
  var _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _workingDirectory = widget.defaultWorkingDirectory;
    _searchQuery = widget.controller.savedSearchTerm ?? '';
    _showSearch = _searchQuery.isNotEmpty;
    _searchController = TextEditingController(text: _searchQuery)
      ..addListener(() {
        final next = _searchController.text.trim();
        if (next != _searchQuery && mounted) {
          setState(() => _searchQuery = next);
        }
      });
    _searchFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _ThreadPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultWorkingDirectory != widget.defaultWorkingDirectory &&
        _workingDirectory == oldWidget.defaultWorkingDirectory) {
      _workingDirectory = widget.defaultWorkingDirectory;
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    if (_showSearch) {
      setState(() => _showSearch = false);
      _clearSearch();
      return;
    }
    _openSearch();
  }

  void _openSearch() {
    if (!_showSearch) {
      setState(() => _showSearch = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    if (widget.controller.savedSearchTerm != null) {
      unawaited(widget.controller.setSavedSearch(null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
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
        color: widget.hasNavigationRail && !theme.isDark
            ? OfficialCodexTheme.lightContextualSidebarBackground
            : palette.sidebar,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            final savedSearch = controller.savedSearchTerm;
            final offersSavedSearch =
                !widget.runtimeController.usesRemote &&
                controller.sectionScopeId == null;
            final canSubmitSavedSearch =
                offersSavedSearch &&
                _searchQuery.isNotEmpty &&
                _searchQuery.length <=
                    ThreadListController.maxSavedSearchLength &&
                _searchQuery != savedSearch &&
                !controller.catalogBusy;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _brandHeader(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: CodexSidebarRow(
                          key: const ValueKey('new-thread-button'),
                          title: widget.hasNavigationRail
                              ? 'New chat'
                              : 'New thread',
                          leading: const Icon(Icons.edit_square, size: 16),
                          onTap: controller.mutating ? null : _startThread,
                          trailingBuilder: (context, isHovered) => isHovered
                              ? Text(
                                  'Ctrl+N',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontSize: 11,
                                        color: palette.textMuted,
                                      ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      if (!widget.hasNavigationRail) ...[
                        const SizedBox(width: 2),
                        CodexIconButton(
                          key: const ValueKey('thread-directory-button'),
                          tooltip: 'New thread location',
                          size: 30,
                          onPressed: controller.mutating
                              ? null
                              : _chooseDirectory,
                          icon: const Icon(
                            Icons.create_new_folder_outlined,
                            size: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!widget.hasNavigationRail)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: CodexSidebarRow(
                      key: const ValueKey('ecosystem-button'),
                      title: 'Automations & Skills',
                      leading: const Icon(
                        Icons.auto_fix_high_outlined,
                        size: 16,
                      ),
                      onTap: _openEcosystem,
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    widget.hasNavigationRail ? 4 : 8,
                    8,
                    widget.hasNavigationRail ? 0 : 2,
                  ),
                  child: _ThreadCatalogHeader(
                    minHeight: widget.hasNavigationRail
                        ? OfficialCodexTheme.navRowHeight
                        : null,
                    revealActions:
                        widget.hasNavigationRail && !controller.showArchived,
                    title: Text(
                      controller.showArchived
                          ? 'Archived'
                          : widget.hasNavigationRail
                          ? 'Projects'
                          : 'Threads',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.textMuted,
                        fontSize: widget.hasNavigationRail ? 13.0 : 11.5,
                        height: widget.hasNavigationRail ? (18.0 / 13.0) : null,
                        fontWeight: FontWeight.w500,
                        letterSpacing: widget.hasNavigationRail ? 0.0 : 0.1,
                      ),
                    ),
                    actions: [
                      if (!controller.showArchived &&
                          controller.supportsThreadSections)
                        CodexIconButton(
                          key: const ValueKey('thread-section-create-button'),
                          tooltip: 'New section',
                          size: 26,
                          onPressed: controller.loading || controller.mutating
                              ? null
                              : _createSectionDialog,
                          icon: const Icon(Icons.bookmarks_outlined, size: 15),
                        ),
                      if (!widget.hasNavigationRail) _searchButton(),
                      CodexIconButton(
                        key: const ValueKey('thread-archive-toggle'),
                        tooltip: controller.showArchived
                            ? 'Show active threads'
                            : 'Show archived threads',
                        size: 26,
                        onPressed: controller.catalogBusy
                            ? null
                            : () => controller.setShowArchived(
                                !controller.showArchived,
                              ),
                        icon: Icon(
                          controller.showArchived
                              ? Icons.inventory_2_rounded
                              : Icons.inventory_2_outlined,
                          size: 15,
                        ),
                      ),
                      CodexIconButton(
                        tooltip: 'Refresh threads',
                        size: 26,
                        onPressed: controller.catalogBusy
                            ? null
                            : controller.refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                      ),
                    ],
                  ),
                ),
                if (controller.sectionScopeId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Row(
                      children: [
                        CodexIconButton(
                          key: const ValueKey('thread-section-scope-back'),
                          tooltip: 'Show all threads',
                          size: 26,
                          onPressed: controller.catalogBusy
                              ? null
                              : () => controller.setSectionScope(null),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                controller.scopedSection?.name ?? 'Section',
                                key: const ValueKey(
                                  'thread-section-scope-name',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (controller.scopedSection?.isBuiltInPinned ==
                                  true)
                                Text(
                                  'Saved in stock Pinned only',
                                  key: const ValueKey(
                                    'thread-section-scope-pinned-note',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: palette.textMuted,
                                        fontSize: 10.5,
                                      ),
                                ),
                            ],
                          ),
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
                        onEditingComplete: offersSavedSearch
                            ? () {
                                if (canSubmitSavedSearch) {
                                  unawaited(
                                    controller.setSavedSearch(_searchQuery),
                                  );
                                }
                              }
                            : null,
                        decoration: InputDecoration(
                          hintText: savedSearch == null
                              ? 'Filter loaded threads…'
                              : 'Search saved threads…',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 16,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 30,
                          ),
                          suffixIcon:
                              _searchQuery.isEmpty && savedSearch == null
                              ? null
                              : CodexIconButton(
                                  tooltip: 'Clear filter',
                                  onPressed: _clearSearch,
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
                if (_showSearch &&
                    offersSavedSearch &&
                    _searchQuery.isNotEmpty &&
                    _searchQuery != savedSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: CodexButton(
                        key: const ValueKey('thread-search-saved'),
                        variant: CodexButtonVariant.ghost,
                        size: CodexButtonSize.sm,
                        onPressed: canSubmitSavedSearch
                            ? () => controller.setSavedSearch(_searchQuery)
                            : null,
                        label: 'Search saved threads',
                      ),
                    ),
                  ),
                if (savedSearch != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Row(
                      children: [
                        CodexIconButton(
                          key: const ValueKey('thread-search-saved-back'),
                          tooltip: 'Back to loaded threads',
                          size: 26,
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Saved matches for “$savedSearch”',
                            key: const ValueKey('thread-search-saved-scope'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
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
                if (!widget.hasNavigationRail) _compactSidebarFooter(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _brandHeader(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    return Container(
      key: const ValueKey('codex-sidebar-header'),
      height: widget.hasNavigationRail
          ? OfficialCodexTheme.contextualSidebarHeaderHeight
          : OfficialCodexTheme.titlebarHeight,
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
      child: Row(
        children: [
          if (!widget.hasNavigationRail) ...[
            Icon(
              Icons.auto_awesome_mosaic_outlined,
              size: 17,
              color: theme.textPrimary,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              'Codex',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: widget.hasNavigationRail ? 18 : 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (widget.hasNavigationRail) _searchButton(),
        ],
      ),
    );
  }

  Widget _searchButton() => CodexIconButton(
    key: const ValueKey('thread-search-toggle'),
    tooltip: 'Filter threads',
    size: 26,
    onPressed: _toggleSearch,
    icon: Icon(
      _showSearch ? Icons.filter_list_off_rounded : Icons.search_rounded,
      size: 15,
    ),
  );

  Widget _threadList(ThreadListController controller) {
    final scoped = controller.sectionScopeId != null;
    final savedSearch = controller.savedSearchTerm;
    final flat = scoped || savedSearch != null;
    final hasPersistedSections =
        !flat && !controller.showArchived && controller.sections.isNotEmpty;
    if (controller.loading &&
        controller.threads.isEmpty &&
        !hasPersistedSections) {
      return const _SidebarLoadingState();
    }
    if (controller.threads.isEmpty &&
        !hasPersistedSections &&
        !controller.canLoadMore) {
      if (savedSearch != null) {
        return Center(
          child: Text(
            controller.errorMessage == null
                ? 'No saved threads match.'
                : 'Unable to search saved threads.',
          ),
        );
      }
      return scoped
          ? Center(
              child: Text(
                controller.errorMessage == null
                    ? 'No threads in this section.'
                    : 'Unable to load this section.',
              ),
            )
          : const _SidebarEmptyState();
    }

    final query = savedSearch == null ? _searchQuery.toLowerCase() : '';
    final filteredThreads = query.isEmpty
        ? controller.threads
        : controller.threads
              .where((thread) {
                final branch = thread.gitInfo?.branch?.toLowerCase() ?? '';
                final goalObjective =
                    thread.goal?.objective.toLowerCase() ?? '';
                final sectionName = thread.section?.name.toLowerCase() ?? '';
                return thread.displayTitle.toLowerCase().contains(query) ||
                    _projectName(thread.cwd).toLowerCase().contains(query) ||
                    thread.cwd.toLowerCase().contains(query) ||
                    branch.contains(query) ||
                    goalObjective.contains(query) ||
                    sectionName.contains(query);
              })
              .toList(growable: false);

    final matchingEmptySections =
        !flat && !controller.showArchived && query.isNotEmpty
        ? controller.sections
              .where((section) => section.name.toLowerCase().contains(query))
              .toList(growable: false)
        : const <ThreadSection>[];

    if (filteredThreads.isEmpty &&
        !(flat && controller.canLoadMore) &&
        (query.isNotEmpty
            ? matchingEmptySections.isEmpty
            : !hasPersistedSections)) {
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

    final builtInPinnedSection = !controller.showArchived
        ? controller.builtInPinnedSection
        : null;
    final showPinnedGroup = !flat && !controller.showArchived;
    final savedPinnedThreads = <ThreadSummary>[];
    final sessionPinnedThreads = <ThreadSummary>[];
    final unpinnedThreads = <ThreadSummary>[];
    if (showPinnedGroup) {
      for (final thread in filteredThreads) {
        if (thread.isPersistedPinned) {
          savedPinnedThreads.add(thread);
        } else if (controller.isSessionPinnedThread(thread)) {
          sessionPinnedThreads.add(thread);
        } else {
          unpinnedThreads.add(thread);
        }
      }
    } else {
      unpinnedThreads.addAll(filteredThreads);
    }
    final pinnedThreads = showPinnedGroup
        ? <ThreadSummary>[...savedPinnedThreads, ...sessionPinnedThreads]
        : const <ThreadSummary>[];

    final allSections = <ThreadSection>[];
    final seenSectionIds = <String>{};
    if (!controller.showArchived) {
      for (final section in controller.sections) {
        if (seenSectionIds.add(section.id)) {
          allSections.add(section);
        }
      }
      for (final thread in filteredThreads) {
        if (thread.section case final section?
            when seenSectionIds.add(section.id)) {
          allSections.add(section);
        }
      }
    }
    final customSections = allSections
        .where((section) => !section.isBuiltInPinned)
        .toList(growable: false);

    final sectionThreadsById = <String, List<ThreadSummary>>{};
    final unsectionedThreads = <ThreadSummary>[];
    if (!controller.showArchived) {
      for (final thread in unpinnedThreads) {
        final section = thread.section;
        if (section != null && !section.isBuiltInPinned) {
          sectionThreadsById
              .putIfAbsent(section.id, () => <ThreadSummary>[])
              .add(thread);
        } else {
          unsectionedThreads.add(thread);
        }
      }
    } else {
      unsectionedThreads.addAll(unpinnedThreads);
    }

    final projects = <String, List<ThreadSummary>>{};
    for (final thread in unsectionedThreads) {
      projects.putIfAbsent(thread.cwd, () => <ThreadSummary>[]).add(thread);
    }
    final rows = <Object>[];
    if (flat) {
      rows.addAll(filteredThreads);
    } else {
      final showPinnedHeading =
          pinnedThreads.isNotEmpty ||
          (!widget.hasNavigationRail &&
              builtInPinnedSection != null &&
              (query.isEmpty ||
                  builtInPinnedSection.name.toLowerCase().contains(query)));
      if (showPinnedHeading) {
        final pinnedCollapsed =
            query.isEmpty &&
            _collapsedSections.contains(kBuiltInPinnedThreadSectionId);
        rows.add(
          _PinnedHeading(
            section: builtInPinnedSection,
            savedCount: savedPinnedThreads.length,
            sessionCount: sessionPinnedThreads.length,
            collapsed: pinnedCollapsed,
          ),
        );
        if (!pinnedCollapsed) {
          rows.addAll(pinnedThreads);
        }
      }
      for (final section in customSections) {
        final sectionThreads =
            sectionThreadsById[section.id] ?? const <ThreadSummary>[];
        if (query.isNotEmpty &&
            sectionThreads.isEmpty &&
            !section.name.toLowerCase().contains(query)) {
          continue;
        }
        final collapsed =
            query.isEmpty && _collapsedSections.contains(section.id);
        rows.add(
          _SectionHeading(
            section: section,
            count: sectionThreads.length,
            collapsed: collapsed,
          ),
        );
        if (!collapsed) {
          rows.addAll(sectionThreads);
        }
      }
      for (final project in projects.entries) {
        final collapsed =
            query.isEmpty && _collapsedProjects.contains(project.key);
        rows.add(
          _ProjectHeading(
            directory: project.key,
            count: project.value.length,
            collapsed: collapsed,
            hasNavigationRail: widget.hasNavigationRail,
            hasError: project.value.any(
              (thread) => thread.status == ThreadRuntimeStatus.systemError,
            ),
            hasRunning: project.value.any(
              (thread) => thread.status == ThreadRuntimeStatus.active,
            ),
            hasUnread: project.value.any(
              (thread) => thread.readReceipt?.unread ?? false,
            ),
          ),
        );
        if (!collapsed) {
          rows.addAll(project.value);
        }
      }
    }
    final hasFooter =
        (flat || query.isEmpty) &&
        (controller.canLoadMore || controller.retentionLimitReached);
    return ListView.builder(
      key: ValueKey(switch (savedSearch) {
        final term? => 'thread-list-saved-search-$term',
        null when scoped => 'thread-list-section-${controller.sectionScopeId}',
        null => 'thread-list',
      }),
      padding: EdgeInsets.fromLTRB(
        widget.hasNavigationRail ? 8 : 6,
        0,
        widget.hasNavigationRail ? 8 : 6,
        8,
      ),
      itemCount: rows.length + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          if (controller.retentionLimitReached) {
            return Padding(
              padding: const EdgeInsets.all(ThemeTokens.space3),
              child: Text(
                savedSearch != null
                    ? 'Showing the first ${controller.maxRetainedThreads} matches.'
                    : scoped
                    ? 'Showing the first ${controller.maxRetainedThreads} threads in this section.'
                    : 'Showing the newest ${controller.maxRetainedThreads} threads.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          return Center(
            child: CodexButton(
              variant: CodexButtonVariant.ghost,
              size: CodexButtonSize.sm,
              onPressed: controller.catalogBusy ? null : controller.loadMore,
              loading: controller.loadingMore,
              label: 'Load more',
            ),
          );
        }
        final row = rows[index];
        if (row is _PinnedHeading) {
          final section = row.section;
          return _PinnedHeadingRow(
            heading: row,
            enabled:
                !controller.catalogBusy && controller.supportsThreadSections,
            onOpenSection:
                section != null &&
                    controller.sections.any(
                      (candidate) => candidate.id == section.id,
                    )
                ? () => controller.setSectionScope(section.id)
                : null,
            onToggleCollapse: () {
              setState(() {
                if (!_collapsedSections.remove(kBuiltInPinnedThreadSectionId)) {
                  _collapsedSections.add(kBuiltInPinnedThreadSectionId);
                }
              });
            },
          );
        }
        if (row is _SectionHeading) {
          return _SectionHeadingRow(
            heading: row,
            enabled:
                !controller.catalogBusy && controller.supportsThreadSections,
            onOpenSection:
                controller.sections.any(
                  (section) => section.id == row.section.id,
                )
                ? () => controller.setSectionScope(row.section.id)
                : null,
            onToggleCollapse: () {
              setState(() {
                if (!_collapsedSections.remove(row.section.id)) {
                  _collapsedSections.add(row.section.id);
                }
              });
            },
            onRenameSection:
                controller.supportsThreadSections &&
                    !row.section.isBuiltInPinned
                ? () => _renameSectionDialog(row.section)
                : null,
            onDeleteSection:
                controller.supportsThreadSections &&
                    !row.section.isBuiltInPinned
                ? () => unawaited(controller.deleteSection(row.section.id))
                : null,
          );
        }
        if (row is _ProjectHeading) {
          return _ProjectHeadingRow(
            key: ValueKey('project-heading-${row.directory}'),
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
            onRevealDirectory:
                widget.hasNavigationRail &&
                    !widget.runtimeController.usesRemote &&
                    (Platform.isLinux ||
                        Platform.isMacOS ||
                        Platform.isWindows) &&
                    Directory(row.directory).isAbsolute
                ? () => _revealProjectDirectory(row.directory)
                : null,
          );
        }
        final thread = row as ThreadSummary;
        final receipt = thread.readReceipt;
        final selected = controller.selectedThread?.id == thread.id;
        return _ThreadRow(
          key: ValueKey(thread.id),
          thread: thread,
          selected: selected,
          hasNavigationRail: widget.hasNavigationRail,
          showTimestamp:
              !widget.hasNavigationRail || flat || controller.showArchived,
          showGoalBadge:
              !widget.hasNavigationRail ||
              !selected ||
              thread.goal?.status == ThreadGoalStatus.complete,
          pinned: controller.isPinnedThread(thread),
          persistedPinned: thread.isPersistedPinned,
          sessionPinned: controller.isSessionPinnedThread(thread),
          pinActionLabel: controller.pinActionLabelForThread(thread),
          canTogglePin: controller.canTogglePinForThread(thread),
          archived: controller.showArchived,
          enabled: !controller.mutating,
          supportsSections: controller.supportsThreadSections,
          sections: allSections,
          onSelect: () => unawaited(_selectThread(thread.id)),
          onResume: () => unawaited(_resumeThread(thread.id)),
          onTogglePin: () => unawaited(controller.togglePinThread(thread.id)),
          onToggleReadReceipt:
              receipt != null && controller.canChangeReadReceipt(thread)
              ? () =>
                    unawaited(controller.toggleReadReceipt(thread.id, receipt))
              : null,
          onRename: () => _renameThreadDialog(thread),
          onManageGoal: controller.canManageGoal(thread.id)
              ? () => unawaited(_manageThreadGoal(thread))
              : null,
          onFork: () => controller.forkThread(
            ThreadForkOptions(threadId: thread.id, cwd: thread.cwd),
          ),
          onMoveToSection: (sectionId) => unawaited(
            controller.moveThreadToSection(
              threadId: thread.id,
              sectionId: sectionId,
            ),
          ),
          onMoveToNewSection: () => _moveThreadToNewSectionDialog(thread),
          onArchiveToggle: () {
            if (controller.showArchived) {
              unawaited(controller.unarchiveThread(thread.id));
            } else {
              unawaited(controller.archiveThread(thread.id));
            }
          },
          onDelete: () => unawaited(controller.deleteThread(thread.id)),
        );
      },
    );
  }

  Widget _compactSidebarFooter(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.hairlineBorder,
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RuntimeStatusPill(controller: widget.runtimeController),
          ),
          const SizedBox(width: ThemeTokens.space1),
          CodexIconButton(
            key: const ValueKey('remote-setup-button'),
            tooltip: 'Remote & host settings',
            size: 28,
            onPressed: _openRemoteSetup,
            icon: const Icon(Icons.devices_outlined, size: 17),
          ),
        ],
      ),
    );
  }

  Future<void> _openEcosystem() => showDialog<void>(
    context: context,
    builder: (context) => _EcosystemDialog(
      mcpOauthController: widget.mcpOauthController,
      gateway: widget.runtimeController,
      threadController: widget.controller,
      userInputController: widget.userInputController,
      cwd: widget.controller.selectedThread?.cwd ?? _workingDirectory,
      threadId: widget.controller.selectedThread?.id,
    ),
  );

  void _openRemoteSetup() => showDialog<void>(
    context: context,
    builder: (context) => _RemoteSetupDialog(
      gateway: widget.runtimeController,
      ecosystemGateway: widget.runtimeController,
    ),
  );

  Future<void> _selectThread(String threadId) async {
    final selected = await widget.controller.selectThread(threadId);
    if (selected != null &&
        mounted &&
        widget.controller.selectedThread?.id == selected.id) {
      widget.onThreadSelected?.call();
    }
  }

  Future<void> _resumeThread(String threadId) async {
    final resumed = await widget.controller.resumeThread(threadId);
    if (resumed != null &&
        mounted &&
        widget.controller.selectedThread?.id == resumed.id) {
      widget.onThreadSelected?.call();
    }
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
      widget.onWorkingDirectoryChanged?.call(cwd);
    }
    try {
      await widget.controller.startThread(
        widget.settingsController.threadOptions(cwd),
      );
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message.toString())));
      }
    }
  }

  Future<void> _revealProjectDirectory(String path) async {
    try {
      if (await Directory(path).exists() &&
          await launchUrl(
            Uri.directory(path, windows: Platform.isWindows),
            mode: LaunchMode.externalApplication,
          )) {
        return;
      }
    } on Exception {
      // An unavailable directory or platform handler uses the same UI error.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the project folder.')),
      );
    }
  }

  Future<void> _chooseDirectory() async {
    final field = TextEditingController(text: _workingDirectory);
    final next = await showDialog<String>(
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
        );
      },
    );
    field.dispose();
    if (next != null && next.trim().isNotEmpty && mounted) {
      final normalized = next.trim();
      setState(() => _workingDirectory = normalized);
      widget.onWorkingDirectoryChanged?.call(normalized);
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

  Future<void> _createSectionDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _ThreadSectionNameDialog(
        title: 'New section',
        confirmLabel: 'Create',
      ),
    );
    if (name != null && name.trim().isNotEmpty && mounted) {
      await widget.controller.createSection(name);
    }
  }

  Future<void> _manageThreadGoal(ThreadSummary thread) =>
      _showThreadGoalDialog(context, widget.controller, thread.id);

  Future<void> _renameSectionDialog(ThreadSection section) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _ThreadSectionNameDialog(
        title: 'Rename section',
        initialName: section.name,
        confirmLabel: 'Save',
      ),
    );
    if (name != null && name.trim().isNotEmpty && mounted) {
      await widget.controller.renameSection(section.id, name);
    }
  }

  Future<void> _moveThreadToNewSectionDialog(ThreadSummary thread) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _ThreadSectionNameDialog(
        title: 'Move to new section',
        confirmLabel: 'Create & move',
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) {
      return;
    }
    final created = await widget.controller.createSection(name);
    if (created != null && mounted) {
      await widget.controller.moveThreadToSection(
        threadId: thread.id,
        sectionId: created.id,
      );
    }
  }
}

Future<void> _showThreadGoalDialog(
  BuildContext context,
  ThreadListController controller,
  String threadId,
) async {
  bool canContinue() => controller.canManageGoal(threadId);

  final loaded = await controller.loadGoal(threadId);
  if (!context.mounted || !canContinue() || loaded == null) return;

  final change = await showDialog<_GoalDialogResult>(
    context: context,
    builder: (context) => _ThreadGoalDialog(goal: loaded.goal),
  );
  if (!context.mounted || !canContinue() || change == null) return;

  await _applyThreadGoalChange(
    context,
    controller,
    threadId,
    loaded.goal,
    change,
    canContinue: canContinue,
  );
}

Future<void> _applyThreadGoalChange(
  BuildContext context,
  ThreadListController controller,
  String threadId,
  ThreadGoal? expectedGoal,
  _GoalDialogResult change, {
  required bool Function() canContinue,
}) async {
  if (!canContinue() || controller.mutating) return;
  if (change.clear) {
    final confirmed = await _confirmDesktopAction(
      context,
      title: 'Clear this thread’s goal?',
      message: 'Codex will stop using this saved objective for future turns.',
      confirmLabel: 'Clear goal',
    );
    if (!confirmed) return;
  }
  if (!context.mounted || !canContinue() || controller.mutating) return;
  if (!identical(controller.goalForThread(threadId), expectedGoal)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The goal changed. Open it again to continue.'),
      ),
    );
    return;
  }
  if (change.clear) {
    await controller.clearGoal(threadId);
  } else {
    await controller.saveGoal(
      threadId,
      objective: change.objective,
      status: change.status,
    );
  }
}

typedef _GoalDialogResult = ({
  String? objective,
  ThreadGoalStatus? status,
  bool clear,
});

class _ThreadCatalogHeader extends StatefulWidget {
  const _ThreadCatalogHeader({
    this.minHeight,
    required this.revealActions,
    required this.title,
    required this.actions,
  });

  final double? minHeight;
  final bool revealActions;
  final Widget title;
  final List<Widget> actions;

  @override
  State<_ThreadCatalogHeader> createState() => _ThreadCatalogHeaderState();
}

class _ThreadCatalogHeaderState extends State<_ThreadCatalogHeader> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.actions,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.minHeight ?? 0),
          child: Row(
            children: [
              Expanded(child: widget.title),
              if (widget.revealActions)
                Opacity(
                  key: const ValueKey('desktop-project-header-actions'),
                  opacity: _hovered || _focused ? 1 : 0,
                  alwaysIncludeSemantics: true,
                  child: actions,
                )
              else
                actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadGoalDialog extends StatefulWidget {
  const _ThreadGoalDialog({required this.goal});

  final ThreadGoal? goal;

  @override
  State<_ThreadGoalDialog> createState() => _ThreadGoalDialogState();
}

class _ThreadGoalDialogState extends State<_ThreadGoalDialog> {
  late final _objective = TextEditingController(text: widget.goal?.objective);

  @override
  void dispose() {
    _objective.dispose();
    super.dispose();
  }

  void _submit({
    String? objective,
    ThreadGoalStatus? status,
    bool clear = false,
  }) {
    Navigator.of(context)
        .pop((objective: objective, status: status, clear: clear));
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final goal = widget.goal;
    final objective = _objective.text.trim();
    final canSave =
        objective.isNotEmpty &&
        objective.length <= ThreadGoal.maxObjectiveLength &&
        objective != goal?.objective;
    return AlertDialog(
      backgroundColor: theme.modalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OfficialCodexTheme.popoverRadius),
        side: BorderSide(
          color: theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      scrollable: true,
      title: Text(goal == null ? 'New goal' : 'Thread goal'),
      content: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(switch (goal?.status) {
              null =>
                'Create a paused goal, then resume it when you are ready.',
              ThreadGoalStatus.active =>
                'Active. Codex may continue this goal across turns.',
              ThreadGoalStatus.paused =>
                'Paused. Resuming allows Codex to continue across turns.',
              final status => 'Status: ${status.name}',
            }),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('thread-goal-objective'),
              controller: _objective,
              minLines: 2,
              maxLines: 4,
              maxLength: ThreadGoal.maxObjectiveLength,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Objective'),
            ),
            if (goal != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (goal.status == ThreadGoalStatus.active)
                    CodexButton(
                      label: 'Pause goal',
                      variant: CodexButtonVariant.secondary,
                      onPressed: () => _submit(status: ThreadGoalStatus.paused),
                    ),
                  if (goal.status == ThreadGoalStatus.paused)
                    CodexButton(
                      label: 'Resume goal',
                      variant: CodexButtonVariant.secondary,
                      onPressed: () => _submit(status: ThreadGoalStatus.active),
                    ),
                  CodexButton(
                    label: 'Clear goal…',
                    variant: CodexButtonVariant.ghost,
                    onPressed: () => _submit(clear: true),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        CodexButton(
          label: 'Cancel',
          variant: CodexButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        CodexButton(
          label: goal == null ? 'Create paused goal' : 'Save objective',
          variant: CodexButtonVariant.primary,
          onPressed: canSave
              ? () => _submit(
                  objective: objective,
                  status: goal == null ? ThreadGoalStatus.paused : null,
                )
              : null,
        ),
      ],
    );
  }
}

class _ThreadSectionNameDialog extends StatefulWidget {
  const _ThreadSectionNameDialog({
    required this.title,
    required this.confirmLabel,
    this.initialName = '',
  });

  final String title;
  final String confirmLabel;
  final String initialName;

  @override
  State<_ThreadSectionNameDialog> createState() =>
      _ThreadSectionNameDialogState();
}

class _ThreadSectionNameDialogState extends State<_ThreadSectionNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: TextField(
          key: const ValueKey('thread-section-name-field'),
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Section name',
            hintText: 'e.g. Priority tasks',
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
          key: const ValueKey('thread-section-save-button'),
          variant: CodexButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(_controller.text),
          label: widget.confirmLabel,
        ),
      ],
    );
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
  const _PinnedHeading({
    required this.section,
    required this.savedCount,
    required this.sessionCount,
    required this.collapsed,
  });

  final ThreadSection? section;
  final int savedCount;
  final int sessionCount;
  final bool collapsed;

  int get count => savedCount + sessionCount;
}

class _PinnedHeadingRow extends StatefulWidget {
  const _PinnedHeadingRow({
    required this.heading,
    required this.enabled,
    required this.onToggleCollapse,
    this.onOpenSection,
  });

  final _PinnedHeading heading;
  final bool enabled;
  final VoidCallback onToggleCollapse;
  final VoidCallback? onOpenSection;

  @override
  State<_PinnedHeadingRow> createState() => _PinnedHeadingRowState();
}

class _PinnedHeadingRowState extends State<_PinnedHeadingRow> {
  final _menuController = CodexPopoverController();

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  String _summaryLabel() => '${widget.heading.count} loaded';

  String _tooltipSummary() {
    final heading = widget.heading;
    if (heading.section == null) {
      return '${heading.sessionCount} loaded session pins';
    }
    return '${heading.savedCount} loaded saved · ${heading.sessionCount} session';
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final section = widget.heading.section;
    final canBrowse = widget.enabled && widget.onOpenSection != null;
    final summary = _summaryLabel();
    final title = section?.name ?? 'Pinned';
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: CodexSidebarRow(
        key: const ValueKey('pinned-threads-heading'),
        containerKey: section != null
            ? ValueKey('thread-section-heading-${section.id}')
            : null,
        height: 32.0,
        tooltip: '$title · ${_tooltipSummary()}',
        title: title,
        leading: Icon(
          widget.heading.collapsed
              ? Icons.push_pin_outlined
              : Icons.push_pin_rounded,
          size: 14,
          color: palette.textSecondary,
        ),
        onTap: widget.onToggleCollapse,
        trailingBuilder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(summary, style: Theme.of(context).textTheme.labelSmall),
            if (canBrowse && section != null) ...[
              const SizedBox(width: 2),
              CodexPopoverAnchor(
                controller: _menuController,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                width: 216,
                popoverBuilder: (context, close) => CodexMenu<String>(
                  items: const [
                    CodexMenuItem(
                      value: 'open',
                      label: 'Browse saved pins',
                      icon: Icon(Icons.list_rounded),
                    ),
                  ],
                  onSelected: (action) {
                    close();
                    if (action == 'open') {
                      widget.onOpenSection?.call();
                    }
                  },
                ),
                child: CodexIconButton(
                  key: ValueKey('thread-section-menu-${section.id}'),
                  tooltip: 'Pinned section actions',
                  onPressed: _menuController.toggle,
                  size: 22,
                  icon: const Icon(Icons.more_horiz_rounded, size: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _SectionHeading {
  const _SectionHeading({
    required this.section,
    required this.count,
    required this.collapsed,
  });

  final ThreadSection section;
  final int count;
  final bool collapsed;
}

class _SectionHeadingRow extends StatefulWidget {
  const _SectionHeadingRow({
    required this.heading,
    required this.enabled,
    required this.onToggleCollapse,
    required this.onOpenSection,
    this.onRenameSection,
    this.onDeleteSection,
  });

  final _SectionHeading heading;
  final bool enabled;
  final VoidCallback onToggleCollapse;
  final VoidCallback? onOpenSection;
  final VoidCallback? onRenameSection;
  final VoidCallback? onDeleteSection;

  @override
  State<_SectionHeadingRow> createState() => _SectionHeadingRowState();
}

class _SectionHeadingRowState extends State<_SectionHeadingRow> {
  final _menuController = CodexPopoverController();

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final section = widget.heading.section;
    final leadingIcon = widget.heading.collapsed
        ? Icons.label_outline_rounded
        : Icons.label_rounded;
    final canShowMenu =
        widget.enabled &&
        (widget.onOpenSection != null ||
            widget.onRenameSection != null ||
            widget.onDeleteSection != null);

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: CodexSidebarRow(
        containerKey: ValueKey('thread-section-heading-${section.id}'),
        height: 32.0,
        tooltip: '${section.name} · ${widget.heading.count} loaded threads',
        title: section.name,
        leading: Icon(leadingIcon, size: 15, color: palette.textSecondary),
        onTap: widget.onToggleCollapse,
        trailingBuilder: (context, isHovered) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.heading.count} loaded',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (canShowMenu) ...[
                const SizedBox(width: 2),
                CodexPopoverAnchor(
                  controller: _menuController,
                  targetAnchor: Alignment.bottomRight,
                  followerAnchor: Alignment.topRight,
                  width: 216,
                  popoverBuilder: (context, close) => CodexMenu<String>(
                    items: [
                      if (widget.onOpenSection != null)
                        CodexMenuItem(
                          value: 'open',
                          label: section.isBuiltInPinned
                              ? 'Browse saved pins'
                              : 'Browse section',
                          icon: const Icon(Icons.list_rounded),
                        ),
                      if (widget.onRenameSection != null)
                        const CodexMenuItem(
                          value: 'rename',
                          label: 'Rename section',
                          icon: Icon(Icons.drive_file_rename_outline_rounded),
                        ),
                      if (widget.onDeleteSection != null)
                        const CodexMenuItem(
                          value: 'delete',
                          label: 'Delete section',
                          icon: Icon(Icons.delete_outline_rounded),
                        ),
                    ],
                    onSelected: (action) {
                      close();
                      switch (action) {
                        case 'open':
                          widget.onOpenSection?.call();
                        case 'rename':
                          widget.onRenameSection?.call();
                        case 'delete':
                          widget.onDeleteSection?.call();
                      }
                    },
                  ),
                  child: CodexIconButton(
                    key: ValueKey('thread-section-menu-${section.id}'),
                    tooltip: 'Section actions',
                    onPressed: _menuController.toggle,
                    size: 22,
                    icon: const Icon(Icons.more_horiz_rounded, size: 14),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

final class _ProjectHeading {
  const _ProjectHeading({
    required this.directory,
    required this.count,
    required this.collapsed,
    this.hasNavigationRail = false,
    this.hasError = false,
    this.hasRunning = false,
    this.hasUnread = false,
  });

  final String directory;
  final int count;
  final bool collapsed;
  final bool hasNavigationRail;
  final bool hasError;
  final bool hasRunning;
  final bool hasUnread;
}

class _ProjectHeadingRow extends StatefulWidget {
  const _ProjectHeadingRow({
    super.key,
    required this.heading,
    required this.onToggleCollapse,
    this.onNewThreadInProject,
    this.onRevealDirectory,
  });

  final _ProjectHeading heading;
  final VoidCallback onToggleCollapse;
  final VoidCallback? onNewThreadInProject;
  final VoidCallback? onRevealDirectory;

  @override
  State<_ProjectHeadingRow> createState() => _ProjectHeadingRowState();
}

class _ProjectHeadingRowState extends State<_ProjectHeadingRow> {
  final _menuController = CodexPopoverController();
  var _focusWithin = false;

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  Widget? _buildCollapsedIndicator(
    BuildContext context,
    CodexPalette palette,
    _ProjectHeading heading,
  ) {
    if (!heading.hasNavigationRail) {
      return Text(
        '${heading.count}',
        style: Theme.of(context).textTheme.labelSmall,
      );
    }
    if (heading.hasError) {
      return SizedBox.square(
        dimension: 16,
        child: Center(
          child: Semantics(
            label: 'Project has thread with error',
            child: Container(
              key: ValueKey('project-error-${heading.directory}'),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: palette.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }
    if (heading.hasRunning) {
      return SizedBox.square(
        key: ValueKey('project-running-${heading.directory}'),
        dimension: 16,
        child: CircularProgressIndicator(
          strokeWidth: 1.7,
          color: palette.textMuted,
          semanticsLabel: 'Project has running thread',
        ),
      );
    }
    if (heading.hasUnread) {
      return SizedBox.square(
        dimension: 16,
        child: Center(
          child: Semantics(
            label: 'Project has unread thread',
            child: Container(
              key: ValueKey('project-unread-${heading.directory}'),
              width: OfficialCodexTheme.sidebarUnreadIndicatorSize,
              height: OfficialCodexTheme.sidebarUnreadIndicatorSize,
              decoration: const BoxDecoration(
                color: OfficialCodexTheme.sidebarUnreadIndicatorColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final heading = widget.heading;
    final palette = ThemeTokens.of(context);
    final leadingIcon = heading.collapsed
        ? Icons.folder_outlined
        : Icons.folder_open_outlined;
    final reveal = widget.onRevealDirectory;
    final newThread = widget.onNewThreadInProject;
    final collapsedIndicator = _buildCollapsedIndicator(
      context,
      palette,
      heading,
    );

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (focused) => setState(() => _focusWithin = focused),
        child: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(0),
            child: ListenableBuilder(
              listenable: _menuController,
              builder: (context, _) => CodexSidebarRow(
                height: heading.hasNavigationRail
                    ? OfficialCodexTheme.navRowHeight
                    : 32.0,
                tooltip: heading.directory,
                title: _projectName(heading.directory),
                highlighted: _menuController.isOpen,
                leading: Icon(
                  leadingIcon,
                  size: heading.hasNavigationRail ? 16 : 15,
                  color: palette.textSecondary,
                ),
                onTap: widget.onToggleCollapse,
                onSecondaryTap: reveal != null ? _menuController.show : null,
                onSecondaryTapDown: reveal != null
                    ? (details) => _menuController.show(
                        globalPosition: details.globalPosition,
                      )
                    : null,
                trailingBuilder: (context, hovered) {
                  if (reveal == null && newThread == null) {
                    return heading.collapsed && collapsedIndicator != null
                        ? collapsedIndicator
                        : const SizedBox.shrink();
                  }
                  final showActions =
                      hovered || _focusWithin || _menuController.isOpen;
                  return Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      if (heading.collapsed &&
                          !showActions &&
                          collapsedIndicator != null)
                        collapsedIndicator,
                      Opacity(
                        key: ValueKey(
                          'project-actions-visibility-${heading.directory}',
                        ),
                        opacity: showActions ? 1 : 0,
                        alwaysIncludeSemantics: true,
                        child: IgnorePointer(
                          ignoring: !showActions,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (reveal != null)
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(1),
                                  child: CodexPopoverAnchor(
                                    controller: _menuController,
                                    width: 216,
                                    popoverBuilder: (context, close) =>
                                        CodexMenu<VoidCallback>(
                                          items: [
                                            CodexMenuItem(
                                              value: reveal,
                                              label: Platform.isMacOS
                                                  ? 'Reveal in Finder'
                                                  : Platform.isWindows
                                                  ? 'Open in Explorer'
                                                  : 'Open in File Manager',
                                              icon: const Icon(
                                                Icons.folder_open_outlined,
                                              ),
                                            ),
                                          ],
                                          onSelected: (action) {
                                            close();
                                            action();
                                          },
                                        ),
                                    child: CodexIconButton(
                                      key: ValueKey(
                                        'project-menu-${heading.directory}',
                                      ),
                                      tooltip: 'Project actions',
                                      size: 22,
                                      onPressed: _menuController.toggle,
                                      icon: const Icon(
                                        Icons.more_horiz_rounded,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              if (newThread != null)
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(2),
                                  child: CodexIconButton(
                                    key: ValueKey(
                                      'project-new-thread-${heading.directory}',
                                    ),
                                    tooltip: 'New chat in project',
                                    size: 22,
                                    onPressed: newThread,
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 15,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
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
    required this.hasNavigationRail,
    required this.showTimestamp,
    required this.showGoalBadge,
    required this.pinned,
    this.persistedPinned = false,
    this.sessionPinned = false,
    this.pinActionLabel = 'Pin thread',
    this.canTogglePin = true,
    required this.archived,
    required this.enabled,
    this.supportsSections = false,
    this.sections = const [],
    required this.onSelect,
    required this.onResume,
    required this.onTogglePin,
    this.onToggleReadReceipt,
    required this.onRename,
    this.onManageGoal,
    required this.onFork,
    this.onMoveToSection,
    this.onMoveToNewSection,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  final ThreadSummary thread;
  final bool selected;
  final bool hasNavigationRail;
  final bool showTimestamp;
  final bool showGoalBadge;
  final bool pinned;
  final bool persistedPinned;
  final bool sessionPinned;
  final String pinActionLabel;
  final bool canTogglePin;
  final bool archived;
  final bool enabled;
  final bool supportsSections;
  final List<ThreadSection> sections;
  final VoidCallback onSelect;
  final VoidCallback onResume;
  final VoidCallback onTogglePin;
  final VoidCallback? onToggleReadReceipt;
  final VoidCallback onRename;
  final VoidCallback? onManageGoal;
  final VoidCallback onFork;
  final ValueChanged<String?>? onMoveToSection;
  final VoidCallback? onMoveToNewSection;
  final VoidCallback onArchiveToggle;
  final VoidCallback onDelete;

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

  String get _pinMenuLabel => widget.pinActionLabel;

  String? _formatPinBadge() {
    if (widget.persistedPinned) {
      return 'Saved pin';
    }
    if (widget.sessionPinned) {
      final section = widget.thread.section;
      if (section != null && !section.isBuiltInPinned) {
        return _truncateSidebarBadge('Session pin · ${section.name}', 32);
      }
      return 'Session pin';
    }
    return null;
  }

  Future<void> _chooseSection() async {
    final threadId = widget.thread.id;
    final currentSectionId = widget.thread.section?.id;
    final destinations = [
      for (final section in widget.sections)
        if (section.id != currentSectionId) section,
    ];
    final sectionId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OfficialCodexTheme.of(context).modalSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OfficialCodexTheme.popoverRadius),
          side: BorderSide(
            color: OfficialCodexTheme.of(context).hairlineBorder,
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
        title: const Text('Move to section'),
        content: SizedBox(
          width: 360,
          height: 240,
          child: ListView.builder(
            primary: false,
            itemCount: destinations.length,
            itemBuilder: (context, index) {
              final section = destinations[index];
              return CodexSidebarRow(
                title: section.name,
                tooltip: section.name,
                onTap: () => Navigator.of(context).pop(section.id),
              );
            },
          ),
        ),
        actions: [
          CodexButton(
            variant: CodexButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
            label: 'Cancel',
          ),
        ],
      ),
    );
    if (sectionId != null &&
        mounted &&
        widget.thread.id == threadId &&
        widget.thread.section?.id == currentSectionId &&
        widget.enabled &&
        widget.supportsSections &&
        widget.sections.any((section) => section.id == sectionId)) {
      widget.onMoveToSection?.call(sectionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final thread = widget.thread;
    final unread = thread.readReceipt?.unread ?? false;
    final showRunning =
        widget.hasNavigationRail && thread.status == ThreadRuntimeStatus.active;
    final toggleReadReceipt = widget.onToggleReadReceipt;
    final statusColor = switch (thread.status) {
      ThreadRuntimeStatus.active when !showRunning => palette.accent,
      ThreadRuntimeStatus.systemError => palette.danger,
      _ => null,
    };
    final showTrailingUnread =
        widget.hasNavigationRail &&
        unread &&
        !showRunning &&
        statusColor == null;
    final leadingColor =
        statusColor ??
        (unread && !showRunning && !showTrailingUnread ? palette.accent : null);
    final runningIndicator = showRunning
        ? SizedBox.square(
            key: ValueKey('thread-running-${thread.id}'),
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.7,
              color: palette.textMuted,
              semanticsLabel: unread
                  ? 'Running, unread thread'
                  : 'Running thread',
            ),
          )
        : null;

    final pinBadge = _formatPinBadge();
    final gitReference = _formatGitReference(thread.gitInfo);
    final goalBadge = widget.showGoalBadge
        ? _formatGoalBadge(thread.goal)
        : null;
    final hasMetadataBadges = pinBadge != null || goalBadge != null;

    final leadingDot = leadingColor != null
        ? Semantics(
            label: unread ? 'Unread thread' : null,
            child: Container(
              key: unread ? ValueKey('thread-unread-${thread.id}') : null,
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: leadingColor,
                shape: BoxShape.circle,
              ),
            ),
          )
        : null;

    final rowWidget = ListenableBuilder(
      listenable: _menuController,
      builder: (context, _) => CodexSidebarRow(
        containerKey: ValueKey('thread-row-${thread.id}'),
        title: thread.displayTitle,
        tooltip: gitReference == null
            ? null
            : '${thread.displayTitle}\nGit · $gitReference',
        selected: widget.selected,
        highlighted: _menuController.isOpen,
        onTap: widget.enabled ? widget.onSelect : null,
        onSecondaryTap: widget.enabled ? _menuController.show : null,
        onSecondaryTapDown: widget.enabled
            ? (details) =>
                  _menuController.show(globalPosition: details.globalPosition)
            : null,
        revealTrailingOnFocus: showRunning || showTrailingUnread,
        padding: EdgeInsets.only(
          left: widget.hasNavigationRail ? 10 : (leadingColor != null ? 8 : 10),
          right: 8,
        ),
        leading: widget.hasNavigationRail
            ? SizedBox.square(
                dimension: 16,
                child: leadingDot != null ? Center(child: leadingDot) : null,
              )
            : leadingDot,
        trailingBuilder: (context, isHovered) {
          final showActions =
              isHovered ||
              _menuController.isOpen ||
              (widget.selected && !showRunning && !showTrailingUnread);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showActions && thread.status == ThreadRuntimeStatus.notLoaded)
                CodexIconButton(
                  tooltip: 'Resume thread',
                  onPressed: widget.enabled ? widget.onResume : null,
                  size: 24,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                ),
              if (!showActions) ...[
                if (widget.pinned) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 12,
                    color: palette.textMuted,
                  ),
                  const SizedBox(width: 4),
                ],
                if (runningIndicator != null)
                  runningIndicator
                else if (showTrailingUnread)
                  SizedBox.square(
                    dimension: 16,
                    child: Center(
                      child: Semantics(
                        label: 'Unread thread',
                        child: Container(
                          key: ValueKey('thread-unread-${thread.id}'),
                          width: OfficialCodexTheme.sidebarUnreadIndicatorSize,
                          height: OfficialCodexTheme.sidebarUnreadIndicatorSize,
                          decoration: const BoxDecoration(
                            color:
                                OfficialCodexTheme.sidebarUnreadIndicatorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (widget.showTimestamp)
                  Text(
                    key: ValueKey('thread-timestamp-${thread.id}'),
                    _shortTime(thread.updatedAt),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontSize: 11, color: palette.textMuted),
                  ),
              ],
              CodexPopoverAnchor(
                key: ValueKey('thread-menu-anchor-${thread.id}'),
                controller: _menuController,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                width: 212,
                popoverBuilder: (context, close) => CodexMenu<String>(
                  items: [
                    if (toggleReadReceipt != null)
                      CodexMenuItem(
                        value: 'toggle-read-receipt',
                        label: unread ? 'Mark as read' : 'Mark as unread',
                        icon: Icon(
                          unread
                              ? Icons.mark_chat_read_outlined
                              : Icons.mark_chat_unread_outlined,
                        ),
                      ),
                    if (widget.canTogglePin)
                      CodexMenuItem(
                        value: 'pin',
                        label: _pinMenuLabel,
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
                    if (widget.onManageGoal != null)
                      const CodexMenuItem(
                        value: 'manage-goal',
                        label: 'Manage goal…',
                        icon: Icon(Icons.flag_outlined),
                      ),
                    const CodexMenuItem(
                      value: 'fork',
                      label: 'Fork thread',
                      icon: Icon(Icons.call_split_rounded),
                    ),
                    if (widget.supportsSections && !widget.archived) ...[
                      if (widget.onMoveToSection != null &&
                          widget.sections.any(
                            (section) => section.id != thread.section?.id,
                          ))
                        const CodexMenuItem(
                          value: 'move-section',
                          label: 'Move to section…',
                          icon: Icon(Icons.label_outline_rounded),
                        ),
                      if (widget.onMoveToNewSection != null)
                        const CodexMenuItem(
                          value: 'move-new-section',
                          label: 'Move to new section…',
                          icon: Icon(Icons.create_new_folder_outlined),
                        ),
                      if (thread.section != null &&
                          !thread.section!.isBuiltInPinned)
                        const CodexMenuItem(
                          value: 'remove-section',
                          label: 'Remove from section',
                          icon: Icon(Icons.label_off_outlined),
                        ),
                    ],
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
                    const CodexMenuItem(
                      value: 'delete',
                      label: 'Delete thread',
                      icon: Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                  onSelected: (action) {
                    close();
                    switch (action) {
                      case 'toggle-read-receipt':
                        toggleReadReceipt?.call();
                      case 'pin':
                        widget.onTogglePin();
                      case 'rename':
                        widget.onRename();
                      case 'manage-goal':
                        widget.onManageGoal?.call();
                      case 'fork':
                        widget.onFork();
                      case 'move-section':
                        unawaited(_chooseSection());
                      case 'move-new-section':
                        widget.onMoveToNewSection?.call();
                      case 'remove-section':
                        widget.onMoveToSection?.call(null);
                      case 'archive':
                        widget.onArchiveToggle();
                      case 'delete':
                        widget.onDelete();
                    }
                  },
                ),
                child: showActions
                    ? CodexIconButton(
                        key: ValueKey('thread-menu-${thread.id}'),
                        tooltip: 'Thread actions',
                        onPressed: widget.enabled
                            ? _menuController.toggle
                            : null,
                        size: 24,
                        icon: const Icon(Icons.more_horiz_rounded, size: 15),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );

    final body = hasMetadataBadges
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              rowWidget,
              _ThreadMetadataStrip(
                threadId: thread.id,
                hasNavigationRail: widget.hasNavigationRail,
                pinBadge: pinBadge,
                persistedPinned: widget.persistedPinned,
                goalBadge: goalBadge,
              ),
            ],
          )
        : rowWidget;
    return widget.hasNavigationRail
        ? body
        : Padding(padding: const EdgeInsets.only(left: 14.0), child: body);
  }

  static String? _formatGitReference(ThreadGitInfo? gitInfo) {
    if (gitInfo == null) {
      return null;
    }
    final branch = gitInfo.branch?.trim();
    if (branch != null && branch.isNotEmpty) {
      return _truncateSidebarBadge(branch, 28);
    }
    final sha = gitInfo.sha?.trim();
    if (sha != null && sha.isNotEmpty) {
      return _truncateSidebarBadge(
        sha.length > 8 ? sha.substring(0, 8) : sha,
        12,
      );
    }
    final origin = gitInfo.originUrl?.trim();
    if (origin != null && origin.isNotEmpty) {
      return _truncateSidebarBadge(origin, 28);
    }
    return null;
  }

  static String? _formatGoalBadge(ThreadGoal? goal) {
    final trimmed = goal?.objective.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final singleLine = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    return _truncateSidebarBadge(singleLine, 36);
  }

  static String _truncateSidebarBadge(String value, int maxChars) {
    if (value.length <= maxChars) {
      return value;
    }
    var end = maxChars;
    if (end > 0 &&
        end < value.length &&
        (value.codeUnitAt(end - 1) & 0xFC00) == 0xD800) {
      end -= 1;
    }
    return '${value.substring(0, end)}…';
  }
}

class _ThreadMetadataStrip extends StatelessWidget {
  const _ThreadMetadataStrip({
    required this.threadId,
    this.hasNavigationRail = false,
    this.pinBadge,
    this.persistedPinned = false,
    required this.goalBadge,
  });

  final String threadId;
  final bool hasNavigationRail;
  final String? pinBadge;
  final bool persistedPinned;
  final String? goalBadge;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final labelStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontSize: 10.5, color: palette.textMuted, height: 1.1);

    return Padding(
      padding: EdgeInsets.fromLTRB(hasNavigationRail ? 34 : 10, 0, 8, 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 3,
        children: [
          if (pinBadge != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Container(
                key: ValueKey('thread-pin-badge-$threadId'),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      persistedPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 10,
                      color: palette.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        pinBadge!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (goalBadge != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Container(
                key: ValueKey('thread-goal-badge-$threadId'),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 10,
                      color: palette.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        goalBadge!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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

enum _EcosystemSection { skills, plugins, apps, mcp }

enum _McpOperationKind { readResource, callTool }

class _EcosystemController extends ChangeNotifier {
  _EcosystemController({
    required this.gateway,
    required this.cwd,
    this.threadId,
    this.threadController,
    this.userInputController,
    this.mcpOauthController,
    required this.isModal,
    this.mcpOauthReadbackEnabled = true,
    _EcosystemSection initialSection = _EcosystemSection.skills,
  }) : _section = initialSection {
    threadController?.addListener(_handleThreadControllerChanged);
    _mcpOauthCompletionRevision = mcpOauthController?.completionRevision ?? 0;
    mcpOauthController?.addListener(_handleMcpOauthChanged);
    unawaited(refresh());
  }

  static const _appsPageSize = 25;
  static const _maxDisplayedAppTools = 20;

  final EcosystemGateway gateway;
  final String cwd;
  final String? threadId;
  final ThreadListController? threadController;
  final UserInputController? userInputController;
  final McpOauthController? mcpOauthController;
  final bool isModal;

  var _disposed = false;
  _EcosystemSection _section;
  var _skillsLoading = true;
  var _pluginsLoading = true;
  var _appsLoading = false;
  var _mcpLoading = true;
  var _loadingMoreApps = false;
  var _skillsRefreshGeneration = 0;
  var _pluginsRefreshGeneration = 0;
  var _appsRefreshGeneration = 0;
  var _mcpRefreshGeneration = 0;
  Future<void>? _skillsRefreshInFlight;
  Future<void>? _pluginsRefreshInFlight;
  Future<void>? _appsRefreshInFlight;
  Future<void>? _mcpRefreshInFlight;
  var _skillsLoadFailed = false;
  var _pluginsLoadFailed = false;
  var _installedAppsLoadFailed = false;
  var _catalogAppsLoadFailed = false;
  var _mcpLoadFailed = false;
  String? _skillsError;
  String? _pluginsError;
  String? _appsError;
  String? _mcpLoadError;
  String? _pluginActionNotice;
  List<SkillSummary> _skills = const [];
  PluginCatalogSnapshot _pluginCatalog = const PluginCatalogSnapshot(
    plugins: [],
  );

  List<PluginSummaryModel> get _plugins => _pluginCatalog.plugins;
  List<InstalledAppSnapshotModel> _installedApps = const [];
  List<AppSummaryModel> _catalogApps = const [];
  String? _appsNextCursor;
  List<McpServerStatusModel> _mcpServers = const [];
  final Map<String, Object> _mcpResults = <String, Object>{};
  final Map<String, String> _mcpErrors = <String, String>{};
  String? _mcpBusyServer;
  String? _mcpBusyThreadId;
  _McpOperationKind? _mcpBusyOperation;
  Set<Object> _mcpExcludedElicitationIds = const <Object>{};
  var _reloadingMcp = false;
  String? _mcpNotice;
  var _mcpOauthCompletionRevision = 0;
  var _mcpOauthRefreshPending = false;
  bool mcpOauthReadbackEnabled;

  void setMcpOauthReadbackEnabled(bool enabled) {
    if (_disposed || mcpOauthReadbackEnabled == enabled) return;
    mcpOauthReadbackEnabled = enabled;
    if (enabled) {
      // Visibility can change during layout. Reconcile after that build, and
      // retain the catalog/mutation controller rather than recreating it.
      scheduleMicrotask(_handleMcpOauthChanged);
    }
  }

  void _handleMcpOauthChanged() {
    if (_disposed) return;
    if (!mcpOauthReadbackEnabled) {
      // A retained surface can still be mounted behind a dialog: stop its
      // pending animation/update the notice, but leave status readback deferred.
      _notify();
      return;
    }
    final revision = mcpOauthController?.completionRevision ?? 0;
    if (revision != _mcpOauthCompletionRevision) {
      _mcpOauthCompletionRevision = revision;
      _mcpOauthRefreshPending = true;
    }
    if (_mcpOauthRefreshPending &&
        _mcpRefreshInFlight == null &&
        !_reloadingMcp) {
      _mcpOauthRefreshPending = false;
      unawaited(_refreshMcp(forceRefetch: true));
    }
    _notify();
  }

  final Set<String> _mutatingSkillPaths = <String>{};
  final Set<String> _expandedPluginIds = <String>{};
  final Set<String> _readingPluginIds = <String>{};
  final Set<String> _mutatingPluginIds = <String>{};
  final Map<String, PluginDetailModel> _pluginDetails =
      <String, PluginDetailModel>{};

  final Set<String> _expandedInstalledAppIds = <String>{};
  final Set<String> _expandedCatalogAppIds = <String>{};
  final Set<String> _readingAppIds = <String>{};
  final Map<String, AppDetailModel> _appDetails = <String, AppDetailModel>{};
  final Set<String> _missingAppIds = <String>{};

  _EcosystemSection get section => _section;
  List<SkillSummary> get skills => _skills;
  List<PluginSummaryModel> get plugins => _plugins;
  List<PluginSummaryModel> get installedPlugins =>
      _plugins.where((plugin) => plugin.installed).toList(growable: false);
  List<InstalledAppSnapshotModel> get installedApps => _installedApps;
  List<AppSummaryModel> get catalogApps => _catalogApps;
  List<McpServerStatusModel> get mcpServers => _mcpServers;
  bool get skillsLoading => _skillsLoading;
  bool get pluginsLoading => _pluginsLoading;
  bool get appsLoading => _appsLoading;
  bool get mcpLoading => _mcpLoading;
  bool get loadingMoreApps => _loadingMoreApps;
  bool get skillsLoadFailed => _skillsLoadFailed;
  bool get pluginsLoadFailed => _pluginsLoadFailed;
  bool get installedAppsLoadFailed => _installedAppsLoadFailed;
  bool get catalogAppsLoadFailed => _catalogAppsLoadFailed;
  bool get mcpLoadFailed => _mcpLoadFailed;
  bool get pluginCatalogIsPartial => _pluginCatalog.isPartial;
  bool get pluginCatalogIsTruncated => _pluginCatalog.isTruncated;
  String? get appsError => _appsError;
  String? get appsNextCursor => _appsNextCursor;
  String? get pluginActionNotice => _pluginActionNotice;
  String? get mcpNotice => _mcpNotice;
  bool get reloadingMcp => _reloadingMcp;
  String? get mcpBusyServer => _mcpBusyServer;
  _McpOperationKind? get mcpBusyOperation => _mcpBusyOperation;

  bool isSkillMutating(String path) => _mutatingSkillPaths.contains(path);
  bool isPluginExpanded(String id) => _expandedPluginIds.contains(id);
  bool isPluginReading(String id) => _readingPluginIds.contains(id);
  bool isPluginMutating(String id) => _mutatingPluginIds.contains(id);
  bool get hasMutatingPlugins => _mutatingPluginIds.isNotEmpty;
  bool get hasPluginsRefreshInFlight => _pluginsRefreshInFlight != null;
  PluginDetailModel? pluginDetail(String id) => _pluginDetails[id];

  bool isInstalledAppExpanded(String id) =>
      _expandedInstalledAppIds.contains(id);
  bool isCatalogAppExpanded(String id) => _expandedCatalogAppIds.contains(id);
  bool isAppReading(String id) => _readingAppIds.contains(id);
  bool isAppMissing(String id) => _missingAppIds.contains(id);
  AppDetailModel? appDetail(String id) => _appDetails[id];

  String? mcpError(String serverName) => _mcpErrors[serverName];
  Object? mcpResult(String serverName) => _mcpResults[serverName];

  EcosystemCatalogGateway? get catalogGateway => switch (gateway) {
    final EcosystemCatalogGateway g when g.supportsEcosystemCatalog => g,
    _ => null,
  };

  McpCapabilityGateway? get mcpGateway => switch (gateway) {
    final McpCapabilityGateway g when g.supportsMcpCapabilities => g,
    _ => null,
  };

  int get appsBadgeCount =>
      _catalogApps.isNotEmpty ? _catalogApps.length : _installedApps.length;

  bool get isSkillsAtCap => _skills.length >= maxBoundedEcosystemItems;
  bool get isPluginsAtCap => _plugins.length >= maxBoundedEcosystemItems;
  bool get isPluginsIncomplete =>
      pluginCatalogIsPartial || pluginCatalogIsTruncated || isPluginsAtCap;
  bool get isInstalledAppsAtCap =>
      _installedApps.length >= maxBoundedEcosystemItems;
  bool get isCatalogAppsAtCap =>
      _catalogApps.length >= maxBoundedEcosystemItems;
  bool get isCatalogAppsIncomplete =>
      isCatalogAppsAtCap || _appsNextCursor != null;
  bool get isAppsBadgeLoadedOnly =>
      _catalogApps.isNotEmpty ? isCatalogAppsIncomplete : isInstalledAppsAtCap;
  bool get isMcpAtCap => _mcpServers.length >= maxBoundedEcosystemItems;

  String sectionCountText(_EcosystemSection target) => switch (target) {
    _EcosystemSection.skills =>
      isSkillsAtCap ? '${_skills.length} loaded' : '${_skills.length}',
    _EcosystemSection.plugins =>
      isPluginsIncomplete ? '${_plugins.length} loaded' : '${_plugins.length}',
    _EcosystemSection.apps =>
      isAppsBadgeLoadedOnly ? '$appsBadgeCount loaded' : '$appsBadgeCount',
    _EcosystemSection.mcp =>
      isMcpAtCap ? '${_mcpServers.length} loaded' : '${_mcpServers.length}',
  };

  String sectionSegmentLabel(_EcosystemSection target) {
    final name = switch (target) {
      _EcosystemSection.skills => 'Skills',
      _EcosystemSection.plugins => 'Plugins',
      _EcosystemSection.apps => 'Apps',
      _EcosystemSection.mcp => 'MCP',
    };
    return '$name (${sectionCountText(target)})';
  }

  List<String> get _normalizedCwds =>
      cwd.trim().isEmpty ? const <String>[] : <String>[cwd.trim()];

  bool isSectionLoading(_EcosystemSection target) => switch (target) {
    _EcosystemSection.skills =>
      _skillsLoading ||
          _skillsRefreshInFlight != null ||
          _mutatingSkillPaths.isNotEmpty,
    _EcosystemSection.plugins =>
      _pluginsLoading ||
          _pluginsRefreshInFlight != null ||
          _mutatingPluginIds.isNotEmpty,
    _EcosystemSection.apps => _appsLoading || _appsRefreshInFlight != null,
    _EcosystemSection.mcp =>
      _mcpLoading || _mcpRefreshInFlight != null || _reloadingMcp,
  };

  String? sectionError(_EcosystemSection target) => switch (target) {
    _EcosystemSection.skills => _skillsError,
    _EcosystemSection.plugins => _pluginsError,
    _EcosystemSection.apps => null,
    _EcosystemSection.mcp => _mcpLoadError,
  };

  ValueKey<String> sectionErrorKey(_EcosystemSection target) =>
      switch (target) {
        _EcosystemSection.skills => const ValueKey('ecosystem-skills-error'),
        _EcosystemSection.plugins => const ValueKey('ecosystem-plugins-error'),
        _EcosystemSection.apps => const ValueKey('ecosystem-apps-error'),
        _EcosystemSection.mcp => const ValueKey('ecosystem-mcp-error'),
      };

  void setSection(_EcosystemSection next) {
    if (_disposed || _section == next) {
      return;
    }
    _section = next;
    notifyListeners();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _handleThreadControllerChanged() {
    if (_disposed) {
      return;
    }
    final capturedId = threadId;
    final selected = threadController?.selectedThread;
    if (capturedId != null &&
        selected != null &&
        selected.id == capturedId &&
        selected.status != ThreadRuntimeStatus.notLoaded &&
        _mcpErrors.values.any(
          (error) => error.contains('Resume the selected thread'),
        )) {
      _mcpErrors.removeWhere(
        (_, error) => error.contains('Resume the selected thread'),
      );
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    threadController?.removeListener(_handleThreadControllerChanged);
    mcpOauthController?.removeListener(_handleMcpOauthChanged);
    super.dispose();
  }

  List<McpElicitationRequest> activeDirectMcpElicitations(
    UserInputController? controller,
  ) {
    final busyServer = _mcpBusyServer;
    final busyThreadId = _mcpBusyThreadId;
    if (controller == null || busyServer == null || busyThreadId == null) {
      return const <McpElicitationRequest>[];
    }
    return controller.pendingElicitations
        .where(
          (request) =>
              !_mcpExcludedElicitationIds.contains(request.requestId) &&
              request.turnId == null &&
              request.threadId == busyThreadId &&
              request.serverName == busyServer,
        )
        .toList(growable: false);
  }

  void _prunePluginCaches(
    List<PluginSummaryModel> plugins, {
    required bool forceRefetch,
  }) {
    final reachableIds = plugins.map((p) => p.id).toSet();
    _expandedPluginIds.retainAll(reachableIds);
    _readingPluginIds.retainAll(reachableIds);
    _pluginDetails.removeWhere(
      (id, _) =>
          !reachableIds.contains(id) ||
          (forceRefetch && !_expandedPluginIds.contains(id)),
    );
  }

  void _pruneAppCaches(
    List<InstalledAppSnapshotModel> installedApps,
    List<AppSummaryModel> catalogApps, {
    required bool forceRefetch,
  }) {
    final installedIds = installedApps.map((a) => a.id).toSet();
    final catalogIds = catalogApps.map((a) => a.id).toSet();
    final reachableIds = <String>{...installedIds, ...catalogIds};
    _expandedInstalledAppIds.retainAll(installedIds);
    _expandedCatalogAppIds.retainAll(catalogIds);
    _readingAppIds.retainAll(reachableIds);
    final expandedIds = <String>{
      ..._expandedInstalledAppIds,
      ..._expandedCatalogAppIds,
    };
    _appDetails.removeWhere(
      (id, _) =>
          !reachableIds.contains(id) ||
          (forceRefetch && !expandedIds.contains(id)),
    );
    _missingAppIds.removeWhere(
      (id) =>
          !reachableIds.contains(id) ||
          (forceRefetch && !expandedIds.contains(id)),
    );
  }

  void _pruneMcpCaches(
    List<McpServerStatusModel> servers, {
    required bool forceRefetch,
  }) {
    final reachableNames = servers.map((server) => server.name).toSet();
    _mcpResults.removeWhere(
      (name, _) => forceRefetch || !reachableNames.contains(name),
    );
    _mcpErrors.removeWhere(
      (name, _) => forceRefetch || !reachableNames.contains(name),
    );
  }

  Future<void> refresh({bool forceRefetch = false}) async {
    if (_disposed) {
      return;
    }
    final cwds = _normalizedCwds;
    unawaited(_refreshApps(forceRefetch: forceRefetch));
    await Future.wait<void>([
      _refreshSkills(cwds: cwds),
      _refreshPlugins(cwds: cwds, forceRefetch: forceRefetch),
      _refreshMcp(forceRefetch: forceRefetch),
    ]);
  }

  Future<void> retryPlugins() =>
      _refreshPlugins(cwds: _normalizedCwds, forceRefetch: true);

  Future<void> _refreshSkills({required List<String> cwds}) {
    if (_skillsRefreshInFlight case final inFlight?) {
      return inFlight;
    }
    if (_mutatingSkillPaths.isNotEmpty) {
      return Future<void>.value();
    }
    late final Future<void> future;
    future = _runRefreshSkills(cwds: cwds).whenComplete(() {
      if (identical(_skillsRefreshInFlight, future)) {
        _skillsRefreshInFlight = null;
        if (!_disposed && _skillsLoading) {
          _skillsLoading = false;
          _notify();
        }
      }
    });
    _skillsRefreshInFlight = future;
    return future;
  }

  Future<void> _runRefreshSkills({required List<String> cwds}) async {
    final generation = ++_skillsRefreshGeneration;
    if (!_disposed) {
      _skillsLoading = true;
      _skillsError = null;
      _notify();
    }
    try {
      final nextSkills = await gateway.listSkills(cwds: cwds);
      if (_disposed || generation != _skillsRefreshGeneration) {
        return;
      }
      _skills = nextSkills;
      _skillsLoadFailed = false;
      _skillsError = null;
      _skillsLoading = false;
      _notify();
    } catch (error) {
      if (_disposed || generation != _skillsRefreshGeneration) {
        return;
      }
      _skillsLoadFailed = true;
      _skillsError = '$error';
      _skillsLoading = false;
      _notify();
    }
  }

  Future<void> _refreshPlugins({
    required List<String> cwds,
    required bool forceRefetch,
    bool allowDuringMutation = false,
  }) {
    if (_pluginsRefreshInFlight case final inFlight?) {
      return inFlight;
    }
    if (!allowDuringMutation && _mutatingPluginIds.isNotEmpty) {
      return Future<void>.value();
    }
    late final Future<void> future;
    future = _runRefreshPlugins(cwds: cwds, forceRefetch: forceRefetch)
        .whenComplete(() {
          if (identical(_pluginsRefreshInFlight, future)) {
            _pluginsRefreshInFlight = null;
            if (!_disposed) {
              _pluginsLoading = false;
              _notify();
            }
          }
        });
    _pluginsRefreshInFlight = future;
    return future;
  }

  Future<void> _runRefreshPlugins({
    required List<String> cwds,
    required bool forceRefetch,
  }) async {
    final generation = ++_pluginsRefreshGeneration;
    final catalog = catalogGateway;
    if (!_disposed) {
      _pluginsLoading = true;
      _pluginsError = null;
      _notify();
    }
    try {
      final snapshot = catalog != null
          ? await catalog.listPluginCatalog(cwds: cwds)
          : PluginCatalogSnapshot(
              plugins: await gateway.listPlugins(cwds: cwds),
            );
      if (_disposed || generation != _pluginsRefreshGeneration) {
        return;
      }
      final nextPlugins = snapshot.plugins;
      _pluginCatalog = snapshot;
      _prunePluginCaches(nextPlugins, forceRefetch: forceRefetch);
      _pluginsLoadFailed = false;
      _pluginsError = null;
      _pluginsLoading = false;
      _notify();
      if (forceRefetch && catalog != null && _expandedPluginIds.isNotEmpty) {
        await _refreshExpandedPluginDetails(
          catalog: catalog,
          plugins: nextPlugins,
          generation: generation,
        );
      }
    } catch (error) {
      if (_disposed || generation != _pluginsRefreshGeneration) {
        return;
      }
      _pluginsLoadFailed = true;
      _pluginsError = '$error';
      _pluginsLoading = false;
      _notify();
    }
  }

  Future<void> _refreshExpandedPluginDetails({
    required EcosystemCatalogGateway catalog,
    required List<PluginSummaryModel> plugins,
    required int generation,
  }) async {
    final expandedPlugins = plugins
        .where((p) => _expandedPluginIds.contains(p.id))
        .toList(growable: false);
    for (final plugin in expandedPlugins) {
      if (_disposed || generation != _pluginsRefreshGeneration) {
        return;
      }
      if (!_expandedPluginIds.contains(plugin.id)) {
        continue;
      }
      try {
        final updatedDetail = await catalog.readPlugin(
          pluginName: plugin.effectivePluginName,
          marketplacePath: plugin.marketplacePath,
          remoteMarketplaceName: plugin.marketplacePath == null
              ? plugin.marketplaceName
              : null,
        );
        if (!_disposed &&
            generation == _pluginsRefreshGeneration &&
            _expandedPluginIds.contains(plugin.id)) {
          _pluginDetails[plugin.id] = updatedDetail;
          _notify();
        }
      } on Object {
        // Keep existing detail if refresh re-read fails.
      }
    }
  }

  Future<void> _refreshMcp({required bool forceRefetch}) {
    if (_mcpRefreshInFlight case final inFlight?) {
      return inFlight;
    }
    if (_reloadingMcp) {
      return Future<void>.value();
    }
    late final Future<void> future;
    future = _runRefreshMcp(forceRefetch: forceRefetch).whenComplete(() {
      if (identical(_mcpRefreshInFlight, future)) {
        _mcpRefreshInFlight = null;
        if (!_disposed && _mcpLoading) {
          _mcpLoading = false;
          _notify();
        }
        if (!_disposed && mcpOauthReadbackEnabled && _mcpOauthRefreshPending) {
          _mcpOauthRefreshPending = false;
          unawaited(_refreshMcp(forceRefetch: true));
        }
      }
    });
    _mcpRefreshInFlight = future;
    return future;
  }

  Future<void> _runRefreshMcp({required bool forceRefetch}) async {
    final generation = ++_mcpRefreshGeneration;
    if (!_disposed) {
      _mcpLoading = true;
      _mcpLoadError = null;
      _notify();
    }
    try {
      final nextMcpServers = await gateway.listMcpServerStatus();
      if (_disposed || generation != _mcpRefreshGeneration) {
        return;
      }
      _mcpServers = nextMcpServers;
      _pruneMcpCaches(nextMcpServers, forceRefetch: forceRefetch);
      _mcpLoadFailed = false;
      _mcpLoadError = null;
      _mcpLoading = false;
      _notify();
    } catch (error) {
      if (_disposed || generation != _mcpRefreshGeneration) {
        return;
      }
      _mcpLoadFailed = true;
      _mcpLoadError = '$error';
      _mcpLoading = false;
      _notify();
    }
  }

  Future<void> _refreshApps({required bool forceRefetch}) {
    if (_appsRefreshInFlight case final inFlight?) {
      return inFlight;
    }
    final future = _runRefreshApps(forceRefetch: forceRefetch);
    _appsRefreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_appsRefreshInFlight, future)) {
        _appsRefreshInFlight = null;
      }
    });
  }

  Future<void> _runRefreshApps({required bool forceRefetch}) async {
    final generation = ++_appsRefreshGeneration;
    final catalog = catalogGateway;
    if (catalog == null) {
      if (_disposed) {
        return;
      }
      _installedApps = const [];
      _catalogApps = const [];
      _appsNextCursor = null;
      _installedAppsLoadFailed = false;
      _catalogAppsLoadFailed = false;
      _appsError = null;
      _appsLoading = false;
      _loadingMoreApps = false;
      _pruneAppCaches(const [], const [], forceRefetch: true);
      _notify();
      return;
    }

    if (!_disposed) {
      _appsLoading = true;
      _loadingMoreApps = false;
      _appsError = null;
      _notify();
    }

    var nextInstalledApps = _installedApps;
    var nextCatalogApps = _catalogApps;
    var installedAppsLoadFailed = false;
    var catalogAppsLoadFailed = false;
    String? nextCursor = _appsNextCursor;
    String? appsError;

    try {
      nextInstalledApps = await catalog.listInstalledApps(
        threadId: threadId,
        forceRefresh: forceRefetch,
      );
      if (!_disposed && generation == _appsRefreshGeneration) {
        _installedApps = nextInstalledApps;
        _installedAppsLoadFailed = false;
        _notify();
      }
    } catch (error) {
      installedAppsLoadFailed = true;
      appsError = '$error';
    }

    try {
      final page = await catalog.listApps(
        AppListQuery(
          limit: _appsPageSize,
          threadId: threadId,
          forceRefetch: forceRefetch,
        ),
      );
      nextCatalogApps = page.apps
          .take(maxBoundedEcosystemItems)
          .toList(growable: false);
      nextCursor = nextCatalogApps.length >= maxBoundedEcosystemItems
          ? null
          : page.nextCursor;
    } catch (error) {
      catalogAppsLoadFailed = true;
      appsError = appsError == null ? '$error' : '$appsError\n$error';
    }

    if (_disposed || generation != _appsRefreshGeneration) {
      return;
    }
    _installedApps = nextInstalledApps;
    _catalogApps = nextCatalogApps;
    _installedAppsLoadFailed = installedAppsLoadFailed;
    _catalogAppsLoadFailed = catalogAppsLoadFailed;
    _appsNextCursor = nextCursor;
    _appsError = appsError;
    _appsLoading = false;
    _pruneAppCaches(
      nextInstalledApps,
      nextCatalogApps,
      forceRefetch: forceRefetch,
    );
    _notify();

    if (forceRefetch) {
      final expandedIds = <String>{
        ..._expandedInstalledAppIds,
        ..._expandedCatalogAppIds,
      };
      if (expandedIds.isNotEmpty) {
        try {
          final result = await catalog.readApps(
            appIds: expandedIds.toList(growable: false),
            includeTools: true,
            threadId: threadId,
          );
          if (_disposed || generation != _appsRefreshGeneration) {
            return;
          }
          for (final detail in result.apps) {
            _appDetails[detail.id] = detail;
            _missingAppIds.remove(detail.id);
          }
          for (final missing in result.missingAppIds) {
            _missingAppIds.add(missing);
          }
          _notify();
        } on Object {
          // Keep existing detail if refresh re-read fails.
        }
      }
    }
  }

  Future<void> loadMoreApps() async {
    final catalog = catalogGateway;
    final cursor = _appsNextCursor;
    if (_disposed ||
        catalog == null ||
        cursor == null ||
        _loadingMoreApps ||
        _catalogApps.length >= maxBoundedEcosystemItems) {
      return;
    }
    _loadingMoreApps = true;
    _appsError = null;
    _notify();
    try {
      final remaining = maxBoundedEcosystemItems - _catalogApps.length;
      final page = await catalog.listApps(
        AppListQuery(
          cursor: cursor,
          limit: remaining < _appsPageSize ? remaining : _appsPageSize,
          threadId: threadId,
        ),
      );
      if (_disposed) {
        return;
      }
      final merged = <AppSummaryModel>[..._catalogApps];
      final seen = merged.map((a) => a.id).toSet();
      for (final app in page.apps) {
        if (merged.length >= maxBoundedEcosystemItems) {
          break;
        }
        if (seen.add(app.id)) {
          merged.add(app);
        }
      }
      _catalogApps = List<AppSummaryModel>.unmodifiable(merged);
      _appsNextCursor = merged.length >= maxBoundedEcosystemItems
          ? null
          : page.nextCursor;
      _loadingMoreApps = false;
      _notify();
    } catch (error) {
      if (_disposed) {
        return;
      }
      _appsError = '$error';
      _loadingMoreApps = false;
      _notify();
    }
  }

  Future<void> reloadMcpServers() async {
    final mcp = mcpGateway;
    if (_disposed ||
        mcp == null ||
        (mcpOauthController?.busy ?? false) ||
        _reloadingMcp ||
        _mcpLoading ||
        _mcpRefreshInFlight != null) {
      return;
    }
    _reloadingMcp = true;
    _mcpNotice = null;
    _mcpErrors.clear();
    _notify();
    try {
      await mcp.reloadMcpServers();
      if (_disposed) {
        return;
      }
      final generation = ++_mcpRefreshGeneration;
      final servers = await gateway.listMcpServerStatus();
      if (_disposed || generation != _mcpRefreshGeneration) {
        return;
      }
      _mcpServers = servers;
      _pruneMcpCaches(servers, forceRefetch: true);
      _mcpLoadFailed = false;
      _mcpLoadError = null;
      _mcpLoading = false;
      _mcpNotice = 'MCP server configuration reloaded.';
    } catch (error) {
      if (!_disposed) {
        _mcpLoading = false;
        _mcpNotice = 'Reload failed: $error';
      }
    } finally {
      if (!_disposed) {
        _reloadingMcp = false;
        _notify();
        if (mcpOauthReadbackEnabled && _mcpOauthRefreshPending) {
          _mcpOauthRefreshPending = false;
          unawaited(_refreshMcp(forceRefetch: true));
        }
      }
    }
  }

  bool _ensureCapturedThreadReady(String serverName, String capturedThreadId) {
    final threads = threadController;
    if (threads == null) {
      return true;
    }
    final selected = threads.selectedThread;
    if (selected == null || selected.id != capturedThreadId) {
      _mcpErrors[serverName] = isModal
          ? 'Selected thread changed; reopen Skills, Plugins & MCP to continue.'
          : 'Selected thread changed; refresh Customize to continue.';
      _notify();
      return false;
    }
    if (selected.status == ThreadRuntimeStatus.notLoaded &&
        threads.isMaterialized(selected.id)) {
      _mcpErrors[serverName] = isModal
          ? 'Resume the selected thread in the sidebar and reopen Skills, Plugins & MCP to run thread-scoped MCP actions.'
          : 'Resume the selected thread in the Conversations sidebar to run thread-scoped MCP actions.';
      _notify();
      return false;
    }
    return true;
  }

  void _activateMcpOutboundOperation(
    String serverName,
    String? activeThreadId,
    _McpOperationKind kind,
  ) {
    final existingIds = userInputController?.pendingElicitations
        .map((request) => request.requestId)
        .toSet();
    _mcpBusyServer = serverName;
    _mcpBusyThreadId = activeThreadId;
    _mcpBusyOperation = kind;
    _mcpExcludedElicitationIds = existingIds == null || existingIds.isEmpty
        ? const <Object>{}
        : Set<Object>.unmodifiable(existingIds);
    _mcpErrors.remove(serverName);
    _notify();
  }

  Future<void> readMcpResource(
    BuildContext context,
    McpServerStatusModel server,
  ) async {
    final mcp = mcpGateway;
    if (_disposed ||
        !context.mounted ||
        mcp == null ||
        _mcpBusyServer != null) {
      return;
    }
    final uri = await showDialog<String>(
      context: context,
      builder: (context) => _McpResourceReadDialog(serverName: server.name),
    );
    if (uri == null || _disposed) {
      return;
    }
    final normalizedThreadId = threadId?.trim();
    final activeThreadId =
        normalizedThreadId == null || normalizedThreadId.isEmpty
        ? null
        : normalizedThreadId;
    if (activeThreadId != null &&
        !_ensureCapturedThreadReady(server.name, activeThreadId)) {
      return;
    }
    _activateMcpOutboundOperation(
      server.name,
      activeThreadId,
      _McpOperationKind.readResource,
    );
    try {
      final result = await mcp.readMcpResource(
        McpResourceReadQuery(
          server: server.name,
          uri: uri,
          threadId: activeThreadId,
        ),
      );
      if (!_disposed) {
        _mcpResults[server.name] = result;
      }
    } catch (error) {
      if (!_disposed) {
        _mcpErrors[server.name] = '$error';
      }
    } finally {
      if (!_disposed) {
        _mcpBusyServer = null;
        _mcpBusyThreadId = null;
        _mcpBusyOperation = null;
        _mcpExcludedElicitationIds = const <Object>{};
        _notify();
      }
    }
  }

  Future<void> callMcpTool(
    BuildContext context,
    McpServerStatusModel server,
  ) async {
    final mcp = mcpGateway;
    if (_disposed ||
        !context.mounted ||
        mcp == null ||
        _mcpBusyServer != null) {
      return;
    }
    final normalizedThreadId = threadId?.trim();
    if (normalizedThreadId == null || normalizedThreadId.isEmpty) {
      _mcpErrors[server.name] =
          'Select or create a thread before calling an MCP tool.';
      _notify();
      return;
    }
    final input = await showDialog<({String tool, Map<String, Object?> args})>(
      context: context,
      builder: (context) => _McpToolCallDialog(serverName: server.name),
    );
    if (input == null || _disposed) {
      return;
    }
    if (!_ensureCapturedThreadReady(server.name, normalizedThreadId)) {
      return;
    }
    _activateMcpOutboundOperation(
      server.name,
      normalizedThreadId,
      _McpOperationKind.callTool,
    );
    try {
      final result = await mcp.callMcpTool(
        McpToolCallQuery(
          server: server.name,
          threadId: normalizedThreadId,
          tool: input.tool,
          arguments: input.args,
        ),
      );
      if (!_disposed) {
        _mcpResults[server.name] = result;
      }
    } catch (error) {
      if (!_disposed) {
        _mcpErrors[server.name] = '$error';
      }
    } finally {
      if (!_disposed) {
        _mcpBusyServer = null;
        _mcpBusyThreadId = null;
        _mcpBusyOperation = null;
        _mcpExcludedElicitationIds = const <Object>{};
        _notify();
      }
    }
  }

  Future<void> toggleSkill(SkillSummary skill) async {
    if (_disposed ||
        _skillsLoading ||
        _mutatingSkillPaths.contains(skill.path)) {
      return;
    }
    _mutatingSkillPaths.add(skill.path);
    _skillsError = null;
    _notify();
    try {
      final effective = await gateway.setSkillEnabled(
        path: skill.path,
        enabled: !skill.enabled,
      );
      if (_disposed) {
        return;
      }
      ++_skillsRefreshGeneration;
      _skills = [
        for (final item in _skills)
          if (item.path == skill.path)
            item.copyWith(enabled: effective)
          else
            item,
      ];
    } catch (error) {
      if (!_disposed) {
        _skillsError = '$error';
      }
    } finally {
      if (!_disposed) {
        _mutatingSkillPaths.remove(skill.path);
        _notify();
      }
    }
  }

  Future<void> selectAndExpandPlugin(PluginSummaryModel plugin) async {
    if (_disposed) {
      return;
    }
    setSection(_EcosystemSection.plugins);
    if (_expandedPluginIds.contains(plugin.id)) {
      return;
    }
    await togglePluginDetails(plugin);
  }

  Future<void> togglePluginDetails(PluginSummaryModel plugin) async {
    final catalog = catalogGateway;
    if (_disposed ||
        catalog == null ||
        _pluginsLoading ||
        _pluginsRefreshInFlight != null) {
      return;
    }
    if (_expandedPluginIds.contains(plugin.id)) {
      _expandedPluginIds.remove(plugin.id);
      _notify();
      return;
    }
    _expandedPluginIds.add(plugin.id);
    _readingPluginIds.add(plugin.id);
    _pluginsError = null;
    _notify();
    try {
      final detail = await catalog.readPlugin(
        pluginName: plugin.effectivePluginName,
        marketplacePath: plugin.marketplacePath,
        remoteMarketplaceName: plugin.marketplacePath == null
            ? plugin.marketplaceName
            : null,
      );
      if (_disposed) {
        return;
      }
      _pluginDetails[plugin.id] = detail;
      _readingPluginIds.remove(plugin.id);
      _notify();
    } catch (error) {
      if (_disposed) {
        return;
      }
      _readingPluginIds.remove(plugin.id);
      _expandedPluginIds.remove(plugin.id);
      _pluginsError = '$error';
      _notify();
    }
  }

  Future<void> installPlugin(PluginSummaryModel plugin) async {
    final catalog = catalogGateway;
    if (_disposed ||
        catalog == null ||
        _pluginsLoading ||
        _pluginsRefreshInFlight != null ||
        _mutatingPluginIds.isNotEmpty) {
      return;
    }
    _mutatingPluginIds.add(plugin.id);
    _pluginsError = null;
    _pluginActionNotice = null;
    _notify();
    try {
      final result = await catalog.installPlugin(
        pluginName: plugin.effectivePluginName,
        marketplacePath: plugin.marketplacePath,
        remoteMarketplaceName: plugin.marketplacePath == null
            ? plugin.marketplaceName
            : null,
      );
      if (_disposed) {
        return;
      }
      final authApps = result.appsNeedingAuth.map((a) => a.name).join(', ');
      final notice = authApps.isNotEmpty
          ? 'Installed ${plugin.name} (${result.authPolicy}). Connector authentication required: $authApps.'
          : 'Installed ${plugin.name}.';
      final cwds = _normalizedCwds;
      unawaited(_refreshSkills(cwds: cwds));
      unawaited(_refreshMcp(forceRefetch: true));
      unawaited(_refreshApps(forceRefetch: true));
      await _refreshPlugins(
        cwds: cwds,
        forceRefetch: true,
        allowDuringMutation: true,
      );
      if (_disposed) {
        return;
      }
      _mutatingPluginIds.remove(plugin.id);
      _pluginActionNotice = notice;
      _notify();
    } catch (error) {
      if (_disposed) {
        return;
      }
      _mutatingPluginIds.remove(plugin.id);
      _pluginsError = '$error';
      _notify();
    }
  }

  Future<void> uninstallPlugin(PluginSummaryModel plugin) async {
    final catalog = catalogGateway;
    if (_disposed ||
        catalog == null ||
        _pluginsLoading ||
        _pluginsRefreshInFlight != null ||
        _mutatingPluginIds.isNotEmpty) {
      return;
    }
    _mutatingPluginIds.add(plugin.id);
    _pluginsError = null;
    _pluginActionNotice = null;
    _notify();
    try {
      await catalog.uninstallPlugin(pluginId: plugin.id);
      if (_disposed) {
        return;
      }
      final cwds = _normalizedCwds;
      unawaited(_refreshSkills(cwds: cwds));
      unawaited(_refreshMcp(forceRefetch: true));
      unawaited(_refreshApps(forceRefetch: true));
      await _refreshPlugins(
        cwds: cwds,
        forceRefetch: true,
        allowDuringMutation: true,
      );
      if (_disposed) {
        return;
      }
      _mutatingPluginIds.remove(plugin.id);
      _pluginDetails.remove(plugin.id);
      _expandedPluginIds.remove(plugin.id);
      _pluginActionNotice = 'Uninstalled ${plugin.name}.';
      _notify();
    } catch (error) {
      if (_disposed) {
        return;
      }
      _mutatingPluginIds.remove(plugin.id);
      _pluginsError = '$error';
      _notify();
    }
  }

  Future<void> toggleAppDetails(
    String appId, {
    required bool installedSection,
  }) async {
    final catalog = catalogGateway;
    if (_disposed || catalog == null) {
      return;
    }
    final targetSet = installedSection
        ? _expandedInstalledAppIds
        : _expandedCatalogAppIds;
    if (targetSet.contains(appId)) {
      targetSet.remove(appId);
      _notify();
      return;
    }
    targetSet.add(appId);
    _readingAppIds.add(appId);
    _appsError = null;
    _notify();
    try {
      final result = await catalog.readApps(
        appIds: <String>[appId],
        includeTools: true,
        threadId: threadId,
      );
      if (_disposed) {
        return;
      }
      _readingAppIds.remove(appId);
      for (final detail in result.apps) {
        _appDetails[detail.id] = detail;
        _missingAppIds.remove(detail.id);
      }
      for (final missing in result.missingAppIds) {
        _missingAppIds.add(missing);
      }
      if (!_appDetails.containsKey(appId) &&
          !result.missingAppIds.contains(appId)) {
        _missingAppIds.add(appId);
      }
      _notify();
    } catch (error) {
      if (_disposed) {
        return;
      }
      _readingAppIds.remove(appId);
      targetSet.remove(appId);
      _appsError = '$error';
      _notify();
    }
  }
}

class _CustomizeSidebar extends StatefulWidget {
  const _CustomizeSidebar({
    required this.controller,
    required this.selectedSection,
    required this.onSelectSection,
  });

  final _EcosystemController controller;
  final _EcosystemSection selectedSection;
  final ValueChanged<_EcosystemSection> onSelectSection;

  @override
  State<_CustomizeSidebar> createState() => _CustomizeSidebarState();
}

class _CustomizeSidebarState extends State<_CustomizeSidebar> {
  final _installedSearchController = TextEditingController();
  final _installedSearchFocusNode = FocusNode(
    debugLabel: 'customize-installed-search',
  );
  final _searchToggleScopeNode = FocusNode(
    debugLabel: 'customize-installed-search-toggle-scope',
    canRequestFocus: false,
    skipTraversal: true,
  );
  var _showInstalledSearch = false;
  var _installedSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _installedSearchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _CustomizeSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _installedSearchController.clear();
      _installedSearchQuery = '';
      _showInstalledSearch = false;
    }
  }

  @override
  void dispose() {
    _installedSearchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _installedSearchFocusNode.dispose();
    _searchToggleScopeNode.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final next = _installedSearchController.text.trim();
    if (next != _installedSearchQuery && mounted) {
      setState(() => _installedSearchQuery = next);
    }
  }

  void _toggleInstalledSearch() {
    if (_showInstalledSearch) {
      _installedSearchController.clear();
      setState(() {
        _installedSearchQuery = '';
        _showInstalledSearch = false;
      });
      return;
    }
    setState(() => _showInstalledSearch = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showInstalledSearch) {
        _installedSearchFocusNode.requestFocus();
      }
    });
  }

  void _closeInstalledSearchAndRefocusTrigger() {
    _installedSearchController.clear();
    setState(() {
      _installedSearchQuery = '';
      _showInstalledSearch = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchToggleScopeNode.descendants
            .where((node) => node.canRequestFocus)
            .firstOrNull
            ?.requestFocus();
      }
    });
  }

  Widget _buildCountBadge(OfficialCodexThemeData theme, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: theme.textMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
    final controller = widget.controller;

    return ColoredBox(
      key: const ValueKey('customize-sidebar'),
      color: !theme.isDark
          ? OfficialCodexTheme.lightContextualSidebarBackground
          : palette.sidebar,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final queryLower = _installedSearchQuery.toLowerCase();
          final filteredInstalled = queryLower.isEmpty
              ? controller.installedPlugins
              : controller.installedPlugins
                    .where(
                      (plugin) =>
                          plugin.name.toLowerCase().contains(queryLower) ||
                          plugin.effectivePluginName.toLowerCase().contains(
                            queryLower,
                          ) ||
                          plugin.description.toLowerCase().contains(queryLower),
                    )
                    .toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: OfficialCodexTheme.contextualSidebarHeaderHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Customize',
                          key: const ValueKey('customize-sidebar-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                            letterSpacing: -0.15,
                          ),
                        ),
                      ),
                      Focus(
                        focusNode: _searchToggleScopeNode,
                        child: CodexIconButton(
                          key: const ValueKey(
                            'customize-installed-search-toggle',
                          ),
                          tooltip: 'Search installed plugins',
                          selected: _showInstalledSearch,
                          size: 28,
                          onPressed: _toggleInstalledSearch,
                          icon: const Icon(Icons.search_rounded, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showInstalledSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Focus(
                    onKeyEvent: (_, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        _closeInstalledSearchAndRefocusTrigger();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: ListenableBuilder(
                      listenable: _installedSearchFocusNode,
                      builder: (context, _) {
                        final focused = _installedSearchFocusNode.hasFocus;
                        return Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: theme.hoverTint,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: focused
                                  ? theme.focusRing
                                  : theme.hairlineBorder,
                              width: focused
                                  ? 1.5
                                  : OfficialCodexTheme.hairlineBorderWidth,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 15,
                                color: theme.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey(
                                    'customize-installed-search-field',
                                  ),
                                  controller: _installedSearchController,
                                  focusNode: _installedSearchFocusNode,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    hintText: 'Search installed plugins',
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: theme.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              if (_installedSearchQuery.isNotEmpty)
                                CodexIconButton(
                                  tooltip: 'Clear search',
                                  size: 22,
                                  onPressed: _installedSearchController.clear,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  key: const ValueKey('customize-sidebar-scroll'),
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                  children: [
                    KeyedSubtree(
                      key: const ValueKey('customize-section-nav'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CodexSidebarRow(
                            key: const ValueKey('customize-nav-plugins'),
                            title: 'Plugins',
                            leading: const Icon(Icons.widgets_outlined),
                            trailing: _buildCountBadge(
                              theme,
                              controller.sectionCountText(
                                _EcosystemSection.plugins,
                              ),
                            ),
                            selected:
                                widget.selectedSection ==
                                _EcosystemSection.plugins,
                            onTap: () => widget.onSelectSection(
                              _EcosystemSection.plugins,
                            ),
                          ),
                          const SizedBox(height: 1),
                          CodexSidebarRow(
                            key: const ValueKey('customize-nav-skills'),
                            title: 'Skills',
                            leading: const Icon(Icons.layers_outlined),
                            trailing: _buildCountBadge(
                              theme,
                              controller.sectionCountText(
                                _EcosystemSection.skills,
                              ),
                            ),
                            selected:
                                widget.selectedSection ==
                                _EcosystemSection.skills,
                            onTap: () => widget.onSelectSection(
                              _EcosystemSection.skills,
                            ),
                          ),
                          const SizedBox(height: 1),
                          CodexSidebarRow(
                            key: const ValueKey('customize-nav-apps'),
                            title: 'Apps',
                            leading: const Icon(Icons.apps_rounded),
                            trailing: _buildCountBadge(
                              theme,
                              controller.sectionCountText(
                                _EcosystemSection.apps,
                              ),
                            ),
                            selected:
                                widget.selectedSection ==
                                _EcosystemSection.apps,
                            onTap: () =>
                                widget.onSelectSection(_EcosystemSection.apps),
                          ),
                          const SizedBox(height: 1),
                          CodexSidebarRow(
                            key: const ValueKey('customize-nav-mcp'),
                            title: 'MCP',
                            leading: const Icon(Icons.hub_outlined),
                            trailing: _buildCountBadge(
                              theme,
                              controller.sectionCountText(
                                _EcosystemSection.mcp,
                              ),
                            ),
                            selected:
                                widget.selectedSection == _EcosystemSection.mcp,
                            onTap: () =>
                                widget.onSelectSection(_EcosystemSection.mcp),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 14, 8, 4),
                      child: Text(
                        'Installed',
                        key: const ValueKey('customize-installed-heading'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.textMuted,
                        ),
                      ),
                    ),
                    if (controller.pluginsLoadFailed)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Failed to load plugins',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: theme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            CodexButton(
                              key: const ValueKey('customize-installed-retry'),
                              size: CodexButtonSize.sm,
                              variant: CodexButtonVariant.secondary,
                              loading: controller.pluginsLoading,
                              onPressed: controller.pluginsLoading
                                  ? null
                                  : controller.retryPlugins,
                              label: 'Retry',
                            ),
                          ],
                        ),
                      )
                    else if (controller.pluginsLoading &&
                        controller.plugins.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          'Loading plugins...',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.textMuted,
                          ),
                        ),
                      )
                    else if (filteredInstalled.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          _installedSearchQuery.isNotEmpty
                              ? (controller.isPluginsIncomplete
                                    ? 'No matching loaded plugins'
                                    : 'No matching plugins')
                              : controller.pluginCatalogIsPartial
                              ? 'No installed plugins in incomplete catalog'
                              : controller.isPluginsAtCap
                              ? 'No installed plugins in loaded catalog'
                              : 'No installed plugins',
                          key: const ValueKey('customize-installed-empty'),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.textSecondary,
                          ),
                        ),
                      )
                    else ...[
                      for (final plugin in filteredInstalled) ...[
                        CodexSidebarRow(
                          key: ValueKey(
                            'customize-installed-plugin-${plugin.id}',
                          ),
                          title: plugin.name,
                          leading: const Icon(Icons.extension_outlined),
                          selected:
                              widget.selectedSection ==
                                  _EcosystemSection.plugins &&
                              controller.isPluginExpanded(plugin.id),
                          onTap: () {
                            widget.onSelectSection(_EcosystemSection.plugins);
                            unawaited(controller.selectAndExpandPlugin(plugin));
                          },
                        ),
                        const SizedBox(height: 1),
                      ],
                      if (controller.isPluginsIncomplete)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 8, 4),
                          child: Text(
                            controller.pluginCatalogIsPartial
                                ? 'Some plugin sources could not be loaded.'
                                : 'Showing installed plugins from first $maxBoundedEcosystemItems loaded entries.',
                            key: const ValueKey(
                              'customize-installed-incomplete-note',
                            ),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CustomizeWorkspaceView extends StatefulWidget {
  const _CustomizeWorkspaceView({
    required this.controller,
    required this.selectedSection,
    required this.sidebarCollapsed,
    required this.onSelectSection,
  });

  final _EcosystemController controller;
  final _EcosystemSection selectedSection;
  final bool sidebarCollapsed;
  final ValueChanged<_EcosystemSection> onSelectSection;

  @override
  State<_CustomizeWorkspaceView> createState() =>
      _CustomizeWorkspaceViewState();
}

class _CustomizeWorkspaceViewState extends State<_CustomizeWorkspaceView> {
  static const _maxPageContentWidth = 880.0;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'customize-workspace-search');
  var _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _CustomizeWorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.selectedSection != widget.selectedSection) {
      _searchController.clear();
      _searchQuery = '';
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    if (next != _searchQuery && mounted) {
      setState(() => _searchQuery = next);
    }
  }

  (String, String, String) _sectionMetadata(_EcosystemSection section) =>
      switch (section) {
        _EcosystemSection.plugins => (
          'Plugins',
          'Connect plugins to let Codex work across your tools',
          'Search plugins',
        ),
        _EcosystemSection.skills => (
          'Skills',
          'Extend Codex with task-specific skills',
          'Search skills',
        ),
        _EcosystemSection.apps => (
          'Apps',
          'Inspect connected apps and available tool catalogs',
          'Search apps',
        ),
        _EcosystemSection.mcp => (
          'MCP',
          'Manage Model Context Protocol servers, resources, and tools',
          'Search MCP servers',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final palette = ThemeTokens.of(context);
    final controller = widget.controller;
    final section = widget.selectedSection;
    final (title, subtitle, searchPlaceholder) = _sectionMetadata(section);

    return ColoredBox(
      key: const ValueKey('customize-workspace-view'),
      color: theme.workspaceBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = math.max(
            ThemeTokens.space6,
            (constraints.maxWidth - _maxPageContentWidth) / 2,
          );
          final compactHeaderControls = constraints.maxWidth < 680;
          return ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final searchField = Focus(
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape &&
                      _searchController.text.isNotEmpty) {
                    _searchController.clear();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: ListenableBuilder(
                  listenable: _searchFocusNode,
                  builder: (context, _) {
                    final focused = _searchFocusNode.hasFocus;
                    return Container(
                      width: compactHeaderControls ? null : 220,
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: focused
                              ? theme.focusRing
                              : theme.hairlineBorder,
                          width: focused
                              ? 1.5
                              : OfficialCodexTheme.hairlineBorderWidth,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 15,
                            color: theme.textMuted,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: TextField(
                              key: const ValueKey(
                                'customize-workspace-search-field',
                              ),
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textPrimary,
                              ),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                hintText: searchPlaceholder,
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: theme.textMuted,
                                ),
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            CodexIconButton(
                              tooltip: 'Clear search',
                              size: 20,
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close_rounded, size: 14),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );

              final refreshButton = CodexIconButton(
                key: const ValueKey('ecosystem-refresh-button'),
                tooltip: 'Refresh',
                onPressed: controller.isSectionLoading(section)
                    ? null
                    : () => controller.refresh(forceRefetch: true),
                icon: const Icon(Icons.refresh_rounded, size: 17),
              );

              final titleColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          key: const ValueKey('customize-page-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      if (controller.cwd.trim().isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Container(
                          key: const ValueKey('customize-context-chip'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.elevatedSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.hairlineBorder,
                              width: OfficialCodexTheme.hairlineBorderWidth,
                            ),
                          ),
                          child: Text(
                            _projectName(controller.cwd),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    key: const ValueKey('customize-page-subtitle'),
                    style: TextStyle(fontSize: 13, color: theme.textSecondary),
                  ),
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: const ValueKey('customize-workspace-header'),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      14,
                    ),
                    decoration: BoxDecoration(
                      color: theme.workspaceBackground,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.hairlineBorder,
                          width: OfficialCodexTheme.hairlineBorderWidth,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.sidebarCollapsed) ...[
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: CodexSegment<_EcosystemSection>(
                              key: const ValueKey('ecosystem-section-selector'),
                              items: [
                                CodexSegmentItem(
                                  value: _EcosystemSection.plugins,
                                  label: controller.sectionSegmentLabel(
                                    _EcosystemSection.plugins,
                                  ),
                                ),
                                CodexSegmentItem(
                                  value: _EcosystemSection.skills,
                                  label: controller.sectionSegmentLabel(
                                    _EcosystemSection.skills,
                                  ),
                                ),
                                CodexSegmentItem(
                                  value: _EcosystemSection.apps,
                                  label: controller.sectionSegmentLabel(
                                    _EcosystemSection.apps,
                                  ),
                                ),
                                CodexSegmentItem(
                                  value: _EcosystemSection.mcp,
                                  label: controller.sectionSegmentLabel(
                                    _EcosystemSection.mcp,
                                  ),
                                ),
                              ],
                              selectedValue: section,
                              onSelected: widget.onSelectSection,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (compactHeaderControls)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: titleColumn),
                                  const SizedBox(width: 8),
                                  refreshButton,
                                ],
                              ),
                              const SizedBox(height: 10),
                              searchField,
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: titleColumn),
                              const SizedBox(width: 12),
                              searchField,
                              const SizedBox(width: 6),
                              refreshButton,
                            ],
                          ),
                      ],
                    ),
                  ),
                  _EcosystemNoticesAndElicitationSlot(
                    controller: controller,
                    section: section,
                    horizontalPadding: horizontalPadding,
                    palette: palette,
                  ),
                  Expanded(
                    child: _EcosystemSectionBody(
                      controller: controller,
                      section: section,
                      searchQuery: _searchQuery,
                      horizontalPadding: horizontalPadding,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EcosystemDialog extends StatefulWidget {
  const _EcosystemDialog({
    required this.gateway,
    required this.cwd,
    this.threadId,
    this.threadController,
    this.userInputController,
    this.mcpOauthController,
  });

  final EcosystemGateway gateway;
  final String cwd;
  final String? threadId;
  final ThreadListController? threadController;
  final UserInputController? userInputController;
  final McpOauthController? mcpOauthController;

  @override
  State<_EcosystemDialog> createState() => _EcosystemDialogState();
}

class _EcosystemDialogState extends State<_EcosystemDialog> {
  late final _EcosystemController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _EcosystemController(
      gateway: widget.gateway,
      cwd: widget.cwd,
      threadId: widget.threadId,
      threadController: widget.threadController,
      userInputController: widget.userInputController,
      mcpOauthController: widget.mcpOauthController,
      isModal: true,
      initialSection: _EcosystemSection.skills,
    );
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
    return Dialog(
      backgroundColor: theme.modalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OfficialCodexTheme.popoverRadius),
        side: BorderSide(
          color: theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final section = _controller.section;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ThemeTokens.space6,
                    ThemeTokens.space4,
                    ThemeTokens.space3,
                    ThemeTokens.space3,
                  ),
                  child: LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final segment = CodexSegment<_EcosystemSection>(
                        key: const ValueKey('ecosystem-section-selector'),
                        items: [
                          CodexSegmentItem(
                            value: _EcosystemSection.skills,
                            label: _controller.sectionSegmentLabel(
                              _EcosystemSection.skills,
                            ),
                          ),
                          CodexSegmentItem(
                            value: _EcosystemSection.plugins,
                            label: _controller.sectionSegmentLabel(
                              _EcosystemSection.plugins,
                            ),
                          ),
                          CodexSegmentItem(
                            value: _EcosystemSection.apps,
                            label: _controller.sectionSegmentLabel(
                              _EcosystemSection.apps,
                            ),
                          ),
                          CodexSegmentItem(
                            value: _EcosystemSection.mcp,
                            label: _controller.sectionSegmentLabel(
                              _EcosystemSection.mcp,
                            ),
                          ),
                        ],
                        selectedValue: section,
                        onSelected: _controller.setSection,
                      );
                      final actions = <Widget>[
                        CodexIconButton(
                          key: const ValueKey('ecosystem-refresh-button'),
                          tooltip: 'Refresh',
                          onPressed: _controller.isSectionLoading(section)
                              ? null
                              : () => _controller.refresh(forceRefetch: true),
                          icon: const Icon(Icons.refresh_rounded, size: 17),
                        ),
                        CodexIconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ];
                      if (headerConstraints.maxWidth < 680) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.extension_outlined, size: 20),
                                const SizedBox(width: ThemeTokens.space2),
                                Expanded(
                                  child: Text(
                                    'Skills, Plugins & MCP',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                                ...actions,
                              ],
                            ),
                            const SizedBox(height: ThemeTokens.space2),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: segment,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          const Icon(Icons.extension_outlined, size: 20),
                          const SizedBox(width: ThemeTokens.space2),
                          Expanded(
                            child: Text(
                              'Skills, Plugins & MCP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          segment,
                          const SizedBox(width: ThemeTokens.space2),
                          ...actions,
                        ],
                      );
                    },
                  ),
                ),
                Divider(height: 1, color: palette.border),
                _EcosystemNoticesAndElicitationSlot(
                  controller: _controller,
                  section: section,
                  horizontalPadding: 20,
                  palette: palette,
                ),
                Expanded(
                  child: _EcosystemSectionBody(
                    controller: _controller,
                    section: section,
                    searchQuery: '',
                    horizontalPadding: ThemeTokens.space5,
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

class _EcosystemNoticesAndElicitationSlot extends StatelessWidget {
  const _EcosystemNoticesAndElicitationSlot({
    required this.controller,
    required this.section,
    required this.horizontalPadding,
    required this.palette,
  });

  final _EcosystemController controller;
  final _EcosystemSection section;
  final double horizontalPadding;
  final CodexPalette palette;

  @override
  Widget build(BuildContext context) {
    final error = controller.sectionError(section);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              0,
            ),
            child: KeyedSubtree(
              key: controller.sectionErrorKey(section),
              child: _InlineNotice(
                icon: Icons.error_outline_rounded,
                color: palette.danger,
                text: error,
              ),
            ),
          ),
        if (section == _EcosystemSection.plugins &&
            controller.pluginCatalogIsPartial &&
            !controller.pluginsLoadFailed)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              0,
            ),
            child: KeyedSubtree(
              key: const ValueKey('ecosystem-plugins-partial'),
              child: _InlineNotice(
                icon: Icons.warning_amber_rounded,
                color: palette.warning,
                text: 'The plugin catalog may be incomplete.',
              ),
            ),
          ),
        if (section == _EcosystemSection.plugins &&
            controller.pluginCatalogIsTruncated &&
            !controller.pluginsLoadFailed)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              0,
            ),
            child: KeyedSubtree(
              key: const ValueKey('ecosystem-plugins-truncated'),
              child: _InlineNotice(
                icon: Icons.info_outline_rounded,
                color: palette.textSecondary,
                text:
                    'Showing the first ${controller.plugins.length} catalog entries.',
              ),
            ),
          ),
        if (controller.pluginActionNotice case final notice?
            when section == _EcosystemSection.plugins)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              0,
            ),
            child: KeyedSubtree(
              key: const ValueKey('plugin-install-auth-notice'),
              child: _InlineNotice(
                icon: Icons.info_outline_rounded,
                color: palette.accent,
                text: notice,
              ),
            ),
          ),
        if (controller.mcpNotice case final notice?
            when section == _EcosystemSection.mcp)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              0,
            ),
            child: KeyedSubtree(
              key: const ValueKey('mcp-action-notice'),
              child: _InlineNotice(
                icon: notice.startsWith('Reload failed')
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: notice.startsWith('Reload failed')
                    ? palette.danger
                    : palette.accent,
                text: notice,
              ),
            ),
          ),
        if (controller.userInputController case final userInputController?)
          AnimatedBuilder(
            animation: userInputController,
            builder: (context, _) {
              final directElicitations = controller.activeDirectMcpElicitations(
                userInputController,
              );
              final activeDirectElicitation = directElicitations.firstOrNull;
              if (activeDirectElicitation == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                key: const ValueKey('ecosystem-modal-elicitation-slot'),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  0,
                ),
                child: _McpElicitationCard(
                  key: ValueKey(
                    'mcp-elicitation-${activeDirectElicitation.requestId}',
                  ),
                  controller: userInputController,
                  request: activeDirectElicitation,
                  pendingCount: directElicitations.length,
                  errorMessage: userInputController.errorMessage,
                  margin: EdgeInsets.zero,
                  maxFieldsHeight: 180,
                ),
              );
            },
          ),
      ],
    );
  }
}

class _EcosystemSectionBody extends StatelessWidget {
  const _EcosystemSectionBody({
    required this.controller,
    required this.section,
    required this.searchQuery,
    required this.horizontalPadding,
  });

  final _EcosystemController controller;
  final _EcosystemSection section;
  final String searchQuery;
  final double horizontalPadding;

  String get _normalizedQuery => searchQuery.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    if (section == _EcosystemSection.apps) {
      return _buildAppsList(context);
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        ThemeTokens.space5,
        horizontalPadding,
        ThemeTokens.space5,
      ),
      child: switch (section) {
        _EcosystemSection.skills => _buildSkillsList(context),
        _EcosystemSection.plugins => _buildPluginsList(context),
        _EcosystemSection.apps => const SizedBox.shrink(),
        _EcosystemSection.mcp => _buildMcpList(context),
      },
    );
  }

  Widget _buildSkillsList(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final skills = controller.skills;
    if (skills.isEmpty) {
      if (controller.skillsLoading) {
        return Row(
          key: const ValueKey('ecosystem-skills-loading'),
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: ThemeTokens.space2),
            Text(
              'Loading skills...',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.textMuted),
            ),
          ],
        );
      }
      if (controller.skillsLoadFailed) {
        return Text(
          'Unable to load workspace skills.',
          key: const ValueKey('ecosystem-skills-unavailable'),
          style: Theme.of(context).textTheme.bodySmall,
        );
      }
      return Text(
        'No skills discovered in this workspace.',
        key: const ValueKey('ecosystem-skills-empty'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final query = _normalizedQuery;
    final filtered = query.isEmpty
        ? skills
        : skills
              .where(
                (skill) =>
                    skill.name.toLowerCase().contains(query) ||
                    skill.description.toLowerCase().contains(query) ||
                    skill.scope.toLowerCase().contains(query) ||
                    skill.path.toLowerCase().contains(query),
              )
              .toList(growable: false);
    if (filtered.isEmpty) {
      return Text(
        controller.isSkillsAtCap
            ? 'No matching loaded skills'
            : 'No skills found',
        key: const ValueKey('ecosystem-skills-search-empty'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final skill in filtered)
          Container(
            key: ValueKey('skill-row-${skill.name}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceRaised,
              border: Border.all(
                color: palette.border,
                width: OfficialCodexTheme.hairlineBorderWidth,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '\$${skill.name}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            skill.scope,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: palette.textMuted),
                          ),
                        ],
                      ),
                      if (skill.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          skill.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        skill.path,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CodexButton(
                  key: ValueKey('skill-toggle-${skill.name}'),
                  size: CodexButtonSize.sm,
                  variant: skill.enabled
                      ? CodexButtonVariant.secondary
                      : CodexButtonVariant.ghost,
                  loading: controller.isSkillMutating(skill.path),
                  onPressed:
                      controller.skillsLoading ||
                          controller.isSkillMutating(skill.path)
                      ? null
                      : () => controller.toggleSkill(skill),
                  label: skill.enabled ? 'Enabled' : 'Disabled',
                ),
              ],
            ),
          ),
        if (controller.isSkillsAtCap)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing first $maxBoundedEcosystemItems loaded skills.',
              key: const ValueKey('ecosystem-skills-bound-notice'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _buildPluginsList(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final catalogSupported = controller.catalogGateway != null;
    final plugins = controller.plugins;
    if (plugins.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!catalogSupported)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: KeyedSubtree(
                key: const ValueKey('ecosystem-plugins-lifecycle-unsupported'),
                child: _InlineNotice(
                  icon: Icons.lock_outline_rounded,
                  color: palette.textSecondary,
                  text: 'Plugin detail inspection and install/uninstall mutations require a local app-server catalog backend.',
                ),
              ),
            ),
          if (controller.pluginsLoading)
            Row(
              key: const ValueKey('ecosystem-plugins-loading'),
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: ThemeTokens.space2),
                Text(
                  'Loading plugin catalog...',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ],
            )
          else if (controller.pluginsLoadFailed)
            Text(
              'Unable to load plugin catalog.',
              key: const ValueKey('ecosystem-plugins-unavailable'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else if (controller.pluginCatalogIsPartial)
            Text(
              'No plugin entries are available.',
              key: const ValueKey('ecosystem-plugins-partial-empty'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Text(
              'No plugin entries returned.',
              key: const ValueKey('ecosystem-plugins-empty'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      );
    }
    final query = _normalizedQuery;
    final filtered = query.isEmpty
        ? plugins
        : plugins
              .where(
                (plugin) =>
                    plugin.name.toLowerCase().contains(query) ||
                    plugin.effectivePluginName.toLowerCase().contains(query) ||
                    plugin.description.toLowerCase().contains(query) ||
                    (plugin.marketplaceName?.toLowerCase().contains(query) ??
                        false) ||
                    (plugin.sourceType?.toLowerCase().contains(query) ?? false),
              )
              .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!catalogSupported)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: KeyedSubtree(
              key: const ValueKey('ecosystem-plugins-lifecycle-unsupported'),
              child: _InlineNotice(
                icon: Icons.lock_outline_rounded,
                color: palette.textSecondary,
                text: 'Plugin detail inspection and install/uninstall mutations require a local app-server catalog backend.',
              ),
            ),
          ),
        if (filtered.isEmpty)
          Text(
            controller.isPluginsIncomplete
                ? 'No matching loaded plugins'
                : 'No matching plugins',
            key: const ValueKey('ecosystem-plugins-search-empty'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else ...[
          for (final plugin in filtered)
            Container(
              key: ValueKey('plugin-row-${plugin.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surfaceRaised,
                border: Border.all(
                  color: palette.border,
                  width: OfficialCodexTheme.hairlineBorderWidth,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  plugin.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (plugin.version case final version?
                                    when version.isNotEmpty)
                                  Text(
                                    'v$version',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: palette.textMuted),
                                  ),
                                if (plugin.marketplaceName case final mpName?
                                    when mpName.isNotEmpty)
                                  Text(
                                    mpName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: palette.textMuted),
                                  ),
                                if (plugin.sourceType case final sourceType?
                                    when sourceType.isNotEmpty)
                                  Text(
                                    sourceType,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: palette.textMuted),
                                  ),
                              ],
                            ),
                            if (plugin.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                plugin.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (plugin.disabledReason case final reason?
                                when reason.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Unavailable: $reason',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: palette.danger),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            plugin.installed
                                ? (plugin.enabled ? 'Enabled' : 'Disabled')
                                : 'Not installed',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          if (catalogSupported) ...[
                            const SizedBox(width: 8),
                            CodexButton(
                              key: ValueKey('plugin-read-${plugin.id}'),
                              size: CodexButtonSize.sm,
                              variant: CodexButtonVariant.ghost,
                              loading: controller.isPluginReading(plugin.id),
                              onPressed:
                                  controller.pluginsLoading ||
                                      controller.hasPluginsRefreshInFlight ||
                                      controller.isPluginReading(plugin.id)
                                  ? null
                                  : () =>
                                        controller.togglePluginDetails(plugin),
                              label: controller.isPluginExpanded(plugin.id)
                                  ? 'Hide details'
                                  : 'Details',
                            ),
                            const SizedBox(width: 6),
                            if (!plugin.installed)
                              CodexButton(
                                key: ValueKey('plugin-install-${plugin.id}'),
                                size: CodexButtonSize.sm,
                                variant: CodexButtonVariant.secondary,
                                loading: controller.isPluginMutating(plugin.id),
                                onPressed:
                                    !controller.pluginsLoading &&
                                        !controller.hasPluginsRefreshInFlight &&
                                        plugin.canInstall &&
                                        !controller.hasMutatingPlugins
                                    ? () => controller.installPlugin(plugin)
                                    : null,
                                label: 'Install',
                              )
                            else
                              CodexButton(
                                key: ValueKey('plugin-uninstall-${plugin.id}'),
                                size: CodexButtonSize.sm,
                                variant: CodexButtonVariant.ghost,
                                loading: controller.isPluginMutating(plugin.id),
                                onPressed:
                                    !controller.pluginsLoading &&
                                        !controller.hasPluginsRefreshInFlight &&
                                        plugin.canUninstall &&
                                        !controller.hasMutatingPlugins
                                    ? () => controller.uninstallPlugin(plugin)
                                    : null,
                                label: 'Uninstall',
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (controller.isPluginExpanded(plugin.id))
                    _buildPluginDetailSection(context, plugin),
                ],
              ),
            ),
          if (controller.isPluginsAtCap &&
              (!controller.pluginCatalogIsTruncated ||
                  controller.pluginsLoadFailed))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Showing first $maxBoundedEcosystemItems loaded plugins.',
                key: const ValueKey('ecosystem-plugins-bound-notice'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.textMuted),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPluginDetailSection(
    BuildContext context,
    PluginSummaryModel plugin,
  ) {
    final palette = ThemeTokens.of(context);
    final detail = controller.pluginDetail(plugin.id);
    if (detail == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    return Container(
      key: ValueKey('plugin-detail-${plugin.id}'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: palette.border,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.description.isNotEmpty) ...[
            Text(
              detail.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
          ],
          Text(
            'Marketplace: ${detail.marketplaceName}'
            '${detail.marketplacePath != null ? ' · ${detail.marketplacePath}' : ''}',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.textMuted, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 6),
          Text(
            'Skills (${detail.skills.length}) · Apps (${detail.apps.length}) · '
            'MCP (${detail.mcpServers.length}) · Hooks (${detail.hooks.length})',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.textSecondary),
          ),
          if (detail.skills.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Bundled skills: ${detail.skills.map((s) => '\$${s.name}').join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (detail.apps.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Linked apps: ${detail.apps.map((a) => a.name).join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (detail.mcpServers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'MCP servers: ${detail.mcpServers.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppsList(BuildContext context) {
    final palette = ThemeTokens.of(context);
    if (controller.catalogGateway == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          ThemeTokens.space5,
          horizontalPadding,
          ThemeTokens.space5,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: KeyedSubtree(
            key: const ValueKey('ecosystem-catalog-unsupported'),
            child: _InlineNotice(
              icon: Icons.lock_outline_rounded,
              color: palette.textSecondary,
              text: 'Apps catalog and connector runtime inspection are unavailable on this backend.',
            ),
          ),
        ),
      );
    }
    final query = _normalizedQuery;
    final allInstalled = controller.installedApps;
    final allCatalog = controller.catalogApps;
    final filteredInstalled = query.isEmpty
        ? allInstalled
        : allInstalled
              .where(
                (app) =>
                    app.displayName.toLowerCase().contains(query) ||
                    app.id.toLowerCase().contains(query),
              )
              .toList(growable: false);
    final filteredCatalog = query.isEmpty
        ? allCatalog
        : allCatalog
              .where(
                (app) =>
                    app.name.toLowerCase().contains(query) ||
                    app.id.toLowerCase().contains(query) ||
                    app.description.toLowerCase().contains(query) ||
                    (app.category?.toLowerCase().contains(query) ?? false) ||
                    (app.developer?.toLowerCase().contains(query) ?? false),
              )
              .toList(growable: false);

    return CustomScrollView(
      key: const ValueKey('ecosystem-apps-scroll'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            ThemeTokens.space5,
            horizontalPadding,
            0,
          ),
          sliver: SliverList.list(
            children: [
              if (controller.appsError case final appsError?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: KeyedSubtree(
                    key: const ValueKey('ecosystem-apps-error'),
                    child: _InlineNotice(
                      icon: Icons.error_outline_rounded,
                      color: palette.danger,
                      text: appsError,
                    ),
                  ),
                ),
              Text(
                'Installed Connector Runtime (${controller.isInstalledAppsAtCap ? '${allInstalled.length} loaded' : '${allInstalled.length}'})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (allInstalled.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    controller.appsLoading
                        ? 'Loading installed connector runtime...'
                        : controller.installedAppsLoadFailed
                        ? 'Unable to load installed connector runtime.'
                        : 'No installed connector runtime apps in the committed snapshot.',
                    key: ValueKey(
                      controller.appsLoading
                          ? 'ecosystem-installed-apps-loading'
                          : controller.installedAppsLoadFailed
                          ? 'ecosystem-installed-apps-unavailable'
                          : 'ecosystem-installed-apps-empty',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else if (filteredInstalled.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    controller.isInstalledAppsAtCap
                        ? 'No matching loaded installed connector apps.'
                        : 'No matching installed connector apps.',
                    key: const ValueKey(
                      'ecosystem-installed-apps-search-empty',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        if (filteredInstalled.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              12,
            ),
            sliver: SliverList.builder(
              itemCount: filteredInstalled.length,
              itemBuilder: (context, index) =>
                  _buildInstalledAppCard(context, filteredInstalled[index]),
            ),
          ),
        if (controller.isInstalledAppsAtCap)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              12,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Showing first $maxBoundedEcosystemItems loaded installed connector apps.',
                key: const ValueKey('ecosystem-installed-apps-bound-notice'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.textMuted),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'App Catalog (${controller.isCatalogAppsIncomplete ? '${allCatalog.length} loaded' : '${allCatalog.length}'})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (controller.appsLoading)
                    const SizedBox(
                      key: ValueKey('ecosystem-apps-loading'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (allCatalog.isEmpty && !controller.appsLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: ThemeTokens.space5),
                  child: Text(
                    controller.catalogAppsLoadFailed
                        ? 'Unable to load app catalog.'
                        : 'No catalog apps returned.',
                    key: ValueKey(
                      controller.catalogAppsLoadFailed
                          ? 'ecosystem-apps-unavailable'
                          : 'ecosystem-apps-empty',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else if (allCatalog.isEmpty && controller.appsLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: ThemeTokens.space5),
                  child: Text(
                    'Loading app catalog...',
                    key: const ValueKey('ecosystem-apps-loading-label'),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: palette.textMuted),
                  ),
                )
              else if (filteredCatalog.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: ThemeTokens.space5),
                  child: Text(
                    controller.isCatalogAppsIncomplete
                        ? 'No matching loaded catalog apps.'
                        : 'No matching catalog apps.',
                    key: const ValueKey('ecosystem-apps-search-empty'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        if (filteredCatalog.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            sliver: SliverList.builder(
              itemCount: filteredCatalog.length,
              itemBuilder: (context, index) =>
                  _buildCatalogAppCard(context, filteredCatalog[index]),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            ThemeTokens.space5,
          ),
          sliver: SliverList.list(
            children: [
              if (controller.appsNextCursor != null &&
                  allCatalog.length < maxBoundedEcosystemItems)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: CodexButton(
                      key: const ValueKey('ecosystem-apps-load-more'),
                      size: CodexButtonSize.sm,
                      variant: CodexButtonVariant.secondary,
                      loading: controller.loadingMoreApps,
                      onPressed: controller.loadingMoreApps
                          ? null
                          : controller.loadMoreApps,
                      label: 'Load more apps',
                    ),
                  ),
                )
              else if (allCatalog.length >= maxBoundedEcosystemItems)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Showing first $maxBoundedEcosystemItems loaded catalog apps.',
                    key: const ValueKey('ecosystem-apps-bound-notice'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: palette.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstalledAppCard(
    BuildContext context,
    InstalledAppSnapshotModel installed,
  ) {
    final palette = ThemeTokens.of(context);
    final summaryColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          installed.displayName,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 2),
        Text(
          installed.id,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: palette.textMuted, fontFamily: 'monospace'),
        ),
      ],
    );
    final trailingControls = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${installed.enabled ? 'Enabled' : 'Disabled'} · '
          '${installed.callable ? 'Callable' : 'Not callable'}',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: palette.textSecondary),
        ),
        CodexButton(
          key: ValueKey('installed-app-read-${installed.id}'),
          size: CodexButtonSize.sm,
          variant: CodexButtonVariant.ghost,
          loading: controller.isAppReading(installed.id),
          onPressed: controller.isAppReading(installed.id)
              ? null
              : () => controller.toggleAppDetails(
                  installed.id,
                  installedSection: true,
                ),
          label: controller.isInstalledAppExpanded(installed.id)
              ? 'Hide details'
              : 'Details',
        ),
      ],
    );

    return Container(
      key: ValueKey('installed-app-row-${installed.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border.all(
          color: palette.border,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 460) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summaryColumn,
                    const SizedBox(height: 8),
                    trailingControls,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: summaryColumn),
                  const SizedBox(width: 12),
                  trailingControls,
                ],
              );
            },
          ),
          if (controller.isInstalledAppExpanded(installed.id))
            _buildAppDetailSection(context, installed.id),
        ],
      ),
    );
  }

  Widget _buildCatalogAppCard(BuildContext context, AppSummaryModel app) {
    final palette = ThemeTokens.of(context);
    final summaryColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(app.name, style: Theme.of(context).textTheme.titleSmall),
            if (app.category case final category? when category.isNotEmpty)
              Text(
                category,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.textMuted),
              ),
            if (app.developer case final developer? when developer.isNotEmpty)
              Text(
                developer,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.textMuted),
              ),
          ],
        ),
        if (app.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(app.description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
    final trailingControls = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${app.isAccessible ? 'Accessible' : 'Unlinked'} · '
          '${app.isEnabled ? 'Enabled' : 'Disabled'}',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: palette.textSecondary),
        ),
        CodexButton(
          key: ValueKey('app-read-${app.id}'),
          size: CodexButtonSize.sm,
          variant: CodexButtonVariant.ghost,
          loading: controller.isAppReading(app.id),
          onPressed: controller.isAppReading(app.id)
              ? null
              : () => controller.toggleAppDetails(
                  app.id,
                  installedSection: false,
                ),
          label: controller.isCatalogAppExpanded(app.id)
              ? 'Hide details'
              : 'Details',
        ),
      ],
    );

    return Container(
      key: ValueKey('app-row-${app.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border.all(
          color: palette.border,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 460) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summaryColumn,
                    const SizedBox(height: 8),
                    trailingControls,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: summaryColumn),
                  const SizedBox(width: 12),
                  trailingControls,
                ],
              );
            },
          ),
          if (controller.isCatalogAppExpanded(app.id))
            _buildAppDetailSection(context, app.id),
        ],
      ),
    );
  }

  Widget _buildAppDetailSection(BuildContext context, String appId) {
    final palette = ThemeTokens.of(context);
    final detail = controller.appDetail(appId);
    if (controller.isAppReading(appId) && detail == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (controller.isAppMissing(appId) && detail == null) {
      return Container(
        key: ValueKey('app-detail-missing-$appId'),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: palette.border,
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
        child: Text(
          'No catalog metadata found for $appId.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    if (detail == null) {
      return const SizedBox.shrink();
    }
    const maxTools = _EcosystemController._maxDisplayedAppTools;
    final displayedTools = detail.toolSummaries
        .take(maxTools)
        .toList(growable: false);
    return Container(
      key: ValueKey('app-detail-$appId'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: palette.border,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.description.isNotEmpty) ...[
            Text(
              detail.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
          ],
          if (detail.distributionChannel case final channel?
              when channel.isNotEmpty)
            Text(
              'Channel: $channel',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.textMuted),
            ),
          if (detail.pluginDisplayNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Plugins: ${detail.pluginDisplayNames.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Tools (${detail.toolSummaries.length})',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.textSecondary),
          ),
          for (final tool in displayedTools)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• ${tool.name}${tool.isReadOnly ? ' (read-only)' : ''}'
                '${!tool.isEnabled ? ' [disabled]' : ''}: ${tool.description}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (detail.toolSummaries.length > maxTools)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Showing first $maxTools of ${detail.toolSummaries.length} tools.',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMcpList(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final gateway = controller.mcpGateway;
    final servers = controller.mcpServers;
    final oauth = controller.mcpOauthController;
    final query = _normalizedQuery;
    final filtered = query.isEmpty
        ? servers
        : servers
              .where(
                (server) =>
                    server.name.toLowerCase().contains(query) ||
                    server.status.toLowerCase().contains(query) ||
                    (server.authStatus?.toLowerCase().contains(query) ?? false),
              )
              .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                gateway == null
                    ? 'MCP execution is unavailable on this transport.'
                    : 'Inspect resources or call tools without embedding a web runtime.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.textSecondary),
              ),
            ),
            const SizedBox(width: ThemeTokens.space2),
            CodexButton(
              key: const ValueKey('mcp-reload-button'),
              variant: CodexButtonVariant.secondary,
              size: CodexButtonSize.sm,
              loading: controller.reloadingMcp,
              onPressed:
                  gateway == null ||
                      controller.reloadingMcp ||
                      (oauth?.busy ?? false) ||
                      controller.mcpLoading
                  ? null
                  : controller.reloadMcpServers,
              label: 'Reload config',
            ),
          ],
        ),
        const SizedBox(height: ThemeTokens.space3),
        if (oauth?.message case final message?) ...[
          Semantics(
            liveRegion: true,
            child: KeyedSubtree(
              key: const ValueKey('mcp-oauth-notice'),
              child: _InlineNotice(
                icon: Icons.open_in_browser_rounded,
                color: oauth!.phase == McpOauthPhase.failed
                    ? palette.danger
                    : palette.textSecondary,
                text: oauth.serverName == null
                    ? message
                    : '${oauth.serverName}: $message',
              ),
            ),
          ),
          const SizedBox(height: ThemeTokens.space2),
          Wrap(
            spacing: ThemeTokens.space2,
            runSpacing: ThemeTokens.space2,
            children: [
              if (oauth.busy)
                CodexButton(
                  key: const ValueKey('mcp-oauth-open-browser'),
                  variant: CodexButtonVariant.secondary,
                  size: CodexButtonSize.sm,
                  loading: oauth.openingBrowser,
                  onPressed: oauth.canOpenBrowser ? oauth.openBrowser : null,
                  label: 'Open browser',
                ),
              CodexButton(
                key: const ValueKey('mcp-oauth-refresh-status'),
                variant: CodexButtonVariant.secondary,
                size: CodexButtonSize.sm,
                loading: controller.mcpLoading,
                onPressed: controller.mcpLoading
                    ? null
                    : () => controller._refreshMcp(forceRefetch: true),
                label: 'Refresh status',
              ),
              if (!oauth.busy)
                CodexButton(
                  key: const ValueKey('mcp-oauth-dismiss'),
                  variant: CodexButtonVariant.ghost,
                  size: CodexButtonSize.sm,
                  onPressed: oauth.clearNotice,
                  label: 'Dismiss',
                ),
            ],
          ),
          const SizedBox(height: ThemeTokens.space3),
        ],
        if (servers.isEmpty)
          if (controller.mcpLoading)
            Row(
              key: const ValueKey('ecosystem-mcp-loading'),
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: ThemeTokens.space2),
                Text(
                  'Loading MCP servers...',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: palette.textMuted),
                ),
              ],
            )
          else if (controller.mcpLoadFailed)
            Text(
              'Unable to load MCP server status.',
              key: const ValueKey('ecosystem-mcp-unavailable'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Text(
              'No MCP servers configured.',
              key: const ValueKey('ecosystem-mcp-empty'),
              style: Theme.of(context).textTheme.bodySmall,
            )
        else if (filtered.isEmpty)
          Text(
            controller.isMcpAtCap
                ? 'No matching loaded MCP servers.'
                : 'No matching MCP servers.',
            key: const ValueKey('ecosystem-mcp-search-empty'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else ...[
          for (final server in filtered)
            Builder(
              builder: (context) {
                final runtimeStatus = server.status.trim();
                final authStatus = server.authStatus?.trim();
                return Container(
                  key: ValueKey('mcp-row-${server.name}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surfaceRaised,
                    border: Border.all(
                      color: palette.border,
                      width: OfficialCodexTheme.hairlineBorderWidth,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  server.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${server.toolCount} tools · ${server.resourceCount} resources',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (authStatus != null &&
                                    authStatus.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Auth: $authStatus',
                                    key: ValueKey(
                                      'mcp-auth-status-${server.name}',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: palette.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (runtimeStatus.isNotEmpty)
                            Text(
                              runtimeStatus,
                              key: ValueKey('mcp-status-${server.name}'),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: palette.textSecondary),
                            ),
                        ],
                      ),
                      const SizedBox(height: ThemeTokens.space2),
                      Wrap(
                        spacing: ThemeTokens.space2,
                        runSpacing: ThemeTokens.space2,
                        children: [
                          if (oauth != null &&
                              oauth.available &&
                              authStatus == 'notLoggedIn')
                            CodexButton(
                              key: ValueKey('mcp-oauth-sign-in-${server.name}'),
                              variant: CodexButtonVariant.secondary,
                              size: CodexButtonSize.sm,
                              loading:
                                  oauth.busy && oauth.serverName == server.name,
                              onPressed:
                                  oauth.busy ||
                                      controller.mcpLoading ||
                                      controller.reloadingMcp
                                  ? null
                                  : () => oauth.signIn(server.name),
                              label: 'Authenticate',
                            ),
                          CodexButton(
                            key: ValueKey('mcp-read-resource-${server.name}'),
                            variant: CodexButtonVariant.secondary,
                            size: CodexButtonSize.sm,
                            loading:
                                controller.mcpBusyServer == server.name &&
                                controller.mcpBusyOperation ==
                                    _McpOperationKind.readResource,
                            onPressed:
                                gateway == null ||
                                    controller.mcpBusyServer != null
                                ? null
                                : () => controller.readMcpResource(
                                    context,
                                    server,
                                  ),
                            label: 'Read resource',
                          ),
                          CodexButton(
                            key: ValueKey('mcp-call-tool-${server.name}'),
                            variant: CodexButtonVariant.secondary,
                            size: CodexButtonSize.sm,
                            loading:
                                controller.mcpBusyServer == server.name &&
                                controller.mcpBusyOperation ==
                                    _McpOperationKind.callTool,
                            onPressed:
                                gateway == null ||
                                    controller.mcpBusyServer != null
                                ? null
                                : () => controller.callMcpTool(context, server),
                            label: 'Call tool',
                          ),
                        ],
                      ),
                      if (controller.mcpError(server.name)
                          case final error?) ...[
                        const SizedBox(height: ThemeTokens.space2),
                        SelectableText(
                          error,
                          key: ValueKey('mcp-error-${server.name}'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palette.danger),
                        ),
                      ],
                      if (controller.mcpResult(server.name)
                          case final result?) ...[
                        const SizedBox(height: ThemeTokens.space3),
                        _McpOperationResult(
                          key: ValueKey('mcp-result-${server.name}'),
                          result: result,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          if (controller.isMcpAtCap)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Showing first $maxBoundedEcosystemItems loaded MCP servers.',
                key: const ValueKey('ecosystem-mcp-bound-notice'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.textMuted),
              ),
            ),
        ],
      ],
    );
  }
}

class _McpResourceReadDialog extends StatefulWidget {
  const _McpResourceReadDialog({required this.serverName});

  final String serverName;

  @override
  State<_McpResourceReadDialog> createState() => _McpResourceReadDialogState();
}

class _McpResourceReadDialogState extends State<_McpResourceReadDialog> {
  final _uriController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _uriController.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _uriController
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Read from ${widget.serverName}'),
    content: SizedBox(
      width: 520,
      child: TextField(
        key: const ValueKey('mcp-resource-uri-field'),
        controller: _uriController,
        autofocus: true,
        maxLength: 4096,
        decoration: const InputDecoration(
          labelText: 'Resource URI',
          hintText: 'file:///workspace/README.md',
          helperText: 'The server decides which URI schemes it supports.',
        ),
        onSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      CodexButton(
        variant: CodexButtonVariant.ghost,
        size: CodexButtonSize.sm,
        onPressed: () => Navigator.of(context).pop(),
        label: 'Cancel',
      ),
      CodexButton(
        key: const ValueKey('mcp-resource-read-submit'),
        variant: CodexButtonVariant.primary,
        size: CodexButtonSize.sm,
        onPressed: _uriController.text.trim().isEmpty ? null : _submit,
        label: 'Read',
      ),
    ],
  );

  void _submit() {
    final uri = _uriController.text.trim();
    if (uri.isNotEmpty) {
      Navigator.of(context).pop(uri);
    }
  }
}

class _McpToolCallDialog extends StatefulWidget {
  const _McpToolCallDialog({required this.serverName});

  final String serverName;

  @override
  State<_McpToolCallDialog> createState() => _McpToolCallDialogState();
}

class _McpToolCallDialogState extends State<_McpToolCallDialog> {
  final _toolController = TextEditingController();
  final _argumentsController = TextEditingController(text: '{}');
  String? _error;

  @override
  void initState() {
    super.initState();
    _toolController.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _toolController
      ..removeListener(_changed)
      ..dispose();
    _argumentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Call a tool on ${widget.serverName}'),
    content: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('mcp-tool-name-field'),
            controller: _toolController,
            autofocus: true,
            maxLength: 256,
            decoration: const InputDecoration(labelText: 'Tool name'),
          ),
          const SizedBox(height: ThemeTokens.space2),
          TextField(
            key: const ValueKey('mcp-tool-arguments-field'),
            controller: _argumentsController,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Arguments (JSON object)',
              alignLabelWithHint: true,
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: ThemeTokens.space2),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: ThemeTokens.of(context).danger),
            ),
          ],
        ],
      ),
    ),
    actions: [
      CodexButton(
        variant: CodexButtonVariant.ghost,
        size: CodexButtonSize.sm,
        onPressed: () => Navigator.of(context).pop(),
        label: 'Cancel',
      ),
      CodexButton(
        key: const ValueKey('mcp-tool-call-submit'),
        variant: CodexButtonVariant.primary,
        size: CodexButtonSize.sm,
        onPressed: _toolController.text.trim().isEmpty ? null : _submit,
        label: 'Call tool',
      ),
    ],
  );

  void _submit() {
    try {
      final decoded = jsonDecode(_argumentsController.text);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Arguments must be a JSON object.');
      }
      Navigator.of(context).pop((
        tool: _toolController.text.trim(),
        args: Map<String, Object?>.unmodifiable(decoded),
      ));
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = '$error');
    }
  }
}

class _McpOperationResult extends StatelessWidget {
  const _McpOperationResult({super.key, required this.result});

  final Object result;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(ThemeTokens.space2),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: switch (result) {
        final McpResourceReadResultModel value => _resourceResult(
          context,
          value,
        ),
        final McpToolCallResultModel value => _toolResult(context, value),
        _ => Text('$result'),
      },
    );
  }

  Widget _resourceResult(
    BuildContext context,
    McpResourceReadResultModel value,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Resource contents (${value.contents.length})',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      for (final content in value.contents) ...[
        const SizedBox(height: ThemeTokens.space2),
        Text(
          '${content.uri}${content.mimeType == null ? '' : ' · ${content.mimeType}'}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: ThemeTokens.space1),
        switch (content) {
          final McpTextResourceContentModel text => SelectableText(
            text.text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          final McpBlobResourceContentModel blob => Text(
            'Binary payload omitted from UI state '
            '(${blob.encodedLength} encoded characters).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        },
      ],
    ],
  );

  Widget _toolResult(BuildContext context, McpToolCallResultModel value) {
    final palette = ThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          value.isError ? 'Tool returned an error' : 'Tool result',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: value.isError ? palette.danger : null),
        ),
        for (final content in value.content) ...[
          const SizedBox(height: ThemeTokens.space2),
          Text(content.summary, style: Theme.of(context).textTheme.labelSmall),
          if (content.text case final text?) ...[
            const SizedBox(height: ThemeTokens.space1),
            SelectableText(text, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
        if (value.structuredContentPreview case final structured?) ...[
          const SizedBox(height: ThemeTokens.space2),
          Text(
            'Structured content',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: ThemeTokens.space1),
          SelectableText(
            structured,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
