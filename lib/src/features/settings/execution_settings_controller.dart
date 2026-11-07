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
  String? _errorMessage;
  var _loading = false;

  List<CodexModel> get models => _models;
  String? get selectedModelId => _selectedModelId;
  String? get selectedReasoningEffort => _selectedReasoningEffort;
  ApprovalPolicyOverride? get approvalPolicy => _approvalPolicy;
  SandboxModeOverride? get sandbox => _sandbox;
  String? get errorMessage => _errorMessage;
  bool get loading => _loading;

  CodexModel? get effectiveModel {
    final selected = _selectedModelId;
    if (selected != null) {
      return _models.where((model) => model.id == selected).firstOrNull;
    }
    return _models.where((model) => model.isDefault).firstOrNull ??
        _models.firstOrNull;
  }

  List<ReasoningEffortOption> get availableReasoningEfforts =>
      effectiveModel?.supportedReasoningEfforts ?? const [];

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
  }) => TurnStartOptions(
    threadId: threadId,
    text: text,
    model: effectiveModel == null || _selectedModelId == null
        ? null
        : effectiveModel!.model,
    reasoningEffort: _selectedReasoningEffort,
    approvalPolicy: _approvalPolicy,
    sandbox: _sandbox,
  );
}
