# Output Deferral (`deferOutput` & `outputDeferred`) and Multi-Version Stock Evidence

Date: 2026-11-10
Status: Complete (`LOCAL_SCHEMA` + `PUBLIC_SOURCE` + `STATIC_BUNDLE` + `DISPOSABLE_LIVE_PROBE`)
Scope: F24B independent schema, source, static bundle, and disposable live-probe comparison across installed stock `0.167.0-alpha.3.2`, official public stable `0.167.0`, official public alpha `0.169.0-alpha.7`, public `openai/codex` (`e7f32cf`, `d2b4d63`, `e1cc967`), and Official Codex Desktop (`26.1103.60933`, build `25894`).

---

## 1. Executive Summary & Binary Provenance

All measurements were collected from headless JSON-RPC probes using isolated disposable `/tmp` profiles and workspaces without modifying the repository's default runtime binary or application code. The packaged Native GUI was not launched against the external `0.167.0` or `0.169.0-alpha.7` binaries. The three stock `codex` binaries, the installed Desktop bundle, and the bundled Native Host remain distinct evidence sources:

| Artifact | Path | Reported Version / Build | Provenance / Tag Mapping | SHA-256 |
| --- | --- | --- | --- | --- |
| **Installed Desktop Stock Binary** | `/opt/codex-desktop/resources/codex` | `codex-cli 0.167.0-alpha.3.2` | Packaged inside installed Desktop package (local `pacman` `codex-desktop 2026.11.08.211600-1`; no public Git tag assumed) | `c8242fc9e1bac7c6d661a228cecfaf50e6db74da219e4a9ca8912827e11607f0` |
| **Official Public Stable Binary** | `/tmp/native-f24-public-stock.kHdq5U/codex` | `codex-cli 0.167.0` | Public tag `rust-v0.167.0` (`086ccc833bc9cf01024ad2dd6af7dbd421b6bf9a`) | `cdcb45aaa01d0f14e298985e09465aebccd47f64ecd298aea44814af7b62bbda` |
| **Official Public Alpha Binary** | `/tmp/native-f24-public-alpha.xQsk4m/codex` | `codex-cli 0.169.0-alpha.7` | Public tag `rust-v0.169.0-alpha.7` (`25da1b0cb5e876882f8b1fafe186cdfcf3c712cc`) | `b20e3a2f9a25ae9e4b29bfe68ef337757d818f85087ac701d745833894f04c7d` |
| **Measured Official Desktop Bundle** | `/opt/codex-desktop/resources/app.asar` | `26.1103.60933` (build `25894`) | Installed Electron bundle shipping `0.167.0-alpha.3.2` | `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14` |
| **Bundled Native Host** | `build/linux/x64/debug/bundle/codex-native-host` | Built from workspace base `94ac9d3` | Local debug bundle Host executable | `990c9e3af7d1a13e46cc5b2bb2233c9eac1330e2d697263ffdfffc67567ff474` |

### Key Conclusions

