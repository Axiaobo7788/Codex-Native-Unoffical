# ChatGPT Desktop (`26.1103.32239`) — Codex Runtime & Remote Integration Map

> **Scope**: Documents how official ChatGPT Desktop spawns, negotiates capabilities with, and multiplexes across 5 transports for `codex app-server`, how official Remote Control (`wham/remote/control`) works at the cryptographic and protocol level, and what role `codex-native-host` should play in our unified Native platform.

---

## 1. How Official Desktop Spawns & Configures Local `codex app-server`

### 1.1 Bundled Binary & Spawn Arguments (`early-bootstrap-920`)

- **Bundled Binary**: `/opt/codex-desktop/resources/codex` (`codex-linux-x64 0.167.0-alpha.3.2`, 85.4 MB static Rust binary).
- **Default Spawn Command (`ed.Lu0`)**:
  ```bash
  /opt/codex-desktop/resources/codex app-server --analytics-default-enabled
  ```
  with config overrides (`-c key=value`) injected for:
  - `plugins.codex-app-tools@openai-bundled.mcp_servers.codex_app.enabled=true` (when `pluginMcpConfigOverrides` is supported, `>= 0.145.0`)
  - `features.*` flags filtered by the connected `app-server` version (`d5Fp.hR`)
- **Environment Variables Injected into Child Process**:
  - `CODEX_HOME` (defaults to `~/.codex`)
  - `CODEX_CLI_PATH` (`/opt/codex-desktop/resources/codex`)
  - `CODEX_ELECTRON_RESOURCES_PATH` (`/opt/codex-desktop/resources`)
  - `CODEX_TECTONIC_PATH` (`/opt/codex-desktop/resources/tectonic`)
  - `CODEX_APP_TOOLS_PIPE_PATH` (local named pipe / unix domain socket for `codex-app-tools` MCP callbacks)
  - `PATH` prepended with `/opt/codex-desktop/resources` (providing bundled `rg` and `tectonic`).

---

## 2. Version-Gated Capability Matrix (`Ehlj` in `972499.b9f8eb2bc4.js`)

After receiving the `initialize` response (`userAgent` / `serverInfo.version`), ChatGPT Desktop evaluates semver compatibility via module `Ehlj` (`JF(version, capability)`). This table is the authoritative roadmap of `codex app-server` protocol evolution from `0.141.0` to `0.167.0-alpha.1`:

| Capability Name (`Ehlj`) | Min `app-server` Version | Protocol / Product Feature Unlocked |
| :--- | :--- | :--- |
| `threadTurnsList` | `0.141.0` | Cursor-paginated `thread/turns/list` (`sortDirection: "desc" \| "asc"`, `itemsView: "summary" \| "notLoaded"`). |
| `turnSource` | `0.142.0-alpha.3` | Distinguishes turn origin (`user`, `automation`, `delegation`, etc.). |
| `threadTimelineList` | `0.144.0` | `thread/timeline/list` (`limit: 500`) for fast turn/item skeleton loading. |
| `pluginMcpConfigOverrides` | `0.145.0` | Per-plugin MCP config key `plugins.<plugin>@<marketplace>.mcp_servers.<name>.enabled`. |
| `threadItemsList` | `0.147.0` | Item-level pagination `thread/items/list` (`limit`, `sortDirection`, `cursor`) inside a single turn! |
| `skillsConfigWriteScope` | `0.150.0` | Scoped `skills/config/write` (`user` vs `workspace`). |
| `guardianNativeMultiAgentHistory` | `0.152.0` | Native multi-agent subthread history tracking. |
| `threadStartAeon` | `0.156.0` | `thread/startAeon` RPC for Durable Cloud Work/Aeon sessions. |
| `preserveForkPrefix` | `0.157.0` | `features.multi_agent_v2.preserve_fork_prefix` support on `thread/fork`. |
| `asyncCompaction` / `outputTokenReplay` / `incrementalTools` / `skillCatalogDeltas` | `0.158.0` | Non-blocking context compaction, token replay, incremental tool streaming, and delta skill catalog updates. |
| `instantInterrupt` / `reasoningEffortUpdates` | `0.160.0` | Low-latency `turn/interrupt` and live mid-thread reasoning effort updates. |
| `compactionImageBudget` / `deferredToolWorldState` | `0.162.0` | Image token budgeting during compaction and deferred tool state. |
| `mcpOauthRefreshCoordination` / `recommendedPlugins` | `0.164.0` | Coordinated MCP OAuth token refresh and `plugin/list` recommendations. |
| `guardianV2StructuredConfig` | `0.165.0` | Structured JSON configuration for `guardianv2` safety reviewer. |
| `multiAgentWaitToolConfig` | `0.166.0` | `features.multi_agent_v2.wait_agent_enabled`. |
| `guardianV2DecisionsComparison` | `0.167.0-alpha.1` | Shadow/comparison evaluation for Guardian v2 approval decisions. |

