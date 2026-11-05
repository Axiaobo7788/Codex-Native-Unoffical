import 'dart:typed_data';

class OutputDescriptor {
  const OutputDescriptor({
    required this.reference,
    required this.bytes,
    required this.storedBytes,
    required this.truncated,
    required this.available,
  }) : assert(bytes >= 0),
       assert(storedBytes >= 0),
       assert(storedBytes <= bytes);

  final String? reference;
  final int bytes;
  final int storedBytes;
  final bool truncated;
  final bool available;
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
