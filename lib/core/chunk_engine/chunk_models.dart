import 'dart:convert';

enum ChunkState { pending, downloading, completed, failed }

class ChunkInfo {
  final int index;
  final int offset;
  final int size;
  final String expectedHash;
  ChunkState state;
  int retryCount;

  ChunkInfo({
    required this.index,
    required this.offset,
    required this.size,
    required this.expectedHash,
    this.state = ChunkState.pending,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'offset': offset,
      'size': size,
      'expected_hash': expectedHash,
      'state': state.index,
      'retry_count': retryCount,
    };
  }

  factory ChunkInfo.fromMap(Map<String, dynamic> map) {
    return ChunkInfo(
      index: map['index']?.toInt() ?? 0,
      offset: map['offset']?.toInt() ?? 0,
      size: map['size']?.toInt() ?? 0,
      expectedHash: map['expected_hash'] ?? '',
      state: ChunkState.values[map['state']?.toInt() ?? 0],
      retryCount: map['retry_count']?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory ChunkInfo.fromJson(String source) => ChunkInfo.fromMap(json.decode(source));
}
