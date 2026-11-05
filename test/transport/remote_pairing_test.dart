import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:codex_native_unofficial/src/transport/remote/remote_pairing.dart';
import 'package:codex_native_unofficial/src/protocol/remote_pairing_invitation.dart';
import 'package:codex_native_unofficial/src/protocol/remote_trust.dart';
import 'package:flutter_test/flutter_test.dart';

const _code = 'AAAAAAAAAAAAAAAAAAAAAAAA';
const _token = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
const _deviceId = 'CCCCCCCCCCCCCCCCCCCCCC';

void main() {
  group('RemotePairingClient', () {
    test(
      'posts a bounded same-origin request and validates the credential',
      () async {
        final exchange = _FakeExchange(response: _validResponse());
        final client = RemotePairingClient(exchange: exchange);

        final record = await client.pair(
          invitation: _invitation(endpoint: 'wss://host.example:8443/v1/ws'),
          deviceName: '  Test phone  ',
        );

        expect(record.endpoint, Uri.parse('wss://host.example:8443/v1/ws'));
        expect(record.credential, _token);
        expect(record.deviceId, _deviceId);
        expect(record.deviceName, 'Test phone');
        expect(exchange.requests, hasLength(1));
        final request = exchange.requests.single;
        expect(request.uri, Uri.parse('https://host.example:8443/v1/pair'));
        expect(request.connectionTimeout, const Duration(seconds: 5));
        expect(request.requestTimeout, const Duration(seconds: 15));
        expect(request.maximumResponseBytes, 8 * 1024);
        expect(request.trust.kind, RemoteTrustKind.system);
        expect(jsonDecode(utf8.decode(request.body)), {
          'code': _code,
          'deviceName': 'Test phone',
        });
        expect(request.toString(), isNot(contains(_code)));
        expect(record.toString(), isNot(contains(_token)));
        expect(record.toString(), isNot(contains('host.example')));
      },
    );

    test('rejects unsafe or unbounded inputs before network access', () async {
      final exchange = _FakeExchange(response: _validResponse());
      final client = RemotePairingClient(exchange: exchange);
      final cases = <({String invitation, String name})>[
        (invitation: 'not-an-invitation', name: 'Phone'),
        (
          invitation: _rawInvitation(
            endpoint: 'ws://127.0.0.1/v1/ws',
            code: _code,
          ),
          name: 'Phone',
        ),
        (
          invitation: _rawInvitation(
            endpoint: 'wss://host.example/v1/ws',
            code: 'short',
          ),
          name: 'Phone',
        ),
        (invitation: _invitation(), name: 'Phone\nInjected'),
        (invitation: _invitation(), name: List.filled(81, 'x').join()),
        (invitation: _invitation(expiresAtMs: 1), name: 'Phone'),
      ];

      for (final input in cases) {
        await expectLater(
          client.pair(invitation: input.invitation, deviceName: input.name),
          throwsA(
            isA<RemotePairingException>().having(
              (error) => error.failure,
              'failure',
              RemotePairingFailure.invalidInput,
            ),
          ),
        );
      }
      expect(exchange.requests, isEmpty);
    });

    test(
      'maps bounded Host status failures without parsing their bodies',
      () async {
        for (final entry in {
          HttpStatus.unauthorized: RemotePairingFailure.ticketRejected,
          HttpStatus.conflict: RemotePairingFailure.deviceLimitReached,
          HttpStatus.tooManyRequests: RemotePairingFailure.rateLimited,
          HttpStatus.notFound: RemotePairingFailure.incompatibleHost,
          HttpStatus.internalServerError: RemotePairingFailure.hostFailed,
        }.entries) {
          final client = RemotePairingClient(
            exchange: _FakeExchange(
              response: RemotePairingHttpResponse(
                statusCode: entry.key,
                contentType: ContentType.json.mimeType,
                body: Uint8List.fromList(utf8.encode('{private-error-body')),
              ),
            ),
          );

          await expectLater(
            client.pair(invitation: _invitation(), deviceName: 'Phone'),
            throwsA(
              isA<RemotePairingException>()
                  .having((error) => error.failure, 'failure', entry.value)
                  .having(
                    (error) => error.toString(),
                    'redacted error',
                    isNot(contains('private-error-body')),
                  ),
            ),
          );
        }
      },
    );

    test(
      'carries one certificate trust into pairing and saved record',
      () async {
        final trust = RemoteCertificateTrust([0x30, 0x01, 0x00]);
        final exchange = _FakeExchange(response: _validResponse());
        final client = RemotePairingClient(exchange: exchange);

        final record = await client.pair(
          invitation: _invitation(trust: trust),
          deviceName: 'Phone',
        );

        expect(
          exchange.requests.single.trust.kind,
          RemoteTrustKind.certificate,
        );
        expect(record.trustKind, RemoteTrustKind.certificate);
        expect(
          (record.trust as RemoteCertificateTrust).certificate,
          trust.certificate,
        );
      },
    );

    test(
      'rejects malformed, incompatible, and oversized success bodies',
      () async {
        final valid = _validPayload();
        final withUnknown = Map<String, Object?>.from(valid)..['extra'] = true;
        final wrongVersion = Map<String, Object?>.from(valid)
          ..['protocolVersion'] = 2;
        final wrongScopes = Map<String, Object?>.from(valid)
          ..['device'] = {
            ...(valid['device']! as Map<String, Object?>),
            'scopes': ['read'],
          };
        final cases = [
          RemotePairingHttpResponse(
            statusCode: HttpStatus.ok,
            contentType: 'text/plain',
            body: Uint8List.fromList(utf8.encode(jsonEncode(valid))),
          ),
          _jsonResponse(withUnknown),
          _jsonResponse(wrongVersion),
          _jsonResponse(wrongScopes),
          RemotePairingHttpResponse(
            statusCode: HttpStatus.ok,
            contentType: ContentType.json.mimeType,
            body: Uint8List(8 * 1024 + 1),
          ),
        ];

        for (final response in cases) {
          final client = RemotePairingClient(
            exchange: _FakeExchange(response: response),
          );
          await expectLater(
            client.pair(invitation: _invitation(), deviceName: 'Phone'),
            throwsA(
              isA<RemotePairingException>().having(
                (error) => error.failure,
                'failure',
                RemotePairingFailure.malformedResponse,
              ),
            ),
          );
        }
      },
    );

    test('enforces the whole-request deadline around an exchange', () async {
      final exchange = _FakeExchange(pending: Completer());
      final client = RemotePairingClient(
        exchange: exchange,
        requestTimeout: const Duration(milliseconds: 5),
      );

      await expectLater(
        client.pair(invitation: _invitation(), deviceName: 'Phone'),
        throwsA(
          isA<RemotePairingException>().having(
            (error) => error.failure,
            'failure',
            RemotePairingFailure.timeout,
          ),
        ),
      );
    });
  });
}

