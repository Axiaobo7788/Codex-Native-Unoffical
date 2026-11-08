# Project Status

_Last updated: 2026-11-08_

This file is the repository's durable project memory. Update it whenever a task materially changes implementation status, milestones, known blockers, or the next recommended step.

## Operating mode

**Mode: `HUMAN_REVIEW`**

- Current status: **`DESKTOP_SHARED_CONVERSATION_FOUNDATION_RECALIBRATED — HUMAN_REVIEW_REQUIRED`**.
- Prior phase marker (`cb684b5`, preserved history): `DESKTOP_SHARED_CONVERSATION_FOUNDATION_VERIFIED — HUMAN_REVIEW_REQUIRED` — reopened into `SELF_ITERATION` per `ADR-030` after Human/code review and hosted CI inspection identified 2 P1 edge cases (deep-history bookmark fallback beyond `_maxRestorePages = 10`, protocol-boundary `HistoryItem.attachments` metadata bounding), 3 P2 edge cases (legacy envelope false positives & quoted-preview delimiter spoofing, literal `&#x20;` prose preservation, `_RenderConversationViewport` semantics transform & selection evidence tightening), `dart format` CI drift on `cb684b5`, and symbol/constant documentation drift across `PROJECT_STATUS.md`, `docs/RESEARCH.md`, and `docs/reverse/ADOPTION_MATRIX.md`. All machine-actionable fixes, regression tests, live Linux walkthrough, and hosted CI gates are now complete.

## Current phase

**Phase 1 — Flutter + Codex app-server vertical slice: IMPLEMENTED, VERIFIED, COMMITTED (`5089320`)**

**Phase 2 — Local usable Codex client: IMPLEMENTED AND MACHINE-VERIFIED — Human approval interaction remains a separate gate**

**Phase 3 — Bounded-memory long-session UX: LINUX MACHINE-ACTIONABLE WORK EXHAUSTED — paginated history, bounded native command-output viewing, safe lazy assistant Markdown, storage-failure recovery, and lifecycle soak are integrated; cross-platform and Human gates remain**

**Phase 4 — Android Remote: PAUSED BY EXPLICIT PRIORITY OVERRIDE — the existing bounded read-only transport/onboarding/admin work remains intact, but writes, approvals, full conversation integration, headless Host work, relay migration, and mobile architecture work must not advance during the Desktop UI phase**

**Prior Desktop UI phase marker (`7f220d5`, preserved history): `DESKTOP_UI_PHASE_COMPLETE — STOPPED FOR MOBILE RESEARCH` — superseded by Human real-use review on 2026-11-07 because machine-only widget tests missed real-use scroll positioning, history anchor preservation, user attachment envelope presentation, and desktop product-completeness defects.**

**Desktop UI productization checkpoint — MACHINE-VERIFIED AND LIVE-LINUX-WALKED; Human acceptance remains pending. The prior marker `DESKTOP_PRODUCT_UX_REVIEW_COMPLETE — STOPPED FOR USER REVIEW` is preserved as checkpoint history.**

**Prior reverse-analysis marker (`17f08f3`, preserved history): `REVERSE_ANALYSIS_MACHINE_COMPLETE — HUMAN_REVIEW_REQUIRED` — superseded by Human/code review on 2026-11-07 (`ADR-032`) to correct current-state drift, separate static/live/public evidence grades, recalibrate `STEPS_PROSE`/Work/Chat/Remote conclusions, and reconcile adoption recommendations with current `HEAD`.**

**Reverse-analysis checkpoint — `REVERSE_ANALYSIS_RECALIBRATED — HUMAN_REVIEW_REQUIRED` at `99e6141` was Human-reviewed and accepted as the research baseline (`683d431`).**

**Prior foundation-hardening marker (`cb684b5`, preserved history): `DESKTOP_SHARED_CONVERSATION_FOUNDATION_VERIFIED — HUMAN_REVIEW_REQUIRED` — core `16.A–16.E` architecture accepted, reopened into `SELF_ITERATION` for targeted P1/P2 boundary fixes, CI format gate restoration, and code-to-documentation reconciliation.**

**Current phase — Desktop Shared Conversation Foundation Correction & Evidence Tightening: `DESKTOP_SHARED_CONVERSATION_FOUNDATION_RECALIBRATED — HUMAN_REVIEW_REQUIRED` (`Mode: HUMAN_REVIEW`).**

## Current repository state

- Flutter application shells exist for Linux, Windows, macOS, and Android under the Dart package `codex_native_unofficial`, with native desktop window titles set to `Codex Native`.
- Desktop runtime flow is real, not mocked:
  - locate `codex` through `CODEX_EXECUTABLE` or `PATH`;
  - spawn stock `codex app-server --listen stdio://`;
  - decode fragmented/multiple JSONL messages;
  - correlate JSON-RPC requests and responses;
  - perform `initialize` followed by `initialized`;
  - surface typed runtime status to Flutter widgets;
  - capture a bounded stderr tail, report malformed protocol data and process exits, and close the child without leaving an orphan.
- `CodexTransport` isolates feature/domain code from transport details. The
  production desktop uses `ProcessTransport`; a read-only `RemoteTransport`
  now reuses the typed model/thread/turn adapters. A separate `RemoteSession`
  seam, bounded projection, applied-cursor store, and reconnect coordinator own
  resync/readiness without changing desktop behavior. Android now constructs
  this stack from platform secure storage and exposes its explicit lifecycle
  states plus bounded read-only metadata, without enabling unsupported gateways.
- Typed thread operations now cover bounded `thread/list`, `thread/start`, metadata-only `thread/read`, history-excluding `thread/resume`, and exact-ID delete for smoke-test cleanup.
- The desktop UI lists at most 100 thread metadata rows, deduplicates `thread/list` rows by `thread.id` with bounded continuation top-up (up to 2 extra pages on `refresh()`) when duplicate rollout entries reduce the initial unique count below `pageSize`, paginates with opaque server cursors, accepts a working directory for new threads, exposes select/resume actions, automatically creates a new thread when submitting from the unselected `Let’s build` landing state, and automatically resumes a selected `notLoaded` thread when the user submits a turn from the composer (`ensureSelectedThreadLoaded()`). It does not retain turns or raw protocol JSON.
- Typed turn operations cover `turn/start`, `turn/interrupt`, lifecycle, assistant text, bounded activity summaries, terminal errors, and completion states without client prompt rewriting.
- The conversation projection retains at most 200 recent entries and 64 KiB per entry, coalesces streaming updates on a 50 ms cadence, and never retains command output payloads.
- Command/file-change approvals support explicit approve-once and reject responses. Unknown and unsupported server requests fail closed and cannot expose an approve action. The real reject path is verified; approve-once is currently unit-tested but not Human-validated.
- `model/list` drives typed visible-model and reasoning-effort controls. Model, effort, approval, and sandbox overrides are omitted by default; `never` approval and `danger-full-access` require an explicit UI confirmation.
- Turn diff notifications are converted immediately into a bounded typed projection: at most 2 MiB processed input, 100 files, 512 KiB retained total, 128 KiB and 4,000 lines per file, and 2,000 characters per retained line. Only the selected file's rows are built by the diff view.
- The desktop UI is a full-window Codex-inspired product workspace: a
  collapsible 264 px project/thread sidebar (`Ctrl+B` / `Cmd+B`), lightweight
  `[edit_square] New thread` action row, collapsible project groups with single
  leading icon (`folder_outlined` / hover chevron) and quick `+` new-thread
  actions, inline thread search (`Ctrl+K` / `Cmd+K`), `Ctrl+N` / `Cmd+N` new
  thread shortcut, compact relative thread timestamps (`now`, `15m`, `2h`, `1d`,
  `2w`, `1mo`, `1y`) without false warning dots on `notLoaded` threads, a quiet
  footer status indicator, a single-line `<Thread Title>  <Project Name>`
  conversation header, a `>_` `Let’s build` landing state with active composer,
  a maximum-760 px reading/composer column, clickable `Worked for Xm Ys ›` / `⌄`
  turn work-duration dividers that expand/collapse `thread/items/list` activity
  on demand, compact typed activity rows, quiet reasoning rows, completed
  assistant copy buttons (`assistant-copy-<id>`), fenced code block headers with
  `Copy` buttons, neutral user bubbles (`#F0F0EC` light / `#2A2B29` dark) with
  `&#x20;\` escape continuation cleanup (while preserving literal `&#x20;` in
  user prose), structured attachment chips (`UserAttachment` in
  `lib/src/domain/user_message_presentation.dart`, normalizing and bounding
  `HistoryItem.attachments` at both `HistoryProtocolAdapter._userAttachments()`
  and `parseUserMessagePresentation` with `maxUserAttachments = 16`,
  `maxAttachmentLabelLength = 160`, `maxAttachmentPathLength = 1024`,
  `maxAttachmentPreviewLength = 2048`, `maxEnvelopeHeaderScanCharacters = 16 * 1024`,
  `seenAttachmentKeys`, and `structuredPaths`), and `Show full message` / `Show
  less` disclosure, inline approvals, selected-file diff, a dark bounded output
  viewer, and a right-aligned `<Model> · <Effort> ⌄` summary pill + Send button
  in the composer.
- The conversation timeline uses a bottom-anchored `CustomScrollView`
  (`anchor: 1.0`, `center` key at the bottom, and a reverse-growing
  `SliverList.builder` with `findChildIndexCallback` before `center`) with a
  custom `_RenderConversationViewport` (`paintOffset` on
  `SliverPhysicalParentData`) that top-aligns short conversations when total
  content height is smaller than the viewport (audited and widget-tested across
  pointer hit-testing, global transformed `SemanticsNode` bounds,
  `SelectableText` selection, focus `ensureVisible`, and dynamic resize).
  Opening or switching to a long thread lands immediately at the latest turn
  (`scrollOffset == 0.0`) on Frame 1, prepending older turns (`Load older
  turns`) preserves the user's current visual anchor both within and across the
  `>100-turn` sliding-window eviction boundary (`0.0 px` drift), live streaming
  follows within `160 px` of latest and preserves the visible anchor without
  yank when scrolled up (`_pendingStreamAnchor`), a floating `Jump to latest`
  pill appears when scrolled up or when the `100`-turn window is shifted, and at
  most `32` per-thread content-identity scroll bookmarks
  (`_ThreadScrollBookmark`: non-null `anchorItemKey`, `anchorTurnId`,
  `anchorViewportTopDy`, `scrollPixels`) are retained in memory to restore
  multi-page scroll positions across up to `_maxRestorePages = 10` older-page
  requests (`220` turns including the initial page) and viewport resizes without
  retaining inactive thread history, while deterministically discarding stale
  bookmarks and resetting to newest (`pixels == 0.0`) if a deep anchor lies
  beyond the restore budget.
- Explicit `CodexPalette` light/dark theme extensions now own neutral,
  semantic, diff, code, focus, hover, selected, typography, radius, border, and
  density tokens. System brightness selects the first default theme;
  `ColorScheme.fromSeed()` no longer determines product appearance. Flutter
  Material remains only the native input/focus/semantics implementation layer.
- `codex_native_app.dart` retains root controller/lifecycle ownership while the
  presentation is split into app shell, sidebar/activity, conversation/
  composer/settings, approval/diff/output, runtime details, Remote setup, and
  Remote onboarding modules. `lib/src/domain/` forms a strict acyclic dependency
  graph (`user_message_presentation.dart` leaf module). Protocol, domain,
  transport, pagination, coalescing, output, diff, and retention contracts remain
  cleanly separated.
- A real small coding task completed through the production Runtime, Conversation, and Diff controllers in a dedicated temporary workspace; it modified exactly one requested file, projected the diff, completed the turn, and cleaned its thread/workspace.
- Stored history uses `thread/turns/list` with `itemsView:summary` and opaque descending cursors. The UI retains a sliding window of at most 100 turns (`turnPageSize = 20`, `maxRetainedTurns = 100`), drives UI post-load anchor alignment via `loadOlderVersion` + `findChildIndexCallback` + `_MeasuredTimelineItem`, tracks sliding-window eviction via `evictionVersion` and `lastEvictedItemIds` (pruning evicted `history-<id>` keys from `_measuredItemHeights`), and can return directly to the newest page via `Jump to latest`.
- The typed history layer loads ascending `thread/items/list` pages for exactly
  one user-selected turn with a 100-item cap. Large `aggregatedOutput` fields are
  removed by the Host before Dart decoding, and switching threads discards all
  stored-history state immediately.
- Stored and live entries are merged by item ID into one virtualized list so a resumed active turn does not render duplicate items.
- `codex-native-host` now supervises stock app-server by default, validates
  stdout incrementally without line buffering, spools decoded
  `aggregatedOutput` values behind opaque references, replaces them with bounded
  descriptors, reuses one session object for exact repeated logical content,
  and implements capped `host/status`, `stat`, `readRange`, and `tail` RPCs.
  The content digest remains internal; Flutter locates Codex and the bundled
  Host independently and has no silent direct-app-server fallback.
- Unpublished output spools are transactional: write, parse-abandonment, flush,
  rename, or metadata failures remove partial artifacts and return their bytes
  to the session budget. Newly created objects remain candidate-owned until the
  first complete descriptor-bearing delivery; pre-delivery malformed JSON or a
  sole-observer failure rolls them back, while a later secondary-delivery
  failure cannot invalidate an object already received by Flutter. Linux
  disk-full simulation degrades the selected output to an unavailable descriptor
  without reinjecting it; invalid or unwritable cache roots fail with context
  before Codex is spawned.
- Historical command rows load full items for only one selected turn. List
  requests prefer upstream output deferral; a deferred selected item uses the
  gated `thread/items/read` API, whose response is still sanitized by the Host.
  The log dialog retains one approximately 64 KiB byte window, uses bounded
  first/previous/next/tail reads, preserves UTF-8 page edges, and virtualizes
  display rows.
- Linux and Windows native builds compile/package the Host beside the app.
  macOS embeds and signs it in `Contents/MacOS`; v1 macOS is a direct notarized
  distribution because App Sandbox cannot preserve the required normal Codex
  developer-workspace/toolchain model. Debug builds use Xcode's active
  architecture; non-Debug builds compile each requested Rust target, merge the
  Host with `lipo`, and sign the merged binary. Hosted Windows Server 2022 now
  verifies the debug bundle, packaged Host/license pair, and Host `--help`. The
  first hosted macOS 15 arm64 build exposed a Bash 3.2 empty-array failure; the
  corrected prior native build/package/Host execution passes on macOS 15 arm64.
  CI `42129434391` now also verifies the release runner, nested Host, App
  framework, and Flutter engine as exact arm64+x86_64 binaries.
- The native Host's complete lockfile-derived runtime license notice is committed
  and drift-checked with pinned `cargo-about` 0.9.3. Linux/Windows package it
  beside the Host and macOS declares it under `Contents/Resources`; Linux and
  hosted Windows/macOS bundle byte identity are verified.
- Completed assistant messages use a project-owned safe Markdown allowlist only
  while in-progress streaming remains selectable plain text. Raw HTML is inert,
  images never load, links require an explicit click and absolute `http`/`https`
  URI, and rich parsing falls back to a bounded plain-text tail above 16 KiB.
  The outer virtualized timeline controls widget construction and no global AST
  cache retains inactive messages.
- Cross-platform RSS/runtime evidence and Human interaction acceptance are not
  complete yet. Those remaining Phase 3 gates require unavailable Human,
  Windows, macOS, or installed-volume evidence in this Linux session, so Phase 4
  machine-actionable work has started without misreporting those gates complete.
- Android Remote now has a pure Rust Host core for typed negotiation,
  session/sequence/ACK resume, count-and-byte-bounded replay, multi-connection
  request correlation, bounded same-session write idempotency, single-use
  pairing, and hash-only scoped device credentials. The WS/WSS listener uses
  these primitives. Android now has a strict platform-backed WSS/default-root
  device-record owner plus a bounded WSS pairing/recovery UI. The Android flow
  still requires an exact operator-configured endpoint. The desktop setup
  surface now reads that explicit advertised endpoint and creates a one-use
  ticket on demand without exposing the issued bearer.
- The desktop Host exposes trusted local `host/remote/pairing/create`,
  `host/remote/devices/list`, and `host/remote/devices/revoke` administration.
  Its credential registry is loaded lazily from a configurable user config file,
  so Remote-store corruption cannot block ordinary local Host status or Codex
  startup. The desktop Flutter surface accesses these methods only through a
  local administration gateway outside `CodexTransport`, reports listener/TLS/
  bind/advertised endpoint state, creates no ticket on open, and confirms every
  device revocation before authoritative readback.
- The Host can explicitly enable a plaintext listener only on a literal loopback
  address. A non-loopback listener requires an operator-provided PEM certificate
  chain/private key and uses rustls HTTPS/WSS; invalid or incomplete material
  fails before bind and before stock Codex starts. Unix keys must be owner-only;
  macOS keys must also have no extended ACL.
  Trusted local `host/remote/tls/reload` atomically changes new-handshake identity
  without dropping established sockets and retains the last valid configuration
  on failure. The bounded endpoints implement pairing, version negotiation,
  heartbeat, live revocation, and coordinated shutdown. The socket exposes
  `host/remote/status`, `model/list`, bounded `thread/list`, and metadata-only
  `thread/read` through the same sanitized stock app-server process. Six bounded
  lifecycle/state notification methods feed sequenced live delivery and same-
  session replay. Android now maps hidden/shown application visibility to
  suspend/resume and displays the bounded ready projection in a read-only panel.
  Android can now decode one bounded versioned invitation, exchange its one-use
  ticket over system-root or invitation-scoped certificate HTTPS, verify and
  save the issued bearer/trust atomically, reuse the same trust for WSS, connect
  only after readback, and explicitly clear an unreadable/revoked profile.
  Desktop can project the exact invitation into one medium-correction QR symbol
  when it fits, without splitting or rewriting the protocol; manual copy remains
  complete for oversized payloads. The transient ticket and QR now disappear at
  expiry. Android can scan QR only after an explicit action, validate the first
  exact current invitation, and fill the obscured form without automatically
  pairing. Manual paste remains complete after invalid input, unavailable camera,
  or denied permission. There is still no Remote write/approval path, full
  conversation surface, or physical-device evidence.
- GitHub Actions CI now fixes Ubuntu 22.04 x64, Windows Server 2022 x64, and
  macOS 15 arm64 runners; uses exact Flutter 3.47.1 and Rust 1.89.0 toolchains;
  builds Linux, Android, Windows, and macOS; and validates the packaged desktop
  Host/license pair. Top-level actions are immutable-SHA pinned, checkout
  credentials are not persisted, and permissions remain read-only. Run
  `42087567359` at `879c26d` passed all three jobs: exact-Rust/Dart/Flutter
  verification, Linux and Android debug builds, and the then-current native
  Windows x64/macOS arm64 bundle/Host/license gates. The current workflow
  advances macOS to a universal release/Host/license gate; run `42129434391` at
  `0b34ae6` passed that new path plus the Windows and Linux/Android jobs.
- Replacement run `42091764792` at `76bf94c` also passed all three jobs after
  the native-notice EOL contract landed, including Ubuntu verification/Linux
  and Android debug builds plus native Windows x64/macOS arm64 bundle gates.
- A separate manual, read-only desktop review-artifact workflow now builds
  release-mode Linux x64, Windows x64, and macOS universal bundles without
  creating tags or Releases. Its assembler requires platform AOT/runtime layout,
  exact notices, no debug kernel, Host execution, source identity, per-file
  SHA-256, archive provenance, and extraction/reinventory verification. Every
  artifact is explicitly `review-only` and `distributionReady=false`. Hosted run
  `42095949000` at `e71e5ac` passed all three targets; the downloaded Linux,
  Windows, and macOS outputs each passed a fresh independent verifier run and
  exact sidecar checksum comparison. A later native-runtime audit preserved a
  narrower Linux defect that those structural checks could not see: both linked
  plugin libraries retained a build-tree RUNPATH. The CMake/runtime-gate fix is
  now locally and on clean hosted runners verified by run `42100825202` at
  `c1803d4`, including extracted native-runtime checks on all three platforms.
  Universal follow-up run `42131127906` at `0b34ae6` passed Linux x64, Windows
  x64, and macOS universal release build/assembly/self-verification/independent
  native verification, then passed the Linux clean-runtime container job.
  None of these artifacts proves signing, native installation, publisher
  identity, or Human acceptance.
