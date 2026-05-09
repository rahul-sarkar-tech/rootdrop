import 'dart:convert';

class TransferMetadata {
  final String transferId;
  final String fileName;
  final int fileSize;
  final int chunkSize;
  final int totalChunks;

  TransferMetadata({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.chunkSize,
    required this.totalChunks,
  });

  Map<String, dynamic> toMap() {
    return {
      'transfer_id': transferId,
      'file_name': fileName,
      'file_size': fileSize,
      'chunk_size': chunkSize,
      'total_chunks': totalChunks,
    };
  }

  factory TransferMetadata.fromMap(Map<String, dynamic> map) {
    return TransferMetadata(
      transferId: map['transfer_id'] ?? '',
      fileName: map['file_name'] ?? '',
      fileSize: map['file_size']?.toInt() ?? 0,
      chunkSize: map['chunk_size']?.toInt() ?? 0,
      totalChunks: map['total_chunks']?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory TransferMetadata.fromJson(String source) =>
      TransferMetadata.fromMap(json.decode(source));
}
