part of '../codex_native_app.dart';

class _UserInputBanner extends StatelessWidget {
  const _UserInputBanner({
    super.key,
    required this.controller,
    required this.desktop,
    this.activeThreadId,
  });

  final UserInputController controller;
  final bool desktop;
  final String? activeThreadId;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final request = controller.pending.firstOrNull;
        final elicitation = controller.pendingElicitations.firstOrNull;
        final error = controller.errorMessage;
        if (request == null && elicitation == null && error == null) {
          return const SizedBox.shrink();
        }
        if (request == null && elicitation == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _InlineNotice(
              icon: Icons.error_outline_rounded,
              color: palette.danger,
              text: error!,
            ),
          );
        }
        if (request == null) {
          return _McpElicitationCard(
            key: ValueKey('mcp-elicitation-${elicitation!.requestId}'),
            controller: controller,
            request: elicitation,
            pendingCount: controller.pendingElicitations.length,
            errorMessage: error,
          );
        }
        return _UserInputCard(
          key: ValueKey('user-input-${request.requestId}'),
          controller: controller,
          request: request,
          pendingCount: controller.pending.length,
          errorMessage: error,
          desktop: desktop,
          autoAdvance: desktop && request.threadId == activeThreadId,
        );
      },
    );
  }
}

class _McpElicitationCard extends StatefulWidget {
  const _McpElicitationCard({
    super.key,
    required this.controller,
    required this.request,
    required this.pendingCount,
    required this.errorMessage,
    this.margin = const EdgeInsets.fromLTRB(16, 4, 16, 6),
    this.maxFieldsHeight = 320,
  });

  final UserInputController controller;
  final McpElicitationRequest request;
  final int pendingCount;
  final String? errorMessage;
  final EdgeInsetsGeometry margin;
  final double maxFieldsHeight;

  @override
  State<_McpElicitationCard> createState() => _McpElicitationCardState();
}

class _McpElicitationCardState extends State<_McpElicitationCard> {
  late final Map<String, TextEditingController> _textControllers;
  final Map<String, bool?> _booleanValues = {};
  final Map<String, String?> _singleValues = {};
  final Map<String, Set<String>> _multiValues = {};
  String? _launchError;

