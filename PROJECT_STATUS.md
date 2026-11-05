# Project Status

_Last updated: 2026-11-05_

This file is the repository's durable project memory. Update it whenever a task materially changes implementation status, milestones, known blockers, or the next recommended step.

## Current phase

**Phase 0 — Repository bootstrap complete**  
**Phase 1 — Flutter + Codex app-server vertical slice: READY / NOT STARTED**

## Current repository state

- Public repository created.
- License: Apache-2.0.
- Project direction documented in `README.md`.
- Architecture constraints documented in `AGENTS.md` and `docs/ARCHITECTURE.md`.
- Bootstrap work is tracked in GitHub Issue #1:
  - Initialize Flutter for Linux, Windows, macOS, and Android.
  - Add desktop `ProcessTransport`.
  - Start stock `codex app-server --listen stdio://`.
  - Perform initialization handshake.
  - Add typed protocol adapter.
  - Add minimal runtime status UI.
  - Add JSONL/request-correlation tests.
  - Run `flutter analyze` and `flutter test`.

## Completed

### 2026-11-05

- Created repository.
- Selected Apache-2.0.
- Chose Flutter/Dart for the client UI.
- Chose stock `codex app-server` as the Codex runtime/harness boundary.
- Decided desktop v1 uses an isolated child process over stdio/JSONL.
- Decided Android is a remote control plane and should not run the full Codex runtime by default.
- Decided `flutter_rust_bridge` is not a v1 dependency.
- Added repository guidance and initial architecture documentation.
- Created Issue #1 for the first vertical slice.

## In progress

None yet.

## Next action

Implement GitHub Issue #1.

The preferred first implementation is intentionally narrow: establish a reliable typed connection to `codex app-server` before building conversation UI, remote transport, plugins, or rich diff views.

## Known risks / watch items

- Flutter Linux/Wayland frame pacing and NVIDIA-specific behavior should be tested early, but should not block the transport bootstrap.
- The app-server protocol may evolve. Protocol differences must remain isolated behind adapters.
- Long-running sessions must never cause the Flutter UI to hydrate unbounded thread history.
- The future Android remote layer must be designed around reconnect/resume rather than assuming a persistent socket.

## Milestone outline

### Phase 1 — Local vertical slice
- Flutter project
- Process transport
- app-server handshake
- typed protocol layer
- runtime status UI
- tests / CI

### Phase 2 — Local Codex workflow
- thread list/start/resume
- turn start
- streaming agent messages
- approvals
- basic diff/task state

### Phase 3 — Bounded-memory UX
- paged turns/items
- virtualized timeline
- lazy tool output
- lazy diff/file content
- inactive-thread eviction

### Phase 4 — Android remote
- host bridge
- pairing/device identity
- authenticated WebSocket
- event sequence + ACK/resume
- notifications/approvals
- chunked file transfer

### Phase 5 — Ecosystem
- Skills / MCP / Plugins management
- optional plugin WebView host
- tablet UX
- multi-host support
