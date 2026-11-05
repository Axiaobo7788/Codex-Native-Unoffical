import 'package:flutter/material.dart';

abstract final class ThemeTokens {
  static const Color canvas = Color(0xFF111312);
  static const Color surface = Color(0xFF191C1A);
  static const Color surfaceRaised = Color(0xFF202421);
  static const Color border = Color(0xFF343A36);
  static const Color textPrimary = Color(0xFFE7EAE7);
  static const Color textSecondary = Color(0xFF9EA69F);
  static const Color connected = Color(0xFF62C487);
  static const Color pending = Color(0xFFE0B86B);
  static const Color error = Color(0xFFE77C7C);

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;

  static const double radiusSmall = 6;
  static const double radiusMedium = 10;

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: connected,
      brightness: Brightness.dark,
      surface: surface,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      dividerColor: border,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
      ),
    );
  }
}
