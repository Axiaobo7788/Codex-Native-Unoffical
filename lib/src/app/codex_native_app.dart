import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/diff_models.dart';
import '../domain/execution_settings.dart';
import '../domain/history_models.dart';
import '../domain/output_gateway.dart';
import '../domain/output_models.dart';
import '../domain/remote_admin_gateway.dart';
import '../domain/remote_admin_models.dart';
import '../domain/runtime_snapshot.dart';
import '../domain/thread_models.dart';
import '../features/approvals/approval_controller.dart';
import '../features/conversation/assistant_markdown.dart';
import '../features/conversation/conversation_controller.dart';
import '../features/conversation/history_controller.dart';
import '../features/conversation/output_viewer_controller.dart';
import '../features/diff/diff_controller.dart';
import '../features/settings/execution_settings_controller.dart';
import '../features/settings/remote_admin_controller.dart';
import '../features/settings/remote_pairing_qr.dart';
import '../features/settings/remote_pairing_scanner.dart';
import '../features/threads/thread_list_controller.dart';
import '../transport/remote/remote_onboarding.dart';
import 'runtime_controller.dart';
import 'theme_tokens.dart';

const _desktopSplitMinimumWidth = 760.0;
const _compactThreadPanelHeight = 320.0;
const _compactConversationMinimumHeight = 420.0;

class CodexNativeApp extends StatefulWidget {
  const CodexNativeApp({
    super.key,
    this.runtimeController,
    this.shutdownHandler,
    this.remotePairingScannerLauncher,
  });

  final RuntimeController? runtimeController;
  final Future<void> Function()? shutdownHandler;
  final RemotePairingScannerLauncher? remotePairingScannerLauncher;

  @override
  State<CodexNativeApp> createState() => _CodexNativeAppState();
}

class _CodexNativeAppState extends State<CodexNativeApp> {
  late final RuntimeController _controller;
  late final ThreadListController _threadController;
  late final ExecutionSettingsController _settingsController;
  late final ConversationController _conversationController;
  late final HistoryController _historyController;
  late final DiffController _diffController;
  late final ApprovalController _approvalController;
  late final bool _ownsController;
  AppLifecycleListener? _lifecycleListener;
  var _requestedInitialThreads = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.runtimeController == null;
    _controller = widget.runtimeController ?? RuntimeController();
    _threadController = ThreadListController(gateway: _controller);
    _settingsController = ExecutionSettingsController(gateway: _controller);
    _conversationController = ConversationController(
      gateway: _controller,
      settings: _settingsController,
    );
    _historyController = HistoryController(gateway: _controller);
    _diffController = DiffController(gateway: _controller);
    _approvalController = ApprovalController(gateway: _controller);
    _controller.addListener(_handleRuntimeState);
    _threadController.addListener(_handleThreadSelection);
    _lifecycleListener = AppLifecycleListener(
      onHide: () => unawaited(_controller.handleAppHidden()),
      onShow: () => unawaited(_controller.handleAppShown()),
      onDetach: () =>
          unawaited(widget.shutdownHandler?.call() ?? _controller.shutdown()),
    );
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _controller.removeListener(_handleRuntimeState);
    _threadController.removeListener(_handleThreadSelection);
    _approvalController.dispose();
    _conversationController.dispose();
    _historyController.dispose();
    _diffController.dispose();
    _settingsController.dispose();
    _threadController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Codex Native (Unofficial)',
      theme: ThemeTokens.darkTheme,
      home: RuntimeStatusScreen(
        controller: _controller,
        threadController: _threadController,
        conversationController: _conversationController,
        historyController: _historyController,
        approvalController: _approvalController,
        settingsController: _settingsController,
        diffController: _diffController,
        defaultWorkingDirectory: Directory.current.path,
        remotePairingScannerLauncher:
            widget.remotePairingScannerLauncher ??
            (Platform.isAndroid ? showRemotePairingScanner : null),
      ),
    );
  }

  void _handleRuntimeState() {
    if (_controller.snapshot.state != RuntimeConnectionState.connected ||
        _requestedInitialThreads) {
      return;
    }
    _requestedInitialThreads = true;
    unawaited(_threadController.refresh());
    unawaited(_settingsController.refreshModels());
  }

  void _handleThreadSelection() {
    _conversationController.bindThread(_threadController.selectedThread);
    _diffController.bindThread(_threadController.selectedThread);
    unawaited(_historyController.bindThread(_threadController.selectedThread));
  }
}

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

class _RemotePairingPanel extends StatefulWidget {
  const _RemotePairingPanel({
    required this.controller,
    required this.scannerLauncher,
  });

  final RuntimeController controller;
  final RemotePairingScannerLauncher? scannerLauncher;

  @override
  State<_RemotePairingPanel> createState() => _RemotePairingPanelState();
}

class _RemotePairingPanelState extends State<_RemotePairingPanel> {
  final TextEditingController _invitationController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController(
    text: 'Android device',
  );
  String? _scanMessage;

