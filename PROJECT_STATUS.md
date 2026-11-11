# Project Status

**Program mode: `SELF_ITERATION`**
**Current phase: Desktop UI Visual Parity Loop (post-structural priority override within Official Client Convergence).**
**Program objective: reach 0.x pre-release/RC readiness.**

The Desktop priority governs slice selection. Phase checkpoints and
slice-scoped Human review preserve the broader program objective.

Use this page for current facts, [the feature matrix](docs/reverse/OFFICIAL_FEATURE_MATRIX.md) for the living queue, [Architecture](docs/ARCHITECTURE.md) for system boundaries, and [Decisions](docs/DECISIONS.md) for ADRs. Historical checkpoints are in the [pre-consolidation archive](docs/history/PROJECT_STATUS_through_F14.md), the [F15–F23 record](docs/history/CONVERGENCE_F15_F23.md), and the [Desktop checkpoint history](docs/history/DESKTOP_UI_CHECKPOINTS_through_fe67973.md).

## Active priority override

- Human side-by-side comparison of the current Native window with the current
  official Codex Desktop rejected the prior structural-fidelity assumption:
  correct individual tokens do not compensate for a divergent shell/component
  hierarchy.
- **UI reconstruction is now the highest-priority machine-actionable program.**
  Existing functional READY items remain valid backlog entries but are
  DEFERRED_BY_UI_PRIORITY until the core official Desktop shell is structurally
  reconverged.
- The implementation contract is **Do not design. Translate.** Refresh the
  current official hierarchy first, then map it one-to-one into Flutter using
  existing domain/controller behavior wherever possible.
- Previous UI reverse documents remain useful token/component evidence, but
  structural claims must be revalidated against the current official window.
  Older geometry tests are regression evidence, not proof of current parity.
- Codex and Gemini remain equal peers through the official agy TUI. During the
  active Golden-State parity phase, **Gemini is the default presentation
  writer**: it refreshes live/ASAR/visual evidence, owns the corresponding
  Flutter presentation slice, captures Native, and iterates on measured visual
  divergence. **Codex is the default systems-integrity owner and adversarial
  reviewer**: it protects architecture/state/memory/protocol boundaries, adds
  targeted regressions, exercises real stock/runtime paths, integrates, and
  runs shared gates/CI. Codex should not take over a presentation slice unless
  Gemini is blocked, the change is predominantly systems work, or ownership is
  explicitly released. Prefer coherent Golden-State row-sized UI slices over
  one remote push/full-CI cycle per micro-adjustment.
- F33+ remains DEFERRED_BY_UI_PRIORITY while evidenced Golden-State work
  can progress. Freeze only the state that lacks evidence. When no UI state
  can progress, resume independent functional READY or RESEARCH_MORE work.

## Current work selector

The structural translation checkpoint is established. [Golden State A](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md)
is the current acceptance matrix for the signed-in wide active conversation.
Use the current official-to-Native divergence to choose the next correction.
The screen remains in machine-actionable reconstruction.

Priority order:

1. same-state official/Native screenshot or live-behavior divergence;
2. explicit Human feedback;
3. correctness/accessibility/security/data-loss/state regression caused or
   exposed by the translated UI;
4. bounded hardening only when it blocks the next comparison or normal use.

Tests remain mandatory gates. They are not the default source of new UI slices.
Speculative extreme-size combinations and test-only follow-ups should be recorded
and deferred unless they expose a material defect.

The wide shell, supported stock conversation controls, lazy activity/output,
Goal side tab and question/composer stack have working source translations.
Current deltas remain row-scoped in the Golden-State matrix. The rich-prose
cluster and ordinary composer action have current source translations.
Routed Customize destination/sidebar/focus structure is the next coherent
candidate. Inline-code pill rendering remains machine-actionable research.
Home, open Changes, Review, compact and dark keep separate state gates.

## Active peer coordination

- Shared source `2446dd0` integrates Gemini's A6/A11 cluster (`d0882b9`,
  `316a4f4`, `50bda90`). The actual-diff review found no P0/P1. The owner
  corrected Copy keyboard focus and the code-card border. Inline pill
  rendering remains a PARTIAL-row machine follow-up.
- The exact published `245204e` checkpoint passed all three hosted CI jobs.
  Current source passed format, strict ASCII analysis, 549 default Flutter
  cases, five direct-stock cases, pure-Dart boundary, memory benchmark and
  Rust gates. Its independent Linux release/83-library closure, instrumented
  packaged-stock replay and pure-Dart runtime smoke passed.
