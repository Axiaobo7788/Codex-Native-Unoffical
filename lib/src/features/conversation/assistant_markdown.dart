import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme_tokens.dart';

typedef ExternalLinkLauncher = Future<bool> Function(Uri uri);

class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({
    super.key,
    required this.data,
    required this.completed,
    ExternalLinkLauncher? externalLinkLauncher,
  }) : externalLinkLauncher = externalLinkLauncher ?? _launchExternal;

  static const maxSourceCharacters = 16 * 1024;
  static const _omittedPrefix =
      '[Earlier assistant text omitted from this view]\n\n';

  static final md.ExtensionSet _safeExtensions = md.ExtensionSet(
    const <md.BlockSyntax>[
      _LiteralHtmlBlockSyntax(),
      md.FencedCodeBlockSyntax(),
      md.TableSyntax(),
      md.UnorderedListWithCheckboxSyntax(),
      md.OrderedListWithCheckboxSyntax(),
    ],
    <md.InlineSyntax>[md.StrikethroughSyntax(), md.AutolinkExtensionSyntax()],
  );

  final String data;
  final bool completed;
  final ExternalLinkLauncher externalLinkLauncher;

  @override
  Widget build(BuildContext context) {
    final source = _boundedSource(data);
    if (!completed || data.length > maxSourceCharacters) {
      return SelectableText(
        source,
        key: ValueKey(
          completed ? 'assistant-bounded-text' : 'assistant-streaming-text',
        ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
      );
    }

    final theme = Theme.of(context);
    final palette = ThemeTokens.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.55);
    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      a: bodyStyle?.copyWith(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: theme.colorScheme.primary,
      ),
      p: bodyStyle,
      code: bodyStyle?.copyWith(
        color: palette.textPrimary,
        backgroundColor: palette.surfaceRaised,
        fontFamily: 'monospace',
        fontSize: 12.5,
      ),
      h1: theme.textTheme.titleLarge?.copyWith(height: 1.35),
      h2: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5, height: 1.35),
      h3: theme.textTheme.titleSmall?.copyWith(fontSize: 14, height: 1.35),
      h4: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      h5: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      h6: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      blockSpacing: 10,
      listIndent: 20,
      listBullet: bodyStyle?.copyWith(color: palette.textSecondary),
      tableBorder: TableBorder.all(color: palette.border),
      tableCellsPadding: const EdgeInsets.all(ThemeTokens.space2),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: ThemeTokens.space3,
        vertical: ThemeTokens.space2,
      ),
      blockquoteDecoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border(left: BorderSide(color: palette.borderStrong, width: 3)),
      ),
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: const BoxDecoration(),
    );

    return SelectionArea(
      child: MarkdownBody(
        key: const ValueKey('assistant-markdown'),
        data: source,
        selectable: false,
        extensionSet: _safeExtensions,
        styleSheet: styleSheet,
        builders: {'pre': _CodeBlockBuilder()},
        imageBuilder: (uri, title, alt) =>
            _blockedImage(context, uri, title, alt),
        onTapLink: (text, href, title) => unawaited(_openLink(context, href)),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String? href) async {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showMessage(context, 'Only http and https links can be opened.');
      return;
    }

    try {
      final opened = await externalLinkLauncher(uri);
      if (!opened && context.mounted) {
        _showMessage(context, 'The link could not be opened.');
      }
    } on Object {
      if (context.mounted) {
        _showMessage(context, 'The link could not be opened.');
      }
    }
  }

  static Future<bool> _launchExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  static Widget _blockedImage(
    BuildContext context,
    Uri uri,
    String? title,
    String? alt,
  ) {
    final label = _boundedLabel(alt?.trim());
    final palette = ThemeTokens.of(context);
    return Container(
      key: const ValueKey('blocked-markdown-image'),
      padding: const EdgeInsets.all(ThemeTokens.space2),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 16),
          const SizedBox(width: ThemeTokens.space2),
          Flexible(child: Text(label ?? 'Image not loaded')),
        ],
      ),
    );
  }

  static String _boundedSource(String value) {
    if (value.length <= maxSourceCharacters) {
      return value;
    }
    final retained = maxSourceCharacters - _omittedPrefix.length;
    return '$_omittedPrefix${value.substring(value.length - retained)}';
  }

  static String? _boundedLabel(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    const maxCharacters = 160;
    return value.length <= maxCharacters
        ? value
        : '${value.substring(0, maxCharacters)}…';
  }
}

class _LiteralHtmlBlockSyntax extends md.BlockSyntax {
  const _LiteralHtmlBlockSyntax();

  static const _delegate = md.HtmlBlockSyntax();

  @override
  RegExp get pattern => _delegate.pattern;

  @override
  bool canEndBlock(md.BlockParser parser) => _delegate.canEndBlock(parser);

  @override
  md.Node parse(md.BlockParser parser) {
    final literal = _delegate.parse(parser);
    return md.Element('p', [literal]);
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    var language = '';
    final children = element.children;
    if (children != null && children.isNotEmpty) {
      final first = children.first;
      if (first is md.Element && first.tag == 'code') {
        final rawClass = first.attributes['class'] ?? '';
        if (rawClass.startsWith('language-')) {
          language = rawClass.substring('language-'.length).trim();
        }
      }
    }
    var code = element.textContent;
    if (code.endsWith('\n')) {
      code = code.substring(0, code.length - 1);
    }
    return _FencedCodeBlockView(language: language, code: code);
  }
}

class _FencedCodeBlockView extends StatefulWidget {
  const _FencedCodeBlockView({required this.language, required this.code});

  final String language;
  final String code;

  @override
  State<_FencedCodeBlockView> createState() => _FencedCodeBlockViewState();
}

class _FencedCodeBlockViewState extends State<_FencedCodeBlockView> {
  var _copied = false;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final label = widget.language.isEmpty ? 'code' : widget.language;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: palette.sidebar.withValues(alpha: 0.7),
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Row(
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: palette.textSecondary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _copyCode,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 13,
                          color: _copied
                              ? palette.success
                              : palette.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copied' : 'Copy',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: _copied
                                    ? palette.success
                                    : palette.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.code,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.5,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
