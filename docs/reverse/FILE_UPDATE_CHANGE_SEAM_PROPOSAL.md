# Bounded Per-Item `FileUpdateChange` Seam Proposal (`Track F` ↔ `Track U`)

- **Status:** `SEAM_PROPOSAL_CALIBRATED — OWNERSHIP_NEGOTIATION_READY` (`SOURCE/DOCS-ONLY`; `0` protocol/domain/controller code edits)
- **Base U8 commit preserved untouched:** `6f196cee637c4bde05132524e134dca41af1883c` (`origin/agent/gemini-golden-ui-u8-a7-hierarchy`)
- **Evidence classes:**
  - Public/stable stock schema: `codex-cli 0.167.2` (`/var/tmp/native-stock-0.167.2-audit-r1/schema-stable/codex_app_server_protocol.v2.schemas.json`)
  - Installed Desktop-train stock schema: `codex-cli 0.167.0-alpha.3.2` (`/var/tmp/native-functional-audit-dgjz20ng/desktop-train-stable/codex_app_server_protocol.v2.schemas.json`)
  - Real persisted stock rollouts (`AGENT REAL-USE VERIFIED`): `/var/tmp/native-gemini-u8-a7-real-stock-r3/session-u8-public-light/.../rollout-*.jsonl` (line `33`) and `session-u8-alpha-light/.../rollout-*.jsonl` (line `33`)
  - Official Desktop `25894` ASAR (`26.1103.60933`): `/webview/assets/182735.5b42af8792.js` (`@951926`, `@2034640`, `@5067413`, `@5106511`, `@5119863`, `@5224278`) and `225284` (`O3Io.au/ap/af/ag/ax`, lines `1817–2108`)

---

## 1. Problem Statement

In `U8` (`6f196cee`), `lib/src/app/presentation/conversation.dart:6808–6918` gates `CodexInlinePatchPreviewCard` behind `_isUnambiguousSingleItemTurnPatch` because:

1. `HistoryProtocolAdapter._parseItem` (`lib/src/protocol/history_protocol.dart:433–439`) and `TurnProtocolAdapter._parseItem` (`lib/src/protocol/turn_protocol.dart:602–617, 674, 699–732`) reduce `fileChange.changes` to a summary string `'File changes: <count> update(s) (+A -D)'` and discard per-item `changes`.
2. `DiffController.snapshot` comes from `turn/diff/updated`, which is the **turn-aggregate** unified diff (`A + B` when a turn has two `fileChange` items) and is absent on cold-loaded saved turns.
3. Official Codex Desktop `25894` (`225284.O3Io.au` -> `Object.entries(d.changes).map(...)` -> `ap`) renders **per-item, per-file** rows (`Created` / `Edited` / `Deleted <basename>`, `+added -deleted`, and bounded per-file diff preview) directly from each `fileChange` item's own `changes`.

---

## 2. Verified Public Stable (`0.167.2`) & Installed (`0.167.0-alpha.3.2`) Wire Contract

Across **both** `0.167.2` stable and `0.167.0-alpha.3.2` stable v2 schemas, all required types and notifications are **public, non-experimental, and byte-for-byte identical**:

1. **`ThreadItem` (`type: "fileChange"`)** — carried in `item/started`, `item/completed`, `thread/items/list` (`ThreadItemEntry.item`), `thread/read`, and `thread/items/read`:
   ```json
   {
     "id": "string",
     "type": "fileChange",
     "status": "inProgress | completed | failed | declined",
     "changes": [
       {
         "path": "string",
         "kind": { "type": "add" }
              | { "type": "delete" }
              | { "type": "update", "move_path": "string | null" },
         "diff": "string"
       }
     ]
   }
   ```
2. **Live streaming notification — `item/fileChange/patchUpdated` (`FileChangePatchUpdatedNotification`, stable):**
   ```json
   {
     "threadId": "string",
     "turnId": "string",
     "itemId": "string",
     "changes": [ /* Array<FileUpdateChange> */ ]
   }
   ```
   - Official `25894` (`182735.5b42af8792.js @951926`) handles `item/fileChange/patchUpdated` by replacing `r.changes` on the existing `(threadId, turnId, itemId)` `fileChange` item, or inserting an `inProgress` `fileChange` item if `patchUpdated` arrives before `item/started`.
