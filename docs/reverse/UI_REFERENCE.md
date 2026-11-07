# ChatGPT Desktop (`26.1103.32239`) — UI Design System & Product Logic Reference

> **Provenance Tag Legend**
> Every visual and behavioral specification in this document carries an explicit provenance tag:
> - `[observed live]`: Verified against live running desktop behavior and human-review screenshots.
> - `[derived from computed style]`: Extracted directly from the 585 CSS bundles (`2,970` CSS custom properties across `@layer base, theme, properties, components, utilities`) and component style bindings (`KkZX`, `qbQ6`, `g.r`).
> - `[static bundle only]`: Verified in the compiled JS/CSS bundle (`182735.d3d917f28d.js`, `324258.54c339c9b6.js`, `622051.ab246b5c4d.js`, `early-bootstrap-920`) for surfaces gated by account/platform flags.
> - `[estimated from screenshot]`: Visual proportion cross-checked against screenshots where dynamic container units (`cqw`/`cqh`) depend on window size.

---

## 1. Foundational Design Tokens (`@layer theme, properties`)

### 1.1 Spacing & Grid Scale (`[derived from computed style]`)

- **Base Unit (`--spacing`)**: `4px` (`0.25rem`). All layout paddings, gaps, and control heights are multiples of `--spacing`.
- **Standard Padding Tokens**:
  - `--padding-XS`: `4px` (`0.25rem`)
  - `--padding-SM`: `8px` (`0.5rem`)
  - `--padding-MD`: `12px` (`0.75rem`)
  - `--padding-LG`: `16px` (`1rem`)
  - `--padding-XL`: `24px` (`1.5rem`)
  - `--padding-2XL`: `32px` (`2rem`)
  - `--padding-panel-base`: `20px` (`calc(var(--spacing) * 5)`)
  - `--padding-row-x`: `8px`

### 1.2 Corner Radius Scale (`[derived from computed style]`)

- **Corner Radius Scale Factor**:
  - Default Chat/Web (`--corner-radius-scale`): `1`
  - Codex Desktop (`--codex-corner-radius-scale`): `1.25` (`--codex-corner-shape: round`)
- **Radius Tokens**:
  - `--radius-2xs-base`: `2px` (`0.125rem`)
  - `--radius-xs`: `4px` (`0.25rem`)
  - `--radius-sm-base`: `6px` (`0.375rem`)
  - `--radius-md-base`: `8px` (`0.5rem`)
  - `--radius-lg`: `10px` (`--radius-token-row: 10px`, `--control-radius-lg: 10px`)
  - `--radius-xl-base`: `12px` (`0.75rem`; `15px` when scaled by `1.25`)
  - `--radius-2xl`: `22px` (`calc(var(--spacing) * 5.5)`)
  - `--radius-3xl-base`: `20px` (`1.25rem`)
  - `--radius-4xl-base`: `24px` (`1.5rem`; `30px` when scaled by `1.25` — used by `--composer-radius`)
  - `--radius-full` / `--radius-circle`: `9999px`

### 1.3 Color Palette & Theme Architecture (`[derived from computed style]`, `[observed live]`)

ChatGPT Desktop uses CSS `light-dark(<light>, <dark>)` tokens paired with three built-in theme presets (`app-default`, `codex-system`, `space-system`):

