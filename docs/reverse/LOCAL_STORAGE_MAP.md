# ChatGPT Desktop Local Storage & SQLite Schema Map (Recalibrated)

> **Evidence Sources**:
> - `LOCAL_SCHEMA`: Read-only (`file:...?mode=ro`) DDL inspection of `~/.codex/*.sqlite` and `~/.codex/sqlite/*.db` via `python3 tools/reverse/inspect_chatgpt_desktop.py --sqlite-schemas`. Zero user row data was read or exported.
> - `STATIC_BUNDLE`: `.vite/build/early-bootstrap-920-a204a41244c4b913.js` (`@708500..734500`, `@3831000..3848000`) SQL queries and `better-sqlite3` migration logic.
> - `PUBLIC_SOURCE`: Stock `codex-cli 0.167.0-alpha.3.2` (`codex-rs/state`) SQLite state store implementation.

---

## 0. Storage Ownership & Evidence Matrix

| Database / File Path | Owner Process | Evidence Tags | Support Classification | Rule for `Codex-Native-Unoffical` |
|---|---|---|---|---|
| `~/.codex/state_5.sqlite` | Stock Rust `codex app-server` | `LOCAL_SCHEMA`, `PUBLIC_SOURCE` | `PUBLIC_SUPPORTED` **only via `app-server` JSON-RPC** (never direct SQL) | **NEVER read/write directly from Flutter.** Always query via `thread/list`, `thread/turns/list`, `thread/items/list`, `thread/items/read` |
| `~/.codex/logs_2.sqlite` | Stock Rust `codex app-server` | `LOCAL_SCHEMA`, `PUBLIC_SOURCE` | Internal `codex-rs` tracing store | **DO NOT couple.** Do not read or mutate |
| `~/.codex/sqlite/local_thread_catalog.sqlite` | ChatGPT Desktop Electron Main Process (`better-sqlite3`) | `LOCAL_SCHEMA`, `STATIC_BUNDLE` | Internal Desktop cache (`DO_NOT_SHARE_FILE`) | **NEVER share or mutate ChatGPT Desktop's `local_thread_catalog.sqlite`.** If we build a local catalog index later, use a separate client-owned file (`codex_native_catalog.sqlite`) (`ADAPT_NATIVE`) |
| `~/.codex/sqlite/codex_dev.db` | ChatGPT Desktop Electron Main Process (`better-sqlite3`) | `LOCAL_SCHEMA`, `STATIC_BUNDLE` | Internal Desktop automations & inbox store | **DO NOT share or mutate.** |
| `~/.codex/config.toml` & `~/.codex/auth.json` | Stock `codex` CLI / `app-server` | `PUBLIC_DOC`, `PUBLIC_SOURCE` | `PUBLIC_SUPPORTED` via `config/*` and `account/*` RPCs | Manage via `config/read`, `config/value/write`, `config/batchWrite`, and `account/*` RPCs |

---

## 1. `~/.codex/state_5.sqlite` (Owned by Stock `codex app-server`)

### 1.1 Tables & Schema (`LOCAL_SCHEMA`, `PUBLIC_SOURCE`)
1. **`threads`** (Primary thread metadata & rollout pointer):
   ```sql
   CREATE TABLE threads (
       id TEXT PRIMARY KEY,
       rollout_path TEXT NOT NULL,
       created_at INTEGER NOT NULL,
       updated_at INTEGER NOT NULL,
       source TEXT NOT NULL,
       model_provider TEXT NOT NULL,
       cwd TEXT NOT NULL,
       title TEXT NOT NULL,
       sandbox_policy TEXT NOT NULL,
       approval_mode TEXT NOT NULL,
       tokens_used INTEGER NOT NULL DEFAULT 0,
       has_user_event INTEGER NOT NULL DEFAULT 0,
       archived INTEGER NOT NULL DEFAULT 0,
       archived_at INTEGER,
       git_sha TEXT,
       git_branch TEXT,
       git_origin_url TEXT,
       cli_version TEXT NOT NULL DEFAULT '',
       first_user_message TEXT NOT NULL DEFAULT '',
       agent_nickname TEXT,
       agent_role TEXT,
       memory_mode TEXT NOT NULL DEFAULT 'enabled',
       model TEXT,
       reasoning_effort TEXT,
       agent_path TEXT
   );
   ```
   - Indexed by `(archived, updated_at DESC, id DESC)`, `(cwd)`, `(created_at DESC, id DESC)`, `(source)`, `(model_provider)`, and `UNIQUE (agent_path)`.
   - Note that full turn/item payloads live in the JSONL rollout files referenced by `rollout_path`, while `state_5.sqlite` indexes metadata for fast `thread/list` queries.