  @override
  void initState() {
    super.initState();
    _textControllers = {};
    for (final field in widget.request.fields) {
      switch (field.kind) {
        case McpElicitationFieldKind.string:
        case McpElicitationFieldKind.number:
        case McpElicitationFieldKind.integer:
          _textControllers[field.id] = TextEditingController(
            text: field.defaultValue?.toString() ?? '',
          )..addListener(_handleChanged);
        case McpElicitationFieldKind.boolean:
          _booleanValues[field.id] = field.defaultValue as bool?;
        case McpElicitationFieldKind.singleSelect:
          _singleValues[field.id] = field.defaultValue as String?;
        case McpElicitationFieldKind.multiSelect:
          final values = field.defaultValue;
          _multiValues[field.id] = values is List<String>
              ? values.toSet()
              : <String>{};
      }
    }
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller
        ..removeListener(_handleChanged)
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final submitting = widget.controller.isSubmitting(widget.request.requestId);
    return Center(
      heightFactor: 1,
      child: Container(
        key: const ValueKey('mcp-elicitation-card'),
        constraints: const BoxConstraints(
          maxWidth: OfficialCodexTheme.maxContentWidth,
        ),
        margin: widget.margin,
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
                Icon(Icons.extension_outlined, size: 18, color: palette.accent),
                const SizedBox(width: ThemeTokens.space2),
                Expanded(
                  child: Text(
                    '${widget.request.serverName} needs input'
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
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxFieldsHeight),
                child: SingleChildScrollView(
                  key: const ValueKey('mcp-elicitation-scroll'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.request.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: ThemeTokens.space2),
                      switch (widget.request.mode) {
                        McpElicitationMode.form => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final field in widget.request.fields)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: ThemeTokens.space3,
                                ),
                                child: _buildField(field, submitting),
                              ),
                          ],
                        ),
                        McpElicitationMode.url => _buildUrlPrompt(submitting),
                        McpElicitationMode.openaiForm => _InlineNotice(
                          icon: Icons.info_outline_rounded,
                          color: palette.textSecondary,
                          text:
                              'This request uses an OpenAI-hosted form renderer that '
                              'is not embedded in this unofficial native client. You '
                              'can safely decline or cancel it.',
                        ),
                      },
                    ],
                  ),
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
            if (_launchError case final error?) ...[
              const SizedBox(height: ThemeTokens.space2),
              Text(
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
                  key: const ValueKey('mcp-elicitation-cancel'),
                  variant: CodexButtonVariant.ghost,
                  size: CodexButtonSize.sm,
                  onPressed: submitting
                      ? null
                      : () => _respond(McpElicitationAction.cancel),
                  label: 'Cancel',
                ),
                CodexButton(
                  key: const ValueKey('mcp-elicitation-decline'),
                  variant: CodexButtonVariant.secondary,
                  size: CodexButtonSize.sm,
                  onPressed: submitting
                      ? null
                      : () => _respond(McpElicitationAction.decline),
                  label: 'Decline',
                ),
                if (widget.request.mode != McpElicitationMode.openaiForm)
                  CodexButton(
                    key: const ValueKey('mcp-elicitation-accept'),
                    variant: CodexButtonVariant.primary,
                    size: CodexButtonSize.sm,
                    loading: submitting,
                    onPressed: submitting || !_isComplete
                        ? null
                        : () => _respond(McpElicitationAction.accept),
                    label: widget.request.mode == McpElicitationMode.url
                        ? 'I completed this'
                        : 'Submit',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlPrompt(bool submitting) {
    final url = widget.request.url!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          url.toString(),
          key: const ValueKey('mcp-elicitation-url'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: ThemeTokens.space2),
        Align(
          alignment: Alignment.centerLeft,
          child: CodexButton(
            key: const ValueKey('mcp-elicitation-open-url'),
            variant: CodexButtonVariant.secondary,
            size: CodexButtonSize.sm,
            onPressed: submitting ? null : _openUrl,
            label: 'Open in browser',
          ),
        ),
      ],
    );
  }

  Future<void> _openUrl() async {
    final url = widget.request.url;
    if (url == null) {
      return;
    }
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        setState(() => _launchError = 'The browser could not open this URL.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _launchError = 'The browser could not open the URL: $error',
        );
      }
    }
  }

  Widget _buildField(McpElicitationField field, bool submitting) {
    final palette = ThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${field.title}${field.required ? ' *' : ''}',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: palette.textSecondary),
        ),
        if (field.description.isNotEmpty) ...[
          const SizedBox(height: ThemeTokens.space1),
          Text(field.description, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: ThemeTokens.space2),
        switch (field.kind) {
          McpElicitationFieldKind.string ||
          McpElicitationFieldKind.number ||
          McpElicitationFieldKind.integer => TextField(
            key: ValueKey('mcp-elicitation-field-${field.id}'),
            controller: _textControllers[field.id],
            enabled: !submitting,
            maxLength: field.maxLength?.clamp(1, 4096) ?? 4096,
            keyboardType: field.kind == McpElicitationFieldKind.string
                ? TextInputType.text
                : const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
            minLines: 1,
            maxLines: field.kind == McpElicitationFieldKind.string ? 3 : 1,
            decoration: const InputDecoration(isDense: true, counterText: ''),
          ),
          McpElicitationFieldKind.boolean => CheckboxListTile(
            key: ValueKey('mcp-elicitation-field-${field.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            tristate: !field.required,
            title: Text(switch (_booleanValues[field.id]) {
              true => 'Yes',
              false => 'No',
              null => 'Not set',
            }),
            value: _booleanValues[field.id],
            onChanged: submitting
                ? null
                : (value) => setState(() => _booleanValues[field.id] = value),
          ),
          McpElicitationFieldKind.singleSelect => Column(
            children: [
              for (final option in field.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: ThemeTokens.space1),
                  child: _UserInputOptionTile(
                    key: ValueKey(
                      'mcp-elicitation-field-${field.id}-${option.value}',
                    ),
                    label: option.label,
                    description: '',
                    selected: _singleValues[field.id] == option.value,
                    enabled: !submitting,
                    onPressed: () =>
                        setState(() => _singleValues[field.id] = option.value),
                  ),
                ),
            ],
          ),
          McpElicitationFieldKind.multiSelect => Column(
            children: [
              for (final option in field.options)
                CheckboxListTile(
                  key: ValueKey(
                    'mcp-elicitation-field-${field.id}-${option.value}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(option.label),
                  value: _multiValues[field.id]!.contains(option.value),
                  onChanged: submitting
                      ? null
                      : (selected) {
                          setState(() {
                            final values = _multiValues[field.id]!;
                            if (selected ?? false) {
                              values.add(option.value);
                            } else {
                              values.remove(option.value);
                            }
                          });
                        },
                ),
            ],
          ),
        },
      ],
    );
  }

  bool get _isComplete {
    if (widget.request.mode != McpElicitationMode.form) {
      return true;
    }
    for (final field in widget.request.fields) {
      switch (field.kind) {
        case McpElicitationFieldKind.string:
          final value = _textControllers[field.id]!.text;
          final minimum = field.minLength ?? (field.required ? 1 : 0);
          if (value.length < minimum ||
              value.length > (field.maxLength ?? 4096)) {
            return false;
          }
        case McpElicitationFieldKind.number:
          final text = _textControllers[field.id]!.text.trim();
          if (text.isEmpty && !field.required) {
            continue;
          }
          final value = num.tryParse(text);
          if (value == null ||
              (value is double && !value.isFinite) ||
              (field.minimum != null && value < field.minimum!) ||
              (field.maximum != null && value > field.maximum!)) {
            return false;
          }
        case McpElicitationFieldKind.integer:
          final text = _textControllers[field.id]!.text.trim();
          if (text.isEmpty && !field.required) {
            continue;
          }
          final value = int.tryParse(text);
          if (value == null ||
              (field.minimum != null && value < field.minimum!) ||
              (field.maximum != null && value > field.maximum!)) {
            return false;
          }
        case McpElicitationFieldKind.boolean:
          if (field.required && _booleanValues[field.id] == null) {
            return false;
          }
        case McpElicitationFieldKind.singleSelect:
          if (field.required && _singleValues[field.id] == null) {
            return false;
          }
        case McpElicitationFieldKind.multiSelect:
          final count = _multiValues[field.id]!.length;
          if (count < (field.minItems ?? (field.required ? 1 : 0)) ||
              count > (field.maxItems ?? field.options.length)) {
            return false;
          }
      }
    }
    return true;
  }

  Map<String, Object?> get _content {
    final result = <String, Object?>{};
    for (final field in widget.request.fields) {
      switch (field.kind) {
        case McpElicitationFieldKind.string:
          final value = _textControllers[field.id]!.text;
          if (value.isNotEmpty || field.required) {
            result[field.id] = value;
          }
        case McpElicitationFieldKind.number:
          final text = _textControllers[field.id]!.text.trim();
          if (text.isNotEmpty) {
            result[field.id] = num.parse(text);
          }
        case McpElicitationFieldKind.integer:
          final text = _textControllers[field.id]!.text.trim();
          if (text.isNotEmpty) {
            result[field.id] = int.parse(text);
          }
        case McpElicitationFieldKind.boolean:
          final value = _booleanValues[field.id];
          if (value != null) {
            result[field.id] = value;
          }
        case McpElicitationFieldKind.singleSelect:
          final value = _singleValues[field.id];
          if (value != null) {
            result[field.id] = value;
          }
        case McpElicitationFieldKind.multiSelect:
          final values = _multiValues[field.id]!.toList(growable: false);
          if (values.isNotEmpty || field.required) {
            result[field.id] = values;
          }
      }
    }
    return result;
  }

  void _respond(McpElicitationAction action) {
    unawaited(
      widget.controller.respondToElicitation(
        widget.request.requestId,
        action,
        content: action == McpElicitationAction.accept ? _content : const {},
      ),
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
    required this.desktop,
    required this.autoAdvance,
  });

  final UserInputController controller;
  final UserInputRequest request;
  final int pendingCount;
  final String? errorMessage;
  final bool desktop;
  final bool autoAdvance;

  @override
  State<_UserInputCard> createState() => _UserInputCardState();
}

