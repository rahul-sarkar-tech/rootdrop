import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../protocol/message_types.dart';
import '../protocol/transfer_metadata.dart';
import '../transport/tcp_server.dart';
import '../transport/transport_constants.dart';
import '../discovery/discovery_constants.dart';
import '../storage/file_manager.dart';
import 'transfer_models.dart';
import 'sender_session.dart';
import 'receiver_session.dart';

/// Orchestrates all active file transfers (both sending and receiving).
///
/// Manages a TCP server for incoming connections and coordinates
/// SenderSession / ReceiverSession instances per transfer.
class TransferScheduler {
  final Map<String, SenderSession> _activeSenders = {};
  final Map<String, ReceiverSession> _activeReceivers = {};

  TcpServer? _server;
  int? _serverPort;
  String? _savePath;

  void setSavePath(String? path) {
    _savePath = path;
  }

  final StreamController<List<TransferInfo>> _transfersController = StreamController.broadcast();
  final StreamController<ReceiverSession> _incomingTransfersController = StreamController.broadcast();

  Stream<List<TransferInfo>> get transfersStream => _transfersController.stream;
  Stream<ReceiverSession> get incomingTransfersStream => _incomingTransfersController.stream;

  List<TransferInfo> get currentTransfers {
    return [
      ..._activeSenders.values.map((s) => s.info),
      ..._activeReceivers.values.map((r) => r.info),
    ];
  }

  int get port => _serverPort ?? 0;

  Future<void> init() async {
    _server = TcpServer(
      onMessage: _handleServerMessage,
    );
    _serverPort = await _server!.start(preferredPort: DiscoveryConstants.transferPort);
  }

  void _notifyTransfers() {
    _transfersController.add(currentTransfers);
  }

  // --- Sending ---

  Future<String> sendFile({
    required File file,
    required String peerIp,
    required int peerPort,
    required String peerName,
  }) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSize = await file.length();
    final transferId = const Uuid().v4();

    final metadata = TransferMetadata(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      chunkSize: TransportConstants.defaultChunkSize,
      totalChunks: (fileSize / TransportConstants.defaultChunkSize).ceil(),
    );

    final session = SenderSession(
      metadata: metadata,
      file: file,
      targetIp: peerIp,
      targetPort: peerPort,
      peerName: peerName,
      onUpdate: (_) => _notifyTransfers(),
    );

    _activeSenders[transferId] = session;
    _notifyTransfers();

    // Start transfer asynchronously
    session.start();

    return transferId;
  }

  // --- Receiving ---

  void _handleServerMessage(Map<String, dynamic> metadata, Uint8List? payload, Socket client) async {
    final type = metadata['type'];
    final transferId = metadata['transfer_id'];

    if (type == MessageTypes.transferOffer) {
      final transferMeta = TransferMetadata.fromMap(metadata);

      final downloadsDir = await FileManager.getReceiveDirectory(customPath: _savePath);
      final uniqueName = await FileManager.getUniqueFileName(downloadsDir, transferMeta.fileName);
      final targetFile = File('${downloadsDir.path}/$uniqueName');

      try {
        final session = ReceiverSession(
          metadata: transferMeta,
          targetFile: targetFile,
          senderIp: client.remoteAddress.address,
          senderName: 'Unknown Device',
          initialSocket: client,
          server: _server!,
          onUpdate: (_) => _notifyTransfers(),
        );

        _activeReceivers[transferId] = session;
        _notifyTransfers();
        _incomingTransfersController.add(session);
      } catch (e) {
        debugPrint('Critical error accepting transfer: $e');
      }
    } else if (type == MessageTypes.socketJoin && transferId != null) {
      final session = _activeReceivers[transferId];
      if (session != null) {
        session.addSocket(client);
      }
    } else if (transferId != null) {
      // Route message to existing receiver session
      final session = _activeReceivers[transferId];
      if (session != null) {
        session.handleMessage(metadata, payload);
      }
    }
  }

  Future<void> acceptTransfer(String transferId) async {
    final session = _activeReceivers[transferId];
    if (session != null) {
      await session.accept();
    }
  }

  void rejectTransfer(String transferId) {
    final session = _activeReceivers[transferId];
    if (session != null) {
      session.reject();
    }
  }

  Future<void> cancelTransfer(String transferId) async {
    if (_activeSenders.containsKey(transferId)) {
      await _activeSenders[transferId]!.cancel();
    } else if (_activeReceivers.containsKey(transferId)) {
      await _activeReceivers[transferId]!.cancel();
    }
  }

  void shutdown() {
    _server?.stop();
    for (var session in _activeSenders.values) {
      session.cancel();
    }
    for (var session in _activeReceivers.values) {
      session.cancel();
    }
  }
}
