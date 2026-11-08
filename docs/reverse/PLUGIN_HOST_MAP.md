# ChatGPT Desktop Plugin, Skill, MCP & Skybridge Host Map (Recalibrated)

> **Evidence Sources**:
> - `STATIC_BUNDLE`: `/opt/codex-desktop/resources/plugins/openai-bundled/` (`marketplace.json`, 17 `.codex-plugin/plugin.json` manifests, `.mcp.json` configs, and 33 `SKILL.md` files) inspected via `python3 tools/reverse/inspect_chatgpt_desktop.py --plugins`, plus `.vite/build/early-bootstrap-920-a204a41244c4b913.js` (`@2193000..2201500`) and `webview/assets/async/182735.d3d917f28d.js`.
> - `PUBLIC_SOURCE`: Stock `/opt/codex-desktop/resources/codex app-server generate-json-schema` (`0.167.0-alpha.3.2`) for `plugin/*`, `skills/*`, `mcpServer/*`, and `apps/*` RPCs.

---

## 0. Evidence & Support Classification Matrix

| Capability / Surface | Evidence Tags | Stock `app-server` Schema Status (`0.167.0-alpha.3.2`) | Support Classification |
|---|---|---|---|
| **Plugin Management RPCs** (`plugin/list`, `plugin/read`, `plugin/install`, `plugin/installed`, `plugin/uninstall`, `plugin/reconcile`, `plugin/skill/read`, `plugin/share/*`, `plugin/search`) | `PUBLIC_SOURCE`, `STATIC_BUNDLE` | Stable (`12` methods including `list`, `read`, `install`, `uninstall`, `reconcile`, `skill/read`, `share/*`) + Experimental-only (`plugin/search`) | **`PUBLIC_SUPPORTED`** (core) / **`EXPERIMENTAL_STOCK_SCHEMA`** (`plugin/search`) |
| **Skills Management RPCs** (`skills/list`, `skills/config/write`, `skills/extraRoots/set` + notification `skills/changed`) | `PUBLIC_SOURCE`, `STATIC_BUNDLE` | All `3` `ClientRequest` methods + `skills/changed` notification are **Stable** in `0.167.0-alpha.3.2` (legacy `skills/remote/*` removed from stock schema) | **`PUBLIC_SUPPORTED`** |
| **MCP Server RPCs** (`config/mcpServer/reload`, `mcpServer/oauth/login`, `mcpServerStatus/list`, `mcpServer/resource/read`, `mcpServer/tool/call`, `mcpServer/elicitation/request`, `mcpServer/event/stream/*`) | `PUBLIC_SOURCE`, `STATIC_BUNDLE` | Stable (`reload`, `oauth/login`, `mcpServerStatus/list`, `resource/read`, `tool/call`, plus stable `ServerRequest` `elicitation/request`) + Experimental-only (`event/stream/start`, `event/stream/stop`) | **`PUBLIC_SUPPORTED`** (all core & resource/elicitation RPCs) / **`EXPERIMENTAL_STOCK_SCHEMA`** (`event/stream/*`) |
| **Apps / Connectors RPCs** (`app/list`, `app/installed`, `app/read`) | `PUBLIC_SOURCE`, `STATIC_BUNDLE` | All `3` singular `app/*` `ClientRequest` methods are **Stable** in `0.167.0-alpha.3.2` | **`PUBLIC_SUPPORTED`** |
| **Desktop Internal MCP Servers** (`openai_artifact_template_picker`, `codex_app` thread/sidebar/worktree tools) | `STATIC_BUNDLE` (`early-bootstrap-920 @2193000..2201500`) | Injected by Desktop Main Process via `buildMcpCodexConfig` | **`PRIVATE_INTERNAL_SERVICE`** (Desktop-specific MCP sidecar) |
| **Skybridge (`ui://` MCP Apps Iframe Bridge)** | `STATIC_BUNDLE` (`webview/assets/async/182735.d3d917f28d.js`), `PUBLIC_SOURCE` (`mcpServer/resource/read`) | Stock `mcpServer/resource/read` is **Stable** (`PUBLIC_SUPPORTED`); renderer `ui://` postMessage iframe is a client UI host layer | **`ADOPT_PATTERN`** (Optional WebView host only when required, per `AGENTS.md` Rule #5) |

---

## 1. Bundled Marketplace & Plugin Manifest Architecture (`STATIC_BUNDLE` + `PUBLIC_SOURCE`)

Located at `/opt/codex-desktop/resources/plugins/openai-bundled/`:
- **Marketplace Index**: `.agents/plugins/marketplace.json` (`name: "openai-bundled"`, `17` plugins).
- **Per-Plugin Structure**:
  ```text
  plugins/<plugin-name>/
    .codex-plugin/plugin.json   # name, version, description, author, interface metadata
    .mcp.json                   # optional MCP server definitions (stdio or HTTP/SSE)
    .app.json                   # optional ChatGPT App / connector ID binding
    skills/<skill-name>/SKILL.md # YAML frontmatter + Markdown instructions & scripts
  ```
- **17 Bundled Plugins Verified via `--plugins`**:
  `agent-browser`, `asana`, `build-ios-apps`, `canva`, `cloudflare`, `figma`, `github`, `gmail`, `google-calendar`, `google-drive`, `linear`, `notion`, `openai-docs`, `pdf`, `playwright`, ` slack`, `vercel` (totalling **33 bundled skills**).

---

## 2. Desktop-Injected Internal MCP Servers (`STATIC_BUNDLE` `@2193000..2201500`)

In `.vite/build/early-bootstrap-920-a204a41244c4b913.js`, `_o.buildMcpCodexConfig` (`@2200200`) and `_s` (`@2193200`) dynamically inject Desktop-managed MCP servers into `codex app-server` configuration when starting local/Work threads:

1. **`mcp_servers.openai_artifact_template_picker`**:
   - Spawns bundled Node script `artifact-template-picker/server.mjs` with env `CODEX_ARTIFACT_TEMPLATE_SKILLS` (capped at `100` template skills / `24 KB` JSON payload) to provide slide/sheet/document templates in Work mode.
2. **Desktop App MCP (`mcp__codex_app__*`)**:
   - Exposes desktop workspace/sidebar/thread coordination tools (`create_thread`, `send_message_to_thread`, `handoff_thread`, `fork_thread`, `list_threads`, `create_worktree`, `archive_worktree`, `load_workspace_dependencies`).
   - Note: For `Codex-Native-Unoffical`, core plugin/skill/MCP support should rely on stock `codex app-server`'s native `plugin/*`, `skills/*`, and `mcpServerStatus/list` RPCs (`PUBLIC_SUPPORTED`) rather than bundling Node sidecars (`AGENTS.md` Rule #5: *"No Electron or Node requirement for the core client"*).

---

## 3. Skybridge (`ui://` MCP Apps Iframe Protocol — `STATIC_BUNDLE` + `PUBLIC_SOURCE`)

When an MCP tool returns a resource URI with scheme `ui://`, the protocol boundary separates into two distinct layers:

1. **Layer A — Stock `codex app-server` Resource & Tool RPCs (`PUBLIC_SUPPORTED` Stable in `0.167.0-alpha.3.2`)**:
   - `mcpServer/resource/read`: Stable `ClientRequest` (`McpResourceReadParams`: required `server: string`, `uri: string`; optional `threadId`, `connectorId`, `originCallId`, `target: { connectorId: string, linkId: string | null }`). Returns `McpResourceReadResponse` (`contents: Array<{ uri: string, mimeType?: string | null, text: string } | { uri: string, mimeType?: string | null, blob: string }>`, optional `originCallId`).
   - `mcpServer/tool/call`: Stable `ClientRequest` (`McpServerToolCallParams`: `server`, `tool`, `arguments`).
   - `mcpServer/elicitation/request`: Stable `ServerRequest` (`McpServerElicitationRequestParams` -> `McpServerElicitationRequestResponse`).
2. **Layer B — Renderer Sandboxed Iframe Bridge (`Skybridge`, `STATIC_BUNDLE`)**:
   - ChatGPT Desktop renders a sandboxed iframe (`Skybridge` in `webview/assets/async/182735.d3d917f28d.js`) that communicates via JSON-RPC 2.0 over `window.postMessage`:
   - **Initialization & Lifecycle**: `ui/initialize`, `ui/notifications/initialized`, `ui/notifications/size-changed`, `ui/notifications/tool-input`, `ui/notifications/tool-result`, `ui/notifications/host-context-changed`, `ui/resource-teardown`.
   - **Host Capability Methods (`openai/*` / `tools/call`)**:
     - `tools/call` (invoke an MCP tool from the widget via `mcpServer/tool/call`)
     - `openai/sendFollowUpMessage` (insert/send a follow-up prompt)
     - `openai/uploadFile` & `openai/getFileDownloadUrl`
     - `openai/requestDisplayMode` (`inline | pip | fullscreen`)
     - `openai/setWidgetState` (persist bounded widget state on the turn item)
     - `openai/requestModal` & `openai/requestClose`
     - `openai/openExternal` (`ui/open-link`)
- **Policy & Reclassification for `Codex-Native-Unoffical`**:
  - Layer A (`mcpServer/resource/read`, `mcpServer/tool/call`, `mcpServer/elicitation/request`, plus `app/list`, `app/installed`, `app/read` and `config/mcpServer/reload`) is `PUBLIC_SUPPORTED` stable schema in `0.167.0-alpha.3.2`. Because Native `HEAD` currently implements only `mcpServerStatus/list`, `plugin/list`, `skills/list`, and `skills/config/write`, these independent stable protocol surfaces are classified as `MISSING` / `PARTIAL` and queued in the active `READY` backlog (`OFFICIAL_FEATURE_MATRIX.md` §3.1).
  - Layer B (`ui://` WebView host) is classified as `RESEARCH_EXHAUSTED` / `DEFERRED_OPTIONAL_WEBVIEW` per `AGENTS.md` Rule #5 (*"No Electron or Node requirement for the core client. Optional plugin web UI may use a system/embedded WebView later, only when required"*). Core client needs no WebView until a user-configured third-party MCP server actively emits `ui://` interactive widget resources.
