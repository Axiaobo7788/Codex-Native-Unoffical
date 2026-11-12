# Peer Follow-Up Audit: Hot Workspace Recovery (`5e08cfe` + `retiredRuntimeVersion` Follow-Up)

Date: 2026-11-12
Reviewer: Antigravity / Gemini (official `agy` TUI peer session, `0` heavy/GUI/Host/stock/model workers)
Audited Target (as actually inspected): `/var/tmp/native-codex-workspace-recovery` commit `5e08cfe3f77bd02fb1ea29d46a396dbcbc2d2624` plus the 6-file uncommitted `retiredRuntimeVersion` working-tree diff (`PROJECT_STATUS.md`, `docs/DECISIONS.md`, `docs/reverse/WORKSPACE_RECOVERY_EVIDENCE.md`, `lib/src/app/codex_native_app.dart`, `lib/src/features/conversation/conversation_controller.dart`, `test/features/conversation/conversation_controller_test.dart`) prior to Root's subsequent commit/merge (`3d68ebe` / `24201ac` not separately re-read in this pass)
Prior Baseline Audit: `docs/reverse/HOT_RECOVERY_PEER_AUDIT.md` (`3c18450385869afe0eef0042a0f532672145ae22`)
Red-Before-Green Evidence Inspected: `/var/tmp/native-ui-r0.BbOvHT/runtime-recovery-peer-findings-red-r1.log`

---

## 1. Verdict Summary

- **Blocking Findings Remaining**: **`0` P0, `0` P1 (`NO BLOCKING FINDINGS`)**.
- **Prior `P1` / `P2-3` Dispositions**: **`P1-1` CLOSED**, **`P1-2` CLOSED**, **`P1-3` CLOSED**, **`P2-3` CLOSED** (`SOURCE-VERIFIED`, with `MACHINE VERIFIED` unit/widget coverage in `5e08cfe` + follow-up; new-source packaged real-stock session-draft replacement replay remains pending as recorded in `docs/reverse/WORKSPACE_RECOVERY_EVIDENCE.md`).
- **Remaining Findings**: **`3` concrete non-blocking `P2` source observations** + **`2` retained `P2` hypotheses/hygiene items** (`P2-1`, `P2-2`).

---

## 2. Disposition of Prior Findings (`HOT_RECOVERY_PEER_AUDIT.md`)

1. **`P1-1` — Session-only unmaterialized / ephemeral thread IDs across runtime restart: `CLOSED` (`SOURCE-VERIFIED`, real-stock replacement replay pending)**
   - `ThreadListController.invalidateRuntime()` (`lib/src/features/threads/thread_list_controller.dart:99-107`) moves `_unmaterializedThreadIds` and any `row.ephemeral` / `selected.ephemeral` IDs into bounded `_retiredSessionDraftIds` (pruned in `_synchronizeSelection` at `:1959`).
   - `_refreshRecoveredWorkspace` (`lib/src/app/codex_native_app.dart:254-277`) refreshes catalog with `preserveSelection: true` and runs metadata-only `selectThread(selectedId)` (`lib/src/features/threads/thread_list_controller.dart:746-783` bypasses the unmaterialized fast-path when `_retiredSessionDraftIds.contains(threadId)` and queries `gateway.readThread`).
   - Failed `readThread` keeps `selectedThreadNeedsDraftRecovery(id) == true` (treated as unavailable/unconfirmed, not proof of deletion or zero accepted work), skips `historyController.bindThread` so last-known bounded prose is not replaced by fabricated empty history, and fails closed in `ensureSelectedThreadLoadedWithOutcome` / `resumeThreadWithOutcome` (`:793-795`, `:1456-1458`). Arbitrary saved-thread failures remain on their normal explicit-resume error path.
   - `_resumeErrorBanner` (`lib/src/app/presentation/conversation.dart:2982-3085`) exposes explicit user-initiated `runtime-draft-new-conversation` (`New conversation`), hides dead `conversation-resume-error-dismiss` when `canReplaceDraft || historyFailure` (`:3034`), starts a replacement thread in `oldThread.cwd` via `replaceSessionDraftId: oldThread.id` (evicting only the local placeholder row at `thread_list_controller.dart:720-725`, zero rollout/store deletion, zero auto-Send/replay), and transfers `_composerController.text` + `_composerAttachments` (`conversation.dart:7449-7498`).

