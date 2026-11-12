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

- Current shared **validation source** is `24201ac2ee22a5cb2befab8f129f2137f920f623`,
  a normal merge preserving Codex recovery `5e08cfe` / `3d68ebe`, Gemini U7
  `44a8809`, and its initial peer audit `3c18450`. It is pushed on the Codex
  branch. Main is still `2600ec5` (docs over source7d) until the current coupled
  corrections are integrated; no history rewrite or overwrite is needed.
- Core local recovery is machine and controlled real-stock verified. It retains
  one mounted editor/draft/attachment state, retires old operations/requests and
  Host references, and reconnects without implicit resume or write replay.
  Unavailable prior-session drafts require an explicit new-conversation action.
  The old failed real packet remains preserved; the new packet demonstrates
  the actual correction on both public and installed stock.
- Codex owns the compact/collapsed replacement-failure feedback follow-up in
  `conversation.dart` and its existing continuity test. A real widget RED proved
  the compact error was hidden. The first notice fix covered Send after a
  successful retry; that negative is preserved. Seven updated widget cases and
  strict analysis now pass after removing the obsolete notice at a new attempt.
- Gemini owns the coupled Back-stack placeholder correction in isolated
  `agent/gemini-runtime-draft-navigation`, based on24201ac. Its writable surfaces
  are ThreadListController, app shell and a new navigation test; Codex does not
  edit them concurrently. Gemini has the exclusive heavy lease for targeted
  validation; Codex is source/docs/CI-only. All Codex real-use workers exited.
- U7 is source-integrated in the shared validation branch, with later peer
  review `5746b8e` reporting zero P0/P1 at its explicitly inspected source.
  Golden A stays PARTIAL. The next UI candidate remains evidenced A7 saved/live
  activity hierarchy and non-Shell rows, followed by other actionable A rows.
- Live communication is official agy TUI-only, refreshed after the long session.
  Peers remain equal; one writer per overlapping surface. Flutter uses one
  worker, Cargo/CMake two jobs, with no overlapping heavy workloads.

## Current verification checkpoint

- **Source24201ac machine gates:** format209/zero changes, strict analysis0,
  pure-Dart68, **685 default Flutter cases/five explicit stock skips**. Five
  enabled direct-stock cases pass separately on public0.167.2 and installed
  0.167.0-alpha.3.2. History retains100/1,000 turns and discards ten3MiB outputs.
  Cargo format and two-job Linux/83-system-library closure pass. Rust source is
  unchanged; no new local Clippy/100-test run is inferred. Hosted verify runs
  its own full Rust gate.
- Frozen packet: `/var/tmp/native-desktop-recovery-u7-24201ac-r1/bundle/`,
  AOT `01f4443b863dcf5ce3a6b3187c96236a417df9498e2926c2be79f846b560988b`,
  Host `73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878`.
  All247 tracked validation/build input hashes match after the shared packet.
  Frozen binary identities also match after real use.
- **Agent real-use:** [recovery evidence](docs/reverse/WORKSPACE_RECOVERY_EVIDENCE.md)
  records23 captures, same-App empty/active crash recovery, retained text and
  mention attachments at wide/700px, explicit replacement and first Send on
  public and installed stock, three controlled model POSTs, and no replay.
  All12 recorded App/Host/stock PIDs are absent; the owned model exits after
  SIGINT and is awaited. These are not Human or live-account acceptance.
- **Hosted exact source:** branch [CI43171510846](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43171510846)
  at24201ac passes verify, macOS and Windows. The newer failure-feedback and
  navigation follow-ups still need their combined final-source gate/CI.
- Earlier settings/provider/Shell evidence remains linked from the functional
  audit and [source7d checkpoint](docs/reverse/SETTINGS_SHELL_PROVIDER_CHECKPOINT.md).
  Old APT timeouts, fixture duplicate IDs, coordinate/clipboard mistakes,
  Xvfb/ATK/model-metadata warnings and failed REDs remain preserved. ASCII-path
  success does not establish a fix for the original Unicode-path LSP failure.

## Current architecture truth

- The stock Codex harness owns intelligence, sessions and tool semantics.
  Desktop uses pure-Dart typed adapters through bundled Rust Host stdio; the
  core client does not require Node/Electron or reimplement the agent loop.
- Conversation state is bounded: paginated history, virtualized lists, bounded
  inactive/live projections and coalesced streaming. Markdown/images are
  bounded; command output and per-file diffs remain lazy. Upstream deferOutput
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
  supported missing/partial workflows, including the coupled recovery follow-ups, Home settings,
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
