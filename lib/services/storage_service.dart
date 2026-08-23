import 'package:hive/hive.dart';
import 'package:pdf_ai_toolkit/models/history_entry.dart';
import 'package:pdf_ai_toolkit/services/file_service.dart';

class StorageService {
  static const String _boxName = 'historyBox';

  /// Helper to safely retrieve or open the history box.
  /// Returns null if Hive is uninitialized or box cannot be opened.
  Future<Box<HistoryEntry>?> _getBox() async {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        return Hive.box<HistoryEntry>(_boxName);
      }
      return await Future(() => Hive.openBox<HistoryEntry>(_boxName));
    } catch (_) {
      return null;
    }
  }

  /// Safely extracts non-null, valid HistoryEntry instances from the Hive box
  List<HistoryEntry> _getValidRecordsFromBox(Box<HistoryEntry> box) {
    final list = <HistoryEntry>[];
    for (final key in box.keys) {
      final dynamic val = box.get(key);
      if (val != null && val is HistoryEntry) {
        list.add(val);
      }
    }
    return list;
  }

  /// Adds a history entry after verifying file accessibility on disk.
  /// Merges duplicate entries pointing to the same file path instead of adding duplicates.
  Future<void> addHistoryEntry(HistoryEntry entry) async {
    try {
      if (entry.filePath.trim().isEmpty) return;
      final accessible = await isEntryFileAccessible(entry);
      if (!accessible) {
        // Failed or non-existent file operations do not create history entries
        return;
      }

      final box = await _getBox();
      if (box == null) return;

      final normalizedPath = FileService().normalizePath(entry.filePath);

      dynamic existingKey;
      HistoryEntry? existingEntry;

      for (final key in box.keys) {
        final dynamic val = box.get(key);
        if (val is HistoryEntry) {
          if (FileService().normalizePath(val.filePath) == normalizedPath || val.id == entry.id) {
            existingKey = key;
            existingEntry = val;
            break;
          }
        }
      }

      if (existingKey != null && existingEntry != null) {
        final updatedEntry = existingEntry.copyWith(
          title: entry.title.isNotEmpty ? entry.title : existingEntry.title,
          date: entry.date,
          filePath: entry.filePath,
          toolType: entry.toolType.isNotEmpty ? entry.toolType : existingEntry.toolType,
        );
        await box.put(existingKey, updatedEntry);
      } else {
        await box.put(entry.id, entry);
      }
    } catch (e) {
      // Storage failure must not crash file operations
    }
  }

  /// Gets all history entries safely
  Future<List<HistoryEntry>> getAllHistoryEntries() async {
    try {
      final box = await _getBox();
      if (box == null) return [];
      return _getValidRecordsFromBox(box);
    } catch (e) {
      return [];
    }
  }

  /// Gets a history entry by ID safely
  Future<HistoryEntry?> getHistoryEntry(String id) async {
    try {
      final box = await _getBox();
      if (box == null) return null;
      final dynamic val = box.get(id);
      if (val is HistoryEntry) return val;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Deletes a history entry and attempts to safely delete physical file if present
  Future<void> deleteHistoryEntry(String id) async {
    try {
      final box = await _getBox();
      final entry = await getHistoryEntry(id);
      if (entry != null && entry.filePath.isNotEmpty) {
        await FileService().deleteFile(entry.filePath);
      }
      if (box != null) {
        await box.delete(id);
      }
    } catch (e) {
      try {
        final box = await _getBox();
        if (box != null) {
          await box.delete(id);
        }
      } catch (_) {}
    }
  }

  /// Deletes a history entry by matching file path
  Future<void> deleteHistoryEntryByPath(String filePath) async {
    try {
      if (filePath.isEmpty) return;
      final box = await _getBox();
      if (box == null) return;
      final normalized = FileService().normalizePath(filePath);
      dynamic targetKey;
      for (final key in box.keys) {
        final dynamic val = box.get(key);
        if (val is HistoryEntry && FileService().normalizePath(val.filePath) == normalized) {
          targetKey = key;
          break;
        }
      }
      if (targetKey != null) {
        await box.delete(targetKey);
      }
    } catch (_) {}
  }

  /// Updates a history entry safely
  Future<void> updateHistoryEntry(HistoryEntry entry) async {
    try {
      final box = await _getBox();
      if (box == null) return;
      await box.put(entry.id, entry);
    } catch (e) {
      // Ignore update error gracefully
    }
  }

  /// Clears all history
  Future<void> clearAllHistory() async {
    try {
      final box = await _getBox();
      if (box == null) return;
      await box.clear();
    } catch (e) {
      // Ignore clear error gracefully
    }
  }

  /// Gets history entries sorted by date (newest first)
  Future<List<HistoryEntry>> getHistoryEntriesSortedByDate() async {
    try {
      final box = await _getBox();
      if (box == null) return [];
      final entries = _getValidRecordsFromBox(box);
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    } catch (e) {
      return [];
    }
  }

  /// Gets history entries by tool type
  Future<List<HistoryEntry>> getHistoryEntriesByType(String toolType) async {
    try {
      final box = await _getBox();
      if (box == null) return [];
      final entries = _getValidRecordsFromBox(box)
          .where((entry) => entry.toolType == toolType)
          .toList();
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    } catch (e) {
      return [];
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
      final box = await _getBox();
      if (box == null) return 0;
      final keysToDelete = <dynamic>[];
      for (final key in box.keys) {
        final dynamic val = box.get(key);
        if (val is HistoryEntry) {
          final exists = await isEntryFileAccessible(val);
          if (!exists) {
            keysToDelete.add(key);
          }
        } else {
          keysToDelete.add(key);
        }
      }
      for (final key in keysToDelete) {
        await box.delete(key);
      }
      return keysToDelete.length;
    } catch (e) {
      return 0;
    }
  }

  /// Gets the count of history entries
  Future<int> getHistoryCount() async {
    try {
      final box = await _getBox();
      if (box == null) return 0;
      return box.length;
    } catch (e) {
      return 0;
    }
  }
}
