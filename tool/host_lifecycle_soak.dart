import 'dart:io';

import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';

Future<void> main() async {
  if (!Platform.isLinux) {
    stderr.writeln('HOST_LIFECYCLE_SOAK=LINUX_ONLY');
    exitCode = 2;
    return;
  }
  final executable = await const CodexExecutableLocator().locate();
  final host = await const HostExecutableLocator().locate();
  if (executable == null || host == null) {
    stderr.writeln('HOST_LIFECYCLE_SOAK=RUNTIME_NOT_FOUND');
    exitCode = 2;
    return;
  }
  final iterations = _iterations();
  final cacheRoot = _cacheRoot();
  final sessionsBefore = await _sessionNames(cacheRoot);
  final shutdownMillis = <int>[];
  final observedChildren = <int>{};

  try {
    for (var index = 0; index < iterations; index += 1) {
      final transport = await ProcessTransport.startHost(
        hostExecutablePath: host,
        codexExecutablePath: executable,
      );
      final hostPid = transport.processId;
      final childPids = <int>[];
      try {
        await transport.initialize(const InitializeRequest());
        await transport.listThreads(const ThreadListQuery(limit: 1));
        childPids.addAll(await _directChildren(hostPid));
        if (childPids.isEmpty) {
          throw StateError('Host $hostPid exposed no Codex child in /proc.');
        }
        observedChildren.addAll(childPids);
      } finally {
        final shutdown = Stopwatch()..start();
        await transport.close();
        shutdown.stop();
        shutdownMillis.add(shutdown.elapsedMilliseconds);
      }

      final survivors = [
        hostPid,
        ...childPids,
      ].where((pid) => Directory('/proc/$pid').existsSync()).toList();
      if (survivors.isNotEmpty) {
        throw StateError('Lifecycle iteration $index left PIDs $survivors.');
      }
    }

    final sessionsAfter = await _sessionNames(cacheRoot);
    final leakedSessions = sessionsAfter.difference(sessionsBefore);
    if (leakedSessions.isNotEmpty) {
      throw StateError('Lifecycle soak left sessions $leakedSessions.');
    }
    final total = shutdownMillis.fold<int>(0, (sum, value) => sum + value);
    final maximum = shutdownMillis.reduce((a, b) => a > b ? a : b);
    stdout.writeln('HOST_LIFECYCLE_SOAK=PASS');
    stdout.writeln('ITERATIONS=$iterations');
    stdout.writeln('OBSERVED_CODEX_CHILDREN=${observedChildren.length}');
    stdout.writeln('MAX_SHUTDOWN_MS=$maximum');
    stdout.writeln('MEAN_SHUTDOWN_MS=${total ~/ shutdownMillis.length}');
    stdout.writeln('LEAKED_PIDS=0');
    stdout.writeln('LEAKED_SESSIONS=0');
  } catch (error, stackTrace) {
    stderr.writeln('HOST_LIFECYCLE_SOAK=FAIL');
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

int _iterations() {
  final raw = Platform.environment['CODEX_NATIVE_SOAK_ITERATIONS'];
  final parsed = raw == null ? 12 : int.tryParse(raw);
  if (parsed == null || parsed < 1 || parsed > 50) {
    throw ArgumentError(
      'CODEX_NATIVE_SOAK_ITERATIONS must be between 1 and 50.',
    );
  }
  return parsed;
}

String _cacheRoot() {
  final override = Platform.environment['CODEX_NATIVE_CACHE_DIR'];
  if (override != null && override.isNotEmpty) {
    return override;
  }
  final base = Platform.environment['XDG_CACHE_HOME'];
  if (base != null && base.isNotEmpty) {
    return '$base/codex-native-unofficial/host-output';
  }
  final userHome = Platform.environment['HOME'];
  if (userHome == null || userHome.isEmpty) {
    throw StateError('Neither XDG_CACHE_HOME nor HOME is available.');
  }
  return '$userHome/.cache/codex-native-unofficial/host-output';
}

Future<Set<String>> _sessionNames(String root) async {
  final directory = Directory(root);
  if (!await directory.exists()) {
    return {};
  }
  return directory
      .list()
      .where((entry) => entry is Directory)
      .map((entry) => entry.uri.pathSegments)
      .where((segments) => segments.isNotEmpty)
      .map((segments) => segments[segments.length - 2])
      .where((name) => name.startsWith('session-'))
      .toSet();
}

Future<List<int>> _directChildren(int pid) async {
  final value = await File('/proc/$pid/task/$pid/children').readAsString();
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(int.parse)
      .toList();
}
