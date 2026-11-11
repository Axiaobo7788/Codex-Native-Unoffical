import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../app/primitives/codex_button.dart';
import '../../app/theme/official_codex_theme.dart';
import '../../app/theme_tokens.dart';
import '../../domain/assistant_content_blocks.dart';
import 'desktop_markdown_body.dart';

typedef ExternalLinkLauncher = Future<bool> Function(Uri uri);

class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({
    super.key,
    required this.data,
    required this.completed,
    this.proseLineHeight,
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
  final double? proseLineHeight;
  final ExternalLinkLauncher externalLinkLauncher;

  @override
  Widget build(BuildContext context) {
    final source = _boundedSource(data);
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      height: proseLineHeight ?? 1.55,
    );
    if (!completed || data.length > maxSourceCharacters) {
      return SelectableText(
        source,
        key: ValueKey(
          completed ? 'assistant-bounded-text' : 'assistant-streaming-text',
        ),
        style: bodyStyle,
      );
    }

    final presentation = parseAssistantContentPresentation(source);
    final palette = ThemeTokens.of(context);
    final codexTheme = OfficialCodexTheme.of(context);
    final baseStyleSheet = MarkdownStyleSheet.fromTheme(theme);
    final fontSize = bodyStyle?.fontSize;
    final lineHeight = proseLineHeight;
    final isDesktop = lineHeight != null && fontSize != null;
    // Desktop lists inset their text by one line height plus 1.5 spaces,
    // where one Markdown space is one quarter of the body font size.
    final listIndent = !isDesktop
        ? 20.0
        : (MediaQuery.textScalerOf(context).scale(fontSize) *
                      (lineHeight + 1.5 / 4) -
                  (baseStyleSheet.listBulletPadding?.horizontal ?? 0))
              .clamp(0.0, double.infinity);
    TextStyle? desktopHeading(double sizeRatio, double lineBoxRatio) {
      if (!isDesktop) {
        return null;
      }
      return bodyStyle?.copyWith(
        fontSize: fontSize * sizeRatio,
        height: lineBoxRatio / sizeRatio,
        fontWeight: FontWeight.w600,
      );
    }

    final styleSheet = baseStyleSheet.copyWith(
      a: isDesktop
          ? bodyStyle?.copyWith(
              color: palette.textPrimary,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: palette.textMuted,
            )
          : bodyStyle?.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.primary,
            ),
      p: bodyStyle,
      code: bodyStyle?.copyWith(
        color: palette.textPrimary,
        backgroundColor: isDesktop ? null : palette.surfaceRaised,
        fontFamily: 'monospace',
        fontSize: isDesktop
            ? fontSize * OfficialCodexTheme.inlineCodeFontScale
            : 12.5,
      ),
      h1:
          desktopHeading(1.5, 2) ??
          theme.textTheme.titleLarge?.copyWith(height: 1.35),
      h2:
          desktopHeading(1.25, 1.75) ??
          theme.textTheme.titleMedium?.copyWith(fontSize: 15.5, height: 1.35),
      h3:
          desktopHeading(1.125, 1.75) ??
          theme.textTheme.titleSmall?.copyWith(fontSize: 14, height: 1.35),
      h4:
          desktopHeading(1, 1.5) ??
          bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      h5: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      h6: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      blockSpacing: 10,
      listIndent: listIndent,
      listBullet: bodyStyle?.copyWith(
        color: isDesktop ? palette.textPrimary : palette.textSecondary,
        fontWeight: isDesktop ? FontWeight.w600 : null,
      ),
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

    Widget buildMarkdown(String markdownData) => SelectionArea(
      child: isDesktop
          ? DesktopMarkdownBody(
              key: const ValueKey('assistant-markdown'),
              data: markdownData,
              styleSheet: styleSheet,
              bodyEm: MediaQuery.textScalerOf(context).scale(fontSize),
              borderMedium: palette.borderStrong,
              borderLight: codexTheme.hairlineBorder,
              inlineCodeBackground: codexTheme.inlineCodeBackground,
              inlineCodeRadius: OfficialCodexTheme.inlineCodeRadius,
              inlineCodeHorizontalPadding:
                  OfficialCodexTheme.inlineCodeHorizontalPadding,
              inlineCodeVerticalPadding:
                  OfficialCodexTheme.inlineCodeVerticalPadding,
              inlineCodeFontScale: OfficialCodexTheme.inlineCodeFontScale,
              maxInlineCodePills: OfficialCodexTheme.maxInlineCodePills,
              extensionSet: _safeExtensions,
              builders: {
                'pre': _CodeBlockBuilder(desktop: true, bodyFontSize: fontSize),
              },
              imageBuilder: (uri, title, alt) =>
                  _blockedImage(context, uri, title, alt),
              onTapLink: (text, href, title) =>
                  unawaited(_openLink(context, href)),
            )
          : MarkdownBody(
              key: const ValueKey('assistant-markdown'),
              data: markdownData,
              selectable: false,
              extensionSet: _safeExtensions,
              styleSheet: styleSheet,
              builders: {
                'pre': _CodeBlockBuilder(
                  desktop: false,
                  bodyFontSize: fontSize,
                ),
              },
              imageBuilder: (uri, title, alt) =>
                  _blockedImage(context, uri, title, alt),
              onTapLink: (text, href, title) =>
                  unawaited(_openLink(context, href)),
            ),
    );

    if (!presentation.hasStructuredBlocks) {
      return buildMarkdown(source);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (presentation.proseMarkdown.isNotEmpty)
          buildMarkdown(presentation.proseMarkdown),
        for (var i = 0; i < presentation.artifacts.length; i++) ...[
          if (presentation.proseMarkdown.isNotEmpty || i > 0)
            const SizedBox(height: ThemeTokens.space2),
          _AssistantArtifactCard(index: i, block: presentation.artifacts[i]),
        ],
        if (presentation.citations.isNotEmpty) ...[
          const SizedBox(height: ThemeTokens.space2),
          Wrap(
            key: const ValueKey('assistant-citations'),
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final citation in presentation.citations)
                _AssistantCitationChip(
                  citation: citation,
                  onTapUrl: citation.url == null
                      ? null
                      : () => unawaited(_openLink(context, citation.url)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _openLink(BuildContext context, String? href) =>
      _openExternalLink(context, href, externalLinkLauncher);

  static Future<void> _openExternalLink(
    BuildContext context,
    String? href,
    ExternalLinkLauncher launcher,
  ) async {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showMessage(context, 'Only http and https links can be opened.');
      return;
    }

    try {
      final opened = await launcher(uri);
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

/// Renders official Desktop reasoning Markdown (`225284.ak` +
/// `0b2d31a9d760.css` `.content-oxuumP`):
/// - `14px` `.text-size-chat` (`OfficialCodexTheme.activityChatFontSize`) and
///   `1.5` line height (`OfficialCodexTheme.activityChatLineHeight`) across
///   paragraphs, lists, tables, and `h1`–`h6` headings (`[&_*]:text-size-chat`).
/// - `60%` outer ink (`activitySummaryText`) on streaming/bounded fallback
///   text and `50%` nested ink (`activityReasoningNestedText`,
///   `[&_*]:text-text/50`) on rendered Markdown elements.
/// - Preserves `ADR-058`: `!completed` streaming `SelectableText` bypass,
///   `16 KiB` source cap, `128`-pill `WidgetSpan` cap, safe `http`/`https`
///   external link opening, and `0` remote image fetches.
class ReasoningMarkdown extends StatelessWidget {
  const ReasoningMarkdown({
    super.key,
    required this.data,
    required this.completed,
    ExternalLinkLauncher? externalLinkLauncher,
  }) : externalLinkLauncher =
           externalLinkLauncher ?? AssistantMarkdown._launchExternal;

  static const maxSourceCharacters = AssistantMarkdown.maxSourceCharacters;
  static const _omittedPrefix =
      '[Earlier reasoning text omitted from this view]\n\n';

  final String data;
  final bool completed;
  final ExternalLinkLauncher externalLinkLauncher;

  @override
  Widget build(BuildContext context) {
    final source = _boundedSource(data);
    final theme = Theme.of(context);
    final palette = ThemeTokens.of(context);
    final codexTheme = OfficialCodexTheme.of(context);
    const fontSize = OfficialCodexTheme.activityChatFontSize;
    const lineHeight = OfficialCodexTheme.activityChatLineHeight;
    final streamingStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: codexTheme.activitySummaryText,
    );
    if (!completed || data.length > maxSourceCharacters) {
      return SelectableText(
        source,
        key: ValueKey(
          completed ? 'reasoning-bounded-text' : 'reasoning-streaming-text',
        ),
        style: streamingStyle,
      );
    }

    final nestedColor = codexTheme.activityReasoningNestedText;
    final bodyStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontSize: fontSize,
          height: lineHeight,
          color: nestedColor,
        ) ??
        TextStyle(fontSize: fontSize, height: lineHeight, color: nestedColor);
    final headingStyle = bodyStyle.copyWith(fontWeight: FontWeight.w600);
    final baseStyleSheet = MarkdownStyleSheet.fromTheme(theme);
    final styleSheet = baseStyleSheet.copyWith(
      a: bodyStyle.copyWith(
        color: nestedColor,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: palette.textMuted,
      ),
      p: bodyStyle,
      strong: bodyStyle.copyWith(fontWeight: FontWeight.bold),
      em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
      del: bodyStyle.copyWith(decoration: TextDecoration.lineThrough),
      code: bodyStyle.copyWith(
        color: nestedColor,
        backgroundColor: null,
        fontFamily: 'monospace',
        fontSize: fontSize * OfficialCodexTheme.inlineCodeFontScale,
      ),
      h1: headingStyle,
      h2: headingStyle,
      h3: headingStyle,
      h4: headingStyle,
      h5: headingStyle,
      h6: headingStyle,
      blockSpacing: OfficialCodexTheme.reasoningParagraphGap,
      listBullet: bodyStyle,
      blockquote: bodyStyle,
      tableHead: headingStyle,
      tableBody: bodyStyle,
      tableBorder: TableBorder.all(color: palette.border),
      tableCellsPadding: const EdgeInsets.all(ThemeTokens.space2),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: ThemeTokens.space3,
        vertical: ThemeTokens.space1,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.borderStrong, width: 3)),
      ),
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: const BoxDecoration(),
    );

    return SelectionArea(
      child: DesktopMarkdownBody(
        key: const ValueKey('reasoning-markdown'),
        data: source,
        variant: DesktopMarkdownVariant.reasoning,
        styleSheet: styleSheet,
        bodyEm: MediaQuery.textScalerOf(context).scale(fontSize),
        borderMedium: palette.borderStrong,
        borderLight: codexTheme.hairlineBorder,
        inlineCodeBackground: codexTheme.inlineCodeBackground,
        inlineCodeRadius: OfficialCodexTheme.inlineCodeRadius,
        inlineCodeHorizontalPadding:
            OfficialCodexTheme.inlineCodeHorizontalPadding,
        inlineCodeVerticalPadding: OfficialCodexTheme.inlineCodeVerticalPadding,
        inlineCodeFontScale: OfficialCodexTheme.inlineCodeFontScale,
        maxInlineCodePills: OfficialCodexTheme.maxInlineCodePills,
        extensionSet: AssistantMarkdown._safeExtensions,
        builders: {
          'pre': _CodeBlockBuilder(desktop: true, bodyFontSize: fontSize),
        },
        imageBuilder: (uri, title, alt) =>
            AssistantMarkdown._blockedImage(context, uri, title, alt),
        onTapLink: (text, href, title) => unawaited(
          AssistantMarkdown._openExternalLink(
            context,
            href,
            externalLinkLauncher,
          ),
        ),
      ),
    );
  }

  /// Formats live streaming reasoning duration per official `100921.F9dY.C`
  /// (`underOneSecond: "null"`, `trimZeroUnits: false`) used by `225284.ak`
  /// `reasoningItem.thoughtWithElapsed` (`"Thought for {elapsed}"`).
  static String? formatElapsed(Duration elapsed) {
    final totalSeconds = math.max(0, elapsed.inMilliseconds) ~/ 1000;
    if (totalSeconds < 1) {
      return null;
    }
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds ~/ 3600) % 24;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (days > 0 || hours > 0) {
      final parts = <String>[
        if (days > 0) '${days}d',
        '${hours}h',
        '${minutes}m',
        '${seconds}s',
      ];
      return parts.join(' ');
    }
    return '${minutes}m ${seconds}s';
  }

  static String _boundedSource(String value) {
    if (value.length <= maxSourceCharacters) {
      return value;
    }
    final retained = maxSourceCharacters - _omittedPrefix.length;
    return '$_omittedPrefix${value.substring(value.length - retained)}';
  }
}

/// Optional clock override for deterministic widget testing of live reasoning
/// elapsed duration (`225284.ak` `R` -> `"Thought for {elapsed}"`).
class ReasoningClockScope extends InheritedWidget {
  const ReasoningClockScope({
    super.key,
    required this.now,
    required super.child,
  });

  final DateTime Function() now;

  static DateTime Function() nowOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ReasoningClockScope>()?.now ??
      DateTime.now;

  @override
  bool updateShouldNotify(covariant ReasoningClockScope oldWidget) =>
      now != oldWidget.now;
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
    if (literal is md.Text) {
      final normalized = literal.text
          .replaceFirst(RegExp(r'^\n+'), '')
          .replaceFirst(RegExp(r'\n+$'), '');
      return md.Element('p', [md.Text(normalized)]);
    }
    return md.Element('p', [literal]);
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder({required this.desktop, required this.bodyFontSize});

  final bool desktop;
  final double? bodyFontSize;

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
    return _FencedCodeBlockView(
      language: language,
      code: code,
      desktop: desktop,
      bodyFontSize: bodyFontSize,
    );
  }
}

