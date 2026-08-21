import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pdf_ai_toolkit/services/pdf_cache_service.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  group('PdfCacheService & Resource Optimization Tests', () {
    final cacheService = PdfCacheService();
    final fileService = FileService();

    test('getPdfData caches PDF content in memory for fast retrieval', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final pdfFile = File('${tempDir.path}/cache_test.pdf');

      final pdf = pw.Document();
      pdf.addPage(pw.Page(build: (pw.Context context) => pw.Text('Cache Test Content')));
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

    test('cleanupTempResources runs safely without throwing exceptions', () async {
      final deleted = await fileService.cleanupTempResources();
      expect(deleted, greaterThanOrEqualTo(0));
    });
  });
}
