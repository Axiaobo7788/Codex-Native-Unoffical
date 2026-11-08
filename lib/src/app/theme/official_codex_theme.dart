import 'package:flutter/material.dart';

/// 9 discrete interactive states for official Codex UI primitives.
enum CodexInteractiveState {
  idle,
  hover,
  pressed,
  focusVisible,
  selected,
  disabled,
  running,
  streaming,
  error,
}

/// Official design token contract and geometry constants derived from measured
/// official ChatGPT / Codex Desktop client CSS custom properties and computed styles.
abstract final class OfficialCodexTheme {
  // --- Geometries & Spacing System ---
  /// Base grid layout unit (4px / 0.25rem).
  static const double baseGrid = 4.0;

  /// Centered conversation reading column max width (44rem / 704px).
  static const double maxContentWidth = 704.0;

  /// Compact reading column width for constrained viewports (40rem / 640px).
  static const double compactContentWidth = 640.0;

  /// User message bubble max width factor within reading column (75% / ~528px).
  static const double maxUserBubbleWidthFactor = 0.75;

  /// Composer max width (44rem / 704px).
  static const double composerMaxWidth = 704.0;

  /// Floating composer corner radius (24px / 1.5rem).
  static const double composerRadius = 24.0;

  /// Floating composer pill corner radius (28px).
  static const double composerRadiusPill = 28.0;

  /// User message corner radius (18px / 1.125rem).
  static const double userMessageRadius = 18.0;

  /// Inset workspace main panel top-left corner radius (12px).
  static const double mainSurfaceRadius = 12.0;

  /// Hairline border width (0.5px, rendered 1px on 1x display).
  static const double hairlineBorderWidth = 0.5;

  /// Standard button corner radius (10px).
  static const double buttonRadius = 10.0;

  /// Compact icon button corner radius (8px).
  static const double iconButtonRadius = 8.0;

  /// Popover container corner radius (16px / 20px).
  static const double popoverRadius = 16.0;
  static const double popoverRadiusLarge = 20.0;

  /// Tooltip pill corner radius (16px).
  static const double tooltipRadius = 16.0;

  /// Segmented control pill corner radius (8px).
  static const double segmentRadius = 8.0;

  /// Sidebar default width on desktop viewports (260px).
  static const double sidebarWidth = 260.0;

  /// Sidebar resize boundaries.
  static const double sidebarMinWidth = 240.0;
  static const double sidebarMaxWidth = 520.0;

  /// Sidebar split breakpoint (760px).
  static const double splitBreakpoint = 760.0;

  /// Navigation & thread row height (36px).
  static const double navRowHeight = 36.0;

  /// App shell titlebar height on Linux/Windows (46px).
  static const double titlebarHeight = 46.0;

  /// Titlebar height on macOS (38px).
  static const double titlebarHeightMacOS = 38.0;

  /// Workspace header bar height (46px).
  static const double headerHeight = 46.0;

  /// Activity / tool summary row height (34px).
  static const double activityRowHeight = 34.0;

  /// Activity / tool card corner radius (8px).
  static const double activityRowRadius = 8.0;

  /// Turn work divider pill height (26px).
  static const double workDividerHeight = 26.0;

  /// Attachment chip height (28px).
  static const double attachmentChipHeight = 28.0;

  /// Attachment chip corner radius (10px).
  static const double attachmentChipRadius = 10.0;

  /// Circular Send/Stop button diameter (34px).
  static const double sendButtonDiameter = 34.0;

  /// Thread reading canvas horizontal gutters (24px).
  static const double threadBodyInlinePadding = 24.0;

  // --- Palette Definitions ---

  // Dark Mode Surface Hierarchy
  static const Color darkShellBackground = Color(0xFF171717); // Tier 0
  static const Color darkWorkspaceBackground = Color(0xFF212121); // Tier 1
  static const Color darkElevatedSurface = Color(0xFF2F2F2F); // Tier 2
  static const Color darkModalSurface = Color(0xFF2F2F2F); // Tier 3
  static const Color darkUserBubbleBackground = Color(0xFF2F2F2F);
  static const Color darkUserBubbleTranslucent = Color(0x14FFFFFF); // ~8% white
  static const Color darkHairlineBorder = Color(
    0x14FFFFFF,
  ); // rgba(255,255,255,0.08)
  static const Color darkFocusRing = Color(0xFF3B82F6);
  static const Color darkAccent = Color(0xFF10A37F);

  static const Color darkTextPrimary = Color(0xFFECECEC);
  static const Color darkTextSecondary = Color(0xFFB4B4B4);
  static const Color darkTextMuted = Color(0xFF8E8E8E);

  static const Color darkDiffAddedFill = Color(0xFF1E4620);
  static const Color darkDiffAddedText = Color(0xFF4ADE80);
  static const Color darkDiffRemovedFill = Color(0xFF5A1E1E);
  static const Color darkDiffRemovedText = Color(0xFFF87171);

  // Light Mode Surface Hierarchy
  static const Color lightShellBackground = Color(0xFFF9F9F9); // Tier 0
  static const Color lightWorkspaceBackground = Color(0xFFFFFFFF); // Tier 1
  static const Color lightElevatedSurface = Color(0xFFF4F4F4); // Tier 2
  static const Color lightModalSurface = Color(0xFFFFFFFF); // Tier 3
  static const Color lightUserBubbleBackground = Color(0xFFF4F4F4);
  static const Color lightUserBubbleTranslucent = Color(
    0x0D000000,
  ); // ~5% black
  static const Color lightHairlineBorder = Color(
    0x14000000,
  ); // rgba(0,0,0,0.08)
  static const Color lightFocusRing = Color(0xFF2563EB);
  static const Color lightAccent = Color(0xFF10A37F);

