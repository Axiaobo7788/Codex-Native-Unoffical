# Project Status

_Last updated: 2026-11-05_

This file is the repository's durable project memory. Update it whenever a task materially changes implementation status, milestones, known blockers, or the next recommended step.

## Current phase

**Phase 1 — Flutter + Codex app-server vertical slice: IMPLEMENTED, VERIFIED, COMMITTED (`5089320`)**

**Phase 2 — Local usable Codex client: IMPLEMENTED AND LOCALLY MACHINE-VERIFIED — Human approval interaction and hosted CI remain separate gates**

**Phase 3 — Bounded-memory long-session UX: LINUX MACHINE-ACTIONABLE WORK EXHAUSTED — paginated history, bounded native command-output viewing, safe lazy assistant Markdown, storage-failure recovery, and lifecycle soak are integrated; cross-platform and Human gates remain**

**Phase 4 — Android Remote: IN PROGRESS — transport/auth/resume research, the Host protocol/auth core, authenticated WS/WSS transport, bounded read-only Codex RPC, sanitized event replay, operator-certificate non-loopback TLS, the bounded Dart Remote transport core, and a recoverable platform credential owner are implemented; pairing-bound local trust, reconnect/resync ownership, writes/approvals, and Android UI integration do not exist yet**

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
- `CodexTransport` isolates feature/domain code from transport details. The
  production desktop uses `ProcessTransport`; a read-only `RemoteTransport`
  now reuses the typed model/thread/turn adapters but is deliberately not wired
  into Android runtime state before resync and reconnect ownership exist.
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
- The typed history layer loads ascending `thread/items/list` pages for exactly
  one user-selected turn with a 100-item cap. Large `aggregatedOutput` fields are
  removed by the Host before Dart decoding, and switching threads discards all
  stored-history state immediately.
- Stored and live entries are merged by item ID into one virtualized list so a resumed active turn does not render duplicate items.
- `codex-native-host` now supervises stock app-server by default, validates
  stdout incrementally without line buffering, spools decoded
  `aggregatedOutput` values behind opaque references, replaces them with bounded
  descriptors, and implements capped `host/status`, `stat`, `readRange`, and
  `tail` RPCs. Flutter locates Codex and the bundled Host independently and has
  no silent direct-app-server fallback.
- Unpublished output spools are transactional: write, parse-abandonment, flush,
  rename, or metadata failures remove partial artifacts and return their bytes
  to the session budget. Linux disk-full simulation degrades the selected output
  to an unavailable descriptor without reinjecting it; invalid or unwritable
  cache roots fail with context before Codex is spawned.
- Historical command rows load full items for only one selected turn. List
  requests prefer upstream output deferral; a deferred selected item uses the
  gated `thread/items/read` API, whose response is still sanitized by the Host.
  The log dialog retains one approximately 64 KiB byte window, uses bounded
  first/previous/next/tail reads, preserves UTF-8 page edges, and virtualizes
  display rows.
- Linux and Windows native builds compile/package the Host beside the app.
  macOS embeds and signs it in `Contents/MacOS`; v1 macOS is a direct notarized
  distribution because App Sandbox cannot preserve the required normal Codex
  developer-workspace/toolchain model. Windows/macOS builds are not verified in
  this Linux environment.
- Completed assistant messages use a project-owned safe Markdown allowlist only
  while in-progress streaming remains selectable plain text. Raw HTML is inert,
  images never load, links require an explicit click and absolute `http`/`https`
  URI, and rich parsing falls back to a bounded plain-text tail above 16 KiB.
  The outer virtualized timeline controls widget construction and no global AST
  cache retains inactive messages.
- Cross-platform RSS/runtime evidence and Human interaction acceptance are not
  complete yet. Those remaining Phase 3 gates require unavailable Human,
  Windows, macOS, or installed-volume evidence in this Linux session, so Phase 4
  machine-actionable work has started without misreporting those gates complete.
- Android Remote now has a pure Rust Host core for typed negotiation,
  session/sequence/ACK resume, count-and-byte-bounded replay, multi-connection
  request correlation, bounded same-session write idempotency, single-use
  pairing, and hash-only scoped device credentials. The WS/WSS listener uses
  these primitives. Android now has a strict platform-backed WSS/system-CA
  device-record owner, but no pairing or runtime UI flow exists yet.
- The desktop Host exposes trusted local `host/remote/pairing/create`,
  `host/remote/devices/list`, and `host/remote/devices/revoke` administration.
  Its credential registry is loaded lazily from a configurable user config file,
  so Remote-store corruption cannot block ordinary local Host status or Codex
  startup.
- The Host can explicitly enable a plaintext listener only on a literal loopback
  address. A non-loopback listener requires an operator-provided PEM certificate
  chain/private key and uses rustls HTTPS/WSS; invalid or incomplete material
  fails before bind and before stock Codex starts. Unix keys must be owner-only.
  Trusted local `host/remote/tls/reload` atomically changes new-handshake identity
  without dropping established sockets and retains the last valid configuration
  on failure. The bounded endpoints implement pairing, version negotiation,
  heartbeat, live revocation, and coordinated shutdown. The socket exposes
  `host/remote/status`, `model/list`, bounded `thread/list`, and metadata-only
  `thread/read` through the same sanitized stock app-server process. Six bounded
  lifecycle/state notification methods feed sequenced live delivery and same-
  session replay. Dart now has a bounded read-only client protocol core, but
  there is still no Remote write/approval path, Android reconnect coordinator or
  UI, or pairing-bound Android certificate trust.
- Lightweight GitHub Actions CI is configured for Dart/Rust format, analyze,
  Clippy, tests, and a Linux debug build. Hosted CI has not run for the current
  local commits.

## Completed

### 2026-11-05 — Phase 4 recoverable Android credential owner

