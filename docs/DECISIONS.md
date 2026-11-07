# Architecture Decision Log

This file records durable project decisions and the reasoning behind them. Do not silently reverse an accepted decision. If a decision changes, append a new entry that supersedes the old one.

## ADR-001 — Use Flutter for the client UI

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

Use Flutter/Dart for desktop and Android presentation layers.

### Why

- Android is a first-class target, not an afterthought.
- The product is dominated by conversation, task, diff, approval, and streaming UI rather than deep native C++ integration.
- A shared component/domain layer is valuable across desktop, phone, and tablet.
- Long lists can be virtualized and kept within a bounded UI working set.

### Consequence

Linux/Wayland performance must be tested early, especially on NVIDIA systems.

---

## ADR-002 — Reuse stock Codex app-server

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

The client must use the stock `codex app-server` as the Codex harness/runtime rather than reimplementing the agent.

### Why

The project aims to replace presentation and remote-control layers, not Codex intelligence. Reusing app-server preserves Codex prompts, tools, compaction behavior, approvals, skills, MCP, plugins, and upstream improvements.

### Consequence

The app-server protocol is the primary integration boundary.

---

## ADR-003 — Keep the local Codex runtime out of process in v1

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

Desktop v1 starts `codex app-server --listen stdio://` as an independent child process and communicates via newline-delimited JSON.

### Why

- Process isolation makes crashes and memory growth independently recoverable.
- Users can upgrade Codex independently of the client.
- It stays on the supported app-server boundary.
- JSON/pipe overhead is negligible compared with model/tool latency.

### Consequence

`flutter_rust_bridge` is not required in v1. An embedded transport may be revisited later only if profiling shows meaningful benefit.

---

## ADR-004 — Android is a remote control plane

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

Android should connect to a host running Codex rather than run the full Codex runtime locally by default.

### Why

This avoids Android filesystem, sandbox, PTY, toolchain, and background-process limitations while keeping the development environment on the real host.

### Consequence

OpenAI/Codex credentials remain on the host. The remote protocol must support pairing, authentication, reconnect/resume, and large-payload streaming.

---

## ADR-005 — Bounded UI memory is a product requirement

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

The Flutter UI must never treat full Codex thread history as resident application state.

### Rules

- Paginate turns/items.
- Virtualize long lists.
- Keep only an active working set in memory.
- Show summaries for large tool output and load full content on demand.
- Load diff content per file/hunk as needed.
- Inactive threads should approach zero presentation-layer memory cost.

### Why

A core project goal is to avoid the double pressure of a large Codex runtime plus a heavyweight UI retaining the same long-running session history.

---

## ADR-006 — Preserve Codex fidelity by default

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

Default behavior must not secretly rewrite system prompts, replace tool schemas, or perform client-side context compaction.

### Why

The project should behave like Codex with a different presentation layer, not like a separate agent harness that merely uses the same model.

---

## ADR-007 — License under Apache-2.0

**Status:** Accepted  
**Date:** 2026-11-05

### Decision

Use Apache License 2.0 for the project.

### Why

It matches the upstream Codex project's permissive style, is friendly to community ports and packaging, and includes explicit patent terms without adding copyleft restrictions.

---

## ADR-008 — Put a bounded native Host between Flutter and app-server

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Desktop production transport runs a lightweight Rust `codex-native-host`. The
Host supervises the stock `codex app-server`, incrementally validates its JSONL
stdout, removes large command-output strings before Flutter receives a message,
and exposes bounded output reads through opaque references.

The Host is a transport and lifecycle boundary. It does not replace Codex
prompts, tools, compaction, protocol semantics, or the agent loop. Remote clients
will later connect to this same boundary rather than introduce a second harness.

### Why

- Dart's normal JSON decoder must materialize a complete JSON string before a
  typed adapter can discard `aggregatedOutput`.
- Current app-server item reads can still return an entire command output in one
  response; upstream output deferral makes list responses safer but does not
  provide byte ranges.
- An incremental native boundary can keep both the Host and Flutter projection
  bounded, spool selected output with explicit caps, isolate process failure, and
  become the natural owner of authenticated Remote transport.

### Consequence

- Desktop release bundles must build and ship `codex-native-host` beside the
  Flutter executable.
- Flutter receives sanitized JSON plus output descriptors and must request only
  bounded ranges/tails.
- Spool files are session-scoped, owner-only, capped, and addressed only by
  opaque IDs. Paths never cross the protocol boundary.
- The Host cannot eliminate app-server's own serialization allocation because
  the reviewed upstream stdio writer creates a complete serialized `String`
  before writing. App-server, Host, and Flutter memory must be measured and
  reported separately.

---

## ADR-009 — Distribute the macOS developer client outside the Mac App Store

**Status:** Accepted

**Date:** 2026-11-05

### Decision

The macOS build is an unsandboxed, Developer ID-signed and notarized direct
distribution. It is not a Mac App Store target. The bundled native Host is copied
into `Contents/MacOS` and signed as nested code during the Xcode build.

### Why

Codex is a developer tool that must run the user's separately installed runtime,
read and write explicitly selected workspaces, and launch normal toolchains and
commands. Apple's App Sandbox is mandatory for Mac App Store distribution, and
child processes inherit the parent's static sandbox. Security-scoped access
granted after launch is not automatically inherited by a child. Constraining
stock Codex to that sandbox would break the product's core local-runtime model,
while broad sandbox exceptions would not recreate normal developer-shell access.

### Consequence

- Mac App Store submission is out of scope for v1.
- Release engineering must sign all nested code, enable the hardened runtime,
  notarize the completed app, and validate on a real macOS machine.
- Removing App Sandbox does not weaken the client's own approval, sandbox-policy,
  opaque-path, or bounded-transport rules. Those remain application requirements.

---

## ADR-010 — Use a Host-owned authenticated resumable Remote envelope

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Android Remote connects to an explicitly enabled listener owned by
`codex-native-host`, not directly to stock app-server. The Host carries sanitized
app-server JSON-RPC inside a minimal versioned envelope with device
authentication, capabilities, a process-scoped session ID, sequenced events,
ACK/resume, bounded replay, and explicit resynchronization.

Pairing uses a short-lived single-use local ticket and returns one random 256-bit
device bearer token. Only its SHA-256 digest and bounded device metadata are
persisted. Non-loopback exposure requires TLS. Ordinary Codex methods remain
Codex methods; project-owned extensions stay under `host/*`.

Replay storage is bounded by both event count and serialized bytes, while
message and per-connection queue limits protect live delivery. Writes require
same-session idempotency keys and are never silently replayed after a Host
restart. Large blobs use separately authenticated chunked transfer rather than
WebSocket base64 payloads.

### Why

- The Host already owns output removal, opaque range reads, child lifecycle, and
  bounded transport; direct app-server access would bypass those invariants.
- A network connection can survive while state hydration, writer ownership, or
  large-payload delivery is broken. Session/sequence/resync semantics make those
  states explicit instead of treating `connected` as authoritative readiness.
