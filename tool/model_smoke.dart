import 'dart:io';

import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';

Future<void> main() async {
  final executable = await const CodexExecutableLocator().locate();
  if (executable == null) {
    stderr.writeln('MODEL_SMOKE=CODEX_NOT_FOUND');
    exitCode = 2;
    return;
  }

  ProcessTransport? transport;
  try {
    transport = await ProcessTransport.start(executablePath: executable);
    await transport.initialize(const InitializeRequest());
    final page = await transport.listModels(const ModelListQuery());
    if (page.models.isEmpty) {
      throw StateError('model/list returned no visible models.');
    }
    final defaultModel = page.models
        .where((model) => model.isDefault)
        .firstOrNull;
    if (defaultModel == null) {
      throw StateError('model/list did not identify a default model.');
    }
    if (defaultModel.supportedReasoningEfforts.isEmpty) {
      throw StateError('The default model advertised no reasoning efforts.');
    }

    stdout.writeln('MODEL_SMOKE=PASS');
    stdout.writeln('VISIBLE_MODELS=${page.models.length}');
    stdout.writeln('DEFAULT_MODEL=${defaultModel.id}');
    stdout.writeln(
      'DEFAULT_REASONING_EFFORT=${defaultModel.defaultReasoningEffort}',
    );
  } catch (error) {
    stderr.writeln('MODEL_SMOKE=FAIL');
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await transport?.close();
  }
}