3. **Deprecated notification — `item/fileChange/outputDelta`:**
   - Marked deprecated in both schemas (`"The server no longer emits this notification."`). Do **not** subscribe.

---

## 3. Three Critical Wire-Format Traps Proven by Real Stock Data + `25894`

### Trap 1 — `FileUpdateChange.diff` has NO `diff --git` header (`UnifiedDiffParser` would return `[]`)
- Real `r3` stock rollouts on **both** `0.167.2` and `0.167.0-alpha.3.2` (`line 33`) emit hunk-only unified diffs for `update`:
  ```json
  "changes": {
    "/var/tmp/native-gemini-u8-a7-real-stock-r3/project/notes.txt": {
      "type": "update",
      "unified_diff": "@@ -1,2 +1,3 @@\n alpha\n-beta\n+beta-updated\n+gamma-added\n",
      "move_path": null
    }
  }
  ```
- Existing `UnifiedDiffParser.parse` (`lib/src/protocol/unified_diff_parser.dart:69`) ignores every line prior to `line.startsWith('diff --git ')`. Passing `FileUpdateChange.diff` into `UnifiedDiffParser` silently drops **100%** of real stock `FileUpdateChange` entries.

### Trap 2 — `kind.type == "add"` and `"delete"` carry raw file content in `diff` (exposing a bug in existing `_fileChangeSummary`)
- Official `25894` `Y.LU` (`182735.5b42af8792.js @5106511`) and `aCkJ.bl` (`@5067413`) prove the exact v2 `FileUpdateChange` semantics:
  - `kind.type == "add"` -> `diff` is the **raw added file content** (not `+`-prefixed). `aCkJ.bl` normalizes `\r\n` -> `\n`, splits on `\n`, drops a trailing `""` after a trailing newline, and synthesizes `@@ -0,0 +1,N @@` with `+` prefixed on every content line (`additions = N, deletions = 0`).
  - `kind.type == "delete"` -> `diff` is the **raw deleted file content** (or `""`). `aCkJ.bl` synthesizes `@@ -1,N +0,0 @@` with `-` prefixed on every content line (`additions = 0, deletions = N`); when `diff == ""`, `O3Io.ap` (`line 1952`) renders `"Contents deleted"`.
  - `kind.type == "update"` -> `diff` is `unified_diff` (`@@ ... @@` hunks, or already-headed diff). `+`/`-` lines (excluding `+++`/`---`) give `additions`/`deletions`; when `diff == ""`, `O3Io.ap` (`line 1955`) renders `"No changes"`.
- **Existing Native protocol defect exposed:** `TurnProtocolAdapter._fileChangeSummary` (`lib/src/protocol/turn_protocol.dart:716–725`) and `HistoryProtocolAdapter._fileChangeSummary` currently count `line.startsWith('+')` / `line.startsWith('-')` on `entry['diff']` without checking `entry['kind']`. For a newly created (`add`) Markdown file containing `- bullet` lines, Native currently reports `0` additions and `N` **deletions**! Parsing `kind` fixes both per-item previews and summary stats.

### Trap 3 — `FileUpdateChange.path` and `kind.move_path` are absolute host paths
- Both `0.167.2` and `0.167.0-alpha.3.2` rollouts (`line 33`) emit absolute filesystem paths (`"/var/tmp/.../project/notes.txt"`).
- Official `25894` (`aCkJ.h @5076004`, `O3Io.tx @1961`) relativizes `path` and `move_path` against `thread.cwd` when inside the workspace root (showing workspace-relative path in card header/tooltip and basename in the collapsed `Created` / `Edited` / `Deleted <basename>` activity row). Path relativization belongs in pure presentation/helper formatting using `ThreadSummary.cwd`, while domain/protocol retains the normalized bounded wire path.

---

## 4. Proposed Bounded Seam Design

### Tier 1 — Pure Dart Protocol / Domain / Controller Seam (Recommended Immediate `Root` Slice)

