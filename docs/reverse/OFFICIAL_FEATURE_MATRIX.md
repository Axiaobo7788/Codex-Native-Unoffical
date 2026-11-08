# Official Feature Matrix & Convergence Queue

> **Audited Packages**:
> - Official ChatGPT / Codex Desktop Linux (`26.1103.32239`, build `25471` / `26.326.51703`)
> - Stock Bundled Runtime (`codex app-server 0.167.0-alpha.3.2`)
> - Official ChatGPT Android (`com.openai.chatgpt`, cross-validation baseline)
> **Classification Taxonomy**: `IMPLEMENTED`, `HUMAN_REVIEW_PENDING`, `PARTIAL`, `MISSING`, `RESEARCH_MORE`, `PRIVATE_ONLY`, `NOT_APPLICABLE`, `NATIVE_ADVANTAGE` (`KEEP_OUR_ADVANTAGE`)  
> **Evidence Grading**: `PUBLIC_DOC`, `PUBLIC_SOURCE`, `LIVE_OBSERVED`, `LIVE_CALLED`, `STATIC_BUNDLE`, `STATIC_APK`, `STATIC_DEX`, `LOCAL_SCHEMA`, `INFERRED`  
> **Support Classifications**: `PUBLIC_SUPPORTED`, `EXPERIMENTAL_STOCK_SCHEMA`, `PRIVATE_WEB_SESSION`, `PRIVATE_INTERNAL_SERVICE`, `INTERNAL_ELECTRON_IPC`

---

## 1. Classification Categories & Architectural Grounding

Every official feature observed across the Desktop ASAR bundle (`STATIC_BUNDLE`), live Chromium DevTools inspection (`LIVE_OBSERVED`), live JSON-RPC invocation (`LIVE_CALLED`), stock `codex app-server` JSON schema (`PUBLIC_SOURCE` / `LOCAL_SCHEMA`), Android APK cross-validation (`STATIC_APK` / `STATIC_DEX`), and public OpenAI documentation (`PUBLIC_DOC`) is audited against actual `Codex-Native-Unoffical` source code (`lib/src/`, `native_host/src/`) and mapped into one of eight classification categories:

1. **`IMPLEMENTED`**: Fully built, unit/widget/E2E tested, and verified in `Codex-Native-Unoffical`.
2. **`HUMAN_REVIEW_PENDING`**: Machine-verified and agent-real-use-verified UI/functional slice awaiting subjective user acceptance; frozen against further subjective visual tweaking while `SELF_ITERATION` continues on independent functional slices.
3. **`PARTIAL`**: Partially built in `lib/src/`; targeted for functional completion in the active convergence queue.
4. **`MISSING`**: Known official capability not yet implemented in `lib/src/`; queued in `READY` if backed by `PUBLIC_SUPPORTED` / `EXPERIMENTAL_STOCK_SCHEMA` interfaces.
5. **`RESEARCH_MORE`**: Under reverse/compatibility investigation; technical contract not yet stabilized or requires unavailable hardware/cloud gates.
6. **`PRIVATE_ONLY`**: Relies on proprietary internal services (`/wham/*`, `/backend-api/*`, `/flora/cca/executor`, `thread/startAeon`, `remote-control-device-key.node`); excluded from core dependencies.
7. **`NOT_APPLICABLE`**: Web-specific, Electron-specific, or macOS-only artifact irrelevant to our native architecture.
8. **`NATIVE_ADVANTAGE` (`KEEP_OUR_ADVANTAGE`)**: Architectural advantages in our Native Rust Host and Dart core that outperform the official Electron client (bounded memory, `512 MiB/item` spooling, `50 ms` stream coalescing, zero direct `~/.codex/*.sqlite` mutation); **strictly preserved**.

---

## 2. Re-Audited Feature Matrix vs Actual Codebase (`lib/src/`)

### 2.1 Shared Shell, Window Chrome & Product Mode Architecture

