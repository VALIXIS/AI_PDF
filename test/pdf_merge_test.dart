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
    tempDir = await Directory.systemTemp.createTemp('pdf_merge_test_');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to create a test PDF using pw.Document with specific page count, text, format
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

  group('Syncfusion API Verification & PDF Merge Tests', () {
    test(
        'Verify Syncfusion createTemplate and drawPdfTemplate API operates natively',
        () async {
      final pathA = await createTestPdf(
          filename: 'docA.pdf', pageCount: 2, textPrefix: 'DocA');
      final pathB = await createTestPdf(
          filename: 'docB.pdf', pageCount: 3, textPrefix: 'DocB');

      final bytesA = await File(pathA).readAsBytes();
      final bytesB = await File(pathB).readAsBytes();

      final destDoc = syncfusion.PdfDocument();
      for (final bytes in [bytesA, bytesB]) {
        final src = syncfusion.PdfDocument(inputBytes: bytes);
        for (int i = 0; i < src.pages.count; i++) {
          final p = src.pages[i];
          final template = p.createTemplate();
          final sec = destDoc.sections!.add();
          sec.pageSettings.size = p.size;
          sec.pageSettings.margins.all = 0;
          sec.pages
              .add()
              .graphics
              .drawPdfTemplate(template, Offset.zero, p.size);
        }
        src.dispose();
      }

      expect(destDoc.pages.count, equals(5));

      final List<int> mergedBytes = destDoc.saveSync();
      expect(mergedBytes, isNotEmpty);
      destDoc.dispose();

      // Verify merged PDF using Syncfusion reader
      final loadedMerged = syncfusion.PdfDocument(inputBytes: mergedBytes);
      expect(loadedMerged.pages.count, equals(5));
      loadedMerged.dispose();
    });

    test('Test 1 — Merge two PDFs (2 pages + 3 pages = 5 pages)', () async {
      final pathA = await createTestPdf(
          filename: 'a.pdf', pageCount: 2, textPrefix: 'DocA');
      final pathB = await createTestPdf(
          filename: 'b.pdf', pageCount: 3, textPrefix: 'DocB');

      final service = PdfService();
      final mergedPath = await service
          .mergePdfs([pathA, pathB], customOutputPath: tempDir.path);

      final file = File(mergedPath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));

      final mergedBytes = await file.readAsBytes();
      final loadedDoc = syncfusion.PdfDocument(inputBytes: mergedBytes);
      expect(loadedDoc.pages.count, equals(5));

      final extractor = syncfusion.PdfTextExtractor(loadedDoc);
      final p1Text = extractor
          .extractText(startPageIndex: 0, endPageIndex: 0)
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(p1Text, contains('DocA Page1'));

      final p3Text = extractor
          .extractText(startPageIndex: 2, endPageIndex: 2)
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(p3Text, contains('DocB Page1'));

      loadedDoc.dispose();
    });

    test('Test 2 — Merge multiple PDFs (3 PDFs preserving order)', () async {
      final pathA = await createTestPdf(
          filename: 'm1.pdf', pageCount: 1, textPrefix: 'Part1');
      final pathB = await createTestPdf(
          filename: 'm2.pdf', pageCount: 2, textPrefix: 'Part2');
      final pathC = await createTestPdf(
          filename: 'm3.pdf', pageCount: 4, textPrefix: 'Part3');

      final service = PdfService();
      final mergedPath = await service
          .mergePdfs([pathA, pathB, pathC], customOutputPath: tempDir.path);

      final loadedDoc = syncfusion.PdfDocument(
          inputBytes: await File(mergedPath).readAsBytes());
      expect(loadedDoc.pages.count, equals(7));

      final extractor = syncfusion.PdfTextExtractor(loadedDoc);
      final p1Text = extractor
          .extractText(startPageIndex: 0, endPageIndex: 0)
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(p1Text, contains('Part1 Page1'));

      final p2Text = extractor
          .extractText(startPageIndex: 1, endPageIndex: 1)
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(p2Text, contains('Part2 Page1'));

      final p4Text = extractor
          .extractText(startPageIndex: 3, endPageIndex: 3)
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(p4Text, contains('Part3 Page1'));

      loadedDoc.dispose();
    });

    test('Test 3 — Single PDF file handling', () async {
      final pathA = await createTestPdf(
          filename: 'single.pdf', pageCount: 3, textPrefix: 'Single');
      final service = PdfService();
      final mergedPath =
          await service.mergePdfs([pathA], customOutputPath: tempDir.path);

      final loadedDoc = syncfusion.PdfDocument(
          inputBytes: await File(mergedPath).readAsBytes());
      expect(loadedDoc.pages.count, equals(3));
      loadedDoc.dispose();
    });

    test('Test 4 — Different page sizes and orientations', () async {
      // Portrait custom (300 x 500)
      final pathPortrait = await createTestPdf(
        filename: 'portrait.pdf',
        pageCount: 1,
        textPrefix: 'Portrait',
        format: const PdfPageFormat(300, 500),
      );
      // Landscape custom (600 x 400)
      final pathLandscape = await createTestPdf(
        filename: 'landscape.pdf',
        pageCount: 1,
        textPrefix: 'Landscape',
        format: const PdfPageFormat(600, 400),
      );

      final service = PdfService();
      final mergedPath = await service.mergePdfs([pathPortrait, pathLandscape],
          customOutputPath: tempDir.path);

      final loadedDoc = syncfusion.PdfDocument(
          inputBytes: await File(mergedPath).readAsBytes());
      expect(loadedDoc.pages.count, equals(2));

      final p1 = loadedDoc.pages[0];
      expect(p1.size.width, closeTo(300, 5));
      expect(p1.size.height, closeTo(500, 5));

      final p2 = loadedDoc.pages[1];
      expect(p2.size.width, closeTo(400, 5));
      expect(p2.size.height, closeTo(600, 5));

      loadedDoc.dispose();
    });

    test('Test 5 — Invalid / corrupted input fails safely', () async {
      final invalidFile = File('${tempDir.path}/corrupted.pdf');
      await invalidFile
          .writeAsString('This is not a PDF document format content');

      final service = PdfService();
      expect(
        () async => await service
            .mergePdfs([invalidFile.path], customOutputPath: tempDir.path),
        throwsA(isA<Exception>()),
      );
    });

    test('Test 6 — Empty file list throws exception', () async {
      final service = PdfService();
      expect(
        () async => await service.mergePdfs([], customOutputPath: tempDir.path),
        throwsA(isA<Exception>()),
      );
    });

    test('Test 7 — Non-existent file throws exception', () async {
      final service = PdfService();
      expect(
        () async => await service.mergePdfs(
            ['${tempDir.path}/does_not_exist.pdf'],
            customOutputPath: tempDir.path),
        throwsA(isA<Exception>()),
      );
    });

    test('Test 8 — Preserves page rotation when merging rotated pages',
        () async {
      final normalPdfPath = await createTestPdf(
        filename: 'normal.pdf',
        pageCount: 1,
        textPrefix: 'NormalPage',
      );

      // Create a PDF and rotate it using PdfService.rotatePdf
      final service = PdfService();
      final rotatedPdfPath = await service.rotatePdf(
        pdfPath: normalPdfPath,
        rotationAngle: 90,
        customOutputPath: tempDir.path,
      );

      final mergedPath = await service.mergePdfs(
        [normalPdfPath, rotatedPdfPath],
        customOutputPath: tempDir.path,
      );

      final loadedDoc = syncfusion.PdfDocument(
          inputBytes: await File(mergedPath).readAsBytes());
      expect(loadedDoc.pages.count, equals(2));
      expect(loadedDoc.pages[0].rotation,
          equals(syncfusion.PdfPageRotateAngle.rotateAngle0));
      expect(loadedDoc.pages[1].rotation,
          equals(syncfusion.PdfPageRotateAngle.rotateAngle90));
      loadedDoc.dispose();
    });

    test('Test 9 — getPdfPageCount returns correct page count', () async {
      final path3Pages = await createTestPdf(
          filename: 'three_pages.pdf', pageCount: 3, textPrefix: 'ThreePages');
      final service = PdfService();
      final count = await service.getPdfPageCount(path3Pages);
      expect(count, equals(3));
    });

    test('Test 10 — Preserves PDF document metadata (title, author, creationDate)', () async {
      final doc1 = syncfusion.PdfDocument();
      doc1.documentInformation.title = 'Merged Document Master Title';
      doc1.documentInformation.author = 'Antigravity Architect';
      doc1.documentInformation.subject = 'Merging Architecture';
      doc1.documentInformation.keywords = 'syncfusion, pdf, metadata';
      doc1.documentInformation.creator = 'AI PDF Maker';
      final creationDate = DateTime(2025, 6, 15, 12, 0, 0);
      doc1.documentInformation.creationDate = creationDate;
      final page1 = doc1.pages.add();
      page1.graphics.drawString(
        'Doc 1 Page 1',
        syncfusion.PdfStandardFont(syncfusion.PdfFontFamily.helvetica, 12),
      );
      final path1 = '${tempDir.path}/meta_doc1.pdf';
      await File(path1).writeAsBytes(doc1.saveSync());
      doc1.dispose();

      final doc2 = syncfusion.PdfDocument();
      final page2 = doc2.pages.add();
      page2.graphics.drawString(
        'Doc 2 Page 1',
        syncfusion.PdfStandardFont(syncfusion.PdfFontFamily.helvetica, 12),
      );
      final path2 = '${tempDir.path}/meta_doc2.pdf';
      await File(path2).writeAsBytes(doc2.saveSync());
      doc2.dispose();

      final service = PdfService();
      final mergedPath = await service.mergePdfs(
        [path1, path2],
        customOutputPath: tempDir.path,
      );

      final loadedDoc = syncfusion.PdfDocument(
        inputBytes: await File(mergedPath).readAsBytes(),
      );
      expect(loadedDoc.documentInformation.title, equals('Merged Document Master Title'));
      expect(loadedDoc.documentInformation.author, equals('Antigravity Architect'));
      expect(loadedDoc.documentInformation.subject, equals('Merging Architecture'));
      expect(loadedDoc.documentInformation.keywords, equals('syncfusion, pdf, metadata'));
      expect(loadedDoc.documentInformation.creator, equals('AI PDF Maker'));
      expect(loadedDoc.documentInformation.creationDate.year, equals(2025));
      expect(loadedDoc.documentInformation.creationDate.month, equals(6));
      expect(loadedDoc.documentInformation.creationDate.day, equals(15));
      loadedDoc.dispose();
    });

    test('Test 11 — Preserves outline tree (bookmarks and nested bookmarks) across merged documents', () async {
      final doc1 = syncfusion.PdfDocument();
      final p1 = doc1.pages.add();
      final p2 = doc1.pages.add();
      final b1 = doc1.bookmarks.add('Chapter 1');
      b1.destination = syncfusion.PdfDestination(p1, const Offset(0, 0));
      final sub1 = b1.add('Section 1.1');
      sub1.destination = syncfusion.PdfDestination(p2, const Offset(0, 0));
      final path1 = '${tempDir.path}/tree_doc1.pdf';
      await File(path1).writeAsBytes(doc1.saveSync());
      doc1.dispose();

      final doc2 = syncfusion.PdfDocument();
      final p3 = doc2.pages.add();
      final p4 = doc2.pages.add();
      final b2 = doc2.bookmarks.add('Chapter 2');
      b2.destination = syncfusion.PdfDestination(p3, const Offset(0, 0));
      final sub2 = b2.add('Section 2.1');
      sub2.destination = syncfusion.PdfDestination(p4, const Offset(0, 0));
      final path2 = '${tempDir.path}/tree_doc2.pdf';
      await File(path2).writeAsBytes(doc2.saveSync());
      doc2.dispose();

      final service = PdfService();
      final mergedPath = await service.mergePdfs(
        [path1, path2],
        customOutputPath: tempDir.path,
      );

      final loaded = syncfusion.PdfDocument(
        inputBytes: await File(mergedPath).readAsBytes(),
      );
      expect(loaded.pages.count, equals(4));
      expect(loaded.bookmarks.count, equals(2));

      // Check Chapter 1 & Section 1.1
      expect(loaded.bookmarks[0].title, equals('Chapter 1'));
      expect(loaded.bookmarks[0].destination?.page, equals(loaded.pages[0]));
      expect(loaded.bookmarks[0].count, equals(1));
      expect(loaded.bookmarks[0][0].title, equals('Section 1.1'));
      expect(loaded.bookmarks[0][0].destination?.page, equals(loaded.pages[1]));

      // Check Chapter 2 & Section 2.1 (destinations remapped to pages 2 and 3)
      expect(loaded.bookmarks[1].title, equals('Chapter 2'));
      expect(loaded.bookmarks[1].destination?.page, equals(loaded.pages[2]));
      expect(loaded.bookmarks[1].count, equals(1));
      expect(loaded.bookmarks[1][0].title, equals('Section 2.1'));
      expect(loaded.bookmarks[1][0].destination?.page, equals(loaded.pages[3]));

      loaded.dispose();
    });

    test('Test 12 — File stream safety and explicit closure in finally blocks', () async {
      final pathA = await createTestPdf(
        filename: 'stream_a.pdf',
        pageCount: 1,
        textPrefix: 'StreamA',
      );
      final pathB = await createTestPdf(
        filename: 'stream_b.pdf',
        pageCount: 1,
        textPrefix: 'StreamB',
      );

      final service = PdfService();
      final mergedPath = await service.mergePdfs(
        [pathA, pathB],
        customOutputPath: tempDir.path,
      );

      // Verify merged file is not locked and can be read or modified immediately
      final mergedFile = File(mergedPath);
      expect(await mergedFile.exists(), isTrue);
      final raf = await mergedFile.open(mode: FileMode.read);
      try {
        expect(await raf.length(), greaterThan(0));
      } finally {
        await raf.close();
      }
    });
  });
}
