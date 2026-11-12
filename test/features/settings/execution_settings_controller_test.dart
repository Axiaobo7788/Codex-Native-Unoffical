import 'dart:async';

import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:codex_native_unofficial/src/domain/model_gateway.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/features/settings/execution_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime invalidation retains explicit intent until fresh catalog validates', () async {
    final gateway = _ModelGateway();
    final controller = ExecutionSettingsController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.refreshModels();
    controller.selectModel('other-model');
    controller.selectReasoningEffort('high');
    controller.invalidateRuntime();
    controller.bindThread(null);
    expect(controller.selectedModelId, 'other-model');
    expect(controller.selectedReasoningEffort, 'high');
    expect(controller.observedSettings, isNull);
    expect(
      () => controller.turnOptions(threadId: 'same', text: 'Keep intent'),
      throwsStateError,
    );
    await controller.refreshModels();
    expect(
      controller.turnOptions(threadId: 'same', text: 'Keep intent').model,
      'other-model-wire',
    );
    expect(controller.selectedReasoningEffort, 'high');
  });

  test(
    'retired catalog completion cannot overwrite a new pending catalog',
    () async {
      final first = Completer<ModelPage>();
      final gateway = _DeferredModels()..next = first;
      final controller = ExecutionSettingsController(gateway: gateway);
      addTearDown(controller.dispose);
      final oldRead = controller.refreshModels();
      controller.invalidateRuntime();
      final second = Completer<ModelPage>();
      gateway.next = second;
      final freshRead = controller.refreshModels();
      first.completeError(StateError('retired runtime'));
      await oldRead;
      expect(controller.loading, isTrue);
      expect(controller.errorMessage, isNull);
      second.complete(const ModelPage(models: [], nextCursor: null));
      await freshRead;
      expect(controller.loading, isFalse);
      expect(controller.errorMessage, isNull);
    },
  );

  test(
    'uncatalogued actual model does not borrow recommendation capabilities',
    () async {
      final controller = ExecutionSettingsController(gateway: _ModelGateway());
      addTearDown(controller.dispose);
      await controller.refreshModels();
      controller.bindThread(_settingsThread(_observedSettings()));
      controller.selectReasoningEffort('high');
      expect(controller.selectedReasoningEffort, 'high');
      controller.bindThread(
        _settingsThread(_observedSettings(model: 'custom-unknown')),
      );
      expect(controller.effectiveModel, isNull);
      expect(controller.availableReasoningEfforts, isEmpty);
      expect(controller.selectedReasoningEffort, isNull);
      controller.selectReasoningEffort('medium');
      expect(controller.selectedReasoningEffort, isNull);
      controller.selectModel('other-model');
      controller.selectReasoningEffort('high');
      controller.bindThread(
        _settingsThread(
          _observedSettings(model: 'another-unknown'),
          id: 'next',
        ),
      );
      expect(controller.selectedReasoningEffort, 'high');
      expect(controller.effectiveModel?.id, 'other-model');
    },
  );

  test(
    'catalog refresh retires a no-longer-supported effort override',
    () async {
      final gateway = _ModelGateway();
      final controller = ExecutionSettingsController(gateway: gateway);
      addTearDown(controller.dispose);
      await controller.refreshModels();
      controller.selectModel('other-model');
      controller.selectReasoningEffort('high');
      gateway.reducedEfforts = true;
      await controller.refreshModels();
      expect(controller.selectedModelId, 'other-model');
      expect(controller.selectedReasoningEffort, isNull);
    },
  );

  test('observed settings do not become client write overrides', () async {
    final controller = ExecutionSettingsController(gateway: _ModelGateway());
    addTearDown(controller.dispose);
    await controller.refreshModels();
    controller.bindThread(_settingsThread(_observedSettings()));

    expect(controller.observedModel?.id, 'other-model');
    expect(controller.observedSettings?.reasoningEffort, 'high');
    expect(
      controller.observedSettings?.approvalPolicy,
      ObservedApprovalPolicy.never,
    );
    expect(controller.selectedModelId, isNull);
    expect(controller.approvalPolicy, isNull);
    expect(controller.sandbox, isNull);
    final inherited = controller.turnOptions(threadId: 'known', text: 'Hello');
    expect(inherited.model, isNull);
    expect(inherited.reasoningEffort, isNull);
    expect(inherited.approvalPolicy, isNull);
    expect(inherited.sandbox, isNull);

    controller
      ..selectModel('default-model')
      ..selectApprovalPolicy(ApprovalPolicyOverride.onRequest);
    controller.bindThread(_settingsThread(_observedSettings(observation: 2)));
    expect(controller.effectiveModel?.id, 'default-model');
    expect(controller.observedModel?.id, 'other-model');
    expect(
      controller.turnOptions(threadId: 'known', text: 'Hello').model,
      'default-model-wire',
    );
    expect(controller.approvalPolicy, ApprovalPolicyOverride.onRequest);
  });

  test(
    'cold, unknown and Home contexts never borrow another thread settings',
    () async {
      final controller = ExecutionSettingsController(gateway: _ModelGateway());
      addTearDown(controller.dispose);
      await controller.refreshModels();
      controller.bindThread(_settingsThread(_observedSettings()));
      expect(controller.observedSettings, isNotNull);
      controller.bindThread(
        _settingsThread(_observedSettings())
            .copyWith(status: ThreadRuntimeStatus.notLoaded),
      );
      expect(controller.observedSettings, isNull);
      controller.bindThread(_settingsThread(_observedSettings()));
      controller.bindThread(_settingsThread(null, id: 'unknown'));
      expect(controller.observedSettings, isNull);
      controller.bindThread(_settingsThread(_observedSettings()));
      controller.bindThread(null);
      expect(controller.observedSettings, isNull);
    },
  );

  test(
    'retired generations and older observations cannot replace current state',
    () async {
      final controller = ExecutionSettingsController(gateway: _ModelGateway());
      addTearDown(controller.dispose);
      final current = _observedSettings(generation: 2, observation: 2);
      controller.bindThread(_settingsThread(current));
      controller.bindThread(
        _settingsThread(_observedSettings(generation: 2, observation: 1)),
      );
      expect(controller.observedSettings, same(current));
      controller.bindThread(
        _settingsThread(_observedSettings(generation: 1, observation: 999)),
      );
      expect(controller.observedSettings, same(current));
      final next = _observedSettings(generation: 3, observation: 1);
      controller.bindThread(_settingsThread(next));
      expect(controller.observedSettings, same(next));
    },
  );

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

