import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/diff_models.dart';
import '../domain/execution_settings.dart';
import '../domain/history_models.dart';
import '../domain/output_gateway.dart';
import '../domain/output_models.dart';
import '../domain/remote_admin_gateway.dart';
import '../domain/remote_admin_models.dart';
import '../domain/runtime_snapshot.dart';
import '../domain/thread_models.dart';
import '../features/approvals/approval_controller.dart';
import '../features/conversation/assistant_markdown.dart';
import '../features/conversation/conversation_controller.dart';
import '../features/conversation/history_controller.dart';
import '../features/conversation/output_viewer_controller.dart';
import '../features/diff/diff_controller.dart';
import '../features/settings/execution_settings_controller.dart';
import '../features/settings/remote_admin_controller.dart';
import '../features/settings/remote_pairing_qr.dart';
import '../features/settings/remote_pairing_scanner.dart';
import '../features/threads/thread_list_controller.dart';
import '../transport/remote/remote_onboarding.dart';
import 'runtime_controller.dart';
import 'theme_tokens.dart';

part 'presentation/app_shell.dart';
part 'presentation/remote_onboarding.dart';
part 'presentation/conversation.dart';
part 'presentation/diff_approval_output.dart';
part 'presentation/sidebar_activity.dart';
part 'presentation/remote_setup.dart';
part 'presentation/runtime_details.dart';

const _desktopSplitMinimumWidth = 760.0;
const _desktopSidebarWidth = 264.0;

class CodexNativeApp extends StatefulWidget {
  const CodexNativeApp({
    super.key,
    this.runtimeController,
    this.shutdownHandler,
    this.remotePairingScannerLauncher,
  });

  final RuntimeController? runtimeController;
  final Future<void> Function()? shutdownHandler;
  final RemotePairingScannerLauncher? remotePairingScannerLauncher;

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
  late final bool _ownsController;
  AppLifecycleListener? _lifecycleListener;
  var _requestedInitialThreads = false;

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
    );
    _historyController = HistoryController(gateway: _controller);
    _diffController = DiffController(gateway: _controller);
    _approvalController = ApprovalController(gateway: _controller);
    _controller.addListener(_handleRuntimeState);
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
    _threadController.removeListener(_handleThreadSelection);
    _approvalController.dispose();
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
      debugShowCheckedModeBanner: false,
      title: 'Codex Native (Unofficial)',
      theme: ThemeTokens.lightTheme,
      darkTheme: ThemeTokens.darkTheme,
      themeMode: ThemeMode.system,
      home: RuntimeStatusScreen(
        controller: _controller,
        threadController: _threadController,
        conversationController: _conversationController,
        historyController: _historyController,
        approvalController: _approvalController,
        settingsController: _settingsController,
        diffController: _diffController,
        defaultWorkingDirectory: Directory.current.path,
        remotePairingScannerLauncher:
            widget.remotePairingScannerLauncher ??
            (Platform.isAndroid ? showRemotePairingScanner : null),
      ),
    );
  }

  void _handleRuntimeState() {
    if (_controller.snapshot.state != RuntimeConnectionState.connected ||
        _requestedInitialThreads) {
      return;
    }
    _requestedInitialThreads = true;
    unawaited(_threadController.refresh());
    unawaited(_settingsController.refreshModels());
  }

  void _handleThreadSelection() {
    _conversationController.bindThread(_threadController.selectedThread);
    _diffController.bindThread(_threadController.selectedThread);
    unawaited(_historyController.bindThread(_threadController.selectedThread));
  }
}
