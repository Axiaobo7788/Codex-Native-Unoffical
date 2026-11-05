import 'dart:convert';

import '../domain/output_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';

final class OutputProtocolAdapter {
  const OutputProtocolAdapter({required this.request});

  static const maxReadBytes = 256 * 1024;

  final ProtocolRequest request;

  Future<OutputDescriptor> stat(String reference) async {
    final descriptor = _descriptor(
      await request('host/output/stat', {'ref': reference}),
      available: true,
    );
    if (descriptor.reference != reference) {
      throw const ProtocolViolation(
        'Host output stat returned a different reference.',
      );
    }
    return descriptor;
  }

  Future<OutputChunk> readRange({
    required String reference,
    required int offset,
    required int length,
  }) async {
    _validateRead(offset: offset, length: length);
    return _chunk(
      await request('host/output/readRange', {
        'ref': reference,
        'offset': offset,
        'length': length,
      }),
      expectedReference: reference,
      expectedOffset: offset,
      requestedLength: length,
    );
  }

  Future<OutputChunk> tail({
    required String reference,
    required int length,
  }) async {
    _validateRead(offset: 0, length: length);
    return _chunk(
      await request('host/output/tail', {'ref': reference, 'length': length}),
      expectedReference: reference,
      requestedLength: length,
      tail: true,
    );
  }

  static OutputDescriptor descriptorFromItem(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation(
        'Host output descriptor must be an object.',
      );
    }
    return _descriptor(value, available: _requiredBool(value, 'available'));
  }

  static OutputDescriptor _descriptor(
    JsonObject value, {
    required bool available,
  }) {
    final reference = _optionalString(value, 'ref');
    final bytes = _requiredInt(value, 'bytes');
    final storedBytes = _requiredInt(value, 'storedBytes');
    final truncated = _requiredBool(value, 'truncated');
    if (storedBytes > bytes ||
        (!truncated && storedBytes != bytes) ||
        available != (reference != null)) {
      throw const ProtocolViolation('Host output descriptor is inconsistent.');
    }
    return OutputDescriptor(
      reference: reference,
      bytes: bytes,
      storedBytes: storedBytes,
      truncated: truncated,
      available: available,
    );
  }

  static OutputChunk _chunk(
    JsonObject value, {
    required String expectedReference,
    required int requestedLength,
    int? expectedOffset,
    bool tail = false,
  }) {
    if (value['encoding'] != 'base64') {
      throw const ProtocolViolation(
        'Host output chunk encoding is unsupported.',
      );
    }
    final encoded = _requiredString(value, 'data');
    try {
      final data = base64Decode(encoded);
      final reference = _requiredString(value, 'ref');
      final offset = _requiredInt(value, 'offset');
      final bytes = _requiredInt(value, 'bytes');
      final storedBytes = _requiredInt(value, 'storedBytes');
      final truncated = _requiredBool(value, 'truncated');
      final eof = _requiredBool(value, 'eof');
      if (storedBytes > bytes || offset > storedBytes) {
        throw const ProtocolViolation('Host output chunk is inconsistent.');
      }
      final expectedDataLength = requestedLength.clamp(0, storedBytes - offset);
      final expectedTailOffset = (storedBytes - requestedLength).clamp(
        0,
        storedBytes,
      );
      if (reference != expectedReference ||
          (expectedOffset != null && offset != expectedOffset) ||
          (!truncated && storedBytes != bytes) ||
          data.length != expectedDataLength ||
          data.length > maxReadBytes ||
          offset + data.length > storedBytes ||
          eof != (offset + data.length >= storedBytes) ||
          (tail && (!eof || offset != expectedTailOffset))) {
        throw const ProtocolViolation('Host output chunk is inconsistent.');
      }
      return OutputChunk(
        reference: reference,
        offset: offset,
        data: data,
        bytes: bytes,
        storedBytes: storedBytes,
        truncated: truncated,
        eof: eof,
      );
    } on FormatException catch (error) {
      throw ProtocolViolation('Host output chunk is not valid base64.', error);
    }
  }

  static void _validateRead({required int offset, required int length}) {
    if (offset < 0 || length <= 0 || length > maxReadBytes) {
      throw RangeError(
        'Output reads require a non-negative offset and 1-$maxReadBytes bytes.',
      );
    }
  }

  static String _requiredString(JsonObject object, String key) {
    final value = object[key];
    if (value is! String || value.isEmpty) {
      throw ProtocolViolation('Host output field $key must be a string.');
    }
    return value;
  }

  static String? _optionalString(JsonObject object, String key) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.isEmpty) {
      throw ProtocolViolation(
        'Host output field $key must be a string or null.',
      );
    }
    return value;
  }

  static int _requiredInt(JsonObject object, String key) {
    final value = object[key];
    if (value is! int || value < 0) {
      throw ProtocolViolation(
        'Host output field $key must be a non-negative integer.',
      );
    }
    return value;
  }

  static bool _requiredBool(JsonObject object, String key) {
    final value = object[key];
    if (value is! bool) {
      throw ProtocolViolation('Host output field $key must be a boolean.');
    }
    return value;
  }
}
