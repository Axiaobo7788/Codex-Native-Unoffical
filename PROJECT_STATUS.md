# Project Status

**Program mode: `SELF_ITERATION`**
**Current phase: Codex Desktop Completion — Functional Parity + High-Fidelity UI.**
**Program objective: finish the Codex Desktop product before expanding scope.**

This phase deliberately narrows **scope**, not quality. The first major target is
the Codex Desktop experience itself: supported Codex functionality should have no
known material gap versus the legitimate current official/stock surface, and the
Desktop UI should continue toward high-fidelity clean-room translation rather
than settling for a merely usable approximation.

Use this page for current facts, [the feature matrix](docs/reverse/OFFICIAL_FEATURE_MATRIX.md)
for the living functional queue, [Golden State A](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md)
and later Golden States for the UI queue, [Architecture](docs/ARCHITECTURE.md) for
system boundaries, and [Decisions](docs/DECISIONS.md) for ADRs.

## Codex Desktop completion scope

Two first-class tracks run in parallel:

### Track F — Codex functional parity

- Re-audit current Native HEAD against the current public/stable stock app-server
  schema, deliberately adopted public experimental stock surfaces, and
  reproducible official Codex Desktop workflows.
- Close every supported Native `MISSING` or material `PARTIAL` capability or
  workflow gap.
- Keep real-stock/runtime verification, lifecycle correctness, bounded memory,
  state recovery, security and truthful unsupported/error behavior at the
  existing high standard.
- A green test suite is necessary but not sufficient; after the living queue
  closes, perform another fresh parity audit.

### Track U — Codex Desktop high-fidelity UI

- Continue the Golden-State translation contract at high standard.
- Do not downgrade to "good enough" visual approximation merely because the
  feature is reachable.
- Current official live behavior, screenshots, ASAR/CSS/component evidence and
  same-state Native captures remain the translation specification.
- Close machine-actionable `PARTIAL` / `DIVERGED` / `MISSING` Codex Desktop
  presentation rows to `MATCH` / `PARITY_ACCEPTABLE`, or explicitly prove the
  remaining state is evidence-blocked / Human-only.
- Human visual acceptance remains distinct from machine verification.

Neither track blocks the other from making independent progress. Functional work
must not wait for cosmetic UI closure, and UI work must not stop merely because a
functional slice is still open.

## Deferred expansion while Codex Desktop is incomplete

Preserve existing work, but do not let these areas steal program priority unless
they are required to verify a Codex Desktop workflow:

- independent ChatGPT Chat backend;
- Work cloud orchestration;
- Responses backend;
- new Android / Direct Host Remote feature expansion beyond maintaining existing
  correctness;
- mobile-first presentation expansion;
- public UI package extraction / MD3 alternative skin;
- unrelated infrastructure or release polish not needed by the current Codex
  Desktop completion gate.

Existing supported Codex Desktop integrations such as Skills, Plugins, Apps,
MCP, Review, Goals, local runtime diagnostics and any legitimate stock Desktop
capability remain **inside** Track F even if they are optional or experimental.

Private/internal first-party services remain `PRIVATE_ONLY`; high standards do
not authorize adopting unsupported private APIs or credentials.

## Current work selector

Run both tracks with equal seriousness:

1. Codex/Codex-owned work: fresh functional-parity audit, then highest-value
   supported `MISSING` / material `PARTIAL` / `READY` functional gap.
2. Gemini/Gemini-owned work: highest-impact evidenced Golden-State UI row or
   coherent row cluster.
3. Use separate worktrees and one writer per overlapping file surface.
4. Integrate coherent checkpoints, run targeted + shared gates, exercise real
   stock paths where practical, update both matrices, then immediately select
   the next pair.
5. If one track becomes evidence-blocked, continue the other. Do not idle the
   program while either track has machine-actionable work.

### Codex Desktop completion gate

Do not declare the Codex Desktop target complete until all are true:

- Track F has no known supported Native `MISSING` or material `PARTIAL`
  functional/workflow row after a fresh audit;
- every supported capability has a reachable, truthful Desktop access path and
  real-stock evidence where locally practical;
- Track U's current Codex Desktop Golden States have no machine-actionable
  `PARTIAL` / `DIVERGED` / `MISSING` row;
- no known P0/P1 correctness, security, state-loss, lifecycle, bounded-memory,
  accessibility or normal-use defect remains;
- remaining differences are explicitly visual/Human-only, `EVIDENCE_BLOCKED`,
  `BLOCKED`, `PRIVATE_ONLY`, `RESEARCH_EXHAUSTED`, or outside the narrowed
  Codex Desktop scope.

High fidelity remains a goal of this phase. Narrowing scope must never be used as
permission to lower the engineering or visual quality bar.

## Active peer coordination

- Main/origin now include integrated `0e2a5b8`; exact hostedCI43203383623
  passes verify/macOS/Windows. The combined provenance preserves approvals `c2b5a64`/`474ec93`, Gemini U8 `6f196cee`,
  clipboard `571a656`, conservative aggregate removal `4a8f83a`, and Track F
  statistics `ac47002` through ordinary merges. Last production merge:
  `1f20a78a16496cbaa7fcee24b2a49a3853b9ff61`. Git is canonical for actual HEAD.