- Android release variants no longer inherit the public debug certificate or
  emit an ambiguous unsigned candidate. A complete external, Git-ignored upload
  keystore contract is required at `preReleaseBuild`; debug CI remains
  credential-free. No production key, Play configuration, or signing secret is
  stored or provisioned by the repository.

## Completed

### 2026-11-07 — ChatGPT Desktop 26.1103.32239 full-stack reverse analysis and unified Native platform map (`ADR-031`)

- Completed clean-room full-stack reverse analysis of the installed latest
  ChatGPT Desktop (`ChatGPT_Desktop_1.2026.103.0_x64.deb`, app version
  `26.1103.32239`, `codexBuildNumber: 25471`, Chromium/Owl `157.0.8103.39`),
  combining live DevTools inspection (`http://127.0.0.1:9333`), local SQLite
  runtime/catalog inspection (`~/.codex/state_5.sqlite`,
  `thread_history_1.sqlite`, `~/.codex/sqlite/codex.db`), and static bundle
  extraction via the committed clean-room tool
  `tools/reverse/inspect_chatgpt_desktop.py`.
- Produced the complete 9-document reverse-analysis and target-architecture
  suite in `docs/reverse/`:
  1. `docs/reverse/DESKTOP_ARCHITECTURE_MAP.md` — Owl runtime topology, worker
     threads (`worker.js`, `git-worker`, `visualize-cache-worker`), preload
     bridges, native sidecars (`codex 0.167.0-alpha.3.2`,
     `codex-code-mode-host`, `cua_node`, `rg`, `tectonic 0.17.0`,
     `artifact-template-picker`, `dictation-ducking`,
     `remote-control-device-key.node`, `hid-topology-watcher.node`), all 26
     `codex_desktop:*` IPC channels, tokenized 256 KiB chunked IPC
     (`codex-host-chunked-message-v1`), and how Chat, Work, and Codex share one
     unified shell.
  2. `docs/reverse/UI_REFERENCE.md` — Provenance-tagged design tokens
     (`[derived from computed style]`, `[observed live]`,
     `[static bundle only]`) and component-to-logic mappings across shell,
     sidebar, header, timeline, composer, approvals, diff, terminal/output, and
     Skybridge.
  3. `docs/reverse/DATA_FLOW.md` — End-to-end runtime flows for startup
     (`getInitialSidebarBootstrap` + `ThreadCatalogSyncManager`), Cloud Chat
     (`MrGp` DAG + `AuIy.Ph` + `uNU6.submitChatGPTCompletion`), Work
     (`STEPS_PROSE` + `tpp` local executor hybrid + `thread/startAeon` on
     Durable Cloud Host), and Codex (`turnHistory.kind === "canonical"`
     islands, tail hydration, opening `userMessage` anchoring,
     viewport-protected active eviction `setBoundary` -> `yV`/`yZ` 1000->500
     cap, fine-grained reactive item/slot maps, and 10-thread LRU).
  4. `docs/reverse/LOCAL_STORAGE_MAP.md` — Full schema and lifecycle map of
     Tier A (`~/.codex/state_5.sqlite`, `thread_history_1.sqlite` byte-offset
     `.jsonl` rollout index, `queue_1.sqlite`, `goals_1.sqlite`,
     `memories_1.sqlite`, `memories_v2_1.sqlite`, `logs_2.sqlite`,
     `reviews.sqlite`) and Tier B (`~/.codex/sqlite/codex.db`
     `local_thread_catalog`, `local_thread_catalog_hosts`,
     `thread_timeline_ledger`, `automations`, `inbox_items`), plus our 5-layer
     target Native storage architecture (`codex_native_catalog.sqlite`).
  5. `docs/reverse/NETWORK_SURFACES.md` — Complete catalog of common headers,
     SSE/JSONL parsers (`WvOS`), retry/error models, `/backend-api/*`
     endpoints, 146 `/wham/*` endpoints,
     `wss://codex-cloud-backend.chatgpt.com/`,
     `wss://chatgpt.com/backend-api/wham/remote/control/server`, and `d5Fp`
     feature flags, classified into `PUBLIC_SUPPORTED`,
     `PUBLIC_UNOFFICIAL_CLIENT_OK`, `PRIVATE_WEB_SESSION`,
     `PRIVATE_INTERNAL_SERVICE`, and `UNKNOWN`.
  6. `docs/reverse/CHATGPT_COMPATIBILITY.md` — Cloud Chat history sync
     (`ThreadCatalogSyncManager` `chatgpt:` host, 30-day window, 5-min
     backoff), DAG branching/editing/regeneration (`MrGp`), unified projects
     (`codex_unified_projects` `g-p-*` snorlax gizmos), public vs private
     compatibility assessment, and our tiered Phase 1 Native Chat plan.
  7. `docs/reverse/PLUGIN_HOST_MAP.md` — Taxonomy of Plugins, Skills, MCP
     Servers, Apps/Connectors, and Skybridge (`codex-sandbox://` + 19
     `MessagePort` channels), full catalog of the 7 bundled plugins
     (`codex-app-tools`, `browser`, `chrome`, `unified-computer-use`, `latex`,
     `deep-research`, `visualize`), and our 3-tier Shared Capability Host
     architecture.
  8. `docs/reverse/CODEX_INTEGRATION_MAP.md` — Local `codex app-server` spawn &
     env config, version-gated capability matrix (`Ehlj` from `0.141.0` to
     `0.167.0-alpha.1`), all 88 JSON-RPC methods, the 5 official transports
     (`stdio`, `ssh`, `wsl`, `remote-control`, durable cloud WS), hardware-key
     Remote Control enrollment (`remote-control-device-key.node` + MFA
     `step_up_token`), and Direct Host comparison.
  9. `docs/reverse/ADOPTION_MATRIX.md` — Subsystem-by-subsystem adoption matrix
     (`ADOPT_AS_CONCEPT`, `ADOPT_PROTOCOL_COMPATIBLE`, `REIMPLEMENT_NATIVELY`,
     `OPTIONAL_EXPERIMENTAL`, `DO_NOT_ADOPT`), resolution of the 5 Round-2 UI
     code-review items, and answers to all 18 Architecture Recommendation
     questions.
- Accepted `ADR-031`, removed `/tmp/chatgpt_desktop_inspect`, verified
  `python3 tools/reverse/inspect_chatgpt_desktop.py --summary --plugins`
  standalone, and transitioned `PROJECT_STATUS.md` to `Mode: HUMAN_REVIEW`
  (`REVERSE_ANALYSIS_MACHINE_COMPLETE — HUMAN_REVIEW_REQUIRED`).

### 2026-11-07 — Reopened Desktop UI real-use review, side-by-side self-audit, productization, and stop

- Human real-use review on Linux reopened Desktop UI fidelity/polish after
  `7f220d5` (`ADR-029` supersedes `ADR-028`'s machine-only closure marker
  without deleting history). Real-use inspection and a subsequent pixel-by-pixel
  side-by-side self-audit against the installed official Codex Desktop
  (`0.166.0-alpha.5.1`) identified and fixed the following product-critical gaps:
  1. **Bottom-anchored conversation scroll model (`4d63e57`)**: Replaced the
     top-anchored `ListView.builder` timeline with `_ConversationScrollView`
     (`CustomScrollView` with `anchor: 1.0`, `center` key at the bottom, and a
     reverse-growing `SliverList.builder` before `center`) plus a custom
     `_RenderConversationViewport` that top-aligns short conversations when
     `totalExtent < size.height`. Opening or switching to a multi-turn thread
     now lands at the latest turn on Frame 1 (`pixels == 0.0 == maxScrollExtent`)
     instead of stranding the user at the top of history. Prepending older turn
     pages via `Load older turns` preserves the current visual reading anchor
     without jumping. Live streaming auto-follows only within `160 px` of
     latest, scrolling up reveals a floating `Jump to latest` pill without
     streaming yank, and up to `32` per-thread scroll offsets are retained in
     memory.
  2. **User message envelope, `&#x20;\` cleanup, `Worked for ...` turn divider,
     and assistant copy actions (`9756949` + `7070e08`)**: Added
     `UserAttachment`, `UserMessagePresentation`, and
     `parseUserMessagePresentation` to normalize `# Files pasted by the user:`,
     `# Files mentioned by the user:`, `# Context from my IDE setup:`, and
     `## My request:` / `## My request for Codex:` scaffolding plus non-text
     `userMessage.content` items (`localImage`, `image`, `skill`, `mention`)
     into compact attachment chips above a clean request body without altering
     outbound prompts sent to Codex, while stripping `&#x20;\` and `&#x20;`
     HTML space entities. Added `HistoryTurn.formattedWorkDuration`
     (`Worked for 3m 58s`, `Worked for 16m 20s`) from `startedAt`..`completedAt`
     and rendered a clickable `_TurnWorkDivider` (`─── Worked for 3m 58s › ───`)
     above each turn's assistant/activity block to expand or collapse
     `thread/items/list` on demand (`loadTurnItems` / `collapseTurnItems`).
     Added a copy button (`assistant-copy-<id>`) below completed assistant
     messages, fenced code block header bars with language labels and `Copy`
     buttons in `AssistantMarkdown`, quiet reasoning rows, and inline command
     output actions without raw `completed` protocol status strings.
  3. **Desktop workspace, `thread/list` deduplication, `Let’s build` landing
     state, sidebar, header, and composer polish (`6079016` + `7070e08`)**:
     Updated native Linux, Windows, and macOS window titles from
     `codex_native_unofficial` to `Codex Native`. Updated
     `ThreadListController.refresh()` to deduplicate threads by `thread.id` and
     fetch up to 2 continuation pages so duplicate rollout rows do not hide
     projects (`fura-project`, `libreoffice_modern`). Replaced the solid-filled
     sidebar `New thread` button with a lightweight `[edit_square] New thread`
     action row, consolidated project headings to a single leading icon
     (`folder_outlined` swapping to chevron on hover/collapse), updated thread
     timestamps to compact relative units (`now`, `15m`, `2h`, `1d`, `2w`,
     `1mo`, `1y`), removed false warning dots on
     `ThreadRuntimeStatus.notLoaded` threads, added a single-line
     `<Thread Title>  <Project Name>` conversation header, rendered the `>_`
     `Let’s build` landing view with an active composer that auto-starts a
     thread on first submit when no thread is selected, automatically resumed
     `notLoaded` threads on submit (`ensureSelectedThreadLoaded()`), and pinned
     the `<Model> · <Effort> ⌄` summary pill and Send button (`↑`) flush right
     in the composer.
  4. **Regression coverage (`faa6875` + `7070e08`)**: Added unit and widget
     regression tests in `test/protocol/history_protocol_test.dart`,
     `test/features/threads/thread_list_controller_test.dart`,
     `test/app/bounded_timeline_test.dart`, and
     `test/app/product_controls_test.dart` covering initial latest scroll
     positioning, `Jump to latest`, no streaming yank while scrolled up, visual
     anchor preservation across `Load older turns`, sidebar collapse/search,
     thread deduplication/top-up, `Worked for ...` turn disclosure expand and
     collapse, `&#x20;\` entity cleanup, unselected composer auto-start, model
     summary pill, assistant copy action, and pasted-file user message
     presentation.
- Verification evidence:
  - `dart analyze`: PASS (0 issues).
  - `flutter analyze --no-pub` via ASCII copy `/tmp/codex_native_ascii_copy`:
    PASS (0 issues; direct Unicode-path `flutter analyze` still hits the known
    Flutter 3.47.1 UTF-8 `Content-Length` bug and is preserved as negative
    toolchain evidence).
  - `flutter test`: PASS (188/188 tests).
  - `cargo test --workspace`: PASS (98/98 tests: 26 lib + 68 bin + 4
    integration).
  - `flutter build linux --debug`: PASS
    (`build/linux/x64/debug/bundle/codex_native_unofficial`).
  - Live Linux desktop run against `/opt/codex-desktop/resources/codex`
    (`0.166.0-alpha.5.1`) verified with side-by-side real window captures
    (`live_v2_01_landing.png` .. `live_v2_04_worked_expanded.png`): native
    window title `Codex Native`, `>_` `Let’s build` landing state with active
    composer and flush-right Send button, deduplicated project-grouped sidebar
    including `fura-project` and `libreoffice_modern` with compact relative
    timestamps (`15h`, `1d`, `2w`), selecting `Build Codex desktop vertical
    slice` and `进入人工回归测试模式` landing immediately at `pixels: 0.0`
    (bottom/latest turn) with single-line header and assistant copy icon,
    `Worked for 3m 58s ›` turn divider expanding intermediate `Command:` and
    `Thought` items on click, scrolling up showing `Jump to latest` and
    rendering pasted-file envelopes as `Pasted · 已粘贴的文本.txt` chip + clean
    user bubble without `&#x20;\`, and clean process shutdown.

### 2026-11-06 — Desktop UI fidelity implementation, validation, and stop

- Added the project-owned Codex-inspired light/dark theme and semantic palette
  (`0876ebd`), split the presentation layer without changing controller
  ownership (`e0c8735`), replaced the engineering shell with the responsive
  product workspace (`dca8eb9`), and added narrow approval/output/keyboard
  regression coverage (`4520c8f`). Every logical slice was pushed to
  `origin/main` without history rewriting.
- The product shell now groups the already-bounded thread metadata by project,
  gives hover/selection/focus/runtime states distinct treatments, moves cwd and
  runtime diagnostics behind explicit disclosures, and keeps Remote setup as a
  functioning compact sidebar action. Conversation, empty/loading/error/
  disconnected states, streaming assistant content, tool/activity rows,
  composer, execution controls, approvals, diff, and command output use the
  same token/component language. No OpenAI logo or copied proprietary asset is
  present.
- Responsive behavior is explicit rather than a stacked-scroll fallback. Wide
  mode retains independent virtualized lists; narrow mode switches between
  threads and conversation, enters conversation after selection, and closes the
  sidebar with Escape. Composer interaction is Enter to send and Shift+Enter to
  insert a newline. The timeline keeps near-end-only auto-scroll, Markdown
  remains lazy/bounded, output retains one byte window, and diff renders one
  bounded selected file.
- Final static/widget/build evidence: `dart analyze` PASS; `flutter analyze
  --no-pub` PASS through a temporary ASCII symlink; all 182 Flutter tests PASS;
  and `flutter build linux --debug` PASS. Direct-path `flutter analyze` still
  exits 255 before diagnostics because Flutter 3.47.1 writes an LSP
  `Content-Length` based on characters while this repository path contains
  multibyte Chinese characters. The failed direct-path run is preserved as a
  toolchain/path limitation rather than overwritten by the symlink pass.
- A real Linux debug bundle launched with stock Codex Desktop
  `0.166.0-alpha.5.1`, displayed the new light workspace and live project/thread
  groups, and left no Host/UI process after shutdown. The run still emitted the
  previously known ATK socket-embedding and missing cursor-theme warnings.
- Real stock-app-server gates PASS: runtime initialization and 60 ms shutdown;
  thread list/read/resume with smoke cleanup and 87 ms shutdown; eight visible
  models; completed and interrupted turns; rejected command approval; and the
  production-controller coding task with one requested file/one addition,
  typed diff/history/output, repeated-output deduplication, zero unexpected
  approvals, cleanup, and 64 ms Host shutdown.
- Bounded-state gates PASS: 1,000 source history turns retained only 100, ten
  discarded 3 MiB outputs added 29,052,928 bytes RSS, the 3/30/300 MiB Host
  benchmark kept Host deltas at 266,240/200,704/253,952 bytes and Dart deltas at
  2,482,176/3,760,128/13,725,696 bytes, and the 12-iteration lifecycle soak left
  zero processes and zero sessions (33 ms maximum shutdown).
- Human visual acceptance was not run on Linux, Windows, or macOS; no Human
  high-DPR, dark-mode, populated approval/diff/output, keyboard/accessibility,
  or platform-native chrome review is claimed. Hosted CI for the new UI commits
  is also a distinct external gate and is not claimed by the local evidence.
- Accepted ADR-028 and stopped autonomous implementation. The next authorized
  phase, if the user explicitly resumes work, starts with fresh current mobile/
  Remote research and must not silently inherit the paused architecture
  assumptions.

### 2026-11-06 — Desktop UI fidelity priority override and current-product research

- Reclassified Desktop UI fidelity as the immediate and sole product phase.
  Android Remote expansion, official relay migration, ChatGPT integration,
  headless Host work, Skills/MCP/Plugins expansion, release engineering,
  installers, signing, extra CI hardening, and non-blocking ACL/TLS work are
  explicitly paused rather than silently treated as abandoned.
- Reviewed current first-party product material, including the unified ChatGPT
  Desktop transition, the still-separate Codex view/history, current composer
  behavior, the project/thread/change workflow, and a reported scrollbar/panel
  interaction regression. Cross-checked the earlier standalone Codex layout
  against one current tutorial and one unlicensed clean-room recreation without
  copying either implementation or assets.
- Recorded an evidence-ranked information architecture, component geometry,
  visual token targets, responsive behavior, state matrix, keyboard/focus/scroll
  requirements, deliberate non-adoptions, and bounded-memory validation plan in
  `docs/RESEARCH.md`.
- Accepted ADR-027: the first default theme is Codex-inspired rather than
  seed-derived Material 3; Flutter Material remains an implementation substrate;
  protocol, controller, lifecycle, and bounded-memory behavior are unchanged;
  and completion requires an explicit stop.

### 2026-11-06 — Session-local exact output deduplication and candidate rollback

- Reviewed current Codex whole-item output behavior, the Chrome DevTools
  explicit stream-close ownership model, Bazel Remote Execution's digest+size
  CAS identity, and ccache's separate reuse/corruption model. ADR-025 adopts only
  a private session identity: streaming SHA-256 over every decoded logical byte
  plus complete logical length. Public descriptors remain opaque random UUIDs.
- Exact repeated output now reuses one readable data/metadata pair even after
  the session budget is full. The identity covers bytes beyond a truncated
  stored prefix; concurrent identical finishes keep one winner; a missing or
  size-inconsistent indexed object is evicted before replacement with
  conservative accounting when deletion cannot be proved. The in-memory index
  and retained object count are independently capped at 16,384; an existing
  duplicate can still be reused at capacity, while a new unique output becomes
  unavailable and rolls back its files/bytes.
- A JSON candidate now tracks only the output objects it created. Malformed,
  truncated, or otherwise undelivered candidates remove their index/files and
  release exact budget, while a failed duplicate cannot delete a prior shared
  object. Remote-response observer failure rolls back an undelivered output;
  once a notification is completely delivered to local stdout, a later Remote
  observer failure retains the object and avoids a dangling Flutter reference.
- The release benchmark now reads each 3/30/300 MiB fixture item twice, requires
  one shared ref plus exactly one `.data`, one `.json`, and zero `.part` files,
  and passed with Host RSS deltas of 200,704/200,704/266,240 bytes and Dart
  deltas of 2,269,184/2,473,984/3,039,232 bytes. Fixture deltas remained
  8,396,800/94,380,032/629,153,792 bytes.
- The real stock-app-server coding smoke passed again: one file/one addition,
  zero unexpected approvals, one retained 6-byte output, exact repeated-item
  reference reuse, test thread/workspace cleanup, and 59 ms Host shutdown.
  This does not remove stock app-server's preceding full-string allocation,
  linear Host hashing/transient duplicate `.part` I/O, or the need for
  Windows/macOS and installed-volume evidence.
- Final local gates pass: Rust format/Clippy and 98 tests, Dart format/analyze,
  native-license regeneration/packaging drift checks, all 176 Flutter tests,
  release Host build, the repeated-output memory benchmark, and the real coding
  smoke.