| Semantic Token | Light Mode Value | Dark Mode Value | Usage |
| :--- | :--- | :--- | :--- |
| `--app-color-background-surface-under` / `--color-token-side-bar-background` | `#f9f9f9` (`--gray-fixed-50`) | `#000000` (`black`) | Window base / Sidebar background (`[derived from computed style]`) |
| `--app-color-background-surface` / `--color-surface` | `#ffffff` (`--gray-fixed-0`) | `#181818` (`--gray-fixed-900`) | Primary main content surface (`[derived from computed style]`) |
| `--main-surface-primary` | `#ffffff` | `#212121` | Chat canvas surface (`[derived from computed style]`) |
| `--color-surface-secondary` / `--bg-elevated-secondary` | `#e8e8e8` / `#f3f3f3` | `#303030` / `#212121` | Secondary cards, code blocks, activity rows (`[derived from computed style]`) |
| `--color-surface-tertiary` | `#f3f3f3` | `#414141` | User message bubble (`--color-background-user-message`), compact action cards (`[derived from computed style]`) |
| `--color-surface-elevated-secondary` / `--composer-layout-surface-background` | `#ffffff` (`--gray-fixed-0`) | `#181818f0` / `#282828` (`--gray-fixed-750`) | Floating composer & popover surface (`[derived from computed style]`) |
| `--color-text` / `--gray-1000` | `#0d0d0d` | `#ffffff` | Primary prose & heading text (`[derived from computed style]`) |
| `--app-color-text-foreground` | `#1a1c1f` | `#dfdfdf` (`--gray-fixed-150`) | App chrome & code foreground (`[derived from computed style]`) |
| `--color-text-secondary` | `#5d5d5d` | `#cdcdcd` | Secondary labels, activity summaries, timestamps (`[derived from computed style]`) |
| `--color-text-tertiary` | `#8f8f8f` | `#afafaf` | Placeholders, muted metadata, subtle icons (`[derived from computed style]`) |
| `--color-border` | `#0000001a` (10% black) | `#ffffff26` (15% white) | Standard card/popover border (`[derived from computed style]`) |
| `--color-border-light` / `--color-border-subtle` | `#0000000d` (5% black) | `#ffffff0d` (5% white) | Hairline dividers (`--border-width-hairline: 0.5px`) (`[derived from computed style]`) |
| `--app-color-accent-blue` / `--color-text-info` | `#3a83f7` (`--blue-400`) | `#339cff` / `#63a8f8` | Primary interactive accent, links, active badges (`[derived from computed style]`) |
| `--app-color-editor-added` / `--color-codex-diff-added` | `#00a240` (`--green-500`) | `#40c977` (`--green-300`) | Diff additions (`+N`) (`[derived from computed style]`) |
| `--app-color-editor-deleted` / `--color-codex-diff-deleted` | `#ba2623` (`--red-600`) | `#fa423e` (`--red-400`) | Diff deletions (`-M`) (`[derived from computed style]`) |
| `--app-color-accent-orange` | `#e25507` (`--orange-500`) | `#fb6a22` (`--orange-400`) | Approval/warning badges (`[derived from computed style]`) |

### 1.4 Typography Scale (`[derived from computed style]`)

- **Font Families**:
  - `--font-sans-default`: `-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`
  - `--font-openai-sans`: `"OpenAI Sans", var(--font-sans-default)`
  - `--font-mono-default`: `ui-monospace, "SFMono-Regular", "SF Mono", menlo, consolas, "Liberation Mono", monospace`
- **Font Weights**:
  - `--font-weight-light`: `300`
  - `--font-weight-normal`: `400`
  - `--font-weight-medium`: `510`
  - `--font-weight-semibold`: `590`
  - `--font-weight-bold`: `700`
- **Font Sizes & Line Heights**:
  - `--text-unread-badge` / `--app-menu-item-font-size`: `11px` (`weight: 590`, `tracking: -0.15px`)
  - `--text-xs`: `12px` (`line-height: 16px` / `1.333`)
  - `--text-control-label` / `--menu-font-size`: `13px` (`0.8125rem`, `weight: 510`, `line-height: 18px`, `tracking: -0.08px`)
  - `--text-sm` / `--text-document` / `--text-page-body`: `14px` (`line-height: 20px` / `1.428`, `tracking: -0.15px`) — **Default Codex chat & markdown body size**
  - `--codex-chat-code-font-size`: `11pt` (`~14.67px`) or `--diffs-font-size: 13px` (`line-height: 20px`)
  - `--text-base` / `--text-composer-control`: `16px` (`line-height: 24px` / `1.5`)
  - `--text-lg` / `--text-heading-sm`: `18px` (`line-height: 28px`)
  - `--text-xl` / `--text-heading-md`: `20px` (`line-height: 28px`)
  - `--text-card-title`: `22px` (`weight: 510`, `line-height: 28px`, `tracking: -0.26px`)
  - `--text-2xl` / `--text-heading-lg`: `24px` (`line-height: 32px`)
  - `--text-heading-app`: `28px`

