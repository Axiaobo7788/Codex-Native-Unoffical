# Local Desktop workspace recovery evidence

Status: implementation and focused machine verification; integration and the
latest-source packaged correction remain pending. Program remains SELF_ITERATION.
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
- Retained live entries initially shadowed fresh saved history. Identity-based
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
