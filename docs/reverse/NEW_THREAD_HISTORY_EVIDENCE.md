# Known-new-thread history admission

Source correction `732d2a4` is combined with U4 in `e052953`; regression
adaptations and the validated release source are `b22e955ab07ffe06b494dae3c31fa6a7fbd8a405`.

## Contract and correction

A just-created stock thread is not readable through `thread/turns/list` until
its first user input materializes it. Native already tracks that bounded
materialization state in ThreadListController. The app now passes this admission
marker to HistoryController, deferring only known-new empty history and saved
occurrence search. First materialization changes generation and hydrates once.
Ordinary history failures remain visible; neither RPC codes nor error wording
are reinterpreted as an empty conversation. Protocol, pagination and retention
limits are unchanged. Gemini reviewed the actual source with zero P0/P1/P2
findings and independently verified public-stock materialization-before-active
notification ordering.

## Machine and actual-runtime evidence

- Old-source product regression fails with one premature history read. The
  corrected history/thread/product cases and strict analysis pass. Missing
  input-frame and incomplete fake active-to-idle lifecycle negatives are retained.
- First combined full run: 624 passes, five skips, two old plain-text assumptions.
  Adaptation retains transformed-sliver geometry, actual mouse drag/select/copy,
  focus/scroll/resize checks and raw toolbar-copy coverage. One intermediate
  adaptation left the existing two-second Copy feedback timer pending; the test
  now completes it before teardown. The 37 focused cases pass. Gemini traced
  current build25894 user Markdown/entity decoding and raw-source Copy callers
  and challenged neither fixture assertion; general citation normalization is
  outside this particular raw-string check.
- Final source `b22e955`: format, strict analysis, 68-root pure-Dart boundary,
  626 default Flutter cases/five opt-in skips, five separately enabled stock
  cases, history memory benchmark and two-job Linux release/83-library closure
  pass. All 244 selected tracked input hashes match before/after. Rust source is
  unchanged from the prior fmt/Clippy/100-test checkpoint.
- [Exact-source hosted CI43128650668](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43128650668)
  passed verify, Windows x64 and macOS arm64 jobs. Physical-platform interaction
  and Human acceptance remain separate.
- Frozen artifact: `/var/tmp/native-new-thread-history-combined-r1/`, AOT
  `6168b2d89d2fbd29b1e802b239df1034397db19829d7ac6349e6cbf692be694d`,
  Host `73218b92…`. Its manifest, results, 20 GUI captures and checksums bind
  the actual packaged App → bundled Host → stock walks. Only the loopback model
  Responses service is a fixture; no account or user profile is used.
- Independently created old/new profiles reproduce the baseline `0286a4d`
  history error at 1191×865 and 720×800. The baseline creates one unmaterialized
  runtime thread and persists zero threads. The initial Home capture was too
  early; it is not an inert-click finding.
- Candidate public `0.167.1`: empty new conversation has no history error in
  both widths; first Send completes and stores user/assistant. A second empty
  thread and warm return work. Full App/Host/stock restart restores saved
  history in both widths without another model call. One persisted thread.
- Candidate installed `0.167.0-alpha.3.2`: empty first conversation and first
  Send from the 720 px composer completes in the 1191 px state. Empty state
  was inspected in both widths. One persisted thread. Total fixture model calls are
  two, one for each candidate's first turn; history reads trigger no extra turn.
- All owned App/Host/stock/Xvfb/private DBus/model workers exited. No observed
  Unhandled/overflow. Private-display accessibility/OpenGL resize warnings and
  stock's fixture-model metadata fallback warning are retained, not erased by
  the later successful frames.

This closes known-new-thread admission. Runtime startup retry/hot recovery,
provider-aware discovery, remaining functional gaps and Golden-State visual
parity remain active; this is neither account acceptance nor Desktop completion.