- Code-bearing CI run `42135777838` at `4d35b56` passed all three jobs. Linux/
  Android job `127623402214` passed the complete formatting, license, signing,
  scanner, Clippy, 98-test Rust, hosted `flutter analyze`, 176-test Flutter,
  Linux build/runtime closure, Host/license package, and debug APK gates.
  Windows job `127623402465` passed native tests, debug build, packaged Host,
  and license verification. macOS job `127623402670` passed native tests,
  universal release build, four-binary architecture checks, packaged Host
  execution, and license identity. This is cross-platform build/package
  evidence, not installed-volume exhaustion, physical-device, Intel execution,
  signing/notarization, or Human acceptance.

### 2026-11-06 — macOS universal nested Host boundary

- Reviewed Apple's universal-binary/build-setting guidance, Rust's official
  Apple target support, the pinned Flutter 3.47.1 macOS build behavior, and
  independent Apache-2.0 implementations in Tauri, Isar, and OpenWallet Askar.
  ADR-024 makes Xcode `ARCHS` authoritative and preserves active-architecture
  Debug iteration.
- The macOS Xcode phase now builds `codex-native-host` once per explicit Rust
  target, merges multiple slices with the system `lipo`, and signs only the
  final embedded binary. Empty or unknown architecture requests fail; the script
  never installs a toolchain target or silently drops a slice.
- CI now uses a release macOS build and requires the runner, nested Host, App
  framework, and Flutter engine to contain exactly arm64 and x86_64. Manual
  review provenance is `macos-universal`, and matching-host assembly plus
  extracted native verification enforce the same four-binary property.
- Local Bash syntax/diff checks, native-license packaging, `dart analyze`, and
  all 176 Flutter tests pass. Two `flutter analyze` attempts exited 255 before
  diagnostics because the analysis server received a truncated LSP
  initialization JSON at character 400; that local tool failure remains
  negative evidence rather than a green local Flutter-analysis claim. Linux
  cannot compile or inspect Apple Mach-O binaries; the hosted evidence below
  supplies those separate macOS and Flutter-analysis gates. Physical Intel
  execution, Developer ID signing, notarization/Gatekeeper, installed workspace
  access, and Human review remain separate gates.
- First hosted CI `42128455985` at `a877c9e` compiled both Rust Apple targets,
  passed all 87 native macOS test instances, and completed the 61.4 MB release
  app build. Its direct verification then failed before inspecting any binary:
  the `lipo` command placed `-verify_arch` before the input, so Xcode 16.4 parsed
  the app path as another architecture name. The same argument-order defect was
  present in the Dart matching-host verifier. The correction puts the input
  first for both `-verify_arch` and `-archs`; the failed run remains negative
  evidence.
- Corrective CI `42129434391` at `0b34ae6` passed all three jobs. macOS 15 job
  `127602082306` passed 26 library, 57 binary, and 4 integration tests, built the
  61.4 MB release app, required exactly arm64+x86_64 in the app runner, nested
  Host, App framework, and Flutter engine, then passed Host `0.1.0` execution
  and native-license identity. Windows job `127602082839` passed native tests,
  debug build, Host, and license checks. Linux/Android job `127602082633` passed
  the complete repository gate, including hosted `flutter analyze`, Linux
  runtime closure, and debug APK verification. The macOS build retains Xcode's
  known Flutter-template warning about `Flutter Assemble`; the phase does
  declare generated input/output file lists and intentionally retains dependency
  analysis.
- Manual read-only review run `42131127906` at the same revision passed Linux
  x64 job `127607720970`, Windows x64 job `127607721434`, macOS universal job
  `127607721455`, and Linux clean-runtime job `127610652373`. The macOS job
  passed source-bundle assembly checks plus independent extracted native
  verification and uploaded the 24,774,088-byte GitHub artifact named
  `codex-native-unofficial-macos-universal-review-only`; its archive SHA-256 is
  `7e98452d0e0be660497c4ee564902daf026d0f75ce10a50216d787fa7ef955d0`.
  This closes build/package architecture completeness, not physical Intel
  execution or any signing, notarization, installation, Gatekeeper, or Human
  gate.

### 2026-11-06 — Bounded operator TLS-key permission gate

- Reviewed Win32 handle/security-descriptor APIs, PowerShell/OpenSSH portable at
  `0172cc6adb99d8b4324b8f0391b5b1fd6f39b2c6`, Vercel agent-desktop at
  `b43ac4f6e892ef608f8851428613c4009f0e84c7`, and `axum-server` 0.8's in-memory
  rustls load/reload path. ADR-022 separates read-only external-key validation
  from ADR-021's Host-owned ACL migration.
- TLS startup/reload now opens certificate and key leaves without following a
  symlink/reparse point, requires regular files, and reads from those same
  handles with 1 MiB/256 KiB caps before calling rustls in memory. Unix also
  requires the effective Host user as key owner plus no group/other bits.
  Windows requires a protected valid DACL, owner current user/SYSTEM/
  Administrators, and no allow ACE outside that set; it never rewrites the
  operator file. Failed reload still preserves the last valid identity.
- Added cross-platform oversize/non-disclosure tests, a Unix symlink gate, and
  Windows native cases for both Everyone access and an otherwise-current-user
  DACL that remains inheritable. Local format, warning-free Clippy, and all 87
  Linux Rust test instances pass.
- Preserve initial hosted CI `42120072496` at `e872e36`, Windows job
  `127569808871`, as negative evidence. Windows compiled the new FFI and passed
  all 28 library plus 58 binary tests, including both ACL refusals, invalid
  material redaction, and WSS rotation. The later process-level failure-path
  test then expected only the old rustls parse error even though its unprotected
  temporary key now correctly fails at the earlier ACL gate; two other
  integration cases passed and the Windows build was skipped. The correction
  accepts either bounded pre-child TLS failure without weakening its no-leak or
  child-not-started assertions.
- Final hosted CI `42120995025` at `56c107c`, Windows Server 2022 job
  `127573718517`, passed all 28 library, 58 binary, and 3 process-integration
  tests with no `warning:` or `error:` log line. That includes both native ACL
  refusals, invalid-material non-disclosure, WSS pairing/auth/atomic rotation,
  and the corrected pre-child failure path. It then built Flutter for Windows
  and passed packaged Host `0.1.0` help plus native-license hash checks. The
  same run's Linux/Android verify job `127573718014` passed the full repository
  gate and debug APK verification, while macOS job `127573718461` built and
  verified its Host/license bundle. This establishes the ADR-022 behavior on
  the hosted Windows image; it does not establish installed-service custody,
  installer behavior, macOS extended ACL handling, or Human acceptance.
- The macOS follow-up uses Apple libc's descriptor-based
  `acl_get_fd_np(..., ACL_TYPE_EXTENDED)` after the existing owner/mode check.
  Only explicit `ENOENT` absence passes; any ACL object or other query failure
  is rejected without mutating the operator file. A native test adds an
  `everyone allow read` ACL to an otherwise-`0600` fixture, and the macOS CI job
  now runs the Rust suite before its Flutter build. Local Linux format, Clippy,
  and all 87 applicable Rust test instances pass.
- Final code-bearing CI `42124376817` at `b5dad38`, macOS 15 arm64 job
  `127585024401`, passed 26 library, 57 binary, and 4 process-integration tests;
  the real macOS extended-ACL fixture specifically passed. It then built the
  macOS Flutter app and passed packaged Host `0.1.0` help plus native-license
  byte-identity checks. Linux/Android job `127585024849` passed the full
  repository and debug APK gates, and Windows job `127585024928` passed native
  tests, build, and Host/license smoke. The macOS log retains one Xcode warning
  from the Flutter template about its `Flutter Assemble` Run Script. The phase
  does declare generated input/output file lists; Flutter's open triaged issue
  #123735 treats this as an Xcode diagnostic defect and maintainers advise
  against disabling dependency analysis. It did not block the build and is
  separate from the ACL behavior.
- Windows ACL evidence follow-up CI `42117298358` at `5ce6b6b`, Windows job
  `127560231894`, passed the prior 85 native test instances with no `warning:`
  line, then passed the Windows Flutter build and Host/license smoke. Its
  Linux/Android verify and macOS jobs also passed. This closes only the warning
  follow-up for ADR-021; it predates ADR-022.

### 2026-11-06 — Windows current-user Host state ACLs

- Reviewed Microsoft Win32 security-descriptor/DACL APIs plus current OpenAI
  Codex, mise, turborepo, and Vercel agent-desktop implementations at pinned
  commits. ADR-021 chooses a protected full-access ACE for the current process
  user's SID rather than ambient cache/config inheritance, account names,
  localized `icacls`, or a broad service/admin principal set.
- Added one Windows-only ACL boundary with owned token/descriptor lifetimes.
  Output-spool and Remote device-store directories receive the descriptor at
  creation and are tightened when already present; an existing Host-owned spool
  tree is recursively migrated, new spool files are protected before use,
  device-store replacements are created protected before any hash is written,
  existing device stores are tightened before read, and reparse or hard-linked
  file objects fail closed. Unix `0700`/`0600` behavior is unchanged.
- Added native Windows regression tests that begin under an Everyone-readable
  parent and require new/migrated directories and files to retain only the exact
  current-user SID, with protected/inheritable directory rules. The Windows CI
  job now runs the Rust suite before building Flutter. Local format, Clippy, all
  84 Linux Rust tests, and native-license checks pass.
- Preserve hosted CI `42112667012`, Windows job `127543995980`, as negative
  evidence: the first Windows compilation stopped before the ACL tests because
  `auth.rs` is part of the library crate while the Windows ACL module had only
  been declared by the binary crate. The follow-up declares the same private
  module in `lib.rs`; the later hosted results below close that compilation
  gap while preserving this first failure as evidence.
- Preserve follow-up CI `42113511534`, Windows job `127547477153`, separately:
  all Remote auth tests and the hard-link rejection passed, while the two DACL
  shape tests rejected the valid canonical SDDL `D:PAI(A;OICI;FA;;;LA)` because
  Windows rendered the runner's current-user SID as its well-known `LA` alias.
  The corrected tests compare the binary ACE SID with `EqualSid` and inspect the
  protected flag, ACE count/type/mask, and inheritance bits directly.
- Final hosted CI `42114960020` at `88d0270`, Windows Server 2022 job
  `127552522560`, passed 85 native test instances with the three ACL cases in
  both library and binary crate contexts, then built the Flutter Windows debug
  bundle and passed packaged Host `0.1.0` help plus native-license hash checks.
  The run's Linux/Android verify and macOS Host bundle jobs also passed. The
  Windows-only unused test-helper parameter warning observed in that successful
  run is removed in the evidence follow-up; this does not broaden the result to
  operator TLS keys, installed-service identities, installers, or Human review.

### 2026-11-06 — Fail-closed desktop review-artifact assembly

- Reviewed Flutter's complete desktop-bundle deployment requirements, GitHub
  artifact permission loss/attestation/immutable-release boundaries, OpenAI
  Codex's staged protected release workflow, TuxCodex's multi-distribution
  installer smokes, and codex-remote-android's simpler prerelease contract.
  ADR-020 separates useful release-mode review artifacts from any claim of
  production signing, installation, publisher identity, or release authority.
- Added one cross-platform assembler/verifier for the currently hosted desktop
  targets. It validates the supplied Git revision and clean/dirty state, refuses
  existing outputs and unsafe/escaping paths, requires the platform's release
  AOT/runtime files, exact application/native notices, bundled Host and a
  ten-second-bounded Host help smoke, and rejects any debug kernel blob.
- Each tar archive preserves Unix modes, case, and macOS symlinks that GitHub's
  ordinary directory upload would normalize. It contains a sorted per-file
  SHA-256/size/mode-or-link manifest, canonical sums, the full Flutter payload,
  and an explicit review warning. The sidecar binds the archive digest/size,
  manifest digest, app version/build, source, target, exact toolchains, build
  origin, and platform signing gap. Verification safely lists, extracts,
  reinventories, and rechecks inner/outer metadata and release layout.
- Added a manual-only, `contents: read`, immutable-action-pinned workflow for
  Linux x64, Windows x64, and macOS arm64. It uploads the archive, checksum, and
  provenance for 14 days but never creates a tag or Release, requests OIDC or
  attestation/write permission, provisions signing, or builds an Android
  release. Android remains behind its external upload-key contract.
- Three focused tests and the full 171-test Flutter suite pass, as do strict
  Dart analysis, formatting, and pinned actionlint 1.7.12. The focused cases
  cover complete Linux assembly plus independent verify,
  post-provenance archive tamper rejection, and missing-AOT fail-closed cleanup.
  A real local release build produced and reverified a 13,250,342-byte archive
  (`sha256:2ce56b20e1ae712c8c2fb05ce2f747c0ea76c7f4f705e75e47b44296fde7b8d4`)
  with exact notices and executable modes. Its provenance correctly says
  `treeState: dirty`, so it is local implementation evidence, not a clean-commit
  or hosted artifact. Direct-path `flutter analyze` again failed in Flutter
  3.47.1's Unicode-path LSP reader with truncated JSON; an independent ASCII
  repository copy passed Flutter analysis with no issues. Hosted three-platform
  workflow execution was still pending at that implementation point; the
  subsequent hosted runs and final pass are recorded below.
- The first manual hosted run `42091064595` reached release builds on Linux and
  macOS but exposed a pre-build Windows source-contract failure: checkout had
  converted the committed generated native notice to CRLF because the repository
  declared no EOL attribute. The strict validator correctly rejected that
  noncanonical release input. The notice is now explicitly `text eol=lf` in
  `.gitattributes`; the failed run was cancelled after diagnosis and does not
  count as Windows artifact evidence. A full replacement run remains required.
- Replacement run `42091784712` at `76bf94c` proved the EOL fix on Windows and
  produced a complete Linux artifact, but correctly failed overall. Windows
  reached assembly and reported that the post-build worktree was dirty; the
  original diagnostic omitted the changed paths. macOS reached assembly and
  showed that the hosted Flutter release bundle gives
  `Contents/Frameworks/App.framework/App` no execute bit. The latter is an AOT
  framework binary, not a launch target, so the validator now requires execute
  permission only on the app runner and bundled Host while retaining existence,
  non-empty, digest, inventory, and archive-mode checks for both frameworks.
  Repository-state mismatch errors now include a bounded porcelain status so a
  corrective hosted run can identify the exact Windows drift without weakening
  the clean-source provenance gate. A fourth focused test covers both accepted
  non-executable framework files and rejected non-executable app launchers.
- Corrective run `42093902515` at `43a256f` proved the macOS permission fix:
  Linux x64 and macOS arm64 both completed release build, assembly, self-verify,
  independent verify, and upload. Windows again failed closed at assembly, and
  the new bounded diagnostic identified exactly all seven tracked Flutter
  desktop plugin registrants across Linux, macOS, and Windows. Flutter refreshes
  them together with host-native line endings during a Windows build. Their
  exact generated-source patterns are now pinned to LF in `.gitattributes`
  rather than weakening source identity or globally rewriting unrelated files.
  Run `42093902515` remains failed and does not count as a three-platform pass;
  a fourth hosted run must prove the targeted EOL contract. Its companion normal
  CI run `42093880114` passed all three jobs, including the full Ubuntu source,
  Rust, Flutter, Linux, and Android gates plus native Windows/macOS debug bundles.
- Fourth run `42095949000` at `e71e5ac` closed the hosted artifact gate without
  relaxing source identity. Linux x64, Windows x64, and macOS arm64 each passed
  release build, clean-tree check, assembly/self-verification, a separate
  verifier invocation, and upload. All three downloaded outputs were then
  independently reverified from their artifact directories. Their sidecar
  checksums also matched the archive bytes: Linux 13,388,830 bytes at
  `8d0228a93b2704f3b7be0f318770ef51e31858c98156b0fd2919cc5cf837ccad`,
  Windows 14,675,442 bytes at
  `457c56340960901907ec0c406b19fe87431dd5a0ce4cfc09a6d2b038b84f2949`,
  and macOS 21,631,021 bytes at
  `4fd8345c3b100381f902e2d3164960c9bd03f9f73e00485d585a5442d3efd098`.
  Each provenance sidecar records the exact clean revision, Flutter 3.47.1,
  Rust 1.89.0, GitHub Actions origin, `reviewOnly: true`, and
  `distributionReady: false`. The macOS archive retained nine safe framework
  symlinks and executable app/Host launchers while correctly permitting the
  non-executable AOT framework binary. Companion normal CI run `42095935941`
  also passed its Ubuntu verification/Linux and Android debug build plus native
  Windows x64 and macOS arm64 debug-build jobs. Native installation, Linux
  dependency compatibility, Windows installer/ACL/SmartScreen, macOS Developer
  ID/notarization/Gatekeeper, and Human review remain separate unrun gates.

### 2026-11-06 — Relocatable Linux runtime and extracted-archive gate

- Direct ELF inspection preserved a defect hidden by the prior successful
  runner-level smoke: `codex_native_unofficial` correctly resolved its engine and
  plugins from `$ORIGIN/lib`, but both linked plugin files retained an absolute
  `linux/flutter/ephemeral` RUNPATH. Re-running the new native verifier against
  the downloaded Linux artifact from `42095949000` fails closed on its exact
  `/home/runner/work/...` build path. The prior checksum, structure, and source-
  provenance evidence remains valid, but it is not relocated-runtime evidence.
- Flutter's Linux CMake integration copies plugin targets as files, bypassing a
  target install-time RPATH rewrite. Those generated plugin targets now build
  with their final `$ORIGIN` install RPATH. A fresh release build gives both
  plugins exactly `$ORIGIN`, and an unrelated temporary copy resolves the
  Flutter engine from that copy's `lib/` even when launched from `/` with loader
  overrides removed.
- Added a reusable Linux runtime gate for ELF64 x86-64 runner/Host identity,
  exact runner `$ORIGIN/lib`, missing dependency detection, exact bundled-library
  resolution, and rejection of non-relocatable paths on the runner's bundled
  closure. The real release bundle passed with three bundled runtime libraries
  and 83 system-library names. That count describes the resolved local host
  closure, not a cross-distribution package manifest. The same gate passes the
  debug bundle and now runs in ordinary push CI after every Linux debug build;
  the stronger extracted release check remains in the manual artifact workflow.
- Matching-host archive verification now runs the extracted Host, with the Linux
  dependency gate applied to the extracted payload. The focused artifact suite
  covers a successful extracted runtime plus build-tree RUNPATH and unresolved-
  dependency rejection. A locally assembled dirty-source archive passed the new
  verifier at
  `68b706e82834800da336dadc652e1ec458af41329de87cb6bd6a492c553716bd`.
  The full Flutter suite passes 175/175, fatal-info Dart analysis passes, an
  independent ASCII-path copy passes `flutter analyze`, the Linux release build
  and real runtime gate pass, all 84 Rust tests plus formatting/Clippy pass, and
  actionlint 1.7.12 accepts both workflows. Direct-path `flutter analyze` still
  reproduces Flutter 3.47.1's known Unicode-path LSP truncated-JSON failure; the
  later ASCII pass does not erase that toolchain result.
  Hosted review run `42100825202` at clean revision `c1803d4` then passed Linux
  x64, Windows x64, and macOS arm64 release build, assembly/self-verification,
  extracted native-runtime verification, and upload. Downloaded copies all pass
  independent structural verification and exact sidecar checksum comparison;
  Linux also passes the native runtime gate after download. Its two linked
  plugin RUNPATHs are exactly `$ORIGIN`, and no `.so` dynamic section retains
  `/home/runner` or `linux/flutter/ephemeral`. The inner archives are Linux
  13,388,731 bytes at
  `18e215546c46bf2fa6ea7ae03e8337d7ec986aacb7192e33257ac31de28e6835`,
  Windows 14,675,440 bytes at
  `aff93b6e1f9e93aeded91c55f1c0ad42a51a08929fdfb229365435f17fc1b639`,
  and macOS 21,630,993 bytes at
  `8c62800837c8d50692453bdf6f53e13a764efcc357335a0744215f4c685245e2`.
  Companion CI `42100804703` passed all three jobs, including the ordinary Linux
  debug runtime gate, Linux/Android builds, and native Windows/macOS builds.
  Broader Linux distribution compatibility, installers/ACLs,
  signing/notarization, and Human use remain distinct.
