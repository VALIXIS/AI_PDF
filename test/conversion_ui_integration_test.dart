import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/views/tools/text_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_text_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/jpg_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_image_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/markdown_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('conversion_ui_test_hive_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Conversion Screens UI & State Workflow Tests', () {
    testWidgets(
        'TextToPdfScreen renders empty fields and validates empty inputs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TextToPdfScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Text to PDF'), findsOneWidget);
      expect(find.text('Create PDF from Text'), findsOneWidget);
      expect(find.text('Generate PDF'), findsOneWidget);
      expect(find.text('Import File'), findsOneWidget);

      // Tap Generate PDF with empty fields
      await tester.tap(find.text('Generate PDF'));
      await tester.pumpAndSettle();

      // Verify ToolErrorBanner is displayed
      expect(find.byType(ToolErrorBanner), findsOneWidget);
      expect(
        find.text('Please enter both a title and content to generate a PDF.'),
        findsOneWidget,
      );
    });

    testWidgets('PdfToTextScreen renders empty state initially',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfToTextScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PDF to Text'), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
      expect(find.text('Select PDF'), findsNWidgets(2));
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });

    testWidgets('JpgToPdfScreen renders empty state and page options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: JpgToPdfScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Images to PDF'), findsOneWidget);
      expect(find.text('No Images Selected'), findsOneWidget);
      expect(find.text('Page size'), findsOneWidget);
      expect(find.text('Fit to page'), findsOneWidget);
      expect(find.text('Select images first'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });

    testWidgets('PdfToImageScreen renders empty state and controls',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfToImageScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PDF to Image'), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
      expect(find.text('Select PDF'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });

    testWidgets('MarkdownToPdfScreen renders shell and empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MarkdownToPdfScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Markdown to PDF'), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
      expect(find.text('Select PDF'), findsOneWidget);
      expect(find.byType(ToolEmptyState), findsOneWidget);
    });
  });
}
