import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/transfer_provider.dart';
import '../widgets/transfer_tile.dart';
import '../widgets/empty_state.dart';

class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransferProvider>(
      builder: (context, provider, child) {
        if (provider.transfers.isEmpty) {
          return const EmptyState(
            icon: Icons.swap_vert,
            title: 'No Active Transfers',
            message: 'Your recent file transfers will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.transfers.length,
          itemBuilder: (context, index) {
            final transfer = provider.transfers[index];
            return TransferTile(
              transfer: transfer,
              onCancel: () => provider.cancelTransfer(transfer.id),
            );
          },
        );
      },
    );
  }
}