- The review workflow now has a dependent Linux clean-runtime job using a pinned
  Ubuntu 22.04 image and only declared runtime/headless-display packages. It
  downloads the just-built Linux artifact, rechecks its checksum, extracts it,
  rejects missing runner/Host dependencies, runs the Host, and requires the GUI
  to remain alive for an eight-second Xvfb/DBus smoke with no surviving product
  process. First hosted review run `42105201413` at `b9cce27` passed all three
  artifact jobs plus the clean image's download, checksum, extraction, dynamic-
  dependency, and Host checks, but the GUI aborted with status 134 because
  `libGLESv2.so.2` was absent. The accompanying AT-SPI/Atk diagnostics preceded
  the fatal loader error and are not treated as the cause. Ubuntu's Jammy package
  index identifies `libgles2` as the GLESv2 runtime provider, so that package is
  now declared. Corrected hosted review run `42107031642` at `3ab0997` passed all
  three platform artifact jobs and clean-runtime job `127528095435`; its log
  records the exact archive checksum pass, Host `0.1.0` execution, the full
  eight-second GUI window, clean process teardown, and
  `LINUX_CLEAN_RUNTIME=PASS`. Companion CI `42107012629` passed the full verify,
  Windows x64, and macOS arm64 jobs. The first failure remains evidence, and the
  result proves only the pinned Ubuntu 22.04 runtime image without broadening the
  review-only boundary.
- Documentation-evidence commit CI `42108470797` preserved an external failure:
  attempt 1 reached Android NDK r28c download, then `sdkmanager` rejected the
  fetched archive as non-ZIP. The same failed verify job reran without source
  changes and attempt 2 passed the complete verify path including the Android
  debug APK; both native desktop jobs had already passed. This is hosted download
  instability, not evidence that the first failed attempt was green.

### 2026-11-06 — Compact desktop shell overflow recovery

- Preserved the original 320x1000 probe failures before changing layout: the
  runtime action row overflowed right by 11 pixels and the fixed desktop split
  overflowed right by 104 pixels. The first stacked revision exposed a 23-pixel
  thread-header right overflow and 64-pixel thread-panel bottom overflow; the
  adjacent 320x720 probe then exposed 93-pixel thread and 83-pixel conversation
  bottom overflows. Later passes do not erase those observed failures.
- Runtime, thread, and paired-device summary action rows now wrap at their
  natural widths. At 760 logical pixels and above the existing 360-pixel thread
  pane plus conversation split remains unchanged. Below that boundary the two
  bounded panels use a vertically scrollable workspace with an always-visible
  draggable scrollbar, a 320-pixel thread panel, and a conversation panel at
  least 420 pixels high rather than compressing either panel below its controls.
- One widget regression exercises the whole connected shell and Remote setup
  dialog at 320x720, asserts the compact/scrollable branch and no rendering
  exception, and the existing 1500x1000 path asserts the wide split remains.
  The full suite passes 168/168, fatal-info Dart analysis passes, independent
  ASCII-path Flutter analysis passes, and the Linux debug build succeeds.
- This is deterministic layout evidence, not Human visual or input acceptance.
  Real window resizing, nested-scroll feel, keyboard navigation, text scaling,
  and platform rendering remain Human/cross-platform review gates. Hosted run
  `42087567359` at `879c26d` passed Ubuntu verification plus Android debug,
  Windows x64, and macOS arm64 build/package gates.

### 2026-11-06 — Bounded Android Remote pairing QR intake

- Reviewed Android's camera permission/optional-feature guidance, Flutter
  lifecycle behavior, `mobile_scanner` 7.5.0 source and lifecycle fixes, ML Kit
  bundled/unbundled behavior, terms/privacy disclosures, and two offline
  alternatives. Selected the mature scanner with the bundled model while
  recording its size/metrics tradeoff and the much younger ML-free alternative
  rather than treating “offline model” as “network-silent runtime.” ADR-019
  captures the durable boundary.
- Added an injectable Android-only Scan QR action and full-screen scanner. It
  requests 1280x720 QR-only input, returns no image to Dart, suppresses duplicate
  detections, disables auto-zoom, and serializes start/stop lifecycle ownership.
  Missing, whitespace-modified, oversized, malformed, and expired results remain
  on the scanner with redacted guidance; the first valid canonical invitation
  fills the obscured field exactly once and never starts pairing automatically.
- Camera permission is requested only after the affirmative Scan QR action.
  Denial, unsupported hardware, scanner failure, and cancellation retain the
  complete manual-paste route. Android declares `CAMERA` while camera-any, back
  camera, and autofocus remain optional so Play filtering does not exclude
  devices that can use manual pairing.
- Added dependency provenance and Google ML Kit terms/privacy behavior to
  `THIRD_PARTY_NOTICES.md`, packaged that file as an application asset, and added
  `verify_android_pairing_scanner.dart` plus a CI source gate. The resolved model
  is bundled and immediately available, but its graph includes Google data
  transport and documented performance/utilization metrics. Auto-zoom remains
  off to avoid its extra session/zoom/candidate-box metrics.
- Six new unit/widget tests cover exact current invitation bounds,
  invalid-then-valid and duplicate intake, lifecycle ordering, delayed-start
  disposal, permission-denied fallback, and scan-without-auto-submit. The full
  Flutter suite passes 167/167, fatal-info Dart analysis passes, and Flutter
  analysis passes from an independent ASCII repository copy. Direct-path Flutter
  analysis again fails in the SDK LSP reader on this Unicode path and is
  preserved as the known toolchain defect rather than a project analysis pass.
- Linux debug build and exact packaged notice comparison pass. Direct Gradle
  Android `assembleDebug` passes 215 tasks through a temporary ASCII Flutter SDK
  alias; the merged manifest contains the permission plus three optional
  features, and the APK contains the exact third-party notice asset. The
  universal debug APK is 214,274,417 bytes, 22,804,773 bytes above the prior
  measurement. Existing AGP/Kotlin and SDK XML warnings remain, with an added
  `mobile_scanner` legacy-DSL deprecation. The alias was removed and ignored
  `local.properties` restored.
- Physical permission prompts, Settings recovery, camera focus/rotation,
  camera-less/front-only devices, dense Version 40 recognition, system-root and
  pairing-bound end-to-end scans, process death, and Human acceptance remain
  unrun device gates. Hosted run `42084742395` at implementation commit
  `1299fb8` passed Ubuntu verification plus Android debug, Windows x64, and
  macOS arm64 build/package gates.

### 2026-11-06 — Bounded desktop Remote pairing QR presentation

- Reviewed the QR Code inventor's version, byte-capacity, error-correction, and
  four-module quiet-zone guidance plus the maintained pure-Dart `qr` 4.0.1
  package and BSD 3-Clause license. The existing protocol permits up to 24 KiB,
  while one standard symbol is bounded far below that, so QR availability is
  explicitly narrower than invitation validity.
- Added an offline projection of the exact validated ASCII
  `codex-native-pairing-v1` invitation using one Version 1-40 symbol at medium
  correction. The painter uses a white four-module quiet zone, integer three-
  pixel modules, and no antialiasing. It never splits, compresses, truncates, or
  invents a QR-only schema; an oversized or layout-constrained invitation keeps
  the full selectable/copyable manual path.
- The setup controller now owns ticket expiry. At the advertised deadline it
  cancels and clears the ticket, drops the in-memory QR with its widget subtree,
  and reports that a fresh ticket is required. Refresh, replacement, dialog
  disposal, and controller disposal also cancel the timer and clear transient
  material.
- Focused protocol/widget tests cover system-root and bounded-certificate
  symbols, malformed/noncanonical input, single-symbol overflow, explicit copy,
  no automatic creation, expiry removal, oversized fallback, and a Version 40/M
  symbol rejected by a safely constrained dialog. Eight focused tests pass. A
  proposed `RepaintBoundary.toImage()` pixel check hung indefinitely in the
  current Flutter test backend and was removed rather than presented as
  evidence; data, layout-state, and lifecycle tests pass, but physical scanning
  and Human visual acceptance remain unperformed.
- A separate 320-logical-pixel whole-shell probe could not isolate QR behavior:
  it exposed existing desktop split-pane, runtime-header, and setup-summary row
  overflows before ticket creation. The valid 620-pixel constrained-symbol test
  passed without an exception. This negative evidence remained attributable to
  this QR slice; the later compact-shell recovery recorded above fixes and
  independently verifies those overflows.
- Added the direct dependency provenance to `THIRD_PARTY_NOTICES.md`. Android
  camera selection/permission/lifecycle and bounded decoder intake were kept
  outside this slice and later completed with their own dependency/license
  review.
- Final local gates pass: zero-change Dart formatting, fatal-info Dart analysis,
  Flutter analysis through the established ASCII project alias, all 161 Flutter
  tests, Linux debug bundle, native-license drift/packaging, Android release-
  signing source contract, and Android `assembleDebug` (185 tasks; 191,469,644-
  byte APK). Two direct Flutter CLI Android attempts failed before project
  compilation because Flutter rewrote the SDK property to this machine's
  Unicode path and Gradle decoded it as mojibake. Direct Gradle assembly with a
  temporary ASCII SDK alias passed; the local property and alias were restored
  and neither environment path is committed.
- Hosted GitHub Actions run `42076435647` at implementation commit `36b7102`
  passed all three jobs. Ubuntu re-ran exact Rust 1.89 format/Clippy/84 tests,
  license and release-signing source gates, Flutter analysis/161 tests, Linux
  bundle verification, and Android debug assembly/artifact checks. Windows x64
  and macOS arm64 each built the Flutter bundle, executed the packaged Host, and
  verified the packaged native-license notice.

### 2026-11-06 — Hosted cross-platform failure-driven corrections

- Published the previously local history and inspected current-tree GitHub
  Actions run `42063855051` at `a77e6ac`. Windows Server 2022 x64 passed the
  Flutter debug build, bundled Host/license assertions, and packaged Host
  `--help`. This is real native build evidence, but not installation, ACL,
  signing, or Human-use evidence.
- Preserved both failures from the same run. Exact Rust 1.89 Clippy rejected an
  explicit `drop` used only to end a closure borrow, while the newer local Rust
  1.99 compiler had accepted it. A lexical scope now ends the borrow naturally;
  a fresh isolated official Rust 1.89.0 toolchain passes strict Clippy and all
  84 tests, and the current toolchain still passes format, Clippy, and tests.
- macOS 15 arm64 reached Flutter's Xcode build but its system Bash 3.2 rejected
  an empty `release_argument` array under `set -u`. The build and nested-signing
  command arrays are now always non-empty. Shell parsing and local Debug/Release
  packaging simulations both pass, including executable Host and license
  placement; only a hosted macOS rerun can close the native failure.
- The run also warned that the old checkout action targeted Node 20 and was
  being forced onto Node 24. Official `actions/checkout` v7.0.1 itself targets
  Node 24, so both jobs now pin its reviewed immutable commit
  `3d3c42e5aac5ba805825da76410c181273ba90b1` while preserving
  `persist-credentials: false`. Pinned actionlint 1.7.12 and independent YAML
  parsing pass after the update.
- Follow-up run `42066453043` proved the first two corrections: macOS 15 arm64
  and Windows Server 2022 x64 both built their Flutter bundles, executed the
  packaged Host, and verified its license. Ubuntu also passed exact Rust 1.89
  Clippy/tests, Dart/Flutter analysis/tests, and the Linux bundle/license gate.
  Its Android step then failed before compilation because the hosted default was
  JVM 11 while Gradle 9.3.1 requires JVM 17 or later. CI now pins official
  `actions/setup-java` v6.2.0 at immutable commit
  `77dd5b2ce225ea11469928ac317850245a74ae78`, selects Temurin 17, and does not
  enable dependency caching. With an exact local OpenJDK 17.0.20.1 runtime and
  only the established temporary ASCII Flutter-SDK alias, `assembleDebug`
  passed all 185 tasks and produced a 191,469,644-byte APK. Known upstream
  Kotlin/AGP and SDK XML warnings remain preserved. The hosted correction still
  required a rerun.
- Final run `42068745322` at `e11a36c` passed the entire matrix. The Ubuntu job
  successfully selected Temurin 17, ran all exact-Rust/Dart/Flutter and source
  contract gates, built/verified the Linux bundle, built the Android debug APK,
  and asserted the APK was non-empty. Windows x64 and macOS arm64 again built
  their Flutter bundles, verified the Host/license locations, and executed the
  packaged Host's `--help`.

### 2026-11-06 — Fail-closed Android release identity

- Reviewed Flutter's current Kotlin DSL release-signing flow and Android's
  official debug/upload/app-signing identity guidance. The existing template
  still assigned `signingConfigs.debug` to the release variant, so every prior
  minified "release" APK proved compilation but carried an insecure development
  identity and could not support an honest RC claim.
- Added a private `android/key.properties` contract with a placeholder-only
  tracked example. Gradle requires all four non-empty fields and a readable
  external keystore, creates the release signing config only when that contract
  is complete, and otherwise stops `preReleaseBuild` with redacted diagnostics.
  Debug builds and IDE configuration remain available without release secrets.
  A CI-owned source validator rejects debug-signing fallback, missing fail-closed
  markers, incomplete ignore rules, or a non-placeholder example without ever
  opening a developer's ignored private properties. Its first run exposed an
  invalid instance `File.isFileSync` call; switching to the correct static
  `FileSystemEntity.isFileSync` API made the validator and fatal-info analysis
  pass rather than hiding the implementation failure.
- The no-key failure path rejected `assembleRelease` with the intended bounded
  error, while `assembleDebug` still passed 185 actionable tasks. A temporary
  local 30-day RSA keystore then built both release APK and AAB; `apksigner`
  verified the 54,019,334-byte APK and exact certificate digest, and `jarsigner`
  verified the 52,739,360-byte AAB. The temporary private key, ignored property
  file, ASCII SDK alias, and test-signed outputs were explicitly removed.
- No production upload key, Play Console app, Play App Signing enrollment,
  key-custody/backup policy, CI secret, publication permission, store upload, or
  device installation was created. Those remain Human/release authority gates.

### 2026-11-06 — Hosted CI hardening and cross-platform build gates

- Reviewed GitHub's immutable-action guidance and current hosted-image catalog,
  Flutter's supported-platform and continuous-delivery guidance, the Linux
  secure-storage compiler requirements, and Cargo's `rust-version` semantics.
  Replaced drifting runner/action references with explicit supported images and
  reviewed full action SHAs; checkout no longer persists credentials and the
  Flutter action's optional floating cache steps are explicitly disabled.
- Proved that the former Rust 1.87 floor was false rather than assuming the
  developer's Rust 1.99 build represented compatibility. An isolated official
  Rust 1.87.0 toolchain rejected the locked `uuid` 1.29.0 before compilation
  because it requires rustc 1.89.0. From empty Cargo/target state, official Rust
  1.89.0 compiled the same locked workspace and passed all 84 tests. The
  temporary toolchain/cache tree was validated and removed afterward.
- Raised the truthful Host floor to 1.89 and advanced the obsolete compatibility
  pins from `sha2` 0.11.0/`rcgen` 0.14.5 to 0.11.1/0.14.10, which both declare
  Rust 1.88. The locked native notice was regenerated for the shipping `sha2`
  change and still passes deterministic drift and packaging validation.
- The first final strict-Clippy run under the developer's Rust 1.99 exposed a
  newly enforced collapsible nested `if` in the Remote shutdown error path. A
  minimal let-chain preserves the required `stop()` call and first-error
  ownership. Strict Clippy/current-toolchain tests and a second clean exact-1.89
  build of the final source all pass; the failure is not hidden by the older CI
  compiler.
- The Ubuntu 22.04 job now installs `libsecret-1-dev`, selects exact Rust 1.89,
  runs the full source/license/test gates, then builds Linux and Android. A
  fail-independent Windows Server 2022 x64/macOS 15 arm64 matrix builds each
  desktop app, runs the packaged Host's `--help`, and compares the bundled
  native-license notice at the real platform location. Superseded workflow runs
  are cancelled; monthly Dependabot review covers GitHub Actions only.
- Pinned `actionlint` 1.7.12 and independent YAML parsing passed locally before
  publication. The later first current-tree run and its failure-driven
  corrections are recorded in the newer section above; signing/notarization,
  native installation/ACL inspection, and Human acceptance remain separate.

### 2026-11-05 — Lockfile-derived native license packaging

- Reviewed current `cargo-about` 0.9.3/Cargo locked-metadata behavior and
  Mozilla's official MPL-2.0 executable-distribution guidance before selecting a
  generation policy. The first fail-closed run exposed a real omission: the
  runtime graph contains MPL-2.0 `option-ext` 0.2.0 through `dirs`. Review also
  found the prior direct list omitted `axum-server`; neither result was hidden by
  an ignore rule.
- Added an explicit accepted-license/desktop-target policy, maintained rustls
  clarification, repository-owned plain-text template, and pinned generator
  wrapper. It evaluates normal, transitive, build, and unioned Linux/Windows/
  macOS platform dependencies with `--locked --workspace --fail`, excludes only
  unshipped development dependencies, and checks the committed 257,985-byte
  result byte-for-byte. The output contains crate versions, upstream source
  locations, SPDX choices, and complete license texts without local paths or
  HTML-escaped prose.
- Preserved a second generation failure from final staging: several upstream
  license files carried CRLF or trailing horizontal whitespace, so the initial
  aggregate failed `git diff --check`. The wrapper now deterministically
  normalizes only line endings, line-end whitespace, and final newlines; the
  validator rejects non-canonical output and the complete prose remains intact.
- Replaced the drifting hand-maintained Rust list with the generated artifact as
  release authority. The `option-ext` entry includes its source URL and complete
  MPL-2.0 text; source and release documentation preserve that specific
  executable-form notice obligation without mislabeling the whole larger work.
- Linux and Windows CMake now install the notice beside `codex-native-host`;
  macOS's Host build phase installs it under `Contents/Resources` and declares
  the Xcode output. A static release-contract validator covers all three sources,
  CI installs the exact generator/checks drift, and CI compares the Linux
  installed copy byte-for-byte.
- A real Linux debug bundle contains the mode-0644, byte-identical 257,985-byte
  notice beside the mode-0755 Host. Later hosted Windows evidence verifies the
  corresponding built bundle, and the corrected hosted macOS build verifies its
  `Contents/Resources` copy. No signing, notarization, native installation, or
  Human-use claim is inferred from either build.

### 2026-11-05 — Phase 4 versioned pairing invitation and local certificate trust

- Re-reviewed the installed Dart 3.13.1 TLS source and current official Dart
  APIs, rustls strict one-root parsing, Syncthing certificate identity, and the
  pinned `codex-remote`/`codex-remote-android` pairing flows. Corrected the prior
  over-broad root-store statement: Linux/Windows use Dart's Mozilla roots while
  macOS/iOS/Android use the platforms' built-in stores. Research changed the
  design by keeping client trust as an explicit independent operator value
  rather than guessing a certificate from the Host chain or listener.
- Added `CODEX_NATIVE_REMOTE_PAIRING_TRUST_CERT`/
  `--remote-pairing-trust-cert`. It requires a listener plus explicit advertised
  endpoint and accepts exactly one bounded DER or PEM certificate. rustls
  validates it before bind/stock-Codex startup; malformed, multiple, oversized,
  or missing-endpoint configurations fail closed without exposing certificate
  bytes. The trust snapshot is separate from server TLS so a reverse proxy can
  own the client-visible identity.
- Replaced desktop endpoint/ticket output and Android's separate input fields
  with one exact-key, size-bounded `codex-native-pairing-v1` envelope binding
  endpoint, single-use code, expiry, and either system roots or certificate DER
  plus verified SHA-256. Desktop still creates nothing on dialog open, retains
  the invitation only for that dialog, and writes it to the clipboard only after
  an explicit action with a short-lived-secret warning. Manual transfer is
  usable; QR rendering/scanning is not implemented.
