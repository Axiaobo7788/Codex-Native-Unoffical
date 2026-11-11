import 'dart:async';

import 'package:codex_native_unofficial/src/app/codex_native_app.dart';
import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/domain/ecosystem_models.dart';
import 'package:codex_native_unofficial/src/domain/mcp_oauth_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

/// Only presentation-relevant typed outcomes are simulated here. Protocol and
/// OAuth exchange truth are checked separately against actual stock processes.
class _OauthHarness extends SimulatedRuntimeHarness {
  final oauthEvents = StreamController<McpOauthEvent>.broadcast(sync: true);
  final starts = <String>[];
  var authenticated = false;
  var statusReads = 0;
  Completer<void>? nextStatusRead;

  @override
  bool get supportsMcpOauth => true;
  @override
  Stream<McpOauthEvent> get mcpOauthEvents => oauthEvents.stream;
  @override
  Future<McpOauthLoginAttempt> startMcpOauthLogin({
    required String serverName,
    int timeoutSeconds = 180,
  }) async {
    starts.add(serverName);
    return McpOauthLoginAttempt(
      authorizationUri: Uri.parse('https://auth.example.test/?state=dummy'),
      loginId: 'current',
    );
  }

  @override
  Future<List<McpServerStatusModel>> listMcpServerStatus() async {
    statusReads++;
    final auth = authenticated;
    final gate = nextStatusRead;
    nextStatusRead = null;
    if (gate != null) await gate.future;
    return [
      McpServerStatusModel(
        name: 'oauth-mcp',
        status: '',
        toolCount: 0,
        resourceCount: 0,
        authStatus: auth ? 'oAuth' : 'notLoggedIn',
      ),
      const McpServerStatusModel(
        name: 'unsupported-mcp',
        status: '',
        toolCount: 0,
        resourceCount: 0,
        authStatus: 'unsupported',
      ),
    ];
  }

  void completeLogin() {
    authenticated = true;
    oauthEvents.add(
      const McpOauthCompleted(
        serverName: 'oauth-mcp',
        success: true,
        loginId: 'current',
      ),
    );
  }

  @override
  Future<void> disposeHarness() async {
    await oauthEvents.close();
    await super.disposeHarness();
  }
}

Future<void> _pumpApp(
  WidgetTester tester,
  _OauthHarness harness, {
  required Size size,
  required Future<bool> Function(Uri) launch,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await harness.disposeHarness();
  });
  await tester.pumpWidget(
    CodexNativeApp(runtimeController: harness, mcpOauthBrowserLauncher: launch),
  );
  await tester.pumpAndSettle();
}

Future<void> _openMcp(WidgetTester tester, {bool pending = false}) async {
  await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
  if (pending) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    await tester.pumpAndSettle();
  }
  final wide = find.byKey(const ValueKey('customize-nav-mcp'));
  await tester.tap(wide.evaluate().isEmpty ? find.text('MCP (2)') : wide);
  if (pending) {
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'wide MCP handoff survives navigation and refreshes authenticated status',
    (tester) async {
      final harness = _OauthHarness();
      final opened = <Uri>[];
      await _pumpApp(
        tester,
        harness,
        size: const Size(1191, 865),
        launch: (uri) async {
          opened.add(uri);
          return false;
        },
      );
      await _openMcp(tester);
      expect(
        find.byKey(const ValueKey('mcp-oauth-sign-in-unsupported-mcp')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('mcp-oauth-sign-in-oauth-mcp')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.starts, ['oauth-mcp']);
      expect(opened, hasLength(1));
      expect(
        find.textContaining('Could not open the browser.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('mcp-oauth-open-browser')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opened, hasLength(2));
      expect(harness.starts, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('app-shell-home-button')));
      await tester.pump(const Duration(milliseconds: 300));
      await _openMcp(tester, pending: true);
      expect(
        tester
            .widget<CodexButton>(
              find.byKey(const ValueKey('mcp-oauth-sign-in-oauth-mcp')),
            )
            .onPressed,
        isNull,
      );
      harness.completeLogin();
      await tester.pumpAndSettle();
      expect(find.text('Auth: oAuth'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mcp-oauth-sign-in-oauth-mcp')),
        findsNothing,
      );
      expect(find.textContaining('Sign-in completed.'), findsOneWidget);
      expect(harness.resumedThreadIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide to compact and dialog close/reopen preserve one pending app flow',
    (tester) async {
      final harness = _OauthHarness();
      await _pumpApp(
        tester,
        harness,
        size: const Size(1191, 865),
        launch: (uri) async => false,
      );
      await _openMcp(tester);
      await tester.tap(
        find.byKey(const ValueKey('mcp-oauth-sign-in-oauth-mcp')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.view.physicalSize = const Size(720, 800);
      await tester.pump(const Duration(milliseconds: 300));
      await _openMcp(tester, pending: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      await _openMcp(tester, pending: true);
      expect(
        find.byKey(const ValueKey('mcp-oauth-open-browser')),
        findsOneWidget,
      );
      expect(harness.starts, hasLength(1));
      tester.view.physicalSize = const Size(1191, 865);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Dialog), findsOneWidget);
      final readsBeforeCompletion = harness.statusReads;
      harness.completeLogin();
      await tester.pumpAndSettle();
      expect(harness.statusReads, readsBeforeCompletion + 1);
      expect(find.text('Auth: oAuth'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(harness.statusReads, readsBeforeCompletion + 2);
      expect(find.text('Auth: oAuth'), findsOneWidget);
      expect(harness.resumedThreadIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completion during a stale status read schedules a bounded fresh read',
    (tester) async {
      final harness = _OauthHarness();
      await _pumpApp(
        tester,
        harness,
        size: const Size(1191, 865),
        launch: (uri) async => false,
      );
      await _openMcp(tester);
      await tester.tap(
        find.byKey(const ValueKey('mcp-oauth-sign-in-oauth-mcp')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final oldRead = Completer<void>();
      harness.nextStatusRead = oldRead;
      final before = harness.statusReads;
      await tester.tap(find.byKey(const ValueKey('mcp-oauth-refresh-status')));
      await tester.pump(const Duration(milliseconds: 300));
      harness.completeLogin();
      await tester.pump(const Duration(milliseconds: 50));
      expect(harness.statusReads, before + 1);
      oldRead.complete();
      await tester.pumpAndSettle();
      expect(harness.statusReads, before + 2);
      expect(find.text('Auth: oAuth'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
