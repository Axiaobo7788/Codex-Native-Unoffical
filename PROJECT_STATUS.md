# Project Status

_Last updated: 2026-11-05_

This file is the repository's durable project memory. Update it whenever a task materially changes implementation status, milestones, known blockers, or the next recommended step.

## Current phase

**Phase 1 — Flutter + Codex app-server vertical slice: IMPLEMENTED, VERIFIED, COMMITTED (`5089320`)**

**Phase 2 — Local usable Codex client: IMPLEMENTED AND LOCALLY MACHINE-VERIFIED — Human approval interaction and hosted CI remain separate gates**

**Phase 3 — Bounded-memory long-session UX: IN PROGRESS — paginated history, bounded native command-output viewing, and safe lazy assistant Markdown are integrated and Linux-measured; cross-platform and Human gates remain**

## Current repository state

- Flutter application shells exist for Linux, Windows, macOS, and Android under the Dart package `codex_native_unofficial`.
- Desktop runtime flow is real, not mocked:
  - locate `codex` through `CODEX_EXECUTABLE` or `PATH`;
  - spawn stock `codex app-server --listen stdio://`;
  - decode fragmented/multiple JSONL messages;
  - correlate JSON-RPC requests and responses;
  - perform `initialize` followed by `initialized`;
  - surface typed runtime status to Flutter widgets;
  - capture a bounded stderr tail, report malformed protocol data and process exits, and close the child without leaving an orphan.
- `CodexTransport` isolates feature/domain code from the process implementation so a later `RemoteTransport` can preserve the same boundary.
- Typed thread operations now cover bounded `thread/list`, `thread/start`, metadata-only `thread/read`, history-excluding `thread/resume`, and exact-ID delete for smoke-test cleanup.
- The desktop UI lists at most 100 thread metadata rows, paginates with opaque server cursors, accepts a working directory for new threads, and exposes select/resume actions. It does not retain turns or raw protocol JSON.
- Typed turn operations cover `turn/start`, `turn/interrupt`, lifecycle, assistant text, bounded activity summaries, terminal errors, and completion states without client prompt rewriting.
- The conversation projection retains at most 200 recent entries and 64 KiB per entry, coalesces streaming updates on a 50 ms cadence, and never retains command output payloads.
- Command/file-change approvals support explicit approve-once and reject responses. Unknown and unsupported server requests fail closed and cannot expose an approve action. The real reject path is verified; approve-once is currently unit-tested but not Human-validated.
- `model/list` drives typed visible-model and reasoning-effort controls. Model, effort, approval, and sandbox overrides are omitted by default; `never` approval and `danger-full-access` require an explicit UI confirmation.
- Turn diff notifications are converted immediately into a bounded typed projection: at most 2 MiB processed input, 100 files, 512 KiB retained total, 128 KiB and 4,000 lines per file, and 2,000 characters per retained line. Only the selected file's rows are built by the diff view.
- The desktop UI now provides a virtualized recent-activity timeline, composer, race-safe stop action, pending-approval banner, execution settings, changed-file summary, and selected-file diff.
- A real small coding task completed through the production Runtime, Conversation, and Diff controllers in a dedicated temporary workspace; it modified exactly one requested file, projected the diff, completed the turn, and cleaned its thread/workspace.
- Stored history uses `thread/turns/list` with `itemsView:summary` and opaque descending cursors. The UI retains a sliding window of at most 100 turns and can return directly to the newest page.
- The typed history layer loads ascending `thread/items/list` pages for exactly
  one user-selected turn with a 100-item cap. Large `aggregatedOutput` fields are
  removed by the Host before Dart decoding, and switching threads discards all
  stored-history state immediately.
- Stored and live entries are merged by item ID into one virtualized list so a resumed active turn does not render duplicate items.
- `codex-native-host` now supervises stock app-server by default, validates
  stdout incrementally without line buffering, spools decoded
  `aggregatedOutput` values behind opaque references, replaces them with bounded
  descriptors, and implements capped `host/status`, `stat`, `readRange`, and
  `tail` RPCs. Flutter locates Codex and the bundled Host independently and has
  no silent direct-app-server fallback.
- Historical command rows load full items for only one selected turn. List
  requests prefer upstream output deferral; a deferred selected item uses the
  gated `thread/items/read` API, whose response is still sanitized by the Host.
  The log dialog retains one approximately 64 KiB byte window, uses bounded
  first/previous/next/tail reads, preserves UTF-8 page edges, and virtualizes
  display rows.
- Linux and Windows native builds compile/package the Host beside the app.
  macOS embeds and signs it in `Contents/MacOS`; v1 macOS is a direct notarized
  distribution because App Sandbox cannot preserve the required normal Codex
  developer-workspace/toolchain model. Windows/macOS builds are not verified in
  this Linux environment.
- Completed assistant messages use a project-owned safe Markdown allowlist only
  while in-progress streaming remains selectable plain text. Raw HTML is inert,
  images never load, links require an explicit click and absolute `http`/`https`
  URI, and rich parsing falls back to a bounded plain-text tail above 16 KiB.
  The outer virtualized timeline controls widget construction and no global AST
  cache retains inactive messages.
