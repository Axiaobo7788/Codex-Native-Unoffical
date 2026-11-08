# Chat Streaming, Viewport Anchoring & Coalescing Specification

> **Audited Package**: ChatGPT / Codex Desktop Linux Packaging (`26.1103.32239`)  
> **Target Subsystems**: Stream Pipeline (`lib/src/transport/`), Presentation Timeline (`lib/src/app/presentation/conversation.dart`)  
> **Evidence Grading**: `STATIC_BUNDLE`, `LIVE_OBSERVED`, `LOCAL_SCHEMA`, `PUBLIC_DOC`

---

## 1. Executive Summary & Problem Formulation

High-velocity text generation presents two major engineering challenges in desktop and mobile client development:
1. **Per-Token Render Thrashing**: When an LLM streams tokens at 60–120 tokens/second, triggering a full Flutter widget layout and paint pass on every discrete token causes severe main-thread UI jank, frame drops, and CPU spikes.
2. **Scroll Jump & Disorientation**: If a user scrolls up into older conversational context while generation is active, appending new incoming tokens at the bottom can erroneously force-scroll or jump the viewport, disorienting the reader.

This specification details the wire event formats, the **50 ms Stream Coalescing Invariant**, and the **Content-Identity Bottom-Anchored Viewport Architecture** that solve both challenges in `Codex-Native-Unoffical`.

---

## 2. Wire Streaming Protocols

### 2.1 Stdio JSON-RPC Stream (`codex app-server`)

In the stock `codex app-server` runtime, streaming events are dispatched as asynchronous server notifications over stdout:

```json
{"jsonrpc":"2.0","method":"thread/token/delta","params":{"threadId":"th-8291","turnId":"tu-0192","delta":"\n```dart\n"}}
{"jsonrpc":"2.0","method":"command/exec/outputDelta","params":{"threadId":"th-8291","turnId":"tu-0192","itemId":"it-4410","delta":"Compiling codex_native v0.1.0\n"}}
```

- **Notification Method**: `thread/token/delta` (for assistant markdown prose)
- **Output Notification**: `command/exec/outputDelta` (for raw terminal outputs)
- **Completion Event**: `turn/completed` with turn metrics and final status

### 2.2 Server-Sent Events (SSE) Stream (`https://api.openai.com/v1`)

In the public REST chat completions API, streaming arrives via standard HTTP SSE (`text/event-stream`):

```text
data: {"id":"chatcmpl-923","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}

data: {"id":"chatcmpl-923","choices":[{"index":0,"delta":{"content":" world"},"finish_reason":null}]}

data: [DONE]
```

---

## 3. The 50 ms Stream Coalescing Engine

### 3.1 Mechanism & Buffer Window

Rather than directly calling `setState()` or emitting new stream values for every individual token delta, `Codex-Native-Unoffical` routes all streaming chunks through a coalescing buffer with a **50 ms debounce/flush timer**:

```
Wire Deltas:   [t1] [t2] [t3] [t4]      [t5] [t6]           [t7]
Timeline:      --|---|---|---|----------|---|---------------|--->
Buffer:        [ t1 + t2 + t3 + t4 ]    [ t5 + t6 ]         [ t7 ]
Flush (50ms):  ========> FLUSH 1 ======> FLUSH 2 =========> FLUSH 3
UI Rebuilds:   1 frame render           1 frame render      1 frame render
```

### 3.2 Performance Benefits
- **Frame Rate Preservation**: Caps timeline rebuild frequency to at most **20 updates/second** (50 ms), maintaining smooth 60–120 FPS rendering even under maximum token velocity.
- **Garbage Collection Reduction**: Minimizes intermediate string allocations and immutable `HistoryItem` object instantiations.
- **Immediate Termination**: When `turn/completed` or `data: [DONE]` arrives, the buffer flushes immediately without waiting for the timer, ensuring zero perceived end-of-turn latency.

---

## 4. Viewport Anchoring & Reading Preservation

### 4.1 Bottom-Anchored Reverse Scroll Architecture

The conversation timeline is implemented as a bottom-anchored scrollview:

```dart
CustomScrollView(
  anchor: 1.0, // Anchored to bottom boundary
  reverse: true, // Item 0 is the newest turn at the bottom
  slivers: [ ... ],
)
```

- When the user opens a thread, the viewport is instantaneously at the newest turn without performing synthetic programmatic jump animations.
- When new tokens arrive while the user is already anchored at the bottom (`pixels == 0.0`), the scroll offset remains naturally pinned to the bottom.

### 4.2 Scrolled-Up Reading Preservation

When a user scrolls up into older conversation history (`pixels > 160.0 px` from bottom):
1. **Scroll Freeze**: Incoming tokens append to the bottom of the list without modifying the user's visible scroll offset. The viewport does **NOT** jump or jitter.
2. **"Jump to Latest" Pill**: A floating indicator appears above the composer:
   - Visual: Muted pill container (`#2F2F2F` dark / `#F4F4F4` light), down-arrow glyph, and text: `Jump to latest ↓`.
   - Interaction: Clicking smoothly animates the viewport back to `pixels = 0.0`.
3. **Content-Identity Bookmarking**: As older turns load or evicted turns slide out, `_maxRestorePages = 10` and Scheme A content-identity keys ensure exact pixel stability (`0.000 px` drift).

---

## 5. Turn Interruption & Cancellation Pipeline

When the user clicks the circular **Stop button** (`Square` glyph) in the composer control bar:

1. **Client Action**: Dispatches `turn/interrupt` JSON-RPC request to `codex app-server`:
   ```json
   {
     "jsonrpc": "2.0",
     "id": "int-552",
     "method": "turn/interrupt",
     "params": {
       "threadId": "th-8291",
       "turnId": "tu-0192"
     }
   }
   ```
2. **Host Interruption**: The app-server signals child worker threads, terminates running bash processes (SIGINT/SIGTERM), and dispatches `turn/completed` with `status: "interrupted"`.
3. **UI Transition**: The composer returns to the idle state immediately, retaining all tokens and commands generated up to the moment of cancellation.
