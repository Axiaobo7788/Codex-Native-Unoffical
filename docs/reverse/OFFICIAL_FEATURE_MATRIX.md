# Official Feature Matrix & Convergence Classification

> **Audited Package**: ChatGPT / Codex Desktop Linux Packaging (`26.1103.32239`)  
> **Classification Taxonomy**: `IMPLEMENTED`, `PARTIAL`, `MISSING`, `RESEARCH_MORE`, `PRIVATE_ONLY`, `NOT_APPLICABLE`, `NATIVE_ADVANTAGE` (`KEEP_OUR_ADVANTAGE`)  
> **Evidence Grading**: `STATIC_BUNDLE`, `LIVE_OBSERVED`, `LOCAL_SCHEMA`, `PUBLIC_DOC`, `PUBLIC_SOURCE`

---

## 1. Classification Categories & Architectural Grounding

Every official feature observed across the Desktop ASAR bundle (`STATIC_BUNDLE`), live Chromium DevTools inspection (`LIVE_OBSERVED`), stock `codex app-server` JSON schema (`LOCAL_SCHEMA`), and public OpenAI documentation (`PUBLIC_DOC`) is mapped into one of seven clear classification categories:

1. **`IMPLEMENTED`**: Fully built, tested, and passing in `Codex-Native-Unoffical`.
2. **`PARTIAL`**: Partially built; targeted for completion during the current convergence phase.
3. **`MISSING`**: Known feature not yet implemented; scoped for implementation or future roadmap.
4. **`RESEARCH_MORE`**: Under research; technical feasibility or interface contract not yet stabilized.
5. **`PRIVATE_ONLY`**: Relies on proprietary internal services (`/wham/*`, `/backend-api/*`, proprietary cloud session keys); not suitable as a core app foundation.
6. **`NOT_APPLICABLE`**: Web-specific, Electron-specific, or macOS-only artifact irrelevant to our native architecture.
7. **`NATIVE_ADVANTAGE` (`KEEP_OUR_ADVANTAGE`)**: Architectural advantages in our Native Rust Host and Dart core that outperform the official Electron client (e.g. bounded memory, spooling, stream coalescing, zero SQLite mutation); **strictly preserved**.

---

## 2. Feature Classification Matrix

### 2.1 Shared Shell & Window Chrome

| # | Feature / Capability | Official Implementation | Native Implementation | Status | Evidence Tag | Rationale & Next Action |
|---|---|---|---|---|---|---|
| 1.1 | **Custom Window Chrome & Drag Region** | `-webkit-app-region: drag`, 46px bar, platform traffic lights | Custom 46px drag bar with platform window controls | `PARTIAL` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Align header height from 52px to 46px in `app_shell.dart`. |
| 1.2 | **Inset Rounded Workspace Panel** | 12px top-left rounded panel inside shell, 0.5px hairline border | Flat unrounded pane separated by vertical divider | `PARTIAL` | `STATIC_BUNDLE` | Implement inset surface card with 12px radius in `app_shell.dart`. |
| 1.3 | **Sidebar Collapsible Navigation Rail** | 260px default rail (`240-520px` resizable), `Ctrl+B` toggle | 264px rail with toggle | `PARTIAL` | `STATIC_BUNDLE` | Adjust default width from 264px to 260px; preserve collapse toggle. |
| 1.4 | **Inline Thread Search (`Ctrl+K`)** | Inline search field filtering titles, projects, and directories | Inline filter in `sidebar_activity.dart` | `IMPLEMENTED` | `LIVE_OBSERVED` | Keep native instant in-memory filtering. |
| 1.5 | **Project Grouping & Workspace Tree** | Collapsible project folders grouped by workspace root (`cwd`) | Project headers grouping thread list | `IMPLEMENTED` | `LIVE_OBSERVED` | Keep project grouping; converge folder icon and chevron styling. |
| 1.6 | **Thread Row Styling & Indicators** | 36px height, 10px radius, status dot, compact relative time | 40px height, 8px radius | `PARTIAL` | `STATIC_BUNDLE` | Converge height to 36px and radius to 10px using `CodexSidebarRow`. |
| 1.7 | **Electron Sidecar Native Modules** | Prebuilt `.node` binaries for parcel watcher, serialport, better-sqlite3 | Native Rust Host (`codex-native-host`) compiled to machine code | `NATIVE_ADVANTAGE` | `STATIC_BUNDLE` | **KEEP OUR ADVANTAGE**: Native Rust host eliminates Node.js runtime and Electron overhead. |
| 1.8 | **100-Thread Catalog Memory Cap** | Unbounded thread list loaded into DOM | Bounded 100-thread catalog window | `NATIVE_ADVANTAGE` | `PUBLIC_SOURCE` | **KEEP OUR ADVANTAGE**: Inactive threads incur near-zero memory footprint. |

