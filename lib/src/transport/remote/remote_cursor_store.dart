import 'dart:async';
import 'dart:convert';

import 'remote_credentials.dart';
import 'remote_protocol.dart';

const _cursorVersion = 1;
const _maxCursorBytes = 1024;
const _maxIdentityLength = 128;

sealed class RemoteCursorLoadResult {
  const RemoteCursorLoadResult();
}

final class RemoteCursorAbsent extends RemoteCursorLoadResult {
  const RemoteCursorAbsent();
}

final class RemoteCursorAvailable extends RemoteCursorLoadResult {
  const RemoteCursorAvailable(this.cursor);

  final RemoteResumeCursor cursor;
}

enum RemoteCursorUnavailableReason { storageUnreadable, invalidRecord }

final class RemoteCursorUnavailable extends RemoteCursorLoadResult {
  const RemoteCursorUnavailable(this.reason);

  final RemoteCursorUnavailableReason reason;

  @override
  String toString() => 'Saved Remote cursor is unavailable.';
}

final class RemoteCursorStoreException implements Exception {
  const RemoteCursorStoreException();

  @override
  String toString() => 'Remote cursor storage operation failed.';
}

final class RemoteAppliedCursorStore {
  RemoteAppliedCursorStore(this._storage);

  static const storageKey = 'remote.cursor.v1';

  final RemoteSecureValueStore _storage;
  Future<void> _operationTail = Future<void>.value();

  Future<RemoteCursorLoadResult> load({required String deviceId}) =>
      _serialized(() async {
        final String? encoded;
        try {
          encoded = await _storage.read(storageKey);
        } on Object {
          return const RemoteCursorUnavailable(
            RemoteCursorUnavailableReason.storageUnreadable,
          );
        }
        if (encoded == null) {
          return const RemoteCursorAbsent();
        }
        try {
          return RemoteCursorAvailable(
            _decode(encoded, expectedDeviceId: deviceId),
          );
        } on FormatException {
          return const RemoteCursorUnavailable(
            RemoteCursorUnavailableReason.invalidRecord,
          );
        }
      });

  Future<void> save({
    required String deviceId,
    required RemoteResumeCursor cursor,
  }) => _serialized(() async {
    final encoded = _encode(deviceId: deviceId, cursor: cursor);
    try {
      await _storage.write(storageKey, encoded);
      if (await _storage.read(storageKey) != encoded) {
        throw const RemoteCursorStoreException();
      }
    } on RemoteCursorStoreException {
      rethrow;
    } on Object {
      throw const RemoteCursorStoreException();
    }
  });

  static String _encode({
    required String deviceId,
    required RemoteResumeCursor cursor,
  }) {
    _validateIdentity(deviceId);
    validateRemoteResumeCursor(cursor);
    return jsonEncode({
      'version': _cursorVersion,
      'deviceId': deviceId,
      'sessionId': cursor.sessionId,
      'sequence': cursor.sequence,
    });
  }

  static RemoteResumeCursor _decode(
    String encoded, {
    required String expectedDeviceId,
  }) {
    try {
      _validateIdentity(expectedDeviceId);
      if (encoded.length > _maxCursorBytes ||
          utf8.encode(encoded).length > _maxCursorBytes) {
        throw const FormatException();
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?> ||
          decoded.length != 4 ||
          !decoded.keys.every(
            const {'version', 'deviceId', 'sessionId', 'sequence'}.contains,
          ) ||
          decoded['version'] != _cursorVersion ||
          decoded['deviceId'] != expectedDeviceId) {
        throw const FormatException();
      }
      final sessionId = decoded['sessionId'];
      final sequence = decoded['sequence'];
      if (sessionId is! String || sequence is! int) {
        throw const FormatException();
      }
      final cursor = RemoteResumeCursor(
        sessionId: sessionId,
        sequence: sequence,
      );
      validateRemoteResumeCursor(cursor);
      return cursor;
    } on Object {
      throw const FormatException(
        'Saved Remote cursor is invalid; details were redacted.',
      );
    }
  }

  static void _validateIdentity(String value) {
    if (value.isEmpty ||
        value.length > _maxIdentityLength ||
        value.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
      throw ArgumentError('Invalid Remote device identity.');
    }
  }

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
