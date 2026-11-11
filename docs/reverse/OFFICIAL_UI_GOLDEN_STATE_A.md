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
| A0 Application/window strip | H1 y0–50 shows Back, Forward, sidebar toggle, File/Edit/View/Help and window controls. `499225.mJEk.z` uses the active destination router. `189497` registers keyboard and side buttons. `early-bootstrap-815` defines Edit and Help roles. | Linux release revisits stock threads and wide routed `Customize` sections (`Plugins`, `Skills`, `Apps`, `MCP`) across toolbar Back/Forward, `Ctrl+[`/`Ctrl+]`, `Alt+Left`/`Alt+Right` and X11 buttons 8/9 (`32`-entry cap), guarded by `_navigationOperationEpoch` against delayed `thread/read` races and restoring conversation focus on `Customize` unmount. Edit targeted the focused composer and Help handed the documentation URI to the platform handler. | `8ce73dd`, `5dc63ca`, `b6e2e1a`, `b10b27a`, `135e8fb`, `21f7525`, `ea267d3` | Native history tracks bounded thread and wide Customize visits. The Native menu has backed editing roles and four public links. OS frame placement, menu mnemonics and the official-only Help commands differ. | PARTIAL | Compare the decorated signed-in frame and open-menu keyboard/focus behavior across available Desktop platforms. |
| A1 Global navigation rail | H1 x0–60 has selected Home and separated destination clusters. `499225.36a7812ae9.js` `lp/lu/lc` define the rail, scrolling group and footer, and `499225` routes `Plugins` (`890434.9dbaee449e.js` `GO7r.wdY` -> `ws5U` `20 px` multi-tile glyph) to inline `Customize` (`sO.SQ` header, `customize-installed-search` with `Escape` trigger refocus, `Plugins` `aJkJ`/`ws5U` + `Skills` `VBV1`/`sLbn` rows, `sidebar.customize.installed`). | At `1191×865` (`/var/tmp/native-gemini-a1-customize-r3/`), the Linux release selects the `20 px` multi-tile `Plugins` rail glyph and swaps the left contextual panel (`x52–340`) and workspace (`x340–1191`) inline to `Customize` while keeping `Home` thread/conversation state mounted offstage under `TooltipVisibility(visible: false)`, qualifying partial/paginated/`100`-capped counts as `<N> loaded`, expanding installed `Alpha Helper` via stock `plugin/read`, closing sidebar search on `Escape` without leaving `Customize`, collapsing to an inline `CodexSegment` on `Ctrl+B`, and retaining `_EcosystemDialog` below `760 px`. Remote and Runtime details remain in the lower cluster. | `8ce73dd`, `373305e`, `3a6e846`, `ea267d3` | Native surfaces supported stock `Plugins`, `Skills`, `Apps` and `MCP` in `_CustomizeSidebar` and keeps Remote/Runtime status in the lower rail cluster. Official Automations, configurable rail ordering, account-backed Apps/Connectors pages and the account footer have distinct capabilities. | PARTIAL | Compare signed-in `Customize` card/detail density against a matched official capture while keeping Automations, configurable rail ordering and account/private-service roles separate from Native runtime status. |
| A2 Contextual Codex sidebar | H1 starts with product, notifications, search, New chat, Dot and Projects. `499225.ZIk0/dR` guard the empty Pinned heading and show Projects actions on group hover/focus. `499225.tI/t_/eK`, `182735.b5fQ/V7pv/r6TF.eH`, `189497.rmk3` and `236683.V5ob.NF/c6` give `Projects` (`13 px` / `18 px`) and project rows `36 px` row boxes, open the local menu at pointer coordinates on right-click (`contextmenu`), at the focused row `bottomLeft` on `ContextMenu` / `Shift+F10`, or anchored to the trigger on ellipsis click while keeping the row highlighted, and show collapsed project status (`error > working > unread > null`) instead of a numeric count. | Wide Projects reveals actions on pointer or keyboard interaction, uses a 36 px `13/18 px` section row, and aligns `New chat` and project labels on a shared `x=95` vertical axis at 1191×865 while preserving compact State F geometry. Right-click opens the folder menu at pointer coordinates, `ContextMenu`/`Shift+F10` opens it at the row `bottomLeft`, and ellipsis opens it at the trigger anchor while keeping the 36 px project row highlighted; collapsed projects render the aggregated unread/running/error indicator instead of a raw thread count. | `fe31e9e`, `373305e`, `b6e2e1a`, `a3737b9`, `0c45b67`, `a8b2104`, `d74cb39`, `f1e2fbb` | Native groups its bounded loaded threads by directory and exposes only the local folder action in this menu. Official organize, project metadata and batch actions have distinct backing. Dot and notifications depend on account services. macOS/Windows launch was not exercised. | PARTIAL | Keep loaded-only operations explicit and track account entries, organize/remove project actions and the product selector separately. |
| A3 Project/thread rows | H1 has full-width row pills (`x71–397`) with a `16 px` reserved leading slot (`927552.qK2L` `reserveLeadingSlot: isGrouped` -> `384375.cSic.y` `w-4 shrink-0`) so child thread titles start at the exact same horizontal coordinate (`x112`) as `New chat` and project titles, plus right-click pointer-coordinate and `ContextMenu` / `Shift+F10` row-`bottomLeft` context menu (`86296.oprL` + `189497.rmk3`) and trailing spinner, unread dot or merged-PR glyph. | Paired stock captures at 1191×865 verify 36 px full-width row pills (`x60–331`), exact parent-label horizontal alignment (`x95` across `New chat`, project titles and child thread titles), pointer-positioned right-click and row-`bottomLeft` `ContextMenu`/`Shift+F10` thread menu opening with persistent row highlight, running spinner and 8 px blue unread dot, with compact geometry preserved under `!hasNavigationRail`. | `fe31e9e`, `9bff30d`, `9785c1a`, `8ee189e`, `d74cb39`, `f1e2fbb` | `927552.2a3666383e.js` derives the purple glyph from an actual merged PR state. Native thread attachments carry link identity but lack provider merge state and stay on-demand. | PARTIAL | Verify the supported Git/PR indicators with comparable data. Keep the merged glyph evidence-blocked until reliable state is available. Do not scan attachments for every visible thread. |
| A4 Shared page/surface geometry | H1 puts sidebar and workspace inside one rounded surface. S2 has a 340 logical px default left panel, 52 px rail fallback and 42 rem content cap. | N1 and geometry tests show a single page with 52 + 288 px default, a resizable sidebar and 672 px reading/composer cap. | `5dc63ca`, `d836c16`, `c3ac6f0` | H1 physical positions depend on zoom and sidebar preference. Native's supported wide geometry follows the same logical roles. | PARITY_ACCEPTABLE | Preserve the dimensions for this state. Measure official logical gutters and resize persistence when a matched signed-in window is available. |
| A5 Workspace header | H1 has folder/title, then thread menu, detail control and trailing panel toggle. `446282.FR4w` puts the side-panel action at right order 300 and delegates panel visibility to `ZU27.kO`. | The release has the three trailing roles and opens conversation search through the thread menu. The last control hides and restores the Goal editor with its draft. The draft also survives switching to stock Changes and back. | `0e19880`, `86eed8a`, `dafafba`, `dc7c3ee` | Native retains its linked-PR affordance and a single current Goal draft. It has no general task tab launcher. | PARTIAL | Verify the signed-in menu and simultaneous tab state. Map backed destinations while preserving link management and the bounded reading position. |
| A6 Conversation reading/prose | H1 shows left reading-column prose with quiet inline events. `702243.U6mT` + `index.html` `@layer` zero root outer margins (`[&>*:first-child]:mt-0 [&>*:last-child]:mb-0`). `0040d5ae1a9f.css` uses `1.625` line-height, body-relative heading sizes/line boxes, `2 em` list text inset (`w600` primary-ink markers), `li + li = 0`, `li > p + p = 4*S` (`1.0 em`), `blockquote` (`2*S` block / `6*S` inline-start padding, `1*S` rounded bar, `0` internal gap), `table` (`4*S` top margin, `max(12px, 0.875em)` `tabular-nums`, borderless outer/vertical grid, `1 px` strong header rule, `1 px` subtle non-last row rules, `6*S` last-row bottom padding), `hr` (`1 px` strong rule, `7*S` margins) and `.InlineCode-Cddi3Y` (`702243.37e071a6c0.js` `dir="ltr"`, `0.92 em` container-relative monospace, `1 px 6 px` pill, `6 px` radius, `box-decoration-break: clone`, standalone prose fill light `0x171A1C1F` / `#EAEBEB` on `#FFFFFF` and dark `0x1CEDEDED` / `#373737` on `#212121`). `23355`/`272587` give `CodeSnippet` `5*S` margins, `20 px` radius, `1 px` subtle border, `48 px` header, mapped language labels and `28×28` / `16 px` copy action. `225284.y5H2`/`o7K3` and `34052` govern message actions. | Retains old/latest message action visibility, `1.625` line-height, `2 em` list inset, heading hierarchy, zeroed root outer edges, loose-list `1.0 em` intra-item paragraph gaps, `blockquote` rounded bar/insets, `20 px`-radius / `48 px`-header fenced code card with keyboard-focusable `28×28` / `16 px` copy, borderless-vertical aligned `table`, `1 px` `hr`, and normalized literal HTML, and adds `1 px 6 px` / `6 px`-radius `dir="ltr"` inline-code pills across `p`, `h1`–`h6`, `ul`/`ol`, `blockquote`, `table` `th`/`td` and enclosing `<a>` links (`[`code`](...)` and `[See `code` here](...)`) while keeping fenced `<pre><code>` unpilled, multi-span heading line boxes intact, `SelectionArea` `selectAll`/drag document order continuous, global `2×` `TextScaler` geometry exact, cached `onTapLink` updates late-dispatched, and `0` image-sentinel GETs across paired `1191×865` light (`#FFFFFF` / `#EAEBEB`) and dark (`#212121` / `#373737`) packaged stock replays (`/var/tmp/native-gemini-a6-inline-code-r1/stock-replay-r2/`), compared against an identical-text controlled `13.5 px` / `640 px` CSS specimen (`official-a6-inline-code-matched-13_5-{light,dark}.png`). | `d836c16`, `650c721`, `a8d9e97`, `2a48724`, `67b85ca`, `80d318d`, `f7144df`, `55541ea`, `d0882b9`, `d9dc65f` | Native reading column renders `640 px` content width (`672 - 32`) at `1191×865` with `ThemeTokens.bodyMedium` `13.5 px` (used to match the controlled component specimen, not as proof of the official signed-in account's font preference). Tokens `<= 640 px` move onto the next line at the preceding space in both CSS and Native `WidgetSpan` (differing slightly in glyph advance between Chrome `Liberation Mono` and Linux system `monospace`); a single unbroken inline-code token `> 640 px` wraps cleanly inside one `640 px`-bounded `6 px`-rounded `WidgetSpan` pill box rather than CSS `box-decoration-break: clone` per-line fragment rounding. Physical text scale, attachment chips and user bubbles lack a matched signed-in comparison. | PARTIAL | Compare attachment chips, user-message bubbles and physical font scaling against a matched signed-in official window while retaining single-parse bounded lazy Markdown and explicit `> 640 px` single-token `WidgetSpan` wrapping. |
| A7 Thought/activity/read-run | H1 shows quiet Thinking and borderless read/run. `225284.NKAf` groups exploration and pluralizes runs. `getw` supplies the completed disclosure, `100921.waM8/F9dY` formats duration and `225284.O3Io` supplies expanded exploration captions. | A stock live turn displayed one Read files segment and singular ran a command. A saved turn opens a second collapsed Read files and ran a command group. The group shows typed read, search and list captions plus a generic Ran row. The Linux release restored real output across Execution and Commands, then released the preview on explicit group collapse. | `388147a`, `0a0f79c`, `31d2abd`, `0c8caca`, `f68889c`, `a18b1fa`, `a3bcd98` | The genuinely untimed fallback lacks a collapsed count. Native groups only completed successful commands with a known in-page boundary. Search and Execution retain individual rows. Mixed-tool groups, declined commands, titled reasoning and matched signed-in expansion remain open. | PARTIAL | Compare grouped row density and specialized or declined command captions. Keep count claims bounded by the loaded page. |
| A8 Closed Changes affordance | H1 x705–911 shows a centered count chip. `34052.eR/ovhK` defines its 20 px elevated surface and closed-only gate. `225284.Bj1J.ef/eg` attaches an upper interactive file list while running. | A held real stock reply allowed a two-file +2/−0 preview during the turn. Selecting the second file opened its actual patch. The closed chip is removed when the pane opens. Header close preserves reading position. | `155ea2f`, `f31239e`, `c36da98`, `a983fa9` | Native uses the bounded stock diff snapshot. A keyboard user opens the pane directly. The separate open-pane composition belongs to D. | PARITY_ACCEPTABLE | Retain the stock snapshot gate and keyboard entry. Compare the actual open pane in D once the A screen is closed. |
| A9 Selected Goal | H1 shows status, clipped objective, elapsed and clear/resume/expand icons. `309406.Ceox.tn` routes title and expand through the same visible-tab toggle and retains dirty state while the tab is parked. The `cI4i` rail applies a 13 px inset. `725496.G5g5` + `182735.KIKs` refresh relative wall time every 60 s while visible, pause when hidden, refresh on visibility return, and cancel on disposal; `74692.wgrH.setPromptText` reverts text with collapsed end selection without refocusing. | The release confirms the inset and opens the stock editor from title or expand. Save, Escape and request submission were exercised. Switching panes retains an unsaved draft. Explicit Close or a second click on the visible Goal strip closes the tab and returns to the saved objective. A 1191×865 stock release run mounted ~15 s after Goal seed transitioned autonomously from `Updated just now` to `Updated 1 min ago` across the 60 s wall-clock tick with zero input or stream events, then persisted a `Ctrl+S` update (`Updated just now`) and reverted an unsaved suffix via pointer click without stealing focus. | `09037a2`, `e5bbfed`, `fc192ff`, `2c5e8c1`, `02862e4`, `dc7c3ee`, `3505385`, `4d379ed`, `c8e96a0`, `d3bf1d0`, `481788f`, `d09fe2e` | Native confirms clear and uses a full reading surface when both columns cannot fit. The tray uses inline objective, bullet and usage within its click target, with 24 px actions. Own saves retain the editor across notification-before-ack ordering, external stock replacement closes the old editor, the mounted 60 s wall-clock timer pauses when hidden and cancels on disposal, and Revert sets collapsed end selection without refocusing. Signed-in terminal variants (`complete`, `blocked`, `usage_limited`, `budget_limited`) and matched live official captures remain open. | PARTIAL | Compare signed-in terminal Goal variants and tab-strip chrome when matched signed-in official captures are available. |
| A10 Pending question/request | H1 Question, voice, Skip and Send are `qMAt` / `Ceox.t6` async input. For stock, `Ceox.iL → IpGh → vMUJ` displays individual questions in a single `100921.Y5qM.Q` header without a separate Desktop banner, `381170.Qr2V` + `42793.dUpd` supply `12 px`-radius choice rows, `20 px` markers, `' (Recommended)'` pills, hover highlight transfer and enter arrows, and `42793.vMUJ.N` + `100921.WNfT` supply the `12 px`-radius inline Other footer (`4 px` below options, `20 px` pencil marker) and primary `⏎` keycap badge. | At 1191×865 the Linux release rendered the unified question header, `Option 1` + `Recommended` badge, `20 px` markers, hovered row highlight transfer with trailing enter arrow, aligned `20 px` inline Other marker (`x` delta `0.0 px` in widget geometry), and `Continue` / `Submit` `⏎` badges, delivering both structured answers to stock. Earlier stock runs verified custom drafts across resize and step navigation, digit/arrow/Enter selection, ArrowUp out of single-line Other, and Escape turn interruption. | `3899c23`, `515d283`, `5769e31`, `b32af57`, `2c290b1`, `39bd7ea`, `9402faa`, `8b9fe5c`, `44100f2`, `a142fd0`, `279e476`, `6d26962`, `5fa5eab`, `0e7c46b`, `f772470`, `15e3242`, `599605c`, `d09fe2e` | Single and multi-step Desktop questions now share one unified header carrying queued count, multi-step chevrons and submitting spinner without an extra banner. Native keeps a stacked Other fallback for narrow or enlarged text and retains its explicit `Cancel request` action alongside Escape turn interruption. Stock rejects questions without options. H1 async free text and voice remain separate. | PARTIAL | Compare expanded-text geometry with current official captures and track H1 async free-text/voice input and Native's explicit `Cancel request` affordance separately. |
| A11 Composer/control grouping | H1 has add on the left and usage, model/reasoning, execution, microphone and Stop on the right. `309406` defines the ring. `341692.LUWz` defines the permission control. `104066.dig0 → 209288.vdOM` maps the end-aligned model list and effort slider. `309406.tYeY.Zp → rG` renders `182735.enVv` (`disabled:opacity-50`, `e77f816560c6.css` `28 px` ordinary circle + `16 px` icon vs `f0eddefa0de7.css` `36 px` `[data-dictation-enabled]` H1 override gated on `309406` `streamingPresentation`). `16389.Ips7.C` gives it an 8 px leading gap and the ordinary Electron surface retains its elevation border on focus. | The release opens stock model and Sandbox controls and respects inheritance. The supported non-dictation Desktop slot renders `28×28 px` with a `16 px` icon across disabled Send (`0.5` opacity scoped to `composer-send-button`), enabled Send, Stop, armed `Esc` Stop and Steer at `1191×865` (`x1064–1091, y814–841`), keeping shared `CodexButton` / `CodexIconButton` defaults at `0.45` and `34 px` compact targets unchanged. Keyboard and pointer stop exercised real stock turns and kept a stable outline while typing. | `d836c16`, `48b95f4`, `fd4ebe1`, `f8a4d99`, `cedb9e3`, `b14b5d1`, `6c9bc6c`, `e64d1e6`, `fe17af8`, `43e4d35`, `d09fe2e`, `d0882b9` | Native translates the supported non-dictation Electron branch (`28 px` / `16 px`); H1's `[data-dictation-enabled]` `36 px` voice/account branch, account model bundles, locked tiers, queue/voice variants and State B Home hero empty-Send gating remain separate. | PARTIAL | Compare multiline composer footer wrapping and signed-in capability controls against a matched official branch while keeping unsupported voice/dictation variants separately gated. |

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

## A9 inline Goal tray

`4d379ed` puts status, objective, the clipped trailing bullet and
usage in the title click target. The peer verified that `405471`
and `708543` contain equivalent `cI4i` modules. The non-embedded
row supplies a 10 px inline inset, an 8 px leading gap and
24 px action buttons with 14 px icons and 4 px inter-action gaps.
`309406.Ceox.tr/ti/ts` supplies regular 14/20 text and a 6 px
start margin for tabular usage. The existing elapsed and token
budget calculations retain their stock state gates.

The first separate fixed-status Row overflowed in two narrow
simulated layouts. The single-line span translation preserves
bounded ellipsis. The peer's next screenshot comparison found
that an Expanded text child pushed short-goal usage to the far
edge. Flexible now lets usage follow the goal naturally. The
same comparison identified the horizontal insets and a dangling
bullet when the narrow layout hides usage. Both are corrected.

The exact rebuilt package at 1191×865 displayed the persisted
paused Goal. Clicking its elapsed text opened the editor, and
App, Host and stock exited. A shorter-goal layout regression checks
the inline position, 14/20 text, action sizes, inset and click
target. The full 534-case Flutter rerun, strict ASCII-path analysis
and Linux build passed. The editor toolbar and external-dirty
state remain concrete machine work. Signed-in official captures
remain a separate evidence gap.

## A9 editor toolbar and save shortcut

`725496.G5g5` supplies the Goal action row through `998287` pane
slots. `c8e96a0` translates its 40 px total height, 1 px lower
border, 8 px inline inset, 6 px button gap and 20 px body padding.
The active font configuration matters. `93122` defines the 14 px
sans default, and `182735` writes the scaled text variables to both
root and body. The installed CSS specimen with those applied
variables computed 14/21 for Updated and editor text. Toolbar
Save resolves to 13/18. The peer's earlier 16 px body inference
was superseded by this source and computed-style chain.

The existing primitive gains the used toolbar size. Other sizes
retain their prior behavior. Scoped Ctrl/Meta+S invokes the same
Save predicate, ignores repeat activation and preserves active IME
composition. Revert uses raw draft inequality while Save uses
trimmed validation. Tests cover geometry, whitespace, IME, an
in-flight save, failure focus/draft retention and retry.

The matching packaged before/after captures retain the same stock
objective. Ctrl+S saved a different paused objective, and all three
processes exited. The first follow-on script typed after Revert
without refocusing and therefore captured saved-content resizing
only. A corrected run explicitly focused the editor and retained
its unsaved draft at 950 and 1191 px. Escape and reopen restored
the saved objective. The first observation remains separate.

All 536 default Flutter cases, five opt-in stock cases, strict
ASCII analysis, Linux release/runtime closure, pure-Dart boundary,
history memory benchmark and 100 Rust cases passed. Isolated Xvfb
logs include software DRI3 fallback, an ATK warning and a transient
initial OpenGL-frame timeout. The frame timeout also occurs in the
pre-editor baseline. Later captures render, and process shutdown
passes. Hardware desktop behavior remains a separate gate.

The peer found no P0/P1 in the actual diff and paired captures.
External-dirty closure, visible relative-time refresh and the
Revert focus observation remain machine-actionable A9 work.

## A10 single-question title

`474578.IpGh.to` supplies neither a replacement header nor a title
variant. `42793.vMUJ.L` therefore renders the question through
`100921.Y5qM.Q` with its default primary title. The agy peer
independently confirmed the 14 px type, medium weight, 20 px line
height, 16 px top/start inset and 12 px header-to-options distance.
`599605c` applies that same mapping to the single-question branch.

Paired 1191×865 packaged captures show the changed weight and inset.
The after-run submitted the preselected Option 1 under the original
`approach` ID through bundled Host and stock. All three processes
exited. All 534 default Flutter cases, formatting, strict ASCII-path
analysis and the Linux release passed. The peer also identified a
separate Native-only queued/submitting header in that branch. It
remains an actionable A10 delta alongside expanded text, H1 async
input and voice. Signed-in official captures remain unavailable.

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

## A2–A3 sidebar row alignment, collapsed status and right-click menus

In H1 (`1191×865`) and build `25894`, `New chat`, project rows
(`182735.V7pv`) and child thread rows (`927552.qK2L` with
`reserveLeadingSlot: isGrouped` -> `384375.cSic.y` `w-4 shrink-0`)
share a single `36 px` row height, full-width row highlight pills
(`x71–397` in H1) and a shared label start axis (`x112` in H1) while
`Projects` (`182735.b5fQ.RQ`, `13 px / 18 px` inside a `36 px` row)
aligns with the `16 px` leading icon column (`x82` in H1). Collapsed
projects (`499225.tI` + `182735.r6TF.eH` + `146502.j89V.N`) render the
aggregated child thread status (`error > working > unread > null`)
rather than a numeric thread count, and both project rows (`499225.th`)
and thread rows (`86296.oprL`) open their action menus at pointer
coordinates on secondary click (`189497.rmk3` `contextmenu` `{x:
e.clientX, y: e.clientY}`), at the focused row `bottomLeft` (`{x:
rect.left, y: rect.bottom}`) on `ContextMenu` / `Shift+F10`, or anchored
to the trigger on ellipsis click while keeping the row highlighted
(`MM7P` `isHighlighted`).

Native previously used `6 px` list padding against `8 px` `New chat`
padding, a `32 px` project heading with a `15 px` icon, an `11.5 px`
`Projects` label, and an outer `14 px` left wrapper on child thread
rows with `leading: null` at rest—truncating the selected pill by
`14 px` on the left (`x72..333`) and starting child thread titles at
`x83` (`9 px` left of project titles at `x92` and `12 px` left of
`New chat` at `x95`). Replacing the wide desktop (`hasNavigationRail`)
outer thread wrapper with the full-width `CodexSidebarRow` (`8 px` list
gutter + `10 px` row padding + `16 px` reserved leading slot + `8 px`
gap), unifying `36 px` row heights and `16 px` leading icons, wiring
pointer-positioned `onSecondaryTapDown` + keyboard `ContextMenu` /
`Shift+F10` (`onSecondaryTap`) + `highlighted` on `CodexSidebarRow` and
`CodexPopoverController`, and translating the collapsed project status
indicator moved all three label tiers (`New chat`, project titles and
child thread titles) to `x95` and expanded the selected pill to
`x60..331` in the `1191×865` Linux release against real stock
`codex app-server`
(`/var/tmp/native-project-menu.Djx1ja/shell-a2-a3-sidebar-after`) while
preserving existing compact (`!hasNavigationRail`) geometry for State F.

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

## A9 source replacement and serialized saves

`d3bf1d0` and `481788f` translate the `309406.Ceox.e9` saved-source
closure rule without changing the stock Goal controller. The parent keeps
one pending thread/objective pair before dispatch. An accepted own source
is adopted before the external-change closure check, including the single
parked draft. Null, complete or externally replaced sources invalidate the
editor. The serialized operation clears its pending projection directly.
Dart records have no guaranteed persistent identity.

A new typed simulated-runtime case covers external replacement, a saved
notification before acknowledgement, parking during that save and a
status-only update retaining a dirty draft. The baseline fails the first
external-source closure assertion. Twenty Goal/history/layout cases pass
with the change. A Linux release through bundled Host and installed stock
persisted two consecutive Ctrl+S objectives, retained the editor after each,
closed it after a separate stock objective update and exited all three
processes. The disposable database was read only for exact persistence
assertions. Screenshots and the failing baseline stay outside Git.

Minute refresh, Revert focus and signed-in terminal variants remain separate
A9 evidence work. The existing Xvfb software-rendering and initial-resize
warnings remain recorded. These runs establish agent runtime behavior.
Subjective Human acceptance and a matched signed-in official capture remain
unavailable.

## A9–A11 bottom-stack convergence

In build `25894`, `474578.IpGh.to` delegates ordinary stock questions to
`42793.vMUJ.L` and `100921.Y5qM.Q`, rendering one header row with the
`14/20 px` medium-weight question title at the start and step/status
controls at the end rather than a separate Desktop `'Codex needs your
input'` banner. `381170.Qr2V` and `42793.dUpd` render `12 px`-radius
choice rows (`min-h-8`, `8 px` inline and `6 px` vertical insets),
`20×20 px` markers (`12 px` medium numeral on `hoverTint`, inverted on
selection), a `Recommended` badge extracted from a trailing
`' (Recommended)'` label suffix, hover highlight transfer while keeping
the selected marker on the active choice, and a trailing `16 px` enter
arrow. `42793.vMUJ.N` and `100921.WNfT` place the `12 px`-radius inline
Other footer `4 px` below the choice list with an aligned `20×20 px`
pencil marker and append a `⏎` keycap badge inside the primary
`Continue` / `Submit` button.

For A9, `725496.G5g5` consumes `182735.KIKs`, which samples wall time
(`new Date`) on a `60,000 ms` interval, pauses while `document.hidden`,
refreshes from wall time on visibility return, and cancels on unmount;
`74692.wgrH.setPromptText` restores the saved objective with a collapsed
end selection without refocusing the editor. For A11, `182735.enVv`
applies `disabled:opacity-50` specifically to the composer primary icon
action (`e77f816560c6.css` `28 px` ordinary circle vs
`f0eddefa0de7.css` `36 px` `[data-dictation-enabled]` override), while
general buttons (`890434.ygO2`) have distinct opacity branches.

`d09fe2e` translates the unified Desktop question header (carrying
queued count, multi-step chevrons and submitting spinner), choice-row
geometry/markers/`Recommended` badge/hover arrow, `Container`-backed
inline Other footer and `⏎` primary action badge, adds the lifecycle-aware
`60 s` wall-clock `_updatedClock` and non-refocusing `Revert` selection
while preserving `d3bf1d0` + `481788f` own-save/external-source ordering,
and scopes `0.5` disabled opacity to `composer-send-button` without
changing shared `0.45` button defaults or the frozen `34 px` diameter.

Targeted verification passed 72 widget/simulated-runtime cases across
`product_controls_test.dart`, `thread_goal_test.dart`,
`official_convergence_geometry_test.dart` and
`tier1_feature_coverage_test.dart`, with clean `dart format` and
`flutter analyze`. Because `FakeAsync` does not advance `DateTime.now()`,
the `thread_goal_test.dart` case verifies `AppLifecycleState` observer
pause/resume, timer cancellation on disposal, and non-refocusing `Revert`
selection via seeded timestamps, while autonomous `60 s` wall-clock
ticking is established separately in the `1191×865` packaged Linux
release against bundled Host and stock `0.167.0-alpha.3.2`
(`/var/tmp/native-gemini-bottom-stack-walk/captures/`). An initial walk
saved via `Ctrl+S` `1.61 s` after editor mount, so tick 1 at
`t_mount + 60 s` sampled `58.39 s < 60 s` (`Updated just now`), matching
`182735.KIKs`'s unaligned `60 s` interval. The calibrated walk exercised
wide disabled/enabled Send (`01`–`02`), two-step stock question header,
`Recommended` badge, hover highlight transfer and `Continue`/`Submit`
`⏎` badges with verified stock answer delivery (`03`–`05`), mounted the
Goal editor `~15 s` after stock seed (`06`, `Updated just now`), waited
`61 s` with zero input or stream events to capture autonomous transition
to `Updated 1 min ago` (`07`), persisted a `Ctrl+S` stock update (`08`,
`Updated just now`), dirtied and pointer-reverted without stealing focus
(`09`–`10`), and exited app, Host and stock cleanly (`MACHINE VERIFIED`
+ `AGENT REAL-USE VERIFIED`, `NOT YET HUMAN VERIFIED`; signed-in official
live capture remains unavailable).

## Integrated bottom-stack verification

Shared source `53a76d5` combines `d09fe2e` with the peer-audited request
operation-lifetime corrections in `c910a97` and `7d416aa`. The full default
Flutter suite passed 547 cases with five opt-in stock cases run separately.
Formatting, strict ASCII-path analysis, the 65-root pure-Dart boundary,
bounded history/output benchmark, Rust formatting/Clippy/100 tests and
Linux release with its 83-library runtime closure passed.

The integrated release replay at 1191×865 submitted both structured answers,
showed the recommendation/hover/footer states, changed the mounted Goal
timestamp to one minute with no input, persisted a Ctrl+S update and reverted
the draft. App, Host and stock exited. The pure-Dart runtime smoke also
passed. Its independent captures are under
`/var/tmp/native-integrated-bottom-stack-53a76d5/captures/`. This replay
refuses reuse of its output directory, preserving the calibrated peer run.

The disposable model profile emits a model-metadata fallback warning, which
remains visible in both capture sets. The early uncalibrated clock capture
was overwritten at the original path by the peer fixture's directory reset.
The recorded timing observation and its phase-offset explanation remain
above. A separate original PNG has not been established in the shared
artifact directories. These limits remain separate from the successful
integrated replay, signed-in official comparison and Human acceptance.

## A6 rich prose and A11 ordinary primary action

In build `25894`, `702243.U6mT` and `index.html` (`@layer theme, base,
components, utilities;`) apply `[&>*:first-child]:mt-0
[&>*:last-child]:mb-0` so root outer margins collapse to `0`. In
`0040d5ae1a9f.css` (`S = fontSize / 4`), loose lists retain `.ListItem +
.ListItem { margin-top: 0 }` and `.ListItem > p { margin: 0 }` while adding
`:is(.ListItem, [data-markdown-list-item-content]) > p + p { margin-top:
4*S }` (`1.0 em`) and zero inter-list gap; `blockquote` uses `padding: 2*S 0
2*S 6*S`, `margin: 0 0 2*S`, a `1*S` pill-rounded `::after` bar (`top/bottom:
2*S`, `--border-medium`) and `0` internal paragraph gap (`.Blockquote >
.Paragraph { margin: 0 }`); `table` uses `margin-top: 4*S`, `max(12 px,
0.875 em)` `tabular-nums`, no outer or vertical borders, a `1 px`
`--border-medium` header bottom rule, `1 px` `--border-light` non-last body
row rules, no last-row rule, and `6*S` last-row bottom padding; `hr` is a
`1 px` `--border-medium` rule with `7*S` margins; and `23355` / `272587`
(`CodeSnippet`) give fenced code blocks `5*S` vertical margins, `20 px`
radius, `1 px` `border-subtle`, unified `#F5F5F5` / `#282828` fill, a
`48 px` header (`20/6/6/6` insets) with mapped language labels (`Dart`,
`Rust`, etc.) and a `28×28 px` / `16 px` icon copy button, above a
`20/0/20/12` scrollport. For A11, `182735.enVv` and `e77f816560c6.css` set
`--spacing-token-button-composer: 28 px` and `--icon-primary-action-size:
16 px` on the ordinary Electron branch, while `f0eddefa0de7.css` overrides
diameter to `36 px` only under `[data-dictation-enabled]` (`309406`
`streamingPresentation` voice rollout).

`d0882b9` translates these A6 and A11 rules within the existing `16 KiB`
bounded single-AST-pass `DesktopMarkdownBody` and single-slot composer
action while preserving streaming plain text, lazy Markdown, recognizer
disposal, and `34 px` compact targets. `_LiteralHtmlBlockSyntax` strips
synthetic leading/trailing newlines injected by `HtmlBlockSyntax` so literal
HTML blocks align flush with root edges; `_FencedCodeBlockView` uses
`CodexIconButton` (`28×28`, `16 px`, keyboard `Focus` + `Enter`/`Space`)
and resets copied/timer state across `didUpdateWidget` and `dispose`; and
table cells build once outside `LayoutBuilder` so `TapGestureRecognizer`s do
not duplicate on resize. As an implementation tradeoff in this slice,
`.InlineCode-Cddi3Y` (`padding: 1 px 6 px`, `border-radius: 6 px`) stays on a
`0.92 em` monospace `TextSpan` with `~9%` ink tint without pill padding or
radius rather than using a default widget `MarkdownElementBuilder` (`Wrap`
run split) or an unvalidated `WidgetSpan`; custom `Text.rich` / `WidgetSpan`
or inline pill-painting approaches remain open machine-actionable follow-up
work evaluated against selection, line-wrapping and link-recognizer
regressions.

Verification passed all `549` default Flutter tests (`5` opt-in stock cases
excluded), `flutter analyze`, `dart format` and the `83`-library Linux
bundle closure. At `1191×865` (DPR 1), the packaged Linux walkthrough
(`/var/tmp/native-gemini-a6-a11-qg8x7i49/native-walkthrough-r1/captures/01..09.png`,
compared against the build `25894` Chromium CSS specimen
`/var/tmp/native-gemini-a6-a11-qg8x7i49/official-codex-fixture-exact.png`)
verified the `640×122 px` `Dart` code card (`1 px` `(230,230,230)` border on
`(245,245,245)` fill), loose-list / blockquote / borderless-vertical table /
`hr` / normalized literal-HTML geometry, and the `28×28 px` (`16 px` icon)
primary composer action at `x1064–1091, y814–841` across disabled Send
(`0.5` opacity), enabled Send, Stop, armed `Esc` Stop and Steer with clean
App/Host/stock exit. In the initial `run_a6_a11_walkthrough.sh` helper, the
fixture image pointed to `https://example.invalid/...` and logged
`IMAGE_REQUESTS=0` before UI startup, so those captures establish visual
fallback text only; loopback network-absence and persisted `turn_aborted`
proof belong to the peer's instrumented sentinel replay
(`/var/tmp/native-ui-r0.BbOvHT/integrated-a6-a11-walk-sentinel.sh`).
The minimal loopback `gpt-5.4` profile does not establish account-backed model
metadata parity. Xvfb software-GL/initial-resize warnings, `640 px` vs `624 px`
specimen width, State B Home hero empty-Send
gating and unavailable signed-in official live captures remain recorded
evidence limits (`MACHINE VERIFIED` + `AGENT REAL-USE VERIFIED`, `NOT YET
HUMAN VERIFIED`).

## Integrated rich-prose verification

Shared source `2446dd0` integrates `d0882b9`, `316a4f4` and `50bda90` through
a normal merge. Its exact presentation/test sources match the isolated ASCII
validation copy. Format (193 files, zero changes), strict Dart analysis, 549
default Flutter cases, five separately enabled direct-stock cases, the
65-root pure-Dart boundary, bounded history/output benchmark, Rust
formatting/Clippy/100 tests and Linux release/83-library closure passed.

The independent packaged replay at
`/var/tmp/native-integrated-a6-a11-50bda90/` reproduced the rich prose and
ordinary action states. Its image URL targets a loopback observer whose
positive-control request was observed before reset. After Native exited,
the observer count remained zero. This verifies the tested image URL. The
stock rollout recorded the latest turn as `turn_aborted` / `interrupted`
before application shutdown. App, bundled Host and stock then exited.
The independent pure-Dart runtime smoke passed with 36 ms shutdown.

Peer captures, CSS specimen, metrics and helper source are separately
preserved at `/var/tmp/native-ui-r0.BbOvHT/peer-a6-a11-d0882b9-evidence/`.
Both replay artifact sets have SHA256 manifests. The original pre-UI image
counter remains insufficient network evidence. The CSS specimen is manually
assembled, at 624 px versus Native's 640 px prose width. Prior bottom-stack
model-metadata fallback warnings remain recorded. The current replay retains
portal/AT-SPI/PipeWire/DRI3 warnings and the recovered initial OpenGL resize
timeout. Unicode-path analysis, signed-in official live
comparison and Human acceptance have separate evidence limits. A6 inline
pill rendering and A1 destination structure remain machine-actionable.

## A0 and A1 routed Customize destination

In build `25894`, `499225.36a7812ae9.js` binds the global navigation rail
`Plugins` item (`railIcons: { default: nO.wdY, selected: aH }`, where
`890434.9dbaee449e.js` `GO7r.wdY` imports `ws5U`, the `20 px` multi-tile glyph)
to `isCurrentDestination: g.startsWith("/skills") || g === "/plugins" ||
g.startsWith("/plugins/")`, while `499225.mJEk.z` drives `Back` and `Forward`
from the active destination router. Inside that route, `499225` replaces the
contextual thread sidebar with `Customize` (`sO.SQ` header, `Search installed
plugins` icon button controlling `customize-installed-search` where `Escape`
closes search and refocuses the trigger without leaving `Customize`, `Plugins`
`aJkJ`/`ws5U` and `Skills` `VBV1`/`sLbn` navigation rows, and the `Installed`
group `sidebar.customize.installed`).

`ea267d3` translates this wide Desktop (`>= 760 px`) surface inline
(`_CustomizeSidebar` at `x52–340` and `_CustomizeWorkspaceView` at
`x340–1191`) while keeping `_EcosystemDialog` on compact viewports (`< 760
px`). `_ConnectedWorkspace` keeps `_ThreadPanel` and `_ConversationPanel`
mounted offstage across `Customize` visits so active turn state, scroll
position and unsent composer drafts survive route switches and `< 760 px`
resizes, while `_customizeController` is created lazily on first `Customize`
visit and disposed whenever `(cwd, threadId)` changes off-screen (zero eager
ecosystem RPCs on `Home`). Bounded `32`-entry `_DesktopNavigationEntry`
history records `(destination, threadId, customizeSection)` across toolbar,
keyboard (`Ctrl+[`/`Ctrl+]`, `Alt+Left`/`Alt+Right`) and X11 buttons `8`/`9`,
guarded by `_navigationOperationEpoch` so a delayed `thread/read` completion
during `Back` retargets bound project/history context without overwriting a
newer `Customize` selection, and `_restoreHomeFocusIfDetached` restores
conversation focus when `_CustomizeWorkspaceView` unmounts.

Peer and visual review closed three concrete defects inside the slice:
1. `_CustomizeSidebar` and `_EcosystemSectionBody` qualify partial
   (`PluginCatalogSnapshot.isPartial`), paginated (`appsNextCursor != null`)
   and `100`-entry-capped (`maxBoundedEcosystemItems`) counts and empty/search
   copy (`<N> loaded`, `No installed plugins in incomplete catalog`, `No
   installed plugins in loaded catalog`, `No matching loaded plugins`) instead
   of claiming clean empty or total counts.
2. Both Customize search pills (`customize-installed-search-field` and
   `customize-workspace-search-field`) override `InputDecorationTheme` borders
   and fill (`InputBorder.none`, `filled: false`) with focus-ring state on the
   outer pill container, eliminating the nested inner box observed in `r1`
   (`/var/tmp/native-gemini-a1-customize-r1/`).
3. Hidden `Offstage` panes wrap their subtrees in `TooltipVisibility(visible:
   ...)` with post-frame transient overlay cleanup, disposing `RawTooltip`
   tickers and pending `< 300 ms` hover timers so a hovered `Home` tooltip
   cannot freeze in `Overlay` over `Customize` as observed in `r2`
   (`/var/tmp/native-gemini-a1-customize-r2/captures/10-forward-to-customize.png`).

Serial `--concurrency=1` validation passed `70/70` widget/simulated cases
(`desktop_thread_navigation_test`, `phase1_6_ecosystem_remote_test`,
`tier1_feature_coverage_test`, `official_convergence_geometry_test`), `dart
format`, `dart analyze --fatal-infos`, the `65`-root pure-Dart boundary and
the `83`-library Linux bundle closure (`CARGO_BUILD_JOBS=2` `--config-only` +
`cmake --build ... --parallel 2`; earlier `r1`/`r2` `flutter build linux` runs
were not Ninja-job-capped). At `1191×865` (DPR 1), the packaged Linux replay
(`/var/tmp/native-gemini-a1-customize-r3/captures/01..11.png`, helper
`run_a1_customize_walkthrough.sh`, fixture `mcp_fixture.py`, and `SHA256SUMS`,
exercising source diff `4cb5496d6a1a451d088cd009779ccb1a1ee1c725b1121dd11a2b6108d395890c`
/ `libapp.so` `ca19d547f04759ef55187b2a67223ab302fe221b9d8d6fbe4f4eff21ffe5634d`)
against bundled `codex-native-host` and stock `0.167.0-alpha.3.2` verified the
`20 px` `Plugins` rail glyph, inline `Customize` sidebar/workspace, local
marketplace install/read (`Alpha Helper` expanded from `Installed`, `Beta
Linter` in catalog), sidebar search and `Escape` trigger refocus, `Skills`
(`$alpha-workflow`, `$alpha-helper:helper`), `MCP` (`native_fixture` with
`Auth: unsupported` separated from runtime status), `Ctrl+B` collapsed
`CodexSegment`, `Ctrl+[`/`Ctrl+]` Back/Forward with unsent draft intact and
zero leaked tooltip, and clean App/Host/stock/fixture exit. Native exposes
supported `Apps` and `MCP` alongside `Plugins` and `Skills` in
`_CustomizeSidebar`; configurable rail ordering, Automations, account footer,
Xvfb portal/AT-SPI/DRI3/initial-resize warnings and matched signed-in official
Customize captures remain recorded boundaries (`MACHINE VERIFIED` + `AGENT
REAL-USE VERIFIED`, `NOT YET HUMAN VERIFIED`).

### Independent A0/A1 integration verification

Codex verified an exact 195-file `lib`/`test`/`tool` copy of `ea267d3` in
an ASCII physical path. Format, strict analysis, the 65-root pure-Dart gate,
553 default Flutter cases, five separately enabled direct-stock cases,
bounded-history/output benchmark, Rust formatting/Clippy/100 tests, Linux
release/83-library closure and pure-Dart MCP smoke passed. The doc-only
`17d201c` correction records the actual unchanged 32-entry navigation cap.

The independent packaged replay at
`/var/tmp/native-integrated-a1-ea267d3-r2/` used the rebuilt Native binary,
bundled Host, stock `0.167.0-alpha.3.2`, and disposable local model/MCP
fixtures. It completed a stock turn before entering Customize. The MCP
server's audit recorded exactly one `resources/read` for the fixture URI and
one `tools/call` with the expected argument. Stock's tool metadata matched
the selected saved thread. Captures show both returned values, preserved
draft/navigation state and no leaked Home tooltip. App, Host, stock, MCP
fixture and Xvfb exited. This is real-runtime evidence with local fixtures,
separate from account-backed official service or Human acceptance.

The initial independent run at `/var/tmp/native-integrated-a1-ea267d3/`
failed its tool-call assertion: automated input omitted the final JSON
brace, the form displayed its parse error, and no tool call reached the
server. Its resource read succeeded. The run also exposed a stale cached
icon font alongside newly compiled Dart code: newly used icon code points
were absent and fell back to unrelated system glyphs. The stale font/cache
metadata are retained at `/var/tmp/native-ui-r0.BbOvHT/a1-stale-font-negative/`.
The failed run's screenshots, audit and logs remain intact; its initial
helper was not frozen before the pacing edit and is not claimed as an
unchanged preserved original.

`flutter clean` in the isolated source copy followed by Flutter
`--config-only` and `cmake --build … --parallel 2` rebuilt the font to the
same SHA256 as the owner's valid r3 artifact. The rerun checks those missing
code points before launch, paces the JSON input, and freezes its helper,
MCP fixture and binary identities with SHA256 manifests. This corrects the
local verification artifact; it does not establish an upstream incremental
cache fix. Portal/AT-SPI/PipeWire/DRI3 warnings, a recovered initial OpenGL
resize timeout and the warm-turn model-metadata fallback banner remain
negative evidence. A0/A1 retain their row-scoped PARTIAL evidence boundaries;
Golden State A remains active.

## A6 inline-code pill translation

In installed build `25894` (`app.asar` SHA-256
`121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`),
`702243.37e071a6c0.js` (`vN`) renders non-fenced inline `<code>` with
`className: "InlineCode-Cddi3Y"` and `dir="ltr"`, while
`/webview/assets/async/0040d5ae1a9f.css` (SHA-256
`37d64cfdd1f7d93c14ccd52b34e4f88fbdff5ef0cd8ed1c96c6085a64d8408f0`) defines
`display: inline; padding: 1px 6px; border-radius: 6px; box-decoration-break:
clone; overflow-wrap: anywhere; word-break: break-word; font-size: .92em`.
Two headless Chromium `1191×865` CSS specimen sets were captured in
`/var/tmp/native-gemini-a6-inline-code-r1/`: an initial unmatched `13 px`
exploratory token specimen (`official-a6-inline-code-{light,dark}.png`,
`official-a6-inline-code-metrics.json`, generator `build_specimen.py`, which
omitted the mixed-link phrase and second list item) and a controlled
identical-text `13.5 px` / `640 px` component specimen
(`official-a6-inline-code-matched-13_5-{light,dark}.png`,
`official-a6-inline-code-matched-13_5-metrics.json`, generator
`build_specimen_matched_13_5.py`) matching `a6-inline-code-fixture.md` and
Native's `ThemeTokens.bodyMedium` (`13.5 px`, `21.9375 px` line height; used
solely for attributable component comparison rather than claiming the official
signed-in account's default font preference). They verified:

1. Standalone assistant prose resolves `color-mix(in srgb,
   var(--color-background-primary-ghost-hover) 60%, var(--color-text) 6%)` to
   `color(srgb 0.101961 0.109804 0.121569 / 0.09)` (`Color(0x171A1C1F)`,
   composited `#EAEBEB` on `#FFFFFF`) in light mode and `color(srgb 0.930283
   0.930283 0.930283 / 0.108)` (`Color(0x1CEDEDED)`, composited `#373737` on
   `#212121`) in dark mode, replacing the earlier too-bright `0x21FFFFFF`
   estimate.
2. `.InlineCode-Cddi3Y` scales `0.92×` relative to its parent container (`p`,
   `h1`–`h6`, `ul`/`ol`, `blockquote`, and `12 px` `table` `th`/`td`), inherits
   parent weight and enclosing `<a>` dotted underline, and wraps natural glyph
   ascent+descent plus `2 px` vertical padding without inflating outer
   paragraph/heading line boxes.

Minimal public-API runtime probes
(`/var/tmp/native-gemini-a6-inline-code-r1/public_api_probe_test.dart`) tested
`flutter_markdown_plus` + `SelectionArea` before implementation:
- Naive `builders['code']` dropped enclosing `<a>` tap activation and collapsed
  multi-span `h1` outer `StrutStyle` height unless heading builders pass the
  heading `TextStyle` as `styleSheet.p`, while omitting `TextScaler.noScaling`
  on inner `Text` inside `WidgetSpan` caused `4×` global painted scaling at `2×`
  `MediaQuery.textScaler` (`_AutoScaleInlineWidget`).
- Both `SelectableRegionState.selectAll` and `PointerDeviceKind.mouse` drag
  across single-line, `640 px` wrapped, and multi-pill wrapped paragraphs
  preserved exact document order, rejecting the static `SelectionArea` ordering
  concern without adding a custom `SelectionContainer` delegate.

`d9dc65f` promotes inline-code geometry and light/dark fills to canonical tokens on
`OfficialCodexTheme` / `OfficialCodexThemeData` and translates inline `<code>`
inside `DesktopMarkdownBody` via `_PreScopeElementBuilder` (skipping fenced
`<pre><code>`), `_LinkScopePaddingBuilder` (tracking non-empty enclosing `<a>`
scopes), `_DesktopInlineCodeBuilder` (`inherit: false`, `TextDirection.ltr`,
`TextScaler.noScaling`, `PlaceholderAlignment.baseline` on
`TextBaseline.alphabetic`, `DecoratedBox` + `Padding(1 px, 6 px)`, and
late-dispatch `(text, href, title) => widget.onTapLink(text, href, title)` so
callback-only updates on a cached `DesktopMarkdownBody` never retain a stale
closure or force a reparse), and `h1`–`h6` `MarkdownBuilder` instances. Single
`16 KiB` AST parse, `!completed` streaming `SelectableText` bypass, `http`/`https`
link validation, literal HTML, and zero-network blocked images are unchanged.

Serial `--concurrency=1` gates passed `23/23` cases (`assistant_markdown_test`,
`theme_tokens_test`, `official_convergence_geometry_test`), `dart format`,
`dart analyze --fatal-infos`, the `65`-root pure-Dart boundary, and a clean
first-build `83`-library Linux release closure (`CARGO_BUILD_JOBS=2`,
`--config-only`, `cmake --build ... --target install --parallel 2`; runner
`be105bf4ad81df2559a7d0e14590a4a9b5a0583a7ea4223bfa79a09e53c81a32`, `libapp.so`
`74b643598ab3676b99818bcb40afc5d1941915d8b7f55590293fa30ab2fc4379`, host
`73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878`, icon font
`1e17adc97b27856e6bf9463fd616263567c4523d6f9361c1c8436043fecf1baf`). In
`1191×865` packaged stock replay against `/opt/codex-desktop/resources/codex`:
- `stock-replay-r1` (`/var/tmp/native-gemini-a6-inline-code-r1/stock-replay-r1/`)
  verified light rendering and `0` sentinel image GETs, and showed that
  `GTK_THEME=Adwaita:dark` without `gsettings` left `FlGnomeSettings` in light
  mode (preserved intact).
- `stock-replay-r2` (`/var/tmp/native-gemini-a6-inline-code-r1/stock-replay-r2/`,
  helper `run_a6_inline_code_replay_r2.sh`
  `c07ae8bddfab9b14acba3db65afa717da3c1ec3e30cf7322934e9c677fa712fd`, fixture
  `ce66acb6b1cadf0070bafa789a3b5db83ec8b644303c5e9e4d5d8c19c5fcbe8e`, manifest
  `SHA256SUMS`) set isolated `dbus-run-session` `gsettings
  org.gnome.desktop.interface color-scheme` (`default` vs `prefer-dark`),
  verified `0` requests to the positively tested loopback image sentinel after
  both App/Host/stock trees exited, and confirmed exact composited pixel parity
  with the controlled `13.5 px` `25894` specimen (`sampled-native-pixels.json`:
  light `#FFFFFF` canvas / `#EAEBEB` pill; dark `#212121` canvas / `#373737`
  pill). In the controlled `13.5 px` / `640 px` comparison, paragraph `s-p1`
  wraps at the same word (`... here in` / `one sentence.`), while `s-p-wrap`'s
  `79`-character path pill wraps onto line 2 at the preceding space in both
  renderers (`600.16 px` in Chrome `Liberation Mono`, pushing `path.` to line 3,
  versus narrower Linux system `monospace` fitting `after path.` on line 2).
  Xvfb portal/AT-SPI/PipeWire/DRI3 warnings, a recovered initial `1280×720 ->
  1191×865` OpenGL resize timeout, single unbroken `> 640 px` token `WidgetSpan`
  box wrapping (versus CSS `box-decoration-break: clone` per-line fragment
  rounding), and matched signed-in official captures/font preferences remain
  explicit boundaries (`MACHINE VERIFIED` + `AGENT REAL-USE VERIFIED`, `NOT YET
  HUMAN VERIFIED`).
