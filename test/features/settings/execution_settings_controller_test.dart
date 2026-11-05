import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:codex_native_unofficial/src/domain/model_gateway.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/features/settings/execution_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inherits Codex defaults until the user selects overrides', () async {
    final controller = ExecutionSettingsController(gateway: _ModelGateway());
    addTearDown(controller.dispose);

    await controller.refreshModels();

    expect(controller.effectiveModel?.id, 'default-model');
    final inherited = controller.turnOptions(
      threadId: 'thread-1',
      text: 'Hello',
    );
    expect(inherited.model, isNull);
    expect(inherited.reasoningEffort, isNull);
    expect(inherited.approvalPolicy, isNull);
    expect(inherited.sandbox, isNull);

    controller
      ..selectModel('other-model')
      ..selectReasoningEffort('high')
      ..selectApprovalPolicy(ApprovalPolicyOverride.onRequest)
      ..selectSandbox(SandboxModeOverride.workspaceWrite);

    final selected = controller.turnOptions(
      threadId: 'thread-1',
      text: 'Hello',
    );
    expect(selected.model, 'other-model-wire');
    expect(selected.reasoningEffort, 'high');
    expect(selected.approvalPolicy, ApprovalPolicyOverride.onRequest);
    expect(selected.sandbox, SandboxModeOverride.workspaceWrite);

    final thread = controller.threadOptions('/workspace');
    expect(thread.model, 'other-model-wire');
    expect(thread.approvalPolicy, ApprovalPolicyOverride.onRequest);
    expect(thread.sandbox, SandboxModeOverride.workspaceWrite);
  });

  test('clears effort when changing models', () async {
    final controller = ExecutionSettingsController(gateway: _ModelGateway());
    addTearDown(controller.dispose);
    await controller.refreshModels();

    controller
      ..selectReasoningEffort('medium')
      ..selectModel('other-model');

    expect(controller.selectedReasoningEffort, isNull);
  });
}

class _ModelGateway implements ModelGateway {
  @override
  Future<ModelPage> listModels(ModelListQuery query) async => const ModelPage(
    models: [
      CodexModel(
        id: 'default-model',
        model: 'default-model-wire',
        displayName: 'Default',
        description: 'Default model',
        isDefault: true,
        defaultReasoningEffort: 'medium',
        supportedReasoningEfforts: [
          ReasoningEffortOption(value: 'low', description: 'Low'),
          ReasoningEffortOption(value: 'medium', description: 'Medium'),
        ],
      ),
      CodexModel(
        id: 'other-model',
        model: 'other-model-wire',
        displayName: 'Other',
        description: 'Other model',
        isDefault: false,
        defaultReasoningEffort: 'high',
        supportedReasoningEfforts: [
          ReasoningEffortOption(value: 'high', description: 'High'),
        ],
      ),
    ],
    nextCursor: null,
  );
}
