import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/ecosystem_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_harness.dart';

void main() {
  group('F9 Apps & Plugins Lifecycle E2E', () {
    testWidgets(
      'inspects plugin details, installs and uninstalls plugins with refresh, and surfaces auth requirements',
      (tester) async {
        final harness = E2ERuntimeHarness();
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

        await pumpE2EApp(tester, harness: harness);

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
        final harness = E2ERuntimeHarness();
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

        await pumpE2EApp(tester, harness: harness);

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

        // Paginate catalog apps up to the 100-item bound
        for (var page = 0; page < 3; page++) {
          final loadMore = find.byKey(
            const ValueKey('ecosystem-apps-load-more'),
          );
          await tester.ensureVisible(loadMore);
          await tester.tap(loadMore);
          await tester.pumpAndSettle();
        }

        expect(find.text('Apps (100)'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('ecosystem-apps-bound-notice')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('ecosystem-apps-load-more')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'fails closed visibly when backend does not support ecosystem catalog mutations',
      (tester) async {
        final harness = E2ERuntimeHarness()..catalogSupported = false;
        await pumpE2EApp(tester, harness: harness);

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
