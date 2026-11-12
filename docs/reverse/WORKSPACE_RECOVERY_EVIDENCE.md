# Local Desktop workspace recovery evidence

Status: source55dcf16 combined gates and controlled real-stock recovery/failure/navigation pass.
The scoped functional flow is verified; Program remains SELF_ITERATION.
This is a local Codex Desktop lifecycle correction, not Remote expansion.

## Preserved failures and source corrections

- The unchanged source7d/2600 widget baseline removes the composer on
  `processExited`: expected one editor, actual zero. Private log:
  `/var/tmp/native-ui-r0.BbOvHT/runtime-workspace-loss-red-r1.log`.
- Peer source audit `3c18450` records three P1s. Two further real regressions are
  demonstrated in `runtime-recovery-peer-findings-red-r1.log`: a queued relay
  callback observes a retired transport, and an open attachment popover remains
  hit-testable above the disconnect surface. Both have focused corrections.
- A real earlier Linux WIP packet retains a stale empty-thread ID across stock
  termination. After reconnect, explicit Send fails with `-32600 thread not
  found` and leaves an optimistic error row. Private capture:
  `/var/tmp/native-workspace-recovery-real-r1/public/shell-candidate-r2/11-empty-send-attempt.png`.
  The later explicit new-conversation correction is not relabeled as a pass of
  that earlier binary.
- Retained live entries initially shadowed fresh saved history. Session-tagged
  reconciliation now preserves new explicit work and the unconfirmed warning.
  A retry follow-up also revealed that retained live text hid the full-page
  history error/Retry affordance. A compact existing-style notice now exposes
  Retry while the old projection is retained; accepted fresh reads reconcile it.
- Early strict-analysis infos, a wrong new-test Send tooltip and a private GUI
  clipboard target/coordinate failure are retained in logs. They are distinct
  from the actual product defects above.

## Earlier packaged real-stock behavior, source identity and limits

The earlier uncommitted packet is frozen at
`/var/tmp/native-desktop-workspace-recovery-wip-r1/bundle/`:

- Dart AOT `81e978802bb98199b6264388209f3dc8844a486c22f81fc121bd73240fc1be6a`;
- runner `3125fd1b1fe4b946c5d171ab674aff75809869418a5a0a06344ff064fede1de2`;
- Host `73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878`.

The 143 production/build input hashes and binary identities are private under
`/var/tmp/native-workspace-recovery-real-r1/`. Source changed afterward to correct
peer findings; this packet cannot establish their final behavior.

Actual packaged App -> bundled Host -> public stock0.167.2, isolated HOME and
CODEX_HOME, and a controlled localhost Responses fixture verified:

- idle owned stock SIGKILL retires old Host/stock; the same App PID reconnects
  with new children, saved history, draft and mention attachment; model calls
  remain one after reconnect;
- an explicit subsequent Send succeeds after full App restart;
- active Host SIGKILL also terminates its stock child on Linux, while the same
  App retains the newly typed draft, shows the prior outcome as unconfirmed and
  refreshes saved history without extra model calls (three total);
- a 700x760 state retains that draft; actual UTF8 clipboard text matches it;
- new-session empty-thread Send then exposes the failure recorded above;
- all twelve recorded App/Host/stock PIDs are absent after cleanup; the owned
  model server exits after SIGINT and its session is awaited.

The first private walk ended after its clipboard driver requested unavailable
STRING data at the wrong vertical coordinate. Its cleanup exited the App and
children; this was not an application crash. A later walk uses UTF8_STRING,
records actual clipboard success and exits with process-tree PASS.

This is AGENT REAL-USE VERIFIED with a controlled local model endpoint. No
personal account, provider credential, private relay or official cloud service
was used. Human acceptance and physical other-platform crash behavior are unrun.

## Machine checkpoint before final shared integration

The earlier recovery full suite passes 674 cases with five opt-in stock skips.
Later source passes 108 focused cases and 18 lifecycle/Retry follow-up cases;
these counts overlap and must not be added. Pure-Dart68 and strict analysis pass
at their recorded snapshots. Full current-source/shared U7 gates, direct-stock
cases, memory benchmark, final Linux packet and exact hosted CI remain pending.

Recovery source follow-up replaces the earlier strong identity snapshot with a
scalar retirement tag on existing bounded entries. Pending reconciliation holds
only versions and a thread ID, so a failed read cannot keep an additional old
entry/text window alive after controller eviction. This preserves the same
manual-Retry and fresh explicit-turn behavior without a second payload owner.


## Shared source24201ac: correction verified in real packaged runtime

Source `24201ac2ee22a5cb2befab8f129f2137f920f623` normally integrates recovery
`5e08cfe` / scalar-tag follow-up `3d68ebe`, U7 `44a8809`, and peer audit `3c18450`.
The follow-up peer audit `5746b8e` records zero P0/P1 at its explicitly inspected
source; [its report](HOT_RECOVERY_PEER_FOLLOWUP.md) retains non-blocking observations
and hypotheses separately. It did not independently rerun the real processes.

The new frozen packet `/var/tmp/native-desktop-recovery-u7-24201ac-r1/bundle/` has
AOT `01f4443b863dcf5ce3a6b3187c96236a417df9498e2926c2be79f846b560988b`,
runner `3125fd1b1fe4b946c5d171ab674aff75809869418a5a0a06344ff064fede1de2`,
and unchanged Host `73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878`.
All247 tracked validation/build hashes match. Format209/zero changes, strict
analysis0, pure-Dart68, 685 default cases/five stock skips, five enabled stock
cases on each tested binary, history100/1,000 plus ten3MiB payloads, Cargo format,
two-job Linux and83-system-library closure pass. Rust source is unchanged;
local earlier Clippy/test evidence is not called a new run. Exact branch
[CI43171510846](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43171510846)
passes all three jobs, including its own full Rust gate.

