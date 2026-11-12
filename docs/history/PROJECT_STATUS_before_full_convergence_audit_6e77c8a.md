<!-- Historical status at6e77c8a before Full Desktop Convergence Audit. Prior VERIFIED labels are scoped evidence, not current convergence certification. -->

# Project Status

**Program mode: `SELF_ITERATION`**
**Current phase: Desktop Completion Gap Audit.**
**Execution: implementation, visual repair and polish paused by explicit user instruction; coverage audit and peer reconciliation complete.**
**Product objective: Codex Desktop Completion — functional parity + high-fidelity UI.**

The user narrowed the current activity to establishing **what is still missing**
before choosing implementation order. This does not lower Desktop quality,
delete prior work, or mark the program complete. Do not resume the old local
polish/test loop or merge pending feature branches during the audit.

## Current truth and memory hierarchy

- Audited delivery baseline: **main/origin/main `0e2a5b80464f7ab6e3f5ab9034e9c37ecf6593ec`**.
  Git is authoritative for the current HEAD; the audit documentation commit will
  be later than this product baseline.
- Exact main [CI43203383623](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43203383623)
  is successful. The prior status's `ba6f27c` main and pending-final-integration
  prose was stale and is superseded here, not evidence that integration failed.
- [Desktop Completion Gap Audit](docs/reverse/DESKTOP_COMPLETION_GAP_AUDIT.md)
  owns the current **cross-layer completion inventory and P0/P1/P2 order**.
  It distinguishes MISSING / PARTIAL / FIDELITY GAP / POLISH / VERIFIED and five
  separate coverage dimensions; no overall completion number is valid.
- [Functional audit](docs/reverse/CODEX_DESKTOP_FUNCTIONAL_AUDIT.md) and
  [feature matrix](docs/reverse/OFFICIAL_FEATURE_MATRIX.md) retain versioned
  capability evidence and history. Their scoped MATCH/IMPLEMENTED labels do not
  close a full product surface or all states.
- [Golden State A](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md),
  [structural mapping](docs/reverse/OFFICIAL_UI_STRUCTURAL_MAPPING.md) and
  [translation plan](docs/reverse/OFFICIAL_UI_TRANSLATION_PLAN.md) retain the
  detailed visual evidence. Current A has machine-actionable partial rows;
  it is not a whole-screen Human-review gate.
- [Architecture](docs/ARCHITECTURE.md) and [Decisions](docs/DECISIONS.md) own
  boundaries/ADRs. Conversation memory is only an index to repository evidence.

## Audit findings and next selector

The replica still lacks complete supported local Desktop workflows. Primary
inventory: in-app account onboarding/re-authentication, saved/workspace Changes
source, interactive terminal, managed local Worktree creation/handoff, and Git
review-to-action controls. Review/PR links/command-output dialogs/cwd metadata
must not be substituted for these complete workflows.

Other material gaps include inline slash/mention menus, Plan/Fast controls, IDE
file-line navigation, PR unlink, background-terminal cleanup and file/image
ingress, plus global message search, file autocomplete, durable
queue management, automatic viewed-turn receipts, Home effective settings,
provider recovery, full Settings/localization/command palette, local environment
and automation surfaces, installed plugin scope and rich result disclosure.
Some advanced/account surfaces require supported-contract research; private
services are not authorized fallback.

Activity/per-item patch access, coherent composer/question/Goal states, open
Changes/Review, Home, compact/dark and menu states remain incomplete. Preserve
proven improvements; do not restart them or reclassify all remaining work as
Human-only. The audit gives row-level evidence and verification needed.

The canonical matrix now contains54 functional workflows,27 surfaces,19 state
units,16 interaction units and20 visual comparison units. Missing pages are
counted explicitly; incomplete rows receive no arbitrary half-fidelity credit.

**Next action:** use the published reconciled audit to select implementation order from its
P0 inventory. The current user asked for the trustworthy gap list before further
implementation, so do not silently start the next feature/polish slice.

## Preserved work and peer ownership

- Codex branch `agent/codex-file-change-item`, HEAD `68e2283`, parent `0d1bf34`:
  Host per-item diff spooling + bounded typed metadata/lazy reader. Committed and
  pushed, **not integrated in main**. Targeted/stock cold-reader evidence belongs
  to that branch, not the delivered product.
