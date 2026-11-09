# Stored Thread Attachment Unlink (`thread/attachment/remove`) — Static & Live Evidence Packet

- **Date:** 2026-11-10
- **Target Baseline:** `d67290e4a97c265f967bbb51bf98087c9fbc890e`
- **Inspected Stock Runtime:** `codex-cli 0.167.0-alpha.3.2` (`/opt/codex-desktop/resources/codex`, SHA-256 `c8242fc9e1bac7c6d661a228cecfaf50e6db74da219e4a9ca8912827e11607f0`)
- **Inspected Official Desktop Bundle:** Linux-packaged ChatGPT / Codex Desktop `26.1103.60933` (build `25894`, `/opt/codex-desktop/resources/app.asar`, SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`)
- **Evidence Grade:** `PUBLIC_DOC` / `PUBLIC_SOURCE` (upstream `app-server` README `#stored-thread-attachments`), `LOCAL_SCHEMA` (generated v2 JSON schema), `STATIC_BUNDLE` (Desktop ASAR + `codex` binary SQL/error strings), `LIVE_CALLED` (disposable `CODEX_HOME` stock `codex app-server` stdio/WebSocket and debug Host executable `target/debug/codex-native-host` probes)

---

## 1. Executive Summary

`thread/attachment/remove` and `thread/attachment/updated` (`operation: "deleted"`) are present in the **stable (`PUBLIC_SUPPORTED`)** stock `codex app-server 0.167.0-alpha.3.2` schema. Static inspection of the `codex` binary and Desktop `26.1103.60933` ASAR together with disposable live probes establish five critical behavioral invariants that govern any future Native review-reference unlink surface:

1. **Exact SQLite key deletion with no compare-and-delete precondition:**
   - Stock `thread/attachment/remove` executes `SELECT 1 FROM threads WHERE id = ?` followed by:
     ```sql
     DELETE FROM thread_attachments
     WHERE thread_id = ? AND attachment_type = ? AND identity_key = ?
     RETURNING id, thread_id, attachment_type, identity_key, payload, created_at
     ```
   - `ThreadAttachmentRemoveParams` accepts only `{ threadId, attachmentType, identityKey }`. There is **no** `attachmentId`, `expectedRevision`, or payload compare-and-delete precondition parameter; supplying extra fields such as `attachmentId` or `expectedRevision` on the wire is silently ignored by serde deserialization (`{"result": {}}`) and does not guard the deletion.
2. **Untrimmed `identityKey` storage vs. trimmed validation (`LIVE_CALLED`):**
   - Stock rejects empty or whitespace-only `identityKey` (`"identityKey must not be empty"`) and keys exceeding 256 UTF-8 bytes (`"identityKey must not exceed 256 bytes"`), **but stores non-empty `identityKey` strings verbatim in `state_5.sqlite` without trimming leading or trailing spaces**.
   - Native's current `ThreadAttachmentProtocolAdapter._requireBoundedSingleLineField` ([`lib/src/protocol/thread_attachment_protocol.dart`](../../lib/src/protocol/thread_attachment_protocol.dart)) trims `raw['identityKey']` on ingress and stores only the synthesized `canonicalIdentityKey` on [`ThreadLinkedPullRequest`](../../lib/src/domain/thread_attachment_models.dart). Passing a trimmed or synthesized canonical key to `thread/attachment/remove` when the stored SQLite row has a legacy URL key, a non-canonical 4-tuple key (`'["www.github.com", "ExampleOrg", "ExampleRepo", "42"]'`), or leading/trailing whitespace returns `{}` (silent no-op), emits **no** `thread/attachment/updated` notification, and leaves the row persisted in SQLite.
3. **Coexisting canonical and legacy alias rows (per-item validation vs. scan deduplication):**
   - Because `thread_attachments` enforces `UNIQUE (thread_id, attachment_type, identity_key)` on the raw `identity_key` string, a single thread can simultaneously hold multiple `pull_request` rows for the same PR/MR (for example, a legacy URL key `'https://github.com/ExampleOrg/ExampleRepo/pull/42'`, a non-canonical 4-tuple key `'["www.github.com", "ExampleOrg", "ExampleRepo", "42"]'`, and the canonical 4-tuple key `'["github.com","exampleorg","examplerepo",42]'`).
   - In Native, per-item validation (`ThreadAttachmentProtocolAdapter._matchesCanonicalIdentityKey` inside `_parseLinkedPullRequestItem`) accepts each of those alias shapes and maps them to the same `canonicalIdentityKey`, while scan-level deduplication (`seenIdentityKeys` in `readLinkedPullRequests`) retains only the first encountered row per `canonicalIdentityKey`.
4. **Notification delivery and ordering:**
   - Removing an existing row returns `{}` and emits `thread/attachment/updated` with `operation: "deleted"`, the deleted row's `attachmentId`, and its exact `identityKey`. Removing an already-deleted or non-existent key on a persisted thread returns `{}` and emits **no** notification.
   - On a single `codex app-server` instance, `thread/attachment/updated` is broadcast to all initialized connections (including unsubscribed WebSocket peers when the thread is `notLoaded`), and can arrive on the wire **either immediately before or immediately after** the `thread/attachment/remove` RPC response. Across separate OS `codex app-server` processes sharing `state_5.sqlite`, only the process executing `thread/attachment/remove` emits the notification; other processes observe the removal only on their next `thread/attachment/list` read.
5. **Cold-thread preservation:**
   - Like `thread/attachment/list` and `thread/attachment/add`, calling `thread/attachment/remove` on a cold persisted thread (`status: {"type": "notLoaded"}`) mutates `state_5.sqlite` directly without loading the thread into `thread/loaded/list`.

---

## 2. Stock Protocol & Binary Contract (`0.167.0-alpha.3.2`)

### 2.1 Schema & SQL Execution Path

In `codex-cli 0.167.0-alpha.3.2` (`app-server/src/request_processors/thread_attachments.rs`, `thread-store/src/local/thread_attachments.rs`, and `state/src/runtime/thread_attachments.rs`, inspected at binary offsets `266681276`–`266682150`):

| Aspect | Observed Contract | Evidence |
|---|---|---|
| Request method | `thread/attachment/remove` | `LOCAL_SCHEMA`, `PUBLIC_SOURCE` |
| Request params | `{ "threadId": string, "attachmentType": string, "identityKey": string }` | `LOCAL_SCHEMA` (`ThreadAttachmentRemoveParams`) |
| Response payload | `{}` (`ThreadAttachmentRemoveResponse`) | `LOCAL_SCHEMA`, `LIVE_CALLED` |
| Prerequisite check | `SELECT 1 FROM threads WHERE id = ?` | `STATIC_BUNDLE` (`@ 266681340`), `LIVE_CALLED` |
| Delete statement | `DELETE FROM thread_attachments WHERE thread_id = ? AND attachment_type = ? AND identity_key = ? RETURNING id, thread_id, attachment_type, identity_key, payload, created_at` | `STATIC_BUNDLE` (`@ 266681928`), `LIVE_CALLED` |
| Notification (if `RETURNING` yields a row) | `thread/attachment/updated` with `{ threadId, attachmentId, attachmentType, identityKey, operation: "deleted" }` | `LOCAL_SCHEMA`, `LIVE_CALLED` |
| Notification (if 0 rows deleted) | None emitted | `LIVE_CALLED` |

### 2.2 Parameter Validation & Whitespace Asymmetry (`LIVE_CALLED`)

Disposable stdio probes against `/opt/codex-desktop/resources/codex` (`0.167.0-alpha.3.2`) with `capabilities: { experimentalApi: false }` verified the exact validation responses on `thread/attachment/remove`:

| Probe Case | Request Params | Observed Stock Result |
|---|---|---|
| Unmaterialized `thread/start` thread (no `threads` row in `state_5.sqlite`) | `{ threadId: "<unmaterialized-thread-id>", attachmentType: "pull_request", identityKey: "[\"github.com\",\"org\",\"repo\",1]" }` | Error `-32602`: `"thread not found: <unmaterialized-thread-id>"` |
| Empty / whitespace `attachmentType` | `{ threadId: "<thread-id>", attachmentType: "   ", identityKey: "k" }` | Error `-32602`: `"attachmentType must not be empty"` |
| Empty `identityKey` | `{ threadId: "<thread-id>", attachmentType: "pull_request", identityKey: "" }` | Error `-32602`: `"identityKey must not be empty"` |
| Whitespace-only `identityKey` | `{ threadId: "<thread-id>", attachmentType: "pull_request", identityKey: "   " }` | Error `-32602`: `"identityKey must not be empty"` |
| Oversized `identityKey` (`257` UTF-8 bytes) | `{ threadId: "<thread-id>", attachmentType: "pull_request", identityKey: "a" * 257 }` | Error `-32602`: `"identityKey must not exceed 256 bytes"` |
| Extra unknown precondition fields (`attachmentId`, `expectedRevision`) | `{ threadId: "<thread-id>", attachmentType: "pull_request", identityKey: "...", attachmentId: "<attachment-id>", expectedRevision: 1 }` | Returns `{"result": {}}`; unknown fields are ignored by serde and **do not** enforce compare-and-delete |
| Padded non-empty `identityKey` (`'  ["github.com","exampleorg","examplerepo",77]  '`) | Added via `thread/attachment/add`, then `remove` called with trimmed `'["github.com","exampleorg","examplerepo",77]'` | `add` stores `'  ["github.com","exampleorg","examplerepo",77]  '` **untrimmed**. `remove` with trimmed key returns `{}` (0 rows deleted, 0 notifications), leaving the padded row in `thread/attachment/list`. Calling `remove` with the exact untrimmed key deletes the row. |

---

## 3. Official Desktop (`26.1103.60933`) Static Call Sites (`STATIC_BUNDLE`)

Static inspection of `/opt/codex-desktop/resources/app.asar` (`SHA-256 121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`) identified two `pull_request` attachment removal call-site families: the renderer dynamic-tool unlink path and the main-process managed-worktree archival path.

### 3.1 Dynamic-Tool PR Unlink Path (`Ygco.Z$` at offset `115750374` & `remove_artifact` at offset `317458286`)

1. **Static call sites:**
   - Module `Ygco` (`offset 115748676`) defines the renderer PR attachment store helpers, exporting the link helper (`op` at offset `115749720`) and the unlink helper (`Z$` at offset `115750374`).
   - In the inspected bundle, the unlink helper (`Ygco.Z$`) is called by the dynamic-tool dispatcher `rUmy` (`executeDynamicToolCallRequest` at offset `317458286`) when servicing the `codex_app` tool `remove_artifact` (`n2eO` at offset `110494285`, which validates an input object containing `artifact_type: "pull_request"` and a non-empty `url`).
2. **Query hydration and raw `identityKey` retention (`WiNP.Nt` at offset `111035680`):**
   - The per-thread attachment query in `WiNP` (`offset 111034460`) pages through `thread/attachment/list` (`limit: 100`) until `nextCursor` is null.
   - For each `"pull_request"` record whose `payload` contains a valid GitHub/GitLab PR URL (parsed via `fiy3.g0` at offset `115740801`), the query retains the record's **raw stored `identityKey`** alongside its `url`, optional `root`, optional `headBranch`, and timestamp. Unlike `"worktree"` records, `"pull_request"` records in `WiNP.Nt` are not filtered by `identityKey` format and are not deduplicated across alias rows.
3. **Behavioral sequence of the unlink helper (`Ygco.Z$` at offset `115750374`):**
   - **Step 1 (Optimistic cache filter):** Cancels any in-flight `WiNP.Nt` query for the `(conversationId, hostId)` pair and optimistically removes entries whose URL matches the target PR under canonical `(hostname, owner, repository, number)` comparison (`fiy3.E6` at offset `115741470`).
   - **Step 2 (Forced full refresh):** Calls `WiNP.oI` (`offset 111037666`), which invalidates the per-thread attachment query and awaits a fresh `thread/attachment/list` fetch (`limit: 100` loop until `nextCursor == null`).
   - **Step 3 (Multi-key match by canonical URL equivalence):** Filters the refreshed attachment list for every `"pull_request"` entry whose `payload.url` matches the target PR via `fiy3.E6` (`fiy3.Tx` / `fiy3.S9` canonical 4-tuple comparison), collecting all matching entries with their stored `identityKey` values.
   - **Step 4 (Parallel `thread/attachment/remove` dispatch):** Dispatches `thread/attachment/remove` (`attachmentType: "pull_request"`, `identityKey: <entry.identityKey>`) across all matched entries concurrently via `Promise.all` through the host transport adapter (`TkUj.B` at offset `111034326`).
   - **Step 5 (Rollback on error and final invalidation):** Reverts the optimistic query snapshot if `Promise.all` rejects, and unconditionally invalidates the `WiNP.Nt` query in `finally`.

### 3.2 Managed-Worktree Detach / Archive Path (`$Z.removeFromThread` at offset `10891665` & `$Z.#ir` at offset `10896950`)

- When archiving or detaching a managed worktree, the main-process worktree service lists all thread attachments (`$d` at offset `10852512`, paging `thread/attachment/list` with `limit: 100`), identifies `"pull_request"` rows whose `payload.root` matches the worktree root (`$c` at offset `10852396`) together with any caller-supplied `pullRequestIdentityKeys`, copies their `{ identityKey, payload }` pairs into the `"archived_worktree"` recovery record, and removes each matched `"pull_request"` `identityKey` via `Promise.allSettled` (`offset 10897950`).

---

## 4. Disposable Live Probes: Coexisting Aliases, Notification Ordering & Concurrency (`LIVE_CALLED`)

### 4.1 Coexisting Legacy URL, Non-Canonical 4-Tuple, and Canonical 4-Tuple Rows

In a disposable `CODEX_HOME` probe against stock `0.167.0-alpha.3.2`, three `pull_request` rows for `https://github.com/ExampleOrg/ExampleRepo/pull/42` were added to the same persisted thread (`<thread-id>`):

1. **Row 1 (legacy URL `identityKey`):**
   - `identityKey`: `'https://github.com/ExampleOrg/ExampleRepo/pull/42'`
   - `id`: `'<legacy-attachment-id>'`, `outcome`: `'created'`
2. **Row 2 (non-canonical 4-tuple `identityKey` with `www.` host, mixed case, and string number):**
   - `identityKey`: `'["www.github.com", "ExampleOrg", "ExampleRepo", "42"]'`
   - `id`: `'<variant-attachment-id>'`, `outcome`: `'created'`
3. **Row 3 (canonical 4-tuple `identityKey`):**
   - `identityKey`: `'["github.com","exampleorg","examplerepo",42]'`
   - `id`: `'<canonical-attachment-id>'`, `outcome`: `'created'`

In Native's [`ThreadAttachmentProtocolAdapter`](../../lib/src/protocol/thread_attachment_protocol.dart), per-item validation (`_matchesCanonicalIdentityKey` inside `_parseLinkedPullRequestItem`) accepts all three rows and normalizes each to `canonicalIdentityKey: '["github.com","exampleorg","examplerepo",42]'`, while scan-level deduplication (`seenIdentityKeys` in `readLinkedPullRequests`) collapses them into a single `ThreadLinkedPullRequest` (`ExampleOrg/ExampleRepo#42`):

- **Removing only the canonical key (`Row 3`) when `Row 1` and `Row 2` coexist:**
  - `thread/attachment/remove` with `identityKey: '["github.com","exampleorg","examplerepo",42]'` returned `{}` and emitted:
    ```json
    {
      "method": "thread/attachment/updated",
      "params": {
        "threadId": "<thread-id>",
        "attachmentType": "pull_request",
        "identityKey": "[\"github.com\",\"exampleorg\",\"examplerepo\",42]",
        "attachmentId": "<canonical-attachment-id>",
        "operation": "deleted"
      }
    }
    ```
  - Immediate `thread/attachment/list` still returned `Row 1` and `Row 2`. Under Native's `readLinkedPullRequests`, per-item `_matchesCanonicalIdentityKey` validation and `seenIdentityKeys` deduplication therefore **continued to project** `ExampleOrg/ExampleRepo#42` (now backed by `Row 1`) after the refresh triggered by `thread/attachment/updated`.
- **Sequential removal of `Row 1` and `Row 2`:**
  - Emitted one `thread/attachment/updated` (`operation: "deleted"`) notification per deleted row (`<legacy-attachment-id>` and `<variant-attachment-id>`), after which `thread/attachment/list` returned `{"data": [], "nextCursor": null}`.
  - Throughout the entire sequence after an app-server restart, `thread/read(includeTurns: false)` reported `status: {"type": "notLoaded"}` and `thread/loaded/list` remained `{"data": [], "nextCursor": null}`.

### 4.2 Stale Retry / Intervening Re-Add Race (`LIVE_CALLED`)

To verify the consequence of `ThreadAttachmentRemoveParams` having no compare-and-delete (`attachmentId` or `expectedRevision`) field:

1. `Row 3` (`id: <canonical-attachment-id>`) was removed.
2. Before a simulated retry of the original remove request, `thread/attachment/add` re-linked the same `identityKey` (`'["github.com","exampleorg","examplerepo",42]'`, `headBranch: "readded-branch"`), minting a **new** row `id: <readded-attachment-id>` (`outcome: "created"`).
3. A stale retry of `thread/attachment/remove` was sent—including `"attachmentId": "<canonical-attachment-id>"` in the JSON-RPC params.
4. Stock ignored the extra `attachmentId` field, deleted the newly created row `<readded-attachment-id>`, and emitted `thread/attachment/updated` with `operation: "deleted"` and `attachmentId: "<readded-attachment-id>"`.

### 4.3 Notification vs. RPC Response Ordering, Debug Host Executable, and Multi-Client Delivery (`LIVE_CALLED`)

| Topology | Observed Behavior |
|---|---|
| **Single stdio stream (`codex app-server` & debug Host executable `target/debug/codex-native-host`)** | `thread/attachment/updated` (`operation: "created"` or `"deleted"`) is dispatched asynchronously relative to the RPC response: in back-to-back calls within the same probe, `thread/attachment/updated` arrived on stdout **before** `{"id": 18, "result": {}}` on one remove call and **after** `{"id": 22, "result": {}}` on the next. The debug Host executable (`target/debug/codex-native-host`) forwarded `thread/attachment/add`, `thread/attachment/remove`, `thread/attachment/list`, and both `created`/`deleted` notifications transparently. |
| **Two WebSocket connections (`ws://127.0.0.1:<ephemeral-port>`) to one `codex app-server`** | When `ws_a` called `thread/attachment/add` and `thread/attachment/remove` on a cold thread (`status: {"type": "notLoaded"}`), **both** `ws_a` and an unsubscribed second connection `ws_b` received `thread/attachment/updated` (`["created", "deleted"]`). Resuming the thread on `ws_b` preserved identical broadcast delivery to both connections. |
| **Two separate OS `codex app-server` processes sharing `state_5.sqlite`** | When `p1` added a `pull_request` attachment and `p2` removed it via `thread/attachment/remove`, `p2` emitted `thread/attachment/updated` (`operation: "deleted"`) while `p1` emitted **no** delete notification. A subsequent `thread/attachment/list` on `p1` immediately returned `0` rows from SQLite. |
| **Track A Direct-Host Remote (`remote_bridge.rs` / `transform.rs`)** | `thread/attachment/*` is not on the Rust Host read-only Remote allowlist (`model/list`, `thread/list`, metadata-only `thread/read`, `thread/turns/list`, `thread/items/list`, `thread/items/read`) and is not forwarded by `transform.rs`. Remote remains fail-closed. |

---

## 5. Comparison of Candidate Future Product Contracts (Evidence & Risks)

Per the F22 peer scope, Native does **not** implement review-reference removal in this slice. Two distinct product contracts are possible for a future implementation slice; their measured tradeoffs and concurrency risks are recorded below.

### 5.1 Candidate Contract A — Exact Single-Key Removal

Under this contract, each user "Unlink" action issues a single `thread/attachment/remove` call for one backing row's exact raw `identityKey`.

- **Required model change if adopted:**
  - `ThreadLinkedPullRequest` must retain the **exact untrimmed raw `identityKey`** (`rawIdentityKey`) from the `thread/attachment/list` item that produced it, rather than sending `canonicalIdentityKey`. Otherwise, unlinking a legacy URL row (`identityKey: "https://github.com/..."`) or a whitespace-padded row (`identityKey: "  [\"github.com\",...]  "`) sends `canonicalIdentityKey`, which succeeds as a silent SQLite no-op (`{}`) without deleting the backing row.
- **Advantages:**
  - Single atomic RPC write per user click; cannot fail mid-loop after deleting a subset of rows.
  - Does not require scanning past the page that yielded the displayed row unless preflight existence verification is desired.
- **Measured Risks & Limitations:**
  1. **Silent re-emergence when alias rows coexist:** Because `_parseLinkedPullRequestItem` validates both canonical and legacy `identityKey` shapes via `_matchesCanonicalIdentityKey` while `readLinkedPullRequests` deduplicates them via `seenIdentityKeys`, if a thread holds both a canonical row and a legacy/variant row for the same PR (or if `readLinkedPullRequests` stopped early at the 16-PR display cap before seeing a second alias), removing the first row's `rawIdentityKey` succeeds and emits `operation: "deleted"`, but the subsequent `readLinkedPullRequests` refresh immediately re-displays the same PR chip backed by the surviving alias row.
  2. **Lost response / stale click + intervening re-add race (no compare-and-delete):** Because `thread/attachment/remove` has no `attachmentId` or `expectedRevision` precondition, if a single-key remove succeeds on the server but the response is lost (or a second remove for the same `rawIdentityKey` is dispatched before refresh completes) and another client/tool re-adds the same `rawIdentityKey` in the interim, the second remove will delete the newly created attachment (`<readded-attachment-id>`).

### 5.2 Candidate Contract B — Multi-Alias Sequential Removal

Under this contract, unlinking a displayed `ThreadLinkedPullRequest` removes **all** stored `pull_request` rows on that thread whose `(identityKey, payload.url)` passes `_matchesCanonicalIdentityKey` for the target `canonicalIdentityKey`.

- **Required scan & execution rules if adopted:**
  1. **Full bounded preflight scan before any delete:** Perform a fresh `thread/attachment/list` scan (`16` rows/page, up to `maxScannedAttachments = 100` and `maxScannedPages = 16`) that scans through `nextCursor == null` **without** breaking early at `maxRetainedPullRequests = 16` or at the first matching row, collecting every matching row's **exact untrimmed raw `identityKey`** in order.
  2. **Incomplete-scan guard (`scanIncomplete`):** Mirrors [`ADR-048`](../DECISIONS.md#adr-048--add-local-review-references-through-explicit-stock-writes): if the preflight scan stops with `nextCursor != null` (or an empty page with a non-null cursor), return `scanIncomplete` without issuing any `thread/attachment/remove` call so unseen aliases beyond the scan bound cannot silently survive.
  3. **Sequential (not parallel) removal of distinct matched raw keys:** Issue `thread/attachment/remove` sequentially for each distinct matched raw `identityKey` rather than `Promise.all`, keeping at most one mutation RPC in flight and serializing with the controller's scan/link queue.
- **Advantages:**
  - Matches Official Desktop's `Ygco.Z$` multi-alias removal outcome (clearing both canonical 4-tuple and legacy URL rows for the unlinked PR) so the PR does not reappear on refresh, while avoiding Desktop's unbounded page loop and parallel `Promise.all` burst.
  - Handles the zero-match case cleanly (if another process already deleted the row since the last UI refresh, the preflight scan finds `0` matching rows and refreshes the header without issuing a redundant write).
- **Measured Risks & Limitations:**
  1. **Partial failure across multiple alias keys:** If a thread has $k \ge 2$ alias rows $[K_1, K_2]$ for the same PR and `remove(K_1)` succeeds while `remove(K_2)` fails (e.g., runtime crash or transport error), $K_1$ is already deleted in `state_5.sqlite` while $K_2$ remains. Because re-inserting $K_1$ would fabricate a new `id`/`createdAt` and emit a spurious `created` event, the adapter must **not** attempt rollback; it must refresh the projection (which will still show the PR via $K_2$) and surface a bounded error so the user can retry explicitly.
  2. **Scan-to-delete TOCTOU window (intervening re-add or payload update):** Because stock provides no compare-and-delete (`attachmentId`) or multi-key transaction:
     - If another client/tool deletes and re-adds key $K_i$ (with a new `headBranch` or `attachmentId`) between the preflight `list` page and `remove(K_i)`, `remove(K_i)` will delete the newly re-added record.
     - If another client/tool links the same PR under a *new* alias key $K_{\text{new}}$ after the preflight scan has passed that position, $K_{\text{new}}$ will not be in the removal set and will remain after the post-unlink refresh.
  3. **Notification burst during sequential removal:** Deleting $k$ alias rows emits $k$ separate `thread/attachment/updated` (`operation: "deleted"`) notifications, which can arrive interleaved with the sequential `remove` RPC responses. The UI controller must coalesce or defer its post-unlink `readLinkedPullRequests` refresh until the active unlink operation finishes (using the existing single in-flight scan + single replaceable pending target queue) so $k$ deletes do not trigger $k$ redundant full scans.

### 5.3 Shared Invariant Across Both Contracts: No Automatic Retry

In both Contract A and Contract B, **automatic silent retry of `thread/attachment/remove` after a timeout or transport error is unsafe**: if the initial request reached SQLite before the response was lost and another turn/tool/client subsequently re-attached the PR under the same `identityKey`, a blind retry would delete the new attachment. Any failure must refresh the bounded read projection and require an explicit fresh user action.
