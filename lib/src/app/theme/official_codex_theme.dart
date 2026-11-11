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

  /// Current conversation reading and composer column (42rem / 672px).
  static const double maxContentWidth = 672.0;

  /// Compact reading column width for constrained viewports (40rem / 640px).
  static const double compactContentWidth = 640.0;

  /// User message bubble max width factor within the reading column
  /// (`.bubble-vBnidZ` `--user-chat-width: 70%`).
  static const double maxUserBubbleWidthFactor = 0.70;

  /// Composer max width shares the reading column width.
  static const double composerMaxWidth = maxContentWidth;
  static const double composerTrayInlineInset = 13.0;

  /// Floating composer corner radius (24px / 1.5rem).
  static const double composerRadius = 24.0;

  /// Floating composer pill corner radius (28px).
  static const double composerRadiusPill = 28.0;
  static const double changesSummaryRadius = 20.0;

  /// User message corner radius (`.bubble-vBnidZ` `--radius-2xl: calc(var(--spacing) * 5.5)` = `22px`).
  static const double userMessageRadius = 22.0;

  /// User message bubble padding (`.bubble-vBnidZ` `--thread-content-margin: 16px`, `py-2.5` = `10px`).
  static const double userMessageHorizontalPadding = 16.0;
  static const double userMessageVerticalPadding = 10.0;

  /// Initialized Electron UI/chat sans font size (`93122` `sansFontSize.default = 14` ->
  /// `182735` `--font-ui-size: 14px` -> `e77f816560c6.css` `--codex-chat-font-size: 14px`).
  static const double chatFontSize = 14.0;

  /// Initialized Electron chat code font size (`93122` `codeFontSize.default = 12` ->
  /// `182735` `:root --font-code-size: 12px` -> `e77f816560c6.css` `--codex-chat-code-font-size: 12px`).
  static const double chatCodeFontSize = 12.0;

  /// Desktop Markdown fenced code block minimum line-box height
  /// (`0040d5ae1a9f.css` `.CodeContent-ybJ8Tl { line-height: max(1.5em, 20px) }`).
  static const double chatCodeBlockMinLineHeight = 20.0;

  /// User message typography size (`93122` `sansFontSize.default = 14` ->
  /// `182735` `--font-ui-size: 14px` -> `e77f816560c6.css` `.text-size-chat` = `14px`).
  static const double userMessageFontSize = chatFontSize;

  /// User message relaxed line-height multiplier (`leading-relaxed`: `1.625`).
  static const double userMessageLineHeight = 1.625;

  /// Default collapsed line threshold for long user messages (`dKZq` `collapsedLineCount = 20`).
  static const int userMessageCollapsedLines = 20;

  /// Bounded collapsed measurement/render slice per collapsed line (`dKZq` `512 * D`).
  static const int userMessageCollapsedCharsPerLine = 512;

  /// Separation between collapsed user message text/ellipsis block and inline
  /// disclosure button (`14353.dKZq` `flex-col gap-1` `4px` + `mt-1.5` `6px` = `10px`).
  static const double userMessageExpandGap = 10.0;

  /// Gap between externalized user attachment row and user bubble (`gap-2` = `8px`).
  static const double userMessageAttachmentGap = 8.0;

  /// Gap between user bubble and hover/focus turn action controls (`gap-1` = `4px`).
  static const double userMessageActionGap = 4.0;

  /// Maximum width of a thread attachment pill (`QAOE` `max-w-[320px]`).
  static const double userAttachmentPillMaxWidth = 320.0;

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

  /// Current rail-with-contextual-sidebar geometry.
  static const double navigationRailWidth = 52.0;
  static const double desktopLeftPanelWidth = 340.0;
  static const double sidebarWidth =
      desktopLeftPanelWidth - navigationRailWidth;
  static const double shellToolbarHeight = 36.0;
  static const double shellPageTopInset = 8.0;
  static const double contextualSidebarHeaderHeight = 52.0;
  static const double sidebarUnreadIndicatorSize = 8.0;
  // The shipped Desktop fallback resolves both roles through --blue-300.
  static const Color chartBlue = Color(0xFF339CFF);
  static const Color sidebarUnreadIndicatorColor = chartBlue;
  static const BoxShadow shellPageShadow = BoxShadow(
    color: Color(0x0D000000),
    offset: Offset(0, 4),
    blurRadius: 16,
  );

  /// Resize bounds include the navigation rail and reserve workspace room.
  static const double desktopLeftPanelMinWidth = 290.0;
  static const double sidebarMaxWidth = 520.0;
  static const double desktopWorkspaceMinWidth = 240.0;

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

  /// Activity / tool summary row height (34px) in card/execution mode.
  static const double activityRowHeight = 34.0;

  /// Activity / tool card corner radius (8px).
  static const double activityRowRadius = 8.0;

  /// Inline command output scroll region (9rem at the reference scale).
  static const double commandOutputPreviewHeight = 144.0;

  /// Turn work divider pill height (26px) in compact/mobile mode.
  static const double workDividerHeight = 26.0;

  /// Top-level conversation item vertical rhythm (`--conversation-item-gap`: `16px`).
  static const double conversationItemGap = 16.0;

  /// Grouped activity item vertical gap (`--conversation-grouped-item-gap`: `4px`).
  static const double conversationGroupedItemGap = 4.0;

  /// Inline activity leading icon and disclosure chevron size (`.icon-2xs`: `14px`).
  static const double activityInlineIconSize = 14.0;

  /// Inline activity leading icon-to-summary gap (`gap-1.5`: `6px`).
  static const double activityInlineIconGap = 6.0;

  /// Inline activity summary-to-chevron gap (`gap-1`: `4px`).
  static const double activityInlineChevronGap = 4.0;

  /// Inline activity chat typography size and line height: `.text-size-chat`
  /// resolves `var(--codex-chat-font-size)` (`14px`) while inheriting root
  /// `html, :host { line-height: 1.5 }` (`21px` line box in `e77f816560c6.css`).
  static const double activityChatFontSize = chatFontSize;
  static const double activityChatLineHeight = 1.5;

  /// Top gap between inline `Worked for` trigger and hairline rule (`pt-1`: `4px`).
  static const double workDividerRuleTopGap = 4.0;

  /// Grouped activity scroll region maximum height (`max-h-56`: `224px`).
  static const double activityGroupMaxHeight = 224.0;

  /// Reasoning preview/expanded scroll body maximum height (`8.75rem`: `140px`).
  static const double reasoningBodyMaxHeight = 140.0;

  /// Attachment chip height (28px).
  static const double attachmentChipHeight = 28.0;

  /// Attachment chip corner radius (10px).
  static const double attachmentChipRadius = 10.0;

  /// Ordinary Electron composer primary action diameter (`--spacing-token-button-composer`: `7 * 4px = 28px`,
  /// while `[data-dictation-enabled]` overrides to `36px` on unsupported voice branches).
  static const double sendButtonDiameter = 28.0;

  /// Composer primary action icon size (`--icon-primary-action-size`: `16px`).
  static const double sendButtonIconSize = 16.0;

  /// Desktop Markdown fenced code block surface radius (`--radius-3xl-base`: `1.25rem = 20px`).
  static const double codeBlockRadius = 20.0;

  /// Desktop Markdown fenced code block border width (`border border-subtle`: `1px`).
  static const double codeBlockBorderWidth = 1.0;

  /// Desktop Markdown fenced code block action bar minimum height (`min-h-12`: `48px`).
  static const double codeBlockHeaderHeight = 48.0;

  /// Desktop Markdown inline code pill corner radius (`.InlineCode`: `border-radius: 6px`).
  static const double inlineCodeRadius = 6.0;

  /// Desktop Markdown inline code pill horizontal padding (`.InlineCode`: `padding-inline: 6px`).
  static const double inlineCodeHorizontalPadding = 6.0;

  /// Desktop Markdown inline code pill vertical padding (`.InlineCode`: `padding-block: 1px`).
  static const double inlineCodeVerticalPadding = 1.0;

  /// Desktop Markdown inline code relative font scale (`.InlineCode`: `font-size: .92em`).
  static const double inlineCodeFontScale = 0.92;

  /// Maximum rich `WidgetSpan` inline-code pills rendered per Desktop Markdown
  /// message before remaining inline-code tokens fall back to merged styled
  /// `TextSpan`s (`ADR-058`).
  static const int maxInlineCodePills = 128;

  /// Thread reading canvas horizontal gutters (24px).
  static const double threadBodyInlinePadding = 24.0;

  /// Current Desktop Markdown's relaxed prose line-height multiplier.
  static const double assistantProseLineHeight = 1.625;

  // --- Palette Definitions ---

  // Opaque control roles for the Flutter adapter. Semantic primitives use
  // translucent interaction tints and hairline borders over their own surfaces.
  static const Color lightControlRaisedSurface = Color(0xFFEDEDED);
  static const Color lightControlHover = Color(0xFFEBEBEB);
  static const Color lightControlSelected = Color(0xFFE5E5E5);
  static const Color lightControlBorder = Color(0xFFE5E5E5);
  static const Color lightControlBorderStrong = Color(0xFFD4D4D4);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color lightControlWarning = Color(0xFFD97706);
  static const Color lightControlDanger = Color(0xFFDC2626);
  static const Color codeSurface = Color(0xFF171717);
  static const Color lightControlShadow = Color(0x14000000);
  static const Color darkControlRaisedSurface = Color(0xFF383838);
  static const Color darkControlHover = Color(0xFF2A2A2A);
  static const Color darkControlSelected = Color(0xFF343434);
  static const Color darkControlBorder = Color(0xFF2E2E2E);
  static const Color darkControlBorderStrong = Color(0xFF424242);
  static const Color darkControlWarning = Color(0xFFFBBF24);
  static const Color darkControlShadow = Color(0x66000000);

  // Dark Mode Surface Hierarchy
  static const Color darkShellBackground = Color(0xFF171717); // Tier 0
  static const Color darkWorkspaceBackground = Color(0xFF212121); // Tier 1
  static const Color darkElevatedSurface = Color(0xFF2F2F2F); // Tier 2
  static const Color darkModalSurface = Color(0xFF2F2F2F); // Tier 3
  // `--color-background-user-message: color-mix(in oklab, var(--color-text) 5%, transparent)`
  static const Color darkUserBubbleBackground = Color(0x0DDFDFDF);
  static const Color darkUserBubbleTranslucent = Color(0x0DDFDFDF);
  static const Color darkHairlineBorder = Color(
    0x14FFFFFF,
  ); // rgba(255,255,255,0.08)
  static const Color darkFocusRing = Color(0xFF3B82F6);
  static const Color darkAccent = Color(0xFF10A37F);

  // Electron dark foreground hierarchy (`890434.F5h5` + `BQgU` + `e77f816560c6.css`):
  // `--color-text: #dfdfdf`, `--color-text-secondary: color-mix(in srgb, #dfdfdf 65%, transparent)`,
  // `--color-text-tertiary: rgba(255, 255, 255, 0.498)` (opaque sRGB over `#212121` workspace).
  static const Color darkTextPrimary = Color(0xFFDFDFDF);
  static const Color darkTextSecondary = Color(0xFF9D9D9D);
  static const Color darkTextMuted = Color(0xFF909090);
  // `.summary-lK7Lpm` (`color-mix(in oklab, var(--color-text) 60%, transparent)`)
  static const Color darkActivitySummaryText = Color(0x99DFDFDF);
  // `.execDescendants-CELqcM` / `text-text/30` (`color-mix(in oklab, var(--color-text) 30%, transparent)`)
  static const Color darkActivityChildText = Color(0x4DDFDFDF);

  static const Color darkDiffAddedFill = Color(0xFF1E4620);
  static const Color darkDiffAddedText = Color(0xFF4ADE80);
  static const Color darkDiffRemovedFill = Color(0xFF5A1E1E);
  static const Color darkDiffRemovedText = Color(0xFFF87171);
  static const Color darkChangesSummarySurface = Color(0xFF414141);
  // `color-mix(in srgb, var(--color-background-primary-ghost-hover) 60%, var(--color-text) 6%)`
  // -> `color(srgb 0.930283 0.930283 0.930283 / 0.108)` in dark mode.
  static const Color darkInlineCodeBackground = Color(0x1CEDEDED);

  // Light Mode Surface Hierarchy
  static const Color lightShellBackground = Color(0xFFF9F9F9); // Tier 0
  static const Color lightNavigationBackground = Color(0xFFF4F4F4);
  static const Color lightContextualSidebarBackground = Color(0xFFFBFBFB);
  static const Color lightWorkspaceBackground = Color(0xFFFFFFFF); // Tier 1
  static const Color lightElevatedSurface = Color(0xFFF4F4F4); // Tier 2
  static const Color lightModalSurface = Color(0xFFFFFFFF); // Tier 3
  // `--color-background-user-message: color-mix(in oklab, var(--color-text) 5%, transparent)`
  static const Color lightUserBubbleBackground = Color(0x0D1A1C1F);
  static const Color lightUserBubbleTranslucent = Color(0x0D1A1C1F);
  // `color-mix(in srgb, var(--color-background-primary-ghost-hover) 60%, var(--color-text) 6%)`
  // -> `color(srgb 0.101961 0.109804 0.121569 / 0.09)` in light mode.
  static const Color lightInlineCodeBackground = Color(0x171A1C1F);
  static const Color lightHairlineBorder = Color(
    0x14000000,
  ); // rgba(0,0,0,0.08)
  static const Color lightFocusRing = Color(0xFF2563EB);
  static const Color lightAccent = Color(0xFF10A37F);

  // Electron light foreground hierarchy (`890434.F5h5` + `BQgU` + `e77f816560c6.css`):
  // `--color-text: #1a1c1f`, `--color-text-secondary: color-mix(in srgb, #1a1c1f 65%, transparent)`,
  // `--color-text-tertiary: rgba(26, 28, 31, 0.495)` (opaque sRGB over `#FFFFFF` workspace).
  static const Color lightTextPrimary = Color(0xFF1A1C1F);
  static const Color lightTextSecondary = Color(0xFF6A6B6D);
  static const Color lightTextMuted = Color(0xFF8E8F90);
  // `.summary-lK7Lpm` (`color-mix(in oklab, var(--color-text) 60%, transparent)`)
  static const Color lightActivitySummaryText = Color(0x991A1C1F);
  // `.execDescendants-CELqcM` / `text-text/30` (`color-mix(in oklab, var(--color-text) 30%, transparent)`)
  static const Color lightActivityChildText = Color(0x4D1A1C1F);

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
    required this.inlineCodeBackground,
    required this.hairlineBorder,
    required this.focusRing,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.activitySummaryText,
    required this.activityChildText,
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
  final Color inlineCodeBackground;
  final Color hairlineBorder;
  final Color focusRing;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color activitySummaryText;
  final Color activityChildText;
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
    inlineCodeBackground: OfficialCodexTheme.darkInlineCodeBackground,
    hairlineBorder: OfficialCodexTheme.darkHairlineBorder,
    focusRing: OfficialCodexTheme.darkFocusRing,
    accent: OfficialCodexTheme.darkAccent,
    textPrimary: OfficialCodexTheme.darkTextPrimary,
    textSecondary: OfficialCodexTheme.darkTextSecondary,
    textMuted: OfficialCodexTheme.darkTextMuted,
    activitySummaryText: OfficialCodexTheme.darkActivitySummaryText,
    activityChildText: OfficialCodexTheme.darkActivityChildText,
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
    inlineCodeBackground: OfficialCodexTheme.lightInlineCodeBackground,
    hairlineBorder: OfficialCodexTheme.lightHairlineBorder,
    focusRing: OfficialCodexTheme.lightFocusRing,
    accent: OfficialCodexTheme.lightAccent,
    textPrimary: OfficialCodexTheme.lightTextPrimary,
    textSecondary: OfficialCodexTheme.lightTextSecondary,
    textMuted: OfficialCodexTheme.lightTextMuted,
    activitySummaryText: OfficialCodexTheme.lightActivitySummaryText,
    activityChildText: OfficialCodexTheme.lightActivityChildText,
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
