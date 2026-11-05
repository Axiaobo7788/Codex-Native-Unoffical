import 'dart:async';
import 'dart:convert';

import '../../protocol/remote_trust.dart';
import 'remote_protocol.dart';

const _recordVersion = 2;
const _maxRecordBytes = 24 * 1024;
const _maxEndpointLength = 2048;
const _maxDeviceIdLength = 128;
const _maxDeviceNameCharacters = 80;

final class RemoteCredentialRecord {
  factory RemoteCredentialRecord({
    required Uri endpoint,
    required String credential,
    required String deviceId,
    required String deviceName,
    RemoteTrust trust = const RemoteSystemTrust(),
  }) {
    _validateEndpoint(endpoint);
    validateRemoteCredential(credential);
    _validateText(
      deviceId,
      field: 'device ID',
      maximumCharacters: _maxDeviceIdLength,
    );
    _validateText(
      deviceName,
      field: 'device name',
      maximumCharacters: _maxDeviceNameCharacters,
    );
    return RemoteCredentialRecord._(
      endpoint: endpoint,
      credential: credential,
      deviceId: deviceId,
      deviceName: deviceName,
      trust: trust,
    );
  }

  const RemoteCredentialRecord._({
    required this.endpoint,
    required this.credential,
    required this.deviceId,
    required this.deviceName,
    required this.trust,
  });

  factory RemoteCredentialRecord.decode(String encoded) {
    try {
      if (encoded.length > _maxRecordBytes ||
          utf8.encode(encoded).length > _maxRecordBytes) {
        throw const FormatException();
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException();
      }
      _requireExactKeys(decoded, const {
        'version',
        'endpoint',
        'credential',
        'device',
        'trust',
      });
      final version = decoded['version'];
      if (version != 1 && version != _recordVersion) {
        throw const FormatException();
      }
      final endpointText = decoded['endpoint'];
      final credential = decoded['credential'];
      final device = decoded['device'];
      final trust = decoded['trust'];
      if (endpointText is! String ||
          endpointText.isEmpty ||
          endpointText.length > _maxEndpointLength ||
          credential is! String ||
          device is! Map<String, Object?> ||
          trust is! Map<String, Object?>) {
        throw const FormatException();
      }
      _requireExactKeys(device, const {'id', 'name'});
      final deviceId = device['id'];
      final deviceName = device['name'];
      if (deviceId is! String || deviceName is! String) {
        throw const FormatException();
      }
      final decodedTrust = RemoteTrust.decode(trust);
      if (version == 1 && decodedTrust.kind != RemoteTrustKind.system) {
        throw const FormatException();
      }
      final endpoint = Uri.tryParse(endpointText);
      if (endpoint == null) {
        throw const FormatException();
      }
      return RemoteCredentialRecord(
        endpoint: endpoint,
        credential: credential,
        deviceId: deviceId,
        deviceName: deviceName,
        trust: decodedTrust,
      );
    } on Object {
      throw const FormatException(
        'Saved Remote credential record is invalid; details were redacted.',
      );
    }
  }

  final Uri endpoint;
  final String credential;
  final String deviceId;
  final String deviceName;
  final RemoteTrust trust;

  RemoteTrustKind get trustKind => trust.kind;

  String encode() => jsonEncode({
    'version': _recordVersion,
    'endpoint': endpoint.toString(),
    'credential': credential,
    'device': {'id': deviceId, 'name': deviceName},
    'trust': trust.toJson(),
  });

  @override
  String toString() =>
      'RemoteCredentialRecord(endpoint: <redacted>, credential: <redacted>, '
      'device: <redacted>, trust: ${trust.kind.name})';

  static void _validateEndpoint(Uri endpoint) {
    if (endpoint.toString().length > _maxEndpointLength) {
      throw ArgumentError('Remote endpoint is too long.');
    }
    validateRemoteEndpoint(endpoint);
  }

