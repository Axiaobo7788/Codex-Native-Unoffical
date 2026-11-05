import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'linux_runtime_gate.dart';

enum DesktopArtifactPlatform {
  linux,
  windows,
  macos;

  static DesktopArtifactPlatform parse(String value) {
    return switch (value) {
      'linux' => linux,
      'windows' => windows,
      'macos' => macos,
      _ => throw DesktopReviewArtifactException(
        'unsupported desktop platform: $value',
      ),
    };
  }

  String get slug => name;
}

final class DesktopReviewArtifactConfig {
  DesktopReviewArtifactConfig({
    required this.repositoryRoot,
    required this.bundleDirectory,
    required this.outputDirectory,
    required this.platform,
    required this.architecture,
    required this.sourceRevision,
    required this.sourceTreeState,
    required this.flutterVersion,
    required this.rustVersion,
    required this.buildOrigin,
    this.verifyRepositoryIdentity = true,
  });

  final Directory repositoryRoot;
  final Directory bundleDirectory;
  final Directory outputDirectory;
  final DesktopArtifactPlatform platform;
  final String architecture;
  final String sourceRevision;
  final String sourceTreeState;
  final String flutterVersion;
  final String rustVersion;
  final String buildOrigin;
  final bool verifyRepositoryIdentity;
}

final class DesktopReviewArtifactResult {
  DesktopReviewArtifactResult({
    required this.archive,
    required this.checksum,
    required this.provenance,
    required this.archiveSha256,
  });

  final File archive;
  final File checksum;
  final File provenance;
  final String archiveSha256;
}

final class DesktopReviewArtifactException implements Exception {
  DesktopReviewArtifactException(this.message);

  final String message;

  @override
  String toString() => 'DesktopReviewArtifactException: $message';
}

Future<DesktopReviewArtifactResult> assembleDesktopReviewArtifact(
  DesktopReviewArtifactConfig config,
) async {
  final metadata = await _validateConfig(config);
  await _validateBundleLayout(
    platform: config.platform,
    architecture: config.architecture,
    bundleDirectory: config.bundleDirectory,
    repositoryRoot: config.repositoryRoot,
    runHostSmoke: true,
  );

  await config.outputDirectory.create(recursive: true);
  final artifactName = [
    'codex-native-unofficial',
    metadata.versionLabel,
    config.platform.slug,
    config.architecture,
    'review-only',
  ].join('-');
  final archive = File(
    _join(config.outputDirectory.path, '$artifactName.tar.gz'),
  );
  final checksum = File('${archive.path}.sha256');
  final provenance = File(
    _join(config.outputDirectory.path, '$artifactName.provenance.json'),
  );
  for (final output in [archive, checksum, provenance]) {
    if (await output.exists()) {
      throw DesktopReviewArtifactException(
        'refusing to overwrite existing artifact output: ${output.path}',
      );
    }
  }

  final stagingParent = Directory(
    _join(
      config.outputDirectory.path,
      '.$artifactName.staging-$pid-${DateTime.now().microsecondsSinceEpoch}',
    ),
  );
  final stagingRoot = Directory(_join(stagingParent.path, artifactName));
  final generatedAt = DateTime.now().toUtc().toIso8601String();

  try {
    await stagingRoot.create(recursive: true);
    final payload = Directory(_join(stagingRoot.path, 'payload'));
    await payload.create();
    if (config.platform == DesktopArtifactPlatform.macos) {
      final appName = _basename(config.bundleDirectory.path);
      await _copyDirectory(
        config.bundleDirectory,
        Directory(_join(payload.path, appName)),
      );
    } else {
      await _copyDirectoryContents(config.bundleDirectory, payload);
    }

    final payloadEntries = await _inventoryPayload(payload, config.platform);
    final manifest = <String, Object?>{
      'schemaVersion': 1,
      'artifactKind': 'codex-native-unofficial-desktop-review',
      'distributionReady': false,
      'reviewOnly': true,
      'generatedAtUtc': generatedAt,
      'application': <String, Object?>{
        'version': metadata.version,
        'buildNumber': metadata.buildNumber,
      },
      'source': <String, Object?>{
        'revision': config.sourceRevision,
        'treeState': config.sourceTreeState,
      },
      'target': <String, Object?>{
        'platform': config.platform.slug,
        'architecture': config.architecture,
        'buildMode': 'release',
      },
      'toolchain': <String, Object?>{
        'flutter': config.flutterVersion,
        'rust': config.rustVersion,
      },
      'buildOrigin': config.buildOrigin,
      'payloadRoot': 'payload',
      'files': payloadEntries,
    };
    final manifestFile = File(
      _join(stagingRoot.path, 'ARTIFACT_MANIFEST.json'),
    );
    await _writeJson(manifestFile, manifest);
    final manifestSha256 = await _sha256File(manifestFile);

    final sums = StringBuffer();
    for (final entry in payloadEntries) {
      if (entry['type'] == 'file') {
        sums.writeln('${entry['sha256']}  payload/${entry['path']}');
      }
    }
    await File(_join(stagingRoot.path, 'SHA256SUMS'))
        .writeAsString(sums.toString(), flush: true);
    await File(_join(stagingRoot.path, 'REVIEW_ONLY.txt')).writeAsString(
      _reviewOnlyText(config.platform, config.sourceRevision),
      flush: true,
    );

    await _createTarArchive(
      stagingParent: stagingParent,
      rootName: artifactName,
      archive: archive,
    );
    final archiveSha256 = await _sha256File(archive);
    await checksum.writeAsString(
      '$archiveSha256  ${_basename(archive.path)}\n',
      flush: true,
    );
    await _writeJson(provenance, <String, Object?>{
      'schemaVersion': 1,
      'artifactKind': 'codex-native-unofficial-desktop-review-archive',
      'distributionReady': false,
      'reviewOnly': true,
      'generatedAtUtc': generatedAt,
      'archiveFile': _basename(archive.path),
      'archiveBytes': await archive.length(),
      'archiveSha256': archiveSha256,
      'archiveRoot': artifactName,
      'manifestSha256': manifestSha256,
      'application': <String, Object?>{
        'version': metadata.version,
        'buildNumber': metadata.buildNumber,
      },
      'source': <String, Object?>{
        'revision': config.sourceRevision,
        'treeState': config.sourceTreeState,
      },
      'target': <String, Object?>{
        'platform': config.platform.slug,
        'architecture': config.architecture,
        'buildMode': 'release',
      },
      'toolchain': <String, Object?>{
        'flutter': config.flutterVersion,
        'rust': config.rustVersion,
      },
      'buildOrigin': config.buildOrigin,
      'signingBoundary': _signingBoundary(config.platform),
    });

    await verifyDesktopReviewArtifact(provenance);
    return DesktopReviewArtifactResult(
      archive: archive,
      checksum: checksum,
      provenance: provenance,
      archiveSha256: archiveSha256,
    );
  } catch (_) {
    for (final output in [archive, checksum, provenance]) {
      if (await output.exists()) {
        await output.delete();
      }
    }
    rethrow;
  } finally {
    if (await stagingParent.exists()) {
      await stagingParent.delete(recursive: true);
    }
  }
}