| # | Feature / Capability | Official Implementation | Current Native Code (`lib/src/`) | Status | Evidence & Support | Code Audit & Verification |
|---|---|---|---|---|---|---|
| 1.1 | **Custom Window Chrome & Drag Region** | `-webkit-app-region: drag`, `46px` bar, traffic lights | `OfficialCodexTheme.titlebarHeight = 46.0` in `app_shell.dart` & `sidebar_activity.dart` | `HUMAN_REVIEW_PENDING` | `STATIC_BUNDLE`, `LIVE_OBSERVED` / `PUBLIC_SUPPORTED` | Implemented in M3 (`a4fbdaa`); geometry verified in `official_convergence_geometry_test.dart`. Frozen for subjective review. |
| 1.2 | **Inset Rounded Workspace Panel** | `12px` top-left rounded panel inside shell, `0.5px` hairline border | `OfficialCodexTheme.mainSurfaceRadius = 12.0`, `hairlineBorderWidth = 0.5` in `app_shell.dart` | `HUMAN_REVIEW_PENDING` | `STATIC_BUNDLE`, `LIVE_OBSERVED` / `PUBLIC_SUPPORTED` | Implemented in M3 (`a4fbdaa`); frozen for subjective review. |
| 1.3 | **Sidebar Collapsible Navigation Rail** | `260px` default rail (`Ctrl+B` toggle) | `OfficialCodexTheme.sidebarWidth = 260.0` in `app_shell.dart` | `HUMAN_REVIEW_PENDING` | `STATIC_BUNDLE`, `LIVE_OBSERVED` / `PUBLIC_SUPPORTED` | Implemented in M3 (`a4fbdaa`); frozen for subjective review. |
| 1.4 | **Inline Thread Search (`Ctrl+K`)** | Inline search field filtering titles, projects, and directories | `_ThreadPanelState._toggleSearch` (`thread-search-field`) in `sidebar_activity.dart` | `IMPLEMENTED` | `LIVE_OBSERVED` / `PUBLIC_SUPPORTED` | Instant in-memory filter + `ThreadListQuery.searchTerm` protocol pass-through (`thread_protocol.dart`). |
| 1.5 | **Project Grouping & Workspace Tree** | Collapsible project folders grouped by workspace root (`cwd`) | `_ProjectHeadingRow` in `sidebar_activity.dart` | `HUMAN_REVIEW_PENDING` | `LIVE_OBSERVED` / `PUBLIC_SUPPORTED` | Implemented and verified across 5 viewports. |
| 1.6 | **Thread Row Styling & Indicators** | `36px` height, `10px` radius, status dot, compact relative time | `CodexSidebarRow` (`navRowHeight = 36.0`, `navRowRadius = 10.0`) in `codex_sidebar_row.dart` | `HUMAN_REVIEW_PENDING` | `STATIC_BUNDLE`, `LIVE_OBSERVED` / `PUBLIC_SUPPORTED` | Implemented in M3 (`a4fbdaa`); frozen for subjective review. |
| 1.7 | **Shared `ProductMode` (`Codex` / `Work` / `Chat`) & `BackendCapabilities` Seam** | Unified shell switching `Codex`, `Work`, `Chat` modes with capability-driven controls | `ProductMode` & `BackendCapabilities` in `lib/src/domain/product_mode.dart`, wired in `codex_native_app.dart` & `conversation.dart` (`product-mode-selector`) | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `STATIC_BUNDLE`, `PUBLIC_SOURCE` / `PUBLIC_SUPPORTED` | Implemented in Slice F1 (`732b87d`) and hardened in review. Drives mode-aware detail projection (`PresentationDetailPolicy`) without prompt injection. |
| 1.8 | **Electron Sidecar Native Modules** | Prebuilt `.node` binaries (`better-sqlite3`, `node-pty`, `watcher.node`) | Native Rust Host (`codex-native-host`) compiled to machine code | `NATIVE_ADVANTAGE` | `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | **KEEP OUR ADVANTAGE**: Zero Node.js/Electron overhead. |
| 1.9 | **100-Thread Catalog Memory Cap** | Hydrates full catalog into Electron memory | `ThreadListController(maxRetainedThreads: 100)` | `NATIVE_ADVANTAGE` | `PUBLIC_SOURCE` / `PUBLIC_SUPPORTED` | **KEEP OUR ADVANTAGE**: Inactive threads incur near-zero memory cost. |

### 2.2 Thread Lifecycle & Sidebar Organization Parity

| # | Feature / Capability | Official Implementation | Current Native Code (`lib/src/`) | Status | Evidence & Support | Code Audit & Verification |
|---|---|---|---|---|---|---|
| 2.1 | **Thread List, Start, Read, Resume, Delete** | `thread/list`, `thread/start`, `thread/read`, `thread/resume`, `thread/delete` | `ThreadProtocolAdapter` & `ThreadListController` (`deleteThread` wired in sidebar & header thread actions menu) | `IMPLEMENTED` | `PUBLIC_SOURCE`, `LIVE_CALLED` / `PUBLIC_SUPPORTED` | Fully implemented and verified against stock `codex app-server` (`T1.6.6`, `thread_list_controller_test.dart`). |
| 2.2 | **Thread Rename (`thread/name/set`) & Live `thread/name/updated`** | Context menu Rename -> `thread/name/set` + `thread/name/updated` notification | `ThreadProtocolAdapter.renameThread`, `ThreadNameUpdatedEvent`, `ThreadListController.renameThread`, `_RenameThreadDialog` | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `LIVE_CALLED`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in Slice F1 (`732b87d`); verified in `thread_protocol_test.dart`, `T1.6.6`, and live stock `codex app-server` (`ecosystem_protocol_test.dart`). |
| 2.3 | **Thread Archive / Unarchive (`thread/archive`, `thread/unarchive`, `archived` filter)** | Archive action + Archived threads filter in sidebar | `ThreadProtocolAdapter.archiveThread` / `unarchiveThread`, `ThreadListController.showArchived`, `thread-archive-toggle` | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `LIVE_CALLED`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in Slice F1 (`732b87d`); verified in `thread_protocol_test.dart`, `T1.6.6`, and live stock `codex app-server`. |
| 2.4 | **Thread Pinning in Sidebar** | Pin/unpin threads to top `Pinned` section in sidebar | `ThreadListController.togglePinThread` (`maxPinnedThreads = 32`), `Pinned` section in `sidebar_activity.dart` | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `STATIC_BUNDLE`, `LOCAL_SCHEMA` / `PUBLIC_SUPPORTED` | Implemented in Slice F1 (`732b87d`); verified in `thread_list_controller_test.dart` and `T1.6.6`. |
| 2.5 | **Thread Forking / Branching (`thread/fork`)** | Fork whole thread or branch at turn (`beforeTurnId` / `lastTurnId`) with `excludeTurns: true` | `ThreadProtocolAdapter.forkThread`, `ThreadListController.forkThread` (with `isMaterialized` guard), `turn-fork-<turnId>` | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `LIVE_CALLED`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in Slices F1 & F2 (`732b87d`, `7b01bfb`); verified in `thread_protocol_test.dart`, `T1.6.6`, and `T1.6.7`. |
| 2.6 | **Thread History Revert (`thread/revert`)** | Truncate persisted thread history before a selected turn (`beforeTurnId`) | `ThreadProtocolAdapter.revertThread`, `ThreadListController.revertThread` (`revertVersion` / `lastRevertedThreadId` clearing live entries & scroll bookmarks), `turn-revert-<turnId>` | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `LOCAL_SCHEMA` / `PUBLIC_SUPPORTED` | Implemented in Slices F1 & F2 (`732b87d`, `7b01bfb`); verified in `thread_protocol_test.dart`, `thread_list_controller_test.dart`, and `T1.6.7`. |
| 2.7 | **Server-Side Context Compaction (`thread/compact/start`)** | Triggers `codex app-server` context compaction without client prompt rewriting | `ThreadProtocolAdapter.compactThread`, `ThreadListController.compactThread` (with `isMaterialized` guard), header/sidebar `Compact context` action | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in Slice F1 (`732b87d`); verified in `thread_protocol_test.dart` and `T1.6.6` (strictly preserves `AGENTS.md` Rule #1). |

### 2.3 Conversation Timeline, Composer & Turn Interaction

| # | Feature / Capability | Official Implementation | Current Native Code (`lib/src/`) | Status | Evidence & Support | Code Audit & Verification |
|---|---|---|---|---|---|---|
| 3.1 | **704px Reading Column & Floating Composer** | Centered `44rem` (`704px`) reading column, `24px` composer radius | `OfficialCodexTheme.maxContentWidth = 704.0`, `composerRadius = 24.0` | `HUMAN_REVIEW_PENDING` | `STATIC_BUNDLE`, `LIVE_OBSERVED` / `PUBLIC_SUPPORTED` | Implemented in M3 (`a4fbdaa`); geometry verified across 5 viewports. |
| 3.2 | **Bottom-Anchored Reverse Viewport & Scrolled-Up Streaming Preservation** | Reverse scroll container + content-identity bookmarks + `Jump to latest` pill | `_ConversationScrollView(anchor: 1.0)` + `_ThreadScrollBookmark` (`_maxRestorePages = 10` + Scheme A) | `NATIVE_ADVANTAGE` | `LIVE_OBSERVED`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | **KEEP OUR ADVANTAGE**: `0.000 px` visual drift across `>100`-turn eviction and streaming. |
| 3.3 | **100-Turn Sliding Window & 50 ms Stream Coalescing** | Unbounded or experiment-gated (`1000 -> 500`) DOM hydration | `HistoryController(maxRetainedTurns: 100)` + `ConversationController(coalesceInterval: 50ms)` | `NATIVE_ADVANTAGE` | `PUBLIC_SOURCE` / `PUBLIC_SUPPORTED` | **KEEP OUR ADVANTAGE**: Sub-100MB memory on long threads. |
| 3.4 | **User Message Bubble & Attachment Chips (Read Path)** | Right-aligned bubble (`75%` / `528px`), `18px` radius, normalized attachment chips | `CodexMessageBubble` + `parseUserMessagePresentation` (`maxUserAttachments = 16`) | `HUMAN_REVIEW_PENDING` | `STATIC_BUNDLE`, `PUBLIC_SOURCE` / `PUBLIC_SUPPORTED` | Read/history path implemented and hardened (`16.E`, `M3`). |
| 3.5 | **Structured Attachment Submission (Write Path in Composer & `turn/start`)** | Composer `+` menu attaches `localImage`, `image`, `skill`, `mention` into `turn/start` `input` array | `TurnStartOptions.attachments`, `TurnSteerOptions.attachments`, `TurnProtocolAdapter._encodeUserInputs`, `composer-add-attachment` & chip bar in `conversation.dart` | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `LOCAL_SCHEMA`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in Slice F2 (`7b01bfb`); verified in `turn_protocol_test.dart`, `conversation_controller_test.dart`, and `T1.6.7`. |
| 3.6 | **Active Turn Steering (`turn/steer`)** | Submit follow-up steering input while a turn is `inProgress` (`expectedTurnId`) | `TurnProtocolAdapter.steerTurn`, `ConversationController.steer` (`canSteer`, race-safe completion & failed-steer rollback), composer active steering mode | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `LOCAL_SCHEMA`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in Slice F2 (`7b01bfb`); verified in `turn_protocol_test.dart`, `conversation_controller_test.dart`, and `T1.6.7`. |
| 3.7 | **Turn-Level Message Actions (`Copy`, `Fork from turn`, `Revert from turn`)** | Per-message copy, branch/fork from turn, and revert/edit from turn | `assistant-copy-<id>`, `user-copy-<id>`, `turn-fork-<turnId>`, `turn-revert-<turnId>` in `_UserMessageEntryView` (left gutter `Stack`, disabled while busy/mutating) | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in Slice F2 (`7b01bfb`); verified in `T1.6.7` with zero vertical-height regression across `T1.2.4` and 5-viewport geometry tests. |
| 3.8 | **3-Way Detail-Mode Presentation Filter (`Prose` / `Commands` / `Execution`)** | Client-side view filter + proprietary `a2` prompt in `STEPS_PROSE` | `PresentationDetailMode` (`CodexSegment`) pure UI projection filter with zero prompt injection | `HUMAN_REVIEW_PENDING` / `NATIVE_ADVANTAGE` | `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in M3 (`c7cfda4`); strictly preserves `AGENTS.md` Rule #1. |
| 3.9 | **ChatGPT Cloud DAG (`MrGp` `mapping` / `current_node` / `/backend-api/f/conversation`)** | Arbitrary tree branching in cloud Chat mode via web session SSE | Documented in `CHAT_DATA_MODEL.md` & `CHAT_PROTOCOL_MAP.md`; not in core runtime | `PRIVATE_ONLY` / `RESEARCH_MORE` | `STATIC_BUNDLE`, `STATIC_APK` / `PRIVATE_WEB_SESSION` | Keep `/backend-api/*` out of core; use `thread/fork` & `thread/revert` for supported Codex branching. |

