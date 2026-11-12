# U8 — Golden State A7 Activity Hierarchy & Non-Shell Inline Rows

- **Slice status:** `IMPLEMENTATION_MACHINE_COMPLETE + AGENT_REAL_USE_VERIFIED — HUMAN_REVIEW_REQUIRED` (`NOT YET HUMAN VERIFIED`)
- **Base commit:** `ba6f27c0834c6e005904c0cda9da1ae8eed4caeb` (`main`)
- **Branch / worktree:** `agent/gemini-golden-ui-u8-a7-hierarchy` (`/var/tmp/native-gemini-u8-a7-hierarchy`)
- **Official reference build:** ChatGPT / Codex Desktop Linux `26.1103.60933` (`codexBuildNumber: "25894"`, ASAR SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`)

---

## 1. Official `25894` Evidence Mapping & Translated Behavior

1. **Quiet Inline Header Accessory Slot (`152406.jKy0.A`):**
   - Official `jKy0.A` orders inline row content as `[leadingIcon, label, accessory, statusText, chevron]`.
   - Translated `accessory` (`Widget?`) and `accessorySemanticLabel` (`String?`) on `CodexInlineActivityHeader` and `CodexActivityRow` (`lib/src/app/primitives/codex_activity_row.dart`), preserving single-node screen-reader button semantics, resting `60%` summary ink, hover promotion to `textPrimary`, and `0` Material ink splash.
2. **Inline `fileChange` `+A -D` Diff Stats & Conservative Per-Item Disclosure Boundary (`225284.O3Io.au/ap/af/ag` + `x8co` `variant: "agent-activity"`):**
   - **Re-verified `25894` per-item contract:** In `225284.O3Io` (`au(e)` -> `Object.entries(d.changes).map(...)` -> `ap(e)` -> `af(e)`/`ag(e)`), official Desktop renders **per-item, per-file** rows (`Created`/`Edited`/`Deleted` `<fileName>`, `+added -deleted`, and per-file `unifiedDiff` inside `max-h-60` `240px` `ag`).
   - **Current Native domain boundary & conservative provenance rule:** Native's `HistoryItem` and `ActivityEvent` currently carry per-item `'File changes: <count> update(s) (+<additions> -<deletions>)'` summary metadata, whereas `DiffController.snapshot` (`turn/diff/updated`) is a **turn-aggregate workspace diff** across all turn tools.
     - Extended `_fileChangesCountPattern` in `lib/src/app/presentation/conversation.dart` to render per-item `CodexInlineDiffStatsAccessory` (`12px`, `tabularFigures`, `+additions` in `theme.diffAddedText`, `-deletions` in `theme.diffRemovedText`, `4px` gap) on every `fileChange` row.
     - Added the standalone `CodexInlinePatchPreviewCard` primitive (`20px` start indent, `6px` top gap, `240px` `max-h-60` bounded scroll container, `80`-line per-file inline render cap, monospace file path header + `+A -D` stats + awaited/guarded `Copy diff` clipboard action, unified `+`/`-` line tinting, and truncation notice) in `lib/src/app/primitives/codex_activity_row.dart`.
     - **Peer review provenance remediation (superseding `6f196cee` `_isUnambiguousSingleItemTurnPatch`):** An earlier `6f196cee` heuristic attempted to disclose `DiffController.snapshot` underneath a `fileChange` row when visible `fileChange` count was `1` and `+/-` stats matched. Adversarial peer review proved visible count + `+/-` equality does **not** establish per-item content provenance (an earlier `fileChange` entry can be evicted by `ConversationController.maxEntries`, a subsequent `exec_command` in the same turn can mutate the workspace with matching net `+/-` counts, and `snapshot.truncated` bypasses stat checks). Timeline `fileChange` rows therefore **conservatively withhold item-level diff disclosure (`hasDisclosure: false`)** until the typed per-item `FileUpdateChange` seam lands, keeping turn-aggregate diffs on the turn-scoped `Changes` surface and preserving `CodexInlinePatchPreviewCard` for direct per-item binding in `U9`.
3. **Saved Non-Completed Turn Boundary-Proven Grouping (`225284.NKAf` / `IgqH`):**
   - Updated `_savedCommandGroups` in `lib/src/app/presentation/conversation.dart` so saved `interrupted` and `failed` turns group contiguous groupable exploration/activity runs (`end - start > 1`) whenever a subsequent loaded item in the same turn proves the run is closed (`end < items.length && items[end].turnId == turnId`), while keeping page-clipped tail runs flat without inspecting `historyController.canLoadMoreItems`.
4. **Numeric `exitCode` Forwarding into `CodexShellExecutionCard` (`225284.PuGl.d.Footer`):**
   - Fixed all 4 `_commandOutputFor(...)` call sites in `lib/src/app/presentation/conversation.dart` (saved standalone, saved grouped, live standalone, and live grouped) to forward `item.exitCode` / `entry.exitCode` so `PuGl.d.Footer` renders `Success` (`0`) or `Exit code <N>` (e.g. `Exit code 2`) instead of falling back to `Exit code unknown` when stock supplies a numeric exit code.
5. **Typed Non-Shell Dual-Tone & Domain Formatting (`225284.gtGM.Q`, `YoMb.B`, `O3Io.nJ`, `O3Io.nO`):**
   - `webSearch`: `_formatWebSearchQueryDetail` extracts `site:` filters, strips leading `www.`, cleans orphan boolean `OR` tokens, and formats `<query> | <domain1> · <domain2>` (`gtGM.Q`) with `verbLength` splitting `'Searched the web'` / `'Searching the web'` / `'Stopped searching the web'` (`60%` summary ink) from `' for ...'` (`30%` child ink, `YoMb.B`).
   - `collabAgentToolCall`: splits action prefix (`'Created'`, `'Waited for'`, `'Sent input to'`, `'Resumed'`, `'Closed'`) in `60%` ink from `' agent'` / `' agents'` in `30%` ink (`O3Io.nJ`).
   - `modelRerouted`: humanizes `'Model rerouted: <from> → <to> (<reason>)'` inline to `'Your request was routed to <to>.'` (`O3Io.nO`), with warning icon treatment for `highRiskCyberActivity`.
   - `hookRun`: splits `'Hook:'` prefix (`verbLength: 5`).
   - `Execution` detail mode and `Ctrl+F` search continue to expose raw diagnostic strings verbatim.

---

## 2. Non-Overlapping Writable Surface Proof

Only the agreed U8 files are modified or added relative to `ba6f27c0834c6e005904c0cda9da1ae8eed4caeb`:

- `lib/src/app/primitives/codex_activity_row.dart`
- `lib/src/app/presentation/conversation.dart`
- `lib/src/app/presentation/diff_approval_output.dart` — **`0` lines changed vs `ba6f27c`** after removing the `inlinePatch` aggregate fallback
- `test/app/u8_a7_activity_hierarchy_test.dart`
- `docs/reverse/U8_A7_ACTIVITY_HIERARCHY_EVIDENCE.md`
- `docs/reverse/APPROVAL_CHOICES_PEER_AUDIT.md` (companion read-only peer audit of `Root` commits `c2b5a64` and `474ec93`)
- `docs/reverse/FILE_UPDATE_CHANGE_SEAM_PROPOSAL.md` (source/docs-only per-item `FileUpdateChange` seam proposal)

---

## 3. Machine & Real-Stock Verification Evidence

### Machine Gates (`MACHINE VERIFIED`)
- `dart format --output=none --set-exit-if-changed` on all 4 Dart files: **PASS (`0` changed)** (`/var/tmp/native-gemini-u8-a7-r1/format.log`)
- `dart analyze --fatal-infos`: **PASS (`No issues found!`)** (`/var/tmp/native-gemini-u8-a7-r1/analyze.log`)
- `dart run tool/verify_pure_dart_boundary.dart`: **PASS (`PURE_DART_BOUNDARY=PASS (roots=68)`)** (`/var/tmp/native-gemini-u8-a7-r1/pure_dart.log`)
- `flutter test -j 1` across `u8_a7_activity_hierarchy_test.dart`, `bounded_timeline_test.dart`, `official_convergence_geometry_test.dart`, `output_dialog_test.dart`, `shell_command_card_test.dart`, `codex_primitives_test.dart`, and `product_controls_test.dart`: **PASS (`78/78` passed, `0` failures)** (`/var/tmp/native-gemini-u8-a7-r1/tests.log`)
- 2-job Linux release build & runtime bundle check (`CMAKE_BUILD_PARALLEL_LEVEL=2 CARGO_BUILD_JOBS=2 flutter build linux --release` + `dart run tool/verify_linux_runtime_bundle.dart --bundle build/linux/x64/release/bundle`): **PASS (`LINUX_RUNTIME_BUNDLE=PASS`, `SYSTEM_RUNTIME_LIBRARY_COUNT=83`)** (`/var/tmp/native-gemini-u8-a7-r1/build_linux.log`, `/var/tmp/native-gemini-u8-a7-r1/bundle_verify.log`)
  - `libapp.so` SHA-256: `4d312e4ec557cf1c4fce0f0fe01c95de2ea5d00281ccf11f2ab449dff400347b`
  - `codex_native_unofficial` SHA-256: `7975935f99c1b2b68b6e13af3395a4f3a39bd12e37d8708d3582dccb3427fb4e`
  - `codex-native-host` SHA-256: `73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878`

### Real Packaged App + Bundled Host + Stock `codex app-server` Replay (`AGENT REAL-USE VERIFIED`)
- **Preserved `r1` negative provenance (`/var/tmp/native-gemini-u8-a7-real-stock-r1`):** Initial script clicked `y=775` (above the `y=814–841` composer pill), leaving the live turn unsubmitted while already proving `01`–`03` saved `Read files and searched the web`, dual-tone `Searched the web for customscrollview | docs.flutter.dev · api.flutter.dev`, and `Exit code 2` with `0` surviving processes.
- **Preserved `r2` pre-guard replay (`/var/tmp/native-gemini-u8-a7-real-stock-r2`):** Verified all `18/18` Light/Dark PNG captures prior to adding `_isUnambiguousSingleItemTurnPatch`.
- **Source-bound `r3` full 3-session Light/Dark replay (`/var/tmp/native-gemini-u8-a7-real-stock-r3/verification.json`, `BUILD_SHA256SUMS.txt`, `SHA256SUMS.txt`):**
  - Exercised `u8-public-light` (`codex-cli 0.167.2`, Light), `u8-public-dark` (`codex-cli 0.167.2`, Dark), and `u8-alpha-light` (`/opt/codex-desktop/resources/codex` `codex-cli 0.167.0-alpha.3.2`, Light) at `1191×865`, `DPR 1` on private `Xvfb` + `dbus-run-session` + loopback `/v1/responses` SSE fixture (`240s` max-lifetime watchdog), bound directly to final `libapp.so` `4d312e4ec557cf1c4fce0f0fe01c95de2ea5d00281ccf11f2ab449dff400347b`.
  - Visually inspected captures across `00` closed saved turn -> `01` expanded `Worked for 0s` showing grouped `Read files and searched the web` + failed command -> `02` expanded group showing dual-tone `Searched the web for customscrollview | docs.flutter.dev · api.flutter.dev` + flush `Read README.md` -> `03` expanded `PuGl.d` Shell card showing numeric `Exit code 2` -> `04` live `apply_patch` turn showing `Edited a file +2 -1` -> `05` clicked `Edited a file +2 -1` disclosing `240px` `CodexInlinePatchPreviewCard` with `notes.txt +2 -1` header and `-beta` / `+beta-updated` / `+gamma-added` unified diff lines in both Light and Dark.
  - `u8-public-light` and `u8-alpha-light` produced bit-for-bit identical SHA-256 renders across states `00`–`03` and `05` (`becc024171ea9381841f25f5f48afadb9c1a843ecc332eddd083cd077a63eab2`); `15` model calls total, `0` remote-image sentinel GETs, `0` Flutter assertions/overflows in `desktop.log`, and `0` surviving App/Host/stock/Xvfb/dbus/model processes.
  - **Post-remediation provenance note (`SOURCE_ONLY_PRE_GATE`):** States `00`–`04` reflect current behavior (`Edited a file +2 -1`, boundary-proven saved grouping, `Searched the web for ... | ...`, `Exit code 2`); state `05` (`*-05-live-inline-patch-card-expanded-1191.png`) is preserved strictly as historical `6f196cee` provenance before timeline aggregate-diff disclosure was conservatively disabled pending the typed per-item `FileUpdateChange` seam (`Root` holds the exclusive heavy lease for the combined integration gate/build).

---

## 4. Honest Remaining `A7` Gaps, Proposed `Root` Seam, & Ready-to-Integrate Matrix Text

### Remaining Gaps & Negotiated `Root` Systems Seam
1. **Per-item `fileChange` file list & patch bodies (`225284.O3Io.au/ap/af`):**
   - `25894` `O3Io.au` maps `Object.entries(d.changes)` per `fileChange` item (`path`, `add`/`delete`/`update` kind, `+added -deleted`, and per-file unified diff).
   - Because `HistoryItem` and `ActivityEvent` currently carry only `'File changes: N update(s) (+A -D)'`, `U8` renders per-item `+A -D` `CodexInlineDiffStatsAccessory` metadata and conservatively withholds item-level diff disclosure (`hasDisclosure: false`) until the typed per-item `FileUpdateChange` seam lands (`docs/reverse/FILE_UPDATE_CHANGE_SEAM_PROPOSAL.md`).
2. **Streaming live `commandExecution/outputDelta` preview delivery** while a command is still in progress and **matched signed-in official screenshot comparison / Human review** remain separate open items.

### Proposed Integration Text for `docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md` (Row `A7`)
- **Official evidence addition:** ``U8 revalidates `152406.jKy0.A` inline accessory ordering, `225284.O3Io.au/ap/af/ag` + `x8co` per-item `+A -D` file-change stats and `240 px` patch preview card, `225284.NKAf` boundary-proven grouping in non-completed saved turns, `225284.gtGM.Q` + `YoMb.B` `site:` web-search dual-tone captions, and `O3Io.nJ`/`nO` collaboration and model-reroute inline captions.``
- **Native evidence / known-delta update:** ``U8 wires numeric `exitCode` across all four saved/live Shell card call sites (`Exit code 2` verified in Light/Dark `0.167.2` and `0.167.0-alpha.3.2` packaged replays), groups boundary-proven runs in saved `interrupted`/`failed` turns while keeping page-clipped tails flat, renders per-item inline `+A -D` file-change stats while conservatively withholding item-level diff disclosure until the typed per-item `FileUpdateChange` seam lands (avoiding turn-aggregate `DiffController.snapshot` misattribution; standalone `CodexInlinePatchPreviewCard` primitive is widget-tested and ready for `U9`), and translates `gtGM.Q`/`YoMb.B`/`O3Io.nJ`/`O3Io.nO` captions. Full per-item `O3Io` patch disclosure, live `commandExecution/outputDelta` streaming, and matched signed-in/Human comparison remain open.``

### Proposed Integration Text for `docs/reverse/OFFICIAL_COMPONENT_MATRIX.md` (`CodexActivityRow`)
- **Add bullet under `3.5 CodexActivityRow`:** ``- **U8 inline accessories & patch preview primitive**: `CodexInlineActivityHeader` and `CodexActivityRow` add an `accessory` slot (`152406.jKy0.A`) used by `CodexInlineDiffStatsAccessory` (`12px` `tabularFigures` `+A -D`), alongside the bounded `CodexInlinePatchPreviewCard` primitive (`20px` start indent, `240px` max height, `80`-line per-file cap, awaited/guarded hover/focus `Copy diff`, staged for per-item `FileUpdateChange` binding). Numeric `exitCode` now reaches `CodexShellExecutionCard` from all saved/live timeline and group call sites.``

---

## 5. Companion Peer Audit Reference

The targeted peer audit of `Root` commit `c2b5a64aad831f4d9219fb323702bfc1c72e57bf` (`agent/codex-approval-choices`) is recorded in [`docs/reverse/APPROVAL_CHOICES_PEER_AUDIT.md`](./APPROVAL_CHOICES_PEER_AUDIT.md) (`0 P0`, `1 P1`, `2 P2`, `1 INVALID` candidate cleared via `25894` `474578`).


## Root integration gate follow-up

Combined production merge `1f20a78` passes format/strict analysis/pure69.
The first full Flutter run records723 passes/five skips/one failure: the new
standalone preview test expected the virtualized footer before scrolling. The
integration correction exercises the actual list, checks the80-line boundary
and footer, then returns to the clipboard flow. All5 U8 cases pass on that
correction (`approval-u8-scroll-test-r2.log`). Production rendering is unchanged;
virtualization stays enabled. The negative remains in `approval-u8-shared-r1.log`;
fresh shared gates and packaged approval capture are separately pending.
