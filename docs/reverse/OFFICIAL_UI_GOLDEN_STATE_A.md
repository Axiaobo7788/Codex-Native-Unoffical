# Golden State A — Signed-in active Codex conversation

This is the current Desktop parity contract for the wide, light, active
conversation. The comparison starts at Native
`70a12da3ee106eeb7dae70d5554b46a904350095`. The commit column identifies
the implementation of each row within the assessed tree. The historical
[structural map](OFFICIAL_UI_STRUCTURAL_MAPPING.md) preserves how the screen
got here.

## Evidence boundary

- **H1** is the user's signed-in 1191×865 capture. It shows the actual
  navigation branch, bottom stack and paused Goal. It has no usable logical
  scale or sidebar preference metadata. Personal content stays outside Git.
- **25894** is the installed `26.1103.60933` renderer, ASAR SHA-256
  `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`.
  S1/S2 in the structural map identify the shell modules and CSS. Static
  variants can establish component structure. Their existence alone does
  not establish which variant or capability a signed-in window enables.
- **N1** is the Native Linux release at `70a12da`, exercised at 1191×865,
  DPR 1, against the bundled Host and stock `0.167.0-alpha.3.2` with
  disposable projects and a deterministic loopback model. It includes
  running read/run activity, a paused goal, a pending choice question,
  and captures of Home, command output and open Changes. The accountless
  official live run reached sign-in. Neither it nor N1 reproduces H1's
  signed-in free-text/voice branch. Region and role comparisons are valid
  for the shared states. Pixel overlays and account-dependent interactions
  need comparable captures.

## Current matrix