class _UserInputCardState extends State<_UserInputCard> {
  late final Map<String, TextEditingController> _textControllers;
  final Map<String, String?> _selectedOptions = {};
  final Set<String> _otherSelections = {};
  final _questionScroll = ScrollController();
  late final Map<String, FocusNode> _otherAnswerFocusNodes;
  Timer? _choiceAdvanceTimer;
  var _questionIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.desktop) {
      for (final question in widget.request.questions) {
        if (question.options.firstOrNull case final first?) {
          _selectedOptions[question.id] = first.label;
        }
      }
    }
    _textControllers = {
      for (final question in widget.request.questions)
        question.id: TextEditingController()..addListener(_handleAnswerChanged),
    };
    _otherAnswerFocusNodes = {
      for (final question in widget.request.questions)
        if (question.options.isNotEmpty && question.allowsOther)
          question.id: FocusNode(),
    };
  }

  @override
  void didUpdateWidget(covariant _UserInputCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.autoAdvance ||
        oldWidget.controller != widget.controller ||
        oldWidget.request.threadId != widget.request.threadId ||
        oldWidget.request.turnId != widget.request.turnId) {
      _cancelChoiceAdvance();
    }
  }

  void _handleAnswerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cancelChoiceAdvance();
    _questionScroll.dispose();
    for (final focus in _otherAnswerFocusNodes.values) {
      focus.dispose();
    }
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
    final theme = OfficialCodexTheme.of(context);
    final submitting = widget.controller.isSubmitting(widget.request.requestId);
    final questions = widget.request.questions;
    final stepped = widget.desktop && questions.length > 1;
    final showHeader =
        !widget.desktop || stepped || widget.pendingCount > 1 || submitting;
    final visibleQuestions = stepped ? [questions[_questionIndex]] : questions;
    final hasNext = stepped && _questionIndex < questions.length - 1;
    final canContinue = hasNext
        ? _answerFor(questions[_questionIndex]) != null
        : _isComplete;
    return Center(
      heightFactor: 1,
      child: Container(
        key: const ValueKey('user-input-card'),
        constraints: const BoxConstraints(
          maxWidth: OfficialCodexTheme.maxContentWidth,
        ),
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        padding: const EdgeInsets.all(ThemeTokens.space3),
        decoration: BoxDecoration(
          color: theme.modalSurface,
          border: Border.all(color: theme.hairlineBorder),
          borderRadius: BorderRadius.circular(
            OfficialCodexTheme.mainSurfaceRadius,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final current = visibleQuestions.firstOrNull;
            final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
            final inlineQuestion =
                widget.desktop &&
                    current != null &&
                    current.options.isNotEmpty &&
                    current.allowsOther &&
                    constraints.maxWidth >= 440 * textScale
                ? current
                : null;
            final actions = _requestActions(
              stepped: stepped,
              hasNext: hasNext,
              submitting: submitting,
              canContinue: canContinue,
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      key: const ValueKey('user-input-question-scroll'),
                      controller: _questionScroll,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showHeader) ...[
                            Row(
                              children: [
                                if (!widget.desktop)
                                  Icon(
                                    Icons.live_help_outlined,
                                    size: 18,
                                    color: theme.textSecondary,
                                  ),
                                if (!widget.desktop)
                                  const SizedBox(width: ThemeTokens.space2),
                                Expanded(
                                  child: Text(
                                    stepped
                                        ? 'Question ${_questionIndex + 1} of ${questions.length}'
                                        : 'Codex needs your input'
                                              '${widget.pendingCount > 1 ? ' (${widget.pendingCount})' : ''}',
                                    style: widget.desktop
                                        ? Theme.of(context).textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme.textSecondary,
                                              )
                                        : Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                  ),
                                ),
                                if (submitting)
                                  const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: ThemeTokens.space2),
                          ],
                          for (
                            var index = 0;
                            index < visibleQuestions.length;
                            index++
                          ) ...[
                            if (index > 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: ThemeTokens.space3,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: palette.border,
                                ),
                              ),
                            _question(
                              visibleQuestions[index],
                              submitting,
                              inlineOther: inlineQuestion != null,
                            ),
                          ],
                        ],
                      ),
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
                if (inlineQuestion != null)
                  _inlineOtherFooter(inlineQuestion, submitting, actions)
                else
                  actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _requestActions({
    required bool stepped,
    required bool hasNext,
    required bool submitting,
    required bool canContinue,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      if (stepped && _questionIndex > 0) ...[
        Flexible(
          child: CodexButton(
            key: const ValueKey('user-input-previous'),
            variant: CodexButtonVariant.ghost,
            size: CodexButtonSize.sm,
            label: 'Previous',
            onPressed: submitting
                ? null
                : () => _showQuestion(_questionIndex - 1),
          ),
        ),
        const SizedBox(width: ThemeTokens.space2),
      ],
      Flexible(
        child: CodexButton(
          key: const ValueKey('user-input-cancel'),
          variant: CodexButtonVariant.ghost,
          size: CodexButtonSize.sm,
          onPressed: submitting ? null : _cancelRequest,
          label: 'Cancel request',
          tooltip: 'Cancel request',
        ),
      ),
      const SizedBox(width: ThemeTokens.space2),
      Flexible(
        child: CodexButton(
          key: ValueKey(hasNext ? 'user-input-next' : 'user-input-submit'),
          variant: CodexButtonVariant.primary,
          size: CodexButtonSize.sm,
          loading: submitting,
          onPressed: submitting || !canContinue
              ? null
              : hasNext
              ? () => _showQuestion(_questionIndex + 1)
              : _submit,
          label: hasNext
              ? 'Continue'
              : widget.desktop
              ? 'Submit'
              : 'Submit answers',
        ),
      ),
    ],
  );

  Widget _inlineOtherFooter(
    UserInputQuestion question,
    bool submitting,
    Widget actions,
  ) {
    final focus = _otherAnswerFocusNodes[question.id]!;
    final theme = OfficialCodexTheme.of(context);
    return AnimatedBuilder(
      animation: focus,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(OfficialCodexTheme.buttonRadius),
          border: Border.all(
            color: focus.hasFocus ? theme.focusRing : Colors.transparent,
          ),
        ),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          key: const ValueKey('desktop-question-other-footer'),
          children: [
            Expanded(
              child: Focus(
                canRequestFocus: false,
                onFocusChange: (focused) {
                  if (focused) {
                    _selectOtherAnswer(question, moveFocus: false);
                  }
                },
                child: _answerField(
                  question,
                  _textControllers[question.id]!,
                  submitting,
                  inline: true,
                ),
              ),
            ),
            const SizedBox(width: ThemeTokens.space2),
            actions,
          ],
        ),
      ),
    );
  }

  Widget _question(
    UserInputQuestion question,
    bool submitting, {
    required bool inlineOther,
  }) {
    final palette = ThemeTokens.of(context);
    final textController = _textControllers[question.id]!;
    final usesOther = _otherSelections.contains(question.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.desktop) ...[
          Text(
            question.header,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: ThemeTokens.space1),
        ],
        Text(question.question, style: Theme.of(context).textTheme.bodyMedium),
        if (question.options.isNotEmpty) ...[
          const SizedBox(height: ThemeTokens.space2),
          for (final (index, option) in question.options.indexed) ...[
            _UserInputOptionTile(
              key: ValueKey('user-input-${question.id}-${option.label}'),
              label: option.label,
              description: option.description,
              desktop: widget.desktop,
              number: question.options.length > 1 ? index + 1 : null,
              selected:
                  !usesOther && _selectedOptions[question.id] == option.label,
              enabled: !submitting,
              onPressed: () => _selectOption(question, option.label),
            ),
            const SizedBox(height: ThemeTokens.space1),
          ],
          if (question.allowsOther && !inlineOther) ...[
            _UserInputOptionTile(
              key: ValueKey('user-input-${question.id}-other'),
              label: 'Other',
              description: 'Enter a different answer.',
              desktop: widget.desktop,
              custom: true,
              selected: usesOther,
              enabled: !submitting,
              onPressed: () => _selectOtherAnswer(question),
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

  void _selectOption(UserInputQuestion question, String label) {
    if (_choiceAdvanceTimer != null) {
      return;
    }
    _otherAnswerFocusNodes[question.id]?.unfocus();
    setState(() {
      _otherSelections.remove(question.id);
      _selectedOptions[question.id] = label;
    });
    if (!widget.autoAdvance) {
      return;
    }

    final index = _questionIndex;
    _choiceAdvanceTimer = Timer(const Duration(milliseconds: 180), () {
      _choiceAdvanceTimer = null;
      if (!mounted ||
          !TickerMode.valuesOf(context).enabled ||
          _questionIndex != index ||
          widget.controller.isSubmitting(widget.request.requestId)) {
        return;
      }
      if (index + 1 < widget.request.questions.length) {
        _showQuestion(index + 1);
      } else {
        _submit();
      }
    });
  }

  void _cancelChoiceAdvance() {
    _choiceAdvanceTimer?.cancel();
    _choiceAdvanceTimer = null;
  }

  void _cancelRequest() {
    _cancelChoiceAdvance();
    unawaited(widget.controller.cancel(widget.request.requestId));
  }

  void _selectOtherAnswer(UserInputQuestion question, {bool moveFocus = true}) {
    _cancelChoiceAdvance();
    if (!_otherSelections.contains(question.id)) {
      setState(() {
        _selectedOptions[question.id] = null;
        _otherSelections.add(question.id);
      });
    }
    if (widget.desktop && moveFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.request.questions[_questionIndex].id == question.id &&
            _otherSelections.contains(question.id) &&
            !widget.controller.isSubmitting(widget.request.requestId)) {
          _otherAnswerFocusNodes[question.id]?.requestFocus();
        }
      });
    }
  }

  Widget _answerField(
    UserInputQuestion question,
    TextEditingController controller,
    bool submitting, {
    bool inline = false,
  }) => TextField(
    key: ValueKey('user-input-${question.id}-text'),
    controller: controller,
    focusNode: widget.desktop ? _otherAnswerFocusNodes[question.id] : null,
    onChanged: inline
        ? (_) => _selectOtherAnswer(question, moveFocus: false)
        : null,
    enabled: !submitting,
    obscureText: question.isSecret,
    maxLength: 4096,
    minLines: 1,
    maxLines: question.isSecret ? 1 : 4,
    decoration: InputDecoration(
      isDense: true,
      counterText: '',
      filled: inline ? false : null,
      border: inline ? InputBorder.none : null,
      enabledBorder: inline ? InputBorder.none : null,
      focusedBorder: inline ? InputBorder.none : null,
      disabledBorder: inline ? InputBorder.none : null,
      prefixIcon: inline ? const Icon(Icons.edit_outlined, size: 14) : null,
      prefixIconConstraints: inline
          ? const BoxConstraints(minWidth: 20, minHeight: 20)
          : null,
      contentPadding: inline
          ? const EdgeInsetsDirectional.only(start: ThemeTokens.space2)
          : null,
      hintText: question.isSecret
          ? 'Enter a private answer'
          : inline
          ? 'Type a different answer'
          : 'Type an answer',
    ),
  );

  void _showQuestion(int index) {
    if (index < 0 || index >= widget.request.questions.length) return;
    _cancelChoiceAdvance();
    if (_questionScroll.hasClients) {
      _questionScroll.jumpTo(0);
    }
    setState(() => _questionIndex = index);
  }

  String? _answerFor(UserInputQuestion question) {
    if (question.options.isNotEmpty &&
        !_otherSelections.contains(question.id)) {
      return _selectedOptions[question.id];
    }
    final draft = _textControllers[question.id]!.text;
    final answer = question.isSecret ? draft : draft.trim();
    return answer.isEmpty ? null : answer;
  }

  bool get _isComplete => widget.request.questions.every(
    (question) => _answerFor(question) != null,
  );

  void _submit() {
    _cancelChoiceAdvance();
    if (!_isComplete) return;
    final answers = {
      for (final question in widget.request.questions)
        question.id: [_answerFor(question)!],
    };
    unawaited(widget.controller.submit(widget.request.requestId, answers));
  }
}

