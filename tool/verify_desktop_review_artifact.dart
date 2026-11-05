import 'dart:io';

import 'src/desktop_review_artifact.dart';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length != 2 ||
        (arguments.first != '--provenance' &&
            arguments.first != '--directory')) {
      throw const FormatException(
        'usage: dart run tool/verify_desktop_review_artifact.dart '
        '(--provenance <file> | --directory <directory>)',
      );
    }
    final provenance = arguments.first == '--provenance'
        ? File(arguments[1])
        : await _findProvenance(Directory(arguments[1]));
    await verifyDesktopReviewArtifact(provenance);
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
