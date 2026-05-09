class TransportConstants {
  static const int defaultChunkSize = 1048576; // 1MB
  static const int socketBufferSize = 1048576 * 2; // 2MB socket buffer
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
}
