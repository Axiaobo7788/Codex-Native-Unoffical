import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'src/app/codex_native_app.dart';
import 'src/app/runtime_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = RuntimeController();
  final signalSubscriptions = <StreamSubscription<ProcessSignal>>[];
  Future<void>? shutdownOperation;

  Future<void> shutdown() => shutdownOperation ??= () async {
    await controller.shutdown();
    for (final subscription in signalSubscriptions) {
      await subscription.cancel();
    }
    controller.dispose();
  }();

  if (Platform.isLinux || Platform.isMacOS) {
    void handleSignal(ProcessSignal signal) {
      unawaited(shutdown().whenComplete(() => exit(0)));
    }

    signalSubscriptions
      ..add(ProcessSignal.sigterm.watch().listen(handleSignal))
      ..add(ProcessSignal.sigint.watch().listen(handleSignal));
  }

  runApp(
    CodexNativeApp(runtimeController: controller, shutdownHandler: shutdown),
  );
}
