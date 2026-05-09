import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/discovery_provider.dart';
import '../providers/transfer_provider.dart';
import '../theme/app_colors.dart';
import 'devices_screen.dart';
import 'transfers_screen.dart';
import '../core/scheduler/receiver_session.dart';

import '../providers/settings_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  Future<void> _initServices() async {
    final transferProvider = Provider.of<TransferProvider>(context, listen: false);
    // Already initialized in main.dart
    
    // Setup incoming transfer dialog
    transferProvider.onIncomingTransfer = _handleIncomingTransfer;

    if (mounted) {
      final discoveryProvider = Provider.of<DiscoveryProvider>(context, listen: false);
      discoveryProvider.startDiscovery(transferProvider.port);
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer<SettingsProvider>(
        builder: (context, settings, child) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 80,
                      width: 80,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'RootDrop',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'v1.0.0',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Save Received Files To:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        settings.customSavePath ?? 'Default App Folder',
                        style: TextStyle(
                          color: settings.customSavePath != null 
                              ? AppColors.textPrimary 
                              : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.folder_open, color: AppColors.primaryLight),
                      onPressed: () async {
                        await settings.pickSavePath();
                        if (context.mounted) {
                          Provider.of<TransferProvider>(context, listen: false)
                              .updateSavePath(settings.customSavePath);
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (settings.customSavePath != null)
                TextButton(
                  onPressed: () {
                    settings.clearSavePath();
                    Provider.of<TransferProvider>(context, listen: false)
                        .updateSavePath(null);
                  },
                  child: const Text('Reset to Default', style: TextStyle(color: AppColors.error)),
                ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('https://github.com/rahul-sarkar-tech/rootdrop/blob/main/LICENSE');
                    try {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      debugPrint('Could not launch GitHub URL: $e');
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.github, size: 20),
                  label: const Text('View on GitHub (AGPLv3)'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('https://www.linkedin.com/in/rahul-rootthrive');
                    try {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      debugPrint('Could not launch LinkedIn URL: $e');
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.linkedin, size: 20, color: Color(0xFF0077B5)),
                  label: const Text('Connect on LinkedIn'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('https://www.instagram.com/rahulxoperator');
                    try {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      debugPrint('Could not launch Instagram URL: $e');
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.instagram, size: 20, color: Color(0xFFE4405F)),
                  label: const Text('Follow on Instagram'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _handleIncomingTransfer(ReceiverSession session) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Incoming File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${session.senderName} wants to send you:'),
            const SizedBox(height: 8),
            Text(
              session.metadata.fileName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('${(session.metadata.fileSize / (1024 * 1024)).toStringAsFixed(2)} MB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<TransferProvider>(context, listen: false).rejectTransfer(session.metadata.transferId);
            },
            child: const Text('Decline', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<TransferProvider>(context, listen: false).acceptTransfer(session.metadata.transferId);
              setState(() {
                _currentIndex = 1; // Switch to transfers tab
              });
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/app-logo.png',
              height: 28,
              width: 28,
            ),
            const SizedBox(width: 10),
            const Text(
              'RootDrop',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          DevicesScreen(),
          TransfersScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            label: 'Nearby',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_vert),
            label: 'Transfers',
          ),
        ],
      ),
    );
  }
}
