# Host-backed per-item file-diff payloads

Base main `0e2a5b80464f7ab6e3f5ab9034e9c37ecf6593ec` has exact hosted
CI43203383623 green on all three jobs. This next Track F sub-slice fixes the
payload boundary; typed per-file metadata, lifecycle retirement and U9 timeline
binding are still active work, not completed UI.

## Contract and implementation

The public stable FileUpdateChange shape carries a required string `diff` at
the typed ThreadItem/changes paths and patchUpdated params.changes. The Host
now spools only those exact fields, preserving opaque MCP arguments/results,
legacy approval fileChanges maps and aggregate turn/diff/updated payloads.

The sanitized `diff` stays an empty **string**, with a sibling
`_codexNativeFileDiff` containing the existing opaque OutputDescriptor fields
and `lineStats: {contentLines, additions, deletions}`. File kind can occur after
diff, so streaming decode measures raw content lines and unified-hunk counts
independently. An11-byte line prefix survives fragmented and escaped input;
no full-file buffer or per-line allocation is introduced. Dart chooses the
appropriate count only after decoding kind. Live/history and existing read-only
Remote share the summary helper; direct-stock raw strings retain the bounded
compatibility path. No Remote RPC or notification allowlist is expanded.

Existing quotas/dedup, candidate rollback, opaque reads and session lifetime
remain shared with command output. The sanitized-forward8MiB limit is retained.
Only an explicitly expanded file should cause a bounded range read; descriptor
retirement and truthful unavailable/truncated states are required before U9 binds
the data. The current summary retains counts, not descriptors or preview bodies.

## Source and process evidence

- Rust workspace:108 tests pass (26 library,78 binary,4 process integration);
  format and two-job Clippy with `-D warnings` pass. New coverage includes every
  typed item path, method/kind key order, escaped one-byte fragments, opaque
  payload preservation, repeated-body dedup, rollback and9MiB truncation/capture.
- Dart:46 targeted live/history cases, strict analysis0 and pure-Dart69 pass.
  Host metrics are tested independently for add/delete/update; raw direct-stock
  parsing remains covered. Logs: `/var/tmp/native-ui-r0.BbOvHT/file-diff-*r1.log`.
- A **controlled Host-process protocol fixture**, not a stock app-server, emits
  one valid-shaped9MiB FileUpdateChange body. The unchanged released Host
  SHA73218b9253ec1ff72173c39ce7356d942d732948318843b15c7b236c62598878
  forwards nothing and exits1 with `sanitized app-server message exceeds
  8388608 bytes`. This failure is preserved.
- The new debug Host SHA70afa24d74305c7a1a4bdc57f6b782d0881d2f57273af68821e79e7222487b1a
  handles that same fixture, forwards407 bytes, reports3,145,728 content lines
  and serves an explicit96-byte host/output/readRange request correctly. It
  exits0. Both Host/fixture child pairs are absent after awaited close.
  `/var/tmp/native-file-diff-host-large-r1/verification.json` records both runs.
- Separate **real bundled-Host/stock-runtime probes** use the new Host with
  public0.167.2 and installed0.167.0-alpha.3.2. Created sign-prefixed Markdown
  reports `+3 -0` live and saved, session editing completes, and all owned
  Host/stock/model processes exit. These are actual stock behavior with a
  controlled local model, not provider-account or Human acceptance:
  `/var/tmp/native-file-change-summary-stock-r2/verification.json`.

Main integration, targeted peer review and exact-source shared/UI gates for this
new Host sub-slice remain separate. Its process fixture is not described as a
full-product E2E test. Golden A7/per-item preview remains PARTIAL.
