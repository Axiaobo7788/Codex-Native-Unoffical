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
repository; the bounded Android Remote path is in progress and currently exposes
only a read-only model/thread metadata surface after secure pairing.

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
rejection, and terminal recovery/revocation states. Android now constructs that
stack, suspends it while hidden, resumes it when shown, and renders only the
bounded model/thread metadata in an explicitly read-only virtualized panel. A
versioned connection profile and device bearer live behind platform
secure storage with explicit unreadable/corrupt recovery and Android
backup/transfer exclusions; the bearer is never put in ordinary preferences or
diagnostics. Android now accepts one bounded `codex-native-pairing-v1`
invitation carrying the exact WSS `/v1/ws` endpoint, one-use ticket, expiry, and
either system-root trust or one explicitly pairing-bound certificate. The
same-origin HTTPS exchange has strict input/response schemas, 8 KiB body limits,
connection/request deadlines, no redirect or certificate bypass, and verified
secure-storage readback before Remote starts. The same scoped TLS identity is
then used for WSS.
Unreadable or revoked profiles require an affirmative local clear. A trusted
desktop setup surface now reports the listener/TLS/bind/advertised endpoint,
creates a transient five-minute invitation only on request, offers an explicit
clipboard action, renders the exact invitation as one bounded medium-correction
QR code when it fits, and confirms device revocation without exposing stored
bearers. Oversized invitations retain their complete manual-copy fallback, and
expired tickets plus their QR projections are removed automatically. Android
now offers explicit QR-only camera intake that validates and fills the existing
obscured invitation field without auto-pairing; manual paste remains available.
Full conversation features and real-device validation remain.

## Run locally

Prerequisites:

- Flutter 3.47.1 or a compatible newer version;
- Rust 1.89 or newer with Cargo;
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

To make the desktop setup surface produce a shareable invitation, also set
`--remote-advertise-endpoint wss://host.example/v1/ws` (or
`CODEX_NATIVE_REMOTE_ADVERTISE_ENDPOINT`). This is the exact client-facing
address and is intentionally separate from the bind address for wildcard,
reverse-proxy, NAT, and split-DNS deployments. It must not contain credentials,
query parameters, or fragments. The UI reports a missing value and will not
guess one or enable networking.

For a private CA or self-signed deployment, additionally set
`--remote-pairing-trust-cert CERT.pem` (or
`CODEX_NATIVE_REMOTE_PAIRING_TRUST_CERT`) to exactly one certificate that
should anchor this endpoint. This file is public trust material, not the private
key. It can be the direct self-signed leaf or, preferably for planned server
certificate rotation, a stable private CA. The Host validates and snapshots it
at startup, then embeds its DER identity in each versioned invitation. It is
deliberately separate from `--remote-tls-cert` because a reverse proxy may own
the client-visible certificate. Without this setting, invitations explicitly
use the Dart/Android runtime system roots. Changing an exact self-signed leaf
requires Host restart and re-pairing; rotating a leaf under the same configured
CA does not change the stored trust anchor.

`tool/remote_smoke.dart` remains plaintext-loopback by default. To exercise WSS,
set `CODEX_NATIVE_REMOTE_SMOKE_TLS_CERT` and
`CODEX_NATIVE_REMOTE_SMOKE_TLS_KEY`; its Dart clients build the explicit trust
context from the versioned Host invitation, prove that ordinary system trust
rejects the generated self-signed identity for both HTTPS and WSS, and never use
an accept-all callback.

The current Android onboarding form accepts only the complete versioned
invitation plus a bounded device name. It never accepts or displays a bearer
token and never learns trust after sending the ticket. The desktop product does
not yet verify real-network reachability; the operator remains responsible for
DNS, firewall, proxy routing, endpoint hostname/SAN consistency, and
transferring the invitation through a trusted local channel. QR rendering is
available only when the exact invitation fits one standard medium-correction
symbol at an integer module scale. It never splits, compresses, or rewrites the
protocol envelope; the desktop always retains selectable text and an explicit
copy action. On Android, Scan QR requests camera access only after the button is
selected, accepts the first exact current versioned invitation, and returns it
to the obscured form for separate Pair and connect confirmation. Missing camera
hardware, denied permission, invalid codes, and unusual oversized invitations
retain manual paste. The barcode model is bundled for immediate use, but ML Kit
may send documented performance/utilization metrics; camera frames and decoded
invitation content remain on-device. Real camera and cross-device behavior are
not yet physically validated.

## Android release signing

Android debug builds use the normal local debug certificate. Release builds do
not fall back to that certificate and do not produce an unsigned artifact. Copy
`android/key.properties.example` to the ignored `android/key.properties`, point
`storeFile` at an external upload keystore, and provide all four values before
running a release build. Keep both files containing secrets outside version
control; the example contains placeholders only.

```sh
flutter build appbundle --release
```

The Android App Bundle is the preferred Play upload format. A missing,
incomplete, or unreadable signing configuration fails at `preReleaseBuild`
without printing property values. No production upload key or Play App Signing
account is configured by this repository, and CI intentionally builds only the
debug APK until a separately authorized signing workflow exists.

## Verify

```sh
dart format --output=none --set-exit-if-changed lib test tool
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
./tool/generate_native_licenses.sh --check
dart run tool/verify_android_release_signing.dart
dart run tool/verify_android_pairing_scanner.dart
flutter analyze
flutter test
flutter build linux --debug
flutter build apk --debug
```

Linux and Windows native builds compile and place `codex-native-host` beside the
Flutter executable. The macOS build embeds it in `Contents/MacOS`; macOS is a
direct, signed/notarized distribution rather than a Mac App Store sandboxed app.
The same builds package `NATIVE_HOST_THIRD_PARTY_LICENSES.txt` beside the Host on
Linux/Windows and under `Contents/Resources` on macOS. Regenerate it with pinned
`cargo-about` 0.9.3 via `./tool/generate_native_licenses.sh --write` after any
native dependency change.
Set `CODEX_NATIVE_HOST` only for development diagnostics when using a separately
built Host. There is intentionally no direct app-server fallback.

GitHub Actions is configured with explicit Flutter 3.47.1 and Rust 1.89.0
toolchains for Linux/Android on Ubuntu 22.04 x64, Windows on Windows Server 2022
x64, and macOS on macOS 15 arm64. The desktop jobs build the native app bundle,
run the packaged Host's `--help` smoke, and compare the packaged native-license
notice with the committed source. Top-level actions are pinned to immutable
commit SHAs and checkout does not persist credentials. A configured workflow is
not evidence for an unpublished local commit: inspect the corresponding hosted
run after that commit is deliberately pushed.

## License

Apache License 2.0. Dependency provenance and complete native license texts are
recorded in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
