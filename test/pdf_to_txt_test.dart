import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_to_txt_test_');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> createTestPdf({
    required String filename,
    required String content,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Text(content, style: const pw.TextStyle(fontSize: 16)),
          );
        },
      ),
    );
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  group('PDF to TXT Conversion Tests', () {
    test('Converts PDF to TXT accurately', () async {
      final pdfPath = await createTestPdf(
        filename: 'text_extract.pdf',
        content: 'Hello World! Extractable PDF Text Content.',
      );

      final service = PdfService();
      final txtPath = await service.convertPdfToTxt(
        pdfPath: pdfPath,
        customOutputPath: tempDir.path,
      );

      final txtFile = File(txtPath);
      expect(await txtFile.exists(), isTrue);

      final content = await txtFile.readAsString();
      expect(content, contains('Hello World! Extractable PDF Text Content.'));
    });
  });
}
