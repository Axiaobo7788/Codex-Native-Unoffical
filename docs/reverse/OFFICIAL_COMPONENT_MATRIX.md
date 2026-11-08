# Official Component Matrix & Semantic Primitives Specification

> **Audited Package**: ChatGPT / Codex Desktop Linux (`26.1103.32239`)  
> **Target Architecture**: Clean-Room Semantic Presentation Primitives (`lib/src/app/primitives/`) & `OfficialCodexTheme` (`lib/src/app/theme/`)  
> **Evidence Grading**: `STATIC_BUNDLE`, `LIVE_OBSERVED`, `LOCAL_SCHEMA`, `PUBLIC_SOURCE`

---

## 1. Executive Summary & Architectural Motivation

In earlier iterations of `Codex-Native-Unoffical`, presentation code relied heavily on Flutter's stock Material 3 components (`FilledButton`, `OutlinedButton`, `TextButton`, `IconButton`, `Chip`, `Card`, and `ListTile`). While functional, this introduced visual leakage incompatible with official desktop fidelity:
1. **Material Ink Ripples**: Pointer clicks generated circular expanding splash waves foreign to the desktop Electron/macOS experience.
2. **Material Elevation & Shadows**: Unintentional drop shadows and surface tint shifts distorted the clean flat hierarchy of the official UI.
3. **Inflexible Geometry Defaults**: Material buttons enforce minimum `48×48 px` touch targets and rigid padding scales that conflict with compact desktop density (`36px` nav rows, `30px` composer selector pills, `34px` circular send buttons).

To achieve 1:1 official fidelity while retaining Flutter's robust low-level capabilities (keyboard traversal, focus nodes, accessibility semantics, IME text editing, and `OverlayPortal`), this specification establishes **10 Native Semantic Primitives (`Codex*`)**.

---

## 2. Component Primitives Mapping Matrix

| Semantic Primitive | Target Path in Repo | Replaces Material Widget | Official Desktop Equivalent | Key Measured Tokens Applied | Behavior & Visual Guarantees |
|---|---|---|---|---|---|
| **`CodexButton`** | `lib/src/app/primitives/codex_button.dart` | `FilledButton`, `OutlinedButton`, `TextButton` | Radix button / Tailwind action pill | Radius: `10px`, Height: `32px` / `36px`, Border: `0.5px` hairline | Zero ink ripple; 80 ms subtle background tint transition; supports `primary`, `secondary`, `danger`, `ghost` variants. |
| **`CodexIconButton`** | `lib/src/app/primitives/codex_button.dart` | `IconButton` | Radix icon action button | Radius: `8px` / `10px`, Size: `32px` / `34px` / `36px` | Quiet square icon container; hover highlight with zero elevation change; accessible tooltip binding. |
| **`CodexSidebarRow`** | `lib/src/app/primitives/codex_sidebar_row.dart` | `ListTile`, `ListTileTheme` | `--height-token-row: 36px` nav row | Height: `36px`, Radius: `10px`, Padding: `0 10px` | Single-line title with trailing relative time or status dot; persistent neutral selection tint; keyboard navigable. |
| **`CodexComposer`** | `lib/src/app/primitives/codex_composer.dart` | `Card`, Material `TextField` box | Floating composer container | Max-width: `704px`, Radius: `24px`, Gutters: `12px/10px` | Auto-growing multiline input; bottom action rail; focus ring on keyboard tab; flush-right 34px circular Send/Stop button. |
| **`CodexMessageBubble`** | `lib/src/app/primitives/codex_message_bubble.dart`| Material `Card`, `Container` | User message pill (`--user-message-*`) | Max-width: `75%` (~528px), Radius: `18px`, Tint: `alpha 8%` | Right-aligned prompt bubble; top attachment chips row; auto-collapse over 12 lines / 680 characters with "Show full message". |
| **`CodexActivityRow`** | `lib/src/app/primitives/codex_activity_row.dart` | Material `Card`, `ExpansionTile` | Terminal / Tool invocation card | Radius: `8px`, Height: `34px`, Border: `0.5px` | Terminal glyph, command string in monospace, status indicator, trailing "View output" action trigger. |
| **`CodexPopover`** | `lib/src/app/primitives/codex_popover.dart` | Material `Dialog`, `PopupMenuButton` | Radix Popover primitive | Radius: `16px` / `20px`, Elevation Tier 2 | Anchored overlay positioning; dismisses on outside tap or `Escape`; smoothly transitions without full-screen route blockage. |
| **`CodexMenu`** | `lib/src/app/primitives/codex_menu.dart` | Material `MenuAnchor`, `PopupMenuEntry` | Radix DropdownMenu | Item height: `32px`, Radius: `8px`, Container radius: `16px` | Keyboard arrow up/down selection, hotkey shortcut indicator, divider rules, submenus. |
| **`CodexTooltip`** | `lib/src/app/primitives/codex_tooltip.dart` | Material `Tooltip` | Radix Tooltip | Radius: `16px` pill, Offset: `6px`, Padding: `4px 10px` | Fast 150 ms fade-in; suppresses hit-testing collisions with timeline items; high-contrast dark surface. |
| **`CodexSegment`** | `lib/src/app/primitives/codex_segment.dart` | `SegmentedButton` | Detail mode pill control | Height: `28px`, Radius: `8px`, Padding: `2px` | 3-way toggle (`Prose` / `Commands` / `Execution`); animated slide indicator; zero Material elevation. |

