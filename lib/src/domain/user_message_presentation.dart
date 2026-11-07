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
final _requestDelimiterPattern = RegExp(
  r'^## My request(?: for Codex)?:[ \t]*$',
  multiLine: true,
);
final _quotedPastedPattern = RegExp(r'##\s+"([\s\S]*?)":\s*([^\r\n]+)');
final _namedEntryPattern = RegExp(
  r'^##\s+([^"\r\n][^:\r\n]*):\s*([^\r\n]+)$',
  multiLine: true,
);

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
    final normalized = _normalizeAttachment(candidate);
    final rawPath = candidate.path?.trim();
    final dedupPath = (rawPath == null || rawPath.isEmpty)
        ? null
        : _canonicalPath(_truncate(rawPath, 4096));
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

  final delimiterMatch = _requestDelimiterPattern.firstMatch(trimmed);
  final rawHeaderSection = delimiterMatch == null
      ? trimmed
      : trimmed.substring(0, delimiterMatch.start);
  final boundedHeaderSection =
      rawHeaderSection.length <= maxEnvelopeHeaderScanCharacters
      ? rawHeaderSection
      : rawHeaderSection.substring(0, maxEnvelopeHeaderScanCharacters);
  final requestText = delimiterMatch == null
      ? ''
      : trimmed.substring(delimiterMatch.end).trim();

  final extractedFromEnvelope = <UserAttachment>[];
  final pastedPreviews = <String>[];

  final sectionBlocks = _splitEnvelopeSections(boundedHeaderSection);
  for (final section in sectionBlocks) {
    switch (section.kind) {
      case 'ide':
        String? activeFile;
        var openTabCount = 0;
        for (final rawLine in section.body.split('\n')) {
          final line = rawLine.trim();
          if (line.startsWith('## Active file:')) {
            final candidate = line.substring('## Active file:'.length).trim();
            if (candidate.isNotEmpty && candidate.toLowerCase() != 'none') {
              activeFile = candidate;
            }
          } else if (line.startsWith('- ')) {
            openTabCount += 1;
          }
        }
        if (activeFile != null) {
          extractedFromEnvelope.add(
            UserAttachment(
              kind: UserAttachmentKind.ideContext,
              label: _basename(activeFile),
              path: activeFile,
              preview: openTabCount > 0
                  ? 'Active file: $activeFile\nOpen tabs: $openTabCount'
                  : 'Active file: $activeFile',
            ),
          );
        } else if (openTabCount > 0) {
          extractedFromEnvelope.add(
            UserAttachment(
              kind: UserAttachmentKind.ideContext,
              label: '$openTabCount IDE tab${openTabCount == 1 ? '' : 's'}',
              preview: section.body.trim(),
            ),
          );
        }
      case 'pasted':
        var matchedQuoted = false;
        for (final match in _quotedPastedPattern.allMatches(section.body)) {
          matchedQuoted = true;
          final preview = (match.group(1) ?? '').trim();
          final path = (match.group(2) ?? '').trim();
          if (preview.isNotEmpty) {
            pastedPreviews.add(_truncate(preview, maxAttachmentPreviewLength));
          }
          final fileName = _basename(path);
          extractedFromEnvelope.add(
            UserAttachment(
              kind: UserAttachmentKind.pastedText,
              label: fileName.isEmpty ? 'Pasted text' : 'Pasted · $fileName',
              path: path.isEmpty ? null : path,
              preview: preview.isEmpty ? null : preview,
            ),
          );
        }
        if (!matchedQuoted) {
          for (final match in _namedEntryPattern.allMatches(section.body)) {
            final label = (match.group(1) ?? '').trim();
            final path = (match.group(2) ?? '').trim();
            extractedFromEnvelope.add(
              UserAttachment(
                kind: UserAttachmentKind.pastedText,
                label: label.isEmpty ? _basename(path) : label,
                path: path.isEmpty ? null : path,
              ),
            );
          }
        }
      case 'mentioned':
        for (final match in _namedEntryPattern.allMatches(section.body)) {
          final label = (match.group(1) ?? '').trim();
          final path = (match.group(2) ?? '').trim();
          extractedFromEnvelope.add(
            UserAttachment(
              kind: UserAttachmentKind.file,
              label: label.isEmpty ? _basename(path) : label,
              path: path.isEmpty ? null : path,
            ),
          );
        }
    }
  }

  if (delimiterMatch == null && extractedFromEnvelope.isEmpty) {
    return UserMessagePresentation(
      bodyText: _cleanUserMessageText(rawText),
      attachments: List.unmodifiable(resultAttachments),
      hadStructuredEnvelope: false,
    );
  }

  for (final attachment in extractedFromEnvelope) {
    addNormalizedAttachment(attachment, isStructured: false);
  }

  var bodyText = requestText;
  if (bodyText.isEmpty && pastedPreviews.isNotEmpty) {
    bodyText = pastedPreviews.join('\n\n');
  }
  if (bodyText.isEmpty && extractedFromEnvelope.isNotEmpty) {
    final first = _normalizeAttachment(extractedFromEnvelope.first);
    bodyText = first.preview ?? first.label;
  }
  if (bodyText.isEmpty && resultAttachments.isNotEmpty) {
    bodyText =
        resultAttachments.first.preview ?? resultAttachments.first.label;
  }

  return UserMessagePresentation(
    bodyText: _cleanUserMessageText(bodyText),
    attachments: List.unmodifiable(resultAttachments),
    hadStructuredEnvelope: true,
  );
}

