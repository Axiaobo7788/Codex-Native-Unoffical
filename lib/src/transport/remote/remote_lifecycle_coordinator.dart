import 'dart:async';

import '../../domain/model_models.dart';
import '../../domain/thread_models.dart';
import 'remote_credentials.dart';
import 'remote_cursor_store.dart';
import 'remote_projection.dart';
import 'remote_protocol.dart';
import 'remote_session.dart';
import 'remote_session_connector.dart';
import 'remote_socket.dart';

enum RemoteLifecyclePhase {
  idle,
  loadingCredentials,
  unpaired,
  credentialRecoveryRequired,
  connecting,
  hydrating,
  ready,
  waitingToRetry,
  revoked,
  suspended,
  stopped,
}

final class RemoteLifecycleState {
  const RemoteLifecycleState({
    required this.phase,
    this.attempt = 0,
    this.retryDelay,
    this.sessionId,
  });

  final RemoteLifecyclePhase phase;
  final int attempt;
  final Duration? retryDelay;
  final String? sessionId;

  @override
  String toString() => 'RemoteLifecycleState(${phase.name})';
}

typedef RemoteDelay = Future<void> Function(Duration duration);

abstract interface class RemoteLifecycleOwner {
  RemoteLifecycleState get state;
  Stream<RemoteLifecycleState> get states;
  RemoteProjectionSnapshot? get projection;

  Future<void> start();
  Future<void> suspend();
  Future<void> stop();
}

final class RemoteLifecycleCoordinator implements RemoteLifecycleOwner {
  factory RemoteLifecycleCoordinator({
    required RemoteCredentialStore credentialStore,
    required RemoteAppliedCursorStore cursorStore,
    required RemoteProjectionOwner projection,
    RemoteSessionConnector connector = connectRemoteSession,
    RemoteDelay delay = _defaultDelay,
    Duration initialRetryDelay = const Duration(seconds: 1),
    Duration maximumRetryDelay = const Duration(seconds: 30),
  }) {
    if (initialRetryDelay <= Duration.zero ||
        maximumRetryDelay < initialRetryDelay) {
      throw ArgumentError('Remote retry delays are invalid.');
    }
    return RemoteLifecycleCoordinator._(
      credentialStore,
      cursorStore,
      projection,
      connector,
      delay,
      initialRetryDelay,
      maximumRetryDelay,
    );
  }

  RemoteLifecycleCoordinator._(
    this._credentialStore,
    this._cursorStore,
    this._projection,
    this._connector,
    this._delay,
    this.initialRetryDelay,
    this.maximumRetryDelay,
  );

  final RemoteCredentialStore _credentialStore;
  final RemoteAppliedCursorStore _cursorStore;
  final RemoteProjectionOwner _projection;
  final RemoteSessionConnector _connector;
  final RemoteDelay _delay;
  final Duration initialRetryDelay;
  final Duration maximumRetryDelay;
  final StreamController<RemoteLifecycleState> _states =
      StreamController<RemoteLifecycleState>.broadcast(sync: true);
  Future<void> _projectionTail = Future<void>.value();

  RemoteLifecycleState _state = const RemoteLifecycleState(
    phase: RemoteLifecyclePhase.idle,
  );
  RemoteSession? _session;
  RemoteResumeCursor? _appliedCursor;
  Completer<void>? _stopSignal;
  var _runGeneration = 0;
  var _connectionGeneration = 0;
  var _active = false;

  @override
  RemoteLifecycleState get state => _state;
  @override
  Stream<RemoteLifecycleState> get states => _states.stream;
  @override
  RemoteProjectionSnapshot? get projection => _projection.snapshot;

  @override
  Future<void> start() {
    if (_active) {
      return Future<void>.value();
    }
    _active = true;
    final generation = ++_runGeneration;
    final stopSignal = Completer<void>();
    _stopSignal = stopSignal;
    _setState(
      const RemoteLifecycleState(
        phase: RemoteLifecyclePhase.loadingCredentials,
      ),
    );
    unawaited(_run(generation, stopSignal.future));
    return Future<void>.value();
  }

  @override
  Future<void> suspend() => _deactivate(
    phase: RemoteLifecyclePhase.suspended,
    invalidateProjection: false,
  );

  @override
  Future<void> stop() => _deactivate(
    phase: RemoteLifecyclePhase.stopped,
    invalidateProjection: true,
  );

  Future<void> _deactivate({
    required RemoteLifecyclePhase phase,
    required bool invalidateProjection,
  }) async {
    _active = false;
    _runGeneration += 1;
    _connectionGeneration += 1;
    final signal = _stopSignal;
    if (signal != null && !signal.isCompleted) {
      signal.complete();
    }
    final session = _session;
    _session = null;
    if (invalidateProjection) {
      _projection.invalidate();
      _appliedCursor = null;
    }
    _setState(RemoteLifecycleState(phase: phase));
    if (session != null) {
      try {
        await session.close();
      } on Object {
        // State is already terminal; close is best effort at this boundary.
      }
    }
  }

