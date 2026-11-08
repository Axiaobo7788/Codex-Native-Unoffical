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
| `thread/list` | `cursor?: string`, `limit?: number`, `archived?: boolean` | `{ data: ThreadSummary[], nextCursor }` | Paginated catalog enumeration; bounded to 100 threads in native client. |
| `thread/read` | `threadId: string`, `includeTurns: false` | `{ thread: Thread }` | Hydrates top-level thread metadata without loading unbounded turns. |
| `thread/start` | `model?: string`, `cwd: string`, `ephemeral: boolean` | `{ thread: Thread }` | Spawns a new active Codex session in target workspace. |
| `thread/name/set` | `threadId: string`, `name: string` | `{}` | Renames a thread (`PUBLIC_SOURCE` stable). |
| `thread/archive` / `thread/unarchive` | `threadId: string` | `{}` / `{ thread: Thread }` | Archives or restores a thread (`PUBLIC_SOURCE` stable). |
| `thread/fork` | `threadId: string`, `beforeTurnId?`, `lastTurnId?`, `excludeTurns: true` | `{ thread: Thread, ... }` | Branches a thread or forks from a specific turn (`PUBLIC_SOURCE` stable). |
| `thread/revert` | `threadId: string`, `beforeTurnId: string` | `{ thread: Thread, ... }` | Truncates persisted turn history before a selected turn (`PUBLIC_SOURCE` stable). |
| `thread/compact/start` | `threadId: string` | `{}` | Triggers server-side context compaction (`PUBLIC_SOURCE` stable). |
| `turn/start` | `threadId: string`, `input: UserInput[]` | `{ turn: Turn }` | Dispatches user prompt, structured attachments, and configuration. |
| `turn/steer` | `threadId: string`, `expectedTurnId: string`, `input: UserInput[]` | `{ turnId: string }` | Steers an active in-progress turn with follow-up input (`PUBLIC_SOURCE` stable). |
| `turn/interrupt`| `threadId: string`, `turnId: string` | `{}` | Requests immediate cancellation/abortion of running turn. |
| `thread/items/list` | `threadId`, `turnId`, `deferOutput` | `{ data: ThreadItemEntry[], nextCursor }` | On-demand lazy fetch of turn items and command outputs. |
| `skills/list` / `skills/config/write` | `cwds: string[]` / `path, enabled` | `{ data: SkillsListEntry[] }` / `{ effectiveEnabled }` | Discovers and enables/disables workspace and bundled skills (`PUBLIC_SOURCE` stable). |
| `plugin/list` / `mcpServerStatus/list` | `cwds?: string[]` / `cursor?, limit?` | `{ marketplaces: ... }` / `{ data: McpServerStatus[] }` | Discovers installed plugins and MCP server connection/tool status (`PUBLIC_SOURCE` stable). |
| `remoteControl/pairing/start` | `{ manualCode?: boolean }` | `{ pairingCode, manualPairingCode?, environmentId, expiresAt }` | Initiates pairing handshake for official remote control (`EXPERIMENTAL_STOCK_SCHEMA`). |
| `remoteControl/pairing/status`| `{ pairingCode?, manualPairingCode? }` | `{ claimed: boolean }` | Polls remote device pairing resolution (`EXPERIMENTAL_STOCK_SCHEMA`). |

### 3.2 Key Server Notifications (`ServerNotification.json`)

| Notification Method | Payload Schema | Client Handling |
|---|---|---|
| `item/agentMessage/delta` | `{ threadId, turnId, itemId, delta: string }` | Streaming prose delta; coalesced over 50 ms window before UI update. |
| `item/started` / `item/completed` | `{ threadId, turnId, item: ThreadItem }` | Lifecycle of user messages, assistant messages, commands, file changes, and MCP tool calls (`_codexNativeOutput` spooled by Native Host). |
| `turn/started` / `turn/completed` | `{ threadId, turn: { id, status, error? } }` | Tracks active turn lifecycle, enables `turn/interrupt` & `turn/steer`, and finalizes turn state. |
| `turn/diff/updated` | `{ threadId, turnId, diff: string }` | Updates bounded unified diff projection (`+A -D`) and refreshes diff view. |
| `thread/name/updated` | `{ threadId, threadName: string? }` | Synchronizes renamed thread title in sidebar and conversation header. |
| `thread/archived` / `thread/unarchived` | `{ threadId }` | Synchronizes archived state across active/archived sidebar lists. |
| `thread/reverted` | `{ threadId, ... }` | Notifies client that turn history was truncated via `thread/revert`. |
| `account/rateLimits/updated` | `{ rateLimits: ... }` | Surfaces rate-limit warnings or plan quota in status views. |

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
