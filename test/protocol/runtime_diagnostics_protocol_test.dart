import 'dart:async';

import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/runtime_diagnostics_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuntimeDiagnosticsProtocolAdapter', () {
    test(
      'parses account/read across chatgpt, apiKey, bedrock, and null accounts',
      () async {
        var mode = 'chatgpt';
        final capturedParams = <JsonObject>[];
        final adapter = RuntimeDiagnosticsProtocolAdapter(
          request: (method, [params = const {}]) async {
            expect(method, 'account/read');
            capturedParams.add(params);
            return switch (mode) {
              'chatgpt' => {
                'requiresOpenaiAuth': true,
                'account': {
                  'type': 'chatgpt',
                  'planType': 'prolite',
                  'email': '  user@example.test  ',
                  'workspaceName': '  Synthetic Team  ',
                },
              },
              'apiKey' => {
                'requiresOpenaiAuth': true,
                'account': {'type': 'apiKey'},
              },
              'bedrock' => {
                'requiresOpenaiAuth': false,
                'account': {
                  'type': 'amazonBedrock',
                  'usesCodexManagedCredentials': true,
                },
              },
              'unauthenticated' => {
                'requiresOpenaiAuth': true,
                'account': null,
              },
              _ => throw StateError('Unexpected mode $mode'),
            };
          },
        );

        final chatgpt = await adapter.readAccount();
        expect(capturedParams.last, {'refreshToken': false});
        expect(chatgpt.isAuthenticated, isTrue);
        expect(chatgpt.requiresOpenaiAuth, isTrue);
        expect(chatgpt.accountType, 'chatgpt');
        expect(chatgpt.planType, 'prolite');
        expect(chatgpt.email, 'user@example.test');
        expect(chatgpt.workspaceName, 'Synthetic Team');

        mode = 'apiKey';
        final apiKey = await adapter.readAccount(refreshToken: true);
        expect(capturedParams.last, {'refreshToken': true});
        expect(apiKey.isAuthenticated, isTrue);
        expect(apiKey.accountType, 'apiKey');
        expect(apiKey.planType, isNull);

        mode = 'bedrock';
        final bedrock = await adapter.readAccount();
        expect(bedrock.accountType, 'amazonBedrock');
        expect(bedrock.requiresOpenaiAuth, isFalse);
        expect(bedrock.usesCodexManagedCredentials, isTrue);

        mode = 'unauthenticated';
        final unauth = await adapter.readAccount();
        expect(unauth.isAuthenticated, isFalse);
        expect(unauth.accountType, 'unauthenticated');
        expect(unauth.requiresOpenaiAuth, isTrue);
      },
    );

    test('parses account/rateLimits/read, clamps percentages, caps buckets, and merges sparse updates', () async {
      final byLimitId = <String, Object?>{
        for (var i = 0; i < maxRateLimitBuckets + 4; i++)
          'bucket-$i': {
            'limitId': 'bucket-$i',
            'limitName': 'Bucket $i',
            'primary': {
              'usedPercent': i == 0 ? 135 : 20 + i,
              'windowDurationMins': 60,
              'resetsAt': 1790000000 + i,
            },
          },
      };

      final adapter = RuntimeDiagnosticsProtocolAdapter(
        request: (method, [params = const {}]) async {
          expect(method, 'account/rateLimits/read');
          expect(params, {'excludeResetCreditDetails': true});
          return {
            'accountId': 'synthetic-discarded-account-id',
            'ordinaryUsageAllowed': true,
            'rateLimitResetCredits': {
              'availableCount': 3,
              'credits': [
                {
                  'id': 'credit-1',
                  'grantedAt': 1780000000,
                  'resetType': 'codexRateLimits',
                  'status': 'available',
                },
              ],
            },
            'rateLimits': {
              'limitId': 'codex',
              'limitName': 'Codex Primary',
              'normalModelSlug': 'o3-mini',
              'planType': 'plus',
              'primary': {
                'usedPercent': 78,
                'windowDurationMins': 300,
                'resetsAt': 1790000500,
              },
              'secondary': {
                'usedPercent': -10,
                'windowDurationMins': 10080,
                'resetsAt': 1790600000,
              },
              'credits': {
                'hasCredits': true,
                'unlimited': false,
                'balance': '14.50',
              },
              'individualLimit': {
                'limit': '100.00',
                'used': '25.00',
                'remainingPercent': 75,
                'resetsAt': 1791000000,
              },
              'rateLimitReachedType': 'rate_limit_reached',
              'spendControlReached': false,
            },
            'rateLimitsByLimitId': byLimitId,
          };
        },
      );

      final snapshot = await adapter.readAccountRateLimits(
        excludeResetCreditDetails: true,
      );
      expect(snapshot.ordinaryUsageAllowed, isTrue);
      expect(snapshot.availableResetCreditsCount, 3);
      expect(snapshot.primaryBucket.limitId, 'codex');
      expect(snapshot.primaryBucket.limitName, 'Codex Primary');
      expect(snapshot.primaryBucket.normalModelSlug, 'o3-mini');
      expect(snapshot.primaryBucket.planType, 'plus');
      expect(snapshot.primaryBucket.primary?.usedPercent, 78);
      expect(snapshot.primaryBucket.primary?.windowDurationMins, 300);
      expect(snapshot.primaryBucket.secondary?.usedPercent, 0);
      expect(snapshot.primaryBucket.credits?.balance, '14.50');
      expect(snapshot.primaryBucket.individualLimit?.remainingPercent, 75);
      expect(snapshot.primaryBucket.rateLimitReachedType, 'rate_limit_reached');
      expect(snapshot.bucketsById, hasLength(maxRateLimitBuckets));
      expect(snapshot.bucketsById.first.primary?.usedPercent, 100);

      // Sparse rolling update preserves nullable metadata when omitted.
      final merged = snapshot.applyRateLimitsUpdated(
        const RateLimitBucketSnapshot(
          limitId: 'bucket-0',
          primary: RateLimitWindowSnapshot(
            usedPercent: 91,
            windowDurationMins: 300,
          ),
        ),
      );
      expect(merged.primaryBucket.planType, 'plus');
      expect(merged.primaryBucket.limitName, 'Codex Primary');
      expect(merged.primaryBucket.primary?.usedPercent, 91);
      expect(merged.bucketsById.first.primary?.usedPercent, 91);
      expect(merged.bucketsById.first.limitName, 'Bucket 0');
    });

    test('deduplicates and bounds permissionProfile/list responses', () async {
      final adapter = RuntimeDiagnosticsProtocolAdapter(
        request: (method, [params = const {}]) async {
          expect(method, 'permissionProfile/list');
          expect(params['cwd'], '/workspace/project');
          return {
            'data': [
              {
                'id': ':read-only',
                'allowed': true,
                'description': 'Read-only inspection',
              },
              {
                'id': ':read-only',
                'allowed': false,
                'description': 'Duplicate entry ignored',
              },
              for (var i = 0; i < maxPermissionProfiles + 5; i++)
                {
                  'id': ':profile-$i',
                  'allowed': i.isEven,
                  'description': 'Profile $i',
                },
            ],
            'nextCursor': 'cursor-2',
          };
        },
      );

      final result = await adapter.listPermissionProfiles(
        cwd: '  /workspace/project  ',
      );
      expect(result.profiles, hasLength(maxPermissionProfiles));
      expect(result.profiles.first.id, ':read-only');
      expect(result.profiles.first.allowed, isTrue);
      expect(result.hasMore, isTrue);
      expect(result.nextCursor, isNull);
    });

    test('discards raw config and origins at parser ingress while retaining bounded config and requirements summary', () async {
      final largePrompt = 'P' * 65536;
      final adapter = RuntimeDiagnosticsProtocolAdapter(
        request: (method, [params = const {}]) async {
          return switch (method) {
            'config/read' => {
              'config': {
                'model': 'o3-mini',
                'review_model': 'o3-mini',
                'model_provider': 'openai',
                'model_reasoning_effort': 'high',
                'model_reasoning_summary': 'concise',
                'model_verbosity': 'low',
                'approval_policy': {
                  'granular': {
                    'mcp_elicitations': true,
                    'rules': true,
                    'sandbox_approval': true,
                  },
                },
                'approvals_reviewer': 'auto_review',
                'sandbox_mode': 'workspace-write',
                'service_tier': 'flex',
                'web_search': 'live',
                'default_permissions': ':workspace',
                'profile': 'ci',
                'model_context_window': 200000,
                'model_auto_compact_token_limit': 150000,
                'developer_instructions': largePrompt,
                'instructions': largePrompt,
                'compact_prompt': largePrompt,
              },
              'origins': {
                for (var i = 0; i < 60; i++)
                  'key_$i': {
                    'name': {
                      'type': 'user',
                      'file': '/home/test/.codex/config.toml',
                    },
                    'version': 'v1',
                  },
              },
              'layers': [
                for (var i = 0; i < maxConfigLayers + 4; i++)
                  {
                    'name': {
                      'type': i == 0 ? 'user' : 'project',
                      if (i == 0) 'file': '/workspace/.codex/config.toml',
                      if (i == 0) 'profile': 'ci',
                      if (i > 0) 'dotCodexFolder': '/workspace/sub-$i/.codex',
                    },
                    'version': 'v$i',
                    'disabledReason': i == 1 ? 'untrusted project' : null,
                    'config': {'model': 'o3-mini', 'instructions': largePrompt},
                  },
              ],
            },
            'configRequirements/read' => {
              'supportsIndependentSpeedModes': true,
              'requirements': {
                'allowedApprovalPolicies': [
                  'untrusted',
                  {
                    'granular': {
                      'mcp_elicitations': true,
                      'rules': true,
                      'sandbox_approval': true,
                    },
                  },
                ],
                'allowedSandboxModes': ['read-only', 'workspace-write'],
                'allowedWebSearchModes': ['disabled', 'cached'],
                'allowedLoginMethods': ['chatgpt'],
                'defaultPermissions': ':read-only',
                'modelProvider': 'openai',
                'enforceResidency': 'us',
                'allowRemoteControl': false,
                'allowManagedHooksOnly': true,
                'allowLoginShell': false,
                'allowBrowserAndComputerUse': false,
                'additionalDeveloperInstructions': largePrompt,
              },
            },
            _ => throw StateError('Unexpected method $method'),
          };
        },
      );

      final config = await adapter.readConfig(cwd: '/workspace');
      expect(config.configKeyCount, 18);
      expect(config.originCount, 60);
      expect(config.model, 'o3-mini');
      expect(config.approvalPolicy, 'granular');
      expect(config.approvalsReviewer, 'auto_review');
      expect(config.sandboxMode, 'workspace-write');
      expect(config.webSearchMode, 'live');
      expect(config.defaultPermissions, ':workspace');
      expect(config.profile, 'ci');
      expect(config.modelContextWindow, 200000);
      expect(config.modelAutoCompactTokenLimit, 150000);
      expect(config.layers, hasLength(maxConfigLayers));
      expect(config.layers.first.sourceType, 'user');
      expect(config.layers.first.profile, 'ci');
      expect(config.layers.first.configEntryCount, 2);
      expect(config.layers[1].disabledReason, 'untrusted project');

      final requirements = await adapter.readConfigRequirements();
      expect(requirements.hasRequirements, isTrue);
      expect(requirements.supportsIndependentSpeedModes, isTrue);
      expect(requirements.allowedApprovalPolicies, ['untrusted', 'granular']);
      expect(requirements.allowedSandboxModes, [
        'read-only',
        'workspace-write',
      ]);
      expect(requirements.allowedWebSearchModes, ['disabled', 'cached']);
      expect(requirements.allowedLoginMethods, ['chatgpt']);
      expect(requirements.defaultPermissions, ':read-only');
      expect(requirements.enforceResidency, 'us');
      expect(requirements.allowRemoteControl, isFalse);
      expect(requirements.allowManagedHooksOnly, isTrue);
      expect(requirements.allowLoginShell, isFalse);
      expect(requirements.allowBrowserAndComputerUse, isFalse);
    });

    test('parses modelProvider/capabilities/read and hooks/list in cwds and threadId modes', () async {
      final calls = <({String method, JsonObject params})>[];
      final adapter = RuntimeDiagnosticsProtocolAdapter(
        request: (method, [params = const {}]) async {
          calls.add((method: method, params: params));
          return switch (method) {
            'modelProvider/capabilities/read' => {
              'imageGeneration': true,
              'webSearch': false,
            },
            'hooks/list' => {
              'data': [
                {
                  'cwd': '/workspace/repo',
                  'hooks': [
                    {
                      'key': 'cmd-hook',
                      'eventName': 'preToolUse',
                      'handlerType': 'command',
                      'command': 'curl -H "Authorization: Bearer sk-secret-hook-token-123" https://internal.example.test',
                      'async': true,
                      'enabled': true,
                      'isManaged': false,
                      'source': 'project',
                      'sourcePath': '/workspace/repo/.codex/hooks.toml',
                      'trustStatus': 'trusted',
                      'timeoutSec': 30,
                      'displayOrder': 0,
                      'currentHash': 'hash-1',
                      'matcher': 'Bash',
                      'statusMessage': 'Checking tests',
                    },
                    {
                      'key': 'mcp-hook',
                      'eventName': 'postToolUse',
                      'handlerType': 'mcpTool',
                      'server': 'audit-mcp',
                      'tool': 'record_call',
                      'enabled': false,
                      'isManaged': true,
                      'source': 'system',
                      'sourcePath': '/etc/codex/hooks.toml',
                      'trustStatus': 'managed',
                      'timeoutSec': 10,
                      'displayOrder': 1,
                      'currentHash': 'hash-2',
                    },
                  ],
                  'errors': [
                    {
                      'path': '/workspace/repo/.codex/hooks.toml',
                      'message': 'Invalid matcher syntax on line 12',
                    },
                  ],
                  'warnings': ['Async hook may outlive turn'],
                },
              ],
            },
            _ => throw StateError('Unexpected method $method'),
          };
        },
      );

      final capabilities = await adapter.readModelProviderCapabilities();
      expect(capabilities.imageGeneration, isTrue);
      expect(capabilities.webSearch, isFalse);

      final hooksByCwd = await adapter.listHooks(
        cwds: ['/workspace/repo', '  /workspace/repo  '],
      );
      expect(calls.last.params, {
        'cwds': ['/workspace/repo'],
      });
      expect(hooksByCwd.totalHookCount, 2);
      expect(hooksByCwd.totalErrorCount, 1);
      expect(hooksByCwd.totalWarningCount, 1);
      expect(
        hooksByCwd.entries.single.hooks.first.targetSummary,
        'Command handler',
      );
      expect(
        hooksByCwd.entries.single.hooks.first.targetSummary,
        isNot(contains('sk-secret-hook-token-123')),
      );
      expect(hooksByCwd.entries.single.hooks.first.isAsync, isTrue);
      expect(
        hooksByCwd.entries.single.hooks[1].targetSummary,
        'audit-mcp/record_call',
      );

      await adapter.listHooks(
        cwds: ['/workspace/ignored'],
        threadId: 'thread-loaded-1',
      );
      expect(calls.last.params, {'threadId': 'thread-loaded-1'});
    });

    test(
      'projects only bounded provider names, kinds, and exact default',
      () async {
        final longNamePrefix = 'x' * (maxDiagnosticsLabelLength - 1);
        final adapter = RuntimeDiagnosticsProtocolAdapter(
          request: (method, [params = const {}]) async {
            expect(method, 'modelProvider/list');
            expect(params, isEmpty);
            return {
              'defaultProviderId': 'gateway',
              'canChangeDefault': true,
              'data': [
                {
                  'id': 'gateway',
                  'name': ' Synthetic\u202E\nGateway ',
                  'canEdit': true,
                  'baseUrl': 'https://private-provider.invalid/',
                  'settings': {
                    'type': 'customGateway',
                    'auth': {
                      'mode': 'future-auth',
                      'envKey': 'PRIVATE_FIXTURE_ENV_IDENTIFIER',
                    },
                  },
                },
                {
                  'id': 'gateway ',
                  'name': '\u2066\u0000',
                  'settings': {
                    'type': 'gcp',
                    'projectId': 'private-fixture-project',
                    'credentialFile': '/tmp/provider-private-fixture',
                  },
                },
                {
                  'id': 'next',
                  'name': '$longNamePrefix🧪',
                  'settings': {'type': 'future-provider'},
                },
                for (var i = 3; i < maxModelProviders; i++)
                  {
                    'id': 'provider-$i',
                    'name': 'Provider $i',
                    'settings': {'type': 'openai'},
                  },
                // Rows beyond the cap must not be parsed.
                null,
              ],
            };
          },
        );

        final inventory = await adapter.listModelProviders();
        expect(inventory.isSupported, isTrue);
        expect(inventory.reportedCount, maxModelProviders + 1);
        expect(inventory.providers, hasLength(maxModelProviders));
        expect(inventory.providers.take(3).map((provider) => provider.name), [
          'Synthetic Gateway',
          'Unnamed provider',
          longNamePrefix,
        ]);
        expect(inventory.providers.take(3).map((provider) => provider.kind), [
          ModelProviderKind.customGateway,
          ModelProviderKind.gcp,
          ModelProviderKind.other,
        ]);
        expect(inventory.providers.where((provider) => provider.isDefault), [
          inventory.providers.first,
        ]);
      },
    );

    test(
      'only exact method absence makes provider inventory unsupported',
      () async {
        var error = const JsonRpcException(
          code: -32601,
          message: 'Method not found',
        );
        final adapter = RuntimeDiagnosticsProtocolAdapter(
          request: (_, [params = const {}]) async => throw error,
        );

        expect((await adapter.listModelProviders()).isSupported, isFalse);

        error = const JsonRpcException(
          code: -32600,
          message: 'Invalid request: unknown variant `modelProvider/list`, expected one of ...',
        );
        expect((await adapter.listModelProviders()).isSupported, isFalse);

        for (final message in [
          'Invalid request: unsupported configuration',
          'Invalid request: unknown variant `modelProvider/listOther`',
        ]) {
          error = JsonRpcException(code: -32600, message: message);
          await expectLater(adapter.listModelProviders(), throwsA(same(error)));
        }
      },
    );

    test(
      'malformed provider inventory response remains a protocol failure',
      () async {
        final adapter = RuntimeDiagnosticsProtocolAdapter(
          request: (_, [params = const {}]) async => {
            'data': [
              {
                'id': 'test',
                'name': 'Test',
                'settings': {'type': null},
              },
            ],
            'defaultProviderId': 'test',
          },
        );
        await expectLater(
          adapter.listModelProviders(),
          throwsA(isA<ProtocolViolation>()),
        );
      },
    );

    test('emits typed events for account/updated and account/rateLimits/updated notifications', () async {
      final notifications = StreamController<CodexNotification>.broadcast();
      addTearDown(notifications.close);

      final adapter = RuntimeDiagnosticsProtocolAdapter(
        request: (_, [_ = const {}]) async => const {},
        notifications: notifications.stream,
      );

      final events = <RuntimeDiagnosticsEvent>[];
      final sub = adapter.events.listen(events.add);
      addTearDown(sub.cancel);

      notifications.add(
        const CodexNotification(
          method: 'account/updated',
          params: {'authMode': 'chatgpt', 'planType': 'pro'},
        ),
      );
      notifications.add(
        const CodexNotification(
          method: 'account/rateLimits/updated',
          params: {
            'rateLimits': {
              'limitId': 'codex',
              'planType': 'pro',
              'primary': {'usedPercent': 64, 'windowDurationMins': 300},
            },
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      final accountEvent = events[0] as AccountUpdatedDiagnosticsEvent;
      expect(accountEvent.authMode, 'chatgpt');
      expect(accountEvent.planType, 'pro');

      final rateLimitEvent =
          events[1] as AccountRateLimitsUpdatedDiagnosticsEvent;
      expect(rateLimitEvent.rateLimits.limitId, 'codex');
      expect(rateLimitEvent.rateLimits.planType, 'pro');
      expect(rateLimitEvent.rateLimits.primary?.usedPercent, 64);
    });

    test('Remote RuntimeController fails closed for all runtime diagnostics methods', () async {
      final controller = RuntimeController(useRemote: true);
      addTearDown(controller.dispose);

      expect(controller.supportsRuntimeDiagnostics, isFalse);
      expect(() => controller.readAccountDiagnostics(), throwsUnsupportedError);
      expect(() => controller.readAccountRateLimits(), throwsUnsupportedError);
      expect(() => controller.listPermissionProfiles(), throwsUnsupportedError);
      expect(() => controller.readConfigDiagnostics(), throwsUnsupportedError);
      expect(() => controller.readConfigRequirements(), throwsUnsupportedError);
      expect(
        () => controller.readModelProviderCapabilities(),
        throwsUnsupportedError,
      );
      expect(() => controller.listModelProviders(), throwsUnsupportedError);
      expect(() => controller.listHooks(), throwsUnsupportedError);
    });
  });
}