  Future<void> _run(int generation, Future<void> stopSignal) async {
    final credentials = await _credentialStore.load();
    if (!_isCurrentRun(generation)) {
      return;
    }
    final RemoteCredentialRecord record;
    switch (credentials) {
      case RemoteCredentialAbsent():
        _active = false;
        _setState(
          const RemoteLifecycleState(phase: RemoteLifecyclePhase.unpaired),
        );
        return;
      case RemoteCredentialRecoveryRequired():
        _active = false;
        _setState(
          const RemoteLifecycleState(
            phase: RemoteLifecyclePhase.credentialRecoveryRequired,
          ),
        );
        return;
      case RemoteCredentialAvailable(record: final availableRecord):
        record = availableRecord;
    }

    await _restoreCursor(record);
    if (!_isCurrentRun(generation)) {
      return;
    }

    var failures = 0;
    while (_isCurrentRun(generation)) {
      final attempt = failures + 1;
      _setState(
        RemoteLifecycleState(
          phase: RemoteLifecyclePhase.connecting,
          attempt: attempt,
        ),
      );
      final resumeCursor = _safeResumeCursor();
      RemoteSession? session;
      try {
        session = await _connector(record, resumeCursor);
        if (!_isCurrentRun(generation)) {
          return;
        }
        _session = session;
        final result = await _runSession(
          generation: generation,
          record: record,
          session: session,
        );
        if (!_isCurrentRun(generation)) {
          return;
        }
        if (result.outcome == _SessionOutcome.revoked) {
          _active = false;
          _setState(
            const RemoteLifecycleState(phase: RemoteLifecyclePhase.revoked),
          );
          return;
        }
        if (result.becameReady) {
          failures = 0;
        }
      } on RemoteCredentialRejected {
        if (_isCurrentRun(generation)) {
          _active = false;
          _setState(
            const RemoteLifecycleState(phase: RemoteLifecyclePhase.revoked),
          );
        }
        return;
      } on _RemoteProfileMismatch {
        if (_isCurrentRun(generation)) {
          _active = false;
          _setState(
            const RemoteLifecycleState(
              phase: RemoteLifecyclePhase.credentialRecoveryRequired,
            ),
          );
        }
        return;
      } on Object {
        if (!_isCurrentRun(generation)) {
          return;
        }
      } finally {
        if (identical(_session, session)) {
          _session = null;
        }
        if (session != null) {
          try {
            await session.close();
          } on Object {
            // Preserve the classified session outcome and continue recovery.
          }
        }
      }

      if (!_isCurrentRun(generation)) {
        return;
      }
      failures += 1;
      final retryDelay = _retryDelay(failures);
      _setState(
        RemoteLifecycleState(
          phase: RemoteLifecyclePhase.waitingToRetry,
          attempt: failures,
          retryDelay: retryDelay,
        ),
      );
      await Future.any([_delay(retryDelay), stopSignal]);
    }
  }

  Future<void> _restoreCursor(RemoteCredentialRecord record) async {
    await _projectionTail;
    final snapshot = _projection.snapshot;
    if (snapshot == null) {
      _appliedCursor = null;
      return;
    }
    final stored = await _cursorStore.load(deviceId: record.deviceId);
    if (stored case RemoteCursorAvailable(:final cursor)
        when cursor.sessionId == snapshot.sessionId &&
            cursor.sequence == snapshot.appliedSequence) {
      _appliedCursor = cursor;
      return;
    }
    _projection.invalidate();
    _appliedCursor = null;
  }

  RemoteResumeCursor? _safeResumeCursor() {
    final snapshot = _projection.snapshot;
    final cursor = _appliedCursor;
    if (snapshot == null ||
        cursor == null ||
        snapshot.sessionId != cursor.sessionId ||
        snapshot.appliedSequence != cursor.sequence) {
      return null;
    }
    return cursor;
  }

