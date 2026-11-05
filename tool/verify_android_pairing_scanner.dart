import 'dart:io';

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _gradlePropertiesPath = 'android/gradle.properties';
const _pubspecPath = 'pubspec.yaml';
const _scannerPath = 'lib/src/features/settings/remote_pairing_scanner.dart';
const _noticesPath = 'THIRD_PARTY_NOTICES.md';

void main() {
  final manifest = _read(_manifestPath);
  final gradleProperties = _read(_gradlePropertiesPath);
  final pubspec = _read(_pubspecPath);
  final scanner = _read(_scannerPath);
  final notices = _read(_noticesPath);

  if (!manifest.contains('android:name="android.permission.CAMERA"')) {
    _fail('Android manifest is missing camera permission');
  }
  for (final feature in const [
    'android.hardware.camera.any',
    'android.hardware.camera',
    'android.hardware.camera.autofocus',
  ]) {
    final optionalDeclaration = RegExp(
      '<uses-feature\\s+'
      'android:name="${RegExp.escape(feature)}"\\s+'
      'android:required="false"\\s*/>',
    );
    if (!optionalDeclaration.hasMatch(manifest)) {
      _fail('$feature must be declared explicitly optional');
    }
  }

  if (!pubspec.contains('  mobile_scanner: ^7.5.0')) {
    _fail('the reviewed mobile_scanner dependency is missing or changed');
  }
  if (!pubspec.contains('    - THIRD_PARTY_NOTICES.md')) {
    _fail('third-party terms are not packaged with the application');
  }
  final activeGradleProperties = gradleProperties
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .join('\n');
  if (RegExp(
    r'^dev\.steenbakker\.mobile_scanner\.useUnbundled\s*[:=]\s*true\s*$',
    multiLine: true,
    caseSensitive: false,
  ).hasMatch(activeGradleProperties)) {
    _fail('the scanner model must not require a first-use network download');
  }

  const scannerMarkers = <String>[
    'autoStart: false',
    'cameraResolution: const Size(1280, 720)',
    'DetectionSpeed.noDuplicates',
    'formats: const [BarcodeFormat.qrCode]',
    'returnImage: false',
    'autoZoom: false',
    'validateRemotePairingScanCandidate',
  ];
  for (final marker in scannerMarkers) {
    if (!scanner.contains(marker)) {
      _fail('scanner source no longer preserves a reviewed bounded setting');
    }
  }

  for (final marker in const [
    'mobile_scanner 7.5.0',
    'com.google.mlkit:barcode-scanning:17.3.0',
    'ML Kit Terms of Service',
    'AndroidX Camera 1.6.1',
  ]) {
    if (!notices.contains(marker)) {
      _fail('scanner dependency provenance is incomplete');
    }
  }

  stdout.writeln('ANDROID_PAIRING_SCANNER=SOURCE_PASS');
}

String _read(String path) {
  final file = File(path);
  if (!FileSystemEntity.isFileSync(path)) {
    _fail('required scanner integration file is missing: $path');
  }
  return file.readAsStringSync();
}

Never _fail(String message) {
  stderr.writeln('Android pairing-scanner validation failed: $message');
  exit(1);
}
