import 'dart:io';

import 'package:codex_native_unofficial/src/domain/ecosystem_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/ecosystem_protocol.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parses skills/list and toggles skill via skills/config/write',
    () async {
      final requests = <(String, JsonObject)>[];
      final adapter = EcosystemProtocolAdapter(
        request: (method, [params = const {}]) async {
          requests.add((method, params));
          return switch (method) {
            'skills/list' => {
              'data': [
                {
                  'cwd': '/workspace',
                  'skills': [
                    {
                      'name': 'frontend-design',
                      'shortDescription': 'Desktop UI skill',
                      'path':
                          '/workspace/.agents/skills/frontend-design/SKILL.md',
                      'enabled': true,
                      'scope': 'repo',
                    },
                  ],
                },
              ],
            },
            'skills/config/write' => {'effectiveEnabled': false},
            _ => const {},
          };
        },
      );

      final skills = await adapter.listSkills(cwds: const ['/workspace']);
      expect(skills, hasLength(1));
      expect(skills.single.name, 'frontend-design');
      expect(skills.single.description, 'Desktop UI skill');
      expect(skills.single.enabled, isTrue);

      final effective = await adapter.setSkillEnabled(
        path: skills.single.path,
        enabled: false,
      );
      expect(effective, isFalse);
      expect(requests.last.$1, 'skills/config/write');
      expect(requests.last.$2, {
        'path': '/workspace/.agents/skills/frontend-design/SKILL.md',
        'enabled': false,
      });
    },
  );

  test(
    'parses plugin/list and mcpServerStatus/list with bounded items',
    () async {
      final adapter = EcosystemProtocolAdapter(
        request: (method, [params = const {}]) async {
          return switch (method) {
            'plugin/list' => {
              'marketplaces': [
                {
                  'name': 'openai-primary-runtime',
                  'path': '/workspace/.agents/plugins/marketplace.json',
                  'plugins': [
                    {
                      'id': 'git-workflow@openai-primary-runtime',
                      'name': 'git-workflow',
                      'installed': true,
                      'enabled': true,
                      'localVersion': '1.2.0',
                      'installPolicy': 'AVAILABLE',
                      'authPolicy': 'ON_USE',
                      'source': {
                        'type': 'local',
                        'path': '/workspace/.agents/plugins/git-workflow',
                      },
                      'interface': {
                        'displayName': 'Git Workflow',
                        'shortDescription': 'Branch and PR helpers',
                        'category': 'Productivity',
                        'capabilities': ['skills', 'mcp'],
                      },
                    },
                  ],
                },
              ],
            },
            'mcpServerStatus/list' => {
              'data': [
                {
                  'name': 'filesystem-mcp',
                  'tools': {'read_file': {}, 'write_file': {}},
                  'resources': [
                    {'uri': 'file:///workspace'},
                  ],
                  'authStatus': 'ready',
                },
              ],
            },
            _ => const {},
          };
        },
      );

      final plugins = await adapter.listPlugins(cwds: const ['/workspace']);
      expect(plugins, hasLength(1));
      expect(plugins.single.id, 'git-workflow@openai-primary-runtime');
      expect(plugins.single.name, 'Git Workflow');
      expect(plugins.single.effectivePluginName, 'git-workflow');
      expect(plugins.single.installed, isTrue);
      expect(plugins.single.version, '1.2.0');
      expect(plugins.single.marketplaceName, 'openai-primary-runtime');
      expect(
        plugins.single.marketplacePath,
        '/workspace/.agents/plugins/marketplace.json',
      );
      expect(plugins.single.sourceType, 'local');
      expect(plugins.single.category, 'Productivity');
      expect(plugins.single.capabilities, ['skills', 'mcp']);

      final mcp = await adapter.listMcpServerStatus();
      expect(mcp, hasLength(1));
      expect(mcp.single.name, 'filesystem-mcp');
      expect(mcp.single.toolCount, 2);
      expect(mcp.single.resourceCount, 1);
      expect(mcp.single.status, 'ready');
    },
  );

  test(
    'reloads MCP config and parses bounded resource and tool results',
    () async {
      final requests = <(String, JsonObject)>[];
      final adapter = EcosystemProtocolAdapter(
        request: (method, [params = const {}]) async {
          requests.add((method, params));
          return switch (method) {
            'config/mcpServer/reload' => const {},
            'mcpServer/resource/read' => {
              'originCallId': 'call-1',
              'contents': [
                {
                  'uri': 'file:///workspace/readme.md',
                  'mimeType': 'text/markdown',
                  'text': '# Workspace',
                },
                {
                  'uri': 'file:///workspace/icon.png',
                  'mimeType': 'image/png',
                  'blob': 'YWJjZA==',
                },
              ],
            },
            'mcpServer/tool/call' => {
              'content': [
                {'type': 'text', 'text': 'Tool complete'},
                {'type': 'image', 'mimeType': 'image/png', 'data': 'YWJjZA=='},
              ],
              'structuredContent': {
                'changed': true,
                'paths': ['README.md'],
              },
              'isError': false,
            },
            _ => const {},
          };
        },
      );

      await adapter.reloadMcpServers();
      expect(requests.single.$1, 'config/mcpServer/reload');
      expect(requests.single.$2, isEmpty);

      final resource = await adapter.readMcpResource(
        const McpResourceReadQuery(
          server: 'filesystem',
          uri: 'file:///workspace/readme.md',
          threadId: 'thread-1',
          connectorId: 'connector-files',
          originCallId: 'call-1',
          target: McpResourceReadTarget(
            connectorId: 'connector-files',
            linkId: 'link-1',
          ),
        ),
      );
      expect(resource.originCallId, 'call-1');
      expect(resource.contents, hasLength(2));
      expect(
        (resource.contents.first as McpTextResourceContentModel).text,
        '# Workspace',
      );
      expect(
        (resource.contents.last as McpBlobResourceContentModel).encodedLength,
        8,
      );
      expect(requests[1].$1, 'mcpServer/resource/read');
      expect(requests[1].$2, {
        'server': 'filesystem',
        'uri': 'file:///workspace/readme.md',
        'threadId': 'thread-1',
        'connectorId': 'connector-files',
        'originCallId': 'call-1',
        'target': {'connectorId': 'connector-files', 'linkId': 'link-1'},
      });

      final tool = await adapter.callMcpTool(
        McpToolCallQuery(
          server: 'filesystem',
          threadId: 'thread-1',
          tool: 'write_file',
          arguments: const {'path': 'README.md', 'text': 'Updated'},
        ),
      );
      expect(tool.isError, isFalse);
      expect(tool.content, hasLength(2));
      expect(tool.content.first.text, 'Tool complete');
      expect(tool.content.last.encodedDataLength, 8);
      expect(tool.structuredContentPreview, contains('README.md'));
      expect(requests.last.$2, {
        'server': 'filesystem',
        'threadId': 'thread-1',
        'tool': 'write_file',
        'arguments': {'path': 'README.md', 'text': 'Updated'},
      });
    },
  );

  test('rejects oversized or structurally unbounded MCP payloads', () async {
    var mode = 'resource';
    final adapter = EcosystemProtocolAdapter(
      request: (method, [params = const {}]) async {
        if (mode == 'resource') {
          return {
            'contents': [
              {
                'uri': 'file:///oversized',
                'text': List<String>.filled(
                  EcosystemProtocolAdapter.maxMcpRetainedTextBytes + 1,
                  'x',
                ).join(),
              },
            ],
          };
        }
        return const {'content': []};
      },
    );

    await expectLater(
      adapter.readMcpResource(
        const McpResourceReadQuery(server: 'filesystem', uri: 'file:///x'),
      ),
      throwsFormatException,
    );

    mode = 'tool';
    Object nested = 'leaf';
    for (var i = 0; i <= EcosystemProtocolAdapter.maxMcpJsonDepth; i++) {
      nested = <String, Object?>{'value': nested};
    }
    await expectLater(
      adapter.callMcpTool(
        McpToolCallQuery(
          server: 'filesystem',
          threadId: 'thread-1',
          tool: 'deep',
          arguments: {'input': nested},
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'accepts bounded binary MCP payloads above retained text limit',
    () async {
      final encodedBinary = List<String>.filled(
        EcosystemProtocolAdapter.maxMcpRetainedTextBytes + 1,
        'A',
      ).join();
      final adapter = EcosystemProtocolAdapter(
        request: (method, [params = const {}]) async {
          return switch (method) {
            'mcpServer/resource/read' => {
              'contents': [
                {
                  'uri': 'file:///workspace/image.bin',
                  'mimeType': 'application/octet-stream',
                  'blob': encodedBinary,
                },
              ],
            },
            'mcpServer/tool/call' => {
              'content': [
                {
                  'type': 'image',
                  'mimeType': 'application/octet-stream',
                  'data': encodedBinary,
                },
              ],
            },
            _ => const {},
          };
        },
      );

      final resource = await adapter.readMcpResource(
        const McpResourceReadQuery(
          server: 'filesystem',
          uri: 'file:///workspace/image.bin',
        ),
      );
      expect(
        (resource.contents.single as McpBlobResourceContentModel).encodedLength,
        encodedBinary.length,
      );

      final tool = await adapter.callMcpTool(
        McpToolCallQuery(
          server: 'filesystem',
          threadId: 'thread-1',
          tool: 'read_image',
          arguments: const {},
        ),
      );
      expect(tool.content.single.encodedDataLength, encodedBinary.length);
    },
  );

  test('parses app/list pagination, app/installed snapshots, and app/read metadata with bounds', () async {
    final calls = <(String, JsonObject)>[];
    final adapter = EcosystemProtocolAdapter(
      request: (method, [params = const {}]) async {
        calls.add((method, params));
        return switch (method) {
          'app/list' => {
            'data': [
              {
                'id': 'connector_github',
                'name': 'GitHub',
                'description': 'Access repositories and pull requests.',
                'isAccessible': true,
                'isEnabled': true,
                'distributionChannel': 'DEFAULT_OAI_CATALOG',
                'installUrl': 'https://chatgpt.com/apps/github',
                'pluginDisplayNames': ['GitHub'],
                'branding': {
                  'category': 'Developer Tools',
                  'developer': 'OpenAI',
                  'isDiscoverableApp': true,
                },
                'appMetadata': {'version': '2.1.0'},
              },
              {'id': 'connector_github', 'name': 'Duplicate GitHub'},
            ],
            'nextCursor': 'cursor-page-2',
          },
          'app/installed' => {
            'apps': [
              {
                'id': 'connector_github',
                'runtimeName': 'GitHub',
                'enabled': true,
                'callable': true,
              },
              {
                'id': 'connector_github',
                'runtimeName': 'Duplicate GitHub',
                'enabled': false,
                'callable': false,
              },
            ],
          },
          'app/read' => {
            'apps': [
              {
                'id': 'connector_github',
                'name': 'GitHub',
                'description': 'Access repositories, issues, and PRs.',
                'distributionChannel': 'DEFAULT_OAI_CATALOG',
                'installUrl': 'https://chatgpt.com/apps/github',
                'pluginDisplayNames': ['GitHub'],
                'toolSummaries': [
                  {
                    'name': 'add_comment_to_issue',
                    'title': 'Add Issue Comment',
                    'description': 'Create a top-level PR comment.',
                    'isEnabled': true,
                    'isReadOnly': false,
                    'disabledReason': null,
                  },
                ],
              },
            ],
            'missingAppIds': ['missing_app'],
          },
          _ => const {},
        };
      },
    );

    final page = await adapter.listApps(
      const AppListQuery(
        cursor: 'cursor-page-1',
        limit: 250,
        threadId: 'thread-42',
        forceRefetch: true,
      ),
    );
    expect(calls.single.$1, 'app/list');
    expect(calls.single.$2, {
      'limit': 100,
      'cursor': 'cursor-page-1',
      'threadId': 'thread-42',
      'forceRefetch': true,
    });
    expect(page.apps, hasLength(1));
    expect(page.apps.single.id, 'connector_github');
    expect(page.apps.single.category, 'Developer Tools');
    expect(page.apps.single.developer, 'OpenAI');
    expect(page.apps.single.version, '2.1.0');
    expect(page.apps.single.isDiscoverableApp, isTrue);
    expect(page.nextCursor, 'cursor-page-2');

    final installed = await adapter.listInstalledApps(
      threadId: 'thread-42',
      forceRefresh: true,
    );
    expect(calls.last.$1, 'app/installed');
    expect(calls.last.$2, {'threadId': 'thread-42', 'forceRefresh': true});
    expect(installed, hasLength(1));
    expect(installed.single.id, 'connector_github');
    expect(installed.single.displayName, 'GitHub');
    expect(installed.single.enabled, isTrue);
    expect(installed.single.callable, isTrue);

    final emptyRead = await adapter.readApps(appIds: const ['  ', '']);
    expect(emptyRead.apps, isEmpty);
    expect(emptyRead.missingAppIds, isEmpty);
    expect(calls, hasLength(2));

    final oversizedIds = [
      'connector_github',
      'connector_github',
      'missing_app',
      for (var i = 0; i < 120; i++) 'extra_$i',
    ];
    final readResult = await adapter.readApps(
      appIds: oversizedIds,
      includeTools: true,
      threadId: 'thread-42',
    );
    expect(calls.last.$1, 'app/read');
    final sentAppIds = calls.last.$2['appIds'] as List<String>;
    expect(sentAppIds, hasLength(100));
    expect(sentAppIds.take(2), ['connector_github', 'missing_app']);
    expect(readResult.apps, hasLength(1));
    expect(
      readResult.apps.single.toolSummaries.single.name,
      'add_comment_to_issue',
    );
    expect(readResult.missingAppIds, ['missing_app']);
  });

  test('parses plugin/read detail manifest and executes plugin/install and plugin/uninstall RPCs', () async {
    final calls = <(String, JsonObject)>[];
    final adapter = EcosystemProtocolAdapter(
      request: (method, [params = const {}]) async {
        calls.add((method, params));
        return switch (method) {
          'plugin/read' => {
            'plugin': {
              'marketplaceName': 'openai-primary-runtime',
              'marketplacePath': '/mp/marketplace.json',
              'description': 'Create and edit document artifacts in Codex.',
              'summary': {
                'id': 'documents@openai-primary-runtime',
                'name': 'documents',
                'localVersion': '26.1104.22356',
                'installed': true,
                'enabled': true,
                'installPolicy': 'AVAILABLE',
                'authPolicy': 'ON_USE',
                'availability': 'AVAILABLE',
                'source': {'type': 'local', 'path': '/mp/plugins/documents'},
                'interface': {
                  'displayName': 'Documents',
                  'shortDescription': 'Create and edit documents',
                },
              },
              'skills': [
                {
                  'name': 'documents:documents',
                  'description': 'Docx workflow',
                  'enabled': true,
                  'path': '/mp/plugins/documents/SKILL.md',
                },
              ],
              'apps': [
                {
                  'id': 'connector_github',
                  'name': 'GitHub',
                  'category': 'Developer Tools',
                },
              ],
              'mcpServers': ['docs-mcp'],
              'hooks': [
                {'key': 'pre-tool', 'eventName': 'preToolUse'},
              ],
              'shareUrl': 'https://chatgpt.com/plugins/documents',
            },
          },
          'plugin/install' => {
            'authPolicy': 'ON_INSTALL',
            'appsNeedingAuth': [
              {
                'id': 'connector_github',
                'name': 'GitHub',
                'installUrl': 'https://chatgpt.com/apps/github',
              },
            ],
          },
          'plugin/uninstall' => const {},
          _ => const {},
        };
      },
    );

    final detail = await adapter.readPlugin(
      pluginName: 'documents',
      marketplacePath: '/mp/marketplace.json',
      remoteMarketplaceName: 'ignored-when-path-present',
    );
    expect(calls.last.$1, 'plugin/read');
    expect(calls.last.$2, {
      'pluginName': 'documents',
      'marketplacePath': '/mp/marketplace.json',
    });
    expect(detail.summary.id, 'documents@openai-primary-runtime');
    expect(detail.summary.name, 'Documents');
    expect(detail.summary.version, '26.1104.22356');
    expect(detail.marketplaceName, 'openai-primary-runtime');
    expect(detail.skills.single.name, 'documents:documents');
    expect(detail.apps.single.name, 'GitHub');
    expect(detail.mcpServers, ['docs-mcp']);
    expect(detail.hooks.single.eventName, 'preToolUse');

    final installResult = await adapter.installPlugin(
      pluginName: 'github',
      remoteMarketplaceName: 'openai-curated',
      installAttemptId: 'attempt-99',
    );
    expect(calls.last.$1, 'plugin/install');
    expect(calls.last.$2, {
      'pluginName': 'github',
      'remoteMarketplaceName': 'openai-curated',
      'installAttemptId': 'attempt-99',
    });
    expect(installResult.authPolicy, 'ON_INSTALL');
    expect(installResult.appsNeedingAuth.single.id, 'connector_github');

    await adapter.uninstallPlugin(pluginId: 'github@openai-curated');
    expect(calls.last.$1, 'plugin/uninstall');
    expect(calls.last.$2, {'pluginId': 'github@openai-curated'});

    expect(() => adapter.readPlugin(pluginName: '   '), throwsArgumentError);
    expect(() => adapter.installPlugin(pluginName: ''), throwsArgumentError);
    expect(() => adapter.uninstallPlugin(pluginId: ''), throwsArgumentError);
  });

  test('manages Track B official remoteControl/* RPCs and distinguishes operational errors from unsupported methods', () async {
    var mode = 'ok';
    final calledMethods = <String>[];
    final adapter = EcosystemProtocolAdapter(
      request: (method, [params = const {}]) async {
        calledMethods.add(method);
        if (mode == 'unsupported') {
          throw const JsonRpcException(
            code: -32600,
            message: 'Invalid request: unknown variant `remoteControl/foo`',
          );
        }
        if (mode == 'operational_error') {
          throw const JsonRpcException(
            code: -32000,
            message: 'ChatGPT account authentication required for relay',
          );
        }
        return switch (method) {
          'remoteControl/status/read' => {
            'status': 'connected',
            'serverName': 'workstation-host',
            'installationId': 'inst-1',
            'environmentId': 'env-123',
          },
          'remoteControl/client/list' => {
            'data': [
              {
                'clientId': 'client-1',
                'displayName': 'iPhone',
                'platform': 'iOS',
                'lastSeenAt': 1700000000,
              },
            ],
          },
          'remoteControl/enable' => {
            'status': 'connecting',
            'serverName': 'workstation-host',
            'installationId': 'inst-1',
            'environmentId': 'env-123',
          },
          'remoteControl/disable' => {
            'status': 'disabled',
            'serverName': 'workstation-host',
            'installationId': 'inst-1',
            'environmentId': null,
          },
          'remoteControl/pairing/start' => {
            'environmentId': 'env-123',
            'expiresAt': 1700000300,
            'pairingCode': 'codex://pair?code=PAIR-1234',
            'manualPairingCode': 'PAIR-1234',
          },
          'remoteControl/client/revoke' => const {},
          _ => const {},
        };
      },
    );

    final status = await adapter.readOfficialRemoteControlStatus();
    expect(status.supported, isTrue);
    expect(status.enabled, isTrue);
    expect(status.connected, isTrue);
    expect(status.stateLabel, 'connected');
    expect(status.serverName, 'workstation-host');
    expect(status.environmentId, 'env-123');
    expect(status.clients.single.id, 'client-1');
    expect(status.clients.single.name, 'iPhone');
    expect(calledMethods, [
      'remoteControl/status/read',
      'remoteControl/client/list',
    ]);

    final disabledStatus = await adapter.setOfficialRemoteControlEnabled(false);
    expect(disabledStatus.supported, isTrue);
    expect(disabledStatus.enabled, isFalse);
    expect(disabledStatus.stateLabel, 'disabled');
    expect(calledMethods.last, 'remoteControl/disable');

    final enabledStatus = await adapter.setOfficialRemoteControlEnabled(true);
    expect(enabledStatus.supported, isTrue);
    expect(enabledStatus.enabled, isTrue);
    expect(enabledStatus.stateLabel, 'connecting');
    expect(calledMethods.last, 'remoteControl/enable');

    final pairing = await adapter.startOfficialRemoteControlPairing();
    expect(pairing.code, 'PAIR-1234');
    expect(pairing.qrPayload, 'codex://pair?code=PAIR-1234');
    expect(pairing.expiresAtMs, 1700000300);
    expect(calledMethods.last, 'remoteControl/pairing/start');

    final disconnected = await adapter.disconnectOfficialRemoteControlClient(
      'client-1',
      environmentId: 'env-123',
    );
    expect(disconnected, isTrue);
    expect(calledMethods.last, 'remoteControl/client/revoke');

    mode = 'operational_error';
    final operationalError = await adapter.setOfficialRemoteControlEnabled(
      true,
    );
    expect(operationalError.supported, isTrue);
    expect(
      operationalError.errorMessage,
      contains('ChatGPT account authentication required'),
    );

    mode = 'unsupported';
    final unsupported = await adapter.readOfficialRemoteControlStatus();
    expect(unsupported.supported, isFalse);
    expect(unsupported.errorMessage, contains('unknown variant'));
  });

  test('live stock codex app-server integration exercises thread lifecycle and ecosystem RPCs', () async {
    const stockCodexPath = '/opt/codex-desktop/resources/codex';
    if (!File(stockCodexPath).existsSync()) {
      return;
    }

    final transport = await ProcessTransport.start(
      executablePath: stockCodexPath,
    );
    addTearDown(() async {
      await transport.close();
    });

    final init = await transport.initialize(const InitializeRequest());
    expect(init.userAgent, isNotEmpty);

    // 1. Ecosystem discovery (Skills, Plugins, Apps, MCP, Track B Remote Control)
    final skills = await transport.listSkills(cwds: [Directory.current.path]);
    expect(skills, isNotEmpty);

    final plugins = await transport.listPlugins(cwds: [Directory.current.path]);
    expect(plugins, isNotEmpty);
    final firstPlugin = plugins.first;
    final pluginDetail = await transport.readPlugin(
      pluginName: firstPlugin.effectivePluginName,
      marketplacePath: firstPlugin.marketplacePath,
      remoteMarketplaceName: firstPlugin.marketplacePath == null
          ? firstPlugin.marketplaceName
          : null,
    );
    expect(pluginDetail.summary.id, firstPlugin.id);

    final installedApps = await transport.listInstalledApps();
    expect(installedApps, isA<List<InstalledAppSnapshotModel>>());
    if (installedApps.isNotEmpty) {
      final appRead = await transport.readApps(
        appIds: [installedApps.first.id],
        includeTools: true,
      );
      expect(
        appRead.apps.isNotEmpty || appRead.missingAppIds.isNotEmpty,
        isTrue,
      );
    }

    final mcpServers = await transport.listMcpServerStatus();
    expect(mcpServers, isA<List<Object?>>());
    await transport.reloadMcpServers();

    final remoteControl = await transport.readOfficialRemoteControlStatus();
    expect(remoteControl.supported, isTrue);
    expect(remoteControl.stateLabel, 'disabled');
    expect(remoteControl.serverName, isNotEmpty);

    final disabledAgain = await transport.setOfficialRemoteControlEnabled(
      false,
    );
    expect(disabledAgain.supported, isTrue);
    expect(disabledAgain.enabled, isFalse);

    // 2. Thread lifecycle (start, rename, archive, unarchive, delete)
    final created = await transport.startThread(
      ThreadStartOptions(cwd: Directory.current.path),
    );
    expect(created.id, isNotEmpty);

    await transport.renameThread(
      threadId: created.id,
      name: 'Convergence Smoke Thread',
    );

    await transport.archiveThread(created.id);

    final archivedPage = await transport.listThreads(
      const ThreadListQuery(limit: 20, archived: true),
    );
    expect(archivedPage.threads.any((t) => t.id == created.id), isTrue);

    final unarchived = await transport.unarchiveThread(created.id);
    expect(unarchived.id, created.id);
    expect(unarchived.name, 'Convergence Smoke Thread');

    await transport.deleteThread(created.id);
  });
}
