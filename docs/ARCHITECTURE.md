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
+---------------------------------------------------------+
| codex-native-host                                       |
| lifecycle / bounded spool / Remote auth + resume core   |
+----------------------------+----------------------------+
                             |
                       stdio / JSONL
                             |
                             v
                +------------------------+
                | stock codex app-server |
                | Rust / Codex harness   |
                +-----------+------------+
                            |
                            v
                        OpenAI/Codex
```

## Transport boundary

All feature code talks to a typed `CodexTransport` abstraction.

Initial implementations:

- `ProcessTransport`: desktop stdio/JSONL client. In production it starts the
  bundled `codex-native-host`, which then owns the app-server child.
- `RemoteTransport`: Android/remote clients using an authenticated WebSocket protocol.

The Host consumes only its reserved `host/*` request namespace. Every ordinary
Codex request, notification, server request, and response remains on the stock
app-server protocol. Large `aggregatedOutput` values are decoded incrementally
to private capped files and replaced with typed descriptors before the ordinary
JSON reaches Dart. Flutter can read only capped byte ranges or tails using opaque
references; it cannot submit filesystem paths.

Possible future implementation:

- `EmbeddedTransport`: Rust in-process app-server reached through flutter_rust_bridge. Experimental only; it must preserve app-server semantics and is not a v1 requirement.

## Memory model

The app-server/thread store is authoritative. Flutter retains only the current working set.

- Thread list: metadata only.
- Active conversation: recent page(s) only.
- Old turns: fetched on scroll.
- Tool output: summary in timeline, bounded file-backed ranges on demand.
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

A local trusted `host/remote/*` administration surface owns pairing-ticket
creation, paired-device metadata, and revocation. Device records are loaded only
when Remote administration or networking is used, so a broken Remote store does
not take down the local Codex runtime. Pairing completion and bearer
authentication belong to the Host listener; tokens never enter Flutter desktop
state after issuance.

The implemented pure Host protocol foundation provides version negotiation,
process-scoped session identity, sequenced replay with count and byte budgets,
ACK validation, correlation namespaces, same-session write idempotency, and
hash-only device credentials. An opt-in loopback-only HTTP/WebSocket listener is
also implemented behind `--remote-listen`/`CODEX_NATIVE_REMOTE_LISTEN`. It pairs
one-use local tickets, requires a scoped bearer token and protocol subprotocol,
enforces explicit body/frame/message/write-buffer/connection limits, negotiates
before RPC, sends heartbeat pings, checks live revocation, and broadcasts a
bounded protocol close before Host shutdown. It currently exposes only the
read-only `host/remote/status` foundation method; ordinary Codex RPC and event
traffic are deliberately not routed through it yet.

The remaining network and Android layers must still provide:

- TLS-required non-loopback transport and certificate policy;
- sanitized protocol-native Codex RPC/event routing with remapped IDs;
- explicit count-and-byte-bounded application outbound queues;
- chunked/resumable file transfer;
- executable replay/gap/slow-reader and large-payload recovery gates;
- platform-backed Android credential storage and lifecycle recovery.

## Fidelity mode

The default mode should keep Codex-native behavior:

- user input and explicit attachments only;
- stock Codex prompts and tool behavior;
- stock context/compaction behavior;
- stock model and reasoning controls.

Custom workflows can be added later as opt-in extensions, not as hidden changes to the default harness.
