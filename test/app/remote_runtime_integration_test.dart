import 'dart:async';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_lifecycle_coordinator.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_projection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'maps Remote lifecycle states without enabling write gateways',
    () async {
      final lifecycle = _FakeRemoteLifecycle();
      final controller = RuntimeController(remoteLifecycle: lifecycle);
      addTearDown(() async {
        await controller.shutdown();
        controller.dispose();
        await lifecycle.dispose();
      });

      await controller.start();
      expect(lifecycle.startCalls, 1);
      expect(
        controller.snapshot.state,
        RuntimeConnectionState.remoteConnecting,
      );

      lifecycle
        ..projection = _projection()
        ..emit(RemoteLifecyclePhase.ready);
      expect(controller.snapshot.state, RuntimeConnectionState.remoteReadOnly);
      expect(controller.remoteModels.single.id, 'model-1');
      expect(controller.remoteThreads.single.id, 'thread-1');
      expect(controller.remoteHasMoreThreads, isTrue);
      expect(
        () => controller.listThreads(const ThreadListQuery()),
        throwsUnsupportedError,
      );

      lifecycle.emit(
        RemoteLifecyclePhase.waitingToRetry,
        retryDelay: const Duration(seconds: 8),
      );
      expect(
        controller.snapshot.state,
        RuntimeConnectionState.remoteWaitingToRetry,
      );
      expect(controller.snapshot.message, contains('8 seconds'));

      lifecycle.emit(RemoteLifecyclePhase.revoked);
      expect(controller.snapshot.state, RuntimeConnectionState.remoteRevoked);
      expect(controller.snapshot.message, isNot(contains('host.example')));
    },
  );

  testWidgets('renders bounded read-only metadata and follows hide/show', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lifecycle = _FakeRemoteLifecycle(
      state: const RemoteLifecycleState(phase: RemoteLifecyclePhase.ready),
      projection: _projection(),
    );
    final controller = RuntimeController(remoteLifecycle: lifecycle);
    addTearDown(() async {
      await controller.shutdown();
      controller.dispose();
      await lifecycle.dispose();
    });

    await tester.pumpWidget(CodexNativeApp(runtimeController: controller));
    await tester.pump();

    expect(find.text('Remote connected (read-only)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('remote-read-only-panel')),
      findsOneWidget,
    );
    expect(find.text('Test thread'), findsOneWidget);
    expect(find.textContaining('1 bounded thread summaries'), findsOneWidget);
    expect(find.textContaining('default Test model'), findsOneWidget);
    expect(find.text('New thread'), findsNothing);
    expect(find.byTooltip('Send'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(lifecycle.suspendCalls, 1);
    expect(controller.snapshot.state, RuntimeConnectionState.remoteSuspended);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(lifecycle.startCalls, 2);
    expect(find.text('Remote connected (read-only)'), findsOneWidget);
  });
}

final class _FakeRemoteLifecycle implements RemoteLifecycleOwner {
  _FakeRemoteLifecycle({
    this._state = const RemoteLifecycleState(phase: RemoteLifecyclePhase.idle),
    this.projection,
  });

  final StreamController<RemoteLifecycleState> _states =
      StreamController<RemoteLifecycleState>.broadcast(sync: true);
  RemoteLifecycleState _state;
  @override
  RemoteProjectionSnapshot? projection;
  var startCalls = 0;
  var suspendCalls = 0;
  var stopCalls = 0;

  @override
  RemoteLifecycleState get state => _state;

  @override
  Stream<RemoteLifecycleState> get states => _states.stream;

  @override
  Future<void> start() async {
    startCalls += 1;
    if (_state.phase == RemoteLifecyclePhase.suspended) {
      emit(RemoteLifecyclePhase.ready);
    } else {
      _states.add(_state);
    }
  }

  @override
  Future<void> suspend() async {
    suspendCalls += 1;
    emit(RemoteLifecyclePhase.suspended);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    emit(RemoteLifecyclePhase.stopped);
  }

  void emit(RemoteLifecyclePhase phase, {Duration? retryDelay}) {
    _state = RemoteLifecycleState(phase: phase, retryDelay: retryDelay);
    _states.add(_state);
  }

  Future<void> dispose() => _states.close();
}

RemoteProjectionSnapshot _projection() => RemoteProjectionSnapshot(
  sessionId: 'host-session',
  appliedSequence: 5,
  models: const [
    CodexModel(
      id: 'model-1',
      model: 'gpt-test',
      displayName: 'Test model',
      description: 'Fixture',
      isDefault: true,
      defaultReasoningEffort: 'medium',
      supportedReasoningEfforts: [],
    ),
  ],
  threads: [_thread()],
  nextModelCursor: null,
  nextThreadCursor: 'more-threads',
);

ThreadSummary _thread() => ThreadSummary(
  id: 'thread-1',
  sessionId: 'codex-session',
  preview: 'Test thread',
  cwd: '/workspace',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  status: ThreadRuntimeStatus.idle,
  ephemeral: false,
);
