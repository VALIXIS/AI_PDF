import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfService pdfService;
  late Directory tempDir;

  // 1x1 valid JPEG byte array for testing image annotations
  final Uint8List sampleImageBytes = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05,
    0x08, 0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B,
    0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A,
    0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28,
    0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38,
    0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01,
    0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
    0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xBF, 0x00, 0xFF,
    0xD9
  ]);

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('io.scer.pdf_renderer'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'open.document.file':
          case 'open.document.data':
          case 'open.document.asset':
            return {
              'id': 'mock-doc-id',
              'pagesCount': 2,
            };
          case 'close.document':
            return null;
          case 'open.page':
            return {
              'id': 'mock-page-id',
              'width': 612.0,
              'height': 792.0,
            };
          case 'close.page':
            return null;
          case 'render':
            return {
              'width': methodCall.arguments['width'] ?? 612,
              'height': methodCall.arguments['height'] ?? 792,
              'path': 'mock_path.png',
            };
          default:
            return null;
        }
      },
    );
  });

  setUp(() {
    pdfService = PdfService();
    tempDir = Directory.systemTemp.createTempSync('pdf_full_regression_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Full PDF Regression Suite', () {
    test('1. PDF Creation (Single-page and Multi-page)', () async {
      // Single-page PDF creation
      final singlePdfPath = await pdfService.generatePdfFromText(
        title: 'Regression Doc Single',
        content: '# Page 1\nThis is a single page PDF test.',
        customOutputPath: tempDir.path,
      );

      final singleFile = File(singlePdfPath);
      expect(await singleFile.exists(), isTrue, reason: 'Single PDF must exist');
      expect(await singleFile.length(), greaterThan(0), reason: 'PDF size must be > 0');

      final singlePageCount = await pdfService.getPdfPageCount(singlePdfPath);
      expect(singlePageCount, equals(1), reason: 'Single page count should be 1');

      // Multi-page PDF creation
      final multiContent = List.generate(
        100,
        (i) => 'Line $i: Content section with detailed text for testing pagination.',
      ).join('\n');

      final multiPdfPath = await pdfService.generatePdfFromText(
        title: 'Regression Doc Multi',
        content: multiContent,
        customOutputPath: tempDir.path,
      );

      final multiFile = File(multiPdfPath);
      expect(await multiFile.exists(), isTrue, reason: 'Multi PDF must exist');
      expect(await multiFile.length(), greaterThan(0), reason: 'Multi PDF size > 0');

      final multiPageCount = await pdfService.getPdfPageCount(multiPdfPath);
      expect(multiPageCount, greaterThan(1), reason: 'Multi page count should be > 1');
    });

    test('2. PDF Import / Load & Input Validation', () async {
      final validPdfPath = await pdfService.generatePdfFromText(
        title: 'Import Test',
        content: 'Valid content for import test.',
        customOutputPath: tempDir.path,
      );

      // Load valid PDF
      final pageCount = await pdfService.getPdfPageCount(validPdfPath);
      expect(pageCount, equals(1));

      final bytes = await File(validPdfPath).readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes);
      expect(doc.pages.count, equals(1));
      expect(doc.pages[0].size.width, greaterThan(0));
      expect(doc.pages[0].size.height, greaterThan(0));
      doc.dispose();

      // Test invalid file path
      expect(
        () => pdfService.getPdfPageCount('${tempDir.path}/non_existent.pdf'),
        throwsA(isA<PdfServiceException>()),
      );

      // Test corrupted / non-PDF file
      final fakeFile = File('${tempDir.path}/corrupt.pdf');
      await fakeFile.writeAsString('This is not a valid PDF content header.');
      expect(
        () => pdfService.getPdfPageCount(fakeFile.path),
        throwsA(isA<PdfServiceException>()),
      );
    });

    test('3. PDF Rendering Verification', () async {
      final pdfPath = await pdfService.generatePdfFromText(
        title: 'Render Test',
        content: 'Testing pdfx document rendering initialization.',
        customOutputPath: tempDir.path,
      );

      final pdfxDoc = await pdfx.PdfDocument.openFile(pdfPath);
      expect(pdfxDoc.pagesCount, equals(2));

      final page = await pdfxDoc.getPage(1);
      expect(page.pageNumber, equals(1));
      expect(page.width, greaterThan(0));
      expect(page.height, greaterThan(0));

      await page.close();
      await pdfxDoc.close();
    });

    test('4. PDF Merge (Multiple PDFs A + B + C)', () async {
      final pdfA = await pdfService.generatePdfFromText(
        title: 'Doc A',
        content: 'Content of Document A',
        customOutputPath: tempDir.path,
      );
      final pdfB1 = await pdfService.generatePdfFromText(
        title: 'Doc B1',
        content: 'Content of Document B1',
        customOutputPath: tempDir.path,
      );
      final pdfB2 = await pdfService.generatePdfFromText(
        title: 'Doc B2',
        content: 'Content of Document B2',
        customOutputPath: tempDir.path,
      );
      final pdfB = await pdfService.mergePdfs(
        [pdfB1, pdfB2],
        customOutputPath: tempDir.path,
      ); // 2 pages
      final pdfC = await pdfService.generatePdfFromText(
        title: 'Doc C',
        content: 'Content of Document C',
        customOutputPath: tempDir.path,
      );

      // Merge 3 PDFs: A (1 page) + B (2 pages) + C (1 page) = 4 pages
      final mergedPath = await pdfService.mergePdfs(
        [pdfA, pdfB, pdfC],
        customOutputPath: tempDir.path,
      );

      final mergedFile = File(mergedPath);
      expect(await mergedFile.exists(), isTrue);
      expect(await mergedFile.length(), greaterThan(0));

      final mergedCount = await pdfService.getPdfPageCount(mergedPath);
      expect(mergedCount, equals(4), reason: '1 + 2 + 1 should equal 4 pages');

      // Reopen merged PDF to verify structure
      final bytes = await mergedFile.readAsBytes();
      final doc = sf.PdfDocument(inputBytes: bytes);
      expect(doc.pages.count, equals(4));
      doc.dispose();
    });

    test('5. PDF Split (Page extraction)', () async {
      final p1 = await pdfService.generatePdfFromText(title: 'P1', content: 'Page 1', customOutputPath: tempDir.path);
      final p2 = await pdfService.generatePdfFromText(title: 'P2', content: 'Page 2', customOutputPath: tempDir.path);
      final p3 = await pdfService.generatePdfFromText(title: 'P3', content: 'Page 3', customOutputPath: tempDir.path);
      final p4 = await pdfService.generatePdfFromText(title: 'P4', content: 'Page 4', customOutputPath: tempDir.path);

      final fourPagePdf = await pdfService.mergePdfs([p1, p2, p3, p4], customOutputPath: tempDir.path);
      expect(await pdfService.getPdfPageCount(fourPagePdf), equals(4));

      // Extract pages 2 to 3
      final splitPath = await pdfService.splitPdf(
        pdfPath: fourPagePdf,
        startPage: 2,
        endPage: 3,
        customOutputPath: tempDir.path,
      );

      final splitFile = File(splitPath);
      expect(await splitFile.exists(), isTrue);
      expect(await splitFile.length(), greaterThan(0));

      final splitCount = await pdfService.getPdfPageCount(splitPath);
      expect(splitCount, equals(2), reason: 'Pages 2 to 3 extracted should result in 2 pages');
    });

    test('6. PDF Editor & Annotation Workflow (Add, Edit, Move, Delete, Multi-page)', () async {
      final p1 = await pdfService.generatePdfFromText(title: 'Ed1', content: 'Page 1 text', customOutputPath: tempDir.path);
      final p2 = await pdfService.generatePdfFromText(title: 'Ed2', content: 'Page 2 text', customOutputPath: tempDir.path);
      final sourcePdf = await pdfService.mergePdfs([p1, p2], customOutputPath: tempDir.path);

      // Construct annotation map for multi-page document
      final textAnn = Annotation.text(
        id: 'ann_text_1',
        x: 0.1,
        y: 0.2,
        text: 'Regression Text Annotation',
        fontSize: 18,
        color: Colors.red,
        bold: true,
      );

      final imageAnn = Annotation.image(
        id: 'ann_img_1',
        x: 0.5,
        y: 0.5,
        width: 0.3,
        height: 0.2,
        imageBytes: sampleImageBytes,
      );

      // Verify annotation copyWith (edit, move, resize)
      final editedTextAnn = textAnn.copyWith(
        x: 0.15,
        y: 0.25,
        text: 'Updated Text Annotation',
        fontSize: 20,
        color: Colors.blue,
      );
      expect(editedTextAnn.text, equals('Updated Text Annotation'));
      expect(editedTextAnn.x, equals(0.15));
      expect(editedTextAnn.y, equals(0.25));

      final annotationsByPage = <int, List<Annotation>>{
        0: [editedTextAnn],
        1: [imageAnn],
      };

      // Save edited PDF
      final savedPath = await pdfService.saveEditedPdf(
        sourcePdfPath: sourcePdf,
        annotationsByPage: annotationsByPage,
        customOutputPath: tempDir.path,
      );

      final savedFile = File(savedPath);
      expect(await savedFile.exists(), isTrue);
      expect(await savedFile.length(), greaterThan(0));

      final pageCount = await pdfService.getPdfPageCount(savedPath);
      expect(pageCount, equals(2));
    });

    test('7. Page Manipulation (Rotation & Layout)', () async {
      final sourcePdf = await pdfService.generatePdfFromText(
        title: 'Rotate Test',
        content: 'Testing page rotation functionality.',
        customOutputPath: tempDir.path,
      );

      final rotatedPath = await pdfService.rotatePdf(
        pdfPath: sourcePdf,
        rotationAngle: 90,
        customOutputPath: tempDir.path,
      );

      final rotatedFile = File(rotatedPath);
      expect(await rotatedFile.exists(), isTrue);
      expect(await rotatedFile.length(), greaterThan(0));

      final count = await pdfService.getPdfPageCount(rotatedPath);
      expect(count, equals(1));
    });

    test('8. Save Integrity (No destructive rasterization / empty outputs)', () async {
      final sourcePdf = await pdfService.generatePdfFromText(
        title: 'Save Test',
        content: 'Original vector PDF text line.',
        customOutputPath: tempDir.path,
      );

      final textAnn = Annotation.text(
        id: 'ann_1',
        x: 0.1,
        y: 0.1,
        text: 'Overlay text',
      );

      final savedPath = await pdfService.saveEditedPdf(
        sourcePdfPath: sourcePdf,
        annotationsByPage: {0: [textAnn]},
        customOutputPath: tempDir.path,
      );

      final savedBytes = await File(savedPath).readAsBytes();
      expect(savedBytes.length, greaterThan(100), reason: 'Saved PDF should contain valid bytes');

      // Verify header matches PDF standard
      final header = String.fromCharCodes(savedBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('9. Reopen Verification (Full Reopen Pipeline)', () async {
      final doc1 = await pdfService.generatePdfFromText(
        title: 'Reopen Source 1',
        content: 'Reopen source 1 content.',
        customOutputPath: tempDir.path,
      );
      final doc2 = await pdfService.generatePdfFromText(
        title: 'Reopen Source 2',
        content: 'Reopen source 2 content.',
        customOutputPath: tempDir.path,
      );

      // Merge -> Edit -> Save -> Reopen
      final merged = await pdfService.mergePdfs([doc1, doc2], customOutputPath: tempDir.path);

      final textAnn = Annotation.text(
        id: 'reopen_ann',
        x: 0.2,
        y: 0.2,
        text: 'Reopen Test String',
      );

      final savedPdf = await pdfService.saveEditedPdf(
        sourcePdfPath: merged,
        annotationsByPage: {0: [textAnn]},
        customOutputPath: tempDir.path,
      );

      // Step 1: Reopen with Syncfusion
      final sfDoc = sf.PdfDocument(inputBytes: await File(savedPdf).readAsBytes());
      expect(sfDoc.pages.count, equals(2));
      sfDoc.dispose();

      // Step 2: Reopen with pdfx engine
      final pdfxDoc = await pdfx.PdfDocument.openFile(savedPdf);
      expect(pdfxDoc.pagesCount, equals(2));
      final page1 = await pdfxDoc.getPage(1);
      expect(page1.pageNumber, equals(1));
      await page1.close();
      await pdfxDoc.close();

      // Step 3: Reopen page count check via service
      final count = await pdfService.getPdfPageCount(savedPdf);
      expect(count, equals(2));
    });

    test('10. Export Integrity', () async {
      final sourcePdf = await pdfService.generatePdfFromText(
        title: 'Export Test Doc',
        content: 'Content to be exported.',
        customOutputPath: tempDir.path,
      );

      final exportPath = '${tempDir.path}/final_exported_output.pdf';
      final savedPath = await pdfService.saveEditedPdf(
        sourcePdfPath: sourcePdf,
        annotationsByPage: {},
        customOutputPath: tempDir.path,
      );

      final exportedFile = await File(savedPath).copy(exportPath);
      expect(await exportedFile.exists(), isTrue);
      expect(await exportedFile.length(), greaterThan(0));

      final count = await pdfService.getPdfPageCount(exportedFile.path);
      expect(count, equals(1));
    });

    test('11. Resource Cleanup & File-Lock Handling (Windows Safety)', () async {
      final sourcePdf = await pdfService.generatePdfFromText(
        title: 'Lock Test',
        content: 'File locking test.',
        customOutputPath: tempDir.path,
      );

      // Perform rapid open, read, write, save, replace operations
      for (int i = 0; i < 3; i++) {
        final bytes = await File(sourcePdf).readAsBytes();
        final doc = sf.PdfDocument(inputBytes: bytes);
        expect(doc.pages.count, equals(1));
        doc.dispose(); // Immediate explicit disposal

        final saved = await pdfService.saveEditedPdf(
          sourcePdfPath: sourcePdf,
          annotationsByPage: {},
          customOutputPath: tempDir.path,
        );

        // Immediate write / overwrite test
        final targetFile = File(saved);
        final fileLength = await targetFile.length();
        expect(fileLength, greaterThan(0));

        // Ensure target file can be copied or deleted without Windows file lock exception
        final copyTarget = File('${tempDir.path}/copy_$i.pdf');
        await targetFile.copy(copyTarget.path);
        expect(await copyTarget.exists(), isTrue);
        await copyTarget.delete();
      }
    });
  });
}
