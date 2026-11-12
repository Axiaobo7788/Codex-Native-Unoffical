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
2. **Inline `fileChange` `+A -D` Diff Stats & Unambiguous Single-Item `240px` Patch Preview Card (`225284.O3Io.au/ap/af/ag` + `x8co` `variant: "agent-activity"`):**
   - **Re-verified `25894` per-item contract:** In `225284.O3Io` (`au(e)` -> `Object.entries(d.changes).map(...)` -> `ap(e)` -> `af(e)`/`ag(e)`), official Desktop renders **per-item, per-file** rows (`Created`/`Edited`/`Deleted` `<fileName>`, `+added -deleted`, and per-file `unifiedDiff` inside `max-h-60` `240px` `ag`).
   - **Current Native domain boundary & truthful gating:** Native's `HistoryItem` and `ActivityEvent` currently carry only `'File changes: <count> update(s) (+<additions> -<deletions>)'` (per-item counts/stats computed by `HistoryProtocolAdapter` / `TurnProtocolAdapter`), while `DiffController.snapshot` carries the **turn-aggregate** `turn/diff/updated` snapshot. To keep presentation strictly truthful without rewriting protocol/domain in this visual slice:
     - Extended `_fileChangesCountPattern` in `lib/src/app/presentation/conversation.dart` to render per-item `CodexInlineDiffStatsAccessory` (`12px`, `tabularFigures`, `+additions` in `theme.diffAddedText`, `-deletions` in `theme.diffRemovedText`, `4px` gap) on every `fileChange` row.
     - Added `CodexInlinePatchPreviewCard` (`20px` start indent, `6px` top gap, `240px` `max-h-60` bounded scroll container, `80`-line per-file inline render cap, monospace file path header + `+A -D` stats + hover/focus `Copy diff` clipboard action, unified `+`/`-` line tinting, and truncation notice).
     - Guarded disclosure via `_isUnambiguousSingleItemTurnPatch`: `CodexInlinePatchPreviewCard` is offered **only** when `snapshot.turnId == turnId`, the turn has **exactly one** `fileChange` item (`liveFileChanges == 1` or unclipped `savedFileChanges == 1`), and `snapshot.files.length` + `+A -D` stats match the item's `editedFileCount` and `+A -D` stats. Whenever a turn has `>= 2` `fileChange` items, clipped saved pages, or no turn-matched snapshot, rows truthfully display per-item `+A -D` stats with `hasDisclosure: false` (never misattributing an `A + B` aggregate turn diff to a single-item row).
     - **This slice does NOT claim closure of multi-item or cold-saved per-item `O3Io` patch parity**; see Section 4 for the proposed `Root`-owned typed protocol/domain seam.
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

Only the agreed U8 files were modified or added relative to `ba6f27c0834c6e005904c0cda9da1ae8eed4caeb`:

- `lib/src/app/primitives/codex_activity_row.dart`
- `lib/src/app/presentation/conversation.dart`
- `lib/src/app/presentation/diff_approval_output.dart` — **first diff hunk is `@@ -422,0 +423 @@ class _HistoryEntryView` (`0` edits in lines `1–412`, leaving `_ApprovalBanner` `270–412` 100% untouched for clean merge with `agent/codex-approval-choices`)**
- `test/app/u8_a7_activity_hierarchy_test.dart`
- `docs/reverse/U8_A7_ACTIVITY_HIERARCHY_EVIDENCE.md`
- `docs/reverse/APPROVAL_CHOICES_PEER_AUDIT.md` (companion read-only peer audit of `Root` commit `c2b5a64`)

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

---

## 4. Honest Remaining `A7` Gaps, Proposed `Root` Seam, & Ready-to-Integrate Matrix Text

