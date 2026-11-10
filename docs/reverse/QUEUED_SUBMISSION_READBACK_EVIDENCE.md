# Saved queue readback and refresh evidence

Measured 2026-11-10 against Native `a1f7610`, the bundled Host, installed
Desktop `26.1103.60933` build `25894`, and four stock app-server builds.
The Native side of this slice is research. The existing composer keeps
its presence-only check and explicit resume flow.

## Contract and current product

- The generated stable inventory exposes `thread/queue/changed`, whose
  payload is `threadId`. `thread/queue/list` remains experimental. In the
  inspected public source, list reads a page from the durable queue using
  a decimal offset cursor and `limit + 1` lookahead. The next cursor is
  the current offset plus the page limit. `QueuedSubmission` includes
  the input array. The alpha also exposes `responsesapiClientMetadata`.
  [Stock queue processor at `1099fe0`](https://github.com/openai/codex/blob/1099fe069438099b8c1d6244f797ffd8515b6de0/codex-rs/app-server/src/request_processors/thread_queue_processor.rs)
- Native requests `limit: 1` for its cold Send preflight and discards
  input after projecting presence. That is a one-record result bound.
  The app-server and Host still serialize the selected queue entry.
  [F23 evidence](../RESEARCH.md#f23-cold-composer-sends-and-workspace-file-evidence)

## Disposable Host probes

Each version used a separate copy of a synthetic saved thread, with the
bundled Host on both sides of the probe. The two clients used separate
stock processes with the same disposable `CODEX_HOME`. The queue began
empty. Neither process loaded the thread in the cold probe.

| Stock executable | Old cursor after delete | Old cursor after reorder | One-row JSONL frame for 65,536 text bytes and one mention | Cold change events (writer / reader) | List with experimental opt-in off |
|---|---|---|---:|---:|---|
| Installed `0.167.0-alpha.3.2` | Skipped a surviving row | Repeated an earlier row | 65,783 B | 0 / 0 | `-32600` |
| Public stable `0.167.0` | Skipped a surviving row | Repeated an earlier row | 65,783 B | 0 / 0 | `-32600` |
| Desktop-train `0.167.0-alpha.4.1` | Skipped a surviving row | Repeated an earlier row | 65,783 B | 0 / 0 | `-32600` |
| Public alpha `0.169.0-alpha.7` | Skipped a surviving row | Repeated an earlier row | 65,817 B | 0 / 0 | `-32600` |

- Add four disposable entries `A B C D`. The reader requests `limit: 2`
  and gets `A B` plus cursor `"2"`. Delete `A` on the writer. Reading
  with that cursor returns `D`, so the reader skips surviving `C`.
  Restart from the first page and observe `B C`. Reorder the queue to
  `D C B` and reuse cursor `"2"`. The second page repeats `B`.
- Reorder a large test entry to the front. `limit: 1` returns its whole
  `input` array and next cursor `"1"`. Increasing the synthetic text
  to 1,048,000 ASCII bytes produced 1,048,247 B on installed stock and
  1,048,281 B on higher alpha. The frame sizes include the JSON-RPC
  envelope and newline. A 1,048,576-byte text fixture exceeded the
  bundled Host's 1,048,576-byte client message cap once the request
  envelope was included. The Host closed that connection during
  `thread/queue/add` and reported the exact frame limit. This is a
  Host request-limit result. The separate default forward-message
  budget is 8 MiB, rather than a per-submission preview guarantee.
- A separate installed-stock run queued ten synthetic rows with
  900,000 text bytes each. A nine-row list returned an 8,101,342 B
  frame. A ten-row list ended the reader's Host connection with
  `sanitized app-server message exceeds 8388608 bytes`. The
  independent writer connection still read the first row and no
  turn started. A row limit alone can therefore reach the existing
  Host connection failure path.
- Without experimental opt-in, all four builds reject
  `thread/queue/list` with `-32600` and the method-specific
  `requires experimentalApi capability` message. The successful cold
  sequences produced zero observed `turn/started` events.
- In separate installed and higher-alpha probes, resume the disposable
  thread and hold one foreground turn against a local loopback model.
  Add two entries and delete them before releasing the held response.
  The loaded writer saw four `thread/queue/changed` events, each with
  only `threadId`. A separate cold process saw zero such events in
  this sample. Its explicit lists observed both queued entries and
  the later empty queue. Each run completed one foreground turn and
  made one loopback model request. These samples distinguish the
  local loaded subscription from cross-process freshness.

## Desktop static evidence

The measured ASAR has SHA-256
`121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`.
`webview/assets/async/182735.5b42af8792.js` at byte offsets `1483919`
and `1488099` contains a renderer-side cursor walk that accumulates
queue rows, and an eligibility-checked refresh on the change event.
`.vite/build/early-bootstrap-815-e030c49be4b9c405.js` repeats the list
and change flow at `4425150` and `4429312`. At `4796908` it separately
checks for presence with `limit: 1` before resuming. Literal inventory
hits elsewhere are registration evidence. These are static paths in
the installed bundle. Their observed code shows both list and presence
flows, while eligibility and runtime activation depend on the client.

## Native boundary

Saved queue browsing stays `RESEARCH_MORE`. A bounded first page with an
explicit refresh could provide useful inspection if the payload path
can enforce a preview budget before allocating a large Dart frame.
Treat a local change event as invalidation of the current page. Reopen
or Refresh should read the latest first page because another process can
change the queue without notifying a cold observer. The observed decimal
offset cursor cannot establish a stable multi-page snapshot under
mutation. Stock owns dispatch. Any future write surface needs its own
intentional enqueue and unknown-outcome handling.
