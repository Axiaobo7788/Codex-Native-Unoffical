import 'dart:convert';
import 'dart:io';

// Platform storage is used by Android onboarding. It is not a root of the
// pure-Dart probe. If a pure root imports it, compilation still fails.
const _platformStorage = 'src/transport/remote/remote_secure_storage.dart';

Future<void> main() async {
  final scratch = await Directory.systemTemp.createTemp(
    'native-dart-boundary-',
  );
  try {
    final lib = Directory('lib').absolute.uri;
    final packageConfig = File('.dart_tool/package_config.json').absolute;
    final roots = <String>[];
    for (final boundary in ['domain', 'protocol', 'transport']) {
      final directory = Directory.fromUri(lib.resolve('src/$boundary/'));
      await for (final file in directory.list(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) {
          continue;
        }
        final path = file.uri.path.substring(lib.path.length);
        if (path != _platformStorage) {
          roots.add(path);
        }
      }
    }
    roots.sort();

    // The standalone Dart front end resolves the transitive VM import graph.
    // A Flutter dependency that reaches dart:ui cannot compile in this target.
    final probe = File.fromUri(scratch.uri.resolve('probe.dart'));
    final depfile = File.fromUri(scratch.uri.resolve('probe.d'));
    await probe.writeAsString(
      [
        for (final path in roots)
          'import "package:codex_native_unofficial/$path";',
        'void main() {}',
      ].join('\n'),
    );
    final result = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      '--packages=${packageConfig.path}',
      '--output=${scratch.uri.resolve('probe.dill').toFilePath()}',
      '--depfile=${depfile.path}',
      probe.path,
    ]);
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      exitCode = result.exitCode;
    } else {
      // Also catch an import of a Flutter library that happens to compile in
      // the VM today. The Ninja depfile escapes spaces in physical paths.
      final config = jsonDecode(await packageConfig.readAsString()) as Map;
      final flutter = (config['packages'] as List).cast<Map>().singleWhere(
        (package) => package['name'] == 'flutter',
      );
      final root = flutter['rootUri'] as String;
      final flutterLib = packageConfig.uri
          .resolve(root.endsWith('/') ? root : '$root/')
          .resolve(flutter['packageUri'] as String)
          .toFilePath()
          .replaceAll(' ', r'\ ');
      if ((await depfile.readAsString()).contains(flutterLib)) {
        stderr.writeln('The standalone VM probe depends on package:flutter.');
        exitCode = 1;
      }
    }
    stdout.writeln(
      'PURE_DART_BOUNDARY=${exitCode == 0 ? 'PASS' : 'FAIL'} '
      '(roots=${roots.length})',
    );
  } finally {
    await scratch.delete(recursive: true);
  }
}
