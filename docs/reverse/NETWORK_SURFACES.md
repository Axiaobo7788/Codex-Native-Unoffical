# ChatGPT Desktop (`26.1103.32239`) — Network Surfaces & Protocol Catalog

> **Scope**: Structured catalog of all REST, Server-Sent Events (SSE), newline-delimited JSON (JSONL), WebSocket, MASQUE, and telemetry network surfaces present in ChatGPT Desktop `26.1103.32239` (`codexBuildNumber: 25471`).

---

## 1. Common Authentication, Workspace, and Surface Headers (`WvOS` in `972499.b9f8eb2bc4.js`)

All requests to `https://chatgpt.com/backend-api/*` and `wss://codex-cloud-backend.chatgpt.com/` attach a standardized set of headers via the main-process proxy (`codex_desktop:fetch` / `codex_desktop:fetch-stream`):

| Header Name | Example / Source | Purpose | Classification |
| :--- | :--- | :--- | :--- |
| `Authorization` | `Bearer <access_token>` | OAuth2 access token obtained via `https://auth.openai.com/` PKCE flow (`~/.codex/auth.json` or Electron session store). | `PRIVATE_COMPATIBILITY` |
| `ChatGPT-Account-Id` | `<account_uuid>` | Selects the active personal or Team/Enterprise workspace account. | `PRIVATE_COMPATIBILITY` |
| `X-OpenAI-Expected-Account-Id` | `<account_uuid>` (`WvOS.zB`) | Guard header ensuring account switches do not leak requests across workspaces. | `PRIVATE_COMPATIBILITY` |
| `X-Codex-Surface` | `"chatgpt_work"` \| `"codex"` (`WvOS.O8`) | Identifies the active desktop product experience (`sidebarProductMode`). | `PRIVATE_COMPATIBILITY` |
| `X-OpenAI-Attach-Desktop-Surface` | `"true"` (`WvOS.jp`) | Signals to the main-process fetch interceptor to inject desktop surface headers. | `LOCAL_IMPLEMENTATION_DETAIL` |
| `X-OpenAI-Attach-DeviceCheck-Token` | `"true"` (`WvOS.mf`) | Attaches platform attestation / DeviceCheck token on supported OSes. | `PLATFORM_NATIVE` |
| `X-OpenAI-Product-Sku` | `"codex"` \| `"aeon"` | Selects the Durable Cloud Host SKU on `wss://codex-cloud-backend.chatgpt.com/`. | `PRIVATE_COMPATIBILITY` |
| `x-codex-client-session-token` | `Bearer <remote_control_token>` | Short-lived session token from `/codex/remote/control/client/refresh/finish` for `remote-control` WebSocket. | `PRIVATE_COMPATIBILITY` |
| `x-codex-git-source` | Git origin / repo identifier (`QDMx.bl`) | Associates cloud tasks/PR checks with the current repository. | `PRIVATE_COMPATIBILITY` |

### 1.1 Streaming Parsers & Error/Retry Model (`WvOS`)

- **SSE Parser (`WvOS.oW`)**:
  - Reads `ReadableStreamDefaultReader`, splits frames on `\r\n\r\n` or `\n\n`, parses `event:` and multi-line `data:` fields, ignores `event: heartbeat`, and yields `{ event, data: JSON.parse(...) }`.
- **JSONL Stream Parser (`WvOS.zT`)**:
  - Splits UTF-8 stream on `\n`, strips trailing `\r`, and yields `JSON.parse(line)` for each non-empty line.
- **Error Extraction (`WvOS.$C` & `WvOS.up`)**:
  - Extracts normalized error code from `{ error_code }`, `{ file_parse_error_code }`, `{ code }`, `{ detail: { error } }`, or `{ extra }`.
  - Extracts retry eligibility from `detail.can_retry ?? can_retry`.
  - Network-layer transient errors (`WvOS.Vt`) match `EAI_AGAIN`, `EADDRINFO`, `ECONNREFUSED`, `ECONNRESET`, `EHOSTUNREACH`, `ENETUNREACH`, `ENOTFOUND`, `ETIMEDOUT`, `UND_ERR_CONNECT_TIMEOUT`, `UND_ERR_HEADERS_TIMEOUT`, `UND_ERR_BODY_TIMEOUT`, `UND_ERR_SOCKET`, or Chromium `net::*` (excluding `net::ERR_ABORTED`).

