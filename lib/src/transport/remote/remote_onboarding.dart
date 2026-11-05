import 'dart:async';

import 'remote_credentials.dart';
import 'remote_cursor_store.dart';
import 'remote_lifecycle_coordinator.dart';
import 'remote_pairing.dart';

enum RemoteOnboardingPhase {
  idle,
  pairing,
  saving,
  activating,
  failed,
  clearing,
}

enum RemoteOnboardingFailure {
  invalidInput,
  timeout,
  tlsRejected,
  networkUnavailable,
  ticketRejected,
  deviceLimitReached,
  rateLimited,
  incompatibleHost,
  malformedResponse,
  hostFailed,
  secureStorageFailed,
  activationFailed,
  clearFailed,
  invalidState,
}

final class RemoteOnboardingState {
  const RemoteOnboardingState({required this.phase, this.failure});

  const RemoteOnboardingState.idle()
    : phase = RemoteOnboardingPhase.idle,
      failure = null;

  final RemoteOnboardingPhase phase;
  final RemoteOnboardingFailure? failure;

  bool get isBusy => switch (phase) {
    RemoteOnboardingPhase.pairing ||
    RemoteOnboardingPhase.saving ||
    RemoteOnboardingPhase.activating ||
    RemoteOnboardingPhase.clearing => true,
    RemoteOnboardingPhase.idle || RemoteOnboardingPhase.failed => false,
  };

  @override
  String toString() => 'RemoteOnboardingState(${phase.name})';
}

abstract interface class RemoteOnboardingOwner {
  RemoteOnboardingState get state;
  Stream<RemoteOnboardingState> get states;

  Future<void> pair({required String invitation, required String deviceName});

  Future<void> clearProfile();

  void setApplicationVisible(bool visible);

  Future<void> stop();
}

final class RemoteOnboardingCoordinator implements RemoteOnboardingOwner {
  factory RemoteOnboardingCoordinator({
    required RemoteCredentialStore credentialStore,
    required RemoteAppliedCursorStore cursorStore,
    required RemoteLifecycleOwner lifecycle,
    RemotePairingGateway pairingGateway = const _DefaultPairingGateway(),
  }) => RemoteOnboardingCoordinator._(
    credentialStore,
    cursorStore,
    lifecycle,
    pairingGateway,
  );

  RemoteOnboardingCoordinator._(
    this._credentialStore,
    this._cursorStore,
    this._lifecycle,
    this._pairingGateway,
  );

  final RemoteCredentialStore _credentialStore;
  final RemoteAppliedCursorStore _cursorStore;
  final RemoteLifecycleOwner _lifecycle;
  final RemotePairingGateway _pairingGateway;
  final StreamController<RemoteOnboardingState> _states =
      StreamController<RemoteOnboardingState>.broadcast(sync: true);

  RemoteOnboardingState _state = const RemoteOnboardingState.idle();
  Future<void>? _operation;
  var _applicationVisible = true;
  var _stopped = false;

  @override
  RemoteOnboardingState get state => _state;

  @override
  Stream<RemoteOnboardingState> get states => _states.stream;

  @override
  Future<void> pair({required String invitation, required String deviceName}) {
    if (_stopped) {
      return Future<void>.value();
    }
    final active = _operation;
    if (active != null) {
      return active;
    }
    final operation = _pair(invitation: invitation, deviceName: deviceName);
    _operation = operation;
    return operation.whenComplete(() {
      if (identical(_operation, operation)) {
        _operation = null;
      }
    });
  }

