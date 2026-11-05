import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/remote_admin_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/remote_pairing_invitation.dart';
import 'package:codex_native_unofficial/src/protocol/remote_trust.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact desktop shell and setup stay overflow-free', (
    tester,
  ) async {
    await _pumpApp(tester, physicalSize: const Size(320, 720));

    expect(find.byKey(const ValueKey('compact-workspace')), findsOneWidget);
    final scrollbar = find.descendant(
      of: find.byKey(const ValueKey('compact-workspace')),
      matching: find.byType(Scrollbar),
    );
    expect(scrollbar, findsOneWidget);
    expect(tester.widget<Scrollbar>(scrollbar).thumbVisibility, isTrue);
    await tester.ensureVisible(find.text('Conversation'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('remote-setup-button')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
    await tester.pumpAndSettle();

    expect(find.text('Remote setup'), findsNWidgets(2));
    expect(find.textContaining('1 active'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trusted setup creates tickets only after affirmative action', (
    tester,
  ) async {
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final runtime = await _pumpApp(tester);

    expect(
      find.byKey(const ValueKey('desktop-split-workspace')),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const ValueKey('remote-ticket-invitation')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('remote-ticket-qr')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('remote-ticket-qr-unavailable')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('remote-copy-invitation-button')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Invitation copied'), findsOneWidget);
    expect(
      platformCalls.where((call) => call.method == 'Clipboard.setData'),
      hasLength(1),
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remote-ticket-card')), findsNothing);
    expect(runtime.createCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired tickets and QR projections leave the setup surface', (
    tester,
  ) async {
    final runtime = await _pumpApp(
      tester,
      ticketLifetime: const Duration(seconds: 1),
    );
    await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remote-create-ticket-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remote-ticket-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('remote-ticket-qr')), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.byKey(const ValueKey('remote-ticket-card')), findsNothing);
    expect(find.byKey(const ValueKey('remote-ticket-qr')), findsNothing);
    expect(
      find.byKey(const ValueKey('remote-ticket-expired-message')),
      findsOneWidget,
    );
    expect(runtime.createCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('oversized certificate invitations keep manual fallback', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      trust: RemoteCertificateTrust(List<int>.filled(3000, 0x41)),
    );
    await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remote-create-ticket-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remote-ticket-qr')), findsNothing);
    expect(
      find.byKey(const ValueKey('remote-ticket-qr-unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('remote-copy-invitation-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('constrained QR layouts preserve the manual fallback', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      trust: RemoteCertificateTrust(List<int>.filled(1100, 0x41)),
      physicalSize: const Size(620, 1000),
    );
    await tester.tap(find.byKey(const ValueKey('remote-setup-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remote-create-ticket-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remote-ticket-qr')), findsNothing);
    expect(
      find.byKey(const ValueKey('remote-ticket-qr-too-narrow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('remote-copy-invitation-button')),
      findsOneWidget,
    );
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
  RemoteTrust trust = const RemoteSystemTrust(),
  Duration ticketLifetime = const Duration(minutes: 5),
  Size physicalSize = const Size(1500, 1000),
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final runtime = _Runtime(
    endpoint: endpoint,
    trust: trust,
    ticketLifetime: ticketLifetime,
  );
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
  _Runtime({
    required this.endpoint,
    required this.trust,
    required this.ticketLifetime,
  });

  final String? endpoint;
  final RemoteTrust trust;
  final Duration ticketLifetime;
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
    pairingTrust: trust.kind == RemoteTrustKind.system
        ? RemotePairingTrustMode.system
        : RemotePairingTrustMode.certificate,
  );

  @override
  Future<RemotePairingTicket> createRemotePairingTicket() async {
    createCalls += 1;
    final actualEndpoint = endpoint ?? 'wss://host.example/v1/ws';
    final expiresAtMs =
        DateTime.now().millisecondsSinceEpoch + ticketLifetime.inMilliseconds;
    return RemotePairingTicket(
      invitation: RemotePairingInvitation(
        endpoint: Uri.parse(actualEndpoint),
        code: 'AAAAAAAAAAAAAAAAAAAAAAAA',
        expiresAtMs: expiresAtMs,
        trust: trust,
      ).encode(),
      expiresAtMs: expiresAtMs,
      endpoint: actualEndpoint,
      trust: trust.kind == RemoteTrustKind.system
          ? RemotePairingTrustMode.system
          : RemotePairingTrustMode.certificate,
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