#### 4.1 Domain Models (`lib/src/domain/diff_models.dart`, wired to `turn_models.dart` & `history_models.dart`)
```dart
enum FileChangeKind { add, delete, update }

class FileChangeEntry {
  const FileChangeEntry({
    required this.path,
    required this.kind,
    this.movePath,
    required this.additions,
    required this.deletions,
    this.previewLines = const [],
    this.truncated = false,
    this.previewTooLarge = false,
  });

  final String path;
  final FileChangeKind kind;
  final String? movePath;
  final int additions;
  final int deletions;
  /// Normalized unified-diff lines (`@@ ... @@`, `+...`, `-...`, ` ...`),
  /// bounded at parse time so UI never re-parses or stores raw full-file text.
  final List<String> previewLines;
  final bool truncated;
  /// True when input `diff.length` exceeded `maxInputCharactersPerFile`
  /// (maps to official `25894` `O3Io` `"Diff too large to preview"`).
  final bool previewTooLarge;
}
```
- **Additions on `ActivityEvent`, `ConversationEntry`, and `HistoryItem`:**
  - `final List<FileChangeEntry> fileChanges` (default `const []`)
  - `final int totalFileChangeCount` (default `0`, preserving true `changes.length` when `changes.length > maxFilesPerItem`)
- **Addition on `TurnEvent` (`lib/src/domain/turn_models.dart`):**
  - `class FileChangePatchUpdatedEvent extends TurnEvent` carrying `{ threadId, turnId, itemId, summary, fileChanges, totalFileChangeCount }`.

#### 4.2 Hard Memory & CPU Bounds (`AGENTS.md` Non-Negotiable Rule 2)
 Parse-time bounds in `FileUpdateChangeParser` (`lib/src/protocol/file_update_change_parser.dart`):
- `maxFilesPerItem = 24` (excess entries are not retained as `FileChangeEntry`, while `totalFileChangeCount` records bounded `min(rawChanges.length, 10000)`)
- `maxPathCharacters = 512` (`path` and optional `movePath`)
- `maxInputCharactersPerFile = 256 * 1024` (`256 KiB` — if `diff.length > 256 KiB`, **do not split/scan the full string**; emit `previewTooLarge: true, previewLines: const [], additions: 0, deletions: 0`)
- `maxPreviewLinesPerFile = 80` (matches `CodexInlinePatchPreviewCard.maxRenderedLinesPerFile = 80`, avoiding retaining lines the inline card will never render; stats still scan up to `maxInputCharactersPerFile` in streaming `indexOf('\n')` style without allocating `diff.split('\n')`!)
- `maxCharactersPerLine = 512`
- `maxStoredCharactersPerItem = 24 * 1024` (`24 KiB` total across all `previewLines` in one `fileChange` item)

**Memory proof:**
- Typical 1–3 file edit item: `~1–4 KiB`.
- Adversarial worst case: `<= 24 KiB` per `fileChange` item (`0` retained raw `diff` strings; `0` allocations via `diff.split('\n')`; `0` bytes retained on inactive threads because `HistoryController` clears `_turns` / `_selectedTurnItems` on thread switch).

#### 4.3 Protocol & Controller Behavior
1. **`FileUpdateChangeParser`:**
   - Used by **both** `TurnProtocolAdapter` and `HistoryProtocolAdapter` so live and saved `fileChange` items produce identical `fileChanges`, `totalFileChangeCount`, and `kind`-accurate `(+A -D)` summary text.
   - Index-scans `diff` with `indexOf('\n', offset)` (like `UnifiedDiffParser`, zero intermediate `List<String>` split):
     - `add`: every logical content line increments `additions` and emits `+$boundedLine` (with synthetic leading `@@ -0,0 +1,N @@` or direct `+` lines).
     - `delete`: every logical content line increments `deletions` and emits `-$boundedLine`.
     - `update`: lines starting with `+` (not `+++`) increment `additions`, `-` (not `---`) increment `deletions`, and lines from the first `@@` (or content lines if hunkless) populate `previewLines`.
2. **`TurnProtocolAdapter._parseNotification`:**
   - Add `'item/fileChange/patchUpdated' => _parseFileChangePatchUpdated(params)`.
3. **`ConversationController._handleEvent`:**
   - On `ActivityEvent`: carry `event.fileChanges` and `event.totalFileChangeCount` into `ConversationEntry` (preserving existing non-empty `fileChanges` if a terminal event ever omits them, otherwise replacing with the newer snapshot).
   - On `FileChangePatchUpdatedEvent`: update matching `(turnId, stockItemId)` `ConversationEntry` **in place** (replacing `fileChanges` / `totalFileChangeCount` / `text`, never appending), or insert an `inProgress` `ConversationEntryKind.activity` entry if `patchUpdated` arrives before `item/started` (matching `25894` `182735.js @951926`), respecting `maxEntries`.

