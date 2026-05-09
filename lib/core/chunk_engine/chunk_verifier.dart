import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class ChunkVerifier {
  /// Computes the SHA256 hash of a chunk's data
  static String computeHash(Uint8List data) {
    return sha256.convert(data).toString();
  }

  /// Verifies if the data matches the expected hash
  static bool verify(Uint8List data, String expectedHash) {
    if (expectedHash.isEmpty) return true; // Skip verification if no hash provided
    return computeHash(data) == expectedHash;
  }
}
