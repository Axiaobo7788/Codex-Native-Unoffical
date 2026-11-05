import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/diff_models.dart';
import '../../domain/thread_models.dart';
import '../../domain/turn_gateway.dart';
import '../../domain/turn_models.dart';

class DiffController extends ChangeNotifier {
  DiffController({required this.gateway}) {
    _subscription = gateway.turnEvents.listen(_handleEvent);
  }

  final TurnGateway gateway;
  late final StreamSubscription<TurnEvent> _subscription;
  ThreadSummary? _thread;
  DiffSnapshot? _snapshot;
  String? _selectedPath;
  var _disposed = false;

  DiffSnapshot? get snapshot => _snapshot;
  String? get selectedPath => _selectedPath;
  DiffFile? get selectedFile {
    final path = _selectedPath;
    if (path == null) {
      return null;
    }
    return _snapshot?.files.where((file) => file.path == path).firstOrNull;
  }

  void bindThread(ThreadSummary? thread) {
    if (_thread?.id == thread?.id) {
      _thread = thread;
      return;
    }
    _thread = thread;
    _snapshot = null;
    _selectedPath = null;
    _notify();
  }

  void selectFile(String path) {
    if (!(_snapshot?.files.any((file) => file.path == path) ?? false)) {
      return;
    }
    _selectedPath = path;
    _notify();
  }

  void _handleEvent(TurnEvent event) {
    if (event is! TurnDiffUpdatedEvent || event.threadId != _thread?.id) {
      return;
    }
    _snapshot = event.snapshot;
    if (!event.snapshot.files.any((file) => file.path == _selectedPath)) {
      _selectedPath = event.snapshot.files.firstOrNull?.path;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
