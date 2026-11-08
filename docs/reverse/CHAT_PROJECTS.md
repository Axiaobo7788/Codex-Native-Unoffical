# Chat Projects, Workspace Binding & Instruction Hierarchy

> **Audited Package**: ChatGPT / Codex Desktop Linux Packaging (`26.1103.32239`)  
> **Target Subsystems**: Workspace Management (`lib/src/domain/`), Sidebar Navigation (`lib/src/app/presentation/sidebar_activity.dart`)  
> **Evidence Grading Standards**: `STATIC_BUNDLE`, `LOCAL_SCHEMA`, `PUBLIC_DOC`, `PUBLIC_SOURCE`

---

## 1. Executive Summary & Workspace Model

In the official Codex Desktop architecture, conversations are not isolated, context-free chat logs; they are deeply anchored to local project workspaces (directories, git repositories, or worktrees). This workspace anchoring dictates:
1. The working directory (`cwd`) in which commands and file operations execute.
2. The automatic discovery and ingestion of developer instructions (`AGENTS.md`, `.codex/instructions.md`).
3. The visual grouping and organization of threads within the sidebar navigation rail.

This specification details the workspace binding semantics, the instruction hierarchy, and the project grouping model in `Codex-Native-Unoffical`.

---

## 2. Workspace Binding Architecture

```
+-------------------------------------------------------------------------------+
|                             LOCAL FILE SYSTEM                                 |
|                                                                               |
|  /home/developer/projects/backend-service/                                    |
|  ├── AGENTS.md                   <-- Primary Project Instruction Contract     |
|  ├── .codex/                                                                  |
|  │   └── instructions.md         <-- Codex Specific Overrides                 |
|  ├── .git/                                                                    |
|  └── src/ ...                                                                 |
+-------------------------------------------------------------------------------+
                                         |
                                         v
+-------------------------------------------------------------------------------+
|                         WORKSPACE BINDING ENGINE                              |
|                                                                               |
|  - Normalizes absolute path: /home/developer/projects/backend-service         |
|  - Derives project name: "backend-service"                                    |
|  - Detects Git root & active branch: "main"                                   |
+-------------------------------------------------------------------------------+
                                         |
                                         v
+-------------------------------------------------------------------------------+
|                      SIDEBAR NAVIGATION & THREAD MODEL                        |
|                                                                               |
|  [v] 📁 backend-service (3)  [+]                                              |
|      ├── Fix authentication crash (running)             now                   |
|      ├── Add payment webhooks                          2h ago                 |
|      └── Upgrade Postgres driver                       Yesterday              |
|                                                                               |
|  [>] 📁 frontend-mobile (5)  [+]                                              |
+-------------------------------------------------------------------------------+
```

---

## 3. Instruction Discovery & Precedence Hierarchy

Codex automatically locates and combines system and developer instructions when initializing a turn. In `Codex-Native-Unoffical`, instruction resolution follows a strict priority order:

| Priority | Instruction Source | File Location / Scope | Resolution Rule |
|---|---|---|---|
| **1 (Highest)** | **Turn Explicit Instructions** | Provided directly in user prompt or composer popover | Overrides all background defaults for this turn. |
| **2** | **Project Codex Instructions** | `<workspace_root>/.codex/instructions.md` | Dedicated project-specific Codex configuration. |
| **3** | **Project Repository Memory** | `<workspace_root>/AGENTS.md` (or `CLAUDE.md`) | General developer instructions and architectural invariants. |
| **4** | **Global User Instructions** | `~/.codex/instructions.md` | User-wide preferences across all projects on this workstation. |
| **5 (Base)** | **Stock System Persona** | Handled internally by `codex app-server` | Base Codex developer harness (never copied into client). |

*Clean-Room Invariant*: `Codex-Native-Unoffical` never forks, modifies, or copies proprietary system prompts (`STEPS_PROSE`, `a2`) into client source files. Instruction ingestion is managed entirely by the underlying `codex app-server`.

---

## 4. Sidebar Project Hierarchy & Navigation Semantics

### 4.1 Collapsible Project Folders
- **Header Structure**:
  - Left: Folder icon (`folder_outlined`), project display name (derived from directory basename or `package.json`/`pubspec.yaml`), and count badge (`(N)`).
  - Hover Action: Plus icon (`+`), immediately spawning a new thread bound to this workspace root (`Cmd/Ctrl+N`).
  - Chevron: Animated rotation (`0°` collapsed `>` vs `90°` expanded `v`).
- **Persistence**: Expanded/collapsed states for each workspace root are remembered in local client preferences.

### 4.2 Projectless / Recents Section
- Threads spawned without a specific directory binding, or initiated via global chat, are grouped into a "Recents" section at the top of the sidebar rail.

---

## 5. Execution Targets & Git Worktrees

The composer control bar includes a host/execution target selector (`CodexPopover`):
1. **Local (`Local`)**: Commands execute directly in the primary workspace directory.
2. **Git Worktree (`Worktree`)**: Codex creates or binds an isolated temporary git worktree (e.g. `.git/worktrees/codex-tu-0192`), preventing uncommitted workspace modifications while experimenting.
3. **SSH Remote (`SSH`)**: Binds execution to a configured remote devbox via SSH tunnel.
4. **Cloud Sandbox (`Cloud`)**: Offloads execution to an isolated cloud container.
