import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/controllers/ai_action_dispatcher.dart';
import 'package:pdf_ai_toolkit/controllers/ai_controller.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfService pdfService;
  late AiActionDispatcher actionDispatcher;
  late AiController aiController;
  late String tempDirPath;
  late Directory hiveTempDir;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
    pdfService = PdfService();
    actionDispatcher = AiActionDispatcher();
    aiController = AiController();
    tempDirPath = Directory.systemTemp.path;

    hiveTempDir =
        await Directory.systemTemp.createTemp('html_to_pdf_hive_test_');
    Hive.init(hiveTempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  group('HTML to PDF Conversion Tests', () {
    test('Successfully converts standard HTML elements to PDF', () async {
      const htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <style>body { font-size: 12px; }</style>
</head>
<body>
  <h1>Main HTML Header</h1>
  <h2>Sub HTML Header</h2>
  <p>This is a paragraph with <b>bold HTML text</b> and <i>italic HTML text</i>.</p>
  <p>Also we have <code>inline HTML code</code> and a blockquote:</p>
  <blockquote>
    <p>This is an HTML quote block.</p>
  </blockquote>
  <ul>
    <li>HTML Bullet item 1</li>
    <li>HTML Bullet item 2</li>
  </ul>
  <ol>
    <li>HTML Numbered item 1</li>
    <li>HTML Numbered item 2</li>
  </ol>
  <pre><code>
Fenced HTML code block line 1
Fenced HTML code block line 2
  </code></pre>
  <hr>
  <p>Horizontal rule above.</p>
</body>
</html>
''';

      final inputPath =
          '$tempDirPath/test_${DateTime.now().millisecondsSinceEpoch}.html';
      final inputFile = File(inputPath);
      await inputFile.writeAsString(htmlContent);
      final originalLength = inputFile.lengthSync();

      final outputPath = await pdfService.convertHtmlToPdf(
        htmlPath: inputPath,
        title: 'HTML Test Document',
      );
      final outputFile = File(outputPath);

      // Output validations
      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.lengthSync(), greaterThan(0));
      expect(outputPath.endsWith('.pdf'), isTrue);

      // Validate that original input file is unchanged
      expect(inputFile.lengthSync(), equals(originalLength));
      expect(inputFile.readAsStringSync(), equals(htmlContent));

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
        expect(normalized.contains('HTML Test Document'), isTrue);
        expect(normalized.contains('Main HTML Header'), isTrue);
        expect(normalized.contains('Sub HTML Header'), isTrue);
        expect(normalized.contains('bold HTML text'), isTrue);
        expect(normalized.contains('italic HTML text'), isTrue);
        expect(normalized.contains('inline HTML code'), isTrue);
        expect(normalized.contains('This is an HTML quote block.'), isTrue);
        expect(normalized.contains('HTML Bullet item 1'), isTrue);
        expect(normalized.contains('HTML Numbered item 1'), isTrue);
        expect(normalized.contains('Fenced HTML code block line 1'), isTrue);
      } finally {
        document.dispose();
      }

      // Cleanup
      await inputFile.delete();
      await outputFile.delete();
    });

    test('Throws PdfServiceException on empty input HTML file', () async {
      final emptyFilePath =
          '$tempDirPath/empty_${DateTime.now().millisecondsSinceEpoch}.html';
      final emptyFile = File(emptyFilePath);
      await emptyFile.writeAsString('');

      await expectLater(
        pdfService.convertHtmlToPdf(
            htmlPath: emptyFilePath, title: 'Empty HTML'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'HTML_TO_PDF_INPUT_EMPTY')),
      );

      await emptyFile.delete();
    });

    test('Throws PdfServiceException on missing input HTML file', () async {
      final missingPath =
          '$tempDirPath/missing_${DateTime.now().millisecondsSinceEpoch}.html';

      await expectLater(
        pdfService.convertHtmlToPdf(
            htmlPath: missingPath, title: 'Missing HTML'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'HTML_TO_PDF_INPUT_NOT_FOUND')),
      );
    });
  });

  group('Workflow Integration Tests', () {
    test(
        'detectActionType correctly identifies Markdown/HTML conversion commands',
        () {
      expect(actionDispatcher.detectActionType('convert markdown to pdf'),
          equals(AiActionType.markdownToPdf));
      expect(actionDispatcher.detectActionType('convert md'),
          equals(AiActionType.markdownToPdf));
      expect(actionDispatcher.detectActionType('md to pdf'),
          equals(AiActionType.markdownToPdf));

      expect(actionDispatcher.detectActionType('convert html to pdf'),
          equals(AiActionType.htmlToPdf));
      expect(actionDispatcher.detectActionType('convert html'),
          equals(AiActionType.htmlToPdf));
    });

    test('executeAction successfully handles md and html files directly',
        () async {
      final mdPath =
          '$tempDirPath/test_${DateTime.now().millisecondsSinceEpoch}.md';
      final htmlPath =
          '$tempDirPath/test_${DateTime.now().millisecondsSinceEpoch}.html';

      await File(mdPath).writeAsString('# Markdown Text');
      await File(htmlPath).writeAsString('<p>HTML Text</p>');

      // Run Markdown execution
      final resultMd = await actionDispatcher.executeAction(
        pdfPath: mdPath,
        command: 'convert',
      );
      expect(resultMd.isSuccess, isTrue);
      expect(resultMd.type, equals(AiActionType.markdownToPdf));
      expect(resultMd.outputPath, isNotNull);
      expect(File(resultMd.outputPath!).existsSync(), isTrue);

      // Run HTML execution
      final resultHtml = await actionDispatcher.executeAction(
        pdfPath: htmlPath,
        command: 'convert',
      );
      expect(resultHtml.isSuccess, isTrue);
      expect(resultHtml.type, equals(AiActionType.htmlToPdf));
      expect(resultHtml.outputPath, isNotNull);
      expect(File(resultHtml.outputPath!).existsSync(), isTrue);

      // Cleanup
      await File(mdPath).delete();
      await File(htmlPath).delete();
      await File(resultMd.outputPath!).delete();
      await File(resultHtml.outputPath!).delete();
    });

    test('processDocumentAction correctly routes md and html paths', () async {
      final mdPath =
          '$tempDirPath/test_${DateTime.now().millisecondsSinceEpoch}.md';
      await File(mdPath).writeAsString('# Hello Markdown');

      final result = await aiController.processDocumentAction(
        pdfPath: mdPath,
        command: 'convert to pdf',
      );

      expect(result, isNotNull);
      expect(result!.isSuccess, isTrue);
      expect(result.type, equals(AiActionType.markdownToPdf));
      expect(File(result.outputPath!).existsSync(), isTrue);

      await File(mdPath).delete();
      await File(result.outputPath!).delete();
    });
  });
}
