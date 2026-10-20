import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pdf_ai_toolkit/services/pdf_cache_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    channel,
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  group('PdfCacheService & Resource Optimization Tests', () {
    final cacheService = PdfCacheService();
    final fileService = FileService();

    test('getPdfData caches PDF content in memory for fast retrieval',
        () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final pdfFile = File('${tempDir.path}/cache_test.pdf');

      final pdf = pw.Document();
      pdf.addPage(pw.Page(
          build: (pw.Context context) => pw.Text('Cache Test Content')));
      await pdfFile.writeAsBytes(await pdf.save());

      // 1. Initial fetch (cache miss)
      final firstFetch = await cacheService.getPdfData(pdfFile.path);
      expect(firstFetch.pageCount, equals(1));
      expect(cacheService.cacheSize, greaterThan(0));

      // 2. Second fetch (instant cache hit)
      final secondFetch = await cacheService.getPdfData(pdfFile.path);
      expect(secondFetch.pageCount, equals(1));

      cacheService.invalidate(pdfFile.path);
      tempDir.deleteSync(recursive: true);
    });

    test('cleanupTempResources runs safely without throwing exceptions',
        () async {
      final deleted = await fileService.cleanupTempResources();
      expect(deleted, greaterThanOrEqualTo(0));
    });

    test('cachePageBitmap stores and retrieves bitmaps using LRU policy', () {
      cacheService.clearPageBitmapCache();
      const testPdf = '/path/to/test.pdf';
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      cacheService.cachePageBitmap(
        pdfPath: testPdf,
        pageNumber: 1,
        bytes: bytes,
        scale: 1.0,
      );

      final retrieved = cacheService.getPageBitmap(testPdf, 1, scale: 1.0);
      expect(retrieved, isNotNull);
      expect(retrieved, equals(bytes));
      expect(cacheService.pageBitmapCacheCount, equals(1));
      expect(cacheService.pageBitmapCacheBytes, equals(5));

      final entry = cacheService.getCachedPageBitmap(testPdf, 1, scale: 1.0);
      expect(entry, isNotNull);
      expect(entry!.pageNumber, equals(1));
      expect(entry.scale, equals(1.0));
    });

    test('LRU eviction policy evicts least recently used bitmaps on count limit', () {
      cacheService.clearPageBitmapCache();
      cacheService.maxBitmapEntries = 3;
      const testPdf = '/doc/sample.pdf';

      final b1 = Uint8List.fromList([10]);
      final b2 = Uint8List.fromList([20]);
      final b3 = Uint8List.fromList([30]);
      final b4 = Uint8List.fromList([40]);

      cacheService.cachePageBitmap(pdfPath: testPdf, pageNumber: 1, bytes: b1);
      cacheService.cachePageBitmap(pdfPath: testPdf, pageNumber: 2, bytes: b2);
      cacheService.cachePageBitmap(pdfPath: testPdf, pageNumber: 3, bytes: b3);

      expect(cacheService.pageBitmapCacheCount, equals(3));

      // Access page 1 so it becomes MRU. Current order from LRU to MRU: 2, 3, 1
      final p1 = cacheService.getPageBitmap(testPdf, 1);
      expect(p1, isNotNull);

      // Now add page 4: page 2 is the LRU and should be evicted!
      cacheService.cachePageBitmap(pdfPath: testPdf, pageNumber: 4, bytes: b4);

      expect(cacheService.pageBitmapCacheCount, equals(3));
      expect(cacheService.getPageBitmap(testPdf, 2), isNull); // evicted!
      expect(cacheService.getPageBitmap(testPdf, 1), isNotNull); // kept!
      expect(cacheService.getPageBitmap(testPdf, 3), isNotNull); // kept!
      expect(cacheService.getPageBitmap(testPdf, 4), isNotNull); // newly added!

      // Reset default limit
      cacheService.maxBitmapEntries = 50;
    });

    test('LRU eviction policy evicts least recently used bitmaps on byte limit', () {
      cacheService.clearPageBitmapCache();
      cacheService.maxBitmapEntries = 10;
      cacheService.maxBitmapBytes = 100; // 100 bytes max

      const testPdf = '/doc/bytes_test.pdf';
      final b1 = Uint8List(40); // 40 bytes
      final b2 = Uint8List(40); // 40 bytes
      final b3 = Uint8List(40); // 40 bytes -> total 120 > 100, b1 must be evicted!

      cacheService.cachePageBitmap(pdfPath: testPdf, pageNumber: 1, bytes: b1);
      cacheService.cachePageBitmap(pdfPath: testPdf, pageNumber: 2, bytes: b2);
      expect(cacheService.pageBitmapCacheBytes, equals(80));

      cacheService.cachePageBitmap(pdfPath: testPdf, pageNumber: 3, bytes: b3);
      // b1 should be evicted, remaining b2 (40) + b3 (40) = 80 bytes <= 100
      expect(cacheService.pageBitmapCacheBytes, equals(80));
      expect(cacheService.getPageBitmap(testPdf, 1), isNull);
      expect(cacheService.getPageBitmap(testPdf, 2), isNotNull);
      expect(cacheService.getPageBitmap(testPdf, 3), isNotNull);

      // Reset default limits
      cacheService.maxBitmapBytes = 64 * 1024 * 1024;
      cacheService.maxBitmapEntries = 50;
    });

    test('invalidatePageBitmaps and invalidatePageBitmap remove entries correctly', () {
      cacheService.clearPageBitmapCache();
      const pdf1 = '/path/pdf1.pdf';
      const pdf2 = '/path/pdf2.pdf';

      cacheService.cachePageBitmap(pdfPath: pdf1, pageNumber: 1, bytes: Uint8List(10));
      cacheService.cachePageBitmap(pdfPath: pdf1, pageNumber: 2, bytes: Uint8List(10));
      cacheService.cachePageBitmap(pdfPath: pdf2, pageNumber: 1, bytes: Uint8List(10));

      expect(cacheService.pageBitmapCacheCount, equals(3));

      // Invalidate specific page
      cacheService.invalidatePageBitmap(pdf1, 1);
      expect(cacheService.getPageBitmap(pdf1, 1), isNull);
      expect(cacheService.getPageBitmap(pdf1, 2), isNotNull);

      // Invalidate all pages of pdf1
      cacheService.invalidatePageBitmaps(pdf1);
      expect(cacheService.getPageBitmap(pdf1, 2), isNull);
      expect(cacheService.getPageBitmap(pdf2, 1), isNotNull);

      // Clear all bitmaps
      cacheService.clearPageBitmapCache();
      expect(cacheService.pageBitmapCacheCount, equals(0));
      expect(cacheService.pageBitmapCacheBytes, equals(0));
    });

    test('onToolOrViewerExit purges scratch directories and cleans bitmaps', () async {
      cacheService.clearPageBitmapCache();
      const pdf = '/path/sample_doc.pdf';
      cacheService.cachePageBitmap(pdfPath: pdf, pageNumber: 1, bytes: Uint8List(20));

      // Create a scratch file
      final scratchFile = await fileService.createScratchFilePath(
        prefix: 'test_scratch',
        extension: 'pdf',
      );
      await File(scratchFile).writeAsString('temporary scratch export');
      expect(await File(scratchFile).exists(), isTrue);

      // Exit viewer for this pdf
      final deletedCount = await cacheService.onToolOrViewerExit(pdfPath: pdf);
      expect(deletedCount, greaterThan(0));
      expect(await File(scratchFile).exists(), isFalse);
      expect(cacheService.getPageBitmap(pdf, 1), isNull);
    });
  });
}
