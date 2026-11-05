final class RemoteResumeCursor {
  const RemoteResumeCursor({required this.sessionId, required this.sequence})
    : assert(sessionId != ''),
      assert(sequence >= 0);

  final String sessionId;
  final int sequence;

  @override
  bool operator ==(Object other) =>
      other is RemoteResumeCursor &&
      other.sessionId == sessionId &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(sessionId, sequence);
}

final class RemoteHandshake {
  const RemoteHandshake({
    required this.sessionId,
    required this.serverSequence,
    required this.requiresResync,
    required this.capabilities,
  });

  final String sessionId;
  final int serverSequence;
  final bool requiresResync;
  final Set<String> capabilities;
}

final class RemoteResyncRequired implements Exception {
  const RemoteResyncRequired({
    required this.sessionId,
    required this.sequence,
    required this.reason,
  });

  final String sessionId;
  final int sequence;
  final String reason;

  @override
  String toString() => 'Remote requires an authoritative resync.';
}

final class RemoteStatus {
  const RemoteStatus({
    required this.sessionId,
    required this.deviceId,
    required this.deviceName,
    required this.mode,
  });

  final String sessionId;
  final String deviceId;
  final String deviceName;
  final String mode;
}
