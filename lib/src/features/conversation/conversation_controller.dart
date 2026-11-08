import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../domain/thread_models.dart';
import '../../domain/turn_gateway.dart';
import '../../domain/turn_models.dart';
import '../settings/execution_settings_controller.dart';

enum ConversationEntryKind { user, assistant, activity, error }

class ConversationEntry {
  const ConversationEntry({
    required this.id,
    required this.kind,
    required this.text,
    required this.completed,
    this.turnId,
    this.status,
    this.attachments = const [],
  });

  final String id;
  final ConversationEntryKind kind;
  final String text;
  final bool completed;
  final String? turnId;
  final String? status;
  final List<UserAttachment> attachments;

  ConversationEntry copyWith({
    String? text,
    bool? completed,
    String? turnId,
    String? status,
    List<UserAttachment>? attachments,
  }) => ConversationEntry(
    id: id,
    kind: kind,
    text: text ?? this.text,
    completed: completed ?? this.completed,
    turnId: turnId ?? this.turnId,
    status: status ?? this.status,
    attachments: attachments ?? this.attachments,
  );
}

class ConversationController extends ChangeNotifier {
  ConversationController({
    required this.gateway,
    required this.settings,
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
  final ExecutionSettingsController settings;
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
  var _steering = false;
  var _interruptReady = false;
  var _disposed = false;
  var _localEntrySequence = 0;

  List<ConversationEntry> get entries => List.unmodifiable(_entries);
  ThreadSummary? get thread => _thread;
  String? get activeTurnId => _activeTurnId;
  bool get busy => _busy;
  bool get canInterrupt => _busy && _interruptReady;
  bool get canSteer =>
      _busy && _interruptReady && _activeTurnId != null && !_steering;

  void bindThread(ThreadSummary? thread) {
    if (_thread?.id == thread?.id) {
      final metadataChanged =
          _thread?.name != thread?.name ||
          _thread?.status != thread?.status ||
          _thread?.preview != thread?.preview;
      _thread = thread;
      if (metadataChanged) {
        _notify();
      }
      return;
    }
    _flushTimer?.cancel();
    _flushTimer = null;
    _deltaBuffers.clear();
    _entries.clear();
    _thread = thread;
    _activeTurnId = null;
    _busy = false;
    _steering = false;
    _interruptReady = false;
    _notify();
  }

  void clearEntries() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _deltaBuffers.clear();
    if (_entries.isEmpty && !_busy && _activeTurnId == null) {
      return;
    }
    _entries.clear();
    _activeTurnId = null;
    _busy = false;
    _steering = false;
    _interruptReady = false;
    _notify();
  }

  Future<bool> submit(
    String text, {
    List<UserAttachment> attachments = const [],
  }) async {
    if (canSteer) {
      return steer(text, attachments: attachments);
    }
    final currentThread = _thread;
    final trimmed = text.trim();
    final normalizedAttachments = normalizeUserAttachments(attachments);
    if (currentThread == null ||
        (trimmed.isEmpty && normalizedAttachments.isEmpty) ||
        _busy) {
      return false;
    }

    _busy = true;
    final entryId = 'local-user-${_localEntrySequence++}';
    _append(
      ConversationEntry(
        id: entryId,
        kind: ConversationEntryKind.user,
        text: _bounded(trimmed),
        completed: true,
        attachments: normalizedAttachments,
      ),
    );
    _notify();

    try {
      final turn = await gateway.startTurn(
        settings.turnOptions(
          threadId: currentThread.id,
          text: trimmed,
          attachments: normalizedAttachments,
        ),
      );
      if (_disposed || _thread?.id != currentThread.id) {
        return true;
      }
      _activeTurnId ??= turn.id;
      _assignTurnIdToEntry(entryId, turn.id);
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

  Future<bool> steer(
    String text, {
    List<UserAttachment> attachments = const [],
  }) async {
    final currentThread = _thread;
    final turnId = _activeTurnId;
    final trimmed = text.trim();
    final normalizedAttachments = normalizeUserAttachments(attachments);
    if (currentThread == null ||
        turnId == null ||
        !canSteer ||
        (trimmed.isEmpty && normalizedAttachments.isEmpty)) {
      return false;
    }

    _steering = true;
    final entryId = 'local-user-${_localEntrySequence++}';
    _append(
      ConversationEntry(
        id: entryId,
        kind: ConversationEntryKind.user,
        text: _bounded(trimmed),
        completed: true,
        turnId: turnId,
        attachments: normalizedAttachments,
      ),
    );
    _notify();

    try {
      final steeredTurnId = await gateway.steerTurn(
        TurnSteerOptions(
          threadId: currentThread.id,
          expectedTurnId: turnId,
          text: trimmed,
          attachments: normalizedAttachments,
        ),
      );
      if (!_disposed && _thread?.id == currentThread.id) {
        if (_busy && _activeTurnId == turnId) {
          _activeTurnId = steeredTurnId;
        }
        _assignTurnIdToEntry(entryId, steeredTurnId);
      }
      return true;
    } catch (error) {
      if (!_disposed && _thread?.id == currentThread.id) {
        _entries.removeWhere((entry) => entry.id == entryId);
        _appendError(error.toString());
      }
      return false;
    } finally {
      if (!_disposed) {
        _steering = false;
        _notify();
      }
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

  void _assignTurnIdToEntry(String entryId, String turnId) {
    if (turnId.isEmpty) {
      return;
    }
    final index = _entries.indexWhere((entry) => entry.id == entryId);
    if (index != -1) {
      _entries[index] = _entries[index].copyWith(turnId: turnId);
    }
  }

  void _assignTurnIdToLatestUnassignedUserEntry(String turnId) {
    if (turnId.isEmpty) {
      return;
    }
    for (var i = _entries.length - 1; i >= 0; i -= 1) {
      final entry = _entries[i];
      if (entry.kind == ConversationEntryKind.user) {
        if (entry.turnId == null || entry.turnId!.isEmpty) {
          _entries[i] = entry.copyWith(turnId: turnId);
        }
        break;
      }
    }
  }

  void _handleEvent(TurnEvent event) {
    if (_disposed || event.threadId != _thread?.id) {
      return;
    }
    switch (event) {
      case TurnStartedEvent():
        _activeTurnId = event.turnId;
        _assignTurnIdToLatestUnassignedUserEntry(event.turnId);
        _busy = true;
        _interruptReady = true;
        _notify();
      case TurnCompletedEvent():
        _flushDeltas();
        _activeTurnId = null;
        _busy = false;
        _steering = false;
        _interruptReady = false;
        if (event.errorMessage case final message?) {
          _appendError(
            message,
            turnId: event.turnId,
            status: event.status == TurnRuntimeStatus.interrupted
                ? 'interrupted'
                : 'failed',
          );
        } else if (event.status == TurnRuntimeStatus.interrupted) {
          _appendError(
            'Turn interrupted.',
            turnId: event.turnId,
            status: 'interrupted',
          );
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
            turnId: event.turnId,
            status: event.status,
          ),
        );
        _notify();
      case TurnErrorEvent():
        _appendError(
          event.willRetry ? '${event.message} (retrying)' : event.message,
          turnId: event.turnId,
          status: event.willRetry ? 'retrying' : 'failed',
        );
        _notify();
      case TurnDiffUpdatedEvent():
      // Diff state has its own bounded projection and view controller.
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
        turnId: event.turnId,
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
          turnId: _activeTurnId,
        ),
      );
      return;
    }
    final existing = _entries[index];
    _entries[index] = existing.copyWith(
      text: _bounded('${existing.text}$delta'),
      completed: false,
      turnId: existing.turnId ?? _activeTurnId,
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

  void _appendError(
    String message, {
    String? turnId,
    String status = 'failed',
  }) {
    _append(
      ConversationEntry(
        id: 'local-error-${_localEntrySequence++}',
        kind: ConversationEntryKind.error,
        text: _bounded(message),
        completed: true,
        turnId: turnId,
        status: status,
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