class _FencedCodeBlockView extends StatefulWidget {
  const _FencedCodeBlockView({
    required this.language,
    required this.code,
    required this.desktop,
    this.bodyFontSize,
  });

  final String language;
  final String code;
  final bool desktop;
  final double? bodyFontSize;

  @override
  State<_FencedCodeBlockView> createState() => _FencedCodeBlockViewState();
}

class _FencedCodeBlockViewState extends State<_FencedCodeBlockView> {
  static const _desktopLanguageLabels = <String, String>{
    'bash': 'Bash',
    'c': 'C',
    'c++': 'C++',
    'cpp': 'C++',
    'cs': 'C#',
    'csharp': 'C#',
    'css': 'CSS',
    'dart': 'Dart',
    'diff': 'Diff',
    'dockerfile': 'Dockerfile',
    'go': 'Go',
    'golang': 'Go',
    'graphql': 'GraphQL',
    'html': 'HTML',
    'java': 'Java',
    'javascript': 'JavaScript',
    'js': 'JavaScript',
    'json': 'JSON',
    'jsx': 'JSX',
    'kotlin': 'Kotlin',
    'kt': 'Kotlin',
    'md': 'Markdown',
    'markdown': 'Markdown',
    'objc': 'Objective-C',
    'php': 'PHP',
    'plaintext': 'Plain text',
    'powershell': 'PowerShell',
    'py': 'Python',
    'python': 'Python',
    'rb': 'Ruby',
    'rs': 'Rust',
    'ruby': 'Ruby',
    'rust': 'Rust',
    'scss': 'SCSS',
    'sh': 'Shell',
    'shell': 'Shell',
    'sql': 'SQL',
    'swift': 'Swift',
    'text': 'Plain text',
    'toml': 'TOML',
    'ts': 'TypeScript',
    'tsx': 'TSX',
    'txt': 'Plain text',
    'typescript': 'TypeScript',
    'xml': 'XML',
    'yaml': 'YAML',
    'yml': 'YAML',
    'zsh': 'Zsh',
  };

