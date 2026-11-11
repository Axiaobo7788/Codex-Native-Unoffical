import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/mcp_oauth_models.dart';
import 'package:codex_native_unofficial/src/domain/remote_admin_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/domain/user_input_models.dart';
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

  test(
    'keeps one raw queued-work read in flight and falls back on old stock',
    () async {
      final first = transport.readThreadQueuePresence('first-thread');
      await pumpEventQueue();
      final request = jsonDecode(child.writes.single) as Map<String, Object?>;
      expect(request['method'], 'thread/queue/list');
      expect(request['params'], {'threadId': 'first-thread', 'limit': 1});
      expect(
        await transport.readThreadQueuePresence('another-thread'),
        ThreadQueuePresence.unknown,
      );
      expect(child.writes, hasLength(1));
      child.addStdout({
        'id': request['id'],
        'result': {
          'data': [
            {'id': 'queued-item', 'input': 'unprojected'},
          ],
          'nextCursor': null,
        },
      });
      expect(await first, ThreadQueuePresence.pending);

      final old = transport.readThreadQueuePresence('another-thread');
      await pumpEventQueue();
      final second = jsonDecode(child.writes.last) as Map<String, Object?>;
      child.addStdout({
        'id': second['id'],
        'error': {'code': -32601, 'message': 'Method not found'},
      });
      expect(await old, ThreadQueuePresence.unsupported);
    },
  );

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

  test(
    'MCP sign-in holds one raw request slot until the response settles',
    () async {
      final first = transport.startMcpOauthLogin(serverName: 'mcp');
      await pumpEventQueue();
      final request = jsonDecode(child.writes.single) as Map<String, Object?>;
      expect(request['method'], 'mcpServer/oauth/login');
      expect(request['params'], {'name': 'mcp'});
      for (var i = 0; i < 20; i++) {
        await expectLater(
          transport.startMcpOauthLogin(serverName: 'other'),
          throwsA(isA<McpOauthStartPendingException>()),
        );
      }
      expect(child.writes, hasLength(1));
      child.addStdout({
        'id': request['id'],
        'result': {
          'authorizationUrl': 'https://auth.example.test/',
          'loginId': 'one',
        },
      });
      expect((await first).loginId, 'one');
      final next = transport.startMcpOauthLogin(serverName: 'other');
      await pumpEventQueue();
      final second = jsonDecode(child.writes.last) as Map<String, Object?>;
      child.addStdout({
        'id': second['id'],
        'error': {'code': -32601, 'message': 'Method not found'},
      });
      await expectLater(next, throwsA(isA<McpOauthNotSupportedException>()));
      expect(transport.supportsMcpOauth, isFalse);
      await expectLater(
        transport.startMcpOauthLogin(serverName: 'mcp'),
        throwsA(isA<McpOauthNotSupportedException>()),
      );
      expect(child.writes, hasLength(2));
    },
  );

  test('shutdown settles pending MCP sign-in and rejects new starts', () async {
    final start = transport.startMcpOauthLogin(serverName: 'mcp');
    final failed = expectLater(start, throwsA(isA<TransportClosedException>()));
    await pumpEventQueue();
    child.exitWhenInputCloses = true;
    await transport.close();
    await failed;
    expect(transport.supportsMcpOauth, isFalse);
    await expectLater(
      transport.startMcpOauthLogin(serverName: 'mcp'),
      throwsA(isA<TransportClosedException>()),
    );
    expect(child.writes, hasLength(1));
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

  test('rejects new RPC writes as soon as shutdown starts', () async {
    child.exitWhenInputCloses = true;

    final closeFuture = transport.close();
    final lateRequest = transport.listModels(const ModelListQuery());

    await expectLater(lateRequest, throwsA(isA<TransportClosedException>()));
    await closeFuture;
    expect(child.writesAfterInputClosed, 0);
  });

  test('routes typed review/start through the guarded process peer', () async {
    final reviewFuture = transport.startReview(
      const ReviewStartOptions(
        threadId: 'thread-review',
        target: UncommittedChangesReviewTarget(),
      ),
    );
    await pumpEventQueue();

    final request = jsonDecode(child.writes.single) as Map<String, Object?>;
    expect(request['method'], 'review/start');
    expect(request['params'], {
      'threadId': 'thread-review',
      'target': {'type': 'uncommittedChanges'},
    });

    child.addStdout({
      'id': request['id'],
      'result': {
        'reviewThreadId': 'thread-review',
        'turn': {'id': 'review-turn-1', 'status': 'inProgress'},
      },
    });
    final review = await reviewFuture;
    expect(review.reviewThreadId, 'thread-review');
    expect(review.turn.id, 'review-turn-1');
    expect(review.turn.status, TurnRuntimeStatus.inProgress);
  });

  test(
    'answers current time server requests through the process peer',
    () async {
      final lowerBound = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      child.addStdout({
        'id': 'clock-1',
        'method': 'currentTime/read',
        'params': <String, Object?>{'threadId': 'thread-1'},
      });
      await pumpEventQueue();

      final response = jsonDecode(child.writes.single) as Map<String, Object?>;
      expect(response['id'], 'clock-1');
      final result = response['result']! as Map<String, Object?>;
      expect(result['currentTimeAt'], isA<int>());
      expect(result['currentTimeAt']! as int, greaterThanOrEqualTo(lowerBound));
    },
  );

  test('round trips typed tool user input through the process peer', () async {
    final eventFuture = transport.userInputEvents.first;
    child.addStdout({
      'id': 'input-1',
      'method': 'item/tool/requestUserInput',
      'params': {
        'threadId': 'thread-1',
        'turnId': 'turn-1',
        'itemId': 'item-1',
        'isBlocking': true,
        'questions': [
          {
            'id': 'approach',
            'header': 'Approach',
            'question': 'Which implementation should be used?',
            'options': [
              {
                'label': 'Incremental',
                'description': 'Make the smallest compatible change.',
              },
            ],
          },
        ],
      },
    });

    final event = await eventFuture as UserInputRequestedEvent;
    expect(event.request.threadId, 'thread-1');
    await transport.submitUserInput(
      requestId: event.request.requestId,
      answers: UserInputAnswers({
        'approach': ['Incremental'],
      }),
    );

    final response = jsonDecode(child.writes.single) as Map<String, Object?>;
    expect(response['id'], 'input-1');
    expect(response['result'], {
      'answers': {
        'approach': {
          'answers': ['Incremental'],
        },
      },
    });
  });

  test(
    'routes trusted local Remote administration through the Host peer',
    () async {
      final statusFuture = transport.readRemoteAdminStatus();
      await pumpEventQueue();
      final request = jsonDecode(child.writes.single) as Map<String, Object?>;
      expect(request['method'], 'host/status');
      child.addStdout({
        'id': request['id'],
        'result': {
          'version': '0.1.0',
          'maxOutputBytes': 1024,
          'maxSessionBytes': 2048,
          'maxReadBytes': 256,
          'remote': {
            'enabled': true,
            'address': '127.0.0.1:4317',
            'tls': false,
            'scope': 'loopback',
            'advertisedEndpoint': 'wss://host.example/v1/ws',
            'pairingTrust': 'system',
          },
        },
      });

      final status = await statusFuture;
      expect(status.scope, RemoteListenerScope.loopback);
      expect(status.canCreatePairingTicket, isTrue);
    },
  );

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

  test('IoChildProcess serializes concurrent writes without StreamSink flush errors', () async {
    final ioChild = await launchIoProcess('cat', const []);
    final linesFuture = ioChild.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();

    await Future.wait([
      ioChild.write('{"id":2,"method":"thread/list"}\n'),
      ioChild.write('{"id":3,"method":"model/list"}\n'),
      ioChild.write('{"id":4,"method":"skills/list"}\n'),
    ]);
    await ioChild.closeInput();

    final lines = await linesFuture;
    expect(lines, [
      '{"id":2,"method":"thread/list"}',
      '{"id":3,"method":"model/list"}',
      '{"id":4,"method":"skills/list"}',
    ]);
    expect(await ioChild.exitCode, 0);
  });
}

final class _FakeChildProcess implements ChildProcess {
  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final StreamController<List<int>> _stderr = StreamController<List<int>>();
  final Completer<int> _exitCode = Completer<int>();

  final List<String> writes = [];
  final List<ProcessSignal> killSignals = [];
  bool inputClosed = false;
  int closeInputCount = 0;
  int writesAfterInputClosed = 0;
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
  Future<void> write(String value) async {
    if (inputClosed) {
      writesAfterInputClosed += 1;
      throw StateError('stdin is closed');
    }
    writes.add(value);
  }

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