- Reviewed Android Keystore and Auto Backup guidance, the current
  `flutter_secure_storage` 11.2.0 implementation/changelog, its namespace and
  migration behavior, and open issue #1298 describing a transient Keystore
  lookup replacing the wrapping key. ADR-012 treats the device bearer as
  recoverable device-bound state rather than an infallible preference.
- Added a strict versioned Remote device record for one WSS endpoint, the exact
  43-character bearer, bounded device ID/name, and explicit `system` trust.
  Plaintext, URI-embedded credentials, unknown/future schema fields, control
  characters, and oversized records fail before persistence. Object strings and
  all public storage errors redact endpoint, bearer, and record data.
- Added a serialized credential owner with distinct absent, available, and
  unreadable/corrupt recovery results. It validates existing data before
  replacement, verifies every write by exact readback, never auto-deletes on a
  read/decrypt error, and exposes clear as a separate explicit recovery action.
  Only that action enables a namespace reset so a lost wrapping key cannot make
  recovery itself impossible.
- Added `flutter_secure_storage` 11.2.0 with a dedicated namespace,
  `resetOnError: false`, algorithm migration, and migration backup. The bearer
  is stored only through this adapter, not in ordinary preferences, routes, or
  diagnostics. Background operation deliberately does not require biometric
  authentication per access.
- Disabled Android application backup and added independent legacy and Android
  12+ rules excluding all SharedPreferences from cloud backup and device
  transfer. The merged debug/release manifests retain these rules and API 24
  minimum compatibility.
- Nine credential/recovery tests bring the Flutter total to 99. Full Dart
  analysis, all Flutter tests, and the Linux debug build pass. Android debug and
  minified release builds pass through the documented temporary Unicode SDK
  path workaround; the three-ABI artifacts are 191,469,644 and 51,791,110
  bytes. The secure-storage dependency inflates the JIT debug kernel, while the
  release artifact tree-shakes to a normal universal-APK range.
- No emulator or physical device was available. Real Keystore encryption,
  transient service failure, uninstall/reinstall, OS backup/restore, device
  transfer, and system-CA network behavior remain unverified platform gates.

### 2026-11-05 — Phase 4 bounded Dart Remote transport core

- Added production Android `INTERNET` permission and a typed
  `RemoteTransport` over `dart:io` WebSocket. WSS is the default; plaintext is
  accepted only through an explicit opt-in with a literal loopback IP. Endpoint
  validation rejects user-info/query credential placement without echoing the
  URI, and bearer validation accepts only the Host's exact 43-character
  base64url credential shape.
- Implemented strict `codex-native-v1` subprotocol and three-message
  negotiation, required capability/version checks, same-session resume, exact
  sequenced event acceptance, ACK, a 64-request correlation cap, 1 MiB encoded
  message cap, request deadlines, and coordinated fail-closed shutdown. A late
  socket arriving after a connection deadline is explicitly closed rather than
  leaked.
- The real `dart:io` socket disables WebSocket compression, configures Dart
  3.13's 1 MiB inbound frame limit, and serializes outbound messages through
  `addStream` so OS write backpressure can pause the source. Its application
  write queue is independently capped at 64 messages and 2 MiB. Real loopback
  socket tests prove ordered writes and that an oversize frame is protocol-
  closed before a message reaches the transport.
- A new connection now requires bounded authoritative resync even when the Host
  has no replay suffix. Events are held behind that snapshot, not exposed to
  feature state, and a generation token prevents an older in-flight resync from
  clearing a newer invalidation. The client buffer mirrors the Host's 512-event
  and 8 MiB journal limits; exhaustion clears the incomplete suffix and forces
  a new generation.
- Reused the existing typed model/thread/turn adapters for the currently
  allowed `host/remote/status`, `model/list`, `thread/list`, and metadata-only
  `thread/read` surface. History/output reads, writes, turns, interruption, and
  approvals are rejected locally without putting an RPC on the socket. A
  synthetic initialize result is returned only after Remote status/session/mode
  validation; this transport foundation is not yet an Android ready state.
- The first fail-closed sequence-gap test stalled during close. The cause was
  closing the socket before cancelling the active `StreamIterator`; reversing
  that order removed the lifecycle wait and is retained as negative evidence.
  Eighteen focused tests now cover endpoint/credential boundaries, late-connect
  cleanup, subprotocol negotiation, resync gating/generation invalidation,
  exact replay/ACK, out-of-order RPC correlation, local write rejection,
  malformed/binary/gap input, abnormal peer close, explicit resync, timeout,
  concurrent close, and real-socket frame/write behavior. Dart's oversize-frame
  path closes the message stream with code 1002 instead of forwarding its
  internal exception; the transport now converts every abnormal peer close into
  a visible protocol error.
- Full `dart analyze` and all 90 Flutter tests pass. The production Android
  manifest contains `INTERNET`; `assembleDebug` again passed 87 Gradle tasks and
  produced the 145 MiB three-ABI debug APK after temporarily Unicode-escaping
  the ignored Flutter SDK property. Ordinary `flutter build apk` still fails
  before compilation on this Unicode path, and no emulator, physical Android,
  real LAN, background lifecycle, platform-CA, or UI claim is made.

### 2026-11-05 — Phase 4 fail-closed non-loopback WSS

- Reviewed `axum-server`/rustls certificate loading and atomic reload, Android
  network-security and pinning guidance, Dart `HttpClient`/`SecurityContext`
  injection, current secure-storage constraints, and maintained Remote clients.
  ADR-011 requires explicit certificate identity for non-loopback Remote and
  forbids arbitrary-certificate callbacks or plaintext downgrade.
- Added paired certificate/key environment and CLI configuration. Both must be
  present with an enabled listener; plaintext remains literal-loopback-only in
  both the parser and the server. TLS parses before bind and before Codex spawn,
  Unix private keys with group/other permissions fail, and errors/status never
  include PEM contents.
- Added rustls HTTPS/WSS through `axum-server` while retaining every existing
  HTTP body, WebSocket frame/message/write-buffer, connection, application queue,
  replay, heartbeat, and timeout bound. Local status now reports actual TLS and
  loopback/network scope instead of hard-coded values.
