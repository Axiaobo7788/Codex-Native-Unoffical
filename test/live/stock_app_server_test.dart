import 'dart:io';

import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/child_process.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'Opt-in direct stock app-server integration',
    () {
      late Directory fixture;
      late ProcessTransport transport;

      setUp(() async {
        final executable = await const CodexExecutableLocator().locate();
        expect(
          executable,
          isNotNull,
          reason: 'Set CODEX_EXECUTABLE to stock Codex.',
        );
        fixture = await Directory.systemTemp.createTemp('native-stock-test-');
        addTearDown(() => fixture.delete(recursive: true));
        final codexHome = await Directory('${fixture.path}/codex-home')
            .create();
        transport = await ProcessTransport.start(
          executablePath: executable!,
          launcher: (executable, arguments) async => IoChildProcess(
            await Process.start(
              executable,
              arguments,
              workingDirectory: fixture.path,
              includeParentEnvironment: false,
              environment: {
                for (final key in [
                  'PATH',
                  'SystemRoot',
                  'WINDIR',
                  'TMP',
                  'TEMP',
                ])
                  key: ?Platform.environment[key],
                'CODEX_HOME': codexHome.path,
                'HOME': fixture.path,
                'USERPROFILE': fixture.path,
                'XDG_CONFIG_HOME': '${fixture.path}/.config',
                'XDG_CACHE_HOME': '${fixture.path}/.cache',
                'XDG_DATA_HOME': '${fixture.path}/.local/share',
                'XDG_STATE_HOME': '${fixture.path}/.local/state',
              },
            ),
          ),
        );
        addTearDown(transport.close);
        final init = await transport.initialize(const InitializeRequest());
        expect(init.userAgent, isNotEmpty);
      });

      test('round-trips sections in disposable storage', () async {
        final created = await transport.createThreadSection(
          const ThreadSectionCreateOptions(name: 'Review queue'),
        );
        final updated = await transport.updateThreadSection(
          ThreadSectionUpdateOptions(sectionId: created.id, name: 'Reviewed'),
        );
        expect(updated.name, 'Reviewed');
        final page = await transport.listThreadSections(
          const ThreadSectionListQuery(limit: 16),
        );
        expect(page.sections.length, lessThanOrEqualTo(16));
        expect(
          page.sections.map((section) => section.id),
          contains(created.id),
        );
        for (final section in page.sections) {
          expect(section.id, isNotEmpty);
          // The adapter allows an extra ellipsis after the bounded prefix.
          expect(section.name.length, lessThanOrEqualTo(129));
        }
        await transport.deleteThreadSection(created.id);
        final after = await transport.listThreadSections();
        expect(
          after.sections.map((section) => section.id),
          isNot(contains(created.id)),
        );
      });

      test('runs thread lifecycle in disposable storage', () async {
        final created = await transport.startThread(
          ThreadStartOptions(cwd: fixture.path),
        );
        expect(created.id, isNotEmpty);
        await transport.renameThread(
          threadId: created.id,
          name: 'Convergence Smoke Thread',
        );
        await transport.archiveThread(created.id);
        final archived = await transport.listThreads(
          const ThreadListQuery(limit: 20, archived: true),
        );
        expect(
          archived.threads.map((thread) => thread.id),
          contains(created.id),
        );
        final unarchived = await transport.unarchiveThread(created.id);
        expect(unarchived.id, created.id);
        expect(unarchived.name, 'Convergence Smoke Thread');
        await transport.deleteThread(created.id);
      });

      test(
        'reads local discovery and diagnostics in a clean profile',
        () async {
          await transport.listSkills(cwds: [fixture.path]);
          await transport.listMcpServerStatus();
          final account = await transport.readAccountDiagnostics();
          expect(account.accountType, 'unauthenticated');
          final profiles = await transport.listPermissionProfiles(
            cwd: fixture.path,
          );
          expect(
            profiles.profiles.map((profile) => profile.id),
            contains(':read-only'),
          );
          await transport.readConfigDiagnostics(
            cwd: fixture.path,
            includeLayers: true,
          );
          await transport.readConfigRequirements();
          await transport.readModelProviderCapabilities();
          await transport.listHooks(cwds: [fixture.path]);
        },
      );
    },
    skip: Platform.environment['CODEX_NATIVE_STOCK_TEST'] == '1'
        ? false
        : 'Requires an explicitly selected local stock app-server run.',
  );
}
