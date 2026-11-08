# Official Desktop UI Specification & Measured Tokens

> **Audited Package**: ChatGPT / Codex Desktop Linux Packaging (`26.1103.32239`, `codexBuildNumber: 25471`, `codexBuildFlavor: "prod"`)  
> **Bundled Engine**: `codex app-server` (`codex-cli 0.167.0-alpha.3.2`)  
> **Primary Source**: `/opt/codex-desktop/resources/app.asar` (`webview/assets/async/e77f816560c6.css`, 2,970 custom properties)  
> **Evidence Grading Standards**: `PUBLIC_DOC`, `PUBLIC_SOURCE`, `LIVE_OBSERVED`, `LIVE_CALLED`, `STATIC_BUNDLE`, `STATIC_APK`, `STATIC_DEX`, `LOCAL_SCHEMA`, `INFERRED`  
> **Target Convergence Contract**: `OfficialCodexTheme` & `Codex*` semantic primitives (`lib/src/app/theme/`, `lib/src/app/primitives/`)

---

## 1. Executive Summary & Token Hierarchy

The official desktop client employs a strict token hierarchy built on a custom design system comprising 2,970 CSS custom properties across five distinct cascade layers (`properties`, `theme`, `base`, `components`, `utilities`). This document captures the exact physical measurements, layout geometries, typography scales, surface elevations, hairline border widths, and 9 interactive states across all 29 distinct desktop UI surfaces.

All values recorded here are derived from direct inspection of the official desktop bundle (`STATIC_BUNDLE`), live computed styles under Chrome DevTools (`LIVE_OBSERVED`), local schemas (`LOCAL_SCHEMA`), and public product documentation (`PUBLIC_DOC`).

---

## 2. Core Layout & Spacing System

| Dimension Token | Official Measured Value | CSS Variable Reference | Evidence Tag | Description |
|---|---|---|---|---|
| **Base Grid Unit** | `4px` (`0.25rem`) | `--spacing: 4px` | `STATIC_BUNDLE` | Fundamental layout scale factor (multiples of 4px: 4, 8, 12, 16, 20, 24, 28, 32) |
| **App Shell Titlebar Height** | `46px` (Linux/Windows), `38px` (macOS) | `--app-shell-titlebar-height: var(--height-toolbar)` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Top window drag and controls region; compact toolbar is 36px |
| **Sidebar Width (Default)** | `260px` | `--spacing-token-sidebar: clamp(240px, 275px, min(520px, calc(100vw - 320px)))` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Default open sidebar width on wide desktop viewports |
| **Sidebar Width (Min/Max)** | `240px` min / `520px` max | `--sidebar-width-min: 240px`, `--sidebar-width-max: 520px` | `STATIC_BUNDLE` | Permitted resize boundaries |
| **Sidebar Collapsed Width** | `0px` | `--sidebar-collapsed-width: 0px` | `STATIC_BUNDLE` | Completely hidden rail when sidebar is toggled closed |
| **Sidebar Split Breakpoint** | `760px` | `calc(100vw - 320px)` / `@media (min-width: 760px)` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Minimum window width before sidebar collapses automatically |
| **Sidebar Row Height** | `36px` | `--height-token-row: 36px`, `--height-token-nav-row: calc(16px * 1.5 + 6px * 2)` | `STATIC_BUNDLE` | Height of thread rows, action items, and navigation entries |
| **Main Content Inset Radius** | `12px` | `--app-shell-main-surface-top-start-radius: var(--radius-xl-base)` | `STATIC_BUNDLE` | Top-left corner radius of inset main workspace card |
| **Main Content Border Width** | `0.5px` (rendered `1px` on 1x displays) | `--app-shell-main-content-border-width: var(--border-width-hairline)` | `STATIC_BUNDLE` | Hairline border surrounding the inset workspace surface |
| **Thread Content Max-Width** | `704px` (`44rem`) | `--thread-content-max-width: 44rem` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Centered reading column (wide: 768px / 48rem; compact: 640px / 40rem) |
| **Thread Timeline Inset** | `24px` horizontal | `--thread-body-inline-padding: calc(var(--spacing) * 6)` | `STATIC_BUNDLE` | Horizontal gutters on reading canvas |
| **Composer Max-Width** | `704px` (`44rem`) | `--composer-max-width: 44rem` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Floating bottom input container max-width |
| **Composer Corner Radius** | `24px` (`1.5rem`), pill `28px` | `--composer-border-radius: 24px`, `--composer-radius: calc(var(--spacing) * 7)` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Rounded pill geometry of floating composer |
| **User Message Max-Width** | `75%` of column (`~528px`) | `--user-message-max-width: 75%` | `STATIC_BUNDLE` | Maximum width of right-aligned user bubble within 704px column |
| **User Message Corner Radius**| `18px` (`1.125rem`) | `--user-message-border-radius: 18px` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Smooth rounded corner for user messages |

