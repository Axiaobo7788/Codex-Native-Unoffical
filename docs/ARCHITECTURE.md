# Architecture

## Design principle

Codex Native is a presentation and remote-control client around the official Codex runtime. It should not become a competing agent harness.

```text
+------------------------+       +------------------------+
| Flutter Desktop        |       | Flutter Android        |
| bounded-memory UI      |       | mobile-first UI        |
+-----------+------------+       +-----------+------------+
            |                                |
      ProcessTransport                 RemoteTransport
       stdio / JSONL                resumable WebSocket
            |                                |
            v                                v
+------------------------+       +------------------------+
| stock codex app-server |<------| Host bridge            |
| Rust / Codex harness   |       | auth / resume / stream |
+-----------+------------+       +------------------------+
            |
            v
        OpenAI/Codex
```

## Transport boundary

All feature code talks to a typed `CodexTransport` abstraction.

Initial implementations:

- `ProcessTransport`: desktop child process using stdio/JSONL.
- `RemoteTransport`: Android/remote clients using an authenticated WebSocket protocol.

Possible future implementation:

- `EmbeddedTransport`: Rust in-process app-server reached through flutter_rust_bridge. Experimental only; it must preserve app-server semantics and is not a v1 requirement.

## Memory model

The app-server/thread store is authoritative. Flutter retains only the current working set.

- Thread list: metadata only.
- Active conversation: recent page(s) only.
- Old turns: fetched on scroll.
- Tool output: summary in timeline, full output on demand.
- Diff: file summary first, file/hunk content on demand.
- Inactive thread: unload UI models and caches.

The target is bounded UI memory even when a Codex session has accumulated very large historical context.

## Remote model

The phone is a control plane.

It can:

- create/resume/steer threads;
- approve or reject tool actions;
- inspect task state, diffs, and selected logs;
- receive completion/approval notifications;
- upload selected files/images.

It should not need the user's OpenAI credentials. Credentials remain on the host running Codex.

A robust remote protocol should eventually provide:

- pairing and device identity;
- encrypted authenticated transport;
- monotonically increasing event sequence numbers;
- ACK + resume from last acknowledged event;
- idempotent requests where practical;
- heartbeat and liveness detection;
- chunked/resumable file transfer;
- explicit protocol version negotiation.

## Fidelity mode

The default mode should keep Codex-native behavior:

- user input and explicit attachments only;
- stock Codex prompts and tool behavior;
- stock context/compaction behavior;
- stock model and reasoning controls.

Custom workflows can be added later as opt-in extensions, not as hidden changes to the default harness.
