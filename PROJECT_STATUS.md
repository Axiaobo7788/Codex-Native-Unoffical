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

- Current shared implementation checkpoint is `7d0282d131ceda57aa2dfa66c9f6cffc2f007b1a`,
  normally integrated and pushed. It preserves Codex settings `9fc19d3` /
  evidence `5c46c44`, saved-title scope `cafcf12`, and Gemini U6 `df46ace` /
  `e9a9697` / `7301289` through a normal merge. Main working tree is clean.
- Codex owns Track F. Loaded inherited settings and saved-title discovery are
  integrated. The isolated workspace-recovery slice now retains one mounted
  editor/draft/attachment state, retires session-local operations and Host
  references, and admits explicit local reconnection without automatic resume
  or write replay. Peer-found stale relay notifications, root popovers and lost
  session-only IDs have regression cases and corrections. Latest 108 targeted
  cases and the 18-case lifecycle/Retry follow-up pass. A 30-case retirement/
  memory follow-up also passes after replacing the old strong-reference snapshot
  with scalar session tags; these counts overlap. Current shared gates,
  new-source packaged session-draft replacement and integration remain pending.
- The earlier isolated Linux packet verifies real owned stock/Host termination,
  same-App recovery, bounded saved history, retained draft/attachment, active
  unconfirmed outcomes and no extra model call. It also **reproduces** the old
  session-only ID failure. That packet is not evidence that the later fix has
  passed real use. See [recovery evidence](docs/reverse/WORKSPACE_RECOVERY_EVIDENCE.md).
- Gemini U7 A6 actual-height clipping/selection is frozen at `44a8809`; its
  independent peer audit is durable at `3c18450`. Neither is integrated yet.
  The peers refreshed the official agy session after the long audit. Gemini
  continues read-only current25894 evidence/targeted review; conversation
  lifecycle surfaces were explicitly released to Codex.
- Codex currently owns the exclusive heavy lease. All earlier owned App/Host/
  stock/model workers exited. Flutter uses one worker and Cargo/CMake two jobs;
  no overlapping heavy workloads. Gemini has zero heavy/runtime workers.
- Live coordination remains official agy TUI-only. Peers are equal; one writer
  per overlapping surface. Codex will negotiate any runtime-generation bridge
  inside Gemini's conversation presentation instead of writing over it.

## Current verification checkpoint

- **Source `7d0282d` machine gates:** format 208/zero changes, strict analysis 0,
  pure-Dart 68, 660 default Flutter cases/five explicit stock skips. Five enabled
  direct-stock cases pass separately on public `0.167.2` and installed alpha.
  History retains 100/1,000 turns and discards ten 3 MiB command payloads.
  Cargo format and two-job Linux/83-system-library bundle closure pass. Rust
  source is unchanged; local Clippy/100-test history is not relabeled as a new
  local run. Hosted CI runs its own complete Rust gate.
- Frozen shared packet:
  `/var/tmp/native-desktop-settings-u6-7d0282d-r1/bundle/`,
  AOT `393b320fc16111e22f507202d0052110cd3b1b651af6a286e2aa61b44e7af554`,
  Host `73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878`.
  Its recorded binary identities remain unchanged after the owned replay.
- **Agent real-use:** [settings evidence](docs/reverse/INHERITED_SETTINGS_EVIDENCE.md)
  verifies acknowledged loaded settings and neutral cold values.
  [Combined evidence](docs/reverse/SETTINGS_SHELL_PROVIDER_CHECKPOINT.md) records
  real old/new provider search, packaged all-provider title discovery, readable
  foreign history, truthful mismatch/draft preservation and zero model calls.
  U6's public light/dark and installed-light stock runs show actual Shell
  success/exit-code2 cards; Codex inspected source, captures and process exit.
  All owned App/Host/stock/model workers exited. These are not Human acceptance.
- **Hosted exact-source gates:** `5c46c44` CI43156192343 passes all three jobs.
  Source9fc's earlier run was cancelled by normal branch concurrency when its
  documentation follow-up was pushed; it is not called green. For `7d0282d`,
  branch CI43157353142 first passes macOS/Windows but verify times out during
  dependency installation before code checks. Only failed job130980357409 was
  rerun. Exact main [CI43158612189](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43158612189) now passes verify, macOS and Windows.
  Branch attempt two also passes at the same SHA. The first timeout is
  preserved; no CI policy/workflow change was made.
- Private seeded duplicate assistant IDs, early captures, coordinate mistakes
  and Xvfb/ATK/model-metadata warnings remain in source-bound evidence. Corrected
  fixture passes do not erase them. ASCII worktree analysis does not establish
  a fix for the original Unicode-path Flutter/LSP framing failure.

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
  supported missing/partial workflows, including hot recovery, Home settings,
  account lifecycle, global content search and queue/terminal management.
- [Golden State A](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md) remains PARTIAL.
  U6 Shell cards and acknowledged controls do not close saved-activity hierarchy,
  every popover/state, Home, Changes, Review, compact or dark comparisons. U7
  rendered-height clipping is active, not delegated to a generic Human gate.
- **NOT YET HUMAN VERIFIED:** matched signed-in official visual comparison,
  subjective interaction/long-session acceptance and unavailable physical
  platform checks remain surface-scoped. Physical Android checks are deferred
  outside this Desktop phase. No whole-program Human stop is justified.
- Global stop predicate is false. Continue the independent F/U ownership pair
  after every integration/checkpoint. Do not expand into another product phase.

## Durable history

Git is canonical for actual HEAD/worktrees. Earlier status/checkpoint narratives
are preserved in [the 7d snapshot](docs/history/PROJECT_STATUS_at_7d0282d.md),
[Desktop UI history](docs/history/DESKTOP_UI_CHECKPOINTS_through_9a75ddc.md)
and the source-bound evidence linked from the functional audit. ADRs remain in
[Decisions](docs/DECISIONS.md); old test counts are historical evidence, not
current verification claims.
