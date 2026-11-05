import 'dart:async';

import 'package:codex_native_unofficial/src/domain/remote_admin_gateway.dart';
import 'package:codex_native_unofficial/src/domain/remote_admin_models.dart';
import 'package:codex_native_unofficial/src/features/settings/remote_admin_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not create a ticket until the user requests one', () async {
    final gateway = _Gateway();
    final controller = RemoteAdminController(
      gateway: gateway,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.phase, RemoteAdminPhase.ready);
    expect(controller.ticket, isNull);
    expect(gateway.createCalls, 0);

    await controller.createPairingTicket();

    expect(gateway.createCalls, 1);
    expect(controller.ticket?.code, 'AAAAAAAAAAAAAAAAAAAAAAAA');
  });

  test('missing advertised endpoint disables invitation creation', () async {
    final gateway = _Gateway(endpoint: null);
    final controller = RemoteAdminController(gateway: gateway);
    addTearDown(controller.dispose);

    await controller.refresh();
    await controller.createPairingTicket();

    expect(controller.canCreatePairingTicket, isFalse);
    expect(gateway.createCalls, 0);
    expect(controller.ticket, isNull);
  });

  test('ticket must match current status and be unexpired', () async {
    final gateway = _Gateway(ticketEndpoint: 'wss://different.example/v1/ws');
    final controller = RemoteAdminController(
      gateway: gateway,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    await controller.createPairingTicket();

    expect(controller.ticket, isNull);
    expect(controller.phase, RemoteAdminPhase.failed);
    expect(controller.errorMessage, contains('current one-use'));
    expect(controller.errorMessage, isNot(contains('different.example')));
  });

  test('revocation reads back authoritative device state', () async {
    final gateway = _Gateway();
    final controller = RemoteAdminController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.refresh();

    await controller.revokeDevice(controller.devices.single);

    expect(gateway.revokeCalls, 1);
    expect(gateway.listCalls, 2);
    expect(controller.devices.single.isRevoked, isTrue);
    expect(controller.phase, RemoteAdminPhase.ready);
  });

  test('failed refresh does not leave stale devices actionable', () async {
    final gateway = _Gateway();
    final controller = RemoteAdminController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.devices, isNotEmpty);

    gateway.failList = true;
    await controller.refresh();

    expect(controller.phase, RemoteAdminPhase.failed);
    expect(controller.devices, isEmpty);
    expect(controller.canRevokeDevices, isFalse);
  });

  test('disposed controller ignores a late Host result', () async {
    final gateway = _Gateway();
    final pending = Completer<RemoteHostStatus>();
    gateway.pendingStatus = pending;
    final controller = RemoteAdminController(gateway: gateway);

    final refresh = controller.refresh();
    controller.dispose();
    pending.complete(gateway.status);
    await refresh;

    expect(controller.status, isNull);
    expect(gateway.listCalls, 0);
  });
}

final class _Gateway implements RemoteAdminGateway {
  _Gateway({this.endpoint = 'wss://host.example/v1/ws', String? ticketEndpoint})
    : ticketEndpoint = ticketEndpoint ?? endpoint;

  final String? endpoint;
  final String? ticketEndpoint;
  var createCalls = 0;
  var listCalls = 0;
  var revokeCalls = 0;
  var revoked = false;
  var failList = false;
  Completer<RemoteHostStatus>? pendingStatus;

  RemoteHostStatus get status => RemoteHostStatus(
    hostVersion: '0.1.0',
    enabled: true,
    bindAddress: '0.0.0.0:4317',
    tls: true,
    scope: RemoteListenerScope.network,
    advertisedEndpoint: endpoint,
  );

  @override
  Future<RemoteHostStatus> readRemoteAdminStatus() =>
      pendingStatus?.future ?? Future.value(status);

  @override
  Future<RemotePairingTicket> createRemotePairingTicket() async {
    createCalls += 1;
    return RemotePairingTicket(
      code: 'AAAAAAAAAAAAAAAAAAAAAAAA',
      expiresAtMs: 5000,
      endpoint: ticketEndpoint,
    );
  }

  @override
  Future<List<RemotePairedDevice>> listRemotePairedDevices() async {
    listCalls += 1;
    if (failList) {
      throw StateError('fixture list failure');
    }
    return [
      RemotePairedDevice(
        id: 'AAAAAAAAAAAAAAAAAAAAAA',
        name: 'Test phone',
        scopes: const {RemoteDeviceScope.read, RemoteDeviceScope.deviceRotate},
        createdAtMs: 1000,
        expiresAtMs: 9000000000000,
        lastSeenAtMs: null,
        rotatedAtMs: null,
        revokedAtMs: revoked ? 2000 : null,
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
