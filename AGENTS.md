# AGENTS.md

## Repository memory

Before starting any non-trivial task:

1. Read `PROJECT_STATUS.md` for the current phase, completed work, blockers, and next action.
2. Read `docs/DECISIONS.md` for accepted architecture decisions.
3. Read `docs/ARCHITECTURE.md` when the task touches system boundaries, transports, memory behavior, or remote design.

Before finishing any task that materially changes the repository:

- Update `PROJECT_STATUS.md` with what changed, current status, new blockers, and the next recommended action.
- If you make or reverse a durable architecture/product decision, append an ADR entry to `docs/DECISIONS.md`.
- Keep status factual. Do not mark work complete unless it is implemented and, where applicable, tested.
- Include the relevant commit/test result in the status entry when useful.

## Operating modes

Every non-trivial task has one explicit **program-level** operating mode. Read
the current mode from `PROJECT_STATUS.md` before starting. Individual slices
may additionally be marked `HUMAN_REVIEW_PENDING` without changing the larger
program out of `SELF_ITERATION`. If the status file does not name a mode, do
not guess from an old completion marker; treat the latest explicit user
instruction as authoritative and update the status file.

### `SELF_ITERATION`

This is the default mode inside an already authorized phase.

In `SELF_ITERATION`, continue autonomously through the highest-value work that
is still inside the authorized phase:

1. inspect the current repository and upstream/reference evidence;
2. research unknowns that materially affect the task;
3. implement or refine the scoped work;
4. run the strongest practical machine validation;
5. exercise the real product/runtime when that is locally possible;
6. fix regressions found by those checks;
7. update durable project memory and ADRs when needed;
8. commit coherent slices normally; then continue to the next scoped item.

Do **not** stop merely because one commit, issue, test suite, document, CI run,
or local milestone is complete. Do not repeatedly ask whether to continue when
the next action is implied by the authorized phase and can be answered from
source, tests, experiments, benchmarks, live inspection, repository history, or
public/reference evidence.

`SELF_ITERATION` is not permission to expand scope indefinitely. It does not
authorize a new product phase, destructive user-data action, release/signing
decision, production/private-API dependency, or unrelated infrastructure work.

### `HUMAN_REVIEW`

Human review is **slice-scoped by default, not program-scoped**.

Mark an individual slice `HUMAN_REVIEW_PENDING` when a material question
cannot be reliably resolved by machine/agent evidence, including:

- subjective product quality, visual fidelity, interaction feel, or long-session
  usability that genuinely requires a person;
- physical-device/platform behavior unavailable to the current environment;
- a high-impact or irreversible choice that requires explicit user approval;
- multiple technically valid product directions where user preference is the
  deciding constraint.

When one slice reaches `HUMAN_REVIEW_PENDING`:

- freeze further **subjective** changes to that slice unless a test, clear defect,
  or new objective evidence requires correction;
- keep the overall authorized program in `SELF_ITERATION`;
- continue every independent machine-actionable slice that does not depend on
  the pending Human decision;
- select the next highest-priority independent item from the active roadmap,
  feature matrix, or status file and proceed without asking whether to continue.

Switch the **whole project** to `HUMAN_REVIEW` only when:

- every remaining authorized material task is genuinely blocked by Human input;
  or
- the user explicitly instructs the agent to pause for review.

A successful milestone, commit, test suite, CI run, Victory Auditor approval, or
`HUMAN_REVIEW_PENDING` slice is **not** a stop condition for the larger
authorized program.

Before switching the whole program from `SELF_ITERATION` to `HUMAN_REVIEW`,
exhaust the reasonable independent machine-actionable work within scope. "It
would be nice for the user to look at this" is not by itself a stop condition.

Human feedback is new high-priority evidence. Unless the user explicitly asks
to remain paused, a reported defect/rejection automatically returns the affected
authorized slice to active `SELF_ITERATION`: diagnose, fix, regression-test,
exercise the real path, update project memory, and continue.

### Blocking, permission, and decision rules

Do not let a routine permission gate or reversible engineering choice silently
stall a long-running `SELF_ITERATION` program.

- Resolve ordinary reversible implementation choices autonomously from source,
  tests, measurements, architecture rules, and existing ADRs.
