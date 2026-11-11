import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.icon,
    this.statusText,
    this.isRunning = false,
    this.isError = false,
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
  final Widget? icon;
  final String? statusText;
  final bool isRunning;
  final bool isError;
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
        leadingIcon: icon ?? const Icon(Icons.terminal_rounded),
        restingTextColor: isError ? theme.danger : theme.activitySummaryText,
        restingIconColor: isError ? theme.danger : theme.activitySummaryText,
        hoverPromotesToPrimary: !isError,
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
                  color: isError ? theme.danger : theme.textMuted,
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
/// Renders a natural-height, self-start inline row (`13.5px` / `20px` scalable
/// chat line box, `6px` icon-to-label gap, `4px` label-to-chevron gap). Only
/// becomes an interactive button with hover ink promotion and `14px` chevron
/// when [hasDisclosure] is `true`.
class CodexInlineActivityHeader extends StatefulWidget {
  const CodexInlineActivityHeader({
    super.key,
    required this.label,
    this.leadingIcon,
    this.restingTextColor,
    this.restingIconColor,
    this.hoverPromotesToPrimary = true,
    this.statusText,
    this.hasDisclosure = false,
    this.isExpanded = false,
    this.onToggle,
    this.disclosureTooltip,
    this.customTextWidget,
  });

  final String label;
  final Widget? leadingIcon;
  final Color? restingTextColor;
  final Color? restingIconColor;
  final bool hoverPromotesToPrimary;
  final String? statusText;
  final bool hasDisclosure;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final String? disclosureTooltip;
  final Widget? customTextWidget;

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
              widget.customTextWidget ??
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: OfficialCodexTheme.activityChatFontSize,
                  height: OfficialCodexTheme.activityChatLineHeight,
                  fontWeight: FontWeight.w400,
                  color: effectiveTextColor,
                ),
              ),
        ),
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
    final semanticLabel = hasStatus
        ? '${widget.label}, ${widget.statusText!}'
        : widget.label;
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
/// Renders a backgroundless inline disclosure button (`13.5px` / `20px`
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
