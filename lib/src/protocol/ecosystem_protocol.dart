import '../domain/ecosystem_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';

typedef OfficialRemoteControlHostAdapter = EcosystemProtocolAdapter;

class EcosystemProtocolAdapter {
  const EcosystemProtocolAdapter({required this.request});

  static const maxBoundedItems = 100;

  final ProtocolRequest request;

  Future<List<SkillSummary>> listSkills({List<String> cwds = const []}) async {
    final normalizedCwds = cwds
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final result = await request('skills/list', {
      if (normalizedCwds.isNotEmpty) 'cwds': normalizedCwds,
    });
    final data = result['data'];
    if (data is! List<Object?>) {
      return const [];
    }
    final skills = <SkillSummary>[];
    final seenPaths = <String>{};
    for (final entry in data) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final rawSkills = entry['skills'];
      if (rawSkills is! List<Object?>) {
        continue;
      }
      for (final rawSkill in rawSkills) {
        if (rawSkill is! Map<String, Object?>) {
          continue;
        }
        final name = (rawSkill['name'] as String?)?.trim() ?? '';
        final path = (rawSkill['path'] as String?)?.trim() ?? '';
        if (name.isEmpty || path.isEmpty || !seenPaths.add(path)) {
          continue;
        }
        final description =
            (rawSkill['shortDescription'] as String?)?.trim() ??
            (rawSkill['description'] as String?)?.trim() ??
            '';
        final enabled = rawSkill['enabled'] as bool? ?? true;
        final scope = (rawSkill['scope'] as String?)?.trim() ?? 'repo';
        skills.add(
          SkillSummary(
            name: name,
            description: description,
            path: path,
            enabled: enabled,
            scope: scope,
          ),
        );
        if (skills.length >= maxBoundedItems) {
          return List<SkillSummary>.unmodifiable(skills);
        }
      }
    }
    return List<SkillSummary>.unmodifiable(skills);
  }

  Future<bool> setSkillEnabled({
    required String path,
    required bool enabled,
  }) async {
    final result = await request('skills/config/write', {
      'path': path,
      'enabled': enabled,
    });
    return result['effectiveEnabled'] as bool? ?? enabled;
  }

  Future<List<PluginSummaryModel>> listPlugins({
    List<String> cwds = const [],
  }) async {
    final normalizedCwds = cwds
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final result = await request('plugin/list', {
      if (normalizedCwds.isNotEmpty) 'cwds': normalizedCwds,
    });
    final plugins = <PluginSummaryModel>[];
    final seenIds = <String>{};

    void addPluginMap(Map<String, Object?> map) {
      if (plugins.length >= maxBoundedItems) {
        return;
      }
      final id =
          (map['id'] as String?)?.trim() ??
          (map['name'] as String?)?.trim() ??
          '';
      if (id.isEmpty || !seenIds.add(id)) {
        return;
      }
      final interfaceMap = map['interface'];
      final displayName = interfaceMap is Map<String, Object?>
          ? (interfaceMap['displayName'] as String?)?.trim()
          : null;
      final description = interfaceMap is Map<String, Object?>
          ? (interfaceMap['shortDescription'] as String?)?.trim()
          : null;
      plugins.add(
        PluginSummaryModel(
          id: id,
          name: (displayName != null && displayName.isNotEmpty)
              ? displayName
              : ((map['name'] as String?)?.trim() ?? id),
          description:
              description ?? ((map['description'] as String?)?.trim() ?? ''),
          enabled: map['enabled'] as bool? ?? true,
          version: (map['version'] as String?)?.trim(),
        ),
      );
    }

    final marketplaces = result['marketplaces'];
    if (marketplaces is List<Object?>) {
      for (final marketplace in marketplaces) {
        if (marketplace is! Map<String, Object?>) {
          continue;
        }
        final list = marketplace['plugins'];
        if (list is List<Object?>) {
          for (final item in list) {
            if (item is Map<String, Object?>) {
              addPluginMap(item);
            }
          }
        }
      }
    }
    final directPlugins = result['plugins'];
    if (directPlugins is List<Object?>) {
      for (final item in directPlugins) {
        if (item is Map<String, Object?>) {
          addPluginMap(item);
        }
      }
    }
    return List<PluginSummaryModel>.unmodifiable(plugins);
  }

  Future<List<McpServerStatusModel>> listMcpServerStatus() async {
    final result = await request('mcpServerStatus/list', {
      'limit': maxBoundedItems,
    });
    final data = result['data'];
    if (data is! List<Object?>) {
      return const [];
    }
    final servers = <McpServerStatusModel>[];
    for (final raw in data.take(maxBoundedItems)) {
      if (raw is! Map<String, Object?>) {
        continue;
      }
      final name = (raw['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) {
        continue;
      }
      final tools = raw['tools'];
      final resources = raw['resources'];
      final toolCount = switch (tools) {
        final Map<Object?, Object?> m => m.length,
        final List<Object?> l => l.length,
        _ => 0,
      };
      final resourceCount = switch (resources) {
        final Map<Object?, Object?> m => m.length,
        final List<Object?> l => l.length,
        _ => 0,
      };
      final authStatus = (raw['authStatus'] as String?)?.trim();
      final status =
          (raw['status'] as String?)?.trim() ??
          (authStatus != null && authStatus.isNotEmpty ? authStatus : 'ready');
      servers.add(
        McpServerStatusModel(
          name: name,
          status: status,
          toolCount: toolCount,
          resourceCount: resourceCount,
          authStatus: authStatus,
        ),
      );
    }
    return List<McpServerStatusModel>.unmodifiable(servers);
  }

  Future<OfficialRemoteControlStatus> readOfficialRemoteControlStatus() async {
    try {
      final result = await request('remoteControl/status/read');
      final parsed = _parseRemoteControlStatus(result);
      final envId = parsed.environmentId;
      if (envId != null && envId.isNotEmpty && parsed.clients.isEmpty) {
        try {
          final clientResult = await request('remoteControl/client/list', {
            'environmentId': envId,
            'limit': maxBoundedItems,
          });
          final listedClients = _parseClientList(clientResult['data']);
          if (listedClients.isNotEmpty) {
            return parsed.copyWith(clients: listedClients);
          }
        } on Object {
          // Client listing requires an active relay session; keep base status.
        }
      }
      return parsed;
    } catch (error) {
      return OfficialRemoteControlStatus(
        supported: !_isUnsupportedMethodError(error),
        enabled: false,
        connected: false,
        errorMessage: '$error',
      );
    }
  }

  Future<OfficialRemoteControlStatus> setOfficialRemoteControlEnabled(
    bool enabled,
  ) async {
    final method = enabled ? 'remoteControl/enable' : 'remoteControl/disable';
    try {
      final result = await request(method, {'ephemeral': false});
      return _parseRemoteControlStatus(result, fallbackEnabled: enabled);
    } catch (error) {
      return OfficialRemoteControlStatus(
        supported: !_isUnsupportedMethodError(error),
        enabled: false,
        connected: false,
        errorMessage: '$error',
      );
    }
  }

  Future<OfficialRemoteControlPairing>
  startOfficialRemoteControlPairing() async {
    final result = await request('remoteControl/pairing/start', {
      'manualCode': true,
    });
    final manualCode = (result['manualPairingCode'] as String?)?.trim();
    final pairingCode = (result['pairingCode'] as String?)?.trim();
    final code =
        (manualCode != null && manualCode.isNotEmpty ? manualCode : null) ??
        (pairingCode != null && pairingCode.isNotEmpty ? pairingCode : null) ??
        (result['code'] as String?)?.trim() ??
        (result['token'] as String?)?.trim() ??
        '';
    final qrPayload =
        (result['qrPayload'] as String?)?.trim() ??
        (result['url'] as String?)?.trim() ??
        ((manualCode != null &&
                manualCode.isNotEmpty &&
                pairingCode != null &&
                pairingCode.isNotEmpty &&
                pairingCode != manualCode)
            ? pairingCode
            : null);
    final rawExpires = result['expiresAtMs'] ?? result['expiresAt'];
    final expiresAtMs = switch (rawExpires) {
      final int v => v,
      final num v => v.toInt(),
      _ => null,
    };
    return OfficialRemoteControlPairing(
      code: code,
      qrPayload: qrPayload,
      expiresAtMs: expiresAtMs,
    );
  }

  Future<bool> disconnectOfficialRemoteControlClient(
    String clientId, {
    String? environmentId,
  }) async {
    final normalizedEnv = environmentId?.trim();
    final result = await request('remoteControl/client/revoke', {
      'clientId': clientId,
      if (normalizedEnv != null && normalizedEnv.isNotEmpty)
        'environmentId': normalizedEnv,
    });
    return result['disconnected'] as bool? ?? true;
  }

  static bool _isUnsupportedMethodError(Object error) {
    if (error is JsonRpcException) {
      if (error.code == -32601) {
        return true;
      }
      final msg = error.message.toLowerCase();
      if (error.code == -32600 &&
          (msg.contains('unknown variant') ||
              msg.contains('method not found') ||
              msg.contains('unsupported'))) {
        return true;
      }
    }
    final text = error.toString().toLowerCase();
    return text.contains('unknown variant') ||
        text.contains('method not found');
  }

  static OfficialRemoteControlStatus _parseRemoteControlStatus(
    JsonObject json, {
    bool fallbackEnabled = false,
  }) {
    final statusField = json['status'];
    final statusObj = statusField is Map<String, Object?> ? statusField : json;
    final rawStatusString = statusField is String ? statusField.trim() : null;
    final enabled = switch (statusObj['enabled']) {
      final bool b => b,
      _ =>
        rawStatusString != null
            ? (rawStatusString != 'disabled' ? true : fallbackEnabled)
            : fallbackEnabled,
    };
    final connected = switch (statusObj['connected']) {
      final bool b => b,
      _ => rawStatusString == 'connected',
    };
    final stateLabel =
        rawStatusString ??
        (connected ? 'connected' : (enabled ? 'connecting' : 'disabled'));
    final serverName = (statusObj['serverName'] as String?)?.trim();
    final installationId = (statusObj['installationId'] as String?)?.trim();
    final rawEnvId = (statusObj['environmentId'] as String?)?.trim();
    final environmentId = (rawEnvId != null && rawEnvId.isNotEmpty)
        ? rawEnvId
        : null;
    final clients = _parseClientList(statusObj['clients'] ?? statusObj['data']);
    return OfficialRemoteControlStatus(
      supported: true,
      enabled: enabled,
      connected: connected,
      stateLabel: stateLabel,
      serverName: (serverName != null && serverName.isNotEmpty)
          ? serverName
          : null,
      installationId: (installationId != null && installationId.isNotEmpty)
          ? installationId
          : null,
      environmentId: environmentId,
      clients: clients,
    );
  }

  static List<OfficialRemoteControlClient> _parseClientList(
    Object? rawClients,
  ) {
    if (rawClients is! List<Object?>) {
      return const [];
    }
    final clients = <OfficialRemoteControlClient>[];
    for (final raw in rawClients.take(maxBoundedItems)) {
      if (raw is! Map<String, Object?>) {
        continue;
      }
      final id =
          (raw['clientId'] as String?)?.trim() ??
          (raw['id'] as String?)?.trim() ??
          '';
      if (id.isEmpty) {
        continue;
      }
      final displayName =
          (raw['displayName'] as String?)?.trim() ??
          (raw['name'] as String?)?.trim() ??
          (raw['deviceModel'] as String?)?.trim();
      final rawTime = raw['lastSeenAt'] ?? raw['connectedAtMs'];
      clients.add(
        OfficialRemoteControlClient(
          id: id,
          name: (displayName != null && displayName.isNotEmpty)
              ? displayName
              : id,
          platform: (raw['platform'] as String?)?.trim(),
          connectedAtMs: switch (rawTime) {
            final int v => v,
            final num v => v.toInt(),
            _ => null,
          },
        ),
      );
    }
    return List<OfficialRemoteControlClient>.unmodifiable(clients);
  }
}
