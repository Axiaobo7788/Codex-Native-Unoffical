# ChatGPT Desktop UI & Design Token Reference (Recalibrated)

> **Evidence Sources**:
> - `STATIC_BUNDLE`: `webview/assets/index-CSK6N93K.css` (1,076 KB, 9 CSS `@layer` groups, 1,710 CSS custom properties) and `webview/assets/index-Dup49xH6.js` + lazy chunks.
> - `LIVE_OBSERVED`: Live Chromium DevTools (`http://127.0.0.1:9333`) computed styles from the running ChatGPT Desktop (`26.326.51703`) renderer.
> - `PUBLIC_DOC`: First-party OpenAI Codex Desktop & ChatGPT Desktop help/product documentation.

---

## 0. Evidence & Adoption Calibration Summary

| UI Surface / Token Group | Primary Evidence | Support / Adoption Classification | Current `Codex-Native-Unoffical` `HEAD` Status |
|---|---|---|---|
| **CSS Layer Cascade & Design Tokens** (`--sidebar-width: 240px`, `--thread-content-max-width: 44rem`, `--radius-*`) | `STATIC_BUNDLE`, `LIVE_OBSERVED` | `COPY_MEASURED_BEHAVIOR` (tokens & layout proportions) | Already aligned on desktop shell geometry, dark/light surfaces, and `720px` (`~45rem`) centered thread column |
| **Product Mode Switcher (`Chat \| Work \| Codex`)** | `STATIC_BUNDLE`, `LIVE_OBSERVED` | `RESEARCH_MORE` / Future multi-mode shell (do not implement in current phase) | Currently single-mode **Codex Desktop** shell |
| **Detail Level Selector (`STEPS_PROSE \| STEPS_COMMANDS \| STEPS_EXECUTION`)** | `STATIC_BUNDLE` (`.vite/build/early-bootstrap.js @271830`, `worker.js @832956`) | `ADOPT_PATTERN` (client-side presentation filter only; **never** copy `a2` system prompt) | Currently renders collapsed `_TurnWorkDivider` (`"Worked for Xm Ys ›"`) and inline command cards; no 3-way detail toggle yet |
| **Bottom-Anchored Conversation Viewport** | `STATIC_BUNDLE`, `LIVE_OBSERVED` | `KEEP_OUR_ADVANTAGE` / `ADAPT_NATIVE` | Already implemented via `_ConversationScrollView extends CustomScrollView(anchor: 1.0)` + `_RenderConversationViewport` (`lib/src/app/presentation/conversation.dart:688-796`) |
| **User Message Envelope & Attachment Chips** | `PUBLIC_SOURCE`, `STATIC_BUNDLE` | `KEEP_OUR_ADVANTAGE` + targeted refinement | Already implemented in `parseUserMessagePresentation` (`lib/src/domain/history_models.dart:69-194`) and `HistoryProtocolAdapter._userAttachments` (`lib/src/protocol/history_protocol.dart:177-229`) |

---

## 1. CSS Cascade Layer Architecture (`STATIC_BUNDLE`)

The renderer stylesheet (`webview/assets/index-CSK6N93K.css`) declares a strict 9-layer cascade:

```css
@layer properties, theme, base, radix, prose, components, utilities, Legacy, overrides;
```

1. `properties`: `@property` houdini declarations for animated gradients, borders, and shimmer masks.
2. `theme`: Semantic light/dark/black color tokens, elevation shadows, radii, and spacing variables.
3. `base`: Reset rules, root font families, scrollbars, and selection highlights.
4. `radix`: Primitives for Popover, Dialog, DropdownMenu, Tooltip, Accordion, and Tabs (`@radix-ui/*`).
5. `prose`: Markdown typography (`--prose-*`), tables, lists, blockquotes, and inline code rules.
6. `components`: Shell chrome, sidebar rows, thread timeline items, composer, diff viewer (`@pierre/diffs`), and approval banners.
7. `utilities`: Tailwind v4 utility classes.
8. `legacy` / `overrides`: Platform-specific Electron window-controls and high-contrast overrides.