  static const Color lightTextPrimary = Color(0xFF0D0D0D);
  static const Color lightTextSecondary = Color(0xFF5D5D5D);
  static const Color lightTextMuted = Color(0xFF8F8F8F);

  static const Color lightDiffAddedFill = Color(0xFFDCFCE7);
  static const Color lightDiffAddedText = Color(0xFF15803D);
  static const Color lightDiffRemovedFill = Color(0xFFFEE2E2);
  static const Color lightDiffRemovedText = Color(0xFFB91C1C);

  /// Helper to retrieve the current OfficialCodexThemeData from context.
  static OfficialCodexThemeData of(BuildContext context) {
    final theme = context
        .dependOnInheritedWidgetOfExactType<_OfficialCodexThemeScope>();
    if (theme != null) {
      return theme.data;
    }
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? OfficialCodexThemeData.dark
        : OfficialCodexThemeData.light;
  }
}

/// Holds resolved theme tokens for a given brightness mode.
@immutable
final class OfficialCodexThemeData {
  const OfficialCodexThemeData({
    required this.brightness,
    required this.shellBackground,
    required this.workspaceBackground,
    required this.elevatedSurface,
    required this.modalSurface,
    required this.userBubbleBackground,
    required this.hairlineBorder,
    required this.focusRing,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.diffAddedFill,
    required this.diffAddedText,
    required this.diffRemovedFill,
    required this.diffRemovedText,
    required this.hoverTint,
    required this.pressedTint,
    required this.selectedTint,
    required this.danger,
    required this.warning,
    required this.success,
  });

  final Brightness brightness;
  final Color shellBackground;
  final Color workspaceBackground;
  final Color elevatedSurface;
  final Color modalSurface;
  final Color userBubbleBackground;
  final Color hairlineBorder;
  final Color focusRing;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color diffAddedFill;
  final Color diffAddedText;
  final Color diffRemovedFill;
  final Color diffRemovedText;
  final Color hoverTint;
  final Color pressedTint;
  final Color selectedTint;
  final Color danger;
  final Color warning;
  final Color success;

  bool get isDark => brightness == Brightness.dark;

  static const dark = OfficialCodexThemeData(
    brightness: Brightness.dark,
    shellBackground: OfficialCodexTheme.darkShellBackground,
    workspaceBackground: OfficialCodexTheme.darkWorkspaceBackground,
    elevatedSurface: OfficialCodexTheme.darkElevatedSurface,
    modalSurface: OfficialCodexTheme.darkModalSurface,
    userBubbleBackground: OfficialCodexTheme.darkUserBubbleBackground,
    hairlineBorder: OfficialCodexTheme.darkHairlineBorder,
    focusRing: OfficialCodexTheme.darkFocusRing,
    accent: OfficialCodexTheme.darkAccent,
    textPrimary: OfficialCodexTheme.darkTextPrimary,
    textSecondary: OfficialCodexTheme.darkTextSecondary,
    textMuted: OfficialCodexTheme.darkTextMuted,
    diffAddedFill: OfficialCodexTheme.darkDiffAddedFill,
    diffAddedText: OfficialCodexTheme.darkDiffAddedText,
    diffRemovedFill: OfficialCodexTheme.darkDiffRemovedFill,
    diffRemovedText: OfficialCodexTheme.darkDiffRemovedText,
    hoverTint: Color(0x14FFFFFF), // ~8% white
    pressedTint: Color(0x24FFFFFF), // ~14% white
    selectedTint: Color(0x1AFFFFFF), // ~10% white
    danger: Color(0xFFF08A86),
    warning: Color(0xFFE2B86D),
    success: Color(0xFF70C18A),
  );

  static const light = OfficialCodexThemeData(
    brightness: Brightness.light,
    shellBackground: OfficialCodexTheme.lightShellBackground,
    workspaceBackground: OfficialCodexTheme.lightWorkspaceBackground,
    elevatedSurface: OfficialCodexTheme.lightElevatedSurface,
    modalSurface: OfficialCodexTheme.lightModalSurface,
    userBubbleBackground: OfficialCodexTheme.lightUserBubbleBackground,
    hairlineBorder: OfficialCodexTheme.lightHairlineBorder,
    focusRing: OfficialCodexTheme.lightFocusRing,
    accent: OfficialCodexTheme.lightAccent,
    textPrimary: OfficialCodexTheme.lightTextPrimary,
    textSecondary: OfficialCodexTheme.lightTextSecondary,
    textMuted: OfficialCodexTheme.lightTextMuted,
    diffAddedFill: OfficialCodexTheme.lightDiffAddedFill,
    diffAddedText: OfficialCodexTheme.lightDiffAddedText,
    diffRemovedFill: OfficialCodexTheme.lightDiffRemovedFill,
    diffRemovedText: OfficialCodexTheme.lightDiffRemovedText,
    hoverTint: Color(0x0D000000), // ~5% black
    pressedTint: Color(0x1A000000), // ~10% black
    selectedTint: Color(0x14000000), // ~8% black
    danger: Color(0xFFB43B3B),
    warning: Color(0xFF9A6417),
    success: Color(0xFF2F7D4B),
  );
}

class OfficialCodexThemeProvider extends StatelessWidget {
  const OfficialCodexThemeProvider({
    super.key,
    required this.data,
    required this.child,
  });

  final OfficialCodexThemeData data;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _OfficialCodexThemeScope(data: data, child: child);
  }
}

class _OfficialCodexThemeScope extends InheritedWidget {
  const _OfficialCodexThemeScope({required this.data, required super.child});

  final OfficialCodexThemeData data;

  @override
  bool updateShouldNotify(covariant _OfficialCodexThemeScope oldWidget) {
    return data != oldWidget.data;
  }
}