### 1.5 Elevations, Shadows, and Motion (`[derived from computed style]`)

- **Shadows**:
  - `--elevation-composer`: `0 0 0 1px #0000000a, 0 2px 8px 0 #0000000a, 0 4px 80px 8px #00000006` (Dark mode adds `--elevation-composer-dark: inset 0 0 1px 0 #fff3`)
  - `--elevation-sidebar`: `0 0 0 0.5px var(--color-border-strong), 0 3px 7.5px #00000008, 0 0 16px #00000005`
  - `--shadow-card`: `0px 4px 16px 0px #0000000d`
  - `--shadow-popover-overlay`: `0px 4px 8px -2px #0000001a`
- **Transitions & Springs**:
  - `--transition-duration-basic`: `150ms` (`0.15s`)
  - `--transition-duration-moderate`: `200ms` (`0.2s`)
  - `--transition-duration-relaxed`: `300ms` (`0.3s`)
  - `--animation-duration-streaming-text`: `700ms` (`0.7s`)
  - `--cubic-enter`: `cubic-bezier(0.19, 1, 0.22, 1)`
  - `--ease-enter-snappy`: `cubic-bezier(0.23, 1, 0.32, 1)`
  - `--ease-card`: `cubic-bezier(0.16, 1, 0.3, 1)`
  - `--ease-spring-snappy`: `linear(0, 0.086, 0.2539, 0.428, 0.5786, 0.698, 0.7879, 0.8534, 0.8998, 0.9323, 0.9546, 0.9697, 0.98, 0.9868, 0.9913, 0.9943, 0.9963, 0.99...)`

---

## 2. Application Shell & Layout Geometry

### 2.1 Shell Structure (`[derived from computed style]`, `[observed live]`)

```text
+-----------------------------------------------------------------------------------+
| Sidebar (Under-Surface #f9f9f9 / #000) | Main Surface Card (#fff / #181818)       |
| Width: default 275-340px               | Top-Start Radius: 12-15px (--radius-xl)  |
| Clamp: min 240px, max 520px            | Hairline border: 0.5px                   |
|----------------------------------------+------------------------------------------|
| Sidebar Header (52px)                  | Thread Toolbar Header (46px)             |
| [SidebarToggle] [Everyday|Coding] [+]  | [Title / Project / Branch] [Open] [+N-M] |
|----------------------------------------+------------------------------------------|
| Primary Nav Rows (New, Search,         | Centered Reading Column                  |
|   Automations, Skills/Plugins)         |   Codex max-width: 40rem (640px)         |
|                                        |   Chat max-width: 800px                  |
| Pinned Threads                         |   Body padding: 20px (--padding-panel)   |
|                                        |                                          |
| Projects / Recents                     |   [User Bubble: right, max 70% width]    |
|   > Project Folder                     |   [Assistant Activity / Markdown Prose]  |
|     - Thread Row (10px radius)         |                                          |
|     - Thread Row                       |   +----------------------------------+   |
|                                        |   | Floating Composer (--radius-4xl) |   |
|----------------------------------------+   | Overhang: 24px each side         |   |
| Sidebar Footer (Settings / Account)    |   +----------------------------------+   |
+-----------------------------------------------------------------------------------+
```

### 2.2 Exact Shell Metrics & Logic (`qbQ6`, `KkZX` in `182735.d3d917f28d.js`)

