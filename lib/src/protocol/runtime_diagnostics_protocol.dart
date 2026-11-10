import '../domain/runtime_diagnostics_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';

final class RuntimeDiagnosticsProtocolAdapter {
  RuntimeDiagnosticsProtocolAdapter({
    required this.request,
    Stream<CodexNotification> notifications = const Stream.empty(),
  }) : events = notifications
           .map(_parseNotification)
           .where((event) => event != null)
           .cast<RuntimeDiagnosticsEvent>();

  final ProtocolRequest request;
  final Stream<RuntimeDiagnosticsEvent> events;

  static final _unsafeProviderLabelCharacters = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u061C\u200E\u200F\u2028-\u202E\u2066-\u2069]+',
  );

  Future<AccountDiagnosticsSnapshot> readAccount({
    bool refreshToken = false,
  }) async {
    final response = await request('account/read', {
      'refreshToken': refreshToken,
    });
    final requiresOpenaiAuth = _requiredBool(
      response,
      'requiresOpenaiAuth',
      context: 'account/read',
    );
    final rawAccount = response['account'];
    if (rawAccount == null) {
      return AccountDiagnosticsSnapshot(
        requiresOpenaiAuth: requiresOpenaiAuth,
        accountType: 'unauthenticated',
      );
    }
    if (rawAccount is! Map<String, Object?>) {
      throw const ProtocolViolation(
        'account/read account field must be an object or null.',
      );
    }
    final type = _requiredBoundedString(
      rawAccount,
      'type',
      maxDiagnosticsIdentifierLength,
      context: 'account/read.account',
    );
    return switch (type) {
      'chatgpt' => AccountDiagnosticsSnapshot(
        requiresOpenaiAuth: requiresOpenaiAuth,
        accountType: type,
        planType: _requiredBoundedString(
          rawAccount,
          'planType',
          maxDiagnosticsIdentifierLength,
          context: 'account/read.account',
        ),
        email: _optionalBoundedString(
          rawAccount,
          'email',
          maxDiagnosticsLabelLength,
          context: 'account/read.account',
        ),
        workspaceName: _optionalBoundedString(
          rawAccount,
          'workspaceName',
          maxDiagnosticsLabelLength,
          context: 'account/read.account',
        ),
      ),
      'amazonBedrock' => AccountDiagnosticsSnapshot(
        requiresOpenaiAuth: requiresOpenaiAuth,
        accountType: type,
        usesCodexManagedCredentials:
            _optionalBool(
              rawAccount,
              'usesCodexManagedCredentials',
              context: 'account/read.account',
            ) ??
            false,
      ),
      _ => AccountDiagnosticsSnapshot(
        requiresOpenaiAuth: requiresOpenaiAuth,
        accountType: type,
        planType: _optionalBoundedString(
          rawAccount,
          'planType',
          maxDiagnosticsIdentifierLength,
          context: 'account/read.account',
        ),
      ),
    };
  }

  Future<RateLimitsDiagnosticsSnapshot> readAccountRateLimits({
    bool excludeResetCreditDetails = false,
  }) async {
    final response = await request('account/rateLimits/read', {
      if (excludeResetCreditDetails) 'excludeResetCreditDetails': true,
    });
    final rawPrimary = response['rateLimits'];
    if (rawPrimary is! Map<String, Object?>) {
      throw const ProtocolViolation(
        'account/rateLimits/read rateLimits must be an object.',
      );
    }
    final primaryBucket = _parseRateLimitBucket(
      rawPrimary,
      context: 'account/rateLimits/read.rateLimits',
    );

    final buckets = <RateLimitBucketSnapshot>[];
    final rawById = response['rateLimitsByLimitId'];
    if (rawById != null) {
      if (rawById is! Map<String, Object?>) {
        throw const ProtocolViolation(
          'account/rateLimits/read rateLimitsByLimitId must be an object or null.',
        );
      }
      for (final entry in rawById.entries) {
        if (buckets.length >= maxRateLimitBuckets) {
          break;
        }
        final value = entry.value;
        if (value is! Map<String, Object?>) {
          throw const ProtocolViolation(
            'account/rateLimits/read bucket entry must be an object.',
          );
        }
        final parsed = _parseRateLimitBucket(
          value,
          fallbackLimitId: entry.key,
          context: 'account/rateLimits/read.rateLimitsByLimitId',
        );
        buckets.add(parsed);
      }
    }

    int? availableResetCreditsCount;
    final rawResetCredits = response['rateLimitResetCredits'];
    if (rawResetCredits != null) {
      if (rawResetCredits is! Map<String, Object?>) {
        throw const ProtocolViolation(
          'account/rateLimits/read rateLimitResetCredits must be an object or null.',
        );
      }
      final count = _requiredInt(
        rawResetCredits,
        'availableCount',
        context: 'account/rateLimits/read.rateLimitResetCredits',
      );
      availableResetCreditsCount = count < 0 ? 0 : count;
    }

    return RateLimitsDiagnosticsSnapshot(
      primaryBucket: primaryBucket,
      bucketsById: buckets,
      ordinaryUsageAllowed: _optionalBool(
        response,
        'ordinaryUsageAllowed',
        context: 'account/rateLimits/read',
      ),
      availableResetCreditsCount: availableResetCreditsCount,
    );
  }

  Future<PermissionProfileListSnapshot> listPermissionProfiles({
    String? cwd,
    int? limit,
    String? cursor,
  }) async {
    final normalizedCwd = _optionalInputString(
      cwd,
      'cwd',
      maxDiagnosticsPathLength,
    );
    final normalizedCursor = _optionalInputString(
      cursor,
      'cursor',
      maxDiagnosticsIdentifierLength,
    );
    if (limit != null && limit < 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be non-negative.');
    }
    final response = await request('permissionProfile/list', {
      'cwd': ?normalizedCwd,
      'limit': ?limit,
      'cursor': ?normalizedCursor,
    });
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ProtocolViolation(
        'permissionProfile/list data must be an array.',
      );
    }
    final profiles = <PermissionProfileSummaryModel>[];
    final seenIds = <String>{};
    var truncated = false;
    for (final item in data) {
      if (item is! Map<String, Object?>) {
        throw const ProtocolViolation(
          'permissionProfile/list entry must be an object.',
        );
      }
      final id = _requiredBoundedString(
        item,
        'id',
        maxDiagnosticsIdentifierLength,
        context: 'permissionProfile/list',
      );
      if (!seenIds.add(id)) {
        continue;
      }
      if (profiles.length >= maxPermissionProfiles) {
        truncated = true;
        break;
      }
      profiles.add(
        PermissionProfileSummaryModel(
          id: id,
          allowed: _requiredBool(
            item,
            'allowed',
            context: 'permissionProfile/list',
          ),
          description: _optionalBoundedString(
            item,
            'description',
            maxDiagnosticsDescriptionLength,
            context: 'permissionProfile/list',
          ),
        ),
      );
    }
    final nextCursor = _optionalBoundedString(
      response,
      'nextCursor',
      maxDiagnosticsIdentifierLength,
      context: 'permissionProfile/list',
    );
    return PermissionProfileListSnapshot(
      profiles: profiles,
      nextCursor: truncated ? null : nextCursor,
      hasMore: nextCursor != null || truncated,
    );
  }

  Future<ConfigDiagnosticsSnapshot> readConfig({
    String? cwd,
    bool includeLayers = true,
  }) async {
    final normalizedCwd = _optionalInputString(
      cwd,
      'cwd',
      maxDiagnosticsPathLength,
    );
    final response = await request('config/read', {
      'includeLayers': includeLayers,
      'cwd': ?normalizedCwd,
    });
    final config = response['config'];
    if (config is! Map<String, Object?>) {
      throw const ProtocolViolation('config/read config must be an object.');
    }
    final origins = response['origins'];
    if (origins is! Map<String, Object?>) {
      throw const ProtocolViolation('config/read origins must be an object.');
    }

    final layers = <ConfigLayerSummaryModel>[];
    final rawLayers = response['layers'];
    if (rawLayers != null) {
      if (rawLayers is! List<Object?>) {
        throw const ProtocolViolation(
          'config/read layers must be an array or null.',
        );
      }
      for (final rawLayer in rawLayers) {
        if (layers.length >= maxConfigLayers) {
          break;
        }
        if (rawLayer is! Map<String, Object?>) {
          throw const ProtocolViolation(
            'config/read layer entry must be an object.',
          );
        }
        layers.add(_parseConfigLayer(rawLayer));
      }
    }

    // Extract only the bounded typed summary from `config` and `origins`;
    // discard raw maps, instructions, and nested provider/MCP definitions.
    return ConfigDiagnosticsSnapshot(
      configKeyCount: config.length,
      originCount: origins.length,
      layers: layers,
      model: _optionalBoundedString(
        config,
        'model',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      reviewModel: _optionalBoundedString(
        config,
        'review_model',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      modelProvider: _optionalBoundedString(
        config,
        'model_provider',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      modelReasoningEffort: _optionalBoundedString(
        config,
        'model_reasoning_effort',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      modelReasoningSummary: _optionalBoundedString(
        config,
        'model_reasoning_summary',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      modelVerbosity: _optionalBoundedString(
        config,
        'model_verbosity',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      approvalPolicy: _parseApprovalPolicySummary(config['approval_policy']),
      approvalsReviewer: _optionalBoundedString(
        config,
        'approvals_reviewer',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      sandboxMode: _optionalBoundedString(
        config,
        'sandbox_mode',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      serviceTier: _optionalBoundedString(
        config,
        'service_tier',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      webSearchMode: _optionalBoundedString(
        config,
        'web_search',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      defaultPermissions: _optionalBoundedString(
        config,
        'default_permissions',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      profile: _optionalBoundedString(
        config,
        'profile',
        maxDiagnosticsIdentifierLength,
        context: 'config/read.config',
      ),
      modelContextWindow: _optionalInt(
        config,
        'model_context_window',
        context: 'config/read.config',
      ),
      modelAutoCompactTokenLimit: _optionalInt(
        config,
        'model_auto_compact_token_limit',
        context: 'config/read.config',
      ),
    );
  }

  Future<ConfigRequirementsSummaryModel> readConfigRequirements() async {
    final response = await request('configRequirements/read', const {});
    final supportsIndependentSpeedModes = _optionalBool(
      response,
      'supportsIndependentSpeedModes',
      context: 'configRequirements/read',
    );
    final rawRequirements = response['requirements'];
    if (rawRequirements == null) {
      return ConfigRequirementsSummaryModel(
        hasRequirements: false,
        supportsIndependentSpeedModes: supportsIndependentSpeedModes,
      );
    }
    if (rawRequirements is! Map<String, Object?>) {
      throw const ProtocolViolation(
        'configRequirements/read requirements must be an object or null.',
      );
    }
    return ConfigRequirementsSummaryModel(
      hasRequirements: true,
      supportsIndependentSpeedModes: supportsIndependentSpeedModes,
      allowedApprovalPolicies: _parseAllowedApprovalPolicies(
        rawRequirements['allowedApprovalPolicies'],
      ),
      allowedSandboxModes: _parseBoundedStringList(
        rawRequirements['allowedSandboxModes'],
        context: 'configRequirements/read.allowedSandboxModes',
      ),
      allowedWebSearchModes: _parseBoundedStringList(
        rawRequirements['allowedWebSearchModes'],
        context: 'configRequirements/read.allowedWebSearchModes',
      ),
      allowedLoginMethods: _parseBoundedStringList(
        rawRequirements['allowedLoginMethods'],
        context: 'configRequirements/read.allowedLoginMethods',
      ),
      defaultPermissions: _optionalBoundedString(
        rawRequirements,
        'defaultPermissions',
        maxDiagnosticsIdentifierLength,
        context: 'configRequirements/read.requirements',
      ),
      modelProvider: _optionalBoundedString(
        rawRequirements,
        'modelProvider',
        maxDiagnosticsIdentifierLength,
        context: 'configRequirements/read.requirements',
      ),
      enforceResidency: _optionalBoundedString(
        rawRequirements,
        'enforceResidency',
        maxDiagnosticsIdentifierLength,
        context: 'configRequirements/read.requirements',
      ),
      allowRemoteControl: _optionalBool(
        rawRequirements,
        'allowRemoteControl',
        context: 'configRequirements/read.requirements',
      ),
      allowManagedHooksOnly: _optionalBool(
        rawRequirements,
        'allowManagedHooksOnly',
        context: 'configRequirements/read.requirements',
      ),
      allowLoginShell: _optionalBool(
        rawRequirements,
        'allowLoginShell',
        context: 'configRequirements/read.requirements',
      ),
      allowBrowserAndComputerUse: _optionalBool(
        rawRequirements,
        'allowBrowserAndComputerUse',
        context: 'configRequirements/read.requirements',
      ),
    );
  }

  Future<ModelProviderCapabilitiesSnapshot>
  readModelProviderCapabilities() async {
    final response = await request('modelProvider/capabilities/read', const {});
    return ModelProviderCapabilitiesSnapshot(
      imageGeneration: _requiredBool(
        response,
        'imageGeneration',
        context: 'modelProvider/capabilities/read',
      ),
      webSearch: _requiredBool(
        response,
        'webSearch',
        context: 'modelProvider/capabilities/read',
      ),
    );
  }

  Future<ModelProviderInventorySnapshot> listModelProviders() async {
    const method = 'modelProvider/list';
    final JsonObject response;
    try {
      response = await request(method, const {});
    } on JsonRpcException catch (error) {
      if (error.code == -32601 ||
          (error.code == -32600 &&
              error.message.startsWith(
                'Invalid request: unknown variant `$method`',
              ))) {
        return const ModelProviderInventorySnapshot.unsupported();
      }
      rethrow;
    }

    final data = response['data'];
    final defaultId = response['defaultProviderId'];
    if (data is! List<Object?> || defaultId is! String || defaultId.isEmpty) {
      throw const ProtocolViolation('Invalid modelProvider/list response.');
    }

    final providers = <ModelProviderInventoryEntry>[];
    for (final provider in data.take(maxModelProviders)) {
      if (provider is! JsonObject) {
        throw const ProtocolViolation('Invalid modelProvider/list entry.');
      }
      final id = provider['id'];
      final rawName = provider['name'];
      if (id is! String || rawName is! String) {
        throw const ProtocolViolation('Invalid modelProvider/list identity.');
      }
      final settings = provider['settings'];
      if (settings is! JsonObject || settings['type'] is! String) {
        throw const ProtocolViolation('Invalid modelProvider/list settings.');
      }

      // Raw endpoint, auth and cloud settings belong to the stock runtime.
      // Keep only the kind, a display name and the exact default comparison.
      final name = _truncateString(
        rawName,
        maxDiagnosticsLabelLength,
      ).replaceAll(_unsafeProviderLabelCharacters, ' ').trim();
      providers.add(
        ModelProviderInventoryEntry(
          name: name.isEmpty ? 'Unnamed provider' : name,
          kind: switch (settings['type']) {
            'openai' => ModelProviderKind.openai,
            'customGateway' => ModelProviderKind.customGateway,
            'bedrock' => ModelProviderKind.bedrock,
            'gcp' => ModelProviderKind.gcp,
            _ => ModelProviderKind.other,
          },
          isDefault: id == defaultId,
        ),
      );
    }

    return ModelProviderInventorySnapshot(
      providers: providers,
      reportedCount: data.length,
    );
  }

  Future<HooksDiagnosticsSnapshot> listHooks({
    List<String> cwds = const [],
    String? threadId,
  }) async {
    final normalizedThreadId = _optionalInputString(
      threadId,
      'threadId',
      maxDiagnosticsIdentifierLength,
    );
    final normalizedCwds = <String>[];
    final seenCwds = <String>{};
    for (final cwd in cwds) {
      if (normalizedCwds.length >= maxHookEntries) {
        break;
      }
      final trimmed = _optionalInputString(
        cwd,
        'cwd',
        maxDiagnosticsPathLength,
      );
      if (trimmed != null && seenCwds.add(trimmed)) {
        normalizedCwds.add(trimmed);
      }
    }

    final response = await request(
      'hooks/list',
      normalizedThreadId != null
          ? {'threadId': normalizedThreadId}
          : {'cwds': normalizedCwds},
    );
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ProtocolViolation('hooks/list data must be an array.');
    }

    final entries = <WorkspaceHooksEntrySummary>[];
    var totalHookCount = 0;
    var totalErrorCount = 0;
    var totalWarningCount = 0;

    for (final rawEntry in data) {
      if (entries.length >= maxHookEntries) {
        break;
      }
      if (rawEntry is! Map<String, Object?>) {
        throw const ProtocolViolation('hooks/list entry must be an object.');
      }
      final entryCwd = _requiredBoundedString(
        rawEntry,
        'cwd',
        maxDiagnosticsPathLength,
        context: 'hooks/list.entry',
      );
      final rawHooks = rawEntry['hooks'];
      if (rawHooks is! List<Object?>) {
        throw const ProtocolViolation(
          'hooks/list.entry.hooks must be an array.',
        );
      }
      final rawErrors = rawEntry['errors'];
      if (rawErrors is! List<Object?>) {
        throw const ProtocolViolation(
          'hooks/list.entry.errors must be an array.',
        );
      }
      final rawWarnings = rawEntry['warnings'];
      if (rawWarnings is! List<Object?>) {
        throw const ProtocolViolation(
          'hooks/list.entry.warnings must be an array.',
        );
      }

      final hooks = <HookSummaryModel>[];
      for (final rawHook in rawHooks) {
        if (hooks.length >= maxHooksPerWorkspace ||
            totalHookCount >= maxTotalDiagnosticsHooks) {
          break;
        }
        if (rawHook is! Map<String, Object?>) {
          throw const ProtocolViolation('hooks/list hook must be an object.');
        }
        hooks.add(_parseHookMetadata(rawHook));
        totalHookCount++;
      }

      final errors = <HookErrorSummaryModel>[];
      for (final rawError in rawErrors) {
        if (errors.length >= maxHookDiagnosticsPerWorkspace) {
          break;
        }
        if (rawError is! Map<String, Object?>) {
          throw const ProtocolViolation(
            'hooks/list error entry must be an object.',
          );
        }
        errors.add(
          HookErrorSummaryModel(
            path: _requiredBoundedString(
              rawError,
              'path',
              maxDiagnosticsPathLength,
              context: 'hooks/list.error',
            ),
            message: _requiredBoundedString(
              rawError,
              'message',
              maxDiagnosticsDescriptionLength,
              context: 'hooks/list.error',
            ),
          ),
        );
        totalErrorCount++;
      }

      final warnings = <String>[];
      for (final rawWarning in rawWarnings) {
        if (warnings.length >= maxHookDiagnosticsPerWorkspace) {
          break;
        }
        if (rawWarning is! String) {
          throw const ProtocolViolation(
            'hooks/list warning entry must be a string.',
          );
        }
        final trimmed = _truncateString(
          rawWarning.trim(),
          maxDiagnosticsDescriptionLength,
        );
        if (trimmed.isNotEmpty) {
          warnings.add(trimmed);
          totalWarningCount++;
        }
      }

      entries.add(
        WorkspaceHooksEntrySummary(
          cwd: entryCwd,
          hooks: hooks,
          errors: errors,
          warnings: warnings,
        ),
      );
    }

    return HooksDiagnosticsSnapshot(
      entries: entries,
      totalHookCount: totalHookCount,
      totalErrorCount: totalErrorCount,
      totalWarningCount: totalWarningCount,
    );
  }

  static RuntimeDiagnosticsEvent? _parseNotification(
    CodexNotification notification,
  ) {
    final params = notification.params;
    return switch (notification.method) {
      'account/updated' => AccountUpdatedDiagnosticsEvent(
        authMode: _optionalBoundedString(
          params,
          'authMode',
          maxDiagnosticsIdentifierLength,
          context: 'account/updated',
        ),
        planType: _optionalBoundedString(
          params,
          'planType',
          maxDiagnosticsIdentifierLength,
          context: 'account/updated',
        ),
      ),
      'account/rateLimits/updated' => _parseRateLimitsUpdatedNotification(
        params,
      ),
      _ => null,
    };
  }

  static AccountRateLimitsUpdatedDiagnosticsEvent
  _parseRateLimitsUpdatedNotification(JsonObject params) {
    final rawRateLimits = params['rateLimits'];
    if (rawRateLimits is! Map<String, Object?>) {
      throw const ProtocolViolation(
        'account/rateLimits/updated rateLimits must be an object.',
      );
    }
    return AccountRateLimitsUpdatedDiagnosticsEvent(
      rateLimits: _parseRateLimitBucket(
        rawRateLimits,
        context: 'account/rateLimits/updated.rateLimits',
      ),
    );
  }

  static RateLimitBucketSnapshot _parseRateLimitBucket(
    JsonObject json, {
    required String context,
    String? fallbackLimitId,
  }) {
    final limitId =
        _optionalBoundedString(
          json,
          'limitId',
          maxDiagnosticsIdentifierLength,
          context: context,
        ) ??
        (fallbackLimitId == null
            ? null
            : _truncateString(
                fallbackLimitId.trim(),
                maxDiagnosticsIdentifierLength,
              ));
    return RateLimitBucketSnapshot(
      limitId: limitId != null && limitId.isEmpty ? null : limitId,
      limitName: _optionalBoundedString(
        json,
        'limitName',
        maxDiagnosticsLabelLength,
        context: context,
      ),
      normalModelSlug: _optionalBoundedString(
        json,
        'normalModelSlug',
        maxDiagnosticsIdentifierLength,
        context: context,
      ),
      planType: _optionalBoundedString(
        json,
        'planType',
        maxDiagnosticsIdentifierLength,
        context: context,
      ),
      primary: _parseRateLimitWindow(
        json['primary'],
        context: '$context.primary',
      ),
      secondary: _parseRateLimitWindow(
        json['secondary'],
        context: '$context.secondary',
      ),
      credits: _parseCredits(json['credits'], context: '$context.credits'),
      individualLimit: _parseSpendControl(
        json['individualLimit'],
        context: '$context.individualLimit',
      ),
      rateLimitReachedType: _optionalBoundedString(
        json,
        'rateLimitReachedType',
        maxDiagnosticsIdentifierLength,
        context: context,
      ),
      spendControlReached: _optionalBool(
        json,
        'spendControlReached',
        context: context,
      ),
    );
  }

  static RateLimitWindowSnapshot? _parseRateLimitWindow(
    Object? raw, {
    required String context,
  }) {
    if (raw == null) {
      return null;
    }
    if (raw is! Map<String, Object?>) {
      throw ProtocolViolation('$context must be an object or null.');
    }
    final usedPercent = _requiredInt(raw, 'usedPercent', context: context);
    return RateLimitWindowSnapshot(
      usedPercent: usedPercent.clamp(0, 100),
      windowDurationMins: _optionalInt(
        raw,
        'windowDurationMins',
        context: context,
      ),
      resetsAtEpochSeconds: _optionalInt(raw, 'resetsAt', context: context),
    );
  }

  static CreditsDiagnosticsSnapshot? _parseCredits(
    Object? raw, {
    required String context,
  }) {
    if (raw == null) {
      return null;
    }
    if (raw is! Map<String, Object?>) {
      throw ProtocolViolation('$context must be an object or null.');
    }
    return CreditsDiagnosticsSnapshot(
      hasCredits: _requiredBool(raw, 'hasCredits', context: context),
      unlimited: _requiredBool(raw, 'unlimited', context: context),
      balance: _optionalBoundedString(
        raw,
        'balance',
        maxDiagnosticsIdentifierLength,
        context: context,
      ),
    );
  }

  static SpendControlDiagnosticsSnapshot? _parseSpendControl(
    Object? raw, {
    required String context,
  }) {
    if (raw == null) {
      return null;
    }
    if (raw is! Map<String, Object?>) {
      throw ProtocolViolation('$context must be an object or null.');
    }
    final remaining = _requiredInt(raw, 'remainingPercent', context: context);
    return SpendControlDiagnosticsSnapshot(
      limit: _requiredBoundedString(
        raw,
        'limit',
        maxDiagnosticsIdentifierLength,
        context: context,
      ),
      used: _requiredBoundedString(
        raw,
        'used',
        maxDiagnosticsIdentifierLength,
        context: context,
      ),
      remainingPercent: remaining.clamp(0, 100),
      resetsAtEpochSeconds: _requiredInt(raw, 'resetsAt', context: context),
    );
  }

  static ConfigLayerSummaryModel _parseConfigLayer(JsonObject layer) {
    final rawName = layer['name'];
    if (rawName is! Map<String, Object?>) {
      throw const ProtocolViolation(
        'config/read layer.name must be an object.',
      );
    }
    final sourceType = _requiredBoundedString(
      rawName,
      'type',
      maxDiagnosticsIdentifierLength,
      context: 'config/read.layer.name',
    );
    final sourceLocation =
        _optionalBoundedString(
          rawName,
          'file',
          maxDiagnosticsPathLength,
          context: 'config/read.layer.name',
        ) ??
        _optionalBoundedString(
          rawName,
          'dotCodexFolder',
          maxDiagnosticsPathLength,
          context: 'config/read.layer.name',
        ) ??
        _optionalBoundedString(
          rawName,
          'domain',
          maxDiagnosticsLabelLength,
          context: 'config/read.layer.name',
        ) ??
        _optionalBoundedString(
          rawName,
          'name',
          maxDiagnosticsLabelLength,
          context: 'config/read.layer.name',
        );
    final profile = _optionalBoundedString(
      rawName,
      'profile',
      maxDiagnosticsIdentifierLength,
      context: 'config/read.layer.name',
    );
    final version = _requiredBoundedString(
      layer,
      'version',
      maxDiagnosticsIdentifierLength,
      context: 'config/read.layer',
    );
    final disabledReason = _optionalBoundedString(
      layer,
      'disabledReason',
      maxDiagnosticsDescriptionLength,
      context: 'config/read.layer',
    );
    final rawLayerConfig = layer['config'];
    final configEntryCount = rawLayerConfig is Map<String, Object?>
        ? rawLayerConfig.length
        : 0;

    return ConfigLayerSummaryModel(
      sourceType: sourceType,
      version: version,
      configEntryCount: configEntryCount,
      sourceLocation: sourceLocation,
      profile: profile,
      disabledReason: disabledReason,
    );
  }

  static String? _parseApprovalPolicySummary(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is String) {
      final trimmed = _truncateString(
        raw.trim(),
        maxDiagnosticsIdentifierLength,
      );
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw is Map<String, Object?> &&
        raw['granular'] is Map<String, Object?>) {
      return 'granular';
    }
    throw const ProtocolViolation(
      'Approval policy field must be a string, granular object, or null.',
    );
  }

  static List<String> _parseAllowedApprovalPolicies(Object? raw) {
    if (raw == null) {
      return const [];
    }
    if (raw is! List<Object?>) {
      throw const ProtocolViolation(
        'configRequirements/read.allowedApprovalPolicies must be an array or null.',
      );
    }
    final result = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      if (result.length >= maxDiagnosticsAllowedItems) {
        break;
      }
      final summary = _parseApprovalPolicySummary(item);
      if (summary != null && seen.add(summary)) {
        result.add(summary);
      }
    }
    return result;
  }

  static List<String> _parseBoundedStringList(
    Object? raw, {
    required String context,
  }) {
    if (raw == null) {
      return const [];
    }
    if (raw is! List<Object?>) {
      throw ProtocolViolation('$context must be an array or null.');
    }
    final result = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      if (result.length >= maxDiagnosticsAllowedItems) {
        break;
      }
      if (item is! String) {
        throw ProtocolViolation('$context items must be strings.');
      }
      final trimmed = _truncateString(
        item.trim(),
        maxDiagnosticsIdentifierLength,
      );
      if (trimmed.isNotEmpty && seen.add(trimmed)) {
        result.add(trimmed);
      }
    }
    return result;
  }

  static HookSummaryModel _parseHookMetadata(JsonObject hook) {
    final handlerType = _requiredBoundedString(
      hook,
      'handlerType',
      maxDiagnosticsIdentifierLength,
      context: 'hooks/list.hook',
    );
    final String? targetSummary = switch (handlerType) {
      'command' => () {
        // Validate that command is a non-empty string per schema, then
        // discard the raw command string so embedded tokens, credentials, or
        // sensitive CLI arguments never enter UI state.
        _requiredBoundedString(
          hook,
          'command',
          maxDiagnosticsDescriptionLength,
          context: 'hooks/list.hook',
        );
        return 'Command handler';
      }(),
      'mcpTool' =>
        '${_requiredBoundedString(hook, 'server', maxDiagnosticsIdentifierLength, context: 'hooks/list.hook')}/'
            '${_requiredBoundedString(hook, 'tool', maxDiagnosticsIdentifierLength, context: 'hooks/list.hook')}',
      _ => null,
    };

    return HookSummaryModel(
      key: _requiredBoundedString(
        hook,
        'key',
        maxDiagnosticsIdentifierLength,
        context: 'hooks/list.hook',
      ),
      eventName: _requiredBoundedString(
        hook,
        'eventName',
        maxDiagnosticsIdentifierLength,
        context: 'hooks/list.hook',
      ),
      handlerType: handlerType,
      enabled: _requiredBool(hook, 'enabled', context: 'hooks/list.hook'),
      isManaged: _requiredBool(hook, 'isManaged', context: 'hooks/list.hook'),
      source: _requiredBoundedString(
        hook,
        'source',
        maxDiagnosticsIdentifierLength,
        context: 'hooks/list.hook',
      ),
      sourcePath: _requiredBoundedString(
        hook,
        'sourcePath',
        maxDiagnosticsPathLength,
        context: 'hooks/list.hook',
      ),
      trustStatus: _requiredBoundedString(
        hook,
        'trustStatus',
        maxDiagnosticsIdentifierLength,
        context: 'hooks/list.hook',
      ),
      timeoutSec: _requiredInt(hook, 'timeoutSec', context: 'hooks/list.hook'),
      isAsync:
          _optionalBool(hook, 'async', context: 'hooks/list.hook') ?? false,
      targetSummary: targetSummary,
      matcher: _optionalBoundedString(
        hook,
        'matcher',
        maxDiagnosticsLabelLength,
        context: 'hooks/list.hook',
      ),
      statusMessage: _optionalBoundedString(
        hook,
        'statusMessage',
        maxDiagnosticsDescriptionLength,
        context: 'hooks/list.hook',
      ),
    );
  }

  static String? _optionalInputString(
    String? value,
    String field,
    int maxLength,
  ) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > maxLength) {
      throw ArgumentError.value(
        value,
        field,
        'Must not exceed $maxLength characters.',
      );
    }
    return trimmed;
  }

  static String _requiredBoundedString(
    JsonObject object,
    String key,
    int maxLength, {
    required String context,
  }) {
    final value = object[key];
    if (value is! String) {
      throw ProtocolViolation('$context.$key must be a string.');
    }
    final trimmed = _truncateString(value.trim(), maxLength);
    if (trimmed.isEmpty) {
      throw ProtocolViolation('$context.$key must not be empty.');
    }
    return trimmed;
  }

  static String? _optionalBoundedString(
    JsonObject object,
    String key,
    int maxLength, {
    required String context,
  }) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ProtocolViolation('$context.$key must be a string or null.');
    }
    final trimmed = _truncateString(value.trim(), maxLength);
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _requiredBool(
    JsonObject object,
    String key, {
    required String context,
  }) {
    final value = object[key];
    if (value is! bool) {
      throw ProtocolViolation('$context.$key must be a boolean.');
    }
    return value;
  }

  static bool? _optionalBool(
    JsonObject object,
    String key, {
    required String context,
  }) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! bool) {
      throw ProtocolViolation('$context.$key must be a boolean or null.');
    }
    return value;
  }

  static int _requiredInt(
    JsonObject object,
    String key, {
    required String context,
  }) {
    final value = object[key];
    if (value is! int) {
      throw ProtocolViolation('$context.$key must be an integer.');
    }
    return value;
  }

  static int? _optionalInt(
    JsonObject object,
    String key, {
    required String context,
  }) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! int) {
      throw ProtocolViolation('$context.$key must be an integer or null.');
    }
    return value;
  }

  static String _truncateString(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    var end = maxLength;
    if (end > 0) {
      final lastUnit = value.codeUnitAt(end - 1);
      if (lastUnit >= 0xD800 && lastUnit <= 0xDBFF) {
        end -= 1;
      }
    }
    return value.substring(0, end);
  }
}
