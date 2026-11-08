# ChatGPT Desktop State & Data Flow Architecture (Recalibrated)

> **Evidence Sources**:
> - `STATIC_BUNDLE`: `.vite/build/early-bootstrap-920-a204a41244c4b913.js` (`@708000..735000`, `@886000..990000`, `@1168000..1170000`, `@1644000..1666500`, `@4399500..4403500`), `.vite/build/early-bootstrap-339-10eda6b28d12299c.js` (`@780000..792000`), and `webview/assets/index-Dup49xH6.js` + lazy chunks.
> - `PUBLIC_SOURCE`: Stock `/opt/codex-desktop/resources/codex app-server generate-json-schema --experimental` (`0.167.0-alpha.3.2`).
> - `LOCAL_SCHEMA`: Read-only DDL from `~/.codex/state_5.sqlite` and `~/.codex/sqlite/local_thread_catalog.sqlite`.

---

## 0. Evidence & Calibration Table for Data Flow Claims

| Subsystem / Claim | Evidence Tags | Support Classification | Calibration Note |
|---|---|---|---|
| **History Islands (`canonical` turn topology: `islands`, `olderBoundary`, `newerBoundary`, `entitiesByKey`)** | `STATIC_BUNDLE` (`early-bootstrap-920 @895000..901000`) | `ADAPT_NATIVE` | Supports bidirectional pagination and non-contiguous turn islands |
| **Initial Tail Hydration (`thread/turns/list`, `limit: 5`, `sortDirection: "desc"`, `itemsView: "summary"`)** | `STATIC_BUNDLE` (`yU @911500`, `bC @897200`, `readLatestPreviewPage @934500`), `PUBLIC_SOURCE` (stable in `0.167.0-alpha.3.2`) | `PUBLIC_SUPPORTED` | **Correction**: `ADR-031` previously stated `"newest 15 turns"` due to conflating a `15e3` (`15,000 ms`) timeout with `limit: 5`. The actual turn page size in `yU`/`bC`/`readLatestPreviewPage` is **`5`**. Both `thread/turns/list` and `thread/items/list` are now in stable `ClientRequest.json` (`thread/items/read` and `thread/timeline/list` remain `--experimental`) |
| **Timeline Hydration (`thread/timeline/list`, `limit: 500` + `thread/turns/list`, `limit: 100, itemsView: "none"`)** | `STATIC_BUNDLE` (`bX @921000`, `@4402302`), `PUBLIC_SOURCE` (`--experimental`) | `EXPERIMENTAL_STOCK_SCHEMA` (Feature-gated) | Gated in Desktop by Statsig gate `"codex-app-thread-timeline-history"` (`readThreadTimelineEnabled`) |
| **Active History Eviction (`yV = 1000 -> yZ = 500` items)** | `STATIC_BUNDLE` (`yX`/`yY @975000..985000`, `@4402302`) | `ADAPT_NATIVE` (Feature-gated in Desktop!) | Gated in Desktop by Statsig experiment `"codex_app_active_history_eviction_v1"` (`enabled`, fallback default `false`!) |
| **Bounded Cloud History (`maxTurns: 1..100`, `maxItemsPerTurn: 1..500`)** | `STATIC_BUNDLE` (`yN @972000`, `@4399600`) | `ADAPT_NATIVE` (Feature-gated) | Gated in Desktop by Statsig gate `"codex-app-bounded-cloud-history"` |
| **10-Thread Hydrated LRU (`yW = 10`)** | `STATIC_BUNDLE` (`@968000`, `readRetainedRecentThreadIds @4402600`) | `ADAPT_NATIVE` | Retains up to 10 inactive threads per host; never evicts active/pending-approval/subagent threads |
| **Chat Conversation Tree DAG (`MrGp`: `mapping`, `current_node`, `parent`, `children`)** | `STATIC_BUNDLE` (`webview/assets/async/182735.d3d917f28d.js`) | `PRIVATE_WEB_SESSION` (API) / `ADOPT_PATTERN` (Domain model if building Chat) | Used for `/backend-api/f/conversation` (`source_kind = "chatgpt"`), distinct from Codex linear turn history |

