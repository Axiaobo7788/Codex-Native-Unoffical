import 'dart:collection';

import 'user_message_presentation.dart';

const maxChatDagNodes = 500;
const maxChatDagNodeTextLength = 16 * 1024;

enum ChatDagRole {
  system,
  user,
  assistant,
  tool,
  unknown;

  static ChatDagRole fromWire(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'system' || 'developer' => ChatDagRole.system,
        'user' => ChatDagRole.user,
        'assistant' => ChatDagRole.assistant,
        'tool' || 'function' => ChatDagRole.tool,
        _ => ChatDagRole.unknown,
      };
}

class ChatDagNode {
  const ChatDagNode({
    required this.id,
    this.parentId,
    this.childrenIds = const [],
    required this.role,
    required this.text,
    this.turnId,
    this.createdAt,
    this.attachments = const [],
  });

  final String id;
  final String? parentId;
  final List<String> childrenIds;
  final ChatDagRole role;
  final String text;
  final String? turnId;
  final DateTime? createdAt;
  final List<UserAttachment> attachments;

  ChatDagNode copyWith({
    String? parentId,
    List<String>? childrenIds,
    ChatDagRole? role,
    String? text,
    String? turnId,
    DateTime? createdAt,
    List<UserAttachment>? attachments,
  }) => ChatDagNode(
    id: id,
    parentId: parentId ?? this.parentId,
    childrenIds: childrenIds ?? this.childrenIds,
    role: role ?? this.role,
    text: text ?? this.text,
    turnId: turnId ?? this.turnId,
    createdAt: createdAt ?? this.createdAt,
    attachments: attachments ?? this.attachments,
  );
}

class ChatSiblingBranchInfo {
  const ChatSiblingBranchInfo({
    required this.nodeId,
    required this.parentId,
    required this.currentIndex,
    required this.totalSiblings,
    required this.siblingNodeIds,
  });

  final String nodeId;
  final String? parentId;
  final int currentIndex;
  final int totalSiblings;
  final List<String> siblingNodeIds;

  bool get hasMultipleBranches => totalSiblings > 1;
  bool get canSelectPrevious => currentIndex > 0;
  bool get canSelectNext => currentIndex + 1 < totalSiblings;
  String get label => '${currentIndex + 1}/$totalSiblings';
  String get displayLabel => label;
}

/// Bounded clean-room representation of the official ChatGPT / Android
/// `mapping` + `current_node` conversation DAG (`MrGp`).
///
/// Supports:
/// - Parsing standard ChatGPT `conversations.json` / `mapping` trees with
///   strict node and text bounds (`maxChatDagNodes`, `maxChatDagNodeTextLength`).
/// - Active path resolution from `currentNodeId` to root with cycle protection.
/// - Sibling branch inspection (`< 1/2 >`) and subtree leaf switching.
/// - Recording local turn edits / regenerations as sibling branches.
class ChatConversationDag {
  ChatConversationDag({
    required Map<String, ChatDagNode> mapping,
    required this.currentNodeId,
    Map<String, String> preferredLeafByNodeId = const {},
  }) : mapping = Map.unmodifiable(mapping),
       _preferredLeafByNodeId = Map.unmodifiable(preferredLeafByNodeId);

  const ChatConversationDag.empty()
    : mapping = const {},
      currentNodeId = null,
      _preferredLeafByNodeId = const {};

  final Map<String, ChatDagNode> mapping;
  final String? currentNodeId;
  final Map<String, String> _preferredLeafByNodeId;

  bool get isEmpty => mapping.isEmpty;

