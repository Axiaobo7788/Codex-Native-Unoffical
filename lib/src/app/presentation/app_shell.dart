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
          final sidebar = _ThreadPanel(
            controller: threadController,
            settingsController: settingsController,
            runtimeController: controller,
            defaultWorkingDirectory: defaultWorkingDirectory,
          );
          final conversation = _ConversationPanel(
            controller: conversationController,
            historyController: historyController,
            approvalController: approvalController,
            settingsController: settingsController,
            diffController: diffController,
            outputGateway: controller,
          );
          if (constraints.maxWidth < _desktopSplitMinimumWidth) {
            return _CompactWorkspace(
              key: const ValueKey('compact-workspace'),
              threadController: threadController,
              sidebar: sidebar,
              conversation: conversation,
            );
          }
          return Row(
            key: const ValueKey('desktop-split-workspace'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: _desktopSidebarWidth, child: sidebar),
              VerticalDivider(width: 1, color: ThemeTokens.of(context).border),
              Expanded(child: conversation),
            ],
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
                  IconButton(
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
      return IconButton(
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
    return OutlinedButton.icon(
      key: showDetails ? const ValueKey('runtime-details-button') : null,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => _RuntimeDetailsDialog(controller: controller),
      ),
      icon: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(showDetails ? 'Runtime details' : snapshot.stateLabel),
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
