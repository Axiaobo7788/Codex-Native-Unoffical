# ChatGPT Desktop Network & API Surface Map (Recalibrated)

> **Evidence Sources**:
> - `STATIC_BUNDLE`: `python3 tools/reverse/inspect_chatgpt_desktop.py --evidence-report` (`168` static `/backend-api/*` and `/wham/*` path templates + `/flora/cca/executor` + `/cloud/environment/:id/status` + WebSocket endpoints across `.vite/build/*.js` and `webview/assets/*.js`).
> - `PUBLIC_SOURCE`: Stock `/opt/codex-desktop/resources/codex` (`codex-cli 0.167.0-alpha.3.2`) CLI and JSON schemas.
> - `PUBLIC_DOC`: Official OpenAI Platform API documentation (`https://platform.openai.com/docs/api-reference/responses`).

---

## 0. Epistemic Rule: Static Bundle Discovery != Public Contract

> [!IMPORTANT]
> **Observation in `app.asar` is NOT support.**
> The `168` `/backend-api/*` and `/wham/*` endpoint templates extracted from `app.asar` are tagged `STATIC_BUNDLE` (`DISCOVERED`). Many are feature-gated (`Statsig`), account-tier-gated, or legacy web-client routes bundled via shared packages. **None** of `/backend-api/*`, `/wham/*`, `/flora/*`, or `wss://codex-cloud-backend.chatgpt.com/` are `PUBLIC_SUPPORTED`.

| Network Surface Family | Static Count in ASAR | Evidence Tags | Support Classification | Policy for `Codex-Native-Unoffical` |
|---|---|---|---|---|
| **OpenAI Platform API** (`https://api.openai.com/v1/responses`, `/v1/models`, `/v1/files`) | N/A (used by `codex` Rust runtime & public API clients) | `PUBLIC_DOC`, `PUBLIC_SOURCE` | **`PUBLIC_SUPPORTED`** | Primary public cloud API for any future Native Chat (`OpenAIResponsesBackend`) |
| **Stock `codex app-server` Transports** (`stdio://`, `ws://IP:PORT` with `--ws-auth`) | Stock CLI & JSON-RPC | `PUBLIC_SOURCE`, `LIVE_CALLED` | **`PUBLIC_SUPPORTED`** (`stdio://`) / **`EXPERIMENTAL_STOCK_SCHEMA`** (`ws://`) | Primary local and direct-host transport for `Codex-Native-Unoffical` |
| **ChatGPT Web-Session API** (`/backend-api/f/conversation`, `/backend-api/conversations`, etc.) | `22` `/backend-api/*` templates (excluding `/backend-api/wham/*`) | `STATIC_BUNDLE` (`DISCOVERED`) | **`PRIVATE_WEB_SESSION`** | Never a default core dependency; isolate behind an opt-in experimental adapter if ever explored |
| **WHAM & Codex Cloud Internal APIs** (`/wham/*`, `/backend-api/wham/*`, `/backend-api/codex/remote/*`) | `146` `/wham/*` templates | `STATIC_BUNDLE` (`DISCOVERED`, many `FEATURE_GATED`) | **`PRIVATE_INTERNAL_SERVICE`** | Reference architecture only; do not depend on in core client |
| **Work Local Executor & Flora Registry** (`POST/DELETE /flora/cca/executor`, `GET /cloud/environment/:id/status`, Noise rendezvous) | `3` paths in `early-bootstrap-920` | `STATIC_BUNDLE` (`DISCOVERED`), `PUBLIC_SOURCE` (`codex exec-server`) | **`PRIVATE_INTERNAL_SERVICE`** | Reference architecture explaining how official Work Mode bridges cloud tasks to a local machine |
| **Durable Cloud Host WebSocket** (`wss://codex-cloud-backend.chatgpt.com/`, `X-OpenAI-Product-Sku: "aeon"`) | `1` WSS endpoint (`early-bootstrap-920 @1168648`) | `STATIC_BUNDLE` (`DISCOVERED`) | **`PRIVATE_INTERNAL_SERVICE`** | Explains `thread/startAeon` and `thread/environmentReady`; not used by local stock `codex app-server` |

---

## 1. Main-Process Network Proxy (`codex_desktop:fetch-from-main`)

### 1.1 Transport Architecture (`STATIC_BUNDLE`)
Renderer code in `webview/assets/*.js` does not call `chatgpt.com` directly via browser `fetch` when CORS, Electron session cookies, or custom headers are required. Instead, it invokes the preload-exposed IPC channel:
- Request: `codex_desktop:fetch-from-main` (with `requestId`, `url`, `method`, `headers`, `body`, `streaming: boolean`)
- Cancellation: `codex_desktop:cancel-fetch-from-main`
- Response / Stream chunks: delivered over `codex_desktop:message-for-view` (`fetch-response`, `fetch-stream-chunk`, `fetch-stream-end`, `fetch-error`).

