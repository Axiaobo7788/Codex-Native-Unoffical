import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/child_process.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeChildProcess child;
  late ProcessTransport transport;

  setUp(() async {
    child = _FakeChildProcess();
    transport = await ProcessTransport.start(
      executablePath: '/test/codex',
      launcher: (executable, arguments) async {
        expect(executable, '/test/codex');
        expect(arguments, ['app-server', '--listen', 'stdio://']);
        return child;
      },
      shutdownTimeout: const Duration(milliseconds: 20),
    );
  });

  tearDown(() async {
    child.completeExit(0);
    await transport.close();
    await child.dispose();
  });

  test('performs initialize request and initialized notification', () async {
    final resultFuture = transport.initialize(const InitializeRequest());
    await pumpEventQueue();

    final request = jsonDecode(child.writes.single) as Map<String, Object?>;
    expect(request['method'], 'initialize');
    expect(request['id'], 1);
    expect(request['params'], {
      'clientInfo': {
        'name': 'codex-native-unofficial',
        'title': 'Codex Native (Unofficial)',
        'version': '0.1.0',
      },
      'capabilities': {'experimentalApi': true},
    });

    child.addStdout({
      'id': request['id'],
      'result': {'userAgent': 'codex-cli/0.test'},
    });
    final result = await resultFuture;
    expect(result.userAgent, 'codex-cli/0.test');

    final initialized = jsonDecode(child.writes.last) as Map<String, Object?>;
    expect(initialized, {'method': 'initialized', 'params': {}});
  });

  test('reports abnormal process exit with bounded stderr context', () async {
    final exitFuture = transport.exits.first;
    child.addStderr('fatal: test failure\n');
    await pumpEventQueue();

    child.completeExit(17);
    final exit = await exitFuture;

    expect(exit.code, 17);
    expect(exit.stderrTail, contains('test failure'));
  });

  test(
    'graceful shutdown closes stdin and does not kill exited process',
    () async {
      child.exitWhenInputCloses = true;

      await transport.close();

      expect(child.inputClosed, isTrue);
      expect(child.killSignals, isEmpty);
    },
  );

  test('coalesces concurrent shutdown requests', () async {
    child.exitWhenInputCloses = true;

    await Future.wait([
      transport.close(),
      transport.close(),
      transport.close(),
    ]);

    expect(child.closeInputCount, 1);
    expect(child.killSignals, isEmpty);
  });

  test(
    'starts the native Host with the separately located Codex path',
    () async {
      final hostChild = _FakeChildProcess()..exitWhenInputCloses = true;
      final hostTransport = await ProcessTransport.startHost(
        hostExecutablePath: '/bundle/codex-native-host',
        codexExecutablePath: '/user/bin/codex',
        launcher: (executable, arguments) async {
          expect(executable, '/bundle/codex-native-host');
          expect(arguments, ['--codex', '/user/bin/codex']);
          return hostChild;
        },
      );
      await hostTransport.close();
      await hostChild.dispose();
    },
  );
}

final class _FakeChildProcess implements ChildProcess {
  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final StreamController<List<int>> _stderr = StreamController<List<int>>();
  final Completer<int> _exitCode = Completer<int>();

  final List<String> writes = [];
  final List<ProcessSignal> killSignals = [];
  bool inputClosed = false;
  int closeInputCount = 0;
  bool exitWhenInputCloses = false;

  @override
  int get pid => 4242;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  Future<void> write(String value) async => writes.add(value);

  @override
  Future<void> closeInput() async {
    inputClosed = true;
    closeInputCount += 1;
    if (exitWhenInputCloses) {
      completeExit(0);
    }
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    completeExit(-signal.signalNumber);
    return true;
  }

  void addStdout(Map<String, Object?> message) {
    _stdout.add(utf8.encode('${jsonEncode(message)}\n'));
  }

  void addStderr(String message) {
    _stderr.add(utf8.encode(message));
  }

  void completeExit(int code) {
    if (!_exitCode.isCompleted) {
      _exitCode.complete(code);
    }
  }

  Future<void> dispose() async {
    await _stdout.close();
    await _stderr.close();
  }
}
