# Project Status

_Last updated: 2026-11-05_

This file is the repository's durable project memory. Update it whenever a task materially changes implementation status, milestones, known blockers, or the next recommended step.

## Current phase

**Phase 1 — Flutter + Codex app-server vertical slice: IMPLEMENTED, VERIFIED, COMMITTED (`5089320`)**

**Phase 2 — Local usable Codex client: IN PROGRESS — thread, turn, streaming, interruption, and approval-rejection slices locally verified**

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
- The desktop UI now provides a virtualized recent-activity timeline, composer, race-safe stop action, and pending-approval banner. Stored turn pagination, model controls, diffs, and Android remote control are not implemented yet.
- Lightweight GitHub Actions CI is configured for format, analyze, tests, and a Linux debug build. Hosted CI has not run for the local Phase 1 commit yet.

## Completed

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
- `flutter test --reporter expanded`: PASS, 37 tests.
- `flutter build linux --debug`: PASS.
- `dart run tool/runtime_smoke.dart`: PASS against the installed stock Codex; the initialize response identified Codex Desktop/app-server `0.166.0-alpha.5.1`.
- `dart run tool/thread_smoke.dart`: PASS against the installed stock Codex; listed 10 oldest threads, read and resumed an existing inactive thread without turns, started a smoke-owned persistent thread, and deleted that exact test thread.
- `dart run tool/turn_smoke.dart`: PASS against the installed stock Codex; a fixed-response turn completed with the expected marker, a second turn reached `turn/started`, interruption completed with status `interrupted`, and the smoke-owned thread was deleted.
- `dart run tool/approval_smoke.dart`: PASS against the installed stock Codex; an untrusted command produced a typed approval, the client rejected it, the turn completed, and the smoke-owned thread was deleted without executing the command.
- Real Linux GUI launch after the conversation slice: PASS; the connected runtime, thread list, and empty conversation state rendered correctly in direct inspection. SIGINT produced a coordinated exit, and neither the Flutter process nor its app-server child survived.
- Secret/credential scan: PASS; no token, private-key, bearer, or assigned credential patterns found in the repository scope.
- Hosted GitHub Actions CI: NOT RUN for the local changes.
- Windows/macOS/Android builds and physical-device validation: NOT RUN in this Linux environment.

## Known risks / watch items

- Direct `flutter analyze` from this repository's Unicode filesystem path currently crashes Flutter 3.47.1's LSP byte-stream parser with a truncated initialization JSON message. The same source passes `dart analyze --fatal-infos` at the real path and `flutter analyze` through an ASCII symlink. This is preserved as a toolchain/path issue, not recorded as a clean direct-path run.
- A successful `turn/start` response does not prove the server has installed the turn as interruptible. Real validation observed `turn/interrupt` fail with `-32600` when sent before `turn/started`; the UI now waits for the notification before exposing Stop.
- Approval approve-once serialization and controller behavior are covered by tests, but no real command or file mutation was approved during automated validation. The real smoke deliberately validated rejection only; Human approval UX remains a separate gate.
- The real GUI launch logged host GTK/Wayland warnings for ATK socket embedding and a missing cursor-theme asset. They did not prevent the window, handshake, or child cleanup, but should be rechecked during later Linux UI work.
- Live thread validation established three upstream lifecycle constraints: an ephemeral empty thread has no readable rollout; a new persistent empty thread is also unreadable until its first turn materializes a rollout; and resuming a thread owned by another app-server fails with `already has an active writer`. The UI/controller must not treat those cases as generic transient retries.
- After loading thread state, the tested stock app-server did not exit within the 3-second stdin-EOF window or the following 3-second SIGTERM window. The SIGKILL fallback completed at about 6.1 seconds and no child survived GUI exit. Shutdown is bounded and correct, but the latency/source should be investigated before release polish.
- The app-server protocol evolves; version differences must stay inside typed protocol adapters.
- Long-running sessions must not cause Flutter to hydrate unbounded history. Phase 2 must introduce metadata/page boundaries before conversation state grows.

## Next action

Continue Phase 2 with model/sandbox controls and a basic lazy diff surface:

1. query supported models/configuration from app-server rather than hardcoding model names;
2. keep model, reasoning effort, sandbox, and approval choices typed and pass them only through supported thread/turn request fields;
3. project file-change events into changed-file metadata without retaining entire patches in the timeline;
4. load one selected file diff on demand with strict size bounds;
5. complete one small real coding-task smoke through the client path, including a Human-approved mutation if approval is required.

Do not begin Android remote transport or ecosystem management until the full local coding-task gate is satisfied.

## Milestone outline

### Phase 1 — Local vertical slice

- Flutter project: complete.
- Process transport and app-server handshake: complete and locally verified.
- Typed initialization/runtime UI: complete and locally verified.
- Tests and local Linux build: complete and locally verified.
- Hosted CI: configured, not yet run.

### Phase 2 — Local Codex workflow

- thread list/start/read/resume metadata;
- turn start, streaming events, completion/failure/cancellation;
- bounded conversation projection;
- approvals and basic diff/task state;
- one real small coding task completed through this client.

### Phase 3 — Bounded-memory UX

- paged turns/items, virtualized timeline, coalesced streaming, lazy tool output/diff/file content, bounded caches, inactive-thread eviction, and stress evidence.

### Phase 4 — Android remote

- host bridge, pairing/device identity, authenticated WebSocket, event sequence + ACK/resume, notifications/approvals, and chunked transfer.

### Phase 5 — Ecosystem

- Skills, MCP, Plugins, optional isolated plugin WebView, tablet UX, and multi-host support.
