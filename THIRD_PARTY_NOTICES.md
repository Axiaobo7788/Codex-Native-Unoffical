# Third-party notices

Flutter release builds include the license texts collected from every bundled
Dart/Flutter package in the generated application notices. The direct packages
introduced for native Markdown presentation are also identified here so source
distributions keep their provenance visible.

## flutter_markdown_plus 1.0.12

- Source: <https://github.com/foresightmobile/flutter_markdown_plus>
- Copyright 2013 The Flutter Authors.
- License: BSD 3-Clause. The complete license is distributed with the package
  and in the generated Flutter application notices.

## markdown 7.3.1

- Source: <https://github.com/dart-lang/tools/tree/main/pkgs/markdown>
- Copyright 2012, the Dart project authors.
- License: BSD 3-Clause. The complete license is distributed with the package
  and in the generated Flutter application notices.

## url_launcher 6.3.3

- Source: <https://github.com/flutter/packages/tree/main/packages/url_launcher>
- Copyright 2013 The Flutter Authors.
- License: BSD 3-Clause. The complete license, including the endorsed platform
  implementations, is distributed in the generated Flutter application
  notices.

## crypto 3.0.8

- Source: <https://github.com/dart-lang/core/tree/main/pkgs/crypto>
- Copyright 2015, the Dart project authors.
- License: BSD 3-Clause. The complete license is distributed with the package
  and in the generated Flutter application notices.

## Native Host Rust dependencies

The native Host's exact resolved versions and checksums are recorded in
`Cargo.lock`. Its direct third-party crates are:

- `axum` 0.8.9 — <https://github.com/tokio-rs/axum> — MIT.
- `base64` 0.22.1 — <https://github.com/marshallpierce/rust-base64> — MIT OR
  Apache-2.0.
- `dirs` 6.0.0 — <https://github.com/dirs-dev/dirs-rs> — MIT OR Apache-2.0.
- `fs2` 0.4.3 — <https://github.com/danburkert/fs2-rs> — MIT OR Apache-2.0.
- `getrandom` 0.4.3 — <https://github.com/rust-random/getrandom> — MIT OR
  Apache-2.0.
- `json-skimmer` 1.0.0 — <https://github.com/joeledwards/json-skimmer> — MIT.
- `libc` 0.2.191 (Unix targets) — <https://github.com/rust-lang/libc> — MIT OR
  Apache-2.0.
- `pem` 3.0.6 — <https://github.com/jcreekmore/pem-rs> — MIT.
- `rustls` 0.23.46 — <https://github.com/rustls/rustls> — Apache-2.0 OR ISC OR
  MIT.
- `serde` 1.0.229 and `serde_json` 1.0.154 —
  <https://github.com/serde-rs/serde> and
  <https://github.com/serde-rs/json> — MIT OR Apache-2.0.
- `sha2` 0.11.0 — <https://github.com/RustCrypto/hashes> — MIT OR Apache-2.0.
- `subtle` 2.6.1 — <https://github.com/dalek-cryptography/subtle> — BSD-3-Clause.
- `tokio` 1.54.1 — <https://github.com/tokio-rs/tokio> — MIT.
- `uuid` 1.29.0 — <https://github.com/uuid-rs/uuid> — MIT OR Apache-2.0.

Direct test-only crates are `tempfile` 3.27.0
(<https://github.com/Stebalien/tempfile>, MIT OR Apache-2.0) and `tungstenite`
0.29.0 (<https://github.com/snapview/tungstenite-rs>, MIT OR Apache-2.0).

Complete license texts for these crates and their transitive dependencies are
available in their source distributions. Release packaging must generate and
ship a lockfile-derived native dependency license bundle before RC.
