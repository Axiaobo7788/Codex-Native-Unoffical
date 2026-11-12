import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/diff_models.dart';
import '../theme/official_codex_theme.dart';
import 'codex_button.dart';
import 'codex_tooltip.dart';

/// Semantic tool and command activity row primitive.
///
/// When [inline] is `false` (compact/card execution mode), renders the 34px
/// bordered card with monospace summary and optional trailing action button.
/// When [inline] is `true` (Desktop conversation timeline), delegates to
/// [CodexInlineActivityHeader] (`152406.BI7J` / `jKy0` / `o6bI`) with natural
/// scalable chat line-height, 60% resting ink, and callback-only disclosure.
class CodexActivityRow extends StatelessWidget {
  const CodexActivityRow({
    super.key,
    required this.summary,
    this.verbLength,
    this.icon,
    this.accessory,
    this.accessorySemanticLabel,
    this.statusText,
    this.isRunning = false,
    this.isError = false,
    this.isWarning = false,
    this.onViewOutput,
    this.actionLabel = 'View output',
    this.trailingAction,
    this.textWidget,
    this.inline = false,
    this.hasDisclosure = false,
    this.isExpanded = false,
    this.onToggle,
    this.disclosureTooltip,
  });

  final String summary;
  final int? verbLength;
  final Widget? icon;
  final Widget? accessory;
  final String? accessorySemanticLabel;
  final String? statusText;
  final bool isRunning;
  final bool isError;
  final bool isWarning;
  final VoidCallback? onViewOutput;
  final String actionLabel;
  final Widget? trailingAction;
  final Widget? textWidget;
  final bool inline;
  final bool hasDisclosure;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final String? disclosureTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    if (inline) {
      final header = CodexInlineActivityHeader(
        label: summary,
        verbLength: isError || isWarning ? null : verbLength,
        leadingIcon: icon ?? const Icon(Icons.terminal_rounded),
        restingTextColor: isError ? theme.danger : theme.activitySummaryText,
        restingIconColor: isError
            ? theme.danger
            : isWarning
            ? theme.warning
            : theme.activitySummaryText,
        hoverPromotesToPrimary: !isError,
        accessory: accessory,
        accessorySemanticLabel: accessorySemanticLabel,
        statusText: statusText,
        hasDisclosure: hasDisclosure,
        isExpanded: isExpanded,
        onToggle: onToggle,
        disclosureTooltip: disclosureTooltip,
        customTextWidget: hasDisclosure ? null : textWidget,
      );
      final Widget? effectiveTrailing =
          trailingAction ??
          (onViewOutput == null
              ? null
              : CodexButton(
                  onPressed: onViewOutput,
                  label: actionLabel,
                  tooltip: actionLabel,
                  variant: CodexButtonVariant.ghost,
                  size: CodexButtonSize.sm,
                ));
      if (effectiveTrailing == null) {
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: header,
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: header,
              ),
            ),
            const SizedBox(width: 8.0),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: effectiveTrailing,
            ),
          ],
        ),
      );
    }

    return Container(
      height: OfficialCodexTheme.activityRowHeight,
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: BorderRadius.circular(
          OfficialCodexTheme.activityRowRadius,
        ),
        border: Border.all(
          color: isError
              ? theme.danger.withValues(alpha: 0.5)
              : isWarning
              ? theme.warning.withValues(alpha: 0.5)
              : theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (isRunning) ...[
              SizedBox(
                width: 14.0,
                height: 14.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
                ),
              ),
            ] else ...[
              IconTheme(
                data: IconThemeData(
                  color: isError
                      ? theme.danger
                      : isWarning
                      ? theme.warning
                      : theme.textMuted,
                  size: 14.0,
                ),
                child: icon ?? const Icon(Icons.terminal_rounded),
              ),
            ],
            const SizedBox(width: 8.0),
            Expanded(
              child:
                  textWidget ??
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      color: isError ? theme.danger : theme.textPrimary,
                    ),
                  ),
            ),
            if (statusText != null && statusText!.isNotEmpty) ...[
              const SizedBox(width: 8.0),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth / 4),
                child: Text(
                  statusText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: theme.textMuted),
                ),
              ),
            ],
            if (trailingAction != null) ...[
              const SizedBox(width: 8.0),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                child: trailingAction!,
              ),
            ] else if (onViewOutput != null) ...[
              const SizedBox(width: 8.0),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                child: CodexButton(
                  onPressed: onViewOutput,
                  label: actionLabel,
                  tooltip: actionLabel,
                  variant: CodexButtonVariant.ghost,
                  size: CodexButtonSize.sm,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Official inline activity summary / disclosure header (`152406.BI7J` / `jKy0` / `o6bI`).
///
/// Renders a natural-height, self-start inline row (`14px` / `21px` scalable
/// `.text-size-chat` line box, `6px` icon-to-label gap, `4px` label-to-chevron gap). Only
/// becomes an interactive button with hover ink promotion and `14px` chevron
/// when [hasDisclosure] is `true`.
typedef CodexInlineHeaderLabelBuilder = Widget Function(
  BuildContext context,
  bool active,
  Color effectiveTextColor,
);

class CodexInlineActivityHeader extends StatefulWidget {
  const CodexInlineActivityHeader({
    super.key,
    required this.label,
    this.verbLength,
    this.leadingIcon,
    this.restingTextColor,
    this.restingIconColor,
    this.hoverPromotesToPrimary = true,
    this.accessory,
    this.accessorySemanticLabel,
    this.statusText,
    this.hasDisclosure = false,
    this.isExpanded = false,
    this.onToggle,
    this.disclosureTooltip,
    this.customTextWidget,
    this.labelBuilder,
    this.semanticLabelOverride,
  });

  final String label;
  final int? verbLength;
  final Widget? leadingIcon;
  final Color? restingTextColor;
  final Color? restingIconColor;
  final bool hoverPromotesToPrimary;
  final Widget? accessory;
  final String? accessorySemanticLabel;
  final String? statusText;
  final bool hasDisclosure;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final String? disclosureTooltip;
  final Widget? customTextWidget;
  final CodexInlineHeaderLabelBuilder? labelBuilder;
  final String? semanticLabelOverride;

  bool get isInteractiveEnabled => hasDisclosure && onToggle != null;

  @override
  State<CodexInlineActivityHeader> createState() =>
      _CodexInlineActivityHeaderState();
}

class _CodexInlineActivityHeaderState extends State<CodexInlineActivityHeader> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void didUpdateWidget(covariant CodexInlineActivityHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isInteractiveEnabled && (_isHovered || _isFocused)) {
      _isHovered = false;
      _isFocused = false;
    }
  }

  void _handleHover(bool hovering) {
    final next = widget.isInteractiveEnabled && hovering;
    if (next != _isHovered) {
      setState(() => _isHovered = next);
    }
  }

  void _handleFocus(bool focused) {
    final next = widget.isInteractiveEnabled && focused;
    if (next != _isFocused) {
      setState(() => _isFocused = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final baseTextColor = widget.restingTextColor ?? theme.activitySummaryText;
    final baseIconColor = widget.restingIconColor ?? baseTextColor;
    final active = widget.isInteractiveEnabled && (_isHovered || _isFocused);
    final effectiveTextColor = active && widget.hoverPromotesToPrimary
        ? theme.textPrimary
        : baseTextColor;
    final effectiveIconColor = active && widget.hoverPromotesToPrimary
        ? theme.textPrimary
        : baseIconColor;

    final hasStatus =
        widget.statusText != null && widget.statusText!.isNotEmpty;
    final rowContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.leadingIcon != null) ...[
          IconTheme(
            data: IconThemeData(
              color: effectiveIconColor,
              size: OfficialCodexTheme.activityInlineIconSize,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                color: effectiveIconColor,
                size: OfficialCodexTheme.activityInlineIconSize,
              ),
              child: _recolorIconIfNeeded(
                widget.leadingIcon!,
                effectiveIconColor,
              ),
            ),
          ),
          const SizedBox(width: OfficialCodexTheme.activityInlineIconGap),
        ],
        Flexible(
          flex: 3,
          child:
              widget.labelBuilder?.call(context, active, effectiveTextColor) ??
              widget.customTextWidget ??
              _buildLabelText(
                theme: theme,
                active: active,
                effectiveTextColor: effectiveTextColor,
              ),
        ),
        if (widget.accessory != null) ...[
          const SizedBox(width: OfficialCodexTheme.activityInlineChevronGap),
          widget.accessory!,
        ],
        if (hasStatus) ...[
          const SizedBox(width: 8.0),
          Flexible(
            child: Text(
              widget.statusText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: OfficialCodexTheme.activityChatLineHeight,
                color: theme.textMuted,
              ),
            ),
          ),
        ],
        if (widget.hasDisclosure) ...[
          const SizedBox(width: OfficialCodexTheme.activityInlineChevronGap),
          Opacity(
            opacity: widget.isExpanded || active ? 1.0 : 0.0,
            child: AnimatedRotation(
              turns: widget.isExpanded ? 0.25 : 0.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.chevron_right_rounded,
                size: OfficialCodexTheme.activityInlineIconSize,
                color: effectiveTextColor,
              ),
            ),
          ),
        ],
      ],
    );

    if (!widget.hasDisclosure) {
      return rowContent;
    }

    final isEnabled = widget.isInteractiveEnabled;
    final semanticParts = <String>[
      widget.label,
      if (widget.accessorySemanticLabel case final acc? when acc.isNotEmpty)
        acc,
      if (hasStatus) widget.statusText!,
    ];
    final overrideLabel = widget.semanticLabelOverride;
    final semanticLabel = overrideLabel != null && overrideLabel.isNotEmpty
        ? overrideLabel
        : semanticParts.join(', ');
    Widget trigger = Semantics(
      container: true,
      button: true,
      enabled: isEnabled,
      focusable: isEnabled,
      focused: _isFocused,
      expanded: widget.isExpanded,
      label: semanticLabel,
      onTap: isEnabled ? widget.onToggle : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: isEnabled,
        onShowHoverHighlight: _handleHover,
        onShowFocusHighlight: _handleFocus,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => isEnabled ? widget.onToggle?.call() : null,
          ),
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isEnabled ? widget.onToggle : null,
          child: MouseRegion(
            onEnter: (_) => _handleHover(true),
            onExit: (_) => _handleHover(false),
            cursor: isEnabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: CustomPaint(
              foregroundPainter: _isFocused
                  ? _InlineFocusRingPainter(color: theme.focusRing)
                  : null,
              child: rowContent,
            ),
          ),
        ),
      ),
    );

    final tooltip = widget.disclosureTooltip;
    if (tooltip != null && tooltip.isNotEmpty) {
      trigger = CodexTooltip(message: tooltip, child: trigger);
    }
    return trigger;
  }

  Widget _buildLabelText({
    required OfficialCodexThemeData theme,
    required bool active,
    required Color effectiveTextColor,
  }) {
    final baseStyle = TextStyle(
      fontSize: OfficialCodexTheme.activityChatFontSize,
      height: OfficialCodexTheme.activityChatLineHeight,
      fontWeight: FontWeight.w400,
      color: effectiveTextColor,
    );
    final splitAt = widget.verbLength;
    if (splitAt != null && splitAt > 0 && splitAt < widget.label.length) {
      final detailColor = active && widget.hoverPromotesToPrimary
          ? theme.textPrimary
          : theme.activityChildText;
      return Text.rich(
        TextSpan(
          text: widget.label.substring(0, splitAt),
          children: [
            TextSpan(
              text: widget.label.substring(splitAt),
              style: TextStyle(color: detailColor),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }
    return Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
    );
  }

  static Widget _recolorIconIfNeeded(Widget icon, Color color) {
    if (icon is Icon) {
      return Icon(
        icon.icon,
        key: icon.key,
        size: icon.size ?? OfficialCodexTheme.activityInlineIconSize,
        fill: icon.fill,
        weight: icon.weight,
        grade: icon.grade,
        opticalSize: icon.opticalSize,
        color: color,
        shadows: icon.shadows,
        semanticLabel: icon.semanticLabel,
        textDirection: icon.textDirection,
        applyTextScaling: icon.applyTextScaling,
        blendMode: icon.blendMode,
      );
    }
    return icon;
  }
}

/// Official Desktop inline `Worked for` turn divider (`225284.getw.i` +
/// `890434.ygO2` `ghostTertiary` `inline` + `14353.mRLe`).
///
/// Renders a backgroundless inline disclosure button (`14px` / `21px`
/// `textMuted` -> `textPrimary` on hover/focus, always-visible `14px` chevron
/// rotating `90°` when expanded), followed by a `4px` gap (`pt-1`), a `1px`
/// full-width hairline rule, and `16px` (`--conversation-item-gap`) bottom rhythm.
class CodexInlineWorkDivider extends StatefulWidget {
  const CodexInlineWorkDivider({
    super.key,
    this.triggerKey,
    required this.label,
    required this.isExpanded,
    required this.onToggle,
    this.isLoading = false,
    this.bottomSpacing = OfficialCodexTheme.conversationItemGap,
  });

  final Key? triggerKey;
  final String label;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final bool isLoading;
  final double bottomSpacing;

  bool get isEnabled => onToggle != null && !isLoading;

  @override
  State<CodexInlineWorkDivider> createState() => _CodexInlineWorkDividerState();
}

class _CodexInlineWorkDividerState extends State<CodexInlineWorkDivider> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void didUpdateWidget(covariant CodexInlineWorkDivider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEnabled && (_isHovered || _isFocused)) {
      _isHovered = false;
      _isFocused = false;
    }
  }

  void _handleHover(bool hovering) {
    final next = widget.isEnabled && hovering;
    if (next != _isHovered) {
      setState(() => _isHovered = next);
    }
  }

  void _handleFocus(bool focused) {
    final next = widget.isEnabled && focused;
    if (next != _isFocused) {
      setState(() => _isFocused = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final active = widget.isEnabled && (_isHovered || _isFocused);
    final effectiveColor = active ? theme.textPrimary : theme.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            key: widget.triggerKey,
            container: true,
            button: true,
            enabled: widget.isEnabled,
            focusable: widget.isEnabled,
            focused: _isFocused,
            expanded: widget.isExpanded,
            label: widget.label,
            onTap: widget.isEnabled ? widget.onToggle : null,
            excludeSemantics: true,
            child: FocusableActionDetector(
              enabled: widget.isEnabled,
              onShowHoverHighlight: _handleHover,
              onShowFocusHighlight: _handleFocus,
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) =>
                      widget.isEnabled ? widget.onToggle?.call() : null,
                ),
              },
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.isEnabled ? widget.onToggle : null,
                child: MouseRegion(
                  onEnter: (_) => _handleHover(true),
                  onExit: (_) => _handleHover(false),
                  cursor: widget.isEnabled
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: CustomPaint(
                    foregroundPainter: _isFocused
                        ? _InlineFocusRingPainter(color: theme.focusRing)
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: OfficialCodexTheme.activityChatFontSize,
                              height: OfficialCodexTheme.activityChatLineHeight,
                              fontWeight: FontWeight.w400,
                              color: effectiveColor,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: OfficialCodexTheme.activityInlineChevronGap,
                        ),
                        if (widget.isLoading)
                          SizedBox(
                            width: OfficialCodexTheme.activityInlineIconSize,
                            height: OfficialCodexTheme.activityInlineIconSize,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                effectiveColor,
                              ),
                            ),
                          )
                        else
                          AnimatedRotation(
                            turns: widget.isExpanded ? 0.25 : 0.0,
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: OfficialCodexTheme.activityInlineIconSize,
                              color: effectiveColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: OfficialCodexTheme.workDividerRuleTopGap),
        SizedBox(
          width: double.infinity,
          height: 1.0,
          child: ColoredBox(color: theme.hairlineBorder),
        ),
        if (widget.bottomSpacing > 0) SizedBox(height: widget.bottomSpacing),
      ],
    );
  }
}

