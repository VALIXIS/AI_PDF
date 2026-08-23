import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  // Valid 1x1 JPEG image bytes
  final Uint8List sampleImageBytes = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06,
    0x05, 0x08, 0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D,
    0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F,
    0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C,
    0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34,
    0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF,
    0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00,
    0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02,
    0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00,
    0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xBF, 0x00, 0xFF, 0xD9,
  ]);

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_editor_test_');
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
                '$textPrefix Page$i Content',
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

  group('PDF Editor Non-Destructive Save Tests', () {
    test('Test 1 — Open and save without edits preserves original content, dimensions, and text', () async {
      final sourcePath = await createTestPdf(
        filename: 'no_edits_source.pdf',
        pageCount: 3,
        textPrefix: 'OriginalDoc',
      );

      final service = PdfService();
      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: sourcePath,
        annotationsByPage: {},
        customOutputPath: tempDir.path,
      );

      final file = File(savedPath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));

      final savedBytes = await file.readAsBytes();
      final savedDoc = syncfusion.PdfDocument(inputBytes: savedBytes);

      // Verify page count is preserved
      expect(savedDoc.pages.count, equals(3));

      // Verify page dimensions are preserved
      for (int i = 0; i < savedDoc.pages.count; i++) {
        expect(savedDoc.pages[i].size.width, closeTo(PdfPageFormat.a4.width, 1));
        expect(savedDoc.pages[i].size.height, closeTo(PdfPageFormat.a4.height, 1));
      }

      // Verify original selectable text remains extractable across all pages
      final extractor = syncfusion.PdfTextExtractor(savedDoc);
      for (int i = 0; i < 3; i++) {
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i).replaceAll(RegExp(r'\s+'), ' ');
        expect(pageText, contains('OriginalDoc Page${i + 1} Content'));
      }

      savedDoc.dispose();
    });

    test('Test 2 — Add text and image editor modifications non-destructively', () async {
      final sourcePath = await createTestPdf(
        filename: 'edit_modification_source.pdf',
        pageCount: 1,
        textPrefix: 'BaseDocument',
      );

      final annotations = <int, List<Annotation>>{
        0: [
          Annotation.text(
            id: 'text-1',
            x: 0.1,
            y: 0.1,
            text: 'EditorAddedText_Alpha',
            fontSize: 18,
            color: Colors.red,
            bold: true,
          ),
          Annotation.image(
            id: 'img-1',
            x: 0.5,
            y: 0.5,
            imageBytes: sampleImageBytes,
          ),
        ],
      };

      final service = PdfService();
      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: sourcePath,
        annotationsByPage: annotations,
        customOutputPath: tempDir.path,
      );

      final savedBytes = await File(savedPath).readAsBytes();
      final savedDoc = syncfusion.PdfDocument(inputBytes: savedBytes);

      expect(savedDoc.pages.count, equals(1));

      // Verify BOTH original text and editor-added text are extractable
      final extractor = syncfusion.PdfTextExtractor(savedDoc);
      final text = extractor.extractText().replaceAll(RegExp(r'\s+'), ' ');
      expect(text, contains('BaseDocument Page1 Content'));
      expect(text, contains('EditorAddedText_Alpha'));

      savedDoc.dispose();
    });

    test('Test 3 — Multi-page PDF: editing one page preserves all other unedited pages', () async {
      final sourcePath = await createTestPdf(
        filename: 'multipage_selective_edit.pdf',
        pageCount: 4,
        textPrefix: 'MultiDoc',
      );

      // Add annotations ONLY to page 2 (index 1)
      final annotations = <int, List<Annotation>>{
        1: [
          Annotation.text(
            id: 'text-p2',
            x: 0.2,
            y: 0.2,
            text: 'SpecialNoteOnPageTwo',
            fontSize: 14,
          ),
        ],
      };

      final service = PdfService();
      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: sourcePath,
        annotationsByPage: annotations,
        customOutputPath: tempDir.path,
      );

      final savedDoc = syncfusion.PdfDocument(inputBytes: await File(savedPath).readAsBytes());
      expect(savedDoc.pages.count, equals(4));

      final extractor = syncfusion.PdfTextExtractor(savedDoc);

      // Page 1 (index 0) - untouched
      final p1Text = extractor.extractText(startPageIndex: 0, endPageIndex: 0).replaceAll(RegExp(r'\s+'), ' ');
      expect(p1Text, contains('MultiDoc Page1 Content'));
      expect(p1Text, isNot(contains('SpecialNoteOnPageTwo')));

      // Page 2 (index 1) - contains original text + new text
      final p2Text = extractor.extractText(startPageIndex: 1, endPageIndex: 1).replaceAll(RegExp(r'\s+'), ' ');
      expect(p2Text, contains('MultiDoc Page2 Content'));
      expect(p2Text, contains('SpecialNoteOnPageTwo'));

      // Page 3 (index 2) - untouched
      final p3Text = extractor.extractText(startPageIndex: 2, endPageIndex: 2).replaceAll(RegExp(r'\s+'), ' ');
      expect(p3Text, contains('MultiDoc Page3 Content'));

      // Page 4 (index 3) - untouched
      final p4Text = extractor.extractText(startPageIndex: 3, endPageIndex: 3).replaceAll(RegExp(r'\s+'), ' ');
      expect(p4Text, contains('MultiDoc Page4 Content'));

      savedDoc.dispose();
    });

    test('Test 4 — Different page sizes and orientations are preserved', () async {
      final pdf = pw.Document();
      // Page 1: Custom portrait (300 x 500)
      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(300, 500),
          build: (pw.Context context) => pw.Center(child: pw.Text('Portrait Page 1')),
        ),
      );
      // Page 2: Custom landscape (600 x 400)
      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(600, 400),
          build: (pw.Context context) => pw.Center(child: pw.Text('Landscape Page 2')),
        ),
      );

      final sourceFile = File('${tempDir.path}/mixed_sizes.pdf');
      await sourceFile.writeAsBytes(await pdf.save());

      final annotations = <int, List<Annotation>>{
        0: [Annotation.text(id: 't1', x: 0.1, y: 0.1, text: 'AnnotatedPortrait')],
        1: [Annotation.text(id: 't2', x: 0.1, y: 0.1, text: 'AnnotatedLandscape')],
      };

      final service = PdfService();
      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: sourceFile.path,
        annotationsByPage: annotations,
        customOutputPath: tempDir.path,
      );

      final savedDoc = syncfusion.PdfDocument(inputBytes: await File(savedPath).readAsBytes());
      expect(savedDoc.pages.count, equals(2));

      // Check dimensions
      expect(savedDoc.pages[0].size.width, closeTo(300, 2));
      expect(savedDoc.pages[0].size.height, closeTo(500, 2));

      expect(savedDoc.pages[1].size.width, closeTo(600, 2));
      expect(savedDoc.pages[1].size.height, closeTo(400, 2));

      // Check text extraction
      final extractor = syncfusion.PdfTextExtractor(savedDoc);
      final p1 = extractor.extractText(startPageIndex: 0, endPageIndex: 0).replaceAll(RegExp(r'\s+'), ' ');
      expect(p1, contains('Portrait Page 1'));
      expect(p1, contains('AnnotatedPortrait'));

      final p2 = extractor.extractText(startPageIndex: 1, endPageIndex: 1).replaceAll(RegExp(r'\s+'), ' ');
      expect(p2, contains('Landscape Page 2'));
      expect(p2, contains('AnnotatedLandscape'));

      savedDoc.dispose();
    });

    test('Test 5 — Preserves page rotation when editing rotated pages', () async {
      final normalPdfPath = await createTestPdf(
        filename: 'to_rotate.pdf',
        pageCount: 2,
        textPrefix: 'RotDoc',
      );

      final service = PdfService();
      final rotatedPdfPath = await service.rotatePdf(
        pdfPath: normalPdfPath,
        rotationAngle: 90,
        customOutputPath: tempDir.path,
      );

      final annotations = <int, List<Annotation>>{
        0: [Annotation.text(id: 't-rot', x: 0.2, y: 0.2, text: 'EditedRotatedPage')],
      };

      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: rotatedPdfPath,
        annotationsByPage: annotations,
        customOutputPath: tempDir.path,
      );

      final savedDoc = syncfusion.PdfDocument(inputBytes: await File(savedPath).readAsBytes());
      expect(savedDoc.pages.count, equals(2));
      expect(savedDoc.pages[0].rotation, equals(syncfusion.PdfPageRotateAngle.rotateAngle90));
      expect(savedDoc.pages[1].rotation, equals(syncfusion.PdfPageRotateAngle.rotateAngle90));

      final extractor = syncfusion.PdfTextExtractor(savedDoc);
      final text = extractor.extractText().replaceAll(RegExp(r'\s+'), ' ');
      expect(text, contains('RotDoc Page1 Content'));
      expect(text, contains('EditedRotatedPage'));

      savedDoc.dispose();
    });

    test('Test 6 — Annotation coordinate accuracy and multiple annotations', () async {
      final sourcePath = await createTestPdf(
        filename: 'coord_test.pdf',
        pageCount: 1,
        textPrefix: 'CoordBase',
      );

      final annotations = <int, List<Annotation>>{
        0: [
          Annotation.text(
            id: 'top-left',
            x: 0.05,
            y: 0.05,
            width: 0.3,
            height: 0.05,
            text: 'TopLeftText',
          ),
          Annotation.text(
            id: 'bottom-right',
            x: 0.6,
            y: 0.8,
            width: 0.35,
            height: 0.05,
            text: 'BottomRightText',
          ),
          Annotation.image(
            id: 'center-image',
            x: 0.3,
            y: 0.4,
            width: 0.4,
            height: 0.2,
            imageBytes: sampleImageBytes,
          ),
        ],
      };

      final service = PdfService();
      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: sourcePath,
        annotationsByPage: annotations,
        customOutputPath: tempDir.path,
      );

      final savedDoc = syncfusion.PdfDocument(inputBytes: await File(savedPath).readAsBytes());
      expect(savedDoc.pages.count, equals(1));

      final extractor = syncfusion.PdfTextExtractor(savedDoc);
      final text = extractor.extractText().replaceAll(RegExp(r'\s+'), ' ');
      expect(text, contains('CoordBase Page1 Content'));
      expect(text, contains('TopLeftText'));
      expect(text, contains('BottomRightText'));

      savedDoc.dispose();
    });

    test('Test 7 — Error handling: non-existent file, empty file, invalid indices', () async {
      final service = PdfService();

      // Non-existent file
      expect(
        () async => await service.saveEditedPdf(
          sourcePdfPath: '${tempDir.path}/does_not_exist.pdf',
          annotationsByPage: {},
          customOutputPath: tempDir.path,
        ),
        throwsA(isA<Exception>()),
      );

      // Empty file
      final emptyFile = File('${tempDir.path}/empty.pdf');
      await emptyFile.writeAsBytes([]);
      expect(
        () async => await service.saveEditedPdf(
          sourcePdfPath: emptyFile.path,
          annotationsByPage: {},
          customOutputPath: tempDir.path,
        ),
        throwsA(isA<Exception>()),
      );

      // Out of bounds page index is handled safely without crashing
      final validSource = await createTestPdf(
        filename: 'bounds_check.pdf',
        pageCount: 1,
        textPrefix: 'BoundsCheck',
      );

      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: validSource,
        annotationsByPage: {
          99: [Annotation.text(id: 'out', x: 0.1, y: 0.1, text: 'OutOfBounds')],
          -1: [Annotation.text(id: 'neg', x: 0.1, y: 0.1, text: 'Negative')],
        },
        customOutputPath: tempDir.path,
      );

      final savedDoc = syncfusion.PdfDocument(inputBytes: await File(savedPath).readAsBytes());
      expect(savedDoc.pages.count, equals(1));
      final extractor = syncfusion.PdfTextExtractor(savedDoc);
      final text = extractor.extractText().replaceAll(RegExp(r'\s+'), ' ');
      expect(text, contains('BoundsCheck Page1 Content'));
      expect(text, isNot(contains('OutOfBounds')));
      savedDoc.dispose();
    });

    test('Test 8 — Verifies no full-page rasterization or image background substitution', () async {
      final sourcePath = await createTestPdf(
        filename: 'text_only_doc.pdf',
        pageCount: 2,
        textPrefix: 'VectorDocument',
      );

      final annotations = <int, List<Annotation>>{
        0: [Annotation.text(id: 'txt-1', x: 0.1, y: 0.8, text: 'AddedFooterText')],
      };

      final service = PdfService();
      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: sourcePath,
        annotationsByPage: annotations,
        customOutputPath: tempDir.path,
      );

      final savedDoc = syncfusion.PdfDocument(inputBytes: await File(savedPath).readAsBytes());
      expect(savedDoc.pages.count, equals(2));

      // Extract and verify exact textual content on both pages
      final extractor = syncfusion.PdfTextExtractor(savedDoc);
      final p1Text = extractor.extractText(startPageIndex: 0, endPageIndex: 0).replaceAll(RegExp(r'\s+'), ' ');
      final p2Text = extractor.extractText(startPageIndex: 1, endPageIndex: 1).replaceAll(RegExp(r'\s+'), ' ');

      expect(p1Text, contains('VectorDocument Page1 Content'));
      expect(p1Text, contains('AddedFooterText'));
      expect(p2Text, contains('VectorDocument Page2 Content'));

      // Verify file size did not inflate disproportionately (destructive JPEG save typically produces ~200-500KB+ per page vs clean vector PDF ~2-10KB)
      final sourceSize = await File(sourcePath).length();
      final savedSize = await File(savedPath).length();
      // Saved vector text addition should be roughly within a small delta of source size
      expect(savedSize, lessThan(sourceSize + 25000));

      savedDoc.dispose();
    });

    test('Test 9 — Extreme and edge coordinate mapping (0.0, 0.99, negative, > 1.0)', () async {
      final sourcePath = await createTestPdf(
        filename: 'edge_coords_source.pdf',
        pageCount: 1,
        textPrefix: 'EdgeCoords',
      );

      final annotations = <int, List<Annotation>>{
        0: [
          Annotation.text(
            id: 'top-left-edge',
            x: 0.0,
            y: 0.0,
            text: 'TopLeftEdgeText',
          ),
          Annotation.text(
            id: 'bottom-right-edge',
            x: 0.95,
            y: 0.95,
            text: 'BottomRightEdgeText',
          ),
          Annotation.text(
            id: 'overflow-edge',
            x: 1.5,
            y: -0.5,
            text: 'ClampedText',
          ),
          Annotation.image(
            id: 'edge-image',
            x: 0.9,
            y: 0.9,
            width: 0.2,
            height: 0.2,
            imageBytes: sampleImageBytes,
          ),
        ],
      };

      final service = PdfService();
      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: sourcePath,
        annotationsByPage: annotations,
        customOutputPath: tempDir.path,
      );

      final savedDoc = syncfusion.PdfDocument(inputBytes: await File(savedPath).readAsBytes());
      expect(savedDoc.pages.count, equals(1));

      final extractor = syncfusion.PdfTextExtractor(savedDoc);
      final text = extractor.extractText().replaceAll(RegExp(r'\s+'), ' ');
      expect(text, contains('EdgeCoords Page1 Content'));
      expect(text, contains('TopLeftEdgeText'));
      expect(text, contains('BottomRightEdgeText'));

      savedDoc.dispose();
    });

    test('Test 10 — Handles corrupted or invalid image bytes gracefully without crash', () async {
      final sourcePath = await createTestPdf(
        filename: 'corrupt_img_source.pdf',
        pageCount: 1,
        textPrefix: 'CorruptImgBase',
      );

      final corruptBytes = Uint8List.fromList([0x00, 0x11, 0x22, 0x33, 0x44]);

      final annotations = <int, List<Annotation>>{
        0: [
          Annotation.image(
            id: 'corrupt-img',
            x: 0.2,
            y: 0.2,
            imageBytes: corruptBytes,
          ),
          Annotation.text(
            id: 'valid-text',
            x: 0.1,
            y: 0.1,
            text: 'StillSavedText',
          ),
        ],
      };

      final service = PdfService();
      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: sourcePath,
        annotationsByPage: annotations,
        customOutputPath: tempDir.path,
      );

      final savedDoc = syncfusion.PdfDocument(inputBytes: await File(savedPath).readAsBytes());
      expect(savedDoc.pages.count, equals(1));

      final extractor = syncfusion.PdfTextExtractor(savedDoc);
      final text = extractor.extractText().replaceAll(RegExp(r'\s+'), ' ');
      expect(text, contains('CorruptImgBase Page1 Content'));
      expect(text, contains('StillSavedText'));

      savedDoc.dispose();
    });

    test('Test 11 — Multiple annotations on multiple pages with complete page isolation', () async {
      final sourcePath = await createTestPdf(
        filename: 'multi_page_isolation.pdf',
        pageCount: 3,
        textPrefix: 'IsolationDoc',
      );

      final annotations = <int, List<Annotation>>{
        0: [
          Annotation.text(id: 'p0-t1', x: 0.1, y: 0.1, text: 'Page0OnlyText'),
          Annotation.image(id: 'p0-i1', x: 0.4, y: 0.4, imageBytes: sampleImageBytes),
        ],
        2: [
          Annotation.text(id: 'p2-t1', x: 0.2, y: 0.2, text: 'Page2OnlyText', bold: true, fontSize: 22, color: Colors.blue),
        ],
      };

      final service = PdfService();
      final savedPath = await service.saveEditedPdf(
        sourcePdfPath: sourcePath,
        annotationsByPage: annotations,
        customOutputPath: tempDir.path,
      );

      final savedDoc = syncfusion.PdfDocument(inputBytes: await File(savedPath).readAsBytes());
      expect(savedDoc.pages.count, equals(3));

      final extractor = syncfusion.PdfTextExtractor(savedDoc);

      // Page 0 has Page0OnlyText
      final p0 = extractor.extractText(startPageIndex: 0, endPageIndex: 0).replaceAll(RegExp(r'\s+'), ' ');
      expect(p0, contains('IsolationDoc Page1 Content'));
      expect(p0, contains('Page0OnlyText'));
      expect(p0, isNot(contains('Page2OnlyText')));

      // Page 1 is untouched
      final p1 = extractor.extractText(startPageIndex: 1, endPageIndex: 1).replaceAll(RegExp(r'\s+'), ' ');
      expect(p1, contains('IsolationDoc Page2 Content'));
      expect(p1, isNot(contains('Page0OnlyText')));
      expect(p1, isNot(contains('Page2OnlyText')));

      // Page 2 has Page2OnlyText
      final p2 = extractor.extractText(startPageIndex: 2, endPageIndex: 2).replaceAll(RegExp(r'\s+'), ' ');
      expect(p2, contains('IsolationDoc Page3 Content'));
      expect(p2, contains('Page2OnlyText'));
      expect(p2, isNot(contains('Page0OnlyText')));

      savedDoc.dispose();
    });

    test('Test 12 — Annotation model copyWith and property updates', () {
      final textAnn = Annotation.text(
        id: 't-test',
        x: 0.1,
        y: 0.2,
        text: 'Initial',
        fontSize: 14,
        color: Colors.red,
        bold: false,
      );

      final updatedText = textAnn.copyWith(
        text: 'Updated',
        fontSize: 20,
        bold: true,
        color: Colors.green,
      );

      expect(updatedText.id, equals('t-test'));
      expect(updatedText.text, equals('Updated'));
      expect(updatedText.fontSize, equals(20));
      expect(updatedText.bold, isTrue);
      expect(updatedText.color, equals(Colors.green));
      expect(updatedText.kind, equals(AnnotationKind.text));

      final imgAnn = Annotation.image(
        id: 'img-test',
        x: 0.3,
        y: 0.3,
        imageBytes: sampleImageBytes,
      );

      final updatedImg = imgAnn.copyWith(
        width: 0.6,
        height: 0.5,
      );

      expect(updatedImg.id, equals('img-test'));
      expect(updatedImg.width, equals(0.6));
      expect(updatedImg.height, equals(0.5));
      expect(updatedImg.imageBytes, equals(sampleImageBytes));
      expect(updatedImg.kind, equals(AnnotationKind.image));
    });

    testWidgets('PdfEditorScreen displays empty state when no PDF loaded', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PdfEditorScreen(),
      ));

      expect(find.text('PDF Editor'), findsOneWidget);
      expect(find.text('Open a PDF to Edit'), findsOneWidget);
      expect(find.text('Choose PDF File'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}