- Added trusted-local `host/remote/tls/reload`. A valid certificate/key pair is
  atomically adopted for new handshakes, existing WSS connections survive, old
  trust no longer connects, and an invalid reload returns a generic error while
  retaining the last valid configuration.
- The initial TLS WebSocket test observed an EOF because `axum-server`'s
  `http1_only()` path did not serve HTTP upgrades. Removing that override fixed
  the concrete lifecycle mismatch; the failure remains recorded in research.
- Rust tests now pass 25 Remote-library tests, 47 Host-binary tests, and three
  executable failure-path tests (75 total). A release Host plus stock app-server
  passed the complete read-only Remote smoke over WSS in 10.828 seconds with a
  Dart `SecurityContext`, network-scope wildcard bind, hash-only pairing, eight
  models, metadata-only thread read, live revocation, no internal-ID leak, and
  zero Host exit. The client connected through loopback on the same Linux host,
  so this is not real LAN, firewall, system-CA, service-install, or Android proof.
- Dependency review caught Cargo initially selecting `rcgen` 0.14.10 and `time`
  0.3.55, both of which require Rust 1.88 despite the Host's declared Rust 1.87
  floor. The committed lock now uses `rcgen` 0.14.5 (declared MSRV 1.71) and
  `time` 0.3.45 (declared MSRV 1.83). This environment has Rust 1.99, so an
  actual Rust 1.87 build remains a separate CI/toolchain gate.

### 2026-11-05 — Phase 4 bounded Codex event replay

- Reviewed the official generated notification envelope and current app-server
  definitions. The first Remote event allowlist is deliberately limited to
  `turn/started`, `turn/completed`, `item/started`, `item/completed`,
  `thread/status/changed`, and `error`. Token/output/reasoning deltas, full diff
  updates, unknown notifications, and every request-shaped object with a
  top-level `id` remain on the desktop path only.
- Extended the incremental output sanitizer to identify top-level method/ID
  shape without materializing app-server messages. Allowlisted notifications are
  still published to desktop first, then captured only after
  `aggregatedOutput` removal, with a 256 KiB Remote cap. A larger event becomes a
  small sequenced `host/resyncRequired` marker rather than a hidden drop or a
  large allocation.
- Connected the existing 512-event/8 MiB journal to a capacity-64 live broadcast
  and the per-connection count-and-byte queue. Sockets subscribe before
  negotiation, skip events represented by the handshake baseline, accept only
  the exact next sequence, and record it as sent for ACK validation. Receiver
  lag or a sequence gap emits `resync_required` and policy-closes; queue or
  socket-write exhaustion also disconnects the slow peer.
- TCP tests prove live delivery, ACK, exact retained replay, abrupt unacknowledged
  reconnect, eviction-to-resync without partial history, and slow-reader
  disconnection under an 18 MiB fanout. Transform/publisher tests cover
  sanitization, server-request and delta exclusion, oversized event markers, and
  non-advancing rejection of request-shaped captures.
- The Rust suite now passes 25 Remote-library tests, 43 Host-binary tests, and
  two executable failure-path tests (70 total), plus format and strict Clippy.
  The release Host build and the real stock app-server read-only smoke also pass;
  the smoke did not start a real turn and therefore does not establish live
  stock turn-event publication.

### 2026-11-05 — Phase 4 bounded read-only Codex bridge

- Generated and reviewed the installed stock app-server
  `0.166.0-alpha.5.1` schemas, then added a strict read-only allowlist for
  `model/list`, `thread/list`, and `thread/read`. List pages are normalized to at
  most 100, cursors to 4 KiB, thread IDs to 128 bytes, `thread/list` to its small
  pagination/sort/non-archived subset, and `thread/read` to
  `includeTurns=false`. Unknown fields, write methods, idempotency keys, or a
  device without read scope fail closed before dispatch.
- Moved the Host event loop from an unbounded channel to a capacity-64 channel.
  Remote request correlation is independently capped at 64 requests and 64 KiB.
  Internal IDs include the random Host session, local input cannot claim their
  reserved namespace, and only the exact current-session top-level response is
  suppressed from desktop stdout.
- Extended the existing streaming sanitizer so a matched Remote response is
  captured only after large `aggregatedOutput` fields have been replaced by
  opaque spool descriptors. Capture is capped at 1 MiB minus envelope headroom;
  a larger response reports its exact sanitized size without being materialized
  or reinjected. Other-session-looking IDs and nested IDs remain on the desktop
  path.
- Added per-connection application queues bounded at 16 messages and 2 MiB, a
  1 MiB encoded-message ceiling, five-second socket writes, 30-second upstream
  request lifetime, and disconnect cleanup. Queue/byte/timeout exhaustion closes
  the socket and releases pending mappings instead of blocking heartbeat or
  retaining ambiguous requests.
- Added `tool/remote_smoke.dart`. A release Host plus the real stock app-server
  passed local ticket creation, hash-only pairing, WebSocket negotiation,
  `model/list` (8 models), one-row `thread/list`, metadata-only `thread/read`, no
  internal-ID leakage to local stdout, live policy-close revocation, temporary
  state cleanup, and zero Host exit. This proves the loopback read path on the
  current Linux runtime, not Android or non-loopback behavior.
- The Rust suite now passes 25 Remote-library tests, 38 Host-binary tests, and
  two executable failure-path tests (65 total); format, strict Clippy, the
  release build, and focused Dart analysis also pass.

### 2026-11-05 — Phase 4 authenticated loopback Remote foundation

- Added an opt-in `CODEX_NATIVE_REMOTE_LISTEN`/`--remote-listen` address. The
  parser and listener independently require a literal IPv4/IPv6 loopback
  address; wildcard, LAN, and hostname forms fail before bind, and the listener
  remains disabled by default.
