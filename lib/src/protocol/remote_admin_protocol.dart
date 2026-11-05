import '../domain/remote_admin_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';

const _maximumEndpointCharacters = 2048;
const _maximumDeviceNameCharacters = 80;
const _maximumTimestamp = 8640000000000000;
const _maximumDevices = 32;

final class RemoteAdminProtocolAdapter {
  const RemoteAdminProtocolAdapter({required this.request});

  final ProtocolRequest request;

  Future<RemoteHostStatus> status() async {
    final response = await request('host/status');
    _requireExactKeys(response, const {
      'version',
      'maxOutputBytes',
      'maxSessionBytes',
      'maxReadBytes',
      'remote',
    });
    final version = _boundedString(response, 'version', maximumCharacters: 64);
    for (final key in const [
      'maxOutputBytes',
      'maxSessionBytes',
      'maxReadBytes',
    ]) {
      _positiveInt(response, key);
    }
    final remote = response['remote'];
    if (remote is! Map<String, Object?>) {
      throw const ProtocolViolation('Host Remote status must be an object.');
    }
    final enabled = remote['enabled'];
    if (enabled is! bool) {
      throw const ProtocolViolation(
        'Host Remote enabled status must be a boolean.',
      );
    }
    if (!enabled) {
      _requireExactKeys(remote, const {'enabled'});
      return RemoteHostStatus(hostVersion: version, enabled: false);
    }

    _requireExactKeys(remote, const {
      'enabled',
      'address',
      'tls',
      'scope',
      'advertisedEndpoint',
    });
    final tls = remote['tls'];
    if (tls is! bool) {
      throw const ProtocolViolation('Host Remote TLS status must be boolean.');
    }
    final scope = switch (remote['scope']) {
      'loopback' => RemoteListenerScope.loopback,
      'network' => RemoteListenerScope.network,
      _ => throw const ProtocolViolation(
        'Host Remote listener scope is unsupported.',
      ),
    };
    final endpoint = _optionalEndpoint(remote, 'advertisedEndpoint');
    return RemoteHostStatus(
      hostVersion: version,
      enabled: true,
      bindAddress: _boundedString(remote, 'address', maximumCharacters: 128),
      tls: tls,
      scope: scope,
      advertisedEndpoint: endpoint,
    );
  }

  Future<RemotePairingTicket> createPairingTicket() async {
    final response = await request('host/remote/pairing/create');
    _requireExactKeys(response, const {'code', 'expiresAt', 'endpoint'});
    final code = _boundedString(response, 'code', maximumCharacters: 24);
    if (!_isUrlSafe(code, exactLength: 24)) {
      throw const ProtocolViolation('Host pairing ticket is malformed.');
    }
    return RemotePairingTicket(
      code: code,
      expiresAtMs: _timestamp(response, 'expiresAt'),
      endpoint: _optionalEndpoint(response, 'endpoint'),
    );
  }

  Future<List<RemotePairedDevice>> listDevices() async {
    final response = await request('host/remote/devices/list');
    _requireExactKeys(response, const {'devices'});
    final rawDevices = response['devices'];
    if (rawDevices is! List<Object?> || rawDevices.length > _maximumDevices) {
      throw const ProtocolViolation(
        'Host paired-device list exceeds its bound.',
      );
    }
    final ids = <String>{};
    final devices = <RemotePairedDevice>[];
    for (final rawDevice in rawDevices) {
      final device = _device(rawDevice);
      if (!ids.add(device.id)) {
        throw const ProtocolViolation(
          'Host paired-device list contains duplicate IDs.',
        );
      }
      devices.add(device);
    }
    return List.unmodifiable(devices);
  }

