# Targeted Peer Audit — `agent/codex-approval-choices` (`c2b5a64`)

- **Audited commit:** `c2b5a64aad831f4d9219fb323702bfc1c72e57bf` (`agent/codex-approval-choices` in `/var/tmp/native-codex-approval-choices`)
- **Base commit:** `ba6f27c0834c6e005904c0cda9da1ae8eed4caeb` (`main`)
- **Audit mode:** Read-only source inspection + official Desktop `25894` ASAR cross-check (`/webview/assets/async/474578.483b200efe.js`, ASAR SHA-256 `121edc7be15b6870fbef8b10ec637be9baef4a629471d80e1192385cf40a4b14`)
- **Verdict counts:** **`0 P0`, `1 P1`, `2 P2`** (`1` investigated compatibility candidate explicitly cleared as **`INVALID` / working as intended** via `474578`)

---

## 1. Exact Inspected Scope & Tests Not Run

### Inspected Files on `c2b5a64`
1. `lib/src/domain/approval_models.dart` (`lines 1–145`)
2. `lib/src/protocol/server_request_protocol.dart` (`lines 1–1408`)
3. `lib/src/features/approvals/approval_controller.dart` (`lines 1–120`)
4. `lib/src/app/presentation/diff_approval_output.dart` (`_ApprovalBanner`, `lines 270–444`; verified `0` edits after `class _HistoryEntryView`)
5. `lib/src/app/codex_native_app.dart` (`approval_models.dart` import diff)
6. `test/protocol/approval_choices_protocol_test.dart` (`lines 1–449`)
7. `test/features/approvals/approval_choices_controller_test.dart` (`lines 1–84`)
8. `test/app/approval_choices_test.dart` (`lines 1–92`)
9. `docs/reverse/APPROVAL_CHOICES_EVIDENCE.md`, `docs/DECISIONS.md` (`ADR-064`), `docs/RESEARCH.md`, `PROJECT_STATUS.md`, `docs/reverse/CODEX_DESKTOP_FUNCTIONAL_AUDIT.md`

### Tests Not Run by Peer Auditor
- No `flutter test` or runtime probes were re-executed inside `/var/tmp/native-codex-approval-choices` during this peer review (kept read-only per single-worktree ownership).
- Real-stock `item/fileChange/requestApproval` session persistence, real-stock managed-network (`networkApprovalContext`) emission, and combined `U8 + approval-choices` merged gates/packaged checks were **not** run in this audit and remain pending at integration.

---

## 2. Verified Invariants (`0 P0`) & Cleared Candidate (`INVALID`)

### Verified Consent Authority, Lifecycle Identity, and Wire Semantics
- **No invented generic session grant:** Omitted `availableDecisions` on generic `item/commandExecution/requestApproval` falls back strictly to `[approveOnce, reject, cancelTurn]` inside `_commandApprovalDecisions` (`server_request_protocol.dart:1185–1228`), never `approveForSession`.
- **Structured payload identity & immutability:** `ApprovalDecision.withExecpolicyAmendment` wraps `List.unmodifiable(amendment)` and retains `Object` identity (`==` / `hashCode` not overridden on `ApprovalDecision`), so client-constructed lookalikes and retired choices from earlier requests with reused JSON-RPC IDs fail `ApprovalRequest.supports` and `ServerRequestProtocolAdapter.decideApproval` (`UnsupportedError`, `server_request_protocol.dart:119–123`).
- **Checkpoint & escalated-permission safety:** `final humanCheckpoint = params['kind'] == 'humanCommand'` (`server_request_protocol.dart:1165, 1176–1180, 1189`) restricts advertised choices inline to `approveOnce`, `reject`, and `cancelTurn` and skips session/policy fallback; `params['additionalPermissions'] == null` (`line 1218`) suppresses `proposedExecpolicyAmendment` fallback.
- **Denial vs cancellation wire fidelity:** Unconditional `ApprovalDecision.reject` maps to stable `{'decision': 'decline'}` (`_encodeApprovalDecision`, `server_request_protocol.dart:1142–1147`) even when `availableDecisions` omits `'decline'` (e.g. `['cancel']`), keeping refusal independent of turn-interrupting `{'decision': 'cancel'}`. Legacy `execLegacy` and `patchLegacy` (`execCommandApproval` / `applyPatchApproval`, `lines 132–140`) preserve `'approved'` vs `{'denied': {'rejection': 'Rejected by the user'}}` without inheriting session grants, and unsupported `item/permissions/requestApproval` (`lines 141–145`) fails deterministically with `_unsupportedErrorCode = -32000`.

### Investigated & Cleared Candidate (`INVALID` — Matches `25894` `474578`)
- **Candidate checked:** `server_request_protocol.dart:1210–1216` compatibility fallback admits only the first `allow` entry from `proposedNetworkPolicyAmendments` (`choice.networkAction == ApprovalNetworkAction.allow`) and ignores proposed `deny` entries when `availableDecisions` is `null`.
- **Why invalid / working as intended:** Direct inspection of `25894` `/webview/assets/async/474578.483b200efe.js` confirms `w = "exec" === U.type ? U.proposedNetworkPolicyAmendments?.find(ts) ?? null : null` where `function ts(e){ return "allow" === e.action }`. Official Desktop likewise binds only the first `allow` amendment in legacy `proposedNetworkPolicyAmendments` mode; explicit `deny` amendments remain supported when advertised via `availableDecisions`.

---

## 3. Concrete Actionable Findings (`1 P1`, `2 P2`)

