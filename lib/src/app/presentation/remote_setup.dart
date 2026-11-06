part of '../codex_native_app.dart';

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