- Cross-platform RSS/runtime evidence and Human interaction acceptance are not
  complete yet. Android remote control remains Phase 4 work.
- Lightweight GitHub Actions CI is configured for Dart/Rust format, analyze,
  Clippy, tests, and a Linux debug build. Hosted CI has not run for the current
  local commits.

## Completed

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

All results below are from 2026-11-05 on Manjaro Linux x86_64 with Flutter 3.47.1 and Codex `0.166.0-alpha.5.1`.

- `dart format lib test tool`: PASS.
- `dart analyze --fatal-infos`: PASS, no issues.
- `flutter analyze --no-pub <ASCII symlink argument from an ASCII working directory>`: PASS, no issues. Running from the symlink as the process working directory still resolves the Unicode real path and reproduces the known LSP truncation failure.
- `flutter test --reporter expanded`: PASS, 72 tests.
- `flutter build linux --debug`: PASS.
- `dart run tool/runtime_smoke.dart`: PASS against the installed stock Codex; the initialize response identified Codex Desktop/app-server `0.166.0-alpha.5.1`.
- `dart run tool/thread_smoke.dart`: PASS against the installed stock Codex; listed 10 oldest threads, read and resumed an existing inactive thread without turns, started a smoke-owned persistent thread, and deleted that exact test thread.
- `dart run tool/turn_smoke.dart`: PASS against the installed stock Codex; a fixed-response turn completed with the expected marker, a second turn reached `turn/started`, interruption completed with status `interrupted`, and the smoke-owned thread was deleted.
- `dart run tool/approval_smoke.dart`: PASS against the installed stock Codex; an untrusted command produced a typed approval, the client rejected it, the turn completed, and the smoke-owned thread was deleted without executing the command.
- `dart run tool/model_smoke.dart`: PASS; the installed app-server advertised 8 visible models, identified `gpt-6.1-sol` as default, and advertised `low` as its default reasoning effort.
- `flutter test tool/coding_task_smoke.dart --reporter expanded`: PASS after history integration in 29 seconds; production controllers completed the exact temporary-file task, projected one changed file/one addition, observed zero approvals, paged back one turn/nine items, and cleaned both thread and workspace.
- `flutter test tool/history_memory_benchmark.dart --reporter expanded`: PASS twice; 1,000 source turns retained 100. RSS deltas were 1,482,752/1,564,672 bytes for turn paging and 29,085,696/31,879,168 bytes for ten sequential 3 MiB discarded outputs. These are Linux debug-test measurements, not cross-platform guarantees.
- `cargo fmt --all -- --check`: PASS.
- `cargo clippy --workspace --all-targets -- -D warnings`: PASS.
- `cargo test --workspace`: PASS, 19 tests.
- `cargo build --release --workspace`: PASS.
- Release `codex-native-host` real-runtime smoke: PASS; one process carried a
  Host status request plus stock app-server initialize/initialized and reported
  Codex Desktop/app-server `0.166.0-alpha.5.1`. This isolated smoke established
  the handshake and clean EOF shutdown before Flutter integration.
- `dart run tool/host_memory_benchmark.dart`: PASS three times for 3/30/300 MiB.
  Fixture deltas were 6,303,744/62,926,848/629,157,888,
  6,303,744/62,926,848/629,157,888, and
  6,299,648/62,922,752/629,153,792 bytes; Host deltas were 0/0/0 bytes at 2 ms
  sampling; Dart deltas were 57,344/774,144/2,281,472,
  36,864/765,952/4,431,872, and 49,152/630,784/2,211,840 bytes. First/tail reads
  matched the complete spooled payload in every case.
- `flutter build linux --debug` and `flutter build linux --release`: PASS with
  an executable packaged `codex-native-host` beside the Flutter binary and the
  native URL-launcher plugin.
- `flutter build apk --debug` from the real Unicode repository/SDK path: FAILED
  before compilation because `android/settings.gradle.kts` observed the SDK as
  `/home/axiaobo/ææ¡£/flutter`. With only the ignored
  `android/local.properties` temporarily pointed at an exact ASCII symlink,
  `./gradlew assembleDebug` passed 87 actionable tasks and produced a 145 MiB
  debug APK with arm64-v8a, armeabi-v7a, and x86_64 native outputs. The file and
  symlink were restored/removed afterward. This proves the Android product and
  plugin build under the path workaround, not a clean ordinary-path build.
- Packaged Linux GUI runtime launch: PASS; direct process inspection showed
  Flutter -> adjacent bundled Host -> separately located stock Codex. SIGINT
  removed all three processes. Existing ATK/cursor-theme warnings remained.
- Host-routed `runtime_smoke`, `thread_smoke`, `model_smoke`, `turn_smoke`, and
  `approval_smoke`: PASS. The approval smoke rejected rather than approved its
  command as designed.
