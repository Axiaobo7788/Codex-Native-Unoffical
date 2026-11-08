part of '../codex_native_app.dart';

class _RuntimeDetailsDialog extends StatefulWidget {
  const _RuntimeDetailsDialog({required this.controller});

  final RuntimeController controller;

  @override
  State<_RuntimeDetailsDialog> createState() => _RuntimeDetailsDialogState();
}

class _RuntimeDetailsDialogState extends State<_RuntimeDetailsDialog> {
  static const int _maxSectionErrorChars = 160;
  static const int _maxAggregateErrorChars = 480;

  StreamSubscription<RuntimeDiagnosticsEvent>? _diagnosticsEventSubscription;
  RuntimeConnectionState? _lastConnectionState;
  var _loading = false;
  var _refreshGeneration = 0;
  var _accountRefreshGeneration = 0;
  final LinkedHashMap<String, String> _sectionErrors =
      LinkedHashMap<String, String>();

  AccountDiagnosticsSnapshot? _account;
  RateLimitsDiagnosticsSnapshot? _rateLimits;
  PermissionProfileListSnapshot? _permissionProfiles;
  ConfigDiagnosticsSnapshot? _config;
  ConfigRequirementsSummaryModel? _configRequirements;
  ModelProviderCapabilitiesSnapshot? _providerCapabilities;
  HooksDiagnosticsSnapshot? _hooks;

  String? get _errorMessage {
    if (_sectionErrors.isEmpty) {
      return null;
    }
    final joined = _sectionErrors.values.join('\n');
    return _truncateDiagnosticsText(joined, _maxAggregateErrorChars);
  }

  bool get _isRemoteOrUnsupported =>
      widget.controller.usesRemote ||
      !widget.controller.supportsRuntimeDiagnostics;

  bool get _canReadLocalDiagnostics =>
      !_isRemoteOrUnsupported &&
      widget.controller.snapshot.state == RuntimeConnectionState.connected;

  bool get _hasAnyDiagnostics =>
      _account != null ||
      _rateLimits != null ||
      _permissionProfiles != null ||
      _config != null ||
      _configRequirements != null ||
      _providerCapabilities != null ||
      _hooks != null;

  @override
  void initState() {
    super.initState();
    _lastConnectionState = widget.controller.snapshot.state;
    widget.controller.addListener(_handleControllerChanged);
    _bindDiagnosticsEvents();
    if (_canReadLocalDiagnostics) {
      unawaited(_refreshDiagnostics());
    }
  }

