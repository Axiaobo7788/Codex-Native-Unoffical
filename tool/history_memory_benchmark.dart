import 'dart:io';

import 'package:codex_native_unofficial/src/domain/history_gateway.dart';
import 'package:codex_native_unofficial/src/domain/history_models.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/history_controller.dart';
import 'package:codex_native_unofficial/src/protocol/history_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'measures bounded history and discarded heavy-output working sets',
    _runBenchmark,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _runBenchmark() async {
  final rssBefore = ProcessInfo.currentRss;
  final gateway = _BenchmarkGateway();
  final controller = HistoryController(
    gateway: gateway,
    maxRetainedTurns: 100,
    maxRetainedItems: 100,
  );
  addTearDown(controller.dispose);
  await controller.bindThread(_thread());
  while (controller.canLoadOlderTurns) {
    await controller.loadOlderTurns();
  }
  final rssAfterTurns = ProcessInfo.currentRss;

  var requestSequence = 0;
  final protocol = HistoryProtocolAdapter(
    request: (_, [_ = const {}]) async {
      requestSequence += 1;
      return {
        'data': [
          {
            'turnId': 'heavy-turn',
            'item': {
              'id': 'command-$requestSequence',
              'type': 'commandExecution',
              'command': 'synthetic-heavy-output',
              'aggregatedOutput': _multiMegabyteOutput(),
              'status': 'completed',
            },
          },
        ],
        'nextCursor': null,
      };
    },
  );
  for (var index = 0; index < 10; index += 1) {
    final page = await protocol.listItems(
      const HistoryItemQuery(
        threadId: 'stress-thread',
        turnId: 'heavy-turn',
        limit: 1,
      ),
    );
    expect(page.items.single.text, 'Command: synthetic-heavy-output');
  }
  final rssAfterHeavyOutput = ProcessInfo.currentRss;

  expect(controller.turns, hasLength(100));
  expect(controller.timelineItems, hasLength(100));
  expect(gateway.calls, 50);
  stdout.writeln('HISTORY_MEMORY_BENCHMARK=PASS');
  stdout.writeln('SOURCE_TURNS=1000');
  stdout.writeln('RETAINED_TURNS=${controller.turns.length}');
  stdout.writeln('HEAVY_OUTPUT_ITERATIONS=10');
  stdout.writeln('HEAVY_OUTPUT_BYTES_PER_ITEM=${3 * 1024 * 1024}');
  stdout.writeln('RSS_BEFORE=$rssBefore');
  stdout.writeln('RSS_AFTER_TURNS=$rssAfterTurns');
  stdout.writeln('RSS_AFTER_HEAVY_OUTPUT=$rssAfterHeavyOutput');
  stdout.writeln('RSS_TURN_DELTA=${rssAfterTurns - rssBefore}');
  stdout.writeln(
    'RSS_HEAVY_OUTPUT_DELTA=${rssAfterHeavyOutput - rssAfterTurns}',
  );
}

class _BenchmarkGateway implements HistoryGateway {
  var calls = 0;

  @override
  Future<HistoryTurnPage> listHistoryTurns(HistoryTurnQuery query) async {
    calls += 1;
    final start = query.cursor == null ? 0 : int.parse(query.cursor!);
    final end = (start + query.limit).clamp(0, 1000);
    return HistoryTurnPage(
      turns: [
        for (var index = start; index < end; index += 1)
          HistoryTurn(
            id: 'turn-$index',
            status: TurnRuntimeStatus.completed,
            items: [
              HistoryItem(
                id: 'summary-$index',
                turnId: 'turn-$index',
                kind: HistoryItemKind.assistant,
                text: 'Summary $index',
              ),
            ],
          ),
      ],
      nextCursor: end < 1000 ? '$end' : null,
    );
  }

  @override
  Future<HistoryItemPage> listHistoryItems(HistoryItemQuery query) =>
      throw UnimplementedError();

  @override
  Future<List<HistoryItem>> readHistoryItems({
    required String threadId,
    required String turnId,
    required List<String> itemIds,
  }) async => const [];
}

ThreadSummary _thread() => ThreadSummary(
  id: 'stress-thread',
  sessionId: 'stress-session',
  preview: 'Stress thread',
  cwd: '/workspace',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  status: ThreadRuntimeStatus.idle,
  ephemeral: false,
);

String _multiMegabyteOutput() {
  final kibibyte = List.filled(1024, 'x').join();
  return List.filled(3 * 1024, kibibyte).join();
}