Future<void> verifyDesktopReviewArtifact(
  File provenanceFile, {
  bool verifyNativeRuntime = false,
  LinuxRuntimeCommandRunner? linuxRuntimeCommandRunner,
}) async {
  final provenance = await _readJsonObject(provenanceFile);
  _requireExact(provenance, 'schemaVersion', 1);
  _requireExact(
    provenance,
    'artifactKind',
    'codex-native-unofficial-desktop-review-archive',
  );
  _requireExact(provenance, 'distributionReady', false);
  _requireExact(provenance, 'reviewOnly', true);

  final archiveName = _requiredSafeBasename(provenance, 'archiveFile');
  final archiveRoot = _requiredSafeBasename(provenance, 'archiveRoot');
  final expectedArchiveSha = _requiredSha256(provenance, 'archiveSha256');
  final expectedManifestSha = _requiredSha256(provenance, 'manifestSha256');
  final archive = File(_join(provenanceFile.parent.path, archiveName));
  final checksum = File('${archive.path}.sha256');
  if (!await archive.exists() || !await checksum.exists()) {
    throw DesktopReviewArtifactException(
      'archive or checksum sidecar is missing beside provenance',
    );
  }
  final actualArchiveSha = await _sha256File(archive);
  if (actualArchiveSha != expectedArchiveSha) {
    throw DesktopReviewArtifactException(
      'archive SHA-256 does not match provenance',
    );
  }
  final expectedChecksumLine = '$expectedArchiveSha  $archiveName\n';
  if (await checksum.readAsString() != expectedChecksumLine) {
    throw DesktopReviewArtifactException(
      'archive checksum sidecar is not canonical or does not match provenance',
    );
  }
  if (await archive.length() !=
      _requiredPositiveInt(provenance, 'archiveBytes')) {
    throw DesktopReviewArtifactException(
      'archive byte length does not match provenance',
    );
  }

  await _validateArchiveListing(archive, archiveRoot);
  final extractionParent = await Directory.systemTemp.createTemp(
    'codex-native-review-verify-',
  );
  try {
    final extract = await Process.run('tar', [
      '-xzf',
      archive.absolute.path,
      '-C',
      extractionParent.path,
    ]);
    if (extract.exitCode != 0) {
      throw DesktopReviewArtifactException(
        'tar could not extract the review artifact: ${_boundedDiagnostic(extract.stderr)}',
      );
    }
    final root = Directory(_join(extractionParent.path, archiveRoot));
    final manifestFile = File(_join(root.path, 'ARTIFACT_MANIFEST.json'));
    final sumsFile = File(_join(root.path, 'SHA256SUMS'));
    final reviewFile = File(_join(root.path, 'REVIEW_ONLY.txt'));
    final payload = Directory(_join(root.path, 'payload'));
    if (!await manifestFile.exists() ||
        !await sumsFile.exists() ||
        !await reviewFile.exists() ||
        !await payload.exists()) {
      throw DesktopReviewArtifactException(
        'archive root is missing its manifest, sums, review notice, or payload',
      );
    }
    if (await _sha256File(manifestFile) != expectedManifestSha) {
      throw DesktopReviewArtifactException(
        'inner manifest SHA-256 does not match provenance',
      );
    }
    if (!(await reviewFile.readAsString()).contains(
      'distributionReady=false',
    )) {
      throw DesktopReviewArtifactException('review-only warning is missing');
    }

    final manifest = await _readJsonObject(manifestFile);
    _requireExact(manifest, 'schemaVersion', 1);
    _requireExact(
      manifest,
      'artifactKind',
      'codex-native-unofficial-desktop-review',
    );
    _requireExact(manifest, 'distributionReady', false);
    _requireExact(manifest, 'reviewOnly', true);
    _requireExact(manifest, 'payloadRoot', 'payload');
    for (final key in const [
      'application',
      'source',
      'target',
      'toolchain',
      'buildOrigin',
    ]) {
      if (jsonEncode(manifest[key]) != jsonEncode(provenance[key])) {
        throw DesktopReviewArtifactException(
          'inner manifest $key does not match outer provenance',
        );
      }
    }
    final target = _requiredObject(manifest, 'target');
    final platform = DesktopArtifactPlatform.parse(
      _requiredString(target, 'platform'),
    );
    final architecture = _requiredString(target, 'architecture');
    if (!_isSupportedTarget(platform, architecture)) {
      throw DesktopReviewArtifactException(
        'unsupported review-artifact target: '
        '${platform.slug}-$architecture',
      );
    }
    if (verifyNativeRuntime && !_isCurrentPlatform(platform)) {
      throw DesktopReviewArtifactException(
        'native runtime verification for ${platform.slug} requires a '
        'matching host operating system',
      );
    }
    _requireExact(target, 'buildMode', 'release');
    final expectedEntries = manifest['files'];
    if (expectedEntries is! List<Object?> || expectedEntries.isEmpty) {
      throw DesktopReviewArtifactException(
        'inner manifest has no payload entries',
      );
    }
    final actualEntries = await _inventoryPayload(payload, platform);
    _validatePayloadEntries(expectedEntries, actualEntries);
    final expectedSums = StringBuffer();
    for (final entry in actualEntries) {
      if (entry['type'] == 'file') {
        expectedSums.writeln('${entry['sha256']}  payload/${entry['path']}');
      }
    }
    if (await sumsFile.readAsString() != expectedSums.toString()) {
      throw DesktopReviewArtifactException(
        'inner SHA256SUMS is not canonical or does not match the payload',
      );
    }
    await _validatePayloadLayout(
      platform: platform,
      architecture: architecture,
      payloadDirectory: payload,
      repositoryRoot: null,
      runHostSmoke: verifyNativeRuntime,
    );
    if (verifyNativeRuntime && platform == DesktopArtifactPlatform.linux) {
      await verifyLinuxRuntimeBundle(
        payload,
        commandRunner: linuxRuntimeCommandRunner,
      );
    }
  } finally {
    if (await extractionParent.exists()) {
      await extractionParent.delete(recursive: true);
    }
  }
}

