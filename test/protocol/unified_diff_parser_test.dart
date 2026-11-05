import 'package:codex_native_unofficial/src/protocol/unified_diff_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses changed files and line counts without retaining raw input', () {
    const parser = UnifiedDiffParser();
    final snapshot = parser.parse(
      threadId: 'thread-1',
      turnId: 'turn-1',
      diff: '''diff --git a/lib/a.dart b/lib/a.dart
index 111..222 100644
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1,2 +1,3 @@
 unchanged
-old
+new
+added
diff --git a/test/new_test.dart b/test/new_test.dart
new file mode 100644
--- /dev/null
+++ b/test/new_test.dart
@@ -0,0 +1 @@
+test
''',
    );

    expect(snapshot.files, hasLength(2));
    expect(snapshot.files[0].path, 'lib/a.dart');
    expect(snapshot.files[0].additions, 2);
    expect(snapshot.files[0].deletions, 1);
    expect(snapshot.files[1].path, 'test/new_test.dart');
    expect(snapshot.additions, 3);
    expect(snapshot.deletions, 1);
    expect(snapshot.truncated, isFalse);
  });

  test('caps processed input and retained lines', () {
    const parser = UnifiedDiffParser(
      maxInputCharacters: 160,
      maxFiles: 2,
      maxStoredCharacters: 80,
      maxStoredCharactersPerFile: 60,
      maxLinesPerFile: 3,
      maxCharactersPerLine: 20,
    );
    final snapshot = parser.parse(
      threadId: 'thread-1',
      turnId: 'turn-1',
      diff:
          'diff --git a/a b/a\n--- a/a\n+++ b/a\n'
          '${List.filled(30, '+a very long added line').join('\n')}\n',
    );

    expect(snapshot.truncated, isTrue);
    expect(snapshot.files.single.truncated, isTrue);
    expect(snapshot.files.single.lines.length, lessThanOrEqualTo(3));
    expect(
      snapshot.files.single.lines.every((line) => line.length <= 21),
      isTrue,
    );
  });
}
