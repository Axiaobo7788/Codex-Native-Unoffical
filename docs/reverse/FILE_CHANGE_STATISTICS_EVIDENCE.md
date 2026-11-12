# Kind-aware file-change statistics

Track F correction from base `9a3421e62ace397da7fe8004625bf46dab202c51`.
This fixes live/saved captions; it does not implement per-item diff loading or
close the A7 visual contract.

The current public `0.167.2` and installed `0.167.0-alpha.3.2` stable
`FileUpdateChange` shape carries `path`, `kind` and `diff`. Current renderer
25894 corroborates that add/delete `diff` values are raw content while updates
are unified hunks; see the [source-bound seam evidence](FILE_UPDATE_CHANGE_SEAM_PROPOSAL.md).
The previous independent live/history helpers scanned every string as a signed
patch, misreporting newly created Markdown bullets as deletions and dropping
content lines beginning with multiple signs inside update hunks.

Both adapters now use one pure-Dart summary helper. Add/delete counts follow
actual content lines, including empty lines but excluding a phantom final line
after a trailing newline. Update headers are excluded outside hunks; sign-prefixed
content inside a hunk remains countable. Legacy explicit non-negative counters
and kind-less unified patches remain compatible.

The summary retains no file contents and never calls `split` on a diff. It scans
at most 100 files, 256 Ki UTF-16 code units per file and 2 Mi code units per item.
Unknown kinds, malformed or oversized bodies, or too many files yield the actual
file count without an exact-looking partial `+/-` total. These are projection
limits, not a claim that Desktop JSONL or stock's stored item is byte-lazy.

## Verification

- Five regression cases fail on the pre-correction source
  (`/var/tmp/native-ui-r0.BbOvHT/file-change-summary-red-r1.log`).
- The five cases now verify both live and saved adapters; the complete focused
  live/history run passes 43 cases (`file-change-summary-green-r1.log`).
- Strict analysis has zero issues; the pure-Dart gate passes 69 roots; formatting
  scans 217 files without changes (`file-change-*-r1.log`).
- Two real bundled-Host probes, public and installed stock, create a three-line
  file containing `one`, `- bullet` and `+literal`. Both live notification and
  saved `thread/items/list` projection report `(+3 -0)`. A second explicit turn
  updates the same file under stock's session permission. Both turns complete
  with one approval; all owned Host/stock/model processes exit. Verification:
  `/var/tmp/native-file-change-summary-stock-r1/verification.json`.
- The model is a bounded local SSE fixture with isolated HOME/CODEX_HOME and an
  owned disposable project. This establishes real stock protocol/runtime behavior,
  not provider-account use, packaged visual fidelity or Human acceptance.

The per-item metadata/lazy-preview seam, cold saved previews and streaming
`item/fileChange/patchUpdated` projection remain active work. A turn-aggregate diff
must not be presented as authoritative content of an individual file-change item.