2. **`P1-2` — Queued async broadcast relay notifications delivered after retirement: `CLOSED` (`SOURCE-VERIFIED` + `MACHINE VERIFIED` red-to-green)**
   - Preserved red log `/var/tmp/native-ui-r0.BbOvHT/runtime-recovery-peer-findings-red-r1.log` confirmed `queued runtime relay never delivers a notification after retirement` failed (`Actual: [false]`) before the fix.
   - All 8 application-owned relay controllers in `lib/src/app/runtime_controller.dart:142-157` (`_turnEvents`, `_threadEvents`, `_approvalEvents`, `_userInputEvents`, `_mcpElicitationEvents`, `_mcpOauthEvents`, `_runtimeDiagnosticsEvents`, `_threadAttachmentEvents`) now use `StreamController<...>.broadcast(sync: true)`.
   - `_invalidateMcpOauth()` (`lib/src/app/runtime_controller.dart:221-230`) schedules `McpOauthInvalidatedEvent` via microtask guarded by `epoch == _desktopEpoch && !_mcpOauthEvents.isClosed`. Reentrancy across `shutdown()` (`:1436-1448`) and `_closeDesktopTransport()` (`:1278-1283`) is safe because transport retirement awaits subscription cancellation before controller `.close()` or subsequent `++_desktopEpoch`.

3. **`P1-3` — Root-overlay `CodexPopover` remains open and hit-testable when workspace is `Offstage`: `CLOSED` (`SOURCE-VERIFIED` + `MACHINE VERIFIED` red-to-green)**
   - Preserved red log confirmed `runtime loss dismisses root-overlay composer popovers` failed (`Found 1 widget with text "Attach file (@mention)"` hit-testable) before the fix.
   - `CodexPopoverAnchorState` (`lib/src/app/primitives/codex_popover.dart:81-93, 186-189`) unconditionally subscribes to `TickerMode.valuesOf(context).enabled` in `didChangeDependencies()`, schedules post-frame `_controller.hide()` when disabled (avoiding build-phase overlay mutation), and blocks `_showPopover()` while inactive.

4. **`P2-3` — Manual history `Retry` reconciliation and error visibility under retained live entries: `CLOSED` (`SOURCE-VERIFIED` + `MACHINE VERIFIED`)**
   - `_pendingRecoveredHistory` + `HistoryController.refreshVersion` (`lib/src/app/codex_native_app.dart:243-303`, `lib/src/features/history/history_controller.dart:45, 71, 417`) reconciles retired live entries on any subsequent successful newest-page refresh on the same `(runtimeVersion, threadId)`.
   - `lib/src/app/presentation/conversation.dart:2409-2415, 3015-3022` exposes `conversation-history-error-banner` and `conversation-history-retry` when retained live entries would otherwise hide the empty-turns history error view.

---

## 3. Non-Blocking `P2` Findings & Calibrated Hypotheses

### Concrete Source Observations (`SOURCE-VERIFIED`, Non-Blocking `P2`)

1. **`P2-A` — Reused `itemId` streaming delta / user-echo lookup in scalar `retiredRuntimeVersion` follow-up (`lib/src/features/conversation/conversation_controller.dart:56, 151-158, 838-849, 881-896, 914-932, 964-976`)**
   - Replacing the temporary `List<ConversationEntry>` snapshot with scalar `retiredRuntimeVersion` cleanly eliminates extra working-set retention after failed history reads.
   - Narrow edge on reused item IDs before `reconcileRecoveredHistory` runs: `test/features/conversation/conversation_controller_test.dart:34-76` emits a complete `AssistantMessageEvent(itemId: 'reused', text: 'Fresh accepted reply')` (overwriting via `_upsert`), whereas a streaming `AssistantDeltaEvent(itemId: 'reused', delta: 'Fresh ')` hits `_flushDelta` (`:914-932`), matches the retired Session-1 entry (`entry.id == itemId` without `entry.retiredRuntimeVersion == 0`), concatenates `'${existing.text}$delta'`, and resets `retiredRuntimeVersion` to `0` via `copyWith` (`:56`). Likewise `_handleUserMessage` (`:974`) checks `entry.stockItemId == event.itemId` across retired entries, dropping a reused user-item echo before `reconcileRecoveredHistory` removes the retired row.
   - Non-blocking for UUID stock item IDs; filtering live event lookups (`_upsert`, `_flushDelta`, `_flushReasoningDelta`, `_completeAssistantMessage`, `_handleUserMessage`) to `entry.retiredRuntimeVersion == 0` and using `entry.retiredRuntimeVersion > 0 && entry.retiredRuntimeVersion <= retiredVersion` in `reconcileRecoveredHistory` closes sequential/synthetic ID reuse across deltas too.

