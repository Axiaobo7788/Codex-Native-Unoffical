import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Uses the existing Markdown parser and builder once, with screen-CSS spacing
/// between supported top-level blocks. Nested and unknown block layouts keep
/// the builder's existing spacing.
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
  });

  final String data;
  final MarkdownStyleSheet styleSheet;
  final md.ExtensionSet extensionSet;
  final Map<String, MarkdownElementBuilder> builders;
  final MarkdownImageBuilder imageBuilder;
  final MarkdownTapLinkCallback onTapLink;
  final double bodyEm;

  @override
  State<DesktopMarkdownBody> createState() => _DesktopMarkdownBodyState();
}

class _DesktopMarkdownBodyState extends State<DesktopMarkdownBody>
    implements MarkdownBuilderDelegate {
  final _recognizers = <TapGestureRecognizer>[];
  List<Widget> _children = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildBlocks();
  }

  @override
  void didUpdateWidget(covariant DesktopMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data ||
        widget.styleSheet != oldWidget.styleSheet ||
        widget.bodyEm != oldWidget.bodyEm) {
      _buildBlocks();
    }
  }

  void _buildBlocks() {
    _disposeRecognizers();
    final document = md.Document(
      extensionSet: widget.extensionSet,
      encodeHtml: false,
    );
    final nodes = document.parseLines(
      const LineSplitter().convert(widget.data),
    );
    final built = MarkdownBuilder(
      delegate: this,
      selectable: false,
      styleSheet: widget.styleSheet,
      imageDirectory: null,
      checkboxBuilder: null,
      bulletBuilder: null,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
      builders: widget.builders,
      paddingBuilders: const {},
      imageBuilder: widget.imageBuilder,
      fitContent: true,
    ).build(nodes);

    // The public builder places one spacer between top-level block widgets.
    // Keep its result intact if a future or unusual node has another shape.
    if (nodes.isEmpty || built.length != nodes.length * 2 - 1) {
      _children = built;
      return;
    }
    final tags = nodes
        .map((node) => node is md.Element ? node.tag : null)
        .toList();
    _children = [
      for (var index = 0; index < nodes.length; index++) ...[
        if (index > 0)
          SizedBox(
            key: ValueKey('desktop-markdown-gap-$index'),
            height: _adjacentGap(tags, index),
          ),
        built[index * 2],
      ],
    ];
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
        'h1' => (top: 4, bottom: 2),
        'h2' || 'h3' => (top: 4, bottom: 1),
        'h4' => (top: 4, bottom: 0),
        'h5' ||
        'h6' when previous == 'ul' || previous == 'ol' => (top: 4, bottom: 0),
        'h5' || 'h6' => (top: 0, bottom: 0),
        _ => null,
      };

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => widget.onTapLink(text, href, title);
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) => TextSpan(
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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: _children,
  );
}
