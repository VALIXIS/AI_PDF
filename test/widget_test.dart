import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/main.dart';
import 'package:pdf_ai_toolkit/views/tools/merge_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/text_to_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_to_text_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/camera_scan_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_editor_screen.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/widgets/tool_state_widgets.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('widget_test_hive_');
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
  testWidgets('App loads and displays Splash Screen to HomeScreen smoke test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PdfAiToolkitApp());
    await tester.pump();
    
    // Splash screen is visible
    expect(find.text('Your Intelligent Document Studio'), findsOneWidget);

    // Wait for splash screen timer to finish (2200ms) and animation
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Home screen is visible with grid categories
    expect(find.text('AI PDF Maker'), findsWidgets);
    expect(find.text('CONVERT'), findsOneWidget);
    expect(find.text('ORGANIZE'), findsOneWidget);
  });

  testWidgets('HomeScreen category grid and tool navigation test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build our app and trigger a frame.
    await tester.pumpWidget(const PdfAiToolkitApp());
    await tester.pumpAndSettle(const Duration(seconds: 3)); // Wait for splash

    // Scroll to find Merge PDF tool if needed
    final mergeCard = find.text('Merge PDF');
    await tester.dragUntilVisible(mergeCard, find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Verify tool is rendered
    expect(mergeCard, findsOneWidget);

    // 2. Verify navigation to an Organize tool (Merge PDF)
    await tester.tap(mergeCard);
    await tester.pumpAndSettle();

    // Verify MergePdfScreen opened
    expect(find.byType(MergePdfScreen), findsOneWidget);
    expect(find.text('No PDF Selected'), findsOneWidget);

    // Navigate back
    final backBtn = find.byType(BackButton);
    await tester.tap(backBtn);
    await tester.pumpAndSettle();


    // Verify we are back on Home screen
    expect(find.byType(MergePdfScreen), findsNothing);
    expect(find.text('Merge PDF'), findsOneWidget);
    expect(find.text('Split PDF'), findsOneWidget);

    // Scroll to an AI tool to verify it's rendered in the list
    final aiTool = find.text('Chat with PDF');
    await tester.dragUntilVisible(aiTool, find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    
    expect(aiTool, findsOneWidget);
  });

  group('Tool State Widgets Unit Tests', () {
    testWidgets('ToolErrorBanner displays message and handles retry/dismiss',
        (WidgetTester tester) async {
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

    testWidgets('ToolSuccessCard displays success info and handles actions',
        (WidgetTester tester) async {
      bool saved = false;
      bool shared = false;
      bool reset = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ToolSuccessCard(
            title: 'PDF Merged Successfully!',
            subtitle: 'Combined 3 documents into one.',
            filePath: '/documents/merged_doc.pdf',
            onSave: () => saved = true,
            onShare: () => shared = true,
            onReset: () => reset = true,
          ),
        ),
      ));

      expect(find.text('PDF Merged Successfully!'), findsOneWidget);
      expect(find.text('merged_doc.pdf'), findsOneWidget);

      await tester.tap(find.text('Save'));
      expect(saved, isTrue);

      await tester.tap(find.text('Share'));
      expect(shared, isTrue);

      await tester.tap(find.text('New Task'));
      expect(reset, isTrue);
    });

    testWidgets('ToolEmptyState displays title and handles action button',
        (WidgetTester tester) async {
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

    testWidgets('ToolLoadingBanner displays loading status message',
        (WidgetTester tester) async {
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
    testWidgets(
        'TextToPdfScreen shows error banner when submitting empty fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: TextToPdfScreen(),
      ));

      // Tap Generate PDF without title or content
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate PDF'));
      await tester.pumpAndSettle();

      expect(find.byType(ToolErrorBanner), findsOneWidget);
      expect(
          find.text('Please enter both a title and content to generate a PDF.'),
          findsOneWidget);
    });

    testWidgets('MergePdfScreen displays empty state when no files selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: MergePdfScreen(),
      ));

      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
    });

    testWidgets('PdfToTextScreen displays empty state when no file selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PdfToTextScreen(),
      ));

      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('No PDF Selected'), findsOneWidget);
    });

    testWidgets('CameraScanScreen displays empty state when no scanned pages',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: CameraScanScreen(),
      ));

      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('No Scanned Pages Yet'), findsOneWidget);
      expect(find.text('Start Scanning'), findsOneWidget);
    });

    testWidgets(
        'PdfEditorScreen displays empty state when no PDF file selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PdfEditorScreen(),
      ));

      expect(find.byType(ToolEmptyState), findsOneWidget);
      expect(find.text('Open a PDF to Edit'), findsOneWidget);
      expect(find.text('Choose PDF File'), findsOneWidget);
    });
  });
}