  @override
  void dispose() {
    _invitationController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.remoteOnboardingState;
    return DecoratedBox(
      key: const ValueKey('remote-pairing-panel'),
      decoration: BoxDecoration(
        color: ThemeTokens.surface,
        border: Border.all(color: ThemeTokens.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ThemeTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pair this Android device',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ThemeTokens.space2),
            Text(
              'On the trusted desktop Host, create a one-use pairing ticket. '
              'Paste its complete versioned invitation here. It can carry '
              'either system trust or one pairing-bound certificate, and this '
              'app never displays the issued device bearer.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ThemeTokens.space4),
            TextField(
              key: const ValueKey('remote-pairing-invitation-field'),
              controller: _invitationController,
              enabled: !state.isBusy,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: true,
              maxLength: 24 * 1024,
              decoration: const InputDecoration(
                labelText: 'Pairing invitation',
                hintText: 'codex-native-pairing-v1.…',
                helperText: 'Includes endpoint, one-use ticket, expiry, and trust mode.',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.scannerLauncher case final scannerLauncher?) ...[
              const SizedBox(height: ThemeTokens.space2),
              OutlinedButton.icon(
                key: const ValueKey('remote-pairing-scan-button'),
                onPressed: state.isBusy
                    ? null
                    : () => unawaited(_scanInvitation(scannerLauncher)),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR'),
              ),
            ],
            if (_scanMessage case final scanMessage?) ...[
              const SizedBox(height: ThemeTokens.space2),
              Text(
                scanMessage,
                key: const ValueKey('remote-pairing-scan-message'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: ThemeTokens.space3),
            TextField(
              key: const ValueKey('remote-device-name-field'),
              controller: _deviceNameController,
              enabled: !state.isBusy,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Device name',
                border: OutlineInputBorder(),
              ),
            ),
            if (_remoteOnboardingMessage(state) case final message?) ...[
              const SizedBox(height: ThemeTokens.space2),
              Text(
                message,
                key: const ValueKey('remote-onboarding-message'),
                style: TextStyle(
                  color: state.phase == RemoteOnboardingPhase.failed
                      ? ThemeTokens.error
                      : null,
                ),
              ),
            ],
            const SizedBox(height: ThemeTokens.space4),
            FilledButton.icon(
              key: const ValueKey('remote-pair-button'),
              onPressed: state.isBusy || !widget.controller.hasRemoteOnboarding
                  ? null
                  : () => unawaited(
                      widget.controller.pairRemote(
                        invitation: _invitationController.text,
                        deviceName: _deviceNameController.text,
                      ),
                    ),
              icon: state.isBusy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: const Text('Pair and connect'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanInvitation(
    RemotePairingScannerLauncher scannerLauncher,
  ) async {
    final scanned = await scannerLauncher(context);
    if (!mounted || scanned == null) {
      return;
    }
    _invitationController
      ..text = scanned
      ..selection = TextSelection.collapsed(offset: scanned.length);
    setState(() {
      _scanMessage = 'QR invitation loaded. Review the device name, then tap Pair and connect.';
    });
  }
}

class _RemoteRecoveryPanel extends StatelessWidget {
  const _RemoteRecoveryPanel({required this.controller});

  final RuntimeController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.remoteOnboardingState;
    final revoked =
        controller.snapshot.state == RuntimeConnectionState.remoteRevoked;
    return DecoratedBox(
      key: const ValueKey('remote-recovery-panel'),
      decoration: BoxDecoration(
        color: ThemeTokens.surface,
        border: Border.all(color: ThemeTokens.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.space4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              revoked ? Icons.link_off : Icons.lock_reset,
              size: 40,
              color: ThemeTokens.error,
            ),
            const SizedBox(height: ThemeTokens.space3),
            Text(
              revoked
                  ? 'Remote credential rejected'
                  : 'Remote profile needs recovery',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ThemeTokens.space2),
            Text(
              revoked
                  ? 'The Host rejected or revoked this device. Clear the saved '
                        'profile, then create a fresh one-use ticket to pair again.'
                  : 'The saved secure profile could not be read or validated. '
                        'It was preserved instead of being silently overwritten.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_remoteOnboardingMessage(state) case final message?) ...[
              const SizedBox(height: ThemeTokens.space3),
              Text(
                message,
                key: const ValueKey('remote-onboarding-message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: state.phase == RemoteOnboardingPhase.failed
                      ? ThemeTokens.error
                      : null,
                ),
              ),
            ],
            const SizedBox(height: ThemeTokens.space4),
            OutlinedButton.icon(
              key: const ValueKey('remote-clear-profile-button'),
              onPressed: state.isBusy || !controller.hasRemoteOnboarding
                  ? null
                  : () => unawaited(_confirmClear(context)),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear saved Remote profile'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear saved Remote profile?'),
        content: const Text(
          'This removes the device credential and resume cursor from this '
          'Android device. It does not revoke the Host-side device entry. '
          'You will need a fresh one-use ticket to pair again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('remote-confirm-clear-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear profile'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clearRemoteProfile();
    }
  }
}

String? _remoteOnboardingMessage(
  RemoteOnboardingState state,
) => switch (state.phase) {
  RemoteOnboardingPhase.idle => null,
  RemoteOnboardingPhase.pairing =>
    'Exchanging the one-use ticket with the Host…',
  RemoteOnboardingPhase.saving =>
    'Host accepted the ticket. Verifying secure device storage…',
  RemoteOnboardingPhase.activating =>
    'Secure profile verified. Connecting to the Host…',
  RemoteOnboardingPhase.clearing => 'Clearing the saved Remote profile…',
  RemoteOnboardingPhase.failed => switch (state.failure) {
    RemoteOnboardingFailure.invalidInput =>
      'Paste a complete, current codex-native-pairing-v1 invitation and enter '
          'a device name of 1–80 characters.',
    RemoteOnboardingFailure.timeout =>
      'The bounded pairing request timed out. Check Host reachability and '
          'create a fresh ticket if the previous one may have been used.',
    RemoteOnboardingFailure.tlsRejected =>
      'Android rejected the Host certificate under the invitation trust mode. '
          'No certificate bypass was attempted.',
    RemoteOnboardingFailure.networkUnavailable =>
      'The Host could not be reached securely.',
    RemoteOnboardingFailure.ticketRejected =>
      'The pairing ticket is invalid, expired, or already used.',
    RemoteOnboardingFailure.deviceLimitReached =>
      'The Host paired-device limit has been reached. Revoke an old device '
          'from the trusted local Host surface, then use a fresh ticket.',
    RemoteOnboardingFailure.rateLimited =>
      'The Host pairing attempt limit was reached. Wait before retrying.',
    RemoteOnboardingFailure.incompatibleHost =>
      'The endpoint is not a compatible Codex Native Host pairing service.',
    RemoteOnboardingFailure.malformedResponse =>
      'The Host returned an invalid or oversized pairing response.',
    RemoteOnboardingFailure.hostFailed =>
      'The Host could not complete pairing. Create a fresh local ticket.',
    RemoteOnboardingFailure.secureStorageFailed =>
      'The Host accepted this ticket, but Android could not verify the '
          'secure save. Create a fresh ticket; the Host-side device entry '
          'may need local revocation.',
    RemoteOnboardingFailure.activationFailed =>
      'The profile was saved, but Remote startup failed. Reopen the app to '
          'retry without entering the bearer.',
    RemoteOnboardingFailure.clearFailed =>
      'The saved profile could not be cleared. Nothing was overwritten.',
    RemoteOnboardingFailure.invalidState ||
    null => 'Remote profile state changed before this operation could run.',
  },
};

class _RemoteReadOnlyPanel extends StatelessWidget {
  const _RemoteReadOnlyPanel({required this.controller});

  final RuntimeController controller;

  @override
  Widget build(BuildContext context) {
    final models = controller.remoteModels;
    final threads = controller.remoteThreads;
    final defaultModel = models.where((model) => model.isDefault).firstOrNull;
    return DecoratedBox(
      key: const ValueKey('remote-read-only-panel'),
      decoration: BoxDecoration(
        color: ThemeTokens.surface,
        border: Border.all(color: ThemeTokens.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android, size: 20),
                const SizedBox(width: ThemeTokens.space2),
                Expanded(
                  child: Text(
                    'Remote threads',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Chip(label: Text('Read-only')),
              ],
            ),
            const SizedBox(height: ThemeTokens.space2),
            Text(
              '${threads.length} bounded thread summaries · '
              '${models.length} models'
              '${defaultModel == null ? '' : ' · default ${defaultModel.displayName}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ThemeTokens.space3),
            const Divider(height: 1),
            if (threads.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'The Host returned no thread metadata.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: threads.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    return ListTile(
                      key: ValueKey('remote-thread-${thread.id}'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: ThemeTokens.space2,
                      ),
                      title: Text(
                        thread.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${thread.cwd}  ·  ${thread.status.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            if (controller.remoteHasMoreThreads) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: ThemeTokens.space3),
                child: Text(
                  'More Host threads exist. Remote paging is not exposed in '
                  'this read-only integration yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationPanel extends StatefulWidget {
  const _ConversationPanel({
    required this.controller,
    required this.historyController,
    required this.approvalController,
    required this.settingsController,
    required this.diffController,
    required this.outputGateway,
  });

  final ConversationController controller;
  final HistoryController historyController;
  final ApprovalController approvalController;
  final ExecutionSettingsController settingsController;
  final DiffController diffController;
  final OutputGateway outputGateway;

  @override
  State<_ConversationPanel> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<_ConversationPanel> {
  late final TextEditingController _composerController;
  late final ScrollController _scrollController;
  var _showChanges = false;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _scrollController = ScrollController();
    widget.controller.addListener(_handleConversationChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleConversationChanged);
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ThemeTokens.surface,
        border: Border.all(color: ThemeTokens.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.controller,
          widget.diffController,
          widget.historyController,
        ]),
        builder: (context, _) {
          final controller = widget.controller;
          final thread = controller.thread;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ThemeTokens.space4,
                  ThemeTokens.space3,
                  ThemeTokens.space3,
                  ThemeTokens.space3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread?.displayTitle ?? 'Conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _ExecutionSettingsButton(
                      controller: widget.settingsController,
                    ),
                    if (widget.diffController.snapshot?.files.isNotEmpty ??
                        false)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showChanges = !_showChanges),
                        icon: Icon(
                          _showChanges ? Icons.chat_outlined : Icons.difference,
                          size: 18,
                        ),
                        label: Text(
                          _showChanges
                              ? 'Conversation'
                              : 'Changes ${widget.diffController.snapshot!.files.length}',
                        ),
                      ),
                    if (controller.canInterrupt)
                      TextButton.icon(
                        onPressed: controller.interrupt,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        label: const Text('Stop'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _ApprovalBanner(controller: widget.approvalController),
              Expanded(
                child: _showChanges && widget.diffController.snapshot != null
                    ? _DiffView(controller: widget.diffController)
                    : _timeline(controller),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(ThemeTokens.space3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composerController,
                        enabled: thread != null && !controller.busy,
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: thread == null
                              ? 'Select or create a thread'
                              : 'Send a message to Codex',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: ThemeTokens.space2),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: thread == null || controller.busy
                          ? null
                          : _send,
                      icon: const Icon(Icons.arrow_upward, size: 19),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _timeline(ConversationController controller) {
    if (controller.thread == null) {
      return Center(
        child: Text(
          'Select a thread to begin.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final liveIds = controller.entries.map((entry) => entry.id).toSet();
    final historyItems = widget.historyController.timelineItems
        .where((item) => !liveIds.contains(item.id))
        .toList(growable: false);
    if (controller.entries.isEmpty && historyItems.isEmpty) {
      if (widget.historyController.loadingTurns) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Text(
          widget.historyController.errorMessage ?? 'No conversation history.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final footerCount =
        widget.historyController.canLoadOlderTurns ||
            widget.historyController.canReturnToNewest ||
            widget.historyController.canLoadMoreItems ||
            widget.historyController.loadingTurns ||
            widget.historyController.loadingItems
        ? 1
        : 0;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(ThemeTokens.space4),
      itemCount: historyItems.length + controller.entries.length + footerCount,
      itemBuilder: (context, index) {
        if (index < historyItems.length) {
          final item = historyItems[index];
          return _HistoryEntryView(
            key: ValueKey('history-${item.id}'),
            item: item,
            historyController: widget.historyController,
            outputGateway: widget.outputGateway,
          );
        }
        final liveIndex = index - historyItems.length;
        if (liveIndex < controller.entries.length) {
          return _ConversationEntryView(
            key: ValueKey(controller.entries[liveIndex].id),
            entry: controller.entries[liveIndex],
          );
        }
        return _HistoryFooter(controller: widget.historyController);
      },
    );
  }

  Future<void> _send() async {
    final text = _composerController.text;
    if (await widget.controller.submit(text)) {
      _composerController.clear();
    }
  }

  void _handleConversationChanged() {
    if (!_scrollController.hasClients) {
      return;
    }
    final distanceFromEnd =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    if (distanceFromEnd > 160) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      );
    });
  }
}

class _ExecutionSettingsButton extends StatelessWidget {
  const _ExecutionSettingsButton({required this.controller});

  final ExecutionSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.selectedModelId == null
            ? 'Defaults'
            : controller.effectiveModel?.displayName ?? 'Model';
        return TextButton.icon(
          onPressed: controller.loading
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      _ExecutionSettingsDialog(controller: controller),
                ),
          icon: controller.loading
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.tune, size: 18),
          label: Text(selected),
        );
      },
    );
  }
}

class _ExecutionSettingsDialog extends StatelessWidget {
  const _ExecutionSettingsDialog({required this.controller});

  static const _inherit = '';

  final ExecutionSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => AlertDialog(
        title: const Text('Execution settings'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Overrides apply only when explicitly selected. Defaults '
                  'continue to come from Codex configuration.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: ThemeTokens.space4),
                _dropdown(
                  label: 'Model',
                  value: controller.selectedModelId ?? _inherit,
                  items: [
                    const DropdownMenuItem(
                      value: _inherit,
                      child: Text('Codex default'),
                    ),
                    for (final model in controller.models)
                      DropdownMenuItem(
                        value: model.id,
                        child: Text(model.displayName),
                      ),
                  ],
                  onChanged: (value) =>
                      controller.selectModel(value == _inherit ? null : value),
                ),
                const SizedBox(height: ThemeTokens.space3),
                _dropdown(
                  label: 'Reasoning effort',
                  value: controller.selectedReasoningEffort ?? _inherit,
                  items: [
                    const DropdownMenuItem(
                      value: _inherit,
                      child: Text('Model default'),
                    ),
                    for (final effort in controller.availableReasoningEfforts)
                      DropdownMenuItem(
                        value: effort.value,
                        child: Text(effort.value),
                      ),
                  ],
                  onChanged: (value) => controller.selectReasoningEffort(
                    value == _inherit ? null : value,
                  ),
                ),
                const SizedBox(height: ThemeTokens.space3),
                _dropdown(
                  label: 'Approval mode',
                  value: _approvalValue(controller.approvalPolicy),
                  items: const [
                    DropdownMenuItem(
                      value: _inherit,
                      child: Text('Codex default'),
                    ),
                    DropdownMenuItem(
                      value: 'untrusted',
                      child: Text('Ask for untrusted commands'),
                    ),
                    DropdownMenuItem(
                      value: 'on-request',
                      child: Text('Ask when Codex requests'),
                    ),
                    DropdownMenuItem(value: 'never', child: Text('Never ask')),
                  ],
                  onChanged: (value) => _setApproval(context, value),
                ),
                const SizedBox(height: ThemeTokens.space3),
                _dropdown(
                  label: 'Sandbox',
                  value: _sandboxValue(controller.sandbox),
                  items: const [
                    DropdownMenuItem(
                      value: _inherit,
                      child: Text('Codex default'),
                    ),
                    DropdownMenuItem(
                      value: 'read-only',
                      child: Text('Read only'),
                    ),
                    DropdownMenuItem(
                      value: 'workspace-write',
                      child: Text('Workspace write'),
                    ),
                    DropdownMenuItem(
                      value: 'danger-full-access',
                      child: Text('Danger: full access'),
                    ),
                  ],
                  onChanged: (value) => _setSandbox(context, value),
                ),
                if (controller.errorMessage case final error?) ...[
                  const SizedBox(height: ThemeTokens.space3),
                  SelectableText(
                    error,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: ThemeTokens.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: controller.refreshModels,
            child: const Text('Refresh models'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  static Widget _dropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String> onChanged,
  }) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: ValueKey('execution-$label'),
        value: value,
        isDense: true,
        isExpanded: true,
        items: items,
        onChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
      ),
    ),
  );

  Future<void> _setApproval(BuildContext context, String value) async {
    final policy = switch (value) {
      'untrusted' => ApprovalPolicyOverride.untrusted,
      'on-request' => ApprovalPolicyOverride.onRequest,
      'never' => ApprovalPolicyOverride.never,
      _ => null,
    };
    if (policy == ApprovalPolicyOverride.never &&
        !await _confirm(
          context,
          title: 'Disable approval prompts?',
          message:
              'Codex may execute commands without asking. The configured '
              'sandbox still applies, but this removes an important review gate.',
          confirmLabel: 'Never ask',
        )) {
      return;
    }
    controller.selectApprovalPolicy(policy);
  }

  Future<void> _setSandbox(BuildContext context, String value) async {
    final sandbox = switch (value) {
      'read-only' => SandboxModeOverride.readOnly,
      'workspace-write' => SandboxModeOverride.workspaceWrite,
      'danger-full-access' => SandboxModeOverride.dangerFullAccess,
      _ => null,
    };
    if (sandbox == SandboxModeOverride.dangerFullAccess &&
        !await _confirm(
          context,
          title: 'Allow full filesystem access?',
          message:
              'Commands will not be restricted by the Codex sandbox. Use this '
              'only for a workspace you trust.',
          confirmLabel: 'Allow full access',
        )) {
      return;
    }
    controller.selectSandbox(sandbox);
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  static String _approvalValue(ApprovalPolicyOverride? policy) =>
      switch (policy) {
        ApprovalPolicyOverride.untrusted => 'untrusted',
        ApprovalPolicyOverride.onRequest => 'on-request',
        ApprovalPolicyOverride.never => 'never',
        null => _inherit,
      };

  static String _sandboxValue(SandboxModeOverride? sandbox) =>
      switch (sandbox) {
        SandboxModeOverride.readOnly => 'read-only',
        SandboxModeOverride.workspaceWrite => 'workspace-write',
        SandboxModeOverride.dangerFullAccess => 'danger-full-access',
        null => _inherit,
      };
}

class _DiffView extends StatelessWidget {
  const _DiffView({required this.controller});

  final DiffController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final selected = controller.selectedFile;
    if (snapshot == null || snapshot.files.isEmpty || selected == null) {
      return Center(
        child: Text(
          'No file changes for this turn.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(ThemeTokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const ValueKey('diff-file-picker'),
                  value: selected.path,
                  isExpanded: true,
                  items: [
                    for (final file in snapshot.files)
                      DropdownMenuItem(
                        value: file.path,
                        child: Text(
                          '${file.path}  +${file.additions} -${file.deletions}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (path) {
                    if (path != null) {
                      controller.selectFile(path);
                    }
                  },
                ),
              ),
              Text(
                '${snapshot.files.length} file(s)  '
                '+${snapshot.additions}  -${snapshot.deletions}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (snapshot.truncated || selected.truncated) ...[
                const SizedBox(height: ThemeTokens.space2),
                Text(
                  'Large diff truncated to the bounded presentation limit.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ThemeTokens.pending),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _DiffLines(file: selected)),
      ],
    );
  }
}

class _DiffLines extends StatelessWidget {
  const _DiffLines({required this.file});

  final DiffFile file;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: ListView.builder(
        itemExtent: 21,
        itemCount: file.lines.length,
        itemBuilder: (context, index) {
          final line = file.lines[index];
          final background = line.startsWith('+') && !line.startsWith('+++')
              ? ThemeTokens.connected.withValues(alpha: 0.1)
              : line.startsWith('-') && !line.startsWith('---')
              ? ThemeTokens.error.withValues(alpha: 0.1)
              : Colors.transparent;
          return ColoredBox(
            color: background,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ThemeTokens.space3,
              ),
              child: Text(
                line,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace', height: 1.5),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner({required this.controller});

  final ApprovalController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final error = controller.errorMessage;
        final request = controller.pending.firstOrNull;
        if (request == null && error == null) {
          return const SizedBox.shrink();
        }
        if (request == null) {
          return Container(
            padding: const EdgeInsets.all(ThemeTokens.space3),
            color: ThemeTokens.error.withValues(alpha: 0.12),
            child: SelectableText(
              error!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: ThemeTokens.error),
            ),
          );
        }

        final deciding = controller.isDeciding(request.requestId);
        return Container(
          padding: const EdgeInsets.all(ThemeTokens.space3),
          color: ThemeTokens.pending.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Approval required'
                      '${controller.pending.length > 1 ? ' (${controller.pending.length})' : ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (deciding)
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: ThemeTokens.space2),
              SelectableText(request.summary),
              if (request.detail case final detail?) ...[
                const SizedBox(height: ThemeTokens.space1),
                SelectableText(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (request.reason case final reason?) ...[
                const SizedBox(height: ThemeTokens.space1),
                SelectableText(
                  'Reason: $reason',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: ThemeTokens.space2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: deciding
                        ? null
                        : () => controller.reject(request.requestId),
                    child: const Text('Reject'),
                  ),
                  if (request.approveSupported) ...[
                    const SizedBox(width: ThemeTokens.space2),
                    FilledButton(
                      onPressed: deciding
                          ? null
                          : () => controller.approve(request.requestId),
                      child: const Text('Approve once'),
                    ),
                  ],
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: ThemeTokens.space2),
                SelectableText(
                  error,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ThemeTokens.error),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HistoryEntryView extends StatelessWidget {
  const _HistoryEntryView({
    super.key,
    required this.item,
    required this.historyController,
    required this.outputGateway,
  });

  final HistoryItem item;
  final HistoryController historyController;
  final OutputGateway outputGateway;

  @override
  Widget build(BuildContext context) {
    final kind = switch (item.kind) {
      HistoryItemKind.user => ConversationEntryKind.user,
      HistoryItemKind.assistant => ConversationEntryKind.assistant,
      HistoryItemKind.activity ||
      HistoryItemKind.reasoning ||
      HistoryItemKind.unknown => ConversationEntryKind.activity,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ConversationEntryView(
          entry: ConversationEntry(
            id: item.id,
            kind: kind,
            text: item.text,
            completed: true,
            status: item.status,
          ),
        ),
        if (item.isCommand) _commandOutputAction(context),
      ],
    );
  }

  Widget _commandOutputAction(BuildContext context) {
    final output = item.output;
    if (output != null && output.available && output.reference != null) {
      return Padding(
        padding: const EdgeInsets.only(
          left: ThemeTokens.space2,
          bottom: ThemeTokens.space3,
        ),
        child: TextButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) =>
                _OutputDialog(gateway: outputGateway, descriptor: output),
          ),
          icon: const Icon(Icons.terminal, size: 16),
          label: Text(
            output.truncated ? 'View stored output (truncated)' : 'View output',
          ),
        ),
      );
    }
    if (output != null && !output.available) {
      return const Padding(
        padding: EdgeInsets.only(
          left: ThemeTokens.space2,
          bottom: ThemeTokens.space3,
        ),
        child: Text('Output unavailable'),
      );
    }
    if (item.outputDeferred) {
      return Padding(
        padding: const EdgeInsets.only(
          left: ThemeTokens.space2,
          bottom: ThemeTokens.space3,
        ),
        child: TextButton(
          onPressed: historyController.loadingItems
              ? null
              : () => historyController.loadDeferredOutput(item),
          child: const Text('Fetch output safely'),
        ),
      );
    }
    if (historyController.selectedTurnId != item.turnId) {
      return Padding(
        padding: const EdgeInsets.only(
          left: ThemeTokens.space2,
          bottom: ThemeTokens.space3,
        ),
        child: TextButton(
          onPressed: historyController.loadingItems
              ? null
              : () => historyController.loadTurnItems(item.turnId),
          child: const Text('Load turn details'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _OutputDialog extends StatefulWidget {
  const _OutputDialog({required this.gateway, required this.descriptor});

  final OutputGateway gateway;
  final OutputDescriptor descriptor;

  @override
  State<_OutputDialog> createState() => _OutputDialogState();
}

class _OutputDialogState extends State<_OutputDialog> {
  late final OutputViewerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OutputViewerController(
      gateway: widget.gateway,
      descriptor: widget.descriptor,
    );
    unawaited(_controller.loadInitial());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 820,
        height: 620,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final chunk = _controller.chunk;
            final rows = _outputRows(_controller.text);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(ThemeTokens.space3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Command output',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              chunk == null
                                  ? '${widget.descriptor.storedBytes} stored byte(s)'
                                  : 'Window at byte ${chunk.offset} of '
                                        '${widget.descriptor.storedBytes}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                if (widget.descriptor.truncated)
                  Container(
                    padding: const EdgeInsets.all(ThemeTokens.space2),
                    color: ThemeTokens.pending.withValues(alpha: 0.12),
                    child: Text(
                      'Only ${widget.descriptor.storedBytes} of '
                      '${widget.descriptor.bytes} bytes were retained by the '
                      'configured Host limit.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (_controller.errorMessage case final error?)
                  Padding(
                    padding: const EdgeInsets.all(ThemeTokens.space2),
                    child: SelectableText(
                      error,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ThemeTokens.error),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: _controller.loading && chunk == null
                      ? const Center(child: CircularProgressIndicator())
                      : SelectionArea(
                          child: ListView.builder(
                            itemExtent: 20,
                            itemCount: rows.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: ThemeTokens.space3,
                              ),
                              child: Text(
                                rows[index],
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(ThemeTokens.space2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _controller.loading
                            ? null
                            : _controller.loadStart,
                        child: const Text('First'),
                      ),
                      TextButton(
                        onPressed: _controller.canLoadPrevious
                            ? _controller.loadPrevious
                            : null,
                        child: const Text('Previous'),
                      ),
                      TextButton(
                        onPressed: _controller.canLoadNext
                            ? _controller.loadNext
                            : null,
                        child: const Text('Next'),
                      ),
                      TextButton(
                        onPressed: _controller.loading
                            ? null
                            : _controller.loadTail,
                        child: const Text('Tail'),
                      ),
                    ],
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

List<String> _outputRows(String text) {
  const maxCharactersPerRow = 4096;
  final rows = <String>[];
  for (final line in text.split('\n')) {
    if (line.isEmpty) {
      rows.add('');
      continue;
    }
    var offset = 0;
    while (offset < line.length) {
      var end = (offset + maxCharactersPerRow).clamp(0, line.length);
      if (end < line.length &&
          _isHighSurrogate(line.codeUnitAt(end - 1)) &&
          _isLowSurrogate(line.codeUnitAt(end))) {
        end -= 1;
      }
      rows.add(line.substring(offset, end));
      offset = end;
    }
  }
  return rows;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xd800 && codeUnit <= 0xdbff;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xdc00 && codeUnit <= 0xdfff;

class _HistoryFooter extends StatelessWidget {
  const _HistoryFooter({required this.controller});

  final HistoryController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loadingTurns || controller.loadingItems) {
      return const Padding(
        padding: EdgeInsets.all(ThemeTokens.space3),
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: ThemeTokens.space2,
      children: [
        if (controller.canLoadOlderTurns)
          TextButton(
            onPressed: controller.loadOlderTurns,
            child: const Text('Load older turns'),
          ),
        if (controller.canReturnToNewest)
          TextButton(
            onPressed: controller.refresh,
            child: const Text('Return to newest'),
          ),
        if (controller.canLoadMoreItems)
          TextButton(
            onPressed: controller.loadMoreItems,
            child: const Text('Load more items'),
          ),
      ],
    );
  }
}

class _ConversationEntryView extends StatelessWidget {
  const _ConversationEntryView({super.key, required this.entry});

  final ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.kind == ConversationEntryKind.user;
    final isActivity = entry.kind == ConversationEntryKind.activity;
    final isError = entry.kind == ConversationEntryKind.error;
    final color = isError
        ? ThemeTokens.error.withValues(alpha: 0.12)
        : isUser
        ? ThemeTokens.surfaceRaised
        : isActivity
        ? ThemeTokens.canvas
        : Colors.transparent;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: ThemeTokens.space3),
        padding: EdgeInsets.all(
          isActivity ? ThemeTokens.space2 : ThemeTokens.space3,
        ),
        decoration: BoxDecoration(
          color: color,
          border: isActivity || isError
              ? Border.all(color: ThemeTokens.border)
              : null,
          borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.status case final status?) ...[
              Text(status, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: ThemeTokens.space1),
            ],
            if (entry.kind == ConversationEntryKind.assistant)
              AssistantMarkdown(data: entry.text, completed: entry.completed)
            else
              SelectableText(
                entry.text,
                style: isActivity
                    ? Theme.of(context).textTheme.bodySmall
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            if (!entry.completed) ...[
              const SizedBox(height: ThemeTokens.space2),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThreadPanel extends StatefulWidget {
  const _ThreadPanel({
    required this.controller,
    required this.settingsController,
    required this.defaultWorkingDirectory,
  });

  final ThreadListController controller;
  final ExecutionSettingsController settingsController;
  final String defaultWorkingDirectory;

  @override
  State<_ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends State<_ThreadPanel> {
  late final TextEditingController _cwdController;

  @override
  void initState() {
    super.initState();
    _cwdController = TextEditingController(
      text: widget.defaultWorkingDirectory,
    );
  }

  @override
  void dispose() {
    _cwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ThemeTokens.surface,
        border: Border.all(color: ThemeTokens.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.space4),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: ThemeTokens.space2,
                  runSpacing: ThemeTokens.space1,
                  children: [
                    Text(
                      'Threads',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      tooltip: 'Refresh threads',
                      onPressed: controller.loading || controller.mutating
                          ? null
                          : controller.refresh,
                      icon: const Icon(Icons.refresh, size: 19),
                    ),
                    const SizedBox(width: ThemeTokens.space2),
                    FilledButton.icon(
                      onPressed: controller.mutating ? null : _startThread,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New thread'),
                    ),
                  ],
                ),
                const SizedBox(height: ThemeTokens.space3),
                TextField(
                  controller: _cwdController,
                  enabled: !controller.mutating,
                  decoration: const InputDecoration(
                    labelText: 'Working directory for new threads',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                if (controller.errorMessage case final error?) ...[
                  const SizedBox(height: ThemeTokens.space3),
                  SelectableText(
                    error,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: ThemeTokens.error),
                  ),
                ],
                const SizedBox(height: ThemeTokens.space3),
                Expanded(child: _threadList(controller)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _threadList(ThreadListController controller) {
    if (controller.loading && controller.threads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.threads.isEmpty) {
      return Center(
        child: Text(
          'No local threads found.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final footerCount =
        controller.canLoadMore || controller.retentionLimitReached ? 1 : 0;
    return ListView.separated(
      itemCount: controller.threads.length + footerCount,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == controller.threads.length) {
          if (controller.retentionLimitReached) {
            return Padding(
              padding: const EdgeInsets.all(ThemeTokens.space3),
              child: Text(
                'Showing the newest ${controller.maxRetainedThreads} threads. '
                'Refresh to return to the newest page.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          return TextButton(
            onPressed: controller.loadingMore ? null : controller.loadMore,
            child: controller.loadingMore
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Load more'),
          );
        }

        final thread = controller.threads[index];
        final selected = controller.selectedThread?.id == thread.id;
        return _ThreadRow(
          key: ValueKey(thread.id),
          thread: thread,
          selected: selected,
          enabled: !controller.mutating,
          onSelect: () => controller.selectThread(thread.id),
          onResume: () => controller.resumeThread(thread.id),
        );
      },
    );
  }

  Future<void> _startThread() async {
    final cwd = _cwdController.text.trim();
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
}

class _ThreadRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final updated = thread.updatedAt.toLocal().toIso8601String();
    return Material(
      color: selected ? ThemeTokens.surfaceRaised : Colors.transparent,
      child: InkWell(
        onTap: enabled ? onSelect : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ThemeTokens.space3,
            vertical: ThemeTokens.space2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: ThemeTokens.space1),
                    Text(
                      '${thread.cwd}  ·  ${updated.substring(0, 16)}  ·  '
                      '${thread.status.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ThemeTokens.space2),
              TextButton(
                onPressed: enabled ? onResume : null,
                child: const Text('Resume'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteSetupDialog extends StatefulWidget {
  const _RemoteSetupDialog({required this.gateway});

  final RemoteAdminGateway gateway;

  @override
  State<_RemoteSetupDialog> createState() => _RemoteSetupDialogState();
}

class _RemoteSetupDialogState extends State<_RemoteSetupDialog> {
  late final RemoteAdminController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RemoteAdminController(gateway: widget.gateway);
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
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
                    const Icon(Icons.devices_other),
                    const SizedBox(width: ThemeTokens.space2),
                    Expanded(
                      child: Text(
                        'Remote setup',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(ThemeTokens.space6),
                  child: _RemoteSetupContent(controller: _controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteSetupContent extends StatelessWidget {
  const _RemoteSetupContent({required this.controller});

  final RemoteAdminController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    final ticket = controller.ticket;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final activeDevices = controller.devices.where(
      (device) => !device.isRevoked && !device.isExpiredAt(nowMs),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Host listener', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: ThemeTokens.space2),
        if (status == null)
          Text(
            controller.phase == RemoteAdminPhase.loading
                ? 'Reading trusted local Host state…'
                : 'Host listener state is unavailable.',
            key: const ValueKey('remote-setup-status'),
          )
        else
          _RemoteListenerDetails(status: status),
        if (controller.errorMessage case final error?) ...[
          const SizedBox(height: ThemeTokens.space3),
          Text(
            error,
            key: const ValueKey('remote-setup-error'),
            style: const TextStyle(color: ThemeTokens.error),
          ),
        ],
        const SizedBox(height: ThemeTokens.space4),
        Wrap(
          spacing: ThemeTokens.space2,
          runSpacing: ThemeTokens.space2,
          children: [
            FilledButton.icon(
              key: const ValueKey('remote-create-ticket-button'),
              onPressed: controller.canCreatePairingTicket
                  ? () => unawaited(controller.createPairingTicket())
                  : null,
              icon: controller.phase == RemoteAdminPhase.creatingTicket
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_link),
              label: const Text('Create one-use ticket'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('remote-setup-refresh-button'),
              onPressed: controller.isBusy
                  ? null
                  : () => unawaited(controller.refresh()),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        if (ticket != null) ...[
          const SizedBox(height: ThemeTokens.space4),
          _RemoteTicketCard(ticket: ticket),
        ] else if (controller.ticketExpired) ...[
          const SizedBox(height: ThemeTokens.space4),
          Container(
            key: const ValueKey('remote-ticket-expired-message'),
            padding: const EdgeInsets.all(ThemeTokens.space3),
            color: ThemeTokens.pending.withValues(alpha: 0.08),
            child: const Text(
              'The one-use pairing ticket expired and was removed from this '
              'screen. Create a fresh ticket before pairing.',
            ),
          ),
        ],
        const SizedBox(height: ThemeTokens.space6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: ThemeTokens.space2,
          runSpacing: ThemeTokens.space1,
          children: [
            Text(
              'Paired devices',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${activeDevices.length} active · '
              '${controller.devices.length} stored',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: ThemeTokens.space2),
        if (controller.devices.isEmpty)
          Text(
            controller.phase == RemoteAdminPhase.loading
                ? 'Loading paired-device metadata…'
                : 'No paired devices.',
            key: const ValueKey('remote-device-empty'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (final device in controller.devices)
            _RemoteDeviceTile(controller: controller, device: device),
      ],
    );
  }
}

class _RemoteListenerDetails extends StatelessWidget {
  const _RemoteListenerDetails({required this.status});

  final RemoteHostStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.enabled) {
      return Container(
        key: const ValueKey('remote-listener-disabled'),
        padding: const EdgeInsets.all(ThemeTokens.space3),
        color: ThemeTokens.pending.withValues(alpha: 0.08),
        child: const Text(
          'Remote listening is disabled. This screen will not enable it. '
          'Configure CODEX_NATIVE_REMOTE_LISTEN and restart the Host.',
        ),
      );
    }
    final endpoint = status.advertisedEndpoint;
    return Container(
      key: const ValueKey('remote-listener-enabled'),
      padding: const EdgeInsets.all(ThemeTokens.space3),
      decoration: BoxDecoration(
        border: Border.all(color: ThemeTokens.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Detail(label: 'Bind', value: status.bindAddress ?? 'Unavailable'),
          const SizedBox(height: ThemeTokens.space2),
          _Detail(
            label: 'Scope',
            value: switch (status.scope) {
              RemoteListenerScope.loopback => 'Loopback',
              RemoteListenerScope.network => 'Network',
              null => 'Unavailable',
            },
          ),
          const SizedBox(height: ThemeTokens.space2),
          _Detail(
            label: 'Local TLS',
            value: status.tls == true ? 'Enabled' : 'Not enabled',
          ),
          const SizedBox(height: ThemeTokens.space2),
          _Detail(
            label: 'Invitation trust',
            value: switch (status.pairingTrust) {
              RemotePairingTrustMode.system => 'System roots',
              RemotePairingTrustMode.certificate => 'Bound certificate',
              null => 'Unavailable',
            },
          ),
          const SizedBox(height: ThemeTokens.space2),
          if (endpoint == null)
            const Text(
              'No client endpoint is advertised. Set '
              'CODEX_NATIVE_REMOTE_ADVERTISE_ENDPOINT to the exact reachable '
              'wss://…/v1/ws address and restart the Host. A wildcard bind is '
              'never converted into an invitation address.',
              key: ValueKey('remote-advertised-endpoint-missing'),
              style: TextStyle(color: ThemeTokens.pending),
            )
          else ...[
            Text(
              'Advertised client endpoint',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: ThemeTokens.space1),
            SelectableText(
              endpoint,
              key: const ValueKey('remote-advertised-endpoint'),
            ),
            const SizedBox(height: ThemeTokens.space2),
            Text(
              status.pairingTrust == RemotePairingTrustMode.certificate
                  ? 'Invitations carry the explicitly configured local trust '
                        'certificate. Changing that identity requires a Host '
                        'restart and affected devices may need re-pairing.'
                  : 'Invitations use Android runtime system roots. For a local '
                        'private CA or self-signed Host, configure '
                        'CODEX_NATIVE_REMOTE_PAIRING_TRUST_CERT with exactly '
                        'one certificate and restart the Host.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (status.tls == false) ...[
              const SizedBox(height: ThemeTokens.space2),
              Text(
                status.scope == RemoteListenerScope.loopback
                    ? 'The local listener is plaintext loopback; the advertised '
                          'WSS endpoint must terminate TLS in a trusted proxy.'
                    : 'The Host configuration is inconsistent: network scope '
                          'must not be plaintext.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RemoteTicketCard extends StatefulWidget {
  const _RemoteTicketCard({required this.ticket});

  final RemotePairingTicket ticket;

  @override
  State<_RemoteTicketCard> createState() => _RemoteTicketCardState();
}

class _RemoteTicketCardState extends State<_RemoteTicketCard> {
  RemotePairingQr? _qr;

  @override
  void initState() {
    super.initState();
    _qr = RemotePairingQr.tryEncode(widget.ticket.invitation);
  }

  @override
  void didUpdateWidget(covariant _RemoteTicketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticket.invitation != widget.ticket.invitation) {
      _qr = RemotePairingQr.tryEncode(widget.ticket.invitation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    return Container(
      key: const ValueKey('remote-ticket-card'),
      padding: const EdgeInsets.all(ThemeTokens.space4),
      decoration: BoxDecoration(
        color: ThemeTokens.connected.withValues(alpha: 0.08),
        border: Border.all(color: ThemeTokens.connected),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'One-use pairing invitation',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: ThemeTokens.space2),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('remote-copy-invitation-button'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: ticket.invitation));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Invitation copied. The clipboard now contains a '
                        'five-minute one-use secret.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy invitation'),
            ),
          ),
          const SizedBox(height: ThemeTokens.space2),
          _RemotePairingQrView(qr: _qr),
          const SizedBox(height: ThemeTokens.space2),
          SelectableText(
            ticket.invitation,
            key: const ValueKey('remote-ticket-invitation'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: ThemeTokens.space2),
          SelectableText(ticket.endpoint),
          const SizedBox(height: ThemeTokens.space2),
          Text(
            ticket.trust == RemotePairingTrustMode.certificate
                ? 'Trust: pairing-bound certificate'
                : 'Trust: Android runtime system roots',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: ThemeTokens.space2),
          Text(
            'Expires ${_formatUtc(ticket.expiresAtMs)}. It is replaced by any '
            'new ticket and is not persisted by this UI.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RemotePairingQrView extends StatelessWidget {
  const _RemotePairingQrView({required this.qr});

  final RemotePairingQr? qr;

  @override
  Widget build(BuildContext context) {
    final qr = this.qr;
    if (qr == null) {
      return Container(
        key: const ValueKey('remote-ticket-qr-unavailable'),
        padding: const EdgeInsets.all(ThemeTokens.space3),
        color: ThemeTokens.pending.withValues(alpha: 0.08),
        child: const Text(
          'This complete invitation is too large for one medium-correction QR '
          'code. Use Copy invitation instead; no data was split or omitted.',
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < qr.logicalSize) {
          return Container(
            key: const ValueKey('remote-ticket-qr-too-narrow'),
            padding: const EdgeInsets.all(ThemeTokens.space3),
            color: ThemeTokens.pending.withValues(alpha: 0.08),
            child: const Text(
              'The window is too narrow to show this QR code without reducing '
              'its module size. Enlarge the window or use Copy invitation.',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              image: true,
              label: 'One-use pairing invitation QR code',
              child: RepaintBoundary(
                key: const ValueKey('remote-ticket-qr'),
                child: CustomPaint(
                  size: Size.square(qr.logicalSize),
                  painter: _RemotePairingQrPainter(qr),
                ),
              ),
            ),
            const SizedBox(height: ThemeTokens.space2),
            Text(
              'Scan only with the Android device you intend to pair. The QR '
              'contains the same five-minute one-use secret shown below.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _RemotePairingQrPainter extends CustomPainter {
  const _RemotePairingQrPainter(this.qr);

  final RemotePairingQr qr;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = Colors.white
      ..isAntiAlias = false;
    final foreground = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    canvas.drawRect(Offset.zero & size, background);
    final scale = remotePairingQrLogicalPixelsPerModule;
    final quiet = remotePairingQrQuietZoneModules * scale;
    for (var row = 0; row < qr.moduleCount; row += 1) {
      for (var column = 0; column < qr.moduleCount; column += 1) {
        if (!qr.isDark(row, column)) {
          continue;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            quiet + column * scale,
            quiet + row * scale,
            scale,
            scale,
          ),
          foreground,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RemotePairingQrPainter oldDelegate) =>
      !identical(qr, oldDelegate.qr);
}

class _RemoteDeviceTile extends StatelessWidget {
  const _RemoteDeviceTile({required this.controller, required this.device});

  final RemoteAdminController controller;
  final RemotePairedDevice device;

  @override
  Widget build(BuildContext context) {
    final expired = device.isExpiredAt(DateTime.now().millisecondsSinceEpoch);
    final active = !device.isRevoked && !expired;
    final status = device.isRevoked
        ? 'Revoked ${_formatUtc(device.revokedAtMs!)}'
        : expired
        ? 'Expired ${_formatUtc(device.expiresAtMs)}'
        : 'Expires ${_formatUtc(device.expiresAtMs)}';
    return Card(
      key: ObjectKey(device),
      margin: const EdgeInsets.only(top: ThemeTokens.space2),
      child: ListTile(
        title: Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_scopeLabels(device.scopes)}\n$status',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: OutlinedButton(
          onPressed: active && controller.canRevokeDevices
              ? () => unawaited(_confirmRevoke(context))
              : null,
          child: const Text('Revoke'),
        ),
      ),
    );
  }

  Future<void> _confirmRevoke(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke paired device?'),
        content: Text(
          'Revoke “${device.name}”? Its current bearer will stop connecting. '
          'This cannot be undone; pairing it again requires a fresh ticket.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('remote-confirm-revoke-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revoke device'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.revokeDevice(device);
    }
  }
}

String _formatUtc(int milliseconds) => DateTime.fromMillisecondsSinceEpoch(
  milliseconds,
  isUtc: true,
).toIso8601String();

String _scopeLabels(Set<RemoteDeviceScope> scopes) => scopes
    .map(
      (scope) => switch (scope) {
        RemoteDeviceScope.read => 'Read',
        RemoteDeviceScope.write => 'Write',
        RemoteDeviceScope.approvalsRespond => 'Approvals',
        RemoteDeviceScope.deviceRotate => 'Rotate credential',
      },
    )
    .join(' · ');

class _RuntimePanel extends StatelessWidget {
  const _RuntimePanel({required this.controller});

  final RuntimeController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final statusColor = switch (snapshot.state) {
      RuntimeConnectionState.connected ||
      RuntimeConnectionState.remoteReadOnly => ThemeTokens.connected,
      RuntimeConnectionState.error ||
      RuntimeConnectionState.processExited ||
      RuntimeConnectionState.notFound ||
      RuntimeConnectionState.hostNotFound ||
      RuntimeConnectionState.remoteCredentialRecoveryRequired ||
      RuntimeConnectionState.remoteRevoked => ThemeTokens.error,
      _ => ThemeTokens.pending,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ThemeTokens.surface,
        border: Border.all(color: ThemeTokens.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: ThemeTokens.space2,
              runSpacing: ThemeTokens.space2,
              children: [
                Text('Runtime', style: Theme.of(context).textTheme.titleMedium),
                if (snapshot.state == RuntimeConnectionState.connected &&
                    !controller.usesRemote)
                  OutlinedButton.icon(
                    key: const ValueKey('remote-setup-button'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) =>
                          _RemoteSetupDialog(gateway: controller),
                    ),
                    icon: const Icon(Icons.devices_other, size: 18),
                    label: const Text('Remote setup'),
                  ),
              ],
            ),
            const SizedBox(height: ThemeTokens.space3),
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: ThemeTokens.space2),
                Expanded(child: Text(snapshot.stateLabel)),
              ],
            ),
            if (snapshot.executablePath case final path?) ...[
              const SizedBox(height: ThemeTokens.space4),
              _Detail(label: 'Codex', value: path),
            ],
            if (snapshot.userAgent case final userAgent?) ...[
              const SizedBox(height: ThemeTokens.space3),
              _Detail(label: 'App server', value: userAgent),
            ],
            if (snapshot.processId case final processId?) ...[
              const SizedBox(height: ThemeTokens.space3),
              _Detail(label: 'Process', value: processId.toString()),
            ],
            if (snapshot.message case final message?) ...[
              const SizedBox(height: ThemeTokens.space4),
              SelectableText(
                message,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: statusColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: SelectableText(value)),
      ],
    );
  }
}
