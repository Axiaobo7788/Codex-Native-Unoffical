# Chat Data Model & Entity Transformation Specification

> **Audited Package**: ChatGPT / Codex Desktop Linux Packaging (`26.1103.32239`)  
> **Target Domain**: Pure Dart Domain Layer (`lib/src/domain/`)  
> **Evidence Grading**: `STATIC_BUNDLE`, `LOCAL_SCHEMA`, `PUBLIC_DOC`, `INFERRED`

---

## 1. Executive Summary & Architectural Integrity

The data architectures of the official ChatGPT web/electron platform and the stock `codex app-server` represent two fundamentally different data paradigms:
1. **The Web / Electron DAG (`MrGp`)**: A branching directed acyclic graph where every message node references its parent and children, allowing multi-branch conversational trees and alternate generation paths.
2. **The Codex App-Server Linear Turn Sequence**: A linear, turn-based execution timeline where each user action initiates an agentic "Turn", containing sequential internal "Items" (reasoning steps, tool executions, file patches, prose responses).

In `Codex-Native-Unoffical`, our pure Dart domain layer (`lib/src/domain/`) normalizes both models into a clean, typed domain schema. In accordance with architecture invariant #1 (`AGENTS.md`), **all domain models are strictly acyclic, immutable, and possess zero dependencies on Flutter UI or protocol wire formats**.

---

## 2. Model Comparison: Web DAG vs Codex Linear Turns

```
Web / Electron DAG (MrGp):
            [Node 1: User Prompt]
                     |
            [Node 2: Assistant Reply A]
            /                         \
  [Node 3A: User Branch 1]    [Node 3B: User Branch 2]
            |                           |
  [Node 4A: Assistant 1]      [Node 4B: Assistant 2]

Codex App-Server Linear Turns:
  [Turn 1] ---> StartedAt, CompletedAt, User Prompt
      |---> [Item 1: Reasoning Step]
      |---> [Item 2: Command Execution: 'cargo test']
      |---> [Item 3: File Modification: 'main.rs']
      |---> [Item 4: Assistant Prose Response]
  [Turn 2] ---> Next User Prompt & Tool Items...
```

| Dimension | Web / Electron DAG (`MrGp`) | Stock Codex App-Server | Codex-Native-Unoffical Domain |
|---|---|---|---|
| **Root Entity** | `conversation_id` | `thread_id` | `ThreadSummary` + `ChatConversationDag` (`lib/src/domain/chat_conversation_dag.dart`) |
| **Node Structure** | Flat `mapping: { [id]: MessageNode }` with `parent` and `children: []` | Ordered list of `Turn` objects | `HistoryTurn` (`HistoryItem`s) + bounded `ChatMessageNode` DAG (`maxRetainedNodes = 256`, `maxSiblingsPerTurn = 16`) |
| **Branching** | Arbitrary branching supported via node pointer tree | Linear timeline (`thread/fork`, `thread/revert`) | Both: `thread/fork` / `thread/revert` on server + `< 1/2 >` sibling branch switcher (`ChatSiblingBranchInfo`) in `ChatConversationDag` |
| **Turn Sub-items** | Single monolithic message content per node | Granular items: command, tool, file patch, reasoning | Typed `HistoryItemKind` + `AssistantContentSegment` (`assistant_content_blocks.dart`) |
| **Memory Footprint** | Hydrates entire tree into browser memory | Paged `turn/list` and on-demand `thread/items/list` | Bounded sliding window (`100` turns max in memory, `256` DAG nodes max) |

---

## 3. Pure Dart Domain Model Schemas (`lib/src/domain/`)

### 3.1 `ConversationThread`
Represents the top-level session bound to a local project workspace or remote host:

```dart
class ConversationThread {
  final String threadId;
  final String title;
  final String? cwd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ThreadStatus status;
  final ThreadSettings settings;

  const ConversationThread({
    required this.threadId,
    required this.title,
    this.cwd,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.settings,
  });
}
```

### 3.2 `HistoryTurn`
Represents a discrete turn initiated by a user submission and executed by Codex:

```dart
class HistoryTurn {
  final String turnId;
  final String threadId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final TurnStatus status;
  final String userPrompt;
  final List<AttachmentPresentation> attachments;
  final List<HistoryItem> items;
  final String? errorSummary;

  Duration get duration => (completedAt ?? DateTime.now()).difference(startedAt);
}
```

### 3.3 `HistoryItem`
Represents an individual discrete action within a turn:

```dart
enum HistoryItemKind {
  userMessage,
  assistantProse,
  reasoning,
  commandExecution,
  fileChange,
  toolCall,
  approvalRequest,
}

class HistoryItem {
  final String itemId;
  final String turnId;
  final HistoryItemKind kind;
  final String content;
  final bool isCommand;
  final bool isTool;
  final String? output;
  final Map<String, dynamic> metadata;

  const HistoryItem({
    required this.itemId,
    required this.turnId,
    required this.kind,
    required this.content,
    this.isCommand = false,
    this.isTool = false,
    this.output,
    this.metadata = const {},
  });
}
```

### 3.4 `AttachmentPresentation`
Normalized representation of attached context (images, code files, folders):

```dart
enum AttachmentKind {
  localFile,
  localImage,
  projectDirectory,
  symbolMention,
}

class AttachmentPresentation {
  final String path;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final AttachmentKind kind;

  const AttachmentPresentation({
    required this.path,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    required this.kind,
  });
}
```

---

## 4. Entity State Lifecycle Transitions

### 4.1 Thread Lifecycle

```
[New Thread Request]
       |
       v
   [Created] ----> (Bound to cwd / project root)
       |
       v
    [Active] <====> [Turn Executing]
       |
       v
    [Idle] -------> (Saved in local catalog)
       |
       v
   [Archived] ----> (Toggled out of active sidebar rail)
```

### 4.2 Turn Execution Lifecycle

```
[User Dispatches Prompt in Composer]
                 |
                 v
             [Pending]
                 |
                 v
             [Running] <---------\
                 |                | (User confirms command)
        +--------+--------+       |
        |                 |       |
        v                 v       |
 [Awaiting Approval]   [Executing]|
        |                 |       |
        +--------+--------+-------/
                 |
                 v
            [Streaming] (Token deltas appended)
                 |
        +--------+--------+
        |                 |
        v                 v
   [Completed]       [Interrupted / Failed]
```

---

## 5. Bounded Memory Invariants

To prevent client degradation and high RSS memory bloat during multi-hour developer sessions:
1. **Sliding Window**: Only the most recent **100 turns** of an active thread are hydrated into memory.
2. **On-Demand Loading**: Turn items (`thread/items/list`) are loaded lazily when a user expands a `Worked for Xm Ys ›` turn divider.
3. **Spooling**: Command outputs larger than preview thresholds (`>64 KB`) are referenced via file descriptors and streamed on demand, up to the **512 MiB** hard spool limit.
4. **Zero SQLite Direct Writes**: The client never directly queries or writes to `~/.codex/` SQLite database files; all persistence is mediated through the official `codex app-server` API.
