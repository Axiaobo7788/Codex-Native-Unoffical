import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../domain/thread_models.dart';
import '../../domain/turn_gateway.dart';
import '../../domain/turn_models.dart';

enum ConversationEntryKind { user, assistant, activity, error }

class ConversationEntry {
  const ConversationEntry({
    required this.id,
    required this.kind,
    required this.text,
    required this.completed,
    this.status,
  });

  final String id;
  final ConversationEntryKind kind;
  final String text;
  final bool completed;
  final String? status;

  ConversationEntry copyWith({String? text, bool? completed, String? status}) =>
      ConversationEntry(
        id: id,
        kind: kind,
        text: text ?? this.text,
        completed: completed ?? this.completed,
        status: status ?? this.status,
      );
}

class ConversationController extends ChangeNotifier {
  ConversationController({
    required this.gateway,
    this.maxEntries = 200,
    this.maxEntryCharacters = 64 * 1024,
    this.maxPendingDeltaItems = 16,
    this.coalesceInterval = const Duration(milliseconds: 50),
  }) : assert(maxEntries > 0),
       assert(maxEntryCharacters >= 1024),
       assert(maxPendingDeltaItems > 0) {
    _eventSubscription = gateway.turnEvents.listen(
      _handleEvent,
      onError: _handleStreamError,
    );
  }

  static const _omittedPrefix = '[Earlier text omitted]\n';

  final TurnGateway gateway;
  final int maxEntries;
  final int maxEntryCharacters;
  final int maxPendingDeltaItems;
  final Duration coalesceInterval;
  final List<ConversationEntry> _entries = [];
  final LinkedHashMap<String, StringBuffer> _deltaBuffers = LinkedHashMap();
  late final StreamSubscription<TurnEvent> _eventSubscription;
  Timer? _flushTimer;
  ThreadSummary? _thread;
  String? _activeTurnId;
  var _busy = false;
  var _interruptReady = false;
  var _disposed = false;
  var _localEntrySequence = 0;

  List<ConversationEntry> get entries => List.unmodifiable(_entries);
  ThreadSummary? get thread => _thread;
  String? get activeTurnId => _activeTurnId;
  bool get busy => _busy;
  bool get canInterrupt => _busy && _interruptReady;

  void bindThread(ThreadSummary? thread) {
    if (_thread?.id == thread?.id) {
      _thread = thread;
      return;
    }
    _flushTimer?.cancel();
    _flushTimer = null;
    _deltaBuffers.clear();
    _entries.clear();
    _thread = thread;
    _activeTurnId = null;
    _busy = false;
    _interruptReady = false;
    _notify();
  }

  Future<bool> submit(String text) async {
    final currentThread = _thread;
    final trimmed = text.trim();
    if (currentThread == null || trimmed.isEmpty || _busy) {
      return false;
    }

    _busy = true;
    _append(
      ConversationEntry(
        id: 'local-user-${_localEntrySequence++}',
        kind: ConversationEntryKind.user,
        text: _bounded(trimmed),
        completed: true,
      ),
    );
    _notify();

    try {
      final turn = await gateway.startTurn(
        threadId: currentThread.id,
        text: trimmed,
      );
      if (_disposed || _thread?.id != currentThread.id) {
        return true;
      }
      _activeTurnId ??= turn.id;
      _busy = turn.status == TurnRuntimeStatus.inProgress;
      _notify();
      return true;
    } catch (error) {
      if (!_disposed && _thread?.id == currentThread.id) {
        _busy = false;
        _interruptReady = false;
        _activeTurnId = null;
        _appendError(error.toString());
        _notify();
      }
      return false;
    }
  }

  Future<void> interrupt() async {
    final currentThread = _thread;
    final turnId = _activeTurnId;
    if (currentThread == null || turnId == null || !canInterrupt) {
      return;
    }
    try {
      await gateway.interruptTurn(threadId: currentThread.id, turnId: turnId);
    } catch (error) {
      _appendError(error.toString());
      _notify();
    }
  }