---

## 2. Core ChatGPT Cloud REST & SSE Endpoints (`https://chatgpt.com/backend-api/*`)

| Endpoint | Method | Purpose | Request / Query Schema | Response / Stream Schema | Pagination & Retry | Classification |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `/backend-api/conversations` | `GET` | Lists cloud Chat & Work conversations for `ThreadCatalogSyncManager` (`chatgpt:` host). | `?offset=<int>&limit=100&order=updated&is_archived=false&hide_snorlax=false` (or `?gizmo_id=g-p-...&cursor=...` for project threads) | `{ items: [{ id, title, create_time, update_time, gizmo_id, conversation_origin, is_archived, is_starred, async_status, current_node }], total, limit, offset, has_missing_conversations }` | Offset pagination (`limit: 100`), 30-day window (`maxHistoryAgeMs = 2592000000`), `300,000ms` (5m) backoff on failure. | `PRIVATE_COMPATIBILITY` |
| `/backend-api/conversations/batch` | `POST` | Batch-fetches summary metadata for specific cloud conversation IDs (`readItem`). | `{ conversation_ids: ["<uuid>", ...] }` | `{ conversations: { "<uuid>": { id, title, update_time, gizmo_id, conversation_origin, async_status, ... } } }` | Single-batch lookup; retried on transient network error. | `PRIVATE_COMPATIBILITY` |
| `/backend-api/conversation/:id` | `GET` | Loads the message DAG (`mapping` + `current_node`) for a single cloud conversation (`MrGp.en`). | Path `:id` (`conversation_id`), optional pagination cursor query. | `{ conversation_id, title, create_time, update_time, mapping: { "<nodeId>": { id, message, parent, children } }, current_node, gizmo_id, conversation_origin, async_status, pagination?: { cursor, numTurns } }` | Cursor-based older turn pagination (`t.pagination.cursor`, `paginated-root:*` merge in `MrGp.en`). | `PRIVATE_COMPATIBILITY` |
| `/backend-api/conversation/:id` | `PATCH` | Renames, archives (`is_visible: false`), pins (`is_starred: true`), or moves a conversation to a project (`gizmo_id`). | `{ title?: string, is_visible?: boolean, is_starred?: boolean, gizmo_id?: string \| null }` | `{ success: true }` | Optimistic update in `MrGp` & `local_thread_catalog` with rollback on error. | `PRIVATE_COMPATIBILITY` |
| `/backend-api/f/conversation` | `POST` (SSE) | Submits a prompt, tool result (`submitChatGPTLocalFunctionResult`), or regeneration (`submitChatGPTRegeneration`) and streams the model response (`uNU6`). | `{ action: "next" \| "variant" \| "continue", messages: [...], parent_message_id, model, conversation_id?, gizmo_id?, conversation_origin?: "chatgpt" \| "work" \| "tpp", thinking_effort?, system_hints?, tpp_execution_target? }` | SSE stream (`WvOS.oW`): delta patches / message objects updating `mapping[nodeId].message`, `current_node`, `async_status`, and `writing_blocks` until `[DONE]`. | Supports continuation / resume via `daybreakContinuationMessageId` and `can_retry`. | `PRIVATE_COMPATIBILITY` |
| `/backend-api/models` | `GET` | Discovers available models, reasoning efforts, enabled tools, and attachment limits (`ed.$0`). | `?is_gizmo=<bool>` | `{ models: [{ slug, title, max_tokens, enabled_tools, product_features, thinking_efforts }], categories: [...] }` | Cached per account/project in query client. | `PRIVATE_COMPATIBILITY` |
| `/backend-api/accounts/check/v4-2023-04-27` | `GET` | Discovers user accounts, Team/Enterprise workspaces, entitlements, and access flags (`codexLocalAccess`, `workCloudAccess`, `workLocalAccess`). | Header `ChatGPT-Account-Id` (optional on initial check) | `{ accounts: { "<id>": { account: { account_id, plan_type, structure }, features: [...], entitlement: {...} } }, account_ordering: [...] }` | Refreshed on startup, login, and workspace switch. | `PRIVATE_COMPATIBILITY` |
| `/backend-api/estuary/content` & `/backend-api/files` | `POST` / `PUT` / `GET` | Uploads composer attachments (`M8gg` / `uLW7`) and downloads user/assistant library files & images. | Initiate: `{ file_name, file_size, use_case, entry_surface: "chat_composer" }` -> PUT bytes -> Finalize (`index_for_retrieval`). | `{ file_id, upload_url, download_url, status }` | Chunked/presigned PUT with abort signal support. | `PRIVATE_COMPATIBILITY` |
| `/backend-api/gizmos/snorlax/sidebar` & `/backend-api/gizmos/*` | `GET` / `POST` | Lists and provisions Cloud Projects (`g-p-*` "snorlax" gizmos) and custom GPTs; backs `codex_unified_projects`. | `?conversations_per_gizmo=5&cursor=...` | `{ items: [{ gizmo: { id: "g-p-...", display: { name, theme } }, conversations: { items: [...] } }], cursor }` | Cursor-paginated; synced with local projects via `~/.codex/project-chatgpt-provisioning/`. | `PRIVATE_COMPATIBILITY` |
| `/backend-api/aip/connectors/*` & `/backend-api/ecosystem/call_mcp` | `GET` / `POST` | Lists OAuth cloud connectors (`app://`) and proxies cloud MCP tool calls (`codex_mcp_elicitation`). | `{ connector_id, tool_name, arguments, elicitation_response? }` | Tool result JSON or `codex_mcp_elicitation` approval prompt. | Per-call timeout and elicitation continuation via `uNU6`. | `SERVER_ONLY` / `PRIVATE_COMPATIBILITY` |

