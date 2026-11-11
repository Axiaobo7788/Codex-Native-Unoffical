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
| A0 Application/window strip | H1 y0–50 shows Back, Forward, sidebar toggle, File/Edit/View/Help and window controls. `499225.mJEk.z` uses the active destination router. `189497` registers keyboard and side buttons. `early-bootstrap-815` defines Edit and Help roles. | Linux release revisits stock threads from the toolbar, keyboard and X11 mouse buttons 8/9. Edit targeted the focused composer and Help handed the documentation URI to the platform handler. | `8ce73dd`, `5dc63ca`, `b6e2e1a`, `b10b27a`, `135e8fb`, `21f7525` | Native history contains thread visits. The Native menu has backed editing roles and four public links. OS frame placement, menu mnemonics and the official-only Help commands differ. | PARTIAL | Compare the decorated signed-in frame and open-menu keyboard/focus behavior across available Desktop platforms. |
| A1 Global navigation rail | H1 x0–60 has selected Home and separated destination clusters. `499225.36a7812ae9.js` `lp/lu/lc` define the rail, scrolling group and footer. `890434.9dbaee449e.js` `GO7r.wdY` resolves to the 20 px Plugins asset. | The release uses the equivalent multi-tile glyph and transfers selection from Home to the existing ecosystem dialog. Escape returns selection to Home without leaving the thread. Remote and Runtime details remain in the lower cluster. | `8ce73dd`, `373305e`, `3a6e846` | Native uses a dialog for Skills, Plugins and MCP. The official destination, configurable ordering and account footer have distinct capabilities. | PARTIAL | Compare the signed-in supported destination and focus transitions. Keep the account and private-service roles separate from Native runtime status. |
| A2 Contextual Codex sidebar | H1 starts with product, notifications, search, New chat, Dot and Projects. `499225.ZIk0/dR` guard the empty Pinned heading and show Projects actions on group hover/focus. `499225.tI/t_/eK` and `236683.V5ob.NF/c6` place the local menu before New chat, keep it visible when open and align it to the trigger start. | Wide Projects reveals actions on pointer or keyboard interaction. View opens the stock-scoped pins catalog. The Linux release created and ran a thread in the second project by keyboard. On a separate stock-backed project it opened the anchored menu and dispatched the exact folder path to the OS handler. A missing folder showed feedback. | `fe31e9e`, `373305e`, `b6e2e1a`, `a3737b9`, `0c45b67`, `a8b2104` | Native groups its bounded loaded threads by directory and exposes only the local folder action in this menu. Official right-click, organize, project metadata and batch actions have distinct behavior or backing. Dot and notifications depend on account services. macOS/Windows launch was not exercised. | PARTIAL | Compare the supported right-click path and signed-in Projects actions. Keep loaded-only operations explicit and track account entries and the product selector separately. |
| A3 Project/thread rows | H1 has indented single-line titles and a trailing spinner or merged-PR glyph. `499225.36a7812ae9.js` suppresses project-list timestamps and floats indicators at the end. `cSic`, `JHLi` and `Kg7g` define the working/unread/PR slot. | Paired stock captures verify 36 px rows, the running spinner, the 8 px blue unread dot and quiet idle titles. Hover swaps the indicator for actions. Scoped and archived views retain recency. | `fe31e9e`, `9bff30d`, `9785c1a`, `8ee189e` | `927552.2a3666383e.js` derives the purple glyph from an actual merged PR state. Native thread attachments carry link identity but lack provider merge state and stay on-demand. | PARTIAL | Verify the supported Git/PR indicators with comparable data. Keep the merged glyph evidence-blocked until reliable state is available. Do not scan attachments for every visible thread. |
| A4 Shared page/surface geometry | H1 puts sidebar and workspace inside one rounded surface. S2 has a 340 logical px default left panel, 52 px rail fallback and 42 rem content cap. | N1 and geometry tests show a single page with 52 + 288 px default, a resizable sidebar and 672 px reading/composer cap. | `5dc63ca`, `d836c16`, `c3ac6f0` | H1 physical positions depend on zoom and sidebar preference. Native's supported wide geometry follows the same logical roles. | PARITY_ACCEPTABLE | Preserve the dimensions for this state. Measure official logical gutters and resize persistence when a matched signed-in window is available. |
| A5 Workspace header | H1 has folder/title, then thread menu, detail control and trailing panel toggle. `446282.FR4w` puts the side-panel action at right order 300 and delegates panel visibility to `ZU27.kO`. | The release has the three trailing roles and opens conversation search through the thread menu. The last control hides and restores the Goal editor with its draft. The draft also survives switching to stock Changes and back. | `0e19880`, `86eed8a`, `dafafba`, `dc7c3ee` | Native retains its linked-PR affordance and a single current Goal draft. It has no general task tab launcher. | PARTIAL | Verify the signed-in menu and simultaneous tab state. Map backed destinations while preserving link management and the bounded reading position. |
| A6 Conversation reading/prose | H1 shows left reading-column prose with quiet inline events. `0040d5ae1a9f.css` uses 1.625 line-height, body-relative heading sizes and line boxes, and two body em of list text inset. `225284.y5H2` and `o7K3` reveal older message actions on hover/focus. `34052` keeps the latest assistant actions persistent. | The stock Linux capture shows old answers without visible copy glyphs at rest. Hover reveals the action in its reserved space. The latest answer remains actionable. Desktop Markdown and streaming prose use the 1.625 line-height ratio. The saved list text starts 27 logical px from the paragraph edge at the default body size. Two stock runs show the translated heading hierarchy with unchanged body glyph widths. A paired stock prose replay confirms the direction and size of the measured root-block gap corrections without changing horizontal text geometry. | `d836c16`, `650c721`, `a8d9e97`, `2a48724`, `67b85ca`, `80d318d`, `f7144df`, `55541ea` | Supported paragraph/list/heading root siblings use the measured collapsed margins. Tight list subtrees use zero extra inter-item spacing. Loose lists, unknown root pairs and outer edges retain their prior spacing. Physical text size and attachment/multiline variants lack a matched comparison. H1 contains no user bubble. | PARTIAL | Measure loose-list paragraph and root-edge margins through the same single-parse renderer. Compare existing attachment types with equivalent official content and retain lazy rendering. |
| A7 Thought/activity/read-run | H1 shows quiet Thinking and borderless read/run. `225284.NKAf` groups exploration and pluralizes runs. `getw` supplies the completed disclosure, `100921.waM8/F9dY` formats duration and `225284.O3Io` supplies expanded exploration captions. | A stock live turn displayed one Read files segment and singular ran a command. A saved turn opens a second collapsed Read files and ran a command group. The group shows typed read, search and list captions plus a generic Ran row. The Linux release restored real output across Execution and Commands, then released the preview on explicit group collapse. | `388147a`, `0a0f79c`, `31d2abd`, `0c8caca`, `f68889c`, `a18b1fa`, `a3bcd98` | The genuinely untimed fallback lacks a collapsed count. Native groups only completed successful commands with a known in-page boundary. Search and Execution retain individual rows. Mixed-tool groups, declined commands, titled reasoning and matched signed-in expansion remain open. | PARTIAL | Compare grouped row density and specialized or declined command captions. Keep count claims bounded by the loaded page. |
| A8 Closed Changes affordance | H1 x705–911 shows a centered count chip. `34052.eR/ovhK` defines its 20 px elevated surface and closed-only gate. `225284.Bj1J.ef/eg` attaches an upper interactive file list while running. | A held real stock reply allowed a two-file +2/−0 preview during the turn. Selecting the second file opened its actual patch. The closed chip is removed when the pane opens. Header close preserves reading position. | `155ea2f`, `f31239e`, `c36da98`, `a983fa9` | Native uses the bounded stock diff snapshot. A keyboard user opens the pane directly. The separate open-pane composition belongs to D. | PARITY_ACCEPTABLE | Retain the stock snapshot gate and keyboard entry. Compare the actual open pane in D once the A screen is closed. |
| A9 Selected Goal | H1 shows status, clipped objective, elapsed and clear/resume/expand icons. `309406.Ceox.tn` routes title and expand through the same visible-tab toggle and retains dirty state while the tab is parked. The `cI4i` rail applies a 13 px inset. | The release confirms the inset and opens the stock editor from title or expand. Save, Escape and request submission were exercised. Switching panes retains an unsaved draft. Explicit Close or a second click on the visible Goal strip closes the tab and returns to the saved objective. | `09037a2`, `e5bbfed`, `fc192ff`, `2c5e8c1`, `02862e4`, `dc7c3ee`, `3505385` | Native confirms clear and uses a full reading surface when both columns cannot fit. The signed-in editor toolbar and terminal status variants remain open. | PARTIAL | Compare editor toolbar, budget and terminal states with the current official tab. |
| A10 Pending question/request | H1 Question, voice, Skip and Send are `qMAt` / `Ceox.t6` async input. For stock, `Ceox.iL → IpGh → vMUJ` displays individual questions and `381170.Qr2V` supplies 20 px choice markers. `42793.vMUJ.L/E/N` initializes the first selection, labels intermediate steps Continue and renders the custom-answer editor. `vMUJ.L` and `100921.Y5qM.Q` put the question and its trailing stepper in one header. | The Linux release submitted two preselected answers through Continue and Submit. The wide Other editor shares the action footer and the typed answer reached stock after an 820×420 resize round trip. A two-step run retained each custom answer and left returned fields unfocused. Separate stock runs submitted alternate choices by click and digit, and used Down with Enter for an option and Enter in Other for text. A separate stock run used both header chevrons and Left/Right, preserved caret navigation inside Other, and submitted both retained drafts under their original question IDs. Another stock run returned from a single-line Other to the last option, retained the draft and kept ArrowUp in the wrapped editor. Two further stock runs interrupted the pending choice and focused Other via Escape. Widget coverage verifies failed-interrupt focus restoration, IME composition, approval and popover priority, timer cancellation and narrow option scrolling. | `3899c23`, `515d283`, `5769e31`, `b32af57`, `2c290b1`, `39bd7ea`, `9402faa`, `8b9fe5c`, `44100f2`, `a142fd0`, `279e476`, `6d26962`, `5fa5eab`, `0e7c46b`, `f772470`, `15e3242` | Native keeps a stacked Other fallback for narrow or enlarged text. Escape interrupts the active stock turn. Native also retains its explicit Cancel request action, which returns a request-scoped error. This stock binary rejects questions without options. H1 async free text and voice remain separate. | PARTIAL | Compare single-question and expanded-text geometry with current official captures. Track H1 async input and the additional Native cancellation affordance separately. |
| A11 Composer/control grouping | H1 has add on the left and usage, model/reasoning, execution, microphone and Stop on the right. `309406` defines the ring. `341692.LUWz` defines the permission control. `104066.dig0 → 209288.vdOM` maps the end-aligned model list and effort slider. `309406.tYeY.Zp → rG` resolves one primary action. `16389.Ips7.C` gives it an 8 px leading gap and the ordinary Electron surface retains its elevation border on focus. | The release opens stock model and Sandbox controls and respects inheritance. A single action changes between disabled Send, Send, Stop and Steer. Keyboard and pointer stop exercised real stock turns. The release kept a stable outline while the editor accepted typing. | `d836c16`, `48b95f4`, `fd4ebe1`, `f8a4d99`, `cedb9e3`, `b14b5d1`, `6c9bc6c`, `e64d1e6`, `fe17af8`, `43e4d35` | Native uses its existing 34 px diameter and 45% disabled opacity. The official ordinary and dictation-enabled branches have different action sizes. Account model bundles, locked tiers and queue/voice variants remain separate. | PARTIAL | Measure the default and dictation-enabled button diameter and multiline footer in the appropriate signed-in branch. Preserve bounded draft and stock inheritance. |

