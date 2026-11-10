part of '../codex_native_app.dart';

class _ComposerModelSummaryButton extends StatefulWidget {
  const _ComposerModelSummaryButton({
    required this.controller,
    this.maxLabelWidth = 190,
    this.iconOnly = false,
    this.useDesktopPicker = false,
  });

  final ExecutionSettingsController controller;
  final double maxLabelWidth;
  final bool iconOnly;
  final bool useDesktopPicker;

  @override
  State<_ComposerModelSummaryButton> createState() =>
      _ComposerModelSummaryButtonState();
}

class _ComposerModelSummaryButtonState
    extends State<_ComposerModelSummaryButton> {
  final _popover = CodexPopoverController();
  var _availableHeight = 316.0;

  @override
  void didUpdateWidget(covariant _ComposerModelSummaryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useDesktopPicker != widget.useDesktopPicker ||
        oldWidget.controller != widget.controller) {
      _popover.hide();
    }
  }

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  void _openPicker() {
    if (!widget.useDesktopPicker) {
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) =>
              _ExecutionSettingsDialog(controller: widget.controller),
        ),
      );
      return;
    }
    final anchor = context.findRenderObject();
    if (anchor is RenderBox && anchor.hasSize) {
      _availableHeight = math.max(0, anchor.localToGlobal(Offset.zero).dy - 14);
    }
    _popover.toggle();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final palette = ThemeTokens.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final model = controller.effectiveModel;
        final String summary;
        if (widget.useDesktopPicker && controller.selectedModelId == null) {
          final effort = _formatModelEffortLabel(
            controller.selectedReasoningEffort,
          );
          summary = effort == null
              ? 'Codex settings'
              : 'Codex settings $effort';
        } else if (model == null) {
          summary = controller.loading ? 'Loading models…' : 'Codex default';
        } else {
          final rawEffort =
              controller.selectedReasoningEffort ??
              model.defaultReasoningEffort;
          final effortLabel = _formatModelEffortLabel(rawEffort);
          summary = effortLabel == null
              ? model.displayName
              : widget.useDesktopPicker
              ? '${model.displayName} $effortLabel'
              : '${model.displayName} · $effortLabel';
        }
        final tooltip = 'Model and reasoning ($summary)';
        final onPressed = controller.loading ? null : _openPicker;
        final button = widget.iconOnly
            ? CodexIconButton(
                key: const ValueKey('composer-model-pill'),
                tooltip: tooltip,
                size: 28,
                onPressed: onPressed,
                icon: const Icon(Icons.tune_rounded, size: 16),
              )
            : Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CodexButton(
                  key: const ValueKey('composer-model-pill'),
                  variant: CodexButtonVariant.ghost,
                  size: CodexButtonSize.sm,
                  onPressed: onPressed,
                  tooltip: tooltip,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: widget.maxLabelWidth,
                        ),
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: palette.textMuted,
                      ),
                    ],
                  ),
                ),
              );
        if (!widget.useDesktopPicker) return button;
        return CodexPopoverAnchor(
          controller: _popover,
          width: 224,
          targetAnchor: Alignment.topRight,
          followerAnchor: Alignment.bottomRight,
          offset: const Offset(0, -6),
          popoverBuilder: (context, close) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.min(
                math.min(316, _availableHeight),
                math.max(0, MediaQuery.sizeOf(context).height - 84),
              ),
            ),
            child: _ComposerModelPicker(controller: controller, close: close),
          ),
          child: button,
        );
      },
    );
  }
}

String? _formatModelEffortLabel(String? effort) {
  if (effort == null || effort.trim().isEmpty) {
    return null;
  }
  return switch (effort.trim().toLowerCase()) {
    'low' => 'Low',
    'medium' => 'Medium',
    'high' => 'High',
    'xhigh' => 'Extra high',
    'minimal' => 'Minimal',
    final other => '${other[0].toUpperCase()}${other.substring(1)}',
  };
}

class _ComposerModelPicker extends StatefulWidget {
  const _ComposerModelPicker({required this.controller, required this.close});

