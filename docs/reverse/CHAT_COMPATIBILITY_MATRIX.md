# Chat Compatibility Matrix & Backend Adaptation Architecture

> **Audited Package**: ChatGPT / Codex Desktop Linux Packaging (`26.1103.32239`)  
> **Target Subsystems**: Backend Seam (`lib/src/domain/`), Transport Adapters (`lib/src/transport/`)  
> **Evidence Grading Standards**: `PUBLIC_DOC`, `PUBLIC_SOURCE`, `LOCAL_SCHEMA`, `STATIC_BUNDLE`

---

## 1. Executive Summary & Architectural Invariant

A foundational design requirement of `Codex-Native-Unoffical` is the strict decoupling of user-facing presentation components from underlying AI execution engines:

> **The Flutter UI and domain viewmodels must never bind directly to private, undocumented backend endpoints (`/backend-api/*`). The core application foundation is built on public supported APIs (`/v1/chat/completions`) and the stock local `codex app-server` JSON-RPC engine. Any proprietary compatibility adapter must exist strictly as an optional, isolated transport plugin.**

This document establishes the capability matrix across all supported and potential backends, defines fallback behaviors, and guarantees graceful degradation when features are unavailable on a given backend.

---

## 2. Multi-Backend Capability Support Matrix

| Feature / Capability | Public OpenAI REST (`/v1/*`) | Stock Local `codex app-server` | Direct Host Remote (`codex-native-host`) | Isolated Compatibility (`/backend-api/*`) |
|---|---|---|---|---|
| **Standard Prose Chat** | Full Support (`/v1/chat/completions`) | Full Support (`turn/start`) | Read-Only History Projection (`thread/turns/list`, `thread/items/list`, `thread/items/read`; `turn/start` fails closed) | Full Support (Session SSE) |
| **Token-by-Token Streaming** | Full Support (SSE) | Full Support (`item/agentMessage/delta`) | Lifecycle Notifications Only (`turn/started`, `turn/completed`, `item/started`, `item/completed`, `thread/*`; token deltas unrouted) | Full Support (Web SSE) |
| **Local Command Execution** | Unsupported (Cloud API only) | Full Support (Child process bash) | Read-Only Activity Summary (writes & host output-range reads fail closed) | Unsupported (Cloud sandbox only) |
| **Interactive Tool Approvals**| Unsupported (Client-side manual) | Full Support (`ServerRequest` approval) | Unsupported in Read-Only Mode (`serverRequests` empty; `decideApproval` fails closed) | Unsupported (No host terminal) |
| **Git Diff Generation** | Unsupported | Full Support (`turn/diff/updated`) | Unsupported in Read-Only Mode (`turn/diff/updated` unrouted) | Unsupported |
| **Workspace File Ingestion** | Multipart upload (`/v1/files`) | Direct local path referencing | Read-Only Attachment Metadata (`turn/start` & file upload fail closed) | Web upload pipeline |
| **Detail-Mode Filtering** | Supported (UI projection filter) | Supported (UI projection filter) | Supported (UI projection filter) | Supported (UI projection filter) |
| **Multi-Turn Memory Cap** | Server-side window / truncation | Client-enforced 100-turn window | Client/Host-enforced 100-turn & 100-item page caps (`MAX_PAGE_SIZE = 100`) | Server-enforced cloud history |
| **Credential Requirement** | Developer API Key (`sk-...`) | Local user login via CLI | Scoped ephemeral pairing token (`readOnlyCodex`) | Cloud web session cookie |
| **Support Classification** | **PUBLIC_SUPPORTED** | **PUBLIC_SUPPORTED** | **PUBLIC_SUPPORTED** (`READ_ONLY`) | **PRIVATE_OPTIONAL_ONLY** |

---

## 3. The `ConversationBackend` & `ExecutionBackend` Abstraction Contracts

All conversation and agentic execution transports implement the pure domain interfaces in `lib/src/domain/conversation_backend.dart` (implemented by `CodexTransport` and `RuntimeController`, with mode-aware capability projection via `resolveEffectiveCapabilities` in `lib/src/domain/product_mode.dart`):

```dart
abstract interface class ConversationBackend
    implements ThreadGateway, ModelGateway, HistoryGateway, TurnGateway {
  BackendCapabilities get capabilities;
}

abstract interface class ExecutionBackend
    implements
        ConversationBackend,
        ApprovalGateway,
        OutputGateway,
        EcosystemGateway {
  @override
  BackendCapabilities get capabilities;
}

// Inherited gateway contracts:
// - ThreadGateway: threads, listThreads, readThread, startThread, resumeThread,
//   renameThread, archiveThread, unarchiveThread, forkThread, revertThread,
//   compactThread, deleteThread
// - ModelGateway: listModels
// - HistoryGateway: listHistoryTurns, listHistoryItems, readHistoryItems
// - TurnGateway: turns, startTurn, steerTurn, interruptTurn
// - ApprovalGateway: approvals, decideApproval
// - OutputGateway: readOutputRange
// - EcosystemGateway: listSkills (List<SkillSummary>), setSkillEnabled,
//   listPlugins (List<PluginMarketplaceSummary>),
//   listMcpServerStatus (List<McpServerStatusSummary>)
```

---

## 4. Graceful Degradation & Fallback Policies

When a user switches between backends or operates in restricted environments:

1. **Terminal Commands on Cloud Backends**:
   - If `capabilities.supportsCommandExecution == false` (e.g. when connected to standard OpenAI REST API), the composer hides the Execution Target selector and permissions pill.
   - Any tool call generated by the model is rendered as a read-only code suggestion rather than an executable command card.
2. **Diff Viewer on Non-Codex Backends**:
   - The Thread Header disables the `Changes (N)` diff action button, showing a tooltip: `Diff review requires local Codex workspace engine`.
3. **Detail Modes on Text-Only Streams**:
   - When running in `Prose` mode on a backend with intermediate tool steps, tool steps are quietly hidden. On prose-only backends, all three detail modes render identically without errors.
4. **Offline / Process Crash Recovery**:
   - If the local `codex app-server` process dies unexpectedly, the UI transitions to the `error` state, preserves active thread and draft input, and offers a one-click `Restart Runtime` action without restarting the entire desktop application.
