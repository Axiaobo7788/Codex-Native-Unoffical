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

- Codex and Gemini remain equal peers. Live coordination uses the official
  `agy` TUI, separate worktrees and one writer per overlapping surface.
- **Track F / Codex:** `agent/codex-desktop-mcp-oauth`,
  `/var/tmp/native-codex-desktop-mcp-oauth`, published source `0cdf0e8`.
  Global stock-owned MCP authentication and U2 are integrated on this branch.
  Actual PKCE, completion/readback, navigation/resize, config reload and stock
  credential persistence after full process restart have been exercised.
  [Detailed evidence](docs/reverse/MCP_OAUTH_ACCESS_EVIDENCE.md).
- A final audit found Native's forced 180-second login timeout differs from the
  official name-only request and public stock's 300-second default. The correction
  preserves omission of optional `timeoutSecs` and uses a five-minute-plus-grace
  client watchdog. Old-source red tests reproduce the mismatch. Corrected format, strict analysis,
  68-root pure-Dart compilation, 43 focused cases and name-only installed/public
  OAuth smoke pass. Fresh combined release/shared gates remain pending; prior
  `0cdf0e8` captures do not prove the new source.
- **Track U3 / Gemini:** branch
  `agent/gemini-golden-ui-u3-a7-reasoning-markdown`, worktree
  `/var/tmp/native-gemini-u3-a7-reasoning-markdown`, source `22bf94e` based on
  `0ecb27d`. It translates remaining A7 reasoning Markdown and the observed live
  elapsed header. The peer has released the six presentation/test surfaces for
  review and integration: `conversation.dart`, `official_codex_theme.dart`,
  `assistant_markdown.dart`, `desktop_markdown_body.dart`,
  `activity_parity_test.dart`, and `assistant_markdown_test.dart`. Codex reviewed the actual diff and light/dark captures. The live reasoning
  240-character flattening defect remains a separately owned systems correction;
  U3 source verification/integration is pending.
- Heavy validation is **Codex-owned** after Gemini's explicit U3 release and
  owned runtime teardown. Gemini is light-only until the next lease handoff. Flutter tests use `--concurrency=1`, Cargo uses two jobs, and
  Linux release uses `--config-only` then CMake `--parallel 2`. The earlier OOM
  was compiler/test overlap; no Native heap-leak correction is claimed.
- The next independently confirmed Track F gap is explicit local runtime
  startup retry/crash recovery. Recovering must retire stale generations,
  preserve thread/draft identity, and never implicitly run queued work.

## Current checkpoints

- **Published branch source `0cdf0e88acc4764ff9f520b1cc10a4720c9895d2`:**
  normal merge `0ecb27d` preserves MCP `beac41f` and Gemini U2 `d725eba`;
  `0cdf0e8` corrects two reproduced peer findings and modal focus ownership.
  [Exact branch CI 43101623112](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43101623112)
  passed Linux, Windows and macOS. Main has not integrated this branch yet.
- **Last hosted-verified main `deb70761f3ebbe32de878b3cd7bc0ff5da400a5c`:**
  [43092114873](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43092114873)
  passed all three platforms. It includes catalog truth and U1 typography,
  preserving the cold-resume failure correction `a0d2a05`.
- Older A6/A7/Customize/question/Goal narratives and prior CI counts remain in
  [checkpoint history](docs/history/DESKTOP_UI_CHECKPOINTS_through_9a75ddc.md).
  [Golden State A](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md) remains the visual
  contract. A6/A7 and the overall primary screen remain `PARTIAL`; a local
  checkpoint does not establish Human acceptance or Desktop completion.

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

- Source `0cdf0e8`: all 376 tracked files were hashed before and after the
  shared run. Format 203 files/0 changes, strict analysis, 68-root pure-Dart
  boundary, 603 default Flutter cases (five opt-in skips), five separately
  enabled real-stock cases, history 100/1,000 plus ten 3 MiB outputs, Rust
  fmt/Clippy/100 tests, two-job Linux release/83-library closure, existing MCP
  smoke and new installed/public OAuth smoke pass. Default unit/widget/typed
  simulated-runtime counts are not full-process E2E. The Unicode-path LSP issue
  is not claimed fixed by the ASCII worktree validation.
- Frozen source-bound bundle and replay evidence:
  `/var/tmp/native-desktop-mcp-u2-0cdf0e8-r1/`, AOT `b99abbd6…`, unchanged
  Host `73218b92…`. Installed `0.167.0-alpha.3.2` and public `0.167.1` used
  real App → Host → stock with only local OAuth/MCP and URI-handler fixtures.
  Installed success survives Home/Customize navigation, compact close/reopen,
  resize while modal is open, same-handoff retry and visible readback. Public
  success survives Reload config and full App/Host/stock exit/relaunch with the
  same private profile. Both have one authorization/PKCE exchange, zero threads
  and no observed overflow/Unhandled failure. This does not implement in-app
  runtime crash recovery or prove real external-browser/account acceptance.
- The initial installed URI-handler setup was unsuccessful: launch API accepted
  the URI, no callback occurred and stock later reported failure. Its negative
  captures/counters remain. Actual successful replay used a task-owned GIO
  `.desktop` URI handler, not the minimal portal (OpenURI count was zero).
  Peer red tests, intermediate animation timeout and modal focus failure remain
  preserved under `/var/tmp/native-ui-r0.BbOvHT/`.
- U2 `d725eba` captures were independently inspected; its typed activity groups
  and captions are in `0cdf0e8`. U3 `22bf94e` and the new timeout correction
  require fresh combined source-bound validation. The timeout correction passes
  targeted checks and real stock; heavy resource ownership is currently Codex's.
- **NOT YET HUMAN VERIFIED:** matched signed-in official live captures,
  subjective interaction/visual acceptance and unavailable physical-platform
  checks remain surface-scoped. Known machine-actionable Golden-State rows
  continue; there is no whole-primary-UI Human stop gate.
- Physical Android TLS/Keystore/camera/cross-network checks remain deferred
  outside the current Desktop target. Account security-notice routing still
  needs a verified public identity contract. See the [living queue](docs/reverse/OFFICIAL_FEATURE_MATRIX.md#36-active-queue-after-consolidation).
