import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/mcp_oauth_gateway.dart';
import '../../domain/mcp_oauth_models.dart';

typedef McpOauthBrowserLauncher = Future<bool> Function(Uri uri);

enum McpOauthPhase { idle, starting, waiting, succeeded, failed, unconfirmed }

/// One app-scoped browser flow. Navigation/resize does not start another login.
/// Stock owns the OAuth exchange and credentials; no token is held here.
class McpOauthController extends ChangeNotifier {
  McpOauthController({
    required this.gateway,
    required this.launchBrowser,
    this.timeoutSeconds = 180,
    this.startTimeout = const Duration(seconds: 30),
  }) : assert(timeoutSeconds >= 1 && timeoutSeconds <= 900),
       assert(startTimeout > Duration.zero) {
    _subscription = gateway.mcpOauthEvents.listen(
      _handleEvent,
      onError: (Object _, StackTrace _) => _invalidate(),
      onDone: _invalidate,
    );
  }

  final McpOauthGateway gateway;
  final McpOauthBrowserLauncher launchBrowser;
  final int timeoutSeconds;
  final Duration startTimeout;
  late final StreamSubscription<McpOauthEvent> _subscription;
  Timer? _deadline;
  McpOauthLoginAttempt? _attempt;
  static const _maxEarlyCompletions = 8;
  final Map<String?, McpOauthCompleted> _earlyCompletions = {};
  String? _serverName;
  String? _message;
  var _phase = McpOauthPhase.idle;
  var _generation = 0;
  var _completionRevision = 0;
  var _openingBrowser = false;
  var _disposed = false;

  McpOauthPhase get phase => _phase;
  String? get serverName => _serverName;
  String? get message => _message;
  int get completionRevision => _completionRevision;
  bool get busy =>
      _phase == McpOauthPhase.starting || _phase == McpOauthPhase.waiting;
  bool get openingBrowser => _openingBrowser;
  bool get available => gateway.supportsMcpOauth;
  bool get canOpenBrowser =>
      !_disposed && busy && !_openingBrowser && _attempt != null && available;

  bool _isCurrent(int generation) =>
      !_disposed && busy && generation == _generation;

  Future<void> signIn(String serverName) async {
    if (_disposed || busy || !available) {
      return;
    }
    final name = serverName.trim();
    if (!isValidMcpOauthIdentifier(name)) {
      _serverName = null;
      _finish(
        McpOauthPhase.failed,
        'This server name cannot be used for sign-in. Check its configuration.',
      );
      return;
    }
    final generation = ++_generation;
    _serverName = name;
    _attempt = null;
    _earlyCompletions.clear();
    _message = 'Starting sign-in…';
    _phase = McpOauthPhase.starting;
    _deadline?.cancel();
    _deadline = Timer(startTimeout, () {
      if (_isCurrent(generation)) {
        _finish(
          McpOauthPhase.unconfirmed,
          'Could not confirm sign-in startup. Refresh server status before retrying.',
        );
      }
    });
    notifyListeners();
    try {
      final attempt = await gateway.startMcpOauthLogin(
        serverName: name,
        timeoutSeconds: timeoutSeconds,
      );
      if (!_isCurrent(generation)) {
        return;
      }
      if (!available) {
        _invalidate();
        return;
      }
      if (!isAllowedMcpAuthorizationUri(attempt.authorizationUri) ||
          (attempt.loginId != null &&
              !isValidMcpOauthIdentifier(attempt.loginId!))) {
        _finish(
          McpOauthPhase.failed,
          'The runtime returned an unsupported sign-in handoff.',
        );
        return;
      }
      _attempt = attempt;
      _phase = McpOauthPhase.waiting;
      _message = 'Continue in your browser.';
      _deadline?.cancel();
      _deadline = Timer(Duration(seconds: timeoutSeconds + 5), () {
        if (_isCurrent(generation)) {
          _finish(
            McpOauthPhase.unconfirmed,
            'Could not confirm sign-in completion. Refresh server status.',
          );
        }
      });
      final early = _earlyCompletions[attempt.loginId];
      _earlyCompletions.clear();
      if (early != null && _matches(early)) {
        _complete(early);
        return;
      }
      notifyListeners();
      await openBrowser();
    } on McpOauthNotSupportedException {
      if (_isCurrent(generation)) {
        _finish(
          McpOauthPhase.failed,
          'This runtime does not support MCP sign-in. Update Codex to use this action.',
        );
      }
    } on McpOauthStartPendingException {
      if (_isCurrent(generation)) {
        _finish(
          McpOauthPhase.unconfirmed,
          'Sign-in startup is still pending in the runtime.',
        );
      }
    } on Object {
      if (_isCurrent(generation)) {
        // Do not echo provider errors, authorization URLs or account material.
        _finish(
          McpOauthPhase.failed,
          'Could not start MCP sign-in. Refresh server status and try again.',
        );
      }
    }
  }

