# Project Status

**Program mode: `SELF_ITERATION`**
**Current phase: Official Client Convergence.**

Use this page for current facts, [the feature matrix](docs/reverse/OFFICIAL_FEATURE_MATRIX.md) for the living queue, [Architecture](docs/ARCHITECTURE.md) for system boundaries, and [Decisions](docs/DECISIONS.md) for ADRs. Earlier status narratives and negative evidence are preserved in [the pre-consolidation archive](docs/history/PROJECT_STATUS_through_F14.md).

## Current checkpoint

- Third-party consolidation landed at `a64b8e7`. [Hosted CI 42648632704](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42648632704) passed on that SHA. See [findings](docs/RESEARCH.md#third-party-consolidation).
- F15 integrated local Goal lifecycle and the Desktop Review target picker. [Hosted CI 42655808877](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/42655808877) passed on `f70a210`. See [runtime evidence](docs/RESEARCH.md#convergence-refresh-after-consolidation).
- F16 integrates stock-ordered local Section browsing and [stored thread attachment evidence](docs/reverse/THREAD_ATTACHMENT_EVIDENCE.md) at `ab268ed`.

## Current product and architecture

- Desktop uses the bundled Rust `codex-native-host` and stock `codex app-server`. The local workflow includes thread management, turn streaming and steering, approvals, model and execution controls, bounded diff/output, stock review, and supported Skills/Plugins/Apps/MCP administration. Availability can depend on installed stock version, configuration and account.
- The native desktop theme uses a 260 logical px default sidebar, a 704 px maximum reading/composer column, and a 760 px narrow-layout breakpoint. `OfficialCodexTheme` owns shared geometry and colors. The Flutter theme adapts those roles.
- Codex is the only wired product. Prose, Commands and Execution are timeline detail choices. The internal Work and Chat capability profiles and backend interfaces are compatibility seams. Independent ChatGPT Chat, Work orchestration and Responses backends are absent.
- App-server owns persisted conversation state. Flutter retains bounded thread/history/active-turn projections, virtualizes lists, coalesces streaming, evicts inactive history, and lazily loads bounded output and diffs. Host spooling keeps large command payloads off the Flutter heap. Stock `deferOutput` did not defer the sampled command output. Experimental `thread/items/read` remains a whole-item fallback.
- The global sidebar groups loaded threads. Browse a local Section to page through stock order with the same 100-thread working-set cap. Section definitions remain capped at 64. Switching scopes can preserve the active conversation outside the list.
- Local Goal actions load the selected thread’s persisted goal on demand and support explicit paused creation, objective changes, pause/resume, and confirmed clear. Stock owns continuation. Desktop Review offers working-tree, base-branch, commit/ref, and custom targets through stock `review/start`.
- Direct Host Remote is read-only. The transport allows bounded model/thread metadata and history reads and sequenced lifecycle projection. Android currently presents pairing, connection recovery and model/thread metadata. Thread/turn writes, approvals, diffs, and command-output reads remain outside the Remote contract. Official Remote support is experimental host-side control through stock schema. There is no Native mobile client for the official relay.

## Verification and pending gates

- F16 passed 409 default Flutter cases with five explicit opt-in skips, 5/5 isolated direct stock cases, 98 Rust tests, the pure-Dart gate, bounded-history benchmark, and Linux debug build. The packaged Linux walkthrough browsed two pages of a 26-row Section, selected row 26, and preserved it on return to the global list. App, Host and stock process exit was verified. See [F16 evidence](docs/RESEARCH.md#f16-scoped-sections-and-stored-attachment-evidence).
- F15 verified terminal completion and matching enter/exit markers for all four Host-backed Review targets. The separate local Goal test used paused state. See [F15 evidence](docs/RESEARCH.md#integrated-f15-verification).
- `HUMAN_REVIEW_PENDING`: desktop visual fidelity and interaction feel, including sections, composer and approval/diff/output/review interactions. Physical Android TLS/Keystore, camera and cross-network pairing remain separate device gates.
- No program-level blocker is recorded. Next machine-actionable candidates and support boundaries are in the [living queue](docs/reverse/OFFICIAL_FEATURE_MATRIX.md#36-active-queue-after-consolidation). Use the official `agy` TUI to coordinate ownership after integration validation.