- Reusing protocol-native app-server methods avoids a second feature schema that
  would drift from Codex, while the narrow envelope supplies the security and
  recovery properties app-server delegates to its remote peer.

### Consequence

- Remote networking is opt-in and loopback-only by default. Configuration must
  reject plaintext non-loopback listeners.
- Protocol, auth, journal, correlation, and idempotency semantics are tested as a
  pure Host state machine before a WebSocket implementation is selected.
- Android keeps only a bounded projection and uses existing paginated adapters
  after resync; it must not hydrate complete thread history automatically.
- Pending approvals/elicitation remain distinct fail-closed Host state rather
  than relying only on the volatile event journal.
- Device secret storage, TLS, installed-network behavior, and reconnect recovery
  require real platform/device validation and cannot be claimed from Linux unit
  tests alone.

---

## ADR-011 — Require explicit certificate identity for non-loopback Remote

**Status:** Accepted

**Date:** 2026-11-05

### Decision

`codex-native-host` permits plaintext Remote only on a literal loopback address.
Every non-loopback listener requires an explicitly configured PEM certificate
chain and matching private key and serves HTTPS/WSS through rustls. Missing,
partial, unreadable, overexposed, or invalid TLS configuration fails before the
listener binds and before stock Codex starts; there is no plaintext fallback.

Certificate rotation is an explicit trusted-local operation under
`host/remote/tls/reload`. A complete valid replacement is swapped atomically for
new handshakes. A failed reload keeps the last valid configuration, exposes no
certificate/key contents, and does not terminate established connections.

Public or managed deployments should use a normal CA-valid certificate, either
directly or through a correctly configured TLS reverse proxy. A future local
self-signed pairing flow must deliver and persist the expected certificate/CA
identity through the trusted pairing surface. Android must never implement
trust by accepting an arbitrary bad certificate.

### Why

- A bearer token sent over non-loopback plaintext is reusable by an observer and
  does not authenticate the Host to the phone.
- Silent downgrade after a certificate error would turn a configuration or
  rotation mistake into credential exposure.
- Android's platform trust store is appropriate for ordinary CA certificates;
  a local self-signed identity needs an explicit pairing-bound trust bootstrap,
  not a global bypass callback.
- Atomic reload permits planned certificate rotation without invalidating active
  work, while retaining the previous valid configuration avoids an outage from
  a partial or malformed file replacement.

### Consequence

- Linux/macOS private-key files must not grant group/other access. Windows key
  ACL behavior and installed-service operation require a separate platform gate.
- The current bearer token remains the device authorization credential; mTLS is
  not required for this slice and may be reconsidered only with measured need.
- The current Host can serve operator-provided TLS, but self-signed Android
  onboarding is not complete until pairing securely binds certificate identity
  and platform-backed secret storage is implemented and device-tested.

---

## ADR-012 — Treat Android Remote credentials as recoverable device-bound state

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Persist one versioned Remote device record through platform secure storage. The
record contains the exact WSS endpoint, 256-bit bearer, bounded device identity,
and an explicit trust kind. The first supported trust kind is ordinary Android
system-CA trust; plaintext endpoints and arbitrary-certificate acceptance cannot
be persisted.

Android uses a dedicated secure-storage namespace with automatic reset disabled
for normal reads and writes. Reads distinguish an absent record from an
unreadable or structurally invalid record. Unreadable data is never silently
removed or overwritten: retry and an explicit clear/re-pair action are separate
recovery choices. Only that explicit clear uses the plugin's namespace reset so
it can recover when the old wrapping key is already unusable. Writes are
serialized, reject an invalid existing record, and are read back before success.
The bearer and record details are redacted from object strings and storage
exceptions.

Disable application backup and independently exclude SharedPreferences from
both legacy cloud backup and Android 12+ cloud/device transfer. The ciphertext
must not be restored to a device whose non-exportable Keystore wrapping key was
not restored with it.

### Why

- Host bearers are revocable and re-pairable, but a transient Keystore failure
  must not be misreported as “never paired” or trigger an invisible destructive
  reset.
- Background reconnect cannot require a biometric prompt for every key use.
- Android Keystore key material is device-bound, while SharedPreferences are
  included in backup by default; restoring only encrypted preferences creates
  predictably unreadable state.
- Keeping the complete connection profile in one bounded secure value gives the
  application one verified update boundary and keeps bearer data out of normal
  preferences, routes, logs, and crash text.

### Consequence

- `flutter_secure_storage` 11.2.0 is the current platform adapter, configured
  with `resetOnError: false`, algorithm migration, migration backup, and an
  isolated namespace. Its open Android transient-Keystore replacement issue is
  an availability risk: the application can surface recovery but cannot repair
  a wrapping key already replaced inside the plugin. Physical-device fault and
  backup/restore testing remains a release gate.
- Pairing-bound local certificate/CA identity must use a new explicit record
  version rather than overloading `system` trust. ADR-014 implements that
  requirement as record version 2 while preserving version-1 reads.
- Cursor durability and reconnect ownership remain outside the credential
  record so a received-but-not-applied event can never advance durable state.

---

## ADR-013 — Require an explicit advertised endpoint for desktop pairing

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Treat the Remote listener bind address and the client-facing pairing endpoint as
two different operator-owned values. `codex-native-host` accepts an optional
`CODEX_NATIVE_REMOTE_ADVERTISE_ENDPOINT`/`--remote-advertise-endpoint` only when
a listener is enabled. It must be an exact absolute `wss://.../v1/ws` URI with
no user info, query, fragment, zero port, or unspecified `0.0.0.0`/`[::]` host.
The Host reports that value through trusted-local status and returns the same
value with a newly created pairing ticket. It never derives an invitation from
the bound socket address.

The Flutter desktop exposes Remote administration through a dedicated local
gateway over `ProcessTransport`, not through `CodexTransport` and not through
the Android `RemoteTransport`. Opening the setup surface reads listener/TLS/
scope/endpoint and bounded public device metadata, but creates no ticket. A
ticket is created only after an explicit action, retained only by that dialog,
and accepted only when its endpoint exactly matches the current status and its
expiry is still in the future. Listener configuration remains restart-owned;
the UI neither enables networking nor edits Host configuration.

Revocation remains explicit and requires confirmation plus authoritative list
readback. The registry limits active credentials to 32. Revoked or expired
records stay visible immediately, then are pruned atomically with the next
successful pairing publication so revocation can release capacity without
making the durable store unbounded.

### Why

- A wildcard bind describes where a server accepts traffic, not a hostname or
  address another device can reach. Guessing one can produce an unusable or
  security-incorrect invitation.
- Bind and public endpoint legitimately differ behind a TLS reverse proxy, NAT,
  split DNS, or an installed service. Requiring equality would reject supported
  deployments while derivation would hide operator intent.
- Pairing tickets are bearer-like, short-lived secrets. Automatic generation on
  screen open, persistence in application state, or diagnostic logging would
  increase exposure without improving setup.
- Local administration can revoke network clients and mint credentials, so it
  must not be added to the transport abstraction used by those same clients.

