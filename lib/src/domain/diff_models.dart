class DiffFile {
  const DiffFile({
    required this.path,
    required this.additions,
    required this.deletions,
    required this.lines,
    required this.truncated,
  });

  final String path;
  final int additions;
  final int deletions;
  final List<String> lines;
  final bool truncated;
}

class DiffSnapshot {
  const DiffSnapshot({
    required this.threadId,
    required this.turnId,
    required this.files,
    required this.additions,
    required this.deletions,
    required this.truncated,
  });

  final String threadId;
  final String turnId;
  final List<DiffFile> files;
  final int additions;
  final int deletions;
  final bool truncated;
}