- Added bounded `axum` 0.8.9/Tokio 1.54.1 HTTP and WebSocket endpoints on a
  dedicated runtime thread. HTTP bodies are capped at 8 KiB; WebSocket frames at
  256 KiB, messages at 1 MiB, the socket write buffer at 2 MiB, connections at
  eight, and the initial client hello at five seconds. Pairing is globally
  limited to ten attempts per minute for this loopback slice.
- Wired local one-use tickets to `/v1/pair`, returning the 256-bit device bearer
  once while persisting only its digest. `/v1/ws` requires the exact bearer and
  `codex-native-v1` subprotocol, performs the three-message negotiation, emits
  heartbeat pings, and rechecks expiry/revocation while connected. The
  unauthenticated health response intentionally omits the process session ID.
- Kept the reachable RPC surface deliberately read-only and narrow:
  `host/remote/status` proves authenticated request/response framing; every
  other method is rejected. Stock app-server IDs/events and write methods are
  not yet connected, so replay, correlation, and idempotency remain tested core
  primitives rather than an end-to-end network claim.
- A real TCP test covers health headers, ticket pairing and non-reuse, absence of
  the token from disk, unauthenticated rejection, subprotocol negotiation,
  read-only RPC, pre-handshake RPC rejection, live revocation, and rejected
  reconnect after revocation. A second active-socket shutdown test initially
  observed `ResetWithoutClosingHandshake`; connection-task draining and a
  shutdown broadcast now deliver an `Away` close frame within the bounded
  one-second drain window. Host cleanup stops Remote intake before stock Codex
  and no Remote error can skip child-process cleanup.
- The Rust suite passes 25 Remote-library tests, 31 Host-binary tests, and two
  executable failure-path tests (58 total), plus format and strict Clippy. A
  release build and real stock-Codex process smoke are recorded separately in
  the current verification section.

### 2026-11-05 — Phase 4 local Remote administration boundary

- Added a separate user-config credential-store location with an explicit
  `CODEX_NATIVE_REMOTE_DEVICE_FILE`/`--remote-device-file` override. If no secure
  config directory is available, local Codex still starts and Remote
  administration fails closed instead of falling back to a shared temporary
  directory.
- Integrated bounded local Host RPCs to create the one active five-minute
  pairing ticket, list public device metadata, and revoke an exact device ID.
  These methods never return a stored token digest or filesystem path; unknown
  parameters and missing IDs are rejected as invalid requests.
- Kept registry initialization lazy. A deterministic corrupt-store gate proves
  `host/status` remains available while the first Remote device call returns a
  generic internal error without leaking its path.
- A production release Host with stock app-server passed process-level
  `host/status`, ticket creation, and empty device-list JSONL calls, then exited
  cleanly on EOF. Stock app-server logged a shutdown-before-client-name warning
  because this management-only smoke deliberately did not initialize Codex; no
  process survived.
- The Rust suite now passes 25 Remote-library tests, 25 Host-binary tests, and
  two executable failure-path tests (52 total), plus format, strict Clippy, and
  the release build. A real network pairing exchange and live revocation remain
  unimplemented.

### 2026-11-05 — Phase 4 Remote protocol and device-auth core

- Added a reusable `codex_native_host::remote` library boundary without changing
  the production desktop stdio path. Typed client/server messages reject RPCs
  before `client_hello`, choose the highest common version, expose capabilities,
  and distinguish same-session replay from explicit gap/process-change resync.
- Added a strictly increasing event journal bounded independently by 512 events
  and 8 MiB by default. Count eviction, byte eviction, oversized single events,
  future cursors, and sequence exhaustion all fail closed; an unretained event
  creates an explicit replay gap rather than silently skipping data.
- Added monotonic ACK tracking and per-connection correlation namespaces. Equal
  client request IDs can coexist on different devices, while duplicate pending
  IDs on one connection, pending-count exhaustion, counter wrap, and disconnect
  cleanup are tested.
- Added a bounded same-session idempotency ledger keyed by device, method, and
  caller key plus a SHA-256 parameter fingerprint. It distinguishes pending,
  replayable result, pre-dispatch cancellation, and post-dispatch unconfirmed
  state; a result too large to retain becomes unconfirmed rather than
  re-executable.
- Added 256-bit device tokens from the operating-system random source,
  SHA-256-only persistence, constant-time digest comparison, typed scopes,
  expiry, rotation, revocation, last-seen state, and short-lived single-use
  pairing tickets. Unix credential files are atomically published as `0600`;
  symlinked, non-regular, foreign-owner, or group/world-accessible stores are
  rejected.
- The new Remote library has 25 unit tests. Together with the existing 23 Host
  binary tests and two executable failure-path tests, the Rust suite passes 50
  tests; format and `clippy --all-targets -D warnings` also pass. Network/TLS,
  concurrent registry writers, Windows ACL replacement semantics, live
  revocation, and physical Android behavior remain unclaimed.

### 2026-11-05 — Phase 4 Remote transport research and protocol decision

- Reviewed current official app-server stdio/Unix/WebSocket listener and
  authentication support, five upstream Remote failure reports, and three
  reference clients at pinned commits with Apache-2.0, PolyForm Noncommercial,
  and GPL licensing boundaries recorded.
- Confirmed that upstream WebSocket availability does not replace this project's
  Host: direct access would bypass the already-integrated bounded output spool,
  lifecycle, and future attachment boundary. ADR-010 keeps ordinary Codex RPC
  semantics while adding only a minimal Host-owned authenticated/resumable
  envelope.
- Defined local single-use pairing, hash-only device credential persistence,
  TLS-required non-loopback exposure, three-message negotiation, process session
  identity, sequence/ACK/resync rules, dual count/byte journal limits,
  correlation namespaces, same-session write idempotency, fail-closed pending
  interactions, bounded recovery reads, and chunked large-object transfer.
- Preserved negative evidence that socket authentication/readiness is separate
  from bounded hydration and live writer state, that large payloads can block
  recovery/control traffic, and that stale lifecycle results can overwrite newer
  navigation/turn state unless generation-scoped and monotonic.