### Consequence

- A listener without an advertised endpoint remains usable for operator-level
  testing but the desktop cannot create a shareable invitation from it.
- Operators must configure a fixed reachable WSS endpoint and restart the Host;
  reachability, DNS, firewall, proxy, and certificate correctness still require
  real-network validation.
- The initial desktop surface presented endpoint and manual ticket text only.
  ADR-014 supersedes this consequence with a versioned manual invitation and
  record migration; QR rendering remains a separate presentation decision.

---

## ADR-014 — Bind Remote trust before the pairing request

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Replace the separate endpoint/ticket Android input with one bounded versioned
pairing invitation created by the trusted local Host surface. Version 1 is an
opaque `codex-native-pairing-v1.<base64url-json>` envelope that binds the exact
WSS endpoint, single-use code, expiry, and one explicit trust mode before any
network request. Trust is either the Dart/Android runtime system roots or one
bounded DER certificate plus its SHA-256 consistency fingerprint.

A private/self-signed deployment must configure exactly one public trust
certificate through `CODEX_NATIVE_REMOTE_PAIRING_TRUST_CERT`/
`--remote-pairing-trust-cert`. It requires both a listener and explicit
advertised endpoint, is parsed and validated before stock Codex starts, and is
snapshotted until Host restart. It is intentionally separate from the Host TLS
certificate chain because a reverse proxy may own the client-visible identity.
The Host never guesses a leaf or CA from a chain.

Android record version 2 persists the same trust object with endpoint, bearer,
and device metadata. Version-1 system-trust records remain readable; verified
saves write version 2 under the existing secure-storage key. Certificate mode
constructs a per-connection empty `SecurityContext`, adds only the invitation
certificate, and uses that context for both HTTPS pairing and WSS. Canonical DER
is persisted; Dart receives PEM on non-iOS and DER on iOS according to the
documented platform container behavior. No global store is modified and no
arbitrary-certificate callback exists.

### Why

- Learning a fingerprint from the pairing response is too late because an
  impersonator would already have received the one-use ticket.
- An explicit trust artifact supports direct self-signed Host TLS, a stable
  private CA, and TLS termination at a reverse proxy without conflating bind and
  client identity.
- The certificate is the actual scoped trust anchor. Its fingerprint detects
  representation drift but is not presented as independent authentication;
  trusted local transfer of the complete invitation is the bootstrap.
- Stable CA trust allows leaf rotation without device migration. Exact leaf
  trust is narrower, but changing it must visibly require restart and re-pairing
  rather than silently accepting a new identity during TLS reload.

### Consequence

- Desktop initially provided manual selectable/copyable invitations only.
  ADR-018 now permits one bounded QR projection while preserving this version
  boundary, dependency licensing, and explicit capacity/fallback behavior.
- Invitation possession grants a short-lived pairing capability and chosen
  trust identity. It must be transferred through the trusted local surface and
  is never logged, persisted by desktop UI state, or copied automatically.
- Host startup rejects malformed, multiple, empty, or oversized trust
  certificates. A full PEM chain is not accepted as an ambiguous trust choice;
  operators supply exactly the intended leaf or CA certificate.
- Real Android TLS-provider, Keystore, backup/restore, LAN, lifecycle, and Human
  interaction validation remain release gates. Same-host Linux WSS evidence does
  not satisfy them.

---

## ADR-015 — Generate and package native dependency licenses from Cargo.lock

**Status:** Accepted

**Date:** 2026-11-05

### Decision

Use pinned `cargo-about` 0.9.3 with `--locked --workspace --fail`, an explicit
accepted-license policy, and a repository-owned plain-text template to generate
`licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt`. Evaluate normal, transitive,
build, and platform-specific dependencies across the supported Linux, Windows,
and macOS target union; exclude only development dependencies that do not ship.

Commit the generated notice for ordinary review and make CI regenerate it into a
temporary file and compare it byte-for-byte. Linux and Windows package it beside
`codex-native-host`; macOS packages it in `Contents/Resources`. A dependency
change whose license cannot be read, clarified, or satisfied must fail rather
than silently disappear from the notice.

### Why

- `Cargo.lock` is the authoritative resolved native graph, while a manually
  curated direct-dependency list omits transitive/platform crates and drifts.
- Complete license texts and source locations must travel with distributed
  native binaries, not exist only in registry caches or release notes.
- A committed artifact makes license changes reviewable; deterministic CI drift
  checking keeps it coupled to the lockfile.
- The real graph includes unchanged MPL-2.0 `option-ext`. Its executable-form
  obligations require telling recipients where to obtain source, which the
  generated entry does alongside the complete license text.

### Consequence

- Native dependency changes require running
  `./tool/generate_native_licenses.sh --write` with the pinned generator and
  reviewing both policy and output changes.
- Accepting a new license is an explicit policy review, not an automatic update.
  Ignore rules must not be used to hide a runtime crate.
- The shared desktop notice is conservative: it can list a platform-specific
  crate not present in one particular binary, but it must not omit a crate used
  by any supported desktop binary.
- Linux byte identity is locally verified and a later hosted Windows build
  verifies its bundle copy; corrected hosted macOS execution verifies its
  `Contents/Resources` copy. Installed Windows/macOS artifact inspection remains
  outstanding.

---

## ADR-016 — Verify the real Rust floor and packaged desktop artifacts in CI

**Status:** Accepted

**Date:** 2026-11-06

### Decision

Declare Rust 1.89 as the native Host's minimum supported version and exercise
that exact toolchain in CI. Treat a clean locked build, not a developer's newer
compiler or individual dependency metadata, as the authority for the floor.

Run the Android Gradle 9 build with explicit Temurin 17 rather than a hosted
runner's default JVM. Pin the official Java setup action to an immutable commit
and leave dependency caching disabled.

Use explicit hosted images for Ubuntu 22.04 x64, Windows Server 2022 x64, and
macOS 15 arm64. Pin top-level third-party actions to full commit SHAs, disable
unused action caching, do not persist checkout credentials, and keep CI
permissions read-only. In addition to source tests, build Linux, Android,
Windows, and macOS; for both non-Linux desktop jobs, execute the packaged Host's
`--help` and compare the packaged native-license notice with the committed
artifact.

### Why

- The prior 1.87 declaration was not true for `Cargo.lock`: official Rust 1.87
  rejects `uuid` 1.29.0, while a clean official Rust 1.89 build passes all tests.
- `latest` runner aliases drift, and the previously implicit macOS image was
  retired. Explicit supported images make architecture and lifecycle changes
  reviewable.
- Source review of CMake/Xcode rules cannot prove that a native build actually
  contains an executable Host and the required license material.
- Immutable action references and non-persisted credentials narrow the
  third-party workflow supply-chain boundary without giving PR validation write
  authority.

### Consequence

- A dependency update that raises the locked graph's real compiler floor must
  either be rejected or accompanied by an explicit MSRV decision and a clean
  exact-toolchain gate; it must not silently rely on the runner's newest Rust.
