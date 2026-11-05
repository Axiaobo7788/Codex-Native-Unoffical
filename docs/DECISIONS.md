# Architecture Decision Log

This file records durable project decisions and the reasoning behind them. Do not silently reverse an accepted decision. If a decision changes, append a new entry that supersedes the old one.

## ADR-001 — Use Flutter for the client UI

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

Use Flutter/Dart for desktop and Android presentation layers.

### Why

- Android is a first-class target, not an afterthought.
- The product is dominated by conversation, task, diff, approval, and streaming UI rather than deep native C++ integration.
- A shared component/domain layer is valuable across desktop, phone, and tablet.
- Long lists can be virtualized and kept within a bounded UI working set.

### Consequence

Linux/Wayland performance must be tested early, especially on NVIDIA systems.

---

## ADR-002 — Reuse stock Codex app-server

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

The client must use the stock `codex app-server` as the Codex harness/runtime rather than reimplementing the agent.

### Why

The project aims to replace presentation and remote-control layers, not Codex intelligence. Reusing app-server preserves Codex prompts, tools, compaction behavior, approvals, skills, MCP, plugins, and upstream improvements.

### Consequence

The app-server protocol is the primary integration boundary.

---

## ADR-003 — Keep the local Codex runtime out of process in v1

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

Desktop v1 starts `codex app-server --listen stdio://` as an independent child process and communicates via newline-delimited JSON.

### Why

- Process isolation makes crashes and memory growth independently recoverable.
- Users can upgrade Codex independently of the client.
- It stays on the supported app-server boundary.
- JSON/pipe overhead is negligible compared with model/tool latency.

### Consequence

`flutter_rust_bridge` is not required in v1. An embedded transport may be revisited later only if profiling shows meaningful benefit.

---

## ADR-004 — Android is a remote control plane

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

Android should connect to a host running Codex rather than run the full Codex runtime locally by default.

### Why

This avoids Android filesystem, sandbox, PTY, toolchain, and background-process limitations while keeping the development environment on the real host.

### Consequence

OpenAI/Codex credentials remain on the host. The remote protocol must support pairing, authentication, reconnect/resume, and large-payload streaming.

---

## ADR-005 — Bounded UI memory is a product requirement

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

The Flutter UI must never treat full Codex thread history as resident application state.

### Rules

- Paginate turns/items.
- Virtualize long lists.
- Keep only an active working set in memory.
- Show summaries for large tool output and load full content on demand.
- Load diff content per file/hunk as needed.
- Inactive threads should approach zero presentation-layer memory cost.

### Why

A core project goal is to avoid the double pressure of a large Codex runtime plus a heavyweight UI retaining the same long-running session history.

---

## ADR-006 — Preserve Codex fidelity by default

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

Default behavior must not secretly rewrite system prompts, replace tool schemas, or perform client-side context compaction.

### Why

The project should behave like Codex with a different presentation layer, not like a separate agent harness that merely uses the same model.

---

## ADR-007 — License under Apache-2.0

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

Use Apache License 2.0 for the project.

### Why

It matches the upstream Codex project's permissive style, is friendly to community ports and packaging, and includes explicit patent terms without adding copyleft restrictions.

---

## ADR-008 — Put a bounded native Host between Flutter and app-server

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Desktop production transport runs a lightweight Rust `codex-native-host`. The
Host supervises the stock `codex app-server`, incrementally validates its JSONL
stdout, removes large command-output strings before Flutter receives a message,
and exposes bounded output reads through opaque references.

The Host is a transport and lifecycle boundary. It does not replace Codex
prompts, tools, compaction, protocol semantics, or the agent loop. Remote clients
will later connect to this same boundary rather than introduce a second harness.

### Why

- Dart's normal JSON decoder must materialize a complete JSON string before a
  typed adapter can discard `aggregatedOutput`.
- Current app-server item reads can still return an entire command output in one
  response; upstream output deferral makes list responses safer but does not
  provide byte ranges.
- An incremental native boundary can keep both the Host and Flutter projection
  bounded, spool selected output with explicit caps, isolate process failure, and
  become the natural owner of authenticated Remote transport.

### Consequence

- Desktop release bundles must build and ship `codex-native-host` beside the
  Flutter executable.
- Flutter receives sanitized JSON plus output descriptors and must request only
  bounded ranges/tails.
