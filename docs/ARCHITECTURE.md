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
hash-only device credentials. An opt-in HTTP/WebSocket listener is implemented
behind `--remote-listen`/`CODEX_NATIVE_REMOTE_LISTEN`. Plaintext is restricted
to a literal loopback address. Non-loopback requires an explicitly configured
PEM certificate chain/private key and serves HTTPS/WSS through rustls; TLS
material is validated before bind and stock-Codex startup and can be atomically
reloaded only through the trusted local Host RPC. It pairs one-use local
tickets, requires a scoped bearer token and protocol subprotocol, enforces
explicit body/frame/message/write-buffer/connection limits, negotiates before
RPC, sends heartbeat pings, checks live revocation, and broadcasts a bounded
protocol close before Host shutdown. It currently exposes only the
read-only `host/remote/status`, `model/list`, bounded `thread/list`, and
metadata-only `thread/read` methods. Codex responses reuse the same Host output
sanitizer, are correlated through a per-process reserved namespace, and are
delivered through a per-connection count-and-byte-bounded queue without leaking
the internal response to desktop stdout. The same sanitizer now publishes only
`turn/started`, `turn/completed`, `item/started`, `item/completed`,
`thread/status/changed`, and `error` notifications to the existing 512-event,
8 MiB journal. A socket subscribes before negotiation, skips the journal
baseline already represented by `hello_ack`, then accepts only the exact next
sequence. Same-session retained suffixes replay; an evicted cursor, receiver
lag, or live sequence gap requires authoritative resync. Token deltas, diffs,
server requests, approvals, and all writes remain deliberately unrouted.

The remaining network and Android layers must still provide:

- pairing-bound self-signed certificate identity or ordinary platform-CA trust;
- chunked/resumable file transfer;
- broader notification/diff delivery only after method-specific payload bounds;
- platform-backed Android credential storage and lifecycle recovery.

## Fidelity mode

The default mode should keep Codex-native behavior:

- user input and explicit attachments only;
- stock Codex prompts and tool behavior;
- stock context/compaction behavior;
- stock model and reasoning controls.

Custom workflows can be added later as opt-in extensions, not as hidden changes to the default harness.
