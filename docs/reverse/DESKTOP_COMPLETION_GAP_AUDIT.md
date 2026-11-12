# Desktop Completion Gap Audit

> Superseded for convergence by [Full Desktop Convergence Audit](DESKTOP_FULL_CONVERGENCE_AUDIT.md).
> This document remains the prior coverage inventory and historical evidence
> index. Its VERIFIED labels are narrow implementation/stock proofs, not current
> Desktop-convergence certification. New functional additions and all eight
> dimensions are assessed in the new canonical audit; implementation is paused.

Audit date: **2026-11-12**. Audited delivery baseline:
**`0e2a5b80464f7ab6e3f5ab9034e9c37ecf6593ec` (main/origin/main)**.
Mode: `SELF_ITERATION`, **audit only; implementation paused by the user**.

The replica is **not Desktop-complete**. The remaining work includes entire
missing workflows and surfaces, incomplete state/data paths, and structural
fidelity differences. It cannot be described as only polish or a whole-screen
Human review gate. **Do not design. Translate.**

## Authority, scope and method

This is the authoritative **cross-layer completion inventory** for this audit
baseline. It uses, rather than replaces, the existing project progress:

- [Functional audit](CODEX_DESKTOP_FUNCTIONAL_AUDIT.md): versioned schemas,
  adapters, supported scope and source-bound stock experiments.
- [Feature matrix](OFFICIAL_FEATURE_MATRIX.md): capability backlog and history.
- [Golden State A](OFFICIAL_UI_GOLDEN_STATE_A.md): current A0–A11 evidence and
  detailed translation history. Earlier R0 statuses are not inherited blindly.
- [Structural mapping](OFFICIAL_UI_STRUCTURAL_MAPPING.md),
  [translation plan](OFFICIAL_UI_TRANSLATION_PLAN.md),
  [component matrix](OFFICIAL_COMPONENT_MATRIX.md), architecture and ADRs.

Source and actual Git override stale prose. At audit start `PROJECT_STATUS.md`
still named main `ba6f27c` and final integration/CI pending; actual main was
`0e2a5b8`, exact [CI43203383623](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43203383623)
successful. `UI_REFERENCE.md` also contains historical 240/720 px and a missing
detail-toggle claim; current production has different measured geometry and a
detail projection. Those old statements are not current completion evidence.

Inspect in both directions: official surface → Native route, and Native
route → controller → adapter → stock behavior. A request name, existing widget,
or passing test does not establish a complete workflow. Functional verification
in one row does not verify that row's visual appearance or every related state.

### Reference and evidence keys

- **O**: installed official Desktop `26.1103.60933`, build `25894`; ASAR SHA256
  `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`, freshly
  rechecked unchanged. H1 is the supplied signed-in 1191×865 light screenshot.
  ASAR/CSS/component findings are measurements, not copied implementation.
  Static presence does not prove a feature is enabled for every account.
