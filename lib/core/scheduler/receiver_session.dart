import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../protocol/message_types.dart';
import '../protocol/transfer_metadata.dart';
import '../chunk_engine/chunk_models.dart';
import '../chunk_engine/chunk_merger.dart';
import '../chunk_engine/chunk_verifier.dart';
import '../transport/tcp_server.dart';
import '../storage/file_manager.dart';
import 'transfer_models.dart';

/// Manages the receiver side of a single file transfer.
///
/// The receiver drives the transfer by requesting chunks from the sender,
/// enabling resume, parallel downloads, and flow control.
class ReceiverSession {
  final TransferMetadata metadata;
  final File targetFile; // This is the requested file
  late File _actualFile; // This is where it's actually being saved
  final String senderIp;
  final String senderName;
  final List<Socket> _sockets = [];
  final TcpServer server;
  final Function(TransferInfo) onUpdate;
  
  // Track which socket is being used for load balancing
  int _nextSocketIndex = 0;

  ChunkMerger? _merger;
  final List<ChunkInfo> _chunks = [];
  Timer? _speedTimer;
  int _lastBytesTransferred = 0;

  // Concurrency control — request even more chunks to saturate high-speed links
  static const int maxConcurrentRequests = 24; 
  int _activeRequests = 0;

  late TransferInfo _info;

  ReceiverSession({
    required this.metadata,
    required this.targetFile,
    required this.senderIp,
    required this.senderName,
    required Socket initialSocket,
    required this.server,
    required this.onUpdate,
  }) {
    _sockets.add(initialSocket);
    _actualFile = targetFile;
    _info = TransferInfo(
      metadata: metadata,
      direction: TransferDirection.receiving,
      peerIp: senderIp,
      peerName: senderName,
    );

    _initChunks();
  }

  void addSocket(Socket socket) {
    if (!_sockets.contains(socket)) {
      _sockets.add(socket);
      debugPrint('ReceiverSession: Added parallel pipe. Total: ${_sockets.length}');
    }
  }

  TransferInfo get info => _info;

  void _initChunks() {
    int offset = 0;
    for (int i = 0; i < metadata.totalChunks; i++) {
      final remaining = metadata.fileSize - offset;
      final size = remaining < metadata.chunkSize ? remaining : metadata.chunkSize;

      _chunks.add(ChunkInfo(
        index: i,
        offset: offset,
        size: size,
        expectedHash: '', // Will be provided by sender with each chunk_data
      ));

      offset += size;
    }
  }

  Future<void> accept() async {
    _updateStatus(TransferStatus.connecting);

    try {
      _merger = ChunkMerger(_actualFile);
      try {
        await _merger!.initialize(metadata.fileSize);
      } catch (e) {
        debugPrint('Initial merger initialization failed: $e. Attempting safety fallback...');
        
        // Safety Fallback: Use app documents directory if the custom one failed
        final fallbackDir = await FileManager.getReceiveDirectory(customPath: null);
        final uniqueName = await FileManager.getUniqueFileName(fallbackDir, metadata.fileName);
        _actualFile = File('${fallbackDir.path}/$uniqueName');
        
        // Re-init with safe path
        _merger = ChunkMerger(_actualFile);
        await _merger!.initialize(metadata.fileSize);
        
        debugPrint('Successfully fell back to safe directory: ${_actualFile.path}');
      }

      debugPrint('PATH READY: Writing file to ${_actualFile.path}');

      for (var socket in _sockets) {
        server.sendMessage(socket, {
          'type': MessageTypes.transferAccept,
          'transfer_id': metadata.transferId,
        });
      }

      _updateStatus(TransferStatus.active);
      _startSpeedTimer();
      _requestNextChunks();
    } catch (e) {
      debugPrint('Critical error accepting transfer: $e');
      _updateStatus(TransferStatus.failed, error: 'File Access Denied');
      _cleanup();
    }
  }

  void reject() {
    for (var socket in _sockets) {
      server.sendMessage(socket, {
        'type': MessageTypes.transferReject,
        'transfer_id': metadata.transferId,
      });
    }
    _updateStatus(TransferStatus.cancelled);
    _cleanup();
  }

