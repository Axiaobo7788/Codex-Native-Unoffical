import 'package:flutter/foundation.dart';

import '../../domain/execution_settings.dart';
import '../../domain/model_gateway.dart';
import '../../domain/model_models.dart';
import '../../domain/thread_models.dart';
import '../../domain/turn_models.dart';

class ExecutionSettingsController extends ChangeNotifier {
  ExecutionSettingsController({required this.gateway});

  final ModelGateway gateway;
  List<CodexModel> _models = const [];
  String? _selectedModelId;
  String? _selectedReasoningEffort;
  ApprovalPolicyOverride? _approvalPolicy;
  SandboxModeOverride? _sandbox;
  String? _observedThreadId;
  ThreadExecutionSettings? _observedSettings;
  String? _errorMessage;
  var _loading = false;

  List<CodexModel> get models => _models;
  String? get selectedModelId => _selectedModelId;
  String? get selectedReasoningEffort => _selectedReasoningEffort;
  ApprovalPolicyOverride? get approvalPolicy => _approvalPolicy;
  SandboxModeOverride? get sandbox => _sandbox;
  String? get errorMessage => _errorMessage;
  bool get loading => _loading;
  ThreadExecutionSettings? get observedSettings => _observedSettings;

  /// Resolve catalog display metadata only after stock acknowledges a model.
  /// It is deliberately independent from a nullable writable override.
  CodexModel? get observedModel {
    final model = _observedSettings?.model;
    if (model == null) return null;
    return _models.where((entry) => entry.model == model).firstOrNull;
  }

  void bindThread(ThreadSummary? thread) {
    // A cold saved thread can acquire different config when explicitly resumed.
    // Metadata selection must not load it just to fill these controls.
    final settings = thread?.status == ThreadRuntimeStatus.notLoaded
        ? null
        : thread?.executionSettings;
    if (_observedThreadId == thread?.id &&
        settings != null &&
        _observedSettings?.isNewerThan(settings) == true) {
      return;
    }
    if (_observedThreadId == thread?.id &&
        identical(_observedSettings, settings)) {
      return;
    }
    _observedThreadId = thread?.id;
    _observedSettings = settings;
    _revalidateReasoningEffort();
    notifyListeners();
  }

  /// A recommendation is useful before a runtime model is known. An actual
  /// uncatalogued model must not borrow another model's capability metadata.
  /// Callers displaying inherited truth still use [observedSettings].
  CodexModel? get effectiveModel {
    final selected = _selectedModelId;
    if (selected != null) {
      return _models.where((model) => model.id == selected).firstOrNull;
    }
    if (_observedSettings?.model != null) return observedModel;
    return _models.where((model) => model.isDefault).firstOrNull ??
        _models.firstOrNull;
  }

  List<ReasoningEffortOption> get availableReasoningEfforts =>
      (_selectedModelId == null ? observedModel : effectiveModel)
          ?.supportedReasoningEfforts ??
      const [];

  Future<void> refreshModels() async {
    if (_loading) {
      return;
    }
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final page = await gateway.listModels(const ModelListQuery());
      _models = page.models;
      if (_selectedModelId != null && effectiveModel == null) {
        _selectedModelId = null;
        _selectedReasoningEffort = null;
      }
      _revalidateReasoningEffort();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectModel(String? modelId) {
    if (modelId != null && !_models.any((model) => model.id == modelId)) {
      return;
    }
    _selectedModelId = modelId;
    _selectedReasoningEffort = null;
    notifyListeners();
  }

  void selectReasoningEffort(String? effort) {
    if (effort != null &&
        !availableReasoningEfforts.any((option) => option.value == effort)) {
      return;
    }
    _selectedReasoningEffort = effort;
    notifyListeners();
  }

  void _revalidateReasoningEffort() {
    final effort = _selectedReasoningEffort;
    if (effort != null &&
        !availableReasoningEfforts.any((option) => option.value == effort)) {
      _selectedReasoningEffort = null;
    }
  }

  void selectApprovalPolicy(ApprovalPolicyOverride? policy) {
    _approvalPolicy = policy;
    notifyListeners();
  }

  void selectSandbox(SandboxModeOverride? sandbox) {
    _sandbox = sandbox;
    notifyListeners();
  }

  ThreadStartOptions threadOptions(String cwd) => ThreadStartOptions(
    cwd: cwd,
    model: effectiveModel == null || _selectedModelId == null
        ? null
        : effectiveModel!.model,
    approvalPolicy: _approvalPolicy,
    sandbox: _sandbox,
  );

  TurnStartOptions turnOptions({
    required String threadId,
    required String text,
    List<UserAttachment> attachments = const [],
    String? clientUserMessageId,
  }) => TurnStartOptions(
    threadId: threadId,
    text: text,
    attachments: attachments,
    clientUserMessageId: clientUserMessageId,
    model: effectiveModel == null || _selectedModelId == null
        ? null
        : effectiveModel!.model,
    reasoningEffort: _selectedReasoningEffort,
    approvalPolicy: _approvalPolicy,
    sandbox: _sandbox,
  );
}
