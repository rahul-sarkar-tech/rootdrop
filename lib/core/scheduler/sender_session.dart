import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../protocol/message_types.dart';
import '../protocol/transfer_metadata.dart';
import '../chunk_engine/chunk_models.dart';
import '../chunk_engine/chunk_splitter.dart';
import '../transport/tcp_client.dart';
import '../storage/random_access_io.dart';
import 'transfer_models.dart';

/// Manages the sender side of a single file transfer.
///
/// Connects to the receiver's TCP server, sends an offer, then responds to
/// chunk requests by reading data via RandomAccessFile.
class SenderSession {
  final TransferMetadata metadata;
  final File file;
  final String targetIp;
  final int targetPort;
  final Function(TransferInfo) onUpdate;

  final List<TcpClient> _clients = [];
  RandomAccessIo? _io;
  List<ChunkInfo> _chunks = [];
  Timer? _speedTimer;
  int _lastBytesTransferred = 0;

  static const int parallelPipes = 4; // Use 4 simultaneous pipes for speed

  late TransferInfo _info;

  SenderSession({
    required this.metadata,
    required this.file,
    required this.targetIp,
    required this.targetPort,
    required String peerName,
    required this.onUpdate,
  }) {
    _info = TransferInfo(
      metadata: metadata,
      direction: TransferDirection.sending,
      peerIp: targetIp,
      peerName: peerName,
    );
  }

  TransferInfo get info => _info;

  Future<void> start() async {
    _updateStatus(TransferStatus.preparing);

    try {
      // 1. Initialize IO and generate chunk manifest with hashes
      _io = RandomAccessIo(file);
      await _io!.openRead();

      final splitter = ChunkSplitter(file, chunkSize: metadata.chunkSize);
      _chunks = await splitter.generateChunkManifest(
        onProgress: (p) {
          _info.preparationProgress = p;
          onUpdate(_info);
        },
      );

      _updateStatus(TransferStatus.connecting);
      final primaryClient = TcpClient(
        host: targetIp,
        port: targetPort,
        onMessage: _handleMessage,
        onError: _handleError,
        onDisconnect: () => _handleDisconnect(),
      );

      _clients.add(primaryClient);
      await primaryClient.connect();

      // 3. Send transfer offer on primary pipe
      primaryClient.sendMessage({
        'type': MessageTypes.transferOffer,
        ...metadata.toMap(),
      });

      // 4. Open parallel pipes
      for (int i = 1; i < parallelPipes; i++) {
        _openParallelPipe();
      }
    } catch (e) {
      _updateStatus(TransferStatus.failed, error: e.toString());
      _cleanup();
    }
  }

  Future<void> _openParallelPipe() async {
    try {
      final client = TcpClient(
        host: targetIp,
        port: targetPort,
        onMessage: _handleMessage,
        onError: (_) {}, // Primary pipe handles errors
        onDisconnect: () {},
      );

      _clients.add(client);
      await client.connect();
      
      client.sendMessage({
        'type': MessageTypes.socketJoin,
        'transfer_id': metadata.transferId,
      });
    } catch (e) {
      debugPrint('Error opening parallel pipe: $e');
    }
  }

  void _handleDisconnect() {
    if (_info.status != TransferStatus.completed && _info.status != TransferStatus.cancelled) {
      _updateStatus(TransferStatus.failed, error: 'Connection lost');
    }
  }

  void _handleMessage(Map<String, dynamic> msgMetadata, Uint8List? payload, TcpClient? sourceClient) {
    if (msgMetadata['transfer_id'] != metadata.transferId) return;

    final type = msgMetadata['type'];

    switch (type) {
      case MessageTypes.transferAccept:
        _updateStatus(TransferStatus.active);
        _startSpeedTimer();
        break;

      case MessageTypes.transferReject:
        _updateStatus(TransferStatus.cancelled, error: 'Receiver rejected transfer');
        _cleanup();
        break;

      case MessageTypes.chunkRequest:
        // Find which client sent this request to send it back on the same pipe
        // Actually, we can just find the client in the list if we had the context
        // Let's improve the TcpClient to pass itself in the callback
        _handleChunkRequest(msgMetadata['chunk_index'], sourceClient);
        break;

      case MessageTypes.chunkAck:
        _info.completedChunks++;
        if (_info.completedChunks >= _chunks.length) {
          _updateStatus(TransferStatus.completed);
          _cleanup();
        } else {
          onUpdate(_info);
        }
        break;

      case MessageTypes.transferCancel:
        _updateStatus(TransferStatus.cancelled, error: 'Receiver cancelled transfer');
        _cleanup();
        break;
    }
  }

  Future<void> _handleChunkRequest(int index, TcpClient? client) async {
    if (index < 0 || index >= _chunks.length || _io == null) return;

    try {
      final chunk = _chunks[index];
      final startTime = DateTime.now();
      final data = await _io!.readChunk(chunk.offset, chunk.size);
      final duration = DateTime.now().difference(startTime);

      // Use the provided client or fallback to primary
      final targetClient = client ?? _clients.first;

      targetClient.sendMessage({
        'type': MessageTypes.chunkData,
        'transfer_id': metadata.transferId,
        'chunk_index': index,
        'chunk_size': chunk.size,
        'sha256': chunk.expectedHash,
      }, data);

      debugPrint('Chunked: Sent #${index} (${data.length} bytes) via Parallel Pipe - Read took ${duration.inMilliseconds}ms');

      _info.bytesTransferred += data.length;
      onUpdate(_info);
    } catch (e) {
      debugPrint('Error sending chunk $index: $e');
    }
  }

  void _handleError(dynamic error) {
    _updateStatus(TransferStatus.failed, error: error.toString());
    _cleanup();
  }

  void _startSpeedTimer() {
    _speedTimer?.cancel();
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_info.status != TransferStatus.active) return;

      final currentBytes = _info.bytesTransferred;
      _info.speedBytesPerSecond = (currentBytes - _lastBytesTransferred).toDouble();
      _lastBytesTransferred = currentBytes;
      onUpdate(_info);
    });
  }

  void _updateStatus(TransferStatus status, {String? error}) {
    _info.status = status;
    if (error != null) _info.error = error;
    onUpdate(_info);
  }

  Future<void> cancel() async {
    if (_info.status == TransferStatus.completed || _info.status == TransferStatus.cancelled) return;

    for (var client in _clients) {
      client.sendMessage({
        'type': MessageTypes.transferCancel,
        'transfer_id': metadata.transferId,
      });
    }

    _updateStatus(TransferStatus.cancelled);
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _speedTimer?.cancel();
    // Copy list to avoid concurrent modification during disconnect
    final pipes = _clients.toList();
    for (var client in pipes) {
      await client.disconnect();
    }
    _clients.clear();
    await _io?.close();
  }
}
