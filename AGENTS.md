# AGENTS.md

## Repository memory

Before starting any non-trivial task:

1. Read `PROJECT_STATUS.md` for the current phase, completed work, blockers, and next action.
2. Read `docs/DECISIONS.md` for accepted architecture decisions.
3. Read `docs/ARCHITECTURE.md` when the task touches system boundaries, transports, memory behavior, or remote design.

Before finishing any task that materially changes the repository:

- Update `PROJECT_STATUS.md` with what changed, current status, new blockers, and the next recommended action.
- If you make or reverse a durable architecture/product decision, append an ADR entry to `docs/DECISIONS.md`.
- Keep status factual. Do not mark work complete unless it is implemented and, where applicable, tested.
- Include the relevant commit/test result in the status entry when useful.

## Project intent

Build an unofficial native-first client for OpenAI Codex. The client must reuse the stock `codex app-server` and preserve the Codex harness rather than reimplementing an agent.

## Primary stack

- Flutter / Dart for desktop and Android UI.
- Stock `codex app-server` as the local Codex runtime.
- Desktop local transport: child process + stdio newline-delimited JSON.
- Android remote transport: authenticated resumable WebSocket to a host bridge.
- `flutter_rust_bridge` is not part of the initial architecture. It may be explored later only as an optional embedded transport if measurements justify it.

## Non-negotiable architecture rules

1. **Codex owns intelligence; the client owns presentation.**
   - Do not copy or fork Codex system prompts into the client.
   - Do not implement client-side context compaction for Native/Fidelity mode.
   - Do not replace Codex tool schemas or agent-loop semantics.

2. **UI state is a bounded projection, never the source of truth.**
   - Never hydrate an entire long thread into Flutter state by default.
   - Paginate thread/turn/item history.
   - Virtualize long lists.
   - Load large command output, diffs, logs, and files on demand.
   - Inactive threads should have near-zero UI memory cost.

3. **Keep the Codex runtime isolated by default.**
   - Desktop should spawn the user's/packaged stock `codex app-server` process.
   - A Codex crash or restart must not require restarting the UI.
   - Preserve thread IDs so sessions can be resumed after runtime restart.

4. **Remote is a first-class product surface.**
   - Android should not run the full Codex runtime by default.
   - OpenAI/Codex credentials stay on the host.
   - Pair devices explicitly.
   - Remote protocol must support reconnect/resume using sequence/ack semantics.
   - Large payloads must use chunking/streaming rather than giant RPC messages.

5. **No Electron or Node requirement for the core client.**
   - Optional plugin web UI may use a system/embedded WebView later, only when required.

## Bootstrap task

Initialize a clean Flutter project suitable for Linux, Windows, macOS, and Android. Use a Dart package/application identifier compatible with this repository name (for example `codex_native_unofficial`).

Create an architecture that separates UI/domain state from transport:

```text
lib/
  src/
    app/
    domain/
    protocol/
    transport/
      process/
      remote/
    features/
      threads/
      conversation/
      approvals/
      diff/
      settings/
```

The first working milestone should:

- launch on desktop;
- locate a `codex` executable without hardcoding a developer machine path;
- spawn `codex app-server --listen stdio://`;
- perform the app-server initialization handshake;
- expose connection/runtime status in the UI;
- implement a typed protocol adapter so widgets never consume raw JSON directly;
- shut down the child process cleanly;
- include unit tests for JSONL framing and request/response correlation;
- pass `flutter analyze` and `flutter test`.

Do not implement the full chat UI, remote host, plugin system, or FRB embedding in the bootstrap commit. Establish clean boundaries first.

## Performance rules

- Avoid unbounded in-memory event/history collections.
- Streaming text updates should be coalesced so every token does not trigger an expensive full-tree rebuild.
- Never render multi-megabyte command output inside the main conversation timeline.
- Diff views must support file/hunk-level lazy loading.
- Prefer measurable optimizations over speculative FFI work.

## Compatibility and upstream

- Treat the app-server protocol as the stable integration boundary.
- Isolate protocol-version differences inside adapters.
- Do not make the Flutter UI depend directly on internal Codex Rust crates.
- Keep it possible to swap between local process transport and remote transport without changing feature/domain code.

## Licensing and branding

- Project license: Apache-2.0.
- Preserve third-party notices when bundling upstream components.
- Clearly describe the project as unofficial and not endorsed by OpenAI.
