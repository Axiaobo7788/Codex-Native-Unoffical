import 'package:codex_native_unofficial/src/domain/remote_admin_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/remote_admin_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses explicit listener state and one-use ticket', () async {
    final requests = <String>[];
    final adapter = RemoteAdminProtocolAdapter(
      request: (method, [params = const {}]) async {
        requests.add(method);
        return switch (method) {
          'host/status' => _hostStatus(
            endpoint: 'wss://host.example:4317/v1/ws',
          ),
          'host/remote/pairing/create' => {
            'code': 'AAAAAAAAAAAAAAAAAAAAAAAA',
            'expiresAt': 5000,
            'endpoint': 'wss://host.example:4317/v1/ws',
          },
          _ => throw StateError(method),
        };
      },
    );

    final status = await adapter.status();
    final ticket = await adapter.createPairingTicket();

    expect(status.enabled, isTrue);
    expect(status.scope, RemoteListenerScope.network);
    expect(status.tls, isTrue);
    expect(status.canCreatePairingTicket, isTrue);
    expect(status.advertisedEndpoint, 'wss://host.example:4317/v1/ws');
    expect(ticket.code, 'AAAAAAAAAAAAAAAAAAAAAAAA');
    expect(ticket.endpoint, status.advertisedEndpoint);
    expect(ticket.toString(), isNot(contains(ticket.code)));
    expect(status.toString(), isNot(contains('host.example')));
    expect(requests, ['host/status', 'host/remote/pairing/create']);
  });

  test('disabled listener has no inferred invitation endpoint', () async {
    final adapter = RemoteAdminProtocolAdapter(
      request: (_, [params = const {}]) async => {
        'version': '0.1.0',
        'maxOutputBytes': 1,
        'maxSessionBytes': 2,
        'maxReadBytes': 1,
        'remote': {'enabled': false},
      },
    );

    final status = await adapter.status();

    expect(status.enabled, isFalse);
    expect(status.advertisedEndpoint, isNull);
    expect(status.canCreatePairingTicket, isFalse);
  });

  test('rejects malformed or non-client advertised endpoints', () async {
    for (final endpoint in <Object?>[
      'ws://host.example/v1/ws',
      'wss://host.example/v1/pair',
      'wss://host.example/v1/ws?ticket=secret',
      'wss://user@host.example/v1/ws',
      'wss://host.example:invalid/v1/ws',
      'wss://0.0.0.0/v1/ws',
      'wss://[::]/v1/ws',
      '',
      7,
    ]) {
      final adapter = RemoteAdminProtocolAdapter(
        request: (_, [params = const {}]) async =>
            _hostStatus(endpoint: endpoint),
      );

      await expectLater(adapter.status(), throwsA(isA<ProtocolViolation>()));
    }
  });

  test('parses bounded public device metadata and revoke result', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final adapter = RemoteAdminProtocolAdapter(
      request: (method, [params = const {}]) async {
        calls.add((method, params));
        if (method == 'host/remote/devices/revoke') {
          return {'revoked': true};
        }
        return {
          'devices': [_device()],
        };
      },
    );

    final devices = await adapter.listDevices();
    final revoked = await adapter.revokeDevice(devices.single.id);

    expect(devices.single.name, 'Test phone');
    expect(devices.single.scopes, {
      RemoteDeviceScope.read,
      RemoteDeviceScope.deviceRotate,
    });
    expect(devices.single.toString(), isNot(contains(devices.single.id)));
    expect(revoked, isTrue);
    expect(calls.last.$2, {'deviceId': 'AAAAAAAAAAAAAAAAAAAAAA'});
  });

  test('rejects duplicate IDs, oversized lists, and unknown scopes', () async {
    for (final devices in <List<Object?>>[
      [_device(), _device()],
      [for (var index = 0; index < 33; index += 1) _device()],
      [
        _device(scopes: ['read', 'superuser']),
      ],
    ]) {
      final adapter = RemoteAdminProtocolAdapter(
        request: (_, [params = const {}]) async => {'devices': devices},
      );

      await expectLater(
        adapter.listDevices(),
        throwsA(isA<ProtocolViolation>()),
      );
    }
  });

  test(
    'rejects Host response shape drift rather than retaining secrets',
    () async {
      final adapter = RemoteAdminProtocolAdapter(
        request: (_, [params = const {}]) async => {
          'code': 'AAAAAAAAAAAAAAAAAAAAAAAA',
          'expiresAt': 5000,
          'endpoint': 'wss://host.example/v1/ws',
          'bearer': 'must-not-enter-desktop-state',
        },
      );

      await expectLater(
        adapter.createPairingTicket(),
        throwsA(isA<ProtocolViolation>()),
      );
    },
  );
}

Map<String, Object?> _hostStatus({required Object? endpoint}) => {
  'version': '0.1.0',
  'maxOutputBytes': 1024,
  'maxSessionBytes': 2048,
  'maxReadBytes': 256,
  'remote': {
    'enabled': true,
    'address': '0.0.0.0:4317',
    'tls': true,
    'scope': 'network',
    'advertisedEndpoint': endpoint,
  },
};

Map<String, Object?> _device({List<String>? scopes}) => {
  'id': 'AAAAAAAAAAAAAAAAAAAAAA',
  'name': 'Test phone',
  'scopes': scopes ?? ['read', 'device_rotate'],
  'createdAtMs': 1000,
  'expiresAtMs': 9000,
  'lastSeenAtMs': null,
  'rotatedAtMs': null,
  'revokedAtMs': null,
};