  final ExecutionSettingsController controller;
  final VoidCallback close;

  @override
  State<_ComposerModelPicker> createState() => _ComposerModelPickerState();
}

class _ComposerModelPickerState extends State<_ComposerModelPicker> {
  var _showModelList = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = OfficialCodexTheme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final model = controller.effectiveModel;
        final efforts = controller.availableReasoningEfforts;
        final current =
            controller.selectedReasoningEffort ?? model?.defaultReasoningEffort;
        final index = efforts.indexWhere((option) => option.value == current);
        return SingleChildScrollView(
          key: const ValueKey('composer-model-picker'),
          child:
              !_showModelList &&
                  controller.selectedModelId != null &&
                  model != null &&
                  efforts.length > 1 &&
                  index >= 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: CodexButton(
                              key: const ValueKey('composer-model-list-button'),
                              tooltip: 'Select model',
                              size: CodexButtonSize.lg,
                              variant: CodexButtonVariant.ghost,
                              onPressed: () =>
                                  setState(() => _showModelList = true),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 168,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatModelEffortLabel(current) ?? '',
                                        style: const TextStyle(
                                          color: OfficialCodexTheme.chartBlue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              model.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.textSecondary,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 14,
                                            color: theme.textMuted,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            start: 0,
                            top: 0,
                            child: CodexIconButton(
                              key: const ValueKey('composer-model-reset'),
                              tooltip: 'Clear model and reasoning overrides',
                              size: 32,
                              onPressed: () {
                                controller.selectModel(null);
                                widget.close();
                              },
                              icon: const Icon(
                                Icons.restart_alt_rounded,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 24,
                          activeTrackColor: theme.hoverTint,
                          inactiveTrackColor: theme.hoverTint,
                          activeTickMarkColor: theme.textMuted,
                          inactiveTickMarkColor: theme.textMuted,
                          thumbColor: theme.modalSurface,
                          overlayColor: theme.focusRing.withValues(alpha: 0.12),
                          trackShape: const RoundedRectSliderTrackShape(),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 11,
                          ),
                          tickMarkShape: const RoundSliderTickMarkShape(
                            tickMarkRadius: 1.5,
                          ),
                          showValueIndicator: ShowValueIndicator.never,
                        ),
                        child: Semantics(
                          label: 'Reasoning effort',
                          child: Slider(
                            key: const ValueKey('composer-reasoning-slider'),
                            autofocus: true,
                            value: index.toDouble(),
                            max: (efforts.length - 1).toDouble(),
                            divisions: efforts.length - 1,
                            semanticFormatterCallback: (value) =>
                                _formatModelEffortLabel(
                                  efforts[value.round()].value,
                                ) ??
                                efforts[value.round()].value,
                            onChanged: (value) {
                              final next = value.round();
                              if (index != next) {
                                controller.selectReasoningEffort(
                                  efforts[next].value,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : CodexMenu<String>(
                  key: const ValueKey('composer-model-list'),
                  header: Text(
                    'Select model',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  selectedValue: controller.selectedModelId ?? '',
                  items: [
                    const CodexMenuItem(
                      value: '',
                      label: 'Inherit from Codex',
                      description: 'Use the runtime’s settings',
                    ),
                    for (final model in controller.models)
                      CodexMenuItem(value: model.id, label: model.displayName),
                  ],
                  onSelected: (id) {
                    final selected = id.isEmpty ? null : id;
                    if (selected != controller.selectedModelId) {
                      controller.selectModel(selected);
                    }
                    if (selected == null) {
                      widget.close();
                      return;
                    }
                    final nextEfforts = controller.availableReasoningEfforts;
                    final nextDefault =
                        controller.selectedReasoningEffort ??
                        controller.effectiveModel?.defaultReasoningEffort;
                    if (nextEfforts.length > 1 &&
                        nextEfforts.any(
                          (effort) => effort.value == nextDefault,
                        )) {
                      setState(() => _showModelList = false);
                    } else {
                      widget.close();
                    }
                  },
                ),
        );
      },
    );
  }
}
