import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/official_codex_theme.dart';
import '../theme_tokens.dart';
import 'codex_tooltip.dart';

/// Semantic navigation and thread row primitive conforming to official
/// Codex desktop specifications (36px height, 10px radius, 0 10px padding, no ink ripple).
class CodexSidebarRow extends StatefulWidget {
  const CodexSidebarRow({
    super.key,
    this.containerKey,
    required this.title,
    this.leading,
    this.trailing,
    this.trailingBuilder,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.height = OfficialCodexTheme.navRowHeight,
    this.radius = 10.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10.0),
    this.tooltip,
  });

  final Key? containerKey;
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final Widget Function(BuildContext context, bool isHovered)? trailingBuilder;
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
    final palette = ThemeTokens.of(context);

    Color background = Colors.transparent;
    if (widget.selected) {
      background = palette.selected;
    } else if (_isHovered) {
      background = palette.hover;
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
            () {
              final trailing = widget.trailingBuilder != null
                  ? widget.trailingBuilder!(context, _isHovered)
                  : widget.trailing;
              if (trailing != null) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const SizedBox(width: 6.0), trailing],
                );
              }
              return const SizedBox.shrink();
            }(),
          ],
        ),
      ),
    );

    content = AnimatedContainer(
      key: widget.containerKey,
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

    Widget result = Semantics(
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
            onEnter: (_) => _handleHover(true),
            onExit: (_) => _handleHover(false),
            cursor: widget.onTap != null
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: content,
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      result = CodexTooltip(message: widget.tooltip!, child: result);
    }

    return result;
  }
}
