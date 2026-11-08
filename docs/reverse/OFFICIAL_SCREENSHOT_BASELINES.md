# Official Screenshot Baselines & Multi-Viewport Geometry Specification

> **Audited Package**: ChatGPT / Codex Desktop Linux Packaging (`26.1103.32239`)  
> **Target Verification**: Automated Multi-Viewport Geometry Test Suite (`test/app/official_convergence_geometry_test.dart`)  
> **Evidence Grading**: `STATIC_BUNDLE`, `LIVE_OBSERVED`, `LOCAL_SCHEMA`

---

## 1. Executive Summary & Test Methodology

To ensure visual convergence does not drift over time or degrade across different desktop display resolutions, this document establishes the quantitative geometric baselines across three standard desktop viewports:
1. **Full HD Desktop Display**: `1920×1080`, Device Pixel Ratio (DPR) `1.0`
2. **Standard Laptop Display**: `1440×900`, Device Pixel Ratio (DPR) `1.0`
3. **HiDPI / Retina Desktop Display**: `2560×1440`, Device Pixel Ratio (DPR) `1.25` and `2.0`

The automated geometry verification suite (`test/app/official_convergence_geometry_test.dart`) uses Flutter's widget test framework to render full app instances inside headless viewports, inspect the rendered `RenderBox` geometry, and programmatically assert dimensions, insets, radii, and alignments against the official measured specifications.

---

## 2. Multi-Viewport Geometry Specifications

### 2.1 Viewport 1: Full HD Desktop (`1920×1080`, DPR `1.0`)

| Structural Node | Official Target Dimension | Native Expected Box Constraint | Tolerated Delta | Asserted Property |
|---|---|---|---|---|
| **App Shell Frame** | `1920.0 × 1080.0` | `Size(1920.0, 1080.0)` | `0.0 px` | Exact match to window frame |
| **Titlebar Drag Region** | `1920.0 × 46.0` | `Size(1920.0, 46.0)` | `0.0 px` | Full-width titlebar height |
| **Expanded Sidebar Rail** | `260.0 × 1034.0` | `Size(260.0, 1034.0)` | `0.0 px` | 260px width; 1080 - 46 = 1034px |
| **Collapsed Sidebar Rail**| `0.0 × 1034.0` | `Size(0.0, 1034.0)` | `0.0 px` | Zero width when collapsed |
| **Inset Workspace Card** | `1654.0 × 1028.0` | `Size(1654.0, 1028.0)` | `±2.0 px` | 1920 - 260 - 6 = 1654px; top-left radius 12px |
| **Thread Header Bar** | `1654.0 × 46.0` | `Size(1654.0, 46.0)` | `0.0 px` | Inset workspace header height |
| **Conversation Column** | `704.0 × 982.0` (max) | `width <= 704.0`, centered | `0.0 px` | Centered reading column (dx = (1654 - 704)/2 = 475px) |
| **User Message Bubble** | `width <= 528.0` (75%) | `width <= 528.0`, right-aligned | `0.0 px` | User prompt bubble clamped to 75% column width |
| **Floating Composer** | `704.0 × height` | `width == 704.0`, centered | `0.0 px` | Composer width matches conversation column |
| **Composer Bottom Inset**| `24.0 px` from bottom | `Offset(dx, 1080 - height - 24)` | `±2.0 px` | Floating clearance from bottom edge |

### 2.2 Viewport 2: Standard Laptop (`1440×900`, DPR `1.0`)

| Structural Node | Official Target Dimension | Native Expected Box Constraint | Tolerated Delta | Asserted Property |
|---|---|---|---|---|
| **App Shell Frame** | `1440.0 × 900.0` | `Size(1440.0, 900.0)` | `0.0 px` | Window bounds |
| **Titlebar Drag Region** | `1440.0 × 46.0` | `Size(1440.0, 46.0)` | `0.0 px` | Titlebar height |
| **Expanded Sidebar Rail** | `260.0 × 854.0` | `Size(260.0, 854.0)` | `0.0 px` | 260px width; 900 - 46 = 854px |
| **Inset Workspace Card** | `1174.0 × 848.0` | `Size(1174.0, 848.0)` | `±2.0 px` | 1440 - 260 - 6 = 1174px |
| **Conversation Column** | `704.0 × 802.0` (max) | `width == 704.0`, centered | `0.0 px` | Centered column (dx = (1174 - 704)/2 = 235px) |
| **User Message Bubble** | `width <= 528.0` (75%) | `width <= 528.0`, right-aligned | `0.0 px` | Clamped to 528px |
| **Floating Composer** | `704.0 × height` | `width == 704.0`, centered | `0.0 px` | Matches column width |

### 2.3 Viewport 3: HiDPI / Retina Desktop (`2560×1440`, DPR `1.25` & `2.0`)

