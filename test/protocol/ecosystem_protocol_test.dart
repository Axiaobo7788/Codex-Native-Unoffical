import 'dart:io';

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
                  'plugins': [
                    {
                      'id': 'git-workflow',
                      'enabled': true,
                      'interface': {
                        'displayName': 'Git Workflow',
                        'shortDescription': 'Branch and PR helpers',
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
      expect(plugins.single.id, 'git-workflow');
      expect(plugins.single.name, 'Git Workflow');

      final mcp = await adapter.listMcpServerStatus();
      expect(mcp, hasLength(1));
      expect(mcp.single.name, 'filesystem-mcp');
      expect(mcp.single.toolCount, 2);
      expect(mcp.single.resourceCount, 1);
      expect(mcp.single.status, 'ready');
    },
  );

  test('manages Track B official remoteControl/* RPCs and degrades gracefully when unsupported', () async {
    var throwUnsupported = false;
    final adapter = EcosystemProtocolAdapter(
      request: (method, [params = const {}]) async {
        if (throwUnsupported) {
          throw StateError('Method not found: $method');
        }
        return switch (method) {
          'remoteControl/status' => {
            'enabled': true,
            'connected': true,
            'environmentId': 'env-123',
            'clients': [
              {'id': 'client-1', 'name': 'iPhone', 'platform': 'iOS'},
            ],
          },
          'remoteControl/setEnabled' => {
            'enabled': params['enabled'],
            'connected': params['enabled'],
            'environmentId': 'env-123',
            'clients': <Object?>[],
          },
          'remoteControl/pair/start' => {
            'code': 'PAIR-1234',
            'qrPayload': 'codex://pair?code=PAIR-1234',
          },
          'remoteControl/clients/disconnect' => {'disconnected': true},
          _ => const {},
        };
      },
    );

    final status = await adapter.readOfficialRemoteControlStatus();
    expect(status.supported, isTrue);
    expect(status.enabled, isTrue);
    expect(status.environmentId, 'env-123');
    expect(status.clients.single.name, 'iPhone');

    final pairing = await adapter.startOfficialRemoteControlPairing();
    expect(pairing.code, 'PAIR-1234');

    final disconnected = await adapter.disconnectOfficialRemoteControlClient(
      'client-1',
    );
    expect(disconnected, isTrue);

    throwUnsupported = true;
    final unsupported = await adapter.readOfficialRemoteControlStatus();
    expect(unsupported.supported, isFalse);
    expect(unsupported.errorMessage, contains('Method not found'));
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

    // 1. Ecosystem discovery (Skills, Plugins, MCP, Track B Remote Control)
    final skills = await transport.listSkills(cwds: [Directory.current.path]);
    expect(skills, isNotEmpty);

    final plugins = await transport.listPlugins(cwds: [Directory.current.path]);
    expect(plugins, isNotEmpty);

    final mcpServers = await transport.listMcpServerStatus();
    expect(mcpServers, isA<List<Object?>>());

    final remoteControl = await transport.readOfficialRemoteControlStatus();
    expect(remoteControl.supported, isA<bool>());

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
