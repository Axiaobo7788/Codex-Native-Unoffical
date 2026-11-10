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
| A3 Project/thread rows | H1 shows indented single-line titles, selected fill and a trailing live spinner or Git indicator. Build 25894 module `cSic` in `384375.45e1f0cefc.js` replaces timestamp metadata with running status and swaps the status for actions on hover/focus. | N1 paired captures show 54 → 36 logical px pitch and Git branch context on hover. The latest release captures a neutral spinner on the running stock row at rest and its menu in the same slot on hover. | `fe31e9e`, `9bff30d`, `9785c1a` | Idle timestamp and unread placement still differ. The branch-shaped H1 icon needs a verified data mapping. | PARTIAL | Confirm idle indicator priority and the source of the PR-shaped indicator before mapping existing linked-PR data. |
| A4 Shared page/surface geometry | H1 puts sidebar and workspace inside one rounded surface. S2 has a 340 logical px default left panel, 52 px rail fallback and 42 rem content cap. | N1 and geometry tests show a single page with 52 + 288 px default, a resizable sidebar and 672 px reading/composer cap. | `5dc63ca`, `d836c16`, `c3ac6f0` | H1 physical positions depend on zoom and sidebar preference. Native's supported wide geometry follows the same logical roles. | PARITY_ACCEPTABLE | Preserve the dimensions for this state. Measure official logical gutters and resize persistence when a matched signed-in window is available. |
| A5 Workspace header | H1 has a folder and selected thread title opposite separate actions, including a trailing panel control. S2 defines a trailing toolbar. | N1 groups folder/title and a separate action cluster. Linked PRs moved into that cluster and runtime/context telemetry moved out. | `fe31e9e`, `0e19880`, `48b95f4` | Native search/detail/PR action order and available side-pane control still differ. | PARTIAL | Trace the 25894 trailing action slots and bind the existing search, menu and panel controllers to matching roles. |
| A6 Conversation reading/prose | H1 shows left reading-column prose with quiet inline events. S2 sizes the column; `225284.63835849b6.js` module `y5H2` supplies right user-bubble actions on hover/focus. | N1 has virtualized bounded history, left Markdown and right user bubbles with actions below on hover/focus. | `d836c16`, `650c721` | Prose rhythm, inter-item spacing and attachment/multiline variants have no matched comparison. H1 contains no user bubble. | PARTIAL | Extract the current prose/timeline class spacing and compare line breaks and vertical rhythm with neutral fixture text before altering typography. |
| A7 Thought/activity/read-run | H1 shows a quiet thinking line and borderless read/run summary. In `225284.63835849b6.js`, `NKAf` distinguishes read/search/list/run and `getw` supplies the completed-turn disclosure with a right-to-down chevron, secondary label and hairline beneath it. | N1 shows a mixed live read/run row in Commands. A fresh release opened a stock saved turn with the right-to-down chevron, muted label, two command rows and thought before the final answer. | `388147a`, `0a0f79c` | The saved duration label and disclosure state have current official precedent. The duration-free fallback, exact expanded activity grouping and quiet live thought remain open. | PARTIAL | Trace the completed-turn call sites and live thinking state. Compare the official expanded group when available. Keep details and command output lazy. |
| A8 Closed Changes affordance | H1 x705–911 shows a centered chip with counts. `34052.444925845b.js` `eR` mounts the active summary through `ovhK`, which sets the elevated surface, 12×6 px padding and 20 px default corner token from CSS. `Bj1J` supplies the count and Changes action. | The release shows the translated outline/surface and one-file +80/−0 label after the stock diff snapshot arrives. Opening the pane at 1450×865 displays the actual patch beside the timeline. | `155ea2f`, `f31239e` | The in-progress stock capture had a file-change activity item and no summary yet. The completed capture has the summary. The official timing and hover list are distinct from the open pane in D. | PARTIAL | Compare when the supported stock diff becomes actionable in a running turn. Verify the official hover slot before adding bounded per-file disclosure. |
| A9 Selected Goal | H1 shows status, clipped objective, elapsed and trailing clear, resume and expand-style icons. Build 25894 `Ceox` orders the actions. `ThreadGoalSidePanelTab` in `725496.2b985984cc.js` opens in the right task panel by default. | The release shows the three actions with a paused Goal and pending request, edits the objective in a right pane at 1191×865, restores focus after Save, closes on Escape and submits the pending stock answer. | `09037a2`, `e5bbfed` | Native retains confirmed clear per its local Goal contract. The editor uses a full reading surface when the side panel and chat cannot fit. Native elapsed is the recorded value rather than the official active clock. | PARTIAL | Translate the selected active elapsed display and compare the status variants. Check the editor against a matching official open state when available. |
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

The peer confirmed the default right task panel and challenged the initial
running-row composition. The Native Goal editor uses the measured right
panel width formula when 320 px of pane and 352 px of chat fit. The current
official shell also has a conditional 960 px resize coordinator. This is
separate from the Goal tab's open route. The first packaged save persisted the
objective and left Escape ineffective after focus dropped. The corrected
build restored editor focus, closed on Escape, delivered the pending answer
and read back the edited paused Goal from disposable stock storage. A widget
test carries one draft across the inline/split transition.

The `9785c1a` build captured the stock running thread while the question was
pending. Pointer hover replaced the spinner with its menu. Moving away
restored the spinner. The answer reached stock and all three processes exited.
The saved activity release opened a completed stock turn with two commands
and one thought. The Changes release showed one file and +80/−0 after the
turn and opened the real patch in the side pane. The earlier in-progress
capture retains the distinct file-change activity with no actionable snapshot.

The combined source passed 515 default Flutter tests, five isolated opt-in
stock tests, 100 Rust tests, Clippy, formatting, the 65-root Dart boundary
check and clean ASCII-path analysis. The bounded-history benchmark retained
100 of 1,000 turns, and the Linux release passed its bundle closure check.
Hosted CI passed on the preceding `927d64e` checkpoint.
[Hosted run 42889063481](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42889063481)

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
