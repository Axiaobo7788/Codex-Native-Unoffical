import 'dart:async';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_lifecycle_coordinator.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_onboarding.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_projection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unpaired phone UI submits bounded onboarding fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lifecycle = _FakeLifecycle(RemoteLifecyclePhase.unpaired);
    final onboarding = _FakeOnboarding();
    final controller = RuntimeController(
      remoteLifecycle: lifecycle,
      remoteOnboarding: onboarding,
    );
    addTearDown(controller.shutdown);

    await tester.pumpWidget(
      CodexNativeApp(
        runtimeController: controller,
        shutdownHandler: () async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remote-pairing-panel')), findsOneWidget);
    expect(find.text('Pair this Android device'), findsOneWidget);
    expect(find.textContaining('bearer'), findsOneWidget);
    expect(find.text('New thread'), findsNothing);
    expect(find.text('Send'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('remote-pairing-invitation-field')),
      'codex-native-pairing-v1.fixture',
    );
    await tester.enterText(
      find.byKey(const ValueKey('remote-device-name-field')),
      'Test phone',
    );
    await tester.tap(find.byKey(const ValueKey('remote-pair-button')));
    await tester.pump();

    expect(onboarding.pairCalls, 1);
    expect(onboarding.invitation, 'codex-native-pairing-v1.fixture');
    expect(onboarding.deviceName, 'Test phone');
    expect(find.textContaining('Paste a complete, current'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovery requires affirmative confirmation before clear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lifecycle = _FakeLifecycle(
      RemoteLifecyclePhase.credentialRecoveryRequired,
    );
    final onboarding = _FakeOnboarding();
    final controller = RuntimeController(
      remoteLifecycle: lifecycle,
      remoteOnboarding: onboarding,
    );
    addTearDown(controller.shutdown);

    await tester.pumpWidget(
      CodexNativeApp(
        runtimeController: controller,
        shutdownHandler: () async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('remote-recovery-panel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remote-clear-profile-button')));
    await tester.pumpAndSettle();
    expect(find.text('Clear saved Remote profile?'), findsOneWidget);
    expect(onboarding.clearCalls, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(onboarding.clearCalls, 0);

    await tester.tap(find.byKey(const ValueKey('remote-clear-profile-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remote-confirm-clear-button')));
    await tester.pumpAndSettle();

    expect(onboarding.clearCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

final class _FakeLifecycle implements RemoteLifecycleOwner {
  _FakeLifecycle(RemoteLifecyclePhase phase)
    : _state = RemoteLifecycleState(phase: phase);

  final StreamController<RemoteLifecycleState> _states =
      StreamController.broadcast(sync: true);
  RemoteLifecycleState _state;

  @override
  RemoteProjectionSnapshot? get projection => null;

  @override
  RemoteLifecycleState get state => _state;

  @override
  Stream<RemoteLifecycleState> get states => _states.stream;

  @override
  Future<void> start() async => _states.add(_state);

  @override
  Future<void> stop() async {
    _state = const RemoteLifecycleState(phase: RemoteLifecyclePhase.stopped);
    _states.add(_state);
  }

  @override
  Future<void> suspend() async {}
}

final class _FakeOnboarding implements RemoteOnboardingOwner {
  final StreamController<RemoteOnboardingState> _states =
      StreamController.broadcast(sync: true);
  RemoteOnboardingState _state = const RemoteOnboardingState.idle();
  var pairCalls = 0;
  var clearCalls = 0;
  String? invitation;
  String? deviceName;

  @override
  RemoteOnboardingState get state => _state;

  @override
  Stream<RemoteOnboardingState> get states => _states.stream;

  @override
  Future<void> pair({
    required String invitation,
    required String deviceName,
  }) async {
    pairCalls += 1;
    this.invitation = invitation;
    this.deviceName = deviceName;
    _state = const RemoteOnboardingState(
      phase: RemoteOnboardingPhase.failed,
      failure: RemoteOnboardingFailure.invalidInput,
    );
    _states.add(_state);
  }

  @override
  Future<void> clearProfile() async {
    clearCalls += 1;
    _state = const RemoteOnboardingState.idle();
    _states.add(_state);
  }

  @override
  void setApplicationVisible(bool visible) {}

  @override
  Future<void> stop() => _states.close();
}
