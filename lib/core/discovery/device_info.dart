import 'dart:convert';

class DeviceInfo {
  final String deviceName;
  final String platform;
  final String ip;
  final int transferPort;
  final DateTime lastSeen;

  DeviceInfo({
    required this.deviceName,
    required this.platform,
    required this.ip,
    required this.transferPort,
    required this.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'app': 'rootdrop',
      'version': 1,
      'device_name': deviceName,
      'platform': platform,
      'ip': ip,
      'transfer_port': transferPort,
      'timestamp': lastSeen.millisecondsSinceEpoch,
    };
  }

  factory DeviceInfo.fromMap(Map<String, dynamic> map, String senderIp) {
    return DeviceInfo(
      deviceName: map['device_name'] ?? 'Unknown Device',
      platform: map['platform'] ?? 'unknown',
      ip: senderIp,
      transferPort: map['transfer_port'] ?? 0,
      lastSeen: DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory DeviceInfo.fromJson(String source, String senderIp) =>
      DeviceInfo.fromMap(json.decode(source), senderIp);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is DeviceInfo &&
      other.ip == ip &&
      other.transferPort == transferPort;
  }

  @override
  int get hashCode {
    return ip.hashCode ^ transferPort.hashCode;
  }
}
