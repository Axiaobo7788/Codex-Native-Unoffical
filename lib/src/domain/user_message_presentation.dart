const int maxUserAttachments = 16;
const int maxAttachmentLabelLength = 160;
const int maxAttachmentPathLength = 1024;
const int maxAttachmentPreviewLength = 2048;
const int maxEnvelopeHeaderScanCharacters = 16 * 1024;

enum UserAttachmentKind { pastedText, file, ideContext, image, skill, mention }

class UserAttachment {
  const UserAttachment({
    required this.kind,
    required this.label,
    this.path,
    this.preview,
  });

  final UserAttachmentKind kind;
  final String label;
  final String? path;
  final String? preview;
}

class UserMessagePresentation {
  const UserMessagePresentation({
    required this.bodyText,
    required this.attachments,
    required this.hadStructuredEnvelope,
  });

  final String bodyText;
  final List<UserAttachment> attachments;
  final bool hadStructuredEnvelope;
}

final _envelopePrefixPattern = RegExp(
  r'^# (?:Files pasted by the user|Files mentioned by the user|Context from my IDE setup):[ \t]*(?:\r?\n|$)',
);
final _namedEntryPattern = RegExp(r'^##\s+([^"\r\n][^:\r\n]*):\s*([^\r\n]+)$');

UserAttachment normalizeUserAttachment(UserAttachment attachment) {
  final rawPath = attachment.path?.trim();
  final normalizedPath = (rawPath == null || rawPath.isEmpty)
      ? null
      : _truncate(rawPath, maxAttachmentPathLength);
  final rawPreview = attachment.preview?.trim();
  final normalizedPreview = (rawPreview == null || rawPreview.isEmpty)
      ? null
      : _truncate(rawPreview, maxAttachmentPreviewLength);
  final rawLabel = attachment.label.trim();
  final fallbackSourcePath = (rawPath == null || rawPath.isEmpty)
      ? null
      : _truncate(rawPath, 4096);
  final fallbackLabel = fallbackSourcePath != null
      ? _basename(fallbackSourcePath)
      : _defaultAttachmentLabel(attachment.kind);
  final effectiveLabel = rawLabel.isEmpty ? fallbackLabel : rawLabel;
  return UserAttachment(
    kind: attachment.kind,
    label: _truncate(
      effectiveLabel.isEmpty
          ? _defaultAttachmentLabel(attachment.kind)
          : effectiveLabel,
      maxAttachmentLabelLength,
    ),
    path: normalizedPath,
    preview: normalizedPreview,
  );
}

List<UserAttachment> normalizeUserAttachments(
  Iterable<UserAttachment> attachments,
) {
  final result = <UserAttachment>[];
  final seenAttachmentKeys = <String>{};
  for (final candidate in attachments) {
    if (result.length >= maxUserAttachments) {
      break;
    }
    final normalized = normalizeUserAttachment(candidate);
    final dedupPath = _dedupPathFor(candidate.path);
    final dedupKey = dedupPath != null
        ? '${normalized.kind.name}|path:$dedupPath'
        : '${normalized.kind.name}|label:${normalized.label.toLowerCase()}';
    if (seenAttachmentKeys.add(dedupKey)) {
      result.add(normalized);
    }
  }
  return result.isEmpty ? const [] : List.unmodifiable(result);
}

UserMessagePresentation parseUserMessagePresentation(
  String rawText, {
  List<UserAttachment> attachments = const [],
}) {
  final resultAttachments = <UserAttachment>[];
  final structuredPaths = <String>{};
  final seenAttachmentKeys = <String>{};

  void addNormalizedAttachment(
    UserAttachment candidate, {
    required bool isStructured,
  }) {
    if (resultAttachments.length >= maxUserAttachments) {
      return;
    }
    final normalized = normalizeUserAttachment(candidate);
    final dedupPath = _dedupPathFor(candidate.path);
    final normalizedLabel = normalized.label.toLowerCase();

    if (!isStructured &&
        dedupPath != null &&
        structuredPaths.contains(dedupPath)) {
      return;
    }

    final dedupKey = dedupPath != null
        ? '${normalized.kind.name}|path:$dedupPath'
        : '${normalized.kind.name}|label:$normalizedLabel';
    if (!seenAttachmentKeys.add(dedupKey)) {
      return;
    }
    if (isStructured && dedupPath != null) {
      structuredPaths.add(dedupPath);
    }
    resultAttachments.add(normalized);
  }

  for (final attachment in attachments) {
    addNormalizedAttachment(attachment, isStructured: true);
  }

  final trimmed = rawText.trimLeft();
  if (!_envelopePrefixPattern.hasMatch(trimmed)) {
    return UserMessagePresentation(
      bodyText: _cleanUserMessageText(rawText),
      attachments: List.unmodifiable(resultAttachments),
      hadStructuredEnvelope: false,
    );
  }

  final parsedEnvelope = _parseLegacyEnvelope(trimmed);
  if (parsedEnvelope == null) {
    return UserMessagePresentation(
      bodyText: _cleanUserMessageText(rawText),
      attachments: List.unmodifiable(resultAttachments),
      hadStructuredEnvelope: false,
    );
  }

  for (final attachment in parsedEnvelope.attachments) {
    addNormalizedAttachment(attachment, isStructured: false);
  }

  var bodyText = parsedEnvelope.requestText;
  if (bodyText.isEmpty && parsedEnvelope.pastedPreviews.isNotEmpty) {
    bodyText = parsedEnvelope.pastedPreviews.join('\n\n');
  }
  if (bodyText.isEmpty && parsedEnvelope.attachments.isNotEmpty) {
    final first = normalizeUserAttachment(parsedEnvelope.attachments.first);
    bodyText = first.preview ?? first.label;
  }
  if (bodyText.isEmpty && resultAttachments.isNotEmpty) {
    bodyText = resultAttachments.first.preview ?? resultAttachments.first.label;
  }

  return UserMessagePresentation(
    bodyText: _cleanUserMessageText(bodyText),
    attachments: List.unmodifiable(resultAttachments),
    hadStructuredEnvelope: true,
  );
}

