import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';
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

  group('Markdown to PDF Conversion Tests', () {
    test('Successfully converts standard Markdown elements to PDF', () async {
      const markdownContent = '''
# Main Header
## Sub Header
This is a paragraph with **bold text** and *italic text*.
Also we have `inline code` and a blockquote:
> This is a quote block.
- Bullet item 1
- Bullet item 2

1. Numbered item 1
2. Numbered item 2

```
Fenced code block line 1
Fenced code block line 2
```

---
Horizontal rule above.
''';

      final inputPath =
          '$tempDirPath/test_${DateTime.now().millisecondsSinceEpoch}.md';
      final inputFile = File(inputPath);
      await inputFile.writeAsString(markdownContent);
      final originalLength = inputFile.lengthSync();

      final outputPath = await pdfService.convertMarkdownToPdf(
        markdownPath: inputPath,
        title: 'Markdown Test Document',
      );
      final outputFile = File(outputPath);

      // Output validations
      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.lengthSync(), greaterThan(0));
      expect(outputPath.endsWith('.pdf'), isTrue);

      // Validate that original input file is unchanged
      expect(inputFile.lengthSync(), equals(originalLength));
      expect(inputFile.readAsStringSync(), equals(markdownContent));

      // Reopen and check validity with Syncfusion
      final sf.PdfDocument document =
          sf.PdfDocument(inputBytes: outputFile.readAsBytesSync());
      try {
        expect(document.pages.count, greaterThan(0));

        final sf.PdfTextExtractor extractor = sf.PdfTextExtractor(document);
        final String extractedText = extractor.extractText();
        final String normalized =
            extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();

        // Verify key semantic content exists in the generated PDF
        expect(normalized.contains('Markdown Test Document'), isTrue);
        expect(normalized.contains('Main Header'), isTrue);
        expect(normalized.contains('Sub Header'), isTrue);
        expect(normalized.contains('bold text'), isTrue);
        expect(normalized.contains('italic text'), isTrue);
        expect(normalized.contains('inline code'), isTrue);
        expect(normalized.contains('This is a quote block.'), isTrue);
        expect(normalized.contains('Bullet item 1'), isTrue);
        expect(normalized.contains('Numbered item 1'), isTrue);
        expect(normalized.contains('Fenced code block line 1'), isTrue);
      } finally {
        document.dispose();
      }

      // Cleanup
      await inputFile.delete();
      await outputFile.delete();
    });

    test('Throws PdfServiceException on empty input Markdown file', () async {
      final emptyFilePath =
          '$tempDirPath/empty_${DateTime.now().millisecondsSinceEpoch}.md';
      final emptyFile = File(emptyFilePath);
      await emptyFile.writeAsString('');

      await expectLater(
        pdfService.convertMarkdownToPdf(
            markdownPath: emptyFilePath, title: 'Empty'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'MARKDOWN_TO_PDF_INPUT_EMPTY')),
      );

      await emptyFile.delete();
    });

    test('Throws PdfServiceException on missing input Markdown file', () async {
      final missingPath =
          '$tempDirPath/missing_${DateTime.now().millisecondsSinceEpoch}.md';

      await expectLater(
        pdfService.convertMarkdownToPdf(
            markdownPath: missingPath, title: 'Missing'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'MARKDOWN_TO_PDF_INPUT_NOT_FOUND')),
      );
    });
  });
}
