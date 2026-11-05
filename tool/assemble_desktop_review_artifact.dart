import 'dart:io';

import 'src/desktop_review_artifact.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseOptions(arguments);
    final result = await assembleDesktopReviewArtifact(
      DesktopReviewArtifactConfig(
        repositoryRoot: Directory(options['repository-root'] ?? '.'),
        bundleDirectory: Directory(_required(options, 'bundle')),
        outputDirectory: Directory(_required(options, 'output')),
        platform: DesktopArtifactPlatform.parse(_required(options, 'platform')),
        architecture: _required(options, 'architecture'),
        sourceRevision: _required(options, 'source-revision'),
        sourceTreeState: _required(options, 'source-tree-state'),
        flutterVersion: _required(options, 'flutter-version'),
        rustVersion: _required(options, 'rust-version'),
        buildOrigin: _required(options, 'build-origin'),
      ),
    );
    stdout.writeln('DESKTOP_REVIEW_ARTIFACT=PASS');
    stdout.writeln('ARCHIVE=${result.archive.path}');
    stdout.writeln('ARCHIVE_SHA256=${result.archiveSha256}');
    stdout.writeln('PROVENANCE=${result.provenance.path}');
  } on Object catch (error) {
    stderr.writeln('DESKTOP_REVIEW_ARTIFACT=FAIL');
    stderr.writeln(error);
    exitCode = 1;
  }
}

Map<String, String> _parseOptions(List<String> arguments) {
  if (arguments.length.isOdd) {
    throw const FormatException('every option must have a value');
  }
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final option = arguments[index];
    if (!option.startsWith('--') || option.length == 2) {
      throw FormatException('invalid option: $option');
    }
    final name = option.substring(2);
    if (result.containsKey(name)) {
      throw FormatException('duplicate option: $option');
    }
    result[name] = arguments[index + 1];
  }
  const allowed = {
    'repository-root',
    'bundle',
    'output',
    'platform',
    'architecture',
    'source-revision',
    'source-tree-state',
    'flutter-version',
    'rust-version',
    'build-origin',
  };
  final unknown = result.keys.toSet().difference(allowed);
  if (unknown.isNotEmpty) {
    throw FormatException('unknown option: --${unknown.first}');
  }
  return result;
}

String _required(Map<String, String> options, String name) {
  final value = options[name];
  if (value == null || value.isEmpty) {
    throw FormatException('missing required option: --$name');
  }
  return value;
}
