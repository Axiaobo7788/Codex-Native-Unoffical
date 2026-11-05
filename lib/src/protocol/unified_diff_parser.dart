import '../domain/diff_models.dart';

/// Converts an aggregated unified diff into a bounded presentation snapshot.
///
/// The input string is owned by the protocol decoder, but this parser never
/// retains it. Processing and retained output are both capped so an unusually
/// large turn diff cannot create an unbounded Flutter working set.
final class UnifiedDiffParser {
  const UnifiedDiffParser({
    this.maxInputCharacters = 2 * 1024 * 1024,
    this.maxFiles = 100,
    this.maxStoredCharacters = 512 * 1024,
    this.maxStoredCharactersPerFile = 128 * 1024,
    this.maxLinesPerFile = 4000,
    this.maxCharactersPerLine = 2000,
  }) : assert(maxInputCharacters > 0),
       assert(maxFiles > 0),
       assert(maxStoredCharacters > 0),
       assert(maxStoredCharactersPerFile > 0),
       assert(maxLinesPerFile > 0),
       assert(maxCharactersPerLine > 0);

  final int maxInputCharacters;
  final int maxFiles;
  final int maxStoredCharacters;
  final int maxStoredCharactersPerFile;
  final int maxLinesPerFile;
  final int maxCharactersPerLine;

  DiffSnapshot parse({
    required String threadId,
    required String turnId,
    required String diff,
  }) {
    final files = <DiffFile>[];
    _FileBuilder? current;
    var offset = 0;
    var storedCharacters = 0;
    var truncated = diff.length > maxInputCharacters;
    final processingEnd = diff.length < maxInputCharacters
        ? diff.length
        : maxInputCharacters;

    void finishCurrent() {
      final builder = current;
      if (builder == null) {
        return;
      }
      if (files.length >= maxFiles) {
        truncated = true;
        current = null;
        return;
      }
      files.add(builder.build());
      current = null;
    }

    while (offset < processingEnd) {
      var newline = diff.indexOf('\n', offset);
      if (newline == -1 || newline > processingEnd) {
        newline = processingEnd;
      }
      var line = diff.substring(offset, newline);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      offset = newline < processingEnd ? newline + 1 : processingEnd;

      if (line.startsWith('diff --git ')) {
        finishCurrent();
        if (files.length >= maxFiles) {
          truncated = true;
          break;
        }
        current = _FileBuilder(path: _pathFromDiffHeader(line));
      }
      final builder = current;
      if (builder == null) {
        continue;
      }

      if (line.startsWith('--- ')) {
        builder.oldPath = _pathFromMarker(line.substring(4));
      } else if (line.startsWith('+++ ')) {
        builder.newPath = _pathFromMarker(line.substring(4));
      } else if (line.startsWith('+')) {
        builder.additions += 1;
      } else if (line.startsWith('-')) {
        builder.deletions += 1;
      }

      final boundedLine = line.length <= maxCharactersPerLine
          ? line
          : '${line.substring(0, maxCharactersPerLine)}…';
      final lineCharacters = boundedLine.length + 1;
      if (builder.lines.length >= maxLinesPerFile ||
          builder.storedCharacters + lineCharacters >
              maxStoredCharactersPerFile ||
          storedCharacters + lineCharacters > maxStoredCharacters) {
        builder.truncated = true;
        truncated = true;
        continue;
      }
      builder.lines.add(boundedLine);
      builder.storedCharacters += lineCharacters;
      storedCharacters += lineCharacters;
    }
    finishCurrent();

    return DiffSnapshot(
      threadId: threadId,
      turnId: turnId,
      files: List.unmodifiable(files),
      additions: files.fold(0, (sum, file) => sum + file.additions),
      deletions: files.fold(0, (sum, file) => sum + file.deletions),
      truncated: truncated,
    );
  }

  static String _pathFromDiffHeader(String line) {
    final marker = line.indexOf(' b/', 'diff --git '.length);
    if (marker == -1) {
      return 'Unknown file';
    }
    return _cleanPath(line.substring(marker + 1));
  }

  static String? _pathFromMarker(String value) {
    final metadata = value.indexOf('\t');
    final path = metadata == -1 ? value : value.substring(0, metadata);
    if (path == '/dev/null') {
      return null;
    }
    return _cleanPath(path);
  }

  static String _cleanPath(String value) {
    var path = value.trim();
    if (path.length >= 2 && path.startsWith('"') && path.endsWith('"')) {
      path = path.substring(1, path.length - 1);
    }
    if (path.startsWith('a/') || path.startsWith('b/')) {
      path = path.substring(2);
    }
    return path.isEmpty ? 'Unknown file' : path;
  }
}

final class _FileBuilder {
  _FileBuilder({required this.path});

  final String path;
  String? oldPath;
  String? newPath;
  int additions = 0;
  int deletions = 0;
  int storedCharacters = 0;
  bool truncated = false;
  final List<String> lines = [];

  DiffFile build() => DiffFile(
    path: newPath ?? oldPath ?? path,
    additions: additions,
    deletions: deletions,
    lines: List.unmodifiable(lines),
    truncated: truncated,
  );
}