bool _isCurrentPlatform(DesktopArtifactPlatform platform) {
  return switch (platform) {
    DesktopArtifactPlatform.linux => Platform.isLinux,
    DesktopArtifactPlatform.windows => Platform.isWindows,
    DesktopArtifactPlatform.macos => Platform.isMacOS,
  };
}

Future<_ApplicationMetadata> _validateConfig(
  DesktopReviewArtifactConfig config,
) async {
  if (!await config.repositoryRoot.exists() ||
      !await config.bundleDirectory.exists()) {
    throw DesktopReviewArtifactException(
      'repository root or desktop bundle directory does not exist',
    );
  }
  if (!_isSupportedTarget(config.platform, config.architecture)) {
    throw DesktopReviewArtifactException(
      'unsupported review-artifact target: '
      '${config.platform.slug}-${config.architecture}',
    );
  }
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(config.sourceRevision)) {
    throw DesktopReviewArtifactException(
      'source revision must be a lowercase 40-character Git object ID',
    );
  }
  if (config.sourceTreeState != 'clean' && config.sourceTreeState != 'dirty') {
    throw DesktopReviewArtifactException(
      'source tree state must be exactly clean or dirty',
    );
  }
  if (config.verifyRepositoryIdentity) {
    await _verifyRepositoryIdentity(config);
  }
  for (final field in <String, String>{
    'Flutter version': config.flutterVersion,
    'Rust version': config.rustVersion,
    'build origin': config.buildOrigin,
  }.entries) {
    if (field.value.isEmpty ||
        field.value.length > 256 ||
        field.value.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
      throw DesktopReviewArtifactException('${field.key} is empty or unsafe');
    }
  }
  final pubspec = File(_join(config.repositoryRoot.path, 'pubspec.yaml'));
  final nativeNotice = File(
    _join(
      config.repositoryRoot.path,
      'licenses',
      'NATIVE_HOST_THIRD_PARTY_LICENSES.txt',
    ),
  );
  final applicationNotice = File(
    _join(config.repositoryRoot.path, 'THIRD_PARTY_NOTICES.md'),
  );
  if (!await pubspec.exists() ||
      !await nativeNotice.exists() ||
      !await applicationNotice.exists()) {
    throw DesktopReviewArtifactException(
      'repository release metadata or required notices are missing',
    );
  }
  final versionMatch = RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)(?:\+([0-9A-Za-z.-]+))?\s*$',
    multiLine: true,
  ).firstMatch(await pubspec.readAsString());
  if (versionMatch == null) {
    throw DesktopReviewArtifactException(
      'pubspec.yaml has no supported version',
    );
  }
  return _ApplicationMetadata(
    version: versionMatch.group(1)!,
    buildNumber: versionMatch.group(2),
  );
}

