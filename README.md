# Codex Native (Unofficial)

An open-source, native-first client for OpenAI Codex.

> This project is unofficial and is not affiliated with or endorsed by OpenAI.

## Goals

- Keep the official Codex harness and `codex app-server` as the intelligence/runtime layer.
- Replace the heavyweight desktop presentation layer with a bounded-memory Flutter UI.
- Treat Android as a first-class remote control plane, not a shrunken desktop IDE.
- Preserve Codex behavior in a fidelity-first mode: no client-side prompt rewriting, custom compaction, or tool-schema replacement.
- Make long-running sessions practical with pagination, virtualization, lazy diffs, and lazy tool output.
- Support reliable remote resume across Wi-Fi/mobile-network changes and app restarts.

## Planned architecture

```text
Desktop Flutter UI
        |
        | stdio / JSONL
        v
codex-native-host
        |
        | bounded/sanitized JSONL
        v
stock codex app-server
        |
        v
OpenAI / Codex

Android Flutter UI
        |
        | authenticated resumable WebSocket
        v
Host bridge on desktop/server
        |
        v
stock codex app-server
```

The UI is a projection of Codex state, never the source of truth.

## Status

Pre-alpha. Phase 1 is implemented: the Flutter desktop app locates a stock
`codex` executable, starts the bundled Rust Host, completes the stock app-server
initialization handshake, displays typed runtime state, and owns the process
lifecycle. Linux, Windows, macOS, and Android project shells are in the
repository; the bounded Android Remote transport foundation is in progress and
is not yet connected to product runtime state.

Phase 2 is locally implemented. The current desktop slice lists bounded pages
of thread metadata, starts threads, reads stored thread metadata without turns,
and resumes threads without hydrating their history. It can also start and stop
turns, coalesce assistant streaming into a bounded recent timeline, summarize
tool activity, and surface explicit approve-once/reject prompts. The UI retains
at most 100 thread rows and 200 recent conversation entries. Model and reasoning
choices come from live app-server discovery; approval and sandbox overrides are
explicit, and dangerous choices require confirmation. Turn diffs are projected
into bounded file summaries with a virtualized selected-file view.

Phase 3 is locally machine-verified on Linux. Stored history uses bounded `thread/turns/list` summary
pages and loads full items for only one selected turn. The Host incrementally
spools large command output behind opaque IDs before Dart sees the JSON, and the
UI reads only a 64 KiB virtualized range at a time. Inactive-thread history is
evicted immediately. Completed assistant responses render through a strict,
bounded Markdown allowlist: raw HTML is inert, images never load, only explicit
`http`/`https` clicks may open externally, streaming stays plain text, and rich
parsing falls back to a bounded tail above 16 KiB. Cross-platform and Human UI
validation remain.

Phase 4 has an explicit Host Remote option. Plaintext is loopback-only;
non-loopback exposure requires an operator-provided certificate/key and uses
rustls HTTPS/WSS with fail-closed startup and trusted-local atomic reload. Local
trusted administration can issue one-use pairing tickets, rotate TLS material,
and revoke hash-only device credentials. The authenticated `codex-native-v1`
WebSocket currently exposes a
strict read-only subset—`model/list`, bounded `thread/list`, and metadata-only
`thread/read`—through the same stock app-server and output sanitizer. A small
allowlist of sanitized lifecycle notifications now uses a 512-event/8 MiB
sequence journal with ACK, same-session replay, and explicit gap resync. Token
deltas, diffs, server requests, and writes/approvals remain unrouted. A bounded
Dart `RemoteTransport` now enforces WSS-by-default negotiation, request/event
limits, ACK/resume, initial authoritative resync, and stale-resync rejection
while reusing the typed protocol adapters. A separate lifecycle owner now adds
device/session-bound applied-cursor persistence, bounded model/thread hydration,
exact apply-before-persist sequencing, capped reconnect backoff, stale-attempt
rejection, and terminal recovery/revocation states. It is not wired into the
Android runtime or UI yet. A versioned system-CA connection profile and device
bearer live behind platform secure storage with explicit unreadable/corrupt
recovery and Android backup/transfer exclusions; the bearer is never put in
ordinary preferences or diagnostics. Pairing-bound self-signed certificate
trust, Android app/process lifecycle wiring, product integration, and real-device
validation remain.

## Run locally

Prerequisites:

- Flutter 3.47.1 or a compatible newer version;
- Rust 1.87 or newer with Cargo;
- Codex available on `PATH`, or `CODEX_EXECUTABLE` set to the executable path.

```sh
flutter pub get
flutter run -d linux
```

The transport-only stock runtime check is also available:

```sh
dart run tool/runtime_smoke.dart
dart run tool/thread_smoke.dart
dart run tool/turn_smoke.dart
dart run tool/approval_smoke.dart
dart run tool/model_smoke.dart
flutter test tool/coding_task_smoke.dart --reporter expanded
flutter test tool/history_memory_benchmark.dart --reporter expanded
dart run tool/host_memory_benchmark.dart
dart run tool/host_lifecycle_soak.dart
cargo build --release --workspace
dart run tool/remote_smoke.dart
```

Remote is disabled unless the Host receives `--remote-listen` (or
`CODEX_NATIVE_REMOTE_LISTEN`). Plaintext accepts only a literal loopback
address. A network listener additionally requires both `--remote-tls-cert` and
`--remote-tls-key` (or the matching `CODEX_NATIVE_REMOTE_TLS_CERT` and
`CODEX_NATIVE_REMOTE_TLS_KEY` variables); on Unix the private key must be
owner-only. Replace certificate/key files completely, then invoke trusted local
`host/remote/tls/reload` to rotate new handshakes. A failed reload keeps the last
valid certificate.

`tool/remote_smoke.dart` remains plaintext-loopback by default. To exercise WSS,
set `CODEX_NATIVE_REMOTE_SMOKE_TLS_CERT` and
`CODEX_NATIVE_REMOTE_SMOKE_TLS_KEY`; its Dart clients build an explicit trust
context from that certificate and never use an accept-all callback.

## Verify

```sh
dart format --output=none --set-exit-if-changed lib test tool
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
flutter analyze
flutter test
flutter build linux --debug
```

Linux and Windows native builds compile and place `codex-native-host` beside the
Flutter executable. The macOS build embeds it in `Contents/MacOS`; macOS is a
direct, signed/notarized distribution rather than a Mac App Store sandboxed app.
Set `CODEX_NATIVE_HOST` only for development diagnostics when using a separately
built Host. There is intentionally no direct app-server fallback.

## License

Apache License 2.0. Direct dependency provenance is recorded in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
