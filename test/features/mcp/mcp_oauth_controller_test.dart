import 'dart:async';

import 'package:codex_native_unofficial/src/domain/mcp_oauth_gateway.dart';
import 'package:codex_native_unofficial/src/domain/mcp_oauth_models.dart';
import 'package:codex_native_unofficial/src/features/mcp/mcp_oauth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements McpOauthGateway {
  final events = StreamController<McpOauthEvent>.broadcast(sync: true);
  final starts = <Completer<McpOauthLoginAttempt>>[];
  final names = <String>[];
  @override
  bool supportsMcpOauth = true;
  @override
  Stream<McpOauthEvent> get mcpOauthEvents => events.stream;
  @override
  Future<McpOauthLoginAttempt> startMcpOauthLogin({
    required String serverName,
    int timeoutSeconds = 180,
  }) {
    names.add(serverName);
    final result = Completer<McpOauthLoginAttempt>();
    starts.add(result);
    return result.future;
  }
}

McpOauthLoginAttempt _attempt({String? loginId = 'current'}) =>
    McpOauthLoginAttempt(
      authorizationUri: Uri.parse('https://auth.example.test/?state=dummy'),
      loginId: loginId,
    );

void main() {
  late _Gateway gateway;
  late McpOauthController controller;
  late List<Uri> opened;

  setUp(() {
    gateway = _Gateway();
    opened = [];
    controller = McpOauthController(
      gateway: gateway,
      launchBrowser: (uri) async {
        opened.add(uri);
        return false;
      },
      timeoutSeconds: 1,
      startTimeout: const Duration(seconds: 1),
    );
  });
  tearDown(() async {
    controller.dispose();
    await gateway.events.close();
  });

  test(
    'one login, retry browser, and correlate the global completion',
    () async {
      final start = controller.signIn('mcp');
      await controller.signIn('other');
      expect(gateway.names, ['mcp']);
      gateway.starts.single.complete(_attempt());
      await start;
      expect(controller.phase, McpOauthPhase.waiting);
      expect(controller.message, contains('Could not open'));
      await controller.openBrowser();
      expect(opened, hasLength(2));
      expect(gateway.starts, hasLength(1));
      for (final event in [
        const McpOauthCompleted(
          serverName: 'other',
          success: true,
          loginId: 'current',
        ),
        const McpOauthCompleted(
          serverName: 'mcp',
          success: true,
          loginId: 'old',
        ),
        const McpOauthCompleted(
          serverName: 'mcp',
          success: true,
          loginId: 'current',
          threadId: 'thread',
        ),
      ]) {
        gateway.events.add(event);
        expect(controller.phase, McpOauthPhase.waiting);
      }
      gateway.events.add(
        const McpOauthCompleted(
          serverName: 'mcp',
          success: true,
          loginId: 'current',
        ),
      );
      expect(controller.phase, McpOauthPhase.succeeded);
      expect(controller.completionRevision, 1);
      expect(controller.canOpenBrowser, isFalse);
      gateway.events.add(
        const McpOauthCompleted(
          serverName: 'mcp',
          success: false,
          loginId: 'current',
        ),
      );
      expect(controller.completionRevision, 1);
      controller.clearNotice();
      expect(controller.phase, McpOauthPhase.idle);
    },
  );

  test(
    'completion before response does not open a stale browser flow',
    () async {
      final start = controller.signIn('mcp');
      gateway.events.add(
        const McpOauthCompleted(
          serverName: 'mcp',
          success: true,
          loginId: 'current',
        ),
      );
      gateway.starts.single.complete(_attempt());
      await start;
      expect(controller.phase, McpOauthPhase.succeeded);
      expect(opened, isEmpty);
    },
  );

  test('late browser failure cannot overwrite successful completion', () async {
    final browserResult = Completer<bool>();
    final actor = McpOauthController(
      gateway: gateway,
      launchBrowser: (uri) => browserResult.future,
    );
    try {
      final start = actor.signIn('mcp');
      gateway.starts.single.complete(_attempt());
      await pumpEventQueue();
      expect(actor.openingBrowser, isTrue);
      gateway.events.add(
        const McpOauthCompleted(
          serverName: 'mcp',
          success: true,
          loginId: 'current',
        ),
      );
      browserResult.complete(false);
      await start;
      expect(actor.phase, McpOauthPhase.succeeded);
      expect(actor.message, 'Sign-in completed.');
    } finally {
      actor.dispose();
    }
  });

  test('legacy global completion works without a login id', () async {
    final start = controller.signIn('mcp');
    gateway.starts.single.complete(_attempt(loginId: null));
    await start;
    gateway.events.add(
      const McpOauthCompleted(serverName: 'mcp', success: false),
    );
    expect(controller.phase, McpOauthPhase.failed);
    expect(controller.completionRevision, 1);
  });

  test('disconnect invalidates pending response and completion', () async {
    final start = controller.signIn('mcp');
    gateway.supportsMcpOauth = false;
    gateway.events.add(const McpOauthInvalidated());
    gateway.starts.single.complete(_attempt());
    await start;
    gateway.events.add(
      const McpOauthCompleted(
        serverName: 'mcp',
        success: true,
        loginId: 'current',
      ),
    );
    expect(controller.phase, McpOauthPhase.unconfirmed);
    expect(controller.completionRevision, 0);
    expect(opened, isEmpty);
    await controller.signIn('mcp');
    expect(gateway.starts, hasLength(1));
  });

  testWidgets('deadline releases projection, ignoring late browser handoff', (
    tester,
  ) async {
    final start = controller.signIn('mcp');
    await tester.pump(const Duration(seconds: 2));
    expect(controller.phase, McpOauthPhase.unconfirmed);
    gateway.starts.single.complete(_attempt());
    await start;
    expect(opened, isEmpty);
    expect(controller.canOpenBrowser, isFalse);
  });

  testWidgets(
    'unconfirmed completion releases URI without inventing cancellation',
    (tester) async {
      final start = controller.signIn('mcp');
      gateway.starts.single.complete(_attempt());
      await start;
      await tester.pump(const Duration(seconds: 7));
      expect(controller.phase, McpOauthPhase.unconfirmed);
      expect(controller.canOpenBrowser, isFalse);
      gateway.events.add(
        const McpOauthCompleted(
          serverName: 'mcp',
          success: true,
          loginId: 'current',
        ),
      );
      expect(controller.completionRevision, 0);
    },
  );

  test(
    'old stock has a truthful unsupported result rather than a retry hint',
    () async {
      final start = controller.signIn('mcp');
      gateway.starts.single.completeError(
        const McpOauthNotSupportedException(),
      );
      await start;
      expect(controller.phase, McpOauthPhase.failed);
      expect(controller.message, contains('does not support'));
      expect(opened, isEmpty);
    },
  );

  test(
    'provider errors and invalid URLs never reach the browser or notice',
    () async {
      var start = controller.signIn('mcp');
      gateway.starts.last.completeError(
        StateError('https://private.test/?token=dummy'),
      );
      await start;
      expect(controller.phase, McpOauthPhase.failed);
      expect(controller.message, isNot(contains('private.test')));
      start = controller.signIn('mcp');
      gateway.starts.last.complete(
        McpOauthLoginAttempt(
          authorizationUri: Uri.parse('file:///tmp/private'),
        ),
      );
      await start;
      expect(controller.phase, McpOauthPhase.failed);
      expect(opened, isEmpty);
    },
  );

  test(
    'an unsupported server name fails visibly without retaining it',
    () async {
      final name = 'x' * 257;
      await controller.signIn(name);
      expect(controller.phase, McpOauthPhase.failed);
      expect(controller.serverName, isNull);
      expect(controller.message, contains('Check its configuration'));
      expect(gateway.starts, isEmpty);
      expect(opened, isEmpty);
    },
  );

  test(
    'a released view cannot cause browser launch after app disposal',
    () async {
      final disposed = McpOauthController(
        gateway: gateway,
        launchBrowser: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      final start = disposed.signIn('mcp');
      disposed.dispose();
      gateway.starts.single.complete(_attempt());
      await start;
      expect(opened, isEmpty);
    },
  );
}
