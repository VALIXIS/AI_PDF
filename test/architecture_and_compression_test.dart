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

  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  group('Centralized AppException Suite', () {
    test('PdfServiceException formats code and details correctly', () {
      final exc = PdfServiceException('PDF rendering failed', code: 'RENDER_ERR', details: 'Null stream');
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
    test('cleanOrphanedTempFiles runs safely without throwing exceptions', () async {
      final deleted = await FileService().cleanOrphanedTempFiles();
      expect(deleted, isA<int>());
      expect(deleted, greaterThanOrEqualTo(0));
    });

    test('compressPdf throws PdfServiceException on non-existent file', () async {
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

    test('compressPdf reduces file size of an uncompressed PDF and does not copy bytes', () async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_compress_test_');
      try {
        print('Supported PdfCompressionLevel values: ${syncfusion.PdfCompressionLevel.values}');

        // Create an uncompressed PDF document
        final pdf = pw.Document(compress: false);
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Center(
              child: pw.Text('Testing high-efficiency stream compression engine.\n' * 200),
            ),
          ),
        );
        
        final inputPath = '${tempDir.path}/uncompressed.pdf';
        final inputFile = File(inputPath);
        await inputFile.writeAsBytes(await pdf.save());
        final originalSize = inputFile.lengthSync();

        // Perform compression
        final compressedPath = await PdfService().compressPdf(
          inputPath,
          customOutputPath: tempDir.path,
        );
        final compressedFile = File(compressedPath);
        final compressedSize = compressedFile.lengthSync();

        expect(compressedFile.existsSync(), isTrue);
        expect(compressedSize, greaterThan(0));
        
        // 1. Verify that the output is not a simple file copy (bytes are different)
        final originalBytes = await inputFile.readAsBytes();
        final compressedBytes = await compressedFile.readAsBytes();
        expect(originalBytes.length == compressedBytes.length, isFalse);

        // 2. Verify that the compressed file size is strictly smaller than the uncompressed original
        expect(compressedSize, lessThan(originalSize));
        print('Original Size: $originalSize, Compressed Size: $compressedSize');
        
        // Clean up
        await inputFile.delete();
        await compressedFile.delete();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('compressPdf supports low, medium, and high levels', () async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_compress_test_levels_');
      try {
        final pdf = pw.Document(compress: false);
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Center(
              child: pw.Text('Testing high-efficiency stream compression engine.\n' * 500),
            ),
          ),
        );
        
        final inputPath = '${tempDir.path}/uncompressed.pdf';
        await File(inputPath).writeAsBytes(await pdf.save());

        final lowPath = await PdfService().compressPdf(inputPath, customOutputPath: tempDir.path, compressionLevel: 'low');
        final mediumPath = await PdfService().compressPdf(inputPath, customOutputPath: tempDir.path, compressionLevel: 'medium');
        final highPath = await PdfService().compressPdf(inputPath, customOutputPath: tempDir.path, compressionLevel: 'high');

        final lowSize = File(lowPath).lengthSync();
        final mediumSize = File(mediumPath).lengthSync();
        final highSize = File(highPath).lengthSync();

        print('Low size: $lowSize, Medium size: $mediumSize, High size: $highSize');
        
        expect(lowSize, greaterThan(0));
        expect(mediumSize, greaterThan(0));
        expect(highSize, greaterThan(0));

        // High compression should yield smaller or equal file sizes compared to low compression
        expect(highSize, lessThanOrEqualTo(lowSize));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
