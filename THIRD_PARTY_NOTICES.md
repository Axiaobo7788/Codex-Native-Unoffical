# Third-party notices

Flutter release builds include the license texts collected from every bundled
Dart/Flutter package in the generated application notices. Direct packages and
native runtime components with product-specific provenance or terms are also
identified here so source distributions keep their origin visible.

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

## mobile_scanner 7.5.0

- Source: <https://github.com/juliansteenbakker/mobile_scanner>
- Copyright 2022 Julian Steenbakker.
- License: BSD 3-Clause. The complete license is distributed with the package
  and in the generated Flutter application notices.
- The product enables this scanner only on Android. The package also declares a
  macOS plugin, so Flutter registers that native code in macOS builds even
  though this product never opens the scanner there.

## Android pairing-scanner native runtime

The default Android path of `mobile_scanner` resolves the bundled
`com.google.mlkit:barcode-scanning:17.3.0` artifact and its
`com.google.android.gms:play-services-mlkit-barcode-scanning:18.3.1` runtime.
Those artifacts are governed by the
[ML Kit Terms of Service](https://developers.google.com/ml-kit/terms), not by
this project's Apache-2.0 license. The barcode models are packaged in the app,
so scanning does not wait for a first-use model download. Google documents that
images, decoded text, and results are processed on-device and are not sent to
Google, while ML Kit can contact Google for fixes, model or accelerator updates,
and sends performance and utilization metrics. Store/privacy disclosures must
reflect that behavior. This project disables ML Kit auto-zoom, which avoids the
additional auto-zoom session and bounding-box metrics documented by Google.

Android camera capture is supplied by AndroidX Camera 1.6.1. Its POM declares
Apache License 2.0 and BSD 3-Clause because Camera Core includes libyuv. Kotlin
coroutines Android 1.11.0 is Apache-2.0. Their complete licenses remain in their
upstream artifacts and source repositories. The resolved Android graph is also
recorded by Gradle and must be re-audited when the scanner version changes.

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
