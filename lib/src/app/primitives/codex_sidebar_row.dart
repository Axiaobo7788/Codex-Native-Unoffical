import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/official_codex_theme.dart';

/// Semantic navigation and thread row primitive conforming to official
/// Codex desktop specifications (36px height, 10px radius, 0 10px padding, no ink ripple).
class CodexSidebarRow extends StatefulWidget {
  const CodexSidebarRow({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.height = OfficialCodexTheme.navRowHeight,
    this.radius = 10.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10.0),
    this.tooltip,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double height;
  final double radius;
  final EdgeInsets padding;
  final String? tooltip;

  @override
  State<CodexSidebarRow> createState() => _CodexSidebarRowState();
}

class _CodexSidebarRowState extends State<CodexSidebarRow> {
  bool _isHovered = false;
  bool _isFocused = false;

  void _handleHover(bool hovering) {
    if (hovering != _isHovered) {
      setState(() => _isHovered = hovering);
    }
  }

  void _handleFocus(bool focused) {
    if (focused != _isFocused) {
      setState(() => _isFocused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);

    Color background = Colors.transparent;
    if (widget.selected) {
      background = theme.selectedTint;
    } else if (_isHovered) {
      background = theme.hoverTint;
    }

    final textColor = widget.selected
        ? theme.textPrimary
        : (_isHovered ? theme.textPrimary : theme.textSecondary);

    Widget content = SizedBox(
      height: widget.height,
      child: Padding(
        padding: widget.padding,
        child: Row(
          children: [
            if (widget.leading != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: widget.selected ? theme.textPrimary : theme.textMuted,
                  size: 16.0,
                ),
                child: widget.leading!,
              ),
              const SizedBox(width: 8.0),
            ],
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.0,
                  height: 1.43,
                  fontWeight: widget.selected
                      ? FontWeight.w500
                      : FontWeight.w400,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 6.0),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );

    content = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(widget.radius),
        border: _isFocused
            ? Border.all(color: theme.focusRing, width: 1.5)
            : null,
      ),
      child: content,
    );

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.title,
      child: FocusableActionDetector(
        enabled: widget.onTap != null,
        onShowHoverHighlight: _handleHover,
        onShowFocusHighlight: _handleFocus,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: MouseRegion(
            cursor: widget.onTap != null
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: content,
          ),
        ),
      ),
    );
  }
}