---

## 3. Codex Cloud, Remote Control, and `/wham/*` Surfaces (146 Endpoints)

The desktop bundle contains **146 `/wham/*` endpoints** (OpenAI's internal codename for Codex Cloud / Work / Remote Control backend services mounted under `/backend-api/wham/*`). They fall into 6 functional groups:

### 3.1 Remote Control Device Enrollment & Relay (`/backend-api/codex/remote/control/*` & `/wham/remote/control/*`)

| Endpoint | Method / Protocol | Purpose | Classification |
| :--- | :--- | :--- | :--- |
| `/backend-api/codex/remote/control/client/enroll/start` | `POST` | Begins controller enrollment using an OS-protected device public key (`remote-control-device-key.node`) and a fresh (`< 300s`) MFA `step_up_token` (`scope: "codex.remote_control.enroll"`). | `PRIVATE_COMPATIBILITY` |
| `/backend-api/codex/remote/control/client/enroll/finish` | `POST` | Completes enrollment with a cryptographic signature over the enrollment challenge. | `PRIVATE_COMPATIBILITY` |
| `/backend-api/codex/remote/control/client/refresh/start` & `/finish` | `POST` | Challenges the hardware device key and mints a short-lived `remote_control_token` (`scopes: ["remote_control_controller_websocket"]`). | `PRIVATE_COMPATIBILITY` |
| `/backend-api/wham/remote/control/environments` | `GET` / `POST` / `DELETE` | Lists, registers, or removes remote host environments (`env_id`, `host_name`, `online`, `busy`, `os`, `arch`, `app_server_version`). | `PRIVATE_COMPATIBILITY` |
| `wss://chatgpt.com/backend-api/wham/remote/control/server` (and `/codex/remote/control/client`) | `WebSocket` | Bidirectional relay for `codex app-server` JSON-RPC over the cloud. Requires `x-codex-client-session-token` header and inline `device_key_challenge` -> `device_key_proof` signature handshake. | `PRIVATE_COMPATIBILITY` |

### 3.2 Durable Cloud App-Server Host (`wss://codex-cloud-backend.chatgpt.com/`)

- **Protocol**: WebSocket carrying `codex app-server` JSON-RPC (`evZ` -> `eph` over `ed.bvG`).
- **Headers**: `Authorization: Bearer <token>`, `ChatGPT-Account-Id`, `X-OpenAI-Product-Sku: "codex"` (or `"aeon"` when `getThreadProductSku(thread) === "aeon"`).
- **Capabilities**: Supports `thread/start`, `thread/startAeon`, `thread/resume`, `turn/start`, and canonical turn/timeline pagination for cloud-hosted agent sessions (`hostConfig.id === "durable"`).
- **Classification**: `PRIVATE_COMPATIBILITY` / `SERVER_ONLY`.

### 3.3 Cloud Tasks, Environments, Usage, and GitHub Integration (`/backend-api/wham/*`)

| Endpoint Group | Representative Paths | Purpose | Classification |
| :--- | :--- | :--- | :--- |
| **Cloud Tasks** | `/wham/tasks`, `/wham/tasks/:id`, `/wham/tasks/:id/turns`, `/wham/tasks/:id/archive` | Manages asynchronous cloud coding tasks (`remoteTaskCreated`), diffs, and PR creation. | `PRIVATE_COMPATIBILITY` |
| **Cloud Environments** | `/wham/environments`, `/wham/environments/:id/setup`, `/wham/environments/:id/secrets` | Configures container images, setup scripts, network access policies, and secrets for cloud tasks. | `PRIVATE_COMPATIBILITY` |
| **Credits & Usage** | `/wham/usage`, `/wham/usage/credits`, `/wham/pricing` | Powers the sidebar/settings usage meter (`--color-usage-meter-*`, plan vs reserve credits). | `PRIVATE_COMPATIBILITY` |
| **GitHub / PR Checks** | `/wham/github/repos`, `/wham/github/pulls`, `/wham/github/checks` | Queries GitHub repository branches, PR mergeability (`p4FI`), and CI check statuses. | `PRIVATE_COMPATIBILITY` |
| **MASQUE Proxy** | `https://masque.chatgpt.com/` | Privacy/network relay endpoint referenced in main-process network configuration. | `SERVER_ONLY` |

---

## 4. Feature Gates, Config Rules, and Telemetry

### 4.1 App-Server `features.*` & Remote Config Rules (`d5Fp` in `972499.b9f8eb2bc4.js`)

The desktop app dynamically merges remote `config_rules` (gated by `min_app_server_version`) with local `config.toml` overrides:

- **UI-Managed Feature Keys (`u` set in `d5Fp`)**:
  - `features.search_mcp`
  - `features.auth_elicitation`
  - `features.plugins`
  - `features.apps`
  - `features.tool_suggest`
  - `features.tool_call_mcp_elicitation`
  - `features.writing_blocks`
  - `guardianv2` (structured config supported when app-server `>= 0.165.0`, otherwise boolean `enabled`)
- **Version-Gated Config Keys (`d5Fp.hR`)**:
  - Automatically strips unsupported `features.*` keys (`guardian_native_multi_agent_history`, `multi_agent_v2.preserve_fork_prefix`, `async_compaction`, `output_token_replay`, `incremental_tools`, `skill_catalog_deltas`, `reasoning_effort_override`, `instant_interrupt`, `apply_patch_preserve_line_endings`, `compaction_image_budget`, `deferred_tool_world_state`, `mcp_oauth_refresh_coordination`, `recommended_plugins`) when the connected `codex app-server` version is older than the required threshold in `Ehlj`.

### 4.2 Telemetry & Experimentation Surfaces (`SERVER_ONLY` — Do Not Adopt)

- `https://ab.chatgpt.com/v1/initialize` & `/rgstr` (Statsig feature gates & dynamic configs, e.g., `codex_unified_projects`).
- `https://ces.chatgpt.com/v1/ces/v1/t` & `/b` (Client Event Service analytics).
- Sentry crash reporting (`codex_desktop:get-sentry-init-options`).
- **Recommendation for `Codex-Native-Unoffical`**: Classify all telemetry/Statsig endpoints as `SERVER_ONLY` and **do not implement them**; expose clean local feature toggles in Settings instead.
