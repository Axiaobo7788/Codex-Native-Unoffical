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
- **Desktop local transport (stdio) has no frame-size cap and needs zero Rust Host changes for Tier 1.**
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
