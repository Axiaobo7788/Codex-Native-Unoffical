import 'remote_credentials.dart';
import 'remote_http_client.dart';
import 'remote_protocol.dart';
import 'remote_session.dart';
import 'remote_socket.dart';
import 'remote_transport.dart';

Future<RemoteSession> connectRemoteSession(
  RemoteCredentialRecord record,
  RemoteResumeCursor? resumeCursor,
) => RemoteTransport.connect(
  endpoint: record.endpoint,
  credential: record.credential,
  resumeCursor: resumeCursor,
  connector: (endpoint, credential) => IoRemoteSocket.connect(
    endpoint,
    credential,
    client: createRemoteHttpClient(record.trust),
  ),
);
