import 'package:flutter/foundation.dart';

import '../../domain/remote_admin_gateway.dart';
import '../../domain/remote_admin_models.dart';

enum RemoteAdminPhase { idle, loading, ready, creatingTicket, revoking, failed }

final class RemoteAdminController extends ChangeNotifier {
  RemoteAdminController({required this.gateway, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final RemoteAdminGateway gateway;
  final DateTime Function() _now;
  RemoteAdminPhase _phase = RemoteAdminPhase.idle;
  RemoteHostStatus? _status;
  List<RemotePairedDevice> _devices = const [];
  RemotePairingTicket? _ticket;
  String? _errorMessage;
  var _generation = 0;
  var _disposed = false;

  RemoteAdminPhase get phase => _phase;
  RemoteHostStatus? get status => _status;
  List<RemotePairedDevice> get devices => _devices;
  RemotePairingTicket? get ticket => _ticket;
  String? get errorMessage => _errorMessage;
  bool get isBusy => switch (_phase) {
    RemoteAdminPhase.loading ||
    RemoteAdminPhase.creatingTicket ||
    RemoteAdminPhase.revoking => true,
    _ => false,
  };
  bool get canCreatePairingTicket =>
      _phase == RemoteAdminPhase.ready &&
      _status?.canCreatePairingTicket == true;
  bool get canRevokeDevices => _phase == RemoteAdminPhase.ready;

  Future<void> refresh() async {
    if (isBusy || _disposed) {
      return;
    }
    final generation = ++_generation;
    _phase = RemoteAdminPhase.loading;
    _ticket = null;
    _devices = const [];
    _errorMessage = null;
    notifyListeners();
    try {
      final status = await gateway.readRemoteAdminStatus();
      if (!_isCurrent(generation)) {
        return;
      }
      _status = status;
      notifyListeners();
      final devices = await gateway.listRemotePairedDevices();
      if (!_isCurrent(generation)) {
        return;
      }
      _devices = devices;
      _phase = RemoteAdminPhase.ready;
    } on Object {
      if (!_isCurrent(generation)) {
        return;
      }
      _phase = RemoteAdminPhase.failed;
      _errorMessage =
          'Remote setup could not read trusted local Host state. Retry after '
          'checking the Host configuration and device store.';
    }
    if (_isCurrent(generation)) {
      notifyListeners();
    }
  }

  Future<void> createPairingTicket() async {
    final expectedEndpoint = _status?.advertisedEndpoint;
    if (!canCreatePairingTicket || expectedEndpoint == null || _disposed) {
      return;
    }
    final generation = ++_generation;
    _phase = RemoteAdminPhase.creatingTicket;
    _ticket = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final ticket = await gateway.createRemotePairingTicket();
      if (!_isCurrent(generation)) {
        return;
      }
      if (ticket.endpoint != expectedEndpoint ||
          ticket.expiresAtMs <= _now().millisecondsSinceEpoch) {
        throw StateError('Host pairing ticket did not match current status.');
      }
      _ticket = ticket;
      _phase = RemoteAdminPhase.ready;
    } on Object {
      if (!_isCurrent(generation)) {
        return;
      }
      _phase = RemoteAdminPhase.failed;
      _errorMessage =
          'The Host could not create a current one-use pairing ticket. Refresh '
          'the setup state before trying again.';
    }
    if (_isCurrent(generation)) {
      notifyListeners();
    }
  }

  Future<void> revokeDevice(RemotePairedDevice device) async {
    if (!canRevokeDevices ||
        _disposed ||
        !_devices.any((item) => item.id == device.id)) {
      return;
    }
    final generation = ++_generation;
    _phase = RemoteAdminPhase.revoking;
    _errorMessage = null;
    notifyListeners();
    try {
      final changed = await gateway.revokeRemotePairedDevice(device.id);
      final devices = await gateway.listRemotePairedDevices();
      if (!_isCurrent(generation)) {
        return;
      }
      _devices = devices;
      _phase = RemoteAdminPhase.ready;
      if (!changed) {
        _errorMessage =
            'The selected device had already changed. The list was refreshed.';
      }
    } on Object {
      if (!_isCurrent(generation)) {
        return;
      }
      _phase = RemoteAdminPhase.failed;
      _errorMessage =
          'The Host could not revoke the selected device. Its current state '
          'was not assumed.';
    }
    if (_isCurrent(generation)) {
      notifyListeners();
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _ticket = null;
    super.dispose();
  }
}
