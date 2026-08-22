import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/main.dart';
import 'package:pdf_ai_toolkit/views/tools/merge_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/text_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_text_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/camera_scan_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_editor_screen.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

void main() {
  testWidgets('App loads and displays HomeScreen smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PdfAiToolkitApp());
    await tester.pumpAndSettle();

    expect(find.text('What would you like\nto do today?'), findsOneWidget);
    expect(find.text('PDF AI Toolkit'), findsWidgets);
    expect(find.text('All Tools'), findsOneWidget);
    expect(find.text('Start Scan'), findsOneWidget);
  });

  testWidgets('HomeScreen category filtering and tool navigation test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build our app and trigger a frame.
    await tester.pumpWidget(const PdfAiToolkitApp());
    await tester.pumpAndSettle();

    // Verify main app title is visible
    expect(find.text('PDF AI Toolkit'), findsWidgets);

    // Verify all categories exist
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Convert'), findsOneWidget);
    expect(find.text('Organize'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);

    // 1. Verify Organize category filtering
    final organizeTab = find.byKey(const ValueKey('category_tab_Organize'));
    await tester.ensureVisible(organizeTab);
    await tester.tap(organizeTab);
    await tester.pumpAndSettle();

    // Verify Organize tools are rendered
    expect(find.text('Merge PDF'), findsOneWidget);
    expect(find.text('Split PDF'), findsOneWidget);
    expect(find.text('Compress PDF'), findsOneWidget);
    expect(find.text('Rotate PDF'), findsOneWidget);

    // Convert and Edit specific tools should not be visible under Organize
    expect(find.text('Word/TXT to PDF'), findsNothing);
    expect(find.text('PDF Editor'), findsNothing);

    // 2. Verify navigation to an Organize tool (Merge PDF)
    final mergeCard = find.byKey(const ValueKey('tool_card_Merge PDF'));
    await tester.ensureVisible(mergeCard);
    await tester.tap(mergeCard);
    await tester.pumpAndSettle();

    // Verify MergePdfScreen opened
    expect(find.byType(MergePdfScreen), findsOneWidget);
    expect(find.text('Select PDFs to Merge'), findsOneWidget);

    // Navigate back to Home screen
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Verify we are back on Home screen and category is still 'Organize'
    expect(find.byType(MergePdfScreen), findsNothing);
    expect(find.text('Merge PDF'), findsOneWidget);
    expect(find.text('Split PDF'), findsOneWidget);

    // 3. Verify Convert category filtering
    final convertTab = find.byKey(const ValueKey('category_tab_Convert'));
    await tester.ensureVisible(convertTab);
    await tester.tap(convertTab);
    await tester.pumpAndSettle();

    expect(find.text('Images to PDF'), findsOneWidget);
    expect(find.text('Word/TXT to PDF'), findsOneWidget);
    expect(find.text('PDF to Text'), findsOneWidget);
    expect(find.text('Camera Scan'), findsOneWidget);
    expect(find.text('Merge PDF'), findsNothing);

    // 4. Verify Edit category filtering
    final editTab = find.byKey(const ValueKey('category_tab_Edit'));
    await tester.ensureVisible(editTab);
    await tester.tap(editTab);
    await tester.pumpAndSettle();

    expect(find.text('PDF Editor'), findsOneWidget);
    expect(find.text('Watermark PDF'), findsOneWidget);
    expect(find.text('Protect PDF'), findsOneWidget);

    // 5. Verify AI category filtering
    final aiTab = find.byKey(const ValueKey('category_tab_AI'));
    await tester.ensureVisible(aiTab);
    await tester.tap(aiTab);
    await tester.pumpAndSettle();

    expect(find.text('AI to PDF'), findsOneWidget);
    expect(find.text('AI Refine'), findsOneWidget);
    expect(find.text('Chat with PDF'), findsOneWidget);

    // 6. Verify All category shows all tools
    final allTab = find.byKey(const ValueKey('category_tab_All'));
    await tester.ensureVisible(allTab);
    await tester.tap(allTab);
    await tester.pumpAndSettle();

    expect(find.text('Images to PDF'), findsOneWidget);
    expect(find.text('Merge PDF'), findsOneWidget);
    expect(find.text('PDF Editor'), findsOneWidget);
  });

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

    testWidgets('CameraScanScreen displays empty state when no scanned pages', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: CameraScanScreen(),
      ));

      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('No Scanned Pages Yet'), findsOneWidget);
      expect(find.text('Start Scanning'), findsOneWidget);
    });

    testWidgets('PdfEditorScreen displays empty state when no PDF file selected', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PdfEditorScreen(),
      ));

      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('Open a PDF to Edit'), findsOneWidget);
      expect(find.text('Choose PDF File'), findsOneWidget);
    });
    });
  });
}
