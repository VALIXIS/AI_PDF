import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/main.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/views/home/home_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_editor_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/merge_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/chat_with_pdf_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('home_redesign_test_hive_');
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

  group('Home Screen M3 Redesign & Category Chips Tests', () {
    testWidgets(
        'Renders category filter chips and switches tool filters interactively',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify all 4 category filter chips exist
      expect(find.text('All Tools'), findsOneWidget);
      expect(find.text('AI Tools'), findsOneWidget);
      expect(find.text('Edit & Sign'), findsOneWidget);
      expect(find.text('Convert & Organize'), findsOneWidget);

      // 2. Test switching to 'AI Tools'
      await tester.tap(find.text('AI Tools'));
      await tester.pumpAndSettle();

      expect(find.text('Chat with PDF'), findsOneWidget);
      expect(find.text('AI to PDF'), findsOneWidget);
      expect(find.text('AI Refine'), findsOneWidget);
      // Non-AI tools should not be visible
      expect(find.text('Merge PDF'), findsNothing);
      expect(find.text('Images to PDF'), findsNothing);

      // 3. Test switching to 'Edit & Sign'
      await tester.tap(find.text('Edit & Sign'));
      await tester.pumpAndSettle();

      expect(find.text('PDF Editor'), findsOneWidget);
      expect(find.text('Watermark PDF'), findsOneWidget);
      expect(find.text('Protect PDF'), findsOneWidget);
      // Convert tools should not be visible
      expect(find.text('Images to PDF'), findsNothing);
      expect(find.text('Chat with PDF'), findsNothing);

      // 4. Test switching to 'Convert & Organize'
      await tester.ensureVisible(find.text('Convert & Organize'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Convert & Organize'));
      await tester.pumpAndSettle();

      expect(find.text('Images to PDF'), findsOneWidget);
      expect(find.text('TXT to PDF'), findsOneWidget);
      expect(find.text('Merge PDF'), findsOneWidget);
      expect(find.text('Split PDF'), findsOneWidget);
      expect(find.text('Compress PDF'), findsOneWidget);
      expect(find.text('Rotate PDF'), findsOneWidget);
      // AI tools should not be visible
      expect(find.text('Chat with PDF'), findsNothing);

      // 5. Test switching back to 'All Tools'
      await tester.ensureVisible(find.text('All Tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Tools'));
      await tester.pumpAndSettle();

      expect(find.text('Images to PDF'), findsOneWidget);
      expect(find.text('Merge PDF'), findsOneWidget);
    });

    testWidgets('Tool card press micro-animation and navigation works smoothly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to 'Edit & Sign' to access PDF Editor card
      await tester.tap(find.text('Edit & Sign'));
      await tester.pumpAndSettle();

      final editorCard = find.text('PDF Editor');
      expect(editorCard, findsOneWidget);

      // Test tap down animation
      final gesture = await tester.startGesture(tester.getCenter(editorCard));
      await tester.pump(const Duration(milliseconds: 70));

      // Release gesture to navigate
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify PDF Editor screen is pushed
      expect(find.byType(PdfEditorScreen), findsOneWidget);

      // Pop back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Verify returned to HomeScreen
      expect(find.byType(PdfEditorScreen), findsNothing);
      expect(find.text('AI PDF Maker'), findsWidgets);
    });

    testWidgets('AI Chat FloatingActionButton navigates cleanly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final aiChatBtn = find.text('AI Chat');
      expect(aiChatBtn, findsOneWidget);

      await tester.tap(aiChatBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ChatWithPdfScreen), findsOneWidget);

      // Pop back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ChatWithPdfScreen), findsNothing);
    });
  });
}