`MATCH` requires current same-state evidence. `PARITY_ACCEPTABLE` records
an evidenced equivalent with a bounded known delta. `PARTIAL`, `DIVERGED`
and `MISSING` retain the next concrete correction. `EVIDENCE_BLOCKED`
names the evidence a specific state requires. `HUMAN_REVIEW_PENDING` applies
to remaining subjective differences after machine-actionable discrepancies
are addressed. Golden State A remains active in `SELF_ITERATION`.

## A2 project-row New chat

The agy peer traced `499225.tI` to Start new chat in the current
project. `499225.eK` separately defines project metadata and batch
actions. Native already starts a stock thread for the displayed
directory. Its first keyboard translation showed New chat when
the row took focus but lost the action when focus moved. Keeping
the control mounted and ordering the row and its action together
preserves focus within the project. The hidden slot ignores pointer
events while remaining reachable by keyboard.

The Linux release tabbed to the second disposable project and then
to its New chat action. Enter created the thread. A model turn ran
through the bundled Host and stock runtime, and the stored session
record verified the second project's working directory. App, Host
and stock exited. The 530 default Flutter cases, format and ASCII
analysis passed. Native still derives projects from loaded threads.
Project metadata, an authoritative all-chats scope and account
destinations remain separate capabilities.

## A2 local project menu

