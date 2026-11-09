import 'dart:convert';
import 'dart:io';

// This offline server serves only the methods used by mcp_smoke.dart.
const fixtureServer = 'native_fixture';
const fixtureTool = 'fixture_echo';
const fixtureUri = 'memory://native-fixture/demo.txt';
const fixtureFormUri = 'memory://native-fixture/needs-form';

Future<void> main() async {
  ({Object id, String? uri})? eliciting;
  void send(Map<String, Object?> body) {
    stdout.writeln(jsonEncode({'jsonrpc': '2.0', ...body}));
  }

  void reply(Object id, Object result) => send({'id': id, 'result': result});

  void askForValue(Object id, {String? uri}) {
    eliciting = (id: id, uri: uri);
    send({
      'id': 'fixture-elicitation',
      'method': 'elicitation/create',
      'params': {
        'mode': 'form',
        'message': 'Fixture value',
        'requestedSchema': {
          'type': 'object',
          'properties': {
            'value': {'type': 'string'},
          },
          'required': ['value'],
        },
      },
    });
  }

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final request = jsonDecode(line) as Map<String, Object?>;
    final id = request['id'];
    if (id == null) continue;
    final pending = eliciting;
    if (id == 'fixture-elicitation' && pending != null) {
      final result = request['result'] as Map<String, Object?>?;
      final content = result?['content'] as Map<String, Object?>?;
      final text = "${result?['action']}: ${content?['value']}";
      final uri = pending.uri;
      if (uri != null) {
        reply(pending.id, {
          'contents': [
            {'uri': uri, 'mimeType': 'text/plain', 'text': text},
          ],
        });
      } else {
        reply(pending.id, {
          'content': [
            {'type': 'text', 'text': text},
          ],
          'isError': result?['action'] != 'accept',
        });
      }
      eliciting = null;
      continue;
    }
    final params = request['params'] as Map<String, Object?>? ?? const {};
    switch (request['method']) {
      case 'initialize':
        reply(id, {
          'protocolVersion': params['protocolVersion'],
          'capabilities': {'tools': {}, 'resources': {}},
          'serverInfo': {'name': 'native-fixture', 'version': '1.0.0'},
        });
      case 'tools/list':
        reply(id, {
          'tools': [
            {
              'name': fixtureTool,
              'description': 'Echo one disposable test value.',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'value': {'type': 'string'},
                },
                'required': ['value'],
              },
            },
          ],
        });
      case 'resources/list':
        reply(id, {
          'resources': [
            {
              'uri': fixtureUri,
              'name': 'Disposable fixture',
              'mimeType': 'text/plain',
            },
          ],
        });
      case 'resources/templates/list':
        reply(id, {'resourceTemplates': []});
      case 'resources/read':
        if (params['uri'] == fixtureFormUri) {
          askForValue(id, uri: fixtureFormUri);
          continue;
        }
        reply(id, {
          'contents': [
            {
              'uri': fixtureUri,
              'mimeType': 'text/plain',
              'text': 'native fixture resource',
            },
          ],
        });
      case 'tools/call':
        final value = (params['arguments'] as Map<String, Object?>)['value'];
        if (value == 'needs-form') {
          askForValue(id);
        } else {
          reply(id, {
            'content': [
              {'type': 'text', 'text': 'echo: $value'},
            ],
            'structuredContent': {'result': value},
            'isError': false,
          });
        }
      case 'ping':
        reply(id, const {});
      default:
        send({
          'id': id,
          'error': {'code': -32601, 'message': 'Fixture method unavailable.'},
        });
    }
  }
}