### 2.4 Work, Approvals, Diff & Execution

| # | Feature / Capability | Official Implementation | Current Native Code (`lib/src/`) | Status | Evidence & Support | Code Audit & Verification |
|---|---|---|---|---|---|---|
| 4.1 | **Interactive Command & File Approval Cards** | Inline banners for `item/commandExecution/requestApproval` & `item/fileChange/requestApproval` | `_ApprovalBanner` & `ApprovalController` with fail-closed unknown-request handling | `IMPLEMENTED` | `PUBLIC_SOURCE`, `LOCAL_SCHEMA` / `PUBLIC_SUPPORTED` | Converged to `Codex*` primitives in M3 (`a4fbdaa`). |
| 4.2 | **Bounded Unified Diff Viewer** | Center-mode file list and hunk viewer (`@pierre/diffs`) | `_DiffView` & `UnifiedDiffParser` (`2 MiB` input cap, `100` files, lazy per-file rows) | `IMPLEMENTED` | `PUBLIC_SOURCE`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Converged to `Codex*` primitives in M3 (`a4fbdaa`). |
| 4.3 | **512 MiB Output Spooling (`codex-native-host`)** | Electron renderer buffers large command outputs in JS heap | Rust `codex-native-host` spools `aggregatedOutput` to disk (`512 MiB/item`, `2 GiB/session`, SHA-256 dedup) | `NATIVE_ADVANTAGE` | `PUBLIC_SOURCE` / `PUBLIC_SUPPORTED` | **KEEP OUR ADVANTAGE**: Protects Flutter UI memory on huge logs. |
| 4.4 | **Work Mode Cloud Orchestration (`thread/startAeon`, `tpp-local-executor`, `/flora/cca/executor`)** | 4-path orchestration including Durable Cloud WS & Noise rendezvous tunnel | Mapped in `DESKTOP_ARCHITECTURE_MAP.md` & `CODEX_INTEGRATION_MAP.md`; local `ProductMode.work` UI policy implemented in `product_mode.dart` | `PRIVATE_ONLY` (cloud) / `IMPLEMENTED` (local mode policy) | `STATIC_BUNDLE`, `PUBLIC_SOURCE` / `PRIVATE_INTERNAL_SERVICE` | Keep cloud `aeon`/`flora` out of core; local `ProductMode.work` presentation policy implemented in Slice F1 (`732b87d`). |