Build `25894` puts the ellipsis before the New chat action and leaves
both visible while the menu is open. `236683.V5ob.c6` defaults to
start alignment. `110557.b38k.S` supplies the platform labels. The agy
peer confirmed the order and identified the initial label and
alignment differences. Native now uses those labels and starts the
popover at the ellipsis left edge. It exposes the folder command on
the wide local Desktop surface for absolute paths.

The packaged Linux app at 1191×865 opened the menu over the second
project's selected stock thread. Down and Enter dispatched the folder
containing a space, a hash and a Unicode character to the disposable
system handler. After that folder moved, the menu reported the
failure and the handler did not run again. The App, Host and stock
processes exited. Widget checks verified ellipsis before New chat,
start alignment, Escape dismissal and keyboard continuation to New
chat. macOS and Windows system dispatch and signed-in official menu
captures are separate evidence gates.

## A6 desktop Markdown list inset

Build `25894` stylesheet `0040d5ae1a9f.css` combines a 1.625 em list
container inset with 1.5 times the quarter-em Markdown space on each
item. The Flutter translation subtracts the bullet padding already
counted by the Markdown widget. At 1191×865 and DPR 1, paired captures of
the same saved stock turn moved both list text edges from x471 to x474
while the paragraph text stayed at x447. Widget geometry verifies the
two-em relation directly. Compact rendering keeps its existing inset.
The Markdown parser and bounded source path are unchanged. Adjacent
paragraph and list gaps still need separate mapping.

