import 'package:flutter/material.dart';

import '../theme/official_codex_theme.dart';

/// Semantic floating composer surface with a bounded width and focus border.
class CodexComposer extends StatelessWidget {
  const CodexComposer({
    super.key,
    this.surfaceKey,
    required this.child,
    this.maxWidth = OfficialCodexTheme.maxContentWidth,
    this.radius = OfficialCodexTheme.composerRadius,
    this.isFocused = false,
    this.showFocusBorder = true,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(14.0, 10.0, 8.0, 8.0),
  });

  final Key? surfaceKey;
  final Widget child;
  final double maxWidth;
  final double radius;
  final bool isFocused;
  final bool showFocusBorder;
  final Color? backgroundColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final isDark = theme.isDark;
    final paintFocusBorder =
        isFocused && (showFocusBorder || MediaQuery.highContrastOf(context));

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AnimatedContainer(
        key: surfaceKey,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.elevatedSurface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: paintFocusBorder ? theme.focusRing : theme.hairlineBorder,
            width: paintFocusBorder ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x24000000) : const Color(0x0A000000),
              blurRadius: 8.0,
              offset: const Offset(0, 2.0),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