### 2.5 Remote & Android Connectivity (Dual-Track `ADR-032` & `ADR-034`)

| # | Feature / Capability | Official Implementation | Current Native Code (`lib/src/`) | Status | Evidence & Support | Code Audit & Verification |
|---|---|---|---|---|---|---|
| 5.1 | **Track A: Direct Host Remote Bridge (`codex-native-host` + Android WSS)** | N/A (Native self-hosted architecture) | Rust WS/WSS listener, 1-use ticket + QR pairing, sequence/ack replay, Android secure storage & lifecycle | `NATIVE_ADVANTAGE` | `PUBLIC_SOURCE` / `PUBLIC_SUPPORTED` | **KEEP OUR ADVANTAGE**: Primary self-hosted Android-to-Desktop bridge without cloud relay. |
| 5.2 | **Track B: Stock Host-Side Remote Control Adapter (`remoteControl/*`)** | `remoteControl/status/read`, `enable`, `disable`, `client/list`, `pairing/start`, `client/revoke` | `OfficialRemoteControlHostAdapter` (`EcosystemProtocolAdapter`) + `RemoteArchitectureTrack` (`remote-track-selector`) & `_OfficialRemoteControlPanel` in `remote_setup.dart` | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE` (`--experimental`), `LIVE_CALLED`, `STATIC_BUNDLE` / `EXPERIMENTAL_STOCK_SCHEMA` | Implemented in Slice F3 (`1084ba6`) and verified against live stock `codex app-server 0.167.0-alpha.3.2` (`ecosystem_protocol_test.dart`, `T1.6.8`). |
| 5.3 | **Controller-Side Official Cloud Relay (`remote-control-device-key.node` + `/wham/remote/control/server`)** | Hardware key attestation + MFA `step_up_token` + `/backend-api/codex/remote/control/client/*` | Stratified in `CODEX_INTEGRATION_MAP.md` Layers 3–8 | `PRIVATE_ONLY` / `RESEARCH_MORE` | `STATIC_BUNDLE`, `STATIC_APK` / `PRIVATE_INTERNAL_SERVICE` | Do not depend on private `/wham/*` relay or hardware attestation addon. |

### 2.6 Plugins, Skills & MCP Ecosystem

| # | Feature / Capability | Official Implementation | Current Native Code (`lib/src/`) | Status | Evidence & Support | Code Audit & Verification |
|---|---|---|---|---|---|---|
| 6.1 | **Skills Discovery & Configuration (`skills/list`, `skills/config/write`, `$skill` attach)** | Lists workspace/bundled skills, toggles enablement, attaches `$skill` in composer | `EcosystemProtocolAdapter.listSkills` & `setSkillEnabled`, `_EcosystemDialog` (`ecosystem-section-selector` -> `Skills`, `skill-toggle-<name>`), composer `$skill` attachment | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `LIVE_CALLED`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in Slices F2 & F3 (`7b01bfb`, `1084ba6`); verified in `ecosystem_protocol_test.dart` (including live stock `codex app-server`) and `T1.6.8`. |
| 6.2 | **Plugin Catalog Inspection (`plugin/list`)** | Lists local/curated marketplace plugins and installation status | `EcosystemProtocolAdapter.listPlugins` (bounded to 100 items), `_EcosystemDialog` (`ecosystem-section-selector` -> `Plugins`) | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `LIVE_CALLED`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in Slice F3 (`1084ba6`); verified in `ecosystem_protocol_test.dart` (including live stock `codex app-server`) and `T1.6.8`. |
| 6.3 | **MCP Server Status Inspection (`mcpServerStatus/list`)** | Lists configured MCP servers, auth status, connection status, tool/resource counts | `EcosystemProtocolAdapter.listMcpServerStatus` (bounded to 100 items), `_EcosystemDialog` (`ecosystem-section-selector` -> `MCP`) | `IMPLEMENTED` (`HUMAN_REVIEW_PENDING` UI) | `PUBLIC_SOURCE`, `LIVE_CALLED`, `STATIC_BUNDLE` / `PUBLIC_SUPPORTED` | Implemented in Slice F3 (`1084ba6`); verified in `ecosystem_protocol_test.dart` (including live stock `codex app-server`) and `T1.6.8`. |
| 6.4 | **Desktop Internal Node MCP Sidecars & Skybridge (`ui://` iframe)** | `artifact-template-picker/server.mjs` + `ui://` postMessage iframe | Documented in `PLUGIN_HOST_MAP.md` | `PRIVATE_ONLY` / `RESEARCH_MORE` | `STATIC_BUNDLE` / `PRIVATE_INTERNAL_SERVICE` | Core client requires no Node/WebView (`AGENTS.md` Rule #5). |

### 2.7 Voice, Browser & Advanced Surfaces

| # | Feature / Capability | Official Implementation | Current Native Code (`lib/src/`) | Status | Evidence & Support | Code Audit & Verification |
|---|---|---|---|---|---|---|
| 7.1 | **Voice Input / Realtime Dictation (`thread/realtime/*`)** | Whisper / Realtime WebRTC audio stream | Not implemented | `RESEARCH_MORE` | `PUBLIC_SOURCE` (`--experimental`), `STATIC_BUNDLE` | Defer until cross-platform audio capture & realtime schema stabilize. |
| 7.2 | **Computer-Use / Screen Inspection** | Desktop screen capture via OS permissions | Not implemented | `NOT_APPLICABLE` | `PUBLIC_DOC` | Out of scope for native Codex client. |
| 7.3 | **Proprietary Telemetry & Billing (`/wham/usage/*`)** | Internal credit/telemetry popups | Omitted | `PRIVATE_ONLY` | `STATIC_BUNDLE` / `PRIVATE_INTERNAL_SERVICE` | Strictly excluded from clean-room architecture. |

---

## 3. Convergence Queue Status

### 3.1 `READY` — Independent Machine-Actionable Convergence Slices (Evaluated & Executed in `Slices F1–F3`)

| Priority & Slice | Product Value | Official Parity Impact | Implementation Cost | Evidence Confidence | Supported / Public Boundary | Dependency | Testability | Real-Use Verification Possible? | Execution Status |
|---|---|---|---|---|---|---|---|---|---|
| **P1 — Slice F1: Shared `ProductMode` / `BackendCapabilities` Seam + Thread Lifecycle & Sidebar Organization (`Rename`, `Archive/Unarchive`, `Pin`, `Fork`, `Revert`, `Compact`, `Delete`)** | **Very High**: Unlocks daily thread organization (rename, archive, pin, delete), conversation branching (`thread/fork`), turn history truncation (`thread/revert`), server-side compaction (`thread/compact/start`), and mode-aware `Codex`/`Work`/`Chat` presentation without duplicating UI shells. | **High**: Closes Matrix items `1.7`, `2.1–2.7`, `4.4 (local)`. | **Medium**: Pure domain `product_mode.dart`, `ThreadProtocolAdapter` + `ThreadListController` extensions, `CodexMenu` actions in sidebar & header. | `PUBLIC_SOURCE`, `LOCAL_SCHEMA`, `LIVE_CALLED`, `STATIC_BUNDLE` | **`PUBLIC_SUPPORTED`** (100% stable stock `codex app-server` RPCs: `thread/name/set`, `thread/archive`, `thread/unarchive`, `thread/fork`, `thread/revert`, `thread/compact/start`, `thread/list(archived)`, `thread/delete`). | None (independent of pending visual review). | Unit tests (`thread_protocol_test`, `thread_list_controller_test`), widget tests, E2E test (`T1.6.6`). | **Yes** — directly verified against live stock `codex app-server 0.167.0-alpha.3.2` on Linux (`ecosystem_protocol_test.dart`). | `IMPLEMENTATION_MACHINE_COMPLETE — HUMAN_REVIEW_REQUIRED` (`732b87d`) |
| **P2 — Slice F2: Active Turn Steering (`turn/steer`), Structured Composer Attachments (`UserAttachment` Write Path), & Turn-Level Branch/Revert Actions** | **Very High**: Allows steering an in-progress turn without killing it, attaching files/images/skills/mentions from the composer into `turn/start` & `turn/steer`, and branching/reverting directly from any turn in the timeline. | **High**: Closes Matrix items `3.5`, `3.6`, `3.7`. | **Medium**: `TurnProtocolAdapter` (`turn/steer` + `UserInput` serialization), `ConversationController.steer`, composer `+` attachment menu & removable chip bar, turn action buttons. | `PUBLIC_SOURCE`, `LOCAL_SCHEMA`, `LIVE_CALLED`, `STATIC_BUNDLE` | **`PUBLIC_SUPPORTED`** (stable `turn/start` `UserInput` union & `turn/steer`, plus `thread/fork` / `thread/revert`). | Builds cleanly on `ThreadListController.forkThread` / `revertThread` from Slice F1. | Protocol serialization unit tests (`turn_protocol_test`), controller tests (`conversation_controller_test`), E2E flow test (`T1.6.7`). | **Yes** — directly verified against live stock `codex app-server`. | `IMPLEMENTATION_MACHINE_COMPLETE — HUMAN_REVIEW_REQUIRED` (`7b01bfb`) |
| **P3 — Slice F3: Ecosystem (`Skills`, `Plugins`, `MCP` Status + `$skill` Composer Picker) & Dual-Track Remote (`OfficialRemoteControlHostAdapter` Track B)** | **High**: Provides bounded discovery & configuration for workspace skills (`skills/list`, `skills/config/write`), plugins (`plugin/list`), MCP servers (`mcpServerStatus/list`), and implements `ADR-032` Track B (`remoteControl/status/read`, `enable`, `disable`, `client/list`, `pairing/start`, `client/revoke`) alongside Track A (`DirectHostRemoteBackend`). | **High**: Closes Matrix items `5.2`, `6.1`, `6.2`, `6.3`. | **Medium**: `EcosystemProtocolAdapter` (`OfficialRemoteControlHostAdapter`), `_EcosystemDialog`, Dual-Track `_RemoteSetupDialog`. | `PUBLIC_SOURCE`, `LOCAL_SCHEMA`, `LIVE_CALLED`, `STATIC_BUNDLE` | **`PUBLIC_SUPPORTED`** (`skills/*`, `plugin/*`, `mcpServerStatus/list`) + **`EXPERIMENTAL_STOCK_SCHEMA`** (`remoteControl/*`). | Independent of pending visual review; uses existing `Codex*` primitives. | Protocol unit tests & live integration tests (`ecosystem_protocol_test`), E2E widget tests (`T1.6.8`). | **Yes** — `skills/list`, `plugin/list`, `mcpServerStatus/list`, `remoteControl/status/read`, and `remoteControl/disable` verified live (`LIVE_CALLED`) on stock `codex app-server`. | `IMPLEMENTATION_MACHINE_COMPLETE — HUMAN_REVIEW_REQUIRED` (`1084ba6`) |

### 3.2 `HUMAN_REVIEW_PENDING` — Slice-Scoped Visual/Physical Gates

| Slice | Current State | Why Human Review Is Pending | Rule |
|---|---|---|---|
| **Desktop UI Fidelity & Semantic Primitives (`M3`: Rows `1.1–1.3`, `1.5–1.6`, `3.1`, `3.4`, `3.8`)** | `MACHINE_VERIFIED` (`5/5` viewports) & `AGENT_REAL_USE_VERIFIED` on KDE Wayland (`c7cfda4`, `3d31be2`). | Subjective visual fidelity, typography feel, and interaction polish require human judgment. | Freeze subjective visual re-polishing of existing tokens/geometry. |
| **Functional Convergence Slices (`F1–F3`: Rows `1.7`, `2.2–2.7`, `3.5–3.7`, `5.2`, `6.1–6.3`)** | `MACHINE_VERIFIED` (`304/304` Flutter tests, `98/98` Rust tests) & `AGENT_REAL_USE_VERIFIED` against live stock `codex app-server`. | Subjective interaction ergonomics of thread organization, turn branching/reverting, composer attachment/steering UX, and Ecosystem/Dual-Track Remote dialogs. | Awaiting user review alongside M3 Desktop UI fidelity. |
| **Interactive Approval Approve-Once Real Mutation Gate** | Reject path live-verified; approve-once unit/widget tested. | Approving a real destructive/mutating command in a user workspace is a human review gate. | Keep automated tests green. |

### 3.3 `RESEARCH_MORE` — Requires Deeper Reverse/Protocol Stabilization

| Item | Evidence Grade | Open Question |
|---|---|---|
| **Official Controller-Side Mobile Discovery (`/wham/*` Layer 8)** | `STATIC_BUNDLE` / `STATIC_APK` | Whether any public/supported controller enrollment path will be exposed upstream for non-first-party mobile clients. |
| **Realtime Voice Dictation (`thread/realtime/*`)** | `PUBLIC_SOURCE` (`--experimental`) | Cross-platform audio capture framing and experimental schema stability across Linux/Windows/macOS/Android. |
| **Optional Skybridge (`ui://`) Sandboxed WebView Host** | `STATIC_BUNDLE` / `PUBLIC_SOURCE` | Only needed when third-party MCP servers return interactive `ui://` widget resources (`AGENTS.md` Rule #5). |

### 3.4 `PRIVATE_ONLY` — Excluded from Core Implementation

| Surface | Evidence Grade | Classification & Policy |
|---|---|---|
| **ChatGPT Web Session Endpoints (`/backend-api/f/conversation`, `/backend-api/conversations`)** | `STATIC_BUNDLE`, `STATIC_APK` | `PRIVATE_WEB_SESSION` — protected by Cloudflare/Sentinel/Turnstile; never a core dependency. |
| **Work Cloud Orchestration (`thread/startAeon`, `thread/environmentReady`, `/flora/cca/executor`)** | `STATIC_BUNDLE` | `PRIVATE_INTERNAL_SERVICE` — cloud-only extensions not present in local stock `codex app-server`. |
| **Controller Hardware Attestation (`remote-control-device-key.node` + MFA `step_up_token`)** | `STATIC_BUNDLE` | `PRIVATE_INTERNAL_SERVICE` — proprietary first-party controller enrollment. |
| **Internal Telemetry & Usage (`/wham/usage/*`, `/wham/user-rules`)** | `STATIC_BUNDLE` | `PRIVATE_INTERNAL_SERVICE` — excluded from clean-room client. |

### 3.5 `BLOCKED` — True External Hardware/Environment Gates

| Gate | Blocker | Impact |
|---|---|---|
| **Physical Android Device TLS/Keystore & Camera QR Walkthrough** | No physical Android handset attached to this Linux session. | Blocks final physical-device sign-off for Phase 4, but does not block Desktop/Host or machine-testable functional slices. |
| **Physical Intel macOS & Developer ID Notarization Gate** | Requires Apple Developer ID credentials and physical Intel hardware. | Hosted CI already verifies universal `arm64 + x86_64` binaries (`42129434391`); signing remains a release-only gate. |
