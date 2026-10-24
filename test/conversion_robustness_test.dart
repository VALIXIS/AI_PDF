import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfService pdfService;
  late FileService fileService;
  late Directory tempDir;
  late String tempDirPath;
  late Directory hiveTempDir;

  setUpAll(() async {
    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );

    tempDir =
        await Directory.systemTemp.createTemp('conversion_robustness_test_');
    tempDirPath = tempDir.path;
    pdfService = PdfService();
    fileService = FileService();

    hiveTempDir = await Directory.systemTemp.createTemp('robustness_hive_');
    Hive.init(hiveTempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  // Helper to generate a valid PDF of minimal size
  Future<String> createValidPdf({String content = 'Test PDF'}) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(child: pw.Text(content));
        },
      ),
    );
    final filePath =
        '$tempDirPath/valid_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  group('Input Validation and Bounds Tests', () {
    test('isPdfFile correctly rejects corrupt or mismatched files', () async {
      final corruptPath = '$tempDirPath/corrupt.pdf';
      await File(corruptPath).writeAsString('This is not a PDF at all.');
      expect(await fileService.isPdfFile(corruptPath), isFalse);
      await File(corruptPath).delete();
    });

    test(
        'isImageFile correctly rejects non-image bytes named with image extension',
        () async {
      final fakeImagePath = '$tempDirPath/fake.png';
      await File(fakeImagePath).writeAsString('Some plain text content.');
      expect(await fileService.isImageFile(fakeImagePath), isFalse);
      await File(fakeImagePath).delete();
    });

    test('isMarkdownFile and isHtmlFile correctly identify formats', () async {
      final mdPath = '$tempDirPath/test.md';
      await File(mdPath).writeAsString('# Markdown Header');
      expect(await fileService.isMarkdownFile(mdPath), isTrue);
      expect(await fileService.isHtmlFile(mdPath), isFalse);
      await File(mdPath).delete();

      final htmlPath = '$tempDirPath/test.html';
      await File(htmlPath).writeAsString('<html><body>Hello</body></html>');
      expect(await fileService.isHtmlFile(htmlPath), isTrue);
      expect(await fileService.isMarkdownFile(htmlPath), isFalse);
      await File(htmlPath).delete();
    });
  });

  group('PDF to TXT Robustness Tests', () {
    test('Throws PDF_TO_TXT_FILE_TOO_LARGE when PDF exceeds size limit',
        () async {
      final hugePath = '$tempDirPath/huge.pdf';
      final file = File(hugePath);

      // Write some bytes mimicking a 51MB file structure containing %PDF- signature
      final sink = file.openWrite();
      sink.add(List<int>.generate(
          1024,
          (i) =>
              i == 100 ? 0x25 : 0x00)); // contains %PDF- magic check implicitly
      // Fill the rest with 51MB of zeroes
      final block = List<int>.filled(1024 * 1024, 0);
      for (int i = 0; i < 51; i++) {
        sink.add(block);
      }
      await sink.close();

      await expectLater(
        pdfService.convertPdfToTxt(pdfPath: hugePath),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_TO_TXT_FILE_TOO_LARGE')),
      );

      await file.delete();
    });

    test('Throws PDF_TO_TXT_INVALID_PDF on malformed/corrupt file', () async {
      final malformedPath = '$tempDirPath/malformed.pdf';
      await File(malformedPath).writeAsString('%PDF-1.4\ncorrupted content');

      await expectLater(
        pdfService.convertPdfToTxt(pdfPath: malformedPath),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_TO_TXT_INVALID_PDF')),
      );

      await File(malformedPath).delete();
    });

    test('Throws PDF_TO_TXT_INPUT_EMPTY on empty PDF file', () async {
      final emptyPath = '$tempDirPath/empty.pdf';
      await File(emptyPath).writeAsString('');

      await expectLater(
        pdfService.convertPdfToTxt(pdfPath: emptyPath),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_TO_TXT_INVALID_PDF')),
      );

      await File(emptyPath).delete();
    });
  });

  group('TXT to PDF Robustness Tests', () {
    test('Throws TXT_TO_PDF_FILE_TOO_LARGE when text exceeds 5MB', () async {
      final largeTxtPath = '$tempDirPath/large.txt';
      final file = File(largeTxtPath);
      // Write 6MB of characters
      await file.writeAsString('A' * 6 * 1024 * 1024);

      await expectLater(
        pdfService.convertTxtToPdf(txtPath: largeTxtPath, title: 'Large Doc'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'TXT_TO_PDF_FILE_TOO_LARGE')),
      );

      await file.delete();
    });

    test('Throws TXT_TO_PDF_INVALID_TEXT on invalid encoding or binary inputs',
        () async {
      final binaryTxtPath = '$tempDirPath/binary.txt';
      final file = File(binaryTxtPath);
      // Write binary bytes (null bytes) to trigger text validation failure
      await file.writeAsBytes([0x00, 0x01, 0x02, 0x03]);

      await expectLater(
        pdfService.convertTxtToPdf(txtPath: binaryTxtPath, title: 'Binary Doc'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'TXT_TO_PDF_INVALID_TEXT')),
      );

      await file.delete();
    });

    test('Throws TXT_TO_PDF_EMPTY_TITLE on empty title argument', () async {
      final txtPath = '$tempDirPath/normal.txt';
      await File(txtPath).writeAsString('Hello world text content');

      await expectLater(
        pdfService.convertTxtToPdf(txtPath: txtPath, title: ' '),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'TXT_TO_PDF_EMPTY_TITLE')),
      );

      await File(txtPath).delete();
    });
  });

  group('Image to PDF Robustness Tests', () {
    test('Throws IMAGE_TO_PDF_TOO_MANY_IMAGES when exceeding 100 images limit',
        () async {
      final imgPaths =
          List<String>.generate(101, (i) => '$tempDirPath/img_$i.png');

      await expectLater(
        pdfService.convertImagesToPdf(imagePaths: imgPaths),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'IMAGE_TO_PDF_TOO_MANY_IMAGES')),
      );
    });

    test('Throws IMAGE_TO_PDF_FILE_TOO_LARGE when image exceeds 10MB',
        () async {
      final largeImgPath = '$tempDirPath/large_img.png';
      // Write 11MB of dummy PNG data to trigger size limit
      final file = File(largeImgPath);
      final sink = file.openWrite();
      sink.add([137, 80, 78, 71, 13, 10, 26, 10]); // PNG magic bytes
      final block = List<int>.filled(1024 * 1024, 0);
      for (int i = 0; i < 11; i++) {
        sink.add(block);
      }
      await sink.close();

      await expectLater(
        pdfService.convertImagesToPdf(imagePaths: [largeImgPath]),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'IMAGE_TO_PDF_FILE_TOO_LARGE')),
      );

      await file.delete();
    });

    test('Throws IMAGE_TO_PDF_INVALID_IMAGE on format mismatch', () async {
      final badImgPath = '$tempDirPath/bad.png';
      // Write text file disguised with image extension
      await File(badImgPath).writeAsString('This is text, not an image.');

      await expectLater(
        pdfService.convertImagesToPdf(imagePaths: [badImgPath]),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'IMAGE_TO_PDF_INVALID_IMAGE')),
      );

      await File(badImgPath).delete();
    });
  });

  group('PDF Rotation and Watermarking Robustness Tests', () {
    test(
        'Throws PDF_ROTATE_FILE_TOO_LARGE when PDF exceeds 50MB during rotation',
        () async {
      final hugePath = '$tempDirPath/huge_rotate.pdf';
      final file = File(hugePath);
      final raf = await file.open(mode: FileMode.write);
      await raf.writeFrom([0x25, 0x50, 0x44, 0x46, 0x2D]); // %PDF- magic bytes
      await raf.truncate(101 * 1024 * 1024);
      await raf.close();

      await expectLater(
        pdfService.rotatePdf(pdfPath: hugePath, rotationAngle: 90),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_ROTATE_FILE_TOO_LARGE')),
      );

      await file.delete();
    });

    test('Throws PDF_WATERMARK_EMPTY_TEXT on empty watermark string', () async {
      final pdfPath = await createValidPdf();

      await expectLater(
        pdfService.watermarkPdf(
          pdfPath: pdfPath,
          watermarkText: '   ',
          opacity: 0.5,
          angle: 0.78,
          color: const Color(0xFFFF0000),
        ),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_WATERMARK_EMPTY_TEXT')),
      );

      await File(pdfPath).delete();
    });

    test('Successfully applies watermark and validates output structure',
        () async {
      final pdfPath = await createValidPdf();

      final resultPath = await pdfService.watermarkPdf(
        pdfPath: pdfPath,
        watermarkText: 'DRAFT',
        opacity: 0.4,
        angle: 45 * 3.14 / 180,
        color: const Color(0xFF00FF00),
      );

      expect(File(resultPath).existsSync(), isTrue);
      expect(File(resultPath).lengthSync(), greaterThan(0));

      // Reopen watermarked PDF and verify
      final sf.PdfDocument document =
          sf.PdfDocument(inputBytes: File(resultPath).readAsBytesSync());
      expect(document.pages.count, equals(1));
      document.dispose();

      await File(pdfPath).delete();
      await File(resultPath).delete();
    });
  });

  group('PDF Compression Robustness Tests', () {
    test('Throws PDF_COMPRESS_FILE_TOO_LARGE when compressing file > 50MB',
        () async {
      final hugePath = '$tempDirPath/huge_compress.pdf';
      final file = File(hugePath);
      final raf = await file.open(mode: FileMode.write);
      await raf.writeFrom([0x25, 0x50, 0x44, 0x46, 0x2D]); // %PDF- magic bytes
      await raf.truncate(101 * 1024 * 1024);
      await raf.close();

      await expectLater(
        pdfService.compressPdf(hugePath),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_COMPRESS_FILE_TOO_LARGE')),
      );

      await file.delete();
    });

    test('Successfully compresses PDF and verifies structure', () async {
      final pdfPath = await createValidPdf();

      final resultPath =
          await pdfService.compressPdf(pdfPath, compressionLevel: 'high');
      expect(File(resultPath).existsSync(), isTrue);

      final sf.PdfDocument document =
          sf.PdfDocument(inputBytes: File(resultPath).readAsBytesSync());
      expect(document.pages.count, equals(1));
      document.dispose();

      await File(pdfPath).delete();
      await File(resultPath).delete();
    });
  });

  group('Markdown and HTML to PDF Robustness Tests', () {
    test('Throws MARKDOWN_TO_PDF_FILE_TOO_LARGE on markdown files > 5MB',
        () async {
      final mdPath = '$tempDirPath/huge.md';
      await File(mdPath).writeAsString('A' * 6 * 1024 * 1024);

      await expectLater(
        pdfService.convertMarkdownToPdf(markdownPath: mdPath, title: 'Huge MD'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'MARKDOWN_TO_PDF_FILE_TOO_LARGE')),
      );

      await File(mdPath).delete();
    });

    test('Throws HTML_TO_PDF_FILE_TOO_LARGE on HTML files > 5MB', () async {
      final htmlPath = '$tempDirPath/huge.html';
      await File(htmlPath).writeAsString('A' * 6 * 1024 * 1024);

      await expectLater(
        pdfService.convertHtmlToPdf(htmlPath: htmlPath, title: 'Huge HTML'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'HTML_TO_PDF_FILE_TOO_LARGE')),
      );

      await File(htmlPath).delete();
    });

    test('Throws HTML_TO_PDF_INVALID_INPUT on non-HTML content files',
        () async {
      final badHtmlPath = '$tempDirPath/bad.html';
      // Write binary data to badge-extension file
      await File(badHtmlPath).writeAsBytes([0x00, 0x01, 0x02, 0x03]);

      await expectLater(
        pdfService.convertHtmlToPdf(htmlPath: badHtmlPath, title: 'Bad HTML'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'HTML_TO_PDF_INVALID_INPUT')),
      );

      await File(badHtmlPath).delete();
    });

    test('Markdown to PDF renders tables and wraps code blocks cleanly',
        () async {
      const mdContent = '''
# Audit Markdown Document

| Component | Status | Details |
| :--- | :---: | ---: |
| HTML Tables | Completed | Styled with borders & padding |
| Code Blocks | Completed | Wrapped long lines & subtle fill |

```dart
final String veryLongUrl = "https://example.com/api/v1/resource/endpoint/subresource/nested?param1=value1&param2=value2&param3=value3&param4=value4&param5=value5";
```
''';

      final mdPath = '$tempDirPath/audit_test.md';
      await File(mdPath).writeAsString(mdContent);

      final outPath = await pdfService.convertMarkdownToPdf(
        markdownPath: mdPath,
        title: 'Audit Markdown Test',
        customOutputPath: tempDirPath,
      );

      final outFile = File(outPath);
      expect(outFile.existsSync(), isTrue);
      expect(outFile.lengthSync(), greaterThan(0));

      final sf.PdfDocument doc =
          sf.PdfDocument(inputBytes: outFile.readAsBytesSync());
      try {
        expect(doc.pages.count, greaterThan(0));
        final text = sf.PdfTextExtractor(doc)
            .extractText()
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(text.contains('Component'), isTrue);
        expect(text.contains('HTML Tables'), isTrue);
        expect(text.contains('veryLongUrl'), isTrue);
      } finally {
        doc.dispose();
      }

      await File(mdPath).delete();
      await outFile.delete();
    });

    test('HTML to PDF renders tables and wraps code blocks cleanly', () async {
      const htmlContent = '''
<!DOCTYPE html>
<html>
<body>
  <h1>Audit HTML Document</h1>
  <table border="1">
    <tr>
      <th>Module</th>
      <th>Result</th>
    </tr>
    <tr>
      <td>UTF-8 Glyphs</td>
      <td>Resolved</td>
    </tr>
  </table>
  <pre><code>final String superLongIdentifierNameThatExceedsTheStandardPageWidthWithoutBreaking = "https://long-domain-name.test.internal/v1/auth/token?signature=abcdef1234567890";</code></pre>
</body>
</html>
''';

      final htmlPath = '$tempDirPath/audit_test.html';
      await File(htmlPath).writeAsString(htmlContent);

      final outPath = await pdfService.convertHtmlToPdf(
        htmlPath: htmlPath,
        title: 'Audit HTML Test',
        customOutputPath: tempDirPath,
      );

      final outFile = File(outPath);
      expect(outFile.existsSync(), isTrue);
      expect(outFile.lengthSync(), greaterThan(0));

      final sf.PdfDocument doc =
          sf.PdfDocument(inputBytes: outFile.readAsBytesSync());
      try {
        expect(doc.pages.count, greaterThan(0));
        final text = sf.PdfTextExtractor(doc)
            .extractText()
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(text.contains('Module'), isTrue);
        expect(text.contains('UTF-8 Glyphs'), isTrue);
        expect(text.contains('superLongIdentifierName'), isTrue);
      } finally {
        doc.dispose();
      }

      await File(htmlPath).delete();
      await outFile.delete();
    });

    test('Markdown and HTML render UTF-8 characters without missing glyph boxes',
        () async {
      const utf8Sample = '''
“Smart Quotes” and ‘single quotes’ — Em Dash and – En Dash.
• Bullet item 1
™ Trademark, © Copyright, ® Registered, ✓ Passed checkmark.
Math: ± 5 ≤ 10 ≥ 2 ≠ 0 × 3 ÷ 2.
Currencies: €100, ₹500, £50, ¥1000.
Arrows: Left ← Right → Both ↔.
Accents: Café, résumé, señor, Über, façade.
''';

      final mdPath = '$tempDirPath/utf8_test.md';
      await File(mdPath).writeAsString('# UTF-8 Test\n\n$utf8Sample');

      final mdOut = await pdfService.convertMarkdownToPdf(
        markdownPath: mdPath,
        title: 'UTF-8 Markdown Test',
        customOutputPath: tempDirPath,
      );

      final mdFile = File(mdOut);
      expect(mdFile.existsSync(), isTrue);

      final sf.PdfDocument mdDoc =
          sf.PdfDocument(inputBytes: mdFile.readAsBytesSync());
      try {
        expect(mdDoc.pages.count, greaterThan(0));
        final extracted = sf.PdfTextExtractor(mdDoc)
            .extractText()
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(extracted.contains('"Smart Quotes"'), isTrue);
        expect(extracted.contains('EUR'), isTrue);
        expect(extracted.contains('INR'), isTrue);
        expect(extracted.contains('Café'), isTrue);
      } finally {
        mdDoc.dispose();
      }

      // Test HTML UTF-8
      final htmlPath = '$tempDirPath/utf8_test.html';
      await File(htmlPath).writeAsString('<p>$utf8Sample</p>');

      final htmlOut = await pdfService.convertHtmlToPdf(
        htmlPath: htmlPath,
        title: 'UTF-8 HTML Test',
        customOutputPath: tempDirPath,
      );

      final htmlFile = File(htmlOut);
      expect(htmlFile.existsSync(), isTrue);

      final sf.PdfDocument htmlDoc =
          sf.PdfDocument(inputBytes: htmlFile.readAsBytesSync());
      try {
        expect(htmlDoc.pages.count, greaterThan(0));
        final extracted = sf.PdfTextExtractor(htmlDoc)
            .extractText()
            .replaceAll(RegExp(r'\s+'), ' ');
        expect(extracted.contains('"Smart Quotes"'), isTrue);
        expect(extracted.contains('EUR'), isTrue);
        expect(extracted.contains('INR'), isTrue);
        expect(extracted.contains('Café'), isTrue);
      } finally {
        htmlDoc.dispose();
      }

      await File(mdPath).delete();
      await File(htmlPath).delete();
      await mdFile.delete();
      await htmlFile.delete();
    });
  });
}
