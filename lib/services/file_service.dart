import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

enum DetectedFileType {
  pdf,
  image,
  text,
  unknown,
}

class FileService {
  /// Safely reads at most [maxBytes] from [filePath] without loading the entire file into memory.
  Future<List<int>> readFileHeader(String filePath,
      {int maxBytes = 1024}) async {
    if (filePath.isEmpty) return [];
    try {
      final file = File(filePath);
      if (!await file.exists()) return [];
      final length = await file.length();
      if (length == 0) return [];

      final bytesToRead = length < maxBytes ? length : maxBytes;
      final stream = file.openRead(0, bytesToRead);
      final builder = <int>[];
      await for (final chunk in stream) {
        builder.addAll(chunk);
        if (builder.length >= bytesToRead) break;
      }
      return builder.length > bytesToRead
          ? builder.sublist(0, bytesToRead)
          : builder;
    } catch (_) {
      return [];
    }
  }

  /// Detects the file type based primarily on header magic byte signatures,
  /// falling back to file extension only if header analysis is inconclusive.
  Future<DetectedFileType> detectFileType(String filePath) async {
    if (filePath.isEmpty) return DetectedFileType.unknown;

    try {
      final file = File(filePath);
      if (!await file.exists()) return DetectedFileType.unknown;
      final length = await file.length();
      if (length == 0) return DetectedFileType.unknown;

      final header = await readFileHeader(filePath, maxBytes: 1024);
      if (header.isEmpty) return DetectedFileType.unknown;

      // 1. PDF Check: '%PDF-' (0x25, 0x50, 0x44, 0x46, 0x2D) anywhere in initial 1024 bytes
      for (int i = 0; i <= header.length - 5; i++) {
        if (header[i] == 0x25 &&
            header[i + 1] == 0x50 &&
            header[i + 2] == 0x44 &&
            header[i + 3] == 0x46 &&
            header[i + 4] == 0x2D) {
          return DetectedFileType.pdf;
        }
      }

      // 2. JPEG Check: 0xFF, 0xD8, 0xFF
      if (header.length >= 3 &&
          header[0] == 0xFF &&
          header[1] == 0xD8 &&
          header[2] == 0xFF) {
        return DetectedFileType.image;
      }

      // 3. PNG Check: 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
      if (header.length >= 8 &&
          header[0] == 0x89 &&
          header[1] == 0x50 &&
          header[2] == 0x4E &&
          header[3] == 0x47 &&
          header[4] == 0x0D &&
          header[5] == 0x0A &&
          header[6] == 0x1A &&
          header[7] == 0x0A) {
        return DetectedFileType.image;
      }

      // 4. WEBP Check: 'RIFF' at 0..3 and 'WEBP' at 8..11
      if (header.length >= 12 &&
          header[0] == 0x52 &&
          header[1] == 0x49 &&
          header[2] == 0x46 &&
          header[3] == 0x46 &&
          header[8] == 0x57 &&
          header[9] == 0x45 &&
          header[10] == 0x42 &&
          header[11] == 0x50) {
        return DetectedFileType.image;
      }

      // 5. GIF Check: 'GIF87a' or 'GIF89a'
      if (header.length >= 6 &&
          header[0] == 0x47 &&
          header[1] == 0x49 &&
          header[2] == 0x46 &&
          header[3] == 0x38 &&
          (header[4] == 0x37 || header[4] == 0x39) &&
          header[5] == 0x61) {
        return DetectedFileType.image;
      }

      // 6. BMP Check: 'BM' (0x42, 0x4D)
      if (header.length >= 2 && header[0] == 0x42 && header[1] == 0x4D) {
        return DetectedFileType.image;
      }

      // 7. Plain Text Check: Header contains no null bytes (0x00)
      bool hasNull = header.contains(0x00);
      if (!hasNull) {
        final ext = getExtension(filePath).toLowerCase();
        if (ext == '.txt' ||
            ext == '.csv' ||
            ext == '.json' ||
            ext == '.md' ||
            ext == '.log' ||
            ext.isEmpty) {
          return DetectedFileType.text;
        }
      }

      // Fallback check by extension if header signature is non-standard
      final ext = getExtension(filePath).toLowerCase();
      if (ext == '.jpg' ||
          ext == '.jpeg' ||
          ext == '.png' ||
          ext == '.webp' ||
          ext == '.gif' ||
          ext == '.bmp') {
        return DetectedFileType.image;
      }
      if (ext == '.txt' || ext == '.pdf') {
        if (!hasNull) return DetectedFileType.text;
      }

      return DetectedFileType.unknown;
    } catch (_) {
      return DetectedFileType.unknown;
    }
  }

