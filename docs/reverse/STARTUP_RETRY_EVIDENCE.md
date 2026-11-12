# Explicit local startup retry — source-bound evidence

This closes only **never-connected local startup retry**. Connected-workspace
crash recovery, draft/request reconciliation and implicit queue admission remain
separate open functional work. Remote stays unchanged.

## Source and admission

- Startup source `e8ece876dde92e8c3d2abd73604c39cbb636e8af` and follow-up
  `c8f5570de5f259ee6d5271aebe1264fe569d92fe`.
- Normal combined merge `c3957c994a57fa1d23cd6aa7e15a733b56040a23` preserves
  Gemini's U5 `3e8d381` / `76e3428` adaptive composer and inherited-label fixes.
- RuntimeController publishes one admitted startup Future before notifying
  listeners; repeated starts/retries join it. Explicit Retry startup is offered
  only after a failed raw attempt and cleanup settle, before any successful
  local connection, and while the controller is neither stopping nor disposed.
- Epoch/transport-identity checks fence locator, Host launch, initialization
  and ten relay subscriptions. Failed-session retirement preserves the eight
  application gateway streams. Public shutdown remains terminal.

## Machine verification

Three source regressions were reproduced before correction: no failure-page
Retry, a late locator overwriting Stopped, and a synchronous Starting listener
closing the app before a later Host factory call. Six startup cases now cover
the explicit action, failed initialization/one fresh retry/coalescing/stale
stream fence, both notification shutdown points, late Host cleanup and late
locator completion. They inject typed discovery/initialization contracts;
they launch no stock process.

Combined `c3957c9` passes:

- format: 207 files, zero changes; strict analysis: zero issues;
- pure-Dart boundary: 68 roots;
- default Flutter suite: **637 passes / five opt-in skips**;
- separately enabled direct-stock suite: **five passes each** on public
  `0.167.2` and installed `0.167.0-alpha.3.2`;
- history benchmark: 1,000 source turns / 100 retained, plus ten 3 MiB output
  iterations;
- two-job Linux release and 83-library runtime closure;
- all **245 tracked source inputs** unchanged through those gates.

Rust sources/manifests are unchanged. The earlier Rust fmt/Clippy/100-test
checkpoint is retained; it is not described as freshly rerun here. All local
heavy work was serialized, with Flutter concurrency one and Cargo/CMake two.

## Actual packaged runtime

Frozen bundle:
`/var/tmp/native-desktop-startup-u5-c3957c9-r1/bundle/`.

| Artifact | SHA-256 |
| --- | --- |
| `libapp.so` | `ea42c125346d657c2d2d12d511b21a8603de3c4c0f4c9f1dd280c45453de332a` |
| Native runner | `386bac01cfa9692d6d0d80dee6ad9baee8eef92ed607b494a8d629a678ff23af` |
| Bundled Host | `73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878` |

Evidence root: `/var/tmp/native-startup-retry-replay-r1/`, with
`walk-results.json`, process proofs and capture checksums. These are actual
App → bundled Host → stock processes in private Xvfb/DBus/profile/project
environments. Only the loopback model Responses endpoint is a deterministic
fixture. No user credentials, real account or model-quality acceptance is used.

| Scenario | Observation |
| --- | --- |
| Old `b22e955` bundle, Codex file initially absent | Failure has no Retry. Providing the private executable leaves the same failure screen unchanged; before/after capture hashes match. |
| Combined source / public `0.167.2` | Failure exposes Retry. Providing the executable and pressing Retry connects the **same App PID** to the real Host/stock. Explicit New thread at 720×800, first Send, completion and saved user/assistant content pass. Wide rendering also passes. |
| Combined source / installed alpha | Missing-executable Retry works at 720×800 on the same App PID. Wide Home first Send creates a thread and saves user/assistant content; compact readback passes. |
| Full public App/Host/stock restart | A different App PID selects the saved thread and reads both messages at 1191×865 and 720×800, without another model request. |

There are **24 captures**, including early/invalid driver captures retained
below. Total model calls are two, one for each candidate first turn. Each
candidate persists exactly one thread. All four GUI helpers exit zero with
process-tree checks; the exact owned model fixture exits after SIGINT. All
recorded App/Host/stock/model PIDs are gone. No unhandled exception or layout
overflow was observed in these walks.

## Negative evidence and limits

- Two initial widget drivers mixed real filesystem I/O and FakeAsync and
  timed out. Their logs remain under `/var/tmp/native-ui-r0.BbOvHT/`. The final
  widget uses typed discovery admission; actual filesystem availability is
  verified in the separate packaged walks. No production workaround hides
  the driver issue.
- `retry-connected-home.png` captured Starting too early; the later settled
  Home proves connection. A compact resize with no selected thread shows
  Threads, and an initial driver typed in its empty area before navigating
  to New thread. That capture is invalid Send setup, not a product failure.
  The corrected New thread/Send flow is independently captured. The first
  restart-wide capture also preceded selection completion; settled wide and
  compact history captures establish readback.
- The deliberately private locator PATH excludes normal utilities and causes
  a stock bubblewrap-availability warning. The fixture model also causes a
  stock metadata-fallback warning. Both remain visible/recorded; neither is
  claimed fixed by startup retry. Private GTK/MESA/accessibility diagnostics
  remain in the desktop logs.
- These are machine and agent real-use results. Human visual acceptance,
  signed-in official overlays and physical macOS/Windows behavior remain
  distinct gates. No hot-recovery or Remote-write parity is claimed.

## Hosted evidence

[Exact-source CI43140754985](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43140754985)
passes macOS and Windows builds. Its first Linux verify attempt failed at
**Install Linux build dependencies**, timing out after five minutes before any
analysis/test step. That failure is preserved. Only the failed job was rerun;
attempt two passes all three jobs at the exact source SHA. The initial timeout
remains part of the evidence. No workflow change was introduced to manufacture
a green result. Main's subsequent documentation/integration CI is a separate
exact-HEAD check.

The next functional slice is bounded authoritative inherited-settings
projection. Gemini independently owns the current-evidence Shell activity-card
translation. This checkpoint is not a program stop.
