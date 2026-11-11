# Official Component Matrix & Semantic Primitives Specification

> **Audited Package**: ChatGPT / Codex Desktop Linux (`26.1103.60933`, `codexBuildNumber: "25894"`, `codexBuildFlavor: "prod"`)
>
> **Target Architecture**: Clean-Room Semantic Presentation Primitives (`lib/src/app/primitives/`) & `OfficialCodexTheme` (`lib/src/app/theme/`)
>
> **Current-state authority:** [Golden State A](OFFICIAL_UI_GOLDEN_STATE_A.md) supersedes historical R0 composition and token claims. User-bubble and activity entries below reflect later verified A6/A7 sources; they do not imply whole-screen parity.
>
> **Evidence Grading**: `STATIC_BUNDLE`, `HUMAN_REVIEWED` (`H1`), `LIVE_OBSERVED` (disposable sign-in gate), `LOCAL_SCHEMA`, `PUBLIC_SOURCE`

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
| **`CodexComposer`** | `lib/src/app/primitives/codex_composer.dart` | `Card`, Material `TextField` box | Floating composer container | Width up to `672px`, active desktop radius `28px` | Auto-growing input, attachment on the left, active controls on the right. Empty and compact Native layouts keep their separate controls row. |
| **`CodexMessageBubble`** | `lib/src/app/primitives/codex_message_bubble.dart`| Material `Card`, `Container` | User message pill (`--user-message-*`) | Actual-parent `70%`, borderless `22px`, `16×10px` padding | Right-aligned prompt bubble with bounded preview and explicit expansion. |
| **`CodexActivityRow`** | `lib/src/app/primitives/codex_activity_row.dart` | Material `Card`, `ExpansionTile` | Inline command and tool activity | Height `34px` | Neutral inline variant on Desktop. The bordered variant remains available for review and compact activity. Output remains on demand. |
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

### 3.2 `CodexSidebarRow` & `rail-with-contextual-sidebar` Shell Hierarchy

- **Shell Hierarchy (`STATIC_BUNDLE` + `H1` `HUMAN_REVIEWED`)**:
  - **Top Application Menu Toolbar (`ApplicationMenuTopBar-SLuX8q`)**: Full-width `36px` (`--height-toolbar-sm`) strip above the rail and page card (`+8px` `--app-shell-titlebar-height` offset in `ApplicationMenuPageSurfaceLayout-yb71ay`), containing the sidebar toggle button (`tr.Q`, `28px`/`36px`) and application menubar (`File`, `Edit`, `View`, `Help`).
  - **Persistent Left Global Icon Rail (`nav[data-app-navigation-rail="true"]`, `lp` / `u$`)**: `52px` (`w-13`: `px-2` + `36px` uniform `size="xl"` icon buttons in `gdzp`; fallback `52` in `X1CL`). Remains visible when the contextual sidebar collapses (`keepVisibleWhenCollapsed: true` -> `closedLeftPanelWidth = railWidth`). Identified destinations: `Home` (`builtin:home`), `Plugins` (`builtin:customize`), account/capability-gated destinations (`KEws`), and bottom Settings trigger (`lh`).
  - **Rounded Inset Page Surface (`PageSurface-g2Llyi`)**: Starts at `inset-inline-start: var(--app-shell-navigation-rail-width)` (`52px` at 1x, `x≈61` in `H1`) and wraps both the contextual `ConversationSidebar-EDF_I4` (`288px` default = `340px` total left panel minus `52px` rail) and `MainContentSurface-EnuIYE` separated by `MainContentLeftBorder-IFAvO_`.
  - **Contextual Sidebar Header & Top Actions (`sO.ic`)**: `52px` (`--sidebar-navigation-header-height`) header row with leading `Codex` dropdown (`vU`/`ht`) and trailing notifications/activity (`sz`), filter (`ut`), and search (`o_.V`), followed by `New chat` (`dE`) and `Your Dot` (`dF`) rows above `Projects` (`bj`).
- **Role**: Render thread entries, project nodes, and primary action buttons in the contextual sidebar.
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
  - Max width is `672px` (`42rem`), centered. See the [current arrangement](OFFICIAL_UI_STRUCTURAL_MAPPING.md).
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
- **Verified mapping**: build `25894` `14353.vHM0` / `dKZq`, `.bubble-vBnidZ` and `225284` attachment composition; translated in `77d3401`.
- **Width**: `70%` of the actual available parent column; wide/narrow independent fill scans are recorded in Golden State A.
- **Shape**: Borderless `22px` corners, `16×10px` padding and `5%` ink tint.
- **Text**: Normal `14px` role, `1.625` line height.
- **Attachments**: Separate bounded pills `8px` above the bubble. Attachment-only messages have no empty text bubble. Thumbnail/preview fidelity remains open.
- **Disclosure**: More than 20 rendered lines shows `Show more` / `Show less`, with `10px` total separation (4px flex gap plus 6px margin). Native collapsed selectable text uses a bounded prefix; full toolbar Copy remains exact. This differs from official CSS clipping and is not claimed identical.
- **Bounds**: Existing saved/live source caps and 16-attachment cap remain; collapse measurement is bounded and cached per message.

### 3.5 `CodexActivityRow`

- **Role**: Compact representation of tool executions, bash commands, and MCP calls.
- **Current composition**: Quiet borderless inline row, `20px` minimum line box, `14px` leading icon and `6px` icon gap; grouped rows use `4px` spacing (`ff931b9` / `7012dd3`).
- **Hierarchy**: Thought disclosure, saved completed-turn divider and activity/output actions share the timeline rather than individual elevated cards.
- **Bounds**: Saved activity retains its `224px` lazy viewport, reasoning its `140px` viewport, and output remains on demand.
- **Remaining deltas**: Captions, live grouping and richer reasoning presentation remain explicit A7 work. Default foreground/type refinement is active Track U1; this entry does not close it.

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
