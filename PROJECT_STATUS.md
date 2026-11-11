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

- Codex and Gemini remain equal peers. Live coordination is official `agy` TUI
  only, with separate worktrees and one writer per overlapping file surface.
- **Track F / Codex:** source `45c80d8` closes the explicit catalog-omission
  signal and malformed-detail correction, preserving `6c278c5`. The first
  cold-resume correction preserves `aba5feb` through `a0d2a05`. Both have
  independent real-stock evidence. The next active functional slice is supported
  stock-owned MCP OAuth access; local installed/public probes pass, Native UI
  start/completion wiring remains missing. [Fresh audit](docs/reverse/CODEX_DESKTOP_FUNCTIONAL_AUDIT.md).
- **Track U2 / Gemini:** `/var/tmp/native-gemini-u2-a7-activity`, branch
  `agent/gemini-golden-ui-u2-a7-activity`, base `9a75ddc`. The six negotiated
  writable surfaces are `conversation.dart`, `diff_approval_output.dart`,
  `codex_activity_row.dart`, `test/features/conversation/activity_parity_test.dart`,
  `test/app/codex_primitives_test.dart` and
  `test/simulated_runtime/saved_turn_details_test.dart`. The goal is refreshed
  build-25894 typed captions and supported live/expanded activity grouping;
  bounded retention/output, raw Execution/search and controllers remain intact.
  Codex owns ecosystem/protocol/runtime surfaces and shared checkpoint docs.
- Heavy validation is **Gemini-owned** after Codex's completed combined replay;
  Codex remains source/docs-only until an explicit slot handoff. Flutter tests
  use `--concurrency=1`, Cargo uses two jobs, and Linux release uses
  `--config-only` then `cmake --build … --target install --parallel 2` (actual
  Ninja `-j 2`). This recovers from host compiler/test overlap, not a proven
  Native heap-leak fix. No user application or shell configuration was changed.

## Current checkpoints

- **Combined application source `9a75ddc`** integrates `45c80d8` catalog truth,
  main `993a700`, and Gemini `dc96f3e` + `b247e07` initialized 14px chat / 12px
  code / foreground and bounded Markdown-context corrections. It preserves all
  original peer commits. Local shared gates and independent Linux replay pass;
  exact hosted CI for the next main publication is still pending.
- **Last hosted-verified main `993a7001ff47d7a99a2769c1cf8e4864749076e5`:**
  [43081894366](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43081894366)
  passed Linux, Windows and macOS. Source `a0d2a05` verifies visible cold-resume
  failures, preserved draft/file, dismissal and exactly one successful retry.
- Older A6/A7/Customize/question/Goal narratives and earlier CI counts remain in
  [checkpoint history](docs/history/DESKTOP_UI_CHECKPOINTS_through_9a75ddc.md).
  Current visual status and measured deltas remain authoritative in
  [Golden State A](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md); A6/A7 and the
  overall primary screen remain `PARTIAL`.

## Current product and architecture

