# Account-Notice Identity Boundary Evidence (`account/read`, `account/updated`, and `account/securitySetup/read`)

- **Date:** 2026-11-10
- **Slice:** F27B (`agent/gemini-account-notice-identity-evidence`)
- **Base Commit:** `a7b0fcdb9b40acf7e740a0fcb8e901e24c3ce646`
- **Evidence Class:** `MACHINE VERIFIED` (disposable headless real-runtime integration via direct `<codex> app-server --listen stdio://` and bundled `codex-native-host --codex <bin> [--cache-dir <fixture>]`, static audit of measured Desktop `app.asar`, and source inspection of peeled upstream commit `25da1b0cb5e876882f8b1fafe186cdfcf3c712cc` / `origin/main` `4dcd8df891ad38ed7d4ea59c44b817c293ffc0e2`; not packaged GUI real-use)
- **Safety / Scope Guardrail:** All live probes used isolated public `app-server` JSON-RPC methods (`initialize`, `account/read`, `account/securitySetup/read`, `account/login/start`, `account/logout`) with disposable `/tmp` `CODEX_HOME` directories and `127.0.0.1` loopback HTTP servers (`chatgpt_base_url = "http://127.0.0.1:<port>/backend-api/"`). No real user credentials, auth stores, or private OpenAI endpoints were accessed, and no production client/host code was modified.

---

## 1. Executive Summary

