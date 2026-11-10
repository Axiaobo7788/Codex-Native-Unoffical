import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/official_codex_theme.dart';
import 'codex_button.dart';

/// Semantic tool and command activity row primitive conforming to official
/// Codex desktop specifications (34px height, 8px radius, hairline border, monospace summary).
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

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);

    return Container(
      height: OfficialCodexTheme.activityRowHeight,
      margin: inline
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 3.0),
      padding: inline
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: inline
          ? null
          : BoxDecoration(
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
                    height: OfficialCodexTheme.workDividerHeight,
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
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 12.0,
                            color: textColor,
                            fontWeight: FontWeight.w500,
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