- Do not stop to ask the user to choose between multiple safe, reversible
  technical approaches when one can be selected on engineering evidence.
- If several permission-sensitive operations are foreseeable, batch or surface
  them as early as practical rather than discovering them hours into execution.
- If one optional operation is blocked on permission or unavailable tooling,
  continue all independent unblocked work first.
- Stop for a permission only when that permission is genuinely on the critical
  path for **all** remaining authorized material work.
- Destructive user-data operations, force-push/history rewriting, credential or
  account-security actions, releases/signing, production/private-API
  dependencies, and other irreversible/high-impact actions still require the
  appropriate Human authorization.
- Never reinterpret a completed subagent/teamwork milestone as permission to
  idle. Integrate its result, update durable status, and continue to the next
  authorized independent slice.

### Dual-agent peer collaboration: Codex CLI + Antigravity/Gemini

Codex and Antigravity/Gemini are **peer engineering agents**. Neither is the
permanent manager, implementer, reviewer, or final authority over the other.
Task ownership follows current evidence, context, and comparative strength rather
than a fixed hierarchy.

Read `docs/AGENT_COLLABORATION.md` before starting work that is intended to run
in parallel with, hand off to, or review work from the other agent.

Default specialization is a routing hint, not an exclusive boundary:

- **Antigravity/Gemini preferred**: visual/UI fidelity, live renderer/DevTools
  inspection, screenshot comparison, interaction polish, ASAR/APK exploratory
  reverse research, component-system work, and mobile presentation.
- **Codex preferred**: architecture boundaries, app-server/protocol work, Rust
  Host/transport, concurrency, bounded-memory behavior, complex state machines,
  regression hardening, CI/release engineering, and final code-consistency
  audits.
- **Either agent** may own shared domain/features, tests, documentation, or any
  other slice when it currently has the better context. Do not duplicate the
  same implementation merely to compare agents.

Parallel work rules:

- Use separate Git worktrees/branches for independent writable slices.
- Maintain **one writer per overlapping file surface**. The other agent may
  inspect/review that work but must not concurrently edit the same files.
- Prefer small coherent commits that the peer can inspect, cherry-pick, or
  integrate without reconstructing chat history.
- If two slices begin to overlap, pause only the overlapping write surface;
  continue independent work elsewhere.
- Do not force-push or rewrite the peer's history. Integrate through ordinary
  commits/merges/cherry-picks according to the current branch strategy.
- Peer review is targeted, not ceremonial: require it for cross-cutting
  architecture/protocol/security/memory changes, public component API changes,
  or evidence-sensitive reverse conclusions. Routine isolated changes do not
  require a second agent merely for formality.

Context and handoff discipline:

- Repository state, commits, ADRs, tests, and measured evidence outrank either
  agent's conversational memory.
- After a long run, Teamwork/subagent return, or handoff, re-anchor by reading
  the current task packet, `PROJECT_STATUS.md`, relevant ADRs, current diff,
  and touched source files before making new claims.
- Especially for Antigravity/Gemini, do not rely on a very long accumulated
  conversation as the sole source of truth. Break work into bounded slices and
  refresh repository evidence between slices.
- Before handing a slice to the peer, provide a compact handoff containing:
  current HEAD/commits, goal, changed files, verified behavior, tests run,
  unresolved risks, evidence level, and the exact next useful action.
- A peer should **review the existing implementation**, not automatically redo
  it from scratch.

Disagreement resolution:

1. latest explicit user instruction;
2. non-negotiable repository rules and accepted ADRs;
3. public/supported schema or reproducible live behavior;
4. tests, benchmarks, traces, and minimal repros;
5. calibrated static reverse evidence;
6. inference/model preference.

When agents disagree, neither wins by identity. Resolve the claim with stronger
evidence. For a safe reversible choice where evidence is still tied, choose a
reasonable option, record the rationale, and continue rather than blocking the
program.

### Evidence labels and completion claims

Keep these evidence classes distinct:

- **MACHINE VERIFIED** — static analysis, unit/widget/integration tests,
  benchmarks, builds, automated protocol/screenshot checks.
- **AGENT REAL-USE VERIFIED** — the real application/runtime was launched and
  exercised against realistic data by the agent. This is stronger than a
  synthetic test but is still not Human acceptance.
