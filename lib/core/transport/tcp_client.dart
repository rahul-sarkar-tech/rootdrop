import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../protocol/message_codec.dart';
import 'transport_constants.dart';

typedef MessageHandler = FutureOr<void> Function(Map<String, dynamic> metadata, Uint8List? payload, TcpClient client);

class TcpClient {
  Socket? _socket;
  final String host;
  final int port;
  
  final MessageHandler onMessage;
  final void Function(dynamic error)? onError;
  final void Function()? onDisconnect;

  TcpClient({
    required this.host,
    required this.port,
    required this.onMessage,
    this.onError,
    this.onDisconnect,
  });

  bool get isConnected => _socket != null;

  Future<void> connect() async {
    int attempts = 0;
    
    while (attempts < TransportConstants.maxRetries) {
      try {
        _socket = await Socket.connect(
          host, 
          port, 
          timeout: TransportConstants.connectionTimeout,
        );
        
        debugPrint('Connected to TCP server $host:$port');
        
        // Optimize socket for high performance
        _socket!.setOption(SocketOption.tcpNoDelay, true);
        
        _setupListeners();
        return;
      } catch (e) {
        attempts++;
        debugPrint('Connection attempt $attempts failed: $e');
        
        if (attempts >= TransportConstants.maxRetries) {
          rethrow;
        }
        
        await Future.delayed(TransportConstants.retryDelay);
      }
    }
  }

  void _setupListeners() {
    if (_socket == null) return;
    
    final StreamController<Uint8List> streamController = StreamController();
    
    // Sequentially process messages from the socket
    unawaited(() async {
      BytesBuilder buffer = BytesBuilder();
      try {
        await for (final data in streamController.stream) {
          buffer.add(data);
          
          while (true) {
            final bytes = buffer.toBytes();
            final decoded = MessageCodec.decode(bytes);
            
            if (decoded == null) break;
            
            try {
              // Await handler to ensure sequential processing and flow control
              await onMessage(decoded.metadata, decoded.payload, this);
            } catch (e) {
              debugPrint('Error in TcpClient message handler: $e');
            }
            
            final remaining = decoded.remaining;
            buffer = BytesBuilder();
            if (remaining.isNotEmpty) {
              buffer.add(remaining);
            } else {
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('Error in TcpClient processing loop: $e');
      }
    }());

    _socket!.listen(
      (Uint8List data) {
        if (!streamController.isClosed) {
          streamController.add(data);
        }
      },
      onError: (error) {
        debugPrint('Socket error: $error');
        onError?.call(error);
        streamController.close();
        disconnect();
      },
      onDone: () {
        debugPrint('Disconnected from server');
        onDisconnect?.call();
        streamController.close();
        disconnect();
      },
      cancelOnError: true,
    );
  }

  void sendMessage(Map<String, dynamic> metadata, [Uint8List? payload]) {
    if (_socket == null) {
      debugPrint('Cannot send message, socket is null');
      return;
    }
    
    try {
      final data = MessageCodec.encode(metadata, payload);
      _socket!.add(data);
    } catch (e) {
      debugPrint('Error sending message: $e');
      onError?.call(e);
    }
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      try {
        await _socket!.close();
      } catch (_) {}
      _socket = null;
    }
  }
}
