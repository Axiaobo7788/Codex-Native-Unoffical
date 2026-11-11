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

The [historical wide Desktop ranking](docs/reverse/OFFICIAL_UI_STRUCTURAL_MAPPING.md#wide-desktop-visual-parity-ranking)
records the earlier passes.
The ordinary project thread rows now retain their Git reference in the hover
tooltip. A paired Linux release capture measures a 54 → 36 logical px thread
pitch and shows Git context and row actions on hover. The pending question
now uses the neutral surface visible in H1. The release app submitted a
choice through the bundled Host and stock app-server. The command preview
groups the neutral output surface and full-output action in one card. The
Linux release opened the 4 KiB preview and the first and last pages of the
same live spool. A fresh wide capture shows the real Changes pane beside the
timeline. The wide composer shows stock context usage in a ring with a
detailed tooltip, freeing the title from its numeric badge. The Home project
selector now sits inside the heading and keeps its keyboard and draft
behavior. The complete Flutter suite passed 515 cases. All five opt-in
stock cases passed in a separate isolated run. Desktop user message actions
now reveal below the right-aligned bubble on hover or focus. The release app
opened and dismissed the existing Edit confirmation. The workspace title
stands apart from the trailing Linked PR control, which remains actionable
with an empty scan. Runtime details open from the lower rail in the wide
shell. Active Commands groups the stock read/run categories on the existing
latest row. Execution and the bounded output preview remain available. The
selected goal now appears above the request and composer, using the existing
stock controller and a single hydration. The selected Goal now has quick
actions and a right-side editor. The release saved an objective, closed on
Escape and submitted the pending stock answer. The active thread row swaps its
trailing spinner for actions on interaction. The release opened saved stock
activity with the corrected chevron and a real +80/−0 diff from the translated
Changes summary. The Golden-State matrix records the remaining machine work.
The workspace header now ends with thread menu, detail options and the
supported side-panel toggle. Release search and Goal opening use the new
routes. The active Goal label now ticks locally without new stock reads.
Desktop stock questions use distinct steps. The Linux release delivered both
answers in a two-question request. The confirmed Full access shield uses its
own warning glyph. The execution dialog and dropdown stay usable at 820×420
and 1191×865. The wide sidebar omits the empty Pinned group and the saved
stock scope stays reachable from View. Desktop assistant prose uses the
measured 1.625 line-height ratio. The release rendered saved stock paragraphs
and lists and retained the bounded timeline behavior. The wide project
list now uses trailing running/unread indicators and quiet idle rows.
The real stock Thinking state now gives way to Thought and final prose.
Goal is inset 13 logical px from the composer. The Plugins rail glyph
and selection use the backed ecosystem route. Desktop Back and Forward
revisit a bounded list of stock threads, and older assistant copy actions
appear on interaction. The Linux release opened the selected patch directly
from a two-file Changes preview during a real stock turn. Opening the pane
removes the closed chip. The Goal title opens the same editor as its expand
control. Projects reveals its current actions on interaction. Numbered
stock question choices work with arrows and Enter. The packaged app delivered
both answers in a real stock request. The desktop permission shield opens
an anchored Sandbox menu. The clean package displayed and dismissed the
existing Full access confirmation without starting a turn. The Desktop model
picker opens an anchored stock catalog and explicit reasoning slider.
The Linux release verified model/effort overrides and subsequent stock
session inheritance. The current Goal draft survives a switch to Changes
and header hide/reopen. Explicit close still returns to the saved objective,
as verified during a real stock turn. Mouse Back/Forward use the same
bounded Desktop thread history as the toolbar and keyboard. The Desktop
strip includes backed Edit and Help menus. A Linux package selected,
deleted and restored an unsent draft through Edit and handed the official
documentation URI to the system handler. The active activity summary groups
stock exploration and counts command runs. The saved disclosure uses the
stock elapsed milliseconds when present and still reads command details on
open. Expanded saved stock exploration has bounded read, search and list
captions in Commands. The Linux package opened real output and switched
to raw Execution. Clicking the visible Goal strip again closes the editor
and discards its local draft. The Linux release submitted both stock
question steps through Continue and Submit. The saved Markdown list text
is inset two body em, verified on a paired stock capture. The active
Desktop composer uses one Stop/Steer slot. Double Escape interrupts a
stock turn while keeping its unsent draft. An arriving approval disarms
that shortcut, verified on the packaged app. Empty Send is disabled and
separated from the permissions control by 8 px. The ordinary focused
composer retains its neutral border. Desktop assistant Markdown uses
the measured body-relative heading proportions. Desktop stock choices
preselect the first answer. Wide stock questions show Other in the
action footer. Direct choices advance or submit by click or digit
in the active Desktop request. A project row keeps its New chat
action reachable by Tab. Home, open Changes, Review, expanded activity,
compact and dark variants have separate evidence gates.
[Hosted CI for `c42eac5`](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42947793108)

## Active peer round

- Base `165d7c5` is pushed and its exact hosted CI passed all three jobs.
  Gemini owns the coherent A9–A11 bottom-stack presentation cluster in
  `agent/gemini-golden-a-bottom-stack`. Codex owns the independent request
  operation-lifetime correction in `agent/codex-input-operation`, actual-diff
  review, real-stock validation and shared integration. Presentation and
  controller/test write surfaces are separate.
- The request controller's old completion could clear the next submission,
  overwrite its error or remove a reused request ID after authoritative
  resolution. Four new typed controller regressions fail on the base. One
  bounded operation token and captured request identity protect submit,
  cancellation and MCP responses. Disposal invalidates pending operations.
  Strict ASCII analysis, 31 controller/widget cases and 26 protocol/simulated
  cross-feature cases passed. The specific delayed-completion race is typed
  test evidence. Real-stock walkthrough and shared gates belong to the
  integrated checkpoint.
- Peer review accepted the typed operation-kind correction. An unrelated
  resolved event cannot retire another request kind with the same ID. A typed
  authoritative resolution still retires an active write after its row leaves
  the bounded projection. The cross-kind regression fails at `c910a97` and
  passes with the correction. The suggested retirement on arbitrary same-ID
  replacement or projection eviction was reclassified NOT REPRODUCED for the
  supported adapter. It suppresses in-flight duplicate IDs, emits typed
  resolution on close and shares a 32-request upstream budget. Local row
  eviction preserves write serialization. The operation record remains one
  slot and compares its child Object token, preserving the public getters.

## Current checkpoint

- `0378125` integrates Gemini's A2–A3 presentation commits `d74cb39` and
  `f1e2fbb` with the Goal lifecycle slice. Wide New chat, project and thread
  labels share one axis. Thread selection uses the full row. Collapsed
  projects show loaded-thread status. Context menus use pointer coordinates,
  focused-row bottom-left keyboard coordinates or the ellipsis anchor.
  The owner corrected compact geometry drift, viewport clipping and the
  independently reproduced 52 px keyboard-menu displacement before
  integration. The integrated release exercised both pointer menus and the
  sequential Goal saves/external replacement through bundled Host and stock.
  Shared format, strict ASCII analysis, 538 default Flutter cases, five
  direct-stock cases, bounded-memory benchmark, pure-Dart boundary, Rust
  gates and Linux release/runtime closure passed. Golden State A remains
  active. The next presentation cluster is being evaluated through agy.
- `d3bf1d0` and `481788f`, integrated in `c241269`, preserve the Goal
  editor's saved-source identity across notification-before-ack ordering.
  External objective replacement closes the old editor. Own saves adopt
  the accepted source before the closure check, including a parked draft.
  The pending save is serialized and cleared without relying on Dart record
  identity. Twenty Goal/history/layout cases and strict ASCII analysis
  passed. A release replay persisted two consecutive keyboard saves,
  closed after a separate stock source update and exited the process tree.
  The baseline reproduced the stale dirty editor. Gemini's actual-diff
  audit returned no P0/P1/P2 findings. The shared integration above preserves
  that behavior.
- `c8e96a0` translates the Goal editor toolbar and guarded save shortcut.
  The font runtime/CSS chain corrected the initial body-size inference.
  The real Linux package saved through Ctrl+S, retained an unsaved draft
  across 950/1191 px resizing and discarded it on explicit close. Minute
  refresh and Revert focus remain active A9 checks. The matrix preserves
  the initial saved-only resize observation
  and the pre-existing isolated-Xvfb frame warning.
- `4d379ed` maps Goal status, objective, bullet and usage into the same
  click target with the measured compact actions. The peer comparison
  corrected short-goal flex and horizontal insets. The exact Linux package
  opened the persisted stock Goal by clicking its elapsed text. The editor
  toolbar, shortcuts and external-source closure are covered by the later
  checkpoints above.
- `599605c` maps the single stock question title to the same measured
  header as multiple questions. Paired release replay submitted the selected
  answer and all three processes exited. The peer identified the extra
  queued/submitting header as a remaining machine-actionable A10 delta.
- Desktop remains in Golden State A reconstruction. `55541ea` adds
  tight-list flow to the root adjacency translation in `f7144df`.
  The parser runs once, and the standard Markdown builder renders each
  root once. Paired stock captures verify root gaps and nested tight-list
  flow. Loose-list and outer-edge margins remain open in A6.
- `15e3242` maps Escape on the active stock question to turn interruption.
  The first real replay rejected a blocking-only assumption. Corrected
  timer and focused-editor replays reached stock interrupted state.
  Explicit request cancellation and H1 async input remain distinct.
- `a3bcd98` adds the saved command group's second disclosure and 224 px
  lazy viewport. The real preview survives Commands/Execution transitions,
  is released on collapse and remains searchable through loaded items.
  Mixed tools, declined activity and signed-in expansion remain in A7.
- Project New chat is keyboard-accessible. `a8b2104` adds the start-aligned
  local folder menu, verified through a disposable Linux system handler
  and the missing-folder error path. Authoritative project metadata and
  account destinations remain separately tracked in A2.

The [current matrix](docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md) identifies
per-row implementation commits, evidence and next corrections.
[Earlier checkpoint narratives](docs/history/DESKTOP_UI_CHECKPOINTS_through_fe67973.md)
remain available as history.

## Current product and architecture

- Desktop uses the bundled Rust `codex-native-host` and stock `codex app-server`. The local workflow includes thread management, turn streaming and steering, approvals, model and execution controls, bounded diff/output, stock review, and supported Skills/Plugins/Apps/MCP administration. Availability can depend on installed stock version, configuration and account.
- The wide native desktop shell has a 52 logical px navigation rail and a 288 px contextual sidebar by default. The 340 px total left area is resizable, and the reading and composer column is capped at 672 px. Below 760 px Native uses compact Threads navigation. `OfficialCodexTheme` owns the geometry and colors, and the responsive shell keeps one active conversation state.
- Codex is the only wired product. Prose, Commands and Execution are timeline detail choices. The internal Work and Chat capability profiles and backend interfaces are compatibility seams. Independent ChatGPT Chat, Work orchestration and Responses backends are absent.
- App-server owns persisted conversation state. Flutter retains bounded thread/history/active-turn projections, virtualizes lists, coalesces streaming, evicts inactive history, and lazily loads bounded output and diffs. Host spooling keeps large command payloads off the Flutter heap and preserves opaque MCP result fields with the same key name. Installed stock and public stable `0.167.0` returned the sampled command output inline. Public alpha `0.169.0-alpha.7` deferred eligible commands through the existing Native fetch path. Experimental `thread/items/read` returns the stored item.
- Saved turns expose a detail disclosure in Commands and Execution even when a work duration cannot be shown. Opening it loads one bounded turn item page. A failed first read leaves the summary in place and can be retried.
- The global sidebar groups and filters loaded threads. Local Section browsing and explicit saved-thread search reuse its 100-thread working-set cap. Section definitions remain capped at 64. Switching scopes preserves the active conversation outside the list. Sidebar, Section rows, and saved-thread search currently use the configured stock provider. Cross-provider visibility and cold resume are separate research questions.
- Saved local threads can show an unread marker from stock. The sidebar Mark as read and Mark as unread actions use the displayed revision. A conflict refreshes the receipt and requires a fresh user action.
- Local composer Send checks queue presence before implicitly resuming a cold thread. Pending or inconclusive results offer a separate Resume and retain the draft. Identified local user items appear in the live timeline. Stock IDs drive deduplication, and a local start or steer keeps its existing visual row when echoed.
- Conversation Find filters loaded messages. A separate action searches saved messages on eligible local stock threads, one 16-hit page at a time. Opening a hit verifies a bounded turn window before replacing the current one. Legacy threads retain loaded-message Find.
- Stock Pinned is protected by its reserved ID. Eligible unsectioned pins use stock membership after a fresh read. Custom-section threads and runtimes without that built-in retain explicitly labeled session pins.
- Local Goal actions load the selected thread’s persisted goal on demand and support explicit paused creation, objective changes, pause/resume, and confirmed clear. Stock owns continuation. Desktop Review offers working-tree, base-branch, commit/ref, and custom targets through stock `review/start`. Both Review entry points apply the cold queue admission rule.
- Local Runtime details displays a bounded read-only provider list when stock supports it. The list keeps display names, provider kinds and the default marker. Older versions show an availability message.
- Local MCP resource and tool forms stay in the running operation's dialog. Direct actions on a cold thread require explicit resume. A global resource read remains available without a selected thread. Eligible saved MCP activity in Commands and Execution offers a one-item local read with a 32 KiB text preview.
- The local conversation header reads stored GitHub and GitLab review references for the selected thread with one in-flight scan and one replaceable pending target. The user can open a link or explicitly add one to a saved thread. Add checks existing canonical and legacy links before writing. Removing references, managed worktrees, and cloud attachments remain separate surfaces.
- Skills, Plugins, Apps and MCP can load independently. Plugin refresh keeps the cached catalog on RPC failure and serializes catalog mutations through readback. Successful partial plugin catalogs retain usable rows and show a generic notice. Failed source paths and raw parser messages are omitted from the typed snapshot. The catalog still retains up to 100 entries. A truncation notice is ready for implementation.
- Direct Host Remote is read-only. The transport allows bounded model/thread metadata and history reads and sequenced lifecycle projection. Android currently presents pairing, connection recovery and model/thread metadata. Thread/turn writes, approvals, diffs, and command-output reads remain outside the Remote contract. Official Remote support is experimental host-side control through stock schema. There is no Native mobile client for the official relay.

## Verification and pending gates

- The current presentation source at `0378125` passed 538 default Flutter cases and
  five separately enabled direct-stock integration cases. Dart format and
  strict analysis passed in an ASCII physical-path source copy. This does
  not fix the recorded Unicode-path Flutter LSP framing failure.
- The Linux release and its 83-library runtime closure passed. Packaged
  walkthroughs exercised local project actions, saved activity/output,
  question steps, custom answers and pending-turn interruption through
  bundled Host and installed stock `0.167.0-alpha.3.2`.
- The pure-Dart boundary checked 65 roots. The history benchmark retained
  100 of 1,000 turns while exercising ten 3 MiB command payloads. The
  unchanged Rust tree passed formatting, Clippy and 100 tests.
- The latest confirmed shared CI checkpoint is `165d7c5`.
  Later exact-HEAD runs remain separate until their results are read.
  [Hosted CI](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42956195792)
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
