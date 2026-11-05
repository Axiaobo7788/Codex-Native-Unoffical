import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/diff_models.dart';
import '../domain/execution_settings.dart';
import '../domain/runtime_snapshot.dart';
import '../domain/thread_models.dart';
import '../features/approvals/approval_controller.dart';
import '../features/conversation/conversation_controller.dart';
import '../features/diff/diff_controller.dart';
import '../features/settings/execution_settings_controller.dart';
import '../features/threads/thread_list_controller.dart';
import 'runtime_controller.dart';
import 'theme_tokens.dart';

class CodexNativeApp extends StatefulWidget {
  const CodexNativeApp({
    super.key,
    this.runtimeController,
    this.shutdownHandler,
  });

  final RuntimeController? runtimeController;
  final Future<void> Function()? shutdownHandler;

  @override
  State<CodexNativeApp> createState() => _CodexNativeAppState();
}

class _CodexNativeAppState extends State<CodexNativeApp> {
  late final RuntimeController _controller;
  late final ThreadListController _threadController;
  late final ExecutionSettingsController _settingsController;
  late final ConversationController _conversationController;
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
    _diffController = DiffController(gateway: _controller);
    _approvalController = ApprovalController(gateway: _controller);
    _controller.addListener(_handleRuntimeState);
    _threadController.addListener(_handleThreadSelection);
    _lifecycleListener = AppLifecycleListener(
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
        approvalController: _approvalController,
        settingsController: _settingsController,
        diffController: _diffController,
        defaultWorkingDirectory: Directory.current.path,
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
  }
}

class RuntimeStatusScreen extends StatelessWidget {
  const RuntimeStatusScreen({
    super.key,
    required this.controller,
    required this.threadController,
    required this.conversationController,
    required this.approvalController,
    required this.settingsController,
    required this.diffController,
    required this.defaultWorkingDirectory,
  });

  final RuntimeController controller;
  final ThreadListController threadController;
  final ConversationController conversationController;
  final ApprovalController approvalController;
  final ExecutionSettingsController settingsController;
  final DiffController diffController;
  final String defaultWorkingDirectory;

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
                    _RuntimePanel(snapshot: controller.snapshot),
                    if (controller.snapshot.state ==
                        RuntimeConnectionState.connected) ...[
                      const SizedBox(height: ThemeTokens.space4),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 360,
                              child: _ThreadPanel(
                                controller: threadController,
                                settingsController: settingsController,
                                defaultWorkingDirectory:
                                    defaultWorkingDirectory,
                              ),
                            ),
                            const SizedBox(width: ThemeTokens.space4),
                            Expanded(
                              child: _ConversationPanel(
                                controller: conversationController,
                                approvalController: approvalController,
                                settingsController: settingsController,
                                diffController: diffController,
                              ),
                            ),
                          ],
                        ),
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

class _ConversationPanel extends StatefulWidget {
  const _ConversationPanel({
    required this.controller,
    required this.approvalController,
    required this.settingsController,
    required this.diffController,
  });

  final ConversationController controller;
  final ApprovalController approvalController;
  final ExecutionSettingsController settingsController;
  final DiffController diffController;

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
        animation: Listenable.merge([widget.controller, widget.diffController]),
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
    if (controller.entries.isEmpty) {
      return Center(
        child: Text(
          'Only new activity is shown in this bootstrap conversation view.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(ThemeTokens.space4),
      itemCount: controller.entries.length,
      itemBuilder: (context, index) => _ConversationEntryView(
        key: ValueKey(controller.entries[index].id),
        entry: controller.entries[index],
      ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Threads',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