---

## 1. Complete Inventory of Codex/Work History Hydration Paths & Constants

Inspection of `.vite/build/early-bootstrap-920-a204a41244c4b913.js` (`@886000..990000` and `@4399500..4403500`) reveals that ChatGPT Desktop does **not** have a single hardcoded history loader. Instead, it has **six coordinated hydration/retention mechanisms**, several of which are controlled by runtime Statsig gates:

### 1.1 Path A: Initial Tail Hydration & Incremental Turn Pagination (`limit: 5`)
- **Where in Bundle**: `yU` (`@911500`), `bC` (`@897200`), `bd` (`@894600`), `readLatestPreviewPage` (`@934500`).
- **Gate**: Enabled by default (`history.useTailHydration: true`, `history.canonicalTurnHistory: true`, `history.paginatedHistoryEnabled: true` at `@4402400`).
- **Exact RPC Call**:
  ```json
  {
    "method": "thread/turns/list",
    "params": {
      "threadId": "<thread-id>",
      "limit": 5,
      "sortDirection": "desc",
      "itemsView": "summary",
      "itemSnapshot": "full"
    }
  }
  ```
  *(Note: `readLatestPreviewPage` passes `itemSnapshot: "metadata"` and `limit: 5`; `bC` paginates older/newer turns from an island boundary using `limit: s?.limit ?? 5` and `cursor: n.handle.cursor`.)*
- **Why `ADR-031` Previously Said `15`**: Initial summarization misread a nearby `15e3` (`15,000 ms`) timeout constant as a turn count. There is **no** `limit: 15` in `thread/turns/list`.

### 1.2 Path B: Opening User Message Backfill (`limit: 2`)
- **Where in Bundle**: `fI` (`@902000`).
- **Purpose**: When a turn is hydrated in summary mode without its opening user prompt, `fI` fetches the first two items of the turn:
  ```json
  {
    "method": "thread/items/list",
    "params": {
      "threadId": "<thread-id>",
      "turnId": "<turn-id>",
      "limit": 2,
      "sortDirection": "asc",
      "deferOutput": { "commandExecution": true }
    }
  }
  ```

### 1.3 Path C: Per-Turn Item Pagination & Deferred Command Output (`limit: 28 | 30 | 100`)
- **Where in Bundle**: `bk.loadTurnItems` (`@905400..909500`) and `prefetchSharedThreadTurns` (`@945200`).
- **Exact RPC Calls**:
  - `thread/items/list` with `turnId`, `sortDirection: "asc" | "desc"`, `limit: 30` (interactive turn expansion), `limit: 28` (`prefetchSharedThreadTurns` across up to `12` subthreads with concurrency `3`), or `limit: 100` (full turn backfill), always passing `deferOutput: { "commandExecution": true }`.
  - When the user expands a command card whose output was deferred (`outputDeferred: true`), the client calls `thread/items/read` (`itemIds: ["<item-id>"]`, schema limit `1..100`).

### 1.4 Path D: Flat Timeline Hydration (`limit: 500` items + `limit: 100` turns, Feature-Gated)
- **Where in Bundle**: `bX` (`@921000..926000`).
- **Gate**: Statsig gate `"codex-app-thread-timeline-history"` (`readThreadTimelineEnabled` at `@4402450`).
- **Exact RPC Calls**:
  1. `thread/timeline/list` with `limit: s ?? 500`, `sortDirection: "desc" | "asc"`, `buildMode`, `includeSourceTypes`, `deferOutput: { "commandExecution": true }`.
  2. Followed by `thread/turns/list` with `limit: 100, itemsView: "none"` to backfill turn-level metadata (`model`, `reasoningEffort`, `status`) without duplicating items.