String _invitation({
  String endpoint = 'wss://host.example/v1/ws',
  int expiresAtMs = 4102444800000,
  RemoteTrust trust = const RemoteSystemTrust(),
}) => RemotePairingInvitation(
  endpoint: Uri.parse(endpoint),
  code: _code,
  expiresAtMs: expiresAtMs,
  trust: trust,
).encode();

String _rawInvitation({required String endpoint, required String code}) {
  final payload = utf8.encode(
    jsonEncode({
      'version': 1,
      'endpoint': endpoint,
      'code': code,
      'expiresAtMs': 4102444800000,
      'trust': {'type': 'system'},
    }),
  );
  return '$remotePairingInvitationPrefix${base64Url.encode(payload).replaceAll('=', '')}';
}

Map<String, Object?> _validPayload() => {
  'protocolVersion': 1,
  'device': {
    'id': _deviceId,
    'name': 'Test phone',
    'scopes': ['read', 'device_rotate'],
    'createdAtMs': 100,
    'expiresAtMs': 200,
    'lastSeenAtMs': null,
    'rotatedAtMs': null,
    'revokedAtMs': null,
  },
  'token': _token,
};

RemotePairingHttpResponse _validResponse() => _jsonResponse(_validPayload());

RemotePairingHttpResponse _jsonResponse(Map<String, Object?> value) =>
    RemotePairingHttpResponse(
      statusCode: HttpStatus.ok,
      contentType: ContentType.json.mimeType,
      body: Uint8List.fromList(utf8.encode(jsonEncode(value))),
    );

final class _FakeExchange implements RemotePairingHttpExchange {
  _FakeExchange({this.response, this.pending});

  final RemotePairingHttpResponse? response;
  final Completer<RemotePairingHttpResponse>? pending;
  final List<RemotePairingHttpRequest> requests = [];

  @override
  Future<RemotePairingHttpResponse> post(RemotePairingHttpRequest request) {
    requests.add(request);
    return pending?.future ?? Future.value(response!);
  }
}