  Future<void> _pair({
    required String invitation,
    required String deviceName,
  }) async {
    if (_lifecycle.state.phase != RemoteLifecyclePhase.unpaired) {
      _setFailure(RemoteOnboardingFailure.invalidState);
      return;
    }
    _setState(
      const RemoteOnboardingState(phase: RemoteOnboardingPhase.pairing),
    );
    final RemoteCredentialRecord record;
    try {
      record = await _pairingGateway.pair(
        invitation: invitation,
        deviceName: deviceName,
      );
    } on RemotePairingException catch (error) {
      _setFailure(_mapPairingFailure(error.failure));
      return;
    } on Object {
      _setFailure(RemoteOnboardingFailure.networkUnavailable);
      return;
    }

    _setState(const RemoteOnboardingState(phase: RemoteOnboardingPhase.saving));
    try {
      await _credentialStore.save(record);
    } on Object {
      _setFailure(RemoteOnboardingFailure.secureStorageFailed);
      return;
    }

    _setState(
      const RemoteOnboardingState(phase: RemoteOnboardingPhase.activating),
    );
    try {
      // Invalidate a foreground reload that may still be completing an earlier
      // absent-credential read. The new run must start only after verified
      // credential persistence.
      await _lifecycle.stop();
      if (_applicationVisible) {
        await _lifecycle.start();
      }
      _setState(const RemoteOnboardingState.idle());
    } on Object {
      _setFailure(RemoteOnboardingFailure.activationFailed);
    }
  }

  @override
  Future<void> clearProfile() {
    if (_stopped) {
      return Future<void>.value();
    }
    final active = _operation;
    if (active != null) {
      return active;
    }
    final operation = _clearProfile();
    _operation = operation;
    return operation.whenComplete(() {
      if (identical(_operation, operation)) {
        _operation = null;
      }
    });
  }

  Future<void> _clearProfile() async {
    final phase = _lifecycle.state.phase;
    if (phase != RemoteLifecyclePhase.credentialRecoveryRequired &&
        phase != RemoteLifecyclePhase.revoked) {
      _setFailure(RemoteOnboardingFailure.invalidState);
      return;
    }
    _setState(
      const RemoteOnboardingState(phase: RemoteOnboardingPhase.clearing),
    );
    try {
      await _lifecycle.stop();
      await _cursorStore.clear();
      await _credentialStore.clear();
      if (_applicationVisible) {
        await _lifecycle.start();
      }
      _setState(const RemoteOnboardingState.idle());
    } on Object {
      if (_applicationVisible) {
        try {
          await _lifecycle.start();
        } on Object {
          // The clear failure remains the primary recovery result.
        }
      }
      _setFailure(RemoteOnboardingFailure.clearFailed);
    }
  }

  @override
  void setApplicationVisible(bool visible) {
    _applicationVisible = visible;
  }

  @override
  Future<void> stop() async {
    if (_stopped) {
      return;
    }
    _stopped = true;
    _applicationVisible = false;
    await _operation;
    await _states.close();
  }

  void _setFailure(RemoteOnboardingFailure failure) {
    _setState(
      RemoteOnboardingState(
        phase: RemoteOnboardingPhase.failed,
        failure: failure,
      ),
    );
  }

  void _setState(RemoteOnboardingState value) {
    _state = value;
    if (!_states.isClosed) {
      _states.add(value);
    }
  }

  static RemoteOnboardingFailure _mapPairingFailure(
    RemotePairingFailure failure,
  ) => switch (failure) {
    RemotePairingFailure.invalidInput => RemoteOnboardingFailure.invalidInput,
    RemotePairingFailure.timeout => RemoteOnboardingFailure.timeout,
    RemotePairingFailure.tlsRejected => RemoteOnboardingFailure.tlsRejected,
    RemotePairingFailure.networkUnavailable =>
      RemoteOnboardingFailure.networkUnavailable,
    RemotePairingFailure.ticketRejected =>
      RemoteOnboardingFailure.ticketRejected,
    RemotePairingFailure.deviceLimitReached =>
      RemoteOnboardingFailure.deviceLimitReached,
    RemotePairingFailure.rateLimited => RemoteOnboardingFailure.rateLimited,
    RemotePairingFailure.incompatibleHost =>
      RemoteOnboardingFailure.incompatibleHost,
    RemotePairingFailure.malformedResponse =>
      RemoteOnboardingFailure.malformedResponse,
    RemotePairingFailure.hostFailed => RemoteOnboardingFailure.hostFailed,
  };
}

final class _DefaultPairingGateway implements RemotePairingGateway {
  const _DefaultPairingGateway();

  @override
  Future<RemoteCredentialRecord> pair({
    required String invitation,
    required String deviceName,
  }) => RemotePairingClient().pair(
    invitation: invitation,
    deviceName: deviceName,
  );
}
