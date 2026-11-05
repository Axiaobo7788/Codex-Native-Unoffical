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
  `sha2` 0.11.1 for token/parameter digests, and `subtle` 2.6.1 for constant-time
  digest comparison. All are permissively licensed. `sha2` was initially held
  at 0.11.0 for an asserted Rust 1.87 floor; the later clean-toolchain gate
  disproved that floor and the now-verified Rust 1.89 floor supports 0.11.1.

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

- Do not wire the transport into `RuntimeController` while resync has no bounded
  application projection and reconnect owner. Endpoint/trust/device credentials
  are no longer transient strings, but storage alone is not runtime readiness.
- Do not persist a cursor in the credential record or ordinary preferences
  before its event has been applied. Bearers remain excluded from ordinary
  preferences, route state, logs, and crash text.
- Do not automatically retry writes or approval answers. The current client is
  read-only; reconnect/idempotency and durable pending interaction state remain
  separate future slices.

### Android device credential storage and recovery

_Reviewed: 2026-11-05_

#### Primary sources and implementation evidence

- Android's [Keystore documentation](https://developer.android.com/privacy-and-security/keystore)
  establishes that key material is non-exportable and may remain inside secure
  hardware. Its [Auto Backup documentation](https://developer.android.com/identity/data/autobackup)
  says SharedPreferences are backed up by default and documents legacy and
  Android 12+ include/exclude rules.
- [`flutter_secure_storage` 11.2.0](https://pub.dev/packages/flutter_secure_storage/changelog)
  is the current release. Version 11 uses RSA-OAEP wrapping plus AES-GCM by
  default, requires Android API 24 with current Flutter, and supports a namespace
  covering data preferences, wrapped keys, config markers, and Keystore aliases.
  Its default `resetOnError` is true; this project explicitly sets it false.
- Open [issue #1298](https://github.com/juliansteenbakker/flutter_secure_storage/issues/1298)
  identifies a current availability defect: transient Android Keystore null
  results can make the plugin replace the RSA wrapping pair before
  `resetOnError` is checked. Stored ciphertext then becomes permanently
  unreadable. This does not expose the bearer, but it means the application must
  model unreadable state and re-pair recovery instead of promising transparent
  persistence.

#### Adopted here

- Store one bounded versioned JSON record under one secure-storage key. Version
  1 permits only an exact WSS `/v1/ws` endpoint, the Host's 43-character
  base64url bearer, bounded/control-free device metadata, and `system` trust.
  Self-signed or local-CA identity will require a new explicit schema version.
- Treat absent, available, and recovery-required as distinct states. A storage
  exception is not absence. Invalid or unreadable data is not deleted, and a
  save cannot overwrite it until the user takes an explicit recovery action.
  Serialize operations and verify every write and delete by readback.
- Configure the Android adapter with `resetOnError: false`, algorithm migration,
  migration backup, no per-operation biometric prompt, and the isolated
  `codex_native_remote` namespace. Background reconnect needs key access without
  an interactive biometric ceremony; the Host bearer remains revocable. The
  plugin initializes storage before ordinary deletion, so an already lost
  wrapping key can otherwise block recovery. Only the explicit clear path uses
  the same namespace with `resetOnError: true`; routine reads and writes never do.
- Use both `allowBackup=false` and explicit preference exclusions for legacy
  cloud backup plus Android 12+ cloud/device transfer. The broader exclusion is
  intentional: current local settings are reconstructable, while restoring any
  device-bound secure-storage ciphertext is not safe.

#### Validation and preserved boundaries

- Nine tests cover strict/redacted serialization, plaintext and credential-URI
  rejection, absent/available/unreadable/corrupt states, preservation until
  explicit clear, verified writes, serialized concurrent saves, and exact
  Android option values. All 99 Flutter tests and the Linux debug build pass.
- Debug and R8-minified release Android builds pass after the existing temporary
  Unicode SDK-path workaround. Merged manifests contain API 24, `INTERNET`,
  `allowBackup=false`, and both backup rule resources. The universal three-ABI
  release APK is 51,791,110 bytes. That historical artifact used the Flutter
  template's debug certificate, so it is compilation/size evidence rather than
  release-identity evidence. No runtime Android Keystore call was made.
- The first ordinary Gradle invocation again failed before compilation because
  Flutter's Unicode SDK path was decoded as mojibake. This known toolchain-path
  failure is preserved; only the escaped-property run is a passing Android build.
- Physical-device Keystore, transient service failure, backup/restore, device
  transfer, uninstall/reinstall, and system-CA TLS behavior remain unrun. The
  open upstream wrapping-key replacement defect remains a release watch item.

### Remote readiness, applied cursors, and lifecycle recovery

_Reviewed: 2026-11-05_

#### Constraints applied

- WebSocket negotiation success is only a transport fact. Product readiness
  additionally requires the authenticated Host status to match the stored device
  and negotiated session, followed by an authoritative bounded state snapshot.
- The transport ACK tracks a contiguous received suffix so the Host can bound
  replay. It is not an application durability claim. A distinct cursor may be
  persisted only after the corresponding projection mutation succeeds.
- A saved cursor alone cannot reconstruct state after process death. Until the
  bounded projection itself is durable, cold start must ignore the cursor and
  perform authoritative reads. Retained in-memory state may resume only when its
  device, Host session, and applied sequence exactly match the verified cursor.
- Suspend, reconnect, resync, and asynchronous snapshot work can overlap. Every
  result needs both run and connection identity, and projection mutations must
  be serialized across sessions so a late old result cannot overwrite new state.
- Authentication rejection and live credential revocation require user recovery,
  not automatic retry. Transient connection/request failures may retry, but with
  a bounded delay and no write replay. The current Remote surface remains
  read-only.

#### Adopted here

- `RemoteTransport` exposes each allowlisted notification together with its
  exact Host session and sequence. Its terminal result distinguishes local,
  peer, protocol, resync, credential-revoked, and generic failure classes while
  keeping close text out of public diagnostics. The real socket converts HTTP
  401 into one redacted typed credential rejection.
- Store one versioned cursor record separately from the device bearer. Bind it
  to device ID, Host session, and non-negative sequence; cap it at 1 KiB;
  serialize access; verify write readback; and report malformed/unreadable data
  generically without deleting it.
- Retain at most 100 model entries and 100 thread summaries in the initial
  projection. Model/thread next cursors remain opaque for explicit later paging.
  Lifecycle events may update a known thread status or advance the exact next
  sequence without inserting unbounded history. Wrong-session, gap, malformed,
  and unsupported events fail closed.
- The lifecycle owner loads credentials, connects, verifies status, concurrently
  requests one bounded model and thread page, replaces the projection, saves the
  baseline cursor, then releases the transport's held suffix. Each released
  event is applied and only then persisted. A resync-generation change discards
  completed stale reads and repeats the bounded snapshot.
- Generic failures use exponential delays from one to 30 seconds. Credential
  rejection and exact live revocation enter terminal state. Suspend closes the
  session while retaining only verifiable applied state; stop also invalidates
  the projection. A connection that completes after deactivation is closed and
  never published.

#### Validation and preserved negative evidence

- Four cursor tests cover exact device binding, malformed/unreadable redaction,
  write verification, and serialized concurrency. Three projection tests cover
  the 100/100 cap, exact sequence application, and fail-closed input. Ten
  lifecycle tests cover absent/recovery credentials, readiness gating,
  apply-before-persist order, retained resume, Host session replacement,
  rejection/revocation, exponential retry (including connected failures before
  readiness), late connection cleanup, stale projection work, and invalidated
  hydration.
- The first real HTTP 401 assertion failed because Dart's
  `WebSocketException.message` omitted the status; its `toString()` retained the
  fixed `HTTP status code: 401` phrase. Matching only that phrase produced the
  typed redacted result without parsing or surfacing the endpoint or bearer.
- The first suspend/late-connection test failed because the stale branch closed
  the session and the surrounding `finally` closed it again. Real
  `RemoteTransport` coalesced this, but the coordinator interface should not rely
  on implementation idempotence. One `finally` now owns cleanup.
- A delayed projection test proves an old session cannot repopulate or advance a
  resumed run. Projection work is serialized globally; resume waits for old work
  to finish; a generation change invalidates the stale result before the new run
  reads its cursor.
- All 118 Flutter tests, `dart analyze --fatal-infos`, an isolated ASCII-copy
  `flutter analyze --no-pub`, Linux debug build, and Android `assembleDebug`
  pass. Direct `flutter analyze` still crashes on the Unicode repository path;
  a simple ASCII symlink was insufficient because the analyzer canonicalized it
  back to the real path. No real Android network, OS background, process death,
  or secure-storage lifecycle was exercised.

#### Deliberately deferred

- Android runtime construction, lifecycle visibility wiring, and a bounded
  read-only metadata panel are now integrated in the following slice. Pairing,
  credential recovery actions, and full conversation behavior remain separate.
- Only bounded model/thread metadata is authoritative. Remote history, output,
  turns, approvals, server requests, and every write remain unavailable.
- Cursor-only cold resume remains intentionally disabled until there is a
  separately designed bounded durable projection. Reconnecting with a stale
  cursor and no matching state would be fast but incorrect.

### Android Remote product lifecycle integration

_Reviewed: 2026-11-05_

#### Official lifecycle facts applied

- Flutter's [`AppLifecycleState`](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html)
  documentation says Android `Activity.onPause` maps to Flutter `inactive`,
  while Android `Activity.onStop` maps to Flutter `paused`. `inactive` can also
  mean a visible app lost focus to a system dialog, notification shade, split
  screen, or picture-in-picture, so it is too aggressive a disconnect boundary.
- Flutter synthesizes `hidden` immediately before mobile `paused` and before
  returning from `paused`; [`AppLifecycleListener`](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html)
  provides matching `onHide` and `onShow` callbacks. These are the visibility
  boundary used for Remote suspend/resume; desktop receives the callbacks too,
  but desktop `RuntimeController` deliberately treats them as no-ops.
- Flutter explicitly warns that lifecycle notifications may be skipped when the
  process is killed or the device terminates unexpectedly. Correctness therefore
  cannot depend on receiving hide/detach: cold start still refuses cursor-only
  resume without an exactly matching in-memory projection.

#### Adopted here

- Android `RuntimeController` creates the secure credential/cursor adapters,
  bounded projection, and lifecycle coordinator by default. Desktop continues
  to locate/spawn the bundled Host and stock Codex through `ProcessTransport`.
- Map each lifecycle phase to an explicit redacted product state. Unpaired,
  unreadable credential, retry, revoked, suspended, and read-only ready are not
  collapsed into a generic connection error. Socket negotiation alone never
  produces the ready state.
- Use `onHide` to suspend Remote, `onShow` to restart it, and detach for full
  shutdown. Suspend closes the socket but preserves only the coordinator's
  verified applied projection/cursor pair.
- Present only the bounded ready projection: a virtualized list of at most 100
  thread summaries plus model count/default model. The view is explicitly
  labeled read-only. It does not instantiate a parallel conversation model or
  expose create/resume/composer/approval/history/output/settings actions.
- Existing gateway methods reject locally in Remote mode. This prevents future
  widget reuse from silently issuing an RPC that the Host has not made safe.

#### Validation and boundaries

- Two integration tests cover state mapping and redaction, projection exposure,
  local gateway rejection, read-only widget contents, and hide/show
  suspend/resume. The first hidden-state test expected the screen to repaint to
  “suspended”; Flutter intentionally stops visible frame scheduling while
  paused, so the correct evidence is controller suspension while hidden and a
  refreshed ready view after `onShow`. The first 412×915 run also exposed a
  100-pixel overflow in the runtime status row; the status label now takes the
  remaining row width and wraps on a phone viewport.
- All 120 Flutter tests, fatal-info Dart analysis, formatting, Linux debug build,
  and Android debug assembly pass. No emulator or physical device was available,
  so Android Activity/process callbacks, Keystore access, WSS, network switching,
  OS process death, and Human layout/interaction remain unverified.
- At this slice boundary the unpaired screen remained an intentional blocker;
  the following slice adds bounded default-root pairing and explicit recovery.
  Pairing-bound local certificate identity remains separate and record version 1
  remains limited to the runtime's default trusted roots.

### Bounded Android pairing and credential recovery onboarding

_Reviewed: 2026-11-05_

#### Sources re-reviewed

- Dart 3.13 [`HttpClient`](https://api.dart.dev/dart-io/HttpClient-class.html),
  [`SecurityContext`](https://api.dart.dev/dart-io/SecurityContext-class.html),
  and [`connectionTimeout`](https://api.dart.dev/dart-io/HttpClient/connectionTimeout.html)
  documentation plus the installed Dart 3.13.1 SDK source. The connection
  timeout applies only to establishing a new connection; a separate whole-
  operation deadline is required. Response bodies are streams that must be
  consumed or drained. The exact SDK says Linux/Windows default roots come from
  Mozilla while macOS/iOS/Android roots come from the platforms' built-in trust
  stores. This corrects the earlier over-broad Mozilla-root description without
  claiming that every Android user-added CA, proxy, or VPN behavior is covered.
- This repository's actual Host router and auth implementation: exact
  `/v1/pair`, 8 KiB HTTP body limit, ten attempts/minute, 24-character URL-safe
  single-use tickets, 80-character Host-bounded names, 22-character device IDs,
  43-character device tokens, read/device-rotate scopes, 401/409/429 failure
  classes, and an exact protocol-version-1 response.
- `codex-remote` at
  [`fcdf784`](https://github.com/Venompool888/codex-remote/commit/fcdf784e6365735ad9efde5cb43c5126042f4556),
  re-reading `PairingLink.kt`, `AddConnectionController.kt`, `RemoteClient.kt`,
  `SecureTokenStore.kt`, and the Host pair route. Its useful ideas are transient
  one-use-code fields, explicit server confirmation, generation-scoped async UI
  callbacks, Host-side rate limits, and encrypted per-Host device tokens. Its
  source-available license remains research-only here.
- `codex-remote-android` at
  [`372581a`](https://github.com/liuhao-labs/codex-remote-android/commit/372581ad5cc66677d5322a9a447a03277d36ce15),
  re-reading `SshAppServerTransport.kt`, `ConnectionStore.kt`, and the host-key
  confirmation UI. It blocks unknown/changed SSH identity before sending a
  password or private key and requires explicit fingerprint acceptance. That is
  compatibility/security evidence for a future local-certificate bootstrap,
  not a reason to adopt SSH as this project's primary transport.

#### Adopted here

- Accept exactly the persisted record-v1 WSS `/v1/ws` endpoint, derive only its
  same-origin HTTPS `/v1/pair` route, and reject userinfo, query, fragment,
  plaintext, wrong paths, invalid ticket alphabets/lengths, control characters,
  and names above 80 Unicode scalar values before network access.
- Use a fresh `HttpClient` for one POST with automatic decompression off,
  redirects off, one connection per Host, an identity encoding request, a
  five-second connection timeout, a 15-second whole-operation timeout, and an
  8 KiB streamed response cap. The exchange is injectable for deterministic
  protocol tests. No error includes the URI, code, response body, token, or TLS
  details, and no `badCertificateCallback` exists.
- Require HTTP 200 plus JSON content type and exact versioned response keys.
  Validate the Host's device identity/name, both required scopes, monotonic
  issuance/expiry, null initial rotation/revocation/last-seen fields, and bearer
  format before constructing the existing strict credential record.
- Keep pairing state separate from connection readiness. A successful exchange
  is written and read back through the existing serialized secure credential
  owner, then the prior lifecycle generation is stopped before a new load starts.
  This prevents an older foreground absent-credential read from winning after a
  successful save. Hiding or detaching never starts a socket; an accepted token
  is still saved so the one-use credential is not intentionally orphaned.
- Recovery cannot be reached through the pairing form and cannot overwrite an
  unreadable record. An affirmative dialog stops the lifecycle, verifies cursor
  deletion first, then verifies credential deletion. Failure restarts persisted-
  state discovery while visible; success returns to unpaired. Clearing this
  device never claims Host-side revocation.

#### Deliberate non-adoptions and remaining boundaries

- Do not adopt the reference client's HTTP/USB onboarding, automatic protocol
  fallback after 404, full response-body string reads, raw Host error messages,
  asynchronous unverified preference writes, or decrypt-error-as-absence
  behavior. Do not send Android model/device metadata automatically; the user
  owns the bounded display name.
- Record version 1 does not trust a self-signed certificate and does not accept
  a fingerprint learned after the ticket has already been sent. The future local
  certificate flow needs a pairing invitation that binds endpoint, ticket, and
  certificate/CA identity through the trusted local surface, a new record
  version, and one scoped client trust context.
- `HttpClient` evidence does not prove Android proxy, VPN, user-added CA,
  captive-portal, Doze, or network-switching behavior. The pairing and WebSocket
  implementations must also be tested with the same real certificate chain; a
  pairing-only success is not connection readiness.
- At this slice boundary the Host local RPC could create a ticket, but the
  desktop product could not present an explicitly configured client endpoint or
  manage devices. The following trusted desktop setup slice closes that manual
  RPC gap without changing the Android trust model.

#### Validation and preserved negative evidence

- Pairing, onboarding, cursor, runtime integration, and 412×915 widget tests now
  contribute to 135 passing Flutter tests. Fatal-info analysis, formatting, the
  Linux debug build, and Android debug assembly also pass; the unchanged
  three-ABI APK is 191,469,644 bytes. Tests cover exact request derivation,
  all current Host status classes, timeout, malformed/oversized success,
  readback-before-start, hidden and shutdown races, recovery preservation,
  explicit clear, clear failure, and affirmative UI confirmation.
- The first route assertion showed that `Uri.replace(query: '', fragment: '')`
  emits an unwanted trailing `?#` even when both components are empty. The code
  now replaces only scheme/path, relying on prior endpoint validation, and the
  test requires the exact `/v1/pair` URI.
- Concurrency review found that an application-show reload could still be
  finishing an absent-credential read when pairing saved a new record. A direct
  `start()` could then no-op while active and leave the later absent result as
  final. Pair activation now stops that generation before starting the verified
  record. The same review found clear failure could leave the lifecycle stopped;
  visible recovery now restarts state discovery after failure.
- Linux is the only connected Flutter device in this environment. No Android
  Keystore call, default-root HTTPS exchange, IME flow, Activity lifecycle,
  backup/restore, process kill, or Human interaction was executed. Those remain
  release gates rather than inferred passes.

### Trusted desktop Remote setup and explicit endpoint advertisement

_Reviewed: 2026-11-05_

#### Sources and constraints re-applied

- `codex-remote` at
  [`fcdf784`](https://github.com/Venompool888/codex-remote/commit/fcdf784e6365735ad9efde5cb43c5126042f4556),
  specifically its explicit `publicUrl`, `PairingLink.kt`, generation-scoped
  setup controller, secure token store, and Host pair route. The useful product
  evidence is that a public client endpoint is explicit and invalid public
  configuration is visible; one-use material is transient and created through
  an operator action. Its HTTP onboarding, protocol fallback, unbounded response
  strings, and unverified asynchronous preference writes remain deliberate
  non-adoptions.
- `codex-remote-android` at
  [`372581a`](https://github.com/liuhao-labs/codex-remote-android/commit/372581ad5cc66677d5322a9a447a03277d36ce15),
  whose SSH setup blocks on explicit Host fingerprint confirmation before
  credentials. This supports keeping identity and invitation presentation on a
  trusted local surface, but does not justify adopting SSH or TOFU after a
  pairing ticket is sent.
- This repository's implemented Host behavior remains authoritative: listener
  bind scope/TLS are runtime facts, pairing tickets last five minutes with only
  one active ticket, public device records are capped at 32, and local
  `host/remote/*` calls are separated from the authenticated network allowlist.

#### Adopted here

- Add a separate optional advertised endpoint rather than reconstructing one
  from the listener. Accept only exact WSS `/v1/ws`, reject user info, query,
  fragment, port zero, and unspecified IP hosts, and require a listener to be
  enabled. Preserve reverse-proxy deployments by not requiring the endpoint to
  equal the bind address or local TLS flag.
- Return the endpoint in both `host/status` and ticket creation. The desktop
  adapter requires exact bounded Host-owned schemas, rejects unexpected bearer
  data, caps the device list at 32, and redacts endpoint/ticket/device IDs from
  object strings and product errors.
- Keep administration outside `CodexTransport`; only the connected desktop
  `ProcessTransport` exposes it. Opening the dialog performs status/device reads
  but creates no ticket. An explicit button creates one ticket, verifies that
  its endpoint still matches status and that it is unexpired, and drops the
  ticket when the dialog closes. The UI never enables or rewrites listener
  configuration.
- Require confirmation before revocation and read the device list back from the
  Host. Count only active credentials toward the 32-device pairing limit; prune
  revoked/expired records atomically only when publishing a replacement so the
  store remains bounded and a just-revoked row can still be read back.

#### Deliberate non-adoptions and validation boundary

- Do not auto-discover LAN addresses, turn `0.0.0.0` into a hostname, create a
  ticket when the dialog opens, copy a ticket to the clipboard automatically,
  log it, persist it, enable a listener, edit configuration, or expose local
  administration to a Remote device.
- This surface does not prove that the configured endpoint is reachable, that
  its certificate chains on Android, or that a reverse proxy forwards the exact
  routes and headers. Those are installed-network/device gates. QR transfer and
  self-signed/local-CA bootstrap still require a versioned pairing artifact that
  binds endpoint, ticket, and Host identity before credentials are sent.
- Six protocol, six controller, three widget, one process-correlation, and three
  new Rust regressions cover malformed endpoints/shapes, no automatic ticket,
  dialog-lifetime state, endpoint/expiry consistency, affirmative revocation,
  authoritative readback, stale disposal, actual Host status projection, and
  capacity release by revoked/expired credentials. All 151 Flutter and 78 Rust
  tests pass, together with fatal-info analysis, strict Clippy, Rust release,
  Linux debug, and Android debug builds.
- The first ProcessTransport test exposed that Dart's `Uri.port` cannot supply a
  default for the `wss` scheme when no explicit port exists; endpoint validation
  now reads the port only when `hasPort` is true. Adjacent review then exposed
  that revoked records still counted toward the old total-record limit, making
  the documented recovery action ineffective. Pairing now prunes inactive
  records at the atomic replacement boundary while preserving the active cap.
- A release Host with stock app-server reported a real ephemeral loopback bind,
  `tls=false`, and the independently configured WSS endpoint, then exited zero
  on EOF. This verifies propagation, not endpoint network reachability. Linux is
  still the only available device and no Human visual acceptance was performed.

### Versioned pairing invitation and local-certificate trust

_Reviewed: 2026-11-05_

#### Sources reviewed

- The installed Dart 3.13.1 `dart:io` source and current official
  [`SecurityContext` constructor](https://api.dart.dev/dart-io/SecurityContext/SecurityContext.html),
  [`setTrustedCertificatesBytes`](https://api.dart.dev/dart-io/SecurityContext/setTrustedCertificatesBytes.html),
  and [`HttpClient` constructor](https://api.dart.dev/dart-io/HttpClient/HttpClient.html).
  A new context has no roots by default; an injected context can therefore be
  scoped to one connection identity rather than changing global process trust.
- rustls 0.23
  [`RootCertStore::add`](https://docs.rs/rustls/latest/rustls/struct.RootCertStore.html#method.add),
  which strictly parses one expected DER trust anchor rather than silently
  accepting the valid subset of an arbitrary bundle. License: Apache-2.0 OR ISC
  OR MIT.
- Syncthing's maintained
  [device-ID](https://github.com/syncthing/syncthing/blob/main/man/syncthing-device-ids.7)
  and [security](https://github.com/syncthing/syncthing/blob/main/man/syncthing-security.7)
  documentation. It derives peer identity from certificate DER and compares the
  presented identity with preconfigured expectation; loss of the corresponding
  private key permits impersonation. License: MPL-2.0; no source code is copied.
- The already pinned `codex-remote` `fcdf784` public-URL/pairing flow and
  `codex-remote-android` `372581a` host-key confirmation flow. They reinforce
  explicit transient invitation state and identity confirmation before
  credentials, but their HTTP/SSH transports and licensing do not replace this
  project's WSS/Host boundary.

#### Findings that changed the implementation

- Do not infer the mobile trust anchor from the Host listener certificate
  chain. The client-visible endpoint may terminate at a reverse proxy, a chain
  may contain several candidates, and automatically choosing a leaf or CA can
  silently produce unusable or over-broad trust. Add a separate explicit trust-
  certificate setting instead.
- A certificate fingerprint inside an unauthenticated exchange is too late: the
  one-use ticket would already have been exposed to an impersonator. Endpoint,
  ticket, expiry, and trust identity must arrive together through the trusted
  local setup surface before the first HTTPS request.
- The certificate bytes are the actual per-connection trust anchor. The SHA-256
  value is a canonical consistency/fingerprint field, not an independent proof
  of authenticity. Authenticity comes from trusted transfer of the invitation.
- A stable private CA permits ordinary leaf rotation without changing Android
  state. Binding an exact self-signed leaf is narrower but requires Host restart,
  a fresh invitation, and re-pairing after that leaf changes. TLS reload alone
  must never silently migrate saved trust.
- The first product-path release smoke preserved a platform-specific negative
  result: Linux rejected the invitation's raw DER leaf through Dart
  `SecurityContext`, although rustls accepted the same DER as a root. The
  official API describes PEM/PKCS#12 generally and single DER specifically for
  iOS. The client now stores canonical DER but supplies PEM on non-iOS and DER
  on iOS. The next smoke then proved both HTTPS pairing and authenticated WSS;
  no arbitrary-certificate callback was introduced.

#### Adopted here

- `CODEX_NATIVE_REMOTE_PAIRING_TRUST_CERT`/
  `--remote-pairing-trust-cert` accepts exactly one bounded DER or PEM
  certificate only when both a listener and explicit advertised WSS endpoint
  exist. Host startup validates it with rustls before stock Codex starts. The
  setting is independent from server TLS files and is snapshotted until restart.
- Trusted-local ticket creation now returns one opaque
  `codex-native-pairing-v1.<base64url-json>` invitation. Its exact schema binds
  version 1, canonical WSS endpoint, 24-character single-use code, expiry, and
  either `{type: system}` or one certificate's SHA-256 plus DER. Both inner
  certificate and outer invitation have hard byte/character caps and exact-key
  parsing.
- Android accepts only that complete invitation plus its user-owned device
  name. It builds an empty, invitation-scoped trust context for certificate
  mode, performs same-origin HTTPS pairing, persists record version 2, and
  rebuilds the same scoped context for WSS. Version-1 system records remain
  readable and are upgraded only on a later verified save; the secure-storage
  key does not change.
- Desktop creates no invitation on open, retains it only for the dialog, and
  copies it only after an explicit user action that warns about the short-lived
  clipboard secret. Manual transfer is implemented; QR rendering is deferred
  until a QR encoder and practical payload/error-correction limits are reviewed.

#### Deliberate non-adoptions and remaining validation

- No TOFU after network contact, `badCertificateCallback`, global trust-store
  mutation, certificate-chain guessing, listener-address guessing, silent trust
  migration, or automatic clipboard write.
- The manual/base64 envelope is intentionally simple and auditable. Do not add
  compression merely to fit every possible 8 KiB certificate into a QR code;
  a later QR slice must measure real certificate sizes and define scan/error-
  correction behavior while preserving this version boundary.
- The release Host plus stock app-server now proves a generated self-signed
  certificate is rejected by ordinary system trust for both pairing and WSS,
  then accepted through the exact invitation-bound context; pairing, model/list,
  metadata history, live revocation, temporary cleanup, and Host exit all pass.
  This remains same-Linux-host evidence, not Android Secure Storage, camera/QR,
  LAN/firewall, Android TLS-provider, lifecycle, or Human acceptance evidence.

### Lockfile-derived native dependency notices

_Reviewed: 2026-11-05_

#### Sources reviewed

- `cargo-about` 0.9.3's maintained
  [quickstart](https://embarkstudios.github.io/cargo-about/),
  [configuration](https://embarkstudios.github.io/cargo-about/cli/generate/config.html),
  and [output-template](https://embarkstudios.github.io/cargo-about/cli/generate/output.html)
  documentation. It evaluates license expressions against an explicit accepted
  set, can fail on unreadable/unresolved license material, filters a union of
  target triples, and renders complete texts through a repository-owned
  template. License: MIT OR Apache-2.0.
- Cargo's official [`cargo metadata`](https://doc.rust-lang.org/cargo/commands/cargo-metadata.html)
  and [`cargo install`](https://doc.rust-lang.org/cargo/commands/cargo-install.html)
  documentation. `--locked` rejects dependency-resolution drift; installing a
  tool with its published lockfile also requires `--locked` explicitly.
- Mozilla's official [MPL 2.0 text](https://www.mozilla.org/en-US/MPL/2.0/)
  and [FAQ](https://www.mozilla.org/en-US/MPL/2.0/FAQ/). Section 3.2 and FAQ Q8
  require a distributor of a compiled, unchanged MPL library to tell recipients
  how to obtain its source; MPL-covered files can remain part of a larger work
  under another license when those obligations are preserved.

#### Findings that changed the implementation

- The hand-maintained native summary was not a complete release artifact. The
  first fail-closed generation found the unlisted MPL-2.0 `option-ext` 0.2.0
  runtime crate through `dirs`, and review also exposed that direct dependency
  `axum-server` was absent from the hand list. A successful compile is not
  evidence that transitive license texts have been packaged.
- Test-only dependencies must not inflate or confuse the distributed runtime
  notice, but target-specific and build dependencies that contribute to Linux,
  Windows, or macOS binaries must be included. One union over supported desktop
  target triples produces a conservative shared notice for every desktop.
- The generated artifact must be committed as reviewable source-distribution
  evidence and regenerated in CI. Generating only during a release would make
  legal drift invisible to ordinary code review; committing without a drift
  check would allow it to become stale.
- Upstream crate license files contain mixed LF/CRLF endings and, in a few cases,
  trailing horizontal whitespace. The first staged aggregate therefore failed
  the repository whitespace gate. Deterministic generation must normalize only
  those representation details and the final newline, not rewrite license prose.
- MPL-2.0 is accepted only for the unchanged `option-ext` crate. The generated
  entry includes its upstream source URL and full license text so recipients of
  the binary have both the notice and a reasonable source-acquisition path.

#### Adopted here and validation boundary

- Pinned `cargo-about` 0.9.3 runs with `--locked --workspace --fail`, explicit
  accepted licenses, maintained rustls clarification, runtime/build dependencies,
  and Linux/Windows/macOS target unions. The repository-owned plain-text template
  emits exact crates.io source archives, repositories, SPDX choice, and complete
  texts without absolute local paths, then canonicalizes line endings and
  trailing whitespace.
- `./tool/generate_native_licenses.sh --check` compares a fresh temporary result
  byte-for-byte with `licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt`; `--write`
  is the only regeneration path. CI installs the exact generator version and
  checks drift before application validation.
- Linux and Windows CMake installs place the notice beside the Host. The macOS
  Host build phase installs it in `Contents/Resources` and declares that output
  to Xcode. A real Linux debug bundle contains a byte-identical 257,985-byte,
  mode-0644 notice beside the mode-0755 Host.
- This Linux slice initially source-reviewed only the Windows/macOS edits. The
  later hosted matrix verified the built Windows bundle and exposed the macOS
  Bash 3.2 defect documented below. A later run verified corrected macOS native
  execution; installation, signing/notarization, and legal review remain
  distinct gates.

## Hosted CI hardening and cross-platform build gates

_Reviewed: 2026-11-06_

### Sources reviewed

- GitHub's official [secure-use guidance for third-party actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions),
  which identifies a full commit SHA as the only immutable third-party action
  reference, and the official [GitHub-hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
- The maintained `actions/runner-images` [available-image table](https://github.com/actions/runner-images#available-images):
  Ubuntu 22.04 x64, Windows Server 2022 x64, and macOS 15 arm64 are supported
  standard images; macOS 14 was retired on 2026-11-02.
- Flutter's official [supported-platform matrix](https://docs.flutter.dev/reference/supported-platforms)
  and [continuous-delivery guidance](https://docs.flutter.dev/deployment/cd).
  Flutter 3.47 supports the selected desktop OS/architectures and tests Linux on
  Ubuntu 22.04 and macOS on macOS 15.
- `flutter_secure_storage_linux` 3.0.3's published [Linux requirements](https://pub.dev/packages/flutter_secure_storage_linux/versions/3.0.3),
  which require `libsecret-1-dev`, and Cargo's official
  [`rust-version` manifest semantics](https://doc.rust-lang.org/cargo/reference/manifest.html#the-rust-version-field).

### Findings that changed the implementation

- The prior `ubuntu-latest` job neither fixed the runner image nor built Android,
  Windows, or macOS. Adding Linux secure storage also made `libsecret-1-dev` a
  required compiler dependency that the old job did not install.
- The latest three hosted runs visible before this change passed, but the newest
  run (`42034034310`) tested only remote commit `2c7f8b9`, not the newer
  local-only history. A green old run cannot be used as evidence for this
  workflow or current tree.
- A clean official Rust 1.87.0 toolchain rejected the locked graph before
  compilation: `uuid` 1.29.0 requires rustc 1.89.0. An isolated official Rust
  1.89.0 toolchain then compiled from empty Cargo/target state and passed all 84
  Rust tests. The former `rust-version = "1.87"` was therefore a false release
  claim, not a compatibility feature worth preserving.
- `subosito/flutter-action` at the reviewed commit contains optional floating
  `actions/cache@v5` steps. This workflow explicitly disables that cache, so
  those conditional steps do not execute; both top-level actions are pinned to
  reviewed full SHAs and checkout persistence is disabled.
- The first current-tree run (`42063855051` at `a77e6ac`) supplied the native
  evidence configuration review could not. Windows Server 2022 x64 passed the
  complete debug bundle, Host/license placement, and Host execution gate.
  Exact Rust 1.89 Clippy rejected a test-only explicit `drop` of a non-`Drop`
  closure, and macOS 15 arm64's system Bash 3.2 rejected expansion of an empty
  array under `set -u`. These are compiler/shell compatibility defects, not
  reasons to weaken the gates.
- The same run warned that the pinned checkout v4 build targeted Node 20 and
  GitHub was forcing it onto Node 24. The official `actions/checkout` v7.0.1
  release commit `3d3c42e5aac5ba805825da76410c181273ba90b1`
  declares `runs.using: node24`, eliminating that compatibility shim without
  restoring persisted checkout credentials.
- Follow-up run `42066453043` passed corrected macOS arm64, Windows x64,
  exact-Rust Clippy/tests, Dart/Flutter analysis/tests, and Linux packaging. The
  Android debug build alone failed before compilation: Flutter reported Java
  11.0.32 driving Gradle 9.3.1. Gradle's official compatibility matrix requires
  JVM 17 or later for Gradle 9; runner defaults therefore cannot define the
  Android build toolchain.
- Official `actions/setup-java` v6.2.0 commit
  `77dd5b2ce225ea11469928ac317850245a74ae78` declares Node 24. Selecting the
  minimum compatible Temurin 17 makes the CI contract match the Android source
  and Kotlin JVM 17 targets without opportunistically advancing to a newer JDK.
- Local OpenJDK 17.0.20.1 then ran the real Gradle 9.3.1 wrapper through all 185
  `assembleDebug` tasks and emitted a non-empty 191,469,644-byte APK. This used
  only the already documented temporary ASCII Flutter-SDK alias needed for the
  repository's Unicode host path; it did not substitute for the hosted rerun.
- Final run `42068745322` at `e11a36c` passed all jobs. Ubuntu selected Temurin
  17 and completed source/license/signing-contract checks, exact Rust 1.89
  Clippy/tests, Dart/Flutter analysis/tests, the Linux bundle/license gate, and
  Android debug build plus non-empty APK assertion. Windows x64 and macOS arm64
  both completed their native bundle, packaged Host execution, and license
  identity checks.

### Adopted here and validation boundary

- The primary Ubuntu 22.04 x64 job installs the actual Linux compiler
  dependencies, selects Flutter 3.47.1, exact Rust 1.89.0, and Temurin 17, runs
  formatting, license drift, strict Clippy, all Dart/Rust tests and analysis,
  then builds both the Linux debug bundle and Android debug APK.
- A fail-independent matrix builds Windows Server 2022 x64 and macOS 15 arm64.
  Each job checks that the Host is non-empty, executes its packaged `--help`, and
  verifies the native-license notice at the platform's real bundle location.
  PR CI remains read-only and unsigned; signing, notarization, installation,
  native ACL inspection, and Human use are separate release gates.
- `actions/checkout` v7.0.1 is pinned to
  `3d3c42e5aac5ba805825da76410c181273ba90b1` with no persisted credentials;
  `subosito/flutter-action` is pinned to
  `1a449444c387b1966244ae4d4f8c696479add0b2` with cache disabled. Concurrency
  cancels superseded runs. `actions/setup-java` v6.2.0 is pinned to
  `77dd5b2ce225ea11469928ac317850245a74ae78`, with no dependency cache enabled;
  monthly Dependabot review remains limited to the GitHub Actions ecosystem.
- Pinned `actionlint` 1.7.12 and independent YAML parsing pass locally. After
  the first hosted failures, lexical borrow scoping passes strict Clippy plus 84
  tests on a fresh official Rust 1.89.0 toolchain, and non-empty macOS command
  arrays pass shell parsing plus local Debug/Release packaging simulation.
  Hosted Windows x64, corrected macOS arm64, Linux, explicit Temurin 17, and
  Android debug assembly are now real passes in one final matrix. Release
  signing, notarization, installation, ACL inspection, physical-device behavior,
  and Human use remain separate evidence until their respective gates run.

## Fail-closed Android release signing

_Reviewed: 2026-11-06_

### Sources reviewed

- Flutter's official [Android release guide](https://docs.flutter.dev/deployment/android),
  including the Kotlin DSL `key.properties` flow, private-file warning, signed
  App Bundle output, and preference for AAB distribution through Google Play.
- Android's official [app-signing guidance](https://developer.android.com/studio/publish/app-signing),
  which distinguishes the insecure, SDK-generated debug certificate from the
  upload/app-signing identities required for publication and emphasizes that
  private signing material must remain protected.
- Android's official [build-variant signing behavior](https://developer.android.com/build/build-variants#signing),
  which states that release artifacts are not signed unless an explicit release
  signing configuration is defined and recommends keeping signing data outside
  source build files.

### Findings that changed the implementation

- The Flutter template's temporary `signingConfig = debug` was still active.
  Earlier 51,791,110-byte "release" APK evidence therefore proved R8/native
  compilation only; it did not prove a distributable release identity and must
  not be treated as RC signing evidence.
- Silently emitting an unsigned archive would still leave an ambiguous artifact
  that could be mislabeled later. Release assembly should stop before expensive
  packaging when the external upload-key contract is missing, while debug
  builds and IDE sync must remain usable for contributors without private keys.
- The keystore path and three credential values are operator-owned secrets. The
  repository can define and test their shape, but creating a production key,
  choosing Play App Signing policy, storing CI secrets, and granting publication
  permissions require a separate explicit Human/release decision.

### Adopted here and validation boundary

- `android/app/build.gradle.kts` loads only the Git-ignored
  `android/key.properties`, requires non-empty `storeFile`, `storePassword`,
  `keyAlias`, and `keyPassword`, and verifies that the external store is a
  readable file. It creates the release signing configuration only when the
  complete contract is present. `preReleaseBuild` otherwise fails with bounded
  diagnostics containing property names but no values or keystore contents.
- The repository ships only `android/key.properties.example` placeholders.
  A CI-owned static validator checks the release-only Gradle contract, explicit
  absence of debug-signing fallback, private-file ignore rules, and exact
  placeholders without reading any ignored local signing file.
  Debug assembly still passes all 185 actionable tasks. With no private config,
  `assembleRelease` stops on the intended signing error. With a temporary
  30-day local RSA test keystore, `assembleRelease bundleRelease` passed;
  `apksigner` verified the 54,019,334-byte APK and its certificate digest exactly
  matched the temporary key, while `jarsigner` verified the 52,739,360-byte AAB.
  The private key, ignored properties, SDK alias, and signed test artifacts were
  then removed.
- This is build-contract evidence, not production signing. No upload key, Play
  Console application, Play App Signing enrollment, key backup/rotation plan,
  CI secret, store validation, publication, or physical-device install was
  created or claimed.

## Bounded desktop pairing QR presentation

_Reviewed: 2026-11-06_

### Sources reviewed

- DENSO WAVE's official QR Code
  [version](https://www.qrcode.com/en/about/version.html),
  [error-correction](https://www.qrcode.com/en/about/error_correction.html), and
  [symbol-construction](https://www.qrcode.com/en/howto/code.html) guidance.
  Standard QR Code versions range from 1 to 40; the maximum Version 40 byte
  capacity is 2,953 bytes only at low correction, higher correction consumes
  capacity, and a four-module margin is required around the symbol.
- The maintained [`qr` 4.0.1](https://pub.dev/packages/qr) package and its
  [source/license](https://github.com/kevmoo/qr.dart). It is a pure-Dart,
  offline matrix generator with Version 1-40 and standard error-correction
  support. License: BSD 3-Clause.
- The repository's exact `codex-native-pairing-v1` encoder/decoder and Host
  constants. The protocol deliberately permits up to 24 KiB of invitation text
  and 8 KiB of DER certificate material, so protocol validity cannot imply
  single-symbol QR capacity.

### Findings that changed the implementation

- Do not derive a second compact pairing representation. Splitting an
  invitation across symbols, compressing it, dropping trust material, or adding
  a QR-only schema would add ordering, allocation, compatibility, and security
  review surfaces. The exact existing envelope remains the only input.
- Medium error correction is appropriate for a transient desktop display, but
  it makes the single-symbol capacity smaller than the official low-correction
  maximum. The encoder must therefore expose ordinary capacity failure as a UI
  fallback, not a protocol error.
- A QR matrix must retain the required four-module white quiet zone and integer
  module geometry. The painter uses three logical pixels per module with
  antialiasing disabled and refuses to shrink below that scale when the dialog
  is too narrow.
- The invitation is a five-minute one-use capability. Generating the matrix
  only once per ticket avoids repeated encoding during rebuilds, and removing
  the ticket at its authoritative expiry ensures the QR does not remain visible
  after the represented capability is stale.

### Adopted here and validation boundary

- `RemotePairingQr.tryEncode` reuses the authoritative invitation decoder,
  rejects noncanonical whitespace and non-ASCII bytes, encodes the exact bytes
  at medium correction, and returns no object for malformed or Version 40
  overflow input. Its diagnostics redact the payload.
- The desktop setup keeps Copy invitation before the QR so the complete manual
  path remains accessible even when a large symbol extends the dialog. Normal
  system-root and bounded-certificate invitations render; a protocol-valid
  invitation carrying a 3,000-byte certificate proves the single-symbol
  overflow fallback. A 1,100-byte certificate produces a Version 40/M symbol
  measuring 555 logical pixels including the quiet zone; at a 620-pixel window,
  the constrained dialog refuses to shrink it and preserves manual copy.
- `RemoteAdminController` schedules the accepted ticket's exact remaining
  lifetime, cancels replacement/refresh/disposal timers, and removes the ticket
  plus QR projection on expiry. No QR bitmap, matrix, or invitation is persisted.
- Eight focused unit/widget tests pass. An attempted test-backend pixel capture
  through `RenderRepaintBoundary.toImage()` hung indefinitely twice and had to
  be interrupted, so it was removed rather than called a visual pass. Matrix
  construction, fallback state, copy behavior, and expiry lifecycle are tested;
  camera decoding, cross-device interoperability, display scaling, physical
  Android behavior, and Human visual acceptance remain unverified.
- A separate attempt to drive the complete desktop shell at 320 logical pixels
  exposed existing horizontal overflows in its split workspace, runtime header,
  and paired-device summary before a ticket could be created. That probe is not
  counted as QR evidence. Compact desktop-window responsiveness remains a
  distinct machine-actionable limitation rather than a hidden passing result.
- Android scanner implementation remains deferred until camera permission,
  selection, lifecycle, bounded decode input, accessibility/manual fallback,
  and dependency licensing receive a separate review. Desktop generation does
  not grant permission to loosen the invitation parser or trust boundary.

## Android pairing QR scanner

_Reviewed: 2026-11-06_

### Sources reviewed

- [`mobile_scanner` 7.5.0](https://pub.dev/packages/mobile_scanner), its
  controller/widget source, changelog, BSD 3-Clause license, and Android Gradle
  graph. The package uses CameraX and ML Kit on Android, supports QR-only format
  selection, exposes explicit start/stop lifecycle ownership, and defaults to a
  bundled barcode model unless an unbundled Gradle property is enabled.
- Flutter's official
  [`AppLifecycleState`](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html)
  and `WidgetsBindingObserver` contracts. Android's official
  [permission declaration](https://developer.android.com/training/permissions/declaring),
  [runtime permission](https://developer.android.com/training/permissions/requesting),
  and [`uses-feature`](https://developer.android.com/guide/topics/manifest/uses-feature-element)
  guidance establish that camera access should follow an affirmative feature
  action, denial must degrade gracefully, and camera/autofocus features must be
  explicitly optional when the app remains functional without them.
- Google's official [Android barcode-scanning](https://developers.google.com/ml-kit/vision/barcode-scanning/android),
  [ML Kit terms/privacy](https://developers.google.com/ml-kit/terms), and
  [Play data-disclosure](https://developers.google.com/ml-kit/android-data-disclosure)
  pages. Barcode pixels and results are processed on-device. The bundled model
  is immediately available, but ML Kit may contact Google for maintenance and
  sends performance/utilization metrics. Auto-zoom adds session, zoom, and
  candidate-box metrics, so it remains disabled.
- `qr_code_scanner_plus` 2.3.2 and `lightweight_barcode_scanner` 0.4.1 were
  reviewed as Android/iOS-only offline alternatives. The former's own README
  calls its Android native ZXing integration outdated and unmaintained. The
  latter has a notably clean QR-only native pipeline and Apache-2.0 vendored
  ZXing-C++ provenance, but at review time it was 27 days old with one like and
  194 downloads, so its camera/permission lifecycle has too little independent
  use to replace the mature option before physical-device validation.

### Findings that changed the implementation

- “Bundled” means that the model is immediately present, not that the runtime
  is network-silent. The resolved `com.google.mlkit:barcode-scanning` 17.3.0
  graph includes `play-services-mlkit-barcode-scanning` 18.3.1 and Google data
  transport. Notices and future store disclosures must preserve the documented
  metrics behavior; the product text says only that camera frames and decoded
  invitation content stay on-device.
- A standard Version 40 QR has 177 modules before its quiet zone. The scanner
  requests 1280x720 rather than the package's 640x480 Android default, while
  still requiring the code to occupy a useful part of the frame. Physical focus
  and dense-symbol recognition are not inferable from a successful build.
- Permission is requested only when the user selects Scan QR. A denied,
  permanently denied, unavailable, or interrupted camera never removes or
  disables manual paste. The manifest declares camera-any, back camera, and
  autofocus as optional to avoid filtering camera-less/front-only devices.
- Scanner intake is not trusted. It keeps only decoded text, accepts the first
  exact current canonical `codex-native-pairing-v1` value, and rejects null,
  whitespace-modified, oversized, malformed, and expired candidates without
  logging them. It closes back to the obscured form and does not call pairing;
  Pair and connect remains a separate user action.
- Camera operations are serialized. The initial permission prompt's inactive
  transition is ignored before permission exists so an early resume cannot
  strand the scanner stopped. Hidden/paused/detached always queue stop behind a
  pending start, so a camera acquired after real backgrounding is immediately
  released. After permission, inactive also stops and resumed queues start.
  Route disposal waits behind the same operation chain before disposing the
  driver, while also retaining the package's repaired session-release behavior.

### Adopted result and evidence boundary

- Added an injectable scanner driver and full-screen route. Production uses
  `mobile_scanner` 7.5.0 with manual start, `DetectionSpeed.noDuplicates`, QR
  only, no returned frame, no auto-zoom, and 1280x720 capture. Tests use a fake
  driver, so Linux test execution never opens a platform camera.
- Five scanner tests cover canonical/current bounds, invalid-then-valid intake,
  duplicate valid detection, lifecycle ordering, delayed-start disposal, and
  permission-denied manual fallback. The onboarding widget proves a scanned
  value only fills the field and remains unsubmitted until Pair and connect is
  selected.
- Android source declares `CAMERA` plus optional camera-any, back-camera, and
  autofocus features. A source validator pins the reviewed dependency/settings,
  rejects an unbundled first-use-download flag, and requires dependency terms to
  ship as a Flutter asset.
- Direct Gradle `assembleDebug` passed with 215 tasks after using the established
  temporary ASCII Flutter-SDK alias. The merged manifest contains the expected
  permission and optional features. The universal debug APK is 214,274,417
  bytes, 22,804,773 bytes larger than the prior 191,469,644-byte evidence. This
  is debug/universal packaging evidence, not per-device release download or
  installed-size evidence.
- The build retains existing AGP 9 built-in-Kotlin and SDK XML skew warnings and
  adds a `mobile_scanner` legacy Android DSL deprecation. A successful assembly
  does not erase those warnings. The package also registers a native macOS
  plugin even though this product exposes scanning only on Android; hosted
  macOS compilation remains required after publication.
- No physical Android camera, runtime permission dialog, Settings recovery,
  process death, rotation, front-only/camera-less device, dense Version 40
  recognition, or desktop-to-phone interoperability was exercised. These remain
  explicit device/Human gates rather than inferred passes.
