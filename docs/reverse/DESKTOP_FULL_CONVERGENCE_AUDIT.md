# Full Desktop Convergence Audit

**2026-11-12 — baseline main/origin/main `6e77c8a78bb9441668dbe9f22c2a16fd500bb1db`.**
Production inputs are unchanged from `0e2a5b8` / packaged source `5dd4758`.
**Audit only. No implementation, polish, fixes, feature-branch integration or
permission/account changes are authorized. Commit/push the audit, then stop for
the user's confirmation of this convergence baseline.**

**Do not design. Translate.**

## What this audit establishes

Coverage asks whether Native has a counterpart. Convergence asks whether that
counterpart preserves official semantics, composition, states and behavior.
The previous [gap audit](DESKTOP_COMPLETION_GAP_AUDIT.md) is a useful coverage
inventory, not a convergence certificate. Its19 functional VERIFIED entries and
two visual VERIFIED units are **not inherited** below.

No whole major surface or complete workflow currently has enough evidence to be
certified **CONVERGED across its major states**. This is a verification conclusion,
not a claim that zero useful code exists or that every working implementation is
incorrect. Several narrow source translations and stock-backed behaviors should
be retained. They do not close their parent surface.

## Frozen baseline and evidence hierarchy

Use official runtime → official shipped source/component/CSS → official public
docs → Native runtime → Native tests → historical reverse prose. History is an
index. Re-read current source and inspect actual artifacts before accepting a
claim. A source-only finding never becomes a runtime-differential pass.

- **O25894:** official installed renderer `26.1103.60933`, build25894, freshly
  read `/opt/codex-desktop/resources/app.asar`, SHA256
  `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`.
  Static components can be account/flag-gated; their presence is not enabled-state
  runtime proof. No proprietary implementation/assets are copied into Native.
- **OR-new:** fresh isolated official launch, no supplied credentials. Official
  reaches sign-in; its signed-in shell is absent. DOM/computed-style snapshots,
  screenshots and resize at1191×865,820×865,700×800, DPR1 were collected.
- **NR-new:** frozen Linux packet `/var/tmp/native-desktop-approval-u8-r2/bundle/`,
  source5dd4758, no production-source diff to this baseline. Real bundled Host +
  public stock0.167.2 in a separate empty HOME/CODEX_HOME. Native reaches connected
  Home, its compact fallback and keyboard focus. No model turn or login is run.
- **DR-new:** same credential-free cold-start precondition, three exact-viewport
  screenshot pairs. Official sign-in versus Native connected Home is a reproduced
  **DIVERGENCE**. It is not a matching signed-in Home/conversation comparison.
  Evidence packet `/var/tmp/native-full-convergence-20261112/verification.json`.
- **H1:** earlier supplied signed-in1191×865 light screenshot. It establishes
  observable structure, not its exact zoom/DPR/preferences, new state transitions,
  authenticated runtime access, or acceptance of Native.
- **NR-retained:** existing source-bound packaged/stock packets were checked as
  retained evidence, not all rerun. See the previous gap audit and per-workflow
  evidence links. A loopback model is not a real-account inference session.
- **P:** current installed stock0.167.0-alpha.3.2 and public0.167.2 schemas/call
  behavior. P is a harness contract, **not an official Desktop interaction trace**.
- **NT:** unit/widget/simulated runtime tests. These establish their exercised
  contract, never runtime differential convergence on their own.

Signed-in official conversation/Goals/Changes/Review/Customize states are not
available in the clean profile. No credential copying, hidden API, authentication
bypass or synthetic DOM/CSS specimen is used to pretend those states ran.

## Reference index — official first, Native second

These locations were revisited in the unchanged current bundle. An identified
module is not evidence that all of its branches were exhaustively reconstructed.
Unknown active predicates are kept unknown. Public docs identify legitimate
surfaces; they do not supply missing private service contracts.

