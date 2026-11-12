import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kBackMouseButton, kForwardMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/chat_conversation_dag.dart';
import '../domain/diff_models.dart';
import '../domain/ecosystem_gateway.dart';
import '../domain/ecosystem_models.dart';
import '../domain/execution_settings.dart';
import '../domain/history_models.dart';
import '../domain/output_gateway.dart';
import '../domain/output_models.dart';
import '../domain/product_mode.dart';
import '../domain/remote_admin_gateway.dart';
import '../domain/remote_admin_models.dart';
import '../domain/runtime_snapshot.dart';
import '../domain/thread_models.dart';
import '../domain/turn_models.dart';
import '../domain/user_input_models.dart';
import '../features/approvals/approval_controller.dart';
import '../features/conversation/assistant_markdown.dart';
import '../features/conversation/conversation_controller.dart';
import '../features/conversation/history_controller.dart';
import '../features/conversation/output_viewer_controller.dart';
import '../features/conversation/user_input_controller.dart';
import '../features/diff/diff_controller.dart';
import '../features/mcp/mcp_oauth_controller.dart';
import '../features/settings/execution_settings_controller.dart';
import '../features/settings/remote_admin_controller.dart';
import '../features/settings/remote_pairing_qr.dart';
import '../features/settings/remote_pairing_scanner.dart';
import '../features/threads/thread_list_controller.dart';
import '../transport/remote/remote_onboarding.dart';
import 'primitives/codex_activity_row.dart';
import 'primitives/codex_button.dart';
import 'primitives/codex_composer.dart';
import 'primitives/codex_menu.dart';
import 'primitives/codex_message_bubble.dart';
import 'primitives/codex_popover.dart';
import 'primitives/codex_segment.dart';
import 'primitives/codex_sidebar_row.dart';
import 'primitives/codex_tooltip.dart';
import 'runtime_controller.dart';
import 'theme/official_codex_theme.dart';
import 'theme_tokens.dart';

part 'presentation/app_shell.dart';
part 'presentation/remote_onboarding.dart';
part 'presentation/conversation.dart';
part 'presentation/composer_model_picker.dart';
part 'presentation/desktop_goal.dart';
part 'presentation/diff_approval_output.dart';
part 'presentation/sidebar_activity.dart';
part 'presentation/remote_setup.dart';
part 'presentation/runtime_details.dart';
part 'presentation/user_input.dart';

const _desktopSplitMinimumWidth = OfficialCodexTheme.splitBreakpoint;

class CodexNativeApp extends StatefulWidget {
  const CodexNativeApp({
    super.key,
    this.runtimeController,
    this.shutdownHandler,
    this.remotePairingScannerLauncher,
    this.mcpOauthBrowserLauncher,
  });

  final RuntimeController? runtimeController;
  final Future<void> Function()? shutdownHandler;
  final RemotePairingScannerLauncher? remotePairingScannerLauncher;
  final McpOauthBrowserLauncher? mcpOauthBrowserLauncher;

  @override
  State<CodexNativeApp> createState() => _CodexNativeAppState();
}

