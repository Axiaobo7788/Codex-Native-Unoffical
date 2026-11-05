import 'dart:convert';
import 'dart:typed_data';

import 'package:codex_native_unofficial/src/domain/output_gateway.dart';
import 'package:codex_native_unofficial/src/domain/output_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/output_viewer_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads only one bounded window and navigates by byte range', () async {
    final bytes = Uint8List.fromList(utf8.encode('0123456789abcdefghij'));
    final gateway = _OutputGateway(bytes);
    final controller = OutputViewerController(
      gateway: gateway,
      descriptor: OutputDescriptor(
        reference: 'output-ref',
        bytes: bytes.length,
        storedBytes: bytes.length,
        truncated: false,
        available: true,
      ),
      pageBytes: 5,
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();
    expect(controller.text, 'fghij');
    expect(controller.chunk?.offset, 15);
    expect(controller.canLoadPrevious, isTrue);
    expect(controller.canLoadNext, isFalse);

    await controller.loadStart();
    expect(controller.text, '01234');
    expect(controller.canLoadPrevious, isFalse);
    expect(controller.canLoadNext, isTrue);

    await controller.loadNext();
    expect(controller.text, '56789');
    expect(gateway.largestRead, 8);
  });

  test(
    'drops split UTF-8 edges instead of showing replacement characters',
    () async {
      final rocket = Uint8List.fromList(utf8.encode('A🚀B'));
      final gateway = _OutputGateway(rocket);
      final controller = OutputViewerController(
        gateway: gateway,
        descriptor: OutputDescriptor(
          reference: 'unicode',
          bytes: rocket.length,
          storedBytes: rocket.length,
          truncated: false,
          available: true,
        ),
        pageBytes: 3,
      );
      addTearDown(controller.dispose);

      await controller.loadStart();
      expect(controller.text, 'A🚀');
      await controller.loadNext();
      expect(controller.text, 'B');
      expect(controller.text, isNot(contains('�')));
    },
  );
}

class _OutputGateway implements OutputGateway {
  _OutputGateway(this.bytes);

  final Uint8List bytes;
  var largestRead = 0;

  @override
  Future<OutputDescriptor> statOutput(String reference) async =>
      OutputDescriptor(
        reference: reference,
        bytes: bytes.length,
        storedBytes: bytes.length,
        truncated: false,
        available: true,
      );

  @override
  Future<OutputChunk> readOutputRange({
    required String reference,
    required int offset,
    required int length,
  }) async {
    largestRead = length > largestRead ? length : largestRead;
    return _chunk(reference, offset, length);
  }

  @override
  Future<OutputChunk> readOutputTail({
    required String reference,
    required int length,
  }) async => _chunk(reference, bytes.length - length, length);

  OutputChunk _chunk(String reference, int offset, int length) {
    final end = (offset + length).clamp(0, bytes.length);
    return OutputChunk(
      reference: reference,
      offset: offset,
      data: Uint8List.fromList(bytes.sublist(offset, end)),
      bytes: bytes.length,
      storedBytes: bytes.length,
      truncated: false,
      eof: end == bytes.length,
    );
  }
}
