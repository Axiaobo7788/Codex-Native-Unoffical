# Plugin catalog and installed snapshot evidence

Measured 2026-11-10 from Native `a755915`, its bundled Host, and four
stock app-server builds. This slice compares catalog responses,
installed snapshots, and the current Native projection.

## Stock contract and reference client

- The generated installed stable schema includes `plugin/list`,
  `plugin/installed`, `plugin/read`, and `plugin/skill/read`. The
  latter takes `remoteMarketplaceName`, `remotePluginId`, and
  `skillName`. Its stable registration establishes the RPC shape.
  This probe exercised local marketplaces and local `plugin/read`.
  [Stock protocol registration at `39b42aa`](https://github.com/openai/codex/blob/39b42aaacdbb55b86528b4294443696985c348ee/codex-rs/app-server-protocol/src/protocol/common.rs)
- `plugin/list` is a marketplace catalog. `plugin/installed` loads
  installed entries and can include explicitly suggested available
  entries. Both return `marketplaces` and `marketplaceLoadErrors`.
  Source also allows authenticated remote catalog and sync work in
  applicable configurations. The disposable probe disabled remote
  plugins and used an isolated account-free configuration.
  [Stock plugin request processor](https://github.com/openai/codex/blob/39b42aaacdbb55b86528b4294443696985c348ee/codex-rs/app-server/src/request_processors/plugins.rs)
- In installed Desktop ASAR `26.1103.60933` build `25894`,
  SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`,
  renderer `webview/assets/async/283932.a6fa53fa90.js` at byte `38690`
  sends a local-marketplace `plugin/list`. The renderer at
  `webview/assets/async/497066.82fad48b12.js` byte `74512` sends
  `plugin/installed` for a scoped installed-plugin action. The
  background installed query at byte `6697336` in
  `webview/assets/async/182735.5b42af8792.js` is a separate call
  site. These are static request paths in the inspected bundle.

## Disposable real-runtime matrix

For each binary, create an isolated `HOME` and `CODEX_HOME`, a local
Git workspace with a valid marketplace, a plain empty workspace, and
a trusted workspace with deliberately invalid project configuration.
The valid catalog has one installed enabled fixture, one installed
disabled fixture, and one available fixture. Seed another installed
cache entry outside the catalog. Configure `remote_plugin = false`,
use a loopback account base URL in the disposable profile, and disable
Git network protocols. Initialize without experimental opt-in.

| Stock | Clean empty rows/errors | Invalid-only rows/errors | Mixed catalog rows/errors | Mixed installed rows/errors | Installed with explicit suggestion rows/errors |
|---|---:|---:|---:|---:|---:|
| Installed `0.167.0-alpha.3.2` | 0 / 0 | 0 / 1 | 3 / 1 | 2 / 1 | 3 / 1 |
| Public stable `0.167.0` | 0 / 0 | 0 / 1 | 3 / 1 | 2 / 1 | 3 / 1 |
| Desktop-train `0.167.0-alpha.4.1` | 0 / 0 | 0 / 1 | 3 / 1 | 2 / 1 | 3 / 1 |
| Public alpha `0.169.0-alpha.7` | 0 / 0 | 0 / 1 | 3 / 1 | 2 / 1 | 3 / 1 |

- Query `plugin/list` with the local kind against mixed,
  clean-empty, and invalid-only sources. The Native-shaped query
  without a kind filter yielded the same invalid and mixed counts
  in this account-free fixture. The invalid source produced an
  error inside a successful response, including when it was the
  only source. A clean empty response had zero errors.
- Query `plugin/installed` with both valid and invalid roots. It
  reported the enabled and disabled installed entries. Passing
  `installSuggestionPluginNames` added the available fixture with
  both `installed` and `enabled` false. The catalog-orphaned cache
  entry was absent from both response families in this fixture.
- Read the available fixture by its local `marketplacePath` and
  `pluginName`. `plugin/read` returned a summary with both
  `installed` and `enabled` false in all four runs.
- An independent typed Dart probe used Native `ProcessTransport`
  and the bundled Host with installed and higher-alpha stock.
  `listPlugins` returned zero rows for both clean empty and
  invalid-only responses. It returned the three mixed rows with
  the measured flags and `readPlugin` preserved the available
  fixture state. Native currently projects `marketplaces` and
  drops `marketplaceLoadErrors`, so the two zero-row outcomes
  appear identical to the presentation layer.

## Native scope

Section-level RPC error and loading isolation can use the existing
typed lists. An empty projected list supports the narrower claim
that the catalog returned zero visible entries. A future typed
catalog snapshot could carry a bounded partial-result summary and
keep rows usable when another source fails. `plugin/installed`
should be scoped and labeled according to its actual marketplace
and suggestion behavior. This evidence leaves the installed view
and partial-result projection as separate convergence candidates.
