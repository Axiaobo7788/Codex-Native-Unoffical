import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'remote_credentials.dart';

const remoteCredentialAndroidOptions = AndroidOptions(
  resetOnError: false,
  migrateOnAlgorithmChange: true,
  migrateWithBackup: true,
  storageNamespace: 'codex_native_remote',
);

const remoteCredentialRecoveryAndroidOptions = AndroidOptions(
  resetOnError: true,
  migrateOnAlgorithmChange: true,
  migrateWithBackup: true,
  storageNamespace: 'codex_native_remote',
);

final class FlutterRemoteSecureValueStore implements RemoteSecureValueStore {
  FlutterRemoteSecureValueStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(aOptions: remoteCredentialAndroidOptions);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(
    key: key,
    aOptions: remoteCredentialRecoveryAndroidOptions,
  );
}
