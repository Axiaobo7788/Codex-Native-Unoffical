# Official Desktop to Native structural mapping

This map applies [ADR-041](../DECISIONS.md#adr-041--current-official-ui-evidence-is-a-translation-contract) and the [translation plan](OFFICIAL_UI_TRANSLATION_PLAN.md). It compares the connected Codex experience on the installed Linux renderer with Native. The desktop app's other product experiences have separate backends. The [official desktop guide](https://help.openai.com/en/articles/20001275-chatgpt-work-and-codex) confirms a product menu, but gives no Linux geometry or navigation hierarchy.

## Current official evidence

The target is the Codex layout shown in the user's signed-in Linux window.
The installed Linux package is `codex-desktop 2026.11.08.211600-1`, with
renderer `26.1103.60933` build `25894` and ASAR SHA-256
`121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`.
These are the locally examined build identifiers. The screenshot itself has
no build or DPR metadata usable to infer logical layout units.
The ASAR contains the shipped JavaScript and CSS. Its `webview` archive index
contains no `.map` entries.

- **H1, Human visual observation** — one 1191×865 signed-in, light, active
  conversation capture from the user on 2026-11-10. The full-width application
  controls occupy the strip above the content surface, which starts at
  y=51. The independent rail spans approximately x=0–60. The Codex sidebar
  starts at x=61; x=421 is its divider and x=422 begins the workspace.
  The left rounded edge encloses the sidebar and workspace surface. The
  screenshot provides physical pixel coordinates and visible state. The image
  and its conversation, project and account details stay out of Git.
- **S1, current static bundle** — `499225.36a7812ae9.js` contains shell/frame,
  application menu, workspace row, left panel and optional trailing sidebar.
  `182735.5b42af8792.js` module `d1ji` includes legacy, rail-only and
  rail-with-contextual-sidebar branches. H1 confirms the last structure for
  this session. The same code can render other navigation configurations.
- **S2, current static bundle** — `961657.97fdcc5e7d.js` includes shell
  titlebar, workspace header placement, page surface, compact gutter,
  main-content and trailing-toolbar slots. CSS defines a 36 px small toolbar
  token. The live sidebar sizing code in `182735.5b42af8792.js` module
  `qbQ6` defaults the persisted total left panel to 340 logical px and
  bounds it by viewport and a 520 px maximum. The current contextual branch
  supplies a 290 px minimum in `499225.36a7812ae9.js`. Its rail component
  feeds measured client width into the shell, with 52 px used as a fallback
  by the same bundle's related left-panel calculations. H1 does not establish
  the untouched default sidebar width or the window's zoom.
- **S3, current static bundle** — `605278.9a7ad6f681.js` module `IoIX`
  sets `isCodexHome` for the Home component in
  `634175.4437e0034c.js` module `ZlsN`. That component has separate
  projectless and project-selected hero text, with an interactive project
  control in the selected-project heading. `943693.334f9bc224.js` module
  `Hy2Z` separately renders the new-thread placeholder. These component
  contracts leave signed-in placement, gating, and the compact transition
  open for live comparison.
- **L1, live accountless control** — the installed app opened on a private
  Xvfb display using a fresh profile and the normal launcher. After startup
  it reached sign-in (1090×760, DPR 1). The frame/workspace/sidebar selectors
  were absent there. The run verifies the access boundary and window launch.

```text
Observed official Codex window (H1)
├── Application menu / window controls across the top
└── Content area
    ├── Persistent global navigation rail
    │   ├── Selected Home destination and other icon destinations
    │   └── Lower status and profile controls
    └── Shared rounded page surface
        ├── Contextual Codex sidebar
        │   ├── Product dropdown, notifications, search
        │   ├── New chat and Dot
        │   └── Projects → thread rows
        └── Conversation workspace
            ├── Folder, thread title and trailing actions
            ├── Scrollable prose / inline activity
            └── Bottom stack: change summary, goal, question, composer
```

## Native R0 baseline

Base `9db67e5` has identical Dart, Linux runner, Host and test source to the previously validated `665e050` bundle. Native was exercised on private Xvfb at device scale 1 with its bundled Host and installed stock `0.167.0-alpha.3.2`. Three saved threads across two disposable Git projects were produced with a local Responses fixture. The selected thread held one user prompt, two real stock command execution items and an assistant Markdown result. The tested commands only printed fixture text.

```text
Platform window (GTK on Linux)
└── RuntimeStatusScreen / connected workspace
    ├── Width ≥ 760, desktop split
    │   ├── Thread panel (260 wide, collapsible)
    │   │   ├── Sidebar brand/header, new thread and location, ecosystem
    │   │   ├── Threads actions, Pinned / sections / project and thread rows
    │   │   └── Connection status and Remote setup
    │   └── Inset workspace (6 top/right/bottom, 12 radius)
    │       └── Conversation panel
    └── Width < 760, compact workspace
        ├── Threads / Conversation toggle header
        └── One visible pane, both kept through Offstage / ExcludeFocus

Conversation panel
├── Workspace header (title, project, links, detail mode, search/actions)
├── Empty: centered project hero, composer and starter suggestions
└── Active: virtualized timeline or selected diff, notices and composer
```

The `app_shell_titlebar` test key is attached to the 46 px brand row **inside**
the sidebar. The outer title bar belongs to the platform runner. At 1280×800,
the open workspace begins at x=260, y=6 in the undecorated client area. When
collapsed, the conversation starts at a 6 px left inset and carries its own
reopen button. At 720×800, Native shows a separate 46 px compact header and the
thread workspace header below it. The same conversation state is reparented
across the breakpoint; navigation never mounts a second conversation state.

Native has live user bubbles and assistant prose, collapsible reasoning and
saved work-duration groups, detail-mode-dependent command/tool cards, and an
explicit command output dialog with a bounded byte window. The diff viewer
occupies the timeline area when a diff snapshot is selected. Code review starts
from thread actions; the chooser offers uncommitted, base branch, commit and
custom targets. The bottom composer has its own 704 px maximum width and input,
attachment, model, execution, workspace and send/stop controls. The hero
composer shares state with the bottom composer. Source paths for each surface
appear in the translation table.

### Native capture index

The filename stem identifies the state and dimensions. Original PNGs were
captured under `/var/tmp/native-ui-r0.BbOvHT/gui/` on 2026-11-10. Raw screenshots
and fixture data are local evidence.

| Capture | Observed state |
| --- | --- |
| `native-empty-1280x800.png` | No selected thread, project sidebar and centered hero |
| `native-conversation-1280x800.png` | Selected saved thread, collapsed work group |
| `native-commands-1280x800.png` | Expanded two-command work group and assistant prose |
| `native-command-output-1280x800.png` | Click-through to one bounded output viewer |
| `native-thread-actions-1280x800.png` | Selected-thread action menu |
| `native-review-target-1280x800.png` | Review target dialog |
| `native-cold-review-failure-1280x800.png` | Cold saved thread review reached stock error `-32600` |
| `native-review-running-1280x800.png` | Review banner and stop control after explicit resume |
| `native-review-result-1280x800.png` | Warm review completed through the bundled Host and stock |
| `native-sidebar-collapsed-1280x800.png` | Collapsed wide sidebar and retained conversation |
| `native-conversation-720x800.png` | Same selected thread and expanded activity after resize |
| `native-sidebar-720x800.png` | Compact Threads pane with selected thread retained |

The Review dialog and its direct action currently gate on a materialized
thread. A saved thread can be materialized but cold in the current stock
process. The dialog accepted the review target and stock returned
`-32600 thread not found`; the same target completed after explicit sidebar
Resume. This reproduces the [cold RPC contract](THREAD_PROVIDER_RESUME_PRESENTATION_EVIDENCE.md)
in the packaged UI. Keep the failure separate from the structural comparison.
Any correction must preserve the existing queue admission rule before resume.

## R0 baseline translation table

The Native column describes the pre-translation `9db67e5` baseline. The
[implementation checkpoint](#native-implementation-checkpoint) records the
translated surfaces and remaining comparisons. Rows with only static or
public evidence still need live verification.

| Surface | Official evidence | Native baseline and status | Translation and files | Verification |
| --- | --- | --- | --- | --- |
| App/window shell | H1 top controls precede rail and shared page. S1/S2 separate application menu, workspace row and surface. | **DIVERGED**. GTK owns window chrome. Flutter starts with sidebar plus inset conversation, and puts its titlebar key in the sidebar. | Put app actions above the page at the shell level. Give sidebar and workspace a shared page boundary. Keep platform window ownership. `app_shell.dart`, `sidebar_activity.dart`, geometry test. | Compare client and decorated window regions separately at one scale. |
| Global navigation | H1 independent rail and selected Home. S1 supports rail with contextual sidebar. | **MISSING**. One Thread panel carries all navigation. | Give supported destinations a persistent rail. Translate selection and focus from observed behavior. `app_shell.dart`, `sidebar_activity.dart`. | Compare rail and sidebar, collapse/expand and keyboard focus. |
| Codex sidebar | H1 product menu, two header actions, then New chat, Dot and Projects. | **DIVERGED**. Brand/collapse, New thread/location, ecosystem, then Threads command row. | Move collapse to shell chrome. Place equivalent sidebar controls by role and keep Native extensions secondary. `sidebar_activity.dart`. | Compare order, row state and reachability. |
| Projects | H1 Projects label and folders above indented threads. | **PARTIAL**. Folder groups share a bounded catalog with saved/section modes. | Recompose the default Projects group before changing optional scopes. `sidebar_activity.dart`. | Two projects, expanded/collapsed and preserved bounded paging. |
| Threads | H1 selected indented row, truncating title and right status. | **PARTIAL**. Rows add branch metadata and hover actions. | Translate the primary row and move extra operations to verified secondary positions. `sidebar_activity.dart`, `codex_sidebar_row.dart`. | Default, selected, hovered and busy rows at comparable width. |
| Workspace header | H1 folder and title, right action group. | **DIVERGED**. Title plus pills and primary detail segment. | Translate folder/title and action zones. Keep diagnostics/details reachable. `conversation.dart`. | Long title, selected row correspondence and retained actions. |
| Empty workspace | S2 separate page, content and toolbar slots. H1 is active. | **PARTIAL**. Centered hero, suggestions and composer. | Verify current empty Codex before moving hero or composer. `conversation.dart`. | Signed-in empty then Native at comparable viewport. |
| Active conversation | H1 header, prose/activity scroll area and bottom stack. | **PARTIAL**. Same broad areas with a different view switch and stacking. | Keep virtual timeline and measured bottom stack. `conversation.dart`. | Active/completed, streaming and scroll continuity. |
| User message | Historical bubble measurements. H1 has no user bubble. | **PARTIAL**. Right-aligned bounded bubble with attachments and actions. | Measure current placement and attachments. `conversation.dart`, `codex_message_bubble.dart`. | Two-turn capture with multiline prompt and synthetic attachment. |
| Assistant prose | H1 left-aligned prose in the reading column, distinct from inline activity. | **PARTIAL**. Left Markdown in bounded virtual timeline. | Preserve rendering and lazy history, translate verified bounds. `conversation.dart`. | Compare prose and code line lengths, scroll and stream. |
| Thought | H1 inline low-emphasis running thought text. | **PARTIAL**. Reasoning and working labels depend on detail mode. | Translate inline status for the matching event. `conversation.dart`. | In-progress and completed disclosure states. |
| Command/tool activity | H1 borderless read/run summary with leading glyph. | **DIVERGED**. Saved work group discloses bordered cards and output dialog. | Translate collapsed hierarchy. Verify expanded placement and preserve lazy output. `conversation.dart`, `diff_approval_output.dart`. | Command-heavy capture, expand, load output on demand. |
| Diff and changes | H1 change summary above bottom stack. Public guide describes review pane. | **DIVERGED**. Diff selection replaces timeline. | Translate summary affordance and verify open pane before changing the host. `conversation.dart`, `diff_approval_output.dart`. | Closed/open disposable Git diff and per-file loading. |
| Review mode | Public guide documents `/review` and review pane. H1 is outside Review. | **PARTIAL**. Target dialog, running banner and result. | Verify current target/running/result states. Keep typed stock Review and safe admission. `conversation.dart`. | Compare targets and lifecycle, verify cold/warm Host requests. |
| Composer | H1 bottom surface, attachment plus left and model/permissions/voice/stop right. | **DIVERGED**. 704 px max, multiline and model/execution at left. | Translate grouping and placement, preserve draft, attachments and execution bindings. `conversation.dart`, `codex_composer.dart`. | Empty, multiline and running, then keyboard send/stop. |
| Menus | H1 shows application menu and context triggers; S1 has app menu slot. | **PARTIAL**. Local menus, no Flutter app strip. | Place triggers by verified owner, verify contents separately. `app_shell.dart`, `sidebar_activity.dart`, `conversation.dart`. | Open menus, keyboard and dismiss. |
| Popovers | H1 shows closed product/model triggers. | **PARTIAL**. Anchored overlays for thread and model actions. | Match verified anchors and open grouping. `conversation.dart`, `codex_popover.dart`. | Open capture, outside click and Escape. |
| Dialogs and questions | H1 turn question card above composer with reply/actions. | **PARTIAL**. Separate question banner, modal management dialogs. | Compare question host and keep management overlays scoped. `conversation.dart`, `diff_approval_output.dart`. | Matching question/approval, focus and dismiss. |
| Compact layout | S1/S2 rail/left panel variants and compact gutters. | **PARTIAL**. Threads/Conversation switch at 760 px with Offstage. | Verify current narrow order. Retain one conversation, selection and draft. `app_shell.dart`. | Native and official at narrow viewport with active thread. |
| Responsive transition | S1 resizable left panel and separate visible width. H1 is one viewport. | **PARTIAL**. Fixed 260 px, explicit collapse and compact switch. | Establish official resize/collapse thresholds and persisted width. Preserve state. `app_shell.dart`, geometry tests. | Cross thresholds with draft, attachment, focus and scroll anchor. |
| ChatGPT-specific destinations | H1 application rail. Official guide separates ChatGPT and Codex. | **NOT_APPLICABLE**. Native has a local Codex backend. | Translate Codex equivalents. Native extensions stay secondary. | Check every visible action reaches a supported destination. |

The [official review guide](https://learn.chatgpt.com/docs/code-review?surface=app)
supports workflow claims. H1 and current bundle evidence establish R1's
shell hierarchy. Empty, expanded activity, open review and narrow signed-in
layouts still need direct comparable captures for their respective slices.

## Native implementation checkpoint

| Slice | Change | Evidence |
| --- | --- | --- |
| R1 | `8ce73dd` and `5dc63ca` add app-wide File/View actions, the persistent navigation rail, a shared rounded page, and a collapsible contextual sidebar. GTK owns the platform window frame. | Packaged Linux comparison against the previous Native shell at 1191×865 and 720×800. The rail and its ecosystem action stay reachable with the sidebar collapsed. |
| R2 | `fe31e9e` moves search and New chat into the Codex sidebar, groups projects below, and places the folder and selected title opposite trailing actions. Detail mode moves to an anchored menu. | Packaged selected-thread comparison and geometry tests, including 780×800. An initial 0.8 px header overflow led to the detail menu placement. |
| R3 | `3e388fe` makes routine activity inline, aligns saved-work disclosure with the reading column and moves the bounded change summary above the composer. | Packaged turn through the bundled Host and stock app-server with a loopback model fixture. The app displayed real command activity, a disposable Git file change, and the opened per-file diff. |
| R4 | `d836c16` uses the current 672 px reading and composer cap. The active desktop composer puts attachment and input on the left and model, execution and send/stop on the right. | Geometry, keyboard and action tests plus packaged wide, running and compact draft states. Clicking Stop in the packaged app produced the stock interrupted state. |
| R5 | `466cda5` applies the existing cold queue admission to both Review entries. If saved work may run, the explicit confirmation resumes the thread and leaves Review for a separate action. | The pre-fix cold attempt returned `-32600`. The fixed Linux bundle opened and completed a working-tree review from a fresh stock process without a manual sidebar resume. Three simulated cases cover queue safety, resume failure and draft retention. |
| R6 | `c3ac6f0` adds drag, keyboard and accessibility actions for a 290–520 logical px total left area, while reserving 240 px for the workspace. Narrow activity labels are bounded. | A 760 px split test with the sidebar at maximum first exposed a 40 px overflow. The corrected geometry passes. Linux 1191→760→720→1191 retained the selected thread, draft and resized width. |
| Peer follow-up | `73f48f3` keeps the return action visible when an open diff becomes empty, and shows an icon-only review link trigger in a tight split. | The peer identified both issues from the actual diff. Simulated runtime tests cover empty diff exit and an in-viewport popover with multiple links at the 240 px workspace minimum. |

The independent `agy` peer evidence is `fdc181a` and `65380cd`. The reference
comparison uses H1's visible hierarchy alongside the current bundle's layout
roles. The Native 1191×865 captures have DPR 1. H1's unknown scale precludes a
pixel overlay claim. The local evidence directory includes
`r1-shell-comparison.png`, `r3-live-comparison.png`, `r4-composer-states.png`,
`r5-fixture/shell-r5-real/`, and `r6-resize-states.png`. These Native captures
contain disposable fixture data. H1 itself is excluded from the repository.

The official bundle has a responsive branch below 768 px. Native retains its
existing 760 px transition and one live conversation state. Native sidebar
width is session-local. The current bundle registers Changes as a right-side
task tab. Native translates this with a side pane above a 960 px workspace and
keeps its existing timeline replacement view below that width.
[Open Changes evidence](../RESEARCH.md#desktop-secondary-surface-follow-up)
At narrow split widths the active steering field can use its own row while
model, execution and Stop controls remain available. A known cold queue now
asks for explicit resume before the review target chooser. The interaction
choices remain open for Human feedback.
The app menu covers supported Native actions, and the rail exposes only wired
destinations. Completed live and saved commands in Desktop Commands and
Execution share one bounded inline output preview, with the complete stored
output still reachable through
the paged dialog. [Inline output evidence](../RESEARCH.md#desktop-inline-command-output)
Comparable signed-in official captures are still needed for
empty Home, expanded activity, open review/diff, model and execution popovers,
questions and approvals, compact navigation, and dark mode. The user has
supplied a wide official reference. Human evaluation of the new Native window
remains open.

## Wide Desktop visual parity ranking

This pass compares H1 with Native at 1191×865 and DPR 1, with build `25894`
used for logical dimensions and component roles. The captures use different
thread content and H1 has unknown zoom and sidebar preference. The comparison
uses aligned regions and states where observable. A physical-pixel overlay or
matching empty Home, expanded activity and open Changes comparison remains
unverified.

| Rank | Official evidence | Native at `6b6ea9f` | Difference and impact | Measured or observed basis | Likely Native files |
| --- | --- | --- | --- | --- | --- |
| 1. Project thread density | H1 shows indented, single-line threads with a right-side spinner and a branch-shaped indicator on different rows. Build `25894` defines a 36 logical px navigation row. | The 36 px thread rows add a separate strip whenever Git metadata is present. | A repeated `main` label gives routine rows a second line and separates threads from their project headings. This changes the density of the entire panel. | The wide Native fixture shows Git strips on all three ordinary threads across two projects. H1 shows no separate strip on its visible threads. | `sidebar_activity.dart`, `codex_sidebar_row.dart` |
| 2. Pending question surface | H1 shows a neutral outlined card above the composer, a muted question glyph and a distinct reply area. | The equivalent pending request uses an accent-tinted surface and border. It also supports typed choices, as seen in the stock fixture. | The tint makes the question dominate the workspace as a colored notification. The pending request should read as an interactive part of the conversation stack. | Compare H1 and the Native wide pending stock request. H1 shows a free-text question, so option geometry and action semantics cannot be inferred from it. | `user_input.dart`, `conversation.dart` |
| 3. Workspace title and actions | H1 shows a folder and thread title on the left and a separate right action group. | Native places an empty `Linked PRs` pill beside the title and may show a token usage pill there when an update arrives. | Persistent secondary chrome competes with the thread title and reduces its available width. | Native active and restored captures show the empty PR pill. The running fixture also shows usage. H1 does not establish the official states with an actual linked PR. | `conversation.dart` |
| 4. Inline activity grouping | H1 shows a compact read/run summary with a leading glyph and a quiet live thought. | Native has inline live commands and bounded disclosure, with saved work headed by a generic `Worked for …` line. | The live and saved summaries use different visual groupings, so a command-heavy conversation is harder to scan as one timeline. | Native live command and saved history captures establish both variants. H1 shows a collapsed running summary. Expanded and completed official variants still need matching evidence. | `conversation.dart`, `diff_approval_output.dart` |
| 5. Home hero and project selector | S3 separates Codex Home from the new-thread placeholder and places the project control within the selected-project heading. | Native's connected Home has a mark, a standalone heading and a separate project-selector row over its composer. | The additional row changes the primary Home hierarchy before the user types. | The Native Home capture and S3 show different component placement. H1 is an active thread. Signed-in Home spacing and gating remain open. | `conversation.dart` |

The first pass moves Git context to the existing row tooltip. Pin and goal
indicators, unread states and row actions retain their existing behavior.
Packaged Linux captures of the same sidebar fixture show the gap between
ordinary thread centers falling from 54 to 36 logical px. The second project
is 36 px higher after its two predecessors lose their branch strips. Hovering
the second thread in the release app displayed `Git · main` and kept its row
actions visible. The branch search still uses the same thread metadata.

The second pass gives the pending question the neutral theme surface and
outline observed in H1, while keeping the existing response controls. The
paired 1191×865 Linux release captures use the same choice request. The
bundled Host and stock app-server presented the question, accepted the
selected response, and returned the next assistant message. A separate
empty-options fixture completed without showing a question, so it does not
verify the H1 free-text workflow. Native free-text and private answers retain
their simulated product coverage.

The official `agy` peer ranked the command-heavy surface next after seeing
the dark Native preview. Independent readback of `225284.63835849b6.js`
module `PuGl` confirms a rounded bordered shell block with a theme-adaptive
surface, a command line and a `max-h-36` output scroller. This is static
evidence for the expanded component. H1 shows only collapsed activity. The
third pass uses an elevated neutral surface for the existing 144 px Native
preview and groups its byte-window status and full-output action inside it.
The raw command stays in the existing activity row. The Native release
opened the 4,096-byte live preview and the first and last windows of the
179,835-byte Host spool while the turn was still active. It also reopened
Changes at 1450×865 with the conversation and a real one-file patch visible
side by side. Matching signed-in official expanded captures remain open.

The next wide comparison has direct evidence for two separate issues. The
`309406.5b468e9851.js` composer context-usage component draws a small ring,
visible in H1 near the model controls. Native still places the full numeric
usage in the workspace header. The peer also identified the permanent
left-gutter user message action strip. The current bundle places the actions
under the user bubble and reveals them on hover or focus. Header/composer
placement has matching H1 evidence. The message-action comparison uses the
bundle because H1 has no user bubble.

The fourth pass moves the wide Desktop context indicator into the composer,
before the model control. The native tooltip keeps the total, input, cached,
output, reasoning and last-turn token counts. Two packaged Linux captures
using stock token-usage updates show the numeric header badge before the
change and a composer ring with its 10% tooltip after it. The percentage
differs between the captures because the second fixture turn adds tokens.
Narrow composer controls keep their existing width budget. The separate
Linked PRs entry in the title area remains visible.

The fifth pass uses `ZlsN/tH` and its `tW` trigger to move the project chooser
into the Home heading. Native uses one selected-directory phrase and retains
its own mark and existing directory dialog. The paired Native releases show
the separate project row before and the inline dotted control after. At
1191×865, Shift+Tab and Space opened the chooser, and confirming a different
directory retained the draft. The first Return sent to the focused button
in the isolated X11 walkthrough did not open it. The existing Flutter
keyboard test exercises Enter and the real dialog accepted Return to submit.
The initial inline implementation scaled the project label twice and pushed
the model control out of the visible 760 px viewport at 200% text size. Using
the inline span's own scaling preserves the effective hit target. The fixed
760×800 release capture shows the model and execution controls.
