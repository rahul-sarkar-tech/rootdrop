import 'dart:io';
import 'package:flutter/foundation.dart';

import 'chunk_models.dart';
import 'chunk_verifier.dart';
import '../transport/transport_constants.dart';

class ChunkSplitter {
  final File file;
  final int chunkSize;
  
  ChunkSplitter(this.file, {this.chunkSize = TransportConstants.defaultChunkSize});

  /// Generates metadata for all chunks without loading the file into memory
  Future<List<ChunkInfo>> generateChunkManifest({Function(double)? onProgress}) async {
    final List<ChunkInfo> chunks = [];
    final fileSize = await file.length();
    final totalChunks = (fileSize / chunkSize).ceil();
    debugPrint('Chunking: Dividing file (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB) into $totalChunks chunks...');
    
    // Read file sequentially to compute hashes
    final randomAccessFile = await file.open(mode: FileMode.read);
    
    try {
      int offset = 0;
      int index = 0;
      
      while (offset < fileSize) {
        final remaining = fileSize - offset;
        final currentChunkSize = remaining < chunkSize ? remaining : chunkSize;
        
        // Read chunk data to compute hash
        final chunkData = await randomAccessFile.read(currentChunkSize);
        final hash = ChunkVerifier.computeHash(chunkData);
        
        chunks.add(ChunkInfo(
          index: index,
          offset: offset,
          size: currentChunkSize,
          expectedHash: hash,
        ));
        
        if (index % 10 == 0 || index == totalChunks - 1) {
          final progress = (index + 1) / totalChunks;
          debugPrint('Chunking: Hashed chunk #$index/${totalChunks} (${(progress * 100).toStringAsFixed(1)}%)');
          onProgress?.call(progress);
        }

        offset += currentChunkSize;
        index++;
      }
      debugPrint('Chunking: Manifest complete. $totalChunks chunks ready.');
    } catch (e) {
      debugPrint('Error generating chunk manifest: $e');
      rethrow;
    } finally {
      await randomAccessFile.close();
    }
    
    return chunks;
  }
}