bool _isSupportedTarget(DesktopArtifactPlatform platform, String architecture) {
  return switch (platform) {
    DesktopArtifactPlatform.linux => architecture == 'x64',
    DesktopArtifactPlatform.windows => architecture == 'x64',
    DesktopArtifactPlatform.macos => architecture == 'universal',
  };
}

Future<void> _verifyRepositoryIdentity(
  DesktopReviewArtifactConfig config,
) async {
  final revision = await Process.run('git', [
    '-C',
    config.repositoryRoot.absolute.path,
    'rev-parse',
    'HEAD',
  ]);
  final actualRevision = '${revision.stdout}'.trim();
  if (revision.exitCode != 0 || actualRevision != config.sourceRevision) {
    throw DesktopReviewArtifactException(
      'declared source revision does not match repository HEAD',
    );
  }
  final status = await Process.run('git', [
    '-C',
    config.repositoryRoot.absolute.path,
    'status',
    '--porcelain=v1',
    '--untracked-files=normal',
  ]);
  if (status.exitCode != 0) {
    throw DesktopReviewArtifactException(
      'could not establish the repository source-tree state',
    );
  }
  final actualState = '${status.stdout}'.trim().isEmpty ? 'clean' : 'dirty';
  if (actualState != config.sourceTreeState) {
    throw DesktopReviewArtifactException(
      'declared source-tree state ${config.sourceTreeState} does not match '
      'the repository state $actualState: '
      '${_boundedDiagnostic(status.stdout)}',
    );
  }
}

Future<void> _validateBundleLayout({
  required DesktopArtifactPlatform platform,
  required String architecture,
  required Directory bundleDirectory,
  required Directory repositoryRoot,
  required bool runHostSmoke,
}) async {
  if (platform == DesktopArtifactPlatform.macos &&
      !_basename(bundleDirectory.path).endsWith('.app')) {
    throw DesktopReviewArtifactException(
      'macOS bundle path must identify one .app directory',
    );
  }
  await _validatePayloadLayout(
    platform: platform,
    architecture: architecture,
    payloadDirectory: bundleDirectory,
    macAppDirectory: platform == DesktopArtifactPlatform.macos
        ? bundleDirectory
        : null,
    repositoryRoot: repositoryRoot,
    runHostSmoke: runHostSmoke,
  );
}

