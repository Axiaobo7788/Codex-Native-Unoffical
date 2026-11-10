# Research Notes

This document records implementation-relevant findings from upstream Codex and
other working clients. It is not a catalog of projects or an endorsement of
their architecture. Upstream behavior and measurements in this repository remain
authoritative.

## Current Codex Desktop UI fidelity

_Reviewed: 2026-11-06_

### Evidence boundary and sources

The official Codex Desktop UI is not published as an open Flutter or reusable UI
source tree. This review therefore ranks observable first-party product behavior
above secondary reconstructions and separates observed facts from the concrete
targets selected for this client.

Primary evidence:

- OpenAI's [Introducing the Codex app](https://openai.com/index/introducing-the-codex-app/)
  defines the Codex-specific hierarchy and workflow: independent agent threads
  grouped by projects, rapid switching among parallel work, in-thread change
  review, diff comments, editor handoff, worktrees, and shared CLI/IDE history
  and configuration.
- The current [ChatGPT Work and Codex](https://help.openai.com/en/articles/20001275-chatgpt-work-and-codex)
  documentation, updated on the review date, establishes a product transition:
  Codex now appears as a separate view inside the unified ChatGPT Desktop app,
  retains separate history, and remains the repository/local-tool experience.
  Its current model picker combines a default model/reasoning slider while an
  explicitly selected model exposes its available reasoning levels.
- The current [Composer predictions in Codex](https://help.openai.com/en/articles/20001601-composer-predictions-in-codex)
  article and its first-party screenshots show the current conversation visual
  language: restrained white/neutral canvas, a compact dark user bubble,
  unboxed assistant content, quiet message actions, a large rounded bordered
  composer, inline execution/model/effort controls, and a circular primary
  send/voice affordance. `Tab` accepts a prediction into the composer without
  sending it.
- The first-party launch/store imagery for the earlier standalone shell shows a
  narrow neutral sidebar, project folders with indented thread rows, compact
  navigation, a low-chrome thread header, a centered empty-state/composer, and
  changes/actions in the thread workspace. This is retained as Codex-specific IA
  evidence, not treated as the complete current shared application shell.
- OpenAI Codex issue
  [#22363](https://github.com/openai/codex/issues/22363) records a real long-chat
  regression where a hover-revealed side panel intercepted the conversation
  scrollbar. This project must keep every timeline scrollbar hit target clear;
  secondary panels require an explicit action and reserved layout space.

Secondary cross-checks:

- The current [Codex Desktop tutorial](https://coding.flowo.design/en/codex/07-desktop-app)
  describes the desktop workbench as a sidebar, center conversation, and optional
  right review/terminal/results region. It is a schematic cross-check, not an
  authority for exact pixels, shortcuts, or features.
- `STEVOHCODER/codex-desktop-recreation` records a clean-room behavioral
  comparison with project-grouped recents, light/dark modes, user bubbles,
  unboxed assistant messages, stop state, and a constrained composer. No license
  was identified in the reviewed repository and its evidence includes reverse
  engineering, so neither code nor assets are adopted.

The developer documentation URLs previously under
`developers.openai.com/codex/app` now redirect to general ChatGPT Learn pages.
That redirect and the current Help material are additional evidence that the
surface is moving. Static early-2026 screenshots alone cannot establish the
November-2026 product.

### Information architecture adopted here

Wide desktop uses one persistent application workspace rather than stacked
engineering cards:

```text
┌──────────── project/thread sidebar ────────────┬──────── conversation workspace ────────┐
│ New thread                                    │ title + runtime state + Changes/Stop   │
│                                               ├─────────────────────────────────────────┤
│ Threads                                       │ virtualized bounded timeline            │
│   project / working-directory group           │ user / assistant / tool / reasoning     │
│     selected thread                    status │ approval appears in the work flow        │
│     another thread                     status │                                         │
│                                               │ bounded diff replaces this center view   │
│ connection + Remote setup                     ├─────────────────────────────────────────┤
│                                               │ max-width composer + execution controls  │
└───────────────────────────────────────────────┴─────────────────────────────────────────┘
```

- The sidebar owns creation, project/working-directory grouping, thread
  selection/resume affordance, pagination, and compact connection/Remote entry.
  Runtime executable paths, process IDs, and server strings move out of the
  persistent top-level workspace and remain available only in a details surface
  or an actionable disconnected/error state.
- The conversation workspace owns its thread title, state, changes toggle, stop
  action, virtualized timeline, approvals, composer, and execution controls.
  Diff is a deliberate center-mode switch; command output is a bounded viewer.
- A third pane is not permanently opened in the first slice because current
  controller state has one bounded selected diff file and one bounded output
  window. The layout may reserve a future explicit panel, but must not introduce
  an empty panel or preload more data for visual parity.
- Project hierarchy is derived only from already retained thread `cwd` metadata.
  No filesystem crawl, repository hydration, or second project database is
  introduced. Groups are view projections; thread pagination and the 100-row
  retention cap remain authoritative.

### Density, geometry, and component states

The following values are implementation targets selected from the first-party
visual evidence and the native desktop constraints; they are not claimed as
extracted proprietary design tokens:

- Wide sidebar: 252 px target, resizable layout breakpoint near 760 px. Narrow
  mode uses an explicit sidebar drawer/sheet or mode switch, never a tall stacked
  page that places the composer below an independently scrolling thread card.
- Global toolbar/header: 48–52 px. Sidebar primary actions: 34–38 px. Thread
  rows: 38 px for one-line content and 48 px only when a visible secondary state
  is necessary. Selected rows use a quiet neutral fill plus a slim accent/strong
  text; hover uses a distinct weaker fill; keyboard focus uses a visible 2 px
  outline without changing layout.
- Conversation reading column and composer: 720–780 px preferred maximum inside
  the available workspace. Assistant content is unboxed. User content is
  right-aligned in a high-contrast compact bubble with a maximum width near 72%
  of the reading column. Tool/activity/reasoning items use concise rows with
  icon, label, status, and optional expandable detail rather than full chat
  bubbles.
- Composer: 14–18 px inner padding, 18–22 px outer radius, subtle one-pixel
  border and restrained shadow/elevation. The text field grows to a bounded
  height. Attach/add, execution policy, model/reasoning, and send/stop controls
  share one visual container; disabled and busy states remain legible.
- Small controls use 28–32 px visual height with at least 36 px pointer target
  where layout allows. Ordinary surface radii are 8–12 px; dialogs and composer
  may use 16–22 px. Borders are one physical/logical pixel depending on DPR;
  heavy nested card borders are avoided.
- Base desktop text is 13–14 px with 1.35–1.5 line height. Section labels and
  metadata are 11–12 px; thread/header titles 14–16 px; empty-state heading
  22–28 px. Monospace remains confined to code, diff, paths where selection
  benefits, and command output.
- Icons remain the platform-neutral Material symbol set for now, consistently
  sized at 16/18/20 px and never used as a copied OpenAI mark. Every icon-only
  action requires a tooltip and semantics label.

### Theme and visual language

- Define explicit light and dark neutral palettes plus semantic accent, success,
  warning, danger, diff-add, and diff-delete colors. The default follows system
  brightness. `ColorScheme.fromSeed()` is not a product color generator.
- Light mode uses a very light neutral sidebar, near-white conversation canvas,
  dark user bubble, restrained gray borders, and a cool blue focus/accent. Dark
  mode uses charcoal rather than pure black, layered neutral surfaces, softened
  white text, and adjusted semantic colors that preserve contrast.
- Material widgets remain useful for text input, selection, menus, dialogs,
  focus, keyboard, semantics, and platform behavior. Their final density,
  shapes, fills, overlays, typography, focus, and disabled states come from the
  project-owned theme/component layer.
- The visible product name remains `Codex Native` with an explicit `Unofficial`
  qualifier in About/details and documentation. No OpenAI logo, wordmark,
  proprietary illustration, or assertion of endorsement is used.

### Conversation and state language

- User: compact right-aligned bubble; preserve selectable prompt text.
- Assistant: unboxed Markdown in the reading column; streaming stays bounded
  plain text as already required, with a small live indicator and no per-token
  full-tree animation.
- Tool/activity: a compact neutral row with leading state icon, status label,
  summary, and lazy action. Reasoning remains visually quieter than assistant
  output and never exposes hidden chain-of-thought beyond the typed summary the
  server already supplies.
- Approval: an inline, high-attention but non-modal card immediately above the
  composer/timeline continuation, with risk text first, Reject secondary, and
  Approve once primary. Unknown/unsupported requests remain reject-only.
- Diff: explicit file navigator, aggregate `+/-` summary, selected-file-only
  virtualized rows, clear truncation state, and restrained add/delete tint.
- Output: terminal-like dark/neutral viewport in both themes, monospace rows,
  current byte-window metadata, truncation warning, and bounded First/Previous/
  Next/Tail controls. It must never concatenate pages in memory.
- Empty: project/thread selection and new-task states use a quiet centered
  heading and composer/primary action, not a diagnostic card. Loading uses local
  skeleton/progress indicators that preserve geometry. Errors show an actionable
  retry/details path. Disconnected/not-found states explain the runtime boundary
  and keep diagnostic data behind disclosure rather than occupying every frame.

### Resize, focus, keyboard, and scroll contract

- At wide widths the sidebar and conversation own independent virtualized
  scrolling. At narrow widths the sidebar is explicitly opened/closed while the
  conversation and composer remain continuously usable. No nested vertical page
  scroll owns both lists.
- The timeline scrollbar has a reserved, unobstructed right-edge hit target.
  Hover surfaces and future change/output panes cannot appear over it.
- `Tab` traversal follows sidebar actions, thread rows, header actions, timeline
  lazy actions, composer controls, and send. `Escape` closes dialogs/menus and a
  narrow sidebar. Enter sends only under the composer rule implemented for this
  client; multiline entry remains available through a modified newline action.
- A selected thread and keyboard focus are independent states. Hover, selected,
  focus, busy, disabled, error, and unread/attention states must each have a
  visible treatment and cannot rely on color alone.
- Auto-scroll remains conditional on being near the newest item. Loading older
  pages must preserve reading position. Switching threads must discard the old
  active projection exactly as the controller already does.

### Deliberate non-adoptions

- Do not reproduce the shared ChatGPT Chat/Work navigation, account surfaces,
  plugin browser, Automations, Skills, browser, sources panel, voice, composer
  predictions, worktrees, commit/PR controls, or cloud features unless an
  existing controller already provides their behavior. Visual fidelity is not
  authorization for new product or protocol scope.
- Do not copy official logos, icons, screenshots, CSS, packaged fonts, Electron
  assets, strings obtained only by reverse engineering, or third-party code.
- Do not convert the Flutter client to a WebView/Electron layout, hydrate full
  history, prefetch command output, build every diff file, or keep inactive
  thread widgets alive for animation continuity.
- Do not hide meaningful missing behavior behind polished placeholder buttons.
  Absent official features remain documented differences rather than inert UI.

### Implementation and validation consequences

The research directly changes the implementation plan:

1. Introduce explicit light/dark palettes and a small theme extension/component
   layer; remove `ColorScheme.fromSeed()` from the default product path.
2. Replace the centered runtime card plus 360 px engineering panel split with a
   full-window shell, compact project/thread sidebar, header, reading column, and
   integrated composer.
3. Decompose `codex_native_app.dart` into presentation modules while preserving
   controller instances and lifecycle ownership at the app root.
4. Add widget evidence for theme palettes, wide/narrow layout, thread
   hover/selected/focus states, major empty/loading/error/connected states,
   composer constraints, and overflow-free approval/diff/output layouts.
5. Re-run the existing bounded timeline, history/output, product-control,
   Remote-setup, analyzer, desktop build, and real stock app-server smoke gates.
   Machine tests do not replace Human visual review at normal and high DPR on
   Linux, Windows, and macOS.

### Implemented fidelity result

_Validated: 2026-11-06_

The research targets are now implemented without changing the stock app-server,
typed controller, lifecycle, or transport contracts:

- `CodexPalette` provides explicit light/dark canvas, sidebar, surface, hover,
  selected, border, text, semantic, diff, code, user-bubble, and shadow tokens.
  `ColorScheme.fromSeed()` is absent from the product path; system brightness
  selects the default. Material widgets remain only as native semantics/input/
  focus primitives under the project-owned component styling.
- The wide layout is a full-window 264 px sidebar plus a one-pixel divider and
  conversation workspace. The header is 52 px, thread rows are 42 px including
  vertical separation, and the reading/composer column is capped at 760 px. The
  760 px breakpoint switches to one explicit thread/conversation surface rather
  than stacking independently scrolling panels.
- Sidebar groups are derived from the retained `cwd` metadata, and list rows
  expose distinct idle/active, hover, selected, keyboard-focus, disabled, and
  resume states. Working directory and runtime process details moved behind
  explicit dialogs; the compact runtime state and functioning Remote setup
  entry remain visible.
- Conversation uses a low-chrome title/project header, virtualized timeline,
  right-aligned user bubbles, unboxed assistant Markdown, compact activity rows,
  bounded loading/empty/error states, inline approval, selected-file diff, and a
  unified rounded composer. Enter sends, Shift+Enter inserts a newline, narrow
  thread selection enters the conversation, and Escape closes the narrow
  sidebar.
- Approval, diff, output, runtime details, Remote administration, and Remote
  onboarding now consume the same semantic palette. Output remains a dark code
  viewport in both themes and retains only one existing bounded byte window;
  diff still builds only the bounded selected file.
- The prior monolith is now a small root/lifecycle file plus app shell,
  sidebar/activity, conversation/composer/settings, approval/diff/output,
  runtime-details, Remote-setup, and Remote-onboarding presentation modules.

### Known differences from the current official product

These are explicit differences, not hidden placeholders and not authorization
for more work in the completed Desktop phase:

- This client is a dedicated Codex workspace, not the unified ChatGPT Desktop
  shell. Chat/Work navigation, account surfaces, shared ChatGPT history, and
  official cloud UI are intentionally absent.
- Official worktrees, editor handoff, source/comment review, commit/PR actions,
  Automations, Skills/MCP/Plugins browsers, attachments, voice, and composer
  predictions are not presented because the current controllers do not own
  those complete behaviors.
- Changes replace the center conversation view instead of opening the current
  official multi-pane review experience. The implementation provides one
  bounded selected file and no inline diff comments.
- Model/reasoning/execution are integrated into the composer but open a native
  settings dialog; they do not copy the official model slider/menu pixel for
  pixel. Command output uses the existing bounded First/Previous/Next/Tail
  viewer rather than an official terminal pane.
- The window uses native Linux/Windows/macOS chrome and Material Symbols under
  custom sizing/states. Official fonts, proprietary icons, OpenAI marks,
  illustrations, motion, and asset bundles were deliberately not copied.
- Project groups are derived from already paged thread metadata. They do not
  crawl repositories, maintain a second project database, or preload inactive
  threads for richer animation.

### Validation boundary and remaining Human gates

- `dart analyze`, all 182 Flutter tests, the Linux debug build, wide/narrow
  layout, hover/selected/focus, composer keyboard behavior, narrow approval and
  output, bounded 1,000-item timeline, Markdown, diff, and Remote-setup tests
  pass. `flutter analyze --no-pub` passes through an ASCII symlink; the direct
  Unicode-path invocation fails before diagnostics because Flutter 3.47.1
  undercounts LSP UTF-8 bytes in `Content-Length`.
- A real Linux debug bundle connected to stock Codex Desktop
  `0.166.0-alpha.5.1`, hydrated ten live threads into project groups, and was
  directly screenshot-inspected in the system light theme. Runtime, thread,
  model, turn/interruption, rejected approval, and production-controller coding
  smokes pass. History/output memory and 12-cycle Host lifecycle gates pass.
- This is machine/agent evidence, not Human acceptance. Human review remains
  unrun for Linux, Windows, and macOS; normal/high DPR; system dark mode;
  populated long conversation, approval, diff, and output surfaces; keyboard
  traversal/screen reader behavior; and platform window chrome. The live Linux
  run also retained the known ATK socket-embedding and missing cursor-theme
  warnings. Hosted CI for the new UI commits is not inferred from local runs.

The Desktop UI phase is therefore closed at its machine-actionable boundary and
autonomous work is stopped. A future mobile/Remote phase requires explicit user
authorization and fresh research rather than extension of this document's
Desktop assumptions.

## Large app-server output and the native Host boundary

_Reviewed: 2026-11-05_

### Sources reviewed

- OpenAI Codex main at
  [`e7f32cf`](https://github.com/openai/codex/commit/e7f32cf1928a35a9232a633a51c2a03b5a7e2c72),
  including `app-server`, `app-server-protocol`, and `app-server-transport`.
- The locally installed Codex `0.166.0-alpha.5.1` experimental JSON schema,
  generated on 2026-11-05 with `codex app-server generate-json-schema
  --experimental`.
- OpenAI Codex PR
  [#59601](https://github.com/openai/codex/pull/59601), which added experimental
  command-output deferral to `thread/items/list` on 2026-11-05.
- OpenAI Codex reports
  [#55005](https://github.com/openai/codex/issues/55005),
  [#39860](https://github.com/openai/codex/issues/39860), and
  [#46690](https://github.com/openai/codex/issues/46690) for real large-history,
  Remote envelope, and renderer-memory failure evidence.
- [`json-skimmer` 1.0.0](https://docs.rs/json-skimmer/1.0.0/json_skimmer/),
  its source, validation notes, and retained resource measurements. License:
  MIT.
- TuxCodex at
  [`1905fc4`](https://github.com/MoussaKassim/TuxCodex/commit/1905fc4c80ee05379c1fa2d24062e04148bfdbb2).
  License: MIT.
- `codex-remote` at
  [`fcdf784`](https://github.com/Venompool888/codex-remote/commit/fcdf784e6365735ad9efde5cb43c5126042f4556).
  License: PolyForm Noncommercial 1.0.0; its code is research-only for this
  Apache-2.0 project.
- `mobile-codex` at
  [`107e7d7`](https://github.com/nokryong/mobile-codex/commit/107e7d73a4cb3285408b90242b37d5d7de49fbf5).
  License: GPL-3.0; its code is research-only for this Apache-2.0 project.

### Upstream facts

- App-server stdio is newline-delimited JSON, but the current implementation is
  not a streaming serializer. Its stdio writer first calls
  `serde_json::to_string(&outgoing_message)`, queues the resulting `String`, and
  only then writes it to stdout. Therefore a large `aggregatedOutput` is already
  materialized inside app-server before any sidecar can receive it. The Host can
  bound its own and Flutter's working sets, but cannot remove that upstream
  app-server allocation.
- The installed `0.166.0-alpha.5.1` protocol already has experimental
  `thread/items/read` for 1-100 IDs. It does **not** provide byte ranges and its
  response still embeds a full `aggregatedOutput` string. Previous project notes
  that said there was no per-item API were imprecise and must be corrected.
- Codex main now accepts
  `deferOutput: {"commandExecution": true}` on a single-turn
  `thread/items/list`. For a completed, successful command with non-empty saved
  output, the list entry carries `outputDeferred: true` and
  `aggregatedOutput: null`; the client then uses `thread/items/read` for the
  selected item. Older app-server versions ignore this unknown request field, so
  sending it is a useful forward-compatible preference, not sufficient protection
  by itself.
- `thread/items/read` on current main still returns the complete selected item in
  one JSON response. No offset/range command-output API exists in the reviewed
  schema. A bounded client-side output transport is still needed for the actual
  read.
- Upstream issue evidence is consistent with payload size being a real product
  boundary: multi-megabyte full-history replies correlate with mobile timeouts,
  unbounded thread previews can break initial Remote loading, and repeated history
  hydration has coincided with renderer heap exhaustion. These reports do not by
  themselves prove one shared defect, but they justify byte limits, explicit
  pagination, cancellation, and no automatic history draining.

### Reference-client observations

- TuxCodex supervises app-server carefully enough to reject stale events from a
  replaced child and has a useful compatibility pattern: retry only when the
  server specifically rejects a newer permission enum spelling. However, its
  bridge uses `BufReader::lines`, parses every complete line into
  `serde_json::Value`, and sends `aggregatedOutput` into React state. This is the
  exact large-payload materialization pattern we must not adopt.
- `codex-remote` has strong remote-security ideas: opaque device credentials,
  hashed Host storage, scoped authorization, idempotency keys, bounded outbound
  queues, device-bound attachment IDs, and no client-selected Host paths. Its
  current app-server bridge still uses Node `readline` plus `JSON.parse`, so Host
  request budgets and outbound caps apply only after a whole app-server line has
  entered memory. It also reconstructs some history directly from rollout files;
  that is a deliberate non-adoption because app-server remains this project's
  authoritative integration boundary.
- `mobile-codex` returns only the newest 40 display messages initially, loads
  older pages only after upward navigation, preserves the reading anchor, rejects
  cross-thread/stale cursors, and discards in-flight results after navigation.
  Those are useful regression-test ideas. We will implement the behavior
  independently because its GPL-3.0 code is not compatible with this project's
  Apache-2.0 distribution goal.

### Incremental JSON options

- `serde_json::from_reader`, line readers, and NDJSON adapters that deserialize a
  full value still materialize the large string. They only move the peak from
  Dart to Rust.
- `json-event-parser` is a streaming event parser, but its string event owns a
  complete `String`; that API does not solve a single huge scalar token.
- `json-skimmer` exposes borrowed raw string fragments from arbitrary byte chunks,
  validates JSON grammar and UTF-8, bounds nesting, and documents memory
  proportional to structural depth rather than scalar length. Its fragment
  boundaries may split UTF-8 and escape sequences, so a consumer must implement a
  correct incremental JSON-string decoder. Version 1.0.0 is recent, so adoption
  requires pinning, extensive split-boundary tests, malformed-input tests, and
  independent RSS measurements rather than relying only on upstream claims.

### Decision for this project

Adopt a lightweight Rust `codex-native-host` as the production desktop runtime
boundary and future Remote Host, while keeping stock app-server semantics intact.

For app-server stdout:

1. Read fixed-size byte chunks, never lines.
2. Use `json-skimmer` only for incremental JSON grammar/events.
3. Independently decode the targeted `aggregatedOutput` JSON string across
   arbitrary fragments, including escapes, surrogate pairs, and raw UTF-8.
4. Write decoded output directly to a restrictive, bounded session spool file.
5. Write the sanitized ordinary JSON candidate to a temporary file and publish it
   to Flutter only after the parser reports a valid complete candidate. Replace
   the large field with `null` plus an opaque output descriptor; never expose a
   filesystem path.
6. Prefer upstream `deferOutput` on listing requests when supported. The Host
   transform remains the compatibility and full-item-read safety net.

The temporary sanitized-candidate file avoids retaining the whole JSON message
while also preventing a malformed partial candidate from being forwarded before
validation. Host output APIs will provide bounded `stat`, `readRange`, and `tail`
operations over opaque IDs. Per-read, per-output, and total-session limits are
mandatory.

### Deliberate non-adoptions

- Do not parse app-server stdout with `read_line`, `lines`, `JSON.parse`, or
  `serde_json::from_str` before removing large scalar content.
- Do not expose spool paths or accept arbitrary file paths from Flutter/Remote.
- Do not read Codex rollout files to replace protocol behavior.
- Do not copy PolyForm Noncommercial or GPL implementation code.
- Do not introduce SQLite for output blobs; ordinary files match the current
  lifecycle and streaming requirements.
- Do not claim that the Host fixes app-server's own serialization peak. Measure
  app-server, Host, and Flutter separately.

### Validation required here

- Parser/decoder tests must cover every-byte fragmentation, multiple messages per
  chunk, escaped quotes and slashes, control escapes, Unicode escapes and
  surrogate pairs, raw multibyte UTF-8, nested objects, malformed/truncated JSON,
  depth limits, disk errors, cache limits, and path traversal attempts.
- End-to-end tests must prove request correlation, notifications, approvals,
  lifecycle cleanup, stale-cache cleanup, and bounded range/tail reads through the
  Host.
- Release-mode benchmarks must exercise approximately 3 MiB, 30 MiB, and 300 MiB
  synthetic outputs. Record baseline, ingest peak, and post-ingest RSS for the
  app-server fixture, Host, and Flutter process. Success means Flutter and Host
  deltas remain bounded/sublinear; app-server is reported separately.
- A real installed app-server smoke must still pass initialization, thread/turn
  flows, approvals, interruption, history, and one coding task through the Host.

## Session-local exact output reuse and candidate ownership

_Reviewed: 2026-11-06_

### Sources reviewed

- OpenAI Codex main and the installed `0.166.0-alpha.5.1` experimental schema
  already reviewed above. `thread/items/read` still returns a complete
  `aggregatedOutput`; the protocol exposes no byte-range or output-release
  ownership operation.
- Chrome DevTools Protocol's official
  [`IO.read`](https://chromedevtools.github.io/devtools-protocol/tot/IO/#method-read)
  and [`IO.close`](https://chromedevtools.github.io/devtools-protocol/tot/IO/#method-close)
  methods model an explicitly owned stream handle whose close operation
  discards backing storage.
- Bazel's Remote Execution API at
  [`c2c07e3d718d3d490a4958344d9c3e47de0bfaf3`](https://github.com/bazelbuild/remote-apis/commit/c2c07e3d718d3d490a4958344d9c3e47de0bfaf3)
  identifies content-addressed blobs with a digest and byte size and lets a
  client avoid re-uploading content already present. License: Apache-2.0.
- ccache at
  [`cb0e1e936f420311a8b6504ee4d730047a68d530`](https://github.com/ccache/ccache/commit/cb0e1e936f420311a8b6504ee4d730047a68d530)
  uses cryptographic content identities for cache reuse and separate checksums
  to detect persistent-cache corruption. License: GPL-3.0; research only for
  this Apache-2.0 project.

### Findings

- Digest plus logical length is a suitable internal exact-content identity, but
  a durable CAS is a different product. This Host's files are private,
  session-scoped, capped, and deleted on shutdown; it neither needs nor claims a
  persistent trust boundary.
- Hashing only the stored prefix is incorrect because output is deliberately
  truncated at the per-output or session cap. Two different complete outputs
  can share the same retained prefix. The identity must cover every decoded
  logical byte even when later bytes are not written.
- A DevTools-style `close` is safe when one client clearly owns one handle. The
  current descriptor may simultaneously be retained by a history row, an open
  dialog, desktop state, and a Remote consumer. Adding close without an
  ownership model would create stale references and read-after-release races.
- Output publication and JSON publication are one transaction until the first
  complete delivery. Finishing a string is not enough: later malformed JSON, a
  bounded-capture failure, or a sole observer failure must roll back a newly
  created output. Once local stdout has received a complete notification, a
  subsequent Remote-observer error cannot reclaim the object without leaving a
  descriptor that Flutter has already observed.

### Adopted boundary

- Stream SHA-256 over the complete decoded output and combine it with logical
  length. Keep a session-only identity-to-reference and reference-to-identity
  index. Reuse an existing object only after its data and metadata still pass
  the Host's size/stat checks.
- Keep the wire descriptor opaque. The client receives the existing random UUID
  reference and bounded metadata, never the digest or a spool path.
- Bound the session identity index independently at 16,384 objects. Resolve an
  exact existing identity before the capacity check; a new unique output at the
  cap becomes unavailable and its just-published files/bytes are rolled back.
  This closes the object-count/memory boundary that a byte cap alone cannot
  establish for many tiny outputs.
- If two identical finishes race, register only one object; delete the losing
  temporary/published pair and return its accounted bytes. An exact duplicate
  can reuse the earlier object even when the session byte budget is otherwise
  full.
- Track only outputs newly created by the current JSON candidate. Roll them back
  on pre-delivery parse, truncation, capture, or callback failure. A duplicate
  candidate never owns the shared object. A complete local publish commits the
  object before a secondary Remote notification callback.
- If an indexed pair is missing or size-inconsistent, evict it and republish the
  current bytes. Release its budget only when the data file is gone; a deletion
  error deliberately keeps conservative accounting until session cleanup.

### Deliberate non-adoptions and evidence boundary

- Do not add persistent cross-session deduplication, a public content digest,
  client-selected keys, or a release RPC. Explicit release requires a future
  descriptor-ownership design.
- Do not copy ccache's GPL implementation or claim persistent corruption
  detection. Same-size external mutation is outside this private session store;
  installed-volume behavior remains a separate platform gate.
- The duplicate must still pass through stock app-server's full-string
  serialization and the Host must stream/hash every logical byte. It can also
  create a bounded `.part` before the digest is known. Deduplication removes
  retained duplication, not upstream peak allocation or linear ingest work.
- The final release benchmark read each 3/30/300 MiB synthetic item twice and
  required the same descriptor plus exactly one `.data`, one `.json`, and zero
  `.part` files. Fixture RSS deltas were 8,396,800/94,380,032/629,153,792
  bytes, Host deltas were 200,704/200,704/266,240 bytes, and Dart deltas were
  2,269,184/2,473,984/3,039,232 bytes. This is Linux fixture evidence, not real
  app-server, Windows, macOS, or installed-volume proof.
- A real stock-app-server coding task completed through production controllers,
  read the persisted command item twice, reused one 6-byte output reference,
  projected one file/one addition with no unexpected approvals, deleted its
  thread/workspace, and shut the Host down in 59 ms.
- Code-bearing CI run `42135777838` at `4d35b56` passed Linux/Android job
  `127623402214`, Windows job `127623402465`, and macOS universal job
  `127623402670`. Every desktop OS ran the 98 native tests. The hosted Linux job
  also passed Flutter analysis/tests, Linux runtime closure, Host/license
  packaging, and the debug APK; Windows passed its debug bundle/Host/license
  checks; macOS passed the universal release and exact four-binary architecture,
  Host, and license checks. These gates do not simulate installed-volume fill,
  persistent corruption, physical Intel execution, or Android-device behavior.

## Desktop packaging and the macOS process model

_Reviewed: 2026-11-05_

### Sources reviewed

- Flutter's official
  [desktop build](https://docs.flutter.dev/platform-integration/desktop) and
  [macOS distribution](https://docs.flutter.dev/platform-integration/macos/building)
  documentation.
- Apple's official
  [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox),
  [sandbox inheritance](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html),
  and
  [embedded command-line tool](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app)
  documentation.

### Findings and decision

- Flutter's release artifacts are ordinary native desktop bundles; the Host must
  be built and copied as part of each platform's native build rather than found
  accidentally in a repository `target` directory.
- Apple supports embedded command-line helpers, but a sandboxed child inherits
  only its parent's static sandbox rights. Rights granted after launch, such as
  user-selected file access, are not automatically inherited. Mac App Store
  distribution requires App Sandbox.
- Stock Codex must access arbitrary user-selected development workspaces and run
  their toolchains. That cannot be made equivalent to a normal Codex shell by
  embedding only the Host with sandbox inheritance.
- Therefore macOS v1 is a direct, notarized distribution with App Sandbox
  disabled. The Host is nested in `Contents/MacOS`, signed during the build, and
  located beside the Flutter executable. Real macOS signing, notarization, child
  launch, workspace access, and cleanup remain platform gates because this Linux
  environment cannot execute them.

## Bounded assistant Markdown rendering

_Reviewed: 2026-11-05_

### Sources reviewed

- OpenAI Codex's current
  [TUI Markdown renderer](https://github.com/openai/codex/blob/main/codex-rs/tui/src/markdown_render.rs)
  and the `0.166.0` release notes covering consistent transcript Markdown.
- The maintained
  [`flutter_markdown_plus` 1.0.12](https://pub.dev/packages/flutter_markdown_plus)
  renderer, its source, changelog, layout modes, and link/image hooks. License:
  BSD-3-Clause.
- The Dart team's
  [`markdown` 7.3.1](https://pub.dev/packages/markdown) parser and extension-set
  documentation. License: BSD-3-Clause.
- Flutter's official lazy
  [`ListView.builder`](https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html)
  behavior and the official
  [`url_launcher` 6.3.3](https://pub.dev/packages/url_launcher) URI API. License:
  BSD-3-Clause.
- `gpt_markdown`, `flutter_md`, and `markdown_widget` were compared as alternative
  renderers. The first brings unrelated network/SVG/LaTeX dependencies, the
  second is only days old, and the third has a broader navigation/visibility
  dependency surface than this first native transcript slice needs.

### Findings and decision

- Current official Codex renders transcript Markdown with fenced code, tables,
  lists, task lists, links, and width-aware layout. It does not render Markdown
  images in the TUI and treats raw HTML as text rather than executing it.
- Dart `markdown` explicitly provides no HTML sanitization. Its predefined
  CommonMark and GitHub extension sets include `InlineHtmlSyntax`, so selecting
  a named preset is not a sufficient security policy even though
  `flutter_markdown_plus` itself is not an HTML engine.
- Use `flutter_markdown_plus` only with a project-owned extension allowlist:
  fenced code, tables, task lists, strikethrough, and autolinks. Do not enable
  `InlineHtmlSyntax`, emoji shortcodes, LaTeX, syntax-highlight grammar bundles,
  or custom web UI in this slice. Wrap the parser's built-in block-HTML syntax
  so its source is rendered literally as paragraph text rather than discarded;
  no HTML is interpreted or executed.
- Render every image reference as a bounded textual placeholder. Never let
  assistant Markdown initiate network, asset, or local-file reads.
- Link activation is user-initiated and allowlisted to `http`/`https`; launch it
  in an external application. Reject `file`, `data`, `javascript`, custom, and
  relative schemes. Local workspace links need a later explicit path/cwd policy.
- Completed assistant messages render Markdown. In-progress streaming messages
  remain selectable plain text so coalesced token updates do not repeatedly
  parse an incomplete document. The outer lazy timeline determines which
  messages are built; there is no global AST cache. Source size remains bounded
  by the existing 64 KiB live-entry and 8 KiB history limits. The rich renderer
  has a stricter 16 KiB fail-safe; larger completed messages show a bounded
  selectable plain-text tail with an explicit omission marker.

### Deliberate non-adoptions and validation

- Do not render through HTML or WebView, fetch remote images, open arbitrary URI
  schemes, retain ASTs for inactive/off-screen threads, or add a second nested
  vertical scroller.
- Do not adopt a streaming-specific renderer until profiling demonstrates that
  completed-only rendering is an unacceptable UX tradeoff.
- The first widget gate showed that a 64 KiB unbroken token could keep the test
  renderer busy for more than 30 seconds. That negative result is the reason for
  the separate 16 KiB rich-rendering cap and plain-text fallback; normal
  formatted content and the capped pathological case must both remain tested.
- Widget tests must cover formatting, raw HTML as inert text, blocked images and
  URI schemes, external `http`/`https` activation, streaming fallback, source
  caps, and the existing 1,000-item lazy-build boundary.

## Android Remote transport, pairing, and resume

_Reviewed: 2026-11-05_

### Sources reviewed

- OpenAI Codex main at
  [`e7f32cf`](https://github.com/openai/codex/commit/e7f32cf1928a35a9232a633a51c2a03b5a7e2c72),
  especially the CLI listener selection, app-server transport authentication,
  app-server README, and WebSocket test client. License: Apache-2.0.
- OpenAI Codex Remote failure reports
  [#39954](https://github.com/openai/codex/issues/39954),
  [#37967](https://github.com/openai/codex/issues/37967),
  [#55005](https://github.com/openai/codex/issues/55005),
  [#41573](https://github.com/openai/codex/issues/41573), and
  [#36189](https://github.com/openai/codex/issues/36189). These are incident
  evidence, not one proven shared root cause.
- `codex-remote` at
  [`fcdf784`](https://github.com/Venompool888/codex-remote/commit/fcdf784e6365735ad9efde5cb43c5126042f4556),
  including protocol v2, Host auth/server code, Android reconnect code, and the
  lifecycle reconciliation audit. License: PolyForm Noncommercial 1.0.0;
  implementation code is research-only for this Apache-2.0 project.
- `codex-remote-android` at
  [`372581a`](https://github.com/liuhao-labs/codex-remote-android/commit/372581ad5cc66677d5322a9a447a03277d36ce15),
  including its SSH transport, host-key confirmation, encrypted credentials,
  bounded initial history, and upward pagination. License: Apache-2.0.
- `mobile-codex` at
  [`107e7d7`](https://github.com/nokryong/mobile-codex/commit/107e7d73a4cb3285408b90242b37d5d7de49fbf5),
  including phone/tablet navigation, draft ownership, stale-turn guards, and
  bounded diff/preview presentation. License: GPL-3.0; implementation code is
  research-only for this Apache-2.0 project.
- Rust `getrandom` 0.4.3 for direct operating-system randomness, RustCrypto
  `sha2` 0.11.1 for token/parameter digests, and `subtle` 2.6.1 for constant-time
  digest comparison. All are permissively licensed. `sha2` was initially held
  at 0.11.0 for an asserted Rust 1.87 floor; the later clean-toolchain gate
  disproved that floor and the now-verified Rust 1.89 floor supports 0.11.1.

### Upstream and failure evidence

- Current stock `codex app-server` can listen on stdio, Unix sockets, or a TCP
  WebSocket address. Its WebSocket transport supports a capability token file,
  a precomputed SHA-256 token hash, or signed bearer credentials. Upstream also
  states that remote-control peers still need a device authenticator.
- Direct Android-to-app-server WebSocket access would bypass this project's
  already-required Host output transformation, spool budgets, lifecycle
  supervision, and future attachment boundary. Availability upstream therefore
  changes implementation options, not ADR-008's ownership.
- An authenticated socket is not equivalent to a usable hydrated client. Real
  reports show connections that initialize/list successfully while large-thread
  hydration loops or times out; some mobile-to-Host writes can persist while
  read-side hydration is still broken.
- Full-history replies can be orders of magnitude larger than summary pages.
  Large payload handling must not block ping/pong or fill an unbounded outbound
  queue, and reconnect must never silently duplicate a write whose outcome is
  unknown.
- A second app-server process is not a safe way to obtain remote writer access:
  the local real-runtime gates already show active-writer ownership, and remote
  reports distinguish live writer state from persisted paged history.
- Reference lifecycle audits found stale completion, late delta, navigation,
  and reconnect results overwriting newer state. Terminal evidence must be
  monotonic and results must be scoped to a connection/session/navigation
  generation; assistant text alone never proves completion.

### Decision for this project

The Rust Host owns an explicitly enabled Remote listener and wraps sanitized
app-server JSON-RPC in a small authenticated, resumable envelope. Ordinary Codex
method names and typed adapter semantics remain protocol-native; only `host/*`
operations belong to this project. The envelope must not become a parallel agent
or feature RPC schema.

The initial protocol has these invariants:

1. The listener is disabled by default and binds loopback unless the user
   explicitly configures remote exposure. Non-loopback exposure requires TLS;
   plaintext WebSocket is limited to loopback/test use.
2. Pairing is initiated from a local trusted Host surface with one short-lived,
   single-use ticket. Success returns one cryptographically random 256-bit
   device token exactly once. The Host persists only its SHA-256 digest plus a
   bounded device name, scopes, creation/expiry/last-seen/revocation metadata,
   using owner-only atomic storage and constant-time digest comparison.
3. A three-message `server_hello` / `client_hello` / `hello_ack` negotiation
   selects a common version and capabilities before any RPC is accepted. The
   Host advertises a process-scoped session ID and current event sequence.
4. Every replayable event has a strictly increasing sequence. The client ACKs
   its highest contiguous sequence. Replay is allowed only for the same Host
   session and a retained continuous suffix; a process change or missing gap
   returns `resyncRequired` and forces bounded authoritative reload.
5. The journal is bounded by both item count and serialized bytes. Each inbound
   message, outbound message, and per-connection queued byte total also has a
   hard cap. Control/heartbeat progress must not wait behind large application
   payloads.
6. Multiple clients cannot share raw app-server request IDs. The Host gives each
   connection a namespace/remaps correlation IDs, then returns the client's
   original ID only to that connection.
7. Remote write methods require an idempotency key. The Host may replay a cached
   outcome only inside the same authoritative Host session; after Host restart,
   an unconfirmed operation is reported as unknown and is never silently
   retried.
8. Pending approval/input requests are durable protocol state independent of the
   volatile event suffix. They have Host-generated opaque IDs, scopes and
   deadlines, are replayed only to eligible devices, and fail closed when stale,
   superseded, or already answered.
9. Initial and recovery reads reuse existing bounded thread/turn/item pagination.
   The client never auto-drains every thread or complete history merely because
   a socket connected.
10. Large attachments and command output do not travel as base64 WebSocket
    frames. They use separately authenticated, device-bound, chunked transfers
    with exact total size, range, per-chunk and whole-object integrity, quotas,
    expiry, and opaque references.

Android will store the issued device secret with platform-backed secure storage
when the device slice is implemented. The first Host slice should establish the
pure protocol/auth/replay state machine and its adversarial tests before adding a
network library, so listener behavior cannot define ambiguous semantics by
accident.

### Deliberate non-adoptions

- Do not connect Android directly to stock app-server or expose its raw listener
  on a LAN.
- Do not make SSH/general remote-shell credentials the default Remote transport;
  it remains a possible explicit future adapter, not a pairing substitute.
- Do not copy PolyForm Noncommercial or GPL implementation code.
- Do not reproduce a feature-by-feature Remote RPC allowlist that drifts from
  app-server, and do not read rollout files to synthesize protocol state.
- Do not use a count-only replay journal, a 64 MiB socket backlog, automatic
  full-history hydration, or base64 attachment bodies as this project's bounds.
- Do not resend writes or approval answers across a changed Host session merely
  because the mobile process still has a queued request.

### Validation required here

- Protocol tests must cover incompatible versions, pre-handshake RPC rejection,
  exact gap boundaries, duplicate/out-of-order ACKs, session changes, item and
  byte eviction, one oversize event, integer overflow, ID namespace collisions,
  stale generations, and idempotency-key parameter mismatch.
- Auth tests must cover ticket expiry/single use, token entropy/format, constant-
  time digest matching, rotation/revocation/expiry, corrupt storage, atomic
  owner-only persistence, rate budgets, and live revocation.
- Network tests must cover loopback-only defaults, refusal of plaintext
  non-loopback exposure, handshake deadlines, message/backlog caps, slow readers,
  ping/pong under application load, abrupt disconnect, TLS configuration, and no
  surviving Host/Codex process.
- End-to-end recovery must prove no missing or duplicate events within a retained
  same-session suffix, explicit bounded resync beyond it, no duplicate writes,
  fail-closed approvals, bounded hydration, and output/attachment range transfer.
- Real Android physical-device gates must include background/foreground, Wi-Fi
  changes, Doze, process death, credential revocation, Host restart, large
  threads, active turns, approval races, and phone/tablet presentation.

### Initial Rust network stack selection

_Reviewed: 2026-11-05_

- `axum` 0.8.9 is MIT-licensed, supports Rust 1.80, and provides HTTP routing
  plus WebSocket upgrade on the Tokio/Hyper stack. Its WebSocket configuration
  exposes read/write buffer, maximum write-buffer, frame, and complete-message
  limits. The defaults are not acceptable here: 64 MiB messages, 16 MiB frames,
  and an unlimited maximum write buffer must all be overridden.
- `tokio` 1.54.1 is MIT-licensed and supports Rust 1.85. Its bounded MPSC channel
  has an explicit item capacity and supports sync/async boundaries. Unbounded
  channels are a deliberate non-adoption because an item count alone also does
  not constrain payload bytes.
- `axum-server` 0.8.0 provides a maintained rustls acceptor and certificate
  reload path while supporting Rust 1.82. It is reserved for the non-loopback
  TLS slice; adding it before certificate/configuration behavior exists would
  expand the release dependency surface without adding a safe reachable mode.
- Adopt `axum` plus a dedicated Tokio runtime thread for the first explicitly
  enabled loopback-only pairing/auth/handshake slice. Keep the existing sync
  stdio/app-server owner unchanged. Set HTTP body, WebSocket message/frame/write
  buffer, handshake deadline, connection count, item count, and application
  queued-byte limits explicitly; axum's socket write-buffer limit is not a
  substitute for an application outbound-queue byte budget.
- Plaintext non-loopback configuration must fail before binding. Later WSS uses
  rustls with an explicit certificate/key policy; it must not silently downgrade
  to `ws://` when TLS configuration fails.

### WSS certificate loading, rotation, and Android trust boundary

_Reviewed: 2026-11-05_

#### Primary sources

- [`axum-server` 0.8 rustls configuration](https://docs.rs/axum-server/0.8.0/axum_server/tls_rustls/struct.RustlsConfig.html),
  [`from_tcp_rustls`](https://docs.rs/axum-server/0.8.0/axum_server/fn.from_tcp_rustls.html),
  and its [graceful-shutdown handle](https://docs.rs/axum-server/0.8.0/axum_server/struct.Handle.html).
- [Android Network Security Configuration](https://developer.android.com/privacy-and-security/security-config)
  and [Android's TLS guidance](https://developer.android.com/privacy-and-security/security-ssl).
- Dart [`WebSocket.connect`](https://api.dart.dev/dart-io/WebSocket/connect.html),
  [`HttpClient`](https://api.dart.dev/dart-io/HttpClient-class.html), and
  [`SecurityContext`](https://api.dart.dev/dart-io/SecurityContext-class.html).
- [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
  and its [release history](https://pub.dev/packages/flutter_secure_storage/changelog)
  for the later Android device-secret slice.

#### Maintained reference implementations

- [`codex-remote`](https://github.com/Venompool888/codex-remote) keeps its core
  service on loopback and recommends HTTPS/WSS termination by a reverse proxy;
  explicit HTTP is limited to trusted private/ADB scenarios. This supports a
  documented reverse-proxy deployment option, but does not substitute for a
  safe built-in listener when this Host is configured directly.
- [LocalSend's protocol](https://github.com/localsend/protocol/blob/main/README.md)
  uses a certificate fingerprint as device identity, while current LocalSend
  hardening also binds the claimed fingerprint to the TLS certificate. This is
  useful evidence for a pairing-bound local identity, but its mutual-TLS model
  is more machinery than the current scoped-bearer envelope requires.
- [`codex-remote-android` at `372581a`](https://github.com/liuhao-labs/codex-remote-android/commit/372581ad5cc66677d5322a9a447a03277d36ce15)
  confirms the value of explicit user-confirmed host identity and fail-closed
  changed-identity handling even though it uses SSH rather than WSS.

#### Findings

- `axum-server` 0.8.0 supports Rust 1.82, the project's axum/Tokio stack, PEM
  certificate-chain loading, shared `ArcSwap`-backed atomic reload, and bounded
  graceful shutdown. Its default rustls backend is AWS-LC. This project pins the
  dependency surface through `Cargo.lock` and keeps the existing HTTP body,
  WebSocket frame/message/write-buffer, connection, queue, journal, and write
  timeout bounds above the TLS acceptor.
- Android can use platform trust anchors for ordinary CA certificates and a
  narrowly supplied trust anchor for a local identity. Android's own guidance
  cautions that routine public-key pinning can strand clients during rotation;
  a future local self-signed flow should therefore bind an expected certificate
  or local CA identity during pairing and define re-pair/rotation behavior rather
  than install an unconditional `badCertificateCallback`.
- Dart supports injecting an `HttpClient` into `WebSocket.connect`, and that
  client can use a `SecurityContext` populated with the exact trusted
  certificate bytes. The release WSS smoke exercises that path without a trust
  bypass callback.
- Current `flutter_secure_storage` uses Android Keystore-backed key wrapping and
  encrypted storage, but its Android backup exclusions and minimum SDK/version
  constraints must be evaluated when the Android client slice lands. It is not
  added merely to make Host TLS reachable.

#### Adopted here

- Add `--remote-tls-cert`/`CODEX_NATIVE_REMOTE_TLS_CERT` and
  `--remote-tls-key`/`CODEX_NATIVE_REMOTE_TLS_KEY`. Both are required together;
  neither is meaningful without a listener. A non-loopback listener without
  both fails configuration, and `RemoteServer` independently enforces the same
  plaintext boundary before binding.
- Load and parse the certificate/key before binding. On Unix, reject a private
  key readable by group or other users. Never echo PEM contents in status or
  errors. Keep optional plaintext loopback operation for local development and
  the established smoke path.
- Expose rotation only through trusted local `host/remote/tls/reload`. A valid
  replacement is swapped for new TLS handshakes without dropping established
  WebSockets. Invalid replacement material returns a generic Host error and
  keeps the last valid rustls configuration.
- Prefer a normal CA certificate or reverse proxy for managed/public deployment.
  Defer local self-signed Android onboarding until the pairing artifact can bind
  certificate identity and platform-backed device-secret storage together. Do
  not add mTLS or arbitrary-certificate acceptance in this slice.

#### Validation and preserved negative evidence

- A first focused WSS test passed TLS but closed immediately before
  `server_hello`. Investigation found that `axum-server`'s `http1_only()` serve
  branch did not use Hyper's upgrade-serving path. Removing that override while
  retaining the router's HTTP/WebSocket limits restored WebSocket upgrade. The
  observed EOF is preserved here rather than erased by the later pass.
- Real TLS tests cover HTTPS health/pairing, hash-only bearer persistence,
  authenticated WSS negotiation, default-root rejection of the self-signed
  certificate, operator-supplied trust, non-loopback wildcard binding, local
  status projection, successful rotation, rejection by the old trust root,
  survival of an established connection, failed-reload rollback, and active
  WSS shutdown with an `Away` close frame.
- A release Host plus stock app-server completed the read-only Remote smoke over
  WSS using an explicitly populated Dart `SecurityContext`. It bound a network-
  scope wildcard and connected back through loopback on the same Linux host.
  This is not a physical Android, real LAN/firewall, system-CA, or installed
  service validation.

### Initial read-only Codex routing surface

_Reviewed: 2026-11-05_

- Generated the experimental JSON Schema bundle from the actually installed
  stock app-server `0.166.0-alpha.5.1` and compared `ModelListParams`,
  `ThreadListParams`, and `ThreadReadParams` with the current typed Flutter
  adapters. This was a temporary generated artifact and was removed after the
  review; no upstream schema is copied into the product.
- The first Remote Codex allowlist is `model/list`, `thread/list`, and
  metadata-only `thread/read`. Both list methods normalize a hard maximum of 100
  results; cursors are capped at 4 KiB. `thread/list` accepts only pagination,
  bounded sort, and `archived=false`; it does not accept cwd/search/project or
  relationship filters. `thread/read` forces `includeTurns=false` and bounds the
  thread ID. Unknown fields, write methods, idempotency keys, and missing read
  scope fail before app-server dispatch.
- The Host remains the only app-server stdio peer. Remote requests use a
  process-session-qualified internal ID namespace, while local input is barred
  from that namespace. Only a top-level response matching that exact random
  session prefix is removed from desktop stdout; other stock server requests,
  notifications, desktop responses, and even another session-like prefix remain
  on the local path.
- Target responses are captured only after the existing `aggregatedOutput`
  sanitizer/file spool completes. Capture is capped below the 1 MiB WebSocket
  message ceiling; an oversized sanitized response becomes an explicit Remote
  error without being loaded into memory or leaked to Flutter. Late responses
  after disconnect stay suppressed and are discarded when their bounded
  correlation no longer exists.
- The shared Host event queue is capped at 64 messages, Remote correlations at
  64 requests/64 KiB, and each connection's application queue at 16 messages
  and 2 MiB. A WebSocket message is capped at 1 MiB and a socket write at five
  seconds. Queue/byte overflow or a 30-second upstream timeout closes the
  connection so disconnect cleanup releases every pending correlation; it does
  not leave retryable-looking requests resident indefinitely.

### Bounded app-server notification publication

_Reviewed: 2026-11-05_

#### Sources reviewed

- OpenAI Codex `ServerNotificationEnvelope` generated TypeScript union:
  <https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/typescript/ServerNotificationEnvelope.ts>
- OpenAI Codex app-server protocol definitions:
  <https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/common.rs>
- OpenAI Codex app-server README:
  <https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md>
- The installed stock app-server `0.166.0-alpha.5.1` schema and the already
  implemented desktop typed notification projector.

#### Observed approaches and pitfalls

- The official notification envelope is a large evolving union. It mixes small
  lifecycle/state events with token/output deltas, full diff updates, account
  state, MCP progress, and other method-specific payloads. Treating every
  top-level `method` as equally replayable would turn the bounded journal into a
  second unreviewed app-server transport.
- Current app-server envelopes may include an optional top-level `emittedAtMs`.
  The Host sequence remains the Remote ordering authority; retaining the stock
  `params` without inventing a timestamp ordering rule avoids two competing
  clocks.
- `item/agentMessage/delta` and other deltas can arrive per token/chunk. A
  512-item journal would rapidly evict terminal evidence while retaining data
  that `item/completed` already supplies. `turn/diff/updated` can also be large
  and needs file/hunk chunking rather than an ordinary replay event.
- JSON-RPC server requests also have a top-level `method`, but additionally have
  a top-level `id`. Method allowlisting alone is therefore insufficient: the
  capture boundary must reject every request-shaped object independently of the
  ID value type.

#### Adopted here

- Publish only `turn/started`, `turn/completed`, `item/started`,
  `item/completed`, `thread/status/changed`, and `error` for the initial event
  slice. Unknown notifications, token/output/reasoning deltas, diffs, approval
  requests, and other server requests remain desktop-only.
- Detect the method and the presence of any top-level `id` in the incremental
  sanitizer. The ordinary desktop message is published first; Remote observes a
  copy only after every `aggregatedOutput` field has been replaced by its opaque
  bounded descriptor. Remote capture is capped at 256 KiB.
- Convert an allowlisted event above that cap into the small sequenced
  `host/resyncRequired` marker instead of allocating or silently dropping the
  payload. The mobile client can then perform bounded authoritative reads.
- Subscribe each socket to a capacity-64 live broadcast before handshake. The
  negotiation journal snapshot defines the baseline, buffered events at or
  below it are skipped, and only a contiguous next sequence is accepted. A
  broadcast lag/gap emits `resync_required` and closes the socket; application
  queue or socket-write exhaustion also disconnects the slow peer.

#### Validation in this project

- Streaming-transform tests cover fragmented method parsing, sanitized capture,
  numeric-ID server-request exclusion, delta exclusion, and oversize capture
  without Remote materialization.
- Real TCP tests cover live delivery, ACK, retained same-session replay, abrupt
  unacknowledged reconnect, count eviction with explicit handshake resync, no
  partial replay, oversize resync markers, bounded outbound queues, and a slow
  reader disconnected under an 18 MiB fanout.
- The release Host still passes pairing and the read-only stock app-server smoke.
  That smoke does not start a paid/mutating turn, so it does not claim a real
  stock turn notification was observed end to end.

Deliberately deferred: write methods, pending approval state, output-range
transfer, diff chunking, pairing-bound Android certificate onboarding, Android
secure storage, reconnect/lifecycle ownership, and Android application
integration remain unavailable.

### Bounded Dart Remote client transport

_Reviewed: 2026-11-05_

#### Sources and constraints applied

- Dart's official `WebSocket.connect`, `HttpClient`, and `SecurityContext` APIs
  reviewed in the WSS section above remain the implementation boundary. The
  WebSocket client negotiates `codex-native-v1`, carries the bearer only in the
  Authorization header, uses platform trust roots by default, and permits a
  narrowly configured `HttpClient` for a future pairing-bound local trust
  anchor. No `badCertificateCallback` exists in the product path.
- Dart automatically handles WebSocket ping/pong control frames. Application
  code still needs request deadlines, socket-close recovery, resume, and
  authoritative readiness; inventing an additional JSON heartbeat would create
  a second liveness protocol without improving the Host's existing heartbeat.
- Dart 3.13 adds `maxPayloadLength` to the WebSocket client. SDK source confirms
  that it rejects each uncompressed frame before exposing a message and caps a
  decompressed frame, but fragmented uncompressed frames accumulate into the
  message builder without an aggregate check. Configure the frame limit to
  1 MiB, disable compression, retain a second combined-message check, and treat
  TLS-authenticated Host behavior as part of the trust boundary. This does not
  prove bounded allocation against a compromised Host that deliberately
  fragments a larger message and is recorded as a release risk, not hidden.
- SDK source also confirms that ordinary `WebSocket.add()` enters a synchronous
  stream-controller path. Use serialized `addStream` writes instead: its source
  subscription is paused when the underlying socket consumer applies
  backpressure. Keep a separate count-and-byte cap because backpressure does not
  itself bound calls already queued by application code.

#### Adopted here

- Require WSS and an exact `/v1/ws` endpoint. Permit plaintext only with an
  explicit flag and a literal loopback IP; reject hostname loopback, query,
  fragment, and user-info forms. Validate the 43-character base64url bearer and
  keep credential/URI details out of validation errors.
- Reuse the Host's three-message negotiation and require protocol version 1 plus
  `ack`, `eventReplay`, and `readOnlyCodex`. A missing subprotocol, inconsistent
  session/sequence, binary/unknown/malformed message, event gap, or malformed RPC
  result policy-closes the connection.
- Treat a connection without an exact same-session retained cursor as requiring
  authoritative resync, even though the Host correctly reports that there is no
  replay request. Hold subsequent events behind the snapshot and require the
  caller to complete the same resync generation. Buffer exhaustion or a Host
  marker increments the generation so a stale read cannot clear newer evidence.
- Mirror the Host bounds: 64 pending RPCs, 1 MiB messages, 512 held events and
  8 MiB held-event bytes. The real socket additionally caps its serialized
  outbound queue at 64 messages/2 MiB and uses the SDK frame cap. One ambiguous
  RPC timeout closes the connection rather than allowing a late response to be
  mistaken for a safe retry. A connection Future that completes after its
  deadline is explicitly closed.
- Reuse typed model/thread/turn adapters, but expose only status, model list,
  bounded thread list, and metadata-only thread read. All writes, approvals,
  history, and output calls reject locally until the Host has end-to-end state
  and idempotency semantics for them.

#### Validation and preserved negative evidence

- Sixteen fake-socket and two real-loopback-socket tests cover security
  configuration, handshake, first resync, retained replay, ACK/cursor
  advancement, out-of-order correlation, unsupported writes,
  malformed/binary/gap input, abnormal peer close, explicit resync, event-buffer
  exhaustion, timeout, concurrent close, ordered real-socket writes, and the
  SDK frame cap. The first sequence-gap test hung:
  the reader tried to close its socket before cancelling the active iterator.
  Cancelling input first fixed the concrete lifecycle cycle; the initial hang is
  retained rather than erased by later green tests. The first real oversize-
  frame assertion expected a stream error; Dart instead intentionally sends a
  protocol close and ends the message stream without forwarding that internal
  error. The test now asserts close code 1002, and `RemoteTransport` surfaces an
  abnormal stream end through its public protocol-error channel.
- Full Dart analysis and all 90 Flutter tests pass. The Android manifest merge
  contains `INTERNET`, and the three-ABI debug APK builds through the documented
  Unicode-path local-property workaround. No real Android network, background,
  process-death, platform-CA, or presentation behavior was exercised.

#### Deliberately deferred

- Do not wire the transport into `RuntimeController` while resync has no bounded
  application projection and reconnect owner. Endpoint/trust/device credentials
  are no longer transient strings, but storage alone is not runtime readiness.
- Do not persist a cursor in the credential record or ordinary preferences
  before its event has been applied. Bearers remain excluded from ordinary
  preferences, route state, logs, and crash text.
- Do not automatically retry writes or approval answers. The current client is
  read-only; reconnect/idempotency and durable pending interaction state remain
  separate future slices.

### Android device credential storage and recovery

_Reviewed: 2026-11-05_

#### Primary sources and implementation evidence

- Android's [Keystore documentation](https://developer.android.com/privacy-and-security/keystore)
  establishes that key material is non-exportable and may remain inside secure
  hardware. Its [Auto Backup documentation](https://developer.android.com/identity/data/autobackup)
  says SharedPreferences are backed up by default and documents legacy and
  Android 12+ include/exclude rules.
- [`flutter_secure_storage` 11.2.0](https://pub.dev/packages/flutter_secure_storage/changelog)
  is the current release. Version 11 uses RSA-OAEP wrapping plus AES-GCM by
  default, requires Android API 24 with current Flutter, and supports a namespace
  covering data preferences, wrapped keys, config markers, and Keystore aliases.
  Its default `resetOnError` is true; this project explicitly sets it false.
- Open [issue #1298](https://github.com/juliansteenbakker/flutter_secure_storage/issues/1298)
  identifies a current availability defect: transient Android Keystore null
  results can make the plugin replace the RSA wrapping pair before
  `resetOnError` is checked. Stored ciphertext then becomes permanently
  unreadable. This does not expose the bearer, but it means the application must
  model unreadable state and re-pair recovery instead of promising transparent
  persistence.

#### Adopted here

- Store one bounded versioned JSON record under one secure-storage key. Version
  1 permits only an exact WSS `/v1/ws` endpoint, the Host's 43-character
  base64url bearer, bounded/control-free device metadata, and `system` trust.
  Self-signed or local-CA identity will require a new explicit schema version.
- Treat absent, available, and recovery-required as distinct states. A storage
  exception is not absence. Invalid or unreadable data is not deleted, and a
  save cannot overwrite it until the user takes an explicit recovery action.
  Serialize operations and verify every write and delete by readback.
- Configure the Android adapter with `resetOnError: false`, algorithm migration,
  migration backup, no per-operation biometric prompt, and the isolated
  `codex_native_remote` namespace. Background reconnect needs key access without
  an interactive biometric ceremony; the Host bearer remains revocable. The
  plugin initializes storage before ordinary deletion, so an already lost
  wrapping key can otherwise block recovery. Only the explicit clear path uses
  the same namespace with `resetOnError: true`; routine reads and writes never do.
- Use both `allowBackup=false` and explicit preference exclusions for legacy
  cloud backup plus Android 12+ cloud/device transfer. The broader exclusion is
  intentional: current local settings are reconstructable, while restoring any
  device-bound secure-storage ciphertext is not safe.

#### Validation and preserved boundaries

- Nine tests cover strict/redacted serialization, plaintext and credential-URI
  rejection, absent/available/unreadable/corrupt states, preservation until
  explicit clear, verified writes, serialized concurrent saves, and exact
  Android option values. All 99 Flutter tests and the Linux debug build pass.
- Debug and R8-minified release Android builds pass after the existing temporary
  Unicode SDK-path workaround. Merged manifests contain API 24, `INTERNET`,
  `allowBackup=false`, and both backup rule resources. The universal three-ABI
  release APK is 51,791,110 bytes. That historical artifact used the Flutter
  template's debug certificate, so it is compilation/size evidence rather than
  release-identity evidence. No runtime Android Keystore call was made.
- The first ordinary Gradle invocation again failed before compilation because
  Flutter's Unicode SDK path was decoded as mojibake. This known toolchain-path
  failure is preserved; only the escaped-property run is a passing Android build.
- Physical-device Keystore, transient service failure, backup/restore, device
  transfer, uninstall/reinstall, and system-CA TLS behavior remain unrun. The
  open upstream wrapping-key replacement defect remains a release watch item.

### Remote readiness, applied cursors, and lifecycle recovery

_Reviewed: 2026-11-05_

#### Constraints applied

- WebSocket negotiation success is only a transport fact. Product readiness
  additionally requires the authenticated Host status to match the stored device
  and negotiated session, followed by an authoritative bounded state snapshot.
- The transport ACK tracks a contiguous received suffix so the Host can bound
  replay. It is not an application durability claim. A distinct cursor may be
  persisted only after the corresponding projection mutation succeeds.
- A saved cursor alone cannot reconstruct state after process death. Until the
  bounded projection itself is durable, cold start must ignore the cursor and
  perform authoritative reads. Retained in-memory state may resume only when its
  device, Host session, and applied sequence exactly match the verified cursor.
- Suspend, reconnect, resync, and asynchronous snapshot work can overlap. Every
  result needs both run and connection identity, and projection mutations must
  be serialized across sessions so a late old result cannot overwrite new state.
- Authentication rejection and live credential revocation require user recovery,
  not automatic retry. Transient connection/request failures may retry, but with
  a bounded delay and no write replay. The current Remote surface remains
  read-only.

#### Adopted here

- `RemoteTransport` exposes each allowlisted notification together with its
  exact Host session and sequence. Its terminal result distinguishes local,
  peer, protocol, resync, credential-revoked, and generic failure classes while
  keeping close text out of public diagnostics. The real socket converts HTTP
  401 into one redacted typed credential rejection.
- Store one versioned cursor record separately from the device bearer. Bind it
  to device ID, Host session, and non-negative sequence; cap it at 1 KiB;
  serialize access; verify write readback; and report malformed/unreadable data
  generically without deleting it.
- Retain at most 100 model entries and 100 thread summaries in the initial
  projection. Model/thread next cursors remain opaque for explicit later paging.
  Lifecycle events may update a known thread status or advance the exact next
  sequence without inserting unbounded history. Wrong-session, gap, malformed,
  and unsupported events fail closed.
- The lifecycle owner loads credentials, connects, verifies status, concurrently
  requests one bounded model and thread page, replaces the projection, saves the
  baseline cursor, then releases the transport's held suffix. Each released
  event is applied and only then persisted. A resync-generation change discards
  completed stale reads and repeats the bounded snapshot.
- Generic failures use exponential delays from one to 30 seconds. Credential
  rejection and exact live revocation enter terminal state. Suspend closes the
  session while retaining only verifiable applied state; stop also invalidates
  the projection. A connection that completes after deactivation is closed and
  never published.

#### Validation and preserved negative evidence

- Four cursor tests cover exact device binding, malformed/unreadable redaction,
  write verification, and serialized concurrency. Three projection tests cover
  the 100/100 cap, exact sequence application, and fail-closed input. Ten
  lifecycle tests cover absent/recovery credentials, readiness gating,
  apply-before-persist order, retained resume, Host session replacement,
  rejection/revocation, exponential retry (including connected failures before
  readiness), late connection cleanup, stale projection work, and invalidated
  hydration.
- The first real HTTP 401 assertion failed because Dart's
  `WebSocketException.message` omitted the status; its `toString()` retained the
  fixed `HTTP status code: 401` phrase. Matching only that phrase produced the
  typed redacted result without parsing or surfacing the endpoint or bearer.
- The first suspend/late-connection test failed because the stale branch closed
  the session and the surrounding `finally` closed it again. Real
  `RemoteTransport` coalesced this, but the coordinator interface should not rely
  on implementation idempotence. One `finally` now owns cleanup.
- A delayed projection test proves an old session cannot repopulate or advance a
  resumed run. Projection work is serialized globally; resume waits for old work
  to finish; a generation change invalidates the stale result before the new run
  reads its cursor.
- All 118 Flutter tests, `dart analyze --fatal-infos`, an isolated ASCII-copy
  `flutter analyze --no-pub`, Linux debug build, and Android `assembleDebug`
  pass. Direct `flutter analyze` still crashes on the Unicode repository path;
  a simple ASCII symlink was insufficient because the analyzer canonicalized it
  back to the real path. No real Android network, OS background, process death,
  or secure-storage lifecycle was exercised.

#### Deliberately deferred

- Android runtime construction, lifecycle visibility wiring, and a bounded
  read-only metadata panel are now integrated in the following slice. Pairing,
  credential recovery actions, and full conversation behavior remain separate.
- Only bounded model/thread metadata is authoritative. Remote history, output,
  turns, approvals, server requests, and every write remain unavailable.
- Cursor-only cold resume remains intentionally disabled until there is a
  separately designed bounded durable projection. Reconnecting with a stale
  cursor and no matching state would be fast but incorrect.

### Android Remote product lifecycle integration

_Reviewed: 2026-11-05_

#### Official lifecycle facts applied

- Flutter's [`AppLifecycleState`](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html)
  documentation says Android `Activity.onPause` maps to Flutter `inactive`,
  while Android `Activity.onStop` maps to Flutter `paused`. `inactive` can also
  mean a visible app lost focus to a system dialog, notification shade, split
  screen, or picture-in-picture, so it is too aggressive a disconnect boundary.
- Flutter synthesizes `hidden` immediately before mobile `paused` and before
  returning from `paused`; [`AppLifecycleListener`](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html)
  provides matching `onHide` and `onShow` callbacks. These are the visibility
  boundary used for Remote suspend/resume; desktop receives the callbacks too,
  but desktop `RuntimeController` deliberately treats them as no-ops.
- Flutter explicitly warns that lifecycle notifications may be skipped when the
  process is killed or the device terminates unexpectedly. Correctness therefore
  cannot depend on receiving hide/detach: cold start still refuses cursor-only
  resume without an exactly matching in-memory projection.

#### Adopted here

- Android `RuntimeController` creates the secure credential/cursor adapters,
  bounded projection, and lifecycle coordinator by default. Desktop continues
  to locate/spawn the bundled Host and stock Codex through `ProcessTransport`.
- Map each lifecycle phase to an explicit redacted product state. Unpaired,
  unreadable credential, retry, revoked, suspended, and read-only ready are not
  collapsed into a generic connection error. Socket negotiation alone never
  produces the ready state.
- Use `onHide` to suspend Remote, `onShow` to restart it, and detach for full
  shutdown. Suspend closes the socket but preserves only the coordinator's
  verified applied projection/cursor pair.
- Present only the bounded ready projection: a virtualized list of at most 100
  thread summaries plus model count/default model. The view is explicitly
  labeled read-only. It does not instantiate a parallel conversation model or
  expose create/resume/composer/approval/history/output/settings actions.
- Existing gateway methods reject locally in Remote mode. This prevents future
  widget reuse from silently issuing an RPC that the Host has not made safe.

#### Validation and boundaries

- Two integration tests cover state mapping and redaction, projection exposure,
  local gateway rejection, read-only widget contents, and hide/show
  suspend/resume. The first hidden-state test expected the screen to repaint to
  “suspended”; Flutter intentionally stops visible frame scheduling while
  paused, so the correct evidence is controller suspension while hidden and a
  refreshed ready view after `onShow`. The first 412×915 run also exposed a
  100-pixel overflow in the runtime status row; the status label now takes the
  remaining row width and wraps on a phone viewport.
- All 120 Flutter tests, fatal-info Dart analysis, formatting, Linux debug build,
  and Android debug assembly pass. No emulator or physical device was available,
  so Android Activity/process callbacks, Keystore access, WSS, network switching,
  OS process death, and Human layout/interaction remain unverified.
- At this slice boundary the unpaired screen remained an intentional blocker;
  the following slice adds bounded default-root pairing and explicit recovery.
  Pairing-bound local certificate identity remains separate and record version 1
  remains limited to the runtime's default trusted roots.

### Bounded Android pairing and credential recovery onboarding

_Reviewed: 2026-11-05_

#### Sources re-reviewed

- Dart 3.13 [`HttpClient`](https://api.dart.dev/dart-io/HttpClient-class.html),
  [`SecurityContext`](https://api.dart.dev/dart-io/SecurityContext-class.html),
  and [`connectionTimeout`](https://api.dart.dev/dart-io/HttpClient/connectionTimeout.html)
  documentation plus the installed Dart 3.13.1 SDK source. The connection
  timeout applies only to establishing a new connection; a separate whole-
  operation deadline is required. Response bodies are streams that must be
  consumed or drained. The exact SDK says Linux/Windows default roots come from
  Mozilla while macOS/iOS/Android roots come from the platforms' built-in trust
  stores. This corrects the earlier over-broad Mozilla-root description without
  claiming that every Android user-added CA, proxy, or VPN behavior is covered.
- This repository's actual Host router and auth implementation: exact
  `/v1/pair`, 8 KiB HTTP body limit, ten attempts/minute, 24-character URL-safe
  single-use tickets, 80-character Host-bounded names, 22-character device IDs,
  43-character device tokens, read/device-rotate scopes, 401/409/429 failure
  classes, and an exact protocol-version-1 response.
- `codex-remote` at
  [`fcdf784`](https://github.com/Venompool888/codex-remote/commit/fcdf784e6365735ad9efde5cb43c5126042f4556),
  re-reading `PairingLink.kt`, `AddConnectionController.kt`, `RemoteClient.kt`,
  `SecureTokenStore.kt`, and the Host pair route. Its useful ideas are transient
  one-use-code fields, explicit server confirmation, generation-scoped async UI
  callbacks, Host-side rate limits, and encrypted per-Host device tokens. Its
  source-available license remains research-only here.
- `codex-remote-android` at
  [`372581a`](https://github.com/liuhao-labs/codex-remote-android/commit/372581ad5cc66677d5322a9a447a03277d36ce15),
  re-reading `SshAppServerTransport.kt`, `ConnectionStore.kt`, and the host-key
  confirmation UI. It blocks unknown/changed SSH identity before sending a
  password or private key and requires explicit fingerprint acceptance. That is
  compatibility/security evidence for a future local-certificate bootstrap,
  not a reason to adopt SSH as this project's primary transport.

#### Adopted here

- Accept exactly the persisted record-v1 WSS `/v1/ws` endpoint, derive only its
  same-origin HTTPS `/v1/pair` route, and reject userinfo, query, fragment,
  plaintext, wrong paths, invalid ticket alphabets/lengths, control characters,
  and names above 80 Unicode scalar values before network access.
- Use a fresh `HttpClient` for one POST with automatic decompression off,
  redirects off, one connection per Host, an identity encoding request, a
  five-second connection timeout, a 15-second whole-operation timeout, and an
  8 KiB streamed response cap. The exchange is injectable for deterministic
  protocol tests. No error includes the URI, code, response body, token, or TLS
  details, and no `badCertificateCallback` exists.
- Require HTTP 200 plus JSON content type and exact versioned response keys.
  Validate the Host's device identity/name, both required scopes, monotonic
  issuance/expiry, null initial rotation/revocation/last-seen fields, and bearer
  format before constructing the existing strict credential record.
- Keep pairing state separate from connection readiness. A successful exchange
  is written and read back through the existing serialized secure credential
  owner, then the prior lifecycle generation is stopped before a new load starts.
  This prevents an older foreground absent-credential read from winning after a
  successful save. Hiding or detaching never starts a socket; an accepted token
  is still saved so the one-use credential is not intentionally orphaned.
- Recovery cannot be reached through the pairing form and cannot overwrite an
  unreadable record. An affirmative dialog stops the lifecycle, verifies cursor
  deletion first, then verifies credential deletion. Failure restarts persisted-
  state discovery while visible; success returns to unpaired. Clearing this
  device never claims Host-side revocation.

#### Deliberate non-adoptions and remaining boundaries

- Do not adopt the reference client's HTTP/USB onboarding, automatic protocol
  fallback after 404, full response-body string reads, raw Host error messages,
  asynchronous unverified preference writes, or decrypt-error-as-absence
  behavior. Do not send Android model/device metadata automatically; the user
  owns the bounded display name.
- Record version 1 does not trust a self-signed certificate and does not accept
  a fingerprint learned after the ticket has already been sent. The future local
  certificate flow needs a pairing invitation that binds endpoint, ticket, and
  certificate/CA identity through the trusted local surface, a new record
  version, and one scoped client trust context.
- `HttpClient` evidence does not prove Android proxy, VPN, user-added CA,
  captive-portal, Doze, or network-switching behavior. The pairing and WebSocket
  implementations must also be tested with the same real certificate chain; a
  pairing-only success is not connection readiness.
- At this slice boundary the Host local RPC could create a ticket, but the
  desktop product could not present an explicitly configured client endpoint or
  manage devices. The following trusted desktop setup slice closes that manual
  RPC gap without changing the Android trust model.

#### Validation and preserved negative evidence

- Pairing, onboarding, cursor, runtime integration, and 412×915 widget tests now
  contribute to 135 passing Flutter tests. Fatal-info analysis, formatting, the
  Linux debug build, and Android debug assembly also pass; the unchanged
  three-ABI APK is 191,469,644 bytes. Tests cover exact request derivation,
  all current Host status classes, timeout, malformed/oversized success,
  readback-before-start, hidden and shutdown races, recovery preservation,
  explicit clear, clear failure, and affirmative UI confirmation.
- The first route assertion showed that `Uri.replace(query: '', fragment: '')`
  emits an unwanted trailing `?#` even when both components are empty. The code
  now replaces only scheme/path, relying on prior endpoint validation, and the
  test requires the exact `/v1/pair` URI.
- Concurrency review found that an application-show reload could still be
  finishing an absent-credential read when pairing saved a new record. A direct
  `start()` could then no-op while active and leave the later absent result as
  final. Pair activation now stops that generation before starting the verified
  record. The same review found clear failure could leave the lifecycle stopped;
  visible recovery now restarts state discovery after failure.
- Linux is the only connected Flutter device in this environment. No Android
  Keystore call, default-root HTTPS exchange, IME flow, Activity lifecycle,
  backup/restore, process kill, or Human interaction was executed. Those remain
  release gates rather than inferred passes.

### Trusted desktop Remote setup and explicit endpoint advertisement

_Reviewed: 2026-11-05_

#### Sources and constraints re-applied

- `codex-remote` at
  [`fcdf784`](https://github.com/Venompool888/codex-remote/commit/fcdf784e6365735ad9efde5cb43c5126042f4556),
  specifically its explicit `publicUrl`, `PairingLink.kt`, generation-scoped
  setup controller, secure token store, and Host pair route. The useful product
  evidence is that a public client endpoint is explicit and invalid public
  configuration is visible; one-use material is transient and created through
  an operator action. Its HTTP onboarding, protocol fallback, unbounded response
  strings, and unverified asynchronous preference writes remain deliberate
  non-adoptions.
- `codex-remote-android` at
  [`372581a`](https://github.com/liuhao-labs/codex-remote-android/commit/372581ad5cc66677d5322a9a447a03277d36ce15),
  whose SSH setup blocks on explicit Host fingerprint confirmation before
  credentials. This supports keeping identity and invitation presentation on a
  trusted local surface, but does not justify adopting SSH or TOFU after a
  pairing ticket is sent.
- This repository's implemented Host behavior remains authoritative: listener
  bind scope/TLS are runtime facts, pairing tickets last five minutes with only
  one active ticket, public device records are capped at 32, and local
  `host/remote/*` calls are separated from the authenticated network allowlist.

#### Adopted here

- Add a separate optional advertised endpoint rather than reconstructing one
  from the listener. Accept only exact WSS `/v1/ws`, reject user info, query,
  fragment, port zero, and unspecified IP hosts, and require a listener to be
  enabled. Preserve reverse-proxy deployments by not requiring the endpoint to
  equal the bind address or local TLS flag.
- Return the endpoint in both `host/status` and ticket creation. The desktop
  adapter requires exact bounded Host-owned schemas, rejects unexpected bearer
  data, caps the device list at 32, and redacts endpoint/ticket/device IDs from
  object strings and product errors.
- Keep administration outside `CodexTransport`; only the connected desktop
  `ProcessTransport` exposes it. Opening the dialog performs status/device reads
  but creates no ticket. An explicit button creates one ticket, verifies that
  its endpoint still matches status and that it is unexpired, and drops the
  ticket when the dialog closes. The UI never enables or rewrites listener
  configuration.
- Require confirmation before revocation and read the device list back from the
  Host. Count only active credentials toward the 32-device pairing limit; prune
  revoked/expired records atomically only when publishing a replacement so the
  store remains bounded and a just-revoked row can still be read back.

#### Deliberate non-adoptions and validation boundary

- Do not auto-discover LAN addresses, turn `0.0.0.0` into a hostname, create a
  ticket when the dialog opens, copy a ticket to the clipboard automatically,
  log it, persist it, enable a listener, edit configuration, or expose local
  administration to a Remote device.
- This surface does not prove that the configured endpoint is reachable, that
  its certificate chains on Android, or that a reverse proxy forwards the exact
  routes and headers. Those are installed-network/device gates. QR transfer and
  self-signed/local-CA bootstrap still require a versioned pairing artifact that
  binds endpoint, ticket, and Host identity before credentials are sent.
- Six protocol, six controller, three widget, one process-correlation, and three
  new Rust regressions cover malformed endpoints/shapes, no automatic ticket,
  dialog-lifetime state, endpoint/expiry consistency, affirmative revocation,
  authoritative readback, stale disposal, actual Host status projection, and
  capacity release by revoked/expired credentials. All 151 Flutter and 78 Rust
  tests pass, together with fatal-info analysis, strict Clippy, Rust release,
  Linux debug, and Android debug builds.
- The first ProcessTransport test exposed that Dart's `Uri.port` cannot supply a
  default for the `wss` scheme when no explicit port exists; endpoint validation
  now reads the port only when `hasPort` is true. Adjacent review then exposed
  that revoked records still counted toward the old total-record limit, making
  the documented recovery action ineffective. Pairing now prunes inactive
  records at the atomic replacement boundary while preserving the active cap.
- A release Host with stock app-server reported a real ephemeral loopback bind,
  `tls=false`, and the independently configured WSS endpoint, then exited zero
  on EOF. This verifies propagation, not endpoint network reachability. Linux is
  still the only available device and no Human visual acceptance was performed.

### Versioned pairing invitation and local-certificate trust

_Reviewed: 2026-11-05_

#### Sources reviewed

- The installed Dart 3.13.1 `dart:io` source and current official
  [`SecurityContext` constructor](https://api.dart.dev/dart-io/SecurityContext/SecurityContext.html),
  [`setTrustedCertificatesBytes`](https://api.dart.dev/dart-io/SecurityContext/setTrustedCertificatesBytes.html),
  and [`HttpClient` constructor](https://api.dart.dev/dart-io/HttpClient/HttpClient.html).
  A new context has no roots by default; an injected context can therefore be
  scoped to one connection identity rather than changing global process trust.
- rustls 0.23
  [`RootCertStore::add`](https://docs.rs/rustls/latest/rustls/struct.RootCertStore.html#method.add),
  which strictly parses one expected DER trust anchor rather than silently
  accepting the valid subset of an arbitrary bundle. License: Apache-2.0 OR ISC
  OR MIT.
- Syncthing's maintained
  [device-ID](https://github.com/syncthing/syncthing/blob/main/man/syncthing-device-ids.7)
  and [security](https://github.com/syncthing/syncthing/blob/main/man/syncthing-security.7)
  documentation. It derives peer identity from certificate DER and compares the
  presented identity with preconfigured expectation; loss of the corresponding
  private key permits impersonation. License: MPL-2.0; no source code is copied.
- The already pinned `codex-remote` `fcdf784` public-URL/pairing flow and
  `codex-remote-android` `372581a` host-key confirmation flow. They reinforce
  explicit transient invitation state and identity confirmation before
  credentials, but their HTTP/SSH transports and licensing do not replace this
  project's WSS/Host boundary.

#### Findings that changed the implementation

- Do not infer the mobile trust anchor from the Host listener certificate
  chain. The client-visible endpoint may terminate at a reverse proxy, a chain
  may contain several candidates, and automatically choosing a leaf or CA can
  silently produce unusable or over-broad trust. Add a separate explicit trust-
  certificate setting instead.
- A certificate fingerprint inside an unauthenticated exchange is too late: the
  one-use ticket would already have been exposed to an impersonator. Endpoint,
  ticket, expiry, and trust identity must arrive together through the trusted
  local setup surface before the first HTTPS request.
- The certificate bytes are the actual per-connection trust anchor. The SHA-256
  value is a canonical consistency/fingerprint field, not an independent proof
  of authenticity. Authenticity comes from trusted transfer of the invitation.
- A stable private CA permits ordinary leaf rotation without changing Android
  state. Binding an exact self-signed leaf is narrower but requires Host restart,
  a fresh invitation, and re-pairing after that leaf changes. TLS reload alone
  must never silently migrate saved trust.
- The first product-path release smoke preserved a platform-specific negative
  result: Linux rejected the invitation's raw DER leaf through Dart
  `SecurityContext`, although rustls accepted the same DER as a root. The
  official API describes PEM/PKCS#12 generally and single DER specifically for
  iOS. The client now stores canonical DER but supplies PEM on non-iOS and DER
  on iOS. The next smoke then proved both HTTPS pairing and authenticated WSS;
  no arbitrary-certificate callback was introduced.

#### Adopted here

- `CODEX_NATIVE_REMOTE_PAIRING_TRUST_CERT`/
  `--remote-pairing-trust-cert` accepts exactly one bounded DER or PEM
  certificate only when both a listener and explicit advertised WSS endpoint
  exist. Host startup validates it with rustls before stock Codex starts. The
  setting is independent from server TLS files and is snapshotted until restart.
- Trusted-local ticket creation now returns one opaque
  `codex-native-pairing-v1.<base64url-json>` invitation. Its exact schema binds
  version 1, canonical WSS endpoint, 24-character single-use code, expiry, and
  either `{type: system}` or one certificate's SHA-256 plus DER. Both inner
  certificate and outer invitation have hard byte/character caps and exact-key
  parsing.
- Android accepts only that complete invitation plus its user-owned device
  name. It builds an empty, invitation-scoped trust context for certificate
  mode, performs same-origin HTTPS pairing, persists record version 2, and
  rebuilds the same scoped context for WSS. Version-1 system records remain
  readable and are upgraded only on a later verified save; the secure-storage
  key does not change.
- Desktop creates no invitation on open, retains it only for the dialog, and
  copies it only after an explicit user action that warns about the short-lived
  clipboard secret. Manual transfer is implemented; QR rendering is deferred
  until a QR encoder and practical payload/error-correction limits are reviewed.

#### Deliberate non-adoptions and remaining validation

- No TOFU after network contact, `badCertificateCallback`, global trust-store
  mutation, certificate-chain guessing, listener-address guessing, silent trust
  migration, or automatic clipboard write.
- The manual/base64 envelope is intentionally simple and auditable. Do not add
  compression merely to fit every possible 8 KiB certificate into a QR code;
  a later QR slice must measure real certificate sizes and define scan/error-
  correction behavior while preserving this version boundary.
- The release Host plus stock app-server now proves a generated self-signed
  certificate is rejected by ordinary system trust for both pairing and WSS,
  then accepted through the exact invitation-bound context; pairing, model/list,
  metadata history, live revocation, temporary cleanup, and Host exit all pass.
  This remains same-Linux-host evidence, not Android Secure Storage, camera/QR,
  LAN/firewall, Android TLS-provider, lifecycle, or Human acceptance evidence.

### Lockfile-derived native dependency notices

_Reviewed: 2026-11-05_

#### Sources reviewed

- `cargo-about` 0.9.3's maintained
  [quickstart](https://embarkstudios.github.io/cargo-about/),
  [configuration](https://embarkstudios.github.io/cargo-about/cli/generate/config.html),
  and [output-template](https://embarkstudios.github.io/cargo-about/cli/generate/output.html)
  documentation. It evaluates license expressions against an explicit accepted
  set, can fail on unreadable/unresolved license material, filters a union of
  target triples, and renders complete texts through a repository-owned
  template. License: MIT OR Apache-2.0.
- Cargo's official [`cargo metadata`](https://doc.rust-lang.org/cargo/commands/cargo-metadata.html)
  and [`cargo install`](https://doc.rust-lang.org/cargo/commands/cargo-install.html)
  documentation. `--locked` rejects dependency-resolution drift; installing a
  tool with its published lockfile also requires `--locked` explicitly.
- Mozilla's official [MPL 2.0 text](https://www.mozilla.org/en-US/MPL/2.0/)
  and [FAQ](https://www.mozilla.org/en-US/MPL/2.0/FAQ/). Section 3.2 and FAQ Q8
  require a distributor of a compiled, unchanged MPL library to tell recipients
  how to obtain its source; MPL-covered files can remain part of a larger work
  under another license when those obligations are preserved.

#### Findings that changed the implementation

- The hand-maintained native summary was not a complete release artifact. The
  first fail-closed generation found the unlisted MPL-2.0 `option-ext` 0.2.0
  runtime crate through `dirs`, and review also exposed that direct dependency
  `axum-server` was absent from the hand list. A successful compile is not
  evidence that transitive license texts have been packaged.
- Test-only dependencies must not inflate or confuse the distributed runtime
  notice, but target-specific and build dependencies that contribute to Linux,
  Windows, or macOS binaries must be included. One union over supported desktop
  target triples produces a conservative shared notice for every desktop.
- The generated artifact must be committed as reviewable source-distribution
  evidence and regenerated in CI. Generating only during a release would make
  legal drift invisible to ordinary code review; committing without a drift
  check would allow it to become stale.
- Upstream crate license files contain mixed LF/CRLF endings and, in a few cases,
  trailing horizontal whitespace. The first staged aggregate therefore failed
  the repository whitespace gate. Deterministic generation must normalize only
  those representation details and the final newline, not rewrite license prose.
- MPL-2.0 is accepted only for the unchanged `option-ext` crate. The generated
  entry includes its upstream source URL and full license text so recipients of
  the binary have both the notice and a reasonable source-acquisition path.

#### Adopted here and validation boundary

- Pinned `cargo-about` 0.9.3 runs with `--locked --workspace --fail`, explicit
  accepted licenses, maintained rustls clarification, runtime/build dependencies,
  and Linux/Windows/macOS target unions. The repository-owned plain-text template
  emits exact crates.io source archives, repositories, SPDX choice, and complete
  texts without absolute local paths, then canonicalizes line endings and
  trailing whitespace.
- `./tool/generate_native_licenses.sh --check` compares a fresh temporary result
  byte-for-byte with `licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt`; `--write`
  is the only regeneration path. CI installs the exact generator version and
  checks drift before application validation.
- Linux and Windows CMake installs place the notice beside the Host. The macOS
  Host build phase installs it in `Contents/Resources` and declares that output
  to Xcode. A real Linux debug bundle contains a byte-identical 257,985-byte,
  mode-0644 notice beside the mode-0755 Host.
- This Linux slice initially source-reviewed only the Windows/macOS edits. The
  later hosted matrix verified the built Windows bundle and exposed the macOS
  Bash 3.2 defect documented below. A later run verified corrected macOS native
  execution; installation, signing/notarization, and legal review remain
  distinct gates.

## Hosted CI hardening and cross-platform build gates

_Reviewed: 2026-11-06_

### Sources reviewed

- GitHub's official [secure-use guidance for third-party actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions),
  which identifies a full commit SHA as the only immutable third-party action
  reference, and the official [GitHub-hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
- The maintained `actions/runner-images` [available-image table](https://github.com/actions/runner-images#available-images):
  Ubuntu 22.04 x64, Windows Server 2022 x64, and macOS 15 arm64 are supported
  standard images; macOS 14 was retired on 2026-11-02.
- Flutter's official [supported-platform matrix](https://docs.flutter.dev/reference/supported-platforms)
  and [continuous-delivery guidance](https://docs.flutter.dev/deployment/cd).
  Flutter 3.47 supports the selected desktop OS/architectures and tests Linux on
  Ubuntu 22.04 and macOS on macOS 15.
- `flutter_secure_storage_linux` 3.0.3's published [Linux requirements](https://pub.dev/packages/flutter_secure_storage_linux/versions/3.0.3),
  which require `libsecret-1-dev`, and Cargo's official
  [`rust-version` manifest semantics](https://doc.rust-lang.org/cargo/reference/manifest.html#the-rust-version-field).

### Findings that changed the implementation

- The prior `ubuntu-latest` job neither fixed the runner image nor built Android,
  Windows, or macOS. Adding Linux secure storage also made `libsecret-1-dev` a
  required compiler dependency that the old job did not install.
- The latest three hosted runs visible before this change passed, but the newest
  run (`42034034310`) tested only remote commit `2c7f8b9`, not the newer
  local-only history. A green old run cannot be used as evidence for this
  workflow or current tree.
- A clean official Rust 1.87.0 toolchain rejected the locked graph before
  compilation: `uuid` 1.29.0 requires rustc 1.89.0. An isolated official Rust
  1.89.0 toolchain then compiled from empty Cargo/target state and passed all 84
  Rust tests. The former `rust-version = "1.87"` was therefore a false release
  claim, not a compatibility feature worth preserving.
- `subosito/flutter-action` at the reviewed commit contains optional floating
  `actions/cache@v5` steps. This workflow explicitly disables that cache, so
  those conditional steps do not execute; both top-level actions are pinned to
  reviewed full SHAs and checkout persistence is disabled.
- The first current-tree run (`42063855051` at `a77e6ac`) supplied the native
  evidence configuration review could not. Windows Server 2022 x64 passed the
  complete debug bundle, Host/license placement, and Host execution gate.
  Exact Rust 1.89 Clippy rejected a test-only explicit `drop` of a non-`Drop`
  closure, and macOS 15 arm64's system Bash 3.2 rejected expansion of an empty
  array under `set -u`. These are compiler/shell compatibility defects, not
  reasons to weaken the gates.
- The same run warned that the pinned checkout v4 build targeted Node 20 and
  GitHub was forcing it onto Node 24. The official `actions/checkout` v7.0.1
  release commit `3d3c42e5aac5ba805825da76410c181273ba90b1`
  declares `runs.using: node24`, eliminating that compatibility shim without
  restoring persisted checkout credentials.
- Follow-up run `42066453043` passed corrected macOS arm64, Windows x64,
  exact-Rust Clippy/tests, Dart/Flutter analysis/tests, and Linux packaging. The
  Android debug build alone failed before compilation: Flutter reported Java
  11.0.32 driving Gradle 9.3.1. Gradle's official compatibility matrix requires
  JVM 17 or later for Gradle 9; runner defaults therefore cannot define the
  Android build toolchain.
- Official `actions/setup-java` v6.2.0 commit
  `77dd5b2ce225ea11469928ac317850245a74ae78` declares Node 24. Selecting the
  minimum compatible Temurin 17 makes the CI contract match the Android source
  and Kotlin JVM 17 targets without opportunistically advancing to a newer JDK.
- Local OpenJDK 17.0.20.1 then ran the real Gradle 9.3.1 wrapper through all 185
  `assembleDebug` tasks and emitted a non-empty 191,469,644-byte APK. This used
  only the already documented temporary ASCII Flutter-SDK alias needed for the
  repository's Unicode host path; it did not substitute for the hosted rerun.
- Final run `42068745322` at `e11a36c` passed all jobs. Ubuntu selected Temurin
  17 and completed source/license/signing-contract checks, exact Rust 1.89
  Clippy/tests, Dart/Flutter analysis/tests, the Linux bundle/license gate, and
  Android debug build plus non-empty APK assertion. Windows x64 and macOS arm64
  both completed their native bundle, packaged Host execution, and license
  identity checks.

### Adopted here and validation boundary

- The primary Ubuntu 22.04 x64 job installs the actual Linux compiler
  dependencies, selects Flutter 3.47.1, exact Rust 1.89.0, and Temurin 17, runs
  formatting, license drift, strict Clippy, all Dart/Rust tests and analysis,
  then builds both the Linux debug bundle and Android debug APK.
- A fail-independent matrix builds Windows Server 2022 x64 and macOS 15 arm64.
  Each job checks that the Host is non-empty, executes its packaged `--help`, and
  verifies the native-license notice at the platform's real bundle location.
  PR CI remains read-only and unsigned; signing, notarization, installation,
  native ACL inspection, and Human use are separate release gates.
- `actions/checkout` v7.0.1 is pinned to
  `3d3c42e5aac5ba805825da76410c181273ba90b1` with no persisted credentials;
  `subosito/flutter-action` is pinned to
  `1a449444c387b1966244ae4d4f8c696479add0b2` with cache disabled. Concurrency
  cancels superseded runs. `actions/setup-java` v6.2.0 is pinned to
  `77dd5b2ce225ea11469928ac317850245a74ae78`, with no dependency cache enabled;
  monthly Dependabot review remains limited to the GitHub Actions ecosystem.
- Pinned `actionlint` 1.7.12 and independent YAML parsing pass locally. After
  the first hosted failures, lexical borrow scoping passes strict Clippy plus 84
  tests on a fresh official Rust 1.89.0 toolchain, and non-empty macOS command
  arrays pass shell parsing plus local Debug/Release packaging simulation.
  Hosted Windows x64, corrected macOS arm64, Linux, explicit Temurin 17, and
  Android debug assembly are now real passes in one final matrix. Release
  signing, notarization, installation, ACL inspection, physical-device behavior,
  and Human use remain separate evidence until their respective gates run.

## Fail-closed Android release signing

_Reviewed: 2026-11-06_

### Sources reviewed

- Flutter's official [Android release guide](https://docs.flutter.dev/deployment/android),
  including the Kotlin DSL `key.properties` flow, private-file warning, signed
  App Bundle output, and preference for AAB distribution through Google Play.
- Android's official [app-signing guidance](https://developer.android.com/studio/publish/app-signing),
  which distinguishes the insecure, SDK-generated debug certificate from the
  upload/app-signing identities required for publication and emphasizes that
  private signing material must remain protected.
- Android's official [build-variant signing behavior](https://developer.android.com/build/build-variants#signing),
  which states that release artifacts are not signed unless an explicit release
  signing configuration is defined and recommends keeping signing data outside
  source build files.

### Findings that changed the implementation

- The Flutter template's temporary `signingConfig = debug` was still active.
  Earlier 51,791,110-byte "release" APK evidence therefore proved R8/native
  compilation only; it did not prove a distributable release identity and must
  not be treated as RC signing evidence.
- Silently emitting an unsigned archive would still leave an ambiguous artifact
  that could be mislabeled later. Release assembly should stop before expensive
  packaging when the external upload-key contract is missing, while debug
  builds and IDE sync must remain usable for contributors without private keys.
- The keystore path and three credential values are operator-owned secrets. The
  repository can define and test their shape, but creating a production key,
  choosing Play App Signing policy, storing CI secrets, and granting publication
  permissions require a separate explicit Human/release decision.

### Adopted here and validation boundary

- `android/app/build.gradle.kts` loads only the Git-ignored
  `android/key.properties`, requires non-empty `storeFile`, `storePassword`,
  `keyAlias`, and `keyPassword`, and verifies that the external store is a
  readable file. It creates the release signing configuration only when the
  complete contract is present. `preReleaseBuild` otherwise fails with bounded
  diagnostics containing property names but no values or keystore contents.
- The repository ships only `android/key.properties.example` placeholders.
  A CI-owned static validator checks the release-only Gradle contract, explicit
  absence of debug-signing fallback, private-file ignore rules, and exact
  placeholders without reading any ignored local signing file.
  Debug assembly still passes all 185 actionable tasks. With no private config,
  `assembleRelease` stops on the intended signing error. With a temporary
  30-day local RSA test keystore, `assembleRelease bundleRelease` passed;
  `apksigner` verified the 54,019,334-byte APK and its certificate digest exactly
  matched the temporary key, while `jarsigner` verified the 52,739,360-byte AAB.
  The private key, ignored properties, SDK alias, and signed test artifacts were
  then removed.
- This is build-contract evidence, not production signing. No upload key, Play
  Console application, Play App Signing enrollment, key backup/rotation plan,
  CI secret, store validation, publication, or physical-device install was
  created or claimed.

## Bounded desktop pairing QR presentation

_Reviewed: 2026-11-06_

### Sources reviewed

- DENSO WAVE's official QR Code
  [version](https://www.qrcode.com/en/about/version.html),
  [error-correction](https://www.qrcode.com/en/about/error_correction.html), and
  [symbol-construction](https://www.qrcode.com/en/howto/code.html) guidance.
  Standard QR Code versions range from 1 to 40; the maximum Version 40 byte
  capacity is 2,953 bytes only at low correction, higher correction consumes
  capacity, and a four-module margin is required around the symbol.
- The maintained [`qr` 4.0.1](https://pub.dev/packages/qr) package and its
  [source/license](https://github.com/kevmoo/qr.dart). It is a pure-Dart,
  offline matrix generator with Version 1-40 and standard error-correction
  support. License: BSD 3-Clause.
- The repository's exact `codex-native-pairing-v1` encoder/decoder and Host
  constants. The protocol deliberately permits up to 24 KiB of invitation text
  and 8 KiB of DER certificate material, so protocol validity cannot imply
  single-symbol QR capacity.

### Findings that changed the implementation

- Do not derive a second compact pairing representation. Splitting an
  invitation across symbols, compressing it, dropping trust material, or adding
  a QR-only schema would add ordering, allocation, compatibility, and security
  review surfaces. The exact existing envelope remains the only input.
- Medium error correction is appropriate for a transient desktop display, but
  it makes the single-symbol capacity smaller than the official low-correction
  maximum. The encoder must therefore expose ordinary capacity failure as a UI
  fallback, not a protocol error.
- A QR matrix must retain the required four-module white quiet zone and integer
  module geometry. The painter uses three logical pixels per module with
  antialiasing disabled and refuses to shrink below that scale when the dialog
  is too narrow.
- The invitation is a five-minute one-use capability. Generating the matrix
  only once per ticket avoids repeated encoding during rebuilds, and removing
  the ticket at its authoritative expiry ensures the QR does not remain visible
  after the represented capability is stale.

### Adopted here and validation boundary

- `RemotePairingQr.tryEncode` reuses the authoritative invitation decoder,
  rejects noncanonical whitespace and non-ASCII bytes, encodes the exact bytes
  at medium correction, and returns no object for malformed or Version 40
  overflow input. Its diagnostics redact the payload.
- The desktop setup keeps Copy invitation before the QR so the complete manual
  path remains accessible even when a large symbol extends the dialog. Normal
  system-root and bounded-certificate invitations render; a protocol-valid
  invitation carrying a 3,000-byte certificate proves the single-symbol
  overflow fallback. A 1,100-byte certificate produces a Version 40/M symbol
  measuring 555 logical pixels including the quiet zone; at a 620-pixel window,
  the constrained dialog refuses to shrink it and preserves manual copy.
- `RemoteAdminController` schedules the accepted ticket's exact remaining
  lifetime, cancels replacement/refresh/disposal timers, and removes the ticket
  plus QR projection on expiry. No QR bitmap, matrix, or invitation is persisted.
- Eight focused unit/widget tests pass. An attempted test-backend pixel capture
  through `RenderRepaintBoundary.toImage()` hung indefinitely twice and had to
  be interrupted, so it was removed rather than called a visual pass. Matrix
  construction, fallback state, copy behavior, and expiry lifecycle are tested;
  camera decoding, cross-device interoperability, display scaling, physical
  Android behavior, and Human visual acceptance remain unverified.
- A separate attempt to drive the complete desktop shell at 320 logical pixels
  exposed existing horizontal overflows in its split workspace, runtime header,
  and paired-device summary before a ticket could be created. That probe is not
  counted as QR evidence. Compact desktop-window responsiveness remains a
  distinct machine-actionable limitation rather than a hidden passing result.
- Android scanner implementation remains deferred until camera permission,
  selection, lifecycle, bounded decode input, accessibility/manual fallback,
  and dependency licensing receive a separate review. Desktop generation does
  not grant permission to loosen the invitation parser or trust boundary.

## Android pairing QR scanner

_Reviewed: 2026-11-06_

### Sources reviewed

- [`mobile_scanner` 7.5.0](https://pub.dev/packages/mobile_scanner), its
  controller/widget source, changelog, BSD 3-Clause license, and Android Gradle
  graph. The package uses CameraX and ML Kit on Android, supports QR-only format
  selection, exposes explicit start/stop lifecycle ownership, and defaults to a
  bundled barcode model unless an unbundled Gradle property is enabled.
- Flutter's official
  [`AppLifecycleState`](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html)
  and `WidgetsBindingObserver` contracts. Android's official
  [permission declaration](https://developer.android.com/training/permissions/declaring),
  [runtime permission](https://developer.android.com/training/permissions/requesting),
  and [`uses-feature`](https://developer.android.com/guide/topics/manifest/uses-feature-element)
  guidance establish that camera access should follow an affirmative feature
  action, denial must degrade gracefully, and camera/autofocus features must be
  explicitly optional when the app remains functional without them.
- Google's official [Android barcode-scanning](https://developers.google.com/ml-kit/vision/barcode-scanning/android),
  [ML Kit terms/privacy](https://developers.google.com/ml-kit/terms), and
  [Play data-disclosure](https://developers.google.com/ml-kit/android-data-disclosure)
  pages. Barcode pixels and results are processed on-device. The bundled model
  is immediately available, but ML Kit may contact Google for maintenance and
  sends performance/utilization metrics. Auto-zoom adds session, zoom, and
  candidate-box metrics, so it remains disabled.
- `qr_code_scanner_plus` 2.3.2 and `lightweight_barcode_scanner` 0.4.1 were
  reviewed as Android/iOS-only offline alternatives. The former's own README
  calls its Android native ZXing integration outdated and unmaintained. The
  latter has a notably clean QR-only native pipeline and Apache-2.0 vendored
  ZXing-C++ provenance, but at review time it was 27 days old with one like and
  194 downloads, so its camera/permission lifecycle has too little independent
  use to replace the mature option before physical-device validation.

### Findings that changed the implementation

- “Bundled” means that the model is immediately present, not that the runtime
  is network-silent. The resolved `com.google.mlkit:barcode-scanning` 17.3.0
  graph includes `play-services-mlkit-barcode-scanning` 18.3.1 and Google data
  transport. Notices and future store disclosures must preserve the documented
  metrics behavior; the product text says only that camera frames and decoded
  invitation content stay on-device.
- A standard Version 40 QR has 177 modules before its quiet zone. The scanner
  requests 1280x720 rather than the package's 640x480 Android default, while
  still requiring the code to occupy a useful part of the frame. Physical focus
  and dense-symbol recognition are not inferable from a successful build.
- Permission is requested only when the user selects Scan QR. A denied,
  permanently denied, unavailable, or interrupted camera never removes or
  disables manual paste. The manifest declares camera-any, back camera, and
  autofocus as optional to avoid filtering camera-less/front-only devices.
- Scanner intake is not trusted. It keeps only decoded text, accepts the first
  exact current canonical `codex-native-pairing-v1` value, and rejects null,
  whitespace-modified, oversized, malformed, and expired candidates without
  logging them. It closes back to the obscured form and does not call pairing;
  Pair and connect remains a separate user action.
- Camera operations are serialized. The initial permission prompt's inactive
  transition is ignored before permission exists so an early resume cannot
  strand the scanner stopped. Hidden/paused/detached always queue stop behind a
  pending start, so a camera acquired after real backgrounding is immediately
  released. After permission, inactive also stops and resumed queues start.
  Route disposal waits behind the same operation chain before disposing the
  driver, while also retaining the package's repaired session-release behavior.

### Adopted result and evidence boundary

- Added an injectable scanner driver and full-screen route. Production uses
  `mobile_scanner` 7.5.0 with manual start, `DetectionSpeed.noDuplicates`, QR
  only, no returned frame, no auto-zoom, and 1280x720 capture. Tests use a fake
  driver, so Linux test execution never opens a platform camera.
- Five scanner tests cover canonical/current bounds, invalid-then-valid intake,
  duplicate valid detection, lifecycle ordering, delayed-start disposal, and
  permission-denied manual fallback. The onboarding widget proves a scanned
  value only fills the field and remains unsubmitted until Pair and connect is
  selected.
- Android source declares `CAMERA` plus optional camera-any, back-camera, and
  autofocus features. A source validator pins the reviewed dependency/settings,
  rejects an unbundled first-use-download flag, and requires dependency terms to
  ship as a Flutter asset.
- Direct Gradle `assembleDebug` passed with 215 tasks after using the established
  temporary ASCII Flutter-SDK alias. The merged manifest contains the expected
  permission and optional features. The universal debug APK is 214,274,417
  bytes, 22,804,773 bytes larger than the prior 191,469,644-byte evidence. This
  is debug/universal packaging evidence, not per-device release download or
  installed-size evidence.
- The build retains existing AGP 9 built-in-Kotlin and SDK XML skew warnings and
  adds a `mobile_scanner` legacy Android DSL deprecation. A successful assembly
  does not erase those warnings. The package also registers a native macOS
  plugin even though this product exposes scanning only on Android; hosted
  macOS compilation remains required after publication.
- No physical Android camera, runtime permission dialog, Settings recovery,
  process death, rotation, front-only/camera-less device, dense Version 40
  recognition, or desktop-to-phone interoperability was exercised. These remain
  explicit device/Human gates rather than inferred passes.

## Desktop review-artifact assembly and provenance boundary

_Reviewed: 2026-11-06_

### Sources reviewed

- Flutter's official Linux
  [build](https://docs.flutter.dev/platform-integration/linux/building) and
  [deployment](https://docs.flutter.dev/deployment/linux), Windows
  [build](https://docs.flutter.dev/platform-integration/windows/building) and
  [deployment](https://docs.flutter.dev/deployment/windows), and macOS
  [build](https://docs.flutter.dev/platform-integration/macos/building) and
  [deployment](https://docs.flutter.dev/deployment/macos) guidance. Desktop
  distribution carries the complete generated bundle; Windows Store identity,
  macOS Developer ID/hardened-runtime/notarization, Linux packaging, and native
  dependencies remain distinct platform concerns.
- GitHub's official workflow-artifact
  [guidance](https://docs.github.com/en/actions/tutorials/store-and-share-data),
  artifact-attestation
  [guide](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations),
  and [immutable-release](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)
  model, plus `actions/upload-artifact` v7.0.0 at immutable commit
  `bbbca2ddaa5d8feaa63e36b76fdaad77386f024f`. Directory upload normalizes file
  permissions, while pre-archiving preserves modes and case. Attestation needs
  `id-token: write` plus `attestations: write`; Release creation is a separate
  publication boundary.
- OpenAI Codex's release workflow at `be765f1` stages per-target outputs,
  separates unsigned macOS inputs from protected signing, pins upload actions,
  validates tag/version identity, and finalizes artifacts only after the target
  jobs. It is evidence for explicit staging and signing separation, not
  authorization to copy its protected environments or publication permissions.
- TuxCodex at `1905fc4` builds and smokes native Linux packages on multiple
  distributions and produces Windows/macOS installers before a tag-only release
  job. Its stronger installer breadth confirms that successful compilation is
  not installed-package evidence; this Flutter project does not yet have those
  packaging identities or installed-runtime gates.
- `moyi888/codex-remote-android` at `2bbf50a` uses a simple tag/manual workflow
  to upload versioned Windows executables and an Android debug APK, then grants
  a tag-only job `contents: write` to create a prerelease. Its explicit release
  contract is useful, but a debug APK and individually copied executable are not
  acceptable production identities or complete Flutter desktop bundles here.

### Findings that changed the implementation

- GitHub's default artifact ZIP cannot be the only packaging layer for Linux or
  macOS because executable modes are normalized and framework symlink/case
  behavior must remain intact. Each platform now creates a tar.gz before the
  upload action; the workflow uploads that opaque archive plus checksum and
  provenance sidecars.
- A release-mode executable alone is incomplete. The platform gate requires the
  full Flutter layout, AOT runtime, ICU, application assets and notices, bundled
  Host and native notice. It rejects `kernel_blob.bin`, so a mislabeled debug
  bundle does not pass merely because its runner launches.
- Checksums prove byte consistency only relative to the sidecar that carries
  them; they are not publisher authentication. The archive is therefore named
  `review-only`, its inner and outer metadata both state
  `distributionReady=false`, and platform-specific signing/notarization gaps are
  machine-readable rather than hidden in release prose.
- Source provenance must not trust a free-form workflow argument. Assembly
  verifies the supplied 40-character revision against repository `HEAD` and the
  declared clean/dirty state against Git status before recording either.
- Enabling GitHub attestations now would add OIDC and attestation write
  permissions; creating a Release would add content write authority. Neither is
  necessary for this machine-review slice, so the manual workflow remains
  `contents: read` and performs no tag, Release, signing, or publication action.
- Android cannot join an “unsigned review release” matrix without contradicting
  ADR-017. Its release variant continues to fail closed until the operator
  supplies the separately authorized upload identity.

### Adopted result and evidence boundary

- Added one shared Dart assembler/verifier for Linux x64, Windows x64, and macOS
  arm64. It rejects unsafe/control-character paths, absolute or escaping
  symlinks, existing outputs, notice drift, missing/empty installed-layout
  files, debug kernels, and a failing/ten-second-stalled Host help smoke. Failure
  removes only the exact partial outputs and private staging directory it owns.
- The archive contains the complete payload, sorted per-file SHA-256/size/mode
  or symlink-target manifest, canonical `SHA256SUMS`, and a prominent review-only
  warning. The sidecar binds archive bytes, manifest digest, app version/build,
  source revision/tree state, target, build mode, toolchains, origin, and signing
  boundary. Independent verification checks the outer digest and byte count,
  safe archive root, extraction, inner/outer metadata identity, exact payload
  inventory, sums, preserved layout, and release-only AOT markers.
- Four focused tests prove successful Linux assembly/reverification, rejection
  after one post-provenance archive byte is appended, and fail-closed behavior
  when `lib/libapp.so` is absent. The fourth models the hosted macOS bundle:
  framework binaries may be non-executable, while a non-executable app launcher
  still fails closed. A real local Flutter 3.47.1/Rust 1.89.0 Linux
  release bundle produced a 13,250,342-byte archive with digest
  `2ce56b20e1ae712c8c2fb05ce2f747c0ea76c7f4f705e75e47b44296fde7b8d4`;
  it self-verified, preserved executable modes, carried both exact notices, and
  contained no debug kernel. Because the source tree included this uncommitted
  implementation, its provenance truthfully records `treeState: dirty` and it
  is local validation only. Direct-path Flutter analysis reproduced the known
  Flutter 3.47.1 Unicode-path LSP truncated-JSON crash; strict Dart analysis and
  an independent ASCII repository copy both passed, so no project diagnostic
  was hidden behind that toolchain failure.
- `.github/workflows/desktop-review-artifacts.yml` is manual-only, read-only,
  immutable-action pinned, fail-independent across the three desktop targets,
  and retains review artifacts for 14 days. At initial implementation, hosted
  execution and downloaded-artifact verification remained separate gates; the
  later results below close both. Native installation, Linux dependency
  compatibility, Windows ACL/installer/SmartScreen behavior, macOS Developer ID
  signing/notarization/Gatekeeper behavior, and Human use remain separate gates.
- The first hosted run (`42091064595`) exposed one Windows-only pre-build defect
  before artifact assembly: without a repository EOL attribute, Windows checkout
  materialized the generated native notice with CRLF and the canonical-LF source
  validator failed. Weakening that validator would let platform checkout policy
  mutate a committed generated legal artifact. The repository instead pins only
  `licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt` to `text eol=lf`; the failed run
  was cancelled after diagnosis. Replacement run `42091784712` at `76bf94c`
  proved that source notice and its packaged Windows copy now pass the exact-LF
  gate, and Linux assembled, independently verified, and uploaded successfully.
  It also preserved two new negative results. Windows reached assembly but the
  post-build repository state was dirty; the then-current exception did not
  expose the path. The clean-provenance rule remains fail-closed, and its error
  now carries bounded porcelain status for a diagnostic rerun. macOS reached
  assembly but rejected `Contents/Frameworks/App.framework/App` for lacking an
  execute bit. That file is the AOT framework payload rather than a process
  launch target, so execute permission is now required only for the app runner
  and bundled Host; framework files remain mandatory, non-empty, inventoried,
  digested, and mode-preserved. Run `42091784712` remains failed and is not
  three-platform artifact evidence. Normal CI run `42091764792` at the same
  commit passed Ubuntu verification and Linux/Android debug builds plus native
  Windows x64 and macOS arm64 bundle gates. A corrected review-artifact rerun is
  still required.
- Corrective run `42093902515` at `43a256f` completed the full Linux x64 and
  macOS arm64 review-artifact jobs, including the previously failing macOS
  assembly, independent verification, and upload. Windows completed its release
  build but still failed the clean-source identity gate. The added bounded
  porcelain diagnostic made the evidence actionable: Windows had rewritten all
  seven tracked Flutter desktop plugin registrants (`.cc`, `.h`, `.cmake`, and
  `.swift`) across the Linux, macOS, and Windows shells. These are one generated
  family refreshed together by Flutter with host-native line endings, so their
  exact repository patterns are now pinned to LF. This is narrower than a
  whole-repository EOL policy and retains byte/content drift detection. The run
  remains failed; a fresh Windows runner must demonstrate that normalization
  removes only EOL drift and leaves the post-build tree clean. Companion normal
  CI run `42093880114` passed Ubuntu verification/Linux and Android debug builds
  plus native Windows x64 and macOS arm64 debug bundle gates.
- Fourth hosted run `42095949000` at `e71e5ac` demonstrated the targeted EOL
  contract on a fresh Windows Server 2022 runner: the release build left the
  tracked source clean, and Windows x64 proceeded through assembly,
  self-verification, independent verification, and upload. Linux x64 and macOS
  arm64 passed the same complete path, so the run concluded successfully on all
  three targets. This closes the hosted three-platform review-artifact gate while
  preserving every prior negative result and the exact source-provenance check.
- The three unexpired workflow artifacts were downloaded from that run and
  verified again from their artifact directories with
  `tool/verify_desktop_review_artifact.dart`; every invocation reported
  `DESKTOP_REVIEW_ARTIFACT_VERIFY=PASS`, and an independent `sha256sum`
  comparison matched each sidecar. The inner archive results were Linux
  13,388,830 bytes / `8d0228a93b2704f3b7be0f318770ef51e31858c98156b0fd2919cc5cf837ccad`,
  Windows 14,675,442 bytes /
  `457c56340960901907ec0c406b19fe87431dd5a0ce4cfc09a6d2b038b84f2949`,
  and macOS 21,631,021 bytes /
  `4fd8345c3b100381f902e2d3164960c9bd03f9f73e00485d585a5442d3efd098`.
  Their manifests contain 18, 17, and 43 entries respectively; only macOS has
  symlinks (nine safe framework links). The macOS app runner and Host retained
  mode 755, while `App.framework/Versions/A/App` retained its hosted mode 644,
  confirming the corrected semantic permission boundary. All sidecars bind
  clean revision `e71e5ac3aca98c38ed9e51f57fe0995efe1e24fd`, Flutter 3.47.1,
  Rust 1.89.0, workflow origin `42095949000:1`, review-only state, and an
  explicit platform signing gap. Companion normal CI `42095935941` also passed
  Ubuntu verification/Linux and Android debug builds and both native desktop
  debug-build jobs. None of this establishes installed dependency behavior,
  Developer ID/notarization/Gatekeeper, Authenticode/installer/ACL/SmartScreen,
  distribution signing, or Human acceptance.

## Relocatable Linux runtime and extracted-archive gate

_Reviewed: 2026-11-06_

### Sources reviewed

- Flutter's official Linux
  [build guidance](https://docs.flutter.dev/platform-integration/linux/building)
  defines the complete `bundle/` directory as the deployment unit and directs
  distributors to inspect the application with `ldd`, because the bundle still
  relies on system libraries. This supports a dependency-closure gate but does
  not itself choose a package format or prove compatibility beyond the tested
  distribution.
- CMake's official
  [`BUILD_WITH_INSTALL_RPATH`](https://cmake.org/cmake/help/latest/prop_tgt/BUILD_WITH_INSTALL_RPATH.html)
  and
  [`INSTALL_RPATH`](https://cmake.org/cmake/help/latest/prop_tgt/INSTALL_RPATH.html)
  documentation confirms that a target can be linked with its final install
  RPATH in the build tree, avoiding a later relink/edit step. That is relevant
  here because Flutter's generated Linux install logic copies plugin target
  files into the bundle instead of installing those targets.
- LocalSend at `92e133aa43869e94d394fd04fa70c50a0f796a64` builds on Ubuntu
  22.04 and archives the entire Flutter release bundle. It confirms the portable
  tar layout used by a mature Flutter desktop app, but its tar workflow does not
  independently extract, execute, or audit dynamic-library resolution.
- Invoice Ninja Flutter at `7b2dc0ea77c50c9a9558086015846022b587130d`
  builds on Ubuntu 22.04, keeps the runner, `lib/`, and `data/` colocated in its
  AppDir specifically because the runner uses `$ORIGIN/lib`, and then delegates
  broader GTK bundling to `linuxdeploy`. That supports the colocated relative
  lookup rule; adopting AppImage/linuxdeploy remains a separate distribution
  and update-policy decision rather than an implicit extension of review-only
  tar artifacts.

### Direct evidence and adopted boundary

- Before the fix, the main release runner correctly used `$ORIGIN/lib`, and an
  ordinary `ldd` of that runner resolved both plugins and the Flutter engine from
  `bundle/lib`. Inspecting the plugin ELF files directly exposed contradictory
  evidence: both `libflutter_secure_storage_linux_plugin.so` and
  `liburl_launcher_linux_plugin.so` retained the absolute repository path
  `linux/flutter/ephemeral` as RUNPATH. The already-successful hosted Linux
  artifact from run `42095949000` reproduces the defect after download: the new
  native verifier rejects its extracted secure-storage plugin path under
  `/home/runner/work/.../linux/flutter/ephemeral`. Its earlier checksum and
  structural passes remain valid, but it is not relocated-runtime evidence.
- The Linux CMake shell now links generated plugin targets with
  `BUILD_WITH_INSTALL_RPATH` and an install RPATH of `$ORIGIN`. A fresh local
  release build gives both plugins exactly `$ORIGIN`; after copying the entire
  bundle to an unrelated temporary directory and changing cwd to `/`, `ldd`
  resolves their Flutter engine from that copied `lib/` directory rather than
  the repository.
- `tool/verify_linux_runtime_bundle.dart` now requires ELF64 x86-64 runner and
  Host identities, the runner's exact `$ORIGIN/lib` search path, successful
  runner/Host dependency closure with `LD_LIBRARY_PATH` and `LD_PRELOAD`
  removed, exact resolution of bundled SONAMEs from `bundle/lib`, and no
  non-relative RUNPATH on every bundled library reachable from the runner. The
  real local release bundle passed with the Flutter engine and both plugins in
  its bundled closure and 83 resolved system-library names. This records the
  observed local-host closure; it does not claim that 83 packages must be
  installed separately or that another distribution supplies compatible ABIs.
  The same gate passes the debug bundle and now follows the ordinary CI Linux
  debug build, while the manual review workflow applies it to the independently
  extracted release archive.
- The archive verifier accepts `--native-runtime`. On the matching host it now
  runs the Host from the extracted tar, and Linux also runs the dependency gate
  against that extracted payload. A new local dirty-source archive passed
  assembly and native verification at SHA-256
  `68b706e82834800da336dadc652e1ec458af41329de87cb6bd6a492c553716bd`.
  Focused fixtures cover the successful extracted path, build-tree RUNPATH
  rejection, and unresolved-dependency rejection. The full 175-test Flutter
  suite, fatal-info Dart analysis, Linux release build, 84 Rust tests with
  formatting/Clippy, actionlint 1.7.12, and `flutter analyze` from an independent
  ASCII path all pass. Direct-path `flutter analyze` still reproduces the known
  Flutter 3.47.1 Unicode-path LSP truncated-JSON failure. Windows and macOS use
  the same extracted Host smoke but retain their separate installer, ACL,
  signing, notarization, Gatekeeper, and Human gates.
- The bundle also contains `libdartjni.so`, a transitive native asset with a
  system JVM RUNPATH. It is not in the Linux runner or Host dependency closure,
  and the product exposes scanning only on Android. The current gate therefore
  does not misreport it as a Linux startup dependency; removal or platform-
  selective packaging remains a separate size/hygiene investigation.
- Clean hosted review run `42100825202` at
  `c1803d422325060f0859c2cc7e78846f24d0c675` passed the complete Linux x64,
  Windows x64, and macOS arm64 release paths. Every platform assembled and
  self-verified its archive, then extracted it and successfully executed the
  packaged Host before upload; Linux additionally passed the ELF/RUNPATH/`ldd`
  gate on its extracted payload. Companion ordinary CI `42100804703` passed all
  three jobs, including the same gate on the Linux debug bundle plus Linux,
  Android, Windows, and macOS builds.
- All three new workflow artifacts were downloaded and independently verified
  again. Structural verification and sidecar SHA-256 comparison passed for
  Linux, Windows, and macOS, while Linux also passed `--native-runtime` after
  download. The archives are Linux 13,388,731 bytes /
  `18e215546c46bf2fa6ea7ae03e8337d7ec986aacb7192e33257ac31de28e6835`,
  Windows 14,675,440 bytes /
  `aff93b6e1f9e93aeded91c55f1c0ad42a51a08929fdfb229365435f17fc1b639`,
  and macOS 21,630,993 bytes /
  `8c62800837c8d50692453bdf6f53e13a764efcc357335a0744215f4c685245e2`.
  Their provenance binds the exact clean revision, Flutter 3.47.1, Rust 1.89.0,
  workflow origin `42100825202:1`, and the unchanged review-only/signing gaps.
  Direct inspection of the downloaded Linux payload shows `$ORIGIN` on both
  linked plugin RUNPATHs and no `/home/runner` or `linux/flutter/ephemeral`
  dynamic path in any bundled `.so`. This closes the identified relocation
  defect; it still does not establish a package-manager format, clean minimal-
  runtime GUI launch, another distribution's ABI compatibility, or signing.

### Clean-runtime follow-up

- GitHub's official workflow syntax permits container jobs only on Linux and
  requires an Ubuntu GitHub-hosted runner for hosted container execution. The
  workflow therefore adds a dependent Ubuntu 22.04 container job rather than
  assuming the release builder's installed development packages represent an
  end-user runtime.
- The image is pinned to manifest digest
  `sha256:076e7bf82319619f28dd0aa9c02ab34b055ad37100395b4f49a2ffba04fb5e11`.
  Its installed packages start with Flutter's documented `libgtk-3-0`,
  `libblkid1`, and `liblzma5`, add this product's `libsecret-1-0` plugin
  dependency, and add only the Xvfb/DBus/Mesa tools needed for headless launch.
  Ubuntu's official Jammy
  [`libgles2` package index](https://packages.ubuntu.com/jammy/libgles2)
  identifies 1.4.0-1 as the vendor-neutral GLESv2 runtime; unlike the
  `libgles2-mesa` transitional package, it directly provides the runtime library
  required by Flutter's headless GL startup. This is a bounded Ubuntu 22.04
  runtime claim, not a multi-distribution package or dependency-policy decision.
- The job downloads the Linux artifact produced by the matrix instead of
  reusing its build directory, verifies the sidecar checksum, extracts the tar,
  checks runner/Host dependency closure, executes the Host, and treats an
  eight-second live GUI under software-rendered Xvfb as success. Early exit or a
  surviving product process fails closed. In first hosted run `42105201413`, all
  three artifact jobs passed and the clean image passed download, checksum,
  extraction, `ldd`, and Host execution before the GUI aborted with status 134:
  `libGLESv2.so.2` could not be opened. AT-SPI/Atk warnings were also emitted,
  but the missing GLES loader error was the fatal condition. The declared
  runtime set now includes the official `libgles2` provider. Corrected hosted
  run `42107031642` at `3ab09971c762b3406ba36f52e9853c08e22c3f65`
  installed Jammy's `libgles2` 1.4.0-1, passed all three artifact builds, then
  passed clean-runtime job `127528095435`: the exact archive checksum, extracted
  runner/Host dependency checks, Host 0.1.0 help smoke, eight-second GUI window,
  and no-surviving-product-process check all completed before
  `LINUX_CLEAN_RUNTIME=PASS`. Companion ordinary CI `42107012629` passed its
  verify, Windows x64, and macOS arm64 jobs. The first failed run remains negative
  evidence; the correction establishes only the pinned Ubuntu 22.04 runtime, not
  general Linux ABI/package compatibility or installed-user acceptance.

## Windows current-user Host state ACLs

_Reviewed: 2026-11-06_

### Sources reviewed

- Microsoft's official documentation for
  [`SECURITY_ATTRIBUTES`](https://learn.microsoft.com/en-us/windows/win32/api/wtypesbase/ns-wtypesbase-security_attributes),
  [`SetSecurityInfo`](https://learn.microsoft.com/en-us/windows/win32/api/aclapi/nf-aclapi-setsecurityinfo),
  [SDDL security descriptors](https://learn.microsoft.com/en-us/windows/win32/secauthz/security-descriptor-string-format),
  [ACE strings](https://learn.microsoft.com/en-us/windows/win32/secauthz/ace-strings),
  and [SID strings](https://learn.microsoft.com/en-us/windows/win32/secauthz/sid-strings).
- OpenAI Codex at `c8a1109fa78b46df24b055250b67d5daf745e566`
  (Apache-2.0), especially its Windows auth-file replacement and native DACL
  regression test. It creates a replacement with the destination's protected
  DACL before writing credentials and rejects hard-linked replacement targets.
- mise at `e6cac975789e7dc335f76a8a5e170938c0d8bad0` (MIT), whose
  secret-bearing history store supplies a protected inheritable descriptor to
  `CreateDirectoryW` and also tightens an existing directory.
- turborepo at `f6ae32bd38e386f93d8bdbbddfd36bd39401d4f2` (MIT), whose
  Windows daemon endpoint resolves the current token user SID, verifies path
  ownership, and replaces inherited access with a protected current-user DACL.
- Vercel agent-desktop at `b43ac4f6e892ef608f8851428613c4009f0e84c7`
  (Apache-2.0), whose Windows private-state layer builds protected inheritable
  ACLs and separately validates that no untrusted principal receives an allow
  ACE.

### Adopted boundary

- Ambient `%LOCALAPPDATA%`/config inheritance is not a sufficient product
  contract because both Host state roots can be overridden. Resolve the current
  process token's SID, build one protected full-access ACE for that SID, use
  object/container inheritance only on directories, and apply the rule to both
  new and existing Host-owned state.
- Supply the descriptor at directory and atomic device-store temporary-file
  creation so no secret-bearing object is first published under a permissive
  parent. `SetNamedSecurityInfoW` then tightens existing objects and propagates
  the directory rule to existing inheriting children. Recursively replace DACLs
  under the Host-owned spool root to remove old explicit permissive ACEs, but do
  not touch unrelated siblings beside an overridden device-store file. Reject
  reparse objects, use checked object handles for the DACL mutation, reject
  hard-linked files, and fail closed if descriptor construction or application
  fails.
- Keep the Win32 unsafe boundary in one Windows-only module with RAII wrappers
  for token handles and `LocalFree` allocations. Do not invoke `icacls`: command
  discovery, localization, quoting, and subprocess behavior add failure modes
  without improving the security identity.
- Add native Windows tests under a deliberately Everyone-readable parent. They
  must prove that new and migrated directory/file DACLs are protected, include
  the exact current-user SID, retain inheritable directory flags, and remove the
  Everyone ACE. The normal Windows CI job now runs the Rust suite before the
  Flutter build; Linux-only tests cannot establish Win32 ACL behavior.

### Deliberate non-adoptions and remaining gates

- Do not copy another project's code or broad principal set. This desktop Host
  chooses the exact current process user rather than pre-authorizing SYSTEM,
  Administrators, a service group, or account names. A future multi-user service
  requires its own identity/ACL ADR.
- Do not claim protection from local administrators, who can take ownership by
  platform design. The boundary prevents accidental or inherited cross-user
  access to command output and stored credential hashes.
- Operator-supplied TLS keys are not Host-owned state. Their Windows ACL,
  installed service identity, installer ACLs, and post-install inspection remain
  separate gates; this change must not silently rewrite an external key's ACL.
- Local Linux compilation and tests do not validate the Windows-only FFI. A
  fresh hosted Windows Server 2022 Rust test plus bundle/Host smoke is required
  before this implementation is marked machine-verified; the final hosted runs
  recorded below satisfy that requirement for ADR-021.
- Hosted CI `42112667012`, Windows job `127543995980`, first failed during
  compilation before any ACL behavior ran: `auth.rs` belongs to the library
  crate, but the Windows ACL module had only been declared in the binary crate.
  The corrective library-module declaration required a fresh hosted run; the
  later passes below close that gap but must not relabel this first attempt as
  green.
- Follow-up CI `42113511534`, Windows job `127547477153`, compiled the Win32
  boundary and passed Remote auth plus hard-link rejection, then exposed a test
  oracle defect: Windows represented the runner's exact current-user SID as the
  canonical SDDL alias `LA`. The production DACL was protected, inheritable, and
  current-user-only; the revised oracle uses `EqualSid` on the binary ACE and
  inspects the control flags, ACE count/type/mask, and inheritance directly.
- Final CI `42114960020` at `88d0270`, Windows Server 2022 job `127552522560`,
  passed 85 native test instances, including the new/create, existing/migrate,
  and hard-link-reject ACL cases in both library and binary crate contexts. It
  then built the Flutter Windows debug bundle and passed the packaged Host
  `0.1.0` help and native-license hash smoke. The same run's Linux/Android verify
  and macOS bundle jobs passed. The successful Windows log retained one unrelated
  test-helper parameter warning caused by a Unix-only body; the evidence
  follow-up removes it. CI `42117298358` at `5ce6b6b`, Windows job
  `127560231894`, subsequently passed all 85 native test instances, the Flutter
  build, and Host/license smoke with no `warning:` line; its Linux/Android and
  macOS jobs also passed. This establishes the Host-owned state boundary on
  those hosted images, not operator TLS-key, installed-service, installer, or
  Human acceptance behavior.

## Operator-supplied TLS private-key validation

_Reviewed: 2026-11-06_

### Sources reviewed

- Microsoft's official documentation for handle-based
  [`GetSecurityInfo`](https://learn.microsoft.com/en-us/windows/win32/api/aclapi/nf-aclapi-getsecurityinfo),
  [security-descriptor operations](https://learn.microsoft.com/en-us/windows/win32/secauthz/security-descriptor-operations),
  [`CreateFileW`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew),
  [`IsValidAcl`](https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-isvalidacl),
  [well-known SIDs](https://learn.microsoft.com/en-us/windows/win32/secauthz/well-known-sids),
  and [`SE_DACL_PROTECTED`](https://learn.microsoft.com/en-us/windows-hardware/drivers/ifs/security-descriptor-control).
  `GetSecurityInfo` requires `READ_CONTROL`, keeps owner/DACL pointers inside one
  returned descriptor, and explicitly does not solve concurrent DACL changes;
  the protected bit prevents later parent inheritance from changing the DACL.
- PowerShell/OpenSSH portable at
  `0172cc6adb99d8b4324b8f0391b5b1fd6f39b2c6` (component BSD licenses),
  especially its
  [Windows secure-file permission check](https://github.com/PowerShell/openssh-portable/blob/0172cc6adb99d8b4324b8f0391b5b1fd6f39b2c6/contrib/win32/win32compat/w32-sshfileperm.c)
  and private-key loader. It requires the owner to be the current user, SYSTEM,
  Administrators, or TrustedInstaller, rejects an allow ACE for any other
  principal, and reads the key from an already-open descriptor after checking.
- Vercel agent-desktop at
  `b43ac4f6e892ef608f8851428613c4009f0e84c7` (Apache-2.0), especially its
  [handle-based DACL validator](https://github.com/vercel-labs/agent-desktop/blob/b43ac4f6e892ef608f8851428613c4009f0e84c7/crates/windows/src/system/private_file/dacl.rs)
  and owner-eligible SID analysis. It validates every granting principal,
  retains the security descriptor until ACE traversal finishes, bounds file
  reads, and distinguishes user identity from the owner Windows selects under
  elevation.
- `axum-server` 0.8.0's
  [`RustlsConfig::from_pem`](https://docs.rs/axum-server/0.8.0/axum_server/tls_rustls/struct.RustlsConfig.html#method.from_pem)
  and `reload_from_pem` accept already-read bytes. That avoids reopening a path
  after permission validation and preserves the existing atomic config swap.
  No third-party source code is copied.

### Adopted boundary

- Treat certificate and key paths as operator-owned, read-only inputs. Open the
  leaf once without following a Unix symlink or Windows reparse point, require a
  regular file, validate the key on that handle, then read bounded bytes from the
  same handle. Pass those bytes to rustls rather than asking `axum-server` to
  reopen both paths. This removes the validation-to-read path substitution and
  makes startup/reload allocation explicit: 1 MiB certificate chain, 256 KiB
  private key, with an extra-byte read guard in case the file grows after its
  metadata query.
- On Unix require the key owner to equal the effective Host user and reject all
  group/other mode bits. On Windows require the owner to be the exact current
  process user, LocalSystem, or built-in Administrators. Require a valid,
  non-null, protected DACL. Every standard allow ACE must name one of the same
  three principals; standard deny ACEs do not grant access, while all other ACE
  forms fail closed rather than relying on an unimplemented SID layout.
- Require the protected Windows DACL even when its present ACE set is safe. The
  Host will not mutate an external key, and an inheritable DACL could otherwise
  gain a new principal later through a parent change while the process keeps
  running. A trusted operator must prepare the file before startup.
- Keep reload all-or-nothing. Permission, size, I/O, or rustls parsing failure
  returns a coarse error without key bytes and leaves the last valid config
  serving existing and new connections.

### Deliberate non-adoptions and remaining gates

- Do not reuse ADR-021's current-user-only rewrite for an external key. SYSTEM
  and Administrators are accepted because elevated creation and installed
  service custody legitimately use those principals; local administrators can
  take ownership in any case. A concrete service account remains accepted as
  the current process user rather than by a pre-authorized broad service group.
- Do not reject a Windows hard link merely because it has another name. NTFS
  hard links identify the same file object and share its security descriptor;
  this path never modifies the key and reads from its checked handle. That is
  different from Host-owned atomic state, where alternate mutation paths are
  refused.
- The leaf-object gate does not claim installer/service provisioning, parent
  directory custody, local-administrator isolation, macOS extended-ACL
  inspection, or installed-machine acceptance. Linux tests cannot establish the
  Win32 behavior; the hosted Windows evidence below is therefore the applicable
  gate.
- Initial hosted CI `42120072496` at `e872e36`, Windows job `127569808871`,
  compiled the Win32 boundary and passed all 28 library and 58 binary tests,
  including both ACL refusal cases, invalid-material redaction, and WSS
  rotation. Its later process-level failure fixture kept an inheritable Windows
  temp-file ACL and therefore failed earlier at the new permission gate instead
  of producing the old rustls parser text; the test's single-message expectation
  failed and skipped the Windows build. That failure remains evidence. The
  correction accepts either pre-child TLS-material failure while retaining the
  private-marker and child-start prohibitions.
- Final hosted CI `42120995025` at `56c107c` passed all three jobs. Windows
  Server 2022 job `127573718517` ran 28 library, 58 binary, and 3
  process-integration tests without a `warning:` or `error:` log line, including
  the protected/untrusted DACL cases, invalid-material non-disclosure, WSS
  rotation, and corrected pre-child failure. It then built the Flutter Windows
  bundle and passed packaged Host help plus native-license hash checks. Linux/
  Android job `127573718014` passed the full repository gate and debug APK
  verification; macOS job `127573718461` built and verified its Host/license
  bundle. This closes the hosted compilation/behavior requirement only for the
  implemented leaf-object gate, not the remaining installed-service, installer,
  directory-custody, extended-ACL, or Human gates.

## macOS external TLS-key extended ACL gate

_Reviewed: 2026-11-06_

### Sources reviewed

- Apple's archived [`acl_get_fd_np(3)`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/acl_get_fd.3.html)
  documents descriptor-based retrieval of a requested ACL type and requires the
  returned allocation to be released with `acl_free`. Apple's ACL guidance says
  filesystem clients must check for and respect ACL presence rather than assume
  mode bits are the complete access policy.
- Apple's open-source Libc at
  `71bbe350ab79eef58113991d817ccc6165061a64` (APSL-2.0) implements
  `acl_get_fd_np` with `ACL_TYPE_EXTENDED` through `fstatx_np` and records
  `ENOENT` when the `FILESEC_ACL` property is absent. This establishes an exact
  same-handle absence result rather than requiring a path-based `ls`/`chmod`
  subprocess. No source code is copied.
- GNU gnulib at `f6cbe6673d0cbc8e13ca27773aeb53e891d33bac`
  (GPL-3.0-or-later) treats `ACL_TYPE_EXTENDED` as the real macOS ACL type,
  retrieves it from a supplied descriptor when available, classifies the
  returned object, and releases it. The Host adopts the descriptor lifetime and
  release pattern, not gnulib code or its cross-platform policy.
- uutils/coreutils at `4a8a9643904ffae87e42891a3632f6ab971a32b1`
  (MIT) declares the same public macOS ACL type, checks for an extended entry,
  releases the object, and tests with `chmod +a "everyone allow read"`. This
  independently confirms the constant and native fixture syntax; no source code
  is copied.
- rsync at `a6b31adfa495513abf7ae002b81fabe29bc50986`
  (GPL-3.0-or-later) likewise maps its macOS access-ACL abstraction to
  `ACL_TYPE_EXTENDED` and iterates named entries. The Host deliberately does not
  copy that parser because an external TLS key needs no extended ACL at all.

### Adopted boundary

- Retain ADR-022's no-follow open, same-handle ownership check, and no
  group/other mode bits. On macOS query that descriptor for
  `ACL_TYPE_EXTENDED` before reading a key byte. Accept only `ENOENT`; reject
  every returned ACL object and every other error. Always free a returned ACL.
- Rejecting the whole ACL object avoids a fragile second authorization engine
  for UUID-qualified principals, ordered allow/deny entries, inheritance, and
  future ACE forms. The Host remains read-only and gives the operator a coarse
  remediation condition without printing ACL identities or key content.
- The hosted macOS job now runs `cargo test --workspace` before the Flutter
  build. Its native fixture starts with mode `0600`, adds `everyone allow read`,
  and requires the same production read path to fail. Linux cannot execute or
  validate this Apple-libc boundary, so local format/Clippy/tests are necessary
  but not sufficient evidence.

### Deliberate non-adoptions and remaining gates

- Do not invoke `chmod -N`, reinterpret a deny-only ACL as harmless, or repair
  operator state. An explicit empty/deny ACL is also rejected so future edits
  cannot silently broaden a configuration the Host had accepted.
- Do not claim parent-directory custody, installed service-account readability,
  installer ACL behavior, administrator isolation, signing/notarization, or
  Human installed-machine acceptance from this leaf-object gate.
- Code-bearing CI `42124376817` at `b5dad38` passed all three jobs. macOS 15
  arm64 job `127585024401` compiled the FFI and passed 26 library, 57 binary,
  and 4 process-integration tests; the real macOS `0600` plus
  `everyone allow read` case specifically passed. It then built the Flutter app
  and passed packaged Host help plus native-license byte-identity checks.
  Linux/Android job `127585024849` passed the complete repository and debug APK
  gates, while
  Windows job `127585024928` passed native tests, build, and Host/license smoke.
  The macOS build retained Xcode's known Flutter-template warning about
  `Flutter Assemble`; the phase does declare generated input/output file lists
  and retains dependency analysis as documented below. This closes the
  implemented leaf-object ACL gate, not the remaining service, directory,
  installer, signing/notarization, or Human gates.

## macOS universal nested-Host packaging

_Reviewed: 2026-11-06_

### Sources reviewed

- Apple's official [Building a universal macOS binary](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
  guidance requires every executable component shipped in an application to
  contain the supported slices. For a custom build system it prescribes building
  once per architecture and combining the results with `lipo`. Apple's build-
  setting reference identifies `ARCHS` as the architectures Xcode builds.
- Rust's official [platform support](https://doc.rust-lang.org/rustc/platform-support/apple-darwin.html)
  lists `aarch64-apple-darwin` and `x86_64-apple-darwin` and documents Xcode SDK
  cross-compilation on macOS. The rustc book also documents that
  `MACOSX_DEPLOYMENT_TARGET` controls the minimum target version.
- The repository-pinned Flutter 3.47.1 source at revision `6655482ec0` was
  inspected directly. Its macOS build command uses the active host architecture
  for Debug, while a normal non-Debug build requests the standard universal
  product unless the separate arm64-only feature is enabled. Its support page
  still lists macOS x64 and arm64, while warning that Intel support is being
  deprecated; this is a current-toolchain contract, not a permanent promise.
- Tauri at `2e23492ab9bcec06bab041e0e47447aaa0da298c` (Apache-2.0)
  builds the two Apple Rust targets separately and uses `lipo -create`, requiring
  both targets to be installed. Isar at
  `713001bf1615ea15460d9bc8d3fb9c8cb4150a2e` (Apache-2.0) and OpenWallet
  Askar at `b9bf50222af8a2d78369afd2ddac7a49a2a93cd0` (Apache-2.0) independently
  use the same per-target-build plus `lipo` pattern. No source code was copied.

### Adopted boundary

- Follow Xcode `ARCHS` rather than guessing from `uname`. Build the Host with an
  explicit Rust target for every requested supported slice, merge only when more
  than one exists, and run the existing nested-code signing step after the merge.
  Debug therefore stays thin when Xcode requests one active architecture, while
  release/profile remain architecture-complete with the outer app.
- Provision both Rust targets in hosted macOS workflows rather than mutating the
  toolchain inside an Xcode build phase. Reject an empty/unknown request and let a
  missing target fail in Cargo.
- Name release review provenance `macos-universal`. On a real macOS verifier,
  require exactly `arm64` and `x86_64` in the runner, nested Host, App framework,
  and Flutter engine before Host execution. Structural verification remains
  cross-platform, but only matching-host verification can inspect Mach-O slices.

### Deliberate non-adoptions and remaining gates

- Do not replace Flutter's architecture decision with an always-universal local
  build, and do not make Debug iteration pay for two Rust compilations.
- Do not preserve an arm64-only artifact label merely because the current hosted
  runner is Apple Silicon. The artifact describes the payload, not the machine
  that assembled it.
- Universal Mach-O construction does not establish physical Intel execution,
  Developer ID signing, hardened runtime, notarization, stapling, Gatekeeper,
  installed workspace/toolchain access, or Human acceptance. The hosted build
  and review-artifact evidence below establishes only architecture-complete
  construction and matching-host verification.
- Initial hosted CI `42128455985` at `a877c9e` compiled both Rust targets,
  passed 26 library, 57 binary, and 4 integration tests on macOS, and built the
  61.4 MB release app. Verification did not reach an architecture assertion:
  Xcode 16.4's `lipo` requires the input file before the `-verify_arch` command,
  while the workflow supplied it last and therefore interpreted the path as an
  architecture token. The Dart verifier had the same `-archs` ordering error.
  Both calls now follow the tool's emitted `lipo <input_file> <command>` usage;
  the first failure remains preserved.
- Corrective CI `42129434391` at `0b34ae6` passed all three jobs. macOS 15 arm64
  job `127602082306` passed 26 library, 57 binary, and 4 integration tests,
  including the real extended-ACL fixture, then built a 61.4 MB release app.
  Its direct gate required exactly arm64 and x86_64 in the app runner, nested
  Host, App framework, and Flutter engine before checking license byte identity
  and executing Host `0.1.0`. Windows job `127602082839` and the full Linux/
  Android job `127602082633` also passed; the latter includes hosted
  `flutter analyze`, all Flutter tests, Linux runtime closure, and debug APK
  verification. Xcode's known warning remains present despite the Flutter-
  generated output file list and is unrelated to architecture correctness.
- Manual read-only workflow `42131127906` at the same revision passed Linux x64
  job `127607720970`, Windows x64 job `127607721434`, macOS universal job
  `127607721455`, and clean Ubuntu 22.04 runtime job `127610652373`. The macOS
  job built release, assembled and self-verified the `macos-universal` payload,
  independently extracted it with native runtime verification, and uploaded
  `codex-native-unofficial-macos-universal-review-only`. The archive SHA-256 is
  `7e98452d0e0be660497c4ee564902daf026d0f75ce10a50216d787fa7ef955d0`;
  GitHub reports 24,774,088 bytes for the uploaded artifact container. These are
  review-only outputs with `distributionReady=false`, not signed releases.

## macOS Flutter Assemble dependency-warning boundary

_Reviewed: 2026-11-06_

### Sources reviewed

- Apple's official WWDC22 build-parallelization guidance says a script phase
  that participates in dependency analysis must declare its complete inputs and
  outputs. Those declarations let Xcode skip unchanged work and prevent unsafe
  scheduling; disabling dependency analysis deliberately gives up that model.
- Flutter issue
  [#123735](https://github.com/flutter/flutter/issues/123735) remains open and
  triaged. Flutter maintainers identify the `Flutter Assemble` warning as an
  Xcode false positive: the aggregate target correctly keeps dependency analysis
  enabled and declares `FlutterInputs.xcfilelist` plus
  `FlutterOutputs.xcfilelist`. They note that Flutter could filter the diagnostic
  from CLI output, but it would still appear in Xcode.
- Earlier Flutter issue
  [#112015](https://github.com/flutter/flutter/issues/112015) explicitly warns
  against adding `alwaysOutOfDate = 1` to this assemble phase because the phase
  does perform proper input/output dependency analysis.
- The repository-pinned Flutter 3.47.1 template and Flutter's current upstream
  macOS template were inspected directly. Both match this repository: only the
  separate embed phase is always out of date; `Flutter Assemble` keeps its input
  and output file lists and the `tripwire` bootstrap input.

### Adopted boundary

- Preserve Flutter's dependency-aware aggregate phase exactly. Do not suppress
  the warning by setting `alwaysOutOfDate = 1`, inventing a synthetic output, or
  removing the generated file lists. A warning-free log would not justify
  weakening correct incremental-build semantics.
- Treat the observed Xcode 16.4 line as a known upstream diagnostic, not evidence
  that this repository omitted a build output. Continue to fail on real build,
  universal-slice, Host, license, and runtime errors, and preserve the warning in
  hosted evidence until Flutter/Xcode resolves it upstream.
- This review makes no code change and does not prove that future Flutter or
  Xcode versions retain the same behavior. Re-audit the pinned template and open
  issue when either toolchain is upgraded.

## Current official Codex Desktop UX and reopened real-use review

_Reviewed: 2026-11-07_

### Sources and live evidence reviewed

- Installed official ChatGPT/Codex Desktop application on this Linux host
  (`/opt/codex-desktop`, bundling stock `codex` `0.166.0-alpha.5.1`), inspected
  live via its Chromium DevTools endpoint (`http://127.0.0.1:9333`) and window
  captures across real local workspaces (`Codex-Native-Unoffical`,
  `fura-project`, `starlight-material-design-theme`, `libreoffice_modern`,
  `Seal-Desktop`, and `minecraft`).
- Official OpenAI Codex Desktop documentation
  ([Codex app](https://developers.openai.com/codex/app),
  [Codex app features](https://developers.openai.com/codex/app/features), and
  [Using the Codex app](https://help.openai.com/en/articles/20001053-using-the-codex-app))
  covering project-grouped sidebars, collapsible navigation, thread switching,
  diff review, and composer controls.
- Stock `codex app-server` v2 protocol schema (`UserInput` union: `text`,
  `image`, `localImage`, `skill`, `mention`) and real persisted `userMessage`
  history payloads returned by `thread/turns/list` and `thread/items/list`.
- Human real-use review of `codex_native_unofficial` at `7f220d5` on Linux,
  which demonstrated that passing widget tests and synthetic smokes had missed
  immediate daily-use defects when opening real multi-turn project threads.

### Real-use defects identified against the official desktop experience

1. **Initial conversation scroll position and history anchor model (P0)**:
   - The previous `ListView.builder` timeline only called
     `animateTo(maxScrollExtent)` when `distanceFromEnd <= 160`. Because a
     standard top-anchored `ListView` starts at `offset == 0.0` (the oldest
     loaded turn at the top of the page), `distanceFromEnd` on first open was
     tens of thousands of pixels (`~24,696 px` on `Build Codex desktop vertical
     slice`), leaving the user stranded at the top of historical turns on every
     thread open or switch.
   - Prepending older turns via `Load older turns` inserted items at index `0`
     of a top-anchored list, shifting the user's current reading position down.
2. **User message envelope and attachment presentation**:
   - Official Codex Desktop and IDE integrations wrap pasted files, mentioned
     files, and IDE context into structured markdown headers inside the
     `userMessage` text item (`# Files pasted by the user:`,
     `# Files mentioned by the user:`, `# Context from my IDE setup:`, followed
     by `## My request:` or `## My request for Codex:`).
   - Rendering the raw protocol text exposed temporary file paths (such as
     `/home/.../.codex/.tmp/pasted-files/.../已粘贴的文本.txt`) and internal
     scaffolding (`Pasted text contains the user's request.`) directly inside the
     user bubble, and also polluted unnamed thread titles in the sidebar when
     `thread.preview` began with `# Files pasted by the user:`.
   - User bubbles in `7f220d5` used a high-contrast dark fill (`#1F211F` in
     light mode) rather than the official Codex Desktop's soft neutral pill
     surface (`#F0F0EC` light / `#2A2B29` dark with primary text).
3. **Desktop shell, window identity, and sidebar noise**:
   - Native Linux, Windows, and macOS window chrome still displayed the package
     identifier `codex_native_unofficial` instead of `Codex Native`.
   - Inactive persisted threads returned by `thread/list` have status
     `ThreadRuntimeStatus.notLoaded` until resumed. Rendering an amber warning
     dot for `notLoaded` marked every historical thread in the sidebar as if it
     were in a warning state.
   - Sidebar thread timestamps formatted every date as `HH:mm`, making weeks-old
     threads indistinguishable from today's turns.
   - The desktop workspace lacked a collapsible sidebar toggle (`Ctrl+B` /
     `Cmd+B`), collapsible project groups, and inline thread filtering
     (`Ctrl+K` / `Cmd+K`).
   - Selecting a `notLoaded` thread in the sidebar kept `readThread` read-only,
     but submitting a new prompt in the composer did not automatically invoke
     `resumeThread` before `startTurn`.

### Adopted product architecture and boundaries

- **Bottom-anchored reverse-sliver conversation viewport**:
  - `_ConversationScrollView` uses a `CustomScrollView` with `anchor: 1.0`, a
    zero-height `center` sliver at the bottom of the timeline, and a single
    reverse-growing `SliverList.builder` placed before `center` (`reverseIndex
    0` = newest item at `scrollOffset == 0.0`, growing into negative scroll
    offsets for older items).
  - A custom `_RenderConversationViewport` overrides `performLayout()` so that
    when total content height is smaller than the viewport (`totalExtent <
    size.height`), children are shifted upward to top-align short threads while
    keeping `minScrollExtent == 0.0` and `maxScrollExtent == 0.0`.
  - Consequently, opening any long thread lands immediately at the latest turn on
    Frame 1 (`pixels == 0.0 == maxScrollExtent`) without measuring offscreen
    items or animating across the timeline. Prepending older turns appends to
    higher reverse indices (more negative `minScrollExtent`), preserving the
    visual position of the item currently on screen to within `< 1 px`.
  - Live streaming updates auto-follow only when within `160 px` of latest
    (`offset >= -160`); when scrolled up (`offset < -160`), streaming never
    yanks the viewport and a compact floating `Jump to latest` pill is shown.
  - Per-thread scroll offsets are remembered in a bounded in-memory map capped
    at `32` threads.
- **Structured user message envelope & attachment presentation**:
  - `parseUserMessagePresentation` parses pasted-file, mentioned-file, and
    IDE-context envelopes at presentation/domain projection time without
    modifying prompts sent to Codex. Extracted file references and non-text
    `userMessage.content` items (`localImage`, `image`, `skill`, `mention`)
    render as compact attachment chips above a clean neutral user bubble, with
    `Show full message` / `Show less` disclosure for long prompts and normalized
    fallback titles for unnamed threads.
- **Timeline, sidebar, header, empty state, and composer product refinements**:
  - `ThreadListController.refresh()` deduplicates `thread/list` entries by
    `thread.id` (preserving newest order) and fetches up to two continuation
    pages when duplicate rollout entries reduce the unique count below
    `pageSize`, ensuring active projects (such as `fura-project` and
    `libreoffice_modern`) appear on initial load just like official Codex
    Desktop.
  - `HistoryTurn` computes `workDuration` and `formattedWorkDuration`
    (`Worked for 15s`, `Worked for 3m 58s`, `Worked for 16m 20s`) from
    `startedAt` and `completedAt` in `thread/turns/list`. `_HistoryEntryView`
    renders a centered `_TurnWorkDivider` (`─── Worked for 3m 58s › ───`) above
    the first non-user item of each turn; clicking it expands or collapses that
    turn's full `thread/items/list` activity items (`loadTurnItems(turnId)` /
    `collapseTurnItems()`).
  - `parseUserMessagePresentation` also strips escaped markdown/HTML space
    continuation/trailing artifacts (`&#x20;\`) from persisted user messages
    while preserving literal `&#x20;` tokens in user prose.
  - Completed assistant messages render a subtle copy action
    (`assistant-copy-<id>`) below the markdown body, and fenced code blocks
    include a header bar with the language label and a `Copy` action. Reasoning
    items render as quiet left-bordered rows, and command rows expose inline
    output actions without raw protocol status strings.
  - Both the unselected workspace state and an empty newly started thread render
    the official Codex Desktop `Let’s build` landing view (`>_` terminal emblem,
    `Let’s build` heading, and active project name) with the composer enabled:
    submitting a prompt when no thread is selected automatically calls
    `startThread` for the active project directory and then `submit`.
  - The conversation header uses a single horizontal title row
    (`<Thread Title>  <Project Name>` on the left, `[Changes N] [Stop]` on the
    right), and the timeline uses `EdgeInsets.fromLTRB(16, 28, 16, 36)` padding
    so the top and bottom turns never crowd the header or composer borders.
  - Native desktop shells set the window title to `Codex Native`. The sidebar
    replaces the solid-filled button with a lightweight `[edit_square] New
    thread` action row, uses a single leading icon on project headings
    (`folder_outlined` by default, swapping to `keyboard_arrow_down_rounded` on
    hover or `keyboard_arrow_right_rounded` when collapsed), formats relative
    thread timestamps in compact units (`now`, `15m`, `2h`, `1d`, `2w`, `1mo`,
    `1y`), supports `Ctrl+B`/`Cmd+B` collapse and `Ctrl+K`/`Cmd+K` inline
    filtering, restricts status dots to active/error states, and pins the
    composer model/effort summary pill (`<Model> · <Effort> ⌄`) and Send button
    (`↑`) flush right.

## ChatGPT Desktop 26.1103.32239 full-stack reverse analysis and unified Native Chat + Work + Codex platform map

_Reviewed: 2026-11-07_

### Sources and live evidence reviewed

- Installed latest unified ChatGPT Desktop package (`~/.cache/codex-desktop-auto-update/ChatGPT_Desktop_1.2026.103.0_x64.deb`, app version `26.1103.32239`, `codexBuildNumber: 25471`, Chromium/Owl `157.0.8103.39`), bundling stock `codex` `0.167.0-alpha.3.2`, `codex-code-mode-host`, `cua_node`, `rg`, `tectonic` `0.17.0`, `artifact-template-picker`, `dictation-ducking`, `remote-control-device-key.node`, and `hid-topology-watcher.node`.
- Live DevTools inspection (`http://127.0.0.1:9333`) of the running official desktop application across real local workspaces (`Codex-Native-Unoffical`, `fura-project`, `libreoffice_modern`, `Seal-Desktop`, `starlight-material-design-theme`, `minecraft`).
- Local SQLite persistence across both Tier A (`~/.codex/` stock app-server runtime databases: `state_5.sqlite`, `thread_history_1.sqlite`, `queue_1.sqlite`, `goals_1.sqlite`, `memories_1.sqlite`, `memories_v2_1.sqlite`, `logs_2.sqlite`, `reviews.sqlite`) and Tier B (`~/.codex/sqlite/codex.db` Electron main-process unified catalog: `local_thread_catalog`, `local_thread_catalog_hosts`, `thread_timeline_ledger`, `automations`, `automation_runs`, `inbox_items`, and `~/.codex/project-chatgpt-provisioning/`).
- Clean-room static inspection via the committed project tool [`tools/reverse/inspect_chatgpt_desktop.py`](../tools/reverse/inspect_chatgpt_desktop.py) (temporary unpack directory `/tmp/chatgpt_desktop_inspect` deleted after analysis; zero proprietary JS/CSS/font/icon assets or personal tokens committed).

### Complete reverse-analysis deliverable suite (`docs/reverse/`)

1. [`docs/reverse/DESKTOP_ARCHITECTURE_MAP.md`](reverse/DESKTOP_ARCHITECTURE_MAP.md) — Process topology (`early-bootstrap-920`, `worker.js`, `git-worker`, `visualize-cache-worker`), preload bridges (`preload.js`, `sandbox-preload.js`, `browser-page-preload.js`, `mcp-annotation-runtime.js`), native sidecars, all 26 `codex_desktop:*` IPC channels, tokenized 256 KiB chunked IPC (`codex-host-chunked-message-v1`), and how Chat, Work, and Codex share one shell and sidebar.
2. [`docs/reverse/UI_REFERENCE.md`](reverse/UI_REFERENCE.md) — Provenance-tagged design tokens (`[derived from computed style]`, `[observed live]`, `[static bundle only]`) and component-to-logic mappings for the shell, sidebar, thread header, timeline, composer, approvals, diff, terminal/output, and Skybridge widgets.
3. [`docs/reverse/DATA_FLOW.md`](reverse/DATA_FLOW.md) — End-to-end runtime data flows for startup (`getInitialSidebarBootstrap` + `ThreadCatalogSyncManager`), Cloud Chat (`MrGp` DAG + `AuIy.Ph` + `uNU6.submitChatGPTCompletion`), Work (`STEPS_PROSE` + `tpp` local executor hybrid + `thread/startAeon` on Durable Cloud Host), and Codex (`turnHistory.kind === "canonical"` islands, tail hydration, opening `userMessage` anchoring, viewport-protected active eviction `setBoundary` -> `yV`/`yZ` 1000->500 cap, fine-grained reactive item/slot maps, and 10-thread LRU).
4. [`docs/reverse/LOCAL_STORAGE_MAP.md`](reverse/LOCAL_STORAGE_MAP.md) — Full schema and lifecycle map of Tier A (`state_5.sqlite`, `thread_history_1.sqlite` byte-offset `.jsonl` rollout index, etc.) and Tier B (`~/.codex/sqlite/codex.db` unified catalog), plus our 5-layer target Native storage architecture (`codex_native_catalog.sqlite`).
5. [`docs/reverse/NETWORK_SURFACES.md`](reverse/NETWORK_SURFACES.md) — Complete inventory of common headers, SSE/JSONL parsers (`WvOS`), retry/error models, `/backend-api/*` endpoints, 146 `/wham/*` endpoints, `wss://codex-cloud-backend.chatgpt.com/`, `wss://chatgpt.com/backend-api/wham/remote/control/server`, and `d5Fp` feature flags, strictly classified into `PUBLIC_SUPPORTED`, `PUBLIC_UNOFFICIAL_CLIENT_OK`, `PRIVATE_WEB_SESSION`, `PRIVATE_INTERNAL_SERVICE`, and `UNKNOWN`.
6. [`docs/reverse/CHATGPT_COMPATIBILITY.md`](reverse/CHATGPT_COMPATIBILITY.md) — Cloud Chat history sync (`ThreadCatalogSyncManager` `chatgpt:` host, 30-day window, 5-min backoff), DAG branching/editing/regeneration (`MrGp`), unified projects (`codex_unified_projects` `g-p-*` snorlax gizmos), public vs private compatibility assessment, and our tiered Phase 1 Native Chat strategy (`PUBLIC_SUPPORTED` stock `app-server` Everyday mode + `conversations.json` import).
7. [`docs/reverse/PLUGIN_HOST_MAP.md`](reverse/PLUGIN_HOST_MAP.md) — Taxonomy of Plugins, Skills, MCP Servers, Apps/Connectors, and Skybridge (`codex-sandbox://` + 19 `MessagePort` channels), full catalog of the 7 bundled plugins (`codex-app-tools`, `browser`, `chrome`, `unified-computer-use`, `latex`, `deep-research`, `visualize`), and our 3-tier Shared Capability Host architecture.
8. [`docs/reverse/CODEX_INTEGRATION_MAP.md`](reverse/CODEX_INTEGRATION_MAP.md) — Local `codex app-server` spawn & env config, version-gated capability matrix (`Ehlj` from `0.141.0` to `0.167.0-alpha.1`), all 88 JSON-RPC methods, the 5 official transports (`stdio`, `ssh`, `wsl`, `remote-control`, durable cloud WS), hardware-key Remote Control enrollment (`remote-control-device-key.node` + MFA `step_up_token`), and Direct Host comparison.
9. [`docs/reverse/ADOPTION_MATRIX.md`](reverse/ADOPTION_MATRIX.md) — Subsystem-by-subsystem adoption matrix (`ADOPT_AS_CONCEPT`, `ADOPT_PROTOCOL_COMPATIBLE`, `REIMPLEMENT_NATIVELY`, `OPTIONAL_EXPERIMENTAL`, `DO_NOT_ADOPT`), resolution of the 5 Round-2 UI code-review items, and direct answers to all 18 Architecture Recommendation questions.

## Reverse analysis correction, evidence revalidation & architecture reconciliation (`ADR-032`)

_Reviewed: 2026-11-07_

### Why recalibration was required

Human review and independent code review of `17f08f3` identified that while the raw forensic extraction from ChatGPT Desktop (`26.326.51703` / `codex-cli 0.167.0-alpha.3.2`) was solid, mapping those observations onto `Codex-Native-Unoffical` (`HEAD`) and `ADR-031` contained:

1. **Current-state repository drift** in `ADOPTION_MATRIX.md`: described our client as calling `thread/read(includeTurns: true)`, storing `_allTurns` with `maxRenderedTurns = 40`, using `ListView.builder` post-frame jumps, maintaining a `120`-entry Markdown AST LRU cache, and capping the Rust `codex-native-host` spool at `1 MiB/item, 32 MiB/session`. Line-by-line audit of `HEAD` (`17f08f3`) confirmed we already use `HistoryController` (`thread/turns/list` `turnPageSize = 20`, `maxRetainedTurns = 100`, `thread/items/list` `itemPageSize = 25`, `maxRetainedItems = 100`, `thread/items/read`), `_ConversationScrollView extends CustomScrollView(anchor: 1.0)` + `_RenderConversationViewport`, `parseUserMessagePresentation` in `lib/src/domain/history_models.dart`, and a `512 MiB/item, 2 GiB/session` SHA-256 deduplicated Rust spool (`native_host/src/config.rs`, `spool.rs`).
2. **Evidence-grade conflation**: static strings in `app.asar` were cited without separating `PRELOAD_EXPOSED` (`10` IPC channels in `preload.js` vs `9` internal) or cross-checking stock `codex app-server` schema (`105` stable + `74` experimental = `179` `ClientRequest` methods; `9` stable + `2` experimental = `11` `ServerRequest` methods; `82` `ServerNotification` methods).
3. **Over-inferred conclusions**:
   - `STEPS_PROSE` (`includeProseDetailLevelInstructions: true` in `early-bootstrap-920 @4400493`) injects `<app-context>### Non-technical UI` (`a2` in `early-bootstrap-339 @780000`) into Codex/Work agent threads and hides intermediate bash outputs in the UI; it does **not** make stock `codex app-server` the backend for normal ChatGPT Cloud Chat (`/backend-api/f/conversation` + `MrGp` DAG), and copying `a2` into our client would violate `AGENTS.md` Rule #1.
   - Work Mode is a **4-path multi-runtime orchestration**: (a) local `app-server` (`STEPS_PROSE` + `writing_blocks` + `artifact-template-picker` MCP), (b) Durable Cloud Host (`wss://codex-cloud-backend.chatgpt.com/` using cloud-only `thread/startAeon`), (c) `tpp-local-executor` registering via `POST /flora/cca/executor`, spawning `codex exec-server --concurrent-requests 32 --remote <url> --environment-id <id>` over a Noise rendezvous tunnel, and sending cloud-only `thread/environmentReady`, and (d) cloud `/backend-api/f/conversation` threads with `conversation_origin = 'tpp'` + `submitChatGPTLocalFunctionResult`.
   - Official Remote Control is stratified into **8 layers**: Layers 1–2 (Host-side `remoteControl/*` RPCs and `codex app-server --listen ws:// --ws-auth`) are in **stock `codex app-server` (`PUBLIC_SOURCE` `--experimental`)**, whereas Layers 3–7 (Controller `remote-control-device-key.node`, MFA `step_up_token`, `/backend-api/codex/remote/control/client/*`, `/wham/remote/control/server` relay) are `PRIVATE_INTERNAL_SERVICE`.
   - Official history pagination uses `limit: 5` turns in `yU`/`bC`/`readLatestPreviewPage` (not `15`, which was a `15e3` ms timeout), `limit: 2` items in `fI`, `limit: 28/30/100` in `loadTurnItems`, `limit: 500` items + `limit: 100` turns in `bX` (gated by `"codex-app-thread-timeline-history"`), and `1000 -> 500` item eviction in `yX`/`yY` (gated by Statsig experiment `"codex_app_active_history_eviction_v1"`, default `false`).

### Tooling & documentation updates

- Extended [`tools/reverse/inspect_chatgpt_desktop.py`](../tools/reverse/inspect_chatgpt_desktop.py) with `--evidence-report` to output per-symbol, per-IPC, per-RPC, and per-endpoint bundle provenance, static occurrence counts, `preload.js` exposure, stock `codex app-server` schema status (`stable` vs `experimental` vs `not_in_local_stock_schema`), Evidence Confidence tags (`PUBLIC_DOC`, `PUBLIC_SOURCE`, `LIVE_OBSERVED`, `LIVE_CALLED`, `STATIC_BUNDLE`, `LOCAL_SCHEMA`, `INFERRED`, `UNKNOWN`), and Support Classifications (`PUBLIC_SUPPORTED`, `EXPERIMENTAL_STOCK_SCHEMA`, `PRIVATE_WEB_SESSION`, `PRIVATE_INTERNAL_SERVICE`, `INTERNAL_ELECTRON_IPC`).
- Recalibrated all 9 documents in `docs/reverse/*.md` and recorded `ADR-032` in [`docs/DECISIONS.md`](DECISIONS.md).

## Desktop Shared Conversation Foundation Hardening (`16.B -> 16.A -> 16.C -> 16.E -> 16.D`) & Evidence Tightening

_Reviewed: 2026-11-08_

### Scope and motivation

Following `ADR-032` and the `HEAD` (`99e6141`) audit in [`docs/reverse/ADOPTION_MATRIX.md`](reverse/ADOPTION_MATRIX.md), this phase resolved the five concrete Desktop conversation foundation debt items (`16.B -> 16.A -> 16.C -> 16.E -> 16.D`) and subsequent Human/code-review edge-case corrections without expanding scope to Native Chat, Work, or Android Remote.

### Technical findings that shaped the implementation

1. **`16.B` — Why `>100-turn` bounded-history eviction required `findChildIndexCallback` and un-clamped height estimation on real `285,523 px` threads**:
   - In `HistoryController.loadOlderTurns()`, `_turns` is stored in descending order (`index 0` = newest turn). When appending page 6 (`turns 100..119`) exceeds `maxRetainedTurns = 100`, `_turns.removeRange(0, evictedTurnCount)` evicts the 20 newest turns (`39` items on our real `>140`-turn thread `<real-long-thread>`).
   - Because `_ConversationScrollView` (`CustomScrollView(anchor: 1.0)`) places `reverseIndex = 0` at `center`, evicting 39 newest items shifts the `reverseIndex` of every retained older item by `-39` (e.g., `reverseIndex 191 -> 152`).
   - **Discovery during live real-use walkthrough**: In a synthetic widget test with short `100 px` items, simple scroll-offset compensation appeared sufficient. However, on the real `>140`-turn Codex thread (`285,523.9 px` scroll extent across 100 turns, average item height `~1,487 px`), two subtler Flutter sliver mechanics surfaced:
     1. Without `findChildIndexCallback` on `SliverList.builder`, Flutter's `SliverMultiBoxAdaptorElement` matched children purely by integer `reverseIndex`, rebinding the mounted element at `reverseIndex 152` to a different item and detaching the anchor's `RenderBox` during rebuild.
     2. `_averageMeasuredItemHeight` had been clamped to `(24.0, 640.0)`, underestimating unmeasured multi-thousand-pixel assistant turns by `>2.3x` when estimating scroll offsets across `39` shifted indices.
     3. Pre-jumping `pixels` by an estimated `evictedExtent` *before* the widget rebuild caused `RenderSliverList` to lay out the wrong slice on the rebuild frame.
   - **Adopted solution**:
     - Added `findChildIndexCallback` to `_ConversationScrollView`'s `SliverList.builder` keyed on `ValueKey('measured-$itemKey')`, allowing `SliverMultiBoxAdaptorElement` to keep mounted `RenderBox`es attached across the `-39` index shift.
     - Widened `_averageMeasuredItemHeight` clamp to `(24.0, 4096.0)` and removed the premature pre-rebuild jump, letting `_schedulePostLoadAnchorAlignment` (triggered by `loadOlderVersion`) align the still-mounted anchor `RenderBox` directly on the post-load frame. Meanwhile, `HistoryController.evictionVersion` and `lastEvictedItemIds` track sliding-window eviction state and prune evicted `history-<id>` keys from `_measuredItemHeights`.
     - Result on real thread `<real-long-thread>`: **`0.000 px` visual drift** across Pages 2..5 and **`0.000 px` visual drift** (`topBefore: -59.0, topAfter: -59.0`) when crossing the `>100-turn` eviction boundary on Page 6 (`turnsCount: 100, evictionVersion: 1, lastEvictedCount: 39, canReturnToNewest: true`).
2. **Scrolled-up streaming visual anchor preservation**:
   - When the user is scrolled up (`distanceFromEnd > 160 px`) and a new live streaming item is inserted at `reverseIndex = 0`, all history items shift their `reverseIndex` by `+1`.
   - `_handleConversationChanged` captures `_pendingStreamAnchor` when `distanceFromEnd > _followThresholdPixels` and runs `_schedulePostLoadAnchorAlignment`, adjusting `pixels` by the inserted item's height while suppressing `_saveCurrentScrollOffset` until alignment finishes so the user's currently visible history row remains at `0.000 px` drift (`topBeforeStream: 34, topDuringStream: 34, yankDriftPx: 0` in live walkthrough Stage 6a).
3. **`16.A` — Content-identity-based cross-thread scroll restoration (`_ThreadScrollBookmark`) and deterministic deep-history fallback**:
   - Replaced raw `Map<String, double> _threadScrollOffsets` with bounded `LinkedHashMap<String, _ThreadScrollBookmark> _threadScrollBookmarks` (`max 32`), storing non-null `(scrollPixels, anchorItemKey, anchorTurnId, anchorViewportTopDy)` while keeping inactive thread history unretained (`AGENTS.md` Rule #2) and pruning deleted thread IDs via `_handleThreadListChanged()`.
   - When returning to a bookmarked thread whose `anchorTurnId` lies in an older page, `_scheduleThreadScrollRestore` automatically pages `loadOlderTurns()` up to `_maxRestorePages = 10` older-page requests (`220` turns including the initial page) and aligns `anchorItemKey` to `anchorViewportTopDy` (`0.000 px` drift in live walkthrough Stage 5 and `< 1.0 px` across viewport width resizes from `1400 px -> 820 px` in `bounded_timeline_test.dart`).
   - **Deep-history safety rule (Scheme A)**: If `anchorTurnId` / `anchorItemKey` is still absent after `_restorePagesLoaded >= _maxRestorePages` (`10`) or when `!canLoadOlderTurns`, `_scheduleThreadScrollRestore` **never** falls back to clamping old `bookmark.scrollPixels` onto a different turn window. Instead, it discards the stale bookmark (`_threadScrollBookmarks.remove(threadId)`), invokes `historyController.refresh()` if `canReturnToNewest` is true, and lands deterministically on the newest boundary (`pixels == 0.0`).
4. **`16.C` & `16.E` — Leaf `user_message_presentation.dart`, protocol-boundary normalization, and strict legacy envelope grammar**:
   - Extracted `UserAttachmentKind`, `UserAttachment`, `UserMessagePresentation`, `normalizeUserAttachment`, `normalizeUserAttachments`, and `parseUserMessagePresentation` into `lib/src/domain/user_message_presentation.dart` (zero `domain/` imports), breaking the `history_models.dart <-> thread_models.dart` cycle.
   - Enforced `normalizeUserAttachments` directly inside `HistoryProtocolAdapter._userAttachments()` (`lib/src/protocol/history_protocol.dart`) as well as `parseUserMessagePresentation`, so `HistoryItem.attachments` is bounded and deduplicated at protocol ingestion time (`maxUserAttachments = 16`, `maxAttachmentLabelLength = 160`, `maxAttachmentPathLength = 1024`, `maxAttachmentPreviewLength = 2048`, `seenAttachmentKeys`, `structuredPaths`).
   - Tightened `_parseLegacyEnvelope` (`maxEnvelopeHeaderScanCharacters = 16 * 1024`) so legacy envelope stripping only occurs when **both** (a) at least one valid attachment or IDE-context line is parsed from a structurally pure header (rejecting any free-form prose paragraph before the delimiter) **and** (b) a top-level `## My request:` / `## My request for Codex:` delimiter is matched outside quoted `## "<preview>": <path>` blocks (`_consumeQuotedPastedEntry` + `_isFollowedByEnvelopeBoundary`).
5. **`16.D` — `_RenderConversationViewport` audit and regression suite**:
   - Direct inspection of Flutter's `RenderViewportBase` (`packages/flutter/lib/src/rendering/viewport.dart:1703-1993`) confirmed that `paintOffset` on `SliverPhysicalParentData` is the single coordinate transform consumed by `paint`, `hitTestChildren`, `applyPaintTransform`, `describeSemanticsConfiguration`, and `showOnScreen`.
   - Added widget regression coverage in `test/app/bounded_timeline_test.dart` verifying pointer hit-testing, global transformed `SemanticsNode` rect geometry (`MatrixUtils.transformRect(node.transform, node.rect)`), `SelectableText` gesture selection in a shifted short viewport, `Scrollable.ensureVisible` focus alignment, and dynamic short-to-overflow viewport resizing without rewriting the working `RenderViewport` subclass.

## Peer Schema/Runtime and Desktop Fidelity Revalidation

_Reviewed: 2026-11-09_

### Official peer workflow and evidence boundary

- Codex and Antigravity/Gemini completed two real interactive round trips in the
  official `agy` 1.4.0 TUI: the initial no-write handshake and the post-sync
  slice-ownership negotiation. No unofficial Gemini API, wrapper, proxy, or
  browser automation was used.
- The peers worked from isolated branches/worktrees with one writer per
  overlapping surface. Codex owned the stock app-server/protocol/process audit;
  Gemini owned the Desktop static-fidelity/interaction audit. Gemini released
  all shared governance/document surfaces before integration.
- Gemini's UI conclusions were treated as peer input, then checked against its
  actual commit and tests. They are calibrated static/machine evidence, not
  Human visual acceptance.

### Current stock schema and installed Desktop snapshot

- Regenerated both stable and `--experimental` schemas from the installed
  `/opt/codex-desktop/resources/codex` (`codex-cli 0.167.0-alpha.3.2`). The
  current counts are `106` stable + `74` experimental-only = `180`
  `ClientRequest` methods, `10` stable + `1` experimental-only = `11`
  `ServerRequest` methods, `86` `ServerNotification` methods, and one
  `ClientNotification` (`initialized`).
- `thread/turns/list` and `thread/items/list` are now stable. The per-item
  `thread/items/read` fallback, `thread/timeline/list`, `remoteControl/*`,
  `collaborationMode/list`, and queue/realtime/search families remain
  experimental-only. In the `ServerRequest` direction, `currentTime/read` is
  the sole experimental-only method.
- Re-running `tools/reverse/inspect_chatgpt_desktop.py --evidence-report`
  against installed Desktop `26.1103.32239` / build `25471` found `19`
  preload-exposed of `25` total static `codex_desktop:*` IPC channels, `234`
  matched RPC-like strings, and `175` endpoints. Of the matched stock client
  requests, `88` are stable and `41` are experimental-only; the conservative
  extractor also reports `28` unmatched RPC-like strings, which mix genuine
  cloud extensions with static-match noise and must be inspected individually.

### Runtime findings and implemented corrections

- A `thread/items/list` call against a nonexistent/unmaterialized thread can
  return `-32601` (`not supported yet`), but the same installed binary returned
  valid results for five of five calls against real materialized local threads.
  The failure is therefore a thread/store availability boundary, not proof that
  the method is globally absent. `thread/turns/list` also works on materialized
  threads.
- Current public upstream source for
  [`ThreadItemsListParams`](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/v2/thread.rs)
  places `outputDeferred` on the outer `ThreadItemEntry`, while the nested
  command item contains `aggregatedOutput`. `HistoryProtocolAdapter` had checked
  only the nested item and would silently discard real deferral state. The
  adapter now propagates the outer field, keeps nested compatibility, and has a
  regression fixture using the upstream shape.
- The installed binary accepts the forward-compatible `deferOutput` request
  field even though its locally generated experimental schema omits that field.
  Sampled command results were not actually deferred, so this remains a useful
  preference rather than a memory guarantee; `thread/items/read` still returns
  a whole selected item.
- `ProcessTransport` previously allowed protocol adapters to call the peer
  directly after `close()` had started but before the peer fully closed. A late
  request or approval response could therefore write to already-closed child
  stdin. All request/notify/respond paths now pass through closing-state guards;
  the regression fake rejects post-close writes and asserts zero writes after
  input closure.

### Desktop fidelity slice

- Calibrated static inspection of the installed official bundle drove a bounded
  Flutter presentation slice: semantic focus/keyboard/disabled state handling
  for custom buttons, segments, menu/sidebar rows and work dividers; consistent
  `CodexTooltip`; Codex-themed confirmation/output dialogs; composer focus-state
  wiring; diff add/remove text tokens; and a tighter fenced-code surface/copy
  interaction.
- The slice preserves virtualized/bounded timeline behavior and does not change
  controller, domain, transport, protocol, or lifecycle ownership. Focused
  widget tests cover the new states. Subjective typography, motion, density,
  color, and real long-session interaction remain `HUMAN_REVIEW_PENDING` until
  a person inspects the integrated desktop build.

## Peer Round 2: `RESEARCH_MORE` Closure & Remote/Schema Documentation Reconciliation

_Reviewed: 2026-11-09_

### 1. Reclassification of the 3 `RESEARCH_MORE` Items Against `0.167.0-alpha.3.2` & `26.1103.32239`

1. **Official Controller-Side Mobile Discovery (`/wham/remote/control/*` Layer 8 -> `PRIVATE_ONLY` / `RESEARCH_EXHAUSTED`)**:
   - Audited the 175 endpoints extracted from `ChatGPT_Desktop_1.2026.103.0_x64.deb` (`26.1103.32239`, `webview/assets/async/182735.d3d917f28d.js`, `.vite/build/early-bootstrap-920-a204a41244c4b913.js`) alongside the regenerated `0.167.0-alpha.3.2` schemas.
   - Controller-side discovery, MFA verification, pairing claim, and client enumeration use `/wham/remote/control/mfa_requirement`, `/wham/remote/control/client/pair`, `/wham/remote/control/clients`, and `/wham/remote/control/clients/{client_id}` (in addition to `/backend-api/codex/remote/control/client/enroll/start` & `/complete`, `/backend-api/codex/remote/control/client/refresh`, `wss://chatgpt.com/backend-api/wham/remote/control/server`, and `remote-control-device-key.node`).
   - All controller-side endpoints are `PRIVATE_INTERNAL_SERVICE` with zero stock `codex app-server` controller-discovery RPCs. Host-side `remoteControl/*` (Track B) and self-hosted `codex-native-host` WSS (Track A) remain the complete supported dual-track boundary.
2. **Realtime Voice Dictation (`thread/realtime/*` -> `RESEARCH_EXHAUSTED` / `EXPERIMENTAL_STOCK_SCHEMA` + `PRIVATE_ONLY` call broker)**:
   - Audited all `v2/ThreadRealtime*.json` schemas in `0.167.0-alpha.3.2`: `6` experimental-only `ClientRequest` methods (`thread/realtime/start`, `appendAudio`, `appendSpeech`, `appendText`, `listVoices`, `stop`) and `11` stable `ServerNotification` methods (`started`, `sdp`, `itemAdded`, `item/started`, `item/completed`, `item/transcript/delta`, `transcript/delta`, `transcript/done`, `outputAudio/delta`, `error`, `closed`).
   - `ThreadRealtimeStartParams` requires `threadId` and `outputModality` (`"text" | "audio"`), supports `version: "v1" | "v2" | "v3"` (Frameless Bidi with `initialItems` capped at `128` items / `8,192` tokens), `35` `RealtimeVoice` values, and three `ThreadRealtimeStartTransport` variants (`websocket`, `webrtc` with SDP offer, and `existingCall` with `callId`).
   - In the official Desktop bundle (`webview/assets/async/366057.b32c7c19c0.js`, `972499.b9f8eb2bc4.js`), `existingCall`/WebRTC voice sessions are brokered through `/wham/realtime/calls?intent=quicksilver&architecture=avas` (`PRIVATE_INTERNAL_SERVICE`) and `/backend-api/pages/realtime-broker/u0s/ws` (`PRIVATE_WEB_SESSION`) plus the unpacked `dictation-ducking` native binary. Stock `thread/realtime/*` remains experimental and is deferred until cross-platform PCM audio capture and V3 Frameless Bidi schemas stabilize.
3. **Optional Skybridge (`ui://` Sandboxed WebView Host -> Layer A promoted to `READY` / Layer B `RESEARCH_EXHAUSTED` `DEFERRED_OPTIONAL_WEBVIEW`)**:
   - Verified in the regenerated `0.167.0-alpha.3.2` stable `ClientRequest.json` and `ServerRequest.json` that `mcpServer/resource/read` (`McpResourceReadParams`: `server`, `uri`, optional `threadId`, `connectorId`, `originCallId`, `target: {connectorId, linkId}` -> `McpResourceReadResponse`: `contents: Array<{uri, mimeType?, text} | {uri, mimeType?, blob}>`), `mcpServer/tool/call` (`McpServerToolCallParams`), `config/mcpServer/reload`, and `mcpServer/elicitation/request` (`McpServerElicitationRequestParams`) are **stable** (`PUBLIC_SUPPORTED`), while only `mcpServer/event/stream/start` and `mcpServer/event/stream/stop` remain experimental-only. Also verified that `skills/list`, `skills/config/write`, `skills/extraRoots/set` and singular `app/list` (`AppsListParams`), `app/installed` (`AppsInstalledParams`), `app/read` (`AppsReadParams`) are all stable in `0.167.0-alpha.3.2`.
   - Because Native `HEAD` currently implements only `mcpServerStatus/list`, `plugin/list`, `skills/list`, and `skills/config/write`, the independent stable protocol surfaces (`mcpServer/resource/read`, `mcpServer/tool/call`, `config/mcpServer/reload`, `mcpServer/elicitation/request`, `app/list`, `app/installed`, `app/read`, and `plugin/read`, `plugin/install`, `plugin/uninstall`) are recorded as `PARTIAL` / `MISSING` and promoted into the living `READY` backlog (`Slices F8–F9` in [`docs/reverse/OFFICIAL_FEATURE_MATRIX.md`](reverse/OFFICIAL_FEATURE_MATRIX.md)). The renderer-side `ui://` iframe widget protocol (`ui/initialize`, `openai/*` over `window.postMessage`) remains an optional WebView host deferred under `AGENTS.md` Rule #5.

### 2. Documentation-to-Code Reconciliation & `BoundedRemoteProjection` Audit Finding

- Reconciled [`docs/ARCHITECTURE.md`](ARCHITECTURE.md), [`docs/reverse/CHAT_COMPATIBILITY_MATRIX.md`](reverse/CHAT_COMPATIBILITY_MATRIX.md), [`docs/reverse/DATA_FLOW.md`](reverse/DATA_FLOW.md), [`docs/reverse/ADOPTION_MATRIX.md`](reverse/ADOPTION_MATRIX.md), [`docs/reverse/PLUGIN_HOST_MAP.md`](reverse/PLUGIN_HOST_MAP.md), [`docs/reverse/CODEX_INTEGRATION_MAP.md`](reverse/CODEX_INTEGRATION_MAP.md), and [`docs/reverse/OFFICIAL_FEATURE_MATRIX.md`](reverse/OFFICIAL_FEATURE_MATRIX.md) with actual `HEAD` (`4a530d2`), preserving the upstream whole-item `thread/items/read` boundary (`deferOutput` accepted as preference, sampled items not deferred by current binary, Host spool sanitizing before Dart decode).
- **Concrete Code Audit Finding Queued in `READY` (`Slice F7`)**: While Slice F6 added `thread/name/updated`, `thread/archived`, `thread/unarchived`, and `thread/reverted` to `native_host/src/transform.rs` (`is_remote_notification`) and `lib/src/transport/remote/remote_transport.dart` (`_eventMethods`), [`BoundedRemoteProjection.apply()`](../lib/src/transport/remote/remote_projection.dart) (`lines 86–97`) only handles `turn/started`, `turn/completed`, `thread/status/changed`, `item/started`, `item/completed`, and `error`, throwing `ProtocolViolation('Remote projection cannot apply ${notification.method}.')` if any of the 4 thread lifecycle notifications arrives while `RemoteLifecycleCoordinator` is active.

## Peer Round 3: F7 Remote Lifecycle and F9 Apps/Plugins Closure

_Reviewed: 2026-11-09_

### Remote lifecycle evidence

- `thread/name/updated` includes sufficient bounded metadata for an in-place
  rename, and `thread/archived` can remove a known row. In contrast,
  `thread/unarchived` and `thread/reverted` identify a thread but do not carry a
  complete `ThreadSummary`; authoritative `model/list` + `thread/list`
  rehydration is required to avoid invented metadata.
- Transport-buffered events are synchronously released by `completeResync`, but
  coordinator application is serialized asynchronously. Readiness must wait for
  that event tail and repeat hydration if a released event requests a new
  generation.
- A same-connection resync can advance while an earlier projection mutation is
  awaiting. Capturing the resync generation and checking it before and after
  cursor persistence prevents the older event from regressing the applied
  cursor. `RemoteAppliedCursorStore` serializes saves in invocation order; a
  later authoritative hydration remains the durable winner even if an older
  save had already started before resync.
- `RemoteTransport.resumeCursor` represents received/buffered transport
  progress. The coordinator does not use it for reconnect; it uses its own
  exact persisted projection-applied cursor. No current correctness consumer
  needs a new cross-layer applied-event acknowledgement API.

### Stable Apps/Plugins evidence and availability boundary

- The installed stock `0.167.0-alpha.3.2` schema confirms stable
  `app/list`, `app/installed`, `app/read`, `plugin/read`, `plugin/install`, and
  `plugin/uninstall`. Live integration against the installed binary verified
  plugin list/read, installed Apps, and `app/read` on available local state.
- `app/list` is catalog/network dependent and can time out in an offline
  environment. This is an operational availability boundary, not evidence that
  the stable RPC is absent. Native therefore loads catalog state independently
  and preserves installed Apps plus the other ecosystem sections on catalog
  failure.
- Protocol parsing caps and deduplicates catalog items at `100`. Presentation
  uses lazy `SliverList.builder` rows; an automated scroll regression proves an
  offscreen row is not initially constructed, becomes visible after scrolling,
  and the first row is no longer built at the bottom. Refresh regressions also
  prove disappeared plugin/app IDs do not resurrect stale detail, expansion,
  missing-ID, or in-flight state.
- These are `MACHINE VERIFIED` and protocol `LIVE_CALLED` findings. The Apps and
  Plugins visual/interaction quality has not received Human acceptance.

## Peer Round 4: Stable MCP Capabilities and Live Turn Telemetry

_Reviewed: 2026-11-09_

### Peer ownership and current schema evidence

- Codex and Antigravity/Gemini negotiated the round as equal peers in the
  official interactive `agy` TUI. Codex owned F8 MCP protocol/gateway/request
  handling and Gemini owned F10 live turn telemetry. They used isolated
  worktrees and did not concurrently write overlapping file surfaces.
- A fresh schema generated from installed stock `codex app-server
  0.167.0-alpha.3.2` reconfirmed stable
  `config/mcpServer/reload`, `mcpServer/resource/read`,
  `mcpServer/tool/call`, and server request
  `mcpServer/elicitation/request`. It also reconfirmed stable
  `turn/plan/updated`, `thread/tokenUsage/updated`,
  `item/reasoning/summaryTextDelta`, `item/mcpToolCall/progress`,
  `hook/started`, `hook/completed`, `model/rerouted`, and `warning`
  notifications. The earlier global method counts remain the current installed
  snapshot rather than a timeless upstream claim.

### F8 MCP runtime and bounded-memory findings

- Native now reloads MCP configuration, reads resources, invokes tools, and
  handles elicitation through typed gateway/domain boundaries. The UI retains
  at most 32 resource/tool content entries; MCP JSON is limited to 8 levels,
  1,024 nodes, and a 256 KiB aggregate encoded response. Retained text is capped
  at 64 KiB and structured previews at 32 KiB. Binary data is omitted from UI
  state and represented only by metadata/encoded length.
- Peer audit found that the initial raw-response validator applied the 64 KiB
  retained-text limit to every JSON string before content parsing. This made a
  64 KiB+1 through bounded binary blob fail before the intended binary/aggregate
  check. The response validator now permits a string leaf up to the aggregate
  cap, while content-specific text/preview/identifier checks still apply.
- Peer audit also found stale per-server MCP result/error caches after force
  refresh/reload and the ability for `num.tryParse` to accept `NaN`/`Infinity`
  while range comparisons remained false. Refresh/reload now clears/prunes the
  caches, and non-finite numeric elicitation values cannot submit.
- Live stock calls reached all three client methods. Reload succeeded;
  resource/tool calls produced expected operational errors for an unknown
  server or nonexistent thread, proving method dispatch without claiming a
  configured successful payload. Standard form and URL elicitations are
  supported; hosted `openai/form` is explicitly decline/cancel-only.

### F10 telemetry projection and audit findings

- `TurnProtocolAdapter` projects plan snapshots, token usage, reasoning-summary
  deltas, MCP progress, hook lifecycle, model reroutes, and warnings into typed
  bounded events. `ConversationController` coalesces reasoning deltas and
  exposes bounded current plan/token/reroute/warning state plus activity rows.
- Peer audit found three raw retention risks: a pre-flush reasoning buffer could
  append an arbitrary delta chunk, MCP base summaries could retain unbounded
  activity strings, and model reroute fields could remain unbounded. Parser and
  controller ingress now truncate those fields, cap plan steps/strings and
  warnings, and preserve bounded map counts (`maxPendingDeltaItems` for pending
  buffers; `maxEntries` for retained metadata).
- A separate regression proves `turn/completed` finalizes matching or unassigned
  entries without finalizing another turn's in-progress activity. The earlier
  peer handoff's claimed `_maxTrackedItemMetadata = 64` constant did not exist;
  the corrected evidence is the actual 16 pending-item and 200 retained-entry
  defaults.

### Integrated validation and evidence boundary

- Integrated main passed formatting, direct `dart analyze`, all `358` Flutter
  tests, all `98` Rust tests, the bounded history benchmark, and a Linux debug
  build. The benchmark retained `100` of `1,000` source turns with
  `RSS_TURN_DELTA=1781760`; ten discarded 3 MiB outputs measured
  `RSS_HEAVY_OUTPUT_DELTA=29425664`.
- The integrated KDE Wayland bundle kept Flutter, the packaged Host, and stock
  app-server alive together and shut them all down cleanly. That is real runtime
  startup/lifecycle evidence, not a Human visual review.
- F10's complete notification set is machine verified from schema, protocol,
  controller, widget, and E2E fixtures. A natural stock session did not emit
  every method during this round; no claim of full live notification observation
  is made. MCP and telemetry presentation remains `HUMAN_REVIEW_PENDING`.

## Peer Round 5: Bounded Local Runtime Diagnostics and Thread Metadata/Notices

_Reviewed: 2026-11-09_

The next official `agy` peer round re-anchored on installed stock
`codex app-server 0.167.0-alpha.3.2` and selected two independent writable
surfaces: Gemini owned stable local diagnostics (`F11`), while Codex owned
thread metadata and notice projection (`F12`). The branches shared no files and
were integrated through ordinary merge commits after targeted peer audit.

### F11 evidence and implementation boundary

- The stable schema and a de-identified live stock probe support seven useful
  read-only local RPCs: `account/read`, `account/rateLimits/read`,
  `permissionProfile/list`, `config/read`, `configRequirements/read`,
  `modelProvider/capabilities/read`, and `hooks/list`.
- `account/updated` and `account/rateLimits/updated` provide live refresh signals.
  The implementation subscribes only while Runtime details is mounted and
  fails closed for Remote/unsupported transports.
- Raw config values/origins and raw command-hook strings are deliberately not
  retained. A command hook is reduced to `Command handler`; identifiers,
  collections, previews, and errors are bounded. UI errors are bounded per
  section and in aggregate, stream errors are handled, successful targeted
  refresh clears only the matching stale error, and labels say `shown` where
  truncation makes totals unknowable.
- The peer audit found five concrete issues in the first implementation:
  command-hook secret retention, unbounded error text/aggregation, an unhandled
  stream-error path, stale targeted errors, and count labels that implied full
  totals. Gemini fixed all five in `bcb8078`; Codex independently reproduced a
  clean analysis and focused `13/13` pass.

### F12 evidence and implementation boundary

- Stock thread payloads expose bounded Git metadata, while stable notifications
  expose `thread/goal/updated`, `thread/goal/cleared`, and process/thread warning
  surfaces for guardian/config/deprecation notices.
- The implementation projects those values through typed domain/protocol and
  bounded controller state. Credential-bearing origins fail closed, and the
  final hardening rejects overlong raw origins before parsing so percent
  encoding cannot expand a truncated value beyond the intended bound.
- Warnings without a usable thread binding are process-global. They survive
  later thread materialization, switching, and `clearEntries`; only explicit
  dismissal removes them. This closes the pre-bind warning-loss issue found by
  Gemini's audit.
- This is not full goal parity: `thread/goal/get`, `thread/goal/set`, and
  `thread/goal/clear` are not implemented, and `gitInfo` is not yet rendered in
  the sidebar. Natural goal/warning notification emission was not observed in
  this round, so tests—not a claimed live event—are the evidence for those paths.

### Rebuilt queue after F11/F12

The installed schema still exposes at least two high-value stable candidates
that are independent if ownership is chosen carefully:

1. thread sections: `threadSection/list|create|update|delete`,
   `thread/section/move`, and `thread/section/changed`, with list-summary section
   metadata suitable for official-style sidebar organization;
2. native code review start: stable `review/start`, supporting uncommitted
   changes, base branch, commit, and custom targets and returning a review
   thread/turn.

The remaining stable goal lifecycle is also actionable, but it overlaps the
thread-model/protocol/controller surface required by thread sections. It must
not be assigned concurrently to another writer. Experimental account-session,
collaboration, realtime, and private cloud paths remain research-only. This
queue is provisional until the post-integration official `agy` peer negotiation
assigns exact ownership.

### Integrated validation and real-use boundary

- Shared `main` passed `git diff --check`, formatting (`168` files, `0`
  changed), direct `dart analyze`, all `377` Flutter tests, all `98` Rust tests,
  the bounded history benchmark, and a Linux debug build.
- The benchmark retained `100` of `1,000` source turns and discarded ten 3 MiB
  heavy outputs with `RSS_TURN_DELTA=1716224` and
  `RSS_HEAVY_OUTPUT_DELTA=32108544`.
- The Linux bundle kept Flutter, the packaged Host, and stock app-server alive
  together and removed all three on Ctrl-C. The runtime also emitted an ATK
  embedding critical and a cursor-theme warning; those environment-level
  warnings did not crash the app but remain negative evidence. This lifecycle
  check is not Human visual acceptance of Runtime details or notice density.

## Peer Round 6: Bounded Thread Sections and Native Code Review

### Peer ownership and supported boundary

- Through the official interactive `agy` TUI, Gemini owned F13 thread sections,
  sidebar Git/goal badges, and their presentation/tests; Codex owned F14 typed
  review targets, review lifecycle projection, controller state, and tests.
  Isolated branches/worktrees maintained one writer per overlapping surface.
- F13 uses stable stock `threadSection/list|create|update|delete`,
  `thread/section/move`, and `thread/section/changed`. It retains at most 64
  section definitions, rejects any page larger than 64 even when `nextCursor`
  is null, bounds names/appearance tokens, and keeps Remote read-only.
- F14 uses stable stock `review/start`. Protocol coverage serializes
  uncommitted-change, base-branch, commit, and custom targets. The first desktop
  action deliberately exposes only `Review uncommitted changes`; the other
  typed targets are protocol/domain capability rather than claimed UI actions.

### Audit findings and corrections

- Gemini's F14 audit reported no P0/P1 and two P2s: entered-review history was
  represented as in-progress despite being a completed stored item, its
  description was not explicitly bounded, and the review menu needed archived
  and materialization guards. The owner fixed all findings in `23c04d1`.
- Codex's F13 audit found that the 64-section protocol bound applied only when
  an oversized response also returned a non-null cursor. Gemini amended the
  owner commit `24dbe3b` so every 65-item response fails closed and added both
  null- and non-null-cursor regressions.
- F13 currently organizes the globally bounded recent-thread working set under
  section definitions. It does not prove authoritative per-section
  `section_position` pagination or unlimited section ordering; that distinction
  remains a future research candidate.

### Stock runtime and dependency-boundary evidence

- The first `dart run tool/review_smoke.dart` invocation failed at compile time
  before any protocol operation: `runtime_diagnostics_models.dart` imported
  Flutter foundation solely for `@immutable`, which pulled `dart:ui` into the
  pure-Dart `ProcessTransport` graph. This was a real regression affecting
  existing `dart run` runtime tools and is preserved as negative evidence.
- `d2947ae` replaced that import with the direct pure-Dart `meta` dependency.
  The final review smoke created an isolated temporary Git repository, committed
  a baseline, introduced an uncommitted defect, started a stock review, observed
  both review lifecycle markers and terminal `completed`, retained a
  `726`-character assistant result, cleaned the thread, and removed the fixture.
  Existing runtime, thread, and model smokes passed afterward.
- The shared gate passed formatting (`171` files), `dart analyze`, all `395`
  Flutter tests, all `98` Rust tests, the bounded history benchmark
  (`RETAINED_TURNS=100`, `RSS_TURN_DELTA=1445888`,
  `RSS_HEAVY_OUTPUT_DELTA=32862208`), and a Linux debug build.
- The integrated Linux client launched on KDE Wayland, connected, and visibly
  rendered project/thread organization, a Git branch badge, and the composer.
  GTK emitted the previously observed ATK embedding critical and cursor-theme
  warning without a crash. No Human visual review of section density, review
  banner/activity presentation, or action placement occurred.

### Stop boundary

The latest explicit user instruction requires stopping after this peer round.
This is not evidence that the living convergence backlog is exhausted and does
not reclassify remaining supported work as blocked. No next round was
negotiated or started.

## Third-party consolidation

Base: `f8de0e9a9057a26ee3a23f85582b4a1d737c99d4`. Codex audited the repository independently, then Gemini challenged the findings read-only through the official `agy` TUI. Both traced the actual runtime and UI paths. Gemini elevated the hidden Section destinations from P2 to P1. It independently confirmed the history-truncation risk and highlighted thread identity checks after asynchronous actions.

| Severity and claim | Actual evidence and affected files | Risk | Minimal correction | Verification |
|---|---|---|---|---|
| P0 — critical defect | No P0 confirmed in the reviewed product, theme, evidence and boundary surfaces. | Scope-limited finding. | Keep the confirmed P1s distinct. | Independent peer challenge. |
| P1-A — separate Chat/Work products | `conversation.dart` changed badges, placeholders, detail mode and capability intersection. `RuntimeController` still called the same Codex transport. | A user can reasonably read a product switch or hidden execution controls as a change of backend or authority. | Hide the public selector and badges. Keep the internal compatibility seams and the existing Prose/Commands/Execution control. Defer an extra `BackendKind` enum until there is a second real backend. | Simulated UI checks verify detail switching and Codex composer controls. |
| P1-B — shared token values had two owners | `theme_tokens.dart`, `theme/official_codex_theme.dart` and the app shell repeated geometry and palette values. Opaque widget fills and translucent primitive states deliberately differ. | Independent edits can drift and flattening state roles changes visible contrast. | Keep one canonical file and alias shared geometry and colors. Preserve existing adapter-specific role values. | Adapter regression and viewport/layout tests. |
| P1-C — green counted as live proof | Three tests returned successfully if stock Codex was absent. One used the user's normal profile and called `remoteControl/disable`. `E2ERuntimeHarness` substituted the typed controller and did not exercise RPC. | False positives and potential mutation of the user's Remote setting. | Rename simulated coverage and move direct stock tests to an explicit, disposable profile. Remove the live disable call. Keep protocol fixture coverage for the removed account/config-dependent expectations. | Default suite reports direct stock cases skipped. Opt-in suite exercises its declared routes. |
| P1-D — stale current-state claims | Prior status was 2,357 lines and mixed old `264/760` geometry with 260/704 production values. README used the old 360 px split and Phase 1–4 snapshot. Architecture overstated Android write capability and lagged F7 projection behavior. | Conflicting instructions and misleading install expectations. | Preserve the old status byte-for-byte, shorten current status, refresh README and repair current architecture/matrix descriptions. | Compare archive to Git baseline and inspect current claims against production code. |
| P1-E — inaccessible Section destinations | `sidebar_activity.dart` used `.take(8)` in the row menu while the controller retains up to 64 catalog definitions. Adding all targets to the original unbounded-height menu would risk clipping. | Users cannot move to many valid sections. | One action opens a scrollable picker. Check target, thread and action availability again on selection. | Simulated 16-section test selects the last destination at a smaller viewport. |
| P1-F — immediate history truncation | Edit, regenerate, rollback retry and explicit revert in `conversation.dart` dispatched `thread/revert` immediately. The simulated suite expected this. | Opening edit can remove saved history even when the replacement is abandoned. | Explicit, cancelable confirmation with the affected history stated. Guard thread identity and action availability around async continuation. Bind pre-turn-ID retries to the clicked failed send; assigned IDs require the rollback path. | Simulated cancel, confirm, resubmit and regenerate flows, plus two failed sends with retry on the older row. |
| P2-A — pure-Dart boundary relied on convention | F14's first smoke failed through `dart:ui`; the repaired graph currently compiles. `remote_secure_storage.dart` intentionally uses Flutter. | An indirect Flutter import can break all standalone runtime tools. | Compile every core root with standalone Dart in CI; the platform storage file is excluded only from root selection. | Positive probe plus negative controls for Flutter foundation and a VM-compatible Flutter annotations import. |
| P2-B — Section and review scope | Section counts came from loaded rows. The protocol encodes four review targets, while the UI exposes only uncommitted review. | Product claims can imply complete ordering or four selectable targets. | Label loaded counts and clarify README/status/matrix. Keep stock `section_position` ordering as research. | Widget flows and stock evidence tracked separately. |
| P2-C — Material leakage | Section input and dialog use Flutter Material hosting with explicit Codex palette, shape and buttons. Other dialogs still use shared Material defaults. | A broader visual parity claim is premature. | Reuse themed controls and Codex buttons. Leave a larger dialog migration to a separately scoped review. | Check token wiring and keep subjective Human gates pending. |
| REJECTED / NOT REPRODUCED | Chat/Work backend implementation, a second app-server inside the fake, full-process proof from a test count, and authoritative per-section pagination were not established. The fake has typed mutable state and canned outcomes, but no JSONL server, model or Host. | Shipping conclusions on unsupported evidence. | Grow the fake only for presentation-relevant typed outcomes; use adapter fixtures/schema/real-process checks for protocol. Avoid introducing an extra framework. | Source and test-entrypoint inspection. |

### Consolidation verification

- `dart format` checked 173 files; `dart analyze` reported no issues.
  The default Flutter suite passed 395 cases with three explicit opt-in
  skips. The isolated direct-stock suite passed 3/3, including a non-empty
  Section create/rename/list/delete round-trip. It used a disposable Codex home,
  workspace and XDG paths. Existing account-specific diagnostics and
  Official Remote calls remain historical evidence.
- The standalone Dart probe compiled 61 roots. A temporary foundation import
  reproduced the `dart:ui` failure. A VM-compatible Flutter annotations import
  also failed the compiler depfile check. Both intentional probes were removed.
- Rust formatting, Clippy and 98 tests passed. The memory benchmark retained
  100 of 1,000 turns and discarded ten 3 MiB outputs (RSS deltas
  1,560,576 / 29,302,784 bytes).
- Packaged Host runtime, thread, model, and uncommitted review smokes passed.
  Review observed both lifecycle markers and terminal completion with 1,008
  assistant characters and cleaned its test thread.
- The Linux debug bundle opened under XWayland with an isolated Codex home.
  The app window showed the connected Codex composer and the Host/app-server
  process chain was observed. Host exit was verified. The ATK embed warning
  still occurred. This observation covers the shell and connection path.
  Subjective visual review and live UI mutation of saved threads remain
  separate gates.
- The picker regression initially found a test click before the final row had
  scrolled into the visible hit-test region. Settling the scroll and ensuring
  visibility made the last retained destination actionable. In the targeted
  peer audit, Gemini flagged the live Retry fallback and fixture isolation.
  The correction limits rollback retries to eligible threads, binds pre-ID
  retries to the clicked failure, and isolates XDG paths.

## Convergence refresh after consolidation

The peers resumed from `a64b8e798f3084ca25af6d6ead78c541344e1a92`
after [Hosted CI 42648632704](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42648632704)
passed. The official `agy` TUI established independent write surfaces.
Codex owned the thread Goal adapter, controller and sidebar. Gemini owned
the Desktop Review picker and its tests/smoke. Each audited the other
peer's actual commits. The Review follow-up added an in-flight thread
mutation gate, removed guessed refs, rejected overlong titles, and
isolated fixture Git signing/hooks. The final Goal audit reported no P0,
P1, or P2 findings.

### Fresh evidence

- The installed Linux-packaged Desktop ASAR is `26.1103.60933`, build
  `25894`, SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`.
  Static matches locate `thread/goal/get|set|clear`, `section_position`,
  and `review/start`. The review UI assets show working-tree and
  base-branch actions. The stock schema, separately, defines four
  review targets. The bounded Native picker follows that public target
  contract.
- Regenerated installed `codex-cli 0.167.0-alpha.3.2` schemas contain
  106 stable and 74 experimental-only ClientRequests, 10 stable and
  one experimental-only ServerRequest, 86 ServerNotifications, and one
  ClientNotification. Goal, Section and Review calls are stable.
  `thread/items/read` and `thread/timeline/list` remain experimental.
- A disposable stock profile and a separate Host-backed probe each
  exercised explicit user paused Goal set/get/clear and received
  updated/cleared notices. The direct integration also edited the objective
  without changing paused status. A second stock process in the same
  disposable profile read the saved goal and its thread after restart.
  The packaged Linux shell listed that thread without its badge before
  selection. Stock metadata payloads omit the goal. The follow-up adds
  selected-only hydration, with widget coverage of the resulting badge
  and controller coverage of rapid selection and stale replies.
- Stock `thread/list` accepted an explicit Section ID, ascending
  `section_position`, `limit: 1` and a second cursor. Inserting a thread
  ahead of the first page during a later probe changed a fresh query’s
  first row, while the existing cursor returned the earlier next row.
  A global query did not list the same unmaterialized fixture threads.
  Two clean profiles returned the same default Pinned section identity.
  These findings inform the bounded queue and do not establish a general
  cursor snapshot guarantee or public reserved-ID contract.
- ADB found no connected Android device and no fresh APK was available.
  [OpenAI’s mobile Remote walkthrough](https://developers.openai.com/blog/mastering-codex-remote-for-engineering)
  describes Goals, review and approvals as mobile controls. It establishes
  product behavior, with no evidence here for a supported Native relay
  client. [OpenAI’s Goal guide](https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex)
  describes persisted, user-controlled thread objectives.

### Integrated F15 verification

- Default Flutter suite: 403 passed and four explicit opt-in skips.
  Direct stock suite: 4/4 with opt-in. Dart format (174 files),
  analyze, standalone boundary (61 roots), Rust fmt, clippy and
  98 Rust tests passed. One concurrent Flutter invocation initially
  failed to copy the native-assets manifest because two invocations
  shared the same build directory. Serializing those commands passed.
- The bounded-history benchmark retained 100 of 1,000 source turns
  and discarded ten 3 MiB outputs. RSS deltas were 1,884,160 bytes
  for turns and 31,559,680 bytes for heavy-output iterations.
  The integrated Linux debug bundle and relocatable-runtime gate passed.
- The packaged Linux app opened on XWayland, rendered the connected Codex
  shell, started the bundled Host and stock app-server, and shut down the
  Host. ATK emitted the existing embed warning. A synthetic X11 click
  did not establish an interactive selected-goal walkthrough. Widget
  evidence covers selection, goal mutation controls and confirmation.
- Gemini's disposable unauthenticated Review probe observed RPC acceptance
  and enter events for the additional targets. It did not complete all
  four targets in that profile. Codex then ran each target through the
  packaged Host, stock app-server and the configured account, against
  separate temporary Git fixtures. All four had matching review and turn
  identities, both review markers, terminal `completed`, and cleaned
  threads. Assistant character counts were 691 for uncommitted, 1,016 for
  base branch, 246 for commit and 464 for custom.
- The new UI surfaces remain `HUMAN_REVIEW_PENDING`. Goal pause/resume
  controls have simulated interaction coverage. The real Goal probe used
  paused state and did not exercise model-driven automatic continuation.

## F16 scoped Sections and stored attachment evidence

The peers used the official `agy` TUI and isolated worktrees from
`f70a210`. Codex owned bounded local Section browsing (`3a25dc4`,
`392fa92`, `fffbcf3`). Gemini owned the [stored attachment evidence](reverse/THREAD_ATTACHMENT_EVIDENCE.md)
(`cbfdc20`, `88f1198`). The Section audit found no P0 or P1 issues.
It found one P2 in draft metadata after switching to another row. The
owner fixed it and verified the transition. The attachment audit narrowed
claims about Native composer types, materialization and global visibility,
and grounded PR identity in the public app-server contract.

- Stock `0.167.0-alpha.3.2` distinguishes omitted `sectionId` (global),
  explicit null (unsectioned), and a concrete Section ID. Section-position
  sorting requires a concrete ID. Direct stock and bundled Host probes
  returned matching membership and ascending order across cursor pages.
  A disposable 26-row fixture returned rows 01–25 and then row 26.
  A move within a section is also an order change. [OpenAI app-server section moves](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md#thread-section-moves)
- The Native scope shares the global working-set cap, resets stale cursors
  after membership changes, and preserves the selected conversation.
  Simulated tests cover filtering before another page is loaded, stale
  replies, membership observed first by a metadata read, and release of
  the former draft's metadata. The read-only Remote rejects scoped requests.
- Public source and a new stock probe establish the built-in Pinned
  identity. Stock rejects rename and delete for that identity. It permits
  a different custom section with the same display name. The fixture's
  named thread was visible in its explicit Pinned scope after a move.
  Metadata read showed no membership after removal. Global and explicit
  unsectioned lists still omitted the named thread before any turn.
  [Stock migration](https://github.com/openai/codex/blob/main/codex-rs/state/migrations/0045_threads_section.sql)
  [Stock section handlers](https://github.com/openai/codex/blob/main/codex-rs/app-server/src/request_processors/thread_sections.rs)
- A second stock lifecycle probe returned `unsubscribed`, then
  `notSubscribed`. The persisted thread remained in `thread/loaded/list`
  for the 1.9 s observation window. Metadata reads succeeded and
  `thread/resume` restored the subscription. These results support
  further notification-lifecycle research. Memory release and background
  approval safety are unverified.
- Stored attachments have a stable local metadata API. Stock bounds
  individual payloads to 64 KiB and a thread to 100 entries. Desktop
  evidence covers managed worktree and linked PR references. A small
  typed local link surface remains a separate candidate.
  [OpenAI stored attachment contract](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md#stored-thread-attachments)

### Integrated F16 verification

- Dart format (174 files), analyze, standalone boundary (61 roots),
  409 default Flutter cases with five explicit opt-in skips, and all
  five isolated direct-stock tests passed. Rust format, Clippy and
  98 Rust tests passed. The Linux debug bundle and source license
  packaging checks passed.
- The history benchmark retained 100 of 1,000 source turns and discarded
  ten 3 MiB command outputs. RSS deltas were 1,703,936 bytes for retained
  history and 24,715,264 bytes for the heavy-output iterations.
- The packaged Linux app connected to its bundled Host and stock
  app-server in a test-owned desktop and Codex profile. An initial
  XWayland launch rendered the connected shell and both section
  headings but ignored synthetic pointer input. In a private Xvfb
  session, the app opened the Section menu, browsed rows 01–25,
  loaded row 26 through the footer, selected it, and kept the active
  thread when returning to the global list. App, Host, and stock
  process exit was verified. The existing GTK accessibility warning
  occurred. This is an agent real-use walkthrough; Human review is
  pending.

## F17 saved pins and stock subscription boundaries

The official `agy` TUI coordinated two worktrees from `075bdf2`.
Gemini owned the saved/session Pin implementation (`0ba969a`,
`9d23964`, `bfcffa1`, `47cff8e`). Codex owned the
[subscription evidence](reverse/THREAD_SUBSCRIPTION_EVIDENCE.md)
(`48225fa`). Gemini audited the seven reported probe outcomes and
their limits. Its review reported no P0, P1, or P2 findings on the
evidence slice.

- Stock source defines the built-in Pinned identity and protects its
  rename/delete operations. The installed ASAR also embeds the same
  identity. The prior packaged Native app offered both invalid actions.
  A custom Section can share the display name and keeps ordinary
  management. [Pinned seed migration](https://github.com/openai/codex/blob/main/codex-rs/state/migrations/0045_threads_section.sql)
  [Stock Section handlers](https://github.com/openai/codex/blob/main/codex-rs/app-server/src/request_processors/thread_sections.rs)
- The first implementation selected a saved move using cached
  membership. A two-process disposable stock probe reproduced a
  custom-section move from another process with no notification to
  the first. A stale unconditional move could overwrite that
  membership. The follow-up reads and verifies the thread immediately
  before either saved write, reconciles the projected row, and declines
  the action when current membership is custom. Regression tests cover
  both stale directions and a mismatched response identity. Stock has
  no atomic compare-and-move field. A cross-process change after the
  read can still race the write.
- Peer review also replaced repeated retained-row lookup with one
  sidebar partition, kept an active custom Section in the capped
  catalog, labeled session fallback in the sidebar and conversation
  header, and made loaded counts explicit.
- The subscription probes established per-connection membership,
  delayed unload, cold metadata reads, active-turn persistence, and
  approval replay after resume. A detached connection missed an
  approval until it resumed the thread, including through the bundled
  Host. Automatic detachment is blocked on a policy that preserves
  execution and approval delivery.
- Follow-up audit found a testable non-WebView MCP evidence gap.
  An offline stdio MCP fixture succeeded through both direct stock
  and the bundled Host for catalog discovery, global/thread resource
  reads and a typed text/structured tool result at the wire. A direct
  tool call with a nested form received a decline in the sampled
  fixture. A model-driven call with a disposable loopback Responses
  server instead routed the stock consent form and the MCP server's
  form as two requests and reached terminal completion. A typed Native
  smoke remains queued. [App-server MCP contract](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md)

### Integrated F17 verification

- Dart format and analyze passed, as did the standalone boundary
  (61 roots), 412 default Flutter cases with five explicit opt-in
  skips, 5/5 isolated direct stock cases, Rust formatting and Clippy,
  and all 98 Rust tests. The Linux debug bundle and source license
  packaging checks passed.
- The history benchmark retained 100 of 1,000 source turns and
  discarded ten 3 MiB command outputs. RSS deltas were 1,908,736
  bytes for retained history and 29,593,600 bytes for heavy outputs.
- A packaged Linux walkthrough used the bundled Host and stock in a
  private Xvfb desktop and disposable profile. A separate stock process
  moved an unsectioned thread and then a saved pin into a custom Section.
  The stale actions in the conversation header declined both writes
  and rendered the current membership. A subsequent ordinary Pin
  persisted in stock. A custom-section session pin kept the stock
  membership and disappeared when the app restarted.
- The built-in menu initially clipped its long Browse label in the
  packaged app. The follow-up shortened it to “Browse saved pins”.
  The fresh bundle displayed the full label, entered the stock-only
  Pinned scope, and omitted the session pin from that scope. A saved
  Unpin removed the row while leaving the selected conversation open.
  A separate stock process confirmed the persisted Pin, persisted
  Unpin, and preserved custom membership after app exit. The
  same-named custom Section still offered Rename and Delete.
- The first private display reached its test deadline. The final
  launch exited on request, and the app, Host and stock processes
  were gone. The environment emitted the existing GTK accessibility
  and software-display warnings. Human visual acceptance is pending.
- Hosted CI on `e61f67c` first reported failure with a single
  successful Windows job and no Linux or macOS job records. The second
  attempt on the same SHA reported success for all three jobs.
  [Attempt 1](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42671357717/attempts/1)
  [Attempt 2](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42671357717/attempts/2)

## F18 direct MCP forms and runtime evidence

The official `agy` TUI coordinated independent worktrees from
`e61f67c`. Codex owned the protocol status correction and real smoke
(`943b8c0`, `7cea8af`). Gemini owned the modal interaction and
simulated regression (`558a8ee`, `1233497`, `a36a9b6`,
`3f6b599`). Both audited the actual commits.

- In the prior packaged app, a direct tool call on a disposable
  on-request thread left the ecosystem modal busy while its form
  rendered in the conversation behind the barrier. Closing the
  modal exposed the form. After submission, reopening the modal
  showed no result because the original dialog had been disposed.
  A focused simulated reproducer independently confirmed that
  the accept control was unreachable with the dialog open.
- Direct stock and bundled Host probes establish separate form paths.
  The sampled direct tool call under `never` returned a decline.
  Under `on-request`, a direct tool call and a thread-scoped resource
  read each delivered a null-turn form and accepted a response.
  A model-driven call delivered stock tool consent and a subsequent
  MCP form with the matching turn ID, then completed the turn.
- The old UI showed bare `unsupported` for a working local MCP
  server. The value came from stock `authStatus`. The global
  catalog reported `runtimeStatus: null`. The thread-scoped
  catalog reported `runtimeStatus: connected` with the same auth
  status. Native now projects these fields separately.
  [Stock MCP schema](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/json/v2/ListMcpServerStatusResponse.json)
- The modal uses one scroll-bounded card for a matching thread, server,
  and null-turn form while a direct operation is in flight. This
  keeps the draft when switching tabs. Peer review removed the
  initial global claim registry and the duplicated form mounts.
  The underlying conversation can still present pending forms.
- `dart run tool/mcp_smoke.dart` uses a fresh profile and a Dart
  stdio MCP fixture with a loopback Responses endpoint. It exercises
  the real Native adapter, bundled Host, and stock app-server with
  no configured account. It checks the typed catalog, global and
  thread-scoped resources, typed tool results, both approval
  policies, and model-turn terminal identity.
- At integration `3c2d327`, an isolated packaged Linux walkthrough
  selected a resumed fixture thread and submitted both tool and resource
  forms. Switching from MCP to Skills and back kept the tool draft.
  The original modal showed the tool result and the resource content.
  The app, bundled Host, and stock child all exited on request.
- The same walkthrough exposed two adjacent failures. A pending resource
  read put the spinner on Call tool. Selecting a cold persisted thread
  and then reading a resource surfaced a raw `thread not found` response.
  A separate bundled Host probe reproduced that response on both direct
  methods after a metadata-only read. Explicit `thread/resume` restored
  both methods, and a global resource read still worked without a thread.
- Automatic resume was considered during peer review. A separate disposable
  installed-stock probe seeded one synthetic turn, persisted a paused Goal,
  restarted, and marked the Goal active while the thread was cold. The
  loopback model request count stayed at one until explicit `thread/resume`.
  It reached four after resume, before the Goal was paused and the runtime
  closed. This verifies a model-execution side effect of resume and keeps it
  an explicit prerequisite for a cold thread. [Upstream Goal resume hook](https://github.com/openai/codex/blob/main/codex-rs/ext/goal/src/extension.rs)
- Shared validation at `3c2d327` passed format and analysis, the pure-Dart
  boundary check over 61 roots, 414 default Flutter cases with five opt-in
  skips, 5/5 isolated direct-stock cases, Rust format, Clippy, and 98
  tests. The bounded-history benchmark retained 100 of 1,000 source turns
  and 100 entries, discarded ten 3 MiB outputs, and reported
  RSS deltas of 1,646,592 and 29,315,072 bytes. The Linux debug bundle and
  license check passed. The MCP smoke passed with that bundle's Host.
- The final code integration `8ad91d3` includes Gemini's operation-specific
  progress and explicit cold-thread requirement. The delayed simulated path
  verifies that a pre-existing form stays in the conversation and the new
  request appears in the modal. An earlier assertion had counted the retained
  conversation card as a failure. The corrected assertion separates the two
  surfaces and resolves the old fixture request.
- The rebuilt packaged Linux app returned a global resource without a selected
  thread. Both cold scoped actions showed guidance to resume. After explicit
  sidebar resume, both scoped operations put the spinner on the active
  button and returned accepted results in the original dialog. Switching tabs
  kept the tool form draft. The run used a private Xvfb display, disposable
  profile, bundled Host and installed stock app-server. All three processes
  exited when the app closed.
- Reverification at `8ad91d3` passed format, analysis, all 61 pure-Dart roots,
  414 Flutter cases with five opt-in skips, 5/5 opt-in direct-stock cases,
  Rust format, Clippy, 98 Rust tests, Linux bundle and licenses, and MCP smoke
  with the exact bundled Host selected. The benchmark retained 100 of 1,000
  source turns and 100 entries, discarded ten 3 MiB outputs, and measured
  RSS deltas of 1,855,488 and 27,193,344 bytes. Human interaction review is
  pending.

### Catalog search follow-up

The Native sidebar currently filters loaded rows. Its typed adapter supports
stock `thread/list.searchTerm`, with no sidebar caller. A disposable stock
fixture placed a named thread behind 27 newer rows. The first 25 rows omitted
it. The title search matched `Cobalt` and `Needle`, skipped mixed-case `cObAlT`,
treated `%` literally in the tested title, and respected the archive filter.
The same search matched the synthetic Goal text and skipped the workspace
path. This differs from Native's case-insensitive local metadata filter.

In the installed Desktop build, call sites at ASAR offsets `8825777` and
`109859343` pass `searchTerm` to `thread/search` or to the stock `thread/list`
fallback with `useStateDbOnly`. The observations establish separate search
paths. Which branch and matching behavior a given Desktop session uses need
runtime evidence before asserting parity.
The installed experimental `thread/search` returned empty for those same
metadata-only fixtures. A search of full persisted turns needs a separate
probe before interpreting that result as a content-search limitation.

## F19 bounded local lookup

- Fresh schemas from installed `0.167.0-alpha.3.2` report 106 stable and 74
  experimental client requests, 10 stable and one experimental server request,
  86 server notifications, and one client notification. The measured Desktop
  build and ASAR hash were unchanged. `adb devices` listed no device.
- A second stock fixture seeded a complete turn with a loopback model,
  renamed the thread, and restarted. Stable `thread/list.searchTerm`, with
  and without `useStateDbOnly`, matched the saved title and first user
  text. The experimental `thread/search` matched the user and assistant
  text and missed the independently saved title. The sampled stable title
  match remained case-sensitive. The default Native loaded-row filter
  still matches local metadata without case sensitivity.
- F19A `c75c06d` uses the stable saved-search contract and one catalog
  working set. The 64 focused Flutter cases cover retained selection,
  bounded pages, a stale result after closing search, refresh after a name
  update, keyboard submit and escape, and the prior geometry and product
  controls. Dart format and analysis and the Linux build passed.
- The packaged F19A app used the bundled Host and stock app-server with 28
  disposable persisted threads. The initial list and loaded filter omitted
  the old title. Explicit search found it while preserving the prior
  active conversation. Selecting the result and returning to loaded rows
  preserved the new conversation. An initial Enter moved focus out of the
  field and prevented immediate Escape. The rebuilt app retained focus,
  cleared search with Escape, and passed the pointer path. At 720 × 800 the
  compact view showed an empty mixed-case result and the exact-case match.
  A direct resize on the private Xvfb display briefly captured a stale frame
  before input repainted the window. The compact flow then passed. The
  packaged app, bundled Host, and stock child all exited.
- F19B `e8acec2` and `67de334` project local stored GitHub and GitLab links
  from stable `thread/attachment/list`. The installed stock store accepted
  generic payload URLs and enforced a 256-byte UTF-8 identity key limit.
  The parser rejects unsafe URLs and identity mismatches, bounds each page
  to 16 records and the total scan to 100 records and 16 pages, and keeps at
  most 16 links for the selected thread. [Stock attachment contract](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md#stored-thread-attachments)
- Peer audit reproduced a Dart percent-decoding exception and a stale
  open popover. Source review found that the initial selection path could
  start additional scans before earlier scans finished. The corrected
  implementation skips malformed URLs, serializes one scan with
  one replaceable pending target, and observes the current selected snapshot
  inside the overlay. Ten focused cases also verified the explicit retry and
  old-runtime `-32601` fallback. A second typed call to an unsupported
  transport fails locally instead of returning an empty success.
- The shared packaged app used a disposable cold thread with 23 stock
  attachments over two pages. It showed the two valid links, excluded
  unrelated and malformed records, and still offered explicit thread
  resume. Selecting a thread without links cleared the prior projection.
  Both Open buttons sent the expected canonical HTTPS URI to a private
  desktop link handler. The popover fit the measured 1280 × 720 and
  720 × 800 layouts. The app, bundled Host and stock child exited on
  request. Human interaction and external browser acceptance remain open.
- Shared integration `8052b0d` passed format, analysis, 64 pure-Dart roots,
  427 Flutter cases with five opt-in skips, 5/5 direct-stock cases, Rust
  format, Clippy, 98 Rust tests, Linux bundle and license verification, and
  the bundled Host MCP smoke. The history benchmark retained 100 of 1,000
  source turns and 100 entries, discarded ten 3 MiB outputs, and measured
  RSS deltas of 2,121,728 and 32,563,200 bytes.

## F20 explicit review links and occurrence search evidence

- F20A `1d2bc47` records the installed stock and bundled Host results for
  [stored conversation search](reverse/THREAD_SEARCH_OCCURRENCE_EVIDENCE.md).
  The bounded anchor lookup reached a hit outside the newest 100 turns.
  Legacy support, stale anchors after revert, and fork behavior have
  independent evidence. Native still searches the loaded conversation.
- F20B `b2dcb01` and `74293f0` add an explicit local Link action. The
  adapter verifies the same thread through bounded pages and reports an
  existing canonical or legacy record without another write. The store
  enforces the 256-byte canonical key limit and create-or-get semantics.
  The preflight and add are separate stock calls, so another process can
  insert a legacy alias between the two.
- The initial link form overflowed the popover by 28 pixels in a simulated
  product test. The corrected layout scrolls the form, notices, and result
  list within the existing popover height. The follow-up rejects an empty
  page with a continuation cursor as incomplete and returns no stored
  record when verification stops before a write.
- Shared format, analyze, 431 default Flutter tests with five opt-in skips,
  5/5 direct-stock tests, 98 Rust tests with Clippy, the 64-root pure-Dart
  gate, Linux debug bundle and license checks, and bundled Host MCP smoke
  passed. The memory benchmark retained 100 of 1,000 source turns and
  exercised ten 3 MiB command outputs.
- Packaged Linux against the bundled Host and stock Codex rejected a synthetic
  URL with user info and a query without echoing either in the error. It
  linked a saved cold thread, reported subsequent identical input as
  already linked, and detected a second thread's legacy URL identity. The
  form fit at 720×800. App, Host, and stock all shut down. A fresh stock
  process read back exactly one expected record in each thread, which both
  remained cold. This is agent real-use evidence. Human visual and physical
  mobile checks remain pending.

## F21 saved-message search and compact thread navigation

- On the measured Desktop `26.1103.60933` ASAR, renderer chunk
  `884779.bf167971f9.js` invokes experimental `thread/searchOccurrences`
  and supplies the returned inclusive cursor to match hydration. The bundle
  requests up to 250 hits in that path. Native requests at most 16 per page,
  validates UTF-16 offsets and cursor progress, and verifies a stable
  `thread/turns/list` summary page before changing the working set.
  [Stock protocol registration](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/common.rs)
- The baseline history test reproduced a stuck item spinner after refresh
  cleared the selected turn while an item page was pending. F21A
  (`eccd4f1`, `1e120e4`) invalidates the item request at window replacement
  and scopes anchor progress to the originating selection. The initial
  packaged narrow view also dropped Ctrl+F after selecting a thread. An
  autofocus-only attempt still failed the regression test. An explicit
  focus request on the mounted conversation passed it.
- The baseline compact view ignored a successful same-row selection when
  its thread ID had not changed. F21B (`c69491f`) closes Threads after an
  explicit successful select or resume and keeps the view open during a
  background catalog refresh or a failed read. Both changes were reviewed
  against their commits through the official `agy` TUI.
- A separate exploratory bundled Host probe found durable read receipts in
  both legacy and paginated saved threads. A cold empty thread could be
  marked unread at `threadStart`, rejected a stale revision with `-32600`,
  and could be marked read using a fresh revision without loading the
  thread. Turn-completion and multi-connection notification behavior remain
  research questions.
- Shared `c788855` passed format and analyze, 441 default Flutter tests with
  five opt-in skips, 5/5 isolated direct-stock tests, 98 Rust tests with
  Clippy, the 64-root pure-Dart gate, the Linux bundle and license checks,
  and bundled Host MCP smoke. The history benchmark kept 100 of 1,000
  source turns and exercised ten 3 MiB output payloads.
- The combined Linux package used bundled Host, stock
  `0.167.0-alpha.3.2`, and a disposable profile seeded with a loopback
  model. At 720×800, Ctrl+F opened after selecting a saved thread.
  Search opened the oldest message in a 108-turn fixture and returned to
  the newest window. A separate stock process reverted a hit before
  navigation. Native reported the failure and left the current window in
  place. A legacy thread kept loaded Find, then a paginated thread
  returned 16 and 3 hits on successive pages in the same app.
- At the same size, refreshing the compact catalog kept Threads open.
  Selecting the current row and explicitly resuming it each returned to
  the conversation. No Flutter overflow or exception was observed, and
  app, Host and stock shut down. The session verifies the packaged
  product. Human visual and physical Android checks remain separate.

## F22 local read receipts and stored unlink evidence

- The measured Desktop ASAR `26.1103.60933` contains sidebar Mark as read and
  Mark as unread menu strings and calls `thread/readState/update`.
  Installed stock `0.167.0-alpha.3.2` registers the write only in the
  experimental request schema. Optional `readState` and `readStates`
  response fields appear only in the experimental generated schema.
  `thread/readState/changed` appears in the stable notification schema.
  An initialization without experimental opt-in still returned passive
  data in the tested runtime and rejected the write. [Stock protocol registration](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/common.rs)
- In isolated bundled Host probes, completed turns in legacy and paginated
  threads set the unread position to the completed turn when the prior
  receipt was clear.
  A later completion changed the revision. A stale mark failed with
  `-32600` and a fresh explicit mark cleared the receipt while the reader's
  thread stayed cold. Repeating a read mark with the fresh revision
  advanced it in the sample. Archived saved threads returned receipts.
  An ephemeral fixture had no receipt.
- In a single stock server with two disposable local connections, a
  metadata-only client received its own mark response while a subscribed
  peer received the notification. With both subscribed, both received
  the matching notice. In the separate-process completion sample the cold
  observer saw the updated receipt through metadata read, with no matching
  event during its observation window.
- F22A (`2f1fbb6`, `e2c3fb1`) projects the optional state and offers an
  explicit, revision-bound local mark. The first race regression showed
  that a delayed successful write response could overwrite a more recent
  catalog receipt. Applying catalog snapshots through the receipt ordering
  guard fixed it. The current branch also tests stale catalog pages and writes,
  receipt-less resume, and unsupported local writes.
- F22B published the reviewed evidence tree as `eb07c25` from Gemini's
  local tip `5c3e1db`. It records exact raw-key deletion, alias and
  whitespace behavior, notification scope, and a reproducible re-add race.
  The peer's original local research history remains intact. Single-key
  deletion can leave an alias visible. Multi-key removal can partially
  succeed and stock offers no compare-and-delete condition or safe
  automatic retry. [Unlink evidence](reverse/THREAD_ATTACHMENT_UNLINK_EVIDENCE.md)
- Shared `eb07c25` passed format and analyze, 450 default Flutter tests
  with five opt-in skips, 5/5 isolated direct-stock tests, 98 Rust tests
  with Clippy, the 64-root pure-Dart gate, Linux bundle and license checks,
  and bundled Host MCP smoke. The history benchmark kept 100 of 1,000
  turns and exercised ten 3 MiB command output payloads.
- The integrated Linux package used bundled Host, stock
  `0.167.0-alpha.3.2`, and a disposable profile. At 720×800, an independent
  stock process changed the unread revision while the Native action menu
  was open. The stale click displayed a conflict and preserved unread
  state. A fresh explicit Mark as read cleared it. Mark as unread
  restored it. Independent metadata reads verified unread, read, and
  unread while the thread remained cold. App, Host, and stock shut down.
  The Human visual and physical Android gates remain separate.

## F23 cold composer sends and workspace file evidence

- Stock `0.167.0-alpha.3.2` registers experimental `thread/queue/*`.
  In a disposable bundled Host probe, two adds with the same
  `clientUserMessageId` created separate saved entries. A second, cold
  process listed them. The loaded process dispatched both after its
  foreground turn completed. Adding while loaded and idle dispatched
  immediately in the sample. Cold add, edit and exact reorder persisted
  without model calls. A partial reorder and cold `queue/start` failed
  with `-32600`. After a restart, explicit `thread/resume` ran the saved
  entries. A list limit of zero was clamped to one.
  [Stock protocol registration](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/common.rs)
- The F22 Linux package reproduced a cold Send dispatching a saved
  prompt and steering its new composer draft into the same persisted
  turn. F23A adds one local `thread/queue/list` request at limit one and
  projects presence only. A pending or inconclusive response requires
  a separate Resume action, which leaves the draft intact. A conclusively
  empty response and the older unknown-method path keep ordinary Send.
  The guard retains the draft when it observes an active resumed turn.
  Queue inspection and resume are separate RPCs. Concurrent stock work
  can change the state between them, and stock `turn/start` can accept
  input on an already active turn.
  [Upstream turn admission test](https://github.com/openai/codex/blob/main/codex-rs/app-server/tests/suite/v2/turn_start.rs)
- The Linux package with F23A used a disposable profile, bundled Host,
  the installed stock binary and a loopback model. Cancel left the model
  request count unchanged. Confirming Resume ran the saved prompt with the
  composer draft intact. After the saved turn completed, Send created a separate turn for the
  draft. Bounded item reads verified the two prompts and their distinct
  persisted turn IDs. After a cold app restart, bounded history showed both
  prompts without a model call. The live timeline still omitted the
  queued user bubble while displaying the reply. The live adapter currently
  discards user-message lifecycle items.
- A separate stock probe received paired `item/started` and
  `item/completed` notifications for each queued user message. Two queue
  entries sharing a client message ID received distinct stock item IDs.
  This makes authoritative live input a separate follow-up. Deduplicate
  lifecycle events by stock item identity, and use a client message ID
  only to reconcile an optimistic entry originating from this client.
  The installed stable schemas and a second bundled probe verified the
  echo independently for direct `turn/start` and `turn/steer`. They
  produced distinct stock user items in the same turn.
- F23B separated concrete Desktop composer and file-tree session calls
  from generic ASAR registration and the direct artifact lookup.
  A stable one-shot stock query works with experimental opt-in disabled.
  Disposable debug Host and independent packaged Host probes found that
  the stock walker can return paths through workspace symlinks that point
  outside the root. A canonical client filter can check suggestions and
  selection after traversal. Stock can still inspect external filenames
  and return them over local stdio. The evidence document records these
  boundaries and distinguishes the sample from a general performance or
  cancellation guarantee. [Workspace file search evidence](reverse/WORKSPACE_FILE_SEARCH_EVIDENCE.md)
- Gemini reviewed F23A `e0834b8` with no unresolved findings. Codex
  audited F23B and the original owner corrected the Native experimental
  default, claimed queue writes, Host provenance, traversal boundary,
  sample calibration and ASAR prose. The reviewed evidence tree from
  `545ca29` was published as `4da0413`. The peer branch retains its
  original commits. Both audits ran through the official `agy` TUI.
- Shared `4da0413` passed Dart format and analyze, 457 Flutter cases with
  five opt-in skips, 5/5 isolated direct-stock cases, 98 Rust tests with
  Clippy, the 64-root pure-Dart gate, Linux bundle and license checks,
  and bundled Host MCP smoke. The benchmark retained 100 of 1,000 turns
  and exercised ten 3 MiB command output payloads.
- The shared Linux build repeated the queue walkthrough at 1280×720.
  The first fixture assertion mistakenly treated a model request's full
  context as the current turn's input. The third model request contained
  the saved prompt as prior context. Independent bounded stock item reads
  identified three completed turns and verified the saved prompt and
  new draft belonged to two distinct turns. Cold relaunch showed both
  prompts without another model request. App, Host, and stock shut
  down in both runs. Subjective Desktop review and physical Android
  remain separate.

## F24 authoritative local user items and output deferral evidence

[Hosted CI 42724519230](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42724519230) passed on `be1f39e`.

- Installed stock `0.167.0-alpha.3.2`, public stable `0.167.0`, and public
  alpha `0.169.0-alpha.7` echoed independently supplied
  `clientUserMessageId` values on direct start and steer in disposable
  bundled Host probes. Installed and public alpha both emitted distinct
  stock item IDs for queued entries sharing one client ID. The stable
  item lifecycle carries the echo separately from the stock item ID.
  [Upstream user-item test](https://github.com/openai/codex/blob/main/codex-rs/app-server/tests/suite/v2/turn_start.rs)
- F24A (`f6bcf5c`) projects completed identified local user items and
  reconciles optimistic rows through the originating client ID. It keeps
  each visual key and the locally authored attachment representation.
  History and repeated events deduplicate on stock item identity. Stock
  user messages without a client ID keep the older optimistic/history
  behavior. Only the local process enables the projection.
- Controlled regressions reproduced a failed old Start clearing a
  subsequent active turn, an old Steer reply releasing a newer Steer,
  and a prior Send response clearing a newly typed draft. Response
  ownership now follows the originating request and binding. The
  composer clears only the submitted draft in that selection.
- The packaged Linux app and bundled Host with installed stock displayed
  two saved queue prompts sharing one client ID, including a file mention,
  followed by one native Start and one native Steer. Independent bounded
  item reads verified distinct stock IDs, two saved queue turns, and the
  Start/Steer inputs in one turn. The first synthetic pointer/clipboard
  pass did not submit the Steer. A longer controlled model window and
  direct typing passed. Cold summary contained only the first input of
  the steered turn. Expanding its bounded details showed both without
  another model request.
- The exact alpha binary also exercised Native's existing command-output
  path. For a saved 2,594 ms turn, opening details showed Fetch output
  safely while the private Host cache had no output payload. Fetch
  produced one spool entry and the viewer displayed the 29-byte fixture
  marker. In a separate 206 ms turn, stock's summary contained only user
  and assistant items and the per-turn page contained a deferred command.
  Commands and Execution had no details affordance because the divider
  currently requires a formatted work duration. This is a separate
  machine-actionable history presentation gap. Native main before F24
  reproduced it with installed stock in a 221 ms saved turn, where the
  per-turn command output was inline on stock and spooled by Host.
  On the longer alpha turn, clicking the divider in Execution mode
  did not load the command, while the same divider loaded it in Commands
  mode. Execution currently treats the view mode itself as expansion.
- F24B published the reviewed evidence tree from Gemini's `f4d2766` as
  `757fd27`. The owner corrected provider write schema claims, identified
  concrete Desktop ASAR occurrences, and separated installed package,
  public releases, source and probe provenance. The original research
  commits remain on the peer branch. Gemini's independent audit of F24A
  found no unresolved P0, P1 or P2. Both audits ran in the official
  `agy` TUI. [Output deferral evidence](reverse/OUTPUT_DEFERRAL_EVIDENCE.md)
- Shared `757fd27` passed Dart format and analyze, 467 Flutter cases
  with five opt-in skips, 5/5 isolated direct-stock cases, 98 Rust
  tests with Clippy, the 65-root pure-Dart gate, Linux bundle and license
  checks, and bundled Host MCP smoke. Loopback-backed Turn and
  uncommitted Review smoke passed, including interruption and both review
  lifecycle markers. The history benchmark retained 100 of 1,000 turns
  and exercised ten 3 MiB command outputs.
- The integrated Linux package repeated the identified queue, attachment,
  Start, Steer and cold expanded-history walkthrough at 1280×720.
  Stock readback matched one initial user item, two queued items and
  two local inputs. Cold selection and expansion made no model calls.
  App, Host, and stock shut down. Human visual and physical Android
  checks remain separate.

## F25 bounded saved-turn details and provider diagnostics evidence

[Hosted CI 42729503871](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42729503871) passed on `4c9ea61`.

- On base `be1f39e`, saved subsecond turns on installed stock and public
  alpha contained command items, but their summaries contained only user
  and assistant rows. A formatted elapsed time was required for the
  disclosure. The longer fixture appeared expanded in Execution while
  its item page was still unopened. A first-page failure left the
  summary visible without an explicit retry state.
- F25A (`8e5e0d8`) reuses one disclosure in Commands and Execution.
  It anchors to the first non-user item, or the last user item when
  the summary has no other row. A formatted duration remains visible
  when present. Selection controls expansion and a failed first
  page offers explicit retry. Display-mode changes leave item loading
  user-initiated and retain the existing 25-item page and 100-item cap.
- Four new simulated-runtime regressions failed on the base and
  passed after the fix. They cover short history, Execution, a failed
  first page and a user-only summary. Existing output and history
  controller checks also passed.
- The packaged Linux branch opened the existing 221 ms fixture on
  installed stock and displayed the saved 29-byte output. Resizing
  the output dialog to 720×800 retained the viewport and controls.
  The 2,594 ms public-alpha fixture opened and collapsed in Execution.
  The temporary Host cache had no output payload before Fetch and
  exactly one matching spool file afterward. View output displayed the
  fixture marker. The first synthetic click on the alpha case preceded
  catalog readiness and was repeated once the row could be selected.
- The packaged branch also exercised the 206 ms public-alpha fixture in
  Execution, including a single matching spool file after Fetch and the
  visible marker. The first automated click on the output viewer did not
  open it after Fetch. The subsequent click opened it, and no cause was
  established for the first click.
- F25B published the reviewed evidence blob from Gemini's `cdd228e` as
  `f838e91`. On two public preview binaries `modelProvider/list` returned
  typed summaries. Installed `0.167.0-alpha.3.2` and stable `0.167.0`
  returned method-specific unknown-variant errors. A separate alpha
  supplied `account/securitySetup/read`, and a disposable loopback probe
  observed unvalidated notice copy and action URLs. Stable snapshots
  lack both identity fields together. Experimental workspace routing is
  a follow-up candidate for selected saved workspaces. Provider writes
  were inspected only through source and schema.
  [Provider and account evidence](reverse/PROVIDER_ACCOUNT_DIAGNOSTICS_EVIDENCE.md)
- The official `agy` TUI peer audit cleared F25A at `8e5e0d8` without
  P0, P1 or P2 findings. F25B's owner corrected the unsupported-method
  scope, privacy bounds and experimental identity distinction. The
  original B commits remain on the peer branch.
- Shared `f838e91` passed Dart format and analyze, 471 Flutter cases
  with five opt-in skips, 5/5 isolated direct-stock cases, 98 Rust
  tests with Clippy, and the 65-root pure-Dart gate. The history
  benchmark retained 100 of 1,000 turns and exercised ten 3 MiB command
  outputs. The Linux bundle and license checks, bundled Host MCP
  smoke, and loopback-backed Turn and uncommitted Review smoke passed.
  Turn smoke verified interruption. Review smoke verified both
  lifecycle markers.
- The integrated Linux package exercised the 221 ms installed-stock
  case at 720×800 and the 206 ms and 2,594 ms alpha cases in
  Execution. Both alpha cases had no matching Host spool file before
  Fetch and one afterward. The 29-byte marker was visible in each
  viewer, and both alpha detail pages collapsed. All three test app,
  Host and stock process trees shut down. Human visual review and
  physical Android remain separate.


## F26 local provider inventory and MCP result integrity

[Hosted CI 42736330309](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42736330309) passed on `a7b0fcd`.

- F26A (`c95df74`) reads `modelProvider/list` only when opening or
  refreshing local Runtime details. The retained snapshot keeps at most
  32 display names, provider kinds and an exact default marker. It caps
  labels without splitting surrogate pairs and removes control and bidi
  formatting characters. Raw endpoints, environment names, cloud
  settings and provider IDs are not retained by the projection. Raw
  JSON still crosses the local Host and is decoded before projection.
- An exact unknown-method reply displays normal version unavailability.
  Other RPC and malformed response errors stay failures with fixed
  provider section copy. The adjacent Provider capabilities card is
  independent. There are no provider mutations or Remote RPC additions.
- A disposable pure-Dart probe through the real bundled Host exercised
  installed `0.167.0-alpha.3.2`, public stable `0.167.0`, Desktop-train
  `0.167.0-alpha.4.1`, and public `0.169.0-alpha.7`. The first two
  returned unsupported. Both previews returned OpenAI as default and
  a synthetic custom gateway. An extra Desktop-train fixture verified
  that a configured custom default was marked instead of OpenAI.
- The branch package showed the legacy unavailable state and the
  Desktop-train provider list with a custom gateway and default marker.
  Refresh and the 720×800 viewport preserved those rows. The first
  rapid synthetic click in the preview case did not open the dialog.
  A focused pointer press opened it. The app, Host, and stock process
  trees shut down. The fixture had no account and rate-limit diagnostics
  separately reported that account authentication was required.
- A separate direct MCP tool probe observed a payload-integrity gap.
  A disposable fixture returned a synthetic string under
  `structuredContent.nested.aggregatedOutput`. Dart through direct
  stock preserved the string. Through the bundled Host with the same
  stock, the string became null and the object gained
  `_codexNativeOutput`. The result reproduced on installed stock and
  public alpha `0.169.0-alpha.7`. The Host test
  `handles_multiple_messages_nested_keys_and_non_string_values` also
  covers name-based interception at a nested path. An independent Host
  correction must preserve actual command-output spooling and keep
  unrelated structured result fields intact.
- F26B published the reviewed final evidence from Gemini's `0ccd0f9`
  as `317dfb1`. The headless four-binary probe measured separate
  1 MiB live and 64 KiB persisted internal result caps and six of
  sixteen selectively deferred fixtures on the higher alpha. The
  wire envelope and arguments can add bytes beyond the internal
  result cap. Legacy, structured, media and error cases retain inline
  paths. The Remote size effects are source extrapolations. The
  installed Desktop evidence is static and records the actual ASAR
  offsets with zero deferral or item-read method strings.
  [MCP result evidence](reverse/MCP_RESULT_DISCLOSURE_EVIDENCE.md)
- Official `agy` TUI review of F26A found no P0, P1 or P2 issues at
  `c95df74`. The B audit corrected source, evidence labels, scope and
  archive provenance. Two amended private B drafts were preserved
  in local audit refs. The accepted corrections were follow-up
  commits, and shared `main` history used ordinary integration.
- Shared code/evidence commit 317dfb1 passed Dart format and analyze,
  475 Flutter cases with five opt-in skips, 5/5 direct stock cases,
  98 Rust tests with Clippy, and the 65-root pure-Dart gate. The
  history benchmark retained 100 of 1,000 turns and exercised ten
  3 MiB command outputs. The Linux bundle and license checks, Host
  MCP smoke, and loopback-backed Turn and uncommitted Review smoke
  passed, including interruption and both Review lifecycle markers.
- The integrated package repeated the installed version fallback and
  the Desktop-train inventory and refresh walkthrough. The provider
  list and default marker fit at 720×800. Both test app, Host and stock
  process trees shut down. The bundled Host also passed the same
  four-binary provider probe and the custom-default case. Human visual
  review and physical Android remain separate gates.

## F27 scoped Host command output and account identity evidence

[Hosted CI 42744314663](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42744314663) passed on `b42f534`.

- A structured result from a disposable MCP tool contained an ordinary
  nested `aggregatedOutput` string. The F26 Host replaced it with null
  and injected a spool descriptor. The new Rust opaque-payload test and
  the real bundled-Host MCP smoke both failed on the old Host.
- F27A (`5e4f42c`) scopes the direct string field to stock v2 ThreadItem
  containers. A bounded path stack follows the JSON parser depth and
  handles escaped keys and either member order. The generated installed
  and public-alpha schemas had ten matching response and notification
  paths, each with a commandExecution item. Nested MCP result and
  argument objects, including command-looking strings or tags, pass
  unchanged. Existing spool decoding, rollback, deduplication and
  Remote capture limits retain their tests.
- The branch passed 17 targeted Host transformer cases, 100 total
  Rust tests, Dart format and analyze, the 65-root pure-Dart gate,
  475 Flutter cases with five opt-in skips, 5/5 direct stock cases,
  the bounded-history benchmark and Linux package checks.
- The bundled Host's MCP smoke passed installed stock, public stable,
  Desktop-train preview and higher public alpha. A packaged Linux
  walkthrough resumed a disposable saved thread and called its
  synthetic MCP tool in Skills, Plugins & MCP. The structured value
  survived at 1280×720 and 720×800. No matching command spool was
  created for the MCP value. The app, Host and stock shut down.
- Packaged command-output fixtures on installed stock and higher
  alpha displayed the expected 29-byte marker. Installed stock
  spooled when the details loaded. The alpha had no matching spool
  before Fetch and exactly one afterward. Both process trees shut down.
- The synthetic child-process Host benchmark verified descriptor
  identity, deduplication and first/last byte ranges at 3, 30 and
  300 MiB on both baseline and fixed binaries. At 300 MiB, sampled
  Host RSS growth was 626,688 B baseline and 1,110,016 B fixed.
  Sampled Dart RSS growth was 4,096 B baseline and 53,248 B fixed.
  Those values describe the sampled runs.
- A separate real installed-stock probe used one saved fixture turn
  through the bundled Host. Full `thread/turns/list`, bounded
  `thread/items/list`, `thread/items/read`, legacy
  `thread/read(includeTurns: true)` and `thread/resume` with a one-turn
  full initial page all projected the same 29-byte command spool
  reference. The deprecated full read ran only on that one-turn fixture.
- F27B's initial peer evidence used incorrect positive wire fields and
  source descriptions. The official `agy` audit challenged those against
  the generated alpha schema, pinned source and independent disposable
  runtime probes. The corrected peer tree `8fc4459` was published as
  `8473a40`. The owner retained the original and follow-up commits in
  the isolated branch. Gemini cleared F27A at `5e4f42c` without P0, P1
  or P2 findings.
- In independent probes through the F26 bundled Host, installed, stable
  and Desktop-train stock returned `-32600` for the notice method.
  Higher public alpha returned a matching synthetic pair in a selected
  workspace. The two experimental capability settings produced the same
  observed routing field, which remains experimental in the schema.
- Direct higher-alpha loopback probes confirmed that an invalid notice
  shape returns null and missing routing can fail `account/read` while
  the notice RPC succeeds. Replacing only the fixture's saved user and
  synthetic bearer while the notice GET was held produced an original
  notice and a matching stale cached account snapshot. A later notice
  returned null. Separate public logout against a disposable fixture
  suppressed the in-flight result. Those probes establish why the
  experimental routing pair cannot authorize notice presentation.
  [Account identity evidence](reverse/ACCOUNT_NOTICE_IDENTITY_EVIDENCE.md)
- Shared code/evidence commit 8473a40 passed Dart format and analyze,
  475 Flutter cases with five opt-in skips, 5/5 direct-stock cases,
  100 Rust tests with Clippy, and the 65-root pure-Dart gate. The
  history benchmark retained 100 of 1,000 turns and exercised ten
  3 MiB outputs. The Linux bundle, license check, and bundled Host
  MCP, Turn and Review smoke passed. Turn interruption and both Review
  lifecycle markers were observed.
- The integrated package showed the preserved structured MCP result in
  its original dialog at 720×800 with no matching command spool.
  Installed stock and higher alpha showed the 29-byte saved command
  output, and the alpha spooled it only after Fetch. All three app,
  Host and stock process trees shut down.
- The shared bundled Host passed 3, 30 and 300 MiB streaming cases
  with repeated spool identity and bounded range reads. At 300 MiB,
  the sampled Host RSS increase was 806,912 B and Dart was 102,400 B.
  Human visual review and physical Android remain separate.

## F28 — Bounded saved MCP text and workspace index evidence

- F28A uses the local experimental `thread/items/read` route for one
  selected item in Commands or Execution. Expanded history retains the
  MCP label and one eligibility flag. The local process requests the
  stock `deferOutput.mcpToolCall` option. The modal accepts completed
  plain text with the stock content shape, verifies the returned turn
  and item identity, and limits the preview to 32 KiB of UTF-8 at a
  scalar boundary and 64 blocks. Structured, annotated, media, fenced,
  app UI, and older JSON-envelope shapes stay outside that viewer.
  The active history window permits one pending read and discards
  results for a superseded turn. The modal can close or show a retry
  state after a 15-second display deadline.
- Through the bundled Host, installed stock `0.167.0-alpha.3.2`,
  public stable `0.167.0`, Desktop-train `0.167.0-alpha.4.1`, and
  public alpha `0.169.0-alpha.7` each returned the same 14-byte saved
  fixture result. Installed stock had one inline block in the list
  response. Higher alpha returned `outputDeferred: true` with an empty
  list body and yielded the matching whole stored item after the click.
  The UTF-8 limit is a projection bound. Older inline responses and a
  selected whole-item read retain stock's transient serialization costs.
  [F26B result disclosure evidence](reverse/MCP_RESULT_DISCLOSURE_EVIDENCE.md)
- The packaged Linux UI displayed the fixture through the installed
  runtime at 1280×720 and 720×800 in Commands and Execution. Prose
  retained its filtered view. The higher alpha package displayed the
  deferred result through the same action. Both package walkthroughs
  used disposable profiles and verified app, Host and stock shutdown.
- Failure testing found a pre-existing JSON-RPC race when a reply or
  peer close arrived before a writer's flush completed. In a controlled
  baseline run, the close escaped into the Dart zone and the caller
  received a second-completion `StateError`. An early typed RPC error
  also escaped before the caller could receive it. F28A exposes the
  pending result immediately and only lets a write failure settle a
  still-registered ID. Both regression tests failed on the parent.
- A longer result produced through real alpha and the bundled Host
  yielded exactly 32,768 preview bytes. The Linux package displayed the
  truncation notice and kept scroll and Close usable at 720×800.
- A controlled child-process check through ProcessTransport delivered
  a method error and a process-exit error while the corresponding
  writer futures were held. The caller received the expected error in
  both cases and a later failed write produced no unhandled error.
- F28B measured Git listing and an app-owned directory walk on this
  repository and disposable trees. The peer correction separated
  observed exclusion on fixed trees from concurrent path safety,
  caller-side limits from child process work, and Git rules for
  tracked and untracked entries. The wide-directory fixture
  materialized 30,000 entries before the synchronous guard. A streamed
  check cancelled at 25,000 visited entries. Hard containment and
  pathological workspace resource bounds remain `RESEARCH_MORE`.
  [F28B workspace index evidence](reverse/LOCAL_WORKSPACE_INDEX_EVIDENCE.md)
- The official `agy` review cleared F28A `4b2f661` with zero open
  P0, P1 or P2 findings. The F28B owner released `b028adc` after
  correcting the evidence. Both branches were integrated with their
  original commits. The A branch passed 484 Flutter cases with five
  opt-in skips, 5/5 direct-stock cases, the 65-root pure-Dart gate,
  the bounded-history benchmark, Linux packaging, and Host-backed
  MCP, Turn and Review smoke. Rust formatting, Clippy and 100 tests
  passed on the unchanged Rust tree.

## F29 — Responsive conversation continuity and saved queue readback

- A packaged baseline at `a1f7610` lost an unsent draft when resizing
  from 1280×720 to 720×800 and back. At a constant 720×800, opening
  Threads and reselecting the same thread lost both its draft and
  pending mention. Two independent widget cases reproduced the loss.
- F29A `f7a7e67` gives the connected workspace one active conversation
  state across the 760 px breakpoint and compact navigation. The
  hidden pane is excluded from focus and tickers. Focus and
  scroll restoration check the active layout and scroll position
  readiness. Cold compact startup still opens Threads without an
  active conversation or draft.
- An interim review caught previous-thread text carrying into a
  different compact thread. The first corrective draft would also
  have removed the existing wide-layout text retention. Independent
  tests established both baselines. The final change clears the
  previous draft on a different thread while compact Threads is
  open, retains text on ordinary wide thread changes, and clears
  old thread attachments. A failed read and same-thread reselection
  preserve the draft. The committed three-file tree matched the
  corrected snapshot that passed 17 focused cases.
- F29B `e3fe91a` and `38fe116` used four stock builds through the
  bundled Host. Offset cursors skipped surviving rows after deletion
  and repeated rows after reorder. A one-row read returned about
  1.05 MB of whole stored input in the near-cap samples. Nine large
  rows fit into one response. Reading ten ended the reader at the
  default 8 MiB forward limit, and an independent connection could
  still read the queue. Loaded same-process change notifications
  carried only `threadId`. The separate cold reader refreshed by
  explicit list. The optional queue browser remains `RESEARCH_MORE`.
  [F29B queue evidence](reverse/QUEUED_SUBMISSION_READBACK_EVIDENCE.md)
- Both exact branches were read and reviewed through official `agy`.
  The queue evidence audit returned zero open findings. F29A's
  original owner corrected the compact thread-change finding and
  released the three-file write surface for integration.
- Shared `fae9f85` passed Dart format and analyze, the 65-root
  pure-Dart gate, 485 Flutter cases with five opt-in skips, five
  isolated direct-stock cases, Rust formatting and Clippy, and
  100 Rust tests. The bounded-history benchmark retained 100 of
  1,000 turns and exercised ten 3 MiB outputs. Linux packaging,
  runtime closure and licenses, and bundled Host MCP, Turn and
  Review smoke all passed.
- The shared Linux package used the same disposable saved thread
  as the baseline. At 720×800, the cold application opened Threads.
  It kept the same synthetic text and `fixture.md` mention through
  720×800 → 1280×720 → 720×800, same-thread reselection, and a second
  expansion while Threads was visible. The test compared the actual
  selected composer text in its private display and checked the
  attachment visually. The app, Host and stock process tree exited.
  Subjective interaction and physical Android remain separate gates.

## F30 — Independent ecosystem loads and plugin catalog truth

[Hosted CI 42760384522](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42760384522) passed on `033eda8`.

- At `a755915`, the shared Skills, Plugins and MCP load waited for
  every source. Three simulated runtime cases reproduced a pending
  plugin read blocking healthy sections and an RPC error leaving
  misleading empty states. In the Linux package, a test-only Host
  fault held and then failed the first `plugin/list`. Healthy stock
  Skills stayed hidden while it waited, and the Plugins tab later
  claimed “No plugins installed.” The fault was injected only for
  that list. Other list traffic went through the bundled Host to
  installed stock in a disposable profile.
- F30A isolates loading, error, empty and cached state by source.
  Pending list reads are coalesced. Same-source writes and list
  reads have a single owner until the relevant readback completes.
  The Plugins tab uses catalog language and leaves cached rows
  usable when refresh fails.
- Peer review exercised duplicate reads, failed MCP reload during
  initial load, a skill toggle against a pending list, a global
  refresh during MCP reload, and a global refresh during a skill
  toggle. Each initial fault was reproduced on the relevant draft
  and independently retested after correction. A separate probe
  confirmed that the pristine parent could show two successful
  installs and then roll the second row back when an earlier
  readback arrived last. Serial catalog mutation and readback
  addresses that parent defect and avoids a stale joined response.
- F30B `f1ab0c4` compared catalog, installed and explicit suggestion
  paths on four stock builds through the bundled Host. A clean
  empty source returned zero rows and zero errors. An invalid
  source also returned a successful RPC with zero rows and one
  `marketplaceLoadErrors` entry. A mixed response preserved three
  catalog rows and one error. The measured installed response kept
  two installed rows and the same error, and an explicit suggestion
  added the available third row. Typed Native probes on two builds
  showed that current projection drops the error. A bounded
  partial-result projection is now independently actionable.
  [F30B plugin catalog evidence](reverse/PLUGIN_CATALOG_TRUTH_EVIDENCE.md)
- The pristine parent and interim `f0c3089` each issued four total
  detail reads when three Refresh clicks overlapped one delayed
  detail read. The corrected flight held the total at two, including
  the initial expansion. The audited production tree at `0faceaf`
  matched the snapshot used for seven focused probes. The peer added
  the bounded-detail case to the repository suite and released both
  writable paths. The official `agy` review of `f1ab0c4` returned zero
  P0, P1 or P2 findings after checking the actual response evidence.
  Both histories were preserved in `f393a4f`.
- Shared `f393a4f` passed Dart format and analyze, the 65-root
  pure-Dart gate, 495 Flutter cases with five opt-in skips, and
  five isolated direct-stock tests. The Rust tree matched the
  parent and passed formatting, Clippy and 100 tests. The history
  benchmark retained 100 of 1,000 turns while exercising ten
  3 MiB outputs. Linux build, runtime bundle and license checks,
  and Host-backed MCP, Turn, Review, Runtime, Thread and Model
  smoke passed. The model responses in Turn, Review and fixture
  creation came from disposable loopback fixtures.
- The first Thread smoke attempt found no persistent row after
  copying only rollout files. A fresh, completed fixture turn
  created a visible row. Reopening under a different configured
  provider excluded it from the default stock list. Keeping the
  fixture provider for Thread smoke verified list, read, resume,
  create and cleanup. Model smoke used the default provider.
- At 1280×720, the Linux package with the same selective Host
  fixture kept real Skills and MCP visible while the first
  plugin request waited. Refreshing Skills left that single
  plugin request in flight. The Plugins tab showed loading, then
  an explicit failure. Retry issued exactly one more list request
  and rendered the 54 entries returned by installed stock in this
  fixture. A second run without fault injection rendered the
  fixture Skill, catalog and MCP server at 720×800. Both app and
  runtime process trees shut down. Human review remains open.

## F31 — Partial plugin catalogs and saved-thread provider scope

[Hosted CI 42765092016](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42765092016) passed on `8c64783`.

- F31A `e0e9f07` adds a local typed catalog snapshot. The adapter
  retains the existing bounded rows and one partial-state bit.
  A missing or empty stock error list preserves the previous
  complete-empty behavior. A nonempty list or unreadable error
  field marks the projection as potentially incomplete. The
  snapshot discards failed source paths and parser messages.
  Read-only Remote rejects the new catalog method.
- Protocol cases covered legacy responses, clean empty, invalid-only,
  mixed, malformed error shape and the existing 100-row cap. The
  simulated runtime verified that a mixed row can open details,
  the invalid-only result uses separate copy, and a healthy
  refresh clears the partial notice. Existing catalog and MCP
  lifecycle tests still passed.
- A disposable typed ProcessTransport probe through the bundled Host
  tested installed `0.167.0-alpha.3.2`, public stable `0.167.0`,
  Desktop-train `0.167.0-alpha.4.1`, and public alpha
  `0.169.0-alpha.7`. Each returned zero complete rows for a clean
  empty catalog, zero partial rows for an invalid local manifest,
  and three partial rows for a valid and invalid source. The
  available fixture's detail remained readable.
- The Linux package used normal bundled Host traffic and a
  disposable invalid marketplace manifest, with no injected
  response. Clean empty and invalid-only had different presentation
  at 1280×720. An independent valid home marketplace supplied three
  rows while the workspace manifest failed. At 720×800, the warning
  remained visible and a valid row opened Details. Repairing the
  invalid manifest and refreshing removed the warning in the same
  dialog. The test-owned process trees exited.
- F31B `05a6aee`, `4c12f61` and `0033969` compared four
  stock builds, current public source and the installed Desktop
  bundle. Native omits the provider filter, so ordinary stock
  lists, Section rows and saved search use the configured default
  provider. The measured Desktop uses different scopes for its
  recent list, saved search and storage/section paths.
- Explicit all-provider discovery returned the synthetic rows.
  Older measured stock rejected cross-provider cold resume.
  Public alpha `0.169.0-alpha.7` could resume with the recorded
  provider still configured. Independent fresh-process checks
  reproduced cold override rejection and a successful loaded
  repeat that retained the recorded provider. A peer correction
  separated these two results after comparing the first table
  with its actual response log.
- On stock builds that expose `currentAccountOnly`, a locally
  marked fixture disappeared from account-free discovery while
  its direct ID read still succeeded. Older measured schemas
  lacked the field. The owner corrected the document to limit
  the claim to measured discovery and direct read. Response
  paging retained its measured cap. Server-side refill can scan
  beyond that returned page. No account login or production
  provider was involved. Cross-provider discovery stays
  `RESEARCH_MORE` pending a deliberate scope and resume policy.
  [F31B provider scope evidence](reverse/THREAD_PROVIDER_SCOPE_EVIDENCE.md)
- The official `agy` audit of `e0e9f07` returned zero P0, P1 or
  P2 findings. The F31B owner corrected the cold/warm,
  direct-read, and server-scan findings in ordinary commits and
  released its single document. Both histories were integrated
  in `a497fb5`.
- Shared `a497fb5` passed Dart format and analyze, the 65-root
  pure-Dart gate, 497 Flutter cases with five opt-in skips, all
  five isolated direct-stock cases, and the bounded-history
  benchmark. The identical Rust tree passed formatting, Clippy
  and 100 tests. Linux packaging, runtime and license checks, and
  the bundled Host Runtime, Thread, Model, MCP, Turn and Review
  smoke paths passed. Shared packaged screenshots verified the
  clean, invalid-only, repaired and mixed detail states at
  1280×720 and 720×800. The test-owned app, Host and stock trees
  exited. Subjective UI and physical Android remain separate.

## F32 — Installed plugin scope and compact resume failure feedback

- F32A `3d38a8b` measured stable catalog and installed
  requests through the bundled Host on four stock builds.
  A 131-row home and workspace catalog placed the workspace
  installed plugin at offset 128. Native retained 100 rows on
  installed stock and public alpha. Its Linux package displayed
  that retained count at 1280×720 and 720×800.
- Independent fresh profiles separated startup from query
  effects. Each sampled default or explicit-local catalog
  request materialized a configured local plugin cache even
  with `forceRefetch` omitted. The first returned row still
  said it was uninstalled. The isolated installed queries did
  not change the sampled config or manifests. Public source
  conditionally schedules authenticated bundle sync for both
  routes. Those authenticated paths were outside the probe.
- A distinct installed inventory stays `RESEARCH_MORE` for
  its effects and lack of upstream pagination. Reporting the
  existing bounded catalog's truncation can proceed separately.
  [F32A installed inventory evidence](reverse/PLUGIN_INSTALLED_SCOPE_EVIDENCE.md)
- Two independent simulated 720×800 cases used the actual
  exception shape for an implicit cold resume and a pending
  queue's explicit Resume action. Both retained the draft and
  started zero turns. The failure was visible only after
  opening Threads.
- A separate normal-path Linux walkthrough opened a disposable
  saved thread through the real bundled Host and installed
  stock. Moving that test rollout aside caused stock to return
  `-32600` on resume. The draft and loaded conversation stayed
  visible. The failure appeared on compact Threads after
  navigation. The original file was restored and the test
  processes exited. This exercised a deliberately induced
  missing-rollout failure. Provider-specific discovery and
  resume remain distinct.
- F32B `0b7a7f0` and `28e9566` mapped the measured Desktop's
  reason-specific provider block, local stock resume and read
  behavior, and Native error presentation. The audit separated
  experimental queue RPCs, current configured-provider discovery,
  specific loaded-thread policy checks, and local error transport.
  A generic conversation-visible resume failure is independently
  actionable. Provider-specific gating and broader discovery
  remain separate.
  [F32B provider resume presentation evidence](reverse/THREAD_PROVIDER_RESUME_PRESENTATION_EVIDENCE.md)
- Official `agy` review approved `3d38a8b` with zero open P0,
  P1 or P2 findings. The original B owner corrected its two P1
  and two P2 evidence findings in an ordinary commit and released
  its only document. Both histories were integrated at `6d96df3`.
- Product, test, tool, Rust and workflow trees matched `8c64783`.
  The identical source passed Dart format and analyze, the
  65-root pure-Dart gate, 497 Flutter cases with five opt-in
  skips, five isolated direct-stock cases, 100 Rust tests,
  formatting and Clippy, and the bounded-history benchmark.
  Linux bundle closure and license checks passed on the reused
  exact product build. The two packaged research walkthroughs
  and simulated failure probes were verified separately.

## Desktop structural reconvergence

- R0 refreshed the installed build `25894` ASAR and CSS. The static renderer
  contains legacy, rail-only and rail-with-contextual-sidebar branches. A
  current signed-in user screenshot confirms the contextual branch in that
  session. An isolated official launch reached sign-in. The screenshot's DPR,
  zoom and sidebar preference are unknown. The project stores anonymous
  measurements and component paths. [Structural map](reverse/OFFICIAL_UI_STRUCTURAL_MAPPING.md)
- R1–R4 translated the wide shell, sidebar and header hierarchy, inline
  activity, bottom change disclosure and active composer. Native fixture
  screenshots compare the former and current shells and exercise a real Git
  change through the bundled Host and stock process. The Responses model
  was a local fixture. The timeline, bounded diff and lazy output continue
  through their existing controllers.
- R5 reproduced a cold saved-thread `review/start` failure in the packaged
  client. Both entry points now apply the existing queue admission before
  implicitly loading an eligible cold thread. Pending or inconclusive queue
  reads require explicit resume and a fresh Review action. The packaged cold
  working-tree review completed through stock after the fix.
- R6 reproduced and fixed a narrow activity row overflow at a 760 px split
  with the sidebar fully expanded. Packaged resize exercises retained the
  selected conversation and draft through compact mode. Native uses its
  existing compact navigation until the official signed-in compact state is
  observed. Signed-in open secondary surfaces and dark mode are separate
  evidence gates.
- The official `agy` peer review found two P1 issues. The diff viewer could
  lose its return action after an empty update, and a tight split with multiple
  linked PRs could overflow the header. `73f48f3` retains the return action,
  bounds the change summary and keeps linked PRs reachable via an icon and a
  bounded popover. Both paths passed simulated runtime regression coverage.

## Desktop interaction follow-up

- A 760 px split with a 520 px left area previously hid the composer model
  and reasoning entry point. `fd4ebe1` keeps an icon trigger at tight widths,
  separates the draft from the controls where necessary, and retains the
  input field across layout changes. The regression exercises focus, draft,
  model settings, steer and Stop. The Linux bundle opened model and reasoning
  settings at the tight split, retained the draft and interrupted a turn
  through the bundled Host and stock with a local model fixture.
- The existing menu primitives handled activation keys but Arrow Up and Arrow
  Down selected no item. `8b6c617` scopes traversal to the opened menu, skips
  disabled items and wraps. The packaged Linux View menu hid the sidebar and
  then opened focused thread search using arrow keys and Enter.
- Opening Changes unmounted the timeline and returning started at the newest
  content. `0023e11` records the existing bounded history bookmark before the
  switch and restores it by content identity on return. The regression
  reproduces the missing older row, then verifies position recovery without
  an additional history page request.
- Official `agy` peer inspection identified two current build `25894` shell
  contracts. The independent readback confirmed the resize coordinator in
  `961657.97fdcc5e7d.js` around memo entries `tl[98]–tl[104]`. It checks
  workspace widths at 960 and 720 and a window width at 720, then changes
  the pane state under several conditions. Module `DUYS` in
  `182735.5b42af8792.js` bounds the right pane to a 320 px minimum and
  leaves a 352 px chat reserve in its regular split mode. It uses a 600 px
  fallback and separately adjusts the default against main width and shell
  height. Those are static shell contracts. The measured values alone do not
  establish the diff tab registration or the state used by the signed-in
  Codex window.

## Desktop secondary surface follow-up

- Further inspection found the exact registration in build `25894`.
  `176566.bc2de94faa.js` module `T8jz` exports the review side-panel open and
  toggle actions. It registers the `DIFF` tab under `thread.sidePanel.diffTab`
  and defaults the target to `right`. Related modules occur in
  `244287.bc1007d00d.js` and `32819.1aa51e75d6.js`. This ties Changes to the
  task side pane in static evidence. It does not determine the active user's
  layout at the narrow boundary.
- `155ea2f` uses the measured right-pane sizing roles above a 960 px workspace
  and keeps Native's replacement view below that threshold. Both paths use
  the same selected-file and virtualized diff projection. A disposable
  Linux walkthrough opened the side pane on an actual Git change from
  `three` to `four` through bundled Host and stock. A first fixture kept the
  saved thread's read-only sandbox and the write was rejected. Re-seeding
  with workspace-write allowed the controlled patch. The peer raised a
  possible reading-position loss on width transition. `bcd3245` verifies
  the visible item and vertical alignment after scrolling inside the wide
  split, going narrow and returning wide, with no extra history page fetch.
- The first short-question correction reproduced a 196 px overflow in the
  820×420 simulated case. A normal-entry stock walkthrough with the
  experimental `default_mode_request_user_input` enabled only in its
  disposable profile still showed 19 px of overflow when a model warning
  was present. `515d283` lets the card take the actual space available after
  fixed controls and scrolls its content. A second packaged walkthrough kept
  the warning, question actions and composer visible at 820×420, scrolled to
  a free-form answer and confirmed the answer reached the stock tool call.

## Desktop short-window request stack

- A simulated approval at 760×420 with the sidebar at its maximum reproduced
  unreachable decisions for a long file list, including horizontal overflow
  in the action row. `fb866dd` makes the details independently scrollable and
  constrains the two decisions to the available width. The empty-thread
  illustration also scrolls when requests leave it very little height. A
  Linux bundle with stock and a disposable loopback model requested command
  approval. After scrolling the details, Reject returned the denial through
  stock. The fixture command was never executed.
- A turn-scoped MCP form with nine fields exceeded the 820×420 viewport by
  244 px before `061f0da`. The form body now shares the actual available height
  while retaining its field cap and independent actions. The packaged app
  accepted the consent for a disposable local echo tool, scrolled its longer
  form and declined it. The stock tool result carried the decline.
- When approval and question arrive concurrently, the fixed chrome of two
  separate cards can exceed their height shares. `5769e31` puts both in one
  bounded scroll region for a short viewport. Stable widget identities retain
  the in-progress answer across entry to and exit from that region. Simulated
  runtime verified rejecting one request and then submitting the preserved
  answer at 760×420. The single-request paths were exercised separately in the
  packaged app.
- Previously a cold target chooser collected the review target before detecting
  that queued work required explicit resume. `aaecb40` checks before opening
  the chooser. When the first check finds no queue, the review entry still
  checks again at submission so a queue that appeared while the chooser was
  open receives the same explicit confirmation. Simulated runtime verifies
  both the early and late queue cases and zero review dispatch on resume alone.
  A cold unqueued thread in the packaged Linux app opened the target chooser
  and completed a working-tree review through stock after explicit submit.
  Strict analysis required the explicit post-await mount guard in `d816aae`.
- A Linux bundle rendered the same saved thread with the Native dark palette
  at 1191×865 and 720×800 after reading `prefer-dark` from an isolated desktop
  appearance portal fixture. A GTK preference file alone left the same
  Xvfb setup in light mode. This exercises Native's system theme selection
  with a controlled OS setting. Signed-in official dark comparison remains
  open.
- At 360×420 and 200% text scale, the simulated output viewer reproduced
  clipped page actions and a displaced code viewport. The activity disclosure
  also overflowed horizontally. The output notice now scrolls within a capped
  area, the actions wrap, and the log rows follow the text scale while keeping
  the same bounded byte reads. The regression test opens truncated output,
  changes its byte window, and closes it at that size. The Linux bundle read
  the 200% preference from isolated GSettings, displayed a saved stock command
  output at 360×420, and closed the dialog. The stock fixture's output fit in
  a single byte window.

## Desktop inline command output

- Installed renderer build `25894`, chunk `225284.63835849b6.js`, starts the
  command disclosure collapsed. Its `hideRawCommand` path removes the toggle.
  The expanded command body uses the chunk's `PuGl` shell module. The command
  header, output scroller, and exit footer appear inline. The stylesheet
  resolves the scroller cap to `9rem`. This is static evidence for the available
  branch. Its current signed-in visibility still needs comparison.
- The live output-delta path in `182735.5b42af8792.js` retains a 20,000-character
  tail on the sampled branch. A separate direct-stock probe on the installed
  binary returned 65,536 bytes for the long disposable command under both
  `deferOutput` settings. Those are different boundaries. Native can translate
  the disclosure with a single small Host tail read and keep the paged viewer
  for the full stored output. The presentation must release the preview with
  its turn and ignore an outstanding read after selection changes.
- Native Desktop Commands and Execution use a collapsed command disclosure
  in opened saved-turn details. Expansion makes one 4 KiB tail request and
  shows a scroll region capped at 144 logical px. A second expansion replaces
  the first. Collapse, turn or thread selection changes, and entry to Prose
  release the preview. A pending read remains single-flight after collapse.
  The complete stored output opens in the existing paged dialog. Compact
  layout retains direct dialog access.
- The packaged Linux client, bundled Host and stock app-server reopened a
  disposable saved command at 760×800 with the sidebar at its 520 px maximum.
  The preview displayed the last 4,096 stored bytes. The full viewer reported
  65,536 stored bytes and showed the start marker. Closing the dialog restored
  the still-expanded preview. An initial labeled disclosure clipped at that
  width. The final chevron retains its accessible action name and leaves more
  room for the command summary.

### Completed commands in the active conversation

- On the same installed stock build, a fresh isolated Linux Host session
  received command `item/completed` notifications with file-backed descriptors
  for 179,835 and 21 bytes. The aggregate field was empty on both forwarded
  items. Explicit Host tail reads returned 4,096 and 21 bytes. The saved
  history probe for the long fixture returned 65,536 bytes. These measured
  payload sizes describe two different stock paths.
- Native previously projected command lifecycle notifications to summary and
  status. The bundled Host path now projects the optional completed-command
  descriptor into the existing bounded activity entry and uses the paged
  viewer. The pure stock and Remote adapters ignore the Host extension.
  Invalid optional metadata leaves the command summary available. Output
  deltas and stock inline output remain outside this projection.
- In a packaged Linux walkthrough with the real Host and stock app-server,
  a disposable loopback model paused after the command completed. While the
  turn was still active, View output opened at byte 114,299 of 179,835. First
  opened byte zero and displayed the command's start marker. The dialog was
  dismissed and the fixture then finished the turn. Unit and widget tests
  cover the adapter boundary and zero output or saved-item reads before the
  user opens the viewer.
- The Desktop release bundle now uses the same collapsed disclosure for
  completed live commands and opened saved-turn details. Both sources
  share one 4 KiB preview and one in-flight preview read. Commands mode
  releases the live preview when a newer activity hides its row. A late
  response cannot reopen that preview, and compact windows keep direct
  paged access. The Linux release bundle showed the 4,096-byte preview and
  opened byte 114,299 and byte zero of the same 179,835-byte spool while
  the fixture still held the assistant turn open.

## Desktop Home project control

- Installed build `25894` separates Codex Home with its project-sensitive
  hero and interactive project control from the new-thread placeholder.
  [Component evidence](reverse/OFFICIAL_UI_STRUCTURAL_MAPPING.md#current-official-evidence)
  identifies the shipped modules. Signed-in layout and compact placement
  still need the matching captures.
- Native Home's local project chooser now participates in keyboard focus
  traversal and shows a focus ring. The directory dialog retains its
  existing trim and cancel behavior. In the Linux release bundle, Shift+Tab
  focused the project from the composer, Space opened the chooser, and
  submitting a second disposable directory preserved the draft. Simulated
  Enter activates the selector. Return did not open it in the Xvfb run.
- The Home regression exercised a 760×800 window at 200% text scale. The
  prior control row overflowed by 68 px. The project control now grows
  with its label, and the composer switches to icon controls based on
  text scale as well as width. Both model and execution controls remain
  hit-testable in that fixture.

## Desktop primary visual parity checkpoint

The current comparison pairs the user-supplied 1191×865 signed-in official
reference with a 1191×865 Native Linux release walkthrough. The Native
walkthrough used the bundled Host and stock app-server with a disposable
loopback model. It captured read/run activity, a paused stock goal and a
pending request together, then opened goal management and submitted a
choice. The official reference uses a free-text question and has unknown
zoom and saved panel width. The installed renderer `25894` supplies the
logical dimensions and component variants. The exact source claims, paired
Native evidence and remaining signed-in comparison gates are recorded in
the [wide Desktop mapping](reverse/OFFICIAL_UI_STRUCTURAL_MAPPING.md#wide-desktop-visual-parity-ranking).

The [Golden State A contract](reverse/OFFICIAL_UI_GOLDEN_STATE_A.md) tracks
current reconstruction. Its A11 evidence distinguishes the shipped model
picker from stock model and reasoning overrides. A real Linux release
round trip showed that the catalog default can differ from the model
resolved by config, and clearing overrides lets an existing stock session
retain its model and effort. The composer now discloses that inheritance.