  Future<bool> revokeDevice(String deviceId) async {
    if (!_isUrlSafe(deviceId, exactLength: 22)) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Invalid device ID.');
    }
    final response = await request('host/remote/devices/revoke', {
      'deviceId': deviceId,
    });
    _requireExactKeys(response, const {'revoked'});
    final revoked = response['revoked'];
    if (revoked is! bool) {
      throw const ProtocolViolation(
        'Host device revocation result must be a boolean.',
      );
    }
    return revoked;
  }

  static RemotePairedDevice _device(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation('Host paired device must be an object.');
    }
    _requireExactKeys(value, const {
      'id',
      'name',
      'scopes',
      'createdAtMs',
      'expiresAtMs',
      'lastSeenAtMs',
      'rotatedAtMs',
      'revokedAtMs',
    });
    final id = _boundedString(value, 'id', maximumCharacters: 22);
    if (!_isUrlSafe(id, exactLength: 22)) {
      throw const ProtocolViolation('Host paired-device ID is malformed.');
    }
    final name = _boundedString(
      value,
      'name',
      maximumCharacters: _maximumDeviceNameCharacters,
    );
    if (name != name.trim() || name.runes.any(_isControlCharacter)) {
      throw const ProtocolViolation('Host paired-device name is malformed.');
    }
    final rawScopes = value['scopes'];
    if (rawScopes is! List<Object?> ||
        rawScopes.isEmpty ||
        rawScopes.length > RemoteDeviceScope.values.length) {
      throw const ProtocolViolation('Host device scopes are malformed.');
    }
    final scopes = <RemoteDeviceScope>{};
    for (final rawScope in rawScopes) {
      final scope = switch (rawScope) {
        'read' => RemoteDeviceScope.read,
        'write' => RemoteDeviceScope.write,
        'approvals_respond' => RemoteDeviceScope.approvalsRespond,
        'device_rotate' => RemoteDeviceScope.deviceRotate,
        _ => throw const ProtocolViolation('Host device scope is unknown.'),
      };
      if (!scopes.add(scope)) {
        throw const ProtocolViolation('Host device scope is duplicated.');
      }
    }
    final createdAtMs = _timestamp(value, 'createdAtMs');
    final expiresAtMs = _timestamp(value, 'expiresAtMs');
    if (expiresAtMs <= createdAtMs) {
      throw const ProtocolViolation('Host device expiry is inconsistent.');
    }
    return RemotePairedDevice(
      id: id,
      name: name,
      scopes: Set.unmodifiable(scopes),
      createdAtMs: createdAtMs,
      expiresAtMs: expiresAtMs,
      lastSeenAtMs: _optionalTimestamp(value, 'lastSeenAtMs'),
      rotatedAtMs: _optionalTimestamp(value, 'rotatedAtMs'),
      revokedAtMs: _optionalTimestamp(value, 'revokedAtMs'),
    );
  }
}

void _requireExactKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.length != expected.length || !value.keys.every(expected.contains)) {
    throw const ProtocolViolation('Host Remote response shape is unsupported.');
  }
}

String _boundedString(
  JsonObject value,
  String key, {
  required int maximumCharacters,
}) {
  final field = value[key];
  if (field is! String ||
      field.isEmpty ||
      field.runes.length > maximumCharacters) {
    throw ProtocolViolation('Host Remote field $key is malformed.');
  }
  return field;
}

int _positiveInt(JsonObject value, String key) {
  final field = value[key];
  if (field is! int || field <= 0) {
    throw ProtocolViolation('Host Remote field $key must be positive.');
  }
  return field;
}

int _timestamp(JsonObject value, String key) {
  final field = value[key];
  if (field is! int || field < 0 || field > _maximumTimestamp) {
    throw ProtocolViolation('Host Remote timestamp $key is malformed.');
  }
  return field;
}

int? _optionalTimestamp(JsonObject value, String key) {
  final field = value[key];
  if (field == null) {
    return null;
  }
  return _timestamp(value, key);
}

String? _optionalEndpoint(JsonObject value, String key) {
  final field = value[key];
  if (field == null) {
    return null;
  }
  if (field is! String || field.runes.length > _maximumEndpointCharacters) {
    throw const ProtocolViolation('Host advertised endpoint is malformed.');
  }
  final uri = Uri.tryParse(field);
  try {
    if (uri == null ||
        uri.scheme != 'wss' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.path != '/v1/ws' ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port == 0) ||
        uri.toString() != field ||
        _isUnspecifiedAddress(uri.host)) {
      throw const FormatException();
    }
  } on FormatException {
    throw const ProtocolViolation('Host advertised endpoint is malformed.');
  }
  return field;
}

bool _isUnspecifiedAddress(String host) =>
    host == '0.0.0.0' || host == '::' || host == '0:0:0:0:0:0:0:0';

bool _isControlCharacter(int rune) => rune < 0x20 || rune == 0x7f;

bool _isUrlSafe(String value, {required int exactLength}) =>
    value.length == exactLength &&
    value.codeUnits.every(
      (unit) =>
          unit >= 0x30 && unit <= 0x39 ||
          unit >= 0x41 && unit <= 0x5a ||
          unit >= 0x61 && unit <= 0x7a ||
          unit == 0x2d ||
          unit == 0x5f,
    );
