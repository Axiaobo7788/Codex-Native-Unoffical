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
