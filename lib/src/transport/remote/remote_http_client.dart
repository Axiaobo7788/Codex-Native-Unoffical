import 'dart:convert';
import 'dart:io';

import '../../protocol/remote_trust.dart';

HttpClient createRemoteHttpClient(RemoteTrust trust) {
  return switch (trust) {
    RemoteSystemTrust() => HttpClient(),
    RemoteCertificateTrust(:final certificate) => HttpClient(
      context: SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificatesBytes(
          Platform.isIOS ? certificate : _pemCertificate(certificate),
        ),
    ),
  };
}

List<int> _pemCertificate(List<int> der) {
  final encoded = base64.encode(der);
  final lines = <String>['-----BEGIN CERTIFICATE-----'];
  for (var offset = 0; offset < encoded.length; offset += 64) {
    final end = offset + 64 < encoded.length ? offset + 64 : encoded.length;
    lines.add(encoded.substring(offset, end));
  }
  lines.add('-----END CERTIFICATE-----');
  return ascii.encode('${lines.join('\n')}\n');
}
