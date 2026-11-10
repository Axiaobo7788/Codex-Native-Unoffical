# Project Status

**Program mode: `SELF_ITERATION`**
**Current phase: Desktop UI Visual Parity Loop (post-structural priority override within Official Client Convergence).**
**Program objective: reach 0.x pre-release/RC readiness.**

The Desktop priority governs slice selection. Phase checkpoints and
slice-scoped Human review preserve the broader program objective.

Use this page for current facts, [the feature matrix](docs/reverse/OFFICIAL_FEATURE_MATRIX.md) for the living queue, [Architecture](docs/ARCHITECTURE.md) for system boundaries, and [Decisions](docs/DECISIONS.md) for ADRs. Historical checkpoints are in the [pre-consolidation archive](docs/history/PROJECT_STATUS_through_F14.md) and [F15–F23 record](docs/history/CONVERGENCE_F15_F23.md).

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
- Codex and Gemini remain equal peers through the official agy TUI. Gemini
  preferentially refreshes live/ASAR/visual evidence; Codex preferentially
  performs clean-room Flutter translation and protects architecture/state
  invariants. Both review the actual result.
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
Home, open Changes, Review, expanded activity,
compact and dark/focused states have separate evidence gates. [Hosted CI for `70a12da`](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42829481686)

## Current checkpoint

