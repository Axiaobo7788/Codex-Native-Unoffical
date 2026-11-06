import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/child_process.dart';
import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';

const _sizes = [3 * 1024 * 1024, 30 * 1024 * 1024, 300 * 1024 * 1024];

Future<void> main() async {
  if (!Platform.isLinux) {
    stderr.writeln('HOST_MEMORY_BENCHMARK=UNSUPPORTED_PLATFORM');
    exitCode = 2;
    return;
  }
  final host = await const HostExecutableLocator().locate();
  if (host == null) {
    stderr.writeln('HOST_MEMORY_BENCHMARK=HOST_NOT_FOUND');
    exitCode = 2;
    return;
  }
  final fixture = await _buildFixture();
  stdout.writeln(
    'bytes,fixtureBaseline,fixturePeak,fixtureDelta,'
    'hostBaseline,hostPeak,hostDelta,dartBaseline,dartPeak,dartDelta',
  );
  for (final size in _sizes) {
    final result = await _runCase(
      size: size,
      hostExecutable: host,
      fixtureExecutable: fixture,
    );
    stdout.writeln(result.csv);
  }
  stdout.writeln('HOST_MEMORY_BENCHMARK=PASS');
}

Future<String> _buildFixture() async {
  final output = File(
    '${Directory.current.path}${Platform.pathSeparator}target'
    '${Platform.pathSeparator}large-output-app-server-fixture',
  );
  await output.parent.create(recursive: true);
  final result = await Process.run('rustc', [
    '--edition=2024',
    '-O',
    'tool/fixtures/large_output_app_server.rs',
    '-o',
    output.path,
  ]);
  if (result.exitCode != 0) {
    throw StateError('Fixture compilation failed: ${result.stderr}');
  }
  return output.absolute.path;
}

