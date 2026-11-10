part of '../codex_native_app.dart';

class RuntimeStatusScreen extends StatelessWidget {
  const RuntimeStatusScreen({
    super.key,
    required this.controller,
    required this.threadController,
    required this.conversationController,
    required this.historyController,
    required this.approvalController,
    required this.userInputController,
    required this.settingsController,
    required this.diffController,
    required this.defaultWorkingDirectory,
    this.remotePairingScannerLauncher,
  });

  final RuntimeController controller;
  final ThreadListController threadController;
  final ConversationController conversationController;
  final HistoryController historyController;
  final ApprovalController approvalController;
  final UserInputController userInputController;
  final ExecutionSettingsController settingsController;
  final DiffController diffController;
  final String defaultWorkingDirectory;
  final RemotePairingScannerLauncher? remotePairingScannerLauncher;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return switch (controller.snapshot.state) {
      RuntimeConnectionState.connected => _ConnectedWorkspace(
        runtimeController: controller,
        threadController: threadController,
        conversationController: conversationController,
        historyController: historyController,
        approvalController: approvalController,
        userInputController: userInputController,
        settingsController: settingsController,
        diffController: diffController,
        defaultWorkingDirectory: defaultWorkingDirectory,
      ),
      RuntimeConnectionState.remoteReadOnly => _StandaloneSurface(
        controller: controller,
        child: _RemoteReadOnlyPanel(controller: controller),
      ),
      RuntimeConnectionState.remoteUnpaired => _StandaloneSurface(
        controller: controller,
        child: _RemotePairingPanel(
          controller: controller,
          scannerLauncher: remotePairingScannerLauncher,
        ),
      ),
      RuntimeConnectionState.remoteCredentialRecoveryRequired ||
      RuntimeConnectionState.remoteRevoked => _StandaloneSurface(
        controller: controller,
        child: _RemoteRecoveryPanel(controller: controller),
      ),
      _ => _RuntimeConnectionScreen(controller: controller),
    };
  }
}

class _ConnectedWorkspace extends StatefulWidget {
  const _ConnectedWorkspace({
    required this.runtimeController,
    required this.threadController,
    required this.conversationController,
    required this.historyController,
    required this.approvalController,
    required this.userInputController,
    required this.settingsController,
    required this.diffController,
    required this.defaultWorkingDirectory,
  });

  final RuntimeController runtimeController;
  final ThreadListController threadController;
  final ConversationController conversationController;
  final HistoryController historyController;
  final ApprovalController approvalController;
  final UserInputController userInputController;
  final ExecutionSettingsController settingsController;
  final DiffController diffController;
  final String defaultWorkingDirectory;

  @override
  State<_ConnectedWorkspace> createState() => _ConnectedWorkspaceState();
}

class _ConnectedWorkspaceState extends State<_ConnectedWorkspace> {
  final _conversationKey = GlobalKey<_ConversationPanelState>();
  var _desktopLeftPanelWidth = OfficialCodexTheme.desktopLeftPanelWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _desktopSplitMinimumWidth) {
          final hasActiveConversation =
              widget.threadController.selectedThread != null ||
              (_conversationKey.currentState?.hasComposerDraft ?? false);
          return _CompactWorkspace(
            key: const ValueKey('compact-workspace'),
            threadController: widget.threadController,
            initialShowSidebar: !hasActiveConversation,
            sidebarBuilder: (onThreadSelected) => _ThreadPanel(
              controller: widget.threadController,
              settingsController: widget.settingsController,
              runtimeController: widget.runtimeController,
              userInputController: widget.userInputController,
              defaultWorkingDirectory: widget.defaultWorkingDirectory,
              onThreadSelected: onThreadSelected,
            ),
            conversationBuilder: (isOffstage) => _ConversationPanel(
              key: _conversationKey,
              controller: widget.conversationController,
              threadController: widget.threadController,
              historyController: widget.historyController,
              approvalController: widget.approvalController,
              userInputController: widget.userInputController,
              settingsController: widget.settingsController,
              diffController: widget.diffController,
              outputGateway: widget.runtimeController,
              transportCapabilities: widget.runtimeController.capabilities,
              defaultWorkingDirectory: widget.defaultWorkingDirectory,
              isOffstage: isOffstage,
            ),
          );
        }
        final maximum =
            (constraints.maxWidth - OfficialCodexTheme.desktopWorkspaceMinWidth)
                .clamp(
                  OfficialCodexTheme.desktopLeftPanelMinWidth,
                  OfficialCodexTheme.sidebarMaxWidth,
                );
        final leftWidth = _desktopLeftPanelWidth.clamp(
          OfficialCodexTheme.desktopLeftPanelMinWidth,
          maximum,
        );
        return _DesktopSplitWorkspace(
          key: const ValueKey('desktop-split-workspace'),
          conversationKey: _conversationKey,
          sidebarWidth: leftWidth - OfficialCodexTheme.navigationRailWidth,
          onSidebarResize: (delta) {
            final visibleWidth = _desktopLeftPanelWidth.clamp(
              OfficialCodexTheme.desktopLeftPanelMinWidth,
              maximum,
            );
            final width = (visibleWidth + delta).clamp(
              OfficialCodexTheme.desktopLeftPanelMinWidth,
              maximum,
            );
            if (_desktopLeftPanelWidth == width) {
              return;
            }
            setState(() => _desktopLeftPanelWidth = width);
          },
          runtimeController: widget.runtimeController,
          threadController: widget.threadController,
          conversationController: widget.conversationController,
          historyController: widget.historyController,
          approvalController: widget.approvalController,
          userInputController: widget.userInputController,
          settingsController: widget.settingsController,
          diffController: widget.diffController,
          defaultWorkingDirectory: widget.defaultWorkingDirectory,
        );
      },
    );
  }
}

