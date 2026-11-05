import '../../domain/model_models.dart';
import '../../domain/thread_models.dart';
import '../../protocol/protocol_models.dart';
import 'remote_credentials.dart';
import 'remote_protocol.dart';

abstract interface class RemoteSession {
  RemoteHandshake get handshake;
  RemoteResumeCursor? get resumeCursor;
  bool get requiresResync;
  int get resyncGeneration;
  int get currentSequence;
  Stream<RemoteResyncRequired> get resyncEvents;
  Stream<RemoteSequencedNotification> get sequencedNotifications;
  Future<RemoteTransportClose> get closed;

  Future<InitializeResult> initialize(InitializeRequest request);
  Future<RemoteStatus> status();
  Future<ModelPage> listModels(ModelListQuery query);
  Future<ThreadPage> listThreads(ThreadListQuery query);
  void completeResync({required int generation});
  Future<void> close();
}

typedef RemoteSessionConnector = Future<RemoteSession> Function(
  RemoteCredentialRecord record,
  RemoteResumeCursor? resumeCursor,
);