Future<_MemoryResult> _runCase({
  required int size,
  required String hostExecutable,
  required String fixtureExecutable,
}) async {
  final cache = await Directory.systemTemp.createTemp(
    'codex-native-host-memory-',
  );
  ProcessTransport? transport;
  Timer? sampler;
  try {
    transport = await ProcessTransport.startHost(
      hostExecutablePath: hostExecutable,
      codexExecutablePath: fixtureExecutable,
      launcher: (executable, arguments) async {
        final process = await Process.start(
          executable,
          arguments,
          environment: {
            ...Platform.environment,
            'CODEX_NATIVE_FIXTURE_BYTES': '$size',
            'CODEX_NATIVE_CACHE_DIR': cache.path,
          },
          runInShell: false,
        );
        return IoChildProcess(process);
      },
    );
    await transport.initialize(const InitializeRequest());
    final childPid = await _waitForChildPid(transport.processId);
    final fixtureBaseline = await _rss(childPid);
    final hostBaseline = await _rss(transport.processId);
    final dartBaseline = ProcessInfo.currentRss;
    var fixturePeak = fixtureBaseline;
    var hostPeak = hostBaseline;
    var dartPeak = dartBaseline;
    var sampling = false;
    sampler = Timer.periodic(const Duration(milliseconds: 2), (_) async {
      if (sampling) {
        return;
      }
      sampling = true;
      try {
        fixturePeak = math.max(fixturePeak, await _rss(childPid));
        hostPeak = math.max(hostPeak, await _rss(transport!.processId));
        dartPeak = math.max(dartPeak, ProcessInfo.currentRss);
      } finally {
        sampling = false;
      }
    });

    final page = await transport.listHistoryItems(
      const HistoryItemQuery(
        threadId: 'thread-fixture',
        turnId: 'turn-fixture',
        limit: 1,
      ),
    );
    final repeatedPage = await transport.listHistoryItems(
      const HistoryItemQuery(
        threadId: 'thread-fixture',
        turnId: 'turn-fixture',
        limit: 1,
      ),
    );
    while (sampling) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    sampler.cancel();
    sampler = null;
    fixturePeak = math.max(fixturePeak, await _rss(childPid));
    hostPeak = math.max(hostPeak, await _rss(transport.processId));
    dartPeak = math.max(dartPeak, ProcessInfo.currentRss);

    final output = page.items.single.output;
    final repeatedOutput = repeatedPage.items.single.output;
    if (output == null ||
        output.reference == null ||
        output.bytes != size ||
        output.storedBytes != size ||
        output.truncated ||
        !output.available) {
      throw StateError('Unexpected output descriptor for $size bytes.');
    }
    if (repeatedOutput == null ||
        repeatedOutput.reference != output.reference ||
        repeatedOutput.bytes != output.bytes ||
        repeatedOutput.storedBytes != output.storedBytes ||
        repeatedOutput.truncated != output.truncated ||
        !repeatedOutput.available) {
      throw StateError('Repeated output was not deduplicated for $size bytes.');
    }
    final spoolFiles = await cache
        .list(recursive: true, followLinks: false)
        .where((entry) => entry is File)
        .cast<File>()
        .toList();
    final dataFiles = spoolFiles
        .where((file) => file.path.endsWith('.data'))
        .length;
    final metadataFiles = spoolFiles
        .where((file) => file.path.endsWith('.json'))
        .length;
    final partialFiles = spoolFiles
        .where((file) => file.path.endsWith('.part'))
        .length;
    if (dataFiles != 1 || metadataFiles != 1 || partialFiles != 0) {
      throw StateError(
        'Repeated output left an unexpected spool inventory for $size bytes.',
      );
    }
    final first = await transport.readOutputRange(
      reference: output.reference!,
      offset: 0,
      length: 1024,
    );
    final last = await transport.readOutputTail(
      reference: output.reference!,
      length: 1024,
    );
    if (first.data.length != 1024 ||
        last.data.length != 1024 ||
        first.data.any((byte) => byte != 0x78) ||
        last.data.any((byte) => byte != 0x78)) {
      throw StateError('Spool range verification failed for $size bytes.');
    }

    return _MemoryResult(
      bytes: size,
      fixtureBaseline: fixtureBaseline,
      fixturePeak: fixturePeak,
      hostBaseline: hostBaseline,
      hostPeak: hostPeak,
      dartBaseline: dartBaseline,
      dartPeak: dartPeak,
    );
  } finally {
    sampler?.cancel();
    await transport?.close();
    if (await cache.exists()) {
      await cache.delete(recursive: true);
    }
  }
}

Future<int> _waitForChildPid(int hostPid) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    final children = File('/proc/$hostPid/task/$hostPid/children');
    if (await children.exists()) {
      final values = (await children.readAsString()).trim().split(' ');
      for (final value in values) {
        final pid = int.tryParse(value);
        if (pid != null) {
          return pid;
        }
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Host child PID was not observable.');
}

Future<int> _rss(int pid) async {
  try {
    final lines = await File('/proc/$pid/status').readAsLines();
    final line = lines.firstWhere((line) => line.startsWith('VmRSS:'));
    final kibibytes = int.parse(line.split(RegExp(r'\s+'))[1]);
    return kibibytes * 1024;
  } on FileSystemException {
    return 0;
  }
}

class _MemoryResult {
  const _MemoryResult({
    required this.bytes,
    required this.fixtureBaseline,
    required this.fixturePeak,
    required this.hostBaseline,
    required this.hostPeak,
    required this.dartBaseline,
    required this.dartPeak,
  });

  final int bytes;
  final int fixtureBaseline;
  final int fixturePeak;
  final int hostBaseline;
  final int hostPeak;
  final int dartBaseline;
  final int dartPeak;

  String get csv => [
    bytes,
    fixtureBaseline,
    fixturePeak,
    fixturePeak - fixtureBaseline,
    hostBaseline,
    hostPeak,
    hostPeak - hostBaseline,
    dartBaseline,
    dartPeak,
    dartPeak - dartBaseline,
  ].join(',');
}
