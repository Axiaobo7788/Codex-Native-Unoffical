import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:codex_native_unofficial/src/domain/mcp_oauth_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/transport/process/child_process.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Unit/widget lifecycle cases inject discovery and minimal initialization/status
// contracts through production transport/adapters. They launch no stock process;
// packaged real-stock startup verification is a separate evidence class.
void main() {
  test(
    'OAuth completion can retire the runtime without recursive relay writes',
    () async {
      final child = _InitializeChild();
      final controller = RuntimeController(
        locator: _DeferredLocator(Future.value('/fixture/codex')),
        hostLocator: _FixedHostLocator(),
        transportStarter: (_, _) => _transport(child),
      );
      Future<void>? stopping;
      final events = <McpOauthEvent>[];
      final subscription = controller.mcpOauthEvents.listen((event) {
        events.add(event);
        if (event is McpOauthCompleted) stopping = controller.shutdown();
      });
      try {
        await controller.start();
        final completed = jsonEncode({
          'method': 'mcpServer/oauthLogin/completed',
          'params': {
            'name': 'fixture-mcp',
            'success': true,
            'loginId': 'fixture-login',
          },
        });
        child.output.add(utf8.encode('$completed\n'));
        await pumpEventQueue();
        await stopping;
        expect(stopping, isNotNull);
        expect(events.whereType<McpOauthCompleted>(), hasLength(1));
        expect(events.whereType<McpOauthInvalidated>(), hasLength(1));
        expect(controller.snapshot.state, RuntimeConnectionState.stopped);
      } finally {
        await subscription.cancel();
        await controller.shutdown();
        controller.dispose();
        await child.dispose();
      }
    },
  );

  test(
    'queued runtime relay never delivers a notification after retirement',
    () async {
      final child = _InitializeChild();
      late ProcessTransport transport;
      final controller = RuntimeController(
        locator: _DeferredLocator(Future.value('/fixture/codex')),
        hostLocator: _FixedHostLocator(),
        transportStarter: (_, _) async => transport = await _transport(child),
      );
      Future<void>? stopping;
      StreamSubscription<ThreadLifecycleEvent>? stopSubscription;
      final deliveryStillCurrent = <bool>[];
      final relay = controller.threadEvents.listen((event) {
        deliveryStillCurrent.add(controller.supportsThreadAttachments);
      });
      try {
        await controller.start();
        expect(controller.supportsThreadAttachments, isTrue);
        // This second transport listener retires the epoch after RuntimeController
        // forwards to its application relay but before async relay delivery.
        stopSubscription = transport.threadEvents.listen((_) {
          stopping = controller.shutdown();
        });
        child.status('at-retirement-boundary');
        await pumpEventQueue();
        await stopping;
        expect(stopping, isNotNull);
        expect(deliveryStillCurrent, isNot(contains(false)));
      } finally {
        await stopSubscription?.cancel();
        await relay.cancel();
        await controller.shutdown();
        controller.dispose();
        await child.dispose();
      }
    },
  );

  test(
    'connected recovery retires one session before one admitted restart',
    () async {
      final children = [_InitializeChild(), _InitializeChild()];
      var launches = 0;
      final controller = RuntimeController(
        locator: _DeferredLocator(Future.value('/fixture/codex')),
        hostLocator: _FixedHostLocator(),
        transportStarter: (_, _) {
          if (launches != 0) expect(children.first.closeInputCount, 1);
          return _transport(children[launches++]);
        },
      );
      final events = <ThreadLifecycleEvent>[];
      final subscription = controller.threadEvents.listen(events.add);
      try {
        await controller.recoverWorkspace();
        expect(launches, 0);
        await controller.start();
        children.first.exit(42);
        await pumpEventQueue();
        expect(controller.canRecoverWorkspace, isTrue);
        expect(controller.canRetryStartup, isFalse);
        final recovery = controller.recoverWorkspace();
        expect(identical(recovery, controller.recoverWorkspace()), isTrue);
        await recovery;
        expect(launches, 2);
        expect(controller.snapshot.state, RuntimeConnectionState.connected);
        children.first.status('retired-session');
        children.last.status('fresh-session');
        await pumpEventQueue();
        expect(
          events.whereType<ThreadStatusChangedEvent>().map((e) => e.threadId),
          ['fresh-session'],
        );
      } finally {
        await subscription.cancel();
        await controller.shutdown();
        controller.dispose();
        for (final child in children) {
          await child.dispose();
        }
      }
    },
  );

  test('shutdown during recovery admission prevents another Host', () async {
    final child = _InitializeChild();
    var launches = 0;
    final controller = RuntimeController(
      locator: _DeferredLocator(Future.value('/fixture/codex')),
      hostLocator: _FixedHostLocator(),
      transportStarter: (_, _) {
        launches += 1;
        return _transport(child);
      },
    );
    Future<void>? stopping;
    try {
      await controller.start();
      child.exit(42);
      await pumpEventQueue();
      controller.addListener(() {
        if (controller.snapshot.state == RuntimeConnectionState.starting) {
          stopping = controller.shutdown();
        }
      });
      await controller.recoverWorkspace();
      await stopping;
      expect(launches, 1);
      expect(controller.snapshot.state, RuntimeConnectionState.stopped);
      expect(controller.canRecoverWorkspace, isFalse);
    } finally {
      await controller.shutdown();
      controller.dispose();
      await child.dispose();
    }
  });

  test('an older recovery cannot reset a reentrant retry admission', () async {
    final children = [
      _InitializeChild(),
      _InitializeChild(failInitialize: true),
      _InitializeChild(),
    ];
    final third = Completer<ProcessTransport>();
    var launches = 0;
    final controller = RuntimeController(
      locator: _DeferredLocator(Future.value('/fixture/codex')),
      hostLocator: _FixedHostLocator(),
      transportStarter: (_, _) {
        final index = launches++;
        return index == 2 ? third.future : _transport(children[index]);
      },
    );
    Future<void>? retry;
    try {
      await controller.start();
      children.first.exit(42);
      await pumpEventQueue();
      controller.addListener(() {
        if (launches == 2 && controller.canRecoverWorkspace) {
          retry = controller.recoverWorkspace();
        }
      });
      await controller.recoverWorkspace();
      await pumpEventQueue();
      expect(launches, 3);
      expect(identical(controller.recoverWorkspace(), retry), isTrue);
      third.complete(await _transport(children.last));
      await retry;
      expect(controller.snapshot.state, RuntimeConnectionState.connected);
    } finally {
      if (!third.isCompleted) third.complete(await _transport(children.last));
      await controller.shutdown();
      controller.dispose();
      for (final child in children) {
        await child.dispose();
      }
    }
  });

  testWidgets(
    'failed discovery can be retried explicitly on the same runtime instance',
    (tester) async {
      final locator = _MutableLocator();
      var launchCount = 0;
      final controller = RuntimeController(
        locator: locator,
        hostLocator: _FixedHostLocator(),
        transportStarter: (hostPath, codexPath) async {
          expect(hostPath, '/fixture/host');
          expect(codexPath, '/fixture/codex');
          launchCount += 1;
          throw StateError('Fixture launch reached after discovery retry');
        },
      );
      addTearDown(() async {
        await controller.shutdown();
        controller.dispose();
      });
      await tester.runAsync(controller.start);
      await tester.pumpWidget(CodexNativeApp(runtimeController: controller));
      await tester.pumpAndSettle();
      expect(controller.snapshot.state, RuntimeConnectionState.notFound);
      expect(launchCount, 0);

      final retry = find.byKey(const ValueKey('runtime-startup-retry'));
      expect(retry, findsOneWidget);
      // The widget test projects a typed discovery change. Actual filesystem
      // availability and real Host startup belong to the process/packaged walk.
      locator.path = '/fixture/codex';
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(launchCount, 1);
      expect(controller.snapshot.state, RuntimeConnectionState.error);
      expect(
        controller.snapshot.message,
        contains('Fixture launch reached after discovery retry'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'failed initialization retires the old session before one fresh retry',
    () async {
      final children = [
        _InitializeChild(failInitialize: true),
        _InitializeChild(),
      ];
      var launches = 0;
      final controller = RuntimeController(
        locator: _DeferredLocator(Future.value('/fixture/codex')),
        hostLocator: _FixedHostLocator(),
        transportStarter: (_, _) => _transport(children[launches++]),
      );
      final events = <ThreadLifecycleEvent>[];
      final subscription = controller.threadEvents.listen(events.add);
      try {
        await controller.start();
        expect(controller.snapshot.state, RuntimeConnectionState.error);
        expect(
          controller.snapshot.message,
          contains('Fixture initialize failed'),
        );
        expect(children.first.closeInputCount, 1);
        expect(controller.canRetryStartup, isTrue);

        final retry = controller.retryStartup();
        final joined = controller.retryStartup();
        expect(identical(retry, joined), isTrue);
        await retry;
        expect(launches, 2);
        expect(controller.snapshot.state, RuntimeConnectionState.connected);
        expect(controller.canRetryStartup, isFalse);
        children.first.status('old-thread');
        children.last.status('fresh-thread');
        await pumpEventQueue();
        expect(
          events.whereType<ThreadStatusChangedEvent>().map((e) => e.threadId),
          ['fresh-thread'],
        );

        children.last.exit(42);
        await pumpEventQueue();
        expect(controller.snapshot.state, RuntimeConnectionState.processExited);
        expect(controller.canRetryStartup, isFalse);
        await controller.retryStartup();
        expect(
          launches,
          2,
        ); // Startup retry remains distinct from explicit workspace recovery.
      } finally {
        await subscription.cancel();
        await controller.shutdown();
        controller.dispose();
        for (final child in children) {
          await child.dispose();
        }
      }
    },
  );

  for (final phase in [
    RuntimeConnectionState.locating,
    RuntimeConnectionState.starting,
  ]) {
    test(
      'shutdown from $phase notification prevents a later Host launch',
      () async {
        var launches = 0;
        Future<void>? stopping;
        final controller = RuntimeController(
          locator: _DeferredLocator(Future.value('/fixture/codex')),
          hostLocator: _FixedHostLocator(),
          transportStarter: (_, _) async {
            launches += 1;
            throw StateError('Host launched after a terminal notification');
          },
        );
        controller.addListener(() {
          if (controller.snapshot.state == phase) {
            stopping = controller.shutdown();
          }
        });
        await controller.start();
        await stopping;
        expect(launches, 0);
        expect(controller.snapshot.state, RuntimeConnectionState.stopped);
        controller.dispose();
      },
    );
  }

  test('shutdown closes a late Host startup without initializing it', () async {
    final child = _InitializeChild();
    final launched = Completer<void>();
    final pending = Completer<ProcessTransport>();
    final controller = RuntimeController(
      locator: _DeferredLocator(Future.value('/fixture/codex')),
      hostLocator: _FixedHostLocator(),
      transportStarter: (_, _) {
        launched.complete();
        return pending.future;
      },
    );
    final startup = controller.start();
    await launched.future;
    await controller.shutdown();
    pending.complete(await _transport(child));
    await startup;
    expect(controller.snapshot.state, RuntimeConnectionState.stopped);
    expect(child.closeInputCount, 1);
    expect(child.initializeCount, 0);
    controller.dispose();
    await child.dispose();
  });

  test('shutdown wins over a pending local discovery result', () async {
    final lookup = Completer<String?>();
    final controller = RuntimeController(
      locator: _DeferredLocator(lookup.future),
    );
    final startup = controller.start();
    expect(controller.snapshot.state, RuntimeConnectionState.locating);
    await controller.shutdown();
    lookup.complete(null);
    await startup;
    expect(controller.snapshot.state, RuntimeConnectionState.stopped);
    controller.dispose();
  });
}

class _DeferredLocator extends CodexExecutableLocator {
  _DeferredLocator(this.lookup);

  final Future<String?> lookup;

  @override
  Future<String?> locate() => lookup;
}

class _FixedHostLocator extends HostExecutableLocator {
  @override
  Future<String?> locate() async => '/fixture/host';
}

Future<ProcessTransport> _transport(_InitializeChild child) =>
    ProcessTransport.start(
      executablePath: '/fixture/codex',
      launcher: (_, _) async => child,
      shutdownTimeout: const Duration(milliseconds: 20),
    );

// Only initialize success/failure and a typed lifecycle notification are
// supplied. Protocol parsing/correlation run through the real transport.
final class _InitializeChild implements ChildProcess {
  _InitializeChild({this.failInitialize = false});

  final bool failInitialize;
  final output = StreamController<List<int>>();
  final errors = StreamController<List<int>>();
  final completion = Completer<int>();
  var closeInputCount = 0;
  var initializeCount = 0;

  @override
  int get pid => 4242;
  @override
  Stream<List<int>> get stdout => output.stream;
  @override
  Stream<List<int>> get stderr => errors.stream;
  @override
  Future<int> get exitCode => completion.future;

  @override
  Future<void> write(String data) async {
    if (closeInputCount != 0) throw StateError('Fixture stdin closed');
    final message = jsonDecode(data) as Map<String, Object?>;
    if (message['method'] == 'initialize') {
      initializeCount += 1;
      output.add(
        utf8.encode(
          '${jsonEncode({
            'id': message['id'],
            if (failInitialize) 'error': {'code': -32603, 'message': 'Fixture initialize failed'} else 'result': {'userAgent': 'startup-retry-fixture'},
          })}\n',
        ),
      );
    }
  }

  void status(String threadId) {
    output.add(
      utf8.encode(
        '${jsonEncode({
          'method': 'thread/status/changed',
          'params': {
            'threadId': threadId,
            'status': {'type': 'idle'},
          },
        })}\n',
      ),
    );
  }

  void exit(int code) {
    if (!completion.isCompleted) completion.complete(code);
  }

  @override
  Future<void> closeInput() async {
    closeInputCount += 1;
    exit(0);
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    exit(-signal.signalNumber);
    return true;
  }

  Future<void> dispose() async {
    await output.close();
    await errors.close();
  }
}

class _MutableLocator extends CodexExecutableLocator {
  String? path;

  @override
  Future<String?> locate() async => path;
}
