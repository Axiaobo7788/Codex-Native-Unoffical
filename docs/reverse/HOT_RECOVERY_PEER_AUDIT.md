# Hot Workspace Recovery — Peer Adversarial Audit

- **Date:** 2026-11-12
- **Auditor:** Antigravity / Gemini (official `agy` peer session, read-only audit; `0` heavy/runtime workers launched)
- **Inspected target:** Codex (`Root`) isolated Track F worktree `/var/tmp/native-codex-workspace-recovery` over base `2600ec5393226a3a7fed2cbf98cf7957015a169d` (`20` files changed: `1171` insertions, `162` deletions, plus `test/app/runtime_workspace_continuity_test.dart`)
- **Peer UI branch anchor:** `/var/tmp/native-gemini-u7-a6-user-bubble` (`44a88094a79176b0d3ba2ff77fb2fb7500a625af`, `U7` `A6` user-bubble actual-height `19lh` overflow clip only; `conversation.dart` lifecycle hook surface explicitly released to `Root`)
- **Scope & claim discipline:** This document records bounded peer-review findings on the inspected `Hot recovery` WIP state before final commit/integration. Neither `Hot recovery` nor whole `A6` / Golden State `A` is claimed complete here; Human visual acceptance remains `NOT YET HUMAN VERIFIED`.

---

## Summary Tally

- **P0:** `0`
- **Closed during WIP iteration (`MACHINE VERIFIED` / `SOURCE-VERIFIED`):** `2`
- **Open P1:** `3` (`1` `AGENT REAL-USE VERIFIED` real-crash reproduction; `2` `SOURCE-VERIFIED — RUNTIME/WIDGET UNVERIFIED`)
- **Open P2:** `3` (`SOURCE-VERIFIED — UNVERIFIED` bounded edge/hygiene hypotheses)

---

## Closed Findings in Inspected WIP Diff

1. **Retained Session-1 live entries shadowing freshly saved history after reconnect (`CLOSED — MACHINE VERIFIED` in targeted controller/widget runs):**
   - **Surface:** `lib/src/app/codex_native_app.dart` (`_refreshRecoveredWorkspace`, lines `232–264`) and `lib/src/features/conversation/conversation_controller.dart` (`reconcileRecoveredHistory`, lines `147–153`).
   - **Resolution:** Snapshots `oldProjection = _conversationController.entries` at recovery start and removes only `HashSet<ConversationEntry>.identity()..addAll(oldProjection)` once `_historyController.bindThread(..., force: true)` succeeds without error, preserving any newly started Session-2 turn entries and `_latestWarning`.
   - **Residual P2 edge (`SOURCE-VERIFIED — UNVERIFIED`):** See **P2-3** below if `bindThread` fails transiently on reconnect and succeeds only on a later manual History Retry.

2. **Uncaught `StateError` from `ExecutionSettingsController.threadOptions(cwd)` while `_waitingForFreshCatalog` (`CLOSED — SOURCE-VERIFIED`):**
   - **Surface:** `lib/src/app/presentation/conversation.dart` (lines `6173–6183`) and `lib/src/app/presentation/sidebar_activity.dart` (lines `952–961`).
   - **Resolution:** Verified all `threadOptions(` / `turnOptions(` call sites across `lib/`; only those two new-thread UI entry points invoke `threadOptions(cwd)` outside `ConversationController.submit` `try/catch`, and both now catch `StateError` without falling back to a silent default model.
   - **Minor polish note:** Prefer `ScaffoldMessenger.maybeOf(context)?.showSnackBar(...)` (matching `conversation.dart:6236`) over `ScaffoldMessenger.of(context)`.

---

## Open P1 Findings

### P1-1 — Previous-session unmaterialized / `ephemeral` thread IDs treated as loaded across runtime loss (`CONFIRMED — AGENT REAL-USE VERIFIED`)

- **Evidence class:** `AGENT REAL-USE VERIFIED` (`Root` real-runtime repro `/var/tmp/native-workspace-recovery-real-r1/public/shell-candidate-r2/11-empty-send-attempt.png`: `New chat` with no first turn -> owned stock `SIGKILL` -> `Reconnect` -> `Send` yields `-32600 thread not found` on the dead Session-1 ID with optimistic ghost/error state) + `SOURCE-VERIFIED`.
- **Exact source mechanism:**
  - `ThreadListController.startThread` (`lib/src/features/threads/thread_list_controller.dart:699`) records the Session-1 ID in `_unmaterializedThreadIds`.
  - `invalidateRuntime()` (`thread_list_controller.dart:98–127`) sets `_selectedThread` status to `ThreadRuntimeStatus.notLoaded` without retiring `_unmaterializedThreadIds`, and `_synchronizeSelection(preserveSelection: true)` (`thread_list_controller.dart:1911–1935`) retains `selectedId` in `_unmaterializedThreadIds` via `_preserveOutsideCatalog = true`.
  - On recovery, `selectThread(selectedId)` (`thread_list_controller.dart:719–727`) only skips `readThread` when the ID is still in `_threads`; when absent from Session-2 `listThreads`, `readThread` fails (`-32600`), leaving `_selectedThread` selected and `selectedId` in `_unmaterializedThreadIds`.
  - On subsequent composer **Send**, `selectedThreadNeedsResume(targetThreadId)` (`thread_list_controller.dart:1382–1385`) returns `false` because `!_unmaterializedThreadIds.contains(threadId)` is `false`, `ensureSelectedThreadLoadedWithOutcome` (`1417–1426`) returns `loaded(current)`, and `submit()` calls `startTurn` against the nonexistent Session-1 ID.
