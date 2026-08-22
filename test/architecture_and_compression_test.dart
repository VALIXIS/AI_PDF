import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';

import 'package:flutter/services.dart';

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
  });
}
