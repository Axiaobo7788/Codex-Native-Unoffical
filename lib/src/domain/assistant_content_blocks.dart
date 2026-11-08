enum AssistantArtifactKind {
  writing,
  code,
  markdown,
  document;

  String get badgeLabel => switch (this) {
    AssistantArtifactKind.writing => 'Writing',
    AssistantArtifactKind.code => 'Code',
    AssistantArtifactKind.markdown => 'Markdown',
    AssistantArtifactKind.document => 'Artifact',
  };
}

class AssistantArtifactBlock {
  const AssistantArtifactBlock({
    required this.id,
    required this.title,
    required this.kind,
    required this.content,
    this.language,
  });

  final String id;
  final String title;
  final AssistantArtifactKind kind;
  final String content;
  final String? language;
}

class AssistantCitation {
  const AssistantCitation({required this.index, required this.label, this.url});

  final int index;
  final String label;
  final String? url;
}

class AssistantContentPresentation {
  const AssistantContentPresentation({
    required this.proseMarkdown,
    this.artifacts = const [],
    this.citations = const [],
  });

  final String proseMarkdown;
  final List<AssistantArtifactBlock> artifacts;
  final List<AssistantCitation> citations;

  bool get hasStructuredBlocks => artifacts.isNotEmpty || citations.isNotEmpty;
}

const maxAssistantArtifacts = 8;
const maxAssistantArtifactTitleLength = 160;
const maxAssistantArtifactContentLength = 8 * 1024;
const maxAssistantCitations = 16;
const maxAssistantCitationLabelLength = 160;
const maxAssistantCitationUrlLength = 1024;

final _directiveArtifactPattern = RegExp(
  r'^:::(writing|artifact)(?:\{([^\n}]*)\}|[ \t]+([^\n]*))?\r?\n([\s\S]*?)^:::[ \t]*$',
  multiLine: true,
);

final _xmlArtifactPattern = RegExp(
  r'<artifact\b([^>]*)>([\s\S]*?)<\/artifact>',
  caseSensitive: false,
);

final _fencedArtifactPattern = RegExp(
  r'^```(artifact|writing)(?::([^\n`]+))?\r?\n([\s\S]*?)^```[ \t]*$',
  multiLine: true,
);

final _attributePattern = RegExp(
  r'([a-zA-Z0-9_-]+)\s*=\s*(?:"([^"]*)"|'
  "'"
  r"([^']*)'|([^\s}]+))",
);

final _bracketCitationPattern = RegExp(
  r'【(\d+(?::\d+)?)[†:]([^】\n]{1,240})】(?:\((https?:\/\/[^\s)]+)\))?',
);

final _inlineCiteLinkPattern = RegExp(
  r'\[(?:cite|citation|source):\s*([^\]]{1,240})\](?:\(([^\s)]+)\))?',
  caseSensitive: false,
);

final _footnoteDefinitionPattern = RegExp(
  r'^\[\^?(\d+)\]:\s*(https?:\/\/\S+)(?:[ \t]+"([^"\n]+)"|[ \t]+([^\n]+))?$',
  multiLine: true,
);

final _standardFencedCodeBlockPattern = RegExp(
  r'^```(?!(?:artifact|writing)\b)[^\n`]*\r?\n[\s\S]*?^```[ \t]*$',
  multiLine: true,
);

