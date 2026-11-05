import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/remote_admin_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trusted setup creates tickets only after affirmative action', (
    tester,
  ) async {
    final runtime = await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
    await tester.pumpAndSettle();

    expect(find.text('Remote setup'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('remote-advertised-endpoint')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('remote-ticket-card')), findsNothing);
    expect(runtime.createCalls, 0);

    await tester.tap(find.byKey(const ValueKey('remote-create-ticket-button')));
    await tester.pumpAndSettle();

    expect(runtime.createCalls, 1);
    expect(find.byKey(const ValueKey('remote-ticket-card')), findsOneWidget);
    expect(find.text('AAAAAAAAAAAAAAAAAAAAAAAA'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remote-ticket-card')), findsNothing);
    expect(runtime.createCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('device revocation requires confirmation and reads back state', (
    tester,
  ) async {
    final runtime = await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Revoke'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke paired device?'), findsOneWidget);
    expect(runtime.revokeCalls, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(runtime.revokeCalls, 0);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Revoke'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('remote-confirm-revoke-button')),
    );
    await tester.pumpAndSettle();

    expect(runtime.revokeCalls, 1);
    expect(runtime.listCalls, 2);
    expect(find.textContaining('Revoked '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing advertised endpoint is reported and blocks tickets', (
    tester,
  ) async {
    final runtime = await _pumpApp(tester, endpoint: null);
    await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('remote-advertised-endpoint-missing')),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('remote-create-ticket-button')),
    );
    expect(button.onPressed, isNull);
    expect(runtime.createCalls, 0);
  });
}

Future<_Runtime> _pumpApp(
  WidgetTester tester, {
  String? endpoint = 'wss://host.example/v1/ws',
}) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final runtime = _Runtime(endpoint: endpoint);
  addTearDown(() async {
    await runtime.shutdown();
    runtime.dispose();
  });
  await tester.pumpWidget(
    CodexNativeApp(runtimeController: runtime, shutdownHandler: () async {}),
  );
  await tester.pumpAndSettle();
  return runtime;
}

final class _Runtime extends RuntimeController {
  _Runtime({required this.endpoint});

  final String? endpoint;
  var createCalls = 0;
  var listCalls = 0;
  var revokeCalls = 0;
  var revoked = false;

  @override
  RuntimeSnapshot get snapshot => const RuntimeSnapshot(
    state: RuntimeConnectionState.connected,
    executablePath: '/usr/bin/codex',
    userAgent: 'test-app-server',
    processId: 42,
  );

  @override
  Future<void> start() async => notifyListeners();

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) async =>
      const ThreadPage(threads: [], nextCursor: null);

  @override
  Future<ModelPage> listModels(ModelListQuery query) async =>
      const ModelPage(models: [], nextCursor: null);

  @override
  Future<RemoteHostStatus> readRemoteAdminStatus() async => RemoteHostStatus(
    hostVersion: '0.1.0',
    enabled: true,
    bindAddress: '0.0.0.0:4317',
    tls: true,
    scope: RemoteListenerScope.network,
    advertisedEndpoint: endpoint,
  );

  @override
  Future<RemotePairingTicket> createRemotePairingTicket() async {
    createCalls += 1;
    return RemotePairingTicket(
      code: 'AAAAAAAAAAAAAAAAAAAAAAAA',
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + 300000,
      endpoint: endpoint,
    );
  }

  @override
  Future<List<RemotePairedDevice>> listRemotePairedDevices() async {
    listCalls += 1;
    return [
      RemotePairedDevice(
        id: 'AAAAAAAAAAAAAAAAAAAAAA',
        name: 'Test phone',
        scopes: const {RemoteDeviceScope.read, RemoteDeviceScope.deviceRotate},
        createdAtMs: 1000,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 300000,
        lastSeenAtMs: null,
        rotatedAtMs: null,
        revokedAtMs: revoked ? DateTime.now().millisecondsSinceEpoch : null,
      ),
    ];
  }

  @override
  Future<bool> revokeRemotePairedDevice(String deviceId) async {
    revokeCalls += 1;
    revoked = true;
    return true;
  }
}
