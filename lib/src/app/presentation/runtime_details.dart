part of '../codex_native_app.dart';

class _RuntimeDetailsDialog extends StatelessWidget {
  const _RuntimeDetailsDialog({required this.controller});

  final RuntimeController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final palette = ThemeTokens.of(context);
    final statusColor = switch (snapshot.state) {
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
    return AlertDialog(
      title: Row(
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
          const Expanded(child: Text('Runtime details')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Detail(label: 'State', value: snapshot.stateLabel),
              if (snapshot.executablePath case final path?) ...[
                const SizedBox(height: ThemeTokens.space3),
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
                _InlineNotice(
                  icon: Icons.info_outline_rounded,
                  color: statusColor,
                  text: message,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        CodexButton(
          variant: CodexButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
          label: 'Close',
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ThemeTokens.space3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: ThemeTokens.space2),
          Expanded(
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
        Expanded(
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
