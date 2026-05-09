import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Provides thread-safe (async-safe) random access to a file.
class RandomAccessIo {
  final File file;
  RandomAccessFile? _raf;
  bool _isOpen = false;
  
  // Mutex for sequential access
  Future<void> _lock = Future.value();

  RandomAccessIo(this.file);

  Future<void> openRead() async {
    if (!_isOpen) {
      _raf = await file.open(mode: FileMode.read);
      _isOpen = true;
    }
  }

  Future<void> openWrite() async {
    if (!_isOpen) {
      _raf = await file.open(mode: FileMode.write);
      _isOpen = true;
    }
  }

  Future<Uint8List> readChunk(int offset, int size) async {
    final prevLock = _lock;
    final completer = Completer<Uint8List>();
    _lock = completer.future.then((_) {}, onError: (_) {});
    
    await prevLock;

    try {
      if (!_isOpen || _raf == null) {
        await openRead();
      }
      await _raf!.setPosition(offset);
      final data = await _raf!.read(size);
      completer.complete(data);
      return data;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    }
  }

  Future<void> writeChunk(int offset, Uint8List data) async {
    final prevLock = _lock;
    final completer = Completer<void>();
    _lock = completer.future.then((_) {}, onError: (_) {});
    
    await prevLock;

    try {
      if (!_isOpen || _raf == null) {
        await openWrite();
      }
      await _raf!.setPosition(offset);
      await _raf!.writeFrom(data);
      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    }
  }

  Future<void> close() async {
    await _lock;
    if (_isOpen && _raf != null) {
      await _raf!.close();
      _isOpen = false;
      _raf = null;
    }
  }
}
