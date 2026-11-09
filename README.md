# Codex Native (Unofficial)

A pre-alpha Flutter client for OpenAI Codex. Desktop uses the bundled Rust
`codex-native-host` and your stock `codex app-server`. This project is unofficial
and is not affiliated with or endorsed by OpenAI.

## What works today

- **Desktop:** create and resume threads, browse bounded history, stream or steer
  turns, approve tool requests, choose models and execution settings, and inspect
  bounded diffs and command output. The desktop layout has a 260 px sidebar,
  a 704 px reading/composer column, and a compact layout for narrow windows.
- **Organization and review:** archive, rename, pin, and group local threads into
  sections. Global section counts describe loaded rows. Browse one local section
  at a time in stock order with bounded pagination. Eligible pins are saved in
  stock Pinned. Quick pins on custom-section threads and older runtimes are
  labeled session-only.
  Manage a local thread Goal from its sidebar menu. Desktop code review can
  target uncommitted changes, a base branch, a commit or ref, or custom
  instructions on an eligible thread.
- **Runtime tools:** discover Skills, Plugins, installed Apps and MCP servers.
  Available actions and catalogs depend on the installed Codex runtime and its
  configuration.
- **Android and Direct Host Remote:** pair by QR or invitation, reconnect, and
  inspect bounded model/thread metadata on Android. The authenticated transport
  also supports bounded history reads and sequenced lifecycle updates. Remote
  thread/turn writes, approvals, diffs and command-output reads are unavailable.

**Experimental:** Desktop can expose stock Official Remote host controls when
the installed runtime supports them. Native Android uses Direct Host pairing.
ChatGPT Chat, Work cloud orchestration, a Responses backend, and a Native
client for the official Remote relay are not implemented. Prose, Commands and
Execution change the Codex timeline display.

## Run locally

Install Flutter 3.47.1, Rust 1.89 or later, platform Flutter build dependencies,
and a stock Codex executable. Put `codex` on `PATH` or set `CODEX_EXECUTABLE`
to its path. Configure your Codex authentication separately.

```sh
flutter pub get
flutter run -d linux
```

Windows and macOS builds also package the Rust Host. A Linux debug build is
available with `flutter build linux --debug`. Use `CODEX_NATIVE_HOST` only to
point at a separately built Host for development. See the
[Remote setup architecture](docs/ARCHITECTURE.md#remote-model) for opt-in WSS,
certificate trust, and advertised endpoints.

## How it works

Flutter consumes typed, bounded projections. Desktop uses stdio JSONL to the
Host, which owns the app-server process and spools large command output to
private files. Android uses an authenticated, resumable WebSocket and keeps
OpenAI credentials on the Host. History is paginated, long lists are
virtualized, and output and diffs are read on demand. The stock Codex harness
owns prompts, tools, execution and conversation persistence.
[Architecture](docs/ARCHITECTURE.md)

## Verify

```sh
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_pure_dart_boundary.dart
dart analyze
flutter test
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

`test/simulated_runtime/` drives the real Flutter UI through a typed fake
runtime controller. It covers product interactions. Direct stock tests are
opt-in and run in disposable state.

```sh
CODEX_NATIVE_STOCK_TEST=1 flutter test test/live/stock_app_server_test.dart
```

For Host-backed runtime checks, build the Linux bundle and run the smoke tools
against your installed Codex. Review smoke runs a model turn against its own
Git fixture. A packaged desktop walkthrough and Human acceptance are separate
verification steps.

```sh
flutter build linux --debug
export CODEX_NATIVE_HOST="$PWD/build/linux/x64/debug/bundle/codex-native-host"
dart run tool/runtime_smoke.dart
dart run tool/thread_smoke.dart
dart run tool/model_smoke.dart
dart run tool/review_smoke.dart
flutter test tool/history_memory_benchmark.dart --reporter expanded
```

See [project status](PROJECT_STATUS.md) for current evidence and pending gates.
See [the feature matrix](docs/reverse/OFFICIAL_FEATURE_MATRIX.md) for supported,
experimental and research-only surfaces.

## License

Apache-2.0. See [LICENSE](LICENSE) and the
[native Host dependency notices](licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt).
