# Official Desktop to Native structural mapping

This map applies [ADR-041](../DECISIONS.md#adr-041--current-official-ui-evidence-is-a-translation-contract) and the [translation plan](OFFICIAL_UI_TRANSLATION_PLAN.md). It compares the connected Codex experience on the installed Linux renderer with Native. The desktop app's other product experiences have separate backends. The [official desktop guide](https://help.openai.com/en/articles/20001275-chatgpt-work-and-codex) confirms a product menu, but gives no Linux geometry or navigation hierarchy.

## Current official evidence

The target is the Codex layout shown in the user's signed-in Linux window.
The installed Linux package is `codex-desktop 2026.11.08.211600-1`, with
renderer `26.1103.60933` build `25894` and ASAR SHA-256
`121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`.
These are the locally examined build identifiers. The screenshot itself has
no build or DPR metadata usable to infer logical layout units.

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

## Translation table

Status describes the stated evidence and Native structure. Rows with only
static or public evidence still require the named live verification before
their final placement can be accepted.

| Surface | Official evidence | Current Native and status | Translation and files | Verification |
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