The new private replay `/var/tmp/native-workspace-recovery-real-r2/verification.json`
records23 PNG captures/checksums and these actual product interactions:

- public0.167.2: create a new empty session, enter `EmptyDraft242` and a local
  mention, terminate only its owned stock child, and reconnect in the same App;
- at700x760, the unavailable-session notice has an explicit New conversation
  action. It preserves draft, attachment and project context, creates no turn
  and makes no model POST. Actual UTF8 clipboard text remains `EmptyDraft242`;
- only explicit subsequent Send produces the first model POST, saves the user
  prompt/attachment and displays the controlled fixture response;
- terminate the owned Host during a later active request, retaining a separately
  typed `Keep242ActiveDraft`. The stock child also exits on Linux. Reconnect
  keeps the same App, reads saved history, shows an unconfirmed-outcome warning
  and makes no extra model POST. The copied draft matches exactly;
- installed0.167.0-alpha.3.2 independently repeats the empty-session Host exit,
  reconnect, explicit replacement, retained `InstalledEmpty242`/mention at700px
  and first successful Send. Its one POST makes three total across both cases;
- all12 recorded App/Host/stock PIDs are absent after normal script cleanup;
  the controlled model is stopped by SIGINT and its session exits0. Frozen
  binary checksums are unchanged. No personal auth/profile or cloud model was used.

The earlier `thread not found` packet remains a real failure of its earlier
binary; this later pass does not erase it. Human visual/long-session acceptance,
physical Windows/macOS crash behavior, and matched official signed-in crash
interaction remain unrun.

## Coupled follow-ups after source24201ac

- Compact/collapsed new-conversation RPC failures were only visible in the
  sidebar. `runtime-replacement-feedback-red-r1.log` passes wide and fails compact
  on missing visible feedback. A first Snackbar correction then covers Send
  after successful retry in both windows (`green-r2`, two actual hit-test failures).
  The corrected flow reports the bounded current-scope error, removes the
  obsolete notice at the next explicit attempt, retains draft/attachment on
  failure, and allows immediate retry/Send. Updated seven widget cases and
  strict analysis pass (`green-r3`); the combined real evidence below closes this scoped correction.
- Gemini4122c37 rewrites only the evicted session-only placeholder in the bounded
  Back/Forward stack, compacts adjacent duplicates and preserves arbitrary saved
  or off-catalog threads. The owner recorded a real +1/-3 RED, then39 targeted
  passes, pure68, zero format changes and strict analysis0; combined validation
  and packaged Back/Forward below pass.
- Persisted stock item IDs identify items across process sessions. The peer's
  synthetic reused-ID delta-prefix observation remains research, not a proven
  supported stock failure: dropping retained prefixes blindly could also lose
  a valid same-item continuation. No speculative namespace rewrite is adopted.

## Final combined failure and navigation packet55dcf16

Source55dcf16293bc6f508d25331d22996340361ca8ee normal-merges Codex507cbc7 and
Gemini4122c37 without rewriting their history. Serial shared gates pass:
format210/zero, strict analysis0, pure68,689 default Flutter/five opt-in skips,
five enabled stock cases on each binary, bounded-history/heavy-output benchmark,
Cargo format, two-job Linux release and83-system-library closure. All248 tracked
inputs match before/after. Packet `/var/tmp/native-desktop-recovery-nav-55dcf16-r1/`
freezes AOT `63e9da82019f1d06eed5bb73dcd392bb3ca7acf9f54b43c77820314275d974fc`;
runner/Host match the earlier24201ac identities. Checksums remain unchanged.

A separate pure-Dart bundled-Host probe actually verifies both public0.167.2 and
installed alpha re-read a private config for thread/start: invalid TOML produces
normal `JsonRpcException -32600`; restoring the same task-owned file lets a
subsequent start succeed. No user configuration, credentials or private service
is involved. Probe results are private in
`/var/tmp/native-thread-create-config-failure-r1/{public,installed}/verification.json`.

The new packaged public-stock replay at
`/var/tmp/native-workspace-recovery-real-r3/verification.json` records16 captures:

- save `BackAnchor55` through explicit Send; create an empty session draft with
  `Retain55Draft` and preserved-draft.md mention; terminate only owned stock;
- reconnect in the same App, retire both old child identities, and retain the
  draft/attachment at700x760 without another model call;
- invalidating only the disposable profile config makes explicit New conversation
  fail in real stock. Capture07 shows the bounded RPC error in the compact view;
  the draft and mention remain. Restore config and explicitly retry;
- capture09/10 and exact UTF8 clipboard confirm the new conversation retains
  `Retain55Draft` and mention, with no automatic Send. The obsolete error notice
  is removed and the following explicit Send succeeds;
- resize1191x865; actual Back displays saved `BackAnchor55`, actual Forward
  displays saved `Retain55Draft` and its attachment/assistant, without visiting
  the retired ID or issuing another turn;
- exactly two controlled model POSTs result from the two explicit Sends. All
  five recorded App/Host/stock PIDs and the owned model are absent after awaited
  cleanup. The two standalone probe Hosts are also absent.

The initial private driver used the pre-attachment text coordinate before the
field moved, and its first clipboard request while the error notice covered the
field was unavailable. These artifacts remain preserved; the later exact
clipboard and actual visible states provide the stated positive evidence.
Neither this packet nor hosted CI is Human visual/long-session acceptance.
