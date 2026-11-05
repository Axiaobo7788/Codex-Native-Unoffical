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

Pre-alpha. The repository is being bootstrapped.

## License

Apache License 2.0.