  void handleMessage(Map<String, dynamic> msgMetadata, Uint8List? payload) async {
    final type = msgMetadata['type'];

    if (type == MessageTypes.chunkData && payload != null) {
      await _handleChunkData(msgMetadata, payload);
    } else if (type == MessageTypes.transferCancel) {
      _updateStatus(TransferStatus.cancelled, error: 'Sender cancelled transfer');
      _cleanup();
    } else if (type == MessageTypes.socketJoin) {
      // Handled by scheduler, but good to have a placeholder
    }
  }

  Future<void> _handleChunkData(Map<String, dynamic> msgMetadata, Uint8List data) async {
    final index = msgMetadata['chunk_index'] as int;
    final expectedHash = msgMetadata['sha256'] as String;

    if (index < 0 || index >= _chunks.length) return;

    final chunk = _chunks[index];
    if (chunk.state == ChunkState.completed) return;

    // Verify chunk integrity in background to avoid blocking network
    final bool isVerified = await compute(_verifyChunk, {
      'data': data,
      'hash': expectedHash,
    });
    
    if (!isVerified) {
      debugPrint('Chunked: HASH MISMATCH for #${chunk.index}!');
      chunk.state = ChunkState.failed;
      chunk.retryCount++;

      final socket = _sockets[_nextSocketIndex % _sockets.length];
      _nextSocketIndex++;

      server.sendMessage(socket, {
        'type': MessageTypes.chunkNack,
        'transfer_id': metadata.transferId,
        'chunk_index': index,
      });

      _activeRequests--;
      _requestNextChunks();
      return;
    }

    // Write verified chunk to disk
    try {
      final startTime = DateTime.now();
      await _merger!.writeChunk(chunk.offset, data);
      final duration = DateTime.now().difference(startTime);
      
      debugPrint('Chunked: Received #${chunk.index} (${data.length} bytes) - Write took ${duration.inMilliseconds}ms. Total progress: ${((_info.completedChunks + 1) / _chunks.length * 100).toStringAsFixed(1)}%');
      
      chunk.state = ChunkState.completed;

      _info.completedChunks++;
      _info.bytesTransferred += data.length;

      final socket = _sockets[_nextSocketIndex % _sockets.length];
      _nextSocketIndex++;

      server.sendMessage(socket, {
        'type': MessageTypes.chunkAck,
        'transfer_id': metadata.transferId,
        'chunk_index': index,
      });

      onUpdate(_info);

      _activeRequests--;

      if (_info.completedChunks >= _chunks.length) {
        debugPrint('TRANSFER SUCCESSFUL! File saved to: ${_actualFile.absolute.path}');
        _updateStatus(TransferStatus.completed);
        for (var s in _sockets) {
          server.sendMessage(s, {
            'type': MessageTypes.transferComplete,
            'transfer_id': metadata.transferId,
          });
        }
        await _cleanup();
      } else {
        _requestNextChunks();
      }
    } catch (e) {
      debugPrint('Error writing chunk: $e');
      _updateStatus(TransferStatus.failed, error: 'File write error');
      await _cleanup();
    }
  }

  void _requestNextChunks() {
    if (_info.status != TransferStatus.active) return;

    while (_activeRequests < maxConcurrentRequests) {
      final index = _chunks.indexWhere((c) =>
        c.state == ChunkState.pending ||
        (c.state == ChunkState.failed && c.retryCount < 3)
      );

      if (index == -1) break;

      _chunks[index].state = ChunkState.downloading;
      _activeRequests++;

      final socket = _sockets[_nextSocketIndex % _sockets.length];
      _nextSocketIndex++;

      server.sendMessage(socket, {
        'type': MessageTypes.chunkRequest,
        'transfer_id': metadata.transferId,
        'chunk_index': index,
      });
    }
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

    for (var socket in _sockets) {
      server.sendMessage(socket, {
        'type': MessageTypes.transferCancel,
        'transfer_id': metadata.transferId,
      });
    }

    _updateStatus(TransferStatus.cancelled);
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _speedTimer?.cancel();
    await _merger?.close();
  }
}

/// Helper for background hashing
bool _verifyChunk(Map<String, dynamic> params) {
  final Uint8List data = params['data'];
  final String expectedHash = params['hash'];
  return ChunkVerifier.verify(data, expectedHash);
}
