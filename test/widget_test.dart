import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';
import 'package:pdf_ai_toolkit/views/tools/text_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_text_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/merge_pdf_screen.dart';

void main() {
  group('Tool State Widgets Unit Tests', () {
    testWidgets('ToolErrorBanner displays message and handles retry/dismiss', (WidgetTester tester) async {
      bool retried = false;
      bool dismissed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolErrorBanner(
            message: 'Failed to process PDF file',
            onRetry: () => retried = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ));

      expect(find.text('Operation Failed'), findsOneWidget);
      expect(find.text('Failed to process PDF file'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(dismissed, isTrue);
    });

    testWidgets('ToolSuccessCard displays success info and handles actions', (WidgetTester tester) async {
      bool shared = false;
      bool reset = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolSuccessCard(
            title: 'PDF Merged Successfully!',
            subtitle: 'Combined 3 documents into one.',
            filePath: '/documents/merged_doc.pdf',
            onShare: () => shared = true,
            onReset: () => reset = true,
          ),
        ),
      ));

      expect(find.text('PDF Merged Successfully!'), findsOneWidget);
      expect(find.text('merged_doc.pdf'), findsOneWidget);

      await tester.tap(find.text('Save / Share'));
      expect(shared, isTrue);

      await tester.tap(find.text('New Task'));
      expect(reset, isTrue);
    });

    testWidgets('ToolEmptyState displays title and handles action button', (WidgetTester tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolEmptyState(
            icon: Icons.picture_as_pdf_outlined,
            title: 'No PDF Selected',
            subtitle: 'Select a PDF document to begin',
            actionLabel: 'Select PDF',
            onAction: () => actionTapped = true,
          ),
        ),
      ));

      expect(find.text('No PDF Selected'), findsOneWidget);
      expect(find.text('Select a PDF document to begin'), findsOneWidget);

      await tester.tap(find.text('Select PDF'));
      expect(actionTapped, isTrue);
    });

    testWidgets('ToolLoadingBanner displays loading status message', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ToolLoadingBanner(
            message: 'Extracting text from PDF document...',
          ),
        ),
      ));

      expect(find.text('Extracting text from PDF document...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('Core PDF Tool Screens State Tests', () {
    testWidgets('TextToPdfScreen shows error banner when submitting empty fields', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: TextToPdfScreen(),
      ));

      // Tap Generate PDF without title or content
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate PDF'));
      await tester.pumpAndSettle();

      expect(find.byType(ToolErrorBanner), findsOneWidget);
      expect(find.text('Please enter both a title and content to generate a PDF.'), findsOneWidget);
    });

    testWidgets('MergePdfScreen displays empty state when no files selected', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: MergePdfScreen(),
      ));

      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('No PDFs Selected'), findsOneWidget);
    });

    testWidgets('PdfToTextScreen displays empty state when no file selected', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PdfToTextScreen(),
      ));

      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
    });
  });
}
