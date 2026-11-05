import 'remote_admin_models.dart';

abstract interface class RemoteAdminGateway {
  Future<RemoteHostStatus> readRemoteAdminStatus();

  Future<RemotePairingTicket> createRemotePairingTicket();

  Future<List<RemotePairedDevice>> listRemotePairedDevices();

  Future<bool> revokeRemotePairedDevice(String deviceId);
}
