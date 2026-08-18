import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';

void main() {
  group('FileService Platform-Safe Path Parsing & Missing-File Tests', () {
    final fileService = FileService();

    test('getFileName handles Unix-style paths correctly', () {
      final name = fileService.getFileName('/path/to/document.pdf');
      expect(name, 'document.pdf');
    });

    test('getFileName handles Windows-style paths correctly', () {
      final name = fileService.getFileName(r'C:\Users\test\Documents\document.pdf');
      expect(name, 'document.pdf');
    });

    test('getFileName handles empty string', () {
      final name = fileService.getFileName('');
      expect(name, '');
    });

    test('getDirectoryName handles Unix and Windows paths', () {
      final dirUnix = fileService.getDirectoryName('/path/to/file.pdf');
      expect(dirUnix, '/path/to');

      final dirWin = fileService.getDirectoryName(r'C:\path\to\file.pdf');
      expect(dirWin, r'C:\path\to');
    });

    test('getExtension extracts correct file extension', () {
      final ext = fileService.getExtension('/path/to/sample.pdf');
      expect(ext, '.pdf');
    });

    test('joinPaths builds valid path', () {
      final joined = fileService.joinPaths('folder', 'subfolder', 'file.pdf');
      expect(joined, contains('file.pdf'));
    });

    test('fileExists returns false for non-existent file path without crashing', () async {
      final exists = await fileService.fileExists('/invalid/non_existent_file.pdf');
      expect(exists, isFalse);
    });

    test('isFileAccessible returns false for non-existent path without throwing', () async {
      final accessible = await fileService.isFileAccessible('/invalid/non_existent_file.pdf');
      expect(accessible, isFalse);
    });

    test('readPdfInfo handles missing file gracefully', () async {
      final info = await fileService.readPdfInfo('/invalid/missing.pdf');
      expect(info, contains('File missing or deleted'));
      expect(info, contains('missing.pdf'));
    });

    test('deleteFile returns false for non-existent file', () async {
      final result = await fileService.deleteFile('/invalid/non_existent.pdf');
      expect(result, isFalse);
    });
  });
}
