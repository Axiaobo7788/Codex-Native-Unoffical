part of '../codex_native_app.dart';

class _ThreadPanel extends StatefulWidget {
  const _ThreadPanel({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.runtimeController,
    required this.defaultWorkingDirectory,
    this.userInputController,
    this.hasNavigationRail = false,
    this.onThreadSelected,
  });

  final ThreadListController controller;
  final ExecutionSettingsController settingsController;
  final RuntimeController runtimeController;
  final String defaultWorkingDirectory;
  final UserInputController? userInputController;
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
                  padding: const EdgeInsets.fromLTRB(18, 8, 8, 2),
                  child: _ThreadCatalogHeader(
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
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
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
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
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
    }
    await widget.controller.startThread(
      widget.settingsController.threadOptions(cwd),
    );
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
    required this.revealActions,
    required this.title,
    required this.actions,
  });

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
  });

  final String directory;
  final int count;
  final bool collapsed;
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

  @override
  Widget build(BuildContext context) {
    final heading = widget.heading;
    final palette = ThemeTokens.of(context);
    final leadingIcon = heading.collapsed
        ? Icons.folder_outlined
        : Icons.folder_open_outlined;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (focused) => setState(() => _focusWithin = focused),
        child: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(0),
            child: CodexSidebarRow(
              height: 32.0,
              tooltip: heading.directory,
              title: _projectName(heading.directory),
              leading: Icon(
                leadingIcon,
                size: 15,
                color: palette.textSecondary,
              ),
              onTap: widget.onToggleCollapse,
              trailingBuilder: (context, hovered) {
                final count = Text(
                  '${heading.count}',
                  style: Theme.of(context).textTheme.labelSmall,
                );
                final reveal = widget.onRevealDirectory;
                final newThread = widget.onNewThreadInProject;
                if (reveal == null && newThread == null) {
                  return heading.collapsed ? count : const SizedBox.shrink();
                }
                return ListenableBuilder(
                  listenable: _menuController,
                  builder: (context, actions) {
                    final showActions =
                        hovered || _focusWithin || _menuController.isOpen;
                    return Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        if (heading.collapsed && !showActions) count,
                        Opacity(
                          key: ValueKey(
                            'project-actions-visibility-${heading.directory}',
                          ),
                          opacity: showActions ? 1 : 0,
                          alwaysIncludeSemantics: true,
                          child: IgnorePointer(
                            ignoring: !showActions,
                            child: actions,
                          ),
                        ),
                      ],
                    );
                  },
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
                            icon: const Icon(Icons.add_rounded, size: 15),
                          ),
                        ),
                    ],
                  ),
                );
              },
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

    final rowWidget = CodexSidebarRow(
      containerKey: ValueKey('thread-row-${thread.id}'),
      title: thread.displayTitle,
      tooltip: gitReference == null
          ? null
          : '${thread.displayTitle}\nGit · $gitReference',
      selected: widget.selected,
      onTap: widget.enabled ? widget.onSelect : null,
      revealTrailingOnFocus: showRunning || showTrailingUnread,
      padding: EdgeInsets.only(left: leadingColor != null ? 8 : 10, right: 8),
      leading: leadingColor != null
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
          : null,
      trailingBuilder: (context, isHovered) {
        if (isHovered ||
            _menuController.isOpen ||
            (widget.selected && !showRunning && !showTrailingUnread)) {
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
                        color: OfficialCodexTheme.sidebarUnreadIndicatorColor,
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
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.only(left: 14.0),
      child: hasMetadataBadges
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rowWidget,
                _ThreadMetadataStrip(
                  threadId: thread.id,
                  pinBadge: pinBadge,
                  persistedPinned: widget.persistedPinned,
                  goalBadge: goalBadge,
                ),
              ],
            )
          : rowWidget,
    );
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
    this.pinBadge,
    this.persistedPinned = false,
    required this.goalBadge,
  });

  final String threadId;
  final String? pinBadge;
  final bool persistedPinned;
  final String? goalBadge;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final labelStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontSize: 10.5, color: palette.textMuted, height: 1.1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 8, 4),
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

class _EcosystemDialog extends StatefulWidget {
  const _EcosystemDialog({
    required this.gateway,
    required this.cwd,
    this.threadId,
    this.threadController,
    this.userInputController,
  });

  final EcosystemGateway gateway;
  final String cwd;
  final String? threadId;
  final ThreadListController? threadController;
  final UserInputController? userInputController;

  @override
  State<_EcosystemDialog> createState() => _EcosystemDialogState();
}

