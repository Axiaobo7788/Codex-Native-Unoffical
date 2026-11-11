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
cluster, inline-code pills and ordinary composer action have current source
translations. Routed Customize destination/sidebar/focus structure also has a
source translation and packaged-stock replay.
Home, open Changes, Review, compact and dark keep separate state gates.

## Active peer coordination

- Exact shared HEAD `5e0996aee18363845b628b1e50ef5b3bb73c4b30` (integrating the
  A0/A1 Customize slice `ea267d3` + `c8d3bd3` + `17d201c`) passed all three
  hosted CI jobs
  ([43007725868](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43007725868):
  `verify`, `Windows x64`, `macOS arm64`).
- Gemini completed the A6 Desktop inline-code pill candidate (`d9dc65f`) on
  branch `agent/gemini-golden-a-inline-code` (`/var/tmp/native-gemini-golden-a-inline-code`).
  Public-API runtime probes (`/var/tmp/native-gemini-a6-inline-code-r1/public_api_probe_test.dart`)
  reproduced lost enclosing-link taps and `4×` double-scaling without
  `TextScaler.noScaling` while confirming that built-in `SelectionArea`
  `selectAll` and mouse drag preserve exact document order across wrapped
  multi-pill paragraphs (no custom selection delegate needed). Peer diff review
  consolidated `DesktopMarkdownBody` defaults and table scale onto
  `OfficialCodexTheme` and switched pill link taps to late State callback
  dispatch, verified on a cached `DesktopMarkdownBody` update with equal
  `MarkdownStyleSheet` and `identical` pill widget instances. Gemini now
  releases all six owned surfaces (`official_codex_theme.dart`,
  `assistant_markdown.dart`, `desktop_markdown_body.dart`,
  `assistant_markdown_test.dart`, `OFFICIAL_UI_GOLDEN_STATE_A.md`,
  `PROJECT_STATUS.md`) and the single heavy runtime slot to Codex for
  independent systems-integrity review, shared gates and integration.
- On 2026-11-11 at 15:54, the host kernel reported global OOM and killed the
  ChatGPT process. Codex and Gemini validation overlapped; the kernel snapshot
  included two Flutter compiler pipelines and six test runners. The interrupted
  Codex batch has no completion result. Its old workers are gone. A subsequent
  four-file batch passed 69 cases serially; later owner edits have separate
  pending validation. This does not establish a Native memory-leak diagnosis
  or fix. Both peers now share one heavy validation/build/capture slot and use
  `flutter test --concurrency=1` and `CARGO_BUILD_JOBS=2`. Installed Flutter
  invokes Ninja directly: setting `CMAKE_BUILD_PARALLEL_LEVEL=2` alone did not
  cap those jobs. Subsequent Linux builds use Flutter `--config-only`
  followed by `cmake --build … --target install --parallel 2`; the independent
  rebuild observed `ninja -j 2`. No user desktop
  applications, swap configuration or account settings were changed.

## Current checkpoints

- `d9dc65f` translates `.InlineCode-Cddi3Y`
  (`1 px 6 px` padding, `6 px` radius, `dir="ltr"`, container-relative `0.92 em`
  monospace, light `0x171A1C1F` / `#EAEBEB` on `#FFFFFF`, dark `0x1CEDEDED` /
  `#373737` on `#212121`) across `p`, `h1`–`h6`, `ul`/`ol`, `blockquote`,
  `table` `th`/`td` and enclosing `<a>` links while preserving `16 KiB` single
  AST parse, `!completed` streaming bypass, fenced `<pre><code>` exclusion,
  `http`/`https` link validation, literal HTML and zero-network blocked images.
  Serial `--concurrency=1` validation passed `23/23` cases
  (`assistant_markdown_test`, `theme_tokens_test`,
  `official_convergence_geometry_test`), `dart format`, `dart analyze
  --fatal-infos`, `65`-root pure-Dart boundary and a clean first-build
  `83`-library Linux bundle closure. Packaged `1191×865` stock replay
  (`/var/tmp/native-gemini-a6-inline-code-r1/stock-replay-r2/`) verified `0`
  requests to the positively tested loopback image sentinel after light and dark
  App/Host/stock exit and matched the controlled identical-text `13.5 px` /
  `640 px` build `25894` CSS specimen (`official-a6-inline-code-matched-13_5-{light,dark}.png`,
  calibrated to `ThemeTokens.bodyMedium` without claiming official signed-in
  account font preference; the earlier unmatched `13 px` exploratory specimen,
  `stock-replay-r1` without `gsettings` dark toggle, Xvfb
  portal/AT-SPI/PipeWire/DRI3/initial-resize warnings, `Liberation Mono` vs
  Linux system `monospace` glyph advance, and single unbroken `> 640 px` token
  `WidgetSpan` box wrapping vs CSS `box-decoration-break: clone` per-fragment
  rounding remain recorded boundaries; `MACHINE VERIFIED` + `AGENT REAL-USE
  VERIFIED`, `NOT YET HUMAN VERIFIED`).
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