| State | Official evidence | Native evidence | Native implementation | Known delta | Status | Next machine-actionable correction |
| --- | --- | --- | --- | --- | --- | --- |
| A0 Application/window strip | H1 y0–50 has back/forward, sidebar toggle, File/Edit/View/Help and window controls. S1 separates the app menu from the content surface. | N1 and `app_shell.dart` show a shared Flutter File/View strip under the GTK frame. | `8ce73dd`, `5dc63ca` | Menu set, control order and frame split differ. | PARTIAL | Inspect the 25894 application menu and history actions. Map supported menu/shortcuts and compare the decorated and client regions separately. |
| A1 Global navigation rail | H1 x0–60 has selected Home, an upper destination cluster and separated lower controls. S1 selects rail plus contextual sidebar. | N1 has the persistent rail with Home and ecosystem, and Remote and Runtime details in its lower cluster. | `8ce73dd`, `373305e` | Native shortcuts occupy different roles and positions. H1 shows additional account-backed destinations. | PARTIAL | Classify each current rail slot by capability. Translate supported destinations and their selection/focus behavior, and record separately any role without a supported backend. |
| A2 Contextual Codex sidebar | H1 starts with product, notifications and search, then New chat, Your Dot and Projects. S1 contains product-specific sidebar slots. | N1 and `sidebar_activity.dart` place New chat and search above the bounded project catalog. The connected footer moved to the rail. | `fe31e9e`, `373305e` | Header and action grouping still differ. Dot and notifications depend on account services. | PARTIAL | Read the exact sidebar header variant, place backed controls in the equivalent groups, and keep unsupported destinations out of the wired route. Verify the open product menu independently. |
| A3 Project/thread rows | H1 shows indented single-line titles, selected fill and a trailing live spinner or Git indicator. Build 25894 module `cSic` in `384375.45e1f0cefc.js` uses a trailing status/indicator slot with separate hover actions. | N1 paired captures show 54 → 36 logical px pitch and Git branch context on hover. The `5b8ef6a` release shows the stock active thread's neutral spinner at the far end, beyond the selected-row menu. Idle, unread and error treatment stays available. | `fe31e9e`, `9bff30d`, `5b8ef6a` | Idle metadata and the selected action visibility still differ. The branch-shaped H1 icon has not been mapped to a verified Native field. | PARTIAL | Compare the current local row's idle and hover slot priority and map the branch/PR icon only after establishing its real data source. |
| A4 Shared page/surface geometry | H1 puts sidebar and workspace inside one rounded surface. S2 has a 340 logical px default left panel, 52 px rail fallback and 42 rem content cap. | N1 and geometry tests show a single page with 52 + 288 px default, a resizable sidebar and 672 px reading/composer cap. | `5dc63ca`, `d836c16`, `c3ac6f0` | H1 physical positions depend on zoom and sidebar preference. Native's supported wide geometry follows the same logical roles. | PARITY_ACCEPTABLE | Preserve the dimensions for this state. Measure official logical gutters and resize persistence when a matched signed-in window is available. |
| A5 Workspace header | H1 has a folder and selected thread title opposite separate actions, including a trailing panel control. S2 defines a trailing toolbar. | N1 groups folder/title and a separate action cluster. Linked PRs moved into that cluster and runtime/context telemetry moved out. | `fe31e9e`, `0e19880`, `48b95f4` | Native search/detail/PR action order and available side-pane control still differ. | PARTIAL | Trace the 25894 trailing action slots and bind the existing search, menu and panel controllers to matching roles. |
| A6 Conversation reading/prose | H1 shows left reading-column prose with quiet inline events. S2 sizes the column; `225284.63835849b6.js` module `y5H2` supplies right user-bubble actions on hover/focus. | N1 has virtualized bounded history, left Markdown and right user bubbles with actions below on hover/focus. | `d836c16`, `650c721` | Prose rhythm, inter-item spacing and attachment/multiline variants have no matched comparison. H1 contains no user bubble. | PARTIAL | Extract the current prose/timeline class spacing and compare line breaks and vertical rhythm with neutral fixture text before altering typography. |
| A7 Thought/activity/read-run | H1 shows a quiet thinking line and borderless read/run summary. Module `NKAf` in `225284.63835849b6.js` distinguishes parsed read, search/list and generic commands. The same chunk defines `Worked for {time}` and a previous-message count for one completed-turn divider. | N1 shows a mixed live read/run row in Commands. Execution exposes both raw commands and thought. Saved groups use `Worked for …` or `Turn details`; outputs stay lazy. | `3e388fe`, `2d2529a`, `388147a` | The duration label has current official precedent. The completed disclosure structure, duration-free fallback and quiet live thought still need an active-branch mapping. | PARTIAL | Trace the divider call sites and match the running and saved branches before changing labels or composition. Keep saved items and output lazy. |
| A8 Closed Changes affordance | H1 x705–911 has a centered bordered pill with file count and colored counts. S2 puts Changes in a task side tab when opened. | N1 and `_desktopChangesSummary` use a centered outline, file count and colored additions/deletions. Wide split preserves the timeline when opened. | `3e388fe`, `155ea2f` | Closed pill size/typography and open-state control placement still need current CSS/readback. D owns the open pane. | PARTIAL | Locate the exact closed component token/spacing and compare a one-file +80/−0 Native capture. Keep file/hunk reconstruction in D. |
| A9 Selected Goal | H1 shows status, clipped objective, elapsed and trailing clear, resume and expand-style icons. Build 25894 `309406.5b468e9851.js` module `Ceox` orders clear, pause/resume, edit and routes edit to `ThreadGoalSidePanelTab`. | A clean Linux build of `09037a2` shows those three actions with the stock paused goal above the pending choice. The release opened clear confirmation and the edit dialog and submitted the pending stock question. | `70a12da`, `09037a2` | Stock status writes are direct. Native retains confirmed clear per its local Goal contract. Native still opens a dialog for edit. Active elapsed rendering and terminal-status visibility differ. | PARTIAL | Translate the verified Goal side-tab editor and recheck its wide routing and selection lifecycle. Compare the remaining status variants and retain the clear confirmation. |
| A10 Pending question/request | H1 shows Question, dismiss, Reply with voice, Skip and Send. The matching strings and controls occur in `42793.61ccb40e22.js` module `qMAt`. `Ceox` routes this branch as `send_user_message_async_question`. It separately mounts the request-input panel through `zVqR`. | N1 has the neutral request stack and choice submit through the bundled Host. Native handles stock `item/tool/requestUserInput`. The 0.167.0-alpha.3.2 experimental schema includes that request and no async-question contract by the renderer's names. | `3899c23`, `515d283`, `5769e31` | H1 and the Native fixture exercise different runtime paths. The accountless stock empty-options probe produced no visible question. | PARTIAL | Compare the supported stock request with the official request-input panel. Track the H1 async branch as evidence-blocked until a supported runtime contract is established. |
| A11 Composer/control grouping | H1 has add on the left; usage, model/reasoning, execution, microphone and Stop on the right. `309406.5b468e9851.js` defines the context ring. | N1 shows add, draft, right model/execution/Stop and context ring. Keyboard, resize and stock interruption evidence exists. | `d836c16`, `48b95f4`, `fd4ebe1` | Closed control treatment, focus and open popovers remain open. Voice lacks verified supported runtime evidence. | PARTIAL | Identify the active composer toolbar and popover anchors. Compare the enabled controls and states with the matching running request. Track voice support separately. |

