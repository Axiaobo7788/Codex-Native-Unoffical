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
`codex` executable, starts `codex app-server --listen stdio://`, completes the
initialization handshake, displays typed runtime state, and owns the child
process lifecycle. Linux, Windows, macOS, and Android project shells are in the
repository; Android remote control is a later phase.

Phase 2 is locally implemented. The current desktop slice lists bounded pages of thread
metadata, starts threads, reads stored thread metadata without turns, and
resumes threads without hydrating their history. It can also start and stop
turns, coalesce assistant streaming into a bounded recent timeline, summarize
tool activity, and surface explicit approve-once/reject prompts. The UI retains
at most 100 thread rows and 200 recent conversation entries. Model and reasoning
choices come from live app-server discovery; approval and sandbox overrides are
explicit, and dangerous choices require confirmation. Turn diffs are projected
into bounded file summaries with a virtualized selected-file view. Stored
turn-history pagination is the next performance slice.

## Run locally

Prerequisites:

- Flutter 3.47.1 or a compatible newer version;
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
```

## Verify

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build linux --debug
```

## License

Apache License 2.0.
