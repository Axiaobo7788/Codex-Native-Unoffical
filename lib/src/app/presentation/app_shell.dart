part of '../codex_native_app.dart';

class RuntimeStatusScreen extends StatefulWidget {
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
    this.mcpOauthController,
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
  final McpOauthController? mcpOauthController;

  @override
  State<RuntimeStatusScreen> createState() => _RuntimeStatusScreenState();
}

class _RuntimeStatusScreenState extends State<RuntimeStatusScreen> {
  var _hasLocalWorkspace = false;

  @override
  void didUpdateWidget(covariant RuntimeStatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _hasLocalWorkspace = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final controller = widget.controller;
    final connected =
        controller.snapshot.state == RuntimeConnectionState.connected;
    if (!controller.usesRemote && connected) _hasLocalWorkspace = true;
    if (controller.usesRemote) _hasLocalWorkspace = false;
    if (_hasLocalWorkspace) {
      // Keep one bounded workspace, including its editor/attachments, mounted
      // across local runtime loss. The existing opaque connection surface still
      // owns interaction while disconnected; no writes or automatic resume are
      // admitted through the hidden workspace.
      return Stack(
        fit: StackFit.expand,
        children: [
          TickerMode(
            enabled: connected,
            child: ExcludeSemantics(
              excluding: !connected,
              child: ExcludeFocus(
                excluding: !connected,
                child: IgnorePointer(ignoring: !connected, child: _workspace()),
              ),
            ),
          ),
          if (!connected) _RuntimeConnectionScreen(controller: controller),
        ],
      );
    }
    return switch (controller.snapshot.state) {
      RuntimeConnectionState.connected => _workspace(),
      RuntimeConnectionState.remoteReadOnly => _StandaloneSurface(
        controller: controller,
        child: _RemoteReadOnlyPanel(controller: controller),
      ),
      RuntimeConnectionState.remoteUnpaired => _StandaloneSurface(
        controller: controller,
        child: _RemotePairingPanel(
          controller: controller,
          scannerLauncher: widget.remotePairingScannerLauncher,
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

  Widget _workspace() => _ConnectedWorkspace(
    runtimeController: widget.controller,
    threadController: widget.threadController,
    conversationController: widget.conversationController,
    historyController: widget.historyController,
    approvalController: widget.approvalController,
    userInputController: widget.userInputController,
    settingsController: widget.settingsController,
    diffController: widget.diffController,
    mcpOauthController: widget.mcpOauthController,
    defaultWorkingDirectory: widget.defaultWorkingDirectory,
  );
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
    this.mcpOauthController,
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
  final McpOauthController? mcpOauthController;

  @override
  State<_ConnectedWorkspace> createState() => _ConnectedWorkspaceState();
}

enum _DesktopShellDestination { home, customize }

typedef _DesktopNavigationEntry = ({
  _DesktopShellDestination destination,
  String? threadId,
  _EcosystemSection customizeSection,
});

typedef _EcosystemContextKey = ({
  String cwd,
  String? threadId,
  int runtimeVersion,
  bool connected,
});

class _ConnectedWorkspaceState extends State<_ConnectedWorkspace> {
  static const _maxNavigationEntries = 32;
  final _conversationKey = GlobalKey<_ConversationPanelState>();
  final _navigationEntries = <_DesktopNavigationEntry>[];
  var _navigationIndex = -1;
  var _navigationOperationEpoch = 0;
  _DesktopNavigationEntry? _pendingNavigationEntry;
  var _activeDestination = _DesktopShellDestination.home;
  var _activeCustomizeSection = _EcosystemSection.plugins;
  var _isCompactLayout = false;
  var _hasCurrentRoute = true;
  var _desktopLeftPanelWidth = OfficialCodexTheme.desktopLeftPanelWidth;
  late String _workingDirectory;
  _EcosystemController? _customizeController;
  _EcosystemContextKey? _customizeControllerKey;

  bool get _canObserveMcpOauthReadback =>
      !_isCompactLayout &&
      _hasCurrentRoute &&
      _activeDestination == _DesktopShellDestination.customize;

  @override
  void initState() {
    super.initState();
    _workingDirectory = widget.defaultWorkingDirectory;
    _bindNavigationState();
  }

  @override
  void didUpdateWidget(covariant _ConnectedWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultWorkingDirectory != widget.defaultWorkingDirectory &&
        _workingDirectory == oldWidget.defaultWorkingDirectory) {
      _workingDirectory = widget.defaultWorkingDirectory;
    }
    if (oldWidget.threadController != widget.threadController ||
        oldWidget.runtimeController != widget.runtimeController ||
        oldWidget.mcpOauthController != widget.mcpOauthController ||
        oldWidget.userInputController != widget.userInputController) {
      oldWidget.threadController.removeListener(_handleThreadControllerChanged);
      _disposeCustomizeController();
      _bindNavigationState();
    } else {
      _syncCustomizeControllerContext();
    }
  }

  @override
  void dispose() {
    widget.threadController.removeListener(_handleThreadControllerChanged);
    _disposeCustomizeController();
    super.dispose();
  }

  _EcosystemContextKey get _currentEcosystemContextKey => (
    cwd: (widget.threadController.selectedThread?.cwd ?? _workingDirectory)
        .trim(),
    threadId: widget.threadController.selectedThread?.id,
    runtimeVersion: widget.conversationController.runtimeInvalidationVersion,
    connected:
        widget.runtimeController.snapshot.state ==
        RuntimeConnectionState.connected,
  );

  void _disposeCustomizeController() {
    _customizeController?.dispose();
    _customizeController = null;
    _customizeControllerKey = null;
  }

  _EcosystemController _ensureCustomizeController() {
    final key = _currentEcosystemContextKey;
    final existing = _customizeController;
    if (existing != null && _customizeControllerKey == key) {
      existing.setMcpOauthReadbackEnabled(_canObserveMcpOauthReadback);
      return existing;
    }
    existing?.dispose();
    final created = _EcosystemController(
      gateway: widget.runtimeController,
      cwd: key.cwd,
      threadId: key.threadId,
      threadController: widget.threadController,
      userInputController: widget.userInputController,
      mcpOauthController: widget.mcpOauthController,
      mcpOauthReadbackEnabled: _canObserveMcpOauthReadback,
      isModal: false,
      initialSection: _activeCustomizeSection,
    );
    _customizeController = created;
    _customizeControllerKey = key;
    return created;
  }

  void _syncCustomizeControllerContext() {
    final existing = _customizeController;
    if (existing == null) {
      if (_activeDestination == _DesktopShellDestination.customize) {
        _ensureCustomizeController();
      }
      return;
    }
    final key = _currentEcosystemContextKey;
    if (_customizeControllerKey == key) {
      return;
    }
    existing.dispose();
    _customizeController = null;
    _customizeControllerKey = null;
    if (_activeDestination == _DesktopShellDestination.customize) {
      _ensureCustomizeController();
    }
  }

  void _handleWorkingDirectoryChanged(String nextDirectory) {
    final normalized = nextDirectory.trim();
    if (normalized.isEmpty || normalized == _workingDirectory) {
      return;
    }
    setState(() {
      _workingDirectory = normalized;
      _syncCustomizeControllerContext();
    });
  }

  void _bindNavigationState() {
    ++_navigationOperationEpoch;
    _navigationEntries.clear();
    _pendingNavigationEntry = null;
    if (widget.threadController.selectedThread?.id case final threadId?) {
      _navigationEntries.add((
        destination: _DesktopShellDestination.home,
        threadId: threadId,
        customizeSection: _activeCustomizeSection,
      ));
    }
    _navigationIndex = _navigationEntries.length - 1;
    widget.threadController.addListener(_handleThreadControllerChanged);
    if (_activeDestination == _DesktopShellDestination.customize) {
      _ensureCustomizeController();
    }
  }

  void _pushNavigationEntry(_DesktopNavigationEntry entry) {
    final current =
        _navigationIndex >= 0 && _navigationIndex < _navigationEntries.length
        ? _navigationEntries[_navigationIndex]
        : null;
    if (current == entry) {
      return;
    }
    if (_navigationIndex < _navigationEntries.length - 1) {
      _navigationEntries.removeRange(
        _navigationIndex + 1,
        _navigationEntries.length,
      );
    }
    _navigationEntries.add(entry);
    if (_navigationEntries.length > _maxNavigationEntries) {
      _navigationEntries.removeAt(0);
    }
    _navigationIndex = _navigationEntries.length - 1;
  }

  void _handleThreadControllerChanged() {
    final threadId = widget.threadController.selectedThread?.id;
    final pending = _pendingNavigationEntry;
    if (pending != null && threadId != null && threadId == pending.threadId) {
      _syncCustomizeControllerContext();
      return;
    }
    final current =
        _navigationIndex >= 0 && _navigationIndex < _navigationEntries.length
        ? _navigationEntries[_navigationIndex]
        : null;
    final previousContextKey = _customizeControllerKey;
    final nextContextKey = _currentEcosystemContextKey;
    final threadChanged = threadId != current?.threadId;
    if (!threadChanged && previousContextKey == nextContextKey) {
      return;
    }
    setState(() {
      _syncCustomizeControllerContext();
      if (!threadChanged) {
        return;
      }
      if (!_isCompactLayout &&
          _activeDestination == _DesktopShellDestination.customize) {
        if (current != null &&
            current.destination == _DesktopShellDestination.customize) {
          _navigationEntries[_navigationIndex] = (
            destination: _DesktopShellDestination.customize,
            threadId: threadId,
            customizeSection: current.customizeSection,
          );
        }
        return;
      }
      if (threadId == null &&
          _activeDestination == _DesktopShellDestination.home) {
        _navigationEntries.clear();
        _navigationIndex = -1;
        return;
      }
      if (threadId != null) {
        _activeDestination = _DesktopShellDestination.home;
        _pushNavigationEntry((
          destination: _DesktopShellDestination.home,
          threadId: threadId,
          customizeSection: _activeCustomizeSection,
        ));
      }
    });
  }

  void _selectHomeDestination({bool requestConversationFocus = true}) {
    if (_activeDestination == _DesktopShellDestination.home) {
      if (_pendingNavigationEntry != null) {
        setState(() {
          ++_navigationOperationEpoch;
          _pendingNavigationEntry = null;
        });
      }
      if (requestConversationFocus) {
        _conversationKey.currentState?._conversationFocusNode.requestFocus();
      }
      return;
    }
    setState(() {
      ++_navigationOperationEpoch;
      _pendingNavigationEntry = null;
      _activeDestination = _DesktopShellDestination.home;
      _pushNavigationEntry((
        destination: _DesktopShellDestination.home,
        threadId: widget.threadController.selectedThread?.id,
        customizeSection: _activeCustomizeSection,
      ));
    });
    if (requestConversationFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeDestination == _DesktopShellDestination.home) {
          _conversationKey.currentState?._conversationFocusNode.requestFocus();
        }
      });
    }
  }

