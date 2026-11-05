# Research Notes

This document records implementation-relevant findings from upstream Codex and
other working clients. It is not a catalog of projects or an endorsement of
their architecture. Upstream behavior and measurements in this repository remain
authoritative.

## Large app-server output and the native Host boundary

_Reviewed: 2026-11-05_

### Sources reviewed

- OpenAI Codex main at
  [`e7f32cf`](https://github.com/openai/codex/commit/e7f32cf1928a35a9232a633a51c2a03b5a7e2c72),
  including `app-server`, `app-server-protocol`, and `app-server-transport`.
- The locally installed Codex `0.166.0-alpha.5.1` experimental JSON schema,
  generated on 2026-11-05 with `codex app-server generate-json-schema
  --experimental`.
- OpenAI Codex PR
  [#59601](https://github.com/openai/codex/pull/59601), which added experimental
  command-output deferral to `thread/items/list` on 2026-11-05.
- OpenAI Codex reports
  [#55005](https://github.com/openai/codex/issues/55005),
  [#39860](https://github.com/openai/codex/issues/39860), and
  [#46690](https://github.com/openai/codex/issues/46690) for real large-history,
  Remote envelope, and renderer-memory failure evidence.
- [`json-skimmer` 1.0.0](https://docs.rs/json-skimmer/1.0.0/json_skimmer/),
  its source, validation notes, and retained resource measurements. License:
  MIT.
- TuxCodex at
  [`1905fc4`](https://github.com/MoussaKassim/TuxCodex/commit/1905fc4c80ee05379c1fa2d24062e04148bfdbb2).
  License: MIT.
- `codex-remote` at
  [`fcdf784`](https://github.com/Venompool888/codex-remote/commit/fcdf784e6365735ad9efde5cb43c5126042f4556).
  License: PolyForm Noncommercial 1.0.0; its code is research-only for this
  Apache-2.0 project.
- `mobile-codex` at
  [`107e7d7`](https://github.com/nokryong/mobile-codex/commit/107e7d73a4cb3285408b90242b37d5d7de49fbf5).
  License: GPL-3.0; its code is research-only for this Apache-2.0 project.

### Upstream facts

- App-server stdio is newline-delimited JSON, but the current implementation is
  not a streaming serializer. Its stdio writer first calls
  `serde_json::to_string(&outgoing_message)`, queues the resulting `String`, and
  only then writes it to stdout. Therefore a large `aggregatedOutput` is already
  materialized inside app-server before any sidecar can receive it. The Host can
  bound its own and Flutter's working sets, but cannot remove that upstream
  app-server allocation.
- The installed `0.166.0-alpha.5.1` protocol already has experimental
  `thread/items/read` for 1-100 IDs. It does **not** provide byte ranges and its
  response still embeds a full `aggregatedOutput` string. Previous project notes
  that said there was no per-item API were imprecise and must be corrected.
- Codex main now accepts
  `deferOutput: {"commandExecution": true}` on a single-turn
  `thread/items/list`. For a completed, successful command with non-empty saved
  output, the list entry carries `outputDeferred: true` and
  `aggregatedOutput: null`; the client then uses `thread/items/read` for the
  selected item. Older app-server versions ignore this unknown request field, so
  sending it is a useful forward-compatible preference, not sufficient protection
  by itself.
- `thread/items/read` on current main still returns the complete selected item in
  one JSON response. No offset/range command-output API exists in the reviewed
  schema. A bounded client-side output transport is still needed for the actual
  read.
- Upstream issue evidence is consistent with payload size being a real product
  boundary: multi-megabyte full-history replies correlate with mobile timeouts,
  unbounded thread previews can break initial Remote loading, and repeated history
  hydration has coincided with renderer heap exhaustion. These reports do not by
  themselves prove one shared defect, but they justify byte limits, explicit
  pagination, cancellation, and no automatic history draining.

### Reference-client observations

- TuxCodex supervises app-server carefully enough to reject stale events from a
  replaced child and has a useful compatibility pattern: retry only when the
  server specifically rejects a newer permission enum spelling. However, its
  bridge uses `BufReader::lines`, parses every complete line into
  `serde_json::Value`, and sends `aggregatedOutput` into React state. This is the
  exact large-payload materialization pattern we must not adopt.
- `codex-remote` has strong remote-security ideas: opaque device credentials,
  hashed Host storage, scoped authorization, idempotency keys, bounded outbound
  queues, device-bound attachment IDs, and no client-selected Host paths. Its
  current app-server bridge still uses Node `readline` plus `JSON.parse`, so Host
  request budgets and outbound caps apply only after a whole app-server line has
  entered memory. It also reconstructs some history directly from rollout files;
  that is a deliberate non-adoption because app-server remains this project's
  authoritative integration boundary.
- `mobile-codex` returns only the newest 40 display messages initially, loads
  older pages only after upward navigation, preserves the reading anchor, rejects
  cross-thread/stale cursors, and discards in-flight results after navigation.
  Those are useful regression-test ideas. We will implement the behavior
  independently because its GPL-3.0 code is not compatible with this project's
  Apache-2.0 distribution goal.

### Incremental JSON options

- `serde_json::from_reader`, line readers, and NDJSON adapters that deserialize a
  full value still materialize the large string. They only move the peak from
  Dart to Rust.
- `json-event-parser` is a streaming event parser, but its string event owns a
  complete `String`; that API does not solve a single huge scalar token.
- `json-skimmer` exposes borrowed raw string fragments from arbitrary byte chunks,
  validates JSON grammar and UTF-8, bounds nesting, and documents memory
  proportional to structural depth rather than scalar length. Its fragment
  boundaries may split UTF-8 and escape sequences, so a consumer must implement a
  correct incremental JSON-string decoder. Version 1.0.0 is recent, so adoption
  requires pinning, extensive split-boundary tests, malformed-input tests, and
  independent RSS measurements rather than relying only on upstream claims.

### Decision for this project

Adopt a lightweight Rust `codex-native-host` as the production desktop runtime
boundary and future Remote Host, while keeping stock app-server semantics intact.

For app-server stdout:

1. Read fixed-size byte chunks, never lines.
2. Use `json-skimmer` only for incremental JSON grammar/events.
3. Independently decode the targeted `aggregatedOutput` JSON string across
   arbitrary fragments, including escapes, surrogate pairs, and raw UTF-8.
4. Write decoded output directly to a restrictive, bounded session spool file.
5. Write the sanitized ordinary JSON candidate to a temporary file and publish it
   to Flutter only after the parser reports a valid complete candidate. Replace
   the large field with `null` plus an opaque output descriptor; never expose a
   filesystem path.
6. Prefer upstream `deferOutput` on listing requests when supported. The Host
   transform remains the compatibility and full-item-read safety net.

The temporary sanitized-candidate file avoids retaining the whole JSON message
while also preventing a malformed partial candidate from being forwarded before
validation. Host output APIs will provide bounded `stat`, `readRange`, and `tail`
operations over opaque IDs. Per-read, per-output, and total-session limits are
mandatory.

### Deliberate non-adoptions

- Do not parse app-server stdout with `read_line`, `lines`, `JSON.parse`, or
  `serde_json::from_str` before removing large scalar content.
- Do not expose spool paths or accept arbitrary file paths from Flutter/Remote.
- Do not read Codex rollout files to replace protocol behavior.
- Do not copy PolyForm Noncommercial or GPL implementation code.
- Do not introduce SQLite for output blobs; ordinary files match the current
  lifecycle and streaming requirements.
- Do not claim that the Host fixes app-server's own serialization peak. Measure
  app-server, Host, and Flutter separately.

### Validation required here

- Parser/decoder tests must cover every-byte fragmentation, multiple messages per
  chunk, escaped quotes and slashes, control escapes, Unicode escapes and
  surrogate pairs, raw multibyte UTF-8, nested objects, malformed/truncated JSON,
  depth limits, disk errors, cache limits, and path traversal attempts.
- End-to-end tests must prove request correlation, notifications, approvals,
  lifecycle cleanup, stale-cache cleanup, and bounded range/tail reads through the
  Host.
- Release-mode benchmarks must exercise approximately 3 MiB, 30 MiB, and 300 MiB
  synthetic outputs. Record baseline, ingest peak, and post-ingest RSS for the
  app-server fixture, Host, and Flutter process. Success means Flutter and Host
  deltas remain bounded/sublinear; app-server is reported separately.
- A real installed app-server smoke must still pass initialization, thread/turn
  flows, approvals, interruption, history, and one coding task through the Host.

## Desktop packaging and the macOS process model

_Reviewed: 2026-11-05_

### Sources reviewed

- Flutter's official
  [desktop build](https://docs.flutter.dev/platform-integration/desktop) and
  [macOS distribution](https://docs.flutter.dev/platform-integration/macos/building)
  documentation.
- Apple's official
  [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox),
  [sandbox inheritance](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html),
  and
  [embedded command-line tool](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app)
  documentation.

### Findings and decision

- Flutter's release artifacts are ordinary native desktop bundles; the Host must
  be built and copied as part of each platform's native build rather than found
  accidentally in a repository `target` directory.
- Apple supports embedded command-line helpers, but a sandboxed child inherits
  only its parent's static sandbox rights. Rights granted after launch, such as
  user-selected file access, are not automatically inherited. Mac App Store
  distribution requires App Sandbox.
- Stock Codex must access arbitrary user-selected development workspaces and run
  their toolchains. That cannot be made equivalent to a normal Codex shell by
  embedding only the Host with sandbox inheritance.
- Therefore macOS v1 is a direct, notarized distribution with App Sandbox
  disabled. The Host is nested in `Contents/MacOS`, signed during the build, and
  located beside the Flutter executable. Real macOS signing, notarization, child
  launch, workspace access, and cleanup remain platform gates because this Linux
  environment cannot execute them.

## Bounded assistant Markdown rendering

_Reviewed: 2026-11-05_

### Sources reviewed

- OpenAI Codex's current
  [TUI Markdown renderer](https://github.com/openai/codex/blob/main/codex-rs/tui/src/markdown_render.rs)
  and the `0.166.0` release notes covering consistent transcript Markdown.
- The maintained
  [`flutter_markdown_plus` 1.0.12](https://pub.dev/packages/flutter_markdown_plus)
  renderer, its source, changelog, layout modes, and link/image hooks. License:
  BSD-3-Clause.
- The Dart team's
  [`markdown` 7.3.1](https://pub.dev/packages/markdown) parser and extension-set
  documentation. License: BSD-3-Clause.
- Flutter's official lazy
  [`ListView.builder`](https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html)
  behavior and the official
  [`url_launcher` 6.3.3](https://pub.dev/packages/url_launcher) URI API. License:
  BSD-3-Clause.
- `gpt_markdown`, `flutter_md`, and `markdown_widget` were compared as alternative
  renderers. The first brings unrelated network/SVG/LaTeX dependencies, the
  second is only days old, and the third has a broader navigation/visibility
  dependency surface than this first native transcript slice needs.

### Findings and decision

- Current official Codex renders transcript Markdown with fenced code, tables,
  lists, task lists, links, and width-aware layout. It does not render Markdown
  images in the TUI and treats raw HTML as text rather than executing it.
- Dart `markdown` explicitly provides no HTML sanitization. Its predefined
  CommonMark and GitHub extension sets include `InlineHtmlSyntax`, so selecting
  a named preset is not a sufficient security policy even though
  `flutter_markdown_plus` itself is not an HTML engine.
- Use `flutter_markdown_plus` only with a project-owned extension allowlist:
  fenced code, tables, task lists, strikethrough, and autolinks. Do not enable
  `InlineHtmlSyntax`, emoji shortcodes, LaTeX, syntax-highlight grammar bundles,
  or custom web UI in this slice. Wrap the parser's built-in block-HTML syntax
  so its source is rendered literally as paragraph text rather than discarded;
  no HTML is interpreted or executed.
- Render every image reference as a bounded textual placeholder. Never let
  assistant Markdown initiate network, asset, or local-file reads.
- Link activation is user-initiated and allowlisted to `http`/`https`; launch it
  in an external application. Reject `file`, `data`, `javascript`, custom, and
  relative schemes. Local workspace links need a later explicit path/cwd policy.
- Completed assistant messages render Markdown. In-progress streaming messages
  remain selectable plain text so coalesced token updates do not repeatedly
  parse an incomplete document. The outer lazy timeline determines which
  messages are built; there is no global AST cache. Source size remains bounded
  by the existing 64 KiB live-entry and 8 KiB history limits. The rich renderer
  has a stricter 16 KiB fail-safe; larger completed messages show a bounded
  selectable plain-text tail with an explicit omission marker.

### Deliberate non-adoptions and validation

- Do not render through HTML or WebView, fetch remote images, open arbitrary URI
  schemes, retain ASTs for inactive/off-screen threads, or add a second nested
  vertical scroller.
- Do not adopt a streaming-specific renderer until profiling demonstrates that
  completed-only rendering is an unacceptable UX tradeoff.
- The first widget gate showed that a 64 KiB unbroken token could keep the test
  renderer busy for more than 30 seconds. That negative result is the reason for
  the separate 16 KiB rich-rendering cap and plain-text fallback; normal
  formatted content and the capped pathological case must both remain tested.
- Widget tests must cover formatting, raw HTML as inert text, blocked images and
  URI schemes, external `http`/`https` activation, streaming fallback, source
  caps, and the existing 1,000-item lazy-build boundary.

## Android Remote transport, pairing, and resume

_Reviewed: 2026-11-05_

### Sources reviewed

- OpenAI Codex main at
  [`e7f32cf`](https://github.com/openai/codex/commit/e7f32cf1928a35a9232a633a51c2a03b5a7e2c72),
  especially the CLI listener selection, app-server transport authentication,
  app-server README, and WebSocket test client. License: Apache-2.0.
- OpenAI Codex Remote failure reports
  [#39954](https://github.com/openai/codex/issues/39954),
  [#37967](https://github.com/openai/codex/issues/37967),
  [#55005](https://github.com/openai/codex/issues/55005),
  [#41573](https://github.com/openai/codex/issues/41573), and
  [#36189](https://github.com/openai/codex/issues/36189). These are incident
  evidence, not one proven shared root cause.
- `codex-remote` at
  [`fcdf784`](https://github.com/Venompool888/codex-remote/commit/fcdf784e6365735ad9efde5cb43c5126042f4556),
  including protocol v2, Host auth/server code, Android reconnect code, and the
  lifecycle reconciliation audit. License: PolyForm Noncommercial 1.0.0;
  implementation code is research-only for this Apache-2.0 project.
- `codex-remote-android` at
  [`372581a`](https://github.com/liuhao-labs/codex-remote-android/commit/372581ad5cc66677d5322a9a447a03277d36ce15),
  including its SSH transport, host-key confirmation, encrypted credentials,
  bounded initial history, and upward pagination. License: Apache-2.0.
- `mobile-codex` at
  [`107e7d7`](https://github.com/nokryong/mobile-codex/commit/107e7d73a4cb3285408b90242b37d5d7de49fbf5),
  including phone/tablet navigation, draft ownership, stale-turn guards, and
  bounded diff/preview presentation. License: GPL-3.0; implementation code is
  research-only for this Apache-2.0 project.
- Rust `getrandom` 0.4.3 for direct operating-system randomness, RustCrypto
  `sha2` 0.11.0 for token/parameter digests, and `subtle` 2.6.1 for constant-time
  digest comparison. All are permissively licensed. `sha2` is pinned to 0.11.0
  because 0.11.1 requires Rust 1.88 while this Host declares Rust 1.87; 0.11.0
  supports Rust 1.85.

### Upstream and failure evidence

- Current stock `codex app-server` can listen on stdio, Unix sockets, or a TCP
  WebSocket address. Its WebSocket transport supports a capability token file,
  a precomputed SHA-256 token hash, or signed bearer credentials. Upstream also
  states that remote-control peers still need a device authenticator.
- Direct Android-to-app-server WebSocket access would bypass this project's
  already-required Host output transformation, spool budgets, lifecycle
  supervision, and future attachment boundary. Availability upstream therefore
  changes implementation options, not ADR-008's ownership.
- An authenticated socket is not equivalent to a usable hydrated client. Real
  reports show connections that initialize/list successfully while large-thread
  hydration loops or times out; some mobile-to-Host writes can persist while
  read-side hydration is still broken.
- Full-history replies can be orders of magnitude larger than summary pages.
  Large payload handling must not block ping/pong or fill an unbounded outbound
  queue, and reconnect must never silently duplicate a write whose outcome is
  unknown.
- A second app-server process is not a safe way to obtain remote writer access:
  the local real-runtime gates already show active-writer ownership, and remote
  reports distinguish live writer state from persisted paged history.
- Reference lifecycle audits found stale completion, late delta, navigation,
  and reconnect results overwriting newer state. Terminal evidence must be
  monotonic and results must be scoped to a connection/session/navigation
  generation; assistant text alone never proves completion.

### Decision for this project

The Rust Host owns an explicitly enabled Remote listener and wraps sanitized
app-server JSON-RPC in a small authenticated, resumable envelope. Ordinary Codex
method names and typed adapter semantics remain protocol-native; only `host/*`
operations belong to this project. The envelope must not become a parallel agent
or feature RPC schema.

The initial protocol has these invariants:

1. The listener is disabled by default and binds loopback unless the user
   explicitly configures remote exposure. Non-loopback exposure requires TLS;
   plaintext WebSocket is limited to loopback/test use.
2. Pairing is initiated from a local trusted Host surface with one short-lived,
   single-use ticket. Success returns one cryptographically random 256-bit
   device token exactly once. The Host persists only its SHA-256 digest plus a
   bounded device name, scopes, creation/expiry/last-seen/revocation metadata,
   using owner-only atomic storage and constant-time digest comparison.
3. A three-message `server_hello` / `client_hello` / `hello_ack` negotiation
   selects a common version and capabilities before any RPC is accepted. The
   Host advertises a process-scoped session ID and current event sequence.
4. Every replayable event has a strictly increasing sequence. The client ACKs
   its highest contiguous sequence. Replay is allowed only for the same Host
   session and a retained continuous suffix; a process change or missing gap
   returns `resyncRequired` and forces bounded authoritative reload.
5. The journal is bounded by both item count and serialized bytes. Each inbound
   message, outbound message, and per-connection queued byte total also has a
   hard cap. Control/heartbeat progress must not wait behind large application
   payloads.
6. Multiple clients cannot share raw app-server request IDs. The Host gives each
   connection a namespace/remaps correlation IDs, then returns the client's
   original ID only to that connection.
7. Remote write methods require an idempotency key. The Host may replay a cached
   outcome only inside the same authoritative Host session; after Host restart,
   an unconfirmed operation is reported as unknown and is never silently
   retried.
8. Pending approval/input requests are durable protocol state independent of the
   volatile event suffix. They have Host-generated opaque IDs, scopes and
   deadlines, are replayed only to eligible devices, and fail closed when stale,
   superseded, or already answered.
9. Initial and recovery reads reuse existing bounded thread/turn/item pagination.
   The client never auto-drains every thread or complete history merely because
   a socket connected.
10. Large attachments and command output do not travel as base64 WebSocket
    frames. They use separately authenticated, device-bound, chunked transfers
    with exact total size, range, per-chunk and whole-object integrity, quotas,
    expiry, and opaque references.

Android will store the issued device secret with platform-backed secure storage
when the device slice is implemented. The first Host slice should establish the
pure protocol/auth/replay state machine and its adversarial tests before adding a
network library, so listener behavior cannot define ambiguous semantics by
accident.

### Deliberate non-adoptions

- Do not connect Android directly to stock app-server or expose its raw listener
  on a LAN.
- Do not make SSH/general remote-shell credentials the default Remote transport;
  it remains a possible explicit future adapter, not a pairing substitute.
- Do not copy PolyForm Noncommercial or GPL implementation code.
- Do not reproduce a feature-by-feature Remote RPC allowlist that drifts from
  app-server, and do not read rollout files to synthesize protocol state.
- Do not use a count-only replay journal, a 64 MiB socket backlog, automatic
  full-history hydration, or base64 attachment bodies as this project's bounds.
- Do not resend writes or approval answers across a changed Host session merely
  because the mobile process still has a queued request.

### Validation required here

- Protocol tests must cover incompatible versions, pre-handshake RPC rejection,
  exact gap boundaries, duplicate/out-of-order ACKs, session changes, item and
  byte eviction, one oversize event, integer overflow, ID namespace collisions,
  stale generations, and idempotency-key parameter mismatch.
- Auth tests must cover ticket expiry/single use, token entropy/format, constant-
  time digest matching, rotation/revocation/expiry, corrupt storage, atomic
  owner-only persistence, rate budgets, and live revocation.
- Network tests must cover loopback-only defaults, refusal of plaintext
  non-loopback exposure, handshake deadlines, message/backlog caps, slow readers,
  ping/pong under application load, abrupt disconnect, TLS configuration, and no
  surviving Host/Codex process.
- End-to-end recovery must prove no missing or duplicate events within a retained
  same-session suffix, explicit bounded resync beyond it, no duplicate writes,
  fail-closed approvals, bounded hydration, and output/attachment range transfer.
- Real Android physical-device gates must include background/foreground, Wi-Fi
  changes, Doze, process death, credential revocation, Host restart, large
  threads, active turns, approval races, and phone/tablet presentation.

### Initial Rust network stack selection

_Reviewed: 2026-11-05_

- `axum` 0.8.9 is MIT-licensed, supports Rust 1.80, and provides HTTP routing
  plus WebSocket upgrade on the Tokio/Hyper stack. Its WebSocket configuration
  exposes read/write buffer, maximum write-buffer, frame, and complete-message
  limits. The defaults are not acceptable here: 64 MiB messages, 16 MiB frames,
  and an unlimited maximum write buffer must all be overridden.
- `tokio` 1.54.1 is MIT-licensed and supports Rust 1.85. Its bounded MPSC channel
  has an explicit item capacity and supports sync/async boundaries. Unbounded
  channels are a deliberate non-adoption because an item count alone also does
  not constrain payload bytes.
- `axum-server` 0.8.0 provides a maintained rustls acceptor and certificate
  reload path while supporting Rust 1.82. It is reserved for the non-loopback
  TLS slice; adding it before certificate/configuration behavior exists would
  expand the release dependency surface without adding a safe reachable mode.
- Adopt `axum` plus a dedicated Tokio runtime thread for the first explicitly
  enabled loopback-only pairing/auth/handshake slice. Keep the existing sync
  stdio/app-server owner unchanged. Set HTTP body, WebSocket message/frame/write
  buffer, handshake deadline, connection count, item count, and application
  queued-byte limits explicitly; axum's socket write-buffer limit is not a
  substitute for an application outbound-queue byte budget.
- Plaintext non-loopback configuration must fail before binding. Later WSS uses
  rustls with an explicit certificate/key policy; it must not silently downgrade
  to `ws://` when TLS configuration fails.

### WSS certificate loading, rotation, and Android trust boundary

_Reviewed: 2026-11-05_

#### Primary sources

- [`axum-server` 0.8 rustls configuration](https://docs.rs/axum-server/0.8.0/axum_server/tls_rustls/struct.RustlsConfig.html),
  [`from_tcp_rustls`](https://docs.rs/axum-server/0.8.0/axum_server/fn.from_tcp_rustls.html),
  and its [graceful-shutdown handle](https://docs.rs/axum-server/0.8.0/axum_server/struct.Handle.html).
- [Android Network Security Configuration](https://developer.android.com/privacy-and-security/security-config)
  and [Android's TLS guidance](https://developer.android.com/privacy-and-security/security-ssl).
- Dart [`WebSocket.connect`](https://api.dart.dev/dart-io/WebSocket/connect.html),
  [`HttpClient`](https://api.dart.dev/dart-io/HttpClient-class.html), and
  [`SecurityContext`](https://api.dart.dev/dart-io/SecurityContext-class.html).
- [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
  and its [release history](https://pub.dev/packages/flutter_secure_storage/changelog)
  for the later Android device-secret slice.

#### Maintained reference implementations

- [`codex-remote`](https://github.com/Venompool888/codex-remote) keeps its core
  service on loopback and recommends HTTPS/WSS termination by a reverse proxy;
  explicit HTTP is limited to trusted private/ADB scenarios. This supports a
  documented reverse-proxy deployment option, but does not substitute for a
  safe built-in listener when this Host is configured directly.
- [LocalSend's protocol](https://github.com/localsend/protocol/blob/main/README.md)
  uses a certificate fingerprint as device identity, while current LocalSend
  hardening also binds the claimed fingerprint to the TLS certificate. This is
  useful evidence for a pairing-bound local identity, but its mutual-TLS model
  is more machinery than the current scoped-bearer envelope requires.
- [`codex-remote-android` at `372581a`](https://github.com/liuhao-labs/codex-remote-android/commit/372581ad5cc66677d5322a9a447a03277d36ce15)
  confirms the value of explicit user-confirmed host identity and fail-closed
  changed-identity handling even though it uses SSH rather than WSS.

#### Findings

- `axum-server` 0.8.0 supports Rust 1.82, the project's axum/Tokio stack, PEM
  certificate-chain loading, shared `ArcSwap`-backed atomic reload, and bounded
  graceful shutdown. Its default rustls backend is AWS-LC. This project pins the
  dependency surface through `Cargo.lock` and keeps the existing HTTP body,
  WebSocket frame/message/write-buffer, connection, queue, journal, and write
  timeout bounds above the TLS acceptor.
- Android can use platform trust anchors for ordinary CA certificates and a
  narrowly supplied trust anchor for a local identity. Android's own guidance
  cautions that routine public-key pinning can strand clients during rotation;
  a future local self-signed flow should therefore bind an expected certificate
  or local CA identity during pairing and define re-pair/rotation behavior rather
  than install an unconditional `badCertificateCallback`.
- Dart supports injecting an `HttpClient` into `WebSocket.connect`, and that
  client can use a `SecurityContext` populated with the exact trusted
  certificate bytes. The release WSS smoke exercises that path without a trust
  bypass callback.
- Current `flutter_secure_storage` uses Android Keystore-backed key wrapping and
  encrypted storage, but its Android backup exclusions and minimum SDK/version
  constraints must be evaluated when the Android client slice lands. It is not
  added merely to make Host TLS reachable.

#### Adopted here

- Add `--remote-tls-cert`/`CODEX_NATIVE_REMOTE_TLS_CERT` and
  `--remote-tls-key`/`CODEX_NATIVE_REMOTE_TLS_KEY`. Both are required together;
  neither is meaningful without a listener. A non-loopback listener without
  both fails configuration, and `RemoteServer` independently enforces the same
  plaintext boundary before binding.
- Load and parse the certificate/key before binding. On Unix, reject a private
  key readable by group or other users. Never echo PEM contents in status or
  errors. Keep optional plaintext loopback operation for local development and
  the established smoke path.
- Expose rotation only through trusted local `host/remote/tls/reload`. A valid
  replacement is swapped for new TLS handshakes without dropping established
  WebSockets. Invalid replacement material returns a generic Host error and
  keeps the last valid rustls configuration.
- Prefer a normal CA certificate or reverse proxy for managed/public deployment.
  Defer local self-signed Android onboarding until the pairing artifact can bind
  certificate identity and platform-backed device-secret storage together. Do
  not add mTLS or arbitrary-certificate acceptance in this slice.

#### Validation and preserved negative evidence

- A first focused WSS test passed TLS but closed immediately before
  `server_hello`. Investigation found that `axum-server`'s `http1_only()` serve
  branch did not use Hyper's upgrade-serving path. Removing that override while
  retaining the router's HTTP/WebSocket limits restored WebSocket upgrade. The
  observed EOF is preserved here rather than erased by the later pass.
- Real TLS tests cover HTTPS health/pairing, hash-only bearer persistence,
  authenticated WSS negotiation, default-root rejection of the self-signed
  certificate, operator-supplied trust, non-loopback wildcard binding, local
  status projection, successful rotation, rejection by the old trust root,
  survival of an established connection, failed-reload rollback, and active
  WSS shutdown with an `Away` close frame.
- A release Host plus stock app-server completed the read-only Remote smoke over
  WSS using an explicitly populated Dart `SecurityContext`. It bound a network-
  scope wildcard and connected back through loopback on the same Linux host.
  This is not a physical Android, real LAN/firewall, system-CA, or installed
  service validation.

### Initial read-only Codex routing surface

_Reviewed: 2026-11-05_

- Generated the experimental JSON Schema bundle from the actually installed
  stock app-server `0.166.0-alpha.5.1` and compared `ModelListParams`,
  `ThreadListParams`, and `ThreadReadParams` with the current typed Flutter
  adapters. This was a temporary generated artifact and was removed after the
  review; no upstream schema is copied into the product.
- The first Remote Codex allowlist is `model/list`, `thread/list`, and
  metadata-only `thread/read`. Both list methods normalize a hard maximum of 100
  results; cursors are capped at 4 KiB. `thread/list` accepts only pagination,
  bounded sort, and `archived=false`; it does not accept cwd/search/project or
  relationship filters. `thread/read` forces `includeTurns=false` and bounds the
  thread ID. Unknown fields, write methods, idempotency keys, and missing read
  scope fail before app-server dispatch.
- The Host remains the only app-server stdio peer. Remote requests use a
  process-session-qualified internal ID namespace, while local input is barred
  from that namespace. Only a top-level response matching that exact random
  session prefix is removed from desktop stdout; other stock server requests,
  notifications, desktop responses, and even another session-like prefix remain
  on the local path.
- Target responses are captured only after the existing `aggregatedOutput`
  sanitizer/file spool completes. Capture is capped below the 1 MiB WebSocket
  message ceiling; an oversized sanitized response becomes an explicit Remote
  error without being loaded into memory or leaked to Flutter. Late responses
  after disconnect stay suppressed and are discarded when their bounded
  correlation no longer exists.
- The shared Host event queue is capped at 64 messages, Remote correlations at
  64 requests/64 KiB, and each connection's application queue at 16 messages
  and 2 MiB. A WebSocket message is capped at 1 MiB and a socket write at five
  seconds. Queue/byte overflow or a 30-second upstream timeout closes the
  connection so disconnect cleanup releases every pending correlation; it does
  not leave retryable-looking requests resident indefinitely.

### Bounded app-server notification publication

_Reviewed: 2026-11-05_

#### Sources reviewed

- OpenAI Codex `ServerNotificationEnvelope` generated TypeScript union:
  <https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/typescript/ServerNotificationEnvelope.ts>
- OpenAI Codex app-server protocol definitions:
  <https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/common.rs>
- OpenAI Codex app-server README:
  <https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md>
- The installed stock app-server `0.166.0-alpha.5.1` schema and the already
  implemented desktop typed notification projector.

#### Observed approaches and pitfalls

- The official notification envelope is a large evolving union. It mixes small
  lifecycle/state events with token/output deltas, full diff updates, account
  state, MCP progress, and other method-specific payloads. Treating every
  top-level `method` as equally replayable would turn the bounded journal into a
  second unreviewed app-server transport.
- Current app-server envelopes may include an optional top-level `emittedAtMs`.
  The Host sequence remains the Remote ordering authority; retaining the stock
  `params` without inventing a timestamp ordering rule avoids two competing
  clocks.
- `item/agentMessage/delta` and other deltas can arrive per token/chunk. A
  512-item journal would rapidly evict terminal evidence while retaining data
  that `item/completed` already supplies. `turn/diff/updated` can also be large
  and needs file/hunk chunking rather than an ordinary replay event.
- JSON-RPC server requests also have a top-level `method`, but additionally have
  a top-level `id`. Method allowlisting alone is therefore insufficient: the
  capture boundary must reject every request-shaped object independently of the
  ID value type.

#### Adopted here

- Publish only `turn/started`, `turn/completed`, `item/started`,
  `item/completed`, `thread/status/changed`, and `error` for the initial event
  slice. Unknown notifications, token/output/reasoning deltas, diffs, approval
  requests, and other server requests remain desktop-only.
- Detect the method and the presence of any top-level `id` in the incremental
  sanitizer. The ordinary desktop message is published first; Remote observes a
  copy only after every `aggregatedOutput` field has been replaced by its opaque
  bounded descriptor. Remote capture is capped at 256 KiB.
- Convert an allowlisted event above that cap into the small sequenced
  `host/resyncRequired` marker instead of allocating or silently dropping the
  payload. The mobile client can then perform bounded authoritative reads.
- Subscribe each socket to a capacity-64 live broadcast before handshake. The
  negotiation journal snapshot defines the baseline, buffered events at or
  below it are skipped, and only a contiguous next sequence is accepted. A
  broadcast lag/gap emits `resync_required` and closes the socket; application
  queue or socket-write exhaustion also disconnects the slow peer.

#### Validation in this project

- Streaming-transform tests cover fragmented method parsing, sanitized capture,
  numeric-ID server-request exclusion, delta exclusion, and oversize capture
  without Remote materialization.
- Real TCP tests cover live delivery, ACK, retained same-session replay, abrupt
  unacknowledged reconnect, count eviction with explicit handshake resync, no
  partial replay, oversize resync markers, bounded outbound queues, and a slow
  reader disconnected under an 18 MiB fanout.
- The release Host still passes pairing and the read-only stock app-server smoke.
  That smoke does not start a paid/mutating turn, so it does not claim a real
  stock turn notification was observed end to end.

Deliberately deferred: write methods, pending approval state, output-range
transfer, diff chunking, pairing-bound Android certificate onboarding, Android
secure storage, reconnect/lifecycle ownership, and Android application
integration remain unavailable.

### Bounded Dart Remote client transport

_Reviewed: 2026-11-05_

#### Sources and constraints applied

- Dart's official `WebSocket.connect`, `HttpClient`, and `SecurityContext` APIs
  reviewed in the WSS section above remain the implementation boundary. The
  WebSocket client negotiates `codex-native-v1`, carries the bearer only in the
  Authorization header, uses platform trust roots by default, and permits a
  narrowly configured `HttpClient` for a future pairing-bound local trust
  anchor. No `badCertificateCallback` exists in the product path.
- Dart automatically handles WebSocket ping/pong control frames. Application
  code still needs request deadlines, socket-close recovery, resume, and
  authoritative readiness; inventing an additional JSON heartbeat would create
  a second liveness protocol without improving the Host's existing heartbeat.
- Dart 3.13 adds `maxPayloadLength` to the WebSocket client. SDK source confirms
  that it rejects each uncompressed frame before exposing a message and caps a
  decompressed frame, but fragmented uncompressed frames accumulate into the
  message builder without an aggregate check. Configure the frame limit to
  1 MiB, disable compression, retain a second combined-message check, and treat
  TLS-authenticated Host behavior as part of the trust boundary. This does not
  prove bounded allocation against a compromised Host that deliberately
  fragments a larger message and is recorded as a release risk, not hidden.
- SDK source also confirms that ordinary `WebSocket.add()` enters a synchronous
  stream-controller path. Use serialized `addStream` writes instead: its source
  subscription is paused when the underlying socket consumer applies
  backpressure. Keep a separate count-and-byte cap because backpressure does not
  itself bound calls already queued by application code.

#### Adopted here

- Require WSS and an exact `/v1/ws` endpoint. Permit plaintext only with an
  explicit flag and a literal loopback IP; reject hostname loopback, query,
  fragment, and user-info forms. Validate the 43-character base64url bearer and
  keep credential/URI details out of validation errors.
- Reuse the Host's three-message negotiation and require protocol version 1 plus
  `ack`, `eventReplay`, and `readOnlyCodex`. A missing subprotocol, inconsistent
  session/sequence, binary/unknown/malformed message, event gap, or malformed RPC
  result policy-closes the connection.
- Treat a connection without an exact same-session retained cursor as requiring
  authoritative resync, even though the Host correctly reports that there is no
  replay request. Hold subsequent events behind the snapshot and require the
  caller to complete the same resync generation. Buffer exhaustion or a Host
  marker increments the generation so a stale read cannot clear newer evidence.
- Mirror the Host bounds: 64 pending RPCs, 1 MiB messages, 512 held events and
  8 MiB held-event bytes. The real socket additionally caps its serialized
  outbound queue at 64 messages/2 MiB and uses the SDK frame cap. One ambiguous
  RPC timeout closes the connection rather than allowing a late response to be
  mistaken for a safe retry. A connection Future that completes after its
  deadline is explicitly closed.
- Reuse typed model/thread/turn adapters, but expose only status, model list,
  bounded thread list, and metadata-only thread read. All writes, approvals,
  history, and output calls reject locally until the Host has end-to-end state
  and idempotency semantics for them.

#### Validation and preserved negative evidence

- Sixteen fake-socket and two real-loopback-socket tests cover security
  configuration, handshake, first resync, retained replay, ACK/cursor
  advancement, out-of-order correlation, unsupported writes,
  malformed/binary/gap input, abnormal peer close, explicit resync, event-buffer
  exhaustion, timeout, concurrent close, ordered real-socket writes, and the
  SDK frame cap. The first sequence-gap test hung:
  the reader tried to close its socket before cancelling the active iterator.
  Cancelling input first fixed the concrete lifecycle cycle; the initial hang is
  retained rather than erased by later green tests. The first real oversize-
  frame assertion expected a stream error; Dart instead intentionally sends a
  protocol close and ends the message stream without forwarding that internal
  error. The test now asserts close code 1002, and `RemoteTransport` surfaces an
  abnormal stream end through its public protocol-error channel.
- Full Dart analysis and all 90 Flutter tests pass. The Android manifest merge
  contains `INTERNET`, and the three-ABI debug APK builds through the documented
  Unicode-path local-property workaround. No real Android network, background,
  process-death, platform-CA, or presentation behavior was exercised.

#### Deliberately deferred

- Do not wire the transport into `RuntimeController` while endpoint/trust and
  device credential ownership are transient strings and resync has no bounded
  application projection owner.
- Do not persist a bearer or cursor in ordinary preferences, route state, logs,
  or crash text. Add platform-backed storage with backup exclusions and explicit
  key-loss recovery first.
- Do not automatically retry writes or approval answers. The current client is
  read-only; reconnect/idempotency and durable pending interaction state remain
  separate future slices.
