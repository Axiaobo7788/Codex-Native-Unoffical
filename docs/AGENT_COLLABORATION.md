# Codex CLI + Antigravity/Gemini Peer Collaboration

_Last updated: 2026-11-09_

This document defines the lightweight collaboration protocol for two equal
engineering agents working on Codex-Native-Unoffical.

The goal is higher throughput and better cross-checking without paying the cost
of duplicated implementation, constant mutual review, or relying on one model's
long conversational context.

## 1. Core model: peers, not manager + worker

Codex and Antigravity/Gemini are peers.

There is no permanent rule that:

- Gemini implements and Codex reviews;
- Codex decides architecture and Gemini obeys;
- one agent must approve every commit from the other.

For each slice, choose an **owner** based on current context, evidence, and the
kind of work. The owner is responsible for implementation and local closure of
that slice. The peer may research an independent question, review a risky
boundary, or own a different slice in parallel.

The final authority is evidence plus the repository's durable decisions, not
agent identity.

## 2. Default routing by comparative strength

These are defaults, not hard ownership boundaries.

### Prefer Antigravity/Gemini for

- official Desktop visual reconstruction;
- live renderer / Chromium DevTools inspection;
- screenshots, overlays, geometry comparison, and UI state matrices;
- Flutter presentation and component-system work;
- interaction polish and mobile adaptation;
- exploratory ASAR/APK reverse research;
- long autonomous UI/research loops where Teamwork or browser-style tooling is
  useful.

### Prefer Codex for

- architecture and dependency boundaries;
- app-server protocol/schema integration;
- Rust Host, transports, Remote plumbing, and concurrency;
- bounded-memory and long-session state;
- difficult state-machine / lifecycle bugs;
- adversarial regression hardening;
- CI/build/release engineering;
- narrow code audits where implementation detail consistency matters.

### Either agent can own

- shared domain models;
- feature integration;
- test additions;
- documentation;
- reverse-analysis reconciliation;
- routine bug fixes.

Route to whichever agent already has the strongest *current* context. Avoid
moving a slice just because another model has quota available.

## 2.1 Live peer interaction channel: official `agy` TUI only

Codex↔Gemini live collaboration must use Google's official Antigravity CLI TUI.

The intended flow is:

```text
Codex terminal
→ launch official agy TUI
→ converse with Gemini as a peer
→ Gemini inspects/researches/implements within its owned scope
→ repository commits / compact HANDOFF
→ either peer continues
```

This is a communication path, **not a hierarchy**. The fact that Codex launches
the TUI does not make Gemini a subagent or reviewer-only tool.

Do not use:

- third-party `ask-antigravity`-style wrappers;
- unofficial API adapters or reverse-engineered RPC control;
- browser automation as a substitute for the CLI;
- quota/proxy bridges;
- any external tool that turns Antigravity into a hidden API.

If the official TUI pauses too often, fix the official CLI configuration rather
than routing around it. Prefer `/config` or `/settings`; when the user's
chosen risk posture is full access, configure the official tool/permission mode
and artifact review policy to always proceed/Turbo-equivalent behavior. If
alt-screen rendering is the only obstacle to Codex driving the interactive
terminal, use the documented CLI rendering setting (including
`altScreenMode=never` when necessary) while continuing to use the TUI.

The documented CLI settings file
`~/.gemini/antigravity-cli/settings.json` may be edited only for official CLI
configuration. Never copy credentials or unrelated account state from it into
the repository or prompts.

If TUI integration still fails after reasonable configuration work, record the
failure precisely and continue independent repository work; do not replace the
channel with a third-party integration.


## 3. Task packet

Before substantial parallel work, define a small task packet. It may live in the
prompt or current project status; it does not need a new permanent file for every
task.

A useful packet contains:

- **Task ID / slice**;
- **User outcome**;
- **Current base HEAD**;
- **Owner agent**;
- **Writable scope** (files/directories or subsystem);
- **Read-only adjacent scope**;
- **Must-read durable docs / ADRs**;
- **Evidence required**;
- **Validation gates**;
- **Expected handoff**;
- **True Human/blocking conditions**.