- Spool files are session-scoped, owner-only, capped, and addressed only by
  opaque IDs. Paths never cross the protocol boundary.
- The Host cannot eliminate app-server's own serialization allocation because
  the reviewed upstream stdio writer creates a complete serialized `String`
  before writing. App-server, Host, and Flutter memory must be measured and
  reported separately.

---

## ADR-009 — Distribute the macOS developer client outside the Mac App Store

**Status:** Accepted

**Date:** 2026-11-05

### Decision

The macOS build is an unsandboxed, Developer ID-signed and notarized direct
distribution. It is not a Mac App Store target. The bundled native Host is copied
into `Contents/MacOS` and signed as nested code during the Xcode build.

### Why

Codex is a developer tool that must run the user's separately installed runtime,
read and write explicitly selected workspaces, and launch normal toolchains and
commands. Apple's App Sandbox is mandatory for Mac App Store distribution, and
child processes inherit the parent's static sandbox. Security-scoped access
granted after launch is not automatically inherited by a child. Constraining
stock Codex to that sandbox would break the product's core local-runtime model,
while broad sandbox exceptions would not recreate normal developer-shell access.

### Consequence

- Mac App Store submission is out of scope for v1.
- Release engineering must sign all nested code, enable the hardened runtime,
  notarize the completed app, and validate on a real macOS machine.
- Removing App Sandbox does not weaken the client's own approval, sandbox-policy,
  opaque-path, or bounded-transport rules. Those remain application requirements.

---

## ADR-010 — Use a Host-owned authenticated resumable Remote envelope

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Android Remote connects to an explicitly enabled listener owned by
`codex-native-host`, not directly to stock app-server. The Host carries sanitized
app-server JSON-RPC inside a minimal versioned envelope with device
authentication, capabilities, a process-scoped session ID, sequenced events,
ACK/resume, bounded replay, and explicit resynchronization.

Pairing uses a short-lived single-use local ticket and returns one random 256-bit
device bearer token. Only its SHA-256 digest and bounded device metadata are
persisted. Non-loopback exposure requires TLS. Ordinary Codex methods remain
Codex methods; project-owned extensions stay under `host/*`.

Replay storage is bounded by both event count and serialized bytes, while
message and per-connection queue limits protect live delivery. Writes require
same-session idempotency keys and are never silently replayed after a Host
restart. Large blobs use separately authenticated chunked transfer rather than
WebSocket base64 payloads.

### Why

- The Host already owns output removal, opaque range reads, child lifecycle, and
  bounded transport; direct app-server access would bypass those invariants.
- A network connection can survive while state hydration, writer ownership, or
  large-payload delivery is broken. Session/sequence/resync semantics make those
  states explicit instead of treating `connected` as authoritative readiness.
- Reusing protocol-native app-server methods avoids a second feature schema that
  would drift from Codex, while the narrow envelope supplies the security and
  recovery properties app-server delegates to its remote peer.

### Consequence

- Remote networking is opt-in and loopback-only by default. Configuration must
  reject plaintext non-loopback listeners.
- Protocol, auth, journal, correlation, and idempotency semantics are tested as a
  pure Host state machine before a WebSocket implementation is selected.
- Android keeps only a bounded projection and uses existing paginated adapters
  after resync; it must not hydrate complete thread history automatically.
- Pending approvals/elicitation remain distinct fail-closed Host state rather
  than relying only on the volatile event journal.
- Device secret storage, TLS, installed-network behavior, and reconnect recovery
  require real platform/device validation and cannot be claimed from Linux unit
  tests alone.

---

## ADR-011 — Require explicit certificate identity for non-loopback Remote

**Status:** Accepted

**Date:** 2026-11-05

### Decision

`codex-native-host` permits plaintext Remote only on a literal loopback address.
Every non-loopback listener requires an explicitly configured PEM certificate
chain and matching private key and serves HTTPS/WSS through rustls. Missing,
partial, unreadable, overexposed, or invalid TLS configuration fails before the
listener binds and before stock Codex starts; there is no plaintext fallback.

Certificate rotation is an explicit trusted-local operation under
`host/remote/tls/reload`. A complete valid replacement is swapped atomically for
new handshakes. A failed reload keeps the last valid configuration, exposes no
certificate/key contents, and does not terminate established connections.

Public or managed deployments should use a normal CA-valid certificate, either
directly or through a correctly configured TLS reverse proxy. A future local
self-signed pairing flow must deliver and persist the expected certificate/CA
identity through the trusted pairing surface. Android must never implement
trust by accepting an arbitrary bad certificate.

