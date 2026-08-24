import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final fileService = FileService();
  final pdfService = PdfService();
  final storageService = StorageService();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('file_validation_test_');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to create a valid minimal PDF file
  Future<String> createValidPdf(String name) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Center(child: pw.Text('Test PDF')),
      ),
    );
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  group('File Type Detection and Validation Robustness Tests', () {
    test('1. Valid supported PDF file is accepted', () async {
      final path = await createValidPdf('valid_document.pdf');
      final isPdf = await fileService.isPdfFile(path);
      final type = await fileService.detectFileType(path);

      expect(isPdf, isTrue);
      expect(type, equals(DetectedFileType.pdf));
    });

    test('2. Valid PDF file with spaces in its name and no extension is accepted', () async {
      final path = await createValidPdf('my valid resume 2026');
      final isPdf = await fileService.isPdfFile(path);
      final type = await fileService.detectFileType(path);

      expect(isPdf, isTrue);
      expect(type, equals(DetectedFileType.pdf));
    });

    test('3. Unsupported file type (e.g. random binary/executable) is rejected gracefully', () async {
      final file = File('${tempDir.path}/unsupported.bin');
      await file.writeAsBytes([0x7F, 0x45, 0x4C, 0x46, 0x01, 0x01, 0x01, 0x00]);

      final isPdf = await fileService.isPdfFile(file.path);
      final isImg = await fileService.isImageFile(file.path);
      final type = await fileService.detectFileType(file.path);

      expect(isPdf, isFalse);
      expect(isImg, isFalse);
      expect(type, equals(DetectedFileType.unknown));
    });

    test('4. Zero-byte file is rejected and handled gracefully', () async {
      final file = File('${tempDir.path}/zero_bytes.pdf');
      await file.writeAsBytes([]);

      final isAccessible = await fileService.isFileValidAndAccessible(file.path);
      final isPdf = await fileService.isPdfFile(file.path);

      expect(isAccessible, isFalse);
      expect(isPdf, isFalse);
    });

    test('5. Corrupt/malformed PDF file does not crash the app and throws PdfServiceException', () async {
      final file = File('${tempDir.path}/corrupt.pdf');
      // Truncated header that looks like PDF start but contains junk body
      await file.writeAsString('%PDF-1.4\n%junk_corrupted_data_without_objects');

      expect(
        () async => await pdfService.getPdfPageCount(file.path),
        throwsA(isA<PdfServiceException>()),
      );
    });

    test('6. Missing file does not crash the app', () async {
      const missingPath = '/non_existent_directory/missing_file.pdf';
      final exists = await fileService.fileExists(missingPath);
      final accessible = await fileService.isFileValidAndAccessible(missingPath);
      final isPdf = await fileService.isPdfFile(missingPath);

      expect(exists, isFalse);
      expect(accessible, isFalse);
      expect(isPdf, isFalse);

      expect(
        () async => await pdfService.getPdfPageCount(missingPath),
        throwsA(isA<PdfServiceException>()),
      );
    });

    test('7. File with incorrect extension (plain text named .pdf) is handled safely', () async {
      final file = File('${tempDir.path}/fake_doc.pdf');
      await file.writeAsString('This is just plain text content, not a PDF document.');

      final isPdf = await fileService.isPdfFile(file.path);
      final isText = await fileService.isTextFile(file.path);

      expect(isPdf, isFalse);
      expect(isText, isTrue);
    });

    test('8. Invalid/empty path strings are handled safely without exceptions', () async {
      expect(await fileService.isFileValidAndAccessible(''), isFalse);
      expect(await fileService.isPdfFile(''), isFalse);
      expect(await fileService.detectFileType(''), equals(DetectedFileType.unknown));
    });

    test('9. Failed validation does not create a false history entry in Hive', () async {
      final missingPath = '${tempDir.path}/non_existent_history_file.pdf';
      final entry = HistoryEntry(
        id: 'test_missing_id',
        title: 'Failed History Entry',
        date: DateTime.now(),
        filePath: missingPath,
        toolType: 'test',
      );

      await storageService.addHistoryEntry(entry);
      final fetched = await storageService.getHistoryEntry('test_missing_id');

      expect(fetched, isNull);
    });

    test('10. Existing valid document history entry is persisted', () async {
      final validPath = await createValidPdf('history_valid.pdf');
      final entry = HistoryEntry(
        id: 'test_valid_id',
        title: 'Valid Document Entry',
        date: DateTime.now(),
        filePath: validPath,
        toolType: 'test',
      );

      await storageService.addHistoryEntry(entry);
      final fetched = await storageService.getHistoryEntry('test_valid_id');

      expect(fetched, isNotNull);
      expect(fetched?.filePath, equals(validPath));
    });

    test('11. Large files are read via header bytes (<=1024 bytes) without full memory load', () async {
      final file = File('${tempDir.path}/large_mock.pdf');
      final sink = file.openWrite();
      sink.write('%PDF-1.7\n');
      // Write 2MB of padding
      final padding = List.filled(1024 * 1024, 65);
      sink.add(padding);
      sink.add(padding);
      await sink.close();

      final header = await fileService.readFileHeader(file.path, maxBytes: 1024);
      final isPdf = await fileService.isPdfFile(file.path);

      expect(header.length, equals(1024));
      expect(isPdf, isTrue);
    });
  });
}
