import 'runtime_diagnostics_models.dart';

/// Read-only local runtime diagnostics contract for stock `codex app-server`.
///
/// Direct-Host Remote deliberately does not expose host-local account,
/// rate-limit, permission-profile, configuration, provider-capability, or hook
/// inspection RPCs. Callers must check [supportsRuntimeDiagnostics] and fail
/// closed on Remote surfaces.
abstract interface class RuntimeDiagnosticsGateway {
  bool get supportsRuntimeDiagnostics;

  Stream<RuntimeDiagnosticsEvent> get runtimeDiagnosticsEvents;

  Future<AccountDiagnosticsSnapshot> readAccountDiagnostics({
    bool refreshToken = false,
  });

  Future<RateLimitsDiagnosticsSnapshot> readAccountRateLimits({
    bool excludeResetCreditDetails = false,
  });

  Future<PermissionProfileListSnapshot> listPermissionProfiles({
    String? cwd,
    int? limit,
    String? cursor,
  });

  Future<ConfigDiagnosticsSnapshot> readConfigDiagnostics({
    String? cwd,
    bool includeLayers = true,
  });

  Future<ConfigRequirementsSummaryModel> readConfigRequirements();

  Future<ModelProviderCapabilitiesSnapshot> readModelProviderCapabilities();

  Future<HooksDiagnosticsSnapshot> listHooks({
    List<String> cwds = const [],
    String? threadId,
  });
}