  Future<_SessionRunResult> _runSession({
    required int generation,
    required RemoteCredentialRecord record,
    required RemoteSession session,
  }) async {
    final connectionGeneration = ++_connectionGeneration;
    final outcome = Completer<_SessionOutcome>();
    var becameReady = false;
    Future<void> eventTail = Future<void>.value();
    Future<void> hydrationTail = Future<void>.value();

    void fail(Object _) {
      if (!outcome.isCompleted) {
        outcome.complete(_SessionOutcome.failed);
        unawaited(session.close());
      }
    }

    final eventSubscription = session.sequencedNotifications.listen((event) {
      eventTail = eventTail
          .then<void>(
            (_) => _applyEvent(
              generation: generation,
              connectionGeneration: connectionGeneration,
              record: record,
              session: session,
              event: event,
            ),
          )
          .catchError((Object error, StackTrace stackTrace) {
            fail(error);
          });
    }, onError: (Object error, StackTrace stackTrace) => fail(error));
    StreamSubscription<RemoteResyncRequired>? resyncSubscription;
    unawaited(
      session.closed.then((close) {
        if (!outcome.isCompleted) {
          outcome.complete(
            close.kind == RemoteTransportCloseKind.credentialRevoked
                ? _SessionOutcome.revoked
                : _SessionOutcome.closed,
          );
        }
      }, onError: (Object error, StackTrace stackTrace) => fail(error)),
    );

    try {
      final status = await session.status();
      if (status.sessionId != session.handshake.sessionId ||
          status.mode != 'readOnlyCodex' ||
          status.deviceId != record.deviceId) {
        throw const _RemoteProfileMismatch();
      }
      if (!_isCurrentConnection(generation, connectionGeneration, session)) {
        return const _SessionRunResult(
          outcome: _SessionOutcome.closed,
          becameReady: false,
        );
      }

      if (session.requiresResync) {
        await _hydrateUntilCurrent(
          generation: generation,
          connectionGeneration: connectionGeneration,
          record: record,
          session: session,
          waitForDeliveredEvents: () => eventTail,
        );
      } else {
        final snapshot = _projection.snapshot;
        final cursor = _appliedCursor;
        if (snapshot == null ||
            cursor == null ||
            snapshot.sessionId != session.handshake.sessionId ||
            cursor.sessionId != snapshot.sessionId ||
            cursor.sequence != snapshot.appliedSequence) {
          throw StateError('Remote resume has no matching applied projection.');
        }
        _setState(
          RemoteLifecycleState(
            phase: RemoteLifecyclePhase.ready,
            sessionId: session.handshake.sessionId,
          ),
        );
      }
      becameReady =
          _isCurrentConnection(generation, connectionGeneration, session) &&
          _state.phase == RemoteLifecyclePhase.ready;

      void scheduleHydration() {
        hydrationTail = hydrationTail
            .then<void>(
              (_) => _hydrateUntilCurrent(
                generation: generation,
                connectionGeneration: connectionGeneration,
                record: record,
                session: session,
                waitForDeliveredEvents: () => eventTail,
              ),
            )
            .catchError((Object error, StackTrace stackTrace) {
              fail(error);
            });
      }

      resyncSubscription = session.resyncEvents.listen(
        (_) => scheduleHydration(),
        onError: (Object error, StackTrace stackTrace) => fail(error),
      );
      if (session.requiresResync) {
        scheduleHydration();
      }
      return _SessionRunResult(
        outcome: await outcome.future,
        becameReady: becameReady,
      );
    } finally {
      await eventSubscription.cancel();
      await resyncSubscription?.cancel();
      try {
        await eventTail;
        await hydrationTail;
      } on Object {
        // The session outcome already records the failed work item.
      }
    }
  }

  Future<void> _hydrateUntilCurrent({
    required int generation,
    required int connectionGeneration,
    required RemoteCredentialRecord record,
    required RemoteSession session,
    required Future<void> Function() waitForDeliveredEvents,
  }) async {
    var completedHydration = false;
    while (session.requiresResync &&
        _isCurrentConnection(generation, connectionGeneration, session)) {
      final resyncGeneration = session.resyncGeneration;
      final baselineSequence = session.currentSequence;
      _appliedCursor = null;
      _setState(
        RemoteLifecycleState(
          phase: RemoteLifecyclePhase.hydrating,
          sessionId: session.handshake.sessionId,
        ),
      );
      final modelsFuture = session.listModels(const ModelListQuery(limit: 100));
      final threadsFuture = session.listThreads(
        const ThreadListQuery(limit: 100),
      );
      final pages = await Future.wait<Object>([modelsFuture, threadsFuture]);
      final models = pages[0] as ModelPage;
      final threads = pages[1] as ThreadPage;
      if (!_isCurrentConnection(generation, connectionGeneration, session) ||
          !session.requiresResync ||
          session.resyncGeneration != resyncGeneration) {
        continue;
      }
      final replaced = await _mutateProjection(
        generation: generation,
        connectionGeneration: connectionGeneration,
        session: session,
        operation: () => _projection.replace(
          sessionId: session.handshake.sessionId,
          baselineSequence: baselineSequence,
          models: models,
          threads: threads,
        ),
      );
      if (!replaced ||
          !_isCurrentConnection(generation, connectionGeneration, session) ||
          session.resyncGeneration != resyncGeneration) {
        continue;
      }
      final cursor = RemoteResumeCursor(
        sessionId: session.handshake.sessionId,
        sequence: baselineSequence,
      );
      await _cursorStore.save(deviceId: record.deviceId, cursor: cursor);
      if (!_isCurrentConnection(generation, connectionGeneration, session) ||
          session.resyncGeneration != resyncGeneration) {
        continue;
      }
      _appliedCursor = cursor;
      session.completeResync(generation: resyncGeneration);
      // Completing a resync synchronously releases transport-buffered events
      // to the session stream. Wait for the coordinator's serialized event
      // tail before publishing ready or accepting this hydration as current.
      // A released metadata-incomplete event may itself require a newer
      // authoritative generation.
      await waitForDeliveredEvents();
      completedHydration = true;
    }
    if (_isCurrentConnection(generation, connectionGeneration, session) &&
        !session.requiresResync &&
        (completedHydration || _state.phase != RemoteLifecyclePhase.ready)) {
      _setState(
        RemoteLifecycleState(
          phase: RemoteLifecyclePhase.ready,
          sessionId: session.handshake.sessionId,
        ),
      );
    }
  }

