# Typed per-item metadata and explicit file previews

Track F continuation of Host commit `0d1bf34`, based on main `0e2a5b8`.
This completes the typed data/read seam for U9; timeline binding and matched
official/Native captures remain a separate active presentation slice.

## Retained state and authority

- Live items and selected saved-item details retain a FileChangeSet: at most24
  ordered entries, bounded512-code-unit path/move-path labels, kind, nullable
  statistics and opaque OutputDescriptor. No diff body, raw RPC map or preview
  lines are stored in HistoryItem/ConversationEntry. Turn summaries retain no
  file metadata references at all. Total file count remains explicit; access
  beyond the first24-file window still needs a bounded paging path.
- Stable patchUpdated creates/replaces the same activity. An early patch survives
  a later empty started snapshot; a late patch does not turn a terminal item back
  into inProgress. Existing history/entry caps, generation fences and streaming
  coalescing remain unchanged.
- Runtime invalidation retires file references in both projections. The optional
  local HistoryFileChangeGateway is implemented by ProcessTransport and the
  runtime service; CodexTransport/Remote acquire no new required operation or RPC.
- An explicit expansion first reads its exact live Host capability, because a
  running patch can precede persistence. Missing/expired references refresh only
  one stock item through the already adopted experimental thread/items/read,
  validate turn/item/index/path/kind and read the fresh opaque reference. There
  is no path-based filesystem read, implicit resume, turn replay or aggregate
  fallback. The stock whole-item fallback remains explicit.
- Known-empty content needs zero RPCs. Remote/nonlocal body capability is gated
  while metadata/empty states remain displayable. Unavailable/quota-denied,
  unsupported and oversized-legacy states remain distinct from an empty diff.
- Each body read is capped at64KiB; incomplete trailing UTF-8 is trimmed safely,
  malformed earlier data fails. The retained result is at most80 lines,
  512 code units per line and24Ki code units total. Add/delete lines remain raw
  content (`isUnifiedDiff == false`), so Markdown signs do not change their kind.
- HistoryController owns a4-entry active cache and at most4 physical reads.
  Same-key calls coalesce. Releasing a view cannot free a physical slot early;
  collapse/release, thread binding, runtime invalidation and disposal retire
  pending publication. Old failures cannot clear a newer same-key request.

## Verification

- **100 targeted cases pass** across file metadata/preview/summary, live/history
  adapters and both conversation/history controllers. Strict analysis0 and
  pure-Dart70 pass (`file-change-reader-focused-r3.log`, `analyze-r6`, `pure-r3`).
- Preserve the first reader96-pass/four-failure run: the new test fixture omitted
  the required `encoding: base64` marker. The existing output adapter correctly
  rejected it. Only the fixture was corrected. Earlier bytes/data type errors,
  nullable-interface promotion and style findings are preserved in the separate
  analysis logs, not relabelled as green runs.
- Real public0.167.2 and installed0.167.0-alpha.3.2 probes use the new Host with
  isolated HOME/CODEX_HOME and an owned local model. Each first creates a file,
  then changes its working-tree content in a second explicit turn.
- Direct and cold-after-Host-restart previews of the **first** file-change item
  return its original three lines, even while the actual file starts with the
  second turn's `two` content. The cold read mints a different session reference.
  Model call count stays4; no resume or model replay is introduced.
- All8 recorded original/restarted Host/stock identities and both bounded models
  exit after awaited close. Verification:
  `/var/tmp/native-file-change-preview-stock-r1/verification.json`.

These are real stock process outcomes with a controlled model, not provider-account
use, a packaged U9 walk or Human acceptance. New multi-file timeline binding,
file-window paging and adjacent large aggregate turn/diff forwarding remain
machine-actionable; Golden A7 stays PARTIAL. Current stock source forwards
content-exact aggregate diffs without a size bound, so the per-item9MiB Host
fixture must not be described as proof of the entire large-file turn workflow.
