import 'dart:convert';

import '../domain/ecosystem_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';

typedef OfficialRemoteControlHostAdapter = EcosystemProtocolAdapter;

class EcosystemProtocolAdapter {
  const EcosystemProtocolAdapter({required this.request});

  static const maxBoundedItems = maxBoundedEcosystemItems;

  final ProtocolRequest request;

  static const maxMcpResourceContents = 32;
  static const maxMcpToolContents = 32;
  static const maxMcpPayloadBytes = 256 * 1024;
  static const maxMcpRetainedTextBytes = 64 * 1024;
  static const maxMcpStructuredPreviewBytes = 32 * 1024;
  static const maxMcpJsonDepth = 8;
  static const maxMcpJsonNodes = 1024;
  static const maxMcpIdentifierLength = 256;
  static const maxMcpUriLength = 4096;

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
        final parsed = _parseSkillSummary(rawSkill, requirePath: true);
        if (parsed == null || !seenPaths.add(parsed.path)) {
          continue;
        }
        skills.add(parsed);
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

  Future<void> reloadMcpServers() async {
    await request('config/mcpServer/reload', const {});
  }

  Future<McpResourceReadResultModel> readMcpResource(
    McpResourceReadQuery query,
  ) async {
    final server = _requiredInput(
      query.server,
      'server',
      maxMcpIdentifierLength,
    );
    final uri = _requiredInput(query.uri, 'uri', maxMcpUriLength);
    final threadId = _optionalInput(
      query.threadId,
      'threadId',
      maxMcpIdentifierLength,
    );
    final connectorId = _optionalInput(
      query.connectorId,
      'connectorId',
      maxMcpIdentifierLength,
    );
    final originCallId = _optionalInput(
      query.originCallId,
      'originCallId',
      maxMcpIdentifierLength,
    );
    final target = query.target;
    final targetConnectorId = target == null
        ? null
        : _requiredInput(
            target.connectorId,
            'target.connectorId',
            maxMcpIdentifierLength,
          );
    final targetLinkId = target == null
        ? null
        : _optionalInput(
            target.linkId,
            'target.linkId',
            maxMcpIdentifierLength,
          );
    final result = await request('mcpServer/resource/read', {
      'server': server,
      'uri': uri,
      'threadId': ?threadId,
      'connectorId': ?connectorId,
      'originCallId': ?originCallId,
      if (targetConnectorId != null)
        'target': {'connectorId': targetConnectorId, 'linkId': targetLinkId},
    });
    _requireMcpPayloadBound(result, 'MCP resource response');
    final rawContents = result['contents'];
    if (rawContents is! List<Object?> ||
        rawContents.length > maxMcpResourceContents) {
      throw FormatException(
        'MCP resource response must contain at most '
        '$maxMcpResourceContents contents.',
      );
    }
    final contents = <McpResourceContentModel>[];
    for (final raw in rawContents) {
      if (raw is! Map<String, Object?>) {
        throw const FormatException('MCP resource content must be an object.');
      }
      final contentUri = _requiredOutputString(raw, 'uri', maxMcpUriLength);
      final mimeType = _optionalOutputString(
        raw,
        'mimeType',
        maxMcpIdentifierLength,
      );
      final text = raw['text'];
      final blob = raw['blob'];
      if (text is String && blob == null) {
        _requireUtf8Bound(text, maxMcpRetainedTextBytes, 'MCP resource text');
        contents.add(
          McpTextResourceContentModel(
            uri: contentUri,
            text: text,
            mimeType: mimeType,
          ),
        );
      } else if (blob is String && text == null) {
        _requireUtf8Bound(blob, maxMcpPayloadBytes, 'MCP resource blob');
        contents.add(
          McpBlobResourceContentModel(
            uri: contentUri,
            encodedLength: blob.length,
            mimeType: mimeType,
          ),
        );
      } else {
        throw const FormatException(
          'MCP resource content must contain exactly one of text or blob.',
        );
      }
    }
    return McpResourceReadResultModel(
      contents: contents,
      originCallId: _optionalOutputString(
        result,
        'originCallId',
        maxMcpIdentifierLength,
      ),
    );
  }

