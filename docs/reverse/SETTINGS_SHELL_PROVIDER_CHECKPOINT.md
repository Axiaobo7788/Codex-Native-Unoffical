# Settings, Shell activity and saved-title scope checkpoint

Implementation checkpoint `7d0282d131ceda57aa2dfa66c9f6cffc2f007b1a`, normally
merged and published to main on 2026-11-12. Git remains canonical for later
source/documentation HEADs. This is a checkpoint inside `SELF_ITERATION`, not
Codex Desktop completion or Human visual acceptance.

## Source and review

- Codex `9fc19d3` adds bounded acknowledged thread settings; `5c46c44` records
  [its source-bound evidence](INHERITED_SETTINGS_EVIDENCE.md).
- Codex `cafcf12` corrects the existing explicit local saved-title search.
- Gemini `df46ace`, `e9a9697` and `7301289` translate the A7/C Shell card,
  then project nullable int32 command exitCode and correct unknown status.
- The normal merge preserves both peers' original commits. Separate worktrees
  and negotiated ownership avoided concurrent conversation-file edits.
- Official agy peer review of the corrected settings and actual title-search
  commit/combined diff reports zero P0/P1/P2. Codex independently read the U6
  public API/protocol/controller changes and actual success/failure captures;
  the earlier dropped exitCode/false unknown-success finding was corrected
  by its original owner before integration.

## Title search support and scope

The public `0.167.2` generated ThreadListParams defines an explicit empty
modelProviders list as all providers. Current installed Desktop build `25894`
ASAR SHA-256 remains
`121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`.
The current `182735.searchThreads` title fallback was re-read at its measured
location: it sends an empty provider filter, archived false and no section.
Only observable request facts were translated; bundled source was not copied.

ProcessTransport explicitly opts into this behavior. The generic adapter
and Remote keep the narrower default. Only a trimmed nonempty active,
unsectioned title query uses the all-provider filter. Ordinary, archived and
section catalogs retain their previous scope. Each cursor page keeps its query
scope, and existing pagination/100-thread retention limits remain unchanged.
Discovery does not resume a thread, change providers or replay a queued input.

Fresh private profiles were seeded with two Alpha threads and one Beta thread
through the real bundled Host and stock runtime, with Beta configured at read
back. The old and new Native adapters ran against the same storage. Both public
`0.167.2` and installed `0.167.0-alpha.3.2` verify:

- Ordinary catalog: only the Beta thread, before and after.
- Old title search: one Beta result. Corrected search: all three results,
  traversed with one-row pages and terminating cursors.
- Alpha metadata and one-turn history are readable while remaining notLoaded.
- Explicit Alpha resume returns the actual structured modelProviderMismatch;
  the experiment does not assume a newer runtime will reject the same way.
- All recorded Host/stock children disappear after awaited close. The local
  Responses fixture exits through explicit cleanup; there are three seed model
  calls per binary and no model call for discovery/history/failing resume.

Private artifacts: `/var/tmp/native-saved-title-provider-r1/{public,installed}/`.
These are real-process probes, separate from the simulated runtime test harness.

## Packaged saved-title and failure walkthrough

The combined release is frozen at
`/var/tmp/native-desktop-settings-u6-7d0282d-r1/bundle/`:

- AOT: `393b320fc16111e22f507202d0052110cd3b1b651af6a286e2aa61b44e7af554`.
- Host: `73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878`.

In an owned Xvfb/DBus profile, the actual App → bundled Host → public `0.167.2`
initially shows only Beta. Loaded filtering still shows Beta. The existing
Search saved threads action returns all three; selecting Alpha displays its
saved user/assistant turn without implicit resume. Explicit Send shows the
stock provider-mismatch failure above the composer and preserves the unsent
draft at 1191×865 and 700×760. Switching and exiting saved search remain usable.
The model fixture records zero POST calls. App/Host/stock and model workers all
exit; no Flutter unhandled exception or overflow is observed.

Eleven captures/logs and their checksum manifest are under
`/var/tmp/native-title-provider-native-r1/`. Early selected-thread captures
precede the settled frame and are retained rather than substituted for a pass.
Wide switching intentionally retains draft text under ADR-055; that observed
behavior is not a new per-thread draft cache or a newly reproduced regression.

## U6 Shell activity evidence

The measured current `25894` `jKy0`/`PuGl.d` structure becomes a quiet full-row
command disclosure and expanded Shell card: shell label, two-line collapsed
command with explicit expansion, hover/focus copy controls, 144 px bounded
output viewport and completion footer. The existing OutputViewerController
still fetches only a 4 KiB preview; full output remains a separate lazy action.
Numeric exitCode is retained as a nullable int32 through live/history adapters
and small typed descriptors; raw aggregated output is not retained in rows.
Unknown non-completed status cannot silently imply success.

Owner source `7301289` real-stock replay covers public light/dark and installed
light, including actual completed and failed commands. Eighteen captures and
binary checksums are in `/var/tmp/native-gemini-u6-a7-real-stock-r4/`; fixture
stats record nine Responses calls and zero image-sentinel GETs. Codex inspected
public Success and Exit code 2 screenshots and independently checked that all
21 recorded processes were absent. Owner AOT is
`d14c60281abeb4d629e2d554744f8af5dc81e062782780e94dd87531c559bff6`.
The combined source has the shared regression gate below and the separate
packaged title walkthrough; it is not mislabeled as a new combined Shell replay.

## Shared gate and preserved limits

Source `7d0282d`: format 208/zero changes, strict analysis 0, pure-Dart 68, 660 default
Flutter cases/five opt-in skips; five direct-stock cases pass separately on each
binary. History retains 100/1,000 turns and discards ten 3 MiB command payloads.
Cargo format, two-job Linux release and 83-system-library bundle closure pass.
Rust source is unchanged; no new local Clippy/100-test run is claimed.

Exact source branch CI43157353142 first passes Windows/macOS but verify times
out in Install Linux build dependencies after five minutes, before code checks.
Only failed job130980357409 was rerun. Exact main [CI43158612189](https://github.com/Axiaobo7788/Codex-Native-Unoffical/actions/runs/43158612189)
now passes verify, macOS and Windows. Branch attempt two also passes at the
same source; its first dependency timeout remains preserved. Earlier
settings/evidence source `5c46c44` CI43156192343 passes all three jobs. No workflow
or permission policy was changed to bypass the dependency failure.

Home/current-cwd settings preview, global full-content search, broader provider
inventory/configuration and dedicated provider-block presentation remain open.
U6 does not establish streaming command-preview delivery or close the full
saved completed-activity hierarchy. Matched signed-in official comparisons,
subjective visual/interaction acceptance and physical-platform checks remain
unrun. A6 clipping continues as U7; hot recovery remains a separate Track F gap.