- Approval choices preserve exact stock scope, explicit refusal/cancellation and
  request identity. A bounded response menu fixes legibility without the earlier
  vertical Wrap overflow. Old deciding/error completions cannot affect a newer
  request reusing the ID. Gemini's source reinspection closes the original
  1P1/2P2 on `474ec93`; historical findings/REDs remain preserved.
- U8 translates saved interrupted/failed grouping, search/collaboration/reroute
  captions, inline stats and all four numeric Shell exit-code call sites. Root
  inspected source and actual owner r3 captures. Visible count/stat equality is
  **not** per-item content identity: `4a8f83a` removes aggregate-as-item disclosure.
  The preview primitive is staged for an authoritative typed/lazy per-item seam.
- `ac47002` fixes raw add/delete versus unified-update statistics with one bounded
  pure-Dart helper. Actual public/installed stock emits the same `+3 -0` live and
  saved result for created sign-prefixed Markdown. This is not per-item preview
  implementation or A7 closure.
- Root holds the exclusive heavy lease after the combined gates/build and packaged
  walk, now for the next file-diff seam. Gemini stays source/docs-only for independent review and
  current official evidence. Flutter1/Cargo-CMake2 remain serialized. Live peer
  communication remains the official agy TUI only.

## Current verification checkpoint

- Approval correction: 70 focused cases, strict analysis0/pure68/format214;
  exact `474ec93` hosted [CI43195046161](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43195046161)
  passes verify/macOS/Windows. Source-only peer reinspection reports no open
  P0/P1/P2 on that correction; merged gates remain separate.
- File statistics: 5 RED regressions; 43 focused live/history cases pass,
  strict analysis0/pure69/217-file format passes. Two actual bundled-Host stock
  probes verify live and saved `+3 -0`, session editing and process cleanup.
  [Statistics evidence](docs/reverse/FILE_CHANGE_STATISTICS_EVIDENCE.md).
- Real approvals: 4 command-rule/cancel and 4 file-session/cancel cases pass on
  public0.167.2 and installed0.167.0-alpha.3.2. Exact persisted prefixes, repeated
  identical command and independent interrupted outcomes are checked. All owned
  workers exit. Managed-network natural emission remains unverified.
  [Evidence and preserved negatives](docs/reverse/APPROVAL_CHOICES_EVIDENCE.md).
- **Combined source5dd4758:** format217/zero changes, strict analysis0, pure69,
  **724 default Flutter passes/five explicit skips**, five enabled direct-stock
  cases on each binary, memory100/1,000 plus ten3MiB outputs, Cargo format and
  two-job Linux/83-library closure pass. All255 tracked build/validation hashes
  remain unchanged. The earlier723-pass/one-failure run and actual-scroll test
  correction remain preserved; no production virtualization was disabled.
- Frozen packet: `/var/tmp/native-desktop-approval-u8-r2/bundle/`, AOT
  `55b7a35d59c316cbd4bf7779235175a04eb445648469ac155e9690f6cb7871c8`,
  Host `73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878`.
  Ten new packaged captures verify the real approval response menu at1191x865
  and840x420. Open/Escape/resize grants nothing; explicit exact-rule selection
  executes, and an identical second command completes without another choice.
  Persisted rule equality, two marker lines/four model calls and owned-process
  retirement pass. Frozen binary hashes remain identical after use. The first
  synthetic Home Return did not submit; explicit Send followed. That input
  observation stays recorded rather than being called keyboard-parity proof.
- Main0e2a5b8 exact [CI43203383623](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43203383623)
  passes all three jobs. These local/controlled-model results do not establish Human acceptance, managed-network
  emission or live provider-account use. Rust source is unchanged in this
  checkpoint; no new local Clippy/full-Rust run is inferred.
- Previous shared recovery source55dcf16 passed 689 default cases/five skips,
  5 enabled stock cases per binary, memory100/1,000 plus ten3MiB outputs and
  two-job Linux/83-library closure. Its frozen packet and actual recovery/error/
  retry/Back-Forward captures remain in the [recovery evidence](docs/reverse/WORKSPACE_RECOVERY_EVIDENCE.md).
  Mainba6 hosted [CI43178375434](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43178375434)
  is green; it is not evidence for the later combined branch.
- Source7d settings/provider/Shell results remain in the [earlier checkpoint](docs/reverse/SETTINGS_SHELL_PROVIDER_CHECKPOINT.md).
  Earlier real runtime, fixture, APT and Unicode-path LSP negatives remain
  preserved. ASCII-path gates do not establish that the Unicode-path bug is fixed.

## Active next file-diff sub-slice

Root owns Host/protocol/domain/controller surfaces in
`agent/codex-file-change-item`; Gemini owns U9 official per-file evidence and
presentation in its isolated worktree. Root retains the exclusive heavy lease.
The Host now spools exact FileUpdateChange bodies and emits opaque descriptors
plus key-order-independent metrics; direct/raw and read-only Remote summaries
remain compatible.108 Rust/Clippy and46 protocol/analysis0/pure69 gates pass.
An old/new Host-process fixture preserves the old8MiB fatal rejection and new
9MiB ->407-byte sanitized event +96-byte range read. Separate public/installed
real-stock small-file statistics/session probes pass with the new Host.
[Evidence](docs/reverse/FILE_DIFF_HOST_SPOOL_EVIDENCE.md).