## A6 assistant heading hierarchy

The screen CSS in `0040d5ae1a9f.css` gives h1 through h4 font sizes
of 1.5, 1.25, 1.125 and 1 times the body font. Their line boxes are
2, 1.75, 1.75 and 1.5 body em. H5 and h6 use body size and line height.
All six are semibold. The agy peer independently separated those
ratios from the print stylesheet. Native applies them to Desktop
assistant prose and retains the Markdown input cap and parser.

Two Linux releases rendered the same Markdown reply through the
bundled Host and stock runtime at 1191×865. Thresholded glyph widths
for the first three headings changed from 106/94/94 to 123/103/104 px.
The introductory and closing paragraph widths remained 166/160 px.
The widget test checks the effective font and line-box ratios of all
six headings. All 527 default Flutter cases, format and ASCII-path
analysis passed.

The peer checked `flutter_markdown_plus` 1.0.12. Its block spacing
applies to every sibling. The element padding hooks cannot wrap all
container blocks or see following siblings. The official paragraph,
list and heading adjacency still needs a block-aware integration
that retains a single bounded parse. Changing the global gap would
change sibling pairs that already have a different official rule.

## A9 repeat toggle and A10 stock step label

`309406.Ceox.tn` closes the registered Goal tab when it is already visible.
The release opened an unsaved objective, clicked the strip to close and
reopened the saved objective. The header and Changes switches continue to
park the draft. The ordinary question call site `474578.IpGh.to` supplies
submit and Escape actions without a Skip action. `42793.vMUJ.E` shows
Continue on intermediate steps and Submit on the final step. The Linux
release clicked both and the stock runtime returned the two expected
answers to the disposable fixture. H1's async input remains separate.

For this checkpoint, 526 default Flutter cases and five opt-in stock
cases passed. Format, ASCII-path analysis, the pure-Dart gate, bundle
closure and bounded-history benchmark passed. The Linux list capture
exited the app, bundled Host and stock app-server.

## A6 root-block adjacency

The build `25894` screen stylesheet `0040d5ae1a9f.css` defines
a quarter-em Markdown space and normal positive-margin collapse.
An isolated Chromium specimen loaded both installed CSS assets.
At body size 16 px, its measured gaps were 16 px for p/p, 4 px for
p/list, 8 px for list/p, 8 px for h1/p, 4 px for h2/p or h3/p,
8 px for h4/p and 16 px for p/h1. The root list/heading rule also
adds one body em before h5/h6. This is CSS-specimen evidence,
distinct from a signed-in official window.

Native uses the existing Markdown document parser and exported
builder once. It adjusts only the supported root sibling spacers,
retains the code and link handlers and drops the transient AST
after construction. Unknown root combinations keep the existing
builder layout. Streaming and oversized source still bypass the
Markdown parser through the existing bounded text path.

A paired 1191×865 packaged stock replay kept identical horizontal
ink bounds for six prose/list/heading lines. Successive line-top
intervals changed from 29/32/35/30/33 px to 22/29/38/34/26 px.
The −7/−3/+3/+4/−7 px changes match the corresponding gap corrections
after raster rounding. The App, Host and stock processes exited.
All 533 default Flutter tests, five opt-in stock cases, format,
strict ASCII-path analysis and the 83-library Linux closure passed.
Tests include links, code, tables and 2× text scale. Nested list
spacing, unknown root combinations and outer edges remain open.

## A6 tight and nested list flow

The screen CSS gives consecutive list items zero extra margin and
sets nested list margins to zero. Native renders each parsed root
once with a reused standard builder. A second builder and zero-gap
style are created lazily for a tight list subtree. Paragraphs,
headings, quotes, code and table blocks keep that subtree outside
the tight-list path. The AST remains transient, link recognizers
retain their normal lifecycle, and explicit ordered-list starts
are preserved.

Paired packaged stock captures of the same tight/nested list changed
the three internal line-top intervals from 32/32/33 px to 22/22/23 px.
The two surrounding intervals stayed at 22 and 31 px. App, Host and
stock exited. A separate 4,500-character debug widget sample recorded
17 post-warmup builds, with median wall time 252,632 µs before and
221,183 µs after. These are local debug samples. The 534 default
Flutter cases and strict ASCII-path analysis passed. Loose-list
paragraph spacing and root-edge behavior remain open.

## A10 stock choice and custom-answer focus

