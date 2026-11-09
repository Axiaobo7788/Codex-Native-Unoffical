import '../domain/user_message_presentation.dart';

String parseStockUserText(Object? content, {required int maxCharacters}) {
  if (content is! List<Object?>) {
    return 'User message';
  }
  final text = StringBuffer();
  var hasPart = false;
  for (final part in content.whereType<Map<String, Object?>>()) {
    final value = part['text'];
    if (part['type'] != 'text' || value is! String) {
      continue;
    }
    if (hasPart) {
      if (text.length == maxCharacters) {
        return '$text…';
      }
      text.write('\n');
    }
    hasPart = true;
    var end = maxCharacters - text.length;
    if (value.length > end) {
      if (end > 0) {
        final unit = value.codeUnitAt(end - 1);
        if (unit >= 0xD800 && unit <= 0xDBFF) {
          end -= 1;
        }
      }
      text.write(value.substring(0, end));
      return '$text…';
    }
    text.write(value);
  }
  return text.toString();
}

List<UserAttachment> parseStockUserAttachments(Object? content) {
  if (content is! List<Object?>) {
    return const [];
  }
  final candidates = <UserAttachment>[];
  for (final part in content.whereType<Map<String, Object?>>()) {
    if (candidates.length >= maxUserAttachments * 4) {
      break;
    }
    final type = part['type'];
    switch (type) {
      case 'localImage':
        final path = (_string(part, 'path') ?? '').trim();
        candidates.add(
          UserAttachment(
            kind: UserAttachmentKind.image,
            label: path.isEmpty ? 'Local image' : '',
            path: path.isEmpty ? null : path,
          ),
        );
      case 'image':
        final url = _string(part, 'url');
        candidates.add(
          UserAttachment(
            kind: UserAttachmentKind.image,
            label: 'Image',
            path: url,
          ),
        );
      case 'file':
        final path = (_string(part, 'path') ?? '').trim();
        final name = (_string(part, 'name') ?? '').trim();
        candidates.add(
          UserAttachment(
            kind: UserAttachmentKind.file,
            label: name,
            path: path.isEmpty ? null : path,
          ),
        );
      case 'skill':
        final name = (_string(part, 'name') ?? '').trim();
        final path = _string(part, 'path');
        candidates.add(
          UserAttachment(
            kind: UserAttachmentKind.skill,
            label: name.isEmpty ? 'Skill' : name,
            path: path,
          ),
        );
      case 'mention':
        final name = (_string(part, 'name') ?? '').trim();
        final path = _string(part, 'path');
        candidates.add(
          UserAttachment(
            kind: UserAttachmentKind.mention,
            label: name.isEmpty ? 'Mention' : name,
            path: path,
          ),
        );
    }
  }
  return normalizeUserAttachments(candidates);
}

String? _string(Map<String, Object?> value, String key) {
  final field = value[key];
  return field is String ? field : null;
}
