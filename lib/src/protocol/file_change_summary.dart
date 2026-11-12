/// Projects stock FileUpdateChange statistics without retaining diff bodies.
///
/// Add/delete `diff` values are raw file contents; update values are unified
/// hunks. A bounded or unknown input produces a count-only caption, never an
/// exact-looking partial total. Limits count UTF-16 code units, not bytes.
String fileChangeSummary(Object? rawChanges) {
  final count = rawChanges is List<Object?> ? rawChanges.length : 0;
  final caption = 'File changes: $count update(s)';
  if (rawChanges is! List<Object?> || rawChanges.length > 100) {
    return caption;
  }
  var remainingCharacters = 2 * 1024 * 1024;
  var additions = 0;
  var deletions = 0;
  for (final entry in rawChanges) {
    if (entry is! Map<String, Object?>) return caption;
    final explicitAdd = _nonnegativeInt(entry['additions']);
    final explicitDelete = _nonnegativeInt(entry['deletions']);
    if (explicitAdd != null && explicitDelete != null) {
      additions += explicitAdd;
      deletions += explicitDelete;
      continue;
    }
    final rawKind = entry['kind'];
    // Older fixtures/runtimes supplied a unified diff without a kind object.
    final kind = rawKind == null
        ? 'update'
        : rawKind is Map<String, Object?>
        ? rawKind['type']
        : null;
    if (kind != 'add' && kind != 'delete' && kind != 'update') return caption;
    final diff = entry['diff'];
    if (diff is! String ||
        diff.length > 256 * 1024 ||
        diff.length > remainingCharacters) {
      return caption;
    }
    remainingCharacters -= diff.length;
    var added = 0;
    var deleted = 0;
    var insideHunk = false;
    for (var offset = 0; offset < diff.length;) {
      if (kind == 'add') {
        added += 1;
      } else if (kind == 'delete') {
        deleted += 1;
      } else if (diff.startsWith('@@', offset)) {
        insideHunk = true;
      } else if (diff.startsWith('diff --git ', offset)) {
        insideHunk = false;
      } else {
        final first = diff.codeUnitAt(offset);
        if (first == 0x2b && (insideHunk || !diff.startsWith('+++', offset))) {
          added += 1;
        } else if (first == 0x2d &&
            (insideHunk || !diff.startsWith('---', offset))) {
          deleted += 1;
        }
      }
      final newline = diff.indexOf('\n', offset);
      if (newline < 0) break;
      offset = newline + 1;
    }
    additions += explicitAdd ?? added;
    deletions += explicitDelete ?? deleted;
  }
  if (additions == 0 && deletions == 0) return caption;
  return '$caption (+$additions -$deletions)';
}

int? _nonnegativeInt(Object? value) =>
    value is int && value >= 0 ? value : null;