### 1.2 Authentication & Anti-Bot Headers (`STATIC_BUNDLE` / `PRIVATE_WEB_SESSION`)
Requests routed through `applicationNetwork` attach:
- `Authorization: Bearer <chatgpt_access_token>` (obtained from the ChatGPT OAuth session / `app-server` account token).
- `ChatGPT-Account-Id: <account_id>` (workspace/team/enterprise scoping).
- `OAI-Device-Id: <device_uuid>` and `OAI-Language: <locale>`.
- **Sentinel / Proof-of-Work / Turnstile headers** (for `/backend-api/f/conversation` and `/prepare`):
  - `OpenAI-Sentinel-Chat-Requirements-Token`
  - `OpenAI-Sentinel-Proof-Token`
  - `OpenAI-Sentinel-Turnstile-Token`

---

## 2. ChatGPT Web-Session Surface (`/backend-api/*` — `PRIVATE_WEB_SESSION`)

| Endpoint Path (`STATIC_BUNDLE`) | Method | Role in ChatGPT Desktop | Status / Gate |
|---|---|---|---|
| `/backend-api/f/conversation/prepare` | `POST` | Pre-flight Sentinel/Turnstile/conduit token negotiation before starting a chat turn | Active in Chat/Work cloud conversations |
| `/backend-api/f/conversation` | `POST` (SSE) | Primary streaming conversation turn endpoint (emits `MrGp` DAG delta patches) | Active in Chat/Work cloud conversations |
| `/backend-api/conversations` | `GET` | Paginated conversation list (`offset`, `limit`, `order`, `is_archived`, returns `conversation_origin`, `gizmo_id`) | Used by `LocalThreadCatalog` (`@3831904`) |
| `/backend-api/conversation/:id` | `GET` / `PATCH` / `DELETE` | Fetch full `MrGp` tree DAG (`mapping`, `current_node`), rename, archive, or delete | Active in Chat mode |
| `/backend-api/me` & `/backend-api/accounts/check/v4-...` | `GET` | Account identity, workspace entitlements, and plan discovery | Active on sign-in |
| `/backend-api/files` & `/backend-api/files/download/:id` | `POST` / `GET` | Multimodal attachment upload & download | Active on file/image attach |

---

## 3. Work Mode & Durable Cloud Surface (`PRIVATE_INTERNAL_SERVICE`)

Verified in `.vite/build/early-bootstrap-920-a204a41244c4b913.js` (`@1168648`, `@1644000..1666500`):

| Endpoint / Protocol (`STATIC_BUNDLE`) | Component | Purpose |
|---|---|---|
| `POST /flora/cca/executor` | `tpp-local-executor` (`@1653000`) | Registers the local desktop (`installation_id`, `custom_display_name`) as a Work executor and returns `executor_id` (`environmentId`) |
| `DELETE /flora/cca/executor` | `tpp-local-executor` (`@1652200`) | Clears local Work executor registrations for the account |
| `GET /cloud/environment/:id/status` | `tpp-local-executor` (`@1646200`) | Verifies that the local `codex exec-server` is `"connected"` to the cloud rendezvous |
| Outbound Noise Rendezvous (`codex exec-server --remote <url> --environment-id <id>`) | `tpp-local-executor` (`@1658200`) | Encrypted Noise-protocol tunnel (`noise_event="rendezvous_connection"`) allowing cloud Work turns to execute tools locally |
| `wss://codex-cloud-backend.chatgpt.com/` | Durable Cloud Host (`@1168648`) | JSON-RPC-over-WebSocket connection for cloud threads (`thread/startAeon` when `X-OpenAI-Product-Sku === "aeon"`, plus `thread/environmentReady`) |

---

## 4. WHAM & Official Remote Control Surface (`146` `/wham/*` Paths — `PRIVATE_INTERNAL_SERVICE`)

The `146` `/wham/*` (and `/backend-api/wham/*`) path templates discovered in `webview/assets/*.js` and `.vite/build/*.js` group into six functional areas (`STATIC_BUNDLE`, many `FEATURE_GATED`):

1. **Official Remote Control Enrollment & Relay** (`early-bootstrap-920`):
   - `POST /backend-api/codex/remote/control/client/enroll/start` & `/complete` (requires `remote-control-device-key.node` + MFA `step_up_token`).
   - `POST /backend-api/codex/remote/control/client/refresh` (rotates controller credentials).
   - `wss://chatgpt.com/backend-api/wham/remote/control/server` (cloud WebSocket relay between controller and host).
2. **Cloud Tasks & Environments** (`/wham/tasks/*`, `/wham/environments/*`):
   - Managing cloud coding environments, container snapshots, PR creation, and background cloud tasks.
3. **GitHub / GitLab / Slack Integrations** (`/wham/github/*`, `/wham/slack/*`):
   - Repository linking, branch inspection, and PR status checks.
4. **Usage, Credits & Rate Limits** (`/wham/usage/*`, `/wham/credits/*`):
   - Plan quota and credit balance reporting.
5. **Automations & Jawbone Schedules** (`/wham/automations/*`, `/wham/jawbone/*`):
   - Cloud-hosted recurring automations (`habitatAutomationsService`).
6. **Marketplace & Remote Plugins** (`/wham/plugins/*`, `/wham/marketplace/*`):
   - Discovering and syncing remote plugin catalogs.
