enum RemoteListenerScope { loopback, network }

enum RemoteDeviceScope { read, write, approvalsRespond, deviceRotate }

final class RemoteHostStatus {
  const RemoteHostStatus({
    required this.hostVersion,
    required this.enabled,
    this.bindAddress,
    this.tls,
    this.scope,
    this.advertisedEndpoint,
  });

  final String hostVersion;
  final bool enabled;
  final String? bindAddress;
  final bool? tls;
  final RemoteListenerScope? scope;
  final String? advertisedEndpoint;

  bool get canCreatePairingTicket =>
      enabled &&
      advertisedEndpoint != null &&
      scope != null &&
      (tls == true || scope == RemoteListenerScope.loopback);

  @override
  String toString() =>
      'RemoteHostStatus(version: $hostVersion, enabled: $enabled, '
      'endpoint: <redacted>)';
}

final class RemotePairingTicket {
  const RemotePairingTicket({
    required this.code,
    required this.expiresAtMs,
    required this.endpoint,
  });

  final String code;
  final int expiresAtMs;
  final String? endpoint;

  DateTime get expiresAt => DateTime.fromMillisecondsSinceEpoch(expiresAtMs);

  @override
  String toString() => 'RemotePairingTicket(<redacted>)';
}

final class RemotePairedDevice {
  const RemotePairedDevice({
    required this.id,
    required this.name,
    required this.scopes,
    required this.createdAtMs,
    required this.expiresAtMs,
    required this.lastSeenAtMs,
    required this.rotatedAtMs,
    required this.revokedAtMs,
  });

  final String id;
  final String name;
  final Set<RemoteDeviceScope> scopes;
  final int createdAtMs;
  final int expiresAtMs;
  final int? lastSeenAtMs;
  final int? rotatedAtMs;
  final int? revokedAtMs;

  bool get isRevoked => revokedAtMs != null;

  bool isExpiredAt(int nowMs) => nowMs >= expiresAtMs;

  @override
  String toString() => 'RemotePairedDevice(<redacted>)';
}
