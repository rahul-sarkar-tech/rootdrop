class DiscoveryConstants {
  static const int broadcastPort = 41234;
  static const Duration broadcastInterval = Duration(seconds: 2);
  static const Duration staleDeviceTimeout = Duration(seconds: 10);
  static const int protocolVersion = 1;
  static const String appId = 'rootdrop';
  static const int transferPort = 53000;
}