- Monthly GitHub Actions updates arrive as reviewable Dependabot changes rather
  than floating automatically at execution time.
- Ordinary CI produces unsigned debug artifacts only. Developer ID signing,
  notarization, Windows installation/ACL checks, release signing, and Human
  interaction remain independent release gates.
- Hosted results remain authoritative for native paths. The first inspected
  current-tree run passed Windows x64 and exposed exact-Rust Clippy plus macOS
  Bash 3.2 defects. The second verified both corrections and exposed JVM 11 at
  Android assembly. The third (`42068745322`) passed the entire exact-toolchain,
  Linux, Android debug, Windows x64, and macOS arm64 matrix with explicit
  Temurin 17.

---

## ADR-017 — Android release builds require an external upload identity

**Status:** Accepted

**Date:** 2026-11-06

### Decision

Never sign an Android release variant with the SDK-generated debug key and never
silently treat an unsigned artifact as a release candidate. Debug variants keep
the standard debug identity. A release variant requires an external keystore and
all four Git-ignored `key.properties` values (`storeFile`, `storePassword`,
`keyAlias`, and `keyPassword`); missing, incomplete, or unreadable material fails
at `preReleaseBuild` without exposing values.

Prefer a signed Android App Bundle for future Play distribution. Keep creation,
custody, backup, rotation, Play App Signing enrollment, and CI injection of the
real upload key outside the repository and behind a separate explicit release
authorization.

### Why

- Android's debug certificate is insecure by design and is not a stable product
  identity. Shipping it would prevent the repository from making an honest RC
  or update-continuity claim.
- A signing key becomes part of the application's long-term update identity;
  generating one opportunistically in source or CI would be an external product
  decision with irreversible custody consequences.
- Contributors and untrusted PR validation do not need access to release
  credentials. Keeping CI on debug APKs preserves useful compilation evidence
  without widening secret exposure.

### Consequence

- `flutter run --release`, `flutter build apk --release`, and
  `flutter build appbundle --release` intentionally fail until the operator
  supplies the private local contract.
- Earlier minified APK builds that used Flutter's template debug-signing fallback
  remain compilation evidence only and are not valid release-signing evidence.
- Release automation may add a secret-backed signing step later only after the
  exact repository/application, key custody, Play policy, workflow permissions,
  and publication boundary receive explicit Human approval.

---

## ADR-018 — Render pairing QR as a bounded projection of the exact invitation

**Status:** Accepted

**Date:** 2026-11-06

### Decision

The desktop may render the existing canonical
`codex-native-pairing-v1.<base64url-json>` invitation as exactly one standard QR
symbol. It first revalidates the invitation through the authoritative protocol
decoder, encodes its exact ASCII bytes at medium error correction, uses QR
versions 1 through 40, preserves a four-module white quiet zone, and paints
integer three-logical-pixel modules without antialiasing.

QR is an optional presentation, not another pairing protocol. If the complete
invitation cannot fit one symbol or cannot be shown at the required module size,
the UI explains that limitation and retains the full selectable/copyable manual
fallback. It must not split, compress, truncate, omit fields from, or rewrite an
invitation merely to fit. QR state exists only with the transient ticket card;
the controller removes both at expiry and never persists the image or payload.

Use the pure-Dart `qr` 4.0.1 package under its BSD 3-Clause license for offline
matrix generation. Keep its provenance in `THIRD_PARTY_NOTICES.md` and Flutter's
generated application notices.

### Why

- The protocol permits invitations much larger than any standard QR symbol so
  that bounded certificates can be represented. Treating every protocol-valid
  value as QR-encodable would either fail at runtime or pressure the security
  envelope into a second, less-auditable schema.
- Medium correction is a deliberate compromise for a secret normally scanned
  from a desktop display. A four-module quiet zone and integer, non-antialiased
  modules preserve the symbol geometry rather than shrinking it to fit a narrow
  layout.
- The existing manual path is complete, explicit, and protocol-identical. It is
  the safe fallback for unusual certificate sizes, constrained windows, camera
  permission denial, inaccessible cameras, or future scanner incompatibility.
- Removing expired material from the visible tree narrows accidental exposure
  and ensures a QR never outlives the one-use capability it represents.

### Consequence

- System-root invitations and realistically bounded certificate invitations
  can be scanned once Android camera intake exists; larger yet protocol-valid
  certificates remain manual-only by design.
- Scanner selection, camera permission UX, lifecycle behavior, decoding bounds,
  and real Android/device scanning remain a separate researched implementation
  and release gate. Desktop generation tests do not prove camera interoperability
  or Human visual acceptance.
- Future invitation versions may reuse this projection only after their exact
  payload and capacity behavior are reviewed. This ADR does not authorize a
  QR-only wire format or automatic clipboard access.

---

## ADR-019 — Keep Android pairing scans explicit, bounded, and offline-ready

**Status:** Accepted

**Date:** 2026-11-06

### Decision

Android exposes a Scan QR action only from the unpaired onboarding surface. It
opens a foreground camera route, decodes QR symbols only, rejects missing,
oversized, noncanonical, malformed, or expired content through the existing
`codex-native-pairing-v1` adapter, and returns the first valid invitation to the
obscured form field. A scan never starts the pairing exchange automatically;
the user still reviews the device name and selects Pair and connect. Manual
paste remains available before, during, and after permission or camera failure.

Use `mobile_scanner` 7.5.0 with its bundled Android ML Kit model rather than the
first-use Play Services download. Configure a 1280x720 request, QR-only format,
duplicate suppression, no returned image, and no auto-zoom. The camera starts
only after the user's Scan QR action, releases across background lifecycle
states, and is disposed when the route closes. Declare camera, back-camera, and
autofocus features as optional so devices without those capabilities retain the
complete manual pairing path.

### Why

- The invitation already defines strict size, endpoint, ticket, expiry, and TLS
  trust semantics. A scanner is an untrusted intake surface and must not create
  a second parser, accept a QR-only schema, or bypass the explicit pairing act.
- A bundled model is immediately usable on trusted local networks and on
  Android builds without a first-use model download. Restricting recognition to
  QR and omitting frame return keeps the Dart boundary to small decoded text.
- `mobile_scanner` has substantially broader adoption and lifecycle repair
  history than the newly reviewed lightweight alternatives. The maintained
  `qr_code_scanner_plus` alternative explicitly describes its Android native
  ZXing integration as outdated and unmaintained. The ML-free
  `lightweight_barcode_scanner` 0.4.1 has a promising bounded native design but
  was only 27 days old, with one pub.dev like and 194 downloads at review time;
  adopting it before real-device evidence would exchange a measured size and
  privacy cost for a much younger lifecycle surface.

### Consequence

- The Android runtime resolves bundled `com.google.mlkit:barcode-scanning`
  17.3.0, AndroidX Camera 1.6.1, and their graph. The model works offline, but
  ML Kit is governed by Google's terms and may send performance/utilization
  metrics or contact Google for runtime maintenance. Camera frames, decoded
  text, and results remain on-device according to Google's documentation. This
  distinction must appear in dependency notices and future store/privacy
  disclosures; the app must not claim the library is network-silent.
