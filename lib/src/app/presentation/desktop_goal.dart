part of '../codex_native_app.dart';

typedef _GoalEditorDraft = ({String sourceObjective, TextEditingValue value});

class _DesktopGoalUsage extends StatefulWidget {
  const _DesktopGoalUsage({required this.goal, this.budgetText});

  final ThreadGoal goal;
  final String? budgetText;

  bool get tracksElapsed =>
      budgetText == null && goal.status == ThreadGoalStatus.active;

  @override
  State<_DesktopGoalUsage> createState() => _DesktopGoalUsageState();
}

class _DesktopGoalUsageState extends State<_DesktopGoalUsage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncClock();
  }

  @override
  void didUpdateWidget(covariant _DesktopGoalUsage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tracksElapsed != oldWidget.tracksElapsed) {
      _syncClock();
    }
  }

  void _syncClock() {
    _tick?.cancel();
    _tick = widget.tracksElapsed
        ? Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}))
        : null;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _elapsedLabel() {
    final goal = widget.goal;
    final sinceUpdate = widget.tracksElapsed && goal.updatedAtSeconds > 0
        ? DateTime.now().millisecondsSinceEpoch ~/ 1000 - goal.updatedAtSeconds
        : 0;
    final elapsed = Duration(
      seconds: math.max(0, goal.timeUsedSeconds + sinceUpdate),
    );
    if (elapsed.inSeconds == 0) return '0s';
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);
    return [
      if (elapsed.inHours > 0) '${elapsed.inHours}h',
      if (minutes > 0) '${minutes}m',
      if (seconds > 0) '${seconds}s',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.space2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 92),
        child: Text(
          widget.budgetText ?? _elapsedLabel(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: theme.textMuted),
        ),
      ),
    );
  }
}

class _DesktopGoalEditor extends StatefulWidget {
  const _DesktopGoalEditor({
    super.key,
    required this.goal,
    required this.saving,
    required this.onClose,
    required this.onSave,
    this.initialDraft,
  });

  final ThreadGoal goal;
  final bool saving;
  final VoidCallback onClose;
  final Future<void> Function(String objective) onSave;
  final _GoalEditorDraft? initialDraft;

  @override
  State<_DesktopGoalEditor> createState() => _DesktopGoalEditorState();
}

class _DesktopGoalEditorState extends State<_DesktopGoalEditor> {
  late String _sourceObjective =
      widget.initialDraft?.sourceObjective ?? widget.goal.objective;
  late final _draft = TextEditingController.fromValue(
    widget.initialDraft?.value ?? TextEditingValue(text: _sourceObjective),
  );
  final _focus = FocusNode();

  _GoalEditorDraft get draft => (
    sourceObjective: _sourceObjective,
    value: _draft.value.copyWith(composing: TextRange.empty),
  );

  @override
  void didUpdateWidget(covariant _DesktopGoalEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final saved = widget.goal.objective;
    if (saved != _sourceObjective &&
        (_draft.text == _sourceObjective || _draft.text.trim() == saved)) {
      _revert();
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _revert() {
    _sourceObjective = widget.goal.objective;
    _draft.text = _sourceObjective;
  }

  Future<void> _save(String objective) async {
    await widget.onSave(objective);
    if (mounted) {
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final objective = _draft.text.trim();
    final changed = objective != widget.goal.objective;
    final stale = _sourceObjective != widget.goal.objective;
    final minutes = math.max(
      0,
      (DateTime.now().millisecondsSinceEpoch ~/ 1000 -
              widget.goal.updatedAtSeconds) ~/
          60,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.workspaceBackground,
        border: BorderDirectional(
          start: BorderSide(
            color: theme.hairlineBorder,
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
            child: SizedBox(
              height: OfficialCodexTheme.headerHeight,
              child: Row(
                children: [
                  const Icon(Icons.track_changes_outlined, size: 16),
                  const SizedBox(width: ThemeTokens.space2),
                  Expanded(
                    child: Text(
                      'Edit goal',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  CodexIconButton(
                    tooltip: 'Close goal editor',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    stale
                        ? 'Goal changed. Revert to the latest objective.'
                        : minutes == 0
                        ? 'Updated just now'
                        : 'Updated $minutes min ago',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: theme.textSecondary),
                  ),
                ),
                CodexIconButton(
                  tooltip: 'Revert goal draft',
                  size: 28,
                  onPressed: !widget.saving && (changed || stale)
                      ? () => setState(_revert)
                      : null,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                ),
                const SizedBox(width: ThemeTokens.space1),
                CodexButton(
                  label: 'Save',
                  size: CodexButtonSize.sm,
                  variant: CodexButtonVariant.primary,
                  loading: widget.saving,
                  onPressed:
                      !widget.saving &&
                          changed &&
                          !stale &&
                          objective.isNotEmpty &&
                          objective.length <= ThreadGoal.maxObjectiveLength
                      ? () => unawaited(_save(objective))
                      : null,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.hairlineBorder),
          Expanded(
            child: TextField(
              key: const ValueKey('desktop-goal-editor-objective'),
              controller: _draft,
              focusNode: _focus,
              onChanged: (_) => setState(() {}),
              autofocus: true,
              readOnly: widget.saving,
              expands: true,
              maxLines: null,
              maxLength: ThreadGoal.maxObjectiveLength,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Goal',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