### Tier 2 — Separate Optional Rust Host Spooling Note (Android Remote Only)

- Inspection of `native_host/src/transform.rs:12, 18–19, 154–170` confirms `codex-native-host` currently spools **only** `TARGET_KEY = b"aggregatedOutput"` on `commandExecution`, while capping Remote WebSocket frames at `MAX_REMOTE_NOTIFICATION_BYTES = 256 KiB` and `MAX_REMOTE_RESPONSE_BYTES = 1024 * 1024 - 4096` (~`1 MiB`).
- **Superseded by Section 7:** Dart JSONL has no frame cap, but the production Host CandidateFile has an8MiB sanitized-forward cap. Pure-Dart eager previews alone do not close the large-file path; the next slice requires bounded Host spooling.
- Because `PROJECT_STATUS.md` defers new Android / Direct Host Remote expansion unless required to maintain existing correctness, Tier 1 should land cleanly in pure Dart first; `Root` can record Remote `>256 KiB` `patchUpdated` / `>1 MiB` `thread/items/list` `fileChange.changes[*].diff` spooling as a separate tracked Remote note if desired.

---

## 5. Proposed Non-Overlapping Peer Ownership Split

1. **Slice F-FileChange (`Root` / Codex preferred — systems, protocol, domain, controller):**
   - **Write surface:**
     - `lib/src/domain/diff_models.dart`, `lib/src/domain/turn_models.dart`, `lib/src/domain/history_models.dart`
     - `lib/src/protocol/file_update_change_parser.dart`, `lib/src/protocol/turn_protocol.dart`, `lib/src/protocol/history_protocol.dart`
     - `lib/src/features/conversation/conversation_controller.dart`
     - `test/protocol/...` & `test/features/conversation/...` + real-stock `add` / `update` / `delete` / multi-item verification.
   - **Zero overlap with Track U (`0` edits in `lib/src/app/`).**
2. **Slice U9 (`Gemini` — `225284.O3Io` per-item/per-file presentation binding after `F-FileChange` lands, while continuing an independent Golden-State row in parallel during `F-FileChange`):**
   - **Write surface:**
     - `lib/src/app/presentation/conversation.dart` & `lib/src/app/primitives/codex_activity_row.dart`
   - **Scope:**
     - Bind `fileChange` rows and `CodexInlinePatchPreviewCard` directly to `entry.fileChanges` / `item.fileChanges` across multi-edit live turns, streaming `patchUpdated`, and cold saved turns.
     - Translate `225284.O3Io.au/ap/af/ag/ax` per-file states (`Created` / `Creating` / `Edited` / `Editing` / `Deleted` / `Deleting <basename>`, workspace-relative header path via `thread.cwd`, `movePath` display, `"Contents deleted"`, `"No changes"`, `"Diff too large to preview"`).
     - Retire `_isUnambiguousSingleItemTurnPatch` and remove the `DiffController.snapshot` fallback from inline timeline rows.

---

## 6. `_SingleFilePatchCardState._copyDiff` P2 Check & Disposition

- **Peer observation verified (`VALID P2`):**
  - In `6f196cee`, `_SingleFilePatchCardState._copyDiff` (`lib/src/app/primitives/codex_activity_row.dart:1633–1645`, wired at `:1832`) calls `unawaited(Clipboard.setData(ClipboardData(text: payload)))` and synchronously runs `setState(() => _copied = true)`.
  - Compared against `_CodexShellExecutionCardState._handleCopyCommand` / `_handleCopyOutput` (`lib/src/app/primitives/codex_activity_row.dart:1065–1091`), synchronous `_copied = true` before awaiting `Clipboard.setData` can both surface an unhandled async `PlatformException` and falsely display `'Copied'` when the clipboard write fails or before the widget unmounts.