`474578.IpGh.to` restores a draft only for the matching request.
For a fresh single-select step `42793.vMUJ.L` sets the actual
selected option to the first label. The agy peer confirmed the
initialization and distinguished the separate option-picker RPC.
The Linux release clicked Continue and Submit with no option click.
The loopback received both default labels through stock. Simulated
coverage verifies that changing the selected option takes precedence.

`42793.vMUJ.N` puts the custom editor in the question footer and
clears the active option when the user enters it. The first Native
pass focused the field when the user selected Other. The wide
release now places it directly in the footer with 8 px horizontal
and 6 px vertical insets. The peer found an extra Tab stop in the
initial focus wrapper. A regression verifies one Tab from the last
option reaches the editor. At 1191×865 the field shares the action
row. At 820×420 Native uses the existing bounded scroll area. The
release returned to the wide footer with its draft and the exact
custom answer reached the loopback through stock.
A paired focus test reproduced one shared Flutter FocusNode carrying
focus to the previous question. Native now gives each custom-answer
step its own node. A two-step Linux run typed into both fields, moved
back and forward, and submitted the two distinct drafts. Returned
fields lost their active focus borders. App, bundled Host and stock
exited cleanly. The 528 default Flutter cases, format and ASCII-path
analysis passed.

`42793.vMUJ.L` schedules a 180 ms advance or submit on explicit
single-option activation and cancels it on step change or custom
editor interaction. Native now uses that timing only in the
selected visible Desktop request. Changing thread, entering Other,
or invoking a footer action cancels the timer. A widget test checks
179 ms versus 180 ms, and the Linux release clicked the alternate
choice in both steps without a Continue or Submit click.

The same official choice surface routes digits 1–9, the next digit
for Other, and Enter on the focused card. Native focuses a current
choice card when it can take focus, preserving approval precedence.
Digits inside the editor stay in the editor. A separate Linux
walkthrough used only the digit 2 on both steps and stock returned
both alternate answers. Up and Down now update selection and reveal
the focused option in the bounded question scroll region. Enter in
Other accepts its draft while active IME composition remains with the
editor. The release selected the alternate with Down and Enter, then
opened Other by digit and submitted its text with Enter. The loopback
received both values through stock. At 820×420 the widget test reaches
the eighth option by arrow without submitting. The 529 default
Flutter cases passed. Horizontal step navigation and returning from
Other with ArrowUp remain separate.

The current renderer has a standalone no-options editor. In separate
real stock attempts, both an empty options array and an omitted
options field returned `request_user_input requires non-empty options
for every question`. The simulated standalone autofocus candidate
was withdrawn. The supported Other path and H1's account-driven async
question have distinct evidence.

## A7 live grouping and recorded saved duration

`225284.NKAf` renders one exploration segment and a separate command
segment with singular and plural variants. The Linux release grouped
read, search and list into Read files and showed one run as singular
while a real stock question remained pending. The existing output
preview and Execution detail paths keep their bounded behavior.

In a saved command fixture, stock's summary held equal second-resolution
timestamps and `durationMs: 570`. Native previously showed Turn details.
`225284.getw` delegates known elapsed time to `100921.waM8/F9dY`,
which formats subsecond elapsed as 0s. Native now consumes the existing
optional elapsed value and falls back to timestamps for older responses.
The packaged app showed Worked for 0s, disclosed four commands and
collapsed them again. Simulated coverage asserts one bounded page read
and no detail request before the disclosure. The full 523-case Flutter
suite and ASCII-path analyzer passed.

The same real stock summary held user and assistant messages without
a collapsed count. Its lazy item page included `read`, `search`,
`listFiles` and `unknown` actions. Native retains only one supported
exploration action per item and caps each display field at 240 Unicode
scalars. The peer review identified path-only read and multiline label
variants, now covered by focused tests. Compound or unrecognized commands
retain raw text. The release showed Read counter.txt, Searched for one
in counter.txt, and Listed files after expanding the saved turn. It
opened real read output through the existing preview and switched to
raw Execution. The full 525-case Flutter suite, five opt-in stock cases,
ASCII-path analyzer, bundle closure and bounded-history benchmark passed.

## A7 completed activity group contract

The peer independently traced the build `25894` completed hierarchy.
`225284.QypQ.D/m` places the `getw.i` disclosure before the final
answer. After expansion, `899308.NQNw.c/udV3.rJ` and
`225284.NKAf.D/em` retain a second, initially collapsed group for
consecutive groupable items. A standalone commentary boundary ends
the group, and `899308.I3PO.Pq` unwraps a completed singleton.
A generic successful command joins adjacent exploration actions and
adds the separate run segment to the group summary. It still gets
its own `O3Io.t_` disclosure within that group. The group viewport
has a 224 logical px cap. Current signed-in expanded capture is
unavailable. This evidence supports translating the bounded stock
command group while retaining lazy output and item search.