ThreadExecutionSettings _observedSettings({
  String model = 'other-model-wire',
  int generation = 1,
  int observation = 1,
}) => ThreadExecutionSettings(
  model: model,
  modelProvider: 'fixture-provider',
  reasoningEffort: 'high',
  approvalPolicy: ObservedApprovalPolicy.never,
  sandbox: ObservedSandboxPolicy.readOnly,
  generation: generation,
  observation: observation,
  source: ThreadSettingsSource.resume,
);

ThreadSummary _settingsThread(
  ThreadExecutionSettings? settings, {
  String id = 'known',
}) => ThreadSummary(
  id: id,
  sessionId: id,
  preview: 'Settings context',
  cwd: '/workspace',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  status: ThreadRuntimeStatus.idle,
  ephemeral: false,
  executionSettings: settings,
);

class _ModelGateway implements ModelGateway {
  bool reducedEfforts = false;
  @override
  Future<ModelPage> listModels(ModelListQuery query) async => ModelPage(
    models: [
      CodexModel(
        id: 'default-model',
        model: 'default-model-wire',
        displayName: 'Default',
        description: 'Default model',
        isDefault: true,
        defaultReasoningEffort: 'medium',
        supportedReasoningEfforts: const [
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
        supportedReasoningEfforts: reducedEfforts
            ? const []
            : const [ReasoningEffortOption(value: 'high', description: 'High')],
      ),
    ],
    nextCursor: null,
  );
}

class _DeferredModels implements ModelGateway {
  late Completer<ModelPage> next;
  @override
  Future<ModelPage> listModels(ModelListQuery query) => next.future;
}
