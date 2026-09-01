import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';

import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;

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

  group('Centralized AppException Suite', () {
    test('PdfServiceException formats code and details correctly', () {
      final exc = PdfServiceException('PDF rendering failed',
          code: 'RENDER_ERR', details: 'Null stream');
      expect(exc.message, equals('PDF rendering failed'));
      expect(exc.code, equals('RENDER_ERR'));
      expect(exc.details, equals('Null stream'));
      expect(exc.toString(), equals('PDF rendering failed'));
    });

    test('FileStorageException formats default error code', () {
      final exc = FileStorageException('Access denied');
      expect(exc.message, equals('Access denied'));
      expect(exc.code, equals('FILE_STORAGE_ERROR'));
    });

    test('AiServiceException formats default error code', () {
      final exc = AiServiceException('API key missing');
      expect(exc.message, equals('API key missing'));
      expect(exc.code, equals('AI_SERVICE_ERROR'));
    });
  });

  group('Temp File Cleanup & Compression Engine Tests', () {
    test('cleanOrphanedTempFiles runs safely without throwing exceptions',
        () async {
      final deleted = await FileService().cleanOrphanedTempFiles();
      expect(deleted, isA<int>());
      expect(deleted, greaterThanOrEqualTo(0));
    });

    test('compressPdf throws PdfServiceException on non-existent file',
        () async {
      expect(
        () => PdfService().compressPdf('/tmp/non_existent_file_12345.pdf'),
        throwsA(isA<PdfServiceException>()),
      );
    });

    test('compressPdf executes real compression on valid sample PDF', () async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_compress_test_');
      try {
        // Generate valid PDF using generatePdfFromText
        final generatedPath = await PdfService().generatePdfFromText(
          title: 'Compression Architecture Test',
          content: 'Testing high-efficiency stream compression engine.\n' * 50,
        );

        final compressedPath = await PdfService().compressPdf(
          generatedPath,
          customOutputPath: tempDir.path,
        );

        expect(File(compressedPath).existsSync(), isTrue);
        expect(File(compressedPath).lengthSync(), greaterThan(0));

        // Clean up sample generated file
        await File(generatedPath).delete();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        'compressPdf reduces file size of an uncompressed PDF and does not copy bytes',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_compress_test_');
      try {
        // Create an uncompressed PDF document with multiple pages and distinct content
        final pdf = pw.Document(compress: false);
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Center(
              child: pw.Text(
                  'Page One - Testing high-efficiency stream compression engine.\n' *
                      50),
            ),
          ),
        );
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Center(
              child: pw.Text(
                  'Page Two - Testing high-efficiency stream compression engine.\n' *
                      50),
            ),
          ),
        );

        final inputPath = '${tempDir.path}/uncompressed.pdf';
        final inputFile = File(inputPath);
        await inputFile.writeAsBytes(await pdf.save());
        final originalSize = inputFile.lengthSync();
        final originalBytes = await inputFile.readAsBytes();

        // Perform compression
        final compressedPath = await PdfService().compressPdf(
          inputPath,
          customOutputPath: tempDir.path,
        );
        final compressedFile = File(compressedPath);
        final compressedSize = compressedFile.lengthSync();

        // 1. Verify output file exists and is non-empty
        expect(compressedFile.existsSync(), isTrue);
        expect(compressedSize, greaterThan(0));

        // 2. Verify that the output is not a simple file copy (bytes are different)
        final compressedBytes = await compressedFile.readAsBytes();
        expect(compressedBytes, isNot(equals(originalBytes)));

        // 3. Verify that the compressed file size is strictly smaller than the uncompressed original
        expect(compressedSize, lessThan(originalSize));

        // 4. Verify that the original input remains unchanged (bytes and length are identical)
        final originalBytesAfter = await inputFile.readAsBytes();
        expect(originalBytesAfter, equals(originalBytes));
        expect(inputFile.lengthSync(), equals(originalSize));

        // 5. Verify the output is a valid PDF that can be reopened and read
        final syncfusion.PdfDocument outputDoc =
            syncfusion.PdfDocument(inputBytes: compressedBytes);
        try {
          // 6. Verify page count is preserved
          expect(outputDoc.pages.count, equals(2));

          // 7. Verify page order is preserved & content remains usable
          final syncfusion.PdfTextExtractor extractor =
              syncfusion.PdfTextExtractor(outputDoc);
          final String extractedText = extractor.extractText();
          final String normalizedText =
              extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();
          expect(normalizedText.contains('Page One'), isTrue);
          expect(normalizedText.contains('Page Two'), isTrue);
          final firstIdx = normalizedText.indexOf('Page One');
          final secondIdx = normalizedText.indexOf('Page Two');
          expect(firstIdx < secondIdx, isTrue);
        } finally {
          outputDoc.dispose();
        }

        // Clean up
        await inputFile.delete();
        await compressedFile.delete();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('compressPdf supports low, medium, and high levels with genuine size reduction', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('pdf_compress_test_levels_');
      try {
        final pdf = pw.Document(compress: false);
        for (int p = 0; p < 3; p++) {
          pdf.addPage(
            pw.Page(
              build: (context) => pw.Column(
                children: List.generate(
                  30,
                  (i) => pw.Text('Page $p Line $i: Testing high-efficiency stream compression engine.\n' * 2),
                ),
              ),
            ),
          );
        }

        final inputPath = '${tempDir.path}/uncompressed_levels.pdf';
        final inputFile = File(inputPath);
        final uncompressedBytes = await pdf.save();
        await inputFile.writeAsBytes(uncompressedBytes);
        final originalSize = inputFile.lengthSync();

        final lowPath = await PdfService().compressPdf(inputPath,
            customOutputPath: tempDir.path, compressionLevel: 'low');
        final mediumPath = await PdfService().compressPdf(inputPath,
            customOutputPath: tempDir.path, compressionLevel: 'medium');
        final highPath = await PdfService().compressPdf(inputPath,
            customOutputPath: tempDir.path, compressionLevel: 'high');

        final lowFile = File(lowPath);
        final mediumFile = File(mediumPath);
        final highFile = File(highPath);

        final lowSize = lowFile.lengthSync();
        final mediumSize = mediumFile.lengthSync();
        final highSize = highFile.lengthSync();

        // 1. All output files must exist and be non-empty
        expect(lowSize, greaterThan(0));
        expect(mediumSize, greaterThan(0));
        expect(highSize, greaterThan(0));

        // 2. All compression levels must achieve genuine size reduction over uncompressed original
        expect(lowSize, lessThan(originalSize));
        expect(mediumSize, lessThan(originalSize));
        expect(highSize, lessThan(originalSize));

        // 3. Progressive level hierarchy: High <= Medium <= Low
        expect(highSize, lessThanOrEqualTo(mediumSize));
        expect(mediumSize, lessThanOrEqualTo(lowSize));

        // 4. Validate output PDFs are valid, readable, and preserve all 3 pages
        for (final file in [lowFile, mediumFile, highFile]) {
          final doc = syncfusion.PdfDocument(inputBytes: await file.readAsBytes());
          try {
            expect(doc.pages.count, equals(3));
            final text = syncfusion.PdfTextExtractor(doc).extractText();
            final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
            expect(normalized.contains('Page 0'), isTrue);
            expect(normalized.contains('Page 1'), isTrue);
            expect(normalized.contains('Page 2'), isTrue);
          } finally {
            doc.dispose();
          }
        }

        // 5. Verify original input remains untouched
        expect(inputFile.lengthSync(), equals(originalSize));
        expect(await inputFile.readAsBytes(), equals(uncompressedBytes));

        // 6. Verify honest reduction calculation
        final bytesSavedLow = originalSize - lowSize;
        final percentLow = (bytesSavedLow / originalSize * 100);
        expect(bytesSavedLow, greaterThan(0));
        expect(percentLow, greaterThan(0.0));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('compressPdf throws PdfServiceException on empty input file',
        () async {
      final tempDir =
          Directory.systemTemp.createTempSync('pdf_compress_empty_');
      try {
        final emptyFile = File('${tempDir.path}/empty.pdf');
        await emptyFile.writeAsBytes([]);

        await expectLater(
          PdfService()
              .compressPdf(emptyFile.path, customOutputPath: tempDir.path),
          throwsA(isA<PdfServiceException>()),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('compressPdf throws PdfServiceException on corrupt input file',
        () async {
      final tempDir =
          Directory.systemTemp.createTempSync('pdf_compress_corrupt_');
      try {
        final corruptFile = File('${tempDir.path}/corrupt.pdf');
        await corruptFile.writeAsString('Definitely not a PDF document');

        await expectLater(
          PdfService()
              .compressPdf(corruptFile.path, customOutputPath: tempDir.path),
          throwsA(isA<PdfServiceException>()),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
