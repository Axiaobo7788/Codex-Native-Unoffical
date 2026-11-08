import '../../domain/model_models.dart';
import '../../domain/thread_models.dart';
import '../../protocol/protocol_models.dart';
import 'remote_protocol.dart';

const _maxProjectionModels = 100;
const _maxProjectionThreads = 100;
const _maxThreadIdLength = 128;
const _maxThreadNameLength = 4096;

enum RemoteProjectionApplyOutcome { applied, requiresAuthoritativeHydration }

final class RemoteProjectionSnapshot {
  const RemoteProjectionSnapshot({
    required this.sessionId,
    required this.appliedSequence,
    required this.models,
    required this.threads,
    required this.nextModelCursor,
    required this.nextThreadCursor,
  });

  final String sessionId;
  final int appliedSequence;
  final List<CodexModel> models;
  final List<ThreadSummary> threads;
  final String? nextModelCursor;
  final String? nextThreadCursor;
}

abstract interface class RemoteProjectionOwner {
  RemoteProjectionSnapshot? get snapshot;

  Future<void> replace({
    required String sessionId,
    required int baselineSequence,
    required ModelPage models,
    required ThreadPage threads,
  });

  Future<RemoteProjectionApplyOutcome> apply(RemoteSequencedNotification event);

  void invalidate();
}

final class BoundedRemoteProjection implements RemoteProjectionOwner {
  RemoteProjectionSnapshot? _snapshot;

  @override
  RemoteProjectionSnapshot? get snapshot => _snapshot;

  @override
  Future<void> replace({
    required String sessionId,
    required int baselineSequence,
    required ModelPage models,
    required ThreadPage threads,
  }) async {
    if (sessionId.isEmpty ||
        sessionId.length > _maxThreadIdLength ||
        baselineSequence < 0) {
      throw const ProtocolViolation('Invalid Remote projection baseline.');
    }
    _snapshot = RemoteProjectionSnapshot(
      sessionId: sessionId,
      appliedSequence: baselineSequence,
      models: List.unmodifiable(models.models.take(_maxProjectionModels)),
      threads: List.unmodifiable(threads.threads.take(_maxProjectionThreads)),
      nextModelCursor: models.nextCursor,
      nextThreadCursor: threads.nextCursor,
    );
  }

  @override
  Future<RemoteProjectionApplyOutcome> apply(
    RemoteSequencedNotification event,
  ) async {
    final current = _snapshot;
    if (current == null || event.sessionId != current.sessionId) {
      throw const ProtocolViolation(
        'Remote event does not match the authoritative projection.',
      );
    }
    if (event.sequence != current.appliedSequence + 1) {
      throw ProtocolViolation(
        'Remote projection sequence gap: expected '
        '${current.appliedSequence + 1}, received ${event.sequence}.',
      );
    }

    final notification = event.notification;
    if (notification.method == 'thread/unarchived' ||
        notification.method == 'thread/reverted') {
      _requiredThreadId(notification.params);
      return RemoteProjectionApplyOutcome.requiresAuthoritativeHydration;
    }

    if (notification.method == 'thread/name/updated') {
      final threadId = _requiredThreadId(notification.params);
      final threadName = _optionalThreadName(notification.params);
      _snapshot = _copySnapshot(
        current,
        appliedSequence: event.sequence,
        threads: _replaceThreadName(current.threads, threadId, threadName),
      );
      return RemoteProjectionApplyOutcome.applied;
    }

    if (notification.method == 'thread/archived') {
      final threadId = _requiredThreadId(notification.params);
      _snapshot = _copySnapshot(
        current,
        appliedSequence: event.sequence,
        threads: _removeThread(current.threads, threadId),
      );
      return RemoteProjectionApplyOutcome.applied;
    }

    final ThreadRuntimeStatus? status = switch (notification.method) {
      'turn/started' => ThreadRuntimeStatus.active,
      'turn/completed' => ThreadRuntimeStatus.idle,
      'thread/status/changed' => _threadStatus(notification.params['status']),
      'error' when notification.params['willRetry'] == false =>
        ThreadRuntimeStatus.systemError,
      'item/started' || 'item/completed' || 'error' => null,
      _ => throw ProtocolViolation(
        'Remote projection cannot apply ${notification.method}.',
      ),
    };
    final threadId = _requiredThreadId(notification.params);
    final updatedThreads = status == null
        ? current.threads
        : _replaceThreadStatus(current.threads, threadId, status);
    _snapshot = _copySnapshot(
      current,
      appliedSequence: event.sequence,
      threads: updatedThreads,
    );
    return RemoteProjectionApplyOutcome.applied;
  }

