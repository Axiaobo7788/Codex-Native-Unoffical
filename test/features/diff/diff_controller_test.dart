import 'dart:async';

import 'package:codex_native_unofficial/src/domain/diff_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_gateway.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/features/diff/diff_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracks only the active thread and selects a bounded file', () async {
    final gateway = _TurnGateway();
    final controller = DiffController(gateway: gateway)..bindThread(_thread());
    addTearDown(() async {
      controller.dispose();
      await gateway.dispose();
    });

    gateway.events.add(
      TurnDiffUpdatedEvent(snapshot: _snapshot(threadId: 'other-thread')),
    );
    expect(controller.snapshot, isNull);

    gateway.events.add(
      TurnDiffUpdatedEvent(snapshot: _snapshot(threadId: 'thread-1')),
    );
    expect(controller.snapshot?.files, hasLength(2));
    expect(controller.selectedPath, 'a.dart');

    controller.selectFile('b.dart');
    expect(controller.selectedFile?.path, 'b.dart');

    controller.bindThread(_thread(id: 'thread-2'));
    expect(controller.snapshot, isNull);
    expect(controller.selectedPath, isNull);
  });
}

class _TurnGateway implements TurnGateway {
  final StreamController<TurnEvent> events =
      StreamController<TurnEvent>.broadcast(sync: true);

  @override
  Stream<TurnEvent> get turnEvents => events.stream;

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) =>
      throw UnimplementedError();

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) => throw UnimplementedError();

  Future<void> dispose() => events.close();
}

DiffSnapshot _snapshot({required String threadId}) => DiffSnapshot(
  threadId: threadId,
  turnId: 'turn-1',
  files: const [
    DiffFile(
      path: 'a.dart',
      additions: 1,
      deletions: 0,
      lines: ['+a'],
      truncated: false,
    ),
    DiffFile(
      path: 'b.dart',
      additions: 0,
      deletions: 1,
      lines: ['-b'],
      truncated: false,
    ),
  ],
  additions: 1,
  deletions: 1,
  truncated: false,
);

ThreadSummary _thread({String id = 'thread-1'}) => ThreadSummary(
  id: id,
  sessionId: 'session-$id',
  preview: 'Thread',
  cwd: '/workspace',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  status: ThreadRuntimeStatus.idle,
  ephemeral: false,
);
