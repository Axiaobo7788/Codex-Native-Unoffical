# Bounded live and saved reasoning projection

Source: `0286a4dfbc99390f7ad9c35d6e74920ae25b2d64`, based on main
`abd0e41`. This closes the observed data projection defect. Official first-part
emphasis is a separate Gemini-owned presentation correction; Golden State A7
remains PARTIAL.

## Evidence and correction

Actual U3 stock replay exposed a flattened 240-character live body. The protocol
also discarded started/completed summary arrays, and the controller ignored
summaryIndex. Saved history joined parts with one newline, differing from the
observed official paragraph composition.

The corrected adapter projects typed reasoning snapshots and bounded deltas.
The controller retains at most 8 KiB and 32 sparse summary parts per item,
respects smaller entry budgets, coalesces at the existing interval, and keeps the
existing pending-item/entry/thread limits. Nonempty completed stock snapshots
replace partial live state; older empty/missing snapshots retain observed text.
Thread changes clear transient state. Optional immutable reasoningParts carries
structure to presentation. Protocol/raw Execution/Find text gains no invented
Markdown emphasis. ADR-060 records the boundary.

## Targeted peer audit and negative evidence

Gemini reviewed the actual diff through the official agy TUI and reported no
P0/P1 plus two P2s: UTF-16 clipping could split a surrogate pair, and saved
multipart reasoning lost paragraph boundaries. Both were independently
reproduced before correction. Prefix clipping now respects code-point boundaries;
live and saved adapters share bounded part parsing and paragraph boundaries.
The peer accepted the typed parts seam, including an empty first index; final
consumption/recheck occurs in its presentation follow-up.

Three old-source pipeline cases reproduce multiline/index/snapshot loss. Three
P2 red cases reproduce both clipping paths and saved paragraph loss. The first
new implementation exposed a smaller maxEntryCharacters budget violation and
was corrected while preserving the Reasoning entry kind. An unused private
history helper was removed after strict analysis identified it. Negative logs
remain under `/var/tmp/native-ui-r0.BbOvHT/reasoning-*`.

## Machine validation

- Format 204 files/zero changes, strict analysis, pure-Dart 68 roots.
- 615 default Flutter cases plus five opt-in skips; this mixes unit/widget/typed
  simulated-runtime integration and is not a full-process E2E count.
- Five separately enabled actual-stock cases and history memory benchmark pass.
- Two-job Linux release and 83-library closure pass. All 218 tracked
  application/test/tool/Linux/build-input hashes match before/after validation.
- The first build omitted the Cargo job environment and was intentionally
  terminated with its owned tree (exit143). Rerun explicitly verified
  CARGO_BUILD_JOBS=2 and CMake parallel2. The interrupted build is not a pass.
- Rust source is unchanged from the earlier fmt/Clippy/100-test checkpoint.
  Auxiliary ASCII validation does not establish a Unicode-path LSP fix.

## Agent real-use comparison

Artifact root: `/var/tmp/native-reasoning-stream-0286a4d-r1/`.
Candidate AOT: `9f9c6d2a91254129e9b4a11810bebd23052f36c860709ab12d30d172b32dddc0`.
Host: `73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878`.

The real packaged App → bundled Host → public stock 0.167.1 was exercised before
and after, using the same U3 presentation. Each private profile was seeded
directly; no SQLite or rollout paths were cloned. Only model responses and an
image sentinel used loopback fixtures. The provider emits two reasoning parts
and then a real stock completed turn.

Root independently inspected both live07 captures. Baseline03b23c4 collapses and
cuts the body; candidate0286a4d displays two paragraphs, all four list rows and
FINAL-REASONING-SENTINEL. The 140 px scroll cap and observed elapsed header
remain. Ten model fixture calls and zero sentinel image requests were observed.
Both logs have zero Unhandled/overflow failures. All owned App/Host/stock/Xvfb/
model/DBus workers were verified gone after the replay exited0.

This is agent real-use with a model fixture, not real-account inference or Human
acceptance. First-part emphasis, full signed-in official same-state comparison,
subjective feel and unavailable physical platform gates remain separate. Existing
stock fixture metadata and graphics/accessibility warnings are preserved.
