import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../protocol/remote_pairing_invitation.dart';
import '../../protocol/remote_trust.dart';
import 'remote_credentials.dart';
import 'remote_http_client.dart';
import 'remote_protocol.dart';

const _pairingProtocolVersion = 1;
const _deviceIdLength = 22;
const _maximumDeviceNameCharacters = 80;
const _maximumPairingBodyBytes = 8 * 1024;

enum RemotePairingFailure {
  invalidInput,
  timeout,
  tlsRejected,
  networkUnavailable,
  ticketRejected,
  deviceLimitReached,
  rateLimited,
  incompatibleHost,
  malformedResponse,
  hostFailed,
}

final class RemotePairingException implements Exception {
  const RemotePairingException(this.failure);

  final RemotePairingFailure failure;

  @override
  String toString() => 'Remote pairing failed.';
}

abstract interface class RemotePairingGateway {
  Future<RemoteCredentialRecord> pair({
    required String invitation,
    required String deviceName,
  });
}

enum RemotePairingExchangeFailure {
  timeout,
  tlsRejected,
  networkUnavailable,
  responseTooLarge,
}

final class RemotePairingExchangeException implements Exception {
  const RemotePairingExchangeException(this.failure);

  final RemotePairingExchangeFailure failure;

  @override
  String toString() => 'Remote pairing exchange failed.';
}

final class RemotePairingHttpRequest {
  const RemotePairingHttpRequest({
    required this.uri,
    required this.body,
    required this.connectionTimeout,
    required this.requestTimeout,
    required this.maximumResponseBytes,
    required this.trust,
  });

  final Uri uri;
  final Uint8List body;
  final Duration connectionTimeout;
  final Duration requestTimeout;
  final int maximumResponseBytes;
  final RemoteTrust trust;

  @override
  String toString() => 'RemotePairingHttpRequest(<redacted>)';
}

final class RemotePairingHttpResponse {
  const RemotePairingHttpResponse({
    required this.statusCode,
    required this.contentType,
    required this.body,
  });

  final int statusCode;
  final String? contentType;
  final Uint8List body;

  @override
  String toString() => 'RemotePairingHttpResponse($statusCode, <redacted>)';
}

abstract interface class RemotePairingHttpExchange {
  Future<RemotePairingHttpResponse> post(RemotePairingHttpRequest request);
}

final class IoRemotePairingHttpExchange implements RemotePairingHttpExchange {
  const IoRemotePairingHttpExchange();

  @override
  Future<RemotePairingHttpResponse> post(
    RemotePairingHttpRequest request,
  ) async {
    HttpClient? client;
    try {
      client = createRemoteHttpClient(request.trust)
        ..autoUncompress = false
        ..connectionTimeout = request.connectionTimeout
        ..idleTimeout = request.requestTimeout
        ..maxConnectionsPerHost = 1;
      return await _post(client, request).timeout(
        request.requestTimeout,
        onTimeout: () {
          client?.close(force: true);
          throw const RemotePairingExchangeException(
            RemotePairingExchangeFailure.timeout,
          );
        },
      );
    } on RemotePairingExchangeException {
      rethrow;
    } on TlsException {
      throw const RemotePairingExchangeException(
        RemotePairingExchangeFailure.tlsRejected,
      );
    } on SocketException {
      throw const RemotePairingExchangeException(
        RemotePairingExchangeFailure.networkUnavailable,
      );
    } on HttpException {
      throw const RemotePairingExchangeException(
        RemotePairingExchangeFailure.networkUnavailable,
      );
    } on TimeoutException {
      throw const RemotePairingExchangeException(
        RemotePairingExchangeFailure.timeout,
      );
    } finally {
      client?.close(force: true);
    }
  }