class _DesktopSplitWorkspace extends StatefulWidget {
  const _DesktopSplitWorkspace({
    super.key,
    required this.conversationKey,
    required this.sidebarWidth,
    required this.onSidebarResize,
    required this.runtimeController,
    required this.threadController,
    required this.conversationController,
    required this.historyController,
    required this.approvalController,
    required this.userInputController,
    required this.settingsController,
    required this.diffController,
    required this.defaultWorkingDirectory,
  });

  final GlobalKey<_ConversationPanelState> conversationKey;
  final double sidebarWidth;
  final ValueChanged<double> onSidebarResize;
  final RuntimeController runtimeController;
  final ThreadListController threadController;
  final ConversationController conversationController;
  final HistoryController historyController;
  final ApprovalController approvalController;
  final UserInputController userInputController;
  final ExecutionSettingsController settingsController;
  final DiffController diffController;
  final String defaultWorkingDirectory;

  @override
  State<_DesktopSplitWorkspace> createState() => _DesktopSplitWorkspaceState();
}

class _DesktopSplitWorkspaceState extends State<_DesktopSplitWorkspace> {
  final _threadPanelKey = GlobalKey<_ThreadPanelState>();
  final _fileMenu = CodexPopoverController();
  final _viewMenu = CodexPopoverController();
  var _sidebarCollapsed = false;
  var _ecosystemOpen = false;

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  Future<void> _openRailEcosystem() async {
    final panel = _threadPanelKey.currentState;
    if (panel == null || _ecosystemOpen) {
      return;
    }
    setState(() => _ecosystemOpen = true);
    try {
      await panel._openEcosystem();
    } finally {
      if (mounted) {
        setState(() => _ecosystemOpen = false);
      }
    }
  }

