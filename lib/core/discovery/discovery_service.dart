import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'device_info.dart';
import 'discovery_constants.dart';

class DiscoveryService {
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  
  final List<DeviceInfo> _peers = [];
  final StreamController<List<DeviceInfo>> _peersController = StreamController<List<DeviceInfo>>.broadcast();

  Stream<List<DeviceInfo>> get peersStream => _peersController.stream;
  List<DeviceInfo> get currentPeers => List.unmodifiable(_peers);

  String _deviceName = '';
  String _platform = '';
  int _transferPort = 0;
  String? _localIp;

  Future<void> start({
    required String deviceName,
    required String platform,
    required int transferPort,
  }) async {
    _deviceName = deviceName;
    _platform = platform;
    _transferPort = transferPort;

    _localIp = await _getLocalIpAddress();

    try {
      // Bind to all interfaces (anyIPv4) for maximum compatibility
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 
        DiscoveryConstants.broadcastPort,
        reuseAddress: true,
        reusePort: true,
      );
      
      _socket!.broadcastEnabled = true;
      _socket!.multicastLoopback = false;

      // Join multicast group on all interfaces
      try {
        _socket!.joinMulticast(InternetAddress('224.0.0.1'));
        if (_localIp != null) {
          try {
            // Find the interface that matches our local IP
            final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
            final wifiInterface = interfaces.firstWhere(
              (i) => i.addresses.any((a) => a.address == _localIp),
            );
            _socket!.joinMulticast(InternetAddress('224.0.0.1'), wifiInterface);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Multicast join error: $e');
      }

      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            debugPrint('Received packet from ${datagram.address.address}');
            _handleDiscoveryMessage(datagram);
          }
        }
      });

      _broadcastTimer = Timer.periodic(DiscoveryConstants.broadcastInterval, (_) {
        _sendDiscoveryBroadcast();
      });

      _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _cleanupStalePeers();
      });

      debugPrint('DiscoveryService started on port ${DiscoveryConstants.broadcastPort} with IP $_localIp');
    } catch (e) {
      debugPrint('Error starting DiscoveryService: $e');
    }
  }

  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      if (interfaces.isNotEmpty) {
        // Return the first non-loopback IPv4 address
        for(var interface in interfaces) {
           for (var addr in interface.addresses) {
             if (addr.address.startsWith('192.168.') || addr.address.startsWith('10.') || addr.address.startsWith('172.')) {
               return addr.address;
             }
           }
        }
        return interfaces.first.addresses.first.address;
      }
    } catch (e) {
      debugPrint('Error getting local IP: $e');
    }
    return null;
  }

  void _sendDiscoveryBroadcast() {
    if (_socket == null || _localIp == null) return;

    final info = DeviceInfo(
      deviceName: _deviceName,
      platform: _platform,
      ip: _localIp!,
      transferPort: _transferPort,
      lastSeen: DateTime.now(),
    );

    final data = utf8.encode(info.toJson());
    try {
      // 1. Standard broadcast
      try {
        _socket!.send(data, InternetAddress('255.255.255.255'), DiscoveryConstants.broadcastPort);
      } catch (_) {}
      
      // 2. Multicast broadcast
      try {
        _socket!.send(data, InternetAddress('224.0.0.1'), DiscoveryConstants.broadcastPort);
      } catch (_) {}

      // 3. Subnet-specific broadcast (Most reliable for macOS)
      if (_localIp != null) {
        final parts = _localIp!.split('.');
        if (parts.length == 4) {
          final subnetBroadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
          try {
            _socket!.send(data, InternetAddress(subnetBroadcast), DiscoveryConstants.broadcastPort);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error sending broadcast: $e');
    }
  }

  void _handleDiscoveryMessage(Datagram datagram) {
    try {
      final jsonStr = utf8.decode(datagram.data);
      final map = json.decode(jsonStr) as Map<String, dynamic>;

      // Validate message
      if (map['app'] != DiscoveryConstants.appId) {
        return;
      }

      final senderIp = datagram.address.address;
      
      // Ignore self (improved check)
      if (senderIp == _localIp && map['transfer_port'] == _transferPort) {
        return;
      }

      final peer = DeviceInfo.fromMap(map, senderIp);
      _updatePeer(peer);
    } catch (e) {
      debugPrint('Error parsing discovery packet: $e');
    }
  }

  void _updatePeer(DeviceInfo peer) {
    final index = _peers.indexWhere((p) => p.ip == peer.ip && p.transferPort == peer.transferPort);
    
    bool changed = false;
    if (index >= 0) {
      _peers[index] = peer;
    } else {
      _peers.add(peer);
      changed = true;
    }

    if (changed) {
      _peersController.add(List.from(_peers));
    }
  }

  void _cleanupStalePeers() {
    final now = DateTime.now();
    bool changed = false;

    _peers.removeWhere((peer) {
      final isStale = now.difference(peer.lastSeen) > DiscoveryConstants.staleDeviceTimeout;
      if (isStale) changed = true;
      return isStale;
    });

    if (changed) {
      _peersController.add(List.from(_peers));
    }
  }

  void stop() {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
    _peers.clear();
    _peersController.add([]);
    debugPrint('DiscoveryService stopped');
  }
}
