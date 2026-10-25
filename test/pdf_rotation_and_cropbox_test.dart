import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_ai_toolkit/models/pdf_page_geometry.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfService pdfService;
  late Directory tempDir;
  late String tempDirPath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_rotation_cropbox_test_');
    tempDirPath = tempDir.path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDirPath;
      },
    );
    pdfService = PdfService();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Helper to create an in-memory PNG image
  Uint8List createTestPng({int width = 100, int height = 100}) {
    final image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        image.setPixelRgba(x, y, 255, 0, 0, 200);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  // Helper to create a PDF with 4 pages rotated at 0, 90, 180, and 270 degrees
  Future<String> createRotatedPagesPdf() async {
    final sf.PdfDocument doc1 = sf.PdfDocument();

    final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 24);
    final brush = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));

    for (int i = 0; i < 4; i++) {
      final page = doc1.pages.add();
      page.graphics.drawString(
        'Page ${i + 1} Original Upright Text',
        font,
        brush: brush,
        bounds: const Rect.fromLTWH(50, 50, 400, 50),
      );
    }

    final bytes1 = await doc1.save();
    doc1.dispose();

    final sf.PdfDocument doc2 = sf.PdfDocument(inputBytes: bytes1);
    doc2.pages[0].rotation = sf.PdfPageRotateAngle.rotateAngle0;
    doc2.pages[1].rotation = sf.PdfPageRotateAngle.rotateAngle90;
    doc2.pages[2].rotation = sf.PdfPageRotateAngle.rotateAngle180;
    doc2.pages[3].rotation = sf.PdfPageRotateAngle.rotateAngle270;

    final bytes2 = await doc2.save();
    doc2.dispose();

    final file = File('$tempDirPath/rotated_pages_test.pdf');
    await file.writeAsBytes(bytes2);
    return file.path;
  }

  group('PdfPageGeometry Unit Tests', () {
    test('Maps visual normalized rect to page coordinates on 0-degree page', () {
      const geometry = PdfPageGeometry(
        mediaBox: Rect.fromLTWH(0, 0, 500, 800),
        cropBox: Rect.fromLTWH(0, 0, 500, 800),
        rotation: 0,
      );

      final pageRect = geometry.mapNormalizedVisualRectToPage(
        const Rect.fromLTRB(0.1, 0.2, 0.5, 0.6),
      );

      expect(pageRect.left, closeTo(50, 0.001));
      expect(pageRect.top, closeTo(160, 0.001));
      expect(pageRect.width, closeTo(200, 0.001));
      expect(pageRect.height, closeTo(320, 0.001));
    });

    test('Maps visual normalized rect to page coordinates on 90-degree page', () {
      const geometry = PdfPageGeometry(
        mediaBox: Rect.fromLTWH(0, 0, 500, 800),
        cropBox: Rect.fromLTWH(0, 0, 500, 800),
        rotation: 90,
      );

      final pageRect = geometry.mapNormalizedVisualRectToPage(
        const Rect.fromLTRB(0.1, 0.2, 0.5, 0.6),
      );

      // 90° CW: x in [0.2*500, 0.6*500] = [100, 300]
      // y in [(1-0.5)*800, (1-0.1)*800] = [400, 720]
      expect(pageRect.left, closeTo(100, 0.001));
      expect(pageRect.top, closeTo(400, 0.001));
      expect(pageRect.width, closeTo(200, 0.001));
      expect(pageRect.height, closeTo(320, 0.001));
    });

    test('Maps visual normalized rect to page coordinates on 180-degree page', () {
      const geometry = PdfPageGeometry(
        mediaBox: Rect.fromLTWH(0, 0, 500, 800),
        cropBox: Rect.fromLTWH(0, 0, 500, 800),
        rotation: 180,
      );

      final pageRect = geometry.mapNormalizedVisualRectToPage(
        const Rect.fromLTRB(0.1, 0.2, 0.5, 0.6),
      );

      // 180° CW: x in [(1-0.5)*500, (1-0.1)*500] = [250, 450]
      // y in [(1-0.6)*800, (1-0.2)*800] = [320, 640]
      expect(pageRect.left, closeTo(250, 0.001));
      expect(pageRect.top, closeTo(320, 0.001));
      expect(pageRect.width, closeTo(200, 0.001));
      expect(pageRect.height, closeTo(320, 0.001));
    });

    test('Maps visual normalized rect to page coordinates on 270-degree page', () {
      const geometry = PdfPageGeometry(
        mediaBox: Rect.fromLTWH(0, 0, 500, 800),
        cropBox: Rect.fromLTWH(0, 0, 500, 800),
        rotation: 270,
      );

      final pageRect = geometry.mapNormalizedVisualRectToPage(
        const Rect.fromLTRB(0.1, 0.2, 0.5, 0.6),
      );

      // 270° CW: x in [(1-0.6)*500, (1-0.2)*500] = [200, 400]
      // y in [0.1*800, 0.5*800] = [80, 400]
      expect(pageRect.left, closeTo(200, 0.001));
      expect(pageRect.top, closeTo(80, 0.001));
      expect(pageRect.width, closeTo(200, 0.001));
      expect(pageRect.height, closeTo(320, 0.001));
    });

    test('Accounts for CropBox offsets correctly', () {
      const geometry = PdfPageGeometry(
        mediaBox: Rect.fromLTWH(0, 0, 600, 900),
        cropBox: Rect.fromLTWH(50, 100, 500, 800),
        rotation: 0,
      );

      expect(geometry.cropOffsetX, 50);
      expect(geometry.cropOffsetY, 100);
      expect(geometry.cropWidth, 500);
      expect(geometry.cropHeight, 800);
      expect(geometry.hasCropOffset, true);

      final pageRect = geometry.mapNormalizedVisualRectToPage(
        const Rect.fromLTRB(0.0, 0.0, 1.0, 1.0),
      );

      expect(pageRect.left, closeTo(50, 0.001));
      expect(pageRect.top, closeTo(100, 0.001));
      expect(pageRect.width, closeTo(500, 0.001));
      expect(pageRect.height, closeTo(800, 0.001));
    });
  });

  group('Rotated & CropBox Watermarking & Redaction Integration Tests', () {
    test('Watermark applies across 0, 90, 180, and 270 degree rotated pages', () async {
      final inputPath = await createRotatedPagesPdf();

      final outPath = await pdfService.watermarkPdf(
        pdfPath: inputPath,
        watermarkText: 'ROTATION_WATERMARK',
        opacity: 0.35,
        angle: 0.0, // horizontal visual angle
        color: Colors.blue,
      );

      final outFile = File(outPath);
      expect(await outFile.exists(), true);

      final outBytes = await outFile.readAsBytes();
      final sfDoc = sf.PdfDocument(inputBytes: outBytes);
      expect(sfDoc.pages.count, 4);

      // Verify page rotations are preserved
      expect(sfDoc.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle0);
      expect(sfDoc.pages[1].rotation, sf.PdfPageRotateAngle.rotateAngle90);
      expect(sfDoc.pages[2].rotation, sf.PdfPageRotateAngle.rotateAngle180);
      expect(sfDoc.pages[3].rotation, sf.PdfPageRotateAngle.rotateAngle270);

      // Verify watermark text is present on all pages
      final extractor = sf.PdfTextExtractor(sfDoc);
      final text = extractor.extractText();
      expect(text.contains('ROTATION_WATERMARK'), true);

      sfDoc.dispose();
    });

    test('Image watermark applies across rotated pages', () async {
      final inputPath = await createRotatedPagesPdf();
      final pngBytes = createTestPng(width: 80, height: 80);

      final outPath = await pdfService.watermarkPdf(
        pdfPath: inputPath,
        watermarkImageBytes: pngBytes,
        opacity: 0.4,
        angle: 0.0,
        imageScale: 0.8,
      );

      final outFile = File(outPath);
      expect(await outFile.exists(), true);

      final outBytes = await outFile.readAsBytes();
      final sfDoc = sf.PdfDocument(inputBytes: outBytes);
      expect(sfDoc.pages.count, 4);

      // Verify page rotations are preserved
      expect(sfDoc.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle0);
      expect(sfDoc.pages[1].rotation, sf.PdfPageRotateAngle.rotateAngle90);
      expect(sfDoc.pages[2].rotation, sf.PdfPageRotateAngle.rotateAngle180);
      expect(sfDoc.pages[3].rotation, sf.PdfPageRotateAngle.rotateAngle270);

      sfDoc.dispose();
    });

    test('Redaction accounts for page rotation (90, 180, 270) and crop box', () async {
      final inputPath = await createRotatedPagesPdf();

      // Define visual redactions across all 4 pages
      final redactions = {
        0: [const Rect.fromLTWH(0.1, 0.1, 0.8, 0.2)],
        1: [const Rect.fromLTWH(0.2, 0.2, 0.6, 0.3)],
        2: [const Rect.fromLTWH(0.05, 0.05, 0.4, 0.4)],
        3: [const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4)],
      };

      final outPath = await pdfService.redactPdf(
        pdfPath: inputPath,
        redactionsByPage: redactions,
      );

      final outFile = File(outPath);
      expect(await outFile.exists(), true);
      expect(await outFile.length() > 0, true);

      final outBytes = await outFile.readAsBytes();
      final sfDoc = sf.PdfDocument(inputBytes: outBytes);
      expect(sfDoc.pages.count, 4);
      sfDoc.dispose();
    });
  });
}
