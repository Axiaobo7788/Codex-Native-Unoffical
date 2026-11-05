import 'package:codex_native_unofficial/src/features/settings/remote_pairing_qr.dart';
import 'package:codex_native_unofficial/src/protocol/remote_pairing_invitation.dart';
import 'package:codex_native_unofficial/src/protocol/remote_trust.dart';
import 'package:flutter_test/flutter_test.dart';

const _pairingCode = 'AAAAAAAAAAAAAAAAAAAAAAAA';
const _expiry = 4102444800000;

void main() {
  test('encodes exact system and bounded-certificate invitations offline', () {
    final invitations = [
      _invitation(),
      _invitation(
        trust: RemoteCertificateTrust(
          List<int>.generate(384, (index) => index & 0xff),
        ),
      ),
    ];

    for (final invitation in invitations) {
      final qr = RemotePairingQr.tryEncode(invitation);

      expect(qr, isNotNull);
      expect(qr!.version, inInclusiveRange(1, 40));
      expect(qr.moduleCount, qr.version * 4 + 17);
      expect(
        qr.logicalSize,
        (qr.moduleCount + remotePairingQrQuietZoneModules * 2) *
            remotePairingQrLogicalPixelsPerModule,
      );
      expect([
        for (var row = 0; row < qr.moduleCount; row += 1)
          for (var column = 0; column < qr.moduleCount; column += 1)
            qr.isDark(row, column),
      ], contains(true));
      expect(qr.toString(), isNot(contains(_pairingCode)));
      expect(qr.toString(), isNot(contains('host.example')));
    }
  });

  test('fails closed for malformed and single-symbol-overflow invitations', () {
    final oversized = _invitation(
      trust: RemoteCertificateTrust(List<int>.filled(3000, 0x41)),
    );
    expect(oversized.length, lessThan(remotePairingInvitationMaxCharacters));

    expect(RemotePairingQr.tryEncode('not-an-invitation'), isNull);
    expect(RemotePairingQr.tryEncode(' ${_invitation()}'), isNull);
    expect(RemotePairingQr.tryEncode(oversized), isNull);
  });
}

String _invitation({RemoteTrust trust = const RemoteSystemTrust()}) =>
    RemotePairingInvitation(
      endpoint: Uri.parse('wss://host.example:4317/v1/ws'),
      code: _pairingCode,
      expiresAtMs: _expiry,
      trust: trust,
    ).encode();
