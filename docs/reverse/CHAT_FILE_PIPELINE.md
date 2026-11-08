# Chat File Pipeline & Attachment Ingestion Specification

> **Audited Package**: ChatGPT / Codex Desktop Linux Packaging (`26.1103.32239`)  
> **Target Subsystems**: Attachment Pipeline (`lib/src/domain/`, `lib/src/protocol/`), Rust Spooler (`codex-native-host`)  
> **Evidence Grading Standards**: `STATIC_BUNDLE`, `LOCAL_SCHEMA`, `PUBLIC_DOC`, `PUBLIC_SOURCE`

---

## 1. Executive Summary & Repository Invariants

Handling attachments in an agentic coding environment introduces complex performance and safety concerns: developers frequently paste multi-megabyte log files, attach binary screenshots, mention workspace source trees, or run commands that emit hundreds of megabytes of standard output.

To safeguard memory while delivering seamless attachment presentation, `Codex-Native-Unoffical` enforces four non-negotiable invariants:

1. **The 16-Attachment Hard Cap**: A user prompt turn may contain at most **16 attachments** across all types (images, files, directories, symbol mentions). Additional attachments are rejected with a typed validation error before dispatch.
2. **The 512 MiB Output Spooling Cap**: Large terminal outputs and file contents exceeding `64 KB` are never held as monolithic strings in Flutter memory. They are spooled to disk by `codex-native-host`, allowing on-demand paged inspection up to **512 MiB per item** (and a session budget cap of **2 GiB**).
3. **Structured User Message Envelope**: Files pasted or attached to a message are extracted into structured metadata chips rendered above the user prompt bubble, rather than inlined as unformatted raw file paths.
4. **Deterministic Ephemeral Cache Lifecycle**: Attachment thumbnails and spooled output segments are stored in ephemeral directories (`~/.cache/codex-native-spool/`) and pruned automatically upon application shutdown or session termination.

---

## 2. Ingestion Channels & Pipeline Flow

```
[User Action: Drag & Drop / Clipboard Paste / File Mention (@) / File Picker (+)]
                                   |
                                   v
             +-------------------------------------------+
             |    MIME & File Path Detection Layer       |
             | - Detect binary images (PNG, JPG, WEBP)   |
             | - Detect source code text (UTF-8)         |
             | - Validate file existence & readability   |
             +-------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             |        16-Attachment Cap Enforcer         |
             |   Count <= 16 ? Proceed : Validation Error|
             +-------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             |    Attachment Presentation Structuring    |
             | - Generate local thumbnail (images)       |
             | - Extract basename & size bytes           |
             | - Wrap in AttachmentPresentation domain   |
             +-------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             |       Protocol Serialization              |
             |   Dispatched via turn/start UserInput     |
             +-------------------------------------------+
```

---

## 3. MIME Classification & Kind Mapping

| Extension / Header | Detected MIME Type | Attachment Kind | Preview Render in UI | Wire Serialization |
|---|---|---|---|---|
| `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif` | `image/png`, `image/jpeg`, etc. | `localImage` | 28px square image thumbnail chip | `{ type: "localImage", path: "..." }` |
| `.dart`, `.rs`, `.py`, `.js`, `.json`, `.md` | `text/plain`, `application/json`, etc. | `localFile` | Code file chip with syntax icon and filename | `{ type: "localFile", path: "..." }` |
| Directory path | `inode/directory` | `projectDirectory` | Folder icon + directory basename | `{ type: "directory", path: "..." }` |
| Workspace symbol `@Symbol` | `application/x-symbol` | `symbolMention` | Tag badge with symbol name | Mention text in user prompt body |

---

## 4. Large Output Spooling Architecture (`codex-native-host`)

When an agent tool or bash command produces substantial output:

```
[Command stdout/stderr] ---> [Stream Pipe]
                                  |
                                  v
              +---------------------------------------+
              |           codex-native-host           |
              |                                       |
              |  Bytes <= 64 KB:                      |
              |    Forward directly in memory         |
              |                                       |
              |  Bytes > 64 KB (up to 512 MiB):       |
              |    1. Spool chunks to disk file       |
              |    2. Forward truncated 64 KB preview |
              |    3. Emit OutputDescriptor {         |
              |         spoolFile: "/path/...",       |
              |         totalBytes: 15482910,         |
              |         isTruncated: true             |
              |       }                               |
              +---------------------------------------+
                                  |
                                  v
              +---------------------------------------+
              |           Flutter UI Client           |
              |  - Renders inline preview             |
              |  - Provides "View output" button      |
              |  - Spawns Bounded Output Dialog on    |
              |    click, paging chunks from disk     |
              +---------------------------------------+
```

### 4.1 Bounded Output Viewer Dialog
- **Modal Size**: Max width `720px`, max height `80%` viewport.
- **Scroll Optimization**: `ListView.builder` with fixed item extent (`20px` line height).
- **Page Budget**: Renders at most 1,000 lines per page with Next/Previous pagination controls, eliminating UI memory allocation for hundred-thousand-line logs.
