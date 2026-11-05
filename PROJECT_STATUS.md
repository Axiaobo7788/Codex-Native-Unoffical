# Project Status

_Last updated: 2026-11-05_

This file is the repository's durable project memory. Update it whenever a task materially changes implementation status, milestones, known blockers, or the next recommended step.

## Current phase

**Phase 1 — Flutter + Codex app-server vertical slice: IMPLEMENTED AND LOCALLY VERIFIED**

**Phase 2 — Local usable Codex client: READY / NOT STARTED**

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
- The UI is intentionally limited to runtime status and uses centralized theme tokens. Conversation, threads, approvals, diffs, and Android remote control are not implemented yet.
- Lightweight GitHub Actions CI is configured for format, analyze, tests, and a Linux debug build. Hosted CI has not run for the local Phase 1 commit yet.

## Completed

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
- `flutter analyze --no-pub <ASCII symlink to repository>`: PASS, no issues.
- `flutter test --reporter expanded`: PASS, 11 tests.
- `flutter build linux --debug`: PASS.
- `dart run tool/runtime_smoke.dart`: PASS against the installed stock Codex; the initialize response identified Codex Desktop/app-server `0.166.0-alpha.5.1`.
- Real Linux GUI launch: PASS; the Flutter process spawned an app-server child, and the child was no longer alive after the GUI process exited.
- Secret/credential scan: PASS; no token, private-key, bearer, or assigned credential patterns found in the repository scope.
- Hosted GitHub Actions CI: NOT RUN for the local changes.
- Windows/macOS/Android builds and physical-device validation: NOT RUN in this Linux environment.

## Known risks / watch items

- Direct `flutter analyze` from this repository's Unicode filesystem path currently crashes Flutter 3.47.1's LSP byte-stream parser with a truncated initialization JSON message. The same source passes `dart analyze --fatal-infos` at the real path and `flutter analyze` through an ASCII symlink. This is preserved as a toolchain/path issue, not recorded as a clean direct-path run.
- The real GUI launch logged host GTK/Wayland warnings for ATK socket embedding and a missing cursor-theme asset. They did not prevent the window, handshake, or child cleanup, but should be rechecked during later Linux UI work.
- The app-server protocol evolves; version differences must stay inside typed protocol adapters.
- Long-running sessions must not cause Flutter to hydrate unbounded history. Phase 2 must introduce metadata/page boundaries before conversation state grows.

## Next action

Begin Phase 2 with the smallest usable local workflow:

1. add typed `thread/list`, `thread/start`, `thread/read`, and `thread/resume` protocol adapters with bounded page parameters;
2. expose thread metadata through a controller that does not retain complete history;
3. add a minimal thread list/start surface;
4. validate against the real stock app-server before adding turn streaming.

Do not begin full conversation UI, approvals, rich diffs, Android remote transport, or ecosystem management until the preceding vertical slice is real and tested.

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
