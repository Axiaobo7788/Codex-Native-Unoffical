import 'package:flutter/material.dart';

@immutable
final class CodexPalette extends ThemeExtension<CodexPalette> {
  const CodexPalette({
    required this.canvas,
    required this.sidebar,
    required this.surface,
    required this.surfaceRaised,
    required this.hover,
    required this.selected,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.codeSurface,
    required this.diffAdded,
    required this.diffRemoved,
    required this.userBubble,
    required this.onUserBubble,
    required this.shadow,
  });

  final Color canvas;
  final Color sidebar;
  final Color surface;
  final Color surfaceRaised;
  final Color hover;
  final Color selected;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color codeSurface;
  final Color diffAdded;
  final Color diffRemoved;
  final Color userBubble;
  final Color onUserBubble;
  final Color shadow;

  static const light = CodexPalette(
    canvas: Color(0xFFFCFCFB),
    sidebar: Color(0xFFF3F3F1),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF8F8F7),
    hover: Color(0xFFEAEAE7),
    selected: Color(0xFFE3E3DF),
    border: Color(0xFFE2E2DE),
    borderStrong: Color(0xFFC7C7C1),
    textPrimary: Color(0xFF20201E),
    textSecondary: Color(0xFF666662),
    textMuted: Color(0xFF92928C),
    accent: Color(0xFF3E6FD8),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF2F7D4B),
    warning: Color(0xFF9A6417),
    danger: Color(0xFFB43B3B),
    codeSurface: Color(0xFF171817),
    diffAdded: Color(0xFFE5F5E9),
    diffRemoved: Color(0xFFFBE8E7),
    userBubble: Color(0xFFF0F0EC),
    onUserBubble: Color(0xFF20201E),
    shadow: Color(0x20000000),
  );

  static const dark = CodexPalette(
    canvas: Color(0xFF181918),
    sidebar: Color(0xFF202120),
    surface: Color(0xFF222321),
    surfaceRaised: Color(0xFF292A28),
    hover: Color(0xFF30312F),
    selected: Color(0xFF383936),
    border: Color(0xFF373936),
    borderStrong: Color(0xFF50524D),
    textPrimary: Color(0xFFEDEDE9),
    textSecondary: Color(0xFFB2B3AD),
    textMuted: Color(0xFF83857F),
    accent: Color(0xFF7DA2F2),
    onAccent: Color(0xFF122147),
    success: Color(0xFF70C18A),
    warning: Color(0xFFE2B86D),
    danger: Color(0xFFF08A86),
    codeSurface: Color(0xFF101110),
    diffAdded: Color(0xFF203829),
    diffRemoved: Color(0xFF422827),
    userBubble: Color(0xFF2A2B29),
    onUserBubble: Color(0xFFEDEDE9),
    shadow: Color(0x66000000),
  );

  @override
  CodexPalette copyWith({
    Color? canvas,
    Color? sidebar,
    Color? surface,
    Color? surfaceRaised,
    Color? hover,
    Color? selected,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? codeSurface,
    Color? diffAdded,
    Color? diffRemoved,
    Color? userBubble,
    Color? onUserBubble,
    Color? shadow,
  }) => CodexPalette(
    canvas: canvas ?? this.canvas,
    sidebar: sidebar ?? this.sidebar,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    hover: hover ?? this.hover,
    selected: selected ?? this.selected,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    codeSurface: codeSurface ?? this.codeSurface,
    diffAdded: diffAdded ?? this.diffAdded,
    diffRemoved: diffRemoved ?? this.diffRemoved,
    userBubble: userBubble ?? this.userBubble,
    onUserBubble: onUserBubble ?? this.onUserBubble,
    shadow: shadow ?? this.shadow,
  );

  @override
  CodexPalette lerp(covariant CodexPalette? other, double t) {
    if (other == null) {
      return this;
    }
    return CodexPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      codeSurface: Color.lerp(codeSurface, other.codeSurface, t)!,
      diffAdded: Color.lerp(diffAdded, other.diffAdded, t)!,
      diffRemoved: Color.lerp(diffRemoved, other.diffRemoved, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      onUserBubble: Color.lerp(onUserBubble, other.onUserBubble, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

abstract final class ThemeTokens {
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;

  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 18;
  static const double radiusComposer = 24;

  static const double maxContentWidth = 704;
  static const double sidebarWidth = 260;
  static const double titlebarHeight = 46;
  static const double navRowHeight = 36;
  static const double mainSurfaceRadius = 12;
  static const double hairlineBorderWidth = 0.5;

  static CodexPalette of(BuildContext context) =>
      Theme.of(context).extension<CodexPalette>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? CodexPalette.dark
          : CodexPalette.light);

  static ThemeData get lightTheme =>
      _build(CodexPalette.light, Brightness.light);

  static ThemeData get darkTheme => _build(CodexPalette.dark, Brightness.dark);

  static ThemeData _build(CodexPalette palette, Brightness brightness) {
    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: palette.accent,
            onPrimary: palette.onAccent,
            secondary: palette.accent,
            onSecondary: palette.onAccent,
            surface: palette.surface,
            onSurface: palette.textPrimary,
            error: palette.danger,
            onError: palette.surface,
          )
        : ColorScheme.light(
            primary: palette.accent,
            onPrimary: palette.onAccent,
            secondary: palette.accent,
            onSecondary: palette.onAccent,
            surface: palette.surface,
            onSurface: palette.textPrimary,
            error: palette.danger,
            onError: palette.surface,
          );
    final textTheme = TextTheme(
      headlineSmall: TextStyle(
        color: palette.textPrimary,
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.35,
      ),
      titleLarge: TextStyle(
        color: palette.textPrimary,
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
      ),
      titleMedium: TextStyle(
        color: palette.textPrimary,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: palette.textPrimary,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: palette.textPrimary,
        fontSize: 15,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: palette.textPrimary,
        fontSize: 13.5,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        color: palette.textPrimary,
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: palette.textSecondary,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: palette.textMuted,
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSmall),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      cardColor: palette.surface,
      dividerColor: palette.border,
      disabledColor: palette.textMuted.withValues(alpha: 0.55),
      focusColor: palette.accent.withValues(alpha: 0.16),
      hoverColor: palette.hover,
      highlightColor: palette.selected,
      splashColor: Colors.transparent,
      visualDensity: VisualDensity.compact,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: palette.textSecondary, size: 18),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: palette.shadow,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border),
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceRaised,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
        labelStyle: textTheme.bodySmall,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: palette.border),
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: palette.border),
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: palette.accent, width: 1.5),
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.textPrimary,
          foregroundColor: palette.canvas,
          disabledBackgroundColor: palette.border,
          disabledForegroundColor: palette.textMuted,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          shape: rounded,
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.borderStrong),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: rounded,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.textSecondary,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          shape: rounded,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.textSecondary,
          minimumSize: const Size.square(34),
          maximumSize: const Size.square(34),
          padding: const EdgeInsets.all(7),
          shape: rounded,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceRaised,
        selectedColor: palette.selected,
        side: BorderSide(color: palette.border),
        shape: rounded,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: palette.shadow,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? palette.borderStrong
              : palette.border,
        ),
        thickness: const WidgetStatePropertyAll(7),
        radius: const Radius.circular(8),
        crossAxisMargin: 2,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.textPrimary,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: palette.canvas),
        waitDuration: const Duration(milliseconds: 450),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.canvas),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
    );
  }
}
