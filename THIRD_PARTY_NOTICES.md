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

## qr 4.0.1

- Source: <https://github.com/kevmoo/qr.dart>
- Copyright 2014, the Dart QR project authors.
- License: BSD 3-Clause. The package is pure Dart, performs QR generation
  offline, and its complete license is distributed in the generated Flutter
  application notices.

## Native Host Rust dependencies

The native Host's exact resolved versions and checksums are recorded in
`Cargo.lock`. `licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt` is generated from
that locked runtime graph with pinned `cargo-about` 0.9.3. It lists every direct,
transitive, build, and platform-specific runtime crate, the selected SPDX
license, upstream source location, and complete license text. Pure development
dependencies are intentionally excluded because they are not shipped.

The graph includes unmodified `option-ext` 0.2.0 under MPL-2.0. Its exact
published source is available at <https://crates.io/crates/option-ext/0.2.0> and
its repository is <https://github.com/soc/option-ext.git>; the generated notice
tells binary recipients where to obtain that source and includes the complete
MPL-2.0 text. The rest of this application's source does not become MPL-covered
merely because it is part of the same larger work.

Linux and Windows builds place the generated notice beside
`codex-native-host`; macOS places it in the application `Resources` directory.
CI regenerates it with `--locked --fail` and rejects any byte-level drift before
building. Run `./tool/generate_native_licenses.sh --write` after changing the
native dependency graph, then commit the reviewed result.
