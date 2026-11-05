import 'dart:typed_data';

import 'package:qr/qr.dart';

import '../../protocol/remote_pairing_invitation.dart';

const remotePairingQrQuietZoneModules = 4;
const remotePairingQrLogicalPixelsPerModule = 3.0;

/// A bounded, offline QR projection of one exact versioned pairing invitation.
///
/// The protocol remains authoritative. Invitations that do not fit one standard
/// Version 1-40 symbol at medium error correction are deliberately not split,
/// compressed, or rewritten; the UI keeps its complete manual-copy fallback.
final class RemotePairingQr {
  RemotePairingQr._(this._image);

  static RemotePairingQr? tryEncode(String invitation) {
    try {
      RemotePairingInvitation.decode(invitation);
      if (invitation.trim() != invitation ||
          invitation.codeUnits.any((unit) => unit > 0x7f)) {
        return null;
      }
      final code = QrCode(
        payload: QrPayload.fromTypedData(
          Uint8List.fromList(invitation.codeUnits),
        ),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      );
      return RemotePairingQr._(QrImage(code));
    } on FormatException {
      return null;
    } on InputTooLongException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  final QrImage _image;

  int get version => _image.typeNumber;
  int get moduleCount => _image.moduleCount;
  int get totalModuleCount => moduleCount + remotePairingQrQuietZoneModules * 2;
  double get logicalSize =>
      totalModuleCount * remotePairingQrLogicalPixelsPerModule;

  bool isDark(int row, int column) => _image.isDark(row, column);

  @override
  String toString() =>
      'RemotePairingQr(version: $version, payload: <redacted>)';
}
