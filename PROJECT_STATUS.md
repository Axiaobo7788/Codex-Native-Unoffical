# Project Status

**Program mode: `SELF_ITERATION`**
**Current phase: Official Client Convergence.**

Use this page for current facts, [the feature matrix](docs/reverse/OFFICIAL_FEATURE_MATRIX.md) for the living queue, [Architecture](docs/ARCHITECTURE.md) for system boundaries, and [Decisions](docs/DECISIONS.md) for ADRs. Earlier status narratives and negative evidence are preserved in [the pre-consolidation archive](docs/history/PROJECT_STATUS_through_F14.md).

## Current checkpoint

- Integration baseline: `f8de0e9a9057a26ee3a23f85582b4a1d737c99d4` (F13/F14). [Hosted CI 42541433565](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42541433565) passed on that SHA. The user resumed execution after that checkpoint.
- Third-party consolidation landed at `a64b8e7`. [Hosted CI 42648632704](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42648632704) passed on that SHA. See [findings](docs/RESEARCH.md#third-party-consolidation).
- The current F15 peer round integrates local Goal lifecycle (`62378e4`, `fba3c07`) and the Desktop Review target picker (`79c21fb`, `5ad65c7`). See [fresh evidence and peer boundaries](docs/RESEARCH.md#convergence-refresh-after-consolidation).

## Current product and architecture

- Desktop uses the bundled Rust `codex-native-host` and stock `codex app-server`. The local workflow includes thread management, turn streaming and steering, approvals, model and execution controls, bounded diff/output, uncommitted-change review, and supported Skills/Plugins/Apps/MCP administration. Availability can depend on installed stock version, configuration and account.
- The native desktop theme uses a 260 logical px default sidebar, a 704 px maximum reading/composer column, and a 760 px narrow-layout breakpoint. `OfficialCodexTheme` owns shared geometry and colors. The Flutter theme adapts those roles.
- Codex is the only wired product. Prose, Commands and Execution are timeline detail choices. The internal Work and Chat capability profiles and backend interfaces are compatibility seams. Independent ChatGPT Chat, Work orchestration and Responses backends are absent.
- App-server owns persisted conversation state. Flutter retains bounded thread/history/active-turn projections, virtualizes lists, coalesces streaming, evicts inactive history, and lazily loads bounded output and diffs. Host spooling keeps large command payloads off the Flutter heap. Stock `deferOutput` did not defer the sampled command output. Experimental `thread/items/read` remains a whole-item fallback.
- Sections group the bounded global thread working set. The catalog is capped at 64 and counts describe loaded rows. Stock `section_position` paging is confirmed in a disposable profile. Native ordered per-section browsing is in the living queue.
- Local Goal actions load the selected thread’s persisted goal on demand and support explicit paused creation, objective changes, pause/resume, and confirmed clear. Stock owns continuation. Desktop Review offers working-tree, base-branch, commit/ref, and custom targets through stock `review/start`.
- Direct Host Remote is read-only. The transport allows bounded model/thread metadata and history reads and sequenced lifecycle projection. Android currently presents pairing, connection recovery and model/thread metadata. Thread/turn writes, approvals, diffs, and command-output reads remain outside the Remote contract. Official Remote support is experimental host-side control through stock schema. There is no Native mobile client for the official relay.

## Verification and pending gates

- Integrated F15 validation passed 403 default Flutter cases with four explicit opt-in skips, 4/4 isolated direct stock cases, 98 Rust tests, the pure-Dart gate, the history benchmark, and the Linux bundle check. The packaged Linux shell connected and its Host child exited. All four Host-backed Review targets reached terminal completion with enter/exit markers. See Research for the direct stock, packaged-app, and Human evidence boundaries.
- F13/F14 baseline: 395 Flutter test cases, 98 Rust tests, bounded-history benchmark, Linux build, and Host-backed uncommitted review smoke passed. The packaged Linux UI connected and rendered thread groups, a Git badge and the composer. GTK emitted an ATK embed and cursor-theme warning. Natural goal notifications and a populated real section catalog were unobserved.
- `HUMAN_REVIEW_PENDING`: desktop visual fidelity and interaction feel, including sections, composer and approval/diff/output/review interactions. Physical Android TLS/Keystore, camera and cross-network pairing remain separate device gates.
- No program-level blocker is recorded. Next machine-actionable candidates and support boundaries are in the [living queue](docs/reverse/OFFICIAL_FEATURE_MATRIX.md#36-active-queue-after-consolidation). Use the official `agy` TUI to coordinate ownership after integration validation.