Native translates the supported completed command group only when
the bounded selected detail page contains the following same-turn
boundary. The initial Worked for disclosure still performs one
page read. The nested group starts collapsed and builds its rows
within a 224 px viewport. Opening search uses the individual loaded
items, so an offscreen nested command remains findable. Execution
retains raw individual rows. A group remounts open when it contains
an existing output preview, and explicit collapse releases that
preview.

At 1191×865 the packaged Linux app expanded a saved stock turn with
read, search, list and one generic command. It opened the real read
output, preserved it through Commands → Execution → Commands and
cleared it when the group collapsed. The App, Host and stock exited.
Widget coverage scrolled a longer group, verified one item-page read,
found the last command and verified one output read across search.
All 531 default Flutter tests, format, ASCII-path analysis and 100
Rust tests passed. The history benchmark retained 100 of 1,000 turns
and exercised ten 3 MiB outputs. The pure-Dart gate checked 65 roots.
The signed-in official group capture and unsupported combinations
remain outside this evidence.

## A0 navigation inputs

The two side buttons from the current renderer command registry reuse
the same thread navigation callbacks as the toolbar and keyboard.
The Linux release exercised mouse buttons 8 and 9 over the thread body.
Its captured header moved from the second stock thread to the first,
remained at the history boundary on a second Back, and returned to the
second on Forward. App, Host and stock exited. The simulated test also
covers resize, failed reads and keyboard navigation.

The installed Electron menu template `early-bootstrap-815` defines
Undo, Redo, Cut, Copy, Paste, Delete and Select All. `499225` preserves
the focused editor when its Windows menu trigger receives a pointer
press. The initial Native build passed a touch-style widget test and
then lost its editor before the mouse could open Edit. A mouse regression
reproduced the loss. The fixed trigger joins the Flutter text-field tap
region and dispatches the existing editing Actions to the captured
focus context. Linux release captures confirmed Select All, Delete and
Undo on an unsent composer draft. Help passed its public documentation
URI to a disposable system handler. The installed template also provides
public changelog, troubleshooting and status links. The full 522-case
Flutter suite and ASCII-path analysis passed. The isolated window has no
matched decorated frame.

## A5 and A9 Goal draft lifetime

`725496.G5g5` stores its edited text in the registered Goal tab state.
`309406.Ceox.e7` preserves a dirty tab when it is revealed again.
`182735.ZU27` changes the active tab or visibility without removing
its state. Its explicit close removes the registered tab and draft.
The official agy peer independently traced the three actions and
reviewed the Native diff and captures.

A simulated regression reproduced loss of an unsaved Native objective
when switching to Changes. The corrected Linux release used a paused
stock Goal and a real live file patch at 1191×865. It restored the
draft from Changes and from the header hide/reopen action. Explicit
close restored the saved objective on the next open. Only the selected
thread can hold one parked, length-bounded draft. Thread changes, a
changed source objective, completion or removal invalidate it. The
521-case Flutter suite and ASCII-path analysis passed. The official
signed-in tab strip still needs a matched capture.

## A10 stock question stepper

The agy peer confirmed `474578.IpGh.to` passes the question directly
to `42793.vMUJ.L`. The title renders once at the start of the header,
with Previous, `n of m` and Next trailing it. The ordinary call
does not override the default forward-navigation gate. Native
uses that header and lets the chevrons browse an unanswered step.
Continue and Submit retain their existing validation. Left/Right
changes steps within the active request, clamps at the ends and
keeps the editor's caret keys available while Other is focused.

At 1191×865 the packaged app moved both ways with Left/Right,
clamped at the last question and used the header chevrons to move
away from and back to separate Other drafts. Stock's saved
function result contained the exact two drafts under the original
question IDs. The app, Host and stock processes exited. All 530
default Flutter tests, five opt-in stock cases, format and
ASCII-path analysis passed. The ordinary official Escape handler
interrupts a turn. Native explicit Cancel request returns a
request-scoped JSON-RPC error. H1's asynchronous free-text and
voice request is a separate call site.

The Other editor's `vMUJ.L` ArrowUp handler leaves a single visual
line and selects the last option without submitting. Native checks
the editor's actual rendered line boundary and preserves ordinary
caret navigation for wrapped text and active IME composition. In a
separate packaged stock run, the short draft reappeared on return
to Other and the wrapped draft's caret moved up within its editor.
The saved result verified the last predefined first answer and the
typed second answer. The 530 default Flutter cases, format and
ASCII-path analysis passed.

## A10 ordinary request interruption

`474578.IpGh.to` wires ordinary Escape to turn interruption. The
first Native release replay failed to interrupt before the cleanup
deadline, despite passing a blocking-only simulated case. A direct
bundled-Host/stock probe reproduced `isBlocking: false` with both
active IDs matched. The official ordinary Escape mapping does not
use that flag. The corrected Native route uses the active thread,
turn and interrupt capability. It preserves approval, MCP, popover,
route and IME priority.

