const maxBoundedEcosystemItems = 100;

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
    this.pluginName,
    this.installed = true,
    this.marketplaceName,
    this.marketplacePath,
    this.sourceType,
    this.installPolicy = 'AVAILABLE',
    this.authPolicy = 'ON_USE',
    this.availability = 'AVAILABLE',
    this.disabledReason,
    this.category,
    this.capabilities = const [],
  });

  final String id;
  final String name;
  final String description;
  final bool enabled;
  final String? version;
  final String? pluginName;
  final bool installed;
  final String? marketplaceName;
  final String? marketplacePath;
  final String? sourceType;
  final String installPolicy;
  final String authPolicy;
  final String availability;
  final String? disabledReason;
  final String? category;
  final List<String> capabilities;

  String get effectivePluginName {
    final trimmed = pluginName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    final atIndex = id.indexOf('@');
    if (atIndex > 0) {
      return id.substring(0, atIndex);
    }
    return id;
  }

  bool get canInstall =>
      !installed &&
      availability == 'AVAILABLE' &&
      installPolicy != 'NOT_AVAILABLE';

  bool get canUninstall => installed && installPolicy != 'INSTALLED_BY_DEFAULT';

  PluginSummaryModel copyWith({
    bool? enabled,
    bool? installed,
    String? version,
  }) => PluginSummaryModel(
    id: id,
    name: name,
    description: description,
    enabled: enabled ?? this.enabled,
    version: version ?? this.version,
    pluginName: pluginName,
    installed: installed ?? this.installed,
    marketplaceName: marketplaceName,
    marketplacePath: marketplacePath,
    sourceType: sourceType,
    installPolicy: installPolicy,
    authPolicy: authPolicy,
    availability: availability,
    disabledReason: disabledReason,
    category: category,
    capabilities: capabilities,
  );
}

class PluginAppReferenceModel {
  const PluginAppReferenceModel({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.installUrl,
  });

  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? installUrl;
}

class PluginHookSummaryModel {
  const PluginHookSummaryModel({required this.key, required this.eventName});

  final String key;
  final String eventName;
}

class PluginDetailModel {
  const PluginDetailModel({
    required this.summary,
    required this.marketplaceName,
    this.marketplacePath,
    this.description = '',
    this.skills = const [],
    this.apps = const [],
    this.mcpServers = const [],
    this.hooks = const [],
    this.shareUrl,
  });

  final PluginSummaryModel summary;
  final String marketplaceName;
  final String? marketplacePath;
  final String description;
  final List<SkillSummary> skills;
  final List<PluginAppReferenceModel> apps;
  final List<String> mcpServers;
  final List<PluginHookSummaryModel> hooks;
  final String? shareUrl;
}

class PluginInstallResultModel {
  const PluginInstallResultModel({
    this.authPolicy = 'ON_USE',
    this.appsNeedingAuth = const [],
  });

  final String authPolicy;
  final List<PluginAppReferenceModel> appsNeedingAuth;
}

class AppListQuery {
  const AppListQuery({
    this.cursor,
    this.limit = 50,
    this.threadId,
    this.forceRefetch = false,
  }) : assert(limit > 0);

  final String? cursor;
  final int limit;
  final String? threadId;
  final bool forceRefetch;
}

class AppSummaryModel {
  const AppSummaryModel({
    required this.id,
    required this.name,
    this.description = '',
    this.isAccessible = false,
    this.isEnabled = true,
    this.distributionChannel,
    this.installUrl,
    this.category,
    this.developer,
    this.version,
    this.isDiscoverableApp = false,
    this.pluginDisplayNames = const [],
  });

  final String id;
  final String name;
  final String description;
  final bool isAccessible;
  final bool isEnabled;
  final String? distributionChannel;
  final String? installUrl;
  final String? category;
  final String? developer;
  final String? version;
  final bool isDiscoverableApp;
  final List<String> pluginDisplayNames;
}

class AppListPage {
  const AppListPage({required this.apps, this.nextCursor});

  final List<AppSummaryModel> apps;
  final String? nextCursor;
}

class InstalledAppSnapshotModel {
  const InstalledAppSnapshotModel({
    required this.id,
    required this.enabled,
    required this.callable,
    this.runtimeName,
  });

  final String id;
  final bool enabled;
  final bool callable;
  final String? runtimeName;

  String get displayName {
    final trimmed = runtimeName?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : id;
  }
}

class AppToolSummaryModel {
  const AppToolSummaryModel({
    required this.name,
    required this.description,
    this.title,
    this.isEnabled = true,
    this.isReadOnly = false,
    this.disabledReason,
  });

  final String name;
  final String description;
  final String? title;
  final bool isEnabled;
  final bool isReadOnly;
  final String? disabledReason;
}

class AppDetailModel {
  const AppDetailModel({
    required this.id,
    required this.name,
    this.description = '',
    this.distributionChannel,
    this.installUrl,
    this.iconUrl,
    this.iconUrlDark,
    this.pluginDisplayNames = const [],
    this.toolSummaries = const [],
  });

