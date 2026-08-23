import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storageService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_storage_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }
  });

  setUp(() async {
    storageService = StorageService();
    await storageService.clearAllHistory();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StorageService Missing-File & Accessibility Tests', () {
    test(
        'isEntryFileAccessible returns false when entry filePath points to non-existent file',
        () async {
      final entry = HistoryEntry(
        id: 'test_1',
        title: 'Non Existent PDF',
        date: DateTime.now(),
        filePath: '/non_existent_folder/missing_file.pdf',
        toolType: 'text_to_pdf',
      );

      final accessible = await storageService.isEntryFileAccessible(entry);
      expect(accessible, isFalse);
    });

    test('isEntryFileAccessible returns false for empty filePath', () async {
      final entry = HistoryEntry(
        id: 'test_2',
        title: 'Empty Path',
        date: DateTime.now(),
        filePath: '',
        toolType: 'text_to_pdf',
      );

      final accessible = await storageService.isEntryFileAccessible(entry);
      expect(accessible, isFalse);
    });

    test('addHistoryEntry ignores non-existent or failed file operation', () async {
      final entry = HistoryEntry(
        id: 'failed_op_1',
        title: 'Failed PDF Save',
        date: DateTime.now(),
        filePath: '${tempDir.path}/missing_output.pdf',
        toolType: 'compress_pdf',
      );

      await storageService.addHistoryEntry(entry);
      final entries = await storageService.getAllHistoryEntries();
      expect(entries.where((e) => e.id == 'failed_op_1'), isEmpty);
    });

    test('addHistoryEntry persists accessible existing file', () async {
      final validFile = File('${tempDir.path}/sample_valid.pdf');
      await validFile.writeAsString('Dummy PDF bytes');

      final entry = HistoryEntry(
        id: 'valid_op_1',
        title: 'Sample PDF',
        date: DateTime.now(),
        filePath: validFile.path,
        toolType: 'text_to_pdf',
      );

      await storageService.addHistoryEntry(entry);
      final entries = await storageService.getAllHistoryEntries();
      expect(entries.any((e) => e.filePath == validFile.path), isTrue);
    });

    test('addHistoryEntry merges duplicate records for identical file path', () async {
      final validFile = File('${tempDir.path}/duplicate_test.pdf');
      await validFile.writeAsString('Dummy Content');

      final initialEntry = HistoryEntry(
        id: 'dup_1',
        title: 'First Export',
        date: DateTime.now().subtract(const Duration(minutes: 5)),
        filePath: validFile.path,
        toolType: 'text_to_pdf',
      );

      final updatedEntry = HistoryEntry(
        id: 'dup_2',
        title: 'Updated Export',
        date: DateTime.now(),
        filePath: validFile.path,
        toolType: 'compress_pdf',
      );

      await storageService.addHistoryEntry(initialEntry);
      await storageService.addHistoryEntry(updatedEntry);

      final entries = await storageService.getAllHistoryEntries();
      final matching = entries.where((e) => e.filePath == validFile.path).toList();

      expect(matching.length, equals(1));
      expect(matching.first.title, equals('Updated Export'));
      expect(matching.first.toolType, equals('compress_pdf'));
    });

    test('deleteHistoryEntry deletes entry and physical file', () async {
      final fileToDelete = File('${tempDir.path}/to_delete.pdf');
      await fileToDelete.writeAsString('Delete me');

      final entry = HistoryEntry(
        id: 'del_1',
        title: 'To Delete',
        date: DateTime.now(),
        filePath: fileToDelete.path,
        toolType: 'text_to_pdf',
      );

      await storageService.addHistoryEntry(entry);
      expect(await fileToDelete.exists(), isTrue);

      await storageService.deleteHistoryEntry('del_1');
      expect(await fileToDelete.exists(), isFalse);
      expect(await storageService.getHistoryEntry('del_1'), isNull);
    });

    test('cleanupMissingEntries removes stale entries pointing to missing files', () async {
      final box = await Hive.openBox<HistoryEntry>('historyBox');
      final missingEntry = HistoryEntry(
        id: 'stale_1',
        title: 'Stale PDF',
        date: DateTime.now(),
        filePath: '${tempDir.path}/deleted_externally.pdf',
        toolType: 'text_to_pdf',
      );
      await box.put(missingEntry.id, missingEntry);

      final removedCount = await storageService.cleanupMissingEntries();
      expect(removedCount, equals(1));
      expect(await storageService.getHistoryEntry('stale_1'), isNull);
    });
  });
}

