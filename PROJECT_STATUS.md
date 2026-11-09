# Project Status

**Program mode: `SELF_ITERATION`**
**Current phase: Official Client Convergence.**

Use this page for current facts, [the feature matrix](docs/reverse/OFFICIAL_FEATURE_MATRIX.md) for the living queue, [Architecture](docs/ARCHITECTURE.md) for system boundaries, and [Decisions](docs/DECISIONS.md) for ADRs. Earlier status narratives and negative evidence are preserved in [the pre-consolidation archive](docs/history/PROJECT_STATUS_through_F14.md).

## Current checkpoint

- Integration baseline: `f8de0e9a9057a26ee3a23f85582b4a1d737c99d4` (F13/F14). [Hosted CI 42541433565](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42541433565) passed on that SHA. The user resumed execution after that checkpoint.
- Consolidation is the current integration checkpoint. See [the findings and verification](docs/RESEARCH.md#third-party-consolidation). Hosted CI evidence is tied to the published SHA.

## Current product and architecture

- Desktop uses the bundled Rust `codex-native-host` and stock `codex app-server`. The local workflow includes thread management, turn streaming and steering, approvals, model and execution controls, bounded diff/output, uncommitted-change review, and supported Skills/Plugins/Apps/MCP administration. Availability can depend on installed stock version, configuration and account.
- The native desktop theme uses a 260 logical px default sidebar, a 704 px maximum reading/composer column, and a 760 px narrow-layout breakpoint. `OfficialCodexTheme` owns shared geometry and colors. The Flutter theme adapts those roles.
- Codex is the only wired product. Prose, Commands and Execution are timeline detail choices. The internal Work and Chat capability profiles and backend interfaces are compatibility seams. Independent ChatGPT Chat, Work orchestration and Responses backends are absent.
- App-server owns persisted conversation state. Flutter retains bounded thread/history/active-turn projections, virtualizes lists, coalesces streaming, evicts inactive history, and lazily loads bounded output and diffs. Host spooling keeps large command payloads off the Flutter heap. Stock `deferOutput` did not defer the sampled command output. Experimental `thread/items/read` remains a whole-item fallback.
- F13 sections group the bounded global thread working set. The section catalog is capped at 64. Sidebar counts describe loaded rows. Authoritative per-section `section_position` ordering and pagination remain unverified. F14 exposes only **Review uncommitted changes**. The other three targets have serialization coverage.
- Direct Host Remote is read-only. The transport allows bounded model/thread metadata and history reads and sequenced lifecycle projection. Android currently presents pairing, connection recovery and model/thread metadata. Thread/turn writes, approvals, diffs, and command-output reads remain outside the Remote contract. Official Remote support is experimental host-side control through stock schema. There is no Native mobile client for the official relay.

## Verification and pending gates

- Consolidation passed 395 default Flutter cases with three explicit opt-in skips, 3/3 isolated direct stock cases, 98 Rust tests, the pure-Dart architecture gate, the bounded-history benchmark and the Linux debug build. Host-backed runtime/thread/model/uncommitted-review smokes passed. The packaged Linux shell connected in a clean profile and the Host child exited. See the research record for the ATK warning and verification scope.
- F13/F14 baseline: 395 Flutter test cases, 98 Rust tests, bounded-history benchmark, Linux build, and Host-backed uncommitted review smoke passed. The packaged Linux UI connected and rendered thread groups, a Git badge and the composer. GTK emitted an ATK embed and cursor-theme warning. Natural goal notifications and a populated real section catalog were unobserved.
- `HUMAN_REVIEW_PENDING`: desktop visual fidelity and interaction feel, including sections, composer and approval/diff/output/review interactions. Physical Android TLS/Keystore, camera and cross-network pairing remain separate device gates.
- No program-level blocker is recorded. Active research and next-slice ownership live in the [feature matrix](docs/reverse/OFFICIAL_FEATURE_MATRIX.md). After validating consolidation, refresh stock/Desktop/Android evidence and coordinate the next independent slices through the official `agy` TUI.