1. **Measured Version & Bundle Support Limitations:**
   - **Installed Desktop Stock (`0.167.0-alpha.3.2`)**, **Official Public Stable (`0.167.0`)**, and **Desktop-Train Public Alpha (`0.167.0-alpha.4.1`)** do **not** implement `account/securitySetup/read` (returning JSON-RPC `-32600`) and do **not** declare or emit `userId` in `v2/GetAccountResponse` (`account/read` top-level keys are `["account", "requiresOpenaiAuth", "workspaceRouting"]` for both `experimentalApi: false` and `true`).
   - **Measured Official Desktop Bundle (`26.1103.60933`, build `25894`)** contains zero references to `account/securitySetup/read`.
   - **Higher Public Alpha (`0.169.0-alpha.7`, tag object `367d997f42430c9260ef8e6bdc00b3aebc2aee3c` -> peeled commit `25da1b0cb5e876882f8b1fafe186cdfcf3c712cc`)** declares `userId` as a nullable field (`["string", "null"]`) in stable `v2/GetAccountResponse.json` (always emitted in `account/read` result keys `["account", "requiresOpenaiAuth", "userId", "workspaceRouting"]`, and populated with a non-null string only when the active provider's account is a ChatGPT account with a JWT user ID) and implements `account/securitySetup/read` (`notice` keys `["accountId", "action", "description", "title", "userId"]`, `action` keys `["label", "url"]`). Replacing only the loopback notice payload with `mode`/`setupUrl` yields `notice: null` (`noticeKeys: []`).

2. **Schema-vs-Wire Experimental Leak (`workspaceRouting`):**
   - Across all four stock binaries, `GetAccountResponse.workspace_routing` (`routingKeys`: `["accountRoutingOverride", "backendOrigin", "chatgptAccountId"]`) is annotated with `#[experimental("account/read.workspaceRouting")]` (`codex-rs/app-server-protocol/src/protocol/v2/account.rs:593`).
   - Stable schema generation (`generate-json-schema` without `--experimental`) omits `workspaceRouting` from `v2/GetAccountResponse.json` `properties`, **but** runtime outgoing filtering (`codex-rs/app-server/src/transport.rs:178-198`) only strips experimental fields on `ServerRequest::CommandExecutionRequestApproval`, never on `OutgoingMessage::Response`. Consequently, `account/read` emits `"workspaceRouting"` on the wire even when `experimentalApi: false`.

3. **Why Experimental `account/read.workspaceRouting` Is Rejected as an Identity Authority:**
   - Although `pairMatches` (`notice.accountId == workspaceRouting.chatgptAccountId && notice.userId == accountRead.userId`) is `true` in the static positive fixture on `0.169.0-alpha.7`, measured direct-stdio loopback probes demonstrate that experimental `workspaceRouting` + cached `account/read` cannot safely verify `account/securitySetup/read`:
     1. **In-Flight External File Race (`external-file-race` at the `/backend-api/wham/security-setup` HTTP gate):** When `auth.json` on disk is atomically replaced with a new user and synthetic bearer while `GET /backend-api/wham/security-setup` is held in flight (leaving `app-server` memory untouched), the in-flight `account/securitySetup/read` response still contains the **original** user's notice (`firstNoticeExists: true`, `firstNoticeMatchesOriginalUser: true`), a subsequent `account/read(refreshToken: false)` **also** still returns that same old user (`laterSnapshotStillOriginal: true`), and a subsequent `account/securitySetup/read` returns `null` with total `/backend-api/wham/security-setup` HTTP hits still `1` (`laterNoticeExists: false`, `noticeHttpCount: 1`). Thus, a cached `account/read(refreshToken: false)` match **actually accepts a stale in-flight notice**.
     2. **In-Flight Logout Race (`logout-race` at the `/backend-api/wham/security-setup` HTTP gate):** When public `account/logout` completes while the loopback GET is held (`loggedOut: true`), the in-flight notice resolves to `null` (`firstNoticeExists: false`), subsequent `account/read` is signed out (`laterSnapshotSignedOut: true`), and a subsequent notice read is `null` with `noticeHttpCount: 1`.
     3. **Missing Selected Route (`missing-route` & `accounts-check-500`):** When `/backend-api/wham/accounts/check` omits the selected workspace or returns HTTP 500, `account/read` fails with JSON-RPC `-32603` (`accountError: -32603`, `accountKeys: []`, `routingKeys: []`, measured total `/backend-api/wham/accounts/check` HTTP hits `3`) while `account/securitySetup/read` independently returns a valid non-null notice (`noticeHttpCount: 1`, `pairMatches: false`).
     4. **Blank Account, Blank User, and Custom Provider Controls (`empty-account`, `empty-user`, `custom-provider`):**
        - Blank fixture `account_id`: `account/read` returns `-32603`, while `account/securitySetup/read` returns a non-null blank-account notice (`blankNoticeAccount: true`, `pairMatches: false`).
        - Blank fixture user ID: `account/read` and `account/securitySetup/read` both return blank user strings (`blankNoticeUser: true`, `pairMatches: true`).
        - Measured synthetic `custom-provider`: `account/read` returns `account: null`, `userId: null`, and `workspaceRouting: null` (`accountPresent: false`, `routingKeys: []`), while `account/securitySetup/read` returns a non-null notice (`pairMatches: false`).

---

## 2. Binary, Bundle, and Source Provenance

| Artifact Role | Path / Ref | Version | SHA-256 / Commit |
| :--- | :--- | :--- | :--- |
| Installed Desktop Stock | `/opt/codex-desktop/resources/codex` | `codex-cli 0.167.0-alpha.3.2` | `c8242fc9e1bac7c6d661a228cecfaf50e6db74da219e4a9ca8912827e11607f0` |
| Official Public Stable | `/tmp/native-f24-public-stock.kHdq5U/codex` | `codex-cli 0.167.0` | `cdcb45aaa01d0f14e298985e09465aebccd47f64ecd298aea44814af7b62bbda` |
| Desktop-Train Public Alpha | `/tmp/native-f25-desktop-train.8q6EXA/codex` | `codex-cli 0.167.0-alpha.4.1` | `c3dea068c8794f1764051c1fd182ff0524352bbddf2f2638e72386b9b74368` |
| Higher Public Alpha | `/tmp/native-f24-public-alpha.xQsk4m/codex` | `codex-cli 0.169.0-alpha.7` | `b20e3a2f9a25ae9e4b29bfe68ef337757d818f85087ac701d745833894f04c7d` |
| Bundled Native Host | `build/linux/x64/debug/bundle/codex-native-host` | workspace debug bundle | `990c9e3af7d1a13e46cc5b2bb2233c9eac1330e2d697263ffdfffc67567ff474` |
| Official Desktop Bundle | `/opt/codex-desktop/resources/app.asar` | `26.1103.60933` (build `25894`) | `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14` |
| Upstream `rust-v0.169.0-alpha.7` | `/tmp/native-f26-stock-source.uBveEm` | tag `367d997f42430c9260ef8e6bdc00b3aebc2aee3c` | peeled commit `25da1b0cb5e876882f8b1fafe186cdfcf3c712cc` |
| Upstream `origin/main` | `/tmp/native-f26-stock-source.uBveEm` | `origin/main` | `4dcd8df891ad38ed7d4ea59c44b817c293ffc0e2` |

---

## 3. Reproducible Loopback Methodology

1. **Transport Modes Verified:**
   - **Direct Stock Stdio:** `<codex-binary> app-server --listen stdio://` (used by `/tmp/native-f27-account-audit.T6YXqD/{probe,race,edge}.py`).
   - **Bundled Native Host Stdio:** `./build/linux/x64/debug/bundle/codex-native-host --codex <codex-binary> --cache-dir <fixture-spool-dir>`.
2. **Fixture Layout:**
   - Temporary `CODEX_HOME` directory with `config.toml` setting `chatgpt_base_url = "http://127.0.0.1:<port>/backend-api/"` and `cli_auth_credentials_store = "file"`, plus `auth.json` containing disposable unsigned JWT claims and synthetic tokens.
   - Local `ThreadingHTTPServer` on `127.0.0.1:<port>` serving `/backend-api/wham/accounts/check`, `/backend-api/wham/config/bundle`, and `/backend-api/wham/security-setup`.
3. **HTTP Hit Accounting:**
   - Reported `/backend-api/wham/accounts/check` and `/backend-api/wham/security-setup` counts are **measured total loopback HTTP hits** during each probe run and do not establish internal retry ownership.

---

## 4. Measured Loopback Observations

### 4.1 Cross-Binary Preflight (`positive` fixture, Direct Stdio & Bundled Host)

| Binary | Transport Verified | `experimentalApi` | `accountError` | `accountKeys` | `routingKeys` | `noticeError` | `noticeKeys` | `actionKeys` | `pairMatches` | Measured Total Loopback Hits (`accounts/check` / `security-setup`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `0.167.0-alpha.3.2` | Direct stdio + `codex-native-host --codex` | `false`, `true` | `null` | `["account", "requiresOpenaiAuth", "workspaceRouting"]` | `["accountRoutingOverride", "backendOrigin", "chatgptAccountId"]` | `-32600` | `[]` | `[]` | `false` | `1` / `0` |
| `0.167.0` | Direct stdio + `codex-native-host --codex` | `false`, `true` | `null` | `["account", "requiresOpenaiAuth", "workspaceRouting"]` | `["accountRoutingOverride", "backendOrigin", "chatgptAccountId"]` | `-32600` | `[]` | `[]` | `false` | `1` / `0` |
| `0.167.0-alpha.4.1` | Direct stdio + `codex-native-host --codex` | `false`, `true` | `null` | `["account", "requiresOpenaiAuth", "workspaceRouting"]` | `["accountRoutingOverride", "backendOrigin", "chatgptAccountId"]` | `-32600` | `[]` | `[]` | `false` | `1` / `0` |
| `0.169.0-alpha.7` | Direct stdio + `codex-native-host --codex` | `false`, `true` | `null` | `["account", "requiresOpenaiAuth", "userId", "workspaceRouting"]` | `["accountRoutingOverride", "backendOrigin", "chatgptAccountId"]` | `null` | `["accountId", "action", "description", "title", "userId"]` | `["label", "url"]` | `true` | `1` / `1` |

### 4.2 Higher-Alpha (`0.169.0-alpha.7`) Boundary & Control Cases (Direct Stdio)

| Case | `accountError` | `accountKeys` | `accountPresent` | `routingKeys` | `noticeKeys` / `actionKeys` | `blankNoticeAccount` / `blankNoticeUser` | `pairMatches` | Measured Total Loopback Hits (`accounts/check` / `security-setup`) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `bad-notice-shape` (`mode`/`setupUrl` payload) | `null` | `["account", "requiresOpenaiAuth", "userId", "workspaceRouting"]` | `true` | `["accountRoutingOverride", "backendOrigin", "chatgptAccountId"]` | `[]` / `[]` (`notice: null`) | `false` / `false` | `false` | `1` / `1` |
| `missing-route` | `-32603` | `[]` | `false` | `[]` | `["accountId", "action", "description", "title", "userId"]` / `["label", "url"]` | `false` / `false` | `false` | `3` / `1` |
| `accounts-check-500` | `-32603` | `[]` | `false` | `[]` | `["accountId", "action", "description", "title", "userId"]` / `["label", "url"]` | `false` / `false` | `false` | `3` / `1` |
| `unselected-workspace` (`tokens.account_id: null`) | `null` | `["account", "requiresOpenaiAuth", "userId", "workspaceRouting"]` | `true` | `[]` (`null`) | `[]` / `[]` (`notice: null`) | `false` / `false` | `false` | `0` / `0` |
| `missing-user` (`chatgpt_user_id` omitted) | `null` | `["account", "requiresOpenaiAuth", "userId", "workspaceRouting"]` | `true` | `["accountRoutingOverride", "backendOrigin", "chatgptAccountId"]` | `[]` / `[]` (`notice: null`) | `false` / `false` | `false` | `1` / `0` |
| `empty-account` (`tokens.account_id: ""`) | `-32603` | `[]` | `false` | `[]` | `["accountId", "action", "description", "title", "userId"]` / `["label", "url"]` | `true` / `false` | `false` | `0` / `1` |
| `empty-user` (`chatgpt_user_id: ""`) | `null` | `["account", "requiresOpenaiAuth", "userId", "workspaceRouting"]` | `true` | `["accountRoutingOverride", "backendOrigin", "chatgptAccountId"]` | `["accountId", "action", "description", "title", "userId"]` / `["label", "url"]` | `false` / `true` | `true` | `1` / `1` |
| `custom-provider` (measured custom `model_provider`) | `null` | `["account", "requiresOpenaiAuth", "userId", "workspaceRouting"]` | `false` | `[]` (`null`) | `["accountId", "action", "description", "title", "userId"]` / `["label", "url"]` | `false` / `false` | `false` | `0` / `1` |
| `fedramp-claim` (`chatgpt_account_is_fedramp: true`) | `null` | `["account", "requiresOpenaiAuth", "userId", "workspaceRouting"]` | `true` | `["accountRoutingOverride", "backendOrigin", "chatgptAccountId"]` | `[]` / `[]` (`notice: null`) | `false` / `false` | `false` | `1` / `0` |

### 4.3 Higher-Alpha (`0.169.0-alpha.7`) In-Flight Races at the Notice HTTP Gate (Direct Stdio)

| Race Variant | Gate Mutation While `GET /backend-api/wham/security-setup` Is Held | `loggedOut` | `firstNoticeExists` | `firstNoticeMatchesOriginalUser` | `laterSnapshotStillOriginal` | `laterSnapshotSignedOut` | `laterNoticeExists` | Measured Total `noticeHttpCount` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `external-file-race` | Atomic `auth.json` replacement on disk (new user + new synthetic bearer; `app-server` memory untouched) | `false` | `true` | `true` | `true` | `false` | `false` | `1` |
| `logout-race` | Public `account/logout` RPC completed before releasing HTTP gate | `true` | `false` | `false` | `false` | `true` | `false` | `1` |
| `external-tokens-login-race` | Public `account/login/start` (`chatgptAuthTokens` for second user/workspace) completed before releasing HTTP gate | `false` | `false` | `false` | `false` | `false` | `false` | `1` |

---

## 5. Source-Only Inferences (`25da1b0cb5e876882f8b1fafe186cdfcf3c712cc`)

The following observations come strictly from static source inspection of peeled commit `25da1b0cb5e876882f8b1fafe186cdfcf3c712cc` (`rust-v0.169.0-alpha.7^{commit}`):

1. **`get_account_security_setup` (`codex-rs/app-server/src/request_processors/account_processor/security_setup.rs:25-115`):**
   - **Pre-GET Check (`lines 28-48`):** Reads active `(auth, factory)` from `auth_manager`, records `source_generation`, loads `saved` from `config.auth_config().load_auth(/*enable_codex_api_key_env*/ false)`, and requires `matches!(saved, CodexAuth::Chatgpt(_)) && !saved.is_fedramp_account()` and `auth.auth_mode() == AuthMode::Chatgpt && saved.get_token().ok()? == auth.get_token().ok()?`.
   - **URL & Copy Forwarding (`lines 49-88`):** Appends `/wham/security-setup` to `config.chatgpt_base_url.trim_end_matches('/')`, sends `chatgpt-account-id`, parses `Response { notice: Option<Notice { title, description, action }> }`, and forwards copy/URL without server-side validation.
   - **Post-GET Check (`lines 89-101`):** Calls `self.auth_manager.auth().await?` (in-memory `AuthManager` state, **not** re-loading `auth.json` from disk) and compares `source_generation`, `auth_mode`, `account_id`, `user_id`, and `is_fedramp_account()`.

2. **`read_account` & Model-Provider Branches (`codex-rs/app-server/src/request_processors/account_processor/workspace_routing.rs:337-368`):**
   - Calls `create_model_provider(config.model_provider.clone(), Some(self.auth_manager.clone())).account_state()?`.
   - In `codex-rs/model-provider`:
     - `DefaultModelProvider::account_state` (`src/provider.rs:655-696`) returns `account: None, requires_openai_auth: false` when `requires_openai_auth` is `false` (matching the measured `custom-provider` case).
     - `GcpModelProvider::account_state` (`src/gcp/mod.rs:112-117`) returns `account: Some(ProviderAccount::Gcp), requires_openai_auth: false`.
     - `AmazonBedrockModelProvider::account_state` (`src/amazon_bedrock/mod.rs:399-410`) returns `account: Some(ProviderAccount::AmazonBedrock { .. }), requires_openai_auth: false`.
   - In `workspace_routing.rs:345-364`, `user_id` and `workspace_routing` (for `account/read`, where `request` is `None`) are populated only when `matches!(account_state.account, Some(ProviderAccount::Chatgpt { .. }))`.

3. **`codex-tui` Client Validation & UUID Invalidation (`25da1b0`):**
   - `prefetch` (`codex-rs/tui/src/security_setup.rs:69-71`) gates on `config.model_provider_id == "openai" && !server.uses_remote_workspace()`, validates `Notice::valid()` (`lines 44-60`), and re-loads `config.auth_config().load_auth(false)` after the RPC returns (`lines 100-109`) to compare `Identity::from_auth(&current) == Some(identity)`.
   - On `ServerNotification::AccountUpdated` (`codex-rs/tui/src/app/app_server_events.rs:403-408`), TUI calls `self.chat_widget.invalidate_security_setup()`.
   - `ChatWidget::invalidate_security_setup` (`codex-rs/tui/src/chatwidget/security_setup.rs:27-32`) assigns a fresh `self.security_setup_request_id = uuid::Uuid::new_v4()` and clears any presented security-setup banner.
   - `AppEvent::SecuritySetupLoaded` dispatch (`codex-rs/tui/src/app/event_dispatch.rs:1600-1604`) checks `request_id == self.chat_widget.security_setup_request_id` (`Uuid` equality) before calling `show_security_setup` (distinct from `rate_limit_hard_stop_generation.wrapping_add(1)` at `app_server_events.rs:415-416`).

---

## 6. Rejected Experimental Path vs Future Verified Public Contract

1. **Rejected Experimental Path (`account/read.workspaceRouting.chatgptAccountId` + Cached `account/read`):**
   - Using `account/read.workspaceRouting.chatgptAccountId` and cached `account/read.userId` to verify `account/securitySetup/read` is **rejected**:
     - `external-file-race` proves that a cached `account/read(refreshToken: false)` check still matches and accepts a stale in-flight notice after `auth.json` has already switched owners on disk.
     - `missing-route` / `/backend-api/wham/accounts/check` errors fail `account/read` with `-32603` while `account/securitySetup/read` succeeds.
     - `empty-user` satisfies equality on blank user IDs, and `workspaceRouting` remains an experimental schema surface (`#[experimental("account/read.workspaceRouting")]`).
2. **Future Verified Public Contract (`RESEARCH_EXHAUSTED` Until Upstream Stock Support):**
   - Keep `account/securitySetup/read` classified as **`RESEARCH_EXHAUSTED` (Deferred / Blocked on Stable Stock Identity Contract)**.
   - Any future Native client adoption must rely on a verified public `app-server` contract (for example, stock `app-server` performing post-GET persisted-store identity verification, provider gating, and `Notice::valid()` checks directly inside `account/securitySetup/read`, or exposing a non-routing-coupled, generation/store-verified identity authority on public RPCs) rather than reading `auth.json` in the client/Host or trusting experimental `workspaceRouting`.
