import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late FileService fileService;
  late StorageService storageService;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('perf_test_dir_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HistoryEntryAdapter());
    }
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

  group('Large-File & Performance Tests', () {
    test('safeCopyFile handles streaming copy cleanly without buffer allocation failure', () async {
      final srcFile = File('${tempDir.path}/large_test_source.bin');
      // Write 2MB test payload
      final chunk = List<int>.filled(1024 * 1024, 65);
      await srcFile.writeAsBytes(chunk, mode: FileMode.append);
      await srcFile.writeAsBytes(chunk, mode: FileMode.append);

      final destPath = '${tempDir.path}/large_test_dest.bin';
      final copiedPath = await fileService.safeCopyFile(srcFile.path, destPath);

      expect(await File(copiedPath).exists(), isTrue);
      expect(await File(copiedPath).length(), equals(2 * 1024 * 1024));
    });

    test('readFileHeader uses fast RandomAccessFile without full stream overhead', () async {
      final sampleFile = File('${tempDir.path}/header_test.pdf');
      await sampleFile.writeAsString('%PDF-1.7\nSample content header test');

      final header = await fileService.readFileHeader(sampleFile.path, maxBytes: 8);
      expect(header.length, equals(8));
      final headerStr = String.fromCharCodes(header);
      expect(headerStr, equals('%PDF-1.7'));
    });

    test('Concurrent getValidHistoryEntries scales efficiently with multiple items', () async {
      // Create 10 valid files
      final files = <File>[];
      for (int i = 0; i < 10; i++) {
        final f = File('${tempDir.path}/perf_doc_$i.pdf');
        await f.writeAsString('%PDF-1.4 dummy pdf $i');
        files.add(f);

        final entry = HistoryEntry(
          id: 'perf_entry_$i',
          title: 'Perf Doc $i',
          date: DateTime.now().subtract(Duration(minutes: i)),
          filePath: f.path,
          toolType: 'text_to_pdf',
        );
        await storageService.addHistoryEntry(entry);
      }

      final validEntries = await storageService.getValidHistoryEntries();
      expect(validEntries.length, equals(10));
    });

    test('cleanupMissingEntries batch deletes stale entries correctly', () async {
      final box = await Hive.openBox<HistoryEntry>('historyBox');
      final missing1 = HistoryEntry(
        id: 'stale_batch_1',
        title: 'Stale 1',
        date: DateTime.now(),
        filePath: '${tempDir.path}/non_existent_1.pdf',
        toolType: 'compress_pdf',
      );
      final missing2 = HistoryEntry(
        id: 'stale_batch_2',
        title: 'Stale 2',
        date: DateTime.now(),
        filePath: '${tempDir.path}/non_existent_2.pdf',
        toolType: 'split_pdf',
      );

      await box.put(missing1.id, missing1);
      await box.put(missing2.id, missing2);

      final removedCount = await storageService.cleanupMissingEntries();
      expect(removedCount, greaterThanOrEqualTo(2));
      expect(await storageService.getHistoryEntry('stale_batch_1'), isNull);
      expect(await storageService.getHistoryEntry('stale_batch_2'), isNull);
    });
  });
}
