import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/official_codex_theme.dart';

class CodexMenuItem<T> {
  const CodexMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.description,
    this.trailing,
    this.disabled = false,
  });

  final T value;
  final String label;
  final Widget? icon;
  final String? description;
  final Widget? trailing;
  final bool disabled;
}

/// Semantic desktop menu dropdown list conforming to official Codex desktop
/// specifications (item height 32px, radius 8px, container radius 16px, no ink ripples).
class CodexMenu<T> extends StatelessWidget {
  const CodexMenu({
    super.key,
    required this.items,
    this.selectedValue,
    required this.onSelected,
    this.header,
    this.width,
    this.padding = const EdgeInsets.all(6.0),
  });

  final List<CodexMenuItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T> onSelected;
  final Widget? header;
  final double? width;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 6.0,
              ),
              child: header!,
            ),
            const Divider(
              height: 1.0,
              thickness: OfficialCodexTheme.hairlineBorderWidth,
            ),
            const SizedBox(height: 4.0),
          ],
          for (final item in items)
            _CodexMenuItemWidget<T>(
              item: item,
              isSelected: item.value == selectedValue,
              onTap: item.disabled ? null : () => onSelected(item.value),
            ),
        ],
      ),
    );
  }
}

class _CodexMenuItemWidget<T> extends StatefulWidget {
  const _CodexMenuItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final CodexMenuItem<T> item;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<_CodexMenuItemWidget<T>> createState() =>
      _CodexMenuItemWidgetState<T>();
}

class _CodexMenuItemWidgetState<T> extends State<_CodexMenuItemWidget<T>> {
  bool _isHovered = false;
  bool _isFocused = false;

  void _handleHover(bool hovering) {
    if (widget.onTap != null && hovering != _isHovered) {
      setState(() => _isHovered = hovering);
    }
  }

  void _handleFocus(bool focused) {
    if (widget.onTap != null && focused != _isFocused) {
      setState(() => _isFocused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);

    Color background = Colors.transparent;
    if (widget.isSelected) {
      background = theme.selectedTint;
    } else if (_isHovered) {
      background = theme.hoverTint;
    }

    final textColor = widget.item.disabled
        ? theme.textMuted
        : (widget.isSelected ? theme.textPrimary : theme.textSecondary);

    Widget content = Container(
      height: 32.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8.0),
        border: _isFocused
            ? Border.all(color: theme.focusRing, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          if (widget.item.icon != null) ...[
            IconTheme(
              data: IconThemeData(
                color: widget.isSelected ? theme.textPrimary : theme.textMuted,
                size: 16.0,
              ),
              child: widget.item.icon!,
            ),
            const SizedBox(width: 8.0),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13.0,
                    fontWeight: widget.isSelected
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
                if (widget.item.description != null) ...[
                  Text(
                    widget.item.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textMuted, fontSize: 11.0),
                  ),
                ],
              ],
            ),
          ),
          if (widget.item.trailing != null) ...[
            const SizedBox(width: 8.0),
            widget.item.trailing!,
          ] else if (widget.isSelected) ...[
            const SizedBox(width: 8.0),
            Icon(Icons.check_rounded, size: 14.0, color: theme.textPrimary),
          ],
        ],
      ),
    );

    if (widget.item.disabled) {
      content = Opacity(opacity: 0.45, child: content);
    }

    return FocusableActionDetector(
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
        child: MouseRegion(
          cursor: widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: content,
        ),
      ),
    );
  }
}