The next typed metadata/read seam now passes100 targeted cases, strict0 and
pure70. Live/details retain bounded metadata/descriptors; turn summaries carry
no file references. Patch ordering and runtime retirement preserve terminal and
session truth. Explicit previews use the live capability or one-item cold
refresh,64KiB reads/80 lines/24Ki code-unit retention and4 physical/cache slots.
Public and installed real stock verify original-item content after a second
workspace edit and fresh references after Host restart, with no model replay;
all owned processes exit. [Read-seam evidence](docs/reverse/FILE_CHANGE_PREVIEW_SEAM_EVIDENCE.md).

U9 primitives are independently gated at22abb4f (59 targeted cases, strict0,
format218/pure69) after preserved format/API/21px layout negatives. Timeline
binding, source-coherent shared gates, packaged same-state comparison and
file-window paging remain ACTIVE. Root has the exclusive heavy lease; Gemini
continues source/evidence/binding preparation. No main/UI completion is claimed.
An adjacent large aggregate turn/diff forwarding path still needs runtime
reconciliation; current stock source has no equivalent diff-size cap. Golden A7
and the larger Desktop F+U phase remain PARTIAL/SELF_ITERATION.

## Current architecture truth

- The stock Codex harness owns intelligence, sessions and tool semantics.
  Desktop uses pure-Dart typed adapters through bundled Rust Host stdio; the
  core client does not require Node/Electron or reimplement the agent loop.
- Conversation state is bounded: paginated history, virtualized lists, bounded
  inactive/live projections and coalesced streaming. Markdown/images are
  bounded; command output stays Host-backed and lazy. Changes remains a bounded
  turn aggregate; per-item file previews and Host-backed file-diff payloads are
  still separate machine-actionable work. Upstream deferOutput
  acceptance is not proof of deferred loading; whole-item fallback limitations
  remain explicit.
- Loaded settings are stock acknowledgement, never catalog-default inference.
  The 100-entry metadata/invalidation cache uses local generation/order fences;
  null writable overrides stay null until the user selects them. Home/current-
  cwd preview and complete provider editing remain separate supported gaps.
- Explicit local active/unsectioned saved-title search includes all providers,
  matching current official fallback. Normal, archived and section catalogs
  keep their existing scope. Foreign history is readable without resume;
  current public/installed stock reject foreign resume with a visible mismatch.
  No automatic provider/configuration switch is performed.
- A7/C Shell disclosure uses the current measured component structure and a
  bounded 4 KiB inline output preview. Nullable int32 exitCode flows through
  typed adapters to the footer. Full output remains separately available.
- Local MCP global OAuth/resource/tool flows remain stock-owned and bounded.
  Their browser evidence uses a controlled GIO handler, not real account/
  external-browser/portal acceptance. Scope/concurrency expansion stays
  separately classified in the functional audit.
- Remote remains readOnlyCodex. No thread/turn writes, approvals, diffs or
  command-output read parity is claimed. Mobile, Chat/Work/Responses and other
  expansion remain deferred under the Desktop completion scope above.

## Remaining work and Human gates

- Both tracks still have machine-actionable work. The
  [functional audit](docs/reverse/CODEX_DESKTOP_FUNCTIONAL_AUDIT.md) and
  [living matrix](docs/reverse/OFFICIAL_FEATURE_MATRIX.md) remain canonical for
  supported missing/partial workflows, including advertised approval choices, Home settings,
  account lifecycle, global content search and queue/terminal management.
- [Golden State A](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md) remains PARTIAL.
  U6 Shell cards, U7 user-bubble clipping and acknowledged controls do not close saved-activity hierarchy,
  every popover/state, Home, Changes, Review, compact or dark comparisons. U7
  rendered-height clipping is implemented; remaining evidenced A6/A7 differences
  are active machine work, not delegated to a generic Human gate.
- **NOT YET HUMAN VERIFIED:** matched signed-in official visual comparison,
  subjective interaction/long-session acceptance and unavailable physical
  platform checks remain surface-scoped. Physical Android checks are deferred
  outside this Desktop phase. No whole-program Human stop is justified.
- Global stop predicate is false. Continue the independent F/U ownership pair
  after every integration/checkpoint. Do not expand into another product phase.

## Durable history

Git is canonical for actual HEAD/worktrees. Earlier status/checkpoint narratives
are preserved in [the24201ac snapshot](docs/history/PROJECT_STATUS_at_24201ac.md),
[the7d snapshot](docs/history/PROJECT_STATUS_at_7d0282d.md),
[Desktop UI history](docs/history/DESKTOP_UI_CHECKPOINTS_through_9a75ddc.md)
and the source-bound evidence linked from the functional audit. ADRs remain in
[Decisions](docs/DECISIONS.md); old test counts are historical evidence, not
current verification claims.