- **Disposition (zero-friction dual path):**
  1. `origin/agent/gemini-golden-ui-u8-a7-hierarchy` is left **untouched at `6f196cee637c4bde05132524e134dca41af1883c`** so `Root`'s audit/merge of the gated `r3` commit stays bound to its exact tested SHA.
  2. A minimal surgical fix (`Future<void> _copyDiff() async` with `try { await Clipboard.setData(...); } on Object { return; } if (!mounted) return;` + `onPressed: () => unawaited(_copyDiff())` + 1 failure/unmount widget test, zero framework rewrite) is staged as a clean cherry-pickable commit on `origin/agent/gemini-file-change-seam` (`SOURCE_ONLY_PRE_GATE` while `Root` holds the heavy lease), **and Gemini explicitly releases `_SingleFilePatchCardState._copyDiff` (`codex_activity_row.dart:1633–1645, 1832`) to `Root`** so `Root` may cherry-pick or fold it directly during the active integration gate.

---

## 7. Targeted Peer Audit of `ac47002` & Source-Evidenced Host-Spooling Constraints (`2026-11-12`)

- **Reviewed `ac47002ed954ed68c96359ec155ac79966be0cd6` (`d29cffe` / `5dd4758`):** `SOURCE_INSPECTED_0_HEAVY` (tests not run by Gemini under active `Root` exclusive heavy lease; `4a8f83a` recorded as `SOURCE_ONLY_PRE_GATE` prior to `5dd4758` virtualized-footer scroll test fix).
- **`ac47002` Disposition — `0 P0 / 0 P1 / 0 P2`:**
  - Inspected all 5 changed files: `lib/src/protocol/file_change_summary.dart` (`1–72`), `lib/src/protocol/history_protocol.dart` (`157, 170, 334, 349, 438`), `lib/src/protocol/turn_protocol.dart` (`244–245, 675`), `test/protocol/file_change_summary_test.dart` (`1–107`), and `docs/reverse/FILE_CHANGE_STATISTICS_EVIDENCE.md`.
  - Verified all four live and saved `fileChange` parse paths (`item/started`, `item/completed`, `thread/items/list`, and `thread/read`) route through `fileChangeSummary(changes)`.
  - Verified `indexOf('\n', offset)` (the bounded loop in the72-line `ac47002` helper) avoids `split('\n')` allocations, excludes trailing-`\n` phantom lines on `add`/`delete`, preserves interior blank lines (`\r\n\r\n` / `\n\n`), tracks `insideHunk` (`@@` sets `true`, `diff --git ` sets `false`) so `+++`/`---` content inside hunks is counted while file headers outside hunks are skipped, and conservatively returns count-only `'File changes: $count update(s)'` on unknown `kind['type']`, `> 100` files, `> 256 Ki` UTF-16 code units per file, or `> 2 Mi` code units per item.

### 7.1 Why Production Host Spooling Supersedes Section 4's Eager `24 KiB`/Item Proposal

1. **Host `CandidateFile` `8 MiB` forward cap (`native_host/src/spool.rs:638–649` + `native_host/src/config.rs:12`):**
   - Section 4.3 (`line 156`) previously assumed Desktop stdio had no frame cap. Source inspection disproves that: `CandidateFile::write` enforces `DEFAULT_MAX_FORWARD_MESSAGE_BYTES = 8 * 1024 * 1024` (`8,388,608` bytes) on **every** transformed app-server message before `publish_to(output)` (`transform.rs:419`). Any unsanitized `item/completed`, `item/fileChange/patchUpdated`, `thread/read`, or `thread/items/list` message whose `changes[*].diff` total exceeds `8 MiB` aborts `transform_stream` with `InvalidData("sanitized app-server message exceeds 8388608 bytes")` and drops the app-server stdio session.
2. **Unbounded Dart JSONL decode (`lib/src/protocol/jsonl_decoder.dart:15–19`):**
   - Even below `8 MiB`, `utf8.decoder` + `LineSplitter` + `jsonDecode` materializes the entire raw diff string as UTF-16 on the Flutter UI isolate before any Dart parser can bound `previewLines`, and retaining `24 KiB` eagerly across `100` saved + `200` live timeline entries holds up to `~7.2 MiB` of cold widget-state strings that are never expanded.
