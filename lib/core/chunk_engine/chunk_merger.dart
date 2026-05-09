import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Reassembles a file from individually received chunks using RandomAccessFile.
/// Supports out-of-order chunk writes via offset-based positioning.
class ChunkMerger {
  final File targetFile;
  RandomAccessFile? _randomAccessFile;
  
  // Mutex to prevent concurrent writes to the same RandomAccessFile handle
  Future<void> _writeLock = Future.value();

  ChunkMerger(this.targetFile);

  /// Pre-allocates the target file with [totalSize] bytes.
  Future<void> initialize(int totalSize) async {
    try {
      if (!await targetFile.parent.exists()) {
        await targetFile.parent.create(recursive: true);
      }
      
      _randomAccessFile = await targetFile.open(mode: FileMode.write);
      await _randomAccessFile!.truncate(totalSize);
    } catch (e) {
      debugPrint('Error initializing chunk merger: $e');
      rethrow;
    }
  }

  /// Writes [data] at the specified byte [offset].
  /// Synchronized to prevent pointer corruption.
  Future<void> writeChunk(int offset, Uint8List data) async {
    final prevLock = _writeLock;
    final completer = Completer<void>();
    _writeLock = completer.future.then((_) {}, onError: (_) {});
    
    await prevLock;

    try {
      if (_randomAccessFile == null) {
        throw StateError('ChunkMerger not initialized');
      }
      
      await _randomAccessFile!.setPosition(offset);
      await _randomAccessFile!.writeFrom(data);
      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    }
  }

  /// Closes the underlying file handle.
  Future<void> close() async {
    await _writeLock;
    if (_randomAccessFile != null) {
      try {
        await _randomAccessFile!.close();
      } catch (e) {
        debugPrint('Error closing random access file: $e');
      }
      _randomAccessFile = null;
    }
  }
}