class _UserInputOptionTile extends StatefulWidget {
  const _UserInputOptionTile({
    super.key,
    required this.label,
    required this.description,
    this.desktop = false,
    this.number,
    this.custom = false,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final String description;
  final bool desktop;
  final int? number;
  final bool custom;
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
    final theme = OfficialCodexTheme.of(context);
    final background = widget.selected
        ? palette.selected
        : _hovered && widget.enabled
        ? palette.hover
        : Colors.transparent;
    final borderColor = _focused
        ? palette.accent
        : widget.desktop
        ? Colors.transparent
        : widget.selected
        ? palette.borderStrong
        : palette.border;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      padding: widget.desktop
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: widget.desktop ? const BoxConstraints(minHeight: 32) : null,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(OfficialCodexTheme.buttonRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.desktop)
            _desktopMarker(theme)
          else
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
      checked: widget.desktop ? widget.selected : null,
      inMutuallyExclusiveGroup: widget.desktop,
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

  Widget _desktopMarker(OfficialCodexThemeData theme) {
    final number = widget.number;
    if (widget.custom) {
      return SizedBox.square(
        dimension: 20,
        child: Icon(Icons.edit_outlined, size: 14, color: theme.textMuted),
      );
    }
    final foreground = widget.selected
        ? theme.workspaceBackground
        : theme.textSecondary;
    return Container(
      key: const ValueKey('desktop-question-option-marker'),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.selected ? theme.textPrimary : theme.elevatedSurface,
        border: Border.all(
          color: widget.selected ? theme.textPrimary : theme.hairlineBorder,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: number != null
          ? Text(
              '$number',
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            )
          : widget.selected
          ? Icon(Icons.circle, size: 6, color: foreground)
          : null,
    );
  }
}
