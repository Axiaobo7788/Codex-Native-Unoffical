import 'dart:io';

import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  final executableName = Platform.isWindows
      ? 'codex-native-host.exe'
      : 'codex-native-host';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('host-locator-test-');
  });

  tearDown(() => temp.delete(recursive: true));

  test('uses an existing explicit override first', () async {
    final override = File('${temp.path}${Platform.pathSeparator}custom-host');
    await override.writeAsString('fixture');
    final locator = HostExecutableLocator(
      environment: {'CODEX_NATIVE_HOST': override.path, 'PATH': ''},
      resolvedExecutable: '${temp.path}${Platform.pathSeparator}app',
      currentDirectory: temp.path,
    );

    expect(await locator.locate(), override.absolute.path);
  });

  test('finds the packaged executable beside the application', () async {
    final appDirectory = Directory(
      '${temp.path}${Platform.pathSeparator}bundle',
    );
    await appDirectory.create();
    final host = File(
      '${appDirectory.path}${Platform.pathSeparator}$executableName',
    );
    await host.writeAsString('fixture');
    final locator = HostExecutableLocator(
      environment: const {'PATH': ''},
      resolvedExecutable:
          '${appDirectory.path}${Platform.pathSeparator}application',
      currentDirectory: temp.path,
    );

    expect(await locator.locate(), host.path);
  });

  test(
    'finds release and debug development builds without a fallback',
    () async {
      final releaseDirectory = Directory(
        '${temp.path}${Platform.pathSeparator}target'
        '${Platform.pathSeparator}release',
      );
      await releaseDirectory.create(recursive: true);
      final host = File(
        '${releaseDirectory.path}${Platform.pathSeparator}$executableName',
      );
      await host.writeAsString('fixture');
      final locator = HostExecutableLocator(
        environment: const {'PATH': ''},
        resolvedExecutable:
            '${temp.path}${Platform.pathSeparator}missing-application',
        currentDirectory: temp.path,
      );

      expect(await locator.locate(), host.path);
      await host.delete();
      expect(await locator.locate(), isNull);
    },
  );
}
