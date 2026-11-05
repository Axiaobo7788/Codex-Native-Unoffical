import 'dart:io';

const _gradlePath = 'android/app/build.gradle.kts';
const _ignorePath = 'android/.gitignore';
const _examplePath = 'android/key.properties.example';

const _requiredPropertyNames = <String>{
  'storeFile',
  'storePassword',
  'keyAlias',
  'keyPassword',
};

void main() {
  final gradle = _read(_gradlePath);
  final ignore = _read(_ignorePath);
  final example = _read(_examplePath);

  const requiredGradleMarkers = <String>[
    'rootProject.file("key.properties")',
    'listOf("storeFile", "storePassword", "keyAlias", "keyPassword")',
    'releaseStoreFile?.let { it.isFile && it.canRead() } == true',
    'create("release")',
    'signingConfig = signingConfigs.getByName("release")',
    'name == "preReleaseBuild"',
    'Android release signing is not configured.',
    'Android release signing is incomplete; missing properties:',
  ];
  for (final marker in requiredGradleMarkers) {
    if (!gradle.contains(marker)) {
      _fail('release-signing Gradle contract is missing a required marker');
    }
  }

  const forbiddenGradleMarkers = <String>[
    'signingConfig = signingConfigs.getByName("debug")',
    'signingConfig = signingConfigs.debug',
  ];
  for (final marker in forbiddenGradleMarkers) {
    if (gradle.contains(marker)) {
      _fail('release build must never select the debug signing configuration');
    }
  }

  final ignoreLines = ignore
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
  for (final marker in const ['key.properties', '**/*.keystore', '**/*.jks']) {
    if (!ignoreLines.contains(marker)) {
      _fail('Android private signing material is not fully ignored');
    }
  }

  final exampleValues = <String, String>{};
  for (final rawLine in example.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final separator = line.indexOf('=');
    if (separator <= 0) {
      _fail('signing example contains a malformed property');
    }
    final key = line.substring(0, separator).trim();
    final value = line.substring(separator + 1).trim();
    if (exampleValues.containsKey(key) || value.isEmpty) {
      _fail('signing example contains a duplicate or empty property');
    }
    exampleValues[key] = value;
  }
  if (exampleValues.keys
          .toSet()
          .difference(_requiredPropertyNames)
          .isNotEmpty ||
      _requiredPropertyNames
          .difference(exampleValues.keys.toSet())
          .isNotEmpty) {
    _fail('signing example must contain exactly the four supported properties');
  }
  if (exampleValues['storeFile'] != '/absolute/path/to/upload-keystore.jks' ||
      exampleValues['storePassword'] != 'replace-with-store-password' ||
      exampleValues['keyAlias'] != 'replace-with-upload-key-alias' ||
      exampleValues['keyPassword'] != 'replace-with-key-password') {
    _fail('signing example must contain placeholders only');
  }

  stdout.writeln('ANDROID_RELEASE_SIGNING=SOURCE_PASS');
}

String _read(String path) {
  final file = File(path);
  if (!FileSystemEntity.isFileSync(path)) {
    _fail('required Android release-signing file is missing: $path');
  }
  return file.readAsStringSync();
}

Never _fail(String message) {
  stderr.writeln('Android release-signing validation failed: $message');
  exit(1);
}