### 2026-11-05 — Phase 3 Host storage-failure and shutdown gates

- Found and fixed a concrete session-budget leak: an output that had stored
  earlier chunks and was then abandoned or failed retained those byte counts
  after its partial file was removed, causing long sessions to hit the 2 GiB cap
  prematurely.
- Made output publication transactional across data flush/rename and metadata
  write/rename. Any unpublished path now closes the handle, removes data,
  metadata, and `.part` artifacts, releases its exact accounted bytes, and emits
  an unavailable descriptor instead of a broken reference or original output.
- Added deterministic Linux `/dev/full` coverage, abandoned-output reuse,
  post-data/pre-metadata failure cleanup, invalid-cache-root handling, and an
  executable-level unwritable-cache gate proving Host exits with bounded context
  before starting the configured Codex child.
- Added close-phase timing to runtime, thread, and real coding-task smokes. The
  current release Host closed in 108 ms after initialization, 58 ms after
  list/read/resume/start/delete, and 63 ms after a completed coding turn plus
  bounded output read; a fresh Linux release bundle closed its packaged Host in
  32 ms. The earlier approximately 6.1-second GUI fallback remains historical
  negative evidence but did not reproduce in these current stock-app-server
  paths, so shutdown budgets were not speculatively shortened.
- Added a Linux lifecycle soak that records each Host's direct Codex child from
  `/proc`, loads a bounded thread page, closes through production transport, and
  checks both PIDs and cache-session names. A 50-iteration release run observed
  50 distinct Codex children, 51 ms maximum/26 ms mean shutdown, zero surviving
  Host or Codex PIDs, and zero new session directories.

### 2026-11-05 — Phase 3 product interaction gates

- Added a production-App widget gate for the complete stored-command path:
  summary rows defer full turn items, the selected turn exposes one deferred
  command, explicit fetch reads only that item, and opening the viewer then
  reads only a 64 KiB tail window.
- Exercised truncated-output messaging and First/Previous/Next/Tail navigation
  against a 150,000-byte retained fixture. Assertions cover exact byte offsets,
  the three-byte UTF-8 look-ahead ceiling, and the absence of output-range calls
  before the corresponding user actions.
- Added a failed-tail-read gate proving the controller exposes the error, leaves
  no false chunk, and recovers only after an explicit retry.
- Added production-App gates for both dangerous execution overrides. Canceling
  `never` approval and `danger-full-access` preserves inherited Codex defaults;
  confirming each choice is required before those exact overrides reach the
  next real `TurnStartOptions`.
- Added a 4,000-line/2-file diff widget gate. The UI displays the bounded
  truncation warning and aggregate counts, builds the first visible line but not
  the off-screen last line, and switches to the second file without retaining a
  parallel rendered list.

### 2026-11-05 — Phase 3 bounded assistant Markdown

- Researched the current Codex TUI renderer, `flutter_markdown_plus`, Dart
  `markdown`, Flutter lazy-list behavior, and `url_launcher`; compared three
  broader/younger renderer alternatives and recorded exact adoption and
  non-adoption decisions in `docs/RESEARCH.md`.
- Added completed-only assistant Markdown with a project-owned extension
  allowlist for fenced code, tables, task lists, strikethrough, and autolinks.
  Block HTML is rendered literally, inline HTML is not enabled, remote/local
  images become bounded placeholders, and only user-clicked absolute
  `http`/`https` links can leave the app through the external launcher.
- Kept streaming messages as selectable plain text, relied on the existing
  lazy timeline rather than retaining parsed documents, and added a separate
  16 KiB rich-rendering cap with an explicit bounded plain-text tail fallback.
- Added direct third-party provenance, widget gates for formatting/HTML/image
  safety, URI allowlisting, streaming fallback, and pathological source caps,
  and retained the existing 1,000-row production-App lazy-build test.
- The first pathological widget gate sent a completed 64 KiB unbroken token to
  the renderer and kept `flutter_tester` busy for more than 30 seconds. That is
  preserved as a real negative performance result; the 16 KiB rich cap and
  plain-text fallback were introduced from it, and the capped rerun completed.
- Linux release packaging passed with the desktop launcher plugin. A normal
  Android build from the repository's Unicode path failed because Flutter's
  Gradle settings decoded the SDK path incorrectly. Repeating the native
  `assembleDebug` gate with a temporary ASCII SDK alias passed all 87 actionable
  tasks and produced the 145 MiB debug APK for arm64-v8a, armeabi-v7a, and
  x86_64; the ignored local SDK path was restored afterward.

### 2026-11-05 — Phase 3 Host integration and bounded output viewer

- Made the native Host the only production desktop process entry, with separate
  `CODEX_EXECUTABLE` and `CODEX_NATIVE_HOST` discovery and an explicit typed
  Host-not-found state instead of an unsafe direct fallback.
- Added Linux/Windows Cargo build-and-package rules, a macOS Xcode build/sign
  phase, and CI gates for Rust format, Clippy, tests, and the synthetic fixture.
- Added typed output descriptors, `stat`/range/tail adapters, strict response
  validation, deferred-item reads, stale-result guards, and a range-backed log
  viewer that keeps at most a 64 KiB page plus three UTF-8 look-ahead bytes.
- Item-list requests now send the forward-compatible
  `deferOutput.commandExecution` preference. Initialization explicitly opts into
  `experimentalApi`, which is required by the installed server for
  `thread/items/read`.
- Added a release synthetic app-server fixture that deliberately holds both its
  3/30/300 MiB source output and serialized response. Three Linux runs verified
  every descriptor and the first/tail 1 KiB. At 300 MiB, fixture RSS grew
  629,157,888/629,157,888/629,153,792 bytes, Host RSS had no observable growth
  at 2 ms sampling, and Dart RSS grew 2,281,472/4,431,872/2,211,840 bytes. These
  are synthetic Linux observations, not absolute or cross-platform guarantees.
