import 'dart:typed_data';

class OutputDescriptor {
  const OutputDescriptor({
    required this.reference,
    required this.bytes,
    required this.storedBytes,
    required this.truncated,
    required this.available,
    this.exitCode,
  }) : assert(bytes >= 0),
       assert(storedBytes >= 0),
       assert(storedBytes <= bytes);

  final String? reference;
  final int bytes;
  final int storedBytes;
  final bool truncated;
  final bool available;
  final int? exitCode;

  /// Host spool references belong to one process session, never saved history.
  OutputDescriptor withoutSessionReference() => OutputDescriptor(
    reference: null,
    bytes: bytes,
    storedBytes: 0,
    truncated: truncated,
    available: false,
    exitCode: exitCode,
  );

  OutputDescriptor withExitCode(int? exitCode) => exitCode == this.exitCode
      ? this
      : OutputDescriptor(
          reference: reference,
          bytes: bytes,
          storedBytes: storedBytes,
          truncated: truncated,
          available: available,
          exitCode: exitCode,
        );
}

class OutputChunk {
  const OutputChunk({
    required this.reference,
    required this.offset,
    required this.data,
    required this.bytes,
    required this.storedBytes,
    required this.truncated,
    required this.eof,
  });

  final String reference;
  final int offset;
  final Uint8List data;
  final int bytes;
  final int storedBytes;
  final bool truncated;
  final bool eof;
}