- Auto-zoom remains disabled, avoiding its additional session/zoom/bounding-box
  metrics. Any future enablement requires a separate UX, privacy, and device
  review.
- The measured universal debug APK grew from 191,469,644 to 214,274,417 bytes
  in this environment. That is not per-device release size evidence and remains
  a reason to re-evaluate the decoder after physical-device gates.
- The package also declares a macOS plugin, so Flutter registers its native
  code in macOS builds even though the product exposes no desktop scan action.
  Hosted macOS compilation and later release-size review must preserve that
  boundary.
- Unit/widget tests and Android compilation cannot establish camera focus,
  permission-settings recovery, rotation, dense Version 40 recognition, or
  cross-device interoperability. Both system-root and pairing-bound invitations
  remain physical-device and Human release gates.

---

## ADR-020 — Separate desktop review artifacts from production release authority

**Status:** Accepted

**Date:** 2026-11-06

### Decision

Build Linux x64, Windows x64, and macOS arm64 release-mode desktop bundles in a
manual, read-only GitHub Actions workflow, but label every result
`review-only` with `distributionReady=false`. Package the complete Flutter
bundle rather than a standalone executable. Before archiving, require the
platform's release AOT/runtime files, the bundled native Host, exact application
and native-license notices, absence of a debug kernel blob, and a successful
native Host `--help` smoke. On a matching hosted operating system, independently
extract the completed archive and run the extracted Host smoke again. The Linux
gate must additionally prove ELF64 x86-64 runner/Host identity, the runner's
`$ORIGIN/lib` lookup, no unresolved runner/Host dependencies with build-time
loader overrides removed, and relocatable runtime paths for the bundled
libraries reachable from the runner. After upload, download the Linux artifact
into a pinned clean Ubuntu 22.04 container containing runtime rather than build
dependencies, recheck its checksum and dependency closure, run the extracted
Host, and require the GUI to remain alive for a bounded Xvfb smoke window.

Wrap each bundle in a tar archive before uploading it so Unix executable modes,
case, and macOS framework symlinks survive GitHub artifact transport. Include a
sorted per-file SHA-256 manifest, canonical `SHA256SUMS`, source revision and
tree state, application version/build number, exact Flutter/Rust versions,
target/build mode, and an explicit platform signing boundary. Publish an outer
archive SHA-256 plus provenance sidecar and verify the archive by listing,
extracting, reinventorying, and rechecking its layout before upload.

Do not create a tag or GitHub Release, request `contents: write`, enable OIDC or
artifact-attestation permissions, provision signing identities, or call these
archives release candidates. Android remains excluded because ADR-017 requires
a real external upload identity for release variants.

### Why

- Flutter desktop deployment requires the complete generated bundle. Shipping
  only the runner executable omits engine, AOT, plugin, ICU, asset, Host, and
  license files.
- GitHub's artifact transport does not preserve file permissions when it zips a
  directory. Archiving first preserves executable bits and the macOS bundle's
  symlink topology while still allowing ordinary workflow-artifact retention.
- The repository does not yet possess or authorize the durable identities and
  platform gates needed for a production distribution: Developer ID plus
  notarization on macOS, an Authenticode/installer choice on Windows, a Linux
  distribution/signature policy, or the Android upload key.
- GitHub attestations require new `id-token` and `attestations` write
  permissions, and Releases require content write authority. A checksum and
  self-consistency manifest are useful preparation without silently expanding
  repository permissions or implying signed provenance.

### Consequence

- A manual workflow artifact can prove that one clean commit produced a
  complete release-mode bundle with internally consistent bytes and layout. It
  cannot prove publisher identity, tamper resistance outside the workflow,
  platform installation, Gatekeeper/SmartScreen behavior, ACLs, dependency
  compatibility on other distributions, or Human acceptance.
- Linux plugins are copied into `bundle/lib` as files rather than installed as
  CMake targets, so they are linked with their final `$ORIGIN` install RPATH
  from the start. The native archive verifier rejects a build-tree plugin path
  even when the main runner would happen to preload the same engine library and
  mask that defect during an ordinary launch.
- The assembler refuses existing outputs, unsafe paths and escaping symlinks,
  mismatched Git revision/tree state, missing or empty layout files, notice
  drift, debug kernel blobs, Host smoke failure, and archive/manifest/checksum
  mismatch. Partial outputs are removed on failure.
- A future production workflow should consume these validated bundle contracts
  only after each platform's signing/installer decisions and the exact GitHub
  permission increase receive explicit review. It must not relabel historical
  review-only artifacts as releases.

---

## ADR-021 — Protect Host-owned Windows state with a current-user DACL

**Status:** Accepted

**Date:** 2026-11-06

### Decision

On Windows, give every Host-owned output-spool and Remote device-store directory
a protected DACL with one full-access allow ACE for the current process user's
SID. Directory ACEs inherit to child objects. Supply that descriptor through
`SECURITY_ATTRIBUTES` when creating a directory or atomic device-store
replacement, then apply the same protected DACL to an existing directory/file
before the Host uses it. Recursively migrate the Host-owned spool root so an old
explicit permissive file ACE is removed as well; do not recursively rewrite
siblings of a custom device-store path. Reject reparse directories and files.
Open existing objects without following reparse points, verify their type and
file link count, and update the DACL by handle. Any failure to construct or
apply the DACL fails the affected Host startup or Remote storage operation
rather than falling back to ambient inheritance.

Use Win32 security APIs through `windows-sys`; do not shell out to the localized
`icacls` utility. Keep the Windows-only unsafe code in one module with owned
handle/`LocalFree` wrappers. Run its permissive-parent migration tests on the
native Windows CI job. Unix keeps its existing `0700` directory and `0600` file
rules.

### Why

- The default LocalAppData/config ACL is usually user-scoped, but explicit
  `--cache-dir` and `--remote-device-file` paths can inherit broader ACEs. Large
  command output and hash-only device credentials should not depend on an
  operator noticing that inheritance.
- A creation-time descriptor avoids a window in which a new secret-bearing
  object exists with its parent's broad DACL. Protecting existing objects also
  migrates state created by older Host versions.
- A current-user SID is precise across local, domain, CI, and renamed accounts;
  account names and localized command output are not stable security identities.
- A protected DACL prevents later parent inheritance from silently reintroducing
  unrelated principals. Rejecting reparse points prevents an override path from
  redirecting the hardening operation to another object; rejecting hard-linked
  files prevents one sensitive object from retaining an alternate path.

### Consequence

- Windows Host state becomes fail-closed and independent of cache/config parent
  ACLs. Local administrators can still take ownership by platform design; this
  is an inter-user disclosure boundary, not protection from an administrator.
- Tightening an existing custom state path may remove deliberately added service
  or group access. A future installed multi-user service needs a separate service
  identity and ACL decision rather than weakening this desktop default.
