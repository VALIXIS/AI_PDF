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

  /// Sanitizes a file name by removing illegal filename characters
  /// across Windows, macOS, Linux, Android, and iOS.
  String sanitizeFileName(String fileName) {
    if (fileName.isEmpty) return 'untitled';
    // Replace Windows & POSIX illegal characters: < > : " / \ | ? * and control chars
    String sanitized = fileName.replaceAll(RegExp(r'[<>"|?*:\/\\]'), '_');
    // Remove null characters or control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    // Trim spaces and trailing dots (problematic on Windows)
    sanitized = sanitized.trim().replaceAll(RegExp(r'\.+$'), '');
    return sanitized.isEmpty ? 'untitled' : sanitized;
  }

  /// Generates a non-colliding file path if the target file already exists.
  /// Example: 'doc.pdf' -> 'doc (1).pdf' -> 'doc (2).pdf'
  Future<String> getUniqueFilePath(String targetPath) async {
    if (targetPath.isEmpty) return targetPath;
    final normalized = normalizePath(targetPath);
    if (!await File(normalized).exists()) {
      return normalized;
    }

    final dir = getDirectoryName(normalized);
    final ext = getExtension(normalized);
    final baseWithoutExt = path.basenameWithoutExtension(normalized);

    int counter = 1;
    while (true) {
      final newFileName = '$baseWithoutExt ($counter)$ext';
      final newPath = dir.isEmpty ? newFileName : path.join(dir, newFileName);
      if (!await File(newPath).exists()) {
        return newPath;
      }
      counter++;
    }
  }

  /// Writes bytes atomically to [targetPath] using a temporary file.
  /// If [overwrite] is false, automatically resolves duplicate filenames.
  /// If an error occurs during write/rename, cleans up the temporary file.
  Future<String> safeWriteBytes(
    String targetPath,
    List<int> bytes, {
    bool overwrite = false,
  }) async {
    if (targetPath.isEmpty) {
      throw const FileSystemException('Target file path cannot be empty');
    }

    final finalPath = overwrite ? normalizePath(targetPath) : await getUniqueFilePath(targetPath);
    final parentDir = Directory(getDirectoryName(finalPath));
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    final tempPath = '$finalPath.tmp_${DateTime.now().microsecondsSinceEpoch}';
    final tempFile = File(tempPath);

    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      try {
        await tempFile.rename(finalPath);
      } catch (_) {
        // Fallback for cross-device or permission renames
        await tempFile.copy(finalPath);
        await tempFile.delete().catchError((_) => tempFile);
      }
      return finalPath;
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      throw FileSystemException('Failed to write file safely: $e', finalPath);
    }
  }

  /// Copies [sourcePath] safely to [targetPath] using a temporary file.
  /// If [overwrite] is false, automatically resolves duplicate filenames.
  Future<String> safeCopyFile(
    String sourcePath,
    String targetPath, {
    bool overwrite = false,
  }) async {
    if (!await isFileAccessible(sourcePath)) {
      throw FileSystemException('Source file does not exist or is inaccessible', sourcePath);
    }
    final sourceFile = File(sourcePath);
    final bytes = await sourceFile.readAsBytes();
    return await safeWriteBytes(targetPath, bytes, overwrite: overwrite);
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

  /// Automatically cleans up temporary working files safely across platforms.
  Future<int> cleanupTempResources([List<String>? extraDirectories]) async {
    int deletedCount = 0;
    final now = DateTime.now();
    final dirsToCheck = <Directory>[
      Directory.systemTemp,
      if (extraDirectories != null)
        ...extraDirectories.map((d) => Directory(d)),
    ];

    for (final dir in dirsToCheck) {
      try {
        if (!await dir.exists()) continue;
        final entities = await dir.list().toList();

        for (final entity in entities) {
          if (entity is File) {
            final lowerPath = entity.path.toLowerCase();
            final isTempPdf = lowerPath.endsWith('.pdf') && (path.basename(lowerPath).startsWith('tmp_') || path.basename(lowerPath).startsWith('pdf_') || lowerPath.contains('temp'));
            final isTempFile = lowerPath.contains('.tmp_');

            if (isTempPdf || isTempFile) {
              try {
                final stat = await entity.stat();
                final age = now.difference(stat.modified);
                // Delete temp PDF or working files older than 1 hour for .tmp_ or 24h for old PDFs
                if ((isTempFile && age.inMinutes >= 60) || (isTempPdf && age.inHours >= 24)) {
                  await entity.delete();
                  deletedCount++;
                }
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    }
    return deletedCount;
  }
}


