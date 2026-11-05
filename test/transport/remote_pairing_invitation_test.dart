import 'dart:convert';

import 'package:codex_native_unofficial/src/protocol/remote_pairing_invitation.dart';
import 'package:codex_native_unofficial/src/protocol/remote_trust.dart';
import 'package:flutter_test/flutter_test.dart';

const _code = 'AAAAAAAAAAAAAAAAAAAAAAAA';
const _expiry = 4102444800000;

void main() {
  test('round trips system and certificate trust without debug leakage', () {
    final source = <int>[0x30, 0x03, 0x02, 0x01, 0x00];
    final certificate = RemoteCertificateTrust(source);
    source[0] = 0;
    final invitations = [
      RemotePairingInvitation(
        endpoint: Uri.parse('wss://host.example/v1/ws'),
        code: _code,
        expiresAtMs: _expiry,
      ),
      RemotePairingInvitation(
        endpoint: Uri.parse('wss://host.example:4317/v1/ws'),
        code: _code,
        expiresAtMs: _expiry,
        trust: certificate,
      ),
    ];

    final system = RemotePairingInvitation.decode(invitations[0].encode());
    final bound = RemotePairingInvitation.decode(invitations[1].encode());

    expect(system.trust.kind, RemoteTrustKind.system);
    expect(bound.trust.kind, RemoteTrustKind.certificate);
    expect((bound.trust as RemoteCertificateTrust).certificate, [
      0x30,
      0x03,
      0x02,
      0x01,
      0x00,
    ]);
    expect(bound.endpoint, Uri.parse('wss://host.example:4317/v1/ws'));
    expect(bound.code, _code);
    expect(bound.expiresAtMs, _expiry);
    expect(bound.toString(), isNot(contains(_code)));
    expect(bound.toString(), isNot(contains('host.example')));
    expect(bound.trust.toString(), isNot(contains(certificate.fingerprint)));
  });

  test('rejects shape, endpoint, code, version, and digest drift', () {
    final certificate = RemoteCertificateTrust([0x30, 0x01, 0x00]);
    final base = <String, Object?>{
      'version': 1,
      'endpoint': 'wss://host.example/v1/ws',
      'code': _code,
      'expiresAtMs': _expiry,
      'trust': certificate.toJson(),
    };
    final badDigest = Map<String, Object?>.from(certificate.toJson())
      ..['sha256'] = List.filled(43, 'B').join();
    final cases = <String>[
      'wrong-prefix.payload',
      _raw({...base, 'version': 2}),
      _raw({...base, 'endpoint': 'ws://127.0.0.1/v1/ws'}),
      _raw({...base, 'endpoint': 'wss://user@host.example/v1/ws'}),
      _raw({...base, 'code': 'short'}),
      _raw({...base, 'extra': true}),
      _raw({...base, 'trust': badDigest}),
      '$remotePairingInvitationPrefix***',
    ];

    for (final value in cases) {
      expect(
        () => RemotePairingInvitation.decode(value),
        throwsA(
          isA<FormatException>().having(
            (error) => error.toString(),
            'redacted error',
            allOf(isNot(contains(_code)), isNot(contains('host.example'))),
          ),
        ),
      );
    }
  });

  test('rejects oversized invitations before decoding', () {
    expect(
      () => RemotePairingInvitation.decode(
        '$remotePairingInvitationPrefix${List.filled(remotePairingInvitationMaxCharacters, 'A').join()}',
      ),
      throwsFormatException,
    );
  });
}

String _raw(Map<String, Object?> value) {
  final bytes = utf8.encode(jsonEncode(value));
  return '$remotePairingInvitationPrefix${base64Url.encode(bytes).replaceAll('=', '')}';
}
