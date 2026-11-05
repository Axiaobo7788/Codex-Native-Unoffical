enum RuntimeConnectionState {
  idle,
  locating,
  starting,
  connected,
  notFound,
  error,
  processExited,
  unsupported,
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
    RuntimeConnectionState.error => 'Error',
    RuntimeConnectionState.processExited => 'Process exited',
    RuntimeConnectionState.unsupported => 'Unavailable on this platform',
    RuntimeConnectionState.stopped => 'Stopped',
  };
}
