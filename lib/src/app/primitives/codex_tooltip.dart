import 'package:flutter/material.dart';

import '../theme/official_codex_theme.dart';

/// Desktop tooltip conforming to official Codex desktop specification
/// (16px pill radius, 4x10 padding, fast fade transition, non-blocking hit-test).
class CodexTooltip extends StatelessWidget {
  const CodexTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 300),
    this.monospace = false,
  });

  final String message;
  final Widget child;
  final Duration waitDuration;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return child;

    final theme = OfficialCodexTheme.of(context);
    final isDark = theme.isDark;

    return Tooltip(
      message: message,
      waitDuration: waitDuration,
      verticalOffset: 6.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFF212121),
        borderRadius: BorderRadius.circular(OfficialCodexTheme.tooltipRadius),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0x26000000),
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8.0,
            offset: Offset(0, 2.0),
          ),
        ],
      ),
      textStyle: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontFamily: monospace ? 'monospace' : null,
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        height: 1.33,
      ),
      child: child,
    );
  }
}