### 2.2 Conversation & Timeline

| # | Feature / Capability | Official Implementation | Native Implementation | Status | Evidence Tag | Rationale & Next Action |
|---|---|---|---|---|---|---|
| 2.1 | **704px Reading Column** | Centered 44rem (704px) reading column | 760px column | `PARTIAL` | `STATIC_BUNDLE` | Clamp reading column to 704px (`OfficialCodexTheme.maxContentWidth`). |
| 2.2 | **Bottom-Anchored Reverse Viewport** | Reverse scroll container starting at Frame 1 | `_ConversationScrollView` (`CustomScrollView(anchor: 1.0)`) | `NATIVE_ADVANTAGE` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | **KEEP OUR ADVANTAGE**: Instant bottom-scroll presentation on thread open. |
| 2.3 | **Scrolled-Up Streaming Preservation** | Preserves reading position when scrolled up `>160px` | Content-identity bookmarks + floating "Jump to latest" pill | `NATIVE_ADVANTAGE` | `LIVE_OBSERVED` | **KEEP OUR ADVANTAGE**: Streaming does not yank viewport while user is reading older turns. |
| 2.4 | **100-Turn History Sliding Window** | Unbounded turn history hydration in DOM | Bounded 100-turn window with Scheme A reset | `NATIVE_ADVANTAGE` | `PUBLIC_SOURCE` | **KEEP OUR ADVANTAGE**: Limits memory usage to `<100MB` on long threads (`>140` turns). |
| 2.5 | **Stream Coalescing** | Continuous per-token DOM layout mutations | 50 ms throttling window coalescing token deltas | `NATIVE_ADVANTAGE` | `PUBLIC_SOURCE` | **KEEP OUR ADVANTAGE**: Prevents UI freeze during rapid token generation. |
| 2.6 | **User Message Bubble Envelope** | Translucent bubble (`alpha 8%`), 18px radius, attachment chips | Right-aligned bubble, 18px radius, chips | `PARTIAL` | `STATIC_BUNDLE` | Converge max-width to 75% (~528px) and tint to soft alpha fill. |
| 2.7 | **Assistant Prose & Markdown** | 14px size, 1.6 line-height, unboxed layout | Markdown widget with custom styles | `PARTIAL` | `STATIC_BUNDLE` | Converge typography scale to measured official rem ratios. |
| 2.8 | **Code Blocks with Language Header & Copy**| Elevated background `#171817` / `#F4F4F4`, 8px radius, copy action | Custom code block with copy action | `IMPLEMENTED` | `STATIC_BUNDLE` | Verify corner radius and elevated background color match. |
| 2.9 | **Turn Work Divider (`Worked for Xm Ys ›`)**| Centered rule with disclosure pill expanding commands | `_TurnWorkDivider` with on-demand item load | `IMPLEMENTED` | `STATIC_BUNDLE` / `LIVE_OBSERVED` | Wire expansion seamlessly to detail mode filter. |

### 2.3 Codex & Detail-Mode Presentation

| # | Feature / Capability | Official Implementation | Native Implementation | Status | Evidence Tag | Rationale & Next Action |
|---|---|---|---|---|---|---|
| 3.1 | **Detail-Mode Presentation Filtering** | 3-way toggle (`Prose` / `Commands` / `Execution`) | Collapsed work divider only | `PARTIAL` | `STATIC_BUNDLE` | Implement client-side `CodexSegment` projection filter (Slice C). |
| 3.2 | **Clean-Room Prompt Discipline** | Injects proprietary `STEPS_PROSE` / `a2` prompt instructions | Zero prompt injection; pure UI projection filter | `NATIVE_ADVANTAGE` | `STATIC_BUNDLE` | **KEEP OUR ADVANTAGE**: Strict compliance with `AGENTS.md` Rule #1 (no proprietary prompts). |
| 3.3 | **Child Process Stdio JSON-RPC Transport** | Spawns `codex app-server --listen stdio://` | Process transport managing `codex app-server` | `IMPLEMENTED` | `PUBLIC_SOURCE` / `LOCAL_SCHEMA` | Clean JSON-RPC 2.0 framing, request/response correlation, clean shutdown. |
| 3.4 | **Stock Codex Protocol Schemas** | 180 client requests, 86 notifications, 11 server requests | Typed JSON-RPC protocol adapters | `IMPLEMENTED` | `LOCAL_SCHEMA` | Fully validated against stock `codex app-server` schemas. |
| 3.5 | **Zero Direct SQLite Mutation** | Electron app reads/writes `~/.codex/` via `better-sqlite3` | Zero direct SQLite writes; runtime owns state | `NATIVE_ADVANTAGE` | `STATIC_BUNDLE` / `LOCAL_SCHEMA` | **KEEP OUR ADVANTAGE**: Eliminates database corruption risks on concurrent access. |

