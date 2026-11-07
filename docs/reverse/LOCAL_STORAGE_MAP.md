# ChatGPT Desktop (`26.1103.32239`) — Local Persistence & Native Storage Map

> **Scope**: Documents the complete on-disk persistence architecture of ChatGPT Desktop and `codex app-server` across `~/.codex/` and Chromium profile partitions, followed by the concrete storage design for the unified Native Flutter + Rust Host client.

---

## 1. Two-Tier On-Disk Storage Topology

ChatGPT Desktop splits local persistence into two distinct tiers under `~/.codex/` plus browser-partition storage under the OS config directory:

1. **Tier A — Stock `codex-rs` / `codex app-server` Storage (`~/.codex/*.sqlite` + `~/.codex/sessions/**/*.jsonl`)**:
   - Owned and mutated by the Rust `codex app-server` process (`0.167.0-alpha.3.2`).
   - Uses append-only JSONL rollout files as the durable source of truth for local agent turns, paired with a **byte-offset SQLite index** (`thread_history_1.sqlite`) for `O(1)` random-access turn/item pagination without loading entire JSONL files into RAM!
2. **Tier B — Desktop Main-Process Unified Catalog (`~/.codex/sqlite/codex.db` + `~/.codex/project-chatgpt-provisioning/`)**:
   - Owned and mutated by the Electron main process (`early-bootstrap-920` via `better-sqlite3`).
   - Unifies local `app-server` threads, SSH/WSL/Remote-Control threads, and Cloud ChatGPT (`/backend-api/conversations`) into a single indexed catalog (`local_thread_catalog`), alongside automations, inbox items, and timeline ledgers.
3. **Tier C — Owl / Chromium Partition Storage (`~/.config/codex-desktop/` / `persist:*`)**:
   - Stores persisted UI atom state (`persisted-atom-state` in `localStorage` / `.codex-global-state.json`), in-app browser cookies/sessions (`persist:codex-browser-app`), and OS-encrypted auth cookies.

---

## 2. Tier A: Stock `codex app-server` Databases & Rollouts (`~/.codex/`)

### 2.1 `state_5.sqlite` — Core Runtime Catalog, Projects, and Jobs

| Table | Primary Key | Key Columns & Purpose | Classification |
| :--- | :--- | :--- | :--- |
| `threads` | `id TEXT` | `rollout_path TEXT`, `created_at`, `updated_at`, `source TEXT`, `model_provider`, `cwd TEXT`, `title TEXT`, `sandbox_policy`, `approval_mode`, `tokens_used`, `git_sha`, `git_branch`, `git_origin_url`, `cli_version`, `first_user_message`, `agent_nickname`, `agent_role`, `memory_mode`, `model`, `reasoning_effort`, `agent_path`. Master index of local `app-server` threads. | `PUBLIC_SUPPORTED` (via RPC) |
| `thread_dynamic_tools` | `(thread_id, position)` | `name`, `description`, `input_schema`, `defer_loading`. Per-thread dynamic MCP/custom tool definitions. | `LOCAL_IMPLEMENTATION_DETAIL` |
| `projects` | `id TEXT` | `name TEXT`, `created_at`, `updated_at`, `deleted_at`. Local workspace project definitions. | `PUBLIC_SUPPORTED` |
| `project_roots` | `(project_id, root_path)` | Maps one or more filesystem directories (`root_path`) to a `project_id`. | `PUBLIC_SUPPORTED` |
| `thread_Filter_projects` / `project_threads` | `(project_id, thread_id)` | Explicit thread-to-project assignments. | `PUBLIC_SUPPORTED` |
| `agent_jobs` & `agent_job_items` | `id TEXT` | Batch/subagent job orchestration state and item progress. | `LOCAL_IMPLEMENTATION_DETAIL` |
| `backfill_state` | `id INTEGER` | Tracks background migration/indexing progress from `.jsonl` rollouts into SQLite. | `LOCAL_IMPLEMENTATION_DETAIL` |

### 2.2 `thread_history_1.sqlite` — Byte-Offset Rollout Index (Crucial Performance Mechanism!)

Instead of storing multi-megabyte turn JSON blobs inside SQLite or re-parsing whole `.jsonl` files on every scroll, `codex app-server` builds a **byte-offset index** over each thread's `.jsonl` rollout file:

