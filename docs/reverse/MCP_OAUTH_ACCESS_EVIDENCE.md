# Local Desktop MCP authentication access

Current Track F work, based on `deb70761f3ebbe32de878b3cd7bc0ff5da400a5c`.
The Native access source passes focused and real-stock checks; packaged replay
and peer review remain pending. This document separates the supported stock
contract from the client projection and each validation level.

## Official and stock evidence

- Installed Desktop build `25894`, ASAR SHA-256
  `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`:
  `webview/assets/async/548929.7a0b4cbb28.js` contains the MCP settings manager
  and server row. The observable action is **Authenticate** on a
  `notLoggedIn` server. Starting is a separate pending state; a retained
  authorization handoff can reopen the browser rather than creating another
  request. An already authenticated row does not expose this action. Other
  import-manager consumers (`603466.87b1a31e74.js`,
  `837769.5833a3e219.js`) likewise use a server-name login and reuse the
  retained handoff. This is static component evidence, not a matched signed-in
  screenshot or account acceptance.
- Current installed/public stable schemas have stable
  `mcpServer/oauth/login` and `mcpServer/oauthLogin/completed`. The request
  requires a server name; thread scope, timeout, scopes and client registration
  are optional. The result has an authorization URL and an optional login ID.
  Completion has a server name/success flag and optional login/thread IDs.
- Public stock source `c875667eb837663697d5ffa32d375043434e73b4`
  corroborates asynchronous completion and stock-owned OAuth exchange/storage.
  It is not asserted to be the exact installed Desktop source revision.
- Actual bundled Host → installed `0.167.0-alpha.3.2` and public `0.167.1`
  preflights both authenticated against a disposable loopback MCP/OAuth service.
  Each had one successful authorization/PKCE exchange, a correlated completion
  and `notLoggedIn` → `oAuth` readback. These preflights used raw protocol;
  they do **not** verify the new Native adapter or UI. Redacted results remain
  in `/var/tmp/native-mcp-oauth-installed-preflight-r1/` and
  `/var/tmp/native-mcp-oauth-public-01671-preflight-r1/`.

## Client scope and ownership

- The first access path is global configured-server authentication from the
  existing Desktop MCP status surface. It does not load or resume a thread.
  Per-thread overrides, custom scopes/registration controls and other settings
  are not implied by this first global access path.
- `McpOauthGateway` is an optional local gateway. Remote remains read-only;
  neither Remote permission admission nor the mobile product is expanded.
- The protocol adapter owns wire names/validation. Domain/transport stay pure
  Dart. Runtime relays typed completion plus a distinct client invalidation
  event; widgets do not parse JSON.
- One app-scoped controller owns at most one pending handoff, one early
  completion, one deadline and scalar state. Wide Customize and the compact
  dialog observe it without owning its lifetime. Navigation/resize does not
  create a second flow. Runtime invalidation and app disposal make late
  responses/browser results ineligible to update it.
- Server, optional login ID and global scope must match. Older stock omitting
  both login IDs uses the documented name/global fallback. An unknown/stale ID
  cannot establish success. A matching completion triggers fresh server-status
  readback, coalesced behind an in-flight status/reload operation.
- The transport retains one raw login-start slot until the actual RPC settles.
  A UI timeout cannot cancel that request or justify accumulating more pending
  requests. Expiry is reported as unconfirmed, not as a successful cancellation.
  No MCP OAuth cancellation/logout RPC has been fabricated.
- The launcher receives a bounded absolute HTTP(S) URI without userinfo.
  Provider errors, authorization URLs and credentials are not echoed in notices
  or persisted by the Native UI. Stock remains responsible for the exchange and
  credential store. The browser can be retried using the same handoff.

## Validation and remaining gates

Format (203 files, zero changes), strict analysis and the standalone 68-root
pure-Dart compile pass. The four focused files pass 33 cases. The first strict
lint and compact test timing failure are retained in the `r1` logs; the latter
needed a post-build frame to render asynchronously returned status, not a
production route change. Corrected product `r2` and full focused `r3` pass.

- Adapter tests: global/legacy contract, identity projection, malformed
  completion, invalid arguments and unsafe/oversized handoffs.
- Controller tests: one active flow, browser retry, completion identity and
  ordering, startup/completion deadlines, runtime invalidation, disposal and
  generic provider failure.
- Process tests: one unsettled raw start and shutdown settlement/rejection.
- Simulated-runtime product tests: wide navigation, compact close/reopen,
  authenticated readback and a completion during a stale status read.
  These are typed product integrations, not full-process E2E.
- `tool/mcp_oauth_smoke.dart`: pure-Dart real ProcessTransport → bundled Host →
  stock, with a bounded disposable loopback provider. It checks actual PKCE,
  typed correlated completion and authenticated readback without a real account
  or model. Installed `0.167.0-alpha.3.2` and public `0.167.1` both pass via the
  unchanged bundled Host `73218b92…`. Logs are
  `/var/tmp/native-ui-r0.BbOvHT/mcp-oauth-{installed,public-01671}-smoke-r1.log`.
- A packaged Native walkthrough, browser-handoff failure/retry and clean owned
  process teardown remain pending. Human/external-provider acceptance remains
  separate. The product matrix must not become MATCH from authored tests alone.

Heavy validation remains serialized. Gemini explicitly released its U2 slot;
Codex now owns it while Gemini performs light-only peer review.