- Real Host-routed runtime, thread, model, turn, interruption, approval-reject,
  history, coding-task, `thread/items/read`, and bounded output-tail paths passed.
  The coding task retained 7,443 output bytes behind an opaque Host reference and
  cleaned its exact test thread/workspace.
- The first enhanced coding smoke failed with `-32600: thread/items/read requires
  experimentalApi capability`. This was a real protocol-negotiation defect, not
  a flaky run; explicit capability negotiation fixed it and the rerun passed.
- Final range-view review found that the three UTF-8 look-ahead bytes were also
  rendered for ordinary ASCII pages, duplicating them on the next page. The
  decoder now consumes look-ahead only to finish a split scalar, and regression
  tests cover both ASCII non-duplication and split four-byte UTF-8.
- Added ADR-009 after official Flutter/Apple research: macOS v1 uses direct
  signed/notarized distribution rather than a Mac App Store sandbox.

### 2026-11-05 — Phase 3 native Host bounded-output core

- Researched current upstream Codex, its same-day experimental output deferral,
  three large-history failure reports, two incompatible-license reference
  clients, one permissive reference client, and incremental Rust JSON parsers;
  recorded exact adoption and non-adoption decisions in `docs/RESEARCH.md`.
- Added an Apache-2.0 Rust workspace and `codex-native-host`, pinning
  `json-skimmer` 1.0.0 behind an independently implemented streaming JSON-string
  decoder.
- The Host reads fixed-size stdout chunks, validates complete JSON candidates
  before atomically publishing them, extracts command output without retaining
  the scalar, preserves escape/Unicode semantics, and rejects malformed,
  truncated, over-depth, junk, or over-budget input.
- Added owner-only session/output files, per-output and per-session caps, stale
  inactive-session cleanup, opaque 128-bit references, path-traversal rejection,
  bounded base64 range/tail replies, parent-death handling on Linux, and bounded
  EOF/TERM/KILL child shutdown.
- Added 19 Rust tests covering every input fragmentation point, escapes,
  surrogate pairs, raw UTF-8, multiple/nested messages, truncation, malformed
  input, input budgets, permissions, range/tail semantics, traversal, and Host
  routing.

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
- `flutter test`: PASS, 99 tests, including 18 bounded Dart Remote transport
  tests and 9 credential/recovery tests.
- `flutter build linux --debug`: PASS.
- `dart run tool/runtime_smoke.dart`: PASS against the installed stock Codex; the initialize response identified Codex Desktop/app-server `0.166.0-alpha.5.1`.
- `dart run tool/thread_smoke.dart`: PASS against the installed stock Codex; listed 10 oldest threads, read and resumed an existing inactive thread without turns, started a smoke-owned persistent thread, and deleted that exact test thread.
- `dart run tool/turn_smoke.dart`: PASS against the installed stock Codex; a fixed-response turn completed with the expected marker, a second turn reached `turn/started`, interruption completed with status `interrupted`, and the smoke-owned thread was deleted.
- `dart run tool/approval_smoke.dart`: PASS against the installed stock Codex; an untrusted command produced a typed approval, the client rejected it, the turn completed, and the smoke-owned thread was deleted without executing the command.
- `dart run tool/model_smoke.dart`: PASS; the installed app-server advertised 8 visible models, identified `gpt-6.1-sol` as default, and advertised `low` as its default reasoning effort.
- `flutter test tool/coding_task_smoke.dart --reporter expanded`: PASS after history integration in 29 seconds; production controllers completed the exact temporary-file task, projected one changed file/one addition, observed zero approvals, paged back one turn/nine items, and cleaned both thread and workspace.
- `flutter test tool/history_memory_benchmark.dart --reporter expanded`: PASS twice; 1,000 source turns retained 100. RSS deltas were 1,482,752/1,564,672 bytes for turn paging and 29,085,696/31,879,168 bytes for ten sequential 3 MiB discarded outputs. These are Linux debug-test measurements, not cross-platform guarantees.
- `cargo fmt --all -- --check`: PASS.
- `cargo clippy --workspace --all-targets -- -D warnings`: PASS.
- `cargo test --workspace`: PASS, 25 Remote-library tests, 47 Host-binary tests,
  and 3 executable failure-path tests (75 total), including real TCP/WSS,
  exact event replay/gap recovery, abrupt reconnect, slow-reader disconnection,
  live revocation, certificate trust/rotation/rollback, protocol-close shutdown,
  deterministic storage failure, and cache/TLS startup gates.
- `cargo build --release --workspace`: PASS.
- Release `codex-native-host` real-runtime smoke: PASS; one process carried a
  Host status request plus stock app-server initialize/initialized and reported
  Codex Desktop/app-server `0.166.0-alpha.5.1`. This isolated smoke established
  the handshake and clean EOF shutdown before Flutter integration.
- Release Host Remote-foundation smoke: PASS in 333 ms against the same stock
  app-server. The process bound an ephemeral loopback port, reported
  `enabled=true`, `scope=loopback`, and `tls=false`, created a redacted local
  one-use pairing ticket, completed initialize/initialized, and exited zero on
  EOF without leaving a device credential file. The first harness attempt was
  invalid because its absent `jq` consumer caused stdout `Broken pipe`; it was
  not counted as a product pass or failure.
- `dart run tool/remote_smoke.dart`: PASS in 10.777 seconds against release Host
  and stock app-server. It paired without plaintext token persistence, negotiated
  `codex-native-v1`, read 8 models, listed and metadata-read a real thread,
  observed no internal ID on local stdout, live-revoked the device, removed its
  temporary state, and observed Host exit code zero.
- TLS-configured `dart run tool/remote_smoke.dart`: PASS in 10.828 seconds
  against release Host and the same stock app-server. The Host bound
  `0.0.0.0:0`, reported `scope=network`/`tls=true`, and Dart trusted the generated
  self-signed certificate only through an explicit `SecurityContext`; pairing,
  WSS negotiation, eight-model and metadata-thread reads, internal-ID isolation,
  live revocation, temporary-state cleanup, and zero Host exit all passed.