```sql
CREATE TABLE rollout_files (
    thread_id TEXT PRIMARY KEY,
    rollout_path TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    mtime_ns INTEGER NOT NULL,
    indexed_at INTEGER NOT NULL
);

CREATE TABLE rollout_turns (
    thread_id TEXT NOT NULL,
    turn_seq INTEGER NOT NULL,
    turn_id TEXT NOT NULL,
    started_at INTEGER,
    completed_at INTEGER,
    status TEXT,
    start_byte_offset INTEGER NOT NULL,
    end_byte_offset INTEGER NOT NULL,
    PRIMARY KEY (thread_id, turn_seq)
);

CREATE TABLE rollout_items (
    thread_id TEXT NOT NULL,
    turn_seq INTEGER NOT NULL,
    item_seq INTEGER NOT NULL,
    item_id TEXT NOT NULL,
    item_type TEXT NOT NULL,
    byte_offset INTEGER NOT NULL,
    byte_len INTEGER NOT NULL,
    is_summary INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (thread_id, turn_seq, item_seq)
);
```

- **Why this matters for `Codex-Native-Unoffical`**:
  - When the UI calls `thread/turns/list` (`limit: 5, sortDirection: "desc"`) or `thread/items/list` (`limit: 2, sortDirection: "asc"` for the opening user message), `codex app-server` queries `rollout_turns` / `rollout_items` to get `(byte_offset, byte_len)` and performs a direct `pread()` slice on the `.jsonl` file!
  - This is why `thread/turns/list` and `thread/items/list` are `O(page_size)` rather than `O(history_length)`.

### 2.3 Other Tier A SQLite Databases in `~/.codex/`

| Database | Tables | Purpose |
| :--- | :--- | :--- |
| `queue_1.sqlite` | `queued_follow_ups` | Persists queued user follow-up prompts waiting for an active turn to finish. |
| `goals_1.sqlite` | `goals`, `goal_steps` | Autonomous long-running goal state. |
| `memories_1.sqlite` & `memories_v2_1.sqlite` | `stage1_outputs`, `memories`, `memory_embeddings` | Local workspace memory extraction and semantic retrieval. |
| `logs_2.sqlite` | `logs` (`ts`, `level`, `target`, `message`, `thread_id`, `file`, `line`) | Structured runtime diagnostics log with automatic retention pruning. |
| `reviews.sqlite` | `review_runs`, `review_comments`, `review_findings` | Local code-review findings and inline diff annotations. |

---

## 3. Tier B: Desktop Main-Process Databases (`~/.codex/sqlite/codex.db`)

### 3.1 `local_thread_catalog` & `local_thread_catalog_hosts` (Migration `0009` / `0010`)

`~/.codex/sqlite/codex.db` is the unified cross-mode catalog that powers the sidebar across **Chat**, **Work**, and **Codex**:

```sql
CREATE TABLE local_thread_catalog_hosts (
    host_id TEXT PRIMARY KEY,
    host_kind TEXT NOT NULL CHECK (
        host_kind IN ('local', 'ssh', 'wsl', 'remote-control', 'chatgpt')
    ),
    cursor_json TEXT,
    sync_exhausted INTEGER NOT NULL DEFAULT 0,
    last_synced_at INTEGER,
    updated_at INTEGER NOT NULL
);

CREATE TABLE local_thread_catalog (
    host_id TEXT NOT NULL,
    thread_id TEXT NOT NULL,
    host_kind TEXT NOT NULL CHECK (
        host_kind IN ('local', 'ssh', 'wsl', 'remote-control', 'chatgpt')
    ),
    source_kind TEXT NOT NULL CHECK (
        source_kind IN ('app-server', 'chatgpt')
    ),
    title TEXT,
    preview TEXT,
    cwd TEXT,
    project_id TEXT,
    git_branch TEXT,
    git_sha TEXT,
    git_origin_url TEXT,
    model TEXT,
    model_provider TEXT,
    status_type TEXT,
    archived INTEGER NOT NULL DEFAULT 0,
    pinned INTEGER NOT NULL DEFAULT 0,
    unread INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    last_activity_at INTEGER NOT NULL,
    conversation_origin TEXT,          -- 'chatgpt' | 'work' | 'tpp' | NULL
    trial_conversation_type TEXT,
    chatgpt_async_status TEXT,
    raw_summary_json TEXT NOT NULL,
    PRIMARY KEY (host_id, thread_id)
);

CREATE INDEX idx_local_thread_catalog_host_activity
    ON local_thread_catalog (host_id, archived, last_activity_at DESC, thread_id DESC);
CREATE INDEX idx_local_thread_catalog_project_activity
    ON local_thread_catalog (project_id, archived, last_activity_at DESC);
```

### 3.2 Additional Tables in `~/.codex/sqlite/codex.db`

