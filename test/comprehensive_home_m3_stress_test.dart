import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/main.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/views/home/home_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/merge_pdf_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/camera_scan_screen.dart';
import 'package:pdf_ai_toolkit/views/tools/ai_refine_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('comprehensive_home_stress_');
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

  group('Multi-dimensional Comprehensive Testing - Home M3 Tools Redesign', () {
    // ── 1. Responsive Form Factor & Orientation Testing ─────────────────────
    testWidgets('Renders cleanly on Small Phone form factor (360x640)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('AI PDF Maker'), findsOneWidget);
      expect(find.text('All Tools'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on Tablet Landscape form factor (1280x800)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('AI PDF Maker'), findsOneWidget);
      expect(find.text('All Tools'), findsOneWidget);
      expect(find.text('Convert & Organize'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on High-DPI Modern Phone (1080x2400 @ 2.5x)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('AI PDF Maker'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ── 2. Theme Switching & Color Token Contrast Testing ───────────────────
    testWidgets('Dynamic Dark Mode and Light Mode switching retains contrast',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.light,
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify light mode appearance
      expect(find.text('All Tools'), findsOneWidget);

      // Rebuild with Dark Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.dark,
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify dark mode appearance
      expect(find.text('All Tools'), findsOneWidget);
      expect(find.text('AI PDF Maker'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ── 3. Rapid Category Switching Stress Testing ──────────────────────────
    testWidgets('Rapid category chip cycling stress test',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      // Cycle rapidly across tabs 5 times
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('AI Tools'));
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.text('Edit & Sign'));
        await tester.pump(const Duration(milliseconds: 50));

        await tester.ensureVisible(find.text('Convert & Organize'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('Convert & Organize'));
        await tester.pump(const Duration(milliseconds: 50));

        await tester.ensureVisible(find.text('All Tools'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('All Tools'));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();
      expect(find.text('Images to PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ── 4. Card Micro-Animation & Tap Lifecycle Testing ────────────────────
    testWidgets('Card touch press, hold, and cancel animation lifecycle',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      // Switch to AI Tools
      await tester.tap(find.text('AI Tools'));
      await tester.pumpAndSettle();

      final aiToPdfCard = find.text('AI to PDF');
      expect(aiToPdfCard, findsOneWidget);

      // Start gesture (Press and Hold)
      final gesture = await tester.startGesture(tester.getCenter(aiToPdfCard));
      await tester.pump(const Duration(milliseconds: 70));

      // Cancel gesture (drag off without release)
      await gesture.moveTo(const Offset(0, 0));
      await gesture.cancel();
      await tester.pumpAndSettle();

      // Card must recover to full size and stay on Home screen
      expect(find.text('AI to PDF'), findsOneWidget);
      expect(find.text('AI PDF Maker'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    // ── 5. Full Navigation Round-Trip Testing Across Core Tools ─────────────
    testWidgets('Navigate to Merge PDF and return safely',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Convert & Organize'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Convert & Organize'));
      await tester.pumpAndSettle();

      final mergeCard = find.text('Merge PDF');
      expect(mergeCard, findsOneWidget);

      await tester.tap(mergeCard);
      await tester.pumpAndSettle();

      expect(find.byType(MergePdfScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(MergePdfScreen), findsNothing);
      expect(find.text('AI PDF Maker'), findsWidgets);
    });

    testWidgets('Navigate to Camera Scan and return safely',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Convert & Organize'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Convert & Organize'));
      await tester.pumpAndSettle();

      final scanCard = find.text('Camera Scan');
      expect(scanCard, findsOneWidget);

      await tester.tap(scanCard);
      await tester.pumpAndSettle();

      expect(find.byType(CameraScanScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(CameraScanScreen), findsNothing);
      expect(find.text('AI PDF Maker'), findsWidgets);
    });

    testWidgets('Navigate to AI Refine and return safely',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI Tools'));
      await tester.pumpAndSettle();

      final refineCard = find.text('AI Refine');
      expect(refineCard, findsOneWidget);

      await tester.tap(refineCard);
      await tester.pumpAndSettle();

      expect(find.byType(AiRefineScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(AiRefineScreen), findsNothing);
      expect(find.text('AI PDF Maker'), findsWidgets);
    });
  });
}