| Metric / Token | Exact Value | Backing Logic & Behavior |
| :--- | :--- | :--- |
| **Sidebar Width (`qbQ6`)** | Default `340px` (CSS token `--spacing-token-sidebar`: `clamp(240px, 275px, min(520px, calc(100vw - 320px)))`); drag-clamped to `[240px, min(520px, windowWidth - 240px)]` (`[derived from computed style]`) | Persisted under key `"sidebar-width"`. Below `768px` (`mk: "(min-width: 768px)"`), sidebar collapses into an overlay sheet. |
| **Sidebar Header Height** | `52px` (`--sidebar-navigation-header-height: calc(var(--spacing) * 13)`) (`[derived from computed style]`) | Houses sidebar collapse toggle, `ProductModeToggle` (`32px` height), and quick New Thread button. |
| **Main Toolbar Height** | `46px` (`--height-toolbar: 46px`, `--height-toolbar-pane: 40px`, `--height-toolbar-sm: 36px`) (`[derived from computed style]`) | Sticky top bar inside the main surface with `backdrop-filter: blur(4px)`. |
| **Main Surface Inset & Radius** | `--app-shell-main-surface-top-start-radius: var(--radius-xl-base)` (`12px` / `15px`), border `0.5px` (`--border-width-hairline`) (`[derived from computed style]`) | The sidebar sits on `--app-color-background-surface-under` (`#f9f9f9` light / `#000000` dark) with **no hard vertical divider** (`--app-shell-sidebar-divider: transparent`); the main content area is an elevated rounded surface card with `--app-shell-page-surface-shadow`. |
| **Thread Reading Column Width** | `--thread-content-max-width: 40rem` (`640px`) in Codex/compact mode; `--chat-max-width: 800px` in standard Chat; `--wb-editor-page-max-width: min(48rem, calc(100vw - 2rem))` (`768px`) (`[derived from computed style]`) | Wrapper `KkZX` sets `--thread-body-max-width: calc(var(--thread-content-max-width) + var(--thread-body-inline-padding, 0px) * 2)` (`640px + 2 * 20px = 680px` outer box). When a right-hand floating panel (diff/browser/canvas) is open at `@[900px]/app-shell-main-content`, right padding reserves `calc(var(--thread-floating-panel-width) + 20px)`. |
| **Item Vertical Spacing** | `--conversation-item-gap: 16px`, `--conversation-grouped-item-gap: 4px` (`[derived from computed style]`) | Consecutive tool/activity items within the same turn group tightly (`4px`); top-level user/assistant turns separate by `16px`. |

---

## 3. Component-by-Component UI & Product Logic Mapping

### 3.1 Sidebar (`local_thread_catalog` + `sidebarProductMode`)

- **Visual Structure (`[derived from computed style]`, `[observed live]`)**:
  - Top scroll fade mask (`--sidebar-scroll-header-fade-distance: 16px`) and bottom scroll fade mask (`--sidebar-scroll-footer-fade-distance: 40px`).
  - **Row geometry**: `--radius-token-row: 10px`, horizontal padding `--padding-row-x: 8px`, label inset `--sidebar-row-label-inset: calc(var(--height-token-row) + 2px)`, hover background `--codex-row-hover: color-mix(in srgb, var(--color-text-primary) 5%, transparent)`.
  - **Indicators**:
    - Unread dot (`--radius-unread-badge: 4px`, `--text-unread-badge: 11px`, `weight: 590`).
    - Running spinner / pulsing dot (`--animate-token-pulsing-dot: token-pulsing-dot 1.25s infinite ease-in-out`).
    - Diff stat pill (`+N` in `--color-codex-git-added`, `-M` in `--color-codex-git-deleted`).
    - Hover actions (`--sidebar-row-action-opacity: 0` -> `1` on hover): Pin, Archive, Rename, Move to Project.
- **Backing Product Logic (`[static bundle only]`, `[observed live]`)**:
  - **Zero-flicker startup**: `window.electronBridge.getInitialSidebarBootstrap()` synchronously loads cached projects and top recents before React mounts.
  - **Mode-aware filtering (`622051.ab246b5c4d.js`)**:
    - When `sidebarProductMode === "work"` ("Everyday"): Shows `Recents` (Chat + Work threads from `chatgpt:<accountId>:<userId>` and local Work threads) + unified Projects (`g-p-*` gizmos and local projects with `chatGptBacking`).
    - When `sidebarProductMode === "codex"` ("Coding"): Groups threads under local/remote workspace **Project folders** (`state_5.sqlite` `projects` + `project_roots`), with projectless threads in a separate `Recents` list (`electron:projectless-thread-ids`).
  - **Pagination**: Loads 50 threads per host initially; scrolling triggers `ThreadCatalogSyncManager` cursor/offset pagination (`limit: 100` for `/backend-api/conversations`, `limit: 50` for `app-server` `thread/list`).