Keep the packet small enough that an agent can re-read it frequently.

## 4. Git/worktree concurrency

Parallelism is encouraged only where writes are independent.

Recommended local shape:

```text
main
├─ worktree/codex-<slice>
└─ worktree/gemini-<slice>
```

Rules:

1. one writer per overlapping file surface;
2. separate branches/worktrees for independent concurrent slices;
3. small coherent commits;
4. no force-push or peer-history rewriting;
5. if ownership overlap appears, finish or hand off the overlapping part before
   the second agent edits it;
6. integration should preserve the original commits where practical so the peer
   can inspect provenance and regressions.

Do not create two implementations of the same feature merely to compare model
quality. Spend the second agent on independent work or targeted review.

## 5. Handoff contract

A handoff should be short and repository-grounded:

```text
HANDOFF
Base/HEAD:
Commits:
Goal:
Changed:
Evidence:
Validation:
Open risks:
Files/surface released:
Next useful action:
Claims that deserve peer verification:
```

The receiving agent must inspect the referenced commits/source instead of
trusting the prose summary alone.

For a long Antigravity/Teamwork run, emit or refresh a handoff after every
coherent integrated slice. This limits attention drift and prevents stale
assumptions from surviving across hours of context.

## 6. Context hygiene

Conversation history is a cache, not project memory.

After any of the following:

- a long autonomous run;
- multiple subagents returning;
- a branch handoff;
- a substantial merge;
- a major upstream/reverse-evidence refresh;

the active agent should re-read:

1. the task packet;
2. `AGENTS.md`;
3. the top/current phase of `PROJECT_STATUS.md`;
4. relevant ADRs;
5. current `git status` / `git log` / diff;
6. the exact source files it is about to change.

For Gemini in particular, prefer several bounded, evidence-refreshed slices over
one enormous prompt that expects perfect attention to every earlier detail.

Do not paste the whole repository or every reverse document into each prompt.
Point the agent to authoritative files and require it to read the relevant
sections.

## 7. Peer review without hierarchy

Peer review is **risk-based**.

Request peer review for:

- architecture changes crossing multiple subsystems;
- public/shared component API changes;
- protocol/schema interpretation;
- security/auth/credential boundaries;
- Rust/transport/concurrency changes;
- memory-retention changes;
- reverse-engineering conclusions that drive implementation;
- changes whose failure could invalidate a large amount of later work.

For ordinary isolated UI or feature work, the owner can validate and integrate
without waiting for the peer.

When reviewing:

- audit the actual commit/diff;
- identify concrete P0/P1/P2 findings;
- distinguish correctness issues from stylistic preference;
- do not rewrite the slice merely to demonstrate another approach.

## 8. UI collaboration

Gemini is the preferred first owner of UI fidelity work because it can spend
attention on live visual evidence, geometry, and presentation details.

Codex remains an equal peer and is especially useful for checking that UI work
does not regress:

- bounded projections;
- lifecycle/state correctness;
- virtualization;
- architecture boundaries;
- testability;
- component API quality;
- protocol behavior.

Codex should not override measured visual evidence with abstract style
preference. Gemini should not override architecture/memory/protocol invariants
for visual convenience.

### Golden-State presentation-owner mode

When `PROJECT_STATUS.md` activates Desktop UI Visual Parity / Golden-State
reconstruction, use a stronger temporary routing rule than the general
preference above:

1. Gemini owns the presentation slice end to end: current official evidence,
   explicit mapping, Flutter presentation changes, Native same-state capture,
   and visual correction loop.
2. Codex reads and reviews the actual Gemini diff rather than reimplementing the
   same presentation. Codex owns systems-risk findings, regression coverage,
   real-stock/runtime verification, integration and CI.
3. If a slice needs both presentation and systems work, split ownership by file
   surface/worktree. One writer remains mandatory for every overlapping file.
4. Keep UI slices large enough to close a meaningful Golden-State row or
   coherent cluster. Avoid repeated remote push/full-CI cycles for isolated
   spacing, wording, icon, or focus tweaks when those changes can be validated
   together locally.