---

## 3. Detailed Primitive Specifications & Contracts

### 3.1 `CodexButton` & `CodexIconButton`

- **Visual Style**: Flat container with optional `0.5px` hairline border.
- **Elevation**: Always `0` (flat surface).
- **Ink Response**: Suppressed. Hover and pressed feedback use pure opacity/color tinting:
  - `hover`: `color-mix(in srgb, var(--color-text-primary) 8%, transparent)`
  - `pressed`: `color-mix(in srgb, var(--color-text-primary) 14%, transparent)`
- **Radius**: `10px` (`OfficialCodexTheme.buttonRadius`).
- **Variants**:
  - `primary`: Solid fill (`#FFFFFF` in dark theme / `#000000` in light theme), inverted high-contrast text.
  - `secondary`: Subtle Tier 2 surface fill (`#2F2F2F` dark / `#F4F4F4` light), hairline border.
  - `ghost`: Transparent surface, reveals tint only on hover/press.
  - `danger`: Red outline/fill on confirmation states.
- **Sizes**:
  - `small`: Height `28px`, font `12px`, padding `0 8px`.
  - `medium` (default): Height `34px`, font `13px`, padding `0 12px`.
  - `large`: Height `40px`, font `14px`, padding `0 16px`.

### 3.2 `CodexSidebarRow`

- **Role**: Render thread entries, project nodes, and primary action buttons in the navigation rail.
- **Height**: Exactly `36px` (`--height-token-row`).
- **Radius**: `10px` (`--radius-token-row`).
- **Padding**: `0 10px` horizontal inset.
- **Layout Structure**:
  - Leading: `16px` icon (e.g. `chat_bubble_outline`, `folder_outlined`, `add`).
  - Title: Expanded single-line text (`13px`, line-height `1.43`), trailing ellipsis on overflow.
  - Trailing: Compact status indicator:
    - Running turn: spinning `12px` progress indicator or accent pulse.
    - Error turn: red status dot.
    - Unread / Inactive: compact relative timestamp (`now`, `5m`, `2h`, `3d`, `1w`).
- **Interactive Feedback**:
  - `hover`: Subtle tint (`alpha 6%`).
  - `selected`: Persistent neutral fill (`alpha 10%`), bold title (`font-weight: 500`).

### 3.3 `CodexComposer`

- **Role**: Bounded floating composer at the bottom of the conversation column.
- **Geometry**:
  - Max width: `704px` (`44rem`), centered.
  - Corner radius: `24px` (`1.5rem`) (or `28px` pill).
  - Background: Elevated surface Tier 2 (`#2F2F2F` dark / `#F4F4F4` light).
  - Border: `1px` subtle hairline (`rgba(255,255,255,0.08)` / `rgba(0,0,0,0.08)`).
  - Insets: `12px` horizontal, `10px` vertical.
