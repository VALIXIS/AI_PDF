import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';

class StorageService {
  static const String _boxName = 'historyBox';

  /// Gets the history box
  Box<HistoryEntry> get _historyBox => Hive.box<HistoryEntry>(_boxName);

  /// Adds a history entry
  Future<void> addHistoryEntry(HistoryEntry entry) async {
    try {
      await _historyBox.put(entry.id, entry);
    } catch (e) {
      throw Exception('Failed to add history entry: $e');
    }
  }

  /// Gets all history entries
  Future<List<HistoryEntry>> getAllHistoryEntries() async {
    try {
      return _historyBox.values.toList().cast<HistoryEntry>();
    } catch (e) {
      throw Exception('Failed to get history entries: $e');
    }
  }

  /// Gets a history entry by ID
  Future<HistoryEntry?> getHistoryEntry(String id) async {
    try {
      return _historyBox.get(id);
    } catch (e) {
      throw Exception('Failed to get history entry: $e');
    }
  }

  /// Deletes a history entry and attempts to safely delete physical file if present
  Future<void> deleteHistoryEntry(String id) async {
    try {
      final entry = await getHistoryEntry(id);
      if (entry != null && entry.filePath.isNotEmpty) {
        await FileService().deleteFile(entry.filePath);
      }
      await _historyBox.delete(id);
    } catch (e) {
      await _historyBox.delete(id);
    }
  }

  /// Updates a history entry
  Future<void> updateHistoryEntry(HistoryEntry entry) async {
    try {
      await _historyBox.put(entry.id, entry);
    } catch (e) {
      throw Exception('Failed to update history entry: $e');
    }
  }

  /// Clears all history
  Future<void> clearAllHistory() async {
    try {
      await _historyBox.clear();
    } catch (e) {
      throw Exception('Failed to clear history: $e');
    }
  }

  /// Gets history entries sorted by date (newest first)
  Future<List<HistoryEntry>> getHistoryEntriesSortedByDate() async {
    try {
      final entries = _historyBox.values.toList().cast<HistoryEntry>();
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    } catch (e) {
      throw Exception('Failed to get sorted history entries: $e');
    }
  }

  /// Gets history entries by tool type
  Future<List<HistoryEntry>> getHistoryEntriesByType(String toolType) async {
    try {
      final entries = _historyBox.values
          .toList()
          .cast<HistoryEntry>()
          .where((entry) => entry.toolType == toolType)
          .toList();
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    } catch (e) {
      throw Exception('Failed to get history entries by type: $e');
    }
  }

  /// Checks whether a history entry's associated file exists on disk and is accessible
  Future<bool> isEntryFileAccessible(HistoryEntry entry) async {
    try {
      if (entry.filePath.isEmpty) return false;
      return await FileService().isFileAccessible(entry.filePath);
    } catch (e) {
      return false;
    }
  }

  /// Retrieves history entries filtering out non-existent or inaccessible files
  Future<List<HistoryEntry>> getValidHistoryEntries() async {
    try {
      final allEntries = await getHistoryEntriesSortedByDate();
      final validEntries = <HistoryEntry>[];
      for (final entry in allEntries) {
        if (await isEntryFileAccessible(entry)) {
          validEntries.add(entry);
        }
      }
      return validEntries;
    } catch (e) {
      return [];
    }
  }

  /// Removes stale history records pointing to files that no longer exist
  Future<int> cleanupMissingEntries() async {
    try {
      final entries = _historyBox.values.toList().cast<HistoryEntry>();
      int removedCount = 0;
      for (final entry in entries) {
        final exists = await isEntryFileAccessible(entry);
        if (!exists) {
          await _historyBox.delete(entry.id);
          removedCount++;
        }
      }
      return removedCount;
    } catch (e) {
      return 0;
    }
  }

  /// Gets the count of history entries
  Future<int> getHistoryCount() async {
    try {
      return _historyBox.length;
    } catch (e) {
      throw Exception('Failed to get history count: $e');
    }
  }
}

