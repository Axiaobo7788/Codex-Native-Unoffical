part of '../codex_native_app.dart';

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
    final palette = ThemeTokens.of(context);
    return ColoredBox(
      color: palette.canvas,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.controller,
          widget.diffController,
          widget.historyController,
        ]),
        builder: (context, _) {
          final controller = widget.controller;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _conversationHeader(controller),
              Expanded(
                child: _showChanges && widget.diffController.snapshot != null
                    ? _DiffView(controller: widget.diffController)
                    : _timeline(controller),
              ),
              _ApprovalBanner(controller: widget.approvalController),
              _composer(controller),
            ],
          );
        },
      ),
    );
  }

  Widget _conversationHeader(ConversationController controller) {
    final palette = ThemeTokens.of(context);
    final thread = controller.thread;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.space4),
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread?.displayTitle ?? 'Conversation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (thread != null)
                  Text(
                    _projectName(thread.cwd),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          if (widget.diffController.snapshot?.files.isNotEmpty ?? false)
            TextButton.icon(
              key: const ValueKey('changes-view-button'),
              onPressed: () => setState(() => _showChanges = !_showChanges),
              icon: Icon(
                _showChanges
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.difference_outlined,
                size: 17,
              ),
              label: Text(
                _showChanges
                    ? 'Conversation'
                    : 'Changes ${widget.diffController.snapshot!.files.length}',
              ),
            ),
          if (controller.canInterrupt) ...[
            const SizedBox(width: ThemeTokens.space1),
            OutlinedButton.icon(
              onPressed: controller.interrupt,
              icon: const Icon(Icons.stop_rounded, size: 16),
              label: const Text('Stop'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeline(ConversationController controller) {
    if (controller.thread == null) {
      return const _ConversationEmptyState();
    }
    final liveIds = controller.entries.map((entry) => entry.id).toSet();
    final historyItems = widget.historyController.timelineItems
        .where((item) => !liveIds.contains(item.id))
        .toList(growable: false);
    if (controller.entries.isEmpty && historyItems.isEmpty) {
      if (widget.historyController.loadingTurns) {
        return const _ConversationLoadingState();
      }
      if (widget.historyController.errorMessage case final error?) {
        return _ConversationErrorState(
          message: error,
          onRetry: widget.historyController.refresh,
        );
      }
      return _ThreadEmptyState(thread: controller.thread!);
    }

    final footerCount =
        widget.historyController.canLoadOlderTurns ||
            widget.historyController.canReturnToNewest ||
            widget.historyController.canLoadMoreItems ||
            widget.historyController.loadingTurns ||
            widget.historyController.loadingItems
        ? 1
        : 0;
    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        key: const ValueKey('conversation-timeline'),
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
        itemCount:
            historyItems.length + controller.entries.length + footerCount,
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
      ),
    );
  }

  Widget _composer(ConversationController controller) {
    final palette = ThemeTokens.of(context);
    final thread = controller.thread;
    final enabled = thread != null && !controller.busy;
    return Container(
      color: palette.canvas,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: DecoratedBox(
            key: const ValueKey('composer-surface'),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.borderStrong),
              borderRadius: BorderRadius.circular(ThemeTokens.radiusComposer),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.enter): () {
                        if (enabled) {
                          unawaited(_send());
                        }
                      },
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        shift: true,
                      ): _insertComposerNewline,
                    },
                    child: TextField(
                      key: const ValueKey('conversation-composer'),
                      controller: _composerController,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: thread == null
                            ? 'Select or create a thread'
                            : 'Send a message to Codex',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(2, 2, 8, 8),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _ExecutionSettingsButton(
                        controller: widget.settingsController,
                      ),
                      const Spacer(),
                      if (controller.busy)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Working…',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      IconButton.filled(
                        key: const ValueKey('composer-send-button'),
                        tooltip: 'Send (Enter)',
                        style: IconButton.styleFrom(
                          shape: const CircleBorder(),
                          minimumSize: const Size.square(34),
                          maximumSize: const Size.square(34),
                          backgroundColor: palette.textPrimary,
                          foregroundColor: palette.canvas,
                          disabledBackgroundColor: palette.border,
                          disabledForegroundColor: palette.textMuted,
                        ),
                        onPressed: enabled ? _send : null,
                        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _composerController.text;
    if (await widget.controller.submit(text)) {
      _composerController.clear();
    }
  }

  void _insertComposerNewline() {
    final value = _composerController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final text = value.text.replaceRange(selection.start, selection.end, '\n');
    _composerController.value = value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: selection.start + 1),
      composing: TextRange.empty,
    );
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

