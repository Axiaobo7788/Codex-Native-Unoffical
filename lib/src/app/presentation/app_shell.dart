part of '../codex_native_app.dart';

class RuntimeStatusScreen extends StatelessWidget {
  const RuntimeStatusScreen({
    super.key,
    required this.controller,
    required this.threadController,
    required this.conversationController,
    required this.historyController,
    required this.approvalController,
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
      RuntimeConnectionState.connected => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _desktopSplitMinimumWidth) {
            final sidebar = _ThreadPanel(
              controller: threadController,
              settingsController: settingsController,
              runtimeController: controller,
              defaultWorkingDirectory: defaultWorkingDirectory,
            );
            final conversation = _ConversationPanel(
              controller: conversationController,
              threadController: threadController,
              historyController: historyController,
              approvalController: approvalController,
              settingsController: settingsController,
              diffController: diffController,
              outputGateway: controller,
              defaultWorkingDirectory: defaultWorkingDirectory,
            );
            return _CompactWorkspace(
              key: const ValueKey('compact-workspace'),
              threadController: threadController,
              sidebar: sidebar,
              conversation: conversation,
            );
          }
          return _DesktopSplitWorkspace(
            key: const ValueKey('desktop-split-workspace'),
            runtimeController: controller,
            threadController: threadController,
            conversationController: conversationController,
            historyController: historyController,
            approvalController: approvalController,
            settingsController: settingsController,
            diffController: diffController,
            defaultWorkingDirectory: defaultWorkingDirectory,
          );
        },
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

class _DesktopSplitWorkspace extends StatefulWidget {
  const _DesktopSplitWorkspace({
    super.key,
    required this.runtimeController,
    required this.threadController,
    required this.conversationController,
    required this.historyController,
    required this.approvalController,
    required this.settingsController,
    required this.diffController,
    required this.defaultWorkingDirectory,
  });

  final RuntimeController runtimeController;
  final ThreadListController threadController;
  final ConversationController conversationController;
  final HistoryController historyController;
  final ApprovalController approvalController;
  final ExecutionSettingsController settingsController;
  final DiffController diffController;
  final String defaultWorkingDirectory;

  @override
  State<_DesktopSplitWorkspace> createState() => _DesktopSplitWorkspaceState();
}

class _DesktopSplitWorkspaceState extends State<_DesktopSplitWorkspace> {
  var _sidebarCollapsed = false;

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
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
        color: theme.shellBackground,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_sidebarCollapsed)
              SizedBox(
                key: const ValueKey('app_shell_sidebar'),
                width: _desktopSidebarWidth,
                child: _ThreadPanel(
                  controller: widget.threadController,
                  settingsController: widget.settingsController,
                  runtimeController: widget.runtimeController,
                  defaultWorkingDirectory: widget.defaultWorkingDirectory,
                  onToggleSidebar: _toggleSidebar,
                ),
              ),
            Expanded(
              child: Container(
                key: const ValueKey('inset_workspace_card'),
                margin: EdgeInsets.fromLTRB(
                  _sidebarCollapsed ? 6.0 : 0.0,
                  6.0,
                  6.0,
                  6.0,
                ),
                decoration: BoxDecoration(
                  color: theme.workspaceBackground,
                  borderRadius: BorderRadius.circular(
                    OfficialCodexTheme.mainSurfaceRadius,
                  ),
                  border: Border.all(
                    color: theme.hairlineBorder,
                    width: OfficialCodexTheme.hairlineBorderWidth,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _ConversationPanel(
                  controller: widget.conversationController,
                  threadController: widget.threadController,
                  historyController: widget.historyController,
                  approvalController: widget.approvalController,
                  settingsController: widget.settingsController,
                  diffController: widget.diffController,
                  outputGateway: widget.runtimeController,
                  defaultWorkingDirectory: widget.defaultWorkingDirectory,
                  sidebarCollapsed: _sidebarCollapsed,
                  onToggleSidebar: _toggleSidebar,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactWorkspace extends StatefulWidget {
  const _CompactWorkspace({
    super.key,
    required this.threadController,
    required this.sidebar,
    required this.conversation,
  });

  final ThreadListController threadController;
  final Widget sidebar;
  final Widget conversation;

  @override
  State<_CompactWorkspace> createState() => _CompactWorkspaceState();
}

class _CompactWorkspaceState extends State<_CompactWorkspace> {
  var _showSidebar = true;
  String? _selectedThreadId;

  @override
  void initState() {
    super.initState();
    _selectedThreadId = widget.threadController.selectedThread?.id;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_showSidebar) {
            setState(() => _showSidebar = false);
          }
        },
      },
      child: Focus(
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
                    onPressed: () =>
                        setState(() => _showSidebar = !_showSidebar),
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_showSidebar),
                  child: _showSidebar ? widget.sidebar : widget.conversation,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleThreadSelection() {
    final next = widget.threadController.selectedThread?.id;
    if (next == null || next == _selectedThreadId) {
      return;
    }
    _selectedThreadId = next;
    if (mounted && _showSidebar) {
      setState(() => _showSidebar = false);
    }
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
