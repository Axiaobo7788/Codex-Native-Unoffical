import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../app/theme/official_codex_theme.dart';

/// Renders bounded Desktop Markdown in a single AST pass using the official
/// Codex Desktop screen-CSS geometry for root edges, block adjacency, tight
/// and loose lists, blockquotes, tables, horizontal rules, and code blocks.
class DesktopMarkdownBody extends StatefulWidget {
  const DesktopMarkdownBody({
    super.key,
    required this.data,
    required this.styleSheet,
    required this.extensionSet,
    required this.builders,
    required this.imageBuilder,
    required this.onTapLink,
    required this.bodyEm,
    this.borderMedium = OfficialCodexTheme.lightControlBorderStrong,
    this.borderLight = OfficialCodexTheme.lightControlBorder,
    this.inlineCodeBackground = OfficialCodexTheme.lightInlineCodeBackground,
    this.inlineCodeRadius = OfficialCodexTheme.inlineCodeRadius,
    this.inlineCodeHorizontalPadding =
        OfficialCodexTheme.inlineCodeHorizontalPadding,
    this.inlineCodeVerticalPadding =
        OfficialCodexTheme.inlineCodeVerticalPadding,
    this.inlineCodeFontScale = OfficialCodexTheme.inlineCodeFontScale,
    this.maxInlineCodePills = OfficialCodexTheme.maxInlineCodePills,
  });

  final String data;
  final MarkdownStyleSheet styleSheet;
  final md.ExtensionSet extensionSet;
  final Map<String, MarkdownElementBuilder> builders;
  final MarkdownImageBuilder imageBuilder;
  final MarkdownTapLinkCallback onTapLink;
  final double bodyEm;
  final Color borderMedium;
  final Color borderLight;
  final Color inlineCodeBackground;
  final double inlineCodeRadius;
  final double inlineCodeHorizontalPadding;
  final double inlineCodeVerticalPadding;
  final double inlineCodeFontScale;
  final int maxInlineCodePills;

  @override
  State<DesktopMarkdownBody> createState() => _DesktopMarkdownBodyState();
}

class _DesktopMarkdownBodyState extends State<DesktopMarkdownBody> {
  static const _blockTags = <String>{
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'ul',
    'ol',
    'blockquote',
    'pre',
    'table',
    'hr',
  };