  /// Parses a ChatGPT conversation object containing `mapping` and
  /// `current_node` (or `currentNode`).
  factory ChatConversationDag.fromMappingJson(
    Map<String, Object?> json, {
    int maxNodes = maxChatDagNodes,
  }) {
    final rawMapping = json['mapping'];
    if (rawMapping is! Map<String, Object?> || rawMapping.isEmpty) {
      return const ChatConversationDag.empty();
    }
    final boundedEntries = rawMapping.entries.take(maxNodes).toList();
    final allowedIds = boundedEntries.map((e) => e.key).toSet();
    final parsed = <String, ChatDagNode>{};

    for (final entry in boundedEntries) {
      final nodeId = entry.key;
      final value = entry.value;
      if (value is! Map<String, Object?>) {
        continue;
      }
      final rawParent = value['parent'];
      final parentId = rawParent is String && allowedIds.contains(rawParent)
          ? rawParent
          : null;
      final rawChildren = value['children'];
      final childrenIds = rawChildren is List<Object?>
          ? rawChildren
                .whereType<String>()
                .where(allowedIds.contains)
                .toList(growable: false)
          : const <String>[];

      var role = ChatDagRole.unknown;
      var text = '';
      DateTime? createdAt;
      String? turnId;
      if (value['message'] case final Map<String, Object?> message) {
        if (message['author'] case final Map<String, Object?> author) {
          role = ChatDagRole.fromWire(author['role'] as String?);
        }
        if (message['create_time'] case final num timestamp) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(
            (timestamp * 1000).round(),
            isUtc: true,
          );
        }
        if (message['id'] case final String msgId) {
          turnId = msgId;
        }
        if (message['content'] case final Map<String, Object?> content) {
          if (content['parts'] case final List<Object?> parts) {
            final textParts = parts.whereType<String>().toList();
            text = _boundText(textParts.join('\n'));
          } else if (content['text'] case final String contentText) {
            text = _boundText(contentText);
          }
        }
      }

      parsed[nodeId] = ChatDagNode(
        id: nodeId,
        parentId: parentId,
        childrenIds: childrenIds,
        role: role,
        text: text,
        turnId: turnId,
        createdAt: createdAt,
      );
    }

    final rawCurrent = (json['current_node'] ?? json['currentNode']) as String?;
    final currentNodeId = rawCurrent != null && parsed.containsKey(rawCurrent)
        ? rawCurrent
        : (parsed.isNotEmpty ? parsed.keys.last : null);