### 1.5 Path E: Viewport-Protected Active History Eviction (`1000 -> 500` items, Feature-Gated)
- **Where in Bundle**: `yV = 1e3`, `yZ = 500`, `yX` / `yY` (`@975000..985000`).
- **Gate**: Statsig experiment `"codex_app_active_history_eviction_v1"` (`get("enabled", false)` at `@4402500` — **disabled by default unless the experiment is active!**).
- **Mechanism**:
  - Tracks total loaded items across all turns in the active conversation.
  - When total items exceed `yV = 1000`, evicts turns/items down to `yZ = 500` starting from the edge farthest from the user's current viewport anchor (`anchorTurnId`, `protectNewestEdge`), while never evicting an in-progress turn.
  - Because canonical turn history is stored as **History Islands** (`islands: [{id, entries, olderBoundary, newerBoundary}]`, `entitiesByKey`), evicting a range simply splits or shrinks an island and marks its `olderBoundary` or `newerBoundary` as `"available"` with a pagination cursor so scrolling back re-fetches seamlessly.

### 1.6 Path F: Bounded Cloud History (`maxTurns: 1..100`, `maxItemsPerTurn: 1..500`, Feature-Gated)
- **Where in Bundle**: `yN` (`@972000`).
- **Gate**: Statsig gate `"codex-app-bounded-cloud-history"` (`useBoundedCloudHistory` at `@4399600`).
- **Mechanism**: Caps cloud-hydrated conversations to `maxTurns` (`1..100`) and `maxItemsPerTurn` (`1..500`), preserving each turn's `openingUserMessageItem` plus the newest tail items.

### 1.7 Multi-Thread Hydrated Retention (`10`-Thread LRU)
- **Where in Bundle**: `yW = 10` (`@968000`), `readRetainedRecentThreadIds` (`@4402600`), `bn` (`@893800`).
- **Mechanism**: Keeps up to `10` recently viewed inactive threads hydrated in memory per host, while pinning any thread that is currently `active`, waiting on an approval/user-input request, or part of an active parent/subagent tree (`bn`).

---

## 2. Reconciling Against Current `Codex-Native-Unoffical` (`HEAD` `4a530d2`)

A thorough source audit of `Codex-Native-Unoffical` at `HEAD` (`4a530d2`) confirms that our client implements a two-controller bounded history architecture with all `16.A–16.E` scroll/eviction/attachment hardening integrated:

