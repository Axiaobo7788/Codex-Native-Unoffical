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
    this.useDesktopSurface = false,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(14.0, 10.0, 8.0, 8.0),
  });

  final Key? surfaceKey;
  final Widget child;
  final double maxWidth;
  final double radius;
  final bool isFocused;
  final bool showFocusBorder;
  final bool useDesktopSurface;
  final Color? backgroundColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final isDark = theme.isDark;
    final highContrast = MediaQuery.highContrastOf(context);
    final paintFocusBorder = isFocused && (showFocusBorder || highContrast);

    final Color resolvedColor;
    final BoxBorder resolvedBorder;
    final List<BoxShadow> resolvedShadows;
    if (useDesktopSurface) {
      resolvedColor = backgroundColor ?? theme.composerSurface;
      if (paintFocusBorder) {
        resolvedBorder = Border.all(color: theme.focusRing, width: 1.5);
      } else if (highContrast) {
        resolvedBorder = Border.all(color: theme.textPrimary, width: 1.0);
      } else if (isDark) {
        resolvedBorder = Border.all(
          color: OfficialCodexTheme.darkComposerElevationBorder,
          width: 1.0,
        );
      } else {
        resolvedBorder = Border.all(
          color: OfficialCodexTheme.lightComposerElevationBorder,
          width: 1.0,
        );
      }
      if (highContrast || isDark) {
        resolvedShadows = const [];
      } else {
        final compactViewport =
            MediaQuery.sizeOf(context).width <
            OfficialCodexTheme.composerSingleLineBreakpoint;
        resolvedShadows = compactViewport
            ? OfficialCodexTheme.lightComposerCompactShadows
            : OfficialCodexTheme.lightComposerShadows;
      }
    } else {
      resolvedColor = backgroundColor ?? theme.elevatedSurface;
      resolvedBorder = Border.all(
        color: paintFocusBorder ? theme.focusRing : theme.hairlineBorder,
        width: paintFocusBorder ? 1.5 : 1.0,
      );
      resolvedShadows = [
        BoxShadow(
          color: isDark ? const Color(0x24000000) : const Color(0x0A000000),
          blurRadius: 8.0,
          offset: const Offset(0, 2.0),
        ),
      ];
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AnimatedContainer(
        key: surfaceKey,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: padding,
        decoration: BoxDecoration(
          color: resolvedColor,
          borderRadius: BorderRadius.circular(radius),
          border: resolvedBorder,
          boxShadow: resolvedShadows,
        ),
        child: child,
      ),
    );
  }
}
