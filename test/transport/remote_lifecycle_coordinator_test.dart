import 'dart:async';

import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_credentials.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_cursor_store.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_lifecycle_coordinator.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_projection.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_protocol.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_session.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_socket.dart';
import 'package:flutter_test/flutter_test.dart';

const _credential = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  group('RemoteLifecycleCoordinator', () {
    test('does not connect without a usable credential', () async {
      final absentBackend = _MemorySecureStore();
      final absentConnector = _Connector();
      final absent = _coordinator(
        absentBackend,
        connector: absentConnector.call,
      );

      await absent.start();
      await _waitFor(() => absent.state.phase == RemoteLifecyclePhase.unpaired);
      expect(absentConnector.calls, 0);

      final recoveryBackend = _MemorySecureStore()
        ..values[RemoteCredentialStore.storageKey] = '{invalid';
      final recoveryConnector = _Connector();
      final recovery = _coordinator(
        recoveryBackend,
        connector: recoveryConnector.call,
      );

      await recovery.start();
      await _waitFor(
        () =>
            recovery.state.phase ==
            RemoteLifecyclePhase.credentialRecoveryRequired,
      );
      expect(recoveryConnector.calls, 0);
    });

    test('hydrates before ready and persists only applied state', () async {
      final order = <String>[];
      final backend = _pairedBackend(order: order);
      final projection = _RecordingProjection(order);
      final models = Completer<ModelPage>();
      final threads = Completer<ThreadPage>();
      final session = _FakeRemoteSession(
        sessionId: 'host-1',
        serverSequence: 5,
        modelsLoader: () => models.future,
        threadsLoader: () => threads.future,
      );
      final connector = _Connector()..sessions.add(session);
      final coordinator = _coordinator(
        backend,
        projection: projection,
        connector: connector.call,
      );

      await coordinator.start();
      await _waitFor(
        () => coordinator.state.phase == RemoteLifecyclePhase.hydrating,
      );
      expect(coordinator.projection, isNull);
      expect(backend.values[RemoteAppliedCursorStore.storageKey], isNull);

      models.complete(ModelPage(models: [_model('model-1')], nextCursor: null));
      threads.complete(
        ThreadPage(threads: [_thread('thread-1')], nextCursor: null),
      );
      await _waitFor(
        () => coordinator.state.phase == RemoteLifecyclePhase.ready,
      );

      expect(coordinator.projection!.appliedSequence, 5);
      expect(order, containsAllInOrder(['replace:5', 'cursor:5']));
      session.emit(
        const RemoteSequencedNotification(
          sessionId: 'host-1',
          sequence: 6,
          notification: CodexNotification(
            method: 'turn/started',
            params: {'threadId': 'thread-1'},
          ),
        ),
      );
      await _waitFor(() => coordinator.projection!.appliedSequence == 6);
      await _waitFor(() => order.contains('cursor:6'));

      expect(order, containsAllInOrder(['apply:6', 'cursor:6']));
      expect(
        coordinator.projection!.threads.single.status,
        ThreadRuntimeStatus.active,
      );
      await coordinator.stop();
    });

    test('rehydrates metadata-incomplete lifecycle events before advancing the cursor', () async {
      final order = <String>[];
      final backend = _pairedBackend(order: order);
      var threadLoad = 0;
      final session = _FakeRemoteSession(
        sessionId: 'host-1',
        serverSequence: 5,
        threadsLoader: () async {
          threadLoad += 1;
          return ThreadPage(
            threads: [
              _thread(
                threadLoad == 1 ? 'old-thread' : 'restored-thread',
                name: threadLoad == 1 ? null : 'Authoritative name',
              ),
            ],
            nextCursor: null,
          );
        },
      );
      final connector = _Connector()..sessions.add(session);
      final coordinator = _coordinator(backend, connector: connector.call);

      await coordinator.start();
      await _waitFor(
        () => coordinator.state.phase == RemoteLifecyclePhase.ready,
      );
      expect(coordinator.projection!.threads.single.id, 'old-thread');

      session.emit(
        const RemoteSequencedNotification(
          sessionId: 'host-1',
          sequence: 6,
          notification: CodexNotification(
            method: 'thread/unarchived',
            params: {'threadId': 'restored-thread'},
          ),
        ),
      );
      // This event is deliberately queued before the first one can switch
      // the session into resync. The authoritative baseline at sequence 7
      // covers it, so it must not be applied again after hydration.
      session.emit(
        const RemoteSequencedNotification(
          sessionId: 'host-1',
          sequence: 7,
          notification: CodexNotification(
            method: 'thread/name/updated',
            params: {
              'threadId': 'restored-thread',
              'threadName': 'Queued name',
            },
          ),
        ),
      );

      await _waitFor(
        () =>
            threadLoad == 2 &&
            coordinator.state.phase == RemoteLifecyclePhase.ready &&
            coordinator.projection!.appliedSequence == 7,
      );
      expect(coordinator.projection!.threads.single.id, 'restored-thread');
      expect(coordinator.projection!.threads.single.name, 'Authoritative name');
      expect(session.authoritativeResyncReasons, [
        'thread/unarchived requires authoritative hydration.',
      ]);
      expect(order, contains('cursor:7'));
      await coordinator.stop();
    });

    test('resumes only with an exactly retained applied projection', () async {
      final backend = _pairedBackend();
      final first = _FakeRemoteSession(sessionId: 'host-1', serverSequence: 4);
      final resumed = _FakeRemoteSession(
        sessionId: 'host-1',
        serverSequence: 4,
        requiresResync: false,
      );
      final connector = _Connector()
        ..sessions.add(first)
        ..sessions.add(resumed);
      final coordinator = _coordinator(backend, connector: connector.call);

      await coordinator.start();
      await _waitFor(
        () => coordinator.state.phase == RemoteLifecyclePhase.ready,
      );
      await coordinator.suspend();
      await coordinator.start();
      await _waitFor(
        () =>
            coordinator.state.phase == RemoteLifecyclePhase.ready &&
            connector.calls == 2,
      );

      expect(connector.resumeCursors, [
        null,
        const RemoteResumeCursor(sessionId: 'host-1', sequence: 4),
      ]);
      expect(resumed.modelCalls, 0);
      expect(resumed.threadCalls, 0);
      await coordinator.stop();
    });

    test('replaces the snapshot when the Host session changes', () async {
      final backend = _pairedBackend();
      final first = _FakeRemoteSession(
        sessionId: 'host-1',
        serverSequence: 2,
        threadPage: ThreadPage(
          threads: [_thread('old-thread')],
          nextCursor: null,
        ),
      );
      final second = _FakeRemoteSession(
        sessionId: 'host-2',
        serverSequence: 8,
        threadPage: ThreadPage(
          threads: [_thread('new-thread')],
          nextCursor: null,
        ),
      );
      final connector = _Connector()
        ..sessions.add(first)
        ..sessions.add(second);
      final coordinator = _coordinator(
        backend,
        connector: connector.call,
        delay: (_) async {},
      );

      await coordinator.start();
      await _waitFor(
        () => coordinator.state.phase == RemoteLifecyclePhase.ready,
      );
      first.finish(RemoteTransportCloseKind.peer);
      await _waitFor(
        () =>
            connector.calls == 2 &&
            coordinator.state.phase == RemoteLifecyclePhase.ready,
      );

      expect(
        connector.resumeCursors[1],
        const RemoteResumeCursor(sessionId: 'host-1', sequence: 2),
      );
      expect(coordinator.projection!.sessionId, 'host-2');
      expect(coordinator.projection!.appliedSequence, 8);
      expect(coordinator.projection!.threads.single.id, 'new-thread');
      await coordinator.stop();
    });

    test('credential rejection and live revocation never retry', () async {
      final rejectedBackend = _pairedBackend();
      final rejectedConnector = _Connector()
        ..errors.add(const RemoteCredentialRejected());
      final rejected = _coordinator(
        rejectedBackend,
        connector: rejectedConnector.call,
      );

      await rejected.start();
      await _waitFor(
        () => rejected.state.phase == RemoteLifecyclePhase.revoked,
      );
      expect(rejectedConnector.calls, 1);

      final revokedBackend = _pairedBackend();
      final revokedSession = _FakeRemoteSession(
        sessionId: 'host-1',
        serverSequence: 0,
      );
      final revokedConnector = _Connector()..sessions.add(revokedSession);
      final revoked = _coordinator(
        revokedBackend,
        connector: revokedConnector.call,
      );
      await revoked.start();
      await _waitFor(() => revoked.state.phase == RemoteLifecyclePhase.ready);
      revokedSession.finish(RemoteTransportCloseKind.credentialRevoked);
      await _waitFor(() => revoked.state.phase == RemoteLifecyclePhase.revoked);
      expect(revokedConnector.calls, 1);
    });

    test('backs off exponentially after connection failures', () async {
      final backend = _pairedBackend();
      final connector = _Connector()
        ..errors.add(StateError('offline-1'))
        ..errors.add(StateError('offline-2'))
        ..errors.add(StateError('offline-3'));
      final delays = <Duration>[];
      final gates = <Completer<void>>[];
      Future<void> delay(Duration value) {
        delays.add(value);
        final gate = Completer<void>();
        gates.add(gate);
        return gate.future;
      }

      final coordinator = _coordinator(
        backend,
        connector: connector.call,
        delay: delay,
      );
      await coordinator.start();
      await _waitFor(() => delays.length == 1);
      gates[0].complete();
      await _waitFor(() => delays.length == 2);
      gates[1].complete();
      await _waitFor(() => delays.length == 3);

      expect(delays, const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ]);
      expect(coordinator.state.phase, RemoteLifecyclePhase.waitingToRetry);
      await coordinator.suspend();
    });

    test('backs off when connected sessions fail before readiness', () async {
      final backend = _pairedBackend();
      Future<ModelPage> failHydration() =>
          Future.error(StateError('snapshot unavailable'));
      final connector = _Connector()
        ..sessions.add(
          _FakeRemoteSession(
            sessionId: 'host-1',
            serverSequence: 0,
            modelsLoader: failHydration,
          ),
        )
        ..sessions.add(
          _FakeRemoteSession(
            sessionId: 'host-1',
            serverSequence: 0,
            modelsLoader: failHydration,
          ),
        );
      final delays = <Duration>[];
      final gates = <Completer<void>>[];
      Future<void> delay(Duration value) {
        delays.add(value);
        final gate = Completer<void>();
        gates.add(gate);
        return gate.future;
      }

      final coordinator = _coordinator(
        backend,
        connector: connector.call,
        delay: delay,
      );
      await coordinator.start();
      await _waitFor(() => delays.length == 1);
      gates.single.complete();
      await _waitFor(() => delays.length == 2);

      expect(delays, const [Duration(seconds: 1), Duration(seconds: 2)]);
      await coordinator.suspend();
    });

    test('closes a connection that arrives after suspend', () async {
      final backend = _pairedBackend();
      final connection = Completer<RemoteSession>();
      final session = _FakeRemoteSession(
        sessionId: 'host-1',
        serverSequence: 0,
      );
      final coordinator = _coordinator(
        backend,
        connector: (_, _) => connection.future,
      );

      await coordinator.start();
      await _waitFor(
        () => coordinator.state.phase == RemoteLifecyclePhase.connecting,
      );
      await coordinator.suspend();
      connection.complete(session);
      await _waitFor(() => session.closeCalls == 1);

      expect(coordinator.state.phase, RemoteLifecyclePhase.suspended);
      expect(coordinator.projection, isNull);
    });

    test('stale projection work cannot overwrite a resumed run', () async {
      final backend = _pairedBackend();
      final projection = _DelayedApplyProjection();
      final first = _FakeRemoteSession(
        sessionId: 'host-1',
        serverSequence: 0,
        threadPage: ThreadPage(
          threads: [_thread('thread-1')],
          nextCursor: null,
        ),
      );
      final second = _FakeRemoteSession(sessionId: 'host-2', serverSequence: 7);
      final connector = _Connector()
        ..sessions.add(first)
        ..sessions.add(second);
      final coordinator = _coordinator(
        backend,
        projection: projection,
        connector: connector.call,
      );

      await coordinator.start();
      await _waitFor(
        () => coordinator.state.phase == RemoteLifecyclePhase.ready,
      );
      first.emit(
        const RemoteSequencedNotification(
          sessionId: 'host-1',
          sequence: 1,
          notification: CodexNotification(
            method: 'turn/started',
            params: {'threadId': 'thread-1'},
          ),
        ),
      );
      await projection.applyEntered.future;
      await coordinator.suspend();
      await coordinator.start();
      await Future<void>.delayed(Duration.zero);
      expect(connector.calls, 1);

      projection.releaseApply.complete();
      await _waitFor(
        () =>
            connector.calls == 2 &&
            coordinator.state.phase == RemoteLifecyclePhase.ready,
      );

      expect(connector.resumeCursors[1], isNull);
      expect(coordinator.projection!.sessionId, 'host-2');
      expect(coordinator.projection!.appliedSequence, 7);
      await coordinator.stop();
    });

    test(
      'discards an invalidated hydration and retries its new generation',
      () async {
        final backend = _pairedBackend();
        final firstModels = Completer<ModelPage>();
        final firstThreads = Completer<ThreadPage>();
        var modelRequest = 0;
        var threadRequest = 0;
        final session = _FakeRemoteSession(
          sessionId: 'host-1',
          serverSequence: 3,
          modelsLoader: () => modelRequest++ == 0
              ? firstModels.future
              : Future.value(
                  ModelPage(models: [_model('model')], nextCursor: null),
                ),
          threadsLoader: () => threadRequest++ == 0
              ? firstThreads.future
              : Future.value(const ThreadPage(threads: [], nextCursor: null)),
        );
        final connector = _Connector()..sessions.add(session);
        final coordinator = _coordinator(backend, connector: connector.call);

        await coordinator.start();
        await _waitFor(
          () => session.modelCalls == 1 && session.threadCalls == 1,
        );
        session.invalidateResync();
        firstModels.complete(
          ModelPage(models: [_model('stale-model')], nextCursor: null),
        );
        firstThreads.complete(
          ThreadPage(threads: [_thread('stale-thread')], nextCursor: null),
        );
        await _waitFor(
          () => session.modelCalls == 2 && session.threadCalls == 2,
        );
        await _waitFor(
          () => coordinator.state.phase == RemoteLifecyclePhase.ready,
        );

        expect(coordinator.projection!.models.single.id, 'model');
        expect(coordinator.projection!.threads, isEmpty);
        expect(coordinator.projection!.appliedSequence, 3);
        await coordinator.stop();
      },
    );
  });
}

