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

#### Codex Desktop Completion dual-track override

When `PROJECT_STATUS.md` names **Codex Desktop Completion**, scope is narrowed
without lowering standards.

- Run two first-class tracks in parallel:
  - **Track F — functional parity:** close supported Codex Desktop
    `MISSING` / material `PARTIAL` workflow and capability gaps.
  - **Track U — high-fidelity UI:** continue Golden-State clean-room translation
    until machine-actionable Codex Desktop presentation gaps are closed.
- Track F and Track U are both completion requirements. Neither may be demoted to
  "good enough" merely to ship sooner.
- Codex preferentially owns functional/schema/protocol/state/runtime slices and
  systems-integrity review. Gemini preferentially owns presentation/evidence/
  same-state UI translation. Both remain equal peers.
- Keep independent work moving in both tracks. One blocked Human/evidence gate
  freezes only that slice, not the other track.
- Defer new Chat/Work/Responses/mobile/Direct-Host-Remote expansion and unrelated
  product scope until Codex Desktop completion, unless needed to verify or fix a
  Codex Desktop path. Preserve existing code and correctness.
- Private/internal services remain excluded even if first-party UI depends on
  them. Functional-parity claims are scoped to legitimate supported/reproducible
  Codex functionality.
- After apparent closure, run a fresh functional audit and a fresh UI
  Golden-State audit before declaring the narrowed target complete.

#### Golden-State UI convergence ownership override

While `PROJECT_STATUS.md` names an active Desktop UI Visual Parity / Golden-State
phase **or an active Track U inside Codex Desktop Completion**, the peers remain
equal but the default **write ownership** becomes intentionally asymmetric by
surface:

- **Antigravity/Gemini is the default presentation owner** for visual/interaction
  translation slices whose main purpose is official Desktop fidelity. It should
  gather or refresh official evidence, implement the corresponding Flutter
  presentation in its own worktree, run the closest Native state, compare the
  result, and iterate before handoff.
- **Codex is the default systems-integrity owner and adversarial reviewer** for
  those Gemini-owned presentation slices. Codex checks controller/domain
  boundaries, bounded memory, lazy loading/virtualization, async lifecycle and
  race behavior, protocol correctness, accessibility/keyboard regressions,
  tests, real-stock validation, integration, and CI.
- Codex must not take over a presentation slice merely because it can implement
  it. Transfer presentation ownership to Codex only when Gemini is blocked, the
  change is predominantly state/architecture rather than visual translation, or
  Gemini explicitly releases the slice.
- Gemini must not rewrite protocol/controller/state machinery for visual
  convenience when the existing boundary can support the translated UI. If a
  real systems change is required, release that surface or negotiate a
  non-overlapping Codex-owned systems slice first.
- Prefer **surface-sized coherent slices** (for example one complete Golden-State
  row or tightly coupled row cluster) over one commit/CI cycle per spacing,
  label, focus, or icon adjustment. Local targeted tests and captures should
  iterate inside the owner worktree; shared full gates and hosted CI belong at
  coherent integration checkpoints.
- This override expires when the active Golden-State parity phase ends. The
  normal evidence/context-based peer routing above then resumes.

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

### Official Antigravity interaction channel

When Codex needs live interaction with Antigravity/Gemini, the **only approved
interactive channel is the official `agy` TUI**.

- Launch the official `agy` executable directly in an interactive terminal/PTY.
- Do not use third-party wrappers, proxy bridges, reverse-engineered RPCs,
  browser automation, unofficial quota relays, or tools that expose
  Antigravity/Gemini as a surrogate API.
- Repository commits, task packets, and handoff documents remain the durable
  shared memory, but any live Codex↔Gemini conversation must occur inside the
  official `agy` TUI.
- If the TUI is blocked by permissions or review policy, first adjust the
  official Antigravity CLI configuration (prefer `/config` or `/settings`)
  instead of bypassing the TUI. For unattended project work, use the appropriate
  official always-proceed/Turbo-style permission and artifact-review settings
  when the user has authorized that risk level.
- If terminal rendering makes the full-screen TUI hard to drive, adjust the
  official rendering configuration (for example `altScreenMode`) rather than
  switching to a non-TUI integration.
- Editing `~/.gemini/antigravity-cli/settings.json` is permitted only as the
  CLI's own documented configuration mechanism; never read, print, commit, or
  exfiltrate credentials/tokens from Antigravity state.
- Failure of one TUI attempt is a configuration/debugging problem to solve when
  practical, not a reason to demote Gemini to a subordinate/read-only role.

The relationship remains peer-to-peer: using `agy` from a Codex-owned terminal
does not make Codex the manager of Gemini. Codex may ask Gemini for an
independent opinion, evidence gathering, or a jointly scoped slice; Gemini's
answer is peer input and is judged by the same evidence rules as Codex's work.

### Continuous iteration and queue exhaustion

A completed slice, peer-coordinated round, merge, hosted CI run, or peer closure
is a **checkpoint**, not a valid end of the active `SELF_ITERATION` turn.

Before emitting a final completion report or returning control solely because
the current slice is closed, evaluate this global stop predicate:

1. there is no independent `READY` work;
2. there is no materially progressable `RESEARCH_MORE` work using available
   source, schemas, binaries, APK/ASAR evidence, live runtime, tests, or public
   documentation;
3. a fresh audit of current Native HEAD vs current stock app-server schema,
   official Desktop evidence, and available Android evidence finds no new
   supported `MISSING` / `PARTIAL` / regression gap;
4. every remaining material item is genuinely blocked by Human input,
   unavailable physical/external environment, or an intentionally excluded
   private/unsupported service.

Only when **all four** are true may the larger authorized program become idle or
move to program-level `HUMAN_REVIEW`.

Queue behavior:

- If `READY` is non-empty, select the highest-value independent item and
  continue.
- If `READY` is empty, `RESEARCH_MORE` becomes the active machine-work queue:
  select the highest-value researchable item, investigate it, and reclassify it
  as `READY`, `PRIVATE_ONLY`, `BLOCKED`, `NOT_APPLICABLE`, or
  `RESEARCH_EXHAUSTED`.
- If existing `RESEARCH_MORE` cannot progress, perform a fresh convergence
  audit and rebuild the living backlog.
- `OFFICIAL_FEATURE_MATRIX.md` is a living backlog, not a finite checklist.
  Completing all currently listed `READY` rows requires a new audit; it does
  not prove convergence is finished.

During a peer-coordinated Codex + Gemini run:

- after integrating the current owned slices and validating the resulting HEAD,
  reopen or continue the official `agy` TUI peer session;
- exchange the compact handoff/evidence for the completed round;
- negotiate the next non-overlapping high-value ownership pair;
- then continue implementation without waiting for the user unless the global
  stop predicate above is satisfied.

Do not use wording such as "this report closes the current coordinated slice" as
an implicit reason to end the active program. A report may close a slice while
the same agent turn immediately proceeds to the next authorized slice.

### Official UI translation rule

When current official Codex Desktop evidence exists for a user-visible surface,
the implementation task is **translation, not redesign**.

**Do not design. Translate.**

- Reconstruct observable hierarchy, geometry, component states, interaction
  behavior, density, spacing, and placement from current official evidence, then
  implement the closest clean-room Flutter equivalent.
- Prefer the thinnest language/platform translation. Do not add a model-authored
  design layer between official evidence and Flutter.
- Current live official behavior, screenshots, DevTools/computed styles, and
  revalidated ASAR/component evidence outrank older reverse documents, current
  Native composition, and model aesthetic preference.
- Existing reverse documents are evidence, not immutable truth. If Human visual
  comparison or current live inspection contradicts an older structural claim,
  mark it stale/revalidation-required and refresh it before implementation.
- Preserve existing domain/controllers/protocol behavior unless translation
  exposes a real correctness defect. Prefer presentation recomposition over
  rewriting working business logic.
- Do not copy proprietary source code, private assets, prompts, credentials, or
  internal services. Clean-room reimplementation of observable structure,
  measurements, states, and behavior remains required.
- When the current shell is structurally divergent, structural reconvergence
  outranks new presentation-bearing feature expansion. Functional backlog items
  may remain technically READY while being deferred by active UI priority.
- Passing an old geometry test does not establish current official parity.
  Verify the current official and Native screen at the same state/viewport.

For reconstruction, work in this order unless evidence proves otherwise:

1. app/window shell and global navigation hierarchy;
2. Codex product/sidebar hierarchy;
3. workspace/thread header;
4. conversation timeline and activity presentation;
5. composer and controls;
6. menus, popovers, dialogs and secondary surfaces;
7. compact/responsive behavior;
8. screenshot/overlay comparison and Human acceptance.

### UI reconvergence work-selection rule

During Desktop UI Structural/Visual Reconvergence, **tests are validation gates,
not an autonomous backlog generator**.

Select the next UI task in this order:

1. a measured same-state difference between the current official Codex Desktop
   and Native;
2. explicit Human visual/interaction feedback;
3. a correctness, accessibility, security, data-loss, or state-regression defect
   exposed by the translation;
4. only then a bounded hardening item that materially blocks the next official
   comparison.

Do not recursively turn every newly imagined edge case, extreme viewport, or
test-only scenario into the next priority. A passing test may close a risk; it
does not by itself create another slice.

After the primary shell/navigation/workspace/composer structure is translated,
the default loop becomes:

official same-state capture -> Native same-state capture -> compare/overlay ->
rank the largest visible or behavioral divergences -> fix the highest-impact
divergence -> run targeted regression gates -> repeat.

Rules:

- Prefer a short targeted test for the changed surface plus the normal shared
  checkpoint gate. Do not expand the test matrix merely because another extreme
  dimension can be imagined.
- Fix P0/P1 correctness/security/data-loss/accessibility regressions immediately.
  Record lower-priority speculative hardening as deferred when it does not block
  official parity or normal product use.
- Accessibility is a product requirement, but accessibility work should be tied
  to the translated surface or an observed regression; do not let arbitrary
  stress combinations displace the current visual-parity loop.
- During this phase, the largest measured official-vs-Native divergence outranks
  unrelated polish and feature-long-tail work.
- A green CI checkpoint is a gate, not evidence that the next task should be
  another test-only hardening slice.

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