---

## 2. Measured Shell & Layout Tokens (`STATIC_BUNDLE` + `LIVE_OBSERVED`)

| Token / Property | Value in `index-CSK6N93K.css` (`STATIC_BUNDLE`) | Live Computed Value (`LIVE_OBSERVED`) | Usage |
|---|---|---|---|
| `--app-shell-titlebar-height` | `36px` (`macOS: 38px`) | `36px` | Custom drag region / window header bar |
| `--sidebar-width` | `240px` (resizable `220px..360px`, default open `260px` on wide viewports) | `260px` | Left navigation rail width |
| `--sidebar-collapsed-width` | `0px` | `0px` | Collapsed sidebar state |
| `--thread-content-max-width` | `44rem` (`704px`, wide mode `48rem` / `768px`) | `704px` | Centered conversation & composer column |
| `--composer-max-width` | `44rem` (`704px`) | `704px` | Floating bottom composer container |
| `--composer-border-radius` | `24px` (`1.5rem`) | `24px` | Rounded pill/card composer surface |
| `--user-message-border-radius` | `18px` (`1.125rem`) | `18px` | Right-aligned user message bubble |
| `--user-message-max-width` | `75%` of thread column (`~528px`) | `528px` | User bubble width cap |
| `--radius-xs` / `sm` / `md` / `lg` / `xl` / `2xl` | `4px` / `6px` / `8px` / `12px` / `16px` / `24px` | Verified | Component corner radii |

---

## 3. Color Palette & Surface Hierarchy (`STATIC_BUNDLE` + `LIVE_OBSERVED`)

| Surface Role | Dark Theme (`LIVE_OBSERVED` / `STATIC_BUNDLE`) | Light Theme (`STATIC_BUNDLE`) | Current `Codex-Native-Unoffical` Equivalent |
|---|---|---|---|
| App Shell / Sidebar Background | `#171717` (`rgb(23, 23, 23)`) | `#F9F9F9` (`rgb(249, 249, 249)`) | `_Palette` dark/light sidebar surface in `lib/src/app/app.dart` |
| Main Content Panel Surface | `#212121` (`rgb(33, 33, 33)`) | `#FFFFFF` (`rgb(255, 255, 255)`) | Inset rounded workspace panel in `lib/src/app/app.dart` |
| Elevated Card / Composer Surface | `#2F2F2F` (`rgb(47, 47, 47)`) | `#F4F4F4` (`rgb(244, 244, 244)`) | Composer & card surface |
| User Message Bubble | `#2F2F2F` (`rgb(47, 47, 47)`) | `#F4F4F4` (`rgb(244, 244, 244)`) | Right-aligned bubble in `conversation.dart` |
| Primary Text | `#ECECEC` (`rgb(236, 236, 236)`) | `#0D0D0D` (`rgb(13, 13, 13)`) | Primary foreground text |
| Secondary / Muted Text | `#B4B4B4` / `#8E8E8E` | `#5D5D5D` / `#8F8F8F` | Metadata, timestamps, collapsed step summaries |
| Subtle Border / Hairline | `rgba(255, 255, 255, 0.08)` | `rgba(0, 0, 0, 0.08)` | `1px` card/panel borders |
| Diff Addition / Deletion | `#1E4620` / `#5A1E1E` (text `#4ADE80` / `#F87171`) | `#DCFCE7` / `#FEE2E2` | Diff viewer hunk colors |

---

## 4. Typography System (`STATIC_BUNDLE` + `LIVE_OBSERVED`)

- **UI & Prose Font Stack (`--font-sans`)**:
  `ui-sans-serif, -apple-system, system-ui, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif`
- **Monospace Font Stack (`--font-mono`)**:
  `ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace`