RemoteLifecycleCoordinator _coordinator(
  _MemorySecureStore backend, {
  RemoteProjectionOwner? projection,
  required RemoteSessionConnector connector,
  RemoteDelay? delay,
}) => RemoteLifecycleCoordinator(
  credentialStore: RemoteCredentialStore(backend),
  cursorStore: RemoteAppliedCursorStore(backend),
  projection: projection ?? BoundedRemoteProjection(),
  connector: connector,
  delay: delay ?? (_) async {},
);

_MemorySecureStore _pairedBackend({List<String>? order}) {
  final backend = _MemorySecureStore(order: order);
  backend.values[RemoteCredentialStore.storageKey] = _record().encode();
  return backend;
}

RemoteCredentialRecord _record() => RemoteCredentialRecord(
  endpoint: Uri.parse('wss://host.example/v1/ws'),
  credential: _credential,
  deviceId: 'device-1',
  deviceName: 'Test phone',
);

final class _MemorySecureStore implements RemoteSecureValueStore {
  _MemorySecureStore({this.order});

  final Map<String, String> values = {};
  final List<String>? order;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
    if (key == RemoteAppliedCursorStore.storageKey) {
      final sequence = RegExp(r'"sequence":(\d+)').firstMatch(value)?[1];
      order?.add('cursor:$sequence');
    }
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

final class _RecordingProjection implements RemoteProjectionOwner {
  _RecordingProjection(this.order);

