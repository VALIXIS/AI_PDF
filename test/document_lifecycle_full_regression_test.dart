import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/pdf_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';
import 'package:pdf_ai_toolkit/core/errors/app_exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfService pdfService;
  late FileService fileService;
  late StorageService storageService;
  late Directory tempDir;
  late String tempDirPath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('full_lifecycle_test_');
    tempDirPath = tempDir.path;

    Hive.init(tempDirPath);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }

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

  group('Full 8-Stage Document Lifecycle Regression Suite', () {
    test(
        'Complete Sequence: Import -> Process -> Save -> History -> Open -> Export -> Share -> Delete',
        () async {
      // 1. IMPORT & VALIDATION
      const rawText = 'Comprehensive Lifecycle Regression Test Content\nLine 2';
      final textFileName = fileService.formatOutputFileName(
        baseName: 'input_document',
        extension: 'txt',
      );
      final textInputPath = fileService.joinPaths(tempDirPath, textFileName);
      final savedTextPath = await fileService.safeWriteBytes(
          textInputPath, utf8.encode(rawText));

      expect(await fileService.isFileValidAndAccessible(savedTextPath), isTrue);
      expect(await fileService.isTextFile(savedTextPath), isTrue);

      // 2. PROCESS (Text to PDF Conversion)
      final pdfOutputPath = await pdfService.generatePdfFromText(
        title: 'Full Lifecycle PDF',
        content: rawText,
        customOutputPath: tempDirPath,
      );

      // 3. SAVE
      expect(await fileService.isFileValidAndAccessible(pdfOutputPath), isTrue);
      expect(await fileService.isPdfFile(pdfOutputPath), isTrue);
      expect(await pdfService.getPdfPageCount(pdfOutputPath), equals(1));

      // 4. HISTORY
      final historyId = 'full_lifecycle_${DateTime.now().millisecondsSinceEpoch}';
      final entry = HistoryEntry(
        id: historyId,
        title: 'Full Lifecycle PDF',
        date: DateTime.now(),
        filePath: pdfOutputPath,
        toolType: 'text_to_pdf',
      );
      await storageService.addHistoryEntry(entry);

      final retrievedEntry = await storageService.getHistoryEntry(historyId);
      expect(retrievedEntry, isNotNull);
      expect(retrievedEntry!.filePath, equals(pdfOutputPath));
      expect(await storageService.isEntryFileAccessible(retrievedEntry), isTrue);

      // 5. OPEN
      final openedPageCount = await pdfService.getPdfPageCount(retrievedEntry.filePath);
      expect(openedPageCount, equals(1));

      // 6. EXPORT (Split PDF export workflow)
      final exportedPath = await pdfService.splitPdf(
        pdfPath: retrievedEntry.filePath,
        startPage: 1,
        endPage: 1,
        customOutputPath: tempDirPath,
      );
      expect(await fileService.isFileValidAndAccessible(exportedPath), isTrue);
      expect(await fileService.isPdfFile(exportedPath), isTrue);

      // Record export in history
      final exportEntryId = 'export_${DateTime.now().millisecondsSinceEpoch}';
      final exportEntry = HistoryEntry(
        id: exportEntryId,
        title: 'Exported Split Page 1',
        date: DateTime.now(),
        filePath: exportedPath,
        toolType: 'split_pdf',
      );
      await storageService.addHistoryEntry(exportEntry);
      expect(await storageService.getHistoryEntry(exportEntryId), isNotNull);

      // 7. SHARE (Verify file availability prior to sharing)
      expect(await fileService.isFileAccessible(exportedPath), isTrue);

      // 8. DELETE
      await storageService.deleteHistoryEntry(exportEntryId);

      // Verify physical file deleted and history removed
      expect(await storageService.getHistoryEntry(exportEntryId), isNull);
      expect(await fileService.isFileAccessible(exportedPath), isFalse);

      // Cleanup original text file
      await fileService.deleteFile(savedTextPath);
      await storageService.deleteHistoryEntry(historyId);
    });

    test('Stage 1 (Import): Invalid, empty, or non-existent files rejected safely',
        () async {
      final fakePath = fileService.joinPaths(tempDirPath, 'does_not_exist.pdf');
      expect(await fileService.isFileValidAndAccessible(fakePath), isFalse);
      expect(await fileService.isPdfFile(fakePath), isFalse);
      expect(await fileService.isImageFile(fakePath), isFalse);
      expect(await fileService.isTextFile(fakePath), isFalse);

      // 0-byte file check
      final emptyPath = fileService.joinPaths(tempDirPath, 'empty_file.pdf');
      await File(emptyPath).create();
      expect(await fileService.isFileValidAndAccessible(emptyPath), isFalse);
      expect(await fileService.isPdfFile(emptyPath), isFalse);
      await fileService.deleteFile(emptyPath);

      // Header magic byte validation for invalid PDF content masquerading with .pdf extension
      final fakePdfPath = fileService.joinPaths(tempDirPath, 'fake_header.pdf');
      await fileService.safeWriteBytes(fakePdfPath, utf8.encode('NOT A REAL PDF CONTENT'));
      expect(await fileService.isPdfFile(fakePdfPath), isFalse);
      await fileService.deleteFile(fakePdfPath);
    });

    test('Stage 2 & 3 (Process & Save): Non-colliding path & sanitization',
        () async {
      // Filename sanitization checks across platforms
      const illegalName = 'test: illegal/name*with?chars<>|.pdf';
      final sanitized = fileService.sanitizeFileName(illegalName);
      expect(sanitized.contains(':'), isFalse);
      expect(sanitized.contains('/'), isFalse);
      expect(sanitized.contains('*'), isFalse);
      expect(sanitized.contains('?'), isFalse);
      expect(sanitized.contains('<'), isFalse);
      expect(sanitized.contains('>'), isFalse);

      // Reserved Windows names check
      final reserved = fileService.sanitizeFileName('CON.pdf');
      expect(reserved.startsWith('file_'), isTrue);

      // Duplicate filename increment test
      final baseDoc = fileService.joinPaths(tempDirPath, 'dup_test.pdf');
      await fileService.safeWriteBytes(baseDoc, utf8.encode('%PDF-1.4 test'));
      final dup1 = await fileService.getUniqueFilePath(baseDoc);
      expect(dup1, equals(fileService.joinPaths(tempDirPath, 'dup_test (1).pdf')));

      await fileService.safeWriteBytes(dup1, utf8.encode('%PDF-1.4 test'));
      final dup2 = await fileService.getUniqueFilePath(baseDoc);
      expect(dup2, equals(fileService.joinPaths(tempDirPath, 'dup_test (2).pdf')));
    });

    test('Stage 4 (History): Failed operations emit no records & stale cleanup',
        () async {
      final initialCount = await storageService.getHistoryCount();

      // Attempt adding history for non-existent file
      final fakeEntry = HistoryEntry(
        id: 'fake_hist_1',
        title: 'Non-existent file history',
        date: DateTime.now(),
        filePath: fileService.joinPaths(tempDirPath, 'missing_file.pdf'),
        toolType: 'test',
      );
      await storageService.addHistoryEntry(fakeEntry);

      final postFakeCount = await storageService.getHistoryCount();
      expect(postFakeCount, equals(initialCount));

      // Add valid entry then delete file from disk externally to simulate stale record
      final validPdfPath = await pdfService.generatePdfFromText(
        title: 'Stale Record Test',
        content: 'Content',
        customOutputPath: tempDirPath,
      );
      final staleEntry = HistoryEntry(
        id: 'stale_hist_1',
        title: 'Stale Record Test',
        date: DateTime.now(),
        filePath: validPdfPath,
        toolType: 'text_to_pdf',
      );
      await storageService.addHistoryEntry(staleEntry);
      expect(await storageService.getHistoryEntry('stale_hist_1'), isNotNull);

      // Manually delete file from disk
      await fileService.deleteFile(validPdfPath);

      // Run cleanup missing entries
      final cleanedCount = await storageService.cleanupMissingEntries();
      expect(cleanedCount, greaterThanOrEqualTo(1));
      expect(await storageService.getHistoryEntry('stale_hist_1'), isNull);
    });

    test('Stage 5 & 6 (Open & Export): Error handling on corrupt/missing inputs',
        () async {
      final missingPath = fileService.joinPaths(tempDirPath, 'missing_open.pdf');
      expect(() => pdfService.getPdfPageCount(missingPath),
          throwsA(isA<PdfServiceException>()));

      expect(
          () => pdfService.splitPdf(
                pdfPath: missingPath,
                startPage: 1,
                endPage: 1,
              ),
          throwsA(isA<PdfServiceException>()));
    });

    test('Stage 7 & 8 (Share & Delete): Repeated deletion & safe sharing check',
        () async {
      final outPath = await pdfService.generatePdfFromText(
        title: 'Deletion Test',
        content: 'Content to be deleted',
        customOutputPath: tempDirPath,
      );

      final entryId = 'delete_id_${DateTime.now().millisecondsSinceEpoch}';
      final entry = HistoryEntry(
        id: entryId,
        title: 'Deletion Test',
        date: DateTime.now(),
        filePath: outPath,
        toolType: 'text_to_pdf',
      );
      await storageService.addHistoryEntry(entry);

      // First deletion: deletes physical file and Hive entry
      await storageService.deleteHistoryEntry(entryId);
      expect(await fileService.isFileAccessible(outPath), isFalse);
      expect(await storageService.getHistoryEntry(entryId), isNull);

      // Idempotent second deletion attempt: should not crash or throw exception
      await storageService.deleteHistoryEntry(entryId);
      await storageService.deleteHistoryEntryByPath(outPath);
    });
  });
}
