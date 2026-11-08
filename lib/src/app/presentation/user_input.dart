part of '../codex_native_app.dart';

class _UserInputBanner extends StatelessWidget {
  const _UserInputBanner({required this.controller});

  final UserInputController controller;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final request = controller.pending.firstOrNull;
        final error = controller.errorMessage;
        if (request == null && error == null) {
          return const SizedBox.shrink();
        }
        if (request == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _InlineNotice(
              icon: Icons.error_outline_rounded,
              color: palette.danger,
              text: error!,
            ),
          );
        }
        return _UserInputCard(
          key: ValueKey('user-input-${request.requestId}'),
          controller: controller,
          request: request,
          pendingCount: controller.pending.length,
          errorMessage: error,
        );
      },
    );
  }
}

class _UserInputCard extends StatefulWidget {
  const _UserInputCard({
    super.key,
    required this.controller,
    required this.request,
    required this.pendingCount,
    required this.errorMessage,
  });

  final UserInputController controller;
  final UserInputRequest request;
  final int pendingCount;
  final String? errorMessage;

  @override
  State<_UserInputCard> createState() => _UserInputCardState();
}

class _UserInputCardState extends State<_UserInputCard> {
  late final Map<String, TextEditingController> _textControllers;
  final Map<String, String?> _selectedOptions = {};
  final Set<String> _otherSelections = {};

  @override
  void initState() {
    super.initState();
    _textControllers = {
      for (final question in widget.request.questions)
        question.id: TextEditingController()..addListener(_handleAnswerChanged),
    };
  }

  void _handleAnswerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller
        ..removeListener(_handleAnswerChanged)
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final submitting = widget.controller.isSubmitting(widget.request.requestId);
    return Center(
      child: Container(
        key: const ValueKey('user-input-card'),
        constraints: const BoxConstraints(
          maxWidth: OfficialCodexTheme.maxContentWidth,
        ),
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        padding: const EdgeInsets.all(ThemeTokens.space3),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.07),
          border: Border.all(color: palette.accent.withValues(alpha: 0.32)),
          borderRadius: BorderRadius.circular(
            OfficialCodexTheme.mainSurfaceRadius,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.question_answer_outlined,
                  size: 18,
                  color: palette.accent,
                ),
                const SizedBox(width: ThemeTokens.space2),
                Expanded(
                  child: Text(
                    'Codex needs your input'
                    '${widget.pendingCount > 1 ? ' (${widget.pendingCount})' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (submitting)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: ThemeTokens.space2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                key: const ValueKey('user-input-question-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var index = 0;
                      index < widget.request.questions.length;
                      index++
                    ) ...[
                      if (index > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: ThemeTokens.space3,
                          ),
                          child: Divider(height: 1, color: palette.border),
                        ),
                      _question(widget.request.questions[index], submitting),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.errorMessage case final error?) ...[
              const SizedBox(height: ThemeTokens.space2),
              SelectableText(
                error,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.danger),
              ),
            ],
            const SizedBox(height: ThemeTokens.space3),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: ThemeTokens.space2,
              runSpacing: ThemeTokens.space2,
              children: [
                CodexButton(
                  key: const ValueKey('user-input-cancel'),
                  variant: CodexButtonVariant.ghost,
                  size: CodexButtonSize.sm,
                  onPressed: submitting
                      ? null
                      : () =>
                            widget.controller.cancel(widget.request.requestId),
                  label: 'Cancel request',
                ),
                CodexButton(
                  key: const ValueKey('user-input-submit'),
                  variant: CodexButtonVariant.primary,
                  size: CodexButtonSize.sm,
                  loading: submitting,
                  onPressed: submitting || !_isComplete ? null : _submit,
                  label: 'Submit answers',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _question(UserInputQuestion question, bool submitting) {
    final palette = ThemeTokens.of(context);
    final textController = _textControllers[question.id]!;
    final usesOther = _otherSelections.contains(question.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question.header,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: ThemeTokens.space1),
        Text(question.question, style: Theme.of(context).textTheme.bodyMedium),
        if (question.options.isNotEmpty) ...[
          const SizedBox(height: ThemeTokens.space2),
          for (final option in question.options) ...[
            _UserInputOptionTile(
              key: ValueKey('user-input-${question.id}-${option.label}'),
              label: option.label,
              description: option.description,
              selected:
                  !usesOther && _selectedOptions[question.id] == option.label,
              enabled: !submitting,
              onPressed: () {
                setState(() {
                  _otherSelections.remove(question.id);
                  _selectedOptions[question.id] = option.label;
                });
              },
            ),
            const SizedBox(height: ThemeTokens.space1),
          ],
          if (question.allowsOther) ...[
            _UserInputOptionTile(
              key: ValueKey('user-input-${question.id}-other'),
              label: 'Other',
              description: 'Enter a different answer.',
              selected: usesOther,
              enabled: !submitting,
              onPressed: () {
                setState(() {
                  _selectedOptions[question.id] = null;
                  _otherSelections.add(question.id);
                });
              },
            ),
            if (usesOther) ...[
              const SizedBox(height: ThemeTokens.space2),
              _answerField(question, textController, submitting),
            ],
          ],
        ] else ...[
          const SizedBox(height: ThemeTokens.space2),
          _answerField(question, textController, submitting),
        ],
      ],
    );
  }

  Widget _answerField(
    UserInputQuestion question,
    TextEditingController controller,
    bool submitting,
  ) => TextField(
    key: ValueKey('user-input-${question.id}-text'),
    controller: controller,
    enabled: !submitting,
    obscureText: question.isSecret,
    maxLength: 4096,
    minLines: 1,
    maxLines: question.isSecret ? 1 : 4,
    decoration: InputDecoration(
      isDense: true,
      counterText: '',
      hintText: question.isSecret ? 'Enter a private answer' : 'Type an answer',
    ),
  );

  bool get _isComplete {
    for (final question in widget.request.questions) {
      if (question.options.isEmpty || _otherSelections.contains(question.id)) {
        if (_textControllers[question.id]!.text.trim().isEmpty) {
          return false;
        }
      } else if (_selectedOptions[question.id] == null) {
        return false;
      }
    }
    return true;
  }

  void _submit() {
    final answers = <String, List<String>>{};
    for (final question in widget.request.questions) {
      final answer =
          question.options.isEmpty || _otherSelections.contains(question.id)
          ? _textControllers[question.id]!.text.trim()
          : _selectedOptions[question.id]!;
      answers[question.id] = [answer];
    }
    unawaited(widget.controller.submit(widget.request.requestId, answers));
  }
}

class _UserInputOptionTile extends StatefulWidget {
  const _UserInputOptionTile({
    super.key,
    required this.label,
    required this.description,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final String description;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_UserInputOptionTile> createState() => _UserInputOptionTileState();
}

class _UserInputOptionTileState extends State<_UserInputOptionTile> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final background = widget.selected
        ? palette.selected
        : _hovered && widget.enabled
        ? palette.hover
        : Colors.transparent;
    final borderColor = _focused
        ? palette.accent
        : widget.selected
        ? palette.borderStrong
        : palette.border;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(OfficialCodexTheme.buttonRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              widget.selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: widget.selected ? palette.accent : palette.textMuted,
            ),
          ),
          const SizedBox(width: ThemeTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (widget.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.description,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: widget.enabled,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onPressed : null,
          child: MouseRegion(
            cursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Opacity(opacity: widget.enabled ? 1 : 0.55, child: content),
          ),
        ),
      ),
    );
  }
}
