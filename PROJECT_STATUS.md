# Project Status

_Last updated: 2026-11-05_

This file is the repository's durable project memory. Update it whenever a task materially changes implementation status, milestones, known blockers, or the next recommended step.

## Current phase

**Phase 1 — Flutter + Codex app-server vertical slice: IMPLEMENTED, VERIFIED, COMMITTED (`5089320`)**

**Phase 2 — Local usable Codex client: IMPLEMENTED AND LOCALLY MACHINE-VERIFIED — Human approval interaction and hosted CI remain separate gates**

**Phase 3 — Bounded-memory long-session UX: IN PROGRESS — paginated stored turns/items and inactive-thread eviction locally verified**

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
- The typed history layer can load ascending `thread/items/list` pages for exactly one turn with a 100-item cap, and the real smoke verifies it. The production UI intentionally does not expose that full-item action yet because one command item can contain unbounded `aggregatedOutput`. Switching threads discards all stored-history state immediately.
- Stored and live entries are merged by item ID into one virtualized list so a resumed active turn does not render duplicate items.
- Lazy full command-output retrieval, Markdown parsing policy, log viewer, and measured process-memory evidence are not implemented yet. Android remote control remains Phase 4 work.
- Lightweight GitHub Actions CI is configured for format, analyze, tests, and a Linux debug build. Hosted CI has not run for the local Phase 1 commit yet.

## Completed

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
- `flutter test --reporter expanded`: PASS, 51 tests.
- `flutter build linux --debug`: PASS.
- `dart run tool/runtime_smoke.dart`: PASS against the installed stock Codex; the initialize response identified Codex Desktop/app-server `0.166.0-alpha.5.1`.
- `dart run tool/thread_smoke.dart`: PASS against the installed stock Codex; listed 10 oldest threads, read and resumed an existing inactive thread without turns, started a smoke-owned persistent thread, and deleted that exact test thread.
- `dart run tool/turn_smoke.dart`: PASS against the installed stock Codex; a fixed-response turn completed with the expected marker, a second turn reached `turn/started`, interruption completed with status `interrupted`, and the smoke-owned thread was deleted.
- `dart run tool/approval_smoke.dart`: PASS against the installed stock Codex; an untrusted command produced a typed approval, the client rejected it, the turn completed, and the smoke-owned thread was deleted without executing the command.
- `dart run tool/model_smoke.dart`: PASS; the installed app-server advertised 8 visible models, identified `gpt-6.1-sol` as default, and advertised `low` as its default reasoning effort.
- `flutter test tool/coding_task_smoke.dart --reporter expanded`: PASS after history integration in 29 seconds; production controllers completed the exact temporary-file task, projected one changed file/one addition, observed zero approvals, paged back one turn/nine items, and cleaned both thread and workspace.
- `flutter test tool/history_memory_benchmark.dart --reporter expanded`: PASS twice; 1,000 source turns retained 100. RSS deltas were 1,482,752/1,564,672 bytes for turn paging and 29,085,696/31,879,168 bytes for ten sequential 3 MiB discarded outputs. These are Linux debug-test measurements, not cross-platform guarantees.
- Real Linux GUI launch after the model/diff slice: PASS; the connected runtime, thread list, empty conversation state, and loaded `Defaults` execution-control entry rendered correctly in direct inspection. SIGINT produced a coordinated exit, and neither the Flutter process nor its app-server child survived.
- Secret/credential scan: PASS; no token, private-key, bearer, or assigned credential patterns found in the repository scope.
- Hosted GitHub Actions CI: NOT RUN for the local changes.
- Windows/macOS/Android builds and physical-device validation: NOT RUN in this Linux environment.

## Known risks / watch items

- Direct `flutter analyze` from this repository's Unicode filesystem path currently crashes Flutter 3.47.1's LSP byte-stream parser with a truncated initialization JSON message. The same source passes `dart analyze --fatal-infos` at the real path and `flutter analyze` through an ASCII symlink. This is preserved as a toolchain/path issue, not recorded as a clean direct-path run.
- A successful `turn/start` response does not prove the server has installed the turn as interruptible. Real validation observed `turn/interrupt` fail with `-32600` when sent before `turn/started`; the UI now waits for the notification before exposing Stop.
- Approval approve-once serialization and controller behavior are covered by tests, but no real command or file mutation was approved during automated validation. The real smoke deliberately validated rejection only; Human approval UX remains a separate gate.
- The dangerous execution-setting confirmation dialogs and populated diff view have not received Human visual/interaction acceptance. Their protocol/controller/parser behavior is machine-tested, and the main GUI surface was directly inspected, but those are distinct claims.
- Stock app-server `0.166.0-alpha.5.1` exposes no per-item or byte-range history request for command output. `thread/items/list` returns a command's whole `aggregatedOutput` inside one JSON item. The client drops that field immediately, but cannot implement a genuinely lazy log viewer without transiently decoding the full payload. This is an upstream protocol blocker; do not claim lazy heavy-output loading until a bounded API exists.
- The real GUI launch logged host GTK/Wayland warnings for ATK socket embedding and a missing cursor-theme asset. They did not prevent the window, handshake, or child cleanup, but should be rechecked during later Linux UI work.
- Live thread validation established three upstream lifecycle constraints: an ephemeral empty thread has no readable rollout; a new persistent empty thread is also unreadable until its first turn materializes a rollout; and resuming a thread owned by another app-server fails with `already has an active writer`. The UI/controller must not treat those cases as generic transient retries.
- After loading thread state, the tested stock app-server did not exit within the 3-second stdin-EOF window or the following 3-second SIGTERM window. The SIGKILL fallback completed at about 6.1 seconds and no child survived GUI exit. Shutdown is bounded and correct, but the latency/source should be investigated before release polish.
- The app-server protocol evolves; version differences must stay inside typed protocol adapters.
- Long-running sessions must not cause Flutter to hydrate unbounded history. Turn/item caps now exist, but heavy-item retrieval and actual process-memory profiling remain required Phase 3 evidence.

## Next action

Continue Phase 3 with measured memory/rendering evidence around the supported protocol surface:

1. define lazy Markdown parsing for only visible assistant blocks and cache only the active window;
2. keep historical command output summarized/disabled with an explicit upstream-limitation message rather than invoking full-payload `thread/items/list` as a log viewer;
3. repeat RSS measurements on release builds and Windows/macOS to establish comparable baselines;
4. re-check newer stock app-server schemas periodically for an item/offset/byte-range output API.

Do not begin Android remote transport or ecosystem management until bounded stored-history behavior is implemented and measured.

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
