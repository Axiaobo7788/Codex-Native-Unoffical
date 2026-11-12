import 'dart:async';

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
    this.verbLength,
    this.icon,
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
class CodexInlineActivityHeader extends StatefulWidget {
  const CodexInlineActivityHeader({
    super.key,
    required this.label,
    this.verbLength,
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
  final int? verbLength;
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
              _buildLabelText(
                theme: theme,
                active: active,
                effectiveTextColor: effectiveTextColor,
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