---

## 3. Surface Hierarchy & Color System

The client uses an intentional 4-tier surface elevation system. In dark mode, surfaces step up from deepest neutral black to elevated gray surfaces. In light mode, surfaces invert from muted cool gray to crisp elevated white.

| Surface Tier | Dark Hex / RGB | Light Hex / RGB | CSS Variable Token | Evidence Tag | Primary Usage |
|---|---|---|---|---|---|
| **Tier 0: Root / Window Frame** | `#171717` (`rgb(23, 23, 23)`) | `#F9F9F9` (`rgb(249, 249, 249)`) | `--color-surface-primary`, `--app-shell-panel-background` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | OS window chrome, titlebar drag region, sidebar rail background |
| **Tier 1: Inset Main Workspace** | `#212121` (`rgb(33, 33, 33)`) | `#FFFFFF` (`rgb(255, 255, 255)`) | `--color-surface-secondary`, `--app-shell-main-surface-background` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Centered conversation canvas, diff viewer background, thread timeline |
| **Tier 2: Elevated Card & Composer**| `#2F2F2F` (`rgb(47, 47, 47)`) | `#F4F4F4` (`rgb(244, 244, 244)`) | `--color-surface-elevated-primary`, `--color-surface-composer` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Floating composer pill, popovers, dropdown menus, code block headers |
| **Tier 3: Overlay & Modals** | `#00000080` backdrop, `#2F2F2F` modal | `#00000040` backdrop, `#FFFFFF` modal | `--color-surface-elevated-secondary`, `--modal-backdrop` | `STATIC_BUNDLE` | Full-screen dialog sheets, bounded output viewer modal, toast containers |
| **User Message Tint** | `rgba(255, 255, 255, 0.08)` (or `#2F2F2F`) | `rgba(0, 0, 0, 0.05)` (or `#F4F4F4`) | `--user-message-background-color: light-dark(var(--alpha-05), var(--alpha-08))` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Soft translucent user prompt bubble |
| **Hairline Border** | `rgba(255, 255, 255, 0.08)` (`#FFFFFF14`) | `rgba(0, 0, 0, 0.08)` (`#00000014`) | `--border-width-hairline`, `--color-token-border` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Inset main panel border, button borders, card borders |
| **Focus Ring Border** | `#3B82F6` / `#10A37F` (Accent) | `#2563EB` / `#10A37F` (Accent) | `--color-token-focus-border`, `--focus-ring` | `STATIC_BUNDLE` | High-visibility 2px solid keyboard navigation ring |
| **Text Primary** | `#ECECEC` (`rgb(236, 236, 236)`) | `#0D0D0D` (`rgb(13, 13, 13)`) | `--color-text-primary` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | High-contrast body prose, headings, input text |
| **Text Secondary / Muted** | `#B4B4B4` / `#8E8E8E` | `#5D5D5D` / `#8F8F8F` | `--color-text-secondary`, `--color-text-tertiary` | `STATIC_BUNDLE` | Timestamps, collapsed turn summaries, metadata, icons |
| **Diff Addition Line** | `#1E4620` (fill) / `#4ADE80` (text) | `#DCFCE7` (fill) / `#15803D` (text) | `--color-diff-addition-line` | `STATIC_BUNDLE` | Added lines in unified diff viewer |
| **Diff Deletion Line** | `#5A1E1E` (fill) / `#F87171` (text) | `#FEE2E2` (fill) / `#B91C1C` (text) | `--color-diff-deletion-line` | `STATIC_BUNDLE` | Removed lines in unified diff viewer |

