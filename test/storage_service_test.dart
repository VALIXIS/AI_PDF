import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/storage_service.dart';

void main() {
  group('StorageService Missing-File & Accessibility Tests', () {
    final storageService = StorageService();

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
  });
}