- Gemini branch `agent/gemini-golden-ui-u9-o3io`, code `22abb4f`,
  doc-only HEAD `e6667dd`: O3Io per-file
  primitives/evidence and focused gates. Uncommitted `codex_activity_row.dart`
  work is preserved. Binding, integration and packaged same-state closure are
  unfinished; no presentation ownership is taken over during the audit.
- Live peer conversation remains **official agy interactive TUI only**. Both
  peers completed independent audit/challenge, not implementation. Gemini
  endorsed the canonical audit with0P0/0P1 document defects; its original
  doc-only audit commit is `e6667dd`, preserved via `ac6ca4b` in history. No concurrent
  heavy Flutter/Cargo jobs are authorized for this audit. Historical OOM requires
  serialized heavy work when implementation resumes.

## Verification and negative evidence

- Audit publication source `de77288` exact [CI43220947635](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43220947635)
  finished: macOS7m17s and Windows7m12s builds pass; Linux `verify` **fails** at
  `Install Linux build dependencies` after its5-minute timeout. The log shows
  repeated `mirrors.kernel.org` Ubuntu fetch retries; Dart/Flutter verification
  did not start. This does not establish a code/test regression or green final
  gates. No CI configuration change or retry/hardening loop is part of this
  audit. This factual documentation follow-up triggers its own automatic CI;
  its status must be read separately, never inherited from source0e2a or de77288.

- Official installed renderer `26.1103.60933` / build25894 and ASAR hash were
  freshly rechecked; public latest and locally probed stock are0.167.2, installed
  stock0.167.0-alpha.3.2. Existing schema counts are method counts, not coverage.
- Main production-equivalent source5dd4758 has retained format/strict analysis,
  pure69, **724 default Flutter cases/five explicit stock skips**, enabled direct
  stock cases on both binaries, bounded history100/1,000 + ten3MiB outputs,
  two-job Linux/83-library closure and exact-main CI evidence. These are not
  724 full-stack E2E or fidelity passes; audit does not rerun heavy gates for docs.
- Fresh audit-only packaged runtime uses real bundled Host/public stock and a
  credential-free isolated profile. Home and actual plugin catalog were inspected
  at1191/820/700px; compact still says `Automations & Skills` without Automation
  management. Twelve captures and clean owned-process exit are recorded in the
  audit. Synthetic menu clicks were inconclusive, not reported as product bugs.
- The earlier synthetic Home Return that did not submit, actual-scroll fixture
  failure before its fix, recovery/graphics/portal negatives, and Unicode-path
  analyze LSP framing failure remain preserved in per-workflow evidence. ASCII
  analysis is not proof that the Unicode-path failure is fixed.
- Controlled Host fixture proves large item/aggregate diff can exceed the8MiB
  forward cap and exit the Host. Branch spooling fixes the item subset but not
  aggregate `turn/diff/updated`. It is **not actual stock large-aggregate emission**;
  this remains an explicit high-impact boundary risk, not solved lazy diff parity.

## Architecture and scope retained

Stock Codex owns the harness. Pure-Dart typed adapters/Host isolation, bounded
history and inactive projections, coalescing, lazy output/diff/Markdown and no
core Node/Electron requirement remain unchanged. Known upstream `deferOutput`
and whole-item fallback limits remain explicit. Loaded settings come from stock
acknowledgement, never model-catalog inference. Direct Host Remote remains
readOnlyCodex; no new Remote/Android, Chat/Work/Responses, UI-package or unrelated
release/infrastructure expansion is part of the current Desktop audit.

**NOT YET HUMAN VERIFIED:** matched signed-in official states, subjective
interaction/long-session acceptance and physical platform/AT checks. They are
surface-scoped, not substitutes for remaining machine-actionable reconstruction.

## History

The prior current-state text is retained as a clearly historical
[pre-audit snapshot](docs/history/PROJECT_STATUS_before_completion_gap_audit_0e2a5b8.md).
Earlier [24201ac](docs/history/PROJECT_STATUS_at_24201ac.md),
[7d0282d](docs/history/PROJECT_STATUS_at_7d0282d.md) and
[UI checkpoints](docs/history/DESKTOP_UI_CHECKPOINTS_through_9a75ddc.md), Git and
linked evidence retain provenance. No previous source/test result is erased.