Future<void> _validatePayloadLayout({
  required DesktopArtifactPlatform platform,
  required String architecture,
  required Directory payloadDirectory,
  Directory? macAppDirectory,
  required Directory? repositoryRoot,
  required bool runHostSmoke,
}) async {
  late final Directory layoutRoot;
  late final String hostRelativePath;
  late final String nativeNoticeRelativePath;
  late final String applicationNoticeRelativePath;
  late final List<String> requiredFiles;
  final executableFiles = <String>{};

  switch (platform) {
    case DesktopArtifactPlatform.linux:
      layoutRoot = payloadDirectory;
      hostRelativePath = 'codex-native-host';
      nativeNoticeRelativePath = 'NATIVE_HOST_THIRD_PARTY_LICENSES.txt';
      applicationNoticeRelativePath =
          'data/flutter_assets/THIRD_PARTY_NOTICES.md';
      requiredFiles = const [
        'codex_native_unofficial',
        'codex-native-host',
        'NATIVE_HOST_THIRD_PARTY_LICENSES.txt',
        'data/icudtl.dat',
        'data/flutter_assets/AssetManifest.bin',
        'data/flutter_assets/NOTICES.Z',
        'data/flutter_assets/THIRD_PARTY_NOTICES.md',
        'lib/libapp.so',
        'lib/libflutter_linux_gtk.so',
      ];
      executableFiles.addAll(const [
        'codex_native_unofficial',
        'codex-native-host',
      ]);
    case DesktopArtifactPlatform.windows:
      layoutRoot = payloadDirectory;
      hostRelativePath = 'codex-native-host.exe';
      nativeNoticeRelativePath = 'NATIVE_HOST_THIRD_PARTY_LICENSES.txt';
      applicationNoticeRelativePath =
          'data/flutter_assets/THIRD_PARTY_NOTICES.md';
      requiredFiles = const [
        'codex_native_unofficial.exe',
        'codex-native-host.exe',
        'NATIVE_HOST_THIRD_PARTY_LICENSES.txt',
        'flutter_windows.dll',
        'data/app.so',
        'data/icudtl.dat',
        'data/flutter_assets/AssetManifest.bin',
        'data/flutter_assets/NOTICES.Z',
        'data/flutter_assets/THIRD_PARTY_NOTICES.md',
      ];
    case DesktopArtifactPlatform.macos:
      if (macAppDirectory != null) {
        layoutRoot = macAppDirectory;
      } else {
        final appEntities = await payloadDirectory
            .list(followLinks: false)
            .where((entity) => entity.path.endsWith('.app'))
            .toList();
        final apps = <Directory>[];
        for (final entity in appEntities) {
          final app = Directory(entity.path);
          if (await app.exists()) {
            apps.add(app);
          }
        }
        if (apps.length != 1) {
          throw DesktopReviewArtifactException(
            'macOS payload must contain exactly one .app bundle',
          );
        }
        layoutRoot = apps.single;
      }
      hostRelativePath = 'Contents/MacOS/codex-native-host';
      nativeNoticeRelativePath =
          'Contents/Resources/NATIVE_HOST_THIRD_PARTY_LICENSES.txt';
      applicationNoticeRelativePath =
          'Contents/Frameworks/App.framework/Resources/flutter_assets/'
          'THIRD_PARTY_NOTICES.md';
      requiredFiles = const [
        'Contents/Info.plist',
        'Contents/MacOS/codex_native_unofficial',
        'Contents/MacOS/codex-native-host',
        'Contents/Resources/NATIVE_HOST_THIRD_PARTY_LICENSES.txt',
        'Contents/Frameworks/App.framework/App',
        'Contents/Frameworks/App.framework/Resources/flutter_assets/'
            'AssetManifest.bin',
        'Contents/Frameworks/App.framework/Resources/flutter_assets/NOTICES.Z',
        'Contents/Frameworks/App.framework/Resources/flutter_assets/'
            'THIRD_PARTY_NOTICES.md',
        'Contents/Frameworks/FlutterMacOS.framework/FlutterMacOS',
      ];
      executableFiles.addAll(const [
        'Contents/MacOS/codex_native_unofficial',
        'Contents/MacOS/codex-native-host',
      ]);
  }

  for (final relativePath in requiredFiles) {
    final file = File(_resolveRelative(layoutRoot, relativePath));
    if (!await file.exists() || await file.length() <= 0) {
      throw DesktopReviewArtifactException(
        '${platform.slug} release layout is missing non-empty $relativePath',
      );
    }
    if (executableFiles.contains(relativePath) && !Platform.isWindows) {
      final mode = (await file.stat()).mode & 0x1ff;
      if (mode & 0x49 == 0) {
        throw DesktopReviewArtifactException(
          '${platform.slug} release executable lacks execute permission: '
          '$relativePath',
        );
      }
    }
  }
  await for (final entity in layoutRoot.list(
    recursive: true,
    followLinks: false,
  )) {
    if (_basename(entity.path) == 'kernel_blob.bin') {
      throw DesktopReviewArtifactException(
        '${platform.slug} review artifact contains a debug kernel blob',
      );
    }
  }

  if (repositoryRoot != null) {
    await _requireIdenticalFile(
      File(
        _join(
          repositoryRoot.path,
          'licenses',
          'NATIVE_HOST_THIRD_PARTY_LICENSES.txt',
        ),
      ),
      File(_resolveRelative(layoutRoot, nativeNoticeRelativePath)),
      'packaged native Host license notice',
    );
    await _requireIdenticalFile(
      File(_join(repositoryRoot.path, 'THIRD_PARTY_NOTICES.md')),
      File(_resolveRelative(layoutRoot, applicationNoticeRelativePath)),
      'packaged application third-party notice',
    );
  }
  if (runHostSmoke &&
      platform == DesktopArtifactPlatform.macos &&
      architecture == 'universal' &&
      Platform.isMacOS) {
    await _verifyMacOsUniversalBinaries(layoutRoot);
  }
  if (runHostSmoke) {
    await _runHostHelpSmoke(
      File(_resolveRelative(layoutRoot, hostRelativePath)),
    );
  }
}