  Timer? _copiedResetTimer;
  var _copied = false;
  var _copyHovered = false;

  static String _formatDesktopLanguage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'Code';
    }
    final normalized = trimmed.split(RegExp(r'\s+')).first.toLowerCase();
    return _desktopLanguageLabels[normalized] ?? trimmed;
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) {
      return;
    }
    _copiedResetTimer?.cancel();
    setState(() => _copied = true);
    _copiedResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _FencedCodeBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code ||
        oldWidget.language != widget.language) {
      _copiedResetTimer?.cancel();
      _copied = false;
    }
  }

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final codexTheme = OfficialCodexTheme.of(context);
    if (widget.desktop) {
      final label = _formatDesktopLanguage(widget.language);
      final codeSurface = codexTheme.isDark
          ? const Color(0xFF282828)
          : const Color(0xFFF2F3F3);
      final baseSize = widget.bodyFontSize ?? OfficialCodexTheme.chatFontSize;
      final codeFontSize =
          OfficialCodexTheme.chatCodeFontSize *
          (baseSize / OfficialCodexTheme.chatFontSize);
      final codeLineHeight =
          math.max(
            codeFontSize * 1.5,
            OfficialCodexTheme.chatCodeBlockMinLineHeight,
          ) /
          codeFontSize;
      return Container(
        key: const ValueKey('desktop-markdown-code-block'),
        width: double.infinity,
        decoration: BoxDecoration(
          color: codeSurface,
          border: Border.all(
            color: codexTheme.hairlineBorder,
            width: OfficialCodexTheme.codeBlockBorderWidth,
          ),
          borderRadius: BorderRadius.circular(
            OfficialCodexTheme.codeBlockRadius,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: OfficialCodexTheme.codeBlockHeaderHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 18 / 13,
                          fontWeight: FontWeight.w500,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    CodexIconButton(
                      key: const ValueKey('desktop-markdown-code-copy'),
                      size: 28,
                      iconSize: 16,
                      tooltip: _copied ? 'Copied' : 'Copy code',
                      onPressed: _copyCode,
                      icon: Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        color: _copied ? palette.success : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                widget.code,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: codeFontSize,
                  height: codeLineHeight,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final label = widget.language.isEmpty ? 'code' : widget.language;
    final codeSurface = codexTheme.isDark
        ? const Color(0xFF171817)
        : const Color(0xFFF4F4F4);
    final headerSurface = codexTheme.isDark
        ? const Color(0xFF1F201F)
        : const Color(0xFFEAEAEA);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: codeSurface,
        border: Border.all(
          color: codexTheme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
        borderRadius: BorderRadius.circular(
          OfficialCodexTheme.activityRowRadius,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: headerSurface,
              border: Border(
                bottom: BorderSide(
                  color: codexTheme.hairlineBorder,
                  width: OfficialCodexTheme.hairlineBorderWidth,
                ),
              ),
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _copyCode,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _copyHovered = true),
                    onExit: (_) => setState(() => _copyHovered = false),
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _copyHovered
                            ? codexTheme.hoverTint
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 13,
                            color: _copied
                                ? palette.success
                                : (_copyHovered
                                      ? palette.textPrimary
                                      : palette.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _copied ? 'Copied' : 'Copy',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: _copied
                                      ? palette.success
                                      : (_copyHovered
                                            ? palette.textPrimary
                                            : palette.textSecondary),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

class _AssistantArtifactCard extends StatefulWidget {
  const _AssistantArtifactCard({required this.index, required this.block});

  final int index;
  final AssistantArtifactBlock block;

  @override
  State<_AssistantArtifactCard> createState() => _AssistantArtifactCardState();
}

class _AssistantArtifactCardState extends State<_AssistantArtifactCard> {
  var _copied = false;
  var _expanded = true;

  Future<void> _copyContent() async {
    await Clipboard.setData(ClipboardData(text: widget.block.content));
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
    final isWriting = widget.block.kind == AssistantArtifactKind.writing;
    final kindLabel = widget.block.kind.badgeLabel;
    final langSuffix = widget.block.language == null
        ? ''
        : ' · ${widget.block.language}';
    return Container(
      key: ValueKey('assistant-artifact-${widget.index}'),
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
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: palette.sidebar.withValues(alpha: 0.7),
              border: _expanded
                  ? Border(bottom: BorderSide(color: palette.border))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isWriting ? Icons.article_outlined : Icons.widgets_outlined,
                  size: 15,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.block.title} ($kindLabel$langSuffix)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  key: ValueKey('assistant-artifact-copy-${widget.index}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _copyContent,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
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
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  key: ValueKey('assistant-artifact-toggle-${widget.index}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                widget.block.content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: isWriting ? null : 'monospace',
                  fontSize: isWriting
                      ? OfficialCodexTheme.chatFontSize
                      : OfficialCodexTheme.chatCodeFontSize,
                  height: 1.55,
                  color: palette.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantCitationChip extends StatelessWidget {
  const _AssistantCitationChip({required this.citation, this.onTapUrl});

  final AssistantCitation citation;
  final VoidCallback? onTapUrl;

  @override
  Widget build(BuildContext context) {
    final palette = ThemeTokens.of(context);
    final chip = Container(
      key: ValueKey('assistant-citation-${citation.index}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            citation.url == null
                ? Icons.bookmark_border_rounded
                : Icons.open_in_new_rounded,
            size: 12,
            color: palette.textSecondary,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '[${citation.index}] ${citation.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTapUrl == null) {
      return chip;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapUrl,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: chip),
    );
  }
}
