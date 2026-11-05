import 'dart:io';

import 'src/linux_runtime_gate.dart';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length != 2 || arguments.first != '--bundle') {
      throw const FormatException(
        'usage: dart run tool/verify_linux_runtime_bundle.dart '
        '--bundle <directory>',
      );
    }
    final report = await verifyLinuxRuntimeBundle(Directory(arguments[1]));
    stdout.writeln('LINUX_RUNTIME_BUNDLE=PASS');
    stdout.writeln(
      'BUNDLED_RUNTIME_LIBRARIES=${report.bundleLibraries.join(',')}',
    );
    stdout.writeln(
      'SYSTEM_RUNTIME_LIBRARY_COUNT=${report.systemLibraries.length}',
    );
  } on Object catch (error) {
    stderr.writeln('LINUX_RUNTIME_BUNDLE=FAIL');
    stderr.writeln(error);
    exitCode = 1;
  }
}
