import 'package:codex_native_unofficial/src/transport/remote/remote_credentials.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_cursor_store.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoteAppliedCursorStore', () {
    test('round trips only for the exact paired device', () async {
      final backend = _FakeSecureValueStore();
      final store = RemoteAppliedCursorStore(backend);

      expect(await store.load(deviceId: 'device-1'), isA<RemoteCursorAbsent>());
      await store.save(
        deviceId: 'device-1',
        cursor: const RemoteResumeCursor(sessionId: 'session-1', sequence: 7),
      );

      final loaded = await store.load(deviceId: 'device-1');
      expect(loaded, isA<RemoteCursorAvailable>());
      expect(
        (loaded as RemoteCursorAvailable).cursor,
        const RemoteResumeCursor(sessionId: 'session-1', sequence: 7),
      );
      expect(
        await store.load(deviceId: 'device-2'),
        isA<RemoteCursorUnavailable>().having(
          (value) => value.reason,
          'reason',
          RemoteCursorUnavailableReason.invalidRecord,
        ),
      );
    });

    test(
      'preserves unreadable and malformed data without leaking it',
      () async {
        final backend = _FakeSecureValueStore()..value = '{secret-session';
        final store = RemoteAppliedCursorStore(backend);

        final malformed = await store.load(deviceId: 'device-1');
        expect(malformed, isA<RemoteCursorUnavailable>());
        expect(malformed.toString(), isNot(contains('secret-session')));
        expect(backend.deleteCalls, 0);

        backend.readError = StateError('keystore secret');
        final unreadable = await store.load(deviceId: 'device-1');
        expect(
          unreadable,
          isA<RemoteCursorUnavailable>().having(
            (value) => value.reason,
            'reason',
            RemoteCursorUnavailableReason.storageUnreadable,
          ),
        );
        expect(unreadable.toString(), isNot(contains('keystore secret')));
      },
    );

    test('verifies writes and reports only a generic failure', () async {
      final backend = _FakeSecureValueStore()..corruptAfterWrite = true;
      final store = RemoteAppliedCursorStore(backend);

      await expectLater(
        store.save(
          deviceId: 'device-1',
          cursor: const RemoteResumeCursor(
            sessionId: 'private-session',
            sequence: 3,
          ),
        ),
        throwsA(
          isA<RemoteCursorStoreException>().having(
            (error) => error.toString(),
            'redacted error',
            isNot(contains('private-session')),
          ),
        ),
      );
    });

    test('serializes concurrent writes', () async {
      final backend = _FakeSecureValueStore(
        delay: const Duration(milliseconds: 2),
      );
      final store = RemoteAppliedCursorStore(backend);

      await Future.wait([
        store.save(
          deviceId: 'device-1',
          cursor: const RemoteResumeCursor(sessionId: 'session-1', sequence: 1),
        ),
        store.save(
          deviceId: 'device-1',
          cursor: const RemoteResumeCursor(sessionId: 'session-1', sequence: 2),
        ),
      ]);

      expect(backend.maxConcurrentCalls, 1);
      final loaded =
          await store.load(deviceId: 'device-1') as RemoteCursorAvailable;
      expect(loaded.cursor.sequence, 2);
    });
  });
}

final class _FakeSecureValueStore implements RemoteSecureValueStore {
  _FakeSecureValueStore({this.delay = Duration.zero});

  final Duration delay;
  String? value;
  Object? readError;
  bool corruptAfterWrite = false;
  var deleteCalls = 0;
  var concurrentCalls = 0;
  var maxConcurrentCalls = 0;

  @override
  Future<String?> read(String key) => _call(() {
    final error = readError;
    if (error != null) {
      throw error;
    }
    return value;
  });

  @override
  Future<void> write(String key, String nextValue) => _call(() {
    value = corruptAfterWrite ? '$nextValue-corrupt' : nextValue;
  });

  @override
  Future<void> delete(String key) => _call(() {
    deleteCalls += 1;
    value = null;
  });

  Future<T> _call<T>(T Function() body) async {
    concurrentCalls += 1;
    maxConcurrentCalls = concurrentCalls > maxConcurrentCalls
        ? concurrentCalls
        : maxConcurrentCalls;
    try {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      return body();
    } finally {
      concurrentCalls -= 1;
    }
  }
}
