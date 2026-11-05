enum RuntimeConnectionState {
  idle,
  locating,
  starting,
  connected,
  notFound,
  hostNotFound,
  error,
  processExited,
  unsupported,
  remoteUnpaired,
  remoteCredentialRecoveryRequired,
  remoteConnecting,
  remoteHydrating,
  remoteWaitingToRetry,
  remoteReadOnly,
  remoteRevoked,
  remoteSuspended,
  stopped,
}

class RuntimeSnapshot {
  const RuntimeSnapshot({
    required this.state,
    this.executablePath,
    this.userAgent,
    this.processId,
    this.message,
  });

  const RuntimeSnapshot.idle() : this(state: RuntimeConnectionState.idle);

  final RuntimeConnectionState state;
  final String? executablePath;
  final String? userAgent;
  final int? processId;
  final String? message;

  String get stateLabel => switch (state) {
    RuntimeConnectionState.idle => 'Idle',
    RuntimeConnectionState.locating => 'Locating Codex',
    RuntimeConnectionState.starting => 'Starting',
    RuntimeConnectionState.connected => 'Connected',
    RuntimeConnectionState.notFound => 'Codex not found',
    RuntimeConnectionState.hostNotFound => 'Native Host not found',
    RuntimeConnectionState.error => 'Error',
    RuntimeConnectionState.processExited => 'Process exited',
    RuntimeConnectionState.unsupported => 'Unavailable on this platform',
    RuntimeConnectionState.remoteUnpaired => 'Remote not paired',
    RuntimeConnectionState.remoteCredentialRecoveryRequired =>
      'Remote pairing needs recovery',
    RuntimeConnectionState.remoteConnecting => 'Connecting to Remote Host',
    RuntimeConnectionState.remoteHydrating => 'Loading Remote state',
    RuntimeConnectionState.remoteWaitingToRetry => 'Remote reconnect pending',
    RuntimeConnectionState.remoteReadOnly => 'Remote connected (read-only)',
    RuntimeConnectionState.remoteRevoked => 'Remote device revoked',
    RuntimeConnectionState.remoteSuspended => 'Remote suspended',
    RuntimeConnectionState.stopped => 'Stopped',
  };
}