Future<void> _verifyMacOsUniversalBinaries(Directory appBundle) async {
  for (final relativePath in const [
    'Contents/MacOS/codex_native_unofficial',
    'Contents/MacOS/codex-native-host',
    'Contents/Frameworks/App.framework/App',
    'Contents/Frameworks/FlutterMacOS.framework/FlutterMacOS',
  ]) {
    final binary = File(_resolveRelative(appBundle, relativePath));
    final result = await Process.run('/usr/bin/lipo', [
      '-archs',
      binary.absolute.path,
    ]);
    if (result.exitCode != 0) {
      throw DesktopReviewArtifactException(
        'could not inspect macOS architectures for $relativePath: '
        '${_boundedDiagnostic(result.stderr)}',
      );
    }
    final architectures = '${result.stdout}'
        .trim()
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toSet();
    if (architectures.length != 2 ||
        !architectures.contains('arm64') ||
        !architectures.contains('x86_64')) {
      throw DesktopReviewArtifactException(
        'macOS universal binary $relativePath must contain exactly arm64 and '
        'x86_64; found ${architectures.toList()..sort()}',
      );
    }
  }
}

Future<void> _runHostHelpSmoke(File host) async {
  final process = await Process.start(host.absolute.path, const ['--help']);
  final stdoutFuture = _drainBounded(process.stdout);
  final stderrFuture = _drainBounded(process.stderr);
  late final int exit;
  try {
    exit = await process.exitCode.timeout(const Duration(seconds: 10));
  } on TimeoutException {
    process.kill();
    await process.exitCode;
    throw DesktopReviewArtifactException(
      'packaged native Host --help smoke timed out',
    );
  }
  final output = await stdoutFuture;
  final error = await stderrFuture;
  if (exit != 0) {
    throw DesktopReviewArtifactException(
      'packaged native Host --help smoke failed with exit $exit: '
      '${_boundedDiagnostic('$output\n$error')}',
    );
  }
}

Future<String> _drainBounded(Stream<List<int>> stream) async {
  const maximumBytes = 8192;
  final retained = BytesBuilder(copy: false);
  var retainedBytes = 0;
  await for (final chunk in stream) {
    if (retainedBytes >= maximumBytes) {
      continue;
    }
    final take = chunk.length < maximumBytes - retainedBytes
        ? chunk.length
        : maximumBytes - retainedBytes;
    retained.add(chunk.sublist(0, take));
    retainedBytes += take;
  }
  return utf8.decode(retained.takeBytes(), allowMalformed: true);
}

Future<List<Map<String, Object?>>> _inventoryPayload(
  Directory payload,
  DesktopArtifactPlatform platform,
) async {
  final entities = await payload
      .list(recursive: true, followLinks: false)
      .where((entity) => entity is File || entity is Link)
      .toList();
  entities.sort((left, right) {
    return _relativePosix(
      payload.path,
      left.path,
    ).compareTo(_relativePosix(payload.path, right.path));
  });
  final entries = <Map<String, Object?>>[];
  for (final entity in entities) {
    final relativePath = _relativePosix(payload.path, entity.path);
    _validateManifestPath(relativePath);
    if (entity is Link) {
      final target = await entity.target();
      _validateRelativeLink(relativePath, target);
      entries.add(<String, Object?>{
        'path': relativePath,
        'type': 'symlink',
        'target': target,
      });
      continue;
    }
    final file = File(entity.path);
    final stat = await file.stat();
    final entry = <String, Object?>{
      'path': relativePath,
      'type': 'file',
      'bytes': stat.size,
      'sha256': await _sha256File(file),
    };
    if (platform != DesktopArtifactPlatform.windows) {
      entry['unixMode'] = (stat.mode & 0x1ff).toRadixString(8).padLeft(3, '0');
    }
    entries.add(entry);
  }
  if (entries.isEmpty) {
    throw DesktopReviewArtifactException('desktop payload is empty');
  }
  return entries;
}

