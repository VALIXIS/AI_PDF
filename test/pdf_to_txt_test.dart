import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  // Helper to generate a multi-page test PDF with text
  Future<String> createTestPdf({
    required List<String> pageTexts,
  }) async {
    final pdf = pw.Document();
    for (final text in pageTexts) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text(text),
            );
          },
        ),
      );
    }
    final file = File('$tempDirPath/test_input_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  group('PDF to TXT Conversion Tests', () {
    test('Successfully extracts text from single-page PDF', () async {
      final inputPath = await createTestPdf(pageTexts: ['Hello World PDF Text']);
      final inputFile = File(inputPath);
      final inputLength = await inputFile.length();

      final outputPath = await pdfService.convertPdfToTxt(pdfPath: inputPath);
      final outputFile = File(outputPath);

      expect(await outputFile.exists(), true);
      expect(await outputFile.length() > 0, true);

      final content = await outputFile.readAsString();
      final normalizedContent = content.replaceAll(RegExp(r'\s+'), ' ').trim();
      expect(normalizedContent.contains('Hello World PDF Text'), true);

      // Verify original file is unchanged
      expect(await inputFile.length(), inputLength);

      // Cleanup
      await inputFile.delete();
      await outputFile.delete();
    });

    test('Successfully extracts text from multi-page PDF preserving sequence', () async {
      final inputPath = await createTestPdf(pageTexts: [
        'First Page Content Text',
        'Second Page Content Text',
        'Third Page Content Text',
      ]);

      final outputPath = await pdfService.convertPdfToTxt(pdfPath: inputPath);
      final outputFile = File(outputPath);

      expect(await outputFile.exists(), true);

      final content = await outputFile.readAsString();
      final normalizedContent = content.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Check for content presence
      expect(normalizedContent.contains('First Page Content Text'), true);
      expect(normalizedContent.contains('Second Page Content Text'), true);
      expect(normalizedContent.contains('Third Page Content Text'), true);

      // Check for sequence (indices of pages in normalized string)
      final firstIdx = normalizedContent.indexOf('First Page Content Text');
      final secondIdx = normalizedContent.indexOf('Second Page Content Text');
      final thirdIdx = normalizedContent.indexOf('Third Page Content Text');

      expect(firstIdx < secondIdx, true);
      expect(secondIdx < thirdIdx, true);

      // Cleanup
      await File(inputPath).delete();
      await outputFile.delete();
    });

    test('Successfully extracts Unicode/special characters', () async {
      final inputPath = await createTestPdf(pageTexts: ['éàüößçñ Unicode Text']);
      
      final outputPath = await pdfService.convertPdfToTxt(pdfPath: inputPath);
      final outputFile = File(outputPath);

      expect(await outputFile.exists(), true);

      final content = await outputFile.readAsString();
      final normalizedContent = content.replaceAll(RegExp(r'\s+'), ' ').trim();
      expect(normalizedContent.contains('éàüößçñ Unicode Text'), true);

      // Cleanup
      await File(inputPath).delete();
      await outputFile.delete();
    });

    test('Throws exception on empty/no-text PDF (simulating scanned/image-only PDF)', () async {
      // Create a PDF with only an empty page (no text widgets)
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(); // Empty container, no text
          },
        ),
      );
      final inputPath = '$tempDirPath/empty_page_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(inputPath).writeAsBytes(await pdf.save());

      expect(
        () async => await pdfService.convertPdfToTxt(pdfPath: inputPath),
        throwsA(isA<Exception>()),
      );

      // Cleanup
      await File(inputPath).delete();
    });

    test('Throws exception on missing input PDF file', () async {
      expect(
        () async => await pdfService.convertPdfToTxt(pdfPath: '$tempDirPath/non_existent.pdf'),
        throwsA(isA<Exception>()),
      );
    });

    test('Throws exception on corrupt PDF file', () async {
      final corruptFile = File('$tempDirPath/corrupt_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await corruptFile.writeAsString('This is not a PDF file');

      expect(
        () async => await pdfService.convertPdfToTxt(pdfPath: corruptFile.path),
        throwsA(isA<Exception>()),
      );

      // Cleanup
      await corruptFile.delete();
    });

    test('Throws exception on empty input PDF file', () async {
      final emptyFile = File('$tempDirPath/empty_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await emptyFile.writeAsBytes([]);

      expect(
        () async => await pdfService.convertPdfToTxt(pdfPath: emptyFile.path),
        throwsA(isA<Exception>()),
      );

      // Cleanup
      await emptyFile.delete();
    });
  });
}