| Structural Node | Logical Target Dimension | Physical Pixels (DPR 2.0) | Asserted Logical Property |
|---|---|---|---|
| **App Shell Frame** | `2560.0 × 1440.0` | `5120 × 2880` | Logical coordinate system stability |
| **Titlebar Height** | `46.0 px` | `92 px` | Exact scaling without subpixel artifact |
| **Sidebar Width** | `260.0 px` | `520 px` | Exact scaling |
| **Conversation Column** | `704.0 px` | `1408 px` | Perfectly centered on wide canvas |
| **Composer Corner Radius**| `24.0 px` | `48 px` | Antialiased smooth corner curve |
| **Hairline Border** | `0.5 px` (or `1.0 px` device) | `1.0 px` physical | Crisp 1px physical hairline without blur |

---

## 3. Quantitative Divergence Table (`Official vs Native vs delta`)

This table records every concrete discrepancy between the measured official desktop values and the legacy Native implementation (`HEAD`), providing the exact target delta for convergence.

| UI Element & Property | Official Measured Value (`STATIC_BUNDLE` / `LIVE_OBSERVED`) | Legacy Native Implementation (`HEAD`) | Delta (`Official - Native`) | Convergence Action & Target File |
|---|---|---|---|---|
| **Reading Column Width** | `704.0 px` (`44rem`) | `760.0 px` | **`-56.0 px`** | `conversation.dart`: replace `maxWidth: 760.0` with `maxWidth: 704.0` |
| **Composer Container Width**| `704.0 px` (`44rem`) | `760.0 px` | **`-56.0 px`** | `conversation.dart`: clamp composer container to `704.0 px` |
| **User Bubble Max Width** | `528.0 px` (`75%` of `704px`) | `560.0 px` | **`-32.0 px`** | `conversation.dart`: clamp bubble to `0.75 * columnWidth` |
| **Composer Corner Radius** | `24.0 px` (`1.5rem`) | `22.0 px` | **`+2.0 px`** | `theme_tokens.dart`: update `radiusComposer` to `24.0` |
| **Titlebar Drag Height** | `46.0 px` (`38.0 px` macOS) | `52.0 px` | **`-6.0 px`** | `app_shell.dart`: reduce header from `52.0` to `46.0` |
| **Sidebar Nav Row Height** | `36.0 px` | `40.0 px` | **`-4.0 px`** | `sidebar_activity.dart`: set thread row height to `36.0` |
| **Sidebar Default Width** | `260.0 px` | `264.0 px` | **`-4.0 px`** | `app_shell.dart`: set `_desktopSidebarWidth = 260.0` |
| **Sidebar Row Corner Radius**| `10.0 px` | `8.0 px` | **`+2.0 px`** | `codex_sidebar_row.dart`: set row radius to `10.0` |
| **Main Surface Top Radius** | `12.0 px` (inset card) | `0.0 px` (flat full-bleed) | **`+12.0 px`** | `app_shell.dart`: apply `BorderRadius.circular(12.0)` to inset panel |
| **Main Surface Hairline Border**| `0.5 px` border | `1.0 px` `VerticalDivider` | **`-0.5 px`** | `app_shell.dart`: replace divider with hairline inset border |
| **Standard Button Radius** | `10.0 px` | `8.0 px` | **`+2.0 px`** | `codex_button.dart`: default `buttonRadius = 10.0` |
| **Tooltip Corner Radius** | `16.0 px` pill | `6.0 px` | **`+10.0 px`** | `codex_tooltip.dart`: set radius to `16.0` |
| **Popover Corner Radius** | `16.0 px` / `20.0 px` | `12.0 px` | **`+4.0 px`..`+8.0 px`**| `codex_popover.dart`: set container radius to `16.0` / `20.0` |

---

## 4. Multi-Viewport Automated Assertion Guide

The automated geometry test suite (`test/app/official_convergence_geometry_test.dart`) executes tests conforming to the following structure:

```dart
testWidgets('desktop shell converges to official geometry at 1920x1080', (tester) async {
  // Set headless viewport to 1920x1080 with DPR 1.0
  tester.view.physicalSize = const Size(1920.0, 1080.0);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const CodexNativeApp());
  await tester.pumpAndSettle();

  // Assert Titlebar geometry
  final titlebarFinder = find.byKey(const ValueKey('app_shell_titlebar'));
  expect(tester.getSize(titlebarFinder).height, equals(46.0));

  // Assert Sidebar width
  final sidebarFinder = find.byKey(const ValueKey('app_shell_sidebar'));
  expect(tester.getSize(sidebarFinder).width, equals(260.0));

  // Assert Conversation column max-width
  final columnFinder = find.byKey(const ValueKey('conversation_reading_column'));
  expect(tester.getSize(columnFinder).width, lessThanOrEqualTo(704.0));

  // Assert Composer width and radius
  final composerFinder = find.byKey(const ValueKey('floating_composer'));
  expect(tester.getSize(composerFinder).width, lessThanOrEqualTo(704.0));
});
```
