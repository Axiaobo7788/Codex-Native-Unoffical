# Model Provider Discovery, Config Write Boundaries, and Account Security Setup Evidence

Date: 2026-11-10
Status: Complete (`LOCAL_SCHEMA` + `PUBLIC_SOURCE` + `STATIC_BUNDLE` + `DISPOSABLE_LIVE_PROBE`)
Scope: F25B independent schema, source, static bundle, and disposable live-probe comparison across installed stock `0.167.0-alpha.3.2`, official public stable `0.167.0`, newly released Desktop-train alpha `0.167.0-alpha.4.1`, official public alpha `0.169.0-alpha.7`, public `openai/codex` (`caae161dd0c82f2e04e57e6f9d738fafbce503ba`), and Official Codex Desktop (`26.1103.60933`, build `25894`).

---

## 1. Executive Summary & Binary Provenance

All live measurements were collected from headless JSON-RPC probes using isolated disposable `/tmp` profiles, synthetic `config.toml` / `auth.json` fixtures with inert sentinel values, and loopback HTTP servers on `127.0.0.1` (`chatgpt_base_url = "http://127.0.0.1:<port>/backend-api"`) without modifying the repository's default runtime binary, application code, or developer credentials. All external/backend HTTP traffic during the probes remained strictly on `127.0.0.1` loopback, and the two synthetic `account/login/start` checks mutated only disposable `/tmp` state that was deleted immediately on process exit. No `modelProvider/config/write` calls were issued at runtime on any binary version; `modelProvider/config/write` was audited strictly via generated JSON schemas and upstream Rust source.

| Artifact | Path | Reported Version / Build | Provenance / Tag Mapping | SHA-256 |
| --- | --- | --- | --- | --- |
| **Installed Desktop Stock Binary** | `/opt/codex-desktop/resources/codex` | `codex-cli 0.167.0-alpha.3.2` | Packaged inside installed Desktop package (`codex-desktop 2026.11.08.211600-1`; no public Git tag assumed) | `c8242fc9e1bac7c6d661a228cecfaf50e6db74da219e4a9ca8912827e11607f0` |
| **Official Public Stable Binary** | `/tmp/native-f24-public-stock.kHdq5U/codex` | `codex-cli 0.167.0` | Public tag `rust-v0.167.0` (`086ccc833bc9cf01024ad2dd6af7dbd421b6bf9a`) | `cdcb45aaa01d0f14e298985e09465aebccd47f64ecd298aea44814af7b62bbda` |
| **Desktop-Train Public Alpha Binary** | `/tmp/native-f25-desktop-train.8q6EXA/codex` | `codex-cli 0.167.0-alpha.4.1` | Public tag `rust-v0.167.0-alpha.4.1` (`d2c035639366e0bf2c316aa2065c24aabc12bcdc`) | `c3dea068c8794f1764051c1fd182ff0524352bbddf2f2638e72386b9b7b74368` |
| **Higher Public Alpha Binary** | `/tmp/native-f24-public-alpha.xQsk4m/codex` | `codex-cli 0.169.0-alpha.7` | Public tag `rust-v0.169.0-alpha.7` (`25da1b0cb5e876882f8b1fafe186cdfcf3c712cc`) | `b20e3a2f9a25ae9e4b29bfe68ef337757d818f85087ac701d745833894f04c7d` |
| **Measured Official Desktop Bundle** | `/opt/codex-desktop/resources/app.asar` | `26.1103.60933` (build `25894`) | Installed Electron bundle shipping `0.167.0-alpha.3.2` | `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14` |
| **Bundled Native Host** | `build/linux/x64/debug/bundle/codex-native-host` | Built from workspace base | Local debug bundle Host executable | `990c9e3af7d1a13e46cc5b2bb2233c9eac1330e2d697263ffdfffc67567ff474` |
| **Upstream Public Source** | `/tmp/openai-codex-audit.FC7cNp` | `caae161dd0c82f2e04e57e6f9d738fafbce503ba` | Public `openai/codex` repository commit | — |

### Key Conclusions

