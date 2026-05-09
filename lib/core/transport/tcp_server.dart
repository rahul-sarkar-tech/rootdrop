import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../protocol/message_codec.dart';

typedef MessageHandler = FutureOr<void> Function(Map<String, dynamic> metadata, Uint8List? payload, Socket client);
typedef ErrorHandler = void Function(dynamic error, Socket client);
typedef DisconnectHandler = void Function(Socket client);

class TcpServer {
  ServerSocket? _serverSocket;
  final List<Socket> _clients = [];
  
  final MessageHandler onMessage;
  final ErrorHandler? onError;
  final DisconnectHandler? onDisconnect;

  TcpServer({
    required this.onMessage,
    this.onError,
    this.onDisconnect,
  });

  int get port => _serverSocket?.port ?? 0;

  Future<int> start({int preferredPort = 0}) async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, preferredPort);
      debugPrint('TCP Server listening on port ${_serverSocket!.port}');
      
      _serverSocket!.listen(
        _handleClientConnection,
        onError: (error) => debugPrint('TCP Server error: $error'),
      );
      
      return _serverSocket!.port;
    } catch (e) {
      debugPrint('Failed to start TCP Server: $e');
      rethrow;
    }
  }

  void _handleClientConnection(Socket client) {
    debugPrint('Client connected: ${client.remoteAddress.address}:${client.remotePort}');
    
    client.setOption(SocketOption.tcpNoDelay, true);
    _clients.add(client);
    
    final StreamController<Uint8List> streamController = StreamController();
    
    // Use a worker to process messages sequentially
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
              // Await the message handler for flow control and sequential processing
              await onMessage(decoded.metadata, decoded.payload, client);
            } catch (e) {
              debugPrint('Error in TcpServer message handler: $e');
            }
            
            // Re-build buffer from remaining bytes
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
        debugPrint('Error in TcpServer processing loop: $e');
      }
    }());

    client.listen(
      (Uint8List data) {
        if (!streamController.isClosed) {
          streamController.add(data);
        }
      },
      onError: (error) {
        debugPrint('Client socket error: $error');
        onError?.call(error, client);
        streamController.close();
        _removeClient(client);
      },
      onDone: () {
        debugPrint('Client disconnected');
        onDisconnect?.call(client);
        streamController.close();
        _removeClient(client);
      },
      cancelOnError: true,
    );
  }

  void _removeClient(Socket client) {
    _clients.remove(client);
    try {
      client.close();
    } catch (_) {}
  }

  void sendMessage(Socket client, Map<String, dynamic> metadata, [Uint8List? payload]) {
    try {
      final data = MessageCodec.encode(metadata, payload);
      client.add(data);
    } catch (e) {
      debugPrint('Error sending message: $e');
      onError?.call(e, client);
    }
  }

  Future<void> stop() async {
    for (final client in _clients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();
    
    await _serverSocket?.close();
    _serverSocket = null;
    debugPrint('TCP Server stopped');
  }
}
