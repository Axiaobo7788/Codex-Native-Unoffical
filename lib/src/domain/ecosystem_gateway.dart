import 'ecosystem_models.dart';

abstract interface class EcosystemGateway {
  Future<List<SkillSummary>> listSkills({List<String> cwds = const []});

  Future<bool> setSkillEnabled({required String path, required bool enabled});

  Future<List<PluginSummaryModel>> listPlugins({List<String> cwds = const []});

  Future<List<McpServerStatusModel>> listMcpServerStatus();

  Future<OfficialRemoteControlStatus> readOfficialRemoteControlStatus();

  Future<OfficialRemoteControlStatus> setOfficialRemoteControlEnabled(
    bool enabled,
  );

  Future<OfficialRemoteControlPairing> startOfficialRemoteControlPairing();

  Future<bool> disconnectOfficialRemoteControlClient(
    String clientId, {
    String? environmentId,
  });
}

/// Optional capability sub-interface for stock `codex app-server` catalog
/// discovery and plugin lifecycle mutations (`app/list`, `app/installed`,
/// `app/read`, `plugin/read`, `plugin/install`, `plugin/uninstall`).
///
/// Backends that do not implement or enable this capability must fail closed
/// visibly in the UI without requiring stubs on read-only remote transports.
abstract interface class EcosystemCatalogGateway implements EcosystemGateway {
  bool get supportsEcosystemCatalog;

  Future<AppListPage> listApps([AppListQuery query = const AppListQuery()]);

  Future<List<InstalledAppSnapshotModel>> listInstalledApps({
    String? threadId,
    bool forceRefresh = false,
  });

  Future<AppReadResultModel> readApps({
    required List<String> appIds,
    bool includeTools = true,
    String? threadId,
  });

  Future<PluginDetailModel> readPlugin({
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
  });

  Future<PluginInstallResultModel> installPlugin({
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
    String? installAttemptId,
  });

  Future<void> uninstallPlugin({required String pluginId});
}
