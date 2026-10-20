import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/widgets/tool_screen_shell.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

import 'package:pdf_ai_toolkit/views/tools/rotate_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/protect_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/watermark_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/redaction_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/text_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_text_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_image_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/jpg_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/ai_refine_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/ai_summarizer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String tempDirPath;
  late String demoPdfPath;
  late PdfService pdfService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('demo_pdf_tool_test_');
    tempDirPath = tempDir.path;

    // Initialize Hive for storage
    Hive.init(tempDirPath);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }

    // Mock path provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDirPath,
    );

    // Mock package_info_plus and other standard channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall methodCall) async => {
        'appName': 'PDF AI Toolkit',
        'packageName': 'com.example.pdf_ai_toolkit',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );

    pdfService = PdfService();

    // Create a real multi-page demo PDF document using Syncfusion for full font/stream compatibility
    final sfDoc = sf.PdfDocument();
    final page1 = sfDoc.pages.add();
    page1.graphics.drawString(
      'Antigravity Demo PDF Document\nThis is page 1 of the demo PDF document used for verifying tool screens.',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 16),
      bounds: const Rect.fromLTWH(20, 20, 500, 100),
    );
    final page2 = sfDoc.pages.add();
    page2.graphics.drawString(
      'Demo PDF - Page 2\nAdditional content on the second page for multi-page tests.',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 16),
      bounds: const Rect.fromLTWH(20, 20, 500, 100),
    );

    final demoFile = File('$tempDirPath/demo_document.pdf');
    final bytes = sfDoc.saveSync();
    sfDoc.dispose();
    await demoFile.writeAsBytes(bytes);
    demoPdfPath = demoFile.path;
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Demo PDF Tool Screens Widget & Shell Rendering Tests', () {
    testWidgets('RotatePdfScreen renders ToolScreenShell and empty state',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RotatePdfScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ToolScreenShell), findsOneWidget);
      expect(find.text('Rotate PDF'), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });

    testWidgets('ProtectPdfScreen renders ToolScreenShell and empty state',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProtectPdfScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ToolScreenShell), findsOneWidget);
      expect(find.text('Protect PDF'), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });

    testWidgets('WatermarkScreen renders ToolScreenShell and empty state',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WatermarkScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ToolScreenShell), findsOneWidget);
      expect(find.text('Watermark PDF'), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });

    testWidgets(
        'RedactionScreen renders ToolScreenShell with actions and empty state',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RedactionScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ToolScreenShell), findsOneWidget);
      expect(find.text('Redact PDF'), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });

    testWidgets('TextToPdfScreen renders ToolScreenShell with input fields',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TextToPdfScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ToolScreenShell), findsOneWidget);
      expect(find.text('Text to PDF'), findsOneWidget);
      expect(find.text('Create PDF from Text'), findsOneWidget);
      expect(find.text('Import File'), findsOneWidget);
      expect(find.text('Generate PDF'), findsOneWidget);
    });

    testWidgets('PdfToTextScreen renders ToolScreenShell and empty state',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PdfToTextScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ToolScreenShell), findsOneWidget);
      expect(find.text('PDF to Text'), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });

    testWidgets('PdfToImageScreen renders ToolScreenShell and empty state',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PdfToImageScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ToolScreenShell), findsOneWidget);
      expect(find.text('PDF to Image'), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });

    testWidgets('JpgToPdfScreen renders ToolScreenShell and settings',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: JpgToPdfScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ToolScreenShell), findsOneWidget);
      expect(find.text('Images to PDF'), findsOneWidget);
      expect(find.text('No Images Selected'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });

    testWidgets('AiRefineScreen renders ToolScreenShell and mode chips',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AiRefineScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ToolScreenShell), findsOneWidget);
      expect(find.text('AI Refine'), findsOneWidget);
      expect(find.text('Polish Your Text with AI'), findsOneWidget);
      expect(find.text('Refine Text with AI'), findsOneWidget);
    });

    testWidgets('AiSummarizerScreen renders ToolScreenShell and title',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AiSummarizerScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ToolScreenShell), findsOneWidget);
      expect(find.text('AI Document Summarizer'), findsOneWidget);
    });
  });

  group('Demo PDF Functional Operations End-to-End Tests', () {
    test('Demo PDF exists and is valid 2-page PDF', () async {
      final file = File(demoPdfPath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));

      final bytes = await file.readAsBytes();
      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      expect(sfDoc.pages.count, 2);
      sfDoc.dispose();
    });

    test('Rotate Tool: successfully rotates demo PDF by 90 degrees', () async {
      final rotatedPath = await pdfService.rotatePdf(
        pdfPath: demoPdfPath,
        rotationAngle: 90,
      );

      final rotatedFile = File(rotatedPath);
      expect(await rotatedFile.exists(), isTrue);

      final bytes = await rotatedFile.readAsBytes();
      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      expect(sfDoc.pages.count, 2);
      expect(sfDoc.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle90);
      expect(sfDoc.pages[1].rotation, sf.PdfPageRotateAngle.rotateAngle90);
      sfDoc.dispose();
    });

    test('Watermark Tool: successfully applies custom watermark text to demo PDF',
        () async {
      final watermarkedPath = await pdfService.watermarkPdf(
        pdfPath: demoPdfPath,
        watermarkText: 'CONFIDENTIAL REVIEW',
        opacity: 0.5,
        angle: -0.5,
        color: Colors.red,
      );

      final watermarkedFile = File(watermarkedPath);
      expect(await watermarkedFile.exists(), isTrue);

      final bytes = await watermarkedFile.readAsBytes();
      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      expect(sfDoc.pages.count, 2);

      final extractor = sf.PdfTextExtractor(sfDoc);
      final text = extractor.extractText();
      expect(text.contains('Antigravity Demo PDF Document'), isTrue);
      expect(text.contains('CONFIDENTIAL REVIEW'), isTrue);
      sfDoc.dispose();
    });

    test('Protect Tool: successfully encrypts demo PDF with user password',
        () async {
      const password = 'demoSecretPassword123';
      final protectedPath = await pdfService.protectPdf(
        pdfPath: demoPdfPath,
        userPassword: password,
        ownerPassword: password,
      );

      final protectedFile = File(protectedPath);
      expect(await protectedFile.exists(), isTrue);

      final bytes = await protectedFile.readAsBytes();

      // Expect opening without password to fail
      expect(
        () => sf.PdfDocument(inputBytes: bytes),
        throwsA(anything),
      );

      // Expect opening with password to succeed
      final sfDoc = sf.PdfDocument(inputBytes: bytes, password: password);
      expect(sfDoc.pages.count, 2);
      sfDoc.dispose();
    });

    test('PDF to Text Tool: converts demo PDF to TXT file accurately',
        () async {
      final txtPath = await pdfService.convertPdfToTxt(pdfPath: demoPdfPath);
      final txtFile = File(txtPath);
      expect(await txtFile.exists(), isTrue);
      expect(await txtFile.length(), greaterThan(0));

      final content = await txtFile.readAsString();
      expect(content.contains('Antigravity Demo PDF Document'), isTrue);
    });

    test('Text to PDF Tool: creates a new formatted PDF document from text',
        () async {
      final generatedPath = await pdfService.generatePdfFromText(
        title: 'Generated From Demo Text',
        content: 'This document was dynamically created by the Text to PDF tool.',
      );

      final genFile = File(generatedPath);
      expect(await genFile.exists(), isTrue);
      expect(await genFile.length(), greaterThan(0));

      final bytes = await genFile.readAsBytes();
      final sfDoc = sf.PdfDocument(inputBytes: bytes);
      expect(sfDoc.pages.count, greaterThanOrEqualTo(1));
      sfDoc.dispose();
    });
  });
}