---

## 3. Complete `codex app-server` JSON-RPC Method Surface (88 Methods)

Extracted from `.vite/build/early-bootstrap-920-C1369sJ4.js`, the official client exercises **88 distinct JSON-RPC methods** across 11 namespaces:

1. **Thread Lifecycle & Pagination (`thread/*` — 36 methods)**:
   - Creation & Resume: `thread/start`, `thread/startAeon`, `thread/resume`, `thread/fork`, `thread/unsubscribe`, `thread/loaded/list`
   - History & Pagination: `thread/read`, `thread/list`, `thread/turns/list`, `thread/items/list`, `thread/timeline/list`
   - Mutations: `thread/name/set`, `thread/metadata/update`, `thread/archive`, `thread/unarchive`, `thread/compact/start`, `thread/rollback`, `thread/BackgroundTerminals/clean`
   - Sub-surfaces: `thread/realtime/start`, `thread/realtime/appendAudio`, `thread/realtime/appendText`, `thread/realtime/stop`, `thread/shellCommand`
   - Server Notifications: `thread/started`, `thread/status/changed`, `thread/name/updated`, `thread/tokenUsage/updated`, `thread/archived`, `thread/unarchived`, `thread/closed`, `thread/compacted`
2. **Turn Lifecycle (`turn/*` — 6 methods)**:
   - Requests: `turn/start`, `turn/steer`, `turn/interrupt`
   - Notifications: `turn/started`, `turn/completed`, `turn/diff/updated`, `turn/plan/updated`
3. **Item Streaming & Approvals (`item/*` — 16 methods)**:
   - Notifications: `item/started`, `item/completed`, `item/agentMessage/delta`, `item/plan/delta`, `item/reasoning/summaryTextDelta`, `item/reasoning/summaryPartAdded`, `item/reasoning/textDelta`, `item/commandExecution/outputDelta`, `item/commandExecution/terminalInteraction`, `item/fileChange/outputDelta`, `item/mcpToolCall/progress`
   - Server -> Client Requests (Approvals / Elicitations): `item/commandExecution/requestApproval`, `item/fileChange/requestApproval`, `item/permissions/requestApproval`, `item/tool/requestUserInput`, `item/tool/call`
4. **Skills, Plugins, and MCP (`skills/*`, `plugin/*`, `mcpServer/*` — 12 methods)**:
   - `skills/list`, `skills/config/write`, `skills/changed`
   - `plugin/list`, `plugin/read`, `plugin/install`, `plugin/uninstall`
   - `config/mcpServer/reload`, `mcpServerStatus/list`, `mcpServer/oauth/login`, `mcpServer/oauth/login/completed`, `mcpServer/elicitation/request`
5. **Code Review, Search, Config, Account, and Exec (`18` methods)**:
   - `review/start`, `fuzzyFileSearch`, `fuzzyFileSearch/sessionStart`, `fuzzyFileSearch/sessionUpdate`, `fuzzyFileSearch/sessionStop`, `command/exec`, `command/exec/write`, `command/exec/resize`, `command/exec/terminate`, `config/read`, `config/value/write`, `config/batchWrite`, `configRequirements/read`, `account/read`, `account/login/start`, `account/login/cancel`, `account/logout`, `account/rateLimits/read`.

---

## 4. The 5 Official `app-server` Transports (`evZ` in `early-bootstrap-920`)

Function `evZ` (`early-bootstrap-920 @3666331`) selects the runtime transport based on `hostConfig`:

```mermaid
flowchart TD
  evZ["evZ(hostConfig) Transport Factory"]
  evZ -->|hostConfig.id === 'durable'<br/>(ei.ZJQ)| Durable["1. Durable Cloud Host (eph)<br/>WebSocket: wss://codex-cloud-backend.chatgpt.com/<br/>Headers: X-OpenAI-Product-Sku: codex | aeon"]
  evZ -->|hostConfig.kind === 'remote-control'<br/>(ei.mq / ecU)| RemoteCtrl["2. Official Remote Control (ecU)<br/>WebSocket: wss://chatgpt.com/backend-api/wham/remote/control/server<br/>Auth: remote-control-device-key.node + step_up_token"]
  evZ -->|hostConfig.kind === 'ssh'| SSH["3. SSH Remote Host (evv)<br/>[ssh-websocket-v0] tunnel to remote codex app-server"]
  evZ -->|hostConfig.kind === 'wsl'| WSL["4. WSL Host (evF)<br/>wsl.exe -d <distro> codex app-server"]
  evZ -->|hostConfig.kind === 'local'| Local["5. Local Process (ed.Lu0)<br/>Child process stdio JSONL"]
```