UserAttachment _normalizeAttachment(UserAttachment attachment) {
  final rawPath = attachment.path?.trim();
  final normalizedPath = (rawPath == null || rawPath.isEmpty)
      ? null
      : _truncate(rawPath, maxAttachmentPathLength);
  final rawPreview = attachment.preview?.trim();
  final normalizedPreview = (rawPreview == null || rawPreview.isEmpty)
      ? null
      : _truncate(rawPreview, maxAttachmentPreviewLength);
  final rawLabel = attachment.label.trim();
  final fallbackLabel = normalizedPath != null
      ? _basename(normalizedPath)
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

String _defaultAttachmentLabel(UserAttachmentKind kind) => switch (kind) {
  UserAttachmentKind.pastedText => 'Pasted text',
  UserAttachmentKind.file => 'File',
  UserAttachmentKind.ideContext => 'IDE context',
  UserAttachmentKind.image => 'Image',
  UserAttachmentKind.skill => 'Skill',
  UserAttachmentKind.mention => 'Mention',
};

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
final _trailingHtmlSpaceEscapePattern = RegExp(r'[ \t]*&#x20;\\[ \t]*(?=\n|$)');

String _cleanUserMessageText(String text) {
  if (!text.contains('&#x20;')) {
    return text;
  }
  return text
      .replaceAll(_htmlSpaceContinuationPattern, '')
      .replaceAll(_trailingHtmlSpaceEscapePattern, '')
      .replaceAll('&#x20;', ' ');
}

List<({String kind, String body})> _splitEnvelopeSections(String header) {
  final lines = header.split('\n');
  final sections = <({String kind, String body})>[];
  String? currentKind;
  final buffer = StringBuffer();

  void flush() {
    if (currentKind != null) {
      sections.add((kind: currentKind, body: buffer.toString()));
      buffer.clear();
    }
  }

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed == '# Context from my IDE setup:') {
      flush();
      currentKind = 'ide';
    } else if (trimmed == '# Files pasted by the user:') {
      flush();
      currentKind = 'pasted';
    } else if (trimmed == '# Files mentioned by the user:') {
      flush();
      currentKind = 'mentioned';
    } else if (currentKind != null) {
      buffer.writeln(line);
    }
  }
  flush();
  return sections;
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