  static void _validateText(
    String value, {
    required String field,
    required int maximumCharacters,
  }) {
    if (value.isEmpty ||
        value.runes.length > maximumCharacters ||
        value.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
      throw ArgumentError('Invalid Remote $field.');
    }
  }
}

void _requireExactKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.length != expected.length || !value.keys.every(expected.contains)) {
    throw const FormatException();
  }
}

abstract interface class RemoteSecureValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

sealed class RemoteCredentialLoadResult {
  const RemoteCredentialLoadResult();
}

final class RemoteCredentialAbsent extends RemoteCredentialLoadResult {
  const RemoteCredentialAbsent();
}

final class RemoteCredentialAvailable extends RemoteCredentialLoadResult {
  const RemoteCredentialAvailable(this.record);

  final RemoteCredentialRecord record;
}

enum RemoteCredentialRecoveryReason { secureStorageUnreadable, invalidRecord }

final class RemoteCredentialRecoveryRequired
    extends RemoteCredentialLoadResult {
  const RemoteCredentialRecoveryRequired(this.reason);

  final RemoteCredentialRecoveryReason reason;

  @override
  String toString() => 'Remote credential recovery is required.';
}

enum RemoteCredentialStoreFailure {
  recoveryRequired,
  writeFailed,
  writeVerificationFailed,
  clearFailed,
}

final class RemoteCredentialStoreException implements Exception {
  const RemoteCredentialStoreException(this.failure);

  final RemoteCredentialStoreFailure failure;

  @override
  String toString() => 'Remote credential storage operation failed.';
}

final class RemoteCredentialStore {
  RemoteCredentialStore(this._storage);

  static const storageKey = 'remote.device.v1';

  final RemoteSecureValueStore _storage;
  Future<void> _operationTail = Future<void>.value();

  Future<RemoteCredentialLoadResult> load() => _serialized(() async {
    final String? encoded;
    try {
      encoded = await _storage.read(storageKey);
    } on Object {
      return const RemoteCredentialRecoveryRequired(
        RemoteCredentialRecoveryReason.secureStorageUnreadable,
      );
    }
    if (encoded == null) {
      return const RemoteCredentialAbsent();
    }
    try {
      return RemoteCredentialAvailable(RemoteCredentialRecord.decode(encoded));
    } on FormatException {
      return const RemoteCredentialRecoveryRequired(
        RemoteCredentialRecoveryReason.invalidRecord,
      );
    }
  });

  Future<void> save(RemoteCredentialRecord record) => _serialized(() async {
    final encoded = record.encode();
    final String? existing;
    try {
      existing = await _storage.read(storageKey);
    } on Object {
      throw const RemoteCredentialStoreException(
        RemoteCredentialStoreFailure.recoveryRequired,
      );
    }
    if (existing != null) {
      try {
        RemoteCredentialRecord.decode(existing);
      } on FormatException {
        throw const RemoteCredentialStoreException(
          RemoteCredentialStoreFailure.recoveryRequired,
        );
      }
    }
    try {
      await _storage.write(storageKey, encoded);
    } on Object {
      throw const RemoteCredentialStoreException(
        RemoteCredentialStoreFailure.writeFailed,
      );
    }

    final String? readBack;
    try {
      readBack = await _storage.read(storageKey);
    } on Object {
      throw const RemoteCredentialStoreException(
        RemoteCredentialStoreFailure.writeVerificationFailed,
      );
    }
    if (readBack != encoded) {
      throw const RemoteCredentialStoreException(
        RemoteCredentialStoreFailure.writeVerificationFailed,
      );
    }
  });

  Future<void> clear() => _serialized(() async {
    try {
      await _storage.delete(storageKey);
      if (await _storage.read(storageKey) != null) {
        throw const RemoteCredentialStoreException(
          RemoteCredentialStoreFailure.clearFailed,
        );
      }
    } on RemoteCredentialStoreException {
      rethrow;
    } on Object {
      throw const RemoteCredentialStoreException(
        RemoteCredentialStoreFailure.clearFailed,
      );
    }
  });

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}
