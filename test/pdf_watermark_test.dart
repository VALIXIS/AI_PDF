import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
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

  group('PDF Watermarking Tests', () {
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
    });
  });
}
