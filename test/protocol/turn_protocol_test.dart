import 'dart:async';

import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/turn_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<CodexNotification> notifications;
  late List<_Request> requests;
  late Map<String, JsonObject> responses;
  late TurnProtocolAdapter adapter;

  setUp(() {
    notifications = StreamController<CodexNotification>.broadcast(sync: true);
    requests = [];
    responses = {};
    adapter = TurnProtocolAdapter(
      request: (method, [params = const {}]) async {
        requests.add(_Request(method, params));
        return responses[method] ?? const {};
      },
      notifications: notifications.stream,
    );
  });

  tearDown(() => notifications.close());

  test('starts a text turn without client prompt rewriting', () async {
    responses['turn/start'] = {
      'turn': {'id': 'turn-1', 'status': 'inProgress'},
    };

    final turn = await adapter.startTurn(
      threadId: 'thread-1',
      text: 'Do the task',
    );

    expect(turn.id, 'turn-1');
    expect(turn.status, TurnRuntimeStatus.inProgress);
    expect(requests.single.method, 'turn/start');
    expect(requests.single.params, {
      'threadId': 'thread-1',
      'input': [
        {'type': 'text', 'text': 'Do the task', 'text_elements': <Object?>[]},
      ],
    });
    expect(requests.single.params, isNot(contains('developerInstructions')));
    expect(requests.single.params, isNot(contains('model')));
  });

  test('interrupts the exact active turn', () async {
    responses['turn/interrupt'] = const {};

    await adapter.interruptTurn(threadId: 'thread-1', turnId: 'turn-1');

    expect(requests.single.method, 'turn/interrupt');
    expect(requests.single.params, {
      'threadId': 'thread-1',
      'turnId': 'turn-1',
    });
  });

  test('maps lifecycle and assistant delta notifications', () async {
    final events = <TurnEvent>[];
    final subscription = adapter.events.listen(events.add);
    addTearDown(subscription.cancel);

    notifications
      ..add(
        CodexNotification(
          method: 'turn/started',
          params: {
            'threadId': 'thread-1',
            'turn': {'id': 'turn-1'},
          },
        ),
      )
      ..add(
        const CodexNotification(
          method: 'item/agentMessage/delta',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'itemId': 'message-1',
            'delta': 'Hello',
          },
        ),
      )
      ..add(
        CodexNotification(
          method: 'item/completed',
          params: {
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'completedAtMs': 1,
            'item': {
              'type': 'agentMessage',
              'id': 'message-1',
              'text': 'Hello',
            },
          },
        ),
      )
      ..add(
        CodexNotification(
          method: 'turn/completed',
          params: {
            'threadId': 'thread-1',
            'turn': {'id': 'turn-1', 'status': 'completed', 'error': null},
          },
        ),
      );
    await pumpEventQueue();

    expect(events, hasLength(4));
    expect(events[0], isA<TurnStartedEvent>());
    expect(
      events[1],
      isA<AssistantTextDeltaEvent>().having(
        (event) => event.delta,
        'delta',
        'Hello',
      ),
    );
    expect(
      events[2],
      isA<AssistantMessageEvent>().having(
        (event) => event.completed,
        'completed',
        isTrue,
      ),
    );
    expect(
      events[3],
      isA<TurnCompletedEvent>().having(
        (event) => event.status,
        'status',
        TurnRuntimeStatus.completed,
      ),
    );
  });

  test('summarizes command activity without retaining its output', () async {
    final eventFuture = adapter.events.first;
    notifications.add(
      CodexNotification(
        method: 'item/completed',
        params: {
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'item': {
            'type': 'commandExecution',
            'id': 'command-1',
            'command': 'flutter test',
            'status': 'completed',
            'aggregatedOutput': 'MULTI_MEGABYTE_OUTPUT_MUST_NOT_BE_RETAINED',
          },
        },
      ),
    );

    final event = await eventFuture as ActivityEvent;
    expect(event.summary, 'Command: flutter test');
    expect(event.summary, isNot(contains('MULTI_MEGABYTE')));
    expect(event.status, 'completed');
  });
}

class _Request {
  const _Request(this.method, this.params);

  final String method;
  final JsonObject params;
}
