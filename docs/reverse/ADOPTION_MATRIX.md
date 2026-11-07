# ChatGPT Desktop (`26.1103.32239`) vs `Codex-Native-Unoffical` — Adoption Matrix & Architecture Recommendations

> **Scope**: Maps every official ChatGPT Desktop subsystem against our current Flutter + Rust (`codex-native-host`) codebase, resolves the 5 Round-2 UI code-review items (Section 9) against verified official mechanics, and answers all **18 Architecture Recommendation Questions** (Section 22).

---

## 1. Subsystem-by-Subsystem Adoption Matrix

| Subsystem | Official ChatGPT Desktop (`26.1103.32239`) | Current `Codex-Native-Unoffical` | Classification | Strategic Decision |
| :--- | :--- | :--- | :--- | :--- |
| **App Shell & Mode Switch** | Single shell with `ProductModeToggle` (`Everyday` / `"work"` ↔ `Coding` / `"codex"`) and `conversationDetailMode` (`STEPS_PROSE` / `STEPS_COMMANDS` / `STEPS_EXECUTION`). | Codex-focused desktop shell with sidebar, header, reading column, composer, and right-hand drawers. | `LOCAL_IMPLEMENTATION_DETAIL` | **ADOPT_NOW**: Add the `Everyday (Chat/Work)` ↔ `Coding (Codex)` mode toggle and `conversationDetailMode` (`STEPS_PROSE` vs `STEPS_COMMANDS`) to the existing shell. |
| **Sidebar Bootstrap & Catalog** | Synchronous IPC `getInitialSidebarBootstrap()` + SQLite `local_thread_catalog` (`host_kind`: `local`, `ssh`, `wsl`, `remote-control`, `chatgpt`) + `ThreadCatalogSyncManager`. | Paginated in-memory `ThreadListController` backed by `thread/list` RPC + local workspace grouping. | `LOCAL_IMPLEMENTATION_DETAIL` | **ADOPT_NOW**: Persist `local_thread_catalog` in SQLite (`codex-native-host` / Dart) so cold start renders cached projects & threads in `0ms` before background `thread/list` sync. |
| **Conversation History & Pagination** | Canonical Turn History Islands (`turnHistory.kind === "canonical"`), `thread/turns/list` (`limit: 5, desc`), `thread/items/list` (`limit: 2, asc` for opening `userMessage`), `olderCursor` item/turn pagination. | `ConversationController` loads thread turns and keeps the last `maxRenderedTurns = 40` in a sliding window, with `loadOlderTurns()` expanding by 40. | `PUBLIC_SUPPORTED` | **ADOPT_NOW**: Upgrade `ConversationController` + `codex-native-host` to use `thread/turns/list` & `thread/items/list` (when app-server `>= 0.147.0`), canonical turn islands, and opening-user-message anchoring. |
| **Active History Eviction** | Viewport-protected eviction (`setBoundary` -> `setHistoryViewport` -> `yV`/`yZ`): evicts active island `> 1000` items down to `500` items **strictly above** `(oldestProtectedTurnId, firstProtectedItemId)`, preserving structural items (`!yX`). | Fixed tail cap (`_turns.length > 40`) in `ConversationController._trimExcessTurns()`. | `LOCAL_IMPLEMENTATION_DETAIL` | **ADOPT_NOW**: Replace blind tail-count trimming with **viewport-protected eviction** (`oldestProtectedTurnId`, `firstProtectedItemId`) + structural item preservation (`userMessage`, `plan`, `todo-list`, `error`, `approval`). |
| **Scroll Anchoring & Initial Open** | Tail island hydrated first (`readLatestPreviewPage`, `limit: 5`); viewport mounts bottom-anchored at latest turn; `setBoundary` protects user scroll position. | Reverse-list / post-frame scroll to bottom in `conversation.dart`. | `LOCAL_IMPLEMENTATION_DETAIL` | **ADOPT_NOW**: Pair Flutter `CustomScrollView(center: centerKey)` / anchor-keyed slivers with tail-island hydration so opening a thread is natively anchored at the bottom on Frame 0 without post-frame jumps. |
| **Streaming & Reactive Store** | Fine-grained signal maps (`L` items by `(entityKey, itemId)`, `B` slots, `H` turns) + 10-thread LRU (`t.slice(-10)`). | 50 ms streaming coalescing timer in `ConversationController` + inactive-thread eviction + bounded `LruCache<String, String>` (120 entries) for Markdown. | `LOCAL_IMPLEMENTATION_DETAIL` | **ADAPT_NATIVE**: Keep our 50 ms coalescing & bounded Markdown cache, and add per-item `ValueListenable` / slot isolation + a 10-thread LRU cache for instant back/forward thread switching. |
| **Large Command Output & Diffs** | Truncates in app-server / main process and sends tokenized 256 KiB IPC chunks (`codex-host-chunked-message-v1`). | Rust `codex-native-host` strips large `aggregatedOutput` in-stream, spools to disk (`1 MiB`/item, `32 MiB`/session), and serves byte ranges via `host/output/readRange`. | `PUBLIC_SUPPORTED` | **KEEP_OUR_ADVANTAGE**: Our Rust host spool + range-read log viewer and lazy hunk diff viewer are more memory-efficient than Electron's 64 MiB chunk buffer. |
| **Cloud Chat & Projects Compatibility** | `ThreadCatalogSyncManager` (`chatgpt:` host, `/backend-api/conversations`, 30-day window) + `MrGp` DAG (`mapping`/`current_node`) + `codex_unified_projects` (`g-p-*`). | Not yet implemented (Codex-only today). | `PRIVATE_COMPATIBILITY` / `PUBLIC_SUPPORTED` | **ADOPT_PHASE_2**: Implement `ConversationBackendAdapter` with (1) Stock `app-server` Everyday mode (`PUBLIC_SUPPORTED`), (2) Public `/v1/responses` API + `conversations.json` export importer (`PUBLIC_SUPPORTED`), and (3) Opt-in `/backend-api/conversations` sync adapter (`PRIVATE_COMPATIBILITY`). |
| **Plugins, Skills, and MCP** | 7 bundled plugins (`codex-app-tools`, `browser`, `chrome`, `unified-computer-use`, `latex`, `deep-research`, `visualize`), `plugin/*` & `skills/*` RPCs, `codex-sandbox://` Skybridge iframe. | Basic MCP/tool item rendering in timeline; no Skills/Plugins UI or Skybridge host yet. | `PUBLIC_SUPPORTED` | **ADOPT_PHASE_2**: Build native Flutter UI for `skills/list`, `plugin/list`, `$skill` composer autocomplete, and `mcpServer/elicitation/request`, plus an on-demand disposable WebView fallback for `visualize` / MCP apps. |
| **Remote Control** | Cloud relay (`wss://chatgpt.com/backend-api/wham/remote/control/server`) gated by `remote-control-device-key.node` + MFA `step_up_token`. | Direct Host resumable WebSocket bridge in `codex-native-host` with QR/token pairing and `seq`/`ack` replay. | `PRIVATE_COMPATIBILITY` | **KEEP_OUR_ADVANTAGE**: Keep Direct Host as the primary Android/Remote architecture; add `ssh` and `wsl` host transports to `codex-native-host`. |
| **Telemetry & Experimentation** | Statsig (`ab.chatgpt.com`), CES (`ces.chatgpt.com`), Sentry. | None (privacy-preserving local client). | `SERVER_ONLY` | **DO_NOT_ADOPT**: Never include telemetry/Statsig calls; use local Settings flags. |