- Added credential-record version 2 under the existing secure-storage key.
  Version-1 system records remain readable and upgrade only on a later verified
  save. Certificate mode creates an empty per-connection `SecurityContext` and
  uses only the invitation certificate for both same-origin HTTPS pairing and
  WSS; system mode retains default roots. No global trust mutation,
  `badCertificateCallback`, TOFU after ticket disclosure, or silent trust
  migration exists. Stable private CA trust supports leaf rotation; exact
  self-signed-leaf changes require restart and re-pairing.
- Preserved two directly coupled negative results. The first release smoke
  showed Dart/Linux rejecting the canonical raw DER leaf even though rustls had
  accepted it as a root; official API semantics require PEM generally and DER
  specifically on iOS, so the stored canonical DER is converted per platform.
  A later clipboard widget assertion initially observed no snackbar because the
  test had not installed/awaited the platform channel; a controlled mock now
  proves exactly one explicit `Clipboard.setData` call and the warning.
- The corrected release Host plus stock app-server passed in 10.701 seconds with
  a generated self-signed identity: ordinary system trust rejected both HTTPS
  pairing and WSS, the exact invitation-bound context then paired and connected,
  eight models and metadata-only history loaded, live revocation closed the
  socket, temporary state was removed, and Host exit was zero. This is
  same-Linux-host evidence, not Android TLS-provider, Keystore, LAN, lifecycle,
  QR, or Human evidence.
- All 156 Flutter tests and 84 Rust tests, fatal-info analysis, formatting,
  strict Clippy, Rust release, Linux debug, and Android debug builds pass. The
  Android build used only the reversible ASCII Flutter-SDK property workaround,
  restored `local.properties`, removed the temporary link, and produced the
  unchanged 191,469,644-byte APK. Device inventory still contains only Linux.

### 2026-11-05 — Phase 4 trusted desktop Remote setup and device management

- Added an optional `CODEX_NATIVE_REMOTE_ADVERTISE_ENDPOINT`/
  `--remote-advertise-endpoint` Host setting. It requires an enabled listener
  and an exact WSS `/v1/ws` URI, rejecting user info, query, fragment, zero port,
  and unspecified `0.0.0.0`/`[::]` destinations. The value is separate from the
  actual bind address so reverse proxies and wildcard binds remain truthful; the
  Host never guesses a client address.
- Extended trusted-local status and pairing-ticket responses with that exact
  endpoint. A release Host plus stock app-server reported a real ephemeral
  loopback bind and the independently configured endpoint, then exited zero on
  EOF. This is configuration propagation evidence, not DNS/firewall/certificate
  or Android reachability proof.
- Added strict typed desktop administration models/protocol and a separate
  `RemoteAdminGateway`. Only a connected `ProcessTransport` implements it;
  `CodexTransport` and Android `RemoteTransport` do not. Exact response shapes,
  WSS endpoint grammar, ticket/ID alphabets, Unicode device-name bounds, four
  known scopes, timestamps, unique IDs, and the 32-row device cap fail closed.
  Object strings and product errors redact endpoint, ticket, and device IDs and
  reject any unexpected bearer field.
- Added the desktop setup dialog. Opening it reads Host/device state but never
  creates a ticket or enables networking. An affirmative action creates one
  transient five-minute ticket only when an advertised endpoint is present;
  its endpoint must match current status and its expiry must be future. Closing
  the dialog drops it. Missing configuration explains the exact environment
  setting instead of deriving a value from the wildcard bind.
- Added bounded device metadata and affirmative revocation. The UI never shows
  a bearer or device ID and always reads the authoritative list after the Host
  action. Adjacent review found the existing total-record limit meant revoked
  devices did not actually release a slot. The registry now limits active
  credentials and atomically prunes revoked/expired records only with the next
  successful pairing, preserving immediate revocation readback without
  unbounded storage.
- Added six protocol, six controller, three widget, one ProcessTransport, and
  three Rust regression cases. The initial no-port WSS process test exposed that
  Dart does not provide a default `Uri.port` for `wss`; validation now reads the
  port only when explicitly present. All 151 Flutter tests and 78 Rust tests,
  fatal-info analysis, formatting, strict Clippy, Rust release, Linux debug, and
  Android debug builds pass. The Android build again used only the reversible
  ASCII Flutter-SDK property workaround and produced the unchanged
  191,469,644-byte APK. No emulator/physical Android device or Human visual
  acceptance was available.

### 2026-11-05 — Phase 4 bounded Android pairing and recovery onboarding

- Added a strict pairing client for the Host's exact `/v1/pair` contract. Input
  accepts only an exact WSS `/v1/ws` endpoint, the Host's 24-character URL-safe
  ticket, and a trimmed control-free 1–80-character device name. It derives one
  same-origin HTTPS route, does not follow redirects, disables response
  decompression, and caps request and response bodies at 8 KiB with five-second
  connection and 15-second whole-request deadlines.
- Successful responses require HTTP 200 JSON, protocol version 1, exact device
  fields, the 22-character device ID, `read` plus `device_rotate` scopes, valid
  issue/expiry ordering, and the 43-character bearer. Ticket rejection, device
  limit, rate limit, incompatible route, Host failure, TLS rejection, network
  failure, timeout, and malformed/oversized data remain distinct but redacted.
  Neither request/response diagnostics nor object strings expose the endpoint,
  ticket, bearer, device identity, or server error body.
- Added a pairing/recovery coordinator over the existing verified credential and
  applied-cursor stores. A bearer is never used until its complete versioned
  record has been written and read back. The coordinator invalidates any older
  credential-load generation before starting Remote, saves an accepted pairing
  while hidden without connecting, waits for that save during shutdown, refuses
  to overwrite recovery-required state, and never auto-retries a single-use
  ticket. A post-acceptance secure-save failure explicitly warns that the local
  Host may need to revoke the orphaned device entry.
- Recovery for unreadable or revoked state now requires an affirmative dialog.
  It stops Remote, deletes and verifies the non-secret cursor before deleting and
  verifying the credential, then reloads persisted state. A failed clear restarts
  state discovery when visible instead of leaving the product on a stopped
  screen. No clear action claims Host-side revocation.
- Added phone-sized unpaired and recovery surfaces with no bearer entry/display,
  no insecure-certificate option, and no accidental conversation/write controls.
  The default Android stack shares one secure-storage adapter across credential,
  cursor, lifecycle, and onboarding owners; desktop process behavior is
  unchanged.
- Targeted review of `codex-remote` at `fcdf784` confirmed the value of transient
  one-use-code UI state and generation-scoped callbacks, while also showing
  failure boundaries this project does not adopt: HTTP onboarding, version
  fallback, unbounded response-string parsing, asynchronous unverified
  preference writes, and treating decrypt failure as absence.
  `codex-remote-android` at `372581a` confirms that unknown/changed Host identity
  should block before credentials are sent; its SSH fingerprint confirmation is
  reference evidence for the future pairing-bound local-certificate flow, not an
  architecture to copy.
- Preserved three directly coupled negative results. The first URI test exposed
  that explicitly replacing empty query/fragment generated a trailing `?#`;
  pairing now changes only scheme/path and proves the exact route. Concurrency
  review found a foreground absent-credential load could outlive a pairing save,
  so the prior lifecycle generation is now stopped before the verified record is
  activated. The same review found a failed clear could strand the runtime in
  `stopped`; visible state discovery now restarts after that failure.
- All 135 Flutter tests, `dart analyze --fatal-infos`, formatting, the Linux
  debug build, and Android `assembleDebug` pass. Android still requires the
  temporary ASCII Flutter-SDK property workaround and produces the unchanged
  191,469,644-byte three-ABI debug APK. The available device inventory contains
  only Linux; no Android emulator or physical device exists, so none of real
  HTTPS trust, Keystore write/readback, Activity lifecycle, keyboard/IME
  behavior, network switching, or Human interaction is proven here.

### 2026-11-05 — Phase 4 Android Remote runtime and read-only product state

- `RuntimeController` now selects the secure Remote stack by default on Android
  while leaving desktop Host/process startup unchanged. It constructs one
  platform secure-value adapter shared by credential and applied-cursor stores,
  then owns the tested lifecycle coordinator and bounded projection.
- Added explicit product states for unpaired, credential recovery, connecting,
  authoritative hydration, bounded retry, read-only ready, revoked, and
  suspended. Messages disclose no endpoint, bearer, close reason, or device
  identity. A negotiated socket never maps directly to the ready state.
- Wired Flutter's visibility lifecycle at `onHide`/`onShow`: hiding suspends and
  closes Remote while retaining only verified applied state; showing starts the
  coordinator again. Detach still performs full shutdown. Cold-process safety
  does not depend on these callbacks because a process can be killed without a
  lifecycle notification and cursor-only cold resume remains disabled.
- Added a bounded, virtualized read-only Android surface for up to 100 hydrated
  thread summaries plus model count/default model. It has explicit read-only
  labeling and contains no create, resume, composer, approval, history, output,
  or settings actions. Every existing gateway method still rejects locally in
  Remote mode rather than accidentally reaching the Host.
- Two integration tests cover state/redaction mapping, projection exposure,
  local write-surface rejection, read-only widget contents, and hide/show
  suspend/resume. The first hidden-state assertion expected a repaint, but
  Flutter intentionally stops scheduling visible frames while paused; the test
  now verifies controller suspension while hidden and the rendered state after
  showing again. The first 412×915 phone-size run then exposed a 100-pixel
  overflow in the longer Remote status label; constraining the label to the
  status row's remaining width fixed the directly coupled mobile defect.
- All 120 Flutter tests, `dart analyze --fatal-infos`, formatting, the Linux
  debug build, and Android `assembleDebug` pass. The Android build still uses the
  temporary ASCII Flutter-SDK property workaround and produces the restored
  191,469,644-byte three-ABI APK. No emulator/physical-device lifecycle,
  Keystore, WSS, network switching, or Human visual interaction was exercised.

### 2026-11-05 — Phase 4 Remote lifecycle and authoritative projection owner

- Added a `RemoteSession` seam and production connector around
  `RemoteTransport`. The transport now exposes exact session/sequence-bearing
  notifications plus a redacted terminal close classification. HTTP 401 maps to
  a typed credential rejection, and the Host's exact policy-close reason maps to
  terminal device revocation instead of an endless reconnect loop.
- Added a strict versioned applied-cursor store in the existing secure-storage
  namespace. A cursor is bound to the paired device ID and exact Host
  session/sequence, capped at 1 KiB, serialized, and verified by readback. It is
  deliberately separate from the bearer record and is never trusted on cold
  start without an in-memory projection representing the same session and
  sequence.
- Added a bounded authoritative Remote projection retaining at most 100 models
  and 100 thread rows. Snapshot replacement records opaque next cursors, while
  the allowlisted lifecycle events update only thread status and advance only an
  exact next sequence. A gap, wrong session, malformed thread ID/status, or
  unsupported event fails closed.
- Added `RemoteLifecycleCoordinator` states for credential loading, unpaired and
  credential-recovery gates, connecting, hydrating, ready, bounded retry,
  revoked, suspended, and stopped. A socket is not ready until its device/session
  status is verified and both bounded model/thread snapshots have replaced the
  projection. The baseline cursor is persisted after replacement; each live
  cursor is persisted only after its event mutation completes.
- Same-session resume is allowed only when the retained projection, secure
  cursor, device ID, Host session, and sequence all agree. A fresh process,
  changed Host session, gap, invalid cursor, or resync generation performs a new
  bounded snapshot. Generic connection failures back off from one second to a
  30-second cap; credential rejection and live revocation are terminal. Run and
  connection generations reject late connects and stale hydration, while a
  cross-connection projection queue prevents a suspended session's delayed work
  from overwriting a resumed run.
- Preserved three negative results. The first real 401 test showed Dart's
  `WebSocketException.message` omitted the HTTP status even though its bounded
  `toString()` included it; the mapper now matches only the exact status phrase.
  A suspend/late-connect test exposed duplicate close ownership; cleanup now
  belongs to one `finally`. A direct `flutter analyze` again crashed in the
  Unicode repository path, and an ASCII symlink still canonicalized back to that
  path; an isolated ASCII copy passed instead.
- Nineteen new tests bring the Flutter total to 118. `dart analyze
  --fatal-infos`, the ASCII-copy `flutter analyze --no-pub`, all Flutter tests,
  the Linux debug build, and Android `assembleDebug` pass. Android still needs
  the documented temporary ASCII Flutter-SDK property; the restored three-ABI
  APK remains 191,469,644 bytes. No emulator/physical-device, background OS,
  process-death, real LAN, or Android UI behavior was exercised.

### 2026-11-05 — Phase 4 recoverable Android credential owner

- Reviewed Android Keystore and Auto Backup guidance, the current
  `flutter_secure_storage` 11.2.0 implementation/changelog, its namespace and
  migration behavior, and open issue #1298 describing a transient Keystore
  lookup replacing the wrapping key. ADR-012 treats the device bearer as
  recoverable device-bound state rather than an infallible preference.
- Added a strict versioned Remote device record for one WSS endpoint, the exact
  43-character bearer, bounded device ID/name, and explicit `system` trust.
  Plaintext, URI-embedded credentials, unknown/future schema fields, control
  characters, and oversized records fail before persistence. Object strings and
  all public storage errors redact endpoint, bearer, and record data.
- Added a serialized credential owner with distinct absent, available, and
  unreadable/corrupt recovery results. It validates existing data before
  replacement, verifies every write by exact readback, never auto-deletes on a
  read/decrypt error, and exposes clear as a separate explicit recovery action.
  Only that action enables a namespace reset so a lost wrapping key cannot make
  recovery itself impossible.
- Added `flutter_secure_storage` 11.2.0 with a dedicated namespace,
  `resetOnError: false`, algorithm migration, and migration backup. The bearer
  is stored only through this adapter, not in ordinary preferences, routes, or
  diagnostics. Background operation deliberately does not require biometric
  authentication per access.
- Disabled Android application backup and added independent legacy and Android
  12+ rules excluding all SharedPreferences from cloud backup and device
  transfer. The merged debug/release manifests retain these rules and API 24
  minimum compatibility.
- Nine credential/recovery tests bring the Flutter total to 99. Full Dart
  analysis, all Flutter tests, and the Linux debug build pass. Android debug and
  minified release builds pass through the documented temporary Unicode SDK
  path workaround; the three-ABI artifacts are 191,469,644 and 51,791,110
  bytes. The secure-storage dependency inflates the JIT debug kernel, while the
  release artifact tree-shakes to a normal universal-APK range. That historical
  release APK used the Flutter template's debug signing fallback; it remains
  compilation/size evidence only and has been superseded by the fail-closed
  upload-key requirement.
- No emulator or physical device was available. Real Keystore encryption,
  transient service failure, uninstall/reinstall, OS backup/restore, device
  transfer, and system-CA network behavior remain unverified platform gates.

### 2026-11-05 — Phase 4 bounded Dart Remote transport core

- Added production Android `INTERNET` permission and a typed
  `RemoteTransport` over `dart:io` WebSocket. WSS is the default; plaintext is
  accepted only through an explicit opt-in with a literal loopback IP. Endpoint
  validation rejects user-info/query credential placement without echoing the
  URI, and bearer validation accepts only the Host's exact 43-character
  base64url credential shape.
- Implemented strict `codex-native-v1` subprotocol and three-message
  negotiation, required capability/version checks, same-session resume, exact
  sequenced event acceptance, ACK, a 64-request correlation cap, 1 MiB encoded
  message cap, request deadlines, and coordinated fail-closed shutdown. A late
  socket arriving after a connection deadline is explicitly closed rather than
  leaked.
- The real `dart:io` socket disables WebSocket compression, configures Dart
  3.13's 1 MiB inbound frame limit, and serializes outbound messages through
  `addStream` so OS write backpressure can pause the source. Its application
  write queue is independently capped at 64 messages and 2 MiB. Real loopback
  socket tests prove ordered writes and that an oversize frame is protocol-
  closed before a message reaches the transport.
- A new connection now requires bounded authoritative resync even when the Host
  has no replay suffix. Events are held behind that snapshot, not exposed to
  feature state, and a generation token prevents an older in-flight resync from
  clearing a newer invalidation. The client buffer mirrors the Host's 512-event
  and 8 MiB journal limits; exhaustion clears the incomplete suffix and forces
  a new generation.
- Reused the existing typed model/thread/turn adapters for the currently
  allowed `host/remote/status`, `model/list`, `thread/list`, and metadata-only
  `thread/read` surface. History/output reads, writes, turns, interruption, and
  approvals are rejected locally without putting an RPC on the socket. A
  synthetic initialize result is returned only after Remote status/session/mode
  validation; this transport foundation is not yet an Android ready state.
- The first fail-closed sequence-gap test stalled during close. The cause was
  closing the socket before cancelling the active `StreamIterator`; reversing
  that order removed the lifecycle wait and is retained as negative evidence.
  Eighteen focused tests now cover endpoint/credential boundaries, late-connect
  cleanup, subprotocol negotiation, resync gating/generation invalidation,
  exact replay/ACK, out-of-order RPC correlation, local write rejection,
  malformed/binary/gap input, abnormal peer close, explicit resync, timeout,
  concurrent close, and real-socket frame/write behavior. Dart's oversize-frame
  path closes the message stream with code 1002 instead of forwarding its
  internal exception; the transport now converts every abnormal peer close into
  a visible protocol error.
- Full `dart analyze` and all 90 Flutter tests pass. The production Android
  manifest contains `INTERNET`; `assembleDebug` again passed 87 Gradle tasks and
  produced the 145 MiB three-ABI debug APK after temporarily Unicode-escaping
  the ignored Flutter SDK property. Ordinary `flutter build apk` still fails
  before compilation on this Unicode path, and no emulator, physical Android,
  real LAN, background lifecycle, platform-CA, or UI claim is made.

### 2026-11-05 — Phase 4 fail-closed non-loopback WSS

- Reviewed `axum-server`/rustls certificate loading and atomic reload, Android
  network-security and pinning guidance, Dart `HttpClient`/`SecurityContext`
  injection, current secure-storage constraints, and maintained Remote clients.
  ADR-011 requires explicit certificate identity for non-loopback Remote and
  forbids arbitrary-certificate callbacks or plaintext downgrade.
- Added paired certificate/key environment and CLI configuration. Both must be
  present with an enabled listener; plaintext remains literal-loopback-only in
  both the parser and the server. TLS parses before bind and before Codex spawn,
  Unix private keys with group/other permissions fail, and errors/status never
  include PEM contents.
- Added rustls HTTPS/WSS through `axum-server` while retaining every existing
  HTTP body, WebSocket frame/message/write-buffer, connection, application queue,
  replay, heartbeat, and timeout bound. Local status now reports actual TLS and
  loopback/network scope instead of hard-coded values.
- Added trusted-local `host/remote/tls/reload`. A valid certificate/key pair is
  atomically adopted for new handshakes, existing WSS connections survive, old
  trust no longer connects, and an invalid reload returns a generic error while
  retaining the last valid configuration.
- The initial TLS WebSocket test observed an EOF because `axum-server`'s
  `http1_only()` path did not serve HTTP upgrades. Removing that override fixed
  the concrete lifecycle mismatch; the failure remains recorded in research.
- Rust tests now pass 25 Remote-library tests, 47 Host-binary tests, and three
  executable failure-path tests (75 total). A release Host plus stock app-server
  passed the complete read-only Remote smoke over WSS in 10.828 seconds with a
  Dart `SecurityContext`, network-scope wildcard bind, hash-only pairing, eight
  models, metadata-only thread read, live revocation, no internal-ID leak, and
  zero Host exit. The client connected through loopback on the same Linux host,
  so this is not real LAN, firewall, system-CA, service-install, or Android proof.
- The original dependency review held `rcgen` and `sha2` below their current
  patches to preserve an asserted Rust 1.87 floor. A later isolated 1.87 build
  disproved that floor because locked `uuid` 1.29.0 requires Rust 1.89. The
  manifest now truthfully requires 1.89, the obsolete pins have advanced, and an
  isolated official 1.89 build passes all 84 Rust tests.