2. **`thread_dynamic_tools`**:
   - Stores per-thread dynamic tool definitions (`thread_id`, `position`, `name`, `description`, `input_schema`).
3. **`stage1_outputs`**:
   - Stores phase-1 memory extraction outputs (`thread_id`, `source_updated_at`, `raw_memory`, `rollout_summary`, `rollout_slug`, `generated_at`, `selected_for_phase2`).
4. **`agent_jobs`** & **`agent_job_items`**:
   - Batch/multi-agent job queues and CSV-like item status tracking (`pending | running | completed | failed`).
5. **`_sqlx_migrations`**:
   - Tracks Rust `sqlx` schema version (`state_5`).

---

## 2. `~/.codex/sqlite/local_thread_catalog.sqlite` (Owned by ChatGPT Desktop Main Process)

### 2.1 Why ChatGPT Desktop Has a Separate Catalog SQLite (`STATIC_BUNDLE` `@708500..734500`, `@3831000..3848000`)
Because ChatGPT Desktop unifies **multiple hosts and product modes** in a single sidebar—Local `app-server` (`host_id = "local"`), SSH remote `app-server` (`host_id = "ssh:..."`), Durable Cloud Host (`host_id = "durable"`), and ChatGPT Cloud Conversations (`source_kind = "chatgpt"`, both `conversation_origin = 'tpp'` for Work and `conversation_origin IS NOT 'tpp'` for Chat)—it maintains an Electron-owned SQLite catalog (`local_thread_catalog.sqlite`) synchronized incrementally via watermarks.

### 2.2 Exact Schema (`LOCAL_SCHEMA` + `STATIC_BUNDLE` `@709257`)
```sql
CREATE TABLE local_thread_catalog (
    host_id TEXT NOT NULL,
    thread_id TEXT NOT NULL,
    display_title TEXT NOT NULL,
    archived INTEGER NOT NULL,
    source_created_at INTEGER NOT NULL,
    source_updated_at INTEGER NOT NULL,
    source_recency_at INTEGER NOT NULL,
    cwd TEXT NOT NULL,
    source_kind TEXT NOT NULL,
    source_detail TEXT,
    thread_source TEXT,
    model_provider TEXT,
    git_branch TEXT,
    project_id TEXT,
    conversation_origin TEXT,
    trial_conversation_type TEXT,
    chatgpt_async_status INTEGER,
    observation_sequence INTEGER NOT NULL,
    pending_observed_title INTEGER NOT NULL DEFAULT 0,
    missing_candidate INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (host_id, thread_id)
);

CREATE TABLE local_thread_catalog_host_sync_state (
    host_id TEXT PRIMARY KEY,
    watermark_updated_at INTEGER,
    last_full_reconciled_at INTEGER,
    initial_build_complete INTEGER NOT NULL DEFAULT 0
);
```

### 2.3 Key Query Semantics Verified in `early-bootstrap-920` (`@732731`)
- **Work vs Chat Separation**:
  - `"tpp" === e.conversationOrigin` -> `AND conversation_origin = 'tpp'` (Work mode cloud conversations).
  - `"non-tpp" === e.conversationOrigin` -> `AND conversation_origin IS NOT 'tpp'` (Standard ChatGPT Cloud Chat conversations).
- **Project Grouping**:
  - Local/SSH threads group by longest matching normalized `cwd` prefix (`pd(cwds)` at `@732760`).
  - ChatGPT Cloud threads group by `project_id` (`gizmo_id` starting with `"g-p-"` at `@3847540`).
- **Conflict Resolution**:
  - Uses `observation_sequence = MAX(local_thread_catalog.observation_sequence, excluded.observation_sequence)` and `source_updated_at` watermarks so stale background list pages do not overwrite fresher live title/archive mutations.

---

## 3. `~/.codex/sqlite/codex_dev.db` (Owned by ChatGPT Desktop Main Process)

### 3.1 Tables & Schema (`LOCAL_SCHEMA`)
1. **`automations`**:
   - Scheduled local tasks (`id`, `name`, `prompt`, `status`, `next_run_at`, `last_run_at`, `cwds`, `rrule`, `execution_environment`, `model`, `reasoning_effort`, `project_id`, `thread_id`).
2. **`automation_runs`**:
   - Execution log per run (`thread_id PRIMARY KEY`, `automation_id`, `status`, `read_at`, `thread_title`, `source_cwd`, `inbox_title`, `inbox_summary`, `archived_user_message`, `archived_assistant_message`).
3. **`inbox_items`**:
   - Heartbeat / background notification inbox (`id`, `title`, `description`, `thread_id`, `read_at`, `created_at`).
