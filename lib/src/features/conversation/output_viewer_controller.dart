import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/output_gateway.dart';
import '../../domain/output_models.dart';

class OutputViewerController extends ChangeNotifier {
  OutputViewerController({
    required this.gateway,
    required this.descriptor,
    this.pageBytes = 64 * 1024,
  }) : assert(pageBytes > 0 && pageBytes <= 256 * 1024 - 3);

  final OutputGateway gateway;
  final OutputDescriptor descriptor;
  final int pageBytes;
  OutputChunk? _chunk;
  String? _errorMessage;
  var _loading = false;
  var _generation = 0;
  var _disposed = false;

  OutputChunk? get chunk => _chunk;
  String? get errorMessage => _errorMessage;
  bool get loading => _loading;
  bool get canLoadPrevious => !_loading && (_chunk?.offset ?? 0) > 0;
  bool get canLoadNext {
    final chunk = _chunk;
    return !_loading &&
        chunk != null &&
        chunk.offset + pageBytes < descriptor.storedBytes;
  }

  String get text =>
      _decodeWindow(_chunk?.data ?? Uint8List(0), logicalLength: pageBytes);

  Future<void> loadInitial() => loadTail();

  Future<void> loadStart() => _loadOffset(0);

  Future<void> loadPrevious() {
    final offset = (_chunk?.offset ?? 0) - pageBytes;
    return _loadOffset(offset < 0 ? 0 : offset);
  }

  Future<void> loadNext() {
    final chunk = _chunk;
    if (chunk == null) {
      return loadStart();
    }
    return _loadOffset(chunk.offset + pageBytes);
  }

  Future<void> loadTail() async {
    final reference = descriptor.reference;
    if (!_canRead(reference) || _loading) {
      return;
    }
    if (descriptor.storedBytes == 0) {
      _setEmpty(reference!);
      return;
    }
    await _load(
      () => gateway.readOutputTail(
        reference: reference!,
        length: pageBytes.clamp(1, descriptor.storedBytes),
      ),
    );
  }

  Future<void> _loadOffset(int offset) async {
    final reference = descriptor.reference;
    if (!_canRead(reference) || _loading) {
      return;
    }
    if (descriptor.storedBytes == 0) {
      _setEmpty(reference!);
      return;
    }
    final boundedOffset = offset.clamp(0, descriptor.storedBytes - 1);
    // Up to three look-ahead bytes ensure a valid UTF-8 scalar crossing the
    // logical page edge is visible in this page. Adjacent pages still advance
    // by exactly `pageBytes`, so the overlap cannot grow retained memory.
    final length = (pageBytes + 3).clamp(
      1,
      descriptor.storedBytes - boundedOffset,
    );
    await _load(
      () => gateway.readOutputRange(
        reference: reference!,
        offset: boundedOffset,
        length: length,
      ),
    );
  }

  Future<void> _load(Future<OutputChunk> Function() operation) async {
    final generation = ++_generation;
    _loading = true;
    _errorMessage = null;
    _notify();
    try {
      final chunk = await operation();
      if (_isCurrent(generation)) {
        _chunk = chunk;
      }
    } catch (error) {
      if (_isCurrent(generation)) {
        _errorMessage = error.toString();
      }
    } finally {
      if (_isCurrent(generation)) {
        _loading = false;
        _notify();
      }
    }
  }

  bool _canRead(String? reference) =>
      descriptor.available && reference != null && !_disposed;

  void _setEmpty(String reference) {
    _chunk = OutputChunk(
      reference: reference,
      offset: 0,
      data: Uint8List(0),
      bytes: descriptor.bytes,
      storedBytes: descriptor.storedBytes,
      truncated: descriptor.truncated,
      eof: true,
    );
    _errorMessage = null;
    _notify();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    super.dispose();
  }
}

String _decodeWindow(Uint8List bytes, {required int logicalLength}) {
  if (bytes.isEmpty) {
    return '';
  }
  var start = 0;
  while (start < bytes.length && (bytes[start] & 0xc0) == 0x80) {
    start += 1;
  }
  final logicalEnd = logicalLength.clamp(0, bytes.length);
  final lookaheadEnd = (logicalEnd + 3).clamp(logicalEnd, bytes.length);
  for (var end = logicalEnd; end <= lookaheadEnd; end += 1) {
    try {
      return utf8.decode(bytes.sublist(start, end));
    } on FormatException {
      // A scalar that starts inside the logical page can require at most three
      // look-ahead bytes. Other malformed data is represented only inside the
      // logical page so ASCII look-ahead never appears twice across pages.
    }
  }
  return utf8.decode(bytes.sublist(start, logicalEnd), allowMalformed: true);
}
