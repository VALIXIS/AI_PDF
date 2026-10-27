import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';
import 'package:pdfx/src/renderer/interfaces/platform.dart';
import 'package:pdfx/src/renderer/io/platform_method_channel.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PdfxPlatform.instance = PdfxPlatformMethodChannel();

  late PdfService pdfService;
  late Directory tempDir;
  late String tempDirPath;
  final List<MethodCall> methodChannelLog = <MethodCall>[];

  setUpAll(() async {
    tempDir =
        await Directory.systemTemp.createTemp('conversion_workflows_test_');
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
              'pagesCount': 3,
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

  // Helper to generate an image file with custom dimensions and aspect ratio
  Future<String> createOrientedImage({
    required int width,
    required int height,
  }) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(50, 150, 250));
    final pngBytes = Uint8List.fromList(img.encodePng(image));
    final file = File(
        '$tempDirPath/test_img_${width}x${height}_${DateTime.now().microsecondsSinceEpoch}.png');
    file.writeAsBytesSync(pngBytes);
    return file.path;
  }

  // Helper to generate a multi-page test PDF with distinct per-page rotations
  Future<String> createMultiPagePdfWithRotations({
    required List<sf.PdfPageRotateAngle> rotations,
  }) async {
    final doc = sf.PdfDocument();
    for (int i = 0; i < rotations.length; i++) {
      final section = doc.sections!.add();
      section.pageSettings.size = const Size(595, 842);
      section.pageSettings.rotate = rotations[i];
      section.pageSettings.margins.all = 0;
      final page = section.pages.add();
      page.graphics.drawString(
        'Page ${i + 1} with rotation ${rotations[i]}',
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(20, 20, 250, 50),
      );
    }
    final bytes = doc.saveSync();
    doc.dispose();
    final file = File(
        '$tempDirPath/multi_orient_${DateTime.now().microsecondsSinceEpoch}.pdf');
    file.writeAsBytesSync(bytes);
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
    test('Individual page selection exports correct single PNG with deterministic naming', () async {
      final pdfPath = await createTestPdf(
          pageTexts: ['Page 1 Content', 'Page 2 Content', 'Page 3 Content']);

      // 1. Select Page 1
      final page1Paths = await pdfService.convertPdfToImages(
          pdfPath: pdfPath, startPage: 1, endPage: 1, customOutputPath: tempDirPath);
      expect(page1Paths.length, equals(1));
      expect(page1Paths.first.endsWith('_page_1.png'), isTrue);
      final file1 = File(page1Paths.first);
      expect(file1.existsSync(), isTrue);
      expect(file1.lengthSync(), greaterThan(0));
      final header1 = await file1.openRead(0, 8).first;
      expect(header1.take(4).toList(), equals([137, 80, 78, 71])); // PNG signature

      // 2. Select Page 2
      final page2Paths = await pdfService.convertPdfToImages(
          pdfPath: pdfPath, startPage: 2, endPage: 2, customOutputPath: tempDirPath);
      expect(page2Paths.length, equals(1));
      expect(page2Paths.first.endsWith('_page_2.png'), isTrue);
      final file2 = File(page2Paths.first);
      expect(file2.existsSync(), isTrue);
      expect(file2.lengthSync(), greaterThan(0));

      // 3. Select Page 3
      final page3Paths = await pdfService.convertPdfToImages(
          pdfPath: pdfPath, startPage: 3, endPage: 3, customOutputPath: tempDirPath);
      expect(page3Paths.length, equals(1));
      expect(page3Paths.first.endsWith('_page_3.png'), isTrue);
      final file3 = File(page3Paths.first);
      expect(file3.existsSync(), isTrue);
      expect(file3.lengthSync(), greaterThan(0));

      await file1.delete();
      await file2.delete();
      await file3.delete();
      await File(pdfPath).delete();
    });

    test('Save All exports every page of multi-page PDF into individual PNG files', () async {
      final pdfPath = await createTestPdf(
          pageTexts: ['Page 1 Content', 'Page 2 Content', 'Page 3 Content']);

      final allImagePaths = await pdfService.convertPdfToImages(
          pdfPath: pdfPath, customOutputPath: tempDirPath);
      expect(allImagePaths.length, equals(3));

      expect(allImagePaths[0].endsWith('_page_1.png'), isTrue);
      expect(allImagePaths[1].endsWith('_page_2.png'), isTrue);
      expect(allImagePaths[2].endsWith('_page_3.png'), isTrue);

      for (int i = 0; i < allImagePaths.length; i++) {
        final imgFile = File(allImagePaths[i]);
        expect(imgFile.existsSync(), isTrue);
        expect(imgFile.lengthSync(), greaterThan(0));

        final header = await imgFile.openRead(0, 8).first;
        expect(header.take(4).toList(), equals([137, 80, 78, 71]));
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

      await expectLater(
        pdfService.convertPdfToImages(
            pdfPath: pdfPath, startPage: 1, endPage: 5),
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

  group('Orientation & Aspect Ratio Workflows', () {
    test('Image to PDF respects portrait and landscape orientation', () async {
      // 1. Portrait image (width < height)
      final portraitImg = await createOrientedImage(width: 300, height: 600);
      final portraitPdf = await pdfService.convertImagesToPdf(
        imagePaths: [portraitImg],
        customOutputPath: tempDirPath,
      );
      final docPortrait =
          sf.PdfDocument(inputBytes: await File(portraitPdf).readAsBytes());
      expect(docPortrait.pages.count, equals(1));
      final portraitSize = docPortrait.pages[0].size;
      expect(portraitSize.height, greaterThanOrEqualTo(portraitSize.width));
      docPortrait.dispose();

      // 2. Landscape image (width > height)
      final landscapeImg = await createOrientedImage(width: 800, height: 400);
      final landscapePdf = await pdfService.convertImagesToPdf(
        imagePaths: [landscapeImg],
        customOutputPath: tempDirPath,
      );
      final docLandscape =
          sf.PdfDocument(inputBytes: await File(landscapePdf).readAsBytes());
      expect(docLandscape.pages.count, equals(1));
      final landscapeSize = docLandscape.pages[0].size;
      expect(landscapeSize.width, greaterThan(landscapeSize.height));
      docLandscape.dispose();

      await File(portraitImg).delete();
      await File(portraitPdf).delete();
      await File(landscapeImg).delete();
      await File(landscapePdf).delete();
    });

    test(
        'Full 360-degree rotation cycle rotates cleanly through 90, 180, 270, and back to 0 degrees',
        () async {
      final inputPath = await createMultiPagePdfWithRotations(
        rotations: [sf.PdfPageRotateAngle.rotateAngle0],
      );

      // Rotate by 90
      final path90 = await pdfService.rotatePdf(
        pdfPath: inputPath,
        rotationAngle: 90,
        customOutputPath: tempDirPath,
      );
      final doc90 =
          sf.PdfDocument(inputBytes: await File(path90).readAsBytes());
      expect(
          doc90.pages[0].rotation, equals(sf.PdfPageRotateAngle.rotateAngle90));
      doc90.dispose();

      // Rotate by another 90 (cumulative 180)
      final path180 = await pdfService.rotatePdf(
        pdfPath: path90,
        rotationAngle: 90,
        customOutputPath: tempDirPath,
      );
      final doc180 =
          sf.PdfDocument(inputBytes: await File(path180).readAsBytes());
      expect(doc180.pages[0].rotation,
          equals(sf.PdfPageRotateAngle.rotateAngle180));
      doc180.dispose();

      // Rotate by another 90 (cumulative 270)
      final path270 = await pdfService.rotatePdf(
        pdfPath: path180,
        rotationAngle: 90,
        customOutputPath: tempDirPath,
      );
      final doc270 =
          sf.PdfDocument(inputBytes: await File(path270).readAsBytes());
      expect(doc270.pages[0].rotation,
          equals(sf.PdfPageRotateAngle.rotateAngle270));
      doc270.dispose();

      // Rotate by another 90 (cumulative 360 -> back to 0)
      final path360 = await pdfService.rotatePdf(
        pdfPath: path270,
        rotationAngle: 90,
        customOutputPath: tempDirPath,
      );
      final doc360 =
          sf.PdfDocument(inputBytes: await File(path360).readAsBytes());
      expect(
          doc360.pages[0].rotation, equals(sf.PdfPageRotateAngle.rotateAngle0));
      doc360.dispose();

      await File(inputPath).delete();
      await File(path90).delete();
      await File(path180).delete();
      await File(path270).delete();
      await File(path360).delete();
    });

    test('reorganizePdfPages applies distinct rotations to individual pages',
        () async {
      final inputPath = await createMultiPagePdfWithRotations(
        rotations: [
          sf.PdfPageRotateAngle.rotateAngle0,
          sf.PdfPageRotateAngle.rotateAngle0,
          sf.PdfPageRotateAngle.rotateAngle0,
        ],
      );

      final reorgPath = await pdfService.reorganizePdfPages(
        pdfPath: inputPath,
        pages: const [
          PdfPageReorganizeItem(originalPageIndex: 0, rotationAngle: 90),
          PdfPageReorganizeItem(originalPageIndex: 1, rotationAngle: 180),
          PdfPageReorganizeItem(originalPageIndex: 2, rotationAngle: 270),
        ],
        customOutputPath: tempDirPath,
      );

      final doc =
          sf.PdfDocument(inputBytes: await File(reorgPath).readAsBytes());
      expect(doc.pages.count, equals(3));
      expect(
          doc.pages[0].rotation, equals(sf.PdfPageRotateAngle.rotateAngle90));
      expect(
          doc.pages[1].rotation, equals(sf.PdfPageRotateAngle.rotateAngle180));
      expect(
          doc.pages[2].rotation, equals(sf.PdfPageRotateAngle.rotateAngle270));
      doc.dispose();

      await File(inputPath).delete();
      await File(reorgPath).delete();
    });
  });

  group('Edge-Case Splits Workflows', () {
    test(
        'Boundary split: Single first page (1 to 1) extraction preserves content and orientation',
        () async {
      final inputPath = await createMultiPagePdfWithRotations(
        rotations: [
          sf.PdfPageRotateAngle.rotateAngle90,
          sf.PdfPageRotateAngle.rotateAngle180,
          sf.PdfPageRotateAngle.rotateAngle270,
        ],
      );

      final splitPath = await pdfService.splitPdf(
        pdfPath: inputPath,
        startPage: 1,
        endPage: 1,
        customOutputPath: tempDirPath,
      );

      final doc =
          sf.PdfDocument(inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(1));
      expect(
          doc.pages[0].rotation, equals(sf.PdfPageRotateAngle.rotateAngle90));
      final text = sf.PdfTextExtractor(doc).extractText();
      expect(text, contains('Page 1'));
      doc.dispose();

      await File(inputPath).delete();
      await File(splitPath).delete();
    });

    test(
        'Boundary split: Single last page (N to N) extraction preserves content and orientation',
        () async {
      final inputPath = await createMultiPagePdfWithRotations(
        rotations: [
          sf.PdfPageRotateAngle.rotateAngle0,
          sf.PdfPageRotateAngle.rotateAngle90,
          sf.PdfPageRotateAngle.rotateAngle270,
        ],
      );

      final splitPath = await pdfService.splitPdf(
        pdfPath: inputPath,
        startPage: 3,
        endPage: 3,
        customOutputPath: tempDirPath,
      );

      final doc =
          sf.PdfDocument(inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(1));
      expect(
          doc.pages[0].rotation, equals(sf.PdfPageRotateAngle.rotateAngle270));
      final text = sf.PdfTextExtractor(doc).extractText();
      expect(text, contains('Page 3'));
      doc.dispose();

      await File(inputPath).delete();
      await File(splitPath).delete();
    });

    test(
        'Full document split: (1 to N) extracts all pages retaining exact orientation sequence',
        () async {
      final inputPath = await createMultiPagePdfWithRotations(
        rotations: [
          sf.PdfPageRotateAngle.rotateAngle0,
          sf.PdfPageRotateAngle.rotateAngle90,
          sf.PdfPageRotateAngle.rotateAngle180,
          sf.PdfPageRotateAngle.rotateAngle270,
        ],
      );

      final splitPath = await pdfService.splitPdf(
        pdfPath: inputPath,
        startPage: 1,
        endPage: 4,
        customOutputPath: tempDirPath,
      );

      final doc =
          sf.PdfDocument(inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(4));
      expect(
          doc.pages[0].rotation, equals(sf.PdfPageRotateAngle.rotateAngle0));
      expect(
          doc.pages[1].rotation, equals(sf.PdfPageRotateAngle.rotateAngle90));
      expect(
          doc.pages[2].rotation, equals(sf.PdfPageRotateAngle.rotateAngle180));
      expect(
          doc.pages[3].rotation, equals(sf.PdfPageRotateAngle.rotateAngle270));
      doc.dispose();

      await File(inputPath).delete();
      await File(splitPath).delete();
    });

    test(
        'Subrange split: middle pages (2 to 3) correctly extracts subset preserving rotations',
        () async {
      final inputPath = await createMultiPagePdfWithRotations(
        rotations: [
          sf.PdfPageRotateAngle.rotateAngle0,
          sf.PdfPageRotateAngle.rotateAngle90,
          sf.PdfPageRotateAngle.rotateAngle180,
          sf.PdfPageRotateAngle.rotateAngle270,
        ],
      );

      final splitPath = await pdfService.splitPdf(
        pdfPath: inputPath,
        startPage: 2,
        endPage: 3,
        customOutputPath: tempDirPath,
      );

      final doc =
          sf.PdfDocument(inputBytes: await File(splitPath).readAsBytes());
      expect(doc.pages.count, equals(2));
      expect(
          doc.pages[0].rotation, equals(sf.PdfPageRotateAngle.rotateAngle90));
      expect(
          doc.pages[1].rotation, equals(sf.PdfPageRotateAngle.rotateAngle180));
      final text = sf.PdfTextExtractor(doc).extractText();
      expect(text, contains('Page 2'));
      expect(text, contains('Page 3'));
      doc.dispose();

      await File(inputPath).delete();
      await File(splitPath).delete();
    });

    test('Edge case rejection: inverted range (startPage > endPage)',
        () async {
      final inputPath =
          await createTestPdf(pageTexts: ['Page 1', 'Page 2', 'Page 3']);

      await expectLater(
        pdfService.splitPdf(pdfPath: inputPath, startPage: 3, endPage: 1),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_INVALID_PAGE_RANGE')),
      );

      await File(inputPath).delete();
    });

    test('Edge case rejection: startPage <= 0', () async {
      final inputPath = await createTestPdf(pageTexts: ['Page 1', 'Page 2']);

      await expectLater(
        pdfService.splitPdf(pdfPath: inputPath, startPage: 0, endPage: 2),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_INVALID_PAGE_RANGE')),
      );

      await expectLater(
        pdfService.splitPdf(pdfPath: inputPath, startPage: -2, endPage: 2),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_INVALID_PAGE_RANGE')),
      );

      await File(inputPath).delete();
    });

    test('Edge case rejection: endPage out of bounds (> totalPages)', () async {
      final inputPath = await createTestPdf(pageTexts: ['Page 1', 'Page 2']);

      await expectLater(
        pdfService.splitPdf(pdfPath: inputPath, startPage: 1, endPage: 10),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_INVALID_PAGE_RANGE')),
      );

      await File(inputPath).delete();
    });

    test('Edge case rejection: missing or corrupted file', () async {
      await expectLater(
        pdfService.splitPdf(
          pdfPath: '$tempDirPath/non_existent.pdf',
          startPage: 1,
          endPage: 2,
        ),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_INPUT_NOT_FOUND')),
      );

      final corruptFile = File('$tempDirPath/corrupt_split.pdf');
      corruptFile.writeAsStringSync('not a pdf at all');

      await expectLater(
        pdfService.splitPdf(
          pdfPath: corruptFile.path,
          startPage: 1,
          endPage: 1,
        ),
        throwsA(isA<PdfServiceException>()
            .having((e) => e.code, 'code', 'PDF_CORRUPT_OR_INVALID')),
      );

      await corruptFile.delete();
    });
  });
}