  void _selectCustomizeDestination({_EcosystemSection? section}) {
    final targetSection = section ?? _activeCustomizeSection;
    final currentThreadId = widget.threadController.selectedThread?.id;
    if (_activeDestination == _DesktopShellDestination.customize &&
        _activeCustomizeSection == targetSection) {
      if (_pendingNavigationEntry != null) {
        setState(() {
          ++_navigationOperationEpoch;
          _pendingNavigationEntry = null;
        });
      }
      return;
    }
    setState(() {
      ++_navigationOperationEpoch;
      _pendingNavigationEntry = null;
      if (_navigationEntries.isEmpty &&
          _activeDestination == _DesktopShellDestination.home) {
        _pushNavigationEntry((
          destination: _DesktopShellDestination.home,
          threadId: currentThreadId,
          customizeSection: _activeCustomizeSection,
        ));
      }
      _activeDestination = _DesktopShellDestination.customize;
      _activeCustomizeSection = targetSection;
      final controller = _ensureCustomizeController();
      controller.setSection(targetSection);
      _pushNavigationEntry((
        destination: _DesktopShellDestination.customize,
        threadId: currentThreadId,
        customizeSection: targetSection,
      ));
    });
  }

  Future<void> _moveNavigationVisit(int delta) async {
    final controller = widget.threadController;
    final index = _navigationIndex + delta;
    if (_pendingNavigationEntry != null ||
        controller.mutating ||
        index < 0 ||
        index >= _navigationEntries.length) {
      return;
    }
    final operationEpoch = ++_navigationOperationEpoch;
    final target = _navigationEntries[index];
    final currentThreadId = controller.selectedThread?.id;
    final needsThreadSelect =
        target.threadId != null && target.threadId != currentThreadId;
    if (!needsThreadSelect) {
      setState(() {
        _pendingNavigationEntry = null;
        _navigationIndex = index;
        _activeDestination = target.destination;
        if (target.destination == _DesktopShellDestination.customize) {
          _activeCustomizeSection = target.customizeSection;
          final customize = _ensureCustomizeController();
          customize.setSection(target.customizeSection);
        } else {
          _syncCustomizeControllerContext();
        }
      });
      return;
    }
    setState(() => _pendingNavigationEntry = target);
    try {
      await controller.selectThread(target.threadId!);
    } finally {
      if (mounted &&
          identical(controller, widget.threadController) &&
          operationEpoch == _navigationOperationEpoch) {
        setState(() {
          if (controller.selectedThread?.id == target.threadId) {
            _navigationIndex = index;
            _activeDestination = target.destination;
            if (target.destination == _DesktopShellDestination.customize) {
              _activeCustomizeSection = target.customizeSection;
              final customize = _ensureCustomizeController();
              customize.setSection(target.customizeSection);
            } else {
              _syncCustomizeControllerContext();
            }
          }
          _pendingNavigationEntry = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _desktopSplitMinimumWidth;
        _isCompactLayout = compact;
        _hasCurrentRoute = ModalRoute.isCurrentOf(context) ?? true;
        _customizeController?.setMcpOauthReadbackEnabled(
          _canObserveMcpOauthReadback,
        );
        if (compact) {
          final hasActiveConversation =
              widget.threadController.selectedThread != null ||
              (_conversationKey.currentState?.hasComposerDraft ?? false);
          return _CompactWorkspace(
            key: const ValueKey('compact-workspace'),
            threadController: widget.threadController,
            initialShowSidebar: !hasActiveConversation,
            sidebarBuilder: (onThreadSelected) => _ThreadPanel(
              mcpOauthController: widget.mcpOauthController,
              controller: widget.threadController,
              settingsController: widget.settingsController,
              runtimeController: widget.runtimeController,
              userInputController: widget.userInputController,
              defaultWorkingDirectory: _workingDirectory,
              onWorkingDirectoryChanged: _handleWorkingDirectoryChanged,
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
              defaultWorkingDirectory: _workingDirectory,
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
        final customizeController =
            _activeDestination == _DesktopShellDestination.customize
            ? _ensureCustomizeController()
            : _customizeController;
        final workspace = _DesktopSplitWorkspace(
          key: const ValueKey('desktop-split-workspace'),
          conversationKey: _conversationKey,
          destination: _activeDestination,
          customizeSection: _activeCustomizeSection,
          customizeController: customizeController,
          onSelectHome: _selectHomeDestination,
          onSelectCustomize: _selectCustomizeDestination,
          onBack: _pendingNavigationEntry == null && _navigationIndex > 0
              ? () => unawaited(_moveNavigationVisit(-1))
              : null,
          onForward:
              _pendingNavigationEntry == null &&
                  _navigationIndex < _navigationEntries.length - 1
              ? () => unawaited(_moveNavigationVisit(1))
              : null,
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
          mcpOauthController: widget.mcpOauthController,
          defaultWorkingDirectory: _workingDirectory,
          onWorkingDirectoryChanged: _handleWorkingDirectoryChanged,
        );
        return Listener(
          onPointerDown: (event) {
            if (event.kind != PointerDeviceKind.mouse) return;
            switch (event.buttons) {
              case kBackMouseButton:
                workspace.onBack?.call();
              case kForwardMouseButton:
                workspace.onForward?.call();
            }
          },
          child: workspace,
        );
      },
    );
  }
}

class _DesktopSplitWorkspace extends StatefulWidget {
  const _DesktopSplitWorkspace({
    super.key,
    required this.conversationKey,
    required this.destination,
    required this.customizeSection,
    required this.customizeController,
    required this.onSelectHome,
    required this.onSelectCustomize,
    required this.onBack,
    required this.onForward,
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
    required this.onWorkingDirectoryChanged,
    this.mcpOauthController,
  });

  final GlobalKey<_ConversationPanelState> conversationKey;
  final _DesktopShellDestination destination;
  final _EcosystemSection customizeSection;
  final _EcosystemController? customizeController;
  final void Function({bool requestConversationFocus}) onSelectHome;
  final void Function({_EcosystemSection? section}) onSelectCustomize;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
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
  final ValueChanged<String> onWorkingDirectoryChanged;
  final McpOauthController? mcpOauthController;

  @override
  State<_DesktopSplitWorkspace> createState() => _DesktopSplitWorkspaceState();
}

class _DesktopSplitWorkspaceState extends State<_DesktopSplitWorkspace> {
  final _threadPanelKey = GlobalKey<_ThreadPanelState>();
  final _customizeFocusNode = FocusNode(debugLabel: 'customize-workspace');
  final _fileMenu = CodexPopoverController();
  final _editMenu = CodexPopoverController();
  final _viewMenu = CodexPopoverController();
  final _helpMenu = CodexPopoverController();
  FocusNode? _editMenuTarget;
  var _sidebarCollapsed = false;

  bool get _isCustomize =>
      widget.destination == _DesktopShellDestination.customize;

  void _toggleSidebar() {
    Tooltip.dismissAllToolTips();
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  void _dismissTransientShellOverlays() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Tooltip.dismissAllToolTips();
      _fileMenu.hide();
      _editMenu.hide();
      _viewMenu.hide();
      _helpMenu.hide();
    });
  }

  @override
  void initState() {
    super.initState();
    _editMenu.addListener(() {
      if (!_editMenu.isOpen) _editMenuTarget = null;
    });
    if (_isCustomize) {
      _requestCustomizeFocus();
    }
  }

  @override
  void didUpdateWidget(covariant _DesktopSplitWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination) {
      _dismissTransientShellOverlays();
      if (_isCustomize) {
        _requestCustomizeFocus();
      } else {
        _restoreHomeFocusIfDetached();
      }
    }
  }

  void _requestCustomizeFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _isCustomize &&
          (ModalRoute.of(context)?.isCurrent ?? true) &&
          !_customizeFocusNode.hasFocus) {
        _customizeFocusNode.requestFocus();
      }
    });
  }

  void _restoreHomeFocusIfDetached() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _isCustomize ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null ||
          primary is FocusScopeNode ||
          primary.context == null) {
        widget.conversationKey.currentState?._conversationFocusNode
            .requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _customizeFocusNode.dispose();
    _fileMenu.dispose();
    _editMenu.dispose();
    _viewMenu.dispose();
    _helpMenu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final isCustomize = _isCustomize;
    final customizeController = widget.customizeController;

    return CallbackShortcuts(
      bindings: {
        if (widget.onBack case final back?) ...{
          const SingleActivator(LogicalKeyboardKey.bracketLeft, control: true):
              back,
          const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
              back,
        },
        if (widget.onForward case final forward?) ...{
          const SingleActivator(LogicalKeyboardKey.bracketRight, control: true):
              forward,
          const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true):
              forward,
        },
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _toggleSidebar,
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
            _toggleSidebar,
        if (isCustomize &&
            !_fileMenu.isOpen &&
            !_editMenu.isOpen &&
            !_viewMenu.isOpen &&
            !_helpMenu.isOpen)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              widget.onSelectHome(),
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
                            child: TooltipVisibility(
                              visible: !_sidebarCollapsed,
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
                                          Offstage(
                                            offstage: isCustomize,
                                            child: TooltipVisibility(
                                              visible:
                                                  !isCustomize &&
                                                  !_sidebarCollapsed,
                                              child: TickerMode(
                                                enabled: !isCustomize,
                                                child: ExcludeFocus(
                                                  excluding: isCustomize,
                                                  child: _ThreadPanel(
                                                    mcpOauthController: widget
                                                        .mcpOauthController,
                                                    key: _threadPanelKey,
                                                    controller:
                                                        widget.threadController,
                                                    settingsController: widget
                                                        .settingsController,
                                                    runtimeController: widget
                                                        .runtimeController,
                                                    userInputController: widget
                                                        .userInputController,
                                                    defaultWorkingDirectory: widget
                                                        .defaultWorkingDirectory,
                                                    onWorkingDirectoryChanged:
                                                        widget
                                                            .onWorkingDirectoryChanged,
                                                    hasNavigationRail: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (isCustomize &&
                                              customizeController != null)
                                            _CustomizeSidebar(
                                              controller: customizeController,
                                              selectedSection:
                                                  widget.customizeSection,
                                              onSelectSection: (section) =>
                                                  widget.onSelectCustomize(
                                                    section: section,
                                                  ),
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
                          ),
                          Expanded(
                            child: KeyedSubtree(
                              key: const ValueKey('app-shell-workspace'),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Offstage(
                                    offstage: isCustomize,
                                    child: TooltipVisibility(
                                      visible: !isCustomize,
                                      child: TickerMode(
                                        enabled: !isCustomize,
                                        child: ExcludeFocus(
                                          excluding: isCustomize,
                                          child: _ConversationPanel(
                                            key: widget.conversationKey,
                                            controller:
                                                widget.conversationController,
                                            threadController:
                                                widget.threadController,
                                            historyController:
                                                widget.historyController,
                                            approvalController:
                                                widget.approvalController,
                                            userInputController:
                                                widget.userInputController,
                                            settingsController:
                                                widget.settingsController,
                                            diffController:
                                                widget.diffController,
                                            outputGateway:
                                                widget.runtimeController,
                                            transportCapabilities: widget
                                                .runtimeController
                                                .capabilities,
                                            defaultWorkingDirectory:
                                                widget.defaultWorkingDirectory,
                                            hasDesktopShell: true,
                                            isOffstage: isCustomize,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isCustomize &&
                                      customizeController != null)
                                    Focus(
                                      focusNode: _customizeFocusNode,
                                      child: _CustomizeWorkspaceView(
                                        controller: customizeController,
                                        selectedSection:
                                            widget.customizeSection,
                                        sidebarCollapsed: _sidebarCollapsed,
                                        onSelectSection: (section) =>
                                            widget.onSelectCustomize(
                                              section: section,
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
          ListenableBuilder(
            listenable: widget.threadController,
            builder: (context, _) {
              final busy = widget.threadController.mutating;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CodexIconButton(
                    key: const ValueKey('app-shell-back-button'),
                    tooltip: 'Back',
                    size: 28,
                    onPressed: busy ? null : widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  ),
                  CodexIconButton(
                    key: const ValueKey('app-shell-forward-button'),
                    tooltip: 'Forward',
                    size: 28,
                    onPressed: busy ? null : widget.onForward,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: ThemeTokens.space1),
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
                    widget.onSelectHome(requestConversationFocus: false);
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
          TextFieldTapRegion(
            child: _applicationMenu(
              'Edit',
              _editMenu,
              _editMenuItems,
              onPressed: () {
                if (!_editMenu.isOpen) {
                  _editMenuTarget = FocusManager.instance.primaryFocus;
                }
                _editMenu.toggle();
              },
            ),
          ),
          _applicationMenu('View', _viewMenu, () {
            final threads = widget.threadController;
            final pinned = threads.builtInPinnedSection;
            return [
              CodexMenuItem(value: _toggleSidebar, label: sidebarLabel),
              CodexMenuItem(
                value: () {
                  widget.onSelectHome(requestConversationFocus: false);
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
                    widget.onSelectHome(requestConversationFocus: false);
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
          _applicationMenu('Help', _helpMenu, _helpMenuItems),
        ],
      ),
    );
  }

  Widget _applicationMenu(
    String label,
    CodexPopoverController controller,
    List<CodexMenuItem<VoidCallback>> Function() items, {
    VoidCallback? onPressed,
  }) => CodexPopoverAnchor(
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
      onPressed: onPressed ?? controller.toggle,
    ),
  );

  List<CodexMenuItem<VoidCallback>> _editMenuItems() {
    final focus = _editMenuTarget;
    final target = focus?.context;
    const cause = SelectionChangedCause.toolbar;
    const roles = <(String, Intent)>[
      ('Undo', UndoTextIntent(cause)),
      ('Redo', RedoTextIntent(cause)),
      ('Cut', CopySelectionTextIntent.cut(cause)),
      ('Copy', CopySelectionTextIntent.copy),
      ('Paste', PasteTextIntent(cause)),
      ('Delete', DeleteCharacterIntent(forward: true)),
      ('Select All', SelectAllTextIntent(cause)),
    ];
    bool enabled(Intent intent) {
      if (target == null) return false;
      final action = Actions.maybeFind(target, intent: intent);
      return action is ContextAction<Intent>
          ? action.isEnabled(intent, target)
          : action?.isEnabled(intent) ?? false;
    }

    return [
      for (final (label, intent) in roles)
        CodexMenuItem(
          label: label,
          disabled: !enabled(intent),
          value: () {
            if (target == null || !target.mounted || focus?.context != target) {
              return;
            }
            focus!.requestFocus();
            Actions.maybeInvoke(target, intent);
          },
        ),
    ];
  }

  List<CodexMenuItem<VoidCallback>> _helpMenuItems() => [
    for (final (label, url) in const [
      ('Documentation', 'https://developers.openai.com/codex/app'),
      ("What's New", 'https://developers.openai.com/codex/changelog'),
      (
        'Troubleshooting',
        'https://developers.openai.com/codex/app/troubleshooting',
      ),
      ('System Status', 'https://status.openai.com'),
    ])
      CodexMenuItem(
        label: label,
        value: () => unawaited(_openHelpLink(Uri.parse(url))),
      ),
  ];

  Future<void> _openHelpLink(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Exception {
      // Report an unavailable platform URL handler below.
    }
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not open the help page.')),
      );
    }
  }

  Widget _navigationRail() {
    final isCustomize = _isCustomize;
    return Semantics(
      label: 'App navigation',
      container: true,
      child: SizedBox(
        key: const ValueKey('app-shell-navigation-rail'),
        width: OfficialCodexTheme.navigationRailWidth,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: ThemeTokens.space2,
                ),
                child: Column(
                  children: [
                    CodexIconButton(
                      key: const ValueKey('app-shell-home-button'),
                      tooltip: 'Home',
                      selected: !isCustomize,
                      size: 36,
                      icon: Icon(
                        !isCustomize ? Icons.home_rounded : Icons.home_outlined,
                        size: 19,
                      ),
                      onPressed: widget.onSelectHome,
                    ),
                    const SizedBox(height: ThemeTokens.space2),
                    CodexIconButton(
                      key: const ValueKey('ecosystem-button'),
                      tooltip: 'Plugins',
                      selected: isCustomize,
                      size: 36,
                      icon: Icon(
                        isCustomize
                            ? Icons.widgets_rounded
                            : Icons.widgets_outlined,
                        size: 20,
                      ),
                      onPressed: () => widget.onSelectCustomize(),
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
                    child: TooltipVisibility(
                      visible: _showSidebar,
                      child: TickerMode(
                        enabled: _showSidebar,
                        child: ExcludeFocus(
                          excluding: !_showSidebar,
                          child: widget.sidebarBuilder(_closeSidebar),
                        ),
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: _showSidebar,
                    child: TooltipVisibility(
                      visible: !_showSidebar,
                      child: TickerMode(
                        enabled: !_showSidebar,
                        child: ExcludeFocus(
                          excluding: _showSidebar,
                          child: widget.conversationBuilder(_showSidebar),
                        ),
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
                if (controller.canRetryStartup) ...[
                  const SizedBox(height: ThemeTokens.space5),
                  CodexButton(
                    key: const ValueKey('runtime-startup-retry'),
                    label: 'Retry startup',
                    onPressed: () => unawaited(controller.retryStartup()),
                  ),
                ],
                if (controller.canRecoverWorkspace) ...[
                  const SizedBox(height: ThemeTokens.space5),
                  CodexButton(
                    key: const ValueKey('runtime-workspace-recover'),
                    label: 'Reconnect runtime',
                    onPressed: () => unawaited(controller.recoverWorkspace()),
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