class _EcosystemDialogState extends State<_EcosystemDialog> {
  static const _appsPageSize = 25;
  static const _maxDisplayedAppTools = 20;

  var _section = _EcosystemSection.skills;
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
  List<PluginSummaryModel> _plugins = const [];
  var _pluginCatalogIsPartial = false;
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

  EcosystemCatalogGateway? get _catalogGateway => switch (widget.gateway) {
    final EcosystemCatalogGateway g when g.supportsEcosystemCatalog => g,
    _ => null,
  };

  McpCapabilityGateway? get _mcpGateway => switch (widget.gateway) {
    final McpCapabilityGateway g when g.supportsMcpCapabilities => g,
    _ => null,
  };

  int get _appsBadgeCount =>
      _catalogApps.isNotEmpty ? _catalogApps.length : _installedApps.length;

  List<String> get _normalizedCwds => widget.cwd.trim().isEmpty
      ? const <String>[]
      : <String>[widget.cwd.trim()];

  bool get _activeSectionLoading => switch (_section) {
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

  String? get _activeSectionError => switch (_section) {
    _EcosystemSection.skills => _skillsError,
    _EcosystemSection.plugins => _pluginsError,
    _EcosystemSection.apps => null,
    _EcosystemSection.mcp => _mcpLoadError,
  };

  ValueKey<String> get _activeSectionErrorKey => switch (_section) {
    _EcosystemSection.skills => const ValueKey('ecosystem-skills-error'),
    _EcosystemSection.plugins => const ValueKey('ecosystem-plugins-error'),
    _EcosystemSection.apps => const ValueKey('ecosystem-apps-error'),
    _EcosystemSection.mcp => const ValueKey('ecosystem-mcp-error'),
  };

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  List<McpElicitationRequest> _activeDirectMcpElicitations(
    UserInputController? userInputController,
  ) {
    final busyServer = _mcpBusyServer;
    final busyThreadId = _mcpBusyThreadId;
    if (userInputController == null ||
        busyServer == null ||
        busyThreadId == null) {
      return const <McpElicitationRequest>[];
    }
    return userInputController.pendingElicitations
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

  Future<void> _refresh({bool forceRefetch = false}) async {
    final cwds = _normalizedCwds;
    unawaited(_refreshApps(forceRefetch: forceRefetch));
    await Future.wait<void>([
      _refreshSkills(cwds: cwds),
      _refreshPlugins(cwds: cwds, forceRefetch: forceRefetch),
      _refreshMcp(forceRefetch: forceRefetch),
    ]);
  }

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
        if (mounted && _skillsLoading) {
          setState(() => _skillsLoading = false);
        }
      }
    });
    _skillsRefreshInFlight = future;
    return future;
  }

  Future<void> _runRefreshSkills({required List<String> cwds}) async {
    final generation = ++_skillsRefreshGeneration;
    if (mounted) {
      setState(() {
        _skillsLoading = true;
        _skillsError = null;
      });
    }
    try {
      final nextSkills = await widget.gateway.listSkills(cwds: cwds);
      if (!mounted || generation != _skillsRefreshGeneration) {
        return;
      }
      setState(() {
        _skills = nextSkills;
        _skillsLoadFailed = false;
        _skillsError = null;
        _skillsLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _skillsRefreshGeneration) {
        return;
      }
      setState(() {
        _skillsLoadFailed = true;
        _skillsError = '$error';
        _skillsLoading = false;
      });
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
            if (mounted) {
              setState(() => _pluginsLoading = false);
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
    final catalog = _catalogGateway;
    if (mounted) {
      setState(() {
        _pluginsLoading = true;
        _pluginsError = null;
      });
    }
    try {
      final snapshot = catalog != null
          ? await catalog.listPluginCatalog(cwds: cwds)
          : PluginCatalogSnapshot(
              plugins: await widget.gateway.listPlugins(cwds: cwds),
            );
      if (!mounted || generation != _pluginsRefreshGeneration) {
        return;
      }
      final nextPlugins = snapshot.plugins;
      setState(() {
        _plugins = nextPlugins;
        _pluginCatalogIsPartial = snapshot.isPartial;
        _prunePluginCaches(nextPlugins, forceRefetch: forceRefetch);
        _pluginsLoadFailed = false;
        _pluginsError = null;
        _pluginsLoading = false;
      });
      if (forceRefetch && catalog != null && _expandedPluginIds.isNotEmpty) {
        await _refreshExpandedPluginDetails(
          catalog: catalog,
          plugins: nextPlugins,
          generation: generation,
        );
      }
    } catch (error) {
      if (!mounted || generation != _pluginsRefreshGeneration) {
        return;
      }
      setState(() {
        _pluginsLoadFailed = true;
        _pluginsError = '$error';
        _pluginsLoading = false;
      });
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
      if (!mounted || generation != _pluginsRefreshGeneration) {
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
        if (mounted &&
            generation == _pluginsRefreshGeneration &&
            _expandedPluginIds.contains(plugin.id)) {
          setState(() {
            _pluginDetails[plugin.id] = updatedDetail;
          });
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
        if (mounted && _mcpLoading) {
          setState(() => _mcpLoading = false);
        }
      }
    });
    _mcpRefreshInFlight = future;
    return future;
  }

  Future<void> _runRefreshMcp({required bool forceRefetch}) async {
    final generation = ++_mcpRefreshGeneration;
    if (mounted) {
      setState(() {
        _mcpLoading = true;
        _mcpLoadError = null;
      });
    }
    try {
      final nextMcpServers = await widget.gateway.listMcpServerStatus();
      if (!mounted || generation != _mcpRefreshGeneration) {
        return;
      }
      setState(() {
        _mcpServers = nextMcpServers;
        _pruneMcpCaches(nextMcpServers, forceRefetch: forceRefetch);
        _mcpLoadFailed = false;
        _mcpLoadError = null;
        _mcpLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _mcpRefreshGeneration) {
        return;
      }
      setState(() {
        _mcpLoadFailed = true;
        _mcpLoadError = '$error';
        _mcpLoading = false;
      });
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
    final catalog = _catalogGateway;
    if (catalog == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _installedApps = const [];
        _catalogApps = const [];
        _appsNextCursor = null;
        _installedAppsLoadFailed = false;
        _catalogAppsLoadFailed = false;
        _appsError = null;
        _appsLoading = false;
        _loadingMoreApps = false;
        _pruneAppCaches(const [], const [], forceRefetch: true);
      });
      return;
    }

    if (mounted) {
      setState(() {
        _appsLoading = true;
        _loadingMoreApps = false;
        _appsError = null;
      });
    }

    var installedApps = _installedApps;
    var catalogApps = _catalogApps;
    var installedAppsLoadFailed = false;
    var catalogAppsLoadFailed = false;
    String? nextCursor = _appsNextCursor;
    String? appsError;

    try {
      installedApps = await catalog.listInstalledApps(
        threadId: widget.threadId,
        forceRefresh: forceRefetch,
      );
      if (mounted && generation == _appsRefreshGeneration) {
        setState(() {
          _installedApps = installedApps;
          _installedAppsLoadFailed = false;
        });
      }
    } catch (error) {
      installedAppsLoadFailed = true;
      appsError = '$error';
    }

    try {
      final page = await catalog.listApps(
        AppListQuery(
          limit: _appsPageSize,
          threadId: widget.threadId,
          forceRefetch: forceRefetch,
        ),
      );
      catalogApps = page.apps
          .take(maxBoundedEcosystemItems)
          .toList(growable: false);
      nextCursor = catalogApps.length >= maxBoundedEcosystemItems
          ? null
          : page.nextCursor;
    } catch (error) {
      catalogAppsLoadFailed = true;
      appsError = appsError == null ? '$error' : '$appsError\n$error';
    }

    if (!mounted || generation != _appsRefreshGeneration) {
      return;
    }
    setState(() {
      _installedApps = installedApps;
      _catalogApps = catalogApps;
      _installedAppsLoadFailed = installedAppsLoadFailed;
      _catalogAppsLoadFailed = catalogAppsLoadFailed;
      _appsNextCursor = nextCursor;
      _appsError = appsError;
      _appsLoading = false;
      _pruneAppCaches(installedApps, catalogApps, forceRefetch: forceRefetch);
    });

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
            threadId: widget.threadId,
          );
          if (!mounted || generation != _appsRefreshGeneration) {
            return;
          }
          setState(() {
            for (final detail in result.apps) {
              _appDetails[detail.id] = detail;
              _missingAppIds.remove(detail.id);
            }
            for (final missing in result.missingAppIds) {
              _missingAppIds.add(missing);
            }
          });
        } on Object {
          // Keep existing detail if refresh re-read fails.
        }
      }
    }
  }

  Future<void> _loadMoreApps() async {
    final catalog = _catalogGateway;
    final cursor = _appsNextCursor;
    if (catalog == null ||
        cursor == null ||
        _loadingMoreApps ||
        _catalogApps.length >= maxBoundedEcosystemItems) {
      return;
    }
    setState(() {
      _loadingMoreApps = true;
      _appsError = null;
    });
    try {
      final remaining = maxBoundedEcosystemItems - _catalogApps.length;
      final page = await catalog.listApps(
        AppListQuery(
          cursor: cursor,
          limit: remaining < _appsPageSize ? remaining : _appsPageSize,
          threadId: widget.threadId,
        ),
      );
      if (!mounted) {
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
      setState(() {
        _catalogApps = List<AppSummaryModel>.unmodifiable(merged);
        _appsNextCursor = merged.length >= maxBoundedEcosystemItems
            ? null
            : page.nextCursor;
        _loadingMoreApps = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _appsError = '$error';
        _loadingMoreApps = false;
      });
    }
  }

  Future<void> _reloadMcpServers() async {
    final gateway = _mcpGateway;
    if (gateway == null ||
        _reloadingMcp ||
        _mcpLoading ||
        _mcpRefreshInFlight != null) {
      return;
    }
    setState(() {
      _reloadingMcp = true;
      _mcpNotice = null;
      _mcpErrors.clear();
    });
    try {
      await gateway.reloadMcpServers();
      final generation = ++_mcpRefreshGeneration;
      final servers = await widget.gateway.listMcpServerStatus();
      if (!mounted || generation != _mcpRefreshGeneration) {
        return;
      }
      setState(() {
        _mcpServers = servers;
        _pruneMcpCaches(servers, forceRefetch: true);
        _mcpLoadFailed = false;
        _mcpLoadError = null;
        _mcpLoading = false;
        _mcpNotice = 'MCP server configuration reloaded.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _mcpLoading = false;
          _mcpNotice = 'Reload failed: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _reloadingMcp = false);
      }
    }
  }

  bool _ensureCapturedThreadReady(String serverName, String capturedThreadId) {
    final threadController = widget.threadController;
    if (threadController == null) {
      return true;
    }
    final selected = threadController.selectedThread;
    if (selected == null || selected.id != capturedThreadId) {
      setState(() {
        _mcpErrors[serverName] = 'Selected thread changed; reopen Skills, Plugins & MCP to continue.';
      });
      return false;
    }
    if (selected.status == ThreadRuntimeStatus.notLoaded &&
        threadController.isMaterialized(selected.id)) {
      setState(() {
        _mcpErrors[serverName] = 'Resume the selected thread in the sidebar and reopen Skills, Plugins & MCP to run thread-scoped MCP actions.';
      });
      return false;
    }
    return true;
  }

  void _activateMcpOutboundOperation(
    String serverName,
    String? threadId,
    _McpOperationKind kind,
  ) {
    final existingIds = widget.userInputController?.pendingElicitations
        .map((request) => request.requestId)
        .toSet();
    setState(() {
      _mcpBusyServer = serverName;
      _mcpBusyThreadId = threadId;
      _mcpBusyOperation = kind;
      _mcpExcludedElicitationIds = existingIds == null || existingIds.isEmpty
          ? const <Object>{}
          : Set<Object>.unmodifiable(existingIds);
      _mcpErrors.remove(serverName);
    });
  }

  Future<void> _readMcpResource(McpServerStatusModel server) async {
    final gateway = _mcpGateway;
    if (gateway == null || _mcpBusyServer != null) {
      return;
    }
    final uri = await showDialog<String>(
      context: context,
      builder: (context) => _McpResourceReadDialog(serverName: server.name),
    );
    if (uri == null || !mounted) {
      return;
    }
    final normalizedThreadId = widget.threadId?.trim();
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
      final result = await gateway.readMcpResource(
        McpResourceReadQuery(
          server: server.name,
          uri: uri,
          threadId: activeThreadId,
        ),
      );
      if (mounted) {
        setState(() => _mcpResults[server.name] = result);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _mcpErrors[server.name] = '$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _mcpBusyServer = null;
          _mcpBusyThreadId = null;
          _mcpBusyOperation = null;
          _mcpExcludedElicitationIds = const <Object>{};
        });
      }
    }
  }

  Future<void> _callMcpTool(McpServerStatusModel server) async {
    final gateway = _mcpGateway;
    final threadId = widget.threadId;
    if (gateway == null || _mcpBusyServer != null) {
      return;
    }
    final normalizedThreadId = threadId?.trim();
    if (normalizedThreadId == null || normalizedThreadId.isEmpty) {
      setState(() {
        _mcpErrors[server.name] =
            'Select or create a thread before calling an MCP tool.';
      });
      return;
    }
    final input = await showDialog<({String tool, Map<String, Object?> args})>(
      context: context,
      builder: (context) => _McpToolCallDialog(serverName: server.name),
    );
    if (input == null || !mounted) {
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
      final result = await gateway.callMcpTool(
        McpToolCallQuery(
          server: server.name,
          threadId: normalizedThreadId,
          tool: input.tool,
          arguments: input.args,
        ),
      );
      if (mounted) {
        setState(() => _mcpResults[server.name] = result);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _mcpErrors[server.name] = '$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _mcpBusyServer = null;
          _mcpBusyThreadId = null;
          _mcpBusyOperation = null;
          _mcpExcludedElicitationIds = const <Object>{};
        });
      }
    }
  }

  Future<void> _toggleSkill(SkillSummary skill) async {
    if (_skillsLoading || _mutatingSkillPaths.contains(skill.path)) {
      return;
    }
    setState(() {
      _mutatingSkillPaths.add(skill.path);
      _skillsError = null;
    });
    try {
      final effective = await widget.gateway.setSkillEnabled(
        path: skill.path,
        enabled: !skill.enabled,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        ++_skillsRefreshGeneration;
        _skills = [
          for (final item in _skills)
            if (item.path == skill.path)
              item.copyWith(enabled: effective)
            else
              item,
        ];
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _skillsError = '$error');
    } finally {
      if (mounted) {
        setState(() => _mutatingSkillPaths.remove(skill.path));
      }
    }
  }

  Future<void> _togglePluginDetails(PluginSummaryModel plugin) async {
    final catalog = _catalogGateway;
    if (catalog == null || _pluginsLoading || _pluginsRefreshInFlight != null) {
      return;
    }
    if (_expandedPluginIds.contains(plugin.id)) {
      setState(() => _expandedPluginIds.remove(plugin.id));
      return;
    }
    setState(() {
      _expandedPluginIds.add(plugin.id);
      _readingPluginIds.add(plugin.id);
      _pluginsError = null;
    });
    try {
      final detail = await catalog.readPlugin(
        pluginName: plugin.effectivePluginName,
        marketplacePath: plugin.marketplacePath,
        remoteMarketplaceName: plugin.marketplacePath == null
            ? plugin.marketplaceName
            : null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pluginDetails[plugin.id] = detail;
        _readingPluginIds.remove(plugin.id);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _readingPluginIds.remove(plugin.id);
        _expandedPluginIds.remove(plugin.id);
        _pluginsError = '$error';
      });
    }
  }

  Future<void> _installPlugin(PluginSummaryModel plugin) async {
    final catalog = _catalogGateway;
    if (catalog == null ||
        _pluginsLoading ||
        _pluginsRefreshInFlight != null ||
        _mutatingPluginIds.isNotEmpty) {
      return;
    }
    setState(() {
      _mutatingPluginIds.add(plugin.id);
      _pluginsError = null;
      _pluginActionNotice = null;
    });
    try {
      final result = await catalog.installPlugin(
        pluginName: plugin.effectivePluginName,
        marketplacePath: plugin.marketplacePath,
        remoteMarketplaceName: plugin.marketplacePath == null
            ? plugin.marketplaceName
            : null,
      );
      if (!mounted) {
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
      if (!mounted) {
        return;
      }
      setState(() {
        _mutatingPluginIds.remove(plugin.id);
        _pluginActionNotice = notice;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mutatingPluginIds.remove(plugin.id);
        _pluginsError = '$error';
      });
    }
  }

  Future<void> _uninstallPlugin(PluginSummaryModel plugin) async {
    final catalog = _catalogGateway;
    if (catalog == null ||
        _pluginsLoading ||
        _pluginsRefreshInFlight != null ||
        _mutatingPluginIds.isNotEmpty) {
      return;
    }
    setState(() {
      _mutatingPluginIds.add(plugin.id);
      _pluginsError = null;
      _pluginActionNotice = null;
    });
    try {
      await catalog.uninstallPlugin(pluginId: plugin.id);
      if (!mounted) {
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
      if (!mounted) {
        return;
      }
      setState(() {
        _mutatingPluginIds.remove(plugin.id);
        _pluginDetails.remove(plugin.id);
        _expandedPluginIds.remove(plugin.id);
        _pluginActionNotice = 'Uninstalled ${plugin.name}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mutatingPluginIds.remove(plugin.id);
        _pluginsError = '$error';
      });
    }
  }

  Future<void> _toggleAppDetails(
    String appId, {
    required bool installedSection,
  }) async {
    final catalog = _catalogGateway;
    if (catalog == null) {
      return;
    }
    final targetSet = installedSection
        ? _expandedInstalledAppIds
        : _expandedCatalogAppIds;
    if (targetSet.contains(appId)) {
      setState(() => targetSet.remove(appId));
      return;
    }
    setState(() {
      targetSet.add(appId);
      _readingAppIds.add(appId);
      _appsError = null;
    });
    try {
      final result = await catalog.readApps(
        appIds: <String>[appId],
        includeTools: true,
        threadId: widget.threadId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
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
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _readingAppIds.remove(appId);
        targetSet.remove(appId);
        _appsError = '$error';
      });
    }
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ThemeTokens.space6,
                ThemeTokens.space4,
                ThemeTokens.space3,
                ThemeTokens.space3,
              ),
              child: Row(
                children: [
                  const Icon(Icons.extension_outlined, size: 20),
                  const SizedBox(width: ThemeTokens.space2),
                  Expanded(
                    child: Text(
                      'Skills, Plugins & MCP',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  CodexSegment<_EcosystemSection>(
                    key: const ValueKey('ecosystem-section-selector'),
                    items: [
                      CodexSegmentItem(
                        value: _EcosystemSection.skills,
                        label: 'Skills (${_skills.length})',
                      ),
                      CodexSegmentItem(
                        value: _EcosystemSection.plugins,
                        label: 'Plugins (${_plugins.length})',
                      ),
                      CodexSegmentItem(
                        value: _EcosystemSection.apps,
                        label: 'Apps ($_appsBadgeCount)',
                      ),
                      CodexSegmentItem(
                        value: _EcosystemSection.mcp,
                        label: 'MCP (${_mcpServers.length})',
                      ),
                    ],
                    selectedValue: _section,
                    onSelected: (next) => setState(() => _section = next),
                  ),
                  const SizedBox(width: ThemeTokens.space2),
                  CodexIconButton(
                    key: const ValueKey('ecosystem-refresh-button'),
                    tooltip: 'Refresh',
                    onPressed: _activeSectionLoading
                        ? null
                        : () => _refresh(forceRefetch: true),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                  ),
                  CodexIconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.border),
            if (_activeSectionError case final error?)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: KeyedSubtree(
                  key: _activeSectionErrorKey,
                  child: _InlineNotice(
                    icon: Icons.error_outline_rounded,
                    color: palette.danger,
                    text: error,
                  ),
                ),
              ),
            if (_section == _EcosystemSection.plugins &&
                _pluginCatalogIsPartial &&
                !_pluginsLoadFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: KeyedSubtree(
                  key: const ValueKey('ecosystem-plugins-partial'),
                  child: _InlineNotice(
                    icon: Icons.warning_amber_rounded,
                    color: palette.warning,
                    text: 'The plugin catalog may be incomplete.',
                  ),
                ),
              ),
            if (_pluginActionNotice case final notice?
                when _section == _EcosystemSection.plugins)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: KeyedSubtree(
                  key: const ValueKey('plugin-install-auth-notice'),
                  child: _InlineNotice(
                    icon: Icons.info_outline_rounded,
                    color: palette.accent,
                    text: notice,
                  ),
                ),
              ),
            if (_mcpNotice case final notice?
                when _section == _EcosystemSection.mcp)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
            if (widget.userInputController case final userInputController?)
              AnimatedBuilder(
                animation: userInputController,
                builder: (context, _) {
                  final directElicitations = _activeDirectMcpElicitations(
                    userInputController,
                  );
                  final activeDirectElicitation =
                      directElicitations.firstOrNull;
                  if (activeDirectElicitation == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    key: const ValueKey('ecosystem-modal-elicitation-slot'),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
            Expanded(
              child: _section == _EcosystemSection.apps
                  ? _buildAppsList(context)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(ThemeTokens.space5),
                      child: switch (_section) {
                        _EcosystemSection.skills => _buildSkillsList(context),
                        _EcosystemSection.plugins => _buildPluginsList(context),
                        _EcosystemSection.apps => const SizedBox.shrink(),
                        _EcosystemSection.mcp => _buildMcpList(context),
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsList(BuildContext context) {
    final palette = ThemeTokens.of(context);
    if (_skills.isEmpty) {
      if (_skillsLoading) {
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
      if (_skillsLoadFailed) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final skill in _skills)
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
                  loading: _mutatingSkillPaths.contains(skill.path),
                  onPressed:
                      _skillsLoading || _mutatingSkillPaths.contains(skill.path)
                      ? null
                      : () => _toggleSkill(skill),
                  label: skill.enabled ? 'Enabled' : 'Disabled',
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPluginsList(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final catalogSupported = _catalogGateway != null;
    if (_plugins.isEmpty) {
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
          if (_pluginsLoading)
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
          else if (_pluginsLoadFailed)
            Text(
              'Unable to load plugin catalog.',
              key: const ValueKey('ecosystem-plugins-unavailable'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else if (_pluginCatalogIsPartial)
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
        for (final plugin in _plugins)
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
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: palette.textMuted),
                                ),
                              if (plugin.marketplaceName case final mpName?
                                  when mpName.isNotEmpty)
                                Text(
                                  mpName,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: palette.textMuted),
                                ),
                              if (plugin.sourceType case final sourceType?
                                  when sourceType.isNotEmpty)
                                Text(
                                  sourceType,
                                  style: Theme.of(context).textTheme.labelSmall
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
                            loading: _readingPluginIds.contains(plugin.id),
                            onPressed:
                                _pluginsLoading ||
                                    _pluginsRefreshInFlight != null ||
                                    _readingPluginIds.contains(plugin.id)
                                ? null
                                : () => _togglePluginDetails(plugin),
                            label: _expandedPluginIds.contains(plugin.id)
                                ? 'Hide details'
                                : 'Details',
                          ),
                          const SizedBox(width: 6),
                          if (!plugin.installed)
                            CodexButton(
                              key: ValueKey('plugin-install-${plugin.id}'),
                              size: CodexButtonSize.sm,
                              variant: CodexButtonVariant.secondary,
                              loading: _mutatingPluginIds.contains(plugin.id),
                              onPressed:
                                  !_pluginsLoading &&
                                      _pluginsRefreshInFlight == null &&
                                      plugin.canInstall &&
                                      _mutatingPluginIds.isEmpty
                                  ? () => _installPlugin(plugin)
                                  : null,
                              label: 'Install',
                            )
                          else
                            CodexButton(
                              key: ValueKey('plugin-uninstall-${plugin.id}'),
                              size: CodexButtonSize.sm,
                              variant: CodexButtonVariant.ghost,
                              loading: _mutatingPluginIds.contains(plugin.id),
                              onPressed:
                                  !_pluginsLoading &&
                                      _pluginsRefreshInFlight == null &&
                                      plugin.canUninstall &&
                                      _mutatingPluginIds.isEmpty
                                  ? () => _uninstallPlugin(plugin)
                                  : null,
                              label: 'Uninstall',
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (_expandedPluginIds.contains(plugin.id))
                  _buildPluginDetailSection(context, plugin),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPluginDetailSection(
    BuildContext context,
    PluginSummaryModel plugin,
  ) {
    final palette = ThemeTokens.of(context);
    final detail = _pluginDetails[plugin.id];
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
    if (_catalogGateway == null) {
      return Padding(
        padding: const EdgeInsets.all(ThemeTokens.space5),
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
    return CustomScrollView(
      key: const ValueKey('ecosystem-apps-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            ThemeTokens.space5,
            ThemeTokens.space5,
            ThemeTokens.space5,
            0,
          ),
          sliver: SliverList.list(
            children: [
              if (_appsError case final appsError?)
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
                'Installed Connector Runtime (${_installedApps.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_installedApps.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _appsLoading
                        ? 'Loading installed connector runtime...'
                        : _installedAppsLoadFailed
                        ? 'Unable to load installed connector runtime.'
                        : 'No installed connector runtime apps in the committed snapshot.',
                    key: ValueKey(
                      _appsLoading
                          ? 'ecosystem-installed-apps-loading'
                          : _installedAppsLoadFailed
                          ? 'ecosystem-installed-apps-unavailable'
                          : 'ecosystem-installed-apps-empty',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        if (_installedApps.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ThemeTokens.space5,
              0,
              ThemeTokens.space5,
              12,
            ),
            sliver: SliverList.builder(
              itemCount: _installedApps.length,
              itemBuilder: (context, index) =>
                  _buildInstalledAppCard(context, _installedApps[index]),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.space5),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'App Catalog (${_catalogApps.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (_appsLoading)
                    const SizedBox(
                      key: ValueKey('ecosystem-apps-loading'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_catalogApps.isEmpty && !_appsLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: ThemeTokens.space5),
                  child: Text(
                    _catalogAppsLoadFailed
                        ? 'Unable to load app catalog.'
                        : 'No catalog apps returned.',
                    key: ValueKey(
                      _catalogAppsLoadFailed
                          ? 'ecosystem-apps-unavailable'
                          : 'ecosystem-apps-empty',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else if (_catalogApps.isEmpty && _appsLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: ThemeTokens.space5),
                  child: Text(
                    'Loading app catalog...',
                    key: const ValueKey('ecosystem-apps-loading-label'),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: palette.textMuted),
                  ),
                ),
            ],
          ),
        ),
        if (_catalogApps.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.space5),
            sliver: SliverList.builder(
              itemCount: _catalogApps.length,
              itemBuilder: (context, index) =>
                  _buildCatalogAppCard(context, _catalogApps[index]),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            ThemeTokens.space5,
            0,
            ThemeTokens.space5,
            ThemeTokens.space5,
          ),
          sliver: SliverList.list(
            children: [
              if (_appsNextCursor != null &&
                  _catalogApps.length < maxBoundedEcosystemItems)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: CodexButton(
                      key: const ValueKey('ecosystem-apps-load-more'),
                      size: CodexButtonSize.sm,
                      variant: CodexButtonVariant.secondary,
                      loading: _loadingMoreApps,
                      onPressed: _loadingMoreApps ? null : _loadMoreApps,
                      label: 'Load more apps',
                    ),
                  ),
                )
              else if (_catalogApps.length >= maxBoundedEcosystemItems)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Showing first $maxBoundedEcosystemItems catalog apps.',
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
          loading: _readingAppIds.contains(installed.id),
          onPressed: _readingAppIds.contains(installed.id)
              ? null
              : () => _toggleAppDetails(installed.id, installedSection: true),
          label: _expandedInstalledAppIds.contains(installed.id)
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
          if (_expandedInstalledAppIds.contains(installed.id))
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
          loading: _readingAppIds.contains(app.id),
          onPressed: _readingAppIds.contains(app.id)
              ? null
              : () => _toggleAppDetails(app.id, installedSection: false),
          label: _expandedCatalogAppIds.contains(app.id)
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
          if (_expandedCatalogAppIds.contains(app.id))
            _buildAppDetailSection(context, app.id),
        ],
      ),
    );
  }

  Widget _buildAppDetailSection(BuildContext context, String appId) {
    final palette = ThemeTokens.of(context);
    if (_readingAppIds.contains(appId) && !_appDetails.containsKey(appId)) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_missingAppIds.contains(appId) && !_appDetails.containsKey(appId)) {
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
    final detail = _appDetails[appId];
    if (detail == null) {
      return const SizedBox.shrink();
    }
    final displayedTools = detail.toolSummaries
        .take(_maxDisplayedAppTools)
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
          if (detail.toolSummaries.length > _maxDisplayedAppTools)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Showing first $_maxDisplayedAppTools of ${detail.toolSummaries.length} tools.',
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
    final gateway = _mcpGateway;
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
              loading: _reloadingMcp,
              onPressed: gateway == null || _reloadingMcp || _mcpLoading
                  ? null
                  : _reloadMcpServers,
              label: 'Reload config',
            ),
          ],
        ),
        const SizedBox(height: ThemeTokens.space3),
        if (_mcpServers.isEmpty)
          if (_mcpLoading)
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
          else if (_mcpLoadFailed)
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
            ),
        for (final server in _mcpServers)
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
                                  style: Theme.of(context).textTheme.labelSmall
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
                        CodexButton(
                          key: ValueKey('mcp-read-resource-${server.name}'),
                          variant: CodexButtonVariant.secondary,
                          size: CodexButtonSize.sm,
                          loading:
                              _mcpBusyServer == server.name &&
                              _mcpBusyOperation ==
                                  _McpOperationKind.readResource,
                          onPressed: gateway == null || _mcpBusyServer != null
                              ? null
                              : () => _readMcpResource(server),
                          label: 'Read resource',
                        ),
                        CodexButton(
                          key: ValueKey('mcp-call-tool-${server.name}'),
                          variant: CodexButtonVariant.secondary,
                          size: CodexButtonSize.sm,
                          loading:
                              _mcpBusyServer == server.name &&
                              _mcpBusyOperation == _McpOperationKind.callTool,
                          onPressed: gateway == null || _mcpBusyServer != null
                              ? null
                              : () => _callMcpTool(server),
                          label: 'Call tool',
                        ),
                      ],
                    ),
                    if (_mcpErrors[server.name] case final error?) ...[
                      const SizedBox(height: ThemeTokens.space2),
                      SelectableText(
                        error,
                        key: ValueKey('mcp-error-${server.name}'),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: palette.danger),
                      ),
                    ],
                    if (_mcpResults[server.name] case final result?) ...[
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