---

## 2. Resolution of the 5 Round-2 Code-Review Items (Section 9)

Here we compare our Round-2 Desktop UI implementation against the exact mechanisms uncovered in ChatGPT Desktop `26.1103.32239`:

### Item 9.1: Long-Thread Hydration & Sliding Window (`lib/src/features/conversation/conversation_controller.dart`)
- **What Our Code Currently Does**:
  - `ConversationController` calls `thread/read` (`includeTurns: true`), receives all turns from the runtime, stores `_allTurns`, and slices the last `maxRenderedTurns = 40` into `_turns`. Calling `loadOlderTurns()` increases `_renderedTurnLimit` by `40`.
- **How Official ChatGPT Desktop Solves It**:
  - Official Desktop (`early-bootstrap-920 @971120`) uses **Canonical Turn History Islands** (`turnHistory.kind === "canonical"`). It does **not** load all turns on thread open when `app-server >= 0.147.0`; instead it calls `thread/turns/list` (`limit: 5, sortDirection: "desc", itemsView: "summary", itemSnapshot: "latest"`) and, for any partially snapshotted turn, calls `thread/items/list` (`limit: 2, sortDirection: "asc"`) to anchor the turn's opening `userMessage` (`oldestUserInput`).
- **Actionable Upgrade Plan**:
  1. Add `thread/turns/list`, `thread/items/list`, and `thread/timeline/list` to `lib/src/protocol/app_server_protocol.dart` (gated by `serverVersion >= 0.147.0`, falling back to `thread/read` on older CLI versions).
  2. Replace `_allTurns` in `ConversationController` with a bounded **Turn Island Window** that fetches older turns/items on demand via cursor pagination (`olderCursor`) and always preserves each turn's opening `userMessage`.

