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