- This decision covers only files the Host creates and owns. The ACL, custody,
  and service-account readability of an operator-provided Windows TLS private key
  remain an installed-platform validation gate.

---

## ADR-022 — Validate external TLS material through one bounded checked handle

**Status:** Accepted

**Date:** 2026-11-06

### Decision

Treat the configured Remote TLS certificate chain and private key as
operator-owned, read-only inputs. Open each leaf without following a Unix
symbolic link or Windows reparse point, require a regular file, and read at most
1 MiB of certificate bytes and 256 KiB of key bytes. Validate the private key
through its already-open handle and pass those exact bytes to
`RustlsConfig::from_pem`/`reload_from_pem`; do not validate one path lookup and
then ask another layer to reopen it.

On Unix, require the key to be owned by the process's effective user with no
group/other permission bits. On Windows, require a protected, valid, non-null
DACL and an owner equal to the current process user, LocalSystem, or built-in
Administrators. Permit only standard allow ACEs for those same three principals
and standard deny ACEs; reject any other granting principal or unsupported ACE
shape. Never repair or replace the external file. A validation, bounded-read, or
parse failure fails Host startup/reload, and reload keeps the last valid rustls
configuration.

### Why

- A metadata check followed by a path-based parser leaves a substitution window
  and delegates allocation size to a dependency. One no-follow handle plus an
  extra-byte read cap binds validation and content while keeping memory bounded.
- A Windows owner is security-relevant because an owner can change its DACL.
  Exact SIDs avoid localized account names; the process user, SYSTEM, and
  Administrators cover desktop, elevated, and service-owned keys without
  admitting ordinary cross-user access.
- A currently safe but inheritable DACL can later acquire a parent ACE. Requiring
  `SE_DACL_PROTECTED` makes the checked principal set durable without the Host
  changing an operator-owned object.
- TLS reload is a security boundary: partial certificate/key rotation or an
  invalid replacement must not discard the working identity.

### Consequence

- Windows operators must prepare a protected key DACL before enabling Remote.
  The Host reports the failed condition but does not invoke `icacls` or silently
  change access. Local administrators remain trusted by platform design.
- Windows hard links are not rejected here: every name refers to the same file
  object and DACL, and this code never mutates the external key. Host-owned
  atomic state retains ADR-021's stricter alternate-link rule.
- Installed-service identity/provisioning, installer ACLs, parent-directory
  custody, macOS extended ACLs, signing, and Human installed-machine review
  remain separate release gates.

---

## ADR-023 — Reject every macOS extended ACL on an external TLS private key

**Status:** Accepted

**Date:** 2026-11-06

### Decision

After ADR-022's same-handle owner and mode checks, query the already-open macOS
private-key descriptor with `acl_get_fd_np(..., ACL_TYPE_EXTENDED)`. Accept only
the documented absent-property result, `ENOENT`. Reject every returned extended
ACL object, including a deny-only or explicitly empty object, and fail closed on
every other query error. Release a returned ACL with `acl_free`. Do not parse,
repair, or remove the operator's ACL.

Run the native Host Rust suite on the hosted macOS job so a real Apple libc and
native macOS filesystem fixture exercise both a plain owner-only key and a
`0600` key that also has an `everyone allow read` ACL.

### Why

- macOS extended ACLs can name users or groups independently from the three
  POSIX mode classes, so `0600` alone does not establish the intended principal
  boundary.
- The Apple API retrieves the ACL from the descriptor that will later be read,
  preserving ADR-022's no-second-path-lookup property.
- Interpreting UUID-qualified allow/deny order, inheritance flags, and future
  ACE forms would add a second platform policy engine. This operator input has
  no compatibility need for an ACL, so requiring explicit absence is the
  smaller fail-closed contract.

### Consequence

- A macOS operator must remove any extended ACL before Host startup or TLS
  reload; the Host reports the condition but does not invoke `chmod` or mutate
  the external key.
- A filesystem or runtime that cannot prove ACL absence is rejected even if its
  POSIX mode appears owner-only. Root and other platform administrators remain
  outside this local-user boundary.
- Parent-directory custody, installed service identities, installer behavior,
  signing/notarization, and Human installed-machine review remain separate
  release gates. This decision supersedes only ADR-022's macOS extended-ACL
  deferral.

---

## ADR-024 — Keep the nested macOS Host architecture-complete with the app

**Status:** Accepted

**Date:** 2026-11-06

### Decision

Treat Xcode's `ARCHS` as the source of truth for the architecture set of the
nested `codex-native-host`. Map `arm64` to `aarch64-apple-darwin` and `x86_64`
to `x86_64-apple-darwin`, invoke locked Cargo once per requested target, merge
multiple results with the system `lipo`, then sign the final embedded Host once.
Reject an unknown or empty architecture request. Do not install Rust targets or
fall back to the build machine architecture when Xcode made an explicit request.

Keep Debug builds on Xcode's active architecture. For the pinned Flutter 3.47.1
release path, provision both Rust targets and require the app runner, Host, App
framework, and Flutter engine to contain exactly arm64 and x86_64. Identify that
review artifact as `macos-universal`; do not label an arm64-only artifact as the
macOS release candidate.

### Why

- A universal outer app with a thin nested executable can launch on the build
  machine yet fail only when the other architecture attempts to start the Host.
- Xcode already decides the product architecture set. Mirroring `ARCHS` avoids a
  second hard-coded release mode while preserving fast active-architecture Debug
  builds.
- Building explicit Rust targets and merging their complete executables follows
  the supported custom-build-system pattern; post-merge signing avoids
  invalidating a signature by changing Mach-O bytes later.
- A native artifact check makes the target label an enforced property rather
  than provenance prose.

### Consequence

- macOS release builders must install both Rust Apple targets before invoking
  the universal build. Missing targets fail visibly; the build phase does not
  mutate a developer toolchain.
- CI uses an Apple Silicon runner but validates both slices. That proves build
  and package completeness, not runtime behavior on physical Intel hardware.
- Developer ID signing, entitlements, notarization, stapling, Gatekeeper,
  installed-workspace access, and Human review remain separate release gates.
- Flutter's announced Intel deprecation is not guessed around here. A later
  Flutter/toolchain upgrade must deliberately retain or revise this decision.

---

## ADR-025 — Deduplicate exact Host outputs inside one session

**Status:** Accepted

**Date:** 2026-11-06

### Decision

While incrementally decoding each `aggregatedOutput`, compute a streaming
SHA-256 over every logical decoded byte and pair it with the complete logical
byte length. Use that identity only inside the current Host process to reuse an
already readable spool object. Keep the public descriptor unchanged: an opaque
random UUID reference plus bounded size/truncation/availability metadata. Never
expose the digest, a filesystem path, or a client-selected object key.

Cap the session identity index at 16,384 objects independently of the byte
budget. Check for an existing identity first so a duplicate remains readable at
capacity; publish a new unique output as unavailable when the object cap is
reached and remove its temporary data/metadata with exact byte-account rollback.

