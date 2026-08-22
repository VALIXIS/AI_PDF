import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pdf_ai_toolkit/controllers/ai_action_dispatcher.dart';
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

  group('AiActionDispatcher Unit Tests', () {
    final dispatcher = AiActionDispatcher();

    test(
        'detectActionType identifies rotate, watermark, split, protect, merge, compress, and pdfToText intents',
        () {
      expect(dispatcher.detectActionType('Rotate this PDF by 90 degrees'),
          equals(AiActionType.rotate));
      expect(dispatcher.detectActionType('Add a watermark saying DRAFT'),
          equals(AiActionType.watermark));
      expect(dispatcher.detectActionType('Split pages 1 to 3'),
          equals(AiActionType.split));
      expect(
          dispatcher
              .detectActionType('Protect this PDF with password secret123'),
          equals(AiActionType.protect));
      expect(dispatcher.detectActionType('Merge attached PDFs'),
          equals(AiActionType.merge));
      expect(dispatcher.detectActionType('Compress this PDF'),
          equals(AiActionType.compress));
      expect(dispatcher.detectActionType('Extract text from PDF'),
          equals(AiActionType.pdfToText));
      expect(dispatcher.detectActionType('What is the summary of page 2?'),
          equals(AiActionType.none));
    });

    test('executeAction executes rotate command on real PDF', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final samplePdf = File('${tempDir.path}/sample.pdf');

      final pdf = pw.Document();
      pdf.addPage(
          pw.Page(build: (pw.Context context) => pw.Text('Sample PDF Text')));
      await samplePdf.writeAsBytes(await pdf.save());

      final result = await dispatcher.executeAction(
        pdfPath: samplePdf.path,
        command: 'Rotate this PDF 90 degrees',
      );

      expect(result.isSuccess, isTrue);
      expect(result.type, equals(AiActionType.rotate));
      expect(result.outputPath, isNotNull);
      expect(File(result.outputPath!).existsSync(), isTrue);

      tempDir.deleteSync(recursive: true);
    });

    test('executeAction executes watermark command on real PDF', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final samplePdf = File('${tempDir.path}/sample_watermark.pdf');

      final pdf = pw.Document();
      pdf.addPage(
          pw.Page(build: (pw.Context context) => pw.Text('Sample Text')));
      await samplePdf.writeAsBytes(await pdf.save());

      final result = await dispatcher.executeAction(
        pdfPath: samplePdf.path,
        command: 'Add watermark CONFIDENTIAL',
      );

      expect(result.isSuccess, isTrue);
      expect(result.type, equals(AiActionType.watermark));
      expect(result.outputPath, isNotNull);
      expect(File(result.outputPath!).existsSync(), isTrue);

      tempDir.deleteSync(recursive: true);
    });
  });
}
