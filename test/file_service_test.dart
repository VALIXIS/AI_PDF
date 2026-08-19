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

    test('getFileName handles paths with spaces and nested directories', () {
      final nameWin = fileService.getFileName(r'C:\Users\test user\My Documents\nested\my resume final.pdf');
      expect(nameWin, 'my resume final.pdf');

      final nameUnix = fileService.getFileName('/home/user/my documents/nested/my report 2026.pdf');
      expect(nameUnix, 'my report 2026.pdf');
    });

    test('getDirectoryName handles nested Windows paths and spaces', () {
      final dirWin = fileService.getDirectoryName(r'C:\Program Files\App Data\sub dir\file name.pdf');
      expect(dirWin, r'C:\Program Files\App Data\sub dir');
    });

    test('joinPaths handles spaces, nested directories and optional parts', () {
      final joined = fileService.joinPaths(r'C:\Base Dir', 'Sub Dir', 'Nested Folder', 'my document.pdf');
      expect(joined, contains('my document.pdf'));
      expect(joined, contains('Nested Folder'));
    });

    test('normalizePath cleans redundant separators and relative paths', () {
      final normalized = fileService.normalizePath(r'C:\Users\test\..\test\Documents\.\file.pdf');
      expect(normalized, isNotEmpty);
      expect(normalized, contains('file.pdf'));
    });

    test('readTextFile throws Exception for missing/invalid path', () async {
      expect(
        () async => await fileService.readTextFile(r'C:\non_existent_dir\missing_text_file.txt'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteFile returns false for non-existent file without throwing uncaught exception', () async {
      final result = await fileService.deleteFile('/invalid/non_existent.pdf');
      expect(result, isFalse);
    });
  });
}
