import 'dart:async';

import 'package:codex_native_unofficial/src/features/settings/remote_pairing_scanner.dart';
import 'package:codex_native_unofficial/src/protocol/remote_pairing_invitation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 12);

  test('accepts only a current exact canonical pairing invitation', () {
    final invitation = _invitation(
      expiresAtMs: now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    );

    expect(
      validateRemotePairingScanCandidate(invitation, now: now),
      invitation,
    );
    expect(validateRemotePairingScanCandidate(null, now: now), isNull);
    expect(validateRemotePairingScanCandidate('', now: now), isNull);
    expect(
      validateRemotePairingScanCandidate(' $invitation', now: now),
      isNull,
    );
    expect(
      validateRemotePairingScanCandidate('$invitation\n', now: now),
      isNull,
    );
    expect(
      validateRemotePairingScanCandidate(
        'codex-native-pairing-v1.invalid',
        now: now,
      ),
      isNull,
    );
    expect(
      validateRemotePairingScanCandidate(
        List.filled(remotePairingInvitationMaxCharacters + 1, 'x').join(),
        now: now,
      ),
      isNull,
    );
    expect(
      validateRemotePairingScanCandidate(
        _invitation(expiresAtMs: now.millisecondsSinceEpoch),
        now: now,
      ),
      isNull,
    );
  });

  testWidgets('invalid scans stay open and one valid scan returns once', (
    tester,
  ) async {
    final driver = _FakeScannerDriver();
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showRemotePairingScanner(
                context,
                driver: driver,
                now: () => now,
              );
            },
            child: const Text('Open scanner'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
    expect(driver.operations, ['start']);
    expect(find.text('Scan pairing QR'), findsOneWidget);

    driver.emit('codex-native-pairing-v1.invalid');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('remote-pairing-scanner-message')),
      findsOneWidget,
    );
    expect(result, isNull);

    final invitation = _invitation(
      expiresAtMs: now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    );
    driver
      ..emit(invitation)
      ..emit(invitation);
    await tester.pumpAndSettle();

    expect(result, invitation);
    expect(driver.disposeCalls, 1);
    expect(find.text('Scan pairing QR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera lifecycle operations are serialized after permission', (
    tester,
  ) async {
    final driver = _FakeScannerDriver(hasCameraPermission: true);
    await tester.pumpWidget(
      MaterialApp(
        home: RemotePairingScannerDialog(driver: driver, now: () => now),
      ),
    );
    await tester.pumpAndSettle();
    expect(driver.operations, ['start']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(driver.operations, ['start', 'stop', 'start']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(driver.operations, ['start', 'stop', 'start', 'stop']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(driver.disposeCalls, 1);
  });

  testWidgets('permission denial remains a manual-paste fallback', (
    tester,
  ) async {
    final driver = _FakeScannerDriver(
      previewFailure: RemotePairingScannerFailure.permissionDenied,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RemotePairingScannerDialog(driver: driver, now: () => now),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Camera permission was denied'), findsOneWidget);
    expect(find.text('Cancel and paste manually'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(driver.operations, ['start']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(driver.operations, ['start', 'stop']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(driver.operations, ['start', 'stop']);
  });

  testWidgets('dispose waits for an in-flight camera start', (tester) async {
    final startGate = Completer<void>();
    final driver = _FakeScannerDriver(startGate: startGate);
    await tester.pumpWidget(
      MaterialApp(
        home: RemotePairingScannerDialog(driver: driver, now: () => now),
      ),
    );
    await tester.pump();
    expect(driver.operations, ['start']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(driver.disposeCalls, 0);

    startGate.complete();
    await tester.pumpAndSettle();
    expect(driver.disposeCalls, 1);
  });
}

final class _FakeScannerDriver implements RemotePairingScannerDriver {
  _FakeScannerDriver({
    this.hasCameraPermission = false,
    this.previewFailure,
    this.startGate,
  });

  final StreamController<String?> _candidates =
      StreamController<String?>.broadcast(sync: true);
  final List<String> operations = [];
  @override
  bool hasCameraPermission;
  final RemotePairingScannerFailure? previewFailure;
  final Completer<void>? startGate;
  var disposeCalls = 0;

  @override
  Stream<String?> get candidates => _candidates.stream;

  void emit(String? value) => _candidates.add(value);

  @override
  Widget buildPreview({
    required Widget Function(
      BuildContext context,
      RemotePairingScannerFailure failure,
    )
    errorBuilder,
  }) {
    final failure = previewFailure;
    return failure == null
        ? const ColoredBox(
            key: ValueKey('fake-camera-preview'),
            color: Colors.black,
          )
        : Builder(builder: (context) => errorBuilder(context, failure));
  }

  @override
  Future<void> start() async {
    operations.add('start');
    await startGate?.future;
  }

  @override
  Future<void> stop() async {
    operations.add('stop');
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _candidates.close();
  }
}

String _invitation({required int expiresAtMs}) => RemotePairingInvitation(
  endpoint: Uri.parse('wss://host.example:9443/v1/ws'),
  code: 'abcdefghijklmnopqrstuvwx',
  expiresAtMs: expiresAtMs,
).encode();
