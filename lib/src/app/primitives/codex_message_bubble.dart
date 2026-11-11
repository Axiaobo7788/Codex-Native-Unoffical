import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/official_codex_theme.dart';

/// Semantic user message bubble primitive translated from official Codex
/// Desktop `.bubble-vBnidZ` / `14353.dKZq` / `189497.oQwr` / `225284.y5H2`:
/// - `70%` max width of the actual containing reading column (`--user-chat-width: 70%`)
/// - `22px` borderless radius (`--radius-2xl`), `16×10` padding, `5%` ink fill
/// - `14px` `.text-size-chat` (`sansFontSize.default = 14`) with `1.625`
///   `leading-relaxed` line box and zero compact-only negative letter-spacing
/// - `20`-line collapse (`D = 20`, bounded measurement slice `B = 512 * D = 10,240`):
///   in official `14353.dKZq`, `P($ ? R.slice(0, B) : R)` slices child source
///   only when `R.length > B`; for `<= 10,240` chars, `dKZq` clips full children
///   via CSS `max-height: 19lh` + `overflow-hidden`, toggles `inert` /
///   `aria-hidden="true"` via `IntersectionObserver` only on clipped interactive
///   descendants (`a[href]`, `button`, inputs, `[tabindex]`), appends an
///   `aria-hidden` `'…'` line, and renders a `data-markdown-copy="exclude"`
///   `'Show more'` / `'Show less'` button (`ghostUserMessage` + rotating
///   `.icon-2xs` chevron), while `225284.y5H2` toolbar Copy copies the full
///   prompt in both states.
/// - Calibrated Flutter `SelectableText` tradeoff: because `SelectableText`
///   (`EditableText`) scrolls internally under bounded `maxLines`/`maxHeight`
///   and projects root-overlay selection handles outside a `ClipRect` if
///   offscreen lines remain laid out, collapsed mode renders the measured
///   `19`-line visible prefix (scoping collapsed selection to visible lines
///   until expanded, while toolbar Copy still copies the full prompt).
class CodexMessageBubble extends StatefulWidget {
  const CodexMessageBubble({
    super.key,
    required this.text,
    this.attachments = const [],
    this.maxColumnWidth = OfficialCodexTheme.maxContentWidth,
    this.radius = OfficialCodexTheme.userMessageRadius,
    this.maxCollapsedLines = OfficialCodexTheme.userMessageCollapsedLines,
    this.maxExpandedCharacters = defaultMaxExpandedCharacters,
    this.expandKey,
  });

  /// Matches live `ConversationController.maxEntryCharacters` / `TurnProtocol`
  /// `64 KiB` bound so direct callers cannot force unbounded paragraph layout.
  static const int defaultMaxExpandedCharacters = 64 * 1024;

  final String text;
  final List<Widget> attachments;
  final double maxColumnWidth;
  final double radius;
  final int maxCollapsedLines;
  final int maxExpandedCharacters;
  final Key? expandKey;

  @override
  State<CodexMessageBubble> createState() => _CodexMessageBubbleState();
}

class _CodexMessageBubbleState extends State<CodexMessageBubble> {
  bool _isExpanded = false;
  _CollapseLayoutCache? _layoutCache;