2. **`P2-B` — Compact / collapsed-sidebar error feedback if `New conversation` `startThread` RPC fails (`lib/src/app/presentation/conversation.dart:3066-3079`)**
   - `_replaceUnavailableSessionDraft` catches `StateError` from `settingsController.threadOptions`, while `ThreadListController.startThread` (`lib/src/features/threads/thread_list_controller.dart:730-733`) catches RPC errors into `threads.errorMessage` (shown inside `_ThreadPanel`) and returns `null`. When `_ThreadPanel` is hidden (`700x760` compact pane or collapsed wide sidebar), checking `created == null` and showing `threads.errorMessage` via `ScaffoldMessenger.maybeOf(context)` provides direct feedback.

3. **`P2-C` — Evicted placeholder ID retained in shell Back stack (`lib/src/app/presentation/app_shell.dart:309-365`)**
   - After `startThread(..., replaceSessionDraftId: oldId)` evicts `oldId` and selects `newId`, `_ConnectedWorkspaceState._navigationEntries` retains `oldId` as the prior Back entry. Clicking Back fails closed on `selectThread(oldId)` without data loss (`newId` stays selected); pruning/rewriting `replaceSessionDraftId` in `_navigationEntries` is minor cleanup.

### Calibrated Hypotheses / Hygiene (Unchanged from Baseline Audit)

4. **`P2-1` (`SOURCE-HYPOTHESIS` vs `ADR-061`)** — `_closeDesktopTransport` throw propagation in `_retireDesktopTransport` (`lib/src/app/runtime_controller.dart:1245-1284`) and late `_transportStarter` / second-caller `shutdown()` completion ordering (`:1066-1080`, `:1414-1451`) remain bounded lifecycle hypotheses unless a custom starter/closer throws or stalls.
5. **`P2-2` (`SOURCE-VERIFIED` Hygiene — Bounded Strings, NOT Host References)** — `DiffController` (`lib/src/features/diff/diff_controller.dart`) holds bounded plain-Dart `DiffSnapshot` strings (`<= 8` threads, `<= 200` files, `<= 256 KiB` patch text, zero Host spool/process handles); clearing or revalidating stale snapshots on cold same-ID reconnect remains optional freshness hygiene.

---

## 4. Documentation Check & `U8` Read-Only Candidate Ownership

- **Documentation Check**: Updates in `PROJECT_STATUS.md`, `docs/DECISIONS.md` (`ADR-063`), and `docs/reverse/WORKSPACE_RECOVERY_EVIDENCE.md` are factual, preserve negative evidence (`11-empty-send-attempt.png` and red-before-green logs), and keep evidence classes distinct (`MACHINE VERIFIED` vs `AGENT REAL-USE VERIFIED` vs `NOT YET HUMAN VERIFIED`).
- **Track U (`current 25894` `U8`) Read-Only Candidate Ownership (`0` Gemini heavy workers)**:
  1. **`A7` saved vs live activity-group hierarchy & non-shell tool rows** (`225284.NKAf` / `IgqH` / `getw`, `899308.tHoD` -> `lib/src/app/primitives/codex_activity_row.dart` + timeline activity grouping),
  2. **`A6` external user-attachment pill / hover-card presentation** (`225284` attachment strip above `.bubble-vBnidZ` -> `lib/src/app/primitives/codex_message_bubble.dart`), or
  3. **`State D` open `Changes` pane** (`lib/src/app/presentation/diff_approval_output.dart` — zero file overlap if Track F keeps `conversation.dart` write-locked in the next round).