### 2026-11-05 — Phase 4 bounded Codex event replay

- Reviewed the official generated notification envelope and current app-server
  definitions. The first Remote event allowlist is deliberately limited to
  `turn/started`, `turn/completed`, `item/started`, `item/completed`,
  `thread/status/changed`, and `error`. Token/output/reasoning deltas, full diff
  updates, unknown notifications, and every request-shaped object with a
  top-level `id` remain on the desktop path only.
- Extended the incremental output sanitizer to identify top-level method/ID
  shape without materializing app-server messages. Allowlisted notifications are
  still published to desktop first, then captured only after
  `aggregatedOutput` removal, with a 256 KiB Remote cap. A larger event becomes a
  small sequenced `host/resyncRequired` marker rather than a hidden drop or a
  large allocation.
- Connected the existing 512-event/8 MiB journal to a capacity-64 live broadcast
  and the per-connection count-and-byte queue. Sockets subscribe before
  negotiation, skip events represented by the handshake baseline, accept only
  the exact next sequence, and record it as sent for ACK validation. Receiver
  lag or a sequence gap emits `resync_required` and policy-closes; queue or
  socket-write exhaustion also disconnects the slow peer.
- TCP tests prove live delivery, ACK, exact retained replay, abrupt unacknowledged
  reconnect, eviction-to-resync without partial history, and slow-reader
  disconnection under an 18 MiB fanout. Transform/publisher tests cover
  sanitization, server-request and delta exclusion, oversized event markers, and
  non-advancing rejection of request-shaped captures.
- The Rust suite now passes 25 Remote-library tests, 43 Host-binary tests, and
  two executable failure-path tests (70 total), plus format and strict Clippy.
  The release Host build and the real stock app-server read-only smoke also pass;
  the smoke did not start a real turn and therefore does not establish live
  stock turn-event publication.

### 2026-11-05 — Phase 4 bounded read-only Codex bridge

- Generated and reviewed the installed stock app-server
  `0.166.0-alpha.5.1` schemas, then added a strict read-only allowlist for
  `model/list`, `thread/list`, and `thread/read`. List pages are normalized to at
  most 100, cursors to 4 KiB, thread IDs to 128 bytes, `thread/list` to its small
  pagination/sort/non-archived subset, and `thread/read` to
  `includeTurns=false`. Unknown fields, write methods, idempotency keys, or a
  device without read scope fail closed before dispatch.
- Moved the Host event loop from an unbounded channel to a capacity-64 channel.
  Remote request correlation is independently capped at 64 requests and 64 KiB.
  Internal IDs include the random Host session, local input cannot claim their
  reserved namespace, and only the exact current-session top-level response is
  suppressed from desktop stdout.
- Extended the existing streaming sanitizer so a matched Remote response is
  captured only after large `aggregatedOutput` fields have been replaced by
  opaque spool descriptors. Capture is capped at 1 MiB minus envelope headroom;
  a larger response reports its exact sanitized size without being materialized
  or reinjected. Other-session-looking IDs and nested IDs remain on the desktop
  path.
- Added per-connection application queues bounded at 16 messages and 2 MiB, a
  1 MiB encoded-message ceiling, five-second socket writes, 30-second upstream
  request lifetime, and disconnect cleanup. Queue/byte/timeout exhaustion closes
  the socket and releases pending mappings instead of blocking heartbeat or
  retaining ambiguous requests.
- Added `tool/remote_smoke.dart`. A release Host plus the real stock app-server
  passed local ticket creation, hash-only pairing, WebSocket negotiation,
  `model/list` (8 models), one-row `thread/list`, metadata-only `thread/read`, no
  internal-ID leakage to local stdout, live policy-close revocation, temporary
  state cleanup, and zero Host exit. This proves the loopback read path on the
  current Linux runtime, not Android or non-loopback behavior.
- The Rust suite now passes 25 Remote-library tests, 38 Host-binary tests, and
  two executable failure-path tests (65 total); format, strict Clippy, the
  release build, and focused Dart analysis also pass.

### 2026-11-05 — Phase 4 authenticated loopback Remote foundation

- Added an opt-in `CODEX_NATIVE_REMOTE_LISTEN`/`--remote-listen` address. The
  parser and listener independently require a literal IPv4/IPv6 loopback
  address; wildcard, LAN, and hostname forms fail before bind, and the listener
  remains disabled by default.
- Added bounded `axum` 0.8.9/Tokio 1.54.1 HTTP and WebSocket endpoints on a
  dedicated runtime thread. HTTP bodies are capped at 8 KiB; WebSocket frames at
  256 KiB, messages at 1 MiB, the socket write buffer at 2 MiB, connections at
  eight, and the initial client hello at five seconds. Pairing is globally
  limited to ten attempts per minute for this loopback slice.
- Wired local one-use tickets to `/v1/pair`, returning the 256-bit device bearer
  once while persisting only its digest. `/v1/ws` requires the exact bearer and
  `codex-native-v1` subprotocol, performs the three-message negotiation, emits
  heartbeat pings, and rechecks expiry/revocation while connected. The
  unauthenticated health response intentionally omits the process session ID.
- Kept the reachable RPC surface deliberately read-only and narrow:
  `host/remote/status` proves authenticated request/response framing; every
  other method is rejected. Stock app-server IDs/events and write methods are
  not yet connected, so replay, correlation, and idempotency remain tested core
  primitives rather than an end-to-end network claim.
- A real TCP test covers health headers, ticket pairing and non-reuse, absence of
  the token from disk, unauthenticated rejection, subprotocol negotiation,
  read-only RPC, pre-handshake RPC rejection, live revocation, and rejected
  reconnect after revocation. A second active-socket shutdown test initially
  observed `ResetWithoutClosingHandshake`; connection-task draining and a
  shutdown broadcast now deliver an `Away` close frame within the bounded
  one-second drain window. Host cleanup stops Remote intake before stock Codex
  and no Remote error can skip child-process cleanup.
- The Rust suite passes 25 Remote-library tests, 31 Host-binary tests, and two
  executable failure-path tests (58 total), plus format and strict Clippy. A
  release build and real stock-Codex process smoke are recorded separately in
  the current verification section.

### 2026-11-05 — Phase 4 local Remote administration boundary

- Added a separate user-config credential-store location with an explicit
  `CODEX_NATIVE_REMOTE_DEVICE_FILE`/`--remote-device-file` override. If no secure
  config directory is available, local Codex still starts and Remote
  administration fails closed instead of falling back to a shared temporary
  directory.
- Integrated bounded local Host RPCs to create the one active five-minute
  pairing ticket, list public device metadata, and revoke an exact device ID.
  These methods never return a stored token digest or filesystem path; unknown
  parameters and missing IDs are rejected as invalid requests.
- Kept registry initialization lazy. A deterministic corrupt-store gate proves
  `host/status` remains available while the first Remote device call returns a
  generic internal error without leaking its path.
- A production release Host with stock app-server passed process-level
  `host/status`, ticket creation, and empty device-list JSONL calls, then exited
  cleanly on EOF. Stock app-server logged a shutdown-before-client-name warning
  because this management-only smoke deliberately did not initialize Codex; no
  process survived.
- The Rust suite now passes 25 Remote-library tests, 25 Host-binary tests, and
  two executable failure-path tests (52 total), plus format, strict Clippy, and
  the release build. A real network pairing exchange and live revocation remain
  unimplemented.

### 2026-11-05 — Phase 4 Remote protocol and device-auth core

- Added a reusable `codex_native_host::remote` library boundary without changing
  the production desktop stdio path. Typed client/server messages reject RPCs
  before `client_hello`, choose the highest common version, expose capabilities,
  and distinguish same-session replay from explicit gap/process-change resync.
- Added a strictly increasing event journal bounded independently by 512 events
  and 8 MiB by default. Count eviction, byte eviction, oversized single events,
  future cursors, and sequence exhaustion all fail closed; an unretained event
  creates an explicit replay gap rather than silently skipping data.
- Added monotonic ACK tracking and per-connection correlation namespaces. Equal
  client request IDs can coexist on different devices, while duplicate pending
  IDs on one connection, pending-count exhaustion, counter wrap, and disconnect
  cleanup are tested.
- Added a bounded same-session idempotency ledger keyed by device, method, and
  caller key plus a SHA-256 parameter fingerprint. It distinguishes pending,
  replayable result, pre-dispatch cancellation, and post-dispatch unconfirmed
  state; a result too large to retain becomes unconfirmed rather than
  re-executable.
- Added 256-bit device tokens from the operating-system random source,
  SHA-256-only persistence, constant-time digest comparison, typed scopes,
  expiry, rotation, revocation, last-seen state, and short-lived single-use
  pairing tickets. Unix credential files are atomically published as `0600`;
  symlinked, non-regular, foreign-owner, or group/world-accessible stores are
  rejected.
- The new Remote library has 25 unit tests. Together with the existing 23 Host
  binary tests and two executable failure-path tests, the Rust suite passes 50
  tests; format and `clippy --all-targets -D warnings` also pass. Network/TLS,
  concurrent registry writers, Windows ACL replacement semantics, live
  revocation, and physical Android behavior remain unclaimed.

### 2026-11-05 — Phase 4 Remote transport research and protocol decision

- Reviewed current official app-server stdio/Unix/WebSocket listener and
  authentication support, five upstream Remote failure reports, and three
  reference clients at pinned commits with Apache-2.0, PolyForm Noncommercial,
  and GPL licensing boundaries recorded.
- Confirmed that upstream WebSocket availability does not replace this project's
  Host: direct access would bypass the already-integrated bounded output spool,
  lifecycle, and future attachment boundary. ADR-010 keeps ordinary Codex RPC
  semantics while adding only a minimal Host-owned authenticated/resumable
  envelope.
- Defined local single-use pairing, hash-only device credential persistence,
  TLS-required non-loopback exposure, three-message negotiation, process session
  identity, sequence/ACK/resync rules, dual count/byte journal limits,
  correlation namespaces, same-session write idempotency, fail-closed pending
  interactions, bounded recovery reads, and chunked large-object transfer.
- Preserved negative evidence that socket authentication/readiness is separate
  from bounded hydration and live writer state, that large payloads can block
  recovery/control traffic, and that stale lifecycle results can overwrite newer
  navigation/turn state unless generation-scoped and monotonic.

### 2026-11-05 — Phase 3 Host storage-failure and shutdown gates

- Found and fixed a concrete session-budget leak: an output that had stored
  earlier chunks and was then abandoned or failed retained those byte counts
  after its partial file was removed, causing long sessions to hit the 2 GiB cap
  prematurely.
- Made output publication transactional across data flush/rename and metadata
  write/rename. Any unpublished path now closes the handle, removes data,
  metadata, and `.part` artifacts, releases its exact accounted bytes, and emits
  an unavailable descriptor instead of a broken reference or original output.
- Added deterministic Linux `/dev/full` coverage, abandoned-output reuse,
  post-data/pre-metadata failure cleanup, invalid-cache-root handling, and an
  executable-level unwritable-cache gate proving Host exits with bounded context
  before starting the configured Codex child.
- Added close-phase timing to runtime, thread, and real coding-task smokes. The
  current release Host closed in 108 ms after initialization, 58 ms after
  list/read/resume/start/delete, and 63 ms after a completed coding turn plus
  bounded output read; a fresh Linux release bundle closed its packaged Host in
  32 ms. The earlier approximately 6.1-second GUI fallback remains historical
  negative evidence but did not reproduce in these current stock-app-server
  paths, so shutdown budgets were not speculatively shortened.
- Added a Linux lifecycle soak that records each Host's direct Codex child from
  `/proc`, loads a bounded thread page, closes through production transport, and
  checks both PIDs and cache-session names. A 50-iteration release run observed
  50 distinct Codex children, 51 ms maximum/26 ms mean shutdown, zero surviving
  Host or Codex PIDs, and zero new session directories.

### 2026-11-05 — Phase 3 product interaction gates

- Added a production-App widget gate for the complete stored-command path:
  summary rows defer full turn items, the selected turn exposes one deferred
  command, explicit fetch reads only that item, and opening the viewer then
  reads only a 64 KiB tail window.
- Exercised truncated-output messaging and First/Previous/Next/Tail navigation
  against a 150,000-byte retained fixture. Assertions cover exact byte offsets,
  the three-byte UTF-8 look-ahead ceiling, and the absence of output-range calls
  before the corresponding user actions.
- Added a failed-tail-read gate proving the controller exposes the error, leaves
  no false chunk, and recovers only after an explicit retry.
- Added production-App gates for both dangerous execution overrides. Canceling
  `never` approval and `danger-full-access` preserves inherited Codex defaults;
  confirming each choice is required before those exact overrides reach the
  next real `TurnStartOptions`.
- Added a 4,000-line/2-file diff widget gate. The UI displays the bounded
  truncation warning and aggregate counts, builds the first visible line but not
  the off-screen last line, and switches to the second file without retaining a
  parallel rendered list.

### 2026-11-05 — Phase 3 bounded assistant Markdown

- Researched the current Codex TUI renderer, `flutter_markdown_plus`, Dart
  `markdown`, Flutter lazy-list behavior, and `url_launcher`; compared three
  broader/younger renderer alternatives and recorded exact adoption and
  non-adoption decisions in `docs/RESEARCH.md`.
- Added completed-only assistant Markdown with a project-owned extension
  allowlist for fenced code, tables, task lists, strikethrough, and autolinks.
  Block HTML is rendered literally, inline HTML is not enabled, remote/local
  images become bounded placeholders, and only user-clicked absolute
  `http`/`https` links can leave the app through the external launcher.
- Kept streaming messages as selectable plain text, relied on the existing
  lazy timeline rather than retaining parsed documents, and added a separate
  16 KiB rich-rendering cap with an explicit bounded plain-text tail fallback.
- Added direct third-party provenance, widget gates for formatting/HTML/image
  safety, URI allowlisting, streaming fallback, and pathological source caps,
  and retained the existing 1,000-row production-App lazy-build test.
- The first pathological widget gate sent a completed 64 KiB unbroken token to
  the renderer and kept `flutter_tester` busy for more than 30 seconds. That is
  preserved as a real negative performance result; the 16 KiB rich cap and
  plain-text fallback were introduced from it, and the capped rerun completed.
- Linux release packaging passed with the desktop launcher plugin. A normal
  Android build from the repository's Unicode path failed because Flutter's
  Gradle settings decoded the SDK path incorrectly. Repeating the native
  `assembleDebug` gate with a temporary ASCII SDK alias passed all 87 actionable
  tasks and produced the 145 MiB debug APK for arm64-v8a, armeabi-v7a, and
  x86_64; the ignored local SDK path was restored afterward.

### 2026-11-05 — Phase 3 Host integration and bounded output viewer

- Made the native Host the only production desktop process entry, with separate
  `CODEX_EXECUTABLE` and `CODEX_NATIVE_HOST` discovery and an explicit typed
  Host-not-found state instead of an unsafe direct fallback.
- Added Linux/Windows Cargo build-and-package rules, a macOS Xcode build/sign
  phase, and CI gates for Rust format, Clippy, tests, and the synthetic fixture.
- Added typed output descriptors, `stat`/range/tail adapters, strict response
  validation, deferred-item reads, stale-result guards, and a range-backed log
  viewer that keeps at most a 64 KiB page plus three UTF-8 look-ahead bytes.
- Item-list requests now send the forward-compatible
  `deferOutput.commandExecution` preference. Initialization explicitly opts into
  `experimentalApi`, which is required by the installed server for
  `thread/items/read`.
- Added a release synthetic app-server fixture that deliberately holds both its
  3/30/300 MiB source output and serialized response. Three Linux runs verified
  every descriptor and the first/tail 1 KiB. At 300 MiB, fixture RSS grew
  629,157,888/629,157,888/629,153,792 bytes, Host RSS had no observable growth
  at 2 ms sampling, and Dart RSS grew 2,281,472/4,431,872/2,211,840 bytes. These
  are synthetic Linux observations, not absolute or cross-platform guarantees.
- Real Host-routed runtime, thread, model, turn, interruption, approval-reject,
  history, coding-task, `thread/items/read`, and bounded output-tail paths passed.
  The coding task retained 7,443 output bytes behind an opaque Host reference and
  cleaned its exact test thread/workspace.
- The first enhanced coding smoke failed with `-32600: thread/items/read requires
  experimentalApi capability`. This was a real protocol-negotiation defect, not
  a flaky run; explicit capability negotiation fixed it and the rerun passed.
- Final range-view review found that the three UTF-8 look-ahead bytes were also
  rendered for ordinary ASCII pages, duplicating them on the next page. The
  decoder now consumes look-ahead only to finish a split scalar, and regression
  tests cover both ASCII non-duplication and split four-byte UTF-8.
- Added ADR-009 after official Flutter/Apple research: macOS v1 uses direct
  signed/notarized distribution rather than a Mac App Store sandbox.

### 2026-11-05 — Phase 3 native Host bounded-output core

- Researched current upstream Codex, its same-day experimental output deferral,
  three large-history failure reports, two incompatible-license reference
  clients, one permissive reference client, and incremental Rust JSON parsers;
  recorded exact adoption and non-adoption decisions in `docs/RESEARCH.md`.
- Added an Apache-2.0 Rust workspace and `codex-native-host`, pinning
  `json-skimmer` 1.0.0 behind an independently implemented streaming JSON-string
  decoder.
- The Host reads fixed-size stdout chunks, validates complete JSON candidates
  before atomically publishing them, extracts command output without retaining
  the scalar, preserves escape/Unicode semantics, and rejects malformed,
  truncated, over-depth, junk, or over-budget input.
- Added owner-only session/output files, per-output and per-session caps, stale
  inactive-session cleanup, opaque 128-bit references, path-traversal rejection,
  bounded base64 range/tail replies, parent-death handling on Linux, and bounded
  EOF/TERM/KILL child shutdown.
- Added 19 Rust tests covering every input fragmentation point, escapes,
  surrogate pairs, raw UTF-8, multiple/nested messages, truncation, malformed
  input, input budgets, permissions, range/tail semantics, traversal, and Host
  routing.

### 2026-11-05 — Phase 3 bounded stored-history vertical slice

- Added typed `thread/turns/list` and `thread/items/list` adapters with server-owned opaque cursors.
- Turn pages explicitly request summary items; command history retains only a bounded command label and never `aggregatedOutput`.
- Added a history controller with 20-turn/25-item pages, 100-turn and 100-selected-item hard caps, cursor-based load-more, ID deduplication, stale-response generation guards, immediate inactive-thread eviction, and a fixed-size older-turn window that evicts its newest edge while browsing backwards.
- Merged paged summary history with the bounded live projection by item ID and kept the timeline virtualized. Full-item pagination remains typed/tested but is deliberately not exposed in the UI until heavy payloads can be requested safely.
- Added synthetic 1,000-turn/200-item-per-turn coverage proving the controller walks all 50 source pages while retaining only its configured 100-turn/50-selected-item test window. A separate 3 MiB `aggregatedOutput` fixture proves command output is not copied into the typed presentation projection.
- Added a production-App widget test with 1,000 projected history rows; after real thread selection, fewer than 100 history row widgets exist in the element tree and the last off-screen row is absent, proving `ListView.builder` virtualization rather than eager construction.
- Added `tool/history_memory_benchmark.dart`. Across two recorded runs, walking 1,000 source turns while retaining 100 increased RSS by 1,482,752–1,564,672 bytes. Decoding and immediately discarding ten 3 MiB command outputs then increased RSS by another 29,085,696–31,879,168 bytes, quantifying the upstream full-payload limitation rather than hiding it.
- Extended the real coding smoke to read the completed turn through both pagination APIs before deleting it; the server returned one turn and nine items.

### 2026-11-05 — Phase 2 execution controls, bounded diff, and coding-task gate