void _validatePayloadEntries(
  List<Object?> expected,
  List<Map<String, Object?>> actual,
) {
  if (expected.length != actual.length) {
    throw DesktopReviewArtifactException(
      'payload entry count does not match the inner manifest',
    );
  }
  for (var index = 0; index < actual.length; index += 1) {
    final expectedEntry = expected[index];
    if (expectedEntry is! Map<String, Object?>) {
      throw DesktopReviewArtifactException('inner manifest entry is malformed');
    }
    final actualEntry = actual[index];
    if (jsonEncode(expectedEntry) != jsonEncode(actualEntry)) {
      throw DesktopReviewArtifactException(
        'payload entry does not match the inner manifest: '
        '${actualEntry['path']}',
      );
    }
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await _copyDirectoryContents(source, destination);
}

Future<void> _copyDirectoryContents(
  Directory source,
  Directory destination,
) async {
  final entities = await source
      .list(recursive: true, followLinks: false)
      .toList();
  entities.sort((left, right) => left.path.compareTo(right.path));
  for (final entity in entities) {
    final relativePath = _relativeNative(source.path, entity.path);
    final targetPath = _join(destination.path, relativePath);
    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
    } else if (entity is Link) {
      final target = await entity.target();
      _validateRelativeLink(
        relativePath.split(Platform.pathSeparator).join('/'),
        target,
      );
      await Directory(_dirname(targetPath)).create(recursive: true);
      await Link(targetPath).create(target);
    } else if (entity is File) {
      await Directory(_dirname(targetPath)).create(recursive: true);
      final copied = await entity.copy(targetPath);
      if (!Platform.isWindows) {
        final mode = (await entity.stat()).mode & 0x1ff;
        final chmod = await Process.run('chmod', [
          mode.toRadixString(8).padLeft(3, '0'),
          copied.path,
        ]);
        if (chmod.exitCode != 0) {
          throw DesktopReviewArtifactException(
            'could not preserve payload file mode: '
            '${_boundedDiagnostic(chmod.stderr)}',
          );
        }
      }
    } else {
      throw DesktopReviewArtifactException(
        'desktop bundle contains an unsupported filesystem entity',
      );
    }
  }
}

Future<void> _createTarArchive({
  required Directory stagingParent,
  required String rootName,
  required File archive,
}) async {
  final result = await Process.run('tar', [
    '-czf',
    archive.absolute.path,
    '-C',
    stagingParent.absolute.path,
    rootName,
  ]);
  if (result.exitCode != 0 ||
      !await archive.exists() ||
      await archive.length() <= 0) {
    throw DesktopReviewArtifactException(
      'tar could not create the review artifact: '
      '${_boundedDiagnostic(result.stderr)}',
    );
  }
}

Future<void> _validateArchiveListing(File archive, String rootName) async {
  final result = await Process.run('tar', ['-tzf', archive.absolute.path]);
  if (result.exitCode != 0) {
    throw DesktopReviewArtifactException(
      'tar could not list the review artifact: '
      '${_boundedDiagnostic(result.stderr)}',
    );
  }
  final lines = '${result.stdout}'
      .split(RegExp(r'\r?\n'))
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    throw DesktopReviewArtifactException('review artifact archive is empty');
  }
  for (final line in lines) {
    if (line.contains('\\') ||
        line.startsWith('/') ||
        line.contains('\u0000')) {
      throw DesktopReviewArtifactException('archive contains an unsafe path');
    }
    final parts = line.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty ||
        parts.first != rootName ||
        parts.any((part) => part == '.' || part == '..')) {
      throw DesktopReviewArtifactException(
        'archive entry escapes or differs from the declared root',
      );
    }
  }
}

Future<void> _requireIdenticalFile(
  File expected,
  File actual,
  String label,
) async {
  if (!await expected.exists() || !await actual.exists()) {
    throw DesktopReviewArtifactException('$label is missing');
  }
  if (await expected.length() != await actual.length() ||
      await _sha256File(expected) != await _sha256File(actual)) {
    throw DesktopReviewArtifactException(
      '$label drifted from repository source',
    );
  }
}

Future<String> _sha256File(File file) async {
  if (!await file.exists()) {
    throw DesktopReviewArtifactException(
      'required file is missing: ${file.path}',
    );
  }
  return (await sha256.bind(file.openRead()).first).toString();
}

Future<void> _writeJson(File file, Map<String, Object?> value) async {
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
    flush: true,
  );
}

Future<Map<String, Object?>> _readJsonObject(File file) async {
  if (!await file.exists() || await file.length() > 4 * 1024 * 1024) {
    throw DesktopReviewArtifactException(
      'JSON metadata is missing or oversized',
    );
  }
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('not an object');
    }
    return decoded;
  } on FormatException {
    throw DesktopReviewArtifactException('JSON metadata is malformed');
  }
}

void _requireExact(Map<String, Object?> object, String key, Object? expected) {
  if (object[key] != expected) {
    throw DesktopReviewArtifactException('$key has an unexpected value');
  }
}

Map<String, Object?> _requiredObject(Map<String, Object?> object, String key) {
  final value = object[key];
  if (value is! Map<String, Object?>) {
    throw DesktopReviewArtifactException('$key is missing or malformed');
  }
  return value;
}

String _requiredString(Map<String, Object?> object, String key) {
  final value = object[key];
  if (value is! String || value.isEmpty) {
    throw DesktopReviewArtifactException('$key is missing or malformed');
  }
  return value;
}

String _requiredSafeBasename(Map<String, Object?> object, String key) {
  final value = _requiredString(object, key);
  if (value != _basename(value) ||
      value == '.' ||
      value == '..' ||
      value.contains('/') ||
      value.contains('\\')) {
    throw DesktopReviewArtifactException('$key is not a safe basename');
  }
  return value;
}