  final List<String> order;
  final BoundedRemoteProjection delegate = BoundedRemoteProjection();

  @override
  RemoteProjectionSnapshot? get snapshot => delegate.snapshot;

  @override
  Future<void> replace({
    required String sessionId,
    required int baselineSequence,
    required ModelPage models,
    required ThreadPage threads,
  }) async {
    await delegate.replace(
      sessionId: sessionId,
      baselineSequence: baselineSequence,
      models: models,
      threads: threads,
    );
    order.add('replace:$baselineSequence');
  }

  @override
  Future<RemoteProjectionApplyOutcome> apply(
    RemoteSequencedNotification event,
  ) async {
    final outcome = await delegate.apply(event);
    order.add('apply:${event.sequence}');
    return outcome;
  }

  @override
  void invalidate() => delegate.invalidate();
}

final class _DelayedApplyProjection implements RemoteProjectionOwner {
  final BoundedRemoteProjection delegate = BoundedRemoteProjection();
  final Completer<void> applyEntered = Completer<void>();
  final Completer<void> releaseApply = Completer<void>();

  @override
  RemoteProjectionSnapshot? get snapshot => delegate.snapshot;

  @override
  Future<void> replace({
    required String sessionId,
    required int baselineSequence,
    required ModelPage models,
    required ThreadPage threads,
  }) => delegate.replace(
    sessionId: sessionId,
    baselineSequence: baselineSequence,
    models: models,
    threads: threads,
  );