A request-identity-scoped presentation signal immediately cancels
the pending 180 ms choice callback and disables stale actions during
the interrupt call. It clears on thread changes and method completion.
A failed call restores the previously focused card control and its
draft. It does not resolve the protocol request locally.

Separate packaged runs pressed Escape during choice activation and
inside the typed Other editor. Stock stored `turn_aborted` with the
interrupted reason, no subsequent fixture answer ran, and App, Host
and stock exited. All 532 default Flutter tests, format and strict
ASCII-path analysis passed. The additional Native Cancel request
button retains its explicit request-error semantics. H1 async
free-text/voice and an inactive request retain separate evidence.

## A11 active primary action and stop confirmation

The installed `309406.tYeY.pR/Zp` chooses Stop for an interruptible local
turn without a draft, and a follow-up action for a draft. `309406.rG`
renders a single `182735.enVv` slot. Local Steer and Send share the upward
arrow. Official Queue, dictation and realtime voice are separate variants.
`309406.tL` arms the stop key for two seconds and scopes it to the turn.
The agy peer independently traced the single-slot path and reviewed
the Native diff and release captures.

At 1191×865, the Linux release used one position for Stop, Steer and
the Esc confirmation. A distinct disposable follow-up reached the
loopback through stock after clicking Steer. Double Escape interrupted
the active stock turn with its next unsent draft intact. Pointer Stop
interrupted a second stock turn. An initial run captured a stale frame
and the reused marker could match prior conversation history. A settled
rerun used a fresh message marker and explicitly focused the field.

The peer found that a newly arriving request could leave the confirmation
armed. Native now clears it immediately on a pending approval, question
or elicitation, when the active target changes and when the panel goes
offstage. A release fixture opened the approval after the Esc hint was
visible. The hint reverted to Stop, two Escape presses left the approval
pending, and Reject reached stock. Both package runs exited the app,
bundled Host and stock process. A simulated runtime regression covers
stable placement, the 2-second timeout, approval precedence and draft
retention. The 526 default Flutter cases, five opt-in stock cases,
format, ASCII-path analysis, Linux bundle closure and the bounded-history
benchmark passed. Signed-in official focus and density still need a
matched capture.

## A11 idle action and focused surface

`16389.Ips7.C` adds the primary action after the other footer controls
with an 8 px leading margin. `182735.enVv` mutes a disabled action.
Native now disables Send without text or attachments, treating whitespace
as empty. The Linux package showed the disabled action and accepted a
nonempty draft in the same slot. The widget assertion measures 8 px
from the permission control. The initial test run exposed tests that
tapped in the same frame as editing. Their input steps now allow the
widget to paint its enabled state before clicking. All 526 cases passed.

The agy peer traced the default Electron composer surface in
`f0eddefa0de7.css` to its base elevation border. The focus-dependent
document-composer background and assistant-mode outline are separate
branches. Native retains its neutral outline while the editor is focused.
High-contrast rendering preserves the Native focus cue. A widget test
moves focus to conversation search and back without changing the ordinary
composer border. At 1191×865, the top outline region was identical before
and after pointer focus and text entry. Linux build, format, ASCII-path
analysis, 526 Flutter cases, Rust format, Clippy and 100 Rust tests passed.

## A11 stock model and reasoning

Build `25894` uses a 224 px end-aligned picker in `104066.dig0`.
`209288.vdOM` selects the advanced model list when there is no resolved
power selection. Its explicit-model view has a 24 px discrete track, a
model-list switch and a 32 px clear action. The peer independently traced
both views and their CSS in `0b2d31a9d760.css`. The Native release projects
only the stock catalog and advertised reasoning efforts. Account-controlled
model bundles, speed tiers and locked rows require separate evidence.

The disposable config selected `gpt-5.4` while `model/list` marked
`gpt-6.1-sol` as default. The first stock request used the configured
model without an explicit effort. The explicit choice reached the loopback
provider as `gpt-6-sol` / `high`. Clearing the client override retained
that model and effort on the next turn in the same stock session. The
interface labels the action and selection as clearing overrides and
inheriting runtime settings. The simulated test confirms the next typed
request omits both overrides. The first fixture exposed the stock warning
for missing `gpt-5.4` metadata and retained it in the captures.

The release walkthrough exercised both views at 1191×865 and verified
process teardown. At 820×420 and 200% text scale, an early widget run
reproduced a 6 px overflow in fixed-height menu rows. Rows now retain a
32 px minimum and grow for their text. The full 520-case Flutter suite,
five opt-in stock cases, ASCII-path analysis, Model smoke and Linux bundle
closure passed. The signed-in official open picker is still unavailable
for live comparison.

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