  final _recognizers = <TapGestureRecognizer>[];
  final _activeLinks = <_ActiveMarkdownLink>[];
  var _preDepth = 0;
  var _inlineCodePillCount = 0;
  var _needsRebuild = true;
  bool? _builtWithFiniteWidth;
  double? _lastMaxWidth;
  var _minValidRootMaxWidth = 0.0;
  var _maxValidRootMaxWidth = double.infinity;
  TextStyle? _lastDefaultTextStyle;
  TextScaler? _lastTextScaler;
  Locale? _lastLocale;
  var _currentAvailableWidth = double.infinity;
  var _currentWidthInset = 0.0;
  var _currentDefaultTextStyle = const TextStyle();
  var _currentTextScaler = TextScaler.noScaling;
  Locale? _currentLocale;
  BuildContext? _currentMarkdownContext;
  List<Widget> _children = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _needsRebuild = true;
  }

  @override
  void didUpdateWidget(covariant DesktopMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data ||
        widget.styleSheet != oldWidget.styleSheet ||
        widget.bodyEm != oldWidget.bodyEm ||
        widget.borderMedium != oldWidget.borderMedium ||
        widget.borderLight != oldWidget.borderLight ||
        widget.inlineCodeBackground != oldWidget.inlineCodeBackground ||
        widget.inlineCodeRadius != oldWidget.inlineCodeRadius ||
        widget.inlineCodeHorizontalPadding !=
            oldWidget.inlineCodeHorizontalPadding ||
        widget.inlineCodeVerticalPadding !=
            oldWidget.inlineCodeVerticalPadding ||
        widget.inlineCodeFontScale != oldWidget.inlineCodeFontScale ||
        widget.maxInlineCodePills != oldWidget.maxInlineCodePills) {
      _needsRebuild = true;
    }
  }

  T _withContainerWidth<T>({
    required double availableWidth,
    required double widthInset,
    required T Function() action,
  }) {
    final previousWidth = _currentAvailableWidth;
    final previousInset = _currentWidthInset;
    _currentAvailableWidth = availableWidth;
    _currentWidthInset = widthInset;
    try {
      return action();
    } finally {
      _currentAvailableWidth = previousWidth;
      _currentWidthInset = previousInset;
    }
  }

  void _recordRootWidthThreshold({
    required bool fits,
    required double thresholdRootWidth,
  }) {
    if (!thresholdRootWidth.isFinite) {
      return;
    }
    const subpixelCushion = 1.0;
    if (fits) {
      _minValidRootMaxWidth = math.max(
        _minValidRootMaxWidth,
        thresholdRootWidth + subpixelCushion,
      );
    } else {
      _maxValidRootMaxWidth = math.min(
        _maxValidRootMaxWidth,
        math.max(0.0, thresholdRootWidth - subpixelCushion),
      );
    }
  }

  double _measureSingleLineWidth(
    String text,
    TextStyle style,
    TextScaler textScaler,
    Locale? locale,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      locale: locale,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  void _buildBlocks({
    required BuildContext markdownContext,
    required double maxWidth,
    required TextStyle defaultTextStyle,
    required TextScaler textScaler,
    required Locale? locale,
  }) {
    _disposeRecognizers();
    _activeLinks.clear();
    _preDepth = 0;
    _inlineCodePillCount = 0;
    _builtWithFiniteWidth = maxWidth.isFinite;
    _minValidRootMaxWidth = 0.0;
    _maxValidRootMaxWidth = double.infinity;
    _currentAvailableWidth = maxWidth;
    _currentWidthInset = 0.0;
    _currentDefaultTextStyle = defaultTextStyle;
    _currentTextScaler = textScaler;
    _currentLocale = locale;
    _currentMarkdownContext = markdownContext;
    try {
      if (widget.data.isEmpty) {
        _children = const [];
        return;
      }
      final document = md.Document(
        extensionSet: widget.extensionSet,
        encodeHtml: false,
      );
      final nodes = document.parseLines(
        const LineSplitter().convert(widget.data),
      );
      if (nodes.isEmpty) {
        _children = const [];
        return;
      }

      final zeroBuilder = _builder(widget.styleSheet.copyWith(blockSpacing: 0));
      final headingBuilders = <String, MarkdownBuilder>{};
      MarkdownBuilder getHeadingBuilder(String tag) =>
          headingBuilders.putIfAbsent(
            tag,
            () => _builder(
              widget.styleSheet.copyWith(
                blockSpacing: 0,
                p: widget.styleSheet.styles[tag] ?? widget.styleSheet.p,
              ),
            ),
          );
      MarkdownBuilder? blockquoteParagraphBuilder;
      MarkdownBuilder getBlockquoteParagraphBuilder() =>
          blockquoteParagraphBuilder ??= _builder(
            widget.styleSheet.copyWith(
              blockSpacing: 0,
              p: widget.styleSheet.p?.copyWith(fontWeight: FontWeight.w400),
            ),
          );

      var blockquoteIndex = 0;
      var tableIndex = 0;
      var hrIndex = 0;

      Widget buildNode(
        md.Node node, {
        required int listDepth,
        required bool insideBlockquote,
        required double availableWidth,
        required double widthInset,
      }) {
        if (node is md.Element) {
          switch (node.tag) {
            case 'ul' || 'ol':
              return _buildList(
                node,
                listDepth: listDepth,
                insideBlockquote: insideBlockquote,
                availableWidth: availableWidth,
                widthInset: widthInset,
                textScaler: textScaler,
                buildChildNode: buildNode,
              );
            case 'blockquote':
              final currentIndex = blockquoteIndex++;
              return _buildBlockquote(
                node,
                index: currentIndex,
                listDepth: listDepth,
                availableWidth: availableWidth,
                widthInset: widthInset,
                buildChildNode: buildNode,
              );
            case 'table':
              final currentIndex = tableIndex++;
              return _withContainerWidth(
                availableWidth: double.infinity,
                widthInset: 0.0,
                action: () => _buildTable(node, index: currentIndex),
              );
            case 'hr':
              final currentIndex = hrIndex++;
              return _buildHorizontalRule(index: currentIndex);
            case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
              return _wrapBuilt(
                _withContainerWidth(
                  availableWidth: availableWidth,
                  widthInset: widthInset,
                  action: () => getHeadingBuilder(node.tag).build([node]),
                ),
              );
            case 'p' when insideBlockquote:
              return _wrapBuilt(
                _withContainerWidth(
                  availableWidth: availableWidth,
                  widthInset: widthInset,
                  action: () => getBlockquoteParagraphBuilder().build([node]),
                ),
              );
          }
        }
        final normalized = node is md.Text ? md.Element('p', [node]) : node;
        return _wrapBuilt(
          _withContainerWidth(
            availableWidth: availableWidth,
            widthInset: widthInset,
            action: () => zeroBuilder.build([normalized]),
          ),
        );
      }

      final blocks = <Widget>[
        for (final node in nodes)
          buildNode(
            node,
            listDepth: 0,
            insideBlockquote: false,
            availableWidth: maxWidth,
            widthInset: 0.0,
          ),
      ];
      final tags = nodes.map(_nodeTag).toList(growable: false);

      // MarkdownRoot carries `[&>*:first-child]:mt-0 [&>*:last-child]:mb-0`, so
      // outer top and bottom margins at root edges collapse to 0.
      _children = [
        for (var index = 0; index < nodes.length; index++) ...[
          if (index > 0)
            SizedBox(
              key: ValueKey('desktop-markdown-gap-$index'),
              height: _adjacentGap(tags, index),
            ),
          blocks[index],
        ],
      ];
    } finally {
      _currentMarkdownContext = null;
    }
  }

  Widget _wrapBuilt(List<Widget> built) {
    if (built.isEmpty) {
      return const SizedBox.shrink();
    }
    if (built.length == 1) {
      return built.single;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: built,
    );
  }

  Widget _buildList(
    md.Element listElement, {
    required int listDepth,
    required bool insideBlockquote,
    required double availableWidth,
    required double widthInset,
    required TextScaler textScaler,
    required Widget Function(
      md.Node node, {
      required int listDepth,
      required bool insideBlockquote,
      required double availableWidth,
      required double widthInset,
    })
    buildChildNode,
  }) {
    final isOrdered = listElement.tag == 'ol';
    final start = int.tryParse(listElement.attributes['start'] ?? '') ?? 1;
    final space = widget.bodyEm / 4;
    final markerGutterWidth = widget.bodyEm * 1.625;
    final markerGap = space * 1.5;
    final baseStyle = _currentDefaultTextStyle;
    final markerStyle = baseStyle.copyWith(
      color: baseStyle.color,
      fontWeight: FontWeight.w600,
    );

    final rawItems = (listElement.children ?? const <md.Node>[])
        .whereType<md.Element>()
        .where((child) => child.tag == 'li')
        .toList(growable: false);
    if (rawItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = <Widget>[];
    for (var itemIndex = 0; itemIndex < rawItems.length; itemIndex++) {
      final item = rawItems[itemIndex];
      final (:blocks, :taskChecked) = _normalizeListItemBlocks(item);

      final Widget marker;
      final double markerBoxWidth;
      if (taskChecked != null) {
        final topInset = math.max(
          0.0,
          (widget.bodyEm * 1.625 - widget.bodyEm) / 2,
        );
        marker = Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Icon(
            taskChecked
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            size: widget.bodyEm,
            color: taskChecked ? baseStyle.color : widget.borderMedium,
          ),
        );
        markerBoxWidth = math.max(markerGutterWidth, widget.bodyEm);
      } else if (isOrdered) {
        final markerLabel = '${start + itemIndex}.';
        marker = Text(
          markerLabel,
          textAlign: TextAlign.right,
          style: markerStyle,
        );
        markerBoxWidth = math.max(
          markerGutterWidth,
          _measureSingleLineWidth(
            markerLabel,
            markerStyle,
            textScaler,
            _currentLocale,
          ),
        );
      } else {
        final bullet = switch (listDepth) {
          0 => '•',
          1 => '◦',
          _ => '▪',
        };
        marker = Text(bullet, textAlign: TextAlign.right, style: markerStyle);
        markerBoxWidth = math.max(
          markerGutterWidth,
          _measureSingleLineWidth(
            bullet,
            markerStyle,
            textScaler,
            _currentLocale,
          ),
        );
      }

      final itemDelta = markerBoxWidth + markerGap;
      final itemAvailableWidth = availableWidth.isFinite
          ? math.max(0.0, availableWidth - itemDelta)
          : double.infinity;
      final itemWidthInset = widthInset + itemDelta;

      final itemWidgets = <Widget>[];
      final childTags = blocks.map(_nodeTag).toList(growable: false);
      for (var childIdx = 0; childIdx < blocks.length; childIdx++) {
        if (childIdx > 0) {
          final gap = _listItemChildGap(
            childTags[childIdx - 1],
            childTags[childIdx],
          );
          if (gap > 0) {
            itemWidgets.add(SizedBox(height: gap));
          }
        }
        final childNode = blocks[childIdx];
        final isNestedList =
            childNode is md.Element &&
            (childNode.tag == 'ul' || childNode.tag == 'ol');
        itemWidgets.add(
          buildChildNode(
            childNode,
            listDepth: isNestedList ? listDepth + 1 : listDepth,
            insideBlockquote: insideBlockquote,
            availableWidth: itemAvailableWidth,
            widthInset: itemWidthInset,
          ),
        );
      }

      // `.ListItem + .ListItem { margin-top: 0 }` holds for both tight and loose lists.
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: markerGutterWidth),
              child: Align(alignment: Alignment.topRight, child: marker),
            ),
            SizedBox(width: markerGap),
            Expanded(
              child: itemWidgets.length == 1
                  ? itemWidgets.single
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: itemWidgets,
                    ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  ({List<md.Node> blocks, bool? taskChecked}) _normalizeListItemBlocks(
    md.Element item,
  ) {
    final normalized = _normalizeContainerChildren(
      item.children ?? const <md.Node>[],
    );
    bool? taskChecked;
    if (normalized.isNotEmpty) {
      final first = normalized.first;
      if (first is md.Element &&
          first.tag == 'p' &&
          first.children != null &&
          first.children!.isNotEmpty) {
        final firstInline = first.children!.first;
        if (firstInline is md.Element &&
            firstInline.tag == 'input' &&
            firstInline.attributes['type'] == 'checkbox') {
          taskChecked =
              firstInline.attributes.containsKey('checked') &&
              firstInline.attributes['checked'] != 'false';
          final remaining = <md.Node>[...first.children!.skip(1)];
          if (remaining.isNotEmpty && remaining.first is md.Text) {
            final text = (remaining.first as md.Text).text;
            if (text.startsWith(' ')) {
              final trimmed = text.substring(1);
              if (trimmed.isEmpty) {
                remaining.removeAt(0);
              } else {
                remaining[0] = md.Text(trimmed);
              }
            }
          }
          normalized[0] = md.Element('p', remaining);
        }
      }
    }
    return (blocks: normalized, taskChecked: taskChecked);
  }

  List<md.Node> _normalizeContainerChildren(List<md.Node> rawChildren) {
    final blocks = <md.Node>[];
    var inlineRun = <md.Node>[];

    void flushInline() {
      if (inlineRun.isEmpty) {
        return;
      }
      final hasNonWhitespace = inlineRun.any(
        (node) => node is! md.Text || node.text.trim().isNotEmpty,
      );
      if (hasNonWhitespace) {
        blocks.add(md.Element('p', inlineRun));
      }
      inlineRun = <md.Node>[];
    }

    for (final child in rawChildren) {
      if (child is md.Element && _blockTags.contains(child.tag)) {
        flushInline();
        blocks.add(child);
      } else {
        inlineRun.add(child);
      }
    }
    flushInline();
    return blocks;
  }

  double _listItemChildGap(String? previousTag, String? currentTag) {
    final space = widget.bodyEm / 4;
    if (previousTag == 'p' && currentTag == 'p') {
      // `:is(.ListItem, [data-markdown-list-item-content]) > p + p { margin-top: 4 * S }`
      return 4 * space;
    }
    if (previousTag == 'ul' ||
        previousTag == 'ol' ||
        currentTag == 'ul' ||
        currentTag == 'ol') {
      return 0;
    }
    final prevBottom = _containerChildMargins(previousTag).bottom;
    final currTop = _containerChildMargins(currentTag).top;
    return math.max(prevBottom, currTop) * space;
  }

  ({double top, double bottom}) _containerChildMargins(String? tag) =>
      switch (tag) {
        'p' || 'ul' || 'ol' || 'h5' || 'h6' => (top: 0, bottom: 0),
        'h1' => (top: 4, bottom: 2),
        'h2' || 'h3' => (top: 4, bottom: 1),
        'h4' => (top: 4, bottom: 0),
        'blockquote' => (top: 0, bottom: 2),
        'pre' => (top: 5, bottom: 5),
        'table' => (top: 4, bottom: 0),
        'hr' => (top: 7, bottom: 7),
        _ => (top: 0, bottom: 0),
      };

  Widget _buildBlockquote(
    md.Element blockquote, {
    required int index,
    required int listDepth,
    required double availableWidth,
    required double widthInset,
    required Widget Function(
      md.Node node, {
      required int listDepth,
      required bool insideBlockquote,
      required double availableWidth,
      required double widthInset,
    })
    buildChildNode,
  }) {
    final space = widget.bodyEm / 4;
    final quoteDelta = space * 6;
    final childAvailableWidth = availableWidth.isFinite
        ? math.max(0.0, availableWidth - quoteDelta)
        : double.infinity;
    final childWidthInset = widthInset + quoteDelta;
    final blocks = _normalizeContainerChildren(
      blockquote.children ?? const <md.Node>[],
    );
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    final tags = blocks.map(_nodeTag).toList(growable: false);
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) {
        // `.Blockquote > .Paragraph { margin: 0 }` overrides `.Paragraph + .Paragraph`.
        final gap =
            math.max(
              _containerChildMargins(tags[i - 1]).bottom,
              _containerChildMargins(tags[i]).top,
            ) *
            space;
        if (gap > 0) {
          children.add(SizedBox(height: gap));
        }
      }
      children.add(
        buildChildNode(
          blocks[i],
          listDepth: listDepth,
          insideBlockquote: true,
          availableWidth: childAvailableWidth,
          widthInset: childWidthInset,
        ),
      );
    }

    return Stack(
      key: ValueKey('desktop-markdown-blockquote-$index'),
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: space * 6,
            top: space * 2,
            bottom: space * 2,
          ),
          child: children.length == 1
              ? children.single
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
        ),
        Positioned(
          left: 0,
          top: space * 2,
          bottom: space * 2,
          width: space,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.borderMedium,
              borderRadius: BorderRadius.circular(space / 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(md.Element tableElement, {required int index}) {
    final headerRows = <md.Element>[];
    final bodyRows = <md.Element>[];
    for (final section
        in (tableElement.children ?? const <md.Node>[])
            .whereType<md.Element>()) {
      if (section.tag == 'thead') {
        headerRows.addAll(
          (section.children ?? const <md.Node>[]).whereType<md.Element>().where(
            (row) => row.tag == 'tr',
          ),
        );
      } else if (section.tag == 'tbody') {
        bodyRows.addAll(
          (section.children ?? const <md.Node>[]).whereType<md.Element>().where(
            (row) => row.tag == 'tr',
          ),
        );
      } else if (section.tag == 'tr') {
        bodyRows.add(section);
      }
    }

    var columnCount = 0;
    for (final row in [...headerRows, ...bodyRows]) {
      final count = (row.children ?? const <md.Node>[])
          .whereType<md.Element>()
          .where((cell) => cell.tag == 'th' || cell.tag == 'td')
          .length;
      if (count > columnCount) {
        columnCount = count;
      }
    }
    if (columnCount == 0) {
      return const SizedBox.shrink();
    }

    final space = widget.bodyEm / 4;
    final baseStyle = _currentDefaultTextStyle;
    final baseFontSize = baseStyle.fontSize ?? OfficialCodexTheme.chatFontSize;
    final smallFontSize = math.max(12.0, baseFontSize * 0.875);
    final headerStyle = baseStyle.copyWith(
      fontSize: smallFontSize,
      height: baseFontSize / smallFontSize,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final cellStyle = baseStyle.copyWith(
      fontSize: smallFontSize,
      height: (baseFontSize * 1.625) / smallFontSize,
      fontWeight: FontWeight.w400,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final inlineCodeStyle = widget.styleSheet.code?.copyWith(
      fontSize: smallFontSize * widget.inlineCodeFontScale,
    );
    final linkStyle = widget.styleSheet.a?.copyWith(fontSize: smallFontSize);

    final buildersCache = <(bool, WrapAlignment), MarkdownBuilder>{};
    MarkdownBuilder cellBuilder({
      required bool isHeader,
      required WrapAlignment textAlign,
    }) => buildersCache.putIfAbsent(
      (isHeader, textAlign),
      () => _builder(
        widget.styleSheet.copyWith(
          blockSpacing: 0,
          p: isHeader ? headerStyle : cellStyle,
          a: linkStyle,
          code: inlineCodeStyle,
          textAlign: textAlign,
        ),
      ),
    );

    Widget buildCell(
      md.Element? cell, {
      required bool isHeader,
      required bool isLastColumn,
      required bool isLastBodyRow,
    }) {
      final alignAttr = cell?.attributes['align'];
      final (wrapAlign, boxAlign) = switch (alignAttr) {
        'center' => (WrapAlignment.center, Alignment.topCenter),
        'right' => (WrapAlignment.end, Alignment.topRight),
        _ => (WrapAlignment.start, Alignment.topLeft),
      };
      final inlineChildren = cell?.children ?? const <md.Node>[];
      final Widget content;
      if (inlineChildren.isEmpty) {
        content = const SizedBox.shrink();
      } else {
        final built = cellBuilder(
          isHeader: isHeader,
          textAlign: wrapAlign,
        ).build([md.Element('p', inlineChildren)]);
        content = _wrapBuilt(built);
      }

      final padding = isHeader
          ? EdgeInsets.only(
              top: space * 2,
              bottom: space * 2,
              right: isLastColumn ? space * 10 : space * 6,
            )
          : EdgeInsets.only(
              top: space * 2.5,
              bottom: isLastBodyRow ? space * 6 : space * 2.5,
              right: space * 6,
            );

      return Padding(
        padding: padding,
        child: Align(alignment: boxAlign, child: content),
      );
    }

    final tableRows = <TableRow>[];
    for (final row in headerRows) {
      final cells = (row.children ?? const <md.Node>[])
          .whereType<md.Element>()
          .where((cell) => cell.tag == 'th' || cell.tag == 'td')
          .toList(growable: false);
      tableRows.add(
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: widget.borderMedium, width: 1),
            ),
          ),
          children: [
            for (var col = 0; col < columnCount; col++)
              buildCell(
                col < cells.length ? cells[col] : null,
                isHeader: true,
                isLastColumn: col == columnCount - 1,
                isLastBodyRow: false,
              ),
          ],
        ),
      );
    }

    for (var rowIdx = 0; rowIdx < bodyRows.length; rowIdx++) {
      final isLastBodyRow = rowIdx == bodyRows.length - 1;
      final cells = (bodyRows[rowIdx].children ?? const <md.Node>[])
          .whereType<md.Element>()
          .where((cell) => cell.tag == 'th' || cell.tag == 'td')
          .toList(growable: false);
      tableRows.add(
        TableRow(
          decoration: isLastBodyRow
              ? null
              : BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: widget.borderLight, width: 1),
                  ),
                ),
          children: [
            for (var col = 0; col < columnCount; col++)
              buildCell(
                col < cells.length ? cells[col] : null,
                isHeader: false,
                isLastColumn: col == columnCount - 1,
                isLastBodyRow: isLastBodyRow,
              ),
          ],
        ),
      );
    }

    final tableWidget = Table(
      key: ValueKey('desktop-markdown-table-$index'),
      defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: tableRows,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: tableWidget,
          ),
        );
      },
    );
  }

  Widget _buildHorizontalRule({required int index}) => SizedBox(
    key: ValueKey('desktop-markdown-hr-$index'),
    width: double.infinity,
    height: 1,
    child: DecoratedBox(decoration: BoxDecoration(color: widget.borderMedium)),
  );

  MarkdownBuilder _builder(MarkdownStyleSheet styleSheet) {
    final mergedBuilders = <String, MarkdownElementBuilder>{
      ...widget.builders,
      'pre': _PreScopeElementBuilder(
        delegate: widget.builders['pre'],
        onEnter: () => _preDepth++,
        onExit: () {
          if (_preDepth > 0) {
            _preDepth--;
          }
        },
      ),
      'code': _DesktopInlineCodeBuilder(
        delegate: widget.builders['code'],
        isInsidePre: () => _preDepth > 0,
        hasPillSlot: () => _inlineCodePillCount < widget.maxInlineCodePills,
        consumePillSlot: () {
          _inlineCodePillCount++;
        },
        availableWidth: () => _currentAvailableWidth,
        widthInset: () => _currentWidthInset,
        recordWidthThreshold: _recordRootWidthThreshold,
        defaultTextStyle: () => _currentDefaultTextStyle,
        textScaler: () => _currentTextScaler,
        locale: () => _currentLocale,
        currentLink: () => _activeLinks.isEmpty ? null : _activeLinks.last,
        obtainLinkRecognizer: (link) =>
            link.recognizer ??= _createLink(link.text, link.href, link.title),
        onTapLink: (text, href, title) => widget.onTapLink(text, href, title),
        fallbackStyle: styleSheet.p,
        backgroundColor: widget.inlineCodeBackground,
        borderRadius: widget.inlineCodeRadius,
        horizontalPadding: widget.inlineCodeHorizontalPadding,
        verticalPadding: widget.inlineCodeVerticalPadding,
        fontScale: widget.inlineCodeFontScale,
      ),
    };
    return MarkdownBuilder(
      delegate: _DesktopMarkdownDelegate(
        context: _currentMarkdownContext ?? context,
        onCreateLink: _createLink,
        onFormatText: _formatText,
      ),
      selectable: false,
      styleSheet: styleSheet,
      imageDirectory: null,
      checkboxBuilder: null,
      bulletBuilder: null,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
      builders: mergedBuilders,
      paddingBuilders: {
        if (!widget.builders.containsKey('a'))
          'a': _LinkScopePaddingBuilder(activeLinks: _activeLinks),
      },
      imageBuilder: widget.imageBuilder,
      fitContent: true,
    );
  }

  String? _nodeTag(md.Node node) {
    if (node is md.Element) {
      return node.tag;
    }
    if (node is md.Text && node.text.trim().isNotEmpty) {
      return 'p';
    }
    return null;
  }

  double _adjacentGap(List<String?> tags, int index) {
    final previous = _margins(
      tags[index - 1],
      index > 1 ? tags[index - 2] : null,
    );
    final current = _margins(tags[index], tags[index - 1]);
    if (previous == null || current == null) {
      return widget.styleSheet.blockSpacing ?? 10;
    }
    return math.max(previous.bottom, current.top) * widget.bodyEm / 4;
  }

  ({double top, double bottom})? _margins(String? tag, String? previous) =>
      switch (tag) {
        'p' when previous == 'p' => (top: 4, bottom: 4),
        'p' when previous == 'h1' || previous == 'h2' || previous == 'h3' => (
          top: 0,
          bottom: 1,
        ),
        'p' => (top: 2, bottom: 1),
        'ul' || 'ol' => (top: 0, bottom: 0),
        'h1' when previous == 'hr' => (top: 0, bottom: 2),
        'h1' => (top: 4, bottom: 2),
        'h2' || 'h3' when previous == 'hr' => (top: 0, bottom: 1),
        'h2' || 'h3' => (top: 4, bottom: 1),
        'h4' when previous == 'hr' => (top: 0, bottom: 0),
        'h4' => (top: 4, bottom: 0),
        'h5' ||
        'h6' when previous == 'ul' || previous == 'ol' => (top: 4, bottom: 0),
        'h5' || 'h6' => (top: 0, bottom: 0),
        'blockquote' => (top: 0, bottom: 2),
        'pre' when previous == 'hr' => (top: 0, bottom: 5),
        'pre' => (top: 5, bottom: 5),
        'table' when previous == 'hr' => (top: 0, bottom: 0),
        'table' => (top: 4, bottom: 0),
        'hr' => (top: 7, bottom: 7),
        _ => null,
      };

  GestureRecognizer _createLink(String text, String? href, String title) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => widget.onTapLink(text, href, title);
    _recognizers.add(recognizer);
    if (_activeLinks.isNotEmpty) {
      final current = _activeLinks.last;
      if (current.recognizer == null &&
          current.text == text &&
          current.href == href &&
          current.title == title) {
        current.recognizer = recognizer;
      }
    }
    return recognizer;
  }

  TextSpan _formatText(MarkdownStyleSheet styleSheet, String code) => TextSpan(
    text: code.endsWith('\n') ? code.substring(0, code.length - 1) : code,
    style: styleSheet.code,
  );

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDefaultStyle = DefaultTextStyle.of(context).style
        .merge(widget.styleSheet.p);
    final textScaler =
        widget.styleSheet.textScaler ?? MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    return DefaultTextStyle.merge(
      style: widget.styleSheet.p,
      child: LayoutBuilder(
        builder: (markdownContext, constraints) {
          final maxWidth = constraints.maxWidth;
          final canReuseForWidth =
              !_needsRebuild &&
              _lastDefaultTextStyle == effectiveDefaultStyle &&
              _lastTextScaler == textScaler &&
              _lastLocale == locale &&
              _builtWithFiniteWidth == maxWidth.isFinite &&
              (_lastMaxWidth == maxWidth ||
                  !maxWidth.isFinite ||
                  (maxWidth >= _minValidRootMaxWidth &&
                      maxWidth <= _maxValidRootMaxWidth));
          if (!canReuseForWidth) {
            _needsRebuild = false;
            _lastMaxWidth = maxWidth;
            _lastDefaultTextStyle = effectiveDefaultStyle;
            _lastTextScaler = textScaler;
            _lastLocale = locale;
            _buildBlocks(
              markdownContext: markdownContext,
              maxWidth: maxWidth,
              defaultTextStyle: effectiveDefaultStyle,
              textScaler: textScaler,
              locale: locale,
            );
          } else {
            _lastMaxWidth = maxWidth;
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _children,
          );
        },
      ),
    );
  }
}