- **HUMAN REVIEWED** — the user actually inspected or used the relevant result
  and supplied feedback/acceptance.
- **NOT YET HUMAN VERIFIED** — the relevant Human gate has not occurred.

Never promote `MACHINE VERIFIED` or `AGENT REAL-USE VERIFIED` to a generic
"UI complete", "done", or "accepted" claim when Human review is still required.
Prefer precise markers such as
`IMPLEMENTATION_MACHINE_COMPLETE — HUMAN_REVIEW_REQUIRED`.

If Human real-use evidence contradicts an earlier machine completion marker,
preserve the old record as history but immediately supersede it in
`PROJECT_STATUS.md` and, when durable, in an ADR.


## Project intent

Build an unofficial native-first client for OpenAI Codex. The client must reuse the stock `codex app-server` and preserve the Codex harness rather than reimplementing an agent.

## Primary stack

- Flutter / Dart for desktop and Android UI.
- Stock `codex app-server` as the local Codex runtime.
- Desktop local transport: child process + stdio newline-delimited JSON.
- Android remote transport: authenticated resumable WebSocket to a host bridge.
- `flutter_rust_bridge` is not part of the initial architecture. It may be explored later only as an optional embedded transport if measurements justify it.

## Non-negotiable architecture rules

1. **Codex owns intelligence; the client owns presentation.**
   - Do not copy or fork Codex system prompts into the client.
   - Do not implement client-side context compaction for Native/Fidelity mode.
   - Do not replace Codex tool schemas or agent-loop semantics.

2. **UI state is a bounded projection, never the source of truth.**
   - Never hydrate an entire long thread into Flutter state by default.
   - Paginate thread/turn/item history.
   - Virtualize long lists.
   - Load large command output, diffs, logs, and files on demand.
   - Inactive threads should have near-zero UI memory cost.

3. **Keep the Codex runtime isolated by default.**
   - Desktop should spawn the user's/packaged stock `codex app-server` process.
   - A Codex crash or restart must not require restarting the UI.
   - Preserve thread IDs so sessions can be resumed after runtime restart.

4. **Remote is a first-class product surface.**
   - Android should not run the full Codex runtime by default.
   - OpenAI/Codex credentials stay on the host.
   - Pair devices explicitly.
   - Remote protocol must support reconnect/resume using sequence/ack semantics.
   - Large payloads must use chunking/streaming rather than giant RPC messages.

5. **No Electron or Node requirement for the core client.**
   - Optional plugin web UI may use a system/embedded WebView later, only when required.

## Bootstrap task

Initialize a clean Flutter project suitable for Linux, Windows, macOS, and Android. Use a Dart package/application identifier compatible with this repository name (for example `codex_native_unofficial`).

Create an architecture that separates UI/domain state from transport:

```text
lib/
  src/
    app/
    domain/
    protocol/
    transport/
      process/
      remote/
    features/
      threads/
      conversation/
      approvals/
      diff/
      settings/
```

The first working milestone should:

- launch on desktop;
- locate a `codex` executable without hardcoding a developer machine path;
- spawn `codex app-server --listen stdio://`;
- perform the app-server initialization handshake;
- expose connection/runtime status in the UI;
- implement a typed protocol adapter so widgets never consume raw JSON directly;
- shut down the child process cleanly;
- include unit tests for JSONL framing and request/response correlation;
- pass `flutter analyze` and `flutter test`.

Do not implement the full chat UI, remote host, plugin system, or FRB embedding in the bootstrap commit. Establish clean boundaries first.

## Performance rules

- Avoid unbounded in-memory event/history collections.
- Streaming text updates should be coalesced so every token does not trigger an expensive full-tree rebuild.
- Never render multi-megabyte command output inside the main conversation timeline.
- Diff views must support file/hunk-level lazy loading.
- Prefer measurable optimizations over speculative FFI work.

## Compatibility and upstream

- Treat the app-server protocol as the stable integration boundary.
- Isolate protocol-version differences inside adapters.
- Do not make the Flutter UI depend directly on internal Codex Rust crates.
- Keep it possible to swap between local process transport and remote transport without changing feature/domain code.

## Licensing and branding

- Project license: Apache-2.0.
- Preserve third-party notices when bundling upstream components.
- Clearly describe the project as unofficial and not endorsed by OpenAI.
