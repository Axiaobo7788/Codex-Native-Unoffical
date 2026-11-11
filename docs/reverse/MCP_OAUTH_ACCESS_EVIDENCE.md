# Local Desktop MCP authentication access

Current Track F work, based on `deb70761f3ebbe32de878b3cd7bc0ff5da400a5c`.
Published Native access source `0cdf0e8` passes shared gates, peer correction
and packaged replay. A subsequent default-timeout correction is authored but
targeted-verified; combined release gates are pending. This document separates the supported stock
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
- One app-scoped controller owns at most one pending handoff, eight early
  outcomes keyed by exact login ID, one deadline and scalar state. Wide Customize and the compact
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
- Source-bound packaged replay now passes as recorded below. Human/external-
  provider acceptance remains separate; earlier counts above are historical
  focused evidence, not the latest shared result.

Heavy validation remains serialized. After the completed `0cdf0e8` gates and
owned runtime teardown, Codex released the slot to Gemini for U3, and Gemini has now explicitly
returned it after its source/captures. Codex owns current combined validation.

## Targeted peer review and corrections

Gemini independently reviewed source `beac41f` through the official `agy` TUI.
No P0/P1 was found. Two P2s were reproduced with red tests before correction:

1. A late old login completion overwrote the current early completion, leaving
   the controller waiting and reopening a consumed handoff. A fixed eight-ID
   buffer now selects the response's exact ID and clears on response/finish.
2. A retained wide Customize controller and compact dialog both refreshed MCP
   status on completion. Readback now belongs to the visible/current-route
   surface. Hidden state remains alive, including mutation ownership; reactivation
   reconciles its missed completion. A modal remains open when resized wide.

That replay exposed a directly coupled keyboard defect: constructing the wide
shell behind the modal requested background Customize focus, so Escape did not
close the dialog. A separate red test reproduced it. Post-frame focus restoration
now checks route ownership. Hidden notices still update so a completed login
cannot leave a stale loading animation running behind the modal. The first
correction exposed that animation timeout and is retained as negative evidence.

Strict analysis and 42 focused MCP/runtime/navigation cases pass after these
corrections. A fresh `0cdf0e8` shared run passes 603 default cases plus five
opt-in skips and five separately enabled real-stock cases. The 601-case pass at
`0ecb27d` predates these corrections and remains separately source-bound. Logs are under
`/var/tmp/native-ui-r0.BbOvHT/mcp-oauth-peer-*` and
`mcp-oauth-wide-modal-focus-red-r1.log`.

The suggested login-ID trimming change was rejected: IDs are opaque and must
match exactly. A focused test confirms that differently padded IDs cannot grant
success, while identical opaque IDs can. Stock's generated response/completion
IDs correlate in both live smoke runs. Malformed completion notifications remain
typed protocol errors and conservatively make the active flow unconfirmed; the
client does not infer authentication success from invalid wire data. A legitimate
stock cross-scope notification that contradicts this policy has not been observed.
That evidence boundary stays explicit rather than adding a scoped-error framework
from synthetic malformed notifications alone.


## Packaged and shared checkpoint at `0cdf0e8`

All 376 tracked files were hashed before and after shared validation. Format
203 files/zero changes, strict analysis, 68-root pure-Dart compilation, history
100/1,000 plus ten 3 MiB discarded outputs, Rust fmt/Clippy/100 tests, two-job
Linux release/83-library closure, existing MCP smoke and new installed/public
OAuth smoke pass. Exact branch CI `43101623112` passes all three platforms.
The default Flutter suite above mixes unit, widget and typed simulated product
integration; its count is not a full-process E2E claim.

Frozen bundle: `/var/tmp/native-desktop-mcp-u2-0cdf0e8-r1/`, AOT
`b99abbd6165f68a260cff793ae996e6f0e027953277af94dd9fe25d510960a51`,
Host `73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878`.
Its source manifest and per-file hashes bind the captures to this source.

- Installed success profile: pending authentication survives navigation,
  1191×865 → 720×800 → wide, compact close/reopen, resizing while the modal is
  retained and retrying the same handoff. Completion/readback shows `oAuth`;
  Escape closes the widened modal. One authorization/exchange and 20
  authenticated MCP calls were observed.
- Public `0.167.1`: completion and Reload config retain `oAuth`. After full
  App/Host/stock teardown and a new app process, the same private profile reads
  authenticated status without another authorization. One authorization/exchange
  and 15 authenticated MCP calls were observed. This is stock credential
  persistence, not in-app crash recovery.
- Both successful profiles created zero threads and had no observed
  overflow/Unhandled failure. Owned App/Host/stock/Xvfb/provider/portal/DBus
  workers exited. Private driver/accessibility warnings remain recorded.
- Initial installed setup had no valid URI handler: launch API accepted a URI,
  but no callback occurred; stock later reported failure. Counters were zero.
  The successful runs used a controlled GIO `.desktop` URI handler constrained
  to the local fixture. Minimal portal OpenURI counters were zero, so no portal
  callback claim is made. Actual Chrome/external-provider/account and Human
  acceptance are not established.

## Default-timeout correction — targeted verified, combined gates pending

The final audit found a material configuration mismatch: Native forced 180
seconds, whereas the inspected official manager sends only the server name.
Public stock source `c875667e`, `perform_oauth_login.rs`, defines the omitted
OAuth timeout as 300 seconds and the request processor preserves omission.
The authored correction omits optional `timeoutSecs` by default, retains bounded
explicit overrides, and gives the client completion watchdog five minutes plus
five seconds. The watchdog is local observation, not backend cancellation.

Tests now assert name-only protocol and ProcessTransport requests, and that a
normal flow still waits after 190 seconds. The typed real-stock smoke now uses
omission too. An isolated `0cdf0e8` worktree reproduces both failures: forced `timeoutSecs:
180` and the prematurely expiring controller. Corrected format, strict analysis,
68-root pure-Dart compilation and 43 focused cases pass. Both installed/public
real Host-backed OAuth smoke runs pass with timeout omitted. The first focused
command accidentally named two nonexistent test files; it was corrected and
rerun, not treated as a product failure. Logs are `mcp-timeout-*` under
`/var/tmp/native-ui-r0.BbOvHT/`. Fresh combined release/shared gates remain
pending; prior `0cdf0e8` CI/captures do not validate this new source.

Concurrent different-server authentication and custom scope/registration/thread
overrides remain separate research. The first global path serializes one
app-level pending flow; this checkpoint does not establish all MCP workflow
parity or optional rich app UI support.