  @override
  void dispose() {
    _fileMenu.dispose();
    _viewMenu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _toggleSidebar,
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
            _toggleSidebar,
      },
      child: ColoredBox(
        color: theme.isDark
            ? theme.shellBackground
            : OfficialCodexTheme.lightNavigationBackground,
        child: Column(
          children: [
            _applicationToolbar(),
            const SizedBox(height: OfficialCodexTheme.shellPageTopInset),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _navigationRail(),
                  Expanded(
                    child: Container(
                      key: const ValueKey('app-shell-page-surface'),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: theme.workspaceBackground,
                        borderRadius: BorderRadius.circular(
                          OfficialCodexTheme.mainSurfaceRadius,
                        ),
                        boxShadow: const [OfficialCodexTheme.shellPageShadow],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Offstage(
                            offstage: _sidebarCollapsed,
                            child: TickerMode(
                              enabled: !_sidebarCollapsed,
                              child: ExcludeFocus(
                                excluding: _sidebarCollapsed,
                                child: DecoratedBox(
                                  position: DecorationPosition.foreground,
                                  decoration: BoxDecoration(
                                    border: BorderDirectional(
                                      end: BorderSide(
                                        color: theme.hairlineBorder,
                                        width: OfficialCodexTheme
                                            .hairlineBorderWidth,
                                      ),
                                    ),
                                  ),
                                  child: SizedBox(
                                    key: const ValueKey('app_shell_sidebar'),
                                    width: widget.sidebarWidth,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _ThreadPanel(
                                          key: _threadPanelKey,
                                          controller: widget.threadController,
                                          settingsController:
                                              widget.settingsController,
                                          runtimeController:
                                              widget.runtimeController,
                                          userInputController:
                                              widget.userInputController,
                                          defaultWorkingDirectory:
                                              widget.defaultWorkingDirectory,
                                          hasNavigationRail: true,
                                        ),
                                        PositionedDirectional(
                                          top: 0,
                                          bottom: 0,
                                          end: 0,
                                          width: ThemeTokens.space2,
                                          child: _sidebarResizeHandle(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: KeyedSubtree(
                              key: const ValueKey('app-shell-workspace'),
                              child: _ConversationPanel(
                                key: widget.conversationKey,
                                controller: widget.conversationController,
                                threadController: widget.threadController,
                                historyController: widget.historyController,
                                approvalController: widget.approvalController,
                                userInputController: widget.userInputController,
                                settingsController: widget.settingsController,
                                diffController: widget.diffController,
                                outputGateway: widget.runtimeController,
                                transportCapabilities:
                                    widget.runtimeController.capabilities,
                                defaultWorkingDirectory:
                                    widget.defaultWorkingDirectory,
                                hasDesktopShell: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarResizeHandle() {
    const step = 24.0;
    final direction = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    void grow() => widget.onSidebarResize(step);
    void shrink() => widget.onSidebarResize(-step);

    return Semantics(
      label: 'Sidebar width',
      onIncrease: grow,
      onDecrease: shrink,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): direction == 1
              ? shrink
              : grow,
          const SingleActivator(LogicalKeyboardKey.arrowRight): direction == 1
              ? grow
              : shrink,
        },
        child: Focus(
          child: Builder(
            builder: (context) => MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                key: const ValueKey('sidebar-resize-handle'),
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onHorizontalDragUpdate: (event) =>
                    widget.onSidebarResize(event.delta.dx * direction),
                child: ColoredBox(
                  color: Focus.of(context).hasPrimaryFocus
                      ? OfficialCodexTheme.of(context).focusRing
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _applicationToolbar() {
    final sidebarLabel = _sidebarCollapsed ? 'Show sidebar' : 'Hide sidebar';
    return SizedBox(
      key: const ValueKey('app_shell_titlebar'),
      height: OfficialCodexTheme.shellToolbarHeight,
      child: Row(
        children: [
          const SizedBox(width: ThemeTokens.space2),
          CodexIconButton(
            key: ValueKey(
              _sidebarCollapsed
                  ? 'sidebar-expand-button'
                  : 'sidebar-collapse-button',
            ),
            tooltip: '$sidebarLabel (Ctrl+B)',
            size: 28,
            onPressed: _toggleSidebar,
            icon: Transform.flip(
              flipX: true,
              child: const Icon(Icons.view_sidebar_outlined, size: 17),
            ),
          ),
          const SizedBox(width: ThemeTokens.space2),
          _applicationMenu(
            'File',
            _fileMenu,
            () => [
              CodexMenuItem(
                value: () {
                  if (!widget.threadController.mutating) {
                    unawaited(_threadPanelKey.currentState?._startThread());
                  }
                },
                label: 'New thread',
              ),
              CodexMenuItem(
                value: () {
                  if (!widget.threadController.mutating) {
                    unawaited(_threadPanelKey.currentState?._chooseDirectory());
                  }
                },
                label: 'New thread location',
              ),
            ],
          ),
          _applicationMenu('View', _viewMenu, () {
            final threads = widget.threadController;
            final pinned = threads.builtInPinnedSection;
            return [
              CodexMenuItem(value: _toggleSidebar, label: sidebarLabel),
              CodexMenuItem(
                value: () {
                  if (_sidebarCollapsed) {
                    _toggleSidebar();
                  }
                  _threadPanelKey.currentState?._openSearch();
                },
                label: 'Search threads',
              ),
              if (pinned != null && !threads.showArchived)
                CodexMenuItem(
                  value: () {
                    if (_sidebarCollapsed) {
                      _toggleSidebar();
                    }
                    unawaited(threads.setSectionScope(pinned.id));
                  },
                  label: 'Browse saved pins',
                  disabled: threads.catalogBusy,
                ),
            ];
          }),
        ],
      ),
    );
  }

  Widget _applicationMenu(
    String label,
    CodexPopoverController controller,
    List<CodexMenuItem<VoidCallback>> Function() items,
  ) => CodexPopoverAnchor(
    controller: controller,
    width: 194,
    popoverBuilder: (context, close) => CodexMenu<VoidCallback>(
      items: items(),
      onSelected: (action) {
        close();
        action();
      },
    ),
    child: CodexButton(
      label: label,
      size: CodexButtonSize.sm,
      variant: CodexButtonVariant.ghost,
      onPressed: controller.toggle,
    ),
  );

  Widget _navigationRail() => Semantics(
    label: 'App navigation',
    container: true,
    child: SizedBox(
      key: const ValueKey('app-shell-navigation-rail'),
      width: OfficialCodexTheme.navigationRailWidth,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: ThemeTokens.space2),
              child: Column(
                children: [
                  CodexIconButton(
                    key: const ValueKey('app-shell-home-button'),
                    tooltip: 'Codex home',
                    selected: !_ecosystemOpen,
                    size: 36,
                    icon: const Icon(Icons.home_rounded, size: 19),
                    onPressed: () => widget
                        .conversationKey
                        .currentState
                        ?._conversationFocusNode
                        .requestFocus(),
                  ),
                  const SizedBox(height: ThemeTokens.space2),
                  CodexIconButton(
                    key: const ValueKey('ecosystem-button'),
                    tooltip: 'Skills, Plugins & MCP',
                    selected: _ecosystemOpen,
                    size: 36,
                    icon: const Icon(Icons.widgets_outlined, size: 20),
                    onPressed: _openRailEcosystem,
                  ),
                ],
              ),
            ),
          ),
          CodexIconButton(
            key: const ValueKey('remote-setup-button'),
            tooltip: 'Remote & host settings',
            size: 36,
            icon: const Icon(Icons.devices_outlined, size: 19),
            onPressed: () => _threadPanelKey.currentState?._openRemoteSetup(),
          ),
          _RuntimeStatusPill(
            controller: widget.runtimeController,
            compact: true,
          ),
          const SizedBox(height: ThemeTokens.space2),
        ],
      ),
    ),
  );
}

class _CompactWorkspace extends StatefulWidget {
  const _CompactWorkspace({
    super.key,
    required this.threadController,
    required this.initialShowSidebar,
    required this.sidebarBuilder,
    required this.conversationBuilder,
  });

  final ThreadListController threadController;
  final bool initialShowSidebar;
  final Widget Function(VoidCallback onThreadSelected) sidebarBuilder;
  final Widget Function(bool isOffstage) conversationBuilder;

  @override
  State<_CompactWorkspace> createState() => _CompactWorkspaceState();
}

class _CompactWorkspaceState extends State<_CompactWorkspace> {
  late bool _showSidebar;
  String? _selectedThreadId;
  final _focusNode = FocusNode(debugLabel: 'compact-workspace');

  @override
  void initState() {
    super.initState();
    _selectedThreadId = widget.threadController.selectedThread?.id;
    _showSidebar = widget.initialShowSidebar && _selectedThreadId == null;
    widget.threadController.addListener(_handleThreadSelection);
  }

  @override
  void didUpdateWidget(covariant _CompactWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadController == widget.threadController) {
      return;
    }
    oldWidget.threadController.removeListener(_handleThreadSelection);
    _selectedThreadId = widget.threadController.selectedThread?.id;
    widget.threadController.addListener(_handleThreadSelection);
  }

  @override
  void dispose() {
    widget.threadController.removeListener(_handleThreadSelection);
    _focusNode.dispose();
    super.dispose();
  }

  void _setShowSidebar(bool value) {
    if (_showSidebar == value || !mounted) {
      return;
    }
    setState(() => _showSidebar = value);
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showSidebar && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_showSidebar) {
            _setShowSidebar(false);
          }
        },
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Column(
          children: [
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(
                horizontal: ThemeTokens.space2,
              ),
              decoration: BoxDecoration(
                color: _showSidebar ? palette.sidebar : palette.canvas,
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  CodexIconButton(
                    key: const ValueKey('compact-workspace-toggle'),
                    tooltip: _showSidebar
                        ? 'Show conversation'
                        : 'Show threads',
                    onPressed: () => _setShowSidebar(!_showSidebar),
                    icon: Icon(
                      _showSidebar
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.menu_rounded,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: ThemeTokens.space1),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: widget.threadController,
                      builder: (context, _) => Text(
                        _showSidebar
                            ? 'Threads'
                            : widget
                                      .threadController
                                      .selectedThread
                                      ?.displayTitle ??
                                  'Conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Offstage(
                    offstage: !_showSidebar,
                    child: TickerMode(
                      enabled: _showSidebar,
                      child: ExcludeFocus(
                        excluding: !_showSidebar,
                        child: widget.sidebarBuilder(_closeSidebar),
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: _showSidebar,
                    child: TickerMode(
                      enabled: !_showSidebar,
                      child: ExcludeFocus(
                        excluding: _showSidebar,
                        child: widget.conversationBuilder(_showSidebar),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _closeSidebar() {
    _selectedThreadId = widget.threadController.selectedThread?.id;
    _setShowSidebar(false);
  }

  void _handleThreadSelection() {
    final next = widget.threadController.selectedThread?.id;
    if (next == null) {
      _selectedThreadId = null;
      return;
    }
    if (next == _selectedThreadId) {
      return;
    }
    _selectedThreadId = next;
    _setShowSidebar(false);
  }
}

class _StandaloneSurface extends StatelessWidget {
  const _StandaloneSurface({required this.controller, required this.child});

  final RuntimeController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return ColoredBox(
      color: palette.canvas,
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.space4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 19),
                const SizedBox(width: ThemeTokens.space2),
                Text(
                  'Codex Native',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                _RuntimeStatusPill(controller: controller, compact: true),
              ],
            ),
          ),
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.space4),
            color: palette.surfaceRaised,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _runtimeStatusColor(context, controller.snapshot),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: ThemeTokens.space2),
                Expanded(
                  child: Text(
                    controller.snapshot.stateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: const EdgeInsets.all(ThemeTokens.space6),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeConnectionScreen extends StatelessWidget {
  const _RuntimeConnectionScreen({required this.controller});

  final RuntimeController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final palette = ThemeTokens.of(context);
    final failed = switch (snapshot.state) {
      RuntimeConnectionState.error ||
      RuntimeConnectionState.processExited ||
      RuntimeConnectionState.notFound ||
      RuntimeConnectionState.hostNotFound => true,
      _ => false,
    };
    return ColoredBox(
      color: palette.canvas,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ThemeTokens.space6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: failed
                        ? palette.danger.withValues(alpha: 0.1)
                        : palette.surfaceRaised,
                    border: Border.all(color: palette.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    failed
                        ? Icons.error_outline_rounded
                        : Icons.terminal_rounded,
                    color: failed ? palette.danger : palette.textPrimary,
                    size: 23,
                  ),
                ),
                const SizedBox(height: ThemeTokens.space5),
                Text(
                  'Codex Native',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: ThemeTokens.space1),
                Text(
                  'Unofficial native-first client',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: ThemeTokens.space6),
                Text(
                  snapshot.stateLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (snapshot.message case final message?) ...[
                  const SizedBox(height: ThemeTokens.space3),
                  SelectableText(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: failed ? palette.danger : palette.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: ThemeTokens.space5),
                _RuntimeStatusPill(controller: controller, showDetails: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuntimeStatusPill extends StatelessWidget {
  const _RuntimeStatusPill({
    required this.controller,
    this.showDetails = false,
    this.compact = false,
  });

  final RuntimeController controller;
  final bool showDetails;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final color = _runtimeStatusColor(context, snapshot);
    if (compact) {
      return CodexIconButton(
        tooltip: '${snapshot.stateLabel} — runtime details',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => _RuntimeDetailsDialog(controller: controller),
        ),
        icon: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
    }
    if (!showDetails && snapshot.state == RuntimeConnectionState.connected) {
      return CodexButton(
        variant: CodexButtonVariant.ghost,
        size: CodexButtonSize.sm,
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => _RuntimeDetailsDialog(controller: controller),
        ),
        icon: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        label: snapshot.stateLabel,
      );
    }
    return CodexButton(
      key: showDetails ? const ValueKey('runtime-details-button') : null,
      variant: CodexButtonVariant.secondary,
      size: CodexButtonSize.sm,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => _RuntimeDetailsDialog(controller: controller),
      ),
      icon: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: showDetails ? 'Runtime details' : snapshot.stateLabel,
    );
  }
}

Color _runtimeStatusColor(BuildContext context, RuntimeSnapshot snapshot) {
  final palette = ThemeTokens.of(context);
  return switch (snapshot.state) {
    RuntimeConnectionState.connected ||
    RuntimeConnectionState.remoteReadOnly => palette.success,
    RuntimeConnectionState.error ||
    RuntimeConnectionState.processExited ||
    RuntimeConnectionState.notFound ||
    RuntimeConnectionState.hostNotFound ||
    RuntimeConnectionState.remoteCredentialRecoveryRequired ||
    RuntimeConnectionState.remoteRevoked => palette.danger,
    _ => palette.warning,
  };
}