  static Future<RemotePairingHttpResponse> _post(
    HttpClient client,
    RemotePairingHttpRequest input,
  ) async {
    final request = await client.postUrl(input.uri);
    request
      ..followRedirects = false
      ..persistentConnection = false
      ..contentLength = input.body.length;
    request.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.acceptHeader, ContentType.json.mimeType)
      ..set(HttpHeaders.acceptEncodingHeader, 'identity')
      ..set(HttpHeaders.cacheControlHeader, 'no-store');
    request.add(input.body);
    final response = await request.close();
    final body = BytesBuilder(copy: false);
    var retainedBytes = 0;
    await for (final chunk in response) {
      retainedBytes += chunk.length;
      if (retainedBytes > input.maximumResponseBytes) {
        throw const RemotePairingExchangeException(
          RemotePairingExchangeFailure.responseTooLarge,
        );
      }
      body.add(chunk);
    }
    return RemotePairingHttpResponse(
      statusCode: response.statusCode,
      contentType: response.headers.contentType?.mimeType,
      body: body.takeBytes(),
    );
  }
}

final class RemotePairingClient implements RemotePairingGateway {
  factory RemotePairingClient({
    RemotePairingHttpExchange exchange = const IoRemotePairingHttpExchange(),
    Duration connectionTimeout = const Duration(seconds: 5),
    Duration requestTimeout = const Duration(seconds: 15),
    DateTime Function()? now,
  }) {
    if (connectionTimeout <= Duration.zero || requestTimeout <= Duration.zero) {
      throw ArgumentError('Remote pairing timeouts must be positive.');
    }
    return RemotePairingClient._(
      exchange,
      connectionTimeout,
      requestTimeout,
      now ?? DateTime.now,
    );
  }

  RemotePairingClient._(
    this._exchange,
    this.connectionTimeout,
    this.requestTimeout,
    this._now,
  );

  final RemotePairingHttpExchange _exchange;
  final Duration connectionTimeout;
  final Duration requestTimeout;
  final DateTime Function() _now;

