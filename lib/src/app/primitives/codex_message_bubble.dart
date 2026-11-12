import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../features/conversation/assistant_markdown.dart';
import '../theme/official_codex_theme.dart';

/// Semantic user message bubble primitive translated from official Codex
/// Desktop `.bubble-vBnidZ` / `14353.dKZq` / `189497.oQwr` / `225284.y5H2`:
/// - `70%` max width of the actual containing reading column (`--user-chat-width: 70%`)
/// - `22px` borderless radius (`--radius-2xl`), `16×10` padding, `5%` ink fill
/// - `14px` `.text-size-chat` (`sansFontSize.default = 14`) with `1.625`
///   `leading-relaxed` line box and zero compact-only negative letter-spacing
/// - `20`-line actual rendered-height collapse (`D = 20`, bounded measurement
///   slice `B = 512 * D = 10,240`):
///   - `189497.oQwr.ee` measures `collapsedHeightPx = Math.ceil(lineHeightPx * D)`
///     and `contentHeightPx = Math.ceil(scrollHeight)`, collapsing iff
///     `contentHeightPx > collapsedHeightPx + 1` (or `R.length > B`).
///   - `14353.dKZq.S` passes `R` uncorrupted when `R.length <= B` (`P($ ? R.slice(0, B) : R)`),
///     clips rendered children at `Math.ceil(lineHeightPx * (D - 1))` (`19lh`),
///     expands the clip height to `Math.ceil(codeBlock.bottom)` when any
///     `[data-markdown-copy="code-block"]:not(pre)` straddles the clip boundary
///     (`!forceCollapsible`), gates clipped interactive descendants (`inert` +
///     `aria-hidden="true"` with `intersectionRatio > 0` for links and `>= 1`
///     for non-link controls), scopes collapsed text selection to the visible
///     viewport while excluding `'…'` and `'Show more'` / `'Show less'`
///     (`data-markdown-copy="exclude"`), and preserves `225284.y5H2` full-prompt
///     toolbar Copy in both states.
class CodexMessageBubble extends StatefulWidget {
  const CodexMessageBubble({
    super.key,
    required this.text,
    this.attachments = const [],
    this.maxColumnWidth = OfficialCodexTheme.maxContentWidth,
    this.radius = OfficialCodexTheme.userMessageRadius,
    this.maxCollapsedLines = OfficialCodexTheme.userMessageCollapsedLines,
    this.maxExpandedCharacters = defaultMaxExpandedCharacters,
    this.plainTextOnly = false,
    this.forceExpanded = false,
    this.externalLinkLauncher,
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
  final bool plainTextOnly;
  final bool forceExpanded;
  final ExternalLinkLauncher? externalLinkLauncher;
  final Key? expandKey;

  @override
  State<CodexMessageBubble> createState() => _CodexMessageBubbleState();
}

class _CodexMessageBubbleState extends State<CodexMessageBubble> {
  bool _isExpanded = false;
  _LineHeightCache? _lineHeightCache;
  late final _ClippedUserSelectionContainerDelegate _selectionDelegate =
      _ClippedUserSelectionContainerDelegate();

  @override
  void didUpdateWidget(covariant CodexMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      if (_isExpanded && _selectionDelegate.value.hasSelection) {
        _selectionDelegate.dispatchSelectionEvent(const ClearSelectionEvent());
      }
      _isExpanded = false;
    }
  }

  @override
  void dispose() {
    _selectionDelegate.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    final nextExpanded = !_isExpanded;
    if (!nextExpanded && _selectionDelegate.value.hasSelection) {
      _selectionDelegate.dispatchSelectionEvent(const ClearSelectionEvent());
    }
    setState(() {
      _isExpanded = nextExpanded;
    });
  }

  double _resolveSingleLineHeight({
    required TextStyle effectiveStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required Locale? locale,
  }) {
    final cached = _lineHeightCache;
    if (cached != null &&
        cached.effectiveStyle == effectiveStyle &&
        cached.textDirection == textDirection &&
        cached.textScaler == textScaler &&
        cached.locale == locale) {
      return cached.lineHeightPx;
    }

    final painter = TextPainter(
      text: TextSpan(text: 'M', style: effectiveStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      maxLines: 1,
    );
    late final double measured;
    try {
      painter.layout();
      measured = painter.height > 0
          ? painter.height
          : textScaler.scale(
              OfficialCodexTheme.userMessageFontSize *
                  OfficialCodexTheme.userMessageLineHeight,
            );
    } finally {
      painter.dispose();
    }

    final nextCache = _LineHeightCache(
      effectiveStyle: effectiveStyle,
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      lineHeightPx: measured,
    );
    _lineHeightCache = nextCache;
    return measured;
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
    final materialTheme = Theme.of(context);
    const horizontalPadding = OfficialCodexTheme.userMessageHorizontalPadding;
    const verticalPadding = OfficialCodexTheme.userMessageVerticalPadding;
    const fontSize = OfficialCodexTheme.userMessageFontSize;

    final messageStyle = TextStyle(
      color: theme.textPrimary,
      fontSize: fontSize,
      height: OfficialCodexTheme.userMessageLineHeight,
      fontFamily: materialTheme.textTheme.bodyMedium?.fontFamily,
      fontFamilyFallback:
          materialTheme.textTheme.bodyMedium?.fontFamilyFallback,
    );
    final effectiveStyle = DefaultTextStyle.of(context).style
        .merge(messageStyle);
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final lineHeightPx = _resolveSingleLineHeight(
      effectiveStyle: effectiveStyle,
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
    );

    final safeCollapsedLines = math.max(1, widget.maxCollapsedLines);
    final collapsedBudget =
        safeCollapsedLines *
        OfficialCodexTheme.userMessageCollapsedCharsPerLine;
    final forceCollapsible =
        !widget.forceExpanded && widget.text.length > collapsedBudget;
    final showExpandedSource = _isExpanded || widget.forceExpanded;
    final safeMaxExpanded = math.max(1, widget.maxExpandedCharacters);
    final expandedTruncated =
        showExpandedSource && widget.text.length > safeMaxExpanded;
    final displayText = showExpandedSource
        ? _sliceCodeUnitsSafe(widget.text, safeMaxExpanded)
        : (forceCollapsible
              ? _sliceCodeUnitsSafe(widget.text, collapsedBudget)
              : widget.text);
    final usePlainText =
        displayText.isEmpty ||
        widget.plainTextOnly ||
        displayText.length > UserMessageMarkdown.maxSourceCharacters;

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

        final Widget contentChild = usePlainText
            ? Text(
                displayText,
                key: const ValueKey('user-bounded-text'),
                style: messageStyle,
              )
            : UserMessageMarkdown(
                data: displayText,
                includeSelectionArea: false,
                externalLinkLauncher: widget.externalLinkLauncher,
              );

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
                  SelectionArea(
                    child: _UserMessageCollapsibleLayout(
                      expandedTruncated: expandedTruncated,
                      isExpanded: _isExpanded,
                      lineHeightPx: lineHeightPx,
                      textDirection: textDirection,
                      selectionDelegate: _selectionDelegate,
                      children: [
                        SelectionContainer(
                          delegate: _selectionDelegate,
                          child: _UserMessageClipViewport(
                            key: const ValueKey('user-message-clip-viewport'),
                            lineHeightPx: lineHeightPx,
                            maxCollapsedLines: safeCollapsedLines,
                            forceCollapsible: forceCollapsible,
                            forceExpanded: widget.forceExpanded,
                            isExpanded: _isExpanded,
                            child: contentChild,
                          ),
                        ),
                        SelectionContainer.disabled(
                          child: _UserMessageCollapseChromeBuilder(
                            builder: (context, chromeConstraints) {
                              if (!chromeConstraints.showEllipsis &&
                                  !chromeConstraints.showToggle) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (chromeConstraints.showEllipsis)
                                    ExcludeSemantics(
                                      child: Text('…', style: messageStyle),
                                    ),
                                  if (chromeConstraints.showToggle) ...[
                                    const SizedBox(
                                      height: OfficialCodexTheme
                                          .userMessageExpandGap,
                                    ),
                                    _UserMessageExpandButton(
                                      key:
                                          widget.expandKey ??
                                          const ValueKey(
                                            'user-message-expand-toggle',
                                          ),
                                      isExpanded: chromeConstraints.isExpanded,
                                      onPressed: _toggleExpanded,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _LineHeightCache {
  const _LineHeightCache({
    required this.effectiveStyle,
    required this.textDirection,
    required this.textScaler,
    required this.locale,
    required this.lineHeightPx,
  });

  final TextStyle effectiveStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final double lineHeightPx;
}

class _UserMessageCollapsibleParentData
    extends ContainerBoxParentData<RenderBox> {}

class _UserMessageCollapsibleLayout extends MultiChildRenderObjectWidget {
  const _UserMessageCollapsibleLayout({
    required this.expandedTruncated,
    required this.isExpanded,
    required this.lineHeightPx,
    required this.textDirection,
    required this.selectionDelegate,
    required super.children,
  });

  final bool expandedTruncated;
  final bool isExpanded;
  final double lineHeightPx;
  final TextDirection textDirection;
  final _ClippedUserSelectionContainerDelegate selectionDelegate;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderUserMessageCollapsibleLayout(
      expandedTruncated: expandedTruncated,
      isExpanded: isExpanded,
      lineHeightPx: lineHeightPx,
      textDirection: textDirection,
      selectionDelegate: selectionDelegate,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderUserMessageCollapsibleLayout renderObject,
  ) {
    renderObject
      ..expandedTruncated = expandedTruncated
      ..isExpanded = isExpanded
      ..lineHeightPx = lineHeightPx
      ..textDirection = textDirection
      ..selectionDelegate = selectionDelegate;
  }
}

class _RenderUserMessageCollapsibleLayout extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          _UserMessageCollapsibleParentData
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _UserMessageCollapsibleParentData
        > {
  _RenderUserMessageCollapsibleLayout({
    required bool expandedTruncated,
    required bool isExpanded,
    required double lineHeightPx,
    required TextDirection textDirection,
    required _ClippedUserSelectionContainerDelegate selectionDelegate,
  }) {
    _expandedTruncated = expandedTruncated;
    _isExpanded = isExpanded;
    _lineHeightPx = lineHeightPx;
    _textDirection = textDirection;
    _selectionDelegate = selectionDelegate;
  }

  late bool _expandedTruncated;
  set expandedTruncated(bool value) {
    if (_expandedTruncated == value) {
      return;
    }
    _expandedTruncated = value;
    markNeedsLayout();
  }

  late bool _isExpanded;
  set isExpanded(bool value) {
    if (_isExpanded == value) {
      return;
    }
    _isExpanded = value;
    markNeedsLayout();
  }

  late double _lineHeightPx;
  set lineHeightPx(double value) {
    if ((_lineHeightPx - value).abs() < 1e-6) {
      return;
    }
    _lineHeightPx = value;
    markNeedsLayout();
  }

  late TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    _selectionDelegate.updateClipState(
      isClipped: _selectionDelegate.isClipped,
      lineHeightPx: _lineHeightPx,
      textDirection: _textDirection,
    );
  }

  late _ClippedUserSelectionContainerDelegate _selectionDelegate;
  set selectionDelegate(_ClippedUserSelectionContainerDelegate value) {
    if (identical(_selectionDelegate, value)) {
      return;
    }
    _selectionDelegate = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _UserMessageCollapsibleParentData) {
      child.parentData = _UserMessageCollapsibleParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      firstChild?.getMinIntrinsicWidth(height) ?? 0.0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      firstChild?.getMaxIntrinsicWidth(height) ?? 0.0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      firstChild?.getMinIntrinsicHeight(width) ?? 0.0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      firstChild?.getMaxIntrinsicHeight(width) ?? 0.0;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void performLayout() {
    final viewport = firstChild as _RenderUserMessageClipViewport?;
    if (viewport == null) {
      size = constraints.smallest;
      return;
    }
    final chrome = childAfter(viewport);

    final childBoxConstraints = BoxConstraints(
      minWidth: 0.0,
      maxWidth: constraints.maxWidth,
    );
    viewport.layout(childBoxConstraints, parentUsesSize: true);
    (_parentDataOf(viewport)).offset = Offset.zero;

    _selectionDelegate.updateClipState(
      isClipped: viewport.isActivelyClipped,
      lineHeightPx: _lineHeightPx,
      textDirection: _textDirection,
    );

    final showToggle = viewport.isCollapsible;
    final showEllipsis =
        (viewport.isActivelyClipped && viewport.showCollapsedEllipsis) ||
        (!viewport.isActivelyClipped && _expandedTruncated);

    var totalWidth = viewport.size.width;
    var totalHeight = viewport.size.height;

    if (chrome != null) {
      chrome.layout(
        _UserCollapseChromeConstraints(
          minWidth: 0.0,
          maxWidth: constraints.maxWidth,
          minHeight: 0.0,
          maxHeight: double.infinity,
          showEllipsis: showEllipsis,
          showToggle: showToggle,
          isExpanded: _isExpanded,
        ),
        parentUsesSize: true,
      );
      _parentDataOf(chrome).offset = Offset(0.0, viewport.size.height);
      totalWidth = math.max(totalWidth, chrome.size.width);
      totalHeight += chrome.size.height;
    }

    size = constraints.constrain(Size(totalWidth, totalHeight));
  }

  static _UserMessageCollapsibleParentData _parentDataOf(RenderBox child) =>
      child.parentData! as _UserMessageCollapsibleParentData;

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

class _UserMessageClipViewport extends SingleChildRenderObjectWidget {
  const _UserMessageClipViewport({
    super.key,
    required this.lineHeightPx,
    required this.maxCollapsedLines,
    required this.forceCollapsible,
    required this.forceExpanded,
    required this.isExpanded,
    required super.child,
  });

  final double lineHeightPx;
  final int maxCollapsedLines;
  final bool forceCollapsible;
  final bool forceExpanded;
  final bool isExpanded;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderUserMessageClipViewport(
      lineHeightPx: lineHeightPx,
      maxCollapsedLines: maxCollapsedLines,
      forceCollapsible: forceCollapsible,
      forceExpanded: forceExpanded,
      isExpanded: isExpanded,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderUserMessageClipViewport renderObject,
  ) {
    renderObject
      ..lineHeightPx = lineHeightPx
      ..maxCollapsedLines = maxCollapsedLines
      ..forceCollapsible = forceCollapsible
      ..forceExpanded = forceExpanded
      ..isExpanded = isExpanded;
  }
}

class _RenderUserMessageClipViewport extends RenderProxyBox {
  _RenderUserMessageClipViewport({
    required double lineHeightPx,
    required int maxCollapsedLines,
    required bool forceCollapsible,
    required bool forceExpanded,
    required bool isExpanded,
  }) {
    _lineHeightPx = lineHeightPx;
    _maxCollapsedLines = maxCollapsedLines;
    _forceCollapsible = forceCollapsible;
    _forceExpanded = forceExpanded;
    _isExpanded = isExpanded;
  }

  final LayerHandle<ClipRectLayer> _clipLayerHandle =
      LayerHandle<ClipRectLayer>();

  late double _lineHeightPx;
  set lineHeightPx(double value) {
    if ((_lineHeightPx - value).abs() < 1e-6) {
      return;
    }
    _lineHeightPx = value;
    markNeedsLayout();
  }

  late int _maxCollapsedLines;
  set maxCollapsedLines(int value) {
    if (_maxCollapsedLines == value) {
      return;
    }
    _maxCollapsedLines = value;
    markNeedsLayout();
  }

  late bool _forceCollapsible;
  set forceCollapsible(bool value) {
    if (_forceCollapsible == value) {
      return;
    }
    _forceCollapsible = value;
    markNeedsLayout();
  }

  late bool _forceExpanded;
  set forceExpanded(bool value) {
    if (_forceExpanded == value) {
      return;
    }
    _forceExpanded = value;
    markNeedsLayout();
  }

  late bool _isExpanded;
  set isExpanded(bool value) {
    if (_isExpanded == value) {
      return;
    }
    _isExpanded = value;
    markNeedsLayout();
  }

  bool _isCollapsible = false;
  bool get isCollapsible => _isCollapsible;

  bool _isActivelyClipped = false;
  bool get isActivelyClipped => _isActivelyClipped;

  bool get showCollapsedEllipsis => _maxCollapsedLines > 2;

  @override
  void dispose() {
    _clipLayerHandle.layer = null;
    super.dispose();
  }

  double _clipIntrinsicHeight(double childHeight) {
    if (_isExpanded || _forceExpanded) {
      return childHeight;
    }
    final collapsedHeightPx = (_lineHeightPx * _maxCollapsedLines)
        .ceilToDouble();
    final isCollapsible =
        _forceCollapsible || childHeight.ceilToDouble() > collapsedHeightPx + 1;
    if (!isCollapsible) {
      return childHeight;
    }
    final visibleLines = _maxCollapsedLines - (showCollapsedEllipsis ? 1 : 0);
    return math.min(childHeight, (_lineHeightPx * visibleLines).ceilToDouble());
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final raw = super.computeMinIntrinsicHeight(width);
    return _clipIntrinsicHeight(raw);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final raw = super.computeMaxIntrinsicHeight(width);
    return _clipIntrinsicHeight(raw);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) {
      return constraints.smallest;
    }
    final childSize = child.getDryLayout(
      BoxConstraints(minWidth: 0.0, maxWidth: constraints.maxWidth),
    );
    return constraints.constrain(
      Size(childSize.width, _clipIntrinsicHeight(childSize.height)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      _isCollapsible = false;
      _isActivelyClipped = false;
      size = constraints.smallest;
      return;
    }

    child.layout(
      BoxConstraints(minWidth: 0.0, maxWidth: constraints.maxWidth),
      parentUsesSize: true,
    );
    final childSize = child.size;

    final collapsedHeightPx = (_lineHeightPx * _maxCollapsedLines)
        .ceilToDouble();
    final contentHeightPx = childSize.height.ceilToDouble();
    final isMeasuredCollapsible = contentHeightPx > collapsedHeightPx + 1.0;

    _isCollapsible =
        !_forceExpanded && (_forceCollapsible || isMeasuredCollapsible);
    final wasClipped = _isActivelyClipped;
    _isActivelyClipped = _isCollapsible && !_isExpanded;

    var visibleHeight = childSize.height;
    if (_isActivelyClipped) {
      final visibleLineCount =
          _maxCollapsedLines - (showCollapsedEllipsis ? 1 : 0);
      var clipHeight = (_lineHeightPx * visibleLineCount).ceilToDouble();

      if (!_forceCollapsible) {
        _visitCodeBlockBoxes(child, (codeBox) {
          final boxSize = codeBox.laidOutSize;
          if (boxSize == null) {
            return;
          }
          final bounds = MatrixUtils.transformRect(
            codeBox.getTransformTo(child),
            Offset.zero & boxSize,
          );
          if (bounds.top < clipHeight && bounds.bottom > clipHeight) {
            clipHeight = bounds.bottom.ceilToDouble();
          }
        });
      }
      visibleHeight = math.min(childSize.height, clipHeight);
    }

    _syncClipInertControls(child, visibleHeight: visibleHeight);

    size = constraints.constrain(Size(childSize.width, visibleHeight));
    if (wasClipped != _isActivelyClipped) {
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  void _visitCodeBlockBoxes(
    RenderObject node,
    void Function(RenderCodexMarkdownCodeBlockBox codeBox) onCodeBox,
  ) {
    if (node is RenderCodexMarkdownCodeBlockBox) {
      onCodeBox(node);
      return;
    }
    node.visitChildren((child) => _visitCodeBlockBoxes(child, onCodeBox));
  }

  void _syncClipInertControls(
    RenderBox contentRoot, {
    required double visibleHeight,
  }) {
    void walk(RenderObject node) {
      if (node is RenderCodexMarkdownClipInertControl) {
        final controlSize = node.laidOutSize;
        if (!_isActivelyClipped || controlSize == null) {
          node.setClippedInert(false);
        } else {
          final bounds = MatrixUtils.transformRect(
            node.getTransformTo(contentRoot),
            Offset.zero & controlSize,
          );
          final isFullyVisible =
              bounds.top >= -0.5 && bounds.bottom <= visibleHeight + 0.5;
          node.setClippedInert(!isFullyVisible);
        }
      }
      node.visitChildren(walk);
    }

    walk(contentRoot);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _isActivelyClipped ? Offset.zero & size : null;

  @override
  Rect? describeSemanticsClip(RenderObject? child) =>
      _isActivelyClipped ? Offset.zero & size : null;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_isActivelyClipped) {
      _clipLayerHandle.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        super.paint,
        clipBehavior: Clip.hardEdge,
        oldLayer: _clipLayerHandle.layer,
      );
    } else {
      _clipLayerHandle.layer = null;
      super.paint(context, offset);
    }
  }
}

final class _UserCollapseChromeConstraints extends BoxConstraints {
  const _UserCollapseChromeConstraints({
    required super.minWidth,
    required super.maxWidth,
    required super.minHeight,
    required super.maxHeight,
    required this.showEllipsis,
    required this.showToggle,
    required this.isExpanded,
  });

  final bool showEllipsis;
  final bool showToggle;
  final bool isExpanded;

  BoxConstraints get boxConstraints => BoxConstraints(
    minWidth: minWidth,
    maxWidth: maxWidth,
    minHeight: minHeight,
    maxHeight: maxHeight,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _UserCollapseChromeConstraints &&
        super == other &&
        other.showEllipsis == showEllipsis &&
        other.showToggle == showToggle &&
        other.isExpanded == isExpanded;
  }

  @override
  int get hashCode =>
      Object.hash(super.hashCode, showEllipsis, showToggle, isExpanded);
}

class _UserMessageCollapseChromeBuilder
    extends ConstrainedLayoutBuilder<_UserCollapseChromeConstraints> {
  const _UserMessageCollapseChromeBuilder({required super.builder});

  @override
  RenderAbstractLayoutBuilderMixin<_UserCollapseChromeConstraints, RenderBox>
  createRenderObject(BuildContext context) =>
      _RenderUserCollapseChromeBuilder();
}

class _RenderUserCollapseChromeBuilder extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<
          _UserCollapseChromeConstraints,
          RenderBox
        > {
  @override
  double computeMinIntrinsicWidth(double height) => 0.0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0.0;

  @override
  double computeMinIntrinsicHeight(double width) => 0.0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0.0;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  @override
  void performLayout() {
    final chromeConstraints = constraints as _UserCollapseChromeConstraints;
    runLayoutCallback();
    final child = this.child;
    if (child != null) {
      child.layout(chromeConstraints.boxConstraints, parentUsesSize: true);
      size = chromeConstraints.constrain(child.size);
    } else {
      size = chromeConstraints.smallest;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) {
      context.paintChild(child, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child?.hitTest(result, position: position) ?? false;
  }
}

final class _ClippedUserSelectionContainerDelegate
    extends StaticSelectionContainerDelegate {
  bool _isClipped = false;
  bool get isClipped => _isClipped;
  double _lineHeightPx = 23.0;
  TextDirection _textDirection = TextDirection.ltr;

  void updateClipState({
    required bool isClipped,
    required double lineHeightPx,
    required TextDirection textDirection,
  }) {
    _isClipped = isClipped;
    _lineHeightPx = lineHeightPx;
    _textDirection = textDirection;
  }

  double get _bottomEdgeInset =>
      math.min(4.0, math.max(1.0, _lineHeightPx * 0.25));

  Offset _topLeadingGlobalPosition() {
    final containerToGlobal = getTransformTo(null);
    final leadingX = _textDirection == TextDirection.rtl
        ? containerSize.width
        : 0.0;
    final topY = math.min(1.0, containerSize.height * 0.5);
    return MatrixUtils.transformPoint(
      containerToGlobal,
      Offset(leadingX, topY),
    );
  }

  Offset _bottomTrailingGlobalPosition() {
    final containerToGlobal = getTransformTo(null);
    final trailingX = _textDirection == TextDirection.rtl
        ? 0.0
        : containerSize.width;
    final bottomY = math.max(0.0, containerSize.height - _bottomEdgeInset);
    return MatrixUtils.transformPoint(
      containerToGlobal,
      Offset(trailingX, bottomY),
    );
  }

  Offset _clampGlobalPositionToVisibleEdge(Offset globalPosition) {
    if (!_isClipped || !hasSize) {
      return globalPosition;
    }
    final containerToGlobal = getTransformTo(null);
    final globalToContainer = Matrix4.tryInvert(containerToGlobal);
    if (globalToContainer == null) {
      return globalPosition;
    }
    final local = MatrixUtils.transformPoint(globalToContainer, globalPosition);
    if (local.dy < containerSize.height) {
      return globalPosition;
    }
    return _bottomTrailingGlobalPosition();
  }

  bool _isSelectableBelowClip(Selectable selectable) {
    if (!_isClipped || !hasSize) {
      return false;
    }
    final toContainer = getTransformFrom(selectable);
    Rect? union;
    for (final box in selectable.boundingBoxes) {
      final mapped = MatrixUtils.transformRect(toContainer, box);
      union = union == null ? mapped : union.expandToInclude(mapped);
    }
    return union != null && union.top >= containerSize.height - 0.5;
  }

  @override
  SelectionResult dispatchSelectionEventToChild(
    Selectable selectable,
    SelectionEvent event,
  ) {
    if (event is! ClearSelectionEvent && _isSelectableBelowClip(selectable)) {
      selectable.dispatchSelectionEvent(const ClearSelectionEvent());
      return SelectionResult.end;
    }
    return super.dispatchSelectionEventToChild(selectable, event);
  }

  @override
  SelectionResult handleSelectAll(SelectAllSelectionEvent event) {
    if (!_isClipped || !hasSize || containerSize.isEmpty) {
      return super.handleSelectAll(event);
    }
    if (selectables.isEmpty) {
      return SelectionResult.none;
    }
    super.handleClearSelection(const ClearSelectionEvent());
    super.handleSelectionEdgeUpdate(
      SelectionEdgeUpdateEvent.forStart(
        globalPosition: _topLeadingGlobalPosition(),
      ),
    );
    super.handleSelectionEdgeUpdate(
      SelectionEdgeUpdateEvent.forEnd(
        globalPosition: _bottomTrailingGlobalPosition(),
      ),
    );
    return SelectionResult.none;
  }

  @override
  SelectionResult handleSelectionEdgeUpdate(SelectionEdgeUpdateEvent event) {
    if (!_isClipped || !hasSize) {
      return super.handleSelectionEdgeUpdate(event);
    }
    final clampedGlobal = _clampGlobalPositionToVisibleEdge(
      event.globalPosition,
    );
    if (clampedGlobal == event.globalPosition) {
      return super.handleSelectionEdgeUpdate(event);
    }
    final updated = event.type == SelectionEventType.startEdgeUpdate
        ? SelectionEdgeUpdateEvent.forStart(
            globalPosition: clampedGlobal,
            granularity: event.granularity,
          )
        : SelectionEdgeUpdateEvent.forEnd(
            globalPosition: clampedGlobal,
            granularity: event.granularity,
          );
    return super.handleSelectionEdgeUpdate(updated);
  }

  @override
  SelectionResult handleSelectWord(SelectWordSelectionEvent event) {
    if (_isClipped && hasSize) {
      final clamped = _clampGlobalPositionToVisibleEdge(event.globalPosition);
      if (clamped != event.globalPosition) {
        return SelectionResult.end;
      }
    }
    return super.handleSelectWord(event);
  }

  @override
  SelectionResult handleSelectParagraph(SelectParagraphSelectionEvent event) {
    if (_isClipped && hasSize) {
      final clamped = _clampGlobalPositionToVisibleEdge(event.globalPosition);
      if (clamped != event.globalPosition) {
        return SelectionResult.end;
      }
    }
    final result = super.handleSelectParagraph(event);
    _clampEndPointIfPastClip();
    return result;
  }

  @override
  SelectionResult handleGranularlyExtendSelection(
    GranularlyExtendSelectionEvent event,
  ) {
    final result = super.handleGranularlyExtendSelection(event);
    _clampEndPointIfPastClip();
    return result;
  }

  @override
  SelectionResult handleDirectionallyExtendSelection(
    DirectionallyExtendSelectionEvent event,
  ) {
    final result = super.handleDirectionallyExtendSelection(event);
    _clampEndPointIfPastClip();
    return result;
  }

  void _clampEndPointIfPastClip() {
    if (!_isClipped || !hasSize) {
      return;
    }
    final endPoint = value.endSelectionPoint;
    if (endPoint != null &&
        endPoint.localPosition.dy > containerSize.height + 0.5) {
      super.handleSelectionEdgeUpdate(
        SelectionEdgeUpdateEvent.forEnd(
          globalPosition: _bottomTrailingGlobalPosition(),
        ),
      );
    }
  }
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

/// Asynchronous bounded local-file [ImageProvider] for externalized user image
/// thumbnails and modal previews (`182735.smHt.RP` / `early-bootstrap-815`
/// bounded file reads + bounded `pendingNativeThumbnailCount` queue).
///
/// Unlike SDK [FileImage], which reads the entire file via
/// `ImmutableBuffer.fromFilePath` after only rejecting `length == 0`,
/// [BoundedLocalFileImage]:
/// 1. Asynchronously checks `File.stat()` before opening, requiring a regular
///    `FileSystemEntityType.file` (following symlinks while rejecting missing
///    paths, directories, FIFOs/pipes, sockets, and device nodes) whose size
///    satisfies `0 < size <= maxEncodedBytes`.
/// 2. Opens a single [RandomAccessFile] inside `try / finally`, re-verifies
///    `raf.length()` (`fstat`) on that descriptor, and reads in `<= 64 KiB`
///    chunks capped at `maxEncodedBytes + 1` bytes so concurrent mid-read file
///    growth aborts immediately without reading the remainder of the file.
/// 3. Bounds both concurrent encoded-byte loads ([maxConcurrentLoads] = 4) and
///    queued pending waiters ([maxPendingLoads] = 64, sized above normal
///    multi-message `16`-attachment working sets), retiring detached
///    queued/in-flight sessions on listener removal or widget disposal
///    ([retainWidgetInterest] / [releaseWidgetInterest]) and evicting failed
///    keys from [ImageCache] so later valid writes or remounts recover cleanly.
@immutable
class BoundedLocalFileImage extends ImageProvider<BoundedLocalFileImage> {
  const BoundedLocalFileImage(
    this.file, {
    this.scale = 1.0,
    this.maxEncodedBytes = OfficialCodexTheme.userImageMaxEncodedBytes,
  }) : assert(maxEncodedBytes > 0);

  static const int maxConcurrentLoads = 4;
  static const int maxPendingLoads = 64;
  static const int _maxReadChunkBytes = 64 * 1024;
  static int _activeLoads = 0;
  static final Queue<_BoundedImageLoadSession> _pendingLoadWaiters =
      Queue<_BoundedImageLoadSession>();
  static final Set<_BoundedImageLoadSession> _inFlightSessions =
      <_BoundedImageLoadSession>{};
  static final Map<String, int> _interestCountByPath = <String, int>{};

  final File file;
  final double scale;
  final int maxEncodedBytes;

  @visibleForTesting
  static int get debugActiveLoadCount => _activeLoads;

  @visibleForTesting
  static int get debugPendingLoadCount => _pendingLoadWaiters.length;

  @visibleForTesting
  static int get debugTrackedInterestCount => _interestCountByPath.length;

  /// Increments mounted widget interest for [path] so queued/in-flight reads
  /// can be retired immediately when all mounted tiles/dialogs for [path]
  /// dispose during virtualization scroll or thread switches.
  static void retainWidgetInterest(String path) {
    _interestCountByPath[path] = (_interestCountByPath[path] ?? 0) + 1;
  }

  /// Decrements mounted widget interest for [path]; when interest reaches `0`,
  /// retires any queued or in-flight load sessions for [path] and evicts
  /// pending [ImageCache] entries for [evictProviders] without disturbing
  /// already-decoded cached thumbnails.
  static void releaseWidgetInterest(
    String path, {
    Iterable<ImageProvider<Object>> evictProviders = const [],
  }) {
    final current = _interestCountByPath[path];
    if (current == null) {
      return;
    }
    if (current > 1) {
      _interestCountByPath[path] = current - 1;
      return;
    }
    _interestCountByPath.remove(path);

    var retiredPendingOrInFlight = false;
    final matchingQueued = _pendingLoadWaiters
        .where((session) => session.key.file.path == path)
        .toList(growable: false);
    for (final session in matchingQueued) {
      retiredPendingOrInFlight = true;
      _retireSession(
        session,
        reason: 'Local image load retired after widget disposal',
      );
    }
    final matchingInFlight = _inFlightSessions
        .where((session) => session.key.file.path == path)
        .toList(growable: false);
    for (final session in matchingInFlight) {
      retiredPendingOrInFlight = true;
      _retireSession(
        session,
        reason: 'Local image load retired after widget disposal',
      );
    }
    if (retiredPendingOrInFlight) {
      for (final provider in evictProviders) {
        unawaited(provider.evict());
      }
    }
  }

  static Future<bool> _acquireLoadSlot(_BoundedImageLoadSession session) {
    if (session.canceled) {
      return SynchronousFuture<bool>(false);
    }
    if (_activeLoads < maxConcurrentLoads) {
      _activeLoads += 1;
      session.hasActiveSlot = true;
      _inFlightSessions.add(session);
      return SynchronousFuture<bool>(true);
    }
    while (_pendingLoadWaiters.length >= maxPendingLoads) {
      _BoundedImageLoadSession? detachedVictim;
      for (final candidate in _pendingLoadWaiters) {
        if (candidate.canceled ||
            !_interestCountByPath.containsKey(candidate.key.file.path)) {
          detachedVictim = candidate;
          break;
        }
      }
      final victim = detachedVictim ?? _pendingLoadWaiters.first;
      _pendingLoadWaiters.remove(victim);
      victim.canceled = true;
      victim.cancelReason =
          'Local image load queue capacity exceeded ($maxPendingLoads pending)';
      final waiter = victim.waiter;
      victim.waiter = null;
      if (waiter != null && !waiter.isCompleted) {
        waiter.complete(false);
      }
    }
    final waiter = Completer<bool>();
    session.waiter = waiter;
    _pendingLoadWaiters.addLast(session);
    return waiter.future;
  }

  static void _retireSession(
    _BoundedImageLoadSession session, {
    required String reason,
  }) {
    session.canceled = true;
    session.cancelReason ??= reason;
    if (_pendingLoadWaiters.remove(session)) {
      final waiter = session.waiter;
      session.waiter = null;
      if (waiter != null && !waiter.isCompleted) {
        waiter.complete(false);
      }
    }
    // Never release an active slot while OS file I/O or engine codec work is
    // still running; if neither is active (e.g., retired between phases in a
    // FakeAsync zone), release the idle slot immediately.
    if (session.hasActiveSlot && !session.inIo && !session.inDecode) {
      _releaseLoadSlot(session);
    }
  }

  static void _releaseLoadSlot(_BoundedImageLoadSession completedSession) {
    if (!completedSession.hasActiveSlot) {
      return;
    }
    completedSession.hasActiveSlot = false;
    _inFlightSessions.remove(completedSession);
    while (_pendingLoadWaiters.isNotEmpty) {
      final next = _pendingLoadWaiters.removeFirst();
      final waiter = next.waiter;
      next.waiter = null;
      if (next.canceled || waiter == null || waiter.isCompleted) {
        if (waiter != null && !waiter.isCompleted) {
          waiter.complete(false);
        }
        continue;
      }
      next.hasActiveSlot = true;
      _inFlightSessions.add(next);
      waiter.complete(true);
      return;
    }
    if (_activeLoads > 0) {
      _activeLoads -= 1;
    }
  }

  @override
  Future<BoundedLocalFileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<BoundedLocalFileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    BoundedLocalFileImage key,
    ImageDecoderCallback decode,
  ) {
    final session = _BoundedImageLoadSession(key: key);
    final completer = MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, session: session, decode: decode),
      scale: key.scale,
      debugLabel: key.file.path,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Path: ${file.path}'),
        IntProperty('maxEncodedBytes', maxEncodedBytes),
      ],
    );
    completer.addOnLastListenerRemovedCallback(() {
      _retireSession(
        session,
        reason: 'Local image load retired after last listener detached',
      );
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
    });
    completer.addEphemeralErrorListener((Object error, StackTrace? stackTrace) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
    });
    return completer;
  }

  /// Reads at most [maxEncodedBytes] encoded image bytes from [file], throwing
  /// a [FileSystemException] or [StateError] when missing, non-regular, empty,
  /// canceled via [isCanceled], or larger than [maxEncodedBytes].
  @visibleForTesting
  static Future<Uint8List> readBoundedEncodedBytes(
    File file, {
    int maxEncodedBytes = OfficialCodexTheme.userImageMaxEncodedBytes,
    bool Function()? isCanceled,
  }) async {
    if (maxEncodedBytes <= 0) {
      throw RangeError.value(maxEncodedBytes, 'maxEncodedBytes');
    }
    if (isCanceled != null && isCanceled()) {
      throw StateError('Local image load canceled: ${file.path}');
    }
    final stat = await file.stat();
    if (isCanceled != null && isCanceled()) {
      throw StateError('Local image load canceled: ${file.path}');
    }
    if (stat.type == FileSystemEntityType.notFound) {
      throw PathNotFoundException(
        file.path,
        const OSError('Local image file does not exist'),
      );
    }
    if (stat.type != FileSystemEntityType.file) {
      throw FileSystemException(
        'Local image path is not a regular file (${stat.type})',
        file.path,
      );
    }
    if (stat.size <= 0) {
      throw StateError('Local image file is empty: ${file.path}');
    }
    if (stat.size > maxEncodedBytes) {
      throw FileSystemException(
        'Local image exceeds $maxEncodedBytes-byte preview limit (${stat.size} bytes)',
        file.path,
      );
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      if (isCanceled != null && isCanceled()) {
        throw StateError('Local image load canceled: ${file.path}');
      }
      final openedLength = await raf.length();
      if (openedLength <= 0) {
        throw StateError('Local image file is empty: ${file.path}');
      }
      if (openedLength > maxEncodedBytes) {
        throw FileSystemException(
          'Local image exceeds $maxEncodedBytes-byte preview limit ($openedLength bytes)',
          file.path,
        );
      }

      final builder = BytesBuilder(copy: false);
      var totalRead = 0;
      final readCap = maxEncodedBytes + 1;
      while (totalRead < readCap) {
        if (isCanceled != null && isCanceled()) {
          throw StateError('Local image load canceled: ${file.path}');
        }
        final requestBytes = math.min(_maxReadChunkBytes, readCap - totalRead);
        final chunk = await raf.read(requestBytes);
        if (chunk.isEmpty) {
          break;
        }
        totalRead += chunk.length;
        if (totalRead > maxEncodedBytes) {
          throw FileSystemException(
            'Local image grew past $maxEncodedBytes-byte preview limit while reading',
            file.path,
          );
        }
        builder.add(chunk);
      }
      if (totalRead == 0) {
        throw StateError('Local image file is empty: ${file.path}');
      }
      return builder.takeBytes();
    } finally {
      await raf.close();
    }
  }

  Future<ui.Codec> _loadAsync(
    BoundedLocalFileImage key, {
    required _BoundedImageLoadSession session,
    required ImageDecoderCallback decode,
  }) async {
    assert(key == this);
    final acquired = await _acquireLoadSlot(session);
    if (!acquired) {
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError(
        session.cancelReason ?? 'Local image load canceled: ${file.path}',
      );
    }
    if (session.canceled) {
      _releaseLoadSlot(session);
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError(
        session.cancelReason ?? 'Local image load canceled: ${file.path}',
      );
    }
    try {
      session.inIo = true;
      final ioCompleter =
          Completer<({Uint8List? bytes, Object? error, StackTrace? stack})>();
      Zone.root.run(() async {
        try {
          final data = await readBoundedEncodedBytes(
            file,
            maxEncodedBytes: maxEncodedBytes,
            isCanceled: () => session.canceled,
          );
          session.inIo = false;
          if (session.canceled) {
            _releaseLoadSlot(session);
            ioCompleter.complete((
              bytes: null,
              error: StateError(
                session.cancelReason ??
                    'Local image load canceled: ${file.path}',
              ),
              stack: StackTrace.current,
            ));
            return;
          }
          ioCompleter.complete((bytes: data, error: null, stack: null));
        } on Object catch (error, stackTrace) {
          session.inIo = false;
          _releaseLoadSlot(session);
          ioCompleter.complete((bytes: null, error: error, stack: stackTrace));
        }
      });

      final ioResult = await ioCompleter.future;
      if (ioResult.error != null) {
        PaintingBinding.instance.imageCache.evict(key);
        Error.throwWithStackTrace(ioResult.error!, ioResult.stack!);
      }
      final bytes = ioResult.bytes!;
      if (session.canceled) {
        PaintingBinding.instance.imageCache.evict(key);
        throw StateError(
          session.cancelReason ?? 'Local image load canceled: ${file.path}',
        );
      }

      session.inDecode = true;
      try {
        final ui.ImmutableBuffer buffer;
        try {
          buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        } on Object {
          PaintingBinding.instance.imageCache.evict(key);
          rethrow;
        }
        // Ownership of `buffer` transfers to `decode` (`instantiateImageCodecWithSize`
        // disposes `buffer` in its `finally` block; see `dart:ui` painting.dart).
        try {
          return await decode(buffer);
        } on Object {
          PaintingBinding.instance.imageCache.evict(key);
          rethrow;
        }
      } finally {
        session.inDecode = false;
      }
    } finally {
      _releaseLoadSlot(session);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoundedLocalFileImage &&
          other.runtimeType == runtimeType &&
          other.file.path == file.path &&
          other.scale == scale &&
          other.maxEncodedBytes == maxEncodedBytes);

  @override
  int get hashCode => Object.hash(file.path, scale, maxEncodedBytes);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'BoundedLocalFileImage')}("${file.path}", '
      'scale: ${scale.toStringAsFixed(1)}, maxEncodedBytes: $maxEncodedBytes)';
}

final class _BoundedImageLoadSession {
  _BoundedImageLoadSession({required this.key});

  final BoundedLocalFileImage key;
  Completer<bool>? waiter;
  bool hasActiveSlot = false;
  bool inIo = false;
  bool inDecode = false;
  bool canceled = false;
  String? cancelReason;
}