### Item 9.2: Active Streaming Eviction vs User Scroll Position (`lib/src/features/conversation/conversation_controller.dart`)
- **What Our Code Currently Does**:
  - `_trimExcessTurns()` trims `_turns` whenever `_turns.length > _renderedTurnLimit`, regardless of whether the user is currently scrolled up reading an older turn.
- **How Official ChatGPT Desktop Solves It**:
  - Official Desktop (`lTUh.setBoundary` in `182735` -> `yV`/`yZ` in `early-bootstrap-920`) tracks the user's visible viewport boundary `(oldestProtectedTurnId, firstProtectedItemId)`. When an active island exceeds **1,000 items**, `yZ` evicts down to **500 items**, but **never evicts at or below `(oldestProtectedTurnId, firstProtectedItemId)`**, and never evicts structural items (`!yX`: `oldestUserInput`, `plan`, `todo-list`, `error`, `approval`).
- **Actionable Upgrade Plan**:
  1. Have `ConversationView` report its first visible `(turnId, itemId)` to `ConversationController.setViewportBoundary(...)`.
  2. Update eviction in `ConversationController` to only evict items/turns strictly older than the protected viewport boundary, preserving structural items and storing an `olderItemCursor` stub where items were cut.

### Item 9.3: Initial Bottom Anchoring & Scroll Restoration (`lib/src/app/presentation/conversation.dart`)
- **What Our Code Currently Does**:
  - Uses a `ScrollController` on the timeline `ListView.builder` and schedules post-frame `jumpTo(maxScrollExtent)` / `_stickToBottom` checks when opening or growing a thread.
- **How Official ChatGPT Desktop Solves It**:
  - Official Desktop hydrates only the tail 5-turn island on open, mounts the virtualizer anchored to the tail item, and expands upward via `olderBoundary.cursor` without shifting the viewport anchor.
- **Actionable Upgrade Plan**:
  1. Use a bottom-anchored sliver layout (`CustomScrollView` with `center: _bottomAnchorKey` or reverse-anchored tail sliver + upward-growing older-turns sliver) so the latest turn is laid out at the bottom on **Frame 0** without needing post-frame `maxScrollExtent` jumps.
  2. Persist per-thread `(anchorTurnId, anchorItemId, leadingOffset)` in the 10-thread LRU cache so switching between recent threads restores the exact reading position instantaneously.

### Item 9.4: Narrow-Width Composer & Execution Controls (`lib/src/app/presentation/conversation.dart` & `execution_settings_controller.dart`)
- **What Our Code Currently Does**:
  - Fixed in commit `7070e08`: `conversation.dart` now subtracts the send-button reservation (`46px`) before deciding between inline vs stacked composer controls, and `execution_settings_controller.dart` falls back to `_models.firstOrNull` when no model has `isDefault == true`.
