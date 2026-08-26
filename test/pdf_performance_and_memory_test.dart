import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PdfService pdfService;

  // 1x1 valid sample image bytes
  final Uint8List sampleImageBytes = Uint8List.fromList([
    0xFF,
    0xD8,
    0xFF,
    0xDB,
    0x00,
    0x43,
    0x00,
    0x08,
    0x06,
    0x06,
    0x07,
    0x06,
    0x05,
    0x08,
    0x07,
    0x07,
    0x07,
    0x09,
    0x09,
    0x08,
    0x0A,
    0x0C,
    0x14,
    0x0D,
    0x0C,
    0x0B,
    0x0B,
    0x0C,
    0x19,
    0x12,
    0x13,
    0x0F,
    0x14,
    0x1D,
    0x1A,
    0x1F,
    0x1E,
    0x1D,
    0x1A,
    0x1C,
    0x1C,
    0x20,
    0x24,
    0x2E,
    0x27,
    0x20,
    0x22,
    0x2C,
    0x23,
    0x1C,
    0x1C,
    0x28,
    0x37,
    0x29,
    0x2C,
    0x30,
    0x31,
    0x34,
    0x34,
    0x34,
    0x1F,
    0x27,
    0x39,
    0x3D,
    0x38,
    0x32,
    0x3C,
    0x2E,
    0x33,
    0x34,
    0x32,
    0xFF,
    0xC0,
    0x00,
    0x0B,
    0x08,
    0x00,
    0x01,
    0x00,
    0x01,
    0x01,
    0x01,
    0x11,
    0x00,
    0xFF,
    0xC4,
    0x00,
    0x1F,
    0x00,
    0x00,
    0x01,
    0x05,
    0x01,
    0x01,
    0x01,
    0x01,
    0x01,
    0x01,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x01,
    0x02,
    0x03,
    0x04,
    0x05,
    0x06,
    0x07,
    0x08,
    0x09,
    0x0A,
    0x0B,
    0xFF,
    0xDA,
    0x00,
    0x08,
    0x01,
    0x01,
    0x00,
    0x00,
    0x3F,
    0x00,
    0xBF,
    0x00,
    0xFF,
    0xD9,
  ]);

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_perf_test_');
    pdfService = PdfService();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to generate multi-page PDF documents
  Future<String> createMultiPagePdf({
    required String filename,
    required int pageCount,
    String textPrefix = 'PerfDoc',
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
                '$textPrefix Page $i Content',
                style: const pw.TextStyle(fontSize: 20),
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

  /// Helper to create image-heavy multi-page PDF
  Future<String> createImageHeavyPdf({
    required String filename,
    required int pageCount,
  }) async {
    final pdf = pw.Document();
    final memImg = pw.MemoryImage(sampleImageBytes);

    for (int i = 1; i <= pageCount; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Image Page $i',
                    style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Image(memImg, width: 200, height: 200),
              ],
            );
          },
        ),
      );
    }
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  group('Deterministic Large/Multi-Page Document Processing Tests', () {
    test('1. 1-page PDF processing, rendering, and validation', () async {
      final docPath = await createMultiPagePdf(
        filename: 'doc_1p.pdf',
        pageCount: 1,
        textPrefix: 'OnePage',
      );

      final count = await pdfService.getPdfPageCount(docPath);
      expect(count, equals(1));

      // Test split
      final splitPath = await pdfService.splitPdf(
        pdfPath: docPath,
        startPage: 1,
        endPage: 1,
        customOutputPath: tempDir.path,
      );
      expect(await File(splitPath).exists(), isTrue);
      expect(await pdfService.getPdfPageCount(splitPath), equals(1));
    });

    test('2. 5-page PDF processing and text extraction', () async {
      final docPath = await createMultiPagePdf(
        filename: 'doc_5p.pdf',
        pageCount: 5,
        textPrefix: 'FivePage',
      );

      final count = await pdfService.getPdfPageCount(docPath);
      expect(count, equals(5));

      final txt = (await pdfService.extractPdfText(docPath))
          .replaceAll(RegExp(r'\s+'), ' ');
      for (int i = 1; i <= 5; i++) {
        expect(txt, contains('FivePage Page $i Content'));
      }
    });

    test('3. 10-page PDF split and compression', () async {
      final docPath = await createMultiPagePdf(
        filename: 'doc_10p.pdf',
        pageCount: 10,
        textPrefix: 'TenPage',
      );

      final count = await pdfService.getPdfPageCount(docPath);
      expect(count, equals(10));

      final splitPath = await pdfService.splitPdf(
        pdfPath: docPath,
        startPage: 3,
        endPage: 7,
        customOutputPath: tempDir.path,
      );
      expect(await pdfService.getPdfPageCount(splitPath), equals(5));

      final compressedPath = await pdfService.compressPdf(
        splitPath,
        customOutputPath: tempDir.path,
      );
      expect(await File(compressedPath).exists(), isTrue);
      expect(await pdfService.getPdfPageCount(compressedPath), equals(5));
    });

    test('4. 25+ page PDF large document scaling without corruption', () async {
      final docPath = await createMultiPagePdf(
        filename: 'doc_30p.pdf',
        pageCount: 30,
        textPrefix: 'ThirtyPage',
      );

      final count = await pdfService.getPdfPageCount(docPath);
      expect(count, equals(30));

      // Rotate all 30 pages
      final rotatedPath = await pdfService.rotatePdf(
        pdfPath: docPath,
        rotationAngle: 180,
        customOutputPath: tempDir.path,
      );
      expect(await pdfService.getPdfPageCount(rotatedPath), equals(30));

      // Verify rotation preserved across all pages
      final doc = syncfusion.PdfDocument(
          inputBytes: await File(rotatedPath).readAsBytes());
      try {
        expect(doc.pages.count, equals(30));
        for (int i = 0; i < 30; i++) {
          expect(doc.pages[i].rotation,
              equals(syncfusion.PdfPageRotateAngle.rotateAngle180));
        }
      } finally {
        doc.dispose();
      }
    });

    test('5. Image-heavy multi-page PDF processing', () async {
      final imgHeavyPath = await createImageHeavyPdf(
        filename: 'img_heavy_8p.pdf',
        pageCount: 8,
      );

      final count = await pdfService.getPdfPageCount(imgHeavyPath);
      expect(count, equals(8));

      // Apply watermark to image-heavy document
      final watermarked = await pdfService.watermarkPdf(
        pdfPath: imgHeavyPath,
        watermarkText: 'TOP SECRET',
        opacity: 0.4,
        angle: 45,
        color: Colors.blue,
        customOutputPath: tempDir.path,
      );

      expect(await File(watermarked).exists(), isTrue);
      expect(await pdfService.getPdfPageCount(watermarked), equals(8));
    });

    test('6. Multi-document Merge with sequential source disposal', () async {
      final doc1 = await createMultiPagePdf(
          filename: 'merge_p1.pdf', pageCount: 4, textPrefix: 'DocA');
      final doc2 = await createMultiPagePdf(
          filename: 'merge_p2.pdf', pageCount: 6, textPrefix: 'DocB');
      final doc3 = await createMultiPagePdf(
          filename: 'merge_p3.pdf', pageCount: 5, textPrefix: 'DocC');

      final mergedPath = await pdfService.mergePdfs(
        [doc1, doc2, doc3],
        customOutputPath: tempDir.path,
      );

      expect(await File(mergedPath).exists(), isTrue);
      expect(await pdfService.getPdfPageCount(mergedPath), equals(15));

      final txt = (await pdfService.extractPdfText(mergedPath))
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(txt, contains('DocA Page 1 Content'));
      expect(txt, contains('DocB Page 6 Content'));
      expect(txt, contains('DocC Page 5 Content'));
    });

    test('7. Multi-page Split preserving exact page sequence', () async {
      final source = await createMultiPagePdf(
          filename: 'split_source_12p.pdf', pageCount: 12, textPrefix: 'Seq');

      final splitPath = await pdfService.splitPdf(
        pdfPath: source,
        startPage: 4,
        endPage: 8,
        customOutputPath: tempDir.path,
      );

      expect(await pdfService.getPdfPageCount(splitPath), equals(5));
      final txt = (await pdfService.extractPdfText(splitPath))
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(txt, contains('Seq Page 4 Content'));
      expect(txt, contains('Seq Page 8 Content'));
      expect(txt, isNot(contains('Seq Page 3 Content')));
      expect(txt, isNot(contains('Seq Page 9 Content')));
    });

    test('8. Multi-page Editor save with multi-page annotation isolation',
        () async {
      final source = await createMultiPagePdf(
          filename: 'editor_multi_6p.pdf', pageCount: 6, textPrefix: 'EditSeq');

      final annotations = <int, List<Annotation>>{
        0: [Annotation.text(id: 'a0', x: 0.1, y: 0.1, text: 'Annot_P1')],
        2: [Annotation.text(id: 'a2', x: 0.2, y: 0.2, text: 'Annot_P3')],
        5: [
          Annotation.text(id: 'a5', x: 0.3, y: 0.3, text: 'Annot_P6'),
          Annotation.image(
              id: 'i5', x: 0.5, y: 0.5, imageBytes: sampleImageBytes),
        ],
      };

      final savedPath = await pdfService.saveEditedPdf(
        sourcePdfPath: source,
        annotationsByPage: annotations,
        customOutputPath: tempDir.path,
      );

      final doc = syncfusion.PdfDocument(
          inputBytes: await File(savedPath).readAsBytes());
      try {
        expect(doc.pages.count, equals(6));
        final extractor = syncfusion.PdfTextExtractor(doc);

        final p1 = extractor
            .extractText(startPageIndex: 0, endPageIndex: 0)
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(p1, contains('Annot_P1'));
        expect(p1, isNot(contains('Annot_P3')));

        final p2 = extractor
            .extractText(startPageIndex: 1, endPageIndex: 1)
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(p2, contains('EditSeq Page 2 Content'));
        expect(p2, isNot(contains('Annot_P1')));
        expect(p2, isNot(contains('Annot_P3')));

        final p3 = extractor
            .extractText(startPageIndex: 2, endPageIndex: 2)
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(p3, contains('Annot_P3'));

        final p6 = extractor
            .extractText(startPageIndex: 5, endPageIndex: 5)
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(p6, contains('Annot_P6'));
      } finally {
        doc.dispose();
      }
    });

    test('9. Save -> Dispose -> Reopen lifecycle verification', () async {
      final source = await createMultiPagePdf(
          filename: 'lifecycle_test.pdf', pageCount: 3, textPrefix: 'Life');

      final savedPath = await pdfService.saveEditedPdf(
        sourcePdfPath: source,
        annotationsByPage: {
          1: [
            Annotation.text(
                id: 'mid', x: 0.1, y: 0.1, text: 'MidPageAnnotation')
          ]
        },
        customOutputPath: tempDir.path,
      );

      // Verify file is fully unlocked and readable
      final reopenedDoc = syncfusion.PdfDocument(
          inputBytes: await File(savedPath).readAsBytes());
      expect(reopenedDoc.pages.count, equals(3));
      reopenedDoc.dispose();

      // Perform a subsequent operation on the saved output
      final reRotated = await pdfService.rotatePdf(
        pdfPath: savedPath,
        rotationAngle: 90,
        customOutputPath: tempDir.path,
      );

      expect(await File(reRotated).exists(), isTrue);
      expect(await pdfService.getPdfPageCount(reRotated), equals(3));
    });

    test('10. PDF-to-image error handling on corrupt or empty files', () async {
      final emptyFile = File('${tempDir.path}/empty_test.pdf');
      await emptyFile.writeAsBytes([]);

      expect(
        () => pdfService.convertPdfToImages(pdfPath: emptyFile.path),
        throwsA(isA<PdfServiceException>()),
      );

      final corruptFile = File('${tempDir.path}/corrupt_test.pdf');
      await corruptFile.writeAsString('not a pdf header');

      expect(
        () => pdfService.convertPdfToImages(pdfPath: corruptFile.path),
        throwsA(isA<PdfServiceException>()),
      );
    });
  });
}
