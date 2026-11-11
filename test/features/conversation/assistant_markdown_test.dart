import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/features/conversation/assistant_markdown.dart';
import 'package:codex_native_unofficial/src/features/conversation/desktop_markdown_body.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders bounded Markdown without loading assistant images', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AssistantMarkdown(
          data: '''
# Result

Use **bold**, `code`, and:

- one
- two

![remote diagram](https://example.com/private.png)

<script>alert("not executable")</script>

Raw <em>inline</em> HTML.
''',
          completed: true,
          externalLinkLauncher: (_) async => true,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('assistant-markdown')), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
    expect(find.textContaining('bold', findRichText: true), findsOneWidget);
    expect(
      find.byKey(const ValueKey('blocked-markdown-image')),
      findsOneWidget,
    );
    expect(find.text('remote diagram'), findsOneWidget);
    expect(find.textContaining('<script>', findRichText: true), findsOneWidget);
    expect(find.textContaining('<em>', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens only absolute http and https links', (tester) async {
    final launched = <Uri>[];
    Future<bool> launch(Uri uri) async {
      launched.add(uri);
      return true;
    }

    await tester.pumpWidget(
      _app(
        AssistantMarkdown(
          data: '''
[Web](https://example.com/path)

[Local](file:///tmp/secret)
''',
          completed: true,
          externalLinkLauncher: launch,
        ),
      ),
    );

    await tester.tap(find.text('Web', findRichText: true));
    await tester.pump();
    expect(launched, [Uri.parse('https://example.com/path')]);

    await tester.tap(find.text('Local', findRichText: true));
    await tester.pump();
    expect(launched, hasLength(1));
    expect(
      find.text('Only http and https links can be opened.'),
      findsOneWidget,
    );
  });

  testWidgets('keeps incomplete streaming Markdown as selectable source', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AssistantMarkdown(
          data: '**partial response',
          completed: false,
          proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
        ),
      ),
    );

    final streaming = find.byKey(const ValueKey('assistant-streaming-text'));
    expect(
      tester.widget<SelectableText>(streaming).style?.height,
      OfficialCodexTheme.assistantProseLineHeight,
    );
    expect(find.text('**partial response'), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-markdown')), findsNothing);
  });

  testWidgets('aligns desktop list text with its measured prose inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AssistantMarkdown(
          data: 'Introductory paragraph.\n\n- First list item',
          completed: true,
          proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
        ),
      ),
    );
    final paragraph = find.text('Introductory paragraph.', findRichText: true);
    final item = find.text('First list item', findRichText: true);
    final bodySize = Theme.of(tester.element(paragraph))
        .textTheme
        .bodyMedium!
        .fontSize!;
    expect(
      tester.getTopLeft(item).dx - tester.getTopLeft(paragraph).dx,
      closeTo(bodySize * 2, 0.01),
    );
  });

  testWidgets('renders desktop Markdown heading sizes relative to body text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AssistantMarkdown(
          data: '''
# Heading one
## Heading two
### Heading three
#### Heading four
##### Heading five
###### Heading six
''',
          completed: true,
          proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
        ),
      ),
    );
    const measurements = <(String, double, double)>[
      ('Heading one', 1.5, 2),
      ('Heading two', 1.25, 1.75),
      ('Heading three', 1.125, 1.75),
      ('Heading four', 1, 1.5),
      ('Heading five', 1, 1.625),
      ('Heading six', 1, 1.625),
    ];
    for (final (heading, sizeRatio, lineBoxRatio) in measurements) {
      final text = find.text(heading);
      final style = tester.widget<Text>(text).textSpan!.style!;
      final bodySize = Theme.of(tester.element(text))
          .textTheme
          .bodyMedium!
          .fontSize!;
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontSize, closeTo(bodySize * sizeRatio, 0.01));
      expect(
        style.fontSize! * style.height!,
        closeTo(bodySize * lineBoxRatio, 0.01),
      );
    }
  });

  testWidgets(
    'desktop root block gaps follow screen CSS and retain Markdown interactions',
    (tester) async {
      const pairs = <(String, double)>[
        ('First paragraph.\n\nSecond paragraph.', 1),
        ('Paragraph.\n\n- List item', 0.25),
        ('- List item\n\nParagraph.', 0.5),
        ('# Heading\n\nParagraph.', 0.5),
        ('## Heading\n\nParagraph.', 0.25),
        ('### Heading\n\nParagraph.', 0.25),
        ('#### Heading\n\nParagraph.', 0.5),
        ('##### Heading\n\nParagraph.', 0.5),
        ('Paragraph.\n\n# Heading', 1),
        ('- List item\n\n##### Heading', 1),
        ('1. List item\n\n###### Heading', 1),
      ];
      for (final (source, ratio) in pairs) {
        await tester.pumpWidget(
          _app(
            AssistantMarkdown(
              data: source,
              completed: true,
              proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
            ),
          ),
        );
        final gap = find.byKey(const ValueKey('desktop-markdown-gap-1'));
        expect(gap, findsOneWidget);
        final fontSize = Theme.of(tester.element(gap))
            .textTheme
            .bodyMedium!
            .fontSize!;
        expect(tester.getSize(gap).height, closeTo(fontSize * ratio, 0.01));
        expect(tester.takeException(), isNull);
      }

      final launched = <Uri>[];
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: AssistantMarkdown(
              data: '''[link](https://example.com/)

Second paragraph.

- Item
  - Nested item

```dart
print('bounded');
```

| Name | Value |
| --- | --- |
| Sample | One |
''',
              completed: true,
              proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
              externalLinkLauncher: (uri) async {
                launched.add(uri);
                return true;
              },
            ),
          ),
        ),
      );
      final expandedParagraphGap = find.byKey(
        const ValueKey('desktop-markdown-gap-2'),
      );
      final fontSize = Theme.of(tester.element(expandedParagraphGap))
          .textTheme
          .bodyMedium!
          .fontSize!;
      expect(tester.getSize(expandedParagraphGap).height, fontSize);
      expect(find.text('Nested item', findRichText: true), findsOneWidget);
      expect(
        find.textContaining("print('bounded');", findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Sample', findRichText: true), findsOneWidget);
      await tester.tap(find.text('link', findRichText: true));
      await tester.pump();
      expect(launched, [Uri.parse('https://example.com/')]);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _app(
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AssistantMarkdown(
              data: 'First paragraph.\n\nSecond paragraph.',
              completed: true,
              proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
            ),
          ),
        ),
      );
      final scaledGap = find.byKey(const ValueKey('desktop-markdown-gap-1'));
      expect(tester.getSize(scaledGap).height, fontSize * 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop tight list rows use the measured zero-margin flow', (
    tester,
  ) async {
    for (final nested in [false, true]) {
      final source = nested
          ? '- First item\n- Second item\n  - Nested item\n- Last item'
          : '- First item\n- Second item\n- Last item';
      await tester.pumpWidget(
        _app(
          AssistantMarkdown(
            data: source,
            completed: true,
            proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
          ),
        ),
      );
      final labels = [
        'First item',
        'Second item',
        if (nested) 'Nested item',
        'Last item',
      ];
      for (var index = 1; index < labels.length; index++) {
        final first = find.text(labels[index - 1], findRichText: true);
        final second = find.text(labels[index], findRichText: true);
        expect(
          tester.getTopLeft(second).dy - tester.getTopLeft(first).dy,
          closeTo(tester.getSize(first).height, 0.01),
        );
      }
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(
      _app(
        const AssistantMarkdown(
          data:
              '- First loose paragraph\n\n'
              '  Continuation paragraph\n\n'
              '- Second loose item',
          completed: true,
          proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
        ),
      ),
    );
    final first = find.text('First loose paragraph', findRichText: true);
    final continuation = find.text(
      'Continuation paragraph',
      findRichText: true,
    );
    final second = find.text('Second loose item', findRichText: true);
    final bodySize = Theme.of(tester.element(first))
        .textTheme
        .bodyMedium!
        .fontSize!;
    // Inside a loose list item, `li > p + p` uses `4 * S` (`1.0em`), while
    // `li + li` keeps zero inter-item margin.
    expect(
      tester.getTopLeft(continuation).dy - tester.getBottomLeft(first).dy,
      closeTo(bodySize, 0.01),
    );
    expect(
      tester.getTopLeft(second).dy - tester.getBottomLeft(continuation).dy,
      closeTo(0, 0.01),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      _app(
        const AssistantMarkdown(
          data: '3. Third item\n4. Fourth item',
          completed: true,
          proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
        ),
      ),
    );
    expect(find.text('3.', findRichText: true), findsOneWidget);
    expect(find.text('4.', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caps the source passed to the Markdown parser', (tester) async {
    final oversized =
        'prefix-${List.filled(AssistantMarkdown.maxSourceCharacters + 32, 'x').join()}';
    await tester.pumpWidget(
      _app(
        AssistantMarkdown(
          data: oversized,
          completed: true,
          externalLinkLauncher: (_) async => true,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('assistant-bounded-text')),
      findsOneWidget,
    );
    expect(
      find.textContaining('[Earlier assistant text omitted from this view]'),
      findsOneWidget,
    );
    expect(find.textContaining('prefix-'), findsNothing);
    expect(find.byKey(const ValueKey('assistant-markdown')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders structured writing/artifact cards and citation chips with collapse and link actions',
    (tester) async {
      final launched = <Uri>[];
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: AssistantMarkdown(
              data: '''
Here is the summary 【1†Protocol Spec】 and [cite: Guide](https://example.com/guide).

:::writing{title="Release Notes"}
# v1.2 Release
All checks green.
:::

<artifact title="config.json" language="json">
{"port": 8765}
</artifact>

[^2]: https://example.com/ footnote "Footnote Source"
''',
              completed: true,
              externalLinkLauncher: (uri) async {
                launched.add(uri);
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('assistant-markdown')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('assistant-artifact-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('assistant-artifact-1')),
        findsOneWidget,
      );
      expect(find.textContaining('Release Notes (Writing)'), findsOneWidget);
      expect(
        find.textContaining('config.json (Artifact · json)'),
        findsOneWidget,
      );
      expect(find.textContaining('{"port": 8765}'), findsOneWidget);

      // Collapse first artifact card
      await tester.tap(
        find.byKey(const ValueKey('assistant-artifact-toggle-0')),
      );
      await tester.pump();
      expect(find.textContaining('All checks green.'), findsNothing);

      // Citations rendered and clickable when URL is present
      expect(find.byKey(const ValueKey('assistant-citations')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('assistant-citation-1')),
        findsOneWidget,
      );
      final guideCitation = find.textContaining('Guide');
      expect(guideCitation, findsOneWidget);
      await tester.tap(guideCitation);
      await tester.pump();
      expect(launched, [Uri.parse('https://example.com/guide')]);
    },
  );

  testWidgets(
    'preserves artifact/citation syntax inside normal fenced code blocks and renders Code badgeLabel',
    (tester) async {
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: AssistantMarkdown(
              data: '''
Example syntax in a standard code fence:

```html
<artifact title="ShouldStayInCodeFence">
  <div>Literal code example 【1†NotACitation】</div>
</artifact>
```

Actual code artifact outside fence:

<artifact type="code" title="lib.rs" language="rust">
pub fn add(a: i32, b: i32) -> i32 { a + b }
</artifact>

Invalid scheme citation [cite: Unsafe](javascript:void).
''',
              completed: true,
              externalLinkLauncher: (_) async => true,
            ),
          ),
        ),
      );

      // Only 1 artifact card should be extracted (the one outside the ```html fence)
      expect(
        find.byKey(const ValueKey('assistant-artifact-0')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('assistant-artifact-1')), findsNothing);
      expect(find.textContaining('lib.rs (Code · rust)'), findsOneWidget);
      // Literal <artifact> inside ```html fence remains in the code block
      expect(
        find.textContaining('ShouldStayInCodeFence', findRichText: true),
        findsOneWidget,
      );
      // Only 1 citation extracted (Unsafe, with null url), not 【1†NotACitation】
      expect(
        find.byKey(const ValueKey('assistant-citation-1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('assistant-citation-2')), findsNothing);

      // Verify compact fenced code block geometry (8px radius, 0.5px hairline border, 32px header)
      final codeHeaderLabel = find.text('html');
      expect(codeHeaderLabel, findsOneWidget);
      final headerContainer = tester.widget<Container>(
        find
            .ancestor(of: codeHeaderLabel, matching: find.byType(Container))
            .first,
      );
      expect(headerContainer.constraints?.maxHeight, 32.0);
    },
  );

  testWidgets(
    'desktop rich prose translates loose lists, blockquote, fenced code, table, hr, and root edges',
    (tester) async {
      final launched = <Uri>[];
      const fixtureSource = '''# Bounded prose fixture

Opening paragraph with **strong text**, *emphasis* and `inline code`.

Second paragraph establishes consecutive paragraph spacing.

## Loose list

- First list paragraph.

  A second paragraph inside the same item.

- Second item with a [fixture link](https://example.invalid/native-prose).

1. First ordered item.

   Another paragraph within the ordered item.

2. Last ordered item.

### Quoted context

> First quoted paragraph.
>
> Second quoted paragraph with `quoted code`.
>
> - A nested quoted item.

Paragraph after the quote.

```dart
int add(int first, int second) {
  return first + second;
}
```

Paragraph after fenced code.

| Surface | State | Evidence |
| :--- | :---: | ---: |
| Paragraph | Complete | 1 |
| [Table link](https://example.invalid/table) | Complete | 2 |
| Quote and code | Complete | 3 |

Paragraph after the table.

---

Final paragraph. A remote image stays an explicit blocked preview.

![Fixture image](https://example.invalid/never-load-native-prose.png)

<div>Literal HTML remains text.</div>''';

      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: SizedBox(
              width: 624,
              child: AssistantMarkdown(
                data: fixtureSource,
                completed: true,
                proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
                externalLinkLauncher: (uri) async {
                  launched.add(uri);
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      final root = find.byKey(const ValueKey('assistant-markdown'));
      expect(root, findsOneWidget);
      final bodySize = Theme.of(tester.element(root))
          .textTheme
          .bodyMedium!
          .fontSize!;
      final space = bodySize / 4;

      // Root-edge: first child (`h1`) and last child (literal HTML paragraph)
      // carry zero outer top/bottom margin.
      final firstHeading = find.text('Bounded prose fixture');
      final lastLiteral = find.text(
        '<div>Literal HTML remains text.</div>',
        findRichText: true,
      );
      expect(
        tester.getTopLeft(firstHeading).dy,
        closeTo(tester.getTopLeft(root).dy, 0.01),
      );
      expect(
        tester.getBottomLeft(lastLiteral).dy,
        closeTo(tester.getBottomLeft(root).dy, 0.01),
      );

      // Loose ordered list: `li > p + p` = `4 * S` (`1.0em`), `li + li` = `0`.
      final orderedP1 = find.text('First ordered item.', findRichText: true);
      final orderedP2 = find.text(
        'Another paragraph within the ordered item.',
        findRichText: true,
      );
      final orderedItem2 = find.text('Last ordered item.', findRichText: true);
      expect(
        tester.getTopLeft(orderedP2).dy - tester.getBottomLeft(orderedP1).dy,
        closeTo(bodySize, 0.01),
      );
      expect(
        tester.getTopLeft(orderedItem2).dy - tester.getBottomLeft(orderedP2).dy,
        closeTo(0, 0.01),
      );

      // Blockquote: `2 * S` top/bottom padding, `6 * S` inline-start padding,
      // `1 * S` vertical bar, `0` internal paragraph/list gap, and `2 * S`
      // (`0.5em`) collapsed gap before the following paragraph.
      final blockquote = find.byKey(
        const ValueKey('desktop-markdown-blockquote-0'),
      );
      final quoteP1 = find.text('First quoted paragraph.', findRichText: true);
      final quoteP2 = find.textContaining(
        'Second quoted paragraph with',
        findRichText: true,
      );
      final quoteNested = find.text(
        'A nested quoted item.',
        findRichText: true,
      );
      final afterQuote = find.text(
        'Paragraph after the quote.',
        findRichText: true,
      );
      expect(
        tester.getTopLeft(quoteP1).dx - tester.getTopLeft(blockquote).dx,
        closeTo(space * 6, 0.01),
      );
      expect(
        tester.getTopLeft(quoteP1).dy - tester.getTopLeft(blockquote).dy,
        closeTo(space * 2, 0.01),
      );
      expect(
        tester.getBottomLeft(blockquote).dy -
            tester.getBottomLeft(quoteNested).dy,
        closeTo(space * 2, 0.01),
      );
      expect(
        tester.getTopLeft(quoteP2).dy - tester.getBottomLeft(quoteP1).dy,
        closeTo(0, 0.01),
      );
      expect(
        tester.getTopLeft(quoteNested).dy - tester.getBottomLeft(quoteP2).dy,
        closeTo(0, 0.01),
      );
      expect(
        tester.getTopLeft(afterQuote).dy - tester.getBottomLeft(blockquote).dy,
        closeTo(space * 2, 0.01),
      );

      // Desktop fenced code block: `20px` radius, `48px` header, `'Dart'` label,
      // and `5 * S` (`1.25em`) outer top/bottom margins.
      final codeBlock = find.byKey(
        const ValueKey('desktop-markdown-code-block'),
      );
      final codeContainer = tester.widget<Container>(codeBlock);
      final codeDecoration = codeContainer.decoration! as BoxDecoration;
      expect(
        codeDecoration.borderRadius,
        BorderRadius.circular(OfficialCodexTheme.codeBlockRadius),
      );
      expect(
        (codeDecoration.border! as Border).top.width,
        OfficialCodexTheme.codeBlockBorderWidth,
      );
      expect(find.text('Dart'), findsOneWidget);
      final codeCopyButton = find.byKey(
        const ValueKey('desktop-markdown-code-copy'),
      );
      expect(tester.getSize(codeCopyButton), const Size(28, 28));
      expect(
        tester.getSize(
          find.descendant(
            of: codeCopyButton,
            matching: find.byIcon(Icons.copy_rounded),
          ),
        ),
        const Size(16, 16),
      );
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final codeCopyTarget = find.descendant(
        of: codeCopyButton,
        matching: find.byType(GestureDetector),
      );
      final codeCopyFocusNode = Focus.of(tester.element(codeCopyTarget.first));
      codeCopyFocusNode.requestFocus();
      await tester.pump();
      expect(codeCopyFocusNode.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(
        copiedText,
        'int add(int first, int second) {\n  return first + second;\n}',
      );
      expect(
        find.descendant(
          of: codeCopyButton,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      final afterCode = find.text(
        'Paragraph after fenced code.',
        findRichText: true,
      );
      expect(
        tester.getTopLeft(codeBlock).dy - tester.getBottomLeft(afterQuote).dy,
        closeTo(space * 5, 0.01),
      );
      expect(
        tester.getTopLeft(afterCode).dy - tester.getBottomLeft(codeBlock).dy,
        closeTo(space * 5, 0.01),
      );

      // Table: `4 * S` (`1.0em`) top margin, `2 * S` (`0.5em`) gap before the
      // following paragraph, borderless outer/vertical grid, strong header
      // bottom border, light non-last body row borders, no last-row border,
      // column alignment (`left`, `center`, `right`), and working cell links.
      final tableFinder = find.byKey(
        const ValueKey('desktop-markdown-table-0'),
      );
      final tableWidget = tester.widget<Table>(tableFinder);
      expect(tableWidget.border, isNull);
      expect(tableWidget.children, hasLength(4));
      expect(
        (tableWidget.children[0].decoration as BoxDecoration?)?.border,
        isNotNull,
      );
      expect(
        (tableWidget.children[1].decoration as BoxDecoration?)?.border,
        isNotNull,
      );
      expect(
        (tableWidget.children[2].decoration as BoxDecoration?)?.border,
        isNotNull,
      );
      expect(tableWidget.children[3].decoration, isNull);

      final afterTable = find.text(
        'Paragraph after the table.',
        findRichText: true,
      );
      expect(
        tester.getTopLeft(tableFinder).dy - tester.getBottomLeft(afterCode).dy,
        closeTo(space * 4, 0.01),
      );
      expect(
        tester.getTopLeft(afterTable).dy - tester.getBottomLeft(tableFinder).dy,
        closeTo(space * 2, 0.01),
      );

      final cellLeft = find.text('Paragraph', findRichText: true);
      final cellCenter = find.text('Complete', findRichText: true).first;
      final cellRight = find.text('1', findRichText: true);
      expect(
        tester.getTopLeft(cellLeft).dx,
        closeTo(tester.getTopLeft(tableFinder).dx, 0.01),
      );
      expect(
        tester.getCenter(cellCenter).dx,
        greaterThan(tester.getTopRight(cellLeft).dx),
      );
      expect(
        tester.getTopRight(cellRight).dx,
        closeTo(tester.getTopRight(tableFinder).dx - space * 6, 0.5),
      );

      // Horizontal rule: `1px` rule with `7 * S` (`1.75em`) top/bottom margins.
      final hrFinder = find.byKey(const ValueKey('desktop-markdown-hr-0'));
      final finalParagraph = find.text(
        'Final paragraph. A remote image stays an explicit blocked preview.',
        findRichText: true,
      );
      expect(tester.getSize(hrFinder).height, 1.0);
      expect(
        tester.getTopLeft(hrFinder).dy - tester.getBottomLeft(afterTable).dy,
        closeTo(space * 7, 0.01),
      );
      expect(
        tester.getTopLeft(finalParagraph).dy -
            tester.getBottomLeft(hrFinder).dy,
        closeTo(space * 7, 0.01),
      );

      // Safe links (in loose list and table), blocked image, and rebuild/unmount
      // recognizer lifecycle stay intact.
      expect(
        find.byKey(const ValueKey('blocked-markdown-image')),
        findsOneWidget,
      );
      await tester.tapOnText(find.textRange.ofSubstring('fixture link'));
      await tester.pump();
      final tableLink = find.text('Table link', findRichText: true);
      await tester.ensureVisible(tableLink);
      await tester.pump();
      await tester.tap(tableLink);
      await tester.pump();
      expect(launched, [
        Uri.parse('https://example.invalid/native-prose'),
        Uri.parse('https://example.invalid/table'),
      ]);

      // Rebuild with updated Markdown while the 2-second copy timer is active,
      // then unmount to verify copied-state reset and recognizer/timer cleanup.
      await tester.pumpWidget(
        _app(
          AssistantMarkdown(
            data: '```rust\nfn main() {}\n```\n\n[Updated link](https://example.invalid/updated)',
            completed: true,
            proseLineHeight: OfficialCodexTheme.assistantProseLineHeight,
            externalLinkLauncher: (uri) async {
              launched.add(uri);
              return true;
            },
          ),
        ),
      );
      expect(find.text('Rust'), findsOneWidget);
      expect(
        find.descendant(
          of: codeCopyButton,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: codeCopyButton,
          matching: find.byIcon(Icons.copy_rounded),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Updated link', findRichText: true));
      await tester.pump();
      expect(launched.last, Uri.parse('https://example.invalid/updated'));

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop inline code pills translate geometry, container scaling, links, selection order, wrapping, and 2x scale',
    (tester) async {
      final launched = <Uri>[];
      const allContainersSource = '''# Heading `h1_code` pill

Paragraph with `body_code`, [`linked_code()`](https://example.invalid/code), [See `mixed_code` here](https://example.invalid/mixed), [](https://example.invalid/empty) `unlinked_code`, and [`unsafe_code`](javascript:void(0)).

## Subheading `h2_code`

- Tight item `list_code`

> Quoted `quote_code`

| Header `th_code` | Value |
| :--- | :--- |
| Row | `td_code` |

```dart
const fenced = 'not_inline_pill';
```''';

      Widget buildThemed({
        required Brightness brightness,
        required String data,
        double scale = 1.0,
        double width = 640,
      }) {
        final themeData = brightness == Brightness.dark
            ? OfficialCodexThemeData.dark
            : OfficialCodexThemeData.light;
        return MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: OfficialCodexThemeProvider(
            data: themeData,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: width,
                    child: AssistantMarkdown(
                      data: data,
                      completed: true,
                      proseLineHeight:
                          OfficialCodexTheme.assistantProseLineHeight,
                      externalLinkLauncher: (uri) async {
                        launched.add(uri);
                        return true;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      for (final (brightness, expectedFill) in [
        (Brightness.light, OfficialCodexTheme.lightInlineCodeBackground),
        (Brightness.dark, OfficialCodexTheme.darkInlineCodeBackground),
      ]) {
        await tester.pumpWidget(
          buildThemed(brightness: brightness, data: allContainersSource),
        );
        final root = find.byKey(const ValueKey('assistant-markdown'));
        final bodySize = Theme.of(tester.element(root))
            .textTheme
            .bodyMedium!
            .fontSize!;
        final tableSize = bodySize * 0.875 < 12.0 ? 12.0 : bodySize * 0.875;

        for (final (token, expectedBaseSize, expectedWeight) in [
          ('h1_code', bodySize * 1.5, FontWeight.w600),
          ('body_code', bodySize, FontWeight.w400),
          ('h2_code', bodySize * 1.25, FontWeight.w600),
          ('list_code', bodySize, FontWeight.w400),
          ('quote_code', bodySize, FontWeight.w400),
          ('th_code', tableSize, FontWeight.w600),
          ('td_code', tableSize, FontWeight.w400),
        ]) {
          final textFinder = find.text(token);
          expect(textFinder, findsOneWidget);
          final textWidget = tester.widget<Text>(textFinder);
          expect(textWidget.textDirection, TextDirection.ltr);
          expect(
            textWidget.style!.fontSize,
            closeTo(
              expectedBaseSize * OfficialCodexTheme.inlineCodeFontScale,
              0.01,
            ),
          );
          expect(textWidget.style!.fontWeight, expectedWeight);
          expect(textWidget.style!.backgroundColor, isNull);

          final paddingWidget = tester.widget<Padding>(
            find.ancestor(of: textFinder, matching: find.byType(Padding)).first,
          );
          expect(
            paddingWidget.padding,
            const EdgeInsets.symmetric(
              horizontal: OfficialCodexTheme.inlineCodeHorizontalPadding,
              vertical: OfficialCodexTheme.inlineCodeVerticalPadding,
            ),
          );

          final decoratedWidget = tester.widget<DecoratedBox>(
            find
                .ancestor(of: textFinder, matching: find.byType(DecoratedBox))
                .first,
          );
          final box = decoratedWidget.decoration as BoxDecoration;
          expect(box.color, expectedFill);
          expect(
            box.borderRadius,
            BorderRadius.circular(OfficialCodexTheme.inlineCodeRadius),
          );
        }

        // Multi-span H1 preserves full H1 line-box height (`2.0 * bodySize`).
        final h1RichText = find
            .ancestor(of: find.text('h1_code'), matching: find.byType(RichText))
            .last;
        expect(
          tester.getSize(h1RichText).height,
          greaterThanOrEqualTo(bodySize * 2 - 0.5),
        );

        // Fenced code content is not wrapped in an inline-code pill padding/box.
        expect(
          find.textContaining('not_inline_pill', findRichText: true),
          findsOneWidget,
        );
      }

      // Enclosing link styling + tap activation + empty-link isolation + scheme guard.
      final linkedText = tester.widget<Text>(find.text('linked_code()'));
      expect(linkedText.style!.decoration, TextDecoration.underline);
      expect(linkedText.style!.decorationStyle, TextDecorationStyle.dotted);

      launched.clear();
      await tester.tap(find.text('linked_code()'));
      await tester.pump();
      await tester.tap(find.text('mixed_code'));
      await tester.pump();
      await tester.tap(find.text('unlinked_code'));
      await tester.pump();
      expect(launched, [
        Uri.parse('https://example.invalid/code'),
        Uri.parse('https://example.invalid/mixed'),
      ]);

      await tester.tap(find.text('unsafe_code'));
      await tester.pump();
      expect(launched, hasLength(2));
      expect(
        find.text('Only http and https links can be opened.'),
        findsOneWidget,
      );

      // Updating only externalLinkLauncher keeps an equal MarkdownStyleSheet and
      // identical cached pill widget while dispatching through the latest callback.
      final beforeBody = tester.widget<DesktopMarkdownBody>(
        find.byType(DesktopMarkdownBody),
      );
      final beforeLinkedText = tester.widget<Text>(find.text('linked_code()'));
      final updatedLaunched = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: OfficialCodexThemeProvider(
            data: OfficialCodexThemeData.dark,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.0)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 640,
                    child: AssistantMarkdown(
                      data: allContainersSource,
                      completed: true,
                      proseLineHeight:
                          OfficialCodexTheme.assistantProseLineHeight,
                      externalLinkLauncher: (uri) async {
                        updatedLaunched.add(uri);
                        return true;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final afterBody = tester.widget<DesktopMarkdownBody>(
        find.byType(DesktopMarkdownBody),
      );
      final afterLinkedText = tester.widget<Text>(find.text('linked_code()'));
      expect(afterBody.styleSheet, equals(beforeBody.styleSheet));
      expect(identical(afterLinkedText, beforeLinkedText), isTrue);
      await tester.tap(find.text('linked_code()'));
      await tester.pump();
      expect(updatedLaunched, [Uri.parse('https://example.invalid/code')]);
      expect(launched, hasLength(2));

      // Built-in SelectionArea clipboard order (selectAll + mouse drag) across wrapped 640px prose.
      String? copiedSelection;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedSelection =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      const wrappedSelectionMarkdown =
          'First `alpha` with prose that wraps onto line two before `beta` and wraps again onto line three with `gamma` at the end.';
      const expectedPlain =
          'First alpha with prose that wraps onto line two before beta and wraps again onto line three with gamma at the end.';
      await tester.pumpWidget(
        buildThemed(
          brightness: Brightness.light,
          data: wrappedSelectionMarkdown,
        ),
      );
      final selectableState = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      final selectionActionContext = tester.element(find.text('alpha'));
      selectableState.selectAll(SelectionChangedCause.keyboard);
      await tester.pump();
      Actions.invoke(selectionActionContext, CopySelectionTextIntent.copy);
      await tester.pump();
      expect(copiedSelection, expectedPlain);

      copiedSelection = null;
      selectableState.clearSelection();
      await tester.pump();
      final markdownRect = tester.getRect(
        find.byKey(const ValueKey('assistant-markdown')),
      );
      final drag = await tester.startGesture(
        markdownRect.topLeft + const Offset(2, 6),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await drag.moveTo(markdownRect.bottomRight - const Offset(2, 6));
      await tester.pump();
      await drag.up();
      await tester.pump();
      Actions.invoke(selectionActionContext, CopySelectionTextIntent.copy);
      await tester.pump();
      expect(copiedSelection, expectedPlain);

      // Exact P1 repro: three short pills + a single >640px unbroken path must
      // fall back to a merged styled TextSpan for the internally-wrapping token
      // while keeping short WidgetSpan pills and exact clipboard document order.
      const longWrappingToken =
          'src/features/conversation/a_descriptive_configuration_filename_used_for_inline_wrapping_verification.dart';
      const fixtureParagraph =
          'Before `alpha` between [`linked.cfg`](https://example.invalid/native-inline-code) and `beta_gamma`, followed by enough ordinary prose to wrap the trailing fragment onto the next line in document order. Path `$longWrappingToken` ends here.';
      const expectedFixtureClipboard =
          'Before alpha between linked.cfg and beta_gamma, followed by enough ordinary prose to wrap the trailing fragment onto the next line in document order. Path $longWrappingToken ends here.';
      await tester.pumpWidget(
        buildThemed(brightness: Brightness.light, data: fixtureParagraph),
      );
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('linked.cfg'), findsOneWidget);
      expect(find.text('beta_gamma'), findsOneWidget);
      expect(find.text(longWrappingToken), findsNothing);
      expect(
        find.textContaining(longWrappingToken, findRichText: true),
        findsOneWidget,
      );

      final fixtureSelectable = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      final fixtureActionContext = tester.element(find.text('alpha'));
      copiedSelection = null;
      final fixtureRect = tester.getRect(
        find.byKey(const ValueKey('assistant-markdown')),
      );
      final fixtureDrag = await tester.startGesture(
        fixtureRect.topLeft + const Offset(2, 6),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      for (var step = 1; step <= 8; step++) {
        await fixtureDrag.moveTo(
          Offset(
            fixtureRect.left + 2 + (198 * step / 8),
            fixtureRect.top + 6 + ((fixtureRect.height + 18) * step / 8),
          ),
        );
        await tester.pump();
      }
      await fixtureDrag.up();
      await tester.pump();
      Actions.invoke(fixtureActionContext, CopySelectionTextIntent.copy);
      await tester.pump();
      expect(copiedSelection, expectedFixtureClipboard);

      copiedSelection = null;
      fixtureSelectable.clearSelection();
      await tester.pump();
      fixtureSelectable.selectAll(SelectionChangedCause.keyboard);
      await tester.pump();
      Actions.invoke(fixtureActionContext, CopySelectionTextIntent.copy);
      await tester.pump();
      expect(copiedSelection, expectedFixtureClipboard);

      // Enclosing link on an internally-wrapping inline-code token keeps dotted
      // underline, link tap dispatch, and exact copy order.
      launched.clear();
      await tester.pumpWidget(
        buildThemed(
          brightness: Brightness.light,
          data:
              'Open [`$longWrappingToken`](https://example.invalid/long-wrapped) next.',
        ),
      );
      TextSpan? wrappedLinkSpan;
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          if (span is TextSpan && span.text == longWrappingToken) {
            wrappedLinkSpan = span;
            return false;
          }
          return true;
        });
      }
      expect(wrappedLinkSpan, isNotNull);
      expect(
        wrappedLinkSpan!.style!.backgroundColor,
        OfficialCodexTheme.lightInlineCodeBackground,
      );
      expect(wrappedLinkSpan!.style!.decoration, TextDecoration.underline);
      expect(
        wrappedLinkSpan!.style!.decorationStyle,
        TextDecorationStyle.dotted,
      );
      (wrappedLinkSpan!.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(launched, [Uri.parse('https://example.invalid/long-wrapped')]);

      // Actual-width-aware + container-inset + 2x TextScaler adaptation:
      // a medium token fits as a pill at 640px (1x) and inside horizontally
      // scrollable table cells, but falls back to a flat TextSpan when narrowed,
      // scaled to 2x beyond container width, or inset inside blockquote/list.
      const mediumToken = 'medium_width_inline_code_token';
      await tester.pumpWidget(
        buildThemed(
          brightness: Brightness.light,
          data: 'Check `$mediumToken` end.',
          width: 640,
        ),
      );
      expect(find.text(mediumToken), findsOneWidget);

      await tester.pumpWidget(
        buildThemed(
          brightness: Brightness.light,
          data: 'Check `$mediumToken` end.',
          width: 300,
        ),
      );
      expect(find.text(mediumToken), findsNothing);
      expect(
        find.textContaining(mediumToken, findRichText: true),
        findsOneWidget,
      );

      await tester.pumpWidget(
        buildThemed(
          brightness: Brightness.light,
          data: 'Check `$mediumToken` end.',
          width: 640,
          scale: 2.0,
        ),
      );
      expect(find.text(mediumToken), findsNothing);

      await tester.pumpWidget(
        buildThemed(
          brightness: Brightness.light,
          data:
              '> See `$mediumToken`.\n\n| Col |\n| :--- |\n| See `$mediumToken`. |',
          width: 405,
        ),
      );
      // Blockquote subtracts `6 * space`, pushing `mediumToken` to flat TextSpan,
      // while the horizontally scrollable table cell keeps its single-line pill.
      expect(find.text(mediumToken), findsOneWidget);
      expect(
        find.ancestor(of: find.text(mediumToken), matching: find.byType(Table)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Painted global 2x TextScaler check (verifies exact 2x, not 1x frozen or 4x double-scaled).
      for (final sample in ['Text `scale_token` end.', '`scale_token`']) {
        await tester.pumpWidget(
          buildThemed(brightness: Brightness.light, data: sample, scale: 1.0),
        );
        final rect1x = tester.getRect(
          find
              .ancestor(
                of: find.text('scale_token'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        await tester.pumpWidget(
          buildThemed(brightness: Brightness.light, data: sample, scale: 2.0),
        );
        final rect2x = tester.getRect(
          find
              .ancestor(
                of: find.text('scale_token'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(rect2x.width, closeTo(rect1x.width * 2, 1.0));
        expect(rect2x.height, closeTo(rect1x.height * 2, 1.0));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'desktop inline code enforces shared 128-pill budget with styled linked TextSpan fallback',
    (tester) async {
      final launched = <Uri>[];
      String tok(int n) => 'tok_${n.toString().padLeft(3, '0')}';

      final bodyPills = [for (var i = 8; i <= 128; i++) '`${tok(i)}`']
          .join(' ');
      final overBudgetSource =
          '''# Heading `${tok(1)}`

| Header `${tok(2)}` | `${tok(3)}` |
| :--- | :--- |
| `${tok(4)}` | `${tok(5)}` |

- Bullet `${tok(6)}`

> Quote `${tok(7)}`

$bodyPills `${tok(129)}` [`${tok(130)}`](https://example.invalid/over) [See `${tok(131)}` here](https://example.invalid/mixed-over).

# Over heading `${tok(132)}`

| Over `${tok(133)}` | `${tok(134)}` |
| :--- | :--- |
| Row | `${tok(135)}` |''';

      Widget buildBudgetApp({
        required Brightness brightness,
        required String data,
        required ExternalLinkLauncher launcher,
      }) {
        final themeData = brightness == Brightness.dark
            ? OfficialCodexThemeData.dark
            : OfficialCodexThemeData.light;
        return MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: OfficialCodexThemeProvider(
            data: themeData,
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 640,
                  child: AssistantMarkdown(
                    data: data,
                    completed: true,
                    proseLineHeight:
                        OfficialCodexTheme.assistantProseLineHeight,
                    externalLinkLauncher: launcher,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      TextSpan? findSpanByText(InlineSpan rootSpan, String target) {
        TextSpan? found;
        rootSpan.visitChildren((span) {
          if (span is TextSpan && span.text == target) {
            found = span;
            return false;
          }
          return true;
        });
        if (found != null) {
          return found;
        }
        if (rootSpan is TextSpan && rootSpan.text == target) {
          return rootSpan;
        }
        return null;
      }

      TextSpan? findSpanInTree(String target) {
        for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
          final match = findSpanByText(rich.text, target);
          if (match != null) {
            return match;
          }
        }
        return null;
      }

      for (final (brightness, expectedFill) in [
        (Brightness.light, OfficialCodexTheme.lightInlineCodeBackground),
        (Brightness.dark, OfficialCodexTheme.darkInlineCodeBackground),
      ]) {
        await tester.pumpWidget(
          buildBudgetApp(
            brightness: brightness,
            data: overBudgetSource,
            launcher: (uri) async {
              launched.add(uri);
              return true;
            },
          ),
        );

        final root = find.byKey(const ValueKey('assistant-markdown'));
        final bodySize = Theme.of(tester.element(root))
            .textTheme
            .bodyMedium!
            .fontSize!;
        final tableSize = bodySize * 0.875 < 12.0 ? 12.0 : bodySize * 0.875;

        // Exactly 128 rich WidgetSpan pills are created across heading + table +
        // list + blockquote + paragraph.
        final pillRadius = BorderRadius.circular(
          OfficialCodexTheme.inlineCodeRadius,
        );
        final pillDecoratedCount = tester
            .widgetList<DecoratedBox>(
              find.descendant(of: root, matching: find.byType(DecoratedBox)),
            )
            .where((w) {
              final d = w.decoration;
              return d is BoxDecoration && d.borderRadius == pillRadius;
            })
            .length;
        expect(pillDecoratedCount, OfficialCodexTheme.maxInlineCodePills);
        expect(find.text(tok(1)), findsOneWidget);
        expect(find.text(tok(5)), findsOneWidget);
        expect(find.text(tok(128)), findsOneWidget);

        // Tokens 129..135 fall back to merged TextSpans (zero inline-code pill
        // DecoratedBox wrappers) while keeping parent-relative size/weight and fill.
        for (var i = 129; i <= 135; i++) {
          final match = find.textContaining(tok(i), findRichText: true);
          expect(match, findsOneWidget);
          final ancestorPills = tester
              .widgetList<DecoratedBox>(
                find.ancestor(of: match, matching: find.byType(DecoratedBox)),
              )
              .where((w) {
                final d = w.decoration;
                return d is BoxDecoration && d.borderRadius == pillRadius;
              });
          expect(ancestorPills, isEmpty);
        }

        for (final (token, expectedBaseSize, expectedWeight) in [
          (tok(129), bodySize, FontWeight.w400),
          (tok(130), bodySize, FontWeight.w400),
          (tok(131), bodySize, FontWeight.w400),
          (tok(132), bodySize * 1.5, FontWeight.w600),
          (tok(133), tableSize, FontWeight.w600),
          (tok(135), tableSize, FontWeight.w400),
        ]) {
          final span = findSpanInTree(token);
          expect(span, isNotNull, reason: 'Missing fallback TextSpan $token');
          expect(span!.style!.backgroundColor, expectedFill);
          expect(
            span.style!.fontSize,
            closeTo(
              expectedBaseSize * OfficialCodexTheme.inlineCodeFontScale,
              0.01,
            ),
          );
          expect(span.style!.fontWeight, expectedWeight);
        }

        final linkedSpan130 = findSpanInTree(tok(130))!;
        final linkedSpan131 = findSpanInTree(tok(131))!;
        expect(linkedSpan130.style!.decoration, TextDecoration.underline);
        expect(
          linkedSpan130.style!.decorationStyle,
          TextDecorationStyle.dotted,
        );
        expect(linkedSpan130.recognizer, isA<TapGestureRecognizer>());
        expect(linkedSpan131.recognizer, isA<TapGestureRecognizer>());
      }

      // Enclosing link activation + cached callback-only update on over-budget spans.
      launched.clear();
      (findSpanInTree(tok(130))!.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      (findSpanInTree(tok(131))!.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(launched, [
        Uri.parse('https://example.invalid/over'),
        Uri.parse('https://example.invalid/mixed-over'),
      ]);

      final beforeBody = tester.widget<DesktopMarkdownBody>(
        find.byType(DesktopMarkdownBody),
      );
      final beforeSpan130 = findSpanInTree(tok(130))!;
      final updatedLaunched = <Uri>[];
      await tester.pumpWidget(
        buildBudgetApp(
          brightness: Brightness.dark,
          data: overBudgetSource,
          launcher: (uri) async {
            updatedLaunched.add(uri);
            return true;
          },
        ),
      );
      final afterBody = tester.widget<DesktopMarkdownBody>(
        find.byType(DesktopMarkdownBody),
      );
      final afterSpan130 = findSpanInTree(tok(130))!;
      expect(afterBody.styleSheet, equals(beforeBody.styleSheet));
      expect(identical(afterSpan130, beforeSpan130), isTrue);
      (afterSpan130.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(updatedLaunched, [Uri.parse('https://example.invalid/over')]);

      // Clipboard copy preserves document order across pill 128 -> fallback 129..135.
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final selectableState = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      selectableState.selectAll(SelectionChangedCause.keyboard);
      await tester.pump();
      Actions.invoke(
        tester.element(find.text(tok(1))),
        CopySelectionTextIntent.copy,
      );
      await tester.pump();
      expect(copiedText, isNotNull);
      var prevIndex = -1;
      for (final marker in [
        tok(1),
        tok(5),
        tok(128),
        tok(129),
        tok(130),
        'See ${tok(131)} here',
        tok(132),
        tok(133),
        tok(134),
        tok(135),
      ]) {
        final idx = copiedText!.indexOf(marker);
        expect(idx, greaterThan(prevIndex), reason: 'Out-of-order $marker');
        prevIndex = idx;
      }

      // Rebuilding with an internally-wrapping flat TextSpan plus 128 short
      // tokens keeps all 128 short tokens as rich WidgetSpan pills before #129.
      final nonConsumingSource = [
        '`${'w' * 80}`',
        for (var i = 1; i <= 129; i++) '`s_$i`',
      ].join(' ');
      await tester.pumpWidget(
        buildBudgetApp(
          brightness: Brightness.light,
          data: nonConsumingSource,
          launcher: (_) async => true,
        ),
      );
      expect(find.text('w' * 80), findsNothing);
      expect(find.text('s_1'), findsOneWidget);
      expect(find.text('s_128'), findsOneWidget);
      expect(find.text('s_129'), findsNothing);
      expect(find.textContaining('s_129', findRichText: true), findsOneWidget);

      // Dense 16 KiB (4,096 inline-code tokens) stays strictly O(1) element-bounded
      // and returns to exact baseline element count on unmount.
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      final emptyShellElements = tester.allElements.length;

      final dense16KiB = List.filled(4096, '`a`').join(' ');
      expect(
        dense16KiB.length,
        lessThanOrEqualTo(AssistantMarkdown.maxSourceCharacters),
      );
      await tester.pumpWidget(
        buildBudgetApp(
          brightness: Brightness.light,
          data: dense16KiB,
          launcher: (_) async => true,
        ),
      );
      final denseElementCount = tester.allElements.length;
      expect(denseElementCount - emptyShellElements, lessThan(2000));

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await tester.pump();
      expect(tester.allElements.length, emptyShellElements);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));
