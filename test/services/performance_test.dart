import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/models/pdf_annotation.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:hive/hive.dart';

void main() {
  late PdfService pdfService;
  late StorageService storageService;
  late Directory tempDir;

  setUp(() async {
    pdfService = PdfService();
    storageService = StorageService();
    tempDir = Directory.systemTemp.createTempSync('performance_test_dir');

    // Initialize Hive for StorageService
    final hiveDir = Directory('${tempDir.path}/hive');
    hiveDir.createSync();
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }
    await Hive.openBox<HistoryEntry>('historyBox');
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Helper to create a dummy image of specific dimensions in bytes (approximate)
  File createDummyImage(String fileName, {int sizeInMB = 1}) {
    final file = File('${tempDir.path}/$fileName');
    // Just writing random bytes isn't a valid PNG/JPG, so we might need a real valid image format
    // For performance testing large images to PDF, if the PDF renderer parses the image,
    // we need valid image bytes. We will use a valid tiny PNG but repeat it in the list to simulate
    // multi-page image conversions.
    final validPngBytes = Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      6,
      0,
      0,
      0,
      31,
      21,
      196,
      137,
      0,
      0,
      0,
      10,
      73,
      68,
      65,
      84,
      120,
      156,
      99,
      0,
      1,
      0,
      0,
      5,
      0,
      1,
      13,
      10,
      45,
      180,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130
    ]);
    file.writeAsBytesSync(validPngBytes);
    return file;
  }

  void printPerf(String task, Stopwatch watch, int startRss) {
    final endRss = ProcessInfo.currentRss;
    final diffMB = (endRss - startRss) / (1024 * 1024);
    debugPrint(
        'PERF: $task took ${watch.elapsedMilliseconds}ms, Memory delta: ${diffMB.toStringAsFixed(2)}MB');
  }

  group('Performance Tests', () {
    test('Large Text to PDF Conversion', () async {
      final largeText = List.generate(
              5000,
              (i) =>
                  'This is line $i of a very large text document to test PDF generation performance.')
          .join('\n');

      final watch = Stopwatch()..start();
      final startRss = ProcessInfo.currentRss;

      final pdfPath = await pdfService.generatePdfFromText(
        title: 'Large Document',
        content: largeText,
        customOutputPath: tempDir.path,
      );

      watch.stop();
      printPerf('Large Text to PDF', watch, startRss);

      final file = File(pdfPath);
      expect(await file.exists(), isTrue);
      // Ensure we measure time for a reasonable execution, e.g. should not take forever
      expect(watch.elapsedMilliseconds, lessThan(10000));
    });

    test('Merge Many PDFs (Multi-page PDF generation)', () async {
      final basePdf = await pdfService.generatePdfFromText(
        title: 'Base PDF',
        content: 'Single page content.',
        customOutputPath: tempDir.path,
      );

      // Simulate merging 50 pages
      final pdfPaths = List.filled(50, basePdf);

      final watch = Stopwatch()..start();
      final startRss = ProcessInfo.currentRss;

      final mergedPath = await pdfService.mergePdfs(
        pdfPaths,
        customOutputPath: tempDir.path,
      );

      watch.stop();
      printPerf('Merge 50 PDFs', watch, startRss);

      final file = File(mergedPath);
      expect(await file.exists(), isTrue);
      expect(await pdfService.getPdfPageCount(mergedPath), equals(50));
    });

    test('Large Image List to PDF (50 images)', () async {
      final img = createDummyImage('dummy.png');
      final imagePaths = List.filled(50, img.path);

      final watch = Stopwatch()..start();
      final startRss = ProcessInfo.currentRss;

      final pdfPath = await pdfService.convertImagesToPdf(
        imagePaths: imagePaths,
        customOutputPath: tempDir.path,
      );

      watch.stop();
      printPerf('50 Images to PDF', watch, startRss);

      final file = File(pdfPath);
      expect(await file.exists(), isTrue);
      expect(await pdfService.getPdfPageCount(pdfPath), equals(50));
    });

    test('PDF Editor Memory Usage (Heavy Annotations)', () async {
      final basePdf = await pdfService.generatePdfFromText(
        title: 'Base PDF',
        content: 'Content',
        customOutputPath: tempDir.path,
      );

      // Add 1000 annotations to a single page
      final annotations = <Annotation>[];
      for (int i = 0; i < 1000; i++) {
        annotations.add(Annotation.text(
          id: i.toString(),
          x: (i % 100) / 100,
          y: (i % 100) / 100,
          text: 'Ann \$i',
        ));
      }

      final watch = Stopwatch()..start();
      final startRss = ProcessInfo.currentRss;

      final editedPath = await pdfService.saveEditedPdf(
        sourcePdfPath: basePdf,
        annotationsByPage: {0: annotations},
        customOutputPath: tempDir.path,
      );

      watch.stop();
      printPerf('Save 1000 Annotations', watch, startRss);

      final file = File(editedPath);
      expect(await file.exists(), isTrue);
    });

    test('Document History Heavy Load (1000 entries)', () async {
      final watch = Stopwatch()..start();
      final startRss = ProcessInfo.currentRss;

      for (int i = 0; i < 1000; i++) {
        final dummyPdf = File('${tempDir.path}/history_dummy_$i.pdf')
          ..writeAsStringSync('%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>');
        final entry = HistoryEntry(
          id: 'hist_$i',
          title: 'Doc $i',
          date: DateTime.now(),
          filePath: dummyPdf.path,
          toolType: 'merge',
        );
        await storageService.addHistoryEntry(entry);
      }

      final count = await storageService.getHistoryCount();
      expect(count, equals(1000));

      // Test read performance
      final watchRead = Stopwatch()..start();
      await storageService.getHistoryEntriesSortedByDate();
      watchRead.stop();

      watch.stop();
      printPerf('Storage 1000 Entries (Write+Read)', watch, startRss);
      debugPrint(
          'PERF: Read 1000 Entries took \${watchRead.elapsedMilliseconds}ms');
    });
  });
}