3. **Exhaustive v2 schema path uniqueness (`0.167.2` stable & `0.167.0-alpha.3.2` experimental):**
   - Full scan of `$defs`/`definitions` in `/var/tmp/native-stock-0.167.2-audit-r1/schema-stable/codex_app_server_protocol.v2.schemas.json` and `/var/tmp/native-functional-audit-dgjz20ng/desktop-train-experimental/codex_app_server_protocol.v2.schemas.json` confirms `"changes"` exists **only** on `FileChangeThreadItem` and `FileChangePatchUpdatedNotification`.
   - Matching `<each of the 10 COMMAND_ITEM_PATHS in native_host/src/transform.rs:154–170> + [Changes, Element]` plus `&[Params, Changes, Element]` on key `b"diff"` covers 100% of live, saved, and experimental `FileUpdateChange.diff` locations (`item/started`, `item/completed`, `item/fileChange/patchUpdated`, `thread/items/list`, `thread/items/read`, `thread/read`, `initialTurnsPage`, `turn/completed`, `thread/started`) with **zero collision** against:
     - `TurnDiffUpdatedNotification` (`&[Params]` + key `b"diff"`, consumed by `DiffController`),
     - `FileChangeRequestApprovalParams` (`FileChangeRequestApprovalParams.json:3–38`: carries `{grantRoot, itemId, reason, startedAtMs, threadId, turnId}`, no `changes` or `diff`),
     - legacy `ApplyPatchApprovalParams` (`ApplyPatchApprovalParams.json:4–85`: uses `fileChanges` map with `content` / `unified_diff`, not `changes[*].diff`), or
     - opaque `mcpToolCall` / `dynamicToolCall` `arguments` and `result.structuredContent` (`transform.rs:714–728`).

### 7.2 Four Source-Proven Constraints Required for Host-Spooled `FileUpdateChange.diff`

1. **Constraint 1 — Key-Order-Independent Parallel Content & Unified-Hunk Metrics:**
   - **Evidence:** `FileUpdateChange` (`{"diff": "string", "kind": PatchChangeKind, "path": "string"}`) is a JSON object where RFC 8259 allows arbitrary key order and canonical alphabetical ordering emits `"diff"` (`'d'`) **before** `"kind"` (`'k'`); compare `native_host/src/transform.rs:731–789` (`spools_direct_command_output_at_each_supported_path_in_any_key_order`).
   - **Contract:** `transform.rs` must not assume `kind.type` is known while streaming `"diff"`. During `JsonStringDecoder::feed` on `"diff"`, maintain parallel `O(1)` counters for **both** raw content lines (`rawLines`, applicable to `kind.type == "add" | "delete"`) and hunk-aware unified diff lines (`hunkAdditions`, `hunkDeletions`, applicable to `kind.type == "update"` or legacy absent `kind`), emitting the sibling `_codexNativeDiff` object immediately at `Event::StringEnd` (paralleling `_codexNativeOutput` at `transform.rs:351–365`). Dart resolves `(additions, deletions)` once the full `FileUpdateChange` map (including `kind`) is decoded, regardless of JSON key order.
2. **Constraint 2 — Bounded `11`-Byte Line-Prefix State Machine (`chunk_size = 1` & `\uXXXX` Escape Invariance):**
   - **Evidence:** `native_host/src/transform.rs:10, 318–320` reads `16 KiB` chunks (`INPUT_BUFFER_BYTES`) and passes raw string fragments through `JsonStringDecoder::feed` (`native_host/src/json_string.rs:33–136`), which invokes `emit(&[u8])` at every chunk boundary and around every JSON escape (`\"`, `\\`, `\n`, `\r`, `\uXXXX`, surrogate pairs at `json_string.rs:43–45, 69, 83, 125`).
   - **Contract:** Never test `fragment.starts_with(...)` directly on `emit` slices (which breaks under `chunk_size = 1` at `transform.rs:698` or escaped `\u002d\u002d\u002d`). Maintain a fixed `[u8; 11]` per-line prefix buffer (`b"diff --git ".len() == 11`) + `prefix_len: u8` + `at_line_start: bool`: increment `rawLines` on the first decoded byte of each line (`at_line_start == true`, matching `ac47002` no-trailing-`\n`-phantom semantics), accumulate up to `11` bytes before `\n`, and classify `prefix[..prefix_len]` once at `\n` or `finish()` (`@@` -> `inside_hunk = true`; `diff --git ` -> `inside_hunk = false`; leading `+` when `inside_hunk || !starts_with(b"+++")` -> `hunkAdditions += 1`; leading `-` when `inside_hunk || !starts_with(b"---")` -> `hunkDeletions += 1`).
