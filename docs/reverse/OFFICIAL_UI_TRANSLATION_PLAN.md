# Official Codex UI Translation Plan

_Last updated: 2026-11-10_

## Purpose

The current Native product has strong functional coverage, but Human side-by-side
comparison rejected the assumption that its Desktop composition already matches
the current official Codex Desktop.

This phase is not a new visual design exercise.

> **Do not design. Translate.**

Observable official hierarchy, geometry, state and interaction are the
clean-room implementation specification. Existing Native domain/controller
behavior should be retained and re-presented through the translated hierarchy.

## Current acceptance contract

The [Golden State A matrix](OFFICIAL_UI_GOLDEN_STATE_A.md) owns the wide
active conversation's current evidence, implementation and next correction.
Close machine-actionable rows before a screen-wide subjective review.
Freeze only the state that requires unavailable evidence. Proceed to the next
evidenced Golden State, or to independent functional work when every UI
state is blocked. The program remains in `SELF_ITERATION`.

## Evidence order

Use the strongest current evidence in this order:

1. current official Codex Desktop live screen and reproducible interaction;
2. DevTools DOM/component/computed-style measurements from that same state;
3. refreshed ASAR/CSS/component evidence tied to the current build;
4. current screenshots at known viewport/state;
5. previously recorded reverse documents after revalidation;
6. inference/model preference only where direct evidence is unavailable.

If a previous reverse document conflicts with current live evidence, update the
document; do not reinterpret the current screen to preserve the old claim.

## Translation surfaces

For each surface, record the official evidence, Native status
(MATCH/PARTIAL/DIVERGED/MISSING), direct translation action and verification.

Primary surfaces:

- app/window shell;
- global navigation hierarchy;
- Codex sidebar;
- workspace/thread header;
- timeline / thought / command / diff / review;
- composer;
- menus/popovers/dialogs;
- compact/responsive composition.

Do not mark a surface MATCH from token equality alone.

## Execution order

### R0 — Refresh the official structural map

Before changing Native composition:

- open the current official Codex Desktop;
- reproduce representative empty, active, command-heavy and review states;
- inspect the actual current hierarchy and measurements;
- refresh OFFICIAL_UI_SPEC.md, OFFICIAL_COMPONENT_MATRIX.md, and
  OFFICIAL_SCREENSHOT_BASELINES.md where prior assumptions are stale;
- produce an explicit Official -> Native mapping.

### R1 — Shell and navigation

Translate the outer shell first. Do not polish inner cards while the shell or
navigation hierarchy is structurally wrong.

### R2 — Workspace hierarchy

Translate the product/sidebar organization and thread workspace header while
reusing existing thread/controller behavior.

### R3 — Timeline/activity

Translate user/assistant/thought/command/tool/diff/review presentation from
official evidence. Preserve lazy history/output and bounded-memory behavior.

### R4 — Composer

Translate placement, width, control grouping, states, focus and send/stop
behavior without changing the Codex execution contract.

### R5 — Secondary surfaces

Translate menus, popovers, dialogs, MCP/plugin/review surfaces after the primary
screen hierarchy is correct.

### R6 — Responsive and verification

Verify at the same states and viewports as official evidence. Use screenshot
comparison/overlay plus machine geometry and interaction tests. Human visual
acceptance remains distinct from machine verification.

## Post-structural visual parity loop

Once the primary shell/navigation/workspace/composer structure is translated,
do not continue by inventing additional hardening work.

The default selector is now:

```text
official same-state screen/behavior
-> Native same-state screen/behavior
-> side-by-side / overlay
-> rank visible or interaction divergences
-> fix the highest-impact divergence
-> targeted regression tests
-> shared checkpoint gate
-> repeat
```

A test failure can create immediate work when it proves a material correctness,
accessibility, security, data-loss, or state regression. A passing test does not
create another slice merely because a more extreme viewport or concurrency
combination can be imagined.

Use a bounded hardening budget:

- protect normal desktop, compact, keyboard/focus and accessibility behavior;
- fix regressions caused by current translation;
- defer speculative stress combinations that neither match observed official
  behavior nor block normal product use;
- return to screenshot/live comparison after each bounded correction cluster.

The purpose of R6 is to verify translated behavior, not to turn UI convergence
into an unbounded test-exploration program.

## Scope guard

During this priority phase:

- do not add unrelated F33+ presentation-bearing features;
- do not extract a public UI package;
- do not implement MD3;
- do not rewrite working protocol/domain/controllers merely to make UI code
  aesthetically cleaner;
- do not copy proprietary official source/assets;
- do fix correctness regressions discovered by the translation.

The existing feature backlog remains valid. The current acceptance contract
governs when independent functional work resumes.

## Peer workflow

Use the official agy TUI only.

Gemini and Codex are equal peers:

- Gemini preferentially owns refreshed official visual/structural evidence;
- Codex preferentially owns Flutter translation and architecture/regression
  protection;
- either may challenge or own a slice when it has stronger current context.

Every loop is:

official evidence
-> mapping
-> Flutter translation
-> run Native
-> same-state screenshot
-> overlay/diff
-> fix measured divergence
-> peer review
-> next surface

The phase is successful when the first impression, primary information
hierarchy, and component placement of the Native Desktop clearly correspond to
the same official Codex product before subjective micro-polish begins.