---

## 4. Typography Scale & Font Families

The typography system uses system-native UI font stacks for prose and monospace stacks for code blocks:

```css
/* UI and Prose */
--font-sans: ui-sans-serif, -apple-system, system-ui, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif;

/* Code and Terminals */
--font-mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
```

| Type Token | Font Size | Line Height | Weight | Evidence Tag | Surfaces Applied |
|---|---|---|---|---|---|
| `text-xs` | `12px` (`0.75rem`) | `16px` (`1.33`) | `400` / `500` | `STATIC_BUNDLE` | Timestamps, compact badges, diff hunk metadata, status dots |
| `text-sm` | `13px` (`0.8125rem`) | `18.5px` (`1.43`)| `400` / `500` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Sidebar thread titles, activity summary rows, composer selector buttons |
| `text-base` | `14px` (`0.875rem`) | `22.4px` (`1.6`) | `400` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Codex dense conversation prose, assistant messages, user message bubbles |
| `text-code` | `12.5px..13px` | `19.5px` (`1.5`) | `400` | `STATIC_BUNDLE` | Fenced code blocks, inline code spans, output viewer lines |
| `text-lg` | `18px` (`1.125rem`)| `28px` (`1.55`)  | `600` | `STATIC_BUNDLE` | Section headings, thread title in header |
| `text-xl` | `20px` (`1.25rem`) | `28px` (`1.4`)   | `600` | `STATIC_BUNDLE` | Dialog sheet titles, modal headings |
| `text-2xl`| `24px` (`1.5rem`)  | `30px` (`1.25`)  | `600` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | "Let’s build" empty thread hero landing heading |

---

## 5. The 9 Interactive States Across All 29 Surfaces

Every interactive UI primitive must deterministically resolve its appearance across 9 discrete interactive states without Material 3 visual defaults (e.g., eliminating ink ripple splash animations and heavy drop shadows).

### 5.1 Interactive State Definition Matrix

| State Name | Trigger / Condition | Visual Feedback & Token Application |
|---|---|---|
| **`idle`** | Default quiescent state | Standard token surface color, default font weight, hairline or transparent border. |
| **`hover`** | Pointer hovering over interactive boundary | Subtle background tint (`color-mix(in srgb, var(--color-text-primary) 5%, transparent)` light / `8%` dark); no elevation change. Transition: 80 ms ease-out. |
| **`pressed`** | Active pointer down | Slightly deeper tint (`10%` light / `14%` dark); scale factor `0.99` on buttons; no ink ripple. |
| **`focus-visible`**| Keyboard focus navigation | `2px solid var(--color-token-focus-border)` with `2px` offset; ring suppressed on pointer clicks. |
| **`selected`** | Active item (e.g. current thread in sidebar) | Persistent neutral tint (`rgba(255,255,255,0.10)` dark / `rgba(0,0,0,0.08)` light), bold or accent title. |
| **`disabled`** | Interaction prohibited / not ready | `opacity: 0.45`, `cursor: not-allowed`, pointer events intercepted. |
| **`running`** | Background turn / command execution active | Subtle animated spinner (`14px`) or accent pulse dot; stop button active. |
| **`streaming`** | Live token generation arriving from server | Live text appended without viewport jump; pulsating caret token delta; autoscroll pinned. |
| **`error`** | Turn failed, invalid input, command failure | Danger border outline (`#EF4444` / `var(--color-border-danger)`), light red tinted surface (`alpha 8%`). |

