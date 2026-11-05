import 'dart:async';
import 'dart:convert';

typedef JsonObject = Map<String, Object?>;

/// Decodes UTF-8 JSON objects separated by newlines.
///
/// The UTF-8 and line decoders retain partial input between chunks. A malformed
/// line is emitted as a stream error while later complete lines remain usable.
final class JsonlDecoder extends StreamTransformerBase<List<int>, JsonObject> {
  const JsonlDecoder();

  @override
  Stream<JsonObject> bind(Stream<List<int>> stream) {
    return stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty)
        .map(_decodeObject);
  }

  static JsonObject _decodeObject(String line) {
    final value = jsonDecode(line);
    if (value is! Map<String, Object?>) {
      throw const FormatException(
        'A JSONL protocol message must be an object.',
      );
    }
    return value;
  }
}
