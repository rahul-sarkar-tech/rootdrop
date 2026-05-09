import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/discovery_provider.dart';
import '../providers/transfer_provider.dart';
import '../widgets/device_card.dart';
import '../widgets/empty_state.dart';

import '../theme/app_colors.dart';
import '../core/discovery/discovery_constants.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _sendFile(BuildContext context, String ip, int port, String name) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      
      if (context.mounted) {
        Provider.of<TransferProvider>(context, listen: false).sendFile(
          file, ip, port, name
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer initiated')),
        );
      }
    }
  }

  void _showManualConnect(BuildContext context) {
    final TextEditingController ipController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Connect Manually'),
        content: TextField(
          controller: ipController,
          decoration: const InputDecoration(
            labelText: 'Device IP Address',
            hintText: 'e.g. 192.168.1.10',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(context);
                _sendFile(context, ip, DiscoveryConstants.transferPort, 'Manual Device');
              }
            },
            child: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DiscoveryProvider>(
      builder: (context, provider, child) {
        return Stack(
          children: [
            if (provider.devices.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: Tween(begin: 0.95, end: 1.05).animate(
                        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                      ),
                      child: Icon(
                        Icons.wifi_tethering,
                        size: 80,
                        color: AppColors.primaryLight.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Searching for devices...',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Ensure both devices are on the same WiFi network.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )
            else
              RefreshIndicator(
                onRefresh: () async {
                  final port = Provider.of<TransferProvider>(context, listen: false).port;
                  provider.stopDiscovery();
                  await Future.delayed(const Duration(milliseconds: 500));
                  provider.startDiscovery(port);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.devices.length,
                  itemBuilder: (context, index) {
                    final device = provider.devices[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 400 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: DeviceCard(
                            device: device,
                            onTap: () => _sendFile(context, device.ip, device.transferPort, device.deviceName),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _showManualConnect(context),
                icon: const Icon(Icons.add),
                label: const Text('Manual IP'),
              ),
            ),
          ],
        );
      },
    );
  }
}
