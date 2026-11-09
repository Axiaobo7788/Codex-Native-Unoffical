# Persistent Thread Attachments (`thread/attachment/*`) — Static & Live Evidence Packet

- **Date:** 2026-11-10
- **Target Baseline:** `f70a21016325f6615da50755a1e38d1a2bd9e896`
- **Inspected Stock Runtime:** `codex-cli 0.167.0-alpha.3.2` (`/opt/codex-desktop/resources/codex`)
- **Inspected Official Desktop Bundle:** Linux-packaged ChatGPT / Codex Desktop `26.1103.60933` (build `25894`, `/opt/codex-desktop/resources/app.asar`, SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`)
- **Evidence Grade:** `PUBLIC_DOC` / `PUBLIC_SOURCE` (upstream `app-server` README `#stored-thread-attachments` + generated JSON schema), `STATIC_BUNDLE` (ASAR + binary SQL/error strings), `LIVE_CALLED` (disposable `CODEX_HOME` stock `codex app-server` probes)

---

## 1. Executive Summary

`thread/attachment/add`, `thread/attachment/list`, `thread/attachment/remove`, `thread/attachmentOwner/list`, and the `thread/attachment/updated` notification are **stable (`PUBLIC_SUPPORTED`)** in `codex-cli 0.167.0-alpha.3.2`. Based on the upstream `app-server` README (`#stored-thread-attachments`), generated v2 schemas, static ASAR/binary inspection, and disposable runtime probes, they form a persisted thread-metadata/artifact store rather than per-turn composer prompt inputs:

1. **Composer prompt inputs vs. Stored thread attachments:**
   - Per-turn prompt inputs use the `UserInput` union in `turn/start` and `turn/steer` (stock schema variants: `text`, `image`, `localImage`, `skill`, `mention`, `localAudio`; Native Slice F2 currently encodes and renders `text`, `image`/`localImage`, `skill`, and `mention`, with local file paths attached via `mention`).
   - In `state_5.sqlite`, `thread_attachments` was renamed by migration from `thread_artifacts` (`ALTER TABLE thread_artifacts RENAME TO thread_attachments; ALTER TABLE thread_attachments RENAME COLUMN artifact_type TO attachment_type;`).
   - Per the upstream `app-server` README (`#stored-thread-attachments`) and observed `0.167.0-alpha.3.2` behavior, `thread_attachments` is a non-loading, paginated SQLite metadata store keyed by `(thread_id, attachment_type, identity_key)`. Reading or mutating stored attachments does not load the thread into active memory, and `thread/list` / `thread/read` `Thread` payloads do not include `thread_attachments` rows. No prompt-injection path from `thread_attachments` into `turn/start` was observed in the inspected `codex` binary; in the audited Desktop ASAR, the model accesses stored thread attachments through client-handled dynamic tools (`list_artifacts`, `attach_artifact`, `remove_artifact`).
2. **Audited Official Desktop (`26.1103.60933`) call sites:**
   - In the audited Desktop bundle (`WiNP`, `TkUj`, `Ygco`, `n2eO`, `rUmy`, `$f`, `$y`, `YQVA`), the observed `thread/attachment/*` call sites read and write three task-level artifact types:
     - `"worktree"` — active Desktop-managed Git worktree checkout metadata (`root`, `workspaceRoot`, `sourceCwd`, optional `hostId`, `environmentId`, `operationId`).
     - `"archived_worktree"` — recovery metadata and associated PR snapshots saved when detaching or archiving a managed worktree.
     - `"pull_request"` — linked GitHub/GitLab Pull Request metadata (`url`, `root`, `headBranch`), mutated by the local Git/PR UI (`Ygco`) or client-handled `codex_app` dynamic tools (`attach_artifact`, `list_artifacts`, `remove_artifact`).
   - `thread/attachmentOwner/list` is used by Desktop's worktree archive cleanup (`hasOtherAttachmentOwner`) and `WorktreesSettingsPage` (`YQVA`) as a reverse lookup to check whether any non-archived thread still owns a given worktree root.

---

## 2. Stock Protocol Contract (`0.167.0-alpha.3.2` Stable Schema & Upstream README)

All four `ClientRequest` methods and one `ServerNotification` are present in the non-experimental (`codex app-server generate-json-schema`) v2 schema and documented in the upstream `app-server` README (`#stored-thread-attachments`):

| Method / Notification | Direction | Request / Notification Params | Response Shape |
|---|---|---|---|
| `thread/attachment/add` | `ClientRequest` | `{ threadId: string, attachmentType: string, identityKey: string, payload: any }` | `{ attachment: ThreadAttachment, outcome: "created" \| "existing" }` |
| `thread/attachment/list` | `ClientRequest` | `{ threadId: string, cursor?: string \| null, limit?: uint32 \| null }` | `{ data: ThreadAttachment[], nextCursor?: string \| null }` |
| `thread/attachment/remove` | `ClientRequest` | `{ threadId: string, attachmentType: string, identityKey: string }` | `{}` |
| `thread/attachmentOwner/list` | `ClientRequest` | `{ attachmentType: string, identityKey: string, archived?: boolean \| null, cursor?: string \| null, limit?: uint32 \| null }` | `{ data: ThreadAttachmentOwner[], nextCursor?: string \| null }` |
| `thread/attachment/updated` | `ServerNotification` | `{ threadId: string, attachmentId: string, attachmentType: string, identityKey: string, operation: "created" \| "deleted" }` | — |

Where:
- `ThreadAttachment`:
  ```json
  {
    "id": "01a1c13d-22ea-7be3-b7ad-573eaaadbb3e",
    "attachmentType": "worktree",
    "identityKey": "/tmp/wt-1",
    "payload": { "root": "/tmp/wt-1", "workspaceRoot": "/tmp/wt-1", "sourceCwd": "/tmp/ws" },
    "createdAt": 1794243371
  }
  ```
- `ThreadAttachmentOwner`:
  ```json
  {
    "threadId": "01a1c13d-223a-7d53-93ea-3ec854b24854",
    "archived": false
  }
  ```
- **Documented canonical `pull_request` identity (`#stored-thread-attachments` + ASAR `Ygco`)**:
  - Upstream `app-server` README `#stored-thread-attachments` documents that `pull_request` attachments use the canonical 4-tuple JSON array string as `identityKey`:
    ```js
    JSON.stringify([canonicalHostname, lowercaseOwner, lowercaseRepository, pullRequestNumber])
    ```
    with `payload` carrying `{ url, root?, headBranch? }`.
  - In ASAR `Ygco` (`offset 115749800`), `(0, l.Tx)(pullRequest, url)` produces this canonical identity key and falls back to normalized URL comparison for legacy entries.

---

## 3. Static Evidence from `codex` Binary & Desktop ASAR `26.1103.60933`

### 3.1 Stock `codex` SQLite Schema & Source Modules

Inspection of `/opt/codex-desktop/resources/codex` (`0.167.0-alpha.3.2`) locates the implementation across:
- `app-server/src/request_processors/thread_attachments.rs`
- `thread-store/src/local/thread_attachments.rs`
- `state/src/runtime/thread_attachments.rs`

The underlying SQLite migration in `state_5.sqlite` establishes the table schema and uniqueness constraint:

```sql
CREATE TABLE thread_artifacts (
    id TEXT PRIMARY KEY,
    thread_id TEXT NOT NULL REFERENCES threads(id) ON DELETE CASCADE,
    artifact_type TEXT NOT NULL,
    identity_key TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    UNIQUE (thread_id, artifact_type, identity_key)
);

ALTER TABLE thread_artifacts RENAME TO thread_attachments;
ALTER TABLE thread_attachments RENAME COLUMN artifact_type TO attachment_type;

CREATE INDEX idx_thread_attachments_thread_created_id
    ON thread_attachments(thread_id, created_at, id);

CREATE INDEX idx_thread_attachments_identity_thread
    ON thread_attachments(attachment_type, identity_key, thread_id);
```

### 3.2 Audited Official Desktop ASAR (`26.1103.60933`) Call Sites & Parsers

The inspected `thread/attachment/*` and `WiNP` / `TkUj` call sites in `/opt/codex-desktop/resources/app.asar` cover:

1. **Transport adapter (`TkUj` @ offset `111034326`)**:
   - For local hosts, wraps `sendRequest("thread/attachment/list")`, `sendRequest("thread/attachment/add")`, and `sendRequest("thread/attachment/remove")`.
   - For cloud hosts, delegates to `appServices.cloudThreadAttachments` (`addThreadAttachment`, `listThreadAttachments`, `removeThreadAttachment` unary RPCs where `payload` is serialized as `payloadJson`).
2. **Renderer query & payload parsers (`WiNP` @ offset `111034460`)**:
   - Pages through `thread/attachment/list` with `limit: 100` until `nextCursor == null`.
   - Parses two `attachmentType` values into thread query state:
     - `attachmentType === "worktree"`: parsed via `C = z.object({ root: z.string().min(1), workspaceRoot: z.string().min(1), environmentId: z.string().min(1).optional() })`, computing `latestWorktree` (highest `createdAt`) to select the thread's active worktree directory (`JM0a`, `eU`, `aqTO`).
     - `attachmentType === "pull_request"`: parsed via `T = z.object({ url: z.string(), root: z.string().nullable().optional(), headBranch: z.string().nullable().optional() })`, validated as a GitHub/GitLab PR URL (`m.g0(url)`).
   - Subscribes to `thread/attachment/updated` (`offset 110971195`):
     ```js
     if ("pull_request" !== r.attachmentType && "worktree" !== r.attachmentType) return;
     ```
     Invalidates the per-thread `WiNP.Nt` query and, when `attachmentType === "worktree"`, invalidates `["settings-worktree-conversations", hostId]`.
3. **Client-side dynamic tools (`n2eO` @ offset `110494200`, `rUmy` @ offset `317457355`)**:
   - Exposes `attach_artifact`, `list_artifacts`, and `remove_artifact` inside the `codex_app` dynamic tool namespace.
   - `attach_artifact` and `remove_artifact` accept `z.strictObject({ artifact_type: z.enum(["pull_request"]), url: z.string().min(1) })` and call `Ygco.op` (`thread/attachment/add` with `attachmentType: "pull_request"`) and `Ygco.Z$` (`thread/attachment/remove`).
   - `list_artifacts` returns `{ artifacts: [...] }` combining the thread's stored attachments and any parent owner thread's `"worktree"` / `"archived_worktree"` attachments.
4. **Worktree ownership reverse lookup (`hasOtherAttachmentOwner` @ offset `10620617`, `WorktreesSettingsPage` `YQVA` @ offset `486998000`)**:
   - Calls `thread/attachmentOwner/list` with `{ attachmentType: "worktree", identityKey: worktreeRoot, archived: false, cursor, limit: 100 }` to determine which active threads reference each managed worktree.

---

## 4. Disposable Live Stock `codex app-server` Probes (`LIVE_CALLED`)

Four isolated Python probes were executed against stock `codex app-server` (`0.167.0-alpha.3.2`) using disposable `CODEX_HOME` and `XDG_*` directories (cleaned up immediately after execution).

### 4.1 Attachment-Store Eligibility vs. `thread/list` Visibility

| Thread State | `thread/attachment/list` | `thread/attachment/add` | `thread/attachment/remove` |
|---|---|---|---|
| Fresh `thread/start` (before a `threads` row exists in `state_5.sqlite`) | Returns `{"data": [], "nextCursor": null}` | Fails `-32602`: `"thread not found: <threadId>"` | Fails `-32602`: `"thread not found: <threadId>"` |
| Persisted in `state_5.sqlite` `threads` (e.g., after `thread/name/set` or `thread/goal/set`) | Returns persisted rows + `nextCursor` | Succeeds (`outcome: "created"` or `"existing"`) | Succeeds (`{}`) |

- **Attachment eligibility vs. global `thread/list` visibility**:
  - `thread/name/set` and `thread/goal/set` both satisfy the `threads(id)` foreign-key prerequisite required by `thread/attachment/add` and `thread/attachment/remove` (and `thread/attachmentOwner/list` returns both threads because its SQL joins `thread_attachments` with `threads`).
  - However, global `thread/list` visibility remains conditional on what materialized the thread: in the same probe (`tid_a` with `thread/name/set` only vs. `tid_b` with `thread/goal/set`), `thread/list` (both default and `useStateDbOnly: true`) returned only `tid_b` and omitted `tid_a` (though `tid_a` could be read via `thread/read` or listed under an explicit section scope after `thread/section/move`).

### 4.2 Idempotency, Immutability & Notification Semantics

1. **First `thread/attachment/add` for `(threadId, attachmentType, identityKey)`**:
   - Returns:
     ```json
     {
       "outcome": "created",
       "attachment": {
         "id": "01a1c13d-22ea-7be3-b7ad-573eaaadbb3e",
         "attachmentType": "worktree",
         "identityKey": "/tmp/wt-1",
         "payload": { "root": "/tmp/wt-1", "workspaceRoot": "/tmp/wt-1", "sourceCwd": "..." },
         "createdAt": 1794243371
       }
     }
     ```
   - Emits `thread/attachment/updated` notification:
     ```json
     {
       "method": "thread/attachment/updated",
       "params": {
         "threadId": "01a1c13d-223a-7d53-93ea-3ec854b24854",
         "attachmentType": "worktree",
         "identityKey": "/tmp/wt-1",
         "attachmentId": "01a1c13d-22ea-7be3-b7ad-573eaaadbb3e",
         "operation": "created"
       }
     }
     ```
2. **Duplicate `thread/attachment/add` with the same `(threadId, attachmentType, identityKey)` (same OR different `payload`)**:
   - Returns `"outcome": "existing"` and the **original unmodified `attachment` (including the original `payload` and `id`)**.
   - Emits **no** `thread/attachment/updated` notification.
   - **Implication**: `thread/attachment/add` is a create-or-get operation, **not** an upsert. Replacing `payload` for an existing `(attachmentType, identityKey)` requires `thread/attachment/remove` followed by `thread/attachment/add`.
3. **`thread/attachment/remove` idempotency**:
   - Removing an existing `(threadId, attachmentType, identityKey)` returns `{}` and emits `thread/attachment/updated` with `"operation": "deleted"` and the deleted `"attachmentId"`.
   - Removing an already-removed or non-existent `(threadId, attachmentType, identityKey)` on an eligible thread returns `{}` and emits **no** notification.

### 4.3 Hard Bounds & Validation Errors (`LIVE_CALLED`)

| Check | Input | Observed Stock Result |
|---|---|---|
| Empty / whitespace `attachmentType` | `""` or `"   "` | Error `-32602`: `"attachmentType must not be empty"` |
| Empty `identityKey` | `""` | Error `-32602`: `"identityKey must not be empty"` |
| Max `identityKey` UTF-8 bytes | 256 ASCII bytes or 128 two-byte characters | Succeeds. 257 bytes in either fixture fails with `identityKey must not exceed 256 bytes`. Confirmed in the F19 installed-stock probe. |
| Max `payload` serialized JSON bytes | `65,536` bytes (`64 KiB`) | Succeeds (`"outcome": "created"`) |
| Oversized `payload` serialized JSON bytes | `65,537` bytes (`64 KiB + 1`) | Error `-32602`: `"attachment payload must not exceed 65536 bytes"` |
| Max attachments per thread | `100` distinct `(attachmentType, identityKey)` rows | `1..100` succeed; `101`st fails `-32602`: `"thread attachment identity count exceeds 100"` |
| `thread/attachment/list` default `limit` | `limit` omitted / `null` (with 100 rows) | Returns `25` rows + `nextCursor: "<threadId>|<createdAt>|<id>"` |
| `thread/attachment/list` `limit` clamping | `limit: 0`, `limit: 100`, `limit: 101`, `limit: 500` (with 100 rows) | Clamped to `[1, 100]`: `limit: 0` returns `1` row; `limit >= 100` returns all `100` rows (`nextCursor: null`) |
| Invalid `cursor` | `cursor: "not-a-cursor"` | Error `-32602`: `"invalid pagination cursor"` |

### 4.4 Lifecycle Interactions (`fork`, `archive`, `delete`, restart)

- **`thread/fork`**: Calling `thread/fork` on a thread with persisted attachments **copies all `thread_attachments` rows** to the newly created fork thread with fresh attachment UUIDs (`copy_thread_attachments`). Both the parent and forked thread subsequently appear in `thread/attachmentOwner/list`.
- **`thread/archive` & `thread/attachmentOwner/list(archived)`**:
  - `archived: false` returns only non-archived owner threads (`archived: false`).
  - `archived: true` returns only archived owner threads (`archived: true`).
  - `archived: null` (or omitted) returns all owner threads regardless of archive status.
- **`thread/delete`**: Cascades (`ON DELETE CASCADE`) to remove all `thread_attachments` rows owned by the deleted thread while preserving copies on any forked threads.
- **Process restart**: Stopping and restarting `codex app-server` against the same `CODEX_HOME` preserves all `thread_attachments` rows and owner index entries in `state_5.sqlite`.
