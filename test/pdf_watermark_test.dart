import 'dart:io';
import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
=======
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
>>>>>>> origin/develop

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

<<<<<<< HEAD
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_watermark_test_');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper to create a test PDF
  Future<String> createTestPdf({
    required String filename,
    required int pageCount,
    required String textPrefix,
  }) async {
    final pdf = pw.Document();
    for (int i = 1; i <= pageCount; i++) {
=======
  late PdfService pdfService;
  late String tempDirPath;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
    pdfService = PdfService();
    tempDirPath = Directory.systemTemp.path;
  });

  // Helper to generate a multi-page test PDF
  Future<String> createTestPdf({required int pageCount}) async {
    final pdf = pw.Document();
    for (int i = 0; i < pageCount; i++) {
>>>>>>> origin/develop
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
<<<<<<< HEAD
              child: pw.Text(
                '$textPrefix Page$i',
                style: const pw.TextStyle(fontSize: 24),
              ),
=======
              child: pw.Text('Page ${i + 1}'),
>>>>>>> origin/develop
            );
          },
        ),
      );
    }
<<<<<<< HEAD
    final file = File('${tempDir.path}/$filename');
=======
    final file = File('$tempDirPath/test_watermark_input_${DateTime.now().millisecondsSinceEpoch}.pdf');
>>>>>>> origin/develop
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  group('PDF Watermarking Tests', () {
<<<<<<< HEAD
    test('Watermark applies to all pages and text remains extractable', () async {
      final sourcePath = await createTestPdf(
        filename: 'watermark_source.pdf',
        pageCount: 3,
        textPrefix: 'BaseText',
      );

      final service = PdfService();
      final watermarkedPath = await service.watermarkPdf(
        pdfPath: sourcePath,
        watermarkText: 'CONFIDENTIAL',
        opacity: 0.5,
        angle: 0.785, // ~45 deg
        color: Colors.red,
        customOutputPath: tempDir.path,
      );

      final file = File(watermarkedPath);
      expect(await file.exists(), isTrue);

      final doc = syncfusion.PdfDocument(inputBytes: await file.readAsBytes());
      expect(doc.pages.count, equals(3));

      final extractor = syncfusion.PdfTextExtractor(doc);
      for (int i = 0; i < 3; i++) {
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i).replaceAll(RegExp(r'\s+'), ' ');
        expect(text, contains('BaseText Page${i + 1}'));
        expect(text, contains('CONFIDENTIAL'));
      }

      doc.dispose();
=======
    test('Successfully applies text watermark to all pages of a multi-page PDF', () async {
      final inputPath = await createTestPdf(pageCount: 3);
      final inputFile = File(inputPath);

      // Verify page count of input file
      final inputBytes = await inputFile.readAsBytes();
      final sf.PdfDocument inputDoc = sf.PdfDocument(inputBytes: inputBytes);
      expect(inputDoc.pages.count, 3);
      inputDoc.dispose();

      // Perform watermarking
      final outputPath = await pdfService.watermarkPdf(
        pdfPath: inputPath,
        watermarkText: 'TEST WATERMARK',
        opacity: 0.3,
        angle: -0.4,
        color: Colors.red,
      );

      final outputFile = File(outputPath);
      expect(await outputFile.exists(), true);
      expect(await outputFile.length() > 0, true);

      // Verify pages count and text content in output
      final outputBytes = await outputFile.readAsBytes();
      final sf.PdfDocument outputDoc = sf.PdfDocument(inputBytes: outputBytes);
      expect(outputDoc.pages.count, 3);

      final sf.PdfTextExtractor extractor = sf.PdfTextExtractor(outputDoc);
      final String extractedText = extractor.extractText();
      
      // Verify original content is preserved
      expect(extractedText.contains('Page'), true);
      expect(extractedText.contains('1'), true);
      expect(extractedText.contains('2'), true);
      expect(extractedText.contains('3'), true);

      // Verify watermark is genuinely present
      expect(extractedText.contains('TEST WATERMARK'), true);

      outputDoc.dispose();

      // Verify that original input is unchanged (by comparing file hashes or size)
      final inputBytesAfter = await inputFile.readAsBytes();
      expect(inputBytesAfter.length, inputBytes.length);

      // Clean up
      await inputFile.delete();
      await outputFile.delete();
    });

    test('Throws exception on non-existent file', () async {
      expect(
        () async => await pdfService.watermarkPdf(
          pdfPath: '$tempDirPath/non_existent_file.pdf',
          watermarkText: 'CONFIDENTIAL',
          opacity: 0.5,
          angle: 0.0,
          color: Colors.black,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Throws exception on corrupt file', () async {
      final corruptFile = File('$tempDirPath/corrupt.pdf');
      await corruptFile.writeAsString('Definitely not a PDF content');

      expect(
        () async => await pdfService.watermarkPdf(
          pdfPath: corruptFile.path,
          watermarkText: 'CONFIDENTIAL',
          opacity: 0.5,
          angle: 0.0,
          color: Colors.black,
        ),
        throwsA(isA<Exception>()),
      );

      // Clean up
      await corruptFile.delete();
    });

    test('Throws exception on empty file', () async {
      final emptyFile = File('$tempDirPath/empty.pdf');
      await emptyFile.writeAsBytes([]);

      expect(
        () async => await pdfService.watermarkPdf(
          pdfPath: emptyFile.path,
          watermarkText: 'CONFIDENTIAL',
          opacity: 0.5,
          angle: 0.0,
          color: Colors.black,
        ),
        throwsA(isA<Exception>()),
      );

      // Clean up
      await emptyFile.delete();
    });

    test('Throws exception on empty watermark text', () async {
      final inputPath = await createTestPdf(pageCount: 1);

      expect(
        () async => await pdfService.watermarkPdf(
          pdfPath: inputPath,
          watermarkText: '',
          opacity: 0.5,
          angle: 0.0,
          color: Colors.black,
        ),
        throwsA(isA<Exception>()),
      );

      // Clean up
      await File(inputPath).delete();
>>>>>>> origin/develop
    });
  });
}
