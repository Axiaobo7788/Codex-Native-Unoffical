import 'dart:async';

import 'package:codex_native_unofficial/src/transport/remote/remote_credentials.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_cursor_store.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_lifecycle_coordinator.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_onboarding.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_pairing.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_projection.dart';
import 'package:flutter_test/flutter_test.dart';

const _token = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const _invitation = 'codex-native-pairing-v1.fixture';

void main() {
  test(
    'saves with verified readback before starting Remote lifecycle',
    () async {
      final events = <String>[];
      final storage = _FakeStorage(events: events);
      final lifecycle = _FakeLifecycle(
        phase: RemoteLifecyclePhase.unpaired,
        events: events,
      );
      final coordinator = RemoteOnboardingCoordinator(
        credentialStore: RemoteCredentialStore(storage),
        cursorStore: RemoteAppliedCursorStore(storage),
        lifecycle: lifecycle,
        pairingGateway: _FakePairingGateway(events: events),
      );

      await coordinator.pair(invitation: _invitation, deviceName: 'Phone');

      expect(coordinator.state.phase, RemoteOnboardingPhase.idle);
      expect(lifecycle.startCalls, 1);
      expect(lifecycle.stopCalls, 1);
      expect(events, [
        'pair',
        'read:${RemoteCredentialStore.storageKey}',
        'write:${RemoteCredentialStore.storageKey}',
        'read:${RemoteCredentialStore.storageKey}',
        'lifecycle:stop',
        'lifecycle:start',
      ]);
      final loaded = await RemoteCredentialStore(storage).load();
      expect(loaded, isA<RemoteCredentialAvailable>());
    },
  );

  test(
    'persists an accepted pairing while hidden without reconnecting',
    () async {
      final storage = _FakeStorage();
      final lifecycle = _FakeLifecycle(phase: RemoteLifecyclePhase.unpaired);
      final coordinator = RemoteOnboardingCoordinator(
        credentialStore: RemoteCredentialStore(storage),
        cursorStore: RemoteAppliedCursorStore(storage),
        lifecycle: lifecycle,
        pairingGateway: _FakePairingGateway(),
      )..setApplicationVisible(false);

      await coordinator.pair(invitation: _invitation, deviceName: 'Phone');

      expect(lifecycle.startCalls, 0);
      expect(lifecycle.stopCalls, 1);
      expect(coordinator.state.phase, RemoteOnboardingPhase.idle);
      expect(
        await RemoteCredentialStore(storage).load(),
        isA<RemoteCredentialAvailable>(),
      );
    },
  );

  test(
    'reports verified-save failure and never starts with an unverified token',
    () async {
      final storage = _FakeStorage()..corruptCredentialWrite = true;
      final lifecycle = _FakeLifecycle(phase: RemoteLifecyclePhase.unpaired);
      final coordinator = RemoteOnboardingCoordinator(
        credentialStore: RemoteCredentialStore(storage),
        cursorStore: RemoteAppliedCursorStore(storage),
        lifecycle: lifecycle,
        pairingGateway: _FakePairingGateway(),
      );

      await coordinator.pair(invitation: _invitation, deviceName: 'Phone');

      expect(lifecycle.startCalls, 0);
      expect(coordinator.state.phase, RemoteOnboardingPhase.failed);
      expect(
        coordinator.state.failure,
        RemoteOnboardingFailure.secureStorageFailed,
      );
      expect(coordinator.state.toString(), isNot(contains(_token)));
      expect(coordinator.state.toString(), isNot(contains('host.example')));
    },
  );

  test(
    'does not overwrite a recovery-required profile through pairing',
    () async {
      final storage = _FakeStorage()
        ..values[RemoteCredentialStore.storageKey] = '{invalid-private-record';
      final gateway = _FakePairingGateway();
      final lifecycle = _FakeLifecycle(
        phase: RemoteLifecyclePhase.credentialRecoveryRequired,
      );
      final coordinator = RemoteOnboardingCoordinator(
        credentialStore: RemoteCredentialStore(storage),
        cursorStore: RemoteAppliedCursorStore(storage),
        lifecycle: lifecycle,
        pairingGateway: gateway,
      );

      await coordinator.pair(invitation: _invitation, deviceName: 'Phone');

      expect(gateway.calls, 0);
      expect(coordinator.state.failure, RemoteOnboardingFailure.invalidState);
      expect(
        storage.values[RemoteCredentialStore.storageKey],
        '{invalid-private-record',
      );
    },
  );

  test(
    'explicit recovery clears cursor before credential and restarts',
    () async {
      final events = <String>[];
      final storage = _FakeStorage(events: events)
        ..values[RemoteCredentialStore.storageKey] = '{invalid-private-record'
        ..values[RemoteAppliedCursorStore.storageKey] = '{private-cursor';
      final lifecycle = _FakeLifecycle(
        phase: RemoteLifecyclePhase.credentialRecoveryRequired,
        events: events,
      );
      final coordinator = RemoteOnboardingCoordinator(
        credentialStore: RemoteCredentialStore(storage),
        cursorStore: RemoteAppliedCursorStore(storage),
        lifecycle: lifecycle,
        pairingGateway: _FakePairingGateway(),
      );

      await coordinator.clearProfile();

      expect(lifecycle.stopCalls, 1);
      expect(lifecycle.startCalls, 1);
      expect(storage.values, isEmpty);
      expect(events, [
        'lifecycle:stop',
        'delete:${RemoteAppliedCursorStore.storageKey}',
        'read:${RemoteAppliedCursorStore.storageKey}',
        'delete:${RemoteCredentialStore.storageKey}',
        'read:${RemoteCredentialStore.storageKey}',
        'lifecycle:start',
      ]);
    },
  );

  test(
    'shutdown waits for an accepted ticket to be saved but does not connect',
    () async {
      final storage = _FakeStorage();
      final lifecycle = _FakeLifecycle(phase: RemoteLifecyclePhase.unpaired);
      final gateway = _PendingPairingGateway();
      final coordinator = RemoteOnboardingCoordinator(
        credentialStore: RemoteCredentialStore(storage),
        cursorStore: RemoteAppliedCursorStore(storage),
        lifecycle: lifecycle,
        pairingGateway: gateway,
      );

      final pairing = coordinator.pair(
        invitation: _invitation,
        deviceName: 'Phone',
      );
      final stopping = coordinator.stop();
      var stopped = false;
      unawaited(stopping.then((_) => stopped = true));
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);

      gateway.complete(_record());
      await Future.wait([pairing, stopping]);

      expect(lifecycle.startCalls, 0);
      expect(
        await RemoteCredentialStore(storage).load(),
        isA<RemoteCredentialAvailable>(),
      );
    },
  );

  test(
    'clear failure restarts persisted-state discovery for recovery UI',
    () async {
      final storage = _FakeStorage()
        ..values[RemoteCredentialStore.storageKey] = '{invalid-private-record'
        ..values[RemoteAppliedCursorStore.storageKey] = '{private-cursor'
        ..deleteErrors.add(RemoteAppliedCursorStore.storageKey);
      final lifecycle = _FakeLifecycle(
        phase: RemoteLifecyclePhase.credentialRecoveryRequired,
      );
      final coordinator = RemoteOnboardingCoordinator(
        credentialStore: RemoteCredentialStore(storage),
        cursorStore: RemoteAppliedCursorStore(storage),
        lifecycle: lifecycle,
        pairingGateway: _FakePairingGateway(),
      );

      await coordinator.clearProfile();

      expect(lifecycle.stopCalls, 1);
      expect(lifecycle.startCalls, 1);
      expect(coordinator.state.phase, RemoteOnboardingPhase.failed);
      expect(coordinator.state.failure, RemoteOnboardingFailure.clearFailed);
      expect(
        storage.values[RemoteCredentialStore.storageKey],
        '{invalid-private-record',
      );
    },
  );
}

