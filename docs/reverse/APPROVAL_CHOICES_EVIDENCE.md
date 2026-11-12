# Typed stock approval choices

Implemented on `agent/codex-approval-choices`, base
`ba6f27c0834c6e005904c0cda9da1ae8eed4caeb`. This is a Desktop functional
slice; it does not close the Golden-State approval visual comparison.

## Current upstream contract

- Fresh local exports of public stable0.167.2 and installed
  0.167.0-alpha.3.2 retain stable command/file response decisions. The command
  request's `availableDecisions` is an **experimental** field; Native already
  opts into experimental app-server surfaces. A stable response variant is
  not evidence that every request permits that grant.
- Public stable remains [rust-v0.167.2](https://github.com/openai/codex/releases/tag/rust-v0.167.2),
  rechecked against the latest-release endpoint during this slice.
- [Public protocol approval rules](https://github.com/openai/codex/blob/rust-v0.167.2/codex-rs/protocol/src/approvals.rs)
  distinguish explicit offered decisions from compatibility fallback. Ordinary
  command context does **not** imply session consent. Network context may offer
  session consent and a proposed allow rule; additional permissions do not
  imply reusable consent. Command-prefix grants require an actual proposal.
- [Public app-server handling](https://github.com/openai/codex/blob/rust-v0.167.2/codex-rs/app-server/src/bespoke_event_handling.rs)
  maps one-time approval, session approval, an exact command amendment, network
  allow/deny, decline and turn cancellation to distinct runtime outcomes.
  Decline lets a turn continue; cancel stops it. Neither is substituted for the
  other. Legacy response shapes and structured additional-permission requests
  remain separate compatibility paths.
- Current installed renderer build25894, ASAR fingerprint
  `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`,
  module474578 exposes separate network-scoped, file-session and proposed-prefix
  actions. Its deny callback sends stable decline independently of the scoped
  grant choices. These are calibrated component observations, not a signed-in
  same-state visual comparison or proof of private account capabilities.

## Native boundary

- The domain retains the existing one-time/reject constants and gateway
  signature. Immutable typed choices add explicit session, cancel, command-rule
  and network-rule alternatives. Widgets never consume raw RPC maps.
- The protocol adapter owns each pending request and its offered objects.
  Structured consent uses object identity: a client-created lookalike, a rule
  from another request or an old callback cannot authorize a fresh request.
  Payload strings are preserved; the client invents no prefix, host or rule.
- Choices are bounded to16 per command request,32 prefix arguments,4096 prefix
  characters,512 host characters and16384 aggregate retained rule characters.
  Unsupported-only choices and malformed/oversized inputs resolve with an
  explicit error rather than retaining an unusable pending request.
- Managed human checkpoints never receive reusable consent. Without an explicit
  choice list, normal command context retains conservative one-time/decline/cancel
  behavior plus only the stock-backed proposed rule. Stable file responses have
  a separate session choice. Legacy and unsupported permission paths gain no
  new grant.
- A stable refusal remains available even when not listed among grant choices;
  the existing decline wire path is preserved. New UI cancellation is explicitly
  labelled as stopping the turn. Persistent network actions show the exact host
  and scope; proposed command arguments remain inspectable in bounded details.
- The controller checks the exact pending request before choosing. Existing
  runtime-generation fences still retire in-flight completion and reused IDs.
  Conversation changes are restricted to the approval banner and one import;
  Gemini owns the independent A7 activity translation below that surface.

## Verification and remaining work

The initial scoped gate found19 missing-import analysis errors, corrected by one
domain import in the existing part library. The next run passed60 cases but
failed one existing short-split layout: wrapping actions caused33px bottom
overflow and zero usable details height. The correction preserves the existing
single-row flexible controls. A subsequent63-case gate, strict analysis0 and
pure-Dart68 pass. Logs remain private under
`/var/tmp/native-ui-r0.BbOvHT/approval-choices-*`.

Later source inspection preserved the official unconditional decline action and
legacy button order, and added an adapter-level reused-ID policy-identity test.
Strict analysis0 and pure68 pass on that source. The64-case targeted run passes
63 and exposes one stale new-test expectation that still expected an RPC error
for refusal. Correcting it to the observed stable decline contract makes all14
protocol cases pass; the other50 cases already pass on the same production
source. This is64 distinct green targeted cases across those two runs, not a
claim that the first run was green. Format scans213 source/test/tool files.

## Real stock rule and cancellation outcomes

All probes use private HOME/CODEX_HOME, owned projects, a bounded local model
fixture with a240-second lifetime and the existing frozen bundled Host. No user
configuration, account credential, private service or provider account is used.

The first public probe saves a real proposed rule and executes its first command,
but the next command receives another approval. This is preserved in
`/var/tmp/native-approval-choices-stock-r1/public-prefix/verification.json`.
The actual stock proposal is the **full shell invocation and command**, not the
model's suggested `printf` prefix. Changing the output path creates a different
command outside that exact rule. The client correctly does not broaden it.

A distinct r2 fixture repeats the exact same append command. All four real
bundled-Host cases pass in
`/var/tmp/native-approval-choices-stock-r2/verification.json`:

- public0.167.2 and installed0.167.0-alpha.3.2 each offer one-time approval,
  an actual proposed command rule and turn cancellation;
- selecting the exact offered rule executes the harmless first command. Stock
  writes its own default.rules. A read-only AST/literal check verifies the saved
  allow pattern equals the actual proposal, byte-for-byte in its arguments;
- the identical next command completes without another approval. The append
  marker contains two lines; only one approval was received across both turns;
- separate cancel cases produce `interrupted` and no command marker. Decline is
  not silently substituted for cancel;
- every recorded Host/stock process exits after awaited transport close, and each
  owned model exits after SIGINT/wait. The earlier r1 children are also absent.

Exact-rule file hashes are retained in persisted-policy-verification.json.
These are real stock-process outcomes with a controlled model, not provider-account
or Human acceptance. Session/file and managed-network variants currently have
schema/typed-protocol/widget evidence; their specific real emission/outcome is
not asserted by the command-rule probes.

## Peer findings and source-bound remediation

The targeted peer audit ofc2b5a64 records0P0,1P1 and2P2. Its original
observations remain source-scoped; a green hosted CI did not establish legible
consent choices. A separate worktree preserves exactlyc2 plus three new
regression files. `approval-peer-red-r1.log` records16 passes/four failures:
consent legibility, same-connection deciding-ID reuse, duplicate rules and
legacy multiline-rule suppression. A refined critical-verb check confirms the
old strip gives18.15px where154.70px is needed to distinguish allow from deny.

The follow-up keeps ordinary Reject/Approve once buttons and moves additional
responses to a bounded existing CodexPopover/CodexMenu. Opening it grants
nothing. Its16-choice list scrolls independently, preserves distinct policy
verbs and exposes complete scope details. Request identity keys retire the
menu on resolution/replacement; Escape closes it without consent. This avoids
both horizontal compression and the earlier proven33px vertical Wrap overflow.
Full hostnames can ellipsize while the action verb remains readable; a test's
initial full-host non-ellipsis check was overly strict for the test font and is
preserved separately from the meaningful critical-verb regression.

Deciding state is now keyed by request identity without changing the public ID
query. The relevant race is same-connection external resolution followed by ID
reuse; the existing runtime-generation guard already covered cross-runtime
completion. Exercising the adjacent failure path also reproduces an old RPC
error polluting a new request (`approval-peer-retired-error-red-r5.log`). Error
publication now requires that exact request still be pending.

Structured options deduplicate by their canonical wire value **inside one
request**, keeping the first actual offered object and preserving cross-request
identity protection. Compatibility prefixes containing CR/LF are suppressed,
matching the current renderer. Explicitly offered payloads remain unchanged;
numbered scope arguments are JSON-quoted/escaped for display, preventing embedded
newlines from impersonating another argument.

The corrected source passes **70 targeted cases in one run**, strict analysis0
and pure-Dart68 (`approval-peer-green-r7.log`, `analyze-r7`, `pure-r7`). Escape,
external menu retirement, escaped scope text and the old short-split detail
scroll all pass. The earlier missing import, wrong pure-gate filename, actual
Wrap overflow, duplicate-text finder and overly strict full-host check remain
recorded rather than reclassified as successful runs.

## Real file-session approval and cancellation

An initial direct custom apply_patch fixture times out waiting for approval;
its owned rollout records `unsupported custom tool call: apply_patch`, not an
executed edit or a client approval failure. Public handler code alone did not
prove that tool was advertised in this model setup. The failed profile and
closed Host/stock identities remain in
`/var/tmp/native-approval-file-session-stock-r1/`.

A distinct fixture follows the already observed stock-supported exec_command
apply_patch heredoc workflow. All four cases pass in
`/var/tmp/native-approval-file-session-stock-r2/verification.json`:

- public0.167.2 and installed alpha both emit real file-change approvals;
- explicit session approval applies the first patch, then a second patch of
  the **same file** completes with only one approval across both turns;
- independent cancellation returns interrupted and leaves no edited file;
- all recorded Host/stock PIDs are absent, and every owned bounded model is
  stopped and awaited. No user profile or account is involved.

This verifies same-file session behavior, not an unlimited or cross-thread
file grant. Together with command-rule/cancel probes it supplies eight real
cases. Managed-network emission still has schema/typed-protocol/widget evidence
only; no private service or fake managed-network parity is introduced.

## Remaining validation

c2b5a64's exact hostedCI43184267473 passes verify/macOS/Windows. That older
checkpoint does not verify the follow-up fixes. Targeted peer reinspection,
merged U8 shared gates, a new packaged approval walkthrough and exact final-HEAD
hosted CI remain machine-actionable. Gemini's U8 A7 subset does not close the
remaining per-item file-diff or live-output functional seams. Root has the
exclusive heavy lease for correction/integration; peers continue independently
on source/evidence. No Desktop completion or Human acceptance is claimed.
