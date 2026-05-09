import 'dart:convert';
import 'dart:typed_data';

/// Encodes and decodes the RootDrop wire protocol.
///
/// Wire format:
///   [4 bytes: JSON header length (big-endian)] + [N bytes: JSON UTF-8] + [M bytes: binary payload]
class MessageCodec {
  /// Encodes a message with JSON metadata and optional binary payload.
  static Uint8List encode(Map<String, dynamic> metadata, [Uint8List? payload]) {
    final jsonStr = json.encode(metadata);
    final jsonBytes = utf8.encode(jsonStr);

    final headerLength = jsonBytes.length;

    final builder = BytesBuilder(copy: false);

    // Write 4 bytes header length (big-endian)
    final lengthBytes = ByteData(4)..setUint32(0, headerLength, Endian.big);
    builder.add(lengthBytes.buffer.asUint8List());

    // Write JSON bytes
    builder.add(Uint8List.fromList(jsonBytes));

    // Write binary payload if present
    if (payload != null) {
      builder.add(payload);
    }

    return builder.toBytes();
  }

  /// Attempts to decode one complete message from a byte buffer.
  /// Returns null if the buffer doesn't contain enough data yet.
  static DecodedMessage? decode(Uint8List data) {
    if (data.length < 4) return null;

    final lengthBytes = ByteData.sublistView(data, 0, 4);
    final headerLength = lengthBytes.getUint32(0, Endian.big);

    if (data.length < 4 + headerLength) return null;

    final jsonBytes = data.sublist(4, 4 + headerLength);
    final jsonStr = utf8.decode(jsonBytes);
    final metadata = json.decode(jsonStr) as Map<String, dynamic>;

    // chunk_data messages carry a binary payload whose size is in `chunk_size`
    final hasPayload = metadata['type'] == 'chunk_data';

    if (hasPayload) {
      final payloadSize = metadata['chunk_size'] as int?;
      if (payloadSize != null) {
        if (data.length < 4 + headerLength + payloadSize) {
          return null; // Not enough data for payload yet
        }
        final payload = data.sublist(4 + headerLength, 4 + headerLength + payloadSize);
        final remaining = data.sublist(4 + headerLength + payloadSize);
        return DecodedMessage(metadata: metadata, payload: payload, remaining: remaining);
      }
    }

    final remaining = data.sublist(4 + headerLength);
    return DecodedMessage(metadata: metadata, remaining: remaining);
  }
}

/// Result of decoding a single protocol message.
class DecodedMessage {
  final Map<String, dynamic> metadata;
  final Uint8List? payload;
  final Uint8List remaining;

  DecodedMessage({
    required this.metadata,
    this.payload,
    required this.remaining,
  });
}
