import '../domain/file_change_models.dart';
import '../domain/output_models.dart';
import 'output_protocol.dart';
import 'protocol_models.dart';

/// Projects statistics without retaining a diff body or a raw protocol map.
String fileChangeSummary(Object? changes) =>
    parseFileChanges(changes, includeMetadata: false).summary;

final class FileChangeProjection {
  const FileChangeProjection(this.summary, this.changes);
  final String summary;
  final FileChangeSet changes;
}

/// Limits count UTF-16 code units, not bytes. Unknown/bounded statistics never
/// masquerade as exact partial totals. Metadata is independent of body loading.
FileChangeProjection parseFileChanges(
  Object? raw, {
  bool includeMetadata = true,
}) {
  final count = raw is List<Object?> ? raw.length : 0;
  final caption = 'File changes: $count update(s)';
  final files = <FileChangeEntry>[];
  var exact = raw is List<Object?> && raw.length <= 100;
  var remainingCharacters = 2 * 1024 * 1024;
  var additions = 0;
  var deletions = 0;
  if (raw is List<Object?>) {
    for (var index = 0; index < raw.length && index < 100; index++) {
      final entry = raw[index];
      if (entry is! Map<String, Object?>) {
        exact = false;
        continue;
      }
      final diff = entry['diff'];
      final rawLength =
          entry['_codexNativeFileDiff'] is! Map<String, Object?> &&
              diff is String &&
              !(_nonnegativeInt(entry['additions']) != null &&
                  _nonnegativeInt(entry['deletions']) != null)
          ? diff.length
          : 0;
      final stats = rawLength <= remainingCharacters ? _lineStats(entry) : null;
      remainingCharacters -= rawLength;
      if (stats == null) {
        exact = false;
      } else {
        additions += stats.additions;
        deletions += stats.deletions;
      }
      if (!includeMetadata || index >= FileChangeSet.maxFiles) continue;
      final path = entry['path'];
      if (path is! String) continue;
      final rawKind = entry['kind'];
      final kindName = rawKind == null
          ? 'update'
          : rawKind is Map<String, Object?>
          ? rawKind['type']
          : null;
      final kind = switch (kindName) {
        'add' => FileChangeKind.add,
        'delete' => FileChangeKind.delete,
        'update' => FileChangeKind.update,
        _ => FileChangeKind.unknown,
      };
      final move = rawKind is Map<String, Object?>
          ? rawKind['move_path']
          : null;
      final rawDescriptor = entry['_codexNativeFileDiff'];
      final reference = rawDescriptor is Map<String, Object?>
          ? rawDescriptor['ref']
          : null;
      OutputDescriptor? descriptor;
      if (kind != FileChangeKind.unknown &&
          rawDescriptor is Map<String, Object?> &&
          (reference == null ||
              reference is String && reference.length <= 128)) {
        try {
          descriptor = OutputProtocolAdapter.descriptorFromItem(rawDescriptor);
        } on ProtocolViolation {
          // Malformed optional metadata is not an authority to read a body.
        }
      }
      files.add(
        FileChangeEntry(
          index: index,
          path: _boundedPath(path),
          kind: kind,
          movePath: move is String ? _boundedPath(move) : null,
          additions: stats?.additions,
          deletions: stats?.deletions,
          diff: descriptor,
          empty: rawDescriptor == null && diff is String && diff.isEmpty,
          pathTruncated:
              path.length > FileChangeSet.maxPathCharacters ||
              move is String && move.length > FileChangeSet.maxPathCharacters,
        ),
      );
    }
  }
  return FileChangeProjection(
    exact && (additions != 0 || deletions != 0)
        ? '$caption (+$additions -$deletions)'
        : caption,
    FileChangeSet(
      files: List.unmodifiable(files),
      totalFiles: count,
      truncated: count > files.length,
    ),
  );
}

String _boundedPath(String path) {
  if (path.length <= FileChangeSet.maxPathCharacters) return path;
  var end = FileChangeSet.maxPathCharacters;
  final last = path.codeUnitAt(end - 1);
  if (last >= 0xd800 && last <= 0xdbff) end--;
  return path.substring(0, end);
}

({int additions, int deletions})? _lineStats(Map<String, Object?> entry) {
  final explicitAdd = _nonnegativeInt(entry['additions']);
  final explicitDelete = _nonnegativeInt(entry['deletions']);
  if (explicitAdd != null && explicitDelete != null) {
    return (additions: explicitAdd, deletions: explicitDelete);
  }
  final rawKind = entry['kind'];
  final kind = rawKind == null
      ? 'update'
      : rawKind is Map<String, Object?>
      ? rawKind['type']
      : null;
  if (kind != 'add' && kind != 'delete' && kind != 'update') return null;
  final native = entry['_codexNativeFileDiff'];
  if (native is Map<String, Object?>) {
    final stats = native['lineStats'];
    if (stats is! Map<String, Object?>) return null;
    final lines = _nonnegativeInt(stats['contentLines']);
    final add = _nonnegativeInt(stats['additions']);
    final del = _nonnegativeInt(stats['deletions']);
    if (lines == null || add == null || del == null) return null;
    return (
      additions:
          explicitAdd ??
          (kind == 'add'
              ? lines
              : kind == 'delete'
              ? 0
              : add),
      deletions:
          explicitDelete ??
          (kind == 'delete'
              ? lines
              : kind == 'add'
              ? 0
              : del),
    );
  }
  final diff = entry['diff'];
  if (diff is! String || diff.length > 256 * 1024) return null;
  var added = 0;
  var deleted = 0;
  var insideHunk = false;
  for (var offset = 0; offset < diff.length;) {
    if (kind == 'add') {
      added++;
    } else if (kind == 'delete') {
      deleted++;
    } else if (diff.startsWith('@@', offset)) {
      insideHunk = true;
    } else if (diff.startsWith('diff --git ', offset)) {
      insideHunk = false;
    } else {
      final first = diff.codeUnitAt(offset);
      if (first == 0x2b && (insideHunk || !diff.startsWith('+++', offset))) {
        added++;
      } else if (first == 0x2d &&
          (insideHunk || !diff.startsWith('---', offset))) {
        deleted++;
      }
    }
    final newline = diff.indexOf('\n', offset);
    if (newline < 0) break;
    offset = newline + 1;
  }
  return (
    additions: explicitAdd ?? added,
    deletions: explicitDelete ?? deleted,
  );
}

int? _nonnegativeInt(Object? value) =>
    value is int && value >= 0 ? value : null;
