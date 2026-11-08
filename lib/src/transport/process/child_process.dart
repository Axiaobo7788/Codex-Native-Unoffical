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
  Future<void> _writeQueue = Future<void>.value();

  @override
  int get pid => _process.pid;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> write(String value) {
    final operation = _writeQueue.then((_) async {
      _process.stdin.write(value);
      await _process.stdin.flush();
    });
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<void> closeInput() {
    final operation = _writeQueue.then((_) => _process.stdin.close());
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }

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