class _CodexNativeAppState extends State<CodexNativeApp> {
  late final RuntimeController _controller;
  late final ThreadListController _threadController;
  late final ExecutionSettingsController _settingsController;
  late final ConversationController _conversationController;
  late final HistoryController _historyController;
  late final DiffController _diffController;
  late final ApprovalController _approvalController;
  late final UserInputController _userInputController;
  late final McpOauthController _mcpOauthController;
  late final bool _ownsController;
  AppLifecycleListener? _lifecycleListener;
  var _requestedInitialThreads = false;
  var _hadConnectedWorkspace = false;
  var _runtimeProjectionVersion = 0;
  var _refreshingRuntimeProjection = false;
  ({
    int runtimeVersion,
    String? threadId,
    int afterHistoryVersion,
    int retiredEntriesVersion,
  })?
  _pendingRecoveredHistory;
  final _navigatorKey = GlobalKey<NavigatorState>();
  var _lastRevertVersion = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.runtimeController == null;
    _controller = widget.runtimeController ?? RuntimeController();
    _threadController = ThreadListController(gateway: _controller);
    _settingsController = ExecutionSettingsController(gateway: _controller);
    _conversationController = ConversationController(
      gateway: _controller,
      settings: _settingsController,
      reviewStarter: _controller.startReview,
    );
    _historyController = HistoryController(gateway: _controller);
    _diffController = DiffController(gateway: _controller);
    _approvalController = ApprovalController(gateway: _controller);
    _userInputController = UserInputController(
      gateway: _controller,
      mcpGateway: _controller,
    );
    _mcpOauthController = McpOauthController(
      gateway: _controller,
      launchBrowser: (uri) =>
          widget.mcpOauthBrowserLauncher?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication),
    );
    _lastRevertVersion = _threadController.revertVersion;
    _controller.addListener(_handleRuntimeState);
    _historyController.addListener(_handleRecoveredHistory);
    _threadController.addListener(_handleThreadSelection);
    _lifecycleListener = AppLifecycleListener(
      onHide: () => unawaited(_controller.handleAppHidden()),
      onShow: () => unawaited(_controller.handleAppShown()),
      onDetach: () =>
          unawaited(widget.shutdownHandler?.call() ?? _controller.shutdown()),
    );
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _controller.removeListener(_handleRuntimeState);
    _historyController.removeListener(_handleRecoveredHistory);
    _threadController.removeListener(_handleThreadSelection);
    _approvalController.dispose();
    _userInputController.dispose();
    _mcpOauthController.dispose();
    _conversationController.dispose();
    _historyController.dispose();
    _diffController.dispose();
    _settingsController.dispose();
    _threadController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Codex Native (Unofficial)',
      theme: ThemeTokens.lightTheme,
      darkTheme: ThemeTokens.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) => OfficialCodexThemeProvider(
        data: Theme.of(context).brightness == Brightness.dark
            ? OfficialCodexThemeData.dark
            : OfficialCodexThemeData.light,
        child: child ?? const SizedBox(),
      ),
      home: RuntimeStatusScreen(
        controller: _controller,
        threadController: _threadController,
        conversationController: _conversationController,
        historyController: _historyController,
        approvalController: _approvalController,
        userInputController: _userInputController,
        settingsController: _settingsController,
        diffController: _diffController,
        mcpOauthController: _mcpOauthController,
        defaultWorkingDirectory: Directory.current.path,
        remotePairingScannerLauncher:
            widget.remotePairingScannerLauncher ??
            (Platform.isAndroid ? showRemotePairingScanner : null),
      ),
    );
  }

  void _handleRuntimeState() {
    final connected =
        _controller.snapshot.state == RuntimeConnectionState.connected;
    if (!connected) {
      if (!_controller.usesRemote && _requestedInitialThreads) {
        _requestedInitialThreads = false;
        _runtimeProjectionVersion += 1;
        _pendingRecoveredHistory = null;
        _refreshingRuntimeProjection = true;
        // Dismiss session-bound modal readers/forms. Their Host references and
        // server-request IDs cannot survive replacement of the local process.
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        // Invalidate before any replacement runtime can publish new requests.
        // These methods preserve bounded saved projections and user intent.
        _conversationController.invalidateRuntime();
        _approvalController.invalidateRuntime();
        _userInputController.invalidateRuntime();
        _historyController.invalidateRuntime();
        _settingsController.invalidateRuntime();
        _threadController.invalidateRuntime();
        _refreshingRuntimeProjection = false;
      }
      return;
    }
    if (_requestedInitialThreads) return;
    _requestedInitialThreads = true;
    unawaited(_settingsController.refreshModels());
    if (_hadConnectedWorkspace && !_controller.usesRemote) {
      unawaited(_refreshRecoveredWorkspace(++_runtimeProjectionVersion));
    } else {
      _hadConnectedWorkspace = true;
      unawaited(_threadController.refresh());
    }
  }

  Future<void> _refreshRecoveredWorkspace(int version) async {
    final selectedId = _threadController.selectedThread?.id;
    _pendingRecoveredHistory = (
      runtimeVersion: version,
      threadId: selectedId,
      afterHistoryVersion: _historyController.refreshVersion,
      retiredEntriesVersion: _conversationController.runtimeInvalidationVersion,
    );
    bool current() =>
        mounted &&
        version == _runtimeProjectionVersion &&
        _controller.snapshot.state == RuntimeConnectionState.connected;
    _refreshingRuntimeProjection = true;
    try {
      await _threadController.refresh(preserveSelection: true);
      if (!current()) return;
      // Read metadata/history only. A cold thread (including one with queued
      // work) must remain cold until the existing explicit-resume flow admits it.
      if (selectedId != null &&
          _threadController.selectedThread?.id == selectedId) {
        await _threadController.selectThread(selectedId);
      }
      if (!current()) return;
    } finally {
      if (version == _runtimeProjectionVersion) {
        _refreshingRuntimeProjection = false;
      }
    }
    if (!current()) return;
    final selected = _threadController.selectedThread;
    if (selected != null &&
        _threadController.selectedThreadNeedsDraftRecovery(selected.id)) {
      // The fresh read did not establish this previous-session ID. Keep the
      // bounded last-known projection with retired references; never turn an
      // unavailable/ambiguous saved read into a fabricated empty history.
      return;
    }
    await _historyController.bindThread(
      selected,
      force: true,
      knownUnmaterialized:
          selected != null && !_threadController.isMaterialized(selected.id),
    );
  }

  void _handleRecoveredHistory() {
    final pending = _pendingRecoveredHistory;
    if (pending == null) return;
    if (pending.runtimeVersion != _runtimeProjectionVersion ||
        pending.threadId != _threadController.selectedThread?.id) {
      _pendingRecoveredHistory = null;
      return;
    }
    if (_historyController.loadingTurns ||
        _historyController.errorMessage != null ||
        _historyController.refreshVersion <= pending.afterHistoryVersion) {
      return;
    }
    _pendingRecoveredHistory = null;
    _conversationController.reconcileRecoveredHistory(
      pending.retiredEntriesVersion,
    );
  }

  void _handleThreadSelection() {
    final selected = _threadController.selectedThread;
    if (_pendingRecoveredHistory?.threadId != selected?.id) {
      _pendingRecoveredHistory = null;
    }
    _settingsController.bindThread(selected);
    if (_threadController.revertVersion != _lastRevertVersion) {
      _lastRevertVersion = _threadController.revertVersion;
      final revertedId = _threadController.lastRevertedThreadId;
      if (revertedId != null && selected?.id == revertedId) {
        _conversationController.clearEntries();
        unawaited(_historyController.refresh());
      }
    }
    _conversationController.bindThread(selected);
    _diffController.bindThread(selected);
    if (_refreshingRuntimeProjection) return;
    // A just-created stock thread has no persisted history before its first
    // turn. Reuse the catalog's existing admission marker; never reinterpret
    // arbitrary history RPC failures as an empty conversation.
    unawaited(
      _historyController.bindThread(
        selected,
        knownUnmaterialized:
            selected != null && !_threadController.isMaterialized(selected.id),
      ),
    );
  }
}
