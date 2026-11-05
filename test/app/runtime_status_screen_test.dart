import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a typed Codex-not-found runtime state', (tester) async {
    final controller = RuntimeController(
      locator: const CodexExecutableLocator(environment: {'PATH': ''}),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(CodexNativeApp(runtimeController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Codex Native'), findsOneWidget);
    expect(find.text('Codex not found'), findsOneWidget);
    expect(find.textContaining('CODEX_EXECUTABLE'), findsOneWidget);
  });
}