- Added typed `model/list` discovery and a settings controller for server-advertised models/reasoning efforts plus explicit approval/sandbox overrides.
- Preserved stock Codex defaults by omitting all overrides until the user selects one. Added confirmation dialogs before disabling approval prompts or granting danger-full-access sandbox mode.
- Added typed turn override serialization using the server's `model`, `effort`, `approvalPolicy`, and `sandboxPolicy` fields.
- Added a bounded unified-diff parser, active-thread diff controller, changed-file counts, selected-file picker, truncation state, and virtualized line rendering.
- Added `tool/model_smoke.dart` and an opt-in Flutter harness at `tool/coding_task_smoke.dart`.
- The real coding smoke used `workspace-write` and `never` only inside a newly created `/tmp` workspace, changed `notes.txt` from `alpha` to `alpha` + `beta`, observed one file/one addition/no approval requests, and deleted the exact smoke thread and workspace.
- The first coding-smoke harness attempt used `testWidgets`; its fake clock prevented timeout/shutdown timers from advancing and required runner interruption after read-only inspection showed no remaining app-server or temp workspace. The harness now uses ordinary Flutter `test`, and the same task passed with real timers.

### 2026-11-05 — Phase 2 turn and approval vertical slice

- Added typed turn requests/events for start, interruption, assistant streaming, lifecycle, failures, and summarized tool activity.
- Added a bounded conversation controller with 50 ms delta coalescing, a 200-entry cap, a 64 KiB per-entry cap, and a 16-item pending-delta cap.
- Added a desktop conversation surface with a virtualized timeline, composer, terminal state reporting, and stop control.
- Preserved an observed app-server race: a `turn/start` response can precede `turn/started`, and an immediate interrupt is rejected as having no active turn. The UI now enables Stop only after the matching start notification.
- Added v2 and legacy approval adapters for commands and file changes, a bounded pending queue, resolution notifications, fail-closed handling for unknown/permission requests, and explicit approve-once/reject UI.
- Added optional typed thread-start approval/sandbox overrides without changing the default user-configured policy.
- Added `tool/turn_smoke.dart` and `tool/approval_smoke.dart`. The approval smoke uses `untrusted` + `read-only`, rejects the requested harmless print command, waits for terminal turn state, and deletes only its own thread.

### 2026-11-05 — Phase 2 thread metadata vertical slice

- Added typed thread/domain models and isolated v2 serialization/parsing for list/start/read/resume.
- Enforced `includeTurns:false` for reads and `excludeTurns:true` for resumes so metadata UI cannot hydrate full history.
- Added a bounded thread controller with 25-row pages, a hard 100-row retention cap, opaque cursor pagination, deduplication, refresh, start, select, and resume state.
- Added a functional thread list/start/resume desktop surface using the existing theme tokens.
- Added exact-ID `thread/delete` only for deterministic cleanup of smoke-owned persistent threads.
- Added SIGTERM/SIGINT coordination on Linux/macOS so the Flutter process waits for bounded child shutdown rather than abandoning a loaded app-server.
- Added protocol/controller tests and `tool/thread_smoke.dart` for real list/read/resume/start/delete-cleanup validation.

### 2026-11-05 — Phase 1 local vertical slice

- Bootstrapped Flutter targets for Linux, Windows, macOS, and Android.
- Added typed initialization models, JSONL decoding, JSON-RPC correlation, notifications/server-request streams, and explicit protocol errors.
- Added process executable discovery, stock app-server startup, bounded stderr capture, abnormal-exit reporting, graceful EOF/TERM/KILL shutdown, and concurrent-close coalescing.
- Added the minimal runtime status UI for locating, starting, connected, not found, error, process-exited, unsupported, and stopped states.
- Added `tool/runtime_smoke.dart` for a real stock app-server handshake without launching the GUI.
- Added 11 focused tests covering fragmented/multiple/malformed JSONL input, request correlation, unknown response IDs, JSON-RPC errors, initialization, process exit, stderr context, graceful/concurrent shutdown, and typed UI state.
- Added local run/verification instructions and lightweight CI.

### 2026-11-05 — Repository foundation

- Created repository and selected Apache-2.0.
- Chose Flutter/Dart for the client UI and stock `codex app-server` as the runtime/harness boundary.
- Chose isolated stdio/JSONL for desktop v1 and a future authenticated resumable remote control plane for Android.
- Decided `flutter_rust_bridge` is not a v1 dependency.

## Validation evidence

Results below span 2026-11-05 and 2026-11-06 on Manjaro Linux x86_64 with
Flutter 3.47.1 and Codex `0.166.0-alpha.5.1`; individual entries preserve their
specific evidence boundaries.

- `dart format lib test tool`: PASS.
- `dart analyze --fatal-infos`: PASS, no issues.
- `flutter analyze --no-pub <ASCII symlink argument from an ASCII working directory>`: PASS, no issues. Running from the symlink as the process working directory still resolves the Unicode real path and reproduces the known LSP truncation failure.
- `flutter test`: PASS, 176 tests, including the Remote transport, invitation,
  record-v1 migration/v2 certificate trust, lifecycle, pairing/onboarding,
  trusted desktop administration/clipboard/QR, ticket-expiry behavior, and
  widget interaction gates.
- `flutter build linux --debug`: PASS.
- `dart run tool/runtime_smoke.dart`: PASS against the installed stock Codex; the initialize response identified Codex Desktop/app-server `0.166.0-alpha.5.1`.
- `dart run tool/thread_smoke.dart`: PASS against the installed stock Codex; listed 10 oldest threads, read and resumed an existing inactive thread without turns, started a smoke-owned persistent thread, and deleted that exact test thread.
- `dart run tool/turn_smoke.dart`: PASS against the installed stock Codex; a fixed-response turn completed with the expected marker, a second turn reached `turn/started`, interruption completed with status `interrupted`, and the smoke-owned thread was deleted.
- `dart run tool/approval_smoke.dart`: PASS against the installed stock Codex; an untrusted command produced a typed approval, the client rejected it, the turn completed, and the smoke-owned thread was deleted without executing the command.
- `dart run tool/model_smoke.dart`: PASS; the installed app-server advertised 8 visible models, identified `gpt-6.1-sol` as default, and advertised `low` as its default reasoning effort.
- `flutter test tool/coding_task_smoke.dart --reporter expanded`: PASS after history integration in 29 seconds; production controllers completed the exact temporary-file task, projected one changed file/one addition, observed zero approvals, paged back one turn/nine items, and cleaned both thread and workspace.
- `flutter test tool/history_memory_benchmark.dart --reporter expanded`: PASS twice; 1,000 source turns retained 100. RSS deltas were 1,482,752/1,564,672 bytes for turn paging and 29,085,696/31,879,168 bytes for ten sequential 3 MiB discarded outputs. These are Linux debug-test measurements, not cross-platform guarantees.
- `cargo fmt --all -- --check`: PASS.
- `./tool/generate_native_licenses.sh --check`: PASS with pinned cargo-about
  0.9.3; the committed runtime notice is byte-identical to fresh locked output.
- `dart run tool/verify_native_license_packaging.dart`: PASS,
  `NATIVE_LICENSE_PACKAGING=SOURCE_PASS`, 257,985 notice bytes, with Linux,
  Windows, and macOS source packaging contracts present.
- `dart run tool/verify_android_release_signing.dart`: PASS,
  `ANDROID_RELEASE_SIGNING=SOURCE_PASS`; debug fallback, fail-closed markers,
  private-file ignore rules, and placeholder-only example are enforced without
  reading ignored signing material.
- `cargo clippy --workspace --all-targets -- -D warnings`: PASS.
- `cargo test --workspace`: PASS, 26 Remote-library tests, 68 Host-binary tests,
  and 4 executable failure-path tests (98 total), including exact-output dedup,
  candidate rollback/first-delivery ownership, real TCP/WSS,
  exact event replay/gap recovery, abrupt reconnect, slow-reader disconnection,
  live revocation, certificate trust/rotation/rollback, protocol-close shutdown,
  deterministic storage failure, and cache/TLS startup gates.
- `cargo build --release --workspace`: PASS.
- Isolated official Rust 1.87.0 `cargo test --locked --workspace`: EXPECTED
  COMPATIBILITY FAILURE before compilation because `uuid` 1.29.0 requires rustc
  1.89.0. This disproves the former manifest floor. Isolated official Rust
  1.89.0 from empty Cargo/target state: PASS, all 84 Rust tests; the validated
  temporary tree was removed afterward.
- Pinned `actionlint` 1.7.12 over `.github/workflows/ci.yml`: PASS. Independent
  PyYAML parsing of CI and Dependabot configuration: PASS.
- Release `codex-native-host` real-runtime smoke: PASS; one process carried a
  Host status request plus stock app-server initialize/initialized and reported
  Codex Desktop/app-server `0.166.0-alpha.5.1`. This isolated smoke established
  the handshake and clean EOF shutdown before Flutter integration.
- Release Host Remote-foundation smoke: PASS in 333 ms against the same stock
  app-server. The process bound an ephemeral loopback port, reported
  `enabled=true`, `scope=loopback`, and `tls=false`, created a redacted local
  one-use pairing ticket, completed initialize/initialized, and exited zero on
  EOF without leaving a device credential file. The first harness attempt was
  invalid because its absent `jq` consumer caused stdout `Broken pipe`; it was
  not counted as a product pass or failure.
- `dart run tool/remote_smoke.dart`: PASS in 10.777 seconds against release Host
  and stock app-server. It paired without plaintext token persistence, negotiated
  `codex-native-v1`, read 8 models, listed and metadata-read a real thread,
  observed no internal ID on local stdout, live-revoked the device, removed its
  temporary state, and observed Host exit code zero.
- TLS-configured `dart run tool/remote_smoke.dart`: PASS in 10.701 seconds
  against release Host and the same stock app-server. The Host bound network
  scope, reported certificate invitation trust, and Dart first rejected the
  generated self-signed identity under ordinary system trust for both HTTPS and
  WSS. The exact versioned invitation trust then completed pairing and WSS,
  eight-model and metadata-thread reads, internal-ID isolation, live revocation,
  temporary-state cleanup, and zero Host exit.
- `dart run tool/host_memory_benchmark.dart`: PASS three times for 3/30/300 MiB.
  Fixture deltas were 6,303,744/62,926,848/629,157,888,
  6,303,744/62,926,848/629,157,888, and
  6,299,648/62,922,752/629,153,792 bytes; Host deltas were 0/0/0 bytes at 2 ms
  sampling; Dart deltas were 57,344/774,144/2,281,472,
  36,864/765,952/4,431,872, and 49,152/630,784/2,211,840 bytes. First/tail reads
  matched the complete spooled payload in every case. The final exact-repeat
  gate then read every size twice and required one shared ref plus one data/
  metadata pair: fixture deltas were 8,396,800/94,380,032/629,153,792, Host
  deltas 200,704/200,704/266,240, and Dart deltas
  2,269,184/2,473,984/3,039,232 bytes.
- `flutter build linux --debug` and `flutter build linux --release`: PASS with
  an executable packaged `codex-native-host` beside the Flutter binary and the
  native URL-launcher plugin.
- Fresh `flutter build linux --debug`: PASS with byte-identical
  `NATIVE_HOST_THIRD_PARTY_LICENSES.txt` beside the Host; notice mode is 0644 and
  Host mode is 0755. Later hosted Windows and macOS builds verify their package
  locations and execute their packaged Host binaries.
- Fresh Linux release-bundle Host runtime smoke after transactional storage
  recovery: PASS against stock Codex with a measured 32 ms close phase.
- `flutter build apk --debug` from the real Unicode repository/SDK path: FAILED
  before compilation because `android/settings.gradle.kts` observed the SDK as
  `/home/axiaobo/ææ¡£/flutter`. With only the ignored
  `android/local.properties` temporarily pointed at an exact ASCII symlink,
  `./gradlew assembleDebug` passed 185 actionable tasks and produced the
  unchanged 191,469,644-byte debug APK with arm64-v8a, armeabi-v7a, and x86_64
  native outputs. The file and symlink were restored/removed afterward. This
  proves the Android product and plugin build under the path workaround, not a
  clean ordinary-path build.
- Android release-signing contract: PASS for both failure and success paths.
  Without `android/key.properties`, `assembleRelease` stopped at the intended
  redacted configuration error; `assembleDebug` still passed 185 tasks. A
  temporary external RSA keystore produced a 54,019,334-byte APK and
  52,739,360-byte AAB; `apksigner` matched the exact temporary certificate and
  `jarsigner` verified the bundle. All temporary signing material and signed
  outputs were removed. No production-key or store claim is made.
- Packaged Linux GUI runtime launch: PASS; direct process inspection showed
  Flutter -> adjacent bundled Host -> separately located stock Codex. SIGINT
  removed all three processes. Existing ATK/cursor-theme warnings remained.
- Host-routed `runtime_smoke`, `thread_smoke`, `model_smoke`, `turn_smoke`, and
  `approval_smoke`: PASS. The approval smoke rejected rather than approved its
  command as designed. Current close-phase measurements were 108 ms for the
  initialization-only runtime smoke and 58 ms after the thread smoke's
  list/read/resume/start/delete lifecycle.
- Enhanced `coding_task_smoke`: first run FAILED at the newly exercised
  `thread/items/read` capability gate; after declaring `experimentalApi`, rerun
  PASS in 27 seconds with 11 history items and a verified 7,443-byte Host output
  spool/tail.
- Final packaged-release reruns after strict output reference/range/EOF
  validation: PASS in 21/27 seconds with 9/10 history items, readable 6-byte
  selected command outputs, and exact test thread/workspace cleanup.
- Real coding-task rerun after transactional storage recovery: PASS in 23
  seconds with 9 history items, a readable 6-byte output spool, exact thread and
  workspace cleanup, and a measured 63 ms Host shutdown.
- Real coding-task rerun after exact-output reuse and the independent object cap:
  PASS in 18 seconds with 9 history items, one readable 6-byte output, the same
  reference on the second item read, one changed file/one addition, zero
  unexpected approvals, exact thread/workspace cleanup, and a 59 ms Host
  shutdown.
- `CODEX_NATIVE_SOAK_ITERATIONS=50 dart run tool/host_lifecycle_soak.dart`: PASS;
  50 Host/Codex process pairs, 51 ms maximum and 26 ms mean close, zero surviving
  PIDs, and zero new cache sessions.
- Real Linux GUI launch after the model/diff slice: PASS; the connected runtime, thread list, empty conversation state, and loaded `Defaults` execution-control entry rendered correctly in direct inspection. SIGINT produced a coordinated exit, and neither the Flutter process nor its app-server child survived.
- Secret/credential scan: PASS; no token, private-key, bearer, or assigned credential patterns found in the repository scope.
- Hosted GitHub Actions CI: run `42076435647` at `36b7102` PASS. Ubuntu verify,
  Windows x64, and macOS arm64 all completed successfully; Android debug assembly
  and its non-empty artifact assertion passed under explicit Temurin 17.
- Exact local OpenJDK 17.0.20.1 Android `assembleDebug`: PASS, 185 tasks and a
  non-empty 191,469,644-byte debug APK. The temporary ASCII SDK alias was removed
  and ignored `local.properties` was restored afterward.
- Windows and macOS debug build/package execution: PASS on hosted Windows Server
  2022 x64 and macOS 15 arm64. Native install/ACL/Human validation, macOS
  signing/notarization, and physical-device validation remain unrun.
- Exact-output code-bearing CI: run `42135777838` at `4d35b56` PASS. Linux/
  Android job `127623402214`, Windows job `127623402465`, and macOS universal
  job `127623402670` all completed successfully, including native tests on each
  OS, hosted Flutter analysis/tests, supported desktop builds and Host/license
  execution, Linux runtime closure, and the debug APK gate.
- Reverse analysis correction, evidence revalidation & architecture
  reconciliation (`ADR-032`):
  - Audited current `HEAD` (`17f08f3`) source files (`history_controller.dart`,
    `conversation_controller.dart`, `conversation.dart`, `history_protocol.dart`,
    `history_models.dart`, `thread_models.dart`, `thread_list_controller.dart`,
    `native_host/src/config.rs`, `native_host/src/spool.rs`) and eliminated all
    stale repository descriptions in `docs/reverse/ADOPTION_MATRIX.md`.
  - Extended `tools/reverse/inspect_chatgpt_desktop.py` with `--evidence-report`,
    cross-checking ASAR symbols, IPC channels (`10` preload-exposed vs `9`
    internal), RPC strings, and network endpoints (`168` `/backend-api/*` and
    `/wham/*` templates) against the stock `codex app-server 0.167.0-alpha.3.2`
    generated JSON schemas (`105` stable + `74` experimental = `179`
    `ClientRequest` methods; `9` stable + `2` experimental = `11`
    `ServerRequest` methods; `82` `ServerNotification` methods).
  - Verified all 6 official history hydration/retention paths and their Statsig
    gates (`limit: 5` turns in `yU`/`bC`/`readLatestPreviewPage`, `limit: 2`
    items in `fI`, `limit: 28/30/100` in `loadTurnItems`, `limit: 500` items +
    `limit: 100` turns in `bX` gated by `"codex-app-thread-timeline-history"`,
    `maxTurns: 1..100` in `yN` gated by `"codex-app-bounded-cloud-history"`,
    `1000 -> 500` active item eviction in `yX`/`yY` gated by experiment
    `"codex_app_active_history_eviction_v1"` default `false`, and `10`-thread
    LRU `yW = 10`), correcting the `"newest 15 turns"` claim from `ADR-031`.
  - Proved from `early-bootstrap-339 @780000..792000` and `early-bootstrap-920
    @4400493` that `STEPS_PROSE` (`includeProseDetailLevelInstructions: true`)
    injects `<app-context>### Non-technical UI` (`a2`) into Codex/Work agent
    threads and hides bash outputs in the UI rather than making stock
    `app-server` a ChatGPT Cloud Chat backend; mapped the 4-path Work Mode
    runtime orchestration (`local app-server`, `durable` cloud `thread/startAeon`,
    `tpp-local-executor` `codex exec-server` Noise rendezvous +
    `POST /flora/cca/executor` + `thread/environmentReady`, and `tpp` cloud
    conversations); and stratified Official Remote Control into 8 layers (Host
    `remoteControl/*` RPCs and `--listen ws://` in stock `--experimental` schema
    vs Controller `remote-control-device-key.node` + MFA `step_up_token` +
    `/wham/remote/control/server` relay).

### 2026-11-07 — Desktop Shared Conversation Foundation Hardening (`16.B -> 16.A -> 16.C -> 16.E -> 16.D`)