  @override
  void didUpdateWidget(covariant _RuntimeDetailsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    unawaited(_diagnosticsEventSubscription?.cancel());
    _diagnosticsEventSubscription = null;
    _lastConnectionState = widget.controller.snapshot.state;
    widget.controller.addListener(_handleControllerChanged);
    _bindDiagnosticsEvents();
    if (_canReadLocalDiagnostics) {
      unawaited(_refreshDiagnostics());
    } else {
      _clearDiagnostics();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    unawaited(_diagnosticsEventSubscription?.cancel());
    super.dispose();
  }

  void _bindDiagnosticsEvents() {
    if (_isRemoteOrUnsupported) {
      return;
    }
    _diagnosticsEventSubscription = widget.controller.runtimeDiagnosticsEvents
        .listen(
          _handleDiagnosticsEvent,
          onError: _handleDiagnosticsStreamError,
        );
  }

  void _handleDiagnosticsStreamError(Object error, [StackTrace? _]) {
    if (!mounted || !_canReadLocalDiagnostics) {
      return;
    }
    setState(() {
      _setSectionError('Diagnostics stream', error);
    });
  }

  void _setSectionError(String section, Object? error) {
    if (error == null) {
      _sectionErrors.remove(section);
      return;
    }
    _sectionErrors.remove(section);
    _sectionErrors[section] = _formatBoundedSectionError(section, error);
  }

  static String _formatBoundedSectionError(String section, Object error) {
    final normalized = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    final detail = normalized.isEmpty
        ? 'Request failed.'
        : _truncateDiagnosticsText(normalized, _maxSectionErrorChars);
    return '$section: $detail';
  }

  static String _truncateDiagnosticsText(String value, int maxChars) {
    if (value.length <= maxChars) {
      return value;
    }
    var end = maxChars;
    if (end > 0) {
      final lastUnit = value.codeUnitAt(end - 1);
      if (lastUnit >= 0xD800 && lastUnit <= 0xDBFF) {
        end -= 1;
      }
    }
    return '${value.substring(0, end)}…';
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    final nextState = widget.controller.snapshot.state;
    final previousState = _lastConnectionState;
    _lastConnectionState = nextState;
    if (_canReadLocalDiagnostics &&
        previousState != RuntimeConnectionState.connected) {
      unawaited(_refreshDiagnostics());
      return;
    }
    if (!_canReadLocalDiagnostics && _hasAnyDiagnostics) {
      _clearDiagnostics();
      return;
    }
    setState(() {});
  }

  void _clearDiagnostics() {
    _refreshGeneration++;
    _accountRefreshGeneration++;
    setState(() {
      _loading = false;
      _sectionErrors.clear();
      _account = null;
      _rateLimits = null;
      _permissionProfiles = null;
      _config = null;
      _configRequirements = null;
      _providerCapabilities = null;
      _hooks = null;
    });
  }

  void _handleDiagnosticsEvent(RuntimeDiagnosticsEvent event) {
    if (!mounted || !_canReadLocalDiagnostics) {
      return;
    }
    switch (event) {
      case AccountUpdatedDiagnosticsEvent():
        setState(() {
          _sectionErrors.remove('Diagnostics stream');
          if (_account != null) {
            _account = _account!.applyAccountUpdated(event);
          }
        });
        unawaited(
          _refreshAccountAndRateLimits(
            preservedAuthMode: event.authMode ?? _account?.authMode,
            preservedPlanType: event.planType,
          ),
        );
      case AccountRateLimitsUpdatedDiagnosticsEvent():
        if (_rateLimits != null) {
          setState(() {
            _sectionErrors.remove('Diagnostics stream');
            _rateLimits = _rateLimits!.applyRateLimitsUpdated(event.rateLimits);
          });
        } else {
          unawaited(_refreshAccountAndRateLimits());
        }
    }
  }

  Future<void> _refreshAccountAndRateLimits({
    String? preservedAuthMode,
    String? preservedPlanType,
  }) async {
    if (!_canReadLocalDiagnostics) {
      return;
    }
    final generation = ++_accountRefreshGeneration;
    Object? accountError;
    Object? rateLimitsError;

    AccountDiagnosticsSnapshot? nextAccount;
    try {
      nextAccount = await widget.controller.readAccountDiagnostics();
    } on Object catch (error) {
      accountError = error;
    }

    RateLimitsDiagnosticsSnapshot? nextRateLimits;
    try {
      nextRateLimits = await widget.controller.readAccountRateLimits();
    } on Object catch (error) {
      rateLimitsError = error;
    }

    if (!mounted ||
        generation != _accountRefreshGeneration ||
        !_canReadLocalDiagnostics) {
      return;
    }
    setState(() {
      if (nextAccount != null) {
        _account = nextAccount.copyWith(
          authMode:
              nextAccount.authMode ?? preservedAuthMode ?? _account?.authMode,
          planType: nextAccount.planType ?? preservedPlanType,
        );
      }
      if (nextRateLimits != null) {
        _rateLimits = nextRateLimits;
      }
      _setSectionError('Account', accountError);
      _setSectionError('Rate limits', rateLimitsError);
    });
  }

  Future<void> _refreshDiagnostics() async {
    if (!_canReadLocalDiagnostics) {
      return;
    }
    final generation = ++_refreshGeneration;
    final accountGeneration = ++_accountRefreshGeneration;
    setState(() {
      _loading = true;
      _sectionErrors.clear();
    });

    final sectionFailures = <String, Object?>{};
    Future<T?> safeLoad<T>(String section, Future<T> Function() loader) async {
      try {
        return await loader();
      } on Object catch (error) {
        sectionFailures[section] = error;
        return null;
      }
    }

    final results = await Future.wait<Object?>([
      safeLoad('Account', () => widget.controller.readAccountDiagnostics()),
      safeLoad('Rate limits', () => widget.controller.readAccountRateLimits()),
      safeLoad(
        'Permission profiles',
        () => widget.controller.listPermissionProfiles(),
      ),
      safeLoad('Config', () => widget.controller.readConfigDiagnostics()),
      safeLoad(
        'Config requirements',
        () => widget.controller.readConfigRequirements(),
      ),
      safeLoad(
        'Provider capabilities',
        () => widget.controller.readModelProviderCapabilities(),
      ),
      safeLoad('Hooks', () => widget.controller.listHooks()),
    ]);

    if (!mounted ||
        generation != _refreshGeneration ||
        !_canReadLocalDiagnostics) {
      return;
    }

    final nextAccount = results[0] as AccountDiagnosticsSnapshot?;
    final nextRateLimits = results[1] as RateLimitsDiagnosticsSnapshot?;
    final nextProfiles = results[2] as PermissionProfileListSnapshot?;
    final nextConfig = results[3] as ConfigDiagnosticsSnapshot?;
    final nextRequirements = results[4] as ConfigRequirementsSummaryModel?;
    final nextCapabilities = results[5] as ModelProviderCapabilitiesSnapshot?;
    final nextHooks = results[6] as HooksDiagnosticsSnapshot?;

    setState(() {
      if (accountGeneration == _accountRefreshGeneration) {
        if (nextAccount != null) {
          _account = nextAccount.copyWith(
            authMode: nextAccount.authMode ?? _account?.authMode,
          );
        }
        if (nextRateLimits != null) {
          _rateLimits = nextRateLimits;
        }
        _setSectionError('Account', sectionFailures['Account']);
        _setSectionError('Rate limits', sectionFailures['Rate limits']);
      }
      if (nextProfiles != null) {
        _permissionProfiles = nextProfiles;
      }
      if (nextConfig != null) {
        _config = nextConfig;
      }
      if (nextRequirements != null) {
        _configRequirements = nextRequirements;
      }
      if (nextCapabilities != null) {
        _providerCapabilities = nextCapabilities;
      }
      if (nextHooks != null) {
        _hooks = nextHooks;
      }
      _setSectionError(
        'Permission profiles',
        sectionFailures['Permission profiles'],
      );
      _setSectionError('Config', sectionFailures['Config']);
      _setSectionError(
        'Config requirements',
        sectionFailures['Config requirements'],
      );
      _setSectionError(
        'Provider capabilities',
        sectionFailures['Provider capabilities'],
      );
      _setSectionError('Hooks', sectionFailures['Hooks']);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
    final statusColor = switch (snapshot.state) {
      RuntimeConnectionState.connected ||
      RuntimeConnectionState.remoteReadOnly => palette.success,
      RuntimeConnectionState.error ||
      RuntimeConnectionState.processExited ||
      RuntimeConnectionState.notFound ||
      RuntimeConnectionState.hostNotFound ||
      RuntimeConnectionState.remoteCredentialRecoveryRequired ||
      RuntimeConnectionState.remoteRevoked => palette.danger,
      _ => palette.warning,
    };

    return AlertDialog(
      key: const ValueKey('runtime-details-dialog'),
      backgroundColor: theme.modalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OfficialCodexTheme.popoverRadius),
        side: BorderSide(
          color: theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: ThemeTokens.space2),
          const Expanded(child: Text('Runtime details')),
          if (_canReadLocalDiagnostics)
            CodexIconButton(
              key: const ValueKey('runtime-diagnostics-refresh-button'),
              tooltip: 'Refresh diagnostics',
              size: 28,
              onPressed: _loading ? null : _refreshDiagnostics,
              icon: const Icon(Icons.refresh_rounded, size: 16),
            ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          key: const ValueKey('runtime-diagnostics-scroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Detail(label: 'State', value: snapshot.stateLabel),
              if (snapshot.executablePath case final path?) ...[
                const SizedBox(height: ThemeTokens.space3),
                _Detail(label: 'Codex', value: path),
              ],
              if (snapshot.userAgent case final userAgent?) ...[
                const SizedBox(height: ThemeTokens.space3),
                _Detail(label: 'App server', value: userAgent),
              ],
              if (snapshot.processId case final processId?) ...[
                const SizedBox(height: ThemeTokens.space3),
                _Detail(label: 'Process', value: processId.toString()),
              ],
              if (snapshot.message case final message?) ...[
                const SizedBox(height: ThemeTokens.space4),
                _InlineNotice(
                  icon: Icons.info_outline_rounded,
                  color: statusColor,
                  text: message,
                ),
              ],
              if (_isRemoteOrUnsupported) ...[
                const SizedBox(height: ThemeTokens.space4),
                KeyedSubtree(
                  key: const ValueKey('runtime-diagnostics-remote-unavailable'),
                  child: _InlineNotice(
                    icon: Icons.lock_outline_rounded,
                    color: palette.warning,
                    text:
                        'Local runtime diagnostics (account, rate limits, '
                        'permission profiles, effective configuration, '
                        'provider capabilities, and workspace hooks) are '
                        'unavailable on the read-only Remote surface.',
                  ),
                ),
              ] else if (_canReadLocalDiagnostics) ...[
                if (_errorMessage case final error?) ...[
                  const SizedBox(height: ThemeTokens.space4),
                  KeyedSubtree(
                    key: const ValueKey('runtime-diagnostics-error'),
                    child: _InlineNotice(
                      icon: Icons.warning_amber_rounded,
                      color: palette.danger,
                      text: error,
                    ),
                  ),
                ],
                if (_loading && !_hasAnyDiagnostics) ...[
                  const SizedBox(height: ThemeTokens.space4),
                  Row(
                    key: const ValueKey('runtime-diagnostics-loading'),
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: ThemeTokens.space2),
                      Text(
                        'Loading runtime diagnostics…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                if (_account case final account?) ...[
                  const SizedBox(height: ThemeTokens.space4),
                  _DiagnosticsCard(
                    key: const ValueKey('runtime-diagnostics-account-card'),
                    title: 'Account',
                    children: _buildAccountDetails(account),
                  ),
                ],
                if (_rateLimits case final rateLimits?) ...[
                  const SizedBox(height: ThemeTokens.space3),
                  _DiagnosticsCard(
                    key: const ValueKey('runtime-diagnostics-rate-limits-card'),
                    title: 'Rate limits',
                    children: _buildRateLimitDetails(rateLimits),
                  ),
                ],
                if (_permissionProfiles case final profiles?) ...[
                  const SizedBox(height: ThemeTokens.space3),
                  _DiagnosticsCard(
                    key: const ValueKey(
                      'runtime-diagnostics-permission-profiles-card',
                    ),
                    title: 'Permission profiles (${profiles.profiles.length})',
                    children: _buildPermissionProfileDetails(profiles),
                  ),
                ],
                if (_config != null || _configRequirements != null) ...[
                  const SizedBox(height: ThemeTokens.space3),
                  _DiagnosticsCard(
                    key: const ValueKey('runtime-diagnostics-config-card'),
                    title: 'Configuration & layers',
                    children: _buildConfigDetails(_config, _configRequirements),
                  ),
                ],
                if (_providerCapabilities case final capabilities?) ...[
                  const SizedBox(height: ThemeTokens.space3),
                  _DiagnosticsCard(
                    key: const ValueKey(
                      'runtime-diagnostics-capabilities-card',
                    ),
                    title: 'Provider capabilities',
                    children: [
                      _Detail(
                        label: 'Web search',
                        value: capabilities.webSearch
                            ? 'Supported'
                            : 'Unavailable',
                      ),
                      const SizedBox(height: ThemeTokens.space2),
                      _Detail(
                        label: 'Image gen',
                        value: capabilities.imageGeneration
                            ? 'Supported'
                            : 'Unavailable',
                      ),
                    ],
                  ),
                ],
                if (_hooks case final hooks?) ...[
                  const SizedBox(height: ThemeTokens.space3),
                  _DiagnosticsCard(
                    key: const ValueKey('runtime-diagnostics-hooks-card'),
                    title: 'Workspace hooks (${hooks.totalHookCount})',
                    children: _buildHooksDetails(hooks),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        CodexButton(
          variant: CodexButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
          label: 'Close',
        ),
      ],
    );
  }

  List<Widget> _buildAccountDetails(AccountDiagnosticsSnapshot account) {
    final rows = <Widget>[
      _Detail(label: 'Type', value: account.accountType),
      const SizedBox(height: ThemeTokens.space2),
      _Detail(
        label: 'OpenAI auth',
        value: account.requiresOpenaiAuth ? 'Required' : 'Not required',
      ),
    ];
    if (account.planType case final planType?) {
      rows.addAll([
        const SizedBox(height: ThemeTokens.space2),
        _Detail(label: 'Plan', value: planType),
      ]);
    }
    if (account.authMode case final authMode?) {
      rows.addAll([
        const SizedBox(height: ThemeTokens.space2),
        _Detail(label: 'Auth mode', value: authMode),
      ]);
    }
    if (account.workspaceName case final workspaceName?) {
      rows.addAll([
        const SizedBox(height: ThemeTokens.space2),
        _Detail(label: 'Workspace', value: workspaceName),
      ]);
    }
    if (account.email case final email?) {
      rows.addAll([
        const SizedBox(height: ThemeTokens.space2),
        _Detail(label: 'Identity', value: email),
      ]);
    }
    if (account.usesCodexManagedCredentials case final managed?) {
      rows.addAll([
        const SizedBox(height: ThemeTokens.space2),
        _Detail(label: 'Managed', value: managed ? 'Yes' : 'No'),
      ]);
    }
    return rows;
  }

  List<Widget> _buildRateLimitDetails(RateLimitsDiagnosticsSnapshot snapshot) {
    final rows = <Widget>[];
    final primaryBucket = snapshot.primaryBucket;
    if (snapshot.ordinaryUsageAllowed case final allowed?) {
      rows.add(
        _Detail(label: 'Usage', value: allowed ? 'Allowed' : 'Restricted'),
      );
    }
    final bucketLabel = [
      if (primaryBucket.limitId != null) primaryBucket.limitId!,
      if (primaryBucket.limitName != null) primaryBucket.limitName!,
      if (primaryBucket.planType != null) 'plan: ${primaryBucket.planType}',
      if (primaryBucket.normalModelSlug != null)
        'model: ${primaryBucket.normalModelSlug}',
    ].join(' · ');
    if (bucketLabel.isNotEmpty) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: ThemeTokens.space2));
      }
      rows.add(_Detail(label: 'Bucket', value: bucketLabel));
    }
    if (primaryBucket.primary case final primaryWindow?) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: ThemeTokens.space2));
      }
      rows.add(
        _Detail(label: 'Primary', value: _formatWindowSummary(primaryWindow)),
      );
    }
    if (primaryBucket.secondary case final secondaryWindow?) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: ThemeTokens.space2));
      }
      rows.add(
        _Detail(
          label: 'Secondary',
          value: _formatWindowSummary(secondaryWindow),
        ),
      );
    }
    if (primaryBucket.credits case final credits?) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: ThemeTokens.space2));
      }
      final creditText = credits.unlimited
          ? 'Unlimited'
          : credits.hasCredits
          ? (credits.balance != null
                ? 'Available (${credits.balance})'
                : 'Available')
          : 'None';
      rows.add(_Detail(label: 'Credits', value: creditText));
    }
    if (primaryBucket.individualLimit case final spend?) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: ThemeTokens.space2));
      }
      rows.add(
        _Detail(
          label: 'Spend limit',
          value:
              '${spend.used} / ${spend.limit} (${spend.remainingPercent}% remaining)',
        ),
      );
    }
    if (primaryBucket.rateLimitReachedType case final reached?) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: ThemeTokens.space2));
      }
      rows.add(_Detail(label: 'Limit state', value: reached));
    }
    if (snapshot.availableResetCreditsCount case final resetCount?) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: ThemeTokens.space2));
      }
      rows.add(_Detail(label: 'Resets', value: '$resetCount available'));
    }
    if (snapshot.bucketsById.length > 1) {
      for (final bucket in snapshot.bucketsById) {
        final id = bucket.limitId ?? 'bucket';
        final windowText = bucket.primary != null
            ? _formatWindowSummary(bucket.primary!)
            : 'No active window';
        if (rows.isNotEmpty) {
          rows.add(const SizedBox(height: ThemeTokens.space2));
        }
        rows.add(_Detail(label: id, value: windowText));
      }
    }
    if (rows.isEmpty) {
      rows.add(const _Detail(label: 'Status', value: 'No active rate limits'));
    }
    return rows;
  }

  String _formatWindowSummary(RateLimitWindowSnapshot window) {
    final parts = <String>['${window.usedPercent}% used'];
    if (window.windowDurationMins case final mins? when mins > 0) {
      parts.add('${mins}m window');
    }
    if (window.resetsAtEpochSeconds case final resetsAt? when resetsAt > 0) {
      parts.add('resets @$resetsAt');
    }
    return parts.join(' · ');
  }

  List<Widget> _buildPermissionProfileDetails(
    PermissionProfileListSnapshot snapshot,
  ) {
    if (snapshot.profiles.isEmpty) {
      return const [
        _Detail(label: 'Profiles', value: 'No permission profiles reported'),
      ];
    }
    final rows = <Widget>[];
    for (var i = 0; i < snapshot.profiles.length; i++) {
      final profile = snapshot.profiles[i];
      if (i > 0) {
        rows.add(const SizedBox(height: ThemeTokens.space2));
      }
      final stateText = profile.allowed ? 'Allowed' : 'Restricted';
      final valueText = profile.description != null
          ? '$stateText — ${profile.description}'
          : stateText;
      rows.add(_Detail(label: profile.id, value: valueText));
    }
    if (snapshot.hasMore) {
      rows.addAll([
        const SizedBox(height: ThemeTokens.space2),
        Text(
          'Showing first ${snapshot.profiles.length} bounded profiles.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]);
    }
    return rows;
  }

  List<Widget> _buildConfigDetails(
    ConfigDiagnosticsSnapshot? config,
    ConfigRequirementsSummaryModel? requirements,
  ) {
    final rows = <Widget>[];
    void addRow(String label, String value) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: ThemeTokens.space2));
      }
      rows.add(_Detail(label: label, value: value));
    }

    if (config != null) {
      addRow(
        'Summary',
        '${config.configKeyCount} keys · ${config.originCount} origins · '
            '${config.layers.length} layers',
      );
      if (config.model case final model?) {
        addRow('Model', model);
      }
      if (config.reviewModel case final reviewModel?) {
        addRow('Review model', reviewModel);
      }
      if (config.modelProvider case final provider?) {
        addRow('Provider', provider);
      }
      if (config.modelReasoningEffort case final effort?) {
        addRow('Effort', effort);
      }
      if (config.modelReasoningSummary case final summary?) {
        addRow('Reasoning', summary);
      }
      if (config.modelVerbosity case final verbosity?) {
        addRow('Verbosity', verbosity);
      }
      if (config.approvalPolicy case final approvalPolicy?) {
        addRow('Approvals', approvalPolicy);
      }
      if (config.approvalsReviewer case final reviewer?) {
        addRow('Reviewer', reviewer);
      }
      if (config.sandboxMode case final sandboxMode?) {
        addRow('Sandbox', sandboxMode);
      }
      if (config.webSearchMode case final webSearch?) {
        addRow('Web search', webSearch);
      }
      if (config.defaultPermissions case final defaultPermissions?) {
        addRow('Permissions', defaultPermissions);
      }
      if (config.serviceTier case final serviceTier?) {
        addRow('Service tier', serviceTier);
      }
      if (config.profile case final profile?) {
        addRow('Profile', profile);
      }
      if (config.modelContextWindow case final contextWindow?) {
        addRow('Context win', '$contextWindow');
      }
      if (config.modelAutoCompactTokenLimit case final autoCompact?) {
        addRow('Auto-compact', '$autoCompact');
      }
      for (final layer in config.layers) {
        final layerHeader = [
          layer.sourceType,
          if (layer.profile != null) '(${layer.profile})',
          '${layer.configEntryCount} keys',
          if (layer.sourceLocation != null) layer.sourceLocation!,
          if (layer.disabledReason != null)
            'disabled: ${layer.disabledReason!}',
        ].join(' · ');
        addRow('Layer', layerHeader);
      }
    }

    if (requirements != null) {
      addRow(
        'Requirements',
        requirements.hasRequirements ? 'Managed policy active' : 'None',
      );
      if (requirements.supportsIndependentSpeedModes case final independent?) {
        addRow('Speed modes', independent ? 'Independent' : 'Shared');
      }
      if (requirements.hasRequirements) {
        if (requirements.allowedApprovalPolicies.isNotEmpty) {
          addRow(
            'Allowed appr',
            requirements.allowedApprovalPolicies.join(', '),
          );
        }
        if (requirements.allowedSandboxModes.isNotEmpty) {
          addRow('Allowed sb', requirements.allowedSandboxModes.join(', '));
        }
        if (requirements.allowedWebSearchModes.isNotEmpty) {
          addRow('Allowed web', requirements.allowedWebSearchModes.join(', '));
        }
        if (requirements.allowedLoginMethods.isNotEmpty) {
          addRow('Allowed auth', requirements.allowedLoginMethods.join(', '));
        }
        if (requirements.enforceResidency case final residency?) {
          addRow('Residency', residency);
        }
        if (requirements.allowRemoteControl case final allowRemote?) {
          addRow('Remote policy', allowRemote ? 'Allowed' : 'Disallowed');
        }
        if (requirements.allowManagedHooksOnly case final managedHooksOnly?) {
          addRow(
            'Hooks policy',
            managedHooksOnly ? 'Managed hooks only' : 'Standard',
          );
        }
      }
    }

    return rows;
  }

  List<Widget> _buildHooksDetails(HooksDiagnosticsSnapshot hooks) {
    final rows = <Widget>[
      _Detail(
        label: 'Shown counts',
        value:
            '${hooks.entries.length} shown workspaces · '
            '${hooks.totalHookCount} shown hooks · '
            '${hooks.totalErrorCount} shown errors · '
            '${hooks.totalWarningCount} shown warnings',
      ),
    ];
    for (final entry in hooks.entries) {
      rows.addAll([
        const SizedBox(height: ThemeTokens.space2),
        _Detail(
          label: 'Workspace',
          value: '${entry.cwd} (${entry.hooks.length} shown hooks)',
        ),
      ]);
      for (final hook in entry.hooks) {
        final parts = <String>[
          hook.eventName,
          hook.handlerType,
          hook.trustStatus,
          hook.enabled ? 'enabled' : 'disabled',
          if (hook.isManaged) 'managed',
          if (hook.isAsync) 'async',
          '${hook.timeoutSec}s',
          if (hook.targetSummary != null) hook.targetSummary!,
          if (hook.matcher != null) 'matcher: ${hook.matcher}',
          if (hook.statusMessage != null) hook.statusMessage!,
        ];
        rows.addAll([
          const SizedBox(height: ThemeTokens.space2),
          _Detail(label: hook.key, value: parts.join(' · ')),
        ]);
      }
      for (final error in entry.errors) {
        rows.addAll([
          const SizedBox(height: ThemeTokens.space2),
          _Detail(
            label: 'Hook error',
            value: '${error.path}: ${error.message}',
          ),
        ]);
      }
      for (final warning in entry.warnings) {
        rows.addAll([
          const SizedBox(height: ThemeTokens.space2),
          _Detail(label: 'Hook warn', value: warning),
        ]);
      }
    }
    return rows;
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final theme = OfficialCodexTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(ThemeTokens.space3),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border.all(
          color: theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: ThemeTokens.space2),
          ...children,
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ThemeTokens.space3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: ThemeTokens.space2),
          Expanded(
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
