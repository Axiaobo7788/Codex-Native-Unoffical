import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef LinuxRuntimeCommandRunner = Future<LinuxRuntimeCommandResult> Function(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
});

final class LinuxRuntimeCommandResult {
  const LinuxRuntimeCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

final class LinuxRuntimeGateReport {
  const LinuxRuntimeGateReport({
    required this.bundleLibraries,
    required this.systemLibraries,
  });

  final List<String> bundleLibraries;
  final List<String> systemLibraries;
}

final class LinuxRuntimeGateException implements Exception {
  const LinuxRuntimeGateException(this.message);

  final String message;

  @override
  String toString() => 'LinuxRuntimeGateException: $message';
}

Future<LinuxRuntimeGateReport> verifyLinuxRuntimeBundle(
  Directory bundleDirectory, {
  LinuxRuntimeCommandRunner? commandRunner,
}) async {
  if (commandRunner == null && !Platform.isLinux) {
    throw const LinuxRuntimeGateException(
      'the Linux runtime gate must run on Linux',
    );
  }
  final bundle = bundleDirectory.absolute;
  final runner = File(_join(bundle.path, 'codex_native_unofficial'));
  final host = File(_join(bundle.path, 'codex-native-host'));
  final libraryDirectory = Directory(_join(bundle.path, 'lib'));
  for (final entity in <FileSystemEntity>[
    bundle,
    runner,
    host,
    libraryDirectory,
  ]) {
    if (!await entity.exists()) {
      throw LinuxRuntimeGateException(
        'Linux runtime bundle is missing ${entity.path}',
      );
    }
  }

  final run = commandRunner ?? _runCommand;
  await _requireElf64X64(runner, run);
  await _requireElf64X64(host, run);

  final runnerDynamic = await _readDynamicSection(runner, run);
  final runnerRuntimePaths = _runtimePaths(runnerDynamic);
  if (!runnerRuntimePaths.contains(r'$ORIGIN/lib')) {
    throw const LinuxRuntimeGateException(
      r'Linux app runner must use $ORIGIN/lib as its runtime library path',
    );
  }
  _rejectUnsafeRuntimePaths(runner.path, runnerRuntimePaths);

  final runnerDependencies = await _readDependencies(runner, run);
  final hostDependencies = await _readDependencies(host, run);
  final bundledByName = <String, File>{};
  await for (final entity in libraryDirectory.list(followLinks: false)) {
    if (entity is File || entity is Link) {
      bundledByName[_basename(entity.path)] = File(entity.path);
    }
  }

  final resolvedBundleLibraries = <String>{};
  final systemLibraries = <String>{};
  for (final dependency in runnerDependencies) {
    final bundled = bundledByName[dependency.name];
    if (bundled != null) {
      if (dependency.resolvedPath == null) {
        throw LinuxRuntimeGateException(
          'bundled dependency ${dependency.name} has no resolved path',
        );
      }
      final expected = await bundled.resolveSymbolicLinks();
      final actual = await File(dependency.resolvedPath!)
          .resolveSymbolicLinks();
      if (actual != expected) {
        throw LinuxRuntimeGateException(
          'bundled dependency ${dependency.name} resolved outside bundle/lib',
        );
      }
      resolvedBundleLibraries.add(dependency.name);
    } else if (dependency.resolvedPath != null) {
      systemLibraries.add(dependency.name);
    }
  }
  for (final dependency in hostDependencies) {
    if (dependency.resolvedPath != null) {
      systemLibraries.add(dependency.name);
    }
  }
  if (!resolvedBundleLibraries.contains('libflutter_linux_gtk.so')) {
    throw const LinuxRuntimeGateException(
      'Linux app runner did not resolve the bundled Flutter engine',
    );
  }

  final resolvedFiles =
      resolvedBundleLibraries.map((name) => bundledByName[name]!).toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  for (final library in resolvedFiles) {
    final dynamicSection = await _readDynamicSection(library, run);
    _rejectUnsafeRuntimePaths(library.path, _runtimePaths(dynamicSection));
  }

  final bundleNames = resolvedBundleLibraries.toList()..sort();
  final systemNames = systemLibraries.toList()..sort();
  return LinuxRuntimeGateReport(
    bundleLibraries: List.unmodifiable(bundleNames),
    systemLibraries: List.unmodifiable(systemNames),
  );
}

Future<void> _requireElf64X64(File file, LinuxRuntimeCommandRunner run) async {
  final result = await run('readelf', ['-h', file.path], workingDirectory: '/');
  if (result.exitCode != 0 ||
      !RegExp(
        r'^\s*Class:\s+ELF64\s*$',
        multiLine: true,
      ).hasMatch(result.stdout) ||
      !RegExp(
        r'^\s*Machine:\s+Advanced Micro Devices X86-64\s*$',
        multiLine: true,
      ).hasMatch(result.stdout)) {
    throw LinuxRuntimeGateException(
      'expected an ELF64 x86-64 runtime file at ${file.path}: '
      '${_boundedDiagnostic('${result.stdout}\n${result.stderr}')}',
    );
  }
}

Future<String> _readDynamicSection(
  File file,
  LinuxRuntimeCommandRunner run,
) async {
  final result = await run('readelf', ['-d', file.path], workingDirectory: '/');
  if (result.exitCode != 0) {
    throw LinuxRuntimeGateException(
      'readelf could not inspect ${file.path}: '
      '${_boundedDiagnostic('${result.stdout}\n${result.stderr}')}',
    );
  }
  return result.stdout;
}

Future<List<_LinuxDependency>> _readDependencies(
  File file,
  LinuxRuntimeCommandRunner run,
) async {
  final result = await run('env', [
    '-u',
    'LD_LIBRARY_PATH',
    '-u',
    'LD_PRELOAD',
    'ldd',
    file.path,
  ], workingDirectory: '/');
  final diagnostic = '${result.stdout}\n${result.stderr}';
  if (result.exitCode != 0) {
    throw LinuxRuntimeGateException(
      'ldd could not inspect ${file.path}: ${_boundedDiagnostic(diagnostic)}',
    );
  }
  if (RegExp(r'=>\s+not found(?:\s|$)').hasMatch(diagnostic)) {
    throw LinuxRuntimeGateException(
      'Linux runtime has an unresolved dependency for ${file.path}: '
      '${_boundedDiagnostic(diagnostic)}',
    );
  }
  return _parseLdd(result.stdout);
}

List<_LinuxDependency> _parseLdd(String output) {
  final dependencies = <_LinuxDependency>[];
  for (final line in const LineSplitter().convert(output)) {
    final withArrow = RegExp(
      r'^\s*([^\s]+)\s+=>\s+(.+?)(?:\s+\(0x[0-9a-fA-F]+\))?\s*$',
    ).firstMatch(line);
    if (withArrow != null) {
      final resolved = withArrow.group(2)!.trim();
      dependencies.add(
        _LinuxDependency(
          name: withArrow.group(1)!,
          resolvedPath: resolved == 'not found' ? null : resolved,
        ),
      );
      continue;
    }
    final absolute = RegExp(r'^\s*(/[^\s]+)\s+\(0x[0-9a-fA-F]+\)\s*$')
        .firstMatch(line);
    if (absolute != null) {
      final path = absolute.group(1)!;
      dependencies.add(
        _LinuxDependency(name: _basename(path), resolvedPath: path),
      );
    }
  }
  return dependencies;
}

List<String> _runtimePaths(String dynamicSection) {
  final result = <String>[];
  final matches = RegExp(r'\((?:RPATH|RUNPATH)\).*?\[([^\]]*)\]')
      .allMatches(dynamicSection);
  for (final match in matches) {
    for (final entry in match.group(1)!.split(':')) {
      final normalized = entry.trim().replaceAll(r'${ORIGIN}', r'$ORIGIN');
      if (normalized.isNotEmpty) {
        result.add(normalized);
      }
    }
  }
  return result;
}

void _rejectUnsafeRuntimePaths(String file, List<String> runtimePaths) {
  for (final path in runtimePaths) {
    if (!path.startsWith(r'$ORIGIN') ||
        path == r'$ORIGIN/..' ||
        path.contains(r'/../')) {
      throw LinuxRuntimeGateException(
        'runtime file $file retains a non-relocatable RUNPATH entry: $path',
      );
    }
  }
}

Future<LinuxRuntimeCommandResult> _runCommand(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  final stdoutFuture = utf8.decoder.bind(process.stdout).join();
  final stderrFuture = utf8.decoder.bind(process.stderr).join();
  late final int exitCode;
  try {
    exitCode = await process.exitCode.timeout(const Duration(seconds: 10));
  } on TimeoutException {
    process.kill();
    await process.exitCode;
    throw LinuxRuntimeGateException(
      '$executable timed out while inspecting the Linux runtime bundle',
    );
  }
  return LinuxRuntimeCommandResult(
    exitCode: exitCode,
    stdout: await stdoutFuture,
    stderr: await stderrFuture,
  );
}

String _boundedDiagnostic(String value) {
  final text = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  return text.length <= 512 ? text : '${text.substring(0, 512)}…';
}

String _join(String left, String right) {
  final separator = Platform.pathSeparator;
  return left.endsWith(separator) ? '$left$right' : '$left$separator$right';
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

final class _LinuxDependency {
  const _LinuxDependency({required this.name, required this.resolvedPath});

  final String name;
  final String? resolvedPath;
}
