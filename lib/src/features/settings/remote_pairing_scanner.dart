import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../protocol/remote_pairing_invitation.dart';

typedef RemotePairingScannerLauncher = Future<String?> Function(
  BuildContext context,
);

enum RemotePairingScannerFailure { permissionDenied, unsupported, unavailable }

abstract interface class RemotePairingScannerDriver {
  Stream<String?> get candidates;

  bool get hasCameraPermission;

  Widget buildPreview({
    required Widget Function(
      BuildContext context,
      RemotePairingScannerFailure failure,
    )
    errorBuilder,
  });

  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}

final class MobileRemotePairingScannerDriver
    implements RemotePairingScannerDriver {
  MobileRemotePairingScannerDriver()
    : _controller = MobileScannerController(
        autoStart: false,
        cameraResolution: const Size(1280, 720),
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
        returnImage: false,
        autoZoom: false,
      ) {
    _candidates = _controller.barcodes.expand(
      (capture) => capture.barcodes
          .where((barcode) => barcode.format == BarcodeFormat.qrCode)
          .map((barcode) => barcode.rawValue),
    );
  }

  final MobileScannerController _controller;
  late final Stream<String?> _candidates;

  @override
  Stream<String?> get candidates => _candidates;

  @override
  bool get hasCameraPermission =>
      _controller.value.hasCameraPermission && _controller.value.error == null;

  @override
  Widget buildPreview({
    required Widget Function(
      BuildContext context,
      RemotePairingScannerFailure failure,
    )
    errorBuilder,
  }) => MobileScanner(
    key: const ValueKey('remote-pairing-camera-preview'),
    controller: _controller,
    useAppLifecycleState: false,
    fit: BoxFit.cover,
    tapToFocus: true,
    errorBuilder: (context, error) =>
        errorBuilder(context, switch (error.errorCode) {
          MobileScannerErrorCode.permissionDenied =>
            RemotePairingScannerFailure.permissionDenied,
          MobileScannerErrorCode.unsupported =>
            RemotePairingScannerFailure.unsupported,
          _ => RemotePairingScannerFailure.unavailable,
        }),
  );

  @override
  Future<void> start() => _controller.start();

  @override
  Future<void> stop() => _controller.stop();

  @override
  Future<void> dispose() => _controller.dispose();
}

Future<String?> showRemotePairingScanner(
  BuildContext context, {
  RemotePairingScannerDriver? driver,
  DateTime Function()? now,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (context) => RemotePairingScannerDialog(driver: driver, now: now),
);

class RemotePairingScannerDialog extends StatefulWidget {
  const RemotePairingScannerDialog({super.key, this.driver, this.now});

  final RemotePairingScannerDriver? driver;
  final DateTime Function()? now;

  @override
  State<RemotePairingScannerDialog> createState() =>
      _RemotePairingScannerDialogState();
}

class _RemotePairingScannerDialogState extends State<RemotePairingScannerDialog>
    with WidgetsBindingObserver {
  late final RemotePairingScannerDriver _driver;
  late final StreamSubscription<String?> _candidateSubscription;
  late final DateTime Function() _now;
  Future<void> _cameraOperation = Future<void>.value();
  String? _message;
  var _accepted = false;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    _driver = widget.driver ?? MobileRemotePairingScannerDriver();
    _now = widget.now ?? DateTime.now;
    _candidateSubscription = _driver.candidates.listen(
      _handleCandidate,
      onError: _handleDetectionError,
      cancelOnError: false,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleStart());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_accepted || _disposed) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        if (_driver.hasCameraPermission) {
          _scheduleStart();
        }
      case AppLifecycleState.inactive:
        // A system permission prompt makes the app inactive while the initial
        // start is waiting. Do not queue a stop behind that prompt: its resume
        // can arrive before the controller publishes permission state.
        if (_driver.hasCameraPermission) {
          _scheduleStop();
        }
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // These are real background/termination signals. Queueing stop behind
        // an in-flight start guarantees a camera acquired late is released.
        _scheduleStop();
    }
  }

  void _scheduleStart() {
    if (_accepted || _disposed) {
      return;
    }
    _enqueueCameraOperation(_driver.start);
  }

  void _scheduleStop() => _enqueueCameraOperation(_driver.stop);

  void _enqueueCameraOperation(Future<void> Function() operation) {
    _cameraOperation = _cameraOperation.catchError((Object _) {}).then((
      _,
    ) async {
      if (_disposed) {
        return;
      }
      try {
        await operation();
      } on Object {
        _setUnavailableMessage();
      }
    });
  }

  void _handleCandidate(String? candidate) {
    if (_accepted || _disposed) {
      return;
    }
    final validated = validateRemotePairingScanCandidate(
      candidate,
      now: _now(),
    );
    if (validated == null) {
      setState(() {
        _message =
            'That QR code is not a complete, current Codex Native pairing '
            'invitation. Try another code or cancel to paste it manually.';
      });
      return;
    }
    _accepted = true;
    Navigator.of(context).pop(validated);
  }

  void _handleDetectionError(Object _, StackTrace _) {
    _setUnavailableMessage();
  }

  void _setUnavailableMessage() {
    if (!mounted || _accepted || _disposed) {
      return;
    }
    setState(() {
      _message =
          'The camera scanner is unavailable. Cancel and paste the invitation '
          'manually.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan pairing QR'),
          leading: IconButton(
            key: const ValueKey('remote-pairing-scanner-close'),
            tooltip: 'Cancel and paste manually',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Point the camera at the one-use QR shown by the trusted '
                  'desktop Host. The camera image is processed on this device. '
                  'You will still review and confirm pairing afterward.',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _driver.buildPreview(
                      errorBuilder: _buildScannerError,
                    ),
                  ),
                ),
                if (_message case final message?) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    key: const ValueKey('remote-pairing-scanner-message'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('remote-pairing-scanner-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Cancel and paste manually'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerError(
    BuildContext context,
    RemotePairingScannerFailure failure,
  ) {
    final message = switch (failure) {
      RemotePairingScannerFailure.permissionDenied => 'Camera permission was denied. Cancel and paste the invitation manually.',
      RemotePairingScannerFailure.unsupported => 'No supported camera is available. Cancel and paste the invitation manually.',
      RemotePairingScannerFailure.unavailable => 'The camera scanner is unavailable. Cancel and paste the invitation manually.',
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            key: const ValueKey('remote-pairing-scanner-camera-error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_candidateSubscription.cancel());
    unawaited(
      _cameraOperation
          .catchError((Object _) {})
          .then((_) => _driver.dispose())
          .catchError((Object _) {}),
    );
    super.dispose();
  }
}

String? validateRemotePairingScanCandidate(
  String? value, {
  required DateTime now,
}) {
  if (value == null ||
      value.isEmpty ||
      value.length > remotePairingInvitationMaxCharacters ||
      value.trim() != value) {
    return null;
  }
  try {
    final invitation = RemotePairingInvitation.decode(value);
    return invitation.encode() == value &&
            invitation.expiresAtMs > now.millisecondsSinceEpoch
        ? value
        : null;
  } on FormatException {
    return null;
  }
}