final class _DesktopMarkdownDelegate implements MarkdownBuilderDelegate {
  _DesktopMarkdownDelegate({
    required this.context,
    required this.onCreateLink,
    required this.onFormatText,
  });

  @override
  final BuildContext context;

  final GestureRecognizer Function(String text, String? href, String title)
  onCreateLink;

  final TextSpan Function(MarkdownStyleSheet styleSheet, String code)
  onFormatText;

  @override
  GestureRecognizer createLink(String text, String? href, String title) =>
      onCreateLink(text, href, title);

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) =>
      onFormatText(styleSheet, code);
}

final class _ActiveMarkdownLink {
  _ActiveMarkdownLink({
    required this.text,
    required this.href,
    required this.title,
  });

  final String text;
  final String? href;
  final String title;
  GestureRecognizer? recognizer;
}

final class _LinkScopePaddingBuilder extends MarkdownPaddingBuilder {
  _LinkScopePaddingBuilder({required this.activeLinks});

  final List<_ActiveMarkdownLink> activeLinks;

  static String? _extractLinkText(md.Node element) {
    if (element is md.Element && (element.children?.isNotEmpty ?? false)) {
      return element.children!
          .map(
            (child) =>
                child is md.Text ? child.text : _extractLinkText(child) ?? '',
          )
          .join();
    }
    if (element is md.Element && element.attributes.isNotEmpty) {
      return element.attributes['alt'];
    }
    return '';
  }