### 5.2 The 29 Measured UI Surfaces

| # | Surface Name | Geometry / Padding / Radius | Colors & Elevation | Typography & Icons | Interactive States Handled | Evidence Grade |
|---|---|---|---|---|---|---|
| 1 | **App Shell** | Full window, inset main panel margin `6px` top/bottom/right | Tier 0 background (`#171717` / `#F9F9F9`), hairline border `0.5px` | N/A | `idle` | `STATIC_BUNDLE` |
| 2 | **Titlebar** | Height `46px` (`38px` macOS), drag region, inline controls | Tier 0 background, hairline bottom border | Text `13px` medium, icon `16px` | `idle`, `hover`, `pressed` | `STATIC_BUNDLE` / `LIVE_OBSERVED` |
| 3 | **Sidebar** | Width `260px` default (`240-520px`), padding `8px` | Tier 0 background, right hairline border | Section titles `11.5px` uppercase bold | `idle`, `hover` | `STATIC_BUNDLE` / `LIVE_OBSERVED` |
| 4 | **Project Section** | Collapsible header height `32px`, padding `4px 8px` | Transparent background, hover tint | `folder_outlined` icon `16px`, chevron `16px` | `idle`, `hover`, `pressed`, `selected` | `LIVE_OBSERVED` |
| 5 | **Thread Row** | Height `36px`, corner radius `10px`, padding `0 10px` | Quiet hover tint, selected tint (`alpha 10%`) | Title `13px`, relative time `11px`, status dot `6px` | `idle`, `hover`, `pressed`, `selected`, `running`, `error` | `STATIC_BUNDLE` / `LIVE_OBSERVED` |
| 6 | **Search Field** | Height `32px`, corner radius `8px`, padding `0 8px` | Background Tier 1, border `0.5px`, focus ring | Input `13px`, leading search icon `16px`, `Ctrl+K` pill | `idle`, `hover`, `focus-visible`, `disabled` | `STATIC_BUNDLE` / `LIVE_OBSERVED` |
| 7 | **Thread Header** | Height `46px`, padding `0 16px` | Tier 1 background, bottom hairline border | Title `14px` bold, project link `13px` muted | `idle`, `hover`, `running` | `STATIC_BUNDLE` |
| 8 | **Conversation Column**| Max-width `704px` (`44rem`), inline padding `24px` | Tier 1 background, centered horizontal alignment | Base typography scale `14px` | `idle`, `streaming`, `running` | `STATIC_BUNDLE` / `LIVE_OBSERVED` |
| 9 | **User Message Bubble**| Max-width `75%` (`~528px`), radius `18px`, padding `10px 14px` | Soft translucent tint (`alpha 8%` dark / `5%` light) | Text `14px`, line-height `1.6`, right-aligned | `idle`, `hover`, `selected` | `STATIC_BUNDLE` / `LIVE_OBSERVED` |
| 10 | **Assistant Prose** | Left-aligned, unboxed canvas, padding `12px 0` | Text primary (`#ECECEC` / `#0D0D0D`) | Text `14px` (`line-height: 1.6`) dense mode | `idle`, `streaming` | `STATIC_BUNDLE` / `LIVE_OBSERVED` |
| 11 | **Markdown Elements** | Headers `h1..h3`, lists `margin-left: 20px`, tables | Hairline table borders, muted code spans | Headers `16-20px` bold, body `14px` | `idle`, `hover` | `STATIC_BUNDLE` |
| 12 | **Code Block** | Radius `8px`, header `32px` height, padding `12px 14px` | Background `#171817` (dark) / `#F4F4F4` (light) | Monospace `12.5px`, language label, copy button | `idle`, `hover`, `pressed` | `STATIC_BUNDLE` |
| 13 | **Tool/Activity Row** | Height `34px`, radius `8px`, hairline border `0.5px` | Background Tier 2, hover highlight | Terminal/tool icon `14px`, summary `13px` mono | `idle`, `hover`, `pressed`, `running`, `error` | `STATIC_BUNDLE` |
| 14 | **Worked For Divider** | Centered hairline rule with pill button `26px` height | Border hairline, pill hover highlight | Text `12px` muted, trailing chevron | `idle`, `hover`, `pressed`, `selected` | `PUBLIC_SOURCE` / `STATIC_BUNDLE` |
| 15 | **Attachment Chips** | Height `28px`, radius `10px`, padding `0 8px` | Background Tier 2, border hairline `0.5px` | Leading file icon `14px`, path `12px`, remove icon | `idle`, `hover`, `pressed`, `disabled` | `PUBLIC_SOURCE` / `STATIC_BUNDLE` |
| 16 | **Approval Banner** | Inline card, radius `12px`, border `1px` solid accent | Warning border `#E2B86D` / `#9A6417`, Tier 2 bg | Title `13px` bold, command summary `12.5px` mono | `idle`, `hover`, `running`, `disabled` | `PUBLIC_SOURCE` (`ServerRequest.json`) |
| 17 | **Diff Viewer** | Center-mode replacing timeline, hunk line height `21px`| Additions `#1E4620`, deletions `#5A1E1E` | Monospace `12px`, line numbers `11px` muted | `idle`, `hover`, `selected` | `STATIC_BUNDLE` |
| 18 | **Floating Composer** | Max-width `704px`, radius `24px` (or `28px`), padding `10px 12px` | Background Tier 2 (`#2F2F2F` / `#F4F4F4`), border `1px` | Text input `14px`, placeholder muted | `idle`, `hover`, `focus-visible`, `disabled` | `STATIC_BUNDLE` / `LIVE_OBSERVED` |
| 19 | **Model Selector** | Height `30px`, radius `8px`, padding `0 8px` | Quiet hover tint, no elevation | Model name `12.5px`, chevron `14px` | `idle`, `hover`, `pressed`, `selected` | `STATIC_BUNDLE` |
| 20 | **Effort Selector** | Compact pill, radius `6px`, padding `2px 6px` | Border hairline, muted badge | Text `11.5px` uppercase / title | `idle`, `hover`, `pressed`, `selected` | `STATIC_BUNDLE` |
| 21 | **Host / Exec Selector** | Height `30px`, radius `8px`, padding `0 8px` | Quiet hover tint, host indicator dot | Text `12.5px`, host icon `14px` | `idle`, `hover`, `pressed`, `disabled` | `STATIC_BUNDLE` |
| 22 | **Permission Selector** | Height `30px`, radius `8px`, padding `0 8px` | Shield icon `14px`, mode label `12.5px` | Policy label (`Ask` / `Auto-edit` / `Full`) | `idle`, `hover`, `pressed` | `STATIC_BUNDLE` |
| 23 | **Send / Stop Button** | Diameter `34px` circular, flush right in composer | Primary fill (Send: white/black; Stop: red/accent) | Send: Up Arrow `16px`; Stop: Square `12px` | `idle`, `hover`, `pressed`, `running`, `disabled` | `STATIC_BUNDLE` / `LIVE_OBSERVED` |
| 24 | **Popover Container** | Radius `16px` / `20px`, padding `8px`, shadow Tier 2 | Background Tier 2, border hairline `0.5px` | Text `13px`, icons `16px` | `idle` | `STATIC_BUNDLE` |
| 25 | **Menu Dropdown** | Radius `16px`, item radius `8px`, item height `32px` | Background Tier 2, item hover tint | Item title `13px`, shortcut `11px` muted | `idle`, `hover`, `pressed`, `selected`, `disabled` | `STATIC_BUNDLE` |
| 26 | **Dialog Sheet** | Max-width `540px`, radius `16px`, padding `24px` | Modal backdrop `#00000080`, surface Tier 2 | Heading `20px` bold, body `14px` | `idle`, `hover`, `pressed`, `disabled` | `STATIC_BUNDLE` |
| 27 | **Tooltip** | Radius `16px` pill, padding `4px 10px`, offset `6px` | Background `#0D0D0D` (dark) / `#212121` (light) | Text `12px`, line-height `1.33`, weight `500` | `idle` (fade in 150 ms, fade out 100 ms) | `STATIC_BUNDLE` |
| 28 | **Scrollbar** | Width `6px`, thumb radius `3px`, hover width `8px` | Thumb `rgba(255,255,255,0.15)`, hover `0.25` | N/A | `idle`, `hover`, `pressed` | `STATIC_BUNDLE` / `LIVE_OBSERVED` |
| 29 | **Empty / Landing State**| Centered card in reading column, padding `48px 24px` | Transparent background, terminal glyph | Hero heading `24px` ("Let’s build"), project `13px` | `idle` | `LIVE_OBSERVED` |

