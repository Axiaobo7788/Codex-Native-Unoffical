import '../protocol/protocol_models.dart';

abstract interface class CodexTransport {
  Stream<CodexNotification> get notifications;
  Stream<CodexServerRequest> get serverRequests;
  Stream<ProtocolViolation> get protocolErrors;

  Future<InitializeResult> initialize(InitializeRequest request);
  Future<void> close();
}
