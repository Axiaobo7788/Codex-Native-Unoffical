# Chat Protocol Map & Endpoint Taxonomy

> **Audited Package**: ChatGPT / Codex Desktop Linux Packaging (`26.1103.32239`)  
> **Target Architecture**: Clean-Room `ChatBackend` Abstraction (`lib/src/domain/` & `lib/src/protocol/`)  
> **Evidence Grading Standards**: `PUBLIC_DOC`, `PUBLIC_SOURCE`, `LIVE_OBSERVED`, `LIVE_CALLED`, `STATIC_BUNDLE`, `STATIC_APK`, `STATIC_DEX`, `LOCAL_SCHEMA`, `INFERRED`

---

## 1. Executive Summary & Clean-Room Architecture Principles

This document defines the complete protocol mapping and endpoint taxonomy governing ChatGPT and Codex client interactions. In strict adherence to repository memory (`AGENTS.md` and `docs/DECISIONS.md`), our architecture enforces the following non-negotiable clean-room principles:

1. **Public Supported Interfaces First**: The primary foundation for standard conversational AI is the public, documented OpenAI API (`/v1/chat/completions`, `/v1/models`, `/v1/files`).
2. **Stock Codex App-Server as Desktop Engine**: For agentic coding, repository navigation, terminal execution, and diff generation, the client integrates directly with the stock `codex app-server` over stdio JSON-RPC 2.0.
3. **Private Web APIs Never Form Core Foundation**: Proprietary web session endpoints (`/backend-api/*`, `/wham/*`) observed in official Electron/Android bundles are documented strictly for reverse analysis, wire compatibility, and security auditing. They are **never** permitted as the core dependency of `Codex-Native-Unoffical`.
4. **Isolate Protocol-Version Differences**: All protocol adaptations occur within typed protocol adapters (`lib/src/protocol/`), keeping the domain model (`lib/src/domain/`) completely decoupled and agnostic of wire formats.

---

## 2. Multi-Tier Protocol Taxonomy

```
+-----------------------------------------------------------------------------------+
|                           Codex-Native-Unoffical UI                               |
|                  (Presentation Primitives & ViewModels)                           |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
|                        Domain Abstraction Seam (ChatBackend)                      |
|                  ConversationThread | HistoryTurn | HistoryItem                   |
+-----------------------------------------------------------------------------------+
           |                                       |                     |
           v                                       v                     v
+-----------------------+              +-----------------------+   +----------------+
|  Stock Codex Backend  |              |   Public API Backend  |   | Compatibility  |
|  (Local / Remote)     |              |   (Direct OpenAI)     |   | Layer (Opt-in) |
|                       |              |                       |   |                |
| - Stdio JSON-RPC 2.0  |              | - REST / SSE          |   | - Session Auth |
| - 180 Client Requests |              | - /v1/chat/completions|   | - /backend-api |
| - 86 Notifications    |              | - /v1/models          |   |   (Secondary)  |
| - 11 Server Requests  |              | - /v1/files           |   |                |
+-----------------------+              +-----------------------+   +----------------+
```

---

## 3. Protocol Surface 1: Stock `codex app-server` (Local Engine)

The official desktop client bundles `codex app-server` (`codex-cli 0.167.0-alpha.3.2`). Communication occurs via newline-delimited JSON-RPC 2.0 over standard input and standard output (`stdio://`).

- **Evidence Tag**: `LOCAL_SCHEMA`, `LIVE_CALLED`, `PUBLIC_SOURCE`
- **Framing**: UTF-8 encoded, single newline-terminated JSON strings (`\n`). No binary headers or BOM.
- **Specification Counts** (`codex app-server generate-json-schema --experimental`):
  - **`ClientRequest`**: 180 methods
  - **`ServerNotification`**: 86 notification methods
  - **`ServerRequest`**: 11 server-initiated approval/elicitation methods
  - **`ClientNotification`**: 1 method (`initialized`)

### 3.1 Key Client Requests (`ClientRequest.json`)

| RPC Method | Parameters | Return Type | Role in Client Architecture |
|---|---|---|---|
| `initialize` | `clientInfo: { name, version }`, `capabilities` | `InitializeResult` | Handshake establishing protocol version and client capabilities. |
| `thread/list` | `cursor?: string`, `limit?: number` | `{ threads: ThreadSummary[], nextCursor }` | Paginated catalog enumeration; bounded to 100 threads in native client. |
| `thread/read` | `threadId: string` | `ThreadDetail` | Hydrates top-level thread metadata without loading unbounded turns. |
| `thread/start` | `model?: string`, `effort?: string`, `cwd?: string` | `{ threadId: string }` | Spawns a new active Codex session in target workspace. |
| `turn/start` | `threadId: string`, `input: UserInput` | `{ turnId: string }` | Dispatches user prompt, attachments, and configuration. |
| `turn/interrupt`| `threadId: string`, `turnId: string` | `void` | Requests immediate cancellation/abortion of running turn. |
| `thread/items/list` | `threadId`, `turnId`, `deferOutput` | `{ items: ThreadItem[] }` | On-demand lazy fetch of turn items and command outputs. |
| `remoteControl/pairing/start` | `{}` | `{ pairingCode, expiresAt }` | Initiates pairing handshake for mobile remote control. |
| `remoteControl/pairing/status`| `pairingId: string` | `{ status: 'pending' \| 'paired' }` | Polls/subscribes to remote device pairing resolution. |

