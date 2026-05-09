import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as pp;

/// Cross-platform file path management for received files.
class FileManager {
  /// Gets the platform-specific directory for saving received files.
  ///
  /// If [customPath] is provided, it uses that. Otherwise:
  /// - Android: `/storage/emulated/0/Download/RootDrop` (fallback to app external dir)
  /// - macOS/Linux/Windows: `<AppDocuments>/RootDrop` (sandbox-safe)
  /// - iOS: App documents directory
  static Future<Directory> getReceiveDirectory({String? customPath}) async {
    Directory dir;
    debugPrint('FileManager: Getting receive directory. Custom path: $customPath');

    try {
      if (customPath != null && customPath.isNotEmpty) {
        dir = Directory(customPath);
        debugPrint('FileManager: Testing custom path: ${dir.path}');
        
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        
        // Use a unique test file name to avoid collisions
        final testFile = File('${dir.path}/.rootdrop_write_test_${DateTime.now().millisecondsSinceEpoch}');
        await testFile.writeAsBytes(Uint8List(0), flush: true);
        await testFile.delete();
        
        debugPrint('FileManager: Custom path verified.');
        return dir;
      }
    } catch (e) {
      debugPrint('FileManager: Sandbox/Permission block for "$customPath": $e');
    }

    // Default Fallback
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/RootDrop');
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        debugPrint('FileManager: Using Android public downloads: ${dir.path}');
      } catch (e) {
        final extDir = await pp.getExternalStorageDirectory();
        dir = Directory('${extDir?.path}/RootDrop');
        debugPrint('FileManager: Using Android app external dir: ${dir.path}');
      }
    } else {
      Directory? downloadsDir;
      try {
        downloadsDir = await pp.getDownloadsDirectory();
      } catch (_) {}
      
      if (downloadsDir != null) {
        dir = Directory('${downloadsDir.path}/RootDrop');
      } else {
        final docsDir = await pp.getApplicationDocumentsDirectory();
        dir = Directory('${docsDir.path}/RootDrop');
      }
    }

    // FINAL VALIDATION: If we still can't write, use the most private internal dir (Nuclear Option)
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      // Test write
      final testFile = File('${dir.path}/.rootdrop_write_test_${DateTime.now().millisecondsSinceEpoch}');
      await testFile.writeAsString('test');
      await testFile.delete();
      
      debugPrint('FileManager: FINAL CHOICE: ${dir.path}');
    } catch (e) {
      debugPrint('FileManager: Final directory choice failed (${dir.path}), using app support dir');
      final supportDir = await pp.getApplicationSupportDirectory();
      dir = Directory('${supportDir.path}/Received');
      if (!await dir.exists()) await dir.create(recursive: true);
    }

    return dir;
  }

  /// Generates a unique filename if the file already exists in [dir].
  static Future<String> getUniqueFileName(Directory dir, String fileName) async {
    var file = File('${dir.path}/$fileName');
    if (!await file.exists()) {
      return fileName;
    }

    final dotIndex = fileName.lastIndexOf('.');
    final String nameWithoutExt;
    final String ext;
    if (dotIndex > 0) {
      nameWithoutExt = fileName.substring(0, dotIndex);
      ext = fileName.substring(dotIndex);
    } else {
      nameWithoutExt = fileName;
      ext = '';
    }

    int counter = 1;
    while (await file.exists()) {
      final newName = '${nameWithoutExt}_$counter$ext';
      file = File('${dir.path}/$newName');
      counter++;
    }

    return file.path.split(Platform.pathSeparator).last;
  }
}
