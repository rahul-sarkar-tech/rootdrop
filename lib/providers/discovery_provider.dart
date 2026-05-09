import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/discovery/discovery_service.dart';
import '../core/discovery/device_info.dart';

class DiscoveryProvider extends ChangeNotifier {
  final DiscoveryService _service = DiscoveryService();
  List<DeviceInfo> _devices = [];
  bool _isDiscovering = false;

  List<DeviceInfo> get devices => _devices;
  bool get isDiscovering => _isDiscovering;

  Future<void> startDiscovery(int transferPort) async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    notifyListeners();

    await _service.start(
      deviceName: Platform.localHostname,
      platform: Platform.operatingSystem,
      transferPort: transferPort,
    );

    _service.peersStream.listen((peers) {
      _devices = peers;
      notifyListeners();
    });
  }

  void stopDiscovery() {
    _service.stop();
    _isDiscovering = false;
    _devices.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _service.stop();
    super.dispose();
  }
}