### 3.2 Thread Header & Mode Switch (`[derived from computed style]`, `[observed live]`)

- **Height**: `46px` (`--height-toolbar`).
- **Left cluster**:
  - When sidebar is collapsed, displays the expand-sidebar button and traffic-light clearance (`--window-titlebar-inset-left: 8px`).
  - Thread title (`14px`, `weight: 510`, single-line ellipsis) + Project folder badge / Git branch chip (`codex/...`).
- **Right cluster (Codex mode)**:
  - **Open in IDE dropdown** (`open-in-target-preferences`: VS Code, Cursor, Windsurf, Zed, Terminal, Finder/Files).
  - **Git / PR actions**: Commit, Push, Create PR (with CI check status dot `--pr-status-dot-color` from `p4FI`: `passing`, `pending`, `failing`).
  - **Diff toggle pill**: Shows live `+added -deleted` counts and toggles the right-hand Diff Inspector drawer.
  - **Terminal toggle**: Toggles the `node-pty` integrated terminal drawer.

### 3.3 Conversation Timeline: User Messages & Structured Input Chips (`[derived from computed style]`, `[observed live]`)

- **User Message Bubble**:
  - Alignment: Right-aligned (`ml-auto`).
  - Width: `--user-chat-width: 70%` maximum width (`[derived from computed style]`).
  - Surface: `--color-background-user-message: var(--color-surface-tertiary)` (`#f3f3f3` in light mode, `#414141` in dark mode) or `--user-message-background-color: light-dark(var(--alpha-05), var(--alpha-08))`.
  - Corner radius: `--message-bubble-radius: 11px` (`calc(15px - 4px)`) or `16px` (`--radius-2xl`) for multi-line bubbles.
- **How Pasted Files, IDE Context, and Mentions Are Handled (Answering Section 9.5)**:
  - When a user attaches files, selects IDE lines, or pastes large snippets, `codex-rs` / `app-server` serializes them into a single text block using markdown headers (`# Files mentioned by the user:`, `# Context from my IDE setup:`, `## My request for Codex:`).
  - In the official UI, raw scaffolding headers are **parsed and stripped from the visible user bubble**, rendering the referenced paths as compact **file/mention chips** above the extracted user request (`## My request for Codex:`), while preserving the full structured items (`type: "mention" | "localImage" | "skill" | "text"`) in the composer and turn state.

### 3.4 Conversation Timeline: Assistant Prose vs Activity Rows (`[derived from computed style]`, `[static bundle only]`)

- **Assistant Markdown Prose**:
  - Full width of the reading column (`640px` in Codex, `800px` in Chat).
  - Font size: `--markdown-font-size: 14px` (`--text-document`), line height `18px–20px` (`calc(var(--markdown-font-size) + 4px)`), paragraph spacing `--markdown-space: 3.5px`.
  - Wide blocks (tables, charts, code blocks): can bleed up to `--markdown-wide-block-max-width: 64rem` (`1024px`).
- **Detail-Mode Dependent Tool & Reasoning Presentation (`324258.54c339c9b6.js`)**:
  - **`STEPS_PROSE` ("Everyday" / Work)**:
    - Consecutive tool calls (`commandExecution`, `fileChange`, `mcpToolCall`, `webSearch`) are collapsed into a single muted summary pill (`--agent-activity-summary-color`, `13px`) such as *"Explored 4 files, ran 2 commands"* or *"Worked for 1m 14s"* with a disclosure chevron (`--icon-disclosure-size: 12px`).
  - **`STEPS_COMMANDS` ("Coding" / Codex)**:
    - Displays individual compact command/edit cards (`--conversation-grouped-item-gap: 4px`) with status icon, command string in `--font-mono`, duration, and one-click expansion for bounded stdout/stderr or unified diff hunks.

### 3.5 Composer (`g.r` in `182735.d3d917f28d.js`, `324258.54c339c9b6.js`)