- Desktop uses the bundled Rust `codex-native-host` and stock `codex app-server`. The local workflow includes thread management, turn streaming and steering, approvals, model and execution controls, bounded diff/output, stock review, and supported Skills/Plugins/Apps/MCP administration. Availability can depend on installed stock version, configuration and account.
- The wide native desktop shell has a 52 logical px navigation rail and a 288 px contextual sidebar by default. The 340 px total left area is resizable, and the reading and composer column is capped at 672 px. Plugins opens an inline Customize destination on wide Desktop. Below 760 px Native uses compact Threads navigation and retains the ecosystem dialog. `OfficialCodexTheme` owns the geometry and colors, and the responsive shell keeps one active conversation state.
- Codex is the only wired product. Prose, Commands and Execution are timeline detail choices. The internal Work and Chat capability profiles and backend interfaces are compatibility seams. Independent ChatGPT Chat, Work orchestration and Responses backends are absent.
- App-server owns persisted conversation state. Flutter retains bounded thread/history/active-turn projections, virtualizes lists, coalesces streaming, evicts inactive history, and lazily loads bounded output and diffs. Host spooling keeps large command payloads off the Flutter heap and preserves opaque MCP result fields with the same key name. Installed stock and public stable `0.167.0` returned the sampled command output inline. Public alpha `0.169.0-alpha.7` deferred eligible commands through the existing Native fetch path. Experimental `thread/items/read` returns the stored item.
- Saved turns expose a detail disclosure in Commands and Execution even when a work duration cannot be shown. Opening it loads one bounded turn item page. A failed first read leaves the summary in place and can be retried.
- The global sidebar groups and filters loaded threads. Local Section browsing and explicit saved-thread search reuse its 100-thread working-set cap. Section definitions remain capped at 64. Switching scopes preserves the active conversation outside the list. Sidebar, Section rows, and saved-thread search currently use the configured stock provider. Cross-provider visibility and cold resume are separate research questions.
- Saved local threads can show an unread marker from stock. The sidebar Mark as read and Mark as unread actions use the displayed revision. A conflict refreshes the receipt and requires a fresh user action.
- Local composer Send checks queue presence before implicitly resuming a cold thread. Pending or inconclusive results offer a separate Resume and retain the draft. Identified local user items appear in the live timeline. Stock IDs drive deduplication, and a local start or steer keeps its existing visual row when echoed.
- Interactive request submission keeps one typed operation token. Late completion cannot clear another submission or remove a reused ID after authoritative resolution. Typed resolution retires an active write even after projection eviction. The supported adapter suppresses duplicate pending IDs and shares the 32-request budget. Projection eviction preserves serialization.
- Conversation Find filters loaded messages. A separate action searches saved messages on eligible local stock threads, one 16-hit page at a time. Opening a hit verifies a bounded turn window before replacing the current one. Legacy threads retain loaded-message Find.
- Stock Pinned is protected by its reserved ID. Eligible unsectioned pins use stock membership after a fresh read. Custom-section threads and runtimes without that built-in retain explicitly labeled session pins.
- Local Goal actions load the selected thread’s persisted goal on demand and support explicit paused creation, objective changes, pause/resume, and confirmed clear. Stock owns continuation. Desktop Review offers working-tree, base-branch, commit/ref, and custom targets through stock `review/start`. Both Review entry points apply the cold queue admission rule.
- Local Runtime details displays a bounded read-only provider list when stock supports it. The list keeps display names, provider kinds and the default marker. Older versions show an availability message.
- Local MCP resource/tool inputs use dialogs; server elicitation stays with the initiating ecosystem operation, on the wide Customize surface or inside the compact dialog. Direct actions on a cold thread require explicit resume. A global resource read remains available without a selected thread. Eligible saved MCP activity in Commands and Execution offers a one-item local read with a 32 KiB text preview.
- The local conversation header reads stored GitHub and GitLab review references for the selected thread with one in-flight scan and one replaceable pending target. The user can open a link or explicitly add one to a saved thread. Add checks existing canonical and legacy links before writing. Removing references, managed worktrees, and cloud attachments remain separate surfaces.
- Skills, Plugins, Apps and MCP can load independently. Plugin refresh keeps the cached catalog on RPC failure and serializes catalog mutations through readback. Successful partial catalogs retain usable rows. Partial, paginated or 100-capped inventories qualify loaded counts and empty/search wording. Failed source paths and raw parser messages are omitted from the typed snapshot; retained catalogs remain bounded.
- Direct Host Remote is read-only. The transport allows bounded model/thread metadata and history reads and sequenced lifecycle projection. Android currently presents pairing, connection recovery and model/thread metadata. Thread/turn writes, approvals, diffs, and command-output reads remain outside the Remote contract. Official Remote support is experimental host-side control through stock schema. There is no Native mobile client for the official relay.

## Verification and pending gates

- Source `9a75ddc`: all 365 tracked source files byte-matched in the auxiliary
  ASCII tree. Format (0 changes), strict analysis and 65-root pure-Dart boundary
  pass; 577 default Flutter cases (five opt-in skips), five separately enabled
  real-stock cases, history 100/1,000 plus ten 3 MiB outputs, Rust fmt/Clippy/100
  tests, two-job Linux release/83-library closure and MCP smoke pass. Unit,
  widget and simulated-runtime cases are not full-process E2E. The original
  Unicode-path LSP framing issue is not claimed fixed.
- Frozen combined AOT `a6dfb1cd…` at
  `/var/tmp/native-desktop-f-u-9a75ddc-r1/`: real App → bundled Host → public
  stock `0.167.1` rendered mixed Markdown at 1191×865 / 820×865, copied all 40
  code bytes, completed a normal turn, switched threads and returned, and made
  zero live image-sentinel requests. Only model responses used a loopback
  fixture; no real-account/inference or token-stream-granularity claim is made.
- `/var/tmp/native-plugin-catalog-real-stock-r1/`: four actual typed stock cases
  cover installed/public saturated and exact catalogs, including coexisting
  source errors. Packaged Linux verifies wide/compact disclosure, exact-100
  omission of the truncation notice, independent source-error warning and valid
  detail inspection. The cap/query and conservative loaded-only wording remain.
  Scoped installed inventory and full-catalog access are separate open work.
- App/Host/stock/private Xvfb/model workers exited. Negative fixture, clipboard,
  rendering and driver evidence is retained in the audit/artifacts/history.
  Current checks found no overflow/Unhandled failure; private-Xvfb accessibility
  / graphics and stock fixture model-metadata warnings remain.
- **NOT YET HUMAN VERIFIED:** matched signed-in official live captures,
  subjective interaction/visual acceptance and unavailable physical-platform
  checks remain surface-scoped. Known machine-actionable Golden-State rows
  continue; there is no whole-primary-UI Human stop gate.
- Physical Android TLS/Keystore/camera/cross-network checks remain deferred
  outside the current Desktop target. Account security-notice routing still
  needs a verified public identity contract. See the [living queue](docs/reverse/OFFICIAL_FEATURE_MATRIX.md#36-active-queue-after-consolidation).