  /// Checks whether [filePath] is an accessible, non-empty file that is a valid PDF document.
  Future<bool> isPdfFile(String filePath) async {
    if (!await isFileValidAndAccessible(filePath)) return false;
    final type = await detectFileType(filePath);
    return type == DetectedFileType.pdf;
  }

  /// Checks whether [filePath] is an accessible, non-empty file that is a supported image.
  Future<bool> isImageFile(String filePath) async {
    if (!await isFileValidAndAccessible(filePath)) return false;
    final type = await detectFileType(filePath);
    return type == DetectedFileType.image;
  }

  /// Checks whether [filePath] is an accessible, non-empty file that is plain text.
  Future<bool> isTextFile(String filePath) async {
    if (!await isFileValidAndAccessible(filePath)) return false;
    final type = await detectFileType(filePath);
    return type == DetectedFileType.text;
  }

  /// Checks if file exists, is accessible, and has size > 0 (not a zero-byte file).
  Future<bool> isFileValidAndAccessible(String filePath) async {
    if (filePath.trim().isEmpty) return false;
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      final stat = await file.stat();
      return stat.size > 0;
    } catch (_) {
      return false;
    }
  }

  /// Picks single PDF file safely
  Future<String?> pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final p = result.files.single.path!;
        if (await isPdfFile(p)) {
          return p;
        } else {
          throw Exception(
              'The selected file is empty, corrupt, missing, or not a valid PDF.');
        }
      }
      return null;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to pick PDF file: $e');
    }
  }

  /// Picks multiple PDF files safely and deduplicates output
  Future<List<String>> pickMultiplePdfFiles() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        final rawPaths = result.paths.whereType<String>().toList();
        return await validateSelectedFiles(rawPaths,
            allowedExtensions: ['pdf']);
      }
      return [];
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to pick PDF files: $e');
    }
  }

  /// Validates a list of selected file paths:
  /// - Removes duplicates preserving order
  /// - Removes missing or inaccessible files
  /// - Filters zero-byte or corrupt files using magic byte detection
  Future<List<String>> validateSelectedFiles(
    List<String> filePaths, {
    List<String>? allowedExtensions,
  }) async {
    final validPaths = <String>[];
    final seenNormalized = <String>{};

    for (final rawPath in filePaths) {
      if (rawPath.trim().isEmpty) continue;
      final normalized = normalizePath(rawPath);
      if (seenNormalized.contains(normalized)) continue;

      if (!await isFileValidAndAccessible(normalized)) continue;

      if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
        final extSet = allowedExtensions
            .map((e) => e.replaceAll('.', '').toLowerCase())
            .toSet();

        if (extSet.contains('pdf')) {
          if (!await isPdfFile(normalized)) continue;
        } else if (extSet.contains('txt')) {
          if (!await isTextFile(normalized)) continue;
        } else if (extSet.any(
            (e) => ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(e))) {
          if (!await isImageFile(normalized)) continue;
        } else {
          final ext =
              getExtension(normalized).replaceAll('.', '').toLowerCase();
          if (!extSet.contains(ext)) continue;
        }
      }

      validPaths.add(normalized);
      seenNormalized.add(normalized);
    }

    return validPaths;
  }

  /// Picks a text file safely
  Future<String?> pickTextFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null && result.files.single.path != null) {
        final p = result.files.single.path!;
        if (await isTextFile(p)) {
          return p;
        } else {
          throw Exception(
              'The selected file is empty, missing, or not a valid text file.');
        }
      }
      return null;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to pick text file: $e');
    }
  }

  /// Picks a markdown file safely
  Future<String?> pickMarkdownFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown'],
      );

      if (result != null && result.files.single.path != null) {
        final p = result.files.single.path!;
        if (await isFileAccessible(p)) {
          return p;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick markdown file: $e');
    }
  }

  /// Picks an HTML file safely
  Future<String?> pickHtmlFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['html', 'htm'],
      );

      if (result != null && result.files.single.path != null) {
        final p = result.files.single.path!;
        if (await isFileAccessible(p)) {
          return p;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick HTML file: $e');
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
        throw FileSystemException(
            'File does not exist or is inaccessible', filePath);
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
    final parts = [
      part1,
      part2,
      if (part3 != null) part3,
      if (part4 != null) part4
    ];
    return path.joinAll(parts);
  }

  /// Normalizes path for platform safety across platforms
  String normalizePath(String filePath) {
    if (filePath.isEmpty) return '';
    return path.normalize(filePath);
  }

  static final _reservedWindowsNames = <String>{
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  /// Sanitizes a file name by removing illegal filename characters
  /// across Windows, macOS, Linux, Android, and iOS.
  String sanitizeFileName(String fileName) {
    if (fileName.trim().isEmpty) return 'untitled';
    // Replace Windows & POSIX illegal characters: < > : " / \ | ? * and control chars
    String sanitized = fileName.replaceAll(RegExp(r'[<>"|?*:\/\\]'), '_');
    // Remove null characters or control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    // Trim spaces and trailing dots (problematic on Windows)
    sanitized = sanitized.trim().replaceAll(RegExp(r'[\.\s]+$'), '');

    if (sanitized.isEmpty) return 'untitled';

    // Handle Windows reserved device names
    final baseWithoutExt =
        path.basenameWithoutExtension(sanitized).toUpperCase();
    if (_reservedWindowsNames.contains(baseWithoutExt)) {
      sanitized = 'file_$sanitized';
    }

    return sanitized.isEmpty ? 'untitled' : sanitized;
  }

  /// Formats an output filename from a base name, optional suffix, and extension.
  /// Prevents extension duplication (e.g. 'doc.pdf' + '.pdf' -> 'doc.pdf').
  String formatOutputFileName({
    required String baseName,
    String? suffix,
    required String extension,
  }) {
    final ext = extension.startsWith('.') ? extension : '.$extension';
    String cleanBase = baseName.trim();
    if (cleanBase.isEmpty) {
      cleanBase = 'document';
    }

    // Strip trailing matching extension if present in cleanBase to avoid duplication
    if (cleanBase.toLowerCase().endsWith(ext.toLowerCase())) {
      cleanBase = cleanBase.substring(0, cleanBase.length - ext.length);
    } else {
      final currentExt = path.extension(cleanBase);
      if (currentExt.isNotEmpty && currentExt.length <= 5) {
        cleanBase = path.basenameWithoutExtension(cleanBase);
      }
    }

    final String withSuffix = (suffix != null && suffix.isNotEmpty)
        ? '${cleanBase}_$suffix'
        : cleanBase;

    final String sanitized = sanitizeFileName(withSuffix);
    return '$sanitized$ext';
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
    String baseWithoutExt = path.basenameWithoutExtension(normalized);

    int counter = 1;
    final match = RegExp(r'^(.*) \((\d+)\)$').firstMatch(baseWithoutExt);
    if (match != null) {
      baseWithoutExt = match.group(1)!;
      counter = int.parse(match.group(2)!) + 1;
    }

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

    final finalPath = overwrite
        ? normalizePath(targetPath)
        : await getUniqueFilePath(targetPath);
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
      throw FileSystemException(
          'Source file does not exist or is inaccessible', sourcePath);
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
            final isTempPdf = lowerPath.endsWith('.pdf') &&
                (path.basename(lowerPath).startsWith('tmp_') ||
                    path.basename(lowerPath).startsWith('pdf_') ||
                    lowerPath.contains('temp'));
            final isTempFile = lowerPath.contains('.tmp_');

            if (isTempPdf || isTempFile) {
              try {
                final stat = await entity.stat();
                final age = now.difference(stat.modified);
                // Delete temp PDF or working files older than 1 hour for .tmp_ or 24h for old PDFs
                if ((isTempFile && age.inMinutes >= 60) ||
                    (isTempPdf && age.inHours >= 24)) {
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

  /// Public entrypoint for cleaning up orphaned application temporary files.
  Future<int> cleanOrphanedTempFiles() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      return await cleanupTempResources([docDir.path, tempDir.path]);
    } catch (_) {
      return 0;
    }
  }
}
