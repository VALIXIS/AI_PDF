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
    test('Verify Syncfusion createTemplate and drawPdfTemplate API operates natively', () async {
      final pathA = await createTestPdf(filename: 'docA.pdf', pageCount: 2, textPrefix: 'DocA');
      final pathB = await createTestPdf(filename: 'docB.pdf', pageCount: 3, textPrefix: 'DocB');

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
          sec.pages.add().graphics.drawPdfTemplate(template, Offset.zero, p.size);
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
      final pathA = await createTestPdf(filename: 'a.pdf', pageCount: 2, textPrefix: 'DocA');
      final pathB = await createTestPdf(filename: 'b.pdf', pageCount: 3, textPrefix: 'DocB');

      final service = PdfService();
      final mergedPath = await service.mergePdfs([pathA, pathB], customOutputPath: tempDir.path);

      final file = File(mergedPath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));

      final mergedBytes = await file.readAsBytes();
      final loadedDoc = syncfusion.PdfDocument(inputBytes: mergedBytes);
      expect(loadedDoc.pages.count, equals(5));

      final extractor = syncfusion.PdfTextExtractor(loadedDoc);
      final p1Text = extractor.extractText(startPageIndex: 0, endPageIndex: 0).replaceAll(RegExp(r'\s+'), ' ');
      expect(p1Text, contains('DocA Page1'));

      final p3Text = extractor.extractText(startPageIndex: 2, endPageIndex: 2).replaceAll(RegExp(r'\s+'), ' ');
      expect(p3Text, contains('DocB Page1'));

      loadedDoc.dispose();
    });

    test('Test 2 — Merge multiple PDFs (3 PDFs preserving order)', () async {
      final pathA = await createTestPdf(filename: 'm1.pdf', pageCount: 1, textPrefix: 'Part1');
      final pathB = await createTestPdf(filename: 'm2.pdf', pageCount: 2, textPrefix: 'Part2');
      final pathC = await createTestPdf(filename: 'm3.pdf', pageCount: 4, textPrefix: 'Part3');

      final service = PdfService();
      final mergedPath = await service.mergePdfs([pathA, pathB, pathC], customOutputPath: tempDir.path);

      final loadedDoc = syncfusion.PdfDocument(inputBytes: await File(mergedPath).readAsBytes());
      expect(loadedDoc.pages.count, equals(7));

      final extractor = syncfusion.PdfTextExtractor(loadedDoc);
      final p1Text = extractor.extractText(startPageIndex: 0, endPageIndex: 0).replaceAll(RegExp(r'\s+'), ' ');
      expect(p1Text, contains('Part1 Page1'));

      final p2Text = extractor.extractText(startPageIndex: 1, endPageIndex: 1).replaceAll(RegExp(r'\s+'), ' ');
      expect(p2Text, contains('Part2 Page1'));

      final p4Text = extractor.extractText(startPageIndex: 3, endPageIndex: 3).replaceAll(RegExp(r'\s+'), ' ');
      expect(p4Text, contains('Part3 Page1'));

      loadedDoc.dispose();
    });

    test('Test 3 — Single PDF file handling', () async {
      final pathA = await createTestPdf(filename: 'single.pdf', pageCount: 3, textPrefix: 'Single');
      final service = PdfService();
      final mergedPath = await service.mergePdfs([pathA], customOutputPath: tempDir.path);

      final loadedDoc = syncfusion.PdfDocument(inputBytes: await File(mergedPath).readAsBytes());
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
      final mergedPath = await service.mergePdfs([pathPortrait, pathLandscape], customOutputPath: tempDir.path);

      final loadedDoc = syncfusion.PdfDocument(inputBytes: await File(mergedPath).readAsBytes());
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
      await invalidFile.writeAsString('This is not a PDF document format content');

      final service = PdfService();
      expect(
        () async => await service.mergePdfs([invalidFile.path], customOutputPath: tempDir.path),
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
        () async => await service.mergePdfs(['${tempDir.path}/does_not_exist.pdf'], customOutputPath: tempDir.path),
        throwsA(isA<Exception>()),
      );
    });

    test('Test 8 — Preserves page rotation when merging rotated pages', () async {
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

      final loadedDoc = syncfusion.PdfDocument(inputBytes: await File(mergedPath).readAsBytes());
      expect(loadedDoc.pages.count, equals(2));
      expect(loadedDoc.pages[0].rotation, equals(syncfusion.PdfPageRotateAngle.rotateAngle0));
      expect(loadedDoc.pages[1].rotation, equals(syncfusion.PdfPageRotateAngle.rotateAngle90));
      loadedDoc.dispose();
    });

    test('Test 9 — getPdfPageCount returns correct page count', () async {
      final path3Pages = await createTestPdf(filename: 'three_pages.pdf', pageCount: 3, textPrefix: 'ThreePages');
      final service = PdfService();
      final count = await service.getPdfPageCount(path3Pages);
      expect(count, equals(3));
    });
  });
}
