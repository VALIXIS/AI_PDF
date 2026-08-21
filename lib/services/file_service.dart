import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
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

  /// Reads text from a file safely
  Future<String> readTextFile(String filePath) async {
    try {
      if (filePath.isEmpty) {
        throw FileSystemException('File path is empty', filePath);
      }
      final file = File(filePath);
      if (!await isFileAccessible(filePath)) {
        throw FileSystemException('File does not exist or is inaccessible', filePath);
      }
      return await file.readAsString();
    } catch (e) {
      throw Exception('Failed to read text file: $e');
    }
  }

  /// Reads a PDF file (extracts metadata) safely
  Future<String> readPdfInfo(String pdfPath) async {
    try {
      if (pdfPath.isEmpty || !await isFileAccessible(pdfPath)) {
        return 'PDF Info: ${getFileName(pdfPath)}\nStatus: File missing or deleted';
      }
      final file = File(pdfPath);
      if (!await file.exists()) {
        return 'PDF Info: ${getFileName(pdfPath)}\nStatus: File missing or deleted';
      }
      final stat = await file.stat();
      return 'PDF Info: ${file.path}\nSize: ${_formatBytes(stat.size)}\nModified: ${stat.modified}';
    } catch (e) {
      return 'PDF Info: ${getFileName(pdfPath)}\nStatus: File missing or deleted';
    }
  }

  /// Checks if file exists
  Future<bool> fileExists(String filePath) async {
    if (filePath.isEmpty) return false;
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Checks if file exists and is accessible
  Future<bool> isFileAccessible(String filePath) async {
    if (filePath.isEmpty) return false;
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      await file.stat();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets file name from path safely across Windows and Unix platforms
  String getFileName(String filePath) {
    if (filePath.isEmpty) return '';
    return path.basename(filePath);
  }

  /// Gets directory name from path safely across platforms
  String getDirectoryName(String filePath) {
    if (filePath.isEmpty) return '';
    return path.dirname(filePath);
  }

  /// Gets file extension from path
  String getExtension(String filePath) {
    if (filePath.isEmpty) return '';
    return path.extension(filePath);
  }

  /// Platform-safe path joining
  String joinPaths(String part1, String part2, [String? part3, String? part4]) {
    final parts = [part1, part2, if (part3 != null) part3, if (part4 != null) part4];
    return path.joinAll(parts);
  }

  /// Normalizes path for platform safety across platforms
  String normalizePath(String filePath) {
    if (filePath.isEmpty) return '';
    return path.normalize(filePath);
  }

  /// Formats bytes to readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Deletes a file safely without throwing uncaught exceptions
  Future<bool> deleteFile(String filePath) async {
    if (filePath.isEmpty) return false;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Automatically sorts and cleans up temporary working files
  Future<int> cleanupTempResources() async {
    int deletedCount = 0;
    try {
      final tempDir = Directory.systemTemp;
      if (!await tempDir.exists()) return 0;

      final now = DateTime.now();
      final entities = await tempDir.list().toList();

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.pdf')) {
          try {
            final stat = await entity.stat();
            final age = now.difference(stat.modified);
            // Delete temp PDF files older than 24h
            if (age.inHours >= 24) {
              await entity.delete();
              deletedCount++;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return deletedCount;
  }
}

