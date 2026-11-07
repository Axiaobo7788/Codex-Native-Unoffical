# ChatGPT Compatibility & Future `ChatBackend` Architecture Analysis (Recalibrated)

> **Evidence Sources**:
> - `STATIC_BUNDLE`: `.vite/build/early-bootstrap-920-a204a41244c4b913.js` (`@2190585`, `@4400493`), `.vite/build/early-bootstrap-339-10eda6b28d12299c.js` (`@780000..792000`), and `webview/assets/async/182735.d3d917f28d.js`.
> - `PUBLIC_SOURCE`: Stock `/opt/codex-desktop/resources/codex app-server` (`0.167.0-alpha.3.2`).
> - `PUBLIC_DOC`: OpenAI Platform Responses API (`https://platform.openai.com/docs/api-reference/responses`).

---

## 0. Correction of the `STEPS_PROSE` Inference Chain (`ADR-031` -> `ADR-032`)

In the initial reverse-analysis pass (`ADR-031`), observing `conversationDetailMode = "STEPS_PROSE"` led to the over-inferred claim that *"Everyday Chat / Work prose mode is powered by stock `codex app-server` (`PUBLIC_SUPPORTED`), so we can build a `PUBLIC_SUPPORTED` Native Chat experience simply by running stock `app-server` in `STEPS_PROSE` mode."*

**Why that inference was wrong (`STATIC_BUNDLE` proof)**:
1. **What `STEPS_PROSE` actually does in `early-bootstrap-339 @780000..792000`**:
   - When `conversationDetailMode.effective === "STEPS_PROSE"`, the Electron main process sets `includeProseDetailLevelInstructions: true` (`early-bootstrap-920 @4400493`).
   - Function `a7` (`early-bootstrap-339 @787500`) appends constant `a2` (`### Non-technical UI`) inside `<app-context>...</app-context>` of `developerInstructions` for **Codex / Work agent threads**, instructing the coding agent to avoid technical jargon and hide intermediate bash/python steps while producing artifacts, while the renderer UI collapses command execution cards.
2. **What `STEPS_PROSE` does NOT do**:
   - It does **not** make stock `codex app-server` the backend for standard ChatGPT Cloud Chat (`/chat/:conversationId`). Standard Chat in ChatGPT Desktop is backed by `/backend-api/f/conversation` (`source_kind = "chatgpt"`, `conversation_origin IS NOT 'tpp'`) using the `MrGp` conversation tree DAG.
   - Stock `codex app-server` has no built-in `"STEPS_PROSE"` RPC field; the string `"STEPS_PROSE"` does not exist in `codex app-server generate-json-schema`.
   - Furthermore, copying the proprietary `a2` (`### Non-technical UI`) developer prompt from `early-bootstrap-339` into `Codex-Native-Unoffical` would violate **`AGENTS.md` Non-Negotiable Rule #1** (*"Do not copy or fork Codex system prompts into the client"*).

---

## 1. Honest Comparison of the Three Candidate `ChatBackend` Routes

If `Codex-Native-Unoffical` expands beyond a pure Codex client in a future phase to offer a "Chat" surface, there are three distinct technical routes. None of them is a magic bullet; each has explicit trade-offs:

| Dimension | Route A: `OpenAIResponsesBackend` | Route B: `ChatGPTCompatibilityBackend` | Route C: `CodexBackend` (Prose-First UI Filter) |
|---|---|---|---|
| **Underlying Transport / API** | Official `POST https://api.openai.com/v1/responses` | Private `POST https://chatgpt.com/backend-api/f/conversation` (+ `/prepare`) | Local stock `codex app-server` (`thread/start`, `turn/start`) |
| **Evidence Confidence** | `PUBLIC_DOC` | `STATIC_BUNDLE` (`DISCOVERED`) | `PUBLIC_SOURCE`, `LIVE_CALLED` |
| **Support Classification** | **`PUBLIC_SUPPORTED`** | **`PRIVATE_WEB_SESSION`** | **`PUBLIC_SUPPORTED`** |
| **Authentication & Billing** | Requires Platform API Key (`OPENAI_API_KEY`, pay-per-token) | Uses consumer ChatGPT Plus/Pro/Team web session token | Uses stock Codex OAuth (`account/login/start` ChatGPT sign-in) or API key |
| **Syncs with `chatgpt.com` Web Chat History?** | **No** (stored locally or on Platform `Responses` store) | **Yes** (`source_kind = "chatgpt"`, `MrGp` tree DAG) | **No** (stored in local `~/.codex/state_5.sqlite` as a Codex thread) |
| **Anti-Bot / Breakage Risk** | **Zero** (versioned public SLA) | **High** (requires `OpenAI-Sentinel-Chat-Requirements-Token`, `Proof-Token`, `Turnstile-Token`; unannounced schema changes) | **Zero** (stock `codex app-server` protocol) |
| **True Product Identity** | Native API Chat client | Unofficial `chatgpt.com` web-session client | **Prose-first local Codex agent** (hides shell cards by default in UI, but still runs the Codex harness) |
| **Violates `AGENTS.md` Rule #1?** | No | No (if prompt-free), but high maintenance/ToS risk | No **only if** implemented purely as a client UI filter (`STEPS_PROSE` view toggle) without copying `a2` prompts |

---

## 2. Architectural Recommendation (`ADR-032`)

1. **Keep the Core Client Purely `PUBLIC_SUPPORTED` + `EXPERIMENTAL_STOCK_SCHEMA`**:
   - Never make `Route B` (`/backend-api/f/conversation`) a core or default dependency of `Codex-Native-Unoffical`.
2. **Treat `STEPS_PROSE` as a Client-Side Presentation Filter (`ADOPT_PATTERN`)**:
   - Within our existing Codex experience (`Route C`), adding a user-facing turn-detail presentation toggle (`Prose | Commands | Full Execution`) that controls whether intermediate command/tool cards are collapsed by default is a clean, 100% presentation-layer improvement that requires **zero** prompt injection and **zero** private endpoints.
3. **Keep Future `ChatBackend` Pluggable (`RESEARCH_MORE`)**:
   - If a dedicated non-agent Chat mode is authorized in a future phase, define a clean domain interface (`ChatBackend`) where `OpenAIResponsesBackend` (`Route A`, `PUBLIC_SUPPORTED`) is the supported cloud implementation, and any `ChatGPTCompatibilityBackend` (`Route B`, `PRIVATE_WEB_SESSION`) remains strictly optional and isolated.