class _ParsedLegacyEnvelope {
  const _ParsedLegacyEnvelope({
    required this.attachments,
    required this.pastedPreviews,
    required this.requestText,
  });

  final List<UserAttachment> attachments;
  final List<String> pastedPreviews;
  final String requestText;
}

_ParsedLegacyEnvelope? _parseLegacyEnvelope(String trimmed) {
  final scanLimit = trimmed.length <= maxEnvelopeHeaderScanCharacters
      ? trimmed.length
      : maxEnvelopeHeaderScanCharacters;
  final extractedFromEnvelope = <UserAttachment>[];
  final pastedPreviews = <String>[];

  String? currentSection;
  String? ideActiveFile;
  var ideOpenTabCount = 0;
  final ideTabLines = <String>[];
  int? delimiterEnd;

  void flushIdeSection() {
    if (currentSection != 'ide') {
      return;
    }
    if (ideActiveFile != null) {
      extractedFromEnvelope.add(
        UserAttachment(
          kind: UserAttachmentKind.ideContext,
          label: _basename(ideActiveFile!),
          path: ideActiveFile,
          preview: ideOpenTabCount > 0
              ? 'Active file: $ideActiveFile\nOpen tabs: $ideOpenTabCount'
              : 'Active file: $ideActiveFile',
        ),
      );
    } else if (ideOpenTabCount > 0) {
      extractedFromEnvelope.add(
        UserAttachment(
          kind: UserAttachmentKind.ideContext,
          label: '$ideOpenTabCount IDE tab${ideOpenTabCount == 1 ? '' : 's'}',
          preview: ideTabLines.join('\n'),
        ),
      );
    }
    ideActiveFile = null;
    ideOpenTabCount = 0;
    ideTabLines.clear();
  }

  var offset = 0;
  var reachedScanLimitWithValidEntries = false;
  while (offset < scanLimit) {
    final rawLineEnd = trimmed.indexOf('\n', offset);
    final lineEnd = rawLineEnd == -1 ? trimmed.length : rawLineEnd;
    if (lineEnd > scanLimit && rawLineEnd != -1) {
      reachedScanLimitWithValidEntries = extractedFromEnvelope.isNotEmpty;
      break;
    }
    final effectiveLineEnd = lineEnd <= scanLimit ? lineEnd : scanLimit;
    final line = trimmed
        .substring(offset, effectiveLineEnd)
        .replaceAll('\r', '');
    final trimmedLine = line.trim();
    final rightTrimmedLine = line.trimRight();

    if (trimmedLine.isEmpty) {
      offset = effectiveLineEnd + 1;
      continue;
    }

    if (rightTrimmedLine == '# Context from my IDE setup:') {
      flushIdeSection();
      currentSection = 'ide';
      offset = effectiveLineEnd + 1;
      continue;
    }
    if (rightTrimmedLine == '# Files pasted by the user:') {
      flushIdeSection();
      currentSection = 'pasted';
      offset = effectiveLineEnd + 1;
      continue;
    }
    if (rightTrimmedLine == '# Files mentioned by the user:') {
      flushIdeSection();
      currentSection = 'mentioned';
      offset = effectiveLineEnd + 1;
      continue;
    }

    if (rightTrimmedLine == '## My request:' ||
        rightTrimmedLine == '## My request for Codex:') {
      flushIdeSection();
      delimiterEnd = effectiveLineEnd < trimmed.length
          ? effectiveLineEnd + 1
          : trimmed.length;
      break;
    }

    if (currentSection == null) {
      return null;
    }

    if (currentSection == 'ide') {
      if (trimmedLine.startsWith('## Active file:')) {
        final candidate = trimmedLine
            .substring('## Active file:'.length)
            .trim();
        if (candidate.isNotEmpty && candidate.toLowerCase() != 'none') {
          ideActiveFile = candidate;
        }
        offset = effectiveLineEnd + 1;
        continue;
      }
      if (trimmedLine == '## Open tabs:' ||
          trimmedLine.startsWith('## Open tabs:')) {
        offset = effectiveLineEnd + 1;
        continue;
      }
      if (trimmedLine.startsWith('- ')) {
        final tab = trimmedLine.substring(2).trim();
        if (tab.isNotEmpty) {
          ideOpenTabCount += 1;
          ideTabLines.add(trimmedLine);
          offset = effectiveLineEnd + 1;
          continue;
        }
      }
      return null;
    }

    if (currentSection == 'pasted') {
      if (trimmedLine == "Pasted text contains the user's request.") {
        offset = effectiveLineEnd + 1;
        continue;
      }
      if (line.startsWith('## "')) {
        final quoted = _consumeQuotedPastedEntry(
          trimmed,
          startOffset: offset,
          scanLimit: scanLimit,
        );
        if (quoted == null) {
          return null;
        }
        if (quoted.preview.isNotEmpty) {
          pastedPreviews.add(
            _truncate(quoted.preview, maxAttachmentPreviewLength),
          );
        }
        final fileName = _basename(quoted.path);
        extractedFromEnvelope.add(
          UserAttachment(
            kind: UserAttachmentKind.pastedText,
            label: fileName.isEmpty ? 'Pasted text' : 'Pasted · $fileName',
            path: quoted.path.isEmpty ? null : quoted.path,
            preview: quoted.preview.isEmpty ? null : quoted.preview,
          ),
        );
        offset = quoted.nextOffset;
        continue;
      }
      final match = _namedEntryPattern.firstMatch(line);
      if (match != null) {
        final label = (match.group(1) ?? '').trim();
        final path = (match.group(2) ?? '').trim();
        if (label.isEmpty || path.isEmpty) {
          return null;
        }
        extractedFromEnvelope.add(
          UserAttachment(
            kind: UserAttachmentKind.pastedText,
            label: label,
            path: path,
          ),
        );
        offset = effectiveLineEnd + 1;
        continue;
      }
      return null;
    }

    if (currentSection == 'mentioned') {
      final match = _namedEntryPattern.firstMatch(line);
      if (match != null) {
        final label = (match.group(1) ?? '').trim();
        final path = (match.group(2) ?? '').trim();
        if (label.isEmpty || path.isEmpty) {
          return null;
        }
        extractedFromEnvelope.add(
          UserAttachment(
            kind: UserAttachmentKind.file,
            label: label,
            path: path,
          ),
        );
        offset = effectiveLineEnd + 1;
        continue;
      }
      return null;
    }

    return null;
  }

  flushIdeSection();
  if (delimiterEnd == null &&
      (offset >= scanLimit || reachedScanLimitWithValidEntries) &&
      extractedFromEnvelope.isNotEmpty) {
    delimiterEnd = _findTopLevelRequestDelimiterEnd(
      trimmed,
      startOffset: offset,
    );
  }
  if (delimiterEnd == null || extractedFromEnvelope.isEmpty) {
    return null;
  }

  return _ParsedLegacyEnvelope(
    attachments: extractedFromEnvelope,
    pastedPreviews: pastedPreviews,
    requestText: trimmed.substring(delimiterEnd).trim(),
  );
}