1. **Absence in `0.167.0-alpha.3.2` and `0.167.0` vs Presence in `0.169.0-alpha.7`**:
   - In both installed `0.167.0-alpha.3.2` (proven directly by its generated schemas and live RPC behavior) and official public stable `0.167.0` (whose tag `086ccc8` predates upstream [`e7f32cf`](https://github.com/openai/codex/commit/e7f32cf) `#59601` and [`d2b4d63`](https://github.com/openai/codex/commit/d2b4d63) `#60390`), generated schemas omit `deferOutput` and `outputDeferred` even with `--experimental`. At runtime, `ThreadItemsListParams` deserialization ignores unknown fields, so `deferOutput` requests succeed without error (even when `experimentalApi: false`) and return full inline outputs.
   - Public alpha `0.169.0-alpha.7` (`25da1b0`, which includes `e7f32cf` and `d2b4d63`, also present in `e1cc967`) implements both `deferOutput.commandExecution` and `deferOutput.mcpToolCall`.
2. **Schema & Capability Gating in `0.169.0-alpha.7`**:
   - In `0.169.0-alpha.7`, `stable/v2/ThreadItemsListParams.json` exposes `deferOutput: ThreadItemOutputDeferral | null` with an empty object schema (`{"properties": {}, "type": "object"}`) and no stable booleans, while `experimental/v2/ThreadItemsListParams.json` exposes `commandExecution` and `mcpToolCall` booleans and `experimental/v2/ThreadItemsListResponse.json` exposes outer `ThreadItemEntry.outputDeferred`.
   - On a connection initialized with `experimentalApi: false`, `0.169.0-alpha.7` accepts `deferOutput: null`, `{}`, `{"commandExecution": false, "mcpToolCall": false}`, and `{"unknownOption": true}`, but rejects `{"commandExecution": true}` or `{"mcpToolCall": true}` with JSON-RPC `-32600` (`"thread/items/list.deferOutput.<field> requires experimentalApi capability"`).
3. **Command & MCP Deferral Eligibility vs Fallback**:
   - Both deferral flags require a non-null `turnId` in `thread/items/list` and a recorded `completedAtMs` on the stored entry. Omitting `turnId` returns all items inline (`outputDeferred` omitted).
   - `commandExecution: true` defers only completed commands with `exitCode == 0` and nonempty `aggregatedOutput`, setting outer `outputDeferred: true` and `item.aggregatedOutput: null`. Non-zero exit codes and empty outputs stay inline.
   - `mcpToolCall: true` defers only completed, non-error MCP calls (`server != "codex_app"`) without app UI/resource metadata (`mcpAppResourceUri`, `mcpAppUi`, `appContext.resourceUri`), without `structuredContent` or `_meta`, whose `result.content` consists exclusively of unannotated 2-field `{"type": "text", "text": ...}` blocks (not starting after whitespace/BOM with `{`, `[`, ```` ``` ````, or `~~~`) with at least one nonempty text string. Eligible items return `outputDeferred: true` and `item.result.content: []` while preserving `appContext.connectorId`.
   - `thread/items/read` (experimental-only across all three binaries) returns the complete stored `ThreadItemEntry` (`outputDeferred` omitted). For MCP results that exceeded the 64 KiB history truncation limit at completion time, `thread/items/read` returns the saved bounded preview (`< 64 KiB`), not the pre-truncation wire payload.
4. **Official Desktop Bundle & Native Scope Boundary**:
   - Measured Desktop `26.1103.60933` (`app.asar`) contains `0` string occurrences of `deferOutput`, `0` occurrences of `outputDeferred`, and `0` occurrences of `thread/items/read`, alongside `28` static string occurrences of `thread/items/list`.
   - Codex Native currently sends `deferOutput: {'commandExecution': true}` on `thread/items/list`, spools non-null `aggregatedOutput` into `_codexNativeOutput` via `codex-native-host`, and reads `ThreadItemEntry.outputDeferred` for `commandExecution` items with on-demand `thread/items/read` fallback. Native does not request `deferOutput.mcpToolCall`, does not spool MCP `result.content` in `codex-native-host`, and does not project MCP result bodies in `HistoryProtocolAdapter`.

---

## 2. Generated Schema & Method Inventory Comparison (`LOCAL_SCHEMA`)

Generated directly from each binary via `<codex> app-server generate-json-schema [--experimental] --out <dir>`:

| Dimension | Installed `0.167.0-alpha.3.2` | Public Stable `0.167.0` | Public Alpha `0.169.0-alpha.7` |
| --- | --- | --- | --- |
| **`ClientRequest` (stable + experimental-only = total)** | `106 + 74 = 180` | `106 + 74 = 180` | `109 + 74 = 183` |
| **`ServerRequest` (stable + experimental-only = total)** | `10 + 1 = 11` (`currentTime/read` exp) | `10 + 1 = 11` (`currentTime/read` exp) | `10 + 1 = 11` (`currentTime/read` exp) |
| **`ServerNotification` (stable / experimental)** | `86 / 86` | `86 / 86` | `86 / 86` |
| **`ClientNotification` (stable / experimental)** | `1 / 1` (`initialized`) | `1 / 1` (`initialized`) | `1 / 1` (`initialized`) |
| **New stable `ClientRequest` methods vs `0.167.0`** | — | None (`0` diff vs `0.167.0-alpha.3.2`) | `account/securitySetup/read`, `modelProvider/list`, `modelProvider/config/write` |
| **`ThreadItemsListParams.deferOutput` (stable)** | Absent | Absent | Present: `ThreadItemOutputDeferral \| null` (`properties: {}`) |
| **`ThreadItemsListParams.deferOutput` (`--experimental`)** | Absent | Absent | Present: `commandExecution?: boolean`, `mcpToolCall?: boolean` |
| **`ThreadItemEntry.outputDeferred` (stable)** | Absent | Absent | Absent |
| **`ThreadItemEntry.outputDeferred` (`--experimental`)** | Absent | Absent | Present on `ThreadItemsListResponse` & `ThreadItemsReadResponse` |
| **`thread/items/read` schema gate** | Experimental-only | Experimental-only | Experimental-only |

### New Stable Routes in `0.169.0-alpha.7` (`LOCAL_SCHEMA` + Read-Only `DISPOSABLE_LIVE_PROBE`)

- `account/securitySetup/read` (`params: null` -> `GetAccountSecuritySetupResponse { notice: AccountSecuritySetupNotice | null }`): on an unauthenticated disposable profile with `experimentalApi: false`, `0.169.0-alpha.7` returned `{"notice": null}`, whereas `0.167.0-alpha.3.2` and `0.167.0` returned `-32600` (`unknown variant`).
- `modelProvider/list` (`ModelProviderListParams {}` -> `ModelProviderListResponse { canChangeDefault, data: ModelProviderSummary[], defaultProviderId }`): with `experimentalApi: false`, `0.169.0-alpha.7` returned `{"data": [{"id": "openai", "name": "OpenAI", "canEdit": false, "baseUrl": null, "settings": {"type": "openai"}}], "defaultProviderId": "openai", "canChangeDefault": true}`, whereas `0.167.0-alpha.3.2` and `0.167.0` returned `-32600` (`unknown variant`).
- `modelProvider/config/write` (`LOCAL_SCHEMA` only; not live-called): in `stable/v2/ModelProviderConfigWriteParams.json`, the request requires `{ settings: ProviderSettingsPatch }` (`required: ["settings"]`, `additionalProperties: false`), where `ProviderSettingsPatch` is a `oneOf` union over three `"type"` discriminators only:
  - `"customGateway"` (`CustomGatewayProviderSettingsPatch`: required `"type"`, optional `"providerId"`, `"name"`, `"baseUrl"`, `"envKey"`),
  - `"bedrock"` (`BedrockProviderSettingsPatch`: required `"type"` and `"providerId"` in `["amazon-bedrock", "amazon-bedrock-runtime"]`, optional `"profile"`, `"region"`), and
  - `"gcp"` (`GcpProviderSettingsPatch`: required `"type"` and `"providerId"` `"gcp"`, optional `"credentialFile"`, `"location"`, `"projectId"`).
  There is no `"openai"` patch variant in `ProviderSettingsPatch`. `stable/v2/ModelProviderConfigWriteResponse.json` requires `{ provider: ModelProviderSummary }` (`required: ["provider"]`).

---

## 3. Upstream Source Contract (`PUBLIC_SOURCE`)

Cross-referenced against public `openai/codex` commits [`e7f32cf`](https://github.com/openai/codex/commit/e7f32cf) (`#59601`) and [`d2b4d63`](https://github.com/openai/codex/commit/d2b4d63) (`#60390`, ancestor of `0.169.0-alpha.7` `25da1b0` and `e1cc967`):

1. **Request & Turn-Scope Gate (`codex-rs/app-server/src/request_processors/thread_processor.rs`)**:
   - `let defer_output = defer_output.filter(|_| turn_id.is_some());`
   - Deferral runs only during `thread/items/list` when **both** `params.turn_id.is_some()` and `entry.completed_at_ms.is_some()` hold. Thread-wide `thread/items/list` calls (`turnId: null`) never defer output.
2. **Command Output Deferral (`defer_item_output` -> `ThreadItemPayload::CommandExecution`)**:
   - Requires `options.command_execution == true`, `status == CommandExecutionStatus::Completed`, `exit_code == Some(0)`, and `aggregated_output.as_ref().is_some_and(|output| !output.is_empty())`.
   - Mutates the listed entry in place: `*aggregated_output = None` and `entry.output_deferred = true`.
3. **Plain-Text MCP Output Deferral (`defer_item_output` -> `ThreadItemPayload::McpToolCall`)**:
   - Requires `options.mcp_tool_call == true`, `server != "codex_app"`, `status == McpToolCallStatus::Completed`, `result: Some(result)`, `error: None`, `app_context.as_ref().is_none_or(|ctx| ctx.resource_uri.is_none())`, `mcp_app_resource_uri: None`, and `mcp_app_ui: None`.
   - `is_deferrable_mcp_result(result)` requires `result.structured_content.is_none()`, `result.meta.is_none()`, at least one nonempty text block, and every block in `result.content` to satisfy `codex_protocol::mcp::plain_output_text(block)`:
     - Block must be a JSON object with **exactly 2 fields** (`fields.len() == 2`) where `"type" == "text"` and `"text"` is a string (any extra field such as `"annotations"` fails the 2-field check).
     - After stripping leading whitespace and UTF-8 BOM (`ch.is_whitespace() || ch == '\u{feff}'`), the text must **not** start with `'{'`, `'['`, `'```'`, or `'~~~'`.
   - Mutates the listed entry in place: `result.content.clear()` (`[]`) and `entry.output_deferred = true`, while preserving `appContext` (`connectorId`, `linkId`) on the item.
4. **Interaction with 64 KiB History Truncation (`codex-rs/utils/output-truncation/src/lib.rs`)**:
   - At turn execution time, `truncate_mcp_tool_result` caps persisted MCP tool results to 64 KiB (`65,536` bytes).
   - Prior to `d2b4d63` (including `0.167.0-alpha.3.2` and `0.167.0`), `truncate_mcp_tool_result` serialized the entire `CallToolResult` struct via `serde_json::to_string(result)` (`{"content":[{"type":"text","text":"..."}],...}`) before slicing the preview into a text block.
   - Commit `d2b4d63` changed `truncate_mcp_tool_result` so that when a non-error MCP result has no `structured_content` or `meta` and all content blocks pass `plain_output_text`, the truncated preview is formatted as `"Truncated tool output:\n<plain text...>"` instead of JSON. This keeps the saved 64 KiB preview eligible for `deferOutput.mcpToolCall`, and `thread/items/read` returns that bounded preview.

---

## 4. Official Desktop Bundle Audit (`STATIC_BUNDLE`)

Audited `/opt/codex-desktop/resources/app.asar` (`26.1103.60933`, build `25894`, SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`):

| Search Token | Static String Occurrences in `app.asar` | Observed Bundle Behavior |
| --- | --- | --- |
| `deferOutput` | `0` | Not present anywhere in the renderer, preload, or main-process bundles. |
| `outputDeferred` | `0` | Not present; entry-unwrapping helpers at byte offsets `8571419` and `109614177` extract the nested `item` object and copy `startedAtMs` while tracking `completedAtMs` IDs, ignoring any `outputDeferred` property on the outer entry. |
| `thread/items/read` | `0` | Not registered in method tables or invoked by timeline hydration. |
| `thread/items/list` | `28` string occurrences | Spans method allowlists/routing tables (offsets `11624615`, `11625331`, `11627739`, `11628481`, `14336879`, `110784365`), error-message templates, and pagination/hydration helpers (offsets `8571081–8573863`, `8652624–8652817`, `8716884`, `9033750`, `109613839`, `109751921`, `110026974`, `142927953`, `224411186–224412270`). The pagination wrappers pass `{threadId, turnId, limit, sortDirection, cursor}` with default page size `100` and retry with halved integer page sizes when the server returns an oversized-response error. |

---

## 5. Disposable Loopback Live Probe Evidence (`DISPOSABLE_LIVE_PROBE`)

A disposable headless loopback fixture was executed through the bundled Host (`build/linux/x64/debug/bundle/codex-native-host --codex <binary>`, SHA-256 `990c9e3af7d1a13e46cc5b2bb2233c9eac1330e2d697263ffdfffc67567ff474`) against each of the three stock binaries using an isolated `/tmp` `HOME`, `CODEX_HOME`, and `--cache-dir`, a loopback HTTP `/v1/responses` SSE server on `127.0.0.1`, and local stdio MCP servers (`fixture_mcp` plus a separate `codex_app` server probe). All temporary directories and child processes were terminated and deleted immediately after each run.

### 5.1 Capability Gate & Request Option Matrix (`thread/items/list` & `thread/items/read`)

| Request / Option (with valid `turnId`) | Connection `experimentalApi` | `0.167.0-alpha.3.2` & `0.167.0` Observed Result | `0.169.0-alpha.7` Observed Result |
| --- | --- | --- | --- |
| `deferOutput` omitted / `null` / `{}` | `false` or `true` | Succeeded; `0` items deferred | Succeeded; `0` items deferred |
| `deferOutput: {"commandExecution": false, "mcpToolCall": false}` | `false` or `true` | Succeeded; `0` items deferred | Succeeded; `0` items deferred |
| `deferOutput: {"unknownOption": true}` | `false` or `true` | Succeeded; `0` items deferred | Succeeded; unknown field ignored, `0` items deferred |
| `deferOutput: {"commandExecution": true}` | `false` | **Succeeded** (unknown field ignored by `0.167.0`; `0` items deferred) | **Rejected**: `-32600` `"thread/items/list.deferOutput.commandExecution requires experimentalApi capability"` |
| `deferOutput: {"mcpToolCall": true}` | `false` | **Succeeded** (unknown field ignored by `0.167.0`; `0` items deferred) | **Rejected**: `-32600` `"thread/items/list.deferOutput.mcpToolCall requires experimentalApi capability"` |
| `deferOutput: {"commandExecution": true}` | `true` | Succeeded, but **`0` items deferred** (full output inline) | Succeeded; eligible exit-`0` nonempty commands deferred (`outputDeferred: true`, `aggregatedOutput: null`) |
| `deferOutput: {"mcpToolCall": true}` | `true` | Succeeded, but **`0` items deferred** (full output inline) | Succeeded; eligible plain-text MCP items deferred (`outputDeferred: true`, `result.content: []`) |
| `deferOutput: {"commandExecution": true, "mcpToolCall": true}` with **`turnId` omitted** | `true` | Succeeded; `0` items deferred | Succeeded; **`0` items deferred** (`turnId` required for deferral) |
| `thread/items/read` (`itemIds: [...]`) | `false` | **Rejected**: `-32600` `"thread/items/read requires experimentalApi capability"` | **Rejected**: `-32600` `"thread/items/read requires experimentalApi capability"` |
| `thread/items/read` (`itemIds: [...]`) | `true` | Succeeded; returns full `ThreadItemEntry[]` | Succeeded; returns full `ThreadItemEntry[]` with saved output restored and `outputDeferred` omitted |

### 5.2 Per-Item Eligibility, Fallback, and Host Spooling Matrix (`experimentalApi: true`, `turnId` set)

In the 16-item turn seeded via the loopback Responses server + `codex_app` probe, `thread/items/list` with `deferOutput: {"commandExecution": true, "mcpToolCall": true}` and subsequent `thread/items/read` produced:

| Fixture Item | Wire Input / Tool Result Shape | `0.167.0-alpha.3.2` & `0.167.0` (`both_defer`) | `0.169.0-alpha.7` (`cmd_defer` only) | `0.169.0-alpha.7` (`mcp_defer` only) | `0.169.0-alpha.7` (`both_defer`) | `0.169.0-alpha.7` `thread/items/read` Readback |
| --- | --- | --- | --- | --- | --- | --- |
| **`cmd-ok-nonempty`** | `printf 'alpha-command-output-line1\n...'` (`exitCode: 0`, nonempty) | `outputDeferred: false`, spooled (`_codexNativeOutput` present) | **`outputDeferred: true`**, `aggregatedOutput: null`, **not spooled on list** | `outputDeferred: false`, spooled (`_codexNativeOutput` present) | **`outputDeferred: true`**, `aggregatedOutput: null`, **not spooled on list** | Restores output; `codex-native-host` spools `aggregatedOutput` into `_codexNativeOutput` on read |
| **`cmd-fail-nonempty`** | `printf 'failing-command-stderr\n' && exit 7` (`exitCode: 7`, nonempty) | `outputDeferred: false`, spooled | `outputDeferred: false`, stays inline & spooled | `outputDeferred: false`, stays inline & spooled | `outputDeferred: false`, stays inline & spooled | Returns same completed entry with spooled output |
| **`cmd-ok-empty`** | `true` (`exitCode: 0`, empty output) | `outputDeferred: false`, `spool: false` | `outputDeferred: false`, `spool: false` | `outputDeferred: false`, `spool: false` | `outputDeferred: false`, `spool: false` | Returns same entry (`aggregatedOutput: null`) |
| **`mcp-plain-nonempty`** | `content: [{"type": "text", "text": "plain text mcp result body"}]` (`26` chars) | `outputDeferred: false`, `content_blocks: 1` (`26` chars) | `outputDeferred: false`, `content_blocks: 1` (`26` chars) | **`outputDeferred: true`**, `result.content: []` | **`outputDeferred: true`**, `result.content: []` | Restores `result.content` (`1` block, `26` chars) |
| **`mcp-plain-oversized`** | `("é" * 40960) + "\nTAIL_MARKER_PLAIN"` (`> 80 KiB` UTF-8) | `outputDeferred: false`, `content_blocks: 1` (`32,780` chars, `65,468` B JSON preview) | `outputDeferred: false`, `content_blocks: 1` (`32,769` chars, `65,479` B plain preview) | **`outputDeferred: true`**, `result.content: []` | **`outputDeferred: true`**, `result.content: []` | Restores saved 64 KiB plain preview (`32,769` chars starting with `"Truncated tool output:\n..."` and ending with `"TAIL_MARKER_PLAIN"`) |
| **`mcp-codex-app`** | `server: "codex_app"`, `tool: "read_thread_terminal"`, plain text (`36` chars) | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, stays inline (`content_blocks: 1`) | `outputDeferred: false`, stays inline (`content_blocks: 1`) | Returns same inline entry |
| **`mcp-json-text`** | `text: "\ufeff {\"structured\":\"json_in_text\"}"` (`31` chars) | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, stays inline (`content_blocks: 1`) | `outputDeferred: false`, stays inline (`content_blocks: 1`) | Returns same inline entry |
| **`mcp-fenced-text`** | ````text: "```json\n{\"fenced\":true}\n```"```` (`27` chars) | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, stays inline (`content_blocks: 1`) | `outputDeferred: false`, stays inline (`content_blocks: 1`) | Returns same inline entry |
| **`mcp-tilde-fence`** | `text: "~~~markdown\nhello\n~~~"` (`21` chars) | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, stays inline (`content_blocks: 1`) | `outputDeferred: false`, stays inline (`content_blocks: 1`) | Returns same inline entry |
| **`mcp-structured`** | Plain text + `structuredContent: {"key": "val"}` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, stays inline (`content_blocks: 1`) | `outputDeferred: false`, stays inline (`content_blocks: 1`) | Returns same inline entry |
| **`mcp-meta`** | Plain text + `_meta: {"uri": "ui://panel"}` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, stays inline (`content_blocks: 1`) | `outputDeferred: false`, stays inline (`content_blocks: 1`) | Returns same inline entry |
| **`mcp-annotated`** | Text block with `"annotations": {"audience": ["user"]}` (`3` keys) | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, stays inline (`content_blocks: 1`) | `outputDeferred: false`, stays inline (`content_blocks: 1`) | Returns same inline entry |
| **`mcp-image`** | Text block + `{"type": "image", "mimeType": "image/png", "data": "YQ=="}` | `outputDeferred: false`, `content_blocks: 2` | `outputDeferred: false`, `content_blocks: 2` | `outputDeferred: false`, stays inline (`content_blocks: 2`) | `outputDeferred: false`, stays inline (`content_blocks: 2`) | Returns same inline entry |
| **`mcp-error`** | `isError: true` (`status: "failed"`, `error: {"message": ...}`) | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, stays inline (`content_blocks: 1`) | `outputDeferred: false`, stays inline (`content_blocks: 1`) | Returns same inline entry |
| **`mcp-empty`** | `content: [{"type": "text", "text": ""}]` (`0` chars) | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, `content_blocks: 1` | `outputDeferred: false`, stays inline (`content_blocks: 1`) | `outputDeferred: false`, stays inline (`content_blocks: 1`) | Returns same inline entry |

### 5.3 Cross-Version Rollout Truncation Observation (`0.167.0-alpha.3.2` Writer -> `0.169.0-alpha.7` Reader)

When a disposable thread was seeded under `0.167.0-alpha.3.2` with both a short plain-text MCP call (`"short plain text"`) and an oversized plain-text MCP call (`> 80 KiB` UTF-8) and then listed cold under `0.169.0-alpha.7` with `deferOutput: {"mcpToolCall": true}`:

- The **short** `0.167.0-alpha.3.2`-persisted MCP item returned `outputDeferred: true` and `result.content: []`.
- The **oversized** (`> 64 KiB`) `0.167.0-alpha.3.2`-persisted MCP item returned `outputDeferred: false` (`content_len: 1`) and remained inline. Because `0.167.0-alpha.3.2` persisted the 64 KiB truncated preview as serialized JSON (`{"content":[{"type":"text","text":"..."}],"isError":false}`), `0.169.0-alpha.7`'s `plain_output_text` classified the saved preview as JSON (`starts_with('{')`) and excluded it from deferral.

### 5.4 Reproducible Fixture Recipe

1. **Isolated Profile & Loopback Endpoints**:
   - Create a temporary directory `/tmp/codex_f24b_probe_<id>` with subdirectories `codex-home` and `host-cache`, and delete it on exit.
   - Bind an HTTP server on `127.0.0.1:0` handling `POST /v1/responses` with `Content-Type: text/event-stream`.
   - Write `codex-home/config.toml` pointing `model_provider = "loopback"` (`base_url = "http://127.0.0.1:<port>/v1"`, `wire_api = "responses"`, `supports_websockets = false`) and registering `[mcp_servers.fixture_mcp]` (and optionally `[mcp_servers.codex_app]`) as a local stdio script.
2. **Seed Turn via Bundled Host**:
   - Spawn `build/linux/x64/debug/bundle/codex-native-host --codex <binary>` with `HOME`, `CODEX_HOME`, and `CODEX_NATIVE_CACHE_DIR` pointed at the disposable directory.
   - Send `initialize` with `{"capabilities": {"experimentalApi": true}}`, followed by `initialized`, `thread/start` (`approvalPolicy: "never"`, `sandbox: "danger-full-access"` in this probe; `sandbox: "read-only"` also suffices for the read-only `printf` / `true` / `exit 7` command cases), and `turn/start`.
   - On the first `/v1/responses` call, emit `response.created`, one `response.output_item.done` event per `function_call` item (`name: "exec_command"` with `arguments: "{\"cmd\":\"...\",\"login\":false,\"tty\":false}"` for command cases; `name: "fixture_tool"`, `namespace: "mcp__fixture_mcp"` with `arguments: "{\"case\":\"...\"}"` for MCP cases), and `response.completed`.
   - On the second `/v1/responses` call (after tool outputs are submitted), emit a terminal assistant `message` item and `response.completed`, then wait for the `turn/completed` notification and shut down the child process.
3. **Cold Relist & Single-Item Readback**:
   - Respawn `codex-native-host --codex <binary>` against the same `CODEX_HOME`:
     - Initialize with `experimentalApi: false`: on `0.169.0-alpha.7`, verify JSON-RPC `-32600` capability rejection on `deferOutput: {"commandExecution": true}`, `deferOutput: {"mcpToolCall": true}`, and `thread/items/read`, and normal JSON-RPC result acceptance on `null`, `{}`, `false`, and unknown fields (whereas `0.167.0-alpha.3.2` and `0.167.0` ignore `deferOutput` and reject only `thread/items/read` with `-32600`).
     - Initialize with `experimentalApi: true` and call `thread/items/list` (`threadId`, `turnId`, `limit: 100`) across `deferOutput` variants (`{"commandExecution": true}`, `{"mcpToolCall": true}`, `{"commandExecution": true, "mcpToolCall": true}`) plus with `turnId` omitted.
     - For each entry with `outputDeferred == true`, call `thread/items/read` (`{"threadId": threadId, "turnId": turnId, "itemIds": [itemId]}`) and verify that `data[0]` restores the saved `aggregatedOutput` (spooled into `_codexNativeOutput` by `codex-native-host`) or `result.content` (`outputDeferred` omitted).

---

## 6. Architecture & Native Integration Boundary

1. **Command Execution Deferral & Host Spool Coexistence**:
   - In `Codex Native` (`lib/src/protocol/history_protocol.dart:127-164`), `HistoryProtocolAdapter.listItems()` sends `'deferOutput': const {'commandExecution': true}` with a required `turnId` and reads outer `ThreadItemEntry.outputDeferred`.
   - Against `0.167.0-alpha.3.2` and `0.167.0`, `deferOutput` is ignored by stock, `aggregatedOutput` arrives inline on `thread/items/list`, and `codex-native-host` (`native_host/src/transform.rs`, `TARGET_KEY = b"aggregatedOutput"`) spools it immediately into `_codexNativeOutput` so large command output still stays off the Flutter heap.
   - Against `0.169.0-alpha.7`, eligible completed exit-`0` commands omit `aggregatedOutput` (`null`) during `thread/items/list` and set `outputDeferred: true`, avoiding even Host spool writes until the user expands/requests output via `HistoryController.loadDeferredOutput()`, which calls `thread/items/read` and triggers `codex-native-host` spooling for only that single requested item.
   - Because `0.169.0-alpha.7` gates `deferOutput.commandExecution: true` on `experimentalApi: true` (`-32600` when `experimentalApi: false`), any local `thread/items/list` caller sending `deferOutput: {'commandExecution': true}` must initialize with `experimentalApi: true` (which `InitializeRequest` in `lib/src/protocol/protocol_models.dart` already enables by default).
2. **MCP Output Deferral Boundary (No Lazy-Parity Claim)**:
   - Stock caps persisted MCP results at 64 KiB at completion time, and `deferOutput.mcpToolCall` omits only eligible completed plain-text MCP results while keeping JSON-prefixed, fenced, annotated, structured, `_meta`, image, `codex_app`, error, and pre-`d2b4d63` truncated-preview MCP results inline.
   - `codex-native-host` currently spools only `"aggregatedOutput"` (not MCP `result.content`), and `HistoryProtocolAdapter._parseItem` currently projects `mcpToolCall` items as compact `'MCP: <server>/<tool>'` activity rows without retaining `result.content` or exposing a per-MCP-item `thread/items/read` viewer. Adding MCP history result inspection in a future slice should therefore bound inline MCP result parsing independently rather than assuming `deferOutput.mcpToolCall` defers all MCP payloads.
