import '../protocol/transfer_metadata.dart';

enum TransferStatus {
  idle,
  preparing,
  connecting,
  active,
  paused,
  completed,
  failed,
  cancelled,
}

enum TransferDirection { sending, receiving }

class TransferInfo {
  final TransferMetadata metadata;
  final TransferDirection direction;
  final String peerIp;
  final String peerName;

  TransferStatus status;
  int bytesTransferred;
  double speedBytesPerSecond;
  double preparationProgress;
  int completedChunks;
  String? error;

  TransferInfo({
    required this.metadata,
    required this.direction,
    required this.peerIp,
    required this.peerName,
    this.status = TransferStatus.idle,
    this.bytesTransferred = 0,
    this.speedBytesPerSecond = 0,
    this.preparationProgress = 0,
    this.completedChunks = 0,
    this.error,
  });

  double get progress => metadata.fileSize > 0
      ? bytesTransferred / metadata.fileSize
      : 0.0;

  String get id => metadata.transferId;
}