- Enhanced `coding_task_smoke`: first run FAILED at the newly exercised
  `thread/items/read` capability gate; after declaring `experimentalApi`, rerun
  PASS in 27 seconds with 11 history items and a verified 7,443-byte Host output
  spool/tail.
- Final packaged-release reruns after strict output reference/range/EOF
  validation: PASS in 21/27 seconds with 9/10 history items, readable 6-byte
  selected command outputs, and exact test thread/workspace cleanup.
- Real Linux GUI launch after the model/diff slice: PASS; the connected runtime, thread list, empty conversation state, and loaded `Defaults` execution-control entry rendered correctly in direct inspection. SIGINT produced a coordinated exit, and neither the Flutter process nor its app-server child survived.
- Secret/credential scan: PASS; no token, private-key, bearer, or assigned credential patterns found in the repository scope.
- Hosted GitHub Actions CI: NOT RUN for the local changes.
- Windows/macOS builds and physical-device validation: NOT RUN in this Linux environment.

## Known risks / watch items

- Direct `flutter analyze` from this repository's Unicode filesystem path currently crashes Flutter 3.47.1's LSP byte-stream parser with a truncated initialization JSON message. The same source passes `dart analyze --fatal-infos` at the real path and `flutter analyze` through an ASCII symlink. This is preserved as a toolchain/path issue, not recorded as a clean direct-path run.
- The same Unicode-path toolchain defect affects Android settings evaluation:
  ordinary `flutter build apk --debug` corrupts the Flutter SDK path before
  compilation. A temporary ASCII SDK alias proves `assembleDebug` itself passes,
  but the normal developer command is still blocked on this filesystem layout.
  The passing build also reported Gradle-10/AGP-9 migration warnings, an ignored
  legacy manifest `package` attribute in `url_launcher_android`, and an Android
  SDK XML version skew; none was promoted to a clean warning-free gate.
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
  macOS allocator behavior, disk-full recovery in an installed bundle, or Human
  log-viewer acceptance.
- `thread/items/read` requires the negotiated experimental API capability in the
  installed server. Protocol adapters and tests cover this version, but future
  schema changes remain a compatibility risk.
- macOS App Sandbox was deliberately removed because all Codex child processes
  inherit the parent sandbox and cannot reproduce ordinary workspace/toolchain
  access. Developer ID signing, hardened-runtime nested Host signing,
  notarization, workspace access, and cleanup require a real macOS release gate.
- Unix spool directories/files are explicitly restricted to `0700`/`0600`.
  Windows currently relies on the user cache directory's inherited ACL; a real
  Windows gate must inspect it and add an explicit owner-only ACL if inheritance
  is not sufficiently restrictive. The current macOS Cargo phase also produces
  only the active build architecture, not a universal Host binary.
- Re-reading the same upstream command item creates another session-scoped spool
  object. The 2 GiB session cap prevents unbounded disk growth and UI actions do
  not automatically reread a loaded item, but deduplication or explicit release
  remains unresolved for very long sessions.
- The real GUI launch logged host GTK/Wayland warnings for ATK socket embedding and a missing cursor-theme asset. They did not prevent the window, handshake, or child cleanup, but should be rechecked during later Linux UI work.
- Live thread validation established three upstream lifecycle constraints: an ephemeral empty thread has no readable rollout; a new persistent empty thread is also unreadable until its first turn materializes a rollout; and resuming a thread owned by another app-server fails with `already has an active writer`. The UI/controller must not treat those cases as generic transient retries.
- After loading thread state, the tested stock app-server did not exit within the 3-second stdin-EOF window or the following 3-second SIGTERM window. The SIGKILL fallback completed at about 6.1 seconds and no child survived GUI exit. Shutdown is bounded and correct, but the latency/source should be investigated before release polish.
- The app-server protocol evolves; version differences must stay inside typed protocol adapters.
- Long-running sessions must not cause Flutter to hydrate unbounded history.
  Turn/item/live-entry/output-window/Markdown caps and Linux synthetic memory
  evidence now exist, but real app-server RSS and cross-platform installed-build
  profiling remain required Phase 3 evidence.

## Next action

Continue Phase 3 with the remaining presentation and platform gates:

1. obtain Human visual/interaction acceptance for populated range-backed logs,
   truncated output, large diffs, dangerous settings, and Markdown selection/link
   behavior; their production-App machine gates now pass;
2. run Windows and macOS native builds plus packaged process/output/lifecycle RSS
   gates; on macOS also validate nested signing, notarization, ordinary workspace
   access, and no surviving child;
3. exercise disk-full/unwritable-cache behavior end to end and investigate the
   stock app-server's observed six-second shutdown fallback before RC.

Do not begin Android remote transport or ecosystem management until the remaining
Phase 3 RC gates are exhausted or require unavailable platform/Human evidence.

## Milestone outline

### Phase 1 — Local vertical slice

- Flutter project: complete.
- Process transport and app-server handshake: complete and locally verified.
- Typed initialization/runtime UI: complete and locally verified.
- Tests and local Linux build: complete and locally verified.
- Hosted CI: configured, not yet run.

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
