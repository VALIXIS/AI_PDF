import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfService pdfService;
  late FileService fileService;
  late StorageService storageService;
  late Directory tempDir;
  late String tempDirPath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('document_lifecycle_test_');
    tempDirPath = tempDir.path;

    Hive.init(tempDirPath);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDirPath;
      },
    );

    pdfService = PdfService();
    fileService = FileService();
    storageService = StorageService();
  });

  tearDownAll(() async {
    try {
      await Hive.close();
    } catch (_) {}
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group(
      'PDF Workflow Lifecycle: Create -> Save -> History -> Resolve -> Export',
      () {
    test(
        'Successful text PDF creation records valid history and resolves on disk',
        () async {
      final outPath = await pdfService.generatePdfFromText(
        title: 'Lifecycle PDF Test',
        content: 'This is a test content for lifecycle verification.',
        customOutputPath: tempDirPath,
      );

      // 1. Save: verify file exists on disk and is non-empty valid PDF
      expect(await fileService.isFileValidAndAccessible(outPath), isTrue);
      expect(await fileService.isPdfFile(outPath), isTrue);

      // 2. History: add history entry and verify retrieval
      final entryId = 'pdf_test_${DateTime.now().millisecondsSinceEpoch}';
      final entry = HistoryEntry(
        id: entryId,
        title: 'Lifecycle PDF Test',
        date: DateTime.now(),
        filePath: outPath,
        toolType: 'text_to_pdf',
      );
      await storageService.addHistoryEntry(entry);

      final retrieved = await storageService.getHistoryEntry(entryId);
      expect(retrieved, isNotNull);
      expect(retrieved!.filePath, equals(outPath));
      expect(await storageService.isEntryFileAccessible(retrieved), isTrue);

      // 3. Re-open / Read verification
      final pageCount = await pdfService.getPdfPageCount(outPath);
      expect(pageCount, equals(1));
    });
  });

  group('Scanner Workflow Lifecycle: Scan -> Save -> History -> Resolve', () {
    test(
        'Scanner generated PDF passes safe write, validation, and history recording',
        () async {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(child: pw.Text('Scanned Page Content')),
        ),
      );

      final fileName = fileService.formatOutputFileName(
        baseName: 'scan_lifecycle',
        suffix: 'test',
        extension: 'pdf',
      );
      final targetPath = fileService.joinPaths(tempDirPath, fileName);
      final pdfBytes = await pdf.save();

      // 1. Save safely
      final savedPath = await fileService.safeWriteBytes(targetPath, pdfBytes);
      expect(await fileService.isPdfFile(savedPath), isTrue);

      // 2. History: verify adding valid scan history
      final entry = HistoryEntry(
        id: 'scan_test_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Scan Lifecycle Test (1 page)',
        date: DateTime.now(),
        filePath: savedPath,
        toolType: 'scan_to_pdf',
      );
      await storageService.addHistoryEntry(entry);

      final retrieved = await storageService.getHistoryEntry(entry.id);
      expect(retrieved, isNotNull);
      expect(await storageService.isEntryFileAccessible(retrieved!), isTrue);
    });
  });

  group('Conversion Workflow Lifecycle: Convert -> Save -> History -> Resolve',
      () {
    test('JPG to PDF conversion follows reliable lifecycle', () async {
      // Create test PNG image
      final imgBytes = Uint8List.fromList([
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
      final imgPath =
          fileService.joinPaths(tempDirPath, 'test_img_lifecycle.png');
      await fileService.safeWriteBytes(imgPath, imgBytes);

      // Convert
      final pdfPath = await pdfService.convertImagesToPdf(
        imagePaths: [imgPath],
        customOutputPath: tempDirPath,
      );

      // Save & History verification
      expect(await fileService.isPdfFile(pdfPath), isTrue);
      final entry = HistoryEntry(
        id: 'jpg_to_pdf_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Images to PDF (1)',
        date: DateTime.now(),
        filePath: pdfPath,
        toolType: 'jpg_to_pdf',
      );
      await storageService.addHistoryEntry(entry);

      final retrieved = await storageService.getHistoryEntry(entry.id);
      expect(retrieved, isNotNull);
      expect(await storageService.isEntryFileAccessible(retrieved!), isTrue);
    });

    test('PDF to TXT conversion follows reliable lifecycle', () async {
      final pdfPath = await pdfService.generatePdfFromText(
        title: 'Source PDF for Text Extraction',
        content: 'Extractable content in PDF document.',
        customOutputPath: tempDirPath,
      );

      final txtPath = await pdfService.convertPdfToTxt(
        pdfPath: pdfPath,
        customOutputPath: tempDirPath,
      );

      expect(await fileService.isFileValidAndAccessible(txtPath), isTrue);

      final entry = HistoryEntry(
        id: 'pdf_to_txt_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Extracted Text',
        date: DateTime.now(),
        filePath: txtPath,
        toolType: 'pdf_to_text',
      );
      await storageService.addHistoryEntry(entry);

      final retrieved = await storageService.getHistoryEntry(entry.id);
      expect(retrieved, isNotNull);
      expect(await storageService.isEntryFileAccessible(retrieved!), isTrue);
    });
  });

  group('Lifecycle Integrity & Edge Cases', () {
    test('Non-existent or 0-byte file is NOT recorded in history', () async {
      final fakePath =
          fileService.joinPaths(tempDirPath, 'non_existent_file.pdf');
      final entry = HistoryEntry(
        id: 'fake_entry_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Fake Document',
        date: DateTime.now(),
        filePath: fakePath,
        toolType: 'test',
      );

      await storageService.addHistoryEntry(entry);
      final retrieved = await storageService.getHistoryEntry(entry.id);
      expect(retrieved, isNull);
    });

    test('Deleted file is detected as inaccessible without crashing', () async {
      final outPath = await pdfService.generatePdfFromText(
        title: 'Temp PDF To Delete',
        content: 'Temporary content',
        customOutputPath: tempDirPath,
      );

      final entry = HistoryEntry(
        id: 'delete_test_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Temp PDF',
        date: DateTime.now(),
        filePath: outPath,
        toolType: 'text_to_pdf',
      );
      await storageService.addHistoryEntry(entry);

      // Verify file accessible initially
      expect(await storageService.isEntryFileAccessible(entry), isTrue);

      // Delete file from disk
      await fileService.deleteFile(outPath);

      // Verify accessible returns false gracefully without throwing exception
      expect(await storageService.isEntryFileAccessible(entry), isFalse);
    });

    test('Duplicate filename generation yields unique non-colliding paths',
        () async {
      final basePath = fileService.joinPaths(tempDirPath, 'duplicate_doc.pdf');
      await fileService.safeWriteBytes(basePath, [1, 2, 3]);

      final unique1 = await fileService.getUniqueFilePath(basePath);
      expect(unique1, isNot(equals(basePath)));
      expect(unique1.contains('(1)'), isTrue);

      await fileService.safeWriteBytes(unique1, [1, 2, 3]);
      final unique2 = await fileService.getUniqueFilePath(basePath);
      expect(unique2.contains('(2)'), isTrue);
    });
  });
}
