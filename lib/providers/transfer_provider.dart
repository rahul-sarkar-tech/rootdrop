import 'dart:io';
import 'package:flutter/material.dart';
import '../core/scheduler/transfer_scheduler.dart';
import '../core/scheduler/transfer_models.dart';
import '../core/scheduler/receiver_session.dart';

class TransferProvider extends ChangeNotifier {
  final TransferScheduler _scheduler = TransferScheduler();
  List<TransferInfo> _transfers = [];

  List<TransferInfo> get transfers => _transfers;
  int get port => _scheduler.port;

  Function(ReceiverSession)? onIncomingTransfer;

  Future<void> init() async {
    await _scheduler.init();
    
    _scheduler.transfersStream.listen((list) {
      _transfers = list;
      notifyListeners();
    });

    _scheduler.incomingTransfersStream.listen((session) {
      if (onIncomingTransfer != null) {
        onIncomingTransfer!(session);
      } else {
        // Auto-accept if no handler (for testing)
        _scheduler.acceptTransfer(session.metadata.transferId);
      }
    });
  }

  void updateSavePath(String? path) {
    _scheduler.setSavePath(path);
  }

  Future<void> sendFile(File file, String peerIp, int peerPort, String peerName) async {
    await _scheduler.sendFile(
      file: file,
      peerIp: peerIp,
      peerPort: peerPort,
      peerName: peerName,
    );
  }

  void acceptTransfer(String id) => _scheduler.acceptTransfer(id);
  void rejectTransfer(String id) => _scheduler.rejectTransfer(id);
  void cancelTransfer(String id) => _scheduler.cancelTransfer(id);

  @override
  void dispose() {
    _scheduler.shutdown();
    super.dispose();
  }
}
