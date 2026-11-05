import 'dart:convert';

import 'package:codex_native_unofficial/src/transport/remote/remote_credentials.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_secure_storage.dart';
import 'package:codex_native_unofficial/src/protocol/remote_trust.dart';
import 'package:flutter_test/flutter_test.dart';

const _credential = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  group('RemoteCredentialRecord', () {
    test('round trips a strict system-trust record without debug leakage', () {
      final record = _record();
      final decoded = RemoteCredentialRecord.decode(record.encode());

      expect(decoded.endpoint, Uri.parse('wss://host.example/v1/ws'));
      expect(decoded.credential, _credential);
      expect(decoded.deviceId, 'device-1');
      expect(decoded.deviceName, 'Pixel');
      expect(decoded.trustKind, RemoteTrustKind.system);
      expect(record.toString(), isNot(contains(_credential)));
      expect(record.toString(), isNot(contains('host.example')));
    });

    test('migrates v1 system trust and round trips v2 certificate trust', () {
      final v1 = jsonDecode(_record().encode()) as Map<String, Object?>
        ..['version'] = 1;
      final migrated = RemoteCredentialRecord.decode(jsonEncode(v1));
      expect(migrated.trustKind, RemoteTrustKind.system);
      expect(jsonDecode(migrated.encode()), containsPair('version', 2));

      final certificate = RemoteCertificateTrust([0x30, 0x01, 0x00]);
      final record = _record(trust: certificate);
      final decoded = RemoteCredentialRecord.decode(record.encode());
      expect(decoded.trustKind, RemoteTrustKind.certificate);
      expect(
        (decoded.trust as RemoteCertificateTrust).certificate,
        certificate.certificate,
      );
      expect(record.toString(), isNot(contains(certificate.fingerprint)));
    });

    test('rejects plaintext, URI credentials, and malformed fields', () {
      expect(
        () => RemoteCredentialRecord(
          endpoint: Uri.parse('ws://127.0.0.1:8765/v1/ws'),
          credential: _credential,
          deviceId: 'device-1',
          deviceName: 'Pixel',
        ),
        throwsArgumentError,
      );
      expect(
        () => RemoteCredentialRecord(
          endpoint: Uri.parse('wss://host.example/v1/ws?token=secret'),
          credential: _credential,
          deviceId: 'device-1',
          deviceName: 'Pixel',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.toString(),
            'redacted error',
            isNot(contains('secret')),
          ),
        ),
      );
      expect(
        () => RemoteCredentialRecord(
          endpoint: Uri.parse('wss://host.example/v1/ws'),
          credential: 'invalid',
          deviceId: 'device-1',
          deviceName: 'Pixel',
        ),
        throwsFormatException,
      );
      expect(
        () => RemoteCredentialRecord(
          endpoint: Uri.parse('wss://host.example/v1/ws'),
          credential: _credential,
          deviceId: 'device-1',
          deviceName: 'Pixel\nInjected',
        ),
        throwsArgumentError,
      );
      expect(
        () => RemoteCredentialRecord(
          endpoint: Uri.parse('wss://host.example/v1/ws'),
          credential: _credential,
          deviceId: 'device-1',
          deviceName: List.filled(81, '🙂').join(),
        ),
        throwsArgumentError,
      );
      expect(
        RemoteCredentialRecord(
          endpoint: Uri.parse('wss://host.example/v1/ws'),
          credential: _credential,
          deviceId: 'device-1',
          deviceName: List.filled(80, '🙂').join(),
        ).deviceName.runes.length,
        80,
      );
    });

    test('rejects unknown, oversized, and future-version saved records', () {
      final valid = jsonDecode(_record().encode()) as Map<String, Object?>;
      final withUnknown = Map<String, Object?>.from(valid)..['extra'] = true;
      final futureVersion = Map<String, Object?>.from(valid)..['version'] = 3;

      for (final encoded in [
        jsonEncode(withUnknown),
        jsonEncode(futureVersion),
        List.filled(24 * 1024 + 1, 'x').join(),
      ]) {
        expect(
          () => RemoteCredentialRecord.decode(encoded),
          throwsA(
            isA<FormatException>().having(
              (error) => error.toString(),
              'redacted error',
              allOf(
                isNot(contains(_credential)),
                isNot(contains('host.example')),
              ),
            ),
          ),
        );
      }
    });
  });

  group('RemoteCredentialStore', () {
    test('distinguishes absent, available, and unreadable storage', () async {
      final backend = _FakeSecureValueStore();
      final store = RemoteCredentialStore(backend);

      expect(await store.load(), isA<RemoteCredentialAbsent>());
      await store.save(_record());
      final available = await store.load();
      expect(available, isA<RemoteCredentialAvailable>());
      expect(
        (available as RemoteCredentialAvailable).record.deviceId,
        'device-1',
      );

      backend.readError = StateError('keystore unavailable');
      final unreadable = await store.load();
      expect(unreadable, isA<RemoteCredentialRecoveryRequired>());
      expect(
        (unreadable as RemoteCredentialRecoveryRequired).reason,
        RemoteCredentialRecoveryReason.secureStorageUnreadable,
      );
      expect(backend.deleteCalls, 0);
      expect(unreadable.toString(), isNot(contains('keystore unavailable')));

      await expectLater(
        store.save(_record(deviceId: 'must-not-overwrite')),
        throwsA(
          isA<RemoteCredentialStoreException>().having(
            (error) => error.failure,
            'failure',
            RemoteCredentialStoreFailure.recoveryRequired,
          ),
        ),
      );
      expect(backend.writeCalls, 1);

      backend.readError = null;
      expect(await store.load(), isA<RemoteCredentialAvailable>());
    });

    test('preserves malformed data until recovery is explicit', () async {
      final backend = _FakeSecureValueStore()..value = '{bad:$_credential}';
      final store = RemoteCredentialStore(backend);

      final result = await store.load();
      expect(result, isA<RemoteCredentialRecoveryRequired>());
      expect(
        (result as RemoteCredentialRecoveryRequired).reason,
        RemoteCredentialRecoveryReason.invalidRecord,
      );
      expect(backend.deleteCalls, 0);

      await expectLater(
        store.save(_record(deviceId: 'replacement')),
        throwsA(
          isA<RemoteCredentialStoreException>().having(
            (error) => error.failure,
            'failure',
            RemoteCredentialStoreFailure.recoveryRequired,
          ),
        ),
      );
      expect(backend.writeCalls, 0);
      expect(backend.value, contains(_credential));
    });

    test('verifies writes and reports a generic failure', () async {
      final backend = _FakeSecureValueStore()..corruptAfterWrite = true;
      final store = RemoteCredentialStore(backend);

      await expectLater(
        store.save(_record()),
        throwsA(
          isA<RemoteCredentialStoreException>()
              .having(
                (error) => error.failure,
                'failure',
                RemoteCredentialStoreFailure.writeVerificationFailed,
              )
              .having(
                (error) => error.toString(),
                'redacted error',
                allOf(
                  isNot(contains(_credential)),
                  isNot(contains('host.example')),
                ),
              ),
        ),
      );
    });

    test('clears only through the explicit recovery action', () async {
      final backend = _FakeSecureValueStore();
      final store = RemoteCredentialStore(backend);
      await store.save(_record());

      await store.clear();

      expect(backend.deleteCalls, 1);
      expect(await store.load(), isA<RemoteCredentialAbsent>());
    });

    test('serializes concurrent operations without overlap', () async {
      final backend = _FakeSecureValueStore(
        delay: const Duration(milliseconds: 2),
      );
      final store = RemoteCredentialStore(backend);

      await Future.wait([
        store.save(_record(deviceId: 'first')),
        store.save(_record(deviceId: 'second')),
      ]);

      expect(backend.maxConcurrentCalls, 1);
      final loaded = await store.load() as RemoteCredentialAvailable;
      expect(loaded.record.deviceId, 'second');
    });
  });

  test('Android storage resets only for explicit recovery', () {
    expect(
      remoteCredentialAndroidOptions.toMap(),
      containsPair('resetOnError', 'false'),
    );
    expect(
      remoteCredentialAndroidOptions.toMap(),
      containsPair('migrateOnAlgorithmChange', 'true'),
    );
    expect(
      remoteCredentialAndroidOptions.toMap(),
      containsPair('migrateWithBackup', 'true'),
    );
    expect(
      remoteCredentialAndroidOptions.toMap(),
      containsPair('storageNamespace', 'codex_native_remote'),
    );
    expect(
      remoteCredentialAndroidOptions.toMap(),
      containsPair('enforceBiometrics', 'false'),
    );
    expect(
      remoteCredentialRecoveryAndroidOptions.toMap(),
      containsPair('resetOnError', 'true'),
    );
    expect(
      remoteCredentialRecoveryAndroidOptions.toMap(),
      containsPair('storageNamespace', 'codex_native_remote'),
    );
  });
}

