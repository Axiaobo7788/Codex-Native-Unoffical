import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_projection.dart';
import 'package:codex_native_unofficial/src/transport/remote/remote_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoundedRemoteProjection', () {
    test('replaces state with a bounded authoritative snapshot', () async {
      final projection = BoundedRemoteProjection();

      await projection.replace(
        sessionId: 'session-1',
        baselineSequence: 9,
        models: ModelPage(
          models: List.generate(101, (index) => _model('model-$index')),
          nextCursor: 'models-next',
        ),
        threads: ThreadPage(
          threads: List.generate(101, (index) => _thread('thread-$index')),
          nextCursor: 'threads-next',
        ),
      );

      final snapshot = projection.snapshot!;
      expect(snapshot.sessionId, 'session-1');
      expect(snapshot.appliedSequence, 9);
      expect(snapshot.models, hasLength(100));
      expect(snapshot.threads, hasLength(100));
      expect(snapshot.nextModelCursor, 'models-next');
      expect(snapshot.nextThreadCursor, 'threads-next');
      expect(
        () => snapshot.models.add(_model('extra')),
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.threads.add(_thread('extra')),
        throwsUnsupportedError,
      );
    });

    test('applies an exact next event before advancing the cursor', () async {
      final projection = BoundedRemoteProjection();
      await projection.replace(
        sessionId: 'session-1',
        baselineSequence: 4,
        models: const ModelPage(models: [], nextCursor: null),
        threads: ThreadPage(threads: [_thread('thread-1')], nextCursor: null),
      );

      await projection.apply(
        const RemoteSequencedNotification(
          sessionId: 'session-1',
          sequence: 5,
          notification: CodexNotification(
            method: 'turn/started',
            params: {'threadId': 'thread-1'},
          ),
        ),
      );

      expect(projection.snapshot!.appliedSequence, 5);
      expect(
        projection.snapshot!.threads.single.status,
        ThreadRuntimeStatus.active,
      );
    });

    test(
      'fails closed on a gap, session mismatch, or malformed event',
      () async {
        final projection = BoundedRemoteProjection();
        await projection.replace(
          sessionId: 'session-1',
          baselineSequence: 4,
          models: const ModelPage(models: [], nextCursor: null),
          threads: ThreadPage(threads: [_thread('thread-1')], nextCursor: null),
        );

        for (final event in [
          const RemoteSequencedNotification(
            sessionId: 'session-1',
            sequence: 6,
            notification: CodexNotification(
              method: 'turn/started',
              params: {'threadId': 'thread-1'},
            ),
          ),
          const RemoteSequencedNotification(
            sessionId: 'session-2',
            sequence: 5,
            notification: CodexNotification(
              method: 'turn/started',
              params: {'threadId': 'thread-1'},
            ),
          ),
          const RemoteSequencedNotification(
            sessionId: 'session-1',
            sequence: 5,
            notification: CodexNotification(
              method: 'thread/status/changed',
              params: {'threadId': 'thread-1', 'status': 7},
            ),
          ),
        ]) {
          await expectLater(
            projection.apply(event),
            throwsA(isA<ProtocolViolation>()),
          );
          expect(projection.snapshot!.appliedSequence, 4);
        }
      },
    );
  });
}

CodexModel _model(String id) => CodexModel(
  id: id,
  model: id,
  displayName: id,
  description: 'Test model',
  isDefault: false,
  defaultReasoningEffort: 'medium',
  supportedReasoningEfforts: const [],
);

ThreadSummary _thread(String id) => ThreadSummary(
  id: id,
  sessionId: 'codex-$id',
  preview: 'Test thread',
  cwd: '/workspace',
  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
  status: ThreadRuntimeStatus.idle,
  ephemeral: false,
);
