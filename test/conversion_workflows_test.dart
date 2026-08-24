import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';
import 'package:pdfx/src/renderer/interfaces/platform.dart';
import 'package:pdfx/src/renderer/io/platform_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PdfxPlatform.instance = PdfxPlatformMethodChannel();

  late PdfService pdfService;
  late Directory tempDir;
  late String tempDirPath;
  final List<MethodCall> methodChannelLog = <MethodCall>[];

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('conversion_workflows_test_');
    tempDirPath = tempDir.path;

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDirPath;
      },
    );

    // Mock pdfx (io.scer.pdf_renderer)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('io.scer.pdf_renderer'),
      (MethodCall methodCall) async {
        methodChannelLog.add(methodCall);
        switch (methodCall.method) {
          case 'open.document.file':
            return {
              'id': 'uuid-file-id',
              'pagesCount': 2,
            };
          case 'close.document':
            return null;
          case 'open.page':
            return {
              'id': 'page-id',
              'width': 720.0,
              'height': 1280.0,
            };
          case 'close.page':
            return null;
          case 'render':
            return {
              'width': methodCall.arguments['width'],
              'height': methodCall.arguments['height'],
              'path': 'test/image.png',
              'data': Uint8List.fromList([
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
              ]), // A 1x1 valid PNG file bytes
            };
          default:
            return null;
        }
      },
    );

    pdfService = PdfService();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  tearDown(() {
    methodChannelLog.clear();
  });

  // Helper to generate a multi-page test PDF with text
  Future<String> createTestPdf({
    required List<String> pageTexts,
  }) async {
    final pdf = pw.Document();
    for (final text in pageTexts) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text(text),
            );
          },
        ),
      );
    }
    final file = File(
        '$tempDirPath/test_input_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  // Helper to generate a mock image file
  Future<String> createTestImage() async {
    // 1x1 valid PNG file
    final bytes = Uint8List.fromList([
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
    final file = File(
        '$tempDirPath/test_img_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  group('PDF to TXT', () {
    test('Successful text extraction', () async {
      final pdfPath = await createTestPdf(pageTexts: ['Hello PDF Text']);
      final txtPath = await pdfService.convertPdfToTxt(pdfPath: pdfPath);
      final txtFile = File(txtPath);

      expect(txtFile.existsSync(), isTrue);
      expect(txtFile.lengthSync(), greaterThan(0));

      final extractedText = txtFile.readAsStringSync();
      final normalizedText =
          extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();
      expect(normalizedText.contains('Hello PDF Text'), isTrue);

      await File(pdfPath).delete();
      await txtFile.delete();
    });

    test('Throws on scanned/empty PDF', () async {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Container(),
        ),
      );
      final pdfPath =
          '$tempDirPath/scanned_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(pdfPath).writeAsBytes(await pdf.save());

      await expectLater(
        pdfService.convertPdfToTxt(pdfPath: pdfPath),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_TO_TXT_NO_TEXT')),
      );

      await File(pdfPath).delete();
    });

    test('Throws on missing file', () async {
      await expectLater(
        pdfService.convertPdfToTxt(pdfPath: '$tempDirPath/missing.pdf'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_TO_TXT_INPUT_NOT_FOUND')),
      );
    });

    test('Throws on corrupt/invalid file', () async {
      final corruptFile = File(
          '$tempDirPath/corrupt_${DateTime.now().millisecondsSinceEpoch}.pdf');
      corruptFile.writeAsStringSync('Defo not a PDF');

      await expectLater(
        pdfService.convertPdfToTxt(pdfPath: corruptFile.path),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_TO_TXT_INVALID_PDF')),
      );

      await corruptFile.delete();
    });
  });

  group('TXT to PDF', () {
    test('Successful text to PDF conversion with pagination', () async {
      final txtFile = File(
          '$tempDirPath/test_txt_${DateTime.now().millisecondsSinceEpoch}.txt');
      txtFile.writeAsStringSync(
          'Line 1\nLine 2\n' * 50); // long text to trigger pages

      final pdfPath = await pdfService.convertTxtToPdf(
          txtPath: txtFile.path, title: 'My Text Doc');
      final pdfFile = File(pdfPath);

      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(0));

      // Reopen and check pages count > 1 due to pagination
      final pagesCount = await pdfService.getPdfPageCount(pdfPath);
      expect(pagesCount, greaterThan(1));

      await txtFile.delete();
      await pdfFile.delete();
    });

    test('Throws on empty TXT', () async {
      final txtFile = File(
          '$tempDirPath/empty_txt_${DateTime.now().millisecondsSinceEpoch}.txt');
      txtFile.writeAsStringSync('   \n  ');

      await expectLater(
        pdfService.convertTxtToPdf(txtPath: txtFile.path, title: 'Empty'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'TXT_TO_PDF_INPUT_EMPTY')),
      );

      await txtFile.delete();
    });

    test('Throws on missing TXT file', () async {
      await expectLater(
        pdfService.convertTxtToPdf(
            txtPath: '$tempDirPath/missing.txt', title: 'Missing'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'TXT_TO_PDF_INPUT_NOT_FOUND')),
      );
    });
  });

  group('Image to PDF', () {
    test('Successful conversion of single image', () async {
      final imgPath = await createTestImage();
      final pdfPath =
          await pdfService.convertImagesToPdf(imagePaths: [imgPath]);
      final pdfFile = File(pdfPath);

      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(0));

      final pageCount = await pdfService.getPdfPageCount(pdfPath);
      expect(pageCount, equals(1));

      await File(imgPath).delete();
      await pdfFile.delete();
    });

    test('Successful conversion of multiple images preserving count', () async {
      final img1 = await createTestImage();
      final img2 = await createTestImage();

      final pdfPath =
          await pdfService.convertImagesToPdf(imagePaths: [img1, img2]);
      final pdfFile = File(pdfPath);

      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(0));

      final pageCount = await pdfService.getPdfPageCount(pdfPath);
      expect(pageCount, equals(2));

      await File(img1).delete();
      await File(img2).delete();
      await pdfFile.delete();
    });

    test('Throws on missing image path', () async {
      await expectLater(
        pdfService.convertImagesToPdf(imagePaths: ['$tempDirPath/missing.png']),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'IMAGE_TO_PDF_INPUT_NOT_FOUND')),
      );
    });

    test('Throws on corrupt image file', () async {
      final corruptImg = File(
          '$tempDirPath/corrupt_img_${DateTime.now().millisecondsSinceEpoch}.png');
      corruptImg.writeAsStringSync('Definitely not PNG bytes');

      await expectLater(
        pdfService.convertImagesToPdf(imagePaths: [corruptImg.path]),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'IMAGE_TO_PDF_INVALID_IMAGE')),
      );

      await corruptImg.delete();
    });
  });

  group('PDF to Image', () {
    test('Successful PDF to Image conversion', () async {
      final pdfPath =
          await createTestPdf(pageTexts: ['Page 1 Content', 'Page 2 Content']);

      final imagePaths = await pdfService.convertPdfToImages(
          pdfPath: pdfPath, startPage: 1, endPage: 2);
      expect(imagePaths.length, equals(2));

      for (int i = 0; i < imagePaths.length; i++) {
        final imgFile = File(imagePaths[i]);
        expect(imgFile.existsSync(), isTrue);
        expect(imgFile.lengthSync(), greaterThan(0));
        await imgFile.delete();
      }

      await File(pdfPath).delete();
    });

    test('Throws on invalid page range', () async {
      final pdfPath = await createTestPdf(pageTexts: ['Page 1 Content']);

      await expectLater(
        pdfService.convertPdfToImages(
            pdfPath: pdfPath, startPage: 2, endPage: 1),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_TO_IMAGE_INVALID_PAGE_RANGE')),
      );

      await expectLater(
        pdfService.convertPdfToImages(
            pdfPath: pdfPath, startPage: 0, endPage: 1),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_TO_IMAGE_INVALID_PAGE_RANGE')),
      );

      await File(pdfPath).delete();
    });

    test('Throws on missing PDF', () async {
      await expectLater(
        pdfService.convertPdfToImages(pdfPath: '$tempDirPath/missing.pdf'),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_TO_IMAGE_INPUT_NOT_FOUND')),
      );
    });
  });
}
