import 'package:file_picker/file_picker.dart';
import 'dart:io';

class FileService {
  /// Picks a single PDF file
  Future<String?> pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        return result.files.single.path;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick PDF file: $e');
    }
  }

  /// Picks multiple PDF files
  Future<List<String>> pickMultiplePdfFiles() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        return result.paths.whereType<String>().toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to pick PDF files: $e');
    }
  }

  /// Picks a text file
  Future<String?> pickTextFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null) {
        return result.files.single.path;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick text file: $e');
    }
  }

  /// Reads text from a file
  Future<String> readTextFile(String filePath) async {
    try {
      final file = File(filePath);
      return await file.readAsString();
    } catch (e) {
      throw Exception('Failed to read text file: $e');
    }
  }

  /// Reads a PDF file (extracts metadata)
  Future<String> readPdfInfo(String pdfPath) async {
    try {
      // Simple file info extraction
      final file = File(pdfPath);
      final stat = await file.stat();
      return 'PDF Info: ${file.path}\nSize: ${_formatBytes(stat.size)}\nModified: ${stat.modified}';
    } catch (e) {
      throw Exception('Failed to read PDF info: $e');
    }
  }

  /// Checks if file exists
  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Gets file name from path
  String getFileName(String filePath) {
    return filePath.split('/').last;
  }

  /// Formats bytes to readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Deletes a file
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