  @override
  Future<RemoteProjectionApplyOutcome> apply(
    RemoteSequencedNotification event,
  ) async {
    final outcome = await delegate.apply(event);
    applyEntered.complete();
    await releaseApply.future;
    return outcome;
  }

  @override
  void invalidate() => delegate.invalidate();
}

final class _Connector {
  final List<_FakeRemoteSession> sessions = [];
  final List<Object> errors = [];
  final List<RemoteResumeCursor?> resumeCursors = [];
  var calls = 0;

  Future<RemoteSession> call(
    RemoteCredentialRecord record,
    RemoteResumeCursor? cursor,
  ) async {
    resumeCursors.add(cursor);
    final index = calls++;
    if (index < errors.length) {
      throw errors[index];
    }
    return sessions[index - errors.length];
  }
}

final class _FakeRemoteSession implements RemoteSession {
  _FakeRemoteSession({
    required String sessionId,
    required int serverSequence,
    bool requiresResync = true,
    this.modelsLoader,
    this.threadsLoader,
    this.threadPage = const ThreadPage(threads: [], nextCursor: null),
  }) : handshake = RemoteHandshake(
         sessionId: sessionId,
         serverSequence: serverSequence,
         requiresResync: requiresResync,
         capabilities: const {'ack', 'eventReplay', 'readOnlyCodex'},
       ),
       currentSequence = serverSequence,
       _requiresResync = requiresResync,
       _resyncGeneration = requiresResync ? 1 : 0;

