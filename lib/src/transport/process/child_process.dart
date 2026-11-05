import 'dart:io';

abstract interface class ChildProcess {
  int get pid;
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;

  Future<void> write(String value);
  Future<void> closeInput();
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]);
}

class IoChildProcess implements ChildProcess {
  IoChildProcess(this._process);

  final Process _process;

  @override
  int get pid => _process.pid;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> write(String value) async {
    _process.stdin.write(value);
    await _process.stdin.flush();
  }

  @override
  Future<void> closeInput() => _process.stdin.close();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) =>
      _process.kill(signal);
}

typedef ProcessLauncher = Future<ChildProcess> Function(
  String executable,
  List<String> arguments,
);

Future<ChildProcess> launchIoProcess(
  String executable,
  List<String> arguments,
) async {
  final process = await Process.start(
    executable,
    arguments,
    runInShell: false,
    mode: ProcessStartMode.normal,
  );
  return IoChildProcess(process);
}
