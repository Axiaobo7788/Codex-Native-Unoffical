part of '../codex_native_app.dart';

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
