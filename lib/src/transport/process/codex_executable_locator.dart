import 'dart:io';

class CodexExecutableLocator {
  const CodexExecutableLocator({this.environment});

  final Map<String, String>? environment;

  Future<String?> locate() async {
    final processEnvironment = environment ?? Platform.environment;
    final override = processEnvironment['CODEX_EXECUTABLE'];
    if (override != null && override.trim().isNotEmpty) {
      final candidate = File(override).absolute;
      if (await candidate.exists()) {
        return candidate.path;
      }
    }

    final path = processEnvironment['PATH'];
    if (path == null || path.isEmpty) {
      return null;
    }

    final extensions = Platform.isWindows
        ? _windowsExtensions(processEnvironment['PATHEXT'])
        : const [''];
    for (final directory in path.split(Platform.isWindows ? ';' : ':')) {
      if (directory.isEmpty) {
        continue;
      }
      for (final extension in extensions) {
        final candidate = File(
          '$directory${Platform.pathSeparator}codex$extension',
        );
        if (await candidate.exists()) {
          return candidate.absolute.path;
        }
      }
    }
    return null;
  }

  static List<String> _windowsExtensions(String? value) {
    final configured = value
        ?.split(';')
        .where((extension) => extension.isNotEmpty)
        .map((extension) => extension.toLowerCase())
        .toList();
    return configured == null || configured.isEmpty
        ? const ['.exe', '.cmd', '.bat']
        : configured;
  }
}
