import 'package:flutter/material.dart';

import '../theme/official_codex_theme.dart';

/// Semantic floating composer container primitive conforming to official
/// Codex desktop specifications (704px max width, 24px radius, hairline border, Tier 2 surface).
class CodexComposer extends StatelessWidget {
  const CodexComposer({
    super.key,
    this.surfaceKey,
    required this.child,
    this.maxWidth = OfficialCodexTheme.maxContentWidth,
    this.radius = OfficialCodexTheme.composerRadius,
    this.isFocused = false,
    this.padding = const EdgeInsets.fromLTRB(14.0, 10.0, 8.0, 8.0),
  });

  final Key? surfaceKey;
  final Widget child;
  final double maxWidth;
  final double radius;
  final bool isFocused;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final isDark = theme.isDark;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AnimatedContainer(
        key: surfaceKey,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: padding,
        decoration: BoxDecoration(
          color: theme.workspaceBackground,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isFocused ? theme.focusRing : theme.hairlineBorder,
            width: isFocused ? 1.5 : OfficialCodexTheme.hairlineBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x33000000) : const Color(0x14000000),
              blurRadius: 16.0,
              offset: const Offset(0, 4.0),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
