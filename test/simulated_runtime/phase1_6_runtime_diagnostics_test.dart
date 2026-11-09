import 'package:codex_native_unofficial/src/app/primitives/codex_button.dart';
import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/runtime_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

void main() {
  group('F11 Bounded Local Runtime Diagnostics simulated runtime', () {
    testWidgets(
      'renders all 6 bounded diagnostic cards in Runtime details and refreshes on account/updated and account/rateLimits/updated',
      (tester) async {
        final harness = SimulatedRuntimeHarness(
          initialThreads: [
            createTestThread(
              id: 'thread-diag-1',
              preview: 'Diagnostics verification thread',
            ),
          ],
        );

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        // Open Runtime details from the sidebar footer status button.
        await tester.tap(find.text('Connected'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('runtime-details-dialog')),
          findsOneWidget,
        );
        expect(harness.accountReadCount, 1);
        expect(harness.rateLimitsReadCount, 1);
        expect(harness.permissionProfilesListCount, 1);
        expect(harness.configReadCount, 1);
        expect(harness.configRequirementsReadCount, 1);
        expect(harness.providerCapabilitiesReadCount, 1);
        expect(harness.hooksListCount, 1);

        // Verify all 6 bounded cards are present with expected de-identified data.
        expect(
          find.byKey(const ValueKey('runtime-diagnostics-account-card')),
          findsOneWidget,
        );
        expect(find.text('dev@example.test'), findsOneWidget);
        expect(find.text('Synthetic Workspace'), findsOneWidget);

        expect(
          find.byKey(const ValueKey('runtime-diagnostics-rate-limits-card')),
          findsOneWidget,
        );
        expect(find.textContaining('42% used · 300m window'), findsOneWidget);

        final profilesCard = find.byKey(
          const ValueKey('runtime-diagnostics-permission-profiles-card'),
        );
        expect(profilesCard, findsOneWidget);
        expect(
          find.descendant(of: profilesCard, matching: find.text(':read-only')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: profilesCard, matching: find.text(':workspace')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: profilesCard,
            matching: find.text(':danger-full-access'),
          ),
          findsOneWidget,
        );

        expect(
          find.byKey(const ValueKey('runtime-diagnostics-config-card')),
          findsOneWidget,
        );
        expect(find.text('48 keys · 12 origins · 2 layers'), findsOneWidget);
        expect(find.text('Managed policy active'), findsOneWidget);

        expect(
          find.byKey(const ValueKey('runtime-diagnostics-capabilities-card')),
          findsOneWidget,
        );

        expect(
          find.byKey(const ValueKey('runtime-diagnostics-hooks-card')),
          findsOneWidget,
        );
        expect(
          find.text(
            '1 shown workspaces · 1 shown hooks · 0 shown errors · 1 shown warnings',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Command handler'), findsOneWidget);
        expect(find.textContaining('pre-tool-lint'), findsOneWidget);

        // Emit rolling account/rateLimits/updated notification -> merges in place.
        harness.emitAccountRateLimitsUpdated(
          const RateLimitBucketSnapshot(
            limitId: 'codex',
            primary: RateLimitWindowSnapshot(
              usedPercent: 88,
              windowDurationMins: 300,
              resetsAtEpochSeconds: 1790000000,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('88% used · 300m window'), findsOneWidget);
        expect(harness.rateLimitsReadCount, 1);

        // Emit account/updated notification -> updates authMode/planType and triggers targeted account + rateLimits refresh.
        harness.accountDiagnostics = harness.accountDiagnostics.copyWith(
          planType: 'pro',
        );
        harness.rateLimitsDiagnostics = RateLimitsDiagnosticsSnapshot(
          primaryBucket: const RateLimitBucketSnapshot(
            limitId: 'codex',
            limitName: 'Codex Primary',
            planType: 'pro',
            primary: RateLimitWindowSnapshot(
              usedPercent: 19,
              windowDurationMins: 300,
            ),
          ),
          ordinaryUsageAllowed: true,
        );
        harness.emitAccountUpdated(authMode: 'chatgpt', planType: 'pro');
        await tester.pumpAndSettle();

        expect(harness.accountReadCount, 2);
        expect(harness.rateLimitsReadCount, 2);
        expect(harness.configReadCount, 1);
        expect(find.text('pro'), findsWidgets);
        expect(find.textContaining('19% used · 300m window'), findsOneWidget);

        // Manual refresh button reloads all 7 diagnostic RPCs.
        await tester.tap(
          find.byKey(const ValueKey('runtime-diagnostics-refresh-button')),
        );
        await tester.pumpAndSettle();

        expect(harness.accountReadCount, 3);
        expect(harness.rateLimitsReadCount, 3);
        expect(harness.permissionProfilesListCount, 2);
        expect(harness.configReadCount, 2);
        expect(harness.configRequirementsReadCount, 2);
        expect(harness.providerCapabilitiesReadCount, 2);
        expect(harness.hooksListCount, 2);
      },
    );

    testWidgets(
      'isolates and bounds oversized partial RPC failure, clears stale error on targeted refresh, and handles stream errors cleanly',
      (tester) async {
        final oversizedTail = 'X' * 4000;
        final harness = SimulatedRuntimeHarness()
          ..accountDiagnosticsError = StateError(
            'Simulated account/read failure $oversizedTail',
          );

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(find.text('Connected'));
        await tester.pumpAndSettle();

        final errorFinder = find.byKey(
          const ValueKey('runtime-diagnostics-error'),
        );
        expect(errorFinder, findsOneWidget);
        expect(
          find.textContaining('Account: Bad state: Simulated account/read'),
          findsOneWidget,
        );
        final errorSelectable = tester.widget<SelectableText>(
          find.descendant(
            of: errorFinder,
            matching: find.byType(SelectableText),
          ),
        );
        expect(errorSelectable.data, isNotNull);
        expect(errorSelectable.data!.length, lessThanOrEqualTo(481));
        expect(errorSelectable.data!, endsWith('…'));
        expect(
          find.byKey(const ValueKey('runtime-diagnostics-account-card')),
          findsNothing,
        );
        // Other diagnostic cards still load and render cleanly.
        expect(
          find.byKey(const ValueKey('runtime-diagnostics-rate-limits-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('runtime-diagnostics-config-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('runtime-diagnostics-hooks-card')),
          findsOneWidget,
        );

        // Recover account/read and trigger a targeted refresh via account/updated:
        // stale Account error must clear and the Account card must render.
        harness.accountDiagnosticsError = null;
        harness.emitAccountUpdated(authMode: 'chatgpt', planType: 'plus');
        await tester.pumpAndSettle();

        expect(errorFinder, findsNothing);
        expect(
          find.byKey(const ValueKey('runtime-diagnostics-account-card')),
          findsOneWidget,
        );

        // Emit a malformed notification error on runtimeDiagnosticsEvents:
        // must be caught and bounded in the dialog without unhandled async exception,
        // and cleared when a valid diagnostics event arrives.
        harness.emitDiagnosticsStreamError(
          FormatException('Malformed account notification $oversizedTail'),
        );
        await tester.pumpAndSettle();

        expect(errorFinder, findsOneWidget);
        expect(
          find.textContaining(
            'Diagnostics stream: FormatException: Malformed account notification',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        harness.emitAccountRateLimitsUpdated(
          const RateLimitBucketSnapshot(
            limitId: 'codex',
            primary: RateLimitWindowSnapshot(
              usedPercent: 55,
              windowDurationMins: 300,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(errorFinder, findsNothing);
        expect(find.textContaining('55% used · 300m window'), findsOneWidget);
      },
    );

    testWidgets(
      'fails closed on read-only Remote surface without dispatching local diagnostics RPCs',
      (tester) async {
        final harness = SimulatedRuntimeHarness(
          initialSnapshot: const RuntimeSnapshot(
            state: RuntimeConnectionState.remoteReadOnly,
            message: 'Read-only Remote metadata is ready.',
          ),
        )..remoteModeOverride = true;

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is CodexIconButton &&
                widget.tooltip ==
                    'Remote connected (read-only) — runtime details',
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('runtime-details-dialog')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('runtime-diagnostics-remote-unavailable')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('runtime-diagnostics-refresh-button')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('runtime-diagnostics-account-card')),
          findsNothing,
        );
        expect(harness.accountReadCount, 0);
        expect(harness.rateLimitsReadCount, 0);
        expect(harness.permissionProfilesListCount, 0);
        expect(harness.configReadCount, 0);
        expect(harness.configRequirementsReadCount, 0);
        expect(harness.providerCapabilitiesReadCount, 0);
        expect(harness.hooksListCount, 0);
      },
    );
  });
}
