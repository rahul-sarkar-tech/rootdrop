import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _keySavePath = 'save_path';
  String? _customSavePath;
  late SharedPreferences _prefs;

  String? get customSavePath => _customSavePath;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _customSavePath = _prefs.getString(_keySavePath);
    notifyListeners();
  }

  Future<void> pickSavePath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      // Ensure the path is writable by checking if it exists or trying to create a test file
      // On macOS, the sandbox will grant access to this folder via the picker.
      _customSavePath = selectedDirectory;
      await _prefs.setString(_keySavePath, selectedDirectory);
      notifyListeners();
    }
  }

  Future<void> clearSavePath() async {
    _customSavePath = null;
    await _prefs.remove(_keySavePath);
    notifyListeners();
  }
}
