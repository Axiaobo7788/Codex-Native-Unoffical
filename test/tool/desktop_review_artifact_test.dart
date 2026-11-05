import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/desktop_review_artifact.dart';

void main() {
  test(
    'assembles and independently verifies a bounded Linux review archive',
    () async {
      final fixture = await _createLinuxFixture();
      addTearDown(() => fixture.root.delete(recursive: true));

      final result = await assembleDesktopReviewArtifact(fixture.config);

      expect(await result.archive.exists(), isTrue);
      expect(await result.checksum.exists(), isTrue);
      expect(await result.provenance.exists(), isTrue);
      expect(result.archiveSha256, hasLength(64));
      await verifyDesktopReviewArtifact(result.provenance);

      final provenance = jsonDecode(await result.provenance.readAsString());
      expect(provenance['distributionReady'], isFalse);
      expect(provenance['reviewOnly'], isTrue);
      expect(provenance['target']['buildMode'], 'release');
      expect(provenance['signingBoundary']['status'], 'not_assessed');
    },
  );

  test(
    'verification rejects an archive changed after provenance generation',
    () async {
      final fixture = await _createLinuxFixture();
      addTearDown(() => fixture.root.delete(recursive: true));
      final result = await assembleDesktopReviewArtifact(fixture.config);

      await result.archive.writeAsBytes(const [0], mode: FileMode.append);

      await expectLater(
        verifyDesktopReviewArtifact(result.provenance),
        throwsA(
          isA<DesktopReviewArtifactException>().having(
            (error) => error.message,
            'message',
            contains('archive SHA-256'),
          ),
        ),
      );
    },
  );

  test(
    'assembly fails closed when the release AOT library is missing',
    () async {
      final fixture = await _createLinuxFixture();
      addTearDown(() => fixture.root.delete(recursive: true));
      await File('${fixture.bundle.path}/lib/libapp.so').delete();

      await expectLater(
        assembleDesktopReviewArtifact(fixture.config),
        throwsA(
          isA<DesktopReviewArtifactException>().having(
            (error) => error.message,
            'message',
            contains('lib/libapp.so'),
          ),
        ),
      );
      expect(await fixture.output.list().toList(), isEmpty);
    },
  );
}

Future<_LinuxFixture> _createLinuxFixture() async {
  final root = await Directory.systemTemp.createTemp('desktop-review-test-');
  final repository = Directory('${root.path}/repository')..createSync();
  final bundle = Directory('${root.path}/bundle')..createSync();
  final output = Directory('${root.path}/output')..createSync();
  File('${repository.path}/pubspec.yaml')
      .writeAsStringSync('name: fixture\nversion: 0.1.0+1\n');
  final nativeNotice = File(
    '${repository.path}/licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt',
  );
  nativeNotice.parent.createSync(recursive: true);
  nativeNotice.writeAsStringSync('native notice\n');
  File('${repository.path}/THIRD_PARTY_NOTICES.md')
      .writeAsStringSync('application notice\n');

  final files = <String, String>{
    'codex_native_unofficial': '#!/bin/sh\nexit 0\n',
    'codex-native-host': '#!/bin/sh\nexit 0\n',
    'NATIVE_HOST_THIRD_PARTY_LICENSES.txt': 'native notice\n',
    'data/icudtl.dat': 'icu',
    'data/flutter_assets/AssetManifest.bin': 'assets',
    'data/flutter_assets/NOTICES.Z': 'notices',
    'data/flutter_assets/THIRD_PARTY_NOTICES.md': 'application notice\n',
    'lib/libapp.so': 'aot',
    'lib/libflutter_linux_gtk.so': 'flutter',
  };
  for (final entry in files.entries) {
    final file = File('${bundle.path}/${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }
  for (final executable in const [
    'codex_native_unofficial',
    'codex-native-host',
  ]) {
    final chmod = await Process.run('chmod', [
      '755',
      '${bundle.path}/$executable',
    ]);
    if (chmod.exitCode != 0) {
      throw StateError('could not prepare executable fixture');
    }
  }

  return _LinuxFixture(
    root: root,
    bundle: bundle,
    output: output,
    config: DesktopReviewArtifactConfig(
      repositoryRoot: repository,
      bundleDirectory: bundle,
      outputDirectory: output,
      platform: DesktopArtifactPlatform.linux,
      architecture: 'x64',
      sourceRevision: 'a' * 40,
      sourceTreeState: 'clean',
      flutterVersion: '3.47.1',
      rustVersion: '1.89.0',
      buildOrigin: 'test',
      verifyRepositoryIdentity: false,
    ),
  );
}

final class _LinuxFixture {
  _LinuxFixture({
    required this.root,
    required this.bundle,
    required this.output,
    required this.config,
  });

  final Directory root;
  final Directory bundle;
  final Directory output;
  final DesktopReviewArtifactConfig config;
}
