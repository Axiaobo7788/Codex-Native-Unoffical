class ReasoningEffortOption {
  const ReasoningEffortOption({required this.value, required this.description});

  final String value;
  final String description;
}

class CodexModel {
  const CodexModel({
    required this.id,
    required this.model,
    required this.displayName,
    required this.description,
    required this.isDefault,
    required this.defaultReasoningEffort,
    required this.supportedReasoningEfforts,
  });

  final String id;
  final String model;
  final String displayName;
  final String description;
  final bool isDefault;
  final String defaultReasoningEffort;
  final List<ReasoningEffortOption> supportedReasoningEfforts;
}

class ModelPage {
  const ModelPage({required this.models, required this.nextCursor});

  final List<CodexModel> models;
  final String? nextCursor;
}

class ModelListQuery {
  const ModelListQuery({
    this.cursor,
    this.limit = 100,
    this.includeHidden = false,
  }) : assert(limit > 0 && limit <= 100);

  final String? cursor;
  final int limit;
  final bool includeHidden;
}
