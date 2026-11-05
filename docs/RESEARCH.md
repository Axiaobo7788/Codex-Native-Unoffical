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
