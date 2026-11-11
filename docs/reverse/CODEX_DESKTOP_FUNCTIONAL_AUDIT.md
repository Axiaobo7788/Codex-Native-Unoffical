# Codex Desktop functional capability and workflow audit

Audited 2026-11-12 against Native `327ed906a0231ab4aac864956f224279fad2ad64`.
Program: `SELF_ITERATION`. Target: **Codex Desktop Completion — functional
parity and high-fidelity UI**, with neither track reduced to a fallback.

This is the current Track F assessment. Earlier F1–F32 milestone labels are
implementation history, not completion evidence. Visual acceptance belongs to
[Golden State A](OFFICIAL_UI_GOLDEN_STATE_A.md) and the later state contracts;
a functional `MATCH` below does not close a visual `PARTIAL`.

## Evidence and method

- Fresh isolated schema exports, executable versions and schema fingerprints
  are in `/var/tmp/native-functional-audit-dgjz20ng/`. Each executable ran with
  an empty private HOME/CODEX_HOME. No installed runtime or account setting was
  changed. Current public stable `0.167.1` was downloaded from the [official
  release](https://github.com/openai/codex/releases/tag/rust-v0.167.1); its archive
  SHA-256 matched the release asset digest
  `64bcc99c32e434b4bcb0508a97df9b7aeecdb97e956d976fb13661096ec4e3e2`.
- The [public app-server protocol documentation](https://learn.chatgpt.com/docs/app-server)
  describes authentication, history, approvals and streamed events, and specifies
  that generated schemas are version-specific. Actual locally generated shapes,
  not examples from a different release, control implementation decisions.
- Native audit follows protocol adapter → transport/runtime → controller →
  reachable Desktop action. `native-request-literal-inventory.json` is only a
  navigation aid: a method string is not proof of lifecycle correctness, and an
  absent string is not proof that an equivalent native workflow is absent.
- Installed official Desktop evidence is build `25894`, renderer
  `26.1103.60933`, ASAR SHA-256
  `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`,
  rechecked in this round. Static components do not establish an authenticated
  account entitlement or a private-service integration contract.
- Fresh source-77 shared validation covers the code retained by `327ed90`:
  format/strict analysis, 65-root pure-Dart boundary, 565 default Flutter cases,
  five separately enabled direct-stock cases, history 100/1,000 plus ten 3 MiB
  outputs, Rust fmt/Clippy/100 tests, two-job Linux release, 83-library closure,
  and pure-Dart MCP smoke. Unit/widget/simulated-runtime cases are not described
  as full-process E2E. The independent packaged replay actually exercised saved
  threads, bounded history, attachments, copy and thread switching through the
  bundled Host and stock runtime.
- Prior focused stock probes are linked explicitly below. Source identity and
  fresh schemas can revalidate a claim's contract; they do not mean its earlier
  live interaction was rerun. New functional corrections require targeted tests
  and real-stock verification where practical.

## Current binary/schema comparison

All five executable versions and both schema modes were checked in this round.
Counts describe methods, not completed product capabilities.

| Binary | Client requests stable / experimental-only / total | Server requests stable / experimental-only | Server notifications | Client notifications |
|---|---:|---:|---:|---:|
| Installed `0.167.0-alpha.3.2` | 106 / 74 / 180 | 10 / 1 | 86 | 1 |
| Cached public `0.167.0` | 106 / 74 / 180 | 10 / 1 | 86 | 1 |
| Current public stable `0.167.1` | 106 / 74 / 180 | 10 / 1 | 86 | 1 |
| Cached Desktop train `0.167.0-alpha.4.1` | 108 / 74 / 182 | 10 / 1 | 86 | 1 |
| Cached public alpha `0.169.0-alpha.7` | 109 / 74 / 183 | 10 / 1 | 86 | 1 |

The train adds stable `modelProvider/list` and `modelProvider/config/write`;
the inspected public alpha additionally has `account/securitySetup/read`.
These three are absent from the installed and current public-stable method sets.
Do not unconditionally call them on the installed runtime, or call a private
replacement. Public-alpha support is a compatibility/research item, not evidence
that the installed protocol already offers a provider editor.

`thread/turns/list` and `thread/items/list` remain stable. `thread/items/read`,
`thread/timeline/list`, `thread/search`, `thread/queue/*`, `thread/realtime/*`,
`remoteControl/*` and `collaborationMode/list` remain experimental in the inspected
sets. `currentTime/read` is the one experimental-only server request. The adapter
already implements it; private attestation and external-token callbacks remain
separate from ordinary approvals.

A fresh feature-default check adds an important support qualifier:
`request_permissions_tool` and `exec_permission_approvals` are both
**under development and disabled by default** on the installed, current public
stable and inspected alpha runtimes. A stable server-request shape alone does
not prove a normal enabled official Desktop workflow. Additional-permission
coverage remains a real conditional Native limitation, but its emission/adoption
boundary must be established before prioritizing it over a confirmed default-path
failure. This negative evidence supersedes the initial schema-only priority.

## Capability/workflow assessment

Status is scoped to the workflow described in the first column. `MATCH` means
that supported subset is implemented and has identified machine/stock evidence;
it does not assert every optional related RPC or every platform was exercised.
A `PARTIAL`, `MISSING` or `RESEARCH_MORE` remains active machine work unless its
next action identifies a real external dependency.

| Capability/workflow | Status | Official/stock evidence | Current Native implementation/access | Actual delta and user impact | Next action |
|---|---|---|---|---|---|
| Local runtime discovery, initialization, stop/restart | MATCH | Installed/public schemas; fresh direct-stock cases and MCP smoke | `process_transport.dart`, executable/Host locators, `runtime_controller.dart`, Runtime panel | Stock harness remains in the child process; handshake, request correlation and shutdown are implemented. Physical platform installation/signing is not established by Linux tests. | Preserve lifecycle gates; investigate concrete regressions rather than inventing a new runtime. |
| Local thread create/list/select/read/resume, bounded ordinary history | MATCH | Stable `thread/*`, `thread/turns/list`, `thread/items/list`; fresh packaged same-stock history replay | `thread_protocol.dart`, `thread_list_controller.dart`, `history_controller.dart`, sidebar and timeline | Normal supported path is reachable and paginated. Provider discovery and failed cold resume have separate non-matching rows below. | Keep all history/working-set caps and inactive-view eviction. |
| Cold-resume failure feedback in the active conversation | MATCH | Stable `thread/resume`; fresh before/after packaged stock replay and 42 targeted cases | Source `a0d2a05` preserves peer `aba5feb`, adds typed loaded/failed/skipped outcomes and a bounded current-thread live-region notice above the composer | Failed normal Send and explicit resume now preserve draft/attachments with visible feedback in compact and collapsed-sidebar states. Review uses attempt outcome. This does not close provider discovery or other thread-action feedback. | Preserve the guards; continue the next supported gap. Physical screen-reader/Human acceptance remains unrun. |
| Provider-aware saved-thread discovery and recovery | PARTIAL | [Four-build stock/provider matrix](THREAD_PROVIDER_SCOPE_EVIDENCE.md), fresh same-version exports | `thread_protocol.dart` defaults to configured-provider lists; saved title search shares that scope; `JsonRpcException.data` is retained | All-provider local history is supported upstream, but Native has no explicit discovery/read-only recovery path. Cold resume differs between 0.167 and 0.169 alpha. | Design bounded explicit discovery and structured provider-block handling from actual version behavior; never silently switch providers or send queued work. |
| Thread rename/archive/unarchive/permanent deletion | MATCH | Stable schemas; `thread_smoke.dart` and existing controller/stock evidence | Typed thread gateway, sidebar actions/confirmation | Supported local actions are reachable. Deleting real user data remains an explicit user action; this audit performs no such deletion. | Retain destructive confirmation and truthful failures. |
| Turn start, assistant streaming, steer and interrupt | MATCH | Stable turn/item methods; current direct-stock cases and earlier real Linux turn walks | `turn_protocol.dart`, `conversation_controller.dart`, composer Send/Steer/Stop | Ordinary lifecycle is wired, including stopped/failed/completed states. Streaming is coalesced. | Preserve race/admission guards and 50 ms coalescing. |
| One-time command/file approvals and legacy decisions | MATCH | Stable server requests; `approval_protocol_test.dart`, controller/widget tests, `approval_smoke.dart` | Single `ServerRequestProtocolAdapter`, approval controller and cards | Native respects advertised one-time acceptance availability and can decline. This is not full permission/session-choice parity. | Keep the single dispatcher and in-flight decision guards. |
| Structured additional-permission approval | RESEARCH_MORE | Stable `item/permissions/requestApproval` in all five exports; typed `PermissionsRequestApprovalResponse` | `server_request_protocol.dart` emits `ApprovalKind.permissions` with `approveSupported: false`; tests intentionally assert refusal | Valid network/filesystem requests cannot be approved. The card drops the permission profile. However, observed permission-emitting feature flags are under-development/off by default; stable schema does not establish an enabled normal workflow. | Reproduce public emission and verify official/adopted feature scope first; then implement bounded exact request/grant profiles, turn/session choices and typed empty denial with targeted security review. Keep safe refusal until that contract is implemented. |
| Advertised session/amendment approval choices | PARTIAL | Stable command decision schema and `availableDecisions` | `ApprovalDecision` exposes only `approveOnce` and `reject` | Session and policy-amendment choices are not available. Existing availability checks already prevent an unadvertised one-time grant; no such security bypass was reproduced. | Add only explicitly supported/advertised decisions with correct scope and user intent; no fabricated policy amendment. |
| Request-user-input questions and MCP elicitation | MATCH | Stable server request schemas; current protocol/controller/product tests and prior packaged request walk | `user_input_controller.dart`, `user_input.dart`, request cards; form/URL elicitation adapter | Bounded supported fields/options have response and resolved/cancel paths. Unknown forms fail truthfully rather than hanging. Richer/private form variants are not implied. | Preserve bounds and inspect specific unsupported public forms when discovered. |
| Model, reasoning, sandbox/approval/execution controls | MATCH | Stable `model/list`, thread/turn overrides; `model_smoke.dart`, fresh control/layout suite | Model picker and execution settings controller; stock-backed values | Current model/reasoning/execution choices are reachable. The model catalog is not proof of account entitlement. Provider editing is separately unimplemented. | Retain inherited settings, failure behavior and runtime-specific capabilities. |
| Edit/resubmit, regenerate, retry and continue | MATCH | Stable turn/fork/revert primitives; current product/simulated-runtime cases and earlier stock use | Conversation actions and bounded branch bookkeeping | Local workflows are reachable and guard concurrent turns/selection changes. Their UI fidelity is still Track U work. | Verify relevant real path when changing admission or branch state. |
| Fork, revert and explicit harness compaction | MATCH | Stable schemas; thread/turn adapters and smoke/controller coverage | Sidebar/turn menus, confirmation and gateway | Revert affects conversation history rather than undoing workspace files; client-side compaction is not introduced. | Preserve clear confirmation and stock ownership. |
| Loaded/title search and per-thread occurrence search | MATCH | Stable `thread/list.searchTerm`; [occurrence evidence](THREAD_SEARCH_OCCURRENCE_EVIDENCE.md) | Sidebar local saved-title search; bounded occurrence/timeline projection | These supported scopes are reachable. They are not global full-history content search. | Keep scope/loading/pagination wording explicit. |
| Global saved-content search | MISSING | Experimental stock `thread/search`, inspected Desktop caller and prior saved-content probes | No Native `thread/search` request or UI path | User cannot search all saved message content through the supported stock surface. Title and in-thread search do not close it. Fork inheritance/search coverage has measured limits. | Re-probe bounded result/preview/cursor semantics and expose the measured supported scope. |
| Local Goals lifecycle | MATCH | Stable goal get/set/clear and notifications; existing Goal smoke/product paths | Thread controller, selected-Goal tab/editor/actions | Supported objective lifecycle is reachable. Simultaneous tabs/actions/visual states remain Track U deltas. | Maintain bounded one-thread projection and fresh real use on lifecycle changes. |
| Review uncommitted/base-branch/commit/custom targets | MATCH | Stable `review/start`; current target chooser source and `review_smoke.dart` target variants | `_StartReviewDialog`, `_startThreadReview`, typed target union and lifecycle | All four target choices now exist in Desktop; the old F14 uncommitted-only milestone is historical. Visual Review parity is not implied. | Refresh target-specific stock smoke when changing target wiring; keep review-state admission and error feedback. |
| Sections, explicit pin/move and bounded organization | MATCH | Stable section CRUD/move plus existing section stock/controller tests | Thread/section gateway, scoped sidebar browsing and menus | Bounded loaded definitions/threads are usable; no authoritative unlimited catalog claim. | Retain global cap, scoped cursor semantics and qualified counts. |
| Manual read-receipt marking | MATCH | Adopted experimental receipt methods; [receipt/notification coverage](OFFICIAL_FEATURE_MATRIX.md) | Revision-aware thread controller and explicit row action | Explicit mark actions have stale-response guards. Opening a conversation does not automatically acknowledge it. | Preserve compare-the-seen-revision semantics. |
| Automatic viewed-turn acknowledgement | PARTIAL | Stock receipt revisions and official viewed-state workflow; old research remains unclosed | No automatic visibility/focus/latest-turn admission | Unread state can differ from the first-party workflow. Blind marking on selection would incorrectly acknowledge unseen data. | Define and verify current visible/focused/latest-state evidence; implement safe admission without expanding history. |
| Live turn diff and bounded file/hunk rendering | MATCH | `turn/diff/updated`, typed diff/file-change items; current diff tests and prior packaged split/output walks | `DiffController`, bounded parser, file selection and Changes view | Current controller consumes active-turn diff events, with per-file rendering. This scoped match is not full workspace/restart Git-diff parity. | Keep lazy/per-file bounds and separate saved/working-tree scopes. |
| Saved/restart/full-working-tree Changes coverage | RESEARCH_MORE | Official local Changes workflows; stable saved file-change items and local Git behavior | `DiffController.bindThread` clears its snapshot and listens only to `TurnDiffUpdatedEvent`; saved file-change previews are separate | Need prove which official saved/workspace states lack an equivalent Native path; a live diff screenshot cannot close every scope. | Same local repository/stock state probe across restart/resume and trace official local Git-diff caller. Do not claim a confirmed full-workspace implementation. |
| Command activity and lazy large output | MATCH | Stable item events; Host output descriptors/range reads; current history/output benchmark and A7 replay | Bounded live/saved activity projection, Host file spool, output viewer | Large command strings stay out of the timeline; saved output is opened on demand. Counts remain loaded-only. | Preserve Host ownership, limits and output availability/error states. |
| Whole-item deferred output fallback | RESEARCH_MORE | [Measured upstream deferOutput boundary](OUTPUT_DEFERRAL_EVIDENCE.md) | `outputDeferred` metadata is retained; `thread/items/read` fallback remains whole-item | Accepted deferOutput does not prove upstream genuinely deferred sampled output. Host bounding helps but does not establish fully solved upstream laziness. | Keep the negative evidence and re-probe when runtime behavior changes. |
| Skills list/config and plugin install/read/uninstall | MATCH | Stable public ecosystem methods; current adapter tests, MCP smoke and packaged Customize | Ecosystem gateway/controller, Customize and details | Supported local catalog/detail/install operations are reachable with retained cache on failures. An installed-catalog completeness claim is separate. | Preserve mutation serialization/readback and retained usable partial catalogs. |
| Explicit plugin catalog truncation signal | PARTIAL | [131-row fixture and stable catalog evidence](PLUGIN_INSTALLED_SCOPE_EVIDENCE.md); fresh adapter source | `EcosystemProtocolAdapter.listPlugins` caps at 100; `PluginCatalogSnapshot.isPartial` reports source errors only | Additional distinct usable rows are silently omitted. At-cap/loaded wording is not an explicit omitted-row signal. | Track actual omitted usable distinct rows separately from source errors, without raising the cap or changing the query. |
| Scoped installed-plugin inventory | PARTIAL | Stable `plugin/installed`; [four-build scoped inventory](PLUGIN_CATALOG_TRUTH_EVIDENCE.md) | Native queries `plugin/list`, not `plugin/installed` | Catalog and installed queries are different; home/workspace/suggestion scope and authenticated background-sync effects remain to reconcile. | Design explicit safe scope and payload bounds; do not label the existing catalog an authoritative installed inventory. |
| Apps catalog/details, direct MCP calls/resources | MATCH | Stable app and MCP methods; current protocol tests and real MCP smoke | Typed ecosystem adapter, bounded app pages/tool form/resource result surface | Supported text/structured local calls are reachable. Account/private installations and arbitrary rich UI templates are not established by this subset. | Keep page/tool/source limits and per-result bounds. |
| MCP OAuth login from server status | MISSING | Stable `mcpServer/oauth/login` and completion notification | Native parses `authStatus`, but has no OAuth login request/action | A configured server requiring OAuth cannot be authenticated through the normal Native status path. URL elicitation is a different workflow. | Add supported start/result/lifecycle/browser handoff, with Host-owned credentials and cancellation/failure behavior; verify via a disposable local OAuth fixture where practical. |
| Rich historical MCP result disclosure | PARTIAL | [Stored/live rich-result evidence](MCP_RESULT_DISCLOSURE_EVIDENCE.md) | Bounded text/result summaries; structured/media history subsets differ | Some saved structured/media content cannot be inspected through a complete equivalent path. Do not inflate summaries into full results. | Reconcile typed content availability and bounded lazy disclosure. |
| Optional public MCP app UI (`ui://`) | RESEARCH_MORE | Public MCP app/resource contracts; [integration map](CODEX_INTEGRATION_MAP.md) | Layer-A calls exist; optional sandboxed WebView host does not | Interactive template behavior is not implemented by a text/tool form. First-party private resources remain excluded. | Establish a required supported local template/workflow and bounded sandbox policy before optional WebView adoption. |
| Native account sign-in/cancel/sign-out | MISSING | Stable account login/cancel/logout and completion/account notifications; official unauthenticated Desktop state | Runtime details only read account/rate-limit state; users rely on external stock login | First-time/expired-account onboarding is not reachable inside Native. Stock credential ownership is not a reason to claim a missing UI exists. | Implement supported stock-managed login lifecycle without exposing/persisting tokens in Flutter; actual account/security interaction stays user-operated. |
| Runtime/account/provider diagnostics | MATCH | Stable account/read, rate limits, requirements/config/provider capabilities and notices | Typed bounded diagnostics adapter and Runtime page | Read-only diagnostics are reachable and redact/qualify failures. They do not implement provider switching or account security management. | Preserve account identity correlation and avoid secret payload/log exposure. |
| Provider list/config editing on newer stock | RESEARCH_MORE | Fresh train/alpha stable additions; absent on installed/current public stable | Current diagnostics and model selection do not call new provider editing methods | Need version support, config policy and a Desktop access path before adoption. No unconditional new RPC on older runtimes. | Compare schemas/behavior with provider config in isolated profiles and implement truthful capability gating. |
| Workspace file suggestions/composer lookup | MISSING | Stable fuzzy search + experimental session routes; [F23/F28 source/probes](WORKSPACE_FILE_SEARCH_EVIDENCE.md) | Manual structured attachment/path entry exists; no supported indexed autocomplete | Manual attachment is not equivalent to Desktop local file suggestion workflow. Previous one-shot/index bounds issues remain material. | Resolve bounded session/result/exclusion semantics from supported stock behavior, then wire an explicit scoped query path. |
| Durable queued prompt inspection/management | MISSING | Experimental queue methods; [mutable cursor/full-payload evidence](QUEUED_SUBMISSION_READBACK_EVIDENCE.md) | Queue-presence admission only | Native cannot inspect/edit/delete/reorder the persisted queue. A queue-present confirmation does not implement management. | Bound payload/readback and unknown-outcome reconciliation before queue writes. |
| Background terminal inspection/cleanup | MISSING | Public experimental `thread/backgroundTerminals/*`; current public docs and local schema | No corresponding Native request or action | Existing command output is not an inspect/terminate interface for background processes. | Verify loaded-thread and process identity semantics with private fixture, then expose explicit bounded cleanup actions. |
| Linked review references and removal | PARTIAL | Stable attachment add/list/remove/owner APIs; [unlink race evidence](THREAD_ATTACHMENT_UNLINK_EVIDENCE.md) | Add/list-backed linked-PR surface; no remove/owner query | Removing references and incomplete-scan/concurrent re-add behavior are unimplemented. | Define safe exact-key/partial outcome UI, then implement without losing aliases or concurrent additions. |
| Safe stock detach of inactive threads | RESEARCH_MORE | Stable unsubscribe; [live approval delivery caveat](THREAD_SUBSCRIPTION_EVIDENCE.md) | Native evicts UI state but does not automatically unsubscribe stock | Unsafe detach can strand an approval; lack of detach is not a measured client heap leak. | Define idle/active/Goal/review/approval admission and reconnect policy with real-stock memory/lifecycle evidence. |
| Native equivalents of helper fs/command RPCs | NOT_APPLICABLE | Stable fs and command helper methods | Native uses platform facilities where equivalent; explicit terminal/editor workflows need their own evidence | Absence of every helper RPC is not a product gap by itself. This does not excuse a discovered missing user workflow. | Audit observable Desktop workflow, not a method-count checklist. |
| Private first-party relay, attestation, external account-token callbacks | PRIVATE_ONLY | Private/service-specific support boundary and unsupported callbacks | No client private API, token, or hardware-attestation bridge | Unsupported first-party services cannot be used to manufacture parity. Safe rejection is retained. | Keep excluded; adopt only a legitimate newly public supported contract with evidence. |
| Physical platform/account-only end states | BLOCKED | Physical macOS/Windows/Android, authenticated account or hardware context not available for all paths | Linux/hosted cross-build evidence is distinct | Subjective visual acceptance, account entitlements and physical accessibility are not established by current machine gates. | Freeze only the exact unavailable check; continue all independent F/U work. |
| Chat/Work/Responses/mobile/Direct Remote expansion | NOT_APPLICABLE | Explicit narrowed phase | Existing code retained | Outside the current completion target; no deletion or regression authorized. | Resume only after the narrowed Desktop completion criteria or a new user instruction. |

## Prioritized confirmed functional work

| Rank | Confirmed gap | User-visible value | Support confidence | Feasibility / risk | Action |
|---|---|---|---|---|---|
| Closed (`a0d2a05`) | Cold-resume failure hidden from conversation | High: a normal failed send can look inert | High: fresh current source plus prior normal-entry real stock evidence | Small state/presentation seam, independent of U1; guard stale attempts and keep draft | Fresh current reproduction and attempt-scoped feedback for implicit and explicit resume. |
| 2 | Silent plugin catalog omission | Medium/high for affected workspaces; truthful inventory | High: stable response + distinct 131-row fixture; current cap/source-error code | Narrow protocol/model/UI truth correction, low regression surface | Signal genuine truncation separately from partial sources while retaining cap 100. |
| 3 | Account and MCP OAuth access paths absent | High: onboarding/configured-server usability | High stable contracts; actual identity flow requires user/local OAuth evidence | Separate lifecycle/security/UI work | Implement complete stock-owned flows, not a credential bridge. |
| 4 | Additional-permission grant coverage | High when the opt-in feature is in scope | Stable request/response, but relevant emitter flags are under-development and off | Security-sensitive; normal-workflow/adoption evidence still needed | Reproduce and classify before implementation; schema presence alone is insufficient. |
| 5 | Global search, queue, suggestions, terminal cleanup and richer saved data | High but different scopes/dependencies | Public methods exist; bounds and state behavior need focused probes | Separate coherent slices, not one generic framework | Progress the highest supported research item and reclassify; no queue-exhaustion stop. |

The first correction preserves peer commit
`aba5febb1f8b7e6dcd722a62df512a3172315f2b`
(`agent/gemini-conversation-resume-failure`). It adds immutable resume outcomes,
a thread-scoped conversation notice, and targeted controller/product tests.
The old worktree is clean. Normal merge `a0d2a05` retains that commit as its second
parent and adapts it to the current request/composer composition; the source was
reviewed by both peers and independently verified against real stock.

No completion is asserted: this audit finds both supported `MISSING` and material
`PARTIAL` workflows. The first correction is verified below; explicit catalog
truncation is the next active functional slice. A green implementation checkpoint is not a
stop condition; Track U continues concurrently.

## First correction checkpoint — cold-resume feedback

The existing `aba5feb` source is integrated through a normal merge, retaining its
provenance and adapting the banner to the current request/Goal/composer hierarchy.
Resume outcomes distinguish loaded, failed and skipped. A bounded thread-scoped
notice appears directly above the composer; it is a semantic live region with a
keyboard-accessible dismiss action. Successful resume, thread switch and runtime
replacement clear it; canceled/skipped retry retains the last failure. Review
uses the same attempt outcome rather than a stale controller-wide error. Drafts
and attachments are not consumed by a failed resume.

Latest targeted validation: 42 controller, Send and Review cases pass in the
ASCII auxiliary tree, with strict analysis, unchanged formatting and the 65-root
pure-Dart boundary. An initial test-only SemanticsHandle cleanup-order failure
is retained in the local evidence; `try/finally` corrected it. These are unit /
widget / simulated runtime product integration cases, not full-process E2E.

Fresh baseline real use in `/var/tmp/native-f-resume-real-stock-r2/` launches the
frozen unmodified `327ed90` app code (AOT `4b703ae5…`), bundled Host and installed
stock. A directly seeded private profile has self-contained rollout paths. After
selecting a cold thread, moving only its fixture rollout aside and pressing Send
at 720×800 leaves the draft and unchanged saved rollout, with no conversation
error. Opening Threads reveals stock `-32600 no rollout found`. The fixture was
restored and App/Host/stock exited cleanly. The first cloned-profile attempt had
absolute paths into an older task fixture and did not trigger failure; it is
preserved as invalid setup evidence, not counted as a reproduction. No user
account or project data was used. Only the model-response endpoint is loopback;
the app-server and Host are real processes.

Patched source `a0d2a05` passed 570 default Flutter cases (five opt-in skips),
five separately enabled real-stock cases, history 100/1,000 plus ten 3 MiB
outputs, Rust fmt/Clippy/100 tests, two-job Linux release, 83-library closure and
pure-Dart MCP smoke. The auxiliary ASCII source was byte-compared across all
196 tracked lib/test/tool files. This does not claim the original Unicode-path
LSP framing defect is fixed.

Independent patched AOT `b396a6abeb5da3d1af2c9745e0e6b5ffd88ebd774c1c90cdef776cd20b18a5ee`
uses the same real Host/stock and directly seeded private fixture. At 720×800 a
failed Send shows the error above the composer while retaining the local file
attachment and exact draft. Dismiss retains both; a repeated failed Send shows
the error again. At 1191×865 it remains visible with the sidebar collapsed.
Both failed sends left the held rollout byte-identical. Restoring it and retrying
creates exactly one stock task-start/completion pair containing the draft and
file, clears composer/error, and renders the real stock response. App/Host/stock
and private Xvfb exited. The loopback model fixture was also stopped. Full
manifest, hashes, screenshots and before/after setup evidence are in the r2
artifact above. No overflow/Unhandled was found; baseline Xvfb accessibility /
graphics warnings and stock fixture model-metadata fallback remain recorded.

This is `AGENT REAL-USE VERIFIED`, not Human acceptance or physical screen-reader
verification. U1 is a separate peer source and has not been merged into this F
binary. The remaining supported gaps above keep Track F active independently of
Track U.
