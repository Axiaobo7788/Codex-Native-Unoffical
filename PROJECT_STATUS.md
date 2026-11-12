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

- Program remains `SELF_ITERATION`; both Desktop tracks have machine-actionable
  work. Codex and Gemini remain equal peers using the official `agy` TUI and
  isolated worktrees with one writer per surface.
- **Combined source checkpoint `c3957c9`:** normal merge preserves startup
  `e8ece87` / `c8f5570` and U5 `3e8d381` / `76e3428`. Format/analysis,
  pure-Dart68, 637 default cases/five skips, five stock cases each on public
  `0.167.2` and installed alpha, memory, Linux83 and source245 pass.
  [Startup evidence](docs/reverse/STARTUP_RETRY_EVIDENCE.md) records old/new
  actual packaged recovery on the same App PID, both first turns saved, and
  public history after full process restart with no extra model call.
  All owned workers exited. Driver timeouts/early captures and fixture warnings
  remain preserved. Connected-workspace hot recovery stays `MISSING`.
- **Track F / Codex source9fc19d3:** bounded acknowledged loaded-thread
  model/provider/effort/policy projection, 100-entry cache, unload/eviction/order/
  generation fences, and existing model/execution-control access. Writable
  overrides remain separate. Full652/five skips, pure68/strict analysis, final
  protocol/settings/memory41, both real-stock probes and Linux83 pass.
  [Packaged evidence](docs/reverse/INHERITED_SETTINGS_EVIDENCE.md) verifies
  public cold unknown→explicit Send High/read-only, Advanced inherited values,
  new chat Medium, compact and warm switches, and restart/saved replay. A seeded
  duplicate-ID fixture negative and corrected unique-ID run are retained. Both
  owned App/Host/stock trees and model fixtures exited. Home/current-cwd preview
  remains PARTIAL. Branch is pushed; coherent UI integration/CI remains pending.
- **Track U / Gemini sourcedf46ace + e9a9697:** U6 A7/C Shell card and row
  disclosure, followed by nullable bounded public exitCode projection and
  calibrated unknown/footer status. Gemini owns the isolated U6 worktree and
  has the exclusive heavy lease after Codex completed its packet. Targeted
  validation and real-stock/capture handoff are pending. Codex released only
  independent command DTO/adapters/controller surfaces for the correction;
  the viewer descriptor bridges exitCode without concurrent conversation writes.
  U7 A6 rendered-height clipping remains the next evidenced UI candidate.
- **Hosted checkpoint:** exact-source CI43140754985 macOS/Windows builds pass.
  First verify failed before tests at dependency installation's five-minute
  timeout. Only that job was rerun; attempt two passes verify, macOS and Windows
  at the exact source SHA. The original failure remains preserved; no workflow
  change was introduced. Safe main integration and its exact-HEAD CI follow.
- **Heavy lease:** Codex explicitly returned it to Gemini after shared gates
  and all packaged workers exited. Codex stays source/docs-only while Gemini
  validates U6. Flutter tests use one worker, Cargo and CMake two jobs. Do not
  start another heavy workload without peer coordination.

## Current checkpoints

Git is canonical for the current HEAD and working tree. These are immutable
source/validation checkpoints, rather than a second branch-state database.

- **Prior main `9e0c8a6` integration checkpoint:**
  [CI43131012688](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43131012688)
  passed verify/Windows/macOS at the exact SHA. It preserves combined release
  source `b22e955` and the source-bound evidence documentation; startup retry
  and U5 are subsequent work, not part of that verified checkpoint.

- **Prior main checkpoint `27db663b8a4d29b658401d7c03abf6b4f37d09ec`:**
  [main CI43119069301](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43119069301)
  and [branch CI43116961616](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43116961616)
  both passed all three platforms at the exact SHA. It contains reasoning
  source `0286a4d`, MCP authentication/timeouts, U2/U3, and all earlier catalog,
  typography and cold-resume corrections. New-thread admission and U4 are not
  integrated into that checkpoint.
- **Current combined release source `b22e955`:**
  [exact-source CI43128650668](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43128650668)
  passes all three jobs; 626 default/five stock cases, pure-Dart/analysis/memory,
  Linux 83-library closure and source-bound public/installed walks pass. AOT
  `6168b2d8…`, 244 selected tracked inputs unchanged. [Evidence](docs/reverse/NEW_THREAD_HISTORY_EVIDENCE.md)
  records failures and scope. Git remains canonical for current integration.
- **Published new-thread source `732d2a4`:**
  [CI43122125258](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43122125258)
  completed successfully at the exact SHA. This is not the combined U4 source or
  the pending local packaged-stock walkthrough.
- **Previous combined source `03b23c4` / main `abd0e41`:** shared 607-case
  checkpoint and actual global MCP login/reload pass; exact main
  [43113451050](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43113451050)
  passed all platforms. Detailed source-bound results remain in
  [MCP evidence](docs/reverse/MCP_OAUTH_ACCESS_EVIDENCE.md).
- Older A6/A7/Customize/question/Goal narratives remain in
  [history](docs/history/DESKTOP_UI_CHECKPOINTS_through_9a75ddc.md).
  [Golden State A](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md) remains the visual
  contract. A6/A7 and the overall primary screen remain PARTIAL. A green source
  checkpoint is not Human acceptance or Desktop completion.

## Current public-stock refresh

