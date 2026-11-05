import 'dart:convert';

import 'package:crypto/crypto.dart';

const remoteMaximumTrustCertificateBytes = 8 * 1024;

enum RemoteTrustKind { system, certificate }

sealed class RemoteTrust {
  const RemoteTrust();

  RemoteTrustKind get kind;

  Map<String, Object?> toJson();

  static RemoteTrust decode(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Remote trust is invalid.');
    }
    switch (value['type']) {
      case 'system':
        _requireExactKeys(value, const {'type'});
        return const RemoteSystemTrust();
      case 'certificate':
        _requireExactKeys(value, const {'type', 'sha256', 'der'});
        final fingerprint = value['sha256'];
        final encoded = value['der'];
        if (fingerprint is! String || encoded is! String) {
          throw const FormatException('Remote trust is invalid.');
        }
        return RemoteCertificateTrust.fromEncoded(
          fingerprint: fingerprint,
          encodedCertificate: encoded,
        );
      default:
        throw const FormatException('Remote trust is unsupported.');
    }
  }
}

final class RemoteSystemTrust extends RemoteTrust {
  const RemoteSystemTrust();

  @override
  RemoteTrustKind get kind => RemoteTrustKind.system;

  @override
  Map<String, Object?> toJson() => const {'type': 'system'};

  @override
  String toString() => 'RemoteTrust(system)';
}

final class RemoteCertificateTrust extends RemoteTrust {
  factory RemoteCertificateTrust(List<int> certificate) {
    final bytes = _validatedCertificate(certificate);
    return RemoteCertificateTrust._(
      bytes,
      _base64UrlNoPadding(sha256.convert(bytes).bytes),
    );
  }

  factory RemoteCertificateTrust.fromEncoded({
    required String fingerprint,
    required String encodedCertificate,
  }) {
    if (!_isBase64UrlNoPadding(fingerprint, exactLength: 43) ||
        encodedCertificate.isEmpty ||
        encodedCertificate.length >
            _maximumBase64UrlLength(remoteMaximumTrustCertificateBytes)) {
      throw const FormatException('Remote certificate trust is invalid.');
    }
    final List<int> decoded;
    try {
      decoded = base64Url.decode(_withBase64Padding(encodedCertificate));
    } on FormatException {
      throw const FormatException('Remote certificate trust is invalid.');
    }
    final bytes = _validatedCertificate(decoded);
    if (_base64UrlNoPadding(bytes) != encodedCertificate ||
        _base64UrlNoPadding(sha256.convert(bytes).bytes) != fingerprint) {
      throw const FormatException('Remote certificate trust is invalid.');
    }
    return RemoteCertificateTrust._(bytes, fingerprint);
  }

  RemoteCertificateTrust._(List<int> certificate, this.fingerprint)
    : certificate = List<int>.unmodifiable(certificate);

  final List<int> certificate;
  final String fingerprint;

  @override
  RemoteTrustKind get kind => RemoteTrustKind.certificate;

  @override
  Map<String, Object?> toJson() => {
    'type': 'certificate',
    'sha256': fingerprint,
    'der': _base64UrlNoPadding(certificate),
  };

  @override
  String toString() => 'RemoteTrust(certificate: <redacted>)';
}

List<int> _validatedCertificate(List<int> value) {
  if (value.isEmpty || value.length > remoteMaximumTrustCertificateBytes) {
    throw const FormatException('Remote certificate trust is invalid.');
  }
  for (final byte in value) {
    if (byte < 0 || byte > 255) {
      throw const FormatException('Remote certificate trust is invalid.');
    }
  }
  return List<int>.from(value);
}

String _base64UrlNoPadding(List<int> value) =>
    base64Url.encode(value).replaceAll('=', '');

String _withBase64Padding(String value) =>
    value.padRight(value.length + ((4 - value.length % 4) % 4), '=');

int _maximumBase64UrlLength(int bytes) => ((bytes + 2) ~/ 3) * 4;

bool _isBase64UrlNoPadding(String value, {required int exactLength}) =>
    value.length == exactLength &&
    value.codeUnits.every(
      (unit) =>
          unit >= 0x30 && unit <= 0x39 ||
          unit >= 0x41 && unit <= 0x5a ||
          unit >= 0x61 && unit <= 0x7a ||
          unit == 0x2d ||
          unit == 0x5f,
    );

void _requireExactKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.length != expected.length || !value.keys.every(expected.contains)) {
    throw const FormatException('Remote trust shape is unsupported.');
  }
}
