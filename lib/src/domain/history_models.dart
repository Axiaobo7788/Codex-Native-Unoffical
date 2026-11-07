import 'thread_models.dart';
import 'turn_models.dart';
import 'output_models.dart';

enum HistoryItemKind { user, assistant, activity, reasoning, unknown }

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

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.turnId,
    required this.kind,
    required this.text,
    this.status,
    this.output,
    this.outputDeferred = false,
    this.isCommand = false,
    this.attachments = const [],
  });

  final String id;
  final String turnId;
  final HistoryItemKind kind;
  final String text;
  final String? status;
  final OutputDescriptor? output;
  final bool outputDeferred;
  final bool isCommand;
  final List<UserAttachment> attachments;
}

final _requestDelimiterPattern = RegExp(
  r'^## My request(?: for Codex)?:\s*$',
  multiLine: true,
);
final _quotedPastedPattern = RegExp(r'##\s+"([\s\S]*?)":\s*([^\n]+)');
final _namedEntryPattern = RegExp(
  r'^##\s+([^"\n][^:\n]*):\s*([^\n]+)$',
  multiLine: true,
);

UserMessagePresentation parseUserMessagePresentation(
  String rawText, {
  List<UserAttachment> attachments = const [],
}) {
  final trimmed = rawText.trimLeft();
  final hasEnvelopePrefix =
      trimmed.startsWith('# Files pasted by the user:') ||
      trimmed.startsWith('# Files mentioned by the user:') ||
      trimmed.startsWith('# Context from my IDE setup:');
  if (!hasEnvelopePrefix) {
    return UserMessagePresentation(
      bodyText: rawText,
      attachments: attachments,
      hadStructuredEnvelope: false,
    );
  }

  final delimiterMatch = _requestDelimiterPattern.firstMatch(trimmed);
  final headerSection = delimiterMatch == null
      ? trimmed
      : trimmed.substring(0, delimiterMatch.start);
  final requestText = delimiterMatch == null
      ? ''
      : trimmed.substring(delimiterMatch.end).trim();

  final extracted = <UserAttachment>[...attachments];
  final pastedPreviews = <String>[];

  final sectionBlocks = _splitEnvelopeSections(headerSection);
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
          extracted.add(
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
          extracted.add(
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
            pastedPreviews.add(preview);
          }
          final fileName = _basename(path);
          extracted.add(
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
            extracted.add(
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
          extracted.add(
            UserAttachment(
              kind: UserAttachmentKind.file,
              label: label.isEmpty ? _basename(path) : label,
              path: path.isEmpty ? null : path,
            ),
          );
        }
    }
  }

  var bodyText = requestText;
  if (bodyText.isEmpty && pastedPreviews.isNotEmpty) {
    bodyText = pastedPreviews.join('\n\n');
  }
  if (bodyText.isEmpty && extracted.isNotEmpty) {
    bodyText = extracted.first.preview ?? extracted.first.label;
  }

  return UserMessagePresentation(
    bodyText: bodyText,
    attachments: List.unmodifiable(extracted),
    hadStructuredEnvelope: true,
  );
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

class HistoryTurn {
  const HistoryTurn({
    required this.id,
    required this.status,
    required this.items,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final TurnRuntimeStatus status;
  final List<HistoryItem> items;
  final DateTime? startedAt;
  final DateTime? completedAt;
}

class HistoryTurnPage {
  const HistoryTurnPage({required this.turns, required this.nextCursor});

  final List<HistoryTurn> turns;
  final String? nextCursor;
}

class HistoryItemPage {
  const HistoryItemPage({required this.items, required this.nextCursor});

  final List<HistoryItem> items;
  final String? nextCursor;
}

class HistoryTurnQuery {
  const HistoryTurnQuery({
    required this.threadId,
    this.cursor,
    this.limit = 20,
    this.sortDirection = SortDirection.descending,
  }) : assert(limit > 0 && limit <= 50);

  final String threadId;
  final String? cursor;
  final int limit;
  final SortDirection sortDirection;
}

class HistoryItemQuery {
  const HistoryItemQuery({
    required this.threadId,
    required this.turnId,
    this.cursor,
    this.limit = 25,
    this.sortDirection = SortDirection.ascending,
  }) : assert(limit > 0 && limit <= 50);

  final String threadId;
  final String turnId;
  final String? cursor;
  final int limit;
  final SortDirection sortDirection;
}
