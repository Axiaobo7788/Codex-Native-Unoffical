import 'dart:io';

import '../../protocol/protocol_models.dart';

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

void validateRemoteEndpoint(
  Uri endpoint, {
  bool allowInsecureLoopback = false,
}) {
  if (endpoint.userInfo.isNotEmpty ||
      endpoint.query.isNotEmpty ||
      endpoint.fragment.isNotEmpty ||
      endpoint.path != '/v1/ws') {
    throw ArgumentError(
      'Invalid Remote endpoint; URI details were redacted.',
      'endpoint',
    );
  }
  if (endpoint.scheme == 'wss' && endpoint.host.isNotEmpty) {
    return;
  }
  final address = InternetAddress.tryParse(endpoint.host);
  if (endpoint.scheme != 'ws' ||
      !allowInsecureLoopback ||
      address == null ||
      !address.isLoopback) {
    throw ArgumentError(
      'Remote requires WSS; insecure WS is limited to explicit literal loopback.',
    );
  }
}

void validateRemoteCredential(String credential) {
  final valid =
      credential.length == 43 &&
      credential.codeUnits.every(
        (value) =>
            value >= 0x30 && value <= 0x39 ||
            value >= 0x41 && value <= 0x5a ||
            value >= 0x61 && value <= 0x7a ||
            value == 0x2d ||
            value == 0x5f,
      );
  if (!valid) {
    throw const FormatException('Remote credential has an invalid format.');
  }
}

void validateRemoteResumeCursor(RemoteResumeCursor? cursor) {
  if (cursor != null &&
      (cursor.sessionId.isEmpty ||
          cursor.sessionId.length > 128 ||
          cursor.sequence < 0)) {
    throw ArgumentError('Invalid Remote cursor.');
  }
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

final class RemoteSequencedNotification {
  const RemoteSequencedNotification({
    required this.sessionId,
    required this.sequence,
    required this.notification,
  });

  final String sessionId;
  final int sequence;
  final CodexNotification notification;
}

enum RemoteTransportCloseKind {
  local,
  peer,
  protocolViolation,
  resyncRequired,
  credentialRevoked,
  failed,
}

final class RemoteTransportClose {
  const RemoteTransportClose({required this.kind, this.code});

  final RemoteTransportCloseKind kind;
  final int? code;

  @override
  String toString() => 'Remote transport closed.';
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