### Why

- A bearer token sent over non-loopback plaintext is reusable by an observer and
  does not authenticate the Host to the phone.
- Silent downgrade after a certificate error would turn a configuration or
  rotation mistake into credential exposure.
- Android's platform trust store is appropriate for ordinary CA certificates;
  a local self-signed identity needs an explicit pairing-bound trust bootstrap,
  not a global bypass callback.
- Atomic reload permits planned certificate rotation without invalidating active
  work, while retaining the previous valid configuration avoids an outage from
  a partial or malformed file replacement.

### Consequence

- Linux/macOS private-key files must not grant group/other access. Windows key
  ACL behavior and installed-service operation require a separate platform gate.
- The current bearer token remains the device authorization credential; mTLS is
  not required for this slice and may be reconsidered only with measured need.
- The current Host can serve operator-provided TLS, but self-signed Android
  onboarding is not complete until pairing securely binds certificate identity
  and platform-backed secret storage is implemented and device-tested.

---

## ADR-012 — Treat Android Remote credentials as recoverable device-bound state

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Persist one versioned Remote device record through platform secure storage. The
record contains the exact WSS endpoint, 256-bit bearer, bounded device identity,
and an explicit trust kind. The first supported trust kind is ordinary Android
system-CA trust; plaintext endpoints and arbitrary-certificate acceptance cannot
be persisted.

Android uses a dedicated secure-storage namespace with automatic reset disabled
for normal reads and writes. Reads distinguish an absent record from an
unreadable or structurally invalid record. Unreadable data is never silently
removed or overwritten: retry and an explicit clear/re-pair action are separate
recovery choices. Only that explicit clear uses the plugin's namespace reset so
it can recover when the old wrapping key is already unusable. Writes are
serialized, reject an invalid existing record, and are read back before success.
The bearer and record details are redacted from object strings and storage
exceptions.

Disable application backup and independently exclude SharedPreferences from
both legacy cloud backup and Android 12+ cloud/device transfer. The ciphertext
must not be restored to a device whose non-exportable Keystore wrapping key was
not restored with it.

### Why

- Host bearers are revocable and re-pairable, but a transient Keystore failure
  must not be misreported as “never paired” or trigger an invisible destructive
  reset.
- Background reconnect cannot require a biometric prompt for every key use.
- Android Keystore key material is device-bound, while SharedPreferences are
  included in backup by default; restoring only encrypted preferences creates
  predictably unreadable state.
- Keeping the complete connection profile in one bounded secure value gives the
  application one verified update boundary and keeps bearer data out of normal
  preferences, routes, logs, and crash text.

### Consequence

- `flutter_secure_storage` 11.2.0 is the current platform adapter, configured
  with `resetOnError: false`, algorithm migration, migration backup, and an
  isolated namespace. Its open Android transient-Keystore replacement issue is
  an availability risk: the application can surface recovery but cannot repair
  a wrapping key already replaced inside the plugin. Physical-device fault and
  backup/restore testing remains a release gate.
- Pairing-bound local certificate/CA identity must use a new explicit record
  version rather than overloading `system` trust. ADR-014 implements that
  requirement as record version 2 while preserving version-1 reads.
- Cursor durability and reconnect ownership remain outside the credential
  record so a received-but-not-applied event can never advance durable state.

---

## ADR-013 — Require an explicit advertised endpoint for desktop pairing

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Treat the Remote listener bind address and the client-facing pairing endpoint as
two different operator-owned values. `codex-native-host` accepts an optional
`CODEX_NATIVE_REMOTE_ADVERTISE_ENDPOINT`/`--remote-advertise-endpoint` only when
a listener is enabled. It must be an exact absolute `wss://.../v1/ws` URI with
no user info, query, fragment, zero port, or unspecified `0.0.0.0`/`[::]` host.
The Host reports that value through trusted-local status and returns the same
value with a newly created pairing ticket. It never derives an invitation from
the bound socket address.

The Flutter desktop exposes Remote administration through a dedicated local
gateway over `ProcessTransport`, not through `CodexTransport` and not through
the Android `RemoteTransport`. Opening the setup surface reads listener/TLS/
scope/endpoint and bounded public device metadata, but creates no ticket. A
ticket is created only after an explicit action, retained only by that dialog,
and accepted only when its endpoint exactly matches the current status and its
expiry is still in the future. Listener configuration remains restart-owned;
the UI neither enables networking nor edits Host configuration.

