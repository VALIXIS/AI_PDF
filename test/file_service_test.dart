import 'dart:io';
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
      final name =
          fileService.getFileName(r'C:\Users\test\Documents\document.pdf');
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

    test('fileExists returns false for non-existent file path without crashing',
        () async {
      final exists =
          await fileService.fileExists('/invalid/non_existent_file.pdf');
      expect(exists, isFalse);
    });

    test(
        'isFileAccessible returns false for non-existent path without throwing',
        () async {
      final accessible =
          await fileService.isFileAccessible('/invalid/non_existent_file.pdf');
      expect(accessible, isFalse);
    });

    test('readPdfInfo handles missing file gracefully', () async {
      final info = await fileService.readPdfInfo('/invalid/missing.pdf');
      expect(info, contains('File missing or deleted'));
      expect(info, contains('missing.pdf'));
    });

    test('getFileName handles paths with spaces and nested directories', () {
      final nameWin = fileService.getFileName(
          r'C:\Users\test user\My Documents\nested\my resume final.pdf');
      expect(nameWin, 'my resume final.pdf');

      final nameUnix = fileService
          .getFileName('/home/user/my documents/nested/my report 2026.pdf');
      expect(nameUnix, 'my report 2026.pdf');
    });

    test('getDirectoryName handles nested Windows paths and spaces', () {
      final dirWin = fileService
          .getDirectoryName(r'C:\Program Files\App Data\sub dir\file name.pdf');
      expect(dirWin, r'C:\Program Files\App Data\sub dir');
    });

    test('joinPaths handles spaces, nested directories and optional parts', () {
      final joined = fileService.joinPaths(
          r'C:\Base Dir', 'Sub Dir', 'Nested Folder', 'my document.pdf');
      expect(joined, contains('my document.pdf'));
      expect(joined, contains('Nested Folder'));
    });

    test('normalizePath cleans redundant separators and relative paths', () {
      final normalized = fileService
          .normalizePath(r'C:\Users\test\..\test\Documents\.\file.pdf');
      expect(normalized, isNotEmpty);
      expect(normalized, contains('file.pdf'));
    });

    test('readTextFile throws Exception for missing/invalid path', () async {
      expect(
        () async => await fileService
            .readTextFile(r'C:\non_existent_dir\missing_text_file.txt'),
        throwsA(isA<Exception>()),
      );
    });

    test(
        'deleteFile returns false for non-existent file without throwing uncaught exception',
        () async {
      final result = await fileService.deleteFile('/invalid/non_existent.pdf');
      expect(result, isFalse);
    });

    test(
        'sanitizeFileName removes illegal characters and control chars across platforms',
        () {
      const input = '  invalid/file:name*test?.pdf.  ';
      final sanitized = fileService.sanitizeFileName(input);
      expect(sanitized, isNot(contains('/')));
      expect(sanitized, isNot(contains(':')));
      expect(sanitized, isNot(contains('*')));
      expect(sanitized, isNot(contains('?')));
      expect(sanitized, equals('invalid_file_name_test_.pdf'));
    });

    test('getUniqueFilePath creates non-colliding filename when file exists',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('unique_path_test_');
      try {
        final initialPath = '${tempDir.path}/test_doc.pdf';
        await File(initialPath).writeAsString('test content');

        final uniquePath = await fileService.getUniqueFilePath(initialPath);
        expect(uniquePath, isNot(equals(initialPath)));
        expect(uniquePath, contains('test_doc (1).pdf'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('safeWriteBytes performs atomic write and directory creation',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('safe_write_test_');
      try {
        final targetPath = '${tempDir.path}/nested/dir/atomic_doc.pdf';
        final savedPath =
            await fileService.safeWriteBytes(targetPath, [65, 66, 67]);

        expect(await File(savedPath).exists(), isTrue);
        expect(await File(savedPath).readAsString(), equals('ABC'));

        // Attempting to safeWriteBytes again without overwrite should resolve duplicate filename
        final secondPath =
            await fileService.safeWriteBytes(targetPath, [68, 69, 70]);
        expect(secondPath, isNot(equals(savedPath)));
        expect(secondPath, contains('atomic_doc (1).pdf'));
        expect(await File(secondPath).readAsString(), equals('DEF'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('safeCopyFile safely duplicates a file', () async {
      final tempDir = await Directory.systemTemp.createTemp('safe_copy_test_');
      try {
        final srcPath = '${tempDir.path}/source.txt';
        await File(srcPath).writeAsString('Hello Copy');

        final destPath = '${tempDir.path}/destination.txt';
        final copiedPath = await fileService.safeCopyFile(srcPath, destPath);

        expect(await File(copiedPath).exists(), isTrue);
        expect(await File(copiedPath).readAsString(), equals('Hello Copy'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'sanitizeFileName handles Windows reserved names and trailing dots/spaces',
        () {
      expect(fileService.sanitizeFileName('CON.pdf'), equals('file_CON.pdf'));
      expect(fileService.sanitizeFileName('nul'), equals('file_nul'));
      expect(fileService.sanitizeFileName('PRN.txt'), equals('file_PRN.txt'));
      expect(fileService.sanitizeFileName('  doc name.pdf. . '),
          equals('doc name.pdf'));
      expect(fileService.sanitizeFileName(''), equals('untitled'));
    });

    test(
        'formatOutputFileName avoids duplicate extensions and handles suffixes cleanly',
        () {
      final name1 = fileService.formatOutputFileName(
        baseName: 'document.pdf',
        suffix: 'compressed',
        extension: 'pdf',
      );
      expect(name1, equals('document_compressed.pdf'));

      final name2 = fileService.formatOutputFileName(
        baseName: 'report.txt',
        suffix: 'extracted',
        extension: 'txt',
      );
      expect(name2, equals('report_extracted.txt'));

      final name3 = fileService.formatOutputFileName(
        baseName: 'my file name',
        extension: '.pdf',
      );
      expect(name3, equals('my file name.pdf'));
    });

    test('getUniqueFilePath increments existing (N) suffixes correctly',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('unique_inc_test_');
      try {
        final doc1Path = '${tempDir.path}/doc (1).pdf';
        await File(doc1Path).writeAsString('content 1');

        final nextPath = await fileService.getUniqueFilePath(doc1Path);
        expect(nextPath, contains('doc (2).pdf'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('validateSelectedFiles deduplicates and filters missing/invalid files',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('validate_files_test_');
      try {
        final f1 = File('${tempDir.path}/valid1.pdf');
        await f1.writeAsString('%PDF-1.4 pdf 1');

        final f2 = File('${tempDir.path}/valid2.pdf');
        await f2.writeAsString('%PDF-1.4 pdf 2');

        final pathsToValidate = [
          f1.path,
          f1.path, // duplicate
          '${tempDir.path}/non_existent.pdf', // missing
          f2.path,
        ];

        final validated = await fileService
            .validateSelectedFiles(pathsToValidate, allowedExtensions: ['pdf']);
        expect(validated.length, equals(2));
        expect(validated.first, equals(fileService.normalizePath(f1.path)));
        expect(validated.last, equals(fileService.normalizePath(f2.path)));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