The A5 header reorder exposed a stale popover controller on wide/compact
recomposition. The original test failed with `LateInitializationError`.
`86eed8a` detaches the old controller, removes its overlay and binds the
replacement. A regression test swaps two controllers with an open menu.
The release used the thread menu to find a saved answer and opened Goal from
the right-panel button. The follow-up build verified the active Goal clock
while the stock request was pending and submitted the request afterward.
The combined default Flutter suite now passes 516 cases with five opt-ins
run separately. The clean ASCII-path analyzer and Linux release build pass.

## Stock request, settings and prose verification

At the `b6d031a` checkpoint, exact hosted CI completed successfully.
[Hosted run 42895183024](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42895183024)

The packaged desktop presented a real two-question stock request with
separate steps and delivered both typed answers to the disposable loopback
fixture. The widget path verifies back navigation and preservation of private
text, including its whitespace. The renderer's async H1 card remains a
distinct branch.

The packaged Full access check used a disposable profile and started no
turn under the changed permissions. It showed the new warning shield after
confirmation. That run exposed a clipped Sandbox popover in the 1191×865
window. A follow-up 820×420 test reported 113 px of dialog overflow and
placed the menu below the visible viewport. The corrected package shows
all Sandbox options within the trigger width in both viewports. The short
dialog scrolls and the menu opens above its anchor. The wide sidebar
omits an empty Pinned group, and the application View menu opens its
separate saved-in-stock scope.

The packaged Markdown comparison used real saved stock history containing
paragraphs and lists. The line-height token comes from build 25894's CSS.
The targeted 13-case Flutter run includes bounded timeline, scroll-anchor,
streaming plain text and lazy Markdown checks. Clean ASCII-path analysis
and Linux release build passed. The official signed-in scale and the
matched prose block spacing remain open.

## Rail, thread metadata and active thinking verification

Exact hosted CI passed on `3ca2f8a`, including Windows and macOS builds.
[Hosted run 42898842754](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42898842754)

The agy peer confirmed that the purple H1 glyph indicates a merged PR and
that the Native attachment record cannot establish that state. The wide
release puts the stock unread dot at the end with no idle project timestamp.
Targeted tests retain receipt writes and hover/focus access. A packaged
stock stream showed the unadorned Thinking label, its completed Thought
state and the final answer. The disposable model emitted an independent
fallback-metadata warning. Native's bounded summary and stock completion
behavior stayed available. The generated `ThreadTurnsListResponse` Turn
has `items` and `itemsView`, without a collapsed-message count.

The 1191×865 packaged Goal strip starts 13 px inside the composer on each
side. The independent ecosystem walkthrough verified the current Plugins
glyph, the backed dialog and restoration to Home on close. The first
press-and-hold screenshot did not open the dialog. The normal click and
keyboard Escape sequence reproduced the intended behavior in the clean
package, and the widget suite asserts the selected states.

## Window navigation, message actions and running Changes

Exact hosted CI passed on `ca51e7b`.
[Hosted run 42902044133](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42902044133)

The official agy peer traced Back and Forward to the active destination's
router history. Goal and Changes tabs do not create entries. Native reuses
the stock selection path and retains only 32 thread IDs. The packaged
walkthrough selected two real saved threads, used both arrows, then
revisited the first thread with Ctrl+[. The first incremental build
rendered the Forward glyph as an unrelated icon. The clean ASCII build
regenerated the subset and displayed both arrows. The same build captured
old reply actions hidden and revealed without moving the reading position.

An independent bundled Host → stock trace captured file-change completion
and two `turn/diff/updated` notifications before the final model response.
The earlier run remains a distinct observation with no actionable snapshot
in its in-progress capture. The release held a real two-file response open
long enough to hover the count and select the second patch. The first
preview inherited a white tooltip foreground. The corrected package showed
both filenames and per-file counts in the current surface colors. The
follow-up regression tests keep the chip absent while its pane is open
and verify the timeline anchor through close and resize.

## Numbered questions and composer permissions

The current release captured a two-step real stock question with numbered
options and both typed answers reached the loopback model. The simulated
path verifies directional focus, Enter selection and preservation of private
text when going back. The H1 async card and voice route remain separate.

The wide composer shows an anchored stock Sandbox menu. Existing safety
confirmations and the advanced execution dialog remain the same paths.
The first layout pass lengthened a compact Home control and overflowed by
31 px near the split threshold. A compact label restored all four affected
layout cases. In private Xvfb, short captures after selecting Full access
showed the menu closed before the confirmation was visible. A disposable
instrumented run verified the callback and showed the dialog on a later
frame. The clean uninstrumented package reproduced the confirmation and
Escape dismissal. No new turn was started under the changed permissions.

The exact release also reopened the selected file patch from the in-turn
preview, switched to the wide split at 1450×865 and closed from the header.
The chip appeared only with the pane closed. This confirms the A8
transition. It does not close the official open-pane comparison in D.

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