- **Sub-components**:
  - **Text Input**: Multiline scrollable field, `14px` font, auto-grow up to `240px` max height.
  - **Action Control Bar**:
    - Left group:
      - `+` Context menu button (`CodexIconButton`).
      - Model + Effort Selector button (`CodexButton` ghost variant).
      - Execution Target button (`Local` / `Worktree` / `SSH`).
      - Permission Mode pill (`Ask` / `Auto-edit` / `Full`).
    - Right group:
      - Voice dictation button.
      - Flush-right `Send` / `Stop` button: `34px` circular diameter.
        - Idle/Has text: Up-arrow icon, primary fill.
        - Running/Active: Square stop icon, red/accent fill.
        - Disabled: Opacity `0.45` when text field is blank or engine is offline.

### 3.4 `CodexMessageBubble`

- **Role**: Render user prompt entries with clear visual boundaries.
- **Alignment**: Flush right in the reading column.
- **Max Width**: Clamped to `75%` of column width (`~528px` on `704px` column).
- **Corner Radius**: `18px` (`--user-message-border-radius`).
- **Background**: Soft translucent tint `light-dark(var(--alpha-05), var(--alpha-08))` (`#2F2F2F` in dark mode).
- **Attachments Row**: Rendered above the message text if files/images are attached:
  - Pill chip: Height `28px`, radius `10px`, icon + truncated path.
- **Content Collapse**: Long prompts exceeding 12 lines or 680 characters display a "Show full message" / "Show less" toggle.

### 3.5 `CodexActivityRow`

- **Role**: Compact representation of tool executions, bash commands, and MCP calls.
- **Height**: `34px`.
- **Corner Radius**: `8px`.
- **Border**: `0.5px` hairline border.
- **Surface**: Subtle elevated card tint.
- **Content**:
  - Leading terminal glyph (`terminal_rounded`) or MCP wrench glyph.
  - Monospace summary text (`12.5px`).
  - Trailing action: `View output` link, triggering the bounded output dialog.

### 3.6 `CodexPopover` & `CodexMenu`

- **Role**: Positioned flyout menus for model selection, project settings, context actions, and search.
- **Container Radius**: `16px` / `20px`.
- **Container Elevation**: Surface Tier 2 with subtle drop shadow (`box-shadow: 0 8px 24px rgba(0,0,0,0.25)`).
- **Item Specs**:
  - Height: `32px`.
  - Corner radius: `8px`.
  - Padding: `0 10px`.
  - Font size: `13px`.
  - Hover feedback: `80ms` background tint without ripple.

### 3.7 `CodexSegment`

- **Role**: 3-way client presentation detail mode switcher (`Prose` / `Commands` / `Execution`).
- **Height**: `28px`.
- **Radius**: `8px`.
- **Surface**: Background Tier 2, border hairline.
- **Selection Pill**: Animated horizontal slide indicator under selected option (`12px` font, weight `500`).

---

## 4. Material Leakage Audit & Elimination Plan

| Material Leakage Source | Affected Native Files | Root Cause | Replacement Strategy |
|---|---|---|---|
| `FilledButton` / `OutlinedButton` | `lib/src/app/presentation/conversation.dart`, `app_shell.dart`, `sidebar_activity.dart` | Default Flutter button choice | Replace with `CodexButton(variant: ...)` |
| `IconButton` | `lib/src/app/presentation/conversation.dart`, `app_shell.dart` | Standard icon button with ink ripple | Replace with `CodexIconButton` |
| `Chip` / `InputChip` | `lib/src/app/presentation/conversation.dart` (attachment chips, mode pills) | Material chip styling & padding | Replace with custom inline chip / `CodexSegment` |
| `Card` | `lib/src/app/presentation/conversation.dart` (composer, approvals) | Material elevation & rounded rect | Replace with `CodexComposer` & custom container |
| `ListTile` | `lib/src/app/presentation/sidebar_activity.dart` | Material navigation row with 48px min height | Replace with `CodexSidebarRow(height: 36)` |
| `InkWell` / `InkResponse` | Across presentation layer | Flutter splash animations | Replace with `GestureDetector` / `Focus` / `HoverListener` |
