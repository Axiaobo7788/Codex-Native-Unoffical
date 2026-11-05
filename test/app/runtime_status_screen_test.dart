import 'dart:io';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a typed Codex-not-found runtime state', (tester) async {
    final controller = RuntimeController(
      locator: const CodexExecutableLocator(environment: {'PATH': ''}),
    );
    addTearDown(controller.dispose);

    await tester.runAsync(controller.start);
    await tester.pumpWidget(CodexNativeApp(runtimeController: controller));
    await tester.pump();

    expect(find.text('Codex Native'), findsOneWidget);
    expect(find.text('Codex not found'), findsOneWidget);
    expect(find.textContaining('CODEX_EXECUTABLE'), findsOneWidget);
  });

  test('does not silently bypass a missing native Host', () async {
    final temp = await Directory.systemTemp.createTemp('missing-host-test-');
    final codex = File('${temp.path}${Platform.pathSeparator}codex');
    await codex.writeAsString('fixture');
    final controller = RuntimeController(
      locator: CodexExecutableLocator(
        environment: {'CODEX_EXECUTABLE': codex.path, 'PATH': ''},
      ),
      hostLocator: HostExecutableLocator(
        environment: const {'PATH': ''},
        resolvedExecutable:
            '${temp.path}${Platform.pathSeparator}missing-application',
        currentDirectory: temp.path,
      ),
    );
    try {
      await controller.start();
      expect(controller.snapshot.state, RuntimeConnectionState.hostNotFound);
      expect(controller.snapshot.stateLabel, 'Native Host not found');
      expect(
        controller.snapshot.message,
        contains('Direct app-server fallback is disabled'),
      );
    } finally {
      await controller.shutdown();
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });
}
