# Stored conversation search and history anchors

The F20A audit used Native base `4ec5651`, installed stock Codex
`0.167.0-alpha.3.2`, and the bundled Linux Host. The installed stock
binary SHA-256 was `c8242fc9e1bac7c6d661a228cecfaf50e6db74da219e4a9ca8912827e11607f0`.
The measured Desktop build was `26.1103.60933` (25894). Its ASAR SHA-256
was `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`.

## Stock contracts

Installed stable schema includes `thread/list`, `thread/turns/list`, and
`thread/items/list`. Global `thread/search` and per-thread
`thread/searchOccurrences` are experimental in the installed schema
and in current public source. Native's saved sidebar search already uses
the stable metadata query. The Desktop bundle has both global content
search and stable-list call sites, as recorded in the F18 research.
[Upstream protocol registration](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/common.rs)

| Surface | Observed in disposable stock profiles |
|---|---|
| Stable `thread/list.searchTerm` | Matched a renamed saved title and initial user text. The sampled title match was case-sensitive. |
| Experimental `thread/search` | Matched user and assistant text in a completed turn, omitted a separately renamed title, and returned a thread metadata object plus a snippet. A paginated fork lacked its inherited global match. |
| Experimental `thread/searchOccurrences` | Found literal, case-insensitive user occurrences and final assistant text in a paginated thread. A message with two matches returned two occurrences. Each result included a snippet, a UTF-16 range, item and turn IDs, and an inclusive turn cursor. |
| `thread/turns/list` | Both ascending and descending pages started on the matching turn when supplied the occurrence's inclusive cursor. Both `summary` and `notLoaded` item views kept the same first turn identity. |
| `thread/items/list` | The stable schema describes its structured item anchor as exclusive. An occurrence's item ID is distinct from the turn anchor. |

## Runtime observations

- A three-turn fixture matched a mixed-case literal with an emoji before
  the hit. Three occurrence rows decoded to the expected literal when
  the reported UTF-16 ranges were applied. A separate query found one
  final assistant occurrence in each of the three turns.
- An occurrence continuation cursor was rejected with `-32600` when
  reused with a different term or a different thread. Preserve each
  occurrence cursor with the exact wire query that produced it.
- The same initialized process successfully searched a cold paginated
  thread and returned `-32601` for a cold legacy thread. Both rejected
  whitespace-only queries with `-32600`. Treat history-mode support as
  thread-scoped, even when the server uses an unknown-method code.
- A paginated parent and fork both returned the inherited message in
  per-thread search. Their respective inclusive turn cursors each
  opened the matching turn. Global search returned the parent and
  omitted the fork in this fixture. [Upstream reproduction](https://github.com/openai/codex/issues/47012)
- An isolated `thread/revert` removed the matched turn. The prior
  inclusive cursor then failed with `-32600` because its position was
  outside the thread lineage. A new search returned zero hits.
- In a 125-occurrence fixture, omitting `limit` returned 50 rows,
  `limit: 0` returned one row, and requesting 1,000 returned all 125 rows.
  The longest observed snippet used 160 UTF-16 code units. Apply a
  client page cap at the request and response boundary.
- The bundled Host fixture seeded 108 completed turns with a loopback
  Responses endpoint. The first turn was outside the newest 100-turn
  page. One occurrence query and one bounded history page located it
  without loading the thread. Three occurrence RPCs took 6.05, 3.49,
  and 2.72 ms on this machine. Sampled stock RSS was 122,008 KiB before
  and 126,940 KiB after the three queries. These measurements cover a
  small fixture with short turns and do not establish a peak memory
  or production latency budget.

## Reproduction outline

Use a disposable `CODEX_HOME`, isolated XDG directories, and a loopback
model that returns a fixed final assistant message. Start stock directly
over stdio or start the bundled Host with the stock binary path. Enable
`experimentalApi` on initialization. Complete the fixture turns, then
restart before measuring cold reads.

Request a small `thread/searchOccurrences` page for the cold thread.
Check the returned turn and item IDs and apply the snippet range as
UTF-16 offsets. Follow `nextCursor` with the same thread and term.
Use one selected occurrence's `turnCursor` in `thread/turns/list` with
a small `limit` and verify that the first returned turn has the expected
ID. Metadata-only `thread/read` should report `notLoaded` before and after.

For the stale-anchor check, save a matching cursor, explicitly resume
the disposable thread, and revert before the matched turn. Retry the
old history anchor and repeat the search. For the fork check, fork a
completed paginated thread and compare the global search result with
occurrence search inside the fork.

## Native boundary for a scoped integration

Per-thread search and jumping to an older turn are machine-actionable
on supported paginated threads. Keep the loaded-timeline filter
available. Use explicit requests, small verified pages, one retained
result scope, and one active RPC with one replaceable pending query.
The existing history adapter sends summary pages and passes opaque
cursors. Preserve the current history window until the bounded anchor
response confirms the expected turn ID. Keep item loading on the
existing lazy path. Full global content coverage remains under research
because the installed global search can omit inherited fork messages.

F20A records runtime evidence. F21 adds the explicit local saved search
and guarded turn-window jump. Loaded Find remains independent. See
[F21 evidence](../RESEARCH.md#f21-saved-message-search-and-compact-thread-navigation).
