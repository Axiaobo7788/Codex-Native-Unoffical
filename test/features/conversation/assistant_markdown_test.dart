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
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));
