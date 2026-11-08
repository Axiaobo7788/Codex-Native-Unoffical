# Chat Authentication Boundary & Credential Isolation

> **Audited Package**: ChatGPT / Codex Desktop Linux Packaging (`26.1103.32239`)  
> **Target Subsystems**: Host Security Boundary, Remote Transport (`lib/src/transport/remote/`)  
> **Evidence Grading Standards**: `PUBLIC_DOC`, `PUBLIC_SOURCE`, `LOCAL_SCHEMA`, `STATIC_APK`, `STATIC_BUNDLE`

---

## 1. Executive Summary & Core Security Invariant

A central architectural mandate of `Codex-Native-Unoffical` is the **Host Credential Isolation Invariant**:

> **OpenAI credentials (API keys, session cookies, OAuth refresh tokens) and local filesystem access permissions reside exclusively on the host workstation running `codex app-server` or `codex-native-host`. They must NEVER be transmitted to, stored on, or accessible by remote clients (e.g. Android devices or secondary web viewers).**

Remote clients authenticate to the host via ephemeral, scoped pairing tokens. The host acts as an authorized gateway and security boundary, executing all network calls to OpenAI and managing all local bash execution.

---

## 2. Security Boundary Architecture

```
+-------------------------------------------------------------------------------+
|                             LOCAL HOST WORKSTATION                            |
|                                                                               |
|  +---------------------------+             +-------------------------------+  |
|  |   Secure Credential Store |             |       Local Filesystem        |  |
|  | - OpenAI API Keys         |             | - Workspaces, Git repos       |  |
|  | - OAuth Refresh Tokens    |             | - Terminal execution (bash)   |  |
|  +---------------------------+             +-------------------------------+  |
|                 |                                          |                  |
|                 v                                          v                  |
|  +-------------------------------------------------------------------------+  |
|  |                codex app-server / codex-native-host                     |  |
|  |                      (Core Security Boundary)                           |  |
|  +-------------------------------------------------------------------------+  |
|                 ^                                                             |
|                 | Authenticated WebSocket (TLS / Ephemeral Session Token)     |
+-----------------|-------------------------------------------------------------+
                  |
                  | (No OpenAI Credentials Cross This Boundary!)
                  v
+-------------------------------------------------------------------------------+
|                            REMOTE CLIENT (ANDROID / WEB)                      |
|                                                                               |
|  - Holds only ephemeral Session ID & signed pairing bearer token             |
|  - Receives projected UI state and streaming deltas                          |
|  - Sends user prompts, tool decisions (approve/reject), and UI events        |
+-------------------------------------------------------------------------------+
```

---

## 3. Host-Side Credential Lifecycle

### 3.1 Local Desktop Storage & Refresh
On desktop, `codex app-server` manages user authentication state using encrypted local configuration stores or OS keychains (`~/.codex/config.json`, libsecret/KWallet/Keychain).

When tokens approach expiration, the server requests a fresh access token from the host environment via the `account/chatgptAuthTokens/refresh` server-initiated request:

```json
{
  "jsonrpc": "2.0",
  "id": "srv-tok-991",
  "method": "account/chatgptAuthTokens/refresh",
  "params": {}
}
```

The host client resolves this request by reading or renewing OAuth tokens and responding with `{ accessToken: "...", expiresAt: 1731065000 }`.

---

## 4. Remote Device Pairing Protocols

### 4.1 Stock Remote Control Protocol (`remoteControl/*`)
The official Codex CLI and Electron app implement experimental pairing RPCs:

1. **Pairing Initiation**:
   Host calls `remoteControl/pairing/start`:
   ```json
   {
     "jsonrpc": "2.0",
     "id": "p-1",
     "method": "remoteControl/pairing/start",
     "params": {}
   }
   ```
   Response returns a time-limited 6-digit alphanumeric code and QR code payload:
   ```json
   {
     "jsonrpc": "2.0",
     "id": "p-1",
     "result": {
       "pairingCode": "K8F-29P",
       "environmentId": "env-00912",
       "expiresAt": "2026-11-08T05:30:00Z"
     }
   }
   ```
2. **Mobile Handshake**:
   The user scans the QR code or enters the pairing code in the mobile client. The mobile client submits the code to complete pairing without receiving raw API credentials.

### 4.2 Direct Host Remote Protocol (`codex-native-host`)

Our native Rust host provides a direct, high-performance pairing protocol optimized for local network or Tailscale connectivity:

1. **Host Setup**:
   `codex-native-host` generates an asymmetric ED25519 keypair and displays a pairing QR code containing the host's LAN/VPN IP and public key.
2. **Mutual Handshake**:
   The Android client connects via secure WebSocket (`wss://`), signs a challenge with its device key, and establishes an encrypted channel.
3. **Session Token**:
   The host issues an ephemeral scoped `SessionToken`. This token permits:
   - Reading thread history
   - Submitting prompts
   - Approving/rejecting pending tool execution requests
   It does **NOT** grant access to export raw API keys or execute unrestricted arbitrary shell commands outside the project sandbox.

---

## 5. Security Invariants Checklist

- [x] Android APK / Dart code never bundles hardcoded OpenAI API keys.
- [x] Remote transport messages contain no `Authorization: Bearer sk-...` headers.
- [x] Host-side token refresh is performed entirely within `codex app-server`.
- [x] Remote clients cannot inspect or extract the host's `~/.codex/` configuration files.
- [x] Lost or stolen mobile devices can be instantly invalidated by revoking their pairing token on the host workstation.