  Future<McpToolCallResultModel> callMcpTool(McpToolCallQuery query) async {
    final server = _requiredInput(
      query.server,
      'server',
      maxMcpIdentifierLength,
    );
    final threadId = _requiredInput(
      query.threadId,
      'threadId',
      maxMcpIdentifierLength,
    );
    final tool = _requiredInput(query.tool, 'tool', maxMcpIdentifierLength);
    _validateBoundedJson(query.arguments, 'MCP tool arguments');
    final result = await request('mcpServer/tool/call', {
      'server': server,
      'threadId': threadId,
      'tool': tool,
      'arguments': query.arguments,
    });
    _requireMcpPayloadBound(result, 'MCP tool response');
    final rawContent = result['content'];
    if (rawContent is! List<Object?> ||
        rawContent.length > maxMcpToolContents) {
      throw FormatException(
        'MCP tool response must contain at most $maxMcpToolContents contents.',
      );
    }
    final content = <McpToolContentModel>[];
    for (final raw in rawContent) {
      content.add(_parseMcpToolContent(raw));
    }
    final structured = result['structuredContent'];
    String? structuredPreview;
    if (structured != null) {
      _validateBoundedJson(structured, 'MCP structured content');
      structuredPreview = jsonEncode(structured);
      _requireUtf8Bound(
        structuredPreview,
        maxMcpStructuredPreviewBytes,
        'MCP structured content preview',
      );
    }
    final isError = result['isError'];
    if (isError != null && isError is! bool) {
      throw const FormatException('MCP tool isError must be a boolean.');
    }
    return McpToolCallResultModel(
      content: content,
      isError: isError as bool? ?? false,
      structuredContentPreview: structuredPreview,
    );
  }

