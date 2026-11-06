part of '../codex_native_app.dart';

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
