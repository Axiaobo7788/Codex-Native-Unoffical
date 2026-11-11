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

- Latest integrated UI checkpoint `11e2d3ab` preserves Gemini's A6
  user-message/attachment translation and Codex's independent systems/runtime
  validation. That work remains valid and Track U continues from it.
- Under Codex Desktop Completion, Gemini remains the default presentation owner
  for Track U coherent Golden-State slices. Codex remains the default systems /
  protocol / functional-parity owner for Track F and adversarial reviewer of UI
  changes. They are equal peers; ownership follows the current slice.
- The immediate next Codex-owned action is a **fresh Codex Desktop functional
  parity audit**, not merely consuming the old READY list. The immediate
  Gemini-owned action is the highest-impact evidenced remaining Golden-State UI
  row/cluster.
- Live coordination continues only through the official `agy` TUI. Use separate
  worktrees and avoid overlapping writes. Heavy Flutter/Cargo validation remains
  serialized after the recorded host OOM.
- Integration checkpoints must update both the functional matrix and UI
  Golden-State evidence. Closing either one track alone is not permission to end
  the program.

## Current checkpoints

- A6 source `77d3401` translates actual-parent `70%` user-bubble width,
  borderless `22 px` corners, `16×10 px` padding, initialized `14 px` text,
  `20`-line disclosure with a `10 px` combined button gap, externalized attachment
  pills and attachment-only messages. Independent packaged replay measures
  `447`/`313` fill pixels at `1191`/`820` viewport width (logical `448`/`313.6`),
  with full Copy exact in collapsed and expanded states. User-message Markdown,
  clipped-selection semantics and attachment thumbnails remain explicit deltas.
  The global body `13.5→14 px` initialized-default gap remains machine-actionable,
  separately from H1 personal appearance. See the [current A6 contract](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md#a6-user-bubble-and-externalized-attachments).
- `ff931b9` + `7012dd3` translate quiet inline activity and Thought disclosures,
  grouped 4 px spacing, the 140 px reasoning viewport and completed-turn
  divider rhythm. The saved group keeps its 224 px lazy list and existing
  output controller; unknown/capped projections retain details. Search and
  Execution expose raw reasoning when needed. Review reproduced duplicate
  screen-reader labels and an Execution collapse regression, both corrected
  by the owner with preserved negative evidence. Independent gates and the
  same-history packaged replay passed; the initial strict-format failure and
  recovered private-Xvfb graphics warnings remain recorded. See the
  [A7 evidence](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md) for source, captures,
  limits and remaining machine-actionable caption/live-group gaps.
- A6 sources through `40e8aaf` translate measured inline-code geometry,
  container-relative type and light/dark fills with at most 128 rich pills per
  message. Over-budget and internally wrapping tokens use styled, linked flat
  spans. One scalar width interval reuses blocks across resizes that change no
  fit decision. Source/history limits, streaming bypass, single-pass lazy
  Markdown, safe links and blocked images remain intact. Independent JIT dense
  reflow returned from about 3 seconds to 43–49 ms. Peer packaged replay `r3`
  verified the exact 271-character clipboard, all four link variants and zero
  image-sentinel requests after exit. Independent final-release checks passed:
  dense narrow resize measured 330.7 ms / two sampled frames (baseline
  294–334 ms / two; rejected `e836769` 1,007–1,038 ms / six). These timings
  include screenshot sampling, and saved history is still capped at 8 KiB
  plus ellipsis. The separate dense JIT specimen contains 16,384 characters.
  The density, copy-order, resize and helper-calibration negatives are
  preserved in the [current A6 evidence](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md)
  and ADR-058. Golden State A remains `PARTIAL`; cloned per-line code rounding,
  matched signed-in fonts, attachments and user bubbles retain separate gaps.
- `ea267d3` (`5e0996a`) adds wide inline Customize navigation with contextual Plugins,
  Skills, Apps and MCP, Installed search and bounded Back/Forward. The active
  conversation stays mounted; catalog state is lazy and scoped to the current
  `(cwd, threadId)`. Compact retains its dialog. The independent replay
  completed a stock turn, retained a composer draft across navigation,
  displayed real MCP results and exited App/Host/stock/fixture processes.
  Its first run correctly rejected malformed automated JSON input and exposed
  stale incremental icon-font assets. Failure captures and the old font are
  retained. A clean isolated rebuild and paced input passed; this does not
  establish an upstream cache fix or account-backed UI parity.
- `2446dd0` adds measured loose-list, quote, table, separator and fenced-code
  geometry through the bounded single-parse Markdown renderer. The code card
  has keyboard Copy and timer cleanup. Ordinary Desktop Send/Stop/Steer uses
  the verified 28 px / 16 px branch, with compact targets preserved. The
  independent stock replay used a positively tested loopback image sentinel,
  checked its count after Native exited, and verified persisted interruption
  before application shutdown. The original peer pre-UI image counter was
  insufficient network evidence. Both capture sets and that limitation remain
  recorded in the matrix. This cluster leaves Golden State A active.
- `53a76d5` integrates `d09fe2e` + `7b30475` and `c910a97` + `7d416aa`.
  Desktop stock questions share one title/status header. Choice rows map the
  recommendation badge, markers, hover transfer and return affordance.
  The inline Other footer and primary action share the measured grouping.
  Goal time reads wall time on a mounted, lifecycle-aware minute ticker.
  Revert restores collapsed end selection without refocusing. Empty Send
  uses the measured opacity while shared button defaults are preserved.
  Peer and integrated releases submitted both stock answers, observed a
  zero-input minute update, saved an objective, reverted a draft and exited
  the process tree. Integrated captures use a separate non-reusable folder.
  The fixture's model-metadata warning remains visible and recorded.

The [current matrix](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md) retains
per-row implementation commits, evidence and next corrections. Earlier
narratives remain in the [Golden State A checkpoint archive](docs/history/GOLDEN_STATE_A_CHECKPOINTS_through_165d7c5.md)
and [preceding Desktop history](docs/history/DESKTOP_UI_CHECKPOINTS_through_fe67973.md).

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

- The current presentation source at `ea267d3` passed 553 default Flutter cases and
  five separately enabled direct-stock integration cases. Dart format and
  strict analysis passed in an ASCII physical-path source copy. This does
  not fix the recorded Unicode-path Flutter LSP framing failure.
- The clean Linux release and its 83-library runtime closure passed. The
  independent packaged walkthrough at `/var/tmp/native-integrated-a1-ea267d3-r2/`
  used bundled Host, installed stock `0.167.0-alpha.3.2` and disposable local
  model/MCP fixtures. Its service-side audit verified resource/tool requests
  and selected-thread identity; result rows, navigation and draft continuity
  were inspected. No owned runtime children remain. Earlier checkpoints
  cover rich prose, turn controls, project actions, output, questions and Goals.
- The pure-Dart boundary checked 65 roots. The history benchmark retained
  100 of 1,000 turns while exercising ten 3 MiB command payloads. The
  unchanged Rust tree passed formatting, Clippy and 100 tests.
- The preceding published `22c1136` passed all three hosted CI jobs.
  Each subsequent pushed HEAD requires its own result check.
  [Hosted CI](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42976181660)
- Signed-in official live captures, subjective interaction acceptance
  and unavailable physical devices remain evidence gates on their own
  surfaces. The primary UI has machine-actionable rows in Golden State A.

- `HUMAN_REVIEW_PENDING`: subjective section interaction, the saved MCP text
  viewer, and ecosystem loading, partial-state and retry presentation.
  Physical Android TLS/Keystore, camera and cross-network pairing remain
  separate device gates.
- Account security notice presentation remains unavailable. A disposable probe showed that experimental cached account routing can match an already stale notice. A future presentation requires a verified public stock identity contract.
- The primary Desktop screen has open machine-actionable rows in the
  Golden-State contract. Signed-in official comparisons for later states
  are tracked there individually. [Living queue](docs/reverse/OFFICIAL_FEATURE_MATRIX.md#36-active-queue-after-consolidation)