  @override
  void visitElementBefore(md.Element element) {
    final text = _extractLinkText(element);
    if (text == null) {
      return;
    }
    activeLinks.add(
      _ActiveMarkdownLink(
        text: text,
        href: element.attributes['href'],
        title: element.attributes['title'] ?? '',
      ),
    );
  }

  @override
  EdgeInsets getPadding() {
    if (activeLinks.isNotEmpty) {
      activeLinks.removeLast();
    }
    return EdgeInsets.zero;
  }
}

final class _PreScopeElementBuilder extends MarkdownElementBuilder {
  _PreScopeElementBuilder({
    required this.delegate,
    required this.onEnter,
    required this.onExit,
  });

  final MarkdownElementBuilder? delegate;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  @override
  bool isBlockElement() => delegate?.isBlockElement() ?? true;

  @override
  void visitElementBefore(md.Element element) {
    onEnter();
    delegate?.visitElementBefore(element);
  }

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) =>
      delegate?.visitText(text, preferredStyle);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    onExit();
    return delegate?.visitElementAfterWithContext(
      context,
      element,
      preferredStyle,
      parentStyle,
    );
  }
}

final class _DesktopInlineCodeBuilder extends MarkdownElementBuilder {
  _DesktopInlineCodeBuilder({
    required this.delegate,
    required this.isInsidePre,
    required this.hasPillSlot,
    required this.consumePillSlot,
    required this.availableWidth,
    required this.widthInset,
    required this.recordWidthThreshold,
    required this.defaultTextStyle,
    required this.textScaler,
    required this.locale,
    required this.currentLink,
    required this.obtainLinkRecognizer,
    required this.onTapLink,
    required this.fallbackStyle,
    required this.backgroundColor,
    required this.borderRadius,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.fontScale,
  });

