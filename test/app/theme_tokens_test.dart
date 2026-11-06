import 'package:codex_native_unofficial/src/app/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Codex themes use explicit palettes without seed-derived colors', () {
    final light = ThemeTokens.lightTheme;
    final dark = ThemeTokens.darkTheme;
    final lightPalette = light.extension<CodexPalette>();
    final darkPalette = dark.extension<CodexPalette>();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(lightPalette, same(CodexPalette.light));
    expect(darkPalette, same(CodexPalette.dark));
    expect(light.colorScheme.primary, CodexPalette.light.accent);
    expect(dark.colorScheme.primary, CodexPalette.dark.accent);
    expect(light.scaffoldBackgroundColor, CodexPalette.light.canvas);
    expect(dark.scaffoldBackgroundColor, CodexPalette.dark.canvas);
    expect(CodexPalette.light.sidebar, isNot(CodexPalette.light.canvas));
    expect(CodexPalette.dark.userBubble, isNot(CodexPalette.dark.canvas));
  });

  testWidgets('semantic palette follows the active application theme', (
    tester,
  ) async {
    late CodexPalette palette;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeTokens.lightTheme,
        home: Builder(
          builder: (context) {
            palette = ThemeTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(palette, same(CodexPalette.light));
  });
}
