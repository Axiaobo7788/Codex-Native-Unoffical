import 'dart:io';

import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';

Future<void> main() async {
  final executable = await const CodexExecutableLocator().locate();
  if (executable == null) {
    stderr.writeln('THREAD_SMOKE=CODEX_NOT_FOUND');
    exitCode = 2;
    return;
  }
  final host = await const HostExecutableLocator().locate();
  if (host == null) {
    stderr.writeln('THREAD_SMOKE=HOST_NOT_FOUND');
    exitCode = 2;
    return;
  }

  ProcessTransport? transport;
  String? smokeThreadId;
  try {
    transport = await ProcessTransport.startHost(
      hostExecutablePath: host,
      codexExecutablePath: executable,
    );
    await transport.initialize(const InitializeRequest());

    final page = await transport.listThreads(
      const ThreadListQuery(
        limit: 10,
        sortKey: ThreadSortKey.createdAt,
        sortDirection: SortDirection.ascending,
      ),
    );
    if (page.threads.isEmpty) {
      throw StateError(
        'No persistent thread is available to verify thread/read and resume.',
      );
    }
    final existing = page.threads.first;
    final read = await transport.readThread(existing.id);
    final resumed = await transport.resumeThread(existing.id);
    if (read.id != existing.id || resumed.id != existing.id) {
      throw StateError('Thread identity changed across list/read/resume.');
    }

    final started = await transport.startThread(
      ThreadStartOptions(cwd: Directory.current.path),
    );
    smokeThreadId = started.id;

    stdout.writeln('THREAD_SMOKE=PASS');
    stdout.writeln('LISTED_THREADS=${page.threads.length}');
    stdout.writeln('READ_EXISTING_THREAD=true');
    stdout.writeln('EPHEMERAL_THREAD=${started.ephemeral}');
    stdout.writeln('RESUMED_STATUS=${resumed.status.name}');
  } catch (error) {
    stderr.writeln('THREAD_SMOKE=FAIL');
    stderr.writeln(error);
    final stderrTail = transport?.stderrTail.trim();
    if (stderrTail != null && stderrTail.isNotEmpty) {
      stderr.writeln(stderrTail);
    }
    exitCode = 1;
  } finally {
    if (transport != null && smokeThreadId != null) {
      try {
        await transport.deleteThread(smokeThreadId);
        stdout.writeln('SMOKE_THREAD_CLEANED=true');
      } catch (error) {
        stderr.writeln('SMOKE_THREAD_CLEANUP=FAIL');
        stderr.writeln(error);
        exitCode = 1;
      }
    }
    await transport?.close();
  }
}
