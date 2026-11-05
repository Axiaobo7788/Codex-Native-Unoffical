import 'dart:io';

class HostExecutableLocator {
  const HostExecutableLocator({
    this.environment,
    this.resolvedExecutable,
    this.currentDirectory,
  });

  final Map<String, String>? environment;
  final String? resolvedExecutable;
  final String? currentDirectory;

  Future<String?> locate() async {
    final processEnvironment = environment ?? Platform.environment;
    final override = processEnvironment['CODEX_NATIVE_HOST'];
    if (override != null && override.trim().isNotEmpty) {
      final candidate = File(override).absolute;
      if (await candidate.exists()) {
        return candidate.path;
      }
    }

    final executableName = Platform.isWindows
        ? 'codex-native-host.exe'
        : 'codex-native-host';
    final application = File(resolvedExecutable ?? Platform.resolvedExecutable)
        .absolute;
    final adjacent = File(
      '${application.parent.path}${Platform.pathSeparator}$executableName',
    );
    if (await adjacent.exists()) {
      return adjacent.path;
    }

    final fromPath = await _fromPath(
      executableName: executableName,
      path: processEnvironment['PATH'],
    );
    if (fromPath != null) {
      return fromPath;
    }

    final workingDirectory = Directory(
      currentDirectory ?? Directory.current.path,
    ).absolute;
    for (final profile in const ['release', 'debug']) {
      final candidate = File(
        '${workingDirectory.path}${Platform.pathSeparator}target'
        '${Platform.pathSeparator}$profile'
        '${Platform.pathSeparator}$executableName',
      );
      if (await candidate.exists()) {
        return candidate.path;
      }
    }
    return null;
  }

  static Future<String?> _fromPath({
    required String executableName,
    required String? path,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }
    final separator = Platform.isWindows ? ';' : ':';
    for (final directory in path.split(separator)) {
      if (directory.isEmpty) {
        continue;
      }
      final candidate = File(
        '$directory${Platform.pathSeparator}$executableName',
      );
      if (await candidate.exists()) {
        return candidate.absolute.path;
      }
    }
    return null;
  }
}
