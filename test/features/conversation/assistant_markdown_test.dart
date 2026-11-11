import 'package:codex_native_unofficial/src/app/theme/official_codex_theme.dart';
import 'package:codex_native_unofficial/src/features/conversation/assistant_markdown.dart';
import 'package:flutter/material.dart';
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

      // Verify fenced code block geometry (8px radius, 0.5px hairline border, 32px header)
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
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));
