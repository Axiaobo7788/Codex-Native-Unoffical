import 'package:codex_native_unofficial/src/domain/model_models.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/model_protocol.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'lists typed visible models with advertised reasoning efforts',
    () async {
      String? method;
      JsonObject? params;
      final adapter = ModelProtocolAdapter(
        request: (requestMethod, [requestParams = const {}]) async {
          method = requestMethod;
          params = requestParams;
          return {
            'data': [
              {
                'id': 'model-id',
                'model': 'model-wire-name',
                'displayName': 'Model Name',
                'description': 'A model',
                'isDefault': true,
                'defaultReasoningEffort': 'medium',
                'supportedReasoningEfforts': [
                  {'reasoningEffort': 'low', 'description': 'Fast response'},
                  {
                    'reasoningEffort': 'medium',
                    'description': 'Balanced response',
                  },
                ],
              },
            ],
            'nextCursor': null,
          };
        },
      );

      final page = await adapter.listModels(const ModelListQuery(limit: 20));

      expect(method, 'model/list');
      expect(params, {'limit': 20, 'includeHidden': false});
      expect(page.models.single.model, 'model-wire-name');
      expect(page.models.single.isDefault, isTrue);
      expect(
        page.models.single.supportedReasoningEfforts.map((item) => item.value),
        ['low', 'medium'],
      );
    },
  );

  test('rejects malformed model entries', () async {
    final adapter = ModelProtocolAdapter(
      request: (_, [_ = const {}]) async => {
        'data': [
          {'id': 'incomplete'},
        ],
      },
    );

    await expectLater(
      adapter.listModels(const ModelListQuery()),
      throwsA(isA<ProtocolViolation>()),
    );
  });
}