  final MarkdownElementBuilder? delegate;
  final bool Function() isInsidePre;
  final bool Function() hasPillSlot;
  final VoidCallback consumePillSlot;
  final double Function() availableWidth;
  final double Function() widthInset;
  final void Function({required bool fits, required double thresholdRootWidth})
  recordWidthThreshold;
  final TextStyle Function() defaultTextStyle;
  final TextScaler Function() textScaler;
  final Locale? Function() locale;
  final _ActiveMarkdownLink? Function() currentLink;
  final GestureRecognizer Function(_ActiveMarkdownLink link)
  obtainLinkRecognizer;
  final MarkdownTapLinkCallback onTapLink;
  final TextStyle? fallbackStyle;
  final Color backgroundColor;
  final double borderRadius;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontScale;

  Widget _buildFlatSpanFallback({
    required String codeText,
    required TextStyle effectiveParent,
    required TextStyle? preferredStyle,
    required double baseFontSize,
    required _ActiveMarkdownLink? activeLink,
  }) {
    final recognizer = activeLink != null
        ? obtainLinkRecognizer(activeLink)
        : null;
    final parentHeight = effectiveParent.height;
    final fallbackSpanStyle = TextStyle(
      inherit: true,
      color: effectiveParent.color ?? preferredStyle?.color,
      backgroundColor: backgroundColor,
      fontFamily: preferredStyle?.fontFamily ?? 'monospace',
      fontFamilyFallback:
          preferredStyle?.fontFamilyFallback ??
          effectiveParent.fontFamilyFallback,
      fontSize: baseFontSize * fontScale,
      height: parentHeight != null && fontScale > 0
          ? parentHeight / fontScale
          : null,
      fontWeight: effectiveParent.fontWeight,
      fontStyle: effectiveParent.fontStyle,
      letterSpacing: effectiveParent.letterSpacing,
      decoration: effectiveParent.decoration,
      decorationColor: effectiveParent.decorationColor,
      decorationStyle: effectiveParent.decorationStyle,
      decorationThickness: effectiveParent.decorationThickness,
      fontFeatures: effectiveParent.fontFeatures,
      textBaseline: TextBaseline.alphabetic,
    );
    return Text.rich(
      TextSpan(
        text: codeText,
        style: fallbackSpanStyle,
        recognizer: recognizer,
        mouseCursor: recognizer != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
      ),
    );
  }