  @override
  Future<RemoteCredentialRecord> pair({
    required String invitation,
    required String deviceName,
  }) async {
    final RemotePairingInvitation parsedInvitation;
    try {
      parsedInvitation = RemotePairingInvitation.decode(invitation);
    } on FormatException {
      throw const RemotePairingException(RemotePairingFailure.invalidInput);
    }
    if (parsedInvitation.expiresAtMs <= _now().millisecondsSinceEpoch) {
      throw const RemotePairingException(RemotePairingFailure.invalidInput);
    }
    final boundedDeviceName = _validatedDeviceName(deviceName);
    final requestBody = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'code': parsedInvitation.code,
          'deviceName': boundedDeviceName,
        }),
      ),
    );
    if (requestBody.length > _maximumPairingBodyBytes) {
      throw const RemotePairingException(RemotePairingFailure.invalidInput);
    }
    final pairingUri = parsedInvitation.endpoint.replace(
      scheme: 'https',
      path: '/v1/pair',
    );

    final RemotePairingHttpResponse response;
    try {
      response = await _exchange
          .post(
            RemotePairingHttpRequest(
              uri: pairingUri,
              body: requestBody,
              connectionTimeout: connectionTimeout,
              requestTimeout: requestTimeout,
              maximumResponseBytes: _maximumPairingBodyBytes,
              trust: parsedInvitation.trust,
            ),
          )
          .timeout(requestTimeout);
    } on RemotePairingExchangeException catch (error) {
      throw RemotePairingException(switch (error.failure) {
        RemotePairingExchangeFailure.timeout => RemotePairingFailure.timeout,
        RemotePairingExchangeFailure.tlsRejected =>
          RemotePairingFailure.tlsRejected,
        RemotePairingExchangeFailure.networkUnavailable =>
          RemotePairingFailure.networkUnavailable,
        RemotePairingExchangeFailure.responseTooLarge =>
          RemotePairingFailure.malformedResponse,
      });
    } on TimeoutException {
      throw const RemotePairingException(RemotePairingFailure.timeout);
    } on Object {
      throw const RemotePairingException(
        RemotePairingFailure.networkUnavailable,
      );
    }

    if (response.body.length > _maximumPairingBodyBytes) {
      throw const RemotePairingException(
        RemotePairingFailure.malformedResponse,
      );
    }
    switch (response.statusCode) {
      case HttpStatus.unauthorized:
        throw const RemotePairingException(RemotePairingFailure.ticketRejected);
      case HttpStatus.conflict:
        throw const RemotePairingException(
          RemotePairingFailure.deviceLimitReached,
        );
      case HttpStatus.tooManyRequests:
        throw const RemotePairingException(RemotePairingFailure.rateLimited);
      case >= 500 && <= 599:
        throw const RemotePairingException(RemotePairingFailure.hostFailed);
      case != HttpStatus.ok:
        throw const RemotePairingException(
          RemotePairingFailure.incompatibleHost,
        );
    }
    if (response.contentType?.toLowerCase() != ContentType.json.mimeType) {
      throw const RemotePairingException(
        RemotePairingFailure.malformedResponse,
      );
    }
    return _decodeResponse(
      parsedInvitation.endpoint,
      response.body,
      parsedInvitation.trust,
    );
  }

  static String _validatedDeviceName(String value) {
    final name = value.trim();
    if (name.isEmpty ||
        name.runes.length > _maximumDeviceNameCharacters ||
        name.runes.any((rune) => rune < 0x20 || rune == 0x7f)) {
      throw const RemotePairingException(RemotePairingFailure.invalidInput);
    }
    return name;
  }

  static RemoteCredentialRecord _decodeResponse(
    Uri endpoint,
    Uint8List body,
    RemoteTrust trust,
  ) {
    try {
      final decoded = jsonDecode(utf8.decode(body));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException();
      }
      _requireExactKeys(decoded, const {'protocolVersion', 'device', 'token'});
      if (decoded['protocolVersion'] != _pairingProtocolVersion) {
        throw const FormatException();
      }
      final token = decoded['token'];
      final device = decoded['device'];
      if (token is! String || device is! Map<String, Object?>) {
        throw const FormatException();
      }
      validateRemoteCredential(token);
      _requireExactKeys(device, const {
        'id',
        'name',
        'scopes',
        'createdAtMs',
        'expiresAtMs',
        'lastSeenAtMs',
        'rotatedAtMs',
        'revokedAtMs',
      });
      final id = device['id'];
      final name = device['name'];
      final scopes = device['scopes'];
      final createdAtMs = device['createdAtMs'];
      final expiresAtMs = device['expiresAtMs'];
      if (id is! String ||
          !_isUrlSafe(id, exactLength: _deviceIdLength) ||
          name is! String ||
          name.isEmpty ||
          name != name.trim() ||
          name.runes.length > _maximumDeviceNameCharacters ||
          name.runes.any((rune) => rune < 0x20 || rune == 0x7f) ||
          scopes is! List<Object?> ||
          scopes.length != 2 ||
          scopes.toSet().length != scopes.length ||
          !scopes.every((scope) => scope is String) ||
          !scopes.contains('read') ||
          !scopes.contains('device_rotate') ||
          createdAtMs is! int ||
          createdAtMs < 0 ||
          expiresAtMs is! int ||
          expiresAtMs <= createdAtMs ||
          device['lastSeenAtMs'] != null ||
          device['rotatedAtMs'] != null ||
          device['revokedAtMs'] != null) {
        throw const FormatException();
      }
      return RemoteCredentialRecord(
        endpoint: endpoint,
        credential: token,
        deviceId: id,
        deviceName: name,
        trust: trust,
      );
    } on Object {
      throw const RemotePairingException(
        RemotePairingFailure.malformedResponse,
      );
    }
  }
}

void _requireExactKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.length != expected.length || !value.keys.every(expected.contains)) {
    throw const FormatException();
  }
}

bool _isUrlSafe(String value, {required int exactLength}) =>
    value.length == exactLength &&
    value.codeUnits.every(
      (unit) =>
          unit >= 0x30 && unit <= 0x39 ||
          unit >= 0x41 && unit <= 0x5a ||
          unit >= 0x61 && unit <= 0x7a ||
          unit == 0x2d ||
          unit == 0x5f,
    );
