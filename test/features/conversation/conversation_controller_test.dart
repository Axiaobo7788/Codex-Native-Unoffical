import 'dart:async';

import 'package:codex_native_unofficial/src/domain/model_gateway.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_gateway.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/conversation_controller.dart';
import 'package:codex_native_unofficial/src/features/settings/execution_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeTurnGateway gateway;
  late ConversationController controller;

  setUp(() {
    gateway = _FakeTurnGateway();
    final settings = ExecutionSettingsController(gateway: _FakeModelGateway());
    addTearDown(settings.dispose);
    controller = ConversationController(
      gateway: gateway,
      settings: settings,
      maxEntries: 8,
      maxEntryCharacters: 1024,
      coalesceInterval: Duration.zero,
    )..bindThread(_thread());
  });

  tearDown(() async {
    controller.dispose();
    await gateway.dispose();
  });

  test('submits user text and tracks turn lifecycle', () async {
    expect(await controller.submit('  Hello Codex  '), isTrue);

    expect(gateway.started, [('thread-1', 'Hello Codex')]);
    expect(controller.entries.single.kind, ConversationEntryKind.user);
    expect(controller.entries.single.text, 'Hello Codex');
    expect(controller.activeTurnId, 'turn-1');
    expect(controller.busy, isTrue);

    gateway.events
      ..add(const TurnStartedEvent(threadId: 'thread-1', turnId: 'turn-1'))
      ..add(
        const TurnCompletedEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          status: TurnRuntimeStatus.completed,
        ),
      );

    expect(controller.busy, isFalse);
    expect(controller.activeTurnId, isNull);
  });

  test('coalesces token deltas into one presentation update', () async {
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    for (var index = 0; index < 100; index += 1) {
      gateway.events.add(
        const AssistantTextDeltaEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'assistant-1',
          delta: 'x',
        ),
      );
    }
    expect(notifications, 0);

    await Future<void>.delayed(Duration.zero);

    expect(notifications, 1);
    expect(controller.entries.single.text, List.filled(100, 'x').join());
    expect(controller.entries.single.completed, isFalse);
  });

  test('caps assistant text and retains the newest portion', () async {
    gateway.events.add(
      AssistantMessageEvent(
        threadId: 'thread-1',
        turnId: 'turn-1',
        itemId: 'assistant-large',
        text: List.filled(2000, 'a').join(),
        completed: true,
      ),
    );

    final entry = controller.entries.single;
    expect(entry.text.length, 1024);
    expect(entry.text, startsWith('[Earlier text omitted]'));
    expect(entry.completed, isTrue);
  });

  test('stores activity summaries and can interrupt the active turn', () async {
    await controller.submit('Run it');
    gateway.events
      ..add(const TurnStartedEvent(threadId: 'thread-1', turnId: 'turn-1'))
      ..add(
        const ActivityEvent(
          threadId: 'thread-1',
          turnId: 'turn-1',
          itemId: 'command-1',
          summary: 'Command: flutter test',
          status: 'inProgress',
          completed: false,
        ),
      );

    await controller.interrupt();

    expect(controller.entries.last.kind, ConversationEntryKind.activity);
    expect(controller.entries.last.text, 'Command: flutter test');
    expect(gateway.interrupted, [('thread-1', 'turn-1')]);
  });

  test('does not interrupt before turn/started is observed', () async {
    await controller.submit('Run it');

    expect(controller.busy, isTrue);
    expect(controller.canInterrupt, isFalse);
    await controller.interrupt();

    expect(gateway.interrupted, isEmpty);
  });

  test('ignores events for inactive threads and clears on thread switch', () {
    gateway.events.add(
      const AssistantMessageEvent(
        threadId: 'another-thread',
        turnId: 'turn-2',
        itemId: 'assistant-2',
        text: 'Not visible',
        completed: true,
      ),
    );
    expect(controller.entries, isEmpty);

    controller.bindThread(_thread(id: 'thread-2'));
    expect(controller.entries, isEmpty);
    expect(controller.thread?.id, 'thread-2');
  });
}

class _FakeTurnGateway implements TurnGateway {
  final StreamController<TurnEvent> events =
      StreamController<TurnEvent>.broadcast(sync: true);
  final List<(String, String)> started = [];
  final List<(String, String)> interrupted = [];

  @override
  Stream<TurnEvent> get turnEvents => events.stream;

  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) async {
    started.add((options.threadId, options.text));
    return const TurnHandle(id: 'turn-1', status: TurnRuntimeStatus.inProgress);
  }

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    interrupted.add((threadId, turnId));
  }

  Future<void> dispose() => events.close();
}

class _FakeModelGateway implements ModelGateway {
  @override
  Future<ModelPage> listModels(ModelListQuery query) async =>
      const ModelPage(models: [], nextCursor: null);
}

ThreadSummary _thread({String id = 'thread-1'}) => ThreadSummary(
  id: id,
  sessionId: 'session-$id',
  preview: 'Test thread',
  cwd: '/workspace',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  status: ThreadRuntimeStatus.idle,
  ephemeral: false,
);
