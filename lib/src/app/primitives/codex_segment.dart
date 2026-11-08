import 'package:flutter/material.dart';

import '../theme/official_codex_theme.dart';

class CodexSegmentItem<T> {
  const CodexSegmentItem({
    required this.value,
    required this.label,
    this.icon,
    this.tooltip,
  });

  final T value;
  final String label;
  final Widget? icon;
  final String? tooltip;
}

/// Semantic segmented control primitive conforming to official Codex desktop
/// specifications (28px height, 8px radius, sliding active indicator, no ink ripples).
class CodexSegment<T> extends StatelessWidget {
  const CodexSegment({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<CodexSegmentItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final isDark = theme.isDark;

    return Container(
      height: 28.0,
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEAEAEA),
        borderRadius: BorderRadius.circular(OfficialCodexTheme.segmentRadius),
        border: Border.all(
          color: theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            _SegmentOptionWidget<T>(
              item: item,
              isSelected: item.value == selectedValue,
              onTap: () => onSelected(item.value),
            ),
        ],
      ),
    );
  }
}

class _SegmentOptionWidget<T> extends StatefulWidget {
  const _SegmentOptionWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final CodexSegmentItem<T> item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SegmentOptionWidget<T>> createState() =>
      _SegmentOptionWidgetState<T>();
}

class _SegmentOptionWidgetState<T> extends State<_SegmentOptionWidget<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final isDark = theme.isDark;

    Color background = Colors.transparent;
    if (widget.isSelected) {
      background = isDark ? const Color(0xFF2F2F2F) : const Color(0xFFFFFFFF);
    } else if (_isHovered) {
      background = theme.hoverTint;
    }

    final textColor = widget.isSelected
        ? theme.textPrimary
        : (_isHovered ? theme.textPrimary : theme.textSecondary);

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6.0),
        boxShadow: widget.isSelected
            ? [
                BoxShadow(
                  color: isDark
                      ? const Color(0x33000000)
                      : const Color(0x14000000),
                  blurRadius: 4.0,
                  offset: const Offset(0, 1.0),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.item.icon != null) ...[
            IconTheme(
              data: IconThemeData(color: textColor, size: 13.0),
              child: widget.item.icon!,
            ),
            const SizedBox(width: 4.0),
          ],
          Text(
            widget.item.label,
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.w400,
              color: textColor,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}
