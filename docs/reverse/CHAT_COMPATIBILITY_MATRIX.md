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
| **Standard Prose Chat** | Full Support (`/v1/chat/completions`) | Full Support (`turn/start`) | Full Support (Replayed stream) | Full Support (Session SSE) |
| **Token-by-Token Streaming** | Full Support (SSE) | Full Support (`thread/token/delta`) | Full Support (Coalesced WebSocket) | Full Support (Web SSE) |
| **Local Command Execution** | Unsupported (Cloud API only) | Full Support (Child process bash) | Full Support (Host execution) | Unsupported (Cloud sandbox only) |
| **Interactive Tool Approvals**| Unsupported (Client-side manual) | Full Support (`ServerRequest` approval) | Full Support (Remote approval RPC) | Unsupported (No host terminal) |
| **Git Diff Generation** | Unsupported | Full Support (`turn/diff/updated`) | Full Support (Host git diff stream) | Unsupported |
| **Workspace File Ingestion** | Multipart upload (`/v1/files`) | Direct local path referencing | Streaming file fetch from Host | Web upload pipeline |
| **Detail-Mode Filtering** | Supported (UI projection filter) | Supported (UI projection filter) | Supported (UI projection filter) | Supported (UI projection filter) |
| **Multi-Turn Memory Cap** | Server-side window / truncation | Client-enforced 100-turn window | Host-enforced 100-turn window | Server-enforced cloud history |
| **Credential Requirement** | Developer API Key (`sk-...`) | Local user login via CLI | Scoped ephemeral pairing token | Cloud web session cookie |
| **Support Classification** | **PUBLIC_SUPPORTED** | **PUBLIC_SUPPORTED** | **PUBLIC_SUPPORTED** | **PRIVATE_OPTIONAL_ONLY** |

---

## 3. The `ConversationBackend` & `ExecutionBackend` Abstraction Contracts

All conversation and agentic execution transports implement the pure domain interfaces in `lib/src/domain/conversation_backend.dart` (implemented by `CodexTransport` and `RuntimeController`, with mode-aware capability projection via `resolveEffectiveCapabilities` in `lib/src/domain/product_mode.dart`):

```dart
abstract interface class ConversationBackend {
  Stream<ThreadLifecycleEvent> get threads;
  Stream<TurnStreamEvent> get turns;
  Future<ThreadPage> listThreads(ThreadListQuery query);
  Future<ThreadSummary> readThread(String threadId);
  Future<ThreadSummary> startThread(ThreadStartOptions options);
  Future<ThreadSummary> resumeThread(ThreadResumeOptions options);
  Future<void> renameThread({required String threadId, required String name});
  Future<void> archiveThread(String threadId);
  Future<ThreadSummary> unarchiveThread(String threadId);
  Future<ThreadSummary> forkThread(ThreadForkOptions options);
  Future<ThreadSummary> revertThread({
    required String threadId,
    required String beforeTurnId,
  });
  Future<void> compactThread(String threadId);
  Future<void> deleteThread(String threadId);
  Future<ModelPage> listModels(ModelListQuery query);
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query);
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query);
  Future<HistoryItemPage> readHistoryItems(HistoryItemReadQuery query);
  Future<TurnHandle> startTurn(TurnStartOptions options);
  Future<String> steerTurn(TurnSteerOptions options);
  Future<void> interruptTurn({required String threadId, required String turnId});
}

abstract interface class ExecutionBackend implements ConversationBackend, OutputGateway {
  Stream<ApprovalStreamEvent> get approvals;
  Future<void> decideApproval({
    required Object requestId,
    required ApprovalDecision decision,
  });
  Future<List<SkillMetadata>> listSkills({List<String> cwds = const []});
  Future<bool> setSkillEnabled({required String path, required bool enabled});
  Future<List<PluginMarketplaceSummary>> listPlugins({List<String> cwds = const []});
  Future<List<McpServerStatusSummary>> listMcpServers();
}
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
