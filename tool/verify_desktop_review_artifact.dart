import 'dart:io';

import 'src/desktop_review_artifact.dart';

Future<void> main(List<String> arguments) async {
  try {
    final nativeRuntimeCount = arguments
        .where((argument) => argument == '--native-runtime')
        .length;
    if (nativeRuntimeCount > 1) {
      throw const FormatException('--native-runtime may be supplied once');
    }
    final verifyNativeRuntime = nativeRuntimeCount == 1;
    final selectorArguments = arguments
        .where((argument) => argument != '--native-runtime')
        .toList();
    if (selectorArguments.length != 2 ||
        (selectorArguments.first != '--provenance' &&
            selectorArguments.first != '--directory')) {
      throw const FormatException(
        'usage: dart run tool/verify_desktop_review_artifact.dart '
        '(--provenance <file> | --directory <directory>) '
        '[--native-runtime]',
      );
    }
    final provenance = selectorArguments.first == '--provenance'
        ? File(selectorArguments[1])
        : await _findProvenance(Directory(selectorArguments[1]));
    await verifyDesktopReviewArtifact(
      provenance,
      verifyNativeRuntime: verifyNativeRuntime,
    );
    stdout.writeln('DESKTOP_REVIEW_ARTIFACT_VERIFY=PASS');
  } on Object catch (error) {
    stderr.writeln('DESKTOP_REVIEW_ARTIFACT_VERIFY=FAIL');
    stderr.writeln(error);
    exitCode = 1;
  }
}

Future<File> _findProvenance(Directory directory) async {
  if (!await directory.exists()) {
    throw const FormatException('artifact directory does not exist');
  }
  final files = await directory
      .list(followLinks: false)
      .where(
        (entity) => entity is File && entity.path.endsWith('.provenance.json'),
      )
      .cast<File>()
      .toList();
  if (files.length != 1) {
    throw const FormatException(
      'artifact directory must contain exactly one provenance JSON file',
    );
  }
  return files.single;
}