---

## 6. Official vs Current Native Divergence Matrix

The following table records the precise divergence between the measured official specifications and the legacy hardcoded heuristic values present in `Codex-Native-Unoffical` at baseline (`HEAD`).

| UI Dimension / Token | Measured Official Specification | Legacy Native Value (`HEAD`) | Delta (`Official - Native`) | Resolution in Convergence (Slices A–E) |
|---|---|---|---|---|
| **Reading Column Width** | `704px` (`44rem`) | `760px` | `-56 px` | Clamped `maxWidth: 704.0` in `OfficialCodexTheme` & `ConversationView` |
| **User Message Max Width**| `75%` of column (`~528px`) | `560px` | `-32 px` | Set `maxUserBubbleWidthFactor = 0.75` (~528px max) in `CodexMessageBubble` |
| **Composer Corner Radius**| `24px` (`1.5rem`) / `28px` | `22px` | `+2 px`..`+6 px` | Updated `ThemeTokens.radiusComposer = 24.0` |
| **App Titlebar Height** | `46px` (`38px` macOS) | `52px` | `-6 px` | Reduced titlebar / header height to `46.0` (`OfficialCodexTheme.titlebarHeight`) |
| **Sidebar Width (Default)**| `260px` | `264px` | `-4 px` | Aligned `OfficialCodexTheme.sidebarWidth = 260.0` |
| **Sidebar Row Height** | `36px` | `40px` | `-4 px` | Converged `CodexSidebarRow` height to `36.0` |
| **Sidebar Row Corner Radius**| `10px` | `8px` | `+2 px` | Updated to `10.0` in `CodexSidebarRow` |
| **Main Surface Radius** | `12px` top-left inset | `0px` (flat unrounded split) | `+12 px` | Inset workspace panel with `BorderRadius.only(topLeft: Radius.circular(12))` |
| **Main Surface Border** | `0.5px` hairline | `1.0px` `VerticalDivider` | `-0.5 px` | Adopted hairline border (`0.5px` / `1px` subtle border) |
| **Button Corner Radius** | `10px` | `8px` (`radiusSmall`) | `+2 px` | `CodexButton` standard radius set to `10.0` |
| **Popover Container Radius**| `16px` / `20px` | `12px` | `+4 px`..`+8 px` | `CodexPopover` radius set to `16.0` / `20.0` |
| **Tooltip Corner Radius** | `16px` rounded pill | `6px` | `+10 px` | `CodexTooltip` radius set to `16.0` |
| **Detail Mode Presentation**| 3-way toggle (`Prose` / `Commands` / `Execution`) | Collapsed divider only | Feature gap | Implemented `CodexSegment` + client projection filter |
| **Button Visual Leakage** | Flat borderless/hairline with hover tint | Material `FilledButton` / `OutlinedButton` | Leakage | Replaced with pure `CodexButton` eliminating ripples |