A sanitized JSON candidate owns only the output objects it newly created. If
parsing, capture, or the sole observer fails before complete delivery, remove
those objects from the index, delete their data/metadata, and release their
exact session-budget bytes. Once any consumer has received the complete
descriptor-bearing candidate, the object is committed and cannot be rolled
back by a later secondary-delivery failure. A duplicate candidate never owns or
deletes the pre-existing shared object.

Do not add a public release RPC until the presentation model has explicit
descriptor ownership and can prove that no retained history row, dialog, or
Remote consumer can still read the reference.

### Why

- Re-reading one unchanged command item should not consume another share of the
  2 GiB session budget or leave another data/metadata pair.
- Hashing every logical byte, including bytes beyond the stored truncation cap,
  prevents different large outputs with the same stored prefix from aliasing.
- Opaque references preserve the Host boundary and leave hash algorithms and
  corruption policy as implementation details.
- Immediate client-driven release is unsafe while the same descriptor can be
  retained by more than one projection. A stale reference is worse than bounded
  session-lifetime storage.
- Candidate ownership closes a leak in which a valid output string could be
  published before later malformed JSON invalidated the containing message.

### Consequence

- The second exact read still streams and hashes the complete upstream string
  and may temporarily write a bounded `.part` file before its identity is known;
  CPU and transient I/O therefore remain linear in the source payload.
- Deduplication is process/session local. It is not a persistent content-addressed
  cache, does not trust client-provided digests, and does not claim same-size
  corruption detection for private session files.
- Unique outputs remain until Host shutdown and are still constrained by the
  per-output, per-session-byte, and 16,384-object caps. A future release protocol
  requires a separate ownership ADR.
- The Host still cannot prevent stock app-server from first materializing the
  complete string in its own serializer.

---

## ADR-026 — Switch to official Desktop UI fidelity after the core daily-use loop

**Status:** Accepted

**Date:** 2026-11-06

### Decision

First complete the core daily-use product loop: Android Remote session and
write behavior, approvals, bounded output and attachments, a headless Host, and
the Skills/MCP/Plugins paths required for real Codex work. As soon as that loop
is usable, make official Codex Desktop UI fidelity the project's highest
priority.

At the transition, systematically research the then-current official product
and reproduce its information architecture, layout, density, interactions,
component states, and visual language with native Flutter. Replace the current
engineering-oriented surfaces incrementally, while preserving bounded memory,
virtualized lists, lazy output/diff loading, typed protocol boundaries, and
native performance.

After the transition, do not continue open-ended non-blocking CI, release,
packaging, or infrastructure expansion. Such work may preempt UI fidelity only
when it is necessary for functional correctness, security, supported-platform
execution, realistic validation, or delivery.

### Why

- The bootstrap UI proves protocol and memory behavior but is not the intended
  product finish.
- Functional parity must come first so visual work is exercised against real
  sessions, approvals, output, attachments, and extension surfaces rather than
  mocks.
- A deliberate priority switch prevents release machinery from becoming an
  infinite substitute for the user-facing product.
- Re-research at the switch avoids freezing a moving official design into a
  stale local interpretation.

### Consequence

- UI fidelity is a product requirement, not a request to copy official prompts,
  agent logic, assets without license, or internal Rust crates.
- Visual similarity cannot weaken ADR-005's bounded-state rules or turn an
  inactive thread into resident presentation state.
- Human visual/interaction review and cross-platform layout evidence become
  explicit acceptance gates for the fidelity phase.
- Until the core loop closes, fidelity research may inform reusable foundations,
  but it must not displace the missing functional paths.

---

## ADR-027 — Make Desktop UI fidelity the immediate sole phase, then stop

**Status:** Accepted

**Date:** 2026-11-06

### Decision

Supersede only ADR-026's sequencing rule. Begin the Desktop UI fidelity phase
immediately, before Android Remote write/full-conversation work, a headless Host,
official relay migration, ChatGPT integration, Skills/MCP/Plugins expansion, or
additional non-blocking release/infrastructure work. Preserve those existing
implementations and open gates without advancing them during this phase.

Use current first-party Codex Desktop evidence as the primary design source. The
current product now lives in the unified ChatGPT Desktop application while
retaining a distinct Codex view and history, so combine the current shared
conversation/composer visual language with Codex-specific project, thread,
approval, diff, output, and repository information architecture. Earlier
standalone Codex screenshots are historical evidence, not a license to freeze a
stale shell. Do not copy OpenAI branding, logos, proprietary assets, or imply
official affiliation.

Replace the seed-derived Material 3 visual baseline with a small project-owned,
Codex-inspired light/dark token and component layer. Flutter Material widgets may
remain underneath for semantics, focus, input, and platform integration, but
`ColorScheme.fromSeed()` must not choose the final visual system. Do not build a
general theme framework for hypothetical Material You, KDE, or Breeze themes in
advance.

Decompose the presentation layer into coherent modules while leaving the typed
protocol, domain, controllers, runtime ownership, and transport boundaries
unchanged. Fidelity work must retain thread/history pagination, virtualized
lists, bounded active projections, lazy Markdown, lazy range-based output,
per-file bounded diff rendering, inactive-thread eviction, streaming
coalescing, and bounded image/file behavior.

When the defined Desktop UI acceptance gates are satisfied, stop autonomous
development and report the exact phase marker
`DESKTOP_UI_PHASE_COMPLETE — STOPPED FOR MOBILE RESEARCH`. A later mobile or
Remote architecture phase requires a new explicit instruction and fresh
research; it must not inherit current mobile assumptions by default.

### Why

- The existing interface proves runtime, protocol, and memory behavior but its
  centered runtime card, separated engineering panels, exposed working-directory
  field, and Material-default controls do not form a product-grade desktop
  workspace.
- Current product evidence changed after ADR-026: Codex moved into the unified
  desktop application while preserving its dedicated developer workflow. A
  research-first implementation prevents both a generic AI dashboard and a
  pixel copy of an obsolete standalone shell.
- The current controllers already exercise thread, conversation, approval,
  settings, diff, output, and Remote administration paths. Refactoring their
  presentation now produces fidelity against real behavior rather than mocks.
- An explicit stop condition prevents adjacent Remote, CI, packaging, and
  infrastructure work from displacing Human evaluation of the desktop product.

### Consequence

- Android Remote, official relay, ChatGPT history/backend, headless Host,
  ecosystem expansion, release engineering, signing, installer, and non-blocking
  security-edge work are paused, not deleted or declared complete.
- Light and dark modes, wide and narrow desktop layouts, focus/keyboard/scroll
  behavior, and major empty/loading/error/disconnected/active states become
  acceptance requirements.
- Existing controller and bounded-memory tests must continue to pass. UI tests
  must add token, density, responsive, hover/selection, and overflow evidence;
  realistic desktop/app-server smoke remains distinct from Human visual review.
- Material component types in the widget tree are acceptable implementation
  details. Seed-derived appearance, oversized Material surfaces, and default
  dashboard-style cards are not the product baseline.

---