  bool _fitsSingleLinePill({
    required String codeText,
    required TextStyle pillTextStyle,
    required double scaleBaseFontSize,
  }) {
    if (codeText.contains('\n')) {
      return false;
    }
    final containerWidth = availableWidth();
    if (!containerWidth.isFinite) {
      return true;
    }
    final scaler = textScaler();
    final scaleFactor = scaleBaseFontSize > 0
        ? scaler.scale(scaleBaseFontSize) / scaleBaseFontSize
        : 0.0;
    if (scaleFactor <= 0 || !scaleFactor.isFinite) {
      return false;
    }
    final maxInnerTextWidth =
        (containerWidth / scaleFactor) - horizontalPadding * 2;
    final painter =
        TextPainter(
          text: TextSpan(text: codeText, style: pillTextStyle),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          locale: locale(),
        )..layout(
          maxWidth: maxInnerTextWidth > 0 ? maxInnerTextWidth : double.infinity,
        );
    final fits =
        maxInnerTextWidth > 0 &&
        painter.computeLineMetrics().length <= 1 &&
        painter.width <= maxInnerTextWidth + 0.01;
    final intrinsicInnerWidth = math.max(
      painter.maxIntrinsicWidth,
      fits ? painter.width : 0.0,
    );
    painter.dispose();
    final thresholdRootWidth =
        widthInset() +
        (intrinsicInnerWidth + horizontalPadding * 2) * scaleFactor;
    recordWidthThreshold(fits: fits, thresholdRootWidth: thresholdRootWidth);
    return fits;
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (isInsidePre()) {
      return null;
    }
    final custom = delegate?.visitElementAfterWithContext(
      context,
      element,
      preferredStyle,
      parentStyle,
    );
    if (custom != null) {
      return custom;
    }

    final codeText = element.textContent;
    final defaultStyle = defaultTextStyle();
    final effectiveParent = defaultStyle
        .merge(fallbackStyle)
        .merge(parentStyle);
    final baseFontSize =
        effectiveParent.fontSize ??
        preferredStyle?.fontSize ??
        OfficialCodexTheme.chatFontSize;
    final activeLink = currentLink();

    if (!hasPillSlot()) {
      return _buildFlatSpanFallback(
        codeText: codeText,
        effectiveParent: effectiveParent,
        preferredStyle: preferredStyle,
        baseFontSize: baseFontSize,
        activeLink: activeLink,
      );
    }

    final pillTextStyle = TextStyle(
      inherit: false,
      color: effectiveParent.color ?? preferredStyle?.color,
      fontFamily: preferredStyle?.fontFamily ?? 'monospace',
      fontFamilyFallback:
          preferredStyle?.fontFamilyFallback ??
          effectiveParent.fontFamilyFallback,
      fontSize: baseFontSize * fontScale,
      fontWeight: effectiveParent.fontWeight,
      fontStyle: effectiveParent.fontStyle,
      letterSpacing: effectiveParent.letterSpacing,
      decoration: effectiveParent.decoration,
      decorationColor: effectiveParent.decorationColor,
      decorationStyle: effectiveParent.decorationStyle,
      decorationThickness: effectiveParent.decorationThickness,
      fontFeatures: effectiveParent.fontFeatures,
      textBaseline: TextBaseline.alphabetic,
    );

    if (!_fitsSingleLinePill(
      codeText: codeText,
      pillTextStyle: pillTextStyle,
      scaleBaseFontSize: defaultStyle.fontSize ?? kDefaultFontSize,
    )) {
      return _buildFlatSpanFallback(
        codeText: codeText,
        effectiveParent: effectiveParent,
        preferredStyle: preferredStyle,
        baseFontSize: baseFontSize,
        activeLink: activeLink,
      );
    }

    consumePillSlot();

    Widget pill = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Text(
          codeText,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          style: pillTextStyle,
        ),
      ),
    );

    if (activeLink != null) {
      pill = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              onTapLink(activeLink.text, activeLink.href, activeLink.title),
          child: pill,
        ),
      );
    }

    return Text.rich(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: pill,
      ),
    );
  }
}