String _requiredSha256(Map<String, Object?> object, String key) {
  final value = _requiredString(object, key);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw DesktopReviewArtifactException('$key is not a SHA-256 digest');
  }
  return value;
}

int _requiredPositiveInt(Map<String, Object?> object, String key) {
  final value = object[key];
  if (value is! int || value <= 0) {
    throw DesktopReviewArtifactException('$key is not a positive integer');
  }
  return value;
}

void _validateManifestPath(String path) {
  final parts = path.split('/');
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains('\\') ||
      path.runes.any((rune) => rune < 0x20 || rune == 0x7f) ||
      parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw DesktopReviewArtifactException('payload contains an unsafe path');
  }
}

void _validateRelativeLink(String linkPath, String target) {
  if (target.isEmpty ||
      target.startsWith('/') ||
      target.startsWith('\\') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(target) ||
      target.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
    throw DesktopReviewArtifactException(
      'payload symlink is absolute or unsafe: $linkPath',
    );
  }
  final base = linkPath.split('/')..removeLast();
  for (final part in target.split(RegExp(r'[\\/]'))) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (base.isEmpty) {
        throw DesktopReviewArtifactException(
          'payload symlink escapes its root: $linkPath',
        );
      }
      base.removeLast();
    } else {
      base.add(part);
    }
  }
}

String _reviewOnlyText(
  DesktopArtifactPlatform platform,
  String sourceRevision,
) {
  final platformBoundary = switch (platform) {
    DesktopArtifactPlatform.linux => 'Linux distribution format, dependency compatibility, and installed-volume behavior have not been validated.',
    DesktopArtifactPlatform.windows => 'No Windows installer identity, code-signing identity, SmartScreen reputation, or installed ACL behavior is claimed.',
    DesktopArtifactPlatform.macos => 'No Developer ID identity, notarization ticket, stapling, or installed Gatekeeper behavior is claimed.',
  };
  return '''Codex Native Unofficial desktop review artifact

distributionReady=false
reviewOnly=true
sourceRevision=$sourceRevision

This archive exists for machine review of one release-mode desktop bundle. It
is not a production release and must not be presented as signed, notarized,
store-ready, installer-validated, or Human-accepted. $platformBoundary
''';
}

Map<String, Object?> _signingBoundary(DesktopArtifactPlatform platform) {
  return switch (platform) {
    DesktopArtifactPlatform.linux => <String, Object?>{
      'status': 'not_assessed',
      'claim': 'No package-manager or distribution signature is claimed.',
    },
    DesktopArtifactPlatform.windows => <String, Object?>{
      'status': 'not_code_signed_or_installer_validated',
      'claim': 'No Authenticode or installer identity is claimed.',
    },
    DesktopArtifactPlatform.macos => <String, Object?>{
      'status': 'developer_id_and_notarization_not_verified',
      'claim': 'Build-system ad-hoc signing, if present, is not Developer ID or notarization evidence.',
    },
  };
}

String _boundedDiagnostic(Object? value) {
  final text = '$value'.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  return text.length <= 512 ? text : '${text.substring(0, 512)}…';
}

String _resolveRelative(Directory root, String relativePath) {
  return relativePath
      .split('/')
      .fold(root.path, (current, part) => _join(current, part));
}

String _relativeNative(String root, String path) {
  final normalizedRoot = Directory(root).absolute.path;
  final normalizedPath = File(path).absolute.path;
  final prefix = normalizedRoot.endsWith(Platform.pathSeparator)
      ? normalizedRoot
      : '$normalizedRoot${Platform.pathSeparator}';
  if (!normalizedPath.startsWith(prefix)) {
    throw DesktopReviewArtifactException('filesystem entity escaped its root');
  }
  return normalizedPath.substring(prefix.length);
}

String _relativePosix(String root, String path) {
  return _relativeNative(root, path).split(Platform.pathSeparator).join('/');
}

String _join(String first, String second, [String? third]) {
  var result = first.endsWith(Platform.pathSeparator)
      ? '$first$second'
      : '$first${Platform.pathSeparator}$second';
  if (third != null) {
    result = result.endsWith(Platform.pathSeparator)
        ? '$result$third'
        : '$result${Platform.pathSeparator}$third';
  }
  return result;
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final withoutTrailing = normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
  return withoutTrailing.substring(withoutTrailing.lastIndexOf('/') + 1);
}

String _dirname(String path) {
  final separator = path.lastIndexOf(Platform.pathSeparator);
  if (separator < 0) {
    return '.';
  }
  return path.substring(0, separator);
}

final class _ApplicationMetadata {
  _ApplicationMetadata({required this.version, required this.buildNumber});

  final String version;
  final String? buildNumber;

  String get versionLabel =>
      buildNumber == null ? version : '$version+$buildNumber';
}