AssistantContentPresentation parseAssistantContentPresentation(String rawText) {
  if (rawText.isEmpty) {
    return const AssistantContentPresentation(proseMarkdown: '');
  }

  final artifacts = <AssistantArtifactBlock>[];
  var working = rawText;

  String extractArtifact({
    required String kindHint,
    required String? rawAttributes,
    required String? inlineTitle,
    required String body,
    required String originalMatch,
  }) {
    if (artifacts.length >= maxAssistantArtifacts) {
      return originalMatch;
    }
    final attrs = _parseAttributes(rawAttributes ?? '');
    final titleCandidate =
        (inlineTitle?.trim().isNotEmpty == true
                ? inlineTitle!.trim()
                : (attrs['title'] ?? attrs['name'] ?? ''))
            .trim();
    final typeAttr = (attrs['type'] ?? attrs['kind'] ?? kindHint)
        .trim()
        .toLowerCase();
    final languageAttr = attrs['language'] ?? attrs['lang'];
    final kind = switch (typeAttr) {
      'writing' ||
      'prose' ||
      'email' ||
      'essay' => AssistantArtifactKind.writing,
      'code' || 'script' => AssistantArtifactKind.code,
      'markdown' || 'md' => AssistantArtifactKind.markdown,
      _ =>
        kindHint.toLowerCase() == 'writing'
            ? AssistantArtifactKind.writing
            : AssistantArtifactKind.document,
    };
    final index = artifacts.length;
    final defaultTitle = kind == AssistantArtifactKind.writing
        ? 'Writing block ${index + 1}'
        : 'Artifact ${index + 1}';
    final normalizedTitle = _boundString(
      titleCandidate.isEmpty ? defaultTitle : titleCandidate,
      maxAssistantArtifactTitleLength,
    );
    final normalizedContent = _boundString(
      body.trim(),
      maxAssistantArtifactContentLength,
    );
    artifacts.add(
      AssistantArtifactBlock(
        id: attrs['id']?.trim().isNotEmpty == true
            ? _boundString(attrs['id']!.trim(), 64)
            : 'artifact-$index',
        title: normalizedTitle,
        kind: kind,
        content: normalizedContent,
        language: languageAttr?.trim().isNotEmpty == true
            ? _boundString(languageAttr!.trim(), 32)
            : null,
      ),
    );
    return '';
  }

  if (working.contains('```artifact') || working.contains('```writing')) {
    working = working.replaceAllMapped(_fencedArtifactPattern, (match) {
      final kindHint = match.group(1) ?? 'artifact';
      final inlineTitle = match.group(2);
      final body = match.group(3) ?? '';
      return extractArtifact(
        kindHint: kindHint,
        rawAttributes: null,
        inlineTitle: inlineTitle,
        body: body,
        originalMatch: match.group(0) ?? body,
      );
    });
  }

  final protectedCodeBlocks = <String>[];
  if (working.contains('```')) {
    working = working.replaceAllMapped(_standardFencedCodeBlockPattern, (
      match,
    ) {
      final index = protectedCodeBlocks.length;
      protectedCodeBlocks.add(match.group(0) ?? '');
      return '\u0000CODEX_CODE_BLOCK_$index\u0000';
    });
  }

  if (working.contains(':::')) {
    working = working.replaceAllMapped(_directiveArtifactPattern, (match) {
      final kindHint = match.group(1) ?? 'artifact';
      final braceAttrs = match.group(2);
      final inlineTitle = match.group(3);
      final body = match.group(4) ?? '';
      return extractArtifact(
        kindHint: kindHint,
        rawAttributes: braceAttrs,
        inlineTitle: inlineTitle,
        body: body,
        originalMatch: match.group(0) ?? body,
      );
    });
  }

  if (working.contains('<artifact') || working.contains('<ARTIFACT')) {
    working = working.replaceAllMapped(_xmlArtifactPattern, (match) {
      final rawAttrs = match.group(1);
      final body = match.group(2) ?? '';
      return extractArtifact(
        kindHint: 'artifact',
        rawAttributes: rawAttrs,
        inlineTitle: null,
        body: body,
        originalMatch: match.group(0) ?? body,
      );
    });
  }

  final citations = <AssistantCitation>[];
  final seenCitationKeys = <String>{};

  ({int? index, String? normalizedUrl}) registerCitation(
    String label,
    String? url,
  ) {
    final normalizedLabel = _boundString(
      label.trim().isEmpty ? 'Source' : label.trim(),
      maxAssistantCitationLabelLength,
    );
    final normalizedUrl = _normalizeHttpUrl(url);
    final dedupKey = '${normalizedLabel.toLowerCase()}|${normalizedUrl ?? ''}';
    final existingIndex = citations.indexWhere(
      (c) => '${c.label.toLowerCase()}|${c.url ?? ''}' == dedupKey,
    );
    if (existingIndex != -1) {
      return (
        index: citations[existingIndex].index,
        normalizedUrl: citations[existingIndex].url,
      );
    }
    if (citations.length >= maxAssistantCitations) {
      return (index: null, normalizedUrl: normalizedUrl);
    }
    seenCitationKeys.add(dedupKey);
    final nextIndex = citations.length + 1;
    citations.add(
      AssistantCitation(
        index: nextIndex,
        label: normalizedLabel,
        url: normalizedUrl,
      ),
    );
    return (index: nextIndex, normalizedUrl: normalizedUrl);
  }

  if (working.contains('【')) {
    working = working.replaceAllMapped(_bracketCitationPattern, (match) {
      final rawLabel = (match.group(2) ?? 'Source').trim();
      final rawUrl = match.group(3);
      final registered = registerCitation(rawLabel, rawUrl);
      final index = registered.index;
      final url = registered.normalizedUrl;
      if (index == null) {
        return url != null ? '[$rawLabel]($url)' : '[$rawLabel]';
      }
      return url != null ? '[[$index]]($url)' : '[$index]';
    });
  }

  if (working.contains('[cite') ||
      working.contains('[Cite') ||
      working.contains('[citation') ||
      working.contains('[source:')) {
    working = working.replaceAllMapped(_inlineCiteLinkPattern, (match) {
      final rawLabel = (match.group(1) ?? 'Source').trim();
      final rawUrl = match.group(2);
      final registered = registerCitation(rawLabel, rawUrl);
      final index = registered.index;
      final url = registered.normalizedUrl;
      if (index == null) {
        return url != null ? '[$rawLabel]($url)' : '[$rawLabel]';
      }
      return url != null ? '[[$index]]($url)' : '[$index]';
    });
  }

  if (working.contains('[^') || working.contains(']: http')) {
    working = working.replaceAllMapped(_footnoteDefinitionPattern, (match) {
      final rawUrl = match.group(2);
      final quotedTitle = match.group(3);
      final trailingTitle = match.group(4);
      final label = (quotedTitle ?? trailingTitle ?? rawUrl ?? 'Source').trim();
      final registered = registerCitation(label, rawUrl);
      if (registered.index == null) {
        return match.group(0) ?? '';
      }
      return '';
    });
  }

  if (protectedCodeBlocks.isNotEmpty) {
    for (var i = 0; i < protectedCodeBlocks.length; i++) {
      working = working.replaceAll(
        '\u0000CODEX_CODE_BLOCK_$i\u0000',
        protectedCodeBlocks[i],
      );
    }
  }

  if (artifacts.isEmpty && citations.isEmpty) {
    return AssistantContentPresentation(proseMarkdown: rawText);
  }

  return AssistantContentPresentation(
    proseMarkdown: working.trim(),
    artifacts: List.unmodifiable(artifacts),
    citations: List.unmodifiable(citations),
  );
}

Map<String, String> _parseAttributes(String raw) {
  if (raw.trim().isEmpty) {
    return const {};
  }
  final result = <String, String>{};
  for (final match in _attributePattern.allMatches(raw)) {
    final key = match.group(1)?.toLowerCase();
    final value = match.group(2) ?? match.group(3) ?? match.group(4);
    if (key != null && value != null) {
      result[key] = value;
    }
  }
  return result;
}

String? _normalizeHttpUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    return null;
  }
  final trimmed = _boundString(rawUrl.trim(), maxAssistantCitationUrlLength);
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !uri.isAbsolute ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return trimmed;
}

String _boundString(String value, int maxLength) {
  if (value.length <= maxLength) {
    return value;
  }
  return '${value.substring(0, maxLength)}…';
}