RemoteCredentialRecord _record({
  String deviceId = 'device-1',
  RemoteTrust trust = const RemoteSystemTrust(),
}) => RemoteCredentialRecord(
  endpoint: Uri.parse('wss://host.example/v1/ws'),
  credential: _credential,
  deviceId: deviceId,
  deviceName: 'Pixel',
  trust: trust,
);

final class _FakeSecureValueStore implements RemoteSecureValueStore {
  _FakeSecureValueStore({this.delay = Duration.zero});

  String? value;
  Object? readError;
  bool corruptAfterWrite = false;
  int readCalls = 0;
  int writeCalls = 0;
  int deleteCalls = 0;
  int maxConcurrentCalls = 0;
  final Duration delay;
  int _concurrentCalls = 0;
  bool _didWrite = false;

  @override
  Future<String?> read(String key) => _tracked(() {
    readCalls += 1;
    final error = readError;
    if (error != null) {
      throw error;
    }
    if (corruptAfterWrite && _didWrite) {
      return 'corrupt-readback';
    }
    return value;
  });

  @override
  Future<void> write(String key, String newValue) => _tracked(() {
    writeCalls += 1;
    value = newValue;
    _didWrite = true;
  });

  @override
  Future<void> delete(String key) => _tracked(() {
    deleteCalls += 1;
    value = null;
    _didWrite = false;
  });

  Future<T> _tracked<T>(T Function() operation) async {
    _concurrentCalls += 1;
    if (_concurrentCalls > maxConcurrentCalls) {
      maxConcurrentCalls = _concurrentCalls;
    }
    try {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      return operation();
    } finally {
      _concurrentCalls -= 1;
    }
  }
}