### Remaining Gaps & Negotiated `Root` Systems Seam
1. **Per-item `fileChange` file list & patch bodies (`225284.O3Io.au/ap/af`):**
   - `25894` `O3Io.au` maps `Object.entries(d.changes)` per `fileChange` item (`path`, `add`/`delete`/`update` kind, `+added -deleted`, and per-file unified diff).
   - Because `HistoryItem` and `ActivityEvent` currently carry only `'File changes: N update(s) (+A -D)'`, `U8` keeps multi-`fileChange`-item turns and cold saved turns strictly truthful (`+A -D` stats only, `hasDisclosure: false`) and discloses `CodexInlinePatchPreviewCard` only when `_isUnambiguousSingleItemTurnPatch` proves `DiffController.snapshot` belongs to the turn's sole `fileChange` item.
   - **Proposed `Root`-owned systems seam:** Expose bounded per-item `List<FileChangePatch>` (or Host-backed lazy per-item diff reference from public v2 `item/completed` `fileChange.changes` `FileUpdateChange` / `FileChangePatchUpdatedNotification` / `ThreadReadResponse`) on `ActivityEvent` and `HistoryItem`, with per-item byte/file caps matching `DiffProtocolAdapter`. Once available, `CodexInlinePatchPreviewCard` and per-file `Created`/`Edited`/`Deleted <basename>` captions can bind directly to per-item data without consulting `DiffController.snapshot`.
2. **Streaming live `commandExecution/outputDelta` preview delivery** while a command is still in progress and **matched signed-in official screenshot comparison / Human review** remain separate open items.

### Proposed Integration Text for `docs/reverse/OFFICIAL_UI_GOLDEN_STATE_A.md` (Row `A7`)
- **Official evidence addition:** ``U8 revalidates `152406.jKy0.A` inline accessory ordering, `225284.O3Io.au/ap/af/ag` + `x8co` per-item `+A -D` file-change stats and `240 px` patch preview card, `225284.NKAf` boundary-proven grouping in non-completed saved turns, `225284.gtGM.Q` + `YoMb.B` `site:` web-search dual-tone captions, and `O3Io.nJ`/`nO` collaboration and model-reroute inline captions.``
- **Native evidence / known-delta update:** ``U8 wires numeric `exitCode` across all four saved/live Shell card call sites (`Exit code 2` verified in Light/Dark `0.167.2` and `0.167.0-alpha.3.2` packaged replays), groups boundary-proven runs in saved `interrupted`/`failed` turns while keeping page-clipped tails flat, renders per-item inline `+A -D` file-change stats and bounded `240 px` `CodexInlinePatchPreviewCard` (`16`-key cap, gated by `_isUnambiguousSingleItemTurnPatch` so multi-edit turns and cold saved turns never misattribute turn-aggregate diffs), and translates `gtGM.Q`/`YoMb.B`/`O3Io.nJ`/`O3Io.nO` captions (`74` targeted widget/simulated tests green). Full per-item `O3Io` multi-edit/saved patch parity awaits a typed `FileUpdateChange` protocol/domain seam; live `commandExecution/outputDelta` streaming and matched signed-in/Human comparison remain open.``

### Proposed Integration Text for `docs/reverse/OFFICIAL_COMPONENT_MATRIX.md` (`CodexActivityRow`)
- **Add bullet under `3.5 CodexActivityRow`:** ``- **U8 inline accessories & patch preview**: `CodexInlineActivityHeader` and `CodexActivityRow` add an `accessory` slot (`152406.jKy0.A`) used by `CodexInlineDiffStatsAccessory` (`12px` `tabularFigures` `+A -D`) alongside `CodexInlinePatchPreviewCard` (`20px` start indent, `240px` max height, `80`-line per-file cap, hover/focus `Copy diff`). Numeric `exitCode` now reaches `CodexShellExecutionCard` from all saved/live timeline and group call sites.``

---

## 5. Companion Peer Audit Reference

The targeted peer audit of `Root` commit `c2b5a64aad831f4d9219fb323702bfc1c72e57bf` (`agent/codex-approval-choices`) is recorded in [`docs/reverse/APPROVAL_CHOICES_PEER_AUDIT.md`](./APPROVAL_CHOICES_PEER_AUDIT.md) (`0 P0`, `1 P1`, `2 P2`, `1 INVALID` candidate cleared via `25894` `474578`).