- **P**: installed stock `0.167.0-alpha.3.2` and public stock `0.167.2`, versions
  freshly rechecked. Official release API still names
  [rust-v0.167.2](https://github.com/openai/codex/releases/tag/rust-v0.167.2)
  latest. Existing exported schemas: 106 stable + 74 experimental-only client
  requests; 10 + 1 server requests; 86 server notifications. These are **method
  counts, never product completion percentages**.
- **D-terminal**: [official integrated terminal](https://learn.chatgpt.com/docs/integrated-terminal).
- **D-local**: [official local environments and Git controls](https://learn.chatgpt.com/docs/environments/local-environment).
- **D-worktree**: [official local Worktree creation/handoff](https://learn.chatgpt.com/docs/environments/git-worktrees).
- **D-settings**: [official preferences](https://learn.chatgpt.com/docs/reference/settings)
  and [developer settings](https://learn.chatgpt.com/docs/developer-settings).
  These are current public docs; where newer than build25894, live build/enablement
  still needs checking before exact translation. Cloud implementation is not
  authorized merely because a shared app page mentions it.
- **R**: source-bound packaged/stock evidence already preserved in the linked
  per-workflow documents. Re-read and checked against retained source, **not
  represented as newly rerun in this audit**.
- **A-run**: fresh audit-only Linux run, frozen packet source `5dd4758` whose
  `lib/native_host/linux/windows/macos/pubspec` production inputs have no diff
  from main `0e2a5b8`. Real bundled Host + public stock0.167.2; isolated empty
  HOME/CODEX_HOME, no supplied account credentials. Home, real plugin catalog,
  1191×865 / 820×865 / 700×800 were inspected. Packet:
  `/var/tmp/native-desktop-gap-audit-runtime-r1/verification.json`, 12 captures.
  App1636716 / Host1636947 / stock1636949 exited; helper reports process-tree
  cleanup. This is **AGENT REAL-USE**, not a signed-in official comparison.
  Synthetic menu/runtime clicks were inconclusive; screenshots from those
  attempts do not establish broken mouse or keyboard behavior.
- **C-large**: controlled Host protocol-process negative, **not stock emission**:
  `/var/tmp/native-file-diff-aggregate-negative-r1/verification.json`.
  Branch Host0d1bf34 forwards a 9 MiB item as407 bytes, then exits1 on ≥12 MiB
  aggregate `turn/diff/updated`: `sanitized app-server message exceeds 8388608 bytes`.
  Main's old Host separately rejects the large item itself. Public0.167.2
  `core/src/turn_diff_tracker.rs` concatenates content-exact patches and
  app-server forwards the aggregate; no source cap closes this boundary.
  This proves the client boundary failure, not its frequency on real repositories.

### Categories and reading the tables

**MISSING**: absent official workflow/route. **PARTIAL**: incomplete closure,
including identified evidence-open state paths. **FIDELITY GAP**: functional
subset exists but composition/interaction differs materially. **POLISH**: only
non-structural details remain. **VERIFIED**: the explicitly named subset has
official/stock evidence **and actual runtime evidence**. Tests alone never earn
VERIFIED. `PARTIAL (evidence open)` does not assert a reproduced product bug.

Priority: **P0** absent/broken primary workflows; **P1** partial workflows and
obvious high-frequency fidelity gaps; **P2** polish/rare states. `—` means no
known gap in the narrowly verified subset. Conditional/private boundaries below
are not silently counted as supported missing parity.

## F — Functional workflow matrix

Every row is scoped to the audited main. Visual differences are separate in S/V.

| ID | Official workflow / current Native access | Category | Priority | Evidence, actual delta and next closure check |
|---|---|---|---|---|
| F01 | Process discovery, handshake and normal shutdown; Runtime | VERIFIED | — | P/R; `ProcessTransport`, Host locator, runtime controller and real-process smokes. No claim of physical Windows/macOS execution. |
| F02 | Failed first startup → explicit Retry | VERIFIED | — | P/R [startup](STARTUP_RETRY_EVIDENCE.md); same-app retry after executable availability works on both stock versions, with failed-child retirement. |
| F03 | Connected process exit → draft retained → reconnect | VERIFIED | — | P/R [recovery](WORKSPACE_RECOVERY_EVIDENCE.md); public/installed empty/active recovery, no implicit writes/replay. Official automatic-recovery policy is not claimed. |
| F04 | New chat → empty history → first saved turn | VERIFIED | — | P/R [new thread](NEW_THREAD_HISTORY_EVIDENCE.md); creation/materialization fence, first Send, cold restart. |
| F05 | Open/select/resume ordinary local saved thread | VERIFIED | — | P/R; thread gateway/sidebar/history. Foreign-provider resume is F23. |
| F06 | Switch threads and shell Back/Forward | VERIFIED | — | O/R Golden A0/recovery; bounded visits and actual stock selections. General workspace tabs are S05. |
| F07 | Paginated thread/turn/item history | VERIFIED | — | P/R; bounded history and actual saved replay. No full-history residency or unlimited section claim. |
| F08 | Long-thread position restoration across eviction/restart | PARTIAL | P1 | O/P; bookmarks and lazy history exist, but ordinary prior captures do not establish the complete long-history restore/anchor path against official. Compare middle-history paging, warm/cold return and changed layout. |
| F09 | Rename/archive/unarchive/delete | VERIFIED | — | P/R thread smoke + reachable row actions. Destructive user confirmation remains; audit deletes no user data. |
| F10 | User Send → streaming assistant → complete | VERIFIED | — | P/R real stock turns; bounded/coalesced projection. Token-by-token account behavior is not inferred from loopback models. |
| F11 | Follow-up while running: steer versus durable queue | PARTIAL | P1 | P; steer is wired, but queue management and user preference are incomplete (F40/S18). Verify interruption/failure between admission and acknowledgement. |
| F12 | Stop/interrupt and stopped outcome | VERIFIED | — | P/R packaged running Stop produces stock interrupted outcome; retirement fences retained. |
| F13 | Failure/retry/continue/edit/regenerate combined lifecycle | PARTIAL | P1 | P; reachable turn actions and simulated cases, but no one artifact establishes every packaged failed/cold/branch/attachment continuation. Audit the full action chain, not only action presence. |
| F14 | Fork/revert/explicit harness compaction | PARTIAL | P1 | P + existing smokes; Native controls exist. Stock revert does not undo workspace files; same-state official action/confirmation and full product-chain evidence remain open. |
| F15 | One-time command/file approval or refusal | VERIFIED | — | P/R [approval](APPROVAL_CHOICES_EVIDENCE.md); exact request authority and no grant on merely opening/dismissing controls. |
| F16 | Advertised session/rule/cancel decisions | VERIFIED | — | P/O/R eight public/installed probes plus packaged rule menu; exact persisted prefix and repeated command. This subset excludes F17/F18. |
| F17 | Managed-network approval outcomes | PARTIAL | P1 | P/O; typed scoped choices exist, natural supported emission and distinct network outcomes unverified. Reproduce before declaring closed; no private service. |
| F18 | Structured additional permissions | PARTIAL | P2 | P; adapter intentionally refuses and drops grant profile. Emitting feature flags are under-development/off by default; establish adopted public emission before permission implementation. |
| F19 | Structured request-user-input options and steps | VERIFIED | — | P/O/R Golden A10; real stock Continue/Submit and answers; Escape/explicit cancellation remain distinct from H1 async input. |
| F20 | MCP elicitation including unsupported/error/cancel | PARTIAL | P1 | P; bounded form/URL paths exist, unsupported shapes fail truthfully. Full successful packaged form/URL lifecycle and official presentation are not established by simulated tests. |
| F21 | Explicit + acknowledged loaded model/reasoning/permissions | VERIFIED | — | P/R [inherited settings](INHERITED_SETTINGS_EVIDENCE.md); actual Start/Resume/Fork/notification, cold unknown, no catalog-default inference. |
| F22 | Home/current-cwd effective settings before first Send | PARTIAL | P1 | P; neutral unknown labels are truthful but no cwd-scoped effective preview. `config/read` exists; verify resolved values without cold resume. |
| F23 | Provider mismatch / model catalog failure and recovery | PARTIAL | P1 | P/R [provider](THREAD_PROVIDER_SCOPE_EVIDENCE.md); cross-provider title discovery/read works; actual foreign resume rejects. Dedicated supported provider recovery/editor is absent; no silent config switching. |
| F24 | Saved-title and within-thread occurrence search | VERIFIED | — | P/R [occurrences](THREAD_SEARCH_OCCURRENCE_EVIDENCE.md); explicit bounded scopes. Not global message search. |
| F25 | Global saved-message content search | MISSING | P1 | P/O; experimental `thread/search` exists/caller documented; no Native request or route. Re-probe result/cursor scope, then implement bounded search. |
| F26 | Goals get/set/pause/clear and notifications | VERIFIED | — | P/O/R Goal walks; quick actions/editor now exist. Old management-dialog-only claim is stale; terminal variants/tab fidelity remain S16. |
| F27 | Review target → running → result/failure | PARTIAL | P1 | P/O; all four targets now reachable, contrary to old uncommitted-only F14 summary. Smokes and real review exist; full target/state product and inline/detached presentation agreement remain open. |
| F28 | Bounded Sections/Pinned CRUD/move | VERIFIED | — | P/R sections/thread smoke and reachable menus. Global working-set bounds are deliberate, not an unlimited per-section catalog. Project metadata/batch actions are S03. |
| F29 | View → focus/latest-visible automatic read receipt | PARTIAL | P1 | O/P; manual revision-aware action exists; automatic visibility admission absent. Selection alone must not acknowledge unseen turns. |
| F30 | Live turn Changes and bounded file/hunk inspection | PARTIAL | P1 | P/O; `DiffController` accepts only live TurnDiffUpdatedEvent. Normal bounded rendering works, large payload boundary C-large and official open pane remain unclosed. |
| F31 | Saved/restarted/workspace Changes source | MISSING | P0 | O/D-local; `DiffController.bindThread` clears snapshot; no readback/Git workspace source. Reopening edited work can lose the Changes path although timeline history loads. Reproduce same repo before translating the complete pane. |
| F32 | Per-item/per-file live + saved patch disclosure | PARTIAL | P1 | O/P; main has kind-aware captions, but no typed file list/lazy read/binding. Aggregate-as-item was correctly removed. Branch-only work below is not delivered parity. |
| F33 | Command/activity and live/saved lazy output | PARTIAL | P1 | O/P/R U8; completed Shell numeric exit/output preview and lazy full output work; in-progress output delivery and complete saved/expanded hierarchy remain open. `deferOutput` acceptance is not proof of upstream laziness. |
| F34 | Skills discovery/toggle/attach | VERIFIED | — | P/R ecosystem/MCP smokes and packaged Customize. Only the supported bounded local subset, not all creation/marketplace UI. |
| F35 | Plugin catalog/install/read/uninstall/installed inventory | PARTIAL | P1 | P/R/A-run; actual catalog visible, caps/partial errors disclosed. `plugin/list` is not authoritative `plugin/installed`; install/auth/background-sync scopes remain incomplete. |
| F36 | Apps/MCP tools/resources and saved rich results | PARTIAL | P1 | P/R; typed local calls exist; saved structured/media disclosure and complete account-backed install flow do not. Text summary is not a rich result surface. |
| F37 | Configured MCP OAuth launch/completion/readback | VERIFIED | — | P/R [OAuth](MCP_OAUTH_ACCESS_EVIDENCE.md); installed/public PKCE, navigation/resize and persistence. Successful controlled OAuth is not arbitrary provider-account acceptance. |
| F38 | Native account login/cancel/logout/expired-session recovery | MISSING | P0 | P/O/A-run; only read-only account diagnostics. No `account/login/start`, cancel or logout adapter/route. External `codex login` is a workaround, not Native onboarding. |
| F39 | Workspace file autocomplete/mention lookup | MISSING | P1 | O/P [file lookup](WORKSPACE_FILE_SEARCH_EVIDENCE.md); manual attachment path exists; fuzzy/session lookup absent. Bound session lifetime/results/exclusions before wiring. |
| F40 | Durable queued prompt inspect/edit/remove/reorder | MISSING | P1 | O/P [queue](QUEUED_SUBMISSION_READBACK_EVIDENCE.md); only queue-presence admission is implemented. No queue management surface; do not claim queue parity. |
| F41 | Interactive project/worktree terminal | MISSING | P0 | O/D-terminal; output viewer and agent `read_task_terminal` caption are not a user terminal. No terminal route, PTY ownership, tab or input/lifecycle. Research supported host boundary first. |
| F42 | Local Worktree create/branch selection/handoff | MISSING | P0 | O/D-worktree; cwd/thread metadata is not app-managed checkout creation/handoff. No equivalent Native entry/lifecycle. Existing Git worktrees used by agents do not implement the product feature. |
| F43 | Git stage/revert chunk/file, commit/push/PR actions | MISSING | P0 | O/D-local; read-only turn diff, Review and attached PR links do not implement these actions. Establish supported local Git worker equivalents and confirmations; private hosted PR service remains excluded. |
| F44 | Local/thread automation create/edit/schedule/results | MISSING | P1 | O; rail/component evidence and compact label, no Native scheduler/management route. Determine supported local persistence/runtime contract; cloud scheduling APIs are not authorized fallback. |
| F45 | Client language/localization behavior | MISSING | P1 | O/H1 Chinese labels; no app locale/delegates/catalog, hard-coded English. Rendering Chinese model text does not localize the client. Inventory actual official selector/system fallback. |
| F46 | Local environment setup scripts and reusable actions | MISSING | P1 | O/D-local; no settings/actions route or execution/readback chain. Not equivalent to a prompt asking the agent to run commands. Requires terminal/worktree lifecycle. |
| F47 | Remove a stored linked review/PR reference | MISSING | P1 | P/O [unlink evidence](THREAD_ATTACHMENT_UNLINK_EVIDENCE.md); add/list exists but no remove adapter/control. Exact identity deletion has no revision precondition; stale replacement/foreign-thread safety needs explicit readback. |
| F48 | Open in IDE and navigate workspace file/line references | MISSING | P1 | O `openInTarget`; Native assistant links accept only http/https, no IDE/file launcher. An external web link is not a local file/line access path. |
| F49 | Inline slash commands and contextual @/$ completion | MISSING | P1 | O composer components; no keystroke-triggered command/file/skill popover. Sidebar menus/manual attachment are narrower alternatives, not equivalent keyboard workflows. |
| F50 | Select Plan/Default mode and act on an interactive plan | PARTIAL | P1 | O/P `collaborationMode`; plan/todo output can render, but no composer mode selection or complete plan-accept/implement path. A displayed plan is not mode control. |
| F51 | Select Fast/service tier and project acknowledged state | PARTIAL | P1 | O/P; service tier is read-only diagnostics, no composer speed control/turn override. Establish model/runtime support, entitlement/error and inherited acknowledgement. |
| F52 | Native file/folder drop and clipboard image paste | PARTIAL | P1 | O; manual bounded attachment/source/preview exists, drag/drop and image-paste ingestion are absent. Verify platform/size/error/cancel independently of text paste. |
| F53 | Inspect/clean up stock background terminals | MISSING | P1 | O/P experimental `thread/backgroundTerminals/*`; no adapter/control. Confirm deliberate supported adoption before implementation. Different from killing the app Host or viewing a completed command. |
| F54 | Rich sub-agent/image/hook/auto-review activity | PARTIAL | P1 | O current components; summaries exist, complete child-thread drill-down, generated/viewed image disclosure, hook-stats/guardian paths do not. Public supported emitted variants require bounded typed mapping. |

## S — Complete surface/entry inventory

These are **surface existence/structure**, not another functional percentage.
Missing official surfaces are listed even when Native has no corresponding file.

| ID | Official surface → Native route | Category | Priority | Remaining structural/entry gap and evidence |
|---|---|---|---|---|
| S01 | App/window strip → shell File/Edit/View/Help | FIDELITY GAP | P1 | O/A0; bounded navigation exists, OS decoration/menu mnemonics/platform arrangement and complete official actions differ. |
| S02 | Global rail/account footer → Home/Customize/Remote/Runtime | PARTIAL | P1 | O/A1, actual enum only `home, customize`; account/notification/automation destinations cannot be represented as completed rail parity. |
| S03 | Contextual sidebar/project menus → loaded directory groups | PARTIAL | P1 | O/A2; organize/remove/project metadata/batch routes absent; private Dot/notification roles separated. |
| S04 | Thread rows/context menus → real bounded thread list | FIDELITY GAP | P1 | O/A3; hover/selection/36px/group alignment implemented. Real merged-PR state unavailable; automatic unread behavior incomplete F29. |
| S05 | Workspace tabs/New tab → conversation, Goal and Changes | PARTIAL | P1 | O/A5; no general task/tab launcher or Terminal/browser/file tab; link affordance and bounded Goal tab are only a subset. |
| S06 | Assistant/user reading + attachment preview | FIDELITY GAP | P1 | O/A6; bounded Markdown, 70% bubble, code Copy exist; external attachment pills/hover/selection and matched signed-in typography/hierarchy remain open. |
| S07 | Thought/activity/read-run groups and expanded cards | PARTIAL | P1 | O/A7/U8; per-item patch missing in main, live output and expanded/completed grouping not closed. |
| S08 | Changes closed affordance + open pane | PARTIAL | P0 | O/A8/D; closed affordance accepted subset; open pane/source, history/workspace and Git actions incomplete F30–43. |
| S09 | Review target/running/result/inline comments | PARTIAL | P1 | O/E + D-settings; four target dialog exists; actual official tab/inline/detached/results interaction not closed. |
| S10 | Login/account switch/logout/expired account | MISSING | P0 | O/P; read-only diagnostics cannot replace account product surface. |
| S11 | Settings General/Appearance/keyboard/notifications | MISSING | P0 | O/D-settings; only runtime and execution dialogs. System theme fixed; no preferences navigation, language/font/theme choice or shortcuts editor. |
| S12 | Integrated terminal/tab | MISSING | P0 | O/D-terminal/F41; lazy command output dialog is a different surface. |
| S13 | Local/Worktree chooser, branch/handoff and environment actions | MISSING | P0 | O/D-worktree/D-local; not a cwd text field. |
| S14 | Git working-tree review/stage/commit/push/PR | MISSING | P0 | O/D-local/F43; no action entry. |
| S15 | Global content search result list | MISSING | P1 | O/P/F25; thread title/occurrence search has narrower scope. |
| S16 | Goal tray/quick actions/editor/terminal states | PARTIAL | P1 | O/A9; quick actions are implemented. Simultaneous task-tab chrome and finished/exhausted/error variants not matched. |
| S17 | Pending questions/Other/free text/voice | PARTIAL | P1 | O/A10; typed option steps work, async free-text/voice not equivalent; explicit cancellation and narrow Other fallback differ. |
| S18 | Composer + model/reasoning/execution menus | PARTIAL | P1 | O/A11; measured non-dictation/adaptive branch implemented. Home inherited values, open-state grouping, send preference/queue behavior/voice are incomplete. |
| S19 | Attach menu, file lookup, source/image preview | PARTIAL | P1 | O/P; manual bounded paths and saved attachments work; local autocomplete/drag-paste/native picker/IDE context require distinct verification, not a generic attachment checkbox. |
| S20 | Customize Skills/Plugins/Apps/MCP/detail/auth | PARTIAL | P1 | O/A1/A-run; real catalog route exists. Installed scope, rich result/UI, matching cards/detail states and account-backed paths remain incomplete. |
| S21 | Automation list/editor/schedule/result inbox | MISSING | P1 | O/F44; compact `Automations & Skills` currently opens only ecosystem. Misleading entry is observed in A-run/source, not an implemented Automation page. |
| S22 | Browser/preview/file/artifact task tabs | MISSING | P1 | O component/tab evidence; no Native host/navigation route. Distinguish supported local file/browser path from private cloud artifact APIs; establish enabled official Codex variants before implementation. |
| S23 | Wide/normal shared shell geometry | VERIFIED | — | O/A4 + measured Native captures: shared surface, 52+288 default left region, 672 reading cap. Only geometry/roles, not full wide-screen acceptance. |
| S24 | Signed-in Home, compact and dark variants | FIDELITY GAP | P1 | O/B/F/G; Native states render, but no matched signed-in state closure. A-run700 still shows older contextual hierarchy. Do not turn these into a generic Human-only gate. |
| S25 | Header Open-in-IDE and clickable local file/line routes | MISSING | P1 | O/P/F48; no Native target launcher; web-only Markdown links cannot open a local citation. |
| S26 | Inline command/mention/skill menus and Plan/Fast controls | MISSING | P1 | O/P/F49–51; manual attach and static plan activity don't implement these composer entry surfaces. |
| S27 | Detached thread/diff windows, quick overlay and tab docking | MISSING | P2 | O renderer routes/components; Native single-window has mutually exclusive Goal/Changes. Establish enabled variants before claiming exact platform parity. |

## T — State/error coverage matrix

State rows apply to the named path; they are not the Cartesian product of every
widget and every viewport. The latter has not been run and is not counted.

| ID | Required state/transition | Category | Priority | Evidence / remaining check |
|---|---|---|---|---|
| T01 | Starting → connected; failed initial startup → Retry | VERIFIED | — | P/R startup + A-run real connection. |
| T02 | Active/empty backend exit → disabled retained workspace → reconnect | VERIFIED | — | P/R recovery; no automatic resubmission. |
| T03 | Empty draft/new thread → submitting → first saved history | VERIFIED | — | P/R new-thread packet; warm/cold return. |
| T04 | History loading/error → Retry → newest reconciliation | VERIFIED | — | P/R recovery RPC failure/retry; not all long-history scroll states. |
| T05 | Long history fetch/evict/restore/scroll anchor | PARTIAL | P1 | Bounds/virtualization machine evidence exists; matched normal long-thread position/scroll restoration not closed. |
| T06 | Typing/multiline/attachment draft/disabled/submitting | PARTIAL | P1 | P/R retained drafts and responsive tests; full matched composer-state set/attachment ingress not verified. Empty Home Send can appear enabled; do not infer acceptance or a bug from appearance alone. |
| T07 | Streaming → completed / stopped | VERIFIED | — | P/R actual turns and Stop; reasoning/timing is a separate visual row. |
| T08 | Failed turn → edit/retry/regenerate/continue with attachments | PARTIAL | P1 | Existing actions/simulated tests, no complete source-bound packaged failure-tree proof. |
| T09 | Approval pending/deciding/error/refused/rule accepted | VERIFIED | — | P/O/R exact-scoped command/file subset. Managed-network/extra permissions excluded. |
| T10 | User input options/step/submitting/answer/cancel | VERIFIED | — | P/O/R supported option forms; H1 async form/voice excluded. |
| T11 | Model unknown/catalog loading/error/entitlement/provider mismatch | PARTIAL | P1 | Loaded settings known; Home preview/provider-aware recovery/real-account expired model behavior incomplete. |
| T12 | Diff ready/empty/loading/unavailable/too large/restart | PARTIAL | P0 | Live ready/empty exit fixed; missing saved source, per-item fetch and C-large boundary remain. |
| T13 | Command running/completed/failed/interrupted + live output | PARTIAL | P1 | Numeric exit and saved disclosure exist; live read delivery and all expanded-state mapping incomplete. |
| T14 | Ecosystem loading/empty/partial/truncated/error/OAuth | PARTIAL | P1 | Retained cache/truncation/global OAuth verified subsets; installed inventory/rich forms/account-backed errors remain. |
| T15 | Unauthenticated/login waiting/cancel/expired/logged out | MISSING | P0 | No login lifecycle route (F38). A-run green runtime connection is not signed-in readiness. |
| T16 | Hover/focus/selected/disabled across menus/secondary views | PARTIAL | P1 | Primitive tests cover useful subsets; no complete current official state map or actual keyboard/AT sweep. |
| T17 | Durable queued/waiting/edited/removed prompt states | MISSING | P1 | F40; presence admission alone cannot expose these state transitions. |
| T18 | User terminal/worktree/Git-action running/error/exit states | MISSING | P0 | F41–43 missing routes mean their primary lifecycle/failure states are missing too. |
| T19 | Preferences editing/apply/cancel/failure/readback | MISSING | P0 | S11 full Settings absent; an execution override dialog does not cover app preferences. |

## I — Interaction fidelity matrix

| ID | Interaction | Category | Priority | Official → Native delta / verification boundary |
|---|---|---|---|---|
| I01 | Back/Forward + keyboard/mouse navigation | VERIFIED | — | O/R A0 same role; bounded history actual runtime. General workspace tabs excluded. |
| I02 | Thread/project right-click and keyboard context menu | VERIFIED | — | O/R A2/A3 pointer anchor, Shift+F10/ContextMenu, selection retention. |
| I03 | Sidebar resize/collapse and draft retention | VERIFIED | — | O/R A4/F, actual resize retains state; exact official persistence/preference still open. |
| I04 | Enter/Shift+Enter/Ctrl+Enter/IME/focus return | PARTIAL | P1 | Typed shortcuts exist; official send preference absent. One prior synthetic Home Return did not submit; preserved, not diagnosed as a product bug. |
| I05 | Command palette/shortcut discovery/remapping | MISSING | P1 | O/D-settings; Ctrl+K only thread search in sidebar, no general command palette/settings editor. |
| I06 | Model/reasoning/execution open/close/keyboard states | FIDELITY GAP | P1 | O/A11; controllers correct subset; all official open-state groups/anchors/focus not matched. |
| I07 | Composer file mention/paste/drop/IDE context/voice | PARTIAL | P1 | O/P; manual attachment routes don't prove native ingress or dictation; supported/privacy boundaries need mapping. |
| I08 | Timeline autoscroll/manual scroll/restore/selection/copy | PARTIAL | P1 | Bounded bottom-anchor and Copy real use exist; long restore, selection and streaming-scroll feel not matched. |
| I09 | Goal toggle/quick action/parked editor/cancel | PARTIAL | P1 | O/R A9; implemented actions, terminal variants and simultaneous tabs remain open. |
| I10 | Approval scope menu/Escape and question step actions | VERIFIED | — | O/P/R exact command/file + structured question subset; no grant on menu open/dismiss. |
| I11 | Changes per-file/hunk/review/comment/Git actions | PARTIAL | P0 | O/D-local; normal read-only live pane exists, rest of chain absent. |
| I12 | Dialog/popover focus, keyboard escape and announcements | PARTIAL | P1 | Existing semantics/ownership tests, no broad actual official/AT verification. No physical screen-reader claim. |
| I13 | Global New chat/Search from composer, collapsed sidebar and Customize | PARTIAL | P1 | Source confirms Ctrl/Cmd+N/K registered only under `_ThreadPanel` CallbackShortcuts, outside focused conversation/Customize ancestry. Whole-app advertised shortcuts have a scope gap; actual per-platform key reproduction is still needed. |
| I14 | Terminal input, worktree handoff, Git stage/revert/commit interactions | MISSING | P0 | F41–43; absent routes cannot earn interaction credit from a functioning conversation shell. |
| I15 | Account and app preferences navigation/edit/cancel | MISSING | P0 | F38/S11; no equivalent complete interaction chain. |
| I16 | Inline slash/mention and mode/speed command discovery | MISSING | P1 | F49–51; direct controls/keyboard menus absent, not verified by static activity output. |

## V — Visual fidelity matrix

No pixel-percentage or signed-in screen acceptance is inferred. These are
structural comparison units, not counts of matching individual pixels.

| ID | Comparison unit | Category | Priority | Evidence / largest remaining difference |
|---|---|---|---|---|
| V01 | Shared wide page/rail/sidebar/reading geometry | VERIFIED | — | O/A4 + measured Native same viewport; 672px cap and shared rounded surface roles. |
| V02 | Closed Changes bottom affordance | VERIFIED | — | O/A8 + R measured Native; open pane is not included. |
| V03 | Window strip/rail destinations/account footer | FIDELITY GAP | P1 | O/A0/A1; action/destination completeness and platform decoration differ. |
| V04 | Project/thread hierarchy and status | FIDELITY GAP | P1 | O/A2/A3; normal rows improved, project operations/provider PR state and unread transitions incomplete. |
| V05 | Workspace header/tab grouping | FIDELITY GAP | P1 | O/A5; bounded Goal/link controls do not replace general task/tab hierarchy. |
| V06 | Prose/user/attachment hierarchy and selection | FIDELITY GAP | P1 | O/A6; actual tokens/Markdown fixes retained, external attachments and matched signed-in composition open. |
| V07 | Thought/activity/expanded command/per-file cards | PARTIAL | P1 | O/A7/U8; U9 not integrated and exact live/saved state composition incomplete. |
| V08 | Goal + question + composer coherent bottom stack | FIDELITY GAP | P1 | O/A9–11; supported branches translated, async voice/free-text/open controls and terminal variants differ. |
| V09 | Open Changes/Review/diff/output surfaces | PARTIAL | P1 | O/D/E; functional dialogs/panes are not matched official expanded states. |
| V10 | Menus/popovers/settings/Customize details | PARTIAL | P1 | O/A1/A11; semantic primitives exist; full settings absent, matching open/detail/loading/error states incomplete. |
| V11 | Signed-in Home | PARTIAL | P1 | O/B; A-run is credential-free Native Home, not matching official signed-in Home. |
| V12 | Compact/dark/focused variants | PARTIAL | P1 | O/F/G; available Native captures/geometry tests are not a matched signed-in official comparison. |
| V13 | Settings page and preference sections | MISSING | P0 | S11; no Native page to compare. |
| V14 | Account onboarding/re-authentication | MISSING | P0 | S10; Runtime diagnostics is not this visual surface. |
| V15 | Interactive terminal/docked tab | MISSING | P0 | S12; completed-command output viewer is not the official terminal panel. |
| V16 | Worktree/environment setup/branch/handoff | MISSING | P0 | S13/F46; no Native surface. |
| V17 | Git stage/revert/commit/push/PR action surfaces | MISSING | P0 | S14; read-only unified diff cannot earn visual parity here. |
| V18 | Global search/Automation list/editor/inbox | MISSING | P1 | S15/S21; no corresponding full screens. |
| V19 | Inline slash/mention/skill/mode control popovers | MISSING | P1 | S26; manual path dialog has a different structure/interaction. |
| V20 | IDE/file-tab/preview/detached-window entry surfaces | MISSING | P1 | S22/S25/S27; exact local/conditional variants still need supported-evidence mapping. |

**POLISH is a valid category, but no whole audited surface is classified
POLISH-only here.** Do not invent icon/spacing tasks while the structural and
functional gaps above remain. Specific final token/micro-animation differences
can enter P2 after a matched-state comparison establishes them.

## Five separate coverage estimates

The denominator is this explicit finite inventory, **not every possible official
account feature, platform or state combination**. Each dimension is counted
independently; rows intentionally overlap across dimensions and must not be
summed into an overall score. Equal-weight rows are a planning convention, not
an effort estimate. VERIFIED counts require the strict scoped evidence above.

The estimates are **observed inventory ratios**, not subjective 0.5 credit for
every unfinished row. Functional/state/interaction/visual rows report the strict
evidence-closed floor; surface coverage additionally reports whether an entry
exists at all. An existing but incomplete view is not half visually correct.
Missing pages participate in the visual/state/interaction inventories too.
Counts are calculated from the tables; no blended overall score is produced.

| Dimension | Inventory units | VERIFIED subset | Existing incomplete | MISSING | Evidence-closed floor | Presence only |
|---|---:|---:|---:|---:|---:|---|
| Functional coverage | 54 | 19 | 20 | 15 | 19/54 (35%) | Not a closure claim |
| Surface coverage | 27 | 1 | 15 | 11 | 1/27 (4%) | 16/27 (59%) have an entry |
| State coverage | 19 | 7 | 8 | 4 | 7/19 (37%) | Not a closure claim |
| Interaction fidelity | 16 | 4 | 8 | 4 | 4/16 (25%) | Not a closure claim |
| Visual fidelity | 20 | 2 | 10 | 8 | 2/20 (10%) | Not a closure claim |

An absent major page and a small existing path have the same weight here; the
P0/P1 ordering, not a percentage, determines implementation order.
Visual and interaction values are especially low-confidence because many
signed-in official states lack a matched Native capture. Unknown comparisons
are not silently promoted to VERIFIED or to subjective Human-only work.

## P0/P1/P2 implementation ordering after audit

### Tests green, visibly incomplete in normal product use

These are concrete counterexamples to inferring completion from passing tests:

- Open a clean profile: the runtime can be green/connected and Home can render,
  while there is no Native account sign-in/cancel/re-authentication path (F38).
- Resize to700px: `Automations & Skills` is visible, but its handler opens only
  the ecosystem dialog. A working button test cannot prove an Automation page
  exists (S21).
- Open a saved edited conversation after a thread change/restart: the timeline
  can load successfully while `DiffController` has discarded its only live
  snapshot and has no saved/workspace read source (F31).
- A file-change caption can correctly show `+3 -0` without a per-file disclosure
  or readable patch. The caption regression test does not close F32; unfinished
  owner branches must not be counted as released UI.
- A bounded large-command-output benchmark passes because command output is
  spooled, yet a large file/aggregate diff still crosses the Host's forwarded
  message cap (C-large). These are different payload paths.
- A successful typed form/tool test can display a text summary while the saved
  structured/media result or interactive template is inaccessible (F20/F36).

`test/simulated_runtime/simulated_runtime_harness.dart` correctly names a typed
fake RuntimeController. It is valuable presentation integration evidence; it
does not invoke the real Host or establish official-state geometry. Preserve
those tests without promoting their count into full-process or visual coverage.

### P0 — primary workflow inventory complete; implementation remains paused

1. **Account onboarding/re-authentication** (F38/S10/T15): complete stock-managed
   login/cancel/logout, explicit browser handoff, success/error/cancel/expired
   readback. Account/security interaction stays user-operated; never retain keys
   or tokens in Flutter. Acceptance: fresh private profile can reach an explicit
   legitimate account flow and recover/cancel without restarting the app.
2. **Changes persistence/workspace source** (F31/S08/T12): current-turn-only data
   is not a saved/workspace Changes implementation. Acceptance: same repository,
   same edit, live → switch → process restart → reopen still has a truthful
   source/scope and bounded file access, including empty/error/large cases.
3. **Interactive terminal + general task-tab seam** (F41/S05/S12): actual PTY
   input/output, local cwd, resize, stop/exit and lifecycle. A command-output
   dialog cannot be the acceptance artifact.
4. **Local worktree create/branch/handoff** (F42/S13): preserve original checkout,
   coordinate thread cwd and setup, surface failures; agent-side worktree usage
   is not product evidence.
5. **Git review-to-action workflow** (F43/S14): staged/unstaged source and safe
   chunk/file actions → commit/push; separate public/local PR integration from
   private backend. This is a missing product surface, not a diff color task.
6. **Routed Settings destination** (S11): a complete preference/configuration
   route with supported controls, loading/error/readback and keyboard entry.
   Existing execution and diagnostics dialogs cannot replace the missing page.

P0 here is the user's **missing/broken primary-workflow priority**, not an assertion
that each item is a catastrophic production incident. Missing local capabilities
must not be hidden behind private-service exclusions. The precise supported
integration boundary still needs research before implementation.

### P1 — close partial chains and frequent structural differences

- Complete typed lazy per-item patches **only after reviewing/integrating the
  preserved branches**; then bound aggregate-diff forwarding too. C-large is a
  reproduced process-fixture failure and a high-impact risk, not proven stock
  frequency. Retain the negative until actual stock large-edit verification.
- Global message search, file autocomplete, durable queue, automatic viewed-state
  receipt, Home effective settings and explicit provider recovery.
- Inline slash/@/$ workflows, Plan/Default and supported Fast tier selection,
  file/image ingress, IDE/file-line navigation, PR unlink and background-terminal
  cleanup (F47–54) are separately missing/partial, not decorative composer polish.
- Keyboard/command palette, localization, local environments,
  truthful Automation entry/management; determine local supported contracts.
- Installed-plugin scope, saved rich MCP results and supported tool/auth states.
- Coherent A6/A7/A9–A11, open Changes/Review, then Home/compact/dark and complete
  menu/popover states, using current official captures and exact mappings.
- Failure/retry/regenerate/edit/continue with attachments, long-history restore
  and actual keyboard/focus/selection paths; do not replace runtime evidence with
  another large simulated-test count.
- Source-confirmed compact Desktop branch loss and global shortcut focus scope
  precede micro-polish. Compact `_ConversationPanel` omits `hasDesktopShell:true`
  and takes legacy presentation paths. Wide Changes split requires workspace
  >960px (so not at1191px with340px left region); that behavior is confirmed,
  but its official correctness needs current same-state evidence. A different
  Goal threshold alone does not prove an incorrect Changes threshold.

### P2 — conditional/rare states and final polish

- Additional-permission grants only after proving enabled/adopted stock emission;
  retain safe refusal meanwhile.
- Physical-platform/AT/device-only behavior, after available local equivalents.
- Typography offsets, micro-motion and color/radius deviations only when a
  measured same-state comparison proves these are the remaining differences.

## Scope/evidence boundaries that cannot disappear from the inventory

| Official/shared-app surface | Native status | Treatment |
|---|---|---|
| Realtime voice/dictation; async H1 free-text voice question | MISSING for complete voice path | Public experimental `thread/realtime/*` and renderer branches exist; no Native audio lifecycle. Research supported local contract. Private `/wham/realtime/*` is not authorized. Not counted as verified composer parity. |
| Browser/computer-use, rich `ui://`/artifact tabs | MISSING for complete host surface | Keep S22 visible. Establish required supported local workflow, sandbox/permission lifecycle and account enablement; static renderer strings do not authorize private services. |
| General task tabs/files/preview | PARTIAL / MISSING by tab kind | Goal and Changes do not prove an arbitrary workspace tab system exists. Map enabled Codex tabs independently. |
| Remote relay / SSH / cloud environment chooser | PARTIAL or absent route by backend | Existing supported host Remote administration retained. New relay/private services and mobile expansion remain deferred; cloud capability is not synthesized. |
| ChatGPT Chat/Work, Dot, Space, Sites, billing/profile cloud, first-party notifications | No equivalent complete backend | Record as shared-shell/private/deferred, outside current local Codex completion denominator; do not fake rail destinations or count them as successful supported parity. |
| Provider config APIs only on newer train/alpha | PARTIAL research | Installed/public0.167.2 lack newer methods. Gate by actual runtime; no unconditional RPC or hidden service fallback. |

These exclusions explain scope; they are not evidence that the official surface
does not exist. The baseline remains official Codex Desktop, not a generic AI
dashboard or the union of every ChatGPT product.

## Preserved branch work, not delivered completion

| Owner branch/HEAD | Existing work | Audit treatment |
|---|---|---|
| `agent/codex-file-change-item` / `68e2283` (parent `0d1bf34`) | Host per-item diff spooling; bounded typed metadata/reader, 4 physical requests/cache and cold stock probe | Committed/pushed, not in main. Review/integration and presentation remain open. C-large aggregate cap still fails. |
| `agent/gemini-golden-ui-u9-o3io` / code `22abb4f`, doc-only `e6667dd` | Official O3Io per-file primitives/evidence, focused gates | Not in main; binding and packaged same-state verification not complete. Preserve uncommitted `codex_activity_row.dart` work; do not overwrite or call it delivered. |

No production code, owner commits, protocol or UI behavior is changed by this
audit. Historical validation remains valuable and source-scoped. This document
does not rerun or promote the 724 default Flutter cases/five opt-in stock skips
to full-process E2E or visual fidelity proof.

## Peer reconciliation and audit validation

Official `agy`1.5.1 interactive PTY session89818 is the live peer channel. Gemini
was explicitly told to stop implementation/heavy work, preserve U9 WIP, inspect
actual main and independently challenge missing surfaces, priorities and
previous completion claims. Peer verdict is recorded below after reading it;
no verdict is inferred from a spinner, truncated transcript or a prior review.

**Peer verdict read in the official TUI:** `ENDORSED (0 P0 / 0 P1 doc defects)`
for canonical documentation; zero implementation workers, U9 `+47/-2` WIP
preserved unstaged, functional/UI branches unmerged. Independent source note:
original commit `e6667dd`, preserved with provenance via `ac6ca4b` and archived as
[peer audit evidence](../history/GEMINI_DESKTOP_COMPLETION_GAP_AUDIT_2026-11-12.md).
Its differently grouped36-surface estimates are historical input, not a second
current completion matrix.

Reconciliation was evidence-based:

| Peer finding / disputed claim | Disposition | Evidence / correction |
|---|---|---|
| Missing IDE/file-line, inline slash/@/$, Plan/Fast, PR unlink, background terminals, richer activity | Accepted | Added F47–54, S25–27 and related state/interaction/visual rows; actual main adapters/routes checked. |
| Compact omits Desktop mode; global N/K focus scope; nonexistent Alt bindings | Accepted | Actual constructors and CallbackShortcuts re-read. Current A0 prose corrected; historical narrative remains preserved. Actual per-platform key sweep still required. |
| Full Settings is a primary missing surface | Accepted | S11/P0; execution and Runtime dialogs do not replace it. |
| User bubble still truncates text prefix | REJECTED — stale | U7 actual rendered-height clipping is present on main; peer re-read and corrected S29. No duplicate implementation scheduled. |
| >960px Changes split differs from Goal, therefore incorrect | Not proved | Source behavior confirmed; current official same-state threshold/placement remains evidence-open. No speculative threshold fix. |
| Prose/reasoning whole surfaces need only POLISH because official expanded state is uncaptured | Rejected as completion inference | Retain existing measured work; missing official state evidence does not establish whole-surface polish-only completion. Peer corrected classification. |
| Every partial row merits arbitrary0.5 fidelity credit | Removed | Missing pages now participate in all applicable dimensions. Only explicit counts/strict evidence floors and surface presence are reported. |

Audit validation:136 unique dimension IDs, allowed categories/priorities,
relative repository links, final diff/whitespace and docs-only source scope checked.
An initial link checker matched existing literal `(...)` Markdown examples in
Golden A; excluding those literals makes the link check pass. No product test
or UI change was made to fix that checker assumption. Fresh A-run and retained
negative C-large evidence are explicitly scoped above; no heavy Flutter/Cargo
suite was rerun for documentation. Main product CI0e2a is green; the final
**documentation HEAD's** hosted result is tracked separately at publication.

### Publication negative evidence

Documentation source `de77288` was pushed to main. Exact
[CI43220947635](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43220947635)
finished with successful macOS (7m17s) and Windows (7m12s) builds, but failed Linux
`verify`: `Install Linux build dependencies` timed out after5 minutes, with
repeated `mirrors.kernel.org` Ubuntu fetch retries. Dart/Flutter verification
steps did not execute. This preserves an infrastructure negative; it is not
represented as a code-test failure, a green suite, or grounds to reopen unrelated
CI hardening during the audit. The documentation follow-up has its own automatic
CI status; read that exact HEAD separately.

### Direct source navigation at the audited baseline

- Shell destinations/rail and compact switch:
  `lib/src/app/presentation/app_shell.dart` (`_DesktopShellDestination`,
  `_navigationRail`, `_CompactWorkspace`).
- Compact Automation label and scoped search shortcuts:
  `lib/src/app/presentation/sidebar_activity.dart` (`_ThreadPanel`,
  `_openEcosystem`, `_EcosystemController`, `_CustomizeWorkspaceView`).
- Timeline/composer/actions/Review:
  `lib/src/app/presentation/conversation.dart`, `composer_model_picker.dart`,
  `desktop_goal.dart` and `user_input.dart` in the same directory.
- Diff lifetime/source: `lib/src/features/diff/diff_controller.dart`.
  Diff/approval/output composition: `lib/src/app/presentation/diff_approval_output.dart`.
- Account/config **read-only** projection:
  `lib/src/protocol/runtime_diagnostics_protocol.dart`,
  `lib/src/app/presentation/runtime_details.dart`.
- File-change main summary only: `lib/src/protocol/file_change_summary.dart`,
  `turn_protocol.dart` and `history_protocol.dart`.
- Host sanitizer/cap: `native_host/src/transform.rs`, `config.rs` and `main.rs`.
- Theme preference/localization absence: `lib/src/app/codex_native_app.dart`
  (`ThemeMode.system`); no client locale/delegates/catalog configuration.

All these paths refer to main0e2a5b8, not to a hypothetical completed U9 merge.

Audit remaining work is visible in F/S/T/I/V and the boundary table. The audit
does not authorize resuming micro-polish or silently implementing the next old
READY item. Reconcile this inventory and schedule coherent complete workflows
before returning to implementation.