- **How Official ChatGPT Desktop Solves It**:
  - Official Desktop (`KkZX` & `AdaptiveFooter` in `324258.54c339c9b6.js`) gives the composer a `24px` inline overhang (`--composer-inline-overhang: 24px`) beyond `--thread-content-max-width: 40rem` (`640px` -> `688px` composer width), and uses container queries (`cqw`) inside `AdaptiveFooter` to progressively collapse text labels on secondary pills before stacking.
- **Actionable Upgrade Plan**:
  1. Adopt the official `640px` reading column + `24px` composer inline overhang (`688px` composer max-width) and `--composer-radius: 24px`.
  2. Add compact label-collapse thresholds inside the composer footer before falling back to multi-row wrapping.

### Item 9.5: User Message Scaffolding & Pasted-File Chips (`lib/src/app/presentation/conversation.dart`)
- **What Our Code Currently Does**:
  - Parses `# Files mentioned by the user:`, `# Context from my IDE setup:`, and `## My request for Codex:` inside `conversation.dart` to render compact file chips instead of a raw scaffolding wall of text.
- **How Official ChatGPT Desktop Solves It**:
  - Official Desktop (`972499.b9f8eb2bc4.js` & `182735.d3d917f28d.js`) stores structured input items (`type: "text" | "image" | "localImage" | "skill" | "mention"` plus `plugin://...?mention=tab-v1` browser tab mentions) and parses legacy/CLI markdown scaffolding (`# Files mentioned by the user:`, `## My request for Codex:`) in the domain/protocol projection layer so widgets receive clean `UserAttachmentChip` models + `requestText`.
- **Actionable Upgrade Plan**:
  1. Move user-input scaffolding extraction from `conversation.dart` into the typed protocol adapter (`lib/src/protocol/` / `lib/src/domain/`) and support all 5 official `UserInput` item types (`text`, `image`, `localImage`, `skill`, `mention`).

---

## 3. Answers to All 18 Architecture Recommendation Questions (Section 22)

### Q1. How does official ChatGPT Desktop organize the relationship between Chat, Work, and Codex?
- **Answer**: They are **three experience modes of a single unified codebase (`openai-codex-electron`) sharing one App Shell, Router, Sidebar Catalog (`local_thread_catalog`), Composer (`g.r`), and Reactive Transcript Store (`182735`)**.
- The UI switches between **"Everyday" (`sidebarProductMode = "work"`, covering Chat + Work)** and **"Coding" (`sidebarProductMode = "codex"`)** via a header `ProductModeToggle`, while the timeline switches presentation density via `conversationDetailMode`: `"STEPS_PROSE"` (condensed prose summaries + writing blocks for Chat/Work) vs `"STEPS_COMMANDS"` (full command/diff/terminal cards for Codex).

### Q2. Which parts of our future Native Client should be shared across Chat, Work, and Codex, and which must remain separated?
- **Shared (80% of client)**:
  1. Application Shell, Window Chrome, Command Menu (`Cmd/Ctrl+K`), and Theme System (`CodexPalette`).
  2. Unified SQLite Thread & Project Catalog (`local_thread_catalog` + `0ms` synchronous startup bootstrap).
  3. Unified Composer (rich text, `@file` mentions, `$skill` pills, file/image attachments, model/effort selector, queued follow-ups).
  4. Bounded Virtualized Transcript Viewport (item/slot reactive store, 10-thread LRU, viewport-protected active eviction, `STEPS_PROSE` vs `STEPS_COMMANDS` detail toggle).
  5. Shared Capability Host (Skills, Plugins, MCP status/OAuth/elicitation, native chart/LaTeX blocks, disposable WebView fallback).