- **Agreed safe boundary & exact traps to guard:**
  - **No silent auto-recreate / no auto-Send:** Because `_unmaterializedThreadIds` only clears asynchronously on `ThreadStatusChangedEvent != notLoaded` (`1439–1441`) or `readThread`/`resumeThread`, an accepted first turn that raced with runtime death may or may not have persisted. Never treat a previous-session unmaterialized marker as loaded in a new session, and never claim a thread is empty/deleted purely from the marker or a failed metadata read.
  - **Recovery probe:** Mark previous-session unmaterialized (and `thread.ephemeral == true`) IDs as stale-session candidates on `invalidateRuntime()`, then attempt a bounded metadata `readThread` on recovery (no implicit `resumeThread` or write). If `readThread` succeeds, clear the stale marker and bind history normally; if unavailable, leave the conversation unconfirmed/unavailable and surface a truthful composer notice offering an explicit **New conversation** action (keeping arbitrary saved-thread read failures distinct).
  - **Trap 1 — Attachment wipe on replacement selection:** `_ConversationPanelState._syncActiveThreadSelection` (`lib/src/app/presentation/conversation.dart:7395–7397`) unconditionally runs `_composerAttachments.clear()` whenever `nextThreadId != _activeThreadId` (even when mounted). The explicit **New conversation** replacement bridge must preserve draft text, `_composerAttachments`, and the dead thread's `cwd` across that single `threadId` transition, fenced by selection/operation generation.
  - **Trap 2 — `thread.ephemeral`:** Ephemeral threads (`thread_list_controller.dart:120–125`) never persist across stock process exit and must follow the same stale-session rule rather than offering a doomed cold `resumeThread`.

### P1-2 — Async gateway broadcast streams can deliver pre-exit Session-1 events after synchronous `invalidateRuntime()` (`SOURCE-VERIFIED — RUNTIME UNVERIFIED`)

- **Evidence class:** `SOURCE-VERIFIED — RUNTIME UNVERIFIED` (deterministic in Dart async broadcast stream semantics; not yet isolated by a dedicated microtask-ordering test).
- **Exact source mechanism:**
  - `RuntimeController` declares its 8 application-owned event streams (`_turnEvents`, `_threadEvents`, `_approvalEvents`, `_userInputEvents`, `_mcpElicitationEvents`, `_mcpOauthEvents`, `_runtimeDiagnosticsEvents`, `_threadAttachmentEvents` at `lib/src/app/runtime_controller.dart:139–154`) as asynchronous `StreamController.broadcast()` (`sync: false`).
  - When a Session-1 notification arrives immediately before `ProcessExit` / `ProtocolViolation`, `_turnEvents.add(event)` (`1115`) queues listener delivery onto a later microtask, whereas `_handleExit` / `_handleProtocolError` (`1367–1399`) bumps `_desktopEpoch` and synchronously invokes `_setSnapshot(...)` -> `CodexNativeApp._handleRuntimeState()` -> feature `invalidateRuntime()` (`lib/src/app/codex_native_app.dart:210–215`) *before* that already-queued microtask fires.
  - When the queued microtask drains after `invalidateRuntime()`, `ApprovalController`, `UserInputController`, `ConversationController`, and `ThreadListController` receive the stale Session-1 event as if it were post-invalidation traffic (re-populating dead server-request IDs or setting `_busy = true` / `ThreadRuntimeStatus.active`).
- **Minimal fix options:** Use `StreamController<...>.broadcast(sync: true)` for those 8 relay streams (transport listeners already guard `if (current())` synchronously before adding) and/or ignore gateway events in feature controllers while runtime state is not `connected`.

### P1-3 — Root-overlay `CodexPopoverAnchor` popovers stay interactive above `_RuntimeConnectionScreen` (`SOURCE-VERIFIED — WIDGET UNVERIFIED`)