    return ChatConversationDag(mapping: parsed, currentNodeId: currentNodeId);
  }

  /// Chronological sequence of nodes from root to `currentNodeId`.
  List<ChatDagNode> get activeBranchNodes {
    final current = currentNodeId;
    if (current == null || !mapping.containsKey(current)) {
      return const [];
    }
    final reversed = <ChatDagNode>[];
    final visited = <String>{};
    String? cursor = current;
    while (cursor != null && visited.add(cursor)) {
      final node = mapping[cursor];
      if (node == null) {
        break;
      }
      reversed.add(node);
      cursor = node.parentId;
    }
    return List.unmodifiable(reversed.reversed);
  }

  /// Visible user/assistant message nodes along the active branch.
  List<ChatDagNode> get activeVisibleMessages => activeBranchNodes
      .where(
        (node) =>
            (node.role == ChatDagRole.user ||
                node.role == ChatDagRole.assistant) &&
            (node.text.trim().isNotEmpty || node.attachments.isNotEmpty),
      )
      .toList(growable: false);

  List<String> get _rootNodeIds => mapping.values
      .where(
        (node) => node.parentId == null || !mapping.containsKey(node.parentId),
      )
      .map((node) => node.id)
      .toList(growable: false);

  /// Returns sibling branch metadata for `nodeId` if its parent (or root set)
  /// has multiple children.
  ChatSiblingBranchInfo? siblingInfoFor(String nodeId) {
    final node = mapping[nodeId];
    if (node == null) {
      return null;
    }
    final parentId = node.parentId;
    final List<String> siblings;
    if (parentId != null && mapping.containsKey(parentId)) {
      siblings = mapping[parentId]!.childrenIds
          .where(mapping.containsKey)
          .toList(growable: false);
    } else {
      siblings = _rootNodeIds;
    }
    final index = siblings.indexOf(nodeId);
    if (index < 0) {
      return null;
    }
    return ChatSiblingBranchInfo(
      nodeId: nodeId,
      parentId: parentId,
      currentIndex: index,
      totalSiblings: siblings.length,
      siblingNodeIds: siblings,
    );
  }

  /// Finds the active-branch user node matching `turnId` (or whose sibling
  /// group contains `turnId`).
  ChatDagNode? nodeForTurnId(String turnId) {
    if (turnId.isEmpty) {
      return null;
    }
    for (final node in activeBranchNodes) {
      if (node.turnId == turnId || node.id == turnId) {
        return node;
      }
    }
    for (final node in mapping.values) {
      if (node.turnId == turnId || node.id == turnId) {
        return node;
      }
    }
    return null;
  }

  static String _selectedSiblingKey(String? parentId) =>
      'selected-sibling:${parentId ?? '__root__'}';

  /// Switches the active branch at `nodeId` by `offset` (`-1` for previous
  /// sibling, `+1` for next sibling) and resolves `currentNodeId` to the
  /// preferred or deepest leaf of the selected sibling subtree.
  ChatConversationDag selectSiblingBranch({
    required String nodeId,
    required int offset,
  }) {
    final info = siblingInfoFor(nodeId);
    if (info == null) {
      return this;
    }
    final targetIndex = info.currentIndex + offset;
    if (targetIndex < 0 || targetIndex >= info.totalSiblings) {
      return this;
    }
    final targetSiblingId = info.siblingNodeIds[targetIndex];
    final nextPreferred = Map<String, String>.from(_preferredLeafByNodeId);
    if (currentNodeId != null) {
      nextPreferred[nodeId] = currentNodeId!;
    }
    nextPreferred[_selectedSiblingKey(info.parentId)] = targetSiblingId;
    final rememberedLeaf = nextPreferred[targetSiblingId];
    final resolvedLeaf =
        rememberedLeaf != null &&
            mapping.containsKey(rememberedLeaf) &&
            _isDescendantOrSelf(
              candidateId: rememberedLeaf,
              ancestorId: targetSiblingId,
            )
        ? rememberedLeaf
        : _resolveLatestLeaf(targetSiblingId);
    return ChatConversationDag(
      mapping: mapping,
      currentNodeId: resolvedLeaf,
      preferredLeafByNodeId: nextPreferred,
    );
  }

  /// Records a branched turn alternative (e.g. when editing or regenerating a
  /// user prompt at `turnId`) so sibling branch navigation (`< 1/2 >`) can
  /// switch between the original and edited/regenerated branches.
  ChatConversationDag recordTurnBranch({
    required String turnId,
    required String originalUserText,
    List<UserAttachment> originalAttachments = const [],
    String? originalAssistantText,
    required String nextTurnId,
    required String nextUserText,
    List<UserAttachment> nextAttachments = const [],
    String? nextAssistantText,
    String? parentTurnId,
  }) {
    final nextMap = LinkedHashMap<String, ChatDagNode>.from(mapping);
    final nextPreferred = Map<String, String>.from(_preferredLeafByNodeId);

    final matchedOriginal = nodeForTurnId(turnId);
    final existingOriginal = matchedOriginal == null
        ? null
        : (matchedOriginal.role == ChatDagRole.user
              ? matchedOriginal
              : (matchedOriginal.parentId != null
                    ? nextMap[matchedOriginal.parentId!]
                    : null));

    String? parentNodeId = existingOriginal?.parentId;
    if (parentNodeId == null || !nextMap.containsKey(parentNodeId)) {
      if (parentTurnId != null && parentTurnId.isNotEmpty) {
        final parentNode = nodeForTurnId(parentTurnId);
        if (parentNode != null) {
          final parentAsst = parentNode.role == ChatDagRole.user
              ? assistantChildFor(parentNode.id)
              : null;
          parentNodeId = (parentAsst ?? parentNode).id;
        } else {
          parentNodeId = 'slot-parent-$parentTurnId';
          nextMap.putIfAbsent(
            parentNodeId,
            () => ChatDagNode(
              id: parentNodeId!,
              role: ChatDagRole.system,
              text: '',
              turnId: parentTurnId,
            ),
          );
        }
      } else {
        parentNodeId = 'slot-$turnId';
        nextMap.putIfAbsent(
          parentNodeId,
          () => ChatDagNode(
            id: parentNodeId!,
            role: ChatDagRole.system,
            text: '',
          ),
        );
      }
    }

    final originalUserId = existingOriginal?.id ?? 'user-$turnId';
    if (!nextMap.containsKey(originalUserId)) {
      final origAsstId =
          originalAssistantText != null && originalAssistantText.isNotEmpty
          ? 'assistant-$turnId'
          : null;
      nextMap[originalUserId] = ChatDagNode(
        id: originalUserId,
        parentId: parentNodeId,
        childrenIds: origAsstId != null ? [origAsstId] : const [],
        role: ChatDagRole.user,
        text: _boundText(originalUserText),
        turnId: turnId,
        attachments: normalizeUserAttachments(originalAttachments),
      );
      if (origAsstId != null) {
        nextMap[origAsstId] = ChatDagNode(
          id: origAsstId,
          parentId: originalUserId,
          role: ChatDagRole.assistant,
          text: _boundText(originalAssistantText!),
          turnId: turnId,
        );
      }
      if (nextMap.containsKey(parentNodeId)) {
        final parent = nextMap[parentNodeId]!;
        if (!parent.childrenIds.contains(originalUserId)) {
          nextMap[parentNodeId] = parent.copyWith(
            childrenIds: [...parent.childrenIds, originalUserId],
          );
        }
      }
    } else {
      final existingUser = nextMap[originalUserId]!;
      if (existingUser.parentId == null && nextMap.containsKey(parentNodeId)) {
        nextMap[originalUserId] = existingUser.copyWith(parentId: parentNodeId);
        final parent = nextMap[parentNodeId]!;
        if (!parent.childrenIds.contains(originalUserId)) {
          nextMap[parentNodeId] = parent.copyWith(
            childrenIds: [...parent.childrenIds, originalUserId],
          );
        }
      }
      if (originalAssistantText != null && originalAssistantText.isNotEmpty) {
        final currentUser = nextMap[originalUserId]!;
        final hasAssistantChild = currentUser.childrenIds.any(
          (id) => nextMap[id]?.role == ChatDagRole.assistant,
        );
        if (!hasAssistantChild) {
          final origTurnKey = currentUser.turnId ?? turnId;
          final origAsstId = 'assistant-$origTurnKey';
          nextMap[origAsstId] = ChatDagNode(
            id: origAsstId,
            parentId: originalUserId,
            role: ChatDagRole.assistant,
            text: _boundText(originalAssistantText),
            turnId: origTurnKey,
          );
          nextMap[originalUserId] = currentUser.copyWith(
            childrenIds: [...currentUser.childrenIds, origAsstId],
          );
        }
      }
    }

    final effectiveParentId = nextMap[originalUserId]?.parentId ?? parentNodeId;
    final nextUserId = 'user-$nextTurnId';
    final nextAsstId = nextAssistantText != null && nextAssistantText.isNotEmpty
        ? 'assistant-$nextTurnId'
        : null;
    nextMap[nextUserId] = ChatDagNode(
      id: nextUserId,
      parentId: effectiveParentId,
      childrenIds: nextAsstId != null ? [nextAsstId] : const [],
      role: ChatDagRole.user,
      text: _boundText(nextUserText),
      turnId: nextTurnId,
      attachments: normalizeUserAttachments(nextAttachments),
    );
    if (nextAsstId != null) {
      nextMap[nextAsstId] = ChatDagNode(
        id: nextAsstId,
        parentId: nextUserId,
        role: ChatDagRole.assistant,
        text: _boundText(nextAssistantText!),
        turnId: nextTurnId,
      );
    }
    if (nextMap.containsKey(effectiveParentId)) {
      final parent = nextMap[effectiveParentId]!;
      if (!parent.childrenIds.contains(nextUserId)) {
        nextMap[effectiveParentId] = parent.copyWith(
          childrenIds: [...parent.childrenIds, nextUserId],
        );
      }
    }
    nextPreferred[_selectedSiblingKey(effectiveParentId)] = nextUserId;

    while (nextMap.length > maxChatDagNodes) {
      nextMap.remove(nextMap.keys.first);
    }

    return ChatConversationDag(
      mapping: nextMap,
      currentNodeId: nextAsstId ?? nextUserId,
      preferredLeafByNodeId: nextPreferred,
    );
  }

  /// Finds the currently active sibling user node for the sibling group
  /// containing `turnId`.
  ChatDagNode? activeSiblingForTurn(String turnId) {
    final matched = nodeForTurnId(turnId);
    if (matched == null) {
      return null;
    }
    final userNode = matched.role == ChatDagRole.user
        ? matched
        : (matched.parentId != null ? mapping[matched.parentId!] : null);
    if (userNode == null) {
      return null;
    }
    final siblings = siblingInfoFor(userNode.id);
    if (siblings == null) {
      return userNode;
    }
    final activeIds = activeBranchNodes.map((n) => n.id).toSet();
    for (final siblingId in siblings.siblingNodeIds) {
      if (activeIds.contains(siblingId)) {
        return mapping[siblingId];
      }
    }
    final preferredId =
        _preferredLeafByNodeId[_selectedSiblingKey(siblings.parentId)];
    if (preferredId != null &&
        siblings.siblingNodeIds.contains(preferredId) &&
        mapping.containsKey(preferredId)) {
      return mapping[preferredId];
    }
    return userNode;
  }

  /// Returns the assistant reply node attached to `userNodeId`, if any.
  ChatDagNode? assistantChildFor(String userNodeId) {
    final userNode = mapping[userNodeId];
    if (userNode == null) {
      return null;
    }
    for (final childId in userNode.childrenIds) {
      final child = mapping[childId];
      if (child != null && child.role == ChatDagRole.assistant) {
        return child;
      }
    }
    return null;
  }

  /// Updates or attaches the assistant response for `turnId` in the DAG.
  ChatConversationDag updateTurnAssistantText({
    required String turnId,
    required String assistantText,
  }) {
    if (turnId.isEmpty || assistantText.trim().isEmpty) {
      return this;
    }
    final userId = 'user-$turnId';
    final userNode = mapping[userId];
    if (userNode == null) {
      return this;
    }
    final asstId = 'assistant-$turnId';
    final existingAsst = mapping[asstId];
    final bounded = _boundText(assistantText);
    if (existingAsst != null && existingAsst.text == bounded) {
      return this;
    }
    final nextMap = LinkedHashMap<String, ChatDagNode>.from(mapping);
    nextMap[asstId] = ChatDagNode(
      id: asstId,
      parentId: userId,
      role: ChatDagRole.assistant,
      text: bounded,
      turnId: turnId,
    );
    if (!userNode.childrenIds.contains(asstId)) {
      nextMap[userId] = userNode.copyWith(
        childrenIds: [...userNode.childrenIds, asstId],
      );
    }
    return ChatConversationDag(
      mapping: nextMap,
      currentNodeId: currentNodeId == userId ? asstId : currentNodeId,
      preferredLeafByNodeId: _preferredLeafByNodeId,
    );
  }

  bool _isDescendantOrSelf({
    required String candidateId,
    required String ancestorId,
  }) {
    final visited = <String>{};
    String? cursor = candidateId;
    while (cursor != null && visited.add(cursor)) {
      if (cursor == ancestorId) {
        return true;
      }
      cursor = mapping[cursor]?.parentId;
    }
    return false;
  }

  String _resolveLatestLeaf(String startNodeId) {
    final visited = <String>{};
    var cursor = startNodeId;
    while (visited.add(cursor)) {
      final node = mapping[cursor];
      if (node == null || node.childrenIds.isEmpty) {
        return cursor;
      }
      final validChildren = node.childrenIds
          .where(mapping.containsKey)
          .toList(growable: false);
      if (validChildren.isEmpty) {
        return cursor;
      }
      cursor = validChildren.last;
    }
    return cursor;
  }

  static String _boundText(String value) {
    if (value.length <= maxChatDagNodeTextLength) {
      return value;
    }
    return '${value.substring(0, maxChatDagNodeTextLength)}…';
  }
}
