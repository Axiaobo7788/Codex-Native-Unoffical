import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/desktop_review_artifact.dart';
import '../../tool/src/linux_runtime_gate.dart';

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

  test(
    'macOS framework binaries may be non-executable while launchers may not',
    () async {
      final fixture = await _createMacOsFixture();
      addTearDown(() => fixture.root.delete(recursive: true));

      final result = await assembleDesktopReviewArtifact(fixture.config);
      await verifyDesktopReviewArtifact(result.provenance);

      final launcher = File(
        '${fixture.bundle.path}/Contents/MacOS/codex_native_unofficial',
      );
      final chmod = await Process.run('chmod', ['644', launcher.path]);
      if (chmod.exitCode != 0) {
        throw StateError('could not remove executable fixture permission');
      }

      await expectLater(
        assembleDesktopReviewArtifact(
          fixture.config.copyWithOutput(
            Directory('${fixture.root.path}/invalid-output')..createSync(),
          ),
        ),
        throwsA(
          isA<DesktopReviewArtifactException>().having(
            (error) => error.message,
            'message',
            contains('Contents/MacOS/codex_native_unofficial'),
          ),
        ),
      );
    },
  );

  test(
    'native verification exercises the extracted Linux runtime closure',
    () async {
      final fixture = await _createLinuxFixture();
      addTearDown(() => fixture.root.delete(recursive: true));
      final result = await assembleDesktopReviewArtifact(fixture.config);

      await verifyDesktopReviewArtifact(
        result.provenance,
        verifyNativeRuntime: true,
        linuxRuntimeCommandRunner: _fakeLinuxRuntimeCommand,
      );
    },
  );

  test('Linux runtime gate rejects a build-tree library RUNPATH', () async {
    final fixture = await _createLinuxFixture();
    addTearDown(() => fixture.root.delete(recursive: true));

    await expectLater(
      verifyLinuxRuntimeBundle(
        fixture.bundle,
        commandRunner: _fakeUnsafeLinuxRuntimeCommand,
      ),
      throwsA(
        isA<LinuxRuntimeGateException>().having(
          (error) => error.message,
          'message',
          contains('non-relocatable RUNPATH'),
        ),
      ),
    );
  });

  test('Linux runtime gate rejects an unresolved runner dependency', () async {
    final fixture = await _createLinuxFixture();
    addTearDown(() => fixture.root.delete(recursive: true));

    await expectLater(
      verifyLinuxRuntimeBundle(
        fixture.bundle,
        commandRunner: _fakeMissingLinuxRuntimeCommand,
      ),
      throwsA(
        isA<LinuxRuntimeGateException>().having(
          (error) => error.message,
          'message',
          contains('unresolved dependency'),
        ),
      ),
    );
  });
}

Future<LinuxRuntimeCommandResult> _fakeLinuxRuntimeCommand(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) {
  return _fakeLinuxCommand(executable, arguments, unsafeLibraryRunpath: false);
}

Future<LinuxRuntimeCommandResult> _fakeUnsafeLinuxRuntimeCommand(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) {
  return _fakeLinuxCommand(executable, arguments, unsafeLibraryRunpath: true);
}

Future<LinuxRuntimeCommandResult> _fakeLinuxCommand(
  String executable,
  List<String> arguments, {
  required bool unsafeLibraryRunpath,
}) async {
  if (executable == 'readelf' && arguments.first == '-h') {
    return const LinuxRuntimeCommandResult(
      exitCode: 0,
      stdout:
          '  Class:                             ELF64\n'
          '  Machine:                           '
          'Advanced Micro Devices X86-64\n',
      stderr: '',
    );
  }
  if (executable == 'readelf' && arguments.first == '-d') {
    final file = arguments.last.replaceAll('\\', '/');
    final runtimePath = file.endsWith('/codex_native_unofficial')
        ? r'$ORIGIN/lib'
        : unsafeLibraryRunpath && file.endsWith('/libflutter_linux_gtk.so')
        ? '/repository/linux/flutter/ephemeral'
        : r'$ORIGIN';
    return LinuxRuntimeCommandResult(
      exitCode: 0,
      stdout:
          ' 0x000000000000001d (RUNPATH) '
          'Library runpath: [$runtimePath]\n',
      stderr: '',
    );
  }
  if (executable == 'env' && arguments.contains('ldd')) {
    final file = File(arguments.last).absolute;
    if (file.path.endsWith('codex-native-host')) {
      return const LinuxRuntimeCommandResult(
        exitCode: 0,
        stdout: 'libc.so.6 => /lib/libc.so.6 (0x00000001)\n',
        stderr: '',
      );
    }
    final engine = File('${file.parent.path}/lib/libflutter_linux_gtk.so')
        .absolute
        .path;
    return LinuxRuntimeCommandResult(
      exitCode: 0,
      stdout:
          'libflutter_linux_gtk.so => $engine (0x00000001)\n'
          'libc.so.6 => /lib/libc.so.6 (0x00000002)\n',
      stderr: '',
    );
  }
  return LinuxRuntimeCommandResult(
    exitCode: 127,
    stdout: '',
    stderr: 'unexpected command: $executable ${arguments.join(' ')}',
  );
}