3. **Constraint 3 — Shared `CandidateFile` Schema Validity (`"diff": ""`, NOT `null`) & Remote Read-Only Compatibility:**
   - **Evidence:**
     - In `0.167.2` and `0.167.0-alpha.3.2` `codex_app_server_protocol.v2.schemas.json`, `CommandExecutionThreadItem.aggregatedOutput` has type `["string", "null"]` (so `transform.rs:289` writing `b"null"` is schema-valid), **whereas `FileUpdateChange.diff` has required non-nullable `"type": "string"`**.
     - `native_host/src/transform.rs:391–418` (`capture_bounded(MAX_REMOTE_RESPONSE_BYTES)` at `1 MiB - 4 KiB` and `publish_to_with_capture(output, MAX_REMOTE_NOTIFICATION_BYTES)` at `256 KiB`) feeds the **exact same transformed `CandidateFile`** to Desktop stdout and to `RemoteCoordinator::receive` (`native_host/src/remote_bridge.rs:99, 155–158` for `thread/read`, `thread/items/list`, `thread/items/read`) plus `is_remote_notification` (`transform.rs:537–538` for `item/started`, `item/completed`).
   - **Contract:** Replace `"diff"` in `CandidateFile` with **`""` (`b"\"\""`, empty JSON string — never `null`)** followed by `,"_codexNativeDiff":{...}`. That keeps `FileUpdateChange.diff` a valid JSON string for raw-string/schema consumers on the shared Remote path, prevents `>256 KiB` / `>1 MiB` Remote message drops on large `fileChange` items, and lets `fileChangeSummary` (`lib/src/protocol/file_change_summary.dart`) compute exact `(+A -D)` captions from `kind` + `_codexNativeDiff` on both Desktop and existing read-only Remote without adding any Remote RPC (while direct-stock stdio without Host retains bounded pure-Dart `String` parsing). When Desktop expands a file and calls `host/output/readRange`, decode bounded byte chunks with UTF-8 codepoint-boundary safety in case `readRange` slices mid-character.
4. **Constraint 4 — Shared `16,384` `SpoolStore` Object Quota & Post-Restart Descriptor Retirement:**
   - **Evidence:**
     - `native_host/src/spool.rs:17, 340–342, 479–482` enforces a session-wide non-evicting cap `MAX_SESSION_OUTPUT_OBJECTS = 16 * 1024` (`16,384`) on `OutputIndex.by_identity`, shared between `commandExecution` and any spooled `FileUpdateChange.diff`, with two synchronous file writes/renames (`<uuid>.data` + `<uuid>.json`, `spool.rs:494–515`) per newly stored hash on the `transform_stream` thread. Exhausting `16,384` distinct hashes causes `OutputRegistration::CapacityReached` -> `available: false` (`spool.rs:546–555`) for all subsequent outputs in that Host session.
     - Spool `ref`s are scoped to one `session-<timestamp>-<uuid>` directory (`spool.rs:125`) and expire across hot Host restarts (`55dcf16`). `ConversationController.invalidateRuntime` (`lib/src/features/conversation/conversation_controller.dart:273`) and `HistoryController` (`lib/src/features/conversation/history_controller.dart:378`) already retire `commandOutput` / `output` via `OutputDescriptor.withoutSessionReference()` (`lib/src/domain/output_models.dart:23–30`).
   - **Contract:**
     - Retire per-file diff descriptors via `withoutSessionReference()` in **both** `ConversationController.invalidateRuntime` (`conversation_controller.dart:273`) and `HistoryController` (`history_controller.dart:378`) upon runtime invalidation/disconnect.
     - Retain only per-file metadata + opaque `OutputDescriptor` on `HistoryItem` / `ConversationEntry` at rest (`0` eager preview lines across the `100` saved / `200` live window), load bounded per-file preview bytes lazily on user expansion, and when a descriptor is unavailable/retired (`!available` after Host restart, Remote read-only session, or `CapacityReached`), either re-read the single turn/item through the live Desktop Host (`thread/items/list` / `thread/items/read` minting a fresh `ref`) or render an explicit truthful unavailable/truncated notice—never falling back to turn-aggregate `DiffController.snapshot`. Evaluate skipping disk spool creation on `0`-byte `""` diffs (or bounding `item/fileChange/patchUpdated` churn) so intermediate live patch updates cannot prematurely exhaust `MAX_SESSION_OUTPUT_OBJECTS = 16,384`.