5. Handoff back to Codex only when the visual slice has a concrete diff and
   evidence. Codex returns P0/P1/P2 findings; the original owner fixes its own
   presentation surface unless ownership is explicitly renegotiated.
6. The mode ends with the Golden-State phase. It is not a permanent hierarchy:
   Gemini is not Codex's subordinate, and Codex is not a permanent cleanup
   worker.

### UI reconstruction protocol

For official-fidelity work, neither peer invents a new visual direction.

- Gemini owns the default end-to-end presentation loop during Golden-State
  reconstruction. It refreshes evidence through the official app, DevTools,
  screenshots, ASAR/CSS/component inspection and measured states, translates
  the mapping into Flutter, captures Native and corrects measured divergence
  in its own worktree.
- Codex preferentially protects bounded state, virtualization, async lifecycle,
  focus/semantics, controller and protocol boundaries. It reviews the actual
  implementation, adds targeted regressions, exercises real stock paths and
  owns integration and shared gates. Presentation findings return to the
  current owner under the phase-specific ownership rules above.
- This remains peer collaboration, not a manager/worker hierarchy. Either agent
  may challenge the other's claim with stronger evidence.
- The loop is: official evidence -> explicit mapping -> Flutter translation ->
  run Native -> screenshot/overlay comparison -> correct measured divergence.
- Model preference is not a valid reason to change an official-observed layout
  when a direct clean-room translation is feasible.

## 9. Systems collaboration

Codex is the preferred first owner for protocol/Rust/transport/state-hardening
work.

Gemini remains an equal peer and can review user-visible consequences, reverse
official behavior, or implement the presentation surface on top of the new
capability.

Neither agent should create a private/internal dependency merely to obtain
feature parity.

## 10. Disagreement resolution

Use this order:

1. latest explicit user instruction;
2. `AGENTS.md` invariants and accepted ADRs;
3. public/supported upstream schema and reproducible live behavior;
4. tests, traces, benchmarks, and minimal repros;
5. calibrated static bundle/APK evidence;
6. inference or model preference.

If the disagreement is about a safe reversible engineering choice and the
evidence remains tied, select one reasonable approach, record why, and keep
moving.

Escalate to the user only when preference is genuinely the deciding input or the
decision is high-impact/irreversible.

## 11. Integration rhythm

A productive rhythm is:

```text
Gemini UI/reverse slice ───────┐
                              ├─ integrate → shared tests → next queue
Codex systems/feature slice ───┘
```

or, for one cross-cutting feature:

```text
research owner
→ implementation owner
→ targeted peer audit
→ remediation by original owner
→ integration
```

The reviewer does not become the permanent superior, and the implementer does
not gain permanent ownership of that subsystem.

## 11.1 Continuous peer-round loop

A successful peer round does not end the collaboration session.

After both owned slices are integrated and the shared HEAD has passed the
appropriate local/hosted gates:

1. refresh repository state and the living convergence queue;
2. reopen or continue the official `agy` TUI;
3. exchange a compact HANDOFF for the completed round;
4. identify the next highest-value non-overlapping work;
5. assign ownership as equal peers;
6. continue immediately.

If the current `READY` queue is empty, the peers must not conclude "nothing
left to do." They should jointly select a machine-progressable
`RESEARCH_MORE` item or perform a fresh Native-vs-official/schema audit to
discover new supported gaps.

A final peer-session completion report is appropriate only when the global stop
predicate in `AGENTS.md` is satisfied. Otherwise use the report as a checkpoint
and continue to the next round.


## 12. Success criterion

The collaboration model is working when:

- both agents can make independent forward progress;
- duplicated work is rare;
- cross-agent handoffs survive context resets;
- a long Gemini context cannot silently become project truth;
- Codex does not become a permanent cleanup worker;
- Gemini does not become a permanent UI-only subordinate;
- risky changes receive independent scrutiny;
- routine work does not wait on unnecessary peer approval;
- the repository remains the canonical shared memory.