  @override
  void didUpdateWidget(covariant CodexMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _isExpanded = false;
      _layoutCache = null;
    } else if (widget.maxCollapsedLines != oldWidget.maxCollapsedLines) {
      _layoutCache = null;
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  _CollapseLayoutCache _resolveCollapseLayout({
    required TextStyle effectiveStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required double maxTextWidth,
  }) {
    final safeCollapsedLines = math.max(1, widget.maxCollapsedLines);
    final cached = _layoutCache;
    if (cached != null &&
        (identical(cached.sourceText, widget.text) ||
            cached.sourceText == widget.text) &&
        cached.maxCollapsedLines == safeCollapsedLines &&
        (cached.maxTextWidth - maxTextWidth).abs() < 0.01 &&
        cached.effectiveStyle == effectiveStyle &&
        cached.textDirection == textDirection &&
        cached.textScaler == textScaler) {
      return cached;
    }

    final collapsedBudget =
        safeCollapsedLines *
        OfficialCodexTheme.userMessageCollapsedCharsPerLine;
    final measurementSource = _sliceCodeUnitsSafe(widget.text, collapsedBudget);
    final exceededBudget = widget.text.length > measurementSource.length;

    bool isCollapsible;
    String collapsedText;

    if (measurementSource.isEmpty) {
      isCollapsible = false;
      collapsedText = '';
    } else {
      final painter = TextPainter(
        text: TextSpan(text: measurementSource, style: effectiveStyle),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: safeCollapsedLines,
      );
      try {
        painter.layout(maxWidth: maxTextWidth);
        final exceededLines = painter.didExceedMaxLines;
        if (!exceededBudget && !exceededLines) {
          isCollapsible = false;
          collapsedText = widget.text;
        } else {
          isCollapsible = true;
          final visibleLines = safeCollapsedLines > 2
              ? safeCollapsedLines - 1
              : safeCollapsedLines;
          final metrics = painter.computeLineMetrics();
          if (metrics.isEmpty) {
            collapsedText = '';
          } else {
            final lastLineIndex = math.min(visibleLines, metrics.length) - 1;
            var lineCenterY = 0.0;
            for (var i = 0; i < lastLineIndex; i += 1) {
              lineCenterY += metrics[i].height;
            }
            lineCenterY += metrics[lastLineIndex].height * 0.5;
            final edgeX = textDirection == TextDirection.rtl
                ? 0.0
                : maxTextWidth;
            final endOffset = painter
                .getPositionForOffset(Offset(edgeX, lineCenterY))
                .offset
                .clamp(0, measurementSource.length);
            collapsedText = _sliceCodeUnitsSafe(
              measurementSource,
              endOffset,
            ).trimRight();
          }
        }
      } finally {
        painter.dispose();
      }
    }

    final nextCache = _CollapseLayoutCache(
      sourceText: widget.text,
      maxCollapsedLines: safeCollapsedLines,
      maxTextWidth: maxTextWidth,
      effectiveStyle: effectiveStyle,
      textDirection: textDirection,
      textScaler: textScaler,
      isCollapsible: isCollapsible,
      collapsedText: collapsedText,
    );
    _layoutCache = nextCache;
    return nextCache;
  }

  static String _sliceCodeUnitsSafe(String text, int maxCodeUnits) {
    if (maxCodeUnits <= 0 || text.isEmpty) {
      return '';
    }
    if (text.length <= maxCodeUnits) {
      return text;
    }
    var end = maxCodeUnits;
    final prev = text.codeUnitAt(end - 1);
    if (prev >= 0xD800 && prev <= 0xDBFF) {
      end -= 1;
    }
    return text.substring(0, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    const horizontalPadding = OfficialCodexTheme.userMessageHorizontalPadding;
    const verticalPadding = OfficialCodexTheme.userMessageVerticalPadding;
    const fontSize = OfficialCodexTheme.userMessageFontSize;

    final messageStyle = TextStyle(
      color: theme.textPrimary,
      fontSize: fontSize,
      height: OfficialCodexTheme.userMessageLineHeight,
    );
    final effectiveStyle = DefaultTextStyle.of(context).style
        .merge(messageStyle);
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableColumnWidth = constraints.hasBoundedWidth
            ? math.min(constraints.maxWidth, widget.maxColumnWidth)
            : widget.maxColumnWidth;
        final rawMaxBubbleWidth =
            availableColumnWidth * OfficialCodexTheme.maxUserBubbleWidthFactor;
        final maxBubbleWidth = math.max(
          rawMaxBubbleWidth,
          horizontalPadding * 2 + 1.0,
        );
        final maxTextWidth = maxBubbleWidth - horizontalPadding * 2;

        final collapseLayout = _resolveCollapseLayout(
          effectiveStyle: effectiveStyle,
          textDirection: textDirection,
          textScaler: textScaler,
          maxTextWidth: maxTextWidth,
        );

        final isCollapsible = collapseLayout.isCollapsible;
        final showFull = _isExpanded || !isCollapsible;
        final safeMaxExpanded = math.max(1, widget.maxExpandedCharacters);
        final expandedTruncated =
            showFull && widget.text.length > safeMaxExpanded;
        final displayText = showFull
            ? _sliceCodeUnitsSafe(widget.text, safeMaxExpanded)
            : collapseLayout.collapsedText;
        final showEllipsisLine =
            (!showFull && isCollapsible) || expandedTruncated;

        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(
                color: theme.userBubbleBackground,
                borderRadius: BorderRadius.circular(widget.radius),
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
                    const SizedBox(
                      height: OfficialCodexTheme.userMessageAttachmentGap,
                    ),
                  ],
                  SelectableText(displayText, style: messageStyle),
                  if (showEllipsisLine)
                    ExcludeSemantics(child: Text('…', style: messageStyle)),
                  if (isCollapsible) ...[
                    const SizedBox(
                      height: OfficialCodexTheme.userMessageExpandGap,
                    ),
                    _UserMessageExpandButton(
                      key: widget.expandKey,
                      isExpanded: _isExpanded,
                      onPressed: _toggleExpanded,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _CollapseLayoutCache {
  const _CollapseLayoutCache({
    required this.sourceText,
    required this.maxCollapsedLines,
    required this.maxTextWidth,
    required this.effectiveStyle,
    required this.textDirection,
    required this.textScaler,
    required this.isCollapsible,
    required this.collapsedText,
  });

  final String sourceText;
  final int maxCollapsedLines;
  final double maxTextWidth;
  final TextStyle effectiveStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final bool isCollapsible;
  final String collapsedText;
}

class _UserMessageExpandButton extends StatefulWidget {
  const _UserMessageExpandButton({
    super.key,
    required this.isExpanded,
    required this.onPressed,
  });

  final bool isExpanded;
  final VoidCallback onPressed;

  @override
  State<_UserMessageExpandButton> createState() =>
      _UserMessageExpandButtonState();
}

class _UserMessageExpandButtonState extends State<_UserMessageExpandButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final label = widget.isExpanded ? 'Show less' : 'Show more';

    return Semantics(
      button: true,
      toggled: widget.isExpanded,
      label: label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6.0),
              border: _focused
                  ? Border.all(
                      color: theme.focusRing,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: OfficialCodexTheme.userMessageFontSize,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 4.0),
                AnimatedRotation(
                  turns: widget.isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: OfficialCodexTheme.activityInlineIconSize,
                    color: theme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
