import 'dart:io';

import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';

Future<void> main() async {
  final executable = await const CodexExecutableLocator().locate();
  if (executable == null) {
    stderr.writeln('RUNTIME_SMOKE=CODEX_NOT_FOUND');
    exitCode = 2;
    return;
  }

  ProcessTransport? transport;
  try {
    transport = await ProcessTransport.start(executablePath: executable);
    final result = await transport.initialize(const InitializeRequest());
    stdout.writeln('RUNTIME_SMOKE=PASS');
    stdout.writeln('CODEX_EXECUTABLE=$executable');
    stdout.writeln('APP_SERVER_USER_AGENT=${result.userAgent}');
  } catch (error) {
    stderr.writeln('RUNTIME_SMOKE=FAIL');
    stderr.writeln(error);
    final stderrTail = transport?.stderrTail.trim();
    if (stderrTail != null && stderrTail.isNotEmpty) {
      stderr.writeln(stderrTail);
    }
    exitCode = 1;
  } finally {
    await transport?.close();
  }
}