## ADR-028 — Close the Desktop UI fidelity phase at the verified native boundary

**Status:** Accepted

**Date:** 2026-11-06

### Decision

Declare the authorized Desktop UI fidelity implementation complete after the
project-owned light/dark theme, modular presentation, full-window project/thread
workspace, responsive conversation/composer interactions, unified approval/
diff/output states, bounded-memory regression evidence, Linux native execution,
and real stock-app-server smoke gates pass. Emit
`DESKTOP_UI_PHASE_COMPLETE — STOPPED FOR MOBILE RESEARCH` and perform no further
autonomous implementation.

Completion is a precise machine-actionable boundary, not a claim of Human or
cross-platform visual acceptance. Preserve the unrun Linux/Windows/macOS Human,
high-DPR, dark-mode, accessibility, populated-state, platform-chrome, and hosted
CI gates in project status. Preserve the direct Unicode-path `flutter analyze`
failure separately from the passing real-path `dart analyze` and ASCII-symlink
`flutter analyze` evidence.

If the user later resumes the project for mobile/Remote work, start a distinct
research phase against then-current official ChatGPT/Codex Android/iOS clients,
official Remote relay/controller implementation, and current community work.
Do not assume that the paused Android transport, official-versus-Direct Host
split, or `codex-native-host` product role is still correct.

### Why

- The prior engineering shell has been replaced by the researched native
  product workspace while keeping every controller, protocol, pagination,
  virtualization, lazy-output, bounded-diff, coalescing, and lifecycle boundary.
- Local widget/build/memory evidence and real stock-app-server behavior now
  exercise the complete existing Desktop feature loop rather than only visual
  fixtures.
- Human review and hosted cross-platform execution establish different claims;
  explicitly listing them is more accurate than either blocking indefinitely
  on unavailable reviewers or silently calling them passed.
- The user's stop condition is part of product scope. Continuing into Remote,
  mobile, ecosystem, release, or infrastructure work would be unauthorized even
  if technically adjacent.

### Consequence

- Desktop UI code may be changed again only through a later explicit request;
  this ADR does not create a background polish queue.
- Known visual differences from current official Codex remain documented in
  `docs/RESEARCH.md` instead of being represented by inert placeholder controls.
- Paused Android/Remote, ChatGPT, Skills/MCP/Plugins, release, installer,
  signing, CI-hardening, and ACL/TLS edge work remains intact but inactive.
- The next recommended activity is research only after explicit authorization;
  no implementation or protocol migration begins from this decision.

---

## ADR-029 — Reopen Desktop UI fidelity after Human real-use review and adopt a bottom-anchored conversation viewport

**Status:** Accepted (supersedes ADR-028's `DESKTOP_UI_PHASE_COMPLETE` closure marker)

**Date:** 2026-11-07

### Decision

Reopen Desktop UI fidelity and productization because Human real-use review of
`7f220d5` demonstrated that machine-only widget tests had missed significant
navigation, scroll restoration, user-message presentation, and product-completeness
defects. Preserve `ADR-028` and the prior `PROJECT_STATUS.md` history intact,
recording that Human real-use evidence supersedes the earlier machine-only
completion claim.

Replace the top-anchored `ListView.builder` conversation timeline with a
bottom-anchored `CustomScrollView` (`anchor: 1.0`, a zero-height `center` sliver
at the bottom, and a reverse-growing `SliverList.builder` before `center`) backed
by a custom `_RenderConversationViewport` that top-aligns content when total
sliver extent is smaller than the viewport height. Opening or resuming an
existing thread lands immediately at `scrollOffset == 0.0` (`maxScrollExtent`) on
the first frame without measuring offscreen turns or animating from the top.
Prepending older turn pages extends negative scroll offsets without shifting the
user's visual reading anchor. Live streaming follows only when within `160 px`
of latest (`offset >= -160`); when scrolled up, streaming does not yank the
viewport and a compact `Jump to latest` control is shown. Retain at most `32`
per-thread scroll offsets in memory.

Normalize persisted and live `userMessage` items for presentation only: parse
`# Files pasted by the user:`, `# Files mentioned by the user:`,
`# Context from my IDE setup:`, and `## My request:` / `## My request for Codex:`
envelopes plus non-text `userMessage.content` items (`localImage`, `image`,
`skill`, `mention`) into structured `UserAttachment` chips and a clean user
request body, without modifying outbound prompts sent to `codex app-server`.
Align user bubble tokens with the official Codex Desktop neutral surface
(`#F0F0EC` light / `#2A2B29` dark), add `Show full message` / `Show less`
disclosure for long user messages, add fenced code block headers with `Copy`
actions, separate quiet reasoning rows, and remove raw protocol status text from
command activity rows.

Align the desktop workspace shell with current official Codex Desktop behavior:
set the native window title to `Codex Native` across Linux, Windows, and macOS;
add collapsible sidebar (`Ctrl+B` / `Cmd+B`), collapsible project groups with
quick new-thread creation, and inline thread search (`Ctrl+K` / `Cmd+K`); show
relative date labels (`HH:mm`, `Nd`, `MM/dd`) and omit false warning dots on
`ThreadRuntimeStatus.notLoaded` threads; and automatically resume a selected
`notLoaded` thread when the user submits a turn from the composer.

Stop after live Linux desktop verification and emit
`DESKTOP_PRODUCT_UX_REVIEW_COMPLETE — STOPPED FOR USER REVIEW`, explicitly
separating `MACHINE VERIFIED`, `HUMAN REVIEWED`, and `NOT YET HUMAN VERIFIED`.

### Why

- A top-anchored `ListView` starts at `offset == 0.0` (the oldest loaded turn).
  Checking `distanceFromEnd <= 160` therefore never triggered on initial load of
  a multi-turn thread, stranding the user at the top of history and causing
  upward pagination (`Load older turns`) to shift the visible viewport.
- A bottom-anchored reverse sliver list places the newest item at `0.0` from the
  very first layout pass while preserving lazy `SliverList.builder`
  virtualization and all Phase 3 bounded-memory invariants.
- Stock Codex and IDE integrations embed pasted-file and workspace context
  scaffolding inside the protocol `userMessage` text item. Parsing that envelope
  in the presentation projection matches official Codex Desktop's attachment
  chip UX while keeping `Codex owns intelligence; client owns presentation`.
- `ThreadRuntimeStatus.notLoaded` is the normal cold state of persisted threads
  in `thread/list`; treating it as a warning state created false visual noise
  across every historical thread in the sidebar.

### Consequence

- All bounded-memory, pagination, virtualization, 50 ms streaming coalescing,
  16 KiB Markdown cap, 64 KiB output window, bounded diff, and Host spool
  invariants remain intact.
- Selecting a thread in the sidebar remains read-only (`readThread`), while
  submitting a prompt in the composer transparently calls `resumeThread` if the
  selected thread is still `notLoaded`.
- Final product acceptance requires the user's own interactive review of the
  updated desktop build; automated tests and agent-captured live Linux window
  walks do not substitute for the user's sign-off.

