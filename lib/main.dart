import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'theme/app_theme.dart';
import 'providers/discovery_provider.dart';
import 'providers/transfer_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();

  final settings = SettingsProvider();
  await settings.init();

  final transferProvider = TransferProvider();
  await transferProvider.init();
  transferProvider.updateSavePath(settings.customSavePath);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DiscoveryProvider()),
        ChangeNotifierProvider.value(value: transferProvider),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: const RootDropApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  // Only request runtime permissions on Android — desktop/iOS don't need them
  // (macOS uses entitlements, Linux has no sandbox, file_picker handles its own)
  if (Platform.isAndroid) {
    try {
      await Permission.storage.request();
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
  }
}

class RootDropApp extends StatelessWidget {
  const RootDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RootDrop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