### `P1-1` — `_ApprovalBanner` single-row `Flexible` button strip truncates opposite persistent policies to identical prefixes and overflows `RenderFlex` within the 16-choice protocol bound
- **Location:** `lib/src/app/presentation/diff_approval_output.dart:379–400` (`_ApprovalBanner` `Row` + `Flexible`), `lib/src/app/primitives/codex_button.dart:105, 249`, and `lib/src/protocol/server_request_protocol.dart:1168` (`advertised.length > 16`).
- **Evidence & reproduction math:**
  1. **Opposite-policy consent ambiguity (`5–6` advertised choices in narrow/compact `320–520 px` conversation widths):** `_ApprovalBanner` places all `actions` (`_orderedChoices` + unconditional `reject`) into a single non-wrapping `Row` of `Flexible(child: CodexButton(size: CodexButtonSize.sm, ...))` with `8 px` gaps. For an advertised network approval with `[applyNetworkPolicyAmendment(allow), applyNetworkPolicyAmendment(deny), acceptForSession, accept, decline, cancel]` (`6` buttons), `TextOverflow.ellipsis` collapses `"Always allow <host>"` and `"Always deny <host>"` (`_label`, `lines 422–425`) to identical `'Alw…'` (or `0 px` blank pills), making opposite persistent host rules visually indistinguishable.
  2. **Deterministic horizontal `RenderFlex` overflow within admitted protocol cap (`advertised.length <= 16`):** Each `CodexButton(size: CodexButtonSize.sm)` enforces `EdgeInsets.symmetric(horizontal: 8.0)` (`16 px` minimum width at `0 px` text). Minimum row width for `N` buttons is `16*N + 8*(N - 1)`. At a `320 px` conversation width (`264 px` inner banner width after outer/card padding), any valid request with `N >= 12` actions (`280 px > 264 px`, up to `17` actions = `400 px` at `16` advertised choices + `reject`) throws `RenderFlex overflowed ... on the right`.
- **Constraint note for fix:** Unconstrained `Wrap` alone is **not** safe (`Root`'s retained `r2` already proved a `33 px` vertical overflow and collapsed the detail viewport in short splits). The fix must keep explicit choice labels distinguishable and horizontally overflow-safe (e.g. bounded explicit primary actions + overflow menu/selector or height-bounded scrollable action strip) while preserving non-zero detail viewport height in short splits.

### `P2-1` — Same-connection `ApprovalResolvedEvent` + reused `requestId` clears `ApprovalController._deciding` while the replacement request's RPC is still in flight
- **Location:** `lib/src/features/approvals/approval_controller.dart:20, 28, 59, 63, 70, 79–82, 88–99`.
- **Evidence:** Cross-runtime retirement is already guarded by `final generation = _runtimeGeneration` (`lines 48, 63, 79`), and `choose(ApprovalRequest request, ...)` (`line 42`) checks `identical(pending, request)`. However, within the **same** runtime connection (`generation == _runtimeGeneration`), `_deciding` is `final Set<Object> _deciding = {}` keyed by `requestId` (`isDeciding(Object requestId)`). If `reqA` (`requestId: 1`) is awaiting `gateway.decideApproval(...)` when same-connection `ApprovalResolvedEvent(requestId: 1)` (`lines 96–98`) removes `reqA` and clears `1` from `_deciding`, and a new `reqB` arrives on the same connection reusing `requestId: 1` (`lines 88–92`) and starts deciding (`_deciding.add(1)`), `reqA`'s `finally` block sees `generation == _runtimeGeneration` and executes `_deciding.remove(1)` (`line 80`) while `reqB`'s `decideApproval` Future is still pending—prematurely clearing `isDeciding` and re-enabling `reqB`'s action buttons.
- **Recommended direction:** Track in-flight decisions by `ApprovalRequest` identity (`Set<ApprovalRequest>.identity()`) rather than raw `requestId`.

### `P2-2` — Structured choice deduplication in `_commandApprovalDecisions` & multiline (`\n` / `\r`) `execpolicy` suppression vs `25894` `474578`
- **Location:** `lib/src/protocol/server_request_protocol.dart:1182, 1218–1225, 1271–1288` (`_commandApprovalDecisions`, `_parseExecpolicyApprovalDecision`) and `lib/src/app/presentation/diff_approval_output.dart:434–436` (`_scope`).
- **Evidence:**
  1. At `server_request_protocol.dart:1182`, `if (!choices.contains(choice)) choices.add(choice);` only deduplicates `const` singleton choices (`approveOnce`, `approveForSession`, `reject`, `cancelTurn`) because structured `ApprovalDecision` intentionally uses `Object` identity (`==`). Duplicate structured entries in `availableDecisions` (e.g. repeated identical `acceptWithExecpolicyAmendment` or `applyNetworkPolicyAmendment` JSON objects) remain duplicated in `request.availableDecisions` and render duplicate buttons. Deduplicating via a local structural key set inside `_commandApprovalDecisions` avoids duplicate buttons while keeping `Object` identity across requests.
  2. In `25894` `/webview/assets/async/474578.483b200efe.js` `ta(e)`, official Desktop explicitly suppresses `proposedExecpolicyAmendment` whenever `e.join(" ")` contains `\n` or `\r`:
     `k = "exec" === U.type ? function(e){ if (null == e) return null; let t = e.join(" "); return t.includes("\n") || t.includes("\r") ? null : e }(U.proposedExecpolicyAmendment) : null`.
     `_commandApprovalDecisions` / `_parseExecpolicyApprovalDecision` (`lines 1218–1225, 1271–1288`) currently admits tokens containing `\n`/`\r`, which also split across lines inside `_ApprovalBanner._scope` (`lines 434–436`: `'Approve and apply the proposed command rule. Prefix arguments in order:\n1: ...'`). Suppressing `\n`/`\r` in `proposedExecpolicyAmendment` fallback (and escaping `\n`/`\r` in `_scope` when explicitly advertised) aligns with `474578` and prevents multiline rule-scope spoofing.