int? _findTopLevelRequestDelimiterEnd(String text, {required int startOffset}) {
  const maxDelimiterSearchChars = 128 * 1024;
  final limit = text.length <= maxDelimiterSearchChars
      ? text.length
      : maxDelimiterSearchChars;
  var cursor = startOffset;
  if (cursor > 0 && text[cursor - 1] != '\n') {
    final nextNewline = text.indexOf('\n', cursor);
    if (nextNewline == -1 || nextNewline >= limit) {
      return null;
    }
    cursor = nextNewline + 1;
  }
  while (cursor < limit) {
    final rawLineEnd = text.indexOf('\n', cursor);
    final lineEnd = rawLineEnd == -1 ? text.length : rawLineEnd;
    if (lineEnd > limit && rawLineEnd != -1) {
      return null;
    }
    final effectiveLineEnd = lineEnd <= limit ? lineEnd : limit;
    final line = text.substring(cursor, effectiveLineEnd).replaceAll('\r', '');
    final trimmedLine = line.trim();
    final rightTrimmed = line.trimRight();
    if (trimmedLine.isEmpty ||
        trimmedLine == "Pasted text contains the user's request." ||
        rightTrimmed == '# Context from my IDE setup:' ||
        rightTrimmed == '# Files pasted by the user:' ||
        rightTrimmed == '# Files mentioned by the user:' ||
        trimmedLine.startsWith('- ')) {
      cursor = effectiveLineEnd + 1;
      continue;
    }
    if (rightTrimmed == '## My request:' ||
        rightTrimmed == '## My request for Codex:') {
      return effectiveLineEnd < text.length
          ? effectiveLineEnd + 1
          : text.length;
    }
    if (!line.startsWith('## ')) {
      return null;
    }
    cursor = effectiveLineEnd + 1;
  }
  return null;
}

