import 'dart:convert';

import 'remote_trust.dart';

const remotePairingInvitationPrefix = 'codex-native-pairing-v1.';
const remotePairingInvitationMaxCharacters = 24 * 1024;
const _maximumDecodedBytes = 18 * 1024;
const _maximumEndpointCharacters = 2048;
const _pairingCodeLength = 24;
const _maximumTimestamp = 8640000000000000;

final class RemotePairingInvitation {
  factory RemotePairingInvitation({
    required Uri endpoint,
    required String code,
    required int expiresAtMs,
    RemoteTrust trust = const RemoteSystemTrust(),
  }) {
    _validateEndpoint(endpoint);
    if (!_isUrlSafe(code, exactLength: _pairingCodeLength) ||
        expiresAtMs <= 0 ||
        expiresAtMs > _maximumTimestamp) {
      throw const FormatException('Remote pairing invitation is invalid.');
    }
    return RemotePairingInvitation._(
      endpoint: endpoint,
      code: code,
      expiresAtMs: expiresAtMs,
      trust: trust,
    );
  }

  const RemotePairingInvitation._({
    required this.endpoint,
    required this.code,
    required this.expiresAtMs,
    required this.trust,
  });

  factory RemotePairingInvitation.decode(String value) {
    try {
      final bounded = value.trim();
      if (bounded.length > remotePairingInvitationMaxCharacters ||
          !bounded.startsWith(remotePairingInvitationPrefix)) {
        throw const FormatException();
      }
      final encoded = bounded.substring(remotePairingInvitationPrefix.length);
      if (encoded.isEmpty ||
          !encoded.codeUnits.every(_isBase64UrlCodeUnit) ||
          encoded.contains('=')) {
        throw const FormatException();
      }
      final bytes = base64Url.decode(_withBase64Padding(encoded));
      if (bytes.isEmpty || bytes.length > _maximumDecodedBytes) {
        throw const FormatException();
      }
      final canonical = base64Url.encode(bytes).replaceAll('=', '');
      if (canonical != encoded) {
        throw const FormatException();
      }
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException();
      }
      _requireExactKeys(decoded, const {
        'version',
        'endpoint',
        'code',
        'expiresAtMs',
        'trust',
      });
      if (decoded['version'] != 1 ||
          decoded['endpoint'] is! String ||
          decoded['code'] is! String ||
          decoded['expiresAtMs'] is! int) {
        throw const FormatException();
      }
      final endpointText = decoded['endpoint']! as String;
      if (endpointText.isEmpty ||
          endpointText.length > _maximumEndpointCharacters) {
        throw const FormatException();
      }
      final endpoint = Uri.tryParse(endpointText);
      if (endpoint == null || endpoint.toString() != endpointText) {
        throw const FormatException();
      }
      return RemotePairingInvitation(
        endpoint: endpoint,
        code: decoded['code']! as String,
        expiresAtMs: decoded['expiresAtMs']! as int,
        trust: RemoteTrust.decode(decoded['trust']),
      );
    } on Object {
      throw const FormatException(
        'Remote pairing invitation is invalid; details were redacted.',
      );
    }
  }

  final Uri endpoint;
  final String code;
  final int expiresAtMs;
  final RemoteTrust trust;

  String encode() {
    final payload = utf8.encode(
      jsonEncode({
        'version': 1,
        'endpoint': endpoint.toString(),
        'code': code,
        'expiresAtMs': expiresAtMs,
        'trust': trust.toJson(),
      }),
    );
    if (payload.length > _maximumDecodedBytes) {
      throw const FormatException('Remote pairing invitation is too large.');
    }
    final encoded =
        '$remotePairingInvitationPrefix${base64Url.encode(payload).replaceAll('=', '')}';
    if (encoded.length > remotePairingInvitationMaxCharacters) {
      throw const FormatException('Remote pairing invitation is too large.');
    }
    return encoded;
  }

  @override
  String toString() => 'RemotePairingInvitation(<redacted>)';
}

void _validateEndpoint(Uri endpoint) {
  if (endpoint.toString().length > _maximumEndpointCharacters ||
      endpoint.scheme != 'wss' ||
      endpoint.host.isEmpty ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.path != '/v1/ws' ||
      endpoint.query.isNotEmpty ||
      endpoint.fragment.isNotEmpty ||
      endpoint.hasPort && endpoint.port == 0 ||
      endpoint.host == '0.0.0.0' ||
      endpoint.host == '::') {
    throw const FormatException('Remote pairing invitation is invalid.');
  }
}

String _withBase64Padding(String value) =>
    value.padRight(value.length + ((4 - value.length % 4) % 4), '=');

bool _isBase64UrlCodeUnit(int unit) =>
    unit >= 0x30 && unit <= 0x39 ||
    unit >= 0x41 && unit <= 0x5a ||
    unit >= 0x61 && unit <= 0x7a ||
    unit == 0x2d ||
    unit == 0x5f;

bool _isUrlSafe(String value, {required int exactLength}) =>
    value.length == exactLength && value.codeUnits.every(_isBase64UrlCodeUnit);

void _requireExactKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.length != expected.length || !value.keys.every(expected.contains)) {
    throw const FormatException();
  }
}