Future<LinuxRuntimeCommandResult> _fakeMissingLinuxRuntimeCommand(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  if (executable == 'env' &&
      arguments.last
          .replaceAll('\\', '/')
          .endsWith('/codex_native_unofficial')) {
    return const LinuxRuntimeCommandResult(
      exitCode: 0,
      stdout: 'libflutter_linux_gtk.so => not found\n',
      stderr: '',
    );
  }
  return _fakeLinuxCommand(executable, arguments, unsafeLibraryRunpath: false);
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

Future<_MacOsFixture> _createMacOsFixture() async {
  final root = await Directory.systemTemp.createTemp('desktop-review-macos-');
  final repository = Directory('${root.path}/repository')..createSync();
  final bundle = Directory('${root.path}/codex_native_unofficial.app')
    ..createSync();
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
    'Contents/Info.plist': '<plist/>',
    'Contents/MacOS/codex_native_unofficial': '#!/bin/sh\nexit 0\n',
    'Contents/MacOS/codex-native-host': '#!/bin/sh\nexit 0\n',
    'Contents/Resources/NATIVE_HOST_THIRD_PARTY_LICENSES.txt':
        'native notice\n',
    'Contents/Frameworks/App.framework/App': 'aot framework',
    'Contents/Frameworks/App.framework/Resources/flutter_assets/'
            'AssetManifest.bin':
        'assets',
    'Contents/Frameworks/App.framework/Resources/flutter_assets/NOTICES.Z':
        'notices',
    'Contents/Frameworks/App.framework/Resources/flutter_assets/'
            'THIRD_PARTY_NOTICES.md':
        'application notice\n',
    'Contents/Frameworks/FlutterMacOS.framework/FlutterMacOS':
        'flutter framework',
  };
  for (final entry in files.entries) {
    final file = File('${bundle.path}/${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }
  for (final executable in const [
    'Contents/MacOS/codex_native_unofficial',
    'Contents/MacOS/codex-native-host',
  ]) {
    final chmod = await Process.run('chmod', [
      '755',
      '${bundle.path}/$executable',
    ]);
    if (chmod.exitCode != 0) {
      throw StateError('could not prepare executable fixture');
    }
  }

  final config = DesktopReviewArtifactConfig(
    repositoryRoot: repository,
    bundleDirectory: bundle,
    outputDirectory: output,
    platform: DesktopArtifactPlatform.macos,
    architecture: 'arm64',
    sourceRevision: 'b' * 40,
    sourceTreeState: 'clean',
    flutterVersion: '3.47.1',
    rustVersion: '1.89.0',
    buildOrigin: 'test',
    verifyRepositoryIdentity: false,
  );
  return _MacOsFixture(
    root: root,
    bundle: bundle,
    output: output,
    config: config,
  );
}

extension on DesktopReviewArtifactConfig {
  DesktopReviewArtifactConfig copyWithOutput(Directory outputDirectory) {
    return DesktopReviewArtifactConfig(
      repositoryRoot: repositoryRoot,
      bundleDirectory: bundleDirectory,
      outputDirectory: outputDirectory,
      platform: platform,
      architecture: architecture,
      sourceRevision: sourceRevision,
      sourceTreeState: sourceTreeState,
      flutterVersion: flutterVersion,
      rustVersion: rustVersion,
      buildOrigin: buildOrigin,
      verifyRepositoryIdentity: verifyRepositoryIdentity,
    );
  }
}

final class _MacOsFixture {
  _MacOsFixture({
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
