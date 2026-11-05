import 'dart:convert';
import 'dart:io';

const _noticePath = 'licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt';
const _maximumNoticeBytes = 2 * 1024 * 1024;

Future<void> main() async {
  final notice = await _read(_noticePath);
  final noticeBytes = utf8.encode(notice);
  if (noticeBytes.isEmpty || noticeBytes.length > _maximumNoticeBytes) {
    _fail('native Host notice is empty or exceeds $_maximumNoticeBytes bytes');
  }
  _requireAll(_noticePath, notice, const [
    'Generated from Cargo.lock with cargo-about 0.9.3.',
    '- axum-server 0.8.0 - https://crates.io/crates/axum-server/0.8.0',
    'Mozilla Public License 2.0 (MPL-2.0)',
    '- option-ext 0.2.0 - https://crates.io/crates/option-ext/0.2.0',
    'Source repository: https://github.com/soc/option-ext.git',
  ]);
  for (final developmentOnly in const ['- rcgen ', '- tempfile ']) {
    if (notice.contains(developmentOnly)) {
      _fail('native Host notice includes development-only $developmentOnly');
    }
  }
  if (notice.contains('&quot;') || notice.contains(Directory.current.path)) {
    _fail('native Host notice contains escaped text or a local absolute path');
  }
  if (notice.contains('\r') ||
      notice.endsWith('\n\n') ||
      notice.split('\n').any((line) => line.trimRight() != line)) {
    _fail('native Host notice has non-canonical line endings or whitespace');
  }

  for (final cmakePath in const [
    'linux/CMakeLists.txt',
    'windows/CMakeLists.txt',
  ]) {
    _requireAll(cmakePath, await _read(cmakePath), const [
      '../licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt',
      'install(FILES "\${NATIVE_HOST_LICENSES}"',
    ]);
  }
  _requireAll(
    'macos/build_native_host.sh',
    await _read('macos/build_native_host.sh'),
    const [
      'licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt',
      '"\${resources_dir}/NATIVE_HOST_THIRD_PARTY_LICENSES.txt"',
    ],
  );
  _requireAll(
    'macos/Runner.xcodeproj/project.pbxproj',
    await _read('macos/Runner.xcodeproj/project.pbxproj'),
    const [
      r'$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/NATIVE_HOST_THIRD_PARTY_LICENSES.txt',
    ],
  );

  stdout.writeln('NATIVE_LICENSE_PACKAGING=SOURCE_PASS');
  stdout.writeln('NOTICE_BYTES=${noticeBytes.length}');
  stdout.writeln('DESKTOP_TARGETS=linux,windows,macos');
}

Future<String> _read(String path) async {
  try {
    return await File(path).readAsString();
  } on FileSystemException {
    _fail('required release-packaging file is missing or unreadable: $path');
  }
}

void _requireAll(String path, String source, List<String> fragments) {
  for (final fragment in fragments) {
    if (!source.contains(fragment)) {
      _fail('$path does not contain the required packaging contract');
    }
  }
}

Never _fail(String message) {
  stderr.writeln('NATIVE_LICENSE_PACKAGING=FAIL');
  throw StateError(message);
}
