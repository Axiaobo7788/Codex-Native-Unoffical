import '../domain/ecosystem_models.dart';
import 'jsonl_decoder.dart';
import 'thread_protocol.dart';

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
      final result = await request('remoteControl/status');
      return _parseRemoteControlStatus(result);
    } catch (error) {
      return OfficialRemoteControlStatus(
        supported: false,
        enabled: false,
        connected: false,
        errorMessage: '$error',
      );
    }
  }

  Future<OfficialRemoteControlStatus> setOfficialRemoteControlEnabled(
    bool enabled,
  ) async {
    try {
      final result = await request('remoteControl/setEnabled', {
        'enabled': enabled,
      });
      return _parseRemoteControlStatus(result, fallbackEnabled: enabled);
    } catch (error) {
      return OfficialRemoteControlStatus(
        supported: false,
        enabled: false,
        connected: false,
        errorMessage: '$error',
      );
    }
  }

  Future<OfficialRemoteControlPairing>
  startOfficialRemoteControlPairing() async {
    final result = await request('remoteControl/pair/start');
    final code =
        (result['code'] as String?)?.trim() ??
        (result['pairingCode'] as String?)?.trim() ??
        (result['token'] as String?)?.trim() ??
        '';
    final qrPayload =
        (result['qrPayload'] as String?)?.trim() ??
        (result['url'] as String?)?.trim();
    final expiresAtMs = switch (result['expiresAtMs']) {
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

  Future<bool> disconnectOfficialRemoteControlClient(String clientId) async {
    final result = await request('remoteControl/clients/disconnect', {
      'clientId': clientId,
    });
    return result['disconnected'] as bool? ?? true;
  }

  static OfficialRemoteControlStatus _parseRemoteControlStatus(
    JsonObject json, {
    bool fallbackEnabled = false,
  }) {
    final statusObj = json['status'] is Map<String, Object?>
        ? json['status']! as Map<String, Object?>
        : json;
    final enabled = statusObj['enabled'] as bool? ?? fallbackEnabled;
    final connected = statusObj['connected'] as bool? ?? false;
    final environmentId = (statusObj['environmentId'] as String?)?.trim();
    final rawClients = statusObj['clients'];
    final clients = <OfficialRemoteControlClient>[];
    if (rawClients is List<Object?>) {
      for (final raw in rawClients.take(maxBoundedItems)) {
        if (raw is! Map<String, Object?>) {
          continue;
        }
        final id =
            (raw['id'] as String?)?.trim() ??
            (raw['clientId'] as String?)?.trim() ??
            '';
        if (id.isEmpty) {
          continue;
        }
        clients.add(
          OfficialRemoteControlClient(
            id: id,
            name: (raw['name'] as String?)?.trim() ?? id,
            platform: (raw['platform'] as String?)?.trim(),
            connectedAtMs: switch (raw['connectedAtMs']) {
              final int v => v,
              final num v => v.toInt(),
              _ => null,
            },
          ),
        );
      }
    }
    return OfficialRemoteControlStatus(
      supported: true,
      enabled: enabled,
      connected: connected,
      environmentId: environmentId,
      clients: List<OfficialRemoteControlClient>.unmodifiable(clients),
    );
  }
}
