enum ApprovalPolicyOverride { untrusted, onRequest, never }

enum SandboxModeOverride { readOnly, workspaceWrite, dangerFullAccess }

/// Read-side policy classifications are deliberately separate from writable
/// client overrides. A stock granular policy or external sandbox must never be
/// misrepresented as one of the narrower controls Native can send.
enum ObservedApprovalPolicy { untrusted, onRequest, never, granular, unknown }

enum ObservedSandboxPolicy {
  readOnly,
  workspaceWrite,
  dangerFullAccess,
  externalSandbox,
  unknown,
}

enum ThreadSettingsSource { start, resume, fork, notification, invalidated }

/// Bounded stock-acknowledged settings, never synthesized from model/list.
///
/// [generation] orders transport adapters within the current Dart isolate.
/// [observation] orders local request admission and notifications in that one
/// generation; it is not a stock revision or a wall-clock timestamp. A request
/// reply retains its admission order so it cannot overwrite a newer in-flight
/// settings notification. No raw config, writable-root list or credential is
/// retained here. A null text field is unknown/unrepresentable within the
/// projection budget; it never causes a successful thread operation to fail.
final class ThreadExecutionSettings {
  const ThreadExecutionSettings({
    required this.model,
    required this.modelProvider,
    required this.approvalPolicy,
    required this.sandbox,
    required this.generation,
    required this.observation,
    required this.source,
    this.reasoningEffort,
  });

  static const maxIdentifierLength = 512;
  static const maxReasoningEffortLength = 64;

  final String? model;
  final String? modelProvider;
  final String? reasoningEffort;
  final ObservedApprovalPolicy approvalPolicy;
  final ObservedSandboxPolicy sandbox;
  final int generation;
  final int observation;
  final ThreadSettingsSource source;

  /// A retired adapter cannot overwrite a later adapter's acknowledged state.
  bool isNewerThan(ThreadExecutionSettings other) =>
      generation > other.generation ||
      (generation == other.generation && observation > other.observation);
}