- `dart run tool/host_memory_benchmark.dart`: PASS three times for 3/30/300 MiB.
  Fixture deltas were 6,303,744/62,926,848/629,157,888,
  6,303,744/62,926,848/629,157,888, and
  6,299,648/62,922,752/629,153,792 bytes; Host deltas were 0/0/0 bytes at 2 ms
  sampling; Dart deltas were 57,344/774,144/2,281,472,
  36,864/765,952/4,431,872, and 49,152/630,784/2,211,840 bytes. First/tail reads
  matched the complete spooled payload in every case.
- `flutter build linux --debug` and `flutter build linux --release`: PASS with
  an executable packaged `codex-native-host` beside the Flutter binary and the
  native URL-launcher plugin.
- Fresh Linux release-bundle Host runtime smoke after transactional storage
  recovery: PASS against stock Codex with a measured 32 ms close phase.
- `flutter build apk --debug` from the real Unicode repository/SDK path: FAILED
  before compilation because `android/settings.gradle.kts` observed the SDK as
  `/home/axiaobo/ææ¡£/flutter`. With only the ignored
  `android/local.properties` temporarily pointed at an exact ASCII symlink,
  `./gradlew assembleDebug` passed 87 actionable tasks and produced a 145 MiB
  debug APK with arm64-v8a, armeabi-v7a, and x86_64 native outputs. The file and
  symlink were restored/removed afterward. This proves the Android product and
  plugin build under the path workaround, not a clean ordinary-path build.
- Packaged Linux GUI runtime launch: PASS; direct process inspection showed
  Flutter -> adjacent bundled Host -> separately located stock Codex. SIGINT
  removed all three processes. Existing ATK/cursor-theme warnings remained.
- Host-routed `runtime_smoke`, `thread_smoke`, `model_smoke`, `turn_smoke`, and
  `approval_smoke`: PASS. The approval smoke rejected rather than approved its
  command as designed. Current close-phase measurements were 108 ms for the
  initialization-only runtime smoke and 58 ms after the thread smoke's
  list/read/resume/start/delete lifecycle.
- Enhanced `coding_task_smoke`: first run FAILED at the newly exercised
  `thread/items/read` capability gate; after declaring `experimentalApi`, rerun
  PASS in 27 seconds with 11 history items and a verified 7,443-byte Host output
  spool/tail.
- Final packaged-release reruns after strict output reference/range/EOF
  validation: PASS in 21/27 seconds with 9/10 history items, readable 6-byte
  selected command outputs, and exact test thread/workspace cleanup.
- Real coding-task rerun after transactional storage recovery: PASS in 23
  seconds with 9 history items, a readable 6-byte output spool, exact thread and
  workspace cleanup, and a measured 63 ms Host shutdown.
- `CODEX_NATIVE_SOAK_ITERATIONS=50 dart run tool/host_lifecycle_soak.dart`: PASS;
  50 Host/Codex process pairs, 51 ms maximum and 26 ms mean close, zero surviving
  PIDs, and zero new cache sessions.
- Real Linux GUI launch after the model/diff slice: PASS; the connected runtime, thread list, empty conversation state, and loaded `Defaults` execution-control entry rendered correctly in direct inspection. SIGINT produced a coordinated exit, and neither the Flutter process nor its app-server child survived.
- Secret/credential scan: PASS; no token, private-key, bearer, or assigned credential patterns found in the repository scope.
- Hosted GitHub Actions CI: NOT RUN for the local changes.
- Windows/macOS builds and physical-device validation: NOT RUN in this Linux environment.

## Known risks / watch items

- Direct `flutter analyze` from this repository's Unicode filesystem path currently crashes Flutter 3.47.1's LSP byte-stream parser with a truncated initialization JSON message. The same source passes `dart analyze --fatal-infos` at the real path and `flutter analyze` through an ASCII symlink. This is preserved as a toolchain/path issue, not recorded as a clean direct-path run.
- The same Unicode-path toolchain defect affects Android settings evaluation:
  ordinary `flutter build apk --debug` corrupts the Flutter SDK path before
  compilation. A temporary ASCII SDK alias proves `assembleDebug` itself passes,
  but the normal developer command is still blocked on this filesystem layout.
  The passing build also reported Gradle-10/AGP-9 migration warnings, an ignored
  legacy manifest `package` attribute in `url_launcher_android`, and an Android
  SDK XML version skew; none was promoted to a clean warning-free gate.
- Dart 3.13 exposes an inbound WebSocket frame cap, not an aggregate fragmented-
  message cap. The client sets it to 1 MiB, disables compression, and also
  rejects any delivered combined message above 1 MiB; the authenticated Host
  independently caps each message and emits it as one frame. This is bounded
  for the trusted Host implemented here, not proof that a compromised
  authenticated Host cannot fragment a larger message and cause a transient
  client allocation before the combined check. There is no accept-all TLS path.
- `flutter_secure_storage` 11.2.0 has an open Android issue in which a transient
  Keystore lookup can return null and cause its RSA wrapping pair to be replaced
  before `resetOnError` is consulted. This project disables automatic reset and
  surfaces unreadable/corrupt state without deleting it, but cannot recover an
  already replaced non-exportable key. Because the Remote bearer is revocable,
  explicit clear and re-pair is the bounded recovery; real device fault testing
  and an upstream fix or re-evaluation remain release gates.
- Safe assistant Markdown intentionally differs by lifecycle and size:
  in-progress messages are plain text, and completed messages above 16 KiB show
  only a labeled bounded tail rather than rich formatting. Actual external
  browser activation, selection behavior, and visual fidelity still require
  Human validation; local workspace/file links are deliberately blocked until
  an explicit cwd/path authorization policy exists.