  void _handleEvent(TurnEvent event) {
    if (_disposed || event.threadId != _thread?.id) {
      return;
    }
    switch (event) {
      case TurnStartedEvent():
        _activeTurnId = event.turnId;
        _busy = true;
        _interruptReady = true;
        _notify();
      case TurnCompletedEvent():
        _flushDeltas();
        _activeTurnId = null;
        _busy = false;
        _interruptReady = false;
        if (event.errorMessage case final message?) {
          _appendError(message);
        } else if (event.status == TurnRuntimeStatus.interrupted) {
          _appendError('Turn interrupted.');
        }
        _notify();
      case AssistantTextDeltaEvent():
        _bufferDelta(event.itemId, event.delta);
      case AssistantMessageEvent():
        _completeAssistantMessage(event);
      case ActivityEvent():
        _upsert(
          ConversationEntry(
            id: event.itemId,
            kind: ConversationEntryKind.activity,
            text: _bounded(event.summary),
            completed: event.completed,
            status: event.status,
          ),
        );
        _notify();
      case TurnErrorEvent():
        _appendError(
          event.willRetry ? '${event.message} (retrying)' : event.message,
        );
        _notify();
    }
  }

  void _bufferDelta(String itemId, String delta) {
    var buffer = _deltaBuffers[itemId];
    if (buffer == null) {
      if (_deltaBuffers.length >= maxPendingDeltaItems) {
        final oldestId = _deltaBuffers.keys.first;
        _flushDelta(oldestId, _deltaBuffers.remove(oldestId)!);
      }
      buffer = StringBuffer();
      _deltaBuffers[itemId] = buffer;
    }
    buffer.write(delta);
    _flushTimer ??= Timer(coalesceInterval, _flushDeltas);
  }

  void _completeAssistantMessage(AssistantMessageEvent event) {
    final buffered = _deltaBuffers.remove(event.itemId);
    if (buffered != null) {
      _flushDelta(event.itemId, buffered);
    }
    final currentIndex = _entries.indexWhere(
      (entry) => entry.id == event.itemId,
    );
    final currentText = currentIndex == -1 ? '' : _entries[currentIndex].text;
    _upsert(
      ConversationEntry(
        id: event.itemId,
        kind: ConversationEntryKind.assistant,
        text: _bounded(event.text.isEmpty ? currentText : event.text),
        completed: event.completed,
      ),
    );
    if (_deltaBuffers.isEmpty) {
      _flushTimer?.cancel();
      _flushTimer = null;
    }
    _notify();
  }

  void _flushDeltas() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_deltaBuffers.isEmpty) {
      return;
    }
    final buffered = Map<String, StringBuffer>.from(_deltaBuffers);
    _deltaBuffers.clear();
    for (final entry in buffered.entries) {
      _flushDelta(entry.key, entry.value);
    }
    _notify();
  }

  void _flushDelta(String itemId, StringBuffer buffer) {
    final delta = buffer.toString();
    final index = _entries.indexWhere((entry) => entry.id == itemId);
    if (index == -1) {
      _append(
        ConversationEntry(
          id: itemId,
          kind: ConversationEntryKind.assistant,
          text: _bounded(delta),
          completed: false,
        ),
      );
      return;
    }
    final existing = _entries[index];
    _entries[index] = existing.copyWith(
      text: _bounded('${existing.text}$delta'),
      completed: false,
    );
  }

  void _upsert(ConversationEntry entry) {
    final index = _entries.indexWhere((candidate) => candidate.id == entry.id);
    if (index == -1) {
      _append(entry);
    } else {
      _entries[index] = entry;
    }
  }

  void _appendError(String message) {
    _append(
      ConversationEntry(
        id: 'local-error-${_localEntrySequence++}',
        kind: ConversationEntryKind.error,
        text: _bounded(message),
        completed: true,
      ),
    );
  }

  void _append(ConversationEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  String _bounded(String value) {
    if (value.length <= maxEntryCharacters) {
      return value;
    }
    final retained = maxEntryCharacters - _omittedPrefix.length;
    return '$_omittedPrefix${value.substring(value.length - retained)}';
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (_disposed || _thread == null) {
      return;
    }
    _appendError('Turn protocol error: $error');
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
    _flushTimer?.cancel();
    _deltaBuffers.clear();
    unawaited(_eventSubscription.cancel());
    super.dispose();
  }
}