### 3.2 Key Server Notifications (`ServerNotification.json`)

| Notification Method | Payload Schema | Client Handling |
|---|---|---|
| `thread/token/delta` | `{ threadId, turnId, delta: string }` | Streaming prose delta; coalesced over 50 ms window before UI update. |
| `command/exec/outputDelta` | `{ threadId, turnId, itemId, delta }` | Raw terminal stdout/stderr stream; spooled to disk by Native Host. |
| `turn/completed` | `{ threadId, turnId, status, error? }` | Finalizes turn; updates relative time; unlocks composer. |
| `thread/diff/updated` | `{ threadId, diffSummary, hunks }` | Updates inline diff pill (`+A -D`) and refreshes diff center-mode. |
| `account/rateLimits/updated` | `{ plan, tokensRemaining, resetAt }` | Surfaces rate-limit warnings or plan quota in footer. |

### 3.3 Key Server Requests (`ServerRequest.json`)

Server requests require the client to reply with a JSON-RPC response before the server proceeds:

| Request Method | Request Parameters | Required Response | Client Action |
|---|---|---|---|
| `item/commandExecution/requestApproval` | `{ command, cwd, riskLevel }` | `{ decision: 'approved' \| 'rejected' }` | Renders inline `CodexActivityRow` approval banner. |
| `item/fileChange/requestApproval` | `{ patch, path }` | `{ decision: 'approved' \| 'rejected' }` | Renders file modification confirmation card. |
| `account/chatgptAuthTokens/refresh` | `{}` | `{ accessToken, expiresAt }` | Requests fresh OAuth token from host credential store. |
| `mcpServer/elicitation/request` | `{ serverName, prompt }` | `{ input: string }` | Prompts user for interactive tool parameters. |

---

## 4. Protocol Surface 2: Public OpenAI REST / SSE API

- **Evidence Tag**: `PUBLIC_DOC`, `PUBLIC_SOURCE`
- **Base URL**: `https://api.openai.com/v1`
- **Wire Format**: HTTPS POST with Bearer token authentication (`Authorization: Bearer sk-...`).
- **Streaming**: Server-Sent Events (`text/event-stream`).

### 4.1 Endpoint Schema

| HTTP Method | Path | Request Body | Response Body | Usage |
|---|---|---|---|---|
| `POST` | `/v1/chat/completions` | `{ model, messages, stream: true, tools }` | SSE stream: `data: {"choices":[{"delta":{"content":"..."}}]}` | Standard LLM prose chat without Codex tooling. |
| `GET` | `/v1/models` | None | `{ data: [{ id: "gpt-4o", ... }] }` | Dynamic model list populating composer selector. |
| `POST` | `/v1/files` | `multipart/form-data` (file, purpose: "assistants") | `{ id: "file-...", filename, bytes }` | Uploads attachments for server processing. |

---

## 5. Protocol Surface 3: Reverse-Inspected Private Endpoints (`PRIVATE_INTERNAL_SERVICE`)

- **Evidence Tag**: `STATIC_BUNDLE`, `STATIC_APK`, `STATIC_DEX`
- **Classification**: `PRIVATE_INTERNAL_SERVICE` (Audit only; not for primary implementation)

The official Electron and Android packages contain static references to private internal services:

| Endpoint Path | Evidence Source | Classification | Note / Reason for Exclusion from Core |
|---|---|---|---|
| `/backend-api/conversation` | `STATIC_BUNDLE` (`early-bootstrap.js`) | `PRIVATE_INTERNAL_SERVICE` | Proprietary web-session SSE stream requiring cloud session cookies. |
| `/backend-api/models` | `STATIC_BUNDLE` / `STATIC_DEX` | `PRIVATE_INTERNAL_SERVICE` | Internal model catalog with experimental flags. |
| `/wham/usage/*` | `STATIC_BUNDLE` (`inspect_chatgpt_desktop.py`) | `PRIVATE_INTERNAL_SERVICE` | Internal telemetry and billing breakdown APIs. |
| `/wham/user-rules` | `STATIC_BUNDLE` (`338923.5e5c677ceb.js`) | `PRIVATE_INTERNAL_SERVICE` | Internal custom instructions storage. |
| `wss://chatgpt.com/backend-api/lat/r` | `STATIC_BUNDLE` | `PRIVATE_INTERNAL_SERVICE` | Real-time WebSocket relay for multi-client synchronization. |

---

## 6. Error Handling & Framing Schemas

JSON-RPC error payloads returned by `codex app-server` conform to `JSONRPCErrorError.json`:

```json
{
  "jsonrpc": "2.0",
  "id": "req-1234",
  "error": {
    "code": -32603,
    "message": "Tool execution rejected by host policy",
    "data": {
      "details": "Command failed with exit code 1",
      "command": "cargo build"
    }
  }
}
```

Standard error codes:
- `-32700`: Parse error (invalid JSON)
- `-32600`: Invalid request (not a valid JSON-RPC 2.0 object)
- `-32601`: Method not found (unsupported RPC call)
- `-32602`: Invalid params (schema mismatch)
- `-32603`: Internal error (app-server crash or exception)
- `-32000`..`-32099`: Server-defined errors (rate limit reached, process timeout, authorization denied)
