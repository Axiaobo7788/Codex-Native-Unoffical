import 'remote_credentials.dart';
import 'remote_protocol.dart';
import 'remote_session.dart';
import 'remote_transport.dart';

Future<RemoteSession> connectRemoteSession(
  RemoteCredentialRecord record,
  RemoteResumeCursor? resumeCursor,
) => RemoteTransport.connect(
  endpoint: record.endpoint,
  credential: record.credential,
  resumeCursor: resumeCursor,
);