  @override
  void invalidate() {
    _snapshot = null;
  }

  static String _requiredThreadId(Map<String, Object?> params) {
    final value = params['threadId'];
    if (value is! String ||
        value.isEmpty ||
        value.length > _maxThreadIdLength) {
      throw const ProtocolViolation(
        'Remote projection event has an invalid thread ID.',
      );
    }
    return value;
  }

  static String? _optionalThreadName(Map<String, Object?> params) {
    final value = params.containsKey('threadName')
        ? params['threadName']
        : params['name'];
    if (value == null) {
      return null;
    }
    if (value is! String || value.length > _maxThreadNameLength) {
      throw const ProtocolViolation(
        'Remote thread name event has an invalid name.',
      );
    }
    return value;
  }

  static ThreadRuntimeStatus _threadStatus(Object? value) {
    final raw = switch (value) {
      String status => status,
      Map<String, Object?> status => status['type'],
      _ => null,
    };
    if (raw is! String) {
      throw const ProtocolViolation(
        'Remote thread status event has an invalid status.',
      );
    }
    return switch (raw) {
      'notLoaded' => ThreadRuntimeStatus.notLoaded,
      'idle' => ThreadRuntimeStatus.idle,
      'active' => ThreadRuntimeStatus.active,
      'systemError' => ThreadRuntimeStatus.systemError,
      _ => ThreadRuntimeStatus.unknown,
    };
  }

  static List<ThreadSummary> _replaceThreadStatus(
    List<ThreadSummary> threads,
    String threadId,
    ThreadRuntimeStatus status,
  ) {
    final index = threads.indexWhere((thread) => thread.id == threadId);
    if (index == -1 || threads[index].status == status) {
      return threads;
    }
    final old = threads[index];
    final updated = List<ThreadSummary>.of(threads);
    updated[index] = ThreadSummary(
      id: old.id,
      sessionId: old.sessionId,
      preview: old.preview,
      cwd: old.cwd,
      createdAt: old.createdAt,
      updatedAt: old.updatedAt,
      status: status,
      ephemeral: old.ephemeral,
      name: old.name,
      model: old.model,
      projectId: old.projectId,
    );
    return List.unmodifiable(updated);
  }

  static List<ThreadSummary> _replaceThreadName(
    List<ThreadSummary> threads,
    String threadId,
    String? threadName,
  ) {
    final index = threads.indexWhere((thread) => thread.id == threadId);
    if (index == -1 || threads[index].name == threadName) {
      return threads;
    }
    final updated = List<ThreadSummary>.of(threads);
    updated[index] = updated[index].copyWith(
      name: threadName,
      clearName: threadName == null,
    );
    return List.unmodifiable(updated);
  }

  static List<ThreadSummary> _removeThread(
    List<ThreadSummary> threads,
    String threadId,
  ) {
    final index = threads.indexWhere((thread) => thread.id == threadId);
    if (index == -1) {
      return threads;
    }
    final updated = List<ThreadSummary>.of(threads)..removeAt(index);
    return List.unmodifiable(updated);
  }

  static RemoteProjectionSnapshot _copySnapshot(
    RemoteProjectionSnapshot current, {
    required int appliedSequence,
    required List<ThreadSummary> threads,
  }) => RemoteProjectionSnapshot(
    sessionId: current.sessionId,
    appliedSequence: appliedSequence,
    models: current.models,
    threads: threads,
    nextModelCursor: current.nextModelCursor,
    nextThreadCursor: current.nextThreadCursor,
  );
}