- **Evidence class:** `SOURCE-VERIFIED — WIDGET UNVERIFIED`.
- **Exact source mechanism:**
  - `AppShell` keeps workspace state alive during runtime loss via `Offstage` + `TickerMode(enabled: false)` + `ExcludeSemantics` + `ExcludeFocus` + `IgnorePointer` (`lib/src/app/presentation/app_shell.dart:495–510`), and `CodexNativeApp._handleRuntimeState` pops non-first `Navigator` routes via `popUntil((route) => route.isFirst)` (`lib/src/app/codex_native_app.dart:207`).
  - However, `CodexPopoverAnchor` (`lib/src/app/primitives/codex_popover.dart:171–217`) inserts `OverlayEntry`s directly into `Overlay.maybeOf(context, rootOverlay: true)` — sibling entries inside `Navigator`'s root `Overlay`, outside `AppShell`'s subtree wrappers and unaffected by `popUntil`. Any model/effort/permission/thread/PR/composer menu popover open at runtime loss remains visible, focused, and clickable on top of `_RuntimeConnectionScreen`.
- **Minimal fix:** In `CodexPopoverAnchorState.didChangeDependencies()`, auto-hide when `!TickerMode.valuesOf(context).enabled` (scheduling cleanup safely if needed).

---

## Open P2 Findings (Bounded Hypotheses & Display Hygiene)

### P2-1 — Transport-retirement cleanup throw & `shutdown()` / pending `_transportStarter` ordering vs `ADR-061` (`SOURCE-VERIFIED — UNVERIFIED`)

- **Evidence class:** `SOURCE-VERIFIED — UNVERIFIED`.
- **Explicit distinction from `ADR-061` and existing `runtime_startup_retry_test.dart` (`MACHINE VERIFIED`):**
  - Existing `ADR-061` tests already verify that when `shutdown()` runs during `start()`, `!_isCurrentDesktopAttempt(epoch)` prevents overwriting `RuntimeConnectionState.stopped` and `_startDesktop` closes the late transport at `lib/src/app/runtime_controller.dart:1100–1102` when `transport.close()` succeeds.
  - Two narrower edges remain distinct from that covered path:
    1. **Cleanup-throw propagation (`runtime_controller.dart:398, 1228–1236, 1274, 1406, 1428`):** If `transport?.close()` throws inside `_closeDesktopTransport()`, `_retireDesktopTransport()` completes `_desktopRetirement` with error. `_retireFaultedDesktop()` (`1406`) ignores that error via `.catchError`, **but** if `shutdown()` (`1428`) or `_recoverDesktop()` (`398`) joins that same `_desktopRetirement` future (or initiates it), `shutdown()` aborts before closing the 8 `StreamController`s (`1433–1440`) or setting `stopped` (`1442`), and `_recoverDesktop()` fails fresh startup even though `_transport` was already detached (`1246`).
    2. **Caller completion ordering (`runtime_controller.dart:1099–1102, 1424–1428`):** If `shutdown()` is awaited while `_transportStarter` is still pending (`1099`, `_transport == null`), `await shutdown()` resolves before `_startDesktop` resumes at `1101` to finish `await transport.close()`; similarly, a second `shutdown()` caller at `1424` (`if (_stopping) return;`) returns immediately instead of joining the in-flight shutdown future.

### P2-2 — `DiffController` retains previous-session ephemeral turn diff across cold reconnect on same `thread.id` (`SOURCE-VERIFIED — UNVERIFIED`)

- **Evidence class:** `SOURCE-VERIFIED — UNVERIFIED` (correctly `P2` display-state hygiene, **not** `P1`: `DiffSnapshot` stores bounded plain Dart strings/hunks with zero Host/process references).
- **Exact source mechanism:** `DiffController` (`lib/src/features/diff/diff_controller.dart:32–41`) is not invalidated in `CodexNativeApp._handleRuntimeState()` and `bindThread(selected)` early-returns when `_thread?.id == thread?.id`, leaving Session 1's last in-memory `TurnDiffUpdatedEvent` snapshot visible until a new turn emits a diff or the user switches threads.

### P2-3 — Manual History Retry after transient reconnect `bindThread` error skips `reconcileRecoveredHistory` (`SOURCE-VERIFIED — UNVERIFIED`)

- **Evidence class:** `SOURCE-VERIFIED — UNVERIFIED`.
- **Exact source mechanism:** In `CodexNativeApp._refreshRecoveredWorkspace` (`lib/src/app/codex_native_app.dart:256–264`), `reconcileRecoveredHistory(oldProjection)` runs only if the initial recovery `bindThread` finishes with `_historyController.errorMessage == null`. If that initial `thread/read` fails transiently and the user later clicks History **Retry** (`_historyController.refresh()`), `oldProjection` is not reconciled and continues shadowing the newly loaded history items.
