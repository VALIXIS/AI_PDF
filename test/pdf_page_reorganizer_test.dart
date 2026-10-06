import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';
import 'package:pdf_ai_toolkit/views/tools/pdf_page_reorganizer_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfService pdfService;
  late Directory tempDir;
  late String multiPagePdfPath;

  setUpAll(() async {
    pdfService = PdfService();
    tempDir = Directory.systemTemp.createTempSync('pdf_reorganizer_test_dir');

    // Create a 3-page test PDF
    final page1 = await pdfService.generatePdfFromText(
      title: 'Page 1 Title',
      content: 'First page content description.',
      customOutputPath: tempDir.path,
    );
    final page2 = await pdfService.generatePdfFromText(
      title: 'Page 2 Title',
      content: 'Second page content description.',
      customOutputPath: tempDir.path,
    );
    final page3 = await pdfService.generatePdfFromText(
      title: 'Page 3 Title',
      content: 'Third page content description.',
      customOutputPath: tempDir.path,
    );

    multiPagePdfPath = await pdfService.mergePdfs(
      [page1, page2, page3],
      customOutputPath: tempDir.path,
    );
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('PdfService.reorganizePdfPages Backend Engine Tests', () {
    test('Reorders pages correctly', () async {
      final outputPath = await pdfService.reorganizePdfPages(
        pdfPath: multiPagePdfPath,
        pages: const [
          PdfPageReorganizeItem(originalPageIndex: 2),
          PdfPageReorganizeItem(originalPageIndex: 0),
          PdfPageReorganizeItem(originalPageIndex: 1),
        ],
        customOutputPath: tempDir.path,
      );

      final file = File(outputPath);
      expect(await file.exists(), isTrue);
      expect(await pdfService.getPdfPageCount(outputPath), equals(3));

      final bytes = await file.readAsBytes();
      final doc = syncfusion.PdfDocument(inputBytes: bytes);
      try {
        expect(doc.pages.count, equals(3));
      } finally {
        doc.dispose();
      }
    });

    test('Rotates pages with custom angles', () async {
      final outputPath = await pdfService.reorganizePdfPages(
        pdfPath: multiPagePdfPath,
        pages: const [
          PdfPageReorganizeItem(originalPageIndex: 0, rotationAngle: 90),
          PdfPageReorganizeItem(originalPageIndex: 1, rotationAngle: 180),
          PdfPageReorganizeItem(originalPageIndex: 2, rotationAngle: 270),
        ],
        customOutputPath: tempDir.path,
      );

      final file = File(outputPath);
      expect(await file.exists(), isTrue);
      expect(await pdfService.getPdfPageCount(outputPath), equals(3));

      final bytes = await file.readAsBytes();
      final doc = syncfusion.PdfDocument(inputBytes: bytes);
      try {
        expect(doc.pages.count, equals(3));
        expect(doc.pages[0].rotation, equals(syncfusion.PdfPageRotateAngle.rotateAngle90));
        expect(doc.pages[1].rotation, equals(syncfusion.PdfPageRotateAngle.rotateAngle180));
        expect(doc.pages[2].rotation, equals(syncfusion.PdfPageRotateAngle.rotateAngle270));
      } finally {
        doc.dispose();
      }
    });

    test('Duplicates a page', () async {
      final outputPath = await pdfService.reorganizePdfPages(
        pdfPath: multiPagePdfPath,
        pages: const [
          PdfPageReorganizeItem(originalPageIndex: 0),
          PdfPageReorganizeItem(originalPageIndex: 0), // duplicated
          PdfPageReorganizeItem(originalPageIndex: 1),
        ],
        customOutputPath: tempDir.path,
      );

      final file = File(outputPath);
      expect(await file.exists(), isTrue);
      expect(await pdfService.getPdfPageCount(outputPath), equals(3));
    });

    test('Deletes a page by selecting subset', () async {
      final outputPath = await pdfService.reorganizePdfPages(
        pdfPath: multiPagePdfPath,
        pages: const [
          PdfPageReorganizeItem(originalPageIndex: 0),
          PdfPageReorganizeItem(originalPageIndex: 2),
        ],
        customOutputPath: tempDir.path,
      );

      final file = File(outputPath);
      expect(await file.exists(), isTrue);
      expect(await pdfService.getPdfPageCount(outputPath), equals(2));
    });

    test('Throws error for empty pages list', () async {
      expect(
        () => pdfService.reorganizePdfPages(
          pdfPath: multiPagePdfPath,
          pages: const [],
          customOutputPath: tempDir.path,
        ),
        throwsA(isA<PdfServiceException>()),
      );
    });

    test('Throws error for out-of-bound page index', () async {
      expect(
        () => pdfService.reorganizePdfPages(
          pdfPath: multiPagePdfPath,
          pages: const [
            PdfPageReorganizeItem(originalPageIndex: 99),
          ],
          customOutputPath: tempDir.path,
        ),
        throwsA(isA<PdfServiceException>()),
      );
    });

    test('Throws error for non-existent PDF file', () async {
      expect(
        () => pdfService.reorganizePdfPages(
          pdfPath: '${tempDir.path}/non_existent.pdf',
          pages: const [
            PdfPageReorganizeItem(originalPageIndex: 0),
          ],
        ),
        throwsA(isA<PdfServiceException>()),
      );
    });
  });

  group('PdfPageReorganizerScreen UI Widget Tests', () {
    testWidgets('Renders empty state when no PDF is provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfPageReorganizerScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Reorganize & Rotate Pages'), findsOneWidget);
      expect(find.text('Visual 3D Page Grid'), findsOneWidget);
      expect(find.text('Select PDF to Reorganize'), findsOneWidget);
    });

    testWidgets('Loads PDF and renders multi-page cards with action buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: PdfPageReorganizerScreen(),
        ),
      );
      await tester.pump();

      final state = tester.state<PdfPageReorganizerScreenState>(
          find.byType(PdfPageReorganizerScreen));
      await tester.runAsync(() async {
        await state.loadPdf(multiPagePdfPath);
      });
      await tester.pump();

      // Check header info
      expect(find.text('3 pages total'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Page 3'), findsOneWidget);

      // Check action buttons
      expect(find.text('Rotate 90°'), findsWidgets);
      expect(find.text('Duplicate'), findsWidgets);
      expect(find.text('Save & Export PDF'), findsOneWidget);
    });

    testWidgets('Rotates single page on tap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: PdfPageReorganizerScreen(),
        ),
      );
      await tester.pump();

      final state = tester.state<PdfPageReorganizerScreenState>(
          find.byType(PdfPageReorganizerScreen));
      await tester.runAsync(() async {
        await state.loadPdf(multiPagePdfPath);
      });
      await tester.pump();

      // Tap first Rotate 90° button
      final rotateButtons = find.text('Rotate 90°');
      await tester.tap(rotateButtons.first);
      await tester.pump();

      expect(find.text('90°'), findsOneWidget);
      expect(find.text('3 pages total • 1 rotated'), findsOneWidget);
    });

    testWidgets('Duplicates page on tap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: PdfPageReorganizerScreen(),
        ),
      );
      await tester.pump();

      final state = tester.state<PdfPageReorganizerScreenState>(
          find.byType(PdfPageReorganizerScreen));
      await tester.runAsync(() async {
        await state.loadPdf(multiPagePdfPath);
      });
      await tester.pump();

      // Tap first Duplicate button
      final duplicateButtons = find.text('Duplicate');
      await tester.tap(duplicateButtons.first);
      await tester.pump();

      // Now we should have 4 pages
      expect(find.text('4 pages total • page count modified'), findsOneWidget);
      expect(find.text('Page 4'), findsOneWidget);
    });

    testWidgets('Deletes page on badge tap with undo',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: PdfPageReorganizerScreen(),
        ),
      );
      await tester.pump();

      final state = tester.state<PdfPageReorganizerScreenState>(
          find.byType(PdfPageReorganizerScreen));
      await tester.runAsync(() async {
        await state.loadPdf(multiPagePdfPath);
      });
      await tester.pump();

      // Tap first delete icon
      final deleteIcons = find.byIcon(Icons.delete_outline_rounded);
      await tester.tap(deleteIcons.first);
      await tester.pump();

      // Should have 2 pages and snackbar
      expect(find.text('Page 1 deleted'), findsOneWidget);
      expect(find.byType(SnackBarAction), findsOneWidget);
      expect(find.text('2 pages total • page count modified'), findsOneWidget);

      // Tap UNDO
      final undoAction = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
      undoAction.onPressed();
      await tester.pump();

      expect(find.text('3 pages total'), findsOneWidget);
    });

    testWidgets('Rotates all pages 90° via app bar action',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: PdfPageReorganizerScreen(),
        ),
      );
      await tester.pump();

      final state = tester.state<PdfPageReorganizerScreenState>(
          find.byType(PdfPageReorganizerScreen));
      await tester.runAsync(() async {
        await state.loadPdf(multiPagePdfPath);
      });
      await tester.pump();

      final rotateAllBtn = find.byIcon(Icons.rotate_90_degrees_cw_rounded);
      await tester.tap(rotateAllBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Rotated all pages 90° clockwise'), findsOneWidget);
      expect(find.text('3 pages total • 3 rotated'), findsOneWidget);
    });

    testWidgets('Resets all modifications on Reset button tap',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: PdfPageReorganizerScreen(),
        ),
      );
      await tester.pump();

      final state = tester.state<PdfPageReorganizerScreenState>(
          find.byType(PdfPageReorganizerScreen));
      await tester.runAsync(() async {
        await state.loadPdf(multiPagePdfPath);
      });
      await tester.pump();

      // Rotate all
      final rotateAllBtn = find.byIcon(Icons.rotate_90_degrees_cw_rounded);
      await tester.tap(rotateAllBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('3 pages total • 3 rotated'), findsOneWidget);

      // Tap reset
      final resetBtn = find.byIcon(Icons.restore_rounded);
      await tester.tap(resetBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Reset all pages to original order'), findsOneWidget);
      expect(find.text('3 pages total'), findsOneWidget);
    });

    testWidgets('Prevents deleting the last remaining page',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: PdfPageReorganizerScreen(),
        ),
      );
      await tester.pump();

      final state = tester.state<PdfPageReorganizerScreenState>(
          find.byType(PdfPageReorganizerScreen));
      await tester.runAsync(() async {
        await state.loadPdf(multiPagePdfPath);
      });
      await tester.pump();

      // Delete page 1
      var deleteIcons = find.byIcon(Icons.delete_outline_rounded);
      await tester.tap(deleteIcons.first);
      await tester.pump();

      // Delete page 2 (now first)
      deleteIcons = find.byIcon(Icons.delete_outline_rounded);
      await tester.tap(deleteIcons.first);
      await tester.pump();

      // Now only 1 page remains
      expect(find.text('1 pages total • page count modified'), findsOneWidget);

      // Attempt to delete last page
      deleteIcons = find.byIcon(Icons.delete_outline_rounded);
      await tester.tap(deleteIcons.first);
      await tester.pump();

      expect(find.text('Cannot delete the last remaining page.'), findsOneWidget);
      expect(find.text('1 pages total • page count modified'), findsOneWidget);
    });

    testWidgets('Full 360 degree rotation returns to 0 degrees',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: PdfPageReorganizerScreen(),
        ),
      );
      await tester.pump();

      final state = tester.state<PdfPageReorganizerScreenState>(
          find.byType(PdfPageReorganizerScreen));
      await tester.runAsync(() async {
        await state.loadPdf(multiPagePdfPath);
      });
      await tester.pump();

      final rotateBtn = find.text('Rotate 90°').first;

      // 1st rotate -> 90°
      await tester.tap(rotateBtn);
      await tester.pump();
      expect(find.text('90°'), findsOneWidget);

      // 2nd rotate -> 180°
      await tester.tap(rotateBtn);
      await tester.pump();
      expect(find.text('180°'), findsOneWidget);

      // 3rd rotate -> 270°
      await tester.tap(rotateBtn);
      await tester.pump();
      expect(find.text('270°'), findsOneWidget);

      // 4th rotate -> 0° (badge disappears)
      await tester.tap(rotateBtn);
      await tester.pump();
      expect(find.text('270°'), findsNothing);
      expect(find.text('3 pages total'), findsOneWidget);
    });
  });
}