  Future<void> openBrowser() async {
    if (!canOpenBrowser) {
      return;
    }
    final generation = _generation;
    final uri = _attempt!.authorizationUri;
    _openingBrowser = true;
    notifyListeners();
    try {
      final opened = await launchBrowser(uri);
      if (_isCurrent(generation)) {
        _openingBrowser = false;
        _message = opened
            ? 'Continue in your browser.'
            : 'Could not open the browser. Use Open browser to try again.';
        notifyListeners();
      }
    } on Object {
      if (_isCurrent(generation)) {
        _openingBrowser = false;
        _message = 'Could not open the browser. Use Open browser to try again.';
        notifyListeners();
      }
    }
  }

  bool _matches(McpOauthCompleted event) =>
      event.serverName == _serverName &&
      event.threadId == null &&
      event.loginId == _attempt?.loginId;

  void _handleEvent(McpOauthEvent event) {
    if (_disposed) {
      return;
    }
    if (event is McpOauthInvalidated) {
      _invalidate();
    } else if (event is McpOauthCompleted &&
        busy &&
        event.serverName == _serverName &&
        event.threadId == null) {
      if (_phase == McpOauthPhase.starting) {
        // A late prior attempt must not overwrite the current early result.
        // The response selects its exact id from this constant-size buffer.
        if (!_earlyCompletions.containsKey(event.loginId) &&
            _earlyCompletions.length >= _maxEarlyCompletions) {
          _earlyCompletions.remove(_earlyCompletions.keys.first);
        }
        _earlyCompletions[event.loginId] = event;
      } else if (_matches(event)) {
        _complete(event);
      }
    }
  }

  void _complete(McpOauthCompleted event) {
    _completionRevision += 1;
    _finish(
      event.success ? McpOauthPhase.succeeded : McpOauthPhase.failed,
      event.success ? 'Sign-in completed.' : 'MCP sign-in did not complete.',
    );
  }

  void _invalidate() {
    if (_disposed) {
      return;
    }
    if (busy) {
      _finish(
        McpOauthPhase.unconfirmed,
        'The runtime can no longer confirm this sign-in. Refresh server status.',
      );
    } else if (_phase != McpOauthPhase.idle) {
      clearNotice();
    }
  }

  void _finish(McpOauthPhase phase, String message) {
    _deadline?.cancel();
    _deadline = null;
    _generation += 1;
    _phase = phase;
    _message = message;
    _attempt = null;
    _earlyCompletions.clear();
    _openingBrowser = false;
    if (!_disposed) {
      notifyListeners();
    }
  }

  void clearNotice() {
    if (_disposed || busy) {
      return;
    }
    _phase = McpOauthPhase.idle;
    _message = null;
    _serverName = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _deadline?.cancel();
    _attempt = null;
    _earlyCompletions.clear();
    _serverName = null;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