| Key | Official source/location and relevant fact | Native source/location |
|---|---|---|
| OS-shell | `499225.36a7812ae9.js` `mJEk/lp/lu/lc`; `961657.97fdcc5e7d.js` shell/titlebar/layout; `182735.5b42af8792.js` `qbQ6` persisted left width | `app_shell.dart` `_ConnectedWorkspaceState`, `_DesktopSplitWorkspace`; `official_codex_theme.dart` |
| OS-side | `499225` project/sidebar/Customize; `927552.2a3666383e.js` grouped leading slot/PR state; `236683` context-menu roles | `sidebar_activity.dart` `_ThreadPanel/_ProjectHeadingRow/_ThreadRow`; `codex_sidebar_row.dart` |
| OS-home | `605278.9a7ad6f681.js` `isCodexHome`, `634175.4437e0034c.js` selected/projectless branches; `943693` placeholder | `conversation.dart` `_ConversationEmptyState/_ThreadEmptyState` |
| OS-message | `14353` `dKZq/vHM0` collapse logic; `fc8ef2a8f545.css` `.bubble-vBnidZ`; `225284` attachments/message actions | `codex_message_bubble.dart`, `conversation.dart` `_UserMessageEntryView/_UserAttachmentChip` |
| OS-prose | `702243` Markdown root/inline-code; `0040d5ae1a9f.css`; `23355/272587` CodeSnippet | `assistant_markdown.dart`, `desktop_markdown_body.dart` |
| OS-composer | `309406.5b468e9851.js` `Ceox/ComposerContent`; `182735` adaptive footer/model control; `f0eddefa0de7.css`, `e77f816560c6.css` | `conversation.dart` composer branch; `codex_composer.dart`, `composer_model_picker.dart` |
| OS-activity | `225284` `PuGl/O3Io/Worked for`, `188504/361057` file rows, public item events; current source still has distinct live/saved/terminal branches | `conversation.dart` `_ActivityContent`, `diff_approval_output.dart` `_HistoryEntryView/_SavedCommandGroup`; `codex_activity_row.dart` |
| OS-changes | `2482.c7f2dd654d.js`, `440338/816203` task panes/diff scopes; `966041.11e4e4a4b2.js` stage/unstage/revert file/hunk handlers | `DiffController`, `_DesktopChangesPane/_DiffView`; no Git write equivalent |
| OS-goal | `309406.Ceox`, `42793` questions; `225284` plan/reasoning bodies; public Goal/request-input/review methods | `desktop_goal.dart`, `user_input.dart`, `_StartReviewDialog`, typed controllers |
| OS-settings | `366057.55eed6c00a.js` routes; `107421.a695473920.js`, `906175/530534` settings; official [preferences](https://learn.chatgpt.com/docs/reference/settings), [developer settings](https://learn.chatgpt.com/docs/developer-settings) | Runtime/execution dialogs only; `ThemeMode.system`; no full preferences/localization route |
| OS-dev | `110557.82455d0c53.js` terminal launch/tab exports, `970426` terminals; `209174/884779/116410` worktrees/environments; [terminal](https://learn.chatgpt.com/docs/integrated-terminal), [worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees), [local environments](https://learn.chatgpt.com/docs/environments/local-environment) | No terminal/worktree/environment-action product lifecycle |
| OS-secondary | `881959/622950` local automation/inbox; `656640/16389/923712/116432` slash/mentions; `225284/4948` IDE/file target; `11951/553834` locale | Manual attachment/ecosystem/dialog subsets; no corresponding complete routes |
| OS-motion | `e77f816560c6.css` duration/easing tokens; `0040d5ae1a9f.css` streaming fade; `fc8ef2a8f545.css` `.Transition-TpKe3L/.Popover-x1v5UD` | `AnimatedContainer/Rotation`, immediate OverlayEntry, Flutter Tooltip/Dialog defaults |

Native filenames above are under `lib/src/app/presentation/`,
`lib/src/app/primitives/`, `lib/src/app/theme/`, or
`lib/src/features/conversation/`; complete domain/protocol locations are in the
functional workflow table below and the previous audit. No raw bundle code is
the product implementation specification copied into the repository.

## Unified official surface matrix

The36-surface inventory expands the official-first independent inventory used as
an index in the previous peer audit; each row is newly assessed. It does not
silently drop missing routes. Existing sub-surfaces such as Plan output versus
Plan controls and Steer versus queue management are explicitly **partial**, not
full presence of every sub-workflow.

Statuses: **C** CONVERGED; **MC** MOSTLY CONVERGED; **P** PARTIAL;
**U** IMPLEMENTED BUT UNVERIFIED; **D** DIVERGED; **M** MISSING.
Unknown evidence is U, not a reproduced defect. **No C/MC is awarded to a whole
row from token equality, one screenshot, protocol correctness or green tests.**

Source classes: **DT** DIRECTLY TRANSLATED; **FE** FUNCTIONALLY EQUIVALENT;
**AP** APPROXIMATED; **RD** RE-DESIGNED; **M** MISSING; **?** UNKNOWN.
Source classification is whole-row conservative; narrow DT/FE atoms are listed
separately below and cannot close their parent.

Runtime differential: **DR-D** runtime verified **divergence** under the named
precondition; **SV** source-only verified aspects, no paired signed-in run;
**TV** test-only exercised variants; **UV** unverified. All source-only aspect
claims remain bounded to the cited source, not the whole surface. OR column
**H1** is a historical screenshot; **—** means no official live state available.
Confidence H/M/L applies to the finding, not to an unearned convergence claim.

| ID / official surface | Official source; runtime | Native equivalent | Function | Surface | State | Interaction | Visual | Motion | Source | Differential | Confidence | Blocking gap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S01 Account/login/first-run/logout | OS-settings/routes + P; OR-new | diagnostics only | M | M | M | M | M | M | M | DR-D | H | Fresh no-credential start routes to different products; no login/cancel/re-auth path. |
| S02 Settings/preferences/configuration | OS-settings; — | Runtime/execution modals | M | M | M | M | M | M | M | SV | H | No routed preferences, keyboard/theme/font/language/readback chain. Existing overrides do not replace it. |
| S03 Interactive terminal/background cleanup | OS-dev; — | command output viewer only | M | M | M | M | M | M | M | SV | H | No user PTY/tab/input/resize/exit or experimental background-terminal controls. |
| S04 Local Worktree/branch/handoff | OS-dev; — | cwd metadata only | M | M | M | M | M | M | M | SV | H | No provision/handoff lifecycle; agent worktrees are not a product route. |
| S05 Git review-to-action | OS-changes/OS-dev; — | read-only live diff/Review | M | M | M | M | M | M | M | SV | H | No stage/unstage/revert chunk/file, commit/push/PR chain. Private hosted APIs remain excluded. |
| S06 IDE/file-line navigation | OS-secondary; — | http/https links only | M | M | M | M | M | M | M | SV | H | Local file/citation and Open-in target absent. |
| S07 Local automation/inbox | OS-secondary; — | misleading compact ecosystem label | M | M | M | M | M | M | M | SV | H | No schedule/editor/results lifecycle; cloud/webhook scheduling is separate/private. |
| S08 Local environments/setup/actions | OS-dev; — | manual cwd/commands | M | M | M | M | M | M | M | SV | H | No configuration/readback or action buttons; depends on terminal/worktree support. |
| S09 Inline slash/@/$ menus | OS-secondary; — | manual attachment dialog | M | M | M | M | M | M | M | SV | H | Entry/trigger/query/keyboard lifecycle absent. |
| S10 Localization/language picker | OS-settings/OS-secondary; H1 | hard-coded English | M | M | M | M | M | M | M | SV | H | CJK text rendering is not localized chrome/system fallback. |
| S11 Global content search/quick switcher | OS-secondary + P; — | title/in-thread search only | M | M | M | M | M | M | M | SV | H | Existing scopes are not cross-thread message search. |
| S12 Detached/mini/docked multi-window | OS-settings/routes; — | single window | M | M | M | M | M | M | M | SV | M | No corresponding window/tab lifecycle; enabled platform variants need confirmation. |
| S13 Changes/diff scopes/pane | OS-changes; H1 closed only | DiffController/live pane | P | P | P | P | P | U | AP | SV | H | Clears on bind; no saved/workspace source/Git actions; caller-proved pane coordinate/effect loss, no authenticated live pane comparison; large diff boundary. |
| S14 Per-file patch activity | OS-activity/O3Io; — | summary only | P | P | P | P | D | U | AP | SV | H | Native omits file-row/disclosure hierarchy; U9 and typed reader branches not integrated. |
| S15 Plan mode/card | OS-goal/OS-composer + P; — | plan/todo output | P | P | P | P | P | U | AP | TV | H | Data projection exists; no mode toggle/accept-implement workflow. |
| S16 Queue versus Steer | OS-composer + P; — | Steer/presence admission | P | P | P | P | P | U | AP | SV | H | No durable queue inspect/edit/delete/reorder or user follow-up preference. |
| S17 Keyboard/focus/command discovery | OS-shell/OS-secondary; H1 static | CallbackShortcuts | P | P | P | D | P | U | AP | SV | H | N/K focus loss; K searches threads instead of Electron command menu. Browser Alt-nav is separate from app history; no palette/settings binding. |
| S18 Compact/narrow composition | OS-shell/OS-composer; — | legacy compact Offstage panes | P | D | D | P | D | U | AP | SV | H | Desktop flag omitted; chrome/routes change; exact official breakpoint branch not established from numeric grep. |
| S19 Command execution/output | OS-activity/PuGl + P; — | Shell card/Host lazy viewer | P | P | P | P | P | U | AP | SV | H | Completion output works; live output, stdin and full expanded-state comparison remain incomplete. |
| S20 Rich tool/sub-agent/image/hooks | OS-activity + P; — | summaries/typed subsets | P | P | P | P | P | U | AP | TV | M | Missing drill-down/rich image/hook/guardian states; unknown emission/entitlement separated. |
| S21 Model/reasoning/execution controls | OS-composer + P; H1 closed | picker/settings controller | P | P | P | P | P | U | AP | SV | H | Loaded acknowledgement works; Home/provider/speed and inherited picker effort flow differ; Advanced effort fallback exists, not global inability. |
| S22 Attachment/file/image ingress/preview | OS-message/OS-secondary; — | bounded manual paths/chips | P | P | P | P | P | U | AP | SV | H | No image clipboard/file drop/autocomplete; external chip/preview/selection not closed. |
| S23 Approvals/sandbox permissions | OS-activity + P; — | request-scoped banner/menu | P | P | P | P | P | U | AP | SV | H | Exact command/file subset verified on stock; managed network/extra permissions and official layout/motion not closed. |
| S24 Questions/Other/MCP elicitation | OS-goal + P; H1 async only | structured step cards/forms | P | P | P | P | P | U | AP | SV | H | Option forms are not H1 async free text/voice; cancellation/header/Other variants differ. |
| S25 Customize/Plugins/Apps/MCP | OS-side/OS-settings + P; — | real routed catalog/details | P | P | P | P | P | U | AP | SV | H | Installed query scope, rich forms/results, server CRUD/concurrency and matched card/detail states incomplete. |
| S26 Contextual sidebar/project/thread list | OS-side; H1 | bounded local groups/menus | P | P | P | P | P | U | AP | SV | H | Missing auto read acknowledgement, metadata/batch/project actions and PR state; no unlimited catalog claim. |
| S27 Workspace header/Review/links | OS-shell/OS-changes/OS-goal; H1 header | header + target dialog | P | P | P | P | P | U | AP | SV | H | Four targets exist; branch picker/inline-detached/tab actions, reference unlink and official open Review not closed. |
| S28 Signed-in Home/project selector | OS-home; — | centered hero/chips | U | P | P | P | P | U | AP | UV | M | Official signed-in branch unavailable; Native Home is not auth onboarding and has authored starter hierarchy. |
| S29 User message/hover/attachments | OS-message; — | U7 rendered clip/bubble | U | P | P | P | P | U | AP | SV | M | Retain actual-height clipping; external pills/hover/selection/scroll-follow require source/state closure. |
| S30 Assistant prose/code/inline pills | OS-prose; H1 subset | bounded Markdown renderer | P | P | P | P | D | D | AP | SV | H | Many scalar/block translations retained; link/file behavior, wrap/pill fallback and streaming fade differ. |
| S31 Thought/reasoning disclosure | OS-activity/OS-prose; H1 collapsed | bounded body/timer | P | P | P | U | P | U | AP | SV | M | Body/protocol evidence is not expanded official state; exact active scrolling/timing/motion still needs mapping. |
| S32 Saved activity/worked-for groups | OS-activity; H1 live only | saved bounded grouping | P | P | P | P | P | U | AP | SV | H | Terminal/clipped boundaries and rich children differ; no matched expanded saved official state. |
| S33 Goal tray/editor/actions | OS-goal; H1 tray | quick actions + Goal editor | U | P | P | P | P | U | AP | SV | M | Retain translated actions; coexistence/tab and terminal/exhausted/error variants unclosed. |
| S34 Composer/adaptive controls | OS-composer; H1 running | desktop and legacy branches | P | P | P | P | P | U | AP | SV | H | Desktop branch translated subset; Home/compact focus, advanced controls, queue and transitions not whole convergence. |
| S35 App shell/rail/window/menu/popovers | OS-shell/OS-motion; H1 static | native shell/OverlayEntry | P | P | P | P | P | D | AP | SV | H | Logical geometry subset is not rendered/OS parity; session-only width, routes, menu focus and instant overlays differ. |
| S36 Loading/error/disconnected/restored | OS-shell + P; — | explicit Native recovery UI | U | U | P | U | U | U | ? | UV | M | Strong Native recovery tests/real use, no official crash/retry ordering/composition reference. |

## Functional coverage is not functional convergence

The prior54 workflow IDs remain stable. This audit adds F55–58 for complete
preferences, command-palette semantics, detached-window lifecycle and sidebar
width persistence, which the old functional denominator omitted. These additions
are cross-walked explicitly, not silently used to improve a score. Coverage is
now40 counterparts/58, including23 partial counterparts;18 are absent. The19 former VERIFIED rows have been
reconsidered individually: their API/source-bound Native runs do not certify
official Desktop input/output/persistence/cancel/error/retry/lifecycle/side-effect
equivalence. Full workflow CONVERGED is **not established for any of40**. F06 and F10 now
have concrete source-confirmed loss and are PARTIAL, rather than merely
unverified; the remaining17 formerly VERIFIED rows are unverified as full
Desktop contracts. Narrow stock-backed proofs remain valid.

| ID / workflow | Counterpart | Old label | New functional convergence | Why this is not complete Desktop convergence |
|---|---|---|---|---|
| F01 Process discovery, handshake and normal shutdown; Runtime | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Stock handshake/process retirement works; official Desktop startup/discovery/error ordering was not paired. |
| F02 Failed first startup → explicit Retry | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Explicit Native retry real use is not an official Desktop retry/prompt/order comparison. |
| F03 Connected process exit → draft retained → reconnect | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Mounted draft recovery is real; official crash auto-restart/replay/visual state contract unavailable. |
| F04 New chat → empty history → first saved turn | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Stock materialization/first-turn/restart proven; official New-chat draft/admission flow not compared. |
| F05 Open/select/resume ordinary local saved thread | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Ordinary resume succeeds; complete official selection/loading/cancel/provider transitions not compared. |
| F06 Switch threads and shell Back/Forward | Yes, possibly partial | VERIFIED | PARTIAL | Source-confirmed unsent text shares wide selection scope and clears offstage; attachment clearing and official composer-draft ownership need full mapping. Actual saved-thread loss not rerun. |
| F07 Paginated thread/turn/item history | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Paged stock data and bounded list work; official scroll/anchor/lifecycle under the same history not compared. |
| F08 Long-thread position restoration across eviction/restart | Yes, possibly partial | PARTIAL | PARTIAL | O/P; bookmarks and lazy history exist, but ordinary prior captures do not establish the complete long-history restore/anchor path against official. Compare middle-history paging, warm/cold return and changed layout. |
| F09 Rename/archive/unarchive/delete | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Correct stock mutations exist; official UI confirmations/undo/error/selection side effects unpaired. |
| F10 User Send → streaming assistant → complete | Yes, possibly partial | VERIFIED | PARTIAL | Native live assistant/reasoning is raw SelectableText until completed, then swaps to Markdown; official source uses streaming Markdown/fade. Source-confirmed output/presentation loss, no new paired signed-in run. |
| F11 Follow-up while running: steer versus durable queue | Yes, possibly partial | PARTIAL | PARTIAL | P; steer is wired, but queue management and user preference are incomplete (F40/S18). Verify interruption/failure between admission and acknowledgement. |
| F12 Stop/interrupt and stopped outcome | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Actual interrupt reaches stock; official Escape/pending-request/disabled ordering is broader. |
| F13 Failure/retry/continue/edit/regenerate combined lifecycle | Yes, possibly partial | PARTIAL | PARTIAL | P; reachable turn actions and simulated cases, but no one artifact establishes every packaged failed/cold/branch/attachment continuation. Audit the full action chain, not only action presence. |
| F14 Fork/revert/explicit harness compaction | Yes, possibly partial | PARTIAL | PARTIAL | P + existing smokes; Native controls exist. Stock revert does not undo workspace files; same-state official action/confirmation and full product-chain evidence remain open. |
| F15 One-time command/file approval or refusal | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Exact typed response and refusal proven on stock; official full approval lifecycle/layout not paired. |
| F16 Advertised session/rule/cancel decisions | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Scope/persistence tested on stock; official menu/rule/cancel transition sequence not paired. |
| F17 Managed-network approval outcomes | Yes, possibly partial | PARTIAL | PARTIAL | P/O; typed scoped choices exist, natural supported emission and distinct network outcomes unverified. Reproduce before declaring closed; no private service. |
| F18 Structured additional permissions | Yes, possibly partial | PARTIAL | PARTIAL | P; adapter intentionally refuses and drops grant profile. Emitting feature flags are under-development/off by default; establish adopted public emission before permission implementation. |
| F19 Structured request-user-input options and steps | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Supported option steps answer stock; H1 async request is a different branch and other states remain open. |
| F20 MCP elicitation including unsupported/error/cancel | Yes, possibly partial | PARTIAL | PARTIAL | P; bounded form/URL paths exist, unsupported shapes fail truthfully. Full successful packaged form/URL lifecycle and official presentation are not established by simulated tests. |
| F21 Explicit + acknowledged loaded model/reasoning/permissions | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Acknowledged loaded settings are correct data; all official menus/default/provider/cancel states not matched. |
| F22 Home/current-cwd effective settings before first Send | Yes, possibly partial | PARTIAL | PARTIAL | P; neutral unknown labels are truthful but no cwd-scoped effective preview. `config/read` exists; verify resolved values without cold resume. |
| F23 Provider mismatch / model catalog failure and recovery | Yes, possibly partial | PARTIAL | PARTIAL | P/R [provider](THREAD_PROVIDER_SCOPE_EVIDENCE.md); cross-provider title discovery/read works; actual foreign resume rejects. Dedicated supported provider recovery/editor is absent; no silent config switching. |
| F24 Saved-title and within-thread occurrence search | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Title/in-thread scopes work; official discoverability/result interaction and global scope differ. |
| F25 Global saved-message content search | No | MISSING | MISSING | P/O; experimental `thread/search` exists/caller documented; no Native request or route. Re-probe result/cursor scope, then implement bounded search. |
| F26 Goals get/set/pause/clear and notifications | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Stock Goal lifecycle works; official terminal variants/coexisting tabs/actions not completely compared. |
| F27 Review target → running → result/failure | Yes, possibly partial | PARTIAL | PARTIAL | P/O; all four targets now reachable, contrary to old uncommitted-only F14 summary. Smokes and real review exist; full target/state product and inline/detached presentation agreement remain open. |
| F28 Bounded Sections/Pinned CRUD/move | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Bounded sections work; authoritative official catalog/project interactions not closed by those probes. |
| F29 View → focus/latest-visible automatic read receipt | Yes, possibly partial | PARTIAL | PARTIAL | O/P; manual revision-aware action exists; automatic visibility admission absent. Selection alone must not acknowledge unseen turns. |
| F30 Live turn Changes and bounded file/hunk inspection | Yes, possibly partial | PARTIAL | PARTIAL | P/O; `DiffController` accepts only live TurnDiffUpdatedEvent. Normal bounded rendering works, large payload boundary C-large and official open pane remain unclosed. |
| F31 Saved/restarted/workspace Changes source | No | MISSING | MISSING | O/D-local; `DiffController.bindThread` clears snapshot; no readback/Git workspace source. Reopening edited work can lose the Changes path although timeline history loads. Reproduce same repo before translating the complete pane. |
| F32 Per-item/per-file live + saved patch disclosure | Yes, possibly partial | PARTIAL | PARTIAL | O/P; main has kind-aware captions, but no typed file list/lazy read/binding. Aggregate-as-item was correctly removed. Branch-only work below is not delivered parity. |
| F33 Command/activity and live/saved lazy output | Yes, possibly partial | PARTIAL | PARTIAL | O/P/R U8; completed Shell numeric exit/output preview and lazy full output work; in-progress output delivery and complete saved/expanded hierarchy remain open. `deferOutput` acceptance is not proof of upstream laziness. |
| F34 Skills discovery/toggle/attach | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Local list/toggle/attach works; official installed/detail/create and error/keyboard workflows unpaired. |
| F35 Plugin catalog/install/read/uninstall/installed inventory | Yes, possibly partial | PARTIAL | PARTIAL | P/R/A-run; actual catalog visible, caps/partial errors disclosed. `plugin/list` is not authoritative `plugin/installed`; install/auth/background-sync scopes remain incomplete. |
| F36 Apps/MCP tools/resources and saved rich results | Yes, possibly partial | PARTIAL | PARTIAL | P/R; typed local calls exist; saved structured/media disclosure and complete account-backed install flow do not. Text summary is not a rich result surface. |
| F37 Configured MCP OAuth launch/completion/readback | Yes, possibly partial | VERIFIED | IMPLEMENTED BUT UNVERIFIED | Controlled stock PKCE persists; official per-server scope/concurrency/browser/account outcomes not paired. |
| F38 Native account login/cancel/logout/expired-session recovery | No | MISSING | MISSING | P/O/A-run; only read-only account diagnostics. No `account/login/start`, cancel or logout adapter/route. External `codex login` is a workaround, not Native onboarding. |
| F39 Workspace file autocomplete/mention lookup | No | MISSING | MISSING | O/P [file lookup](WORKSPACE_FILE_SEARCH_EVIDENCE.md); manual attachment path exists; fuzzy/session lookup absent. Bound session lifetime/results/exclusions before wiring. |
| F40 Durable queued prompt inspect/edit/remove/reorder | No | MISSING | MISSING | O/P [queue](QUEUED_SUBMISSION_READBACK_EVIDENCE.md); only queue-presence admission is implemented. No queue management surface; do not claim queue parity. |
| F41 Interactive project/worktree terminal | No | MISSING | MISSING | O/D-terminal; output viewer and agent `read_task_terminal` caption are not a user terminal. No terminal route, PTY ownership, tab or input/lifecycle. Research supported host boundary first. |
| F42 Local Worktree create/branch selection/handoff | No | MISSING | MISSING | O/D-worktree; cwd/thread metadata is not app-managed checkout creation/handoff. No equivalent Native entry/lifecycle. Existing Git worktrees used by agents do not implement the product feature. |
| F43 Git stage/revert chunk/file, commit/push/PR actions | No | MISSING | MISSING | O/D-local; read-only turn diff, Review and attached PR links do not implement these actions. Establish supported local Git worker equivalents and confirmations; private hosted PR service remains excluded. |
| F44 Local/thread automation create/edit/schedule/results | No | MISSING | MISSING | O; rail/component evidence and compact label, no Native scheduler/management route. Determine supported local persistence/runtime contract; cloud scheduling APIs are not authorized fallback. |
| F45 Client language/localization behavior | No | MISSING | MISSING | O/H1 Chinese labels; no app locale/delegates/catalog, hard-coded English. Rendering Chinese model text does not localize the client. Inventory actual official selector/system fallback. |
| F46 Local environment setup scripts and reusable actions | No | MISSING | MISSING | O/D-local; no settings/actions route or execution/readback chain. Not equivalent to a prompt asking the agent to run commands. Requires terminal/worktree lifecycle. |
| F47 Remove a stored linked review/PR reference | No | MISSING | MISSING | P/O [unlink evidence](THREAD_ATTACHMENT_UNLINK_EVIDENCE.md); add/list exists but no remove adapter/control. Exact identity deletion has no revision precondition; stale replacement/foreign-thread safety needs explicit readback. |
| F48 Open in IDE and navigate workspace file/line references | No | MISSING | MISSING | O `openInTarget`; Native assistant links accept only http/https, no IDE/file launcher. An external web link is not a local file/line access path. |
| F49 Inline slash commands and contextual @/$ completion | No | MISSING | MISSING | O composer components; no keystroke-triggered command/file/skill popover. Sidebar menus/manual attachment are narrower alternatives, not equivalent keyboard workflows. |
| F50 Select Plan/Default mode and act on an interactive plan | Yes, possibly partial | PARTIAL | PARTIAL | O/P `collaborationMode`; plan/todo output can render, but no composer mode selection or complete plan-accept/implement path. A displayed plan is not mode control. |
| F51 Select Fast/service tier and project acknowledged state | Yes, possibly partial | PARTIAL | PARTIAL | O/P; service tier is read-only diagnostics, no composer speed control/turn override. Establish model/runtime support, entitlement/error and inherited acknowledgement. |
| F52 Native file/folder drop and clipboard image paste | Yes, possibly partial | PARTIAL | PARTIAL | O; manual bounded attachment/source/preview exists, drag/drop and image-paste ingestion are absent. Verify platform/size/error/cancel independently of text paste. |
| F53 Inspect/clean up stock background terminals | No | MISSING | MISSING | O/P experimental `thread/backgroundTerminals/*`; no adapter/control. Confirm deliberate supported adoption before implementation. Different from killing the app Host or viewing a completed command. |
| F54 Rich sub-agent/image/hook/auto-review activity | Yes, possibly partial | PARTIAL | PARTIAL | O current components; summaries exist, complete child-thread drill-down, generated/viewed image disclosure, hook-stats/guardian paths do not. Public supported emitted variants require bounded typed mapping. |
| F55 Complete app preferences/readback | No | Not in old F denominator | MISSING | S02 source has General/Appearance/fonts/keys/notification settings. Runtime and execution dialogs are distinct. |
| F56 Command palette/discovery/dispatch | No | Not in old F denominator | MISSING | Official Electron openCommandMenu Cmd+K/Shift+P; Native local search cannot dispatch the command catalog. |
| F57 Detached/mini/docked-window lifecycle | No | Not in old F denominator | MISSING | S12 current source routes/launch commands; Native lacks lifecycle. Enabled platform/account variants must be checked. |
| F58 Sidebar resize/collapse preference readback | Yes, partial | Not in old F denominator | PARTIAL | Official qbQ6 reads/writes sidebar-width through persistent store; Native keeps a widget scalar and resets on reconstruction. |

## G — Source translation ledger

Each atom is a specific source fact/predicate/handler/measurement, not a vote for
whole-screen similarity. DT/FE counts are scoped to the stated fact. AP/RD do
not count as complete translation. M is a confirmed absent equivalent; UNKNOWN
does not claim an implementation defect. Active feature/variant gating matters.

| ID / facet | Official source fact | Native equivalent | Translation status | Boundary / loss |
|---|---|---|---|---|
| G01 Shared shell hierarchy | OS-shell frame/rail/shared rounded page | app_shell._DesktopSplitWorkspace | DIRECTLY TRANSLATED | Observable role/parent mapping retained; platform window frame excluded. |
| G02 Logical shell width constants | OS-shell qbQ6 base min240/default340/max520; contextual290/rail52 | OfficialCodexTheme desktopLeftPanel* | DIRECTLY TRANSLATED | Contextual-branch scalars only; base helper min240 is distinct. H1 zoom/DPR/preferences are unknown. |
| G03 Sidebar width persistence | OS-shell qbQ6 persisted width/readback | _ConnectedWorkspaceState._desktopLeftPanelWidth | APPROXIMATED | Native scalar resets with widget; no disk preference/readback. |
| G04 Rail destination hierarchy | OS-shell lp/lu/lc routes/footer | _DesktopShellDestination{home,customize} | APPROXIMATED | Supported destination subset; Runtime/Remote are not account/automation replacements. |
| G05 Back/Forward handler | OS-shell router visit changes | _moveNavigationVisit + bounded visits | FUNCTIONALLY EQUIVALENT | Scoped visit navigation;32-entry cap deliberately limits retention; not all official routes. |
| G06 Browser versus app navigation shortcut | OS-shell189497 navigateBrowserBack uses Alt+Left; navigateBack uses CmdOrCtrl+[ + MouseBack | Native app history binds brackets/mouse, no browser-navigation layer | MISSING | Browser scope only. Missing Alt is not proof that the existing app-history handler is broken; old claims conflated roles. |
| G07 Global command semantics/focus | OS-shell189497 openCommandMenu Electron CmdOrCtrl+K/Shift+P; newTask CmdOrCtrl+N | _ThreadPanel N/K; K toggles thread search | APPROXIMATED | Both operation semantics and focus ancestry differ. Browser searchChats Cmd+K is a different platform definition. |
| G08 Compact branch selection | OS-shell current renderer variants/layout constraints | Compact _ConversationPanel without hasDesktopShell | APPROXIMATED | Explicit Native legacy fallback loses Desktop flag; do not assert a guessed768 breakpoint. |
| G09 Grouped thread row box/leading slot | OS-side reserveLeadingSlot,36px row | CodexSidebarRow/_ThreadRow | DIRECTLY TRANSLATED | Narrow geometry contract, not all status/menu states. |
| G10 Merged-PR indicator predicate | OS-side927552 actual merged provider state | No provider merged-state source | MISSING | Attached URL is insufficient to infer merged status. |
| G11 Project/catalog scope | OS-side project/section query and status aggregation | bounded loaded directory grouping | APPROXIMATED | Loaded-only projection is truthful; not an authoritative unlimited catalog. |
| G12 Pointer/key context-menu anchor | OS-side236683/189497 pointer versus bottom-left keyboard | _ProjectHeadingRow/_ThreadRow showAt | FUNCTIONALLY EQUIVALENT | Event/anchor roles translated; popup focus/motion remain separate. |
| G13 Project New chat cwd action | OS-side project action handler | _startThread cwd with typed gateway | FUNCTIONALLY EQUIVALENT | Scoped action effect only; project setup/worktree flow absent. |
| G14 Home component hierarchy | OS-home project-selected hero versus placeholder | _ConversationEmptyState hero/chips | APPROXIMATED | Native authored starter composition; no signed-in official run. |
| G15 Home/placeholder state predicate | OS-home isCodexHome/project/temporary branches | thread==null Native Home branch | APPROXIMATED | Not an exact translation of all official route/entitlement conditions. |
| G16 Reading/composer logical cap | OS-shell/OS-composer42rem | OfficialCodexTheme.maxContentWidth672 | DIRECTLY TRANSLATED | Logical scalar; not a rendered screenshot parity certificate. |
| G17 User bubble dimensions | OS-message70%,22px,16x10 | CodexMessageBubble LayoutBuilder/tokens | DIRECTLY TRANSLATED | Actual-parent cap and declared box metrics, not text/attachment full parity. |
| G18 User actual-height disclosure | OS-message dKZq20-line/19lh collapse and crossing block | CodexMessageBubble U7 render clip | DIRECTLY TRANSLATED | Source and retained runtime clipping/copy evidence; old prefix allegation rejected. |
| G19 External attachment placement gap | OS-message attachment-above-bubble8px | _UserMessageEntryView attachment gap | DIRECTLY TRANSLATED | Placement scalar; chip/hover/preview still open. |
| G20 Inline code pill metrics | OS-prose InlineCode-Cddi3Y .92em,1x6,6px | DesktopMarkdownBody inline WidgetSpan | DIRECTLY TRANSLATED | Non-wrapping ordinary pill only; clipping/fallback separate. |
| G21 Inline pill overflow budget | OS-prose wrapping box-decoration-break clone | 128 WidgetSpan budget and styled TextSpan fallback | APPROXIMATED | Bounded architecture retained, but wrapping/fragment shape and selection need comparison. |
| G22 Streaming text entry/fade | OS-prose AdaptiveStreaming fade,700ms base | No corresponding paragraph/marker fade path | MISSING | Raw live SelectableText bypasses formatted Markdown as well as fade; coalescing does not translate this path. |
| G23 Code card box/header/copy role | OS-prose23355/272587 CodeSnippet | DesktopMarkdownBody code card | DIRECTLY TRANSLATED | Completed-item declared box/copy-control mapping only; streaming bypasses this renderer and is not covered. |
| G24 Initialized prose type metrics | OS-prose14px and1.625 line box | theme/Markdown initialized metrics | DIRECTLY TRANSLATED | Source-defined default only; user font preference/render wrapping not closed. |
| G25 Appearance/font preference state | OS-settings appearance/fonts | No settings preference controls/readback | MISSING | System font/default token is not appearance workflow. |
| G26 Reasoning raw-part body projection | OS-activity item reasoning/summary parts + P | typed bounded reasoning parts/render paragraphs | FUNCTIONALLY EQUIVALENT | Typed bounded part content/completed-body contract only. Live raw-text bypass is not formatted-Markdown parity. |
| G27 Reasoning expanded viewport |225284.ak @381131 maxHeightByState8.75rem + edge-fade1rem + streaming-status gate | _ReasoningEntryView fixed140, reverse while streaming, boolean mount | APPROXIMATED | Default size can agree at16px rem; edge fade, active status predicate, unit/preference scaling and height animation are not fully translated. |
| G28 Live mounted reasoning elapsed caption |225284.ak @377400 live Date.now start/completion, cold Thought fallback | _ReasoningTimingScope/_ReasoningEntryView timer/caption | FUNCTIONALLY EQUIVALENT | Narrow live mounted transition/elapsed label only; full virtualization, persistence, timing/motion or cold-page equivalence not certified. |
| G29 Saved activity group predicate | OS-activity live/saved/terminal group boundaries | _SavedCommandGroup + bounded known boundary | APPROXIMATED | Correctness guards retained; complete official grouping/expanded state not paired. |
| G30 Command exit code predicate | OS-activity/PuGl numeric terminal status + P int32 | CodexShellExecutionCard numeric exitCode | FUNCTIONALLY EQUIVALENT | Exact typed integer/success-failure subset; live stdin/output separate. |
| G31 In-progress command output | OS-activity outputDelta while inProgress | Preview populated at completion | MISSING | Completed lazy viewer cannot close live-output behavior. |
| G32 Per-item file-row hierarchy | OS-activity O3Io per-file children | Main collapsed summary/hasDisclosure:false | MISSING | Branch-only primitives/reader are not shipped correspondence. |
| G33 Per-file body/readback | OS-activity O3Io/typed FileUpdateChange | No main typed lazy item reader/binding | MISSING | Aggregate turn diff is not an item patch. |
| G34 Open Changes hierarchy | OS-changes scope/tree/task tabs | _DesktopChangesPane picker/flat lines | APPROXIMATED | Live subset with a different component hierarchy; open official active state unavailable. |
| G35 Saved/workspace Changes persistence | OS-changes Git/saved/workspace scopes | DiffController clears on bind, live-only events | MISSING | No authoritative readback source after switch/restart. |
| G36 Pane gating coordinate/effect |961657 V @143283 passes mainWidth+leftViewportWidth to O;182735.QcW8/gbrq defaults/resize close | canSplit tests post-sidebar main width>960 and replaces timeline | APPROXIMATED | Full caller trace confirms coordinate/effect loss: default1191 window gives official gate1191 but Native851. Official requested regular split can size499px; still source-only, not live authenticated comparison. |
| G37 Goal public mutation/readback subset |OS-goal + P thread/goal get/set/clear/pause | typed controller mutations/ack | FUNCTIONALLY EQUIVALENT | RPC effects only, no tray/UI claim. Complete status is hidden by Native parent gate; official terminal variant remains to close. |
| G38 Simultaneous task/pane relation | OS-shell/OS-goal registered task tabs | Goal and Changes mutually exclusive | APPROXIMATED | General tab launcher/terminal/docking absent; per-variant official composition needs closure. |
| G39 Goal external-update/save lifetime | OS-goal source acknowledgement/notification flow | serialized saves/own-write fences | APPROXIMATED | Native correctness evidence does not establish identical official event-order guards. |
| G40 Review target composition | OS-changes supported branch/commit pickers | _StartReviewDialog raw fields/chips | RE-DESIGNED | Four semantic targets exist; chooser hierarchy and inline/detached lifecycle differ. |
| G41 Review-link unlink event | OS-changes stored attachment remove + P | No removal adapter/action | MISSING | Add/list URL routes are only a subset. |
| G42 Passive loaded settings authority |OS-composer thread effective read-side state + P | observed settings separate nullable overrides; Advanced uses observed effort options | FUNCTIONALLY EQUIVALENT | Controller/readback only. Composer picker requires selectedModelId for effort view; inherited flow differs, but Advanced effort adjustment is possible without overriding model. |
| G43 Home effective setting source | OS-composer cwd config/default projection + P | Neutral unknown; no cwd effective read | MISSING | Catalog recommendation is not config readback. |
| G44 Plan/Fast visibility and event | OS-composer Plan/Default/speed controls + P | Static plan output/read-only diagnostics | MISSING | A plan item or service-tier label is not a writable control. |
| G45 Approval exact payload authority | OS-activity advertised decision union + P | typed offered choices with request identity | FUNCTIONALLY EQUIVALENT | Exact scoped command/file responses, no client grant cache; extra variants excluded. |
| G46 Approval component/choice hierarchy | OS-activity consent row/card/persistent actions | Native banner + response menu | APPROXIMATED | Legible bounded Native path works; matched official branch/layout/focus not established. |
| G47 Additional permission grant profile | P item/permissions/requestApproval, conditional flags | Refusal-only request projection | MISSING | Do not invent grant semantics; enabled/adopted emission still conditional. |
| G48 Question step labels | OS-goal42793 Continue versus final Submit | UserInputCard step action | DIRECTLY TRANSLATED | Specific predicate/label, not all free-text/voice/cancel states. |
| G49 Other/custom answer composition | OS-goal option/custom state | Stacked fallback and explicit cancel | APPROXIMATED | Compact/high-text arrangement and interruption affordances need matching source variant. |
| G50 H1 async free-text/voice request | OS-goal/H1 async component branch | Structured options only | MISSING | Stock option validation does not implement the async branch; private audio excluded. |
| G51 Installed plugin read source | OS-side scoped installed inventory + P | plugin/list catalog instead of plugin/installed | MISSING | Catalog presence is not installed-source convergence. |
| G52 Customize hierarchy/route state | OS-side499225 installed/sidebar/cards | _CustomizeSidebar/_CustomizeWorkspaceView | APPROXIMATED | Real catalog works; counts/details/auth/compact route differ or remain unpaired. |
| G53 Global MCP OAuth request omission | P mcpServer/oauth/login name-only default | McpOauthProtocolAdapter optional timeout omission | FUNCTIONALLY EQUIVALENT | Narrow stock-owned request/ack path; concurrency/browser/account scope not whole parity. |
| G54 Saved rich tool-result presentation | OS-activity rich tool result body | Bounded text/summary only subset | APPROXIMATED | Text preview omits some structured/media/template behavior. |
| G55 File/image drop and paste handler | OS-composer local upload events | Manual attachment paths/chips | MISSING | Clipboard text is not image ingestion; native ingress route absent. |
| G56 Local file/line target handler | OS-secondary openInTarget/citations | AssistantMarkdown only http/https | MISSING | No IDE target/cwd/file-line path. |
| G57 Account state/route/readback | OS-settings login/welcome/logout + P | Read-only diagnostics/no auth route | MISSING | Fresh paired runtime confirms precondition divergence. |
| G58 Preferences route/persistence | OS-settings General/Appearance/keys/locales | No full route/preference store | MISSING | Execution overrides/Runtime data are separate. |
| G59 Terminal tab/process ownership | OS-dev canOpenTerminalPanelTab/launchTerminal | Output viewer only | MISSING | No interactive terminal or background-terminal management. |
| G60 Worktree/environment/Git lifecycle | OS-dev/OS-changes local provision/actions/mutations | cwd/metadata/readonly diff | MISSING | Three missing product workflows, not represented by raw directory strings. |
| G61 Popover entry/exit continuity | OS-motion Transition-TpKe3L scale/opacity enter/exit | CodexPopover OverlayEntry insert/remove | RE-DESIGNED | No equivalent entry/exit animation or interrupted transition lifetime. |
| G62 Hover/focus transition timing | OS-motion base150ms/ease, but OR-new login controls compute transition all0s | buttons/sidebar80ms easeOut; composer120ms easeOut | UNKNOWN | Active equivalent component/variant/property must be resolved. Token existence is not an applied duration; do not universalize150ms or add motion by design. |
| G63 Reduced-motion predicate | OS-motion data-reduced-motion animation gates | No equivalent end-to-end preference mapping found | UNKNOWN | TickerMode for inactive widgets is a different contract; check platform/accessibleNavigation before changes. |
| G64 Icon/asset role mapping | OS-side/OS-composer shipped role-specific glyphs | Material Icons/Native own mark | APPROXIMATED | Many glyphs approximate shape; no proprietary assets/logo copied; intentional unofficial branding excluded. |

## Cross-cutting state and interaction checkpoints

These16 checkpoints explain State/Interaction statuses; they are not a new
percentage denominator or a Cartesian explosion of imagined edge cases.

| State / combination | Source/Native observation | Evidence boundary / status |
|---|---|---|
| Cold empty + unauthenticated | Official login, Native connected Home at3 sizes | DR-new DIVERGED; not signed-in Home. |
| Initial loading | Official startup-loader/shimmer; Native RuntimeStatusScreen/card | Source-level composition differs; transient sequence not frame-timed. |
| Selected/hovered project/thread | Selected row/context anchors mapped in source | Retained Native use, H1 static only; all official status/hover branches not closed. |
| Keyboard focused versus pointer hover | Native Focus/MouseRegion exist; command scope differs | Native Tab focuses attach; official synthetic Tab inconclusive. No generic focus convergence. |
| Empty/typing/multiline/disabled composer | Home/desktop/compact use different predicates | NR-new + source; default empty Home action appearance is not proof of accepted invalid input. |
| Streaming + formatted blocks | Native raw branch then Markdown swap | Source-confirmed loss; no new signed-in temporal comparison. |
| Running + pending approval/question | Stop arm/IME/request precedence exists | Official2s confirmation and ordinary request interrupt must be respected; reject peer's universal single-Escape/dismiss assumption. |
| Queued/waiting/edited/removed input | Only presence admission/Steer subset | Queue editor/preferences states missing. |
| Interrupted/error/retry/continue | Strong typed Native guards/retained runs | Complete official lifecycle/error/dismiss sequence unpaired. |
| Disconnected/restored + unsent editor | Native bounded mounted recovery and explicit reconnect | NR-retained; official crash/restart experience unavailable. |
| Saved history + paging + return | Bounded windows/bookmarks and one expanded detail | Runtime/native history proof does not establish identical official scroll/selection/anchor experience. |
| Wide→narrow→wide + pending drafts | Legacy compact flag and local state reconstruction | Source/NR-new; ordinary saved-thread draft-loss run not established here. |
| Light/dark + focused/error/menu | Native system-theme tokens and retained dark captures | No matched signed-in official dark/control variant, no appearance route. |
| Goal/Changes/task coexistence | Native bool toggles/parked drafts, official tab registry | Do not confuse one visible pane with missing registered tab retention; exact combined variant/caller open. |
| Approval+question+Goal+multiline at normal height | Tall stack and <560 admission deserve scrutiny | Existing short-split combined test retained; proposed max-height arithmetic is not a reproduced overflow or a normative state. |
| App restart + preferences | Official sidebar-width stored; Native scalar reset | Confirmed source persistence loss; per-thread editor draft and other keys require individual tracing. |

## F — Motion convergence, independently assessed

Official current source sets basic150ms/ease, moderate200ms, relaxed300ms and
streaming-text700ms; popover `.Transition-TpKe3L` entry350ms from scale.95,
exit200ms to scale.95 with separate cubic-enter(.19,1,.22,1) and
cubic-exit(.8,0,.4,1). These are **source values**, not measured frame timings
for every active official variant. Native overlays insert/remove immediately,
button/sidebar hover80ms easeOut, composer120ms easeOut, disclosure160ms and
message disclosure150ms. Native Flutter dialog/tooltip defaults do not prove
the corresponding official motion was translated. **OR-new login controls all
compute `transition: all 0s`**, despite the global150ms token. Do not treat a
base token as the applied duration for every component, state or property.
Adding guessed animations would be redesign, not convergence.

No complete surface motion contract is certified. No frame-timed paired
authenticated transition was run. Missing source/active-variant facts are
UNKNOWN, not an invented target duration. Reduced-motion behavior also needs
its own source/Native mapping; existing TickerMode does not establish parity.

## H — Runtime differential evidence and limits

| Scenario | Official run | Native run | Comparison / verdict |
|---|---|---|---|
| Credential-free cold start1191×865 | actual sign-in; DOM shell=false, DPR1 | connected Home, shell/sidebar/composer | DR-wide: reproduced onboarding divergence, not an authenticated conversation comparison. |
| Same precondition820×865 | same login, centered340px actions | Home with wide shell | DR-normal: same divergence; dimensions now exact. |
| Same precondition700×800 | same login | old compact sidebar/conversation branch | DR-narrow: same divergence; Native branch loss also confirmed in source. |
| Native Home typing → Ctrl+K | no matching signed-in official route available | typed `audit` remains; no sidebar search opens | Native-only runtime + source focus-scope finding; not paired keyboard-converged. |
| Official Tab/focus | synthetic Tab did not establish focused control in DOM | Native Tab focuses attach control | Inconclusive cross-product focus test; no generic keyboard failure/parity claim. |
| Signed-in A/B/C/D/E/F/G states | unavailable in isolated official profile | retained source-bound Native packets exist | No current matched product differential. CSS specimens are not a substitute for official product states. |

Initial official wide/normal PNGs were860px high because the window extended5px
beyond the960px Xvfb screen. The originals remain; moving the owned window to0,0
and recapturing produced exact1191×865 and820×865 pairs. This is an audit setup
correction, not a product geometry fix. `Browser.getWindowForTarget` also returned
`Browser window not found`; isolated X11 positioning was used instead. No
application implementation changed. App/Host/stock/official/Xvfb owned PIDs were
checked gone in the evidence packet; all profiles are private and credential-free.

## FALSE_CONVERGENCE_FINDINGS

| ID / false-completion pattern | Actual evidence and severity | Correction to the claim |
|---|---|---|
| FC01 Protocol works → Desktop converged (types1/4) | Former19 functional VERIFIED rows had P/NR/NT but no full official Desktop comparison. F06/F10 additionally have source-confirmed loss. | Keep stock integration proof; reclassify full contracts to17U +2P, never infer official experience from RPC success. |
| FC02 Token geometry → rendered parity (types2/3/7) | Former V01 used52+288/672 logical metrics. H1 zoom/DPR/preferences unknown; dynamic/sidebar persistence and compact branches differ. | Preserve narrow scalar DT atoms; no whole-frame visual/runtime pass. |
| FC03 One closed Changes screenshot → persistent product (types3/4/8) | Live snapshot clears on bind; saved/workspace readback absent, open pane variant not paired. | Previous V02 is only an ephemeral live-turn affordance subset. |
| FC04 Final Markdown → streaming parity (types1/6/7) | AssistantMarkdown/ReasoningMarkdown `!completed` use raw SelectableText; entry.completed controls real product call sites. Official source has streaming formatted blocks/fade. | PARTIAL F10/S30/S31; source-confirmed, not claimed fresh authenticated runtime reproduction. Preserve bounded parse policy while planning translation. |
| FC05 Enum/widget presence → all states (types2/3/5) | CodexInteractiveState appears only at its declaration; it is not an enforced state matrix. Existing primitives separately implement some states. | Inventory actual visibility/focus/disabled/loading/error combinations, not enum member count. |
| FC06 Styled popover → translated motion (types5/6) | Native OverlayEntry insert/remove is immediate; official Transition-TpKe3L has distinct entry/exit/interruption states. | Source translation RD for this lifecycle; no motion pass from a post-settle screenshot. |
| FC07 Compact route exists → Desktop state continuity (types3/7/8) | hasDesktopShell defaults false in compact constructor; source and NR-new show legacy chrome. Width/collapse/Goal state have different ownership. | Preserve controller correctness but classify structure/state partial/diverged; exact official active compact predicate still needed. |
| FC08 Shortcut text → matching operation (types1/4/6) | Official Electron Cmd+K opens command menu; Native K searches threads only under sidebar focus. Native Home key run leaves query unopened. | Distinguish command semantics, platform and focus ancestry. NewTask Ctrl+N also differs in scope. |
| FC09 One history number → correct key scope (types5/6) | Official navigateBack brackets/mouse and navigateBrowserBack Alt keys are separate commands. | Reject conflation of missing browser Alt binding with broken existing app history. Preserve old contradictory prose as history. |
| FC10 Matching960 literal → same pane predicate (types2/6) |Full caller trace now shows official workspaceWidth=main+left viewport, plus visibility/720 gates and resize close/reopen. Native tests main-only at open time. |G36 downgraded DT→AP.499 sizing alone was insufficient; accepted full trace proves source loss in coordinate/gating/effect, not a live screenshot result. |
| FC11 One scalar composer controller → per-thread drafts (types4/7/8) | Ordinary wide switch retains text in one controller; offstage switch clears it, attachments clear absent replacement preservation. | Source-confirmed ownership/retention gap and P0 data-loss risk; official composer-draft scope and current saved-thread repro still need closure. A workspace-draft-tab key alone does not prove composer text ownership. |
| FC12 All tests pass → combined-state space closed (types1/3/8) | ShortViewport<560 gate and tall bottom stack merit a normal combined-state probe. But product_controls_test already has a concurrent approval/question short-split case. | Reject blanket no-combined-tests claim and unexecuted height sums as observed RenderFlex failure. Keep legitimate wide-combination risk UNREPRODUCED. |
| FC13 Motion/persistence names → complete implementation (types5/6) | Sidebar width is widget-local; official qbQ6 reads/writes persistent sidebar-width. Many official UI keys are not represented by a Native store. | Confirm specific per-key gaps; reject unbounded0/60+ statistics mixing non-Codex keys without a defined inventory. |
| FC14 Native branches credited from worktrees (types4/5) |68e2283/22abb4f and47/-2 WIP remain unmerged. | No coverage/convergence credit to main for staged per-item metadata/UI. |
| FC15 Global motion token → applied motion (types3/5/6) | OR-new login controls computed all0s while bundle basic duration is150ms. Native role-equivalent active styles are not yet paired. | G62 is UNKNOWN, not assumed150ms parity or a universal timing bug. Keep variant/property mapping and reduced-motion gates explicit. |


## Counts, denominators and uncertainty

**No overall completion percentage.** Coverage counts counterparts; convergence
counts only complete defined contracts, with source atoms separated from parent
surfaces. A zero certified full-contract numerator is a lower bound on verified
convergence, **not an estimate that the product is0% correct**. Where evidence
cannot establish a true convergence percentage, report the numerator/denominator
and unknown/partial reasons instead of assigning half-credit.

| Metric | Numerator / denominator | Interpretation |
|---|---|---|
| Functional coverage |40/58 (69%)|Counterparts include23 PARTIAL and17 implemented-but-unverified workflows.18 missing. IDs F01–54 retained; additions F55–58 explicit.|
| Functional convergence |0/40 certified complete workflows|True Desktop convergence percentage is not identifiable; do not present lack of certification as proof every path diverges.|
| Surface coverage |24/36 (67%)|Existing counterpart/subset versus12 missing complete routes/surfaces.|
| Surface convergence |0/24 certified complete existing surfaces|No parent surface closes all material hierarchy/state/interaction differences.|
| State convergence |0/24 complete existing surface-state families|Not every widget×state combination. Concrete losses and unresolved evidence are both identified below.|
| Interaction convergence |0/24 complete existing interaction families|Narrow handlers exist; global semantics/focus, combined states and paired sequences remain open.|
| Visual convergence |0/24 complete existing rendered surface families|Previous2 geometry/affordance VERIFIED units were source-only scoped proofs, not full signed-in runtime passes.|
| Motion convergence |0/24 complete existing motion families|No paired frame-timed authenticated sequence; source reveals concrete missing transitions.|
| Source translation coverage |44/64 facets have some counterpart|20 missing facets; UNKNOWN does not count as translated.|
| Source translation convergence |21/44 existing facets DT/FE; 21/64 across inventory|11 DT +10 FE narrow facts; AP/RD/UNKNOWN receive no convergence credit. Parent source certification stays0/24.|
| Runtime differential verification exposure |1/36 surface contracts in one named substate;3 viewport pairs|S01 cold-start only. No complete signed-in implemented family is paired:0/24.|
| Runtime differential convergence |0/1 executed cold-start scenario family|All3 exact-viewport pairs diverge. This denominator is scenarios executed, not the whole product.|

Source ledger distribution: **DIRECTLY TRANSLATED: 11**, **APPROXIMATED: 19**, **FUNCTIONALLY EQUIVALENT: 10**, **MISSING: 20**, **RE-DESIGNED: 2**, **UNKNOWN: 2**.
**17 old VERIFIED workflows are now U; F06/F10 are P after concrete source loss.**
23 PARTIAL workflows include the20 earlier partial rows, those2 reclassifications
and F58.18 absent workflows are the previous15 plusF55–57. Counts are comparable
only with this explicit crosswalk. Independent denominators are never averaged.

## Discovered/conditional/shared surfaces outside the36-row denominator

These are visible inventory boundaries, **not ignored because Native lacks code**.
The36 rows and58 workflows are the defined local Codex/shared-desktop corpus;
they are not the union of all9387 renderer chunks or every ChatGPT mode. Native
absence, official enablement and legitimate support are separate questions.

| ID / discovered surface | Official evidence / Native equivalent | Classification and counting rule |
|---|---|---|
| X01 Embedded browser/preview tabs | OS-shell/browser navigation commands and task-tab source; no complete Native browser host | MISSING Native counterpart; enabled Codex branch/public host contract still needs closure. Not automatically PRIVATE_ONLY. Extend the baseline when scoped; do not count browser Alt commands as app-history failure. |
| X02 Voice/dictation/realtime/audio requests | Composer voice branches + public experimental thread/realtime methods; no Native complete audio lifecycle | MISSING locally; public method adoption versus private first-party call broker must be distinguished. No private relay/broker adoption authorized. |
| X03 Interactive MCP ui:// templates | Public MCP resources and renderer sandbox/template paths; Native text/tool forms only | Host surface MISSING/contract research. Existing tool calls do not implement templates; private first-party resources remain excluded. |
| X04 Rich images/artifacts/viewed/generated media | Official rich item/viewer branches; Native summaries/limited images | Partial subsets already counted under S20/S22/F54. Do not double-count; account-backed artifact/template variants still need support/enablement evidence. |
| X05 Chat/Work/Dot/Space/Sites/billing/profile cloud | Same shipped app has these routes; Native has no independent real backends | Shared-shell/private/deferred outside current Codex scope. Their source presence does not authorize private APIs or fake product selectors. |
| X06 Remote/SSH/cloud controllers | Public host controls versus private relay/cloud controller routes; Direct Host administration retained | Supported host administration is a Settings subset; relay/mobile expansion and private attestation/services remain deferred/excluded. No write parity inferred from read-only Remote. |
| X07 Updater/About/release-specific preferences | Official update/recovery commands and licensing pages; Native packaging/manual workflow | Record separately from functional harness/UI convergence. First-party update service cannot be copied; Native release/installer/signing expansion remains deferred. Settings/license navigation is included in S02, not silently accepted. |

The statement is **18 confirmed missing workflows in the58-row corpus**, not
that exactly18 is the complete count of every possible official feature. These
explicit boundaries and unavailable signed-in states prevent a reliable single
true-convergence percentage. They do not erase the confirmed gaps.

## Three decision lists

### NOT IMPLEMENTED

Functional **F25,F31,F38,F39,F40,F41,F42,F43,F44,F45,F46,F47,F48,F49,F53,F55,F56,F57** are the18 missing workflows.
The explicit row scopes in the reassessment table control. The36-surface inventory has12 missing complete routes/surfaces:
S01–S12. They include account, Settings, terminal, worktree, Git actions, IDE/file
navigation, local automation, environments, inline menus, localization, global
content search and detached windows. Supported/private/experimental boundaries
must be checked before implementation; missing local UI is not a private-service
exclusion. Deferred private Chat/Work/cloud/relay are outside this denominator.

### IMPLEMENTED BUT NOT CONVERGED

- **P0:** Changes live-only source/pane and restart/workspace readback; coding
  activity that lacks per-file disclosure; primary creation/recovery/account
  ordering across the actual Desktop first-use path. Missing neighbors remain
  separately S01–S12, rather than being credited to the existing diff/Review UI.
- **P1:** S14–27 and S32–35: compact branch, shortcut scope, model/default state,
  queue/Plan controls, attachments/rich results, activity grouping, open Review,
  menus/focus and Goal/composer combined states. Their working typed primitives
  remain valuable; completing one default branch does not close the family.
- **P2 / evidence-open:** exact glyph/baseline/wrap/scrollbar/clipping residuals,
  transition/easing/entry-exit, dark/focused/loading variants and physical-platform
  observations. Some visible/interaction loss is P1 rather than final polish;
  unread evidence cannot automatically be labeled P2 or Human-only.

### ACTUALLY CONVERGED — only explicitly bounded subcontracts

No whole36-surface row or whole58-workflow row earns this label. The DT/FE atoms
in G identify the parts safe to retain: measured logical shell/reading dimensions,
user bubble ratio/radius/padding and rendered-height clipping, specific Markdown
block/code/inline-code facts, context-menu anchoring and exact stock-owned typed
responses. Evidence is **official source + Native source**, and where linked,
**Native runtime/clipboard/stock**. They have **no new signed-in official runtime
differential**. Keep these translated parts; do not redo them merely to change
agent ownership. Do not present them as acceptance of their surrounding surface.

## Highest-value next convergence slices — proposed, not started

1. **Onboarding/account contract:** official signed-out → supported stock login,
   cancel/error/readback/expired-session route; establish access without private
   service assumptions. Separate Human account operations from agent measurement.
2. **One coherent shell/compact/keyboard contract:** current official active
   branch, breakpoint units, persisted left width, global focus ancestry and
   routes. Reproduce Native loss; translate after baseline approval.
3. **Changes source + Review/Git composition:** saved/workspace/live scopes,
   bounded per-file readback, empty/error/restart, caller-proved width coordinate
   and resize/open effects, plus correct pane/tab relationship.
   Keep exact Git action/security confirmations separate and source-backed.
4. **Activity/output/per-file contract:** audit preserved68e2283/22abb4f branches
   before any integration, live/saved grouping, lazy output/readback, large diff
   framing and failure states. No branch is merged during this audit.
5. **Composer/controls/queue/Plan/attachments as one state family:** inherited and
   explicit settings, running/queued/stop/error, IME/shortcuts/paste/drop,
   matching open menus and explicit unsupported audio paths.
6. **Routed Settings and local developer surfaces:** preference/configuration
   readback, terminal lifecycle, local environment/worktree handoff. Work in
   independently owned coherent contracts, not unrelated appearance toggles.
7. **Complete project/search/read-state organization:** global versus scoped
   search, auto viewed-state acknowledgement, persistence and bounded catalog
   navigation without pretending the working set is an unlimited catalog.
8. **Customization/results lifecycle:** installed scope versus catalog,
   tool/auth/elicitation outcomes, rich saved content, source-matched details and
   bounded optional local app UI; private account/cloud flows remain excluded.
9. **Motion and differential pass per closed state:** measure entry/exit,
   reduced motion, hover/focus, stream/scroll and resizing; then close matching
   light/dark/compact variants. Do not optimize guessed durations.

The biggest issue is the combination of **source translation loss + incomplete
state/interaction closure**, alongside significant missing workflows. Runtime
verification shortage prevents precise full-convergence certification. This is
not chiefly a typography/spacing finishing pass, and it does not justify
throwing away the bounded architecture or verified stock integration.

## Peer challenge, validation and stop

Independent Gemini challenge runs only through official `agy`1.5.1 PTY19573.
Gemini may inspect source and audit artifacts, not implement or merge. Codex
accepts/rebuts each claim on evidence; neither identity confers authority.

The official TUI returned **CONCUR with publishing the canonical baseline and
STOPPING after documentation commit/push for Human confirmation**. It did not
claim a current signed-in runtime comparison. Peer source-only note is summarized without proprietary code snippets
as [historical challenge](../history/GEMINI_FULL_CONVERGENCE_CHALLENGE_2026-11-12.md),
SHA256 `d5f88c98f513489de6cd34f42823e0dc74f55021fd80be4fd823d0d6a8646d99`. Its provisional counts/line numbers are superseded here.

| Peer claim / challenge | Codex disposition and evidence |
|---|---|
| Raw live Markdown then completed renderer swap; missing exit motion/persistence | Accepted from current source and real product call sites; not called a fresh paired signed-in runtime trace. |
| G36 same960 must be DT;499 helper alone proves split | Rejected both shortcuts. Accepted strengthened full caller proof: main+left coordinate, visibility/720 conditions, default split flags and resize close/reopen. G36 is AP. |
| G27 unknown140px lookup | Resolved from8.75rem and status/mask/height-transition source. AP, not merely a fixed scalar mismatch. |
| G28 elapsed reasoning unknown | Accepted FE only for live mounted transition/caption; no whole reasoning-state or temporal differential pass. |
| G37/G42 broad FE | Narrowed to Goal typed mutations and passive settings readback; UI tray and picker predicates stay partial. Advanced effort fallback disproves global inability to change effort. |
| Double-Escape stop is invented | Rejected/retracted:309406.tL/WO implements2s confirmation. Broader priority chain remains incomplete. |
| Ordinary question Escape should only dismiss | Rejected/retracted:474578.IpGh.to conditionally replies empty or interrupts. Native ordinary interrupt is a supported branch. |
| Composer MediaQuery causes wrong adaptive layout | Rejected/retracted:that read chooses shadow only; actual layout has separate width predicates. Home legacy composer branch is a valid surviving finding. |
| No combined tests / exact max-height overflow /0-of60+ persistence | Rejected as blanket/measured claims; existing concurrent test retained, layout arithmetic risk UNREPRODUCED, only individually traced preference keys count. |
| Stale Home text/line references | Corrected against current source and NR-new. No duplicate implementation of already translated U7 clipping scheduled. |
| Draft ownership loss | Native source behavior accepted, no current saved-thread runtime repro. Official composer ownership must be traced separately from a workspace-tab storage key; retain this boundary. |
| Motion basic150ms universally applied | Root further calibrated from OR-new:login controls compute all0s. G62 UNKNOWN; do not insert guessed motion. |

This is adversarial evidence reconciliation, not acceptance by agent identity.
No original owner code or47/-2 U9 WIP was touched. Proposed slices remain frozen.


Only audit documents/evidence are changed. Final checks cover scope, source
identity, IDs/status/count arithmetic, links and diff. Existing Native tests and
builds are retained evidence, not rerun to improve the baseline or called
differential convergence. Publication CI is tracked for its exact HEAD;
network/install failures are kept distinct from code tests. No CI hardening is
part of this audit.

**STOP AFTER COMMIT/PUSH — WAIT FOR HUMAN CONFIRMATION OF CONVERGENCE BASELINE.**
No implementation or further branch round resumes automatically.
