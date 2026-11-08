import 'package:flutter/material.dart';

import '../theme/official_codex_theme.dart';

/// Semantic user message bubble primitive conforming to official Codex desktop
/// specifications (75% max width / ~528px, 18px radius, soft tint, 12-line auto-collapse).
class CodexMessageBubble extends StatefulWidget {
  const CodexMessageBubble({
    super.key,
    required this.text,
    this.attachments = const [],
    this.maxColumnWidth = OfficialCodexTheme.maxContentWidth,
    this.radius = OfficialCodexTheme.userMessageRadius,
    this.maxCollapsedLines = 12,
    this.collapseCharacterThreshold = 680,
    this.expandKey,
  });

  final String text;
  final List<Widget> attachments;
  final double maxColumnWidth;
  final double radius;
  final int maxCollapsedLines;
  final int collapseCharacterThreshold;
  final Key? expandKey;

  @override
  State<CodexMessageBubble> createState() => _CodexMessageBubbleState();
}

class _CodexMessageBubbleState extends State<CodexMessageBubble> {
  bool _isExpanded = false;

  bool get _isCollapsible {
    if (widget.text.length > widget.collapseCharacterThreshold) {
      return true;
    }
    final lineBreaks = '\n'.allMatches(widget.text).length;
    return lineBreaks >= widget.maxCollapsedLines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final maxBubbleWidth =
        widget.maxColumnWidth * OfficialCodexTheme.maxUserBubbleWidthFactor;

    final isLong = _isCollapsible;
    final showFull = _isExpanded || !isLong;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: theme.userBubbleBackground,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: theme.hairlineBorder,
              width: OfficialCodexTheme.hairlineBorderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.attachments.isNotEmpty) ...[
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: widget.attachments,
                ),
                const SizedBox(height: 8.0),
              ],
              SelectableText(
                widget.text,
                maxLines: showFull ? null : widget.maxCollapsedLines,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 14.0,
                  height: 1.6,
                  letterSpacing: -0.1,
                ),
              ),
              if (isLong) ...[
                const SizedBox(height: 6.0),
                GestureDetector(
                  key: widget.expandKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        _isExpanded ? 'Show less' : 'Show full message',
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
