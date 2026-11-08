class SkillSummary {
  const SkillSummary({
    required this.name,
    required this.description,
    required this.path,
    required this.enabled,
    this.scope = 'repo',
  });

  final String name;
  final String description;
  final String path;
  final bool enabled;
  final String scope;

  SkillSummary copyWith({bool? enabled}) => SkillSummary(
    name: name,
    description: description,
    path: path,
    enabled: enabled ?? this.enabled,
    scope: scope,
  );
}

class PluginSummaryModel {
  const PluginSummaryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.enabled,
    this.version,
  });

  final String id;
  final String name;
  final String description;
  final bool enabled;
  final String? version;
}

class McpServerStatusModel {
  const McpServerStatusModel({
    required this.name,
    required this.status,
    required this.toolCount,
    required this.resourceCount,
    this.authStatus,
  });

  final String name;
  final String status;
  final int toolCount;
  final int resourceCount;
  final String? authStatus;
}

enum RemoteArchitectureTrack {
  directHostBridge,
  officialAppServerRelay;

  String get label => switch (this) {
    RemoteArchitectureTrack.directHostBridge => 'Direct Host Bridge',
    RemoteArchitectureTrack.officialAppServerRelay => 'Official App-Server',
  };
}

class OfficialRemoteControlClient {
  const OfficialRemoteControlClient({
    required this.id,
    required this.name,
    this.platform,
    this.connectedAtMs,
  });

  final String id;
  final String name;
  final String? platform;
  final int? connectedAtMs;
}

class OfficialRemoteControlPairing {
  const OfficialRemoteControlPairing({
    required this.code,
    this.qrPayload,
    this.expiresAtMs,
  });

  final String code;
  final String? qrPayload;
  final int? expiresAtMs;
}

class OfficialRemoteControlStatus {
  const OfficialRemoteControlStatus({
    this.supported = true,
    this.enabled = false,
    this.connected = false,
    this.stateLabel = 'disabled',
    this.serverName,
    this.installationId,
    this.environmentId,
    this.clients = const [],
    this.errorMessage,
  });

  final bool supported;
  final bool enabled;
  final bool connected;
  final String stateLabel;
  final String? serverName;
  final String? installationId;
  final String? environmentId;
  final List<OfficialRemoteControlClient> clients;
  final String? errorMessage;

  OfficialRemoteControlStatus copyWith({
    bool? supported,
    bool? enabled,
    bool? connected,
    String? stateLabel,
    String? serverName,
    String? installationId,
    String? environmentId,
    List<OfficialRemoteControlClient>? clients,
    String? errorMessage,
  }) => OfficialRemoteControlStatus(
    supported: supported ?? this.supported,
    enabled: enabled ?? this.enabled,
    connected: connected ?? this.connected,
    stateLabel: stateLabel ?? this.stateLabel,
    serverName: serverName ?? this.serverName,
    installationId: installationId ?? this.installationId,
    environmentId: environmentId ?? this.environmentId,
    clients: clients ?? this.clients,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}
