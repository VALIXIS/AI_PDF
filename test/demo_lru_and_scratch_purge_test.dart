// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_cache_service.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider for Flutter test environment
  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    channel,
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  group('Demo PDF - End-to-End LRU Bitmap Cache & Scratch Purge Verification', () {
    final cacheService = PdfCacheService();
    final fileService = FileService();
    late File demoPdfFile;
    late Directory testTempDir;

    setUpAll(() async {
      testTempDir = Directory.systemTemp.createTempSync('demo_test_suite_');

      // Create a 5-page real demo PDF for the test suite
      final pdfDoc = pw.Document();
      for (int i = 1; i <= 5; i++) {
        pdfDoc.addPage(
          pw.Page(
            build: (pw.Context ctx) => pw.Center(
              child: pw.Text('Demo Document Page $i',
                  style: const pw.TextStyle(fontSize: 24)),
            ),
          ),
        );
      }
      demoPdfFile = File('${testTempDir.path}/demo_sample.pdf');
      await demoPdfFile.writeAsBytes(await pdfDoc.save());
      print('\n========================================');
      print('Created Demo PDF: ${demoPdfFile.path}');
      print('Demo PDF Size: ${await demoPdfFile.length()} bytes');
      print('========================================');
    });

    tearDownAll(() {
      try {
        if (testTempDir.existsSync()) {
          testTempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Verify demo PDF file and text caching', () async {
      expect(await demoPdfFile.exists(), isTrue);

      final isPdf = await fileService.isPdfFile(demoPdfFile.path);
      expect(isPdf, isTrue);

      final data = await cacheService.getPdfData(demoPdfFile.path);
      expect(data.pageCount, equals(5));
      expect(data.textContent, contains('Demo'));
      expect(data.textContent, contains('Page'));
      print('Demo PDF verified: ${demoPdfFile.path}');
      print('Extracted Page Count: ${data.pageCount}');
    });

    test('2. Verify LRU Cache Eviction Policy for Cached Page Bitmaps', () {
      cacheService.clearPageBitmapCache();
      cacheService.maxBitmapEntries = 3; // Limit to 3 pages in RAM

      // Simulate rasterized page bitmaps (e.g. 100 KB each)
      final page1Bytes = Uint8List.fromList(List.filled(1024 * 100, 1));
      final page2Bytes = Uint8List.fromList(List.filled(1024 * 100, 2));
      final page3Bytes = Uint8List.fromList(List.filled(1024 * 100, 3));
      final page4Bytes = Uint8List.fromList(List.filled(1024 * 100, 4));

      print('\n--- Testing LRU Cache Eviction ---');
      // Step A: Cache pages 1, 2, 3
      cacheService.cachePageBitmap(
          pdfPath: demoPdfFile.path, pageNumber: 1, bytes: page1Bytes);
      cacheService.cachePageBitmap(
          pdfPath: demoPdfFile.path, pageNumber: 2, bytes: page2Bytes);
      cacheService.cachePageBitmap(
          pdfPath: demoPdfFile.path, pageNumber: 3, bytes: page3Bytes);

      expect(cacheService.pageBitmapCacheCount, equals(3));
      print('Cached Pages 1, 2, 3 -> Cache count: ${cacheService.pageBitmapCacheCount}');

      // Step B: User navigates back to Page 1 (hit: page 1 becomes Most Recently Used)
      final hitPage1 =
          cacheService.getPageBitmap(demoPdfFile.path, 1);
      expect(hitPage1, isNotNull);
      print('User viewed Page 1 again -> Page 1 is now Most Recently Used (MRU)');
      print('Current LRU-to-MRU order: Page 2, Page 3, Page 1');

      // Step C: User scrolls to Page 4 -> Capacity limit (3) exceeded!
      // LRU policy MUST evict Page 2, NOT Page 1!
      cacheService.cachePageBitmap(
          pdfPath: demoPdfFile.path, pageNumber: 4, bytes: page4Bytes);

      expect(cacheService.pageBitmapCacheCount, equals(3));
      expect(cacheService.getPageBitmap(demoPdfFile.path, 2), isNull); // Evicted!
      expect(cacheService.getPageBitmap(demoPdfFile.path, 1), isNotNull); // Kept!
      expect(cacheService.getPageBitmap(demoPdfFile.path, 3), isNotNull); // Kept!
      expect(cacheService.getPageBitmap(demoPdfFile.path, 4), isNotNull); // Kept!

      print('SUCCESS: Page 2 was evicted (least recently used).');
      print('SUCCESS: Page 1, Page 3, and Page 4 are safely kept in RAM.');

      // Reset default limit
      cacheService.maxBitmapEntries = 50;
    });

    test('3. Verify Scratch Export Directory Creation & Writing', () async {
      print('\n--- Testing Scratch Export Directory Generation ---');
      final scratchDir = await fileService.getScratchExportDirectory(subDir: 'demo_export');
      expect(await scratchDir.exists(), isTrue);
      print('Scratch Export Directory created at: ${scratchDir.path}');

      // Simulate a tool exporting converted images/pages from the demo PDF
      final scratchImg1 = await fileService.createScratchFilePath(
        prefix: 'demo_page_1',
        extension: 'png',
        subDir: 'demo_export',
      );
      final scratchImg2 = await fileService.createScratchFilePath(
        prefix: 'demo_page_2',
        extension: 'png',
        subDir: 'demo_export',
      );
      final scratchMerged = await fileService.createScratchFilePath(
        prefix: 'demo_merged',
        extension: 'pdf',
        subDir: 'demo_export',
      );

      await File(scratchImg1).writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
      await File(scratchImg2).writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
      await File(scratchMerged).writeAsString('%PDF-1.4 mock merged demo');

      expect(await File(scratchImg1).exists(), isTrue);
      expect(await File(scratchImg2).exists(), isTrue);
      expect(await File(scratchMerged).exists(), isTrue);

      print('Exported temporary files created:');
      print('  1. $scratchImg1');
      print('  2. $scratchImg2');
      print('  3. $scratchMerged');
    });

    test('4. Verify Purging of Scratch Directories Whenever User Exits Tool or Viewer', () async {
      print('\n--- Testing Purge on Tool / Viewer Exit ---');

      // Ensure scratch files exist before exit
      final scratchDir = await fileService.getScratchExportDirectory(subDir: 'demo_export');
      final scratchTestFile = File('${scratchDir.path}/scratch_active_export.pdf');
      await scratchTestFile.writeAsString('%PDF-1.4 temporary active file');
      expect(await scratchTestFile.exists(), isTrue);

      // Also ensure bitmap cache has active pages for this demo PDF
      cacheService.cachePageBitmap(
        pdfPath: demoPdfFile.path,
        pageNumber: 1,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(cacheService.getPageBitmap(demoPdfFile.path, 1), isNotNull);

      // Create a simulated permanent user-saved file to verify it is NEVER touched
      final permanentSavedFile = File('${testTempDir.path}/Permanent_Saved_User_Doc.pdf');
      await permanentSavedFile.writeAsString('%PDF-1.4 permanent saved copy');
      expect(await permanentSavedFile.exists(), isTrue);

      // --- USER EXITS TOOL / VIEWER ---
      print('Simulating user exiting tool / viewer...');
      final purgedCount = await cacheService.onToolOrViewerExit(pdfPath: demoPdfFile.path);
      print('Purge completed! Purged items count: $purgedCount');

      // VERIFICATIONS:
      // A. Scratch export files must be deleted
      expect(await scratchTestFile.exists(), isFalse);
      expect(await scratchDir.exists(), isFalse);
      print('SUCCESS: Scratch export directory and working files were completely purged.');

      // B. Cached bitmaps for the exited PDF must be invalidated
      expect(cacheService.getPageBitmap(demoPdfFile.path, 1), isNull);
      print('SUCCESS: Document page bitmaps in RAM were invalidated.');

      // C. Permanent user-saved documents must NEVER be deleted
      expect(await permanentSavedFile.exists(), isTrue);
      print('SUCCESS: Permanent user-saved document remained 100% untouched and safe.');
      print('========================================\n');
    });
  });
}
