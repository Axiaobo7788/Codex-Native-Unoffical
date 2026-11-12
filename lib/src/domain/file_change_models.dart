import 'output_models.dart';

enum FileChangeKind { add, delete, update, unknown }

/// Metadata only. File bodies stay in the Host until explicitly expanded.
final class FileChangeEntry {
  const FileChangeEntry({
    required this.index,
    required this.path,
    required this.kind,
    this.movePath,
    this.additions,
    this.deletions,
    this.diff,
    this.pathTruncated = false,
    this.empty = false,
  });

  final int index;
  final String path;
  final FileChangeKind kind;
  final String? movePath;
  final int? additions;
  final int? deletions;
  final OutputDescriptor? diff;
  final bool pathTruncated;

  /// Known empty legacy/raw content, distinct from a missing descriptor.
  final bool empty;

  bool get isEmpty => diff?.bytes == 0 || empty;

  FileChangeEntry withoutSessionReference() => FileChangeEntry(
    index: index,
    path: path,
    kind: kind,
    movePath: movePath,
    additions: additions,
    deletions: deletions,
    diff: diff?.withoutSessionReference(),
    pathTruncated: pathTruncated,
    empty: empty,
  );
}

final class FileChangeSet {
  const FileChangeSet({
    required this.files,
    required this.totalFiles,
    required this.truncated,
  });

  static const maxFiles = 24;
  static const maxPathCharacters = 512;

  final List<FileChangeEntry> files;
  final int totalFiles;
  final bool truncated;

  FileChangeSet withoutSessionReferences() => FileChangeSet(
    files: List.unmodifiable([
      for (final file in files) file.withoutSessionReference(),
    ]),
    totalFiles: totalFiles,
    truncated: truncated,
  );
}

enum FileChangePreviewStatus { ready, unavailable, unsupported, tooLarge }

/// One explicitly requested file, bounded independently of the saved item.
final class FileChangePreview {
  const FileChangePreview({
    required this.file,
    required this.lines,
    required this.truncated,
    this.status = FileChangePreviewStatus.ready,
  });

  static const maxLines = 80;
  static const maxLineCharacters = 512;
  static const maxStoredCharacters = 24 * 1024;
  static const maxReadBytes = 64 * 1024;

  final FileChangeEntry file;
  final List<String> lines;
  final bool truncated;
  final FileChangePreviewStatus status;

  /// Add/delete bodies are raw content; leading signs are file content.
  bool get isUnifiedDiff => file.kind == FileChangeKind.update;
}
