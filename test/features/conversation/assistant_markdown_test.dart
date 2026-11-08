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
        const AssistantMarkdown(data: '**partial response', completed: false),
      ),
    );

    expect(
      find.byKey(const ValueKey('assistant-streaming-text')),
      findsOneWidget,
    );
    expect(find.text('**partial response'), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-markdown')), findsNothing);
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
    },
  );
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));