1. **Split Rollout Across `0.167.0-alpha.3.2` / `0.167.0`, `0.167.0-alpha.4.1`, and `0.169.0-alpha.7`**:
   - In generated JSON schemas, installed stock `0.167.0-alpha.3.2` and public stable `0.167.0` (`106` stable + `74` experimental-only = `180` `ClientRequest` methods) omit `modelProvider/list`, `modelProvider/config/write`, and `account/securitySetup/read`. Live read-only probes against both binaries confirmed that `modelProvider/list` and `account/securitySetup/read` return JSON-RPC `-32600` (`Invalid request: unknown variant \`<method>\`...`) on both `experimentalApi: false` and `experimentalApi: true` (`modelProvider/config/write` was audited by schema/source only and never live-called).
   - Desktop-train release `rust-v0.167.0-alpha.4.1` (`d2c0356`, `108` stable + `74` experimental-only = `182` `ClientRequest` methods) exports stable schemas for [`3026a8e54`](https://github.com/openai/codex/commit/3026a8e54) (`#58845`, `modelProvider/list`) and [`053e5b1ca`](https://github.com/openai/codex/commit/053e5b1ca) (`#58876`, `modelProvider/config/write`), but **predates** [`4be90eb06`](https://github.com/openai/codex/commit/4be90eb06) (`#60082`, `account/securitySetup/read`) as well as output deferral (`#59601`, `#60390`). In live read-only probes on `0.167.0-alpha.4.1`, `modelProvider/list` succeeded on both `experimentalApi: false` and `true`, while `account/securitySetup/read` returned `-32600` (`Invalid request: unknown variant \`account/securitySetup/read\`...`).
   - Higher public alpha `0.169.0-alpha.7` (`25da1b0`, `109` stable + `74` experimental-only = `183` `ClientRequest` methods) and upstream `caae161dd0c82f2e04e57e6f9d738fafbce503ba` export all three stable schemas (`modelProvider/list`, `modelProvider/config/write`, and `account/securitySetup/read`), and live read-only probes confirmed both `modelProvider/list` and `account/securitySetup/read` succeed on `0.169.0-alpha.7`.
   - Any client consumer of read-only `modelProvider/list` must detect unsupported runtimes by matching the **exact method-specific unknown-variant shape** (`code == -32601` or `code == -32600` with message starting with `'Invalid request: unknown variant \`modelProvider/list\`'`, matching upstream `codex-rs/tui/src/app/provider/rpc.rs:94-101`), rather than treating arbitrary `-32600` responses as unsupported-method fallbacks.
2. **Server-Side Redaction vs Client-Side Residual Sensitivity in `modelProvider/list`**:
   - Stock `summarize_provider` never resolves environment-variable values or reads GCP credential-file contents, and it redacts `baseUrl` to `null` whenever the URL fails `valid_endpoint` (including non-`http`/`https` schemes, missing hosts, embedded userinfo credentials, `?query` parameters, or `#fragment` suffixes). When external authentication is present (`http_headers`, `env_http_headers`, `query_params`, `auth`, `gateway_oauth`, `aws`, `experimental_bearer_token`, `requires_openai_auth = true`, or a URL with embedded userinfo/query), custom gateways report `settings.auth.mode = "externallyConfigured"` with `envKey: String | null`.
   - Even after stock's redaction, `ModelProviderSummary` still carries **environment-sensitive metadata** that should **not** be rendered in default diagnostics views: custom gateway `baseUrl` (internal corporate/VPC hostnames or ports), `settings.auth.envKey` (environment variable identifiers), Bedrock `profile` / `region`, and GCP `projectId` / `location` / `credentialFile` (a raw host filesystem path). Upstream Rust explicitly redacts `base_url` to `"[REDACTED]"` in `std::fmt::Debug for ModelProviderSummary`.
   - A read-only `modelProvider/list` diagnostics projection can stand independently of `account/securitySetup/read` and `modelProvider/config/write` provided that default diagnostics metadata omits raw `baseUrl`, `envKey`, and cloud `projectId` / `profile` / `region` / `location` / `credentialFile` values, and bounds/sanitizes operator-supplied labels (`id`, `name`, `defaultProviderId`).
3. **`account/securitySetup/read` Remains `RESEARCH_MORE` Due to Missing Stable `(accountId, userId)` Identity Binding**:
   - Stock `get_account_security_setup()` (3-second timeout) fetches `GET <chatgpt_base_url>/wham/security-setup` only when **both** the persisted `auth.json` login and the active in-memory auth session are non-FedRAMP `AuthMode::Chatgpt` with identical bearer tokens and non-empty `account_id` and `chatgpt_user_id`, and re-verifies the auth `source_generation`, `account_id`, and `user_id` after the HTTP response arrives.
   - Upstream `codex-rs/app-server/README.md` (`L590`) and `codex-rs/tui/src/security_setup.rs` (`L78-115`) require the client to verify that the notice's `(accountId, userId)` pair matches the active account's current `(account, user)` identity before retaining or rendering it, and to validate all copy and URL fields client-side (because `app-server` forwards `title`, `description`, `action.label`, and `action.url` verbatim without sanitization).
   - Over the public `codex app-server` RPC contract, **there is no stable `(accountId, userId)` pair in `account/read` or `account/updated`**:
     - In `0.169.0-alpha.7` stable `v2/GetAccountResponse.json`, top-level properties are `account` (`ApiKeyAccount | ChatgptAccount { email, planType, type, workspaceName } | AmazonBedrockAccount | GcpAccount | null`), `requiresOpenaiAuth`, and optional top-level `userId: string | null` (which is absent in `0.167.0-alpha.4.1`, `0.167.0`, and `0.167.0-alpha.3.2`). There is **no** stable `accountId` field.
     - Upstream `codex-rs/app-server/README.md` documents experimental `account/read.workspaceRouting.chatgptAccountId` for selected saved workspaces (and the same `0.169.0-alpha.7` `GetAccountResponse` can contain top-level `userId`), which could form a candidate experimental same-snapshot `(chatgptAccountId, userId)` route in the future — but evaluating that route still requires a dedicated disposable supported app-server probe, verification of freshness/absence behavior when workspace routing is unpopulated or changes, and a privacy assessment before retaining correlation IDs.
     - `v2/AccountUpdatedNotification.json` contains only `authMode` and `planType` (neither `accountId` nor `userId`), and Codex Native's `AccountDiagnosticsSnapshot` (`lib/src/domain/runtime_diagnostics_models.dart`) retains neither `accountId` nor `userId`.
   - Upstream TUI does not use `account/read` for notice binding; instead it runs in-process with `codex_core::config::Config` and reads local auth storage directly via `config.auth_config().load_auth(false)` (`codex-rs/tui/src/security_setup.rs:88-96`). Codex Native must **not** read `auth.json` or OS keyring state directly (which would violate the app-server boundary) and must **not** call `/wham/security-setup` directly. Checking `accountType == 'chatgpt'` and clearing on `account/updated` alone is **not** equivalent to upstream TUI's `(accountId, userId)` pair verification. Therefore, `account/securitySetup/read` presentation remains **`RESEARCH_MORE`**.
4. **Official Desktop Bundle (`26.1103.60933`) & Native Boundary**:
   - Measured Desktop `26.1103.60933` (`app.asar`) contains `0` occurrences of `modelProvider/list`, `0` occurrences of `modelProvider/config/write`, `0` occurrences of `ModelProviderSummary`, `0` occurrences of `account/securitySetup/read`, and `0` occurrences of `wham/security-setup` (it references only `modelProvider/capabilities/read` `3` times, `account/read` `14` times, and `account/rateLimits/read` `7` times).
   - In Codex Native, Direct Host Remote (`native_host/src/remote_bridge.rs`) allowlists only `model/list`, `thread/list`, `thread/read`, `thread/turns/list`, `thread/items/list`, and `thread/items/read`, rejecting `modelProvider/*` and `account/*` with `-32602` (`"Method is not available on the Remote read-only surface"`). Any future read-only adoption of `modelProvider/list` belongs strictly to local Desktop runtime diagnostics (`RuntimeDiagnosticsProtocolAdapter` / `_RuntimeDetailsDialog`) while keeping `account/securitySetup/read` in `RESEARCH_MORE` and `modelProvider/config/write` out of scope.

---

## 2. Four-Binary Generated Schema & Method Inventory (`LOCAL_SCHEMA`)

Generated directly from each binary via `<codex> app-server generate-json-schema [--experimental] --out <dir>`:

| Dimension | Installed `0.167.0-alpha.3.2` | Public Stable `0.167.0` | Desktop-Train `0.167.0-alpha.4.1` | Public Alpha `0.169.0-alpha.7` |
| --- | --- | --- | --- | --- |
| **`ClientRequest` (stable + exp-only = total)** | `106 + 74 = 180` | `106 + 74 = 180` | `108 + 74 = 182` | `109 + 74 = 183` |
| **`ServerRequest` (stable + exp-only = total)** | `10 + 1 = 11` | `10 + 1 = 11` | `10 + 1 = 11` | `10 + 1 = 11` |
| **`ServerNotification` (stable / exp)** | `86 / 86` | `86 / 86` | `86 / 86` | `86 / 86` |
| **`ClientNotification` (stable / exp)** | `1 / 1` (`initialized`) | `1 / 1` (`initialized`) | `1 / 1` (`initialized`) | `1 / 1` (`initialized`) |
| **`modelProvider/list` in `ClientRequest`** | Absent | Absent | **Present (stable & exp)** | **Present (stable & exp)** |
| **`modelProvider/config/write` in `ClientRequest`** | Absent | Absent | **Present (stable & exp)** | **Present (stable & exp)** |
| **`account/securitySetup/read` in `ClientRequest`** | Absent | Absent | Absent | **Present (stable & exp)** |
| **`ThreadItemsListParams.deferOutput`** | Absent | Absent | Absent | Present (stable empty object; exp booleans) |
| **`v2/ModelProviderListParams.json`** | Absent | Absent | Byte-identical to `0.169.0-alpha.7` | Present |
| **`v2/ModelProviderListResponse.json`** | Absent | Absent | Byte-identical to `0.169.0-alpha.7` | Present |
| **`v2/ModelProviderConfigWriteParams.json`** | Absent | Absent | Byte-identical to `0.169.0-alpha.7` | Present |
| **`v2/ModelProviderConfigWriteResponse.json`** | Absent | Absent | Byte-identical to `0.169.0-alpha.7` | Present |
| **`v2/GetAccountSecuritySetupResponse.json`** | Absent | Absent | Absent | Present |
| **`v2/GetAccountResponse.json` identity fields** | `account`, `requiresOpenaiAuth` (no `userId`, no stable `accountId`) | `account`, `requiresOpenaiAuth` (no `userId`, no stable `accountId`) | `account`, `requiresOpenaiAuth` (no `userId`, no stable `accountId`) | Adds optional top-level `userId: string \| null`; still **no** stable `accountId` (`ChatgptAccount` has only `email`, `planType`, `type`, `workspaceName`) |
| **`v2/AccountUpdatedNotification.json` fields** | `authMode`, `planType` | `authMode`, `planType` | `authMode`, `planType` | `authMode`, `planType` (neither `accountId` nor `userId`) |

### 2.1 `modelProvider/list` Schema Contract (`LOCAL_SCHEMA`)

- **Request (`v2/ModelProviderListParams.json`)**:
  - `{"title": "ModelProviderListParams", "type": "object"}` (accepts `{}`).
- **Response (`v2/ModelProviderListResponse.json`)**:
  - Required top-level fields: `data: ModelProviderSummary[]`, `defaultProviderId: string`, `canChangeDefault: boolean`.
  - `ModelProviderSummary` required fields: `id: string`, `name: string`, `canEdit: boolean`, `settings: ProviderSettings`; optional/nullable field: `baseUrl: string | null` (`"Null when the endpoint is absent or cannot be safely displayed."`).
  - `ProviderSettings` (`oneOf` tagged by `"type"`):
    1. `{"type": "openai"}` (`OpenaiProviderSettings`).
    2. `{"type": "customGateway", "auth": GatewayAuth}` (`CustomGatewayProviderSettings`), where `GatewayAuth` is tagged by `"mode"`:
       - `{"mode": "none"}`
       - `{"mode": "environmentVariable", "envKey": string}`
       - `{"mode": "externallyConfigured", "envKey"?: string | null}` (`"Authentication is configured outside the gateway form. Preserve it on edits."`)
    3. `{"type": "bedrock", "profile"?: string | null, "region"?: string | null}` (`BedrockProviderSettings`).
    4. `{"type": "gcp", "projectId"?: string | null, "location"?: string | null, "credentialFile"?: string | null}` (`GcpProviderSettings`; `"Path on the app-server host, without credential-file contents."`).

### 2.2 `modelProvider/config/write` Schema-Only Contract (`LOCAL_SCHEMA`)

- **Request (`v2/ModelProviderConfigWriteParams.json`)**:
  - Top-level object (`additionalProperties: false`, `required: ["settings"]`) with `settings: ProviderSettingsPatch`.
  - `ProviderSettingsPatch` (`oneOf` tagged by `"type"`, each branch enforcing `additionalProperties: false`):
    1. `CustomGatewayProviderSettingsPatch`: `required: ["type"]` (`"customGateway"`), optional `providerId: string | null` (`"Omit or pass null to allocate a new custom provider ID."`), `name: string` (non-nullable when present), `baseUrl: string | null`, `envKey: string | null`.
    2. `BedrockProviderSettingsPatch`: `required: ["providerId", "type"]` (`"bedrock"`), where `providerId` is enum `["amazon-bedrock", "amazon-bedrock-runtime"]`, optional `profile: string | null`, `region: string | null`.
    3. `GcpProviderSettingsPatch`: `required: ["providerId", "type"]` (`"gcp"`), where `providerId` is enum `["gcp"]`, optional `projectId: string | null`, `location: string | null`, `credentialFile: string | null`.
  - There is no `"openai"` branch in `ProviderSettingsPatch`.
- **Response (`v2/ModelProviderConfigWriteResponse.json`)**:
  - Required field: `provider: ModelProviderSummary`.

### 2.3 `account/securitySetup/read` & Account Identity Schema Contract (`LOCAL_SCHEMA`)

- **Request (`ClientRequest.json` entry)**:
  - `method: "account/securitySetup/read"`, `params: null` or omitted (`"type": "null"` in JSON schema; optional in serde deserialization).
- **Response (`v2/GetAccountSecuritySetupResponse.json`)**:
  - `notice?: AccountSecuritySetupNotice | null` (`"Optional security reminder bound to the account that fetched it. Unavailable or ineligible accounts return no notice; this read never changes account security."`).
  - `AccountSecuritySetupNotice` required fields: `accountId: string`, `userId: string`, `title: string`, `description: string`, `action: AccountSecuritySetupAction`.
  - `AccountSecuritySetupAction` required fields: `label: string`, `url: string`.
- **Identity Binding Gap in Stable `v2/GetAccountResponse.json` and `v2/AccountUpdatedNotification.json`**:
  - While `AccountSecuritySetupNotice` carries required `accountId` and `userId` strings for client-side identity matching, stable `v2/GetAccountResponse.json` (`account/read`) in `0.169.0-alpha.7` exposes only an optional top-level `userId: string | null` (absent in `0.167.0-alpha.4.1`, `0.167.0`, and `0.167.0-alpha.3.2`) and **no** stable `accountId` (`ChatgptAccount` has only `email`, `planType`, `type`, and `workspaceName`).
  - Upstream `codex-rs/app-server/README.md` documents experimental `account/read.workspaceRouting.chatgptAccountId` for selected saved workspaces (and the same `0.169.0-alpha.7` `GetAccountResponse` can contain top-level `userId`), leaving an experimental same-snapshot `(chatgptAccountId, userId)` route as a future candidate pending a dedicated disposable supported app-server probe, freshness/absence behavior verification, and privacy assessment.
  - `v2/AccountUpdatedNotification.json` (`account/updated`) exposes only `authMode` and `planType`, with neither `accountId` nor `userId`, and Codex Native's `AccountDiagnosticsSnapshot` (`lib/src/domain/runtime_diagnostics_models.dart`) retains neither `accountId` nor `userId`.

---

## 3. Upstream Source & Privacy Audit (`PUBLIC_SOURCE`)

Audited against public `openai/codex` commit `caae161dd0c82f2e04e57e6f9d738fafbce503ba` (including commits [`3026a8e54`](https://github.com/openai/codex/commit/3026a8e54) `#58845`, [`053e5b1ca`](https://github.com/openai/codex/commit/053e5b1ca) `#58876`, and [`4be90eb06`](https://github.com/openai/codex/commit/4be90eb06) `#60082`):

### 3.1 `modelProvider/list` Discovery, Layer Precedence, and Redaction (`codex-rs/app-server/src/config_manager_service_model_providers.rs`)

1. **Provider Catalog Inclusion & Ordering**:
   - `ConfigManager::model_provider_list` loads the thread-agnostic `ConfigLayerStack` and collects all keys from `effective.get("model_providers")` into a `BTreeSet` (lexicographical ID order), explicitly **excluding** local OSS built-in IDs `ollama` (`OLLAMA_OSS_PROVIDER_ID`) and `lmstudio` (`LMSTUDIO_OSS_PROVIDER_ID`), and always chaining `"openai"` (`OPENAI_PROVIDER_ID`).
   - Built-in providers (`amazon-bedrock`, `amazon-bedrock-runtime`, `gcp`) appear in `data` **only** when a `[model_providers.<id>]` table exists in the effective configuration (or requirements); `"openai"` is always included even when unconfigured.
   - `defaultProviderId` resolves `layers.required_model_provider()` first, then `effective.get("model_provider")`, falling back to `"openai"` — even if the selected default provider (for example `"ollama"` or an unconfigured custom ID) has no entry in `data`.
2. **Editability & Layer-Precedence Flags (`canChangeDefault`, `canEdit`)**:
   - `canChangeDefault` is `true` iff `layers.required_model_provider().is_none()` and an active writable user config layer exists whose precedence is `>=` the highest-precedence layer defining `model_provider` (so a CLI `-c model_provider=...` override or `requirements.toml` `model_provider` sets `canChangeDefault: false`).
   - `canEdit` is `true` iff at least one supported field for that provider (`[]` for `openai`, `["aws.profile", "aws.region"]` or `["aws.region"]` for Bedrock without `auth`, `["project_id", "location", "credential_file"]` for `gcp`, `["name", "base_url", "env_key"]` for custom gateways) is writable in the active user layer (not locked by `requirements_toml().model_providers` or a higher-precedence layer such as CLI `-c`).
3. **Server-Side Endpoint & Auth Redaction (`valid_endpoint`, `has_external_auth`)**:
   - `valid_endpoint(url)` accepts only `http` or `https` URLs with a host and **no** username, password, query string, or fragment. Any `base_url` (or `openai_base_url` for `openai`) failing `valid_endpoint` is redacted to `baseUrl: null` in `ModelProviderSummary`.
   - `has_external_auth(config)` returns `true` when `base_url` contains a username, password, or query string, when any of `["auth", "gateway_oauth", "aws", "experimental_bearer_token"]` is present, when `requires_openai_auth == true`, or when any table in `["http_headers", "env_http_headers", "query_params"]` is non-empty.
   - For custom gateways (`id` not in `openai`, `amazon-bedrock`, `amazon-bedrock-runtime`, `gcp`), `has_external_auth` forces `GatewayAuth::ExternallyConfigured { env_key }`, preventing a client form from overwriting hidden headers, query parameters, OAuth blocks, or embedded credentials.
4. **Write Semantics (`codex-rs/app-server/src/config_manager_service_provider_write.rs` & `codex-rs/tui/src/app/provider/rpc.rs`)**:
   - `modelProvider/config/write` is a partial field patch into the user `config.toml` layer with no optimistic-concurrency version token (`expected_version` is not part of the RPC), shares the config write queue on a last-write-wins basis, automatically injects `wire_api = "responses"` when creating a new custom provider table, and does not change `model_provider` (selecting a default requires a separate `config/value/write` on `keyPath: "model_provider"`).
   - Upstream TUI (`rpc::write_provider`) has to special-case `-32603` / transport errors during custom-provider creation (`providerId: null`) as `ProviderWrite::UnconfirmedCreate` (`"Could not confirm the save. Check the provider list before adding it again."`) because a lost response after a committed write would otherwise allocate duplicate `slug-2`, `slug-3` provider IDs on retry.
   - Upstream TUI (`codex-rs/tui/src/app/provider/rpc.rs:94-101`) detects unsupported servers via `unknown_method(err, method)`, which checks `err.code == -32601 || (err.code == -32600 && err.message.starts_with(&format!("Invalid request: unknown variant \`{method}\`")))`.

### 3.2 `account/securitySetup/read` Execution & Client Validation (`codex-rs/app-server/src/request_processors/account_processor/security_setup.rs` & `codex-rs/tui/src/security_setup.rs`)

1. **App-Server Fetch Guards (`security_setup.rs:284-375`)**:
   - Wrapped in `tokio::time::timeout(Duration::from_secs(3), ...)`; any timeout or internal error maps to `GetAccountSecuritySetupResponse { notice: None }`.
   - Requires saved credentials from `config.auth_config().load_auth(false)` to match `CodexAuth::Chatgpt(_)` with `!saved.is_fedramp_account()`, and requires the active `auth_manager` session to also be `AuthMode::Chatgpt` with the exact same bearer token (`saved.get_token() == auth.get_token()`), plus non-empty `account_id` and `chatgpt_user_id`.
   - Calls `GET <chatgpt_base_url>/wham/security-setup` without following redirects (`RouteAwareClientPool::new_without_redirects`) and with `chatgpt-account-id: <account_id>`.
   - After deserializing `notice`, re-reads `self.auth_manager.auth()` and discards the notice (`return None`) if `source_generation`, `auth_mode`, `account_id`, `chatgpt_user_id`, or `is_fedramp_account()` changed while the HTTP request was in flight.
2. **Client-Side Validation & Local Auth Identity Check (`codex-rs/tui/src/security_setup.rs:41-115` & `README.md:590`)**:
   - Upstream `codex-rs/app-server/README.md` states: *"A returned notice includes its account and user IDs; clients must discard it after an account change and validate its copy and action URL before rendering."*
   - Upstream TUI's `Notice::valid(&self)` enforces:
     - `!title.trim().is_empty() && title.len() <= 256 && !title.chars().any(char::is_control)`
     - `description.len() <= 2048 && !description.chars().any(char::is_control)`
     - `!action.label.trim().is_empty() && action.label.len() <= 128 && !action.label.chars().any(char::is_control)`
     - `Url::parse(&action.url)` must have `scheme() == "https"`, `host_str() == Some("chatgpt.com")`, `username().is_empty()`, `password().is_none()`, and `port().is_none()`.
     - Note two implementation subtleties in `Notice::valid(&self)`:
       1. **UTF-8 byte limits**: Rust `String::len()` measures **UTF-8 bytes** (`256`, `2048`, `128`), whereas Dart `String.length` counts UTF-16 code units (`utf8.encode(value).length` is required for byte-exact parity).
       2. **Default-port normalization**: Rust `url::Url::parse` normalizes the default HTTPS port `:443` to `url.port() == None` (so `https://chatgpt.com:443/...` passes `url.port().is_none()`), whereas a stricter future Native URL policy can additionally reject any explicit `:port` authority segment.
   - Critically, upstream TUI's `Identity::from_config(config)` (`security_setup.rs:78-96`) does **not** use `account/read` or `account/updated` to verify `notice.account_id` and `notice.user_id`; instead, it calls `config.auth_config().load_auth(false)` directly on the local filesystem/keyring to extract `(account_id, user_id)` and checks `identity.matches(&notice)` (`self.account == notice.account_id && self.user == notice.user_id`) both on prefetch completion and immediately before display. Because pure `codex app-server` clients cannot read `auth.json`/keyring directly without violating the runtime boundary — and stable `GetAccountResponse` / `AccountUpdatedNotification` do not provide the `(accountId, userId)` pair — Native cannot currently replicate TUI's identity pair verification.

---

## 4. Official Desktop Bundle Audit (`STATIC_BUNDLE`)

Audited `/opt/codex-desktop/resources/app.asar` (`26.1103.60933`, build `25894`, SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`):

| Search Token | Static Occurrences in `app.asar` | Observed Bundle Behavior |
| --- | --- | --- |
| `modelProvider/list` | `0` | Absent from method allowlists, routing maps, and settings UI. |
| `modelProvider/config/write` | `0` | Absent from method allowlists, routing maps, and settings UI. |
| `ModelProviderSummary` | `0` | Absent. |
| `account/securitySetup/read` | `0` | Absent from method allowlists, routing maps, and account hooks. |
| `AccountSecuritySetupNotice` | `0` | Absent. |
| `wham/security-setup` / `security-setup` | `0` | Absent. |
| `modelProvider/capabilities/read` | `3` | Present at byte offsets `6679556`, `110782825`, and `110786410` inside read-only method sets and the `"models"` host-request scheduler category (already implemented in Native F11). |
| `account/read` / `account/rateLimits/read` | `14` / `7` | Existing account/rate-limit RPCs used by Desktop (already implemented in Native F11). |
| `account/gatewayOAuth/read` | `4` | Present at byte offsets `9313062`, `110319837`, `110780740`, and `111407751` for gateway OAuth readiness checks. |

Because installed Desktop `26.1103.60933` ships `0.167.0-alpha.3.2`, neither `modelProvider/list` nor `account/securitySetup/read` is wired in the measured Electron bundle; upstream TUI (`codex-rs/tui`) is currently the reference first-party consumer for both RPCs.

---

## 5. Disposable Live Probe Evidence (`DISPOSABLE_LIVE_PROBE`)

All probes ran through the bundled Host (`build/linux/x64/debug/bundle/codex-native-host --codex <binary>`, SHA-256 `990c9e3af7d1a13e46cc5b2bb2233c9eac1330e2d697263ffdfffc67567ff474`) or direct `app-server --listen stdio://` (for CLI `-c` flag injection) using temporary `/tmp` directories that were deleted immediately on exit. Only the read-only methods `modelProvider/list` and `account/securitySetup/read` were called in the cross-version availability probe (`modelProvider/config/write` was never called).

### 5.1 Cross-Version Read-Only Method Availability Matrix (Default Disposable Profile)

| Binary | `experimentalApi` | `modelProvider/list` (`{}`) | `account/securitySetup/read` (`null` or omitted `params`) |
| --- | --- | --- | --- |
| `0.167.0-alpha.3.2` (Installed) | `false` or `true` | `-32600` (`Invalid request: unknown variant \`modelProvider/list\`...`) | `-32600` (`Invalid request: unknown variant \`account/securitySetup/read\`...`) |
| `0.167.0` (Public Stable) | `false` or `true` | `-32600` (`Invalid request: unknown variant \`modelProvider/list\`...`) | `-32600` (`Invalid request: unknown variant \`account/securitySetup/read\`...`) |
| `0.167.0-alpha.4.1` (Desktop-Train Alpha) | `false` or `true` | **Succeeded**: `{"canChangeDefault": true, "data": [{"baseUrl": null, "canEdit": false, "id": "openai", "name": "OpenAI", "settings": {"type": "openai"}}], "defaultProviderId": "openai"}` | `-32600` (`Invalid request: unknown variant \`account/securitySetup/read\`...`) |
| `0.169.0-alpha.7` (Higher Public Alpha) | `false` or `true` | **Succeeded**: `{"canChangeDefault": true, "data": [{"baseUrl": null, "canEdit": false, "id": "openai", "name": "OpenAI", "settings": {"type": "openai"}}], "defaultProviderId": "openai"}` | **Succeeded**: `{"notice": null}` |

### 5.2 Synthetic Multi-Provider & Privacy Redaction Matrix (`0.167.0-alpha.4.1` & `0.169.0-alpha.7`)

Both `0.167.0-alpha.4.1` and `0.169.0-alpha.7` produced **byte-identical** `modelProvider/list` responses across synthetic provider profiles with inert sentinel values and CLI `-c` layer overrides:

| Synthetic Configuration Input (`config.toml` / CLI `-c`) | Observed `ModelProviderSummary` / Top-Level Output | Privacy / Redaction Verification |
| --- | --- | --- |
| `openai_base_url = "https://proxy.example.test/v1?query_param=<inert-query-sentinel>"` | `id: "openai"`, `name: "OpenAI"`, `canEdit: false`, **`baseUrl: null`**, `settings: {"type": "openai"}` | Query-string parameter in `openai_base_url` failed `valid_endpoint` and redacted `baseUrl` to `null`. |
| `[model_providers.amazon-bedrock]` with `base_url = "https://bedrock.example.test/v1"`, `aws.profile = "work-profile"`, `aws.region = "us-east-1"` | `id: "amazon-bedrock"`, `name: "Amazon Bedrock Mantle"`, `canEdit: true`, `baseUrl: "https://bedrock.example.test/v1"`, `settings: {"type": "bedrock", "profile": "work-profile", "region": "us-east-1"}` | Built-in display name mapped to `"Amazon Bedrock Mantle"`; AWS profile and region exposed as plain strings. |
| `[model_providers.amazon-bedrock-runtime.aws]` with `region = "us-west-2"`, `credential_export = "<inert-credential-export-command>"` | `id: "amazon-bedrock-runtime"`, `name: "Amazon Bedrock Runtime"`, `canEdit: true`, `baseUrl: null`, `settings: {"type": "bedrock", "profile": null, "region": "us-west-2"}` | `credential_export` command string is omitted from `settings` while keeping `aws.region` editable. |
| `[model_providers.gcp]` with `project_id = "demo-gcp-project"`, `location = "us-central1"`, `credential_file = "/tmp/fake-host-gcp-creds.json"` (containing `<inert-credential-file-body>`), `base_url = "https://vertex.example.test/v1"` | `id: "gcp"`, `name: "Google Cloud Vertex AI"`, `canEdit: true`, `baseUrl: "https://vertex.example.test/v1"`, `settings: {"type": "gcp", "projectId": "demo-gcp-project", "location": "us-central1", "credentialFile": "/tmp/fake-host-gcp-creds.json"}` | Contents of `/tmp/fake-host-gcp-creds.json` (`<inert-credential-file-body>`) were **never read or returned**, but the **host file path** and `projectId` are returned verbatim in `settings`. |
| `[model_providers.ollama]` and `[model_providers.lmstudio]` tables | **Omitted from `data`** (`0` entries) | Local OSS built-ins (`ollama`, `lmstudio`) are filtered out of `data` even when tables are present in `config.toml`. |
| `[model_providers.basic-creds]` with `base_url = "https://<inert-userinfo-sentinel>@basic.example.test/v1"` | `id: "basic-creds"`, `canEdit: true`, **`baseUrl: null`**, `settings: {"type": "customGateway", "auth": {"mode": "externallyConfigured", "envKey": null}}` | Embedded `<inert-userinfo-sentinel>@` userinfo redacted `baseUrl` to `null` and forced `mode: "externallyConfigured"`. |
| `[model_providers.query-creds]` with `base_url = "https://query.example.test/v1?param=<inert-query-sentinel>"`, `env_key = "QUERY_ENV_KEY"`, `http_headers = { X-Custom-Auth = "<inert-header-sentinel>" }` + env `QUERY_ENV_KEY=<inert-env-value-sentinel>` | `id: "query-creds"`, `canEdit: true`, **`baseUrl: null`**, `settings: {"type": "customGateway", "auth": {"mode": "externallyConfigured", "envKey": "QUERY_ENV_KEY"}}` | Query-string parameter and `http_headers` sentinel value were never emitted; `baseUrl` was redacted to `null`, `mode` became `"externallyConfigured"`, and only the variable **name** `"QUERY_ENV_KEY"` (not `<inert-env-value-sentinel>`) was returned. |
| `[model_providers.header-only]` with `base_url = "https://header.example.test/v1"`, `query_params = { param = "<inert-param-sentinel>" }` | `id: "header-only"`, `canEdit: true`, `baseUrl: "https://header.example.test/v1"`, `settings: {"type": "customGateway", "auth": {"mode": "externallyConfigured", "envKey": null}}` | Clean `baseUrl` remained visible while `query_params` sentinel value stayed hidden and forced `mode: "externallyConfigured"`. |
| `[model_providers.env-gateway]` with `base_url = "https://gateway.example.test/v1"`, `env_key = "TEAM_GATEWAY_KEY"` + env `TEAM_GATEWAY_KEY=<inert-env-value-sentinel>` | `id: "env-gateway"`, `canEdit: true`, `baseUrl: "https://gateway.example.test/v1"`, `settings: {"type": "customGateway", "auth": {"mode": "environmentVariable", "envKey": "TEAM_GATEWAY_KEY"}}` | Only the variable name `"TEAM_GATEWAY_KEY"` was returned; the environment variable value (`<inert-env-value-sentinel>`) was never resolved or leaked. |
| CLI higher-precedence override: `-c model_provider="corp-cli"` and `-c model_providers.corp-cli.*=...` | Top-level **`defaultProviderId: "corp-cli"`**, **`canChangeDefault: false`**, and `corp-cli` entry **`canEdit: false`** (while user-layer `team` remained `canEdit: true`) | Higher-precedence CLI layer locked both `canChangeDefault` and `corp-cli.canEdit` to `false`. |

### 5.3 `account/securitySetup/read` Loopback Probe Matrix (`0.169.0-alpha.7`)

Tested against a disposable `127.0.0.1` loopback HTTP server (`chatgpt_base_url = "http://127.0.0.1:<port>/backend-api"`) handling `/backend-api/wham/accounts/check` and `/backend-api/wham/security-setup` with `cli_auth_credentials_store = "file"` inside an ephemeral `/tmp` `CODEX_HOME` directory. All backend traffic stayed on `127.0.0.1` loopback, and the two synthetic `account/login/start` checks mutated only disposable `/tmp` state that was deleted immediately on process exit:

| Disposable Auth / Backend Case | `/backend-api/wham/security-setup` HTTP Hits | Observed `account/securitySetup/read` Result | Verification Finding |
| --- | --- | --- | --- |
| **Saved ChatGPT login + valid notice** (`accountId: "acct-synthetic-123"`, `userId: "user-synthetic-456"`) | `1` (`Authorization: <inert-loopback-auth-header>`, `chatgpt-account-id: acct-synthetic-123`) | `{"notice": {"accountId": "acct-synthetic-123", "action": {"label": "Settings", "url": "https://chatgpt.com/cyber"}, "description": "Account security reminder", "title": "Set up security", "userId": "user-synthetic-456"}}` | Binds saved JWT `accountId` and `userId` onto the backend-returned notice object. |
| **Saved ChatGPT login + hostile/unvalidated backend notice** (`title: "Urgent Verification\u0007"`, `action.url: "https://evil.example.test/phish"`) | `1` | `{"notice": {"accountId": "acct-synthetic-123", "action": {"label": "Open", "url": "https://evil.example.test/phish"}, "description": "Click external link", "title": "Urgent Verification\u0007", "userId": "user-synthetic-456"}}` | **App-server performs no URL or control-char filtering**; the client **must** validate `https://chatgpt.com` and reject control characters before rendering or opening `action.url`. |
| **Saved ChatGPT login + backend `{"notice": null}`** | `1` | `{"notice": null}` | Cleanly returns `null` notice. |
| **Saved ChatGPT login + backend HTTP `500`** | `1` | `{"notice": null}` | Non-2xx backend responses map to `{"notice": null}` rather than a JSON-RPC error. |
| **Saved FedRAMP ChatGPT login** (`chatgpt_account_is_fedramp: true`) | `0` | `{"notice": null}` | Short-circuits before making any `/wham/security-setup` HTTP request. |
| **Saved API-key login** (`auth_mode: "apikey"`) | `0` | `{"notice": null}` | Short-circuits before making any HTTP request. |
| **Signed-out profile** (no `auth.json`) | `0` | `{"notice": null}` | Short-circuits before making any HTTP request. |
| **Saved ChatGPT login overridden in disposable `/tmp` session by `account/login/start` (`type: "apiKey"`)** | `0` | `{"notice": null}` | Active `auth.auth_mode() != AuthMode::Chatgpt` blocks the fetch even when the disposable `auth.json` fixture initially held ChatGPT tokens. |
| **Saved ChatGPT login overridden in disposable `/tmp` session by `account/login/start` (`type: "chatgptAuthTokens"`, `experimentalApi: true`)** | `0` | `{"notice": null}` | External in-memory `chatgptAuthTokens` login in the disposable process does not match saved file auth state and returns `{"notice": null}` with `0` loopback HTTP hits. |

---

## 6. Privacy Analysis & Candidate Read-Only Presentation Boundary for Codex Native

### 6.1 Sensitivity Classification of Returned Fields

| RPC & Field | Sensitivity Class | Rationale & Default Presentation Rule |
| --- | --- | --- |
| `modelProvider/list` -> `defaultProviderId`, `canChangeDefault`, `data[].id`, `data[].name`, `data[].canEdit`, `data[].settings.type`, `data[].settings.auth.mode` | **Low (Structural Provider Metadata)** | Structural identifiers, operator-supplied labels, and booleans suitable for a bounded read-only Runtime Diagnostics projection once `id`, `name`, and `defaultProviderId` are control-character sanitized and length-bounded (`<= 256` chars). |
| `modelProvider/list` -> `data[].settings.auth.envKey` | **Medium (Environment Variable Identifier)** | Names the environment variable (e.g., `TEAM_GATEWAY_KEY`), never its value, but still reveals local environment naming conventions. **Omit raw `envKey` names from default diagnostics metadata** (at most expose `settings.auth.mode` or a boolean `hasEnvKey`), and never export to Remote. |
| `modelProvider/list` -> `data[].baseUrl` | **Medium-High (Endpoint Topology)** | Stock strips userinfo, queries, and fragments, but internal corporate gateway hostnames/ports remain visible, and upstream Rust redacts `base_url` to `"[REDACTED]"` in `Debug` logs. **Omit raw `baseUrl` endpoints from default diagnostics metadata** (at most expose a boolean `hasCustomEndpoint: baseUrl != null`), never log in plain text, and never expose over Direct Host Remote. |
| `modelProvider/list` -> `data[].settings.{profile, region, projectId, location}` | **Medium-High (Cloud Account / Project Metadata)** | Reveals cloud account profile names and GCP project identifiers. **Omit raw `projectId`, `profile`, `region`, and `location` strings from default diagnostics metadata** and never expose over Remote. |
| `modelProvider/list` -> `data[].settings.credentialFile` | **High (Host Filesystem Path)** | Exposes a raw filesystem path on the app-server host (e.g., `/home/<user>/...`). **Omit `credentialFile` from default diagnostics metadata** and never retain or log raw host paths. |
| `account/securitySetup/read` -> `notice.accountId`, `notice.userId` | **High (Identity Correlation Tokens — No Stable Pair in Public RPC)** | Required to verify that a returned notice matches the active `(accountId, userId)` pair, but there is no stable `(accountId, userId)` pair in `GetAccountResponse` (`account/read`) or `AccountUpdatedNotification` (`account/updated`). **Keep `account/securitySetup/read` presentation in `RESEARCH_MORE`**. |
| `account/securitySetup/read` -> `notice.title`, `notice.description`, `notice.action.label`, `notice.action.url` | **Untrusted Backend Copy / External Link (`RESEARCH_MORE`)** | Forwarded without server-side sanitization. Any future adoption after identity binding is solved must enforce UTF-8 byte limits (`title <= 256`, `description <= 2048`, `action.label <= 128`), reject Unicode control characters, and require `action.url` to be `https://chatgpt.com/...` with no userinfo or port (including rejecting explicit `:443` if stricter than `url::Url` normalization). |

### 6.2 Separation of `modelProvider/list` Read-Only Projection vs `account/securitySetup/read` (`RESEARCH_MORE`)

1. **`modelProvider/list` Can Stand Independently as a Bounded Read-Only Diagnostics Candidate**:
   - **Exact Unknown-Method Detection**: Because `0.167.0-alpha.3.2` and `0.167.0` do not implement `modelProvider/list` while `0.167.0-alpha.4.1` and `0.169.0-alpha.7` do, `RuntimeDiagnosticsProtocolAdapter` must detect unsupported runtimes by matching the exact known method + unknown-variant shape (`code == -32601` or `code == -32600` whose message starts with `'Invalid request: unknown variant \`modelProvider/list\`'`, matching upstream `codex-rs/tui/src/app/provider/rpc.rs:94-101`), rather than treating any `-32600` response as an unsupported fallback.
   - **Privacy-Safe Default Projection**: A read-only `modelProvider/list` snapshot in `RuntimeDiagnosticsProtocolAdapter` should cap retained entries (e.g., `maxModelProviders = 32` with `truncated` flag), strip/reject control characters and cap length (`<= 256` chars) on operator-supplied strings (`defaultProviderId`, `id`, `name`), retain only structural fields (`canChangeDefault`, `canEdit`, `settings.type`, `settings.auth.mode`), and **omit** raw endpoints (`baseUrl`), environment-variable identifiers (`envKey`), and cloud `projectId` / `profile` / `region` / `location` / `credentialFile` host paths from default diagnostics metadata.
2. **`account/securitySetup/read` Presentation Remains `RESEARCH_MORE`**:
   - **Why `accountType == 'chatgpt'` + `account/updated` Clearing Is Insufficient**: Upstream TUI (`codex-rs/tui/src/security_setup.rs:78-115`) requires matching `(notice.account_id, notice.user_id)` against the current active login identity `(identity.account, identity.user)` both when a notice arrives and before rendering. In `0.169.0-alpha.7`, stable `v2/GetAccountResponse.json` has only an optional top-level `userId` (absent in `0.167.0-alpha.4.1` and `0.167.0`) and **no** stable `accountId` (`ChatgptAccount` has only `email`, `planType`, `type`, `workspaceName`), `v2/AccountUpdatedNotification.json` has only `authMode` and `planType`, and Native's `AccountDiagnosticsSnapshot` retains neither ID.
   - **Experimental Same-Snapshot Route Candidate**: Upstream `codex-rs/app-server/README.md` documents experimental `account/read.workspaceRouting.chatgptAccountId` for selected saved workspaces (and the same `0.169.0-alpha.7` `GetAccountResponse` can contain top-level `userId`). Evaluating that experimental same-snapshot route as a future candidate requires a dedicated disposable supported app-server probe, freshness/absence behavior verification when workspace routing is unpopulated or changes, and a privacy assessment before retaining correlation IDs.
   - **Non-Negotiable Boundary**: Codex Native must **not** read `auth.json` or OS keyring storage directly as a workaround to obtain `(accountId, userId)` and must **not** call `/wham/security-setup` directly from the client. Therefore, `account/securitySetup/read` presentation remains **`RESEARCH_MORE`** until a verified public RPC identity-binding path is established.
3. **Keep `modelProvider/config/write` and Direct Host Remote Separate**:
   - `modelProvider/config/write` mutates user `config.toml` without version tokens, requires multi-branch form validation (`customGateway` / `bedrock` / `gcp`), and needs `UnconfirmedCreate` duplicate-ID recovery plus a separate `config/value/write` call to change `model_provider`. It remains out of scope for read-only diagnostics.
   - Direct Host Remote (`native_host/src/remote_bridge.rs`) must remain closed to `modelProvider/*` and `account/securitySetup/read`.