- **Measured Type Scale**:
  - Thread body prose: `14px` (`0.875rem`), `line-height: 1.6` (`22.4px`) in Codex/Work dense mode; `15px..16px` (`line-height: 1.65`) in standard Chat prose.
  - Code blocks & terminal output: `12.5px..13px`, `line-height: 1.5`.
  - Sidebar thread title: `13px`, `font-weight: 400` (`500` when active/unread), single-line ellipsis.
  - Sidebar section header (`Projects`, `Recents`, `Pinned`): `11.5px`, `font-weight: 600`, muted foreground.
  - Collapsed tool/step summary row: `13px`, muted foreground with hover highlight.

---

## 5. Component Anatomy & Presentation Modes

### 5.1 Sidebar (`STATIC_BUNDLE` + `LIVE_OBSERVED`)
- **Top Action Block**: `New thread` (`Cmd/Ctrl+N`), `Search` (`Cmd/Ctrl+K`), `Automations`, `Skills & Plugins`.
- **Pinned & Custom Sections**: Threads or projects pinned to top or organized into user/agent-created custom sections (`sidebarCustomSectionsEnabled`).
- **Projects Hierarchy**: Collapsible project folders grouped by normalized workspace root (`cwd` / `project_id`), showing nested thread rows with relative time (`2h`, `3d`), running spinner or unread badge, and `+N -M` diff summary pills.
- **Recents (Projectless / Chat / Work)**: Filtered by `sidebarProductMode` (`chat` -> `source_kind = 'chatgpt' AND conversation_origin IS NOT 'tpp'`; `work` -> `conversation_origin = 'tpp'` or Work threads; `codex` -> `source_kind IN ('local', 'ssh', 'cloud')`).

### 5.2 Conversation Timeline & Turn Detail Modes (`STATIC_BUNDLE`)
In `.vite/build/early-bootstrap.js @271830` and `webview/assets/async/182735.d3d917f28d.js`:
- **`STEPS_PROSE` ("Everyday / Non-technical UI")**:
  - Hides intermediate shell/bash command execution cards and technical tool logs by default, surfacing only prose updates, high-level progress summaries, and final outputs/artifacts (`writing_blocks`).
  - Also sets `includeProseDetailLevelInstructions: true` in `<app-context>` (`early-bootstrap-339 @780000`) when starting/turning a Codex/Work thread—an internal prompt injection that `Codex-Native-Unoffical` must **not** copy (`AGENTS.md` Rule #1).
- **`STEPS_COMMANDS` (Default in Codex)**:
  - Collapses intermediate exploration/command steps behind a compact summary divider (`"Worked for Xm Ys ›"` / `"Ran N commands"`) while keeping key command cards and file-change summaries accessible on click.
  - **Current `Codex-Native-Unoffical` `HEAD` status**: Already implements `_TurnWorkDivider` (`"Worked for Xm Ys ›"`) with on-demand `HistoryController.loadTurnItems(turnId)` (`thread/items/list` with `deferOutput: {'commandExecution': true}`).
- **`STEPS_EXECUTION` ("Verbose / Full Execution")**:
  - Expands all intermediate reasoning summaries, command executions, MCP tool calls, and file patches inline by default.

### 5.3 Floating Composer (`STATIC_BUNDLE` + `LIVE_OBSERVED`)
- **Bottom Pill Container**: `border-radius: 24px`, `1px` subtle border, auto-growing multiline input (`max-height: 240px`).
- **Bottom Control Bar**:
  - Left: `+` attachment/context menu (`localImage`, file mention `@`, skill `$`), model + reasoning-effort selector (`low | medium | high | xhigh`), execution target / host selector (`Local`, `Worktree`, `SSH`, `Cloud`), and permission/approval mode pill (`Ask`, `Auto-edit`, `Full access`).
  - Right: Voice dictation button and primary Send (`ArrowUp`) / Stop (`Square`) button.