| Mechanism | ChatGPT Desktop (`26.326.51703`) | Current `Codex-Native-Unoffical` (`HEAD` `4a530d2`) | Comparison & Verification Status |
|---|---|---|---|
| **Turn Pagination RPC** | `thread/turns/list` (`limit: 5`, `sortDirection: "desc"`, `itemsView: "summary"`) | [`HistoryController`](lib/src/features/conversation/history_controller.dart#L29-L418) calls stable `thread/turns/list` (`turnPageSize = 20`, `sortDirection: SortDirection.descending`, `itemsView: 'summary'`) with opaque `nextCursor` (`loadOlderTurns()`) | **Equivalent in protocol (`PUBLIC_SUPPORTED`)!** `turnPageSize = 20` is well-suited to desktop viewport height (`KEEP_OUR_ADVANTAGE` / `ADAPT_NATIVE`). |
| **Turn Retention Window** | History Islands (`islands`, `olderBoundary`, `newerBoundary`) + experiment-gated `1000 -> 500` item eviction | `HistoryController` caps `_turns` at `maxRetainedTurns = 100` (`history_controller.dart:33`), tracks `loadOlderVersion`, `evictionVersion`, and `lastEvictedItemIds`, and pairs with `findChildIndexCallback` + `_MeasuredTimelineItem` in `_ConversationScrollView` | **Resolved (`16.B`)**: Evicting the newest turns when `loadOlderTurns()` crosses `>100` turns preserves the visible anchor with `0.000 px` drift across `285,523 px` real threads and prunes evicted `history-<id>` keys from `_measuredItemHeights` (`ADAPT_NATIVE`). |
| **Per-Turn Item Expansion & Deferred Output** | `thread/items/list` (`limit: 30`, `deferOutput: {commandExecution: true}`) + `thread/items/read` | `HistoryController.loadTurnItems(turnId)` (`itemPageSize = 25`, `maxRetainedItems = 100`, `deferOutput: {'commandExecution': true}`, propagating outer `ThreadItemEntry.outputDeferred` in `HistoryProtocolAdapter`) + `loadDeferredOutput(item)` via experimental `thread/items/read` | **Bounded client/Host handling (`PUBLIC_SUPPORTED` list + `EXPERIMENTAL_STOCK_SCHEMA` read)**: Installed `0.167.0-alpha.3.2` accepts `deferOutput` as a preference, though sampled command outputs were not actually deferred and `thread/items/read` remains a whole-item app-server read sanitized by the Host spool before Dart decoding (`ADAPT_NATIVE` / `KEEP_OUR_ADVANTAGE`). |
| **Live Turn Streaming & Coalescing** | Renderer store updates from `codex_desktop:message-for-view` | [`ConversationController`](lib/src/features/conversation/conversation_controller.dart#L24-L820) (`maxEntries = 200`, `maxEntryCharacters = 64 KiB`, `maxPendingDeltaItems = 16`, `50 ms` `coalesceInterval`), deduplicated by `item.id` in `conversation.dart` | **Native advantage!** Bounded 50 ms delta coalescing + Rust `codex-native-host` `512 MiB/item`, `2 GiB/session` streaming SHA-256 deduplicated spool (`KEEP_OUR_ADVANTAGE`). |
| **Cross-Thread Switching & Scroll Restoration** | `10`-thread hydrated LRU (`yW = 10`) + turn-anchored scroll state | `HistoryController.bindThread()` clears `_turns` on every thread switch while `conversation.dart` stores bounded `_ThreadScrollBookmark(scrollPixels, anchorItemKey, anchorTurnId, anchorViewportTopDy)` (`max 32`) | **Resolved (`16.A`)**: `_scheduleThreadScrollRestore` pages up to `_maxRestorePages = 10` older pages (`220` turns including page 1) to align `anchorItemKey` to `anchorViewportTopDy` (`0.000 px` drift), and under Scheme A deterministically discards stale bookmarks beyond `_maxRestorePages` and resets to newest (`pixels == 0.0`) (`ADAPT_NATIVE`). |

---

## 3. Chat Mode Data Flow: `MrGp` Conversation Tree DAG (`STATIC_BUNDLE`)

In `webview/assets/async/182735.d3d917f28d.js`, standard ChatGPT Cloud Chat (`/chat/:conversationId`) uses the `MrGp` conversation tree DAG:

```typescript
interface ChatConversationDAG {
  conversation_id: string;
  title: string;
  current_node: string;
  mapping: Record<string, {
    id: string;
    parent?: string | null;
    children: string[];
    message?: {
      id: string;
      author: { role: 'system' | 'user' | 'assistant' | 'tool'; name?: string };
      create_time?: number | null;
      content: {
        content_type:
          | 'text'
          | 'multimodal_text'
          | 'code'
          | 'execution_output'
          | 'thoughts'
          | 'reasoning_recap'
          | 'tether_browsing_display'
          | 'sonic_webpage';
        parts?: Array<string | Record<string, unknown>>;
      };
      metadata?: Record<string, unknown>;
    } | null;
  }>;
}
```

- **Branching & Sibling Switching**: Editing a user prompt or regenerating an assistant reply appends a new child node to the parent node's `children[]` array and updates `current_node` to the leaf of the newly active branch. The active linear transcript is computed by walking `parent` pointers backward from `current_node` to the root (`O(depth)`).
- **Streaming Delta Protocol**: `/backend-api/f/conversation` streams SSE frames (`event: delta_encoding` / `event: delta`) using JSON-patch operations (`o: "append" | "replace" | "add" | "patch"`, `p: "/message/content/parts/0"`, `v: "..."`).
- **Support Classification**: The `/backend-api/f/conversation` transport is `PRIVATE_WEB_SESSION`, whereas the `MrGp` parent/children branch-tree data structure itself is a general UI/domain pattern (`ADOPT_PATTERN` if/when `Codex-Native-Unoffical` adds a `ChatBackend`).