  Future<void> _applyEvent({
    required int generation,
    required int connectionGeneration,
    required RemoteCredentialRecord record,
    required RemoteSession session,
    required RemoteSequencedNotification event,
  }) async {
    if (!_isCurrentConnection(generation, connectionGeneration, session)) {
      return;
    }
    final snapshot = _projection.snapshot;
    if (session.requiresResync ||
        (snapshot != null &&
            snapshot.sessionId == event.sessionId &&
            event.sequence <= snapshot.appliedSequence)) {
      // A locally requested hydration may cover notifications that were
      // already delivered to this queue before the session entered resync.
      return;
    }
    final eventResyncGeneration = session.resyncGeneration;
    _appliedCursor = null;
    var outcome = RemoteProjectionApplyOutcome.applied;
    final applied = await _mutateProjection(
      generation: generation,
      connectionGeneration: connectionGeneration,
      session: session,
      operation: () async {
        outcome = await _projection.apply(event);
      },
    );
    if (!applied ||
        !_isCurrentConnection(generation, connectionGeneration, session) ||
        session.requiresResync ||
        session.resyncGeneration != eventResyncGeneration) {
      return;
    }
    if (outcome ==
        RemoteProjectionApplyOutcome.requiresAuthoritativeHydration) {
      session.requireAuthoritativeResync(
        reason:
            '${event.notification.method} requires authoritative hydration.',
      );
      return;
    }
    final cursor = RemoteResumeCursor(
      sessionId: event.sessionId,
      sequence: event.sequence,
    );
    await _cursorStore.save(deviceId: record.deviceId, cursor: cursor);
    if (_isCurrentConnection(generation, connectionGeneration, session) &&
        !session.requiresResync &&
        session.resyncGeneration == eventResyncGeneration &&
        (_appliedCursor == null ||
            (_appliedCursor!.sessionId == cursor.sessionId &&
                _appliedCursor!.sequence <= cursor.sequence))) {
      _appliedCursor = cursor;
      _setState(_state);
    }
  }

  Future<bool> _mutateProjection({
    required int generation,
    required int connectionGeneration,
    required RemoteSession session,
    required Future<void> Function() operation,
  }) {
    final result = Completer<bool>();
    _projectionTail = _projectionTail.then((_) async {
      if (!_isCurrentConnection(generation, connectionGeneration, session)) {
        result.complete(false);
        return;
      }
      try {
        await operation();
        final isCurrent = _isCurrentConnection(
          generation,
          connectionGeneration,
          session,
        );
        if (!isCurrent) {
          _projection.invalidate();
          _appliedCursor = null;
        }
        result.complete(isCurrent);
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Duration _retryDelay(int failures) {
    var delay = initialRetryDelay;
    for (var index = 1; index < failures; index += 1) {
      if (delay >= maximumRetryDelay) {
        return maximumRetryDelay;
      }
      final doubled = delay * 2;
      delay = doubled > maximumRetryDelay ? maximumRetryDelay : doubled;
    }
    return delay;
  }

  bool _isCurrentRun(int generation) => _active && generation == _runGeneration;

  bool _isCurrentConnection(
    int generation,
    int connectionGeneration,
    RemoteSession session,
  ) =>
      _isCurrentRun(generation) &&
      connectionGeneration == _connectionGeneration &&
      identical(_session, session);

  void _setState(RemoteLifecycleState value) {
    _state = value;
    if (!_states.isClosed) {
      _states.add(value);
    }
  }

  static Future<void> _defaultDelay(Duration duration) =>
      Future<void>.delayed(duration);
}

enum _SessionOutcome { closed, failed, revoked }

final class _SessionRunResult {
  const _SessionRunResult({required this.outcome, required this.becameReady});

  final _SessionOutcome outcome;
  final bool becameReady;
}

final class _RemoteProfileMismatch implements Exception {
  const _RemoteProfileMismatch();
}