| Table | Purpose |
| :--- | :--- |
| `thread_timeline_ledger` | Stores compressed turn/timeline checkpoints (`thread_id`, `sequence_id`, `payload_json`) for fast local timeline restoration. |
| `automations` & `automation_runs` | Scheduled recurring agent tasks (`rrule`, `prompt`, `cwd`, `status`, `next_run_at`, `last_run_at`). |
| `inbox_items` | Notification center items (`id`, `thread_id`, `kind`, `title`, `body`, `read_at`, `created_at`) for completed background tasks, approvals, and automation results. |

### 3.3 Unified Project Provisioning (`~/.codex/project-chatgpt-provisioning/<sha256>.json`)

When the `codex_unified_projects` gate is enabled, each local project's cloud ChatGPT backing (`g-p-...` gizmo) is persisted in `~/.codex/project-chatgpt-provisioning/<sha256(hostId + projectId)>.json`:

```json
{
  "version": 1,
  "hostId": "local",
  "localProjectId": "proj_...",
  "chatGptBacking": {
    "accountId": "acct_...",
    "userId": "user-...",
    "projectId": "g-p-..."
  },
  "updatedAtMs": 1762500000000
}
```

---

## 4. Concrete Native Storage Architecture for `Codex-Native-Unoffical`

To support a unified **Native Chat + Work + Codex** client across Desktop and Android without duplicating `codex app-server`'s storage or bloating Flutter memory, we recommend the following 5-layer local storage design:

### 4.1 What Belongs in Each Storage Layer

| Storage Layer | Technology | What Belongs Here | Retention & Bounding Policy |
| :--- | :--- | :--- | :--- |
| **1. Unified Client Catalog DB** | SQLite (`codex_native_catalog.sqlite`, WAL mode) in `codex-native-host` (Desktop) & Flutter `sqlite3` (Android) | - `unified_threads`: Composite `(host_id, thread_id)` across `local`, `remote-host`, and `chatgpt` (`conversation_origin`: `chat`, `work`, `codex`)<br/>- `unified_projects`: Local roots + optional `chatgpt_gizmo_id`<br/>- `host_sync_state`: Pagination cursors & `last_synced_at`<br/>- `chat_message_nodes`: Cached DAG metadata (`node_id`, `parent_id`, `children_json`, `role`, `created_at`, `body_preview`, `blob_ref`) for Cloud Chat conversations<br/>- `inbox_notifications` & `drafts` | Indexed by `(host_id, archived, last_activity_at DESC)`. Cloud `chatgpt` catalog rows bounded to 30 days (`maxHistoryAgeMs = 30d`) + pinned/active threads, matching official `ThreadCatalogSyncManager`. |
| **2. Full-Text Search Index** | SQLite `FTS5` virtual table (`unified_search_fts`) | - Tokenized thread titles, project names, user prompts, and assistant final message summaries (`content=""` external content table or prefix-indexed). | Bounded to indexed text summaries; never indexes multi-megabyte command stdout or raw unified diffs. |
| **3. Filesystem Blobs & Rollout Spool** | Content-addressed / range-indexed files under `<app_cache>/spool/` & stock `~/.codex/sessions/**/*.jsonl` | - **Codex turns**: Stay in stock `~/.codex/sessions/**/*.jsonl` indexed by `thread_history_1.sqlite` (zero duplication!).<br/>- **Large Command Output & Diffs**: Bounded spool files in `codex-native-host` served via `host/output/readRange`.<br/>- **Cloud Chat long message bodies & attachments**: Stored as compressed/range-readable files under `<app_cache>/chat_blobs/<sha256>` when `> 16 KiB`. | LRU disk quota (e.g., `512 MiB` for command spool + `1 GiB` for downloaded attachments/images) with automatic startup/background pruning. |
| **4. Secure Credential Store** | OS Keychain (`libsecret` on Linux, Keychain on macOS/iOS, Credential Manager on Windows, `EncryptedSharedPreferences` / Keystore on Android) | - OpenAI API keys / ChatGPT OAuth refresh & access tokens<br/>- Remote Host pairing Ed25519/X25519 keys & session tokens<br/>- Device-key proofs | Never written to plain SQLite, JSON state files, or logs. |
| **5. Ephemeral UI State & Cache** | In-memory bounded projections + lightweight JSON preferences (`settings.json`) | - Sidebar width (`sidebar-width`), active `sidebarProductMode` (`work` vs `codex`), `conversationDetailMode` (`STEPS_PROSE` vs `STEPS_COMMANDS`), theme preset, 10-thread LRU in-memory transcript cache. | Strictly bounded: max 10 inactive threads in memory; active thread island capped at `1,000 -> 500` items via viewport-protected eviction. |
