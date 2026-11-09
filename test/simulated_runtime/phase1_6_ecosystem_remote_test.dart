import 'dart:async';

import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/ecosystem_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  group('F8 Stable MCP Capabilities simulated runtime', () {
    testWidgets(
      'reloads MCP config, reads bounded resources, calls tools, and submits form elicitation',
      (tester) async {
        final harness = SimulatedRuntimeHarness(
          initialThreads: [
            createTestThread(id: 'thread-mcp', preview: 'MCP capability test'),
          ],
        );

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.byKey(const ValueKey('thread-row-thread-mcp')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('MCP (1)'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('mcp-reload-button')));
        await tester.pumpAndSettle();
        expect(harness.mcpReloadCount, 1);
        expect(find.byKey(const ValueKey('mcp-action-notice')), findsOneWidget);

        harness.mcpResourceReadHandler = (query) async {
          if (query.uri == 'memory://native-fixture/needs-form') {
            final response = await harness.emitMcpElicitationAndWait(
              McpElicitationRequest(
                requestId: 'elicitation-resource-1',
                serverName: query.server,
                threadId: query.threadId!,
                message: 'Provide resource token.',
                mode: McpElicitationMode.form,
                fields: [
                  McpElicitationField(
                    id: 'value',
                    title: 'Value',
                    description: 'Resource form value',
                    kind: McpElicitationFieldKind.string,
                    required: true,
                  ),
                ],
              ),
            );
            return McpResourceReadResultModel(
              contents: [
                McpTextResourceContentModel(
                  uri: query.uri,
                  mimeType: 'text/plain',
                  text: '${response.action.name}: ${response.content['value']}',
                ),
              ],
            );
          }
          return harness.mcpResourceReadResult;
        };

        await tester.tap(
          find.byKey(const ValueKey('mcp-read-resource-filesystem-mcp')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('mcp-resource-uri-field')),
          'memory://native-fixture/needs-form',
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('mcp-resource-read-submit')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(harness.mcpResourceReadQueries.single.server, 'filesystem-mcp');
        expect(harness.mcpResourceReadQueries.single.threadId, 'thread-mcp');
        expect(
          harness.mcpResourceReadQueries.single.uri,
          'memory://native-fixture/needs-form',
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('mcp-read-resource-filesystem-mcp')),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('mcp-call-tool-filesystem-mcp')),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('mcp-elicitation-card')).hitTestable(),
          findsOneWidget,
        );
        await tester.enterText(
          find
              .byKey(const ValueKey('mcp-elicitation-field-value'))
              .hitTestable(),
          'answer',
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('mcp-elicitation-accept')).hitTestable(),
        );
        await tester.pumpAndSettle();
        expect(find.text('accept: answer'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('mcp-result-filesystem-mcp')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('ecosystem-refresh-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('mcp-result-filesystem-mcp')),
          findsNothing,
        );

        final callTool = find.byKey(
          const ValueKey('mcp-call-tool-filesystem-mcp'),
        );
        harness.mcpToolCallHandler = (query) async {
          final response = await harness.emitMcpElicitationAndWait(
            McpElicitationRequest(
              requestId: 'elicitation-1',
              serverName: query.server,
              threadId: query.threadId,
              message: 'Choose the write target.',
              mode: McpElicitationMode.form,
              fields: [
                McpElicitationField(
                  id: 'path',
                  title: 'Path',
                  description: 'Relative workspace path',
                  kind: McpElicitationFieldKind.string,
                  required: true,
                ),
                McpElicitationField(
                  id: 'mode',
                  title: 'Mode',
                  description: '',
                  kind: McpElicitationFieldKind.singleSelect,
                  required: true,
                  options: const [
                    McpElicitationOption(value: 'replace', label: 'Replace'),
                    McpElicitationOption(value: 'append', label: 'Append'),
                  ],
                ),
              ],
            ),
          );
          return McpToolCallResultModel(
            content: [
              McpToolContentModel(
                kind: 'text',
                summary: 'Text',
                text:
                    'Tool completed (${response.action.name}: '
                    '${response.content['path']} / ${response.content['mode']}).',
              ),
            ],
            isError: false,
            structuredContentPreview: '{"changed":true}',
          );
        };

        await tester.ensureVisible(callTool);
        await tester.tap(callTool);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('mcp-tool-name-field')),
          'read_file',
        );
        await tester.enterText(
          find.byKey(const ValueKey('mcp-tool-arguments-field')),
          '{"path":"README.md"}',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('mcp-tool-call-submit')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(harness.mcpToolCallQueries.single.tool, 'read_file');
        expect(harness.mcpToolCallQueries.single.threadId, 'thread-mcp');
        expect(harness.mcpToolCallQueries.single.arguments, {
          'path': 'README.md',
        });
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('mcp-call-tool-filesystem-mcp')),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('mcp-read-resource-filesystem-mcp')),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );

        // Direct elicitation (turnId == null) renders inside the open modal
        // scroll-bounded slot and is hit-testable above the modal barrier.
        expect(find.text('Skills, Plugins & MCP'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('ecosystem-modal-elicitation-slot')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('mcp-elicitation-card')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('ecosystem-modal-elicitation-slot')),
            matching: find.byKey(const ValueKey('mcp-elicitation-card')),
          ),
          findsOneWidget,
        );

        await tester.enterText(
          find
              .byKey(const ValueKey('mcp-elicitation-field-path'))
              .hitTestable(),
          'README.md',
        );
        await tester.pump();

        // Switching tabs mid-call keeps the active form reachable in the modal
        // and preserves typed draft text in the single dialog-local slot.
        await tester.tap(find.text('Skills (1)'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('mcp-elicitation-card')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text('MCP (1)'));
        await tester.pump();

        await tester.tap(
          find
              .byKey(const ValueKey('mcp-elicitation-field-mode-replace'))
              .hitTestable(),
        );
        await tester.pump();
        final acceptButton = find
            .byKey(const ValueKey('mcp-elicitation-accept'))
            .hitTestable();
        expect(acceptButton, findsOneWidget);
        await tester.ensureVisible(acceptButton);
        await tester.tap(acceptButton);
        await tester.pumpAndSettle();

        final response = harness.mcpElicitationResponses.last;
        expect(response.requestId, 'elicitation-1');
        expect(response.action, McpElicitationAction.accept);
        expect(response.content, {'path': 'README.md', 'mode': 'replace'});
        expect(
          find.byKey(const ValueKey('mcp-elicitation-card')),
          findsNothing,
        );
        // Result renders directly inside the still-open modal dialog.
        expect(find.text('Skills, Plugins & MCP'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('mcp-result-filesystem-mcp')),
          findsOneWidget,
        );
        expect(
          find.text('Tool completed (accept: README.md / replace).'),
          findsOneWidget,
        );

        // Model-turn elicitations (turnId != null) continue routing to the
        // conversation banner after closing the dialog.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        harness.emitMcpElicitation(
          McpElicitationRequest(
            requestId: 'elicitation-turn-1',
            serverName: 'filesystem-mcp',
            threadId: 'thread-mcp',
            turnId: 'turn-1',
            message: 'Confirm turn-scoped path.',
            mode: McpElicitationMode.form,
            fields: [
              McpElicitationField(
                id: 'path',
                title: 'Path',
                description: 'Turn path',
                kind: McpElicitationFieldKind.string,
                required: true,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('mcp-elicitation-card')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('mcp-elicitation-field-path')),
          'NOTES.md',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('mcp-elicitation-accept')));
        await tester.pumpAndSettle();
        expect(
          harness.mcpElicitationResponses.last.requestId,
          'elicitation-turn-1',
        );
        expect(harness.mcpElicitationResponses.last.content, {
          'path': 'NOTES.md',
        });
      },
    );

    testWidgets(
      'separates MCP runtime status badge from labeled auth status without rendering bare unsupported',
      (tester) async {
        final harness = SimulatedRuntimeHarness(
          initialThreads: [
            createTestThread(
              id: 'thread-mcp-status',
              preview: 'MCP status test',
            ),
          ],
        );
        harness.mcpServers
          ..clear()
          ..addAll(const [
            McpServerStatusModel(
              name: 'catalog-idle-mcp',
              status: '',
              toolCount: 1,
              resourceCount: 0,
              authStatus: 'unsupported',
            ),
            McpServerStatusModel(
              name: 'scoped-connected-mcp',
              status: 'connected',
              toolCount: 3,
              resourceCount: 2,
              authStatus: 'unsupported',
            ),
          ]);

        await pumpSimulatedRuntimeApp(tester, harness: harness);
        await tester.tap(
          find.byKey(const ValueKey('thread-row-thread-mcp-status')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('MCP (2)'));
        await tester.pumpAndSettle();

        expect(find.text('unsupported'), findsNothing);
        expect(
          find.byKey(const ValueKey('mcp-status-catalog-idle-mcp')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('mcp-auth-status-catalog-idle-mcp')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('mcp-status-scoped-connected-mcp')),
          findsOneWidget,
        );
        expect(find.text('connected'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('mcp-auth-status-scoped-connected-mcp')),
          findsOneWidget,
        );
        expect(find.text('Auth: unsupported'), findsNWidgets(2));
      },
    );

    testWidgets('keeps non-finite MCP number elicitation values unsubmitable', (
      tester,
    ) async {
      final harness = SimulatedRuntimeHarness(
        initialThreads: [
          createTestThread(id: 'thread-mcp', preview: 'MCP number test'),
        ],
      );

      await pumpSimulatedRuntimeApp(tester, harness: harness);
      await tester.tap(find.byKey(const ValueKey('thread-row-thread-mcp')));
      await tester.pumpAndSettle();

      harness.emitMcpElicitation(
        McpElicitationRequest(
          requestId: 'elicitation-number',
          serverName: 'filesystem-mcp',
          threadId: 'thread-mcp',
          message: 'Choose a finite retry interval.',
          mode: McpElicitationMode.form,
          fields: [
            McpElicitationField(
              id: 'interval',
              title: 'Interval',
              description: 'Seconds between retries',
              kind: McpElicitationFieldKind.number,
              required: true,
              minimum: 0,
              maximum: 60,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final numberField = find.byKey(
        const ValueKey('mcp-elicitation-field-interval'),
      );
      final accept = find.byKey(const ValueKey('mcp-elicitation-accept'));
      await tester.enterText(numberField, 'NaN');
      await tester.pump();
      await tester.tap(accept, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(harness.mcpElicitationResponses, isEmpty);

      await tester.enterText(numberField, '1.5');
      await tester.pump();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(harness.mcpElicitationResponses.single.content, {'interval': 1.5});
    });
  });

  group('F9 Apps & Plugins Lifecycle simulated runtime', () {
    testWidgets(
      'inspects plugin details, installs and uninstalls plugins with refresh, and surfaces auth requirements',
      (tester) async {
        final harness = SimulatedRuntimeHarness();
        harness.plugins
          ..clear()
          ..addAll([
            const PluginSummaryModel(
              id: 'documents@openai-primary-runtime',
              name: 'Documents',
              pluginName: 'documents',
              description: 'Create and edit documents',
              enabled: true,
              installed: true,
              version: '26.1104.22356',
              marketplaceName: 'openai-primary-runtime',
              marketplacePath: '/workspace/.agents/plugins/marketplace.json',
              sourceType: 'local',
            ),
            const PluginSummaryModel(
              id: 'linear-sync@openai-curated',
              name: 'Linear Sync',
              pluginName: 'linear-sync',
              description: 'Synchronize Linear issues with Codex tasks',
              enabled: false,
              installed: false,
              version: '0.9.0',
              marketplaceName: 'openai-curated',
              sourceType: 'remote',
              authPolicy: 'ON_INSTALL',
            ),
          ]);
        harness.installAuthApps.add(
          const PluginAppReferenceModel(
            id: 'connector_linear',
            name: 'Linear',
            installUrl: 'https://chatgpt.com/apps/linear',
          ),
        );

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Plugins (2)'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey('plugin-row-documents@openai-primary-runtime'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('plugin-row-linear-sync@openai-curated')),
          findsOneWidget,
        );

        // 1. Inspect plugin detail via plugin/read
        await tester.tap(
          find.byKey(
            const ValueKey('plugin-read-documents@openai-primary-runtime'),
          ),
        );
        await tester.pumpAndSettle();

        expect(harness.readPluginRequests, [
          (
            pluginName: 'documents',
            marketplacePath: '/workspace/.agents/plugins/marketplace.json',
            remoteMarketplaceName: null,
          ),
        ]);
        expect(
          find.byKey(
            const ValueKey('plugin-detail-documents@openai-primary-runtime'),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Full detail manifest for Documents.'),
          findsOneWidget,
        );

        // 2. Install remote plugin via plugin/install and verify refresh + auth notice
        await tester.tap(
          find.byKey(
            const ValueKey('plugin-install-linear-sync@openai-curated'),
          ),
        );
        await tester.pumpAndSettle();

        expect(harness.installedPluginRequests, [
          (
            pluginName: 'linear-sync',
            marketplacePath: null,
            remoteMarketplaceName: 'openai-curated',
          ),
        ]);
        expect(
          find.byKey(const ValueKey('plugin-install-auth-notice')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Connector authentication required: Linear.'),
          findsOneWidget,
        );
        // After install + refresh, the button transitions to Uninstall
        expect(
          find.byKey(
            const ValueKey('plugin-uninstall-linear-sync@openai-curated'),
          ),
          findsOneWidget,
        );

        // 3. Uninstall plugin via plugin/uninstall and verify refresh
        await tester.tap(
          find.byKey(
            const ValueKey('plugin-uninstall-linear-sync@openai-curated'),
          ),
        );
        await tester.pumpAndSettle();

        expect(harness.uninstalledPluginIds, ['linear-sync@openai-curated']);
        expect(
          find.byKey(
            const ValueKey('plugin-install-linear-sync@openai-curated'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'presents installed connector runtime, paginated app catalog, app/read tool summaries, and 100-item bound',
      (tester) async {
        final harness = SimulatedRuntimeHarness();
        harness.catalogPageSizeOverride = 25;
        harness.installedApps
          ..clear()
          ..addAll([
            const InstalledAppSnapshotModel(
              id: 'connector_github',
              runtimeName: 'GitHub',
              enabled: true,
              callable: true,
            ),
            const InstalledAppSnapshotModel(
              id: 'connector_unindexed',
              runtimeName: 'Unindexed Local Connector',
              enabled: true,
              callable: false,
            ),
          ]);
        harness.catalogApps
          ..clear()
          ..addAll([
            const AppSummaryModel(
              id: 'connector_github',
              name: 'GitHub',
              description: 'Access repositories, issues, and pull requests.',
              isAccessible: true,
              isEnabled: true,
              category: 'Developer Tools',
              developer: 'OpenAI',
              pluginDisplayNames: ['Git Workflow'],
            ),
            for (var i = 1; i < 110; i++)
              AppSummaryModel(
                id: 'connector_app_$i',
                name: 'Catalog App $i',
                description: 'Description for catalog app $i',
                isAccessible: i.isEven,
                isEnabled: true,
              ),
          ]);

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Apps (25)'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('installed-app-row-connector_github')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('app-row-connector_github')),
          findsOneWidget,
        );
        // Virtualization check: offscreen row at the end of the 25-item page is not built initially.
        expect(
          find.byKey(const ValueKey('app-row-connector_app_24')),
          findsNothing,
        );

        // Inspect catalog app details via app/read
        await tester.tap(
          find.byKey(const ValueKey('app-read-connector_github')),
        );
        await tester.pumpAndSettle();

        expect(harness.readAppRequests.last.appIds, ['connector_github']);
        expect(
          find.byKey(const ValueKey('app-detail-connector_github')),
          findsOneWidget,
        );
        expect(find.textContaining('create_pull_request'), findsOneWidget);

        // Inspect unindexed installed app that returns in missingAppIds
        await tester.tap(
          find.byKey(const ValueKey('installed-app-read-connector_unindexed')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('app-detail-missing-connector_unindexed')),
          findsOneWidget,
        );

        final appsScrollable = find.descendant(
          of: find.byKey(const ValueKey('ecosystem-apps-scroll')),
          matching: find.byType(Scrollable),
        );

        // Scroll until offscreen row 24 is lazily built.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('app-row-connector_app_24')),
          240,
          scrollable: appsScrollable,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('app-row-connector_app_24')),
          findsOneWidget,
        );

        // Paginate catalog apps up to the 100-item bound
        for (var page = 0; page < 3; page++) {
          final loadMore = find.byKey(
            const ValueKey('ecosystem-apps-load-more'),
          );
          await tester.scrollUntilVisible(
            loadMore,
            240,
            scrollable: appsScrollable,
          );
          await tester.tap(loadMore);
          await tester.pumpAndSettle();
        }

        expect(find.text('Apps (100)'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('ecosystem-apps-bound-notice')),
          300,
          scrollable: appsScrollable,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ecosystem-apps-bound-notice')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('app-row-connector_app_99')),
          findsOneWidget,
        );
        // Virtualization check: top row is no longer mounted when scrolled to bottom.
        expect(
          find.byKey(const ValueKey('app-row-connector_github')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('ecosystem-apps-load-more')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'delayed or offline app/list does not block Skills, Plugins, or MCP sections',
      (tester) async {
        final harness = SimulatedRuntimeHarness();
        final appListCompleter = Completer<AppListPage>();
        harness.listAppsOverride = (_) => appListCompleter.future;

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
        await tester.pumpAndSettle();

        // Skills, Plugins, and MCP render immediately while app/list is still pending.
        expect(
          find.byKey(const ValueKey('skill-row-frontend-design')),
          findsOneWidget,
        );

        await tester.tap(find.text('Plugins (1)'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plugin-row-git-workflow')),
          findsOneWidget,
        );

        await tester.tap(find.text('MCP (1)'));
        await tester.pumpAndSettle();
        expect(find.text('filesystem-mcp'), findsOneWidget);

        // Switching to Apps shows already-loaded installed runtime apps plus non-blocking catalog loading.
        await tester.tap(find.text('Apps (1)'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('installed-app-row-connector_github')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('ecosystem-apps-loading')),
          findsOneWidget,
        );

        // Completing app/list with an offline timeout error updates Apps without affecting other sections.
        appListCompleter.completeError(
          StateError('app/list offline network timeout'),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('ecosystem-apps-loading')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('ecosystem-apps-error')),
          findsOneWidget,
        );
        expect(
          find.textContaining('app/list offline network timeout'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('installed-app-row-connector_github')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'prunes detail, missing, and expansion caches across catalog refreshes when IDs change',
      (tester) async {
        final harness = SimulatedRuntimeHarness();
        harness.plugins
          ..clear()
          ..add(
            const PluginSummaryModel(
              id: 'plugin_alpha@local',
              name: 'Plugin Alpha',
              pluginName: 'plugin_alpha',
              description: 'Alpha plugin',
              enabled: true,
              installed: true,
              marketplaceName: 'local',
              marketplacePath: '/workspace/.agents/plugins/marketplace.json',
            ),
          );
        harness.installedApps
          ..clear()
          ..add(
            const InstalledAppSnapshotModel(
              id: 'connector_missing_alpha',
              runtimeName: 'Missing Alpha',
              enabled: true,
              callable: false,
            ),
          );
        harness.catalogApps
          ..clear()
          ..add(
            const AppSummaryModel(
              id: 'connector_alpha',
              name: 'Alpha Connector',
              description: 'Initial alpha description',
              isAccessible: true,
              isEnabled: true,
            ),
          );

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
        await tester.pumpAndSettle();

        // Expand plugin_alpha details
        await tester.tap(find.text('Plugins (1)'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('plugin-read-plugin_alpha@local')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plugin-detail-plugin_alpha@local')),
          findsOneWidget,
        );

        // Expand catalog app connector_alpha details and missing installed app connector_missing_alpha
        await tester.tap(find.text('Apps (1)'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('app-read-connector_alpha')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('app-detail-connector_alpha')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(
            const ValueKey('installed-app-read-connector_missing_alpha'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const ValueKey('app-detail-missing-connector_missing_alpha'),
          ),
          findsOneWidget,
        );

        // Replace catalog with completely new IDs and refresh
        harness.plugins
          ..clear()
          ..add(
            const PluginSummaryModel(
              id: 'plugin_beta@local',
              name: 'Plugin Beta',
              pluginName: 'plugin_beta',
              description: 'Beta plugin',
              enabled: true,
              installed: true,
              marketplaceName: 'local',
              marketplacePath: '/workspace/.agents/plugins/marketplace.json',
            ),
          );
        harness.installedApps.clear();
        harness.catalogApps
          ..clear()
          ..add(
            const AppSummaryModel(
              id: 'connector_beta',
              name: 'Beta Connector',
              description: 'Beta description',
              isAccessible: true,
              isEnabled: true,
            ),
          );

        await tester.tap(
          find.byKey(const ValueKey('ecosystem-refresh-button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('app-detail-connector_alpha')),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey('app-detail-missing-connector_missing_alpha'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('app-row-connector_beta')),
          findsOneWidget,
        );

        // Re-introduce alpha IDs on a subsequent refresh: pruned expansion/detail state must not resurrect.
        harness.plugins
          ..clear()
          ..add(
            const PluginSummaryModel(
              id: 'plugin_alpha@local',
              name: 'Plugin Alpha',
              pluginName: 'plugin_alpha',
              description: 'Alpha plugin v2',
              enabled: true,
              installed: true,
              marketplaceName: 'local',
              marketplacePath: '/workspace/.agents/plugins/marketplace.json',
            ),
          );
        harness.installedApps
          ..clear()
          ..add(
            const InstalledAppSnapshotModel(
              id: 'connector_missing_alpha',
              runtimeName: 'Missing Alpha',
              enabled: true,
              callable: false,
            ),
          );
        harness.catalogApps
          ..clear()
          ..add(
            const AppSummaryModel(
              id: 'connector_alpha',
              name: 'Alpha Connector',
              description: 'Updated alpha description',
              isAccessible: true,
              isEnabled: true,
            ),
          );

        await tester.tap(
          find.byKey(const ValueKey('ecosystem-refresh-button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('app-detail-connector_alpha')),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey('app-detail-missing-connector_missing_alpha'),
          ),
          findsNothing,
        );

        await tester.tap(find.text('Plugins (1)'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plugin-detail-plugin_alpha@local')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'fails closed visibly when backend does not support ecosystem catalog mutations',
      (tester) async {
        final harness = SimulatedRuntimeHarness()..catalogSupported = false;
        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.byKey(const ValueKey('ecosystem-button')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Plugins (1)'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ecosystem-plugins-lifecycle-unsupported')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('plugin-install-git-workflow')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('plugin-uninstall-git-workflow')),
          findsNothing,
        );

        await tester.tap(find.text('Apps (0)'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ecosystem-catalog-unsupported')),
          findsOneWidget,
        );

        final remoteController = RuntimeController(useRemote: true);
        addTearDown(remoteController.dispose);
        expect(remoteController.supportsEcosystemCatalog, isFalse);
        expect(() => remoteController.listApps(), throwsUnsupportedError);
        expect(
          () => remoteController.listInstalledApps(),
          throwsUnsupportedError,
        );
        expect(
          () => remoteController.readApps(appIds: const ['connector_github']),
          throwsUnsupportedError,
        );
        expect(
          () => remoteController.readPlugin(pluginName: 'documents'),
          throwsUnsupportedError,
        );
        expect(
          () => remoteController.installPlugin(pluginName: 'documents'),
          throwsUnsupportedError,
        );
        expect(
          () => remoteController.uninstallPlugin(pluginId: 'documents'),
          throwsUnsupportedError,
        );
      },
    );
  });
}