class _InlineFocusRingPainter extends CustomPainter {
  const _InlineFocusRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(2.0), const Radius.circular(4.0)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _InlineFocusRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Semantic turn work divider primitive ("Worked for Xm Ys ›") with centered hairline rule
/// and interactive collapsible pill button.
class CodexActivityDivider extends StatefulWidget {
  const CodexActivityDivider({
    super.key,
    required this.label,
    required this.isExpanded,
    required this.onToggle,
    this.isLoading = false,
  });

  final String label;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final bool isLoading;

  bool get isEnabled => onToggle != null && !isLoading;

  @override
  State<CodexActivityDivider> createState() => _CodexActivityDividerState();
}

class _CodexActivityDividerState extends State<CodexActivityDivider> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  void didUpdateWidget(covariant CodexActivityDivider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEnabled && (_isHovered || _isPressed || _isFocused)) {
      _isHovered = false;
      _isPressed = false;
      _isFocused = false;
    }
  }

  void _handleHover(bool hovering) {
    final next = widget.isEnabled && hovering;
    if (next != _isHovered) {
      setState(() => _isHovered = next);
    }
  }

  void _handleFocus(bool focused) {
    final next = widget.isEnabled && focused;
    if (next != _isFocused) {
      setState(() => _isFocused = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final Color pillColor;
    if (_isPressed) {
      pillColor = Color.alphaBlend(
        theme.pressedTint,
        theme.workspaceBackground,
      );
    } else if (_isHovered) {
      pillColor = Color.alphaBlend(theme.hoverTint, theme.workspaceBackground);
    } else {
      pillColor = theme.workspaceBackground;
    }

    final textColor = _isHovered || _isPressed
        ? theme.textSecondary
        : theme.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Divider(
            height: 1.0,
            thickness: OfficialCodexTheme.hairlineBorderWidth,
            color: theme.hairlineBorder,
          ),
          Semantics(
            button: true,
            enabled: widget.isEnabled,
            toggled: widget.isExpanded,
            label: widget.label,
            child: FocusableActionDetector(
              enabled: widget.isEnabled,
              onShowHoverHighlight: _handleHover,
              onShowFocusHighlight: _handleFocus,
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) =>
                      widget.isEnabled ? widget.onToggle?.call() : null,
                ),
              },
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.isEnabled ? widget.onToggle : null,
                onTapDown: widget.isEnabled
                    ? (_) => setState(() => _isPressed = true)
                    : null,
                onTapUp: (_) {
                  if (_isPressed) {
                    setState(() => _isPressed = false);
                  }
                },
                onTapCancel: () {
                  if (_isPressed) {
                    setState(() => _isPressed = false);
                  }
                },
                child: MouseRegion(
                  onEnter: (_) => _handleHover(true),
                  onExit: (_) => _handleHover(false),
                  cursor: widget.isEnabled
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOut,
                    constraints: const BoxConstraints(
                      minHeight: OfficialCodexTheme.workDividerHeight,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(
                        OfficialCodexTheme.workDividerHeight / 2,
                      ),
                      border: Border.all(
                        color: _isFocused
                            ? theme.focusRing
                            : theme.hairlineBorder,
                        width: _isFocused
                            ? 1.5
                            : OfficialCodexTheme.hairlineBorderWidth,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        if (widget.isLoading)
                          Padding(
                            padding: const EdgeInsets.only(left: 2.0),
                            child: SizedBox(
                              width: 12.0,
                              height: 12.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  textColor,
                                ),
                              ),
                            ),
                          )
                        else
                          Icon(
                            widget.isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            size: 14.0,
                            color: textColor,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final RegExp _leadingPromptPattern = RegExp(r'^\$\s+');
final RegExp _shellLcPrefixPattern = RegExp(
  r'^(?:(?:/usr)?/bin/)?(?:zsh|bash)\s+-lc\s+',
);
final RegExp _nonWhitespaceOutputPattern = RegExp(r'\S');

String _stripNativeCommandPrefix(String rawCommand) {
  final trimmed = rawCommand.trim();
  if (trimmed.startsWith('Command: ')) {
    return trimmed.substring('Command: '.length).trim();
  }
  return trimmed;
}

/// Detects the display shell header label (`225284.kq2V` + `972499.EWyk`) from
/// [rawCommand] before `-lc` unwrapping, falling back to `'Shell'`.
String detectCodexShellLabel(String rawCommand) {
  var text = _stripNativeCommandPrefix(rawCommand);
  if (text.isEmpty) {
    return 'Shell';
  }
  text = text.replaceFirst(_leadingPromptPattern, '').trimLeft();
  if (text.isEmpty) {
    return 'Shell';
  }
  String? executable;
  final firstChar = text[0];
  if (firstChar == "'" || firstChar == '"') {
    final endQuote = text.indexOf(firstChar, 1);
    if (endQuote > 1) {
      final inner = text.substring(1, endQuote).trim();
      if (endQuote + 1 < text.length) {
        executable = inner;
      } else {
        text = inner;
      }
    }
  }
  if (executable == null) {
    final wsIndex = text.indexOf(RegExp(r'\s'));
    executable = wsIndex == -1 ? text : text.substring(0, wsIndex);
  }
  if (executable.isEmpty) {
    return 'Shell';
  }
  final slashIndex = executable.lastIndexOf('/');
  final backslashIndex = executable.lastIndexOf(r'\');
  final sep = slashIndex > backslashIndex ? slashIndex : backslashIndex;
  final base = (sep >= 0 ? executable.substring(sep + 1) : executable)
      .toLowerCase();
  return switch (base) {
    'bash' || 'bash.exe' || 'git-bash.exe' => 'bash',
    'zsh' || 'zsh.exe' => 'zsh',
    'sh' || 'sh.exe' => 'sh',
    'cmd' || 'cmd.exe' => 'cmd',
    'powershell' || 'powershell.exe' || 'pwsh' || 'pwsh.exe' => 'PowerShell',
    _ => 'Shell',
  };
}

String _stripOuterShellQuotes(String input) {
  var current = input.trim();
  for (var i = 0; i < 8; i++) {
    if (current.length >= 3 &&
        current.startsWith(r"$'") &&
        current.endsWith("'")) {
      current = current
          .substring(2, current.length - 1)
          .replaceAll(r"\'", "'")
          .trim();
      continue;
    }
    if (current.length >= 2 &&
        ((current.startsWith("'") && current.endsWith("'")) ||
            (current.startsWith('"') && current.endsWith('"')))) {
      final isDouble = current.startsWith('"');
      current = current
          .substring(1, current.length - 1)
          .replaceAll('\'"\'"\'', "'");
      if (isDouble) {
        current = current.replaceAll(r'\"', '"');
      }
      current = current.trim();
      continue;
    }
    break;
  }
  return current;
}

String _normalizePromptAndQuotes(String input) {
  var text = input.trim().replaceFirst(_leadingPromptPattern, '');
  if (text.startsWith("'") && text.endsWith('\'"\'"\'')) {
    text = "$text''";
  }
  text = text.replaceAll('\'"\'"\'', "'");
  return _stripOuterShellQuotes(text);
}

/// Unwraps shell `-lc` invocations and outer shell quotes (`225284.PuGl.g`).
String unwrapCodexShellCommand(String rawCommand) {
  final stripped = _stripNativeCommandPrefix(rawCommand);
  if (stripped.isEmpty) {
    return '';
  }
  final normalized = _stripOuterShellQuotes(
    _normalizePromptAndQuotes(stripped),
  );
  final match = _shellLcPrefixPattern.firstMatch(normalized);
  if (match != null) {
    final inner = normalized.substring(match.end).trim();
    return _normalizePromptAndQuotes(_stripOuterShellQuotes(inner));
  }
  final rawMatch = _shellLcPrefixPattern.firstMatch(stripped);
  if (rawMatch != null) {
    final inner = stripped.substring(rawMatch.end).trim();
    return _normalizePromptAndQuotes(_stripOuterShellQuotes(inner));
  }
  return normalized;
}

/// Official expanded shell execution card (`225284.PuGl.d` + `PuGl.d.Footer`).
///
/// Renders:
/// - `8px`-radius (`rounded-lg`), `1px` `border-strong` (`shellCardBorder`)
///   elevated card frame;
/// - shell header bar (`Shell` / `bash` / `zsh` / `sh` / `cmd` / `PowerShell`);
/// - interactive `$ <unwrapped command>` block (`line-clamp-2` default,
///   click/Enter/Space expands) with hover/focus `Copy command`;
/// - `144px` (`max-h-36`) bottom-anchored (`reverse: true`) monospace output
///   viewport (`"No output"` placeholder when completed and whitespace-only)
///   with hover/focus `Copy output`;
/// - `PuGl.d.Footer` status (`✓ Success`, `Exit code {code|unknown}`, `Stopped`)
///   alongside optional Host-spooled full-output controls.
class CodexShellExecutionCard extends StatefulWidget {
  const CodexShellExecutionCard({
    super.key,
    required this.rawCommand,
    required this.output,
    this.loading = false,
    this.errorMessage,
    this.isInProgress = false,
    this.status,
    this.exitCode,
    this.storedBytesNotice,
    this.trailingFooterAction,
  });

  final String rawCommand;
  final String output;
  final bool loading;
  final String? errorMessage;
  final bool isInProgress;
  final String? status;
  final int? exitCode;
  final String? storedBytesNotice;
  final Widget? trailingFooterAction;

  @override
  State<CodexShellExecutionCard> createState() =>
      _CodexShellExecutionCardState();
}

class _CodexShellExecutionCardState extends State<CodexShellExecutionCard> {
  String? _expandedForCommand;
  bool _commandHovered = false;
  bool _commandFocused = false;
  bool _copyCommandFocused = false;
  bool _copiedCommand = false;
  bool _outputHovered = false;
  bool _copyOutputFocused = false;
  bool _copiedOutput = false;
  Timer? _copiedCommandTimer;
  Timer? _copiedOutputTimer;

  @override
  void dispose() {
    _copiedCommandTimer?.cancel();
    _copiedOutputTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopyCommand(String commandText) async {
    await Clipboard.setData(ClipboardData(text: commandText));
    if (!mounted) {
      return;
    }
    _copiedCommandTimer?.cancel();
    setState(() => _copiedCommand = true);
    _copiedCommandTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _copiedCommand = false);
      }
    });
  }

  Future<void> _handleCopyOutput() async {
    await Clipboard.setData(ClipboardData(text: widget.output));
    if (!mounted) {
      return;
    }
    _copiedOutputTimer?.cancel();
    setState(() => _copiedOutput = true);
    _copiedOutputTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _copiedOutput = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final shellLabel = detectCodexShellLabel(widget.rawCommand);
    final unwrappedCommand = unwrapCodexShellCommand(widget.rawCommand);
    final commandExpanded =
        unwrappedCommand.isNotEmpty && _expandedForCommand == unwrappedCommand;
    final showCommandBlock = unwrappedCommand.isNotEmpty;
    final showCopyCommand =
        _commandHovered ||
        _commandFocused ||
        _copyCommandFocused ||
        _copiedCommand;
    final showCopyOutput =
        _outputHovered || _copyOutputFocused || _copiedOutput;
    final statusNorm = widget.status?.trim() ?? '';
    final inProgress = widget.isInProgress || statusNorm == 'inProgress';

    return Container(
      key: const ValueKey('command-output-preview-surface'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        border: Border.all(
          color: theme.shellCardBorder,
          width: OfficialCodexTheme.shellCardBorderWidth,
        ),
        borderRadius: BorderRadius.circular(
          OfficialCodexTheme.activityRowRadius,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            key: const ValueKey('shell-card-header'),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              shellLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: OfficialCodexTheme.shellHeaderFontSize,
                height: 1.4,
                color: theme.shellDescriptionText,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (showCommandBlock)
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0.0),
              child: MouseRegion(
                onEnter: (_) => setState(() => _commandHovered = true),
                onExit: (_) => setState(() => _commandHovered = false),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 24.0),
                      child: Semantics(
                        container: true,
                        button: true,
                        expanded: commandExpanded,
                        label: '\$ $unwrappedCommand',
                        onTap: () => setState(
                          () => _expandedForCommand = unwrappedCommand,
                        ),
                        excludeSemantics: true,
                        child: FocusableActionDetector(
                          onShowFocusHighlight: (focused) {
                            if (_commandFocused != focused) {
                              setState(() => _commandFocused = focused);
                            }
                          },
                          actions: {
                            ActivateIntent: CallbackAction<ActivateIntent>(
                              onInvoke: (_) {
                                setState(
                                  () => _expandedForCommand = unwrappedCommand,
                                );
                                return null;
                              },
                            ),
                          },
                          shortcuts: const {
                            SingleActivator(LogicalKeyboardKey.enter):
                                ActivateIntent(),
                            SingleActivator(LogicalKeyboardKey.space):
                                ActivateIntent(),
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(
                              () => _expandedForCommand = unwrappedCommand,
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: CustomPaint(
                                foregroundPainter: _commandFocused
                                    ? _InlineFocusRingPainter(
                                        color: theme.focusRing,
                                      )
                                    : null,
                                child: Text.rich(
                                  key: const ValueKey(
                                    'shell-card-command-toggle',
                                  ),
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '\$ ',
                                        style: TextStyle(
                                          color: theme.textMuted,
                                        ),
                                      ),
                                      TextSpan(
                                        text: unwrappedCommand,
                                        style: TextStyle(
                                          color: theme.shellDescriptionText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: commandExpanded
                                      ? null
                                      : OfficialCodexTheme
                                            .shellCommandCollapsedLines,
                                  overflow: commandExpanded
                                      ? TextOverflow.clip
                                      : TextOverflow.ellipsis,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize:
                                        OfficialCodexTheme.shellCodeFontSize,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 0.0,
                      end: 0.0,
                      child: _ShellHoverCopyIconButton(
                        key: const ValueKey('shell-card-copy-command'),
                        tooltip: 'Copy command',
                        visible: showCopyCommand,
                        copied: _copiedCommand,
                        onFocusChanged: (focused) {
                          if (_copyCommandFocused != focused) {
                            setState(() => _copyCommandFocused = focused);
                          }
                        },
                        onPressed: () =>
                            unawaited(_handleCopyCommand(unwrappedCommand)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _buildOutputSection(
            context,
            theme: theme,
            inProgress: inProgress,
            showCopyOutput: showCopyOutput,
          ),
          _buildFooter(
            context,
            theme: theme,
            inProgress: inProgress,
            statusNorm: statusNorm,
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSection(
    BuildContext context, {
    required OfficialCodexThemeData theme,
    required bool inProgress,
    required bool showCopyOutput,
  }) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    if (widget.loading) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'Loading output preview…',
          style: textStyle?.copyWith(color: theme.shellDescriptionText),
        ),
      );
    }
    if (widget.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'Could not load output preview.',
          style: textStyle?.copyWith(color: theme.danger),
        ),
      );
    }
    final hasNonWhitespace = _nonWhitespaceOutputPattern.hasMatch(
      widget.output,
    );
    final displayOutput = hasNonWhitespace
        ? widget.output
        : (inProgress ? '' : 'No output');

    return MouseRegion(
      onEnter: (_) => setState(() => _outputHovered = true),
      onExit: (_) => setState(() => _outputHovered = false),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 20.0,
              maxHeight: OfficialCodexTheme.commandOutputPreviewHeight,
            ),
            child: SingleChildScrollView(
              key: const ValueKey('command-output-preview-scroll'),
              primary: false,
              reverse: true,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: SingleChildScrollView(
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SelectionArea(
                      child: Text(
                        displayOutput,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: OfficialCodexTheme.shellCodeFontSize,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                          color: theme.shellDescriptionText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 2.0,
            end: 10.0,
            child: _ShellHoverCopyIconButton(
              key: const ValueKey('shell-card-copy-output'),
              tooltip: 'Copy output',
              visible: showCopyOutput,
              copied: _copiedOutput,
              onFocusChanged: (focused) {
                if (_copyOutputFocused != focused) {
                  setState(() => _copyOutputFocused = focused);
                }
              },
              onPressed: () => unawaited(_handleCopyOutput()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context, {
    required OfficialCodexThemeData theme,
    required bool inProgress,
    required String statusNorm,
  }) {
    final footerStyle = TextStyle(
      fontSize: OfficialCodexTheme.activityChatFontSize,
      height: OfficialCodexTheme.activityChatLineHeight,
      color: theme.textMuted,
    );
    final noticeStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: theme.textSecondary);

    Widget? statusWidget;
    if (!inProgress) {
      if (statusNorm == 'interrupted') {
        statusWidget = Text(
          'Stopped',
          key: const ValueKey('shell-card-status-footer'),
          style: footerStyle,
        );
      } else if (widget.exitCode != null) {
        final isSuccess =
            widget.exitCode == 0 &&
            statusNorm != 'failed' &&
            statusNorm != 'declined';
        if (isSuccess) {
          statusWidget = _buildSuccessStatus(footerStyle, theme);
        } else {
          final codeText = widget.exitCode == 0
              ? 'unknown'
              : widget.exitCode.toString();
          statusWidget = Text(
            'Exit code $codeText',
            key: const ValueKey('shell-card-status-footer'),
            style: footerStyle,
          );
        }
      } else if (statusNorm == 'completed') {
        statusWidget = _buildSuccessStatus(footerStyle, theme);
      } else if (statusNorm == 'failed' || statusNorm == 'declined') {
        statusWidget = Text(
          'Exit code unknown',
          key: const ValueKey('shell-card-status-footer'),
          style: footerStyle,
        );
      }
    }

    final hasLeadingControls =
        widget.storedBytesNotice != null || widget.trailingFooterAction != null;
    if (!hasLeadingControls && statusWidget == null) {
      return const Padding(
        key: ValueKey('shell-card-footer'),
        padding: EdgeInsets.fromLTRB(10.0, 2.0, 10.0, 4.0),
        child: SizedBox(height: 4.0),
      );
    }

    return Padding(
      key: const ValueKey('shell-card-footer'),
      padding: const EdgeInsets.fromLTRB(10.0, 2.0, 10.0, 4.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leadingChildren = <Widget>[
            if (widget.storedBytesNotice != null)
              Text(widget.storedBytesNotice!, style: noticeStyle),
            if (widget.trailingFooterAction != null)
              widget.trailingFooterAction!,
          ];
          if (leadingChildren.isEmpty) {
            return Align(
              alignment: AlignmentDirectional.centerEnd,
              child: statusWidget,
            );
          }
          if (statusWidget == null) {
            return Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: leadingChildren,
            );
          }
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8.0,
            runSpacing: 4.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: leadingChildren,
              ),
              statusWidget,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSuccessStatus(
    TextStyle footerStyle,
    OfficialCodexThemeData theme,
  ) => Row(
    key: const ValueKey('shell-card-status-footer'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.check_rounded,
        size: OfficialCodexTheme.activityInlineIconSize,
        color: theme.textMuted,
      ),
      const SizedBox(width: 4.0),
      Text('Success', style: footerStyle),
    ],
  );
}

/// Inline `+A -D` diff stats accessory (`225284.O3Io.ap` + `x8co`
/// `variant: "agent-activity"`, placed in the `152406.jKy0.A` accessory slot).
class CodexInlineDiffStatsAccessory extends StatelessWidget {
  const CodexInlineDiffStatsAccessory({
    super.key,
    required this.additions,
    required this.deletions,
    this.fontSize = OfficialCodexTheme.chatCodeFontSize,
  });

  final int additions;
  final int deletions;
  final double fontSize;

  static String? semanticLabelFor(int additions, int deletions) {
    final parts = <String>[
      if (additions > 0) '+$additions',
      if (deletions > 0) '-$deletions',
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (additions <= 0 && deletions <= 0) {
      return const SizedBox.shrink();
    }
    final theme = OfficialCodexTheme.of(context);
    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: OfficialCodexTheme.activityChatLineHeight,
      fontWeight: FontWeight.w400,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (additions > 0)
          Text(
            '+$additions',
            maxLines: 1,
            style: baseStyle.copyWith(color: theme.diffAddedText),
          ),
        if (additions > 0 && deletions > 0) const SizedBox(width: 4.0),
        if (deletions > 0)
          Text(
            '-$deletions',
            maxLines: 1,
            style: baseStyle.copyWith(color: theme.diffRemovedText),
          ),
      ],
    );
  }
}

/// Bounded inline patch preview card (`225284.O3Io.af` / `ag`, `max-h-60` =
/// `240px`) disclosed beneath an inline `Edited a file` / `Edited N files`
/// activity row when the active `DiffSnapshot` matches the row's `turnId`.
class CodexInlinePatchPreviewCard extends StatelessWidget {
  const CodexInlinePatchPreviewCard({
    super.key,
    required this.files,
    this.truncated = false,
  });

  static const double maxViewportHeight = 240.0;
  static const int maxRenderedLinesPerFile = 80;

  final List<DiffFile> files;
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = OfficialCodexTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start:
            OfficialCodexTheme.activityInlineIconSize +
            OfficialCodexTheme.activityInlineIconGap,
        top: 6.0,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: maxViewportHeight),
        child: files.length == 1 && !truncated
            ? _SingleFilePatchCard(file: files.single, expandBodyScroll: true)
            : ListView.separated(
                key: const ValueKey('inline-patch-files-scroll'),
                primary: false,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: files.length + (truncated ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 6.0),
                itemBuilder: (context, index) {
                  if (index >= files.length) {
                    return Text(
                      'Showing bounded diff preview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: OfficialCodexTheme.chatCodeFontSize,
                        height: OfficialCodexTheme.activityChatLineHeight,
                        color: theme.textMuted,
                      ),
                    );
                  }
                  return _SingleFilePatchCard(
                    file: files[index],
                    expandBodyScroll: false,
                  );
                },
              ),
      ),
    );
  }
}

class _SingleFilePatchCard extends StatefulWidget {
  const _SingleFilePatchCard({
    required this.file,
    required this.expandBodyScroll,
  });

  final DiffFile file;
  final bool expandBodyScroll;

  @override
  State<_SingleFilePatchCard> createState() => _SingleFilePatchCardState();
}

class _SingleFilePatchCardState extends State<_SingleFilePatchCard> {
  bool _hovered = false;
  bool _copyFocused = false;
  bool _copied = false;
  Timer? _copiedResetTimer;

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopyDiff() async {
    final payload = widget.file.lines.isEmpty
        ? widget.file.path
        : widget.file.lines.join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: payload));
    } on Object {
      return;
    }
    if (!mounted) {
      return;
    }
    _copiedResetTimer?.cancel();
    setState(() => _copied = true);
    _copiedResetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final file = widget.file;
    final visibleLines =
        file.lines.length > CodexInlinePatchPreviewCard.maxRenderedLinesPerFile
        ? file.lines.sublist(
            0,
            CodexInlinePatchPreviewCard.maxRenderedLinesPerFile,
          )
        : file.lines;
    final isTruncated =
        file.truncated ||
        file.lines.length > CodexInlinePatchPreviewCard.maxRenderedLinesPerFile;
    const codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: OfficialCodexTheme.chatCodeFontSize,
      height: 1.45,
    );

    Widget buildLine(String line) {
      final isAdd = line.startsWith('+') && !line.startsWith('+++');
      final isDel = line.startsWith('-') && !line.startsWith('---');
      final isHunk = line.startsWith('@@');
      final bg = isAdd
          ? theme.diffAddedFill
          : isDel
          ? theme.diffRemovedFill
          : Colors.transparent;
      final fg = isAdd
          ? theme.diffAddedText
          : isDel
          ? theme.diffRemovedText
          : isHunk
          ? theme.textMuted
          : theme.textSecondary;
      return ColoredBox(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 1.0),
          child: Text(
            line.isEmpty ? ' ' : line,
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: codeStyle.copyWith(color: fg),
          ),
        ),
      );
    }

    final Widget body;
    if (visibleLines.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Text(
          'No line preview available',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: codeStyle.copyWith(color: theme.textMuted),
        ),
      );
    } else if (widget.expandBodyScroll) {
      body = Flexible(
        child: ListView.builder(
          key: ValueKey('inline-patch-lines-${file.path}'),
          primary: false,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          itemCount: visibleLines.length + (isTruncated ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= visibleLines.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 2.0,
                ),
                child: Text(
                  'Showing bounded diff preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: codeStyle.copyWith(color: theme.textMuted),
                ),
              );
            }
            return buildLine(visibleLines[index]);
          },
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in visibleLines) buildLine(line),
            if (isTruncated)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 2.0,
                ),
                child: Text(
                  'Showing bounded diff preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: codeStyle.copyWith(color: theme.textMuted),
                ),
              ),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: theme.elevatedSurface,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: theme.hairlineBorder,
            width: OfficialCodexTheme.hairlineBorderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 4.0,
              ),
              decoration: BoxDecoration(
                color: theme.hoverTint,
                border: Border(
                  bottom: BorderSide(
                    color: theme.hairlineBorder,
                    width: OfficialCodexTheme.hairlineBorderWidth,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: CodexTooltip(
                            message: file.path,
                            child: Text(
                              file.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: codeStyle.copyWith(
                                color: theme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        if (file.additions > 0 || file.deletions > 0) ...[
                          const SizedBox(width: 6.0),
                          CodexInlineDiffStatsAccessory(
                            additions: file.additions,
                            deletions: file.deletions,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  _ShellHoverCopyIconButton(
                    key: ValueKey('inline-patch-copy-${file.path}'),
                    tooltip: _copied ? 'Copied' : 'Copy diff',
                    visible: _hovered || _copyFocused || _copied,
                    copied: _copied,
                    onFocusChanged: (focused) {
                      if (_copyFocused != focused) {
                        setState(() => _copyFocused = focused);
                      }
                    },
                    onPressed: () => unawaited(_handleCopyDiff()),
                  ),
                ],
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }
}

class _ShellHoverCopyIconButton extends StatefulWidget {
  const _ShellHoverCopyIconButton({
    super.key,
    required this.tooltip,
    required this.visible,
    required this.copied,
    required this.onFocusChanged,
    required this.onPressed,
  });

  final String tooltip;
  final bool visible;
  final bool copied;
  final ValueChanged<bool> onFocusChanged;
  final VoidCallback onPressed;

  @override
  State<_ShellHoverCopyIconButton> createState() =>
      _ShellHoverCopyIconButtonState();
}

class _ShellHoverCopyIconButtonState extends State<_ShellHoverCopyIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final active = widget.visible || _hovered;
    return Opacity(
      opacity: active ? 1.0 : 0.0,
      child: CodexTooltip(
        message: widget.tooltip,
        child: Semantics(
          button: true,
          label: widget.tooltip,
          onTap: widget.onPressed,
          excludeSemantics: true,
          child: FocusableActionDetector(
            onShowFocusHighlight: widget.onFocusChanged,
            onShowHoverHighlight: (hovering) {
              if (_hovered != hovering) {
                setState(() => _hovered = hovering);
              }
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onPressed();
                  return null;
                },
              ),
            },
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 22.0,
                  height: 22.0,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _hovered ? theme.hoverTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Icon(
                    widget.copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: OfficialCodexTheme.activityInlineIconSize,
                    color: active ? theme.textPrimary : theme.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-file change operation kind (`225284.O3Io.ap`).
enum CodexFileChangeKind { add, delete, update, unknown }

/// Per-file change execution status (`225284.O3Io.ap`).
enum CodexFileChangeStatus { inProgress, applied, stopped, rejected }

/// Per-file disclosed diff body state (`225284.O3Io.af` / `ag` / `am`).
enum CodexFileDiffBodyState {
  ready,
  loading,
  empty,
  previewTooLarge,
  unavailable,
  unsupported,
}

/// Extracts the display basename of [rawPath] (`ai.Q0` in `225284.O3Io`).
String codexPathBasename(String rawPath) {
  final trimmed = rawPath.trim();
  if (trimmed.isEmpty) {
    return rawPath;
  }
  final normalized = trimmed.replaceAll(r'\', '/');
  var end = normalized.length;
  while (end > 1 && normalized.codeUnitAt(end - 1) == 0x2F) {
    end--;
  }
  final stripped = normalized.substring(0, end);
  final slash = stripped.lastIndexOf('/');
  if (slash < 0 || slash == stripped.length - 1) {
    return stripped;
  }
  return stripped.substring(slash + 1);
}

bool _isWindowsStylePath(String normalizedPath) {
  if (normalizedPath.startsWith('//')) {
    return true;
  }
  if (normalizedPath.length < 3 || normalizedPath.codeUnitAt(1) != 0x3A) {
    return false;
  }
  final drive = normalizedPath.codeUnitAt(0);
  final isLetter =
      (drive >= 0x41 && drive <= 0x5A) || (drive >= 0x61 && drive <= 0x7A);
  return isLetter && normalizedPath.codeUnitAt(2) == 0x2F;
}

String _stripTrailingPathSlashes(String normalizedPath) {
  var end = normalizedPath.length;
  final minLength =
      normalizedPath.length >= 3 && normalizedPath.codeUnitAt(1) == 0x3A
      ? 3
      : 1;
  while (end > minLength && normalizedPath.codeUnitAt(end - 1) == 0x2F) {
    end--;
  }
  return normalizedPath.substring(0, end);
}

/// Relativizes [rawPath] against [cwd] matching `182735.g3QY.ph` (`@4486914`).
///
/// Normalizes `\` to `/`, strips trailing `/` on [cwd], and removes a leading
/// `<cwd>/` prefix case-insensitively on Windows drive/UNC paths and
/// case-sensitively on POSIX paths.
String formatCodexWorkspaceRelativePath(String rawPath, {String? cwd}) {
  if (rawPath.isEmpty) {
    return rawPath;
  }
  final pathNorm = rawPath.replaceAll(r'\', '/');
  if (cwd == null || cwd.trim().isEmpty) {
    return pathNorm;
  }
  final cwdNorm = _stripTrailingPathSlashes(cwd.trim().replaceAll(r'\', '/'));
  if (cwdNorm.isEmpty) {
    return pathNorm;
  }
  final prefix = cwdNorm.endsWith('/') ? cwdNorm : '$cwdNorm/';
  final caseInsensitive =
      _isWindowsStylePath(pathNorm) || _isWindowsStylePath(cwdNorm);
  if (caseInsensitive) {
    final lowerPath = pathNorm.toLowerCase();
    final lowerPrefix = prefix.toLowerCase();
    if (lowerPath.startsWith(lowerPrefix) && pathNorm.length > prefix.length) {
      return pathNorm.substring(prefix.length);
    }
    return pathNorm;
  }
  if (pathNorm.startsWith(prefix) && pathNorm.length > prefix.length) {
    return pathNorm.substring(prefix.length);
  }
  return pathNorm;
}

/// Formats the monospace path tooltip for `225284.O3Io` (`relPath`, or
/// `relOld → relNew` when [movePath] renames/moves [path]).
String formatCodexFileChangeTooltipPath(
  String path, {
  String? movePath,
  String? cwd,
  bool pathTruncated = false,
}) {
  final relOld = formatCodexWorkspaceRelativePath(path, cwd: cwd);
  final String formatted;
  if (movePath == null || movePath.isEmpty || movePath == path) {
    formatted = relOld;
  } else {
    final relNew = formatCodexWorkspaceRelativePath(movePath, cwd: cwd);
    formatted = '$relOld → $relNew';
  }
  if (pathTruncated && !formatted.endsWith('…')) {
    return '$formatted…';
  }
  return formatted;
}

/// Pure presentation descriptor for a single file entry inside a `fileChange`
/// activity item (`225284.O3Io.au` -> `O3Io.ap`).
@immutable
class CodexPerFileChangeItem {
  const CodexPerFileChangeItem({
    required this.id,
    required this.path,
    this.movePath,
    this.pathTruncated = false,
    this.kind = CodexFileChangeKind.update,
    this.additions = 0,
    this.deletions = 0,
    this.bodyState = CodexFileDiffBodyState.unavailable,
    this.diffLines = const <String>[],
    this.isUnifiedDiff = true,
    this.truncated = false,
    this.copyText,
    this.onRetryPreview,
  });

  final String id;
  final String path;
  final String? movePath;
  final bool pathTruncated;
  final CodexFileChangeKind kind;
  final int additions;
  final int deletions;
  final CodexFileDiffBodyState bodyState;
  final List<String> diffLines;
  final bool isUnifiedDiff;
  final bool truncated;
  final String? copyText;
  final VoidCallback? onRetryPreview;

  String get effectivePath {
    final moved = movePath;
    return moved != null && moved.isNotEmpty ? moved : path;
  }

  String get displayName {
    final base = codexPathBasename(effectivePath);
    if (pathTruncated && !base.endsWith('…')) {
      return '$base…';
    }
    return base;
  }

  bool get showsExpandedCardHeader =>
      bodyState == CodexFileDiffBodyState.ready ||
      bodyState == CodexFileDiffBodyState.empty;
}

/// Collapsed-row `+A -D` + optional `6×6px` kind dot (`225284.O3Io.ap`
/// `T[73]..T[88]` + `--color-chart-blue` / `--color-chart-red`).
class CodexPerFileStatsAccessory extends StatelessWidget {
  const CodexPerFileStatsAccessory({
    super.key,
    required this.additions,
    required this.deletions,
    this.kind = CodexFileChangeKind.update,
  });

  static const double kindDotDiameter = 6.0;
  static const double kindDotGap = 6.0;

  final int additions;
  final int deletions;
  final CodexFileChangeKind kind;

  @override
  Widget build(BuildContext context) {
    if (additions <= 0 && deletions <= 0) {
      return const SizedBox.shrink();
    }
    final theme = OfficialCodexTheme.of(context);
    final Color? dotColor = switch (kind) {
      CodexFileChangeKind.add => OfficialCodexTheme.chartBlue.withValues(
        alpha: 0.70,
      ),
      CodexFileChangeKind.delete => theme.chartRed.withValues(alpha: 0.70),
      CodexFileChangeKind.update || CodexFileChangeKind.unknown => null,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CodexInlineDiffStatsAccessory(
          additions: additions,
          deletions: deletions,
          fontSize: OfficialCodexTheme.shellCodeFontSize,
        ),
        if (dotColor != null) ...[
          const SizedBox(width: kindDotGap),
          Container(
            key: ValueKey('o3io-kind-dot-${kind.name}'),
            width: kindDotDiameter,
            height: kindDotDiameter,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
        ],
      ],
    );
  }
}

/// Disclosed per-file diff card (`225284.O3Io.af` / `ag` / `am`, `max-h-60` =
/// `240px`, `--color-surface-tertiary` body surface).
class CodexPerFileDiffCard extends StatefulWidget {
  const CodexPerFileDiffCard({
    super.key,
    required this.item,
    this.cwd,
    this.indentStart = true,
  });

  static const double maxViewportHeight = 240.0;
  static const int maxRenderedLines = 80;
  static const double inlineStartIndent =
      OfficialCodexTheme.activityInlineIconSize +
      OfficialCodexTheme.activityInlineIconGap;

  final CodexPerFileChangeItem item;
  final String? cwd;
  final bool indentStart;

  @override
  State<CodexPerFileDiffCard> createState() => _CodexPerFileDiffCardState();
}

class _CodexPerFileDiffCardState extends State<CodexPerFileDiffCard> {
  bool _hovered = false;
  bool _copyFocused = false;
  bool _copied = false;
  Timer? _copiedResetTimer;

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopyDiff() async {
    final item = widget.item;
    final fallbackPayload = item.diffLines.isEmpty
        ? item.effectivePath
        : item.diffLines.join('\n');
    final payload = item.copyText ?? fallbackPayload;
    try {
      await Clipboard.setData(ClipboardData(text: payload));
    } on Object {
      return;
    }
    if (!mounted) {
      return;
    }
    _copiedResetTimer?.cancel();
    setState(() => _copied = true);
    _copiedResetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  Widget _buildPlaceholder(
    OfficialCodexThemeData theme, {
    required String label,
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 28.0, 8.0, 32.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: OfficialCodexTheme.activityChatFontSize,
                height: OfficialCodexTheme.activityChatLineHeight,
                color: theme.shellDescriptionText.withValues(alpha: 0.80),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8.0),
              CodexButton(
                label: 'Retry',
                variant: CodexButtonVariant.ghost,
                size: CodexButtonSize.sm,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiffLine(
    OfficialCodexThemeData theme,
    TextStyle codeStyle,
    String line, {
    required CodexFileChangeKind kind,
    required bool isUnifiedDiff,
  }) {
    final bool isAdd;
    final bool isDel;
    final bool isHunk;
    final String displayLine;
    if (!isUnifiedDiff) {
      if (kind == CodexFileChangeKind.add ||
          kind == CodexFileChangeKind.delete) {
        isAdd = kind == CodexFileChangeKind.add;
        isDel = kind == CodexFileChangeKind.delete;
        isHunk = false;
        displayLine = '${isAdd ? '+' : '-'}$line';
      } else {
        // Non-unified bodies on unknown/non-add/delete kinds stay neutral so
        // leading '-' or '+' characters are never guessed as patch signs.
        isAdd = false;
        isDel = false;
        isHunk = false;
        displayLine = line;
      }
    } else {
      isAdd = line.startsWith('+') && !line.startsWith('+++');
      isDel = line.startsWith('-') && !line.startsWith('---');
      isHunk = line.startsWith('@@');
      displayLine = line;
    }
    final bg = isAdd
        ? theme.diffAddedFill
        : isDel
        ? theme.diffRemovedFill
        : Colors.transparent;
    final fg = isAdd
        ? theme.diffAddedText
        : isDel
        ? theme.diffRemovedText
        : isHunk
        ? theme.textMuted
        : theme.textSecondary;
    return ColoredBox(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 1.0),
        child: Text(
          displayLine.isEmpty ? ' ' : displayLine,
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: codeStyle.copyWith(color: fg),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final item = widget.item;
    final tooltipPath = formatCodexFileChangeTooltipPath(
      item.path,
      movePath: item.movePath,
      cwd: widget.cwd,
      pathTruncated: item.pathTruncated,
    );
    const codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: OfficialCodexTheme.shellCodeFontSize,
      height: 1.45,
    );

    final Widget cardBody;
    switch (item.bodyState) {
      case CodexFileDiffBodyState.previewTooLarge:
        cardBody = _buildPlaceholder(theme, label: 'Diff too large to preview');
      case CodexFileDiffBodyState.unavailable:
        cardBody = _buildPlaceholder(
          theme,
          label: 'Diff preview unavailable',
          onRetry: item.onRetryPreview,
        );
      case CodexFileDiffBodyState.unsupported:
        cardBody = _buildPlaceholder(theme, label: 'Diff preview unsupported');
      case CodexFileDiffBodyState.loading:
        cardBody = _buildPlaceholder(theme, label: 'Loading diff preview…');
      case CodexFileDiffBodyState.empty:
        cardBody = _buildPlaceholder(
          theme,
          label: item.kind == CodexFileChangeKind.delete
              ? 'Contents deleted'
              : 'No changes',
        );
      case CodexFileDiffBodyState.ready:
        if (item.diffLines.isEmpty) {
          cardBody = _buildPlaceholder(
            theme,
            label: item.kind == CodexFileChangeKind.delete
                ? 'Contents deleted'
                : 'No changes',
          );
        } else {
          final visibleLines =
              item.diffLines.length > CodexPerFileDiffCard.maxRenderedLines
              ? item.diffLines.sublist(0, CodexPerFileDiffCard.maxRenderedLines)
              : item.diffLines;
          final isTruncated =
              item.truncated ||
              item.diffLines.length > CodexPerFileDiffCard.maxRenderedLines;
          cardBody = ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: CodexPerFileDiffCard.maxViewportHeight,
            ),
            child: ListView.builder(
              key: ValueKey('o3io-diff-scroll-${item.id}'),
              primary: false,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              itemCount: visibleLines.length + (isTruncated ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= visibleLines.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      'Showing bounded diff preview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: codeStyle.copyWith(color: theme.textMuted),
                    ),
                  );
                }
                return _buildDiffLine(
                  theme,
                  codeStyle,
                  visibleLines[index],
                  kind: item.kind,
                  isUnifiedDiff: item.isUnifiedDiff,
                );
              },
            ),
          );
        }
    }

    final showsHeader = item.showsExpandedCardHeader;
    final canCopy =
        showsHeader &&
        item.bodyState == CodexFileDiffBodyState.ready &&
        (item.diffLines.isNotEmpty ||
            (item.copyText != null && item.copyText!.isNotEmpty));

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: widget.indentStart ? CodexPerFileDiffCard.inlineStartIndent : 0,
        top: 6.0,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          key: ValueKey('o3io-diff-card-${item.id}'),
          decoration: BoxDecoration(
            color: theme.shellBackground,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: theme.hairlineBorder,
              width: OfficialCodexTheme.hairlineBorderWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showsHeader)
                Container(
                  key: ValueKey('o3io-diff-header-${item.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: theme.hoverTint,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.hairlineBorder,
                        width: OfficialCodexTheme.hairlineBorderWidth,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: CodexTooltip(
                                message: tooltipPath,
                                monospace: true,
                                child: Text(
                                  item.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: codeStyle.copyWith(
                                    color: theme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            if (item.additions > 0 || item.deletions > 0) ...[
                              const SizedBox(width: 6.0),
                              CodexInlineDiffStatsAccessory(
                                additions: item.additions,
                                deletions: item.deletions,
                                fontSize: OfficialCodexTheme.shellCodeFontSize,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canCopy) ...[
                        const SizedBox(width: 6.0),
                        _ShellHoverCopyIconButton(
                          key: ValueKey('o3io-diff-copy-${item.id}'),
                          tooltip: _copied ? 'Copied' : 'Copy diff',
                          visible: _hovered || _copyFocused || _copied,
                          copied: _copied,
                          onFocusChanged: (focused) {
                            if (_copyFocused != focused) {
                              setState(() => _copyFocused = focused);
                            }
                          },
                          onPressed: () => unawaited(_handleCopyDiff()),
                        ),
                      ],
                    ],
                  ),
                ),
              cardBody,
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-file inline activity row (`225284.O3Io.ap` -> `152406.BI7J.o`).
///
/// Translates the official verb matrix (`Creating` / `Created` / `Stopped
/// creating` / `Rejected`, `Deleting` / `Deleted` / `Stopped deleting` /
/// `Rejected`, `Editing` / `Edited` / `Stopped editing` / `Rejected`), swaps
/// the expanded header to `Created file` / `Deleted file` / `Edited file` only
/// when the inner `af` filename card header is rendered (`ready` / `empty`),
/// and hides the collapsed `+A -D` + `6×6px` dot accessory while that card
/// header is visible so line counts are never duplicated.
class CodexPerFileChangeRow extends StatelessWidget {
  const CodexPerFileChangeRow({
    super.key,
    required this.item,
    this.status = CodexFileChangeStatus.applied,
    this.cwd,
    this.leadingIcon,
    this.showDiffDetails = true,
    this.isExpanded = false,
    this.onToggle,
    this.indentCardStart = true,
  });

  final CodexPerFileChangeItem item;
  final CodexFileChangeStatus status;
  final String? cwd;
  final Widget? leadingIcon;
  final bool showDiffDetails;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final bool indentCardStart;

  static String verbPrefixFor(
    CodexFileChangeKind kind,
    CodexFileChangeStatus status,
  ) {
    return switch (kind) {
      CodexFileChangeKind.add => switch (status) {
        CodexFileChangeStatus.inProgress => 'Creating ',
        CodexFileChangeStatus.stopped => 'Stopped creating ',
        CodexFileChangeStatus.rejected => 'Rejected ',
        CodexFileChangeStatus.applied => 'Created ',
      },
      CodexFileChangeKind.delete => switch (status) {
        CodexFileChangeStatus.inProgress => 'Deleting ',
        CodexFileChangeStatus.stopped => 'Stopped deleting ',
        CodexFileChangeStatus.rejected => 'Rejected ',
        CodexFileChangeStatus.applied => 'Deleted ',
      },
      CodexFileChangeKind.update ||
      CodexFileChangeKind.unknown => switch (status) {
        CodexFileChangeStatus.inProgress => 'Editing ',
        CodexFileChangeStatus.stopped => 'Stopped editing ',
        CodexFileChangeStatus.rejected => 'Rejected ',
        CodexFileChangeStatus.applied => 'Edited ',
      },
    };
  }

  static String expandedGenericTitleFor(CodexFileChangeKind kind) {
    return switch (kind) {
      CodexFileChangeKind.add => 'Created file',
      CodexFileChangeKind.delete => 'Deleted file',
      CodexFileChangeKind.update ||
      CodexFileChangeKind.unknown => 'Edited file',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final canDisclose = showDiffDetails && onToggle != null;
    final effectiveExpanded = canDisclose && isExpanded;
    final usesGenericTitle =
        effectiveExpanded &&
        status == CodexFileChangeStatus.applied &&
        item.showsExpandedCardHeader;
    final displayName = item.displayName;
    final verbPrefix = verbPrefixFor(item.kind, status);
    final visibleSummary = usesGenericTitle
        ? expandedGenericTitleFor(item.kind)
        : '$verbPrefix$displayName';
    final tooltipPath = formatCodexFileChangeTooltipPath(
      item.path,
      movePath: item.movePath,
      cwd: cwd,
      pathTruncated: item.pathTruncated,
    );
    final showRowStats =
        !usesGenericTitle && (item.additions > 0 || item.deletions > 0);
    final statsSemantic = showRowStats
        ? CodexInlineDiffStatsAccessory.semanticLabelFor(
            item.additions,
            item.deletions,
          )
        : null;
    final semanticLabel = canDisclose
        ? <String>[
            'Toggle diff for $displayName',
            visibleSummary,
            ?statsSemantic,
          ].join(', ')
        : null;

    final header = CodexInlineActivityHeader(
      key: ValueKey('o3io-row-header-${item.id}'),
      label: visibleSummary,
      leadingIcon:
          leadingIcon ??
          const Icon(
            Icons.insert_drive_file_outlined,
            size: OfficialCodexTheme.activityInlineIconSize,
          ),
      hasDisclosure: canDisclose,
      isExpanded: effectiveExpanded,
      onToggle: canDisclose ? onToggle : null,
      semanticLabelOverride: semanticLabel,
      accessory: showRowStats
          ? CodexPerFileStatsAccessory(
              additions: item.additions,
              deletions: item.deletions,
              kind: item.kind,
            )
          : null,
      accessorySemanticLabel: statsSemantic,
      labelBuilder: usesGenericTitle
          ? null
          : (context, active, effectiveTextColor) {
              final fileColor = active
                  ? theme.textPrimary
                  : theme.activityChildText;
              final baseStyle = TextStyle(
                fontSize: OfficialCodexTheme.activityChatFontSize,
                height: OfficialCodexTheme.activityChatLineHeight,
                fontWeight: FontWeight.w400,
                color: effectiveTextColor,
              );
              return CodexTooltip(
                message: tooltipPath,
                monospace: true,
                child: Text.rich(
                  TextSpan(
                    text: verbPrefix,
                    children: [
                      TextSpan(
                        text: displayName,
                        style: TextStyle(
                          color: fileColor,
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted,
                          decorationColor: fileColor.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: baseStyle,
                ),
              );
            },
    );

    if (!effectiveExpanded) {
      return Align(alignment: AlignmentDirectional.centerStart, child: header);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(alignment: AlignmentDirectional.centerStart, child: header),
        CodexPerFileDiffCard(
          item: item,
          cwd: cwd,
          indentStart: indentCardStart,
        ),
      ],
    );
  }
}

/// Multi-file `fileChange` container (`225284.O3Io.au` +
/// `e77f816560c6.css` `--conversation-patch-file-gap`).
///
/// Renders one independent [CodexPerFileChangeRow] per entry in [files] with
/// `16px` gap on the standalone timeline and `4px` gap inside a grouped
/// activity block (`225284 @ 143050`).
class CodexFileChangeActivityList extends StatelessWidget {
  const CodexFileChangeActivityList({
    super.key,
    required this.files,
    this.status = CodexFileChangeStatus.applied,
    this.cwd,
    this.grouped = false,
    this.showDiffDetails = true,
    this.expandedFileIds = const <String>{},
    this.onToggleFile,
    this.totalFileCount,
    this.leadingIcon,
  });

  final List<CodexPerFileChangeItem> files;
  final CodexFileChangeStatus status;
  final String? cwd;
  final bool grouped;
  final bool showDiffDetails;
  final Set<String> expandedFileIds;
  final ValueChanged<CodexPerFileChangeItem>? onToggleFile;
  final int? totalFileCount;
  final Widget? leadingIcon;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = OfficialCodexTheme.of(context);
    final gap = grouped
        ? OfficialCodexTheme.conversationGroupedItemGap
        : OfficialCodexTheme.conversationItemGap;
    final omittedCount =
        totalFileCount != null && totalFileCount! > files.length
        ? totalFileCount! - files.length
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < files.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          CodexPerFileChangeRow(
            key: ValueKey('o3io-file-row-${files[i].id}'),
            item: files[i],
            status: status,
            cwd: cwd,
            leadingIcon: leadingIcon,
            showDiffDetails: showDiffDetails,
            isExpanded: expandedFileIds.contains(files[i].id),
            onToggle: showDiffDetails && onToggleFile != null
                ? () => onToggleFile!(files[i])
                : null,
          ),
        ],
        if (omittedCount > 0) ...[
          SizedBox(height: gap),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: CodexPerFileDiffCard.inlineStartIndent,
            ),
            child: Text(
              '+$omittedCount more ${omittedCount == 1 ? 'file' : 'files'} '
              'not shown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: OfficialCodexTheme.shellCodeFontSize,
                height: OfficialCodexTheme.activityChatLineHeight,
                color: theme.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
