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
        child: Padding(
          padding: const EdgeInsets.all(ThemeTokens.space6),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RuntimePanel(controller: controller),
                    if (controller.snapshot.state ==
                        RuntimeConnectionState.connected) ...[
                      const SizedBox(height: ThemeTokens.space4),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final threads = _ThreadPanel(
                              controller: threadController,
                              settingsController: settingsController,
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
                            if (constraints.maxWidth <
                                _desktopSplitMinimumWidth) {
                              final conversationHeight =
                                  constraints.maxHeight <
                                      _compactConversationMinimumHeight
                                  ? _compactConversationMinimumHeight
                                  : constraints.maxHeight;
                              return _CompactWorkspace(
                                key: const ValueKey('compact-workspace'),
                                threads: threads,
                                conversation: conversation,
                                conversationHeight: conversationHeight,
                              );
                            }
                            return Row(
                              key: const ValueKey('desktop-split-workspace'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(width: 360, child: threads),
                                const SizedBox(width: ThemeTokens.space4),
                                Expanded(child: conversation),
                              ],
                            );
                          },
                        ),
                      ),
                    ] else if (controller.snapshot.state ==
                        RuntimeConnectionState.remoteReadOnly) ...[
                      const SizedBox(height: ThemeTokens.space4),
                      Expanded(
                        child: _RemoteReadOnlyPanel(controller: controller),
                      ),
                    ] else if (controller.snapshot.state ==
                        RuntimeConnectionState.remoteUnpaired) ...[
                      const SizedBox(height: ThemeTokens.space4),
                      Expanded(
                        child: _RemotePairingPanel(
                          controller: controller,
                          scannerLauncher: remotePairingScannerLauncher,
                        ),
                      ),
                    ] else if (controller.snapshot.state ==
                            RuntimeConnectionState
                                .remoteCredentialRecoveryRequired ||
                        controller.snapshot.state ==
                            RuntimeConnectionState.remoteRevoked) ...[
                      const SizedBox(height: ThemeTokens.space4),
                      Expanded(
                        child: _RemoteRecoveryPanel(controller: controller),
                      ),
                    ],
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

class _CompactWorkspace extends StatefulWidget {
  const _CompactWorkspace({
    super.key,
    required this.threads,
    required this.conversation,
    required this.conversationHeight,
  });

  final Widget threads;
  final Widget conversation;
  final double conversationHeight;

  @override
  State<_CompactWorkspace> createState() => _CompactWorkspaceState();
}

class _CompactWorkspaceState extends State<_CompactWorkspace> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: _compactThreadPanelHeight, child: widget.threads),
            const SizedBox(height: ThemeTokens.space4),
            SizedBox(
              height: widget.conversationHeight,
              child: widget.conversation,
            ),
          ],
        ),
      ),
    );
  }
}