- The empty Home workspace supports keyboard project selection and retains
  the draft across directory changes. A 760 px viewport at 200% text scale
  keeps the model and execution controls reachable. The current official
  bundle distinguishes the Home hero from the new-thread placeholder.
  [Home keyboard and source evidence](docs/RESEARCH.md#desktop-home-project-control)
- Desktop Commands and Execution share one bounded inline output preview
  across completed live commands and opened saved-turn details. Switching
  to another visible command replaces the preview. A pending read still
  occupies the single read slot after its row disappears. The Linux release
  package previewed 4,096 bytes of an active command and opened the first
  and last pages of the same 179,835-byte Host spool.
  [Unified output evidence](docs/RESEARCH.md#completed-commands-in-the-active-conversation)
- Completed commands in the active conversation can open their paged output
  as soon as the bundled Host provides a valid spool reference. The Linux
  package opened the first and last windows of 179,835 stored bytes before the
  assistant completed the turn. [Active command evidence](docs/RESEARCH.md#completed-commands-in-the-active-conversation)
- Desktop Commands and Execution can expand one saved command output in the
  timeline. Expansion reads at most 4 KiB from Host. The original paged viewer
  stays reachable, and compact layout opens it directly. A packaged Linux
  walkthrough opened the preview and full viewer for a saved stock command in
  a 240 px workspace. [Inline output evidence](docs/RESEARCH.md#desktop-inline-command-output)
- At 360×420 with 200% text size, Command output keeps its reading area,
  page actions and close control reachable. Output still uses the same
  bounded byte windows. [Short-window evidence](docs/RESEARCH.md#desktop-short-window-request-stack)
- `fb866dd`, `061f0da` and `5769e31` complete the short-window request audit.
  Approval details and MCP fields scroll within their budgets, and a short
  workspace with two pending cards gives them one shared scroll region. The
  existing question answer survives arrival and resolution of an approval.
  Linux stock walkthroughs received a rejection at 760×420 and an MCP decline
  at 820×420. The simultaneous request path has simulated runtime coverage.
  `aaecb40` checks cold review admission before opening the target chooser
  and again before a cold review is dispatched.
  [Short-window evidence](docs/RESEARCH.md#desktop-short-window-request-stack)
- `155ea2f` translates the current official Changes side-tab contract into a
  separate wide Desktop pane. The packaged app showed the active timeline and
  a real Git diff side by side. `515d283` gives a pending question room around
  the actual header, warning and composer. A Linux stock walkthrough scrolled
  and submitted an answer at 820×420.
  [Secondary surface evidence](docs/RESEARCH.md#desktop-secondary-surface-follow-up)
  [Hosted CI for `79bcf2e`](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42790089477)
- Desktop remains in `SELF_ITERATION` while signed-in visual comparison is
  slice-scoped. `fd4ebe1` retains model and reasoning controls in a 240 px
  workspace and gives the draft its own row when the active controls need
  room. `8b6c617` enables arrow-key navigation in Desktop menus. `0023e11`
  restores the bounded history position after returning from Changes.
  [Interaction evidence](docs/RESEARCH.md#desktop-interaction-follow-up)
  [Hosted CI for `6ed96f9`](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42787565631)
- The Desktop structural checkpoint translates the current wide Codex shell,
  contextual sidebar, workspace header, inline activity, change disclosure,
  and active composer. R0 ties the changes to installed renderer build
  `25894` and a signed-in official reference supplied by the user. Packaged
  Linux validation exercised a Git diff, a cold working-tree review and
  wide/compact draft continuity. The current Golden-State matrix supersedes
  the earlier screen-wide review designation.
  [Evidence and known differences](docs/reverse/OFFICIAL_UI_STRUCTURAL_MAPPING.md)
- Third-party consolidation landed at `a64b8e7`. [Hosted CI 42648632704](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42648632704) passed on that SHA. See [findings](docs/RESEARCH.md#third-party-consolidation).
- F28 integrated bounded saved MCP text, a JSON-RPC lifecycle fix, and [workspace index evidence](docs/reverse/LOCAL_WORKSPACE_INDEX_EVIDENCE.md). [Hosted CI 42749446986](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42749446986) passed on `a1f7610`.
- F29 integrated responsive draft continuity and [saved queue readback evidence](docs/reverse/QUEUED_SUBMISSION_READBACK_EVIDENCE.md). [Hosted CI 42755492070](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42755492070) passed on `a755915`.
- F30 integrated independent ecosystem list loading and [plugin catalog truth evidence](docs/reverse/PLUGIN_CATALOG_TRUTH_EVIDENCE.md). [Hosted CI 42760384522](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42760384522) passed on `033eda8`.
- F31 integrated local partial plugin catalog states and [saved-thread provider scope evidence](docs/reverse/THREAD_PROVIDER_SCOPE_EVIDENCE.md). [Hosted CI 42765092016](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42765092016) passed on `8c64783`.
- F32 integrated [installed inventory evidence](docs/reverse/PLUGIN_INSTALLED_SCOPE_EVIDENCE.md) and [resume presentation evidence](docs/reverse/THREAD_PROVIDER_RESUME_PRESENTATION_EVIDENCE.md) at `6d96df3`. This round changed documentation.

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

- Home keyboard and large-text controls passed strict Dart analysis, the
  pure-Dart boundary, 515 Flutter cases with five opt-in skips, and Linux
  release bundle and license checks. The unified-preview predecessor
  passed all [Hosted CI jobs](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42815775318).
- Unified command output passed strict Dart analysis, the pure-Dart
  boundary, 514 Flutter cases with five opt-in skips, all five enabled
  direct-stock cases, the bounded-history benchmark, and Linux release
  bundle and license checks.
- Active command output passed strict Dart analysis, the 65-root pure-Dart
  boundary, 513 Flutter cases with five opt-in skips, all five direct-stock
  cases when enabled separately, the bounded-history benchmark, and the Linux
  bundle and license checks. Rust formatting, Clippy, and 100 Rust tests passed.
- The Desktop inline output checkpoint passed strict Dart analysis, the
  65-root pure-Dart boundary, 511 Flutter cases with five opt-in skips, all
  five direct-stock cases when enabled separately, the bounded-history
  benchmark, and the Linux bundle and license checks. Rust formatting,
  Clippy, and 100 Rust tests passed. The preceding `62661ab` checkpoint
  passed all [Hosted CI jobs](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42794120505).
- The short-window request and cold review checkpoint passed strict Dart
  analysis, the 65-root pure-Dart boundary, 510 Flutter cases with five
  opt-in skips, five separately enabled direct-stock cases, the bounded-history
  benchmark, Linux bundle checks, and six bundled Host smoke paths. Rust
  formatting, Clippy, and 100 Rust tests passed on the unchanged Rust tree.
- The Changes side pane and short-window question checkpoint passed 505
  Flutter cases with five opt-in skips, five separately enabled direct-stock
  cases, the bounded-history benchmark, Linux bundle checks, and six bundled
  Host smoke paths. The unchanged Rust tree and CI gates already passed on
  `6ed96f9`. [Secondary surface evidence](docs/RESEARCH.md#desktop-secondary-surface-follow-up)
- The Desktop interaction follow-up passed 504 Flutter cases with five opt-in
  skips, five separately enabled direct-stock cases, Dart format and analysis,
  the 65-root pure-Dart gate, the history benchmark, Linux bundle checks, and
  six bundled Host smoke paths. [Interaction evidence](docs/RESEARCH.md#desktop-interaction-follow-up)
- Desktop translation through `73f48f3` passed Dart format and analysis,
  the 65-root pure-Dart boundary, 502 Flutter cases with five opt-in skips,
  five separately enabled direct-stock cases, and the bounded-history
  benchmark (100 retained of 1,000 source turns). The unchanged Rust tree
  passed formatting, Clippy and 100 tests. [Desktop evidence](docs/reverse/OFFICIAL_UI_STRUCTURAL_MAPPING.md#native-implementation-checkpoint)
- F32 verified the current product's 100-row catalog projection and a compact resume failure visible only on Threads. Identical product source passed the Flutter, direct-stock, pure-Dart, Rust, history and bundle gates. See [F32 evidence](docs/RESEARCH.md#f32-installed-plugin-scope-and-compact-resume-failure-feedback).
- F31 passed 497 Flutter cases with five opt-in skips, 5/5 isolated direct-stock cases, 100 Rust tests, the 65-root pure-Dart gate, the history benchmark, Linux bundle checks, and six bundled Host smoke paths. The package verified distinct empty and partial states, usable mixed rows at 720×800, and successful refresh after a manifest repair. See [F31 evidence](docs/RESEARCH.md#f31-partial-plugin-catalogs-and-saved-thread-provider-scope).
- F30 passed 495 Flutter cases with five opt-in skips, 5/5 isolated direct-stock cases, 100 Rust tests, the 65-root pure-Dart gate, the history benchmark, Linux bundle checks, and six bundled Host smoke paths. The Linux walkthrough covered real healthy sections, a selectively delayed and failed plugin read, retry, and 720×800 navigation. See [F30 evidence](docs/RESEARCH.md#f30-independent-ecosystem-loads-and-plugin-catalog-truth).
- F29 passed 485 Flutter cases with five opt-in skips, 5/5 isolated direct-stock cases, 100 Rust tests, the 65-root pure-Dart gate, the bounded-history benchmark, Linux bundle checks, and Host MCP, Turn and Review smoke. The packaged walkthrough preserved text and a mention through wide and narrow layouts and same-thread reselection. See [F29 evidence](docs/RESEARCH.md#f29-responsive-conversation-continuity-and-saved-queue-readback).
- F28 passed 484 Flutter cases with five opt-in skips, 5/5 isolated direct-stock cases, 100 Rust tests, the 65-root pure-Dart gate, the history benchmark, Linux packaging, and Host MCP, Turn and Review smoke. Four stock versions read the saved fixture. Packaged walkthroughs verified inline and deferred results, including a long preview at 720×800. See [F28 evidence](docs/RESEARCH.md#f28-bounded-saved-mcp-text-and-workspace-index-evidence).
- `HUMAN_REVIEW_PENDING`: subjective section interaction, the saved MCP text
  viewer, and ecosystem loading, partial-state and retry presentation.
  Physical Android TLS/Keystore, camera and cross-network pairing remain
  separate device gates.
- Account security notice presentation remains unavailable. A disposable probe showed that experimental cached account routing can match an already stale notice. A future presentation requires a verified public stock identity contract.
- The primary Desktop screen has open machine-actionable rows in the
  Golden-State contract. Signed-in official comparisons for later states
  are tracked there individually. [Living queue](docs/reverse/OFFICIAL_FEATURE_MATRIX.md#36-active-queue-after-consolidation)
