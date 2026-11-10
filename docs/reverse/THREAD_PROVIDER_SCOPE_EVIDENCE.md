# Thread list provider-scope and account-scope evidence

Measured 2026-11-10 from shared Native `033eda841a20a900ef9b9db6ea59bb08f4225d40`, the bundled Rust Host (`build/linux/x64/debug/bundle/codex-native-host`, SHA-256 `1de94c6ad8ff026e5e7a8318547409700f7b2ffd5c51add3faa64096957547f9`), installed Desktop ASAR `26.1103.60933` build `25894` (SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`), public stock source `b6d93b4cbadd6f449395d326f72465a5823f1492`, and four stock `codex app-server` builds.

- Evidence classes: `LOCAL_SCHEMA`, `PUBLIC_SOURCE`, `STATIC_BUNDLE`, `LIVE_CALLED`.
- Support classification: `PUBLIC_SUPPORTED` (`thread/list`, `thread/read`, `thread/resume`, `thread/turns/list`, `threadSection/list`) and `EXPERIMENTAL_STOCK_SCHEMA` (`thread/search`).

## 1. Stock contract and public source (`b6d93b4`)

- **Schema vs default-provider substitution (`LOCAL_SCHEMA`, `PUBLIC_SOURCE`)**:
  - In generated `v2/ThreadListParams.json` across all four stock binaries and in [`codex-rs/app-server-protocol/src/protocol/v2/thread.rs`](https://github.com/openai/codex/blob/b6d93b4cbadd6f449395d326f72465a5823f1492/codex-rs/app-server-protocol/src/protocol/v2/thread.rs#L1437-L1526), `modelProviders` (`["array", "null"]` of `string`) is described as: *"Optional provider filter; when set, only sessions recorded under these providers are returned. When present but empty, includes all providers."*
  - In [`codex-rs/app-server/src/request_processors/thread_processor.rs`](https://github.com/openai/codex/blob/b6d93b4cbadd6f449395d326f72465a5823f1492/codex-rs/app-server/src/request_processors/thread_processor.rs#L6073-L6083), `list_threads_common` resolves `model_provider_filter` as:
    ```rust
    let model_provider_filter = match model_providers {
        Some(providers) => {
            if providers.is_empty() {
                None
            } else {
                Some(providers)
            }
        }
        None if relation_filter.is_some() => None,
        None => Some(vec![self.config.model_provider_id.clone()]),
    };
    ```
  - Consequently, omitting `modelProviders` or sending `"modelProviders": null` in any ordinary `thread/list` call (`relation_filter.is_none()`) restricts results to `vec![self.config.model_provider_id.clone()]` (the current app-server process's configured default provider, `"openai"` when unset). Only `"modelProviders": []` (or a relation query with `parentThreadId`, `ancestorThreadId`, or `attachedToThreadId`) passes `model_providers: None` to the store and includes all providers.
- **Store pushdown across catalog, section, search-term, and archive paths (`PUBLIC_SOURCE`)**:
  - [`LocalThreadStore::list_threads`](https://github.com/openai/codex/blob/b6d93b4cbadd6f449395d326f72465a5823f1492/codex-rs/thread-store/src/local/list_threads.rs#L24-L319) forwards `params.model_providers.as_deref()` into every listing path:
    1. Section-ordered SQLite queries (`sortKey: "section_position"`, `state_db.list_threads`) and relation/section/project SQLite queries (`state_db::list_threads_db`), which append `AND threads.model_provider IN (...)` when `model_providers` is non-empty ([`codex-rs/state/src/runtime/threads.rs`](https://github.com/openai/codex/blob/b6d93b4cbadd6f449395d326f72465a5823f1492/codex-rs/state/src/runtime/threads.rs#L1583-L1591)).
    2. Rollout and state-DB listing (`RolloutRecorder::list_threads`, `list_archived_threads`, `list_threads_from_state_db`, `list_archived_threads_from_state_db`), where `ProviderMatcher` ([`codex-rs/rollout/src/list.rs`](https://github.com/openai/codex/blob/b6d93b4cbadd6f449395d326f72465a5823f1492/codex-rs/rollout/src/list.rs#L969-L993)) matches `summary.model_provider` against the filter list (treating a legacy `None` provider in `SessionMeta` as matching `default_provider`).
  - By contrast, experimental `thread/search` ([`codex-rs/thread-store/src/local/search_threads.rs`](https://github.com/openai/codex/blob/b6d93b4cbadd6f449395d326f72465a5823f1492/codex-rs/thread-store/src/local/search_threads.rs#L95-L115)) constructs its internal `ListThreadsParams` with `model_providers: None` (and `ThreadSearchParams` has no `modelProviders` field), so `thread/search` matches across all providers regardless of the active provider.
  - `threadSection/list`, `thread/read`, `thread/turns/list`, `thread/items/list`, and `thread/searchOccurrences` do not filter by `model_provider`.
- **Cross-provider `thread/resume` evolution (`PUBLIC_SOURCE`, `LIVE_CALLED`)**:
  - In `0.167.0-alpha.3.2`, `0.167.0`, and `0.167.0-alpha.4.1`, `thread/resume` requires the thread's saved `model_provider` to match the process's current `model_provider_id`, rejecting cross-provider resumes with `-32600` and `data.type = "modelProviderMismatch"`.
  - In `0.169.0-alpha.7` and `b6d93b4` ([`codex-rs/app-server/src/config_manager.rs`](https://github.com/openai/codex/blob/b6d93b4cbadd6f449395d326f72465a5823f1492/codex-rs/app-server/src/config_manager.rs#L522-L592)), `load_for_resume` overrides `typesafe_overrides.model_provider` with `saved_provider`, validates that `saved_provider` exists in `config.model_providers` or `built_in_model_providers` (otherwise returning `ModelProviderNotConfigured`), and rejects any request override that changes `saved_provider` to a different provider (`Cannot change this thread's model provider from ... to ... on resume`).
- **Account-scope boundary (`currentAccountOnly` and `LocalHistoryAccount`, `LOCAL_SCHEMA`, `PUBLIC_SOURCE`)**:
  - `currentAccountOnly` (`bool`, default `false`) is absent from generated `v2/ThreadListParams.json` in `0.167.0-alpha.3.2` and `0.167.0`, and present in `0.167.0-alpha.4.1`, `0.169.0-alpha.7`, and `b6d93b4`.
  - In [`thread_processor.rs`](https://github.com/openai/codex/blob/b6d93b4cbadd6f449395d326f72465a5823f1492/codex-rs/app-server/src/request_processors/thread_processor.rs#L6032-L6044), `local_history_account(current_account_only)` returns `None` when `current_account_only` is `false` or when authenticated with an API key (`CodexAuth::is_api_key_auth`). Otherwise it constructs `LocalHistoryAccount { user_id, account_id }` from `self.auth_manager.auth_cached()` (both `None` when logged out / account-free).
  - [`LocalHistoryAccount::includes`](https://github.com/openai/codex/blob/b6d93b4cbadd6f449395d326f72465a5823f1492/codex-rs/thread-store/src/local_history_account.rs#L21-L68) reads each candidate rollout's `session_meta` line and requires:
    ```rust
    meta.id == thread_id
        && (!meta.account_scoped
            || ((meta.creator_user_id.is_none() || meta.creator_user_id == self.user_id)
                && (meta.creator_account_id.is_none()
                    || meta.creator_account_id == self.account_id)))
    ```
  - Pre-enforcement or unauthenticated rollouts (`account_scoped: false`) remain visible to all accounts. Rollouts with `account_scoped: true` and non-null `creator_user_id` / `creator_account_id` are excluded when `currentAccountOnly: true` and the cached ChatGPT identity is absent or belongs to a different user/account.

## 2. Installed Desktop ASAR call-site map (`STATIC_BUNDLE`)

In installed Desktop `26.1103.60933` build `25894` (`/opt/codex-desktop/resources/app.asar`, SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`), static `thread/list` call sites partition into current-provider (`modelProviders: null`), all-provider (`modelProviders: []`), and passthrough helpers:

| Bundle file | Byte offset | `modelProviders` | Additional parameters & call-site role |
|---|---:|---|---|
| `webview/assets/async/182735.5b42af8792.js` (also `.vite/build/early-bootstrap-815-e030c49be4b9c405.js` @ `1098450`) | `993821` | Caller `t` (`null` in `listArchivedThreads` @ `1029208` and archived section scan @ `1037982`) | `rE` / `listAllThreads`: paginates `limit: 100, useStateDbOnly: !0` with `sectionId: i, archived: r`. |
| `webview/assets/async/182735.5b42af8792.js` (also `early-bootstrap-815` @ `1063409`) | `994202` | `null` | `rI` / `w5`: recent conversations page fetch (`source: "recent_threads"`, `archived: !1, useStateDbOnly: !0`). |
| `webview/assets/async/182735.5b42af8792.js` (also `early-bootstrap-815` @ `1101323`) | `1031750` | `[]` | `searchThreads`: title-only fallback (`searchTitlesOnly` true) sends `modelProviders: [], searchTerm: i, useStateDbOnly: !0`; content search branch calls `thread/search`. |
| `webview/assets/async/182735.5b42af8792.js` (also `early-bootstrap-815` @ `1528903`) | `1418746` | `[]` | `hasActiveThread`: workspace `cwd` scan (`cwd: n.cwd, limit: 100, sortKey: "updated_at", useStateDbOnly: !0`). |
| `webview/assets/async/258250.86a3c8cb72.js` | `13278` | `[]` | `DeviceStorageSettings` chat inventory scan across `archived: false` and `true` (`limit: 100, useStateDbOnly: !0`), followed by `thread/read(includeTurns: !1)` recovery. |
| `webview/assets/async/115648.9f1b875de4.js` (also `328110` @ `28106`, `515055` @ `16577`, `837769` @ `14198`, `868576` @ `46230`) | `32217` | `null` | External agent session import precheck (`archived: o, limit: 50, sortKey: "updated_at", useStateDbOnly: !0`). |
| `.vite/build/early-bootstrap.js` | `59899` | `[]` | `listHostSectionThreadIds`: section-ordered membership query (`sectionId: t, sortKey: "section_position", limit: 100, useStateDbOnly: !0`). |
| `.vite/build/early-bootstrap-815-e030c49be4b9c405.js` | `3862304` | `[]` | `ehI`: host thread catalog page reader (`source: "thread_catalog"`, `parentThreadId: null, sortKey: "updated_at", sortDirection: "desc", useStateDbOnly: !0`). |
| `.vite/build/early-bootstrap-815-e030c49be4b9c405.js` | `3393673`, `3396665`, `4445115` | `[]` | Project assignment migration (`projectId: e` / all active) and inactive thread auto-archive (`sortDirection: "asc", limit: 50`). |
| `.vite/build/early-bootstrap-339-104173bc8fd02c8b.js` | `469186` | `null` | Ambient project suggestions recent-thread context (`limit: 100, sortKey: "updated_at", archived: !1, useStateDbOnly: !0`). |

- In `webview/assets/async/182735.5b42af8792.js` at byte `1140358` (and `.vite/build/early-bootstrap-815-e030c49be4b9c405.js` at byte `1213289`), Desktop parses structured resume errors (`modelProviderMismatch`, `modelProviderNotConfigured`, `modelProviderPolicyConflict`), and `webview/assets/async/884779.bf167971f9.js` at byte `295567` renders dedicated `threadProviderBlock.*` notices when a selected thread uses a different or unconfigured provider.
- Zero occurrences of `currentAccountOnly` exist in this ASAR bundle.

## 3. Disposable 4-binary real-runtime and bundled Host matrix (`LIVE_CALLED`)

For each stock binary, a disposable probe created an isolated `HOME`, `CODEX_HOME`, workspace directory, and loopback HTTP Responses SSE server on `127.0.0.1`, driving all requests through the bundled `codex-native-host` (`--codex <binary>`):

1. **Process 1 (`model_provider = "provider_alpha"`)**: created section `CrossProviderSection` (`sec_id`), materialized `a1` (`"Alpha Thread 1"`, moved into `sec_id`), `a2` (`"Alpha Thread 2 Archived"`, archived via `thread/archive`), and `a3` (`"Alpha Thread 3"`, active unsectioned).
2. **Process 2 (`model_provider = "provider_beta"` on the same `CODEX_HOME`)**: materialized `b1` (`"Beta Thread 1"`, moved into `sec_id`) and `b2` (`"Beta Thread 2"`, active unsectioned), then ran the `thread/list` and `thread/search` matrix.
3. **Process 3 (default `model_provider = "openai"` with `provider_alpha` and `provider_beta` configured in `[model_providers.*]`)**: queried default vs empty-array `thread/list`, `threadSection/list`, section-scoped `thread/list`, 2-row pagination, `thread/read(a1)`, `thread/turns/list(a1)`, and cold `thread/resume(a1)` (with no provider override, matching override, and mismatched `provider_beta` override).
4. **Process 4 (`[model_providers.provider_alpha]` removed from `config.toml`)**: verified `thread/read(a1)`, `thread/turns/list(a1)`, and cold `thread/resume(a1)`.
5. **Process 5 (`a3` rollout `session_meta` marked `account_scoped: true, creator_user_id: "user-scoped-999", creator_account_id: "acct-scoped-999"` in account-free `CODEX_HOME`)**: compared `currentAccountOnly: false` vs `true` on `thread/list(modelProviders: [])`, 2-row pagination (`limit: 2`), `thread/search`, and `thread/read(a3)`.

| Check (via bundled `codex-native-host`) | Installed `0.167.0-alpha.3.2` | Public stable `0.167.0` | Desktop-train `0.167.0-alpha.4.1` | Public alpha `0.169.0-alpha.7` |
|---|---|---|---|---|
| Process 2 (`provider_beta`) `thread/list` (`modelProviders` omitted or `null`) | `2` rows (`[b2, b1]`) | `2` rows (`[b2, b1]`) | `2` rows (`[b2, b1]`) | `2` rows (`[b2, b1]`) |
| Process 2 (`provider_beta`) `thread/list` (`modelProviders: []`) | `4` rows (`[b2, b1, a3, a1]`) | `4` rows (`[b2, b1, a3, a1]`) | `4` rows (`[b2, b1, a3, a1]`) | `4` rows (`[b2, b1, a3, a1]`) |
| Process 2 (`provider_beta`) `thread/list` (`modelProviders: ["provider_alpha"]`) | `2` rows (`[a3, a1]`) | `2` rows (`[a3, a1]`) | `2` rows (`[a3, a1]`) | `2` rows (`[a3, a1]`) |
| Process 2 (`provider_beta`) `thread/list` (`sectionId: sec_id`, `modelProviders` omitted vs `[]`) | `1` (`[b1]`) vs `2` (`[a1, b1]`) | `1` (`[b1]`) vs `2` (`[a1, b1]`) | `1` (`[b1]`) vs `2` (`[a1, b1]`) | `1` (`[b1]`) vs `2` (`[a1, b1]`) |
| Process 2 (`provider_beta`) `thread/list(searchTerm: "Alpha")` (omitted vs `[]`) | `0` vs `2` (`[a3, a1]`) | `0` vs `2` (`[a3, a1]`) | `0` vs `2` (`[a3, a1]`) | `0` vs `2` (`[a3, a1]`) |
| Process 2 (`provider_beta`) `thread/search(searchTerm: "Alpha unique content")` | `2` (`[a3, a1]`) | `2` (`[a3, a1]`) | `2` (`[a3, a1]`) | `2` (`[a3, a1]`) |
| Process 2 (`provider_beta`) `thread/list(archived: true)` (omitted vs `[]`) | `0` vs `1` (`[a2]`) | `0` vs `1` (`[a2]`) | `0` vs `1` (`[a2]`) | `0` vs `1` (`[a2]`) |
| Process 3 (`openai` default) `thread/list` (omitted vs `[]`) | `0` vs `4` (`[b2, b1, a3, a1]`) | `0` vs `4` (`[b2, b1, a3, a1]`) | `0` vs `4` (`[b2, b1, a3, a1]`) | `0` vs `4` (`[b2, b1, a3, a1]`) |
| Process 3 (`openai` default) `threadSection/list` includes `sec_id` / `thread/list(sectionId: sec_id)` omitted vs `[]` | `true` / `0` vs `2` (`[a1, b1]`) | `true` / `0` vs `2` (`[a1, b1]`) | `true` / `0` vs `2` (`[a1, b1]`) | `true` / `0` vs `2` (`[a1, b1]`) |
| Process 3 (`openai` default) `thread/read(a1)` and `thread/turns/list(a1)` | `OK` (`provider_alpha`, `1` turn) | `OK` (`provider_alpha`, `1` turn) | `OK` (`provider_alpha`, `1` turn) | `OK` (`provider_alpha`, `1` turn) |
| Process 3 (`openai` default) cold `thread/resume(a1)` (`provider_alpha` still in `config.toml`) | `-32600` (`modelProviderMismatch`) | `-32600` (`modelProviderMismatch`) | `-32600` (`modelProviderMismatch`) | `OK` (`modelProvider: "provider_alpha"`) |
| Process 3 (`openai` default) cold `thread/resume(a1, modelProvider: "provider_beta")` | `-32600` (`modelProviderMismatch`) | `-32600` (`modelProviderMismatch`) | `-32600` (`modelProviderMismatch`) | `-32600` (`Cannot change this thread's model provider...`) |
| Process 4 (`provider_alpha` removed) `thread/read(a1)` & `thread/turns/list(a1)` / `thread/resume(a1)` | `OK` / `-32600` (`modelProviderNotConfigured`) | `OK` / `-32600` (`modelProviderNotConfigured`) | `OK` / `-32600` (`modelProviderNotConfigured`) | `OK` / `-32600` (`modelProviderNotConfigured`) |
| Process 5 (`a3` `account_scoped: true`) `thread/list(modelProviders: [])` (`currentAccountOnly: false` vs `true`) | `4` vs `4` (field ignored) | `4` vs `4` (field ignored) | `4` vs `3` (`a3` excluded) | `4` vs `3` (`a3` excluded) |
| Process 5 (`a3` `account_scoped: true`) `thread/search` (`currentAccountOnly: false` vs `true`) | `1` vs `1` (field ignored) | `1` vs `1` (field ignored) | `1` vs `0` (`a3` excluded) | `1` vs `0` (`a3` excluded) |

- **Typed Native `ProcessTransport` verification (`LIVE_CALLED`)**:
  - Driving unmodified `ProcessTransport` (`ThreadProtocolAdapter.listThreads`, `listThreadSections`, `readThread`, `resumeThread`, and `HistoryProtocolAdapter.listHistoryTurns`) against the Process 3 (`openai` default) fixture on installed `0.167.0-alpha.3.2` and `0.169.0-alpha.7` confirmed:
    - `listThreads(limit: 20, sortKey: updatedAt)` returned `0` rows on both builds.
    - `listThreadSections()` returned `CrossProviderSection` (`sec_id`) on both builds, while `listThreads(section: (id: secId), sortKey: sectionPosition)` and `listThreads(searchTerm: 'Alpha')` each returned `0` rows.
    - `readThread(a1)` and `listHistoryTurns(threadId: a1, limit: 5)` succeeded on both builds (`1` turn).
    - `resumeThread(a1)` threw `JsonRpcException(-32600, "This chat uses provider_alpha, but your current provider is openai. Switch to provider_alpha to continue.")` on `0.167.0-alpha.3.2` and succeeded (`OK`) on `0.169.0-alpha.7`.

## 4. Native visibility and bounded pagination implications

- **Why current `ThreadProtocolAdapter.listThreads` behavior is safe on `0.167.0*` but hides cross-provider history**:
  - [`ThreadProtocolAdapter.listThreads`](../../lib/src/protocol/thread_protocol.dart#L37-L97) omits `modelProviders`. On `0.167.0-alpha.3.2`, `0.167.0`, and `0.167.0-alpha.4.1`, that default aligns the sidebar list with threads that can be resumed under the current `model_provider` without hitting `-32600` (`modelProviderMismatch`).
  - However, omitting `modelProviders` also filters scoped section browsing (`F16`), saved-thread title search (`F19`), and archived listing (`F1`) to the current provider, even though `threadSection/list` returns sections containing cross-provider threads and `thread/read` / `thread/turns/list` can inspect cross-provider history on all four builds.
- **Prerequisites before adopting `modelProviders: []` or provider-scoped filtering in Native**:
  1. **Project `modelProvider` on `ThreadSummary`**: [`ThreadProtocolAdapter._parseThread`](../../lib/src/protocol/thread_protocol.dart#L580-L608) currently drops `value['modelProvider']`. Surfacing cross-provider rows requires retaining a bounded `modelProvider` identifier on `ThreadSummary` so the UI can distinguish threads recorded under a non-default provider.
  2. **Guard cold resume / composer Send on provider mismatch or removal**: If `thread/list` sends `modelProviders: []`, selecting a cross-provider thread will succeed during metadata/history hydration (`thread/read` + `thread/turns/list`) and then fail on `thread/resume` in `0.167.0*` (`modelProviderMismatch`) or when the provider is removed (`modelProviderNotConfigured` on all four builds). Native must either keep default sidebar listing scoped to the active provider or handle `modelProviderMismatch` / `modelProviderNotConfigured` as a non-fatal read-only thread state before enabling all-provider listing.
  3. **Bounded pagination invariants hold under both `modelProviders: []` and `currentAccountOnly: true`**:
     - `model_providers` is pushed down into SQLite (`WHERE threads.model_provider IN (...)`) and rollout `ProviderMatcher`, so `modelProviders: []` and explicit provider lists preserve exact page sizes (`limit <= 100`) and cursor termination (`p1` returned `[b2, b1]` and `p2` returned `[a3, a1]` with `nextCursor: null` across all four builds).
     - When `currentAccountOnly: true` excludes an `account_scoped` rollout (`a3`) on `0.167.0-alpha.4.1` and `0.169.0-alpha.7`, `list_threads_common`'s internal `while remaining > 0` loop automatically advances the store cursor to refill the requested `limit: 2` (`p1` returned `[b2, b1]`, `p2` returned `[a1]` with `nextCursor: null`), while performing one `session_meta` header read per candidate row in the page.
