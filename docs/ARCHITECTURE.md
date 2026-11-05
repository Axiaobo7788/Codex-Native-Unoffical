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

Host-owned Windows state does not rely on ambient cache/config inheritance. The
output-spool root and sessions receive a protected, inheritable DACL whose only
allow ACE is the current process user's SID, an existing Host-owned spool tree
is recursively migrated, and every new spool file is tightened before use. The
Remote device-store directory receives the same rule; its atomic replacement
file is created with a protected current-user DACL before any credential hash is
written, and an existing store is tightened before it is read. DACL changes use
checked object handles; reparse objects and hard-linked files are rejected.
Unix retains explicit `0700`/`0600` modes. Operator-provided TLS private-key ACL
handling remains read-only because that file is not Host-owned state. Its leaf
is opened without following a symlink/reparse point and read through the same
checked handle with a 256 KiB limit. Unix requires the effective process user as
owner and no group/other mode bits. macOS additionally requires the same handle
to report no `ACL_TYPE_EXTENDED` object; absence must be explicit and any query
error fails closed. Windows requires a protected DACL, an owner of the current
process user, LocalSystem, or Administrators, and only standard allow ACEs for
those same principals. Standard deny ACEs are harmless; a null/invalid DACL or
any other ACE type fails closed. The public certificate chain is likewise a
regular no-follow file and is capped at 1 MiB.
Installed-service key provisioning and platform installer ACLs are still
separate release gates.

The Host separately accepts an optional exact client-facing WSS `/v1/ws`
endpoint through `--remote-advertise-endpoint` or
`CODEX_NATIVE_REMOTE_ADVERTISE_ENDPOINT`. It is never inferred from the bind
socket: wildcard addresses are not client destinations, and a reverse proxy may
make the public endpoint intentionally different. Trusted local status reports
both values. An optional, independently configured pairing trust certificate is
strictly parsed at startup rather than inferred from the listener chain, because
a reverse proxy may terminate the client-visible TLS identity. The desktop setup
dialog uses a local-only typed administration gateway outside `CodexTransport`,
creates a five-minute versioned invitation only after an affirmative action,
retains it only for the dialog lifetime, and requires its endpoint, expiry, and
trust mode to match current status. It can explicitly copy but never
automatically publishes the invitation. It can list and explicitly
revoke at most 32 public device records. It cannot enable or reconfigure the
listener, and Android Remote has no access to these administration methods.

The Dart `RemoteTransport` now implements that read-only envelope without
changing feature schemas. It requires WSS by default (with an explicit literal-
loopback-only development exception), validates the negotiated subprotocol,
versions and capabilities, correlates at most 64 RPCs, accepts only the exact
next event sequence, ACKs accepted events, and reuses the typed model/thread/turn
adapters. A fresh or invalid resume always enters authoritative-resync state.
Incremental events are held behind the snapshot, and resync generations prevent
stale asynchronous reads from claiming a newer invalidation. The held suffix is
bounded to 512 events and 8 MiB. History/output, writes, approvals, and server
requests fail locally because the Host has not made those semantics remotely
safe.

The Android client now has a platform-backed owner for one versioned WSS device
record. Version 2 stores endpoint, bearer, bounded device metadata, and either
system trust or one exact certificate trust object as one
secure value, serializes and verifies mutations, distinguishes absent from
unreadable/corrupt state, and never silently deletes an unreadable record.
Version-1 system records remain readable and are upgraded only by a later
verified save under the same secure-storage key. Certificate bytes are retained
as bounded canonical DER plus a verified SHA-256 fingerprint; a fresh empty
per-connection `SecurityContext` uses that identity for both HTTPS and WSS.
Android cloud backup and device transfer exclude all SharedPreferences because
the corresponding Keystore wrapping key is device-bound.

`RemoteLifecycleCoordinator` owns connection readiness above the
socket. Its separate secure cursor is device/session bound and is accepted only
with an exactly matching retained projection. Fresh or invalid state loads at
most 100 models and 100 thread rows, replaces the bounded authoritative
projection, and persists the baseline only after replacement. Sequenced events
mutate that projection before their cursor is persisted. Connection and resync
generations reject stale work; projection writes are serialized across sessions;
generic failures use capped exponential backoff; credential rejection and live
revocation are terminal; suspend retains only a provably applied projection and
stop invalidates it. Android `RuntimeController` constructs this stack by
default. `AppLifecycleListener.onHide` suspends it and `onShow` restarts it;
detach performs full shutdown. Product state distinguishes every lifecycle gate
and exposes only the ready projection through a bounded read-only metadata view.
Existing desktop controllers and process transport are unchanged, while every
unsupported Remote gateway rejects locally.

The unpaired product state now owns a separate bounded onboarding coordinator.
It accepts one exact `codex-native-pairing-v1` invitation plus a bounded device
name. The invitation binds an exact WSS `/v1/ws` endpoint, one validated
24-character ticket, expiry, and either runtime-system or single-certificate
trust before network contact. It derives the same-origin HTTPS `/v1/pair` route.
Redirects and automatic decompression are disabled; invitation, certificate,
connection, whole-request, request-body, response-body, content-type, status,
protocol, device, scope, timestamp, and bearer bounds are fail-closed. There is
no arbitrary bad-certificate callback, global trust mutation, TOFU after ticket
disclosure, or silent trust migration.

On Android, the same form can receive that exact invitation from an optional
foreground QR scanner. Camera access begins only after an explicit Scan QR
action. The scanner recognizes QR only, returns no frame to Dart, validates the
first decoded string through the authoritative invitation adapter and expiry,
then fills the obscured field without starting network pairing. Manual paste is
always retained. Camera lifecycle calls are serialized and stop after the app
leaves the foreground; camera, back-camera, and autofocus hardware remain
optional manifest features. The bundled ML Kit model avoids a first-use model
download, but its documented performance/utilization metrics are a dependency
privacy property, not application pairing traffic.

The returned record is written and read back through secure storage before a new
Remote lifecycle generation starts. An older credential load is stopped first,
so a late absent result cannot overwrite a successful pairing. If the app is
hidden, an accepted credential is still saved but no socket starts until the
next show/cold-start load. Shutdown waits for this narrow save boundary. An
unreadable record cannot be overwritten by pairing: recovery explicitly stops
Remote, verifies cursor deletion before credential deletion, and reloads actual
persisted state. This client-side clear never claims to revoke the Host entry.

Dart 3.13's socket is configured with a 1 MiB inbound frame cap and no
compression, while
the transport separately caps a delivered combined message. The authenticated
Host also caps and emits one-frame messages. Dart exposes no aggregate
fragmented-message setting, so this is not a malicious-authenticated-Host memory
boundary.

The remaining network and Android layers must still provide:

- real-device evidence for both system-root and pairing-bound certificate trust,
  including Android TLS-provider and Keystore behavior;
- chunked/resumable file transfer;
- broader notification/diff delivery only after method-specific payload bounds;
- physical-device evidence for the exact desktop QR to Android scanner path,
  including permission denial/settings recovery, camera lifecycle, rotation,
  dense symbols, and both trust modes; manual transfer remains complete;
- paged/selectable Remote metadata and later conversation features only after
  their Host semantics are bounded end to end.

## Fidelity mode

The default mode should keep Codex-native behavior:

- user input and explicit attachments only;
- stock Codex prompts and tool behavior;
- stock context/compaction behavior;
- stock model and reasoning controls.

Custom workflows can be added later as opt-in extensions, not as hidden changes to the default harness.
