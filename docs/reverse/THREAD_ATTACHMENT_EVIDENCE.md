# Persistent Thread Attachments (`thread/attachment/*`) — Static & Live Evidence Packet

**Date:** 2026-11-10  
**Target Baseline:** `f70a21016325f6615da50755a1e38d1a2bd9e896`  
**Inspected Stock Runtime:** `codex-cli 0.167.0-alpha.3.2` (`/opt/codex-desktop/resources/codex`)  
**Inspected Official Desktop Bundle:** Linux-packaged ChatGPT / Codex Desktop `26.1103.60933` (build `25894`, `/opt/codex-desktop/resources/app.asar`, SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`)  
**Evidence Grade:** `PUBLIC_SOURCE` (generated JSON schema), `STATIC_BUNDLE` (ASAR + binary SQL/error strings), `LIVE_CALLED` (disposable `CODEX_HOME` stock `codex app-server` probes)

---

## 1. Executive Summary

`thread/attachment/add`, `thread/attachment/list`, `thread/attachment/remove`, `thread/attachmentOwner/list`, and the `thread/attachment/updated` notification are **stable (`PUBLIC_SUPPORTED`)** in `codex-cli 0.167.0-alpha.3.2`, but **they are not user-authored composer file, image, or prompt attachments**:

1. ** Composer inputs vs. Thread attachments:**
   - Per-turn prompt attachments (files, images, local images, skills, mentions, audio) use the `UserInput` union in `turn/start` and `turn/steer` (already implemented in Native Slice F2).
   - The `thread_attachments` SQLite table in `state_5.sqlite` was renamed directly from `thread_artifacts` (`ALTER TABLE thread_artifacts RENAME TO thread_attachments; ALTER TABLE thread_attachments RENAME COLUMN artifact_type TO attachment_type;`).
   - `codex app-server` treats `thread_attachments` as an opaque, bounded per-thread JSON key-value store keyed by `(thread_id, attachment_type, identity_key)`. It **never** injects `thread_attachments` into model prompts during `turn/start`, and it **never** embeds them in `Thread` objects returned by `thread/list` or `thread/read`.
2. **Official Desktop (`26.1103.60933`) usage:**
   - Official Desktop (`WiNP`, `TkUj`, `Ygco`, `n2eO`, `rUmy`, `$f`, `$y`) uses `thread/attachment/*` exclusively to persist and query **three task-level artifact types**:
     - `"worktree"` — active Desktop-managed Git worktree checkout metadata (`root`, `workspaceRoot`, `sourceCwd`, optional `hostId`, `environmentId`, `operationId`).
     - `"archived_worktree"` — recovery metadata + associated PR snapshots saved when detaching/archiving a managed worktree.
     - `"pull_request"` — linked GitHub/GitLab Pull Request metadata (`url`, `root`, `headBranch`), mutated either by the local Git/PR UI (`Ygco`) or by client-handled `codex_app` dynamic tools (`attach_artifact`, `list_artifacts`, `remove_artifact`).
   - `thread/attachmentOwner/list` is used by Desktop's worktree cleanup and `WorktreesSettingsPage` (`YQVA`) as a reverse index to check whether any non-archived thread still owns a given worktree root before deleting the checkout on disk.

---

## 2. Stock Protocol Contract (`0.167.0-alpha.3.2` Stable Schema)

All four `ClientRequest` methods and one `ServerNotification` are present in the non-experimental (`codex app-server generate-json-schema`) v2 schema:

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

---

## 3. Static Evidence from `codex` Binary & Desktop ASAR `26.1103.60933`

### 3.1 Stock `codex` SQLite Schema & Source Modules

Inspection of `/opt/codex-desktop/resources/codex` (`0.167.0-alpha.3.2`) locates the implementation across:
- `app-server/src/request_processors/thread_attachments.rs`
- `thread-store/src/local/thread_attachments.rs`
- `state/src/runtime/thread_attachments.rs`

The underlying SQLite migration in `state_5.sqlite` establishes both the origin and constraints of the table:

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

### 3.2 Official Desktop ASAR (`26.1103.60933`) Call Sites & Zod Schemas

Every occurrence of `thread/attachment/*` and `WiNP` / `TkUj` in `/opt/codex-desktop/resources/app.asar` maps to worktree and PR artifact tracking:

1. **Transport adapter (`TkUj` @ offset `111034326`)**:
   - For local hosts, wraps `sendRequest("thread/attachment/list")`, `sendRequest("thread/attachment/add")`, and `sendRequest("thread/attachment/remove")`.
   - For cloud hosts, delegates to `appServices.cloudThreadAttachments` (`addThreadAttachment`, `listThreadAttachments`, `removeThreadAttachment` unary RPCs where `payload` is serialized as `payloadJson`).
2. **Renderer query & payload parsers (`WiNP` @ offset `111034460`)**:
   - Pages through `thread/attachment/list` with `limit: 100` until `nextCursor == null`.
   - Parses **only** two `attachmentType` values for thread UI state:
     - `attachmentType === "worktree"`: parsed via `C = z.object({ root: z.string().min(1), workspaceRoot: z.string().min(1), environmentId: z.string().min(1).optional() })`, computing `latestWorktree` (highest `createdAt`) to override the thread's default terminal/file cwd (`JM0a`, `eU`, `aqTO`).
     - `attachmentType === "pull_request"`: parsed via `T = z.object({ url: z.string(), root: z.string().nullable().optional(), headBranch: z.string().nullable().optional() })`, validated as a GitHub/GitLab PR URL (`m.g0(url)`).
   - Subscribes to `thread/attachment/updated` (`offset 110971195`):
     ```js
     if ("pull_request" !== r.attachmentType && "worktree" !== r.attachmentType) return;
     ```
     Invalidates the per-thread `WiNP.Nt` query and, when `attachmentType === "worktree"`, invalidates `["settings-worktree-conversations", hostId]`.
3. **Client-side dynamic tools (`n2eO` @ offset `110494200`, `rUmy` @ offset `317457355`)**:
   - Exposes `attach_artifact`, `list_artifacts`, and `remove_artifact` inside the `codex_app` dynamic tool namespace.
   - `attach_artifact` and `remove_artifact` accept `z.strictObject({ artifact_type: z.enum(["pull_request"]), url: z.string().min(1) })` and call `Ygco.op` (`thread/attachment/add` with `attachmentType: "pull_request"`) and `Ygco.Z$` (`thread/attachment/remove`).
   - `list_artifacts` returns `{ artifacts: [...] }` combining the thread's attachments and any parent owner thread's `"worktree"` / `"archived_worktree"` attachments.
4. **Worktree ownership reverse lookup (`hasOtherAttachmentOwner` @ offset `10620617`, `WorktreesSettingsPage` `YQVA` @ offset `486998000`)**:
   - Calls `thread/attachmentOwner/list` with `{ attachmentType: "worktree", identityKey: worktreeRoot, archived: false, cursor, limit: 100 }` to determine which active threads reference each managed worktree.

---

## 4. Disposable Live Stock `codex app-server` Probes (`LIVE_CALLED`)

Four isolated Python probes were executed against stock `codex app-server` (`0.167.0-alpha.3.2`) using disposable `CODEX_HOME` and `XDG_*` directories (cleaned up immediately after execution).

### 4.1 Materialization Gate (`threads` Foreign Key)

| Thread State | `thread/attachment/list` | `thread/attachment/add` | `thread/attachment/remove` |
|---|---|---|---|
| Fresh `thread/start` (no SQLite row in `threads` yet) | Returns `{"data": [], "nextCursor": null}` | Fails `-32602`: `"thread not found: <threadId>"` | Fails `-32602`: `"thread not found: <threadId>"` |
| Materialized in `state_5.sqlite` (e.g., after `thread/name/set` or `thread/goal/set`) | Returns persisted rows + `nextCursor` | Succeeds (`outcome: "created"` or `"existing"`) | Succeeds (`{}`) |

- **Side effect on `thread/list`**: Materializing a thread via `thread/goal/set` (or `thread/name/set`) inserts its row into `threads` in `state_5.sqlite` and creates a rollout file path, making the thread visible in `thread/list` even before the first user turn.

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
   - **Implication**: `thread/attachment/add` is a create-or-get operation, **not** an upsert. Updating `payload` for an existing `(attachmentType, identityKey)` requires `thread/attachment/remove` followed by `thread/attachment/add`.
3. **`thread/attachment/remove` idempotency**:
   - Removing an existing `(threadId, attachmentType, identityKey)` returns `{}` and emits `thread/attachment/updated` with `"operation": "deleted"` and the deleted `"attachmentId"`.
   - Removing an already-removed or non-existent `(threadId, attachmentType, identityKey)` on an existing thread returns `{}` and emits **no** notification.

### 4.3 Hard Bounds & Validation Errors (`LIVE_CALLED`)

| Check | Input | Observed Stock Result |
|---|---|---|
| Empty / whitespace `attachmentType` | `""` or `"   "` | Error `-32602`: `"attachmentType must not be empty"` |
| Empty `identityKey` | `""` | Error `-32602`: `"identityKey must not be empty"` |
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

---

## 5. Architecture & Backlog Classification Decision

1. **Do not conflate with Composer attachments**:
   - Native composer attachments (`UserAttachment` -> `UserInput` in `turn/start` & `turn/steer`) are already implemented in Slice F2 and match official per-turn user attachments. `thread/attachment/*` must **not** be wired as a composer file-upload store.
2. **Managed worktrees (`attachmentType: "worktree" | "archived_worktree"`) remain out of scope**:
   - Official Desktop uses `worktree` attachments to track checkouts created by its internal Electron Git worker (`create-worktree`) and cloud executor (`cloudWorktrees`). Native intentionally does not implement a managed Git worktree manager (`docs/RESEARCH.md` "Deliberate non-adoptions").
3. **Reclassification of Matrix §3.6 `Persistent thread attachments` row**:
   - The protocol contract, SQLite origin (`thread_artifacts`), `64 KiB` / `100`-item bounds, materialization requirement, fork-copy behavior, and official Desktop UX (`pull_request` + `worktree` artifacts) are now completely established (`PUBLIC_SOURCE`, `STATIC_BUNDLE`, `LIVE_CALLED`).
   - Reclassify the `RESEARCH_MORE` row in `docs/reverse/OFFICIAL_FEATURE_MATRIX.md` §3.6:
     - Either **`RESEARCH_EXHAUSTED` (`DEFERRED_WORKTREE_PR_ARTIFACT_STORE`)** while managed worktrees and PR artifact dynamic tools remain outside the core Native workflow; or
     - Scope a small, bounded **Thread Linked PRs / Artifacts (`thread/attachment/list|add|remove`)** slice in `READY` if user-visible PR link / worktree badge inspection on materialized local threads is desired after the current `Scoped Section ordering and pagination` slice.