RemoteCredentialRecord _record() => RemoteCredentialRecord(
  endpoint: Uri.parse('wss://host.example/v1/ws'),
  credential: _token,
  deviceId: 'CCCCCCCCCCCCCCCCCCCCCC',
  deviceName: 'Phone',
);

final class _FakePairingGateway implements RemotePairingGateway {
  _FakePairingGateway({this.events});

  final List<String>? events;
  var calls = 0;

  @override
  Future<RemoteCredentialRecord> pair({
    required String invitation,
    required String deviceName,
  }) async {
    calls += 1;
    events?.add('pair');
    return _record();
  }
}

final class _PendingPairingGateway implements RemotePairingGateway {
  final Completer<RemoteCredentialRecord> _result = Completer();

  @override
  Future<RemoteCredentialRecord> pair({
    required String invitation,
    required String deviceName,
  }) => _result.future;

  void complete(RemoteCredentialRecord record) => _result.complete(record);
}

final class _FakeLifecycle implements RemoteLifecycleOwner {
  _FakeLifecycle({required RemoteLifecyclePhase phase, this.events})
    : _state = RemoteLifecycleState(phase: phase);

  final List<String>? events;
  final StreamController<RemoteLifecycleState> _states =
      StreamController.broadcast();
  RemoteLifecycleState _state;
  var startCalls = 0;
  var stopCalls = 0;

  @override
  RemoteProjectionSnapshot? get projection => null;

  @override
  RemoteLifecycleState get state => _state;

  @override
  Stream<RemoteLifecycleState> get states => _states.stream;

  @override
  Future<void> start() async {
    startCalls += 1;
    events?.add('lifecycle:start');
    _state = const RemoteLifecycleState(
      phase: RemoteLifecyclePhase.loadingCredentials,
    );
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    events?.add('lifecycle:stop');
    _state = const RemoteLifecycleState(phase: RemoteLifecyclePhase.stopped);
  }

  @override
  Future<void> suspend() async {}
}

final class _FakeStorage implements RemoteSecureValueStore {
  _FakeStorage({this.events});

  final List<String>? events;
  final Map<String, String> values = {};
  final Set<String> deleteErrors = {};
  var corruptCredentialWrite = false;

  @override
  Future<String?> read(String key) async {
    events?.add('read:$key');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    events?.add('write:$key');
    values[key] =
        corruptCredentialWrite && key == RemoteCredentialStore.storageKey
        ? '$value-corrupt'
        : value;
  }

  @override
  Future<void> delete(String key) async {
    events?.add('delete:$key');
    if (deleteErrors.contains(key)) {
      throw StateError('private storage failure');
    }
    values.remove(key);
  }
}
