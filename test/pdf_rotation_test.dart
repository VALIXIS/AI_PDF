import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

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

  // Helper to generate a multi-page test PDF
  Future<String> createTestPdf({required int pageCount}) async {
    final pdf = pw.Document();
    for (int i = 0; i < pageCount; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text('Page ${i + 1}'),
            );
          },
        ),
      );
    }
    final file = File(
        '$tempDirPath/test_input_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  group('PDF Rotation Tests', () {
    test('Successfully rotates all pages of a multi-page PDF', () async {
      final inputPath = await createTestPdf(pageCount: 3);
      final inputFile = File(inputPath);

      // Verify page count of input file
      final inputBytes = await inputFile.readAsBytes();
      final sf.PdfDocument inputDoc = sf.PdfDocument(inputBytes: inputBytes);
      expect(inputDoc.pages.count, 3);
      for (int i = 0; i < 3; i++) {
        expect(inputDoc.pages[i].rotation, sf.PdfPageRotateAngle.rotateAngle0);
      }
      inputDoc.dispose();

      // Perform rotation by 90 degrees
      final outputPath = await pdfService.rotatePdf(
        pdfPath: inputPath,
        rotationAngle: 90,
      );

      final outputFile = File(outputPath);
      expect(await outputFile.exists(), true);
      expect(await outputFile.length() > 0, true);

      // Verify pages rotation in output
      final outputBytes = await outputFile.readAsBytes();
      final sf.PdfDocument outputDoc = sf.PdfDocument(inputBytes: outputBytes);
      expect(outputDoc.pages.count, 3);
      for (int i = 0; i < 3; i++) {
        expect(
            outputDoc.pages[i].rotation, sf.PdfPageRotateAngle.rotateAngle90);
      }
      outputDoc.dispose();

      // Verify that original input is unchanged
      final inputBytesAfter = await inputFile.readAsBytes();
      final sf.PdfDocument inputDocAfter =
          sf.PdfDocument(inputBytes: inputBytesAfter);
      for (int i = 0; i < 3; i++) {
        expect(inputDocAfter.pages[i].rotation,
            sf.PdfPageRotateAngle.rotateAngle0);
      }
      inputDocAfter.dispose();

      // Clean up
      await inputFile.delete();
      await outputFile.delete();
    });

    test('Rotation is additive', () async {
      final inputPath = await createTestPdf(pageCount: 1);

      // Rotate by 90
      final path90 =
          await pdfService.rotatePdf(pdfPath: inputPath, rotationAngle: 90);

      // Rotate again by 180 (90 + 180 = 270)
      final path270 =
          await pdfService.rotatePdf(pdfPath: path90, rotationAngle: 180);

      final file270 = File(path270);
      final bytes270 = await file270.readAsBytes();
      final sf.PdfDocument doc270 = sf.PdfDocument(inputBytes: bytes270);
      expect(doc270.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle270);
      doc270.dispose();

      // Clean up
      await File(inputPath).delete();
      await File(path90).delete();
      await file270.delete();
    });

    test('Throws exception on non-existent file', () async {
      expect(
        () async => await pdfService.rotatePdf(
          pdfPath: '$tempDirPath/non_existent_file.pdf',
          rotationAngle: 90,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Throws exception on corrupt file', () async {
      final corruptFile = File('$tempDirPath/corrupt.pdf');
      await corruptFile.writeAsString('Definitely not a PDF content');

      expect(
        () async => await pdfService.rotatePdf(
          pdfPath: corruptFile.path,
          rotationAngle: 90,
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
        () async => await pdfService.rotatePdf(
          pdfPath: emptyFile.path,
          rotationAngle: 90,
        ),
        throwsA(isA<Exception>()),
      );

      // Clean up
      await emptyFile.delete();
    });
  });
}