- A successful `turn/start` response does not prove the server has installed the turn as interruptible. Real validation observed `turn/interrupt` fail with `-32600` when sent before `turn/started`; the UI now waits for the notification before exposing Stop.
- Approval approve-once serialization and controller behavior are covered by tests, but no real command or file mutation was approved during automated validation. The real smoke deliberately validated rejection only; Human approval UX remains a separate gate.
- The dangerous execution-setting confirmation dialogs and populated diff view have not received Human visual/interaction acceptance. Their protocol/controller/parser behavior is machine-tested, and the main GUI surface was directly inspected, but those are distinct claims.
- Stock app-server `0.166.0-alpha.5.1` does expose experimental
  `thread/items/read` for 1–100 item IDs, correcting the earlier project note that
  no per-item request existed. It still has no byte-range API and embeds the
  selected command's complete `aggregatedOutput` in one JSON response. Current
  upstream main can defer completed successful command output in
  `thread/items/list`, but the follow-up read is still whole-item. The Host can
  bound its own and Flutter's handling; it cannot remove app-server's preceding
  full-string serialization allocation.
- The 3/30/300 MiB memory gate uses a purpose-built serializer-shaped fixture,
  not a real Codex thread containing a 300 MiB command result. Its strong
  sublinear Host/Dart evidence does not establish real app-server RSS, Windows or
  macOS allocator behavior, real installed-filesystem exhaustion/recovery, or
  Human log-viewer acceptance. Linux `/dev/full` output failure and invalid or
  unwritable cache startup are now deterministic gates, but are not equivalent
  to filling each supported platform's installed cache volume.
- `thread/items/read` requires the negotiated experimental API capability in the
  installed server. Protocol adapters and tests cover this version, but future
  schema changes remain a compatibility risk.
- macOS App Sandbox was deliberately removed because all Codex child processes
  inherit the parent sandbox and cannot reproduce ordinary workspace/toolchain
  access. Developer ID signing, hardened-runtime nested Host signing,
  notarization, workspace access, and cleanup require a real macOS release gate.
- Unix spool directories/files are explicitly restricted to `0700`/`0600`.
  Windows currently relies on the user cache directory's inherited ACL; a real
  Windows gate must inspect it and add an explicit owner-only ACL if inheritance
  is not sufficiently restrictive. The current macOS Cargo phase also produces
  only the active build architecture, not a universal Host binary.
- Re-reading the same upstream command item creates another session-scoped spool
  object. The 2 GiB session cap prevents unbounded disk growth and UI actions do
  not automatically reread a loaded item, but deduplication or explicit release
  remains unresolved for very long sessions.
- The real GUI launch logged host GTK/Wayland warnings for ATK socket embedding and a missing cursor-theme asset. They did not prevent the window, handshake, or child cleanup, but should be rechecked during later Linux UI work.
- Live thread validation established three upstream lifecycle constraints: an ephemeral empty thread has no readable rollout; a new persistent empty thread is also unreadable until its first turn materializes a rollout; and resuming a thread owned by another app-server fails with `already has an active writer`. The UI/controller must not treat those cases as generic transient retries.
- A prior GUI run after loading thread state did not exit within the 3-second
  stdin-EOF window or the following 3-second SIGTERM window; SIGKILL completed at
  about 6.1 seconds and no child survived. Current release runtime/thread/coding
  smokes closed in 108/58/63 ms and a freshly packaged runtime smoke closed in
  32 ms; none reproduced the fallback. Preserve the earlier negative result and
  recheck during installed-build/platform soak, but do not present it as current
  deterministic latency.
- The app-server protocol evolves; version differences must stay inside typed protocol adapters.
- The loopback Remote Codex path currently depends on the local desktop client
  completing the one stock app-server initialize/initialized handshake. It does
  not yet define a headless Host lifecycle. Sanitized synthetic/TCP gates prove
  event publication and replay, but the current real stock-app-server smoke does
  not start a turn and therefore does not prove a live stock turn notification.
- Operator-provided WSS is implemented and same-host release-tested, but the test
  connected through loopback to a wildcard listener. Real LAN routing, host
  firewall discovery, CA chain/renewal under installed service accounts, Windows
  private-key ACLs, Android platform trust, background reconnect, and pairing-
  bound self-signed identity remain unverified. No Android code accepts arbitrary
  bad certificates.
- Long-running sessions must not cause Flutter to hydrate unbounded history.
  Turn/item/live-entry/output-window/Markdown caps and Linux synthetic memory
  evidence now exist, but real app-server RSS and cross-platform installed-build
  profiling remain required Phase 3 evidence.

## Next action

Build the Android lifecycle/reconnect and authoritative hydration owner around
the now-tested read-only `RemoteTransport` and recoverable system-CA credential
record:

1. add a lifecycle/reconnect coordinator with bounded backoff, persisted
   session/sequence only after applied events, initial and gap-triggered bounded
   authoritative reads, stale-attempt rejection, and explicit revoked/lost-key
   states. Dart automatically handles WebSocket ping/pong control frames; the
   coordinator must still own application readiness and request-timeout recovery;
2. keep the cursor outside the secret record and persist it only after the
   corresponding projection mutation succeeds; a fresh session, invalid cursor,
   gap, or resync marker must discard incremental assumptions and rebuild only
   bounded model/thread metadata;
3. design the local self-signed pairing artifact so certificate/CA identity is
   authenticated and stored through a new explicit record version; never use
   `badCertificateCallback` as onboarding;
4. integrate Android runtime state only after reconnect and hydration boundaries
   are real, then
   exercise Host restart/session change, revocation, malformed/oversized input,
   bounded hydration, and process/background lifecycle in Dart tests and the
   available emulator/device/build gates. Keep server requests/approvals and
   writes rejected until pending interaction state and idempotency are wired end
   to end.

Preserve the unavailable Phase 3 Human, Windows/macOS, physical-Android, and
installed-volume gates as RC requirements.

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