  final Future<ModelPage> Function()? modelsLoader;
  final Future<ThreadPage> Function()? threadsLoader;
  final ThreadPage threadPage;
  final StreamController<RemoteResyncRequired> _resync =
      StreamController<RemoteResyncRequired>.broadcast(sync: true);
  final StreamController<RemoteSequencedNotification> _events =
      StreamController<RemoteSequencedNotification>.broadcast(sync: true);
  final Completer<RemoteTransportClose> _closed = Completer();
  bool _requiresResync;
  int _resyncGeneration;
  var modelCalls = 0;
  var threadCalls = 0;
  var closeCalls = 0;
  final List<String> authoritativeResyncReasons = [];

  @override
  final RemoteHandshake handshake;

  @override
  int currentSequence;

  @override
  RemoteResumeCursor? get resumeCursor => null;

  @override
  bool get requiresResync => _requiresResync;

  @override
  int get resyncGeneration => _resyncGeneration;

  @override
  Stream<RemoteResyncRequired> get resyncEvents => _resync.stream;

  @override
  Stream<RemoteSequencedNotification> get sequencedNotifications =>
      _events.stream;

  @override
  Future<RemoteTransportClose> get closed => _closed.future;

  @override
  Future<RemoteStatus> status() async => RemoteStatus(
    sessionId: handshake.sessionId,
    deviceId: 'device-1',
    deviceName: 'Test phone',
    mode: 'readOnlyCodex',
  );

  @override
  Future<InitializeResult> initialize(InitializeRequest request) async =>
      const InitializeResult(userAgent: 'fake');

  @override
  Future<ModelPage> listModels(ModelListQuery query) {
    modelCalls += 1;
    return modelsLoader?.call() ??
        Future.value(ModelPage(models: [_model('model')], nextCursor: null));
  }

  @override
  Future<ThreadPage> listThreads(ThreadListQuery query) {
    threadCalls += 1;
    return threadsLoader?.call() ?? Future.value(threadPage);
  }

  @override
  void requireAuthoritativeResync({required String reason}) {
    if (_requiresResync) {
      return;
    }
    authoritativeResyncReasons.add(reason);
    _requiresResync = true;
    _resyncGeneration += 1;
    _resync.add(
      RemoteResyncRequired(
        sessionId: handshake.sessionId,
        sequence: currentSequence,
        reason: reason,
      ),
    );
  }

  @override
  void completeResync({required int generation}) {
    if (generation != _resyncGeneration) {
      throw StateError('stale generation');
    }
    _requiresResync = false;
  }

  void emit(RemoteSequencedNotification event) {
    currentSequence = event.sequence;
    _events.add(event);
  }

  void invalidateResync() {
    _requiresResync = true;
    _resyncGeneration += 1;
    _resync.add(
      RemoteResyncRequired(
        sessionId: handshake.sessionId,
        sequence: currentSequence,
        reason: 'test invalidation',
      ),
    );
  }

  void finish(RemoteTransportCloseKind kind) {
    if (!_closed.isCompleted) {
      _closed.complete(RemoteTransportClose(kind: kind));
    }
  }

  @override
  Future<void> close() async {
    closeCalls += 1;
    finish(RemoteTransportCloseKind.local);
  }
}

CodexModel _model(String id) => CodexModel(
  id: id,
  model: id,
  displayName: id,
  description: 'Test model',
  isDefault: true,
  defaultReasoningEffort: 'medium',
  supportedReasoningEfforts: const [],
);

ThreadSummary _thread(String id, {String? name}) => ThreadSummary(
  id: id,
  sessionId: 'codex-$id',
  preview: 'Test thread',
  cwd: '/workspace',
  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
  status: ThreadRuntimeStatus.idle,
  ephemeral: false,
  name: name,
);

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 1000; attempt += 1) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition did not become true before the test deadline.');
}
