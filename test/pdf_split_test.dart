import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
<<<<<<< HEAD
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';
=======
>>>>>>> origin/develop

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_split_test_');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to create a test PDF with given page count, text, and format
  Future<String> createTestPdf({
    required String filename,
    required int pageCount,
    required String textPrefix,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final pdf = pw.Document();
    for (int i = 1; i <= pageCount; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text(
                '$textPrefix Page$i',
                style: const pw.TextStyle(fontSize: 24),
              ),
            );
          },
        ),
      );
    }
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  group('REAL PDF Split Tests', () {
    test('Test 1 — Extract single page from multi-page PDF', () async {
      final sourcePath = await createTestPdf(
        filename: 'source_5pages.pdf',
        pageCount: 5,
        textPrefix: 'SplitDoc',
      );

      final service = PdfService();
      final splitPath = await service.splitPdf(
        pdfPath: sourcePath,
        startPage: 3,
        endPage: 3,
        customOutputPath: tempDir.path,
      );

      final file = File(splitPath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));

      final doc = syncfusion.PdfDocument(inputBytes: await file.readAsBytes());
      expect(doc.pages.count, equals(1));

      final extractor = syncfusion.PdfTextExtractor(doc);
      final text = extractor.extractText(startPageIndex: 0, endPageIndex: 0).replaceAll(RegExp(r'\s+'), ' ');
      expect(text, contains('SplitDoc Page3'));
      expect(text, isNot(contains('SplitDoc Page1')));
      expect(text, isNot(contains('SplitDoc Page2')));

      doc.dispose();
    });

    test('Test 2 — Extract multi-page range preserving exact order', () async {
      final sourcePath = await createTestPdf(
        filename: 'source_range.pdf',
        pageCount: 6,
        textPrefix: 'RangeDoc',
      );

      final service = PdfService();
      final splitPath = await service.splitPdf(
        pdfPath: sourcePath,
        startPage: 2,
        endPage: 4,
        customOutputPath: tempDir.path,
      );

      final doc = syncfusion.PdfDocument(inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(3));

      final extractor = syncfusion.PdfTextExtractor(doc);
      final p1Text = extractor.extractText(startPageIndex: 0, endPageIndex: 0).replaceAll(RegExp(r'\s+'), ' ');
      final p2Text = extractor.extractText(startPageIndex: 1, endPageIndex: 1).replaceAll(RegExp(r'\s+'), ' ');
      final p3Text = extractor.extractText(startPageIndex: 2, endPageIndex: 2).replaceAll(RegExp(r'\s+'), ' ');

      expect(p1Text, contains('RangeDoc Page2'));
      expect(p2Text, contains('RangeDoc Page3'));
      expect(p3Text, contains('RangeDoc Page4'));

      doc.dispose();
    });

    test('Test 3 — Extract full document range', () async {
      final sourcePath = await createTestPdf(
        filename: 'source_full.pdf',
        pageCount: 4,
        textPrefix: 'FullDoc',
      );

      final service = PdfService();
      final splitPath = await service.splitPdf(
        pdfPath: sourcePath,
        startPage: 1,
        endPage: 4,
        customOutputPath: tempDir.path,
      );

      final doc = syncfusion.PdfDocument(inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(4));

      final extractor = syncfusion.PdfTextExtractor(doc);
      for (int i = 0; i < 4; i++) {
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i).replaceAll(RegExp(r'\s+'), ' ');
        expect(text, contains('FullDoc Page${i + 1}'));
      }

      doc.dispose();
    });

    test('Test 4 — Preserves custom page dimensions without rasterization', () async {
      final sourcePath = await createTestPdf(
        filename: 'source_custom_dim.pdf',
        pageCount: 2,
        textPrefix: 'CustomDim',
        format: const PdfPageFormat(320, 480),
      );

      final service = PdfService();
      final splitPath = await service.splitPdf(
        pdfPath: sourcePath,
        startPage: 1,
        endPage: 2,
        customOutputPath: tempDir.path,
      );

      final doc = syncfusion.PdfDocument(inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(2));
      expect(doc.pages[0].size.width, closeTo(320, 5));
      expect(doc.pages[0].size.height, closeTo(480, 5));
      expect(doc.pages[1].size.width, closeTo(320, 5));
      expect(doc.pages[1].size.height, closeTo(480, 5));

      doc.dispose();
    });

    test('Test 5 — Preserves page rotation', () async {
      final sourcePath = await createTestPdf(
        filename: 'source_rotation.pdf',
        pageCount: 2,
        textPrefix: 'RotDoc',
      );

      final service = PdfService();
      final rotatedPath = await service.rotatePdf(
        pdfPath: sourcePath,
        rotationAngle: 180,
        customOutputPath: tempDir.path,
      );

      final splitPath = await service.splitPdf(
        pdfPath: rotatedPath,
        startPage: 1,
        endPage: 1,
        customOutputPath: tempDir.path,
      );

      final doc = syncfusion.PdfDocument(inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(1));
      expect(doc.pages[0].rotation, equals(syncfusion.PdfPageRotateAngle.rotateAngle180));

      doc.dispose();
    });

    test('Test 6 — Start page greater than end page throws exception', () async {
      final sourcePath = await createTestPdf(
        filename: 'source_invalid_range.pdf',
        pageCount: 3,
        textPrefix: 'InvalidRange',
      );

      final service = PdfService();
      expect(
        () async => await service.splitPdf(
          pdfPath: sourcePath,
          startPage: 3,
          endPage: 1,
          customOutputPath: tempDir.path,
        ),
<<<<<<< HEAD
        throwsA(isA<PdfServiceException>()),
=======
        throwsA(isA<Exception>()),
>>>>>>> origin/develop
      );
    });

    test('Test 7 — Start page below 1 throws exception', () async {
      final sourcePath = await createTestPdf(
        filename: 'source_below_one.pdf',
        pageCount: 3,
        textPrefix: 'BelowOne',
      );

      final service = PdfService();
      expect(
        () async => await service.splitPdf(
          pdfPath: sourcePath,
          startPage: 0,
          endPage: 2,
          customOutputPath: tempDir.path,
        ),
<<<<<<< HEAD
        throwsA(isA<PdfServiceException>()),
=======
        throwsA(isA<Exception>()),
>>>>>>> origin/develop
      );
    });

    test('Test 8 — End page beyond total page count throws exception', () async {
      final sourcePath = await createTestPdf(
        filename: 'source_beyond.pdf',
        pageCount: 3,
        textPrefix: 'BeyondDoc',
      );

      final service = PdfService();
      expect(
        () async => await service.splitPdf(
          pdfPath: sourcePath,
          startPage: 1,
          endPage: 10,
          customOutputPath: tempDir.path,
        ),
<<<<<<< HEAD
        throwsA(isA<PdfServiceException>()),
=======
        throwsA(isA<Exception>()),
>>>>>>> origin/develop
      );
    });

    test('Test 9 — Invalid / corrupted PDF throws exception', () async {
      final corruptFile = File('${tempDir.path}/corrupt_split.pdf');
      await corruptFile.writeAsString('not a valid pdf');

      final service = PdfService();
      expect(
        () async => await service.splitPdf(
          pdfPath: corruptFile.path,
          startPage: 1,
          endPage: 1,
          customOutputPath: tempDir.path,
        ),
<<<<<<< HEAD
        throwsA(isA<PdfServiceException>()),
=======
        throwsA(isA<Exception>()),
>>>>>>> origin/develop
      );
    });

    test('Test 10 — Non-existent file throws exception', () async {
      final service = PdfService();
      expect(
        () async => await service.splitPdf(
          pdfPath: '${tempDir.path}/non_existent_file.pdf',
          startPage: 1,
          endPage: 1,
          customOutputPath: tempDir.path,
        ),
<<<<<<< HEAD
        throwsA(isA<PdfServiceException>()),
=======
        throwsA(isA<Exception>()),
>>>>>>> origin/develop
      );
    });
  });
}
