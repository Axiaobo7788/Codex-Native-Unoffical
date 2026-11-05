import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/runtime_snapshot.dart';
import 'runtime_controller.dart';
import 'theme_tokens.dart';

class CodexNativeApp extends StatefulWidget {
  const CodexNativeApp({super.key, this.runtimeController});

  final RuntimeController? runtimeController;

  @override
  State<CodexNativeApp> createState() => _CodexNativeAppState();
}

class _CodexNativeAppState extends State<CodexNativeApp> {
  late final RuntimeController _controller;
  late final bool _ownsController;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.runtimeController == null;
    _controller = widget.runtimeController ?? RuntimeController();
    _lifecycleListener = AppLifecycleListener(
      onDetach: () => unawaited(_controller.shutdown()),
    );
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
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
      home: RuntimeStatusScreen(controller: _controller),
    );
  }
}

class RuntimeStatusScreen extends StatelessWidget {
  const RuntimeStatusScreen({super.key, required this.controller});

  final RuntimeController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(ThemeTokens.space8),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) =>
                    _RuntimePanel(snapshot: controller.snapshot),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuntimePanel extends StatelessWidget {
  const _RuntimePanel({required this.snapshot});

  final RuntimeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (snapshot.state) {
      RuntimeConnectionState.connected => ThemeTokens.connected,
      RuntimeConnectionState.error ||
      RuntimeConnectionState.processExited ||
      RuntimeConnectionState.notFound => ThemeTokens.error,
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
            Text('Runtime', style: Theme.of(context).textTheme.titleMedium),
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
                Text(snapshot.stateLabel),
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