({String preview, String path, int nextOffset})? _consumeQuotedPastedEntry(
  String text, {
  required int startOffset,
  required int scanLimit,
}) {
  final previewStart = startOffset + 4; // after `## "`
  var searchFrom = previewStart;
  while (searchFrom < scanLimit) {
    final closeQuote = text.indexOf('": ', searchFrom);
    if (closeQuote == -1 || closeQuote >= scanLimit) {
      return null;
    }
    final rawLineEnd = text.indexOf('\n', closeQuote + 3);
    final lineEnd = rawLineEnd == -1 ? text.length : rawLineEnd;
    if (lineEnd <= scanLimit) {
      final path = text
          .substring(closeQuote + 3, lineEnd)
          .replaceAll('\r', '')
          .trim();
      final nextOffset = lineEnd < text.length ? lineEnd + 1 : text.length;
      if (path.isNotEmpty &&
          _isFollowedByEnvelopeBoundary(
            text,
            offset: nextOffset,
            scanLimit: scanLimit,
          )) {
        final preview = text.substring(previewStart, closeQuote).trim();
        return (preview: preview, path: path, nextOffset: nextOffset);
      }
    }
    searchFrom = closeQuote + 3;
  }
  return null;
}

bool _isFollowedByEnvelopeBoundary(
  String text, {
  required int offset,
  required int scanLimit,
}) {
  var cursor = offset;
  while (cursor < scanLimit) {
    final rawLineEnd = text.indexOf('\n', cursor);
    final lineEnd = rawLineEnd == -1 ? text.length : rawLineEnd;
    final effectiveLineEnd = lineEnd <= scanLimit ? lineEnd : scanLimit;
    final line = text.substring(cursor, effectiveLineEnd).replaceAll('\r', '');
    final trimmedLine = line.trim();
    final rightTrimmed = line.trimRight();
    if (trimmedLine.isEmpty) {
      cursor = effectiveLineEnd + 1;
      continue;
    }
    return trimmedLine == "Pasted text contains the user's request." ||
        rightTrimmed == '## My request:' ||
        rightTrimmed == '## My request for Codex:' ||
        rightTrimmed == '# Context from my IDE setup:' ||
        rightTrimmed == '# Files pasted by the user:' ||
        rightTrimmed == '# Files mentioned by the user:' ||
        line.startsWith('## ');
  }
  return false;
}

String _defaultAttachmentLabel(UserAttachmentKind kind) => switch (kind) {
  UserAttachmentKind.pastedText => 'Pasted text',
  UserAttachmentKind.file => 'File',
  UserAttachmentKind.ideContext => 'IDE context',
  UserAttachmentKind.image => 'Image',
  UserAttachmentKind.skill => 'Skill',
  UserAttachmentKind.mention => 'Mention',
};

String? _dedupPathFor(String? rawPath) {
  final trimmed = rawPath?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return _canonicalPath(_truncate(trimmed, 4096));
}

String? _canonicalPath(String? path) {
  if (path == null) {
    return null;
  }
  final normalized = path.trim().replaceAll(r'\', '/');
  return normalized.isEmpty ? null : normalized;
}

String _truncate(String value, int maxChars) =>
    value.length <= maxChars ? value : '${value.substring(0, maxChars)}…';

final _htmlSpaceContinuationPattern = RegExp(
  r'^[ \t]*&#x20;\\?[ \t]*$',
  multiLine: true,
);
final _trailingHtmlSpaceEscapePattern = RegExp(
  r'[ \t]*&#x20;\\[ \t]*(?=\r?\n|$)',
);

String _cleanUserMessageText(String text) {
  if (!text.contains('&#x20;')) {
    return text;
  }
  return text
      .replaceAll(_htmlSpaceContinuationPattern, '')
      .replaceAll(_trailingHtmlSpaceEscapePattern, '');
}

String _basename(String path) {
  final normalized = path.trim().replaceAll(r'\', '/');
  if (normalized.isEmpty) {
    return '';
  }
  final segments = normalized
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  return segments.isEmpty ? normalized : segments.last;
}
