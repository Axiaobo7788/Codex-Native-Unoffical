# Desktop vs Android Client Architectural Comparison & Mobile Constraints

> **Audited Packages**:  
> - Desktop: Official ChatGPT / Codex Desktop Linux (`26.1103.32239`, Electron + Node + `codex app-server`)  
> - Android: Official ChatGPT Android (`com.openai.chatgpt`, Target SDK 34 / Android 14)  
> **Evidence Grading Standards**: `STATIC_BUNDLE`, `STATIC_APK`, `STATIC_DEX`, `PUBLIC_DOC`, `PUBLIC_SOURCE`, `LIVE_OBSERVED`

---

## 1. Executive Summary & Cross-Validation Hierarchy

In our clean-room convergence strategy, the official **Desktop client serves as the canonical primary baseline** for all user interface specifications, token measurements, and presentation logic. The **Android client (`com.openai.chatgpt`) serves as secondary cross-validation**, specifically prioritized in four tiers:

1. **Tier 1 (Highest Priority)**: Chat protocol & data model cross-validation (wire serialization, SSE streaming, chunk delimiters).
2. **Tier 2**: Codex Remote / controller architecture (mobile approval interface, remote command streaming).
3. **Tier 3**: Mobile platform constraints (foreground services, network reconnection, wakelocks, lifecycle sleep/resume).
4. **Tier 4 (Lowest Priority)**: Mobile UI appearance (single-column mobile compromises and bottom sheets; **Desktop IA strictly takes precedence**).

---

## 2. Side-by-Side Architectural Comparison Matrix

| Architectural Dimension | Official Desktop Client (`26.1103.32239`) | Official Android Client (`com.openai.chatgpt`) | Codex-Native-Unoffical (Desktop / Android) | Evidence Tag |
|---|---|---|---|---|
| **Runtime Engine** | Electron (Chromium + Node.js) | Android ART / Dalvik VM (Kotlin + Jetpack Compose / WebView) | Flutter Engine (Dart AOT) + Native Rust Host (`codex-native-host`) | `STATIC_BUNDLE` / `STATIC_APK` |
| **Local Codex Runtime** | Spawns stock `codex app-server` as child process via stdio JSON-RPC | **No local runtime**. Functions strictly as a remote controller/viewer. | Desktop: spawns stock `codex app-server`. Android: connects to Host Bridge. | `STATIC_BUNDLE` / `STATIC_DEX` |
| **Transport Boundary** | Stdio newline-delimited JSON-RPC 2.0 | HTTPS REST + SSE / WSS Relay | Desktop: Stdio JSON-RPC. Android: Authenticated WebSocket (`wss://`). | `LOCAL_SCHEMA` / `STATIC_APK` |
| **Local Persistence** | `better-sqlite3` native addon reading `~/.codex/` databases | Android Room / SQLite database with Jetpack DataStore | Domain layer is strictly acyclic; SQLite access mediated by `codex app-server`. | `STATIC_BUNDLE` / `STATIC_DEX` |
| **Credential Storage** | Local config files & OS Keychain (libsecret / Keychain) | Android Keystore / EncryptedSharedPreferences | Desktop: Host keychain. Android: Device keypair; zero OpenAI API keys stored. | `STATIC_BUNDLE` / `STATIC_APK` |
| **Information Architecture** | 3-column capable: Sidebar Rail (260px), Timeline (704px), Diff Panel | Single-column linear timeline with sliding navigation drawer | Unified responsive Flutter UI: full 3-column on desktop, drawer on phone. | `LIVE_OBSERVED` / `STATIC_APK` |
| **Diff Viewer Model** | Center-mode side-by-side or unified diff viewer (`@pierre/diffs`) | Collapsed diff cards with summary stats (`+A -D`) | Bounded unified diff viewer with file picker and lazy hunks. | `STATIC_BUNDLE` / `STATIC_APK` |
| **Interactive Approvals** | Inline warning banners with primary/secondary action buttons | Full-width bottom sheet or push notification approval | Inline `CodexActivityRow` cards with explicit approve/reject actions. | `STATIC_BUNDLE` / `STATIC_APK` |

---

## 3. Android Platform Constraints & Lifecycle Management

Developing an Android client for agentic workflows requires strict adherence to modern Android OS constraints (Target SDK 34 / Android 14):

### 3.1 Network Disconnection & Resumable Replay
Mobile devices frequently transition across Wi-Fi, cellular, and temporary dead zones. To prevent lost turns or broken approval states:
- **Sequence / Ack Tracking**: Every protocol message transmitted across the WebSocket bridge carries a monotonic sequence number (`seq`).
- **Resumable Handshake**: Upon reconnection, the client issues a `resume` packet with the `last_ack_seq`. The host replays any missed notification chunks directly from memory without restarting the turn.

### 3.2 Background Execution & Foreground Services
- When the Android app is backgrounded during a long-running turn, the OS will freeze or terminate background WebSocket threads within seconds unless accompanied by a Foreground Service.
- For active turns awaiting command approval or building large projects, an ongoing notification (`POST_NOTIFICATIONS`) with a compact progress indicator keeps the WebSocket connection alive.

### 3.3 Permissions Architecture
Inspecting the official `AndroidManifest.xml` (`STATIC_APK` / `PUBLIC_DOC`) reveals the required permissions profile:
- `android.permission.INTERNET`: Mandatory for network communication.
- `android.permission.ACCESS_NETWORK_STATE`: Monitors connection handoffs (Wi-Fi <-> Cellular).
- `android.permission.POST_NOTIFICATIONS`: Delivers turn completion alerts and background approval prompts.
- `android.permission.VIBRATE`: Haptic confirmation on command approval/rejection.
- *Strict Separation*: The app does **NOT** require `RECORD_AUDIO` or `CAMERA` for the core coding and terminal approval workflow.

---

## 4. UI Convergence Rule: Desktop Takes Precedence

When discrepancies arise between desktop and mobile designs:
1. **Desktop Proportions Are Authoritative**: The 704px reading column, 24px composer radius, 36px nav row, and 12px inset workspace card are derived from the official desktop Electron experience and must not be distorted by mobile material compromises.
2. **Detail Modes Are Pure Projections**: The 3-way detail mode selector (`Prose` / `Commands` / `Execution`) operates identically on mobile and desktop, filtering the typed timeline projection without requiring mobile-specific backend forks.
3. **Approvals Remain Inline**: Approval requests must remain visible inline within the conversation timeline as historical context, rather than disappearing into transient modal sheets.