`MATCH` requires current same-state evidence. `PARITY_ACCEPTABLE` records
an evidenced equivalent with a bounded known delta. `PARTIAL`, `DIVERGED`
and `MISSING` retain the next concrete correction. `EVIDENCE_BLOCKED`
names the evidence a specific state requires. `HUMAN_REVIEW_PENDING` applies
to remaining subjective differences after machine-actionable discrepancies
are addressed. Golden State A remains active in `SELF_ITERATION`.

## A9 release evidence

The official agy peer independently identified the `Ceox` action order,
direct status mutation and Goal side-tab registration. The initial
incremental Linux build updated its AOT library but retained the previous
Material icon subset. Its capture showed wrong or missing glyphs. A clean
ASCII-path source build regenerated the icon font, showed the target, trash,
play-circle and expand glyphs, and passed analysis. The release fixture
used a disposable paused Goal and a real stock choice request. Clear
confirmation was dismissed, the editor opened and closed, the request
response reached the loopback fixture, and the app, Host and stock child
exited. The 515 default Flutter cases passed with five opt-in cases skipped.
The release screenshots contain only disposable fixture data and stay
outside Git, alongside the separate private H1 evidence.

The subsequent `5b8ef6a` build exercised the running-row slot while the same
stock question was pending. The release captured the neutral spinner to the
right of the selected menu. The fixture submitted a response and the process
tree exited. Nine focused simulated integration cases passed across the
active-resume, read-receipt and Goal paths.

## State order and evidence gates

Close evidenced A rows together before taking new presentation work.
For each row, refresh official evidence through the peer session, map the
component, translate it, run the same Native state, compare, and update
this matrix. Existing bounded history, output/diff windows and controllers
remain the runtime owners.

| Next state | Independent evidence gap |
| --- | --- |
| B Signed-in Home | Static selected-project hero exists. Signed-in branch placement and gating need confirmation. |
| C Expanded activity/command | Expanded command CSS and Native bounded preview exist. Exact saved/completed disclosure and matching expanded hierarchy remain open. |
| D Open Changes | Right-side task-tab registration and Native real one-file split are verified separately. File/hunk and toolbar structure need the active official variant. |
| E Review | Stock review is functional. Chooser, running state and result need current official comparison. |
| F Compact | Native state continuity is exercised. The active signed-in official narrow navigation hierarchy remains open. |
| G Dark/focused | Native dark captures and focus tests exist. Current matching official dark, focused request/composer and open popovers remain open. |

Freeze only the individual surface that genuinely lacks evidence. When no
UI state can progress, resume independent functional READY or RESEARCH_MORE
work from the [living queue](OFFICIAL_FEATURE_MATRIX.md). This scheduling
choice preserves the program's SELF_ITERATION stop predicate.
