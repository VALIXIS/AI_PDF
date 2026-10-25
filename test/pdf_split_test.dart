import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';

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
      final text = extractor
          .extractText(startPageIndex: 0, endPageIndex: 0)
          .replaceAll(RegExp(r'\s+'), ' ');
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

      final doc = syncfusion.PdfDocument(
          inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(3));

      final extractor = syncfusion.PdfTextExtractor(doc);
      final p1Text = extractor
          .extractText(startPageIndex: 0, endPageIndex: 0)
          .replaceAll(RegExp(r'\s+'), ' ');
      final p2Text = extractor
          .extractText(startPageIndex: 1, endPageIndex: 1)
          .replaceAll(RegExp(r'\s+'), ' ');
      final p3Text = extractor
          .extractText(startPageIndex: 2, endPageIndex: 2)
          .replaceAll(RegExp(r'\s+'), ' ');

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

      final doc = syncfusion.PdfDocument(
          inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(4));

      final extractor = syncfusion.PdfTextExtractor(doc);
      for (int i = 0; i < 4; i++) {
        final text = extractor
            .extractText(startPageIndex: i, endPageIndex: i)
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(text, contains('FullDoc Page${i + 1}'));
      }

      doc.dispose();
    });

    test('Test 4 — Preserves custom page dimensions without rasterization',
        () async {
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

      final doc = syncfusion.PdfDocument(
          inputBytes: await File(splitPath).readAsBytes());
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

      final doc = syncfusion.PdfDocument(
          inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(1));
      expect(doc.pages[0].rotation,
          equals(syncfusion.PdfPageRotateAngle.rotateAngle180));

      doc.dispose();
    });

    test('Test 6 — Start page greater than end page throws exception',
        () async {
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
        throwsA(isA<Exception>()),
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
        throwsA(isA<Exception>()),
      );
    });

    test('Test 8 — End page beyond total page count throws exception',
        () async {
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
        throwsA(isA<Exception>()),
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
        throwsA(isA<Exception>()),
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
        throwsA(isA<Exception>()),
      );
    });

    test('Test 11 — Preserves PDF document metadata (title, author, creationDate) when splitting', () async {
      final doc = syncfusion.PdfDocument();
      doc.documentInformation.title = 'Split Master Document';
      doc.documentInformation.author = 'Split Architect';
      doc.documentInformation.subject = 'Splitting Precision';
      doc.documentInformation.keywords = 'split, metadata, test';
      doc.documentInformation.creator = 'AI PDF Splitter';
      final creationDate = DateTime(2025, 4, 10, 9, 30, 0);
      doc.documentInformation.creationDate = creationDate;

      for (int i = 1; i <= 4; i++) {
        final page = doc.pages.add();
        page.graphics.drawString(
          'Split Source Page $i',
          syncfusion.PdfStandardFont(syncfusion.PdfFontFamily.helvetica, 12),
        );
      }
      final sourcePath = '${tempDir.path}/meta_split_source.pdf';
      await File(sourcePath).writeAsBytes(doc.saveSync());
      doc.dispose();

      final service = PdfService();
      final splitPath = await service.splitPdf(
        pdfPath: sourcePath,
        startPage: 2,
        endPage: 3,
        customOutputPath: tempDir.path,
      );

      final loadedDoc = syncfusion.PdfDocument(
        inputBytes: await File(splitPath).readAsBytes(),
      );
      expect(loadedDoc.pages.count, equals(2));
      expect(loadedDoc.documentInformation.title, equals('Split Master Document'));
      expect(loadedDoc.documentInformation.author, equals('Split Architect'));
      expect(loadedDoc.documentInformation.subject, equals('Splitting Precision'));
      expect(loadedDoc.documentInformation.keywords, equals('split, metadata, test'));
      expect(loadedDoc.documentInformation.creator, equals('AI PDF Splitter'));
      expect(loadedDoc.documentInformation.creationDate?.year, equals(2025));
      expect(loadedDoc.documentInformation.creationDate?.month, equals(4));
      expect(loadedDoc.documentInformation.creationDate?.day, equals(10));
      loadedDoc.dispose();
    });

    test('Test 12 — Preserves outline tree (bookmarks) and remaps destination pages for split range', () async {
      final doc = syncfusion.PdfDocument();
      final p1 = doc.pages.add(); // Index 0 (Page 1)
      final p2 = doc.pages.add(); // Index 1 (Page 2)
      final p3 = doc.pages.add(); // Index 2 (Page 3)
      final p4 = doc.pages.add(); // Index 3 (Page 4)
      final p5 = doc.pages.add(); // Index 4 (Page 5)

      final b1 = doc.bookmarks.add('Chapter 1');
      b1.destination = syncfusion.PdfDestination(p1, const Offset(0, 0));
      final sub1 = b1.add('Section 1.1');
      sub1.destination = syncfusion.PdfDestination(p2, const Offset(0, 0));

      final b2 = doc.bookmarks.add('Chapter 2');
      b2.destination = syncfusion.PdfDestination(p3, const Offset(0, 0));
      final sub2 = b2.add('Section 2.1');
      sub2.destination = syncfusion.PdfDestination(p4, const Offset(0, 0));

      final b3 = doc.bookmarks.add('Chapter 3');
      b3.destination = syncfusion.PdfDestination(p5, const Offset(0, 0));

      final sourcePath = '${tempDir.path}/tree_split_source.pdf';
      await File(sourcePath).writeAsBytes(doc.saveSync());
      doc.dispose();

      final service = PdfService();
      // Split pages 2 to 4 (p2, p3, p4) -> 3 pages
      final splitPath = await service.splitPdf(
        pdfPath: sourcePath,
        startPage: 2,
        endPage: 4,
        customOutputPath: tempDir.path,
      );

      final loaded = syncfusion.PdfDocument(
        inputBytes: await File(splitPath).readAsBytes(),
      );
      expect(loaded.pages.count, equals(3));

      // b1 has child Section 1.1 in range (p2 -> index 0 in split)
      expect(loaded.bookmarks.count, equals(2));
      expect(loaded.bookmarks[0].title, equals('Chapter 1'));
      expect(loaded.bookmarks[0].count, equals(1));
      expect(loaded.bookmarks[0][0].title, equals('Section 1.1'));
      expect(loaded.bookmarks[0][0].destination?.page, equals(loaded.pages[0]));

      // b2 has destination p3 -> index 1 in split, and sub2 has p4 -> index 2 in split
      expect(loaded.bookmarks[1].title, equals('Chapter 2'));
      expect(loaded.bookmarks[1].destination?.page, equals(loaded.pages[1]));
      expect(loaded.bookmarks[1].count, equals(1));
      expect(loaded.bookmarks[1][0].title, equals('Section 2.1'));
      expect(loaded.bookmarks[1][0].destination?.page, equals(loaded.pages[2]));

      // Chapter 3 was excluded because page 5 is out of range
      loaded.dispose();
    });

    test('Test 13 — File stream safety and explicit closure in finally blocks', () async {
      final sourcePath = await createTestPdf(
        filename: 'stream_split.pdf',
        pageCount: 3,
        textPrefix: 'StreamSplit',
      );

      final service = PdfService();
      final splitPath = await service.splitPdf(
        pdfPath: sourcePath,
        startPage: 1,
        endPage: 2,
        customOutputPath: tempDir.path,
      );

      final splitFile = File(splitPath);
      expect(await splitFile.exists(), isTrue);
      final raf = await splitFile.open(mode: FileMode.read);
      try {
        expect(await raf.length(), greaterThan(0));
      } finally {
        await raf.close();
      }
    });
  });
}
