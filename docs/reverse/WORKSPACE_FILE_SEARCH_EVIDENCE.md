# Workspace File Search (`fuzzyFileSearch` & `fuzzyFileSearch/session*`) Evidence

Date: 2026-11-10
Status: Complete (`LOCAL_SCHEMA` + `PUBLIC_SOURCE_4E4767F` + `STATIC_BUNDLE` + `DISPOSABLE_LIVE_PROBE`)
Scope: F23B independent static and disposable live audit of stock `codex app-server` (`0.167.0-alpha.3.2`), local `codex-native-host`, public `openai/codex` (`4e4767f`), and Official Codex Desktop (`26.1103.60933`, build `25894`) for safe workspace `@`/file suggestions.

---

## 1. Executive Summary

1. **Stable vs Experimental RPC Split (`LOCAL_SCHEMA` + `PUBLIC_SOURCE_4E4767F` + `DISPOSABLE_LIVE_PROBE`)**:
   - One-shot `fuzzyFileSearch` is part of the **stable** `ClientRequest` schema and requires no new capability opt-in. Note that Codex Native's `InitializeRequest` in `lib/src/protocol/protocol_models.dart` already defaults `experimentalApi = true`; even when a client explicitly initializes with `experimentalApi: false`, one-shot `fuzzyFileSearch` succeeds through `codex-native-host`.
   - Session-based requests (`fuzzyFileSearch/sessionStart`, `fuzzyFileSearch/sessionUpdate`, `fuzzyFileSearch/sessionStop`) are **experimental-gated** (`experimentalApi: true`). When called on a connection initialized with `experimentalApi: false`, stock `0.167.0-alpha.3.2` rejects each with JSON-RPC `-32600` (`"<method> requires experimentalApi capability"`).
   - Server notifications `fuzzyFileSearch/sessionUpdated` and `fuzzyFileSearch/sessionCompleted` appear in the generated `ServerNotification` union in both schema modes, and are emitted during active experimental search sessions.
   - Public upstream `openai/codex` at commit `4e4767f` confirms the one-shot result cap (`MATCH_LIMIT: usize = 50`) in [`codex-rs/app-server/src/fuzzy_file_search.rs`](https://github.com/openai/codex/blob/4e4767f/codex-rs/app-server/src/fuzzy_file_search.rs) and symlink-following directory traversal (`follow_links(true)`) in [`codex-rs/file-search/src/lib.rs`](https://github.com/openai/codex/blob/4e4767f/codex-rs/file-search/src/lib.rs).
2. **Official Desktop Call-Site Separation (`STATIC_BUNDLE`)**:
   - Generic notification allowlists and RPC telemetry tables register all four request methods and both notification methods under the `"fuzzy_file_search"` source category (`desktop.file_search` / `file.search` trace spans).
   - Actual feature usage splits into two distinct patterns:
     - **Shared session-with-fallback controller (`FjRo`)**: starts an experimental search session (`fuzzyFileSearch/sessionStart` + `fuzzyFileSearch/sessionUpdate` + `fuzzyFileSearch/sessionStop`) and falls back to one-shot `fuzzyFileSearch` only if `sessionStart` fails with `-32601` / unknown-method. Used by **(a) Composer `@` Mention File Provider (`GVrb` / `xAmH`)** with `100 ms` query debounce and directory results enabled, and **(b) Workspace File Tree Filter (`VPAs`)** with directory results disabled.
     - **Direct one-shot `fuzzyFileSearch`**: used only by the **Page Artifact Output Fallback** (`cancellationToken: null`, single workspace root) to resolve an unlinked filename to a unique workspace path.
3. **Symlink Traversal vs Client Containment Boundary (`PUBLIC_SOURCE_4E4767F` + `DISPOSABLE_LIVE_PROBE` + `STATIC_BUNDLE`)**:
   - Because [`codex-rs/file-search/src/lib.rs`](https://github.com/openai/codex/blob/4e4767f/codex-rs/file-search/src/lib.rs) configures `ignore::WalkBuilder` with `follow_links(true)` and `.hidden(false)`, the stock `codex app-server` child process follows symlinks **during upstream traversal before any UI post-filter runs**.
   - Both in Codex's independent packaged-Host probe (`build/linux/x64/debug/bundle/codex-native-host --codex /opt/codex-desktop/resources/codex` with isolated `HOME`/`CODEX_HOME` and `experimentalApi: false`) and in our separate disposable probe via `target/debug/codex-native-host`, an in-root symlink pointing to an out-of-root target returned `root: "<workspace_a>"` and a workspace-relative `path` (`"link_to_outside_file.txt"` and `"link_to_outside_dir/outside_sub/deep_escape.txt"`).
   - **Strict Scope Boundary**: Pure lexical path resolution (joining `root` and `path` without resolving symlinks, as Desktop's `bnxy._v` helper does) stays inside `root` and misses the out-of-root symlink target. Client-side canonical path validation (`resolveSymbolicLinks`) on both the declared root and candidate path can **prevent unsafe UI suggestions and prevent attaching out-of-root symlink targets**, provided it is checked both when filtering suggestions and again at selection/attachment time (mitigating, though not eliminating, filesystem TOCTOU between selection and later runtime reads). However, client-side validation **cannot confine upstream `codex app-server` traversal or guarantee that no out-of-root filenames cross the local stdio pipe**.
4. **Additional Fixture Observations (`DISPOSABLE_LIVE_PROBE`)**:
   - **Result cap & `.gitignore`**: returned `50` of `500` matching fixture files (`MATCH_LIMIT = 50`) ordered by descending `score`, honored repository `.gitignore` (`ignored_dir/` and `*.secret` excluded), and completed without hanging on a self-referential directory symlink (`symlink_loop -> .`).
   - **Dotfiles & `.git/` traversal**: with `.hidden(false)` active in `codex-rs/file-search`, querying `"HEAD"` returned `.git/HEAD`, `.git/refs/heads`, and `.git/hooks/sendemail-validate.sample` unless filtered by the client.
   - **Empty vs whitespace query**: `query: ""` returned `files: []`, whereas whitespace-only `query: "   "` returned `50` score-`0` items starting with a degenerate root directory entry (`path: ""`, `file_name: ""`, `match_type: "directory"`) and `.git` entries.
   - **Unicode `indices`**: verified on `"unicode_文件_αβγ_test.dart"` as 0-based **Unicode scalar (`char` / `Runes`) offsets** (`[8, 9, 10, 11]` for `"文件_α"`), not UTF-8 byte offsets.
   - **Single pipelined `cancellationToken` observation**: in a back-to-back two-request probe sharing a non-null `cancellationToken`, the first request resolved as a normal JSON-RPC result `{"files": []}` while the second returned its matches, showing that clients should pair `cancellationToken` with a local request sequence/query guard.

---

## 2. Schema & Public Source Contract (`LOCAL_SCHEMA` + `PUBLIC_SOURCE_4E4767F`)

Extracted from `/opt/codex-desktop/resources/codex app-server generate-json-schema` (`0.167.0-alpha.3.2`) with and without `--experimental`, cross-referenced with public `openai/codex` commit `4e4767f`:

| Method | Direction | Schema Gate | Params Shape | Response / Notification Payload |
| --- | --- | --- | --- | --- |
| `fuzzyFileSearch` | Client -> Server Request | **Stable** (default schema) | `{ query: string, roots: string[], cancellationToken?: string \| null }` | `{ files: FuzzyFileSearchResult[] }` |
| `fuzzyFileSearch/sessionStart` | Client -> Server Request | **Experimental** (`--experimental`) | `{ sessionId: string, roots: string[] }` | `{}` |
| `fuzzyFileSearch/sessionUpdate` | Client -> Server Request | **Experimental** (`--experimental`) | `{ sessionId: string, query: string }` | `{}` |
| `fuzzyFileSearch/sessionStop` | Client -> Server Request | **Experimental** (`--experimental`) | `{ sessionId: string }` | `{}` |
| `fuzzyFileSearch/sessionUpdated` | Server -> Client Notification | Listed in both schemas (emitted by experimental sessions) | — | `{ sessionId: string, query: string, files: FuzzyFileSearchResult[] }` |
| `fuzzyFileSearch/sessionCompleted` | Server -> Client Notification | Listed in both schemas (emitted by experimental sessions) | — | `{ sessionId: string }` |

### `FuzzyFileSearchResult` Item Schema & Upstream Constants

- `root` (`string`, required): The root directory string from `params.roots` under which the match was discovered.
- `path` (`string`, required): Path relative to `root`.
- `file_name` (`string`, required): Basename of the matched entry.
- `match_type` (`"file" | "directory"`, required): Entry kind (`FuzzyFileSearchMatchType`).
- `score` (`uint32`, required): Match score computed by the `nucleo` matcher inside `codex-rs/file-search`.
- `indices` (`uint32[] | null`, optional): 0-based character indices of matched characters within `path`.
- Public upstream [`codex-rs/app-server/src/fuzzy_file_search.rs`](https://github.com/openai/codex/blob/4e4767f/codex-rs/app-server/src/fuzzy_file_search.rs) defines `MATCH_LIMIT: usize = 50` for one-shot `fuzzyFileSearch`, and [`codex-rs/file-search/src/lib.rs`](https://github.com/openai/codex/blob/4e4767f/codex-rs/file-search/src/lib.rs) configures `WalkBuilder` with `follow_links(true)` and `.hidden(false)`.

---

## 3. Official Desktop ASAR Audit (`STATIC_BUNDLE`)

Audited against `/opt/codex-desktop/resources/app.asar` (`26.1103.60933`, build `25894`, SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`). All 24 occurrences of `fuzzyFileSearch` and 5 occurrences of `fuzzy_file_search` in the bundle separate cleanly into generic registration/telemetry tables versus concrete feature call sites.

### 3.1 Generic Method Registration & Telemetry Tables (Non-Composer)

1. **Server Notification Forwarding Allowlists (`offsets 14469957, 14469993, 16288765, 16288801, 86152543, 86152579`)**:
   - Main/preload bridge notification allowlists register `fuzzyFileSearch/sessionUpdated` and `fuzzyFileSearch/sessionCompleted` alongside other server notifications.
2. **RPC Source Classification & Tracing (`offsets 110782043–110782176, 110785660, 110795111`)**:
   - Classifies `fuzzyFileSearch`, `fuzzyFileSearch/sessionStart`, `fuzzyFileSearch/sessionUpdate`, and `fuzzyFileSearch/sessionStop` under telemetry source category `"fuzzy_file_search"`, and wraps `"fuzzy_file_search"` calls (other than `sessionStop`) in trace spans named `"desktop.file_search"` and `"file.search"`.

### 3.2 Shared Search Controller & Post-Filter (`FjRo`, `offsets 113619058–113626050`)

Desktop routes interactive workspace file search through a shared controller module (`FjRo`):

1. **Session-With-Fallback Manager (`offset 113619235`)**:
   - Maintains a per-host session support state (`unknown`, `supported`, or `unsupported`).
   - Creating a session allocates a UUID `sessionId` and sends `fuzzyFileSearch/sessionStart`. On success, session support is marked `supported`; if the server returns `-32601` / unknown-method (`NvvW.Rg`, `offset 560200516`), session support is marked `unsupported`.
   - Updating the query calls `fuzzyFileSearch/sessionUpdate` when sessions are supported. If the server reports that the fuzzy file search session was not found, the controller restarts the session with `fuzzyFileSearch/sessionStart` and retries `fuzzyFileSearch/sessionUpdate`.
   - When sessions are marked `unsupported`, updating the query falls back to one-shot `fuzzyFileSearch` with a static cancellation token (`"vscode-fuzzy-file-search"`) and immediately invokes the session-updated and session-completed callbacks.
   - Stopping a session sends `fuzzyFileSearch/sessionStop` when sessions are supported.
2. **React Hook Lifecycle (`offset 113623640`)**:
   - Tracks active sessions keyed by the NUL-delimited list of root paths, stopping the prior session when the root list changes or the hook unmounts.
   - When the query string is empty or no roots are provided, the hook clears its response state and loading flag without dispatching a search update.
3. **Client Post-Filter, Lexical Path Formatting, and Secondary Re-Ranking (`offset 113625200`)**:
   - Keeps file matches and optionally directory matches when the caller enables directories.
   - Drops any entry whose path segments contain `.git`, `.hg`, `.next`, `.pnpm-store`, `.svn`, `.turbo`, `.yarn`, `build`, `coverage`, `dist`, or `node_modules`.
   - Formats paths through helper `bnxy._v` (`offset 119100500`), which performs a pure lexical path join/resolve between `root` and `path` (without resolving symlinks) and prefixes the workspace root basename to the display path only when multiple roots are searched.
   - Applies a secondary client-side fuzzy scorer (`UN1G.WE`, `offset 113120970`) to the trimmed query against both the basename and formatted path, discarding entries that score zero or below on both, and sorting file matches with positive basename scores ahead of directory or path-only matches, then by descending basename score, label, and original server index.

### 3.3 Actual Feature Call Sites in Official Desktop

| Call Site | Bundle Location | Entry Mechanism | Directories Included? | Selection / Output Behavior |
| --- | --- | --- | --- | --- |
| **1. Composer `@` Mention File Provider (`GVrb` / `xAmH`)** | `xAmH` (`offset 529954006`), `GVrb` (`offset 529976882`), `L03S` (`offset 529970561`) | Triggered by typing `@<query>` in the composer; `xAmH` debounces the query by `100 ms` before calling `GVrb` -> `FjRo` | **Yes** | Selecting an item inserts a ProseMirror `atMention` node (`offset 113060100`) carrying label, display path, and resolved lexical path, which serializes into outbound prompt text as a markdown link (`offsets 113084458, 118706647`). For directory items, pressing `Tab` (`L03S` at `offset 529970561`) replaces `@<query>` with `@<dir>/` in the composer so the user can drill into that directory. |
| **2. Workspace File Tree Filter (`VPAs`)** | `VPAs` (`offset 113628668`) | Sidebar/panel file tree search input calling `FjRo` | **No** | Filters visible file tree entries by matching their resolved lexical paths. |
| **3. Page Artifact Output Fallback** | `offsets 64880081, 257661617` | Direct one-shot `fuzzyFileSearch` request with `roots: [cwd]` and `cancellationToken: null` | Exact match check | Resolves a bare filename in artifact output when only a single unambiguous match exists under `cwd`. |

### 3.4 Composer `@` Mention Serialization: Desktop vs Current Codex Native

- **Official Desktop**: Composer `@` file selection inserts an inline `atMention` chip serialized into the prompt's `text` item as a markdown link (`MX6A.xR` at `offset 118706647`), while structured `{ "type": "mention", "name": ..., "path": ... }` items in `UserInput` are produced by explicit `@[label](path)` / plugin template mentions (`offset 191415896`).
- **Codex Native (`lib/src/protocol/turn_protocol.dart` lines 108–113, `lib/src/app/presentation/conversation.dart` lines 5041–5049)**: Currently provides a manual `"Attach file (@mention)"` dialog where the user types a raw path and optional label, producing `UserAttachment(kind: UserAttachmentKind.mention, label: ..., path: ...)` which `TurnProtocolAdapter` serializes as `{ "type": "mention", "name": label, "path": path }` in `turn/start` (`Codex Native` currently has no `thread/queue/add` or `thread/queue/update` client code).

---

## 4. Disposable Live Probe Evidence (`DISPOSABLE_LIVE_PROBE`)

Two independent disposable local probe setups were used against stock `/opt/codex-desktop/resources/codex` (`0.167.0-alpha.3.2`):
1. **Codex's independent packaged-Host baseline**: launched `build/linux/x64/debug/bundle/codex-native-host --codex /opt/codex-desktop/resources/codex` with an isolated `HOME`/`CODEX_HOME` and `experimentalApi: false`, verifying `50` of `500` fixture matches, `.gitignore` honoring, and out-of-root symlink discovery under a workspace-relative `path`.
2. **This branch's extended disposable fixture probe**: launched `target/debug/codex-native-host --codex /opt/codex-desktop/resources/codex --cache-dir <tmp>` against `/tmp/codex_f23b_probe_*` workspaces (deleted immediately after the run) with both `experimentalApi: false` and `experimentalApi: true`.

### 4.1 Experimental Gate & Pass-Through Verification

| Probe | Connection Capability | Request | Observed Result |
| --- | --- | --- | --- |
| One-shot `fuzzyFileSearch` | `experimentalApi: false` | `fuzzyFileSearch({ query: "match", roots: [root_a], cancellationToken: null })` | **Succeeded** with `files` array of length `50`. |
| `fuzzyFileSearch/sessionStart` | `experimentalApi: false` | `fuzzyFileSearch/sessionStart({ sessionId: "s1", roots: [root_a] })` | **Rejected** with `{"error": {"code": -32600, "message": "fuzzyFileSearch/sessionStart requires experimentalApi capability"}}`. |
| `fuzzyFileSearch/sessionUpdate` | `experimentalApi: false` | `fuzzyFileSearch/sessionUpdate({ sessionId: "s1", query: "match" })` | **Rejected** with `{"error": {"code": -32600, "message": "fuzzyFileSearch/sessionUpdate requires experimentalApi capability"}}`. |
| `fuzzyFileSearch/sessionStop` | `experimentalApi: false` | `fuzzyFileSearch/sessionStop({ sessionId: "s1" })` | **Rejected** with `{"error": {"code": -32600, "message": "fuzzyFileSearch/sessionStop requires experimentalApi capability"}}`. |

### 4.2 Result Cap, `.gitignore`, Dotfiles, `.git/` Walk, and Unicode Offsets

Inside disposable git repository `workspace_a` containing `500` `match_000.txt`..`match_499.txt` files, `.gitignore` (`ignored_dir/` and `*.secret`), `.hidden_env`, `sub_dir/deeper_dir/inside.txt`, and `unicode_文件_αβγ_test.dart`:

1. **50-Result Cap (`MATCH_LIMIT = 50`)**:
   - `query: "match"` returned `50` items (`score: 134`, `indices: [0, 1, 2, 3, 4]`).
2. **`.gitignore` Honored**:
   - `query: "match_ignored"` (for `ignored_dir/match_ignored.txt`) returned `files: []`.
   - `query: "top.secret"` (for `top.secret`) returned `files: []`.
3. **Directory & Nested File `match_type`**:
   - Both one-shot `fuzzyFileSearch` and `fuzzyFileSearch/sessionUpdated` returned `"match_type": "directory"` as well as `"match_type": "file"`.
   - `query: "sub_dir"` returned 4 items: `sub_dir` (`"directory"`), `sub_dir/deeper_dir` (`"directory"`), `sub_dir/deeper_dir/inside.txt` (`"file"`), and `sub_dir/nested_match.txt` (`"file"`).
4. **Dotfiles and `.git/` Traversal**:
   - `query: "hidden_env"` returned `.hidden_env` (`match_type: "file"`, `score: 248`, `indices: [1..10]`).
   - `query: "HEAD"` returned `.git/HEAD` (`match_type: "file"`), `.git/refs/heads` (`match_type: "directory"`), and `.git/hooks/sendemail-validate.sample` (`match_type: "file"`).
   - **Implication**: Because `codex-rs/file-search` sets `.hidden(false)` on `ignore::WalkBuilder`, the client must filter `.git` path segments before surfacing workspace suggestions.
5. **Unicode Scalar (`char`) `indices`**:
   - On `unicode_文件_αβγ_test.dart`, `query: "文件_α"` returned `indices: [8, 9, 10, 11]` and `query: "αβγ_test"` returned `indices: [11, 12, 13, 14, 15, 16, 17, 18]`.
   - Because `"unicode_"` is 8 ASCII code points (`0..7`), `'文'` is scalar index `8`, `'件'` is `9`, `'_'` is `10`, and `'α'` is `11`, `indices` are 0-based **Unicode scalar (`Runes`) indices** into `path`.

### 4.3 Symlink Discovery vs Containment Audit (`follow_links(true)`)

We tested three symlink topologies inside `workspace_a` while `outside_secret_zone` existed as a sibling directory outside `workspace_a`:

| Symlink Inside `workspace_a` | Target | Query | Returned `FuzzyFileSearchResult` | Containment Analysis |
| --- | --- | --- | --- | --- |
| `link_to_outside_file.txt` | `../outside_secret_zone/outside_secret.txt` (outside root) | `"link_to_outside_file"` | `{ root: ".../workspace_a", path: "link_to_outside_file.txt", file_name: "link_to_outside_file.txt", match_type: "file", score: 509 }` | **Escapes root on canonical resolution**: lexical join `workspace_a/link_to_outside_file.txt` stays inside `workspace_a`, whereas canonical symlink resolution (`realpath`) resolves to `.../outside_secret_zone/outside_secret.txt`. |
| `link_to_outside_dir` | `../outside_secret_zone` (outside root directory) | `"outside_secret"` / `"deep_escape"` | `{ root: ".../workspace_a", path: "link_to_outside_dir/outside_secret.txt", ... }` and `{ root: ".../workspace_a", path: "link_to_outside_dir/outside_sub/deep_escape.txt", ... }` | **Upstream traverses external directory**: files inside the external target directory were walked by `codex app-server` and returned over local stdio with workspace-relative `path` strings under `link_to_outside_dir/`. |
| `symlink_loop` | `.` (`workspace_a` self-loop) | `"match"` / `"sub_dir"` | Completed normally in the disposable fixture without hanging | `ignore::WalkBuilder` cycle detection avoided infinite recursion on the self-loop fixture. |
| No symlink; `query: "../outside"` | N/A | `"../outside"` | `files: []` | Query strings match against walked relative paths rather than opening arbitrary relative paths. |
| Un-normalized `roots: [".../workspace_a/../outside_secret_zone"]` | Sibling directory via `..` in `roots` | `"outside_secret"` | `{ root: ".../workspace_a/../outside_secret_zone", path: "outside_secret.txt", ... }` | Server walks whatever path is passed in `roots` and echoes `root` verbatim without canonicalizing it. |

**Containment Capabilities & Limits**:
1. **What client-side canonical validation CAN prevent**: By resolving symlinks (`FileSystemEntity.resolveSymbolicLinks`) on both the declared workspace `root` and each candidate `join(root, entry.path)` before rendering suggestions—and **re-checking canonical containment at selection/attachment time**—the UI can prevent out-of-root symlink targets from being suggested or attached by the user.
2. **What client-side canonical validation CANNOT prevent**: Because `follow_links(true)` is compiled into upstream `codex-rs/file-search`, `codex app-server` traverses symlinked directories before returning the top `50` matches. Client post-filtering cannot stop upstream traversal inside the local child process, cannot prevent out-of-root filenames from crossing the local stdio pipe, and cannot eliminate a post-selection filesystem TOCTOU swap between the moment a user attaches a path and the moment the runtime later reads it.

### 4.4 Empty Query, Root Identity, Cancellation, and Session Snapshot Observations

| Probe Case | Input | Observed Fixture Behavior | Client Design Requirement |
| --- | --- | --- | --- |
| Empty query (`""`) | `query: ""` | Returned `files: []` (`count = 0`). | Do not issue RPC when `query.trim().isEmpty`. |
| Whitespace-only query (`"   "`) | `query: "   "` | Returned `50` score-`0` items starting with `{ path: "", file_name: "", match_type: "directory", score: 0 }` followed by `.git` and `.git/HEAD`. | Always `.trim()` query on the client before checking emptiness, and reject any result with `path.isEmpty` or `file_name.isEmpty`. |
| Single pipelined `cancellationToken` pair | Req 4 (`query: "HEAD"`, `cancellationToken: "same-tok"`) immediately followed by Req 5 (`query: "hidden_env"`, `cancellationToken: "same-tok"`) | In this two-request probe, Req 4 resolved with `{"id": 4, "result": {"files": []}}` while Req 5 returned `.hidden_env`. | Because a cancelled request can resolve with a normal `{"files": []}` payload rather than an error, track a local monotonic `requestSeq` (and active query/root) and ignore responses from superseded requests. |
| Multi-root (`[root_a, root_b]`) | Both roots contain `shared_name.dart` | Returned 2 items discriminated only by each item's `root` field. | Single-workspace composer suggestions should pass only `[canonicalCwd]`. |
| Duplicate root (`[root_a, root_a]`) | Same root passed twice | Returned duplicate entries for `shared_name.dart`. | Deduplicate canonical `roots` before calling `fuzzyFileSearch`. |
| Invalid roots (`[]`, missing dir, regular file path) | `roots: []`, `roots: ["/tmp/no_such_root"]`, `roots: [".../match_000.txt"]` | All three returned `{"files": []}` without throwing a JSON-RPC error. | Safe no-op on missing/uninitialized workspace directory. |
| Single experimental session snapshot probe (`sessionStart` -> file created after `300 ms` -> `sessionUpdate`) | Created `live_created_after_start.rs` `300 ms` after `sessionStart`, then sent `sessionUpdate` for `"live_created_after_start"` | Returned `files: []` in that `sessionUpdated` notification; stopping the session and calling `sessionUpdate` afterward returned `-32600` (`"fuzzy file search session not found: sess-1"`). | One-shot `fuzzyFileSearch` avoids background session lifecycle/teardown state while `InitializeRequest` capabilities remain unchanged. |

---

## 5. Scoped Readiness & Privacy/Containment Contract (`READY` Scope Boundary)

A future Codex Native slice for local workspace file suggestions is `READY` **only within a narrow, explicit privacy and safe-display contract**:

1. **Scope Boundary (Display & Selection Filtering, Not Upstream Traversal Confinement)**:
   - Use stable one-shot `fuzzyFileSearch` on local `ProcessTransport` only (keep Track A Remote fail-closed, as remote clients lack local host filesystem access for symlink resolution and `fuzzyFileSearch` is outside the Remote bridge allowlist).
   - Document clearly in code and UI that client containment filters what Codex Native displays and attaches, while upstream `codex app-server` still walks the local workspace with its stock `follow_links(true)` policy.
2. **Canonical Root & Dual-Stage Symlink Containment Check (Display + Selection)**:
   - Canonicalize the active thread's workspace `cwd` via `Directory(cwd).resolveSymbolicLinks()` before issuing `fuzzyFileSearch`, and pass only `[canonicalRoot]`.
   - **Stage 1 (Suggestion Post-Filter)**: Reject entries with empty `path` or `file_name`, reject noisy/VCS segments (`.git`, `.hg`, `.svn`, `.next`, `.nuxt`, `.turbo`, `.yarn`, `.pnpm-store`, `node_modules`, `build`, `dist`, `coverage`, `.dart_tool`), and resolve each candidate path via `FileSystemEntity.resolveSymbolicLinks(p.join(canonicalRoot, entry.path))`. Drop any entry whose canonical target is missing or outside `canonicalRoot` (`canonicalTarget != canonicalRoot && !p.isWithin(canonicalRoot, canonicalTarget)`).
   - **Stage 2 (Selection / Attachment Re-Verification)**: When the user selects a suggestion to attach (or before submitting the attachment), re-run canonical symlink resolution on the selected path to narrow the TOCTOU window if a path was replaced after suggestions were rendered.
3. **Trimmed Query, Debounce, and Monotonic Request Guard**:
   - Trim the query before checking emptiness (`query.trim().isEmpty` -> clear suggestions without calling `fuzzyFileSearch`).
   - Pair a stable per-composer `cancellationToken` with a local monotonic `_searchRequestSeq` so an earlier cancelled request returning `{"files": []}` cannot overwrite a newer in-flight or completed query.
4. **Directory Drill-Down vs File Mention**:
   - Do not attach directory paths as file mentions; either filter to `match_type == "file"` for attachment chips or treat directory selection/`Tab` as query refinement (`@<dir>/`).
