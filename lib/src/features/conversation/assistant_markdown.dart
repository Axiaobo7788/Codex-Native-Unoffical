import 'dart:async';

import 'package:flutter/material.dart';
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
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final theme = Theme.of(context);
    final palette = ThemeTokens.of(context);
    final bodyStyle = theme.textTheme.bodyMedium;
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
        fontSize: 13,
      ),
      h1: theme.textTheme.headlineSmall,
      h2: theme.textTheme.titleLarge,
      h3: theme.textTheme.titleMedium,
      h4: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      h5: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      h6: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      blockSpacing: ThemeTokens.space2,
      listIndent: ThemeTokens.space6,
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
      codeblockPadding: const EdgeInsets.all(ThemeTokens.space3),
      codeblockDecoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(ThemeTokens.radiusSmall),
      ),
    );

    return SelectionArea(
      child: MarkdownBody(
        key: const ValueKey('assistant-markdown'),
        data: source,
        selectable: false,
        extensionSet: _safeExtensions,
        styleSheet: styleSheet,
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