class _ConversationEntryView extends StatelessWidget {
  const _ConversationEntryView({super.key, required this.entry});

  final ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final isUser = entry.kind == ConversationEntryKind.user;
    final isActivity = entry.kind == ConversationEntryKind.activity;
    final isError = entry.kind == ConversationEntryKind.error;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isUser ? 560 : double.infinity,
            ),
            margin: const EdgeInsets.only(bottom: ThemeTokens.space4),
            padding: isUser
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                : isActivity || isError
                ? const EdgeInsets.symmetric(horizontal: 11, vertical: 9)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isUser
                  ? palette.userBubble
                  : isError
                  ? palette.danger.withValues(alpha: 0.08)
                  : isActivity
                  ? palette.surfaceRaised
                  : Colors.transparent,
              border: isActivity || isError
                  ? Border.all(
                      color: isError
                          ? palette.danger.withValues(alpha: 0.3)
                          : palette.border,
                    )
                  : null,
              borderRadius: BorderRadius.circular(
                isUser ? ThemeTokens.radiusMedium : ThemeTokens.radiusSmall,
              ),
            ),
            child: isActivity
                ? _ActivityContent(entry: entry)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.status case final status?) ...[
                        Text(
                          status,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isUser
                                    ? palette.onUserBubble.withValues(
                                        alpha: 0.72,
                                      )
                                    : null,
                              ),
                        ),
                        const SizedBox(height: ThemeTokens.space1),
                      ],
                      if (entry.kind == ConversationEntryKind.assistant)
                        AssistantMarkdown(
                          data: entry.text,
                          completed: entry.completed,
                        )
                      else
                        SelectableText(
                          entry.text,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isUser
                                    ? palette.onUserBubble
                                    : isError
                                    ? palette.danger
                                    : palette.textPrimary,
                              ),
                        ),
                      if (!entry.completed) ...[
                        const SizedBox(height: ThemeTokens.space2),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ActivityContent extends StatelessWidget {
  const _ActivityContent({required this.entry});

  final ConversationEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            entry.completed
                ? Icons.check_circle_outline_rounded
                : Icons.hourglass_top_rounded,
            size: 16,
            color: entry.completed ? palette.success : palette.accent,
          ),
        ),
        const SizedBox(width: ThemeTokens.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.status case final status?)
                Text(status, style: Theme.of(context).textTheme.labelSmall),
              SelectableText(
                entry.text,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversationEmptyState extends StatelessWidget {
  const _ConversationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.code_rounded,
              size: 28,
              color: ThemeTokens.of(context).textMuted,
            ),
            const SizedBox(height: ThemeTokens.space3),
            Text(
              'Choose a thread',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: ThemeTokens.space2),
            Text(
              'Select existing work from the sidebar or start a new task.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadEmptyState extends StatelessWidget {
  const _ThreadEmptyState({required this.thread});

  final ThreadSummary thread;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThemeTokens.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Let’s build ${_projectName(thread.cwd)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: ThemeTokens.space2),
            Text(
              'Describe the change you want to make. Codex will keep progress, '
              'tools, approvals, and changes in this thread.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationLoadingState extends StatelessWidget {
  const _ConversationLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(ThemeTokens.space6),
          itemCount: 4,
          itemBuilder: (context, index) => Align(
            alignment: index.isEven
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: index.isEven ? 420 : 260,
              height: index.isEven ? 54 : 42,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: ThemeTokens.of(context).surfaceRaised,
                borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationErrorState extends StatelessWidget {
  const _ConversationErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(ThemeTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: palette.danger,
                size: 28,
              ),
              const SizedBox(height: ThemeTokens.space3),
              Text(
                'Conversation unavailable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: ThemeTokens.space2),
              SelectableText(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: ThemeTokens.space4),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
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
                        ?.copyWith(color: ThemeTokens.of(context).danger),
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
