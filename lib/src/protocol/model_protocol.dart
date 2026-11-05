import '../domain/model_models.dart';
import 'jsonl_decoder.dart';
import 'protocol_models.dart';
import 'thread_protocol.dart';

final class ModelProtocolAdapter {
  const ModelProtocolAdapter({required this.request});

  final ProtocolRequest request;

  Future<ModelPage> listModels(ModelListQuery query) async {
    final response = await request('model/list', {
      if (query.cursor != null) 'cursor': query.cursor,
      'limit': query.limit,
      'includeHidden': query.includeHidden,
    });
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ProtocolViolation('model/list data must be an array.');
    }
    return ModelPage(
      models: data.map(_parseModel).toList(growable: false),
      nextCursor: _optionalString(response, 'nextCursor'),
    );
  }

  static CodexModel _parseModel(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation('Model entry must be an object.');
    }
    final efforts = value['supportedReasoningEfforts'];
    if (efforts is! List<Object?>) {
      throw const ProtocolViolation(
        'Model supportedReasoningEfforts must be an array.',
      );
    }
    return CodexModel(
      id: _requiredString(value, 'id'),
      model: _requiredString(value, 'model'),
      displayName: _requiredString(value, 'displayName'),
      description: _requiredString(value, 'description'),
      isDefault: _requiredBool(value, 'isDefault'),
      defaultReasoningEffort: _requiredString(value, 'defaultReasoningEffort'),
      supportedReasoningEfforts: efforts
          .map(_parseEffort)
          .toList(growable: false),
    );
  }

  static ReasoningEffortOption _parseEffort(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const ProtocolViolation('Reasoning effort must be an object.');
    }
    return ReasoningEffortOption(
      value: _requiredString(value, 'reasoningEffort'),
      description: _requiredString(value, 'description'),
    );
  }

  static String _requiredString(JsonObject object, String key) {
    final value = object[key];
    if (value is! String) {
      throw ProtocolViolation('Model field $key must be a string.');
    }
    return value;
  }

  static String? _optionalString(JsonObject object, String key) {
    final value = object[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ProtocolViolation('Model field $key must be a string or null.');
    }
    return value;
  }

  static bool _requiredBool(JsonObject object, String key) {
    final value = object[key];
    if (value is! bool) {
      throw ProtocolViolation('Model field $key must be a boolean.');
    }
    return value;
  }
}