### 2.4 Work & Execution

| # | Feature / Capability | Official Implementation | Native Implementation | Status | Evidence Tag | Rationale & Next Action |
|---|---|---|---|---|---|---|
| 4.1 | **Interactive Approval Cards** | Inline banners for commands/patches requiring user confirmation | Inline approval cards for `ServerRequest` | `IMPLEMENTED` | `LOCAL_SCHEMA` | Converge styling using `Codex*` semantic primitives without Material leakage. |
| 4.2 | **Bounded Unified Diff Viewer** | Center-mode file list and hunk viewer (`@pierre/diffs`) | Center-mode diff viewer with lazy hunks | `IMPLEMENTED` | `STATIC_BUNDLE` | Retain lazy loading; converge button and pill styling. |
| 4.3 | **512 MiB Output Spooling** | Browser memory crash on giant terminal output (>100MB) | Native Rust Host spools output to disk (512 MiB cap) | `NATIVE_ADVANTAGE` | `PUBLIC_SOURCE` | **KEEP OUR ADVANTAGE**: Protects UI memory from runaway terminal commands. |
| 4.4 | **Git Worktrees Execution Target** | Switch execution between local repo, worktree, SSH | UI selector stubbed in composer | `PARTIAL` | `STATIC_BUNDLE` | Wire host selector popover in `CodexComposer`. |

### 2.5 Remote & Android Connectivity

| # | Feature / Capability | Official Implementation | Native Implementation | Status | Evidence Tag | Rationale & Next Action |
|---|---|---|---|---|---|---|
| 5.1 | **Direct Host Remote Bridge (`codex-native-host`)** | Cloud relay through OpenAI servers | Direct authenticated WebSocket bridge with sequence/ack replay | `NATIVE_ADVANTAGE` | `PUBLIC_SOURCE` | **KEEP OUR ADVANTAGE**: Low latency, local network support, no cloud relay dependency. |
| 5.2 | **Stock Remote Control Adapter** | Experimental RPCs: `remoteControl/pairing/start`, `pairing/status` | Researched and documented in `CODEX_INTEGRATION_MAP.md` | `RESEARCH_MORE` | `LOCAL_SCHEMA` | Retain as optional compatibility adapter; keep Direct Host as primary. |
| 5.3 | **Host Credential Isolation** | Mobile client connects via relay; credentials stay on host | Android client pairs via token; credentials never leave host | `NATIVE_ADVANTAGE` | `PUBLIC_DOC` / `STATIC_APK` | **KEEP OUR ADVANTAGE**: Enforces strict security boundary for mobile devices. |

### 2.6 Plugins, Skills & Ecosystem

| # | Feature / Capability | Official Implementation | Native Implementation | Status | Evidence Tag | Rationale & Next Action |
|---|---|---|---|---|---|---|
| 6.1 | **MCP Client Protocol** | Bundled MCP client invoking external servers | Supported via `codex app-server` MCP integrations | `IMPLEMENTED` | `LOCAL_SCHEMA` | Handled natively by stock `codex app-server`. |
| 6.2 | **Bundled Skills (`$skill`)** | Ingests skill instructions from `~/.codex/skills` | Detected via `codex app-server` | `IMPLEMENTED` | `PUBLIC_DOC` | App-server manages skill registration and tool exposure. |
| 6.3 | **Skybridge / Custom Connectors** | Proprietary internal plugin hosting bridge | Internal proprietary service | `PRIVATE_ONLY` | `STATIC_BUNDLE` | Do not implement; rely on open MCP standards. |

### 2.7 Voice, Browser & Advanced Surfaces

| # | Feature / Capability | Official Implementation | Native Implementation | Status | Evidence Tag | Rationale & Next Action |
|---|---|---|---|---|---|---|
| 7.1 | **Voice Input / Dictation** | Whisper API / WebRTC audio stream | Stubbed microphone affordance in composer | `RESEARCH_MORE` | `STATIC_BUNDLE` / `STATIC_APK` | Future milestone; not required for core desktop coding. |
| 7.2 | **Computer-Use / Screen Inspection** | Desktop screen capture via OS permissions | Not implemented | `NOT_APPLICABLE` | `PUBLIC_DOC` | Out of scope for native Codex client. |
| 7.3 | **Proprietary Web Endpoints (`/wham/*`)** | Internal telemetry, credit usage, marketing popups | Omitted | `PRIVATE_ONLY` | `STATIC_BUNDLE` | Strictly excluded from clean-room architecture. |