- **Separated Behind Clean Adapters (20% of client)**:
  1. `ConversationBackendAdapter`: `AppServerConversationAdapter` (JSON-RPC turns/items) vs `CloudChatConversationAdapter` (REST/SSE DAG `mapping`/`current_node`).
  2. Mode-specific Right-Hand Drawers: Git Diff / Worktree / Terminal drawers (Coding mode) vs Writing Blocks / Deliverables / In-App Browser preview (Everyday/Work mode).

### Q3. How should the unified local database be designed?
- **Answer**: Maintain a two-part SQLite design:
  1. **Preserve stock `~/.codex/state_5.sqlite` and `~/.codex/thread_history_1.sqlite` untouched** so `codex app-server` continues to own its `.jsonl` rollout byte-offset index without conflict.
  2. **Create `codex_native_catalog.sqlite` (WAL mode)** owned by `codex-native-host` (Desktop) / Flutter (Android) with:
     - `local_thread_catalog` (`PRIMARY KEY (host_id, thread_id)`, `host_kind IN ('local','ssh','wsl','remote-host','chatgpt','local-chat')`, `conversation_origin`, `project_id`, `last_activity_at DESC`)
     - `unified_projects` (`project_id`, `name`, `local_roots_json`, `chatgpt_gizmo_id`)
     - `chat_message_nodes` (`conversation_id`, `node_id`, `parent_id`, `children_json`, `role`, `created_at`, `content_summary`, `blob_sha256`) for DAG-based Chat threads
     - `unified_search_fts` (`FTS5` virtual table indexing titles, user prompts, and assistant final summaries).

### Q4. How should conversation/thread/turn/item pagination, virtualization, and eviction be designed so UI state stays O(viewport) rather than O(history)?
- **Answer**:
  1. **Canonical Turn Islands**: Represent loaded history as bounded islands with `olderBoundary` and `newerBoundary` cursors rather than a flat array.
  2. **Tail-First Hydration + Opening Prompt Anchor**: On thread open, fetch only the latest 5 turns (`thread/turns/list`, `sortDirection: "desc", limit: 5`). For any turn whose items are partially loaded (`summaryItemIds`), fetch the first 2 items (`thread/items/list`, `sortDirection: "asc", limit: 2`) so the turn's opening `userMessage` is always anchored at the top of the turn.
  3. **Bottom-Anchored Sliver Virtualization**: Render the active island in a `CustomScrollView` anchored at the bottom (`center: bottomAnchorKey`) so initial open is `0ms` at the latest message with zero post-frame scroll jump.
  4. **Viewport-Protected Eviction**: Track the user's visible `(oldestProtectedTurnId, firstProtectedItemId)`. When active items exceed `1,000` (or `250` on mobile), evict down to `500` (or `120` on mobile) **strictly above** the protected viewport boundary, never evicting structural items (`userMessage`, `plan`, `todo-list`, `error`, `approval`), and leaving an `olderCursor` marker where items were cut.

