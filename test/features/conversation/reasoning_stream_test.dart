import 'dart:async';

import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/protocol/history_protocol.dart';
import 'package:codex_native_unofficial/src/domain/model_gateway.dart';
import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_gateway.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/conversation_controller.dart';
import 'package:codex_native_unofficial/src/features/settings/execution_settings_controller.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/turn_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<CodexNotification> wire;
  late ConversationController controller;
  late ExecutionSettingsController settings;

  setUp(() {
    wire = StreamController<CodexNotification>.broadcast(sync: true);
    final adapter = TurnProtocolAdapter(
      request: (method, [params = const {}]) async => const {},
      notifications: wire.stream,
    );
    settings = ExecutionSettingsController(gateway: _Models());
    controller = ConversationController(
      gateway: _Turns(adapter),
      settings: settings,
      maxEntries: 3,
      coalesceInterval: Duration.zero,
    )..bindThread(_thread('thread-1'));
  });
  tearDown(() async {
    controller.dispose();
    settings.dispose();
    await wire.close();
  });

  void delta(int index, String text, {String thread = 'thread-1'}) {
    wire.add(
      CodexNotification(
        method: 'item/reasoning/summaryTextDelta',
        params: {
          'threadId': thread,
          'turnId': 'turn-1',
          'itemId': 'reason-1',
          'summaryIndex': index,
          'delta': text,
        },
      ),
    );
  }

  void snapshot(List<String> parts, {bool completed = false}) {
    wire.add(
      CodexNotification(
        method: completed ? 'item/completed' : 'item/started',
        params: {
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'item': {'id': 'reason-1', 'type': 'reasoning', 'summary': parts},
        },
      ),
    );
  }

  test('preserves multiline reasoning beyond captions and orders summary parts', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);
    final first = '# First\n\n${'readable ' * 80}\n- preserve list';
    delta(1, 'Second paragraph with `code`.');
    delta(0, first);
    delta(0, '\n- append without losing whitespace');
    expect(controller.entries, isEmpty);
    await pumpEventQueue();
    expect(
      controller.entries.single.text,
      'Reasoning: $first\n- append without losing whitespace\n\nSecond paragraph with `code`.',
    );
    expect(controller.entries.single.reasoningParts, [
      '$first\n- append without losing whitespace',
      'Second paragraph with `code`.',
    ]);
    expect(notifications, 1);
    expect(controller.entries.single.completed, isFalse);
  });

  test('projects initial and authoritative completed reasoning snapshots', () async {
    snapshot(['# Initial\n\nSeeded content.']);
    expect(
      controller.entries.single.text,
      'Reasoning: # Initial\n\nSeeded content.',
    );
    delta(0, '\n- streamed detail');
    await pumpEventQueue();
    expect(
      controller.entries.single.text,
      contains('Seeded content.\n- streamed detail'),
    );
    snapshot([
      '# Final\n\nCorrected summary.',
      'Second summary.',
    ], completed: true);
    expect(
      controller.entries.single.text,
      'Reasoning: # Final\n\nCorrected summary.\n\nSecond summary.',
    );
    expect(controller.entries.single.completed, isTrue);
    expect(controller.entries.single.reasoningParts, [
      '# Final\n\nCorrected summary.',
      'Second summary.',
    ]);
    // Some older runtimes omit the final summary; keep the observed projection.
    snapshot([], completed: true);
    expect(controller.entries.single.text, contains('Corrected summary.'));
  });

  test(
    'bounds reasoning text and sparse parts and resets on thread change',
    () async {
      delta(0, '# Budget\n\n${'x' * (24 * 1024)}');
      for (var i = 1; i < 70; i++) {
        delta(i * 10000, 'unbounded-index-must-not-allocate-holes');
      }
      await pumpEventQueue();
      final text = controller.entries.single.text;
      expect(text, startsWith('Reasoning: # Budget\n\n'));
      expect(text.length, lessThanOrEqualTo(8192 + 'Reasoning: '.length));
      expect(text, endsWith('…'));
      controller.bindThread(_thread('thread-2'));
      delta(0, 'Fresh\n\nreasoning.', thread: 'thread-2');
      await pumpEventQueue();
      expect(controller.entries.single.text, 'Reasoning: Fresh\n\nreasoning.');
    },
  );

  for (final fromSnapshot in [false, true]) {
    test(
      'clips emoji safely at the reasoning budget (snapshot=$fromSnapshot)',
      () async {
        final source = '${'a' * 8190}😀tail';
        if (fromSnapshot) {
          snapshot([source], completed: true);
        } else {
          delta(0, source);
          await pumpEventQueue();
        }
        expect(controller.entries.single.text, 'Reasoning: ${'a' * 8190}…');
      },
    );
  }

  test('saved multipart reasoning preserves paragraph boundaries', () async {
    final adapter = HistoryProtocolAdapter(
      request: (method, [params = const {}]) async => {
        'data': [
          {
            'turnId': 'turn-1',
            'item': {
              'id': 'reason-1',
              'type': 'reasoning',
              'summary': ['Heading', 'First paragraph.\n\nSecond paragraph.'],
            },
          },
        ],
      },
    );
    final page = await adapter.listItems(
      const HistoryItemQuery(threadId: 'thread-1', turnId: 'turn-1'),
    );
    expect(
      page.items.single.text,
      'Heading\n\nFirst paragraph.\n\nSecond paragraph.',
    );
  });

  test(
    'keeps optional first-part identity and bounds sparse part storage',
    () async {
      delta(10000, 'Body without a first-part heading.');
      await pumpEventQueue();
      expect(controller.entries.single.reasoningParts, [
        '',
        'Body without a first-part heading.',
      ]);
      snapshot(['', 'Authoritative body.'], completed: true);
      expect(controller.entries.single.reasoningParts, [
        '',
        'Authoritative body.',
      ]);
      controller.clearEntries();
      for (var i = 0; i < 70; i++) {
        delta(i * 10000, 'part-$i');
      }
      await pumpEventQueue();
      expect(
        controller.entries.single.reasoningParts.length,
        lessThanOrEqualTo(32),
      );
      expect(controller.entries.single.text, endsWith('…'));
    },
  );

  test(
    'saved reasoning bounds both typed parts and text without splitting emoji',
    () async {
      final adapter = HistoryProtocolAdapter(
        maxTextCharacters: 256,
        request: (method, [params = const {}]) async => {
          'data': [
            {
              'turnId': 'turn-1',
              'item': {
                'id': 'reason-1',
                'type': 'reasoning',
                'summary': ['${'a' * 254}😀tail', 'not retained'],
              },
            },
          ],
        },
      );
      final page = await adapter.listItems(
        const HistoryItemQuery(threadId: 'thread-1', turnId: 'turn-1'),
      );
      expect(page.items.single.text, '${'a' * 254}…');
      expect(page.items.single.reasoningParts, [page.items.single.text]);
      expect(
        () => page.items.single.reasoningParts.add('mutation'),
        throwsUnsupportedError,
      );
    },
  );
}

ThreadSummary _thread(String id) => ThreadSummary(
  id: id,
  sessionId: 'session-$id',
  preview: 'Reasoning projection',
  cwd: '/workspace',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  status: ThreadRuntimeStatus.idle,
  ephemeral: false,
);

class _Models implements ModelGateway {
  @override
  Future<ModelPage> listModels(ModelListQuery query) async =>
      const ModelPage(models: [], nextCursor: null);
}

class _Turns implements TurnGateway {
  _Turns(this.adapter);
  final TurnProtocolAdapter adapter;
  @override
  Stream<TurnEvent> get turnEvents => adapter.events;
  @override
  Future<TurnHandle> startTurn(TurnStartOptions options) =>
      adapter.startTurn(options);
  @override
  Future<String> steerTurn(TurnSteerOptions options) =>
      adapter.steerTurn(options);
  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) => adapter.interruptTurn(threadId: threadId, turnId: turnId);
}