Revocation remains explicit and requires confirmation plus authoritative list
readback. The registry limits active credentials to 32. Revoked or expired
records stay visible immediately, then are pruned atomically with the next
successful pairing publication so revocation can release capacity without
making the durable store unbounded.

### Why

- A wildcard bind describes where a server accepts traffic, not a hostname or
  address another device can reach. Guessing one can produce an unusable or
  security-incorrect invitation.
- Bind and public endpoint legitimately differ behind a TLS reverse proxy, NAT,
  split DNS, or an installed service. Requiring equality would reject supported
  deployments while derivation would hide operator intent.
- Pairing tickets are bearer-like, short-lived secrets. Automatic generation on
  screen open, persistence in application state, or diagnostic logging would
  increase exposure without improving setup.
- Local administration can revoke network clients and mint credentials, so it
  must not be added to the transport abstraction used by those same clients.

### Consequence

- A listener without an advertised endpoint remains usable for operator-level
  testing but the desktop cannot create a shareable invitation from it.
- Operators must configure a fixed reachable WSS endpoint and restart the Host;
  reachability, DNS, firewall, proxy, and certificate correctness still require
  real-network validation.
- The initial desktop surface presented endpoint and manual ticket text only.
  ADR-014 supersedes this consequence with a versioned manual invitation and
  record migration; QR rendering remains a separate presentation decision.

---

## ADR-014 — Bind Remote trust before the pairing request

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Replace the separate endpoint/ticket Android input with one bounded versioned
pairing invitation created by the trusted local Host surface. Version 1 is an
opaque `codex-native-pairing-v1.<base64url-json>` envelope that binds the exact
WSS endpoint, single-use code, expiry, and one explicit trust mode before any
network request. Trust is either the Dart/Android runtime system roots or one
bounded DER certificate plus its SHA-256 consistency fingerprint.

A private/self-signed deployment must configure exactly one public trust
certificate through `CODEX_NATIVE_REMOTE_PAIRING_TRUST_CERT`/
`--remote-pairing-trust-cert`. It requires both a listener and explicit
advertised endpoint, is parsed and validated before stock Codex starts, and is
snapshotted until Host restart. It is intentionally separate from the Host TLS
certificate chain because a reverse proxy may own the client-visible identity.
The Host never guesses a leaf or CA from a chain.

Android record version 2 persists the same trust object with endpoint, bearer,
and device metadata. Version-1 system-trust records remain readable; verified
saves write version 2 under the existing secure-storage key. Certificate mode
constructs a per-connection empty `SecurityContext`, adds only the invitation
certificate, and uses that context for both HTTPS pairing and WSS. Canonical DER
is persisted; Dart receives PEM on non-iOS and DER on iOS according to the
documented platform container behavior. No global store is modified and no
arbitrary-certificate callback exists.

### Why

- Learning a fingerprint from the pairing response is too late because an
  impersonator would already have received the one-use ticket.
- An explicit trust artifact supports direct self-signed Host TLS, a stable
  private CA, and TLS termination at a reverse proxy without conflating bind and
  client identity.
- The certificate is the actual scoped trust anchor. Its fingerprint detects
  representation drift but is not presented as independent authentication;
  trusted local transfer of the complete invitation is the bootstrap.
- Stable CA trust allows leaf rotation without device migration. Exact leaf
  trust is narrower, but changing it must visibly require restart and re-pairing
  rather than silently accepting a new identity during TLS reload.

### Consequence

- Desktop provides manual selectable/copyable invitations only. QR rendering is
  a later presentation slice and must preserve this version boundary, review QR
  dependency licensing, and validate realistic payload/error-correction limits.
- Invitation possession grants a short-lived pairing capability and chosen
  trust identity. It must be transferred through the trusted local surface and
  is never logged, persisted by desktop UI state, or copied automatically.
- Host startup rejects malformed, multiple, empty, or oversized trust
  certificates. A full PEM chain is not accepted as an ambiguous trust choice;
  operators supply exactly the intended leaf or CA certificate.
- Real Android TLS-provider, Keystore, backup/restore, LAN, lifecycle, and Human
  interaction validation remain release gates. Same-host Linux WSS evidence does
  not satisfy them.