### Q5. How should Cloud Chat history be accessed?
- **Answer**: Use a **tiered, risk-isolated strategy**:
  1. **Tier 1 (`PUBLIC_SUPPORTED` — Default)**: Run "Everyday (Chat/Work)" threads through stock `codex app-server` in `STEPS_PROSE` mode (which natively uses the user's ChatGPT Plus/Pro/Team login from `~/.codex/auth.json`) OR via the official OpenAI `/v1/responses` API.
  2. **Tier 2 (`PUBLIC_SUPPORTED` — Offline History Migration)**: Provide a built-in importer for official ChatGPT Data Export archives (`conversations.json`) into `local_thread_catalog` + `chat_message_nodes`.
  3. **Tier 3 (`PRIVATE_COMPATIBILITY` — Opt-In Cloud Sync)**: Isolate `GET /backend-api/conversations` (limit 100, 30-day window, 5-min backoff) and `GET /backend-api/conversation/:id` inside an optional `ChatGptCloudSyncAdapter` in `codex-native-host`.

### Q6. Which ChatGPT capabilities are `PUBLIC_SUPPORTED` vs `PRIVATE_COMPATIBILITY`, and how should they be isolated?
- **Answer**:
  - `PUBLIC_SUPPORTED`: Stock `codex app-server` (all 88 RPCs, OAuth login, local/worktree execution, skills, plugins, MCP), OpenAI `/v1/responses` API, and `conversations.json` export import.
  - `PRIVATE_COMPATIBILITY`: `/backend-api/conversations*`, `/backend-api/f/conversation`, `/backend-api/gizmos/snorlax/*`, `/backend-api/estuary/content`, `/backend-api/wham/*`, and `wss://codex-cloud-backend.chatgpt.com/`.
  - **Isolation Rule**: No widget or controller in `lib/src/features/` may ever reference `/backend-api/*` or `/wham/*` schemas. All private compatibility endpoints must live behind optional Rust/Dart transport adapters that map into canonical domain models (`ThreadSummary`, `TurnProjection`, `ProjectSummary`).

### Q7. How should Work mode be positioned and implemented in the Native Client?
- **Answer**: Work mode is **not** a separate agent engine—in official ChatGPT Desktop, Work is simply **Everyday mode (`sidebarProductMode = "work"`, `conversationDetailMode = "STEPS_PROSE"`) combined with local/workspace tool execution (`codex app-server`, `codex-app-tools`, document/chart generation, and browser/computer-use skills)**.
- We should implement Work mode as the **"Everyday / Work"** surface on top of our existing `codex-native-host` + `codex app-server` stack:
  - Default to `STEPS_PROSE` (condensed tool activity pills + rich deliverable cards for `.docx`/`.pdf`/charts/files).
  - Allow projectless threads (backed by a managed scratch workspace directory `~/.codex/work-scratch/<threadId>`), matching official `electron:thread-projectless-output-directories`.

### Q8. How should Plugins, Apps, Skills, and MCP be unified in a Shared Capability Host?
- **Answer**: Delegate discovery, configuration, and execution of **Plugins (`plugin/*`)**, **Skills (`skills/*`)**, and **MCP Servers (`mcpServer/*`)** to stock `codex app-server`, and build a unified **Capability Host** in Flutter + `codex-native-host` with three presentation tiers:
  1. **Native UI**: Skills/Plugins marketplace sheet, `$skill` & `@file` composer pills, MCP OAuth/elicitation cards, and native chart/LaTeX widgets.
  2. **Host App-Tools MCP (`codex_app`)**: Optional local MCP server in `codex-native-host` for prompt-gated thread delegation (`create_thread`, `fork_thread`, `handoff_thread`).
  3. **Disposable WebView Sandbox (`Skybridge`)**: Mounted on demand only when an MCP app or `visualize` tool emits interactive HTML/WebGL that requires a DOM, and disposed immediately when off-screen.

### Q9. What should `codex-native-host` evolve into long-term?
- **Answer**: `codex-native-host` should evolve from a "local stdio wrapper" into the **Unified Native Platform Host**:
  1. **Multi-Transport `app-server` Supervisor**: Manages `local` stdio, `ssh`, and `wsl` `codex app-server` processes with crash recovery.
  2. **Canonical History Island & Spool Engine**: Strips multi-MB `aggregatedOutput`, spools logs/diffs to disk, serves byte ranges (`host/output/readRange`), and enforces viewport-protected active eviction (`1,000 -> 500` items).
  3. **Unified SQLite Catalog & Search Daemon**: Maintains `codex_native_catalog.sqlite` + `FTS5` search across all hosts and modes, serving `0ms` bootstrap snapshots to Desktop and Android clients.
  4. **Direct Host Remote Gateway**: Serves authenticated, resumable (`seq`/`ack`) WebSocket connections to Android and remote desktop clients over LAN/Tailscale/VPN.

### Q10. Should Android / Remote use Direct Host (`codex-native-host`), Official Remote Control (`wham/remote/control`), or both?
- **Answer**: **Use Direct Host (`codex-native-host`) as our primary, default Remote architecture**, and treat Official Remote Control (`wham/remote/control/server`) as `PRIVATE_COMPATIBILITY` (do not depend on it).
- **Why**: Official Remote Control requires OpenAI's proprietary `remote-control-device-key.node` N-API addon (non-extractable OS hardware key attestation) plus a 300-second MFA `step_up_token` and routes all traffic through `wss://chatgpt.com/backend-api/wham/remote/control/server`. By contrast, our Direct Host bridge in `codex-native-host` works with zero cloud lock-in over LAN/Tailscale/SSH, supports byte-range output spooling (`host/output/readRange`), and works on Linux, macOS, Windows, and Android today.

### Q11. How should Desktop and Android share code while respecting platform differences?
- **Answer**:
  - **100% Shared Dart Packages / Layers (`lib/src/domain/`, `lib/src/protocol/`, `lib/src/transport/`, `lib/src/features/*/controller`)**: All protocol adapters, canonical turn island models, `ConversationController`, `ThreadListController`, `ExecutionSettingsController`, and theme tokens (`CodexPalette`).
  - **Responsive / Platform-Adaptive Presentation (`lib/src/app/presentation/`)**:
    - Desktop (`>= 768px`): Persistent resizable sidebar (`240px–520px`), `640px` reading column (`688px` composer overhang), side-by-side docked Diff/Terminal/Artifact drawers (`>= 900px`), keyboard shortcuts (`Cmd/Ctrl+K`, `Cmd/Ctrl+B`, `Cmd/Ctrl+N`).
    - Android / Narrow (`< 768px`): Modal slide-over drawer for sidebar, bottom sheets for approvals/diffs/settings, touch-friendly `44px` hit targets, and Direct Host WebSocket transport (never spawning a local Rust `codex app-server` on the phone by default).

### Q12. What is the clean-room strategy for Typography, Design Tokens, and Icons?
- **Answer**:
  - **Design Tokens**: Adopt the exact numerical geometry (`4px` spacing grid, `46px` toolbar, `52px` sidebar header, `640px` Codex column / `800px` Chat column, `24px` composer overhang, `10px` row radius, `24px–30px` composer radius) and semantic light/dark color relationships (`#f9f9f9`/`#000000` under-surface, `#ffffff`/`#181818` main surface, `#f3f3f3`/`#414141` user bubble) inside `CodexPalette` and `CodexTokens`.
  - **Typography & Icons (Strict Clean-Room)**: Never bundle proprietary `"OpenAI Sans"` font files or proprietary SVGs from `app.asar`. Use system UI sans (`-apple-system`, `Segoe UI`, `Inter`/`Roboto` on Linux/Android) + system monospace (`SF Mono`, `JetBrains Mono`, `Consolas`, `Liberation Mono`) and Apache-2.0 / MIT icon sets (`Lucide` / `Material Symbols`).

### Q13. How should we fix our remaining Desktop UI fidelity gaps based on this reverse analysis?
- **Answer**: Execute the 5 targeted upgrades identified in Section 2 above:
  1. Add `thread/turns/list` + `thread/items/list` tail hydration and opening-user-message anchoring (`oldestUserInput`).
  2. Replace blind turn-count trimming with viewport-protected active eviction (`setBoundary` -> `oldestProtectedTurnId`, `firstProtectedItemId`).
  3. Switch the conversation timeline to a bottom-anchored sliver (`CustomScrollView(center: _bottomAnchorKey)`) + 10-thread LRU scroll restoration.
  4. Apply the exact official shell geometry (`#f9f9f9`/`#000` under-surface with inset rounded main surface card, `640px` reading column + `24px` composer overhang, `STEPS_PROSE` vs `STEPS_COMMANDS` detail mode toggle).
  5. Move user-message scaffolding parsing (`# Files mentioned by the user:`) into the protocol/domain layer and support structured `mention`/`skill`/`localImage` chips.

### Q14. How should Unified Projects (`codex_unified_projects`) be modeled in our client?
- **Answer**: Model every project in `codex_native_catalog.sqlite` (`unified_projects`) with:
  - `projectId` (UUID)
  - `name`, `icon`, `themeColor`
  - `localRoots`: `List<WorkspaceRoot>` (for local/SSH/WSL Codex workspaces)
  - `cloudBacking`: Optional `{ accountId, gizmoId: "g-p-..." }`
  This allows a single project folder in the sidebar to hold local coding threads, remote host threads, and Everyday/Work threads seamlessly.

### Q15. How should Multi-Agent / Subagent delegation (`codex-app-tools` & `guardian_native_multi_agent_history`) be presented in the UI?
- **Answer**:
  - Detect `<codex_delegation>` blocks (`EMCu`: `source_thread_id`, `source_orbit_id`, `input`/`task`) and subagent tool calls (`create_thread`, `send_message_to_thread`, `handoff_thread`).
  - Render them as compact **Subagent Delegation Cards** inside the parent turn showing the child thread title, live status spinner, and a one-click action to open/peek the child thread in a side pane or navigate to it with a breadcrumb back-button (`navigateBack`).

### Q16. How should Integrated Terminal & Code Review (`review/start`) be integrated?
- **Answer**:
  - **Code Review**: Wire the `review/start` RPC and `reviews.sqlite` findings into our existing right-hand Diff Inspector drawer so users can trigger a structured Codex review on uncommitted changes or a branch diff and jump directly to annotated file/line findings.
  - **Terminal**: Use `command/exec`, `command/exec/write`, `command/exec/resize`, and `command/exec/terminate` (already supported by stock `codex app-server`!) for the integrated terminal drawer before adding any extra PTY sidecar dependency.

### Q17. What is the recommended phased roadmap from the current codebase to the unified Native Chat + Work + Codex platform?
- **Answer**:
  - **Phase A — Codex Desktop Architecture & UI Perfection (Immediate Next Phase)**:
    - Land canonical turn islands (`thread/turns/list`, `thread/items/list`), viewport-protected eviction (`setBoundary`), bottom-anchored sliver scroll (`0ms` initial bottom open), 10-thread LRU, SQLite sidebar catalog bootstrap (`codex_native_catalog.sqlite`), and `STEPS_PROSE` vs `STEPS_COMMANDS` detail toggle.
  - **Phase B — Everyday (Chat + Work) Surface on Stock Runtime (`PUBLIC_SUPPORTED`)**:
    - Enable the header `Everyday (Work/Chat)` ↔ `Coding (Codex)` mode toggle, projectless scratch workspaces for Work threads, `conversations.json` ChatGPT history archive import + `FTS5` search, and `skills/list` + `plugin/list` management UI.
  - **Phase C — Android Client & Multi-Host (`ssh`/`wsl`/Direct Host) Expansion**:
    - Connect the shared Flutter UI on Android to `codex-native-host` over resumable Direct Host WebSocket (`seq`/`ack`), and add `ssh`/`wsl` host targets on Desktop.
  - **Phase D — Optional Cloud Sync & Skybridge Sandbox (`PRIVATE_COMPATIBILITY` / Optional)**:
    - Add opt-in `ChatGptCloudSyncAdapter` (`/backend-api/conversations` read sync) and on-demand disposable WebView fallback for interactive `visualize`/MCP widgets.

### Q18. What must we explicitly NOT build or copy from ChatGPT Desktop?
- **Answer**:
  1. **Do NOT embed Electron/Node or bundle a 757 MB Chromium runtime**—keep our lightweight Flutter + Rust `codex-native-host` architecture.
  2. **Do NOT copy proprietary JS/CSS bundles, `"OpenAI Sans"` fonts, or OpenAI logos/icons**.
  3. **Do NOT depend on `remote-control-device-key.node` or `/wham/remote/control/server`** for Android/Remote pairing.
  4. **Do NOT make `/backend-api/f/conversation` the required primary backend for Everyday/Work mode**—use stock `codex app-server` (`STEPS_PROSE`) and public `/v1/responses` first so the app never breaks due to web anti-bot/sentinel challenges.
  5. **Do NOT implement Statsig/CES/Sentry telemetry**.