### 4.1 Deep Dive: How Official Remote Control (`ecU`) Works (`early-bootstrap-920 @4210000..4238000`)

Official Remote Control allows a mobile/remote client or desktop controller to drive a `codex app-server` instance running on another machine through OpenAI's cloud relay:

1. **OS-Protected Hardware Device Key (`remote-control-device-key.node`)**:
   - Calls `createDeviceKey("allow_os_protected_nonextractable")` to generate a non-extractable asymmetric keypair backed by the OS secure enclave / TPM / keyring.
2. **MFA Step-Up Enrollment (`/backend-api/codex/remote/control/client/enroll/start` & `/finish`)**:
   - Requires a recent (`< 300s`) OAuth `step_up_token` with scope `"codex.remote_control.enroll"`.
   - Registers the device's public key with OpenAI's backend and stores `deviceId` + `keyHandle` locally.
3. **Session Token Refresh (`/backend-api/codex/remote/control/client/refresh/start` & `/finish`)**:
   - Signs a server challenge with `signDeviceKeyChallenge` to obtain a short-lived `remote_control_token` with scope `"remote_control_controller_websocket"`.
4. **WebSocket Relay Connection (`wss://chatgpt.com/backend-api/wham/remote/control/server`)**:
   - Connects with header `x-codex-client-session-token: Bearer <remote_control_token>`.
   - Responds to inline WebSocket `device_key_challenge` frames with `{ type: "device_key_proof", signature }`.
   - Once authenticated, tunnels standard `codex app-server` JSON-RPC messages between the controller and the registered host environment (`env_id`).

---

## 5. Comparison: Official Remote Control vs `Codex-Native-Unoffical` Direct Host Bridge

| Dimension | Official Remote Control (`wham/remote/control`) | `Codex-Native-Unoffical` Direct Host Bridge (`codex-native-host`) |
| :--- | :--- | :--- |
| **Network Topology** | Cloud-relayed via `wss://chatgpt.com/backend-api/wham/remote/control/server`. | Direct LAN / Tailscale / WireGuard / SSH WebSocket to user's `codex-native-host`. |
| **Authentication** | Proprietary `remote-control-device-key.node` + OpenAI MFA `step_up_token` + cloud enrollment. | Explicit QR/token device pairing + authenticated resumable WebSocket (`seq`/`ack` replay buffer). |
| **Classification** | `PRIVATE_COMPATIBILITY` (High lock-in & MFA/attestation barrier for third-party clients). | `PUBLIC_SUPPORTED` (100% self-hosted, zero cloud relay dependency, works offline on LAN/VPN). |
| **Large Payload Handling** | Relies on app-server truncation + tokenized IPC. | Strips multi-MB `aggregatedOutput` in Rust before WebSocket/stdio, spools to disk, serves byte ranges via `host/output/readRange`. |

### 5.1 Strategic Decision for `codex-native-host`

1. **Keep Direct Host (`codex-native-host`) as Our Primary Desktop & Remote Runtime Bridge**:
   - Do **not** depend on `/backend-api/wham/remote/control/server` or `remote-control-device-key.node` for Android/Remote support. Our Direct Host bridge (`codex-native-host`) works over LAN/Tailscale without OpenAI MFA step-up tokens or proprietary N-API binaries, while preserving all `codex app-server` semantics.
2. **Adopt Official `app-server` Pagination & Capability Negotiation Inside `codex-native-host` and Dart**:
   - Upgrade our protocol adapter to use `thread/turns/list` (`limit: 5, sortDirection: "desc"`), `thread/items/list` (`limit: 2, sortDirection: "asc"` for opening user message anchoring), and `thread/timeline/list` when the connected `codex app-server` version satisfies `Ehlj` (`>= 0.147.0`), plus host-side canonical turn islands and viewport-protected eviction (`1,000 -> 500` items).
3. **Add First-Class SSH & WSL Host Transports**:
   - Just like official `evZ` supports `local`, `ssh`, and `wsl` hosts in `local_thread_catalog`, `codex-native-host` can spawn or tunnel to `ssh` and `wsl` `codex app-server` instances while exposing the exact same unified catalog and spool/range-read guarantees to Flutter.