Public stable is now `0.167.2`; its official asset digest matches and isolated
schema exports are canonically identical to `0.167.1` (322 stable/470
experimental files). Counts are unchanged. This is static protocol evidence;
new packaged runtime walks are pending. Keep the existing `0.167.1` actual-use
records version-scoped. The installed Desktop ASAR remains build25894/hash121edc7b….
See the [functional audit](docs/reverse/CODEX_DESKTOP_FUNCTIONAL_AUDIT.md#public-stable-refresh--01672).

## Current product and architecture

- Desktop uses the bundled Rust `codex-native-host` and stock `codex app-server`. The local workflow includes thread management, turn streaming and steering, approvals, model and execution controls, bounded diff/output, stock review, and supported Skills/Plugins/Apps/MCP administration. Availability can depend on installed stock version, configuration and account.
- Local startup/crash recovery is a newly reopened functional gap: the start
  Future is cached and the disconnected page has no retry/restart action.
  Previous stop/restart MATCH wording was corrected. The dedicated real-process
  failure/recovery replay is pending; recovery must preserve thread/draft
  identity and retire old runtime-generation projections without running queued
  work implicitly.
- The wide native desktop shell has a 52 logical px navigation rail and a 288 px contextual sidebar by default. The 340 px total left area is resizable, and the reading and composer column is capped at 672 px. Plugins opens an inline Customize destination on wide Desktop. Below 760 px Native uses compact Threads navigation and retains the ecosystem dialog. `OfficialCodexTheme` owns the geometry and colors, and the responsive shell keeps one active conversation state.
- Codex is the only wired product. Prose, Commands and Execution are timeline detail choices. The internal Work and Chat capability profiles and backend interfaces are compatibility seams. Independent ChatGPT Chat, Work orchestration and Responses backends are absent.
- App-server owns persisted conversation state. Flutter retains bounded thread/history/active-turn projections, virtualizes lists, coalesces streaming, evicts inactive history, and lazily loads bounded output and diffs. Host spooling keeps large command payloads off the Flutter heap and preserves opaque MCP result fields with the same key name. Installed stock and sampled public `0.167.0` returned the sampled command output inline. Public alpha `0.169.0-alpha.7` deferred eligible commands through the existing Native fetch path. Experimental `thread/items/read` returns the stored item.
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

- Current reasoning systems source: format 204 files/zero changes, strict
  analysis, 68-root pure-Dart boundary, 615 default Flutter cases/five skips,
  five enabled installed-stock cases and history memory benchmark pass.
  The first release invocation omitted the Cargo job environment and was
  intentionally terminated with its owned process tree (exit 143). The rerun
  explicitly used `CARGO_BUILD_JOBS=2` and CMake `--parallel 2` and passed
  release/83-library closure. All 218 tracked application/test/tool/Linux/build
  input hashes matched before/after. Rust source is unchanged; prior 100-test
  evidence remains distinct. Real packaged reasoning replay now passes with
  independently seeded profiles: baseline `03b23c4` versus `0286a4d`, AOT
  `9f9c6d2a…`, same U3 UI. Full multiline/list/sentinel content is visible; ten
  fixture model calls, zero image GETs, zero observed overflow/Unhandled. All
  owned workers exited. This does not close Human or first-part UI gates.
- Prior source `03b23c4`: format 203 files/zero changes, strict analysis, 68-root
  pure-Dart boundary, 607 default Flutter cases/five opt-in skips, five enabled
  real-stock cases, history 100/1,000 plus ten 3 MiB outputs, two-job Linux
  release/83-library closure, existing MCP and installed/public name-only OAuth
  smoke pass. Rust is unchanged from `0cdf0e8`, whose fmt/Clippy/100 tests pass.
  All 376 tracked files matched before/after gates. These counts mix unit,
  widget and simulated integration; they are not full-process E2E. ASCII-path
  validation does not establish a fix for the original Unicode-path LSP issue.
- Frozen source-bound bundle: `/var/tmp/native-desktop-mcp-u3-03b23c4-r1/`,
  AOT `85539d98…`, Host `73218b92…`. Fresh real App → Host → public stock
  `0.167.1` authentication and Reload config pass, with one local authorization/
  PKCE exchange and 18 authenticated MCP calls. One unmaterialized empty thread
  was inadvertently created during compact navigation; persisted thread count
  stays zero, and its actual history failure is preserved for correction.
- Prior `0cdf0e8` bundle/replay at
  `/var/tmp/native-desktop-mcp-u2-0cdf0e8-r1/` verifies installed/public login,
  navigation/resize, compact close/reopen, same-handoff retry and credential
  persistence after full process restart. Initial invalid URI-handler setup,
  peer red tests, intermediate animation timeout and modal focus failure remain
  preserved. Successful callback uses a controlled GIO `.desktop` URI handler;
  portal OpenURI counters were zero. External browser/account acceptance and
  in-app runtime crash recovery are not established by these checks.
- U3 actual light/dark captures have been independently inspected, including the
  live 240-character flattening corrected by source `0286a4d`. Owned
  App/Host/stock/Xvfb/provider/portal/DBus workers exited after packaged replay.
  Private driver/accessibility and fixture metadata warnings remain recorded.
- **NOT YET HUMAN VERIFIED:** matched signed-in official live captures,
  subjective interaction/visual acceptance and unavailable physical-platform
  checks remain surface-scoped. Known machine-actionable Golden-State rows
  continue; there is no whole-primary-UI Human stop gate.
- Physical Android TLS/Keystore/camera/cross-network checks remain deferred
  outside the current Desktop target. Account security-notice routing still
  needs a verified public identity contract. See the [living queue](docs/reverse/OFFICIAL_FEATURE_MATRIX.md#36-active-queue-after-consolidation).
