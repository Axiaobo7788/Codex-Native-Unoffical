# Scoped installed plugin inventory evidence

Measured 2026-11-10 against Native `8c64783`, its bundled Host
`1de94c6ad8ff026e5e7a8318547409700f7b2ffd5c51add3faa64096957547f9`,
and stock public source `c875667`. The four binaries were installed
`0.167.0-alpha.3.2`, public stable `0.167.0`, Desktop-train
`0.167.0-alpha.4.1`, and public alpha `0.169.0-alpha.7`.

## Request and scope

- Both `plugin/list` and `plugin/installed` are stable stock requests.
  The latter accepts optional working directories and explicit
  uninstalled suggestion names. Its schema has no cursor, limit,
  marketplace-kind selector, or request-level local-only flag.
  Stock returns `marketplaces` and `marketplaceLoadErrors`.
  [Protocol at `c875667`](https://github.com/openai/codex/blob/c875667eb837663697d5ffa32d375043434e73b4/codex-rs/app-server-protocol/src/protocol/v2/plugin.rs#L144-L197)
- In Desktop `26.1103.60933` build `25894`, renderer
  `webview/assets/async/497066.82fad48b12.js` at byte `74511`
  sends `plugin/installed` with a single applicable cwd or null.
  Its adjacent flow has an uninstall action. Renderer
  `webview/assets/async/182735.5b42af8792.js` at byte `6697335`
  also issues a background inventory query with optional cwds.
  These are static call sites from the installed ASAR.
  [ASAR identity and prior catalog evidence](PLUGIN_CATALOG_TRUTH_EVIDENCE.md)

## Four-stock Host results

Each disposable profile had one home marketplace, two trusted Git
workspaces with distinct marketplaces, and a workspace with a malformed
marketplace manifest. The home catalog listed 128 entries. Project A
listed three, including a disabled installed fixture, a configured
fixture with no initial cache, and one available suggestion. Project B
included an enabled installed fixture and the same suggestion name.
One configured cache entry was absent from the manifests. No account
was configured. Remote plugins were disabled, the disposable account
base URL was loopback, and Git network protocols were disabled.

| Call in the measured sequence | Result across all four builds |
|---|---|
| `plugin/list`, project A, default or explicit local kind | 131 entries. The project A installed row appeared at zero-based offset 128. |
| `plugin/installed`, cwd omitted or empty | Two home fixtures, one enabled and one disabled. |
| `plugin/installed`, project A | Four entries after the catalog call materialized the configured fixture. An isolated first installed query returned three. |
| `plugin/installed`, project B | Three entries from home and project B. |
| `plugin/installed`, A and B | Five entries across the three marketplaces. |
| Same scopes with one matching and one absent suggestion name | Eight entries. The three added rows shared the requested name and had `installed: false` and `enabled: false`. |
| `plugin/installed`, malformed marketplace | Two home entries and one marketplace error. |
| `plugin/installed`, project A and malformed marketplace | Four valid installed rows and one marketplace error after the earlier catalog calls. |

The seeded orphan cache appeared in none of these responses. The
131-row catalog reply measured 71,080 bytes in the sampled default
request. The project A installed reply after materialization measured
2,575 bytes. These are response measurements for the fixture.

## Query effects and timing

The initial sequence changed a disposable cache manifest. Separate fresh
profiles per query attributed the change on all four builds. A 400 ms
initialization-only interval, a sample immediately after the selected
reply, a second sample 550 ms later, and process exit separated startup
from the query.

- Initialization alone in the neutral workspace or project A did
  not change the selected config or cache manifests.
- One `plugin/list` call for project A created the previously absent
  configured plugin cache manifest. Both the default and explicit local
  kind did so with `forceRefetch` omitted. The first returned row still
  reported `installed: false, enabled: true`. Later reads saw the newly
  installed entry. Existing seeded manifest hashes and config matched.
- Isolated `plugin/installed` calls for home or project A did not
  change the observed fixture config or cache manifests. The project A
  query returned three installed rows and omitted the uncached configured
  fixture. This checks the selected files and timing in an account-free
  local profile.
- Public source schedules non-curated local cache refresh from
  `plugin/list`. It also conditionally schedules remote installed-bundle
  sync from both list routes. The installed route can start that work
  when the applicable plugin configuration and authentication allow
  it. Authenticated sync and production services were outside the probe.
  [Catalog background task call](https://github.com/openai/codex/blob/c875667eb837663697d5ffa32d375043434e73b4/codex-rs/app-server/src/request_processors/plugins.rs#L798-L818) ·
  [Installed query](https://github.com/openai/codex/blob/c875667eb837663697d5ffa32d375043434e73b4/codex-rs/app-server/src/request_processors/plugins.rs#L847-L902) ·
  [Stock sync and cache scheduler](https://github.com/openai/codex/blob/c875667eb837663697d5ffa32d375043434e73b4/codex-rs/core-plugins/src/manager.rs#L1755-L1799)

## Native implications

Actual Native `ProcessTransport.listPluginCatalog` retained 100 rows
on installed stock and public alpha. It kept the two home-installed
rows, omitted the project A installed row at offset 128, and reported
no partial-source error. The Linux package displayed `Plugins (100)`
at 1280×720 and 720×800. The test-owned app, Host and stock exited.

An Installed filter over the retained catalog would inherit that
omission. A distinct installed query has useful source scope and
smaller measured results, but it has separate stock sync behavior and
no upstream page size. A user-facing installed inventory remains
`RESEARCH_MORE` until its admission and effects are specified. The
existing catalog can independently disclose its 100-row truncation
without broadening scope, invoking another route, or raising the cap.
