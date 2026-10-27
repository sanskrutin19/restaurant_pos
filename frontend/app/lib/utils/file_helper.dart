import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_file_plus/open_file_plus.dart';
import 'package:share_plus/share_plus.dart';

class FileHelper {
  static Future<String?> saveDownloadedFile(List<int> bytes, String filename) async {
    try {
      Directory? downloadsDir;
      
      if (Platform.isWindows) {
        final home = Platform.environment['USERPROFILE'];
        if (home != null) {
          downloadsDir = Directory(p.join(home, 'Downloads'));
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      // Fallback to Application Documents if Downloads is inaccessible
      if (downloadsDir == null) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      String filePath = p.join(downloadsDir.path, filename);
      File file = File(filePath);

      // Handle "File in Use" by adding a suffix if it exists and cannot be written
      int counter = 1;
      while (await file.exists()) {
        try {
          // Try to open it for writing to see if it's locked
          final sink = file.openWrite(mode: FileMode.write);
          await sink.close();
          break; // It's not locked, we can proceed
        } catch (e) {
          // File is locked, try a new name
          final basename = p.basenameWithoutExtension(filename);
          final extension = p.extension(filename);
          filePath = p.join(downloadsDir.path, "$basename ($counter)$extension");
          file = File(filePath);
          counter++;
        }
      }

      await file.writeAsBytes(bytes);
      debugPrint("File saved successfully at: $filePath");
      return filePath;
    } catch (e) {
      debugPrint("Error saving file: $e");
      return null;
    }
  }

  static Future<void> openFile(String filePath) async {
    try {
      await OpenFile.open(filePath);
    } catch (e) {
      debugPrint("Error opening file: $e");
    }
  }

  static Future<void> shareFile(String filePath, String subject) async {
    try {
      await Share.shareXFiles([XFile(filePath)], subject: subject);
    } catch (e) {
      debugPrint("Error sharing file: $e");
    }
  }
}