- Completed all five authorized Desktop conversation foundation hardening items in strict priority order:
  1. **`16.B` — `>100 turns` bounded-history eviction / viewport anchor correctness**:
     - Added `loadOlderVersion`, `evictionVersion`, and `lastEvictedItemIds` to `HistoryController` (`lib/src/features/conversation/history_controller.dart`) and clear expanded `_selectedTurnId` state if its turn is evicted.
     - Added `findChildIndexCallback` to `_ConversationScrollView`'s `SliverList.builder` (`ValueKey('measured-$itemKey')`), widened `_averageMeasuredItemHeight` clamp to `(24.0, 4096.0)`, and aligned the pre-load visible anchor (`_MeasuredTimelineItem` / `_VisibleAnchor`) after `loadOlderTurns()` (`loadOlderVersion`) and across `>100-turn` sliding-window eviction (`0.000 px` visual drift across `285,523.9 px` 100-turn real thread).
     - Preserved scrolled-up visual anchor stability when live streaming items are inserted at `reverseIndex = 0` (`_handleConversationChanged` -> `_schedulePostLoadAnchorAlignment`, `0.000 px` yank drift).
     - Added unit test `crossing 100-turn cap evicts newest turns, increments evictionVersion, and records evicted item IDs` (`test/features/conversation/history_controller_test.dart`) and widget test `preserves visual viewport anchor across >100-turn bounded eviction and recovers via Jump to latest` (`test/app/bounded_timeline_test.dart`).
  2. **`16.A` — Content-identity-based cross-thread scroll restoration**:
     - Replaced raw pixel offset map `_threadScrollOffsets` with bounded `LinkedHashMap<String, _ThreadScrollBookmark> _threadScrollBookmarks` (`max 32`), storing `(scrollPixels, anchorItemKey, anchorTurnId, anchorViewportTopDy)` while keeping inactive thread history unretained (`AGENTS.md` Rule #2).
     - On thread return, `_scheduleThreadScrollRestore` automatically pages `loadOlderTurns()` up to `_maxRestorePages = 10` older-page requests (`220` turns including the initial page) when `anchorTurnId` lies in an older page, then aligns `anchorItemKey` to `anchorViewportTopDy` (`0.000 px` drift in live walkthrough Stage 5; `< 1.0 px` across viewport width resizes `1400 px -> 820 px` in `test/app/bounded_timeline_test.dart`).
  3. **`16.C` — Eliminate domain circular import**:
     - Extracted `UserAttachmentKind`, `UserAttachment`, `UserMessagePresentation`, and `parseUserMessagePresentation` into leaf module `lib/src/domain/user_message_presentation.dart` (importing no other `domain/` files), breaking the `history_models.dart <-> thread_models.dart` circular dependency.
  4. **`16.E` — Structured attachment precedence, legacy envelope fallback, deduplication/caps, and adversarial tests**:
     - Enforced strict precedence for structured `UserInput` attachments (`localImage`, `image`, `skill`, `mention`) ahead of legacy envelope fallback (`# Files pasted by the user:`, `# Files mentioned by the user:`, `# Context from my IDE setup:`), with semantic deduplication (`seenAttachmentKeys` / `structuredPaths`), bounded caps (`maxEnvelopeHeaderScanCharacters = 16 * 1024`, `maxUserAttachments = 16`, `maxAttachmentLabelLength = 160`, `maxAttachmentPathLength = 1024`, `maxAttachmentPreviewLength = 2048`), and start-of-message-only header anchoring.
     - Added adversarial unit tests in `test/protocol/history_protocol_test.dart` covering structured-vs-envelope deduplication, 16-attachment cap enforcement, mid-body spoofed header non-stripping, and malformed envelope fallback.
  5. **`16.D` — Audit `_RenderConversationViewport` resize / hit-test / selection / semantics / focus correctness**:
     - Audited Flutter's `RenderViewportBase` (`packages/flutter/lib/src/rendering/viewport.dart:1703-1993`), confirming `paintOffset` on `SliverPhysicalParentData` is the single coordinate transform driving `paint`, `hitTestChildren`, `applyPaintTransform`, `describeSemanticsConfiguration`, and `showOnScreen`.
     - Added widget regression test `short-thread viewport shift preserves hit-testing, semantics, focus ensureVisible, and dynamic resize` in `test/app/bounded_timeline_test.dart`.

### 2026-11-08 — Desktop Shared Conversation Foundation Correction & Evidence Tightening

- Reopened into `SELF_ITERATION` (`ADR-030`) after Human/code review and hosted CI inspection of `cb684b5` identified 2 P1 edge cases, 3 P2 edge cases, `dart format` CI drift, and symbol/constant documentation drift:
  1. **P1 #1 — Deep-history bookmark beyond `_maxRestorePages = 10` never falls back to raw-pixel clamping (`lib/src/app/presentation/conversation.dart`)**:
     - Required non-null `anchorItemKey`, `anchorTurnId`, and `anchorViewportTopDy` on `_ThreadScrollBookmark`.
     - Implemented **Scheme A** in `_scheduleThreadScrollRestore()`: when `anchorTurnId` / `anchorItemKey` is still absent after `_restorePagesLoaded >= _maxRestorePages` (`10`) or when `!canLoadOlderTurns`, the client discards the stale bookmark (`_threadScrollBookmarks.remove(threadId)`), invokes `widget.historyController.refresh()` if `canReturnToNewest` is true, and lands deterministically on the newest boundary (`pixels == 0.0`) rather than clamping old `bookmark.scrollPixels` onto the wrong turn window.
     - Audited and hardened the full `_threadScrollBookmarks` (`max 32`) lifecycle: pruned deleted threads via `_handleThreadListChanged()`, cleared bookmarks at newest / `Jump to latest`, suppressed intermediate bookmark overwrites during scrolled-up streaming via `_pendingStreamAnchor`, and pruned evicted `history-<id>` keys from `_measuredItemHeights` via `HistoryController.lastEvictedItemIds`.
     - Added widget regression test `deep-history bookmark beyond _maxRestorePages does not fall back to raw pixels and resets deterministically to newest` in `test/app/bounded_timeline_test.dart`.
  2. **P1 #2 — Protocol-boundary normalization, deduplication, and bounding of `HistoryItem.attachments` (`lib/src/protocol/history_protocol.dart`, `lib/src/domain/user_message_presentation.dart`)**:
     - Exported `normalizeUserAttachment` and `normalizeUserAttachments` in `lib/src/domain/user_message_presentation.dart` and invoked `normalizeUserAttachments` directly inside `HistoryProtocolAdapter._userAttachments()` so `HistoryItem.attachments` is bounded (`maxUserAttachments = 16`, `maxAttachmentLabelLength = 160`, `maxAttachmentPathLength = 1024`, `maxAttachmentPreviewLength = 2048`) and deduplicated at protocol ingestion time before reaching any domain or UI consumer.
     - Added unit test `bounds, normalizes, and deduplicates HistoryItem.attachments directly at the protocol boundary` in `test/protocol/history_protocol_test.dart`.
  3. **P2 #1 — Strict legacy envelope grammar against prose false positives & quoted-preview delimiter spoofing (`lib/src/domain/user_message_presentation.dart`)**:
     - Replaced broad regex splitting with `_parseLegacyEnvelope`, `_consumeQuotedPastedEntry`, `_isFollowedByEnvelopeBoundary`, and `_findTopLevelRequestDelimiterEnd`: legacy envelope stripping now requires **both** (a) at least one valid attachment or IDE-context line parsed from a structurally pure header (rejecting any free-form prose paragraph before the delimiter) **and** (b) a top-level `## My request:` / `## My request for Codex:` delimiter outside quoted `## "<preview>": <path>` blocks.
     - Added adversarial unit tests in `test/protocol/history_protocol_test.dart` for prose starting with `# Files mentioned by the user:` + `## My request:` (`hadStructuredEnvelope: false`), empty header before `## My request:` (`hadStructuredEnvelope: false`), and `## My request:` inside a quoted `# Files pasted by the user:` preview (`hadStructuredEnvelope: true`, split only at outer delimiter).
  4. **P2 #2 — Preserve literal `&#x20;` in user prose (`lib/src/domain/user_message_presentation.dart`)**:
     - Updated `_cleanUserMessageText()` to strip only confirmed `&#x20;\` line-continuation and trailing escape artifacts (`_htmlSpaceContinuationPattern`, `_trailingHtmlSpaceEscapePattern`), preserving literal ``请问 HTML 里的 `&#x20;` 是什么意思？`` tokens in user prose (verified in `test/protocol/history_protocol_test.dart`).
  5. **P2 #3 — Tighten `_RenderConversationViewport` semantics transform & selection tests (`test/app/bounded_timeline_test.dart`)**:
     - Strengthened `short-thread viewport shift preserves hit-testing, semantics, selection, focus ensureVisible, and dynamic resize` to verify global transformed `SemanticsNode` rect alignment (`MatrixUtils.transformRect(node.transform, node.rect)` matching `tester.getRect`) and `SelectableText` gesture tap selection inside a shifted short viewport.
  6. **Documentation & CI format gate reconciliation**:
     - Reconciled all symbol names and constants across `PROJECT_STATUS.md`, `docs/RESEARCH.md`, and `docs/reverse/ADOPTION_MATRIX.md` with `HEAD` (`_maxRestorePages = 10`, `maxEnvelopeHeaderScanCharacters = 16 * 1024`, `maxUserAttachments = 16`, `maxAttachmentLabelLength = 160`, `maxAttachmentPathLength = 1024`, `maxAttachmentPreviewLength = 2048`, `UserAttachment`, `seenAttachmentKeys`, `structuredPaths`, `SliverPhysicalParentData`).
     - Restored clean `dart format --output=none --set-exit-if-changed lib test tool` compliance across all 130 Dart files.

## Known risks / watch items

- Direct `flutter analyze` from this repository's Unicode filesystem path
  currently crashes Flutter 3.47.1's LSP byte-stream parser with an initialize
  message truncated at character 401. Flutter's tool writes LSP
  `Content-Length` from Dart string characters rather than UTF-8 bytes; the
  multibyte `文档` path therefore undercounts the frame. The same source passes
  `dart analyze` at the real path and `flutter analyze --no-pub` through a
  temporary ASCII symlink. This is preserved as a toolchain/path issue, not
  recorded as a clean direct-path run.
- The same Unicode-path toolchain defect affects Android settings evaluation:
  ordinary `flutter build apk --debug` corrupts the Flutter SDK path before
  compilation. A temporary ASCII SDK alias proves `assembleDebug` itself passes,
  but the normal developer command is still blocked on this filesystem layout.
  The passing build also reported Gradle-10/AGP-9 migration warnings, an ignored
  legacy manifest `package` attribute in `url_launcher_android`, and an Android
  SDK XML version skew; none was promoted to a clean warning-free gate.
- Dart 3.13 exposes an inbound WebSocket frame cap, not an aggregate fragmented-
  message cap. The client sets it to 1 MiB, disables compression, and also
  rejects any delivered combined message above 1 MiB; the authenticated Host
  independently caps each message and emits it as one frame. This is bounded
  for the trusted Host implemented here, not proof that a compromised
  authenticated Host cannot fragment a larger message and cause a transient
  client allocation before the combined check. There is no accept-all TLS path.
- `flutter_secure_storage` 11.2.0 has an open Android issue in which a transient
  Keystore lookup can return null and cause its RSA wrapping pair to be replaced
  before `resetOnError` is consulted. This project disables automatic reset and
  surfaces unreadable/corrupt state without deleting it, but cannot recover an
  already replaced non-exportable key. Because the Remote bearer is revocable,
  explicit clear and re-pair is the bounded recovery; real device fault testing
  and an upstream fix or re-evaluation remain release gates.
- Android production release identity is intentionally unconfigured. Release
  builds now fail closed until an operator supplies an external upload key, but
  key generation/custody/backup, Play App Signing enrollment, CI secret
  injection, store validation, and update-continuity recovery have no Human
  decision or live evidence yet.
- Safe assistant Markdown intentionally differs by lifecycle and size:
  in-progress messages are plain text, and completed messages above 16 KiB show
  only a labeled bounded tail rather than rich formatting. Actual external
  browser activation, selection behavior, and visual fidelity still require
  Human validation; local workspace/file links are deliberately blocked until
  an explicit cwd/path authorization policy exists.
- A successful `turn/start` response does not prove the server has installed the turn as interruptible. Real validation observed `turn/interrupt` fail with `-32600` when sent before `turn/started`; the UI now waits for the notification before exposing Stop.
- Approval approve-once serialization and controller behavior are covered by tests, but no real command or file mutation was approved during automated validation. The real smoke deliberately validated rejection only; Human approval UX remains a separate gate.
- The dangerous execution-setting confirmation dialogs and populated diff view have not received Human visual/interaction acceptance. Their protocol/controller/parser behavior is machine-tested, and the main GUI surface was directly inspected, but those are distinct claims.
- Stock app-server `0.166.0-alpha.5.1` does expose experimental
  `thread/items/read` for 1–100 item IDs, correcting the earlier project note that
  no per-item request existed. It still has no byte-range API and embeds the
  selected command's complete `aggregatedOutput` in one JSON response. Current
  upstream main can defer completed successful command output in
  `thread/items/list`, but the follow-up read is still whole-item. The Host can
  bound its own and Flutter's handling; it cannot remove app-server's preceding
  full-string serialization allocation.
- The 3/30/300 MiB memory gate uses a purpose-built serializer-shaped fixture,
  not a real Codex thread containing a 300 MiB command result. Its strong
  sublinear Host/Dart evidence does not establish real app-server RSS, Windows or
  macOS allocator behavior, real installed-filesystem exhaustion/recovery, or
  Human log-viewer acceptance. Linux `/dev/full` output failure and invalid or
  unwritable cache startup are now deterministic gates, but are not equivalent
  to filling each supported platform's installed cache volume.
- `thread/items/read` requires the negotiated experimental API capability in the
  installed server. Protocol adapters and tests cover this version, but future
  schema changes remain a compatibility risk.
- macOS App Sandbox was deliberately removed because all Codex child processes
  inherit the parent sandbox and cannot reproduce ordinary workspace/toolchain
  access. Developer ID signing, hardened-runtime nested Host signing,
  notarization, workspace access, and cleanup require a real macOS release gate.
- Unix spool directories/files are explicitly restricted to `0700`/`0600`.
  Windows current-user-only DACL creation/migration and native regression tests
  are hosted Windows Server 2022 verified. Operator TLS keys now have a bounded
  no-follow/owner/mode gate plus a hosted-Windows-verified protected-owner/DACL
  gate and a hosted-macOS-verified no-extended-ACL gate; installed-service,
  parent-directory custody, and installer validation remain separate. Universal
  Host construction and extracted verification are now hosted-macOS verified;
  physical Intel execution remains a separate cross-platform gate.
- Exact repeated complete output now reuses one session-scoped spool object.
  Unique outputs still remain until Host shutdown under the 2 GiB byte and
  16,384-object session caps; there is deliberately no public release operation
  because current history, dialog, and Remote projections do not have exclusive
  descriptor ownership.
  Duplicate ingest must still stream/hash the complete logical value and may
  write a bounded `.part` before its digest is known. Same-size external
  mutation is not checksummed as a persistent-cache threat because the store is
  private and session-scoped.
- The post-fidelity real GUI launch still logged GTK/Wayland warnings for ATK
  socket embedding and a missing cursor-theme asset. They did not prevent the
  window, live stock-app-server handshake, project/thread hydration, screenshot
  inspection, or child cleanup. Linux Human review and installed-build
  accessibility/cursor-theme validation remain separate gates.
- Live thread validation established three upstream lifecycle constraints: an ephemeral empty thread has no readable rollout; a new persistent empty thread is also unreadable until its first turn materializes a rollout; and resuming a thread owned by another app-server fails with `already has an active writer`. The UI/controller must not treat those cases as generic transient retries.
- A prior GUI run after loading thread state did not exit within the 3-second
  stdin-EOF window or the following 3-second SIGTERM window; SIGKILL completed at
  about 6.1 seconds and no child survived. Current release runtime/thread/coding
  smokes closed in 108/58/63 ms and a freshly packaged runtime smoke closed in
  32 ms; none reproduced the fallback. Preserve the earlier negative result and
  recheck during installed-build/platform soak, but do not present it as current
  deterministic latency.
- The app-server protocol evolves; version differences must stay inside typed protocol adapters.
- The loopback Remote Codex path currently depends on the local desktop client
  completing the one stock app-server initialize/initialized handshake. It does
  not yet define a headless Host lifecycle. Sanitized synthetic/TCP gates prove
  event publication and replay, but the current real stock-app-server smoke does
  not start a turn and therefore does not prove a live stock turn notification.
- Operator-provided WSS is implemented and same-host release-tested, but the test
  connected through loopback to a wildcard listener. Real LAN routing, host
  firewall discovery, CA chain/renewal under installed service accounts, Windows
  and macOS installed-service key custody, parent-directory custody, Android
  platform trust, background reconnect, and pairing-bound self-signed identity
  remain unverified. No Android code accepts arbitrary bad certificates.
- Long-running sessions must not cause Flutter to hydrate unbounded history.
  Turn/item/live-entry/output-window/Markdown caps and Linux synthetic memory
  evidence now exist, but real app-server RSS and cross-platform installed-build
  profiling remain required Phase 3 evidence.

## Next action

`DESKTOP_SHARED_CONVERSATION_FOUNDATION_RECALIBRATED — HUMAN_REVIEW_REQUIRED` (`Mode: HUMAN_REVIEW`).

- **LOCAL MACHINE VERIFIED**:
  - `dart format --output=none --set-exit-if-changed lib test tool` (`130` files, `0` changed);
  - `dart analyze` (`0` issues);
  - `flutter test` (`196/196` unit and widget tests passing, including new regressions for deep-history bookmark reset beyond `_maxRestorePages = 10`, protocol-boundary `HistoryItem.attachments` normalization/caps/deduplication, prose false-positive & quoted-preview delimiter spoofing defenses, literal `&#x20;` preservation, and `_RenderConversationViewport` global transformed `SemanticsNode` rect + `SelectableText` selection);
  - `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`, and `cargo test --workspace` (`98/98` Rust tests passing);
  - `flutter test tool/history_memory_benchmark.dart` (`HISTORY_MEMORY_BENCHMARK=PASS`, `SOURCE_TURNS=1000`, `RETAINED_TURNS=100`, `RSS_TURN_DELTA=1773568`);
  - `flutter build linux --debug` (`build/linux/x64/debug/bundle/codex_native_unofficial`).
- **HOSTED CI VERIFIED**:
  - Hosted GitHub Actions `CI` workflow (`verify`, `windows`, `macos` jobs) on `origin/main` passing `dart format --output=none --set-exit-if-changed lib test tool`, `flutter analyze`, `flutter test`, `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`, Linux/Windows/macOS desktop bundle builds, and Android debug APK gates.
- **AGENT REAL-USE VERIFIED**:
  - End-to-end live Linux desktop walkthrough of `build/linux/x64/debug/bundle/codex_native_unofficial` against `/opt/codex-desktop/resources/codex` and real user threads `<real-long-thread>` (`>140` turns, `287,442.9 px` scroll extent) and `<real-attachment-thread>` (`6` turns with pasted-file attachments), verifying `0.000 px` visual drift across `open latest -> scroll older (Pages 2..5) -> cross >100-turn boundary (Page 6) -> Jump to latest -> switch thread & attachment presentation -> return & multi-page content-identity scroll restoration -> streaming while scrolled up & at latest`, followed by clean process tree shutdown (`ALL_CLEAN`).
- **HUMAN REVIEWED**:
  - Prior revision `7f220d5` was reviewed by the user on Linux (`ADR-029`), `17f08f3` / `99e6141` were reviewed to authorize `ADR-032` (`683d431`), and `cb684b5` was reviewed to authorize this **Desktop Shared Conversation Foundation Correction & Evidence Tightening** recalibration.
- **NOT YET HUMAN VERIFIED**:
  - Interactive Human review and acceptance of the recalibrated Desktop conversation timeline (`16.A`–`16.E` + P1/P2 boundary hardening) across daily-use long-session workflows, dark/light visual comfort, live approve-once interaction, and native Windows/macOS interactive desktop review.

Wait for Human review and an explicit instruction before starting any next product phase.

## Milestone outline

### Phase 1 — Local vertical slice

- Flutter project: complete.
- Process transport and app-server handshake: complete and locally verified.
- Typed initialization/runtime UI: complete and locally verified.
- Tests and local Linux build: complete and locally verified.
- Hosted CI: latest completed code-bearing run `42135777838` at `4d35b56`
  passed exact-Rust, Dart/Flutter, Linux, Android debug, Windows x64, and macOS
  universal gates, including all 98 native tests on every desktop OS, hosted
  Flutter analysis/tests, the Linux runtime closure, the debug APK, and packaged
  Host/license execution.

### Phase 2 — Local Codex workflow

- thread list/start/read/resume metadata: complete and locally verified;
- turn start, streaming events, completion/failure/cancellation: complete and locally verified;
- bounded live conversation projection: complete and locally verified;
- approvals, execution controls, and basic bounded diff/task state: complete and locally verified, with Human approve-once interaction pending;
- one real small coding task completed through production client controllers: complete and locally verified.

### Phase 3 — Bounded-memory UX

- paged turns/items, virtualized timeline, coalesced streaming, lazy tool output/diff/file content, bounded caches, inactive-thread eviction, and stress evidence.

### Phase 4 — Android remote

- host bridge, pairing/device identity, authenticated WebSocket, event sequence + ACK/resume, notifications/approvals, and chunked transfer.

### Phase 5 — Ecosystem

- Skills, MCP, Plugins, optional isolated plugin WebView, tablet UX, and multi-host support.