  final String id;
  final String name;
  final String description;
  final String? distributionChannel;
  final String? installUrl;
  final String? iconUrl;
  final String? iconUrlDark;
  final List<String> pluginDisplayNames;
  final List<AppToolSummaryModel> toolSummaries;
}

class AppReadResultModel {
  const AppReadResultModel({required this.apps, this.missingAppIds = const []});

  final List<AppDetailModel> apps;
  final List<String> missingAppIds;
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

class McpResourceReadTarget {
  const McpResourceReadTarget({required this.connectorId, this.linkId});

  final String connectorId;
  final String? linkId;
}

class McpResourceReadQuery {
  const McpResourceReadQuery({
    required this.server,
    required this.uri,
    this.threadId,
    this.connectorId,
    this.originCallId,
    this.target,
  });

  final String server;
  final String uri;
  final String? threadId;
  final String? connectorId;
  final String? originCallId;
  final McpResourceReadTarget? target;
}

sealed class McpResourceContentModel {
  const McpResourceContentModel({required this.uri, this.mimeType});

  final String uri;
  final String? mimeType;
}

final class McpTextResourceContentModel extends McpResourceContentModel {
  const McpTextResourceContentModel({
    required super.uri,
    required this.text,
    super.mimeType,
  });

  final String text;
}

final class McpBlobResourceContentModel extends McpResourceContentModel {
  const McpBlobResourceContentModel({
    required super.uri,
    required this.encodedLength,
    super.mimeType,
  });

  /// The base64 payload is deliberately not retained in Flutter state.
  final int encodedLength;
}

class McpResourceReadResultModel {
  McpResourceReadResultModel({
    required List<McpResourceContentModel> contents,
    this.originCallId,
  }) : contents = List.unmodifiable(contents);

  final List<McpResourceContentModel> contents;
  final String? originCallId;
}

class McpToolCallQuery {
  McpToolCallQuery({
    required this.server,
    required this.threadId,
    required this.tool,
    Map<String, Object?> arguments = const {},
  }) : arguments = Map.unmodifiable(arguments);

  final String server;
  final String threadId;
  final String tool;
  final Map<String, Object?> arguments;
}

class McpToolContentModel {
  const McpToolContentModel({
    required this.kind,
    required this.summary,
    this.text,
    this.uri,
    this.mimeType,
    this.encodedDataLength,
  });

  final String kind;
  final String summary;
  final String? text;
  final String? uri;
  final String? mimeType;

  /// Encoded binary content is described, but never retained in UI state.
  final int? encodedDataLength;
}

class McpToolCallResultModel {
  McpToolCallResultModel({
    required List<McpToolContentModel> content,
    required this.isError,
    this.structuredContentPreview,
  }) : content = List.unmodifiable(content);

  final List<McpToolContentModel> content;
  final bool isError;
  final String? structuredContentPreview;
}

enum McpElicitationMode { form, url, openaiForm }

enum McpElicitationFieldKind {
  string,
  number,
  integer,
  boolean,
  singleSelect,
  multiSelect,
}

class McpElicitationOption {
  const McpElicitationOption({required this.value, required this.label});

  final String value;
  final String label;
}

class McpElicitationField {
  McpElicitationField({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.required,
    this.defaultValue,
    this.minimum,
    this.maximum,
    this.minLength,
    this.maxLength,
    this.minItems,
    this.maxItems,
    List<McpElicitationOption> options = const [],
  }) : options = List.unmodifiable(options);

  final String id;
  final String title;
  final String description;
  final McpElicitationFieldKind kind;
  final bool required;
  final Object? defaultValue;
  final num? minimum;
  final num? maximum;
  final int? minLength;
  final int? maxLength;
  final int? minItems;
  final int? maxItems;
  final List<McpElicitationOption> options;
}

class McpElicitationRequest {
  McpElicitationRequest({
    required this.requestId,
    required this.serverName,
    required this.threadId,
    required this.message,
    required this.mode,
    this.turnId,
    this.elicitationId,
    this.url,
    List<McpElicitationField> fields = const [],
  }) : fields = List.unmodifiable(fields);

  final Object requestId;
  final String serverName;
  final String threadId;
  final String? turnId;
  final String message;
  final McpElicitationMode mode;
  final String? elicitationId;
  final Uri? url;
  final List<McpElicitationField> fields;
}

sealed class McpElicitationEvent {
  const McpElicitationEvent();
}

final class McpElicitationRequestedEvent extends McpElicitationEvent {
  const McpElicitationRequestedEvent({required this.request});

  final McpElicitationRequest request;
}

final class McpElicitationResolvedEvent extends McpElicitationEvent {
  const McpElicitationResolvedEvent({required this.requestId});

  final Object requestId;
}

enum McpElicitationAction { accept, decline, cancel }

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