  Future<List<PluginSummaryModel>> listPlugins({
    List<String> cwds = const [],
    bool forceRefetch = false,
    List<String> marketplaceKinds = const [],
  }) async {
    final normalizedCwds = cwds
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final normalizedKinds = marketplaceKinds
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final result = await request('plugin/list', {
      if (normalizedCwds.isNotEmpty) 'cwds': normalizedCwds,
      if (forceRefetch) 'forceRefetch': true,
      if (normalizedKinds.isNotEmpty) 'marketplaceKinds': normalizedKinds,
    });
    final plugins = <PluginSummaryModel>[];
    final seenIds = <String>{};

    void addPluginMap(
      Map<String, Object?> map, {
      String? fallbackMarketplaceName,
      String? fallbackMarketplacePath,
    }) {
      if (plugins.length >= maxBoundedItems) {
        return;
      }
      final summary = _parsePluginSummary(
        map,
        fallbackMarketplaceName: fallbackMarketplaceName,
        fallbackMarketplacePath: fallbackMarketplacePath,
      );
      if (summary == null || !seenIds.add(summary.id)) {
        return;
      }
      plugins.add(summary);
    }

    final marketplaces = result['marketplaces'];
    if (marketplaces is List<Object?>) {
      for (final marketplace in marketplaces) {
        if (marketplace is! Map<String, Object?>) {
          continue;
        }
        final mpName = _nonEmptyString(marketplace['name']);
        final mpPath = _nonEmptyString(marketplace['path']);
        final list = marketplace['plugins'];
        if (list is List<Object?>) {
          for (final item in list) {
            if (item is Map<String, Object?>) {
              addPluginMap(
                item,
                fallbackMarketplaceName: mpName,
                fallbackMarketplacePath: mpPath,
              );
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

  Future<PluginDetailModel> readPlugin({
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
  }) async {
    final normalizedName = pluginName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        pluginName,
        'pluginName',
        'Plugin name must not be empty.',
      );
    }
    final normalizedPath = _nonEmptyString(marketplacePath);
    final normalizedRemote = _nonEmptyString(remoteMarketplaceName);
    final result = await request('plugin/read', {
      'pluginName': normalizedName,
      'marketplacePath': ?normalizedPath,
      if (normalizedPath == null && normalizedRemote != null)
        'remoteMarketplaceName': normalizedRemote,
    });
    final pluginRaw = result['plugin'];
    final pluginObj = pluginRaw is Map<String, Object?> ? pluginRaw : result;
    final mpName =
        _nonEmptyString(pluginObj['marketplaceName']) ??
        normalizedRemote ??
        'local';
    final mpPath =
        _nonEmptyString(pluginObj['marketplacePath']) ?? normalizedPath;
    final summaryRaw = pluginObj['summary'];
    final summary =
        (summaryRaw is Map<String, Object?>
            ? _parsePluginSummary(
                summaryRaw,
                fallbackMarketplaceName: mpName,
                fallbackMarketplacePath: mpPath,
              )
            : null) ??
        PluginSummaryModel(
          id: normalizedName,
          name: normalizedName,
          pluginName: normalizedName,
          description: _nonEmptyString(pluginObj['description']) ?? '',
          enabled: true,
          marketplaceName: mpName,
          marketplacePath: mpPath,
        );
    final description =
        _nonEmptyString(pluginObj['description']) ?? summary.description;
    final skills = <SkillSummary>[];
    final rawSkills = pluginObj['skills'];
    if (rawSkills is List<Object?>) {
      for (final item in rawSkills.take(maxBoundedItems)) {
        if (item is Map<String, Object?>) {
          final parsed = _parseSkillSummary(item, requirePath: false);
          if (parsed != null) {
            skills.add(parsed);
          }
        }
      }
    }
    final apps = _parsePluginAppReferences(pluginObj['apps']);
    final mcpServers = _parseStringList(pluginObj['mcpServers']);
    final hooks = <PluginHookSummaryModel>[];
    final rawHooks = pluginObj['hooks'];
    if (rawHooks is List<Object?>) {
      for (final item in rawHooks.take(maxBoundedItems)) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        final key = _nonEmptyString(item['key']);
        final eventName = _nonEmptyString(item['eventName']);
        if (key != null && eventName != null) {
          hooks.add(PluginHookSummaryModel(key: key, eventName: eventName));
        }
      }
    }
    return PluginDetailModel(
      summary: summary,
      marketplaceName: mpName,
      marketplacePath: mpPath,
      description: description,
      skills: List<SkillSummary>.unmodifiable(skills),
      apps: apps,
      mcpServers: mcpServers,
      hooks: List<PluginHookSummaryModel>.unmodifiable(hooks),
      shareUrl: _nonEmptyString(pluginObj['shareUrl']),
    );
  }

  Future<PluginInstallResultModel> installPlugin({
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
    String? installAttemptId,
  }) async {
    final normalizedName = pluginName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        pluginName,
        'pluginName',
        'Plugin name must not be empty.',
      );
    }
    final normalizedPath = _nonEmptyString(marketplacePath);
    final normalizedRemote = _nonEmptyString(remoteMarketplaceName);
    final normalizedAttempt = _nonEmptyString(installAttemptId);
    final result = await request('plugin/install', {
      'pluginName': normalizedName,
      'marketplacePath': ?normalizedPath,
      if (normalizedPath == null && normalizedRemote != null)
        'remoteMarketplaceName': normalizedRemote,
      'installAttemptId': ?normalizedAttempt,
    });
    return PluginInstallResultModel(
      authPolicy: _nonEmptyString(result['authPolicy']) ?? 'ON_USE',
      appsNeedingAuth: _parsePluginAppReferences(result['appsNeedingAuth']),
    );
  }

  Future<void> uninstallPlugin({required String pluginId}) async {
    final normalizedId = pluginId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        pluginId,
        'pluginId',
        'Plugin id must not be empty.',
      );
    }
    await request('plugin/uninstall', {'pluginId': normalizedId});
  }

  Future<AppListPage> listApps([
    AppListQuery query = const AppListQuery(),
  ]) async {
    final boundedLimit = query.limit.clamp(1, maxBoundedItems);
    final cursor = _nonEmptyString(query.cursor);
    final threadId = _nonEmptyString(query.threadId);
    final result = await request('app/list', {
      'limit': boundedLimit,
      'cursor': ?cursor,
      'threadId': ?threadId,
      if (query.forceRefetch) 'forceRefetch': true,
    });
    final data = result['data'];
    final apps = <AppSummaryModel>[];
    final seenIds = <String>{};
    if (data is List<Object?>) {
      for (final raw in data) {
        if (apps.length >= boundedLimit || apps.length >= maxBoundedItems) {
          break;
        }
        if (raw is! Map<String, Object?>) {
          continue;
        }
        final id = _nonEmptyString(raw['id']);
        if (id == null || !seenIds.add(id)) {
          continue;
        }
        final name = _nonEmptyString(raw['name']) ?? id;
        final branding = raw['branding'] is Map<String, Object?>
            ? raw['branding'] as Map<String, Object?>
            : null;
        final metadata = raw['appMetadata'] is Map<String, Object?>
            ? raw['appMetadata'] as Map<String, Object?>
            : null;
        final metadataCategories = metadata != null
            ? _parseStringList(metadata['categories'])
            : const <String>[];
        final category =
            _nonEmptyString(branding?['category']) ??
            (metadataCategories.isNotEmpty ? metadataCategories.first : null);
        final developer =
            _nonEmptyString(branding?['developer']) ??
            _nonEmptyString(metadata?['developer']);
        final description =
            _nonEmptyString(raw['description']) ??
            _nonEmptyString(metadata?['seoDescription']) ??
            '';
        apps.add(
          AppSummaryModel(
            id: id,
            name: name,
            description: description,
            isAccessible: raw['isAccessible'] as bool? ?? false,
            isEnabled: raw['isEnabled'] as bool? ?? true,
            distributionChannel: _nonEmptyString(raw['distributionChannel']),
            installUrl: _nonEmptyString(raw['installUrl']),
            category: category,
            developer: developer,
            version: _nonEmptyString(metadata?['version']),
            isDiscoverableApp: branding?['isDiscoverableApp'] as bool? ?? false,
            pluginDisplayNames: _parseStringList(raw['pluginDisplayNames']),
          ),
        );
      }
    }
    return AppListPage(
      apps: List<AppSummaryModel>.unmodifiable(apps),
      nextCursor: _nonEmptyString(result['nextCursor']),
    );
  }

  Future<List<InstalledAppSnapshotModel>> listInstalledApps({
    String? threadId,
    bool forceRefresh = false,
  }) async {
    final normalizedThreadId = _nonEmptyString(threadId);
    final result = await request('app/installed', {
      'threadId': ?normalizedThreadId,
      if (forceRefresh) 'forceRefresh': true,
    });
    final rawApps = result['apps'];
    if (rawApps is! List<Object?>) {
      return const [];
    }
    final apps = <InstalledAppSnapshotModel>[];
    final seenIds = <String>{};
    for (final raw in rawApps) {
      if (apps.length >= maxBoundedItems) {
        break;
      }
      if (raw is! Map<String, Object?>) {
        continue;
      }
      final id = _nonEmptyString(raw['id']);
      if (id == null || !seenIds.add(id)) {
        continue;
      }
      apps.add(
        InstalledAppSnapshotModel(
          id: id,
          runtimeName: _nonEmptyString(raw['runtimeName']),
          enabled: raw['enabled'] as bool? ?? true,
          callable: raw['callable'] as bool? ?? false,
        ),
      );
    }
    return List<InstalledAppSnapshotModel>.unmodifiable(apps);
  }

  Future<AppReadResultModel> readApps({
    required List<String> appIds,
    bool includeTools = true,
    String? threadId,
  }) async {
    final normalizedIds = <String>[];
    final seenRequestedIds = <String>{};
    for (final rawId in appIds) {
      final id = rawId.trim();
      if (id.isEmpty || !seenRequestedIds.add(id)) {
        continue;
      }
      normalizedIds.add(id);
      if (normalizedIds.length >= maxBoundedItems) {
        break;
      }
    }
    if (normalizedIds.isEmpty) {
      return const AppReadResultModel(apps: [], missingAppIds: []);
    }
    final normalizedThreadId = _nonEmptyString(threadId);
    final result = await request('app/read', {
      'appIds': normalizedIds,
      'includeTools': includeTools,
      'threadId': ?normalizedThreadId,
    });
    final apps = <AppDetailModel>[];
    final seenAppIds = <String>{};
    final rawApps = result['apps'];
    if (rawApps is List<Object?>) {
      for (final raw in rawApps) {
        if (apps.length >= maxBoundedItems) {
          break;
        }
        if (raw is! Map<String, Object?>) {
          continue;
        }
        final id = _nonEmptyString(raw['id']);
        if (id == null || !seenAppIds.add(id)) {
          continue;
        }
        final name = _nonEmptyString(raw['name']) ?? id;
        final toolSummaries = <AppToolSummaryModel>[];
        final rawTools = raw['toolSummaries'];
        if (rawTools is List<Object?>) {
          for (final rawTool in rawTools.take(maxBoundedItems)) {
            if (rawTool is! Map<String, Object?>) {
              continue;
            }
            final toolName = _nonEmptyString(rawTool['name']);
            if (toolName == null) {
              continue;
            }
            toolSummaries.add(
              AppToolSummaryModel(
                name: toolName,
                description: _nonEmptyString(rawTool['description']) ?? '',
                title: _nonEmptyString(rawTool['title']),
                isEnabled: rawTool['isEnabled'] as bool? ?? true,
                isReadOnly: rawTool['isReadOnly'] as bool? ?? false,
                disabledReason: _nonEmptyString(rawTool['disabledReason']),
              ),
            );
          }
        }
        apps.add(
          AppDetailModel(
            id: id,
            name: name,
            description: _nonEmptyString(raw['description']) ?? '',
            distributionChannel: _nonEmptyString(raw['distributionChannel']),
            installUrl: _nonEmptyString(raw['installUrl']),
            iconUrl: _nonEmptyString(raw['iconUrl']),
            iconUrlDark: _nonEmptyString(raw['iconUrlDark']),
            pluginDisplayNames: _parseStringList(raw['pluginDisplayNames']),
            toolSummaries: List<AppToolSummaryModel>.unmodifiable(
              toolSummaries,
            ),
          ),
        );
      }
    }
    return AppReadResultModel(
      apps: List<AppDetailModel>.unmodifiable(apps),
      missingAppIds: _parseStringList(result['missingAppIds']),
    );
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

  static McpToolContentModel _parseMcpToolContent(Object? raw) {
    if (raw is String) {
      _requireUtf8Bound(raw, maxMcpRetainedTextBytes, 'MCP tool text');
      return McpToolContentModel(kind: 'text', summary: 'Text', text: raw);
    }
    if (raw is! Map<String, Object?>) {
      throw const FormatException(
        'MCP tool content must be a string or object.',
      );
    }
    final kind = _nonEmptyString(raw['type']) ?? 'content';
    final directText = raw['text'];
    final directData = raw['data'];
    final directUri = _nonEmptyString(raw['uri']);
    final directMime = _nonEmptyString(raw['mimeType']);
    if (directText is String) {
      _requireUtf8Bound(directText, maxMcpRetainedTextBytes, 'MCP tool text');
      return McpToolContentModel(
        kind: kind,
        summary: directMime == null ? 'Text' : 'Text · $directMime',
        text: directText,
        uri: directUri,
        mimeType: directMime,
      );
    }
    if (directData is String) {
      _requireUtf8Bound(directData, maxMcpPayloadBytes, 'MCP tool binary data');
      return McpToolContentModel(
        kind: kind,
        summary: directMime == null
            ? 'Encoded data (${directData.length} characters)'
            : '$directMime · ${directData.length} encoded characters',
        uri: directUri,
        mimeType: directMime,
        encodedDataLength: directData.length,
      );
    }
    final resource = raw['resource'];
    if (resource is Map<String, Object?>) {
      final uri = _optionalOutputString(resource, 'uri', maxMcpUriLength);
      final mime = _optionalOutputString(
        resource,
        'mimeType',
        maxMcpIdentifierLength,
      );
      final text = resource['text'];
      final blob = resource['blob'];
      if (text is String && blob == null) {
        _requireUtf8Bound(
          text,
          maxMcpRetainedTextBytes,
          'MCP embedded resource text',
        );
        return McpToolContentModel(
          kind: kind,
          summary: uri == null ? 'Embedded resource' : 'Resource · $uri',
          text: text,
          uri: uri,
          mimeType: mime,
        );
      }
      if (blob is String && text == null) {
        _requireUtf8Bound(
          blob,
          maxMcpPayloadBytes,
          'MCP embedded resource blob',
        );
        return McpToolContentModel(
          kind: kind,
          summary: uri == null
              ? 'Embedded data (${blob.length} characters)'
              : 'Resource · $uri · ${blob.length} encoded characters',
          uri: uri,
          mimeType: mime,
          encodedDataLength: blob.length,
        );
      }
    }
    _validateBoundedJson(raw, 'MCP tool content');
    final preview = jsonEncode(raw);
    _requireUtf8Bound(
      preview,
      maxMcpStructuredPreviewBytes,
      'MCP tool content preview',
    );
    return McpToolContentModel(
      kind: kind,
      summary: preview,
      uri: directUri,
      mimeType: directMime,
    );
  }

  static void _requireMcpPayloadBound(JsonObject value, String label) {
    _validateBoundedJson(value, label);
    final encoded = jsonEncode(value);
    _requireUtf8Bound(encoded, maxMcpPayloadBytes, label);
  }

  static void _validateBoundedJson(Object? value, String label) {
    var nodes = 0;

    void visit(Object? current, int depth) {
      if (depth > maxMcpJsonDepth) {
        throw FormatException('$label exceeds depth $maxMcpJsonDepth.');
      }
      nodes++;
      if (nodes > maxMcpJsonNodes) {
        throw FormatException('$label exceeds $maxMcpJsonNodes JSON nodes.');
      }
      switch (current) {
        case null || bool() || num():
          if (current is double && !current.isFinite) {
            throw FormatException('$label contains a non-finite number.');
          }
        case String():
          _requireUtf8Bound(current, maxMcpRetainedTextBytes, '$label string');
        case List<Object?>():
          for (final item in current) {
            visit(item, depth + 1);
          }
        case Map<String, Object?>():
          for (final entry in current.entries) {
            _requireUtf8Bound(entry.key, maxMcpIdentifierLength, '$label key');
            visit(entry.value, depth + 1);
          }
        default:
          throw FormatException('$label contains a non-JSON value.');
      }
    }

    visit(value, 0);
    late final String encoded;
    try {
      encoded = jsonEncode(value);
    } on Object catch (error) {
      throw FormatException('$label is not JSON encodable: $error');
    }
    _requireUtf8Bound(encoded, maxMcpPayloadBytes, label);
  }

  static String _requiredInput(String value, String label, int maximumLength) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maximumLength) {
      throw ArgumentError.value(
        value,
        label,
        'Must be a non-empty string no longer than $maximumLength characters.',
      );
    }
    return trimmed;
  }

  static String? _optionalInput(
    String? value,
    String label,
    int maximumLength,
  ) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > maximumLength) {
      throw ArgumentError.value(
        value,
        label,
        'Must be no longer than $maximumLength characters.',
      );
    }
    return trimmed;
  }

  static String _requiredOutputString(
    JsonObject value,
    String key,
    int maximumLength,
  ) {
    final result = value[key];
    if (result is! String || result.isEmpty || result.length > maximumLength) {
      throw FormatException(
        '$key must be a non-empty string no longer than '
        '$maximumLength characters.',
      );
    }
    return result;
  }

  static String? _optionalOutputString(
    JsonObject value,
    String key,
    int maximumLength,
  ) {
    final result = value[key];
    if (result == null) {
      return null;
    }
    if (result is! String || result.length > maximumLength) {
      throw FormatException(
        '$key must be a string no longer than $maximumLength characters.',
      );
    }
    return result;
  }

  static void _requireUtf8Bound(String value, int maximumBytes, String label) {
    if (utf8.encode(value).length > maximumBytes) {
      throw FormatException('$label exceeds $maximumBytes UTF-8 bytes.');
    }
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _parseStringList(Object? rawList) {
    if (rawList is! List<Object?>) {
      return const [];
    }
    final items = <String>[];
    final seen = <String>{};
    for (final raw in rawList) {
      if (items.length >= maxBoundedItems) {
        break;
      }
      final text = _nonEmptyString(raw);
      if (text != null && seen.add(text)) {
        items.add(text);
      }
    }
    return List<String>.unmodifiable(items);
  }

  static SkillSummary? _parseSkillSummary(
    Map<String, Object?> rawSkill, {
    required bool requirePath,
  }) {
    final name = _nonEmptyString(rawSkill['name']);
    final path = _nonEmptyString(rawSkill['path']) ?? '';
    if (name == null || (requirePath && path.isEmpty)) {
      return null;
    }
    final interfaceMap = rawSkill['interface'] is Map<String, Object?>
        ? rawSkill['interface'] as Map<String, Object?>
        : null;
    final description =
        _nonEmptyString(rawSkill['shortDescription']) ??
        _nonEmptyString(interfaceMap?['shortDescription']) ??
        _nonEmptyString(rawSkill['description']) ??
        '';
    final enabled = rawSkill['enabled'] as bool? ?? true;
    final scope = _nonEmptyString(rawSkill['scope']) ?? 'repo';
    return SkillSummary(
      name: name,
      description: description,
      path: path,
      enabled: enabled,
      scope: scope,
    );
  }

  static PluginSummaryModel? _parsePluginSummary(
    Map<String, Object?> map, {
    String? fallbackMarketplaceName,
    String? fallbackMarketplacePath,
  }) {
    final rawName = _nonEmptyString(map['name']);
    final id = _nonEmptyString(map['id']) ?? rawName;
    if (id == null) {
      return null;
    }
    final interfaceMap = map['interface'] is Map<String, Object?>
        ? map['interface'] as Map<String, Object?>
        : null;
    final displayName = _nonEmptyString(interfaceMap?['displayName']);
    final description =
        _nonEmptyString(interfaceMap?['shortDescription']) ??
        _nonEmptyString(map['description']) ??
        _nonEmptyString(interfaceMap?['longDescription']) ??
        '';
    final enabled = map['enabled'] as bool? ?? true;
    final installed = map['installed'] as bool? ?? enabled;
    final sourceMap = map['source'] is Map<String, Object?>
        ? map['source'] as Map<String, Object?>
        : null;
    return PluginSummaryModel(
      id: id,
      name: displayName ?? rawName ?? id,
      pluginName: rawName ?? id,
      description: description,
      enabled: enabled,
      installed: installed,
      version:
          _nonEmptyString(map['version']) ??
          _nonEmptyString(map['localVersion']),
      marketplaceName:
          _nonEmptyString(map['marketplaceName']) ?? fallbackMarketplaceName,
      marketplacePath:
          _nonEmptyString(map['marketplacePath']) ?? fallbackMarketplacePath,
      sourceType: _nonEmptyString(sourceMap?['type']),
      installPolicy: _nonEmptyString(map['installPolicy']) ?? 'AVAILABLE',
      authPolicy: _nonEmptyString(map['authPolicy']) ?? 'ON_USE',
      availability: _nonEmptyString(map['availability']) ?? 'AVAILABLE',
      disabledReason: _nonEmptyString(map['disabledReason']),
      category: _nonEmptyString(interfaceMap?['category']),
      capabilities: _parseStringList(interfaceMap?['capabilities']),
    );
  }

  static List<PluginAppReferenceModel> _parsePluginAppReferences(
    Object? rawApps,
  ) {
    if (rawApps is! List<Object?>) {
      return const [];
    }
    final apps = <PluginAppReferenceModel>[];
    final seenIds = <String>{};
    for (final raw in rawApps) {
      if (apps.length >= maxBoundedItems) {
        break;
      }
      if (raw is! Map<String, Object?>) {
        continue;
      }
      final id = _nonEmptyString(raw['id']);
      if (id == null || !seenIds.add(id)) {
        continue;
      }
      apps.add(
        PluginAppReferenceModel(
          id: id,
          name: _nonEmptyString(raw['name']) ?? id,
          description: _nonEmptyString(raw['description']),
          category: _nonEmptyString(raw['category']),
          installUrl: _nonEmptyString(raw['installUrl']),
        ),
      );
    }
    return List<PluginAppReferenceModel>.unmodifiable(apps);
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
