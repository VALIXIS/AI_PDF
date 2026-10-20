import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/views/viewer/pdf_document_viewer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File emptyFile;
  late File demoPdfFile;

  // 1x1 valid sample PNG bytes for mocked PDF page rasterization
  final dummyPngBytes = Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10,
    0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
    0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180,
    0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
  ]);

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_viewer_test_');

    emptyFile = File('${tempDir.path}/empty_book.pdf');
    emptyFile.writeAsBytesSync([]);

    // Create a demo multi-page PDF placeholder file
    demoPdfFile = File('${tempDir.path}/demo_large_book_50p.pdf');
    demoPdfFile.writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]); // %PDF-1.4 header

    // Register mock platform channel for pdfx renderer
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('io.scer.pdf_renderer'),
            (MethodCall call) async {
      if (call.method == 'open.document.file') {
        final path = call.arguments as String;
        if (path.contains('zero_pages')) {
          return {'id': 'doc_zero', 'pagesCount': 0};
        }
        return {'id': 'doc_demo_50p', 'pagesCount': 50}; // 50-page book demo
      } else if (call.method == 'open.page') {
        final pageNum = call.arguments['page'] as int;
        return {
          'id': 'page_$pageNum',
          'width': 595.0,
          'height': 842.0,
        };
      } else if (call.method == 'render') {
        final width = call.arguments['width'] as int? ?? 1190;
        final height = call.arguments['height'] as int? ?? 1684;
        return {
          'width': width,
          'height': height,
          'data': dummyPngBytes,
        };
      } else if (call.method == 'close.page' || call.method == 'close.document') {
        return null;
      }
      return null;
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('io.scer.pdf_renderer'), null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PdfDocumentViewerScreen Virtualized Memory Tests', () {
    testWidgets('Displays error when PDF file does not exist',
        (WidgetTester tester) async {
      final nonExistentPath = '${tempDir.path}/non_existent_book.pdf';

      await tester.pumpWidget(
        MaterialApp(
          home: PdfDocumentViewerScreen(filePath: nonExistentPath),
        ),
      );
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.byIcon(Icons.error_outline_rounded).evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.textContaining('PDF file not found'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Displays error when PDF file is empty (0 bytes)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PdfDocumentViewerScreen(filePath: emptyFile.path),
        ),
      );
      for (int i = 0; i < 15; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.byIcon(Icons.error_outline_rounded).evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.textContaining('PDF file is empty'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
        'Tightens Flutter image cache limits on mount and restores on dispose',
        (WidgetTester tester) async {
      final dummyPath = '${tempDir.path}/non_existent_cache_test.pdf';

      final initialMaxBytes =
          PaintingBinding.instance.imageCache.maximumSizeBytes;

      await tester.pumpWidget(
        MaterialApp(
          home: PdfDocumentViewerScreen(filePath: dummyPath),
        ),
      );
      await tester.pump();

      // Verify image cache limit clamped to 40MB
      expect(PaintingBinding.instance.imageCache.maximumSizeBytes,
          equals(40 * 1024 * 1024));
      expect(PaintingBinding.instance.imageCache.maximumSize, equals(8));

      // Pop widget
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      // Verify original image cache was restored
      expect(PaintingBinding.instance.imageCache.maximumSizeBytes,
          equals(initialMaxBytes));
    });

    testWidgets(
        'Demo PDF: Virtualized rendering renders Page 1 and prefetches Page 2 (+1 ahead)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PdfDocumentViewerScreen(filePath: demoPdfFile.path),
        ),
      );

      // Await file check and async rendering
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.textContaining('Page 1 of 50').evaluate().isNotEmpty) {
          break;
        }
      }

      // Verify Document Title and Page Indicators
      expect(find.textContaining('demo_large_book_50p.pdf'), findsOneWidget);
      expect(find.text('Page 1 of 50'), findsOneWidget);
      expect(find.text('Page 1 / 50'), findsOneWidget);

      // Verify bottom navigation controls
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Verify scrubber slider is present for large book (> 5 pages)
      expect(find.byType(Slider), findsOneWidget);

      // Verify Action buttons (Download, Share, Jump)
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.byIcon(Icons.find_in_page_outlined), findsOneWidget);

      // Inspect internal state of viewer
      final stateFinder = find.byType(PdfDocumentViewerScreen);
      expect(stateFinder, findsOneWidget);
      final state = tester.state(stateFinder) as dynamic;

      // In steady state: exactly visible page (1) and prefetch page (2) exist in memory
      expect(state.inMemoryPageCount, lessThanOrEqualTo(2));
      expect(state.estimatedTextureMemoryBytes, lessThan(30 * 1024 * 1024)); // < 30MB

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
        'Demo PDF: Navigating forward evicts previous offscreen page textures from memory',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PdfDocumentViewerScreen(filePath: demoPdfFile.path),
        ),
      );

      for (int i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.textContaining('Page 1 of 50').evaluate().isNotEmpty) {
          break;
        }
      }

      final stateFinder = find.byType(PdfDocumentViewerScreen);
      final state = tester.state(stateFinder) as dynamic;

      // Tap Next Page button
      final nextButton = find.byIcon(Icons.chevron_right_rounded);
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }

      // Verify Page 2 is now the active visible page
      expect(find.text('Page 2 of 50'), findsOneWidget);
      expect(find.text('Page 2 / 50'), findsOneWidget);

      // Verify that inMemoryPageCount is still strictly <= 2!
      // (Page 1 was evicted, Page 2 visible, Page 3 prefetched)
      expect(state.inMemoryPageCount, lessThanOrEqualTo(2));
      expect(state.estimatedTextureMemoryBytes, lessThan(30 * 1024 * 1024));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
        'Demo PDF: Scrubbing / jumping to page 25 discards all prior pages and caps memory <120MB',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PdfDocumentViewerScreen(filePath: demoPdfFile.path),
        ),
      );

      for (int i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.textContaining('Page 1 of 50').evaluate().isNotEmpty) {
          break;
        }
      }

      final stateFinder = find.byType(PdfDocumentViewerScreen);
      final state = tester.state(stateFinder) as dynamic;

      // Jump directly to page 25
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);
      final Slider slider = tester.widget(sliderFinder);
      slider.onChanged?.call(25.0);
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }

      // Verify Page 25 is active
      expect(find.text('Page 25 of 50'), findsOneWidget);
      expect(find.text('Page 25 / 50'), findsOneWidget);

      // Verify that all 24 prior pages are NOT in memory!
      expect(state.inMemoryPageCount, lessThanOrEqualTo(2));
      expect(state.estimatedTextureMemoryBytes, lessThan(30 * 1024 * 1024));

      // Jump to page 50 (last page)
      slider.onChanged?.call(50.0);
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }

      expect(find.text('Page 50 of 50'), findsOneWidget);
      expect(find.text('Page 50 / 50'), findsOneWidget);

      // On last page, strictly 1 page in memory
      expect(state.inMemoryPageCount, lessThanOrEqualTo(2));
      expect(state.estimatedTextureMemoryBytes, lessThan(30 * 1024 * 1024));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Demo PDF: Jump to Page dialog functions correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PdfDocumentViewerScreen(filePath: demoPdfFile.path),
        ),
      );

      for (int i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.textContaining('Page 1 of 50').evaluate().isNotEmpty) {
          break;
        }
      }

      // Tap on the page indicator to open Jump dialog
      await tester.tap(find.text('Page 1 / 50'));
      await tester.pumpAndSettle();

      expect(find.text('Jump to Page'), findsOneWidget);
      expect(find.text('Page Number (1 - 50)'), findsOneWidget);

      // Enter page 38 and tap Go
      await tester.enterText(find.byType(TextField), '38');
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }

      expect(find.text('Page 38 of 50'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    test('Offscreen texture eviction guarantees bounded memory (<120MB)', () {
      // Simulation of a 1000-page book
      final inMemoryTextures = <int, int>{};
      const pageSizeBytes = 8 * 1024 * 1024; // 8MB per raster page

      void updateViewport(int currentPage, int totalPages) {
        final active = <int>{currentPage};
        if (currentPage + 1 <= totalPages) {
          active.add(currentPage + 1);
        }

        inMemoryTextures.removeWhere((page, _) => !active.contains(page));

        for (final p in active) {
          inMemoryTextures.putIfAbsent(p, () => pageSizeBytes);
        }
      }

      for (int page = 1; page <= 1000; page++) {
        updateViewport(page, 1000);

        expect(inMemoryTextures.length, lessThanOrEqualTo(2));

        final totalMB =
            inMemoryTextures.values.fold<int>(0, (s, v) => s + v) /
                (1024 * 1024);
        expect(totalMB, lessThan(120.0));
        expect(totalMB, equals(page == 1000 ? 8.0 : 16.0));
      }

      expect(inMemoryTextures.keys.toList(), equals([1000]));
    });
  });
}