- Gemini released the completed presentation surfaces. Both peers selected
  A1 routed Customize as the next high-value candidate. Refresh the official
  agy context and negotiate its writable surfaces after integration/CI.
  Gemini remains the default presentation writer. Codex owns systems-risk
  review, realistic runtime validation, integration and shared gates.

## Current checkpoints

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
- `0378125` integrated `d74cb39` + `f1e2fbb`. New chat, project and thread
  labels share one wide axis and selection uses the full row. Collapsed
  projects show loaded-thread status. Menus use pointer coordinates, focused
  row keyboard coordinates or the ellipsis anchor. The owner corrected
  compact drift, edge clipping and the reproduced 52 px keyboard offset.
- `c241269` integrated `d3bf1d0` + `481788f`. Own Goal saves survive a
  notification before acknowledgement, including a parked draft. External
  objective replacement closes the old editor. The baseline reproduced the
  stale editor. The release persisted two sequential keyboard saves and a
  separate stock source replacement with clean process shutdown.

The [current matrix](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md) retains
per-row implementation commits, evidence and next corrections. Earlier
narratives remain in the [Golden State A checkpoint archive](docs/history/GOLDEN_STATE_A_CHECKPOINTS_through_165d7c5.md)
and [preceding Desktop history](docs/history/DESKTOP_UI_CHECKPOINTS_through_fe67973.md).

## Current product and architecture

- Desktop uses the bundled Rust `codex-native-host` and stock `codex app-server`. The local workflow includes thread management, turn streaming and steering, approvals, model and execution controls, bounded diff/output, stock review, and supported Skills/Plugins/Apps/MCP administration. Availability can depend on installed stock version, configuration and account.
- The wide native desktop shell has a 52 logical px navigation rail and a 288 px contextual sidebar by default. The 340 px total left area is resizable, and the reading and composer column is capped at 672 px. Below 760 px Native uses compact Threads navigation. `OfficialCodexTheme` owns the geometry and colors, and the responsive shell keeps one active conversation state.
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
- Local MCP resource and tool forms stay in the running operation's dialog. Direct actions on a cold thread require explicit resume. A global resource read remains available without a selected thread. Eligible saved MCP activity in Commands and Execution offers a one-item local read with a 32 KiB text preview.
- The local conversation header reads stored GitHub and GitLab review references for the selected thread with one in-flight scan and one replaceable pending target. The user can open a link or explicitly add one to a saved thread. Add checks existing canonical and legacy links before writing. Removing references, managed worktrees, and cloud attachments remain separate surfaces.
- Skills, Plugins, Apps and MCP can load independently. Plugin refresh keeps the cached catalog on RPC failure and serializes catalog mutations through readback. Successful partial plugin catalogs retain usable rows and show a generic notice. Failed source paths and raw parser messages are omitted from the typed snapshot. The catalog still retains up to 100 entries. A truncation notice is ready for implementation.
- Direct Host Remote is read-only. The transport allows bounded model/thread metadata and history reads and sequenced lifecycle projection. Android currently presents pairing, connection recovery and model/thread metadata. Thread/turn writes, approvals, diffs, and command-output reads remain outside the Remote contract. Official Remote support is experimental host-side control through stock schema. There is no Native mobile client for the official relay.

## Verification and pending gates

- The current presentation source at `2446dd0` passed 549 default Flutter cases and
  five separately enabled direct-stock integration cases. Dart format and
  strict analysis passed in an ASCII physical-path source copy. This does
  not fix the recorded Unicode-path Flutter LSP framing failure.
- The Linux release and its 83-library runtime closure passed. The current
  packaged walkthrough exercised rich prose, Send/Stop/Esc/Steer presentation
  and persisted interruption through bundled Host and installed stock
  `0.167.0-alpha.3.2`. The pure-Dart runtime smoke shut down in 36 ms.
  Earlier checkpoint walkthroughs cover project actions, saved output,
  structured questions and Goal updates.
- The pure-Dart boundary checked 65 roots. The history benchmark retained
  100 of 1,000 turns while exercising ten 3 MiB command payloads. The
  unchanged Rust tree passed formatting, Clippy and 100 tests.
- The preceding published `245204e` passed all three hosted CI jobs.
  Each subsequent pushed HEAD requires its own result check.
  [Hosted CI](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42965989053)
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