- **Geometry & Overhang (`[derived from computed style]`)**:
  - Width: `--composer-adjacent-max-width: calc(var(--thread-content-max-width) + var(--composer-inline-overhang) * 2)` where `--composer-inline-overhang: 24px` (`calc(var(--spacing) * 6)`). Thus in a `640px` reading column, the composer spans **`688px`** (`24px` wider on each side than the prose column!).
  - Corner radius: `--composer-radius: var(--radius-4xl)` (`24px` base, `30px` with Codex `1.25x` scale).
  - Min height: `--min-height-composer: 44px` (`calc(var(--spacing) * 11)`); single-line editor height `36px` (`calc(var(--spacing) * 9)`).
  - Max height before internal scroll: `--frame-height-cap: min(25dvh, 7lh)` (or expanded mode `calc(100svh - 46px - 128px)`).
  - Surface & shadow: `--composer-layout-surface-background: var(--color-surface-elevated-secondary)` with `--elevation-composer`.
- **Internal Structure & Controls (`[static bundle only]`, `[observed live]`)**:
  - **Top Tray (`--composer-top-tray-background`)**: Queued follow-up messages (`queued-follow-ups`), active task progress bar, or context attachments (`--composer-attachment-inset: 8px`).
  - **ProseMirror Rich Input**: Supports `@` file/folder mentions (`fuzzyFileSearch`), `$` skills, `app://` connectors, and `plugin://` browser tab mentions (`tab-v1`).
  - **Adaptive Footer (`AdaptiveFooter` in `324258.54c339c9b6.js`)**:
    - Left controls: `+` Attachment / Plugin menu (`--height-composer-plugins-menu: 480px`), Execution target picker (`Local` / `Worktree` / `Cloud` / `Remote Host`), Permission mode (`Suggest` / `Auto-edit` / `Full access`).
    - Right controls: Model & Reasoning Effort picker (`--model-picker-content-width: 254px` with interactive power slider `minimal | low | medium | high | xhigh`), Dictation mic button (`FyCz` hold vs single-tap toggle, `400ms` double-tap threshold), and Primary Action button (`Send` arrow / `Stop` square / `Steer` queue button when streaming).

---

## 4. Responsive Breakpoints & Keyboard Shortcuts

### 4.1 Breakpoints (`[derived from computed style]`)

| Token / Media Query | Width | Layout Adaptation |
| :--- | ---: | :--- |
| `--breakpoint-xs` | `320px` (`20rem`) | Minimum supported compact/mini-window width (`codex-micro-layout`). |
| `--breakpoint-sm` | `640px` (`40rem`) | Single-column reading width cap; composer controls wrap or condense into icon-only triggers. |
| `qbQ6.mk` (`768px`) / `--breakpoint-md` | `768px` (`48rem`) | Sidebar transitions from persistent split pane to modal drawer. |
| `@[900px]/app-shell-main-content` | `900px` | Main content container query threshold where right-hand Diff/Browser/Artifact panels dock side-by-side instead of overlaying the thread column. |
| `--breakpoint-lg` / `--breakpoint-xl` / `--breakpoint-2xl` | `1024px` / `1280px` / `1536px` | Wide-block markdown (`64rem`) and side-by-side diff split view thresholds. |

### 4.2 Primary Keyboard Shortcuts (`[static bundle only]`, `[observed live]`)

| Action | macOS Shortcut | Linux / Windows Shortcut | Command ID / Handler |
| :--- | :--- | :--- | :--- |
| New Thread | `Cmd + N` | `Ctrl + N` | `newThread` |
| Command Palette / Search | `Cmd + K` | `Ctrl + K` | `commandMenu.toggle` |
| Toggle Sidebar | `Cmd + B` | `Ctrl + B` | `toggleSidebar` |
| Toggle Plan Mode in Composer | `Shift + Tab` / `Cmd + Shift + P` | `Shift + Tab` / `Ctrl + Shift + P` | `composer.togglePlanMode` |
| Navigate Back / Forward | `Cmd + [` / `Cmd + ]` | `Alt + Left` / `Alt + Right` | `navigateBack` / `navigateForward` |
| Switch Recent Threads | `Ctrl + Tab` | `Ctrl + Tab` | `ctrl-tab-shortcut-notice-shown` |
| Send Message | `Enter` | `Enter` | `composer.submit` |
| Insert Newline | `Shift + Enter` | `Shift + Enter` | `composer.newline` |
